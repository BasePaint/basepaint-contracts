// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBasePaintRewards {
    function mintLatest(address sendMintsTo, uint256 count, address sendRewardsTo) external payable;
}

interface IWETH {
    function withdraw(uint256 amount) external;
}

contract BasePaintERC20Mint {
    IBasePaintRewards public basePaintRewards;
    ISwapRouter public swapRouter;
    IWETH public weth;

    uint24 public constant poolFee = 10000;

    constructor(address _basePaintRewards, address _swapRouter, address _weth) {
        basePaintRewards = IBasePaintRewards(_basePaintRewards);
        swapRouter = ISwapRouter(_swapRouter);
        weth = IWETH(_weth);
    }

    function mintWithERC20(
        address mintToken,
        address sendMintsTo,
        address sendRewardsTo,
        uint256 mintTokenAmountIn,
        uint256 mintQuantity,
        uint256 totalETHCost
    ) public {
        // Transfer tokens in and approve router
        TransferHelper.safeTransferFrom(mintToken, msg.sender, address(this), mintTokenAmountIn);
        TransferHelper.safeApprove(mintToken, address(swapRouter), mintTokenAmountIn);

        // Swap settings
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: mintToken,
            tokenOut: address(weth),
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: totalETHCost,
            amountInMaximum: mintTokenAmountIn,
            sqrtPriceLimitX96: 0
        });

        uint256 mintTokenSwapAmount = swapRouter.exactOutputSingle(params);

        // Transfer excess tokens
        if (mintTokenAmountIn > mintTokenSwapAmount) {
            TransferHelper.safeApprove(mintToken, address(swapRouter), 0);
            TransferHelper.safeTransfer(mintToken, msg.sender, mintTokenAmountIn - mintTokenSwapAmount);
        }

        // Unwrap ETH
        TransferHelper.safeApprove(address(weth), address(weth), mintTokenAmountIn);
        weth.withdraw(totalETHCost);

        // Mint Paints
        basePaintRewards.mintLatest{value: totalETHCost}(sendMintsTo, mintQuantity, sendRewardsTo);
    }
}
