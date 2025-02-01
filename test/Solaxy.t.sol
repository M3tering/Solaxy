// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts@5.2.0/interfaces/IERC20.sol";
import {IERC6551Registry, ISolaxy, Solaxy} from "../src/Solaxy.sol";

contract SolaxyUnitTest is Test {
    Solaxy public SLX;
    IERC20 public RESERVE;
    address public here;
    address public SLX_address;
    address public RESERVE_address;
    uint256 public constant SLX_amountIn = 67.95e18;
    uint256 public constant SLX_amountMinted = 100e18;
    uint256 public constant SLX_amountBurned = 50e18;
    uint256 public constant reserve_amountDeposited = 0.125e18;
    uint256 public constant reserve_amountWithdrawn = 0.09375e18;
    uint256 public constant totalAssetsOneMillion = 1e6 * 1e18;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);
        here = address(this);

        SLX = new Solaxy();
        SLX_address = address(SLX);

        RESERVE_address = SLX.asset();
        RESERVE = IERC20(RESERVE_address);

        deal(RESERVE_address, here, totalAssetsOneMillion, true);
        RESERVE.approve(SLX_address, totalAssetsOneMillion);
    }

    function test_InitialSupplyOfSolaxyIsZero() public view {
        uint256 expected = 0;
        uint256 actual = SLX.totalSupply();
        assertEq(actual, expected, "New Solaxy contract should have 0 total supply");
    }

    function test_RevertWhen_EtherIsTransferredToContract() public {
        vm.expectRevert(); // expect a transaction revert during test.
        uint256 initialEthBalance = SLX_address.balance;
        payable(SLX_address).transfer(1 ether); // Sending 1 Ether to the contract
        assertEq(SLX_address.balance, initialEthBalance, "asset cannot receive ether transfer");
    }

    function test_RevertWhen_CallerHoldsNoM3ter() public {
        vm.expectRevert(ISolaxy.RequiresM3ter.selector);
        SLX.deposit(reserve_amountDeposited, here);

        vm.expectRevert(ISolaxy.RequiresM3ter.selector);
        SLX.mint(SLX_amountMinted, here);
    }

    function test_M3terHolderCanDepositAndWithdraw() public {
        dealERC721(address(SLX.M3TER()), here, 0);
        uint256 SLX_InitialBalance = SLX.balanceOf(here);
        uint256 totalAssetsInitial = SLX.totalAssets();

        // Deposit reserve to Solaxy contract
        SLX.deposit(reserve_amountDeposited, here);
        uint256 SLX_supplyAfterDeposit = SLX.totalSupply();
        uint256 SLX_balanceAfterDeposit = SLX.balanceOf(here);
        uint256 totalAssetsAfterDeposit = SLX.totalAssets();

        assertEq(SLX_InitialBalance, 0, "SLX balance should be 0 before deposit");
        assertEq(totalAssetsInitial, 0, "reserve balance should be 0 before deposit");
        assertEq(SLX_supplyAfterDeposit, SLX_amountMinted, "SLX supply should increase after deposit");
        assertEq(SLX_balanceAfterDeposit, SLX_amountMinted, "SLX balance should increase after deposit");
        assertEq(totalAssetsAfterDeposit, reserve_amountDeposited, "reserve balance should decrease after deposit");

        // convert to shares
        uint256 convertedShares = SLX.convertToShares(reserve_amountDeposited);
        assertEq(convertedShares, SLX_amountMinted);

        // Withdraw reserve from Solaxy contract
        SLX.withdraw(reserve_amountWithdrawn, here, here);
        uint256 SLX_supplyAfterWithdraw = SLX.totalSupply();
        uint256 SLX_balanceAfterWithdraw = SLX.balanceOf(here);
        uint256 totalAssetsAfterWithdraw = SLX.totalAssets();

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
            totalAssetsAfterWithdraw,
            totalAssetsAfterDeposit - reserve_amountWithdrawn,
            "reserve balance should increase after withdrawal"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(SLX.tipAccount());
        assertEq(SLX_feeBalance, 17950000000000000000);
    }

    function test_M3terAccountCanMintAndRedeem() public {
        dealERC721(address(SLX.M3TER()), here, 0);
        uint256 SLX_initialBalance = SLX.balanceOf(here);
        uint256 totalAssetsInitial = SLX.totalAssets();

        // Mint new SLX tokens
        SLX.mint(SLX_amountMinted, here);
        uint256 SLX_supplyAfterMint = SLX.totalSupply();
        uint256 SLX_balanceAfterMint = SLX.balanceOf(here);
        uint256 totalAssetsAfterMint = SLX.totalAssets();

        assertEq(SLX_initialBalance, 0, "SLX balance should be 0 before minting");
        assertEq(totalAssetsInitial, 0, "reserve balance should be 0 before minting");
        assertEq(SLX_supplyAfterMint, SLX_amountMinted, "SLX supply should increase after minting");
        assertEq(SLX_balanceAfterMint, SLX_amountMinted, "SLX balance should increase after minting");
        assertEq(totalAssetsAfterMint, reserve_amountDeposited, "reserve balance should decrease after minting");

        // convert to assets
        uint256 convertedAssets = SLX.convertToAssets(SLX_amountMinted);
        assertEq(convertedAssets, reserve_amountDeposited);

        // Redeem SLX tokens
        SLX.redeem(SLX_amountIn, here, here);
        uint256 SLX_supplyAfterRedeem = SLX.totalSupply();
        uint256 SLX_balanceAfterRedeem = SLX.balanceOf(here);
        uint256 totalAssetsAfterRedeem = SLX.totalAssets();

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
            totalAssetsAfterRedeem,
            totalAssetsAfterMint - reserve_amountWithdrawn,
            0.00002e18,
            "reserve balance should increase after redeeming"
        );

        // Check for fees
        uint256 SLX_feeBalance = SLX.balanceOf(SLX.tipAccount());
        assertEq(SLX_feeBalance, 17938800000000000000);
    }

    function test_knowHolderBalance() public view {
        uint256 knowHolderBalance = RESERVE.balanceOf(0x4e59b44847b379578588920cA78FbF26c0B4956C);
        assertEq(knowHolderBalance, 0.000864e18, "reserve balance should be equal 0.000864 reserve");
    }
}
