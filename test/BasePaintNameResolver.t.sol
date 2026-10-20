// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BasePaintNameResolver} from "../src/BasePaintNameResolver.sol";

contract BasePaintNameResolverTest is Test {
    BasePaintNameResolver resolver;
    uint256 signerKey = 0x5ec2e7;
    address owner = address(0x1);
    bytes name = hex"05616c65783209626173657061696e740378797a00"; // alex.basepaint.xyz
    bytes addrCall = abi.encodeWithSignature("addr(bytes32)", bytes32(uint256(1)));

    function setUp() public {
        resolver = new BasePaintNameResolver(owner, "https://example.com/{sender}/{data}", vm.addr(signerKey));
    }

    function sign(uint256 key, uint64 expires, bytes memory request, bytes memory result)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, resolver.makeSignatureHash(expires, request, result));
        return abi.encode(result, expires, abi.encodePacked(r, s, v));
    }

    function testResolveRevertsWithOffchainLookup() public {
        bytes memory callData = abi.encodeCall(resolver.resolve, (name, addrCall));
        string[] memory urls = new string[](1);
        urls[0] = "https://example.com/{sender}/{data}";
        vm.expectRevert(
            abi.encodeWithSelector(
                BasePaintNameResolver.OffchainLookup.selector,
                address(resolver),
                urls,
                callData,
                resolver.resolveWithProof.selector,
                callData
            )
        );
        resolver.resolve(name, addrCall);
    }

    function testResolveWithProof() public {
        bytes memory request = abi.encodeCall(resolver.resolve, (name, addrCall));
        bytes memory result = abi.encode(address(0xA11CE));
        bytes memory response = sign(signerKey, uint64(block.timestamp + 300), request, result);
        assertEq(resolver.resolveWithProof(response, request), result);
    }

    function testRejectsOtherSignerAndExpiredAnswers() public {
        bytes memory request = abi.encodeCall(resolver.resolve, (name, addrCall));
        bytes memory result = abi.encode(address(0xA11CE));

        bytes memory forged = sign(0xbad, uint64(block.timestamp + 300), request, result);
        vm.expectRevert(BasePaintNameResolver.InvalidSigner.selector);
        resolver.resolveWithProof(forged, request);

        vm.warp(1000);
        bytes memory expired = sign(signerKey, 999, request, result);
        vm.expectRevert(BasePaintNameResolver.SignatureExpired.selector);
        resolver.resolveWithProof(expired, request);
    }

    function testOnlyOwnerUpdatesUrlAndSigner() public {
        vm.expectRevert();
        resolver.setSigner(address(0xBEEF));

        vm.startPrank(owner);
        resolver.setSigner(address(0xBEEF));
        resolver.setUrl("https://basepaint.xyz/api/ens?sender={sender}&data={data}");
        vm.stopPrank();
        assertEq(resolver.signer(), address(0xBEEF));
        assertEq(resolver.url(), "https://basepaint.xyz/api/ens?sender={sender}&data={data}");
    }

    function testSupportsExtendedResolver() public {
        assertTrue(resolver.supportsInterface(0x9061b923));
        assertTrue(resolver.supportsInterface(0x01ffc9a7));
        assertFalse(resolver.supportsInterface(0x3b3b57de));
    }
}
