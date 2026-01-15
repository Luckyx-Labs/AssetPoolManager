# AssetPoolManager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue.svg)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFBD10.svg)](https://getfoundry.sh/)

A secure, upgradeable multi-signature asset pool manager for Ethereum, supporting ETH and ERC20 token deposits/withdrawals with role-based access control.

## Features

- 💰 **Multi-Asset Support** - Handle ETH and any ERC20 token in a single pool
- 📦 **Batch Operations** - Efficient batch payin/payout for multiple recipients
- 🛡️ **Security First** - ReentrancyGuard, SafeERC20, and fee-on-transfer token handling

## Architecture

```
src/
├── AssetPoolManagerMultiSig.sol    # Main contract implementation
└── interfaces/
    └── IAssetPoolManager.sol       # Contract interface
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

## Usage

### Configuration

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
```

### Deploy

```bash
# Load environment variables
source .env

# Deploy to network
forge script script/DeployAssetPoolManagerMultiSigProxy.s.sol:DeployAssetPoolManagerMultiSigProxy \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify
```

### Verify Contract

```bash
forge verify-contract \
    --chain <chain-id> \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    <DEPLOYED_CONTRACT_ADDRESS> \
    src/AssetPoolManagerMultiSig.sol:AssetPoolManagerMultiSig
```

## Contract Functions


| Function | Description |
|----------|-------------|
| `depositETH()` | Deposit native ETH into the pool |
| `deposit(token, amount)` | Deposit ERC20 tokens into the pool |
| `withdrawETH(amount, recipient)` | Withdraw ETH (within limits) |
| `withdraw(token, amount, recipient)` | Withdraw ERC20 tokens (within limits) |
| `batchTransferPayout(...)` | Batch transfer to multiple recipients |
| `addSupportedToken(token)` | Add a new supported token |
| `removeSupportedToken(token)` | Remove a supported token |
| `setWithdrawLimit(token, limit)` | Set operator withdrawal limit |

## Security

This contract has been designed with security best practices:

- ✅ ReentrancyGuard for all state-changing functions
- ✅ SafeERC20 for token transfers
- ✅ Fee-on-transfer token support

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

Built with ❤️ by [Luckyx-Labs](https://github.com/Luckyx-Labs)

