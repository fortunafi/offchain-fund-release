// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {ERC20DecimalsMock} from "openzeppelin-contracts/contracts/mocks/ERC20DecimalsMock.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {OffchainFund} from "src/OffchainFund.sol";

import {Test, stdError} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OffchainFundAdminTest is Test {
    event Refill(address indexed, uint256 indexed, uint256);

    event Drain(address indexed, uint256 indexed, uint256, uint256);

    event Update(address indexed, uint256 indexed, uint256, uint256);

    event Deposit(address indexed, uint256 indexed, uint256);

    IERC20 usdc;

    ERC20DecimalsMock token;
    OffchainFund offchainFund;

    function setUp() public {
        token = new ERC20DecimalsMock("USD Coin Mock", "USDC", 6);

        usdc = IERC20(address(token));
        offchainFund = new OffchainFund(
            address(this),
            address(usdc),
            "Fund Test",
            "OCF"
        );
    }

    receive() external payable {}
}
