// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "../utils/Withdraw.sol";

contract anyApe is CCIPReceiver, Withdraw {
    enum PayFeesIn {
        Native,
        LINK
    }

    address immutable i_router;
    address immutable i_link;

    // handle receive
    struct MessageToUser {
        bytes32 latestMessageId;
        uint64 latestSourceChainSelector;
        address latestSender;
        address initiator;
        string latestMessage;
    }
    mapping(address => MessageToUser) _message;
    
    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        address initiator,
        string latestMessage
    );

    event MessageSent(bytes32 messageId);

    constructor(address router, address link) CCIPReceiver(router) {
        i_router = router;
        i_link = link;
        LinkTokenInterface(i_link).approve(i_router, type(uint256).max);
    }

    receive() external payable {}   

    function send(
        uint64 destinationChainSelector,
        address receiver,
        address initiator,
        string memory messageText,
        PayFeesIn payFeesIn
    ) external returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encode(initiator, messageText),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? i_link : address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(
            destinationChainSelector,
            message
        );

        if (payFeesIn == PayFeesIn.LINK) {
            messageId = IRouterClient(i_router).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            messageId = IRouterClient(i_router).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
        }

        emit MessageSent(messageId);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        (address _initiator, string memory _msg) = abi.decode(message.data, (address, string));

        _message[_initiator].latestMessageId = message.messageId;
        _message[_initiator].latestSourceChainSelector = message.sourceChainSelector;
        _message[_initiator].latestSender = abi.decode(message.sender, (address));
        _message[_initiator].initiator = _initiator;
        _message[_initiator].latestMessage = _msg;

        emit MessageReceived(
            _message[_initiator].latestMessageId,
            _message[_initiator].latestSourceChainSelector,
            _message[_initiator].latestSender,
            _initiator,
            _msg
        );
    }

    function getLatestMessageDetails(address _initiator)
        public
        view
        returns (bytes32, uint64, address, address, string memory)
    {
        return (
            _message[_initiator].latestMessageId,
            _message[_initiator].latestSourceChainSelector,
            _message[_initiator].latestSender,
            _message[_initiator].initiator,
            _message[_initiator].latestMessage
        );
    }
    
}
