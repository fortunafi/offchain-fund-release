// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminDrainTest is OffchainFundAdminTest {
    function testDrainEventEmitted(
        uint256 _epoch,
        uint256 _pendingDeposits,
        uint256 _pendingRedemptions
    ) public {
        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(_epoch))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(13)),
            bytes32(uint256(_pendingDeposits))
        ); // pendingDeposits

        vm.store(
            address(offchainFund),
            bytes32(uint256(16)),
            bytes32(uint256(_pendingRedemptions))
        ); // pendingRedemptions

        token.mint(address(offchainFund), _pendingDeposits);

        vm.expectEmit(true, true, true, true);
        emit Drain(
            address(this),
            _epoch,
            _pendingDeposits,
            _pendingRedemptions
        );
        offchainFund.drain();
    }

    function testDrainWithNoDepositsAndRedemptions(uint256 _amount) public {
        token.mint(address(this), _amount);
        usdc.approve(address(offchainFund), _amount);
        offchainFund.refill(_amount);

        offchainFund.drain();

        assertTrue(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.pendingDeposits(), 0);

        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), _amount);
    }

    function testDrainWithDepositsAndRedemptions(
        uint256 _refillAmount,
        uint256 _pendingDeposits,
        uint256 _pendingRedemptions
    ) external {
        vm.assume(_pendingDeposits > 0 && _pendingDeposits < _refillAmount);

        usdc.approve(address(offchainFund), type(uint256).max);

        token.mint(address(this), _refillAmount);

        offchainFund.refill(_refillAmount);

        vm.store(
            address(offchainFund),
            bytes32(uint256(7)),
            bytes32(uint256(0))
        ); // drained

        vm.store(
            address(offchainFund),
            bytes32(uint256(13)),
            bytes32(uint256(_pendingDeposits))
        ); // pendingDeposits

        vm.store(
            address(offchainFund),
            bytes32(uint256(16)),
            bytes32(uint256(_pendingRedemptions))
        ); // pendingRedemptions

        offchainFund.drain();

        assertTrue(offchainFund.drained());

        assertEq(offchainFund.currentDeposits(), _pendingDeposits);
        assertEq(offchainFund.pendingDeposits(), 0);

        assertEq(offchainFund.currentRedemptions(), _pendingRedemptions);
        assertEq(offchainFund.pendingRedemptions(), 0);

        assertEq(usdc.balanceOf(address(this)), _pendingDeposits);
        assertEq(
            usdc.balanceOf(address(offchainFund)),
            _refillAmount - _pendingDeposits
        );
    }

    function testDrainOnDrainedState() public {
        vm.store(
            address(offchainFund),
            bytes32(uint256(7)),
            bytes32(uint256(1))
        ); // drained
        vm.expectRevert("price has not been updated");
        offchainFund.drain();
    }

    function testDrainOnInsufficientTransfer(uint256 _pendingDeposits) public {
        vm.assume(_pendingDeposits > 0);

        vm.store(
            address(offchainFund),
            bytes32(uint256(13)),
            bytes32(uint256(_pendingDeposits))
        ); // pendingDeposits

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        offchainFund.drain();
    }

    function testDrainOnMockedTransferFail() public {
        bytes memory encodedSelector;

        encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            address(this),
            0
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.drain();

        vm.clearMockedCalls();
    }

    function testDrainAsNonOwner(address _eoa) public {
        vm.assume(_eoa != address(this));
        vm.prank(_eoa);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.drain();
    }
}
