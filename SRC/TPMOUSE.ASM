;******************************************************
;                  TPMOUSE.ASM 5.22
;              Mouse support routines
;     Copyright (c) TurboPower Software 1988, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Data

DATA    SEGMENT BYTE PUBLIC

        ;Pascal variables

        EXTRN   ScreenHeight : BYTE     ;Current height of display
        EXTRN   ScreenWidth : BYTE      ;Current width of display

        EXTRN   MouseInstalled : BYTE   ;set to True if mouse installed
        EXTRN   MouseCursorOn : BYTE    ;keeps tracks of mouse cursor visibility

        EXTRN   MouseXLo : BYTE         ;coordinates for mouse window
        EXTRN   MouseXHi : BYTE
        EXTRN   MouseYLo : BYTE
        EXTRN   MouseYHi : BYTE

        EXTRN   MouseRoutine : DWORD    ;user's event handler
        EXTRN   MouseRoutineEvent : BYTE
        EXTRN   EventHandlerInstalled : BYTE

        EXTRN   MouseEvent : BYTE       ;last mouse event
        EXTRN   MouseStatus : BYTE      ;last button status
        EXTRN   MouseLastX : BYTE       ;last horizontal coordinate
        EXTRN   MouseLastY : BYTE       ;last vertical coordinate

DATA    ENDS

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE,DS:DATA

        PUBLIC  InitializeMouse, ShowMousePrim, HideMousePrim
        PUBLIC  MouseWhereXY, MouseWhereX, MouseWhereY, MouseGotoXY
        PUBLIC  MouseButtonPressed, MouseButtonReleased
        PUBLIC  MouseWindow, SoftMouseCursor, HardMouseCursor
        PUBLIC  GetMousePage, SetMousePage
        PUBLIC  MouseEventPrim, MouseEventHandler
        PUBLIC  GetMickeyCount, SetMickeyToPixelRatio
        PUBLIC  GetStorageSize, SaveMouseStatePrim, RestoreMouseStatePrim

;****************************************************** Macros

MouseCall       MACRO   Function
                MOV     AX,Function     ;function code into AX
                INT     33h             ;call the mouse driver
                ENDM

CheckMouse      MACRO   PopCount
                LOCAL OK
                CMP     MouseInstalled,True
                JE      OK
                XOR     AX,AX           ;return 0 in AX
                RET     PopCount        ;return
        OK:
                ENDM

;****************************************************** MouseEventPrim

;procedure MouseEventPrim(EventMask : MouseEventType;
;                         UserRoutine : Pointer); external;

;Specify the address of a routine to be called when certain mouse events occur

EventMask       EQU WORD PTR [BP+10]
UserRoutine     EQU DWORD PTR [BP+6]

MouseEventPrim  PROC FAR

        CheckMouse 6            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     CX,EventMask
        LES     DX,UserRoutine
        MouseCall 12            ;Set User-Defined Subroutine Input Mask
        Exit_Code 6             ;!!.12

MouseEventPrim  ENDP

;****************************************************** MouseEventHandler

;procedure MouseEventHandler;

MouseEventHandler       PROC FAR

        PUSH    AX              ;save all registers
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES
        PUSH    BP

        MOV     SI,SEG DATA     ;set up our DS
        MOV     DS,SI

        ;store event information in global variables
        PUSH    AX              ;save event info
        CMP     AL,1            ;MouseMoved event only?         !!.21
        JE      mehMouseMoved   ;jump if so                     !!.21
        AND     AL,11111110b    ;clear MouseMoved bit if not    !!.21
mehMouseMoved:                  ;                               !!.21
        MOV     MouseEvent,AL   ;save the event mask in MouseEvent
        MOV     MouseStatus,BL  ;save the button status in MouseStatus
        MOV     AX,CX           ;scale last horizontal coordinate
        CALL    ScaleDownX
        MOV     MouseLastX,AL   ;save last horizontal in MouseLastX
        MOV     AX,DX           ;scale last vertical coordinate
        CALL    ScaleDownY
        MOV     MouseLastY,AL   ;save last vertical in MouseLastY
        POP     AX              ;restore event info

        TEST    AL,MouseRoutineEvent    ;is this an event they're interested in?
        JZ      mehExit         ;if not, don't call them

        LES     DI,MouseRoutine ;ES:DI = MouseRoutine
        MOV     SI,ES           ;SI has segment, DI has offset
        OR      SI,DI           ;MouseRoutine = nil?
        JZ      mehExit         ;if so, exit

        ;MouseRoutine not nil, so call it
        CallFar MouseRoutine    ;call user-written event handler

