pragma solidity >=0.5.0;

/// @title IUniswapV2Pair
/// @notice Uniswap V2 交易对接口：实现自动做市商（AMM）逻辑
interface IUniswapV2Pair {
    // ERC20 事件
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // ERC20 基本函数
    function name() external pure returns (string memory);       // 代币名称
    function symbol() external pure returns (string memory);      // 代币符号
    function decimals() external pure returns (uint8);            // 小数位数
    function totalSupply() external view returns (uint);          // 总供应量
    function balanceOf(address owner) external view returns (uint); // 地址余额
    function allowance(address owner, address spender) external view returns (uint); // 授权额度

    // ERC20 状态改变函数
    function approve(address spender, uint value) external returns (bool);                    // 授权
    function transfer(address to, uint value) external returns (bool);                        // 转账
    function transferFrom(address from, address to, uint value) external returns (bool);       // 使用授权转账

    // EIP-712 permit 相关函数
    function DOMAIN_SEPARATOR() external view returns (bytes32);                              // EIP-712 domain separator
    function PERMIT_TYPEHASH() external pure returns (bytes32);                               // permit 的类型哈希
    function nonces(address owner) external view returns (uint);                              // 每个地址的 nonce
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external; // 通过签名授权

    // Uniswap V2 特有事件
    event Mint(address indexed sender, uint amount0, uint amount1);    // 添加流动性
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to); // 移除流动性
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    ); // 代币交换
    event Sync(uint112 reserve0, uint112 reserve1); // 储备量同步

    // 视图函数
    function MINIMUM_LIQUIDITY() external pure returns (uint);                                          // 最小流动性
    function factory() external view returns (address);                                                 // 工厂合约地址
    function token0() external view returns (address);                                                  // token0 地址
    function token1() external view returns (address);                                                  // token1 地址
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast); // 获取储备量和时间戳
    function price0CumulativeLast() external view returns (uint);                                       // token0 价格累积器
    function price1CumulativeLast() external view returns (uint);                                       // token1 价格累积器
    function kLast() external view returns (uint);                                                      // 最近的 k 值

    // 核心功能函数
    function mint(address to) external returns (uint liquidity);                                                                       // 添加流动性
    function burn(address to) external returns (uint amount0, uint amount1);                                                      // 移除流动性
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;                                      // 代币交换（支持闪贷）
    function skim(address to) external;                                                                                             // 提取超出储备量的余额
    function sync() external;                                                                                                        // 强制同步储备量

    // 初始化函数（由工厂合约调用）
    function initialize(address, address) external;
}
