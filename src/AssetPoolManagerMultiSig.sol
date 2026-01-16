// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAssetPoolManager} from "./interfaces/IAssetPoolManager.sol";

/**
 * @title AssetPoolManagerMultiSig
 * @author AssetPool Team
 * @notice Multi-signature asset pool manager supporting ETH and ERC20 token deposits/withdrawals
 * @dev Security features:
 * - ReentrancyGuard: Prevents reentrancy attacks
 * - Pausable: Emergency pause functionality
 * - AccessControl: Role-based permission management
 * - SafeERC20: Safe token transfer handling 
 */
contract AssetPoolManagerMultiSig is 
    IAssetPoolManager,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable 
{
    using SafeERC20 for IERC20;
    
    /// @notice Role identifier for administrators with full access
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Role identifier for operators with limited withdrawal permissions
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Maximum number of items allowed in batch operations
    uint256 public constant MAX_BATCH_SIZE = 25;
    
    /// @dev Internal pool balances mapping: token address => balance
    mapping(address => uint256) private _poolBalances;
    
    /// @notice Mapping of supported tokens
    mapping(address => bool) public supportedTokens;
    
    /// @notice List of all supported token addresses
    address[] public tokenList;
    
    /// @notice Withdrawal limits per token for Operator role (token => max amount per tx)
    mapping(address => uint256) public withdrawLimits;
    
    /// @notice Sentinel address representing native ETH
    address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /// @dev Restricts function access to Admin role only
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }
    
    /// @dev Validates that the token is in the supported list
    modifier tokenSupported(address token) {
        _tokenSupported(token);
        _;
    }

    /// @dev Validates batch size does not exceed MAX_BATCH_SIZE
    modifier validBatchSize(uint256 size) {
        _validBatchSize(size);
        _;
    }

    /// @dev Internal function for Admin role check
    function _onlyAdmin() internal view {
        require(hasRole(ADMIN_ROLE, msg.sender), "AssetPoolManager: must have admin role");
    }

    /// @dev Internal function for token support check
    function _tokenSupported(address token) internal view {
        require(supportedTokens[token], "AssetPoolManager: token not supported");
    }

    /// @dev Internal function for batch size validation
    function _validBatchSize(uint256 size) internal pure {
        require(size <= MAX_BATCH_SIZE, "AssetPoolManager: batch too large");
    }
    
    /// @dev Reverts direct ETH transfers, use depositETH() instead
    receive() external payable {
        revert("AssetPoolManager: use depositETH function");
    }
    
    /**
     * @notice Initializes the contract with the given admin address
     * @dev Can only be called once due to initializer modifier
     * @param admin Address to be granted Admin, DefaultAdmin, and Operator roles
     */
    function initialize(address admin) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __Pausable_init();
        

        _grantRole(ADMIN_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);

        supportedTokens[ETH_ADDRESS] = true;
        tokenList.push(ETH_ADDRESS);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Sets the withdrawal limit for Operator role on a specific token
     * @dev Only callable by Admin. Set to 0 to disable Operator withdrawals for the token
     * @param token The token address to set limit for
     * @param limit Maximum amount Operator can withdraw per transaction
     */
    function setWithdrawLimit(address token, uint256 limit) external onlyAdmin {
        withdrawLimits[token] = limit;
        emit WithdrawLimitSet(token, limit);
    }

    /**
     * @notice Adds a new token to the supported tokens list
     * @dev Only callable by Admin. Token cannot be zero address or already supported
     * @param token The ERC20 token address to add
     */
    function addSupportedToken(
        address token
    ) external onlyAdmin {
        require(token != address(0), "AssetPoolManager: invalid token address");
        require(!supportedTokens[token], "AssetPoolManager: token already supported");
        
        supportedTokens[token] = true;
        tokenList.push(token);
        
        emit TokenAdded(token, true);
    }
    
    /**
     * @notice Removes a token from the supported tokens list
     * @dev Only callable by Admin. Pool balance for the token must be zero
     * @param token The token address to remove
     */
    function removeSupportedToken(address token) external onlyAdmin {
        require(supportedTokens[token], "AssetPoolManager: token not supported");
        require(_poolBalances[token] == 0, "AssetPoolManager: pool not empty");
        
        supportedTokens[token] = false;
        
        // remove from token list
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
        
        emit TokenRemoved(token);
    }
    
    /**
     * @notice Deposits native ETH into the pool
     * @dev Emits ETHDeposit event on success
     */
    function depositETH() 
        external 
        payable 
        nonReentrant 
        whenNotPaused 
        tokenSupported(ETH_ADDRESS) 
    {
        require(msg.value > 0, "AssetPoolManager: amount must be greater than 0");
        
        _poolBalances[ETH_ADDRESS] += msg.value;
        
        emit ETHDeposit(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @notice Deposits ERC20 tokens into the pool
     * @dev Handles fee-on-transfer tokens by checking actual received amount
     * @param token The ERC20 token address to deposit
     * @param amount The amount of tokens to deposit
     */
    function deposit(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        tokenSupported(token) 
    {
        require(amount > 0, "AssetPoolManager: amount must be greater than 0");

        // use balance delta to handle fee-on-transfer tokens
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));

        uint256 received = balanceAfter - balanceBefore;
        require(received > 0, "AssetPoolManager: zero received");
        require(received <= amount, "AssetPoolManager: received exceeds requested amount");

        // update balance with actual received amount
        _poolBalances[token] += received;

        emit Deposit(msg.sender, token, received, block.timestamp);
    }

    /**
     * @notice Withdraws native ETH from the pool
     * @dev Callable by Admin (unlimited) or Operator (with limits)
     * @param amount The amount of ETH to withdraw (in wei)
     * @param recipient The address to receive the ETH
     */
    function withdrawETH(uint256 amount, address recipient) 
        external 
        nonReentrant 
        whenNotPaused 
        tokenSupported(ETH_ADDRESS) 
    {
        _checkWithdrawPermissions(ETH_ADDRESS, amount);
        
        require(amount > 0, "AssetPoolManager: amount must be greater than 0");
        require(recipient != address(0), "AssetPoolManager: invalid recipient address");
        
        _poolBalances[ETH_ADDRESS] -= amount;
        
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "AssetPoolManager: ETH transfer failed");
        
        emit ETHWithdraw(recipient, amount, block.timestamp);
    }

    /**
     * @notice Withdraws ERC20 tokens from the pool
     * @dev Callable by Admin (unlimited) or Operator (with limits)
     * @param token The ERC20 token address to withdraw
     * @param amount The amount of tokens to withdraw
     * @param recipient The address to receive the tokens
     */
    function withdraw(address token, uint256 amount, address recipient) 
        external 
        nonReentrant 
        whenNotPaused 
        tokenSupported(token) 
    {
        _checkWithdrawPermissions(token, amount); 

        require(amount > 0, "AssetPoolManager: amount must be greater than 0");
        require(recipient != address(0), "AssetPoolManager: invalid recipient address");

        _poolBalances[token] -= amount;
        
        IERC20(token).safeTransfer(recipient, amount);
        
        emit Withdraw(recipient, token, amount, block.timestamp);
    }
    
    /**
     * @dev Internal function to check withdrawal permissions
     * @param token The token being withdrawn
     * @param amount The amount being withdrawn
     */
    function _checkWithdrawPermissions(address token, uint256 amount) internal view {
        if (hasRole(ADMIN_ROLE, msg.sender)) {
            return;
        } else if (hasRole(OPERATOR_ROLE, msg.sender)) {
            uint256 limit = withdrawLimits[token];
            require(limit > 0, "AssetPoolManager: limit not set");
            require(amount <= limit, "AssetPoolManager: amount exceeds operator limit");
        } else {
            revert("AssetPoolManager: missing role");
        }
    }

    /**
     * @notice Batch collects ERC20 tokens from multiple users into the pool
     * @dev Only callable by Admin. Useful for collecting payments from users
     *      Handles fee-on-transfer tokens and emits BatchPayinItem for each transfer
     * @param froms Array of sender addresses (must have approved this contract)
     * @param tokens Array of ERC20 token addresses
     * @param amounts Array of amounts to collect from each sender
     */
    function batchTransferPayin(
        address[] calldata froms,
        address[] calldata tokens,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        whenNotPaused
        validBatchSize(froms.length)
    {
        // Check caller has Admin or Operator role
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender),
            "AssetPoolManager: missing role"
        );
        
        require(
            froms.length == tokens.length &&
            tokens.length == amounts.length,
            "AssetPoolManager: array length mismatch"
        );

        for (uint256 i = 0; i < froms.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];
            address from = froms[i];

            require(amount > 0, "AssetPoolManager: amount must be greater than 0");
            require(supportedTokens[token], "AssetPoolManager: token not supported");

            uint256 balanceBefore = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransferFrom(from, address(this), amount);
            uint256 balanceAfter = IERC20(token).balanceOf(address(this));

            uint256 received = balanceAfter - balanceBefore;
            require(received > 0, "AssetPoolManager: zero received");
            require(received <= amount, "AssetPoolManager: received exceeds requested amount");

            _poolBalances[token] += received;

            // Emit event for each transfer with detailed info
            emit BatchPayinItem(from, token, amount, received, block.timestamp);
        }
    }

    /**
     * @notice Batch transfers tokens/ETH to multiple recipients for settlement
     * @dev Callable by Admin or Operator without amount limits
     *      Validates all transfers before executing any to ensure atomicity
     * @param recipients Array of recipient addresses
     * @param tokens Array of token addresses (use ETH_ADDRESS for native ETH)
     * @param amounts Array of amounts to transfer to each recipient
     */
    function batchTransferPayout(
        address[] calldata recipients,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) 
        external 
        nonReentrant 
        whenNotPaused
        validBatchSize(recipients.length)
    {
        // Check caller has Admin or Operator role
        require(
            hasRole(ADMIN_ROLE, msg.sender) || hasRole(OPERATOR_ROLE, msg.sender),
            "AssetPoolManager: missing role"
        );

        require(
            recipients.length == tokens.length && 
            tokens.length == amounts.length, 
            "AssetPoolManager: array length mismatch"
        );
        
        // Validate and update balances
        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != address(0), "AssetPoolManager: invalid recipient address");
            require(amounts[i] > 0, "AssetPoolManager: amount must be greater than 0");
            require(supportedTokens[tokens[i]], "AssetPoolManager: token not supported");
            require(_poolBalances[tokens[i]] >= amounts[i], "AssetPoolManager: insufficient pool balance");
            
            // Update balances
            _poolBalances[tokens[i]] -= amounts[i];
        }
        
        // Execute actual transfers and emit events
        for (uint256 i = 0; i < recipients.length; i++) {
            if (tokens[i] == ETH_ADDRESS) {
                (bool success, ) = recipients[i].call{value: amounts[i]}("");
                require(success, "AssetPoolManager: ETH transfer failed");
            } else {
                IERC20(tokens[i]).safeTransfer(recipients[i], amounts[i]);
            }
            
            // Emit event for each transfer with detailed info
            emit BatchPayoutItem(recipients[i], tokens[i], amounts[i], block.timestamp);
        }
    }
    
    /**
     * @notice Returns the pool balance for a specific token
     * @param token The token address to query (use ETH_ADDRESS for native ETH)
     * @return The current balance of the token in the pool
     */
    function poolBalance(address token) external view returns (uint256) {
        return _poolBalances[token];
    }
    
    /**
     * @notice Checks if a token is in the supported tokens list
     * @param token The token address to check
     * @return True if the token is supported, false otherwise
     */
    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }
    
    /**
     * @notice Returns all supported token addresses
     * @return Array of supported token addresses including ETH_ADDRESS
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }
    
    /**
     * @notice Returns all supported tokens with their current balances
     * @return tokens Array of supported token addresses
     * @return balances Array of corresponding balances
     */
    function getPoolAllBalances() external view returns (
        address[] memory tokens,
        uint256[] memory balances
    ) {
        uint256 length = tokenList.length; // Cache array length to save gas
        tokens = new address[](length);
        balances = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            tokens[i] = tokenList[i];
            balances[i] = _poolBalances[tokenList[i]];
        }
    }
    
    /**
     * @notice Pauses all deposit and withdrawal operations
     * @dev Only callable by Admin. Use for emergency situations
     */
    function pause() external onlyAdmin {
        _pause();
    }
    
    /**
     * @notice Resumes all deposit and withdrawal operations
     * @dev Only callable by Admin
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev Reserved storage gap for future upgrades
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    uint256[100] private __gap;
}