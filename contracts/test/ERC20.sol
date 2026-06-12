pragma solidity =0.5.16;

import '../UniswapV2ERC20.sol';

/// @title ERC20
/// @notice 测试用的 ERC20 代币，继承自 UniswapV2ERC20
/// 在测试中部署时直接铸造指定数量的代币给部署者
contract ERC20 is UniswapV2ERC20 {
    /// @notice 构造函数：铸造指定数量的代币给部署者
    /// @param _totalSupply 初始总供应量
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
