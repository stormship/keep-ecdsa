pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "./api/IKeepRegistry.sol";

/// @title Keep Registry
/// @notice Contract handling keeps registry.
/// @dev The keep registry serves the role of the master list and tracks sanctioned
/// vendors. It ensures that only approved contracts are used.
/// TODO: This is a stub contract - needs to be implemented.
contract KeepRegistry is IKeepRegistry, Ownable {
    // Registered keep vendors. Mapping of a keep type to a keep vendor address.
    mapping (string => address) internal keepVendors;

    /// @notice Set a keep vendor contract address for a keep type.
    /// @dev Only contract owner can call this function.
    /// @param _keepType Keep type.
    /// @param _vendorAddress Keep Vendor contract address.
    function setVendor(string calldata _keepType, address _vendorAddress) external onlyOwner {
        keepVendors[_keepType] = _vendorAddress;
    }

    /// @notice Get a keep vendor contract address for a keep type.
    /// @param _keepType Keep type.
    /// @return Keep vendor contract address.
    function getVendor(string calldata _keepType) external view returns (address) {
        // TODO: We should probably refer to vendor via proxy - https://github.com/keep-network/keep-tecdsa/pull/43#discussion_r306207111
        return keepVendors[_keepType];
    }
}