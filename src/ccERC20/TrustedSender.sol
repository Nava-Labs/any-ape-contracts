// SPDX-License-Identifier: MIT
// TrustedSender Contracts v0.0.1
// Creator: Nava Labs

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BytesLib} from "./BytesLib.sol";

contract TrustedSender is Ownable {

    using BytesLib for bytes;

    mapping(uint64 chainId => bytes) internal trustedSenderLookup;

    /**
     * @dev Emitted when Trusted Sender is set
     */
    event SetTrustedSenderAddress(uint64 _senderChainId, bytes _senderAddress);

    /**
     * set trusted sender in specific chain
     */
    function setTrustedSenderAddress(uint64 _remoteChainId, bytes calldata _remoteAddress) external onlyOwner {
        trustedSenderLookup[_remoteChainId] = abi.encodePacked(_remoteAddress, address(this));
        emit SetTrustedSenderAddress(_remoteChainId, _remoteAddress);
    }

    /**
     * Returns the trusted sender in specific chain
     */
    function getTrustedSenderAddress(uint64 _senderChainId) external view returns (bytes memory) {
        bytes memory path = trustedSenderLookup[_senderChainId];
        require(path.length != 0, "LzApp: no trusted path record");
        return path.slice(0, path.length - 20); // the last 20 bytes should be address(this)
    }

 }