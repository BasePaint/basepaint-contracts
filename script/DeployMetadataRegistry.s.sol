// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/BasePaintMetadataRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployMetadataRegistry is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address owner = vm.envAddress("OWNER_ADDRESS");
        address editor = vm.rememberKey(vm.envUint("ADMIN_KEY"));

        vm.startBroadcast(deployer);

        BasePaintMetadataRegistry implementation = new BasePaintMetadataRegistry();
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistry.initialize.selector, owner, editor);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        vm.stopBroadcast();

        console.log("MetadataRegistry Implementation deployed to:", address(implementation));
        console.log("MetadataRegistry Proxy deployed to:", address(proxy));
    }
}
