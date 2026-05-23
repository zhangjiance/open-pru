# OpenPRU 架构与编译流程详解

本文档详细说明 TI OpenPRU 项目的架构设计、构建系统和固件生成流程。

---

## 目录

1. [OpenPRU 概述](#openpru-概述)
2. [仓库组织结构](#仓库组织结构)
3. [构建系统架构](#构建系统架构)
4. [编译流程详解](#编译流程详解)
5. [固件生成过程](#固件生成过程)
6. [内存布局与链接](#内存布局与链接)
7. [多设备支持机制](#多设备支持机制)
8. [实例分析](#实例分析)

---

## OpenPRU 概述

### 什么是 OpenPRU？

OpenPRU 是 Texas Instruments (TI) 提供的 PRU (Programmable Real-Time Unit) 开发包，支持以下处理器：

- **AM243x** 系列
- **AM261x** 系列
- **AM263x/AM263Px** 系列
- **AM62x** 系列（如 AM625, PocketBeagle2）
- **AM64x** 系列

### PRU 子系统简介

PRU 是 TI SoC 内的实时处理单元，具有以下特点：

- **实时性能**: 200-333 MHz，确定性的指令周期
- **低延迟**: 直接访问 GPIO 和外设，无需通过 OS
- **独立性**: 与主处理器（ARM）独立运行
- **专用硬件**: 硬件乘法器、移位器、IEP 定时器等

**PRU 的典型用途**:
- 高速 GPIO 控制（LED、传感器采样）
- 自定义协议实现（工业总线、传感器接口）
- 实时数据采集
- 硬件加速（FFT、滤波等）

---

## 仓库组织结构

### 顶层目录结构

```
open-pru/
├── imports.mak                 # 全局配置文件（设备、工具路径等）
├── imports.mak.default         # 默认配置模板
├── makefile                    # 顶层 Makefile（构建入口）
├── pru_rules.mak              # 共享的 PRU 构建规则
├── README.md                   # 项目说明
├── docs/                       # 文档目录
│   ├── getting_started.md
│   ├── open_pru_organization.md
│   └── ...
├── academy/                    # 教学和训练项目
│   ├── getting_started_labs/
│   ├── gpio/
│   ├── intc/
│   └── ...
├── examples/                   # 应用示例
│   ├── empty/                 # 空模板项目
│   ├── empty_c/               # C 语言空模板
│   ├── rpmsg_echo_linux/      # RPMsg 通信示例
│   ├── custom_frequency_generator/
│   └── ...
└── source/                     # 共享源码和库
    ├── firmware/              # 固件通用代码
    ├── include/               # 头文件（按设备组织）
    │   ├── am62x/
    │   ├── am64x/
    │   └── ...
    ├── linker_cmd/            # 链接脚本模板
    └── rpmsg/                 # RPMsg 库

```

### 项目组织模式

每个项目（example 或 academy）遵循统一的结构：

```
project_name/
├── makefile                    # 项目级 Makefile
├── readme.md                   # 项目说明文档
├── firmware/                   # PRU 固件代码
│   ├── main.c / main.asm      # 共享的主源码
│   └── <board>/               # 板级目录
│       └── <core>/            # 核心目录（如 pruss0_pru0_fw）
│           └── ti-pru-cgt/    # 编译器工具链目录
│               ├── makefile
│               ├── linker.cmd
│               └── generated/ # 编译输出目录
├── mcuplus/                    # MCU+ SDK 相关代码（可选）
│   └── <board>/<core>/
└── linux/                      # Linux 应用代码（可选）
    └── <application>/
```

**目录层次说明**:

1. **项目级** (`project_name/`)
   - 定义支持的处理器
   - 定义依赖关系
   - 协调固件和主机代码构建

2. **固件级** (`firmware/`)
   - 存放 PRU 源代码
   - 共享代码位于顶层
   - 设备/板/核心特定代码分层组织

3. **核心级** (`ti-pru-cgt/`)
   - 实际编译发生的地方
   - 包含 linker.cmd 和核心特定 makefile
   - 生成最终的 `.out` 固件文件

---

## 构建系统架构

### 三层 Makefile 系统

OpenPRU 使用三层级联的 Makefile 系统：

```
┌─────────────────────────────────────────┐
│  1. 顶层 Makefile (open-pru/makefile)   │
│     - 读取 imports.mak                  │
│     - 调度 source/、academy/、examples/ │
│     - 提供 all、pru、host、clean 目标   │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  2. 项目级 Makefile                     │
│     (examples/rpmsg_echo_linux/makefile)│
│     - 定义支持的处理器                  │
│     - 检查依赖关系                      │
│     - 调用核心级 Makefile               │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  3. 核心级 Makefile                     │
│     (firmware/.../ti-pru-cgt/makefile)  │
│     - 包含 pru_rules.mak                │
│     - 定义核心特定参数                  │
│     - 执行实际编译                      │
└─────────────────────────────────────────┘
```

### imports.mak 配置文件

`imports.mak` 是全局配置中心，控制整个构建过程：

```makefile
# 设备选择（决定编译哪些项目）
DEVICE ?= am62x

# 配置文件（debug 或 release）
PROFILE ?= release

# 芯片类型（GP 或 HS）
DEVICE_TYPE ?= GP

# 是否构建 MCU+ SDK 项目（AM62x 不支持）
BUILD_MCUPLUS ?= n

# 是否构建 Linux 项目（AM62x 支持）
BUILD_LINUX ?= y

# 工具路径
TOOLS_PATH ?= $(HOME)/ti
CGT_TI_PRU_PATH = $(TOOLS_PATH)/ti-cgt-pru_2.3.3
CCS_PATH = $(TOOLS_PATH)/ccs1280/ccs
...
```

**配置逻辑**:
- `DEVICE` 决定编译哪些项目（每个项目声明支持的处理器）
- `BUILD_MCUPLUS` 和 `BUILD_LINUX` 控制是否编译主机代码
- 工具路径指向编译器和 SDK 位置

### pru_rules.mak 共享规则

`pru_rules.mak` 包含所有 PRU 固件通用的编译规则：

**核心功能**:

1. **设备验证**: 确保 `DEVICE` 与项目支持的设备匹配
2. **编译规则**: 定义如何将 `.c` 和 `.asm` 编译为 `.obj`
3. **链接规则**: 定义如何将 `.obj` 链接为 `.out`
4. **后处理**: 生成 hex 数组（`.h` 文件）供 MCU+ 使用
5. **清理规则**: 删除生成的文件

**编译器标志**:

```makefile
# 编译器标志
CFLAGS := \
    -v3                          # PRU 版本 3 (PRUSS/PRU-ICSS)
    -O2                          # 优化级别 2
    --display_error_number       # 显示错误编号
    --asm_directory=generated    # 汇编输出目录
    --obj_directory=generated    # 目标文件目录
    -g                           # 调试信息
    --endian=little              # 小端序

# 链接器标志
LFLAGS := \
    -m$(GEN_DIR)/$(OUTPUT_NAME).map    # 生成 map 文件
    --warn_sections                     # 警告未使用的段
    --ram_model                         # RAM 模型
    --entry_point=main                  # 入口点
```

---

## 编译流程详解

### 完整编译流程图

```
┌──────────────────────────────────────────────────────────┐
│ 步骤 1: 配置                                              │
│ - 读取 imports.mak                                        │
│ - 验证 DEVICE 设置                                        │
│ - 检查工具链路径                                          │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 步骤 2: 源码扫描                                          │
│ - 在 FILES_PATH 中查找 .c 和 .asm 文件                    │
│ - 生成 OBJECTS 列表                                       │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 步骤 3: 编译源码                                          │
│ - .asm 文件 → clpru → .obj (汇编文件)                    │
│ - .c 文件   → clpru → .obj (C 文件)                      │
│   • 包含头文件（-I 路径）                                 │
│   • 应用编译器标志（CFLAGS）                              │
│   • 应用预定义宏（DFLAGS）                                │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 步骤 4: 链接                                              │
│ - 所有 .obj 文件 + linker.cmd → clpru -z → .out         │
│   • 分配内存段                                            │
│   • 解析符号引用                                          │
│   • 生成 .map 文件（内存映射）                            │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 步骤 5: 后处理（Post-build）                              │
│ - .out → hexpru → .h (hex 数组)                          │
│   • 添加版权头                                            │
│   • 可选：复制到 MCU+ 项目路径                            │
└──────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────────────────────────────────────────────────┐
│ 输出文件                                                  │
│ - generated/xxx.out      (ELF 可执行文件，部署用)         │
│ - generated/xxx.map      (内存映射)                       │
│ - generated/xxx.h        (hex 数组，MCU+ 嵌入用)          │
│ - generated/*.obj        (中间目标文件)                   │
│ - generated/*.pp         (预处理依赖)                     │
└──────────────────────────────────────────────────────────┘
```

### 编译命令详解

#### 1. 编译汇编文件

```bash
"$(CGT_TI_PRU_PATH)/bin/clpru" \
    --include_path=$(CGT_TI_PRU_PATH)/include \
    --include_path=$(OPEN_PRU_PATH)/source \
    --include_path=$(OPEN_PRU_PATH)/source/include/am62x \
    -v3 \              # PRU 版本 3
    -O2 \              # 优化级别
    --display_error_number \
    --asm_directory=generated \
    --obj_directory=generated \
    -g \               # 调试信息
    --endian=little \  # 小端序
    --output_file=generated/main.obj \
    main.asm
```

**输入**: `main.asm`（汇编源码）  
**输出**: `generated/main.obj`（目标文件）

#### 2. 编译 C 文件

```bash
"$(CGT_TI_PRU_PATH)/bin/clpru" \
    --include_path=... \    # 同上
    -v3 -O2 ... \           # 同上
    --stack_size=0x100 \    # C 代码需要栈
    --heap_size=0x100 \     # C 代码需要堆
    --output_file=generated/main.obj \
    main.c
```

**输入**: `main.c`（C 源码）  
**输出**: `generated/main.obj`（目标文件）

**C 代码额外标志**:
- `--stack_size`: 栈大小（默认 256 字节）
- `--heap_size`: 堆大小（默认 256 字节）
- `-i$(CGT_TI_PRU_PATH)/lib`: C 库路径
- `--library=libc.a`: 链接 C 标准库

#### 3. 链接

```bash
"$(CGT_TI_PRU_PATH)/bin/clpru" \
    -v3 -O2 -z \        # -z 表示链接模式
    generated/*.obj \    # 所有目标文件
    linker.cmd \         # 链接脚本
    -m generated/xxx.map \         # 内存映射输出
    --xml_link_info=generated/xxx_linkInfo.xml \
    --warn_sections \
    --reread_libs \
    --ram_model \
    --entry_point=main \
    --disable_auto_rts \    # 汇编模式禁用 C 运行时
    -o generated/xxx.out    # 最终可执行文件
```

**输入**: 
- `generated/*.obj`（所有目标文件）
- `linker.cmd`（链接脚本）

**输出**:
- `generated/xxx.out`（ELF 可执行文件）
- `generated/xxx.map`（内存映射文件）

#### 4. 后处理 - 生成 Hex 数组

```bash
"$(CGT_TI_PRU_PATH)/bin/hexpru" \
    --diag_wrap=off \
    --array \                          # 生成数组格式
    --array:name_prefix=PRU0Firmware \ # 数组名前缀
    -o generated/xxx.h \
    generated/xxx.out
```

**输入**: `generated/xxx.out`（ELF 文件）  
**输出**: `generated/xxx.h`（C 数组格式的固件）

**生成的 .h 文件示例**:

```c
/* Copyright header... */

const unsigned int PRU0FirmwareSize = 2556;
const unsigned char PRU0Firmware[] = {
    0x1e, 0xe0, 0xe0, 0xe0, 0x24, 0x24, 0x00, 0x24,
    0xe2, 0xe2, 0xe2, 0xe2, 0x10, 0xe0, 0xe0, 0x10,
    ...
};
```

**用途**: MCU+ SDK 项目可以直接包含这个 `.h` 文件，通过 `PRUICSS_loadFirmware()` API 将固件加载到 PRU IRAM。

---

## 固件生成过程

### 从源码到可部署固件

```
┌─────────────┐
│  main.asm   │  汇编源码
│  main.c     │  C 源码
└─────────────┘
      │ 编译（clpru）
      ▼
┌─────────────┐
│  main.obj   │  目标文件（机器码 + 符号）
│  other.obj  │
└─────────────┘
      │ 链接（clpru -z + linker.cmd）
      ▼
┌─────────────────────────────┐
│  firmware.out (ELF)         │  可执行文件
│  - .text    (代码段)        │
│  - .data    (数据段)        │
│  - .bss     (未初始化数据)  │
│  - .resource_table (RPMsg)  │
│  - ...                      │
└─────────────────────────────┘
      │
      ├─ 用于 Linux RemoteProc ─────────────┐
      │                                      │
      │                                      ▼
      │                         ┌──────────────────────┐
      │                         │ /lib/firmware/       │
      │                         │ am62x-pru0-fw        │
      │                         │ (直接部署 .out 文件) │
      │                         └──────────────────────┘
      │
      └─ 转换为 Hex 数组（hexpru）
                                      │
                                      ▼
                         ┌──────────────────────┐
                         │  firmware.h          │
                         │  (C 数组格式)        │
                         │  用于 MCU+ 嵌入      │
                         └──────────────────────┘
```

### ELF (.out) 文件结构

PRU 固件是标准的 ELF (Executable and Linkable Format) 文件：

```
ELF Header
  - 魔数: 0x7F 'E' 'L' 'F'
  - 类型: 可执行文件
  - 架构: TI PRU
  - 入口点地址: 0x00000000 (main)

Program Headers (段)
  - LOAD: 0x00000000 - 0x00001000  (.text - 代码)
  - LOAD: 0x00000000 - 0x000001FF  (.data - 数据)
  
Section Headers (节)
  - .text          (代码段)
  - .data          (初始化数据)
  - .bss           (未初始化数据)
  - .resource_table (RPMsg 资源表)
  - .pru_irq_map   (中断映射)
  - .stack         (栈)
  - .cinit         (C 初始化数据)
  - ...

Symbol Table (符号表)
  - main (函数)
  - pru_rpmsg_init (函数)
  - resourceTable (变量)
  - ...

String Table (字符串表)
Debug Information (调试信息)
```

**关键段的作用**:

1. **.text**: PRU 指令代码，加载到 PRU Instruction RAM (IRAM)
2. **.data/.bss**: 数据，加载到 PRU Data RAM (DRAM)
3. **.resource_table**: Linux RemoteProc 所需的资源表（VirtIO/RPMsg）
4. **.pru_irq_map**: 中断控制器配置，传递给 Linux 驱动

---

## 内存布局与链接

### PRU 内存架构（以 AM62X 为例）

```
┌────────────────────────────────────────────┐
│ PRU Instruction RAM (IRAM)                 │
│ 地址: 0x00000000 - 0x00003FFF              │
│ 大小: 16 KB                                │
│ 用途: 存放 PRU 代码 (.text)                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ PRU Data RAM 0 (DRAM0)                     │
│ 地址: 0x00000000 - 0x00001FFF              │
│ 大小: 8 KB                                 │
│ 用途: PRU0 专用数据 (.data, .bss, .stack) │
│ 寄存器: C24                                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ PRU Data RAM 1 (DRAM1)                     │
│ 地址: 0x00002000 - 0x00003FFF              │
│ 大小: 8 KB                                 │
│ 用途: PRU1 专用数据                        │
│ 寄存器: C25                                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ PRU Shared RAM                             │
│ 地址: 0x00010000 - 0x00017FFF              │
│ 大小: 32 KB                                │
│ 用途: PRU0 和 PRU1 共享数据                │
│ 寄存器: C28                                │
└────────────────────────────────────────────┘

┌────────────────────────────────────────────┐
│ 外设寄存器空间                              │
│ - PRU_INTC   (0x00020000) : 中断控制器     │
│ - PRU_CFG    (0x00026000) : PRU 配置       │
│ - PRU_UART   (0x00028000) : UART           │
│ - PRU_IEP    (0x0002E000) : 工业以太网外设 │
│ - PRU0_CTRL  (0x00022000) : PRU0 控制      │
│ 寄存器: C0-C31 (可编程常量表)              │
└────────────────────────────────────────────┘
```

### linker.cmd 内存分配

链接脚本 `linker.cmd` 定义如何将段映射到内存：

```c
/* 内存定义 */
MEMORY {
    PAGE 0:  /* 指令空间 */
        PRU_IMEM : org = 0x00000000 len = 0x00004000  /* 16KB IRAM */
    
    PAGE 1:  /* 数据空间 */
        PRU0_DMEM_0 : org = 0x00000000 len = 0x00002000 CREGISTER=24
        PRU1_DMEM_1 : org = 0x00002000 len = 0x00002000 CREGISTER=25
    
    PAGE 2:  /* 共享和外设空间 */
        PRU_SHAREDMEM : org = 0x00010000 len = 0x00008000 CREGISTER=28
        PRU_INTC      : org = 0x00020000 len = 0x00001504 CREGISTER=0
        PRU_CFG       : org = 0x00026000 len = 0x00000100 CREGISTER=4
        ...
}

/* 段分配 */
SECTIONS {
    /* 强制 _c_int00 到 IRAM 起始位置（入口点） */
    .text:_c_int00* >  0x0, PAGE 0
    
    /* 代码段 → IRAM */
    .text > PRU_IMEM, PAGE 0
    
    /* 数据段 → DRAM0 */
    .stack   > PRU0_DMEM_0, PAGE 1  /* 栈 */
    .bss     > PRU0_DMEM_0, PAGE 1  /* 未初始化数据 */
    .data    > PRU0_DMEM_0, PAGE 1  /* 初始化数据 */
    .sysmem  > PRU0_DMEM_0, PAGE 1  /* 堆 */
    .rodata  > PRU0_DMEM_0, PAGE 1  /* 只读数据 */
    
    /* RPMsg 资源表（8 字节对齐，适配 64 位内核） */
    .resource_table : ALIGN(8) > PRU0_DMEM_0, PAGE 1
    
    /* 中断映射（复制到 Linux 驱动） */
    .pru_irq_map (COPY) : { *(.pru_irq_map) }
}
```

**关键设计决策**:

1. **PAGE 分离**: 指令、数据、外设分别放在不同的 PAGE，便于管理
2. **入口点固定**: `_c_int00` 必须在 IRAM 地址 0，方便引导
3. **资源表对齐**: `.resource_table` 必须 8 字节对齐（ARMv8 要求）
4. **中断映射复制**: `.pru_irq_map` 标记为 COPY，仅供 Linux 读取

---

## 多设备支持机制

### 设备特定的头文件

OpenPRU 通过条件包含头文件支持多设备：

```
source/include/
├── am62x/              # AM62X 专用
│   ├── pru_cfg.h      # PRU 配置寄存器
│   ├── pru_ctrl.h     # PRU 控制寄存器
│   ├── pru_intc.h     # 中断控制器
│   ├── pru_iep.h      # IEP 定时器
│   └── ...
├── am64x/              # AM64X 专用
├── am243x/             # AM243X 专用
└── hw_types.h          # 通用硬件类型
```

**编译时自动选择**:

```makefile
# pru_rules.mak 中自动添加设备特定的包含路径
INCLUDE := \
    --include_path=$(OPEN_PRU_PATH)/source/include/$(DEVICE)
```

编译 AM62X 项目时自动包含 `source/include/am62x/` 中的头文件。

### 设备验证机制

```makefile
# pru_rules.mak 中的验证
EXPECTED_DEVICE := am62x   # 在核心 makefile 中定义

ifneq ($(DEVICE),$(EXPECTED_DEVICE))
$(error DEVICE='$(DEVICE)' but this firmware targets $(EXPECTED_DEVICE))
endif
```

**防止错误**:
- 如果 `imports.mak` 中 `DEVICE=am64x`
- 但尝试编译 AM62X 专用固件
- 构建系统会立即报错，防止使用错误的头文件

### 项目级设备支持声明

```makefile
# examples/rpmsg_echo_linux/makefile
SUPPORTED_PROCESSORS := am62x am64x

# 仅在 DEVICE 匹配时编译
ifeq (,$(findstring $(DEVICE),$(SUPPORTED_PROCESSORS)))
    BUILD_PROJECT := n
endif
```

---

## 实例分析

### 完整编译实例：rpmsg_echo_linux for AM62X

#### 1. 用户操作

```bash
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru
cd examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt
make clean
make
```

#### 2. 构建流程展开

**阶段 1: 配置加载**

```makefile
# 核心 makefile 包含 imports.mak
include ../../imports.mak

# 读取全局配置
DEVICE = am62x
BUILD_LINUX = y
CGT_TI_PRU_PATH = /home/zhangjiance/ti/ti-cgt-pru_2.3.3
...
```

**阶段 2: 参数定义**

```makefile
# 核心 makefile 定义
OUTPUT_NAME := rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw
MCU_HEX_NAME := pru0_load_bin.h
HEX_ARRAY_PREFIX := PRU0Firmware
FILES_PATH := .. ../../.. .
COMMAND_FILES := linker.cmd
PRU_VERSION := 3
EXPECTED_DEVICE := am62x

# 核心特定的编译器定义
DFLAGS := -DHOST_INT_BIT=30 -DTO_ARM_HOST=16 -DFROM_ARM_HOST=17 -DCHAN_PORT=30

# 包含共享规则
include $(OPEN_PRU_PATH)/pru_rules.mak
```

**阶段 3: 源码扫描**

```makefile
# pru_rules.mak 自动扫描
FILES_PATH = .. ../../.. .
# 在以下路径查找:
#   firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/  (.)
#   firmware/am62x-sk/pruss0_pru0_fw/             (..)
#   firmware/am62x-sk/                            (../../..)
#   firmware/                                     (../../..)

# 找到的源文件:
C_FILES = main.c resource_table.c
ASM_FILES = 

# 生成目标文件列表:
OBJECTS = generated/main.obj generated/resource_table.obj
```

**阶段 4: 编译**

```bash
# 编译 main.c
"/home/zhangjiance/ti/ti-cgt-pru_2.3.3/bin/clpru" \
    --include_path=/home/zhangjiance/ti/ti-cgt-pru_2.3.3/include \
    --include_path=/home/zhangjiance/Code/ti_am625/PRU/open-pru/source \
    --include_path=/home/zhangjiance/Code/ti_am625/PRU/open-pru/source/firmware/common \
    --include_path=/home/zhangjiance/Code/ti_am625/PRU/open-pru/source/include \
    --include_path=/home/zhangjiance/Code/ti_am625/PRU/open-pru/source/include/am62x \
    -v3 -O2 \
    --display_error_number \
    --asm_directory=generated \
    --obj_directory=generated \
    -g --endian=little \
    -DHOST_INT_BIT=30 -DTO_ARM_HOST=16 -DFROM_ARM_HOST=17 -DCHAN_PORT=30 \
    --stack_size=0x100 --heap_size=0x100 \
    --output_file=generated/main.obj \
    ../../../main.c

# 编译 resource_table.c
# ... (类似)
```

**输出**: `generated/main.obj`, `generated/resource_table.obj`

**阶段 5: 链接**

```bash
"/home/zhangjiance/ti/ti-cgt-pru_2.3.3/bin/clpru" \
    -v3 -O2 -z \
    generated/main.obj \
    generated/resource_table.obj \
    linker.cmd \
    -mgenerated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.map \
    --xml_link_info=generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw_linkInfo.xml \
    --display_error_number \
    --warn_sections \
    --reread_libs \
    --ram_model \
    --stack_size=0x100 \
    --heap_size=0x100 \
    -i/home/zhangjiance/ti/ti-cgt-pru_2.3.3/lib \
    --library=libc.a \
    --library=/home/zhangjiance/Code/ti_am625/PRU/open-pru/source/rpmsg/lib/rpmsg.lib \
    -o generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out
```

**输出**: 
- `generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out` (5988 字节)
- `generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.map`

**阶段 6: 后处理**

```bash
# 生成 hex 数组
"/home/zhangjiance/ti/ti-cgt-pru_2.3.3/bin/hexpru" \
    --diag_wrap=off \
    --array \
    --array:name_prefix=PRU0Firmware \
    -o generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h \
    generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out

# 添加版权头
cat /home/zhangjiance/Code/ti_am625/PRU/open-pru/source/firmware/pru_load_bin_copyright.h \
    generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h \
    > generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h.temp

mv generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h.temp \
   generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h

# MCU+ 项目不适用于 AM62X，跳过复制
```

**输出**: `generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.h`

#### 3. 生成的文件分析

**generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out**

```bash
$ file generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out
ELF 32-bit LSB executable, TI PRU, version 1 (SYSV), statically linked, not stripped

$ size generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out
   text    data     bss     dec     hex filename
   2020    3968       0    5988    1764 generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out
```

- **text**: 2020 字节代码
- **data**: 3968 字节数据（包括 RPMsg 缓冲区和资源表）
- **总计**: 5988 字节

**generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.map**（内存映射摘录）

```
GLOBAL SYMBOLS: SORTED BY Symbol Address

address    name
--------   ----
00000000   __TI_cinit_table
00000000   __TI_handler_table
00000000   __TI_pprof_out_hndl
00000000   __TI_prof_data_size
00000000   __TI_prof_data_start
00000000   _c_int00
...
00000714   main
...
00000924   pru_rpmsg_init
...
00001d00   resourceTable
...

MEMORY CONFIGURATION

         name            origin    length      used     unused   attr    fill
----------------------  --------  ---------  --------  --------  ----  --------
  PRU_IMEM              00000000   00004000  000007dc  00003824  R  X
  PRU0_DMEM_0           00000000   00002000  00000f84  0000107c  RW  
  PRU_SHAREDMEM         00010000   00008000  00000000  00008000  RW  
  ...
```

**生成的固件已可部署**:
```bash
scp generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out \
    root@192.168.7.2:/lib/firmware/am62x-pru0-fw
```

---

## 总结

### OpenPRU 构建系统的优势

1. **统一的接口**: 所有项目使用相同的 makefile 结构
2. **设备抽象**: 通过 `DEVICE` 配置自动适配不同处理器
3. **模块化**: 共享规则（pru_rules.mak）和项目特定配置分离
4. **灵活性**: 支持汇编、C、混合编程
5. **多目标**: 同时支持 Linux 和 MCU+ SDK
6. **错误防护**: 设备验证、依赖检查防止配置错误

### 关键文件作用总结

| 文件/目录 | 作用 |
|----------|------|
| `imports.mak` | 全局配置（设备、工具路径、构建选项） |
| `pru_rules.mak` | 共享编译规则（编译、链接、后处理） |
| `linker.cmd` | 内存布局和段分配 |
| `makefile` (各级) | 构建编排和依赖管理 |
| `source/include/<device>/` | 设备特定的寄存器定义 |
| `generated/*.out` | 最终可执行固件（ELF 格式） |
| `generated/*.h` | Hex 数组（用于 MCU+ 嵌入） |

### 固件部署路径

| 目标平台 | 部署方式 | 文件格式 |
|---------|---------|---------|
| Linux (A53) | `/lib/firmware/am62x-pru0-fw` | `.out` (ELF) |
| MCU+ (R5F) | 编译时嵌入 | `.h` (C 数组) |
| CCS 调试 | 直接加载 | `.out` (ELF) |

---

**文档版本**: 1.0  
**创建日期**: 2026-05-23  
**适用 OpenPRU 版本**: 最新版（支持 AM62X）
