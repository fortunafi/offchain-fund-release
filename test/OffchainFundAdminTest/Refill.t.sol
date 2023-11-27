// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import "./Main.t.sol";

contract OffchainFundAdminRefillTest is OffchainFundAdminTest {
    function testRefillEventEmitted(uint256 _epoch, uint256 _amount) public {
        vm.store(
            address(offchainFund),
            bytes32(uint256(10)),
            bytes32(uint256(_epoch))
        ); // epoch

        token.mint(address(this), _amount);

        usdc.approve(address(offchainFund), _amount);

        vm.expectEmit(true, true, true, true);
        emit Refill(address(this), _epoch, _amount);
        offchainFund.refill(_amount);
    }

    function testRefill(uint256 _amount) public {
        token.mint(address(this), _amount);

        assertEq(usdc.balanceOf(address(offchainFund)), 0);
        assertEq(usdc.balanceOf(address(this)), _amount);

        usdc.approve(address(offchainFund), _amount);

        offchainFund.refill(_amount);

        assertEq(usdc.balanceOf(address(offchainFund)), _amount);
        assertEq(usdc.balanceOf(address(this)), 0);
    }

    function testRefillInsufficient(uint256 _amount) public {
        vm.assume(_amount > 0);
        token.mint(address(this), _amount);

        vm.expectRevert("ERC20: insufficient allowance");
        offchainFund.refill(_amount);
    }

    function testRefillMockedTransferFail(uint256 _amount) public {
        vm.assume(_amount > 0);
        token.mint(address(this), _amount);

        bytes memory encodedSelector = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            address(this),
            address(offchainFund),
            _amount
        );

        vm.mockCall(address(usdc), encodedSelector, abi.encode(false));

        vm.expectRevert(stdError.assertionError);
        offchainFund.refill(_amount);

        vm.clearMockedCalls();
    }
}
