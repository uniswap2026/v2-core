pragma solidity >=0.5.0;

/// @title IUniswapV2ERC20
/// @notice Uniswap V2 的 ERC20 接口，包含 permit 功能（EIP-712 签名授权）
interface IUniswapV2ERC20 {
    // 事件定义
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

    /// @notice 通过签名授权代币使用（EIP-712 permit），无需事先 approve
    /// @param owner 所有者地址
    /// @param spender 被授权地址
    /// @param value 授权额度
    /// @param deadline 授权截止时间戳
    /// @param v 签名的 v 值
    /// @param r 签名的 r 值
    /// @param s 签名的 s 值
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}
