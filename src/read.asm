PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

; Serial communications
; https://controls.ame.nd.edu/microcontroller/main/node25.html
SCSR        EQU $102E ; Status register, TDRE is bit 7
SCDR        EQU $102F

    ORG PRG_START
            CLRB ; EPROM addess will be in ACCB

            ; Sets PA3 to be an output pin, otherwise P' will float!
            LDAA PACTL
            ORAA #%00001000
            STAA PACTL

            LDAA #%00001000 ; Enable 2764 output
            ;       ^^^^ PROG_EN = 0, CE' = 0, OE' = 0, P' = 1
            STAA PORTA

CHECK       STAB PORTB  ; Output address at PORTB

            INCB        ; 2 cycles @ 2 MHz = 1 us > 2764 t_OE

            ; By this point, data will be on PORTC

            LDAA PORTC      ; Read one byte from the EPROM
            BSR SEND_SCI    ; Send to SCI

            CMPB #25
            BNE CHECK

            ; ------------------------------------------------------------------
            ; Program end
            ; ------------------------------------------------------------------
FAIL        LDAA #%00111000 ; Disables the 2764 EPROM
            ;       ^^^^ PROG_EN = 0, CE' = 1, OE' = 1, P' = 1
            ;STAA PORTA

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
