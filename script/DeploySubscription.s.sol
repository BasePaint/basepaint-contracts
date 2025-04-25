// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "../src/BasePaintSubscription.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBasePaintSubscription is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address owner = vm.envAddress("OWNER_ADDRESS");
        address basePaintAddress = vm.envAddress("BASEPAINT_ADDRESS");

        vm.startBroadcast(deployer);

        BasePaintSubscription implementation = new BasePaintSubscription();
        bytes memory data = abi.encodeWithSelector(BasePaintSubscription.initialize.selector, basePaintAddress, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        vm.stopBroadcast();

        console.log("BasePaintSubscription Implementation deployed to:", address(implementation));
        console.log("BasePaintSubscription Proxy deployed to:", address(proxy));
    }
}