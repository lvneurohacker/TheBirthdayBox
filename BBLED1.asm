	title	BirthdayBox Controller Program
;This program randomly flashes LED's on a birthday gift box  4.6V Battery powered!

;USES LP (Low Power) 32kHz CRYSTAL!!

; REVISION HISTORY
;Rev A	26-Jul-15	neurohacker	Initial program

	list      p=12f629            ; list directive to define processor
	#include <p12f629.inc>        ; processor specific variable definitions

	__CONFIG   _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _MCLRE_OFF
	__IDLOCS	0F629h

savew	equ	021h	;save w (in bank0)
savest	equ	022h	;save status reg.
savlat	equ	023h	;save pcl latch
out	equ	024h

timer	equ	025h
tenms	equ	026h
msecs	equ	027h
secs	equ	028h
mins	equ	029h
hours	equ	02ah

fsecs	equ	02bh
fmins	equ	02ch
fhours	equ	02dh


ctrblink	equ	02fh	;counts blinks
ctrdelay	equ	030h	;delay counter

fint	equ	031h


scr	equ	035h	;scratch memory
scr1	equ	036h	;another scratch area (scr and scr1)
scr2	equ	037h
ctr1	equ	038h
ctr2	equ	039h
;__________________________________________________________________
bank0	equ	0
bank1	equ	b'00100000'

OPsetup	equ	b'00000111'	;Put in OPTION_REG in InitSys:
			;bit7=0: enable GPIO pullups
			;bit5=0: advance TMR0 with internal instr cyc. clock
			;bit3=0: assign prescale to TMR0
			;bit2-0=111: Prescaler (TMR0) = /256

INTsetup	equ	b'10100000'	;Put in INTCON (Interrupt Control Register): Set up timer interupt
			;bit7=1: ENABLE Global Interrupt
			;bit6=0: DISABLE all Peripheral Interrupts
			;bit5=1: ENABLE TMR0 Overflow interrupt
			;bit3=0: DISABLE all unmasked Port-change interrupts
			;bit2=0: TMR0 Clear Overflow Interupt Flag

PIEsetup	equ	b'00000000'	;Put in PIE1 (Peripheral Interrupt Enable Register)
			;bit7-0=0: DISABLE all peripheral Interrupt

T1setup	equ	b'00001110'	;Put in T1CON (Timer1 Control Register): Set up timer operation
			;bit7=0: NOT IMPLEMENTED
			;bit6=0: Timer1 Gate: Timer1 ON (no Gating)
			;bit5-4=00: Prescaler (TMR1) = 1:1
			;bit3=1: LP-Oscillator ENABLED for T1 CLK
			;bit2=1: High for Asynchronous mode when bit1 is high
			;bit1=1: TMR1 uses internal clock (Fosc/4) THIS NEEDS TO BE 
			;	LOW FOR T1 INTERRUPTS TO WORK.  NO, USE
			;	EXTERNAL CLOCK: SEE AN580!
			;bit0=0: Timer1 is OFF when setup is loaded

CMsetup	equ	b'00000111'	;Put in CMCON (Comparator Module Control Register):
			;bit7=0: NOT IMPLEMENTED
			;bit6=0: COUT (Read-only)
			;bit5=0: NOT IMPLEMENTED
			;bit4=0: COUT not inverted
			;bit3=0: Not used in this comparator mode
			;bit2-0=111: Comparator Mode: OFF

;VRsetup (VRCON) Voltage reference: A lower voltage will put the night/day threshhold at a higher brightness level
VRsetup	equ	b'00001000'	;Put in VRCON (Voltage Reference Control Register):
			;bit7=0: (VREN): Voltage Reference Disabled
			;bit6=0: NOT IMPLEMENTED
			;bit5=0: (VRR): Select Vref high range
			;bit4=0: NOT IMPLEMENTED
			;bit3-0=1100: Select Voltage reference level
;__________________________________________________________________
;Beginning of program code
;__________________________________________________________________
	nop
	nop
	nop
	goto	initsys
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;The Interrupt service routine: assume that T0-overflow-interrupt sent us here
;    Each instruction cycle is 1/4000000 X 4 = 1.0 us
;     TMR0 increments every 256 instr cycles: 1.0 us X 256 = 256.0 us
;      with preset at 39 (256-217): 256 us X 39 counts = 9984 us (9.984 ms) between interrupts
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
TheISR	movwf	savew	;Save W (in either bank)
	swapf	STATUS,W	;Swap STATUS to W
	bcf	STATUS,RP0	;change to bank0, regardless of current bank
	movwf	savest	; and save STATUS to bank0 register


	bcf	INTCON,GIE	;disable global interrupts
	bcf	INTCON,T0IF	;Clear TMR0 overflow flag


	clrwdt		;make sure WDT not on

	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	movlw	.217	;preload TMR0
	movwf	TMR0	;timer set up-clk=1.627us

	clrf	fint	;Clear all interrupt use flags

