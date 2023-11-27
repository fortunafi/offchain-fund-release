// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

interface IOffchainFundAdmin {
    /// @dev Emitted when the owner Refills the contract with USDC
    /// @param sender The sender of the `USDC`
    /// @param epoch The epoch of the refill
    /// @param assets The amount of `USDC` refilled
    event Refill(address indexed sender, uint256 indexed epoch, uint256 assets);

    /// @dev Emitted when the funds are drained from the contract
    /// @param sender The caller of the drain() function
    /// @param epoch The epoch of the drain
    /// @param assets The amount of `USDC` drained
    /// @param shares The amount of shares to be burned
    event Drain(
        address indexed sender,
        uint256 indexed epoch,
        uint256 assets,
        uint256 shares
    );

    /// @dev Emitted when the price is updated and the epoch starts
    /// @param sender The caller of the update() function
    /// @param epoch The epoch of the update
    /// @param price The new price of the share
    /// @param totalShares The total amount of shares available
    event Update(
        address indexed sender,
        uint256 indexed epoch,
        uint256 price,
        uint256 totalShares
    );

    /// @dev Emitted when the deposit order is processed
    /// @param sender The caller of the processDeposit() function
    /// @param account The account that placed the deposit order
    /// @param epoch The current epoch
    /// @param shares The amount of shares received
    /// @param assets The amount of `USDC` deposited
    /// @param price The price of the share
    event ProcessDeposit(
        address indexed sender,
        address indexed account,
        uint256 indexed epoch,
        uint256 shares,
        uint256 assets,
        uint256 price
    );

    /// @dev Emitted when the redeem order is processed
    /// @param sender The caller of the processRedeem() function
    /// @param account The account that placed the redeem order
    /// @param epoch The current epoch
    /// @param shares The amount of shares burned
    /// @param assets The amount of `USDC` received
    /// @param price The price of the share
    /// @param filled Whether the order was fully filled or not
    event ProcessRedeem(
        address indexed sender,
        address indexed account,
        uint256 indexed epoch,
        uint256 shares,
        uint256 assets,
        uint256 price,
        bool filled
    );

    /// @dev Total deposits submitted in the current epoch
    /// @return _pendingDeposits Total deposits submitted in the current epoch
    function pendingDeposits() external view returns (uint256 _pendingDeposits);

    /// @dev All passed passed available to be processed on a price update
    /// @return _currentDeposits All passed passed available to be processed on a price update
    function currentDeposits() external view returns (uint256 _currentDeposits);

    /// @dev Number of accounts with current deposits
    /// @return _currentDepositCount Number of accounts with current deposits
    function currentDepositCount()
        external
        view
        returns (uint256 _currentDepositCount);

    /// @dev Returns whether the Fund is drained (cut-off) of deposits or not
    /// @return _drained whether the Fund is drained (cut-off) of deposits or not
    function drained() external view returns (bool _drained);

    /// @dev Number of accounts with pre-drain deposits
    /// @return _preDrainDepositCount Number of accounts with pre-drain deposits
    function preDrainDepositCount()
        external
        view
        returns (uint256 _preDrainDepositCount);

    /// @dev Number of accounts with post-drain deposits
    /// @return _postDrainDepositCount Number of accounts with post-drain deposits
    function postDrainDepositCount()
        external
        view
        returns (uint256 _postDrainDepositCount);

    /// @dev Total redemptions submitted in the current epoch
    /// @return _pendingRedemptions Total redemptions submitted in the current epoch
    function pendingRedemptions()
        external
        view
        returns (uint256 _pendingRedemptions);

    /// @dev All passed redemptions available to be processed
    /// @return _currentRedemptions All passed redemptions available to be processed
    function currentRedemptions()
        external
        view
        returns (uint256 _currentRedemptions);

    /// @dev Sets the limit on USDC accepted per epoch
    /// @param cap_ The new limit on deposits
    function adjustCap(uint256 cap_) external;

    /// @dev Sets the minimum deposit amount
    /// @param min_ The new minimum deposit
    function adjustMin(uint256 min_) external;

    /// @dev Adds an address to the whitelist
    /// @param account Address to add to the whitelist
    function addToWhitelist(address account) external;

    /// @dev Removes address from the whitelist
    /// @param account Address to remove from the whitelist
    function removeFromWhitelist(address account) external;

    /// @dev Process batch of addresses to be whitelisted
    /// @param accounts Address list to add to whitlist
    function batchAddToWhitelist(address[] calldata accounts) external;

    /// @dev Process batch of addresses to be removed the whitelist
    /// @param accounts Address list to remove from the whitelist
    function batchRemoveFromWhitelist(address[] calldata accounts) external;

    /// @dev Pulls the maximum amount of available `USDC`
    function drain() external;

    /// @dev Update the NAV per share for the fund and increment the epoch
    /// @param price New share price
    function update(uint256 price) external;

    /// @dev Transfer `USDC` to the contract
    /// @param assets Number of `USDC` tokens to be transferred to the contract
    function refill(uint256 assets) external;

    /// @dev Process the redeem order for an account to receive `USDC`
    /// @param account Address that placed the order
    function processRedeem(address account) external;

    /// @dev Process the deposit order for account to receive fund shares
    /// @param account Address that placed the order
    function processDeposit(address account) external;

    /// @dev Process the batch of deposit orders for accounts to receive fund shares
    /// @param accountList Address list that placed orders
    function batchProcessDeposit(address[] calldata accountList) external;

    /// @dev Process the batch of redeem orders for accounts to receive `USDC`
    /// @param accountList Address list that placed orders
    function batchProcessRedeem(address[] calldata accountList) external;
}
