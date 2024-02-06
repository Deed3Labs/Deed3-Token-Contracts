# Deed3 Token Contracts

This repository contains smart contract code for the Deed3 Token ecosystem, which includes the Deed3 Equity Token Contract, the Deed3 Redemption Contract, and the Deed3 Liquid Staking Contract. These contracts are designed to provide a comprehensive token ecosystem for Deed3 users.

## Deed3 Equity Token (DDD)

### Overview
The Deed3 Equity Token (DDD) is the primary utility token within the Deed3 ecosystem. It represents equity and ownership in the Deed3 platform. The DDD token is implemented as an upgradable ERC20 token with role-based access control.

### Key Features
- Upgradable: The DDD token contract is designed to be upgradable, allowing for future enhancements and improvements.
- Role-Based Access Control: The contract employs role-based access control to manage key functions like minting and locking transfers.
- Locking Transfers: The contract provides the ability to lock and unlock transfers for specific addresses or all token holders.
- Minting Tokens: Authorized addresses with the MINTER_ROLE can mint new DDD tokens.
- Recovery Role: The RECOVERY_ROLE is available for specific addresses to manage recovery operations.

## Deed3 Redemption Contract

### Overview
The Deed3 Redemption Contract facilitates the redemption of "sTokens" for a pro-rata share of the funds contained within the contract. Users can exchange their "sTokens" for the original deposit and rewards accumulated in the Liquid Staking Contract.

### Key Features
- Controlled by Multisig: The contract is controlled by a multisig wallet, allowing for secure and flexible management.
- Integration with Liquid Staking: The contract interacts with the Deed3 Liquid Staking Contract to get real-time updates on staked amounts.
- Exchange "sTokens": Users can exchange "sTokens" for deposits and rewards associated with the Liquid Staking Contract.
- Configurable Parameters: Parameters such as rewards, deposits, and role assignments can be configured by the multisig or designated addresses.

## Deed3 Liquid Staking Contract

### Overview
The Deed3 Liquid Staking Contract allows users to stake DDD tokens or other whitelisted tokens for various lock periods and earn rewards. The contract calculates and distributes rewards periodically based on staked amounts and lock periods.

### Key Features
- Staking Options: Users can lock their tokens for 3, 6, 12, 24, or 60 months, earning rewards based on the lock period.
- Rewards Distribution: Rewards are calculated and distributed periodically, with the option for manual or automatic reward distribution.
- Token Whitelisting: Whitelisted tokens can be staked to earn rewards.
- Role-Based Access Control: The contract uses role-based access control for essential functions like whitelisting tokens and distributing rewards.

## Getting Started

To interact with these contracts or contribute to the Deed3 ecosystem, please refer to the individual contract files for deployment and usage instructions.

## Security and Audits

The security and integrity of the Deed3 Token Contracts are of utmost importance. To ensure the ongoing safety of the system, these contracts will undergo continual security assessments and audits. Any vulnerabilities identified during these assessments will be promptly addressed and publicly listed to maintain transparency and trust in the ecosystem.
