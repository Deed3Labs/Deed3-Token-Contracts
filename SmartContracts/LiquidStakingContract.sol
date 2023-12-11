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
        uint256 amount;
        uint256 startTime;
        uint256 lockPeriod;
        uint256 lastClaimTime;
    }
    mapping(address => Stake) public stakingBalances;
    uint256 public totalStaked;

    event Staked(address indexed user, address token, uint256 amount, uint256 lockPeriod);
    event Unstaked(address indexed user, address token, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

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

        stakingBalances[msg.sender] = Stake(amount, block.timestamp, lockPeriod, block.timestamp);
        totalStaked += amount;

        _mint(msg.sender, amount);  // Mint sTokens to represent the staked amount
        emit Staked(msg.sender, token, amount, lockPeriod);
    }

    function claimRewards() external nonReentrant {
        Stake storage userStake = stakingBalances[msg.sender];
        require(userStake.amount > 0, "No tokens staked");

        uint256 reward = calculateReward(msg.sender);
        userStake.lastClaimTime = block.timestamp;

        dddToken.mint(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    function unstake(address token) external nonReentrant {
        Stake memory userStake = stakingBalances[msg.sender];
        require(userStake.amount > 0, "No tokens staked");
        require(block.timestamp >= userStake.startTime + (userStake.lockPeriod * 30 days), "Stake is still locked");

        uint256 amount = userStake.amount;
        totalStaked -= amount;

        claimRewards();  // Automatically claim any outstanding rewards

        _burn(msg.sender, amount);  // Burn sTokens representing the unstaked amount
        ERC20Upgradeable(token).transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, token, amount);

        delete stakingBalances[msg.sender];
    }

    function calculateReward(address staker) internal view returns (uint256) {
        Stake memory userStake = stakingBalances[staker];
        uint256 rewardRate = getRewardRate(userStake.lockPeriod);
        uint256 timeStaked = block.timestamp - userStake.lastClaimTime;
        uint256 reward = (userStake.amount * rewardRate * timeStaked) / (365 days) / 100;
        return reward;
    }

    function getRewardRate(uint256 lockPeriod) public pure returns (uint256) {
        if (lockPeriod == 3) return 25;
        if (lockPeriod == 6) return 50;
        if (lockPeriod == 12) return 75;
        if (lockPeriod == 24) return 100;
        return 125;  // For 60 months
    }

    function batchUnstake(address[] calldata users, address token) external onlyRole(MANAGER_ROLE) nonReentrant {
        for (uint i = 0; i < users.length; i++) {
            Stake memory userStake = stakingBalances[users[i]];
            if(userStake.amount > 0 && block.timestamp >= userStake.startTime + (userStake.lockPeriod * 30 days)) {
                uint256 amount = userStake.amount;
                totalStaked -= amount;

                uint256 reward = calculateReward(users[i]);
                dddToken.mint(users[i], reward);

                _burn(users[i], amount); // Burn sTokens
                ERC20Upgradeable(token).transfer(users[i], amount + reward);

                emit RewardClaimed(users[i], reward);
                emit Unstaked(users[i], token, amount);

                delete stakingBalances[users[i]];
            }
        }
    }

}
