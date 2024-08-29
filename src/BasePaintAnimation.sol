// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract BasePaintAnimation is
    ERC1155("https://basepaint.xyz/api/animation/{id}"),
    Ownable(msg.sender),
    IERC1155Receiver
{
    error NotSupported();
    error WrongAmount();
    error WrongCollection();

    address internal immutable _basepaint = 0xBa5e05cb26b78eDa3A2f8e3b3814726305dcAc83;

    function setURI(string calldata newuri) public onlyOwner {
        _setURI(newuri);
    }

    function onERC1155Received(address, /*operator*/ address from, uint256 id, uint256 value, bytes calldata /*data*/ )
        public
        returns (bytes4)
    {
        if (value == 0) revert WrongAmount();
        if (value % 2 != 0) revert WrongAmount();
        if (msg.sender != _basepaint) revert WrongCollection();

        // Burn the artwork NFTs
        ERC1155(_basepaint).safeTransferFrom(address(this), 0x000000000000000000000000000000000000dEaD, id, value, "");

        // Mint animation NFT
        _mint(from, id, value / 2, "");

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        for (uint256 i = 0; i < ids.length; i++) {
            onERC1155Received(operator, from, ids[i], values[i], data);
        }
        return this.onERC1155BatchReceived.selector;
    }
}
