#!/bin/bash
# PRU GPIO Toggle Deployment Script for PocketBeagle2 (AM62x)
# Sets PADCONFIG46 (U22) to PRU mode, uploads firmware, starts PRU

PRU_STATE=/sys/class/remoteproc/remoteproc1/state

echo "=== Setting U22 to PR0_PRU0_GPO8 (Mode 5) ==="
python3 -c "
import mmap, os, struct
PADCONFIG_OFFSET = 0x000F4000
MODE5_VAL = 0x00040005

fd = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
mem = mmap.mmap(fd, 4096, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE, offset=PADCONFIG_OFFSET)
old = struct.unpack('<I', mem[0xB8:0xBC])[0]
mem[0xB8:0xBC] = struct.pack('<I', MODE5_VAL)
new = struct.unpack('<I', mem[0xB8:0xBC])[0]
mem.close()
os.close(fd)
print(f'PADCONFIG46: 0x{old:08X} -> 0x{new:08X}')
assert new == MODE5_VAL, 'Pinmux write failed!'
print('Pinmux OK: U22 -> PR0_PRU0_GPO8')
"

echo ""
echo "=== Starting PRU with GPIO Toggle Firmware ==="
echo stop > $PRU_STATE 2>/dev/null || true
sleep 0.3
echo start > $PRU_STATE
sleep 0.5

echo "PRU State: $(cat $PRU_STATE)"
dmesg | grep 'remoteproc.*pru' | tail -3

if [ "$(cat $PRU_STATE)" = "running" ]; then
    echo ""
    echo "======================================"
    echo "  PRU GPIO Toggle - RUNNING!"
    echo "  U22 (HP2-2) toggling at ~2Hz"
    echo "  Connect LED between U22 and GND"
    echo "======================================"
fi
