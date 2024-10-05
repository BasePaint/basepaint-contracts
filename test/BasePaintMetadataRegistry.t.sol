// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BasePaintMetadataRegistry.sol";

contract MetadataRegistryTest is Test {
    BasePaintMetadataRegistry public registry;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        registry = new BasePaintMetadataRegistry();
    }

    function testSetMetadata() public {
        uint256 id = 1;
        string memory name = "Test Theme";
        uint24[] memory palette = new uint24[](3);
        palette[0] = 0xFF0000; // Red
        palette[1] = 0x00FF00; // Green
        palette[2] = 0x0000FF; // Blue
        uint256 size = 100;

        registry.setMetadata(id, name, palette, size);

        BasePaintMetadataRegistry.Metadata memory data = registry.getMetadata(id);
        assertEq(data.name, name);
        assertEq(data.palette.length, 3);
        assertEq(data.palette[0], 0xFF0000);
        assertEq(data.palette[1], 0x00FF00);
        assertEq(data.palette[2], 0x0000FF);
        assertEq(data.size, size);
        assertEq(data.proposer, owner);
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

        uint256[] memory sizes = new uint256[](2);
        sizes[0] = 100;
        sizes[1] = 200;

        registry.batchSetMetadata(ids, names, palettes, sizes);

        for (uint256 i = 0; i < ids.length; i++) {
            BasePaintMetadataRegistry.Metadata memory data = registry.getMetadata(ids[i]);
            assertEq(data.name, names[i]);
            assertEq(data.palette.length, palettes[i].length);
            for (uint256 j = 0; j < palettes[i].length; j++) {
                assertEq(data.palette[j], palettes[i][j]);
            }
            assertEq(data.size, sizes[i]);
            assertEq(data.proposer, owner);
        }
    }

    function testGetters() public {
        uint256 id = 1;
        string memory name = "Test Theme";
        uint24[] memory palette = new uint24[](3);
        palette[0] = 0xFF0000;
        palette[1] = 0x00FF00;
        palette[2] = 0x0000FF;
        uint256 size = 100;

        registry.setMetadata(id, name, palette, size);

        assertEq(registry.getName(id), name);

        uint24[] memory retrievedPalette = registry.getPalette(id);
        assertEq(retrievedPalette.length, palette.length);
        for (uint256 i = 0; i < palette.length; i++) {
            assertEq(retrievedPalette[i], palette[i]);
        }

        assertEq(registry.getCanvasSize(id), size);
        assertEq(registry.getProposer(id), owner);
    }

    function testOnlyOwnerCanSetMetadata() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        registry.setMetadata(1, "Test", new uint24[](0), 0);
    }

    function testOnlyOwnerCanBatchSetMetadata() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        registry.batchSetMetadata(new uint256[](1), new string[](1), new uint24[][](1), new uint256[](1));
    }

    function testBatchSetMetadataWithMismatchedArrays() public {
        uint256[] memory ids = new uint256[](2);
        string[] memory names = new string[](1);
        uint24[][] memory palettes = new uint24[][](2);
        uint256[] memory sizes = new uint256[](2);

        vm.expectRevert("arrays must have the same length");
        registry.batchSetMetadata(ids, names, palettes, sizes);
    }
}
