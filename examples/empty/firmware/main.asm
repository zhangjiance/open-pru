; SPDX-License-Identifier: BSD-3-Clause
; GPIO Toggle at 1kHz on PR0_PRU0_GPO1 for PocketBeagle2
;
; Toggles PR0_PRU0_GPO1 (bit 1 of R30) at 1kHz frequency
; Period = 1ms, Half period = 500us
; PRU clock = 200MHz (5ns per cycle)
; 500us = 100,000 PRU cycles
; Each loop iteration ≈ 2 cycles, so delay count ≈ 50,000

    .retain     ; Required for building .out with assembly file
    .retainrefs ; Required for building .out with assembly file

    .global     main
    .sect       ".text"

; Definitions
    .asg    50000, DELAY_COUNT    ; Delay for ~500us at 200MHz PRU clock

main:
init:
    ; Clear registers R0 to R29
    ; R30 is GPO (General Purpose Output)
    ; R31 is GPI (General Purpose Input)
    zero    &r0, 120

main_loop:
    ; Set PR0_PRU0_GPO1 high (bit 1 of R30)
    set     r30.t1
    
    ; Delay for half period (~500us)
    ldi32   r5, DELAY_COUNT
delay_high:
    sub     r5, r5, 1
    qbne    delay_high, r5, 0
    
    ; Set PR0_PRU0_GPO1 low (bit 1 of R30)
    clr     r30.t1
    
    ; Delay for half period (~500us)
    ldi32   r6, DELAY_COUNT
delay_low:
    sub     r6, r6, 1
    qbne    delay_low, r6, 0
    
    ; Continue loop
    qba     main_loop

    ; Halt (never reached)
    halt
