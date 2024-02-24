// SPDX-License-Identifier: MIT
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
    mapping(address => uint256) public rewardRate; // bpis, 1 = 0.1%
    uint256 public defaultRewardRate = 10; // 1.0%

    event ToppedUp(uint256 amount);

    constructor(IBasePaint _basepaint) {
        basepaint = _basepaint;
    }

    function mint(address to, uint256 count, address sendRewardsTo) external payable {
        uint256 day = basepaint.today() - 1;
        basepaint.mint{value: msg.value}(day, count);
        basepaint.safeTransferFrom(address(this), to, day, count, "");

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
        require(available > 0, "No funds available in the contract, try later");

        uint256 balance = balanceOf(account);
        require(balance > 0, "No rewards to cash out");

        uint256 withdrawable = available < balance ? available : balance;

        _burn(account, withdrawable);
        (bool success,) = account.call{value: withdrawable}("");
        require(success, "Transfer failed");
    }

    function cashOutBatched(address[] calldata accounts) public {
        for (uint256 i = 0; i < accounts.length; i++) {
            cashOut(accounts[i]);
        }
    }

    function setRewardRate(address account, uint256 rate) public onlyOwner {
        require(rate <= 1_000, "Invalid rate");
        if (account != address(0)) {
            rewardRate[account] = rate;
        } else {
            defaultRewardRate = rate;
        }
    }

    function withdraw(uint256 value) public onlyOwner {
        (bool success,) = msg.sender.call{value: value}("");
        require(success, "Transfer failed");
    }

    receive() external payable {
        emit ToppedUp(msg.value);
    }
}
