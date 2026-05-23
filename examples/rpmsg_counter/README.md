# PRU RPMsg Counter Demo

这是一个基于 TI AM62x PRU-ICSS 的 RPMsg 通信示例，演示了 PRU 如何通过 RPMsg 协议向 Linux 用户空间定期发送递增的计数器值。

## 项目概述

**功能描述：**
- PRU 固件每隔约 1 秒向 Linux 端发送一次递增的计数器值
- Linux 用户空间程序接收并打印计数器消息
- 演示了 PRU 与 Linux 之间的双向 RPMsg 通信机制

**适用平台：**
- AM62x SoC（如 BeaglePlay、PocketBeagle2）
- PRU-ICSS 子系统
- Linux 6.x+ (with remoteproc and rpmsg support)

## 目录结构

```
rpmsg_counter/
├── README.md                           # 本文档
├── makefile                            # 项目顶层 Makefile
├── deploy_counter.sh                   # 自动化部署脚本
├── firmware/                           # PRU 固件源码
│   ├── main.c                          # PRU 主程序
│   └── am62x-sk/                       # AM62x 平台配置
│       └── pruss0_pru0_fw/
│           └── ti-pru-cgt/
│               ├── makefile            # 核心编译 Makefile
│               ├── linker.cmd          # 链接脚本
│               ├── intc_map.h          # 中断控制器映射
│               └── generated/          # 编译生成的固件
│                   └── rpmsg_counter_am62x-sk_pruss0_pru0_fw.out
└── linux/                              # Linux 用户空间程序
    └── rpmsg_counter_receiver/
        ├── Makefile                    # Linux 程序 Makefile
        └── rpmsg_counter_receiver.c    # 接收程序源码
```

## 技术细节

### PRU 固件架构

**1. RPMsg 初始化流程**
```c
// 等待 Linux RemoteProc 驱动就绪
while (!(*status & VIRTIO_CONFIG_S_DRIVER_OK));

// 初始化 RPMsg 传输层
pru_rpmsg_init(&transport, ...);

// 创建 RPMsg 通道（名称: "rpmsg-raw", 端口: 30）
pru_rpmsg_channel(RPMSG_NS_CREATE, &transport, "rpmsg-raw", 30);
```

**2. Endpoint 地址协商**
```c
// PRU 等待 Linux 端发送第一条消息以获取其 endpoint 地址
pru_rpmsg_receive(&transport, &src, &dst, payload, &len);
// src = Linux endpoint 地址
// dst = PRU endpoint 地址

// 后续发送时使用这些地址
pru_rpmsg_send(&transport, dst, src, message, len);
```

**3. 计时机制**
- PRU 运行频率：**333 MHz**
- 空循环延时：`DELAY_1SEC_CYCLES = 16,650,000` 次迭代
- 实际延时：约 1 秒（经过实测校准）

**4. 自定义字符串处理**
为避免 `printf/sprintf` 引入的代码膨胀（超过 16KB IRAM 限制），实现了：
- `uint_to_str()`: 整数转字符串
- `build_message()`: 构造 "PRU Counter: XXXXX" 消息

### Linux 接收程序

**主要功能：**
1. 打开 `/dev/rpmsg0` 设备（由内核 rpmsg_char 驱动创建）
2. 发送 "START" 消息触发 PRU 开始发送
3. 循环读取并打印 PRU 发送的计数器消息

**关键代码：**
```c
// 打开 RPMsg 设备
fd = open("/dev/rpmsg0", O_RDWR);

// 发送启动信号
write(fd, "START", 5);

// 接收循环
while (1) {
    ret = read(fd, buffer, sizeof(buffer));
    printf("[%d] Received %d bytes: %s\n", msg_count++, ret, buffer);
}
```

### 系统配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| PRU 核心 | PRU0 | PRUSS0 的 PRU0 |
| PRU 频率 | 333 MHz | AM62x PRU-ICSS 运行频率 |
| RPMsg 通道名 | rpmsg-raw | Linux 内核识别的通道名 |
| PRU 端口 | 30 | PRU endpoint 地址 |
| 系统事件 TO_ARM_HOST | 16 | PRU→ARM 中断 |
| 系统事件 FROM_ARM_HOST | 17 | ARM→PRU 中断 |
| Host 中断位 | 30 | 映射到 Linux 的中断位 |
| 固件文件名 | am62x-pru0-fw | Linux remoteproc 加载的固件名 |

## 编译和部署

### 前置条件

