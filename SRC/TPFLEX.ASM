;******************************************************
;                  TPFLEX.ASM 5.22
;             Flexible fast write routine
;     Copyright (c) TurboPower Software 1988, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Data

DATA    SEGMENT BYTE PUBLIC

        ;Pascal variables

        EXTRN   WindMin : WORD                  ;Min. XY coordinates
        EXTRN   WindMax : WORD                  ;Max. XY coordinates

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  FlexWrite, FlexWriteWindow

        EXTRN   CalcOffset : NEAR               ;in TPFAST.OBJ

        EXTRN   MapColor : FAR                  ;Pascal routine

;****************************************************** FlexWriteWindow

;procedure FlexWriteWindow(S : string; Row, Col : Byte; var FAttrs : FlexAttrs);
;Write a string flexibly using window-relative coordinates.

FWWCol  EQU     BYTE PTR SS:[BX+8]
FWWRow  EQU     BYTE PTR SS:[BX+10]
FWWSt   EQU     DWORD PTR SS:[BX+12]

FlexWriteWindow PROC FAR

        StackFrame
        MOV     AL,FWWRow               ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FWWRow,AL               ;Reload Row
        MOV     AL,FWWCol               ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FWWCol,AL               ;Reload Col

        ;Let FlexWrite do the rest

FlexWriteWindow ENDP

;****************************************************** FlexWrite

;procedure FlexWrite(St : String; Row, Col : Byte; var FAttrs : FlexAttrs);
;Write St at Row,Col with flexible color handling

FWSt    EQU     DWORD PTR [BP+14]
FWRow   EQU     BYTE PTR [BP+12]
FWCol   EQU     BYTE PTR [BP+10]
FWAttrs EQU     DWORD PTR [BP+6]
;return address is at BP+2
;old BP is at BP+0
SaveDS  EQU     WORD PTR [BP-2]
Attrs   EQU     BYTE PTR [BP-6]

FlexWrite       PROC FAR

        StackFrameBP
        PUSH    DS                      ;Save DS
        SUB     SP,4                    ;make room for locals
        CLD                             ;go forward

        LDS     SI,FWAttrs              ;DS:SI => FAttrs
        PUSH    SS                      ;ES:DI => Attrs
        POP     ES
        LEA     DI,Attrs
        MOVSW                           ;make a local copy of the attributes
        MOVSW
        MOV     DS,SaveDS               ;restore DS

        SetZero AH                      ;AH = 0
        MOV     AL,FWRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FWCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset

        GetDSPtr FWSt                   ;DS:SI points to St[0]
        SetZero CH                      ;CH = 0
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        MOV     CL,AL                   ;CX = Length
        JCXZ    FWExit                  ;If string empty, exit

        MOV     AH,Attrs                ;get the default attribute into AH
        SetZero AL                      ;AL = 0
        PUSH    AX                      ;push the pair onto the stack

        MOV     DH,03h                  ;DH = 3
        CMP     DL,CH                   ;If snow checking is on...
        JE      FWGetNext
        MOV     DL,0DAh                 ;Point DX to CGA status port (03DAh)

FWGetNext:
        LODSB                           ;Load next character into AL
        CMP     AL,DH                   ;is it in range ^A..^C?
        JA      NotSpecial
        OR      AL,AL
        JZ      NotSpecial

        POP     BX                      ;get current char/attr pair off stack
        OR      BL,BL                   ;is the character 0?
        JZ      NewAttr                 ;if so, this is a new attribute
        CMP     BL,AL                   ;is it the same as the current one?
        JNE     NewAttr                 ;if not, this is a new attribute
        POP     AX                      ;else get previous char/attr into AX
;       OR      AL,AL                   ;is the character 0?    !!.12
;       JNZ     NotZero                                         !!.12
        PUSH    AX                      ;if so, push the pair back on the stack
;NotZero:                                                       !!.12
        LOOP    FWGetNext               ;and get next character
        JMP     SHORT FWExit

NewAttr:
        PUSH    BX                      ;put the current pair back on stack
        MOV     AH,AL                   ;save the special character in AH
        LEA     BX,Attrs                ;SS:BX points to Attrs
        XLAT    BYTE PTR SS:[0]         ;translate the attribute
        XCHG    AH,AL                   ;get the attr into AH, char into AL
        PUSH    AX                      ;push the char/attr onto the stack
        LOOP    FWGetNext               ;and get next character
        JMP     SHORT FWExit

NotSpecial:
        OR      DL,DL                   ;is DL set up for retrace checking?
        JNZ     FWWait                  ;if so, use special routine
        STOSW                           ;else, move video word into place
        LOOP    FWGetNext               ;and get next character
        JMP     SHORT FWExit

FWWait:
        MOV     BX,AX                   ;Store video word in BX
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BX              ;Move the word
        LOOP    FWGetNext               ;Get next character

FWExit:
        MOV     DS,SaveDS               ;Restore DS
        Exit_Code 12                    ;!!.12

FlexWrite       ENDP

CODE    ENDS

        END
