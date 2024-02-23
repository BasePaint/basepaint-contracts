// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {BasePaint} from "../src/BasePaint.sol";
import {BasePaintBrush} from "../src/BasePaintBrush.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("DEPLOYER_KEY"));
        address signer = vm.envAddress("SIGNER_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");

        vm.startBroadcast(deployer);
        uint256 epochDuration = block.chainid == 8453 ? 1 days : 1 hours;
        BasePaintBrush brush = new BasePaintBrush(signer);
        BasePaint paint = new BasePaint(brush, epochDuration);

        if (block.chainid == 8453) {
            brush.transferOwnership(owner);
            paint.transferOwnership(owner);
        } else {
            brush.setBaseURI(string.concat("https://basepaint.xyz/api/brush/", Strings.toString(block.chainid), "/"));
            paint.setURI(string.concat("https://basepaint.xyz/api/art/", Strings.toString(block.chainid), "/{id}"));
            paint.setOpenEditionPrice(0.000026 ether);
            paint.start();
        }

        vm.stopBroadcast();

        console2.log("Brush", address(brush));
        console2.log("Paint", address(paint));
    }
}
