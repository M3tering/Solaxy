// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISolaxy, Solaxy} from "../src/Solaxy.sol";

contract SolaxyUnitTest is Test {
    Solaxy SLX;
    IERC20 RESERVE;
    address here;
    address SLX_address;
    address M3TER_address;
    address RESERVE_address;
    address constant M3TER = 0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03;
    uint256 constant SLX_amountIn = 50125.007569468e18;
    uint256 constant SLX_amountMinted = 10000000e18;
    uint256 constant SLX_amountBurned = 46608.61816435866e18;
    uint256 constant reserve_amountDeposited = 1250000000e18;
    uint256 constant reserve_amountWithdrawn = 11625000e18;
    uint256 constant totalAssets = 1e10 * 1e18;

    function setUp() public {
        string memory url = vm.rpcUrl("ethereum-mainnet");
        vm.createSelectFork(url);
        here = address(this);

        SLX = new Solaxy();
        SLX_address = address(SLX);
        M3TER_address = address(M3TER);

        RESERVE_address = SLX.asset();
        RESERVE = IERC20(RESERVE_address);

        deal(RESERVE_address, here, totalAssets, true);
        RESERVE.approve(SLX_address, totalAssets);
    }

    function tipAccount() private view returns (address account) {
        address reg = 0x000000006551c19487814612e58FE06813775758;
        address imp = 0x55266d75D1a14E4572138116aF39863Ed6596E7F;

        (bool success, bytes memory data) = address(reg).staticcall(
            abi.encodeWithSignature("account(address,bytes32,uint256,address,uint256)", imp, 0x0, 1, M3TER_address, 0)
        );
        account = success ? abi.decode(data, (address)) : address(0);
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
        dealERC721(M3TER_address, here, 0);
        uint256 SLX_InitialBalance = SLX.balanceOf(here);
        uint256 totalAssetsInitial = SLX.totalAssets();

        // Deposit reserve to Solaxy contract
        SLX.safeDeposit(reserve_amountDeposited, here, SLX_amountMinted);
        uint256 SLX_supplyAfterDeposit = SLX.totalSupply();
        uint256 SLX_balanceAfterDeposit = SLX.balanceOf(here);
        uint256 totalAssetsAfterDeposit = SLX.totalAssets();

        assertEq(SLX_InitialBalance, 0, "SLX balance should be 0 before deposit");
        assertEq(totalAssetsInitial, 0, "reserve balance should be 0 before deposit");
        assertEq(SLX_supplyAfterDeposit, SLX_amountMinted, "SLX supply should increase after deposit");
        assertEq(SLX_balanceAfterDeposit, SLX_amountMinted, "SLX balance should increase after deposit");
        assertEq(totalAssetsAfterDeposit, reserve_amountDeposited, "reserve balance should decrease after deposit");

        // Withdraw reserve from Solaxy contract
        SLX.safeWithdraw(reserve_amountWithdrawn, here, here, SLX_amountIn);
        uint256 SLX_supplyAfterWithdraw = SLX.totalSupply();
        uint256 SLX_balanceAfterWithdraw = SLX.balanceOf(here);
        uint256 totalAssetsAfterWithdraw = SLX.totalAssets();

        assertApproxEqAbs(
            SLX_balanceAfterWithdraw,
            SLX_balanceAfterDeposit - SLX_amountIn,
            0.000000002e18,
            "SLX balance should decrease after withdrawal"
        );
        assertApproxEqAbs(
            SLX_supplyAfterWithdraw,
            SLX_supplyAfterDeposit - SLX_amountBurned,
            0.000000002e18,
            "SLX supply should decrease after withdrawal"
        );
        assertEq(
            totalAssetsAfterWithdraw,
            totalAssetsAfterDeposit - reserve_amountWithdrawn,
            "reserve balance should increase after withdrawal"
        );
        assertApproxEqAbs(
            SLX.balanceOf(tipAccount()),
            SLX_amountIn - SLX_amountBurned,
            0.000000002e18,
            "tip should be difference between all shares burnt vs shares spent"
        );
    }

    function test_M3terHolderCanMintAndRedeem() public {
        dealERC721(M3TER_address, here, 0);
        uint256 SLX_initialBalance = SLX.balanceOf(here);
        uint256 totalAssetsInitial = SLX.totalAssets();

        // Mint new SLX tokens
        SLX.safeMint(SLX_amountMinted, here, reserve_amountDeposited);
        uint256 SLX_supplyAfterMint = SLX.totalSupply();
        uint256 SLX_balanceAfterMint = SLX.balanceOf(here);
        uint256 totalAssetsAfterMint = SLX.totalAssets();

        assertEq(SLX_initialBalance, 0, "SLX balance should be 0 before minting");
        assertEq(totalAssetsInitial, 0, "reserve balance should be 0 before minting");
        assertEq(SLX_supplyAfterMint, SLX_amountMinted, "SLX supply should increase after minting");
        assertEq(SLX_balanceAfterMint, SLX_amountMinted, "SLX balance should increase after minting");
        assertEq(totalAssetsAfterMint, reserve_amountDeposited, "reserve balance should decrease after minting");

        // Redeem SLX tokens
        SLX.safeRedeem(SLX_amountBurned, here, here, reserve_amountWithdrawn * 93 / 100);
        uint256 SLX_supplyAfterRedeem = SLX.totalSupply();
        uint256 SLX_balanceAfterRedeem = SLX.balanceOf(here);
        uint256 totalAssetsAfterRedeem = SLX.totalAssets();

        assertApproxEqAbs(
            SLX_balanceAfterRedeem,
            SLX_balanceAfterMint - SLX_amountIn,
            0.000000002e18,
            "SLX balance should decrease after redeeming"
        );
        assertApproxEqAbs(
            SLX_supplyAfterRedeem,
            SLX_supplyAfterMint - SLX_amountBurned,
            0.000000002e18,
            "SLX supply should decrease after redeeming"
        );
        assertApproxEqAbs(
            totalAssetsAfterRedeem,
            totalAssetsAfterMint - reserve_amountWithdrawn,
            0.00002e18,
            "reserve balance should increase after redeeming"
        );
        assertApproxEqAbs(
            SLX.balanceOf(tipAccount()),
            SLX_amountIn - SLX_amountBurned,
            0.000000002e18,
            "tip should be difference between all shares burnt vs shares spent"
        );
    }
}
