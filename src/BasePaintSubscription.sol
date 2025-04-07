// SPDX-License-Identifier: MIT

//  ____                  ____       _       _
// | __ )  __ _ ___  ___ |  _ \ __ _(_)_ __ | |_
// |  _ \ / _` / __|/ _ \| |_) / _` | | '_ \| __|
// | |_) | (_| \__ \  __/|  __/ (_| | | | | | |_
// |____/ \__,_|___/\___||_|   \__,_|_|_| |_|\__|
//  ____        _                  _       _   _
// / ___| _   _| |__  ___  ___ _ __(_)_ __ | |_(_) ___  _ __
// \___ \| | | | '_ \/ __|/ __| '__| | '_ \| __| |/ _ \| '_ \
//  ___) | |_| | |_) \__ \ (__| |  | | |_) | |_| | (_) | | | |
// |____/ \__,_|_.__/|___/\___|_|  |_| .__/ \__|_|\___/|_| |_|
//                                   |_|

pragma solidity ^0.8.17;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

interface IBasePaint is IERC1155 {
    function openEditionPrice() external view returns (uint256);
    function mint(uint256 day, uint256 count) external payable;
    function today() external view returns (uint256);
}

contract BasePaintSubscription is Ownable, ERC1155 {
    IBasePaint public basepaint;

    event Subscribed(address indexed subscriber, address indexed mintTo, uint256 length);

    error NotEnoughMinted();
    error WrongEthAmount();
    error InsufficientBalance();

    constructor(address _basepaint, address _owner)
        Ownable(_owner)
        ERC1155("https://basepaint.xyz/api/subscription/{id}")
    {
        basepaint = IBasePaint(_basepaint);
    }

    function subscribe(uint8 _mintPerDay, address _mintToAddress, uint256 _length) external payable {
        uint256 price = basepaint.openEditionPrice();
        uint256 total = price * _mintPerDay * _length;

        if (msg.value != total) revert WrongEthAmount();

        emit Subscribed(msg.sender, _mintToAddress, _length);

        uint256 todayId = basepaint.today();
        for (uint256 i = 0; i < _length; i++) {
            _mint(msg.sender, todayId + i, _mintPerDay, "");
        }
    }

    function mintDaily(address[] calldata _addresses, uint256 _toMint) external {
        uint256 today = basepaint.today() - 1;
        uint256 mintCost = basepaint.openEditionPrice();

        uint256 totalMintCost = 0;
        uint256 minted = 0;

        for (uint256 i; i < _addresses.length;) {
            uint256 tokenBalance = balanceOf(_addresses[i], today);
            if (tokenBalance == 0) {
                unchecked {
                    ++i;
                }
                continue;
            }

            totalMintCost += mintCost * tokenBalance;
            minted += tokenBalance;
            unchecked {
                ++i;
            }
        }

        if (address(this).balance < totalMintCost) revert InsufficientBalance();

        if (minted > 0) {
            basepaint.mint{value: totalMintCost}(today, minted);

            for (uint256 i; i < _addresses.length;) {
                address mintToAddress = _addresses[i];

                uint256 tokenBalance = balanceOf(_addresses[i], today);
                if (tokenBalance > 0) {
                    adminTransferAndBurn(_addresses[i], today, tokenBalance);

                    basepaint.safeTransferFrom(address(this), mintToAddress, today, tokenBalance, "");
                }

                unchecked {
                    ++i;
                }
            }
        }

        if (minted != _toMint) revert NotEnoughMinted();
    }

    function adminTransferAndBurn(address _from, uint256 _id, uint256 _amount) internal {
        _safeTransferFrom(_from, address(this), _id, _amount, "");
        _burn(address(this), _id, _amount);
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
