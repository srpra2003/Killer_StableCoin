//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {KillerDSCEngine} from "../src/KillerDSCEngine.sol";

contract DeployKillerEngine is Script {
    address[] public tokenAdds;
    address[] public pricefeedAdds;

    function deployEngine() public returns (KillerDSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            address wethTokenAddress,
            address wbtcTokenAddress,
            address wethToUSDPricefeedAddress,
            address wbtcToUSDPricefeedAddress,
        ) = helperConfig.activeNetconfig();

        tokenAdds = [wethTokenAddress, wbtcTokenAddress];
        pricefeedAdds = [wethToUSDPricefeedAddress, wbtcToUSDPricefeedAddress];

        vm.startBroadcast();
        KillerDSCEngine killerDscEngine = new KillerDSCEngine(tokenAdds, pricefeedAdds);
        vm.stopBroadcast();

        return (killerDscEngine, helperConfig);
    }

    function run() external returns (KillerDSCEngine, HelperConfig) {
        return deployEngine();
    }
}