mehExit:
        POP     BP              ;restore registers
        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX
        RET                     ;and do a FAR return

MouseEventHandler       ENDP

;****************************************************** InitializeMouse

;procedure InitializeMouse;

;Reinitializes mouse and sets MouseInstalled.

InitializeMouse PROC FAR

        MOV     MouseCursorOn,False     ;reset cursor flag
        MOV     MouseInstalled,False    ;assume failure
        MOV     EventHandlerInstalled,False     ;no event handler installed
        MOV     MouseRoutine.Segm,0     ;reset our event variables
        MOV     MouseRoutine.Ofst,0
        MOV     MouseRoutineEvent,0
        MOV     MouseEvent,0
        MOV     MouseStatus,0

        MOV     AX,3533h                ;Get INT 33 vector
        INT     21h                     ;call DOS
        MOV     AX,ES                   ;is vector nil?
        OR      BX,AX
        JZ      MIexit                  ;if so, no mouse

        MouseCall 0                     ;Mouse Installed Flag and Reset function
        CMP     AX,-1                   ;function returns 0 if not installed, else -1
        JNE     MIexit
        INC     MouseInstalled          ;it's installed

MIexit:
        RET

InitializeMouse ENDP

;****************************************************** ShowMousePrim

;procedure ShowMousePrim;
;Show the mouse cursor.

ShowMousePrim   PROC FAR

        CheckMouse 0            ;make sure mouse is installed
        MOV     MouseCursorOn,True
        MouseCall 1             ;Show Cursor function
        RET

ShowMousePrim   ENDP

;****************************************************** HideMousePrim

;procedure HideMousePrim;
;Hide the mouse cursor.

HideMousePrim   PROC FAR

        MOV     MouseCursorOn,False
        CheckMouse 0            ;make sure mouse is installed
        MouseCall 2             ;Hide Cursor function
        RET

HideMousePrim   ENDP

;****************************************************** ScaleUpY

;on entry, BL has a screen row coordinate to be scaled into the mouse's
;  coordinate system
;on exit, AX has the result

ScaleUpY        PROC NEAR

        DEC     BL              ;convert to 0-based number
        MOV     AL,8            ;get scaling factor into AL
        MUL     BL              ;multiply by coordinate in BL
        RET

ScaleUpY        ENDP

;****************************************************** ScaleUpX

;on entry, BL has a screen column coordinate to be scaled into the mouse's
;  coordinate system
;on exit, AX has the result

ScaleUpX        PROC NEAR

        DEC     BL              ;convert to 0-based number
        MOV     AL,8            ;get scaling factor into AL
        CMP     ScreenWidth,80
        JAE     suxGo
        MOV     AL,16
suxGo:
        MUL     BL              ;multiply by coordinate in BL
        RET

        RET

ScaleUpX        ENDP

;****************************************************** ScaleDownY

;on entry, AX has a number in the mouse's coordinate system that needs to be
;  scaled down to a screen row coordinate
;on exit, AL has the result

ScaleDownY      PROC NEAR

        PUSH    BX              ;save BX
        CMP     AX,0            ;check for > 0
        JG      sdyOK
        MOV     AL,MouseYLo     ;force it to a valid range
        JMP     SHORT sdyExit
sdyOK:
        MOV     BL,8            ;get scaling factor into BL
        DIV     BL              ;divide coordinate by scaling factor
sdyExit:
        SUB     AL,MouseYLo     ;make it relative to current window
        INC     AL              ;convert to 1-based number
        POP     BX              ;restore BX
        RET

ScaleDownY      ENDP

;****************************************************** ScaleDownX

;on entry, AX has a number in the mouse's coordinate system that needs to be
;  scaled down to a screen column coordinate
;on exit, AL has the result

ScaleDownX      PROC NEAR

        PUSH    BX              ;save BX
        CMP     AX,0            ;check for > 0
        JG      sdxOK
        MOV     AL,MouseXLo     ;force it to a valid range
        JMP     SHORT sdxExit
sdxOK:
        MOV     BL,8            ;get scaling factor into BL
        CMP     ScreenWidth,80
        JAE     sdxGo
        MOV     BL,16
