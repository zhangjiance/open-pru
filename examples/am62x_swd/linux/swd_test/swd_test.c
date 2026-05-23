/*
 * swd_test.c - Test program for AM62x PRU-SWD
 *
 * This program demonstrates basic SWD operations using PRU
 * for ARM Cortex-M debugging via Serial Wire Debug protocol.
 *
 * Copyright (C) 2026
 * License: GPLv3+
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <errno.h>

// PRU DRAM base address for AM62x PRU0
#define PRU0_DRAM_BASE   0x4B030000
#define PRU0_DRAM_SIZE   0x2000

// RemoteProc control paths
#define RPROC_STATE      "/sys/class/remoteproc/remoteproc1/state"
#define RPROC_FIRMWARE   "/sys/class/remoteproc/remoteproc1/firmware"

// SWD Command definitions
#define CMD_HALT        0
#define CMD_BLINK       1
#define CMD_GPIO_OUT    2
#define CMD_GPIO_IN     3
#define CMD_SIG_IDLE    4
#define CMD_SIG_GEN     5
#define CMD_READ_REG    6
#define CMD_WRITE_REG   7

// Global pointer to PRU DRAM
static volatile uint32_t *pru_dram = NULL;

/*
 * Initialize PRU communication
 */
int pru_init(void)
{
    int fd;
    
    // Open /dev/mem
    fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("Failed to open /dev/mem");
        printf("Hint: Run with sudo\n");
        return -1;
    }
    
    // Map PRU0 DRAM
    pru_dram = (volatile uint32_t *)mmap(NULL, PRU0_DRAM_SIZE,
                                          PROT_READ | PROT_WRITE,
                                          MAP_SHARED, fd,
                                          PRU0_DRAM_BASE);
    close(fd);
    
    if (pru_dram == MAP_FAILED) {
        perror("Failed to mmap PRU DRAM");
        return -1;
    }
    
    printf("PRU DRAM mapped at %p\n", pru_dram);
    return 0;
}

/*
 * Cleanup PRU communication
 */
void pru_cleanup(void)
{
    if (pru_dram && pru_dram != MAP_FAILED) {
        munmap((void *)pru_dram, PRU0_DRAM_SIZE);
    }
}

/*
 * Send command to PRU and wait for completion
 */
int pru_command(uint8_t cmd)
{
    uint32_t initial_count, current_count;
    int timeout = 1000; // 1 second timeout
    
    // Read initial command counter
    initial_count = pru_dram[72/4];
    
    // Write command
    pru_dram[0] = cmd;
    
    // Trigger PRU via sysfs event (simplified - actual implementation
    // would use proper interrupt mechanism)
    
    // Wait for PRU to process command (counter increment)
    while (timeout-- > 0) {
        current_count = pru_dram[72/4];
        if (current_count != initial_count) {
            return 0; // Success
        }
        usleep(1000); // 1ms delay
    }
    
    printf("ERROR: PRU command timeout\n");
    return -1;
}

/*
 * Configure SWD speed
 */
void swd_set_speed(uint8_t delay_cycles)
{
    pru_dram[0] = delay_cycles; // Write to speed config offset
    printf("SWD speed configured: delay=%d cycles\n", delay_cycles);
}

/*
 * Blink test
 */
void test_blink(void)
{
    printf("\n=== Blink Test ===\n");
    printf("This will blink PRU GPO pins (if LEDs connected)\n");
    
    pru_dram[0] = CMD_BLINK;
    pru_dram[1] = 100000;  // delay
    pru_dram[2] = 10;      // count
    pru_dram[3] = 0;       // led bit (R30.0)
    
    printf("Command sent. Watch for blinking...\n");
    pru_command(CMD_BLINK);
    printf("Blink complete.\n");
}

/*
 * GPIO test
 */
void test_gpio(void)
{
    printf("\n=== GPIO Test ===\n");
    
    // Set GPIO high
    pru_dram[0] = CMD_GPIO_OUT;
    pru_dram[1] = 0x00000100; // bit=0, value=1
    pru_command(CMD_GPIO_OUT);
    printf("GPIO set high\n");
    
    sleep(1);
    
    // Set GPIO low
    pru_dram[0] = CMD_GPIO_OUT;
    pru_dram[1] = 0x00000000; // bit=0, value=0
    pru_command(CMD_GPIO_OUT);
    printf("GPIO set low\n");
}

/*
 * SWD Idle test
 */
void test_swd_idle(void)
{
    printf("\n=== SWD Idle Test ===\n");
    printf("Generating 50 idle cycles (CLK toggle, DIO low)\n");
    
    pru_dram[0] = CMD_SIG_IDLE;
    pru_dram[1] = 50; // 50 cycles
    
    pru_command(CMD_SIG_IDLE);
    printf("Idle cycles sent.\n");
}

/*
 * SWD Signal Pattern test
 */
