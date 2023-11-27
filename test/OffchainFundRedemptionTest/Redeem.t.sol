// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundRedeemTest is OffchainFundRedemptionTest {
    function testRedeemEventEmitted(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndProcess(eoa1, _amount);

        uint256 shares = offchainFund.balanceOf(eoa1);

        vm.expectEmit(true, true, true, true);
        emit Redeem(eoa1, 2, shares);
        vm.prank(eoa1);
        offchainFund.redeem(shares);
    }

    function testRedeemFromDifferentEOAsPreDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());

        _depositAndProcess(eoa1, _amount1);
        _depositAndProcess(eoa2, _amount2);
        _depositAndProcess(eoa3, _amount3);

        uint256 shares1 = offchainFund.balanceOf(eoa1);
        uint256 shares2 = offchainFund.balanceOf(eoa2);
        uint256 shares3 = offchainFund.balanceOf(eoa3);

        uint256 redemptionEpoch = offchainFund.epoch();

        vm.prank(eoa1);
        offchainFund.redeem(shares1);

        assertEq(offchainFund.pendingRedemptions(), shares1);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), shares2);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.totalSupply(), shares2 + shares3);

        vm.prank(eoa2);
        offchainFund.redeem(shares2);

        assertEq(offchainFund.pendingRedemptions(), shares1 + shares2);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.totalSupply(), shares3);

        vm.prank(eoa3);
        offchainFund.redeem(shares3);

        assertEq(
            offchainFund.pendingRedemptions(),
            shares1 + shares2 + shares3
        );
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.totalSupply(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, redemptionEpoch);
        assertEq(assets1, shares1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, redemptionEpoch);
        assertEq(assets2, shares2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userRedemptions(eoa3);
        assertEq(epoch3, redemptionEpoch);
        assertEq(assets3, shares3);
    }

    function testRedeemFromDifferentEOAsPostDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());

        _depositAndProcess(eoa1, _amount1);
        _depositAndProcess(eoa2, _amount2);
        _depositAndProcess(eoa3, _amount3);

        offchainFund.drain();

        uint256 shares1 = offchainFund.balanceOf(eoa1);
        uint256 shares2 = offchainFund.balanceOf(eoa2);
        uint256 shares3 = offchainFund.balanceOf(eoa3);

        uint256 redemptionEpoch = offchainFund.epoch();

        vm.prank(eoa1);
        offchainFund.redeem(shares1);

        assertEq(offchainFund.pendingRedemptions(), shares1);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), shares2);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.totalSupply(), shares2 + shares3);

        vm.prank(eoa2);
        offchainFund.redeem(shares2);

        assertEq(offchainFund.pendingRedemptions(), shares1 + shares2);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.totalSupply(), shares3);

        vm.prank(eoa3);
        offchainFund.redeem(shares3);

        assertEq(
            offchainFund.pendingRedemptions(),
            shares1 + shares2 + shares3
        );
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.totalSupply(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, redemptionEpoch + 1);
        assertEq(assets1, shares1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, redemptionEpoch + 1);
        assertEq(assets2, shares2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userRedemptions(eoa3);
        assertEq(epoch3, redemptionEpoch + 1);
        assertEq(assets3, shares3);
    }

    function testRedeemFromDifferentEOAsPreAndPostDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3,
        uint40 _amount4
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());
        vm.assume(_amount4 > offchainFund.min());

        _depositAndProcess(eoa1, _amount1);
        _depositAndProcess(eoa2, _amount2);
        _depositAndProcess(eoa3, _amount3);
        _depositAndProcess(eoa4, _amount4);

        uint256 shares1 = offchainFund.balanceOf(eoa1);
        uint256 shares2 = offchainFund.balanceOf(eoa2);
        uint256 shares3 = offchainFund.balanceOf(eoa3);
        uint256 shares4 = offchainFund.balanceOf(eoa4);

        uint256 redemptionEpoch = offchainFund.epoch();

        vm.prank(eoa1);
        offchainFund.redeem(shares1);

        assertEq(offchainFund.pendingRedemptions(), shares1);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), shares2);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.balanceOf(eoa4), shares4);
        assertEq(offchainFund.totalSupply(), shares2 + shares3 + shares4);

        vm.prank(eoa2);
        offchainFund.redeem(shares2);

        assertEq(offchainFund.pendingRedemptions(), shares1 + shares2);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), shares3);
        assertEq(offchainFund.balanceOf(eoa4), shares4);
        assertEq(offchainFund.totalSupply(), shares3 + shares4);

        offchainFund.drain();

        vm.prank(eoa3);
        offchainFund.redeem(shares3);

        assertEq(offchainFund.pendingRedemptions(), shares3);
        assertEq(offchainFund.currentRedemptions(), shares1 + shares2);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), shares4);
        assertEq(offchainFund.totalSupply(), shares4);

        vm.prank(eoa4);
        offchainFund.redeem(shares4);

        assertEq(offchainFund.pendingRedemptions(), shares3 + shares4);
        assertEq(offchainFund.currentRedemptions(), shares1 + shares2);
        assertEq(offchainFund.balanceOf(eoa1), 0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.balanceOf(eoa3), 0);
        assertEq(offchainFund.balanceOf(eoa4), 0);
        assertEq(offchainFund.totalSupply(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, redemptionEpoch);
        assertEq(assets1, shares1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, redemptionEpoch);
        assertEq(assets2, shares2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userRedemptions(eoa3);
        assertEq(epoch3, redemptionEpoch + 1);
        assertEq(assets3, shares3);

        (uint256 epoch4, uint256 assets4) = offchainFund.userRedemptions(eoa4);
        assertEq(epoch4, redemptionEpoch + 1);
        assertEq(assets4, shares4);
    }

    function testRedeemFromSameEOAPreDrain(
        uint40 _amount, // With uint40, we don't worry about the cap or overflow
        uint8 _timesRedeemed
    ) public {
        vm.assume(_amount > offchainFund.min());
        vm.assume(_timesRedeemed < 6); // to make tests fast

        _depositAndProcess(eoa1, _amount);

        uint256 shares = offchainFund.balanceOf(eoa1);

        uint256 redemptionEpoch = offchainFund.epoch();

        uint256 totalRedemption;

        for (uint i; i < _timesRedeemed; i++) {
            uint256 amountToRedeem = shares / _timesRedeemed;
            vm.prank(eoa1);
            offchainFund.redeem(amountToRedeem);

            totalRedemption += amountToRedeem;

            assertEq(offchainFund.pendingRedemptions(), totalRedemption);
            assertEq(offchainFund.balanceOf(eoa1), shares - totalRedemption);
            assertEq(offchainFund.totalSupply(), shares - totalRedemption);

            (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(
                eoa1
            );
            assertEq(epoch, redemptionEpoch);
            assertEq(assets, totalRedemption);
        }
    }

    function testRedeemFromSameEOAPostDrain(
        uint40 _amount, // With uint40, we don't worry about the cap or overflow
        uint8 _timesRedeemed
    ) public {
        vm.assume(_amount > offchainFund.min());
        vm.assume(_timesRedeemed < 6); // to make tests fast

        _depositAndProcess(eoa1, _amount);

        offchainFund.drain();

        uint256 shares = offchainFund.balanceOf(eoa1);

        uint256 redemptionEpoch = offchainFund.epoch();

        uint256 totalRedemption;

        for (uint i; i < _timesRedeemed; i++) {
            uint256 amountToRedeem = shares / _timesRedeemed;
            vm.prank(eoa1);
            offchainFund.redeem(amountToRedeem);

            totalRedemption += amountToRedeem;

            assertEq(offchainFund.pendingRedemptions(), totalRedemption);
            assertEq(offchainFund.balanceOf(eoa1), shares - totalRedemption);
            assertEq(offchainFund.totalSupply(), shares - totalRedemption);

            (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(
                eoa1
            );
            assertEq(epoch, redemptionEpoch + 1);
            assertEq(assets, totalRedemption);
        }
    }

    function testRedeemWithUnprocessedRedemptions(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndProcess(eoa1, _amount);

        uint256 shares = offchainFund.balanceOf(eoa1);

        vm.prank(eoa1);
        offchainFund.redeem(shares / 2);

        offchainFund.drain();
        offchainFund.update(1e6);

        vm.expectRevert("user has unprocessed redemptions");
        vm.prank(eoa1);
        offchainFund.redeem(shares / 2);
    }

    function testRedeemWithMoreSharesThanAvailable(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndProcess(eoa1, _amount);

        uint256 shares = offchainFund.balanceOf(eoa1);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(eoa1);
        offchainFund.redeem(shares + 1);
    }

    function testRedeeumUnauthorized(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndProcess(eoa1, _amount);

        vm.expectRevert();
        offchainFund.redeem(_amount);
    }
}
