// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/BasePaintSubscription.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockBasePaint is ERC1155 {
    uint256 private _openEditionPrice = 0.0026 ether;
    uint256 private _today = 600;

    constructor() ERC1155("") {}

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
        _mint(address(this), day, count, "");
    }
}

contract BasePaintSubscriptionV2 is BasePaintSubscription {
    uint256 public specialDiscountBasisPoints;
    
    function setSpecialDiscountBasisPoints(uint256 _specialDiscountBasisPoints) external onlyOwner {
        specialDiscountBasisPoints = _specialDiscountBasisPoints;
    }
    
    function getSpecialDiscountedPrice(uint256 price) public view returns (uint256) {
        return (price * (10000 - specialDiscountBasisPoints)) / 10000;
    }
}

contract BasePaintSubscriptionTest is Test {
    BasePaintSubscription public subscription;
    MockBasePaint public mockBasePaint;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    uint256 public openEditionPrice = 0.0026 ether;
    uint256 public constant DISCOUNT_BASIS_POINTS = 500; // 5%

    function setUp() public {
        mockBasePaint = new MockBasePaint();

        vm.startPrank(owner);
        BasePaintSubscription impl = new BasePaintSubscription();
        bytes memory initData = abi.encodeWithSelector(
            BasePaintSubscription.initialize.selector,
            address(mockBasePaint),
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        subscription = BasePaintSubscription(payable(address(proxy)));
        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(subscription), 100 ether);
    }

    function test_Initialize() public {
        assertEq(address(subscription.basepaint()), address(mockBasePaint));
        assertEq(subscription.owner(), owner);
    }

    function calculateDiscountedPrice(uint256 price, uint256 discountBasisPoints) internal pure returns (uint256) {
        return (price * (10000 - discountBasisPoints)) / 10000;
    }

    function test_Subscribe() public {
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(601, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, DISCOUNT_BASIS_POINTS);
        uint256 totalCost = 2 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost}(subscriptions, user1);

        assertEq(subscription.balanceOf(user1, 601), 2);
    }

    function test_SubscribeForOtherAddress() public {
        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(601, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, DISCOUNT_BASIS_POINTS);
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
        uint256 pastDay = 598;

        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(pastDay, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, DISCOUNT_BASIS_POINTS);
        uint256 totalCost = 2 * discountedPrice;

        vm.prank(user1);
        vm.expectRevert(BasePaintSubscription.InvalidSubscribedDay.selector);
        subscription.subscribe{value: totalCost}(subscriptions, user1);
    }

    function test_MintBasePaints() public {
        mockBasePaint.setToday(800);

        BasePaintSubscription.Subscription[] memory subscriptions = new BasePaintSubscription.Subscription[](1);
        subscriptions[0] = BasePaintSubscription.Subscription(800, 3);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, DISCOUNT_BASIS_POINTS);
        uint256 totalCost = 3 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost}(subscriptions, user1);

        mockBasePaint.setToday(801);

        vm.mockCall(address(mockBasePaint), abi.encodeWithSelector(MockBasePaint.mint.selector, 800, 3), abi.encode());

        vm.mockCall(address(mockBasePaint), abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), abi.encode());

        address[] memory addresses = new address[](1);
        addresses[0] = user1;

        vm.prank(owner);
        subscription.mintBasePaints(addresses);

        assertEq(subscription.balanceOf(user1, 800), 0);
    }

    function test_MintWithDifferentUsers() public {
        mockBasePaint.setToday(800);

        BasePaintSubscription.Subscription[] memory subscriptions1 = new BasePaintSubscription.Subscription[](1);
        subscriptions1[0] = BasePaintSubscription.Subscription(800, 2);

        uint256 discountedPrice = calculateDiscountedPrice(openEditionPrice, DISCOUNT_BASIS_POINTS);
        uint256 totalCost1 = 2 * discountedPrice;

        vm.prank(user1);
        subscription.subscribe{value: totalCost1}(subscriptions1, user1);

        BasePaintSubscription.Subscription[] memory subscriptions2 = new BasePaintSubscription.Subscription[](1);
        subscriptions2[0] = BasePaintSubscription.Subscription(800, 3);

        uint256 totalCost2 = 3 * discountedPrice;

        vm.prank(user2);
        subscription.subscribe{value: totalCost2}(subscriptions2, user2);

        assertEq(subscription.balanceOf(user1, 800), 2);
        assertEq(subscription.balanceOf(user2, 800), 3);

        mockBasePaint.setToday(801);

        vm.mockCall(address(mockBasePaint), abi.encodeWithSelector(MockBasePaint.mint.selector), abi.encode());

        vm.mockCall(address(mockBasePaint), abi.encodeWithSelector(IERC1155.safeTransferFrom.selector), abi.encode());

        address[] memory addresses = new address[](2);
        addresses[0] = user1;
        addresses[1] = user2;

        vm.prank(owner);
        subscription.mintBasePaints(addresses);

        assertEq(subscription.balanceOf(user1, 800), 0);
        assertEq(subscription.balanceOf(user2, 800), 0);
    }

    function test_UpgradeContract() public {
        BasePaintSubscriptionV2 newImplementation = new BasePaintSubscriptionV2();

        vm.prank(owner);
        subscription.upgradeToAndCall(address(newImplementation), "");
        
        BasePaintSubscriptionV2 upgradedContract = BasePaintSubscriptionV2(payable(address(subscription)));
        
        assertEq(upgradedContract.specialDiscountBasisPoints(), 0);
        
        vm.prank(owner);
        upgradedContract.setSpecialDiscountBasisPoints(1500); // 15%
        
        assertEq(upgradedContract.specialDiscountBasisPoints(), 1500);
        
        uint256 originalPrice = 10000;
        uint256 expectedDiscountedPrice = 8500; // 10000 - 15%
        assertEq(upgradedContract.getSpecialDiscountedPrice(originalPrice), expectedDiscountedPrice);
    }

    function test_RevertWhen_NotOwnerUpgrade() public {
        BasePaintSubscription newImplementation = new BasePaintSubscription();

        vm.prank(user1);
        vm.expectRevert();
        subscription.upgradeToAndCall(address(newImplementation), "");
    }

    function test_ReceiveEther() public {
        uint256 initialBalance = address(subscription).balance;

        (bool success,) = address(subscription).call{value: 1 ether}("");
        assertTrue(success);

        assertEq(address(subscription).balance, initialBalance + 1 ether);
    }
}