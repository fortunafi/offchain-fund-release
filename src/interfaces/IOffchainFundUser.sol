// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IOffchainFundUser {
    /// @dev Emitted when `USDC` is deposited to the fund
    /// @param sender The sender of the `USDC`
    /// @param epoch The epoch of the deposit
    /// @param assets The amount of `USDC` deposited
    event Deposit(
        address indexed sender,
        uint256 indexed epoch,
        uint256 assets
    );

    /// @dev Emitted when fund shares redeem order is placed
    /// @param sender The sender of the redeem order
    /// @param epoch The epoch of the redeem order
    /// @param shares The amount of fund shares to redeem
    event Redeem(address indexed sender, uint256 indexed epoch, uint256 shares);

    /// @dev The asset of the fund
    /// @return usdc `USDC` token
    function usdc() external view returns (IERC20 usdc);

    /// @dev Place order to receive fund shares by depositing `USDC`
    /// @param amount The amount of `USDC` to deposit
    function deposit(uint256 amount) external;

    /// @dev Place order to receive `USDC` by burning fund shares
    /// @param shares The amount of shares to redeem
    function redeem(uint256 shares) external;
}
