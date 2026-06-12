pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

/// @title UniswapV2Factory
/// @notice Uniswap V2 的工厂合约：负责创建和管理交易对
contract UniswapV2Factory is IUniswapV2Factory {
    // 手续费接收地址（为零时表示不收取手续费）
    address public feeTo;
    // 可设置手续费接收地址的权限地址
    address public feeToSetter;

    // 映射：返回两个代币的交易对地址
    mapping(address => mapping(address => address)) public getPair;
    // 所有交易对地址列表
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /// @notice 构造函数：初始化手续费设置者
    /// @param _feeToSetter 手续费设置者地址
    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    /// @notice 获取交易对总数
    /// @return 交易对数量
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /// @notice 创建新的交易对
    /// @param tokenA 第一个代币地址
    /// @param tokenB 第二个代币地址
    /// @return pair 新创建的交易对地址
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 两个代币地址不能相同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // 对代币地址进行排序，确保 token0 < token1
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // 不能使用零地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        // 交易对不能已存在
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        // 使用 CREATE2 部署交易对合约
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // 初始化交易对
        IUniswapV2Pair(pair).initialize(token0, token1);
        // 在映射中记录交易对地址（双向记录）
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /// @notice 设置手续费接收地址（仅 feeToSetter 可调用）
    /// @param _feeTo 新的手续费接收地址
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /// @notice 设置手续费设置者地址（仅当前 feeToSetter 可调用）
    /// @param _feeToSetter 新的手续费设置者地址
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
