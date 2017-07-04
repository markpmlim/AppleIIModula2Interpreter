;Name          : MOD2INT.S
;End of file   :  110,115

            REP    50
; Modula-2 Interpreter for Apple DOS 3.3
; Assembler: EdAsm (ProDOS version)
            REP    50
; The M-Code Interpreter is loaded
; into Language Card Bank 2
; This section of the code is specific
; to the Apple II.
            REP    50
            ORG    $D000
            LDA    $FF             ;Set to -1 by HELLO program
            STA    CaseMsk         ;upper case mask
;
; Check for presence of 80-col card
;
            LDA    BasicIn
            CMP    #$38
            BNE    Setup1
            LDA    BasicOut
            CMP    #$18
            BNE    Setup1
            LDA    XC30B
            CMP    #$01            ;Pascal v1.1 protocol?
            BNE    Setup1          ;No
            LDA    XC30C           ;Device signature byte
            AND    #$F0            ;$8x -> 80-col card
            CMP    #$80
            BNE    Setup1          ;No 80-col card
;
; Patch MeDOS's I/O hooks.
;
            LDA    PInit
            STA    IMM1+1
            LDA    PRead
            STA    IMM2+1
            LDA    PWrite
            STA    IMM3+1
            LDA    PStat
            STA    IMM4+1
;
            JSR    InitVideo       ;Init video card
            LDA    #-1
            STA    Has80Col
;
Setup1      LDA    M2Out
            STA    CSWL
            LDA    M2Out+1
            STA    CSWH
;
            LDA    #$00
            STA    SOFTEV+1
            JSR    X03DC           ;Get DOS 3.3 FileMgr's
            STY    CCBPtr          ; parmlist & save it
            STA    CCBPtr+1
            JMP    doInit          ;Initialise the Interpreter
            REP    50
; Save on expression stack ($A0-$BF)
; which is built towards high mem.
; Ref Lilith mcode interpreter manual
;
RstExpStk   SEC
            LDA    SReg
            SBC    #2
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;DEC(S)
            LDY    #1
            LDA    (SReg),Y
            STA    NumWords        ;c:=stk[S]
            BEQ    doRTS           ;empty expr stack
;
; WHILE c > 0
;
RstLoop     SEC
            LDA    SReg
            SBC    #2
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;DEC(S)
;
            LDY    #1
            LDA    (SReg),Y        ;Get word &
            STA    ExprStack,X     ; save on empty slot
            INX                    ; b4 incr the "stack ptr"
            DEY
            LDA    (SReg),Y
            STA    ExprStack,X     ;push(stk[S])
            INX
            DEC    NumWords        ;DEC(c)
            BNE    RstLoop         ;Continue loop
doRTS       RTS
;
NumWords    DFB    0               ;max=16 words
            REP    50
; Set/Restore the registers
; When called by doInit, the various regs are set using
; values from the SEK.ABS file. Their initial values are
; (P)=$2186 (G)=$0800 (L)=$2198   (S)= $21A0
; (H)=$A8D0 (F)=$0960 (Z8E)=$00C4 (PC)=$0A24
;
RstRegs     PHP                    ;Carry bit=changeMask
            LDY    #0
            INY
            LDA    (PReg),Y        ;$00
            ASL    A
            STA    GReg
            DEY
            LDA    (PReg),Y        ;$04
            ROL    A
            STA    GReg+1          ;(GReg)=$0800
;
            INY
            INY
            INY
            LDA    (PReg),Y        ;$CC
            ASL    A
            STA    LReg
            DEY                    ;2
            LDA    (PReg),Y        ;$10
            ROL    A
            STA    LReg+1          ;(LReg)=$2198
;
            INY
            INY                    ;4
            LDA    (PReg),Y
            STA    Z8E+1           ;$00
            INY
            LDA    (PReg),Y        ;$C4
            STA    Z8E             ;(Z8E)=$00C4 - byte offset fr code frame
;
            INY
            PLP                    ;Is changeMask TRUE?
            BCC    SkipM           ;No
;
            LDA    (PReg),Y
            STA    MReg+1          ;$0000
            INY
            LDA    (PReg),Y
            STA    MReg
            INY
;
SkipM       LDY    #8
            INY
            LDA    (PReg),Y        ;$D0
            ASL    A
            STA    SReg
            DEY
            LDA    (PReg),Y        ;$10
            ROL    A
            STA    SReg+1          ;(SReg)=$21A0
;
            INY
            INY
            INY
            LDA    (PReg),Y        ;$80
            ASL    A
            STA    HReg
            DEY
            LDA    (PReg),Y        ;$54
            ROL    A
            STA    HReg+1          ;(HReg)=$A900
            INY
            INY                    ;not needed
;
            SEC
            LDA    HReg
            SBC    #24*2
            STA    HReg
            LDA    HReg+1
            SBC    #0
            STA    HReg+1          ;(HReg)=$A8D0
;
; (F-Reg) is set to code frame of module 0
; (SYSTEM) if called by doInit
;
            LDY    #0
            INY
            LDA    (GReg),Y        ;$96
            ASL    A
            STA    FReg
            DEY
            LDA    (GReg),Y        ;$00
            ROL    A
            STA    FReg+1
            INY
            INY
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1          ;x16 -> $0960
;
            CLC
            LDA    FReg
            ADC    Z8E
            STA    PC
            LDA    FReg+1
            ADC    Z8E+1
            STA    PC+1            ;=$0A24 -> Call System.main
            JSR    RstExpStk
            RTS
            REP    50
; Save a stack frame?
; Valid data fr the Expression stack are saved.
; The process descriptor is then updated.
; Input
;  PC, PReg, LReg, MReg, SReg
; Output
;  GReg, FReg, HReg
;
SaveRegs    JSR    SaveExpStack
            LDY    #0
            LDA    GReg+1
            LSR    A
            STA    (PReg),Y
            LDA    GReg
            ROR    A
            INY
            STA    (PReg),Y        ;stk[P] := G
;
            LDY    #2
            LDA    LReg+1
            LSR    A
            STA    (PReg),Y
            LDA    LReg
            ROR    A
            INY
            STA    (PReg),Y        ;stk[P+1] := L
;
            LDY    #4+1
            SEC
            LDA    PC
            SBC    FReg
            STA    (PReg),Y        ;offset from code frame
            LDA    PC+1
            SBC    FReg+1
            DEY
            STA    (PReg),Y        ;stk[P+2] := PC-F
;
            LDY    #6+1
            LDA    MReg
            STA    (PReg),Y
            LDA    MReg+1
            DEY
            STA    (PReg),Y        ;stk[P+3] := M
;
            LDY    #8
            LDA    SReg+1
            LSR    A
            STA    (PReg),Y
            LDA    SReg
            ROR    A
            INY
            STA    (PReg),Y        ;stk[P+4] := S
;
            LDY    #10+1
            LDA    HReg+1
            LSR    A
            STA    Z86+1           ;Save temporarily
            LDA    HReg
            ROR    A
            CLC
            ADC    #24
            STA    (PReg),Y
            LDA    Z86+1
            ADC    #0
            DEY
            STA    (PReg),Y        ;stk[P+5] := H+24
            RTS
            REP    50
; Only relevant data fr the expr stack are
; saved onto the program stack. A word
; denoting the # of words saved is appended.
;
SaveExpStack       LDY             #0
PshLoop     CPX    #0              ;Is stack empty?
            BEQ    NoMore          ;Yes -> done
            DEX
            LDA    ExprStack,X
            STA    (SReg),Y        ;stk[S] := pop();
            INY
            BNE    PshLoop         ;Always
;
; Append # of words saved
;
NoMore      LDA    #0
            STA    (SReg),Y
            TYA
            LSR    A               ;# of words
            INY
            STA    (SReg),Y        ;stk[S] := # of words
            INY
            CLC
            TYA
            ADC    SReg
            STA    SReg
            BCC    *+4
            INC    SReg+1          ;Point @ next empty slot
            RTS
            REP    50
; Assumes SEK.ABS is already loaded
;
doInit      LDA    #0
            STA    ExprStkP
            STA    ExprStkP+1
            TAX                    ;=0
            LDA    X0800+9         ;$C3 -> init P-Reg
            ASL    A
            STA    PReg
            LDA    X0800+8         ;$10
            ROL    A
            STA    PReg+1          ;P := stk[4] = $10C3x2=$2186
            SEC                    ;changeMask := TRUE
            JSR    RstRegs         ;Init regs using SEK.ABS loaded @ $0800
            JMP    MainLoop
            REP    50
; Interpreter's Main Loop 
;
MainLoop    LDY    KBD             ;Is there a keypress? 
            BPL    GetCode         ;No
            CPY    #CTRLC+$80      ;Abort?
            BNE    GetCode         ;No
;
            BIT    KBSTRB          ;Clear
            BIT    X0800+13        ;bootCode (boot flag)
            BVC    GetCode
            LDA    #stopped
            JSR    TrapProc
;
GetCode     LDY    #0
            LDA    (PC),Y          ;Get instruction
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A               ;double to form an index
            TAY
            BCS    Exec2
;
; Instructions $00-$7F
;
            LDA    JmpT,Y          ;Get JMP addr lo
            STA    IReg
            LDA    JmpT+1,Y
            STA    IReg+1
            JMP    (IReg)
;
; Instructions $80-$FF
;
Exec2       LDA    JmpT2,Y
            STA    IReg
            LDA    JmpT2+1,Y
            STA    IReg+1
            JMP    (IReg)
            REP    50
; Jump tables
;
JmpT        DW     LI0
            DW     LI1
            DW     LI2
            DW     LI3
            DW     LI4
            DW     LI5
            DW     LI6
            DW     LI7
            DW     LI8
            DW     LI9
            DW     LI10
            DW     LI11
            DW     LI12
            DW     LI13
            DW     LI14
            DW     LI15
            DW     LIB
            DW     LD4DD           ;21C
            DW     LIW
            DW     LID
            DW     LLA
            DW     LGA
            DW     LSA
            DW     LEA
            DW     JPC
            DW     JP
            DW     JPFC
            DW     JPF
            DW     JPBC
            DW     JPB
            DW     ORJP
            DW     ANDJP
;
            DW     LLW
            DW     LLD
            DW     LEW
            DW     LED
            DW     LLW4
            DW     LLW5
            DW     LLW6
            DW     LLW7
            DW     LLW8
            DW     LLW9
            DW     LLW10
            DW     LLW11
            DW     LLW12
            DW     LLW13
            DW     LLW14
            DW     LLW15
            DW     SLW
            DW     SLD
            DW     SEW
            DW     SED
            DW     SLW4
            DW     SLW5
            DW     SLW6
            DW     SLW7
            DW     SLW8
            DW     SLW9
            DW     SLW10
            DW     SLW11
            DW     SLW12
            DW     SLW13
            DW     SLW14
            DW     SLW15
;
            DW     LGW
            DW     LGD
            DW     LGW2
            DW     LGW3
            DW     LGW4
            DW     LGW5
            DW     LGW6
            DW     LGW7
            DW     LGW8
            DW     LGW9
            DW     LGW10
            DW     LGW11
            DW     LGW12
            DW     LGW13
            DW     LGW14
            DW     LGW15
            DW     SGW
            DW     SGD
            DW     SGW2
            DW     SGW3
            DW     SGW4
            DW     SGW5
            DW     SGW6
            DW     SGW7
            DW     SGW8
            DW     SGW9
            DW     SGW10
            DW     SGW11
            DW     SGW12
            DW     SGW13
            DW     SGW14
            DW     SGW15
;
            DW     LSW0
            DW     LSW1
            DW     LSW2
            DW     LSW3
            DW     LSW4
            DW     LSW5
            DW     LSW6
            DW     LSW7
            DW     LSW8
            DW     LSW9
            DW     LSW10
            DW     LSW11
            DW     LSW12
            DW     LSW13
            DW     LSW14
            DW     LSW15
            DW     SSW0
            DW     SSW1
            DW     SSW2
            DW     SSW3
            DW     SSW4
            DW     SSW5
            DW     SSW6
            DW     SSW7
            DW     SSW8
            DW     SSW9
            DW     SSW10
            DW     SSW11
            DW     SSW12
            DW     SSW13
            DW     SSW14
            DW     SSW15
;
JmpT2       DW     LSW
            DW     LSD
            DW     LSD0
            DW     LXFW
            DW     LSTA
            DW     LXB
            DW     LXW
            DW     LXD
            DW     DADD
            DW     DSUB
            DW     DMUL
            DW     DDIV
            DW     LDE4A
            DW     LDE4A
            DW     DSHL
            DW     DSHR
            DW     SSW
            DW     SSD
            DW     SSD0
            DW     SXFW
            DW     TS
            DW     SXB
            DW     SXW
            DW     SXD
            DW     FADD
            DW     FSUB
            DW     FMUL
            DW     FDIV
            DW     FCMP
            DW     FABS
            DW     FNEG
            DW     FFCT
;
            DW     READ
            DW     WRITE
            DW     DSKR
            DW     DSKW
            DW     SETRK
            DW     UCHK
            DW     ESC
            DW     SYS
            DW     ENTP
            DW     EXP
            DW     ULSS
            DW     ULEQ
            DW     UGTR
            DW     UGEQ
            DW     TRA
            DW     RDS
            DW     LODFW
            DW     LODFD
            DW     STORE
            DW     STOFV
            DW     STOT
            DW     COPT
            DW     DECS
            DW     PCOP
            DW     UADD
            DW     USUB
            DW     UMUL
            DW     UDIV
            DW     UMOD
            DW     ROR             ;$E5BB
            DW     SHL
            DW     SHR
;
            DW     FOR1
            DW     FOR2
            DW     ENTC
            DW     EXC
            DW     TRAP
            DW     CHK
            DW     CHKZ
            DW     CHKS
            DW     EQL
            DW     NEQ
            DW     LSS
            DW     LEQ
            DW     GTR
            DW     GEQ
            DW     ABS
            DW     NEG
            DW     OR
            DW     XOR
            DW     AND             ;$E9CC
            DW     COM
            DW     IN
            DW     LIN
            DW     MSK
            DW     NOT
            DW     ADD
            DW     SUB
            DW     MUL
            DW     DIV
            DW     InstrErr
            DW     BIT             ;$EC03
            DW     NOP             ;$EC0B
            DW     MOVF
;
            DW     MOV
            DW     CMP             ;$EC69
            DW     DDT
            DW     REPL
            DW     BBLT
            DW     DCH
            DW     UNPK
            DW     PACK
            DW     GB
            DW     GB1
            DW     ALOC
            DW     ENTR
            DW     RTN             ;$EE11
            DW     CX
            DW     CI
            DW     CF
            DW     CL
            DW     CL1
            DW     CL2
            DW     CL3
            DW     CL4
            DW     CL5
            DW     CL6
            DW     CL7
            DW     CL8
            DW     CL9
            DW     CL11
            DW     CL10
            DW     CL12
            DW     CL13
            DW     CL14
            DW     CL15
            REP    50
; Load Immediate - LI0-LI15 involves "pushing" 
; values 0-15 onto the expression stack ($A0-$BF)
; which grows towards high mem.
;
LI0         LDA    #0
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI1         LDA    #1
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI2         LDA    #2
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI3         LDA    #3
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI4         LDA    #4
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI5         LDA    #5
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI6         LDA    #6
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI7         LDA    #7
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI8         LDA    #8
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI9         LDA    #9
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI10        LDA    #10
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI11        LDA    #11
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI12        LDA    #12
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI13        LDA    #13
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI14        LDA    #14
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LI15        LDA    #15
            STA    ExprStack,X
            INX
            LDA    #0
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
; Load Immediate Byte
;
LIB         LDY    #0              ;Get byte fr code stream
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            STA    ExprStack,X     ; and 'push' it onto
            INX
            LDA    #0
            STA    ExprStack,X     ; the expression stack
            INX
            JMP    MainLoop
            REP    50
; Reserved for use by compiler
;
LD4DD       LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Load Immediate Word
; Use to generate constants
; The loaded value is the parameter itself
;
LIW         LDY    #0
            LDA    (PC),Y          ;Get byte from code stream
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    ExprStack+1,X   ; & save on expr stack
;
            LDY    #0
            LDA    (PC),Y          ;next2()
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Immediate Double Word
;
LID         LDY    #0
            LDA    (PC),Y          ;Big Endian
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    ExprStack+1,X
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;next2()
            STA    ExprStack,X
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    ExprStack+2+1,X
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;next2()
            STA    ExprStack+2,X
            INX
            INX
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Local Address onto the expr stack
; Use when assigning pointers & when
; passing parameters by reference
;
LLA         LDA    LReg+1          ;Calc local addr
            LSR    A               ; in terms of words
            STA    Z84+1
            LDA    LReg
            ROR    A
            STA    Z84
;
            LDY    #0
            LDA    (PC),Y          ;next() - offset
            INC    PC
            BNE    *+4
            INC    PC+1
            CLC
            ADC    Z84             ;L+next()
            STA    ExprStack,X     ;push(L+next())
            INX
            LDA    #0
            ADC    Z84+1
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
; Load Global Address
;
LGA         LDA    GReg+1
            LSR    A               ;express in words
            STA    Z84+1
            LDA    GReg
            ROR    A
            STA    Z84
;
            LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            ADC    Z84             ;G+next()
            STA    ExprStack,X     ;addr
            INX
            LDA    #0
            ADC    Z84+1
            STA    ExprStack,X     ;push(G+next())
            INX
            JMP    MainLoop
            REP    50
; Load Stack Address
; Add offset to addr on stack
;
LSA         LDY    #0
            LDA    (PC),Y          ;next() - offset
            INC    PC
            BNE    *+4
            INC    PC+1
            CLC
            ADC    ExprStack-2,X
            STA    ExprStack-2,X
            BCC    *+4
            INC    ExprStack-2+1,X
            JMP    MainLoop
            REP    50
; Load External Address
; External mode: Use for external variables
; imported from other modules
;
LEA         LDY    #0
            LDA    (PC),Y          ;next() -> module # 
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A               ;x2 to form an index
            STA    Z84             
;
            LDY    #0
            LDA    (PC),Y          ;next() -> offset in words
            INC    PC
            BNE    *+4
            INC    PC+1
;
            LDY    Z84
            CLC
            ADC    DFTab+1,Y       ;addr in words
            STA    ExprStack,X     ;push(stk[dft+next()]+next())
            INX
            LDA    #0
            ADC    DFTab,Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
; Jump Conditional
;
JPC         DEX
            DEX
            LDA    ExprStack,X     ;Is pop() = 0? (false)
            BEQ    JP              ;Yes
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;INC(PC,2)
            JMP    MainLoop
            REP    50
; Jump
;
JP          LDY    #0
            LDA    (PC),Y          ;hi-byte (Big E)
            PHA
            INY
            LDA    (PC),Y          ;lo-byte
            CLC
            ADC    PC              ;PC := PC + next2();
            STA    PC
            PLA
            ADC    PC+1
            STA    PC+1
            JMP    MainLoop
            REP    50
; Jump Forward Conditional
;
JPFC        DEX
            DEX
            LDA    ExprStack,X     ;Is pop() = 0?
            BEQ    JPF             ;Yes
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;INC(PC)
            JMP    MainLoop
            REP    50
; Jump Forward
;
JPF         LDY    #0
            LDA    (PC),Y          ;Get a code byte
            CLC
            ADC    PC              ;PC := PC + next();
            STA    PC
            BCC    *+4
            INC    PC+1
            JMP    MainLoop
            REP    50
; Jump Backward Conditional
;
JPBC        DEX
            DEX
            LDA    ExprStack,X     ;Is pop() = 0?
            BEQ    JPB             ;Yes
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;INC(PC)
            JMP    MainLoop
            REP    50
; Jump Backward
;
JPB         LDY    #0
            SEC
            LDA    PC
            SBC    (PC),Y
            STA    PC              ;PC := PC - next();
            BCS    *+4
            DEC    PC+1
            JMP    MainLoop
            REP    50
; Short circuit OR
;
ORJP        LDA    ExprStack-2,X   ;Is pop() = 0 (FALSE)?
            BNE    ORJP1
            LDY    #0              ;Yes
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;INC(PC)
            DEX
            DEX
            JMP    MainLoop
;
ORJP1       LDA    #<true          ;push(1) - TRUE
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            BNE    JPF             ;-> PC := PC + next()
            REP    50
; Short circuit AND
;
ANDJP       LDA    ExprStack-2,X   ;Is pop() = 0?
            BEQ    ANDJP1          ;Yes
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;INC(PC)
            DEX
            DEX
            JMP    MainLoop
;
ANDJP1      LDA    #0
            STA    ExprStack-2+1,X ;push(0)
            STA    ExprStack-2,X
            BEQ    JPF             ;-> PC := PC + next()
            REP    50
; Load Local Word
; Use for variables local to procedures
; Computes addr of the local word
; & load its value onto expr stack
; It pushes variables onto the stack
; that have an offset 16-256 words
;
LLW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            BCC    LLWPsh          ;<128 words
;
            INC    LReg+1          ;128 =< but < 256
            LDA    (LReg),Y        ;stk[L+next()]
            STA    ExprStack+1,X   ;push(stk[L+next()])
            INY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            INX
            DEC    LReg+1
            JMP    MainLoop
;
LLWPsh      LDA    (LReg),Y
            STA    ExprStack+1,X
            INY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Local Double word
;
LLD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            ASL    A
            PHP
            CLC
            ADC    LReg
            STA    Z84             ;i = L+next()
            LDA    #0
            ADC    LReg+1
            STA    Z84+1
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            LDY    #0
            LDA    (Z84),Y
            STA    ExprStack+1,X   ;push(stk[i])
            INY
            LDA    (Z84),Y
            STA    ExprStack,X
            INY
            LDA    (Z84),Y
            STA    ExprStack+2+1,X ;push(stk[i+1])
            INY
            LDA    (Z84),Y
            STA    ExprStack+2,X
            INX
            INX
            INX
            INX
            JMP    MainLoop
            REP    50
