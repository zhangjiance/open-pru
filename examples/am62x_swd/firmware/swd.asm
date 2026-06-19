; swd.asm — SWD protocol functions
; CLK: R30.8 (U22), DIO: R30.9/R31.9 (V24)
;
; Link register convention:
;   r28.w0 — standard return for internal subroutines
;   r29.w0 — used ONLY by DELAY macro (never for subroutine calls)
;   r3.w2  — return for C-callable functions
;
; DELAY clobbers ONLY r29.w0 (not r28.w0!) so subroutines
; called via jal r28.w0 are safe.

    .retain
    .retainrefs
    .sect ".text:swd"
    .clink
    .global swd_init, swd_set_speed
    .global swd_line_reset, swd_idle_cycles
    .global swd_jtag_to_swd, swd_swd_to_jtag
    .global swd_swd_to_dormant, swd_dormant_to_swd
    .global swd_read_reg, swd_write_reg
    .global swd_custom_seq

;========================================================================
; Constants
;========================================================================
KICK0_ADDR     .set 0x00101008
KICK1_ADDR     .set 0x0010100C
KICK0_UNLOCK   .set 0x68EF3490
KICK1_UNLOCK   .set 0xD172BC5A
PADCFG_CLK     .set 0x000F40B8
PADCFG_DIO     .set 0x000F40BC
MODE_CLK_OUT   .set 0x00050005
MODE_DIO_OUT   .set 0x00050005
MODE_DIO_RX    .set 0x00070006   ; pull-up enabled (bit 16), input enabled (bit 18)

;========================================================================
; Macros
;========================================================================
CLK_LO  .macro
    clr r30.t8
    .endm
CLK_HI  .macro
    set r30.t8
    .endm
DIO_LO  .macro
    clr r30.t9
    .endm
DIO_HI  .macro
    set r30.t9
    .endm
; DELAY uses r29.w0 as link (NOT r28.w0!) so subroutines called via r28.w0 are safe
DELAY .macro
    jal r29.w0, delay_fn
    .endm

;========================================================================
; swd_init
;========================================================================
swd_init:
    ldi32 r16, KICK0_ADDR
    ldi32 r17, KICK0_UNLOCK
    sbbo &r17, r16, 0, 4
    ldi32 r16, KICK1_ADDR
    ldi32 r17, KICK1_UNLOCK
    sbbo &r17, r16, 0, 4
    ldi32 r16, PADCFG_CLK
    ldi32 r17, MODE_CLK_OUT
    sbbo &r17, r16, 0, 4
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4
    CLK_LO
    DIO_LO
    jmp r3.w2

;========================================================================
; swd_set_speed — r14 = delay cycles
;========================================================================
swd_set_speed:
    mov r18, r14
    jmp r3.w2

;========================================================================
; tx_setup — DIO to output mode. Called via jal r28.w0
;========================================================================
tx_setup:
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4
    jmp r28.w0

;========================================================================
; rx_setup — DIO to input+pullup. Called via jal r28.w0
;========================================================================
rx_setup:
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_RX
    sbbo &r17, r16, 0, 4
    jmp r28.w0

;========================================================================
; tx_bits — r26=data(LSB), r25=bit count. Called via jal r28.w0.
; DELAY uses r29.w0 so r28.w0 is preserved.
;========================================================================
tx_bits:
txb_loop:
    and r0, r26, 1
    lsr r26, r26, 1
    CLK_LO
    qbbs txb_hi, r0, 0
    DIO_LO
    qba txb_done
txb_hi:
    DIO_HI
txb_done:
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbne txb_loop, r25, 0
    CLK_LO
    jmp r28.w0

;========================================================================
; rx_bits — r21=accumulator, r23=mask, r25=count. Called via jal r28.w0.
;========================================================================
rx_bits:
    CLK_LO         ; ensure CLK starts low before first bit
rxb_loop:
    sub r25, r25, 1
    DELAY          ; DIO setup time (target drives data)
    CLK_HI         ; rising edge — host samples DIO
    qbbc rxb_z, r31, 9
    or r21, r21, r23
rxb_z:
    lsl r23, r23, 1
    DELAY          ; hold time
    CLK_LO         ; falling edge — prepare for next bit
    qbne rxb_loop, r25, 0
    jmp r28.w0

