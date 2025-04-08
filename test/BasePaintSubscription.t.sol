// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BasePaintSubscription.sol";

contract MockBasePaint is IERC1155 {
    uint256 private _openEditionPrice = 0.0026 ether;
    uint256 private _today = 600;
    mapping(address => mapping(uint256 => uint256)) private _balances;

    function openEditionPrice() external view returns (uint256) {
        return _openEditionPrice;
    }

    function setOpenEditionPrice(uint256 price) external {
        _openEditionPrice = price;
    }

    function today() external view returns (uint256) {
        return _today;
    }

    function setToday(uint256 day) external {
        _today = day;
    }

    function mint(uint256 day, uint256 count) external payable {
        require(msg.value == count * _openEditionPrice, "Incorrect payment");
        _balances[address(this)][day] += count;
    }

    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return _balances[account][id];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "Accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = _balances[accounts[i]][ids[i]];
        }
        return batchBalances;
    }

    function setApprovalForAll(address, bool) external {}

    function isApprovedForAll(address, address) external pure returns (bool) {
        return true;
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata)
        external
    {
        require(_balances[from][id] >= amount, "Insufficient balance");
        _balances[from][id] -= amount;
        _balances[to][id] += amount;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata
    ) external {
        require(ids.length == amounts.length, "Ids and amounts length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            require(_balances[from][ids[i]] >= amounts[i], "Insufficient balance");
            _balances[from][ids[i]] -= amounts[i];
            _balances[to][ids[i]] += amounts[i];
        }
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}

