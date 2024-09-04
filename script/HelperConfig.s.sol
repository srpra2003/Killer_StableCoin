//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

//Here we are allowing only wbtc and weth as valid collateral so only their details in network

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethTokenAddress;
        address wbtcTokenAddress;
        address wethToUSDPricefeedAddress;
        address wbtcToUSDPricefeedAddress;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetconfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetconfig = getSepoliaMainnetNetworkConfig();
        } else {
            activeNetconfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaMainnetNetworkConfig() internal view returns (NetworkConfig memory) {
        NetworkConfig memory netConfig = NetworkConfig({
            wethTokenAddress: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtcTokenAddress: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wethToUSDPricefeedAddress: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcToUSDPricefeedAddress: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });

        return netConfig;
    }

    function getOrCreateAnvilNetworkConfig() internal returns (NetworkConfig memory) {
        if (activeNetconfig.wethTokenAddress != address(0)) {
            return activeNetconfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockWethToUSDPricefeed = new MockV3Aggregator(8, 2653e7);
        MockV3Aggregator mockWbtcToUSDPricefeed = new MockV3Aggregator(8, 58113e8);

        ERC20Mock mockWethToken = new ERC20Mock();
        ERC20Mock mockWbtcToken = new ERC20Mock();
        vm.stopBroadcast();

        NetworkConfig memory netconfig = NetworkConfig({
            wethTokenAddress: address(mockWethToken),
            wbtcTokenAddress: address(mockWbtcToken),
            wethToUSDPricefeedAddress: address(mockWethToUSDPricefeed),
            wbtcToUSDPricefeedAddress: address(mockWbtcToUSDPricefeed),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });

        return netconfig;
    }
}
