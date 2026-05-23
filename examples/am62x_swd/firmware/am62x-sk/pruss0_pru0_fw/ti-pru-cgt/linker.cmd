/* linker.cmd - Linker command file for AM62x PRU-SWD
 *
 * Memory layout for AM62x PRU0
 * Based on AM62x PRU0 memory map
 */

-cr
-stack 0x100
-heap 0x0

/* Memory Regions */
MEMORY
{
    PAGE 0:
        /* 16 KB PRU Instruction RAM */
        PRU_IMEM : org = 0x00000000, len = 0x4000
    
    PAGE 1:
        /* 8 KB PRU0 Data RAM */
        PRU0_DMEM_0 : org = 0x00000000, len = 0x2000  CREGISTER=24
        
    PAGE 2:
        /* 32 KB PRU Shared RAM (optional) */
        PRU_SHAREDMEM : org = 0x00010000, len = 0x8000  CREGISTER=28
        
        /* PRU Configuration */
        PRU_CFG : org = 0x00026000, len = 0x100  CREGISTER=4
        
        /* PRU Control */
        PRU0_CTRL : org = 0x00022000, len = 0x30  CREGISTER=11
        
        /* PRU INTC */
        PRU_INTC : org = 0x00020000, len = 0x1504  CREGISTER=0
}

/* Section Configuration */
SECTIONS
{
    /* Forces entry point to start of PRU IRAM */
    .text:START* > 0x0, PAGE 0
    
    /* Code section - goes to instruction memory */
    .text > PRU_IMEM, PAGE 0
    
    /* Data sections - go to PRU0 data memory */
    .stack > PRU0_DMEM_0, PAGE 1
    .bss > PRU0_DMEM_0, PAGE 1
    .data > PRU0_DMEM_0, PAGE 1
    .rodata > PRU0_DMEM_0, PAGE 1
    .cinit > PRU0_DMEM_0, PAGE 1
    .sysmem > PRU0_DMEM_0, PAGE 1
}
