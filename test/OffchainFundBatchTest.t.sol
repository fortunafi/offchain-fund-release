// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundBatchTest is Test {
    event ProcessDeposit(
        address indexed,
        address indexed,
        uint256 indexed,
        uint256,
        uint256,
        uint256
    );

    event ProcessRedeem(
        address indexed,
        address indexed,
        uint256 indexed,
        uint256,
        uint256,
        uint256,
        bool
    );

    address immutable eoa1 = vm.addr(1);
    address immutable eoa2 = vm.addr(2);
    address immutable eoa3 = vm.addr(3);
    address immutable eoa4 = vm.addr(4);
    address immutable eoa5 = vm.addr(5);
    address immutable eoa6 = vm.addr(6);

    IERC20 usdc;
    ERC20DecimalsMock token;

    OffchainFund offchainFund;

    function setUp() public {
        token = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc = IERC20(address(token));
        offchainFund = new OffchainFund(
            address(this),
            address(usdc),
            "Fund Test",
            "OCF"
        );

        vm.prank(eoa1);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(offchainFund), type(uint256).max);

        usdc.approve(address(offchainFund), type(uint256).max);

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);
        offchainFund.addToWhitelist(eoa3);
        offchainFund.addToWhitelist(eoa4);
        offchainFund.addToWhitelist(eoa5);
        offchainFund.addToWhitelist(eoa6);

        offchainFund.adjustCap(type(uint256).max);
    }

    function testProcessBatchError() external {
        address[] memory accountList = new address[](2);

        accountList[0] = eoa1;
        accountList[1] = eoa2;

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 100_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        offchainFund.batchProcessDeposit(accountList);

        assertEq(offchainFund.pendingDeposits(), 200_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        offchainFund.drain();
        offchainFund.refill(0);

        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 200_000e6);

        offchainFund.update(100e8);

        accountList = new address[](3);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;

        offchainFund.batchProcessDeposit(accountList);

        accountList = new address[](2);

        accountList[0] = eoa1;
        accountList[1] = eoa2;

        offchainFund.batchProcessDeposit(accountList);

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.redeem(1_000e18);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.redeem(1_000e18);

        offchainFund.batchProcessRedeem(accountList);

        assertEq(offchainFund.pendingRedemptions(), 2_000e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        offchainFund.drain();
        offchainFund.refill(1); // avoids failing on assert

        offchainFund.update(200e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 2_000e18);

        accountList = new address[](3);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;

        offchainFund.batchProcessRedeem(accountList);
    }

    function testProcessBatchDepositScenario1() external {
        address[] memory accountList;

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 100_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        offchainFund.drain();
        offchainFund.refill(0);

        offchainFund.update(100e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa1, 2, 1_000e18, 100_000e6, 100e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa2, 2, 1_000e18, 100_000e6, 100e8);

        accountList = new address[](2);

        accountList[0] = eoa1;
        accountList[1] = eoa2;

        offchainFund.batchProcessDeposit(accountList);

        assertEq(offchainFund.balanceOf(eoa1), 1_000e18);
        assertEq(offchainFund.balanceOf(eoa2), 1_000e18);
    }

    function testProcessBatchDepositScenario2() external {
        address[] memory accountList;

        token.mint(eoa1, 10_000e6);
        token.mint(eoa2, 20_000e6);
        token.mint(eoa3, 40_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(10_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(20_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(40_000e6);

        offchainFund.drain();
        offchainFund.refill(0);

        offchainFund.update(120e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(
            address(this),
            eoa1,
            2,
            83_333_333_333_333_333_333,
            10_000e6,
            120e8
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(
            address(this),
            eoa2,
            2,
            166_666_666_666_666_666_666,
            20_000e6,
            120e8
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(
            address(this),
            eoa3,
            2,
            333_333_333_333_333_333_333,
            40_000e6,
            120e8
        );

        accountList = new address[](3);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;

        offchainFund.batchProcessDeposit(accountList);

        assertEq(offchainFund.balanceOf(eoa1), 83_333_333_333_333_333_333);
        assertEq(offchainFund.balanceOf(eoa2), 166_666_666_666_666_666_666);
        assertEq(offchainFund.balanceOf(eoa3), 333_333_333_333_333_333_333);
    }

    function testProcessBatchDepositScenario3() external {
        address[] memory accountList;

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 200_000e6);
        token.mint(eoa3, 200_000e6);
        token.mint(eoa4, 400_000e6);

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(12))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(80e8))
        ); // currentPrice

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(200_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(200_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(400_000e6);

        offchainFund.drain();
        offchainFund.refill(0);

        offchainFund.update(800e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa1, 13, 125e18, 100_000e6, 800e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa2, 13, 250e18, 200_000e6, 800e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa3, 13, 250e18, 200_000e6, 800e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa4, 13, 500e18, 400_000e6, 800e8);

        accountList = new address[](4);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;
        accountList[3] = eoa4;

        offchainFund.batchProcessDeposit(accountList);

        assertEq(offchainFund.balanceOf(eoa1), 125e18);
        assertEq(offchainFund.balanceOf(eoa2), 250e18);
        assertEq(offchainFund.balanceOf(eoa3), 250e18);
        assertEq(offchainFund.balanceOf(eoa4), 500e18);
    }

    function testProcessBatchRedeemScenario1() external {
        address[] memory accountList;

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 100_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        offchainFund.drain();
        offchainFund.refill(0);

        offchainFund.update(100e8);

        accountList = new address[](2);

        accountList[0] = eoa1;
        accountList[1] = eoa2;

        offchainFund.batchProcessDeposit(accountList);

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.redeem(1_000e18);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.redeem(1_000e18);

        offchainFund.drain();
        offchainFund.refill(200_000e6);

        offchainFund.update(40e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa1,
            3,
            1_000e18,
            40_000e6,
            40e8,
            true
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa2,
            3,
            1_000e18,
            40_000e6,
            40e8,
            true
        );

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);

        accountList = new address[](2);

        accountList[0] = eoa1;
        accountList[1] = eoa2;

        offchainFund.batchProcessRedeem(accountList);

        assertEq(usdc.balanceOf(eoa1), 40_000e6);
        assertEq(usdc.balanceOf(eoa2), 40_000e6);
    }

    function testProcessBatchRedeemScenario2() external {
        address[] memory accountList;

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 200_000e6);
        token.mint(eoa3, 200_000e6);
        token.mint(eoa4, 400_000e6);

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(84))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(120e8))
        ); // currentPrice

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(200_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(200_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(400_000e6);

        offchainFund.drain();
        offchainFund.refill(0);

        offchainFund.update(800e8);

        accountList = new address[](4);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;
        accountList[3] = eoa4;

        offchainFund.batchProcessDeposit(accountList);

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.redeem(125e18);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.redeem(250e18);

        vm.prank(eoa3);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        offchainFund.redeem(250e18);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.redeem(500e18);

        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), 0);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 1_125e18);

        offchainFund.drain();
        offchainFund.refill(300_000e6);

        offchainFund.update(300e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa1,
            86,
            111_111_111_111_111_111_111,
            33_333_333_333,
            300e8,
            false
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa2,
            86,
            222_222_222_222_500_000_000,
            66_666_666_666,
            300e8,
            false
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa3,
            86,
            222_222_222_223_333_333_333,
            66_666_666_667,
            300e8,
            false
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa4,
            86,
            444_444_444_446_666_666_666,
            133_333_333_334,
            300e8,
            false
        );

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(usdc.balanceOf(eoa3), 0);
        assertEq(usdc.balanceOf(eoa4), 0);

        accountList = new address[](4);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;
        accountList[3] = eoa4;

        offchainFund.batchProcessRedeem(accountList);

        /**
         *
         * Each account is owed:
         *
         * eoa1: 300 * 125 = 37,500
         * eoa2: 300 * 250 = 75,000
         * eoa3: 300 * 250 = 75,000
         * eoa4: 300 * 500 = 150,000
         *
         * Each account gets a fraction of the total:
         *
         * eoa1: 300,000 * (125 / 1,125) = 33,333.33
         * eoa2: 300,000 * (250 / 1,125) = 66,666.67
         * eoa3: 300,000 * (250 / 1,125) = 66,666.67
         * eoa4: 300,000 * (500 / 1,125) = 133,333.33
         *
         */

        assertEq(usdc.balanceOf(eoa1), 33_333_333_333);
        assertEq(usdc.balanceOf(eoa2), 66_666_666_666);
        assertEq(usdc.balanceOf(eoa3), 66_666_666_667);
        assertEq(usdc.balanceOf(eoa4), 133_333_333_334);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        /**
         *
         * The pending redemptions amounts to the portion of the 337,500 total
         * that was owed, of which 37,500 was not fulfilled. Which checks out,
         * because: 300 * 125 = 37,500
         */

        assertApproxEqRel(offchainFund.pendingRedemptions(), 125e18, 0.10e18);
        assertEq(offchainFund.currentRedemptions(), 0);
    }

    function testProcessBatchRedeemScenario3() external {
        address[] memory accountList;

        token.mint(address(this), 1_000e6);

        deal(address(offchainFund), address(eoa1), 10e18, true);
        deal(address(offchainFund), address(eoa2), 10e18, true);
        deal(address(offchainFund), address(eoa3), 10e18, true);
        deal(address(offchainFund), address(eoa4), 10e18, true);

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(12))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(100e8))
        ); // currentPrice

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.redeem(2e18);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.redeem(4e18);

        vm.prank(eoa3);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        offchainFund.redeem(6e18);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.redeem(8e18);

        assertEq(offchainFund.balanceOf(eoa1), 8e18);
        assertEq(offchainFund.balanceOf(eoa2), 6e18);
        assertEq(offchainFund.balanceOf(eoa3), 4e18);
        assertEq(offchainFund.balanceOf(eoa4), 2e18);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 20e18);

        offchainFund.drain();
        offchainFund.refill(1_000e6);

        offchainFund.update(60e8);

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa1,
            13,
            1_666_666_666_666_666_666,
            100e6,
            60e8,
            false
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa2,
            13,
            3_333_333_333_333_333_333,
            200e6,
            60e8,
            false
        );

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa3, 13, 5e18, 300e6, 60e8, false);

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa4,
            13,
            6_666_666_666_666_666_666,
            400e6,
            60e8,
            false
        );

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(usdc.balanceOf(eoa3), 0);
        assertEq(usdc.balanceOf(eoa4), 0);

        accountList = new address[](4);

        accountList[0] = eoa1;
        accountList[1] = eoa2;
        accountList[2] = eoa3;
        accountList[3] = eoa4;

        offchainFund.batchProcessRedeem(accountList);

        /**
         *
         * Each account is owed:
         *
         * eoa1: 60 * 2 = 120
         * eoa2: 60 * 4 = 240
         * eoa3: 60 * 6 = 360
         * eoa4: 60 * 8 = 480
         *
         * Each account gets a fraction of the total:
         *
         * eoa1: 1,000 * (2 / 20) = 100
         * eoa2: 1,000 * (4 / 20) = 200
         * eoa3: 1,000 * (6 / 20) = 300
         * eoa4: 1,000 * (8 / 20) = 400
         *
         */

        assertEq(usdc.balanceOf(eoa1), 100e6);
        assertEq(usdc.balanceOf(eoa2), 200e6);
        assertEq(usdc.balanceOf(eoa3), 300e6);
        assertEq(usdc.balanceOf(eoa4), 400e6);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        /**
         *
         * The pending redemptions amounts to the portion of the 1,200 total
         * that was owed, of which 200 was not fulfilled. Which checks out,
         * because: 3.33 * 60 ~= 200
         *
         */

        assertApproxEqRel(offchainFund.pendingRedemptions(), 3.33e18, 0.10e18);
        assertEq(offchainFund.currentRedemptions(), 0);
    }
}
