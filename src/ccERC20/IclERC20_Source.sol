// SPDX-License-Identifier: MIT
// clERC20_Source Contracts v0.0.1
// Creator: Nava Labs

pragma solidity ^0.8.19;

/**
 * @dev Interface of clERC20_Source.
 */
interface IclERC20_Source {
    /**
     * SYNC FAILED For ACTIVE_SUPPLY
     */
    error SyncFailedForActiveToken();

    /**
     * SYNC FAILED for DEACTIVE_SUPPLY
     */
    error SyncFailedForDeactiveToken();

    // =============================================================
    //                            Structs
    // =============================================================

    struct SupplyMetadata {
        // Chainlink Chain Id.
        uint64 chainId;
        // Active Supply
        uint256 activeSupply;
        // Deactive Supply
        uint256 deactiveSupply;
        // last updated
        uint256 lastUpdated;
    }

    // =============================================================
    //                           Transform
    // =============================================================

    /**
     * Returns the total supply of active ERC20 in accross all chain
     */ 
    function transform(address receiver, uint256 amount) external;

    // =============================================================
    //                         clERC20 SUPPLY
    // =============================================================

    /**
     * Returns the total supply of active ERC20 in accross all chain
     */
    function retriveActiveTotalSupply() external view returns (uint256);

    /**
     * Returns the total supply of active ERC20 in specific chain
     */
    function retriveActiveTotalSupplyInSpecificChain(uint64 chainId) external view returns (uint256);

    /**
     * Returns the SupplyMetadata
     */
    function retriveSupplyMetadataInSpecificChain(uint64 chainId) external view returns (SupplyMetadata memory);

    /**
     * Returns the total supply of deactive ERC20 in accross all chain
     */
    function retriveDeactiveTotalSupply() external view returns (uint256);

    /**
     * Returns the total supply of active ERC20 in specific chain
     */
    function retriveDeactiveTotalSupplyInSpecificChain(uint64 chainId) external view returns (uint256);

    /**
     * @dev Emitted when ERC20 is burned
     */
    event Transform(address indexed initiator, uint256 indexed amount);

    /**
     * @dev Emitted when ERC20 is burned
     */
    event Unlock(uint256 indexed action, address indexed to, uint256 indexed amount);

    /**
     * @dev Emitted when Supply changes
     */
    event Sync(uint256 indexed timestamp, uint64 indexed chainId);
}