; Load External Word
;
LEW         LDY    #0
            LDA    (PC),Y          ;next() - module #
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            LDA    DFTab+1,Y       ;stk[dft+next()]
            ASL    A
            STA    Z84
            LDA    DFTab,Y
            ROL    A
            STA    Z84+1           ;addr @ corr data frame
;
            LDY    #0
            LDA    (PC),Y          ;next() - offset to external
            INC    PC              ; variable in words
            BNE    *+4
            INC    PC+1
            ASL    A               ;offset in bytes
            BCC    *+4             ;LD6FF
            INC    Z84+1
;
            TAY
            LDA    (Z84),Y
            STA    ExprStack+1,X   ;push (var) onto expr stack
            INY
            LDA    (Z84),Y
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
            REP    50
; Load External Double word 
;
LED         LDY    #0
            LDA    (PC),Y          ;next() - module #
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            LDA    DFTab+1,Y
            ASL    A
            STA    Z84             ;addr @ corr data frame
            LDA    DFTab,Y         ;dft+next()
            ROL    A
            STA    Z84+1           ;i := stk[dft+next()]
;
            LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A               ;Offset to var
            BCC    *+4             ;LD735
            INC    Z84+1           ;i := stk[dft+next()] + next()
;
            TAY
            LDA    (Z84),Y
            STA    ExprStack+1,X   ;push(stk[i])
            INY
            LDA    (Z84),Y         ;Push (var) onto stack
            STA    ExprStack,X
            INY
            LDA    (Z84),Y
            STA    ExprStack+2+1,X ;push(stk[i+1])
            INY
            LDA    (Z84),Y
            STA    ExprStack+2,X
            INX
            INX
            INX
            INX
            JMP    MainLoop
            REP    50
; LLW4-LLW15
; Loads a Local variable (Word) onto the expr stack
; LLWn -> Loads the nth word of local storage
; onto the expr stack
;
LLW4        LDY    #4*2+1
            LDA    (LReg),Y        ;push(stk[L] + (IR MOD 16)])
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW5        LDY    #5*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW6        LDY    #6*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW7        LDY    #7*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW8        LDY    #8*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW9        LDY    #9*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW10       LDY    #10*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW11       LDY    #11*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW12       LDY    #12*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW13       LDY    #13*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW14       LDY    #14*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LLW15       LDY    #15*2+1
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (LReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
; Store Local Word
; See LLW for comments
;
SLW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            ASL    A
            TAY
            BCC    SLWPop          ;<128 words
            INC    LReg+1          ;128 =< but < 256
            DEX
            LDA    ExprStack,X     ;pop()
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y        ;stk[L+next()] := pop()
            DEC    LReg+1
            JMP    MainLoop
;
SLWPop      DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
            REP    50
; Store Local Double word
; Normally use to copy an ARRAY of CHAR
; to the local space. The 1st word is
; a pointer to the CHAR ARRAY & the 2nd
; word its size.
;
SLD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            PHP                    ;save
            CLC
            ADC    LReg
            STA    Z84
            LDA    #0
            ADC    LReg+1
            STA    Z84+1           ;i := L+next()
            PLP
            BCC    *+4             ;<128 words
            INC    Z84+1           ;128 =< but < 256 words
;
            LDY    #0
            LDA    ExprStack-4+1,X
            STA    (Z84),Y         ;stk[i] := pop()
            INY
            LDA    ExprStack-4,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-2+1,X
            STA    (Z84),Y         ;stk[i+1] := pop()
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store External Word
;
SEW         LDY    #0
            LDA    (PC),Y          ;next()->module #
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            LDA    DFTab+1,Y
            ASL    A
            STA    Z84             ;addr of corr data frame
            LDA    DFTab,Y
            ROL    A
            STA    Z84+1           ;stk[dft+next()]
;
            LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A               ;offset to var in this data frame
            BCC    *+4
            INC    Z84+1
;
            TAY
            LDA    ExprStack-2+1,X
            STA    (Z84),Y         ;stk[stk[dft+next()]+next()] := pop()
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store external double word
;
SED         LDY    #0
            LDA    (PC),Y          ;next() - module #
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            LDA    DFTab+1,Y
            ASL    A
            STA    Z84             ;addr of corr data frame
            LDA    DFTab,Y
            ROL    A
            STA    Z84+1           ;i := stk[dft+next()]
;
            LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            BCC    *+4
            INC    Z84+1           ;i := stk[dft+next()] + next()
;
            TAY
            LDA    ExprStack-4+1,X
            STA    (Z84),Y         ;stk[i] := pop() 
            INY
            LDA    ExprStack-4,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-2+1,X
            STA    (Z84),Y         ;stk[i+1] := pop() 
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; SLW4-SLW15 - Store Local Word
; See LLW4 for comments
;
SLW4        LDY    #4*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y        ;stk[L+(IR MOD 16)] := pop()
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW5        LDY    #5*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW6        LDY    #6*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW7        LDY    #7*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW8        LDY    #8*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW9        LDY    #9*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW10       LDY    #10*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW11       LDY    #11*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW12       LDY    #12*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW13       LDY    #13*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW14       LDY    #14*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
;
SLW15       LDY    #15*2
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (LReg),Y
            JMP    MainLoop
            REP    50
; Load Global Word
; Loads global variables onto the expr stack
; Global vars are those in the current
; module's Data Frame. It calculates the
; address of vars which have offsets of 16-256
; words from the GReg & loads their contents
; onto expr stack
;
LGW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            BCC    LGWPsh          ;<128 words
;
            INC    GReg+1          ;128 =< but < 256
            LDA    (GReg),Y        ;G+next()
            STA    ExprStack+1,X
            INY
            LDA    (GReg),Y        ;push(stk[G+next()])
            STA    ExprStack,X
            INX
            INX
            DEC    GReg+1
            JMP    MainLoop
;
LGWPsh      LDA    (GReg),Y
            STA    ExprStack+1,X
            INY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Global Double word
; See LGW for comments
;
LGD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            PHP                    ;Save Carry
            CLC
            ADC    GReg
            STA    Z84
            LDA    #$00
            ADC    GReg+1
            STA    Z84+1
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;i := next()+G
;
            LDY    #0              ;128 =< but < 256
            LDA    (Z84),Y         ;stk[i]
            STA    ExprStack+1,X   ;push(stk[i])
            INY
            LDA    (Z84),Y
            STA    ExprStack,X
            INY
            LDA    (Z84),Y
            STA    ExprStack+2+1,X ;push(stk[i+1])
            INY
            LDA    (Z84),Y
            STA    ExprStack+2,X
            INX
            INX
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Global Word - LGW2 - LGW15
; See LGW for comments
;
LGW2        LDY    #2*2+1
            LDA    (GReg),Y        ;stk[G+IR MOD 16)]
            STA    ExprStack,X     ;push(stk[G+IR MOD 16)])
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW3        LDY    #3*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW4        LDY    #4*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW5        LDY    #5*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW6        LDY    #6*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW7        LDY    #7*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW8        LDY    #8*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW9        LDY    #9*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW10       LDY    #10*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW11       LDY    #11*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW12       LDY    #12*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW13       LDY    #13*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW14       LDY    #14*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
;
LGW15       LDY    #15*2+1
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            DEY
            LDA    (GReg),Y
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
; Store Global Word
; See LGW for comments
;
SGW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            BCC    SGWPop          ;<128
;
            INC    GReg+1          ;G+next() 128 =< but < 256
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y        ;stk[G+next()] := pop()
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            DEC    GReg+1
            JMP    MainLoop
;
SGWPop      DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
            REP    50
; Store Global Double word
;
SGD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            PHP                    ;save
;
            CLC
            ADC    GReg
            STA    Z84
            LDA    #0
            ADC    GReg+1
            STA    Z84+1           ;i := G+next()
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            LDY    #0
            LDA    ExprStack-4+1,X
            STA    (Z84),Y         ;stk[i] := pop()
            INY
            LDA    ExprStack-4,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-2+1,X ;stk[i+1] := pop()
            STA    (Z84),Y
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store Global Word SGW2 - SGW15
; See LGW2 for comments
;
SGW2        LDY    #2*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW3        LDY    #3*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW4        LDY    #4*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW5        LDY    #5*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW6        LDY    #6*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW7        LDY    #7*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW8        LDY    #8*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW9        LDY    #9*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW10       LDY    #10*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW11       LDY    #11*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW12       LDY    #12*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW13       LDY    #13*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW14       LDY    #14*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
;
SGW15       LDY    #15*2
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (GReg),Y
            JMP    MainLoop
            REP    50
; Store Stack-addressed Word
; stack mode: use for indirect addressing &
; access via pointers. Dereferencing of ptrs
;
LSW0        LDY    #0*2
;
; Common code for LSW0-LSW15
;
LSWZ        LDA    ExprStack-2,X
            ASL    A
            STA    Z84             ;addr
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1
;
            LDA    (Z84),Y         ;stk[pop()]
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X
            JMP    MainLoop
;
LSW1        LDY    #1*2
            BNE    LSWZ
LSW2        LDY    #2*2
            BNE    LSWZ
LSW3        LDY    #3*2
            BNE    LSWZ
LSW4        LDY    #4*2
            BNE    LSWZ
LSW5        LDY    #5*2
            BNE    LSWZ
LSW6        LDY    #6*2
            BNE    LSWZ
LSW7        LDY    #7*2
            BNE    LSWZ
LSW8        LDY    #8*2
            BNE    LSWZ
LSW9        LDY    #9*2
            BNE    LSWZ
LSW10       LDY    #10*2
            BNE    LSWZ
LSW11       LDY    #11*2
            BNE    LSWZ
LSW12       LDY    #12*2
            BNE    LSWZ
LSW13       LDY    #13*2
            BNE    LSWZ
LSW14       LDY    #14*2
            BNE    LSWZ
LSW15       LDY    #15*2
            BNE    LSWZ
            REP    50
; Store Stack-addressed Word - SSW0-SSW15
; See LSW
;
SSW0        LDY    #0*2
;
; Common code for SSW0-SSW15
;
SSWZ        LDA    ExprStack-4,X
            ASL    A
            STA    Z84             ;addr
            LDA    ExprStack-4+1,X
            ROL    A
            STA    Z84+1           ;i
;
            LDA    ExprStack-2+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y         ;stk[i] := k
;
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
;
SSW1        LDY    #1*2
            BNE    SSWZ
SSW2        LDY    #2*2
            BNE    SSWZ
SSW3        LDY    #3*2
            BNE    SSWZ
SSW4        LDY    #4*2
            BNE    SSWZ
SSW5        LDY    #5*2
            BNE    SSWZ
SSW6        LDY    #6*2
            BNE    SSWZ
SSW7        LDY    #7*2
            BNE    SSWZ
SSW8        LDY    #8*2
            BNE    SSWZ
SSW9        LDY    #9*2
            BNE    SSWZ
SSW10       LDY    #10*2
            BNE    SSWZ
SSW11       LDY    #11*2
            BNE    SSWZ
SSW12       LDY    #12*2
            BNE    SSWZ
SSW13       LDY    #13*2
            BNE    SSWZ
SSW14       LDY    #14*2
            BNE    SSWZ
SSW15       LDY    #15*2
            BNE    SSWZ
            REP    50
; Load Stack Word
;
LSW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            ASL    A
            TAY
            PHP                    ;save
            LDA    ExprStack-2,X   ;pop()
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;i := pop()+next()
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            LDA    (Z84),Y         ;stk[i]
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[i])
            JMP    MainLoop
            REP    50
; Load Stack Double word
;
LSD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            PHP                    ;save
;
            LDA    ExprStack-2,X   ;pop()
            ASL    A
            STA    Z84             ;addr
            LDA    ExprStack-2+1,X ;hi
            ROL    A
            STA    Z84+1
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;i := pop()+next() 128 =< but < 256
;
            LDA    (Z84),Y         ;stk[i]
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[i])
            INY
            BNE    *+4
            INC    Z84+1
;
            LDA    (Z84),Y
            STA    ExprStack+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack,X     ;push(stk[i+1])
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Stack Double word
;
LSD0        LDY    #0
            LDA    ExprStack-2,X
            ASL    A
            STA    Z84             ;addr
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;i=pop()
;
            LDA    (Z84),Y
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[i])
            INY
;
            LDA    (Z84),Y
            STA    ExprStack+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack,X     ;push(stk[i+1]);
            INX
            INX
            JMP    MainLoop
            REP    50
; Load Indexed Frame Word
; Input:
;   addr of module's code frame
;   procedure #
;
LXFW        DEX
            DEX
            LDA    ExprStack-2,X   ;addr of frame in words
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;pop()
;
            ASL    Z84
            ROL    Z84+1
            ASL    Z84
            ROL    Z84+1
            ASL    Z84
            ROL    Z84+1           ;pop()*16
;
            LDA    ExprStack,X     ;Offset in words
            ASL    A
            TAY
            LDA    ExprStack+1,X   ;pop()
            ROL    A               ;offset
            CLC
            ADC    Z84+1
            STA    Z84+1
;
            LDA    (Z84),Y
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[k])
            JMP    MainLoop
            REP    50
; Load String Address
;
LSTA        LDY    #0
            LDA    (PC),Y          ;next() - addr in words
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            LDY    #5
            ADC    (GReg),Y        ;stk[G+2]+next()
            STA    ExprStack,X
            INX
            DEY
            LDA    #0
            ADC    (GReg),Y
            STA    ExprStack,X     ;push(stk[G+2]+next())
            INX
            JMP    MainLoop
            REP    50
; Load Indexed Byte - for indexing arrays of CHAR
;
LXB         ASL    ExprStack-4,X   ;addr
            ROL    ExprStack-4+1,X ;i*2
            CLC
            LDA    ExprStack-4,X
            ADC    ExprStack-2,X
            STA    Z84
            LDA    ExprStack-4+1,X
            ADC    ExprStack-2+1,X
            STA    Z84+1           ;= j + i*2 
;
            LDY    #0
            LDA    (Z84),Y         ;stk[j + i*2]
            STA    ExprStack-4,X   ;push(stk[j + i*2])
            TYA
            STA    ExprStack-4+1,X ;zero lobyte
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Load Indexed Word - for indexing arrays of CARDINAL
;
LXW         DEX
            DEX
            LDA    ExprStack-2,X   ;addr
            CLC
            ADC    ExprStack,X     ;offset
            STA    Z84
            LDA    ExprStack-2+1,X
            ADC    ExprStack+1,X
            STA    Z84+1           ;i := pop()+pop()
            ASL    Z84
            ROL    Z84+1
;
            LDY    #0
            LDA    (Z84),Y
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[i])
            JMP    MainLoop
            REP    50
; Load Indexed Double word 
;
LXD         LDA    ExprStack-2,X
            ASL    A
            STA    ExprStack-2,X
            LDA    ExprStack-2+1,X
            ROL    A
            STA    ExprStack-2+1,X ;2*pop()
;
            CLC
            LDA    ExprStack-4,X
            ADC    ExprStack-2,X
            STA    Z84
            LDA    ExprStack-4+1,X
            ADC    ExprStack-2+1,X
            STA    Z84+1
            ASL    Z84
            ROL    Z84+1           ;i := 2*pop() + pop()
;
            LDY    #0
            LDA    (Z84),Y
            STA    ExprStack-4+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-4,X   ;push[stk[i])
            INY
            LDA    (Z84),Y
            STA    ExprStack-2+1,X
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push[stk[i+1])
            JMP    MainLoop
            REP    50
; Double float operations are not implemented.
;
DADD        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
;
DSUB        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
;
DMUL        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
;
DDIV        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Reserved for used for arithmetics
;
LDE4A       LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Double Shift Left
;
DSHL        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Double Shift Right
;
DSHR        LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Store Stack Word
;
SSW         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            ASL    A
            TAY
            PHP                    ;save
            LDA    ExprStack-4,X
            ASL    A
            STA    Z84
            LDA    ExprStack-4+1,X
            ROL    A
            STA    Z84+1           ;i := pop() + next()
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            DEX
            LDA    ExprStack,X
            STA    (Z84),Y         ;stk[i] := k
            INY
            DEX
            LDA    ExprStack,X
            STA    (Z84),Y
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store Stack Double word
;
SSD         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            ASL    A
            TAY
            PHP                    ;save
            LDA    ExprStack-6,X
            ASL    A
            STA    Z84
            LDA    ExprStack-5,X
            ROL    A
            STA    Z84+1           ;pop()+next()
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            LDA    ExprStack-4+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-4,X
            STA    (Z84),Y         ;stk[i] := j
            INY
            BNE    *+4
            INC    Z84+1
;
            DEX
            LDA    ExprStack,X
            STA    (Z84),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (Z84),Y         ;stk[i+1] := k
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store Stack Double word
;
SSD0        LDY    #0
            LDA    ExprStack-6,X
            ASL    A
            STA    Z84
            LDA    ExprStack-5,X
            ROL    A
            STA    Z84+1           ;i := pop() - addr
;
            LDA    ExprStack-4+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-4,X
            STA    (Z84),Y         ;stk[i] := j
            INY
            LDA    ExprStack-2+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack-2,X
            STA    (Z84),Y         ;stk[i+1] := k
            DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store Indexed Frame Word
; See LXFW
;
SXFW        DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            LDA    ExprStack,X
            ASL    A
            STA    Z84
            LDA    ExprStack+1,X
            ROL    A
            STA    Z84+1
            ASL    Z84
            ROL    Z84+1
;
            ASL    Z84
            ROL    Z84+1
            ASL    Z84
            ROL    Z84+1           ;pop()*16
;
            LDA    ExprStack+2,X   ;Get offset in words
            ASL    A
            TAY
            LDA    ExprStack+2+1,X
            ROL    A
            CLC
            ADC    Z84+1
            STA    Z84+1
;
            LDA    ExprStack+4+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack+4,X
            STA    (Z84),Y         ;stk[k] := i;
            JMP    MainLoop
            REP    50
; Test and Set
;
TS          LDA    ExprStack-2,X   ;addr
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;i := pop()
;
            LDY    #0
            LDA    (Z84),Y
            STA    ExprStack-2+1,X
            TYA                    ;=0
            STA    (Z84),Y
            INY
            LDA    (Z84),Y
            STA    ExprStack-2,X   ;push(stk[i])
            TYA                    ;=1
            STA    (Z84),Y         ;stk[i] := 1
            JMP    MainLoop
            REP    50
; Store Indxed Byte - use to index 
; an ARRAY of CHAR
;
SXB         ASL    ExprStack-6,X   ;addr
            ROL    ExprStack-5,X   ;i ; 2
            CLC
            LDA    ExprStack-6,X
            ADC    ExprStack-4,X   ;offset
            STA    Z84
            LDA    ExprStack-5,X
            ADC    ExprStack-4+1,X
            STA    Z84+1           ;j := pop() + i*2
;
            LDY    #0
            LDA    ExprStack-2,X
            STA    (Z84),Y         ;skt[j] := k MOD 256
            DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            JMP    MainLoop
            REP    50
; Store Indexed Word - use to
; index an ARRAY of CARDINAL
;
SXW         DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            CLC
            LDA    ExprStack,X
            ADC    ExprStack+2,X
            STA    Z84
            LDA    ExprStack+1,X
            ADC    ExprStack+2+1,X
            STA    Z84+1           ;addr in words
            ASL    Z84
            ROL    Z84+1           ;i := pop() + pop()
;
            LDY    #0
            LDA    ExprStack+5,X
            STA    (Z84),Y
            INY
            LDA    ExprStack+4,X
            STA    (Z84),Y         ;stk[i] := k
            JMP    MainLoop
            REP    50
; Store Indexed Double word
;
SXD         DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            DEX
            LDA    ExprStack+2,X
            ASL    A
            STA    ExprStack+2,X
            LDA    ExprStack+2+1,X
            ROL    A
            STA    ExprStack+2+1,X ;2*pop()
;
            CLC
            LDA    ExprStack,X
            ADC    ExprStack+2,X
            STA    Z84
            LDA    ExprStack+1,X
            ADC    ExprStack+2+1,X
            STA    Z84+1
            ASL    Z84
            ROL    Z84+1           ;i := pop() + 2*pop()
;
            LDY    #0
            LDA    ExprStack+5,X
            STA    (Z84),Y
            INY
            LDA    ExprStack+4,X
            STA    (Z84),Y         ;stk[i] := j
;
            INY
            LDA    ExprStack+6+1,X
            STA    (Z84),Y
            INY
            LDA    ExprStack+6,X
            STA    (Z84),Y         ;stk[i+1] := k
            JMP    MainLoop
            REP    50
; Floating Add, Subtract, Multiply
; Divide and Compare
; REALs are represented using 2 words
;
FADD        JSR    AddReals
            JMP    MainLoop
FSUB        JSR    SubReals
            JMP    MainLoop
FMUL        JSR    MulReals
            JMP    MainLoop
FDIV        JSR    DivReals
            JMP    MainLoop
FCMP        JSR    CmpReals
            JMP    MainLoop
            REP    50
; Floating Absolute value
;
FABS        LDA    ExprStack-4+1,X
            AND    #$7F
            STA    ExprStack-4+1,X
            JMP    MainLoop
;
; Floating Negative
;
FNEG        LDA    ExprStack-4+1,X
            EOR    #$80
            STA    ExprStack-4+1,X
            JMP    MainLoop
            REP    50
; Floating FunCTions
; >3 reserved for floating arithmetics
;
FFCT        LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CMP    #$00            ;float?
            BNE    IsFix           ;No
            JSR    FloatInt
            JMP    MainLoop
;
IsFix       CMP    #$02            ;fix?
            BNE    FFCTErr         ;No
            JSR    FixFP
            JMP    MainLoop
;
FFCTErr     LDA    #instrChk
            JSR    TrapProc
            BRK
            REP    50
