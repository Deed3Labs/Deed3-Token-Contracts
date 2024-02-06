// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/**
 * @title The Deed3 Equity Token (DDD)
 * @dev Implements an upgradable ERC20 token with role-based access control.
 */
contract TheDeed3EquityToken is ERC20Upgradeable, AccessControlUpgradeable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant RECOVERY_ROLE = keccak256("RECOVERY_ROLE"); // New role for recovery purposes
    uint8 private constant DECIMALS = 18;
    
    // Mapping to track locked transfers
    mapping(address => bool) private _lockedTransfers;
    bool private _defaultTransferLock; // Flag to lock/unlock transfers for all token holders by default

    /**
     * @dev Initializes the contract with token details and sets up roles.
     * @param multisigWalletAddress The address that will have the default admin role.
     */
    function initialize(address multisigWalletAddress) public initializer {
        __ERC20_init("The Deed3 Equity Token", "DDD");
        __AccessControl_init();

        // Grant the default admin role to the multisig wallet
        _grantRole(DEFAULT_ADMIN_ROLE, multisigWalletAddress);
        
        // Grant MINTER_ROLE to the multisig wallet initially
        _grantRole(MINTER_ROLE, multisigWalletAddress);
        
        // Grant RECOVERY_ROLE to the multisig wallet initially
        _grantRole(RECOVERY_ROLE, multisigWalletAddress);

        // Lock transfers for all token holders by default
        _defaultTransferLock = true;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @dev Mints new tokens. Access restricted to addresses with the MINTER_ROLE.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint (in wei).
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(to != address(0), "Mint to the zero address is not allowed");
        _mint(to, amount);
    }
    
    /**
     * @dev Locks or unlocks token transfers for all token holders. Access restricted to addresses with the DEFAULT_ADMIN_ROLE.
     * @param lockStatus True to lock transfers, false to unlock transfers.
     */
    function lockAllTransfers(bool lockStatus) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _defaultTransferLock = lockStatus;
    }

    /**
     * @dev Locks token transfers for a specific address. Access restricted to addresses with the DEFAULT_ADMIN_ROLE.
     * @param to The address to lock transfers for.
     */
    function lockTransfer(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _lockedTransfers[to] = true;
    }
    
    /**
     * @dev Unlocks token transfers for a specific address. Access restricted to addresses with the DEFAULT_ADMIN_ROLE.
     * @param to The address to unlock transfers for.
     */
    function unlockTransfer(address to) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _lockedTransfers[to] = false;
    }
    
    /**
     * @dev Checks if transfers are locked for a specific address.
     * @param to The address to check.
     * @return True if transfers are locked, false otherwise.
     */
    function isTransferLocked(address to) public view returns (bool) {
        return _lockedTransfers[to] || _defaultTransferLock;
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
