pragma solidity =0.5.16;

// a library for performing various math operations

/// @title Math
/// @notice 数学运算库：提供最小值和平方根计算
library Math {
    /// @notice 返回两个数中的较小值
    /// @param x 第一个数
    /// @param y 第二个数
    /// @return z 较小的数
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    /// @notice 计算平方根（使用巴比伦方法）
    /// @param y 待开方的数
    /// @return z 平方根值（向下取整）
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            // 迭代逼近：x_n+1 = (y/x_n + x_n) / 2
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
