#!/usr/bin/env python3
"""
Switch V24 pinmux between TX and RX modes via devmem2
Run on BeagleBone target
"""

import subprocess
import sys

PADCFG_V24 = 0x000F40BC
KICK0 = 0x00101008
KICK1 = 0x0010100C

MODE_TX = 0x00010005  # Mode 5: PRU0_GPO9
MODE_RX = 0x00060006  # Mode 6: PRU0_GPI9 + pullup

def devmem_write(addr, value):
    """Write to memory using devmem2"""
    cmd = f"devmem2 0x{addr:08X} w 0x{value:08X}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.returncode == 0

def devmem_read(addr):
    """Read from memory using devmem2"""
    cmd = f"devmem2 0x{addr:08X}"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        # Parse output: "Read at address 0x... : 0x12345678"
        for line in result.stdout.split('\n'):
            if 'Read at address' in line and ':' in line:
                val_str = line.split(':')[1].strip()
                return int(val_str, 16)
    return None

def unlock_padconfig():
    """Unlock PADCONFIG registers"""
    print("Unlocking PADCONFIG...")
    devmem_write(KICK0, 0x68EF3490)
    devmem_write(KICK1, 0xD172BC5A)
    print("Unlocked")

def set_tx_mode():
    """Set V24 to TX mode (PRU0_GPO9)"""
    unlock_padconfig()
    print(f"Setting V24 to TX mode (0x{MODE_TX:08X})...")
    devmem_write(PADCFG_V24, MODE_TX)
    val = devmem_read(PADCFG_V24)
    print(f"V24 PADCONFIG readback: 0x{val:08X}")
    return val == MODE_TX

def set_rx_mode():
    """Set V24 to RX mode (PRU0_GPI9)"""
    unlock_padconfig()
    print(f"Setting V24 to RX mode (0x{MODE_RX:08X})...")
    devmem_write(PADCFG_V24, MODE_RX)
    val = devmem_read(PADCFG_V24)
    print(f"V24 PADCONFIG readback: 0x{val:08X}")
    return val == MODE_RX

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: pinmux_switch.py [tx|rx|status]")
        sys.exit(1)
    
    cmd = sys.argv[1].lower()
    
    if cmd == "tx":
        if set_tx_mode():
            print("✓ TX mode set successfully")
        else:
            print("✗ TX mode failed")
            sys.exit(1)
    elif cmd == "rx":
        if set_rx_mode():
            print("✓ RX mode set successfully")
        else:
            print("✗ RX mode failed")
            sys.exit(1)
    elif cmd == "status":
        val = devmem_read(PADCFG_V24)
        print(f"V24 PADCONFIG: 0x{val:08X}")
        if val == MODE_TX:
            print("Mode: TX (PRU0_GPO9)")
        elif val == MODE_RX:
            print("Mode: RX (PRU0_GPI9)")
        else:
            print("Mode: Unknown")
    else:
        print("Unknown command. Use: tx, rx, or status")
        sys.exit(1)
