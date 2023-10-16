// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./CCIPHelper.sol";
import {clERC20Proxy_Source} from "../src/ccERC20/clERC20Proxy_Source.sol";
import {BridgedApe} from "../src/ccERC20/BridgedApe.sol";

contract DeployProxySource is Script, CCIPHelper {
    function run(SupportedNetworks source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        address tokenAddress = 0x0f743cDc229303b52F716bc6C2670dAC2976C256;

        clERC20Proxy_Source proxySource = new clERC20Proxy_Source(
            tokenAddress,
            router,
            link
        );

        console.log(
            "Proxy Source contract deployed with address: ",
            address(proxySource)
        );

        vm.stopBroadcast();
    }
}

contract DeployBridgedApe is Script, CCIPHelper {
    function run(SupportedNetworks source) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        (address router, address link, , ) = getConfigFromNetwork(source);

        string memory name = "Bridged APE";
        string memory symbol = "BAPE";
        console.log(router);
        console.log(link);

        BridgedApe _bridgedApe = new BridgedApe(
            name,
            symbol,
            router,
            link
        );

        console.log(
            "Bridge Ape contract deployed with address: ",
            address(_bridgedApe)
        );

        vm.stopBroadcast();
    }
}
