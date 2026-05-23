# OpenPRU 文档索引

本目录包含 OpenPRU (AM62X/PocketBeagle2) 开发的完整文档集合。

---

## 📚 文档列表

### 1. 🚀 快速入门

**[RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md)** - RPMsg 通信测试总结
- ✅ 实际执行的完整步骤记录
- ✅ 从配置到测试的完整流程
- ✅ 包含所有实际使用的命令
- ✅ 测试结果验证

**适用场景**: 
- 第一次使用 OpenPRU
- 需要验证环境配置
- 学习 RPMsg 通信

---

### 2. 📖 完整操作指南

**[AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md)** - AM62X PRU RPMsg 完整操作指南
- 详细的分步指南（7 个主要步骤）
- 每个步骤的详细解释
- 故障排查方法
- 技术细节说明
- 快速参考命令

**章节内容**:
1. 配置 imports.mak
2. 编译 RPMsg Echo 固件
3. 部署固件到目标设备
4. 加载和启动 PRU
5. 验证 RPMsg 设备
6. 创建测试脚本
7. 执行测试
8. 故障排查

**适用场景**:
- 需要详细理解每个步骤
- 遇到问题需要排查
- 作为参考手册使用

---

### 3. 🏗️ 架构深度解析

**[OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)** - OpenPRU 架构与编译流程详解
- OpenPRU 仓库组织结构
- 三层 Makefile 构建系统架构
- 完整编译流程详解（5 个阶段）
- 固件生成过程
- 内存布局与链接机制
- 多设备支持机制
- 实例分析（rpmsg_echo_linux 完整编译过程）

**章节内容**:
1. OpenPRU 概述
2. 仓库组织结构
3. 构建系统架构
4. 编译流程详解
5. 固件生成过程
6. 内存布局与链接
7. 多设备支持机制
8. 实例分析

**适用场景**:
- 深入理解 OpenPRU 构建系统
- 修改或扩展构建流程
- 开发新的项目模板
- 调试编译或链接问题

---

### 4. ⚡ 快速参考手册

**[OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md)** - OpenPRU 快速参考手册
- 目录结构速查
- 编译流程一览图
- imports.mak 配置速查
- 编译命令速查
- 生成文件说明
- 内存布局速查表
- 部署固件命令
- 常见问题排查
- 编译器标志参考
- 快速开始检查清单

**适用场景**:
- 快速查找命令或参数
- 作为速查表使用
- 了解关键配置选项

---

### 5. 🎯 其他专题文档

**[GPIO_1kHz_README.md](examples/empty/GPIO_1kHz_README.md)** - GPIO 翻转测试指南
- 1kHz GPIO 翻转程序
- 引脚配置说明
- 频率调整方法

---

## 🛠️ 工具脚本

### [deploy_rpmsg.sh](deploy_rpmsg.sh) - 自动部署脚本
一键完成编译、部署、启动和测试的自动化脚本。

**功能**:
- ✅ 自动编译 PRU 固件
- ✅ 自动上传到目标设备
- ✅ 自动停止并启动 PRU
- ✅ 自动运行完整测试
- ✅ 带颜色的状态输出
- ✅ 错误检测和处理

**使用方法**:
```bash
cd /path/to/open-pru
./deploy_rpmsg.sh
```

---

## 📋 推荐阅读顺序

### 初学者路径

1. **[RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md)** 
   - 快速了解整个流程
   - 看实际执行的命令
   
2. **[AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md)**
   - 详细学习每个步骤
   - 理解配置和部署
   
3. **[OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md)**
   - 作为日常参考手册
   - 快速查找命令

4. **[OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)**
   - 深入理解构建系统
   - 用于高级开发

### 快速上手路径

1. 使用 **[deploy_rpmsg.sh](deploy_rpmsg.sh)** 自动部署
2. 参考 **[OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md)** 速查表
3. 遇到问题查看 **[AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md)** 故障排查章节

### 高级开发路径

1. 阅读 **[OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)** 理解架构
2. 研究 `pru_rules.mak` 和项目 makefile
3. 参考实例分析创建自己的项目

---

## 📁 文件组织

```
open-pru/
├── 📄 README.md                           # OpenPRU 官方 README
├── 📄 DOCUMENTATION_INDEX.md              # 本文件（文档索引）
├── 📄 RPMSG_TEST_SUMMARY.md               # RPMsg 测试总结
├── 📄 AM62X_PRU_RPMSG_GUIDE.md            # 完整操作指南
├── 📄 OPENPRU_ARCHITECTURE.md             # 架构详解
├── 📄 OPENPRU_QUICK_REFERENCE.md          # 快速参考
├── 🔧 deploy_rpmsg.sh                     # 自动部署脚本
├── 📁 examples/
│   ├── empty/
│   │   └── 📄 GPIO_1kHz_README.md         # GPIO 测试指南
│   ├── rpmsg_echo_linux/
│   └── ...
└── 📁 docs/                                # OpenPRU 官方文档
    ├── getting_started.md
    ├── open_pru_organization.md
    └── ...
```

