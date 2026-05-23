# Makefile for AM62x SWD Project
# Project-level makefile

PROJECT_NAME := am62x_swd

# Supported processors
SUPPORTED_PROCESSORS := am62x

# Build configuration
BUILD_LINUX := n
BUILD_MCUPLUS := n

# Auto-detect OpenPRU path if not set
ifeq ($(OPEN_PRU_PATH),)
    OPEN_PRU_PATH := $(shell cd ../.. && pwd)
    export OPEN_PRU_PATH
endif

# Set device for AM62x
DEVICE := am62x
export DEVICE

# Include OpenPRU common makefile (optional)
-include $(OPEN_PRU_PATH)/imports.mak

.PHONY: all clean help test

all:
	@echo "========================================="
	@echo "Building AM62x SWD Project"
	@echo "========================================="
	$(MAKE) -C firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt all
	@echo ""
	@echo "========================================="
	@echo "Build Complete!"
	@echo "========================================="
	@echo "Output: firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt/generated/"
	@echo ""

clean:
	@echo "Cleaning AM62x SWD Project..."
	$(MAKE) -C firmware/am62x-sk/pruss0_pru0_fw/ti-pru-cgt clean
	@echo "Clean complete."

help:
	@echo "AM62x SWD - PRU-based Serial Wire Debug for AM62x"
	@echo ""
	@echo "Targets:"
	@echo "  all    - Build PRU firmware"
	@echo "  clean  - Clean build artifacts"
	@echo "  test   - Build test programs"
	@echo "  help   - Show this help"
	@echo ""
	@echo "Configuration:"
	@echo "  PROJECT_NAME = $(PROJECT_NAME)"
	@echo "  PROCESSORS   = $(SUPPORTED_PROCESSORS)"
	@echo ""
	@echo "Usage:"
	@echo "  make           # Build firmware"
	@echo "  make clean     # Clean"
	@echo ""

test:
	@echo "Building test programs..."
	$(MAKE) -C linux/swd_test all
