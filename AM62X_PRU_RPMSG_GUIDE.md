# AM62X PRU RPMsg 完整操作指南

本文档记录了在 AM62X (PocketBeagle2) 上配置、编译、加载和测试 PRU RPMsg 通信的完整流程。

---

## 环境信息

- **开发主机**: Ubuntu Linux (WSL)
- **目标设备**: PocketBeagle2 (AM6232)
- **目标设备 IP**: 192.168.7.2
- **PRU 核心**: PRU0 (remoteproc1)
- **工具路径**: ~/ti/ti-cgt-pru_2.3.3

---

## 步骤 1: 配置 imports.mak

### 1.1 复制默认配置文件

```bash
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru
cp imports.mak.default imports.mak
```

### 1.2 修改 imports.mak 配置

编辑 `imports.mak` 文件，修改以下关键配置项：

```makefile
# 设置目标设备为 am62x
DEVICE ?= am62x

# 配置项目类型
PROFILE?=release

# 设置芯片类型
DEVICE_TYPE?=GP

# 不编译 MCU+ SDK 项目（AM62X 不支持从 R5F 初始化 PRU）
BUILD_MCUPLUS?=n

# 编译 Linux 项目（AM62X 从 A53 Linux 初始化 PRU）
BUILD_LINUX?=y

# 设置工具路径（Linux）
export TOOLS_PATH?=$(HOME)/ti
export CCS_PATH?=$(TOOLS_PATH)/ccs1280/ccs
CGT_GCC_AARCH64_PATH=$(TOOLS_PATH)/gcc-arm-9.2-2019.12-x86_64-aarch64-none-elf
CGT_TI_PRU_PATH=$(TOOLS_PATH)/ti-cgt-pru_2.3.3
```

**关键要点**:
- AM62X 只支持从 Linux (A53) 初始化 PRU
- 因此 `BUILD_MCUPLUS=n`, `BUILD_LINUX=y`

---

## 步骤 2: 编译 RPMsg Echo 固件

### 2.1 进入 rpmsg_echo_linux 示例目录

```bash
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt
```

### 2.2 清理并编译

```bash
make clean
make
```

**编译输出**:
```
Building file: "../../../main.c"
Invoking: PRU Compiler
...
Building target: "generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out"
Invoking: PRU Linker
<Linking>
Finished building target: "generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out"
```

**生成的文件**:
- 固件文件: `generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out` (~6KB)
- 固件大小: 约 5988 字节

### 2.3 验证编译结果

```bash
ls -lh generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out
```

---

## 步骤 3: 部署固件到目标设备

### 3.1 上传固件到 /lib/firmware

```bash
scp generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out \
    root@192.168.7.2:/lib/firmware/am62x-pru0-fw
```

**说明**:
- 固件必须放在 `/lib/firmware/` 目录
- 文件名必须与设备树中配置的固件名一致
- AM62X PRU0 的固件名是 `am62x-pru0-fw`

### 3.2 验证文件上传

```bash
ssh root@192.168.7.2 'ls -lh /lib/firmware/am62x-pru0-fw'
```

**预期输出**:
```
-rw-r--r-- 1 root root 5.9K May 23 18:30 /lib/firmware/am62x-pru0-fw
```

---

## 步骤 4: 加载和启动 PRU

### 4.1 检查 PRU RemoteProc 设备

```bash
ssh root@192.168.7.2 'ls -l /sys/class/remoteproc/'
```

**输出**:
```
remoteproc0 -> .../5000000.m4fss/remoteproc/remoteproc0  (M4F 核心)
remoteproc1 -> .../30074000.pru/remoteproc/remoteproc1   (PRU0)
remoteproc2 -> .../30078000.pru/remoteproc/remoteproc2   (PRU1)
```

**说明**:
- `remoteproc1` 对应 PRU0 (地址 0x30074000)
- `remoteproc2` 对应 PRU1 (地址 0x30078000)

### 4.2 检查当前状态

```bash
ssh root@192.168.7.2 'cat /sys/class/remoteproc/remoteproc1/state'
```

可能的状态:
- `offline` - PRU 未运行
- `running` - PRU 正在运行

### 4.3 停止 PRU（如果正在运行）

```bash
ssh root@192.168.7.2 'echo stop > /sys/class/remoteproc/remoteproc1/state'
```

### 4.4 启动 PRU

```bash
ssh root@192.168.7.2 'echo start > /sys/class/remoteproc/remoteproc1/state'
```

### 4.5 验证 PRU 状态

```bash
ssh root@192.168.7.2 'cat /sys/class/remoteproc/remoteproc1/state'
```

**预期输出**: `running`

### 4.6 查看系统日志

