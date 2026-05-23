# Makefile for RPMsg Counter Receiver
# Cross-compile support for ARM target

# Default to native compilation
CROSS_COMPILE ?=
CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -O2
TARGET := rpmsg_counter_receiver
SRC := rpmsg_counter_receiver.c

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $<
	@echo "Built $(TARGET) successfully"

clean:
	rm -f $(TARGET)
	@echo "Cleaned $(TARGET)"

install: $(TARGET)
	@echo "To copy to target device:"
	@echo "  scp $(TARGET) root@<target-ip>:/usr/bin/"

.PHONY: all clean install
