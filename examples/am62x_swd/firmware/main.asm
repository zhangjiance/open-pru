; SWD IDCODE Read with Dynamic Pinmux Switching
; CLK: R30.8 (U22) - PADCONFIG46 @ 0x000F40B8
; DIO: R30.9/R31.9 (V24) - PADCONFIG47 @ 0x000F40BC
    .retain
    .retainrefs
    .global main
    .sect ".text"

; Constants for pinmux control
    .asg 0x00101008, KICK0_ADDR
    .asg 0x0010100C, KICK1_ADDR
    .asg 0x68EF3490, KICK0_UNLOCK
    .asg 0xD172BC5A, KICK1_UNLOCK
    .asg 0x000F40B8, PADCFG_CLK_ADDR   ; CLK U22
    .asg 0x000F40BC, PADCFG_DIO_ADDR   ; DIO V24
    .asg 0x000F40F8, PADCFG_AB24_ADDR  ; AB24 (pullup provider)
    .asg 0x00050005, MODE_CLK_OUT      ; PRU_GPO8, Mode 5, output
    .asg 0x00010005, MODE_DIO_TX       ; PRU_GPO9, Mode 5, output
    .asg 0x00060006, MODE_DIO_RX       ; PRU_GPI9, Mode 6, input
    .asg 0x00070007, MODE_AB24_PU      ; GPIO0_61, Mode 7, input + pullup

; Delay subroutine: ~100 cycles for slower clock observation
delay_10cyc:
    ldi r29, 47         ; 1 cycle: load counter (47 iterations)
delay_loop:
    sub r29, r29, 1     ; 1 cycle
    qbne delay_loop, r29, 0  ; 1 cycle (branch not taken) or 2 (taken)
    jmp r3.w0           ; 2 cycles: return
    ; Total: 1 + (1+1)*47 + 1 + 2 = ~98 cycles (~294ns @ 333MHz, SWD CLK ~1.7MHz)

main:
    ;========================================
    ; Initialize pinmux - set both pins as outputs
    ;========================================
    ; Unlock MMR
    ldi32 r10, KICK0_ADDR
    ldi32 r11, KICK0_UNLOCK
    sbbo &r11, r10, 0, 4
    ldi32 r10, KICK1_ADDR
    ldi32 r11, KICK1_UNLOCK
    sbbo &r11, r10, 0, 4
    
    ; Set CLK pin (U22) to output mode
    ldi32 r10, PADCFG_CLK_ADDR
    ldi32 r11, MODE_CLK_OUT
    sbbo &r11, r10, 0, 4
    
    ; Set AB24 pin (W21) to GPIO input + pullup for DIO line
    ldi32 r10, PADCFG_AB24_ADDR
    ldi32 r11, MODE_AB24_PU
    sbbo &r11, r10, 0, 4
    
    ; Set DIO pin (V24) to TX mode initially
    ldi32 r10, PADCFG_DIO_ADDR
    ldi32 r11, MODE_DIO_TX
    sbbo &r11, r10, 0, 4

swd_sequence_loop:
    ;========================================
    ; Switch DIO back to TX mode for this sequence
    ;========================================
    ldi32 r10, KICK0_ADDR
    ldi32 r11, KICK0_UNLOCK
    sbbo &r11, r10, 0, 4
    ldi32 r10, KICK1_ADDR
    ldi32 r11, KICK1_UNLOCK
    sbbo &r11, r10, 0, 4
    ldi32 r10, PADCFG_DIO_ADDR
    ldi32 r11, MODE_DIO_TX
    sbbo &r11, r10, 0, 4
    
    ;========================================
    ; JTAG-to-SWD Sequence: 51+ CLK cycles with DIO=1
    ;========================================
    set r30.t9          ; DIO=1
    ldi r1, 55          ; 51 + margin
reset_loop:
    clr r30.t8          ; CLK=0
    jal r3.w0, delay_10cyc
    set r30.t8          ; CLK=1
    jal r3.w0, delay_10cyc
    sub r1, r1, 1
    qbne reset_loop, r1, 0
    
    ;========================================
    ; Idle cycles: at least 2 cycles with DIO=0, CLK toggling
    ;========================================
    clr r30.t9          ; DIO=0
    ldi r1, 2           ; At least 2 idle cycles
idle_loop:
    clr r30.t8          ; CLK=0
    jal r3.w0, delay_10cyc
    set r30.t8          ; CLK=1
    jal r3.w0, delay_10cyc
    sub r1, r1, 1
    qbne idle_loop, r1, 0
    
    ;========================================
    ; Send SWD Command: 0xA5 (IDCODE read)
    ; Format: [Start=1][APnDP=0][RnW=1][Addr[2:3]=(0,1)][Parity=1][Stop=0][Park=1]
    ; Binary: 10100101 = 0xA5
    ; We'll send it LSB first as required by SWD
    ;========================================
    ldi r2, 0xA5        ; Command byte
    ldi r1, 8           ; 8 bits to send
    
