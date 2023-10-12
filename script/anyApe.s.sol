// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./CCIPHelper.sol";
import {anyApe} from "../src/protocol/anyApe.sol";

contract DeployAnyApe is Script, CCIPHelper {
    function run(SupportedNetworks source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        anyApe _anyApe = new anyApe(
            router,
            link
        );

        console.log(
            "anyAoe contract deployed on ",
            networks[source],
            "with address: ",
            address(_anyApe)
        );

        vm.stopBroadcast();
    }
}

contract SendMessage is Script, CCIPHelper {
    function run(
        address payable sender,
        SupportedNetworks destination,
        address receiver,
        address initiator,
        string memory message,
        anyApe.PayFeesIn payFeesIn
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (, , , uint64 destinationChainId) = getConfigFromNetwork(destination);

        bytes32 messageId = anyApe(sender).send(
            destinationChainId,
            receiver,
            initiator,
            message,
            payFeesIn
        );

        console.log(
            "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        );
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }
}

contract GetLatestMessageDetails is Script, CCIPHelper {
    function run(address payable _anyApe, address _initiator) external view {
        (
            bytes32 latestMessageId,
            uint64 latestSourceChainSelector,
            address latestSender,
            address initiator,
            string memory latestMessage
        ) = anyApe(_anyApe).getLatestMessageDetails(_initiator);

        console.log("Latest Message ID: ");
        console.logBytes32(latestMessageId);
        console.log("Latest Source Chain Selector: ");
        console.log(latestSourceChainSelector);
        console.log("Latest Sender: ");
        console.log(latestSender);
        console.log("Initiator: ");
        console.log(initiator);
        console.log("Latest Message: ");
        console.log(latestMessage);
    }
}
