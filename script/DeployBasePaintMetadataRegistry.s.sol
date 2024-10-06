// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/BasePaintMetadataRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployBasePaintMetadataRegistry is Script {
    function setUp() public {}

    function run() public {
        address owner = vm.envAddress("OWNER_ADDRESS");
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));

        vm.startBroadcast();

        BasePaintMetadataRegistry implementation = new BasePaintMetadataRegistry();
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistry.initialize.selector, owner, deployer);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        vm.stopBroadcast();

        console.log("MetadataRegistry Implementation deployed to:", address(implementation));
        console.log("MetadataRegistry Proxy deployed to:", address(proxy));
    }
}
