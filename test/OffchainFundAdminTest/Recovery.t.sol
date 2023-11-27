// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminRecoveryTest is OffchainFundAdminTest {
    function testRecoverToken(uint256 _amount) external {
        ERC20 testToken = new ERC20("Test Token", "TTT");
        deal(address(testToken), address(this), _amount);
        testToken.transfer(address(offchainFund), _amount);
        assertEq(testToken.balanceOf(address(this)), 0);
        assertEq(testToken.balanceOf(address(offchainFund)), _amount);
        offchainFund.recover(address(testToken));
        assertEq(testToken.balanceOf(address(this)), _amount);
        assertEq(testToken.balanceOf(address(offchainFund)), 0);
    }

    function testRecoverTokenAsNonOwner(address _address) external {
        vm.assume(_address != address(this));
        vm.prank(_address);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.recover(address(usdc));
    }

    // OffchainFund contract can't receive ETH
    function testRecoverEth() external {
        uint256 fundStartingBalance = address(offchainFund).balance;
        uint256 ownerStartingBalance = address(this).balance;
        offchainFund.recover();
        assertEq(address(offchainFund).balance, 0);
        assertEq(
            address(this).balance,
            ownerStartingBalance + fundStartingBalance
        );
    }

    function testRecoverEthAsNonOwner(address _address) external {
        vm.assume(_address != address(this));
        vm.prank(_address);
        vm.expectRevert("Ownable: caller is not the owner");
        offchainFund.recover();
    }
}