---

## 🔍 按需求查找文档

### 我想...

| 需求 | 推荐文档 | 章节 |
|------|---------|------|
| 第一次配置环境 | [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md) | 步骤 1-4 |
| 快速部署测试 | [deploy_rpmsg.sh](deploy_rpmsg.sh) | - |
| 了解实际执行流程 | [RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md) | 实际执行步骤 |
| 查看命令语法 | [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md) | 编译命令速查 |
| 理解编译过程 | [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md) | 编译流程详解 |
| 调试编译错误 | [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md) | 常见问题排查 |
| 配置 imports.mak | [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md) | imports.mak 配置 |
| 理解内存布局 | [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md) | 内存布局与链接 |
| 查看生成的文件 | [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md) | 生成的文件说明 |
| 部署固件 | [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md) | 步骤 3-4 |
| PRU 启动失败 | [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md) | 故障排查 |
| RPMsg 通信测试 | [RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md) | 步骤 6-7 |
| GPIO 控制 | [GPIO_1kHz_README.md](examples/empty/GPIO_1kHz_README.md) | 完整文档 |
| 创建新项目 | [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md) | 项目结构 |
| 修改构建系统 | [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md) | 构建系统架构 |

---

## 🎓 学习路径建议

### Level 1: 入门 (0-1 周)
- [ ] 阅读 [RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md)
- [ ] 跟随 [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md) 完成配置
- [ ] 使用 [deploy_rpmsg.sh](deploy_rpmsg.sh) 部署第一个示例
- [ ] 成功运行 RPMsg echo 测试

### Level 2: 熟练 (1-2 周)
- [ ] 研究 [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md)
- [ ] 手动编译和部署不同示例
- [ ] 修改 RPMsg 示例代码
- [ ] 测试 GPIO 翻转程序

### Level 3: 精通 (2-4 周)
- [ ] 深入阅读 [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)
- [ ] 理解 Makefile 系统
- [ ] 分析 linker.cmd 和内存布局
- [ ] 创建自己的 PRU 项目

### Level 4: 专家 (持续学习)
- [ ] 修改 pru_rules.mak 添加自定义功能
- [ ] 移植项目到不同设备
- [ ] 优化 PRU 代码性能
- [ ] 贡献代码到 OpenPRU 项目

---

## ⚙️ 环境配置检查清单

使用文档前，确保已完成以下配置：

- [ ] 安装 PRU 编译器 (ti-cgt-pru_2.3.3)
  - 路径: `~/ti/ti-cgt-pru_2.3.3/`
  - 验证: `~/ti/ti-cgt-pru_2.3.3/bin/clpru --version`

- [ ] 创建并配置 imports.mak
  - [ ] `DEVICE = am62x`
  - [ ] `BUILD_LINUX = y`
  - [ ] `BUILD_MCUPLUS = n`
  - [ ] `CGT_TI_PRU_PATH = $(HOME)/ti/ti-cgt-pru_2.3.3`

- [ ] 编译 source/ 库
  - [ ] `cd source && make`
  - [ ] 验证: `ls source/rpmsg/lib/rpmsg.lib`

- [ ] 目标设备配置
  - [ ] 设备可通过 SSH 访问
  - [ ] RemoteProc 已启用
  - [ ] `/lib/firmware/` 目录可写

---

## 📞 获取帮助

### 查看文档
1. 根据需求在本索引中找到对应文档
2. 使用文档内的目录快速定位章节
3. 参考故障排查章节解决问题

### 调试步骤
1. 查看 [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md) 常见问题
2. 参考 [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md) 故障排查
3. 检查 `dmesg` 和编译日志
4. 查阅 [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md) 理解原理

### 外部资源
- [TI E2E Forums](https://e2e.ti.com)
- [PRU Academy](https://dev.ti.com/tirex/explore/node?node=A__AEIJm0rwIeU.2P1OBWwlaA__AM62-ACADEMY__uiYMDcq__LATEST)
- [OpenPRU GitHub](https://github.com/TexasInstruments/mcupsdk-core)

---

## 📝 文档维护

**文档版本**: 1.0  
**最后更新**: 2026-05-23  
**适用平台**: AM62X (PocketBeagle2)  
**测试环境**: 
- 开发主机: Ubuntu Linux (WSL)
- 目标设备: PocketBeagle2 @ 192.168.7.2
- PRU 编译器: ti-cgt-pru_2.3.3

**文档作者**: Zhang Jiancai  
**基于**: TI OpenPRU 项目

---

## 🎯 快速导航

**新手从这里开始** → [RPMSG_TEST_SUMMARY.md](RPMSG_TEST_SUMMARY.md)  
**详细步骤指南** → [AM62X_PRU_RPMSG_GUIDE.md](AM62X_PRU_RPMSG_GUIDE.md)  
**命令速查表** → [OPENPRU_QUICK_REFERENCE.md](OPENPRU_QUICK_REFERENCE.md)  
**架构深度解析** → [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)  
**自动部署工具** → [deploy_rpmsg.sh](deploy_rpmsg.sh)
