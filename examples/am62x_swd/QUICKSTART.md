# AM62x PRU-SWD 快速开始

## 5分钟快速部署

### 前提条件
- ✅ BeaglePlay/PocketBeagle2 (AM62x) 已连接
- ✅ IP 地址: 192.168.7.2
- ✅ SSH root 访问
- ✅ OpenPRU 环境已配置

### 一键部署

```bash
cd /path/to/open-pru/examples/am62x_swd
./deploy_swd.sh
```

脚本自动完成：
1. ✓ 编译 PRU 固件
2. ✓ 编译测试程序
3. ✓ 上传到目标设备
4. ✓ 重启 PRU
5. ✓ 验证状态

### 运行测试

```bash
ssh root@192.168.7.2
sudo /tmp/swd_test
```

测试菜单：
```
1 - Blink test      # 测试 GPIO 输出
4 - Line reset      # 发送 SWD 线路复位
5 - JTAG-to-SWD     # 切换到 SWD 模式
6 - Read IDCODE     # 读取芯片 ID (需要连接目标)
```

---

## 硬件连接（必读！）

连接目标 ARM 芯片前，需要配置 GPIO：

```bash
# 在 BeaglePlay 上执行 (示例，需根据实际引脚调整)
# 假设使用 P8_11, P8_12 作为 SWD_CLK, SWD_DIO

# 配置为 PRU 模式
config-pin P8.11 pruout   # SWD_CLK
config-pin P8.12 pruout   # SWD_DIO_OUT
config-pin P8.12 pruin    # SWD_DIO_IN (同一引脚)
```

**双引脚 DIO 连接方式：**
```
BeaglePlay                STM32F103
  P8_11 (CLK_OUT)     --> SWCLK
  P8_12 (DIO_OUT)     --> SWDIO  ┐
                                  ├─ 同一物理引脚
  P8_12 (DIO_IN)      <-- SWDIO  ┘
  GND                 --> GND
```

⚠️ **重要说明：**
- ✅ **DIO_OUT 和 DIO_IN 连接到目标的同一个 SWDIO 引脚**
- ✅ PRU 内部使用 R30 输出和 R31 输入，无需物理方向切换
- ✅ 这种设计消除了单引脚双向的复杂性，性能更优

---

## 速度调整

默认速度: **3.3 MHz**

调整方法：
```bash
# 在测试程序中按 's'
Enter delay cycles: 14  # 6.4 MHz
```

| 延时 | 速度 | 适用 |
|-----|------|-----|
| 78  | 1 MHz | 长线、干扰环境 |
| **28** | **3.3 MHz** | **默认推荐** |
| 14  | 6.4 MHz | 短线、STM32F4 |
| 7   | 10 MHz | 极限（需优质连接） |

---

## 故障排查

### PRU 未运行
```bash
cat /sys/class/remoteproc/remoteproc1/state
# 如果不是 "running":
echo start > /sys/class/remoteproc/remoteproc1/state
```

### 读取 IDCODE 失败
1. 检查硬件连接
2. 确保目标芯片供电
3. 先执行 "4 - Line reset"
4. 再执行 "5 - JTAG-to-SWD"
5. 最后执行 "6 - Read IDCODE"
6. 如果仍失败，降低速度到 78

### 编译错误
```bash
# 检查环境变量
echo $OPEN_PRU_PATH
echo $PRU_CGT

# 如果未设置:
export OPEN_PRU_PATH=/path/to/open-pru
export PRU_CGT=/path/to/ti-cgt-pru_2.3.3
```

---

## 支持的芯片

| 芯片系列 | 测试状态 | 推荐速度 |
|---------|---------|---------|
| STM32F0/F1 | 待测试 | 3.3 MHz |
| STM32F4 | 待测试 | 6.4 MHz |
| STM32H7 | 待测试 | 10 MHz |
| NXP KL27 | 待测试 | 6.4 MHz |
| nRF52 | 待测试 | 6.4 MHz |

---

## 下一步

### 进阶使用
- 阅读完整 [README.md](README.md)
- 学习 SWD 协议细节
- 尝试不同速度配置

### 开发调试
- 修改 [firmware/main.p](firmware/main.p) - PRU 汇编代码
- 修改 [linux/swd_test/swd_test.c](linux/swd_test/swd_test.c) - 测试程序
- 重新运行 `./deploy_swd.sh`

### 集成 OpenOCD
- 参考原 beaglebone-pru-swd 的补丁
- 移植驱动到 AM62x 平台

---

## 项目文件

```
am62x_swd/
├── README.md               # 完整文档
├── QUICKSTART.md          # 本文档
├── deploy_swd.sh          # 自动部署脚本
├── makefile               # 项目构建
├── firmware/
│   └── main.p             # PRU 汇编 (520 行)
└── linux/
    └── swd_test/
        └── swd_test.c     # 测试程序 (387 行)
```

总代码量: **1244 行**

---

**快速反馈：** 遇到问题？欢迎提 Issue 或 PR！

🚀 开始你的 ARM 调试之旅吧！