;========================================================================
; turnaround_input — release DIO for target. Called via jal r28.w0.
;========================================================================
turnaround_input:
    CLK_LO
    DIO_LO
    DELAY
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_RX
    sbbo &r17, r16, 0, 4
    DELAY          ; wait for pinmux switch to input mode!
    CLK_HI         ; TRN bit — target sees rising edge, takes control
    DELAY
    CLK_LO         ; prepare for rx: CLK must be low before sampling
    DELAY
    jmp r28.w0

;========================================================================
; turnaround_output — reclaim DIO. Called via jal r28.w0.
;========================================================================
turnaround_output:
    CLK_LO
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4
    DELAY         ; wait for pinmux switch to take effect!
    CLK_HI
    DELAY
    CLK_LO
    DELAY
    jmp r28.w0

;========================================================================
; swd_line_reset
;========================================================================
swd_line_reset:
    jal r28.w0, tx_setup
    DIO_HI
    ldi r25, 55
lr_loop:
    CLK_LO
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbne lr_loop, r25, 0
    DIO_LO
    ldi r25, 2
idle2:
    CLK_LO
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbne idle2, r25, 0
    CLK_LO
    jmp r3.w2

;========================================================================
; swd_idle_cycles — r14 = count
;========================================================================
swd_idle_cycles:
    jal r28.w0, tx_setup
    DIO_LO
    mov r25, r14
    qbeq ic_done, r25, 0
ic_loop:
    CLK_LO
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbne ic_loop, r25, 0
ic_done:
    CLK_LO
    jmp r3.w2

;========================================================================
; send_byte_seq — r14=byte ptr, r15=byte count. Called via jal r28.w0.
;========================================================================
send_byte_seq:
    mov r24, r28.w0          ; save link (will be clobbered by sub-calls)
    jal r28.w0, tx_setup
    mov r25, r15
    qbeq sbs_done, r25, 0
sbs_loop:
    lbbo &r26, r14, 0, 1
    add r14, r14, 1
    ldi r25, 8
    jal r28.w0, tx_bits
    sub r15, r15, 1
    mov r25, r15
    qbne sbs_loop, r25, 0
sbs_done:
    CLK_LO
    mov r28.w0, r24          ; restore link
    jmp r28.w0

;========================================================================
; swd_jtag_to_swd (136 bits), swd_swd_to_jtag (80), etc.
;========================================================================
swd_jtag_to_swd:
    ldi32 r14, j2s_data
    ldi r15, 17
    jal r28.w0, send_byte_seq
    jmp r3.w2

swd_swd_to_jtag:
    ldi32 r14, s2j_data
    ldi r15, 10
    jal r28.w0, send_byte_seq
    jmp r3.w2

swd_swd_to_dormant:
    ldi32 r14, s2d_data
    ldi r15, 9
    jal r28.w0, send_byte_seq
    jmp r3.w2

swd_dormant_to_swd:
    ldi32 r14, d2s_data
    ldi r15, 28
    jal r28.w0, send_byte_seq
    jmp r3.w2

;========================================================================
; swd_custom_seq — r14=bytes, r15=bit count
;========================================================================
swd_custom_seq:
    jal r28.w0, tx_setup
    mov r25, r15
    qbeq cs_done, r25, 0
    lbbo &r26, r14, 0, 1
cs_loop:
    and r0, r26, 1
    lsr r26, r26, 1
    CLK_LO
    qbbs cs_hi, r0, 0
    DIO_LO
    qba cs_set
cs_hi:
    DIO_HI
cs_set:
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbeq cs_done, r25, 0
    mov r0, r25
    and r0, r0, 7
    qbne cs_loop, r0, 0
    add r14, r14, 1
    lbbo &r26, r14, 0, 1
    qba cs_loop
cs_done:
    CLK_LO
    DIO_LO
    jmp r3.w2

