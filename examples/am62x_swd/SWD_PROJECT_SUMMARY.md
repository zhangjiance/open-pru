# AM62x PRU-SWD Project Summary

## Project Overview
Implementation of SWD (Serial Wire Debug) protocol on AM62x PocketBeagle2 using PRU0 assembly, based on Open-PRU build system and Blackmagic probe reference.

## Key Technical Achievements

### 1. PRU GPIO Pin Mapping (Final Configuration)

| Function | Pin | Ball | P2 Header | R30/R31 Bit | PADCONFIG | Address | Mode |
|----------|-----|------|-----------|-------------|-----------|---------|------|
| SWD_CLK | U22 | GPO8 | HP2-2 | R30.8 | PADCONFIG46 | 0x000F40B8 | 5 |
| SWD_DIO_OUT | V24 | GPO9 | HP2-4 | R30.9 | PADCONFIG47 | 0x000F40BC | 5 |
| SWD_DIO_IN | AB24 | GPI6 | W21 | R31.6 | PADCONFIG62 | 0x000F40F8 | 6 |

### 2. Pinmux Configuration Script

```python
import mmap, os, struct
BASE = 0x000F4000
pins = {
    'PADCONFIG46 (U22, CLK)':     (0xB8, 0x00040005),  # Mode 5: PR0_PRU0_GPO8
    'PADCONFIG47 (V24, DIO_OUT)': (0xBC, 0x00040005),  # Mode 5: PR0_PRU0_GPO9
    'PADCONFIG62 (AB24, DIO_IN)': (0xF8, 0x00040006),  # Mode 6: PR0_PRU0_GPI6
}
fd = os.open('/dev/mem', os.O_RDWR | os.O_SYNC)
mem = mmap.mmap(fd, 4096, mmap.MAP_SHARED, mmap.PROT_READ|mmap.PROT_WRITE, offset=BASE)
for name, (off, val) in pins.items():
    mem[off:off+4] = struct.pack('<I', val)
mem.close()
os.close(fd)
```

### 3. PRU Instruction Timing (Empirically Verified @ 333MHz)

| Instruction | Cycles | Notes |
|-------------|--------|-------|
| set/clr R30.t8 | 1 | Bit 8 direct manipulation (verified) |
| set/clr R30.t9 | 1 | Bit 9 direct manipulation (verified) |
| ldi32 | 2 | Compiler emits two ldi for 32-bit immediate |
| ldi rX.w0 | 1 | 16-bit load to lower half |
| mov r30, rX | 1 | Full 32-bit write to GPIO output |
| nop | 1 | |
| sub/add | 1 | |
| qbne (taken) | 2 | Conditional branch taken |
| qbne (not taken) | 1 | Conditional branch not taken |
| qba (unconditional) | 2 | Unconditional jump |
| qbbs/qbbc | 1 | Bit test branch (taken or not) |
| or/and (reg) | 1 | ALU operation |

### 4. PRU Assembly Syntax Limitations (TI CGT 2.3.3)

- `.t8` works on R30 (verified in GPIO toggle test)
- `.t9` may NOT work (need verification - not tested standalone)
- `.t10` definitely does NOT work
- `ldi rX, 0xFFFFFBFF` (32-bit immediate) does NOT work — use `ldi rX.w0` + `ldi rX.w2` pair
- `set r30, 10` / `clr r30, 8` syntax with bit number does NOT work for high bits
- `r10.t0` bit test on general register may not work — use `qbbs label, r10, 0` format

### 5. SWD Protocol Implementation Status

**Working:**
- ✅ GPIO toggle testing (verified 9.5MHz and 55.6MHz on logic analyzer)
- ✅ Pinmux configuration via /dev/mem Python mmap
- ✅ PRU firmware compilation and deployment via remoteproc
- ✅ JTAG-to-SWD line reset sequence (51+4 idle cycles)
- ✅ SWD command 0xA5 transmission (unrolled, 5 cycles/bit)
- ✅ CLK and DIO_OUT waveforms verified on logic analyzer
- ✅ Logic analyzer protocol decoder shows correct "Line reset" and "Operation" frames

**Known Issue - DIO Bidirectional Conflict:**
- PRU GPIO is **push-pull**, not open-drain
- DIO_OUT (V24) and DIO_IN (AB24) are on separate physical pins
- During ACK/data read phases, DIO_OUT drives HIGH while target tries to pull LOW
- This creates a conflict because PRU cannot tristate the output
- **Root cause**: No external resistor (~150Ω) between DIO_OUT and target SWDIO
- Without current limiting, target cannot reliably pull the line LOW against PRU's push-pull HIGH

### 6. Solution Options

#### Option A: External Resistor (Hardware Fix)
```
V24 (DIO_OUT) ──[150Ω]──┬── SWDIO (target)
AB24 (DIO_IN) ──────────┘
```

#### Option B: Dynamic Pinmux Switching (Software Fix - RECOMMENDED)

**Concept**: Dynamically switch V24's pinmux mode between transmit and receive:
- **TX phase**: V24 = PRU_GPO (Mode 5) → strong drive capability
- **RX phase**: V24 = MAIN GPIO input (Mode 0) → use internal pull-up resistor

