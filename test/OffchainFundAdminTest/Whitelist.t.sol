// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminWhitelistTest is OffchainFundAdminTest {
    function testAddToWhitelist(address _eoa) public {
        assertFalse(offchainFund.isWhitelisted(_eoa));
        offchainFund.addToWhitelist(_eoa);
        assertTrue(offchainFund.isWhitelisted(_eoa));
    }

    function testAddToWhitelistBatch(address[] calldata _eoas) public {
        vm.assume(_eoas.length < 10); // Making sure test isn't slow
        for (uint i; i < _eoas.length; i++) {
            assertFalse(offchainFund.isWhitelisted(_eoas[i]));
        }
        offchainFund.batchAddToWhitelist(_eoas);
        for (uint i; i < _eoas.length; i++) {
            assertTrue(offchainFund.isWhitelisted(_eoas[i]));
        }
    }

    function testAddToWhitelistUnauthorized(
        address _eoa1,
        address _eoa2
    ) public {
        vm.assume(_eoa1 != address(this));
        vm.expectRevert();
        vm.prank(_eoa1);
        offchainFund.addToWhitelist(_eoa2);
    }

    function testAddToWhitelistBatchUnauthorized(
        address _eoa,
        address[] calldata _eoas
    ) public {
        vm.assume(_eoas.length < 10 && _eoas.length > 0); // Making sure test isn't slow and array has at least 1 address so `grantRole` is called
        vm.assume(_eoa != address(this));
        vm.expectRevert();
        vm.prank(_eoa);
        offchainFund.batchAddToWhitelist(_eoas);
    }

    function testRemoveToWhitelist(address _eoa) public {
        offchainFund.addToWhitelist(_eoa);
        assertTrue(offchainFund.isWhitelisted(_eoa));
        offchainFund.removeFromWhitelist(_eoa);
        assertFalse(offchainFund.isWhitelisted(_eoa));
    }

    function testRemoveToWhitelistBatch(address[] calldata _eoas) public {
        vm.assume(_eoas.length < 10); // Making sure test isn't slow
        offchainFund.batchAddToWhitelist(_eoas);
        for (uint i; i < _eoas.length; i++) {
            assertTrue(offchainFund.isWhitelisted(_eoas[i]));
        }
        offchainFund.batchRemoveFromWhitelist(_eoas);
        for (uint i; i < _eoas.length; i++) {
            assertFalse(offchainFund.isWhitelisted(_eoas[i]));
        }
    }

    function testRemoveFromWhitelistUnauthorized(
        address _eoa1,
        address _eoa2
    ) public {
        vm.assume(_eoa1 != address(this));
        offchainFund.addToWhitelist(_eoa2);
        vm.expectRevert();
        vm.prank(_eoa1);
        offchainFund.removeFromWhitelist(_eoa2);
    }

    function testRemoveFromWhitelistBatchUnauthorized(
        address _eoa,
        address[] calldata _eoas
    ) public {
        vm.assume(_eoas.length < 10 && _eoas.length > 0); // Making sure test isn't slow and array has at least 1 address so `grantRole` is called
        vm.assume(_eoa != address(this));
        vm.expectRevert();
        vm.prank(_eoa);
        offchainFund.batchRemoveFromWhitelist(_eoas);
    }

    function testFundTokenTransfersForNonWhitelisted(
        address _eoa1,
        address _eoa2
    ) public {
        vm.assume(_eoa1 != address(0));
        vm.assume(_eoa2 != address(0));
        vm.assume(_eoa1 != _eoa2);

        assertFalse(offchainFund.isWhitelisted(_eoa1));
        assertFalse(offchainFund.isWhitelisted(_eoa2));

        vm.expectRevert("receiver address is not in the whitelist");
        vm.prank(_eoa1);
        offchainFund.transfer(_eoa2, 1e18);

        offchainFund.addToWhitelist(_eoa1);

        vm.expectRevert("sender address is not in the whitelist");
        vm.prank(_eoa2);
        offchainFund.transfer(_eoa1, 1e18);
    }

    function testFundTokenTransfersForWhitelisted(
        address _eoa1,
        address _eoa2,
        uint256 _amount
    ) public {
        vm.assume(_eoa1 != address(0));
        vm.assume(_eoa2 != address(0));
        vm.assume(_eoa1 != _eoa2);

        assertFalse(offchainFund.isWhitelisted(_eoa1));
        assertFalse(offchainFund.isWhitelisted(_eoa2));

        offchainFund.addToWhitelist(_eoa1);
        offchainFund.addToWhitelist(_eoa2);

        deal(address(offchainFund), address(_eoa1), _amount, true);

        vm.prank(_eoa1);
        offchainFund.transfer(_eoa2, _amount);

        assertEq(offchainFund.balanceOf(_eoa1), 0);
        assertEq(offchainFund.balanceOf(_eoa2), _amount);

        vm.prank(_eoa2);
        offchainFund.transfer(_eoa1, _amount);

        assertEq(offchainFund.balanceOf(_eoa1), _amount);
        assertEq(offchainFund.balanceOf(_eoa2), 0);
    }
}
