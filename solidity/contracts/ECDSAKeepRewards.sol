pragma solidity ^0.5.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ECDSAKeepRewards {

    IERC20 keepToken;
    IBondedECDSAKeepFactory factory;

    // Total number of keep tokens to distribute.
    uint256 totalRewards;
    // Length of one interval.
    uint256 termLength;
    // Timestamp of first interval beginning.
    uint256 initiated;
    // Minimum number of keep submissions for each interval.
    uint256 minimumSubmissions;
    // Array representing the percentage of total rewards available for each term.
    uint8[] InitialTermWeights = [8, 33, 21, 14, 9, 5, 3, 2, 2, 1, 1, 1]; // percent array

    // Total number of intervals.
    uint256 termCount = InitialTermWeights.length;

    // mapping of keeps to booleans. True if the keep has been used to calim a reward.
    mapping(address => bool) claimed;

    // Number of submissions for each interval.
    mapping(uint256 => uint256) intervalSubmissions;

    // Array of timestamps marking interval's end.
    uint256[] intervalEndpoints;

    constructor (
        uint256 _termLength,
        uint256 _totalRewards,
        address _keepToken,
        uint256 _minimumSubmissions,
        address factoryAddress
    )
    public {
       keepToken = IERC20(_keepToken);
       totalRewards = _totalRewards;
       termLength = _termLength;
       initiated = block.timestamp;
       minimumSubmissions = _minimumSubmissions;
       factory = IBondedECDSAKeepFactory(factoryAddress);
    }

    /// @notice Sends the reward for a keep to the keep owner.
    /// @param _keepAddress ECDSA keep factory address.
    function receiveReward(address _keepAddress) public {
        require(eligibleForReward(_keepAddress));
        require(!claimed[_keepAddress],"Reward already claimed.");
        claimed[_keepAddress] = true;

        IBondedECDSAKeep _keep =  IBondedECDSAKeep(_keepAddress);
        uint256 timestampOpened = _keep.getTimestamp();
        uint256 interval = findInterval(timestampOpened);
        uint256 intervalReward = termReward(interval);
        keepToken.transfer(_keep.getOwner(), intervalReward);
    }


    /// @notice Get the rewards interval a given timestamp falls unnder.
    /// @param _timestamp The timestamp to check.
    /// @return The associated interval.
    function findInterval(uint256 _timestamp) public returns (uint256){
        // provide index/rewards interval and validate on-chain?
        // if interval exists, return it. else updateInterval()
        return updateInterval(_timestamp);
    }

    /// @notice Get the reward dividend for each keep for a given reward interval.
    /// @param term The term to check.
    /// @return The reward dividend.
    function termReward(uint256 term) public view returns (uint256){
        uint256 _totalTermRewards = totalRewards * InitialTermWeights[term] / 100;
        return _totalTermRewards / intervalSubmissions[term];
    }

    /// @notice Updates the latest interval.
    /// @dev Interval should only be updated if the _timestamp provided
    ///      does not belong to a pre-existing interval.
    /// @param _timestamp The timestamp to update with.
    /// @return the new interval.
    function updateInterval(uint256 _timestamp) internal returns (uint256){
        require(
            block.timestamp - initiated >= termLength * intervalEndpoints.length + termLength,
            "not due for new interval"
        );
        uint256 intervalEndpointsLength = intervalEndpoints.length;
        uint256 newInterval = findEndpoint(_timestamp);
        // uint256 newInterval = intervalEndpointsLength > 0 ?
        // find(0, factory.getKeepCount(), _timestamp):
        // find(intervalEndpoints[intervalEndpointsLength - 1], factory.getKeepCount(), _timestamp);

        uint256 totalSubmissions = intervalEndpointsLength > 0 ?
        newInterval:
        newInterval - intervalEndpoints[intervalEndpointsLength - 1];

        intervalSubmissions[intervalEndpointsLength] = totalSubmissions;
        if (totalSubmissions < minimumSubmissions){
            if(intervalEndpointsLength >= InitialTermWeights.length){
                return newInterval;
            }
            InitialTermWeights[intervalEndpointsLength + 1] +=  InitialTermWeights[intervalEndpointsLength];
            InitialTermWeights[intervalEndpointsLength] = 0;
        }
        return newInterval;
    }

    /// @notice Checks if a keep is eligible to receive rewards.
    /// @dev Keeps that close dishonorably or early are not eligible for rewards.
    /// @param _keep The keep to check.
    /// @return True if the keep is eligible, false otherwise
    function eligibleForReward(address _keep) public view returns (bool){
        // check that keep closed properly
        return true;
    }

    function findEndpoint(uint256 intervalEndpoint) public view returns (uint256) {
        require(
            intervalEndpoint <= currentTime(),
            "interval hasn't ended yet"
        );
        uint256 keepCount = factory.getKeepCount();
        // no keeps created yet -> return 0
        if (keepCount == 0) {
            return 0;
        }

        uint256 lb = 0; // lower bound, inclusive
        uint256 timestampLB = factory.getCreationTime(factory.getKeepAtIndex(lb));
        // all keeps created after the interval -> return 0
        if (timestampLB >= intervalEndpoint) {
            return 0;
        }

        uint256 ub = keepCount - 1; // upper bound, inclusive
        uint256 timestampUB = factory.getCreationTime(factory.getKeepAtIndex(ub));
        // all keeps created in or before the interval -> return next keep
        if (timestampUB < intervalEndpoint) {
            return keepCount;
        }

        // The above cases also cover the case
        // where only 1 keep has been created;
        // lb == ub
        // if it was created after the interval, return 0
        // otherwise, return 1

        return _find(lb, timestampLB, ub, timestampUB, intervalEndpoint);
    }

    // Invariants:
    //   lb >= 0, lbTime < target
    //   ub < keepCount, ubTime >= target
    function _find(
        uint256 lb,
        uint256 lbTime,
        uint256 ub,
        uint256 ubTime,
        uint256 target
    ) internal view returns (uint256) {
        uint256 len = ub - lb;
        while (len > 1) {
            // ub >= lb + 2
            // mid > lb
            uint256 mid = lb + (len / 2);
            uint256 midTime = factory.getCreationTime(factory.getKeepAtIndex(mid));

            if (midTime >= target) {
                ub = mid;
                ubTime = midTime;
            } else {
                lb = mid;
                lbTime = midTime;
            }
            len = ub - lb;
        }
        return ub;
    }

   function tt(uint256 ind) public view returns (uint256) {
    return factory.getKeepCount();
}
   function currentTime() public view returns (uint256) {
       return block.timestamp;
   }
}

interface IBondedECDSAKeep {
    function getOwner() external view returns (address);
    function getTimestamp() external view returns (uint256);
}

interface IBondedECDSAKeepFactory {
    function getKeepCount() external view returns (uint256);
    function getKeepAtIndex(uint256 index) external view returns (address);
    function getCreationTime(address _keep) external view returns (uint256);
}