**Implementation** (from [TI E2E Forum](https://e2e.ti.com/support/processors-group/processors/f/processors-forum/1348153)):

```assembly
; 1. Unlock PADCONFIG registers (one-time at boot)
ldi32 r2, 0x000f1008    ; LOCK0_KICK0 register
ldi32 r3, 0x000f100c    ; LOCK0_KICK1 register  
ldi32 r4, 0x68EF3490    ; Kick 0 unlock value
ldi32 r5, 0xD172BC5A    ; Kick 1 unlock value
sbbo  r4, r2, 0, 4
sbbo  r5, r3, 0, 4

; 2. Before sending: V24 = PRU_GPO mode
ldi32 r6, 0x000F40BC    ; PADCONFIG47 (V24)
ldi32 r7, 0x00040005    ; Mode 5 + output enable
sbbo  r7, r6, 0, 4

; 3. Before receiving: V24 = GPIO input with pull-up
ldi32 r7, 0x00050000    ; Mode 0 + pull-up enabled + input
sbbo  r7, r6, 0, 4
```

**PADCONFIG bit fields**:
- `[2:0]` = muxmode (5=PRU_GPO, 0=GPIO)
- `[16]` = pull-up/down enable (1=enabled)
- `[17]` = pull type (0=down, 1=up)
- `[18]` = input enable (1=enabled)

**Advantages**:
- ✅ No external components needed
- ✅ Uses SoC internal pull-up resistor
- ✅ PRU controls everything in firmware
- ✅ Dynamic mode switching at PRU instruction speed

### 11. Next Steps: Implementing Dynamic Pinmux

**Phase 1**: Add unlock sequence at PRU boot
```assembly
main:
    ; Unlock PADCONFIG registers
    ldi32 r2, 0x000f1008
    ldi32 r3, 0x000f100c
    ldi32 r4, 0x68EF3490
    ldi32 r5, 0xD172BC5A
    sbbo  r4, r2, 0, 4
    sbbo  r5, r3, 0, 4
    
    ; Continue with existing GPIO init...
    zero &r0, 120
```

**Phase 2**: Create pinmux switch macros
```assembly
    .asg 0x000F40BC, PADCFG_V24
    
switch_to_tx:
    ldi32 r20, PADCFG_V24
    ldi32 r21, 0x00040005    ; Mode 5, output
    sbbo  r21, r20, 0, 4
    ret

switch_to_rx:
    ldi32 r20, PADCFG_V24
    ldi32 r21, 0x00050000    ; Mode 0, input+pullup
    sbbo  r21, r20, 0, 4
    ret
```

**Phase 3**: Use in SWD sequence
```assembly
    ; Send 0xA5
    call switch_to_tx
    ; ... transmit code ...
    
    ; Park + TRN
    call switch_to_rx
    nop                      ; small delay for mode switch
    
    ; Read ACK
    ; ... receive code ...
```

**Estimated overhead**: ~10 cycles per switch (ldi32×2 + sbbo + ret)

### 7. Build & Deploy Commands

```bash
# Build
cd /home/zhangjiance/Code/ti_am625/PRU/open-pru/examples/am62x_swd
make clean && make

# Deploy
scp firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/am62x_swd_pruss0_pru0_fw.out \
    root@192.168.7.2:/lib/firmware/am62x-pru0-fw
ssh root@192.168.7.2 "echo stop > /sys/class/remoteproc/remoteproc1/state; sleep 0.3; echo start > /sys/class/remoteproc/remoteproc1/state"
```

### 8. Open-PRU Build System

- Uses TI PRU CGT v2.3.3 at `/home/zhangjiance/ti/ti-cgt-pru_2.3.3`
- Three-tier makefile: top-level → project → core
- Assembler files: `.asm` extension (NOT `.p`)
- Constant table entries: `.asg c24, CONST_PRUDRAM` for PRU0 DRAM
- Linker script at `firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/linker.cmd`

### 9. Target Board

- **Board**: PocketBeagle2 (AM62x)
- **PRU**: PRUSS0 PRU0 (remoteproc1)
- **Kernel**: 6.12.57-ti-arm64-r57
- **OS**: Debian Trixie IOT Image 2026-01-15
- **IP**: 192.168.7.2
- **SSH**: root@192.168.7.2 (passwordless key auth)

### 10. Known Working Commands Reference

```bash
# Check PRU state
cat /sys/class/remoteproc/remoteproc1/state

# Set pinmux
python3 -c "import mmap,os,struct; fd=os.open('/dev/mem',os.O_RDWR|os.O_SYNC); mem=mmap.mmap(fd,4096,mmap.MAP_SHARED,mmap.PROT_READ|mmap.PROT_WRITE,offset=0x000F4000); mem[0xB8:0xBC]=struct.pack('<I',0x00040005); mem.close(); os.close(fd)"

# Read padconfig
devmem2 0x000F40B8 w

# Check remoteproc firmware
ls -la /lib/firmware/am62x-pru0-fw

# Read PRU DRAM (partial access)
devmem2 0x30074000 w
```
