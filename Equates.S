;Name          : EQUATES.S
;End of file   :    5,936

********************************
* Disassembler: TFBD (Phoenix)
* References:
*   Lilith MCode Interpreter
*   Medos-2: A Modula-2 Oriented Operating System
*            for the Personal Computer Lilith
*   The Personal Computer Lilith
*   Modula2 Handbook
********************************
; Some ASCII codes used by the Modula2 Interpreter
;
CTRLC       EQU    $03
BELL        EQU    $07
BS          EQU    $08
LF          EQU    $0A
FF          EQU    $0C
CR          EQU    $0D
CTRLS       EQU    $13
SPACE       EQU    $20
DEL         EQU    $7F
;
; Apple II ZPage locations
;
WNDLFT      EQU    $20
WNDWDTH     EQU    $21
WNDTOP      EQU    $22
WNDBTM      EQU    $23
CH          EQU    $24
CV          EQU    $25
BASL        EQU    $28
BAS2L       EQU    $2A
INVFLG      EQU    $32
YSAV1       EQU    $35
CSWL        EQU    $36
CSWH        EQU    $37
Z44         EQU    $44
Z45         EQU    $45
RNDL        EQU    $4E
RNDH        EQU    $4F
KBD         EQU    $C000
;
; Apple Hardware locations
;
KBSTRB      EQU    $C010
SPKR        EQU    $C030
BasicInt    EQU    $C300
BasicIn     EQU    $C305
BasicOut    EQU    $C307
XC30B       EQU    $C30B           ;GENERIC SIGNATURE BYTE
XC30C       EQU    $C30C           ;DEVICE SIGNATURE BYTE
PInit       EQU    $C30D
PRead       EQU    $C30E
PWrite      EQU    $C30F
PStat       EQU    $C310
ClrROM      EQU    $CFFF
; Offsets into Command Control Block
;
; Dummy Section of zpage locations
; used for the various registers
;
            DSECT
            ORG    $80
PC          DS     2               ;Interpreter's Program Counter
IReg        DS     2               ;instruction register
Z84         DS     2               ;General purpose locations
Z86         DS     2
Z88         DS     2
Z8A         DS     2
Z8C         DS     2
Z8E         DS     2
;
; Ref: page 18 MeDOS-2 manual
; 4 regs point to the stack frame of the currently
; executed process
; P - points to the process descriptor at the
;     beginning of the stack frame 
; L - points to the activation rec on top of stack frame
; S - points to 1st free location in the stack frame
; H - points to the end of stack (H for high limit)
;     addr of stack limit
;
; F - points to the base addr of the code frame
; G - points to the base addr of the data frame
; The first word of the data frame gives the
; reference to the corresponding code frame 
;
FReg        DS     2               ;Code frame base address
GReg        DS     2               ;Corr Data frame base address
HReg        DS     2               ;Stack limit address (himem)
LReg        DS     2               ;Local segment base address
SReg        DS     2               ;Procedure Stack ptr (TOS)
PReg        DS     2               ;Process base address
MReg        DS     2               ;Process interrupt mask
ExprStkP    DS     2               ;Save area for index into ExprStack
ExprStack   DS     32              ;Expression Stack ($A0-$BF) 16 words
ZTemp       DS     1
FPTemp      DS     4               ;work area for temp FP
Acc1        DS     6
Acc2        DS     6
            DEND
********************************
*  Ref: Appendix C of interpreter docs Fixed addr section
*
X0800       EQU    $0800           ;F-register of module 0 (SYSTEM)
;
; The data frame table holds addrs of the
; data frames of loaded modules. All modules
; are accessed through this table. The index
; to an entry in this table is called the
; module number.
; MeDOS-2 ref pg 15, Appendix C of interp doc
;
DFTab       EQU    $0840           ;data frame table
********************************
* Trap Error Numbers
* Ref Lilith mcode interpreter manual
*
end         EQU    0
instrChk    EQU    1               ;illegal instruction
prioChk     EQU    2               ;priority error
storageChk  EQU    3               ;storage overflow
rangeChk    EQU    4               ;range violation
addrChk     EQU    5               ;NIL access/invalid computed addr
realOvfl    EQU    6               ;floating point overflow
cardOvfl    EQU    7               ;cardinal overflow
intOvfl     EQU    8               ;integer overflow
funcErr     EQU    9               ;function return error
halt        EQU    10              ;halt called
assertErr   EQU    11              ;assertion error
stopped     EQU    13
;
; Offsets into an unpacked floating point number
;
FMant0      EQU    0               ;Mantissa
FMant1      EQU    1
FMant2      EQU    2
FMant3      EQU    3
FSign       EQU    4               ;Sign
FExp        EQU    5               ;Exponent
;
false       EQU    0
true        EQU    1
;
; Data Structure of File is given below:
; File = RECORD
;          id : CARDINAL;
;          eof : BOOLEAN;
;          res : Response;
;          tmp : BOOLEAN;
;          name : ARRAY[0..29] OF CHAR;
;          data : ARRAY [0..127] OF CARDINAL;
;          ts : ARRAY [0..127] OF CARDINAL;
;          wrk : ARRAY [0..22] OF CARDINAL;
;        END;
;
            DSECT
