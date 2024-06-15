// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {BasePaintBrushEvents, IBasePaintBrush} from "../src/BasePaintBrushEvents.sol";

contract DeployBrushEventsScript is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address brush = 0xD68fe5b53e7E1AbeB5A4d0A6660667791f39263a;

        vm.startBroadcast(deployer);
        BasePaintBrushEvents events = new BasePaintBrushEvents(IBasePaintBrush(brush));
        vm.stopBroadcast();

        console2.log("BasePaint Brush Events", address(events));
    }
}
