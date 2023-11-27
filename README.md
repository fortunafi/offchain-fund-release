# Offchain Fund

Smart contract for deploying stablecoin capital into Real World Assets (RWA) investments.

## Introduction

The Fortunafi Offchain Fund enables the automation for the operations of a traditional investment fund (subscriptions, redemptions,
... ) via a smart contract. To invest in the fund, users are able to permissionlessly make stablecoin deposits to receive tokens that represent shares. For redemptions, tokens can be burned by the user
to get USDC returned, pending the following net asset value (NAV) update and liquidity refill.

## Flow of Funds

The sequence of actions between users and the fund administrator:

- User deposits stablecoins or redeems fund shares
- Fund administrator removes any capital from user deposits in the smart contract (cutoff)
- Fund administrator deposits available liquidity for any upcoming redemptions
- Fund administrator updates share price of the fund
- All eligible users are able to process their orders

## Operations

The fund smart contract state is driven by updating the NAV per share by the fund administrator on a regular cadence. Setting the price enables the processing of investor subscriptions and redemptions. User orders are broken up by _epochs_ which auto increment every time the price is updated by the administrator. There are two basic actions a customer is able to perform, _deposits_ and _redemptions_ before the investment cutoff, enforced by the smart contract. The cutoff locks the user to be eligible to receive their issued shares or returned capital in the next price updated. If they miss the cutoff they must wait for an additional update to be eligible to have their deposit or redemption orders processed.

### Deposits

User calls the **deposit** method in which USDC is transferred into the smart contract and the amount they contributed is recorded. Once the new share price of the fund is updated, another function **processDeposit** can be called permissionlessly that will grant them their shares. A user can make as many deposits as they like before the cutoff or after the cutoff if they do not have a pending order from before the cutoff.

### Redemptions

Redemptions work similarly, except that the user may not receive all their capital on the next available update depending on the liquidity available in the fund. A user calls **redeem** and their shares are burned in the smart contract. The amount they redeemed is recorded and they are eligible to receive a pro rata portion of the capital they are owed after the next price update.

## Setup

```
curl -L https://foundry.paradigm.xyz | bash
```

```
forge install
```

If you want to use hardhat tests:

```
npm install
```

## Development

Foundry tests cover all the possible cases that can occur while interacting with functions, or in general flow. To run Foundry tests, use the following cmd:

```
forge test
```

Hardhat tests cover the scenarios presented in the `.xlsx` files in the `data` folder. To run the Hardhat tests, use the following cmd:

```
npx hardhat test
```
