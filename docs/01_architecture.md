# Uniswap V2 Core 架构文档

## 主入口点

本仓库有两个用户可交互的合约入口，职责截然不同：

| 入口       | 合约               | 部署数量        | 职责                            |
| ---------- | ------------------ | --------------- | ------------------------------- |
| 工厂入口   | `UniswapV2Factory` | 全局 1 个       | 创建交易对、管理手续费开关      |
| 交易对入口 | `UniswapV2Pair`    | 每个代币对 1 个 | 添加/移除流动性、代币交换、闪贷 |

**调用链路**：外部用户 → Router 合约（不在本仓库）→ `UniswapV2Pair`。工厂只在创建交易对时被调用一次。

---

## 部署

| 网络    | Factory 合约                                 | Router02 合约                                |
| ------- | -------------------------------------------- | -------------------------------------------- |
| Mainnet | `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f` | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Sepolia | `0xF62c03E08ada871A0bEb309762E260a7a6a880E6` | `0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3` |

---

## 功能分层（由浅入深）

### 第一层：基础工具库

`contracts/libraries/` 下的三个库无状态、无存储，被上层合约 `using` 引入后使用。

#### SafeMath — 防溢出算术

Solidity 0.5.x 不内置溢出检查，所有 `uint` 运算必须手动保护。SafeMath 提供三个运算：

```
add(x, y) → 要求 z = x+y >= x        // 加法溢出检查
sub(x, y) → 要求 z = x-y <= x        // 减法下溢检查
mul(x, y) → 要求 y==0 或 (x*y)/y==x  // 乘法溢出检查
```

被 `UniswapV2ERC20` 和 `UniswapV2Pair` 通过 `using SafeMath for uint` 使用，覆盖所有算术运算。

#### Math — min 与 sqrt

- `min(x, y)`：取较小值。用于 mint 时按比例计算流动性，取两种代币各自算出的流动性较小值。
- `sqrt(y)`：Babylonian 迭代法求平方根（向下取整）。用于：
  - 首次 mint 计算初始流动性：`√(amount0 × amount1) - MINIMUM_LIQUIDITY`
  - `_mintFee` 计算 √k 和 √k_last 以衡量增长

#### UQ112x112 — 定点数编解码

Q 格式定点数，将 uint112 整数编码为 224 位定点数（112 位整数 + 112 位小数）：

- `encode(y)`：`uint112 → uint224`，左移 112 位（×2¹¹²）
- `uqdiv(x, y)`：`UQ112x112 ÷ uint112 → UQ112x112`

**用途**：在 `_update` 中计算价格比率。reserve 值为 uint112，通过 encode 后 uqdiv 得到高精度定点价格，再乘以时间差累加到 `price0CumulativeLast` / `price1CumulativeLast`。

---

### 第二层：ERC20 代币基座

#### IERC20 — 标准接口

`contracts/interfaces/IERC20.sol`，定义标准 ERC20 的 6 个视图函数 + 3 个状态改变函数 + 2 个事件。被 `UniswapV2Pair` 用于查询代币余额（`balanceOf`）和执行代币转账。

#### UniswapV2ERC20 — LP Token 实现

`contracts/UniswapV2ERC20.sol`，流动性提供者凭证（LP Token）的完整实现。

**状态变量**：

| 变量               | 类型                                   | 说明                         |
| ------------------ | -------------------------------------- | ---------------------------- |
| `totalSupply`      | uint                                   | LP Token 总供应量            |
| `balanceOf`        | mapping(address→uint)                  | LP Token 余额                |
| `allowance`        | mapping(address→mapping(address→uint)) | 授权额度                     |
| `DOMAIN_SEPARATOR` | bytes32                                | EIP-712 域分隔符，构造时计算 |
| `PERMIT_TYPEHASH`  | bytes32 constant                       | permit 结构体哈希            |
| `nonces`           | mapping(address→uint)                  | 签名防重放计数器             |

**关键函数**：

| 函数                                               | 可见性   | 说明                                              |
| -------------------------------------------------- | -------- | ------------------------------------------------- |
| `_mint(to, value)`                                 | internal | 铸造 LP Token，供 Pair 的 mint/burn/_mintFee 调用 |
| `_burn(from, value)`                               | internal | 销毁 LP Token，供 Pair 的 burn 调用               |
| `permit(owner, spender, value, deadline, v, r, s)` | external | EIP-712 链下签名授权，免去 on-chain approve 交易  |

