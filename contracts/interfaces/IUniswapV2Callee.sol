pragma solidity >=0.5.0;

/// @title IUniswapV2Callee
/// @notice Uniswap V2 闪贷回调接口
/// 合约在 swap 时调用此接口的回调函数，用于实现闪贷功能
interface IUniswapV2Callee {
    /// @notice Uniswap V2 闪贷回调函数
    /// @param sender 调用 swap 的地址
    /// @param amount0 借出的 token0 数量
    /// @param amount1 借出的 token1 数量
    /// @param data 回调数据
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
