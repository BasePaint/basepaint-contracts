// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IBasePaintBrush} from "../src/BasePaintBrush.sol";
import {BasePaint} from "../src/BasePaint.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract BasePaintTest is Test {
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public safe = address(0x7);

    FakeBrush public brush;
    BasePaint public paint;

    function setUp() public {
        brush = new FakeBrush();
        paint = new BasePaint(brush, 1 days);

        vm.deal(bob, 100 ether);
    }

    function testPaint() public {
        brush.mint({to: alice, tokenId: 1, strength: 144});
        paint.start();

        bytes memory pixels = new bytes(12 * 12 * 3);
        uint256 offset = 0;
        for (uint256 x = 0; x < 12; x++) {
            for (uint256 y = 0; y < 12; y++) {
                pixels[offset++] = bytes1(uint8(x + 17));
                pixels[offset++] = bytes1(uint8(y + 0));
                pixels[offset++] = bytes1(uint8(1));
            }
        }

        vm.prank(alice);
        paint.paint({day: 1, tokenId: 1, pixels: pixels});

        vm.prank(alice);
        vm.expectRevert("Brush used too much");
        paint.paint({day: 1, tokenId: 1, pixels: pixels});

        vm.warp(block.timestamp + 1 days + 1);
        vm.prank(bob);
        paint.mint{value: 1 ether}({day: 1, count: 1});

        assertEq(paint.balanceOf(bob, 1), 1);

        vm.warp(block.timestamp + 1 days + 1);
        uint256[] memory indexes = new uint256[](1);
        indexes[0] = 1;
        uint256 oldAliceBalance = alice.balance;
        vm.prank(alice);
        paint.authorWithdraw(indexes);
        assertEq(alice.balance, oldAliceBalance + 0.9 ether);

        vm.expectRevert("No funds to withdraw");
        vm.prank(alice);
        paint.authorWithdraw(indexes);

        paint.withdraw(safe);
        assertEq(safe.balance, 0.1 ether);
    }
}

contract FakeBrush is ERC721, IBasePaintBrush {
    mapping(uint256 => uint256) public strengths;

    constructor() ERC721("FakeBrush", "FB") {}

    function mint(address to, uint256 tokenId, uint256 strength) public {
        _mint(to, tokenId);
        strengths[tokenId] = strength;
    }
}
