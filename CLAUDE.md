# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Uniswap V2 Core 是一个去中心化交易协议的核心智能合约仓库。这是一个仅包含核心合约的仓库，不包含前端或外设合约。

## Common Commands

```bash
# 安装依赖
yarn

# 编译合约（会先清理 build 目录）
yarn compile

# 运行所有测试（会先编译）
yarn test

# 检查测试文件的 lint
yarn lint

# 自动修复 lint 问题
yarn lint:fix

# 清理构建目录
yarn clean

# 运行单个测试文件
npx mocha test/UniswapV2Factory.spec.ts
npx mocha test/UniswapV2Pair.spec.ts
```

## Architecture

### 核心合约结构

合约分为三层架构：

1. **Factory Layer** - `UniswapV2Factory`
   - 使用 CREATE2 opcode 部署 Pair 合约
   - 配对地址可预测：`CREATE2(0xff, factory, keccak256(token0, token1), keccak256(bytecode))`
   - 管理所有交易对
   - 处理手续费分配（feeTo 机制）

2. **Pair Layer** - `UniswapV2Pair`
   - 继承自 `UniswapV2ERC20`，代表流动性池代币
   - 每个交易对是一个独立合约
   - 关键操作：mint（添加流动性）、burn（移除流动性）、swap（交易）
   - 使用 reentrancy guard (lock modifier)
   - 使用 TWAP (Time Weighted Average Price) 通过价格累积计算价格

3. **Utility Libraries**
   - `Math` - 提供 min 和 sqrt 函数（Babylonian method）
   - `SafeMath` - 安全数学运算（Solidity 0.5.x 需要手动使用）
   - `UQ112x112` - 处理 Q112 格式的固定点数，用于价格计算

### 关键设计模式

- **Two-Token Sorted**: 配对中的 token0/token1 按地址排序，确保唯一性
- **CREATE2 Deployment**: 配对地址确定性地从 token 地址和合约字节码派生
- **Reserve Tracking**: 使用单个存储槽存储两个储备量（reserve0, reserve1）和时间戳以优化 gas
- **Price Accumulators**: 每个区块累积价格，用于外部计算 TWAP
- **Permit (EIP-712)**: 支持链下签名授权，无需事先 approve

### 测试结构

- `test/UniswapV2Factory.spec.ts` - 测试工厂合约
- `test/UniswapV2Pair.spec.ts` - 测试配对合约（最全面）
- `test/UniswapV2ERC20.spec.ts` - 测试 ERC20 功能
- `test/shared/fixtures.ts` - 测试夹具（factoryFixture, pairFixture）
- `test/shared/utilities.ts` - 共享工具函数（expandTo18Decimals, encodePrice, getCreate2Address）

测试使用 `ethereum-waffle` 的 `createFixtureLoader` 来快速设置测试环境，每个测试用例会重新部署合约以保持隔离。

## Important Constraints

- Solidity 版本：0.5.16
- EVM 版本：Istanbul
- 优化设置：启用，runs=999999（用于重复调用）
- Node 版本：>=10
- 固定 gasLimit：9999999（在测试中）

## Key Constants

- `MINIMUM_LIQUIDITY = 10**3` - 永久锁定的最小流动性，防止迁移攻击
- 所有精度为 18 位小数

## Code Style

- 使用 prettier 格式化测试文件（single quotes, no semicolons, 120 chars width）
- Solidity 代码不使用 prettier（遵循手动格式化）
- 使用 SafeMath 进行所有数学运算
- 使用 `abi.encodePacked` 和 `keccak256` 进行哈希计算