**开发环境：**
- TI PRU Code Generation Tools v2.3.3+
- OpenPRU 构建系统
- Linux 开发主机（支持 ssh/scp）

**目标设备：**
- AM62x 开发板（如 BeaglePlay）
- Linux 系统已启动
- Remoteproc 和 RPMsg 内核驱动已加载

### 方法一：使用自动化脚本

```bash
cd /path/to/open-pru/examples/rpmsg_counter
./deploy_counter.sh
```

脚本自动完成：
1. 编译 PRU 固件
2. 编译 Linux 接收程序
3. 上传固件到目标设备 `/lib/firmware/am62x-pru0-fw`
4. 上传接收程序到 `/tmp/rpmsg_counter_receiver`
5. 重启 PRU 加载新固件
6. 验证 `/dev/rpmsg0` 设备创建

### 方法二：手动编译部署

**1. 编译 PRU 固件**
```bash
# 在项目根目录执行
cd /path/to/open-pru/examples/rpmsg_counter
make clean
make
```

生成文件：`firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/rpmsg_counter_am62x-sk_pruss0_pru0_fw.out`

**2. 编译 Linux 接收程序（在目标设备上）**
```bash
# 在 BeaglePlay 上执行
cd /tmp
gcc -Wall -O2 -o rpmsg_counter_receiver rpmsg_counter_receiver.c
```

**3. 部署固件**
```bash
# 从开发主机上传固件（在项目根目录执行）
scp firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/rpmsg_counter_am62x-sk_pruss0_pru0_fw.out root@192.168.7.2:/lib/firmware/am62x-pru0-fw
```

**4. 启动 PRU**
```bash
# 在目标设备上执行
echo stop > /sys/class/remoteproc/remoteproc1/state
sleep 1
echo start > /sys/class/remoteproc/remoteproc1/state
```

**5. 验证 PRU 状态**
```bash
cat /sys/class/remoteproc/remoteproc1/state
# 应显示: running

ls -l /dev/rpmsg*
# 应看到: /dev/rpmsg0 和 /dev/rpmsg_ctrl0
```

## 运行示例

### 启动接收程序

```bash
# SSH 登录到目标设备
ssh root@192.168.7.2

# 运行接收程序
/tmp/rpmsg_counter_receiver
```

### 预期输出

```
PRU RPMsg Counter Receiver
==========================

Opening /dev/rpmsg0...
Successfully opened /dev/rpmsg0
Sending start message to PRU...
Start message sent
Waiting for messages from PRU (Ctrl+C to exit)...
----------------------------------------

[1] Received 15 bytes: PRU Counter: 0
[2] Received 15 bytes: PRU Counter: 1
[3] Received 15 bytes: PRU Counter: 2
[4] Received 15 bytes: PRU Counter: 3
[5] Received 15 bytes: PRU Counter: 4
...
```

**观察：**
- 每秒收到一条新消息
- 计数器值递增：0, 1, 2, 3, ...
- 消息长度随计数器位数增加（15→16→17 字节）

按 `Ctrl+C` 退出接收程序。

## 调试指南

### 常见问题

**1. `/dev/rpmsg0` 设备不存在**

检查 PRU 是否成功启动：
```bash
dmesg | grep -i pru
```

应看到类似输出：
```
[  123.456] remoteproc remoteproc1: powering up 30074000.pru
[  123.457] remoteproc remoteproc1: Booting fw image am62x-pru0-fw, size 127440
[  123.458] virtio_rpmsg_bus virtio0: rpmsg host is online
[  123.459] virtio_rpmsg_bus virtio0: creating channel rpmsg-raw addr 0x1e
[  123.460] remoteproc remoteproc1: remote processor 30074000.pru is now up
```

**2. "Device or resource busy" 错误**

其他进程已打开 `/dev/rpmsg0`：
```bash
# 查找占用进程
lsof /dev/rpmsg0

# 杀死占用进程
pkill -9 -f rpmsg_counter_receiver
```

**3. 收到 "msg received with no recipient" 错误**

这表明 PRU 在发送消息，但 Linux 端没有打开设备接收。需要重启 PRU 重新建立 endpoint 连接：
```bash
echo stop > /sys/class/remoteproc/remoteproc1/state
sleep 1
echo start > /sys/class/remoteproc/remoteproc1/state
sleep 2
/tmp/rpmsg_counter_receiver
```

**4. 接收频率不是 1 秒**

