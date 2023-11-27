// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundProcessDepositTest is OffchainFundInvestTest {
    uint256 constant BILLION_USDC = 1_000_000_000e6;

    address[] public addressArrays;

    function testProcessDepositEvent(
        uint256 _amount,
        bool _isRemovedFromWhitelist
    ) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();
        offchainFund.update(2e6);

        address recipient = eoa1;

        if (_isRemovedFromWhitelist) {
            offchainFund.removeFromWhitelist(eoa1);
            offchainFund.addToWhitelist(offchainFund.owner());
            recipient = offchainFund.owner();
        }

        vm.expectEmit(true, true, true, true);
        emit ProcessDeposit(
            address(this),
            recipient,
            2,
            (_amount * 1e12 * 1e8) / 2e6,
            _amount,
            2e6
        );
        offchainFund.processDeposit(eoa1);
    }

    function testProcessPreDrainDepositAfterEpoch(
        uint256 _amount,
        bool _isRemovedFromWhitelist
    ) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();
        offchainFund.update(2e6);

        (bool canProcess, ) = offchainFund.canProcessDeposit(eoa1);
        assertTrue(canProcess);

        address recipient = eoa1;

        if (_isRemovedFromWhitelist) {
            offchainFund.removeFromWhitelist(eoa1);
            offchainFund.addToWhitelist(offchainFund.owner());
            recipient = offchainFund.owner();
        }

        offchainFund.processDeposit(eoa1);

        uint256 shares = (_amount * 1e12 * 1e8) / 2e6;

        if (_isRemovedFromWhitelist) {
            assertEq(recipient, offchainFund.owner());
            assertEq(offchainFund.balanceOf(recipient), shares);
            assertEq(offchainFund.balanceOf(eoa1), 0);
        } else {
            assertEq(eoa1, recipient);
            assertEq(offchainFund.balanceOf(recipient), shares);
            assertEq(offchainFund.balanceOf(offchainFund.owner()), 0);
        }

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.totalSupply(), shares);
        assertEq(offchainFund.tempMint(), 0);
    }

    function testProcessPostDrainDepositAfterEpoch(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        offchainFund.drain();

        _deposit(eoa1, _amount);

        offchainFund.update(2e6);

        (bool canProcess, ) = offchainFund.canProcessDeposit(eoa1);
        assertFalse(canProcess);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa1);
    }

    function testProcessPostDrainDepositAfter2Epochs(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        offchainFund.drain();

        _deposit(eoa1, _amount);

        offchainFund.update(2e6);
        offchainFund.drain();
        offchainFund.update(2e6);

        (bool canProcess, ) = offchainFund.canProcessDeposit(eoa1);
        assertTrue(canProcess);
        offchainFund.processDeposit(eoa1);

        uint256 shares = (_amount * 1e12 * 1e8) / 2e6;

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.totalSupply(), shares);
        assertEq(offchainFund.balanceOf(eoa1), shares);
        assertEq(offchainFund.tempMint(), 0);
    }

    function testProcessPreDrainDepositsAfterEpoch(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        vm.assume(_amount0 > offchainFund.min() && _amount0 < BILLION_USDC);
        vm.assume(_amount1 > offchainFund.min() && _amount1 < BILLION_USDC);

        _deposit(eoa1, _amount0);
        _deposit(eoa2, _amount1);

        offchainFund.drain();
        offchainFund.update(2e6);

        uint256 shares0 = (_amount0 * 1e12 * 1e8) / 2e6;
        uint256 shares1 = (_amount1 * 1e12 * 1e8) / 2e6;

        (bool canProcess1, ) = offchainFund.canProcessDeposit(eoa1);
        assertTrue(canProcess1);
        offchainFund.processDeposit(eoa1);

        assertEq(offchainFund.currentDepositCount(), 1);
        assertEq(offchainFund.currentDeposits(), _amount1);
        assertEq(offchainFund.totalSupply(), shares0);
        assertEq(offchainFund.balanceOf(eoa1), shares0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.tempMint(), shares1);

        (bool canProcess2, ) = offchainFund.canProcessDeposit(eoa2);
        assertTrue(canProcess2);
        offchainFund.processDeposit(eoa2);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.totalSupply(), shares0 + shares1);
        assertEq(offchainFund.balanceOf(eoa1), shares0);
        assertEq(offchainFund.balanceOf(eoa2), shares1);
        assertEq(offchainFund.tempMint(), 0);
    }

    function testProcessPostDrainDepositsAfter2Epochs(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        vm.assume(_amount0 > offchainFund.min() && _amount0 < BILLION_USDC);
        vm.assume(_amount1 > offchainFund.min() && _amount1 < BILLION_USDC);

        offchainFund.drain();

        _deposit(eoa1, _amount0);
        _deposit(eoa2, _amount1);

        offchainFund.update(2e6);
        offchainFund.drain();
        offchainFund.update(2e6);

        uint256 shares0 = (_amount0 * 1e12 * 1e8) / 2e6;
        uint256 shares1 = (_amount1 * 1e12 * 1e8) / 2e6;

        (bool canProcess1, ) = offchainFund.canProcessDeposit(eoa1);
        assertTrue(canProcess1);
        offchainFund.processDeposit(eoa1);

        assertEq(offchainFund.currentDepositCount(), 1);
        assertEq(offchainFund.currentDeposits(), _amount1);
        assertEq(offchainFund.totalSupply(), shares0);
        assertEq(offchainFund.balanceOf(eoa1), shares0);
        assertEq(offchainFund.balanceOf(eoa2), 0);
        assertEq(offchainFund.tempMint(), shares1);

        (bool canProcess2, ) = offchainFund.canProcessDeposit(eoa2);
        assertTrue(canProcess2);
        offchainFund.processDeposit(eoa2);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.totalSupply(), shares0 + shares1);
        assertEq(offchainFund.balanceOf(eoa1), shares0);
        assertEq(offchainFund.balanceOf(eoa2), shares1);
        assertEq(offchainFund.tempMint(), 0);
    }

    function testProcessPassingDepositsBatch(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        vm.assume(_amount0 > offchainFund.min() && _amount0 < BILLION_USDC);
        vm.assume(_amount1 > offchainFund.min() && _amount1 < BILLION_USDC);

        _deposit(eoa1, _amount0);
        _deposit(eoa2, _amount1);

        offchainFund.drain();
        offchainFund.update(2e6);

        uint256 shares0 = (_amount0 * 1e12 * 1e8) / 2e6;
        uint256 shares1 = (_amount1 * 1e12 * 1e8) / 2e6;

        addressArrays.push(eoa1);
        addressArrays.push(eoa2);

        offchainFund.batchProcessDeposit(addressArrays);

        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.totalSupply(), shares0 + shares1);
        assertEq(offchainFund.balanceOf(eoa1), shares0);
        assertEq(offchainFund.balanceOf(eoa2), shares1);
        assertEq(offchainFund.tempMint(), 0);
    }

    function testProcessAllFailingDepositsBatch(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        vm.assume(_amount0 > offchainFund.min() && _amount0 < BILLION_USDC);
        vm.assume(_amount1 > offchainFund.min() && _amount1 < BILLION_USDC);

        _deposit(eoa1, _amount0);
        _deposit(eoa2, _amount1);

        addressArrays.push(eoa1);
        addressArrays.push(eoa2);

        uint256 currentDepositCountBeforeProcessing = offchainFund
            .currentDepositCount();
        uint256 currentDepositsBeforeProcessing = offchainFund
            .currentDeposits();
        uint256 tempMintBeforeProcessing = offchainFund.tempMint();
        uint256 shareTotalSupplyBeforeProcessing = offchainFund.totalSupply();
        uint256 eoa1SharesBeforeProcessing = offchainFund.balanceOf(eoa1);
        uint256 eoa2SharesBeforeProcessing = offchainFund.balanceOf(eoa2);

        // Should process any deposits before drain wasn't called
        offchainFund.batchProcessDeposit(addressArrays);

        assertEq(
            offchainFund.currentDepositCount(),
            currentDepositCountBeforeProcessing
        );
        assertEq(
            offchainFund.currentDeposits(),
            currentDepositsBeforeProcessing
        );
        assertEq(offchainFund.totalSupply(), shareTotalSupplyBeforeProcessing);
        assertEq(offchainFund.tempMint(), tempMintBeforeProcessing);
        assertEq(offchainFund.balanceOf(eoa1), eoa1SharesBeforeProcessing);
        assertEq(offchainFund.balanceOf(eoa2), eoa2SharesBeforeProcessing);
    }

    function testProcessSomeFailingDepositsBatch(
        uint256 _amount0,
        uint256 _amount1
    ) external {
        vm.assume(_amount0 > offchainFund.min() && _amount0 < BILLION_USDC);
        vm.assume(_amount1 > offchainFund.min() && _amount1 < BILLION_USDC);

        _deposit(eoa1, _amount0);

        offchainFund.drain();

        _deposit(eoa2, _amount1);

        offchainFund.update(2e6);

        addressArrays.push(eoa1);
        addressArrays.push(eoa2);

        uint256 currentDepositCountBeforeProcessing = offchainFund
            .currentDepositCount();
        uint256 eoa1SharesBeforeProcessing = offchainFund.balanceOf(eoa1);
        uint256 eoa2SharesBeforeProcessing = offchainFund.balanceOf(eoa2);

        offchainFund.batchProcessDeposit(addressArrays);

        // Only eoa1 should be processed
        assertEq(
            offchainFund.currentDepositCount(),
            currentDepositCountBeforeProcessing - 1
        );
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.pendingDeposits(), _amount1);
        assertEq(
            offchainFund.totalSupply(),
            (_amount0 * 1e12 * 1e8) / offchainFund.currentPrice()
        );
        assertEq(offchainFund.tempMint(), eoa1SharesBeforeProcessing);
        assertEq(offchainFund.balanceOf(eoa2), eoa2SharesBeforeProcessing);
    }

    function testProcessPreDrainDepositAfterDrain(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();

        (bool canProcess, ) = offchainFund.canProcessDeposit(eoa1);
        assertFalse(canProcess);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa1);
    }

    function testProcessPostDrainDepositAfterNextDrain(
        uint256 _amount
    ) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        offchainFund.drain();

        _deposit(eoa1, _amount);

        offchainFund.update(2e6);
        offchainFund.drain();

        (bool canProcess, ) = offchainFund.canProcessDeposit(eoa1);
        assertFalse(canProcess);

        vm.expectRevert("nav has not been updated for mint");
        offchainFund.processDeposit(eoa1);
    }

    function testProcessDepositWithZeroPrice(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();
        offchainFund.update(2e6);

        vm.store(
            address(offchainFund),
            bytes32(uint256(11)),
            bytes32(uint256(0))
        ); // currentPrice

        vm.expectRevert(stdError.assertionError);
        offchainFund.processDeposit(eoa1);
    }

    function testProcessDepositWithZeroDepositCount(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();
        offchainFund.update(2e6);

        vm.store(
            address(offchainFund),
            bytes32(uint256(20)),
            bytes32(uint256(0))
        ); // currentDepositCount

        vm.expectRevert(stdError.assertionError);
        offchainFund.processDeposit(eoa1);
    }

    function testProcessDepositWithLessCurrentDeposits(
        uint256 _amount
    ) external {
        vm.assume(_amount > offchainFund.min() && _amount < BILLION_USDC);

        _deposit(eoa1, _amount);

        offchainFund.drain();
        offchainFund.update(2e6);

        vm.store(
            address(offchainFund),
            bytes32(uint256(14)),
            bytes32(uint256(_amount - 1))
        ); // currentDeposits

        vm.expectRevert(stdError.assertionError);
        offchainFund.processDeposit(eoa1);
    }

    function _deposit(address _eoa, uint256 _amount) internal {
        token.mint(_eoa, _amount);

        vm.prank(_eoa);
        offchainFund.deposit(_amount);
    }
}
