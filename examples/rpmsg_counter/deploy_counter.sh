#!/bin/bash
# deploy_counter.sh - Deploy and test PRU Counter demo

set -e  # Exit on error

# Configuration
TARGET_IP="192.168.7.2"
TARGET_USER="root"
FIRMWARE_NAME="am62x-pru0-fw"
PRU_REMOTEPROC="remoteproc1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}PRU Counter Demo Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Step 1: Compile firmware
echo -e "${YELLOW}[1/6] Compiling PRU firmware...${NC}"
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_counter/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt
make clean > /dev/null 2>&1
make
if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firmware compiled successfully${NC}"
echo ""

# Step 2: Compile Linux receiver
echo -e "${YELLOW}[2/6] Compiling Linux receiver...${NC}"
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_counter/linux/rpmsg_counter_receiver
make clean > /dev/null 2>&1
make
if [ $? -ne 0 ]; then
    echo -e "${RED}Receiver compilation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Receiver compiled successfully${NC}"
echo ""

# Step 3: Upload firmware to target
echo -e "${YELLOW}[3/6] Uploading firmware to ${TARGET_IP}...${NC}"
FIRMWARE_PATH="/home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/rpmsg_counter/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/rpmsg_counter_am62x-sk_pruss0_pru0_fw.out"
scp -q "$FIRMWARE_PATH" "${TARGET_USER}@${TARGET_IP}:/lib/firmware/${FIRMWARE_NAME}"
if [ $? -ne 0 ]; then
    echo -e "${RED}Upload failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Firmware uploaded${NC}"
echo ""

# Step 4: Upload receiver to target
echo -e "${YELLOW}[4/6] Uploading receiver to ${TARGET_IP}...${NC}"
scp -q rpmsg_counter_receiver "${TARGET_USER}@${TARGET_IP}:/tmp/"
if [ $? -ne 0 ]; then
    echo -e "${RED}Receiver upload failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Receiver uploaded${NC}"
echo ""

# Step 5: Restart PRU
echo -e "${YELLOW}[5/6] Restarting PRU...${NC}"
ssh "${TARGET_USER}@${TARGET_IP}" << 'EOF'
    echo stop > /sys/class/remoteproc/remoteproc1/state 2>/dev/null || true
    sleep 1
    echo start > /sys/class/remoteproc/remoteproc1/state
    sleep 2
EOF
if [ $? -ne 0 ]; then
    echo -e "${RED}PRU restart failed!${NC}"
    exit 1
fi

# Verify PRU is running
PRU_STATE=$(ssh "${TARGET_USER}@${TARGET_IP}" "cat /sys/class/remoteproc/${PRU_REMOTEPROC}/state")
if [ "$PRU_STATE" != "running" ]; then
    echo -e "${RED}PRU failed to start (state: $PRU_STATE)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PRU started successfully (state: ${PRU_STATE})${NC}"
echo ""

# Verify RPMsg device
RPMSG_DEV=$(ssh "${TARGET_USER}@${TARGET_IP}" "ls /dev/rpmsg0 2>/dev/null || echo 'NOT_FOUND'")
if [ "$RPMSG_DEV" == "NOT_FOUND" ]; then
    echo -e "${RED}/dev/rpmsg0 not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ RPMsg device found: /dev/rpmsg0${NC}"
echo ""

# Step 6: Instructions for running receiver
echo -e "${YELLOW}[6/6] Ready to test!${NC}"
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}To receive counter messages, run on target device:${NC}"
echo -e "${GREEN}  ssh ${TARGET_USER}@${TARGET_IP}${NC}"
echo -e "${GREEN}  /tmp/rpmsg_counter_receiver${NC}"
echo ""
echo -e "${YELLOW}Or run directly:${NC}"
echo -e "${GREEN}  ssh ${TARGET_USER}@${TARGET_IP} '/tmp/rpmsg_counter_receiver'${NC}"
echo ""
echo -e "${YELLOW}Expected output:${NC}"
echo "  [1] Received XX bytes: PRU Counter: 0"
echo "  [2] Received XX bytes: PRU Counter: 1"
echo "  [3] Received XX bytes: PRU Counter: 2"
echo "  ..."
echo ""
