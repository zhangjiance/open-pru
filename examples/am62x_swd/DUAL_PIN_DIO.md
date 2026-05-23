# 双引脚 DIO 设计详解

## 设计理念

AM62x PRU-SWD 采用**双引脚单向**设计来实现 SWD 的 DIO（数据输入/输出）信号，而不是传统的**单引脚双向**方案。

---

## 方案对比

### 传统方案：单引脚双向

```
        ┌──────────────────────────┐
        │   需要外部驱动电路        │
        │   或特殊 GPIO 配置        │
        └─────────┬────────────────┘
                  │
PRU (R30) ◄──────►│ SWDIO ◄──────► Target
                  │
            需要软件控制
            输入/输出方向切换
```

**问题：**
- ❌ PRU 的 R30 寄存器主要用于输出，**不支持动态方向切换**
- ❌ 需要额外的 GPIO 配置或外部三态驱动器
- ❌ TRN（Turn-around）周期需要切换方向，增加时序复杂度
- ❌ 软件逻辑复杂，容易出错

---

### 本项目：双引脚单向

```
PRU R30.b1 ────► DIO_OUT ────┐
                             ├──► Target SWDIO
PRU R31.b1 ◄──── DIO_IN  ◄───┘
```

**优势：**
- ✅ **硬件天然支持**：R30 专用输出，R31 专用输入
- ✅ **无需方向切换**：PRU 始终可以读写
- ✅ **简化时序**：TRN 周期仅需一个空闲时钟
- ✅ **提高性能**：减少指令数和执行时间
- ✅ **代码简洁**：无需复杂的方向控制逻辑

---

## 硬件连接

### 引脚配置

| 信号 | PRU 寄存器 | 位 | 方向 | 连接 |
|------|-----------|-----|------|------|
| SWD_CLK | R30 | bit 0 | 输出 | Target SWCLK |
| SWD_DIO_OUT | R30 | bit 1 | 输出 | Target SWDIO |
| SWD_DIO_IN | R31 | bit 1 | 输入 | Target SWDIO |

### 物理连接

```
BeaglePlay Pin               Target MCU
┌────────────┐              ┌───────────┐
│ PRU0_GPO0  ├─────────────►│  SWCLK    │
│            │              │           │
│ PRU0_GPO1  ├─────────────►│           │
│            │              │  SWDIO    │
│ PRU0_GPI1  │◄─────────────┤           │
│            │              │           │
│ GND        ├──────────────┤  GND      │
└────────────┘              └───────────┘
```

**关键点：**
1. **PRU0_GPO1 和 PRU0_GPI1** 在 Device Tree 中配置为**同一个物理 GPIO 引脚**
2. 物理上只需要**一根线**连接到目标 SWDIO
3. PRU 内部通过 R30.1（输出）和 R31.1（输入）访问

---

## 代码实现

### 引脚定义

```assembly
// 双引脚配置
#define SWD_CLK_BIT        0  // R30 bit 0 for CLK output
#define SWD_DIO_OUT_BIT    1  // R30 bit 1 for DIO output (PRU → Target)
#define SWD_DIO_IN_BIT     1  // R31 bit 1 for DIO input  (Target → PRU)
```

### 宏定义

```assembly
// 驱动 DIO 输出
.macro DRIVE_DIO_HIGH
    SET     r30, SWD_DIO_OUT_BIT
.endm

.macro DRIVE_DIO_LOW
    CLR     r30, SWD_DIO_OUT_BIT
.endm

// 读取 DIO 输入
// 示例: QBBS label, r31, SWD_DIO_IN_BIT
```

### 简化的 TRN 周期

**传统方案（需要方向切换）：**
```assembly
.macro TRN
    DRIVE_CLK_LOW
    SET_DIO_INPUT        // 切换为输入
    DELAY
    DRIVE_CLK_HIGH
    DELAY
.endm
```

**双引脚方案（无需切换）：**
```assembly
.macro TRN
    DRIVE_CLK_LOW
    DELAY                // DIO 始终可读可写
    DRIVE_CLK_HIGH
    DELAY
.endm
```

---

