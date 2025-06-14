//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {KillerDSCEngine} from "src/KillerDSCEngine.sol";
import {DeployKillerEngine} from "script/DeployKillerEngine.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract TestFuzzDSCEngine is Test{

    KillerDSCEngine private killerDSCEngine;
    DeployKillerEngine private deployKillerEngine;
    HelperConfig private helperConfig;

    function setUp() public {

        (killerDSCEngine,helperConfig) = deployKillerEngine.deployEngine();        
    }

}