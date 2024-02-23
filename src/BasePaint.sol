// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IBasePaintBrush} from "./BasePaintBrush.sol";

contract BasePaint is ERC1155("https://basepaint.xyz/api/art/{id}"), Ownable(msg.sender) {
    IBasePaintBrush public brushes;
    uint256 public immutable epochDuration;

    struct Canvas {
        uint256 totalContributions;
        uint256 totalRaised;
        mapping(address => uint256) contributions;
        mapping(uint256 => uint256) brushUsed;
    }

    mapping(uint256 => Canvas) public canvases;
    uint256 public startedAt;

    uint256 public openEditionPrice = 0.0026 ether;
    uint256 public ownerFeePartsPerMillion = 100_000; // 10% fee
    uint256 public ownerEarned;

    event Started(uint256 timestamp);
    event Painted(uint256 indexed day, uint256 tokenId, address author, bytes pixels);

    event ArtistsEarned(uint256 indexed day, uint256 amount);
    event ArtistWithdraw(uint256 indexed day, address author, uint256 amount);

    event OpenEditionPriceUpdated(uint256 price);
    event OwnerFeeUpdated(uint256 fee);
    event OwnerWithdrew(uint256 amount, address to);

    constructor(IBasePaintBrush _brushes, uint256 _epochDuration) {
        brushes = _brushes;
        epochDuration = _epochDuration;
    }

    function mint(uint256 day, uint256 count) public payable {
        require(startedAt > 0, "Not started");
        require(day + 1 == today(), "Invalid day");
        require(msg.value >= openEditionPrice * count, "Invalid price");
        require(canvases[day].totalContributions > 0, "Empty canvas");

        _mint(msg.sender, day, count, "");

        uint256 fee = msg.value * ownerFeePartsPerMillion / 1_000_000;
        ownerEarned += fee;
        canvases[day].totalRaised += msg.value - fee;
        emit ArtistsEarned(day, msg.value - fee);
    }

    function paint(uint256 day, uint256 tokenId, bytes calldata pixels) public {
        require(startedAt > 0, "Not started");
        require(day == today(), "Invalid day");
        require(brushes.ownerOf(tokenId) == msg.sender, "You don't own this brush");
        require(pixels.length % 3 == 0, "Invalid pixel data");
        require(pixels.length > 0, "Invalid pixel data");

        uint256 painted = pixels.length / 3;

        Canvas storage canvas = canvases[day];
        canvas.contributions[msg.sender] += painted;
        canvas.brushUsed[tokenId] += painted;
        canvas.totalContributions += painted;

        require(canvas.brushUsed[tokenId] <= brushes.strengths(tokenId), "Brush used too much");
        emit Painted(day, tokenId, msg.sender, pixels);
    }

    function contribution(uint256 day, address author) public view returns (uint256) {
        return canvases[day].contributions[author];
    }

    function brushUsed(uint256 day, uint256 tokenId) public view returns (uint256) {
        return canvases[day].brushUsed[tokenId];
    }

    function today() public view returns (uint256) {
        // Starts from day 1
        return ((block.timestamp - startedAt) / epochDuration) + 1;
    }

    function authorWithdraw(uint256[] calldata indexes) public {
        uint256 maxDay = today() - 1;
        for (uint256 i = 0; i < indexes.length; i++) {
            uint256 day = indexes[i];
            require(day < maxDay, "Invalid day");

            Canvas storage canvas = canvases[day];
            require(canvas.totalRaised > 0, "No funds to withdraw");
            require(canvas.totalContributions > 0, "Empty canvas");
            require(canvas.contributions[msg.sender] > 0, "No contributions");

            uint256 amount = canvas.totalRaised * canvas.contributions[msg.sender] / canvas.totalContributions;
            canvas.totalRaised -= amount;
            canvas.totalContributions -= canvas.contributions[msg.sender];
            canvas.contributions[msg.sender] = 0;

            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "Transfer failed");
            emit ArtistWithdraw(day, msg.sender, amount);
        }
    }

    function start() public onlyOwner {
        require(startedAt == 0, "Already started");

        startedAt = block.timestamp;
        emit Started(startedAt);
    }

    function setURI(string calldata newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setOwnerFee(uint256 newFee) public onlyOwner {
        require(newFee < 1_000_000, "Invalid fee");
        ownerFeePartsPerMillion = newFee;
        emit OwnerFeeUpdated(newFee);
    }

    function setOpenEditionPrice(uint256 newPrice) public onlyOwner {
        openEditionPrice = newPrice;
        emit OpenEditionPriceUpdated(newPrice);
    }

    function withdraw(address to) public onlyOwner {
        uint256 amount = ownerEarned;
        ownerEarned = 0;

        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");
        emit OwnerWithdrew(amount, to);
    }
}