```bash
ssh root@192.168.7.2 'dmesg | grep -i pru | tail -10'
```

**预期输出**:
```
[xxx] remoteproc remoteproc1: powering up 30074000.pru
[xxx] remoteproc remoteproc1: Booting fw image am62x-pru0-fw, size 5988
[xxx] remoteproc remoteproc1: remote processor 30074000.pru is now up
[xxx] virtio_rpmsg_bus virtio0: creating channel rpmsg-raw addr 0x1e
[xxx] virtio_rpmsg_bus virtio0: rpmsg host is online
```

关键信息:
- "remote processor 30074000.pru is now up" - PRU 启动成功
- "creating channel rpmsg-raw addr 0x1e" - RPMsg 通道创建成功
- 端口 0x1e (十进制 30) 对应代码中的 `CHAN_PORT 30`

---

## 步骤 5: 验证 RPMsg 设备

### 5.1 检查 RPMsg 字符设备

```bash
ssh root@192.168.7.2 'ls -l /dev/rpmsg*'
```

**预期输出**:
```
crw------- 1 root root 243, 0 May 23 18:30 /dev/rpmsg0
crw------- 1 root root 243, 1 May 23 18:30 /dev/rpmsg_ctrl0
```

**说明**:
- `/dev/rpmsg0` - 用于与 PRU0 通信的数据通道
- `/dev/rpmsg_ctrl0` - 控制设备

### 5.2 查看 RPMsg 设备详情

```bash
ssh root@192.168.7.2 'cat /sys/class/rpmsg/rpmsg0/name'
ssh root@192.168.7.2 'cat /sys/class/rpmsg/rpmsg0/src'
ssh root@192.168.7.2 'cat /sys/class/rpmsg/rpmsg0/dst'
```

**预期输出**:
```
rpmsg-raw       # 通道名称
1024            # Linux 端地址
30              # PRU 端地址（CHAN_PORT）
```

---

## 步骤 6: 创建测试脚本

### 6.1 在目标设备上创建测试脚本

通过 SSH 创建测试脚本:

```bash
ssh root@192.168.7.2 'cat > /tmp/rpmsg_test.sh << '\''EOF'\''
#!/bin/bash

echo "=== RPMsg Echo Test ==="
DEVICE="/dev/rpmsg0"

if [ ! -e "$DEVICE" ]; then
    echo "Error: $DEVICE not found!"
    exit 1
fi

echo "Device: $DEVICE"
echo ""

# Test 1: Simple echo
echo "Test 1: Sending '\''Hello PRU'\''"
echo "Reading response..."
echo "Hello PRU" > $DEVICE
dd if=$DEVICE bs=512 count=1 2>/dev/null | head -c 100
echo ""
echo ""

# Test 2: Multiple messages
echo "Test 2: Sending 3 messages"
for i in 1 2 3; do
    MSG="Message $i from Linux"
    echo "Sending: $MSG"
    echo "$MSG" > $DEVICE
    echo "Response:"
    dd if=$DEVICE bs=512 count=1 2>/dev/null | head -c 100
    echo ""
done

echo "=== Test Complete ==="
EOF'
```

### 6.2 添加执行权限

```bash
ssh root@192.168.7.2 'chmod +x /tmp/rpmsg_test.sh'
```

---

## 步骤 7: 执行测试

### 7.1 运行测试脚本

```bash
ssh root@192.168.7.2 '/tmp/rpmsg_test.sh'
```

### 7.2 测试结果

**成功的输出示例**:
```
=== RPMsg Echo Test ===
Device: /dev/rpmsg0

Test 1: Sending 'Hello PRU'
Reading response...
Hello PRU

Test 2: Sending 3 messages
Sending: Message 1 from Linux
Response:
Message 1 from Linux

Sending: Message 2 from Linux
Response:
Message 2 from Linux

Sending: Message 3 from Linux
Response:
Message 3 from Linux

=== Test Complete ===
```

### 7.3 结果分析

✅ **成功标志**:
- `/dev/rpmsg0` 设备存在
- 发送的每条消息都被完整回显
- 消息内容没有损坏或丢失
- 所有 3 次测试都成功

这证明:
1. PRU 固件正确加载并运行
2. RPMsg 通道建立成功
3. Linux → PRU 消息发送正常
4. PRU → Linux 消息返回正常
5. 中断机制工作正常
6. 共享内存配置正确

---

## 步骤 8: 手动测试（可选）

### 8.1 交互式测试

在目标设备上:

```bash
# 读取 PRU 响应（在一个终端）
cat /dev/rpmsg0

# 发送消息到 PRU（在另一个终端）
echo "Test message" > /dev/rpmsg0
```

