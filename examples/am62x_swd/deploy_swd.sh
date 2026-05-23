#!/bin/bash
#
# deploy_swd.sh - Automated deployment script for AM62x PRU-SWD
#
# Usage: ./deploy_swd.sh [target_ip]
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_IP="${1:-192.168.7.2}"
TARGET_USER="root"
FIRMWARE_NAME="am62x-pru0-fw"

# Paths
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$PROJECT_DIR/firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt"
FIRMWARE_OUT="$FIRMWARE_DIR/generated/am62x_swd_pruss0_pru0_fw.out"
TEST_DIR="$PROJECT_DIR/linux/swd_test"
TEST_BIN="$TEST_DIR/swd_test"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AM62x PRU-SWD Deployment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Target: ${GREEN}$TARGET_USER@$TARGET_IP${NC}"
echo ""

# Step 1: Build firmware
echo -e "${YELLOW}[1/6]${NC} Building PRU firmware..."
cd "$PROJECT_DIR"
make clean > /dev/null 2>&1 || true
if make; then
    echo -e "${GREEN}✓${NC} Firmware built successfully"
else
    echo -e "${RED}✗${NC} Firmware build failed"
    exit 1
fi

# Check if firmware exists
if [ ! -f "$FIRMWARE_OUT" ]; then
    echo -e "${RED}✗${NC} Firmware not found: $FIRMWARE_OUT"
    exit 1
fi

FIRMWARE_SIZE=$(du -h "$FIRMWARE_OUT" | cut -f1)
echo -e "  Firmware size: ${GREEN}$FIRMWARE_SIZE${NC}"

# Step 2: Build test program
echo -e "${YELLOW}[2/6]${NC} Building test program..."
cd "$TEST_DIR"
make clean > /dev/null 2>&1 || true
if make; then
    echo -e "${GREEN}✓${NC} Test program built successfully"
else
    echo -e "${RED}✗${NC} Test program build failed"
    exit 1
fi

TEST_SIZE=$(du -h "$TEST_BIN" | cut -f1)
echo -e "  Test program size: ${GREEN}$TEST_SIZE${NC}"

# Step 3: Upload firmware
echo -e "${YELLOW}[3/6]${NC} Uploading firmware to target..."
if scp "$FIRMWARE_OUT" "$TARGET_USER@$TARGET_IP:/lib/firmware/$FIRMWARE_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Firmware uploaded"
else
    echo -e "${RED}✗${NC} Failed to upload firmware"
    echo -e "  ${RED}Hint: Check network connection and SSH access${NC}"
    exit 1
fi

# Step 4: Upload test program
echo -e "${YELLOW}[4/6]${NC} Uploading test program..."
if scp "$TEST_BIN" "$TARGET_USER@$TARGET_IP:/tmp/" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Test program uploaded"
else
    echo -e "${RED}✗${NC} Failed to upload test program"
    exit 1
fi

# Step 5: Restart PRU
echo -e "${YELLOW}[5/6]${NC} Restarting PRU..."
ssh "$TARGET_USER@$TARGET_IP" << 'EOF' 2>/dev/null
    # Stop PRU
    echo stop > /sys/class/remoteproc/remoteproc1/state 2>/dev/null || true
    sleep 1
    
    # Start PRU
    echo start > /sys/class/remoteproc/remoteproc1/state
    sleep 2
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} PRU restarted"
else
    echo -e "${RED}✗${NC} Failed to restart PRU"
    exit 1
fi

# Step 6: Verify PRU state
echo -e "${YELLOW}[6/6]${NC} Verifying PRU state..."
PRU_STATE=$(ssh "$TARGET_USER@$TARGET_IP" "cat /sys/class/remoteproc/remoteproc1/state" 2>/dev/null)

if [ "$PRU_STATE" = "running" ]; then
    echo -e "${GREEN}✓${NC} PRU is running"
else
    echo -e "${RED}✗${NC} PRU state: $PRU_STATE (expected: running)"
    exit 1
fi

# Success summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Files deployed:"
echo -e "  Firmware:     ${BLUE}/lib/firmware/$FIRMWARE_NAME${NC}"
echo -e "  Test program: ${BLUE}/tmp/swd_test${NC}"
echo ""
echo -e "PRU Status:"
echo -e "  State:        ${GREEN}$PRU_STATE${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. SSH to target:  ${YELLOW}ssh $TARGET_USER@$TARGET_IP${NC}"
echo -e "  2. Run test:       ${YELLOW}sudo /tmp/swd_test${NC}"
echo ""
echo -e "${BLUE}Happy debugging! 🚀${NC}"
