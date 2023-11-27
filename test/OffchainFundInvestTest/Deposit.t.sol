// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundDepositTest is OffchainFundInvestTest {
    function testDepositEventEmitted(uint256 _amount) external {
        vm.assume(_amount > offchainFund.min());
        vm.assume(_amount < offchainFund.cap());

        token.mint(eoa1, _amount);

        vm.expectEmit(true, true, true, true);
        emit Deposit(eoa1, 1, _amount);
        vm.prank(eoa1);
        offchainFund.deposit(_amount);
    }

    function testDepositsFromDifferentEOAsPreDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());

        token.mint(eoa1, _amount1);
        token.mint(eoa2, _amount2);
        token.mint(eoa3, _amount3);

        vm.prank(eoa1);
        offchainFund.deposit(_amount1);

        vm.prank(eoa2);
        offchainFund.deposit(_amount2);

        vm.prank(eoa3);
        offchainFund.deposit(_amount3);

        uint256 totalDeposited = uint256(_amount1) +
            uint256(_amount2) +
            uint256(_amount3);

        assertEq(offchainFund.pendingDeposits(), totalDeposited);
        assertEq(offchainFund.preDrainDepositCount(), 3);
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), totalDeposited);
        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userDeposits(eoa1);
        assertEq(epoch1, 1);
        assertEq(assets1, _amount1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userDeposits(eoa2);
        assertEq(epoch2, 1);
        assertEq(assets2, _amount2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userDeposits(eoa3);
        assertEq(epoch3, 1);
        assertEq(assets3, _amount3);
    }

    function testDepositsFromDifferentEOAsPostDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());

        token.mint(eoa1, _amount1);
        token.mint(eoa2, _amount2);
        token.mint(eoa3, _amount3);

        offchainFund.drain();

        vm.prank(eoa1);
        offchainFund.deposit(_amount1);

        vm.prank(eoa2);
        offchainFund.deposit(_amount2);

        vm.prank(eoa3);
        offchainFund.deposit(_amount3);

        uint256 totalDeposited = uint256(_amount1) +
            uint256(_amount2) +
            uint256(_amount3);

        assertEq(offchainFund.pendingDeposits(), totalDeposited);
        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 3);
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), totalDeposited);
        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.currentDepositCount(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userDeposits(eoa1);
        assertEq(epoch1, 1 + 1);
        assertEq(assets1, _amount1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userDeposits(eoa2);
        assertEq(epoch2, 1 + 1);
        assertEq(assets2, _amount2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userDeposits(eoa3);
        assertEq(epoch3, 1 + 1);
        assertEq(assets3, _amount3);
    }

    function testDepositsFromDifferentEOAsPostAndPreDrain(
        uint40 _amount1, // With uint40, we don't worry about the cap or overflow
        uint40 _amount2,
        uint40 _amount3,
        uint40 _amount4
    ) public {
        vm.assume(_amount1 > offchainFund.min());
        vm.assume(_amount2 > offchainFund.min());
        vm.assume(_amount3 > offchainFund.min());
        vm.assume(_amount4 > offchainFund.min());

        token.mint(eoa1, _amount1);
        token.mint(eoa2, _amount2);
        token.mint(eoa3, _amount3);
        token.mint(eoa4, _amount4);

        vm.prank(eoa1);
        offchainFund.deposit(_amount1);

        vm.prank(eoa2);
        offchainFund.deposit(_amount2);

        offchainFund.drain();

        vm.prank(eoa3);
        offchainFund.deposit(_amount3);

        vm.prank(eoa4);
        offchainFund.deposit(_amount4);

        assertEq(
            offchainFund.pendingDeposits(),
            uint256(_amount3) + uint256(_amount4)
        );
        assertEq(offchainFund.preDrainDepositCount(), 2);
        assertEq(offchainFund.postDrainDepositCount(), 2);
        assertEq(
            usdc.balanceOf(address(this)),
            uint256(_amount1) + uint256(_amount2)
        );
        assertEq(
            usdc.balanceOf(address(offchainFund)),
            uint256(_amount3) + uint256(_amount4)
        );
        assertEq(offchainFund.tempMint(), 0);
        assertEq(
            offchainFund.currentDeposits(),
            uint256(_amount1) + uint256(_amount2)
        );
        assertEq(offchainFund.currentDepositCount(), 0);

        (uint256 epoch1, uint256 assets1) = offchainFund.userDeposits(eoa1);
        assertEq(epoch1, 1);
        assertEq(assets1, _amount1);

        (uint256 epoch2, uint256 assets2) = offchainFund.userDeposits(eoa2);
        assertEq(epoch2, 1);
        assertEq(assets2, _amount2);

        (uint256 epoch3, uint256 assets3) = offchainFund.userDeposits(eoa3);
        assertEq(epoch3, 1 + 1);
        assertEq(assets3, _amount3);

        (uint256 epoch4, uint256 assets4) = offchainFund.userDeposits(eoa4);
        assertEq(epoch4, 1 + 1);
        assertEq(assets4, _amount4);
    }

    function testDepositsFromSameEOAPreDrain(
        uint40[5] memory _amounts // With uint40, we don't worry about the cap or overflow
    ) public {
        uint256 totalAmount;
        for (uint i; i < _amounts.length; i++) {
            uint256 amount = _amounts[i];
            vm.assume(amount > offchainFund.min());
            totalAmount += amount;
        }

        token.mint(eoa1, totalAmount);

        for (uint i; i < _amounts.length; i++) {
            vm.prank(eoa1);
            offchainFund.deposit(_amounts[i]);
        }

        assertEq(offchainFund.pendingDeposits(), totalAmount);
        assertEq(offchainFund.preDrainDepositCount(), 1);
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), totalAmount);
        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.currentDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        (uint256 epoch, uint256 assets) = offchainFund.userDeposits(eoa1);
        assertEq(epoch, 1);
        assertEq(assets, totalAmount);
    }

    function testDepositsFromSameEOAPostDrain(
        uint40[5] memory _amounts // With uint40, we don't worry about the cap or overflow
    ) public {
        uint256 totalAmount;
        for (uint i; i < _amounts.length; i++) {
            uint256 amount = _amounts[i];
            vm.assume(amount > offchainFund.min());
            totalAmount += amount;
        }

        token.mint(eoa1, totalAmount);

        offchainFund.drain();

        for (uint i; i < _amounts.length; i++) {
            vm.prank(eoa1);
            offchainFund.deposit(_amounts[i]);
        }

        assertEq(offchainFund.pendingDeposits(), totalAmount);
        assertEq(offchainFund.preDrainDepositCount(), 0);
        assertEq(offchainFund.postDrainDepositCount(), 1);
        assertEq(usdc.balanceOf(address(this)), 0);
        assertEq(usdc.balanceOf(address(offchainFund)), totalAmount);
        assertEq(offchainFund.tempMint(), 0);
        assertEq(offchainFund.currentDeposits(), 0);
        assertEq(offchainFund.currentDepositCount(), 0);

        (uint256 epoch, uint256 assets) = offchainFund.userDeposits(eoa1);
        assertEq(epoch, 1 + 1);
        assertEq(assets, totalAmount);
    }

    function testDepositLowerThanMin(uint256 _amount) public {
        vm.assume(_amount < offchainFund.min());

        token.mint(eoa1, _amount);

        vm.expectRevert("deposit is less than the minimum");
        vm.prank(eoa1);
        offchainFund.deposit(_amount);
    }

    function testDepositExceedingCap(uint256 _amount) public {
        vm.assume(
            _amount > offchainFund.cap() / 2 && _amount < offchainFund.cap()
        );
        vm.assume(_amount > offchainFund.min());

        token.mint(eoa1, _amount);
        token.mint(eoa2, _amount);

        vm.prank(eoa1);
        offchainFund.deposit(_amount);

        vm.expectRevert("deposit would exceed epoch cap");
        vm.prank(eoa2);
        offchainFund.deposit(_amount);
    }

    function testDepositInsufficient(uint256 _amount) public {
        vm.assume(_amount < offchainFund.cap() && _amount > offchainFund.min());

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(eoa1);
        offchainFund.deposit(_amount);
    }

    function testDepositMockedTransferFail(uint256 _amount) public {
        vm.assume(_amount < offchainFund.cap() && _amount > offchainFund.min());

        bytes memory encodedSelector = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            eoa1,
            address(offchainFund),
            _amount
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);

        vm.prank(eoa1);
        offchainFund.deposit(_amount);

        vm.clearMockedCalls();
    }

    function testDepositPostAndAfterDrain(uint256 _amount) public {
        vm.assume(
            // Division by 3 to allow 2 deposits without cap error
            _amount < (offchainFund.cap() / 3) && _amount > offchainFund.min()
        );

        token.mint(eoa1, _amount * 2);
        vm.prank(eoa1);
        offchainFund.deposit(_amount);

        offchainFund.drain();

        vm.expectRevert("can not add to deposit after drain");
        vm.prank(eoa1);
        offchainFund.deposit(_amount);
    }

    function testDepositWithUnprocessedDeposit(uint256 _amount) public {
        vm.assume(_amount < 100_000_000e6 && _amount > offchainFund.min());
        token.mint(eoa1, _amount * 2);
        vm.prank(eoa1);
        offchainFund.deposit(_amount);

        offchainFund.drain();
        offchainFund.update(1e6);

        vm.expectRevert("user has unprocessed userDeposits");
        vm.prank(eoa1);
        offchainFund.deposit(_amount);
    }

    function testDepositUnauthorized(address _eoa, uint256 _amount) public {
        vm.assume(_eoa != address(0));
        for (uint i; i < eoas.length; i++) {
            vm.assume(_eoa != eoas[i]);
        }

        token.mint(_eoa, _amount);

        vm.expectRevert();
        vm.prank(_eoa);
        offchainFund.deposit(_amount);
    }
}
