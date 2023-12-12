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
    mapping(address => Stake) public stakingBalances;
    address[] private stakers;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct Stake {
        uint256 originalAmount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 lastClaimTime;
        uint256 totalStakeValue;
    }

    uint256 public totalStaked;

    event Staked(address indexed user, address token, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, address token, uint256 amount);
    event sTokensClaimed(address indexed user, uint256 amount, uint256 reward);
    event Redeemed(uint256 sTokenAmount, uint256 originalAmount, uint256 rewardAmount);

    function initialize(address _dddTokenAddress, address multisigAddress) public initializer {
        __ERC20_init("StakingToken", "sDDD");
        __ReentrancyGuard_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, multisigAddress);
        _grantRole(MANAGER_ROLE, multisigAddress);

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
        stakingBalances[msg.sender] = Stake(amount, block.timestamp, lockPeriod, block.timestamp, amount + currentReward);
        addStaker(msg.sender); // Add staker to the array
        _mint(msg.sender, amount + currentReward);

        emit Staked(msg.sender, token, amount, lockPeriod);
    }

    function claimRewards() external {
        Stake storage userStake = stakingBalances[msg.sender];
        require(userStake.originalAmount > 0, "No tokens staked");

        uint256 currentReward = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
        userStake.lastClaimTime = block.timestamp;
        userStake.totalStakeValue += currentReward;

        _mint(msg.sender, currentReward);
        emit sTokensClaimed(msg.sender, userStake.totalStakeValue, currentReward);
    }

    function unstake(address token, uint256 sTokenAmount) external nonReentrant {
        require(sTokenAmount > 0, "Invalid sToken amount");
        Stake storage userStake = stakingBalances[msg.sender];
        require(userStake.totalStakeValue >= sTokenAmount, "Insufficient sTokens");

        uint256 originalAmountToWithdraw = (userStake.originalAmount * sTokenAmount) / userStake.totalStakeValue;
        uint256 rewardToWithdraw = sTokenAmount - originalAmountToWithdraw;

        userStake.totalStakeValue -= sTokenAmount;
        userStake.originalAmount -= originalAmountToWithdraw;
        totalStaked -= originalAmountToWithdraw;

        if (userStake.totalStakeValue == 0) {
            removeStaker(msg.sender); // Remove staker from the array
        }

        _burn(msg.sender, sTokenAmount);
        ERC20Upgradeable(token).transfer(msg.sender, originalAmountToWithdraw);
        dddToken.mint(msg.sender, rewardToWithdraw);

        emit Unstaked(msg.sender, token, originalAmountToWithdraw);
    }

    function redeemForTokens(uint256 sTokenAmount) external onlyRole(MANAGER_ROLE) nonReentrant {
        require(sTokenAmount > 0, "Invalid sToken amount");
        require(totalStaked >= sTokenAmount, "Insufficient staked amount in contract");

        uint256 remainingSTokenAmount = sTokenAmount;
        for (uint i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            if (remainingSTokenAmount == 0) break;

            Stake storage userStake = stakingBalances[staker];
            if (userStake.totalStakeValue > 0) {
                uint256 redeemableAmount = min(remainingSTokenAmount, userStake.totalStakeValue);
                userStake.totalStakeValue -= redeemableAmount;
                remainingSTokenAmount -= redeemableAmount;

                uint256 rewardAmount = calculateReward(userStake.originalAmount, userStake.lockPeriod, userStake.lastClaimTime, block.timestamp);
                dddToken.mint(staker, rewardAmount); // Mint rewards to the staker

                if (userStake.totalStakeValue == 0) {
                    totalStaked -= userStake.originalAmount;
                    delete stakingBalances[staker];
                    removeStaker(staker); // Remove staker from the array
                }
            }
        }

        require(remainingSTokenAmount == 0, "Redemption amount exceeds available staked tokens");
        emit Redeemed(sTokenAmount, totalStaked, sTokenAmount);
    }

    function batchUnstake(address[] calldata users, address token, uint256[] calldata sTokenAmounts) external onlyRole(MANAGER_ROLE) nonReentrant {
        require(users.length == sTokenAmounts.length, "Mismatch in array lengths");

        for (uint i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 sTokenAmount = sTokenAmounts[i];
            Stake storage userStake = stakingBalances[user];

            require(sTokenAmount > 0 && userStake.totalStakeValue >= sTokenAmount, "Invalid sToken amount or insufficient sTokens");

            uint256 originalAmountToWithdraw = (userStake.originalAmount * sTokenAmount) / userStake.totalStakeValue;
            uint256 rewardToWithdraw = sTokenAmount - originalAmountToWithdraw;

            userStake.totalStakeValue -= sTokenAmount;
            userStake.originalAmount -= originalAmountToWithdraw;
            totalStaked -= originalAmountToWithdraw;

            if (userStake.totalStakeValue == 0) {
                removeStaker(user); // Remove staker from the array
            }

            _burn(user, sTokenAmount);
            ERC20Upgradeable(token).transfer(user, originalAmountToWithdraw);
            dddToken.mint(user, rewardToWithdraw);

            emit Unstaked(user, token, originalAmountToWithdraw);
        }
    }

    function calculateReward(uint256 amount, uint256 lockPeriod, uint256 fromTime, uint256 toTime) internal view returns (uint256) {
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

    function addStaker(address staker) internal {
        stakers.push(staker);
    }

    function removeStaker(address staker) internal {
        for (uint i = 0; i < stakers.length; i++) {
            if (stakers[i] == staker) {
                stakers[i] = stakers[stakers.length - 1];
                stakers.pop();
                break;
            }
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
