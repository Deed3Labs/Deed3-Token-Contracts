// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title The Deed3 Equity Token (DDD)
 * @dev This contract implements an upgradable ERC20 token with ownership and roles managed via AccessControl.
 */
contract TheDeed3EquityToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
    // Define a role for minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev Initializes the contract with token details and sets up roles.
     */
    function initialize(address multisigWalletAddress) public initializer {
        __ERC20_init("The Deed3 Equity Token", "DDD");
        __AccessControl_init();

        // Set up the default admin role to the multisig wallet
        _setupRole(DEFAULT_ADMIN_ROLE, multisigWalletAddress);

        // Optionally, you can also grant the MINTER_ROLE to the multisig wallet initially
        _setupRole(MINTER_ROLE, multisigWalletAddress);
    }

    /**
     * @dev Allows users with the MINTER_ROLE to mint new tokens.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(to != address(0), "Mint to the zero address is not allowed");
        require(amount > 0, "Mint amount must be greater than zero");

        _mint(to, amount);
    }

    /**
     * @dev Override of AccessControl's renounceRole to prevent renouncing the DEFAULT_ADMIN_ROLE.
     * This ensures that the default admin role cannot be renounced accidentally.
     * @param role The role to be renounced.
     * @param account The account renouncing its role.
     */
    function renounceRole(bytes32 role, address account) public override {
        require(role != DEFAULT_ADMIN_ROLE, "Cannot renounce the default admin role");
        super.renounceRole(role, account);
    }
}
