 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IStakingContract {
    function totalStaked() external view returns (uint256);
}

contract RedemptionContract is Initializable, AccessControlUpgradeable {
    IERC20Upgradeable public sToken;
    IStakingContract public stakingContract;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    event Redeemed(address indexed user, uint256 sTokenAmount, uint256 redeemedAmount);

    function initialize(address _sToken, address _stakingContract, address multisigAddress) public initializer {
        __AccessControl_init();

        sToken = IERC20Upgradeable(_sToken);
        stakingContract = IStakingContract(_stakingContract);

        _setupRole(DEFAULT_ADMIN_ROLE, multisigAddress);
        _setupRole(MANAGER_ROLE, multisigAddress);
    }

    function redeem(uint256 sTokenAmount) external {
        require(sTokenAmount > 0, "Cannot redeem 0 tokens");
        
        uint256 totalStakedFunds = stakingContract.totalStaked();
        uint256 totalSTokens = sToken.totalSupply();
        require(totalSTokens > 0, "No sTokens in circulation");

        uint256 redeemableAmount = (totalStakedFunds * sTokenAmount) / totalSTokens;
        require(redeemableAmount > 0, "Redeemable amount is 0");

        sToken.transferFrom(msg.sender, address(this), sTokenAmount);
        payable(msg.sender).transfer(redeemableAmount);

        emit Redeemed(msg.sender, sTokenAmount, redeemableAmount);
    }

    function withdrawFunds() external onlyRole(MANAGER_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(msg.sender).transfer(balance);
    }

    // Additional functions like adding funds, managing roles, etc., can be implemented here
}
