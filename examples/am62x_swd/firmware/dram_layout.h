/*
 * PRU SWD Zero-Copy DRAM Layout
 * 
 * Physical DRAM: 0x30040000 - 0x30041FFF (8KB)
 * 
 * Layout:
 *   0x0000 - 0x0FFF (4KB): PRU workspace (stack, locals)
 *   0x1000 - 0x103F (64B): Control block (pru_control_t)
 *   0x1040 - 0x17FF (1.75KB): Ring queue (64 × dap_op_t)
 *   0x1800 - 0x1FFF (2KB): Data buffer (for MEM_READ/WRITE)
 */

#ifndef DRAM_LAYOUT_H
#define DRAM_LAYOUT_H

#include <stdint.h>

/* DRAM memory offsets */
#define DRAM_CONTROL_OFFSET  0x1000
#define DRAM_QUEUE_OFFSET    0x1040
#define DRAM_DATA_OFFSET     0x1800

/* Queue configuration */
#define QUEUE_SIZE           64
#define DATA_BUFFER_SIZE     2048

/* DAP operation types */
typedef enum {
    DAP_OP_NONE = 0,
    
    /* Basic operations */
    DAP_OP_DP_READ,
    DAP_OP_DP_WRITE,
    DAP_OP_AP_READ,
    DAP_OP_AP_WRITE,
    
    /* High-level operations (auto-expanded by PRU) */
    DAP_OP_MEM_READ,      /* Auto CSW+TAR+DRW loop */
    DAP_OP_MEM_WRITE,
    
    /* Control operations */
    DAP_OP_CONNECT,       /* SWD init sequence */
    DAP_OP_DISCONNECT,
    DAP_OP_LINE_RESET,
    DAP_OP_JTAG_TO_SWD,
} dap_op_type_t;

/* DAP operation structure (48 bytes) */
typedef struct {
    /* Operation type and flags (4B) */
    uint32_t type      : 8;   /* dap_op_type_t */
    uint32_t flags     : 8;   /* Reserved flags */
    uint32_t ap_num    : 8;   /* AP number (0-255) */
    uint32_t reserved1 : 8;
    
    /* Register/address (4B) */
    uint32_t reg;             /* DP/AP register or memory address (low 32-bit) */
    
    /* Data (8B) */
    uint32_t wdata;           /* Write data */
    uint32_t rdata;           /* Read data (filled by PRU) */
    
    /* Status (4B) */
    uint32_t ack       : 3;   /* SWD ACK (1=OK, 2=WAIT, 4=FAULT) */
    uint32_t status    : 5;   /* Status code (0=success) */
    uint32_t reserved2 : 24;
    
    /* Memory operation extension (24B) */
    uint32_t addr_hi;         /* High 32-bit address (for MEM_READ/WRITE) */
    uint32_t count;           /* Transfer byte count (for MEM_READ/WRITE) */
    uint32_t csw_value;       /* CSW config value (for MEM_READ/WRITE) */
    uint32_t data_offset;     /* Offset in data_buffer (for MEM_READ/WRITE) */
    uint32_t reserved3;
    uint32_t reserved4;
    uint32_t _pad;            /* Explicit padding: ARM GCC=48B = PRU clpru=48B */
} dap_op_t;

/* Control block structure (64 bytes) */
typedef struct {
    /* Synchronization control (16B) */
    volatile uint32_t doorbell;       /* ARM writes 1, PRU clears to 0 */
    volatile uint32_t status;         /* PRU status (0=idle, 1=busy, 2=error) */
    volatile uint32_t queue_head;     /* PRU writes (consumer pointer) */
    volatile uint32_t queue_tail;     /* ARM writes (producer pointer) */
    
    /* Queue configuration (8B) */
    uint32_t queue_size;              /* Fixed to 64 */
    uint32_t total_ops;               /* Total operations processed */
    
    /* Error information (4B) */
    uint32_t error_count;             /* Error counter */
    
    /* SELECT cache (8B) */
    uint32_t select_cache;            /* Current SELECT value */
    uint32_t select_valid : 1;        /* SELECT cache valid flag */
    uint32_t connected    : 1;        /* SWD connected status */
    uint32_t reserved_flags : 30;
    
    /* SWD configuration (4B) */
    uint32_t swd_speed;               /* Clock speed in kHz */
    
    /* Reserved for extension (24B) */
    uint32_t reserved[6];
} pru_control_t;

/* DRAM layout structure */
typedef struct {
    pru_control_t control;                      /* 0x1000: Control block (64B) */
    dap_op_t queue[QUEUE_SIZE];                 /* 0x1040: Ring queue (64×48B = 3KB) */
    uint8_t data_buffer[DATA_BUFFER_SIZE];      /* 0x1800: Data buffer (2KB) */
} pru_dram_layout_t;

#endif /* DRAM_LAYOUT_H */
