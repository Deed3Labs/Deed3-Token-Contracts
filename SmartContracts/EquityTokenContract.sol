// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title The Deed3 Equity Token (DDD)
 * @dev Implements an upgradable ERC20 token with role-based access control.
 */
contract TheDeed3EquityToken is ERC20Upgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Initializes the contract with token details and sets up roles.
     * @param multisigWalletAddress The address that will have the default admin role.
     */
    function initialize(address multisigWalletAddress) public initializer {
        __ERC20_init("The Deed3 Equity Token", "DDD");
        __AccessControl_init();

        // Set up the default admin role
        _setupRole(DEFAULT_ADMIN_ROLE, multisigWalletAddress);

        // Grant MINTER_ROLE to the multisig wallet initially
        _setupRole(MINTER_ROLE, multisigWalletAddress);
    }

    /**
     * @dev Mints new tokens. Access restricted to addresses with the MINTER_ROLE.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(to != address(0), "Mint to the zero address is not allowed");
        require(amount > 0, "Mint amount must be greater than zero");

        _mint(to, amount);
    }

    /**
     * @dev Prevents renouncing of the DEFAULT_ADMIN_ROLE to ensure continued control over the contract.
     * @param role The role to be renounced.
     * @param account The account renouncing its role.
     */
    function renounceRole(bytes32 role, address account) public override {
        require(role != DEFAULT_ADMIN_ROLE, "Cannot renounce the default admin role");
        super.renounceRole(role, account);
    }

}
