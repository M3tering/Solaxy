// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Solaxy} from "../src/Solaxy.sol";
import {RequiresM3ter} from "../src/interfaces/ISolaxy.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.2/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts@5.0.2/interfaces/IERC721.sol";

contract SolaxyUnitTest is Test {
    Solaxy public SLX;
    IERC20 public sDAI;
    address public here;
    address public SLX_address;
    address public sDAI_address;
    uint256 public constant SLX_amountIn = 6.795e18;
    uint256 public constant SLX_amountMinted = 10e18;
    uint256 public constant SLX_amountBurned = 5e18;
    uint256 public constant sDAI_amountDeposited = 0.125e18;
    uint256 public constant sDAI_amountWithdrawn = 0.09375e18;
    uint256 public constant sDAI_balanceOneMillion = 1e6 * 1e18;

    function setUp() public {
        string memory url = vm.rpcUrl("gnosis-mainnet");
        vm.createSelectFork(url);
        here = address(this);

        SLX = new Solaxy(address(99));
        SLX_address = address(SLX);

        sDAI_address = SLX.asset();
        sDAI = IERC20(sDAI_address);
        deal(sDAI_address, here, sDAI_balanceOneMillion, true);
        sDAI.approve(SLX_address, sDAI_balanceOneMillion);
    }

    function testInitialBalanceWithNewSolaxyContract() public {
        uint256 expected = 0;
        uint256 actual = SLX.totalSupply();
        assertEq(actual, expected, "New Solaxy contract should have 0 total supply");
    }

    function testSendEtherToContract() public {
        vm.expectRevert(); // expect a transaction revert during test.
        payable(SLX_address).transfer(1 ether); // Sending 1 Ether to the contract
        assertEq(SLX_address.balance, 0 ether, "asset ether balance is still equal to zero");
    }

    function testNonM3terHolder() public {
        vm.expectRevert(RequiresM3ter.selector);
        SLX.deposit(sDAI_amountDeposited, here);

        vm.expectRevert(RequiresM3ter.selector);
        SLX.mint(SLX_amountMinted, here);
    }

    function testM3terHolderDepositAndWithdraw() public {
        dealERC721(address(SLX.M3TER()), here, 1);
        uint256 SLX_InitialBalance = SLX.balanceOf(here);
        uint256 sDAI_initialBalance = sDAI.balanceOf(SLX_address);

        // Deposit sDAI to Solaxy contract
        SLX.deposit(sDAI_amountDeposited, here);
        uint256 SLX_supplyAfterDeposit = SLX.totalSupply();
        uint256 SLX_balanceAfterDeposit = SLX.balanceOf(here);
        uint256 sDAI_balanceAfterDeposit = sDAI.balanceOf(SLX_address);

        assertEq(SLX_InitialBalance, 0, "SLX balance should be 0 before deposit");
        assertEq(sDAI_initialBalance, 0, "sDAI balance should be 0 before deposit");
        assertEq(SLX_supplyAfterDeposit, SLX_amountMinted, "SLX supply should increase after deposit");
        assertEq(SLX_balanceAfterDeposit, SLX_amountMinted, "SLX balance should increase after deposit");
        assertEq(sDAI_balanceAfterDeposit, sDAI_amountDeposited, "sDAI balance should decrease after deposit");

        // convert to shares
        uint256 convertedShares = SLX.convertToShares(sDAI_amountDeposited);
        assertEq(convertedShares, SLX_amountMinted);

        // Withdraw sDAI from Solaxy contract
        SLX.withdraw(sDAI_amountWithdrawn, here, here);
        uint256 SLX_supplyAfterWithdraw = SLX.totalSupply();
        uint256 SLX_balanceAfterWithdraw = SLX.balanceOf(here);
        uint256 sDAI_balanceAfterWithdraw = sDAI.balanceOf(SLX_address);

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
            sDAI_balanceAfterWithdraw,
            sDAI_balanceAfterDeposit - sDAI_amountWithdrawn,
            "sDAI balance should increase after withdrawal"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(address(99));
        assertEq(SLX_feeBalance, 1795000000000000000);
    }

    function testM3terHolderMintAndRedeem() public {
        dealERC721(address(SLX.M3TER()), here, 1);
        uint256 SLX_initialBalance = SLX.balanceOf(here);
        uint256 sDAI_initialBalance = sDAI.balanceOf(SLX_address);

        // Mint new SLX tokens
        SLX.mint(SLX_amountMinted, here);
        uint256 SLX_supplyAfterMint = SLX.totalSupply();
        uint256 SLX_balanceAfterMint = SLX.balanceOf(here);
        uint256 sDAI_balanceAfterMint = sDAI.balanceOf(SLX_address);

        assertEq(SLX_initialBalance, 0, "SLX balance should be 0 before minting");
        assertEq(sDAI_initialBalance, 0, "sDAI balance should be 0 before minting");
        assertEq(SLX_supplyAfterMint, SLX_amountMinted, "SLX supply should increase after minting");
        assertEq(SLX_balanceAfterMint, SLX_amountMinted, "SLX balance should increase after minting");
        assertEq(sDAI_balanceAfterMint, sDAI_amountDeposited, "sDAI balance should decrease after minting");

        // convert to assets
        uint256 convertedAssets = SLX.convertToAssets(SLX_amountMinted);
        assertEq(convertedAssets, sDAI_amountDeposited);

        // Redeem SLX tokens
        SLX.redeem(SLX_amountIn, here, here);
        uint256 SLX_supplyAfterRedeem = SLX.totalSupply();
        uint256 SLX_balanceAfterRedeem = SLX.balanceOf(here);
        uint256 sDAI_balanceAfterRedeem = sDAI.balanceOf(SLX_address);

        assertApproxEqAbs(
            SLX_balanceAfterRedeem,
            SLX_balanceAfterMint - SLX_amountIn,
            0.002e18,
            "SLX balance should decrease after redeeming"
        );
        assertApproxEqAbs(
            SLX_supplyAfterRedeem,
            SLX_supplyAfterMint - SLX_amountBurned,
            0.002e18,
            "SLX supply should decrease after redeeming"
        );
        assertApproxEqAbs(
            sDAI_balanceAfterRedeem,
            sDAI_balanceAfterMint - sDAI_amountWithdrawn,
            0.002e18,
            "sDAI balance should increase after redeeming"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(address(99));
        assertEq(SLX_feeBalance, 1793880000000000000);
    }

    function testKnowAccountBalance() public {
        uint256 knowHolderBalance = sDAI.balanceOf(sDAI_address);
        assertApproxEqAbs(knowHolderBalance, 30.5e18, 0.001e18, "sDAI balance should approximately equal 30.49 sDAI");
    }
}
