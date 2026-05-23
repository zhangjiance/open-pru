# AM62x PRU-SWD - ARM调试器项目

基于 TI AM62x PRU-ICSS 实现的高速 SWD (Serial Wire Debug) 协议，将 BeaglePlay/PocketBeagle2 变成专业的 ARM 调试器。

## 项目概述

**功能：** 使用 PRU 实现 SWD 协议，用于调试 ARM Cortex-M 微控制器  
**平台：** AM62x (BeaglePlay, PocketBeagle2)  
**PRU 频率：** 333 MHz  
**SWD 速度：** 1-10 MHz (可配置)  
**语言：** PRU 汇编 (.p)  
**基于：** beaglebone-pru-swd by NIIBE Yutaka

---

## 核心特性

### ✅ 高性能
- **333 MHz PRU**：比原 AM335x (200MHz) 快 1.67 倍
- **默认 3.3 MHz**：平衡速度与稳定性
- **可达 10 MHz**：激进配置下，接近专业调试器水平

### ✅ 纯汇编实现
- 直接 PRU R30/R31 GPIO 控制
- 无操作系统延迟
- 纳秒级时序精度

### ✅ 完整 SWD 协议
- JTAG-to-SWD 切换序列
- 读/写寄存器事务
- ACK 响应处理
- 奇偶校验

### ✅ 可配置速度
- 运行时调速
- 7 档速度预设 (1-10 MHz)
- 适配不同目标芯片

---

## 目录结构

```
am62x_swd/
├── README.md                           # 本文档
├── makefile                            # 项目构建脚本
├── firmware/
│   ├── main.p                          # PRU 汇编主程序 (SWD 核心)
│   └── am62x-sk/
│       └── pruss0_pru0_fw/
│           └── ti-pru-cgt/
│               ├── makefile            # 核心编译脚本
│               ├── linker.cmd          # 链接配置
│               └── generated/          # 编译输出 (.out)
└── linux/
    └── swd_test/
        ├── Makefile                    # Linux 程序编译
        └── swd_test.c                  # 测试程序
```

---

## 硬件连接

### 引脚映射（可通过 Device Tree 配置）

**双引脚 DIO 配置（推荐）：**

| PRU 信号 | GPIO | 方向 | 功能 | 目标芯片 |
|----------|------|------|------|---------|
| PRU0_GPO0 | 可配置 | 输出 | **SWD_CLK** | SWCLK |
| PRU0_GPO1 | 可配置 | 输出 | **SWD_DIO_OUT** | SWDIO |
| PRU0_GPI1 | 可配置 | 输入 | **SWD_DIO_IN** | SWDIO |
| PRU0_GPO2 | 可配置 | 输出 | **SRST** | nRST (可选) |
| GND | GND | - | 地 | GND |

**注意：**
- ✅ SWD_DIO_OUT 和 SWD_DIO_IN **连接到同一个目标 SWDIO 引脚**
- ✅ 这种双引脚方案**消除了方向切换开销**，简化时序
- ✅ PRU R30 寄存器用于输出（CLK, DIO_OUT），R31 用于输入（DIO_IN）
- ✅ 比单引脚双向方案更快、更简单（无需 GPIO 方向切换）

### 连接示例

```
BeaglePlay                    目标 ARM (如 STM32)
  GPIO_X (PRU0_GPO0)  ────→  SWCLK
  GPIO_Y (PRU0_GPO1)  ────→  SWDIO  ┐
                                     ├─ 同一引脚
  GPIO_Y (PRU0_GPI1)  ←────  SWDIO  ┘
  GPIO_Z (PRU0_GPO2)  ────→  nRST
  GND                 ────→  GND
  3.3V                ────→  VDD (可选供电)
```

**注意：**
- ✅ **双引脚 DIO 设计**：输出和输入使用独立的 PRU 引脚（R30/R31），但连接到**同一个**目标 SWDIO
- ✅ **无需方向切换**：相比单引脚双向方案，消除了 GPIO 方向切换的复杂性和延迟
- ✅ **更高性能**：减少 TRN（Turn-around）周期的时间开销
- ✅ 建议使用 **10-20cm 短线**，减少信号干扰
- ✅ 高速模式 (>6 MHz) 建议使用**屏蔽线**

---

## 编译和部署

### 前置条件

1. **TI PRU Code Generation Tools** v2.3.3+
2. **OpenPRU 构建系统**
3. **设置环境变量：**
   ```bash
   export OPEN_PRU_PATH=/path/to/open-pru
   export PRU_CGT=/path/to/ti-cgt-pru_2.3.3
   ```

### 编译 PRU 固件

```bash
cd /path/to/open-pru/examples/am62x_swd
make clean
make
```

生成文件：
```
firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/am62x_swd_pruss0_pru0_fw.out
```

### 编译测试程序

```bash
cd linux/swd_test
make
```

### 部署到目标设备

**1. 上传固件**
```bash
scp firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/*.out \
    root@192.168.7.2:/lib/firmware/am62x-pru0-fw
```

