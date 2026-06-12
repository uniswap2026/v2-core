pragma solidity =0.5.16;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

/// @title SafeMath
/// @notice 防溢出的安全数学运算库，Solidity 0.5.x 需要手动使用
library SafeMath {
    /// @notice 安全加法：防止溢出
    /// @param x 被加数
    /// @param y 加数
    /// @return z 和
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    /// @notice 安全减法：防止下溢
    /// @param x 被减数
    /// @param y 减数
    /// @return z 差
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    /// @notice 安全乘法：防止溢出
    /// @param x 被乘数
    /// @param y 乘数
    /// @return z 积
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}
