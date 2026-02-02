// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Settlement
 * @author LuckyX-Labs
 * @notice Batch settlement contract for distributing funds from the asset pool to recipients
 * @dev This contract serves as an intermediary for batch payouts from the main asset pool.
 *      Funds are first transferred from the asset pool to this contract by multi-sig administrators,
 *      then distributed to end users via batch transfer operations.
 */
contract Settlement is 
    ReentrancyGuard,
    AccessControl,
    Pausable 
{
    using SafeERC20 for IERC20;
    
    /// @notice Role identifier for administrators with settlement execution privileges
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Maximum number of transfers allowed in a single batch operation
    /// @dev Prevents out-of-gas errors and ensures predictable execution costs
    uint256 public constant MAX_BATCH_SIZE = 30;
    
    /// @notice Sentinel address used to represent native ETH in token arrays
    /// @dev This convention follows the pattern used by major DeFi protocols
    address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    
    /**
     * @notice Emitted for each individual payout within a batch transfer
     * @param to The recipient address receiving the funds
     * @param token The token address (ETH_ADDRESS for native ETH)
     * @param amount The amount transferred
     * @param timestamp The block timestamp when the transfer occurred
     */
    event BatchPayoutItem(
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    
    /**
     * @notice Emitted when the contract receives native ETH
     * @param from The address that sent the ETH
     * @param amount The amount of ETH received in wei
     * @param timestamp The block timestamp when ETH was received
     */
    event ETHReceived(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );

    /// @dev Restricts function access to accounts with ADMIN_ROLE
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Settlement: must have admin role");
        _;
    }

    /// @dev Validates that batch size is within acceptable bounds
    /// @param size The number of items in the batch
    modifier validBatchSize(uint256 size) {
        require(size > 0 && size <= MAX_BATCH_SIZE, "Settlement: invalid batch size");
        _;
    }
    
    /**
     * @notice Deploys the Settlement contract with the specified administrator
     * @dev The admin address is granted ADMIN_ROLE for executing settlements
     * @param admin The address to be granted administrative privileges
     */
    constructor(address admin) {
        require(admin != address(0), "Settlement: invalid admin address");
        
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /// @dev Allows the contract to receive native ETH transfers
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @notice Executes batch transfers to multiple recipients in a single transaction
     * @dev Performs atomic batch payouts with pre-validation to ensure all-or-nothing execution.
     *      The function validates all transfers before executing any to maintain atomicity.
     *      Supports both native ETH and ERC20 token transfers within the same batch.
     * @param recipients Array of destination addresses for the payouts
     * @param tokens Array of token addresses (use ETH_ADDRESS for native ETH)
     * @param amounts Array of amounts to transfer to each corresponding recipient
     */
    function batchTransferPayout(
        address[] calldata recipients,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) 
        external 
        nonReentrant 
        whenNotPaused
        onlyAdmin
        validBatchSize(recipients.length)
    {
        require(
            recipients.length == tokens.length && 
            tokens.length == amounts.length, 
            "Settlement: array length mismatch"
        );
        
        // Pre-validation phase: verify all transfers can be executed
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "Settlement: invalid recipient address");
            require(amounts[i] > 0, "Settlement: amount must be greater than 0");
            
            // Verify sufficient balance for each transfer
            if (tokens[i] == ETH_ADDRESS) {
                require(address(this).balance >= amounts[i], "Settlement: insufficient ETH balance");
            } else {
                require(
                    IERC20(tokens[i]).balanceOf(address(this)) >= amounts[i], 
                    "Settlement: insufficient token balance"
                );
            }
        }
        
        // Execution phase: perform transfers and emit events
        for (uint256 i = 0; i < recipients.length; i++) {
            if (tokens[i] == ETH_ADDRESS) {
                (bool success, ) = recipients[i].call{value: amounts[i]}("");
                require(success, "Settlement: ETH transfer failed");
            } else {
                IERC20(tokens[i]).safeTransfer(recipients[i], amounts[i]);
            }
            
            emit BatchPayoutItem(recipients[i], tokens[i], amounts[i], block.timestamp);
        }
    }

    /**
     * @notice Returns the contract's native ETH balance
     * @return The current ETH balance in wei
     */
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Returns the contract's balance for a specific token
     * @param token The token address to query (use ETH_ADDRESS for native ETH)
     * @return The current token balance
     */
    function getTokenBalance(address token) external view returns (uint256) {
        if (token == ETH_ADDRESS) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @notice Emergency withdrawal of native ETH from the contract
     * @dev Only callable by admin. Intended for recovering funds in emergency situations.
     * @param recipient The address to receive the withdrawn ETH
     * @param amount The amount of ETH to withdraw in wei
     */
    function emergencyWithdrawETH(address recipient, uint256 amount) 
        external 
        onlyAdmin 
        nonReentrant 
    {
        require(recipient != address(0), "Settlement: invalid recipient address");
        require(amount > 0 && amount <= address(this).balance, "Settlement: invalid amount");
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Settlement: ETH transfer failed");
    }

    /**
     * @notice Emergency withdrawal of ERC20 tokens from the contract
     * @dev Only callable by admin. Intended for recovering funds in emergency situations.
     * @param token The ERC20 token address to withdraw
     * @param recipient The address to receive the withdrawn tokens
     * @param amount The amount of tokens to withdraw
     */
    function emergencyWithdrawToken(address token, address recipient, uint256 amount) 
        external 
        onlyAdmin 
        nonReentrant 
    {
        require(token != address(0) && token != ETH_ADDRESS, "Settlement: invalid token address");
        require(recipient != address(0), "Settlement: invalid recipient address");
        require(amount > 0, "Settlement: amount must be greater than 0");
        
        IERC20(token).safeTransfer(recipient, amount);
    }
    
    /**
     * @notice Pauses all settlement operations
     * @dev Only callable by admin. Use in emergency situations to halt all payouts.
     *      When paused, batchTransferPayout will revert.
     */
    function pause() external onlyAdmin {
        _pause();
    }
    
    /**
     * @notice Resumes settlement operations after being paused
     * @dev Only callable by admin. Restores normal contract functionality.
     */
    function unpause() external onlyAdmin {
        _unpause();
    }
}

