// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ICustomToken {
    function mint(address to, uint256 amount) external;
}

contract LiquidStakingContract is Initializable, ERC20Upgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    ICustomToken public dddToken;
    mapping(address => bool) public whitelistedTokens;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct Stake {
        uint256 originalAmount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 lastClaimTime;
    }
    mapping(address => Stake) public stakingBalances;
    uint256 public totalStaked;

    event Staked(address indexed user, address token, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, address token, uint256 amount);
    event sTokensClaimed(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    function initialize(address _dddTokenAddress, address multisigAddress) public initializer {
        __ERC20_init("StakingToken", "sDDD");
        __ReentrancyGuard_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, multisigAddress);
        _setupRole(MANAGER_ROLE, multisigAddress);

        dddToken = ICustomToken(_dddTokenAddress);
    }

    function addTokenToWhitelist(address token) external onlyRole(MANAGER_ROLE) {
        whitelistedTokens[token] = true;
    }

    function removeTokenFromWhitelist(address token) external onlyRole(MANAGER_ROLE) {
        whitelistedTokens[token] = false;
    }

    function stake(address token, uint256 amount, uint256 lockPeriod) external nonReentrant {
        require(whitelistedTokens[token], "Token not whitelisted");
        require(amount > 0, "Cannot stake 0");
        require(lockPeriod == 3 || lockPeriod == 6 || lockPeriod == 12 || lockPeriod == 24 || lockPeriod == 60, "Invalid lock period");

        ERC20Upgradeable(token).transferFrom(msg.sender, address(this), amount);
        totalStaked += amount;

        uint256 currentReward = calculateReward(amount, lockPeriod, block.timestamp, block.timestamp);
        stakingBalances[msg.sender] = Stake(amount, block.timestamp, lockPeriod, block.timestamp);
        _mint(msg.sender, amount + currentReward);  // Mint sTokens representing the staked amount + initial reward

        emit Staked(msg.sender, token, amount, lockPeriod);
    }

    function claimRewards() external {
        Stake storage userStake = stakingBalances[msg.sender];
        require(userStake.originalAmount > 0, "No tokens staked");

        uint256 currentReward = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
        userStake.lastClaimTime = block.timestamp;

        _mint(msg.sender, currentReward);  // Mint additional sTokens representing new rewards
        emit sTokensClaimed(msg.sender, currentReward);
    }

    function unstake(address token, uint256 sTokenAmount) external nonReentrant {
        Stake storage userStake = stakingBalances[msg.sender];
        require(userStake.originalAmount > 0, "No tokens staked");
        require(block.timestamp >= userStake.startTime + (userStake.lockPeriod * 30 days), "Stake is still locked");
        
        uint256 totalRewards = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
        uint256 totalStakeValue = userStake.originalAmount + totalRewards;
        require(sTokenAmount <= totalStakeValue, "Insufficient sTokens");

        // Calculate the proportional original amount and rewards to withdraw
        uint256 originalAmountToWithdraw = (userStake.originalAmount * sTokenAmount) / totalStakeValue;
        uint256 rewardToWithdraw = (totalRewards * sTokenAmount) / totalStakeValue;

        totalStaked -= originalAmountToWithdraw;

        _burn(msg.sender, sTokenAmount);  // Burn sTokens representing the unstaked amount
        ERC20Upgradeable(token).transfer(msg.sender, originalAmountToWithdraw);
        dddToken.mint(msg.sender, rewardToWithdraw);  // Mint DDD tokens representing the reward

        if (totalStakeValue == sTokenAmount) {
            delete stakingBalances[msg.sender];
        } else {
            userStake.originalAmount -= originalAmountToWithdraw;
        }

        emit Unstaked(msg.sender, token, originalAmountToWithdraw);
    }

    function redeemForTokens(address user, uint256 sTokenAmount) external onlyRole(MANAGER_ROLE) nonReentrant {
        require(balanceOf(user) >= sTokenAmount, "Insufficient sTokens");
        Stake storage userStake = stakingBalances[user];
        require(userStake.originalAmount > 0, "No tokens staked");

        uint256 totalRewards = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
        uint256 totalStakeValue = userStake.originalAmount + totalRewards;
        require(sTokenAmount <= totalStakeValue, "Insufficient sTokens");

        // Calculate the proportional original amount and rewards to withdraw
        uint256 originalAmountToWithdraw = (userStake.originalAmount * sTokenAmount) / totalStakeValue;
        uint256 rewardToWithdraw = (totalRewards * sTokenAmount) / totalStakeValue;

        totalStaked -= originalAmountToWithdraw;

        _burn(user, sTokenAmount);  // Burn sTokens
        dddToken.mint(user, rewardToWithdraw);  // Mint DDD tokens representing the reward

        if (totalStakeValue == sTokenAmount) {
            delete stakingBalances[user];
        } else {
            userStake.originalAmount -= originalAmountToWithdraw;
        }

        emit Redeemed(user, originalAmountToWithdraw);
    }

    function batchUnstake(address[] calldata users, address token, uint256[] calldata sTokenAmounts) external onlyRole(MANAGER_ROLE) nonReentrant {
        require(users.length == sTokenAmounts.length, "Mismatch in array lengths");

        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 sTokenAmount = sTokenAmounts[i];

            Stake storage userStake = stakingBalances[user];
            if (userStake.originalAmount > 0 && block.timestamp >= userStake.startTime + (userStake.lockPeriod * 30 days)) {
                uint256 totalRewards = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
                uint256 totalStakeValue = userStake.originalAmount + totalRewards;
                require(sTokenAmount <= totalStakeValue, "Insufficient sTokens");

                // Calculate the proportional original amount and rewards to withdraw
                uint256 originalAmountToWithdraw = (userStake.originalAmount * sTokenAmount) / totalStakeValue;
                uint256 rewardToWithdraw = (totalRewards * sTokenAmount) / totalStakeValue;

                totalStaked -= originalAmountToWithdraw;

                _burn(user, sTokenAmount);  // Burn sTokens
                ERC20Upgradeable(token).transfer(user, originalAmountToWithdraw);
                dddToken.mint(user, rewardToWithdraw);  // Mint DDD tokens representing the reward

                if (totalStakeValue == sTokenAmount) {
                    delete stakingBalances[user];
                } else {
                    userStake.originalAmount -= originalAmountToWithdraw;
                }

                emit Unstaked(user, token, originalAmountToWithdraw);
            }
        }
    }

    function calculateReward(uint256 amount, uint256 lockPeriod, uint256 fromTime, uint256 toTime) internal pure returns (uint256) {
        uint256 rewardRate = getRewardRate(lockPeriod);
        uint256 timeStaked = toTime - fromTime;
        uint256 reward = (amount * rewardRate * timeStaked) / (365 days) / 100;
        return reward;
    }

    function getRewardRate(uint256 lockPeriod) public pure returns (uint256) {
        if (lockPeriod == 3) return 25;
        if (lockPeriod == 6) return 50;
        if (lockPeriod == 12) return 75;
        if (lockPeriod == 24) return 100;
        return 125;  // For 60 months
    }
}
