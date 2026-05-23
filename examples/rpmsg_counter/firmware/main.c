/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright (C) 2026 - PRU RPMsg Counter Demo
 * 
 * This example demonstrates sending a counter value to Linux every 1 second via RPMsg
 */

#include <stdint.h>
#include <pru_intc.h>
#include <rsc_types.h>
#include <pru_rpmsg.h>
#include <pru_cfg.h>
#include "resource_table.h"
#include "intc_map.h"

volatile register uint32_t __R31;

/*
 * INTC CONFIGURATION
 */
#ifndef HOST_INT_BIT
#error "HOST_INT_BIT not defined, must be passed to the compiler using --define"
#endif
#define HOST_INT			((uint32_t) 1 << HOST_INT_BIT)

#ifndef TO_ARM_HOST
#error "TO_ARM_HOST not defined, must be passed to the compiler using --define"
#endif
#ifndef FROM_ARM_HOST
#error "FROM_ARM_HOST not defined, must be passed to the compiler using --define"
#endif
/*
 * FROM_ARM_HOST < 32 for all cores, so (ENA_STATUS_REG0 & FROM_ARM_HOST_BIT)
 * can be used to check the status of the system event.
 */
#define FROM_ARM_HOST_BIT		((uint32_t) 1 << FROM_ARM_HOST)

/*
 * RPMSG CONFIGURATION
 */
#define CHAN_NAME                       "rpmsg-raw"

#ifndef CHAN_PORT
#error "CHAN_PORT not defined, must be passed to the compiler using --define"
#endif

/*
 * Used to make sure the Linux drivers are ready for RPMsg communication
 */
#define VIRTIO_CONFIG_S_DRIVER_OK	4

/* 
 * PRU runs at 333MHz on AM62x
 * Empirically calibrated delay for 1 second interval
 * (空循环的实际cycles数可能大于理论值)
 */
#define DELAY_1SEC_CYCLES  16650000

void delay_1sec(void) {
	volatile uint32_t i;
	for (i = 0; i < DELAY_1SEC_CYCLES; i++) {
		/* Empty loop for delay */
	}
}

/* Simple integer to string conversion (no printf overhead) */
uint16_t uint_to_str(uint32_t num, char *str) {
	char temp[12];  /* Max 10 digits + null + sign */
	uint16_t i = 0;
	uint16_t j = 0;
	
	/* Handle 0 specially */
	if (num == 0) {
		str[0] = '0';
		str[1] = '\0';
		return 1;
	}
	
	/* Convert digits in reverse order */
	while (num > 0) {
		temp[i++] = '0' + (num % 10);
		num /= 10;
	}
	
	/* Reverse the string */
	while (i > 0) {
		str[j++] = temp[--i];
	}
	str[j] = '\0';
	
	return j;
}

/* Build message: "PRU Counter: XXXXX" */
uint16_t build_message(uint32_t counter, char *msg) {
	const char prefix[] = "PRU Counter: ";
	uint16_t len = 0;
	uint16_t i;
	
	/* Copy prefix */
	for (i = 0; prefix[i] != '\0'; i++) {
		msg[len++] = prefix[i];
	}
	
	/* Add counter value */
	len += uint_to_str(counter, &msg[len]);
	
	/* Add null terminator */
	msg[len] = '\0';
	
	return len + 1;  /* Include null terminator */
}

/*
 * main.c
 */
void main(void)
{
	struct pru_rpmsg_transport transport;
	uint16_t src, dst, len;
	volatile uint8_t *status;
	uint32_t counter = 0;
	char message[64];
	uint8_t payload[16];

	/* Clear the status of the PRU system event that the ARM will use to 'kick' us */
	CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;

	/* Make sure the Linux drivers are ready for RPMsg communication */
	status = &resourceTable.rpmsg_vdev.status;
	while (!(*status & VIRTIO_CONFIG_S_DRIVER_OK));

	/* Initialize the RPMsg transport structure */
	pru_rpmsg_init(&transport, &resourceTable.rpmsg_vring0, &resourceTable.rpmsg_vring1, TO_ARM_HOST, FROM_ARM_HOST);

	/* Create the RPMsg channel between the PRU and ARM user space using the transport structure. */
	while (pru_rpmsg_channel(RPMSG_NS_CREATE, &transport, CHAN_NAME, CHAN_PORT) != PRU_RPMSG_SUCCESS);

	/* Wait for the first message from Linux to establish communication */
	while (1) {
		/* Check for messages from Linux */
		if (__R31 & HOST_INT) {
			if (CT_INTC.ENA_STATUS_REG0 & FROM_ARM_HOST_BIT) {
				/* Clear the event */
				CT_INTC.STATUS_CLR_INDEX_REG_bit.STATUS_CLR_INDEX = FROM_ARM_HOST;
				/* Try to receive message */
				if (pru_rpmsg_receive(&transport, &src, &dst, payload, &len) == PRU_RPMSG_SUCCESS) {
					/* Got message from Linux
					 * src = Linux address (where message came from)
					 * dst = PRU address (our address)
					 * For sending, we use dst as source and src as destination
					 */
					break;
				}
			}
		}
	}

	/* Main counter loop: send counter every ~0.1 second */
	while (1) {
		/* Build the message with current counter value */
		len = build_message(counter, message);

		/* Send the message to Linux 
		 * dst = PRU address (source)
		 * src = Linux address (destination)
		 */
		pru_rpmsg_send(&transport, dst, src, message, len);

		/* Increment counter */
		counter++;

		/* Wait for ~0.1 second */
		delay_1sec();
	}
}