**permit 流程**：
1. 验证 `deadline >= block.timestamp`
2. 用 `DOMAIN_SEPARATOR` + `PERMIT_TYPEHASH` + 参数 + nonce 构造 EIP-712 digest
3. `ecrecover` 恢复签名者地址，验证与 `owner` 一致
4. 调用 `_approve` 完成授权

**特殊设计**：`transferFrom` 中若 `allowance == uint(-1)`（即 type(uint256).max）则跳过扣减，允许 Router 合约无限授权后零 gas 扣减。

---

### 第三层：交易对核心（UniswapV2Pair）

`contracts/UniswapV2Pair.sol`，继承 `UniswapV2ERC20`，是整个协议最核心的合约。每个代币对部署一个独立实例。

#### 状态变量与存储布局

```
┌─────────────────────────────────────────────────────────┐
│ 存储槽 0-4: 继承自 UniswapV2ERC20                        │
│   totalSupply, balanceOf, allowance, DOMAIN_SEPARATOR, nonces │
├─────────────────────────────────────────────────────────┤
│ 存储槽 5:  MINIMUM_LIQUIDITY (constant, 不占槽)           │
│ 存储槽 5:  SELECTOR (constant, 不占槽)                    │
│ 存储槽 5:  factory        (address)                      │
│ 存储槽 6:  token0          (address)                      │
│ 存储槽 7:  token1          (address)                      │
├─────────────────────────────────────────────────────────┤
│ 存储槽 8:  reserve0 (112) | reserve1 (112) | blockTimestampLast (32)  ← 单槽打包 │
├─────────────────────────────────────────────────────────┤
│ 存储槽 9:  price0CumulativeLast                          │
│ 存储槽 10: price1CumulativeLast                          │
│ 存储槽 11: kLast                                         │
│ 存储槽 12: unlocked (重入锁)                              │
└─────────────────────────────────────────────────────────┘
```

**存储槽打包**：`reserve0` + `reserve1` + `blockTimestampLast` 共 112+112+32=256 位，打包进一个存储槽，读写只需一次 SLOAD/SSTORE，节省 gas。

#### 重入保护（lock modifier）

```solidity
uint private unlocked = 1;
modifier lock() {
    require(unlocked == 1, 'UniswapV2: LOCKED');
    unlocked = 0;
    _;
    unlocked = 1;
}
```

所有 5 个外部状态改变函数（mint、burn、swap、skim、sync）均使用 `lock`。因为在 swap 中有外部调用（`_safeTransfer` 和 `IUniswapV2Callee.uniswapV2Call`），必须防止重入。

#### 构造与初始化

```
部署者: UniswapV2Factory.createPair()
  │
  ├─ CREATE2 部署 UniswapV2Pair  → constructor() 记录 factory = msg.sender
  │
  └─ 调用 pair.initialize(token0, token1)
       └─ 记录 token0 和 token1（仅可调用一次，仅 factory 可调用）
```

两阶段初始化是 CREATE2 的标准模式：构造函数中 `msg.sender` 是工厂，`initialize` 设置代币地址。

#### _update — 储备量与价格累积器更新

```
输入: balance0, balance1 (合约实际持有的代币余额)
      _reserve0, _reserve1 (上一次记录的储备量)
```

**执行逻辑**：
1. 检查余额不超过 uint112 上限
2. 计算距上次更新的时间差 `timeElapsed`
3. 若 `timeElapsed > 0` 且储备量非零，更新价格累积器：
   - `price0CumulativeLast += (reserve1/reserve0 在 UQ112x112 中的编码) × timeElapsed`
   - `price1CumulativeLast += (reserve0/reserve1 在 UQ112x112 中的编码) × timeElapsed`
4. 写入新储备量和时间戳
5. 触发 `Sync` 事件

**TWAP 用法**：外部合约在两个时间点 T1、T2 读取 `price0CumulativeLast`，则：
```
TWAP = (price0CumulativeLast[T2] - price0CumulativeLast[T1]) / (T2 - T1)
```
结果为 UQ112x112 格式，右移 112 位得到实际价格比。

#### _mintFee — 协议手续费铸造

**触发时机**：每次 mint 或 burn 的开头调用。

**核心逻辑**：

```
若 feeTo != address(0)（手续费开启）:
  若 kLast != 0:
    rootK     = √(reserve0 × reserve1)    // 当前 k 的平方根
    rootKLast = √(kLast)                  // 上次记录的 k 的平方根
    若 rootK > rootKLast（k 增长了，说明有手续费累积）:
      liquidity = totalSupply × (rootK - rootKLast) / (5 × rootK + rootKLast)
      _mint(feeTo, liquidity)             // 铸造给手续费接收方
若 feeTo == address(0) 且 kLast != 0:
  kLast = 0                               // 关闭手续费时清零
```