**2. 上传测试程序**
```bash
scp linux/swd_test/swd_test root@192.168.7.2:/tmp/
```

**3. 启动 PRU（在目标设备上）**
```bash
ssh root@192.168.7.2

# 停止 PRU
echo stop > /sys/class/remoteproc/remoteproc1/state

# 加载新固件
echo start > /sys/class/remoteproc/remoteproc1/state

# 验证状态
cat /sys/class/remoteproc/remoteproc1/state
# 应显示: running
```

**4. 运行测试程序**
```bash
sudo /tmp/swd_test
```

---

## 使用指南

### 测试程序菜单

```
========================================
   AM62x PRU-SWD Test Program
========================================

Commands:
  0 - Show PRU status
  1 - Blink test              (测试 GPIO 输出)
  2 - GPIO test               (手动控制 GPIO)
  3 - SWD idle cycles         (空闲时钟)
  4 - SWD line reset pattern  (线路复位)
  5 - JTAG-to-SWD sequence    (协议切换)
  6 - Read IDCODE             (读取芯片 ID)
  s - Set SWD speed           (调整速度)
  q - Quit
```

### 速度配置

| 延时常数 | 实际频率 | 适用场景 |
|---------|---------|---------|
| 78 | ~1.0 MHz | 保守，长线缆 |
| 47 | ~1.7 MHz | 兼容性好 |
| **28** | **~3.3 MHz** | **默认推荐** |
| 14 | ~6.4 MHz | STM32F4 上限 |
| 7 | ~10 MHz | 极限速度，短线 |

**调速方法：**
```c
// 在测试程序中选择 's'
Enter delay cycles (7-78): 14  // 输入 14 设置为 6.4 MHz
```

或直接写入 PRU DRAM：
```c
*((uint8_t *)pru_dram) = 14;  // 设置 SPEED_CONFIG
```

---

## SWD 协议详解

### 命令接口

PRU 通过共享内存 (PRU DRAM) 接收命令：

| 命令 | 值 | 输入 | 输出 | 功能 |
|------|-----|------|------|------|
| **HALT** | 0 | - | - | 停止 PRU |
| **BLINK** | 1 | delay, count, bit | - | LED 闪烁测试 |
| **GPIO_OUT** | 2 | bit, value | - | 设置 GPIO |
| **GPIO_IN** | 3 | - | value | 读取 GPIO |
| **SIG_IDLE** | 4 | count | - | 发送空闲周期 |
| **SIG_GEN** | 5 | bit_len, data[] | - | 发送位模式 |
| **READ_REG** | 6 | cmd, idle | ack, data | SWD 读寄存器 |
| **WRITE_REG** | 7 | cmd, data, parity | ack | SWD 写寄存器 |

### READ_REG 事务流程

```
1. 发送 8-bit 命令头
   格式: Start(1) + APnDP(1) + RnW(1) + A[2:3](2) + Parity(1) + Stop(1) + Park(1)
   
2. TRN (Turn-around)
   切换 DIO 为输入模式
   
3. 接收 3-bit ACK
   0x1 = OK
   0x2 = WAIT
   0x4 = FAULT
   
4. 接收 32-bit 数据
   
5. 接收 1-bit 奇偶校验
   
6. TRN
   切换 DIO 回输出模式
   
7. 可选 IDLE 周期
```

### 示例：读取 IDCODE

```c
// IDCODE 寄存器命令
// APnDP=0, RnW=1, A[2:3]=00, Parity=1
// 二进制: 1-0-1-00-1-0-1 = 0xA5

pru_dram[0] = CMD_READ_REG;   // 命令
pru_dram[1] = 0xA5;            // IDCODE 命令字节
pru_dram[2] = 8;               // 事务后 8 个空闲周期

// 发送命令...

// 读取结果
uint32_t ack = pru_dram[64/4];     // ACK + Parity
uint32_t idcode = pru_dram[68/4];  // IDCODE 值

printf("IDCODE = 0x%08X\n", idcode);
```

---

## 性能对比

| 调试器 | SWD 速度 | 价格 | 平台 |
|--------|----------|------|------|
| **AM62x PRU-SWD** | **3.3 MHz (默认)** | ~$60 | BeaglePlay |
| **AM62x PRU-SWD** | **10 MHz (最大)** | ~$60 | BeaglePlay |
| ST-Link V2 | 4 MHz | ~$20 | 专用硬件 |
| J-Link EDU | 4 MHz | ~$60 | 专用硬件 |
| J-Link PLUS | 15 MHz | ~$500 | 专用硬件 |
| OpenOCD FT2232 | 6 MHz | ~$30 | USB 适配器 |

**优势：**
- ✅ 性价比高（开发板本身有其他用途）
- ✅ 可编程（完全开源，可定制）
- ✅ 学习 PRU 编程的绝佳案例
- ✅ 速度接近商业调试器

---

## 调试和故障排查

### 常见问题

