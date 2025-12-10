;******************************************************
;                  TPPACK.ASM 5.22
;           Screen packing/unpacking routines
;     Copyright (c) TurboPower Software 1988, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Equates

;structure of a PackedWindow -- DO NOT CHANGE!!

WSize           EQU     (WORD PTR 0)    ;size of packed window
TopRow          EQU     (BYTE PTR 2)    ;coordinates for top left
TopCol          EQU     (BYTE PTR 3)    ; corner of window
Rows            EQU     (BYTE PTR 4)    ;height of window
Cols            EQU     (BYTE PTR 5)    ;width of window
AStart          EQU     (WORD PTR 6)    ;index to start of attributes section
CDelta          EQU     (WORD PTR 8)    ;# of bytes to first PackRec -- chars
ADelta          EQU     (WORD PTR 10)   ;# of bytes to first PackRec -- attrs
Contents        EQU     (BYTE PTR 12)   ;the contents of the packed screen

;structure of a PackRec -- DO NOT CHANGE!!

Link            EQU     (WORD PTR 0)
FillVal         EQU     (BYTE PTR 2)
FillCnt         EQU     (WORD PTR 3)
PackRecSize     =       5

;****************************************************** Data

DATA    SEGMENT BYTE PUBLIC

        ;Pascal variables

        EXTRN   VirtualWidth : BYTE             ;Current width of screen
        EXTRN   CheckSnow : BYTE                ;If true, check for retrace
        EXTRN   VirtualSegment : WORD           ;Segment of screen

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  PackPrim, DispPackedWindow

;****************************************************** GetWaitState

GetWaitState    PROC NEAR

        MOV     AX,VirtualSegment       ;AX = VirtualSegment
        MOV     AL,CheckSnow            ;Get snow check flag into AL
        OR      AL,AL                   ;Is it set?
        JZ      WaitExit                ;Exit if not
        CMP     AH,0B8h                 ;Reading/writing CGA memory?
        JE      WaitExit                ;Exit if so
        SetZero AL                      ;Otherwise turn snow checking off
WaitExit:
        RET

GetWaitState    ENDP

;****************************************************** PackPrim

;function PackPrim(Height, Width : Byte;
;                  DstSeg, DstOfs, SrcOfs : Word;
;                  var Delta : Word) : Word;
;Primitive routine to pack a window. Called once for the characters and
; once for the attributes

;-------------- params -----------------
PDheight        EQU     BYTE PTR [BP+16]
PDwidth         EQU     BYTE PTR [BP+14]
PDseg           EQU     WORD PTR [BP+12]
PDofs           EQU     WORD PTR [BP+10]
PSofs           EQU     WORD PTR [BP+8]
Delta           EQU     DWORD PTR [BP+4]
;-------------- locals -----------------
LastLink        EQU     WORD PTR [BP-2]
PRdelta         EQU     WORD PTR [BP-4]
Count           EQU     WORD PTR [BP-6]
Pwords1         EQU     WORD PTR [BP-8]
Ldelta          EQU     WORD PTR [BP-10]
LocalSnow1      EQU     BYTE PTR [BP-11]

PackPrim        PROC NEAR

        StackFrameBP
        SUB     SP,11                           ;make room for locals
        PUSH    DS
        CLD                                     ;go forward

        MOV     AX,WP VirtualWidth              ;calculate words to next row
        SHL     AX,1
        MOV     Pwords1,AX

        MOV     Count,1                         ;initialize other locals
        MOV     PRdelta,0
        MOV     LastLink,-1

        CALL    GetWaitState                    ;Set local snow checking flag
        MOV     LocalSnow1,AL

        MOV     DS,VirtualSegment               ;DS:SI => start of window
        MOV     SI,PSofs
        MOV     ES,PDseg                        ;ES:DI => start of packed screen
        MOV     DI,PDofs
        PUSH    DI                              ;save starting offset

        OR      AL,AL                           ;snow checking on?
        JZ      GetFirst
        MOV     DX,03DAh                        ;Point DX to CGA status port
        WaitForRetrace                          ;wait for opportunity
GetFirst:
        MOV     AH,[SI]                         ;AH has last byte -- no NOT AH!
        STI                                     ;interrupts on

        MOV     CL,PDheight                     ;load outer loop counter
        SetZero CH

OuterLoop1:
        PUSH    CX                              ;save outer loop counter
        MOV     CL,PDwidth                      ;load inner loop counter
        SetZero CH
        PUSH    SI                              ;save source index

InnerLoop1:
        CMP     LocalSnow1,False                ;Need to wait for retrace?
        JE      NoWait                          ;if not, go ahead
        WaitForRetrace                          ;Else, wait for an opportunity
