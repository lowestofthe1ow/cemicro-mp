PRG_START   EQU $0000 ; Internal ROM start

PORTA	    EQU $1000 ; PORTA controls OE'
PORTB       EQU $1004 ; PORTB controls 2764 address lines
PORTC       EQU $1003 ; PORTC receives data from 2764

; Serial communications
; https://controls.ame.nd.edu/microcontroller/main/node25.html
SCSR        EQU $102E ; Status register, TDRE is bit 7
SCDR        EQU $102F

    ORG PRG_START
START       CLRA

LOOP        STAA PORTB ; Store address A4...A0

            ; Fastest 68HC11 instruction takes about 965ns
            ; This is slow enough for 2764 t_OE <= 100ns + t_CE <= 250ns
            CLRB
            STAB PORTA ; Set CE' and OE' to LOW here
            INCA

            ; DATA SHOULD BE VALID BY THIS POINT

            LDAB PORTC ; Read one byte from the EPROM
            STAB SCDR ; Writeback the byte to serial data register

            ; Wait for SCI transmit buffer to be empty (TDRE == 1)
            ; This means byte was transmitted successfully
WAIT_SCI    LDAB SCSR ; Get SCI status register
            ANDB #$80 ; Bit mask of #$80 looks at bit 7 (TDRE) of SCSR
            BEQ WAIT_SCI ; If TDRE == 0, go back and wait some more

            ; Set OE' and CE' back to HIGH here
            LDAB #%00110000
            STAB PORTA

            CMPA #25
            BNE LOOP
            STOP
