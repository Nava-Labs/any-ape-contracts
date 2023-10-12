// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IclERC20_Source} from "./IclERC20_Source.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";

/**
 * @dev Extension of {ERC20} that properly manage token supply accross chain
 * via Chainlink CCIP.
 * recognized off-chain (via event analysis).
 */
abstract contract clERC20_Source is Ownable, ERC20, CCIPReceiver, IclERC20_Source {

    address private constant x_DEAD_x = 0x000000000000000000000000000000000000dEaD;

    address immutable i_link;

    address immutable public tokenAddress; 

    mapping(uint64 chainId => SupplyMetadata) private _supplyMetadata;

    uint256 private _activeTotalSupply;

    uint256 private _deactiveTotalSupply;

    // =============================================================
    //                            CCIP
    // =============================================================

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes data, // The message being sent.
        uint256 fees // The fees paid for sending the message.
    );

   // Event emitted when a message is received from another chain.
    event MessageReceived(
        bytes32 indexed messageId, // The unique ID of the message.
        uint64 indexed sourceChainSelector, // The chain selector of the source chain.
        address sender, // The address of the sender from the source chain.
        bytes data // The message that was received.
    );

    constructor(address _tokenAddress, address link) {
        tokenAddress = _tokenAddress;
        i_link = link;    
    }

    function transform(address receiver, uint256 amount) external virtual override {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        _mint(receiver, amount);

        emit Transform(msg.sender, amount);
    }
    

    function retriveActiveTotalSupply() external view virtual override returns (uint256) {
        return _activeTotalSupply;
    }

    function retriveActiveTotalSupplyInSpecificChain(uint64 chainId) external view virtual override returns (uint256) {
        return _supplyMetadata[chainId].activeSupply;
    }

    function retriveDeactiveTotalSupplyInSpecificChain(uint64 chainId) external view virtual override returns (uint256) {
        return _supplyMetadata[chainId].deactiveSupply;
    }

    function retriveSupplyMetadataInSpecificChain(uint64 chainId) 
        external 
        view 
        virtual 
        override 
        returns (SupplyMetadata memory) 
    {
        return _supplyMetadata[chainId];
    }

    function retriveDeactiveTotalSupply() external view virtual override returns (uint256) {
        return _deactiveTotalSupply;
    }

    receive() external payable {}

    // =============================================================
    //                            CCIP SEND & RECEIVE
    // =============================================================


    /// @notice Sends data to receiver on the destination chain.
    /// @dev Assumes your contract has sufficient $LINK for covering the fees
    /// @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param amount token amount.
    /// @return messageId The ID of the message that was sent.
    function fly(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) external returns (bytes32 messageId) {
        // lock the real token
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        _activeTotalSupply += amount;

        SupplyMetadata memory _metadata = _supplyMetadata[destinationChainSelector];
        _supplyMetadata[destinationChainSelector] = SupplyMetadata({
            chainId: destinationChainSelector,
            activeSupply: _metadata.activeSupply + amount,
            deactiveSupply: _metadata.deactiveSupply + amount,
            lastUpdated: block.timestamp
        });

        bytes memory data = abi.encodeWithSignature("mint(address, amount)", msg.sender, amount);

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: data, // ABI-encoded with signature message for minting in destination chain
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: i_link // Setting feeToken to $LINK, as main currency for fee
        });

        // Initialize a router client instance to interact with cross-chain router
        IRouterClient router = IRouterClient(this.getRouter());

        // Get the fee required to send the message
        uint256 fees = router.getFee(destinationChainSelector, evm2AnyMessage);

        LinkTokenInterface(i_link).approve(this.getRouter(), fees);

        // Send the message through the router and store the returned message ID
        messageId = router.ccipSend(
            destinationChainSelector,
            evm2AnyMessage
        );

        // Emit an event with message details
        emit MessageSent(
            messageId,
            destinationChainSelector,
            receiver,
            data,
            fees
        );

        // Return the message ID
        return messageId;
    }

    /// handle a received message
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
        address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address

        (uint256 action, uint256 amount) = abi.decode(any2EvmMessage.data, (uint256, uint256)); // abi-decoding of the sent string message
        
        if (action == 0) {
            IERC20(tokenAddress).transferFrom(address(this), sender, amount);
            _activeTotalSupply -= amount;

            SupplyMetadata memory _metadata = _supplyMetadata[sourceChainSelector];
            _supplyMetadata[sourceChainSelector] = SupplyMetadata({
                chainId: sourceChainSelector,
                activeSupply: _metadata.activeSupply - amount,
                deactiveSupply: _metadata.deactiveSupply,
                lastUpdated: block.timestamp
            });

            emit Unlock(0, sender, amount);

        } else if (action == 1) {
            IERC20(tokenAddress).transferFrom(address(this), x_DEAD_x, amount);
            _activeTotalSupply -= amount;
            _deactiveTotalSupply += amount;

            SupplyMetadata memory _metadata = _supplyMetadata[sourceChainSelector];
            _supplyMetadata[sourceChainSelector] = SupplyMetadata({
                chainId: sourceChainSelector,
                activeSupply: _metadata.activeSupply - amount,
                deactiveSupply: _metadata.deactiveSupply - amount,
                lastUpdated: block.timestamp
            });

            emit Unlock(1, sender, amount);

        }

        emit MessageReceived(
            messageId,
            sourceChainSelector,
            sender,
            any2EvmMessage.data
        );

        emit Sync(block.timestamp, sourceChainSelector);
    }

    function withdrawLINK(
        address beneficiary
    ) public onlyOwner {
        uint256 amount = IERC20(i_link).balanceOf(address(this));
        IERC20(i_link).transfer(beneficiary, amount);
    }
}