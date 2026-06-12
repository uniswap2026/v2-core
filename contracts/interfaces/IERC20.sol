pragma solidity >=0.5.0;

/// @title IERC20
/// @notice 标准 ERC20 代币接口
interface IERC20 {
    // 事件定义
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    // 视图函数
    function name() external view returns (string memory);       // 代币名称
    function symbol() external view returns (string memory);      // 代币符号
    function decimals() external view returns (uint8);            // 小数位数
    function totalSupply() external view returns (uint);          // 总供应量
    function balanceOf(address owner) external view returns (uint); // 地址余额
    function allowance(address owner, address spender) external view returns (uint); // 授权额度

    // 状态改变函数
    function approve(address spender, uint value) external returns (bool);                    // 授权
    function transfer(address to, uint value) external returns (bool);                        // 转账
    function transferFrom(address from, address to, uint value) external returns (bool);       // 使用授权转账
}