sdxGo:
        DIV     BL              ;divide coordinate by scaling factor
sdxExit:
        SUB     AL,MouseXLo     ;make it relative to current window
        INC     AL              ;convert to 1-based number
        POP     BX              ;restore BX
        RET

ScaleDownX      ENDP

;****************************************************** MouseWhereXY

;procedure MouseWhereXY(var MouseX, MouseY : Byte; var Status : ButtonStatus);

;Returns mouse position and button status.

MouseXvar       EQU DWORD PTR [BP+14]
MouseYvar       EQU DWORD PTR [BP+10]
StatusVar       EQU DWORD PTR [BP+6]

MouseWhereXY    PROC FAR

        CheckMouse 12           ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MouseCall 3             ;Get Mouse Position and Button Status
        MOV     AL,BL           ;button status returned in BX
        LES     DI,StatusVar    ;put it in StatusVar
        STOSB
        MOV     AX,CX           ;X position returned in CX
        CALL    ScaleDownX      ;scale it and put it in MouseX
        LES     DI,MouseXvar
        STOSB
        MOV     AX,DX           ;Y position returned in DX
        CALL    ScaleDownY      ;scale it and put it in MouseY
        LES     DI,MouseYvar
        STOSB
        Exit_Code 12            ;!!.12

MouseWhereXY    ENDP

;****************************************************** MouseWhereX

MouseWhereX     PROC FAR

        CheckMouse 0            ;make sure mouse is installed
        MouseCall 3             ;Get Mouse Position and Button Status
        MOV     AX,CX           ;X position returned in CX
        CALL    ScaleDownX      ;scale it
        MOV     MouseLastX,AL   ;save in MouseLastX
        RET

MouseWhereX     ENDP

;****************************************************** MouseWhereY

MouseWhereY     PROC FAR

        CheckMouse 0            ;make sure mouse is installed
        MouseCall 3             ;Get Mouse Position and Button Status
        MOV     AX,DX           ;Y position returned in DX
        CALL    ScaleDownY      ;scale it
        MOV     MouseLastY,AL   ;save in MouseLastY
        RET

MouseWhereY     ENDP

;****************************************************** MouseGotoXY

;procedure MouseGotoXY(MouseX, MouseY : Byte);

;Set mouse position

MouseX  EQU BYTE PTR [BP+8]
MouseY  EQU BYTE PTR [BP+6]

MouseGotoXY     PROC FAR

        CheckMouse 4            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame

        MOV     CL,MouseY       ;check the Y coordinate
        ADD     CL,MouseYLo     ;make it relative to current window
        CMP     CL,MouseYHi     ;is it inside the window?
        JA      mgxyExit

        MOV     BL,MouseX       ;check the X coordinate
        ADD     BL,MouseXLo     ;make it relative to current window
        CMP     BL,MouseXHi     ;is it inside the window?
        JA      mgxyExit

        CALL    ScaleUpX        ;load scaled X position into AX
        MOV     BL,CL           ;MouseY coordinate into BL
        MOV     CX,AX           ;scaled X position into CX

        CALL    ScaleUpY        ;load scaled Y position into DX
        MOV     DX,AX
        MouseCall 4             ;Set Mouse Cursor Position

        CALL    MouseWhereX     ;update MouseLastX and MouseLastY
        CALL    MouseWhereY
mgxyExit:
        Exit_Code 4             ;!!.12

MouseGotoXY     ENDP

;****************************************************** MouseButtonPressed

;function MouseButtonPressed(Button : ButtonStatus; var Count : Word;
;                            var LastX, LastY : Byte) : Boolean;

;Returns True if the Button to check has been pressed. If so, Count has the
; number of times it has been pressed, and LastX/LastY have its position the
; last time it was pressed.

Button  EQU BYTE PTR [BP+18]
Count   EQU DWORD PTR [BP+14]
LastX   EQU DWORD PTR [BP+10]
LastY   EQU DWORD PTR [BP+06]

