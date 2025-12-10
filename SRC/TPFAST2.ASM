;******************************************************
;                  TPFAST2.ASM 5.22
;           More fast screen writing routines
;     Copyright (c) TurboPower Software 1987, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Data

DATA    SEGMENT BYTE PUBLIC

        ;Pascal variables

        EXTRN   DirectVideo : BYTE              ;If false, use BIOS
        EXTRN   WindMin : WORD                  ;Min. XY coordinates
        EXTRN   WindMax : WORD                  ;Max. XY coordinates
        EXTRN   CurrentPage : BYTE              ;Current video page
        EXTRN   CurrentMode : BYTE              ;Current video mode
        EXTRN   ScreenWidth : BYTE              ;Current width of display
        EXTRN   InTextMode : BYTE               ;False if in graphics mode
        EXTRN   TextAttr : BYTE                 ;Current video attribute
        EXTRN   NormalAttr : BYTE               ;Attribute for NormVideo
        EXTRN   CheckSnow : BYTE                ;If true, check for retrace
        EXTRN   VideoSegment : WORD             ;Segment of Video Memory
        EXTRN   VirtualSegment : WORD           ;Segment of Video Memory--alt
        EXTRN   VirtualWidth : BYTE             ;Current width of virtual display

DATA    ENDS


CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  FastText, FastTextWindow, FastVert, FastVertWindow
        PUBLIC  FastFill, FastFillWindow, FastCenter, FastFlush
        PUBLIC  WriteAttribute, WriteAttributeWindow

        EXTRN   CalcOffset : NEAR               ;in TPFAST.OBJ
        EXTRN   FastWrite : FAR

        EXTRN   MapColor : FAR                  ;Pascal routine

;****************************************************** WriteAttributeWindow

;procedure WriteAttributeWindow(St : String; Row, Col : Byte);
;Write string of attributes St at window Row,Col without changing characters

WriteAttributeWindow    PROC FAR

        MOV     SI,1                    ;Write attributes
        JMP     SHORT FastTextWindowPrim

WriteAttributeWindow    ENDP

;****************************************************** FastTextWindow

;procedure FastTextWindow(St : string; Row, Col : Byte);
;Write St at window Row,Col without changing the underlying video attribute.

FTCol           EQU     BYTE PTR SS:[BX+4]
FTRow           EQU     BYTE PTR SS:[BX+6]
FTStr           EQU     DWORD PTR SS:[BX+8]

FastTextWindow  PROC FAR

        SetZero SI                      ;Write characters

FastTextWindowPrim:

        StackFrame
        MOV     AL,FTRow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FTRow,AL                ;Reload Row
        MOV     AL,FTCol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FTCol,AL                ;Reload Col
        JMP     SHORT FastTextPrim      ;Let FastText do the rest

FastTextWindow  ENDP

;****************************************************** WriteAttribute

;procedure WriteAttribute(St : String; Row, Col : Byte);
;Write string of attributes St at Row,Col without changing characters

WriteAttribute  PROC FAR

        MOV     SI,1                    ;Write attributes
        JMP     SHORT FastTextPrim

WriteAttribute  ENDP

;****************************************************** FastText

;procedure FastText(St : string; Row, Col : Byte);
;Write St at Row,Col without changing the underlying video attribute.

FastText        PROC FAR

        SetZero SI                      ;Write characters

FastTextPrim:

        StackFrame
        PUSH    DS                      ;Save DS
        SetZero AH                      ;AH = 0
        MOV     AL,FTRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FTCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        ADD     DI,SI                   ;adjust for attributes if necessary
        GetDSPtr        FTStr           ;DS:SI points to St[0]
        SetZero CX                      ;CX = 0
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        MOV     CL,AL                   ;CX = Length
        JCXZ    FTExit                  ;If string empty, exit
        SHR     DL,1                    ;If snow checking is off...
        JNC     FTNoWait                ; use FTNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
