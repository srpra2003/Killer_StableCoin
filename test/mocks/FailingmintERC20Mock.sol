// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FailingtransferFromERC20Mock is ERC20 {
    constructor() ERC20("ERC20Mock", "E20M") {}

    function mint(address, uint256) external pure returns (bool) {
        return false;
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