**1/6 的数学含义**：0.3% 手续费中，5/6 归 LP，1/6 归协议。公式的推导：

```
设手续费导致 k 从 k_last 增长到 k，增长率为 g = √k/√k_last - 1
手续费份额 = 1/6 的增长 → 铸造量 = totalSupply × g / (6 + 5g)
代入展开后等价于 totalSupply × (√k - √k_last) / (5√k + √k_last)
```

**注意**：铸造新的 LP Token 会稀释现有持有者，如果根据公式 `totalSupply × g / 6` 计算铸造量，会让协议获得超过 1/6 的增长价值。

#### mint — 添加流动性

**前置条件**：调用者已将代币转入 Pair 合约（先转账后调用）。

```
执行流程:
1. 读取当前储备量 _reserve0, _reserve1
2. 查询合约实际余额 balance0, balance1
3. amount0 = balance0 - _reserve0   // 新存入的 token0 数量
   amount1 = balance1 - _reserve1   // 新存入的 token1 数量
4. _mintFee() 处理待分配手续费
5. 计算流动性:
   若 totalSupply == 0 (首次):
     liquidity = √(amount0 × amount1) - MINIMUM_LIQUIDITY
     _mint(address(0), MINIMUM_LIQUIDITY)   // 永久锁定
   否则:
     liquidity = min(amount0 × totalSupply / _reserve0,
                     amount1 × totalSupply / _reserve1)
6. _mint(to, liquidity)
7. _update(balance0, balance1, ...)
8. 若 feeOn: kLast = reserve0 × reserve1
```

**MINIMUM_LIQUIDITY 的意义**：首次添加流动性时，1000 wei 的 LP Token 铸造给 `address(0)` 永久锁定。这使得攻击者无法通过销毁全部流动性后将储备量清零来放大自身份额（即"流动性迁移攻击"）。

#### burn — 移除流动性

**前置条件**：调用者已将 LP Token 转入 Pair 合约。

```
执行流程:
1. 读取储备量和实际余额
2. liquidity = balanceOf[address(this)]  // 合约持有的 LP Token 数量
3. _mintFee() 处理待分配手续费
4. 按比例计算取回数量:
   amount0 = liquidity × balance0 / totalSupply
   amount1 = liquidity × balance1 / totalSupply
5. _burn(address(this), liquidity)
6. _safeTransfer(token0, to, amount0)
   _safeTransfer(token1, to, amount1)
7. 重新查询余额 → _update()
8. 若 feeOn: kLast = reserve0 × reserve1
```

**注意**：使用 `balance`（实际余额）而非 `reserve`（记录值）做除法。这是因为 `balance` 已包含累积的手续费收入，确保 LP 按实际持有量比例取回。

#### swap — 代币交换（含闪贷）

**前置条件**：调用者已将输入代币转入 Pair 合约（先转账后调用），或通过 data 参数触发闪贷。

```
执行流程:
1. 验证至少一种输出 > 0，输出不超过储备量
2. 乐观转账:
   if amount0Out > 0: _safeTransfer(token0, to, amount0Out)
   if amount1Out > 0: _safeTransfer(token1, to, amount1Out)
3. 闪贷回调（可选）:
   if data.length > 0: IUniswapV2Callee(to).uniswapV2Call(...)
4. 查询实际余额 balance0, balance1
5. 计算实际输入:
   amount0In = max(0, balance0 - (_reserve0 - amount0Out))
   amount1In = max(0, balance1 - (_reserve1 - amount1Out))
6. 验证至少一种输入 > 0
7. 恒定乘积验证（含 0.3% 手续费）:
   balance0Adjusted = balance0 × 1000 - amount0In × 3
   balance1Adjusted = balance1 × 1000 - amount1In × 3
   要求 balance0Adjusted × balance1Adjusted >= reserve0 × reserve1 × 1000²
8. _update(balance0, balance1, ...)
```

**恒定乘积公式推导**：

无手续费时：`(reserve0 + Δin)(reserve1 - Δout) = reserve0 × reserve1`

有 0.3% 手续费时，仅 (1-0.3%) 的输入参与乘积：
```
(reserve0 + 0.997 × Δin)(reserve1 - Δout) >= reserve0 × reserve1
```