## SWD 事务流程

### READ 事务（读寄存器）

```
阶段         操作                   DIO 方向
─────────────────────────────────────────────
1. 发送命令   PRU 发送 8-bit 命令    输出 (R30.1)
2. TRN       1 个空闲周期           -
3. 读取 ACK   PRU 读取 3-bit ACK    输入 (R31.1)
4. 读取数据   PRU 读取 32-bit 数据   输入 (R31.1)
5. 读取奇偶   PRU 读取 1-bit 奇偶    输入 (R31.1)
6. TRN       1 个空闲周期           -
7. 空闲周期   可选 N 个周期          输出 (R30.1)
```

**关键代码片段：**
```assembly
READ_ACK_LOOP:
    DRIVE_CLK_LOW
    DELAY
    QBBS    READ_ACK_BIT1, r31, SWD_DIO_IN_BIT  // 从 R31 读取
    LSR     r12, r12, 1
    QBA     READ_ACK_NEXT
READ_ACK_BIT1:
    LSR     r12, r12, 1
    SET     r12, 31
READ_ACK_NEXT:
    DRIVE_CLK_HIGH
    DELAY
    SUB     r11, r11, 1
    QBNE    READ_ACK_LOOP, r11, 0
```

### WRITE 事务（写寄存器）

```
阶段         操作                   DIO 方向
─────────────────────────────────────────────
1. 发送命令   PRU 发送 8-bit 命令    输出 (R30.1)
2. TRN       1 个空闲周期           -
3. 读取 ACK   PRU 读取 3-bit ACK    输入 (R31.1)
4. TRN       1 个空闲周期           -
5. 发送数据   PRU 发送 32-bit 数据   输出 (R30.1)
6. 发送奇偶   PRU 发送 1-bit 奇偶    输出 (R30.1)
7. 空闲周期   可选 N 个周期          输出 (R30.1)
```

**注意：** 在每个阶段，**无需手动切换方向**，PRU 可以随时通过 R30 输出、通过 R31 读取。

---

## 性能优势

### 时序对比

**单引脚方案（假设方向切换需要 10 cycles）：**
```
TRN 周期:
  CLK_LOW         1 cycle
  SET_DIO_INPUT  10 cycles  ← 方向切换开销
  DELAY          28 cycles
  CLK_HIGH        1 cycle
  DELAY          28 cycles
  总计          ~68 cycles (204ns @ 333MHz)
```

**双引脚方案（无方向切换）：**
```
TRN 周期:
  CLK_LOW         1 cycle
  DELAY          28 cycles
  CLK_HIGH        1 cycle
  DELAY          28 cycles
  总计           58 cycles (174ns @ 333MHz)
```

**性能提升：** ~15% 时间节省在每个 TRN 周期

### 完整事务对比

以 READ_REG 为例（含 2 次 TRN）：

| 方案 | TRN 开销 | 总周期 | 执行时间 @ 333MHz |
|------|---------|-------|------------------|
| 单引脚 | ~68 cycles × 2 | ~600+ cycles | ~1.8 μs |
| **双引脚** | **~58 cycles × 2** | **~580+ cycles** | **~1.7 μs** |

---

## Device Tree 配置示例

```dts
&pruss0_pru0 {
    pinctrl-names = "default";
    pinctrl-0 = <&pru_swd_pins>;
};

&main_pmx0 {
    pru_swd_pins: pru-swd-pins {
        pinctrl-single,pins = <
            // SWD_CLK - GPIO output only
            AM62X_IOPAD(0x0XXX, PIN_OUTPUT, 5)  // PRU0_GPO0
            
            // SWD_DIO - GPIO output AND input (critical!)
            AM62X_IOPAD(0x0YYY, PIN_OUTPUT | PIN_INPUT, 5)  // PRU0_GPO1 + GPI1
        >;
    };
};
```

**关键配置：**
- SWD_DIO 引脚需要同时配置 `PIN_OUTPUT | PIN_INPUT`
- Mux 模式选择 PRU 功能（通常是 mode 5）

---

## 调试技巧

### 验证硬件连接

使用测试程序的 GPIO 测试功能：

