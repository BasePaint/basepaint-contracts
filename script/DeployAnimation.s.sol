// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {BasePaintAnimation} from "../src/BasePaintAnimation.sol";

contract DeployAnimationScript is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployer);
        BasePaintAnimation animation = new BasePaintAnimation();
        animation.transferOwnership(owner);

        vm.stopBroadcast();

        console2.log("Animation", address(animation));
    }
}
