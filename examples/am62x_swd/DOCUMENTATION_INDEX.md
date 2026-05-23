# AM62x PRU-SWD 文档索引

## 📚 文档导航

### 🚀 快速开始
- **[QUICKSTART.md](QUICKSTART.md)** - 5分钟快速部署指南
  - 一键部署脚本使用
  - 基础硬件连接
  - 简单测试流程
  - 常见问题快速解决

### 📖 完整文档
- **[README.md](README.md)** - 项目完整技术文档
  - 项目概述和特性
  - 详细硬件连接
  - SWD 协议详解
  - 性能分析和对比
  - 高级配置和调试
  - 扩展应用（OpenOCD 集成）

- **[DUAL_PIN_DIO.md](DUAL_PIN_DIO.md)** - 双引脚 DIO 设计详解 ⭐
  - 方案对比（单引脚 vs 双引脚）
  - 硬件连接原理
  - 代码实现细节
  - 性能优势分析（~15% 提升）
  - Device Tree 配置
  - 常见问题解答

---

## 🛠️ 项目组成

### 核心代码

#### PRU 固件
- **[firmware/main.p](firmware/main.p)** (520 行)
  - 纯 PRU 汇编实现
  - 完整 SWD 协议
  - 8 个命令处理函数
  - 可配置速度（1-10 MHz）

#### Linux 测试程序
- **[linux/swd_test/swd_test.c](linux/swd_test/swd_test.c)** (387 行)
  - 交互式菜单界面
  - PRU 内存映射
  - 命令发送/结果读取
  - GPIO 和 SWD 测试

### 构建系统

- **[makefile](makefile)** (55 行)
  - 项目级构建脚本
  - 集成 OpenPRU 构建系统
  - 自动化依赖处理

- **[firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/makefile](firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/makefile)** (80 行)
  - 核心编译脚本
  - TI PRU 编译器配置
  - 生成 .out 固件文件

- **[firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/linker.cmd](firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/linker.cmd)** (66 行)
  - 内存布局定义
  - 代码段/数据段配置
  - IRAM/DRAM 映射

### 部署工具

- **[deploy_swd.sh](deploy_swd.sh)** (136 行)
  - 自动化部署脚本
  - 编译 + 上传 + 重启 PRU
  - 状态验证
  - 彩色输出和进度提示

---

## 📊 项目统计

| 类型 | 文件数 | 代码行数 |
|-----|--------|---------|
| PRU 汇编 | 1 | 520 |
| C 代码 | 1 | 387 |
| 构建脚本 | 3 | 201 |
| 部署脚本 | 1 | 136 |
| **总计** | **6** | **1244** |

项目大小: ~88 KB

---

## 🎯 使用流程

### 初次使用者
1. 阅读 [QUICKSTART.md](QUICKSTART.md)
2. 运行 `./deploy_swd.sh`
3. 连接硬件并测试

### 开发者
1. 阅读完整 [README.md](README.md)
2. 理解 SWD 协议部分
3. 研究 [firmware/main.p](firmware/main.p) 源码
4. 修改代码并重新部署

### 高级用户
1. 性能优化（调整延时）
2. OpenOCD 集成
3. 支持新的目标芯片

---

## 🔧 技术要点

### 硬件平台
- **SoC:** TI AM62x (BeaglePlay, PocketBeagle2)
- **PRU:** PRUSS0 PRU0 @ 333 MHz
- **GPIO:** 直接 R30/R31 控制
- **内存:** 16KB IRAM, 8KB DRAM

### 软件架构
- **固件:** 纯汇编，无 C 运行时
- **通信:** 共享内存 (PRU DRAM)
- **接口:** 8 个命令处理函数
- **协议:** 完整 SWD (读/写寄存器)

### 性能指标
- **默认速度:** 3.3 MHz
- **最高速度:** 10 MHz
- **时序精度:** 纳秒级（3ns/cycle）
- **代码效率:** 仅占 16% IRAM

---

## 📝 相关文档

### OpenPRU 文档
- [OPENPRU_ARCHITECTURE.md](../../OPENPRU_ARCHITECTURE.md) - OpenPRU 构建系统详解
- [OPENPRU_QUICK_REFERENCE.md](../../OPENPRU_QUICK_REFERENCE.md) - 快速参考

### 示例项目
- [rpmsg_counter](../rpmsg_counter/) - RPMsg 通信示例
- [empty_c](../empty_c/) - C 语言空模板
- [empty](../empty/) - 汇编空模板

---

## 🌟 项目亮点

### 性能优势
- ✅ **高速:** 3.3-10 MHz SWD 时钟
- ✅ **精确:** 纳秒级时序控制
- ✅ **稳定:** 直接 GPIO 访问，无延迟

### 开发友好
- ✅ **开源:** 完全可定制
- ✅ **教育:** 学习 PRU 和 SWD 的绝佳案例
- ✅ **文档:** 中文详细文档
- ✅ **工具:** 自动化部署脚本

### 应用场景
- 🎯 ARM Cortex-M 调试
- 🎯 Flash 编程
- 🎯 嵌入式开发工具
- 🎯 教学和研究

---

## 🤝 贡献指南

### 测试反馈
- 在不同 ARM 芯片上测试
- 报告速度/稳定性
- 分享硬件连接经验

### 代码改进
- 优化延时算法（IEP Timer）
- 完善双向 DIO 控制
- 添加批量读写
- 支持 Flash 编程

### 文档完善
- 翻译为英文
- 添加视频教程
- 补充实际案例

---

## 📜 版本历史

- **v0.1-alpha** (2026-05-23)
  - ✨ 初始版本
  - ✅ 完整 SWD 协议实现
  - ✅ 可配置速度（1-10 MHz）
  - ✅ 交互式测试程序
  - ✅ 自动部署脚本
  - ✅ 中文文档

---

## 📞 联系方式

- **问题反馈:** GitHub Issues
- **贡献代码:** Pull Requests
- **技术讨论:** BeagleBoard 论坛

---

## 📌 快速链接

| 文档 | 说明 | 适合人群 |
|------|------|---------|
| [QUICKSTART.md](QUICKSTART.md) | 快速开始 | 所有用户 |
| [README.md](README.md) | 完整文档 | 开发者 |
| [firmware/main.p](firmware/main.p) | PRU 源码 | 高级开发者 |
| [deploy_swd.sh](deploy_swd.sh) | 部署脚本 | 所有用户 |

---

**项目状态:** 🟡 实验性 - 欢迎测试反馈

**最后更新:** 2026-05-23

🚀 开始探索 PRU-SWD 的世界吧！
