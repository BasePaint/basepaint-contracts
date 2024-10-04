// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/BasepaintThemeRegistry.sol";

contract BasePaintThemeTest is Test {
    BasePaintThemeRegistry public basepaintThemeRegistry;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        basepaintThemeRegistry = new BasepaintThemeRegistry();
    }

    function testSetThemeData() public {
        string memory theme = "On chain summer";
        string[] memory palette = new string[](3);
        palette[0] = "#F7EE82";
        palette[1] = "#F5872C";
        palette[2] = "#55246B";
        uint256 size = 144;

        uint256 themeId = basepaintThemeRegistry.setThemeData(theme, palette, size);
        assertEq(themeId, 1, "First theme should have ID 1");

        BasepaintThemeRegistry.ThemeData memory storedData = basepaintThemeRegistry.getThemeData(themeId);
        assertEq(storedData.theme, theme, "Stored theme should match input");
        assertEq(storedData.palette.length, palette.length, "Stored palette length should match input");
        for (uint256 i = 0; i < palette.length; i++) {
            assertEq(storedData.palette[i], palette[i], "Stored palette color should match input");
        }
        assertEq(storedData.size, size, "Stored size should match input");
    }

    function testGetters() public {
        string memory theme = "Autumn Colors";
        string[] memory palette = new string[](2);
        palette[0] = "#FFA500";
        palette[1] = "#8B4513";
        uint256 size = 100;

        uint256 themeId = basepaintThemeRegistry.setThemeData(theme, palette, size);

        assertEq(basepaintThemeRegistry.getTheme(themeId), theme, "getTheme should return correct theme");

        string[] memory retrievedPalette = basepaintThemeRegistry.getPalette(themeId);
        assertEq(retrievedPalette.length, palette.length, "getPalette should return correct palette length");
        for (uint256 i = 0; i < palette.length; i++) {
            assertEq(retrievedPalette[i], palette[i], "getPalette should return correct palette colors");
        }

        assertEq(basepaintThemeRegistry.getPaletteSize(themeId), palette.length, "getPaletteSize should return correct size");
        assertEq(basepaintThemeRegistry.getSize(themeId), size, "getSize should return correct size");
    }

    function testOnlyOwnerCanSetTheme() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        basepaintThemeRegistry.setThemeData("Test", new string[](0), 0);
    }

    function testGetNextThemeId() public {
        assertEq(basepaintThemeRegistry.getNextThemeId(), 1, "Initial nextThemeId should be 1");

        basepaintThemeRegistry.setThemeData("Theme1", new string[](0), 0);
        assertEq(basepaintThemeRegistry.getNextThemeId(), 2, "After setting one theme, nextThemeId should be 2");

        basepaintThemeRegistry.setThemeData("Theme2", new string[](0), 0);
        assertEq(basepaintThemeRegistry.getNextThemeId(), 3, "After setting two themes, nextThemeId should be 3");
    }
}
