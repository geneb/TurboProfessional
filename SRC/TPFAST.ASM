;******************************************************
;                  TPFAST.ASM 5.22
;             Fast screen writing routines
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
        EXTRN   InTextMode : BYTE               ;False if in graphics mode
        EXTRN   TextAttr : BYTE                 ;Current video attribute
        EXTRN   NormalAttr : BYTE               ;Attribute for NormVideo
        EXTRN   CheckSnow : BYTE                ;If true, check for retrace
        EXTRN   VideoSegment : WORD             ;Segment of Video Memory
        EXTRN   VirtualSegment : WORD           ;Segment of Video Memory--alt
        EXTRN   VirtualWidth : BYTE             ;Current width of virtual display

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE, DS:DATA

        PUBLIC  CalcOffset
        PUBLIC  FastWrite, FastWriteWindow, FastRead, FastReadWindow
        PUBLIC  ReadAttribute, ReadAttributeWindow
        PUBLIC  ChangeAttribute, ChangeAttributeWindow, MoveScreen

        EXTRN   MapColor : FAR                  ;Pascal routine

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

;****************************************************** FastWriteWindow

;procedure FastWriteWindow(S : string; Row, Col, Attr : Byte);
;Write a string using window-relative coordinates.

FWAttr          EQU     BYTE PTR SS:[BX+4]
FWCol           EQU     BYTE PTR SS:[BX+6]
FWRow           EQU     BYTE PTR SS:[BX+8]
FWSt            EQU     DWORD PTR SS:[BX+10]

FastWriteWindow PROC FAR

        StackFrame
        MOV     AL,FWAttr               ;Load Attribute into AL
        PUSH    AX                      ;PUSH parameter onto stack
        CALL    MapColor                ;Call color mapping routine
        StackFrame                      ;Set up stack frame again
        MOV     FWAttr,AL               ;Reload Attr with mapped attribute
        MOV     AL,FWRow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FWRow,AL                ;Reload Row
        MOV     AL,FWCol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FWCol,AL                ;Reload Col

        ;Let FastWrite do the rest

FastWriteWindow ENDP

;****************************************************** FastWrite

;procedure FastWrite(St : String; Row, Col, Attr : Byte);
;Write St at Row,Col in Attr (video attribute) without snow

FastWrite     PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS
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
        MOV     AH,FWAttr               ;AH = Attribute
        SHR     DL,1                    ;If snow checking is off...
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

FastWrite       ENDP

;****************************************************** ReadAttributeWindow

;procedure ReadAttributeWindow(Number, Row, Col : Byte; var St : string);
;Read Number attributes from the screen into St starting at Row,Col

ReadAttributeWindow     PROC FAR

        MOV     SI,1                    ;Read attributes
        JMP     SHORT FastReadWindowPrim

ReadAttributeWindow     ENDP

;****************************************************** FastReadWindow

;procedure FastReadWindow(Number, Row, Col : Byte; var St : string);
;Read Number bytes from the screen into St starting at Row,Col without snow

FRSt    EQU     DWORD PTR SS:[BX+4]
FRCol   EQU     BYTE PTR SS:[BX+8]
FRRow   EQU     BYTE PTR SS:[BX+10]
FRNum   EQU     BYTE PTR SS:[BX+12]

FastReadWindow  PROC FAR

        SetZero SI                      ;Read characters

FastReadWindowPrim:

        StackFrame
        MOV     AL,FRRow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     FRRow,AL                ;Reload Row
        MOV     AL,FRCol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     FRCol,AL                ;Reload Col
        JMP     SHORT FastReadPrim      ;Let FastRead do the rest

FastReadWindow  ENDP

;****************************************************** ReadAttribute

;procedure ReadAttribute(Number, Row, Col : Byte; var St : string);
;Read Number attributes from the screen into St starting at Row,Col