### 8.2 使用 hexdump 查看原始数据

```bash
echo "Hello" > /dev/rpmsg0
hexdump -C /dev/rpmsg0
```

---

## 故障排查

### 问题 1: PRU 无法启动

**检查**:
```bash
ssh root@192.168.7.2 'dmesg | grep -i pru'
```

**可能原因**:
- 固件文件不存在或权限错误
- 固件文件损坏
- 设备树配置错误

**解决方法**:
```bash
# 检查固件
ssh root@192.168.7.2 'ls -l /lib/firmware/am62x-pru0-fw'

# 修复权限
ssh root@192.168.7.2 'chmod 644 /lib/firmware/am62x-pru0-fw'
```

### 问题 2: /dev/rpmsg0 不存在

**检查**:
```bash
ssh root@192.168.7.2 'dmesg | grep rpmsg'
```

**可能原因**:
- PRU 固件未创建 RPMsg 通道
- 通道名称不匹配（需要 "rpmsg-raw"）
- 内核缺少 rpmsg_char 驱动

**解决方法**:
```bash
# 检查内核模块
ssh root@192.168.7.2 'lsmod | grep rpmsg'

# 重启 PRU
ssh root@192.168.7.2 'echo stop > /sys/class/remoteproc/remoteproc1/state'
ssh root@192.168.7.2 'echo start > /sys/class/remoteproc/remoteproc1/state'
```

### 问题 3: 消息没有回显

**检查**:
```bash
# 确认 PRU 正在运行
ssh root@192.168.7.2 'cat /sys/class/remoteproc/remoteproc1/state'

# 查看 PRU 日志
ssh root@192.168.7.2 'dmesg | tail -20'
```

**可能原因**:
- PRU 代码有 bug
- 中断配置错误
- RPMsg 缓冲区问题

---

## 快速参考命令

### 一键部署和启动

```bash
# 从开发主机执行
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt

# 编译、上传、启动一条龙
make clean && make && \
scp generated/rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out root@192.168.7.2:/lib/firmware/am62x-pru0-fw && \
ssh root@192.168.7.2 'echo stop > /sys/class/remoteproc/remoteproc1/state; sleep 1; echo start > /sys/class/remoteproc/remoteproc1/state; cat /sys/class/remoteproc/remoteproc1/state'
```

### 快速测试

```bash
# 发送并接收
ssh root@192.168.7.2 'echo "Hello PRU" > /dev/rpmsg0 && dd if=/dev/rpmsg0 bs=512 count=1 2>/dev/null'
```

### 停止 PRU

```bash
ssh root@192.168.7.2 'echo stop > /sys/class/remoteproc/remoteproc1/state'
```

---

## 技术细节

### RPMsg 配置参数

在 `main.c` 中定义的关键参数:

```c
#define CHAN_NAME "rpmsg-raw"    // 通道名称，匹配 Linux rpmsg_char 驱动
#define CHAN_PORT 30             // PRU 端口号（0x1E）
#define HOST_INT_BIT 30          // 主机中断位
#define TO_ARM_HOST 16           // 发送到 ARM 的系统事件
#define FROM_ARM_HOST 17         // 从 ARM 接收的系统事件
```

### PRU 地址映射

| 核心 | 地址 | RemoteProc | 固件名 |
|------|------|------------|--------|
| PRU0 | 0x30074000 | remoteproc1 | am62x-pru0-fw |
| PRU1 | 0x30078000 | remoteproc2 | am62x-pru1-fw |

### RPMsg 消息大小

- 最大单条消息: 512 字节（RPMSG_MESSAGE_SIZE）
- 缓冲区数量: 16 TX + 16 RX

---

## 下一步

成功完成 RPMsg 测试后，您可以:

1. **修改 PRU 代码**实现自定义功能（如数据处理、传感器采样等）
2. **开发 Linux 应用程序**通过 RPMsg 与 PRU 交互
3. **测试高性能场景**（高频通信、大数据传输）
4. **配置引脚复用**使用 PRU GPIO 进行硬件控制
5. **添加多核支持**同时使用 PRU0 和 PRU1

---

## 文件位置

- **源码**: `/home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_echo_linux/`
- **固件**: `/home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/`
- **配置**: `/home/zhangjiance/Code/ti_am625/PRU/open-pru/imports.mak`
- **目标固件路径**: `/lib/firmware/am62x-pru0-fw` (在目标设备上)
- **测试脚本**: `/tmp/rpmsg_test.sh` (在目标设备上)

---

**文档版本**: 1.0  
**日期**: 2026-05-23  
**测试平台**: PocketBeagle2 (AM6232)  
**PRU 编译器**: ti-cgt-pru_2.3.3
