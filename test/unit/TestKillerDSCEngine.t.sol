//SPDX-Licene-Identifier: MIT

pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KillerDSCEngine} from "../../src/KillerDSCEngine.sol";
import {KillerCoin} from "../../src/KillerCoin.sol";
import {DeployKillerEngine} from "../../script/DeployKillerEngine.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestKillerDSCEngine is Test {
    KillerDSCEngine private killerEngine;
    KillerCoin private killerCoin;
    DeployKillerEngine private deployKillerEngine;
    HelperConfig private helperConfig;

    address private wethTokenAddress;
    address private wbtcTokenAddress;
    address private wethToUSDPricefeedAddress;
    address private wbtcToUSDPricefeedAddress;

    address private USER = makeAddr("user");
    uint256 private INITIAL_BALANCE = 100 ether;

    function setUp() public {
        deployKillerEngine = new DeployKillerEngine();
        (killerEngine, helperConfig) = deployKillerEngine.run();
        killerCoin = KillerCoin(killerEngine.getKillerTokenAddress());

        (wethTokenAddress, wbtcTokenAddress, wethToUSDPricefeedAddress, wbtcToUSDPricefeedAddress,) =
            helperConfig.activeNetconfig();

        ERC20Mock(wethTokenAddress).mint(USER,INITIAL_BALANCE);
        ERC20Mock(wbtcTokenAddress).mint(USER,INITIAL_BALANCE);        
    }
    
}
