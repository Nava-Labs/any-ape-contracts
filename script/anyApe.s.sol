// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./CCIPHelper.sol";
import {AnyApe_Source} from "../src/protocol/AnyApe_Source.sol";
import {AnyApe_Destination} from "../src/protocol/AnyApe_Destination.sol";

contract DeployAnyApe_Source is Script, CCIPHelper {
    function run(SupportedNetworks source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        address APE = 0x6d1566A885AC5c3621FE1Df25E5076f5326E7F69;

        AnyApe_Source _anyApe = new AnyApe_Source(
            router,
            link,
            APE
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

contract DeployAnyApe_Destination is Script, CCIPHelper {
    function run(SupportedNetworks source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        address APE = 0x294bb4c48F762DC0AFfe9DA653E9C6E1A4011452;

        AnyApe_Destination _anyApe = new AnyApe_Destination(
            router,
            link,
            APE
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

contract AnyApe_SourceInteraction is Script, CCIPHelper {
    function updateReceiver(address payable anyApe_source, address destReceiver) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AnyApe_Source(anyApe_source).updateMessageReceiverAddress(destReceiver);
        vm.stopBroadcast();
    }

    function list(address payable anyApe_Source, address tokenAddress, uint256 tokenId, uint256 _price) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AnyApe_Source(anyApe_Source).listing(tokenAddress, tokenId, _price);
        vm.stopBroadcast();
    }

    function listingData(address payable _anyApe, address tokenAddress, uint256 tokenId) external view {
        AnyApe_Source.ListingDetails memory _detail = AnyApe_Source(_anyApe).checkListedNftDetails(tokenAddress, tokenId);

        console.log("listedBy");
        console.log(_detail.listedBy);
        console.log("price");
        console.log(_detail.price);
    }

    function cancel(address payable anyApe_Source, address tokenAddress, uint256 tokenId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AnyApe_Source(anyApe_Source).cancelListing(tokenAddress, tokenId);
        vm.stopBroadcast();
    }

    function wdLink(address payable anyApe_Source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address account1 = 0x222Da5f13D800Ff94947C20e8714E103822Ff716;
        address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        AnyApe_Source(anyApe_Source).withdrawToken(account1, link);
        vm.stopBroadcast();
        
    }

}

contract AnyApe_DestinationInteraction is Script, CCIPHelper {
    function updateReceiver(address payable anyApe_dest, address anyApeMessageReceiver, address apeTokenMessageReceiver) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AnyApe_Destination(anyApe_dest).updateMessageReceiverAddress(anyApeMessageReceiver, apeTokenMessageReceiver);
        vm.stopBroadcast();
    }

    function ccSale(address payable anyApe_dest, address tokenAddress, uint256 tokenId) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        AnyApe_Destination(anyApe_dest).crossChainSale(tokenAddress, tokenId);
        vm.stopBroadcast();
    }

    function listingData(address payable _anyApe, address tokenAddress, uint256 tokenId) external view {
        AnyApe_Destination.ListingDetails memory _detail = AnyApe_Destination(_anyApe).checkListedNftDetailsOnSourceChain(tokenAddress, tokenId);

        console.log("listedBy");
        console.log(_detail.listedBy);
        console.log("price");
        console.log(_detail.price);
    }

}