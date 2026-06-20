/* dap_engine.h - PRU SWD DAP Engine Interface
 *
 * High-level DAP operations with SELECT caching, RDBUFF pipeline,
 * and queue batching. Uses low-level SWD timing functions from swd.asm.
 *
 * Architecture:
 *   dap_engine.c (C)  → swd.asm (timing layer)
 *   - SELECT cache management
 *   - RDBUFF pipeline handling
 *   - Operation queue batching
 *   - Error recovery (sticky errors, ABORT)
 */

#ifndef DAP_ENGINE_H
#define DAP_ENGINE_H

#include <stdint.h>
#include <stdbool.h>

/* ========================================================================
 * SWD Low-level Interface (implemented in swd.asm)
 * ======================================================================== */

/* SWD command structure (8 bits):
 *   bit 0:    START (always 1)
 *   bit 1:    APnDP (0=DP, 1=AP)
 *   bit 2:    RnW (0=write, 1=read)
 *   bit 3-4:  A[3:2] (register address bits)
 *   bit 5:    Parity (odd parity of bits 1-4)
 *   bit 6:    STOP (always 0)
 *   bit 7:    PARK (always 1)
 */

/* SWD ACK values */
#define SWD_ACK_OK    1
#define SWD_ACK_WAIT  2
#define SWD_ACK_FAULT 4
#define SWD_ACK_JUNK  0  /* no response / protocol error */

/* Timing functions (swd.asm exports) */
extern void swd_init(void);
extern void swd_set_speed(uint8_t delay_cycles);
extern void swd_line_reset(void);
extern void swd_jtag_to_swd(void);
extern void swd_idle_cycles(uint8_t count);

/* Core protocol functions (swd.asm exports)
 * Returns: ACK value (SWD_ACK_OK/WAIT/FAULT)
 */
extern uint8_t swd_read_reg(uint8_t cmd, uint32_t *data);
extern uint8_t swd_write_reg(uint8_t cmd, uint32_t data);

/* ========================================================================
 * DAP Engine - High-level Interface
 * ======================================================================== */

/* DP register addresses (bits [3:0], need DPBANKSEL for reg!=0/4) */
#define DP_DPIDR      0x00  /* bank 0 */
#define DP_ABORT      0x00  /* write-only, no banksel */
#define DP_CTRL_STAT  0x04  /* bank 0 */
#define DP_DLCR       0x14  /* bank 1 */
#define DP_TARGETID   0x24  /* bank 2 */
#define DP_SELECT     0x08  /* no banksel */
#define DP_RDBUFF     0x0C  /* no banksel */

/* DP_ABORT bits */
#define DAPABORT      (1U << 0)
#define STKCMPCLR     (1U << 1)
#define STKERRCLR     (1U << 2)
#define WDERRCLR      (1U << 3)
#define ORUNERRCLR    (1U << 4)

/* DP_CTRL_STAT bits */
#define CORUNDETECT   (1U << 0)
#define SSTICKYORUN   (1U << 1)
#define SSTICKYCMP    (1U << 4)
#define SSTICKYERR    (1U << 5)
#define CDBGPWRUPREQ  (1U << 28)
#define CDBGPWRUPACK  (1U << 29)
#define CSYSPWRUPREQ  (1U << 30)
#define CSYSPWRUPACK  (1U << 31)

/* MEM-AP registers (ADIv5) */
#define MEM_AP_CSW    0x00
#define MEM_AP_TAR    0x04
#define MEM_AP_DRW    0x0C
#define MEM_AP_BD0    0x10
#define MEM_AP_BD1    0x14
#define MEM_AP_BD2    0x18
#define MEM_AP_BD3    0x1C
#define MEM_AP_CFG    0xF4
#define MEM_AP_BASE   0xF8
#define MEM_AP_IDR    0xFC

/* CSW bits */
#define CSW_SIZE_32BIT      0x02
#define CSW_ADDRINC_OFF     (0U << 4)
#define CSW_ADDRINC_SINGLE  (1U << 4)
#define CSW_ADDRINC_PACKED  (2U << 4)
#define CSW_DBGSWENABLE     (1U << 31)

/* ========================================================================
 * DAP Operation Queue
 * ======================================================================== */

/* Operation types */
typedef enum {
    DAP_OP_CONNECT = 0,
    DAP_OP_DP_READ,
    DAP_OP_DP_WRITE,
    DAP_OP_AP_READ,
    DAP_OP_AP_WRITE,
    DAP_OP_IDLE,
    DAP_OP_LINE_RESET,
    DAP_OP_JTAG_TO_SWD,
    DAP_OP_MEM_READ,    /* high-level: expanded to AP ops */
    DAP_OP_MEM_WRITE,
} dap_op_type_t;