MouseButtonPressed      PROC FAR

        CheckMouse 14           ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     BL,Button       ;BX has Button to check
        DEC     BL              ;!!.06
        SetZero BH
        MouseCall 5             ;Get Button Press Information
        LES     DI,Count        ;BX has count of button presses
        MOV     ES:[DI],BX
        PUSH    BX              ;save count                !!.06
        MOV     AX,CX           ;CX has last X position
        CALL    ScaleDownX      ;scale it and put it in LastX
        LES     DI,LastX
        STOSB
        MOV     AX,DX           ;DX has last Y position
        CALL    ScaleDownY      ;scale it and put it in LastY
        LES     DI,LastY
        STOSB
        POP     BX              ;restore count
        SetZero AL              ;assume false
        OR      BX,BX           ;has the Button been pressed? !!.06
        JZ      mbcExit
        INC     AL
mbcExit:
        Exit_Code 14            ;!!.12

MouseButtonPressed      ENDP

;****************************************************** MouseButtonReleased

;function MouseButtonReleased(Button : ButtonStatus; var Count : Word;
;                            var LastX, LastY : Byte) : Word;

;Returns True if the Button to check has been released. If so, Count has the
;  number of times it has been released, and LastX/LastY have its position the
;  last time it was released.

MouseButtonReleased     PROC FAR

        CheckMouse 14           ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     BL,Button       ;BX has Button to check
        DEC     BL              ;!!.06
        SetZero BH
        MouseCall 6             ;Get Button Release Information
        LES     DI,Count        ;BX has count of button releases
        MOV     ES:[DI],BX
        PUSH    BX              ;save count                   !!.06
        MOV     AX,CX           ;CX has last X position
        CALL    ScaleDownX      ;scale it and put it in LastX
        LES     DI,LastX
        STOSB
        MOV     AX,DX           ;DX has last Y position
        CALL    ScaleDownY      ;scale it and put it in LastY
        LES     DI,LastY
        STOSB
        POP     BX              ;restore count
        SetZero AL              ;assume false
        OR      BX,BX           ;has the Button been released? !!.06
        JZ      mbrExit
        INC     AL
mbrExit:
        Exit_Code 14            ;!!.12

MouseButtonReleased     ENDP

;****************************************************** MouseWindow

;procedure MouseWindow(XLow, YLow, XHigh, YHigh : Byte);
;Sets window coordinates to be observed by the mouse

XLo     EQU BYTE PTR [BP+12]
YLo     EQU BYTE PTR [BP+10]
XHi     EQU BYTE PTR [BP+8]
YHi     EQU BYTE PTR [BP+6]

MouseWindow     PROC FAR

        CheckMouse 8            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame

        ;validate all parameters BEFORE setting any window coordinates
        MOV     BL,XLo          ;BL = XLo-1
        DEC     BL
        MOV     BH,XHi          ;BH = XHi-1
        DEC     BH
        CMP     BL,BH           ;XLo > XHi?
        JA      mwDone
        CMP     BH,ScreenWidth  ;XHi > ScreenWidth?
        JAE     mwDone
        MOV     AL,YLo          ;AL = YLo-1
        DEC     AL
        MOV     AH,YHi          ;AH = YHi-1
        DEC     AH
        CMP     AL,AH           ;YLo > YHi?
        JA      mwDone
        CMP     AH,ScreenHeight ;YHi > ScreenHeight?
        JAE     mwDone

        MOV     MouseXLo,BL     ;save 0-based coordinates for mouse window
        MOV     MouseYLo,AL

        INC     BH              ;save 1-based coordinates for mouse window
        MOV     MouseXHi,BH
        INC     AH
        MOV     MouseYHi,AH

        INC     BL              ;BL = XLo
        CALL    ScaleUpX        ;scale the XLow param (in BL) and put in CX
        MOV     CX,AX
        MOV     BL,XHi          ;scale the XHigh param and put in DX
        CALL    ScaleUpX
        MOV     DX,AX
        MouseCall 7             ;Set Minimum and Maximum Horizontal Position

        MOV     BL,YLo          ;scale the YLow param and put in CX
        CALL    ScaleUpY
        MOV     CX,AX
        MOV     BL,YHi          ;scale the YHigh param and put in DX
        CALL    ScaleUpY
        MOV     DX,AX
        MouseCall 8             ;Set Minimum and Maximum Vertical Position
mwDone:
        Exit_Code 8             ;!!.12

MouseWindow     ENDP

;****************************************************** SoftMouseCursor

;procedure SoftMouseCursor(ScreenMask, CursorMask : Word);

;Set mouse to use a software cursor.

SoftMouseCursor:
        SetZero BX              ;select software cursor
        JMP     SHORT hmcEntry  ;rest is same as HardMouseCursor

