; pru_gpio_toggle - PRU GPIO Toggle Demo for AM62x (PocketBeagle2 / BeaglePlay)
;
; Toggles PR0_PRU0_GPO8 (R30.8) on HP2-2 (U22) at ~2Hz visible rate
; On AM62x, PRU GPIOs use Mux Mode 5 - must configure via Device Tree overlay
;
; PRU Frequency: 333 MHz (3ns per cycle)
; Toggle Period: 500ms (2Hz) - visible to naked eye
; 500ms = 166,500,000 cycles
; Each inner loop iteration ≈ 2 cycles (sub + qbne)
; Delay count = 166,500,000 / 2 = 83,250,000
;
; Pin Mapping (from DavidSummers' forum post):
;   PR0_PRU0_GPO0  = R30.0  -> V20  HP1-36
;   PR0_PRU0_GPO1  = R30.1  -> AA23 HP1-33
;   PR0_PRU0_GPO8  = R30.8  -> U22  HP2-2  (used in this demo)
;   PR0_PRU0_GPO9  = R30.9  -> V24  HP2-4
;   PR0_PRU0_GPO10 = R30.10 -> W25  HP2-6
;   PR0_PRU0_GPO11 = R30.11 -> W24  HP2-8
;
; SPDX-License-Identifier: BSD-3-Clause

    .retain
    .retainrefs
    .global main
    .sect ".text"

;==============================================================================
; Definitions
;==============================================================================

; Delay count for high-speed toggle test (~10 cycles per half-period)
; Each loop iteration = 2 cycles (sub + qbne)
; 10 cycles / 2 = 5 iterations
    .asg 5, DELAY_COUNT

;-----------------------------------------------------------------------
; Theoretical Frequency Calculation (333MHz PRU, 3ns/cycle)
; Empirically verified with logic analyzer: ~9.5 MHz
;-----------------------------------------------------------------------
;
; CRITICAL: PRU instruction timing corrections (from measurement):
;   - qbne branch-TAKEN = 2 cycles (not 1!)
;   - qbne branch-NOT-TAKEN = 1 cycle
;   - ldi32 = 2 cycles (compiler emits two ldi for 32-bit load)
;   - set/clr on R30 = 1 cycle (GPIO output register, no stall)
;
; Full period (DELAY_COUNT=5, 35 cycles = 105ns):
;   set r30.t8              1
;   ldi32 r5, DELAY_COUNT   2 ← 32-bit load = two ldi
;   delay_high loop:       14 ← sub(1)+qbne(2 when taken, 1 at end)
;   clr r30.t8              1
;   ldi32 r6, DELAY_COUNT   2
;   delay_low loop:        14
;   qba main_loop           1
;   ───────────────────────
;   Total:   35 cycles → 105ns → 9.52 MHz
;
; Delay loop breakdown (COUNT=5):
;   4 iterations qbne-TAKEN:     4 × (sub 1c + qbne 2c) = 12
;   Last iteration qbne-NOT:     1 × (sub 1c + qbne 1c) =  2
;   ────────────────────────────────────────────────────────
;   Total delay: 14 cycles
;
; FOR HIGH-SPEED SQUARE WAVE TESTING:
; Replace loop with NOPs for deterministic, jitter-free output.
;   set  r30.t8    1 cycle
;   nop            1 cycle (delay)
;   clr  r30.t8    1 cycle
;   nop            1 cycle (delay)
;   qba  main_loop 1 cycle
;   ──────────────────────────
;   Total: 5 cycles → 15ns → 66.67 MHz
;   Duty: 50% (set+nop=2, clr+nop=2, qba=1 → 2:3 asymmetry)
;   Actual duty: HIGH=2cycles, LOW=3cycles → 40%

;==============================================================================
; Main
;==============================================================================

main:
    ; Clear all registers R0-R29 (R30 is GPO, R31 is GPI)
    zero    &r0, 120

    ; Initialize: Set PR0_PRU0_GPO8 high initially
    set     r30.t8

main_loop:
    set     r30.t8       ; HIGH
    nop                  ; 1 cycle delay
    clr     r30.t8       ; LOW
    nop                  ; 1 cycle delay
    qba     main_loop    ; loop (2 cycles)

    halt
