; Suicide note

PROG        EQU $0000   ; Internal ROM start
                        ; $0000-$009C (approx.)
DATA        EQU $00E0   ; Location to store 25 bytes in on-chip memory
                        ; $00E0-$00F8

PORTA	    EQU $1000   ; PORTA controls OE'
PORTB       EQU $1004   ; PORTB controls 2764 address lines
PORTC       EQU $1003   ; PORTC receives/sends data from/to 2764
DDRC        EQU $1007   ; PORTC direction pins
PACTL       EQU $1026   ; PORTA accumulator control
                        ; Bit 7 and 3 control directions of PA7 and PA3

; Serial communications
; https://controls.ame.nd.edu/microcontroller/main/node25.html
SCSR        EQU $102E ; Status register, TDRE is bit 7
SCDR        EQU $102F

    ORG DATA
            ; 25-element array to write into the EPROM
ARRAY       DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE

    ORG PROG
            LDAA PACTL
            ORAA #%00001000
            STAA PACTL      ; Sets PA3 to be an output pin

            ; ------------------------------------------------------------------
            ; TODO: This gets initialized per loop in NEXT_DATA. Do we need to
            ; do this here?
            ; ------------------------------------------------------------------
            ; Set PORTA. PROG_EN and CE' are activated at program start.
            ; Bit   6:      PROG_EN = 1 (connected to PSU)
            ;        5:     CE' = 0
            ;         4:    OE' = 1
            ;          3:   P' = 1 (programming pulse sent to 2764)
            LDAA #%01011000
            STAA PORTA

            LDX #0

NEXT_DATA   XGDX        ; Swap D (ACCA:ACCB) with X. ACCB will contain low X
                        ; We do this to avoid accidentally overwriting PORTCL
                        ; ($1005) with the STX instruction. Also, the HC11 is
                        ; big-endian so in that case PORTB would always get 0
            STAB PORTB  ; Index X is also the target address on the 2764
            XGDX        ; Swap D and X back to normal

            ; ------------------------------------------------------------------
            ; 2764 Fast Programming Algorithm
            ; https://downloads.reactivemicro.com/Electronics/ROM/2764 EPROM.pdf
            ; ------------------------------------------------------------------
            LDAA #1     ; Starts at n = 1

RETRY       PSHA        ; Push current n to stack

            LDAA #%01011000 ; Also turns off VERIFY mode from a previous loop
            ;       ^^^^ PROG_EN = 1, CE' = 0, OE' = 1, P' = 1
            STAA PORTA  ; 4 cycles @ 2 MHz > t_GHAX from previous loopp

            LDAA #$FF
            STAA DDRC   ; Set all PORTC pins to output

            LDAB DATA,X ; Get first byte to store...
            STAB PORTC  ; ...and place on PORTC

            ; By this point, HC11 is outputting data and adddress to the 2764.
            ; Data is on PORTC and ACCB; address is on PORTB and X

            LDAA #1     ; 1ms pulse time
            BSR PULSE   ; Send the P' programming pulse (logic low)

            NOP         ; 2 cycles
            NOP         ; 2 cycles (extra for good measure)
            LDAA #$00   ; 2 cycles
                        ; @ 2 MHz = 3000 ns = 3 us >= 2 us 2764 t_PHQX
            STAA DDRC   ; Set all PORTC pins to input

            NOP         ; 2 cycles
            NOP         ; 2 cycles
            NOP         ; 2 cycles (extra for good measure)
                        ; @ 2 MHz = 3000 ns = 3 us >= 2 us 2764 t_QXGL

            LDAA #%01001000 ; Enable 2764 output so we can read from it
            ;       ^^^^ PROG_EN = 1, CE' = 0, OE' = 0, P' = 1
            ; PROG_EN = 1 while OE' = 0 means 2764 is in VERIFY mode
            STAA PORTA

            NOP ; 2 cycles @ 2 MHz = 1000 ns, slow enough for 2764 t_OE <= 150ns

            ; By this point, PORTC will receive data from 2764. Compare with
            ; ACCB to check if correct data was written

            LDAA PORTC      ; Fetch byte from PORTC

            BSR SEND_SCI    ; Send the byte to the SCI for verification

            PULA            ; Retrieve current n from stack
                            ; DO THIS HERE. ACCA = n is REQUIRED for BEQ MATCH

            CMPB PORTC
            BEQ MATCH       ; If received data matches expected

            INCA            ; n++
            CMPA #26        ; n > 25 hard limit for attempted writes
            BEQ FAIL

            BRA RETRY

            ; ------------------------------------------------------------------
            ; Overprogram pulse
            ; ------------------------------------------------------------------
