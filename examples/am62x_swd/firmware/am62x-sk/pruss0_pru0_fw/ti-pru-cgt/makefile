export OPEN_PRU_PATH?=$(abspath ../../../../../..)
include $(OPEN_PRU_PATH)/imports.mak

# Define build outputs
OUTPUT_NAME := am62x_swd_pruss0_pru0_fw

# Source file directories
FILES_PATH := .. ../../.. .

# Linker command file
COMMAND_FILES := linker.cmd

# Silicon version (3: PRUSS, PRU-ICSS; 4: PRU_ICSSG)
PRU_VERSION := 3
EXPECTED_DEVICE := am62x

# pru_rules.mak has shared settings for all PRU/RTU/TX_PRU core makefiles
include $(OPEN_PRU_PATH)/pru_rules.mak

# Append include paths
INCLUDE += --include_path=$(OPEN_PRU_PATH)/source/include

# No additional compiler flags needed for pure assembly
