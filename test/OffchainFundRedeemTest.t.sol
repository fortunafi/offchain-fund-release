// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundRedeemTest is Test {
    event Redeem(address indexed, uint256 indexed, uint256);

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

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        usdc.approve(address(offchainFund), type(uint256).max);

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);
        offchainFund.addToWhitelist(eoa3);
        offchainFund.addToWhitelist(eoa4);
        offchainFund.addToWhitelist(eoa5);
        offchainFund.addToWhitelist(eoa6);

        offchainFund.adjustCap(type(uint256).max);
    }

    function testRedemptionScenario1() external {
        bool valid;
        string memory message;

        uint256 epoch;
        uint256 assets;

        /**
         *
         * Two users redeem differing numbers of shares before and after actions
         * taken by the contract owner. Success and failure is verified against
         * the changing contract state.
         *
         */

        deal(address(offchainFund), address(eoa1), 100e18, true);
        deal(address(offchainFund), address(eoa2), 100e18, true);
        deal(address(offchainFund), address(eoa3), 100e18, true);
        deal(address(offchainFund), address(eoa4), 100e18, true);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 1, 20e18);

        vm.prank(eoa1);
        offchainFund.redeem(20e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 1, 40e18);

        vm.prank(eoa2);
        offchainFund.redeem(40e18);

        // Check user and contract state after redemptions

        assertEq(offchainFund.pendingRedemptions(), 60e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // eoa1

        (epoch, assets) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 1);
        assertEq(assets, 20e18);

        (valid, message) = offchainFund.canProcessRedeem(eoa1);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for redeem");

        // eoa2

        (epoch, assets) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 1);
        assertEq(assets, 40e18);

        (valid, message) = offchainFund.canProcessRedeem(eoa2);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for redeem");

        // eoa3

        (epoch, assets) = offchainFund.userRedemptions(eoa3);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        (valid, message) = offchainFund.canProcessRedeem(eoa3);

        assertFalse(valid);
        assertEq(message, "account has no redeem order");

        // eoa4

        (epoch, assets) = offchainFund.userRedemptions(eoa4);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        (valid, message) = offchainFund.canProcessRedeem(eoa4);

        assertFalse(valid);
        assertEq(message, "account has no redeem order");

        // Check constraints on redemption orders

        // eoa1

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 1, 40e18);

        vm.prank(eoa1);
        offchainFund.redeem(40e18);

        (epoch, assets) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 1);
        assertEq(assets, 60e18);

        // eoa2

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 1, 20e18);

        vm.prank(eoa2);
        offchainFund.redeem(20e18);

        (epoch, assets) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 1);
        assertEq(assets, 60e18);

        // eoa3

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa3, 1, 100e18);

        vm.prank(eoa3);
        offchainFund.redeem(100e18);

        (epoch, assets) = offchainFund.userRedemptions(eoa3);

        assertEq(epoch, 1);
        assertEq(assets, 100e18);

        // eo4

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa4, 1, 100e18);

        vm.prank(eoa4);
        offchainFund.redeem(100e18);

        (epoch, assets) = offchainFund.userRedemptions(eoa4);

        assertEq(epoch, 1);
        assertEq(assets, 100e18);

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Price is set to 100

        offchainFund.update(100e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 320e18);

        vm.expectRevert("user has unprocessed redemptions");

        vm.prank(eoa1);
        offchainFund.redeem(10e6);

        vm.expectRevert("user has unprocessed redemptions");

        vm.prank(eoa2);
        offchainFund.redeem(10e6);
    }

    function testRedemptionScenario2() external {
        bytes memory encodedSelector;

        /**
         *
         * Two users out of three redeem differing numbers of shares at the
         * initial contract state. The price is updated to 20. Each user who has
         * an active redemption is then rejected on any additional orders before
         * they are processed. Furthermore, an additional error state is checked
         * for the third user.
         *
         */

        deal(address(offchainFund), address(eoa1), 100e18, true);
        deal(address(offchainFund), address(eoa2), 100e18, true);

        token.mint(address(this), 24_000e6);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 1, 20e18);

        vm.prank(eoa1);
        offchainFund.redeem(20e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 1, 40e18);

        vm.prank(eoa2);
        offchainFund.redeem(40e18);

        // Check user and contract state after redemptions

        assertEq(offchainFund.pendingRedemptions(), 60e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 24_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Contract must be drained before price can update

        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(400e8);

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 24_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(12_000e6);

        assertEq(usdc.balanceOf(address(this)), 12_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 12_000e6);

        // Price is set to 400

        offchainFund.update(400e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 60e18);

        // eoa1

        vm.expectRevert("user has unprocessed redemptions");

        vm.prank(eoa1);
        offchainFund.redeem(10e18);

        // eoa2

        vm.expectRevert("user has unprocessed redemptions");

        vm.prank(eoa2);
        offchainFund.redeem(10e18);

        // Checks `redeem` call fails if token transfer returns false

        encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            eoa1,
            4_000e6
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        // eoa1

        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa1);

        offchainFund.refill(12_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 24_000e6);

        encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            eoa2,
            16_000e6
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        // eoa3

        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa2);

        vm.clearMockedCalls();
    }

    function testRedemptionScenario3() external {
        bool valid;
        string memory message;

        /**
         *
         * Two users out of four redeem 10 shares. The price is updated to 400,
         * and the redemption orders are processed. The full value of the
         * redemptions is 8 K USDC, but only 4 K USDC is added to the contract,
         * so each user gets half the value of their redemption order in USDC.
         *
         */

        token.mint(address(this), 4_000e6);

        deal(address(offchainFund), address(eoa1), 10e18, true);
        deal(address(offchainFund), address(eoa2), 10e18, true);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 1, 10e18);

        vm.prank(eoa1);
        offchainFund.redeem(10e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 1, 10e18);

        vm.prank(eoa2);
        offchainFund.redeem(10e18);

        // Check user and contract state after redemption orders have been made

        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);

        assertEq(offchainFund.pendingRedemptions(), 20e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);

        assertEq(usdc.balanceOf(address(this)), 4_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        vm.expectRevert("nav has not been updated for redeem");
        offchainFund.processRedeem(eoa1);

        vm.expectRevert("nav has not been updated for redeem");
        offchainFund.processRedeem(eoa2);

        vm.expectRevert("account has no redeem order");
        offchainFund.processRedeem(eoa3);

        vm.expectRevert("account has no redeem order");
        offchainFund.processRedeem(eoa4);

        // Contract must be drained before price can update

        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(400e8);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 4_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(4_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 4_000e6);

        // Price is set to 400

        offchainFund.update(400e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 20e18);

        // eoa1

        (valid, message) = offchainFund.canProcessRedeem(eoa1);

        assertTrue(valid);
        assertEq(message, "");

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa1, 2, 5e18, 2_000e6, 400e8, false);

        offchainFund.processRedeem(eoa1);

        // eoa2

        (valid, message) = offchainFund.canProcessRedeem(eoa2);

        assertTrue(valid);
        assertEq(message, "");

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa2, 2, 5e18, 2_000e6, 400e8, false);

        offchainFund.processRedeem(eoa2);

        // eoa3

        (valid, message) = offchainFund.canProcessRedeem(eoa3);

        assertFalse(valid);
        assertEq(message, "account has no redeem order");

        vm.expectRevert("account has no redeem order");
        offchainFund.processRedeem(eoa3);

        // eoa4

        (valid, message) = offchainFund.canProcessRedeem(eoa4);

        assertFalse(valid);
        assertEq(message, "account has no redeem order");

        vm.expectRevert("account has no redeem order");
        offchainFund.processRedeem(eoa4);

        // Check user and contract state after redemption orders has been
        // processed

        assertEq(offchainFund.pendingRedemptions(), 10e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(eoa1), 2_000e6);
        assertEq(usdc.balanceOf(eoa2), 2_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);
    }

    function testRedemptionScenario4() external {
        uint256 epoch;
        uint256 shares;

        /**
         *
         * Four users, each deposit 250 K USDC at the initial contract state.
         * The price is updated to 1 K, and the subscription orders are
         * processed. Each user with deposits receives 250 tokens.
         *
         * Two of the users redeem all of their 250 tokens. The price is updated
         * to 2 K, so each user is owed 500 K USDC, or 1 M USDC total.
         *
         * The fund owner adds 800 K USDC to the contract, which is 80% of the
         * total redemption value, so 100 shares are rolled over.
         *
         */

        token.mint(eoa1, 250_000e6);
        token.mint(eoa2, 250_000e6);
        token.mint(eoa3, 250_000e6);
        token.mint(eoa4, 250_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(250_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(250_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(250_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(250_000e6);

        offchainFund.drain();
        offchainFund.update(1_000e8);

        offchainFund.processDeposit(eoa1);
        offchainFund.processDeposit(eoa2);
        offchainFund.processDeposit(eoa3);
        offchainFund.processDeposit(eoa4);

        assertEq(offchainFund.balanceOf(eoa1), 250e18);
        assertEq(offchainFund.balanceOf(eoa2), 250e18);
        assertEq(offchainFund.balanceOf(eoa3), 250e18);
        assertEq(offchainFund.balanceOf(eoa4), 250e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 2, 250e18);

        vm.prank(eoa1);
        offchainFund.redeem(250e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 2, 250e18);

        vm.prank(eoa2);
        offchainFund.redeem(250e18);

        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 250e18);
        assertEq(offchainFund.balanceOf(eoa4), 250e18);

        assertEq(offchainFund.pendingRedemptions(), 500e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 1_000_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 2);
        assertEq(shares, 250e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 2);
        assertEq(shares, 250e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa3);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        (epoch, shares) = offchainFund.userRedemptions(eoa4);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 1_000_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(800_000e6);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 800_000e6);

        // Price is set to 2 K

        offchainFund.update(2_000e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 500e18);

        // eoa1

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa1,
            3,
            200e18,
            400_000e6,
            2_000e8,
            false
        );

        offchainFund.processRedeem(eoa1);

        // eoa2

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa2,
            3,
            200e18,
            400_000e6,
            2_000e8,
            false
        );

        offchainFund.processRedeem(eoa2);

        // Check user and contract state after redemption orders have been
        // processed

        // There was 80% of the USDC needed to fill the order, so 100 shares are
        // rolled over

        assertEq(offchainFund.pendingRedemptions(), 100e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(eoa1), 400_000e6);
        assertEq(usdc.balanceOf(eoa2), 400_000e6);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Final user state

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, offchainFund.epoch());
        assertEq(shares, 50e18); // 20.0% left

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, offchainFund.epoch());
        assertEq(shares, 50e18); // 20.0% left
    }

    function testRedemptionScenario5() external {
        uint256 epoch;
        uint256 shares;

        /**
         *
         * Two users, each 80 K USDC and 120 K USDC respectively. The price is
         * updated 400, and the subscription orders are processed. The users
         * receive 200 and 300 tokens respectively.
         *
         * The two users each redeem 100 tokens. The price is updated
         * to 800, so each user is owed 80 K USDC, or 160 K USDC total.
         *
         * The fund owner adds 100 K USDC to the contract, which is 62.5% of the
         * total redemption value, so 75 shares are rolled over.
         *
         */

        token.mint(eoa1, 80_000e6);
        token.mint(eoa2, 120_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(80_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(120_000e6);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Price is set to 400

        offchainFund.update(400e8);

        offchainFund.processDeposit(eoa1);
        offchainFund.processDeposit(eoa2);

        assertEq(offchainFund.balanceOf(eoa1), 200e18);
        assertEq(offchainFund.balanceOf(eoa2), 300e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 2, 100e18);

        vm.prank(eoa1);
        offchainFund.redeem(100e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 2, 100e18);

        vm.prank(eoa2);
        offchainFund.redeem(100e18);

        assertEq(offchainFund.balanceOf(eoa1), 100e18);
        assertEq(offchainFund.balanceOf(eoa2), 200e18);

        assertEq(offchainFund.pendingRedemptions(), 200e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 2);
        assertEq(shares, 100e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 2);
        assertEq(shares, 100e18);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(100_000e6);

        assertEq(usdc.balanceOf(address(this)), 100_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 100_000e6);

        // Price is set to 800

        offchainFund.update(800e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 200e18);

        // eoa1

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa1,
            3,
            62.5 * 1e18,
            50_000e6,
            800e8,
            false
        );

        offchainFund.processRedeem(eoa1);

        // eoa2

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            eoa2,
            3,
            62.5 * 1e18,
            50_000e6,
            800e8,
            false
        );

        offchainFund.processRedeem(eoa2);

        // Check user and contract state after redemption orders have been
        // processed

        // There was 100 K USDC needed to fill redemptions worth 160 K USDC, so
        // 75 shares are rolled over

        assertEq(offchainFund.pendingRedemptions(), 75e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(usdc.balanceOf(eoa1), 50_000e6);
        assertEq(usdc.balanceOf(eoa2), 50_000e6);

        assertEq(usdc.balanceOf(address(this)), 100_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Final user state

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, offchainFund.epoch());
        assertEq(shares, 37.5 * 1e18); // 37.5% left

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, offchainFund.epoch());
        assertEq(shares, 37.5 * 1e18); // 37.5% left
    }

    function testRedemptionScenario6() external {
        uint256 epoch;
        uint256 shares;

        /**
         *
         * Four users each redeem shares in differing amounts. The price is
         * updated to 100, and the redemption orders are processed. The full
         * value of the redemptions is 2 K USDC, and the full 2 K USDC is added
         * to the contract, so all redemptions are filled in full.
         *
         */

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(12))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(60e8))
        ); // currentPrice

        token.mint(address(this), 2_000e6);

        deal(address(offchainFund), address(eoa1), 10e18, true);
        deal(address(offchainFund), address(eoa2), 10e18, true);
        deal(address(offchainFund), address(eoa3), 10e18, true);
        deal(address(offchainFund), address(eoa4), 10e18, true);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 12, 2e18);

        vm.prank(eoa1);
        offchainFund.redeem(2e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 12, 4e18);

        vm.prank(eoa2);
        offchainFund.redeem(4e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa3, 12, 6e18);

        vm.prank(eoa3);
        offchainFund.redeem(6e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa4, 12, 8e18);

        vm.prank(eoa4);
        offchainFund.redeem(8e18);

        // Check user and contract state after redemption orders have been made

        assertEq(offchainFund.balanceOf(eoa1), 8e18);
        assertEq(offchainFund.balanceOf(eoa2), 6e18);
        assertEq(offchainFund.balanceOf(eoa3), 4e18);
        assertEq(offchainFund.balanceOf(eoa4), 2e18);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 20e18);

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(usdc.balanceOf(eoa3), 0);
        assertEq(usdc.balanceOf(eoa4), 0);

        assertEq(usdc.balanceOf(address(this)), 2_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 2_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(2_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 2_000e6);

        offchainFund.update(100e8);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 20e18);

        // eoa1

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa1, 13, 2e18, 200e6, 100e8, true);

        offchainFund.processRedeem(eoa1);
        assertEq(usdc.balanceOf(eoa1), 200e6);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 18e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        // eoa2

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa2, 13, 4e18, 400e6, 100e8, true);

        offchainFund.processRedeem(eoa2);
        assertEq(usdc.balanceOf(eoa2), 400e6);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 14e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        // eoa3

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa3, 13, 6e18, 600e6, 100e8, true);

        offchainFund.processRedeem(eoa3);
        assertEq(usdc.balanceOf(eoa3), 600e6);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 8e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa3);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        // eoa4

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa4, 13, 8e18, 800e6, 100e8, true);

        offchainFund.processRedeem(eoa4);
        assertEq(usdc.balanceOf(eoa4), 800e6);

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 0);

        (epoch, shares) = offchainFund.userRedemptions(eoa4);

        assertEq(epoch, 0);
        assertEq(shares, 0);

        // Check final contract state after redemption orders has been
        // processed

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);
    }

    function testRedemptionScenario7() external {
        uint256 epoch;
        uint256 shares;

        /**
         *
         * Four users each redeem shares in differing amounts. The price is
         * updated to 100, and the redemption orders are processed. The full
         * value of the redemptions is 2 K USDC, and only half, 1 K USDC is
         * added to the contract, so the redemption are partially filled.
         *
         */

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(24))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(60e8))
        ); // currentPrice

        token.mint(address(this), 1_000e6);

        deal(address(offchainFund), address(eoa1), 10e18, true);
        deal(address(offchainFund), address(eoa2), 10e18, true);
        deal(address(offchainFund), address(eoa3), 10e18, true);
        deal(address(offchainFund), address(eoa4), 10e18, true);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 24, 2e18);

        vm.prank(eoa1);
        offchainFund.redeem(2e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa2, 24, 4e18);

        vm.prank(eoa2);
        offchainFund.redeem(4e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa3, 24, 6e18);

        vm.prank(eoa3);
        offchainFund.redeem(6e18);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa4, 24, 8e18);

        vm.prank(eoa4);
        offchainFund.redeem(8e18);

        // Check user and contract state after redemption orders have been made

        assertEq(offchainFund.balanceOf(eoa1), 8e18);
        assertEq(offchainFund.balanceOf(eoa2), 6e18);
        assertEq(offchainFund.balanceOf(eoa3), 4e18);
        assertEq(offchainFund.balanceOf(eoa4), 2e18);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 20e18);

        assertEq(usdc.balanceOf(eoa1), 0);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(usdc.balanceOf(eoa3), 0);
        assertEq(usdc.balanceOf(eoa4), 0);

        assertEq(usdc.balanceOf(address(this)), 1_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(usdc.balanceOf(address(this)), 1_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(1_000e6);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 1_000e6);

        offchainFund.update(100e8); // TODO: Use a different price

        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 20e18);

        // eoa1

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa1, 25, 1e18, 100e6, 100e8, false);

        offchainFund.processRedeem(eoa1);
        assertEq(usdc.balanceOf(eoa1), 100e6);

        assertEq(offchainFund.pendingRedemptions(), 1e18);
        assertEq(offchainFund.currentRedemptions(), 18e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa1);

        assertEq(epoch, 25);
        assertEq(shares, 1e18);

        // eoa2

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa2, 25, 2e18, 200e6, 100e8, false);

        offchainFund.processRedeem(eoa2);
        assertEq(usdc.balanceOf(eoa2), 200e6);

        assertEq(offchainFund.pendingRedemptions(), 3e18);
        assertEq(offchainFund.currentRedemptions(), 14e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa2);

        assertEq(epoch, 25);
        assertEq(shares, 2e18);

        // eoa3

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa3, 25, 3e18, 300e6, 100e8, false);

        offchainFund.processRedeem(eoa3);
        assertEq(usdc.balanceOf(eoa3), 300e6);

        assertEq(offchainFund.pendingRedemptions(), 6e18);
        assertEq(offchainFund.currentRedemptions(), 8e18);

        (epoch, shares) = offchainFund.userRedemptions(eoa3);

        assertEq(epoch, 25);
        assertEq(shares, 3e18);

        // eoa4

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(address(this), eoa4, 25, 4e18, 400e6, 100e8, false);

        offchainFund.processRedeem(eoa4);
        assertEq(usdc.balanceOf(eoa4), 400e6);

        assertEq(offchainFund.pendingRedemptions(), 10e18);
        assertEq(offchainFund.currentRedemptions(), 0);

        (epoch, shares) = offchainFund.userRedemptions(eoa4);

        assertEq(epoch, 25);
        assertEq(shares, 4e18);

        // Check final contract state after redemption orders has been
        // processed

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);
    }
}