MATCH       LDAB #3     ; ACCB = 3, ACCA = n
            MUL         ; D = 3n < $100, so ACCA = 0 while ACCB = 3n
            TAB         ; Copies ACCB to ACCA, so ACCA = 3n
            BSR PULSE   ; 3n ms pulse

            INX         ; Increment the address offset
            CPX #25     ; Address > $18
            BNE NEXT_DATA
            
            ; ------------------------------------------------------------------
            ; Perform a final check if all writes were successful
            ; ------------------------------------------------------------------
            CLRB        ; EPROM addess will be in ACCB
            
            LDAA #%00011000 ; Set 2764 to READ mode but with output disabled
            ;       ^^^^ PROG_EN = 0, CE' = 0, OE' = 1, P' = 1
            STAA PORTA
            
CHECK       STAB PORTB  ; Output address at PORTB

            LDAA #%00001000 ; Enable 2764 output
            ;       ^^^^ PROG_EN = 0, CE' = 0, OE' = 0, P' = 1
            STAA PORTA
            
            INCB        ; 2 cycles @ 2 MHz = 1 us > 2764 t_OE

            ; By this point, data will be on PORTC

            LDAA PORTC      ; Read one byte from the EPROM
            BSR SEND_SCI    ; Send to SCI
            
            CMPA #25
            BNE CHECK

            ; ------------------------------------------------------------------
            ; Program end
            ; ------------------------------------------------------------------
FAIL        LDAA #%00111000 ; Disables the 2764 EPROM
            ;       ^^^^ PROG_EN = 0, CE' = 1, OE' = 1, P' = 1
            STAA PORTA

            STOP

; ------------------------------------------------------------------------------
; Subroutine SEND_SCI
; Sends one byte through the HC11's serial communications subsystem
;
; Parameters:
;   ACCA: The byte data to send
; ------------------------------------------------------------------------------

            ; Wait for SCI transmit buffer to be empty (TDRE == 1)
            ; This means byte was transmitted successfully
SEND_SCI    STAA SCDR       ; Writeback the byte to serial data register
            PSHB            ; Save ACCB since it gets overwritten
WAIT_SCI    LDAB SCSR       ; Get SCI status register
            ANDB #$80       ; Bit mask of #$80 looks at bit 7 (TDRE) of SCSR
            BEQ WAIT_SCI    ; If TDRE == 0, go back and wait some more
            PULB
            RTS

; ------------------------------------------------------------------------------
; Subroutine PULSE
; Sends an approx. n-ms active-LOW pulse at bit 3 of PORTA
; ((6 + (3 + (3 + 3) * 332 + 2 + 3) * 1) + 5 + 2 + 4) cycles @ 2 MHz ~= n ms
;
; Parameters:
;   ACCA: Duration of pulse in ms
; ------------------------------------------------------------------------------

PULSE       PSHA            ; Save accumulators
            PSHB
            PSHX

            LDAB PORTA      ; To avoid overwriting the other PORTA bits

            ;      ____3___
            ANDB #%00001000 ; Reset bit 3
            STAB PORTA
            BSR DELAY_NMS   ; 6 cycles, delays by n milliseconds
            ORAB #%00001000 ; 2 cycles, set bit 3 to 1
            STAB PORTA      ; 4 cycles

            PULX            ; Restore accumulators
            PULB
            PULA
            RTS

; ------------------------------------------------------------------------------
; Subroutine DELAY_NMS
; Causes an approx. n-ms delay at bit 7 of PORTB. Used in PULSE, but the
; additional execution time there is roughly negligible on a millisecond scale
;
; Parameters:
;   ACCA: Duration of pulse in ms
; ------------------------------------------------------------------------------

DELAY_NMS   LDX #332        ; 3 cycles
DELAY_LOOP  DEX             ; 3 cycles
            BNE DELAY_LOOP  ; 3 cycles
            DECA            ; 2 cycles
            BNE DELAY_NMS   ; 3 cycles
            RTS             ; 5 cycles
