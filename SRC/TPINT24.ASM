;******************************************************
;                  TPINT24.ASM 5.22
;               Critical error handler
;     Copyright (c) TurboPower Software 1987, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Data

DATA    SEGMENT WORD PUBLIC

        EXTRN   SaveInt24 : DWORD               ;DOS's Int24 handler

        TPInt24 Pointer <>                      ;Turbo's Int24 handler

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE,DS:DATA

        PUBLIC  Int24Result, Int24On, Int24Off, Int24Init

        EXTRN   IoResultPrimitive : NEAR        ;Pascal routine


;CS-relative data:
Int24Err        DB      0               ;Boolean -- 1 means critical error
Int24ErrCode    DB      0               ;Byte -- the DOS error code
Dos3Plus        DB      True            ;Boolean - True if running DOS 3.x or
                                        ; higher

;****************************************************** Int24

;procedure Int24
;Interrupt handler for DOS critical errors

FailCode        = 3
IgnoreCode      = 0

Int24           PROC NEAR

        MOV     CS:Int24Err,True        ;Set error flag
        XCHG    AX,DI                   ;DI has error code on entry
        MOV     CS:Int24ErrCode,AL      ;Store error code for later
        XCHG    AX,DI                   ;Restore AX
        MOV     AL,FailCode             ;Fail the DOS call
        CMP     CS:Dos3Plus,True        ;DOS 3.x or higher?
        JE      Int24Exit               ;If so, done
        MOV     AL,IgnoreCode           ;else, tell DOS to I)gnore error instead
Int24Exit:
        IRET                            ;Return

Int24           ENDP

;****************************************************** Int24Result

;function Int24Result : Word;

;Returns DOS critical error code in high byte, IoResult in low byte.

Int24Result     PROC FAR

        CALL    IoResultPrimitive       ;Get IoResult into AX
        CMP     CS:Int24Err,True        ;Critical error flag set?
        JNE     IrExit                  ;No? Done

        ;Merge critical error code into result

        MOV     AH,CS:Int24ErrCode      ;Int24ErrCode into AH
        OR      AH,AH                   ;Is AH 0?
        JNZ     IrAHnot0                ;If not, continue
        MOV     AH,0Dh                  ;Else, attempt to write to
                                        ;write protected disk. Map to $0D.
IrAHnot0:
        MOV     CS:Int24ErrCode,0       ;Reset Int24ErrCode to 0
        MOV     CS:Int24Err,False       ;Clear error flag

IrExit:
        RET

Int24Result     ENDP

;****************************************************** Int24On

;procedure Int24On;

;Install DOS critical error handler.

Int24On         PROC FAR

        PUSH    DS                      ;Save DS

        ;Install new critical error handler

        PUSH    CS                      ;Get CS...
        POP     DS                      ; into DS
        MOV     DX,Offset Int24         ;DS:DX points to Int24
        MOV     AX,2524h                ;AH = Set vector, AL = vector to set
        INT     21h                     ;Call DOS

        ;Initialize variables

        MOV     CS:Int24Err,False       ;Clear error flag
        MOV     CS:Int24ErrCode,0       ;Clear error code

        POP     DS                      ;Restore DS
        RET

Int24On         ENDP

;****************************************************** Int24Off

;procedure Int24Off(RestoreDosHandler : Boolean);

;Restore DOS critical error handler or Turbo's.

SwitchDos       EQU     BYTE PTR SS:[BX+4]

Int24Off        PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS

        CMP     SwitchDos,True          ;Switch to DOS's handler?
        JNE     IOuseTP                 ;if not, switch to Turbo's
        MOV     DX,SaveInt24.Ofst       ;DX = old offset stored by Turbo
        MOV     DS,SaveInt24.Segm       ;DS:DX points to old ISR
        JMP     SHORT IOgo
IOuseTP:
        MOV     DX,TPInt24.Ofst         ;DX = old offset
        MOV     DS,TPInt24.Segm         ;DS:DX points to old ISR
IOgo:
        MOV     AX,2524h                ;AH = Set vector, AL = vector to set
        INT     21h                     ;Call DOS
        MOV     CS:Int24Err,False       ;Clear error flag
        POP     DS                      ;Restore DS
        RET     2                       ;!!.11

Int24Off        ENDP

;****************************************************** Int24Init

;procedure Int24Init;
;Save Turbo's vector.

Int24Init       PROC NEAR

        ;Get and save address of old critical error handler
        GetVector 24h, TPInt24          ;Save current vector in TPInt24
        DosCall 30h                     ;Get DOS version
        XCHG    AL,AH                   ;Major version # in AH, minor in AL
        MOV     CS:Dos3Plus,True        ;Assume DOS 3.x or higher
        CMP     AX,0300h                ;Is it?
        JAE     InitExit                ;If so, exit
        MOV     CS:Dos3Plus,False       ;Else, Dos3Plus is False
InitExit:
        RET

Int24Init       ENDP

CODE    ENDS

        END
