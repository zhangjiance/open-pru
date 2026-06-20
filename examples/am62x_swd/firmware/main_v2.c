/*
 * PRU SWD Zero-Copy Main Loop (V2)
 * 
 * Ring queue processor - no debug prints (IRAM/DRAM constrained)
 * Test cases run on ARM side
 */

#include <stdint.h>
#include "dram_layout.h"

/* PRU DRAM base (from PRU perspective, DRAM starts at 0x0000) */
#define PRU_DRAM_BASE  ((volatile uint8_t *)0x00000000)

/* DRAM pointers */
volatile pru_control_t *ctrl;
volatile dap_op_t *queue;
volatile uint8_t *data_buffer;

/* External assembly functions (from swd.asm) */
extern void swd_init(void);
extern void swd_set_speed(uint32_t delay_cycles);
extern void swd_line_reset(void);
extern void swd_jtag_to_swd(void);
extern uint32_t swd_read_reg(uint32_t cmd, uint32_t *data_ptr);
extern uint32_t swd_write_reg(uint32_t cmd, uint32_t data);
extern void swd_idle_cycles(uint32_t count);

/* SELECT register cache */
static uint32_t select_cache;
static uint32_t select_valid;

/* SWD command byte generation */
static inline uint32_t make_swd_cmd(uint32_t APnDP, uint32_t RnW, uint32_t addr)
{
    uint32_t cmd = 0x81;  /* START=1, PARK=1 */
    cmd |= (APnDP << 1);
    cmd |= (RnW << 2);
    cmd |= ((addr & 0xC) << 1);  /* A[3:2] → bits 4:3 */
    
    /* Parity: XOR of APnDP, RnW, A[3:2] */
    uint32_t parity = APnDP ^ RnW ^ ((addr >> 2) & 1) ^ ((addr >> 3) & 1);
    cmd |= (parity << 5);
    
    return cmd;
}

/* DP bankselect */
static uint32_t dp_bankselect(uint32_t dp_bank)
{
    uint32_t new_select = (select_cache & 0xFFFFFFF0) | (dp_bank & 0xF);
    
    if (select_valid && (new_select == select_cache))
        return 1;  /* No change */
    
    /* Write SELECT register */
    uint32_t cmd = make_swd_cmd(0, 0, 0x8);  /* DP, WRITE, SELECT */
    uint32_t ack = swd_write_reg(cmd, new_select);
    
    if (ack == 1) {
        select_cache = new_select;
        select_valid = 1;
    }
    
    return ack;
}

/* AP bankselect (preserves DP bank) */
static uint32_t ap_bankselect(uint32_t ap_num, uint32_t ap_bank)
{
    uint32_t dp_bank = select_cache & 0xF;
    uint32_t new_select = (ap_num << 24) | ((ap_bank & 0xF) << 4) | dp_bank;
    
    if (select_valid && (new_select == select_cache))
        return 1;
    
    uint32_t cmd = make_swd_cmd(0, 0, 0x8);
    uint32_t ack = swd_write_reg(cmd, new_select);
    
    if (ack == 1) {
        select_cache = new_select;
        select_valid = 1;
    }
    
    return ack;
}

/* Execute DP read */
static void exec_dp_read(volatile dap_op_t *op)
{
    uint32_t dp_bank = (op->reg >> 4) & 0xF;
    
    if ((op->reg & 0xF) == 0x4) {  /* Banked register */
        uint32_t ack = dp_bankselect(dp_bank);
        if (ack != 1) { op->ack = ack; return; }
    }
    
    /* WORKAROUND: STM32F0 DPv0 returns DP read data immediately (not pipelined)
     * This is observed on logic analyzer - all DP reads return data in same transaction.
     * TODO: Check if this is DPv0 specific or target-specific behavior.
     */
    uint32_t cmd = make_swd_cmd(0, 1, op->reg);  /* DP, READ */
    uint32_t data;
    op->ack = swd_read_reg(cmd, &data);
    op->rdata = data;
    op->status = (op->ack == 1) ? 0 : 1;
}

