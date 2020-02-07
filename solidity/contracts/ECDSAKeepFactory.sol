pragma solidity ^0.5.4;

import "./ECDSAKeep.sol";
import "./KeepBonding.sol";
import "./api/IBondedECDSAKeepFactory.sol";
import "./utils/AddressArrayUtils.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "@keep-network/sortition-pools/contracts/BondedSortitionPool.sol";
import "@keep-network/sortition-pools/contracts/BondedSortitionPoolFactory.sol";

// TODO: This is temp.
import "@keep-network/sortition-pools/contracts/api/IStaking.sol";

/// @title ECDSA Keep Factory
/// @notice Contract creating bonded ECDSA keeps.
contract ECDSAKeepFactory is
    IBondedECDSAKeepFactory // TODO: Rename to BondedECDSAKeepFactory
{
    using AddressArrayUtils for address payable[];
    using SafeMath for uint256;

    // Notification that a new keep has been created.
    event ECDSAKeepCreated(
        address keepAddress,
        address payable[] members,
        address owner,
        address application
    );

    // Mapping of pools with registered member candidates for each application.
    mapping(address => address) candidatesPools; // application -> candidates pool

    bytes32 groupSelectionSeed;

    BondedSortitionPoolFactory sortitionPoolFactory;
    IStaking tokenStaking = IStaking(address(666)); // TODO: Take from constructor
    KeepBonding keepBonding;

    uint256 minimumStake = 1; // TODO: Take from setter
    uint256 minimumBond = 1; // TODO: Take from setter

    constructor(address _sortitionPoolFactory, address _keepBonding) public {
        sortitionPoolFactory = BondedSortitionPoolFactory(
            _sortitionPoolFactory
        );
        keepBonding = KeepBonding(_keepBonding);
    }

    /// @notice Register caller as a candidate to be selected as keep member
    /// for the provided customer application.
    /// @dev If caller is already registered it returns without any changes.
    function registerMemberCandidate(address _application) external {
        if (candidatesPools[_application] == address(0)) {
            // This is the first time someone registers as signer for this
            // application so let's create a signer pool for it.
            candidatesPools[_application] = sortitionPoolFactory
                .createSortitionPool(
                tokenStaking,
                keepBonding,
                minimumStake,
                minimumBond
            );
        }

        BondedSortitionPool candidatesPool = BondedSortitionPool(
            candidatesPools[_application]
        );

        address operator = msg.sender;
        if (!candidatesPool.isOperatorInPool(operator)) {
            candidatesPool.joinPool(operator);
        }
    }

    /// @notice Open a new ECDSA keep.
    /// @dev Selects a list of members for the keep based on provided parameters.
    /// A caller of this function is expected to be an application for which
    /// member candidates were registered in a pool.
    /// @param _groupSize Number of members in the keep.
    /// @param _honestThreshold Minimum number of honest keep members.
    /// @param _owner Address of the keep owner.
    /// @param _bond Value of ETH bond required from the keep (wei).
    /// @return Created keep address.
    function openKeep(
        uint256 _groupSize,
        uint256 _honestThreshold,
        address _owner,
        uint256 _bond
    ) external payable returns (address keepAddress) {
        address application = msg.sender;
        address pool = candidatesPools[application];
        require(pool != address(0), "No signer pool for this application");

        // TODO: The remainder will not be bonded. What should we do with it?
        uint256 memberBond = _bond.div(_groupSize);
        require(memberBond > 0, "Bond per member must be greater than zero");

        address[] memory selected = BondedSortitionPool(pool).selectSetGroup(
            _groupSize,
            groupSelectionSeed,
            memberBond
        );

        address payable[] memory members = new address payable[](_groupSize);
        for (uint256 i = 0; i < _groupSize; i++) {
            // TODO: for each selected member, validate staking weight and create,
            // bond. If validation failed or bond could not be created, remove
            // operator from pool and try again.
            members[i] = address(uint160(selected[i]));
        }

        ECDSAKeep keep = new ECDSAKeep(_owner, members, _honestThreshold);

        keepAddress = address(keep);

        for (uint256 i = 0; i < _groupSize; i++) {
            keepBonding.createBond(
                members[i],
                keepAddress,
                uint256(keepAddress),
                memberBond
            );
        }

        emit ECDSAKeepCreated(keepAddress, members, _owner, application);

        // TODO: as beacon for new entry and update groupSelectionSeed in callback

    }
}
