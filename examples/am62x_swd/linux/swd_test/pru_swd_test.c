/*
 * pru_swd_test.c — Standalone PRU SWD Mailbox Test
 *
 * Tests PRU SWD firmware via direct mailbox communication.
 * Compile: gcc -o pru_swd_test pru_swd_test.c
 * Run: sudo ./pru_swd_test
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

/* PRU DRAM at ARM phys 0x30040000 (from DTS) */
#define PRU_DRAM_BASE   0x30040000
#define PRU_DRAM_SIZE   0x2000
#define MB_OFFSET       0x1000

/* Mailbox offsets (32-bit words) */
enum { MB_CMD=0, MB_PARAM=1, MB_WDATA=2, MB_RESV=3,
       MB_RDATA=4, MB_ACK=5, MB_STATUS=6, MB_SPEED=7,
       MB_DOORBELL=16 };

/* Commands matching main.asm */
#define CMD_SWD_READ   1
#define CMD_SWD_WRITE  2
#define CMD_LR         3
#define CMD_J2S        4
#define CMD_IDLE       5
#define CMD_ABORT      6
#define CMD_CONNECT    7

static volatile uint32_t *dram, *mb;
static uint32_t db_seq = 1;

int pru_cmd(uint32_t cmd, uint32_t param, uint32_t wdata)
{
    mb[MB_CMD]    = cmd;
    mb[MB_PARAM]  = param;
    mb[MB_WDATA]  = wdata;
    __sync_synchronize();
    if (++db_seq == 0) db_seq = 1;
    mb[MB_DOORBELL] = db_seq;
    __sync_synchronize();

    /* Poll with timeout */
    for (int timeout = 0; timeout < 1000000; timeout++) {
        if (mb[MB_DOORBELL] == 0) {
            uint32_t ack = mb[MB_ACK] & 0x7;
            uint32_t rdata = mb[MB_RDATA];
            printf("  OK: ack=%u rdata=0x%08X status=%u\n",
                   ack, rdata, mb[MB_STATUS]);
            return 0;
        }
    }
    printf("  TIMEOUT! doorbell still 0x%X\n", mb[MB_DOORBELL]);
    return -1;
}

int main(void)
{
    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/mem"); return 1; }

    dram = mmap(NULL, PRU_DRAM_SIZE, PROT_READ|PROT_WRITE, MAP_SHARED,
                fd, PRU_DRAM_BASE);
    close(fd);
    if (dram == MAP_FAILED) { perror("mmap"); return 1; }

    mb = dram + MB_OFFSET/4;
    printf("PRU DRAM mapped. Mailbox at %p (phys 0x%X)\n",
           (void*)mb, PRU_DRAM_BASE + MB_OFFSET);

    /* Init mailbox */
    mb[MB_SPEED] = 55;  /* ~1 MHz */
    mb[MB_DOORBELL] = 0;
    __sync_synchronize();

    printf("\n=== Test 1: Line Reset ===\n");
    pru_cmd(CMD_LR, 0, 0);
    usleep(10000);

    printf("\n=== Test 2: JTAG-to-SWD ===\n");
    pru_cmd(CMD_J2S, 0, 0);
    usleep(10000);

    printf("\n=== Test 3: Read DPIDR (SWD cmd 0xA5) ===\n");
    if (pru_cmd(CMD_SWD_READ, 0xA5, 0) == 0)
        printf("  DPIDR = 0x%08X\n", mb[MB_RDATA]);
    usleep(10000);

    printf("\n=== Test 4: Write DP_ABORT ===\n");
    pru_cmd(CMD_SWD_WRITE, 0x81, 0x0000000F);
    usleep(10000);

    printf("\n=== Test 5: Idle 8 cycles ===\n");
    pru_cmd(CMD_IDLE, 8, 0);
    usleep(10000);

    printf("\n=== Test 6: Connect (LR+J2S+DPIDR+PowerUp) ===\n");
    pru_cmd(CMD_CONNECT, 0, 0);
    usleep(10000);

    printf("\nDone.\n");
    munmap((void*)dram, PRU_DRAM_SIZE);
    return 0;
}
