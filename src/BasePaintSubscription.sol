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
    IBasePaint public basepaint;
    address public minter;
    
    uint256 public subsidyBalance;
    uint256 public constant SUBSIDY_PERCENT = 5;

    struct Subscription {
        address mintToAddress;
        uint96 balance;
        uint8 mintPerDay;
        uint16 lastMinted;
        bool active;
    }

    mapping(address => Subscription) public subscriptions;

    event BalanceLessThanRequired(address indexed _address, uint96 indexed _actualBalance, uint256 indexed _expectedBalance);
    event MintSkippedBalance(address indexed _address, uint96 indexed _balance, uint8 indexed _amountToMint);
    event MintSkippedDaily(address indexed _address, uint96 indexed _balance, uint16 indexed _lastMinted);
    event Subscribed(address indexed subscriber, address indexed mintTo, uint96 indexed balance, uint8 mintPerDay);
    event SubscriptionExtended(address indexed subscriber, uint256 indexed amount);
    event Unsubscribed(address indexed subscriber, uint256 refundAmount);
    event SubsidyAdded(uint256 amount);

    error CantBeZero();
    error MustSendETH();
    error NoBalance();
    error NotEnoughMinted();
    error NotMinter();
    error RefundFailed();
    error SubAlreadyExists();
    error SubDoesntExist();
    error WrongAmount();
    error InsufficientSubsidy();

    constructor(address _basepaint, address _minter, address _owner) Ownable(_owner) {
        basepaint = IBasePaint(_basepaint);
        minter = _minter;
    }

    function addSubsidy() external payable onlyOwner {
        if (msg.value == 0) revert MustSendETH();
        subsidyBalance += msg.value;
        emit SubsidyAdded(msg.value);
    }

    function withdrawSubsidy(uint256 _amount) external onlyOwner {
        if (_amount > subsidyBalance) revert InsufficientSubsidy();
        subsidyBalance -= _amount;
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) revert RefundFailed();
    }

    function getSubsidizedPrice(uint256 _price) public pure returns (uint256) {
        return _price * (100 - SUBSIDY_PERCENT) / 100;
    }

    function subscribe(uint8 _mintPerDay, address _mintToAddress, uint256 _length) external payable {
        if (msg.value == 0) revert MustSendETH();
        if (_mintPerDay == 0) revert CantBeZero();
        
        Subscription storage sub = subscriptions[msg.sender];
        if (sub.active) revert SubAlreadyExists();

        uint256 price = basepaint.openEditionPrice();
        uint256 subsidizedPrice = getSubsidizedPrice(price);
        uint256 total = subsidizedPrice * _mintPerDay * _length;
        
        if (msg.value != total) revert WrongAmount();
        
        sub.mintToAddress = _mintToAddress;
        sub.balance = uint96(msg.value);
        sub.mintPerDay = _mintPerDay;
        sub.lastMinted = 0;
        sub.active = true;

        emit Subscribed(msg.sender, _mintToAddress, uint96(msg.value), _mintPerDay);
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

    function _extendSubscription(address subscriber) private {
        Subscription storage subscription = subscriptions[subscriber];
        if (!subscription.active) revert SubDoesntExist();
        subscription.balance += uint96(msg.value);
        emit SubscriptionExtended(subscriber, msg.value);
    }

    function extendSubscription() external payable {
        _extendSubscription(msg.sender);
    }

    receive() external payable {
        _extendSubscription(msg.sender);
    }

    function mintDaily(address[] calldata _addresses, uint256 _toMint) external {
        if (msg.sender != minter) revert NotMinter();

        uint256 today = basepaint.today() - 1;
        uint256 mintCost = basepaint.openEditionPrice();
        
        uint256 totalSubsidyNeeded = 0;
        uint256 totalMintCost = 0;
        uint256 minted = 0;
        
        for (uint256 i; i < _addresses.length;) {
            Subscription storage subscription = subscriptions[_addresses[i]];

            if (!subscription.active || subscription.balance == 0) {
                emit MintSkippedBalance(_addresses[i], subscription.balance, subscription.mintPerDay);
                unchecked { ++i; }
                continue;
            }

            if (subscription.lastMinted == today) {
                emit MintSkippedDaily(_addresses[i], subscription.balance, subscription.lastMinted);
                unchecked { ++i; }
                continue;
            }

            uint8 count = subscription.mintPerDay;
            uint256 fullCost = mintCost * count;
            uint256 subsidyCost = fullCost * SUBSIDY_PERCENT / 100;
            uint256 userCost = fullCost - subsidyCost;

            if (subscription.balance < userCost) {
                emit BalanceLessThanRequired(_addresses[i], subscription.balance, userCost);
                unchecked { ++i; }
                continue;
            }

            totalSubsidyNeeded += subsidyCost;
            totalMintCost += fullCost;
            minted += count;
            unchecked { ++i; }
        }
        
        if (subsidyBalance < totalSubsidyNeeded) revert InsufficientSubsidy();
        
        if (minted > 0) {
            subsidyBalance -= totalSubsidyNeeded;
            basepaint.mint{value: totalMintCost}(today, minted);
            
            for (uint256 i; i < _addresses.length;) {
                Subscription storage subscription = subscriptions[_addresses[i]];
                
                if (subscription.active && 
                    subscription.balance > 0 && 
                    subscription.lastMinted != today) {
                    
                    uint256 fullCost = mintCost * subscription.mintPerDay;
                    uint256 userCost = getSubsidizedPrice(fullCost);
                    
                    subscription.balance -= uint96(userCost);
                    subscription.lastMinted = uint16(today);
                    
                    basepaint.safeTransferFrom(
                        address(this), 
                        subscription.mintToAddress, 
                        today, 
                        subscription.mintPerDay, 
                        ""
                    );
                }
                
                unchecked { ++i; }
            }
        }

        if (minted != _toMint) revert NotEnoughMinted();
    }

    function setNewMinter(address _newMinter) external onlyOwner {
        minter = _newMinter;
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