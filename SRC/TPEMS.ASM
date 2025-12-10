;******************************************************
;                   TPEMS.ASM 5.22
;                    EMS routines
;     Copyright (c) TurboPower Software 1987, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Equates

EmsErrorCode    =       0FFFFh

;****************************************************** Macros

EmsCall         MACRO EmsFunction
                MOV     AH,EmsFunction  ;function code into AH
                INT     67h             ;call the EMM
                ENDM

EmsWordResult   MACRO RegName
                LOCAL   EWRexit
                OR      AH,AH           ;AH = 0 means success
                MOV     AX,RegName      ;assume success
                JZ      EWRexit         ;Done if not 0
                MOV     AX,EmsErrorCode ;$FFFF for failure
        EWRExit:
                ENDM

EmsByteResult   MACRO RegName
                LOCAL   EBRexit
                OR      AH,AH           ;AH = 0 means success
                JZ      EWRexit         ;Return value in AL if 0
                SetZero AX              ;Else AL = 0
        EWRExit:
                ENDM

EmsBoolean      MACRO
                LOCAL   EBexit
                CMP     AH,0            ;AH = 0 means success
                MOV     AX,1            ;Assume success
                JE      EBexit          ;Done if OK
                DEC     AX              ;Else AX = 0
        EBexit:
                ENDM

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE

        PUBLIC  EmsStatusOK, EmsPagesAvail, EmsTotalPages, EmsPageFramePtr
        PUBLIC  AllocateEmsPages, MapEmsPage, DeallocateEmsHandle, EmsVersion,
        PUBLIC  SaveEmsContext, RestoreEmsContext, EmsActiveHandles,
        PUBLIC  EmsPagesOwned

;****************************************************** EmsStatusOK

;function EmsStatusOK : Boolean;

;Returns true if the EMM reports its status as being OK.

EmsStatusOK     PROC FAR

        EmsCall 40h                     ;Get manager status function
        EmsBoolean                      ;Set AX
        RET

EmsStatusOK     ENDP

;****************************************************** EmsPagesAvail

;function EmsPagesAvail : Word;

;Returns the number of available pages from the expanded memory manager,
; or EmsErrorCode in case of error.

EmsPagesAvail   PROC FAR

        EmsCall 42h                     ;Get number of pages function
        EmsWordResult   BX              ;If successful, return value in BX
        RET

EmsPagesAvail   ENDP

;****************************************************** EmsTotalPages

;function EmsTotalPages {: Word} ;

;Returns total number of pages of EMS memory, including allocated pages,
;or EmsErrorCode in case of error.

EmsTotalPages   PROC FAR

        EmsCall 42h                     ;Get number of pages function
        EmsWordResult   DX              ;If successful, return value in DX
        RET

EmsTotalPages   ENDP

;****************************************************** EmsPageFramePtr

;function EmsPageFramePtr : Pointer;

;Returns a pointer to the page frame used by the EMM. Returns nil pointer
;in case of error.

EmsPageFramePtr PROC FAR

        EmsCall 41h                     ;Get page frame segment
        OR      AH,AH                   ;Check for error
        MOV     AX,0                    ;Offset is zero in any case
        MOV     DX,BX                   ;Segment from DX to BX
        JZ      FramePtrExit            ;Done if AH = 0
        SetZero DX                      ;Else DX = 0
FramePtrExit:
        RET

EmsPageFramePtr ENDP

;****************************************************** AllocateEmsPages

;function AllocateEmsPages(NumPages : Word) : Word

;Allocates the indicated number of pages and returns a handle.
;Returns EmsErrorCode in case of error.

AllocNum        EQU     WORD PTR SS:[BX+4]

AllocateEmsPages        PROC FAR

        StackFrame
        MOV     BX,AllocNum             ;BX = NumPages
        EmsCall 43h                     ;Get handle and allocate memory
        EmsWordResult   DX              ;If successful, return value in DX
        RET     2

AllocateEmsPages        ENDP

;****************************************************** MapEmsPage

;function MapEmsPage(Handle, LogicalPage, PhysicalPage : Word) : Boolean;

;Maps the specified LogicalPage associated with Handle into PhysicalPage
; (0-3). Returns true if successful.}

MapHandle       EQU     WORD PTR SS:[BX+8]
MapLogPage      EQU     WORD PTR SS:[BX+6]
MapPhysPage     EQU     BYTE PTR SS:[BX+4]

MapEmsPage      PROC FAR

        StackFrame
        MOV     AL,MapPhysPage          ;AL = PhysicalPage
        MOV     DX,MapHandle            ;DX = Handle
        MOV     BX,MapLogPage           ;BX = LogicalPage
        EmsCall 44h                     ;Map memory function
        EmsBoolean                      ;Set AX
        RET     6

MapEmsPage      ENDP

;****************************************************** DeallocateEmsHandle

;function DeallocateEmsHandle(Handle : Word) : Boolean;

;Deallocates the indicated handle and the memory associated with it.

EmsHandle       EQU     WORD PTR SS:[BX+4]

DeallocateEmsHandle     PROC FAR

        StackFrame
        MOV     DX,EmsHandle            ;DX = Handle
        EmsCall 45h                     ;Release handle function
        EmsBoolean                      ;Set AX
        RET     2

DeallocateEmsHandle     ENDP

;****************************************************** EmsVersion

;function EmsVersion : Byte;

;Returns a BCD version number of the EMM handle. To check for version 3.2
;or greater for example, use: 'if EmsVersion >= $32 then'. Returns 0 in
;case of error.

EmsVersion      PROC FAR

        EmsCall 46h                     ;Get EMM version function
        EmsByteResult                   ;Return value in AL
        RET

EmsVersion      ENDP

;****************************************************** SaveEmsContext

;function SaveEmsContext(Handle : Word) : Boolean;

;Saves the EMM context for resident programs. The handle passed must have
;been allocated with a call to AllocateEmsPages. Returns true if
;successful.

SaveEmsContext  PROC FAR

        StackFrame
        MOV     DX,EmsHandle            ;DX = Handle
        EmsCall 47h                     ;Save mapping context function
        EmsBoolean                      ;Set AX
        RET     2

SaveEmsContext  ENDP

;****************************************************** RestoreEmsContext

;function RestoreEmsContext(Handle : Word) : Boolean;

;Restores the mapping context of the EMM driver for the handle specified.
;The handle should the same one used in a prior call to SaveEmsContext.
;Returns true if successful.

RestoreEmsContext       PROC FAR

        StackFrame
        MOV     DX,EmsHandle            ;DX = Handle
        EmsCall 48h                     ;Restore mapping context function
        EmsBoolean                      ;Set AX
        RET     2

RestoreEmsContext       ENDP

;****************************************************** EmsActiveHandles

;function EmsActiveHandles : Word;

;Returns the number of active EMS handles, EmsErrorCode in case of error

EmsActiveHandles        PROC FAR

        EmsCall 4Bh                     ;Get number of EMM handles
        EmsWordResult   BX              ;If successful, return value in BX
        RET

EmsActiveHandles        ENDP


;****************************************************** EmsPagesOwned

;function EmsPagesOwned(Handle : Word) : Word;

;Returns the number of pages owned by Handle, or EmsErrorCode in case of error.

EmsPagesOwned   PROC FAR

        StackFrame
        MOV     DX,EmsHandle            ;DX = Handle
        EmsCall 4Ch                     ;Get pages owned by handle function
        EmsWordResult   BX              ;If successful, return value in BX
        RET     2

EmsPagesOwned   ENDP

CODE    ENDS

        END
