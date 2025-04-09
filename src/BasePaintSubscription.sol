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

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

interface IBasePaint is IERC1155 {
    function openEditionPrice() external view returns (uint256);
    function mint(uint256 day, uint256 count) external payable;
    function today() external view returns (uint256);
}

contract BasePaintSubscription is Initializable, OwnableUpgradeable, ERC1155Upgradeable, UUPSUpgradeable {
    IBasePaint public basepaint;
    uint256 immutable discountBasisPoints = 500; // 5%

    error WrongEthAmount();
    error InvalidSubscribedDay();

    struct Subscription {
        uint256 day;
        uint256 count;
    }

    function initialize(address _basepaint, address _owner) public initializer {
        __Ownable_init(_owner);
        __ERC1155_init("https://basepaint.xyz/api/subscription/{id}");
        __UUPSUpgradeable_init();

        basepaint = IBasePaint(_basepaint);
    }

    function subscribe(Subscription[] calldata _subscriptions, address _mintToAddress) external payable {
        uint256 mintingToday = basepaint.today() - 1;
        uint256 fullPrice = basepaint.openEditionPrice();
        uint256 discountedPrice = fullPrice * (10000 - discountBasisPoints) / 10000;
        uint256 totalCount = 0;

        for (uint256 i = 0; i < _subscriptions.length; i++) {
            totalCount += _subscriptions[i].count;
            if (_subscriptions[i].day < mintingToday) {
                revert InvalidSubscribedDay();
            }
        }

        if (msg.value < totalCount * discountedPrice) revert WrongEthAmount();

        for (uint256 i = 0; i < _subscriptions.length; i++) {
            if (_subscriptions[i].day == mintingToday) {
                basepaint.mint{value: fullPrice * _subscriptions[i].count}(mintingToday, _subscriptions[i].count);
                basepaint.safeTransferFrom(address(this), _mintToAddress, mintingToday, _subscriptions[i].count, "");
            } else if (_subscriptions[i].day > mintingToday) {
                _mint(_mintToAddress, _subscriptions[i].day, _subscriptions[i].count, "");
            }
        }
    }

    function mintBasePaints(address[] calldata _addresses) external {
        uint256 mintingToday = basepaint.today() - 1;
        uint256 mintCost = basepaint.openEditionPrice();

        for (uint256 i = 0; i < _addresses.length; i++) {
            uint256 tokenBalance = balanceOf(_addresses[i], mintingToday);
            if (tokenBalance > 0) {
                _burn(_addresses[i], mintingToday, tokenBalance);
                basepaint.mint{value: mintCost * tokenBalance}(mintingToday, tokenBalance);
                basepaint.safeTransferFrom(address(this), _addresses[i], mintingToday, tokenBalance, "");
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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

    receive() external payable {}
}
