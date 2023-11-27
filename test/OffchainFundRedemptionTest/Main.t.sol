// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundRedemptionTest is Test {
    event Redeem(address indexed, uint256 indexed, uint256);

    event ProcessRedeem(
        address indexed,
        address indexed,
        uint256 indexed,
        uint256,
        uint256,
        uint256,
        bool
    );

    address public eoa1 = vm.addr(1);
    address public eoa2 = vm.addr(2);
    address public eoa3 = vm.addr(3);
    address public eoa4 = vm.addr(4);
    address public eoa5 = vm.addr(5);
    address public eoa6 = vm.addr(6);

    IERC20 public usdc;
    ERC20DecimalsMock public token;

    OffchainFund public offchainFund;

    uint256 constant BILLION_USDC = 1_000_000_000e6;

    function setUp() public {
        token = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc = IERC20(address(token));
        offchainFund = new OffchainFund(
            address(this),
            address(usdc),
            "Fund Test",
            "OCF"
        );

        vm.prank(eoa1);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa1);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa2);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa3);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa5);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa6);
        usdc.approve(address(offchainFund), type(uint256).max);

        vm.prank(eoa4);
        offchainFund.approve(address(offchainFund), type(uint256).max);

        usdc.approve(address(offchainFund), type(uint256).max);

        offchainFund.addToWhitelist(eoa1);
        offchainFund.addToWhitelist(eoa2);
        offchainFund.addToWhitelist(eoa3);
        offchainFund.addToWhitelist(eoa4);
        offchainFund.addToWhitelist(eoa5);
        offchainFund.addToWhitelist(eoa6);

        offchainFund.adjustCap(type(uint256).max);
    }

    function _depositAndProcess(address _eoa, uint256 _amount) internal {
        token.mint(_eoa, _amount);

        vm.prank(_eoa);
        offchainFund.deposit(_amount);

        offchainFund.drain();
        offchainFund.update(1e8);

        offchainFund.processDeposit(_eoa);
    }
}
