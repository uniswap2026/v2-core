pragma solidity >=0.5.0;

/// @title IUniswapV2Factory
/// @notice Uniswap V2 工厂合约接口：负责创建和管理交易对
interface IUniswapV2Factory {
    // 事件定义
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 视图函数
    function feeTo() external view returns (address);                // 手续费接收地址
    function feeToSetter() external view returns (address);          // 可设置手续费接收地址的权限地址
    function getPair(address tokenA, address tokenB) external view returns (address pair); // 获取交易对地址
    function allPairs(uint) external view returns (address pair);    // 获取指定索引的交易对地址
    function allPairsLength() external view returns (uint);          // 获取交易对总数

    // 状态改变函数
    function createPair(address tokenA, address tokenB) external returns (address pair);  // 创建新交易对
    function setFeeTo(address) external;                           // 设置手续费接收地址
    function setFeeToSetter(address) external;                      // 设置手续费设置者地址
}
