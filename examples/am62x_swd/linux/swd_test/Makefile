# Makefile for AM62x SWD test program

CC := gcc
CFLAGS := -Wall -O2
TARGET := swd_test

.PHONY: all clean

all: $(TARGET)

$(TARGET): swd_test.c
	$(CC) $(CFLAGS) -o $@ $<
	@echo "Test program built: $(TARGET)"

clean:
	rm -f $(TARGET)

install: $(TARGET)
	@echo "Copying to target device..."
	scp $(TARGET) root@192.168.7.2:/tmp/
	@echo "Installed to /tmp/$(TARGET) on target"
