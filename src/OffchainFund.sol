// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.13;

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IOffchainFundUser} from "src/interfaces/IOffchainFundUser.sol";
import {IOffchainFundAdmin} from "src/interfaces/IOffchainFundAdmin.sol";

interface IOffchainFund is
    IOffchainFundUser,
    IOffchainFundAdmin,
    IAccessControl,
    IERC20,
    IERC20Metadata
{
    struct Order {
        uint256 epoch;
        uint256 amount;
    }

    /// @dev Net asset value of the fund
    /// @return nav Net asset value
    function nav() external view returns (uint256 nav);

    /// @dev Maximum `USDC` balance that can be held
    /// @return cap Maximum `USDC` balance that can be held
    function cap() external view returns (uint256 cap);

    /// @dev Minimum `USDC` balance that can be deposited
    /// @return min Minimum `USDC` balance that can be deposited
    function min() external view returns (uint256 min);

    /// @dev Current increment for the net asset value updates
    /// @return epoch Current increment for the net asset value updates
    function epoch() external view returns (uint256 epoch);

    /// @dev Price per share as calculated by the net asset value
    /// @return currentPrice Price per share
    function currentPrice() external view returns (uint256 currentPrice);

    /// @dev Total number of shares
    /// @return totalShares Total number of shares
    function totalShares() external view returns (uint256 totalShares);

    /// @dev State of a user's pending deposits
    /// @param account Address that placed the order
    /// @return epoch The epoch of the deposit
    /// @return amount The amount of `USDC` deposited
    function userDeposits(
        address account
    ) external view returns (uint256 epoch, uint256 amount);

    /// @dev State of a user's pending redemptions
    /// @param account Address that placed the order
    /// @return epoch The epoch of the redeem
    /// @return amount The amount of fund shares to redeem
    function userRedemptions(
        address account
    ) external view returns (uint256 epoch, uint256 amount);

    /// @dev Checks criteria for receiving fund shares
    /// @param account Address that placed the order
    /// @return canProcess Whether the order can be processed or not
    /// @return message The message for why the order can/can't be processed
    function canProcessDeposit(
        address account
    ) external returns (bool canProcess, string memory message);

    /// @dev Checks criteria for receiving `USDC`
    /// @param account Address that placed the order
    /// @return canProcess Whether the order can be processed or not
    /// @return message The message for why the order can/can't be processed
    function canProcessRedeem(
        address account
    ) external returns (bool canProcess, string memory message);

    /// @dev Checks that the address is a member of the whitelist
    /// @param account Address that placed the order
    /// @return _isWhitelisted Whether the address is a member of the whitelist
    function isWhitelisted(
        address account
    ) external view returns (bool _isWhitelisted);
}

