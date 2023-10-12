// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20, CCIPReceiver, clERC20_Source} from "./clERC20_Source.sol";

contract anyApeSourceERC20 is clERC20_Source {
    constructor(
        string memory name, 
        string memory symbol, 
        address router,
        address tokenAddress,
        address link
    ) ERC20(name, symbol) CCIPReceiver(router) clERC20_Source(tokenAddress, link) {}
}