;========================================================================
; swd_read_reg — r14=SWD cmd byte (START|PARK preset), r15=data ptr
; Returns: r14 = ACK (1=OK, 2=WAIT, 4=FAULT)
;========================================================================
swd_read_reg:
    mov r22, r15             ; save data pointer

    jal r28.w0, tx_setup
    mov r26, r14
    ldi r25, 8
    jal r28.w0, tx_bits       ; send 8-bit command

    jal r28.w0, turnaround_input

    ; Read 3-bit ACK
    ldi r21, 0
    ldi r23, 1
    ldi r25, 3
    jal r28.w0, rx_bits
    mov r20, r21              ; r20 = ACK

    ; Read 32-bit data
    ldi r21, 0
    ldi r23, 1
    ldi r25, 32
    jal r28.w0, rx_bits
    sbbo &r21, r22, 0, 4     ; store to *data

    ; Read parity
    ldi r24, 0
    DELAY
    CLK_HI
    qbbc rd_pdone, r31, 9
    ldi r24, 1
rd_pdone:
    DELAY
    CLK_LO

    jal r28.w0, turnaround_output
    mov r14, r20
    jmp r3.w2

;========================================================================
; swd_write_reg — r14=SWD cmd byte, r15=value
; Returns: r14 = ACK
;========================================================================
swd_write_reg:
    mov r22, r15             ; save write value

    jal r28.w0, tx_setup
    mov r26, r14
    ldi r25, 8
    jal r28.w0, tx_bits

    jal r28.w0, turnaround_input

    ; Read ACK
    ldi r21, 0
    ldi r23, 1
    ldi r25, 3
    jal r28.w0, rx_bits
    mov r20, r21

    ; TRN cycle: switch to output mode
    CLK_LO
    ldi32 r16, PADCFG_DIO
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4
    DELAY         ; wait for pinmux switch to OUTPUT mode
    CLK_HI         ; TRN bit
    DELAY
    CLK_LO

    ; Pre-drive bit 0 — separate from TRN cycle
    and r0, r22, 1
    qbbs wr_hi, r0, 0
    DIO_LO
    qba wr_clk
wr_hi:
    DIO_HI
wr_clk:
    DELAY          ; setup
    CLK_HI          ; target samples bit 0
    DELAY
    CLK_LO

    ; Send bits 1-31
    mov r26, r22
    lsr r26, r26, 1
    ldi r25, 31
wr_txloop:
    and r0, r26, 1
    lsr r26, r26, 1
    CLK_LO
    qbbs wr_txhi, r0, 0
    DIO_LO
    qba wr_txset
wr_txhi:
    DIO_HI
wr_txset:
    DELAY
    CLK_HI
    DELAY
    sub r25, r25, 1
    qbne wr_txloop, r25, 0

    ; Parity
    mov r26, r22
    ldi r0, 0
    ldi r25, 32
wr_par:
    and r21, r26, 1
    xor r0, r0, r21
    lsr r26, r26, 1
    sub r25, r25, 1
    qbne wr_par, r25, 0
    CLK_LO
    qbbs wr_phi, r0, 0     ; r0=1(data odd) → parity=1 → total=even
    DIO_LO                 ; r0=0(data even) → parity=0 → total=even
    qba wr_pdone
wr_phi:
    DIO_HI                 ; r0=1(data odd) → parity=1 → total=even
wr_pdone:
    DELAY
    CLK_HI
    DELAY
    CLK_LO

    mov r14, r20
    jmp r3.w2

;========================================================================
; Sequence data
;========================================================================
    .sect ".rodata"
    .clink
j2s_data:
    .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0x9e,0xe7
    .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0x00
s2j_data:
    .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0x3c,0xe7, 0xff
s2d_data:
    .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0xbc,0xe3
d2s_data:
    .byte 0xff
    .byte 0x92,0xf3,0x09,0x62,0x95,0x2d,0x85,0x86
    .byte 0xe9,0xaf,0xdd,0xe3,0xa2,0x0e,0xbc,0x19
    .byte 0xa0,0xf1,0xff
    .byte 0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0x00

;========================================================================
; delay_fn — r18 = count. Uses r29.w0 as link (set by DELAY macro)
;========================================================================
    .sect ".text:delay"
    .clink
delay_fn:
    qbeq ddret, r18, 0
    mov r19, r18
ddloop:
    sub r19, r19, 1
    qbne ddloop, r19, 0
ddret:
    jmp r29.w0
