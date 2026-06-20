# AM62x PRU-SWD — ARM Debug Probe via PRU

基于 TI AM62x PRU 实现的 SWD 调试适配器，配合 OpenOCD `dapdirect_swd` 驱动，
将 PocketBeagle2 / BeaglePlay 变成 ARM Cortex-M 调试器。

## 架构

```
OpenOCD (ARM A53, Linux)
  └─ dapdirect_swd transport
       └─ am62x_pru_swd.c (dap_ops: connect, queue_dp_read/write, queue_ap_read/write, run)
            └─ 共享内存 mailbox @ PRU DRAM 0x30041000
                 └─ PRU0 firmware (main.asm + swd.asm, 200MHz PRU)
                      └─ SWD bus (CLK + DIO GPIO bit-bang)
```

## Mailbox 协议

| Word | 名称 | 方向 | 说明 |
|------|------|------|------|
| 0 | CMD | ARM→PRU | 命令码 (0-6) |
| 1 | PARAM | ARM→PRU | 寄存器号 或 (AP号<<8)\|reg |
| 2 | WDATA | ARM→PRU | 写数据 |
| 4 | RDATA | PRU→ARM | 读数据 |
| 5 | ACK | PRU→ARM | SWD ACK (1=OK, 2=WAIT, 4=FAULT) |
| 6 | STATUS | PRU→ARM | 0=成功, 1=失败 |
| 7 | SPEED | ARM→PRU | DELAY 循环次数 (SWD 时钟) |
| 9 | RDBUFF | PRU→ARM | AP 读自动缓存的 RDBUFF 值 |
| 10 | FLAGS | PRU→ARM | bit0=1 表示 RDBUFF 有效 |
| 16 | DOORBELL | ARM↔PRU | ARM 写序列号，PRU 清 0 表示完成 |

**协议**：ARM 写 CMD/PARAM/WDATA/DB → PRU 轮询 DB → 执行 → 写 RDATA/ACK/STATUS → 清 DB → ARM 读结果。同步阻塞，单槽位。

## PRU 命令 (0-6)

| 码 | 命令 | PARAM | WDATA | → RDATA | PRU 内部 |
|----|------|-------|-------|---------|---------|
| 0 | CONNECT | - | - | DPIDR | line reset + J2S + 读 DPIDR + ABORT 清 sticky |
| 1 | DP_RD | reg | - | value | reg[3:0]==4 自动写 SELECT (bankselect) |
| 2 | DP_WR | reg | data | - | 同上 |
| 3 | AP_RD | (ap<<8)\|reg | - | pipelined | 自动 SELECT(APSEL+APBANKSEL) + 读 RDBUFF |
| 4 | AP_WR | (ap<<8)\|reg | data | - | 自动 SELECT |
| 5 | LR | - | - | - | line reset, 清 SELECT 缓存 |
| 6 | J2S | - | - | - | JTAG-to-SWD, 清 SELECT 缓存 |

## PRU firmware (main.asm + swd.asm)

### SWD 协议层 (swd.asm)
- `swd_read_reg` / `swd_write_reg`：完整 SWD 读写事务
- `tx_bits` / `rx_bits`：8/32/1-bit 收发
- `turnaround_input` / `turnaround_output`：TRN 方向切换（1 个 SWD 时钟周期）
- 写操作 parity 后 1 个 idle 周期，读操作 TRN_out 后释放总线

### DAP 层 (main.asm)
- **`swd_mkcmd`**：从 reg + APnDP + RnW 构造 8-bit SWD 命令字节
  - bit0=START, bit1=APnDP, bit2=RnW, bit3-4=A[3:2], bit5=PARITY, bit7=PARK
- **`swd_ap_sel`**：AP SELECT 管理，保留 DPBANKSEL 缓存
- **`swd_dp_bs`**：DP bankselect（reg 4 写 SELECT）
- **SELECT 缓存 (r9/r10)**：跨命令保持，减少冗余 SELECT 写
- **RDBUFF 自动缓存**：AP 读后自动读 RDBUFF 存 `M_RDBUFF`

### 寄存器约定
- `r3.w2`：C-callable 返回地址 (jal r3.w2)
- `r28.w0`：内部子程序返回地址 (jal r28.w0)
- `r1-r13`：被 `swd_write_reg` 保留
- `r5/r6`：用于在 `swd_ap_sel`/`swd_dp_bs` 调用前后保存参数

## ARM OpenOCD 驱动 (am62x_pru_swd.c)

### dap_ops 接口

