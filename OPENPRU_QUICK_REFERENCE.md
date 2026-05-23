# OpenPRU 快速参考手册

本文档提供 OpenPRU 编译流程的快速参考。完整架构说明见 [OPENPRU_ARCHITECTURE.md](OPENPRU_ARCHITECTURE.md)。

---

## 目录结构速查

```
open-pru/
├── imports.mak              ← 配置这里（DEVICE、工具路径）
├── makefile                 ← 顶层入口
├── pru_rules.mak           ← 共享编译规则
├── source/                  ← 公共源码和库
│   ├── include/<device>/   ← 设备特定头文件
│   ├── linker_cmd/         ← 链接脚本模板
│   └── rpmsg/              ← RPMsg 库
├── examples/                ← 应用示例
│   └── <project>/
│       ├── firmware/
│       │   └── <board>/<core>/ti-pru-cgt/
│       │       ├── makefile         ← 核心 makefile
│       │       ├── linker.cmd       ← 链接脚本
│       │       └── generated/       ← 编译输出
│       │           ├── xxx.out      ← 最终固件
│       │           ├── xxx.map      ← 内存映射
│       │           └── xxx.h        ← Hex 数组
│       ├── mcuplus/        ← MCU+ 主机代码（可选）
│       └── linux/          ← Linux 主机代码（可选）
└── academy/                 ← 教学项目
```

---

## 编译流程一览

```
配置 imports.mak
      ↓
make (顶层)
      ↓
项目 makefile (检查设备、依赖)
      ↓
核心 makefile + pru_rules.mak
      ↓
┌─────────────────────────────┐
│ 1. 扫描源文件                │
│    .c, .asm → OBJECTS 列表  │
└─────────────────────────────┘
      ↓
┌─────────────────────────────┐
│ 2. 编译源码                  │
│    clpru .c/.asm → .obj     │
└─────────────────────────────┘
      ↓
┌─────────────────────────────┐
│ 3. 链接                      │
│    clpru -z .obj → .out     │
└─────────────────────────────┘
      ↓
┌─────────────────────────────┐
│ 4. 后处理                    │
│    hexpru .out → .h         │
└─────────────────────────────┘
      ↓
生成文件:
  - xxx.out (ELF 固件)
  - xxx.map (内存映射)
  - xxx.h   (Hex 数组)
```

---

## imports.mak 关键配置

```makefile
# 必须配置
DEVICE ?= am62x                # 目标设备
BUILD_LINUX ?= y               # 构建 Linux 项目
BUILD_MCUPLUS ?= n             # 构建 MCU+ 项目 (AM62X 不支持)

# 工具路径
TOOLS_PATH ?= $(HOME)/ti
CGT_TI_PRU_PATH = $(TOOLS_PATH)/ti-cgt-pru_2.3.3
CCS_PATH = $(TOOLS_PATH)/ccs1280/ccs

# 可选
PROFILE ?= release             # debug 或 release
DEVICE_TYPE ?= GP              # GP 或 HS
```

**设备代码对照表**:
- AM62X (PocketBeagle2) → `am62x`
- AM64X → `am64x`
- AM243X → `am243x`
- AM261X → `am261x`
- AM263X → `am263x`

---

## 核心 Makefile 参数

在 `firmware/<board>/<core>/ti-pru-cgt/makefile` 中定义：

```makefile
# 必须定义
OUTPUT_NAME := xxx_fw               # 输出文件基础名
FILES_PATH := .. ../../.. .         # 源文件搜索路径
COMMAND_FILES := linker.cmd         # 链接脚本
PRU_VERSION := 3                    # PRU 版本 (3 或 4)
EXPECTED_DEVICE := am62x            # 期望的设备

# 可选覆盖
OPT_LEVEL ?= 2                      # 优化级别 (0-4)
STACK_SIZE ?= 0x100                 # 栈大小（C 代码）
HEAP_SIZE ?= 0x100                  # 堆大小（C 代码）
ENTRY_POINT ?= main                 # 入口点（汇编）

# 核心特定定义（-D 传给编译器）
DFLAGS := -DHOST_INT_BIT=30 -DCHAN_PORT=30

# 库文件
LIBS := $(OPEN_PRU_PATH)/source/rpmsg/lib/rpmsg.lib
```

**PRU_VERSION 对照**:
- `3` = PRUSS / PRU-ICSS (AM62X, AM64X, AM243X)
- `4` = PRU_ICSSG (某些 AM6x 变种)

---

## 编译命令速查

### 编译单个项目

```bash
# 方法 1: 在项目目录
cd examples/rpmsg_echo_linux
make              # 构建 PRU + 主机代码
make pru          # 仅构建 PRU 固件
make host         # 仅构建主机代码
make clean        # 清理

# 方法 2: 在核心目录（直接编译）
cd examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt
make clean
make
```

