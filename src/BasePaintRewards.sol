// SPDX-License-Identifier: MIT

//    ___               ___       _      __    ___                         __
//   / _ )___ ____ ___ / _ \___ _(_)__  / /_  / _ \___ _    _____ ________/ /__
//  / _  / _ `(_-</ -_) ___/ _ `/ / _ \/ __/ / , _/ -_) |/|/ / _ `/ __/ _  (_-<
// /____/\_,_/___/\__/_/   \_,_/_/_//_/\__/ /_/|_|\__/|__,__/\_,_/_/  \_,_/___/

pragma solidity ^0.8.13;

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

interface IBasePaint is IERC1155 {
    function today() external view returns (uint256);
    function mint(uint256 day, uint256 count) external payable;
}

contract BasePaintRewards is Ownable(msg.sender), ERC20("BasePaint Rewards", "BPR"), ERC1155Holder {
    IBasePaint public immutable basepaint;
    mapping(address referrer => uint256 bips) public rewardRate; // bips, 1 = 0.1%
    uint256 public defaultRewardRate = 10; // 1.0%

    error NotEnoughContractFunds();
    error NoRewards();
    error TransferFailed();
    error InvalidRate();

    event ToppedUp(uint256 amount);

    constructor(IBasePaint _basepaint) {
        basepaint = _basepaint;
    }

    function mintLatest(address sendMintsTo, uint256 count, address sendRewardsTo) public payable {
        uint256 tokenIdOnSale = basepaint.today() - 1;
        mint(tokenIdOnSale, sendMintsTo, count, sendRewardsTo);
    }

    function mint(uint256 tokenId, address sendMintsTo, uint256 count, address sendRewardsTo) public payable {
        basepaint.mint{value: msg.value}(tokenId, count);
        basepaint.safeTransferFrom(address(this), sendMintsTo, tokenId, count, "");

        if (sendRewardsTo == address(0)) {
            return;
        }

        uint256 rate = rewardRate[sendRewardsTo];
        if (rate == 0) {
            rate = defaultRewardRate;
        }

        uint256 reward = msg.value * rate / 1_000;
        _mint(sendRewardsTo, reward);
    }

    function cashOut(address account) public {
        uint256 available = address(this).balance;
        if (available == 0) {
            revert NotEnoughContractFunds();
        }

        uint256 balance = balanceOf(account);
        if (balance == 0) {
            revert NoRewards();
        }

        uint256 withdrawable = available < balance ? available : balance;

        _burn(account, withdrawable);
        (bool success,) = account.call{value: withdrawable}("");

        if (!success) {
            revert TransferFailed();
        }
    }

    function cashOutBatched(address[] calldata accounts) external {
        for (uint256 i = 0; i < accounts.length; i++) {
            cashOut(accounts[i]);
        }
    }

    function setRewardRate(address referrer, uint256 bips) external onlyOwner {
        if (bips > 1_000) {
            revert InvalidRate();
        }

        if (referrer == address(0)) {
            defaultRewardRate = bips;
        } else {
            rewardRate[referrer] = bips;
        }
    }

    function withdraw(uint256 value) external onlyOwner {
        (bool success,) = msg.sender.call{value: value}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    receive() external payable {
        emit ToppedUp(msg.value);
    }
}