;at this point 1.25ms have passed
	decfsz 	msecs,F	;dec 10x100 ms time routine
	goto	exitr	;not timed out
	movlw	.124	;set up secs 10x100 ms routine (124 helps compensate for oscillator error)
	movwf	msecs	;set up for one sec
	clrf	fsecs	;Clear all 1-sec use flags
;now set up minutes
	decfsz	secs,F	;dec secs routine
	goto	exitr	;secs not timed out
	movlw	.60	;timed out reset secs
	movwf	secs	;reset
	clrf	fmins	;Clear all 1-minutes use flag
		
exitr	swapf	savest,W	;Get stored STATUS to W
	movwf	STATUS	; and restore it
	swapf	savew,F	;swap stored W
	swapf	savew,W	;swap stored W into W
	bsf	INTCON,GIE	;enable global interrupts
	retfie		;return from interrupt
;__________________________________________________________________
;__________________________________________________________________
initsys	bcf	STATUS,RP0	;select bank0
	clrwdt
	movlw	INTsetup
	movwf	INTCON	;Setup all interrupts
	clrf	GPIO	;Init GPIO

	bsf	STATUS,RP0	;select bank1
	clrf	PIE1	;Disable all peripheral Interrupts

	movlw	b'00000010'	;Set all GPIO-pins as I/O
	movwf	TRISIO	; with TRISIO

	movlw	OPsetup	;Get OPTION register setup
	movwf	OPTION_REG	; Save in OPTION register

	movlw	VRsetup	;Set up Voltage Reference:
	movwf	VRCON	;with VRCON

	movlw	b'00000010'	;Turn ON pullups on inputs
	movwf	WPU

	clrf	IOC	;DO NOT Allow Interrupt-on change on GPIO's

	bcf	STATUS,RP0	;select bank0

	clrf	GPIO	;turn all outputs OFF

	movlw	CMsetup	;Set up comparator module:
	movwf	CMCON	; Comparator OFF
;__________________________________________________________________
;MAIN PROGRAM
;__________________________________________________________________
main	movlw	.3
	movwf	ctrblink
mblink
mloop25	bsf	GPIO,2	;Turn ON LED1A
	bsf	GPIO,3	;Turn ON LED1B
	bcf	GPIO,4	;Turn OFF LED2A
	bcf	GPIO,5	;Turn OFF LED2B

	movlw	.5
	movwf	scr

mloop29	bsf	fint,0
mloop30	btfsc	fint,0
	goto	mloop30

	decfsz	scr,F
	goto	mloop29
; - - - - - - - - - - - - - - - - - - - -
	bcf	GPIO,2	;Turn OFF LED1A
	bcf	GPIO,3	;Turn OFF LED1B
	bsf	GPIO,4	;Turn ON LED2A
	bsf	GPIO,5	;Turn ON LED2B
; - - - - - - - - - - - - - - - - - - - -
	movlw	.5
	movwf	scr

mloop49	bsf	fint,0
mloop50	btfsc	fint,0
	goto	mloop50

	decfsz	scr,F
	goto	mloop49

	decfsz	ctrblink,F
	goto	mloop25
; - - - - - - - - - - - - - - - - - - - -
	bcf	GPIO,2	;Turn OFF LED1A
	bcf	GPIO,3	;Turn OFF LED1B
	bcf	GPIO,4	;Turn OFF LED2A
	bcf	GPIO,5	;Turn OFF LED2B
; - - - - - - - - - - - - - - - - - - - -
mdelay	movlw	.90
	movwf	ctrdelay

mloop19	bsf	fsecs,0

mloop20	btfss	GPIO,1	;Chk sensor: Skip next if no agitation
	goto	mgocrzy	;  Otherwise, tilted: do a long blink

	btfsc	fsecs,0
	goto	mloop20

	decfsz	ctrdelay,F
	goto	mloop19
	goto	main	;Done with delay: start over with a brief blink


mgocrzy	movlw	.20	; Do a long blink
	movwf	ctrblink
	goto	mblink
;__________________________________________________________________
;__________________________________________________________________
	end		;program end		
