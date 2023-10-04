const { expectEvent, BN } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");

const DAI = artifacts.require("DAI");
const Solaxy = artifacts.require("Solaxy");

contract("Solaxy", (accounts) => {
  let dai;
  let solaxy;

  const daiAmountDeposited = new BN("125000000000000000"); // 0.125 DAI
  const slxAmountMinted = new BN("10000000000000000000"); // 10 SLX

  const slxAmountBurned = new BN("5000000000000000000"); // 5 SLX
  const daiAmountWithdrawn = new BN("93750000000000000"); // 0.09375 DAI
  const slxAmountIn = new BN("6795000000000000000"); // 6.795 SLX

  beforeEach(async () => {
    dai = await DAI.new();
    solaxy = await Solaxy.new(dai.address, accounts[9]);
  });

  it("should allow deposit, withdrawal, and converting assets to shares", async () => {
    const initialDaiBalance = await dai.balanceOf(accounts[0]);
    const initialSlxBalance = await solaxy.balanceOf(accounts[0]);

    await dai.approve(solaxy.address, initialDaiBalance, {
      from: accounts[0],
    });

    const depositTx = await solaxy.deposit(daiAmountDeposited, accounts[0]);
    expectEvent(depositTx, "Deposit", {
      sender: accounts[0],
      owner: accounts[0],
      assets: daiAmountDeposited,
      shares: slxAmountMinted,
    });

    const newDaiBalance = await dai.balanceOf(accounts[0]);
    expect(newDaiBalance).to.be.bignumber.equal(
      initialDaiBalance.sub(daiAmountDeposited)
    );

    const newSlxBalance = await solaxy.balanceOf(accounts[0]);
    expect(newSlxBalance).to.be.bignumber.equal(
      initialSlxBalance.add(slxAmountMinted)
    );

    const convertedShares = await solaxy.convertToShares(daiAmountDeposited);
    expect(convertedShares).to.be.bignumber.equal(slxAmountBurned);

    const withdrawTx = await solaxy.withdraw(
      daiAmountWithdrawn,
      accounts[0],
      accounts[0]
    );
    expectEvent(withdrawTx, "Withdraw", {
      sender: accounts[0],
      receiver: accounts[0],
      owner: accounts[0],
      assets: daiAmountWithdrawn,
      shares: slxAmountBurned,
    });

    const finalDaiBalance = await dai.balanceOf(accounts[0]);
    expect(finalDaiBalance).to.be.bignumber.equal(
      newDaiBalance.add(daiAmountWithdrawn)
    );

    const finalSlxBalance = await solaxy.balanceOf(accounts[0]);
    const expectedFinalSlxBalance = newSlxBalance.sub(slxAmountIn);
    expect(finalSlxBalance).to.be.bignumber.equal(expectedFinalSlxBalance);

    const feeSlxBalance = await solaxy.balanceOf(accounts[9]);
    expect(feeSlxBalance).to.be.bignumber.equal(new BN("1795000000000000000"));
  });

  it("should allow minting and redeeming", async () => {
    const initialDaiBalance = await dai.balanceOf(accounts[0]);
    const initialSlxBalance = await solaxy.balanceOf(accounts[0]);

    await dai.approve(solaxy.address, initialDaiBalance, {
      from: accounts[0],
    });

    const mintTx = await solaxy.mint(slxAmountMinted, accounts[0]);
    expectEvent(mintTx, "Deposit", {
      sender: accounts[0],
      owner: accounts[0],
      shares: slxAmountMinted,
      assets: daiAmountDeposited,
    });

    const newSlxBalance = await solaxy.balanceOf(accounts[0]);
    expect(newSlxBalance).to.be.bignumber.equal(
      initialSlxBalance.add(slxAmountMinted)
    );

    const convertedAssets = await solaxy.convertToAssets(slxAmountBurned);
    expect(convertedAssets).to.be.bignumber.equal(daiAmountDeposited);

    const redeemTx = await solaxy.redeem(slxAmountIn, accounts[0], accounts[0]);
    expectEvent(redeemTx, "Withdraw", {
      sender: accounts[0],
      receiver: accounts[0],
      owner: accounts[0],
      shares: new BN("5001120000000000000"), // 5.00112 SLx instead of 5
    });

    const finalSlxBalance = await solaxy.balanceOf(accounts[0]);
    expect(finalSlxBalance).to.be.bignumber.equal(
      newSlxBalance.sub(slxAmountIn)
    );

    const feeSlxBalance = await solaxy.balanceOf(accounts[9]);
    expect(feeSlxBalance).to.be.bignumber.equal(new BN("1793880000000000000"));
  });

  // Add more test cases for other functions as needed
});
