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

contract AnyApe_Source is CCIPReceiver, Withdraw {

    uint64 constant SOURCE_CHAIN_SELECTOR = 12532609583862916517; // mumbai
    uint64 constant DEST_CHAIN_SELECTOR = 14767482510784806043; // fuji

    address public anyApeMessageReceiver;

    address immutable i_router;
    address immutable i_link;
    address immutable public APE;

    // CrossChain will be done through AnyApe_Destination contracts
    enum SaleType {
        Native,
        CrossChain
    }

    struct ListingDetails {
        address listedBy;
        uint256 price;
    }
    mapping(address => mapping(uint256 => ListingDetails)) private _listingDetails; // tokenAddress => tokenId => ListingDetails

    struct CrossChainSale {
        address newOwner;
    }

    event Listing(
        address indexed ownerAddress, 
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 price
    );

    event Sale(
        SaleType indexed saleType,
        address indexed tokenAddress, 
        address indexed newOwner,
        address prevOwner, 
        uint256 tokenId,
        uint256 price
    );

    event Cancel(
        address indexed userAddress, 
        address tokenAddress, 
        uint256 tokenId
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

    function updateMessageReceiverAddress(address _anyApeMessageReceiver) external onlyOwner {
        anyApeMessageReceiver = _anyApeMessageReceiver;
    }

    function listing(address tokenAddress, uint256 tokenId, uint256 _price) external {
        IERC721(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId);

        _listingDetails[tokenAddress][tokenId] = ListingDetails ({
            listedBy: msg.sender,
            price: _price
        });

        bytes memory data = _encodeListingData(tokenAddress, tokenId);
        _sendListingMessage(DEST_CHAIN_SELECTOR, data);

        emit Listing(msg.sender, tokenAddress, tokenId, _price);
    }
    
    function directBuy(address tokenAddress, uint256 tokenId) external {    
        ListingDetails memory detail = _listingDetails[tokenAddress][tokenId];
        IERC20(APE).transferFrom(msg.sender, detail.listedBy, detail.price);
        IERC721(tokenAddress).safeTransferFrom(address(this), msg.sender, tokenId);

        _listingDetails[tokenAddress][tokenId] = ListingDetails ({
            listedBy: address(0),
            price: 0
        });

        bytes memory data = _encodeListingData(tokenAddress, tokenId);
        _sendListingMessage(DEST_CHAIN_SELECTOR, data);

        emit Sale(SaleType.Native, tokenAddress, msg.sender, detail.listedBy, tokenId, detail.price);
    }
        
    function cancelListing(address tokenAddress, uint256 tokenId) external {
        address _listedBy = _listingDetails[tokenAddress][tokenId].listedBy;
        if (msg.sender != _listedBy) {
            revert Unauthorized();
        }

        _listingDetails[tokenAddress][tokenId] = ListingDetails ({
            listedBy: address(0),
            price: 0
        });

        IERC721(tokenAddress).safeTransferFrom(address(this), msg.sender, tokenId);

        bytes memory data = _encodeListingData(tokenAddress, tokenId);
        _sendListingMessage(DEST_CHAIN_SELECTOR, data);

        emit Cancel(msg.sender, tokenAddress, tokenId);
    }

    function checkListedNftDetails(address tokenAddress, uint256 tokenId) external view returns (ListingDetails memory) {
        return _listingDetails[tokenAddress][tokenId];
    }

    function _encodeListingData(address tokenAddress, uint256 tokenId) internal view returns (bytes memory) {
        return abi.encode(tokenAddress, tokenId, _listingDetails[tokenAddress][tokenId]);
    }

    function _decodeCrossChainBuy(bytes memory data) internal pure returns (
        address tokenAddress, 
        uint256 tokenId,
        ListingDetails memory detail,
        CrossChainSale memory ccSale) 
    {
        (tokenAddress, tokenId, detail, ccSale) = abi.decode(data, (address, uint256, ListingDetails, CrossChainSale));
    }

    function _sendListingMessage(
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
        (address tokenAddress, uint256 tokenId, ListingDetails memory newDetail, CrossChainSale memory ccSale) = _decodeCrossChainBuy(message.data);

        ListingDetails memory prevListingDetail = _listingDetails[tokenAddress][tokenId]; 
        _listingDetails[tokenAddress][tokenId] = newDetail;
        IERC721(tokenAddress).safeTransferFrom(address(this), ccSale.newOwner, tokenId);
            
        emit Sale(SaleType.CrossChain, tokenAddress, ccSale.newOwner, prevListingDetail.listedBy, tokenId, prevListingDetail.price);
        emit MessageReceived(message.messageId, message.data);
    }

    function onERC721Received(address operator, address, uint256, bytes calldata) external view returns(bytes4) {
        require(operator == address(this), "token must be staked over list method");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
