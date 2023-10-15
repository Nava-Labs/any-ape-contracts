// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC721A } from "erc721a/ERC721A.sol";

contract MockERC721 is Ownable, ERC721A {
    using Strings for uint256;

    string public baseURI;

    constructor(string memory name, string memory symbol, string memory _uri) ERC721A(name, symbol) {
        baseURI = _uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 0;
    }

    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    function mint(uint256 _quantity) external payable {
        _mint(msg.sender, _quantity);
    }
}