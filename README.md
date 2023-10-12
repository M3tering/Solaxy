# Solaxy: ERC-20 Token with DAI Linear Bonding Curve

## Overview
Solaxy is an ERC-20 token contract that implements a linear bonding curve with DAI (a stablecoin) as the reserve currency. The bonding curve allows users to buy and sell Solaxy tokens directly from/to the contract at a dynamic price determined by the curve's slope. 
## Token Bonding Curves
A token bonding curve is a mathematical formula that defines the token's price based on its supply. In the case of Solaxy, a linear bonding curve is employed. This means the price of Solaxy tokens increases linearly with each token sold and decreases linearly with each token redeemed.

### Linear Bonding Curve Formula
The price of tokens in a linear bonding curve is calculated as follows: 
$$ f(x) = mx + c $$ 

Here, the slope (`m`) represents the rate at which the price changes concerning the supply. In Solaxy's case, the slope is set to 25 bps (`0.0025`), determining the curve's steepness. Visit the [gitbook docs](https://m3tering.whynotswitch.com/token-economics/mint-and-distribution) to learn more.

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

### Project Structure
The project is filed in the following directory structure:
```
├── contracts/           # Contains the Solidity smart contract files
│   ├── Interfaces/      # Contract interfaces for Solaxy
├── migrations/          # Truffle deployment scripts
├── simulations/         # TokenSpice agent-based sims
├── test/                # JavaScript Mocha tests
```

### How to Run Tests
1. Ensure you have Truffle installed: `npm install -g truffle`
1. Navigate to the project directory in your terminal.
1. Run `npm install` to get the other dependencies 
1. Run `truffle test` to execute the Mocha tests.

### License
This project is licensed under the [MIT License](README.md).