contract OffchainFund is Ownable, AccessControl, ERC20, IOffchainFund {
    bytes32 public constant WHITELIST =
        keccak256(abi.encode("offchain.fund.whitelist"));

    IERC20 public immutable usdc;

    bool public drained = false;

    uint256 public cap = 0;
    uint256 public min = 1e6;

    uint256 public epoch = 1;
    uint256 public currentPrice = 1e8;

    uint256 public tempMint = 0;
    uint256 public pendingDeposits = 0;
    uint256 public currentDeposits = 0;

    uint256 public tempBurn = 0;
    uint256 public pendingRedemptions = 0;
    uint256 public currentRedemptions = 0;

    uint256 public preDrainDepositCount = 0;
    uint256 public postDrainDepositCount = 0;

    uint256 public currentDepositCount = 0;

    mapping(address => Order) public userDeposits;
    mapping(address => Order) public userRedemptions;

    constructor(
        address owner,
        address usdc_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        assert(IERC20Metadata(usdc_).decimals() == 6);

        _transferOwnership(owner);
        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        usdc = IERC20(usdc_);
    }

    /// @notice Transfer `USDC` to the contract
    /// @param assets Number of `USDC` tokens to be transferred to the contract
    function refill(uint256 assets) external {
        assert(usdc.transferFrom(_msgSender(), address(this), assets));

        emit Refill(_msgSender(), epoch, assets);
    }

    /// @notice Place order to receive fund shares by depositing `USDC`
    /// @param assets Number of `USDC` tokens to deposit
    function deposit(uint256 assets) external onlyRole(WHITELIST) {
        require(assets > min, "deposit is less than the minimum");
        require(
            cap > pendingDeposits + assets,
            "deposit would exceed epoch cap"
        );

        (bool valid, ) = _canProcessDeposit(_msgSender());
        require(!valid, "user has unprocessed userDeposits");

        assert(usdc.transferFrom(_msgSender(), address(this), assets));

        // We restrict a user from adding to their deposit if they had made one
        // before `drain` was called.

        if (drained) {
            uint256 userEpoch = userDeposits[_msgSender()].epoch;

            require(
                userEpoch == 0 || userEpoch == epoch + 1,
                "can not add to deposit after drain"
            );

            userDeposits[_msgSender()].epoch = epoch + 1;
            postDrainDepositCount = userDeposits[_msgSender()].amount == 0
                ? postDrainDepositCount + 1
                : postDrainDepositCount;
        } else {
            userDeposits[_msgSender()].epoch = epoch;
            preDrainDepositCount = userDeposits[_msgSender()].amount == 0
                ? preDrainDepositCount + 1
                : preDrainDepositCount;
        }

        pendingDeposits += assets;
        userDeposits[_msgSender()].amount += assets;

        emit Deposit(_msgSender(), epoch, assets);
    }

    /// @notice Process the batch of deposit orders for accounts to receive fund shares
    /// @param accountList Address list that placed orders
    function batchProcessDeposit(address[] calldata accountList) external {
        address account;

        uint256 length = accountList.length;
        for (uint256 i = 0; i < length; ++i) {
            account = accountList[i];
            (bool valid, ) = _canProcessDeposit(account);

            if (!valid) continue;

            _processDeposit(account);
        }
    }

    /// @notice Process the deposit order for account to receive fund shares
    /// @param account Address that placed the order
    function processDeposit(address account) external {
        (bool valid, string memory message) = _canProcessDeposit(account);
        require(valid, message);

        _processDeposit(account);
    }

    /// @notice Process the redeem order for an account to receive `USDC`
    /// @param account Address that placed the order
    function _processDeposit(address account) private {
        // sanity checks, should never fail, added just in case

        assert(currentPrice > 0);

        assert(currentDepositCount > 0);

        uint256 assets = userDeposits[account].amount;

        assert(currentDeposits >= assets);

        uint256 shares = (assets * 1e12 * 1e8) / currentPrice;

        delete userDeposits[account];

        currentDepositCount--;
        currentDeposits -= assets;

        // Safety restriction to prevent overflow from rounding
        tempMint -= Math.min(shares, tempMint);

        address recipient = _isWhitelisted(account) ? account : owner();

        _mint(recipient, shares);

        emit ProcessDeposit(
            _msgSender(),
            recipient,
            epoch,
            shares,
            assets,
            currentPrice
        );
    }

    /// @notice Checks criteria for receiving fund shares
    /// @param account Address that placed the order
    /// @return bool Whether the order can be processed or not
    /// @return string The message for why the order can/can't be processed
    function canProcessDeposit(
        address account
    ) external view returns (bool, string memory) {
        return _canProcessDeposit(account);
    }

    /// @notice Checks criteria for receiving fund shares
    /// @param account Address that placed the order
    /// @return bool Whether the order can be processed or not
    /// @return string The message for why the order can/can't be processed
    function _canProcessDeposit(
        address account
    ) private view returns (bool, string memory) {
        if (userDeposits[account].epoch == 0)
            return (false, "account has no mint order");

        if (userDeposits[account].epoch >= epoch)
            return (false, "nav has not been updated for mint");

        return (true, "");
    }

    /// @notice Place order to receive `USDC` by burning fund shares
    /// @param shares Number of fund tokens to burn
    function redeem(uint256 shares) external onlyRole(WHITELIST) {
        (bool valid, ) = _canProcessRedeem(_msgSender());
        require(!valid, "user has unprocessed redemptions");

        _burnFrom(_msgSender(), shares);

        pendingRedemptions += shares;

        userRedemptions[_msgSender()].epoch = drained ? epoch + 1 : epoch;
        userRedemptions[_msgSender()].amount += shares;

        emit Redeem(_msgSender(), epoch, shares);
    }

    /// @notice Process the batch of redeem orders for accounts to receive `USDC`
    /// @param accountList Address list that placed orders
    function batchProcessRedeem(
        address[] calldata accountList
    ) external onlyOwner {
        address account;

        uint256 length = accountList.length;
        for (uint256 i = 0; i < length; ++i) {
            account = accountList[i];
            (bool valid, ) = _canProcessRedeem(account);

            if (!valid) continue;

            _processRedeem(account);
        }
    }

    /// @notice Process the redeem order for an account to receive `USDC`
    /// @param account Address that placed the order
    function processRedeem(address account) external onlyOwner {
        (bool valid, string memory message) = _canProcessRedeem(account);
        require(valid, message);

        _processRedeem(account);
    }

    /// @notice Process the redeem order for an account to receive `USDC`
    /// @param account Address that placed the order
    function _processRedeem(address account) private {
        uint256 shares = userRedemptions[account].amount;
        uint256 value = (shares * currentPrice) / 1e8;

        // sanity checks, should never fail, added just in case

        assert(currentRedemptions > 0);
        assert(currentRedemptions >= shares);

        uint256 contractsUsdcBalance = usdc.balanceOf(address(this));

        assert(contractsUsdcBalance > 0);

        uint256 balance = contractsUsdcBalance -
            Math.min(contractsUsdcBalance, pendingDeposits);

        uint256 available = (shares * balance * 1e12) / currentRedemptions;

        currentRedemptions -= shares;

        address recipient = _isWhitelisted(account) ? account : owner();

        if (value > available) {
            /**
             *
             * This calculation can be done in one of two ways:
             *
             * 1) Take the percentage of the total value being redeemed and
             *    subract it from the order:
             *
             *    (amount * (value - available)) / value
             *
             * 2) Take the amount of tokens required to transfer out the amount
             *    of value the user is redeeming:
             *
             *    (available * 1e8) / currentPrice
             *
             * Both methods are mathematically identical since:
             *
             *    amount * (available / value)
             *       = amount * (available / (currentPrice * amount) / 1e8)
             *       = (available * 1e8) / currentPrice
             *
             */

            // Safety restriction to prevent overflow in case of rounding
            uint256 deduct = Math.min(
                (available * 1e8) / currentPrice,
                userRedemptions[account].amount
            );

            userRedemptions[account].epoch = epoch;
            userRedemptions[account].amount -= deduct;

            pendingRedemptions += userRedemptions[account].amount;

            // Safety restriction to prevent overflow from rounding
            available = Math.min(available / 1e12, contractsUsdcBalance);

            assert(usdc.transfer(recipient, available));

            emit ProcessRedeem(
                _msgSender(),
                recipient,
                epoch,
                deduct,
                available,
                currentPrice,
                false
            );

            return;
        }

        delete userRedemptions[account];

        // Safety restriction to prevent overflow in case of rounding
        value = Math.min(value / 1e12, contractsUsdcBalance);

        assert(usdc.transfer(recipient, value));

        emit ProcessRedeem(
            _msgSender(),
            recipient,
            epoch,
            shares,
            value,
            currentPrice,
            true
        );
    }

    /// @notice Checks criteria for receiving `USDC`
    /// @param account Address that placed the order
    /// @return bool Whether the order can be processed or not
    /// @return string The message for why the order can/can't be processed
    function canProcessRedeem(
        address account
    ) external view returns (bool, string memory) {
        return _canProcessRedeem(account);
    }

    /// @notice Checks criteria for receiving `USDC`
    /// @param account Address that placed the order
    /// @return bool Whether the order can be processed or not
    /// @return string The message for why the order can/can't be processed
    function _canProcessRedeem(
        address account
    ) private view returns (bool, string memory) {
        if (userRedemptions[account].epoch == 0)
            return (false, "account has no redeem order");

        if (userRedemptions[account].epoch >= epoch)
            return (false, "nav has not been updated for redeem");

        return (true, "");
    }

    /// @notice Pulls the maximum amount of available `USDC`
    function drain() external onlyOwner {
        require(!drained, "price has not been updated");

        drained = true;

        uint256 assets = pendingDeposits;

        currentDeposits += pendingDeposits;
        pendingDeposits = 0;

        uint256 shares = pendingRedemptions;

        currentRedemptions += pendingRedemptions;
        pendingRedemptions = 0;

        tempBurn = shares;

        assert(usdc.transfer(_msgSender(), assets));

        emit Drain(_msgSender(), epoch, assets, shares);
    }

    /// @notice Update the NAV per share for the fund and increment the epoch
    /// @param price New share price
    function update(uint256 price) external onlyOwner {
        require(price > 0, "price can not be set to 0");
        require(drained, "user deposits have not been pulled");

        require(
            currentDepositCount == 0,
            "deposits have not been fully processed"
        );

        ++epoch;

        drained = false;
        currentPrice = price;

        currentDepositCount = preDrainDepositCount;
        preDrainDepositCount = postDrainDepositCount;
        postDrainDepositCount = 0;

        tempBurn = 0;
        tempMint = (currentDeposits * 1e12 * 1e8) / currentPrice;

        emit Update(_msgSender(), epoch, currentPrice, totalShares());
    }

    /// @notice Net asset value of the fund
    /// @return uint256 Net asset value of the fund
    function nav() external view returns (uint256) {
        return (currentPrice * totalShares()) / 1e8;
    }

    /// @notice Total supply of shares
    /// @return uint256 Total supply of shares
    function totalShares() public view returns (uint256) {
        return tempMint + tempBurn + pendingRedemptions + totalSupply();
    }

    /// @notice Sets the limit on USDC accepted per epoch
    /// @param cap_ The new limit on deposits
    function adjustCap(uint256 cap_) external onlyOwner {
        cap = cap_;
    }

    /// @notice Sets the minimum deposit amount
    /// @param min_ The new minimum deposit
    function adjustMin(uint256 min_) external onlyOwner {
        min = min_;
    }

    /// @notice Adds an address to the whitelist
    /// @param account Address to add to the whitelist
    function addToWhitelist(address account) external {
        grantRole(WHITELIST, account);
    }

    /// @notice Process batch of addresses to be whitelisted
    /// @param accounts Address list to add to whitlist
    function batchAddToWhitelist(address[] calldata accounts) external {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; ++i) {
            grantRole(WHITELIST, accounts[i]);
        }
    }

    /// @notice Process batch of addresses to be removed the whitelist
    /// @param account Address to remove from the whitelist
    function removeFromWhitelist(address account) external {
        revokeRole(WHITELIST, account);
    }

    /// @notice Process batch of addresses to be removed from whitelist
    /// @param accounts Address list to remove from whitlist
    function batchRemoveFromWhitelist(address[] calldata accounts) external {
        uint256 length = accounts.length;
        for (uint256 i = 0; i < length; ++i) {
            revokeRole(WHITELIST, accounts[i]);
        }
    }

    /// @notice Checks that the address is a member of the whitelist
    /// @param account Address that placed the order
    /// @return bool Whether the address is a member of the whitelist
    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted(account);
    }

    /// @notice Checks that the address is a member of the whitelist
    /// @param account Address that placed the order
    /// @return bool Whether the address is a member of the whitelist
    function _isWhitelisted(address account) private view returns (bool) {
        return hasRole(WHITELIST, account);
    }

    /// @notice transfer `ETH` to the sender/owner
    function recover() external onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);
    }

    /// @notice transfer `ERC-20` tokens to the sender/owner
    /// @param token_ Asset transferred out
    /// @return bool Status of the transfer
    function recover(address token_) external onlyOwner returns (bool) {
        IERC20 token = IERC20(token_);

        return token.transfer(_msgSender(), token.balanceOf(address(this)));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        require(
            to == address(0) || hasRole(WHITELIST, to),
            "receiver address is not in the whitelist"
        );

        require(
            from == address(0) || hasRole(WHITELIST, from),
            "sender address is not in the whitelist"
        );
    }

    function _burnFrom(address account, uint256 amount) private {
        _spendAllowance(account, address(this), amount);
        _burn(account, amount);
    }
}