FTGetNext:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        MOV     AH,AL                   ;Store char in AH
        WaitForRetrace                  ;Wait for an opportunity to write
        MOV     AL,AH                   ;Move char back to AL
        STOSB                           ;And then to screen
        STI                             ;Allow interrupts
        INC     DI                      ;Skip attribute bytes
        LOOP    FTGetNext               ;Get next character
        JMP     SHORT FTExit            ;Done
FTNoWait:
        MOVSB                           ;Move character to screen
        INC DI                          ;Skip attribute bytes
        LOOP    FTNoWait                ;Get next character
FTExit:
        POP     DS                      ;Restore DS
        RET     8

FastText        ENDP

;****************************************************** FastFillWindow

;procedure FastFillWindow(Number : word; Ch : Char; Row, Col, Attr : Byte);
;Write Num Chs using window-relative coordinates

FFAttr          EQU     BYTE PTR SS:[BX+4]
FFCol           EQU     BYTE PTR SS:[BX+6]
FFRow           EQU     BYTE PTR SS:[BX+8]
FFCh            EQU     BYTE PTR SS:[BX+10]
FFNumber        EQU     WORD PTR SS:[BX+12]

FastFillWindow  PROC FAR

        StackFrame
        MOV     AL,FFAttr               ;Load Attribute into AL
        PUSH    AX                      ;PUSH parameter onto stack
        CALL    MapColor                ;Call color mapping routine
        StackFrame                      ;Set up stack frame again
        MOV     FFAttr,AL               ;Reload Attr with mapped attribute
        MOV     AL,FFRow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FFRow,AL                ;Reload Row
        MOV     AL,FFCol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FFCol,AL                ;Reload Col

        ;Let FastFill do the rest

FastFillWindow  ENDP

;****************************************************** FastFill

;procedure FastFill(Number : word; Ch : Char; Row, Col, Attr : Byte);
;Write Num Chs at Row,Col in Attr (video attribute) without snow

FastFill        PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS
        SetZero AH                      ;AH = 0
        MOV     AL,FFRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FFCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        MOV     CX,FFNumber             ;CX = Number to write
        JCXZ    FFExit                  ;If zero, exit
        MOV     AH,FFAttr               ;AH = Attribute
        MOV     AL,FFCh                 ;AL = Char
        SHR     DL,1                    ;If snow checking is off...
        JNC     FFNoWait                ; use FFNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
        MOV     BX,AX                   ;Store video word in BX
FFGetNext:
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BX              ;Move the word
        LOOP    FFGetNext               ;Get next character
        JMP     SHORT FFExit            ;Done
FFNoWait:
        STOSW                           ;Move video word into place
        LOOP    FFNoWait                ;Get next character
FFExit:
        POP     DS                      ;Restore DS
        RET     10

FastFill        ENDP

;****************************************************** FastCenter

;procedure FastCenter(St : String; Row, Attr : Byte);
;Write St centered on window Row in Attr (video attribute) without snow

FCAttr          EQU     BYTE PTR SS:[BX+4]
FCRow           EQU     BYTE PTR SS:[BX+6]
FCSt            EQU     DWORD PTR SS:[BX+8]

FastCenter      PROC FAR

        StackFrame
        GetPtr  FCSt                    ;ES:DI points to St
        SetZero DH                      ;DX = (Length / 2)
        MOV     DL,ES:[DI]
        SHR     DX,1
        SetZero AH                      ;AX = Succ(LeftEdge+RightEdge)/2
        MOV     AL,WindMin.XLow
        ADD     AL,WindMax.XHigh
        INC     AX
        SHR     AX,1
        SUB     AX,DX                   ;AX has column for St
        INC     AX                      ;convert to 1-base

        ;now set up the stack the way FastWrite wants it

        POP     CX                      ;get the return address into DX:CX
        POP     DX
        POP     DI                      ;get the attribute into DI
        POP     BX                      ;get the row into BX
        ADD     BL,WindMin.YLow         ;adjust the row and put it back
        PUSH    BX
        PUSH    AX                      ;push the column for St
        PUSH    DI                      ;put back the attribute and return addr
        PUSH    DX
        PUSH    CX
        JMP     FastWrite               ;let FastWrite do the rest

