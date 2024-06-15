// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {BasePaintRewards, IBasePaint} from "../src/BasePaintRewards.sol";

contract DeployRewardsScript is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address basepaint = 0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83;
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployer);
        BasePaintRewards rewards = new BasePaintRewards(IBasePaint(basepaint), owner);
        vm.stopBroadcast();

        console2.log("BasePaint Rewards", address(rewards));
    }
}