; Input from channel 
;
READ        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
WRITE       LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
; Disk Read
;
DSKR        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
; Disk Write
;
DSKW        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
; Set Track
;
SETRK       LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Check j =< i =< k
;
UCHK        DEX
            DEX
            DEX
            DEX
            SEC
            LDA    ExprStack-2,X   ;i < j?
            SBC    ExprStack,X
            LDA    ExprStack-2+1,X
            SBC    ExprStack+1,X
            BCC    UChk1           ;Yes
;
            SEC                    ;j =< i
            LDA    ExprStack+2,X   ;k >= i?
            SBC    ExprStack-2,X
            LDA    ExprStack+2+1,X
            SBC    ExprStack-2+1,X
            BCS    UChk2           ;Yes
;
UChk1       LDA    #rangeChk
            JSR    TrapProc
UChk2       JMP    MainLoop
            REP    50
; 0   - reserved for debugging new instructions
; # 0 - reserved for supporting special hardware, extensions
;
ESC         LDY    #0              ;Not implemented
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
            JMP    MainLoop
            REP    50
; Rarely used system functions
; > 5 reserved for operating system needs
; The following functions has been coded
; $00,$02-$04, $64-$79 & $82-$87
;
SYS         LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    ChkSys64
            INC    PC+1
;
ChkSys64    CMP    #$64
            BNE    ChkSys65
            JMP    WrtChar         ;Display char on screen
;
ChkSys65    CMP    #$65
            BNE    ChkSys79
            JMP    ReadKey
;
ChkSys79    CMP    #$79
            BNE    ChkSys83
            JSR    LoadABS         ;Load ABS files into mem
            JMP    MainLoop
;
ChkSys83    CMP    #$83
            BNE    ChkSysFns
            JMP    WriteString
;
ChkSysFns   CMP    #$66
            BCC    ChkBoot
            CMP    #$79
            BCS    ChkBoot
;
            SEC
            SBC    #$66            ;$66-$78 -> $00-$12
            STA    ExprStack,X     ;Push call # onto
            INX
            LDA    #0              ; expression stack
            STA    ExprStack,X
            INX
            JSR    GoDOSCall       ;Call rtn handlers
            JMP    MainLoop
;
ChkBoot     CMP    #$00
            BNE    ChkSys02
            REP    50
; Sys func $00 - Bootstrap the Apple II
;
            JSR    $C600           ;Boot from slot #6
;
ChkSys02    CMP    #$02
            BNE    ChkSys03
            REP    50
; sys func $02 - Read P register
;
            LDA    PReg+1
            LSR    A
            STA    ExprStack+1,X
            LDA    PReg
            ROR    A
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
;
ChkSys03    CMP    #$03            ;Set H Limit?
            BNE    ChkSys04        ;No
;
; sys func $03 - SetStackLimit(limit: ADDRESS)
;
            LDY    #5*2
            LDA    ExprStack-2+1,X
            STA    (PReg),Y
            INY
            LDA    ExprStack-2,X
            STA    (PReg),Y        ;stk[P+5] := i
;
            SEC
            LDA    ExprStack-2,X
            SBC    #24
            STA    Z86
            LDA    ExprStack-2+1,X
            SBC    #0
            STA    Z86+1           ;=i-24 in words
;
            LDA    Z86
            ASL    A
            STA    HReg
            LDA    Z86+1
            ROL    A
            STA    HReg+1          ;H := i-24
            DEX
            DEX
            JMP    MainLoop
;
ChkSys04    CMP    #$04            ;Get H Limit
            BNE    ChkSys82        ;No
;
; sys func $04 - GetStackLimit(): ADDRESS;
;
            LDA    HReg+1
            LSR    A
            STA    Z86+1
            LDA    HReg
            ROR    A
            STA    Z86             ;in words
;
            CLC
            LDA    Z86
            ADC    #24
            STA    ExprStack,X
            INX
            LDA    Z86+1
            ADC    #0
            STA    ExprStack,X     ;push(H+24)
            INX
            JMP    MainLoop
;
ChkSys82    CMP    #$82            ;Show Catalog?
            BNE    ChkSys84
            JSR    ListDir
            JMP    MainLoop
;
ChkSys84    CMP    #$84
            BNE    ChkSys85
            JSR    StoreWrd        ;Modify mem directly
            JMP    MainLoop
;
ChkSys85    CMP    #$85
            BNE    ChkSys86
            JSR    StoreByt        ;Modify mem directly
            JMP    MainLoop
;
ChkSys86    CMP    #$86
            BNE    ChkSys87
            JSR    GoMLI           ;Call a 6502 subroutine
            JMP    MainLoop
;
ChkSys87    CMP    #$87
            BNE    SysErr
            JMP    F.GotoXY
;
SysErr      LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Entry Priority
;
ENTP        LDY    #0
            LDA    (PC),Y          ;next()
            INC    PC
            BNE    *+4
            INC    PC+1
;
            LDY    #3*2
            LDA    MReg+1
            STA    (LReg),Y
            INY
            LDA    MReg
            STA    (LReg),Y        ;stk[L+3] := CARDINAL(M)
            LDA    #0
            STA    MReg
            STA    MReg+1
            JMP    MainLoop
            REP    50
; Exit Priority
;
EXP         LDY    #3*2
            LDA    (LReg),Y
            STA    MReg+1
            INY
            LDA    (LReg),Y
            STA    MReg            ;M := stk[L+3]
            JMP    MainLoop
            REP    50
; Unsigned Less
;
ULSS        DEX
            DEX
            SEC
            LDA    ExprStack-2,X
            SBC    ExprStack,X
            LDA    ExprStack-2+1,X
            SBC    ExprStack+1,X   ;Is i < j?
            BCC    ULSS1           ;Yes
;
            LDA    #false
            STA    ExprStack-2,X
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
ULSS1       LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
ULEQ        DEX
            DEX
            SEC
            LDA    ExprStack,X
            SBC    ExprStack-2,X
            LDA    ExprStack+1,X
            SBC    ExprStack-2+1,X ;j >= i?
            BCS    ULEQ1           ;Yes
;
            LDA    #false
            STA    ExprStack-2,X
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
ULEQ1       LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
UGTR        DEX
            DEX
            SEC
            LDA    ExprStack,X
            SBC    ExprStack-2,X
            LDA    ExprStack+1,X
            SBC    ExprStack-2+1,X ;Is j < i?
            BCC    UGTR1           ;Yes
;
            LDA    #false
            STA    ExprStack-2,X
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
UGTR1       LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
UGEQ        DEX
            DEX
            SEC
            LDA    ExprStack-2,X
            SBC    ExprStack,X
            LDA    ExprStack-2+1,X
            SBC    ExprStack+1,X   ;Is i >= j?
            BCS    UGEQ1           ;Yes
;
            LDA    #false
            STA    ExprStack-2,X
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
UGEQ1       LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; coroutine TRAnsfer
;
TRA         DEX
            LDA    ExprStack,X
            STA    Z88+1           ;to
            DEX
            LDA    ExprStack,X
            STA    Z88
;
            DEX
            LDA    ExprStack,X
            STA    Z8A+1           ;from
            DEX
            LDA    ExprStack,X
            STA    Z8A
;
            LDY    #0
            LDA    (PC),Y          ;Get changeMask (msb)
            INC    PC
            BNE    *+4
            INC    PC+1
;
            ROR    A               ;Shift changeMask into Carry
            JSR    Transfer
            JMP    MainLoop
            REP    50
Transfer    PHP                    ;Save changeMask
            ASL    Z88             ;to
            ROL    Z88+1
            ASL    Z8A             ;from
            ROL    Z8A+1
;
            LDY    #0
            LDA    (Z88),Y
            STA    Z8C+1
            INY
            LDA    (Z88),Y
            STA    Z8C             ;j := stk[to]
            JSR    SaveRegs
;
            LDY    #0
            LDA    PReg+1          ;Save ptr to the curr
            LSR    A
            STA    (Z8A),Y         ; process descriptor
            INY
            LDA    PReg
            ROR    A
            STA    (Z8A),Y         ;stk[from] := P
;
            LDA    Z8C             ;Use this as our curr
            ASL    A
            STA    PReg            ; process descriptor
            LDA    Z8C+1
            ROL    A
            STA    PReg+1          ;P := j
            PLP                    ;changeMask
            JSR    RstRegs
            RTS
            REP    50
; ReaD String - Not implemented
;
RDS         LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Reload expression stack after function return
;
LODFW       DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88             ;i := pop()
            JSR    RstExpStk
            LDA    Z88
            STA    ExprStack,X
            INX
            LDA    Z88+1
            STA    ExprStack,X     ;push(i)
            INX
            JMP    MainLoop
            REP    50
; reload expression stack after function return
;
LODFD       DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88             ;i := pop()
;
            DEX
            LDA    ExprStack,X
            STA    Z8A+1
            DEX
            LDA    ExprStack,X
            STA    Z8A             ;j := pop()
            JSR    RstExpStk
;
            LDA    Z8A
            STA    ExprStack,X
            INX
            LDA    Z8A+1
            STA    ExprStack,X     ;push(j)
;
            INX
            LDA    Z88
            STA    ExprStack,X
            INX
            LDA    Z88+1
            STA    ExprStack,X     ;push(i)
            INX
            JMP    MainLoop
            REP    50
; ExpStackSize=16 words
; One extra word to store # of
; words of valid expr stack data
;
STORE       CLC                    ;Prepare to chk there is...
            LDA    SReg
            ADC    #32+2           ;(expStackSize+1)*2
            STA    Z86
            LDA    SReg+1
            ADC    #0
            STA    Z86+1           ; ...enuf program stack space
;
            SEC
            LDA    HReg            ;Is H < S+(expStackSize+1)?
            SBC    Z86
            LDA    HReg+1
            SBC    Z86+1
            BCC    OutMM1          ;Yes -> OutMem
            JSR    SaveExpStack
            JMP    MainLoop
;
OutMM1      LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Store stack with formal procedure on top
;
STOFV       DEX
            LDA    ExprStack,X
            STA    Z8C+1
            DEX
            LDA    ExprStack,X
            STA    Z8C             ;i := pop()
;
            CLC
            LDA    SReg
            ADC    #32+2           ;(expStackSize+1)*2
            STA    Z86
            LDA    SReg+1
            ADC    #0
            STA    Z86+1
;
            SEC
            LDA    HReg            ;Is H < S+(expStackSize+1)?
            SBC    Z86
            LDA    HReg+1
            SBC    Z86+1
            BCC    OutMM2          ;Yes -> OutMem
;
            JSR    SaveExpStack
            LDY    #0
            LDA    Z8C+1
            STA    (SReg),Y
            INY
            LDA    Z8C
            STA    (SReg),Y        ;stk[S] := i;
;
            CLC
            LDA    SReg            ;INC(S)
            ADC    #2
            STA    SReg
            LDA    SReg+1
            ADC    #0
            STA    SReg+1
            JMP    MainLoop
;
OutMM2      LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; copy 1 word from expr stack to procedure stack
;
STOT        LDY    #0
            DEX
            LDA    ExprStack,X
            STA    (SReg),Y
            INY
            DEX
            LDA    ExprStack,X
            STA    (SReg),Y        ;stk[S] := pop()
;
            CLC
            LDA    SReg
            ADC    #2
            STA    SReg
            BCC    *+4             ;LE32B
            INC    SReg+1          ;INC(S)
;
            SEC
            LDA    HReg            ;H < S?
            SBC    SReg
            LDA    HReg+1
            SBC    SReg+1
            BCC    *+5             ;Yes -> OutMem
            JMP    MainLoop
;
; recover
;
            INX
            INX
            SEC
            LDA    SReg
            SBC    #2
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;DEC(S)
;
            LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; copy element (1 word) on top of expr stack
;
COPT        LDA    ExprStack-2,X
            STA    ExprStack,X
            LDA    ExprStack-2+1,X
            STA    ExprStack+1,X
            INX
            INX
            JMP    MainLoop
            REP    50
; Decrement program Stack pointer
;
DECS        SEC
            LDA    SReg
            SBC    #2
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1
            JMP    MainLoop
            REP    50
