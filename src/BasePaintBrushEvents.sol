// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBasePaintBrush {
    function upgrade(uint256 tokenId, uint256 strength, uint256 nonce, bytes calldata signature) external payable;
}

contract BasePaintBrushEvents {
    IBasePaintBrush public immutable basePaintBrush;

    event Deployed();
    event StrengthChanged(uint256 indexed tokenId, uint256 strength);

    constructor(IBasePaintBrush _basePaintBrush) {
        basePaintBrush = _basePaintBrush;
        emit Deployed();
    }

    function upgrade(uint256 tokenId, uint256 strength, uint256 nonce, bytes calldata signature) external payable {
        basePaintBrush.upgrade{value: msg.value}(tokenId, strength, nonce, signature);
        emit StrengthChanged(tokenId, strength);
    }

    function upgradeMulti(
        uint256[] calldata tokenIds,
        uint256[] calldata strengths,
        uint256[] calldata nonces,
        bytes[] calldata signatures
    ) external {
        require(tokenIds.length == strengths.length, "Invalid input");
        require(tokenIds.length == nonces.length, "Invalid input");
        require(tokenIds.length == signatures.length, "Invalid input");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            basePaintBrush.upgrade(tokenIds[i], strengths[i], nonces[i], signatures[i]);
            emit StrengthChanged(tokenIds[i], strengths[i]);
        }
    }
}
