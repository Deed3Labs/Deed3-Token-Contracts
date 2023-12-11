// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ICustomToken {
    function mint(address to, uint256 amount) external;
}

contract LiquidStakingContract is ERC20Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    ICustomToken public dddToken;
    mapping(address => bool) public whitelistedTokens;
    mapping(address => uint256) public stakingBalances;
    
    event Staked(address indexed user, address token, uint256 amount, uint256 totalBalance);
    event Unstaked(address indexed user, address token, uint256 amount);

    function initialize(address _dddTokenAddress) public initializer {
        __ERC20_init("StakingToken", "sDDD");
        __ReentrancyGuard_init();
        __Ownable_init();

        dddToken = ICustomToken(_dddTokenAddress);
    }

    function addTokenToWhitelist(address token) external onlyOwner {
        whitelistedTokens[token] = true;
    }

    function removeTokenFromWhitelist(address token) external onlyOwner {
        whitelistedTokens[token] = false;
    }

    function stake(address token, uint256 amount) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");
        require(amount > 0, "Cannot stake 0");

        // Transfer tokens to this contract for staking
        ERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount);

        // Update staking balance
        stakingBalances[msg.sender] += amount;

        // Mint sTokens to staker
        _mint(msg.sender, amount);

        emit Staked(msg.sender, token, amount, stakingBalances[msg.sender]);
    }

    function unstake(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(stakingBalances[msg.sender] >= amount, "Insufficient staking balance");

        // Update staking balance
        stakingBalances[msg.sender] -= amount;

        // Burn sTokens
        _burn(msg.sender, amount);

        // Return staked tokens to user
        ERC20Upgradeable(token).transfer(msg.sender, amount);

        emit Unstaked(msg.sender, token, amount);
    }

    function distributeRewards(address[] calldata stakers, uint256[] calldata rewards) external onlyOwner {
        require(stakers.length == rewards.length, "Stakers and rewards length mismatch");

        for (uint256 i = 0; i < stakers.length; i++) {
            dddToken.mint(stakers[i], rewards[i]);
        }
    }
}
