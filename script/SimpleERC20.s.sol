// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import {SimpleERC20} from "../src/token/SimpleERC20.sol";

contract DeploySimpleERC20 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SimpleERC20 erc20 = new SimpleERC20(
            "Mock ERC20",
            "M20"
        );

        console.log(
            "SimpleERC20 contract deployed with address: ",
            address(erc20)
        );

        vm.stopBroadcast();
    }
}

contract SimpleERC20Interaction is Script {
    function approve(
        address token,
        address spender
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SimpleERC20(token).approve(spender, type(uint256).max);

        vm.stopBroadcast();
    }

    function approve(
        address token,
        address from,
        address to,
        uint256 amount
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        SimpleERC20(token).transferFrom(from, to, amount);

        vm.stopBroadcast();
    }

}