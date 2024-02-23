// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IBasePaint is IERC1155 {
    function openEditionPrice() external view returns (uint256);
    function mint(uint256 day, uint256 count) external payable;
    function today() external view returns (uint256);
}

contract BasePaintCollector {
    IBasePaint public basepaint;

    struct Deposit {
        uint96 amount;
        uint16 lastDayMinted;
        uint16 mintPerDay;
    }

    mapping(address => Deposit) public deposists;

    constructor(IBasePaint _basepaint) {
        basepaint = _basepaint;
    }

    function deposit(uint16 mintPerDay) public payable {
        deposists[msg.sender].amount += uint96(msg.value);
        deposists[msg.sender].mintPerDay += mintPerDay;
    }

    function withdraw() public {
        uint256 amount = deposists[msg.sender].amount;
        require(amount > 0, "No deposit");
        deposists[msg.sender].amount = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function mint(address to) public {
        uint256 price = basepaint.openEditionPrice();
        uint256 today = basepaint.today();
        Deposit storage d = deposists[msg.sender];

        require(d.lastDayMinted < today, "Already minted today");
        d.lastDayMinted = uint16(today);

        uint256 maxCount = d.amount / price;
        uint256 count = d.mintPerDay > maxCount ? maxCount : d.mintPerDay;

        require(count > 0, "Out of funds");
        d.amount -= uint96(count * price);

        basepaint.mint{value: price * count}(today, count);
        basepaint.safeTransferFrom(address(this), to, today, count, "");
    }
}
