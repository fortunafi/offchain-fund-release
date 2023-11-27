// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundInvestTest is Test {
    event Deposit(address indexed, uint256 indexed, uint256);

    event ProcessDeposit(
        address indexed,
        address indexed,
        uint256 indexed,
        uint256,
        uint256,
        uint256
    );

    address public eoa1 = vm.addr(1);
    address public eoa2 = vm.addr(2);
    address public eoa3 = vm.addr(3);
    address public eoa4 = vm.addr(4);
    address public eoa5 = vm.addr(5);
    address public eoa6 = vm.addr(6);

    address[] public eoas = [eoa1, eoa2, eoa3, eoa4, eoa5, eoa6];

    IERC20 public usdc;
    ERC20DecimalsMock public token;

    OffchainFund public offchainFund;

    function setUp() public {
        token = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc = IERC20(address(token));
        offchainFund = new OffchainFund(
            address(this),
            address(usdc),
            "Fund Test",
            "OCF"
        );

        for (uint i = 0; i < eoas.length; i++) {
            vm.prank(eoas[i]);
            usdc.approve(address(offchainFund), type(uint256).max);

            offchainFund.addToWhitelist(eoas[i]);
        }

        offchainFund.adjustCap(type(uint256).max / 2); // Division because we catch cap exceeding error instead of overflow
        offchainFund.adjustMin(10e6);
    }
}
