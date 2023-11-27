// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundAdminTest is Test {
    event Refill(address indexed, uint256 indexed, uint256);

    event Drain(address indexed, uint256 indexed, uint256, uint256);

    event Update(address indexed, uint256 indexed, uint256, uint256);

    event Deposit(address indexed, uint256 indexed, uint256);

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

        usdc.approve(address(offchainFund), type(uint256).max);
    }

    function testInitialState() external {
        assertTrue(offchainFund.hasRole(0x00, address(this)));

        assertEq(offchainFund.owner(), address(this));

        assertEq(offchainFund.cap(), 0);
        assertEq(offchainFund.min(), 1e6);

        assertEq(offchainFund.epoch(), 1);
        assertEq(offchainFund.currentPrice(), 1e8);

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.tempBurn(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.currentRedemptions(), 0);

        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
    }

    function testRefill() external {
        bytes memory encodedSelector;

        token.mint(address(this), 1_000_000e6);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        encodedSelector = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            address(this),
            address(offchainFund),
            1_000_000e6
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.refill(1_000_000e6);

        vm.clearMockedCalls();

        vm.expectEmit(true, true, true, true);
        emit Refill(address(this), 1, 1_000_000e6);

        offchainFund.refill(1_000_000e6);

        assertEq(usdc.balanceOf(address(offchainFund)), 1_000_000e6);
    }

    function testDrain() external {
        bytes memory encodedSelector;

        // initialize balances

        token.mint(address(this), 1_000_000e6);

        offchainFund.refill(1_000_000e6);

        // Check for error on failed transfer

        assertFalse(offchainFund.drained());

        encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            address(this),
            0
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.drain();

        vm.clearMockedCalls();

        // Check succesful default call with no deposits or redemptions

        assertFalse(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 1_000_000e6);

        vm.expectEmit(true, true, true, true);
        emit Drain(address(this), 1, 0, 0);

        offchainFund.drain();

        assertTrue(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 1_000_000e6);

        // Check for error on call sequence

        vm.expectRevert("price has not been updated");
        offchainFund.drain();

        // set new starting state

        vm.store(
            address(offchainFund),
            bytes32(uint256(7)),
            bytes32(uint256(0))
        ); // drained

        vm.store(
            address(offchainFund),
            bytes32(uint256(13)),
            bytes32(uint256(500_000e6))
        ); // pendingDeposits

        vm.store(
            address(offchainFund),
            bytes32(uint256(16)),
            bytes32(uint256(10_000e18))
        ); // pendingRedemptions

        // Check for error on failed transfer

        encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            address(this),
            500_000e6
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.drain();

        vm.clearMockedCalls();

        // Check succesful state change no deposits and redemptions

        assertFalse(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.pendingDeposits(), 500_000e6);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 10_000e18);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 1_000_000e6);

        vm.expectEmit(true, true, true, true);
        emit Drain(address(this), 1, 500_000e6, 10_000e18);

        offchainFund.drain();

        assertTrue(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), 500_000e6);
        assertEq(offchainFund.pendingDeposits(), 0);

        assertEq(offchainFund.currentRedemptions(), 10_000e18);
        assertEq(offchainFund.pendingRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 500_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 500_000e6);
    }

    function testUpdate() external {
        vm.expectRevert("price can not be set to 0");
        offchainFund.update(0);

        assertFalse(offchainFund.drained());

        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(100e8);

        vm.store(
            address(offchainFund),
            bytes32(uint256(7)),
            bytes32(uint256(1))
        ); // drained

        vm.store(
            address(offchainFund),
            bytes32(uint256(20)),
            bytes32(uint256(2))
        ); // currentDepositCount

        vm.expectRevert("deposits have not been fully processed");
        offchainFund.update(100e8);

        vm.store(
            address(offchainFund),
            bytes32(uint256(14)),
            bytes32(uint256(1_000e6))
        ); // currentDeposits

        vm.store(
            address(offchainFund),
            bytes32(uint256(18)),
            bytes32(uint256(2))
        ); // preDrainDepositCount

        vm.store(
            address(offchainFund),
            bytes32(uint256(20)),
            bytes32(uint256(0))
        ); // currentDepositCount

        assertTrue(offchainFund.drained());
        assertEq(offchainFund.currentPrice(), 1e8);

        // assertEq(offchainFund.pendingDepositCount(), 2);
        assertEq(offchainFund.currentDepositCount(), 0);

        assertEq(offchainFund.epoch(), 1);

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.currentDeposits(), 1_000e6);

        vm.expectEmit(true, true, true, true);
        emit Update(address(this), 2, 100e8, 10e18);

        offchainFund.update(100e8);

        assertFalse(offchainFund.drained());
        assertEq(offchainFund.currentPrice(), 100e8);

        // assertEq(offchainFund.pendingDepositCount(), 0);
        assertEq(offchainFund.currentDepositCount(), 2);

        assertEq(offchainFund.epoch(), 2);

        assertEq(offchainFund.tempMint(), 10e18);
        assertEq(offchainFund.currentDeposits(), 1_000e6);
    }

    function testWhitelist() external {
        address eoa1 = vm.addr(1);
        address eoa2 = vm.addr(2);
        address eoa3 = vm.addr(3);
        address eoa4 = vm.addr(4);

        deal(address(offchainFund), address(eoa1), 1e18, true);
        deal(address(offchainFund), address(eoa2), 1e18, true);
        deal(address(offchainFund), address(eoa3), 1e18, true);

        assertFalse(offchainFund.isWhitelisted(eoa1));
        assertFalse(offchainFund.isWhitelisted(eoa2));
        assertFalse(offchainFund.isWhitelisted(eoa3));

        vm.expectRevert("receiver address is not in the whitelist");

        vm.prank(eoa1);
        offchainFund.transfer(eoa2, 1e18);

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);

        vm.expectRevert("sender address is not in the whitelist");

        vm.prank(eoa3);
        offchainFund.transfer(eoa1, 1e18);

        vm.expectRevert("receiver address is not in the whitelist");

        vm.prank(eoa1);
        offchainFund.transfer(address(this), 1e18);

        vm.prank(eoa1);
        offchainFund.transfer(eoa2, 1e18);

        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 2e18);
        assertEq(offchainFund.balanceOf(eoa3), 1e18);

        assertTrue(offchainFund.isWhitelisted(eoa1));
        assertTrue(offchainFund.isWhitelisted(eoa2));
        assertFalse(offchainFund.isWhitelisted(eoa3));

        offchainFund.removeFromWhitelist(eoa2);

        assertTrue(offchainFund.isWhitelisted(eoa1));
        assertFalse(offchainFund.isWhitelisted(eoa2));
        assertFalse(offchainFund.isWhitelisted(eoa3));

        offchainFund.grantRole(0x00, eoa4);
        offchainFund.renounceRole(0x00, address(this));

        assertTrue(offchainFund.hasRole(0x00, eoa4));
        assertFalse(offchainFund.hasRole(0x00, address(this)));

        vm.expectRevert();
        offchainFund.addToWhitelist(eoa3);

        vm.expectRevert();
        offchainFund.removeFromWhitelist(eoa1);

        vm.prank(eoa4);
        offchainFund.addToWhitelist(eoa3);

        vm.prank(eoa4);
        offchainFund.removeFromWhitelist(eoa1);

        assertFalse(offchainFund.isWhitelisted(eoa1));
        assertFalse(offchainFund.isWhitelisted(eoa2));
        assertTrue(offchainFund.isWhitelisted(eoa3));
    }

    function testDepositRestrictions() external {
        offchainFund.addToWhitelist(address(this));

        token.mint(address(this), 100e6);

        vm.expectRevert("deposit would exceed epoch cap");
        offchainFund.deposit(2e6);

        offchainFund.adjustCap(10e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), 1, 2e6);

        offchainFund.deposit(2e6);

        vm.expectRevert("deposit is less than the minimum");
        offchainFund.deposit(0.01e6);

        offchainFund.adjustMin(0.001e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(address(this), 1, 0.01e6);

        offchainFund.deposit(0.01e6);
    }
}
