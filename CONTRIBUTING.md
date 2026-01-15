# Contributing to AssetPoolManager

First off, thank you for considering contributing to AssetPoolManager! It's people like you that make this project better.

## Code of Conduct

By participating in this project, you are expected to uphold our code of conduct: be respectful, inclusive, and constructive.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (contract addresses, transaction hashes, etc.)
- **Describe the behavior you observed and what you expected**
- **Include your environment details** (Foundry version, Solidity version, network)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the proposed functionality**
- **Explain why this enhancement would be useful**
- **List any alternatives you've considered**

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Install dependencies**: `forge install`
3. **Make your changes**
4. **Add tests** for any new functionality
5. **Ensure all tests pass**: `forge test`
6. **Format your code**: `forge fmt`
7. **Commit your changes** with clear, descriptive messages
8. **Push to your fork** and submit a pull request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/AssetPoolManager.git
cd AssetPoolManager

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Run tests with verbosity
forge test -vvv

# Format code
forge fmt
```

## Style Guide

### Solidity

- Follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use NatSpec comments for all public functions
- Keep functions focused and small
- Use meaningful variable and function names
- Add comments for complex logic

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests when relevant

### Testing

- Write tests for all new functionality
- Aim for high code coverage
- Test edge cases and failure modes
- Use descriptive test names

## Security

If you discover a security vulnerability, please do NOT open an issue. Instead, please see [SECURITY.md](SECURITY.md) for responsible disclosure guidelines.

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

---

Thank you for contributing! 🎉
