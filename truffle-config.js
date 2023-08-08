require('dotenv').config();
const { IOTEX_PRIVATE_KEY } = process.env;
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 8545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
    },
    testnet: {
      provider: () => new HDWalletProvider(IOTEX_PRIVATE_KEY, "https://babel-api.testnet.iotex.io", 0, 2),
      network_id: 4690,    // IOTEX mainnet chain id 4689, testnet is 4690
      gas: 8500000,
      gasPrice: 1000000000000,
      skipDryRun: true
    }
  },

  compilers: {
    solc: {
      version: "0.8.16",      // Fetch exact version from solc-bin (default: truffle's version)
    }
  },
};