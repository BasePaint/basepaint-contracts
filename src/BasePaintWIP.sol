// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

contract BasePaintWIP is ERC721("BasePaint WIP", "BPWIP"), EIP712("BasePaint WIP", "1"), Ownable(msg.sender) {
    address private _signer;
    string public baseURI = "https://basepaint.xyz/api/wip/";

    constructor(address signer) {
        _signer = signer;
    }

    function mint(bytes32 txHash, bytes calldata signature) public {
        bytes32 structHash = keccak256(abi.encode(keccak256("Mint(address to,bytes32 txHash)"), msg.sender, txHash));

        bytes32 digest = _hashTypedDataV4(structHash);
        require(SignatureChecker.isValidSignatureNow(_signer, digest, signature), "Invalid signature");

        _safeMint(msg.sender, uint256(txHash));
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        return string.concat(baseURI, Strings.toHexString(tokenId));
    }

    function setSigner(address signer) public onlyOwner {
        _signer = signer;
    }

    function setBaseURI(string calldata newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }
}
