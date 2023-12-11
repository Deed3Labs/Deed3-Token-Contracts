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
    mapping(address => uint256) public rewardBalances;

    event Staked(address indexed user, address token, uint256 amount);
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

    function stake(address token, uint256 amount) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");
        require(amount > 0, "Cannot stake 0");

        ERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount);
        stakingBalances[msg.sender] += amount;

        // Mint sTokens to represent the staked amount
        _mint(msg.sender, amount);

        emit Staked(msg.sender, token, amount);
    }

    function unstake(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot unstake 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");

        stakingBalances[msg.sender] -= amount;
        rewardBalances[msg.sender] += calculateRewards(msg.sender);

        // Burn sTokens representing the unstaked amount
        _burn(msg.sender, amount);

        ERC20Upgradeable(token).transfer(msg.sender, amount);
        emit Unstaked(msg.sender, token, amount);
    }

    function calculateRewards(address staker) internal returns (uint256) {
        // Implement your reward calculation logic here
        // This function should update `rewardBalances[staker]` and return the calculated reward
        uint256 rewards = ...; // Calculated rewards
        rewardBalances[staker] += rewards;
        return rewards;
    }

    function claimRewards() external nonReentrant {
        uint256 rewards = rewardBalances[msg.sender];
        require(rewards > 0, "No rewards to claim");

        dddToken.mint(msg.sender, rewards);
        rewardBalances[msg.sender] = 0;
    }

    function distributeRewards() external onlyOwner {
        // Implement the logic to distribute rewards to all stakers
        // This might involve iterating over all stakers and calling `calculateRewards`
        emit RewardsDistributed(...); // Total distributed rewards
    }
}
