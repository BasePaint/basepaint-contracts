// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BasePaintBrush} from "../src/BasePaintBrush.sol";

contract BasePaintBrushTest is Test {
    address alice = address(0xA);
    address signer;
    uint256 signerPrivateKey = 0x1234;

    BasePaintBrush public nft;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        nft = new BasePaintBrush(signer);
        vm.deal(alice, 10 ether);
    }

    function testMintNoSignature() public {
        vm.prank(alice);
        vm.expectRevert("Invalid signature");
        nft.mint(400, 0, new bytes(0));
    }

    function testMint() public {
        bytes32 _TYPE_HASH =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("BasePaint Brush"));
        bytes32 hashedVersion = keccak256(bytes("1"));
        bytes32 domain = keccak256(abi.encode(_TYPE_HASH, hashedName, hashedVersion, block.chainid, address(nft)));

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 strength,uint256 price,uint256 nonce)"), alice, 400, 1 ether, 42
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domain, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        nft.mint{value: 1 ether}(400, 42, signature);

        assertEq(nft.totalSupply(), 1);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.tokenURI(1), "https://basepaint.xyz/api/brush/1");
        assertEq(nft.strengths(1), 400);

        structHash = keccak256(
            abi.encode(
                keccak256("Upgrade(uint256 tokenId,uint256 strength,uint256 price,uint256 nonce)"), 1, 800, 2 ether, 43
            )
        );
        digest = keccak256(abi.encodePacked(hex"1901", domain, structHash));

        (v, r, s) = vm.sign(signerPrivateKey, digest);
        signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        nft.upgrade{value: 2 ether}(1, 800, 43, signature);
        assertEq(nft.strengths(1), 800);
    }
}