```
connect        → CMD_CONNECT → dap_dp_init(dap) [框架函数，走 queue_dp_write/read + run]
send_sequence  → CMD_LR 或 CMD_J2S
queue_dp_read  → CMD_DP_RD (DP_RDBUFF 走缓存)
queue_dp_write → CMD_DP_WR (CTRL_STAT 屏蔽 CORUNDETECT)
queue_ap_read  → CMD_AP_RD → 框架 dap_run 时 pru_run 读 RDBUFF 回填 *data
queue_ap_write → CMD_AP_WR
queue_ap_abort → CMD_DP_WR(DP_ABORT, 0x1E)
run            → 检查 M_FLAGS → 有则缓存 RDBUFF → 有 pending AP read 则读 RDBUFF
```

### Pipeline 管理
SWD AP 读是 pipelined：AP read 返回 stale 值，真值在 RDBUFF。`swd_dap_ops` 用 `dap->last_read` + `swd_finish_read` 实现。
我们使用 `pending_ap_read` 指针：`queue_ap_read` 保存 data 指针 → `run()` 发 `CMD_DP_RD(RDBUFF)` 回填。

### CORUNDETECT
STM32F0 不支持 CORUNDETECT，写 CTRL_STAT 时屏蔽（匹配 ST-Link 行为）。

## 构建 & 部署

```bash
# PRU firmware
cd open-pru/examples/am62x_swd/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt
make clean && make
scp generated/am62x_swd_pruss0_pru0_fw.out root@192.168.7.2:/lib/firmware/am62x-pru0-fw

# OpenOCD
cd openocd
make -j16
scp src/openocd root@192.168.7.2:/tmp/openocd

# 重启 PRU
ssh root@192.168.7.2
echo stop > /sys/class/remoteproc/remoteproc1/state
echo start > /sys/class/remoteproc/remoteproc1/state

# 测试
sudo /tmp/openocd -s /home/beagle/openocd/share/openocd/scripts \
  -f interface/am62x-pru-swd.cfg -f target/stm32f0x.cfg -d3
```

## 当前进展

| 阶段 | 状态 |
|------|------|
| SWD 协议层 (tx/rx/TRN/parity/idle) | ✅ 正常 |
| DP 读写 (IDCODE, CTRL/STAT, SELECT, ABORT) | ✅ 正常 |
| dap_dp_init (power-up + CDBGPWRUPACK/CSYSPWRUPACK poll) | ✅ 正常 |
| MEM-AP 发现 (dap_find_get_ap → IDR=0x04770021) | ✅ 正常 |
| CSW 写 (0xA2000012) | ✅ 正常 |
| TAR 写 / DRW 读 | ❌ TAR 写 ACK=6，排查中 |

## 已知问题

1. **TAR AP 写失败 (ACK=6)**：CSW 写成功后 TAR 写 target 返回异常 ACK。
   分析：正常波形 CSW→TAR 之间 `swd_queue_ap_write` 调 `check_sync` 做 idle，
   当前正在验证 `pru_queue_ap_write` 末尾加 RDBUFF 读是否解决。

2. **寄存器冲突**：`swd_ap_sel`/`swd_dp_bs` 内部 `jal r3.w2, swd_write_reg` 会
   破坏 `r28.w0`、`r1`、`r25`、`r26`。已修复：用 r1 保存 r28.w0，用 r5/r6 保存参数。

3. **SWD 命令 bit 布局**：之前 START/PARK/PARITY 位置错误。已修正为与 OpenOCD
   `swd_cmd()` 一致：bit0=START, bit5=PARITY, bit7=PARK。

## 硬件连接

| PRU 引脚 | 功能 | 目标 |
|----------|------|------|
| PRU0_GPO8 (R30.8) | SWCLK | SWCLK |
| PRU0_GPO9 (R30.9) | SWDIO (out) | SWDIO |
| PRU0_GPI9 (R31.9) | SWDIO (in) | SWDIO |
| GND | 地 | GND |

## 文件结构

```
am62x_swd/
├── firmware/
│   ├── main.asm       # PRU 主循环 + DAP 命令处理
│   ├── swd.asm        # SWD 协议层函数
│   └── am62x-sk/pruss0_pru0_fw/ti-pru-cgt/
│       ├── makefile / linker.cmd
│       └── generated/*.out
├── linux/swd_test/    # (old) standalone test
├── makefile
├── deploy_swd.sh      # 自动部署脚本
└── README.md

openocd/src/jtag/drivers/
└── am62x_pru_swd.c    # OpenOCD dap_ops 驱动
```