;****************************************************** HardMouseCursor

;procedure HardMouseCursor(StartLine, EndLine : Word);

;Set mouse to use the hardware cursor. StartLine and EndLine specify the
;shape of the cursor.

Arg1            EQU WORD PTR [BP+8]
Arg2            EQU WORD PTR [BP+6]

HardMouseCursor PROC FAR

        MOV     BX,1            ;select hardware cursor

hmcEntry:
        CheckMouse 4            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     CX,Arg1
        MOV     DX,Arg2
        MouseCall 10            ;Set Text Cursor
        Exit_Code 4             ;!!.12

HardMouseCursor  ENDP

;****************************************************** GetMickeyCount

;procedure GetMickeyCount(var Horizontal, Vertical : Integer);

;Returns the horizontal and vertical mickey count since the last call to this
;function.

gmcHoriz        EQU DWORD PTR [BP+10]
gmcVert         EQU DWORD PTR [BP+6]

GetMickeyCount  PROC FAR

        CheckMouse 8            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MouseCall 11            ;Read Mouse Motion Counters
        LES     DI,gmcHoriz
        MOV     ES:[DI],CX
        LES     DI,gmcVert
        MOV     ES:[DI],DX
        Exit_Code 8             ;!!.12

GetMickeyCount  ENDP

;****************************************************** SetMickeyToPixelRatio

;procedure SetMickeyToPixelRatio(Horizontal, Vertical : Integer);

;Sets the mickey-to-pixel ratio

mtpHoriz        EQU WORD PTR [BP+8]
mtpVert         EQU WORD PTR [BP+6]

SetMickeyToPixelRatio   PROC FAR

        CheckMouse 4            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     AX,7FFFh        ;for masking out the high bit
        MOV     CX,mtpHoriz     ;CX has horixontal mickeys
        AND     CX,AX
        MOV     DX,mtpVert      ;DX has vertical mickeys
        AND     DX,AX
        MouseCall 15            ;Set Mickey/Pixel Ratio
        Exit_Code 4             ;!!.12

SetMickeyToPixelRatio   ENDP

;****************************************************** GetStorageSize

;function GetStorageSize : Word;
;Returns amount of memory needed to save state of mouse driver

GetStorageSize  PROC FAR

        CheckMouse 0            ;make sure mouse is installed
        SetZero BX              ;set BX to 0       !!.10
        MouseCall 21            ;Query Save-State Storage Size
        MOV     AX,BX           ;size returned in BX
        RET

GetStorageSize  ENDP

;****************************************************** SaveMouseStatePrim

;procedure SaveMouseStatePrim(var Buffer);

;Save mouse state in Buffer

Buffer  EQU DWORD PTR [BP+6]

SaveMouseStatePrim      PROC FAR

        CheckMouse 4            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        LES     DX,Buffer       ;ES:DX points to buffer
        MouseCall 22            ;Save Mouse Driver State
        Exit_Code 4             ;!!.12

SaveMouseStatePrim      ENDP

;****************************************************** RestoreMouseStatePrim

;procedure RestoreMouseStatePrim(var Buffer);

;Restore mouse state from Buffer

RestoreMouseStatePrim   PROC FAR

        CheckMouse 4            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        LES     DX,Buffer       ;ES:DX points to buffer
        MouseCall 23            ;Restore Mouse Driver State
        Exit_Code 4             ;!!.12

RestoreMouseStatePrim   ENDP

;****************************************************** SetMousePage

;procedure SetMousePage(Page : Byte);
;Sets the video page where the mouse will be displayed

PageNum EQU BYTE PTR [BP+6]

SetMousePage    PROC FAR

        CheckMouse 2            ;make sure mouse is installed
        StackFrameBP            ;set up stack frame
        MOV     BL,PageNum      ;BX has page number
        SetZero BH
        MouseCall 29            ;Set CRT Page Number
        Exit_Code 2             ;!!.12

SetMousePage    ENDP

;****************************************************** GetMousePage

;function GetMousePage : Byte;
;Returns the video page where the mouse is being displayed

GetMousePage    PROC FAR

        CheckMouse 0            ;make sure mouse is installed
        MouseCall 30            ;Get CRT Page Number
        MOV     AX,BX           ;page returned in BX
        RET

GetMousePage    ENDP

CODE    ENDS
        END