FastCenter      ENDP

;****************************************************** FastFlush

;procedure FastFlush(St : String; Row, Attr : Byte);
;Write St flush right on window Row in Attr (video attribute) without snow

FastFlush       PROC FAR

        StackFrame
        GetPtr  FCSt                    ;ES:DI points to St
        SetZero DH                      ;DX = Length(St)
        MOV     DL,ES:[DI]
        SetZero AH
        MOV     AL,WindMax.XHigh
        INC     AX                      ;convert to 1-base
        SUB     AX,DX                   ;AX will have column for St
        INC     AX

        ;now set up the stack the way FastWrite wants it

        POP     CX                      ;get the return address into DX:CX
        POP     DX
        POP     DI                      ;get the attribute into DI
        POP     BX                      ;get the row into BX
        ADD     BL,WindMin.YLow         ;adjust the row and put it back
        PUSH    BX
        PUSH    AX                      ;push the column for St
        PUSH    DI                      ;put back the attribute and return addr
        PUSH    DX
        PUSH    CX
        JMP     FastWrite               ;let FastWrite do the rest

FastFlush       ENDP

;****************************************************** FastVertWindow

;procedure FastVertWindow(S : string; Row, Col, Attr : Byte);
;Write a string vertically using window-relative coordinates.

FVAttr          EQU     BYTE PTR SS:[BX+4]
FVCol           EQU     BYTE PTR SS:[BX+6]
FVRow           EQU     BYTE PTR SS:[BX+8]
FVSt            EQU     DWORD PTR SS:[BX+10]

FastVertWindow  PROC FAR

        StackFrame
        MOV     AL,FVAttr               ;Load Attribute into AL
        PUSH    AX                      ;PUSH parameter onto stack
        CALL    MapColor                ;Call color mapping routine
        StackFrame                      ;Set up stack frame again
        MOV     FVAttr,AL               ;Reload Attr with mapped attribute
        MOV     AL,FVRow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FVRow,AL                ;Reload Row
        MOV     AL,FVCol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FVCol,AL                ;Reload Col

        ;Let FastVert do the rest

FastVertWindow  ENDP

;****************************************************** FastVert

;procedure FastVert(St : String; Row, Col, Attr : Byte);
;Write St vertically at Row,Col in Attr (video attribute)

FastVert      PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS
        PUSH    BP                      ;Save BP
        SetZero AH                      ;AH = 0
        MOV     AL,FVRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FVCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        MOV     BP,WP VirtualWidth      ;BP = 2*(ScreenWidth-1) !!.10
        DEC     BP
        SHL     BP,1
        GetDSPtr FVSt                   ;DS:SI points to St[0]
        LODSB                           ;AL = Length(St); DS:SI -> St[1]
        SetZero CH                      ;CH = 0
        MOV     CL,AL                   ;CX = Length
        JCXZ    FVExit                  ;If string empty, exit
        MOV     AH,FVAttr               ;AH = Attribute
        SHR     DL,1                    ;If snow checking is off...
        JNC     FVNoWait                ; use FVNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
FVGetNext:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        MOV     BX,AX                   ;Store video word in BX
        WaitForRetrace                  ;Wait for an opportunity to write
        WordToCGA       BX              ;Move the word
        ADD     DI,BP                   ;Next row
        LOOP    FVGetNext               ;Get next character
        JMP     SHORT FVExit            ;Done
FVNoWait:
        LODSB                           ;Load next character into AL
                                        ; AH already has Attr
        STOSW                           ;Move video word into place
        ADD     DI,BP                   ;Next row
        LOOP    FVNoWait                ;Get next character
FVExit:
        POP     BP                      ;Restore regs
        POP     DS
        RET     10

FastVert        ENDP

CODE    ENDS

        END
