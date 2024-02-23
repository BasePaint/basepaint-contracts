// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {BasePaintWIP} from "../src/BasePaintWIP.sol";

contract DeployWIPScript is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address signer = vm.envAddress("SIGNER_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployer);
        BasePaintWIP wip = new BasePaintWIP(signer);
        wip.transferOwnership(owner);

        vm.stopBroadcast();

        console2.log("WIP", address(wip));
    }
}