/* Execute DP write */
static void exec_dp_write(volatile dap_op_t *op)
{
    uint32_t dp_bank = (op->reg >> 4) & 0xF;
    
    if ((op->reg & 0xF) == 0x4) {
        uint32_t ack = dp_bankselect(dp_bank);
        if (ack != 1) { op->ack = ack; return; }
    }
    
    uint32_t cmd = make_swd_cmd(0, 0, op->reg);  /* DP, WRITE */
    op->ack = swd_write_reg(cmd, op->wdata);
    op->status = (op->ack == 1) ? 0 : 1;
}

/* Execute AP read */
static void exec_ap_read(volatile dap_op_t *op)
{
    uint32_t ap_bank = (op->reg >> 4) & 0xF;
    uint32_t ack = ap_bankselect(op->ap_num, ap_bank);
    if (ack != 1) { 
        op->ack = ack; 
        op->status = 1;
        return; 
    }
    
    /* AP registers: data comes via RDBUFF (ADIv5 pipeline) */
    uint32_t cmd = make_swd_cmd(1, 1, op->reg);  /* AP, READ */
    uint32_t dummy;
    ack = swd_read_reg(cmd, &dummy);
    if (ack != 1) { 
        op->ack = ack;
        op->status = 1;
        return; 
    }
    
    /* Read RDBUFF to get actual data */
    cmd = make_swd_cmd(0, 1, 0xC);  /* DP, READ, RDBUFF */
    op->ack = swd_read_reg(cmd, (uint32_t*)&op->rdata);
    op->status = (op->ack == 1) ? 0 : 1;
}

/* Execute AP write */
static void exec_ap_write(volatile dap_op_t *op)
{
    uint32_t ap_bank = (op->reg >> 4) & 0xF;
    uint32_t ack = ap_bankselect(op->ap_num, ap_bank);
    if (ack != 1) {
        op->ack = ack;
        op->status = 1;
        return;
    }
    
    uint32_t cmd = make_swd_cmd(1, 0, op->reg);  /* AP, WRITE */
    op->ack = swd_write_reg(cmd, op->wdata);
    op->status = (op->ack == 1) ? 0 : 1;
}

/* Execute MEM_READ (auto CSW+TAR+DRW loop) */
static void exec_mem_read(volatile dap_op_t *op)
{
    /* Write CSW */
    ap_bankselect(op->ap_num, 0);
    uint32_t cmd = make_swd_cmd(1, 0, 0x00);  /* AP, WRITE, CSW */
    uint32_t ack = swd_write_reg(cmd, op->csw_value);
    if (ack != 1) { op->ack = ack; return; }
    
    /* Write TAR */
    cmd = make_swd_cmd(1, 0, 0x04);  /* AP, WRITE, TAR */
    ack = swd_write_reg(cmd, op->reg);
    if (ack != 1) { op->ack = ack; return; }
    
    /* Read DRW loop */
    uint32_t words = op->count / 4;
    uint32_t *buf = (uint32_t *)&data_buffer[op->data_offset];
    uint32_t i;
    cmd = make_swd_cmd(1, 1, 0x0C);  /* AP, READ, DRW */
    
    for (i = 0; i < words; i++) {
        uint32_t data;
        ack = swd_read_reg(cmd, &data);
        if (ack != 1) { op->ack = ack; return; }
        buf[i] = data;
    }
    
    op->ack = 1;
    op->status = 0;
}

