; swd.asm - SWD IDCODE 读取汇编函数（C 可调用）
; CLK: R30.8 (U22) - PADCONFIG46 @ 0x000F40B8
; DIO: R30.9/R31.9 (V24) - PADCONFIG47 @ 0x000F40BC
;
; 函数:
;   void swd_init(void)     — 一次性 pinmux 初始化，仅调用一次
;   void swd_read_idcode(volatile uint32_t *result)
;      参数: R14 = 指向 result[3] 的指针
;      result[0] = ACK, result[1] = IDCODE, result[2] = Parity

    .retain
    .retainrefs
    .sect ".text:swd"
    .clink
    .global swd_init
    .global swd_read_idcode

; Pinmux 控制常量
    .asg 0x00101008, KICK0_ADDR
    .asg 0x0010100C, KICK1_ADDR
    .asg 0x68EF3490, KICK0_UNLOCK
    .asg 0xD172BC5A, KICK1_UNLOCK
    .asg 0x000F40B8, PADCFG_CLK_ADDR
    .asg 0x000F40BC, PADCFG_DIO_ADDR
    .asg 0x000F40F8, PADCFG_AB24_ADDR
    .asg 0x00050005, MODE_CLK_OUT
    .asg 0x00050005, MODE_DIO_OUT
    .asg 0x00060006, MODE_DIO_RX
    .asg 0x00060007, MODE_AB24_PU

; 内联延时宏（SWD CLK）：1 个 nop，用于 SWD CLK 半周期
DELAY .macro
    nop
    .endm

; Pinmux 等待宏（固定延时，不受 SWD 频率影响）
PDELAY .macro
    nop
    .endm

;======================================================================
; swd_init — 一次性 pinmux 配置（解锁 MMR 并设置 CLK/AB24/DIO 引脚）
;======================================================================
swd_init:
    ; 解锁 MMR（只需一次）
    ldi32 r16, KICK0_ADDR
    ldi32 r17, KICK0_UNLOCK
    sbbo &r17, r16, 0, 4
    ldi32 r16, KICK1_ADDR
    ldi32 r17, KICK1_UNLOCK
    sbbo &r17, r16, 0, 4

    ; CLK 引脚为输出
    ldi32 r16, PADCFG_CLK_ADDR
    ldi32 r17, MODE_CLK_OUT
    sbbo &r17, r16, 0, 4

    ; AB24 为输入上拉
    ldi32 r16, PADCFG_AB24_ADDR
    ldi32 r17, MODE_AB24_PU
    sbbo &r17, r16, 0, 4

    ; DIO 初始为输出
    ldi32 r16, PADCFG_DIO_ADDR
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4

    jmp r3.w2

;======================================================================
; swd_read_idcode — 执行一次 SWD IDCODE 读取
;======================================================================
swd_read_idcode:
    ;========================================
    ; 切换 DIO 为 TX 模式，等待生效
    ;========================================
    ldi32 r16, PADCFG_DIO_ADDR
    ldi32 r17, MODE_DIO_OUT
    sbbo &r17, r16, 0, 4

    ;========================================
    ; Line Reset：55 个 CLK 周期，DIO=1
    ;========================================
    set r30.t9
    ldi r25, 55
reset_loop:
    clr r30.t8
    DELAY
    set r30.t8
    DELAY
    sub r25, r25, 1
    qbne reset_loop, r25, 0

    ;========================================
    ; 空闲周期：2 个 CLK 周期，DIO=0
    ;========================================
    clr r30.t9
    ldi r25, 2
idle_loop:
    clr r30.t8
    DELAY
    set r30.t8
    DELAY
    sub r25, r25, 1
    qbne idle_loop, r25, 0

    ;========================================
    ; 发送 SWD 命令：0xA5（LSB first）
    ;========================================
    ldi r26, 0xA5
    ldi r25, 8

send_cmd_loop:
    and r27, r26, 1
    lsr r26, r26, 1

    clr r30.t8
    qbbs set_dio_high, r27, 0
    clr r30.t9
    qba dio_set
set_dio_high:
    set r30.t9
dio_set:
    DELAY

    set r30.t8
    DELAY

    sub r25, r25, 1
    qbne send_cmd_loop, r25, 0

    ;========================================
    ; TRN 转向周期：释放 DIO，切换到 RX（MMR 已解锁）
    ;========================================
    clr r30.t8
    clr r30.t9
    DELAY

    ldi32 r16, PADCFG_DIO_ADDR
    ldi32 r17, MODE_DIO_RX
    sbbo &r17, r16, 0, 4

    set r30.t8
    DELAY

    ;========================================
    ; 读取 ACK（3 bit）→ R20
    ;========================================
    ldi r20, 0
    ldi r25, 3
    ldi r23, 1

