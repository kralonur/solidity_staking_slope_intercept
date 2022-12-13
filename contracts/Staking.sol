//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IStaking.sol";
import "hardhat/console.sol";
import "@prb/math/src/UD60x18.sol";

contract Staking is IStaking, AccessControl {
    using SafeERC20 for IERC20Metadata;

    error IncorrectAmount(uint256 amountRequested, uint256 amountAvailable);
    error InsufficientAmount(uint256 amount, uint256 amountRequired);
    error ExecutedEarly(uint256 requiredTime);
    error OnlyStaker();

    /// 100% in basis points
    uint256 public constant MAX_PERCENTAGE = 10000;
    /// Precision for ppt
    uint256 public constant PRECISION = 1e18;
    /// 1 year in seconds
    uint256 public constant YEAR = 365 * 24 * 60 * 60;

    /// Total staked to the contract
    uint256 public totalStaked;
    /// Total reward produced
    uint256 public rewardProduced;
    /// Minimum amount for claiming rewards
    uint256 public minClaimAmount;
    /// Lock period for staked tokens
    uint256 public stakeLockPeriod;
    /// Unlock period for claiming rewards
    uint256 public claimUnlockPeriod;
    /// Extend period for sale participation
    uint256 public unstakeExtendPeriod;
    /// Fine percentage for unstaking early (in basis points)
    uint256 public earlyUnstakeFine;
    /// Index of ppt
    uint256 public parameterIndex;
    /// Treasury address
    address public treasuryAddress;

    /// Staked token
    IERC20Metadata public tokenStaking;

    /**
     * @dev This struct holds information about staker
     * @param amountStaked Amount staked
     * @param availableReward Available reward for the stake holder
     * @param unstakeTime Timestamp to unstake
     * @param lastUpdateTime Stakers latest update time
     */
    struct Staker {
        uint256 amountStaked;
        uint256 availableReward;
        uint128 unstakeTime;
        uint128 lastUpdateTime;
    }

    /**
     * @dev This struct holds information about calculation parameters
     * @param minAmount The minimum amount to get min apy
     * @param minApy The minimum apy to earn yearly
     * @param maxAmount The maximum amount to get max apy
     * @param maxApy The maximum apy to earn yearly
     * @param startTime Start timestamp of parameter
     * @param endTime End timestamp of parameter
     */
    struct Parameter {
        uint256 minAmount;
        uint256 minApy;
        uint256 maxAmount;
        uint256 maxApy;
        uint128 startTime;
        uint128 endTime;
    }

    /// A mapping for storing claim timestamp
    mapping(address => uint256) private _claimTimes;
    /// A mapping for storing staker information
    mapping(address => Staker) private _stakers;
    /// A mapping for storing parameters
    mapping(uint256 => Parameter) private _parameters;

    /**
     * @dev Emitted when stake holder staked tokens
     * @param stakeHolder The address of the stake holder
     * @param amount The amount staked
     */
    event Staked(address indexed stakeHolder, uint256 amount);

    /**
     * @dev Emitted when stake holder unstaked tokens
     * @param stakeHolder The address of the stake holder
     * @param amount The amount unstaked
     */
    event Unstaked(address indexed stakeHolder, uint256 amount);

    /**
     * @dev Emitted when stake holder claimed reward tokens
     * @param stakeHolder The address of the stake holder
     * @param amount The amount of reward tokens claimed
     */
    event Claimed(address indexed stakeHolder, uint256 amount);

    /**
     * @dev Emitted when stake holder unstake tokens before unstake time
     * @param stakeHolder The address of the stake holder
     * @param amount The amount unstaked
     * @param fine The amount fined
     * @param burnedRewards The burned rewards amount
     */
    event EmergencyUnstaked(address indexed stakeHolder, uint256 amount, uint256 fine, uint256 burnedRewards);

    /**
     * @dev Emitted when parameter updated
     * @param minApy The minimum apy to earn yearly
     * @param minAmount The minimum amount to get min apy
     * @param maxApy The maximum apy to earn yearly
     * @param maxAmount The maximum amount to get max apy
     */
    event ParameterUpdated(uint256 minApy, uint256 minAmount, uint256 maxApy, uint256 maxAmount);

    constructor(
        address _tokenStaking,
        address _treasuryAddress,
        uint256 _minClaimAmount,
        uint256 _stakeLockPeriod,
        uint256 _claimUnlockPeriod,
        uint256 _unstakeExtendPeriod,
        uint256 _earlyUnstakeFine,
        uint256 _minApy,
        uint256 _minAmount,
        uint256 _maxApy,
        uint256 _maxAmount
    ) {
        tokenStaking = IERC20Metadata(_tokenStaking);
        treasuryAddress = _treasuryAddress;

        Parameter storage parameter = _parameters[parameterIndex];
        parameter.startTime = uint128(block.timestamp);
        parameter.minApy = _minApy;
        parameter.minAmount = _minAmount;
        parameter.maxApy = _maxApy;
        parameter.maxAmount = _maxAmount;

        minClaimAmount = _minClaimAmount;
        stakeLockPeriod = _stakeLockPeriod;
        claimUnlockPeriod = _claimUnlockPeriod;
        unstakeExtendPeriod = _unstakeExtendPeriod;
        earlyUnstakeFine = _earlyUnstakeFine;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyStaker() {
        if (_stakers[msg.sender].amountStaked == 0) revert OnlyStaker();
        _;
    }

    function updateTreasuryAddress(address _treasuryAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasuryAddress = _treasuryAddress;
    }

    function updateMinClaimAmount(uint256 _minClaimAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minClaimAmount = _minClaimAmount;
    }

    function updateStakeLockPeriod(uint256 _stakeLockPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        stakeLockPeriod = _stakeLockPeriod;
    }

    function updateClaimUnlockPeriod(uint256 _claimUnlockPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimUnlockPeriod = _claimUnlockPeriod;
    }

    function updateUnstakeExtendPeriod(uint256 _unstakeExtendPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        unstakeExtendPeriod = _unstakeExtendPeriod;
    }

    function updateEarlyUnstakeFine(uint256 _earlyUnstakeFine) external onlyRole(DEFAULT_ADMIN_ROLE) {
        earlyUnstakeFine = _earlyUnstakeFine;
    }

    function updateParameter(
        uint256 minApy,
        uint256 minAmount,
        uint256 maxApy,
        uint256 maxAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _parameters[parameterIndex].endTime = uint128(block.timestamp);

        parameterIndex++;
        Parameter storage parameter = _parameters[parameterIndex];
        parameter.startTime = uint128(block.timestamp);
        parameter.minApy = minApy;
        parameter.minAmount = minAmount;
        parameter.maxApy = maxApy;
        parameter.maxAmount = maxAmount;

        emit ParameterUpdated(minApy, minAmount, maxApy, maxAmount);
    }

    function stake(uint256 amount) external {
        _updateStakerValues();

        totalStaked += amount;

        Staker storage staker = _stakers[msg.sender];
        staker.amountStaked += amount;
        staker.unstakeTime = uint128(block.timestamp + stakeLockPeriod);

        // if its first stake of user set claim unlock period
        if (_claimTimes[msg.sender] == 0) _claimTimes[msg.sender] = block.timestamp + claimUnlockPeriod;

        tokenStaking.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external onlyStaker {
        _updateStakerValues();

        Staker storage staker = _stakers[msg.sender];
        if (amount > staker.amountStaked)
            revert IncorrectAmount({ amountRequested: amount, amountAvailable: staker.amountStaked });
        if (block.timestamp < staker.unstakeTime) revert ExecutedEarly({ requiredTime: staker.unstakeTime });

        totalStaked -= amount;
        staker.amountStaked -= amount;

        tokenStaking.safeTransfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {
        _updateStakerValues();
        Staker storage staker = _stakers[msg.sender];

        if (block.timestamp < _claimTimes[msg.sender]) revert ExecutedEarly({ requiredTime: _claimTimes[msg.sender] });
        if (staker.availableReward < minClaimAmount)
            revert InsufficientAmount({ amount: staker.availableReward, amountRequired: minClaimAmount });

        uint256 reward = staker.availableReward;
        rewardProduced += reward;
        staker.availableReward = 0;

        tokenStaking.safeTransferFrom(treasuryAddress, address(this), reward);
        tokenStaking.safeTransfer(msg.sender, reward);

        emit Claimed(msg.sender, reward);
    }

    function emergencyUnstake() external onlyStaker {
        _updateStakerValues();

        Staker storage staker = _stakers[msg.sender];

        totalStaked -= staker.amountStaked;

        uint256 burnedRewards = staker.availableReward;
        staker.availableReward = 0;

        uint256 fine = (staker.amountStaked * earlyUnstakeFine) / MAX_PERCENTAGE;
        uint256 unstakeAmount = staker.amountStaked - fine;

        staker.amountStaked = 0;

        tokenStaking.safeTransfer(treasuryAddress, fine);
        tokenStaking.safeTransfer(msg.sender, unstakeAmount);

        emit EmergencyUnstaked(msg.sender, unstakeAmount, fine, burnedRewards);
    }

    function getStakerDetails(
        address _staker
    )
        external
        view
        returns (
            uint256 amountStaked,
            uint256 availableReward,
            uint128 unstakeTime,
            uint128 lastUpdateTime,
            uint256 claimTime
        )
    {
        Staker memory staker = _stakers[_staker];
        amountStaked = staker.amountStaked;
        availableReward = staker.availableReward + _calculateTotalRewards(staker);
        unstakeTime = staker.unstakeTime;
        lastUpdateTime = staker.lastUpdateTime;
        claimTime = _claimTimes[_staker];
    }

    function _updateStakerValues() private {
        Staker storage staker = _stakers[msg.sender];

        // if not new user
        if (staker.lastUpdateTime != 0) staker.availableReward += _calculateTotalRewards(staker);

        staker.lastUpdateTime = uint128(block.timestamp);
    }

    function _calculateTotalRewards(Staker memory staker) private view returns (uint256 totalRewards) {
        for (uint256 i = 0; i <= parameterIndex; i++) {
            Parameter memory parameter = _parameters[i];
            if (parameter.endTime != 0 && staker.lastUpdateTime > parameter.endTime) {
                continue;
            }

            uint256 startTime = parameter.startTime;
            if (staker.lastUpdateTime > parameter.startTime) startTime = staker.lastUpdateTime;

            uint256 endTime = parameter.endTime;
            if (parameter.endTime == 0) endTime = block.timestamp;

            uint256 deltaTime = endTime - startTime;
            totalRewards += _calculateRewards(deltaTime, staker.amountStaked, parameter);
        }
    }

    function _calculateRewards(
        uint256 deltaTime,
        uint256 amount,
        Parameter memory parameter
    ) private view returns (uint256 reward) {
        UD60x18 amount_ud = toUD60x18(amount);
        UD60x18 year_ud = toUD60x18(YEAR);
        UD60x18 precision_ud = toUD60x18(PRECISION);

        UD60x18 percentage = _calculatePercentagee(amount, parameter);

        if (percentage.lt(toUD60x18(parameter.minApy))) percentage = toUD60x18(0);

        if (percentage.gt(toUD60x18(parameter.maxApy))) percentage = toUD60x18(parameter.maxApy);

        UD60x18 multiplier = percentage.mul(toUD60x18(deltaTime)).div(year_ud);
        reward = fromUD60x18(amount_ud.mul(multiplier).div(precision_ud));
    }

    function _calculatePercentagee(
        uint256 amount,
        Parameter memory parameter
    ) private view returns (UD60x18 percentage) {
        UD60x18 amount_ud = toUD60x18(amount);

        UD60x18 tokenDecimals = toUD60x18(10 ** tokenStaking.decimals());
        UD60x18 x1 = toUD60x18(parameter.minAmount);
        UD60x18 x2 = toUD60x18(parameter.maxAmount);
        // To ensure apy always have more precision than token, for finding slope
        UD60x18 y1 = toUD60x18(parameter.minApy).mul(tokenDecimals);
        UD60x18 y2 = toUD60x18(parameter.maxApy).mul(tokenDecimals);

        console.log("x1: ", fromUD60x18(x1));
        console.log("y1: ", fromUD60x18(y1));
        console.log("x2: ", fromUD60x18(x2));
        console.log("y2: ", fromUD60x18(y2));

        UD60x18 m = y2.sub(y1).div(x2.sub(x1));
        console.log("m: ", fromUD60x18(m));
        UD60x18 b = y1.sub(x1.mul(m));
        console.log("b: ", fromUD60x18(b));

        percentage = m.mul(amount_ud).add(b).div(tokenDecimals);
        console.log("percentage: ", fromUD60x18(percentage));
    }
}
