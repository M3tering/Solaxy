const SLX = artifacts.require("Solaxy");

module.exports = function(deployer, network, accounts) {
  deployer.deploy(SLX, accounts[0]);
};
