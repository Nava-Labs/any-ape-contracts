// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "../utils/Withdraw.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Unauthorized();

interface IBridgedApe {
    function burnAndMintOrUnlock(uint64 destinationChainSelector, address messageReceiver, address tokenReceiver, uint256 amount) external;
}

contract AnyApe_Destination is CCIPReceiver, Withdraw {

    uint64 constant SOURCE_CHAIN_SELECTOR = 12532609583862916517; // mumbai
    uint64 constant DEST_CHAIN_SELECTOR = 14767482510784806043; // fuji

    address public anyApeMessageReceiver;
    address public apeTokenMessageReceiver;

    address immutable i_router;
    address immutable i_link;
    address immutable public APE;

    // Native will be done through AnyApe_Source contract
    enum SaleType {
        Native,
        CrossChain
    }

    struct ListingDetails {
        address listedBy;
        uint256 price;
    }
    // data contains should be eq to source chain
    mapping(address => mapping(uint256 => ListingDetails)) private _listingDetails; // tokenAddress => tokenId => ListingDetails

    struct CrossChainSale {
        address newOwner;
    }

    event Sale(
        SaleType indexed saleType,
        address indexed tokenAddress, 
        address indexed newOwner, 
        address prevOwner, 
        uint256 tokenId,
        uint256 price
    );

    event MessageSent(bytes32 messageId, bytes data);

    event MessageReceived(bytes32 messageId, bytes data);

    constructor(address router, address link, address ape) CCIPReceiver(router) {
        i_router = router;
        i_link = link;
        APE = ape;

        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}   

    function updateMessageReceiverAddress(address _anyApeMessageReceiver, address _apeTokenMessageReceiver) external onlyOwner {
        anyApeMessageReceiver = _anyApeMessageReceiver;
        apeTokenMessageReceiver = _apeTokenMessageReceiver;
    }
   
    function crossChainSale(address tokenAddress, uint256 tokenId) external {    
        ListingDetails memory detail = _listingDetails[tokenAddress][tokenId];
        IERC20(APE).transferFrom(msg.sender, address(this), detail.price);

        IBridgedApe(APE).burnAndMintOrUnlock(SOURCE_CHAIN_SELECTOR, apeTokenMessageReceiver, detail.listedBy, detail.price);

        _listingDetails[tokenAddress][tokenId] = ListingDetails ({
            listedBy: address(0),
            price: 0
        });

        bytes memory data = _encodeCrossChainSaleData(tokenAddress, tokenId, msg.sender);
        _sendCrossChainSaleMessage(SOURCE_CHAIN_SELECTOR, data);

        emit Sale(SaleType.CrossChain, tokenAddress, msg.sender, detail.listedBy, tokenId, detail.price);
    }

    function checkListedNftDetailsOnSourceChain(address tokenAddress, uint256 tokenId) external view returns (ListingDetails memory) {
        return _listingDetails[tokenAddress][tokenId];
    }

    function _encodeCrossChainSaleData(address tokenAddress, uint256 tokenId, address _newOwner) internal view returns (bytes memory) {
        CrossChainSale memory ccSale = CrossChainSale ({
            newOwner: _newOwner
        });
        return abi.encode(tokenAddress, tokenId, _listingDetails[tokenAddress][tokenId], ccSale);
    }

    function _decodeListingData(bytes memory data) internal pure returns (
        address tokenAddress, 
        uint256 tokenId,
        ListingDetails memory detail) 
    {
        (tokenAddress, tokenId, detail) = abi.decode(data, (address, uint256, ListingDetails));
    }

    function _sendCrossChainSaleMessage(
        uint64 destinationChainSelector,
        bytes memory data
    ) internal returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(anyApeMessageReceiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: i_link
        });

        messageId = IRouterClient(i_router).ccipSend(
            destinationChainSelector,
            message
        );

        emit MessageSent(messageId, data);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (address tokenAddress, uint256 tokenId, ListingDetails memory detail) = _decodeListingData(message.data);

        _listingDetails[tokenAddress][tokenId] = detail;
            
        emit MessageReceived(message.messageId, message.data);
    }
    
}
