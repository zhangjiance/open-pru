/*
 * SWD IDCODE 读取 — 通过 RPMsg 将结果发送到 Linux
 *
 * PRU 固件：循环读取 SWD IDCODE，通过 RPMsg 发送给 Linux 用户空间
 * 使用 pru_rpmsg_send 主动发送，不依赖 ARM→PRU 中断握手
 */

#include <stdint.h>
#include <pru_intc.h>
#include <rsc_types.h>
#include <pru_rpmsg.h>
#include "resource_table.h"
#include "intc_map.h"

volatile register uint32_t __R31;

#ifndef HOST_INT_BIT
#error "HOST_INT_BIT not defined"
#endif
#define HOST_INT			((uint32_t) 1 << HOST_INT_BIT)

#ifndef TO_ARM_HOST
#error "TO_ARM_HOST not defined"
#endif
#ifndef FROM_ARM_HOST
#error "FROM_ARM_HOST not defined"
#endif
#define FROM_ARM_HOST_BIT		((uint32_t) 1 << FROM_ARM_HOST)

#define CHAN_NAME                       "rpmsg-raw"

#ifndef CHAN_PORT
#error "CHAN_PORT not defined"
#endif

#define VIRTIO_CONFIG_S_DRIVER_OK	4

/* SWD 读取结果结构体 */
struct swd_result {
    uint32_t ack;      /* 正常应为 0b001 = 1 */
    uint32_t idcode;   /* 32-bit IDCODE */
    uint32_t parity;   /* 校验位 */
};

/* 汇编函数声明 */
extern void swd_init(void);
extern void swd_read_idcode(volatile struct swd_result *result);

/* RPMsg 发送缓冲区 */
uint8_t payload[64];

static const char hexchars[] = "0123456789abcdef";

/* 手动格式化: "[N] ACK=0x__ IDCODE=0x________ Parity=_\r\n" */
static int format_result(char *buf, uint32_t count, struct swd_result *r)
{
    int i, pos = 0;
    uint32_t val;

    if (count >= 1000) buf[pos++] = '0' + (count / 1000) % 10;
    if (count >= 100)  buf[pos++] = '0' + (count / 100) % 10;
    if (count >= 10)   buf[pos++] = '0' + (count / 10) % 10;
    buf[pos++] = '0' + count % 10;

    buf[pos++] = ' '; buf[pos++] = 'A'; buf[pos++] = 'C'; buf[pos++] = 'K';
    buf[pos++] = '='; buf[pos++] = '0'; buf[pos++] = 'x';
    buf[pos++] = hexchars[(r->ack >> 4) & 0xF];
    buf[pos++] = hexchars[r->ack & 0xF];

    buf[pos++] = ' '; buf[pos++] = 'I'; buf[pos++] = 'D'; buf[pos++] = 'C';
    buf[pos++] = 'O'; buf[pos++] = 'D'; buf[pos++] = 'E';
    buf[pos++] = '='; buf[pos++] = '0'; buf[pos++] = 'x';
    val = r->idcode;
    for (i = 7; i >= 0; i--) {
        buf[pos++] = hexchars[(val >> (i * 4)) & 0xF];
    }

    buf[pos++] = ' '; buf[pos++] = 'P'; buf[pos++] = 'a'; buf[pos++] = 'r';
    buf[pos++] = 'i'; buf[pos++] = 't'; buf[pos++] = 'y'; buf[pos++] = '=';
    buf[pos++] = '0' + (r->parity & 1);

    buf[pos++] = '\r';
    buf[pos++] = '\n';

    return pos;
}

void main(void)
{
    struct pru_rpmsg_transport transport;
    volatile uint8_t *status;
    struct swd_result result;
    uint32_t count = 0;
    int msg_len;

    /* 清除 PRU 系统事件状态 */
    CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;

    /* 等待 Linux RPMsg 驱动就绪 */
    status = &resourceTable.rpmsg_vdev.status;
    while (!(*status & VIRTIO_CONFIG_S_DRIVER_OK));

    /* 初始化 RPMsg 传输 */
    pru_rpmsg_init(&transport, &resourceTable.rpmsg_vring0,
                   &resourceTable.rpmsg_vring1,
                   TO_ARM_HOST, FROM_ARM_HOST);

    /* 创建 RPMsg 通道 */
    pru_rpmsg_channel(RPMSG_NS_CREATE, &transport, CHAN_NAME, CHAN_PORT);

    /* 一次性初始化 SWD pinmux */
    swd_init();

    /* 主循环：读取 IDCODE 并发送到 Linux
     * 不依赖 ARM→PRU 中断握手，直接用固定地址发送
     * pru_rpmsg_send(transport, src, dst, data, len)
     *   src = CHAN_PORT (30, PRU 的端点地址)
     *   dst = 0x400 (1024, Linux rpmsg_char 的端点地址)
     */
    while (1) {
        /* 调用汇编函数读取 SWD IDCODE */
        swd_read_idcode(&result);

        /* 格式化结果字符串 */
        count++;
        msg_len = format_result((char *)payload, count, &result);

        /* 通过 RPMsg 发送到 Linux */
        pru_rpmsg_send(&transport, CHAN_PORT, 0x400, payload, msg_len);

        /* 简单延时（约 500ms） */
        {
            volatile uint32_t delay = 8000000;
            while (delay--) {
                __asm__ volatile(" or r0, r0, r0");
            }
        }
    }
}