### 编译所有项目

```bash
cd /path/to/open-pru
make -s           # 构建所有匹配 DEVICE 的项目
make -s pru       # 仅构建 PRU 固件
make -s host      # 仅构建主机代码
make -s clean     # 清理所有项目
```

**注意**: `-s` 抑制详细输出。调试时去掉 `-s`。

---

## 生成的文件说明

### generated/ 目录内容

| 文件 | 说明 | 用途 |
|------|------|------|
| `xxx.out` | ELF 可执行文件 | 部署到 Linux `/lib/firmware/` |
| `xxx.map` | 内存映射文件 | 调试，查看符号地址 |
| `xxx.h` | Hex 数组（C 格式） | MCU+ SDK 嵌入固件 |
| `xxx_linkInfo.xml` | 链接信息（XML） | CCS 调试 |
| `*.obj` | 目标文件 | 中间文件 |
| `*.pp` | 预处理依赖 | Make 依赖跟踪 |

### .out 文件（ELF）

**查看信息**:
```bash
file xxx.out              # 文件类型
size xxx.out              # 段大小
readelf -h xxx.out        # ELF 头
readelf -S xxx.out        # 段表
readelf -s xxx.out        # 符号表
objdump -d xxx.out        # 反汇编
```

### .map 文件（内存映射）

**内容**:
- 内存区域使用情况
- 符号地址列表
- 段分配详情
- 链接统计

**示例摘录**:
```
MEMORY CONFIGURATION
         name            origin    length      used     unused
----------------------  --------  ---------  --------  --------
  PRU_IMEM              00000000   00004000  000007dc  00003824
  PRU0_DMEM_0           00000000   00002000  00000f84  0000107c

GLOBAL SYMBOLS: SORTED BY Symbol Address
address    name
--------   ----
00000000   _c_int00
00000714   main
00001d00   resourceTable
```

---

## 内存布局速查（AM62X）

### PRU 内存空间

| 区域 | 地址 | 大小 | 用途 | C 寄存器 |
|------|------|------|------|---------|
| IRAM | 0x00000000 | 16 KB | 指令代码 | - |
| DRAM0 | 0x00000000 | 8 KB | PRU0 数据 | C24 |
| DRAM1 | 0x00002000 | 8 KB | PRU1 数据 | C25 |
| Shared RAM | 0x00010000 | 32 KB | 共享数据 | C28 |
| INTC | 0x00020000 | - | 中断控制器 | C0 |
| CFG | 0x00026000 | - | PRU 配置 | C4 |
| CTRL (PRU0) | 0x00022000 | - | PRU0 控制 | C11 |

### linker.cmd 段分配

```c
SECTIONS {
    .text           >  PRU_IMEM, PAGE 0        /* 代码 → IRAM */
    .stack          >  PRU0_DMEM_0, PAGE 1     /* 栈 → DRAM0 */
    .data           >  PRU0_DMEM_0, PAGE 1     /* 数据 → DRAM0 */
    .bss            >  PRU0_DMEM_0, PAGE 1     /* BSS → DRAM0 */
    .resource_table >  PRU0_DMEM_0, PAGE 1     /* RPMsg 资源表 */
}
```

---

## 部署固件

### Linux RemoteProc (AM62X)

```bash
# 1. 复制固件
scp generated/xxx.out root@<target-ip>:/lib/firmware/am62x-pru0-fw

# 2. 重启 PRU
ssh root@<target-ip> '
    echo stop > /sys/class/remoteproc/remoteproc1/state
    echo start > /sys/class/remoteproc/remoteproc1/state
'

# 3. 验证
ssh root@<target-ip> 'cat /sys/class/remoteproc/remoteproc1/state'
# 应输出: running
```

**固件名称对照**:
- PRU0: `am62x-pru0-fw`
- PRU1: `am62x-pru1-fw`

### MCU+ SDK (AM243X, AM64X 等)

1. 编译 PRU 固件生成 `.h` 文件
2. 将 `.h` 文件包含到 R5F 项目
3. 使用 `PRUICSS_loadFirmware()` API 加载

```c
#include "pru0_load_bin.h"

PRUICSS_loadFirmware(handle, PRU_ICSSM_PRU0,
                     PRU0Firmware, PRU0FirmwareSize);
```

---

## 常见问题排查

### 编译错误

**错误**: `DEVICE is not set`  
**解决**: 创建 `imports.mak` 并设置 `DEVICE=am62x`

**错误**: `CGT_TI_PRU_PATH not set`  
**解决**: 在 `imports.mak` 中设置正确的编译器路径

