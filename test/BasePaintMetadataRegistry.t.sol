// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BasePaintMetadataRegistry} from "../src/BasePaintMetadataRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BasePaintMetadataRegistryTest is Test {
    ERC1967Proxy proxy;
    BasePaintMetadataRegistry public implementation;
    BasePaintMetadataRegistry public registry;
    address public owner;
    address public user;

    event MetadataUpdated(uint256 indexed id, string name, uint24[] palette, uint256 size, address proposer);

    function setUp() public {
        owner = address(this);
        user = address(0x1);

        implementation = new BasePaintMetadataRegistry();

        // Encode the initialize function call
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistry.initialize.selector, owner);

        proxy = new ERC1967Proxy(address(implementation), data);
        registry = BasePaintMetadataRegistry(address(proxy));
    }

    function testInitialization() public {
        assertEq(registry.owner(), owner);
    }

    function testSetMetadata() public {
        uint256 id = 1;
        string memory name = "Test Theme";
        uint24[] memory palette = new uint24[](3);
        palette[0] = 0xFF0000;
        palette[1] = 0x00FF00;
        palette[2] = 0x0000FF;
        uint96 size = 100;
        address proposer = address(0x2);

        vm.expectEmit(true, false, false, true);
        emit MetadataUpdated(id, name, palette, size, proposer);
        registry.setMetadata(id, name, palette, size, proposer);

        BasePaintMetadataRegistry.Metadata memory data = registry.getMetadata(id);
        assertEq(data.name, name);
        assertEq(data.palette.length, 3);
        assertEq(data.palette[0], 0xFF0000);
        assertEq(data.palette[1], 0x00FF00);
        assertEq(data.palette[2], 0x0000FF);
        assertEq(data.size, size);
        assertEq(data.proposer, proposer);
    }

    function testBatchSetMetadata() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;

        string[] memory names = new string[](2);
        names[0] = "Theme 1";
        names[1] = "Theme 2";

        uint24[][] memory palettes = new uint24[][](2);
        palettes[0] = new uint24[](2);
        palettes[0][0] = 0xFF0000;
        palettes[0][1] = 0x00FF00;
        palettes[1] = new uint24[](3);
        palettes[1][0] = 0x0000FF;
        palettes[1][1] = 0xFFFF00;
        palettes[1][2] = 0xFF00FF;

        uint96[] memory sizes = new uint96[](2);
        sizes[0] = 100;
        sizes[1] = 200;

        address[] memory proposers = new address[](2);
        proposers[0] = address(0x2);
        proposers[1] = address(0x3);

        registry.batchSetMetadata(ids, names, palettes, sizes, proposers);

        for (uint256 i = 0; i < ids.length; i++) {
            BasePaintMetadataRegistry.Metadata memory data = registry.getMetadata(ids[i]);
            assertEq(data.name, names[i]);
            assertEq(data.palette.length, palettes[i].length);
            for (uint256 j = 0; j < palettes[i].length; j++) {
                assertEq(data.palette[j], palettes[i][j]);
            }
            assertEq(data.size, sizes[i]);
            assertEq(data.proposer, proposers[i]);
        }
    }

    function testGetters() public {
        uint256 id = 1;
        string memory name = "Test Theme";
        uint24[] memory palette = new uint24[](3);
        palette[0] = 0xFF0000;
        palette[1] = 0x00FF00;
        palette[2] = 0x0000FF;
        uint96 size = 100;
        address proposer = address(0x2);

        registry.setMetadata(id, name, palette, size, proposer);

        assertEq(registry.getName(id), name);

        uint24[] memory retrievedPalette = registry.getPalette(id);
        assertEq(retrievedPalette.length, palette.length);
        for (uint256 i = 0; i < palette.length; i++) {
            assertEq(retrievedPalette[i], palette[i]);
        }

        assertEq(registry.getCanvasSize(id), size);
        assertEq(registry.getProposer(id), proposer);
    }

    function testOnlyOwnerCanSetMetadata() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.setMetadata(1, "Test", new uint24[](0), 0, address(0));
    }

    function testOnlyOwnerCanBatchSetMetadata() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.batchSetMetadata(
            new uint256[](1), new string[](1), new uint24[][](1), new uint96[](1), new address[](1)
        );
    }

    function testBatchSetMetadataWithMismatchedArrays() public {
        uint256[] memory ids = new uint256[](2);
        string[] memory names = new string[](1);
        uint24[][] memory palettes = new uint24[][](2);
        uint96[] memory sizes = new uint96[](2);
        address[] memory proposers = new address[](2);

        vm.expectRevert("arrays must have the same length");
        registry.batchSetMetadata(ids, names, palettes, sizes, proposers);
    }

    function testUpgrade() public {
        BasePaintMetadataRegistryV2 newImplementation = new BasePaintMetadataRegistryV2();
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistryV2.upgradeHasWorkedJustFine.selector);

        registry.upgradeToAndCall(address(newImplementation), data);
        assertEq(BasePaintMetadataRegistryV2(address(registry)).upgradeHasWorkedJustFine(), "upgradeHasWorkedJustFine");
    }

    function testUpgradeNotOwner() public {
        BasePaintMetadataRegistryV2 newImplementation = new BasePaintMetadataRegistryV2();
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistryV2.upgradeHasWorkedJustFine.selector);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        registry.upgradeToAndCall(address(newImplementation), data);
    }

    function testUpgradeWithBadCall() public {
        BasePaintMetadataRegistryV2 newImplementation = new BasePaintMetadataRegistryV2();
        bytes memory data = abi.encodeWithSelector(BasePaintMetadataRegistry.initialize.selector, owner);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        registry.upgradeToAndCall(address(newImplementation), data);
    }
}

contract BasePaintMetadataRegistryV2 is BasePaintMetadataRegistry {
    function upgradeHasWorkedJustFine() public pure returns (string memory) {
        return "upgradeHasWorkedJustFine";
    }
}
