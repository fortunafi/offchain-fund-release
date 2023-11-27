// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminInitialStateTest is OffchainFundAdminTest {
    function testInitialState(address _eoa) external {
        vm.assume(_eoa != address(this));

        assertEq(address(offchainFund.usdc()), address(usdc));
        assertEq(offchainFund.drained(), false);

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

        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertTrue(offchainFund.hasRole(0x00, address(this)));
        assertEq(offchainFund.owner(), address(this));

        assertFalse(offchainFund.hasRole(0x00, _eoa));

        (uint256 epoch0, uint256 assets0) = offchainFund.userDeposits(_eoa);
        assertEq(epoch0, 0);
        assertEq(assets0, 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(_eoa);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);
    }
}
