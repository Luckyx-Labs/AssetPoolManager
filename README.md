# AssetPoolManager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue.svg)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFBD10.svg)](https://getfoundry.sh/)

A secure, upgradeable multi-signature asset pool manager for Ethereum, supporting ETH and ERC20 token deposits/withdrawals with role-based access control and separated settlement architecture.

## Features

- **Multi-Asset Support** - Handle ETH and any ERC20 token in a single pool
- **Batch Operations** - Efficient batch payin/payout for multiple recipients
- **Security First** - ReentrancyGuard, SafeERC20, and fee-on-transfer token handling
- **Separation of Concerns** - Asset custody and settlement are handled by separate contracts
- **Multi-Sig Governance** - Fund withdrawals require multi-signature approval

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        System Architecture                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────────┐                     ┌─────────────────┐        │
│   │  Proxy Admin    │                     │  Multi-Sig      │        │
│   │  (Multi-Sig)    │                     │  Wallet         │        │
│   └────────┬────────┘                     └────────┬────────┘        │
│            │ Upgrade                               │ Admin Role      │
│            ▼                                       ▼                 │
│   ┌─────────────────────────────────────────────────────────┐        │
│   │             AssetPoolManagerMultiSig                    │        │
│   │              (Upgradeable Proxy)                        │        │
│   │  • Asset Custody                                        │        │
│   │  • Deposit ETH/ERC20                                    │        │
│   │  • Batch Payin Collection                               │        │
│   │  • Withdraw (Admin Only)                                │        │
│   └────────────────────────┬────────────────────────────────┘        │
│                            │                                         │
│                            │ Transfer Funds                          │
│                            ▼                                         │
│   ┌─────────────────────────────────────────────────────────┐        │
│   │                    Settlement                           │        │
│   │               (Direct Deployment)                       │        │
│   │  • Batch Payout Execution                               │        │
│   │  • Settlement Admin (EOA)                               │        │
│   └────────────────────────┬────────────────────────────────┘        │
│                            │                                         │
│                            │ Batch Payout                            │
│                            ▼                                         │
│   ┌─────────────────────────────────────────────────────────┐        │
│   │                      Users                              │        │
│   └─────────────────────────────────────────────────────────┘        │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Contracts

| Contract | Description | Deployment |
|----------|-------------|------------|
| `AssetPoolManagerMultiSig` | Main asset custody contract, handles deposits and admin withdrawals | Upgradeable Proxy |
| `Settlement` | Batch settlement contract for user payouts | Direct Deployment |

### Directory Structure

```
src/
├── AssetPoolManagerMultiSig.sol    # Main asset pool contract (upgradeable)
├── Settlement.sol                   # Batch settlement contract
└── interfaces/
    └── IAssetPoolManager.sol       # Contract interface

script/
├── DeployAssetPoolManagerMutilSigProxy.s.sol  # AssetPool deployment script
└── DeploySettlement.s.sol                      # Settlement deployment script
```

## Installation

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Setup

```bash
# Clone the repository
git clone https://github.com/Luckyx-Labs/AssetPoolManager.git
cd AssetPoolManager

# Install dependencies
forge install

# Build
forge build

# Run tests
forge test
```

## Deployment

### Environment Variables

```bash
# Create .env file
cp .env.example .env

# Required variables:
# DEPLOYER_PRIVATE_KEY=0x...           # Deployer private key
# ADMIN_ADDRESS=0x...                   # Multi-sig wallet for AssetPool admin
# PROXY_ADMIN_OWNER=0x...              # (Optional) Proxy admin owner
# SETTLEMENT_ADMIN_ADDRESS=0x...        # EOA for Settlement admin
# RPC_URL=https://...                   # RPC endpoint
# ETHERSCAN_API_KEY=...                 # For contract verification
```

### Deploy AssetPoolManager (Upgradeable)

```bash
source .env

forge script script/DeployAssetPoolManagerMutilSigProxy.s.sol:DeployAssetPoolManagerMultiSigProxy \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Deploy Settlement

```bash
source .env

forge script script/DeploySettlement.s.sol:DeploySettlement \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Contract Verification

If automatic verification fails during deployment, you can manually verify contracts:

#### Verify AssetPoolManagerMultiSig (Implementation)

```bash
forge verify-contract \
    --chain-id <CHAIN_ID> \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    <IMPLEMENTATION_ADDRESS> \
    src/AssetPoolManagerMultiSig.sol:AssetPoolManagerMultiSig
```

#### Verify Settlement

```bash
forge verify-contract \
    --chain-id <CHAIN_ID> \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address)" $SETTLEMENT_ADMIN_ADDRESS) \
    <SETTLEMENT_ADDRESS> \
    src/Settlement.sol:Settlement
```


## Contract Functions

### AssetPoolManagerMultiSig

| Function | Access | Description |
|----------|--------|-------------|
| `depositETH()` | Public | Deposit native ETH into the pool |
| `deposit(token, amount)` | Public | Deposit ERC20 tokens into the pool |
| `withdrawETH(amount, recipient)` | Admin | Withdraw ETH from the pool |
| `withdraw(token, amount, recipient)` | Admin | Withdraw ERC20 tokens from the pool |
| `batchTransferPayin(...)` | Admin | Batch collect tokens from multiple users |
| `addSupportedToken(token)` | Admin | Add a new supported token |
| `removeSupportedToken(token)` | Admin | Remove a supported token |
| `pause()` / `unpause()` | Admin | Emergency pause controls |

### Settlement

| Function | Access | Description |
|----------|--------|-------------|
| `batchTransferPayout(...)` | Admin | Batch transfer to multiple recipients |
| `getETHBalance()` | Public | Get contract ETH balance |
| `getTokenBalance(token)` | Public | Get contract token balance |
| `emergencyWithdrawETH(...)` | Admin | Emergency ETH withdrawal |
| `emergencyWithdrawToken(...)` | Admin | Emergency token withdrawal |
| `pause()` / `unpause()` | Admin | Emergency pause controls |


## Development

```bash
# Run tests with verbose output
forge test -vvv

# Run tests with gas report
forge test --gas-report

# Format code
forge fmt

# Run local node
anvil
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- [Foundry Documentation](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

---

Built with by [Luckyx-Labs](https://github.com/Luckyx-Labs)