send_cmd_loop:
    ; Extract LSB
    and r4, r2, 1       ; r4 = current bit
    lsr r2, r2, 1       ; Shift for next iteration
    
    ; CLK=0, set DIO
    clr r30.t8
    qbbs set_dio_high, r4, 0
    clr r30.t9          ; DIO=0
    qba dio_set
set_dio_high:
    set r30.t9          ; DIO=1
dio_set:
    jal r3.w0, delay_10cyc
    
    ; CLK=1
    set r30.t8
    jal r3.w0, delay_10cyc
    
    sub r1, r1, 1
    qbne send_cmd_loop, r1, 0
    
    ;========================================
    ; TRN (Turnaround) - 1 cycle with DIO released
    ;========================================
    clr r30.t8
    clr r30.t9          ; Release DIO
    jal r3.w0, delay_10cyc
    
    ; *** SWITCH TO RX MODE ***
    ldi32 r10, KICK0_ADDR
    ldi32 r11, KICK0_UNLOCK
    sbbo &r11, r10, 0, 4
    ldi32 r10, KICK1_ADDR
    ldi32 r11, KICK1_UNLOCK
    sbbo &r11, r10, 0, 4
    ldi32 r10, PADCFG_DIO_ADDR
    ldi32 r11, MODE_DIO_RX
    sbbo &r11, r10, 0, 4
    
    set r30.t8
    jal r3.w0, delay_10cyc
    
    ;========================================
    ; Read ACK (3 bits, LSB first)
    ;========================================
    ldi r20, 0          ; Clear ACK register
    ldi r1, 3           ; 3 bits to read
    ldi r26, 1          ; Bit mask (bit 0, 1, 2)
    
read_ack_loop:
    clr r30.t8
    jal r3.w0, delay_10cyc
    
    ; Sample DIO (R31.t9) and set bit if high
    qbbc ack_bit_zero, r31, 9
    or r20, r20, r26    ; Set current bit
ack_bit_zero:
    lsl r26, r26, 1     ; Move to next bit position
    
    set r30.t8
    jal r3.w0, delay_10cyc
    
    sub r1, r1, 1
    qbne read_ack_loop, r1, 0
    ; ACK should be 0b001 (1) for OK response
    
    ;========================================
    ; Read IDCODE (32 bits) into r21 (LSB first)
    ;========================================
    ldi r21, 0          ; 32-bit IDCODE accumulator
    ldi r0, 32          ; Bit counter
    ldi r26, 1          ; Bit mask (starts at bit 0)
    
read_idcode_loop:
    clr r30.t8
    jal r3.w0, delay_10cyc
    
    ; Sample DIO and set corresponding bit if high
    qbbc idcode_bit_zero, r31, 9
    or r21, r21, r26    ; Set current bit position
idcode_bit_zero:
    lsl r26, r26, 1     ; Move to next bit position
    
    set r30.t8
    jal r3.w0, delay_10cyc
    
    sub r0, r0, 1
    qbne read_idcode_loop, r0, 0
    
    ; Split into r22 (upper 16) and r21 (lower 16) for display
    mov r22, r21.w2     ; Upper 16 bits
    mov r21, r21.w0     ; Lower 16 bits (overwrites full r21)
    
    ; Read parity bit (1 bit)
    clr r30.t8
    jal r3.w0, delay_10cyc
    ldi r23, 0
    qbbc parity_done, r31, 9
    ldi r23, 1
parity_done:
    set r30.t8
    jal r3.w0, delay_10cyc
    
    ;========================================
    ; Results in registers:
    ; r20 = ACK (should be 0b001 for OK)
    ; r21 = IDCODE[15:0]
    ; r22 = IDCODE[31:16]
    ; r23 = Parity bit
    ;========================================
    
    ;========================================
    ; Delay 100ms before next read
    ; PRU @ 333MHz: 100ms = 33,300,000 cycles
    ; Use nested loop: outer * inner * 10 = 33,300,000
    ; outer = 3330, inner = 1000, per iteration = 10 cycles
    ;========================================
    ldi r14, 3330       ; Outer loop counter
delay_100ms_outer:
    ldi r15, 1000       ; Inner loop counter
delay_100ms_inner:
    jal r3.w0, delay_10cyc  ; 10 cycles
    sub r15, r15, 1
    qbne delay_100ms_inner, r15, 0
    sub r14, r14, 1
    qbne delay_100ms_outer, r14, 0
    
    ; Loop back to read next IDCODE
    jmp swd_sequence_loop
