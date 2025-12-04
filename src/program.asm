PRG_START   EQU $0000   ; Internal ROM start

PORTA	    EQU $1000   ; PORTA controls OE'
PORTB       EQU $1004   ; PORTB controls 2764 address lines
PORTC       EQU $1003   ; PORTC receives/sends data from/to 2764
DDRC        EQU $1007   ; PORTC direction pins

DATA        EQU $00E0   ; Location to store 25 bytes in on-chip memory

; Serial communications
; https://controls.ame.nd.edu/microcontroller/main/node25.html
SCSR        EQU $102E ; Status register, TDRE is bit 7
SCDR        EQU $102F

    ORG DATA
            ; 25-element array for the data
ARRAY       DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE, $AA, $BB, $CC, $DD, $EE
            DB $AA, $BB, $CC, $DD, $EE

    ORG PRG_START
            ; Set PORTA. PROG_EN' and CE' are activated at program start.
            ; Bit 6: PROG_EN = 1
            ; Bit 5: CE' = 0
            ; Bit 4: OE' = 1
            LDAA #%01010000
            STAA PORTA

            LDX #0
NEXT_DATA   LDAB DATA,X ; Get first byte to store...
            STAB PORTC  ; ...and place on PORTC

            
            STX PORTB   ; Index X is also the target address on the 2764

            

            LDAA #1     ; Start at n = 1
RETRY       
            PSHA        ; Push current n to stack
            
            LDAA #%01010000
            STAA PORTA

            LDAA #$FF
            STAA DDRC   ; Set all PORTC pins to output

            LDAB DATA,X ; Get first byte to store...
            STAB PORTC  ; ...and place on PORTC

            

            ; By this point, HC11 is outputting data and adddress to the 2764

            LDAA #1     ; ] 1 ms
            BSR PULSE   ; ] pulse
            
            BSR LONG_DELAY
            BSR LONG_DELAY
            BSR LONG_DELAY

            LDAA #$00
            STAA DDRC   ; Set all PORTC pins to input
            
            STAA PORTA

            BSR LONG_DELAY
            BSR LONG_DELAY
            BSR LONG_DELAY

            ; By this point, ACCB has the actual data bit for reference
            ; Compare against PORTC to verify

            
            BSR LONG_DELAY
            
            
            NOP
            NOP
            NOP
            NOP
            
            LDAA PORTC
            STAA SCDR ; Writeback the byte to serial data register
            
            PULA        ; Retrieve current n from stack
            
            
            
            
            
            
            
            
            CMPB PORTC
            BEQ NEXT
            
            ; Wait for SCI transmit buffer to be empty (TDRE == 1)
            ; This means byte was transmitted successfully
WAIT_SCI_2  LDAB SCSR ; Get SCI status register
            ANDB #$80 ; Bit mask of #$80 looks at bit 7 (TDRE) of SCSR
            BEQ WAIT_SCI_2 ; If TDRE == 0, go back and wait some more
            
            

            
            INCA        ; n++
            CMPA #26    ; n > 25
            BEQ FAIL

            BRA RETRY

NEXT        LDAB #3     ; ACCB = 3, ACCA = n
            MUL         ; D = 3*n
            TAB         ; ACCA = 3*n
            BSR PULSE   ; 3*n ms pulse
            INX
            CPX #25     ; Address > $18
            BNE NEXT_DATA

SUCCESS     NOP

FAIL        NOP

            LDAA #%00010000
            STAA PORTA

            STOP

; ------------------------------------------------------------------------------
; Subroutine PULSE
; Sends an approx. n-ms pulse at bit 7 of PORTB
; ((6 + (3 + (3 + 3) * 332 + 2 + 3) * 1) + 5 + 2 + 4) / 2 MHz ~= n ms
;
; Parameters:
;   ACCA: Duration of pulse in ms
; ------------------------------------------------------------------------------

PULSE       PSHA            ; Save accumulators
            PSHB
            PSHX
            LDAB PORTB      ; Save address lines
            
            ANDB #$7F       ; 2 cycles --- reset bit 7
            STAB PORTB
            BSR DELAY_1MS   ; 6 cycles
            ORAB #$80       ; Set bit 7 to 1
            STAB PORTB      ; 4 cycles
            PULX
            PULB
            PULA
            RTS

DELAY_1MS   LDX #332        ; 3 cycles
DELAY_LOOP  DEX             ; 3 cycles
            BNE DELAY_LOOP  ; 3 cycles
            DECA            ; 2 cycles
            BNE DELAY_1MS   ; 3 cycles
            RTS             ; 5 cycles
            
            
LONG_DELAY  PSHX
            LDX #$7FFF
LOOPS       DEX
            BNE LOOPS
            PULX
            RTS

