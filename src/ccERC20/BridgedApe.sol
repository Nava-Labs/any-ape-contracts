// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20, CCIPReceiver, clERC20Proxy_Destination} from "./clERC20Proxy_Destination.sol";

contract BridgedApe is clERC20Proxy_Destination {
    constructor(
        string memory name, 
        string memory symbol, 
        address router,
        address link
    ) ERC20(name, symbol) clERC20Proxy_Destination(router, link) {}
}