NoWait: LODSB                                   ;Read the next byte
        STI                                     ;Allow interrupts
        INC     SI                              ;skip the odd byte
        NOT     AL                              ;flip the bits

        STOSB                                   ;plug it in
        INC     PRdelta                         ;distance between PackRec's
        CMP     AL,AH                           ;a repeated byte?
        JNE     NoRepeat

        INC     Count                           ;increment repeat counter
        LOOP    InnerLoop1                      ;repeat inner loop
        JMP     SHORT EndInner1

NoRepeat:
        CMP     Count,PackRecSize               ;is pattern long enough?
        JBE     EndRepeat                       ;if not, no PackRec
        MOV     BX,Count                        ;Dec(PRdelta, Count+1)
        INC     BX
        SUB     PRdelta,BX
        MOV     BX,LastLink                     ;BX = LastLink
        PUSH    PRdelta                         ;Put PRdelta on stack
        CMP     BX,-1                           ;Is it -1?
        JNE     FixLastPackRec1
        POP     LDelta                          ;if so, LDelta = PRdelta
        JMP     SHORT MakePackRec

FixLastPackRec1:
        POP     ES:[BX]                         ;else, ES:LastLink = PRdelta

MakePackRec:
        MOV     BX,Count                        ;BX has Count
        SUB     DI,BX                           ;DI = DI-Succ(Count)
        DEC     DI
        MOV     LastLink,DI                     ;save offset in LastLink
        INC     DI                              ;skip the link for now
        INC     DI
        XCHG    AH,AL                           ;get last value into AL
        STOSB                                   ;store it as the FillVal
        XCHG    AH,AL                           ;switch AH and AL back
        XCHG    AX,BX                           ;switch AX and BX
        STOSW                                   ;store the FillCnt
        MOV     AX,BX                           ;get old AX back from BX
        MOV     PRdelta,1                       ;reset distance
        STOSB                                   ;append new char after PackRec

EndRepeat:
        MOV     AH,AL                           ;save last value
        MOV     Count,1                         ;repeat count = 1
        LOOP    InnerLoop1                      ;repeat inner loop

EndInner1:
        POP     SI                              ;restore source index
        ADD     SI,Pwords1                      ;advance to next row
        POP     CX                              ;restore outer loop counter
        LOOP    OuterLoop1                      ;repeat outer loop

        ;fill in the previous link

        MOV     CX,PRdelta                      ;CX = PRdelta
        MOV     BX,Count                        ;BX = Count
        CMP     BX,PackRecSize                  ;will we need a PackRec?
        JBE     DeltaOK                         ;if not, don't adjust delta
        SUB     CX,BX                           ;else, CX = PRdelta-Count

DeltaOK:
        CMP     LastLink,-1                     ;have we had a PackRec?
        JNE     FixLastPackRec2
        MOV     Ldelta,CX                       ;if not, Ldelta = PRdelta
        JMP     SHORT PackRecCheck

FixLastPackRec2:
        MOV     SI,LastLink                     ;store PRdelta in the last
        MOV     ES:[SI],CX                      ; unfinished PackRec

PackRecCheck:
        CMP     BX,PackRecSize                  ;do we need a final PackRec?
        JBE     PPdone

        SUB     DI,BX                           ;back up dest index
        MOV     CL,AH                           ;save last value in CL
        XOR     AX,AX                           ;link is 0
        STOSW
        MOV     AL,CL                           ;store FillVal
        STOSB
        MOV     AX,BX                           ;store repeat count
        STOSW

PPdone:
        MOV     BX,DI                           ;save current dest. offset
        LES     DI,Delta                        ;set Delta
        MOV     AX,Ldelta
        STOSW

        POP     AX                              ;recover starting offset
        SUB     BX,AX                           ;calculate difference...
        MOV     AX,BX                           ; and return in AX

        POP     DS                              ;restore DS
        Exit_Code 14                            ;!!.12

PackPrim        ENDP

;****************************************************** DispPackedWindow

;procedure DispPackedWindow(PWP : PackedWindowPtr);
;Display the packed window pointed to by PWP.

;-------------- params -----------------
PWP             EQU     DWORD PTR [BP+6]
;-------------- locals -----------------
NextRecA        EQU     WORD PTR [BP-2]
NextRecC        EQU     WORD PTR [BP-4]
FillCntC        EQU     WORD PTR [BP-6]
FillCntA        EQU     WORD PTR [BP-8]
PWords2         EQU     WORD PTR [BP-10]
LCols           EQU     WORD PTR [BP-12]
LocalSnow2      EQU     BYTE PTR [BP-13]

