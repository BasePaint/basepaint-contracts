// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @notice ENS resolver for *.basepaint.xyz. Every lookup is answered by the BasePaint app over
/// CCIP-read (EIP-3668, ENSIP-10) and accepted only when signed by `signer`.
/// Same signature format as ENS's reference OffchainResolver.
contract BasePaintNameResolver is Ownable {
    string public url;
    address public signer;

    event UrlUpdated(string url);
    event SignerUpdated(address signer);

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);
    error SignatureExpired();
    error InvalidSigner();

    constructor(address initialOwner, string memory initialUrl, address initialSigner) Ownable(initialOwner) {
        url = initialUrl;
        signer = initialSigner;
        emit UrlUpdated(initialUrl);
        emit SignerUpdated(initialSigner);
    }

    function setUrl(string calldata newUrl) external onlyOwner {
        url = newUrl;
        emit UrlUpdated(newUrl);
    }

    function setSigner(address newSigner) external onlyOwner {
        signer = newSigner;
        emit SignerUpdated(newSigner);
    }

    /// @param name DNS-encoded name, e.g. alex.basepaint.xyz.
    /// @param data ABI-encoded resolver call such as addr(bytes32).
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        bytes memory callData = abi.encodeCall(this.resolve, (name, data));
        string[] memory urls = new string[](1);
        urls[0] = url;
        revert OffchainLookup(address(this), urls, callData, this.resolveWithProof.selector, callData);
    }

    /// @param response ABI-encoded (bytes result, uint64 expires, bytes signature) from the gateway.
    /// @param extraData The original gateway request.
    function resolveWithProof(bytes calldata response, bytes calldata extraData) external view returns (bytes memory) {
        (bytes memory result, uint64 expires, bytes memory signature) = abi.decode(response, (bytes, uint64, bytes));
        if (expires < block.timestamp) revert SignatureExpired();

        bytes32 hash = makeSignatureHash(expires, extraData, result);
        if (ECDSA.recover(hash, signature) != signer) revert InvalidSigner();
        return result;
    }

    function makeSignatureHash(uint64 expires, bytes memory request, bytes memory result)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(hex"1900", address(this), expires, keccak256(request), keccak256(result)));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == this.resolve.selector // ENSIP-10 IExtendedResolver
            || interfaceId == 0x01ffc9a7; // ERC-165
    }
}
