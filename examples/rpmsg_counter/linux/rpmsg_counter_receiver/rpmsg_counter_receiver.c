/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (C) 2026 - PRU RPMsg Counter Receiver
 *
 * This example receives counter messages from PRU via RPMsg
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>

#define RPMSG_DEVICE "/dev/rpmsg0"
#define MAX_BUFFER_SIZE 512

int main(int argc, char *argv[])
{
	int fd;
	char buffer[MAX_BUFFER_SIZE];
	int ret;
	int msg_count = 0;

	printf("PRU RPMsg Counter Receiver\n");
	printf("==========================\n\n");

	/* Open the RPMsg device */
	printf("Opening %s...\n", RPMSG_DEVICE);
	fd = open(RPMSG_DEVICE, O_RDWR);
	if (fd < 0) {
		perror("Failed to open rpmsg device");
		printf("\nMake sure:\n");
		printf("  1. PRU firmware is loaded and running\n");
		printf("  2. RPMsg device exists: ls -l /dev/rpmsg*\n");
		printf("  3. You have permission to access the device\n");
		return EXIT_FAILURE;
	}

	printf("Successfully opened %s\n", RPMSG_DEVICE);
	
	/* Send a start message to PRU to initiate counter */
	printf("Sending start message to PRU...\n");
	ret = write(fd, "START", 5);
	if (ret < 0) {
		perror("Failed to send start message");
		close(fd);
		return EXIT_FAILURE;
	}
	printf("Start message sent\n");
	
	printf("Waiting for messages from PRU (Ctrl+C to exit)...\n");
	printf("----------------------------------------\n\n");

	/* Main receive loop */
	while (1) {
		/* Read message from PRU */
		ret = read(fd, buffer, sizeof(buffer));
		
		if (ret < 0) {
			perror("Failed to read from rpmsg device");
			break;
		}

		if (ret == 0) {
			/* No data available, continue */
			continue;
		}

		/* Null-terminate the buffer */
		if (ret < MAX_BUFFER_SIZE) {
			buffer[ret] = '\0';
		} else {
			buffer[MAX_BUFFER_SIZE - 1] = '\0';
		}

		/* Print the received message with timestamp */
		msg_count++;
		printf("[%d] Received %d bytes: %s\n", msg_count, ret, buffer);
		fflush(stdout);
	}

	/* Cleanup */
	close(fd);
	printf("\nClosed RPMsg device\n");

	return EXIT_SUCCESS;
}
