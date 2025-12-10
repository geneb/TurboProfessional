;******************************************************
;                  TPSEARCH.ASM 5.22
;              String handling routines
;     Copyright (c) TurboPower Software 1987, 1992.
; Portions Copyright (c) Sunny Hill Software 1985, 1986
;     and used under license to TurboPower Software
;                All rights reserved.
;******************************************************

        INCLUDE TPCOMMON.ASM

;****************************************************** Code

CODE    SEGMENT BYTE PUBLIC

        ASSUME  CS:CODE

        PUBLIC  Search, SearchUC

        EXTRN   UpCasePrim : FAR

UpcaseAL        MACRO                   ;UpCase character in AL
                PUSH    BX
                CALL    UpCasePrim
                POP     BX
                ENDM

UpcaseAH        MACRO                   ;UpCase character in AL
                XCHG    AL,AH
                UpcaseAL
                XCHG    AH,AL
                ENDM


;****************************************************** Search

;function Search(var Buffer; BufLength : Word;
;                var Match;  MatLength : Word) : Word;

;Search through Buffer for Match.
;BufLength is length of range to search.
;MatLength is length of string to match.
;Returns number of bytes searched to find Match, 0FFFFh if not found.

;equates for parameters:
MatLength       EQU     WORD PTR [BP+6]
Match           EQU     DWORD PTR [BP+8]
BufLength       EQU     WORD PTR  [BP+12]
Buffer          EQU     DWORD PTR [BP+14]

Search  PROC FAR

        StackFrameBP
        PUSH    DS                      ;Save DS
        CLD                             ;Go forward

        LES     DI,Buffer               ;ES:DI => Buffer
        MOV     BX,DI                   ;BX = Ofs(Buffer)

        MOV     CX,BufLength            ;CX = Length of range to scan
        MOV     DX,MatLength            ;DX = Length of match string

        TEST    DX,DX                   ;Length(Match) = 0?
        JZ      Error                   ;If so, we're done

        LDS     SI,Match                ;DS:SI => Match buffer
        LODSB                           ;AL = Match[1]; DS:SI => Match[2]
        DEC     DX                      ;DX = MatLength-1
        SUB     CX,DX                   ;CX = BufLength-(MatLength-1)
        JBE     Error                   ;Error if BufLength is less

;Search for first character in Match
Next:   REPNE   SCASB                   ;Search forward for Match[1]
        JNE     Error                   ;Done if not found
        TEST    DX,DX                   ;If Length = 1 (DX = 0) ...
        JZ      Found                   ; the "string" was found

        ;Search for remainder of Match

        PUSH    CX                      ;Save CX
        PUSH    DI                      ;Save DI
        PUSH    SI                      ;Save SI

        MOV     CX,DX                   ;CX = Length(Match) - 1
        REPE    CMPSB                   ;Does rest of string match?

        POP     SI                      ;Restore SI
        POP     DI                      ;Restore DI
        POP     CX                      ;Restore CX

        JNE     Next                    ;Try again if no match

;Calculate number of bytes searched and return
Found:  DEC     DI                      ;DX = Offset where found
        MOV     AX,DI                   ;AX = Offset where found
        SUB     AX,BX                   ;Subtract starting offset
        JMP     SHORT SDone             ;Done

;Match was not found
Error:  XOR     AX,AX                   ;Return
        DEC     AX                      ;Return FFFF

SDone:  POP     DS                      ;Restore DS
        Exit_Code 12                    ;!!.12

Search  ENDP

;****************************************************** SearchUC

;function SearchUC(var Buffer; BufLength : Word;
;                  var Match;  MatLength : Word) : Word;

;Search through Buffer for Match (CASE-INSENSITIVE)
;BufLength is length of range to search.
;MatLength is length of string to match.
;Returns number of bytes searched to find Match, 0FFFFh if not found.

SearchUC  PROC FAR

        StackFrameBP
        PUSH    DS                      ;Save DS
        CLD                             ;Go forward

        LES     DI,Buffer               ;ES:DI => Buffer
        MOV     BX,DI                   ;BX = Ofs(Buffer)

        MOV     CX,BufLength            ;CX = Length of range to scan
        MOV     DX,MatLength            ;DX = Length of match string

        TEST    DX,DX                   ;Length(Match) = 0?
        JZ      SUCError                ;If so, we're done

        LDS     SI,Match                ;DS:SI => Match buffer
        LODSB                           ;AL = Match[1]; DS:SI => Match[2]
        UpcaseAL                        ;Uppercase it
        DEC     DX                      ;DX = MatLength-1
        SUB     CX,DX                   ;CX = BufLength-(MatLength-1)
        JBE     SUCError                ;No match if BufLength is less

;Search for first character in Match
SUCNext:
        JCXZ    SUCError                ;done if CX is 0 **
        MOV     AH,ES:[DI]              ;Get next character of buffer
        INC     DI                      ;To next position
        UpcaseAH                        ;Uppercase it
        CMP     AH,AL                   ;A match?
        LOOPNE  SUCNext                 ;Loop while CX<>0 and AH<>AL
        JNE     SUCError                ;Done if not found
;**     JCXZ    SUCError                ;wrong position for the check
        OR      DX,DX                   ;If Length = 1 (DX = 0) ...
        JZ      SUCFound                ; the "string" was found

        ;Search for remainder of Match

        PUSH    AX                      ;Save AX
        PUSH    CX                      ;Save CX
        PUSH    DI                      ;Save DI
        PUSH    SI                      ;Save SI

        MOV     CX,DX                   ;CX = Length(Match) - 1
SUCNextM:
        LODSB                           ;Next match character in AL
        UpcaseAL                        ;Uppercase it
        MOV     AH,ES:[DI]              ;Next buffer character in AH
        INC     DI                      ;Increment index
        UpcaseAH                        ;Uppercase it
        CMP     AH,AL                   ;A match?
        LOOPE   SUCNextM                ;Loop while AH=AL and CX<>0

        POP     SI                      ;Restore SI
        POP     DI                      ;Restore DI
        POP     CX                      ;Restore CX
        POP     AX                      ;Restore AX

        JNE     SUCNext                 ;Try again if no match

;Calculate number of bytes searched and return
SUCFound: DEC   DI                      ;DX = Offset where found
        MOV     AX,DI                   ;AX = Offset where found
        SUB     AX,BX                   ;Subtract starting offset
        JMP     SHORT SUCDone           ;Done

;Match was not found
SUCError: XOR   AX,AX
        DEC     AX                      ;Return FFFF

SUCDone:POP     DS                      ;Restore DS
        Exit_Code 12                    ;!!.12

SearchUC  ENDP


CODE    ENDS

        END