ReadAttribute   PROC FAR

        MOV     SI,1                    ;Read attributes
        JMP     SHORT FastReadPrim

ReadAttribute   ENDP

;****************************************************** FastRead

;procedure FastRead(Number, Row, Col : Byte; var St : string);
;Read Number characters from the screen into St starting at Row,Col

FastRead      PROC FAR

        SetZero SI                      ;Read characters

FastReadPrim:

        StackFrame
        PUSH    DS                      ;Save DS
        SetZero AH                      ;AH = 0
        MOV     AL,FRRow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,FRCol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        ADD     DI,SI                   ;adjust for attributes if necessary
        MOV     DS,CX                   ;CX still has VideoSegment
        MOV     SI,DI                   ;DS:SI points to VideoSegment:Row,Col
        GetPtr  FRSt                    ;ES:DI points to St[0]
        SetZero AH                      ;AH = 0
        MOV     AL,FRNum                ;AX = number of bytes to read
        STOSB                           ;Set length byte
        MOV     CX,AX                   ;CX = Length
        JCXZ    FRExit                  ;If string empty, exit
        SHR     DL,1                    ;If snow checking is off...
        JNC     FRNoWait                ; use FWNoWait routine
        MOV     DX,03DAh                ;Point DX to CGA status port
FRGetNext:
        WaitForRetrace                  ;Wait for an opportunity
        LODSB                           ;Load next char into AX
        STI                             ;Allow interrupts
        STOSB                           ;Store the character in St
        INC     SI                      ;Skip attribute
        LOOP    FRGetNext               ;Get next character
        JMP     SHORT FRExit            ;Done
FRNoWait:
        LODSB                           ;Load next byte into AL  !!.22
        INC     SI                      ;Skip over unused byte   !!.22
;!!.22  LODSW                           ;Load next word into AX
        STOSB                           ;Move character into St
        LOOP    FRNoWait                ;Get next character
FRExit:
        POP     DS                      ;Restore DS
        RET     10

FastRead      ENDP

;****************************************************** ChangeAttributeWindow

;procedure ChangeAttributeWindow(Number : Word; Row, Col, Attr : Byte);
;Change Number video attributes to Attr starting at Row,Col

CAAttr          EQU     BYTE PTR SS:[BX+4]
CACol           EQU     BYTE PTR SS:[BX+6]
CARow           EQU     BYTE PTR SS:[BX+8]
CANumber        EQU     WORD PTR SS:[BX+10]

ChangeAttributeWindow   PROC FAR

        StackFrame
        MOV     AL,CAAttr               ;Load Attribute into AL
        PUSH    AX                      ;PUSH parameter onto stack
        CALL    MapColor                ;Call color mapping routine
        StackFrame                      ;Set up stack frame again
        MOV     CAAttr,AL               ;Reload Attr with mapped attribute
        MOV     AL,CARow                ;AL = Row
        ADD     AL,WindMin.YLow         ;Adjust for current window
        MOV     CARow,AL                ;Reload Row
        MOV     AL,CACol                ;AL = Col
        ADD     AL,WindMin.XLow         ;Adjust for current window
        MOV     CACol,AL                ;Reload Col

        ;let ChangeAttribute do the rest

ChangeAttributeWindow   ENDP

;****************************************************** ChangeAttribute

;procedure ChangeAttribute(Number : Word; Row, Col, Attr : Byte);
;Change Number video attributes to Attr starting at Row,Col

ChangeAttribute       PROC FAR

        StackFrame
        SetZero AH                      ;AH = 0
        MOV     AL,CARow                ;AX = Row
        SetZero CH                      ;CH = 0
        MOV     CL,CACol                ;CX = Column
        MOV     DI,CX                   ;DI = Column
        CALL    CalcOffset              ;Call routine to calculate offset
        INC     DI                      ;Skip character
        MOV     AL,CAAttr               ;AL = Attribute
        MOV     CX,CANumber             ;CX = Number to change
        JCXZ    CAExit                  ;If zero, exit
        SHR     DL,1                    ;If snow checking is off...
        JNC     CANoWait                ; use CANoWait routine
        MOV     AH,AL                   ;Store attribute in AH
        MOV     DX,03DAh                ;Point DX to CGA status port
