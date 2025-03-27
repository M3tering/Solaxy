# Solaxy: ERC-20 Token with DAI Linear Bonding Curve

## Overview
Solaxy is an ERC-20 token contract that implements a linear bonding curve with DAI (a stablecoin) as the reserve currency. The bonding curve allows users to buy and sell Solaxy tokens directly from/to the contract at a dynamic price determined by the curve's slope. 
## Token Bonding Curves
A token bonding curve is a mathematical formula that defines the token's price based on its supply. In the case of Solaxy, a linear bonding curve is employed. This means the price of Solaxy tokens increases linearly with each token sold and decreases linearly with each token redeemed.

### Linear Bonding Curve Formula
The price of tokens in a linear bonding curve is calculated as follows: 
$$f(x) = mx + c$$ 

Here, the slope (`m`) represents the rate at which the price changes concerning the supply. In Solaxy's case, the slope is set to `0.000025`, determining the curve's steepness. Visit the [gitbook docs](https://docs.m3ter.ing/token-economics/mint-and-distribution) to learn more.

![Example Linear Bonding Curve](https://4273338628-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FlwEv5vD8Hcwor1O24YXn%2Fuploads%2FznFLXSpiB1QKyCcGpR3m%2Fimage.png?alt=media&token=e305dc82-346f-445d-9afb-4cfe2b10f209)


## ERC-4626 Support

Solaxy extends its functionality by providing support for [`ERC-4626`](https://eips.ethereum.org/EIPS/eip-4626); a tokenized vault interface. This interface allows the Solaxy contract to interact with other DeFi protocols and platforms seamlessly. `ERC-4626` integration enhances the capabilities of Solaxy in the context of token bonding curves.

## Contributing to Solaxy

We welcome contributions from developers, designers, and blockchain enthusiasts to enhance Solaxy. Here's how you can get involved:

- Code: Contribute by fixing bugs, adding features, or optimizing code. Check out open issues and submit pull requests.
- Documentation: Improve existing guides or create new ones to enhance Solaxy's usability.
- Testing: Help test Solaxy, identify edge cases, and ensure its security and functionality.
- Bug Reporting: Report bugs or issues you encounter while using Solaxy to help us improve.
- Feedback: Share your ideas and suggestions to shape Solaxy's development.

Read our Contribution Guidelines for details. Join us in making Solaxy better!

### Project Layout
The project is filed in the following directory structure:
```
├── dependencies/       # Project dependencies stored 
├── script/              # Foundry testing scripts
├── src/                 # Contains the Solidity smart contract files
│   ├── Interfaces/      # Contract interfaces for Solaxy
├── test/                # Solidity tests for Foundry
```

### How to Install Dependencies
Soldeer is used for managing and installing the dependencies for this repo, rather that the default Foundry approach of using git submodules. Simply run `forge soldeer install` to stepup any missing dependencies. See [Foundry book](https://book.getfoundry.sh/projects/soldeer).

### How to Run Tests
1. Ensure you have Foundry installed: See [Foundry book](https://book.getfoundry.sh/getting-started/installation)
1. Download or clone the project repository
1. Navigate to the project directory in your terminal.
1. Install all dependencies: See my section on 
 [How to Install Dependencies](#how-to-install-dependencies)
1. Run `forge test -vvv` to execute tests on a fork of Ethereum mainnet, 

### License
This project is licensed under the [MIT License](README.md).
