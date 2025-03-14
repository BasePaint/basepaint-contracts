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

interface IBasePaint is IERC1155 {
    function openEditionPrice() external view returns (uint256);
    function mint(uint256 day, uint256 count) external payable;
    function today() external view returns (uint256);
}

contract BasePaintSubscription is Ownable {

    event BalanceLessThanRequired(
        address indexed _address, uint96 indexed _actualBalance, uint256 indexed _expectedBalance
    );

    event MintSkippedBalance(address indexed _address, uint96 indexed _balance, uint8 indexed _amountToMint);

    event MintSkippedDaily(address indexed _address, uint96 indexed _balance, uint16 indexed _lastMinted);

    event Subscribed(address indexed subscriber, address indexed mintTo, uint96 indexed balance, uint8 mintPerDay);

    event SubscriptionExtended(address indexed subscriber);

    event Unsubscribed(address indexed subscriber, uint256 refundAmount);

    error CantBeZero();
    error MustSendETH();
    error NoBalance();
    error NotEnoughMinted();
    error NotMinter();
    error RefundFailed();
    error SubAlreadyExists();
    error SubDoesntExist();
    error WrongAmount();

    IBasePaint public basepaint;
    address public minter;

    struct Subscription {
        address mintToAddress;
        uint96 balance;
        uint8 mintPerDay;
        uint16 lastMinted;
        bool active;
    }

    mapping(address => Subscription) public subscriptions;

    constructor(address _basepaint, address _minter, address _owner) Ownable(_owner) {
        basepaint = IBasePaint(_basepaint);
        minter = _minter;
    }

    function subscribe(uint8 _mintPerDay, address _mintToAddress, uint256 _length) external payable {
        uint256 value = msg.value;
        if (value == 0) revert MustSendETH();
        if (_mintPerDay == 0) revert CantBeZero();

        address sender = msg.sender;

        uint256 price = basepaint.openEditionPrice();
        uint256 total = price * _mintPerDay * _length;
        
        if (value != total) revert WrongAmount();

        Subscription storage sub = subscriptions[sender];
        if (sub.active) revert SubAlreadyExists();

        address mintTo = _mintToAddress == address(0) ? sender : _mintToAddress;

        sub.mintToAddress = mintTo;
        sub.balance = uint96(value);
        sub.mintPerDay = _mintPerDay;
        sub.lastMinted = 0;
        sub.active = true;

        emit Subscribed(sender, mintTo, uint96(value), _mintPerDay);
    }

    function unsubscribe() external {
        Subscription storage subscription = subscriptions[msg.sender];

        if (!subscription.active) revert SubDoesntExist();
        if (subscription.balance == 0) revert NoBalance();

        uint256 refund = subscription.balance;
        
        subscription.active = false;
        subscription.balance = 0;

        emit Unsubscribed(msg.sender, refund);

        (bool success,) = payable(msg.sender).call{value: refund}("");
        if (!success) revert RefundFailed();
    }

    function mintDaily(address[] calldata _addresses, uint256 _toMint) external {
        if (msg.sender != minter) revert NotMinter();

        uint256 today = basepaint.today() - 1;
        uint256 mintCost = basepaint.openEditionPrice();

        basepaint.mint{value: mintCost * _toMint}(today, _toMint);

        uint256 minted;
        for (uint256 i; i < _addresses.length;) {
            Subscription storage subscription = subscriptions[_addresses[i]];

            if (!subscription.active || subscription.balance == 0) {
                emit MintSkippedBalance(_addresses[i], subscription.balance, subscription.mintPerDay);

                unchecked {
                    ++i;
                }
                continue;
            }

            uint48 count = subscription.mintPerDay;
            uint256 totalSpend = mintCost * count;

            if (subscription.balance < totalSpend) {
                emit BalanceLessThanRequired(_addresses[i], subscription.balance, totalSpend);

                unchecked {
                    ++i;
                }
                continue;
            }

            if (subscription.lastMinted == today) {
                emit MintSkippedDaily(_addresses[i], subscription.balance, subscription.lastMinted);

                unchecked {
                    ++i;
                }
                continue;
            }

            subscription.lastMinted = uint16(today);
            subscription.balance -= uint96(totalSpend);

            basepaint.safeTransferFrom(address(this), subscription.mintToAddress, today, count, "");

            unchecked {
                minted += count;
                ++i;
            }
        }

        if (minted != _toMint) revert NotEnoughMinted();
    }

    function setNewMinter(address _newMinter) external onlyOwner {
        minter = _newMinter;
    }

    receive() external payable {
        Subscription storage subscription = subscriptions[msg.sender];
        if (!subscription.active) revert SubDoesntExist();
        subscription.balance += uint96(msg.value);
        emit SubscriptionExtended(msg.sender);
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