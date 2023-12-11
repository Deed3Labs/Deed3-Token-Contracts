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
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
    }
    mapping(address => Stake) public stakingBalances;
    uint256 public totalStaked;

    event Staked(address indexed user, address token, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, address token, uint256 amount);
    event RewardsDistributed(uint256 totalRewards);

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

    function stake(address token, uint256 amount, uint256 lockPeriod) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");
        require(amount > 0, "Cannot stake 0");
        require(lockPeriod == 3 || lockPeriod == 6 || lockPeriod == 12 || lockPeriod == 24 || lockPeriod == 60, "Invalid lock period");

        ERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount);

        stakingBalances[msg.sender] = Stake(amount, block.timestamp, lockPeriod);
        totalStaked += amount;

        _mint(msg.sender, amount);  // Mint sTokens to represent the staked amount

        emit Staked(msg.sender, token, amount, lockPeriod);
    }

    function unstake(address token) external nonReentrant {
        uint256 amount = stakingBalances[msg.sender].amount;
        require(amount > 0, "No tokens staked");
        require(block.timestamp >= stakingBalances[msg.sender].startTime + (stakingBalances[msg.sender].lockPeriod * 30 days), "Stake is still locked");

        totalStaked -= amount;

        _burn(msg.sender, amount);  // Burn sTokens representing the unstaked amount

        ERC20Upgradeable(token).transfer(msg.sender, amount);
        emit Unstaked(msg.sender, token, amount);

        delete stakingBalances[msg.sender];
    }

    function distributeRewards() external onlyOwner {
        uint256 totalRewards = 0;
        for(uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            Stake memory userStake = stakingBalances[staker];
            uint256 rewardRate = getRewardRate(userStake.lockPeriod);
            uint256 reward = (userStake.amount * rewardRate * (block.timestamp - userStake.startTime)) / (365 days) / 100;
            totalRewards += reward;
            dddToken.mint(staker, reward);
        }
        emit RewardsDistributed(totalRewards);
    }

    function getRewardRate(uint256 lockPeriod) public pure returns (uint256) {
        if (lockPeriod == 3) return 25;
        if (lockPeriod == 6) return 50;
        if (lockPeriod == 12) return 75;
        if (lockPeriod == 24) return 100;
        return 125;  // For 60 months
    }
}