contract UUPSProxy {
    constructor(address _implementation, bytes memory _data) {
        assembly {
            sstore(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc, _implementation)
        }

        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(_data);
            require(success, "Data execution failed");
        }
    }

    fallback() external payable {
        assembly {
            let implementation := sload(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}

contract BasePaintSubscriptionTest is Test {
    BasePaintSubscription public subscription;
    MockBasePaint public mockBasePaint;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    uint256 public openEditionPrice = 0.0026 ether;

    function setUp() public {
        mockBasePaint = new MockBasePaint();
        
        vm.startPrank(owner);
        BasePaintSubscription impl = new BasePaintSubscription();
        UUPSProxy proxy = new UUPSProxy(address(impl), "");
        subscription = BasePaintSubscription(payable(address(proxy)));
        subscription.initialize(address(mockBasePaint), owner);
        vm.stopPrank();
        
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(subscription), 100 ether);
    }

    function test_Initialize() public {
        assertEq(address(subscription.basepaint()), address(mockBasePaint));
        assertEq(subscription.owner(), owner);
        assertEq(subscription.discountPercentage(), 5);
    }

    function test_SetDiscountPercentage() public {
        vm.prank(owner);
        subscription.setDiscountPercentage(10);
        assertEq(subscription.discountPercentage(), 10);
    }

    function test_RevertWhen_NonOwnerSetsDiscountPercentage() public {
        vm.prank(user1);
        vm.expectRevert();
        subscription.setDiscountPercentage(10);
    }

    function test_RevertWhen_InvalidDiscountPercentage() public {
        vm.prank(owner);
        vm.expectRevert(BasePaintSubscription.InvalidDiscountPercentage.selector);
        subscription.setDiscountPercentage(101);
    }

    function calculateDiscountedPrice(uint256 price, uint256 discountPct) internal pure returns (uint256) {
        return price * (100 - discountPct) / 100;
    }

    function test_Subscribe() public {
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(601, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost = 2 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost}(subscriptions, user1);

        assertEq(subscription.balanceOf(user1, 601), 2);
    }
    
    function test_SubscribeForOtherAddress() public {
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(601, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost = 2 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost}(subscriptions, user2);

        assertEq(subscription.balanceOf(user2, 601), 2);
        assertEq(subscription.balanceOf(user1, 601), 0);
    }

    function test_RevertWhen_SubscribeWithWrongEthAmount() public {
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(601, 2);

        uint256 incorrectCost = openEditionPrice;

        vm.prank(user1);
        vm.expectRevert(BasePaintSubscription.WrongEthAmount.selector);
        subscription.subscribe{value: incorrectCost}(subscriptions, user1);
    }

    function test_RevertWhen_SubscribeForPastDay() public {
        mockBasePaint.setToday(600);
        uint256 pastDay = 599;
        
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(pastDay, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost = 2 * discountedPrice;

        vm.prank(user1);
        vm.expectRevert(BasePaintSubscription.InvalidSubscribedDay.selector);
        subscription.subscribe{value: totalCost}(subscriptions, user1);
    }

    function test_MintBasePaints() public {
        mockBasePaint.setToday(800);
        
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(800, 3);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost = 3 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost}(subscriptions, user1);
        
        mockBasePaint.setToday(801);
        
        vm.mockCall(
            address(mockBasePaint),
            abi.encodeWithSelector(MockBasePaint.mint.selector, 800, 3),
            abi.encode()
        );
        
        vm.mockCall(
            address(mockBasePaint),
            abi.encodeWithSelector(IERC1155.safeTransferFrom.selector),
            abi.encode()
        );
        
        address[] memory addresses = new address[](1);
        addresses[0] = user1;
        
        vm.prank(owner);
        subscription.mintBasePaints(addresses);
        
        assertEq(subscription.balanceOf(user1, 800), 0);
    }

    function test_MintWithDifferentDiscounts() public {
        mockBasePaint.setToday(800);
        
        BasePaintSubscription.Subscription[] memory subscriptions1 = new BasePaintSubscription.Subscription[](1);
        subscriptions1[0] = BasePaintSubscription.Subscription(800, 2);

        uint256 discountedPrice1 = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost1 = 2 * discountedPrice1;

        vm.prank(user1);
        subscription.subscribe{value: totalCost1}(subscriptions1, user1);
        
        vm.prank(owner);
        subscription.setDiscountPercentage(10);
        
        BasePaintSubscription.Subscription[] memory subscriptions2 = new BasePaintSubscription.Subscription[](1);
        subscriptions2[0] = BasePaintSubscription.Subscription(800, 3);

        uint256 discountedPrice2 = calculateDiscountedPrice(openEditionPrice, subscription.discountPercentage());
        uint256 totalCost2 = 3 * discountedPrice2;

        vm.prank(user2);
        subscription.subscribe{value: totalCost2}(subscriptions2, user2);
        
        assertEq(subscription.balanceOf(user1, 800), 2);
        assertEq(subscription.balanceOf(user2, 800), 3);
        
        mockBasePaint.setToday(801);
        
        vm.mockCall(
            address(mockBasePaint),
            abi.encodeWithSelector(MockBasePaint.mint.selector),
            abi.encode()
        );
        
        vm.mockCall(
            address(mockBasePaint),
            abi.encodeWithSelector(IERC1155.safeTransferFrom.selector),
            abi.encode()
        );
        
        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;
        
        vm.prank(owner);
        subscription.mintBasePaints(addresses);
        
        assertEq(subscription.balanceOf(user1, 800), 0);
        assertEq(subscription.balanceOf(user2, 800), 0);
    }

    function test_UpgradeContract() public {
        BasePaintSubscription newImplementation = new BasePaintSubscription();
        
        vm.prank(owner);
        subscription.upgradeToAndCall(address(newImplementation), "");
    }

    function test_RevertWhen_NotOwnerUpgrade() public {
        BasePaintSubscription newImplementation = new BasePaintSubscription();
        
        vm.prank(user1);
        vm.expectRevert();
        subscription.upgradeToAndCall(address(newImplementation), "");
    }

    function test_ReceiveEther() public {
        uint256 initialBalance = address(subscription).balance;
        
        (bool success, ) = address(subscription).call{value: 1 ether}("");
        assertTrue(success);
        
        assertEq(address(subscription).balance, initialBalance + 1 ether);
    }
}