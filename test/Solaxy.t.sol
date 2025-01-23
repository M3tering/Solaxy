// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Solaxy} from "../src/Solaxy.sol";
import {ISolaxy} from "../src/interfaces/ISolaxy.sol";
import {IERC6551Registry} from "../src/interfaces/IERC6551Registry.sol";
import {IERC20} from "@openzeppelin/contracts@5.2.0/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts@5.2.0/interfaces/IERC721.sol";

contract SolaxyUnitTest is Test {
    Solaxy public SLX;
    IERC20 public reserve;
    address public here;
    address public SLX_address;
    address public reserve_address;
    uint256 public constant SLX_amountIn = 67.95e18;
    uint256 public constant SLX_amountMinted = 100e18;
    uint256 public constant SLX_amountBurned = 50e18;
    uint256 public constant reserve_amountDeposited = 0.125e18;
    uint256 public constant reserve_amountWithdrawn = 0.09375e18;
    uint256 public constant reserve_balanceOneMillion = 1e6 * 1e18;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);
        here = address(this);

        SLX = new Solaxy();
        SLX_address = address(SLX);

        reserve_address = SLX.asset();
        reserve = IERC20(reserve_address);
        deal(reserve_address, here, reserve_balanceOneMillion, true);
        reserve.approve(SLX_address, reserve_balanceOneMillion);
    }

    function m3terAccount() public returns (address) {
        // ERC6551@v0.3.1 Registry contract & Implementation Proxy addresses respectively
        return IERC6551Registry(0x000000006551c19487814612e58FE06813775758).createAccount(
            0x55266d75D1a14E4572138116aF39863Ed6596E7F, 0x0, 1, SLX.M3TER(), vm.randomUint()
        );
    }

    function testInitialBalanceWithNewSolaxyContract() public view {
        uint256 expected = 0;
        uint256 actual = SLX.totalSupply();
        assertEq(actual, expected, "New Solaxy contract should have 0 total supply");
    }

    function testSendEtherToContract() public {
        vm.expectRevert(); // expect a transaction revert during test.
        uint256 initialEthBalance = SLX_address.balance;
        payable(SLX_address).transfer(1 ether); // Sending 1 Ether to the contract
        assertEq(SLX_address.balance, initialEthBalance, "asset cannot receive ether transfer");
    }

    function testNonM3terAccount() public {
        vm.expectRevert(ISolaxy.RequiresM3ter.selector);
        SLX.deposit(reserve_amountDeposited, here);

        vm.expectRevert(ISolaxy.RequiresM3ter.selector);
        SLX.mint(SLX_amountMinted, here);
    }

    function testM3terAccountDepositAndWithdraw() public {
        vm.prank(m3terAccount());
        uint256 SLX_InitialBalance = SLX.balanceOf(here);
        uint256 reserve_initialBalance = reserve.balanceOf(SLX_address);

        // Deposit reserve to Solaxy contract
        SLX.deposit(reserve_amountDeposited, here);
        uint256 SLX_supplyAfterDeposit = SLX.totalSupply();
        uint256 SLX_balanceAfterDeposit = SLX.balanceOf(here);
        uint256 reserve_balanceAfterDeposit = reserve.balanceOf(SLX_address);

        assertEq(SLX_InitialBalance, 0, "SLX balance should be 0 before deposit");
        assertEq(reserve_initialBalance, 0, "reserve balance should be 0 before deposit");
        assertEq(SLX_supplyAfterDeposit, SLX_amountMinted, "SLX supply should increase after deposit");
        assertEq(SLX_balanceAfterDeposit, SLX_amountMinted, "SLX balance should increase after deposit");
        assertEq(reserve_balanceAfterDeposit, reserve_amountDeposited, "reserve balance should decrease after deposit");

        // convert to shares
        uint256 convertedShares = SLX.convertToShares(reserve_amountDeposited);
        assertEq(convertedShares, SLX_amountMinted);

        // Withdraw reserve from Solaxy contract
        SLX.withdraw(reserve_amountWithdrawn, here, here);
        uint256 SLX_supplyAfterWithdraw = SLX.totalSupply();
        uint256 SLX_balanceAfterWithdraw = SLX.balanceOf(here);
        uint256 reserve_balanceAfterWithdraw = reserve.balanceOf(SLX_address);

        assertEq(
            SLX_balanceAfterWithdraw,
            SLX_balanceAfterDeposit - SLX_amountIn,
            "SLX balance should decrease after withdrawal"
        );
        assertEq(
            SLX_supplyAfterWithdraw,
            SLX_supplyAfterDeposit - SLX_amountBurned,
            "SLX supply should decrease after withdrawal"
        );
        assertEq(
            reserve_balanceAfterWithdraw,
            reserve_balanceAfterDeposit - reserve_amountWithdrawn,
            "reserve balance should increase after withdrawal"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(SLX.tipAccount());
        assertEq(SLX_feeBalance, 17950000000000000000);
    }

    function testM3terAccountMintAndRedeem() public {
        vm.prank(m3terAccount());
        uint256 SLX_initialBalance = SLX.balanceOf(here);
        uint256 reserve_initialBalance = reserve.balanceOf(SLX_address);

        // Mint new SLX tokens
        SLX.mint(SLX_amountMinted, here);
        uint256 SLX_supplyAfterMint = SLX.totalSupply();
        uint256 SLX_balanceAfterMint = SLX.balanceOf(here);
        uint256 reserve_balanceAfterMint = reserve.balanceOf(SLX_address);

        assertEq(SLX_initialBalance, 0, "SLX balance should be 0 before minting");
        assertEq(reserve_initialBalance, 0, "reserve balance should be 0 before minting");
        assertEq(SLX_supplyAfterMint, SLX_amountMinted, "SLX supply should increase after minting");
        assertEq(SLX_balanceAfterMint, SLX_amountMinted, "SLX balance should increase after minting");
        assertEq(reserve_balanceAfterMint, reserve_amountDeposited, "reserve balance should decrease after minting");

        // convert to assets
        uint256 convertedAssets = SLX.convertToAssets(SLX_amountMinted);
        assertEq(convertedAssets, reserve_amountDeposited);

        // Redeem SLX tokens
        SLX.redeem(SLX_amountIn, here, here);
        uint256 SLX_supplyAfterRedeem = SLX.totalSupply();
        uint256 SLX_balanceAfterRedeem = SLX.balanceOf(here);
        uint256 reserve_balanceAfterRedeem = reserve.balanceOf(SLX_address);

        assertEq(
            SLX_balanceAfterRedeem, SLX_balanceAfterMint - SLX_amountIn, "SLX balance should decrease after redeeming"
        );
        assertApproxEqAbs(
            SLX_supplyAfterRedeem,
            SLX_supplyAfterMint - SLX_amountBurned,
            0.02e18,
            "SLX supply should decrease after redeeming"
        );
        assertApproxEqAbs(
            reserve_balanceAfterRedeem,
            reserve_balanceAfterMint - reserve_amountWithdrawn,
            0.00002e18,
            "reserve balance should increase after redeeming"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(SLX.tipAccount());
        assertEq(SLX_feeBalance, 17938800000000000000);
    }

    // function testKnowAccountBalance() public {
    //     uint256 knowAccountBalance = reserve.balanceOf(reserve_address);
    //     assertApproxEqAbs(
    //         knowAccountBalance, 30.5e18, 0.001e18, "reserve balance should approximately equal 30.49 reserve"
    //     );
    // }
}