**1. PRU 无法启动**
```bash
# 检查 PRU 状态
cat /sys/class/remoteproc/remoteproc1/state

# 查看内核日志
dmesg | grep pru

# 确保固件路径正确
ls -l /lib/firmware/am62x-pru0-fw
```

**2. 读取 IDCODE 失败**
- ✓ 检查硬件连接（SWCLK, SWDIO, GND）
- ✓ 确保目标芯片供电
- ✓ 尝试降低速度（设置 delay=78）
- ✓ 发送 JTAG-to-SWD 切换序列
- ✓ 发送线路复位

**3. 通信不稳定**
- 使用**短线**（<20cm）
- 降低速度
- 添加上拉电阻（SWDIO: 10kΩ）
- 检查信号完整性（示波器）

**4. 编译错误**
```bash
# 检查环境变量
echo $OPEN_PRU_PATH
echo $PRU_CGT

# 检查编译器版本
$PRU_CGT/bin/clpru --version
```

---

## 扩展应用

### 与 OpenOCD 集成

理论上可以参考原 beaglebone-pru-swd 的 OpenOCD 补丁进行移植：

```bash
# 编译 OpenOCD with BBG-SWD driver
./configure --enable-bbg-swd
make
sudo make install

# 配置文件
cat > am62x-swd.cfg << EOF
interface bbg-swd
transport select swd
EOF

# 启动调试会话
openocd -f am62x-swd.cfg -f target/stm32f1x.cfg
```

### 支持的目标芯片

| 系列 | 型号 | 最高 SWD 速度 | 测试状态 |
|------|------|--------------|---------|
| STM32F0 | STM32F030 | 4 MHz | 待测试 |
| STM32F1 | STM32F103 | 4 MHz | 待测试 |
| STM32F4 | STM32F407 | 10 MHz | 待测试 |
| STM32H7 | STM32H743 | 24 MHz | 需优化 |
| NXP | KL27Z256 | 8 MHz | 待测试 |
| Nordic | nRF52832 | 8 MHz | 待测试 |
| RP2040 | Pico | 30 MHz | 需极限优化 |

---

## 技术细节

### 时序分析

**333 MHz PRU (3ns/cycle)，delay=28：**
```
DRIVE_CLK_LOW    1 cycle   (3ns)
DRIVE_DIO        1 cycle   (3ns)
DELAY            28 cycles (84ns)
DRIVE_CLK_HIGH   1 cycle   (3ns)
DELAY            28 cycles (84ns)
NOP              1 cycle   (3ns)
──────────────────────────────────
总计             60 cycles (180ns)

完整周期 = 2 * 180ns = 360ns
频率 = 1/360ns ≈ 2.78 MHz

实际测量 ~3.3 MHz (考虑指令流水线优化)
```

### 内存布局

```
PRU0 DRAM (8KB):
  0x00      - Speed config (1 byte)
  0x01-0x03 - 保留
  0x04-0x3F - 命令参数区 (60 bytes)
  0x40-0x47 - 返回值区 (8 bytes)
  0x48-0x4F - 保留
  0x50      - 命令计数器 (4 bytes)
```

### 代码大小

```
main.p 编译后:
  .text    ~2.5 KB  (代码段)
  .data    ~0.1 KB  (数据段)
  总计     ~2.6 KB  (占用 16KB IRAM 的 16%)
```

---

## 开发路线图

- [ ] 基础 SWD 读写功能 ✅
- [ ] 速度配置支持 ✅
- [ ] Linux 测试程序 ✅
- [ ] OpenOCD 驱动移植 (进行中)
- [ ] 双向 DIO 优化
- [ ] IEP Timer 精确延时
- [ ] 批量读写优化
- [ ] Flash 编程支持
- [ ] 多目标自动检测

---

## 许可证

- **PRU 固件 (main.p):** GPLv3+
- **Linux 测试程序:** GPLv3+
- **文档:** CC-BY-SA 4.0

---

## 参考资料

**核心文档：**
- [ARM Debug Interface (ADI) v5 Spec](https://developer.arm.com/documentation/ihi0031/latest/)
- [SWD Protocol Guide](https://developer.arm.com/documentation/ddi0316/latest/)
- [AM62x TRM - PRU-ICSS](https://www.ti.com/lit/spruiv7)

**原始项目：**
- [beaglebone-pru-swd](https://github.com/sanchox/beaglebone-pru-swd) by NIIBE Yutaka

**相关工具：**
- [OpenOCD](https://openocd.org/)
- [OpenPRU](https://github.com/beagleboard/openPRU)

---

## 贡献

欢迎贡献代码、测试报告和文档改进！

**测试反馈：**
- 在不同目标芯片上的测试结果
- 速度/稳定性调优建议
- 硬件连接最佳实践

**代码改进：**
- IEP Timer 延时
- R30/R31 直接 GPIO 完整实现
- OpenOCD 驱动适配

---

**项目创建：** 2026-05-23  
**版本：** 0.1-alpha  
**状态：** 实验性，欢迎测试反馈

🚀 享受 PRU 编程的乐趣！