**错误**: `DEVICE='am64x' but this firmware targets am62x`  
**解决**: `imports.mak` 中的 `DEVICE` 与项目不匹配，修改为 `am62x`

**错误**: `cannot find file "rpmsg.lib"`  
**解决**: 先编译 `source/` 目录: `cd source && make`

### 链接错误

**错误**: `unresolved symbols`  
**解决**: 
- 缺少库文件：在核心 makefile 中添加 `LIBS`
- 缺少源文件：检查 `FILES_PATH` 是否包含所有源码目录

**错误**: `section .text will not fit`  
**解决**: 代码超过 IRAM 大小（16KB），优化或减少代码

### 运行时问题

**问题**: PRU 启动失败  
**检查**:
```bash
dmesg | grep -i pru       # 查看内核日志
ls -l /lib/firmware/      # 检查固件是否存在
chmod 644 /lib/firmware/am62x-pru0-fw  # 修复权限
```

**问题**: RPMsg 设备不存在  
**检查**:
- PRU 是否运行: `cat /sys/class/remoteproc/remoteproc1/state`
- 固件是否包含资源表: `readelf -S xxx.out | grep resource_table`
- 通道名称是否为 `"rpmsg-raw"` (匹配 Linux rpmsg_char 驱动)

---

## 编译器标志参考

### 常用编译器标志 (CFLAGS)

| 标志 | 说明 |
|------|------|
| `-v3` / `-v4` | PRU 版本 (3=PRUSS, 4=ICSSG) |
| `-O0` - `-O4` | 优化级别 (0=无优化, 4=最高) |
| `-g` | 包含调试信息 |
| `--endian=little` | 小端序（PRU 使用） |
| `--display_error_number` | 显示错误编号 |
| `--asm_directory=dir` | 汇编输出目录 |
| `--obj_directory=dir` | 目标文件目录 |

### 常用链接器标志 (LFLAGS)

| 标志 | 说明 |
|------|------|
| `-z` | 链接模式 |
| `-m file.map` | 生成内存映射文件 |
| `-o file.out` | 输出文件名 |
| `--entry_point=main` | 设置入口点 |
| `--stack_size=0x100` | 栈大小（C 代码） |
| `--heap_size=0x100` | 堆大小（C 代码） |
| `--warn_sections` | 警告未使用的段 |
| `--ram_model` | RAM 模型 |
| `-i path` | 库搜索路径 |
| `--library=lib.a` | 链接库 |

### 预定义宏 (DFLAGS)

```makefile
# 在核心 makefile 中定义
DFLAGS := -DHOST_INT_BIT=30 -DTO_ARM_HOST=16 -DCHAN_PORT=30

# 在代码中使用
#define HOST_INT ((uint32_t)1 << HOST_INT_BIT)
```

---

## 快速开始检查清单

- [ ] 安装 PRU 编译器 (ti-cgt-pru_2.3.3)
- [ ] 复制 `imports.mak.default` → `imports.mak`
- [ ] 设置 `DEVICE = am62x`（或对应设备）
- [ ] 设置 `CGT_TI_PRU_PATH = /path/to/ti-cgt-pru_2.3.3`
- [ ] 设置 `BUILD_LINUX = y`（AM62X）
- [ ] 设置 `BUILD_MCUPLUS = n`（AM62X）
- [ ] 编译 `source/` 库: `cd source && make`
- [ ] 编译示例项目: `cd examples/empty && make`
- [ ] 部署固件到 `/lib/firmware/`
- [ ] 启动 PRU 并验证

---

## 参考资源

### 文档
- [OpenPRU 完整架构](OPENPRU_ARCHITECTURE.md) - 本仓库详细架构文档
- [OpenPRU README](README.md) - 官方说明
- [Getting Started](docs/getting_started.md) - 入门指南
- [PRU RPMsg 测试流程](RPMSG_TEST_SUMMARY.md) - RPMsg 测试指南

### TI 资源
- [PRU 编译器手册](https://www.ti.com/lit/spruij2)
- [AM62X TRM](https://www.ti.com/lit/spruiv7) - 技术参考手册
- [PRU Academy](https://dev.ti.com/tirex/explore/node?node=A__AEIJm0rwIeU.2P1OBWwlaA__AM62-ACADEMY__uiYMDcq__LATEST)

### 工具下载
- [PRU-CGT-2-3](https://www.ti.com/tool/PRU-CGT) - PRU 编译器
- [Code Composer Studio](https://www.ti.com/tool/CCSTUDIO) - CCS IDE
- [Linux SDK](https://www.ti.com/tool/download/PROCESSOR-SDK-LINUX-AM62X)

---

**版本**: 1.0  
**日期**: 2026-05-23  
**适用平台**: AM62X (PocketBeagle2) 及其他 TI PRU 平台
