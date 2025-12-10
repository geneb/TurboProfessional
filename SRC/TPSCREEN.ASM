;******************************************************
;                 TPSCREEN.ASM 5.22
;              Screen handling routines
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

DATA    ENDS


;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  FillAttribChar, FastWriteMem

;****************************************************** FillAttribChar

;procedure FillAttribChar(var Dest; Number : Word; Ch : Char; Attr : Byte);
;Fills Dest with Number character/attribute pairs

Dest    EQU     DWORD PTR SS:[BX+10]
Number  EQU     WORD PTR SS:[BX+8]
TheChar EQU     BYTE PTR SS:[BX+6]
Attr    EQU     BYTE PTR SS:[BX+4]

FillAttribChar  PROC FAR

        StackFrame
        CLD                             ;Set direction to forward
        GetPtr  Dest                    ;ES:DI points to Dest
        MOV     AL,TheChar              ;AL = Ch
        MOV     AH,Attr                 ;AH = TextAttr
        MOV     CX,Number               ;CX = Number
        JCXZ    FAExit                  ;Exit if 0
        MOV     BL,CheckSnow            ;BL = CheckSnow
        RCR     BL,1                    ;Snow checking on?
        JNC     FANoWait                ;Skip the rest of this if not
        MOV     DX,ES                   ;Check segment in ES
        CMP     DH,0B8h                 ;See if we're writing to CGA memory
        JNE     FANoWait                ;If not, don't wait
        MOV     DX,03DAh                ;Point DX to CGA status port
        MOV     BX,AX                   ;Store video word in BX
FANextWord:
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BX              ;Move the word
        STI                             ;Allow interrupts
        LOOP    FANextWord              ;Do next video word
        JMP     SHORT FAExit            ;All done
FANoWait:
        REP     STOSW                   ;That's all!
FAExit:
        RET     10

FillAttribChar  ENDP

;****************************************************** FastWriteMem

;procedure FastWriteMem(St : String; var Address; Attr : Byte);
;Write St at Address in Attr (video attribute) without snow

FWAttr          EQU     BYTE PTR SS:[BX+4]
FWAddress       EQU     DWORD PTR SS:[BX+6]
FWSt            EQU     DWORD PTR SS:[BX+10]

FastWriteMem  PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS
        CLD                             ;Set direction to forward
        GetPtr  FWAddress               ;ES:DI points to Address
        MOV     CX,ES                   ;CX = Seg(Address^)
        MOV     DL,CheckSnow            ;Get snow check into DL
        CMP     DL,True                 ;Is it set?
        JNE     FWGo                    ;Continue if not
        CMP     CH,0B8h                 ;Writing to CGA memory?
        JE      FWGo                    ;Continue if so
        SetZero DL                      ;Otherwise turn snow checking off

FWGo:
        SetZero CX                      ;CX = 0
        GetDSPtr        FWSt            ;DS:SI points to St[0]
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        MOV     CL,AL                   ;CX = Length
        JCXZ    FWExit                  ;If string empty, exit
        MOV     AH,FWAttr               ;AH = Attribute
        RCR     DL,1                    ;If snow checking is off...
        JNC     FWNoWait                ; use FWNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
FWGetNext:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        MOV     BX,AX                   ;Store video word in BX
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BX              ;Move the word
        LOOP    FWGetNext               ;Get next character
        JMP     SHORT FWExit            ;Done
FWNoWait:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        STOSW                           ;Move video word into place
        LOOP    FWNoWait                ;Get next character
FWExit:
        POP     DS                      ;Restore DS
        RET     10

FastWriteMem  ENDP

CODE    ENDS

        END