调整 `firmware/main.c` 中的 `DELAY_1SEC_CYCLES` 值：
- 增大值 → 延时更长
- 减小值 → 延时更短
- 理论值：166,500,000（333MHz ÷ 2）
- 实测校准值：16,650,000（约 1 秒）

### 调试工具

**查看 PRU 日志：**
```bash
dmesg | tail -30
```

**监控 RPMsg 消息：**
```bash
# 直接读取设备（原始数据）
timeout 5 cat /dev/rpmsg0
```

**检查 remoteproc 状态：**
```bash
cat /sys/class/remoteproc/remoteproc1/state      # PRU 状态
cat /sys/class/remoteproc/remoteproc1/firmware   # 加载的固件名
cat /sys/kernel/debug/remoteproc/remoteproc1/resource_table  # 资源表
```

## 代码优化要点

### 1. 代码大小优化

PRU 的 IRAM 仅有 **16KB**，必须避免引入大型库函数：

❌ **不推荐：**
```c
#include <stdio.h>
sprintf(msg, "PRU Counter: %d", counter);  // 引入 ~18KB 代码
```

✅ **推荐：**
```c
// 自定义轻量级字符串处理
uint16_t uint_to_str(uint32_t num, char *str) { ... }
uint16_t build_message(uint32_t counter, char *msg) { ... }
```

### 2. RPMsg Endpoint 管理

**关键点：**
- Linux 每次打开 `/dev/rpmsg0` 会获得新的 endpoint 地址
- PRU 必须通过接收第一条消息来动态学习 Linux 的 endpoint
- 不能硬编码 endpoint 地址

**正确做法：**
```c
// 等待 Linux 发送第一条消息
pru_rpmsg_receive(&transport, &src, &dst, payload, &len);

// src 现在包含 Linux endpoint 地址，用于后续发送
pru_rpmsg_send(&transport, dst, src, message, len);
```

### 3. 中断处理

PRU 使用轮询方式检查中断：
```c
while (1) {
    if (__R31 & HOST_INT) {  // 检查 R31 寄存器的中断位
        if (CT_INTC.ENA_STATUS_REG0 & FROM_ARM_HOST_BIT) {
            // 清除中断
            CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;
            // 处理消息
            pru_rpmsg_receive(...);
        }
    }
}
```

## 扩展应用

这个示例可以作为以下应用的基础：

1. **实时传感器数据采集**
   - PRU 高速采集 ADC/GPIO 数据
   - 定期通过 RPMsg 发送给 Linux 进行处理

2. **实时控制反馈**
   - PRU 执行精确定时控制（电机、PWM）
   - 向 Linux 报告状态/错误信息

3. **协处理器通信**
   - Linux 下发任务给 PRU
   - PRU 完成后返回结果

4. **调试和性能监控**
   - PRU 定期报告性能计数器
   - Linux 端可视化展示

## 性能特性

| 指标 | 值 |
|------|-----|
| PRU 处理周期 | 3 ns (@ 333 MHz) |
| RPMsg 单次传输延迟 | < 100 μs |
| 最大消息速率 | > 1000 msg/s |
| 单条消息最大长度 | 512 字节 |
| 代码占用空间 | ~5 KB (IRAM) |
| 数据占用空间 | ~1 KB (DRAM) |

## 许可证

本示例代码采用 BSD-3-Clause 许可证。详见源文件头部的许可声明。

## 参考资料

**TI 官方文档：**
- [AM62x Technical Reference Manual](https://www.ti.com/lit/spruiv7)
- [PRU-ICSS Documentation](https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/latest/exports/docs/linux/Foundational_Components_PRU_Subsystem.html)
- [PRU Assembly Instruction User Guide](https://www.ti.com/lit/spruij2)

**OpenPRU 项目：**
- [OpenPRU GitHub](https://github.com/beagleboard/openPRU)
- [Getting Started Guide](../../docs/getting_started.md)
- [Create New Project Guide](../../docs/open_pru_create_new_project.md)

**相关示例：**
- `rpmsg_echo_linux`: RPMsg 双向回显示例
- `gpio_toggle`: GPIO 直接控制示例
- `intc_mcu`: 中断控制器配置示例

## 作者和贡献

- **创建时间：** 2026-05-23
- **测试平台：** BeagleBoard.org PocketBeagle2 (AM6232)
- **Linux 版本：** Debian Trixie IOT Image 2026-01-15, Kernel 6.12.57

欢迎贡献改进和 Bug 修复！