CAGetNext:
        WaitForRetrace                  ;Wait for an opportunity to write
        MOV     AL,AH                   ;Move Attr back to AL...
        STOSB                           ; and then to screen
        STI                             ;Allow interrupts
        INC     DI                      ;Skip characters
        LOOP    CAGetNext               ;Look for next opportunity
        JMP     SHORT CAExit            ;Done
CANoWait:
        STOSB                           ;Change the attribute
        INC     DI                      ;Skip characters
        LOOP    CANoWait                ;Get next character
CAExit:
        RET     8

ChangeAttribute       ENDP

;****************************************************** MoveScreen

;procedure MoveScreen(var Source, Dest; Length : Word);
;Move Length words from Source to Dest without snow

MLength         EQU     WORD PTR SS:[BX+4]
MDest           EQU     DWORD PTR SS:[BX+6]
MSource         EQU     DWORD PTR SS:[BX+10]

MoveScreen      PROC FAR

        StackFrame
        PUSH    DS                      ;Save DS
        SetZero AH                      ;AH = 0
        MOV     AL,CheckSnow            ;Grab before changing DS
        GetPtr          MDest           ;ES:DI points to Dest
        GetDSPtr        MSource         ;DS:SI points to Source
        MOV     CX,MLength              ;CX = Length
        JCXZ    MSExit                  ;Exit if CX = 0
        CLD                             ;Assume forward
        MOV     BX,DS                   ;BX = DS
        MOV     DX,ES                   ;DX = ES
        CMP     DX,BX                   ;Same segment?
        MOV     BL,0                    ;Clear same-segment flag
        JNE     MSForward               ;If not, go forward
        INC     BL                      ;Set same-segment flag
        CMP     SI,DI                   ;Check for potential overlap
        JAE     MSForward               ;Go forward if Source at higher offset

        STD                             ;Go backwards
        DEC     CX                      ;CX = Number of words to add to SI/DI
        ADD     DI,CX                   ;Point DI to end of Dest area
        ADD     DI,CX
        ADD     SI,CX                   ;Point SI to end of Source area
        ADD     SI,CX
        INC     CX                      ;Reset CX
        INC     AH                      ;Flag to indicate we're going backward

MSForward:
        SHR     AL,1                    ;Snow checking on?
        JNC     MSNoWait                ;Skip the rest of this if not
        CMP     BH,0B8h                 ;See if we're reading from CGA memory
        JE      MSGetNext               ;If so, wait for retrace
        CMP     DH,0B8h                 ;Check segment in ES, too
        JNE     MSNoWait                ;Not writing to CGA
MSGetNext:
        MOV     DX,03DAh                ;Point DX to CGA status port

IF SuppressAllSnow
        OR      AH,AH                   ;Going forward?
        JZ      MSgo                    ;If so, continue
        INC     SI                      ;Else, point SI/DI to last byte, rather
        INC     DI                      ; than the last word
ELSE
        ;see if we can use a faster algorithm
        OR      BL,BL                   ;is same-segment flag set?
        JNZ     MSgo                    ;if so, use WordMoveNoSnow algorithm
        FastMoveNoSnow                  ;else, use faster algorithm
        JMP     SHORT MSExit
ENDIF

MSgo:
        WordMoveNoSnow                  ;Move CX words, preventing snow
        JMP     SHORT MSExit            ;All done
MSNoWait:
        REP     MOVSW                   ;That's all!
MSExit:
        CLD                             ;Reset direction flag
        POP     DS                      ;Restore DS
        RET     10

MoveScreen      ENDP

CODE    ENDS

        END
