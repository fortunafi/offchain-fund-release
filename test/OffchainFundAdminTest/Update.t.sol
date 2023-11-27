// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminUpdateTest is OffchainFundAdminTest {
    function testUpdateEventEmitted(
        uint256 _epoch,
        uint256 _newPrice,
        uint256 _currentDeposits
    ) public {
        vm.assume(_epoch < type(uint128).max); // preventing overlfow
        vm.assume(_newPrice > 0 && _newPrice < 1_000_000_000_000e8);
        vm.assume(_currentDeposits < 1_000_000_000_000_000e6);

        offchainFund.drain();

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(_epoch))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(14)),
            bytes32(uint256(_currentDeposits))
        ); // currentDeposits

        vm.expectEmit(true, true, true, true);
        emit Update(
            address(this),
            _epoch + 1,
            _newPrice,
            (_currentDeposits * 1e20) / _newPrice
        );
        offchainFund.update(_newPrice);
    }

    function testUpdate(
        uint256 _epoch,
        uint256 _newPrice,
        uint256 _preDrainDepositCount,
        uint256 _postDrainDepositCount,
        uint256 _currentDeposits
    ) external {
        vm.assume(_epoch < type(uint128).max); // preventing overlfow
        vm.assume(_preDrainDepositCount > 0);
        vm.assume(_currentDeposits > 0 && _currentDeposits < 1e18); // Prevent overflow in calculations in `update`
        vm.assume(_newPrice > 0 && _newPrice < 1_000_000e8); // Prevent overflow in calculations in `update`

        offchainFund.drain();

        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(_epoch))
        ); // epoch

        vm.store(
            address(offchainFund),
            bytes32(uint256(14)),
            bytes32(uint256(_currentDeposits))
        ); // currentDeposits

        vm.store(
            address(offchainFund),
            bytes32(uint256(18)),
            bytes32(uint256(_preDrainDepositCount))
        ); // preDrainDepositCount

        vm.store(
            address(offchainFund),
            bytes32(uint256(19)),
            bytes32(uint256(_postDrainDepositCount))
        ); // postDrainDepositCount

        vm.store(
            address(offchainFund),
            bytes32(uint256(20)),
            bytes32(uint256(0))
        ); // currentDepositCount

        offchainFund.update(_newPrice);

        assertEq(offchainFund.epoch(), _epoch + 1);

        assertFalse(offchainFund.drained());
        assertEq(offchainFund.currentPrice(), _newPrice);

        assertEq(offchainFund.currentDepositCount(), _preDrainDepositCount);

        assertEq(offchainFund.preDrainDepositCount(), _postDrainDepositCount);
        assertEq(offchainFund.postDrainDepositCount(), 0);

        assertEq(
            offchainFund.tempMint(),
            (_currentDeposits * 1e20) / _newPrice
        );
        assertEq(offchainFund.tempBurn(), 0);

        assertEq(offchainFund.currentDeposits(), _currentDeposits);
    }

    function testUpdateAsNonOwner(address _eoa) public {
        vm.assume(_eoa != address(this));
        vm.prank(_eoa);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.update(1e8);
    }

    function testUpdateWithZeroPrice() public {
        vm.expectRevert("price can not be set to 0");
        offchainFund.update(0);
    }

    function testUpdateWithoutDraining(uint256 _newPrice) public {
        vm.assume(_newPrice > 0);
        vm.expectRevert("user deposits have not been pulled");
        offchainFund.update(_newPrice);
    }

    function testUpdateWithoutFullDepositProcessing(
        uint256 _newPrice,
        uint256 _currentDepositCount
    ) public {
        vm.assume(_newPrice > 0);
        vm.assume(_currentDepositCount > 0);
        vm.store(
            address(offchainFund),
            bytes32(uint256(7)),
            bytes32(uint256(1))
        ); // drained

        vm.store(
            address(offchainFund),
            bytes32(uint256(20)),
            bytes32(uint256(_currentDepositCount))
        ); // currentDepositCount
        vm.expectRevert("deposits have not been fully processed");
        offchainFund.update(_newPrice);
    }
}
