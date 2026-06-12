pragma solidity =0.5.16;

import './interfaces/IUniswapV2ERC20.sol';
import './libraries/SafeMath.sol';

/// @title UniswapV2ERC20
/// @notice Uniswap V2 配对的 ERC20 代币实现，支持 EIP-712 permit 功能
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint;

    // 代币基本信息
    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';
    uint8 public constant decimals = 18;
    uint  public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    // EIP-712 domain separator，用于 permit 签名验证
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    // 事件定义
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    /// @notice 构造函数，初始化 EIP-712 domain separator
    constructor() public {
        uint chainId;
        assembly {
            chainId := chainid
        }
        // 构造 EIP-712 domain separator，用于 permit 签名验证
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /// @notice 内部函数：铸造代币
    /// @param to 接收代币的地址
    /// @param value 铸造的代币数量
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /// @notice 内部函数：销毁代币
    /// @param from 销毁代币的地址
    /// @param value 销毁的代币数量
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /// @notice 内部函数：设置授权额度
    /// @param owner 所有者地址
    /// @param spender 被授权地址
    /// @param value 授权额度
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /// @notice 内部函数：执行代币转账
    /// @param from 发送方地址
    /// @param to 接收方地址
    /// @param value 转账数量
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /// @notice 授权指定地址使用代币
    /// @param spender 被授权地址
    /// @param value 授权额度
    /// @return 是否授权成功
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /// @notice 转账代币
    /// @param to 接收方地址
    /// @param value 转账数量
    /// @return 是否转账成功
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @notice 使用授权额度进行转账
    /// @param from 发送方地址
    /// @param to 接收方地址
    /// @param value 转账数量
    /// @return 是否转账成功
    function transferFrom(address from, address to, uint value) external returns (bool) {
        // 如果不是无限授权（uint(-1)），则扣除授权额度
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /// @notice 通过签名授权代币使用（EIP-712 permit），无需事先 approve
    /// @param owner 所有者地址
    /// @param spender 被授权地址
    /// @param value 授权额度
    /// @param deadline 授权截止时间戳
    /// @param v 签名的 v 值
    /// @param r 签名的 r 值
    /// @param s 签名的 s 值
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        // 构造签名摘要
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        // 恢复签名地址并验证
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}