void test_swd_pattern(void)
{
    printf("\n=== SWD Pattern Test ===\n");
    printf("Sending line reset pattern (52 bits of 1)\n");
    
    // Line reset: 52+ bits of 1
    uint8_t pattern[] = {
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F
    };
    
    pru_dram[0] = CMD_SIG_GEN;
    pru_dram[1] = 52; // bit count
    
    // Copy pattern
    memcpy((void *)&pru_dram[2], pattern, sizeof(pattern));
    
    pru_command(CMD_SIG_GEN);
    printf("Pattern sent.\n");
}

/*
 * SWD JTAG-to-SWD sequence
 */
void swd_jtag_to_swd(void)
{
    printf("\n=== JTAG to SWD Sequence ===\n");
    
    // JTAG-to-SWD sequence (16 bits selection + some resets)
    uint8_t sequence[] = {
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // Line reset
        0x9E, 0xE7,                         // JTAG-to-SWD pattern
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F  // Another line reset
    };
    
    pru_dram[0] = CMD_SIG_GEN;
    pru_dram[1] = sizeof(sequence) * 8; // bit count
    
    memcpy((void *)&pru_dram[2], sequence, sizeof(sequence));
    
    pru_command(CMD_SIG_GEN);
    printf("JTAG-to-SWD sequence sent.\n");
}

/*
 * Read IDCODE (demonstration - actual values depend on target)
 */
void test_read_idcode(void)
{
    printf("\n=== Read IDCODE Test ===\n");
    printf("NOTE: This requires a real SWD target connected!\n");
    
    // SWD READ IDCODE command
    // Format: 1-APnDP-RnW-A[2:3]-0-parity-1-park
    // IDCODE: AP=0, RnW=1, A=0, parity=1
    // Binary: 10100101
    uint8_t cmd = 0xA5;
    
    pru_dram[0] = CMD_READ_REG;
    pru_dram[1] = cmd;
    pru_dram[2] = 8; // idle cycles after transaction
    
    if (pru_command(CMD_READ_REG) == 0) {
        uint32_t ack_parity = pru_dram[64/4];
        uint32_t data = pru_dram[68/4];
        
        printf("ACK+Parity: 0x%08X\n", ack_parity);
        printf("Data:       0x%08X\n", data);
        
        uint8_t ack = ack_parity & 0x07;
        if (ack == 0x01) {
            printf("ACK OK! IDCODE = 0x%08X\n", data);
        } else {
            printf("ACK Error: 0x%02X\n", ack);
        }
    }
}

/*
 * Display PRU status
 */
void show_pru_status(void)
{
    FILE *fp;
    char buf[256];
    
    printf("\n=== PRU Status ===\n");
    
    // Read state
    fp = fopen(RPROC_STATE, "r");
    if (fp) {
        if (fgets(buf, sizeof(buf), fp)) {
            printf("PRU State: %s", buf);
        }
        fclose(fp);
    }
    
    // Read firmware
    fp = fopen(RPROC_FIRMWARE, "r");
    if (fp) {
        if (fgets(buf, sizeof(buf), fp)) {
            printf("Firmware:  %s", buf);
        }
        fclose(fp);
    }
    
    // Read command counter
    if (pru_dram) {
        printf("Cmd Count: %u\n", pru_dram[72/4]);
    }
}

/*
 * Display menu
 */
void show_menu(void)
{
    printf("\n");
    printf("========================================\n");
    printf("   AM62x PRU-SWD Test Program\n");
    printf("========================================\n");
    printf("\n");
    printf("Commands:\n");
    printf("  0 - Show PRU status\n");
    printf("  1 - Blink test\n");
    printf("  2 - GPIO test\n");
    printf("  3 - SWD idle cycles\n");
    printf("  4 - SWD line reset pattern\n");
    printf("  5 - JTAG-to-SWD sequence\n");
    printf("  6 - Read IDCODE (needs target)\n");
    printf("  s - Set SWD speed\n");
    printf("  q - Quit\n");
    printf("\n");
    printf("Choice: ");
}

int main(int argc, char *argv[])
{
    char choice;
    int speed;
    
    printf("AM62x PRU-SWD Test Program\n");
    printf("==========================\n\n");
    
    // Initialize PRU communication
    if (pru_init() < 0) {
        return 1;
    }
    
    // Main loop
    while (1) {
        show_menu();
        
        if (scanf(" %c", &choice) != 1) {
            break;
        }
        
        switch (choice) {
        case '0':
            show_pru_status();
            break;
            
        case '1':
            test_blink();
            break;
            
        case '2':
            test_gpio();
            break;
            
        case '3':
            test_swd_idle();
            break;
            
        case '4':
            test_swd_pattern();
            break;
            
        case '5':
            swd_jtag_to_swd();
            break;
            
        case '6':
            test_read_idcode();
            break;
            
        case 's':
        case 'S':
            printf("Enter delay cycles (7-78): ");
            if (scanf("%d", &speed) == 1) {
                swd_set_speed(speed);
            }
            break;
            
        case 'q':
        case 'Q':
            goto cleanup;
            
        default:
            printf("Invalid choice\n");
        }
    }
    
cleanup:
    printf("\nCleaning up...\n");
    pru_cleanup();
    printf("Goodbye!\n");
    
    return 0;
}
