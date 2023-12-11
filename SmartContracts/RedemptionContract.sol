// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IStakingContract {
    function totalStaked() external view returns (uint256);
}

contract RedemptionContract is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    IERC20Upgradeable public sToken;
    IStakingContract public stakingContract;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    mapping(address => bool) public whitelistedAddresses;

    event Redeemed(address indexed user, uint256 sTokenAmount, uint256 redeemedAmount);
    event FundsAdded(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event sTokensWithdrawn(address indexed to, uint256 amount);
    event AddressWhitelisted(address indexed addressWhitelisted);

    function initialize(address _sToken, address _stakingContract, address multisigAddress) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        sToken = IERC20Upgradeable(_sToken);
        stakingContract = IStakingContract(_stakingContract);

        _setupRole(DEFAULT_ADMIN_ROLE, multisigAddress);
        _setupRole(MANAGER_ROLE, multisigAddress);
    }

    function redeem(uint256 sTokenAmount) external nonReentrant {
        require(sTokenAmount > 0, "Cannot redeem 0 tokens");
        
        uint256 totalStakedFunds = stakingContract.totalStaked();
        uint256 totalSTokens = sToken.totalSupply();
        require(totalSTokens > 0, "No sTokens in circulation");

        uint256 redeemableAmount = (totalStakedFunds * sTokenAmount) / totalSTokens;
        require(redeemableAmount <= address(this).balance, "Insufficient funds in contract");

        sToken.transferFrom(msg.sender, address(this), sTokenAmount);
        payable(msg.sender).transfer(redeemableAmount);

        emit Redeemed(msg.sender, sTokenAmount, redeemableAmount);
    }

    function withdrawFunds(address to, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount <= address(this).balance, "Insufficient funds in contract");
        payable(to).transfer(amount);
        emit FundsWithdrawn(to, amount);
    }

    function withdrawSTokens(address to, uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(whitelistedAddresses[to], "Address not whitelisted");
        require(amount <= sToken.balanceOf(address(this)), "Insufficient sTokens in contract");
        sToken.transfer(to, amount);
        emit sTokensWithdrawn(to, amount);
    }

    function whitelistAddress(address addr) external onlyRole(MANAGER_ROLE) {
        whitelistedAddresses[addr] = true;
        emit AddressWhitelisted(addr);
    }

    function addFunds() external payable onlyRole(MANAGER_ROLE) {
        emit FundsAdded(msg.sender, msg.value);
    }
}