/* Execute single operation */
static void execute_op(volatile dap_op_t *op)
{
    switch (op->type) {
    case DAP_OP_DP_READ:
        exec_dp_read(op);
        break;
    case DAP_OP_DP_WRITE:
        exec_dp_write(op);
        break;
    case DAP_OP_AP_READ:
        exec_ap_read(op);
        break;
    case DAP_OP_AP_WRITE:
        exec_ap_write(op);
        break;
    case DAP_OP_MEM_READ:
        exec_mem_read(op);
        break;
    case DAP_OP_CONNECT:
        /* SWD connection sequence (ADIv5 spec B4.3.3) */
        swd_line_reset();
        swd_jtag_to_swd();
        
        /* Read IDCODE to exit reset state
         * SPECIAL CASE: DPIDR/IDCODE returns data immediately (not pipelined!)
         * This is an exception to the normal ADIv5 read pipeline rule.
         */
        {
            uint32_t cmd = make_swd_cmd(0, 1, 0x0);  /* DP, READ, DPIDR */
            
            /* Write directly to volatile op->rdata to avoid compiler optimization */
            op->rdata = 0;
            op->ack = swd_read_reg(cmd, (uint32_t*)&op->rdata);
        }
        
        /* Write ABORT + drain RDBUFF (exactly matching CMSIS-DAP sequence) */
        {
            uint32_t cmd = make_swd_cmd(0, 0, 0x00);  /* DP, WRITE, ABORT */
            swd_write_reg(cmd, 0x1E);  /* STKCMPCLR|STKERRCLR|WDERRCLR|ORUNERRCLR */
            
            /* Drain pipeline — CMSIS-DAP always reads RDBUFF after ABORT */
            cmd = make_swd_cmd(0, 1, 0xC);  /* DP, READ, RDBUFF */
            uint32_t drain;
            swd_read_reg(cmd, &drain);
        }
        
        select_valid = 0;
        ctrl->connected = 1;
        op->status = 0;
        break;
    case DAP_OP_LINE_RESET:
        swd_line_reset();
        select_valid = 0;
        op->ack = 1;
        break;
    case DAP_OP_JTAG_TO_SWD:
        swd_jtag_to_swd();
        select_valid = 0;
        op->ack = 1;
        break;
    default:
        op->status = 0xFF;  /* Unknown operation */
        break;
    }
}

/* Process ring queue */
static void process_queue(void)
{
    uint32_t head = ctrl->queue_head;
    uint32_t tail = ctrl->queue_tail;
    
    while (head != tail) {
        volatile dap_op_t *op = &queue[head % QUEUE_SIZE];
        execute_op(op);
        head = (head + 1) % QUEUE_SIZE;
    }
    
    /* Update head pointer */
    ctrl->queue_head = head;
    ctrl->total_ops += (tail >= ctrl->queue_head) ? 
                       (tail - ctrl->queue_head) : 
                       (QUEUE_SIZE - ctrl->queue_head + tail);
}

/* Main loop */
int main(void)
{
    /* Initialize DRAM pointers */
    ctrl = (volatile pru_control_t *)(PRU_DRAM_BASE + DRAM_CONTROL_OFFSET);
    queue = (volatile dap_op_t *)(PRU_DRAM_BASE + DRAM_QUEUE_OFFSET);
    data_buffer = (volatile uint8_t *)(PRU_DRAM_BASE + DRAM_DATA_OFFSET);
    
    /* Initialize control block */
    ctrl->doorbell = 0;
    ctrl->status = 0;
    ctrl->queue_head = 0;
    ctrl->queue_tail = 0;
    ctrl->queue_size = QUEUE_SIZE;
    ctrl->total_ops = 0;
    ctrl->error_count = 0;
    ctrl->select_cache = 0;
    ctrl->select_valid = 0;
    ctrl->connected = 0;
    ctrl->swd_speed = 1000;  /* 1MHz default */
    
    /* Initialize SELECT cache */
    select_cache = 0;
    select_valid = 0;
    
    /* Initialize SWD hardware */
    swd_init();
    swd_set_speed(3);  /* ~12MHz — stable limit */
    
    /* Main loop */
    while (1) {
        if (ctrl->doorbell) {
            ctrl->status = 1;  /* Busy */
            process_queue();
            ctrl->status = 0;  /* Idle */
            ctrl->doorbell = 0;  /* Clear doorbell */
        }
    }
    
    return 0;
}