; Allocation and copy of value parameter.
; Calc addr of local var whose offset fr
; L-reg is the next byte of code stream.
; Allocate space (# of words is on tos)
; for this var & set local var to point
; to the program stack space. The local var
; is the dest addr.
; Copy value parameter (usually a record)
; to the allocated space
;
PCOP        LDY    #0
            LDA    (PC),Y          ;Get offset fr BO LReg
            INC    PC
            BNE    *+4
            INC    PC+1            ;next()
;
            ASL    A               ;x2
            PHP                    ;save
            CLC
            ADC    LReg
            STA    Z84             ;addr of local var
            LDA    #0
            ADC    LReg+1
            STA    Z84+1           ;=L+next()
            PLP
            BCC    *+4             ;<128
            INC    Z84+1           ;128 =< but < 256
;
            LDY    #0
            LDA    SReg+1          ;curr program stack ptr
            LSR    A
            STA    (Z84),Y         ;Save ptr to program stack
            LDA    SReg
            ROR    A               ; space expressed in words
            INY
            STA    (Z84),Y         ;stk[L+next()] := S
;
; Compute size of program stack space to
; allocate which is already on the tos
;
            LDA    ExprStack-2,X   ;Do a 2's complement
            EOR    #$FF            ; on the size
            CLC
            ADC    #$01
            STA    numBytes
            LDA    ExprStack-2+1,X
            EOR    #$FF
            ADC    #$00
            STA    numBytes+1      ;= -sz
;
            ASL    ExprStack-2,X   ;# of bytes to allocate
            ROL    ExprStack-2+1,X
            CLC
            LDA    ExprStack-2,X
            ADC    SReg
            STA    EndAdr
            LDA    ExprStack-2+1,X
            ADC    SReg+1
            STA    EndAdr+1        ;k := sz+S
            DEX
            DEX
;
            SEC
            LDA    HReg            ;If H < k
            SBC    EndAdr
            LDA    HReg+1
            SBC    EndAdr+1
            BCC    OutMM3          ; then -> OutMM
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;srcaddr := pop()
            DEX
            DEX
;
; WHILE sz # 0
;
            LDY    #0
            LDA    numBytes
            BNE    CpyLoop1
            LDA    numBytes+1
            BEQ    PCopDone
CpyLoop1    LDA    (Z84),Y
            STA    (SReg),Y
            INY
            LDA    (Z84),Y
            STA    (SReg),Y        ;stk[S] := stk[adr]
            INY
            BNE    PCop1
            INC    Z84+1           ;INC(adr)
            INC    SReg+1          ;INC(S)
PCop1       INC    numBytes        ;INC(sz)
            BNE    CpyLoop1
            INC    numBytes+1
            BNE    CpyLoop1
;
PCopDone    LDA    EndAdr
            STA    SReg
            LDA    EndAdr+1
            STA    SReg+1          ;S := k
            JMP    MainLoop
;
OutMM3      INX
            INX
            LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
;
numBytes    DW     0
EndAdr      DW     0
            REP    50
; Unsigned integer operations
; Addition, Subtraction,
; Multiplication & Division
;
UADD        CLC
            LDA    ExprStack-4,X
            ADC    ExprStack-2,X
            STA    ExprStack-4,X
            LDA    ExprStack-2+1,X
            ADC    ExprStack-4+1,X
            STA    ExprStack-4+1,X
            DEX
            DEX
            BCC    UAdd1
            JMP    UMulErr         ;Trap(CardOvfl)
UAdd1       JMP    MainLoop
;
USUB        SEC
            LDA    ExprStack-4,X
            SBC    ExprStack-2,X
            STA    ExprStack-4,X
            LDA    ExprStack-4+1,X
            SBC    ExprStack-2+1,X
            STA    ExprStack-4+1,X
            DEX
            DEX
            BCS    USub1
            JMP    UMulErr          ;Trap(CardOvfl)
USub1       JMP    MainLoop
            REP    50
; Note: Big Endian format on expression
; stack but Little Endian in memory
;
UMUL        DEX
            LDA    ExprStack,X
            STA    Z88+1           ;multiplier
            DEX
            LDA    ExprStack,X
            STA    Z88
;
            LDA    ExprStack-2,X
            STA    Z86             ;multiplicand
            LDA    ExprStack-2+1,X
            STA    Z86+1
            STX    ExprStkP
;
            LDX    #0              ;partial product in (Y,X)
            LDY    #0
UMulLup     LSR    Z88+1           ;Shift multiplier
            ROR    Z88             ;If rightmost bit=0, don't
            BCC    UMul1           ; add to partial product
            CLC
            TXA
            ADC    Z86
            TAX
            TYA
            ADC    Z86+1
            TAY
            BCS    UMulErr         ;Overflow -> Trap(CardOvfl)
;
UMul1       ASL    Z86             ;Shift the multiplicand
            ROL    Z86+1           ; left for next iteration
            LDA    Z88
            ORA    Z88+1
            BEQ    UMulDone        ;-> done
            BCC    UMulLup         ;Loop back for next iteration
            JMP    UMulErr         ;Trap(CardOvfl)
;
UMulDone    TXA
            LDX    ExprStkP
            STA    ExprStack-2,X
            TYA
            STA    ExprStack-2+1,X
            JMP    MainLoop
UMulErr     LDA    #cardOvfl
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Calculate the quotient of a divison
;
UDIV        DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88
            BNE    UDiv1
            LDA    Z88+1           ;divisor
            BNE    UDiv1           ;j > 0
            DEX
            DEX
            LDA    #cardOvfl       ;-> div by 0
            JSR    TrapProc
            JMP    MainLoop
;
UDiv1       LDA    ExprStack-2,X
            STA    Z86             ;dividend
            LDA    ExprStack-2+1,X
            STA    Z86+1           ;i
;
            SEC
            LDA    Z86             ;Is i >= j?
            SBC    Z88
            LDA    Z86+1
            SBC    Z88+1
            BCS    UDiv2           ;Yes
;
            LDA    #0              ;quotient is 0
            STA    ExprStack-2,X   ; since dividend
            STA    ExprStack-2+1,X ; is < divisor
            JMP    MainLoop
;
UDiv2       LDA    #0
            STA    Z8A
            STA    Z8A+1
            STA    Z8C             ;quotient
            STA    Z8C+1
            STX    ExprStkP
;
            LDY    #16             ;# of iterations
            LDA    Z86+1
            BNE    UDivLup         ;16 by 16
;
            LDA    Z88             ;divisor
            STA    Z8A+1
            LDA    Z88+1
            STA    Z88
;
            LDY    #8              ;8 by 8
UDivLup     CLC
            ROR    Z88+1           ;Shift until both
            BNE    UDiv3
            ROR    Z88             
            BNE    UDiv4
;
            ROR    Z8A+1           ; bytes are zero
            ROR    Z8A
            LDA    Z86             ;dividend (i)
            SEC
            SBC    Z8A             ;divisor
            TAX
            LDA    Z86+1
            SBC    Z8A+1
            BCC    UDiv5           ;can't subtract divisor fr dividend
;
            STA    Z86+1
            STX    Z86
            SEC
            ROL    Z8C             ;quotient
            ROL    Z8C+1
            DEY
            BNE    UDivLup
            BEQ    UDivDone        ;->done
;
UDiv3       ROR    Z88             ;Shift divisor right
UDiv4       ROR    Z8A+1           ;for next iteration
            ROR    Z8A
;
UDiv5       CLC
            ROL    Z8C             ;quotient
            ROL    Z8C+1
            DEY
            BNE    UDivLup
;
UDivDone    LDX    ExprStkP
            LDA    Z8C             ;quotient
            STA    ExprStack-2,X
            LDA    Z8C+1
            STA    ExprStack-2+1,X
            JMP    MainLoop
            REP    50
; Calculate the remainder of a division
;
UMOD        DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88
            BNE    UMod1
            LDA    Z88+1           ;divisor
            BNE    UMod1
            DEX                    ;(Z88)=0 -> div by 0
            DEX
            LDA    #cardOvfl
            JSR    TrapProc
            JMP    MainLoop
;
UMod1       LDA    ExprStack-2,X
            STA    Z86             ;dividend
            LDA    ExprStack-2+1,X
            STA    Z86+1
;
            SEC
            LDA    Z86             ;Is dividend >= divisor?
            SBC    Z88
            LDA    Z86+1
            SBC    Z88+1
            BCS    UMod2           ;Yes
;
            LDA    Z86             ;Return dividend
            STA    ExprStack-2,X
            LDA    Z86+1           ; as remainder
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
UMod2       LDA    #0
            STA    Z8A
            STA    Z8A+1
            STA    Z8A+2
            STA    Z8A+3
            STX    ExprStkP
;
            LDY    #16             ;# of iterations
            LDA    Z86+1           ;dividend
            BNE    UModLup
;
            LDA    Z88
            STA    Z8A+1
            LDA    Z88+1
            STA    Z88
;
            LDY    #8
UModLup     CLC
            ROR    Z88+1
            BNE    UMod3
            ROR    Z88
            BNE    UMod4
;
            ROR    Z8A+1
            ROR    Z8A
            LDA    Z86
            SEC
            SBC    Z8A
            TAX
            LDA    Z86+1
            SBC    Z8A+1
            BCC    UMod5
;
            STA    Z86+1
            STX    Z86
            SEC
            ROL    Z8C
            ROL    Z8C+1           ;quotient
            DEY
            BNE    UModLup
            BEQ    UModDone
;
UMod3       ROR    Z88
UMod4       ROR    Z8A+1
            ROR    Z8A
;
UMod5       CLC
            ROL    Z8C             ;quotient
            ROL    Z8C+1
            DEY
            BNE    UModLup
;
UModDone    LDX    ExprStkP
            LDA    Z86
            STA    ExprStack-2,X   ;remainder
            LDA    Z86+1
            STA    ExprStack-2+1,X
            JMP    MainLoop
            REP    50
ROR         LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Word on expr stack is left shifted by i places 
;
SHL         DEX
            DEX
            LDA    ExprStack,X
            AND    #$0F
            BEQ    Shl1
;
            TAY                    ;i := pop() MOD 16
ShiftLup    ASL    ExprStack-2,X
            ROL    ExprStack-2+1,X
            DEY
            BNE    ShiftLup
Shl1        JMP    MainLoop
            REP    50
; Word on expr stack is right shifted by i places 
;
SHR         DEX
            DEX
            LDA    ExprStack,X
            AND    #$0F
            BEQ    Shr1
;
            TAY                    ;i := pop() MOD 16
ShiftLup2   LSR    ExprStack-2+1,X
            ROR    ExprStack-2,X
            DEY
            BNE    ShiftLup2
Shr1        JMP    MainLoop
            BRK
            REP    50
; enter FOR statement 
;
FOR1        DEX
            LDA    ExprStack,X
            STA    Z86+1
            DEX
            LDA    ExprStack,X
            STA    Z86             ;lup
;
            DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88             ;llow
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;ladr (running var)
            DEX
            DEX
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z8A             ;i := next() 0-up #0-down
;
            SEC
            LDA    HReg            ;Is S > H?
            SBC    SReg
            LDA    HReg+1
            SBC    SReg+1
            BCC    OutMM4          ;Yes
;
            LDA    PC              ;H >= S
            STA    Z8C
            LDA    PC+1
            STA    Z8C+1           ;=PC
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            PHA                    ;next2()
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            ADC    Z8C
            STA    Z8C
            PLA
            ADC    Z8C+1
            STA    Z8C+1           ;k=PC+next2()
;
            LDA    Z8A
            BNE    ForDown         ;down
            LDA    #%00000101      ;test for >=
            STA    TestCond
            JSR    ChkTrue
            BNE    ForLoop         ;True
;
SkipLoop    LDA    Z8C             ;Don't execute the FOR loop
            STA    PC
            LDA    Z8C+1
            STA    PC+1            ;PC=k
            JMP    MainLoop
;
ForDown     LDA    #%00000011      ;test for =<
            STA    TestCond
            JSR    ChkTrue
            BEQ    SkipLoop
;
; Enter the loop
;
ForLoop     LDY    #0
            LDA    Z88+1
            STA    (Z84),Y
            INY
            LDA    Z88
            STA    (Z84),Y         ;stk[ladr] := llow
            LDY    #0
            LDA    Z84
            STA    (SReg),Y
            INY
            LDA    Z84+1
            STA    (SReg),Y        ;stk[S] := ladr
            INY                    ;INC(S)
            LDA    Z86
            STA    (SReg),Y
            INY
            LDA    Z86+1
            STA    (SReg),Y        ;stk[S] := lup
;
            CLC
            LDA    #4
            ADC    SReg
            STA    SReg            ;INC(S, 2)
            LDA    #0
            ADC    SReg+1
            STA    SReg+1
            JMP    MainLoop
;
OutMM4      LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; exit FOR statement
;
FOR2        DEC    SReg+1
            LDY    #252
            LDA    (SReg),Y
            STA    Z84             ;ladr := stk[S-2]
            INY
            LDA    (SReg),Y
            STA    Z84+1
;
            INY
            LDA    (SReg),Y
            STA    Z86             ;lup := stk[S-1]
            INY
            LDA    (SReg),Y
            STA    Z86+1
            INC    SReg+1
;
            LDY    #0
            LDA    (PC),Y          ;Get lsz
            INC    PC
            BNE    *+4
            INC    PC+1
;
; -128 =< lsz =< 127 ($FFxx =< lsz =< $00xx)
;
            STA    Z8A
            TAY                    ;Is integer < 0?
            BMI    ExitFor3        ;Yes
            LDA    #$00
            BEQ    ExitFor4        ;always
ExitFor3    LDA    #$FF
ExitFor4    STA    Z8A+1           ;sz := next()
;
            LDA    PC
            STA    Z8C
            LDA    PC+1
            STA    Z8C+1           ;=PC
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            PHA                    ;next2()
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            ADC    Z8C
            STA    Z8C
            PLA
            ADC    Z8C+1
            STA    Z8C+1           ;k := PC + next2()
;
            CLC
            LDY    #1
            LDA    (Z84),Y
            ADC    Z8A
            STA    Z88
            DEY
            LDA    (Z84),Y
            ADC    Z8A+1
            STA    Z88+1           ;i := lsz+stk[ladr]
;
            LDA    Z8A+1
            BMI    ExitFor5        ;lsz < 0
            LDA    #%00000010      ; i < lup?
            STA    TestCond
            JSR    ChkTrue
            BNE    ExitFor7
            LDA    Z8A
            BNE    ExitFor6        ;lsz # 0
ExitFor5    LDA    #%00000100      ;(i > lup AND lsz =< 0)
            STA    TestCond
            JSR    ChkTrue
            BNE    ExitFor7
;
ExitFor6    LDY    #0
            LDA    Z88+1
            STA    (Z84),Y
            INY
            LDA    Z88
            STA    (Z84),Y         ;stk[ladr] := i
;
            LDA    Z8C
            STA    PC
            LDA    Z8C+1
            STA    PC+1            ;PC := k
            JMP    MainLoop
;
ExitFor7    SEC
            LDA    SReg
            SBC    #4
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;DEC(S,2)
            JMP    MainLoop
            REP    50
; ENTer Case statement
;
ENTC        LDA    PC
            STA    Z86
            LDA    PC+1
            STA    Z86+1           ;=PC
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            PHA                    ;next2()
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            ADC    Z86
            STA    PC
            PLA
            ADC    Z86+1
            STA    PC+1            ;PC := PC + next2()
;
            DEX
            LDA    ExprStack,X
            STA    Z86+1
            DEX
            LDA    ExprStack,X
            STA    Z86             ;k := pop()
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z8A+1           ;llow := next2()
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z8A
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z88+1           ;lup := next2()
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z88
;
            STX    ExprStkP
            SEC
            LDA    Z88
            SBC    Z8A
            TAX
            LDA    Z88+1
            SBC    Z8A+1
            TAY                    ;(Y,X) := lup-llow
            TXA
            ASL    A
            TAX
            TYA
            ROL    A
            TAY                    ;(Y,X) := 2*(lup-llow)
;
            CLC
            TXA
            ADC    #4
            TAX
            TYA
            ADC    #0
            TAY                    ;(Y,X) := 2*(lup-llow) + 4
;
            CLC
            TXA
            ADC    PC
            TAX
            TYA
            ADC    PC+1
;
            LDY    #1
            STA    (SReg),Y        ;stk[S] := PC + 2*(lup-llow) + 4
            DEY
            TXA
            STA    (SReg),Y
;
            CLC
            LDA    SReg
            ADC    #2
            STA    SReg
            LDA    SReg+1
            ADC    #0
            STA    SReg+1          ;INC(S)
;
            SEC
            LDA    Z88             ;Is lup < k?
            SBC    Z86
            LDA    Z88+1
            SBC    Z86+1
            BCC    EntC2           ;Yes
;
            SEC
            LDA    Z86             ;Is k < llow?
            SBC    Z8A
            LDA    Z86+1
            SBC    Z8A+1
            BCC    EntC2           ;Yes
;
; llow =< k AND k =< lup
;
            SEC
            LDA    Z86
            SBC    Z8A
            TAX
            LDA    Z86+1
            SBC    Z8A+1
            TAY                    ;(Y,X) := k-llow
            INX
            BNE    EntC1
            INY                    ;(Y,X) := k-llow+1
;
EntC1       TXA
            ASL    A
            TAX
            TYA
            ROL    A
            TAY                    ;(Y,X) := 2*(k-llow+1)
;
            CLC
            TXA
            ADC    PC
            STA    PC
            TYA
            ADC    PC+1
            STA    PC+1            ;PC := PC + 2*(k-llow+1)
;
EntC2       LDA    PC
            STA    Z86
            LDA    PC+1
            STA    Z86+1
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            PHA                    ;next2()
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
;
            CLC
            ADC    Z86
            STA    PC
            PLA
            ADC    Z86+1
            STA    PC+1            ;PC := PC + next2()
            LDX    ExprStkP
            JMP    MainLoop
            REP    50
; EXit Case statement
;
EXC         SEC
            LDA    SReg
            SBC    #2
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;DEC(S)
;
            LDY    #0
            LDA    (SReg),Y
            STA    PC
            INY
            LDA    (SReg),Y
            STA    PC+1            ;PC := stk[S]
            JMP    MainLoop
            REP    50
; trap instruction - TRAP(err)
;
TRAP        LDA    ExprStack-2,X
            DEX
            DEX
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Trap Procedure
;
TrapProc    AND    #$0F
            STA    Z86             ;n
            CMP    #8
            BCS    Trap8A          ;8-15
;
            TAY                    ;0-7
            LDA    BitMsk,Y
            LDY    #7*2
            BNE    Trap2           ;always
;
Trap8A      LSR    A
            TAY
            LDA    BitMsk,Y
            LDY    #7*2+1
;
Trap2       AND    (PReg),Y        ;Is n IN stk[P+7]?
            BNE    doRTS1          ;Yes
;
            LDY    #6*2
            LDA    #0
            STA    (PReg),Y
            INY
            LDA    Z86
            STA    (PReg),Y        ;stk[P+6] := n
;
            LDA    #$0E
            STA    Z88
            LDA    #$04            ;trap locn addr (to)
            STA    Z88+1           ;tlc = $081C
;
            LDA    #$0F
            STA    Z8A
            LDA    #$04
            STA    Z8A+1           ;tlc+1 = $081E (from)
            SEC                    ;changeMask=TRUE
            JSR    Transfer
doRTS1      RTS
            REP    50
CHK         LDA    #instrChk
            JSR    TrapProc
            JMP    MainLoop
;
; check i =< k
;
CHKZ        DEX
            DEX
            SEC
            LDA    ExprStack,X     ;k
            SBC    ExprStack-2,X   ;i
            LDA    ExprStack+1,X
            SBC    ExprStack-2+1,X
            BCC    ChkZ1           ;k < i
            JMP    MainLoop        ;No, k >= i
;
ChkZ1       LDA    #$01
            STA    $0400+$10       ;scrn hole?
            LDA    #rangeChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; CHecK Sign bit
;
CHKS        LDA    ExprStack-2+1,X
            BPL    ChkS1
            LDA    #rangeChk       ;k < 0
            JSR    TrapProc
ChkS1       JMP    MainLoop
            REP    50
; Equal
;
EQL         DEX
            DEX
            LDA    ExprStack,X     ;j
            CMP    ExprStack-2,X   ;i
            BNE    NotEQL
            LDA    ExprStack+1,X   ;Is j = i?
            CMP    ExprStack-2+1,X
            BNE    NotEQL
;
            LDA    #<true          ;Yes
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
;
NotEQL      LDA    #false
            STA    ExprStack-2+1,X
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; Not EQual
;
NEQ         DEX
            DEX
            LDA    ExprStack,X     ;j
            CMP    ExprStack-2,X   ;i
            BNE    RtnTrue1
            LDA    ExprStack+1,X
            CMP    ExprStack-2+1,X
            BNE    RtnTrue1
;
            LDA    #false
            STA    ExprStack-2+1,X
            STA    ExprStack-2,X
            JMP    MainLoop
;
RtnTrue1    LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; These routines are used to test
; boolean expressions. We are only
; interested in whether the condition
; is true (Z=0) or false (Z=1)
;
LSS         LDA    #%00000010      ;Test for <
            BPL    SetCond
LEQ         LDA    #%00000011      ;Test for =<
            BPL    SetCond
GTR         LDA    #%00000100      ;Test for >
            BPL    SetCond
GEQ         LDA    #%00000101      ;Test for >=
;
SetCond     STA    TestCond
            DEX
            DEX
            LDA    ExprStack-2,X   ;Get word values
            STA    Z86
            LDA    ExprStack-2+1,X
            STA    Z86+1           ;i
;
            LDA    ExprStack,X
            STA    Z88
            LDA    ExprStack+1,X
            STA    Z88+1           ;j
            JSR    ChkTrue
            BNE    RtnTrue2
;
            LDA    #false
            STA    ExprStack-2+1,X
            STA    ExprStack-2,X
            JMP    MainLoop
;
RtnTrue2    LDA    #<true
            STA    ExprStack-2+1,X
            LDA    #>true
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; Input
;  (Z86) = word value1
;  (Z88) = word value2
; Z=0 - true
; Z=1 -> false
;
ChkTrue     LDA    Z86+1           ;lup/i
            EOR    Z88+1           ;llow/j
            BMI    OppSigns        ;Opposite signs
            LDA    Z86+1
            CMP    Z88+1
            BNE    ChkNotEQ
            LDA    Z86
            CMP    Z88
            BEQ    TestEQ          ;lup == llow
ChkNotEQ    BCC    TestLT          ;lup < llow
            BCS    TestGT          ;lup > llow (Always)
;
; If the signs are opposite, the 2 values
; can never be equal. So we need to test for
; the conditions Greater Than or Less Than.
;
OppSigns    LDA    Z86+1           ;lup/i
            BMI    TestLT          ;lup < llow
;
TestGT      LDA    #%00000100      ;Greater
            BPL    TestNow         ;Always
TestEQ      LDA    #%00000001      ;Equal
            BPL    TestNow         ;Always
TestLT      LDA    #%00000010      ;Less
TestNow     AND    TestCond        ;Result in Z-bit
            RTS
;
TestCond    DFB    0
            REP    50
ABS         LDA    ExprStack-2+1,X
            BMI    NEG
            JMP    MainLoop
;
NEG         CLC
            LDA    ExprStack-2,X   ;Do a 2's complement
            EOR    #$FF
            ADC    #1
            STA    ExprStack-2,X
            LDA    ExprStack-2+1,X
            EOR    #$FF
            ADC    #0
            STA    ExprStack-2+1,X
            CMP    #$80
            BNE    Neg1
            LDA    ExprStack-2,X
            BNE    Neg1
            LDA    #intOvfl        ;$8000
            JSR    TrapProc
Neg1        JMP    MainLoop
            REP    50
; BITSET(j)+BITSET(i)
;
OR          DEX
            DEX
            LDA    ExprStack-2+1,X ;j
            ORA    ExprStack+1,X   ;i
            STA    ExprStack-2+1,X
            LDA    ExprStack-2,X
            ORA    ExprStack,X
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; BITSET(j)/BITSET(i)
;
XOR         DEX
            DEX
            LDA    ExprStack-2+1,X
            EOR    ExprStack+1,X
            STA    ExprStack-2+1,X
            LDA    ExprStack-2,X
            EOR    ExprStack,X
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; BITSET(j)*BITSET(i)
;
AND         DEX
            DEX
            LDA    ExprStack-2+1,X
            AND    ExprStack+1,X
            STA    ExprStack-2+1,X
            LDA    ExprStack-2,X
            AND    ExprStack,X
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
COM         LDA    ExprStack-2+1,X ;Do 1's complement
            EOR    #$FF
            STA    ExprStack-2+1,X
            LDA    ExprStack-2,X
            EOR    #$FF
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; Since the 6502 is an 8-bit processor
; this processing of this instruction
; is divided in two parts.
;
IN          DEX
            DEX
            LDA    ExprStack-2+1,X ;must be 0
            BNE    RetFalse
            LDA    ExprStack-2,X   ;only 0-15 is valid
            CMP    #16             ;i > 15
            BCS    RetFalse        ; => false
            CMP    #8
            BCS    TestUpr         ;i = 8-15
            TAY
            LDA    BitMsk,Y        ; Is i IN BITSET(j)?
            AND    ExprStack+1,X
            BEQ    RetFalse        ;No
;
RtnTrue3    LDA    #>true
            STA    ExprStack-2,X
            LDA    #<true
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
TestUpr     AND    #%00000111      ;8-15 -> 0-7
            TAY
            LDA    BitMsk,Y        ; Is i IN BITSET(j)?
            AND    ExprStack,X
            BNE    RtnTrue3        ;Yes
;
RetFalse    LDA    #false
            STA    ExprStack-2+1,X
            STA    ExprStack-2,X
            JMP    MainLoop
;
BitMsk      DFB    $80,$40,$20,$10,$08,$04,$02,$01
            REP    50
; Load Immediate NIL ($FFFF or -1)
;
LIN         LDA    #$FF
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            JMP    MainLoop
            REP    50
MSK         LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
NOT         LDA    ExprStack-2,X
            EOR    #$01
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; Arithmetic perations on signed integers
;
ADD         CLC
            LDA    ExprStack-4,X   ;i
            ADC    ExprStack-2,X   ;j
            STA    ExprStack-4,X
            LDA    ExprStack-4+1,X
            ADC    ExprStack-2+1,X
            STA    ExprStack-4+1,X
            DEX
            DEX
            BVC    Add1
            LDA    #intOvfl
            JSR    TrapProc
Add1        JMP    MainLoop
;
SUB         SEC
            LDA    ExprStack-4,X   ;i
            SBC    ExprStack-2,X   ;j
            STA    ExprStack-4,X
            LDA    ExprStack-4+1,X
            SBC    ExprStack-2+1,X
            STA    ExprStack-4+1,X
            DEX
            DEX
            BVC    Sub1
            LDA    #intOvfl
            JSR    TrapProc
Sub1        JMP    MainLoop
            REP    50
; Multiplication of signed integers
; See UMUL for comments
;
MUL         LDA    #$00
            STA    Z84             ;assume +ve result
            DEX
            LDA    ExprStack,X
            STA    Z88+1           ;j
            DEX
            LDA    ExprStack,X
            STA    Z88             ;multiplier
;
            LDA    ExprStack-2,X   ;i
            STA    Z86
            LDA    ExprStack-2+1,X
            STA    Z86+1           ;multiplicand
            BPL    Mul1            ;i > 0
;
            LDA    #$01            ;result may be -ve 
            STA    Z84
;
            CLC
            LDA    Z86             ;Do a 2's complement
            EOR    #$FF
            ADC    #$01
            STA    Z86
            LDA    Z86+1
            EOR    #$FF
            ADC    #$00
            STA    Z86+1
            BMI    OvrFlow1        ;-> overflow
;
Mul1        LDA    Z88+1           ;Is j < 0?
            BPL    Mul2            ;No
;
            LDA    Z84
            EOR    #$01
            STA    Z84             ;sign of result
;
            CLC
            LDA    Z88             ;Do a 2's complement
            EOR    #$FF
            ADC    #$01
            STA    Z88
            LDA    Z88+1
            EOR    #$FF
            ADC    #$00
            STA    Z88+1
            BMI    OvrFlow1        ;-> overflow
;
Mul2        STX    ExprStkP
            LDX    #0              ;partial result in (Y,X)
            LDY    #0
MulLoop1    LSR    Z88+1
            ROR    Z88             ;multiplier
            BCC    Mul3            ;Don't add if bit is 0
            CLC
            TXA
            ADC    Z86             ;multiplicand
            TAX
            TYA
            ADC    Z86+1
            TAY
            BVS    OvrFlow1        ;-> overflow
Mul3        ASL    Z86
            ROL    Z86+1
            LDA    Z88
            ORA    Z88+1
            BEQ    MulDone1
            BVC    MulLoop1
            JMP    OvrFlow1        ;-> overflow
;
MulDone1    LDA    Z84
            BNE    NegRslt         ;-ve result
            TXA
            LDX    ExprStkP
            STA    ExprStack-2,X
            TYA
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
NegRslt     TXA
            LDX    ExprStkP
            CLC                    ;Do a 2's complement
            EOR    #$FF
            ADC    #$01
            STA    ExprStack-2,X
            TYA
            EOR    #$FF
            ADC    #$00
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
OvrFlow1    LDA    #intOvfl
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Division of signed integers
;
DIV         DEX
            LDA    ExprStack,X
            STA    Z88+1
            DEX
            LDA    ExprStack,X
            STA    Z88
            BNE    Div1
            LDA    Z88+1           ;Is j=0?
            BNE    Div1            ;No
;
            DEX
            DEX
            LDA    #intOvfl        ;Division by 0
            JSR    TrapProc
            JMP    MainLoop
;
Div1        LDA    ExprStack-2,X
            STA    Z86             ;i
            LDA    ExprStack-2+1,X
            STA    Z86+1
;
            LDA    #$00
            STA    Z8A
            STA    Z8A+1
            STA    Z8C
            STA    Z8C+1
            STA    Z84
            LDA    Z86+1           ;Is i < 0?
            BPL    Div2
;
            LDA    #$01            ;Yes
            STA    Z84             ;Sign of result
            CLC
            LDA    Z86             ;Do a 2's complement
            EOR    #$FF
            ADC    #$01
            STA    Z86             ; on the dividend
            LDA    Z86+1
            EOR    #$FF
            ADC    #$00
            STA    Z86+1
            BMI    OvrFlow1        ;-> overflow
;
Div2        LDA    Z88+1           ;Is j < 0?
            BPL    Div3            ;No
;
            LDA    Z84
            EOR    #$01
            STA    Z84
            CLC
            LDA    Z88             ;Do a 2's complement
            EOR    #$FF
            ADC    #$01
            STA    Z88             ; on the divisor
            LDA    Z88+1
            EOR    #$FF
            ADC    #$00
            STA    Z88+1
            BMI    OvrFlow1        ;-> overflow
;
Div3        SEC
            LDA    Z86             ;Is i >= j in magnitude?
            SBC    Z88
            LDA    Z86+1
            SBC    Z88+1
            BCS    Div4            ;Yes
            LDA    #$00
            STA    ExprStack-2,X   ;Quotient=0
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
Div4        STX    ExprStkP
            LDY    #16             ;16 by 16
            LDA    Z86+1           ;Is dividend an 8-bit #?
            BNE    DivLoop
            LDA    Z88             ;Yes
            STA    Z8A+1
            LDA    Z88+1
            STA    Z88
;
            LDY    #8              ;8 by 8 div
DivLoop     CLC
            ROR    Z88+1
            BNE    Div5
            ROR    Z88
            BNE    Div6
;
            ROR    Z8A+1
            ROR    Z8A
            LDA    Z86
            SEC
            SBC    Z8A             ;Divisor
            TAX
            LDA    Z86+1
            SBC    Z8A+1
            BCC    Div7            ;Too small
;
            STA    Z86+1           ;Save partial result
            STX    Z86
            SEC                    ;Shift a "1" bit
            ROL    Z8C             ; into the quotient
            ROL    Z8C+1
            DEY
            BNE    DivLoop
            BEQ    DivDone         ;Always
;
Div5        ROR    Z88
Div6        ROR    Z8A+1
            ROR    Z8A
Div7        CLC                    ;Shift a "0" bit
            ROL    Z8C             ; into the quotient
            ROL    Z8C+1
            DEY
            BNE    DivLoop
;
DivDone     LDX    ExprStkP
            LDA    Z84
            BNE    NegRslt1        ;-ve result
;
            LDA    Z8C             ;Return quotient
            STA    ExprStack-2,X
            LDA    Z8C+1
            STA    ExprStack-2+1,X
            JMP    MainLoop
;
NegRslt1    CLC
            LDA    Z8C             ;2's complement
            EOR    #$FF
            ADC    #$01
            STA    ExprStack-2,X
            LDA    Z8C+1
            EOR    #$FF
            ADC    #$00
            STA    ExprStack-2+1,X
            JMP    MainLoop
            REP    50
; Reserved for instruction as needed by compiler
;
InstrErr    LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
BIT         LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
;
NOP         JMP    MainLoop
            REP    50
; MOVe Frame
;
MOVF        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; MOVe block
;
MOV         LDA    ExprStack-2,X   ;Do a 2's complement
            CLC
            EOR    #$FF
            ADC    #$01
            STA    Z88
            LDA    ExprStack-2+1,X
            EOR    #$FF
            ADC    #$00
            STA    Z88+1           ;k := -pop() -> len
            DEX
            DEX
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;j := pop() -> src
            DEX
            DEX
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z86
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z86+1           ;i := pop() -> dest
            DEX
            DEX
;
            LDY    #0
            LDA    Z88             ;Is block len 0?
            BNE    MovLoop1
            LDA    Z88+1
            BNE    MovLoop1        ;No
            JMP    MainLoop
;
MovLoop1    LDA    (Z84),Y
            STA    (Z86),Y
            INY
            LDA    (Z84),Y
            STA    (Z86),Y
            INY
            BNE    Move1
            INC    Z84+1
            INC    Z86+1
Move1       INC    Z88
            BNE    MovLoop1
            INC    Z88+1
            BNE    MovLoop1
            JMP    MainLoop
            REP    50
; CoMPare blocks
;
CMP         LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Display DoT
;
DDT         LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; REPLicate pattern
;
REPL        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Bit BLock Transfer
;
BBLT        LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; Display CHaracter
;
DCH         LDA    #instrChk       ;Not implemented
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; UNPacK - extract bits i..j from k,
; then right adjust.
; bit 15 is the leftmost bit of the word
; & bit 0 is the rightmost bit
;
UNPK        DEX
            DEX
            DEX
            DEX
            LDY    ExprStack-2,X   ;i
UnpkLoop    BEQ    Unpk1           ;Got the i-th bit
            ASL    ExprStack+2,X   ;k
            ROL    ExprStack+2+1,X
            LDA    ExprStack,X     ;j
            SEC
            SBC    #1
            STA    ExprStack,X
            DEY
            JMP    UnpkLoop
;
Unpk1       LDY    ExprStack,X
AdjLoop     LSR    ExprStack+2+1,X
            ROR    ExprStack+2,X
            INY
            CPY    #15
            BNE    AdjLoop
;
            LDA    ExprStack+2+1,X
            STA    ExprStack-2+1,X
            LDA    ExprStack+2,X
            STA    ExprStack-2,X
            JMP    MainLoop
            REP    50
; PACK the rightmost j-i+1 bits of k into
; positions i..j of word stk[adr]
;
PACK        TXA                    ;expr stk ptr
            SEC
            SBC    #8
            TAX
            LDA    ExprStack+4,X   ;j
            SEC
            SBC    ExprStack+2,X   ;i
            TAY                    ;j-i+1 (0-based)
;
            LDA    PackTbl,Y
            STA    Z88+1
            EOR    #$FF
            AND    ExprStack+6+1,X ;k
            STA    Z86+1
            LDA    PackTbl+16,Y
            STA    Z88
            EOR    #$FF
            AND    ExprStack+6,X
            STA    Z86
;
            LDA    ExprStack+4,X   ;j
            TAY
PackLoop    CPY    #15
            BEQ    Pack1           ;Done
            LDA    Z86             ;k
            ROL    A
            ROL    Z86+1
            ROL    Z86
            LDA    Z88
            ROL    A
            ROL    Z88+1
            ROL    Z88
            INY
            BNE    PackLoop
;
Pack1       LDA    ExprStack,X
            ASL    A               ;Calc addr
            STA    Z84
            LDA    ExprStack+1,X
            ROL    A               ; (which is in words)
            STA    Z84+1           ;adr
;
            LDY    #0
            LDA    (Z84),Y
            AND    Z88+1
            ORA    Z86+1
            STA    (Z84),Y
            INY
            LDA    (Z84),Y
            AND    Z88
            ORA    Z86
            STA    (Z84),Y         ;stk[adr] := 
            JMP    MainLoop
;
PackTbl     EQU    *
            DFB    $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
            DFB    $FE,$FC,$F8,$F0,$E0,$C0,$80,$00;Only these 2
            DFB    $FE,$FC,$F8,$F0,$E0,$C0,$80,$00; rows are used
            DFB    $00,$00,$00,$00,$00,$00,$00,$00
            REP    50
; Get Base adr n levels down
;
GB          LDA    LReg
            STA    Z84
            LDA    LReg+1
            STA    Z84+1           ;i := L
;
            LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z86             ;j := next() - # of levels
            STX    ExprStkP
;
; REPEAT
;
RptLoop     LDY    #0
            LDA    (Z84),Y
            TAX
            INY
            LDA    (Z84),Y
            STA    Z84+1           ;i := stk[i]
            STX    Z84
            DEC    Z86             ;DEC(j)
            BNE    RptLoop
;
; UNTIL j=0
;
            LDX    ExprStkP
            LDA    Z84+1           ;Ptr to local space
            LSR    A
            STA    ExprStack+1,X
            LDA    Z84
            ROR    A
            STA    ExprStack,X     ;push(i)
            INX
            INX
            JMP    MainLoop
            REP    50
; Get Base adr 1 level down
;
GB1         LDY    #1
            LDA    (LReg),Y        ;stk[L]
            LSR    A
            STA    ExprStack+1,X   ;push(stk[L])
            DEY
            LDA    (LReg),Y
            ROR    A
            STA    ExprStack,X
            INX
            INX
            JMP    MainLoop
            REP    50
; ALlOCate block
; # of words on program stack
;
ALOC        LSR    SReg+1
            ROR    SReg
            CLC
            LDA    ExprStack-2,X   ;i
            ADC    SReg
            STA    Z84
            LDA    ExprStack-2+1,X
            ADC    SReg+1
            STA    Z84+1           ;new S in words
;
            LDA    SReg            ;old S (in words)
            STA    ExprStack-2,X   ;BO allocated space
            LDA    SReg+1
            STA    ExprStack-2+1,X ;push(S)
;
            LDA    Z84
            ASL    A
            STA    SReg            ;new S
            LDA    Z84+1
            ROL    A
            STA    SReg+1          ;S := S + i;
;
            SEC
            LDA    HReg            ;Is H < S?
            SBC    SReg
            LDA    HReg+1
            SBC    SReg+1
            BCC    Aloc1           ;Yes
            JMP    MainLoop
; restore old S
Aloc1       DEX
            LDA    ExprStack,X
            ASL    A
            STA    SReg+1
            DEX
            LDA    ExprStack,X
            ROL    A
            STA    SReg            ;S := pop()
            LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; ENTeR procedure
;
ENTR        LDY    #0
            LDA    (PC),Y          ;# of words to allocate
            INC    PC
            BNE    *+4
            INC    PC+1            ; on program stack
            STA    Z84
            ASL    A               ;# of bytes
            PHP                    ;save
            CLC
            ADC    SReg
            STA    SReg
            BCC    Entr1
            INC    SReg+1          ;S := S + next()
;
Entr1       PLP
            BCC    Entr2           ;<128
            INC    SReg+1          ;128 =< but 256
;
Entr2       SEC                    ;Is H < S?
            LDA    HReg
            SBC    SReg
            LDA    HReg+1
            SBC    SReg+1
            BCC    Entr3           ;Yes -> Not enuf mem
            JMP    MainLoop
;
; Re-adjust the program stack space
;
Entr3       SEC
            LDA    SReg
            SBC    Z84             ;# of words
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1
            SEC
            LDA    SReg
            SBC    Z84
            STA    SReg
            LDA    SReg+1
            SBC    #0
            STA    SReg+1          ;S := S-i
;
            LDA    #storageChk
            JSR    TrapProc
            JMP    MainLoop
            REP    50
; ReTurN from procedure
;
RTN         LDA    LReg            ;ptr to 4-word node
            STA    SReg            ; created on program stack when
            LDA    LReg+1          ; a call procedure was setup
            STA    SReg+1          ;S := L
;
            LDY    #2
            LDA    (SReg),Y        ;Get link to the
            STA    LReg            ; previous 4-word node
            INY
            LDA    (SReg),Y
            STA    LReg+1          ;L := stk[S+1]
;
            LDY    #5
            LDA    (SReg),Y
            BPL    RtnDone         ;-> local
            AND    #$7F            ;external
            STA    PC+1
            DEY
            LDA    (SReg),Y
            STA    PC              ;PC := stk[S+2] - $8000
;
; data frame
;
            LDY    #0
            LDA    (SReg),Y
            STA    GReg
            INY
            LDA    (SReg),Y
            STA    GReg+1          ;G := stk[S]
;
; code frame
;
            LDA    (GReg),Y
            ASL    A
            STA    FReg
            DEY
            LDA    (GReg),Y
            ROL    A
            STA    FReg+1          ;F := stk[G]
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1
            JMP    MainLoop
;
; local
;
RtnDone     STA    PC+1
            DEY
            LDA    (SReg),Y
            STA    PC              ;PC := stk[S+2]
            JMP    MainLoop
            REP    50
; NB. All call procedures CX, CF, CI & CLx 
; require an overhead of 4 words of program
; stack space (in the form of a node).
;
; Call eXternal procedure
; The 4 words saved in the node are:
; Word0 = G, Word1 = L, Word2 = PC, Word3 = reserved for msk
;
CX          LDY    #0
            LDA    (PC),Y          ;get the module #
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z86+1           ;j := next();
;
            LDY    #0
            LDA    (PC),Y          ;procedure #
            INC    PC
            BNE    *+4
            INC    PC+1
            STA    Z86             ;i := next();
            JMP    CommonCFX
            REP    50
; Call procedure at Intermediate level
; The 4 words saved in the node are:
; Word0 = (ExprStack), Word1 = L, Word2 = PC, Word3 = reserved for msk
;
CI          LDY    #0
            LDA    ExprStack-2,X
            ASL    A
            STA    (SReg),Y        ;Overwrite G-reg?
            INY
            LDA    ExprStack-2+1,X
            ROL    A
            STA    (SReg),Y        ;stk[S] := pop()
            DEX
            DEX
            JMP    CommonCLI
            REP    50
; Call Formal procedure
; Use when a procedure is pass as formal parameter
; The 4 words saved in the node are:
; Word0 = G, Word1 = L, Word2 = PC, Word3 = reserved for msk
;
CF          DEC    SReg+1
            LDY    #256-2
            LDA    (SReg),Y
            STA    Z86+1           ;j := i DIV 256 (module #)
            INY
            LDA    (SReg),Y
            STA    Z86             ;i := stk[S-1]; (procedure #)
            INC    SReg+1
;
; Common code for CX & CF
;
CommonCFX   LDY    #0
            LDA    GReg
            STA    (SReg),Y
            INY
            LDA    GReg+1
            STA    (SReg),Y
            SEC                    ;external=TRUE
            JSR    Mark            ;Mark(G, TRUE);
;
            LDA    Z86+1           ;module #
            ASL    A
            CLC
            ADC    #>DFTab
            STA    Z84             ;=j+dft
            LDA    #0
            ADC    #<DFTab
            STA    Z84+1           ;ptr to module's data frame
;
; module's data frame
;
            LDY    #1
            LDA    (Z84),Y
            ASL    A
            STA    GReg
            DEY
            LDA    (Z84),Y
            ROL    A
            STA    GReg+1          ;G := stk[dft+j]
;
; module's code frame
;
            LDY    #1
            LDA    (GReg),Y
            ASL    A
            STA    FReg            ;F := stk[G];
            DEY
            LDA    (GReg),Y
            ROL    A
            STA    FReg+1
;
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1
            ASL    FReg
            ROL    FReg+1          ;ptr to code frame
;
            LDA    FReg
            STA    Z84
            LDA    FReg+1
            STA    Z84+1
            LDA    Z86             ;procedure #
            ASL    A
            TAY
            BCC    Common1
            INC    Z84+1
;
Common1     INY
            CLC
            LDA    (Z84),Y         ;offset to entry point
            ADC    FReg
            STA    PC
            DEY
            LDA    (Z84),Y
            ADC    FReg+1
            STA    PC+1            ; of procedure
            JMP    MainLoop        ;Go execute it
            REP    50
; Call Local procedure
; The 4 words saved in the node are:
; Word0 = L, Word1 = L, Word2 = PC, Word3 = reserved for msk
;
CL          LDY    #0
            LDA    LReg
            STA    (SReg),Y
            INY
            LDA    LReg+1
            STA    (SReg),Y
;
; Common code for CL & CI
;
CommonCLI   LDY    #0
            LDA    (PC),Y
            INC    PC
            BNE    *+4
            INC    PC+1            ;next()
;
            PHA                    ;save i
            CLC                    ;external=FALSE
            JSR    Mark            ;Mark(L,FALSE)
            LDA    FReg
            STA    Z84
            LDA    FReg+1
            STA    Z84+1           ;ptr to code frame
;
            PLA
            ASL    A               ;2*i - offset fr BO code frame
            TAY
            BCC    Common2
            INC    Z84+1
;
Common2     INY
            CLC
            LDA    (Z84),Y         ;Get offset to be added
            ADC    FReg            ; to ptr to code frame
            STA    PC
            DEY
            LDA    (Z84),Y
            ADC    FReg+1
            STA    PC+1            ;execute fr this addr
            JMP    MainLoop
            REP    50
; CL1 - CL15  Call Local procedure
;
CL1         LDA    #1*2
;
; Common code for CL1-CL15
; The 4 words saved in the node are:
; Word0 = L, Word1 = L, Word2 = PC, Word3 = reserved for msk
;
CLZ         PHA
            LDY    #0
            LDA    LReg
            STA    (SReg),Y
            INY
            LDA    LReg+1
            STA    (SReg),Y
            CLC                    ;external=FALSE
            JSR    Mark            ;Mark(L, FALSE)
            PLA
            TAY
            INY
;
            CLC
            LDA    (FReg),Y        ;Get offset
            ADC    FReg
            STA    PC
            DEY
            LDA    (FReg),Y
            ADC    FReg+1
            STA    PC+1
            JMP    MainLoop
;
CL2         LDA    #2*2
            BNE    CLZ
CL3         LDA    #3*2
            BNE    CLZ
CL4         LDA    #4*2
            BNE    CLZ
CL5         LDA    #5*2
            BNE    CLZ
CL6         LDA    #6*2
            BNE    CLZ
CL7         LDA    #7*2
            BNE    CLZ
CL8         LDA    #8*2
            BNE    CLZ
CL9         LDA    #9*2
            BNE    CLZ
CL11        LDA    #10*2
            BNE    CLZ
CL10        LDA    #11*2
            BNE    CLZ
CL12        LDA    #12*2
            BNE    CLZ
CL13        LDA    #13*2
            BNE    CLZ
CL14        LDA    #14*2
            BNE    CLZ
CL15        LDA    #15*2
            BNE    CLZ             ;always
            REP    50
; Input
; C=1 - external
; The LReg will be set to point to this
; newly created 4-word of program stack
;
Mark        LDY    #2              ;save ptr to old
            LDA    LReg
            STA    (SReg),Y        ; local space
            INY
            LDA    LReg+1           ; -> singly linked list
            STA    (SReg),Y        ;stk[S] := L;
;
            INY
            LDA    PC
            STA    (SReg),Y
            INY
            LDA    PC+1            ;stk[S] := PC
            BCC    NotExt          ;Is external?
            ORA    #$80            ;Yes => stk[S] := PC + $8000
;
NotExt      STA    (SReg),Y
            INY
;
            LDA    SReg
            STA    LReg            ;Point @ newly created 4-word
            LDA    SReg+1          ; node on program stack space
            STA    LReg+1          ;L := S
;
            CLC
            LDA    SReg
            ADC    #4*2
            STA    SReg            ;INC(S,4)
            BCC    doRTS2
            INC    SReg+1
doRTS2      RTS
            REP    50
; sys func $87 - gotoxy
; On stack
;   Horizontal tab
;   Vertical tab
;
F.GotoXY    DEX
            DEX
            LDA    ExprStack,X
            STA    Z86             ;htab
            DEX
            DEX
            LDA    ExprStack,X
            STA    Z88             ;vtab
            STX    ExprStkP
;
            LDY    Has80Col
            BEQ    No80Col         ;No, video card
;
            LDA    #30             ;GOTOXY code
            JSR    OutCh80
            LDA    Z86             ;X - horiz tab
            CLC
            ADC    #32             ;space
            JSR    OutCh80
            LDA    Z88             ;Y - vert tab
            CLC
            ADC    #32
            JSR    OutCh80
            JMP    OutRtn
            REP    50
; std 40 col output
;
No80Col     LDA    Z88             ;vtab
            JSR    BASCALC         ;Calc base addr of scrn line
            LDA    Z86             ;htab
            STA    CH
OutRtn      LDX    ExprStkP
            JMP    MainLoop
            REP    50
; Sys func $82 - read directory & print it
;
ListDir     DEX
            DEX
            LDA    ExprStack,X     ;drive #
            STX    ExprStkP
            JMP    ShowDir
            REP    50
; Read and display the directory
; How does ComInt call this rtn? 
;
            JSR    DCBSUP          ;Setup file mgr work area
            LDA    #$FF            ;Store complemented vol #
            STA    DCBVOL
            JSR    RDVTOC          ;Read Vol table of contents (VTOC)
            LDA    #$17            ;Set catalog line count
            STA    TEMP2           ;TEMP2
            JSR    Ck4CR
;
            LDY    #0
MsgLoop1    LDA    DevMsg,Y        ;Display "device: D"
            BEQ    ShowDrv
            JSR    PrtChar
            INY
            BPL    MsgLoop1
;
ShowDrv     LDA    CCBDRV          ;Display drive #
            NOP
            ORA    #'0'+$80
            JSR    PrtChar
            JSR    Ck4CR
            JSR    Ck4CR
            CLC
;
RdDirSect   JSR    RDVDIR          ;Read a rec of vol dir
            BCS    EndDir
            LDX    #0
DirLoop     STX    TEMP1           ;Save directory offset
            LDA    VDFILE,X        ;file dir track
            BEQ    EndDir
            BMI    SkipEnt         ;Deleted file
            LDY    #SPACE+$80
            LDA    VDFILE+2,X      ;file use code
            BPL    ShwLock
;
            LDY    #'*'+$80        ;Display locked status
ShwLock     TYA
            JSR    PrtChar
            LDA    VDFILE+2,X
            AND    #$7F
;
            LDY    #7
            ASL    A
WhchType    ASL    A
            BCS    ShwType
            DEY
            BNE    WhchType
;
ShwType     LDA    FTTAB,Y         ;Get filetype char
            JSR    PrtChar
            LDA    #SPACE+$80
            JSR    PrtChar
            LDA    VDFILE+33,X
            STA    Z44             ;Show # of sectors
            LDA    VDFILE+34,X
            STA    Z44+1
            JSR    ShowDec
            LDA    #SPACE+$80
            JSR    PrtChar
            INX
            INX
            INX
;
            LDY    #30-1
ShwName     LDA    VDFILE,X        ;Display filename
            JSR    PrtChar
            INX
            DEY
            BPL    ShwName
;
            JSR    Ck4CR
SkipEnt     JSR    VDINC           ;Advance to next entry in sector
            BCC    DirLoop         ;More entries to go
            BCS    RdDirSect       ;next track
;
EndDir      JSR    Ck4CR
            JSR    DspFree         ;count & show # of free sectors
            JSR    Ck4CR
            LDX    ExprStkP
            RTS
            REP    50
; Check for a cr key
;
Ck4CR       LDA    #CR+$80
            JSR    PrtChar
            DEC    TEMP2
            BNE    doRTS3
WaitKey0    LDA    KBD             ;Wait for a key press
            BPL    WaitKey0
            LDA    KBSTRB
            LDA    #$15
            STA    TEMP2           ;delay
doRTS3      RTS
            REP    50
; Count # of free sectors
; Ref: Beneath Apple DOS pg 4-3
; Each track has a bitmap of 4 bytes.
; A 5 1/4" diskette has 35 tracks giving
; a total bitmap of 35 x 4 = 140 bytes
; So the entire bit map has 140x8 bits.
; Note: Only 16 bits (2 bytes) of a
; a track bitmap are used to indicate the
; allocation of sectors. A free sector
; is represented by a "1" bit.
;
DspFree     LDY    #0
            STY    Z44             ;# of free sectors
            STY    Z45
CntLoop     LDA    VSECAL,Y        ;Sector allocation area
            LDX    #8              ;Do 8 bits at a time
ChkBit      ASL    A               ;Is the sector free?
            BCC    NxtBit
            INC    Z44             ;Yes, increment cnt
NxtBit      DEX
            BNE    ChkBit
            INY
            CPY    #140
            BNE    CntLoop         ;Next 8 bytes
;
            LDY    #0
MsgLoop2    LDA    FreSectMsg,Y    ;Free Sectors...
            BEQ    MsgDone2
            JSR    PrtChar
            INY
            BNE    MsgLoop2
MsgDone2    JSR    ShowDec         ;convert & print
            RTS
            REP    50
; Convert (45,44) to dec representation
;
ShowDec     LDY    #2
ShowDecZ    LDA    #0
            PHA
CnvLoop     LDA    Z44
            CMP    CVTAB,Y         ;CVTAB - conversion table
            BCC    PrDec
            SBC    CVTAB,Y
            STA    Z44
            LDA    Z45
            SBC    #0
            STA    Z45
            PLA
            ADC    #0
            PHA
            JMP    CnvLoop
;
PrDec       PLA
            ORA    #'0'+$80
            JSR    PrtChar
            DEY
            BPL    ShowDecZ
            RTS
;
FreSectMsg  ASC    'free           sectors: '
            DFB    0
DevMsg      ASC    'device:        D'
            DFB    0
            REP    50
; Sys func $83 - WriteString
; Terminal.WriteString(string: ARRAY OF CHAR);
;
WriteString PHA
            LDA    #$02
            JSR    GetxParms
            PLA
            INC    WrdParm2        ;msg len
            LDA    WrdParm1
            STA    Z84
            LDA    WrdParm1+1
            STA    Z84+1           ;str/msg ptr
;
            LDY    #0
PrtLoop1    LDA    (Z84),Y
            CMP    #0              ;null-terminated
            BEQ    PrtDone
            JSR    PrtChar
            INY
            CPY    WrdParm2
            BCC    PrtLoop1
;
PrtDone     JMP    MainLoop
            REP    50
; Sys func $64-write char to terminal
; Char to be written is on expr stack
;
WrtChar     JSR    DspChar
            JMP    MainLoop
;
Has80Col    DFB    0
            REP    50
InitVideo   LDX    #$C3            ;(X)=$Cn
            LDY    #$30            ;(Y)=$n0
            STA    ClrROM
IMM1        JMP    BasicInt        ;PInit
            REP    50
; Output
; (A) = keystroke with msb off
; (X) = error code
;
KeyIn80     LDX    #$C3
            LDY    #$30
            STA    ClrROM
IMM2        JMP    BasicInt        ;PRead
            REP    50
; Input
; (A) - char to output including ctrl-codes
;
; Output
; (X) - 0 if no errors
;
VidOut80    LDX    #$C3
            LDY    #$30
            STA    ClrROM
IMM3        JMP    BasicInt        ;PWrite
            REP    50
; Input
; (A) = request code
;       0 - read
;       1 - write
;
; Output
; (X) = error code
; C=0 Not ready, C=1 ready
;
VidStat     LDX    #$C3
            LDY    #$30
            STA    ClrROM          ;PStat
IMM4        JMP    BasicInt
;
M2Out       DW     PrtChar         ;MeDOS output rtn
;
; Pop & display char on the terminal
;
DspChar     DEX
            DEX
            LDA    ExprStack,X     ;Get char
;
; Routine to print a char or
; execute if it's a ctrl-char
;
PrtChar     CMP    #30             ;eol
            BNE    PrtChar1
            LDA    #CR
            JSR    PrtCharZ
            RTS
;
PrtChar1    CMP    #DEL
            BNE    PrtChar2
            LDA    #BS             ;Do a BS+blank+BS (rubout)
            JSR    PrtCharZ
            LDA    #SPACE+$80
            JSR    PrtCharZ
            LDA    #BS
PrtChar2    JSR    PrtCharZ
            RTS
            REP    50
; Actual output handler
;
PrtCharZ    STY    YSave
            STX    ExprStkP
            LDY    Has80Col
            BNE    CardOut         ;Yes
;
            JSR    OutCh40
            JMP    PrChrDone
;
CardOut     AND    #$7F
            STA    SavCh
            JSR    OutCh80
            LDA    SavCh
            CMP    #CR
            BNE    PrChrDone
            LDA    #LF
            JSR    OutCh80
PrChrDone   LDY    YSave
            LDX    ExprStkP
            RTS
            REP    50
; Output via 80-col card
; (A) = char
;
OutCh80     PHA
ChkCard     LDA    #$00
            JSR    VidStat         ;Is video card ready for output?
            BCC    ChkCard         ;No, loop until it's ready
            PLA
            JSR    VidOut80
            RTS
            REP    50
; Std 40 col output
;
OutCh40     PHA
            LDY    CH
            LDA    #SPACE+$80
            STA    (BASL),Y
            PLA
            ORA    #$80
            CMP    #$E0            ;'a'-1
            BCC    IsCtrl
            AND    CaseMsk         ;To upper
;
IsCtrl      CMP    #SPACE+$80      ;Ctrl chars?
            BCC    COut40Z         ;Yes
            AND    INVFLG
;
COut40Z     STY    YSAV1
            PHA
            JSR    KeyChk
            PLA
            LDY    YSAV1
            RTS
            REP    50
; Delay rtn - Lifted from Apple's Monitor
;
Wait        SEC
Wait2       PHA
Wait3       SBC    #$01
            BNE    Wait3
            PLA
            SBC    #$01
            BNE    Wait2
            RTS
;
; Lifted from Apple's Monitor
;
doBell      LDA    #$40            ;Delay 0.01 secs
            JSR    Wait
            LDY    #$C0
Bell2       LDA    #$0C            ;Toggle speaker at
            JSR    Wait            ; 1 KHz for 0.1 sec
            LDA    SPKR
            DEY
            BNE    Bell2
            RTS
;
; Lifted from Apple's Monitor
;
BASCALC     PHA
            LSR    A
            AND    #$03
            ORA    #$04
            STA    BASL+1
            PLA
            AND    #$18
            BCC    BSCLC2
            ADC    #$7F
BSCLC2      STA    BASL
            ASL    A
            ASL    A
            ORA    BASL
            STA    BASL
            RTS
;
; Check char being output
;
KeyChk      CMP    #CR+$80         ;Output a CR?
            BNE    VidOut40        ;No
            LDY    KBD             ;Is there a key press?
            BPL    VidOut40        ;No
            CPY    #CTRLS+$80      ;Stop list?
            BNE    VidOut40        ;No
            BIT    KBSTRB
; Do a pause
WaitKey1    LDY    KBD             ;Key down?
            BPL    WaitKey1
            CPY    #CTRLC+$80
            BEQ    VidOut40
            BIT    KBSTRB          ;Clear key strobe
;
VidOut40    CMP    #SPACE+$80      ;ctrl-chars?
            BCC    VidOut2         ;Yes
;
; Lifted from Apple's Monitor
;
StoAdv      LDY    CH
            STA    (BASL),Y
            INC    CH
            LDA    CH              ;Are we at right edge?
            CMP    WNDWDTH
            BCS    OutCR           ;Yes
            RTS
;
VidOut2     TAY                    ;Inverse video
            BPL    StoAdv          ;Yes, output it
            CMP    #CR+$80
            BEQ    OutCR
            CMP    #LF+$80
            BEQ    OutLF
            CMP    #BELL+$80
            BEQ    doBell
            CMP    #FF+$80         ;ctrl-L
            BEQ    ClrScrn
            CMP    #BS+$80
            BNE    doRTS4
            DEC    CH
            BPL    doRTS4
;
; At left edge, move cursor to prev line
;
            LDA    WNDWDTH
            STA    CH              ;Now at right edge
            DEC    CH
            LDA    WNDTOP          ;Are we at top of scrn?
            CMP    CV
            BCS    doRTS4          ;No
            DEC    CV
VTab        LDA    CV
VTabZ       JSR    BASCALC
            ADC    WNDLFT
            STA    BASL
doRTS4      RTS
; Not referenced?
ClrEOP      LDY    CH
            LDA    CV
ClrEOP1     PHA
            JSR    VTabZ
            JSR    ClrEOLZ
            LDY    #0
            PLA
            ADC    #0
            CMP    WNDBTM
            BCC    ClrEOP1
            BCS    VTab            ;always
;
ClrScrn     LDA    WNDTOP
            STA    CV
            LDY    #0
            STY    CH
            BEQ    ClrEOP1         ;always
;
; Lifted from Apple's Monitor
;
OutCR       LDA    #0
            STA    CH
OutLF       INC    CV
            LDA    CV
            CMP    WNDBTM
            BCC    VTabZ
            DEC    CV
            LDA    WNDTOP
            PHA
            JSR    VTabZ
Scroll1     LDA    BASL
            STA    BAS2L
            LDA    BASL+1
            STA    BAS2L+1
            LDY    WNDWDTH
            DEY
            PLA
            ADC    #1
            CMP    WNDBTM
            BCS    Scroll3
            PHA
            JSR    VTabZ
Scroll2     LDA    (BASL),Y
            STA    (BAS2L),Y
            DEY
            BPL    Scroll2
            BMI    Scroll1         ;always
;
Scroll3     LDY    #0
            JSR    ClrEOLZ
            BCS    VTab
; clear to eol
            LDY    CH
ClrEOLZ     LDA    #SPACE+$80
ClEOL2      STA    (BASL),Y
            INY
            CPY    WNDWDTH
            BCC    ClEOL2
            RTS
;
SavCh       DFB    0
CaseMsk     DFB    0
            REP    50
; Sys func $65-Read(VAR ch: CHAR);
; Addr of char is on the expr stack
;
ReadKey     STX    ExprStkP
            INC    RNDH
            BNE    ReadKey1
            INC    RNDL
ReadKey1    LDA    Has80Col
            BEQ    KeyIn40         ;No
;
            LDX    #$C3
            LDY    #$30
            LDA    #$01
            JSR    VidStat         ;Is video card ready for input?
            BCC    NoKeyDwn        ;No
;
            LDX    #$C3
            LDY    #$30
            JSR    KeyIn80
            JMP    ChkKeyDwn
;
KeyIn40     LDY    CH
            LDA    #SPACE          
            STA    (BASL),Y
            BIT    KBD             ;Do we have a key pending?
            BPL    NoKeyDwn        ;No
            BIT    KBSTRB          ;Clear strobe
            LDA    KBD
            BNE    ChkKeyDwn
;
NoKeyDwn    LDA    #0              ;No key press, ret 0
            BEQ    RtnChar         ;always
;
ChkKeyDwn   CMP    #CR
            BNE    IsBS
            LDA    #$1E            ;Replace it w/eol
            BNE    RtnChar         ;always
;
IsBS        CMP    #BS             ;If backspc,
            BNE    RtnChar
            LDA    #DEL            ; ret DEL char
RtnChar     LDX    ExprStkP
            STA    Z86             ;char to be returned
            LDA    ExprStack-2,X   ;Get addr of variable (in words)
            ASL    A
            STA    Z84
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z84+1           ;Ptr to variable
            DEX
            DEX
;
            LDY    #0
            LDA    #0
            STA    (Z84),Y
            INY
            LDA    Z86             ;char keyed in
            STA    (Z84),Y
            JMP    MainLoop
            REP    50
; Sys func $79
; Use to load ABS files
; WrdParm1 = addr of var f
;   where f has the data structure
;   stated above
; WrdParm2 = addr of var containing offset
; WrdParm3 = addr of var containing #
;   of words to read
; WrdParm4 = addr of base
;
LoadABS     LDA    CCBPtr          ;ptr to CCB
            STA    Z84
            LDA    CCBPtr+1
            STA    Z84+1
;
            PHA
            LDA    #$04
            JSR    GetxParms
            PLA
;
            LDA    WrdParm3        ;Addr of var in words
            ASL    A
            STA    Z8A
            LDA    WrdParm3+1
            ROL    A
            STA    Z8A+1
;
            LDY    #0
            LDA    (Z8A),Y
            STA    WrdParm3+1
            INY
            LDA    (Z8A),Y
            STA    WrdParm3        ;# of words to read
;
            LDA    WrdParm2        ;Addr of offset (in words)
            ASL    A
            STA    Z88
            LDA    WrdParm2+1
            ROL    A
            STA    Z88+1
;
            LDY    #1
            CLC
            LDA    WrdParm4        ;base
            ADC    (Z88),Y         ;add offset
            STA    WrdParm2        ;addr of block buf
            DEY
            LDA    WrdParm4+1
            ADC    (Z88),Y
            STA    WrdParm2+1
;
            LDY    #1
            CLC
            LDA    (Z88),Y
            ADC    WrdParm3        ;# of words to read
            STA    (Z88),Y
            DEY
            LDA    (Z88),Y
            ADC    WrdParm3+1
            STA    (Z88),Y
;
            LDY    #0
            LDA    #0
            STA    (Z8A),Y
            INY
            STA    (Z8A),Y
            ASL    WrdParm3        ;# of bytes to read
            ROL    WrdParm3+1
            JSR    FRead           ;read
            BCC    GudRead
            JMP    HndlErr
GudRead     JMP    GoodExit
;
CCBPtr      DW     0               ;Ptr to DOS' Cmd Ctl block (CCB)
            REP    50
; Sys func $85
;
StoreByt    LDA    ExprStack-4,X
            STA    Z84             ;addr
            LDA    ExprStack-4+1,X
            STA    Z84+1
;
            LDY    #0
            LDA    ExprStack-2,X
            STA    (Z84),Y
            DEX
            DEX
            DEX
            DEX
            RTS
            REP    50
; Sys func $84
; Move byte from src location
; to word in dest location
;
StoreWrd    LDA    ExprStack-4,X
            STA    Z84             ;src mem addr
            LDA    ExprStack-4+1,X
            STA    Z84+1
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z86             ;dest mem addr (in words)
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z86+1
;
            LDY    #0
            LDA    (Z84),Y
            INY                    ;Y=1
            STA    (Z86),Y         ;lobyte of dest
            DEY                    ;Y=0
            LDA    #0
            STA    (Z86),Y         ;hi-byte of dest is 0
            DEX
            DEX
            DEX
            DEX
            RTS
            REP    50
; Sys func $86 - Call 6502 subrtn
; Machine Language Interface
; On expression stack:
;   Addr of subrtn
;   Addr containing value to set & for returning A-reg
;   Addr containing value to set & for returning X-reg
;   Addr containing value to set & for returning Y-reg
;
GoMLI       LDA    ExprStack-8,X   ;Ptr to subrtn to be called
            STA    IMM5+1          ; Self-modifying code
            LDA    ExprStack-8+1,X
            STA    IMM5+2
;
            LDA    ExprStack-6,X
            ASL    A
            STA    Z86             ;Mem location (in words)
            LDA    ExprStack-6+1,X
            ROL    A
            STA    Z86+1           ;Ptr to Acc
;
            LDA    ExprStack-4,X
            ASL    A
            STA    Z88
            LDA    ExprStack-4+1,X
            ROL    A
            STA    Z88+1           ;Ptr to X
;
            LDA    ExprStack-2,X
            ASL    A
            STA    Z8A
            LDA    ExprStack-2+1,X
            ROL    A
            STA    Z8A+1           ;Ptr to Y
            STX    ExprStkP
;
            LDY    #1              ;Set 6502 A,X,Y regs
            LDA    (Z8A),Y
            STA    YSave
            LDA    (Z88),Y
            TAX
            LDA    (Z86),Y
            LDY    YSave
IMM5        JSR    $0000           ; before calling...
;
            STY    YSave
            LDY    #1              ;Return A,X,Y regs
            STA    (Z86),Y
            TXA
            STA    (Z88),Y
            LDA    YSave
            STA    (Z8A),Y
;
            LDY    #0
            LDA    #0              ;Return 0 as hi-byte
            STA    (Z86),Y
            STA    (Z88),Y
            STA    (Z8A),Y
;
            LDA    ExprStkP
            SEC
            SBC    #8
            TAX
            RTS
;
YSave       DFB    $00
WrdParm1    DW     $00             ;ptr/addr
WrdParm2    DW     $00
WrdParm3    DW     $00
WrdParm4    DW     $00
            REP    50
; Transfer control to handlers of sys func
; $66-$78 which involve DOS3.3 calls.
; NB. Ptr to Cmd Control Block must be
; obtained prior to these calls.
;
GoDOSCall   LDA    CCBPtr
            STA    Z84
            LDA    CCBPtr+1
            STA    Z84+1
;
            LDA    #1
            STA    DrvNbr
            DEX
            LDA    ExprStack,X     ;A zero, discarded
            DEX
            LDA    ExprStack,X
            ASL    A               ;Index into JMP table
            TAY
            LDA    FSCallTbl,Y
            STA    Z86
            LDA    FSCallTbl+1,Y
            STA    Z86+1
            JMP    (Z86)
            REP    50
; Get word parameters from the expr stack
; (A) = 1-4
;
GetxParms   CMP    #$04
            BEQ    Get4Parms
            CMP    #$03
            BEQ    Get3Parms
            CMP    #$02
            BEQ    Get2Parms
            BNE    Get1Parms
;
Get4Parms   DEX
            LDA    ExprStack,X
            STA    WrdParm4+1
            DEX
            LDA    ExprStack,X
            STA    WrdParm4
;
Get3Parms   DEX
            LDA    ExprStack,X
            STA    WrdParm3+1
            DEX
            LDA    ExprStack,X
            STA    WrdParm3
;
Get2Parms   DEX
            LDA    ExprStack,X
            STA    WrdParm2+1
            DEX
            LDA    ExprStack,X
            STA    WrdParm2
;
Get1Parms   DEX
            LDA    ExprStack,X
            STA    WrdParm1+1
            DEX
            LDA    ExprStack,X
            STA    WrdParm1
            ASL    WrdParm1        ;addr/ptr
            ROL    WrdParm1+1
            STX    ExprStkP
            RTS
            REP    50
; Set ptr to name field within
; File data structure
; Input
;  (Z84)      = Ptr to Cmd Control Blk
;  (WrdParm1) = Ptr to var of type File
;
SetFNPtr    CLC
            LDA    WrdParm1        ;f:File
            ADC    #>f.name
            STA    Z86
            LDA    WrdParm1+1
            ADC    #<f.name
            STA    Z86+1
;
            LDY    #oCCBFN1
            LDA    Z86
            STA    (Z84),Y
            INY
            LDA    Z86+1
            STA    (Z84),Y
            RTS
            REP    50
; Copy filename to f.name
; Input
;  (WrdParm1) = Ptr to var of type File
;
CopyFN      CLC
            LDA    WrdParm1        ;f:File
            ADC    #>f.name
            STA    Z86
            LDA    WrdParm1+1
            ADC    #<f.name
            STA    Z86+1
;
            LDY    #31-1
CpyLoop2    LDA    FNBuf,Y
            STA    (Z86),Y
            DEY
            BPL    CpyLoop2
            RTS
            REP    50
; Check if filename is preceded by
; a drive # prefix of the form "Dn."
; Output
;  C = 1 - Yes
;
GetDrvNum   LDY    #2              ;Look for the prefix "Dn."
            LDA    (Z88),Y         ; b4 a filename
            CMP    #'.'
            BNE    NoDrvPfx
GetDrvNumZ  LDY    #0              ;If entry is here
            LDA    (Z88),Y         ; the prefix check for
            AND    #$DF            ; is "Dn"
            CMP    #'D'
            BNE    NoDrvPfx
            INY
            LDA    (Z88),Y
            CMP    #'1'            ; where n=drive #
            BNE    IsDrv2
            LDA    #1
            BNE    SetDrv          ;always
;
IsDrv2      CMP    #'2'
            BNE    NoDrvPfx
            LDA    #2
;
SetDrv      STA    DrvNbr          ;Flag filename is
            SEC                    ; prefixed with .D1/2
            RTS
NoDrvPfx    CLC
            RTS
            REP    50
; Get ptr to pathname (may be preceded
; by a drive prefix)
; Input
;  (WrdParm2) = addr of pathname
;  (WrdParm3) = len of pathname
; Output
;  (Z88)      = ptr to pathname
;
GetPNPtr    LDA    WrdParm2
            ASL    A               ;addr (in words)
            STA    Z88             ;ptr to pathname
            LDA    WrdParm2+1
            ROL    A
            STA    Z88+1
            INC    WrdParm3        ;len of pathname
            RTS
            REP    50
GetFName    JSR    GetPNPtr        ;Get ptr to filename
;
; Input
;  (Z88)       = Ptr to filename
;  (WordParm3) = len of filename
;
MovFN2Buf   JSR    GetDrvNum       ;Get drive #
            LDY    #0
            BCC    MovIt           ;Drive # is not specified
            LDY    #3              ;Skip past drive prefix
;
MovIt       LDX    #0
MovLoop2    CPY    WrdParm3        ;len of filename
            BEQ    AddSpcs
            CPX    #30             ;max len
            BEQ    doRTS5
            LDA    (Z88),Y
            BEQ    AddSpcs
            ORA    #$80
            CMP    #$E0            ;'a'-1
            BCC    MovIt1
            AND    #$DF            ;to upper
MovIt1      STA    FNBuf,X
            INY
            INX
            BNE    MovLoop2
;
; Pad filename w/trailing spaces
;
AddSpcs     LDA    #SPACE+$80
PadLoop     CPX    #30
            BCS    doRTS5
            STA    FNBuf,X
            INX
            BNE    PadLoop
doRTS5      RTS
            REP    50
; Search for empty slot in file ref table.
; Does not return to caller if none available.
;
GetFRN      LDY    #0
SrchLoop    LDA    FileRefT,Y
            BEQ    Got1FRN         ;Got one
            INY
            CPY    #8
            BNE    SrchLoop
;
            PLA                    ;Dump ret addr
            PLA
            LDA    #true
            STA    FlagErr
            LDA    #$07            ;toomanyfiles
            STA    ErrCode
            JMP    ErrExit
;
Got1FRN     STY    FRTIndx         ;Index into file ref table
            TYA
            LDX    WrdParm1        ;f:File
            STX    Z86
            LDX    WrdParm1+1
            STX    Z86+1
            LDY    #f.id+1
            STA    (Z86),Y         ;Save file ref #
            DEY
            LDA    #0
            STA    (Z86),Y
            RTS
            REP    50
; Call DOS File Mgr
; Set ptrs to 3 buffers within File data structure
; The dir buf ptr points @ f.data field
; the sector buf ptr points @ f.ts field
; the fcb ptr points @ f.wrk field
; Input
;  (Z84)      = ptr to Cmd Control Blk
;  (WrdParm1) = ptr to File structure
;
CallDOSFM   LDY    #oCCBDBP        ;DIR BUF PTR
            CLC
            LDA    WrdParm1        ;f:File
            ADC    #>f.data
            STA    Z86             ;Point @ f.data
            STA    (Z84),Y
            INY
            LDA    WrdParm1+1
            ADC    #<f.data
            STA    Z86+1
            STA    (Z84),Y
            INC    Z86+1           ;next mem page
;
            LDY    #oCCBSBP        ;SECTOR BUF PTR
            LDA    Z86
            STA    (Z84),Y
            INY
            LDA    Z86+1
            STA    (Z84),Y         ;addr of f.ts
            INC    Z86+1           ;next mem page
;
; NB-FCB len is 45 bytes
;
            LDY    #oCCBFCB        ;FCB PTR
            LDA    Z86
            STA    (Z84),Y
            INY
            LDA    Z86+1
            STA    (Z84),Y         ;addr of f.wrk
            JSR    CallFM          ;Call DOS File Manager
            RTS
            REP    50
; Report DOS errs
;
HndlErr     LDA    #true
            STA    FlagErr
            LDY    #oCCBSTA        ;Get RESULT STATUS
            LDA    (Z84),Y         ; return by DOS
            TAY                    ;(A)=1-10
            LDA    ErrCodeT,Y
            STA    ErrCode
            CMP    #8              ;eom
            BNE    ErrExit
;
; (Y)=9 -> CRENSA - NO SECTORS AVAILABLE
;
            LDA    #0
            LDY    #8-1
ZeroLoop    STA    FileRefT,Y
            DEY
            BPL    ZeroLoop
;
            LDA    #CR
            JSR    PrtChar
            LDY    #0
MsgLoop3    LDA    DskFullMsg,Y    ;Disk full...
            BEQ    HndlErr1
            JSR    PrtChar
            INY
            BNE    MsgLoop3
;
HndlErr1    LDA    #CR
            JSR    PrtChar
            JSR    ErrExit
            PLA                    ;Dump ret addr
            PLA
            LDA    #stopped
            JSR    TrapProc
            JMP    MainLoop
;
DskFullMsg  ASC    '               ---- disk full'
            DFB    0
            REP    50
; Error Code Translation Table
; FileSystem err codes returned by Interpreter
; Ref. FileSystem.DEF for declaration of Response
; type
;
ErrCodeT    DFB    $00,$06,$03,$03,$0E,$00,$01,$04
            DFB    $10,$08,$0B
;
; DOS call was successfully executed
;
GoodExit    LDA    #$00
            STA    FlagErr
            STA    ErrCode
            JMP    ErrExit
            REP    50
; Common Exit
; Input
; (WrdParm1)=ptr to File struct
;
ErrExit     LDA    WrdParm1        ;f:File
            STA    Z86
            LDA    WrdParm1+1
            STA    Z86+1
;
            LDY    #f.eof
            LDA    #0
            STA    (Z86),Y
            INY
            LDA    FlagErr
            STA    (Z86),Y
;
            LDY    #f.res
            LDA    #0
            STA    (Z86),Y
            INY
            LDA    ErrCode
            STA    (Z86),Y
            LDX    ExprStkP
            RTS
;
FlagErr     DFB    0               ;FALSE/TRUE
ErrCode     DFB    0               ;Response
            REP    50
; Set vol #, slot # & drive #
; in file mgr parm list
; Input
;  (Z84) = Ptr to Cmd Ctl Blk
;
SetVSD      LDA    #0              ;vol # = 256
            LDY    #oCCBVOL        ;Open Vol #
            STA    (Z84),Y
            JSR    X03E3           ;Get RWTS I/O block
            STY    Z88             ; addr into (A,Y)
            STA    Z88+1
;
            LDY    #oIBSLOT        ;Get controller's
            LDA    (Z88),Y         ;slot # (Sx16)
            LSR    A
            LSR    A
            LSR    A
            LSR    A               ;1-7 
            LDY    #oCCBSLT
            STA    (Z84),Y
;
            LDA    DrvNbr
            LDY    #oIBPDRV        ;Drive # of last access
            STA    (Z88),Y
            LDY    #oCCBDRV
            STA    (Z84),Y
            RTS
            REP    50
; sys func $66 - create
; WrdParm1 = addr of f
; WrdParm2 = addr of filename
; WrdParm3 = len of filename
;
doCreate    PHA
            LDA    #$03
            JSR    GetxParms
            PLA
            JSR    GetFRN
            LDA    FRTIndx         ;file ref table index (0-7)
            CLC
            ADC    #'0'+$80        ;Use an ASCII dec digit to
            LDY    #8              ; replace ? in tmp filename
            STA    tmpFileNam,Y
            JSR    GetPNPtr        ;Get ptr to filename
            JSR    GetDrvNumZ      ;Get drive #
;
            LDA    tmpFNPtr+1
            STA    Z88+1
            LDA    tmpFNPtr
            STA    Z88
;
            LDA    #13
            STA    WrdParm3        ;len of tmp filename
            LDA    #0
            STA    WrdParm3+1
            JSR    MovFN2Buf       ;Copy tmp filename to buf
            LDA    #>true          ;Flag it's a new file
            STA    WrdParm4
            JMP    OpenFile        ;Go create it
            REP    50
; sys func $68 - Open file
; Input
;  (WrdParm1) = File Data rec (f)
;  (WrdParm2) = filename (fn)
;  (WrdParm3) = len of fn
;  (WrdParm4) = newfile flag
;  (Z84)      = Ptr to Cmd Ctl Blk
;
doOpen      PHA
            LDA    #$04
            JSR    GetxParms
            PLA
            JSR    GetFRN
            JSR    GetFName
;
            LDA    #false          ;Flag it's an existing file
OpenFile    LDX    WrdParm1        ;f:File
            STX    Z86
            LDX    WrdParm1+1
            STX    Z86+1
;
            LDY    #f.tmp+1
            STA    (Z86),Y
            DEY
            LDA    #0
            STA    (Z86),Y
;
            LDY    #oCCBFN1
            LDA    FNPtr
            STA    (Z84),Y         ;Ptr to filename
            INY
            LDA    FNPtr+1
            STA    (Z84),Y         ; of file to be opened
            LDY    #oCCBFUC
            LDA    #0              ;file use code
            STA    (Z84),Y
;
            LDA    WrdParm4        ;newfile
            EOR    #$01
            TAX
            LDY    #oCCBREQ
            LDA    #CRQOPN         ;request=open
            STA    (Z84),Y
            LDA    #$FF            ;Set rec len = $FFFF (max)
            LDY    #oCCBRLN
            STA    (Z84),Y
            INY
            STA    (Z84),Y
;
            JSR    SetVSD
            JSR    CallDOSFM       ;(X)=0/1 (0 -> create if not found)
            BCC    OpnFile2
            JMP    HndlErr
;
OpnFile2    LDY    FRTIndx
            LDA    #$01            ;Mark file ref num
            STA    FileRefT,Y       ; slot as 'in use'
            JSR    CopyFN          ;Copy file name to f.name
;
            LDA    #0
            STA    WrdParm2        ;high
            STA    WrdParm2+1
            STA    WrdParm3        ;low
            STA    WrdParm3+1
            JSR    SetFilePos      ;Set to BO file
            BCC    GoodOpn
            JMP    HndlErr
GoodOpn     JMP    GoodExit
            REP    50
; sys func $67 - Close file
; Input
;  (Z84)      = ptr to Cmd Ctl Blk
;  (WrdParm1) = addr of f
;
doClose     PHA
            LDA    #$01
            JSR    GetxParms
            PLA
            LDY    #oCCBREQ
            LDA    #CRQCLS         ;request=close
            STA    (Z84),Y
            JSR    CallDOSFM
            BCC    Close1
            JMP    HndlErr
;
Close1      LDA    WrdParm1
            STA    Z86
            LDA    WrdParm1+1
            STA    Z86+1           ;addr of f
;
            LDY    #f.id+1
            LDA    (Z86),Y         ;Get file ref #
            TAY
            LDA    #$00            ;Mark slot as empty
            STA    FileRefT,Y
            LDY    #f.tmp
            INY
            LDA    (Z86),Y
            BEQ    ClsDone
            LDA    DCBDRV
            STA    DrvNbr
            JMP    DelFile         ;-> delete file
ClsDone     JMP    GoodExit
            REP    50
; sys func $69-rename
; FileSystem.Rename(VAR f: File; fn: ARRAY OF CHAR);
; WrdParm1 = addr of f
; WrdParm2 = addr of filename
; WrdParm3 = len of filename
;
doRename    PHA
            LDA    #$03
            JSR    GetxParms
            PLA
            JSR    GetFName
            LDA    FNBuf           ;Ensure filename doesn't
            CMP    #SPACE+$80      ; start with a blank
            BNE    Rename1
            LDA    #true           ;flag err
            CLC
            JMP    Rename5
;
Rename1     LDA    hiPosPtr
            STA    Z88
            LDA    hiPosPtr+1
            STA    Z88+1
;
            LDA    lowPosPtr
            STA    Z8A
            LDA    lowPosPtr+1
            STA    Z8A+1
            JSR    GetFilePos
            BCC    Rename2
;
            LDY    #oCCBSTA        ; - Result Status
            LDA    #CREFNF         ;file not found
            STA    (Z84),Y
            JMP    HndlErr
;
Rename2     LDY    #oCCBREQ
            LDA    #CRQCLS         ;request=close
            STA    (Z84),Y
            JSR    CallDOSFM
            BCC    Rename3
            JMP    HndlErr
;
Rename3     LDA    DCBDRV
            STA    DrvNbr
            JSR    SetFNPtr        ;Set FNPtr to f.name
            LDY    #oCCBFN2        ;ptr to filename 2
            LDA    FNPtr
            STA    (Z84),Y
            INY
            LDA    FNPtr+1
            STA    (Z84),Y
;
            LDY    #oCCBREQ
            LDA    #CRQRNM         ;request=rename
            STA    (Z84),Y
            JSR    SetVSD
            JSR    CallDOSFM
            BCC    RenamDone
            JMP    HndlErr
;
RenamDone   JSR    CopyFN
            LDY    #oCCBFN1
            LDA    FNPtr           ;filename1 ptr
            STA    (Z84),Y
            INY
            LDA    FNPtr+1
            STA    (Z84),Y
;
            LDY    #oCCBFUC
            LDA    #0              ;file use code
            STA    (Z84),Y
            LDX    #$01            ;Flag don't create
            LDY    #oCCBREQ
            LDA    #CRQOPN         ;request=open
            STA    (Z84),Y
;
            LDA    #0              ;rec len=0
            LDY    #oCCBRLN
            STA    (Z84),Y
            INY
            STA    (Z84),Y
            JSR    SetVSD
            JSR    CallDOSFM       ;Call File Mgr
            BCS    Rename4
;
            LDA    highPos
            STA    WrdParm2
            LDA    highPos+1
            STA    WrdParm2+1
;
            LDA    lowPos+1
            STA    WrdParm3
            LDA    lowPos
            STA    WrdParm3+1
            JSR    SetFilePos
;
Rename4     LDA    #false
Rename5     LDX    WrdParm1        ;Ptr to f:File
            STX    Z86
            LDX    WrdParm1+1
            STX    Z86+1
;
            LDY    #f.tmp
            INY
            STA    (Z86),Y
            BCC    RenExit
            JMP    HndlErr
RenExit     JMP    GoodExit
            REP    50
; Delete File
; Input
;  (Z84) = Ptr to Cmd Ctl Blk
;
DelFile     JSR    SetFNPtr        ;Set ptr to f.name
            LDY    #oCCBREQ
            LDA    #CRQDEL         ;request=delete
            STA    (Z84),Y
            JSR    SetVSD
            JSR    CallFM          ;Call DOS File Manager
            BCC    DelDone
            JMP    HndlErr
DelDone     JMP    GoodExit
            REP    50
; Set file position
; (Z84)      = ptr to CCB
; (WrdParm2) = high
; (WrdParm3) = low
;
SetFilePos  LDA    WrdParm2        ;high
            ORA    WrdParm2+1
            BEQ    SetFP1
;
            LDY    #oCCBSTA        ;-RESULT STATUS
            LDA    #CREFNF         ;-File not found
            STA    (Z84),Y
            JMP    HndlErr
;
SetFP1      LDY    #oCCBRLN
            LDA    #0              ;reclen=0
            STA    (Z84),Y
            INY
            STA    (Z84),Y
;
            LDY    #4              ;#oCCBBYT - relative byte #
            LDA    WrdParm3        ;low
            STA    (Z84),Y
            INY
            LDA    WrdParm3+1
            STA    (Z84),Y
;
            LDY    #oCCBREQ
            LDA    #CRQPOS         ;request=position
            STA    (Z84),Y
            JSR    CallDOSFM
            RTS
            REP    50
; sys func $6F
; FileSystem.SetPos(VAR f: File; high, low: CARDINAL);
; WrdParm1 = addr of f
; WrdParm2 = high
; WrdParm3 = low
;
SetPos      PHA
            LDA    #$03
            JSR    GetxParms
            PLA
            JSR    SetFilePos      ;Let DOS do it
            BCC    SetPos1
            JMP    HndlErr
SetPos1     JMP    GoodExit
            REP    50
; sys func $70-GetPos
; FileSystem.GetPos(VAR f: File; VAR high, low: CARDINAL);
; WrdParm1 = addr of f
; WrdParm2 = addr of high
; WrdParm3 = addr of low
; high, low are actually the HiWord &
; LoWord of the file position.
; Input
;  (Z84) = Ptr to Cmd Ctl Blk
;  (Z86) = Ptr to Data Ctl Blk
;
GetPos      PHA
            LDA    #$03
            JSR    GetxParms
            PLA
            LDA    WrdParm2
            ASL    A               ;addr of high (in words)
            STA    Z88
            LDA    WrdParm2+1
            ROL    A
            STA    Z88+1
;
            LDA    WrdParm3
            ASL    A               ;addr of low (in words)
            STA    Z8A
            LDA    WrdParm3+1
            ROL    A
            STA    Z8A+1
            JSR    GetFilePos
            BCC    GetPos1
;
            LDY    #oCCBSTA        ;RESULT STATUS
            LDA    #CREFNF         ;File not found
            STA    (Z84),Y
            JMP    HndlErr
GetPos1     JMP    GoodExit
            REP    50
; Get file posn fr DOS work area
; Input
;  (Z86) = Ptr to Data Control Block
;  (Z88) = Ptr to word var high
;  (Z8A) = Ptr to word var low
;
GetFilePos  CLC
            LDA    WrdParm1        ;f:File
            ADC    #>f.wrk
            STA    Z86
            LDA    WrdParm1+1
            ADC    #<f.wrk
            STA    Z86+1           ;Points @ DCB
;
            LDY    #0
            LDA    #$00
            STA    (Z88),Y         ;zero high
            INY
            STA    (Z88),Y
;
            LDY    #oDCBCRR        ;curr relative rec
            LDA    (Z86),Y
            INY
            ORA    (Z86),Y
            BEQ    GetFP1
            SEC
            RTS
;
; Call DOS to return the filepos
;
GetFP1      LDY    #oDCBCRB        ;curr relative byte
            LDA    (Z86),Y
            LDY    #1
            STA    (Z8A),Y         ;Ptr to low
            LDY    #28
            LDA    (Z86),Y
            LDY    #0
            STA    (Z8A),Y
            CLC
            RTS
            REP    50
; Prepare to read 1 block of data
; Input
;  (Z84)      = Ptr to Cmd Ctl Blk
;  (WrdParm3) = # of bytes to be read
;
InitBlkRd   LDY    #oCCBRQM        ;REQUEST MODIFIER BYTE
            LDA    #CRMNBL         ;R/W NEXT BLOCK
            STA    (Z84),Y
            LDY    #oCCBBLN
            LDA    WrdParm3        ;IO block len
            STA    (Z84),Y
            INY
            LDA    WrdParm3+1
            STA    (Z84),Y
            RTS
            REP    50
; Read file
; Input
;  (Z84)      = Ptr to Cmd Ctl Blk
;  (WrdParm2) = addr of block buffer
;  (WrdParm3) = # of bytes to read
; Output
;  (Z88)      = 0 if read err
;
FRead       LDY    #oCCBREQ
            LDA    #CRQRD          ;request=READ DATA
            STA    (Z84),Y
            JSR    InitBlkRd       ;Setup
;
            LDY    #oCCBBBA        ;BLOCK BUFFER PTR
            LDA    WrdParm2        ;Set transfer addr
            ASL    A
            STA    (Z84),Y
            LDA    WrdParm2+1
            ROL    A
            INY
            STA    (Z84),Y
            JSR    CallDOSFM
            BCC    doRTS6
;
; if err, return 0C
;
            LDA    WrdParm2
            ASL    A
            STA    Z88             ;Ptr at block buf
            LDA    WrdParm2+1
            ROL    A
            STA    Z88+1
;
            LDA    #0
            TAY
            STA    (Z88),Y         ;Return $0000
            INY
            STA    (Z88),Y
            SEC
doRTS6      RTS
            REP    50
; sys func $74-ReadChar
; FileSystem.ReadChar(VAR f: File; VAR ch: CHAR);
; WrdParm1 = addr of f
; WrdParm2 = addr of ch
;
ReadChar    LDA    #$FF
            STA    TextMode
ReadCharZ   PHA
            LDA    #$02
            JSR    GetxParms
            PLA
            LDA    #1              ;# of bytes
            STA    WrdParm3
            LDA    #$00
            STA    WrdParm3+1
            JSR    FRead           ;read
            BCC    RdChar1
            JMP    HndlErr
;
RdChar1     LDA    WrdParm2
            ASL    A
            STA    Z88
            LDA    WrdParm2+1
            ROL    A
            STA    Z88+1           ;addr of ch
;
            LDY    #0
            LDA    (Z88),Y
            BIT    TextMode
            BVC    RdChar2
            AND    #$7F
            CMP    #CR
            BNE    RdChar2
;
            LDA    #$1E            ;eol
RdChar2     INY
            STA    (Z88),Y
            DEY
            LDA    #$00
            STA    (Z88),Y
            JMP    GoodExit
            REP    50
; sys func $77-ReadChar (binary mode)
; WrdParm1 = addr of f
; WrdParm2 = addr of ch
;
ReadCharB   LDA    #$00
            STA    TextMode
            JMP    ReadCharZ
            REP    50
; sys func $73
; FileSystem.ReadWord(VAR f: File; VAR w: WORD);
; WrdParm1 = addr of f
; WrdParm2 = addr of w
;
ReadWord    PHA
            LDA    #$02
            JSR    GetxParms
            PLA
            LDA    #2              ;rec len
            STA    WrdParm3
            LDA    #0
            STA    WrdParm3+1
            JSR    FRead
            BCC    RdWord1
            JMP    HndlErr
RdWord1     JMP    GoodExit
            REP    50
; Write out a byte
;
Wr1Byte     PHA                    ;byte to be written
            LDY    #oCCBREQ
            LDA    #CRQWR          ;request=write data
            STA    (Z84),Y
            LDY    #oCCBRQM        ;REQUEST MODIFIER BYTE
            LDA    #CRMNBT         ;R/W next byte
            STA    (Z84),Y
;
            LDY    #oCCBDAT        ;BYTE I/O
            PLA                    ;data byte
            STA    (Z84),Y
            JSR    CallDOSFM       ;Call DOS
            RTS
            REP    50
; sys func $76
; FileSystem.WriteChar(VAR f: File; ch: CHAR);
; WrdParm1 = addr of f
; WrdParm2 = char to be written to file
;
WriteChar   LDA    #%11111111
            STA    TextMode
;
WriteCharZ  PHA
            LDA    #$02
            JSR    GetxParms
            PLA
            LDA    WrdParm2        ;ch
            BIT    TextMode
            BVC    WrtChar1
            CMP    #$1E            ;eol
            BNE    WrtChar1
;
            LDA    #CR
            ORA    #$80
WrtChar1    JSR    Wr1Byte
            BCC    WrtChar2
            JMP    HndlErr
WrtChar2    JMP    GoodExit
            REP    50
; sys func $78 - writechar (binary mode)
; WrdParm1 = addr of f
; WrdParm2 = char to be written to file
;
WriteCharB  LDA    #$00
            STA    TextMode
            JMP    WriteCharZ
            REP    50
; sys func $75 - WriteWord
; FileSystem.WriteWord(VAR f: File; w: WORD);
; WrdParm1 = addr of f
; WrdParm2 = addr of w
;
WriteWord   PHA
            LDA    #$02
            JSR    GetxParms
            PLA
            LDA    WrdParm2+1
            JSR    Wr1Byte
            BCS    WrtErr
            LDA    WrdParm2
            JSR    Wr1Byte
            BCC    WrtWord2
WrtErr      JMP    HndlErr         ;err
WrtWord2    JMP    GoodExit
            REP    50
; sys func $71-file len - Not implemented
;
Length      DEX
            DEX
            DEX
            DEX
;
; sys func $6A-$6E, $72 - Not implemented
;
NotImp      DEX
            DEX
            RTS
;
DrvNbr      DFB    $00
;
FRTIndx     DFB    $00             ;file ref table index
FileRefT    DS     10,0            ;File ref table - only 8 is used
;
hiPosPtr    DW     highPos
lowPosPtr   DW     lowPos
TextMode    DFB    $00             ;0-binary $FF-text
;
highPos     DW     $00             ;Should be 0
lowPos      DW     $00
tmpFNPtr    DW     tmpFileNam
;
tmpFileNam  ASC    'WWXXYYZZ'      ;tmp filename
            ASC    '?.TMP'
;
FNPtr       DW     FNBuf
;
FNBuf       DS     30,0
            REP    50
; Module FileSystem
; 19 jmp addrs for sys func $66-$78-DOS calls
; Before passing control to these calls,
; (Z84) is set to point to a Command
; Control Block (CCB)
;
FSCallTbl   EQU    *
            DW     doCreate        ;create
            DW     doClose         ;close
            DW     doOpen          ;open
            DW     doRename        ;rename
            DW     NotImp          ;Not implemented
            DW     NotImp
            DW     NotImp
            DW     NotImp
            DW     NotImp
            DW     SetPos
            DW     GetPos
            DW     Length          ;Not implemented
            DW     NotImp
            DW     ReadWord
            DW     ReadChar
            DW     WriteWord
            DW     WriteChar
            DW     ReadCharB
            DW     WriteCharB
            DFB    $00
            REP    50
; Return double word of 0
; This could also be interpreted as
; a floating point # whose value is 0
;
RtnZeroFP   LDA    #0
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            RTS
;
OvflFP      LDA    #realOvfl
            JSR    TrapProc
            JMP    RtnZeroFP
;
            LDA    #realOvfl       ;unref?
            JSR    TrapProc
            JMP    RtnZeroFP
;
DivBy0      LDA    #realOvfl
            JSR    TrapProc
            JMP    RtnZeroFP
;
OvflInt     LDA    #intOvfl
            JSR    TrapProc
            LDA    #0
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            RTS
            REP    50
; Shift Floating Point Acc1 right once
;
SHLAcc1     ASL    Acc1+FMant0
            ROL    Acc1+FMant1
            ROL    Acc1+FMant2
            ROL    Acc1+FMant3
            RTS
            REP    50
; Shift Floating Point Acc2 right once
;
SHRAcc1     LSR    Acc1+FMant3
            ROR    Acc1+FMant2
            ROR    Acc1+FMant1
            ROR    Acc1+FMant0
            RTS
            REP    50
; Input
;  (X)=$C5/$CB
;  The locations $C5-$CA/$CB-$D0 is used to
;  store an unpacked floating point #.
;
;  Note: (ExprStkP) is changed
; (X)=new exp stack pointer
;
PopFloat    TXA
            LDX    ExprStkP
            STA    ExprStkP        ;Save temporarily
            DEX
            LDA    ExprStack,X
            STA    FPTemp+1        ;Middle of mantissa
            DEX
            LDA    ExprStack,X
            STA    FPTemp          ;End of mantissa
            DEX
            LDA    ExprStack,X
            STA    FPTemp+3        ;Sign bit + rest of exp
            DEX
            LDA    ExprStack,X
            STA    FPTemp+2        ;1 bit exp + rest of mantissa
            TXA
            LDX    ExprStkP        ;(X)=$C5/$CB
            STA    ExprStkP        ;changed
;
; Unpack float into 6 bytes
; Looks like IEEE754 rep where S=sign bit,
;  E=exp bit & M,X,Y=mantissa bit
; SEEE EEEE EMMM MMMM XXXX XXXX YYYY YYYY
; The exponent "exp" may be positive or negative.
; Floats are stored with excess-127 notation.
; That is, you ADD 127 to your exponent and
; store it as a pure (unsigned) binary.  When the
; number is re-created for use later, 127 ($7F)
; will be subtracted from the exponent.
; This method saves having to use 2's complement
; for negative exponents.
; NB. During the unpacking, a zero bit is shifted
; in on the right so there is a slight increase
; in precision.
; The mantissa is assumed normalized (0.5 <= mantissa < 1)
; The most significant bit is not stored (always 1)
;
; Unpacked number will look like
; EEEE EEEE S000 0000 01MM MMMM MXXX XXXX XYYY YYYY Y000 0000
;
            ASL    FPTemp+2        ;C=E <- MMMM MMM0 <- 0
            LDA    FPTemp+3        ;SEEE EEEE
            ROL    A               ; C=S <- EEEE EEEE <- C
            STA    FExp,X
            BEQ    FP00            ;zero exp -> # is ZERO
;
            LDA    #$00
            STA    FMant0,X        ;0000 0000
            ROL    A               ;C=0 <- 0000 000S <- C
            STA    FSign,X         ;sign of mantissa (0/1)
            LDA    FPTemp+2        ;MMMM MMM0
            SEC                    ;Shift in the msb (which is not stored)
            ROR    A               ;C=1 -> 1MMM MMMM -> C=0
            LSR    A               ;C=0 -> 01MM MMMM -> C=M
            STA    FMant3,X        ;(subtract $7F instead of $80)
            LDA    FPTemp+1        ;XXXX XXXX
            ROR    A               ;C=M -> MXXX XXXX -> C=X
            STA    FMant2,X
            LDA    FPTemp          ;YYYY YYYY
            ROR    A               ;C=X -> XYYY YYYY -> C=Y
            STA    FMant1,X
            ROR    FMant0,X        ; -> Y000 0000
            RTS
;
; A FP value of zero is represented
; by exp=0, mantissa=0 & sign=0
;
FP00        STA    FSign,X
            STA    FMant0,X
            STA    FMant1,X
            STA    FMant2,X
            STA    FMant3,X
            RTS
            REP    50
; Get the 2 FP #s fr the expr stack
; unpack 'em into Acc1 and Acc2
;
Pop2FPs     STX    ExprStkP
            LDX    #>Acc2
            JSR    PopFloat
            LDX    #>Acc1
            JSR    PopFloat
            LDX    ExprStkP
            RTS
            REP    50
; Round the FP in the Acc1
;
Round       LDA    #$00
            STA    Acc2+FMant1
            STA    Acc2+FMant2
            STA    Acc2+FMant3
            LDA    #$40
            STA    Acc2+FMant0
            JSR    AddMant
            BPL    Round1          ;msb=0
            INC    Acc1+FExp
            BNE    Round2
            JMP    OvflFP          ;real overflow
;
Round1      JSR    SHLAcc1         ;Shift a 1 into bit7
Round2      ASL    Acc1+FMant3     ;Get "rid off" 1 b4 binary point
            LSR    Acc1+FSign      ;Shift sign bit
            ROR    Acc1+FExp       ; into this byte
            LDA    Acc1+FMant3
            ROR    A
            STA    ExprStack,X
            INX
            LDA    Acc1+FExp
            STA    ExprStack,X
            INX
            LDA    Acc1+FMant1
            STA    ExprStack,X
            INX
            LDA    Acc1+FMant2
            STA    ExprStack,X
            INX
            RTS
            REP    50
; Bump the exponent
;
BumpExp     LDA    Acc1+FMant0
            ORA    Acc1+FMant1
            ORA    Acc1+FMant2
            ORA    Acc1+FMant3
            BNE    BumpExp1
            JMP    RtnZeroFP       ;Acc1 is zero
;
BumpExp1    LDA    Acc1+FMant3
            BPL    NORMLZE
            INC    Acc1+FExp
            BNE    BumpExp2        ;Is FP # too big?
            JMP    OvflFP          ;Yes, real overflow
BumpExp2    JSR    SHRAcc1
            JMP    Round
            REP    50
; Normalize: Each time the mantissa is shifted
; left, the exponent is decremented by one
; until its leading bit is on.
;
NORMLZE     LDA    Acc1+FMant3
            AND    #$40            ;Leading bit of mantissa
            BEQ    NotDone1        ; is still 0
            JMP    Round
NotDone1    JSR    SHLAcc1
            DEC    Acc1+FExp
            BNE    NORMLZE         ;Loop until...
            JMP    RtnZeroFP       ;->FP is 0
            REP    50
; Add Acc2 to Acc1 & store result in Acc1
; Assume exponents of Acc1 & Acc2 have been aligned
;
AddMant     CLC
            LDA    Acc1+FMant0
            ADC    Acc2+FMant0
            STA    Acc1+FMant0
            LDA    Acc1+FMant1
            ADC    Acc2+FMant1
            STA    Acc1+FMant1
            LDA    Acc1+FMant2
            ADC    Acc2+FMant2
            STA    Acc1+FMant2
            LDA    Acc1+FMant3
            ADC    Acc2+FMant3
            STA    Acc1+FMant3
            RTS
            REP    50
; Subtract Acc2 from Acc1, leaving result in Acc1
; Assume exponents of Acc1 & Acc2 have been aligned
;
SubMant     SEC
            LDA    Acc1+FMant0
            SBC    Acc2+FMant0
            STA    Acc1+FMant0
            LDA    Acc1+FMant1
            SBC    Acc2+FMant1
            STA    Acc1+FMant1
            LDA    Acc1+FMant2
            SBC    Acc2+FMant2
            STA    Acc1+FMant2
            LDA    Acc1+FMant3
            SBC    Acc2+FMant3
            STA    Acc1+FMant3
            RTS
            REP    50
SubReals    LDA    #$01
            STA    ZTemp
            JMP    UnpkEm
;
AddReals    LDA    #$00
            STA    ZTemp
;
UnpkEm      JSR    Pop2FPs         ;Unpack the operands
            LDA    ZTemp
            BEQ    AddReals1       ;add
; subtract
            LDA    Acc2+FSign
            EOR    #$01            ;Flip the sign of 2nd FP #
            STA    Acc2+FSign
;
AddReals1   LDA    Acc2+FExp       ;exp
            BNE    AddReals2
            JMP    Round           ;We are adding/subtracting a 0
;
AddReals2   CMP    Acc1+FExp       ;Is (float2) =< (float1)?
            BEQ    Adjust
            BCC    Adjust          ;Yes
;
; float1 is smaller in magnitude; we swap
; the FP #s so that Acc1 contains the bigger
; FP # and Acc2 has the smaller #
;
            LDA    Acc1+FExp       ;swap exps
            STA    ZTemp
            LDA    Acc2+FExp
            STA    Acc1+FExp
            LDA    ZTemp
            STA    Acc2+FExp
;
            LDA    Acc1+FSign      ;swap signs
            STA    ZTemp
            LDA    Acc2+FSign
            STA    Acc1+FSign
            LDA    ZTemp
            STA    Acc2+FSign
;
            LDA    Acc1+FMant0     ;swap mantissas
            STA    FPTemp
            LDA    Acc1+FMant1
            STA    FPTemp+1
            LDA    Acc1+FMant2
            STA    FPTemp+2
            LDA    Acc1+FMant3
            STA    FPTemp+3
; 
            LDA    Acc2+FMant0
            STA    Acc1+FMant0
            LDA    Acc2+FMant1
            STA    Acc1+FMant1
            LDA    Acc2+FMant2
            STA    Acc1+FMant2
            LDA    Acc2+FMant3
            STA    Acc1+FMant3
;
            LDA    FPTemp
            STA    Acc2+FMant0
            LDA    FPTemp+1
            STA    Acc2+FMant1
            LDA    FPTemp+2
            STA    Acc2+FMant2
            LDA    FPTemp+3
            STA    Acc2+FMant3
            JMP    AddReals1       ;After the swap, check
            REP    50
; Align the "decimal points" b4 adding
;
Adjust      LDA    Acc1+FExp
            SEC
            SBC    Acc2+FExp
            STA    ZTemp           ;# of shifts
            CMP    #30
            BPL    GoIncExp        ;float1 >> float2 in magnitude
            LDA    Acc1+FSign
            CMP    Acc2+FSign
            BEQ    Adj1            ;Same sign
;
            SEC                    ;subtract fr 0
            LDA    #$00
            SBC    Acc2+FMant0
            STA    Acc2+FMant0
            LDA    #$00
            SBC    Acc2+FMant1
            STA    Acc2+FMant1
            LDA    #$00
            SBC    Acc2+FMant2
            STA    Acc2+FMant2
            LDA    #$00
            SBC    Acc2+FMant3
            STA    Acc2+FMant3
;
Adj1        LDA    ZTemp           ;# of shifts
            BEQ    ExpSame         ;Both FPs have same exp
;
ShrLoop1    CLC                    ;Shift the smaller # to the right
            LDA    Acc2+FMant3
            BPL    Adj2            ;Shift in a "0" bit
            SEC                    ;Shift in a "1" bit
Adj2        ROR    Acc2+FMant3
            ROR    Acc2+FMant2
            ROR    Acc2+FMant1
            ROR    Acc2+FMant0
            DEC    ZTemp
            BNE    ShrLoop1
;
; Now both #s have the same exponent
;
ExpSame     JSR    AddMant
            LDA    Acc1+FSign
            CMP    Acc2+FSign
            BEQ    GoIncExp
            LDA    Acc1+FMant3
            BPL    GoIncExp        ;result is +ve
;
            LDA    Acc2+FSign
            STA    Acc1+FSign
            SEC
            LDA    #$00
            SBC    Acc1+FMant0
            STA    Acc1+FMant0
            LDA    #$00
            SBC    Acc1+FMant1
            STA    Acc1+FMant1
            LDA    #$00
            SBC    Acc1+FMant2
            STA    Acc1+FMant2
            LDA    #$00
            SBC    Acc1+FMant3
            STA    Acc1+FMant3
GoIncExp    JMP    BumpExp
            REP    50
; The multiplicand is in Acc2 &
; is not shifted.
;
MulReals    JSR    Pop2FPs         ;unpack operands
            LDA    Acc1+FExp
            BEQ    RetZero         ;mul to 0
            SEC
            SBC    #$7F            ;True exp
            STA    Acc1+FExp
            LDA    Acc1+FSign
            EOR    Acc2+FSign
            STA    Acc1+FSign      ;sign of result
;
            LDA    Acc2+FExp
            BEQ    RetZero         ;mul by 0
            SEC
            SBC    #$7F            ;Get true exponent
            CLC
            ADC    Acc1+FExp       ;exp of result
            BVC    MulReals1
            JMP    OvflFP          ;real overflow
;
MulReals1   CLC
            ADC    #$7F            ;Biased exp = true exp + $7F
            STA    Acc1+FExp
            LDA    Acc1+FMant0
            STA    FPTemp
            LDA    Acc1+FMant1     ;Multiplier
            STA    FPTemp+1
            LDA    Acc1+FMant2
            STA    FPTemp+2
            LDA    Acc1+FMant3
            STA    FPTemp+3
;
            LDA    #$00
            STA    Acc1+FMant0     ;Partial result
            STA    Acc1+FMant1
            STA    Acc1+FMant2
            STA    Acc1+FMant3
;
            LDA    #32             ;# of iterations
            STA    ZTemp
MulLoop2    DEC    ZTemp
            BEQ    MulDone2
            JSR    SHRAcc1         ;Prepare for a possible add
            LSR    FPTemp+3
            ROR    FPTemp+2
            ROR    FPTemp+1
            ROR    FPTemp
            BCC    MulLoop2
            JSR    AddMant         ;Add partial result to multipler
            JMP    MulLoop2        ;Next iteration
;
MulDone2    JMP    BumpExp
RetZero     JMP    RtnZeroFP
            REP    50
; The divisor is in Acc2 &
; is not shifted
;
DivReals    JSR    Pop2FPs         ;unpack operands
            LDA    Acc2+FExp       ;Div by zero?
            BNE    IsNum0          ;No
            JMP    DivBy0          ;real overflow
;
IsNum0      LDA    Acc1+FExp       ;Is numerator 0?
            BEQ    Result0         ;Yes, result should be 0
            LDA    Acc1+FSign
            EOR    Acc2+FSign
            STA    Acc1+FSign      ;Sign of result
            LDA    Acc1+FExp
            SEC
            SBC    Acc2+FExp
            CLC
            ADC    #$7E
            STA    Acc1+FExp
            JSR    SubMant         ;Assume it's possible to do a division
;
            LDA    #$00
            STA    FPTemp
            STA    FPTemp+1        ;Zero the quotient
            STA    FPTemp+2
            STA    FPTemp+3
;
            LDA    #32             ;# of iterations
            STA    ZTemp
DivLoop2    ASL    FPTemp
            ROL    FPTemp+1
            ROL    FPTemp+2
            ROL    FPTemp+3
            JSR    SHLAcc1         ;Test the dividend
            BCC    DivReals1
            JSR    AddMant         ;Can't subtract divisor from dividend
            JMP    DivReals2
DivReals1   JSR    SubMant         ;Do division by subtraction
            LDA    FPTemp          ;To flag the division was successful
            ORA    #$01            ; add a "1" bit to the quotient
            STA    FPTemp
DivReals2   DEC    ZTemp           ;Next iteration
            BNE    DivLoop2
;
            LDA    FPTemp
            STA    Acc1+FMant0
            LDA    FPTemp+1
            STA    Acc1+FMant1
            LDA    FPTemp+2
            STA    Acc1+FMant2
            LDA    FPTemp+3
            STA    Acc1+FMant3
Result0     JMP    BumpExp
            REP    50
CmpReals    JSR    Pop2FPs         ;unpack operands
            LDA    Acc1+FSign
            CMP    Acc2+FSign
            BNE    DiffSigns       ;Opposite signs
            LDA    Acc1+FExp       ;Both FP #s have same sign
            CMP    Acc2+FExp       ;Same exp?
            BEQ    CmpMant3        ;Yes
            BCC    Flt2Gtr         ;Float1 < Float2 in magnitude
            BCS    Flt1Gtr         ;Always
;
; Determine which is bigger in magnitude
;
CmpMant3    LDA    Acc1+FMant3
            CMP    Acc2+FMant3
            BEQ    CmpMant2
            BCC    Flt2Gtr
            BCS    Flt1Gtr
CmpMant2    LDA    Acc1+FMant2
            CMP    Acc2+FMant2
            BEQ    CmpMant1
            BCC    Flt2Gtr
            BCS    Flt1Gtr
CmpMant1    LDA    Acc1+FMant1
            CMP    Acc2+FMant1
            BEQ    CmpMant0
            BCC    Flt2Gtr
            BCS    Flt1Gtr
CmpMant0    LDA    Acc1+FMant0
            CMP    Acc2+FMant0
            BCC    Flt2Gtr
            BNE    Flt1Gtr         ;GT
            JMP    RtnZeroFP       ;Same in magnitude
;
; The two FP #s have opposite signs
;
DiffSigns   LDA    Acc1+FSign      ;Is float1 +ve?
            BNE    Flt2Gtr         ;No, float1 is -ve & float2 is +ve
;
; On fall thru, float2 is -ve since float is +ve
;
Flt1Gtr     LDA    #$01            ;float1 > float2
            STA    ExprStack,X
            INX
            LDA    #$00
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            RTS
;
Flt2Gtr     LDA    #$00            ;float1 < float2
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            LDA    #$01
            STA    ExprStack,X
            INX
            LDA    #$00
            STA    ExprStack,X
            INX
            RTS
            REP    50
; Float the integer (on top of expr stack)
; Integers range -32768($8000) to 32767 ($7FFF)
;
FloatInt    LDA    #$00            ;Assume it's +ve
            STA    Acc1+FSign
            STA    Acc1+FMant0
            STA    Acc1+FMant1
            DEX
            LDA    ExprStack,X     ;Get hi-byte
            STA    Acc1+FMant3
            BPL    FltInt1         ;+ve integer
;
            DEX
            LDA    ExprStack,X     ;Get lo-byte
            STA    Acc1+FMant2
            LDA    #$01
            STA    Acc1+FSign      ;flag as -ve
;
            LDA    #$00            ;Subtract fr 0
            SEC
            SBC    Acc1+FMant2
            STA    Acc1+FMant2
            LDA    #$00
            SBC    Acc1+FMant3
            STA    Acc1+FMant3
            JMP    FltInt2
;
FltInt1     DEX
            LDA    ExprStack,X
            STA    Acc1+FMant2
            ORA    Acc1+FMant3
            BNE    FltInt2         ;Not zero
            JMP    RtnZeroFP       ;-> 0
;
FltInt2     LDA    #$8D            ;Set exp (2^14)
            STA    Acc1+FExp
            JMP    BumpExp
            REP    50
; Fix
;
FixFP       STX    ExprStkP
            LDX    #>Acc1
            JSR    PopFloat
            LDX    ExprStkP
            LDA    Acc1+FExp       ;An exp of 0?
            BEQ    Ret0            ;Yes
;
            LDA    #$8D            ;2^14
            SEC
            SBC    Acc1+FExp
            BEQ    FixFP2          ;Same exp
            BPL    FixFP1          ;Maybe within range
            JMP    OvflInt         ;integer overflow
;
FixFP1      CMP    #$0F
            BPL    Ret0            ;>= 15
            STA    ZTemp
ShrLoop2    LSR    Acc1+FMant3
            ROR    Acc1+FMant2
            DEC    ZTemp
            BNE    ShrLoop2
;
FixFP2      LDA    Acc1+FSign      ;Is # +ve?
            BEQ    FixDone         ;Yes
;
            SEC
            LDA    #$00
            SBC    Acc1+FMant2     ;Do a 2's complement
            STA    ExprStack,X
            INX
            LDA    #$00
            SBC    Acc1+FMant3
            STA    ExprStack,X
            INX
            RTS
;
FixDone     LDA    Acc1+FMant2
            STA    ExprStack,X
            INX
            LDA    Acc1+FMant3
            STA    ExprStack,X
            INX
            RTS
;
Ret0        LDA    #$00
            STA    ExprStack,X
            INX
            STA    ExprStack,X
            INX
            RTS
            REP    50
; Read and print directory
; (A)=drive #
;
ShowDir     STA    CCBDRV
            LDA    DCBSLT
            LSR    A
            LSR    A
            LSR    A
            LSR    A
            STA    CCBSLT
            LDA    #>FCBDCB
            STA    CCBFCB
            LDA    #<FCBDCB
            STA    CCBFCB+1
;
            LDA    #CRQDIR         ;Read Dir
            STA    CCBREQ
            JSR    DOSENT
            LDX    ExprStkP
            RTS
; Not used
            DS     11,0