/* Single operation descriptor */
typedef struct {
    uint8_t  type;       /* dap_op_type_t */
    uint8_t  ap_num;     /* AP number (for AP ops) */
    uint8_t  reg;        /* register address */
    uint8_t  ack;        /* returned ACK (SWD_ACK_OK/WAIT/FAULT) */
    uint32_t wdata;      /* write data */
    uint32_t rdata;      /* read data */
} dap_op_t;

#define DAP_QUEUE_SIZE 32

/* ========================================================================
 * DAP Engine API
 * ======================================================================== */

/**
 * Initialize DAP engine
 * - Calls swd_init()
 * - Resets SELECT cache, RDBUFF pipeline
 */
void dap_init(void);

/**
 * Connect to target
 * - Line reset, JTAG-to-SWD sequence
 * - Read DPIDR
 * - Clear sticky errors
 * Returns: 0 on success, -1 on failure
 */
int dap_connect(uint32_t *dpidr);

/**
 * Queue a DP read
 * reg: DP register address (DP_DPIDR, DP_CTRL_STAT, etc.)
 * Returns: queue index, or -1 if queue full
 */
int dap_queue_dp_read(uint8_t reg);

/**
 * Queue a DP write
 * reg: DP register address
 * data: value to write
 */
int dap_queue_dp_write(uint8_t reg, uint32_t data);

/**
 * Queue an AP read
 * ap_num: AP number (0-255)
 * reg: AP register address (MEM_AP_CSW, etc.)
 * Returns: queue index
 */
int dap_queue_ap_read(uint8_t ap_num, uint8_t reg);

/**
 * Queue an AP write
 */
int dap_queue_ap_write(uint8_t ap_num, uint8_t reg, uint32_t data);

/**
 * Execute all queued operations
 * - Automatic SELECT bankselect as needed
 * - Automatic RDBUFF pipeline flushing
 * Returns: 0 on success, -1 if any operation failed
 */
int dap_run_queue(void);

/**
 * Get result of a queued read operation
 * idx: queue index returned by dap_queue_xx_read()
 * data: pointer to store read value
 * Returns: ACK value
 */
uint8_t dap_get_result(int idx, uint32_t *data);

/**
 * Clear all queued operations without execution
 */
void dap_clear_queue(void);

/**
 * Get current queue length
 */
int dap_get_queue_len(void);

/**
 * Clear sticky errors
 * Returns: 0 on success
 */
int dap_clear_sticky_errors(void);

/**
 * Invalidate SELECT cache (e.g., after reconnect)
 */
void dap_invalidate_select(void);

/* ========================================================================
 * High-level Memory Operations (optional, for performance)
 * ======================================================================== */

/**
 * Read memory block (32-bit aligned)
 * ap_num: MEM-AP number (usually 0)
 * addr: target address (must be 32-bit aligned)
 * buf: destination buffer
 * count: number of bytes (must be multiple of 4)
 * Returns: 0 on success, -1 on error
 */
int dap_mem_read_block(uint8_t ap_num, uint32_t addr, uint8_t *buf, uint32_t count);

/**
 * Write memory block (32-bit aligned)
 */
int dap_mem_write_block(uint8_t ap_num, uint32_t addr, const uint8_t *buf, uint32_t count);

/* ========================================================================
 * Internal Helper Functions (exposed for testing, not for normal use)
 * ======================================================================== */

/**
 * Build SWD command byte
 * reg: register address (0-15, only bits [3:2] used)
 * apndp: 0=DP, 1=AP
 * rnw: 0=write, 1=read
 * Returns: 8-bit SWD command with START, parity, PARK bits set
 */
uint8_t dap_make_swd_cmd(uint8_t reg, bool apndp, bool rnw);

/**
 * Perform DP bankselect if needed
 * reg: DP register address (only handles reg[3:0] == 4)
 * Returns: 0 if no write needed or write succeeded, -1 on error
 */
int dap_dp_bankselect(uint8_t reg);

/**
 * Perform AP SELECT (APSEL + APBANKSEL)
 * ap_num: AP number
 * reg: AP register address
 * Returns: 0 if no write needed or write succeeded, -1 on error
 */
int dap_ap_select(uint8_t ap_num, uint8_t reg);

#endif /* DAP_ENGINE_H */
