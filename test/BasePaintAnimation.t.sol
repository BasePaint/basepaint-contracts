// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BasePaintAnimation} from "../src/BasePaintAnimation.sol";
import {BasePaint} from "../src/BasePaint.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

contract BasePaintAnimationTest is Test {
    BasePaintAnimation public animation;
    BasePaint public basepaint = BasePaint(0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83);
    address w1nt3r = address(0x1E79b045Dc29eAe9fdc69673c9DCd7C53E5E159D);

    function setUp() public {
        string memory MAINNET_RPC_URL = vm.envString("RPC_URL");

        vm.createSelectFork(MAINNET_RPC_URL, 19090155);
        animation = new BasePaintAnimation();
    }

    function testMintByBurn() public {
        vm.prank(w1nt3r);
        basepaint.safeTransferFrom(w1nt3r, address(animation), 385, 2, "");

        assertEq(animation.balanceOf(w1nt3r, 385), 1);
        assertEq(basepaint.balanceOf(address(animation), 385), 0);
        assertEq(basepaint.balanceOf(0x000000000000000000000000000000000000dEaD, 385), 2);
    }

    function testMintByBurnBatched() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 385;
        ids[1] = 10;
        values[0] = 2;
        values[1] = 4;

        vm.prank(w1nt3r);
        basepaint.safeBatchTransferFrom(w1nt3r, address(animation), ids, values, "");

        assertEq(animation.balanceOf(w1nt3r, ids[0]), 1);
        assertEq(animation.balanceOf(w1nt3r, ids[1]), 2);
    }

    function testWrongValue1() public {
        vm.prank(w1nt3r);
        vm.expectRevert();
        basepaint.safeTransferFrom(w1nt3r, address(animation), 385, 0, "");
    }

    function testWrongValue2() public {
        vm.prank(w1nt3r);
        vm.expectRevert();
        basepaint.safeTransferFrom(w1nt3r, address(animation), 385, 3, "");
    }

    function testWrongValue3() public {
        vm.prank(w1nt3r);
        vm.expectRevert();
        basepaint.safeTransferFrom(w1nt3r, address(animation), 385, 100, "");
    }

    function testWrongNFT() public {
        FakeNFT fake = new FakeNFT();
        fake.mint(w1nt3r, 385, 2);

        vm.prank(w1nt3r);
        vm.expectRevert(BasePaintAnimation.WrongCollection.selector);
        fake.safeTransferFrom(w1nt3r, address(animation), 385, 2, "");

        assertEq(animation.balanceOf(w1nt3r, 385), 0);
    }

    function testURI() public {
        animation.setURI("ipfs://{id}");
        assertEq(animation.uri(0), "ipfs://{id}");
    }
}

contract FakeNFT is ERC1155("") {
    function mint(address to, uint256 id, uint256 value) external {
        _mint(to, id, value, "");
    }
}
