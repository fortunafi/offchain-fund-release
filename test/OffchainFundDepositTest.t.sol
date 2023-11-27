// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundDepositTest is Test {
    event Deposit(address indexed, uint256 indexed, uint256);

    event ProcessDeposit(
        address indexed,
        address indexed,
        uint256 indexed,
        uint256,
        uint256,
        uint256
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

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);
        offchainFund.addToWhitelist(eoa3);
        offchainFund.addToWhitelist(eoa4);
        offchainFund.addToWhitelist(eoa5);
        offchainFund.addToWhitelist(eoa6);

        offchainFund.adjustCap(type(uint256).max);
    }

    function testDepositScenario1() external {
        bool valid;
        string memory message;

        uint256 epoch;
        uint256 assets;

        /**
         *
         * Four users deposit differing amounts before and after actions taken
         * by the contract owner. Success and failure is verified against the
         * changing contract state.
         *
         */

        token.mint(eoa1, 8_000e6);
        token.mint(eoa2, 8_000e6);
        token.mint(eoa3, 8_000e6);
        token.mint(eoa4, 8_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa1, 1, 2_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(2_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa2, 1, 4_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(4_000e6);

        // Check user and contract state after deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 6_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 6_000e6);

        // eoa1

        (epoch, assets) = offchainFund.userDeposits(eoa1);

        assertEq(epoch, 1);
        assertEq(assets, 2_000e6);

        (valid, message) = offchainFund.canProcessDeposit(eoa1);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for mint");

        // eoa2

        (epoch, assets) = offchainFund.userDeposits(eoa2);

        assertEq(epoch, 1);
        assertEq(assets, 4_000e6);

        (valid, message) = offchainFund.canProcessDeposit(eoa2);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for mint");

        // eoa3

        (epoch, assets) = offchainFund.userDeposits(eoa3);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        (valid, message) = offchainFund.canProcessDeposit(eoa3);

        assertFalse(valid);
        assertEq(message, "account has no mint order");

        // eo4

        (epoch, assets) = offchainFund.userDeposits(eoa4);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        (valid, message) = offchainFund.canProcessDeposit(eoa4);

        assertFalse(valid);
        assertEq(message, "account has no mint order");

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 6_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 6_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Check constraint to add after drain and before process

        // eoa1

        vm.expectRevert("can not add to deposit after drain");

        vm.prank(eoa1);
        offchainFund.deposit(1_000e6);

        // eoa2

        vm.expectRevert("can not add to deposit after drain");

        vm.prank(eoa2);
        offchainFund.deposit(1_000e6);

        // eoa3

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa3, 1, 1_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(1_000e6);

        (epoch, assets) = offchainFund.userDeposits(eoa3);

        assertEq(epoch, 2);
        assertEq(assets, 1_000e6);

        // eo4

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa4, 1, 1_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(1_000e6);

        (epoch, assets) = offchainFund.userDeposits(eoa4);

        assertEq(epoch, 2);
        assertEq(assets, 1_000e6);

        // Check user and contract state after deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 2_000e6);
        assertEq(offchainFund.currentDeposits(), 6_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 2);

        assertEq(usdc.balanceOf(address(this)), 6_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 2_000e6);

        // Price is set to 20

        offchainFund.update(20e8);

        assertEq(offchainFund.tempMint(), 300e18);
        assertEq(offchainFund.pendingDeposits(), 2_000e6);
        assertEq(offchainFund.currentDeposits(), 6_000e6);

        assertEq(offchainFund.currentDepositCount(), 2);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        // assertEq(usdc.balanceOf(address(this)), 6_000e6);
        // assertEq(usdc.balanceOf(address(offchainFund)), 2_000e6);

        vm.expectRevert("user has unprocessed userDeposits");

        vm.prank(eoa1);
        offchainFund.deposit(1_000e6);

        vm.expectRevert("user has unprocessed userDeposits");

        vm.prank(eoa2);
        offchainFund.deposit(1_000e6);
    }

    function testDepositScenario2() external {
        bytes memory encodedSelector;

        /**
         *
         * Two users out of three deposit 100 K USDC at the initial contract
         * state. The price is updated to 20. Each user who has an active
         * subscription is then rejected on any additional deposits before they
         * are processed. Furthermore, an additional error state is checked for
         * the third user.
         *
         */

        token.mint(eoa1, 100_000e6);
        token.mint(eoa2, 100_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa1, 1, 100_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa2, 1, 100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        // Check user and contract state after deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 200_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 200_000e6);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 200_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Price is set to 20

        offchainFund.update(20e8);

        assertEq(offchainFund.tempMint(), 10_000e18);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 200_000e6);

        assertEq(offchainFund.currentDepositCount(), 2);
        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        // eoa1

        vm.expectRevert("user has unprocessed userDeposits");

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        // eoa2

        vm.expectRevert("user has unprocessed userDeposits");

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        // Check `deposit` call fails if token transfer returns false

        encodedSelector = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            eoa3,
            address(offchainFund),
            100_000e6
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        // eoa3

        vm.expectRevert(stdError.assertionError);

        vm.prank(eoa3);
        offchainFund.deposit(100_000e6);

        vm.clearMockedCalls();
    }

    function testDepositScenario3() external {
        bool valid;
        string memory message;

        /**
         *
         * Four users deposit stablecoin capital to receive fund shares. Two
         * before the call to drain and two after.
         *
         */

        token.mint(eoa1, 150_000e6);
        token.mint(eoa2, 150_000e6);
        token.mint(eoa3, 150_000e6);
        token.mint(eoa4, 150_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa1, 1, 100_000e6);

        vm.prank(eoa1);
        offchainFund.deposit(100_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa2, 1, 100_000e6);

        vm.prank(eoa2);
        offchainFund.deposit(100_000e6);

        // Check user and contract state after deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 200_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 200_000e6);

        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), 0);

        assertEq(usdc.balanceOf(address(eoa1)), 50_000e6);
        assertEq(usdc.balanceOf(address(eoa2)), 50_000e6);
        assertEq(usdc.balanceOf(address(eoa3)), 150_000e6);
        assertEq(usdc.balanceOf(address(eoa4)), 150_000e6);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa1);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa2);

        vm.expectRevert("account has no mint order");
        offchainFund.processDeposit(eoa3);

        vm.expectRevert("account has no mint order");
        offchainFund.processDeposit(eoa4);

        // Contract must be drained before price can update

        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(100e8);

        // All user deposits are removed from the contract

        offchainFund.drain();

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa3, 1, 50_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(50_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa4, 1, 50_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(50_000e6);

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 100_000e6);
        assertEq(offchainFund.currentDeposits(), 200_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 2);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 100_000e6);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 200_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 100_000e6);

        // Check constraint to add after drain and before process

        vm.expectRevert("can not add to deposit after drain");

        vm.prank(eoa1);
        offchainFund.deposit(50_000e6);

        vm.expectRevert("can not add to deposit after drain");

        vm.prank(eoa2);
        offchainFund.deposit(50_000e6);

        // Price is set to 100

        offchainFund.update(100e8);

        assertEq(offchainFund.tempMint(), 2_000e18);
        assertEq(offchainFund.pendingDeposits(), 100_000e6);
        assertEq(offchainFund.currentDeposits(), 200_000e6);

        assertEq(offchainFund.currentDepositCount(), 2);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        // eoa1

        (valid, message) = offchainFund.canProcessDeposit(eoa1);

        assertTrue(valid);
        assertEq(message, "");

        // eoa2

        (valid, message) = offchainFund.canProcessDeposit(eoa2);

        assertTrue(valid);
        assertEq(message, "");

        // eoa3

        (valid, message) = offchainFund.canProcessDeposit(eoa3);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for mint");

        // eo4

        (valid, message) = offchainFund.canProcessDeposit(eoa4);

        assertFalse(valid);
        assertEq(message, "nav has not been updated for mint");

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa1, 2, 1_000e18, 100_000e6, 100e8);

        offchainFund.processDeposit(eoa1);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa2, 2, 1_000e18, 100_000e6, 100e8);

        offchainFund.processDeposit(eoa2);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa3);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa4);

        // Check user and contract state after processing all deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 100_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(offchainFund.balanceOf(eoa1), 1_000e18);
        assertEq(offchainFund.balanceOf(eoa2), 1_000e18);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), 0);

        // All user deposits are removed from the contract

        offchainFund.drain();

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 100_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 300_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 300_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Price is set to 120

        offchainFund.update(160e8);

        assertEq(offchainFund.tempMint(), 625e18);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 100_000e6);

        assertEq(offchainFund.currentDepositCount(), 2);
        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        // eoa1

        (valid, message) = offchainFund.canProcessDeposit(eoa1);

        assertFalse(valid);
        assertEq(message, "account has no mint order");

        // eoa2

        (valid, message) = offchainFund.canProcessDeposit(eoa2);

        assertFalse(valid);
        assertEq(message, "account has no mint order");

        // eoa3

        (valid, message) = offchainFund.canProcessDeposit(eoa3);

        assertTrue(valid);
        assertEq(message, "");

        // eo4

        (valid, message) = offchainFund.canProcessDeposit(eoa4);

        assertTrue(valid);
        assertEq(message, "");

        vm.expectRevert("account has no mint order");
        offchainFund.processDeposit(eoa1);

        vm.expectRevert("account has no mint order");
        offchainFund.processDeposit(eoa2);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa3, 3, 312.5e18, 50_000e6, 160e8);

        offchainFund.processDeposit(eoa3);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa4, 3, 312.5e18, 50_000e6, 160e8);

        offchainFund.processDeposit(eoa4);

        // Check user and contract state after processing all deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(offchainFund.balanceOf(eoa1), 1_000e18);
        assertEq(offchainFund.balanceOf(eoa2), 1_000e18);
        assertEq(offchainFund.balanceOf(eoa3), 312.5e18);
        assertEq(offchainFund.balanceOf(eoa4), 312.5e18);
    }

    function testDepositScenario4() external {
        uint256 epoch;
        uint256 assets;

        /**
         * Four users deposit stablecoin capital to receive fund shares. The
         * first account does so before the call to `drain` and next two after,
         * after. And the third makes their deposit before the previous two are
         * processed.
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

        deal(address(offchainFund), address(eoa1), 100e18, true);
        deal(address(offchainFund), address(eoa2), 100e18, true);

        token.mint(eoa3, 4_000e6);
        token.mint(eoa4, 4_000e6);
        token.mint(eoa5, 4_000e6);
        token.mint(eoa6, 4_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa3, 12, 4_000e6);

        vm.prank(eoa3);
        offchainFund.deposit(4_000e6);

        // Check user and contract state after deposits

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 4_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 1);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), 4_000e6);

        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), 0);
        assertEq(offchainFund.balanceOf(eoa5), 0);
        assertEq(offchainFund.balanceOf(eoa6), 0);

        assertEq(usdc.balanceOf(address(eoa3)), 0);
        assertEq(usdc.balanceOf(address(eoa4)), 4_000e6);
        assertEq(usdc.balanceOf(address(eoa5)), 4_000e6);
        assertEq(usdc.balanceOf(address(eoa6)), 4_000e6);

        // eoa3

        (epoch, assets) = offchainFund.userDeposits(eoa3);

        assertEq(epoch, 12);
        assertEq(assets, 4_000e6);

        // eoa4

        (epoch, assets) = offchainFund.userDeposits(eoa4);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        // eoa5

        (epoch, assets) = offchainFund.userDeposits(eoa5);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        // eoa6

        (epoch, assets) = offchainFund.userDeposits(eoa6);

        assertEq(epoch, 0);
        assertEq(assets, 0);

        // Contract must be drained before price can update

        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(80e8);

        // All user deposits are removed from the contract

        offchainFund.drain();

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa4, 12, 2_000e6);

        vm.prank(eoa4);
        offchainFund.deposit(2_000e6);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa5, 12, 4_000e6);

        vm.prank(eoa5);
        offchainFund.deposit(4_000e6);

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 6_000e6);
        assertEq(offchainFund.currentDeposits(), 4_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 1);
        assertEq(offchainFund.postDrainDepositCount(), 2);

        assertEq(usdc.balanceOf(address(this)), 4_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 6_000e6);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 4_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 6_000e6);

        // Price is set to 80

        offchainFund.update(80e8);

        assertEq(offchainFund.tempMint(), 50e18);
        assertEq(offchainFund.pendingDeposits(), 6_000e6);
        assertEq(offchainFund.currentDeposits(), 4_000e6);

        assertEq(offchainFund.currentDepositCount(), 1);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa3, 13, 50e18, 4_000e6, 80e8);

        offchainFund.processDeposit(eoa3);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa4);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa5);

        vm.expectRevert("account has no mint order");
        offchainFund.processDeposit(eoa6);

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 6_000e6);
        assertEq(offchainFund.currentDeposits(), 0);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(offchainFund.balanceOf(eoa3), 50e18);
        assertEq(offchainFund.balanceOf(eoa4), 0);
        assertEq(offchainFund.balanceOf(eoa5), 0);
        assertEq(offchainFund.balanceOf(eoa6), 0);

        offchainFund.drain();

        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);
        assertEq(offchainFund.currentDeposits(), 6_000e6);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(usdc.balanceOf(address(this)), 10_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        offchainFund.refill(0);

        assertEq(usdc.balanceOf(address(this)), 10_000e6);
        assertEq(usdc.balanceOf(address(offchainFund)), 0);

        // Price is set to 80

        offchainFund.update(125e8);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa6, 14, 1_000e6);

        vm.prank(eoa6);
        offchainFund.deposit(1_000e6);

        assertEq(offchainFund.tempMint(), 48e18);
        assertEq(offchainFund.pendingDeposits(), 1_000e6);
        assertEq(offchainFund.currentDeposits(), 6_000e6);

        assertEq(offchainFund.currentDepositCount(), 2);
        assertEq(offchainFund.preDrainDepositCount(), 1);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa4, 14, 16e18, 2_000e6, 125e8);

        offchainFund.processDeposit(eoa4);

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(address(this), eoa5, 14, 32e18, 4_000e6, 125e8);

        offchainFund.processDeposit(eoa5);

        assertEq(offchainFund.balanceOf(eoa3), 50e18);
        assertEq(offchainFund.balanceOf(eoa4), 16e18);
        assertEq(offchainFund.balanceOf(eoa5), 32e18);
        assertEq(offchainFund.balanceOf(eoa6), 0);
    }
}
