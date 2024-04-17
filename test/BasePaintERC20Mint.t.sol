// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IBasePaintBrush} from "../src/BasePaintBrush.sol";
import {BasePaintERC20Mint} from "../src/BasePaintERC20Mint.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface IBasePaintRewards {
    function mintLatest(address sendMintsTo, uint256 count, address sendRewardsTo) external payable;
}

interface IBasePaint {
    function openEditionPrice() external view returns (uint256);
}

interface IWETH {
    function withdraw(uint256 amount) external;
}

contract BasePaintERC20MintTest is Test {
    BasePaintERC20Mint public basePaintERC20Mint;
    IERC20 public ERC20;

    function setUp() public {
        ERC20 = IERC20(0x0578d8A44db98B23BF096A382e016e29a5Ce0ffe); // Higher Address

        basePaintERC20Mint = new BasePaintERC20Mint(
            0xaff1A9E200000061fC3283455d8B0C7e3e728161,
            0x2626664c2603336E57B271c5C0b26F421741e481,
            0x4200000000000000000000000000000000000006
        );
    }

    function testERC20Mint() public {
        address minterAddress = address(1);

        vm.startPrank(minterAddress);
        uint256 swapInAmount = 3000 * 1e18;

        deal(address(ERC20), minterAddress, swapInAmount);

        ERC20.approve(address(basePaintERC20Mint), swapInAmount);
        basePaintERC20Mint.mintWithERC20(address(ERC20), minterAddress, address(0), swapInAmount, 1, 0.0026 * 1e18);
    }
}
