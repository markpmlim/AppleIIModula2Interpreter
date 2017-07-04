;Name          : LOADINTERP.S
;End of file   :    1,370

            LST    OFF
;---------------------------------------------------------;
;     Disassembled with The Flaming Bird Disassembler     ;
;    (c) Phoenix corp. 1992,93  -  All rights reserved    ;
;---------------------------------------------------------;
; TFBD generated equates
;    (c) PHC 1992,93
;
CTRLD       EQU    $84
ROMIN2      EQU    $C081
LCBANK2     EQU    $C083
MeDOSEnt    EQU    $D000
HOME        EQU    $FC58
CROUT       EQU    $FD8E
COUT        EQU    $FDED
RESETV      EQU    $FFFC
;
            ORG    $3000
            JSR    HOME
            LDA    ROMIN2          ;Enable Apple II ROM
            LDA    ROMIN2
            JSR    CROUT
;
; Load Modula-2 Interpreter
;
            LDA    #CTRLD
            JSR    COUT
            LDY    #0
LoadLup1    LDA    LOADINTERP,Y
            BEQ    IntLoaded
            JSR    COUT
            INY
            BNE    LoadLup1
;
; Load SEK.ABS file
; SEK - Sequential Executive Kernel
;
IntLoaded   JSR    CROUT
            JSR    CROUT
            LDA    #CTRLD
            JSR    COUT
            LDY    #0
LoadLup2    LDA    LOADSEK,Y
            BEQ    SekLoaded
            JSR    COUT
            INY
            BNE    LoadLup2
;
SekLoaded   JSR    CROUT
            LDA    LCBANK2         ;Switch in LC bank2
            LDA    LCBANK2
            LDA    #0
            STA    RESETV
            LDA    #0
            STA    RESETV+1
;
; Patch LOCATIONS $00-$0A with the instructions
; 0000: LDA $C081
; 0003: LDA $C081
;
            LDA    #$AD            ;Abs load instruction
            STA    $00
            STA    $03
            LDA    #$81
            STA    $00+1
            STA    $03+1
            LDA    #$C0
            STA    $00+2
            STA    $03+2
;
; 0008: JMP $FAA6 - Return zero 
;
            LDA    #$4C
            STA    $06
            LDA    #$A6
            STA    $06+1
            LDA    #$FA
            STA    $06+2
            JMP    MeDOSEnt        ;XFER CONTROL TO MeDOS
;
            MSB    ON
LOADINTERP  ASC    "BLOAD INTERP,A$D000"
            DB     0
LOADSEK     ASC    "BLOAD SEK.ABS"
            DB     0
            MSB    OFF