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
CMD_BATCH  .set 8   ; batch: N mixed sub-commands from seq_buf
CMD_BRD    .set 9   ; batch read: N AP DRW reads, results in seq_buf

MB_RDBUFF .set 36  ; cached RDBUFF after AP read
MB_FLAGS  .set 40  ; bit0=has cached RDBUFF

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
    qbeq do_batch, r24, CMD_BATCH
    qbeq do_brd, r24, CMD_BRD
    qba finish

; ---- Batch read: r25=count. N AP DRW reads → seq_buf. Max ~47 words ----
do_brd:
    ldi32 r2, 0x1044         ; seq_buf
    mov  r6, r25             ; count
    ldi32 r5, 0x1100         ; scratch
    qbeq brd_done, r6, 0
brd_lp:
    ldi  r14, 0x9F           ; AP DRW read cmd (reload each iter—swd_read_reg clobbers r14)
    mov  r15, r5
    jal  r3.w2, swd_read_reg
    lbbo &r0, r5, 0, 4        ; data
    sbbo &r0, r2, 0, 4        ; store
    add  r2, r2, 4
    sub  r6, r6, 1
    qbne brd_lp, r6, 0
    ; Auto-cache RDBUFF after last read
    ldi  r14, 0xBD           ; DP RDBUFF read
    mov  r15, r5
    jal  r3.w2, swd_read_reg
    lbbo &r0, r5, 0, 4
    sbbo &r0, r4, MB_RDBUFF, 4
    ldi  r0, 1
    sbbo &r0, r4, MB_FLAGS, 4
brd_done:
    ldi  r21, 1
    ldi  r27, 0
    qba  finish

; ---- Batch: r25 sub-commands from seq_buf at MB+(r26*4) (2 words each) ----
do_batch:
    lsl  r2, r26, 2          ; byte offset = wdata * 4
    add  r2, r4, r2          ; r2 = MB + offset
    mov  r6, r25             ; count
    ldi32 r5, 0x1100         ; scratch for read data
    qbeq batch_done, r6, 0
batch_lp:
    lbbo &r20, r2, 0, 4      ; packed: [type:8][arg1:24]
    lbbo &r26, r2, 4, 4      ; arg2 (write data)
    mov  r24, r20
    and  r24, r24, 0xFF       ; type = low 8 bits
    lsr  r25, r20, 8          ; arg1 = high 24 bits
    ldi  r21, 1
    ldi  r27, 0
    qbeq batch_rd, r24, 1    ; CMD_SWD_READ
    qbeq batch_wr, r24, 2    ; CMD_SWD_WRITE
    qbeq batch_idle, r24, 5  ; CMD_IDLE
    qba  batch_next
batch_rd:
    mov  r14, r25
    mov  r15, r5
    jal  r3.w2, swd_read_reg
    mov  r21, r14
    lbbo &r27, r5, 0, 4
    qba  batch_next
batch_wr:
    mov  r14, r25
    mov  r15, r26
    jal  r3.w2, swd_write_reg
    mov  r21, r14
    qba  batch_next
batch_idle:
    mov  r14, r25
    jal  r3.w2, swd_idle_cycles
    qba  batch_next
batch_next:
    sbbo &r27, r2, 0, 4      ; rdata (overwrites packed word)
    sbbo &r21, r2, 4, 4      ; ack   (overwrites arg2)
    add  r2, r2, 8            ; advance 2 words
    sub  r6, r6, 1
    qbne batch_lp, r6, 0
batch_done:
    ldi  r21, 1
    ldi  r27, 0
    qba  finish

do_read:
    ; r25 = SWD cmd byte (START|PARK already set)
    mov  r14, r25
    ldi32 r15, 0x1100       ; scratch pointer for data
    jal  r3.w2, swd_read_reg  ; ack in r14, data at [r15]
    mov  r21, r14
    lbbo &r27, r15, 0, 4

    ; Auto-cache RDBUFF after AP reads (saves one mailbox round-trip)
    mov  r0, r25
    and  r0, r0, 2           ; test APnDP bit
    qbeq rd_done, r0, 0
    ldi  r14, 0xBD           ; DP RDBUFF read cmd: START|RnW|PARK|A32(reg12)|parity
    ldi32 r15, 0x1104
    jal  r3.w2, swd_read_reg
    lbbo &r0, r15, 0, 4
    sbbo &r0, r4, MB_RDBUFF, 4
    ldi  r0, 1
    sbbo &r0, r4, MB_FLAGS, 4
rd_done:
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
