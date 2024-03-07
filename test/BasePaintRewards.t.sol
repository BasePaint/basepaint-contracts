// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IBasePaintBrush} from "../src/BasePaintBrush.sol";
import {BasePaint} from "../src/BasePaint.sol";
import {BasePaintRewards, IBasePaint} from "../src/BasePaintRewards.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract BasePaintRewardsTest is Test {
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public safe = address(0x7);

    FakeBrush public brush;
    BasePaint public paint;
    BasePaintRewards public rewards;

    function setUp() public {
        brush = new FakeBrush();
        paint = new BasePaint(brush, 1 days);
        rewards = new BasePaintRewards(IBasePaint(address(paint)));

        vm.deal(bob, 100 ether);

        brush.mint({to: alice, tokenId: 1, strength: 200});
        paint.start();

        bytes memory pixels = new bytes(12 * 12 * 3);
        vm.prank(alice);
        paint.paint({day: 1, tokenId: 1, pixels: pixels});

        vm.warp(block.timestamp + 1 days + 1);
    }

    function testMintWithRewards() public {
        uint256 price = paint.openEditionPrice();
        rewards.mint{value: price}({tokenId: 1, sendMintsTo: bob, count: 1, sendRewardsTo: safe});

        assertEq(paint.balanceOf(bob, 1), 1);
        assertEq(rewards.balanceOf(safe), price * rewards.defaultRewardRate() / 1_000);

        vm.expectRevert(BasePaintRewards.NotEnoughContractFunds.selector);
        rewards.cashOut(safe);

        vm.deal(address(rewards), 1 ether);

        vm.expectRevert(BasePaintRewards.NoRewards.selector);
        rewards.cashOut(bob);

        rewards.cashOut(safe);
        assertEq(rewards.balanceOf(safe), 0);
        assertEq(safe.balance, 0.000026 ether);
    }

    function testMintWithCustomRewards() public {
        uint256 price = paint.openEditionPrice();
        rewards.setRewardRate(safe, 1_000); // 100%
        rewards.mintLatest{value: price}({sendMintsTo: bob, count: 1, sendRewardsTo: safe});

        vm.deal(address(rewards), 1 ether);
        rewards.cashOut(safe);
        assertEq(rewards.balanceOf(safe), 0);
        assertEq(safe.balance, 0.0026 ether);
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
