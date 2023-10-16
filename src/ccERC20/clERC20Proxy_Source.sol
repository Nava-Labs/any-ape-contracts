// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {TrustedSender} from "./TrustedSender.sol";

error UnauthorizedChainSelector();

/**
 * @dev Extension of {ERC20} that properly manage token accross chain
 * via Chainlink CCIP.
 * recognized off-chain (via event analysis).
 */
contract clERC20Proxy_Source is CCIPReceiver, TrustedSender {    

    address immutable i_link;

    address immutable public tokenAddress; 

    /**
     * @dev Emitted when ERC20 is locked
     */
    event Lock(address indexed initiator, uint256 indexed amount);

    /**
     * @dev Emitted when ERC20 is unlocked
     */
    event Unlock(address indexed initiator, uint256 indexed amount);

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

    constructor(address _tokenAddress, address _router, address link) CCIPReceiver(_router) {
        tokenAddress = _tokenAddress;
        i_link = link;    
    }

    receive() external payable {}

    function lockAndMint(uint64 destinationChainSelector, address receiver, uint256 amount) external virtual {
        // lock the real token
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        // ccip send for triggering mint in dest chain
        _sendMintMessage(destinationChainSelector, receiver, amount);

        emit Lock(msg.sender, amount);
    }

    function withdrawLINK(address beneficiary) public onlyOwner {
        uint256 amount = IERC20(i_link).balanceOf(address(this));
        IERC20(i_link).transfer(beneficiary, amount);
    }

    // =============================================================
    //                       CCIP SEND & RECEIVE
    // =============================================================

    /// @notice Sends data to receiver on the destination chain.
    /// @dev Assumes your contract has sufficient $LINK for covering the fees
    /// @param destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param receiver The address of the recipient on the destination blockchain.
    /// @param amount token amount that want to be minted in destination blockchain.
    /// @return messageId The ID of the message that was sent.
    function _sendMintMessage(
        uint64 destinationChainSelector,
        address receiver,
        uint256 amount
    ) internal returns (bytes32 messageId) {
        // lock the real token
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

        // ABI-encoded message for minting in destination chain
        bytes memory data = _encodeMintMessage(receiver, amount); 

        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        Client.EVM2AnyMessage memory evm2AnyMessage = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver), // ABI-encoded receiver address
            data: data,
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

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        bytes32 messageId = any2EvmMessage.messageId; // fetch the messageId
        uint64 sourceChainSelector = any2EvmMessage.sourceChainSelector; // fetch the source chain identifier (aka selector)
        address sender = abi.decode(any2EvmMessage.sender, (address)); // abi-decoding of the sender address

        // Trusted Sender check
        bytes memory trustedSender = trustedSenderLookup[sourceChainSelector];
        if (trustedSender.length == 0 ||
            keccak256(trustedSender) != keccak256(abi.encodePacked(sender, address(this)))
        ) {
            revert UnauthorizedChainSelector();
        }

        (address receiver, uint256 amount) = _decodeUnlockMessage(any2EvmMessage.data);

        IERC20(tokenAddress).transferFrom(address(this), receiver, amount);

        emit Unlock(msg.sender, amount);
        emit MessageReceived(
            messageId,
            sourceChainSelector,
            sender,
            any2EvmMessage.data
        );
    }

    function _encodeMintMessage(address receiver, uint256 amount) internal pure returns (bytes memory) {
        return abi.encode(receiver, amount);
    }

    function _decodeUnlockMessage(bytes memory message) internal pure returns (address receiver, uint256 amount) {
        (receiver, amount) = abi.decode(message, (address, uint256));
    }
}