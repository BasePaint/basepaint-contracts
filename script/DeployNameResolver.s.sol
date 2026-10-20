// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {BasePaintNameResolver} from "../src/BasePaintNameResolver.sol";

/// Deploy on Ethereum mainnet, then set it as the ENS resolver of basepaint.xyz.
contract DeployNameResolverScript is Script {
    string constant GATEWAY_URL = "https://basepaint.xyz/api/ens?sender={sender}&data={data}";

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address owner = vm.envAddress("OWNER_ADDRESS");
        address signer = vm.envAddress("ENS_SIGNER_ADDRESS");

        vm.startBroadcast(deployer);
        BasePaintNameResolver resolver = new BasePaintNameResolver(owner, GATEWAY_URL, signer);
        vm.stopBroadcast();

        console2.log("BasePaintNameResolver", address(resolver));
    }
}
