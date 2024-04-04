// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

interface IBasePaintRewards {
    function mintLatest(address sendMintsTo, uint256 count, address sendRewardsTo) external payable;
}

interface IBasePaint{
    function openEditionPrice() external view returns (uint256);
}

interface IWETH {
    function withdraw(uint256 amount) external;
}

contract BasePaintERC20Mint {
    ISwapRouter public immutable swapRouter;
    IBasePaintRewards public immutable basePaintRewards;
    IBasePaint public immutable basePaint;
    IWETH public immutable weth;

    uint24 public constant poolFee = 3000;

     constructor(ISwapRouter _swapRouter, IBasePaintRewards _basePaintRewards, IBasePaint _basePaint, IWETH _weth) {
        swapRouter = _swapRouter;
        basePaintRewards = _basePaintRewards;
        basePaint = _basePaint;
        weth = _weth;
    }

    function mintWithERC20(
        address mintToken, 
        address sendMintsTo, 
        address sendRewardsTo, 
        uint256 mintTokenAmountIn,
        uint256 mintQuantity
    ) public {
        // Calc paint cost
        uint256 ethCost = basePaint.openEditionPrice() * mintQuantity;

        // Transfer tokens in and approve router
        TransferHelper.safeTransferFrom(mintToken, msg.sender, address(this), mintTokenAmountIn);
        TransferHelper.safeApprove(mintToken, address(swapRouter), mintTokenAmountIn);

        // Swap settings
        ISwapRouter.ExactOutputSingleParams memory params =
        ISwapRouter.ExactOutputSingleParams({
            tokenIn: mintToken,
            tokenOut: address(weth),
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: ethCost,
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
        weth.withdraw(ethCost); 

        // Mint Paints
        basePaintRewards.mintLatest(sendMintsTo, mintQuantity, sendRewardsTo);
    }
}