代码中为了避免小数，乘以 1000：
```
(1000 × (reserve0 + Δin) - 3 × Δin)(1000 × (reserve1 - Δout) - 3 × Δout)
= (1000 × balance0 - 3 × amountIn)(1000 × balance1 - 3 × amountIn)
>= 1000² × reserve0 × reserve1
```

**闪贷机制**：`data.length > 0` 时触发回调。接收合约实现 `IUniswapV2Callee.uniswapV2Call`，在回调中可使用已转出的代币执行任意操作（如套利），但回调返回前必须将等值代币+手续费转回 Pair，否则第 7 步的恒定乘积检查会失败导致回滚。

#### skim 与 sync — 应急修复函数

| 函数       | 作用                               | 场景                                                        |
| ---------- | ---------------------------------- | ----------------------------------------------------------- |
| `skim(to)` | 将 balance - reserve 的差额转给 to | 有人直接向 Pair 转账导致 balance > reserve 时，提取多余部分 |
| `sync()`   | 将 reserve 强制更新为当前 balance  | 有人直接向 Pair 转账导致 reserve 失真时，重新同步           |

两者配套使用：`skim` 修余额，`sync` 修储备量。在代币通缩（transfer 时扣税）的场景下，`sync` 尤其重要。

#### _safeTransfer — 安全代币转账

```solidity
function _safeTransfer(address token, address to, uint value) private {
    (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
}
```

使用底层 `call` 而非 `IERC20(token).transfer`，原因：
1. 处理不标准 ERC20（无返回值的代币如 USDT），`data.length == 0` 视为成功
2. 避免返回 false 但不 revert 的代币导致静默失败

---

### 第四层：工厂管理层（UniswapV2Factory）

`contracts/UniswapV2Factory.sol`，全局单例，负责交易对的生命周期管理和手续费开关。

#### 状态变量

| 变量          | 说明                                                            |
| ------------- | --------------------------------------------------------------- |
| `feeTo`       | 手续费接收地址。`address(0)` = 关闭，非零 = 开启                |
| `feeToSetter` | 有权设置 feeTo 和转移权限的地址                                 |
| `getPair`     | `mapping(address → mapping(address → address))`，双向查找交易对 |
| `allPairs`    | `address[]`，所有交易对的有序列表                               |

#### createPair — 创建交易对

```
执行流程:
1. tokenA != tokenB（不能与自己配对）
2. 排序: token0 = min(tokenA, tokenB), token1 = max(tokenA, tokenB)
3. token0 != address(0)
4. getPair[token0][token1] == address(0)（不能重复创建）
5. CREATE2 部署:
   salt = keccak256(abi.encodePacked(token0, token1))
   pair = create2(0, bytecode, salt)
6. pair.initialize(token0, token1)
7. 双向映射: getPair[token0][token1] = getPair[token1][token0] = pair
8. allPairs.push(pair)
9. emit PairCreated
```

**CREATE2 地址确定性**：给定 factory 地址、token0、token1 和 Pair 合约字节码，可以链下预计算交易对地址：
```
pair = keccak256(0xff ++ factory ++ salt ++ keccak256(bytecode))[12:]
```

**排序的意义**：无论用户传入 (A, B) 还是 (B, A)，始终得到同一个交易对地址。单向检查 `getPair[token0][token1]` 足以防止重复（因为 token0 < token1 是确定的）。

#### setFeeTo / setFeeToSetter — 手续费治理

- `setFeeTo`：切换手续费开关。设为非零地址即开启，设为 `address(0)` 即关闭。
- `setFeeToSetter`：转移治理权限。采用"钥匙传递"模式，原持有者指定新持有者。

---

## 合约依赖关系

```
IUniswapV2Factory  IUniswapV2Pair  IUniswapV2ERC20  IERC20  IUniswapV2Callee
       │                │               │              │           │
       ▼                ▼               ▼              │           │
UniswapV2Factory  UniswapV2Pair ──→ UniswapV2ERC20 ◄──┘           │
       │                │               │                            │
       │                ├── Math ◄──────┤                            │
       │                ├── UQ112x112 ◄─┤                            │
       │                └── SafeMath ◄──┘                            │
       │                    ▲                                      │
       └── CREATE2 部署 ────┘                                      │
                     │                                            │
                     └──────── IUniswapV2Callee（闪贷回调）──────────┘
```

