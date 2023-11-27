// SPDX-License-Identifier: BLS 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminCapAndMinTest is OffchainFundAdminTest {
    function testAdjustCap(uint256 _amount) external {
        offchainFund.adjustCap(_amount);
        assertEq(offchainFund.cap(), _amount);
    }

    function testAdjustCapAsNonOwner(
        uint256 _amount,
        address _address
    ) external {
        vm.assume(_address != address(this));
        vm.prank(_address);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.adjustCap(_amount);
    }

    function testAdjustMin(uint256 _amount) external {
        offchainFund.adjustMin(_amount);
        assertEq(offchainFund.min(), _amount);
    }

    function testAdjustMinAsNonOwner(
        uint256 _amount,
        address _address
    ) external {
        vm.assume(_address != address(this));
        vm.prank(_address);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.adjustMin(_amount);
    }
}
