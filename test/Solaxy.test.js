const { expectEvent, BN } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const DAI = artifacts.require("DAI");
const Solaxy = artifacts.require("Solaxy");

contract("Solaxy", (accounts) => {
  let daiInstance;
  let solaxyInstance;

  beforeEach(async () => {
    // Deploy DAI token
    daiInstance = await DAI.new();

    // Deploy Solaxy contract and pass the DAI token address
    solaxyInstance = await Solaxy.new(daiInstance.address);
  });

  // ... your other test cases ...

  it("should allow deposit and withdrawal using DAI", async () => {
    const initialDaiBalance = await daiInstance.balanceOf(accounts[0]);
    const depositAmount = web3.utils.toWei("1", "ether");

    // Approve Solaxy contract to spend DAI on behalf of the user
    await daiInstance.approve(solaxyInstance.address, depositAmount, { from: accounts[0] });

    const depositTx = await solaxyInstance.deposit(depositAmount, accounts[0]);
    expectEvent(depositTx, "Deposit", {
      sender: accounts[0],
      owner: accounts[0],
      assets: new BN(depositAmount),
    });

    const newDaiBalance = await daiInstance.balanceOf(accounts[0]);
    expect(newDaiBalance).to.be.bignumber.equal(initialDaiBalance.sub(new BN(depositAmount)));

    const withdrawAmount = web3.utils.toWei("0.5", "ether");
    const withdrawTx = await solaxyInstance.withdraw(withdrawAmount, accounts[0], accounts[0]);
    expectEvent(withdrawTx, "Withdraw", {
      sender: accounts[0],
      receiver: accounts[0],
      owner: accounts[0],
      assets: new BN(withdrawAmount),
    });

    const finalDaiBalance = await daiInstance.balanceOf(accounts[0]);
    expect(finalDaiBalance).to.be.bignumber.equal(newDaiBalance.add(new BN(withdrawAmount)));
  });

  // ... other test cases ...

});