- `UniswapV2Pair` 继承 `UniswapV2ERC20`，使用 Math / SafeMath / UQ112x112
- `UniswapV2Factory` 通过 CREATE2 部署 `UniswapV2Pair`，然后调用 `initialize`
- `UniswapV2Pair` 通过 `IUniswapV2Factory(factory).feeTo()` 读取手续费配置
- `UniswapV2Pair` 通过 `IERC20(token).balanceOf()` 查询代币余额
- `UniswapV2Pair.swap` 通过 `IUniswapV2Callee(to).uniswapV2Call` 实现闪贷回调

---

## 使用场景

### 场景 1：流动性提供

用户向交易对存入两种代币，获得 LP Token，分享交易手续费收益。

```
1. token0.approve(pair, amount0)
2. token1.approve(pair, amount1)
3. token0.transfer(pair, amount0)     // 先将代币转入 Pair
4. token1.transfer(pair, amount1)
5. pair.mint(user)                    // 铸造 LP Token

// 取回时:
6. pair.transfer(pair, liquidity)     // 将 LP Token 转入 Pair
7. pair.burn(user)                    // 销毁 LP Token，取回代币
```

实际中步骤 1-5 由 Router 合约（`addLiquidity`）原子化执行。

### 场景 2：代币交换

用户用一种代币交换另一种代币，价格由恒定乘积公式决定。

```
1. tokenIn.approve(pair, amountIn)
2. tokenIn.transfer(pair, amountIn)   // 先将输入代币转入 Pair
3. pair.swap(0, amountOut, user, "")  // 指定输出数量
```

实际中由 Router 合约（`swapExactTokensForTokens` 等）计算输出量并原子化执行。

### 场景 3：价格预言机

外部合约利用 `price0CumulativeLast` 计算时间加权平均价格（TWAP），抗操纵性远强于瞬时价格。

```
// 在 T1 时刻记录
(uint112 r0, uint112 r1, uint32 ts1) = pair.getReserves();
uint pc1 = pair.price0CumulativeLast();

// 在 T2 时刻记录
uint pc2 = pair.price0CumulativeLast();
(uint112,,uint32 ts2) = pair.getReserves();

// 计算 TWAP
uint twapUQ = (pc2 - pc1) / (ts2 - ts1);
uint twap = twapUQ >> 112;  // UQ112x112 → 整数部分
```

攻击者要在多区块内操纵 TWAP，需在每个区块末尾持有足够头寸维持偏价，成本随观测窗口指数增长。

### 场景 4：闪贷

无抵押借贷，借款和还款在同一交易内完成。若未归还，恒定乘积检查失败，整笔交易回滚。

```
1. 攻击合约调用 pair.swap(amountOut, 0, 攻击合约, callbackData)
2. Pair 乐观转出代币 → 调用 IUniswapV2Callee(攻击合约).uniswapV2Call(...)
3. 攻击合约在回调中执行套利操作
4. 攻击合约将借入代币 + 手续费转回 Pair
5. Pair 检查恒定乘积 → 通过则交易成功
```

### 场景 5：协议手续费

协议方通过 Factory 开启手续费开关，0.3% 交易费中的 1/6 归协议。

```
factory.setFeeTo(protocolTreasury)   // 开启
// 此后每次 mint/burn 时，_mintFee 自动计算并铸造 LP Token 给 protocolTreasury
factory.setFeeTo(address(0))         // 关闭
```

---

## 关键设计决策总结

| 决策                         | 原因                                                                       |
| ---------------------------- | -------------------------------------------------------------------------- |
| 先转账后调用（push vs pull） | Pair 不主动拉取代币，调用者需先转入，Pair 只查余额差值                     |
| CREATE2 部署                 | 交易对地址可链下预计算，无需查询 Factory                                   |
| token 排序                   | 消除 (A,B) 与 (B,A) 的歧义，单次映射查找足够                               |
| reserve 三变量打包           | 112+112+32=256 位，单次 SLOAD/SSTORE，省 gas                               |
| 乐观转账 + 后置检查          | swap 先转出再验证，支持闪贷回调，减少交易次数                              |
| uint112 储备量               | 留足位数给价格累积器（UQ112x112 编码后 uint224 × uint32 不会溢出 uint256） |
| MINIMUM_LIQUIDITY 锁定       | 防止流动性迁移攻击：攻击者无法清空池子后重建以 100% 占有份额               |
| _safeTransfer 底层 call      | 兼容不标准 ERC20（如 USDT 无返回值）                                       |
| 无 owner/admin               | Factory 仅有 feeToSetter 单一权限，无暂停、无升级，最大去中心化            |
