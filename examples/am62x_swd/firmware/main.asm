; main.asm — Minimal PRU SWD Mailbox Loop
; Single-shot SWD operations. WAIT retry handled by ARM driver.
;
; Mailbox in PRU DRAM at offset 0x1000.

    .retain
    .retainrefs
    .global main
    .global swd_init
    .global swd_read_reg
    .global swd_write_reg
    .global swd_line_reset
    .global swd_jtag_to_swd
    .global swd_idle_cycles
    .sect ".text:main"

MB      .set 0x00001000
MB_CMD  .set 0
MB_PARAM .set 4
MB_WDATA .set 8
MB_RDATA .set 16
MB_ACK   .set 20
MB_STATUS .set 24
MB_SPEED .set 28
MB_DB    .set 64

CMD_READ  .set 1
CMD_WRITE .set 2
CMD_LR    .set 3   ; line reset
CMD_J2S   .set 4   ; JTAG-to-SWD
CMD_IDLE  .set 5
CMD_ABORT .set 6
CMD_CONNECT .set 7

main:
    ldi32 r4, MB

    ; Init pinmux
    jal  r3.w2, swd_init

    ; Init mailbox
    ldi  r0, 0
    sbbo &r0, r4, MB_CMD, 4
    sbbo &r0, r4, MB_STATUS, 4
    sbbo &r0, r4, MB_DB, 4
    ldi  r0, 10
    sbbo &r0, r4, MB_SPEED, 4
    ldi  r18, 10

poll:
    lbbo &r20, r4, MB_DB, 4
    qbeq poll, r20, 0

    ; Read params
    lbbo &r18, r4, MB_SPEED, 4
    lbbo &r24, r4, MB_CMD, 4
    lbbo &r25, r4, MB_PARAM, 4
    lbbo &r26, r4, MB_WDATA, 4

    ldi  r21, 1       ; ack = OK
    ldi  r27, 0       ; rdata = 0

    qbeq do_read, r24, CMD_READ
    qbeq do_write, r24, CMD_WRITE
    qbeq do_lr, r24, CMD_LR
    qbeq do_j2s, r24, CMD_J2S
    qbeq do_idle, r24, CMD_IDLE
    qbeq do_abort, r24, CMD_ABORT
    qbeq do_connect, r24, CMD_CONNECT
    qba finish

do_read:
    ; r25 = SWD cmd byte (START|PARK already set)
    mov  r14, r25
    ldi32 r15, 0x1100       ; scratch pointer for data
    jal  r3.w2, swd_read_reg  ; ack in r14, data at [r15]
    mov  r21, r14
    lbbo &r27, r15, 0, 4
    qba finish

do_write:
    mov  r14, r25
    mov  r15, r26
    jal  r3.w2, swd_write_reg
    mov  r21, r14
    qba finish

do_lr:
    jal  r3.w2, swd_line_reset
    qba finish

do_j2s:
    jal  r3.w2, swd_jtag_to_swd
    qba finish

do_idle:
    mov  r14, r25
    jal  r3.w2, swd_idle_cycles
    qba finish

do_abort:
    ; Write DP_ABORT register (clear sticky errors)
    ldi  r14, 0x81             ; START|PARK, DP write ABORT (reg 0, A32=0)
    ldi32 r15, 0x0000000F      ; STKCMPCLR|STKERRCLR|WDERRCLR|ORUNERRCLR (no DAPABORT!)
    jal  r3.w2, swd_write_reg
    mov  r21, r14
    qba finish

do_connect:
    ; Line reset + JTAG-to-SWD + read DPIDR
    jal  r3.w2, swd_line_reset
    jal  r3.w2, swd_jtag_to_swd
    ; Read DPIDR
    ldi  r14, 0xA5             ; START|RNW|PARK, A32=0, parity
    ldi32 r15, 0x1100
    jal  r3.w2, swd_read_reg
    mov  r21, r14
    lbbo &r27, r15, 0, 4
    ; Power up CTRL/STAT
    ldi  r14, 0xA9             ; START|PARK, reg=CTRL_STAT(4), Write
    ldi32 r15, 0x50000000      ; CDBGPWRUPREQ|CSYSPWRUPREQ
    jal  r3.w2, swd_write_reg
    qba finish

finish:
    sbbo &r27, r4, MB_RDATA, 4
    sbbo &r21, r4, MB_ACK, 4
    ldi  r0, 0
    qbeq setok, r21, 1        ; ACK_OK=1
    ldi  r0, 1
setok:
    sbbo &r0, r4, MB_STATUS, 4
    ldi  r0, 0
    sbbo &r0, r4, MB_DB, 4
    qba poll