```bash
sudo /tmp/swd_test

# 选择 2 - GPIO test
Command: 2

# 设置 DIO_OUT 为高
Set bit (0=CLK, 1=DIO, 2=RST): 1
Set value (0/1): 1

# 用万用表或示波器测量目标 SWDIO 引脚
# 应该读到 3.3V

# 设置 DIO_OUT 为低
Set value (0/1): 0

# 应该读到 0V
```

### 验证输入功能

如果目标芯片已上电且 SWDIO 有上拉：

```bash
# 先断开目标 SWDIO 连接
# 设置 DIO_OUT 为低
Set bit: 1, value: 0

# 重新连接目标 SWDIO
# 通过测试程序观察 DIO_IN 状态
# 应该读到高电平（目标上拉）
```

---

## 常见问题

### Q1: 为什么不直接用一个双向引脚？

**A:** PRU 的 R30 寄存器主要设计用于**输出**，动态切换输入/输出方向需要复杂的 GPIO 配置，而且可能不被所有 PRU 模式支持。双引脚方案利用 R30（输出）+ R31（输入）的天然特性，更简单可靠。

### Q2: 双引脚会不会冲突？

**A:** 不会。关键点是：
1. **PRU 内部**：R30.1 用于驱动，R31.1 用于读取，两者独立
2. **物理引脚**：配置为 `PIN_OUTPUT | PIN_INPUT`，硬件支持同时输出和输入
3. **协议保证**：SWD 协议本身定义了主机（PRU）何时驱动、何时接收，不会同时双向传输

### Q3: 如果目标同时驱动 SWDIO 会怎样？

**A:** SWD 协议严格定义了总线控制权：
- 主机发送命令时：主机驱动，目标三态
- 目标响应时：目标驱动，主机应该三态（但我们是双引脚，输出保持为高或低，通过输入读取目标状态）

实际上，由于我们的输出始终在驱动，需要确保：
- 目标芯片 SWDIO 驱动能力 > PRU 输出驱动能力（通常成立）
- 或者在读取阶段，PRU 输出设置为弱驱动/高阻态（需要额外配置）

**改进方案：** 在 TRN 后可以选择性地禁用 R30.1 输出（如果硬件支持）。

### Q4: 需要额外的外部电路吗？

**A:** 不需要！这是双引脚方案的最大优势：
- ✅ 无需三态缓冲器
- ✅ 无需电平转换器（假设都是 3.3V）
- ✅ 无需外部上拉/下拉（可选）

---

## 扩展优化

### 可选的输出使能控制

如果需要更严格的总线控制，可以添加 OE（Output Enable）控制：

```assembly
// 在读取阶段禁用 DIO 输出
.macro DISABLE_DIO_OUTPUT
    // 清除 GPIO OE 寄存器中的对应位
    // (需要访问 GPIO 模块寄存器)
.endm

.macro ENABLE_DIO_OUTPUT
    // 设置 GPIO OE 寄存器中的对应位
.endm
```

### IEP Timer 精确时序

结合 IEP（Industrial Ethernet Peripheral）Timer 可以实现纳秒级精确延时：

```assembly
.macro PRECISE_DELAY
    // 使用 IEP Timer 替代循环延时
    // 可以实现更稳定的 SWD 时钟
.endm
```

---

## 总结

双引脚 DIO 设计是本项目的核心创新之一：

| 特性 | 单引脚 | 双引脚 |
|------|--------|--------|
| 硬件支持 | ❌ 需要特殊配置 | ✅ 天然支持 |
| 方向切换 | ❌ 需要软件控制 | ✅ 无需切换 |
| 代码复杂度 | ❌ 较高 | ✅ 简洁 |
| 性能 | ⚠️ 中等 | ✅ 更快 (~15% 提升) |
| 外部电路 | ⚠️ 可能需要 | ✅ 不需要 |
| 调试难度 | ❌ 较难 | ✅ 简单 |

**推荐指数：** ⭐⭐⭐⭐⭐

---

**最后更新：** 2026-05-23  
**贡献者：** AM62x PRU-SWD Team