read_ack_loop:
    clr r30.t8
    sub r25, r25, 1
    DELAY
    nop
    nop
    set r30.t8
    DELAY

    qbbc ack_bit_zero, r31, 9
    or r20, r20, r23
ack_bit_zero:
    lsl r23, r23, 1

    qbne read_ack_loop, r25, 0

    ;========================================
    ; 读取 IDCODE（32 bit）→ R21
    ldi r21, 0
    ldi r23, 1
    ; bit 0
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id0, r31, 9
    or r21, r21, r23
id0: lsl r23, r23, 1
    ; bit 1
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id1, r31, 9
    or r21, r21, r23
id1: lsl r23, r23, 1
    ; bit 2
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id2, r31, 9
    or r21, r21, r23
id2: lsl r23, r23, 1
    ; bit 3
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id3, r31, 9
    or r21, r21, r23
id3: lsl r23, r23, 1
    ; bit 4
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id4, r31, 9
    or r21, r21, r23
id4: lsl r23, r23, 1
    ; bit 5
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id5, r31, 9
    or r21, r21, r23
id5: lsl r23, r23, 1
    ; bit 6
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id6, r31, 9
    or r21, r21, r23
id6: lsl r23, r23, 1
    ; bit 7
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id7, r31, 9
    or r21, r21, r23
id7: lsl r23, r23, 1
    ; bit 8
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id8, r31, 9
    or r21, r21, r23
id8: lsl r23, r23, 1
    ; bit 9
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id9, r31, 9
    or r21, r21, r23
id9: lsl r23, r23, 1
    ; bit 10
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id10, r31, 9
    or r21, r21, r23
id10: lsl r23, r23, 1
    ; bit 11
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id11, r31, 9
    or r21, r21, r23
id11: lsl r23, r23, 1
    ; bit 12
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id12, r31, 9
    or r21, r21, r23
id12: lsl r23, r23, 1
    ; bit 13
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id13, r31, 9
    or r21, r21, r23
id13: lsl r23, r23, 1
    ; bit 14
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id14, r31, 9
    or r21, r21, r23
id14: lsl r23, r23, 1
    ; bit 15
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id15, r31, 9
    or r21, r21, r23
id15: lsl r23, r23, 1
    ; bit 16
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id16, r31, 9
    or r21, r21, r23
id16: lsl r23, r23, 1
    ; bit 17
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id17, r31, 9
    or r21, r21, r23
id17: lsl r23, r23, 1
    ; bit 18
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id18, r31, 9
    or r21, r21, r23
id18: lsl r23, r23, 1
    ; bit 19
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id19, r31, 9
    or r21, r21, r23
id19: lsl r23, r23, 1
    ; bit 20
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id20, r31, 9
    or r21, r21, r23
id20: lsl r23, r23, 1
    ; bit 21
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id21, r31, 9
    or r21, r21, r23
id21: lsl r23, r23, 1
    ; bit 22
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id22, r31, 9
    or r21, r21, r23
id22: lsl r23, r23, 1
    ; bit 23
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id23, r31, 9
    or r21, r21, r23
id23: lsl r23, r23, 1
    ; bit 24
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id24, r31, 9
    or r21, r21, r23
id24: lsl r23, r23, 1
    ; bit 25
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id25, r31, 9
    or r21, r21, r23
id25: lsl r23, r23, 1
    ; bit 26
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id26, r31, 9
    or r21, r21, r23
id26: lsl r23, r23, 1
    ; bit 27
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id27, r31, 9
    or r21, r21, r23
id27: lsl r23, r23, 1
    ; bit 28
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id28, r31, 9
    or r21, r21, r23
id28: lsl r23, r23, 1
    ; bit 29
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id29, r31, 9
    or r21, r21, r23
id29: lsl r23, r23, 1
    ; bit 30
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id30, r31, 9
    or r21, r21, r23
id30: lsl r23, r23, 1
    ; bit 31
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    qbbc id31, r31, 9
    or r21, r21, r23
id31: lsl r23, r23, 1
    ;========================================
    ; 读取校验位（1 bit）→ R24
    ;========================================
    clr r30.t8
    DELAY
    nop
    nop
    set r30.t8
    DELAY
    ldi r24, 0
    qbbc parity_done, r31, 9
    ldi r24, 1
parity_done:

    ;========================================
    ; 写入结果
    ;========================================
    sbbo &r20, r14, 0, 4
    sbbo &r21, r14, 4, 4
    sbbo &r24, r14, 8, 4

    jmp r3.w2