f.id        DS     2               ;file ref #
f.eof       DS     2               ;Indicate if DOS call was successful
f.res       DS     2               ;error code
f.tmp       DS     2
f.name      DS     30              ;FileName
f.data      DS     256
f.st        DS     256             ;sector
f.wrk       DS     46              ;Use as a DOS FCB/DCB
            DEND
********************************
* Apple DOS 3.3 page 3 vectors
*
CallFM      EQU    $03D6           ;DOS File Manager ($AAFD)
X03DC       EQU    $03DC           ;Subrtn to locate input parm list for File Manager ($B5BB)
X03E3       EQU    $03E3           ;Subrtn to locate input parm list for RWTS ($B7E8)
SOFTEV      EQU    $03F2
;
; DOS 3.3 equates
;
DOSENT      EQU    $AB06           ;File Mgr Main entry
DCBSUP      EQU    $ABDC           ;Init File Mgr work area
RDVTOC      EQU    $AFF7           ;Read/Write VTOC buffer
RDVDIR      EQU    $B011           ;Read a dir sector
VDINC       EQU    $B230           ;Advance index into next dir entry
TEMP1       EQU    $B39C           ;Dir index
TEMP2       EQU    $B39D
CVTAB       EQU    $B3A4           ;Decimal conversion table
FTTAB       EQU    $B3A7           ;file type table
VSECAL      EQU    $B3F3           ;sector allocation (bitmap)
VDFILE      EQU    $B4C6           ;1st dir entry & track of T/S list
CCBREQ      EQU    $B5BB           ;USER REQUEST BYTE (opcode)
CCBDRV      EQU    $B5C0           ;drive
CCBSLT      EQU    $B5C1           ;slot
CCBFCB      EQU    $B5C7           ;FCB PTR (Addr of File Mgr WA)
FCBDCB      EQU    $B5D1           ;FILE DATA CONTROL BLOCK
DCBSLT      EQU    $B5F7           ;slot # x 16
DCBDRV      EQU    $B5F8           ;drive #
DCBVOL      EQU    $B5F9           ;vol # (complemented)
;
; Command Control Block request codes (lifted fr DOS source)
;
CRQNUL      EQU    0               ; 0-NO REQUEST
CRQOPN      EQU    1               ; 1-OPEN FILE
CRQCLS      EQU    2               ; 2-CLOSE FILE
CRQRD       EQU    3               ; 3-READ DATA
CRQWR       EQU    4               ; WRITE DATA
CRQDEL      EQU    5               ; 5-DELETE FILE
CRQDIR      EQU    6               ; 6-READ DIRECTORY
CRQLCK      EQU    7               ; 7-LOCK FILE
CRQUNL      EQU    8               ; 8-UNLOCK FILE
CRQRNM      EQU    9               ; 9-RENAME
CRQPOS      EQU    10              ; 10-POSITION FILE
CRQFMT      EQU    11              ; 11-FORMAT
CRQVAR      EQU    12              ; 12 - VERIFY
CRQMAX      EQU    13
oCCBREQ     EQU    0
oCCBRQM     EQU    1               ;Request Modifier Byte
CRMNBT      EQU    1               ; R/W NEXT BYTE
CRMNBL      EQU    2               ; R/W NEXT BLOCK
oCCBRLN     EQU    2
oCCBFN2     EQU    2
oCCBVOL     EQU    4
;
oCCBDRV     EQU    5
oCCBBLN     EQU    6
oCCBSLT     EQU    6
oCCBFUC     EQU    7
oCCBDAT     EQU    8
oCCBBBA     EQU    8
oCCBFN1     EQU    8               ;Ptr to filename
;
oCCBSTA     EQU    10              ;Result Status
CREFNF      EQU    6               ; FILE NOT FOUND
CRENSA      EQU    9
;
oCCBFCB     EQU    12              ;File Control Block ptr
oCCBDBP     EQU    14              ;Ptr to Dir Buf
oCCBSBP     EQU    16              ;Ptr to SECTOR BUF
oDCBCRR     EQU    25              ;current relative record
oDCBCRB     EQU    27              ;current relative byte
; Offsets into I/O Block
oIBSLOT     EQU    1
oIBPDRV     EQU    16