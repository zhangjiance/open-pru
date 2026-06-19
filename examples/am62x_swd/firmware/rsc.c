/* rsc.c — Resource table (RPMsg vdev for kernel compat) + PRU IRQ map
 *
 * Mailbox at DRAM 0x1000 is above typical vring allocation (~0x200-0x420).
 * The RPMsg vdev is declared so the kernel accepts the firmware,
 * but the firmware does NOT use RPMsg at runtime.
 */

#include <stdint.h>
#include <pru_intc.h>
#include <rsc_types.h>
#include "resource_table.h"
#include "intc_map.h"