DispPackedWindow        PROC FAR

        StackFrameBP                            ;set up stack frame
        SUB     SP,13                           ;make room for locals
        PUSH    DS                              ;save DS
        CLD                                     ;go forward

        MOV     AL,VirtualWidth                 ;calculate words to next row
        SetZero AH
        SHL     AX,1
        MOV     Pwords2,AX
        CALL    GetWaitState                    ;Set local snow checking flag
        MOV     LocalSnow2,AL

        ;get fields in window record into local storage
        LES     BX,PWP                          ;ES:DI = PWP
        SetZero AH                              ;LCols = # of columns
        MOV     AL,ES:[BX].Cols
        MOV     LCols,AX
        MOV     CL,ES:[BX].Rows                 ;CX has outer loop counter
        SetZero CH                              ; (number of rows)
        MOV     AX,ES:[BX].CDelta               ;# of bytes to first PackRec
        MOV     NextRecC,AX                     ; (characters)
        MOV     AX,ES:[BX].ADelta               ;# of bytes to first PackRec
        MOV     NextRecA,AX                     ; (attributes)

        SetZero AH                              ;calculate starting
        MOV     AL,ES:[BX].TopCol               ;offset on screen (in DI)
        MOV     DI,AX
        DEC     DI
        SHL     DI,1
        MOV     AL,ES:[BX].TopRow
        DEC     AX
        MUL     PWords2
        ADD     DI,AX

        LEA     SI,ES:[BX].Contents             ;SI = offset of characters
        MOV     BX,ES:[BX].AStart               ;BX has offset to attributes
        DEC     BX                              ;array is 1-based
        ADD     BX,SI

        MOV     AX,ES                           ;AX = ES
        MOV     ES,VirtualSegment               ;ES = VirtualSegment
        MOV     DS,AX                           ;DS = AX

        SetZero AX                              ;initialize fill counters to 0
        MOV     FillCntA,AX
        MOV     FillCntC,AX

OuterLoop2:
        PUSH    CX                              ;save outer loop counter
        MOV     CX,LCols                        ;load inner loop counter
        PUSH    DI                              ;save dest index

InnerLoop2:
        ;get next character
        CMP     FillCntC,0                      ;still filling?
        JE      NotFillingC
        DEC     FillCntC                        ;yes, decrement counter
        JMP     SHORT NextAttr

NotFillingC:
        CMP     NextRecC,0                      ;see if this is a PackRec
        JNE     NotAPackRecC
        MOV     DX,[SI]                         ;NextRecC = Link
        MOV     NextRecC,DX
        INC     SI                              ;skip over the link
        INC     SI
        LODSB                                   ;AL has FillVal
        NOT     AL                              ;flip the bits
        MOV     DX,[SI]                         ;FillCntC = FillCnt-1
        DEC     DX
        MOV     FillCntC,DX
        INC     SI                              ;skip over the FillCnt
        INC     SI
        JMP     SHORT NextAttr

NotAPackRecC:
        LODSB                                   ;get next character
        NOT     AL                              ;flip the bits
        DEC     NextRecC                        ;decrement counter

        ;get next attribute
NextAttr:
        CMP     FillCntA,0                      ;still filling?
        JE      NotFillingA
        DEC     FillCntA                        ;yes, decrement counter
        JMP     SHORT StoreWord

NotFillingA:
        CMP     NextRecA,0                      ;see if this is a PackRec
        JNE     NotAPackRecA
        MOV     DX,[BX]                         ;NextRecC = Link
        MOV     NextRecA,DX
        INC     BX                              ;skip over the Link
        INC     BX
        MOV     AH,[BX]                         ;AH has FillVal
        NOT     AH                              ;flip the bits
        INC     BX                              ;skip over the FillVal
        MOV     DX,[BX]                         ;FillCntA = FillCnt-1
        DEC     DX
        MOV     FillCntA,DX
        INC     BX                              ;skip over the FillCnt
        INC     BX
        JMP     SHORT StoreWord

NotAPackRecA:
        MOV     AH,[BX]                         ;get next attribute
        NOT     AH                              ;flip the bits
        INC     BX
        DEC     NextRecA                        ;decrement counter

StoreWord:
        PUSH    BX                              ;save BX
        CMP     LocalSnow2,False                ;do we need to wait?
        JE      Go                              ;if not, go ahead
        MOV     DX,03DAh                        ;Point DX to CGA status port
        MOV     BX,AX                           ;save AX in BX
        WaitForRetrace                          ;wait for an opportunity
        MOV     AX,BX                           ;restore AX
Go:     STOSW                                   ;store the pair
        STI                                     ;Allow interrupts
        POP     BX                              ;restore BX
        LOOP    InnerLoop2                      ;repeat inner loop

        POP     DI                              ;restore dest index
        ADD     DI,Pwords2                      ;advance to next row
        POP     CX                              ;restore outer loop counter
        DEC     CX                              ;decrement counter
        JCXZ    DPWdone                         ;done?
        JMP     OuterLoop2                      ;repeat outer loop

DPWdone:
        POP     DS                              ;restore DS
        Exit_Code 4                             ;!!.12

DispPackedWindow        ENDP

CODE    ENDS

        END
