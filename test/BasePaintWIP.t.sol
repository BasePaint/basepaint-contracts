// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {BasePaintWIP} from "../src/BasePaintWIP.sol";

contract BasePaintWIPTest is Test {
    address alice = address(0xA);
    address signer;
    uint256 signerPrivateKey = 0x1234;

    BasePaintWIP public nft;

    function setUp() public {
        signer = vm.addr(signerPrivateKey);
        nft = new BasePaintWIP(signer);
        vm.deal(alice, 10 ether);
    }

    function testMintNoSignature() public {
        vm.prank(alice);
        vm.expectRevert("Invalid signature");
        nft.mint(0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87, new bytes(0));
    }

    function testMint() public {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("BasePaint WIP"));
        bytes32 hashedVersion = keccak256(bytes("1"));
        bytes32 domain = keccak256(abi.encode(typeHash, hashedName, hashedVersion, block.chainid, address(nft)));

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,bytes32 txHash)"),
                alice,
                0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87
            )
        );
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", domain, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(alice);
        nft.mint(0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87, signature);

        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.ownerOf(0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87), alice);
        assertEq(
            nft.tokenURI(0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87),
            "https://basepaint.xyz/api/wip/0xdfa855998287407ae494c73707512376a2e1debfe05159996af8ec09a89fce87"
        );
    }
}
