#!/bin/bash
# AM62X PRU RPMsg 快速部署脚本
# 自动编译、部署、启动和测试 PRU RPMsg 固件

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
TARGET_IP="192.168.7.2"
PRU_DIR="/home/zhangjiance/Code/ti_am625/PRU/open-pru"
FIRMWARE_DIR="$PRU_DIR/examples/rpmsg_echo_linux/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt"
FIRMWARE_NAME="rpmsg_echo_linux_am62x-sk_pruss0_pru0_fw.out"

echo -e "${GREEN}=== AM62X PRU RPMsg 自动部署 ===${NC}"
echo ""

# 步骤 1: 编译固件
echo -e "${YELLOW}[1/5] 编译 PRU 固件...${NC}"
cd "$FIRMWARE_DIR"
make clean > /dev/null 2>&1
if make; then
    echo -e "${GREEN}✓ 编译成功${NC}"
    ls -lh generated/$FIRMWARE_NAME
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi
echo ""

# 步骤 2: 上传固件
echo -e "${YELLOW}[2/5] 上传固件到目标设备...${NC}"
if scp generated/$FIRMWARE_NAME root@$TARGET_IP:/lib/firmware/am62x-pru0-fw; then
    echo -e "${GREEN}✓ 上传成功${NC}"
else
    echo -e "${RED}✗ 上传失败${NC}"
    exit 1
fi
echo ""

# 步骤 3: 停止 PRU
echo -e "${YELLOW}[3/5] 停止 PRU0...${NC}"
ssh root@$TARGET_IP 'echo stop > /sys/class/remoteproc/remoteproc1/state 2>/dev/null || true'
sleep 1
echo -e "${GREEN}✓ PRU0 已停止${NC}"
echo ""

# 步骤 4: 启动 PRU
echo -e "${YELLOW}[4/5] 启动 PRU0...${NC}"
if ssh root@$TARGET_IP 'echo start > /sys/class/remoteproc/remoteproc1/state'; then
    sleep 2
    STATE=$(ssh root@$TARGET_IP 'cat /sys/class/remoteproc/remoteproc1/state')
    if [ "$STATE" == "running" ]; then
        echo -e "${GREEN}✓ PRU0 启动成功 (状态: $STATE)${NC}"
    else
        echo -e "${RED}✗ PRU0 启动失败 (状态: $STATE)${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ 无法启动 PRU0${NC}"
    exit 1
fi
echo ""

# 检查 RPMsg 设备
echo -e "${YELLOW}检查 RPMsg 设备...${NC}"
if ssh root@$TARGET_IP 'test -e /dev/rpmsg0'; then
    echo -e "${GREEN}✓ /dev/rpmsg0 存在${NC}"
else
    echo -e "${RED}✗ /dev/rpmsg0 不存在${NC}"
    echo "等待 3 秒后重试..."
    sleep 3
    if ssh root@$TARGET_IP 'test -e /dev/rpmsg0'; then
        echo -e "${GREEN}✓ /dev/rpmsg0 已创建${NC}"
    else
        echo -e "${RED}✗ RPMsg 设备创建失败${NC}"
        exit 1
    fi
fi
echo ""

# 步骤 5: 运行测试
echo -e "${YELLOW}[5/5] 运行 RPMsg 测试...${NC}"

# 创建测试脚本
ssh root@$TARGET_IP 'cat > /tmp/rpmsg_test.sh << '\''EOF'\''
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

ssh root@$TARGET_IP 'chmod +x /tmp/rpmsg_test.sh'

# 运行测试
echo ""
if ssh root@$TARGET_IP '/tmp/rpmsg_test.sh'; then
    echo ""
    echo -e "${GREEN}=== 所有测试通过！✓ ===${NC}"
else
    echo ""
    echo -e "${RED}=== 测试失败 ✗ ===${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}部署和测试完成！${NC}"
echo ""
echo "查看 PRU 日志:"
echo "  ssh root@$TARGET_IP 'dmesg | grep -i pru | tail -10'"
echo ""
echo "停止 PRU:"
echo "  ssh root@$TARGET_IP 'echo stop > /sys/class/remoteproc/remoteproc1/state'"
