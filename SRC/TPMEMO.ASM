;******************************************************
;                  TPMEMO.ASM 5.22
;             Misc. routines for TPMEMO
;     Copyright (c) TurboPower Software 1987, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Data

DATA    SEGMENT BYTE PUBLIC

        ;Pascal variables

        EXTRN   CheckSnow : BYTE                ;If true, check for retrace
        EXTRN   VirtualSegment : WORD           ;Segment of Video Memory--alt
        EXTRN   VirtualWidth : BYTE             ;Current width of virtual display

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  FastWriteCtrl, Scan

;****************************************************** CalcOffset

;calculate Offset in video memory.
;On entry, AX has Row, DI has Column
;On exit, CX and ES have VideoSegment, DI has offset,
; and DL = 1 if snow checking is needed

CalcOffset      PROC NEAR

        DEC     AX                      ;Row to 0..24 range
        MOV     CX, WP VirtualWidth     ;CX = Rows per column
        MUL     CX                      ;AX = Row * VirtualWidth
        DEC     DI                      ;Column to 0..79 range
        ADD     DI,AX                   ;DI = (Row * VirtualWidth) + Col
        SHL     DI,1                    ;Account for attribute bytes
        MOV     CX,VirtualSegment       ;CX = VirtualSegment
        MOV     ES,CX                   ;ES:DI points to VideoSegment:Row,Col
        CLD                             ;Set direction to forward
        MOV     DL,CheckSnow            ;Get snow check into DL
        CMP     DL,True                 ;Is it set?
        JNE     CalcExit                ;Exit if not
        CMP     CH,0B8h                 ;Writing to CGA memory?
        JE      CalcExit                ;Exit if so
        SetZero DL                      ;Otherwise turn snow checking off
CalcExit:
        RET                             ;Return

CalcOffset      ENDP

;****************************************************** FastWriteCtrl

;procedure FastWriteCtrl(St : String; Row, Col, Attr, Ctrl : Byte);
;Write St at Row,Col in Attr (video attribute) without snow. Ctrl characters
;displayed in Ctrl as upper-case letters

FWCtrl          EQU     BYTE PTR SS:[BX+4]
FWAttr          EQU     BYTE PTR SS:[BX+6]
FWCol           EQU     BYTE PTR SS:[BX+8]
FWRow           EQU     BYTE PTR SS:[BX+10]
FWSt            EQU     DWORD PTR SS:[BX+12]

FastWriteCtrl   PROC FAR

        StackFrame                      ;Set up stack frame
        PUSH    DS                      ;Save DS
        PUSH    BP                      ;Save BP
        SetZero AH                      ;AH = 0
        MOV     AL,FWRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FWCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        GetDSPtr        FWSt            ;DS:SI points to St[0]
        SetZero CX                      ;CX = 0
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        MOV     CL,AL                   ;CX = Length
        JCXZ    FWExit                  ;If string empty, exit
        MOV     AH,FWAttr               ;AH = Attr
        MOV     BL,FWCtrl               ;BL = Ctrl
        MOV     BH,AH                   ;BH = Attr
        SHR     DL,1                    ;If snow checking is off...
        JNC     FWNoWait                ; use FWNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
FWGetNext:
        MOV     AH,BH                   ;Assume regular attribute
        LODSB                           ;Load next character into AL
        CMP     AL,' '                  ;Is it a ctrl character?
        JAE     FWnotCtrl               ;If not, continue
        MOV     AH,BL                   ;Else use Ctrl attribute
        ADD     AL,64                   ;Convert ^A to A, etc.
FWnotCtrl:
        MOV     BP,AX                   ;Store video word in BX
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BP              ;Move the word
        LOOP    FWGetNext               ;Get next character
        JMP     SHORT FWExit            ;Done
FWNoWait:
        MOV     DX,4020h                ;DH = 64, DL = ' '
FWNoWaitAgain:
        MOV     AH,BH                   ;Assume regular attribute
        LODSB                           ;Load next character into AL
        CMP     AL,DL                   ;Is it a ctrl character?
        JAE     FWnotCtrl2              ;If not, continue
        MOV     AH,BL                   ;Else use Ctrl attribute
        ADD     AL,DH                   ;Convert ^A to A, etc.
FWnotCtrl2:
        STOSW                           ;Move video word into place
        LOOP    FWNoWaitAgain           ;Get next character
FWExit:
        POP     BP                      ;Restore BP
        POP     DS                      ;Restore DS
        RET     12                      ;Remove parameters and return

FastWriteCtrl   ENDP

;****************************************************** Scan

;function Scan(Limit : Integer; Ch : Char; T : Pointer) : Integer;
;Scan limit chars for char, ch not found if rslt=limit

ScT     EQU     DWORD PTR [BP+6]
ScCh    EQU     BYTE PTR [BP+10]
ScLimit EQU     WORD PTR [BP+12]

Scan    PROC FAR

        PUSH    BP                      ;Save BP
        MOV     BP,SP                   ;Set up stack frame
        CLD                             ;assume forward
        MOV     AL,ScCh                 ;char to search for
        MOV     CX,ScLimit              ;bytes to search
        OR      CX,CX                   ;check sign
        PUSHF                           ;save flags
        JNS     X1
        NEG     CX                      ;make positive
        STD                             ;but search in reverse
X1:
        MOV     DX,CX                   ;save full count
        LES     DI,ScT                  ;ptr to start
        REPNE   SCASB                   ;search
        JNE     X2
        INC     CX                      ;found a match
X2:
        SUB     DX,CX                   ;find count to match
        MOV     AX,DX                   ;ready for return
        POPF
        JNS     X3
        NEG     AX                      ;make negative if reverse
X3:
        MOV     SP,BP                   ;Restore SP
        POP     BP                      ;Restore BP
        RET     8                       ;Remove parameters and return

Scan    ENDP

CODE    ENDS

        END
