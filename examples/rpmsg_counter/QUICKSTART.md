# RPMsg Counter 快速开始指南

## 5分钟快速测试

### 1. 编译固件
```bash
cd /path/to/open-pru/examples/rpmsg_counter
make clean && make
```

### 2. 部署到设备
```bash
# 上传固件（注意路径）
scp firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/rpmsg_counter_am62x-sk_pruss0_pru0_fw.out root@192.168.7.2:/lib/firmware/am62x-pru0-fw

# 上传接收程序源码
scp linux/rpmsg_counter_receiver/rpmsg_counter_receiver.c root@192.168.7.2:/tmp/

# SSH 到设备
ssh root@192.168.7.2
```

### 3. 在目标设备上
```bash
# 编译接收程序
cd /tmp
gcc -Wall -O2 -o rpmsg_counter_receiver rpmsg_counter_receiver.c

# 停止并重启 PRU
echo stop > /sys/class/remoteproc/remoteproc1/state
sleep 1
echo start > /sys/class/remoteproc/remoteproc1/state
sleep 2

# 运行接收程序
/tmp/rpmsg_counter_receiver
```

应该看到每秒递增的计数器！

## 一键部署（自动化）

如果网络配置正确（能 ssh 到 192.168.7.2）：
```bash
cd /path/to/open-pru/examples/rpmsg_counter
./deploy_counter.sh
```

然后在目标设备上运行：
```bash
ssh root@192.168.7.2 '/tmp/rpmsg_counter_receiver'
```

## 故障排查快查表

| 问题 | 检查命令 | 解决方法 |
|------|---------|---------|
| PRU 未启动 | `cat /sys/class/remoteproc/remoteproc1/state` | `echo start > /sys/class/remoteproc/remoteproc1/state` |
| 设备不存在 | `ls -l /dev/rpmsg*` | 检查 `dmesg` 确认 PRU 已创建通道 |
| 设备被占用 | `lsof /dev/rpmsg0` | `pkill -9 -f rpmsg_counter_receiver` |
| 收不到消息 | `dmesg \| tail -20` | 重启 PRU，重新运行接收程序 |

## 关键文件位置

**在开发主机（项目根目录）：**
- PRU 源码：`firmware/main.c`
- 项目 makefile：`makefile`（在这里执行 make）
- 编译输出：`firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/*.out`
- Linux 源码：`linux/rpmsg_counter_receiver/rpmsg_counter_receiver.c`

**在目标设备：**
- 固件位置：`/lib/firmware/am62x-pru0-fw`
- PRU 控制：`/sys/class/remoteproc/remoteproc1/`
- RPMsg 设备：`/dev/rpmsg0`
- 接收程序：`/tmp/rpmsg_counter_receiver`

## 修改发送频率

编辑 `firmware/main.c`，修改第 59 行：
```c
#define DELAY_1SEC_CYCLES  16650000   // 当前: ~1秒
```

调整值：
- `1665000` → 约 0.1 秒
- `33300000` → 约 2 秒
- `166500000` → 约 10 秒

修改后重新编译并部署。

## 下一步学习

1. 阅读 [完整 README](README.md) 了解技术细节
2. 查看 [OpenPRU 文档](../../docs/) 学习构建系统
3. 参考 `rpmsg_echo_linux` 学习双向通信
4. 尝试修改代码发送传感器数据
