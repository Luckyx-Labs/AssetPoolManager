// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAssetPoolManager {
    // events
    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    event Withdraw(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    event TokenAdded(address indexed token, bool isSupported);
    event TokenRemoved(address indexed token);
    event ETHDeposit(address indexed user, uint256 amount, uint256 timestamp);
    event ETHWithdraw(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawLimitSet(address indexed token, uint256 limit);
    event BatchPayinItem(
        address indexed from,
        address indexed token,
        uint256 requestedAmount,
        uint256 receivedAmount,
        uint256 timestamp
    );
    event BatchPayoutItem(
        address indexed to,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    // core functionality
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount, address recipient) external;

    function addSupportedToken(address token) external;
    function removeSupportedToken(address token) external;

    function poolBalance(address token) external view returns (uint256);
    function isTokenSupported(address token) external view returns (bool);
    function getSupportedTokens() external view returns (address[] memory);
    function getPoolAllBalances() external view returns (address[] memory, uint256[] memory);

    function batchTransferPayin(address[] calldata froms, address[] calldata tokens, uint256[] calldata amounts) external;
    function batchTransferPayout(address[] calldata recipients, address[] calldata tokens, uint256[] calldata amounts) external;
    // ETH functionality
    function depositETH() external payable;
    function withdrawETH(uint256 amount, address recipient) external;
}
