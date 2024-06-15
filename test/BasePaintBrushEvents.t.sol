// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BasePaintBrushEvents, IBasePaintBrush} from "../src/BasePaintBrushEvents.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract BasePaintBrushEventsTest is Test {
    FakeBrush public brush;
    BasePaintBrushEvents public events;

    function setUp() public {
        brush = new FakeBrush();
        events = new BasePaintBrushEvents(IBasePaintBrush(address(brush)));
    }

    function testUpgrade() public {
        events.upgrade(1, 100, 0, "");
        assertEq(brush.strengths(1), 100);
    }

    function testPaidUpgrade() public {
        events.upgrade{value: 1 ether}(1, 100, 0, "");

        assertEq(brush.strengths(1), 100);
        assertEq(address(brush).balance, 1 ether);
    }

    function testupgradeMulti() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory strengths = new uint256[](2);
        uint256[] memory nonces = new uint256[](2);
        bytes[] memory signatures = new bytes[](2);

        tokenIds[0] = 1;
        strengths[0] = 100;
        nonces[0] = 0;
        signatures[0] = "";

        tokenIds[1] = 2;
        strengths[1] = 200;
        nonces[1] = 0;
        signatures[1] = "";

        events.upgradeMulti(tokenIds, strengths, nonces, signatures);
        assertEq(brush.strengths(1), 100);
        assertEq(brush.strengths(2), 200);
    }
}

contract FakeBrush is IBasePaintBrush {
    mapping(uint256 => uint256) public strengths;

    function upgrade(uint256 tokenId, uint256 strength, uint256, bytes calldata) external payable {
        strengths[tokenId] = strength;
    }
}
