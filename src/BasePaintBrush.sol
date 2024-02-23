// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";

interface IBasePaintBrush is IERC721 {
    function strengths(uint256 tokenId) external view returns (uint256);
}

contract BasePaintBrush is
    ERC721("BasePaint Brush", "BPB"),
    EIP712("BasePaint Brush", "1"),
    IBasePaintBrush,
    Ownable(msg.sender)
{
    uint256 public totalSupply;
    mapping(uint256 => uint256) public strengths;

    address private signer;
    mapping(uint256 => bool) private nonces;
    string private baseURI = "https://basepaint.xyz/api/brush/";

    constructor(address newSigner) {
        signer = newSigner;
    }

    function mint(uint256 strength, uint256 nonce, bytes calldata signature) public payable {
        require(!nonces[nonce], "Nonce already used");
        nonces[nonce] = true;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Mint(address to,uint256 strength,uint256 price,uint256 nonce)"),
                msg.sender,
                strength,
                msg.value,
                nonce
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        require(SignatureChecker.isValidSignatureNow(signer, digest, signature), "Invalid signature");

        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        strengths[totalSupply] = strength;
    }

    function upgrade(uint256 tokenId, uint256 strength, uint256 nonce, bytes calldata signature) public payable {
        require(tokenId > 0 && tokenId <= totalSupply, "Invalid tokenId");
        require(!nonces[nonce], "Nonce already used");
        nonces[nonce] = true;

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Upgrade(uint256 tokenId,uint256 strength,uint256 price,uint256 nonce)"),
                tokenId,
                strength,
                msg.value,
                nonce
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        require(SignatureChecker.isValidSignatureNow(signer, digest, signature), "Invalid signature");

        strengths[tokenId] = strength;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setSigner(address newSigner) public onlyOwner {
        signer = newSigner;
    }

    function setBaseURI(string calldata newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function setStrength(uint256 tokenId, uint256 strength) public onlyOwner {
        strengths[tokenId] = strength;
    }

    function withdraw() public onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}(new bytes(0));
        require(success, "Transfer failed");
    }
}
