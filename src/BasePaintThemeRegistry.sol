// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BasePaintThemeRegistry is Ownable {
    struct ThemeData {
        string theme;
        string[] palette;
        uint256 size;
    }

    mapping(uint256 => ThemeData) private themes;
    uint256 private nextThemeId = 1;

    event ThemeUpdated(uint256 indexed themeId, string theme, string[] palette, uint256 size);

    constructor() Ownable(msg.sender) {}

    function setThemeData(string memory _theme, string[] memory _palette, uint256 _size)
        public
        onlyOwner
        returns (uint256)
    {
        uint256 themeId = nextThemeId;
        themes[themeId] = ThemeData(_theme, _palette, _size);
        emit ThemeUpdated(themeId, _theme, _palette, _size);
        nextThemeId++;
        return themeId;
    }

    function getThemeData(uint256 _themeId) public view returns (ThemeData memory) {
        return themes[_themeId];
    }

    function getTheme(uint256 _themeId) public view returns (string memory) {
        return themes[_themeId].theme;
    }

    function getPalette(uint256 _themeId) public view returns (string[] memory) {
        return themes[_themeId].palette;
    }

    function getPaletteSize(uint256 _themeId) public view returns (uint256) {
        return themes[_themeId].palette.length;
    }

    function getSize(uint256 _themeId) public view returns (uint256) {
        return themes[_themeId].size;
    }

    function getNextThemeId() public view returns (uint256) {
        return nextThemeId;
    }
}
