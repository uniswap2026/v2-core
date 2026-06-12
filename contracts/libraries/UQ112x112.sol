pragma solidity =0.5.16;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112

/// @title UQ112x112
/// @notice 处理 Q112 格式的二进制定点数（无符号 224 位，小数点在 112 位后）
/// 用于价格计算，避免精度损失
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112
    /// @notice 将 uint112 编码为 UQ112x112 格式（左移 112 位）
    /// @param y 待编码的整数
    /// @return z 编码后的 UQ112x112 值
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    /// @notice 将 UQ112x112 除以 uint112，结果仍为 UQ112x112 格式
    /// @param x 被除数（UQ112x112 格式）
    /// @param y 除数（uint112 格式）
    /// @return z 商（UQ112x112 格式）
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
