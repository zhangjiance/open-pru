export OPEN_PRU_PATH?=$(abspath ../../../../../..)
include $(OPEN_PRU_PATH)/imports.mak

# Define build outputs
OUTPUT_NAME := am62x_swd_pruss0_pru0_fw

# Source file directories
# main_v2.c, swd.asm, rsc.c are in firmware/ (../../.. from this makefile)
FILES_PATH := .. ../../.. .

# Explicitly specify source files for zero-copy V2
C_FILES := main_v2.c rsc.c
ASM_FILES := swd.asm

# Linker command file
COMMAND_FILES := linker.cmd

# Silicon version (3: PRUSS, PRU-ICSS; 4: PRU_ICSSG)
PRU_VERSION := 3
EXPECTED_DEVICE := am62x

# pru_rules.mak has shared settings for all PRU/RTU/TX_PRU core makefiles
include $(OPEN_PRU_PATH)/pru_rules.mak

# Append include paths
INCLUDE += --include_path=$(OPEN_PRU_PATH)/source/include
INCLUDE += --include_path=$(OPEN_PRU_PATH)/source/include/linux
INCLUDE += --include_path=..
INCLUDE += --include_path=.

# RPMsg defines required by resource_table.h (firmware doesn't call RPMsg APIs)
HOST_INT_BIT = 30
TO_ARM_HOST = 16
FROM_ARM_HOST = 17
CHAN_PORT = 30

DFLAGS := \
	-DCHAN_PORT=$(CHAN_PORT) -DHOST_INT_BIT=$(HOST_INT_BIT) \
	-DTO_ARM_HOST=$(TO_ARM_HOST) -DFROM_ARM_HOST=$(FROM_ARM_HOST)

# No RPMSG library needed (firmware doesn't call RPMsg APIs)
LIBS :=
