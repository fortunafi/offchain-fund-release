// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundProcessRedeemTest is OffchainFundRedemptionTest {
    address[] public eoas;
    uint256[] public amounts;

    function testProcessRedeemEvent(
        uint256 _amount,
        bool _isRemovedFromWhitelist
    ) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        uint256 shares = _depositAndOrderRedeem(eoa1, _amount, true);

        offchainFund.drain();
        _refill(_amount);
        offchainFund.update(1e8);

        address recipient = eoa1;

        if (_isRemovedFromWhitelist) {
            offchainFund.removeFromWhitelist(eoa1);
            offchainFund.addToWhitelist(offchainFund.owner());
            recipient = offchainFund.owner();
        }

        vm.expectEmit(true, true, true, true);
        emit ProcessRedeem(
            address(this),
            recipient,
            offchainFund.epoch(),
            shares,
            _amount,
            offchainFund.currentPrice(),
            true
        );
        offchainFund.processRedeem(eoa1);
    }

    function testProcessPreDrainRedeemAfterEpochFully(
        uint256 _amount,
        uint8 _priceIncrease, // new price = old price * _priceIncrease
        bool _isRemovedFromWhitelist
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, true);

        offchainFund.drain();
        _refill(_amount * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);

        address recipient = eoa1;

        if (_isRemovedFromWhitelist) {
            offchainFund.removeFromWhitelist(eoa1);
            offchainFund.addToWhitelist(offchainFund.owner());
            recipient = offchainFund.owner();
        }

        offchainFund.processRedeem(eoa1);

        if (_isRemovedFromWhitelist) {
            assertEq(offchainFund.owner(), recipient);
            assertEq(
                usdc.balanceOf(recipient),
                _amount * _priceIncrease + _amount // Considering the drained funds
            );
            assertEq(usdc.balanceOf(eoa1), 0);
        } else {
            assertEq(eoa1, recipient);
            assertEq(usdc.balanceOf(recipient), _amount * _priceIncrease);
            assertEq(
                usdc.balanceOf(offchainFund.owner()),
                _amount // Considering the drained funds
            );
        }

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(offchainFund.currentRedemptions(), 0);

        (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch, 0);
        assertEq(assets, 0);
    }

    function testProcessPreDrainRedeemAfterEpochPartially(
        uint256 _amount,
        uint8 _priceIncrease, // new price = old price * _priceIncrease
        uint8 k, // Between 1-9. If 2, user first will get partial 20% USDC back due to lack of funds in contract and 80% later.
        bool _isRemovedFromWhitelist
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(k > 0 && k < 10);
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, true);

        offchainFund.drain();
        _refill(((_amount * k) / 10) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);

        address recipient = eoa1;

        if (_isRemovedFromWhitelist) {
            offchainFund.removeFromWhitelist(eoa1);
            offchainFund.addToWhitelist(offchainFund.owner());
            recipient = offchainFund.owner();
        }

        offchainFund.processRedeem(eoa1);

        uint256 userPendingRedemptions = (_amount - ((_amount * k) / 10)) *
            1e12;

        if (_isRemovedFromWhitelist) {
            assertEq(offchainFund.owner(), recipient);
            assertEq(
                usdc.balanceOf(recipient),
                ((_amount * k) / 10) * _priceIncrease + _amount // Considering the drained funds
            );
            assertEq(usdc.balanceOf(eoa1), 0);
        } else {
            assertEq(eoa1, recipient);
            assertEq(
                usdc.balanceOf(eoa1),
                ((_amount * k) / 10) * _priceIncrease
            );
            assertEq(
                usdc.balanceOf(offchainFund.owner()),
                _amount // Considering the drained funds
            );
        }

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), userPendingRedemptions);

        (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch, offchainFund.epoch());
        assertEq(assets, userPendingRedemptions);

        offchainFund.drain();
        // Refill Remaining funds to fully process the redeem
        _refill((_amount - ((_amount * k) / 10)) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease); // We will leave the price same

        offchainFund.processRedeem(eoa1);

        if (_isRemovedFromWhitelist) {
            assertEq(offchainFund.owner(), recipient);
            assertEq(
                usdc.balanceOf(recipient),
                _amount * _priceIncrease + _amount // Considering the drained funds
            );
            assertEq(usdc.balanceOf(eoa1), 0);
        } else {
            assertEq(eoa1, recipient);
            assertEq(usdc.balanceOf(eoa1), _amount * _priceIncrease);
            assertEq(
                usdc.balanceOf(offchainFund.owner()),
                _amount // Considering the drained funds
            );
        }

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);
    }

    function testProcessPostDrainRedeemAfterEpoch(
        uint256 _amount,
        uint8 _priceIncrease // new price = old price * _priceIncrease
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, false);

        _refill(_amount * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);

        vm.expectRevert("nav has not been updated for redeem");
        offchainFund.processRedeem(eoa1);
    }

    function testProcessPostDrainRedeemAfter2EpochsFully(
        uint256 _amount,
        uint8 _priceIncrease // new price = old price * _priceIncrease
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, false);

        _refill(_amount * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);
        offchainFund.drain();
        offchainFund.update(1e8 * _priceIncrease);

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), _amount * _priceIncrease);
        assertEq(offchainFund.currentRedemptions(), 0);

        (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch, 0);
        assertEq(assets, 0);
    }

    function testProcessPostDrainRedeemAfter2EpochsPartially(
        uint256 _amount,
        uint8 _priceIncrease, // new price = old price * _priceIncrease
        uint8 k // Between 1-9. If 2, user first will get partial 20% USDC back due to lack of funds in contract and 80% later.
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(k > 0 && k < 10);
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, false);

        _refill(((_amount * k) / 10) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);
        offchainFund.drain();
        offchainFund.update(1e8 * _priceIncrease);

        offchainFund.processRedeem(eoa1);

        uint256 userPendingRedemptions = (_amount - ((_amount * k) / 10)) *
            1e12;

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), ((_amount * k) / 10) * _priceIncrease);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), userPendingRedemptions);

        (uint256 epoch, uint256 assets) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch, offchainFund.epoch());
        assertEq(assets, userPendingRedemptions);

        offchainFund.drain();
        // Refill Remaining funds to fully process the redeem
        _refill((_amount - ((_amount * k) / 10)) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease); // We will leave the price same

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), _amount * _priceIncrease);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);
    }

    function testProcessPreDrainRedeemsAfterEpochFully(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint8 _priceIncrease // new price = old price * _priceIncrease
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(
            _amount1 > offchainFund.min() && _amount2 > offchainFund.min()
        );

        uint256 amount1 = uint256(_amount1);
        uint256 amount2 = uint256(_amount2);

        _depositAndOrderRedeem(eoa1, amount1, true);
        uint256 shares2 = _depositAndOrderRedeem(eoa2, amount2, true);

        uint256 usdcProfit1 = amount1 * _priceIncrease;
        uint256 usdcProfit2 = amount2 * _priceIncrease;

        uint256 refillAmount = usdcProfit1 + usdcProfit2;

        offchainFund.drain();
        _refill(refillAmount);
        offchainFund.update(1e8 * _priceIncrease);

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), usdcProfit2);
        assertEq(usdc.balanceOf(eoa1), usdcProfit1);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(offchainFund.currentRedemptions(), shares2);

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), usdcProfit1);
        assertEq(usdc.balanceOf(eoa2), usdcProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, 0);
        assertEq(assets2, 0);
    }

    function testProcessPreDrainRedeemsAfterEpochPartially(
        uint8 _priceIncrease, // new price = old price * _priceIncrease
        uint8 k // Between 1-9. If 2, 20% of total USDC for giving out will be refilled and 80% later.
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(k > 0 && k < 10);

        // I want to make sure that numbers can be divided just fine to avoid incosistencies in number test by +/- 1.
        // vm.assume() was rejecting too many inputs for this criteria so I have it hardcoded.
        uint256 amount1 = 100e6;
        uint256 amount2 = 200e6;

        uint256 totalAmount = amount1 + amount2;

        _depositAndOrderRedeem(eoa1, amount1, true);
        uint256 shares2 = _depositAndOrderRedeem(eoa2, amount2, true);

        uint256 firstRefillAmount = ((totalAmount * k) / 10) * _priceIncrease;

        offchainFund.drain();
        _refill(firstRefillAmount);
        offchainFund.update(1e8 * _priceIncrease);

        uint256 partialProfit1 = (firstRefillAmount * amount1) / totalAmount;
        uint256 partialProfit2 = (firstRefillAmount * amount2) / totalAmount;
        uint256 fullProfit1 = amount1 * _priceIncrease;
        uint256 fullProfit2 = amount2 * _priceIncrease;

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), partialProfit2);
        assertEq(usdc.balanceOf(eoa1), partialProfit1);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(offchainFund.currentRedemptions(), shares2);
        assertEq(
            offchainFund.pendingRedemptions(),
            ((fullProfit1 - partialProfit1) * 1e12) / _priceIncrease // Division because price increase isn't correlated to shares amount
        );

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), partialProfit1);
        assertEq(usdc.balanceOf(eoa2), partialProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(
            offchainFund.pendingRedemptions(),
            ((fullProfit1 + fullProfit2 - partialProfit1 - partialProfit2) *
                1e12) / _priceIncrease // Division because price increase isn't correlated to shares amount
        );

        offchainFund.drain();
        // Refill Remaining funds to fully process the redeem
        _refill((totalAmount - ((totalAmount * k) / 10)) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease); // We will leave the price same

        offchainFund.processRedeem(eoa1);

        assertEq(
            usdc.balanceOf(address(offchainFund)),
            fullProfit2 - partialProfit2
        );
        assertEq(usdc.balanceOf(eoa1), fullProfit1);
        assertEq(usdc.balanceOf(eoa2), partialProfit2);
        assertEq(
            offchainFund.currentRedemptions(),
            ((fullProfit2 - partialProfit2) * 1e12) / _priceIncrease
        ); // Division because price increase isn't correlated to shares amount);
        assertEq(offchainFund.pendingRedemptions(), 0);

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), fullProfit1);
        assertEq(usdc.balanceOf(eoa2), fullProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, 0);
        assertEq(assets2, 0);
    }

    function testProcessPostDrainRedeemsAfter2EpochsFully(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint8 _priceIncrease // new price = old price * _priceIncrease
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(
            _amount1 > offchainFund.min() && _amount2 > offchainFund.min()
        );

        amounts.push(uint256(_amount1));
        amounts.push(uint256(_amount2));
        eoas.push(eoa1);
        eoas.push(eoa2);

        uint256[] memory shares = _depositAndOrderRedeemBatch(
            eoas,
            amounts,
            false
        );

        uint256 usdcProfit1 = amounts[0] * _priceIncrease;
        uint256 usdcProfit2 = amounts[1] * _priceIncrease;

        uint256 refillAmount = usdcProfit1 + usdcProfit2;

        _refill(refillAmount);
        offchainFund.update(1e8 * _priceIncrease);
        offchainFund.drain();
        offchainFund.update(1e8 * _priceIncrease);

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), usdcProfit2);
        assertEq(usdc.balanceOf(eoa1), usdcProfit1);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(offchainFund.currentRedemptions(), shares[1]);

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), usdcProfit1);
        assertEq(usdc.balanceOf(eoa2), usdcProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, 0);
        assertEq(assets2, 0);
    }

    function testProcessPostDrainRedeemsAfter2EpochsPartially(
        uint8 _priceIncrease, // new price = old price * _priceIncrease
        uint8 k // Between 1-9. If 2, 20% of total USDC for giving out will be refilled and 80% later.
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(k > 0 && k < 10);

        // I want to make sure that numbers can be divided just fine to avoid incosistencies in number test by +/- 1.
        // vm.assume() was rejecting too many inputs for this criteria so I have it hardcoded.
        uint256 amount1 = 100e6;
        uint256 amount2 = 200e6;

        uint256 totalAmount = amount1 + amount2;

        amounts.push(amount1);
        amounts.push(amount2);
        eoas.push(eoa1);
        eoas.push(eoa2);

        uint256[] memory shares = _depositAndOrderRedeemBatch(
            eoas,
            amounts,
            false
        );

        uint256 firstRefillAmount = ((totalAmount * k) / 10) * _priceIncrease;

        _refill(firstRefillAmount);
        offchainFund.update(1e8 * _priceIncrease);
        offchainFund.drain();
        offchainFund.update(1e8 * _priceIncrease);

        uint256 partialProfit1 = (firstRefillAmount * amount1) / totalAmount;
        uint256 partialProfit2 = (firstRefillAmount * amount2) / totalAmount;
        uint256 fullProfit1 = amount1 * _priceIncrease;
        uint256 fullProfit2 = amount2 * _priceIncrease;

        offchainFund.processRedeem(eoa1);

        assertEq(usdc.balanceOf(address(offchainFund)), partialProfit2);
        assertEq(usdc.balanceOf(eoa1), partialProfit1);
        assertEq(usdc.balanceOf(eoa2), 0);
        assertEq(offchainFund.currentRedemptions(), shares[1]);
        assertEq(
            offchainFund.pendingRedemptions(),
            ((fullProfit1 - partialProfit1) * 1e12) / _priceIncrease // Division because price increase isn't correlated to shares amount
        );

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), partialProfit1);
        assertEq(usdc.balanceOf(eoa2), partialProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(
            offchainFund.pendingRedemptions(),
            ((fullProfit1 + fullProfit2 - partialProfit1 - partialProfit2) *
                1e12) / _priceIncrease // Division because price increase isn't correlated to shares amount
        );

        offchainFund.drain();
        // Refill Remaining funds to fully process the redeem
        _refill((totalAmount - ((totalAmount * k) / 10)) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease); // We will leave the price same

        offchainFund.processRedeem(eoa1);

        assertEq(
            usdc.balanceOf(address(offchainFund)),
            fullProfit2 - partialProfit2
        );
        assertEq(usdc.balanceOf(eoa1), fullProfit1);
        assertEq(usdc.balanceOf(eoa2), partialProfit2);
        assertEq(
            offchainFund.currentRedemptions(),
            ((fullProfit2 - partialProfit2) * 1e12) / _priceIncrease
        ); // Division because price increase isn't correlated to shares amount);
        assertEq(offchainFund.pendingRedemptions(), 0);

        offchainFund.processRedeem(eoa2);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), fullProfit1);
        assertEq(usdc.balanceOf(eoa2), fullProfit2);
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, 0);
        assertEq(assets2, 0);
    }

    function testProcessPassingRedeemsBatch(
        uint40 _amount1,
        uint40 _amount2,
        uint8 _priceIncrease // new price = old price * _priceIncrease
    ) public {
        vm.assume(_priceIncrease > 0 && _priceIncrease < 10);
        vm.assume(
            _amount1 > offchainFund.min() && _amount2 > offchainFund.min()
        );

        uint256 amount1 = uint256(_amount1);
        uint256 amount2 = uint256(_amount2);

        _depositAndOrderRedeem(eoa1, amount1, true);
        _depositAndOrderRedeem(eoa2, amount2, true);

        offchainFund.drain();
        _refill((amount1 + amount2) * _priceIncrease);
        offchainFund.update(1e8 * _priceIncrease);

        eoas.push(eoa1);
        eoas.push(eoa2);

        offchainFund.batchProcessRedeem(eoas);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(eoa1), amount1 * _priceIncrease);
        assertEq(usdc.balanceOf(eoa2), amount2 * _priceIncrease);
        assertEq(offchainFund.currentRedemptions(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userRedemptions(eoa1);
        assertEq(epoch1, 0);
        assertEq(assets1, 0);

        (uint256 epoch2, uint256 assets2) = offchainFund.userRedemptions(eoa2);
        assertEq(epoch2, 0);
        assertEq(assets2, 0);
    }

    function testProcessFailingRedeemsBatch(
        uint40 _amount1,
        uint40 _amount2
    ) public {
        vm.assume(
            _amount1 > offchainFund.min() && _amount2 > offchainFund.min()
        );

        uint256 amount1 = uint256(_amount1);
        uint256 amount2 = uint256(_amount2);

        offchainFund.drain();
        _refill(amount1 + amount2);
        offchainFund.update(1e8);

        eoas.push(eoa1);
        eoas.push(eoa2);

        uint256 currentRedemptionsBeforeProcessing = offchainFund
            .currentRedemptions();
        uint256 fundsUSDCBeforeProcessing = usdc.balanceOf(
            address(offchainFund)
        );
        uint256 eoa1USDCBeforeProcessing = usdc.balanceOf(eoa1);
        uint256 eoa2USDCBeforeProcessing = usdc.balanceOf(eoa2);

        offchainFund.batchProcessRedeem(eoas);

        assertEq(
            offchainFund.currentRedemptions(),
            currentRedemptionsBeforeProcessing
        );
        assertEq(
            usdc.balanceOf(address(offchainFund)),
            fundsUSDCBeforeProcessing
        );
        assertEq(usdc.balanceOf(eoa1), eoa1USDCBeforeProcessing);
        assertEq(usdc.balanceOf(eoa2), eoa2USDCBeforeProcessing);
    }

    function testProcessSomeFailingRedeemsBatch(
        uint40 _amount1,
        uint40 _amount2
    ) public {
        vm.assume(
            _amount1 > offchainFund.min() && _amount2 > offchainFund.min()
        );

        uint256 amount1 = uint256(_amount1);
        uint256 amount2 = uint256(_amount2);

        _depositAndOrderRedeem(eoa1, amount1, true);

        offchainFund.drain();
        _refill(amount1 + amount2);
        offchainFund.update(1e8);

        eoas.push(eoa1);
        eoas.push(eoa2);

        uint256 eoa1USDCBeforeProcessing = usdc.balanceOf(eoa1);
        uint256 eoa2USDCBeforeProcessing = usdc.balanceOf(eoa2);

        offchainFund.batchProcessRedeem(eoas);

        // Only eoa1 should be processed
        assertEq(offchainFund.currentRedemptions(), 0);
        assertEq(offchainFund.pendingRedemptions(), 0);
        assertEq(offchainFund.tempBurn(), 0);
        assertEq(usdc.balanceOf(eoa1), eoa1USDCBeforeProcessing + amount1);
        assertEq(usdc.balanceOf(eoa2), eoa2USDCBeforeProcessing);
    }

    function testProcessRedeemWithoutOrderPlaced(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        vm.expectRevert("account has no redeem order");
        offchainFund.processRedeem(eoa1);
    }

    function testProcessRedeemWithoutNavUpdate(uint256 _amount) public {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _depositAndOrderRedeem(eoa1, _amount, true);

        vm.expectRevert("nav has not been updated for redeem");
        offchainFund.processRedeem(eoa1);

        offchainFund.drain();

        vm.expectRevert("nav has not been updated for redeem");
        offchainFund.processRedeem(eoa1);
    }

    function testProcessRedeemWithMockedTransferFail(uint40 _amount) public {
        vm.assume(_amount > offchainFund.min());

        uint256 amount = uint256(_amount);

        _depositAndOrderRedeem(eoa1, amount, true);

        offchainFund.drain();
        _refill(amount);
        offchainFund.update(1e8);

        bytes memory encodedSelector = abi.encodeWithSelector(
            IERC20.transfer.selector,
            eoa1,
            _amount
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa1);

        vm.clearMockedCalls();
    }

    function testProcessRedeemWithZeroUSDCBalance(uint40 _amount) public {
        vm.assume(_amount > offchainFund.min());

        uint256 amount = uint256(_amount);

        _depositAndOrderRedeem(eoa1, amount, true);

        offchainFund.drain();
        _refill(amount);
        offchainFund.update(1e8);

        deal(address(usdc), address(offchainFund), 0, true);
        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa1);
    }

    function testProcessRedeemWithZeroCurrentRedemptions(
        uint40 _amount
    ) public {
        vm.assume(_amount > offchainFund.min());

        uint256 amount = uint256(_amount);

        _depositAndOrderRedeem(eoa1, amount, true);

        offchainFund.drain();
        _refill(amount);
        offchainFund.update(1e8);

        vm.store(
            address(offchainFund),
            bytes32(uint256(17)),
            bytes32(uint256(0))
        ); // currentRedemptions

        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa1);
    }

    function testProcessRedeemWithLessCurrentRedemptions(
        uint40 _amount
    ) public {
        vm.assume(_amount > offchainFund.min());

        uint256 amount = uint256(_amount);

        _depositAndOrderRedeem(eoa1, amount, true);
        _depositAndOrderRedeem(eoa2, amount, true);

        offchainFund.drain();
        _refill(amount);
        offchainFund.update(1e8);

        vm.store(
            address(offchainFund),
            bytes32(uint256(17)),
            bytes32(uint256(1))
        ); // currentRedemptions

        vm.expectRevert(stdError.assertionError);
        offchainFund.processRedeem(eoa1);
    }

    function _depositAndOrderRedeem(
        address _eoa,
        uint256 _amount,
        bool _preDrain
    ) internal returns (uint256 shares) {
        _depositAndProcess(_eoa, _amount);

        if (!_preDrain) {
            offchainFund.drain();
        }

        shares = offchainFund.balanceOf(_eoa);

        vm.prank(_eoa);
        offchainFund.redeem(shares);
    }

    function _depositAndOrderRedeemBatch(
        address[] memory _eoas,
        uint256[] memory _amounts,
        bool _preDrain
    ) internal returns (uint256[] memory) {
        for (uint i; i < _eoas.length; i++) {
            _depositAndProcess(_eoas[i], _amounts[i]);
        }

        if (!_preDrain) {
            offchainFund.drain();
        }

        uint256[] memory shares = new uint256[](_eoas.length);

        for (uint i; i < _eoas.length; i++) {
            uint256 _share = offchainFund.balanceOf(_eoas[i]);
            shares[i] = _share;
            vm.prank(_eoas[i]);
            offchainFund.redeem(_share);
        }

        return shares;
    }

    function _refill(uint256 _amount) internal {
        token.mint(address(this), _amount);
        usdc.approve(address(offchainFund), _amount);
        offchainFund.refill(_amount);
    }
}
