export OPEN_PRU_PATH?=$(abspath ../../../../../..)
include $(OPEN_PRU_PATH)/imports.mak

# Define build outputs
OUTPUT_NAME := pru_gpio_toggle_am62x-sk_pruss0_pru0_fw

# Source file search paths
FILES_PATH := .. ../../.. .

# Linker command file
COMMAND_FILES := linker.cmd

# Silicon version (3: PRUSS/PRU-ICSS; 4: PRU_ICSSG)
PRU_VERSION := 3
EXPECTED_DEVICE := am62x

include $(OPEN_PRU_PATH)/pru_rules.mak
