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
    IBasePaint immutable basepaint;

    error WrongEthAmount();

    struct Subscription {
    uint256 day;
    uint256 count;
}

    constructor(address _basepaint, address _owner)
        Ownable(_owner)
        ERC1155("https://basepaint.xyz/api/subscription/{id}")
    {
        basepaint = IBasePaint(_basepaint);
    }

function subscribe(Subscription[] calldata _subscriptions, address _mintToAddress) payable external {
    uint256 price = basepaint.openEditionPrice();
    uint256 totalCount = 0;
    
    for (uint256 i = 0; i < _subscriptions.length; i++) {
        totalCount += _subscriptions[i].count;
    }

    if (msg.value != totalCount * price) revert WrongEthAmount();

    for (uint256 i = 0; i < _subscriptions.length; i++) {
        _mint(_mintToAddress, _subscriptions[i].day, _subscriptions[i].count, "");
    }
}

    function mintDaily(address[] calldata _addresses) external {
        uint256 today = basepaint.today() - 1;
        uint256 mintCost = basepaint.openEditionPrice();

        for (uint256 i; i < _addresses.length;) {
            uint256 tokenBalance = balanceOf(_addresses[i], today);
            if (tokenBalance > 0) {
                basepaint.mint{value: mintCost * tokenBalance}(today, tokenBalance);
                _burn(_addresses[i], today, tokenBalance);
                basepaint.safeTransferFrom(address(this), _addresses[i], today, tokenBalance, "");
            }
            unchecked {
                ++i;
            }
        }
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

    receive() external payable {}
}
