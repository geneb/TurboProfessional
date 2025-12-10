{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$R-,O+,A-}
{$ENDIF}

{$I TPDEFINE.INC}

{*********************************************************}
{*                   TPMEMO.PAS 5.22                     *}
{*     Copyright (c) TurboPower Software 1988, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpMemo;
  {-Memo field editor}

interface

uses
  Dpmi,       {!!.22}
  TpCrt,
  {$IFDEF UseMouse}
  TpMouse,
  {$ENDIF}
  TpCmd,
  TpString;

  {.F-}
const
  EMnone       = 00; {Not a command}
  EMchar       = 01; {A character to enter the string}
  EMctrlChar   = 02; {Accept control character}
  EMenter      = 03; {New line}
  EMquit       = 04; {Quit editing}
  EMrestore    = 05; {Restore line and continue}
  EMhome       = 06; {Cursor to beginning of line}
  EMend        = 07; {Cursor to end of line}
  EMleft       = 08; {Cursor left by one character}
  EMright      = 09; {Cursor right by one character}
  EMup         = 10; {Cursor up one line}
  EMdown       = 11; {Cursor down one line}
  EMscrollUp   = 12; {Scroll display up one line}
  EMscrollDown = 13; {Scroll display down one line}
  EMpageUp     = 14; {Scroll display up one page}
  EMpageDown   = 15; {Scroll display down one page}
  EMscreenTop  = 16; {Cursor to top of screen}
  EMscreenBot  = 17; {Cursor to bottom of screen}
  EMtopOfFile  = 18; {Cursor to top of file}
  EMendOfFile  = 19; {Cursor to bottom of file}
  EMwordLeft   = 20; {Cursor left one word}
  EMwordRight  = 21; {Cursor right one word}
  EMback       = 22; {Backspace one character}
  EMdel        = 23; {Delete current character}
  EMdelEol     = 24; {Delete from cursor to end of line}
  EMdelLine    = 25; {Delete entire line}
  EMdelWord    = 26; {Delete word to right of cursor}
  EMtab        = 27; {Tab}
  EMins        = 28; {Toggle insert mode}
  EMindent     = 29; {Toggle auto-indent mode}
  EMwordWrap   = 30; {Toggle word wrap}
  EMreformatP  = 31; {Reformat paragraph}
  EMreformatG  = 32; {Global reformat}
  EMhelp       = 33; {Invoke help routine}
  EMmouse      = 34; {Mouse select}
  EMuser0      = 35; {user-defined exit commands}
  EMuser1      = 36;
  EMuser2      = 37;
  EMuser3      = 38;
  EMuser4      = 39;
  EMuser5      = 40;
  EMuser6      = 41;
  EMuser7      = 42;
  EMuser8      = 43;
  EMuser9      = 44;
  EMuser10     = 45;
  EMuser11     = 46;
  EMuser12     = 47;
  EMuser13     = 48;
  EMuser14     = 49;
  EMuser15     = 50;
  EMuser16     = 51;
  EMuser17     = 52;
  EMuser18     = 53;
  EMuser19     = 54;
{.F+}

const
  MaxLineLength : Byte = 127; {!do not make larger than 127!}

  {error message codes}
  tmBufferFull    = 1;       {edit buffer is full}
  tmLineTooLong   = 2;       {line too long, CRLF inserted}
  tmTooManyLines  = 3;       {max line limit would be exceeded}
  tmOverLineLimit = 4;       {max line limit already exceeded}

  {if True, reformatting routine treats blank space at start of line as
   signalling the start of a new paragraph}
  IndentStartsParagraph : Boolean = False;

  {if True, pressing <Del> when beyond the end of the current line will pull
   up the following line, just as <CtrlT> does}
  DeleteJoinsLines : Boolean = False;

const
  AllowTruncation : Boolean = True; {read partial files?}

type
  EMtype = EMnone..EMuser19;
  EMbuffer = array[1..65521] of Char;
  EMcontrolBlock =
    record
      UserData : Pointer;    {reserved for user (ID number perhaps)}
      XL, YL, XH, YH : Byte; {coordinates for edit window}
      BufPtr : ^EMbuffer;    {pointer to text buffer}
      BufSize : Word;        {size of buffer}
      MaxLines : Integer;    {maximum number of lines}
      TotalBytes : Word;     {bytes in buffer}
      TotalLines : Integer;  {lines in buffer}
      LineAtTop : Integer;   {line at top of edit window}
      BufPosTop : Word;      {index into buffer for start of line at top}
      CurLine : Integer;     {line number of current line}
      BufPos : Word;         {index into buffer for start of current line}
      CurCol : Byte;         {position of cursor within current line}
      ColDelta : Byte;       {for horizontal scrolling}
      KnownLine : Integer;   {used to speed up scrolling/searching}
      KnownOfs : Word;       {"    "  "     "  "}
      TAttr : Byte;          {attribute for normal text}
      CAttr : Byte;          {attribute for control characters}
      InsertMode : Boolean;  {True if in insert mode}
      IndentMode : Boolean;  {True if in auto-indent mode}
      ReadOnlyMode : Boolean;{True if in read-only mode}
      WordWrap : Boolean;    {True if word wrap is on}
      Modified : Boolean;    {True if edits have been made}
      TabDelta : Byte;       {distance between tab stops}
      Margin : Byte;         {right margin}
      HelpTopic : Word;      {help topic}
     end;

  MemoStatusType = (
    mstOK, mstNotFound, mstInvalidName, mstReadError, mstTooLarge,
    mstTruncated, mstCreationError, mstWriteError, mstCloseError);

const
  MemoKeyPtr : Pointer = nil; {pointer to routine to return next keystroke}
  MemoHelpPtr : Pointer = nil; {pointer to routine to display help}
  MemoStatusPtr : Pointer = nil; {pointer to routine to display status line}
  MemoErrorPtr : Pointer = nil; {pointer to routine to display error messages}
  HelpForMemo = TpCrt.HelpForMemo; {special code for help routine calls}

const
  {the commands in this set are disallowed in read-only mode}
  DisallowedInReadOnlyMode : set of EMtype =
    [EMchar..EMenter, EMrestore, EMback..EMreformatG];

const
  {used only by MemoStatus}
  StatusRow : Byte = 2;      {default to second line of screen for status line}
  StatusAttr : Byte = $F;    {attribute for status line}
const
  {used only by MemoError}
  ErrorRow : Byte = 1;      {default to top line of screen for error messages}
  ErrorAttr : Byte = $F;    {attribute for error message line}

  {$IFDEF UseMouse}
const
  {True if mouse support is enabled}
  MemoMouseEnabled : Boolean = False;
  {$ENDIF}
{.F+}

procedure InitControlBlock(var EMCB : EMcontrolBlock;
                           XLow, YLow, XHigh, YHigh : Byte;
                           TextAttr, CtrlAttr : Byte;
                           InsertOn, IndentOn, WordWrapOn : Boolean;
                           TabSize : Byte; HelpIndex : Word;
                           RightMargin : Byte; LineLimit : Integer;
                           BufferSize : Word; var Buffer);
  {-Initialize a memo editor control block}

function EditMemo(var EMCB : EMcontrolBlock;
                  ReadOnly : Boolean;
                  var CmdList) : EMtype;
  {-Edit a buffer filled with text}

procedure MemoStatus(var EMCB : EMcontrolBlock);
  {-Display status line}

procedure MemoError(var EMCB : EMcontrolBlock; ErrorCode : Word);
  {-Display error message and wait for key press}

function AddMemoCommand(Cmd : EMtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

{$IFDEF UseMouse}

procedure EnableMemoMouse;
  {-Enable mouse support in TPMEMO}

procedure DisableMemoMouse;
  {-Disable mouse support in TPMEMO}

{$ENDIF}

{file handling routines}

function ReadMemoFile(var Buffer; BufferSize : Word;
                      FName : string; var FSize : LongInt) : MemoStatusType;
  {-Read a file into Buffer, returning a status code}

function SaveMemoFile(var EMCB : EMcontrolBlock; FName : string;
                      MakeBackup : Boolean) : MemoStatusType;
  {-Save the current file in the text buffer associated with EMCB}

  {.F-}
const
  {Keystroke to command mapping}
  MemoKeyMax = 250;   {last available slot in MemoKeySet}

  {ID string for installation programs}
  MemoKeyID : string[16] = 'tpmemo key array';

  {default key assignments}
  MemoKeySet : array[0..MemoKeyMax] of Byte = (
   {length keys         command type      key sequence}
    3,     $00, $00,    EMquit,          {^Break}
    3,     $00, $13,    EMreformatG,     {AltR}
    3,     $00, $3B,    EMhelp,          {F1}
    3,     $00, $47,    EMhome,          {Home}
    3,     $00, $48,    EMup,            {Up}
    3,     $00, $49,    EMpageUp,        {PgUp}
    3,     $00, $4B,    EMleft,          {Left}
    3,     $00, $4D,    EMright,         {Right}
    3,     $00, $4F,    EMend,           {End}
    3,     $00, $50,    EMdown,          {Down}
    3,     $00, $51,    EMpageDown,      {PgDn}
    3,     $00, $52,    EMins,           {Ins}
    3,     $00, $53,    EMdel,           {Del}
    3,     $00, $73,    EMwordLeft,      {^Left}
    3,     $00, $74,    EMwordRight,     {^Right}
    3,     $00, $75,    EMscreenBot,     {^End}
    3,     $00, $76,    EMendOfFile,     {^PgDn}
    3,     $00, $77,    EMscreenTop,     {^Home}
    3,     $00, $84,    EMtopOfFile,     {^PgUp}
    2,     $01,         EMwordLeft,      {^A}
    2,     $02,         EMreformatP,     {^B}
    2,     $03,         EMpageDown,      {^C}
    2,     $04,         EMright,         {^D}
    2,     $05,         EMup,            {^E}
    2,     $06,         EMwordRight,     {^F}
    2,     $07,         EMdel,           {^G}
    2,     $08,         EMback,          {^H, Bksp}
    2,     $09,         EMtab,           {^I, Tab}
    2,     $0D,         EMenter,         {^M, Enter}
    2,     $10,         EMctrlChar,      {^P}
    2,     $12,         EMpageUp,        {^R}
    2,     $13,         EMleft,          {^S}
    2,     $14,         EMdelWord,       {^T}
    2,     $16,         EMins,           {^V}
    2,     $17,         EMscrollUp,      {^W}
    2,     $18,         EMdown,          {^X}
    2,     $19,         EMdelLine,       {^Y}
    2,     $1A,         EMscrollDown,    {^Z}
    2,     $1B,         EMquit,          {Esc}
    2,     $7F,         EMback,          {^Bksp}
    3,     $0F, $09,    EMindent,        {^O^I}
    3,     $0F, $17,    EMwordWrap,      {^O^W}
    3,     $11, $03,    EMendOfFile,     {^Q^C}
    3,     $11, $04,    EMend,           {^Q^D}
    3,     $11, $05,    EMscreenTop,     {^Q^E}
    3,     $11, $0C,    EMrestore,       {^Q^L}
    3,     $11, $12,    EMtopOfFile,     {^Q^R}
    3,     $11, $13,    EMhome,          {^Q^S}
    3,     $11, $18,    EMscreenBot,     {^Q^X}
    3,     $11, $19,    EMdelEol,        {^Q^Y}
  {$IFDEF UseMouse}
    3,     $00, $EF,    EMmouse,         {click left  = mouse select}
    3,     $00, $EE,    EMquit,          {click right = ESC}
    3,     $00, $ED,    EMhelp,          {click both  = help}
  {$ELSE}
                            0, 0,        {180}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {190}
  {$ENDIF}
    {-----------pad to end of array----------}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {200}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {210}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {220}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {230}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {240}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0);       {250}
{.F+}

  {routines intended primarily for internal use, but which might be used to
   implement user-defined commands or for other purposes}

function FindLineIndex(var EMCB : EMcontrolBlock; LineNum : Integer) : Word;
  {-Return the index into the edit buffer for the specified line number.
    LineNum must be <= EMCB.TotalLines.}

function FindLineLength(var EMCB : EMcontrolBlock; LineNum : Integer) : Word;
  {-Find the length of the specified line}

procedure InitBufferState(var EMCB : EMcontrolBlock;
                          BufferSize : Word; var Buffer);
  {-Initialize the edit buffer status fields in a control block}

procedure GetLine(var EMCB : EMcontrolBlock; var S : string; LineNum : Integer);
  {-Get the LineNum'th line from the buffer for the specified control block
    and store it in S. If line is longer than 255 characters, only the first
    255 characters will be loaded into S.}

procedure DrawLine(var EMCB : EMcontrolBlock; St : String; LineNum : Integer);
  {-Draw the string St, which represents the specified line number}

procedure FastWriteCtrl(St : String; Row, Col, Attr, Ctrl : Byte);
  {-Write St at Row,Col in Attr (video attribute) without snow.
    Control characters displayed in Ctrl as upper-case letters}

  {==========================================================================}

implementation

const
  SafetyMargin = 2;
  CtrlZ : Char = ^Z;
  CRLF : array[1..2] of Char = ^M^J;
  SearchFailed = $FFFF;

  {$L TPMEMO}

  procedure FastWriteCtrl(St : String; Row, Col, Attr, Ctrl : Byte);
    {-Write St at Row,Col in Attr (video attribute) without snow.
      Control characters displayed in Ctrl as upper-case letters}
    external;

  function Scan(Limit : Integer; Ch : Char; T : Pointer) : Integer;
    {-Scan limit chars for Ch; Ch not found if Result=Limit}
    external;

  procedure HelpRoutine(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Call routine pointed to by MemoHelpPtr}
  inline(
    $FF/$1E/>MemoHelpPtr);   {call dword ptr [>MemoHelpPtr]}

  procedure StatusRoutine(var EMCB : EMcontrolBlock);
    {-Call routine pointed to by MemoStatusPtr}
  inline(
    $FF/$1E/>MemoStatusPtr); {call dword ptr [>MemoStatusPtr]}

  procedure ErrorRoutine(var EMCB : EMcontrolBlock; ErrorCode : Word);
    {-Call routine pointed to by MemoErrorPtr}
  inline(
    $FF/$1E/>MemoErrorPtr); {call dword ptr [>MemoErrorPtr]}

  function GetKey : Word;
    {-Call routine pointed to by MemoKeyPtr}
  inline(
    $FF/$1E/>MemoKeyPtr);    {call dword ptr [>MemoKeyPtr]}

  {$IFDEF UseMouse}

  procedure HideMousePrim(var MouseState : Boolean);
    {-Save state of mouse cursor in MouseState and hide it}
  begin
    MouseState := MouseCursorOn;
    HideMouse;
  end;

  procedure ShowMousePrim(MouseOn : Boolean);
    {-Hide or unhide the mouse cursor}
  begin
    if MouseOn then
      ShowMouse
    else
      HideMouse;
  end;

  {$ENDIF}

  procedure InitBufferState(var EMCB : EMcontrolBlock;
                            BufferSize : Word; var Buffer);
    {-Initialize the edit buffer status fields in a control block}
  var
    I, J : Word;
    Buf : EMbuffer absolute Buffer;
  begin
    with EMCB do begin
      {reset edit buffer state variables}
      Modified := False;
      BufSize := BufferSize;
      BufPtr := @Buffer;
      BufPos := 1;
      BufPosTop := 1;
      KnownLine := 1;
      KnownOfs := 1;
      CurLine := 1;
      CurCol := 1;
      ColDelta := 0;
      LineAtTop := 1;

      {find end of text buffer}
      I := Search(Buffer, BufferSize, CtrlZ, 1);

      if (I = SearchFailed) or (I = 0) then begin
        {buffer is empty}
        TotalBytes := 1;
        TotalLines := 1;
        Buf[1] := CtrlZ;
      end
      else begin
        TotalBytes := I+1;

        {count total number of rows}
        TotalLines := 1;
        I := 1;
        repeat
          J := Search(Buf[I], Succ(TotalBytes-I), CRLF, 2);
          if J <> SearchFailed then begin
            Inc(TotalLines);
            Inc(I, J+2);
          end;
        until (J = SearchFailed) or (I >= TotalBytes);
      end;
    end;
  end;

  procedure InitControlBlock(var EMCB : EMcontrolBlock;
                             XLow, YLow, XHigh, YHigh : Byte;
                             TextAttr, CtrlAttr : Byte;
                             InsertOn, IndentOn, WordWrapOn : Boolean;
                             TabSize : Byte; HelpIndex : Word;
                             RightMargin : Byte; LineLimit : Integer;
                             BufferSize : Word; var Buffer);
    {-Initialize a memo editor control block}
  begin
    with EMCB do begin
      XL := XLow;
      YL := YLow;
      XH := XHigh;
      YH := YHigh;
      TAttr := TextAttr;
      CAttr := CtrlAttr;
      InsertMode := InsertOn;
      IndentMode := IndentOn;
      ReadOnlyMode := False;
      WordWrap := WordWrapOn;
      TabDelta := TabSize;
      if RightMargin = 0 then
        Margin := Succ(XH-XL)
      else if RightMargin > MaxLineLength then
        Margin := MaxLineLength
      else
        Margin := RightMargin;
      if LineLimit <= 0 then
        MaxLines := MaxInt
      else
        MaxLines := LineLimit;
      HelpTopic := HelpIndex;

      {initialize TotalLines, TotalBytes, etc.}
      InitBufferState(EMCB, BufferSize, Buffer);
    end;
  end;

  procedure MemoStatus(var EMCB : EMcontrolBlock);
    {-Display status line}
  const
    OnOff : array[Boolean] of string[3] = ('Off', 'On ');
    Save : array[Boolean] of string[4] = ('    ', 'SAVE');
    StatusLine : string[80] =
      {         1         2         3         4         5         6         7         8}
      {12345678901234567890123456789012345678901234567890123456789012345678901234567890}
      ' Line: xxxxx  Column: xxx  100%  Insert: Off  Indent: Off  Word wrap: Off  SAVE ';
  var
    S : string[5];
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    with EMCB do begin
      {insert line number}
      S := Long2Str(CurLine);
      S := Pad(S, 5);
      Move(S[1], StatusLine[8], 5);

      {insert column number}
      S := Long2Str(CurCol);
      S := Pad(S, 3);
      Move(S[1], StatusLine[23], 3);

      {insert percentage of buffer used}
      S := Real2Str(Trunc((TotalBytes*100.0)/(BufSize-SafetyMargin)), 3, 0);
      Move(S[1], StatusLine[28], 3);

      {insert remaining fields}
      Move(OnOff[InsertMode][1], StatusLine[42], 3);
      Move(OnOff[IndentMode][1], StatusLine[55], 3);
      Move(OnOff[WordWrap][1], StatusLine[71], 3);
      Move(Save[Modified][1], StatusLine[76], 4);

      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      {display status line}
      FastWrite(StatusLine, StatusRow, 1, StatusAttr);

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}
    end;
  end;

  procedure MemoError(var EMCB : EMcontrolBlock; ErrorCode : Word);
    {-Display error message and wait for key press}
  var
    S : string[80];
    I : Word;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    case ErrorCode of
      tmBufferFull  :
        S := 'Edit buffer is full';
      tmLineTooLong :
        S := 'Line too long, carriage return inserted';
      tmTooManyLines :
        S := 'Limit on number of lines has been reached';
      tmOverLineLimit :
        S := 'Limit on number of lines has been exceeded';
      else
        S := 'Unknown error';
    end;
    S := S+'. Press any key...';

    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    {display error message}
    FastWrite(Pad(S, ScreenWidth), ErrorRow, 1, ErrorAttr);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    {flush the keyboard buffer}
    while KeyPressed do
      I := GetKey;

    {wait for key press}
    I := GetKey;

    {clear error message line}
    FastWrite(CharStr(' ', ScreenWidth), ErrorRow, 1, ErrorAttr);
  end;

  function FindLineIndex(var EMCB : EMcontrolBlock; LineNum : Integer) : Word;
    {-Return the index into the edit buffer for the specified line number}
  var
    I : Integer;
  begin
    with EMCB do begin
      if LineNum = 1 then begin
        KnownLine := 1;
        KnownOfs := 1;
      end
      else if LineNum >= KnownLine then
        while KnownLine < LineNum do begin
          I := Succ(TotalBytes-KnownOfs);
          if I < 0 then
            I := MaxInt;
          Inc(KnownOfs, Succ(Scan(I, ^J, @BufPtr^[KnownOfs])));
          Inc(KnownLine);
        end
      else begin
        {linenum < knownline, search backwards}
        Dec(KnownOfs, 2);
        while KnownLine > LineNum do begin
          I := KnownOfs;
          if I < 0 then
            I := MaxInt;
          Inc(Integer(KnownOfs), Pred(Scan(-I, ^J, @BufPtr^[KnownOfs])));
          Dec(KnownLine);
        end;

        {point to start of next line}
        Inc(KnownOfs, 2);
      end;

      FindLineIndex := KnownOfs;
    end;
  end;

  function FindLineLength(var EMCB : EMcontrolBlock; LineNum : Integer) : Word;
    {-Find the length of the specified line}
  var
    I, J : Word;
  begin
    with EMCB do
      if LineNum > TotalLines then
        FindLineLength := 0
      else begin
        {find starting index for line}
        J := FindLineIndex(EMCB, LineNum);

        {calculate length}
        I := Search(BufPtr^[J], Succ(TotalBytes-J), CRLF, 2);
        if I = SearchFailed then
          FindLineLength := TotalBytes-J
        else
          FindLineLength := I;
      end;
  end;

  procedure GetLine(var EMCB : EMcontrolBlock; var S : string; LineNum : Integer);
    {-Get the LineNum'th line from the buffer for the specified control block,
      and store it in S}
  var
    I, J : Word;
    SLen : Byte absolute S;
  begin
    with EMCB do
      if LineNum > TotalLines then
        SLen := 0
      else begin
        {find starting index and length for line}
        J := FindLineIndex(EMCB, LineNum);
        I := FindLineLength(EMCB, LineNum);

        {truncate if line is too long}
        if I > 255 then
          SLen := 255
        else
          SLen := I;

        Move(BufPtr^[J], S[1], SLen);
      end;
  end;

  procedure DrawLine(var EMCB : EMcontrolBlock; St : String; LineNum : Integer);
    {-Draw the string St, which represents the specified line number}
  var
    StLen : Byte absolute St;
    WinWidth : Byte;
  begin
    {calculate screen row}
    Dec(LineNum, Pred(EMCB.LineAtTop));
    Inc(LineNum, Pred(EMCB.YL));

    with EMCB do begin
      WinWidth := Succ(XH-XL);

      {adjust for ColDelta}
      if (ColDelta > 0) and (StLen > 0) then
        if ColDelta >= StLen then
          StLen := 0
        else begin
          Move(St[ColDelta+1], St[1], StLen-ColDelta);
          Dec(StLen, ColDelta);
        end;
    end;

    {pad the end of the string}
    if StLen < WinWidth then
      FillChar(St[Succ(StLen)], WinWidth-StLen, ' ');

    {change the length}
    StLen := WinWidth;

    {draw the string}
    with EMCB do
      if CAttr = TAttr then
        FastWrite(St, LineNum, XL, TAttr)
      else
        FastWriteCtrl(St, LineNum, XL, TAttr, CAttr);
  end;

  function EditMemo(var EMCB : EMcontrolBlock;
                    ReadOnly : Boolean;
                    var CmdList) : EMtype;
    {-Edit a buffer filled with text}
  type
    CmdListType = array[1..100] of EMtype;
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
    OldSt, St : string;      {text of current line}
    OldCol : Byte;
    OldModified : Boolean;
    StLen : Byte absolute St;
    I, J : Word;
    CursorSL : Word;
    CursorXY : Word;
    SaveBreak : Boolean;
    ForceRedraw : Boolean;
    DoingChars : Boolean;
    Done, OK : Boolean;
    WinWidth : Byte;
    EMC : EMtype;
    UserCmdList : CmdListType absolute CmdList;
    NextUserCmd : Word;
    {$IFDEF UseMouse}
    SaveWaitState : Boolean;
    SaveMouse : Boolean;
    {$ENDIF}

    procedure CallErrorRoutine(Code : Integer);
      {-Call the user-defined error routine}
    begin
      if MemoErrorPtr <> nil then
        ErrorRoutine(EMCB, Code);
    end;

    procedure TrimSpaces;
      {-Trim trailing blanks from current line}
    begin
      while St[StLen] = ' ' do
        Dec(StLen);
    end;

    function InsertOK(N : Integer) : Boolean;
      {-Return True if OK to insert N bytes into the edit buffer. Calls user
        error handler if not OK.}
    var
      I : LongInt;
    begin
      with EMCB do begin
        {allow a safety margin}
        I := TotalBytes+SafetyMargin;

        {calculate actual TotalBytes+N}
        Inc(I, LongInt(N)+(LongInt(StLen)-Length(OldSt)));

        if I <= BufSize then
          InsertOK := True
        else begin
          InsertOK := False;
          CallErrorRoutine(tmBufferFull);
        end;
      end;
    end;

    procedure ToggleInsertMode;
      {-Toggle between insert and overtype mode, keeping BIOS keyboard flag up
        to date}
    var
      BiosKbdFlag : ^Byte {absolute $0040 : $0017};                    {!!.22}
    begin
      BiosKbdFlag := Ptr(BiosDataSele, $0017);                         {!!.22}
      with EMCB do begin
        {toggle insert flag}
        InsertMode := not InsertMode;

        {use fat cursor if inserting}
        if InsertMode then begin
          FatCursor;
          BiosKbdFlag^ := BiosKbdFlag^ or $80;                         {!!.22}
        end
        else begin
          NormalCursor;
          BiosKbdFlag^ := BiosKbdFlag^ and $7F;                        {!!.22}
        end;
      end;
    end;

    procedure DrawCurrentLine;
      {-Draw the current line}
      {$IFDEF UseMouse}
      var
        SaveMouse : Boolean;
      {$ENDIF}
    begin
      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      {draw the current line}
      DrawLine(EMCB, St, EMCB.CurLine);

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}
    end;

    procedure RedrawScreen;
      {-Redraw entire screen}
    var
      I, J : Integer;
      S : String;
      {$IFDEF UseMouse}
      SaveMouse : Boolean;
      {$ENDIF}
    begin
      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      with EMCB do begin
        J := LineAtTop+(YH-YL);
        for I := LineAtTop to J do begin
          if (I = CurLine) then
            DrawLine(EMCB, St, I)
          else begin
            GetLine(EMCB, S, I);
            DrawLine(EMCB, S, I);
          end;
        end;
      end;

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}

      ForceRedraw := False;
    end;

    procedure SaveCurrentLine(Trim : Boolean);
      {-Patch the current line back into place}
    var
      I, J : Word;
      K : Integer;
    begin
      with EMCB do begin
        if Trim then
          TrimSpaces;
        if St = OldSt then
          Exit;

        {find the actual length of the current line}
        I := BufPos;
        J := FindLineLength(EMCB, CurLine);

        {calculate difference in size}
        K := Integer(StLen)-J;

        if K > 0 then
          {make room for new text}
          Move(BufPtr^[I], BufPtr^[I+K], Succ(TotalBytes-I))
        else
          {delete excess characters}
          Move(BufPtr^[I-K], BufPtr^[I], Succ(TotalBytes-I)+K);

        {insert the text}
        Move(St[1], BufPtr^[I], StLen);
        Inc(TotalBytes, K);

        KnownLine := LineAtTop;
        KnownOfs := BufPosTop;
        OldSt := St;
        Modified := True;
        OldModified := True;
      end;
    end;

    procedure ScrollDisplay(Lines : Integer);
      {-Scroll the editing window up or down}
    var
      S : string;
      SaveTextAttr : Byte;
      I, J, K : Integer;
      {$IFDEF UseMouse}
      SaveMouse : Boolean;
      {$ENDIF}
    begin
      if Lines = 0 then
        Exit;
      with EMCB do begin
        SaveTextAttr := TextAttr;
        TextAttr := TAttr;

        {$IFDEF UseMouse}
        HideMousePrim(SaveMouse);
        {$ENDIF}

        if Lines < 0 then
          ScrollWindowDown(XL, YL, XH, YH, -Lines)
        else
          ScrollWindowUp(XL, YL, XH, YH, Lines);

        BufPosTop := FindLineIndex(EMCB, LineAtTop+Lines);
        Inc(LineAtTop, Lines);

        if Lines < 0 then begin
          J := LineAtTop;
          K := Pred(J-Lines);
        end
        else begin
          J := LineAtTop+(YH-YL)-Pred(Lines);
          K := Pred(J+Lines);
        end;

        {draw the line(s) replacing the one(s) that scrolled off}
        for I := J to K do begin
          GetLine(EMCB, S, I);
          DrawLine(EMCB, S, I);
        end;

        {$IFDEF UseMouse}
        ShowMousePrim(SaveMouse);
        {$ENDIF}

        TextAttr := SaveTextAttr;
      end;
    end;

    function TooManyLinesCheck : Boolean;
      {-Check to see if there are too many lines}
    begin
      with EMCB do
        if Word(TotalLines) >= Word(MaxLines) then begin
          CallErrorRoutine(tmTooManyLines);
          OK := False;
          TooManyLinesCheck := True;
        end
        else
          TooManyLinesCheck := False;
    end;

    procedure InsLinePrim(LineNum, Col : Integer);
      {-Primitive routine to insert a line break}
    var
      I, J : Word;
    begin
      with EMCB do begin
        if TooManyLinesCheck then
          Exit;

        {find the place to insert the line break}
        I := FindLineIndex(EMCB, LineNum)+Pred(Col);

        {see if we need to trim some blanks}
        J := Pred(I);
        while (J > 0) and (BufPtr^[J] = ' ') do
          Dec(J);
        Inc(J);

        if J <> I then begin
          {see if there's room}
          OK := InsertOK(2-(I-J));
          if not OK then
            Exit;

          {make room for a CRLF}
          Move(BufPtr^[I], BufPtr^[J+2], Succ(TotalBytes-I));

          {insert the CRLF}
          Move(CRLF, BufPtr^[J], 2);

          {adjust counters}
          Inc(TotalLines);
          TotalBytes := (TotalBytes+2)-(I-J);
        end
        else begin
          {see if there's room}
          OK := InsertOK(2);
          if not OK then
            Exit;

          {make room for a CRLF}
          Move(BufPtr^[I], BufPtr^[I+2], Succ(TotalBytes-I));

          {insert the CRLF}
          Move(CRLF, BufPtr^[I], 2);

          {adjust counters}
          Inc(TotalLines);
          Inc(TotalBytes, 2);
        end;

        OldModified := True; {!!.10}
        Modified := True;
      end;
    end;

    procedure LoadLine(LineNum : Integer; Truncate : Boolean);
      {-Load the specified line}
    var
      I, J, K, N, Max : Word;
    begin
      with EMCB do begin
        {find the line we're moving to}
        BufPos := FindLineIndex(EMCB, LineNum);
        CurLine := LineNum;

        {find the length of the line}
        I := FindLineLength(EMCB, LineNum);

        {calc max length of line}
        if Truncate then
          Max := MaxLineLength
        else
          Max := 255;

        {insert carriage return if line is too long}
        if I > Max then begin
          {determine where to break the line}
          K := Max;
          N := FindLineIndex(EMCB, LineNum);
          J := N+Pred(K);
          while (J > N) and (BufPtr^[J] <> ' ') do begin
            Dec(J);
            Dec(K);
          end;
          if J = N then
            K := Max;

          {try to break the line}
          Inc(MaxLines);
          InsLinePrim(LineNum, K);
          Dec(MaxLines);

          if not OK then begin
            {something overflowed--force the line break}
            Inc(N, K);
            BufPtr^[N] := ^M;
            BufPtr^[N+1] := ^J;
            Inc(TotalLines);
          end;

          {report the break}
          CallErrorRoutine(tmLineTooLong);

          {force screen to be redrawn}
          ForceRedraw := True;

          {recalculate the length}
          I := FindLineLength(EMCB, LineNum);
        end;

        {load the line into St and OldSt}
        StLen := I;
        Move(BufPtr^[BufPos], St[1], StLen);
        OldSt := St;
        OldCol := CurCol;
        Modified := OldModified;
      end;
    end;

    procedure GotoLine(LineNum : Integer; Trim : Boolean);
      {-Save the current line and move the cursor to the LineNum'th line}
    var
      I : Word;
    begin
      with EMCB do begin
        {don't go too far}
        if LineNum > TotalLines then
          LineNum := TotalLines;

        {save the line we've been editing}
        SaveCurrentLine(Trim);

        {scroll the display if necessary}
        if LineNum < LineAtTop then
          ScrollDisplay(LineNum-LineAtTop)
        else begin
          I := LineAtTop+(YH-YL);
          if LineNum > I then
            ScrollDisplay(LineNum-I);
        end;

        {load the line}
        LoadLine(LineNum, Trim);
      end;
    end;

    procedure DelLinePrim(LineNum : Integer);
      {-Primitive routine to delete a line}
    var
      I, J : Word;
    begin
      with EMCB do begin
        {find the line we're deleting}
        I := FindLineIndex(EMCB, LineNum);

        {find the length of the line}
        J := Search(BufPtr^[I], Succ(TotalBytes-I), CRLF, 2);
        if J = SearchFailed then
          J := TotalBytes-BufPos
        else
          Inc(J, 2);

        {delete it}
        Move(BufPtr^[I+J], BufPtr^[I], Succ(TotalBytes-I)-J);
        Dec(TotalLines);
        if TotalLines = 0 then begin
          TotalLines := 1;
          TotalBytes := 1;
          BufPtr^[1] := ^Z;
        end
        else
          Dec(TotalBytes, J);

        Modified := True;
        OldModified := True;
      end;
    end;

    procedure JoinLinePrim(LineNum : Integer);
      {-Primitive routine to join two lines}
    var
      I : Word;
    begin
      with EMCB do begin
        {find the place to join the lines}
        I := FindLineIndex(EMCB, LineNum);

        {make room for a CRLF}
        Move(BufPtr^[I], BufPtr^[I-2], Succ(TotalBytes-I));

        Dec(TotalLines);
        Dec(TotalBytes, 2);
        BufPtr^[TotalBytes+1] := ^Z;

        Modified := True;
        OldModified := True;
      end;
    end;

    procedure PutLineAtTop(LineNum : Integer);
      {-Position the specified line at top of editing window}
    begin
      with EMCB do begin
        if LineNum < 1 then
          LineNum := 1
        else if LineNum > TotalLines then
          LineNum := TotalLines;
        SaveCurrentLine(True); {!!}
        BufPosTop := FindLineIndex(EMCB, LineNum);
        LineAtTop := LineNum;
        RedrawScreen;
      end;
    end;

    function GetIndent(S : string) : Byte;
      {-Get the indentation level of S}
    var
      I : Word;
      SLen : Byte absolute S;
    begin
      I := 0;
      while S[SLen] = ' ' do
        Dec(SLen);
      while (I < SLen) and (S[I+1] = ' ') do
        Inc(I);
      GetIndent := I;
    end;

    procedure WrapLine(Trim : Boolean);
      {-Word wrap the current line}
    var
      I : Integer;
      Temp, SaveSt : string;
    begin
      with EMCB do begin
        if TooManyLinesCheck then
          Exit;
        SaveSt := St;
        TpString.WordWrap(St, St, Temp, Margin, False);
        if IndentMode then begin
          I := GetIndent(St);
          if I <> 0 then
            Insert(CharStr(' ', I), Temp, 1);
        end;
        I := Length(Temp)-(Length(SaveSt)-CurCol);
        if I < 1 then
          I := 1;
        SaveCurrentLine(True);
        DrawCurrentLine;
        InsLinePrim(CurLine, StLen+1);
        if OK then begin
          GotoLine(CurLine+1, Trim);
          St := Temp;
          SaveCurrentLine(True);
          ColDelta := 0;
          CurCol := I;
          OldCol := I;
        end
        else begin
          St := SaveSt;
          SaveCurrentLine(True);
        end;
      end;
    end;

    procedure ReformatParagraph;
      {-Reformat a paragraph starting at the current line}
    var
      SaveMax, I : Integer;
    begin
      with EMCB do begin
        SaveCurrentLine(True);

        if StLen = 0 then begin
          GotoLine(CurLine+1, True);
          Exit;
        end;

        {ignore line limit when reformatting}
        SaveMax := MaxLines;
        MaxLines := MaxInt;

        while (CurLine < TotalLines) and (OK = True) do begin
          while (StLen > Margin) and OK do
            WrapLine(False);
          if OK then
            OK := FindLineLength(EMCB, CurLine+1) <> 0;
          if OK and IndentStartsParagraph then
            OK := BufPtr^[KnownOfs] <> ' ';

          if OK then begin
            Inc(StLen);
            St[StLen] := ' ';
            I := Succ(StLen);
            SaveCurrentLine(False);
            JoinLinePrim(CurLine+1);
            LoadLine(CurLine, False);
            while (I < StLen) and (St[I] = ' ') do
              Delete(St, I, 1);
            TrimSpaces;
          end;
        end;

        OK := True;
        while (StLen > Margin) and OK do
          WrapLine(False);

        RedrawScreen;
        GotoLine(CurLine+1, True);
        if CurLine = TotalLines then
          CurCol := Succ(StLen)
        else
          CurCol := 1;
        OldCol := CurCol;
        MaxLines := SaveMax;
      end;
    end;

    procedure DeleteWordPrim;
      {-Primitive routine to delete a word}
    var
      DelEnd : Word;
    begin
      with EMCB do begin
        if CurCol > StLen then
          Exit;

        {start deleting at the cursor}
        DelEnd := CurCol;

        {delete all of the current word, if any}
        if St[CurCol] <> ' ' then
          while (St[DelEnd] <> ' ') and (DelEnd <= StLen) do
            Inc(DelEnd);

        {delete any spaces prior to the next word, if any}
        while (St[DelEnd] = ' ') and (DelEnd <= StLen) do
          Inc(DelEnd);

        Delete(St, CurCol, DelEnd-CurCol);
      end;
    end;

    procedure JoinAtEndOfLine;
      {-Join the following line with the current one at the cursor}
    begin
      with EMCB do
        if (CurLine < TotalLines) and InsertOK(CurCol-StLen) then begin
          FillChar(St[Succ(StLen)], CurCol-StLen, ' ');
          StLen := Pred(CurCol);
          I := CurCol;
          SaveCurrentLine(False);
          JoinLinePrim(CurLine+1);
          LoadLine(CurLine, True);
          CurCol := I;
          ForceRedraw := True;
          OldCol := CurCol;
        end;
    end;

    {$IFDEF UseMouse}

    procedure MouseSelect;
      {-Move cursor to position of mouse}
    var
      CurRow, TargetLine : Integer;
      TargetRow, TargetCol : Integer;
    begin
      {convert mouse X and Y coordinates to absolute row and col}
      TargetRow := MouseKeyWordY+MouseYLo;
      TargetCol := MouseKeyWordX+MouseXLo;

      with EMCB do
        {make sure mouse is within edit window}
        if (TargetCol >= XL) and (TargetCol <= XH)
        and (TargetRow >= YL) and (TargetRow <= YH) then begin
          {calculate current screen row}
          CurRow := Word(YL)+(CurLine-LineAtTop);

          {calculate target line number}
          TargetLine := CurLine+(TargetRow-CurRow);

          if TargetLine <= TotalLines then begin
            {move cursor to desired location}
            CurCol := TargetCol-Pred(XL)+ColDelta;
            GotoLine(TargetLine, True);
          end;
        end;
    end;

    {$ENDIF}

    procedure TopOfFile;
      {-Reset for top of file}
    begin
      with EMCB do begin
        PutLineAtTop(1);
        GotoLine(1, True);
        CurCol := 1;
        OldCol := 1;
        RedrawScreen;
      end;
    end;

    procedure ReformatGlobally;
      {-Reformat entire file}
    begin
      with EMCB do begin
        {skip all this if the file is empty}
        if TotalBytes = 1 then
          Exit;

        {go to top of file}
        TopOfFile;

        {while not at last line, reformat paragraphs}
        while CurLine < TotalLines do
          ReformatParagraph;
      end;
    end;

    procedure CheckLineLimit;
      {-Display error message if line limit exceeded}
    begin
      with EMCB do
        if TotalLines > MaxLines then begin
          RedrawScreen;
          CallErrorRoutine(tmOverLineLimit);
        end;
    end;

  begin
    with EMCB do begin
      {Store cursor position and shape}
      GetCursorState(CursorXY, CursorSL);

      {Save break checking state}
      SaveBreak := CheckBreak;
      CheckBreak := False;

      {set cursor shape}
      InsertMode := not InsertMode;
      ToggleInsertMode;

      {initialize miscellaneous variables}
      WinWidth := Succ(XH-XL);
      NextUserCmd := 1;
      KnownLine := 1;
      KnownOfs := 1;
      OldModified := Modified;
      ReadOnlyMode := ReadOnly;

      {$IFDEF UseMouse}
      SaveMouse := MouseCursorOn;
      {$ENDIF}

      {get the first line}
      LoadLine(EMCB.CurLine, True);

      {draw whole screen}
      ForceRedraw := True;

      {see if we exceeded the line limit}
      CheckLineLimit;

      {loop while reading keys}
      Done := False;
      DoingChars := False;
      repeat
        OK := True;

        {update screen}
        if CurCol > MaxLineLength+1 then
          CurCol := MaxLineLength+1;
        if CurCol > WinWidth+ColDelta then begin
          ColDelta := CurCol-WinWidth;
          RedrawScreen;
        end
        else if CurCol < Succ(ColDelta) then begin
          ColDelta := Pred(CurCol);
          RedrawScreen;
        end
        else if ForceRedraw then
          RedrawScreen
        else
          DrawCurrentLine;

        {position cursor}
        GoToXYAbs(XL+Pred(CurCol)-ColDelta, YL+(CurLine-LineAtTop));

        {set modified flag}
        TrimSpaces;
        Modified := OldModified or (St <> OldSt);

        {display status line}
        if MemoStatusPtr <> nil then begin
          {update TotalBytes field for status routine}
          J := TotalBytes;
          Inc(TotalBytes, Integer(StLen)-Length(OldSt));

          {call status routine}
          StatusRoutine(EMCB);

          {reset TotalBytes field}
          TotalBytes := J;
        end;

        {$IFDEF UseMouse}
        if MemoMouseEnabled then begin
          SaveWaitState := WaitForButtonRelease;
          WaitForButtonRelease := True;
        end;
        {$ENDIF}

        {see if there is a user command left to process}
        EMC := UserCmdList[NextUserCmd];
        if DoingChars then begin
          if EMC = EMchar then begin
            {EMchar acts as toggle}
            EMC := EMnone;
            DoingChars := False;
          end
          else begin
            {treat the command as a character}
            Ch := Char(EMC);
            EMC := EMchar;
          end;
          Inc(NextUserCmd);
        end
        else if EMC = EMnone then
          {read from the keyboard}
          EMC := GetCommand(MemoKeySet, MemoKeyPtr, ChWord)
        else begin
          {process next user command}
          Inc(NextUserCmd);
          if EMC = EMchar then begin
            DoingChars := True;
            EMC := EMnone;
          end;
        end;

        {make sure command is allowable if in read-only mode}
        if ReadOnlyMode then
          if EMC in DisallowedInReadOnlyMode then
            EMC := EMnone;

        {reinterpret potentially troublesome control characters}
        if EMC = EMchar then
          case Ch of
            ^M : EMC := EMenter;
            ^J, ^Z : EMC := EMnone;
          end;

        {$IFDEF UseMouse}
        if MemoMouseEnabled then
          WaitForButtonRelease := SaveWaitState;
        {$ENDIF}

        {deal with control characters if desired}
        if EMC = EMctrlChar then
          {don't allow control characters if attributes are the same}
          if (CAttr = TAttr) then
            EMC := EMnone
          else begin
            BlockCursor;
            ChWord := GetKey;
            EMC := EMchar;
            if InsertMode then
              FatCursor
            else
              NormalCursor;
          end;

        case EMC of
          EMchar :             {A character to enter the string}
            if CurCol <= MaxLineLength then begin
              if CurCol > StLen then
                FillChar(St[Succ(StLen)], CurCol-StLen, ' ');

              if not InsertMode then begin
                {overtype mode}
                if (CurCol <= MaxLineLength) then begin
                  St[CurCol] := Ch;
                  if (Ch <> ' ') and (CurCol > StLen) then begin {!!.12}
                    if InsertOK(CurCol-StLen) then begin         {!!.12}
                      StLen := CurCol;                           {!!.12}
                      Inc(CurCol);                               {!!.12}
                    end;                                         {!!.12}
                  end                                            {!!.12}
                  else                                           {!!.12}
                    Inc(CurCol);                                 {!!.12}
                end;
              end
              else if StLen < MaxLineLength then begin
                {insert mode}
                if CurCol > StLen then begin
                  if Ch = ' ' then
                    Inc(CurCol)
                  else if InsertOK(CurCol-StLen) then begin
                    StLen := CurCol;
                    St[CurCol] := Ch;
                    Inc(CurCol);
                  end;
                end
                else if InsertOK(1) then begin
                  Insert(Ch, St, CurCol);
                  Inc(CurCol);
                end;
              end;

              if WordWrap and (CurCol > Margin) and (StLen > Margin) then begin
                WrapLine(True);
                ForceRedraw := True;
              end;
            end else
              WrapLine(True);

          EMenter :            {new line}
            begin
              I := GetIndent(St);
              if InsertMode then begin
                if IndentMode and (CurCol <= StLen) and (I > 0) then
                  Insert(CharStr(' ', I), St, CurCol);
                SaveCurrentLine(True);
                if CurCol > StLen then
                  CurCol := Succ(StLen);
                InsLinePrim(CurLine, CurCol);
              end;

              if OK then begin
                GotoLine(CurLine+1, True);
                if IndentMode and InsertMode then
                  CurCol := Succ(I)
                else
                  CurCol := 1;
                OldCol := CurCol;
                if InsertMode then
                  ForceRedraw := True;
              end;
            end;

          EMuser0..EMuser19,   {user-defined exit commands}
          EMquit :             {exit from editor}
            begin
              SaveCurrentLine(True);
              Done := True;
            end;

          EMhome :             {Cursor to beginning of line}
            CurCol := 1;

          EMend :              {Cursor to end of line}
            CurCol := Succ(StLen);

          EMdelEol :           {Delete from cursor to end of line}
            if StLen >= CurCol then
              StLen := Pred(CurCol);

          EMdelLine :          {Delete entire line}
            if CurLine = TotalLines then begin
              StLen := 0;
              CurCol := 1;
              SaveCurrentLine(True);
            end
            else begin
              DelLinePrim(CurLine);
              CurCol := 1;
              LoadLine(CurLine, True);
              ForceRedraw := True;
            end;

          EMrestore :          {Restore default and continue}
            begin
              St := OldSt;
              CurCol := OldCol;
            end;

          EMleft :             {Cursor left by one character}
            if CurCol > 1 then
              Dec(CurCol);

          EMright :            {Cursor right by one character}
            Inc(CurCol);

          EMup :               {Cursor up one line}
            if CurLine > 1 then
              GotoLine(CurLine-1, True);

          EMdown :             {Cursor down one line}
            if CurLine < TotalLines then
              GotoLine(CurLine+1, True);

          EMscrollUp :         {Scroll display up one line}
            if LineAtTop > 1 then begin
              SaveCurrentLine(True);  {!!.10}
              ScrollDisplay(-1);
              I := LineAtTop+(YH-YL);
              if CurLine > I then
                GotoLine(I, True);
            end;

          EMscrollDown :       {Scroll display down one line}
            if LineAtTop < TotalLines then begin
              SaveCurrentLine(True);  {!!.10}
              ScrollDisplay(1);
              if CurLine < LineAtTop then
                GotoLine(LineAtTop, True);
            end;

          EMpageUp :           {Scroll display up one page}
            if LineAtTop > 1 then begin
              I := (YH-YL);
              if I > CurLine then begin
                PutLineAtTop(1);
                GotoLine(1, True);
              end
              else begin
                J := CurLine-LineAtTop;
                PutLineAtTop(LineAtTop-I);
                GotoLine(LineAtTop+J, True);
              end;
            end
            else
              GotoLine(1, True);

          EMpageDown :         {Scroll display down one page}
            begin
              I := Succ(YH-YL);
              if (TotalLines > I) or not ReadOnlyMode then
                if LineAtTop < TotalLines then begin
                  if TotalLines <= I then begin
                    PutLineAtTop(TotalLines);
                    GotoLine(TotalLines, True);
                  end
                  else begin
                    J := CurLine-LineAtTop;
                    PutLineAtTop(LineAtTop+Pred(I));
                    GotoLine(LineAtTop+J, True);
                  end;
                end;
            end;

          EMscreenTop :        {Cursor to top of screen}
            GotoLine(LineAtTop, True);

          EMscreenBot :        {Cursor to bottom of screen}
            GotoLine(LineAtTop+(YH-YL), True);

          EMtopOfFile :        {Cursor to top of file}
            TopOfFile;

          EMendOfFile :        {Cursor to bottom of file}
            begin
              I := YH-YL;
              if CurLine < TotalLines-I then
                PutLineAtTop(TotalLines-I);
              GotoLine(TotalLines, True);
              CurCol := Succ(StLen);
              OldCol := CurCol;
            end;

          EMtab :              {Tab}
            begin
              I := Succ(Succ(Pred(CurCol) div TabDelta) * TabDelta);
              if (not InsertMode) or (CurCol > StLen) then
                CurCol := I
              else if (CurCol <= StLen) then begin
                if InsertOK(I-CurCol) and (Margin-StLen > I-CurCol) then begin
                  Insert(CharStr(' ', I-CurCol), St, CurCol);
                  CurCol := I;
                end;
              end
            end;

          EMwordLeft :         {Cursor left one word}
            if CurCol > 1 then begin
              Dec(CurCol);
              while (CurCol >= 1) and ((CurCol > StLen) or (St[CurCol] = ' ')) do
                Dec(CurCol);
              while (CurCol >= 1) and (St[CurCol] <> ' ') do
                Dec(CurCol);
              Inc(CurCol);
            end
            else if CurLine > 1 then begin
              GotoLine(CurLine-1, True);
              CurCol := Succ(StLen);
              OldCol := CurCol;
            end;

          EMwordRight :        {Cursor right one word}
            begin
              if CurCol <= StLen then begin
                Inc(CurCol);
                while (CurCol <= StLen) and (St[CurCol] <> ' ') do
                  Inc(CurCol);
                while (CurCol <= StLen) and (St[CurCol] = ' ') do
                  Inc(CurCol);
              end
              else if CurLine < TotalLines then begin
                GotoLine(CurLine+1, True);
                CurCol := 1;
                OldCol := 1;
              end;
            end;

          EMdel :              {Delete current character}
            if CurCol <= StLen then
              Delete(St, CurCol, 1)
            else if DeleteJoinsLines then
              JoinAtEndOfLine;

          EMback :             {Backspace one character}
            if CurCol > 1 then begin
              Dec(CurCol);
              Delete(St, CurCol, 1);
            end
            else if CurLine > 1 then begin
              GotoLine(CurLine-1, True);
              CurCol := Succ(StLen);
              JoinLinePrim(CurLine+1);
              LoadLine(CurLine, True);
              ForceRedraw := True;
              OldCol := CurCol;
            end;

          EMdelWord :          {Delete word to right of cursor}
            if CurCol <= StLen then
              DeleteWordPrim
            else
              JoinAtEndOfLine;

          EMins :              {Toggle insert mode}
            ToggleInsertMode;

          EMindent :           {Toggle auto-indent mode}
            IndentMode := not IndentMode;

          EMwordWrap :         {Toggle word wrap}
            WordWrap := not WordWrap;

          EMreformatP :        {Reformat paragraph}
            if WordWrap then begin {!!.10}
              ReformatParagraph;
              CheckLineLimit;
            end;

          EMreformatG :        {Global reformat}
            if WordWrap then begin {!!.10}
              ReformatGlobally;
              CheckLineLimit;
            end;

          {$IFDEF UseMouse}

          EMmouse :            {Mouse select}
            if MemoMouseEnabled then
              MouseSelect;

          {$ENDIF}

          EMhelp :             {Help}
            if MemoHelpPtr <> nil then
              HelpRoutine(HelpForMemo, @EMCB, HelpTopic);
        end;

      until Done;

      {redraw the screen one last time}
      RedrawScreen;

      {restore break checking status}
      CheckBreak := SaveBreak;

      {Restore cursor position and shape}
      RestoreCursorState(CursorXY, CursorSL);

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}

      {return exit code}
      EditMemo := EMC;
    end;
  end;

  function AddMemoCommand(Cmd : EMtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
    {-Add a new command key assignment or change an existing one}
  begin
    AddMemoCommand :=
      AddCommandPrim(MemoKeySet, MemoKeyMax, Cmd, NumKeys, Key1, Key2);
  end;

  {$IFDEF UseMouse}
  procedure EnableMemoMouse;
    {-Enable mouse support in TPMEMO}
  begin
    if MouseInstalled and not MemoMouseEnabled then begin
      MemoKeyPtr := @ReadKeyOrButton;
      EnableEventHandling;
      MemoMouseEnabled := True;
    end;
  end;

  procedure DisableMemoMouse;
    {-Disable mouse support in TPMEMO}
  begin
    if MemoMouseEnabled then begin
      MemoKeyPtr := @ReadKeyWord;
      DisableEventHandling;
      MemoMouseEnabled := False;
    end;
  end;
  {$ENDIF}

  function ReadMemoFile(var Buffer; BufferSize : Word;
                        FName : string; var FSize : LongInt) : MemoStatusType;
    {-Read a file into Buffer, returning a status code}
  var
    Buf : array[1..65521] of Char absolute Buffer;
    F : file;
    I, BytesRead, BytesToRead : Word;
    MaxSize : LongInt;
  begin
    ReadMemoFile := mstNotFound;
    FSize := 0;
    Buf[1] := ^Z;
    if Length(FName) = 0 then
      Exit;

    {try to open file}
    Assign(F, FName);
    Reset(F, 1);
    I := IoResult;

    {check for invalid pathname}
    if I = 3 then
      ReadMemoFile := mstInvalidName;

    if I <> 0 then
      Exit;

    {check the file size}
    FSize := FileSize(F);
    MaxSize := LongInt(BufferSize)-Succ(SafetyMargin);
    if (FSize <= MaxSize) then
      BytesToRead := FSize
    else if AllowTruncation then
      BytesToRead := MaxSize
    else begin
      {file too big}
      ReadMemoFile := mstTooLarge;
      Close(F);
      I := IoResult;
      Exit;
    end;

    {read the file into the buffer}
    BlockRead(F, Buf, BytesToRead, BytesRead);
    if (BytesRead <> BytesToRead) then begin
      ReadMemoFile := mstReadError;
      Close(F);
      I := IoResult;
    end
    else begin
      Close(F);
      if IoResult = 0 then
        if FSize > MaxSize then
          ReadMemoFile := mstTruncated
        else
          ReadMemoFile := mstOK
      else
        ReadMemoFile := mstCloseError;
    end;

    {make sure there's a ^Z at the end of the buffer}
    Buf[BytesToRead+1] := ^Z;
  end;

  function SaveMemoFile(var EMCB : EMcontrolBlock; FName : string;
                        MakeBackup : Boolean) : MemoStatusType;
    {-Save the current file in the text buffer associated with EMCB}
  var
    F : file;
    I, BytesWritten : Word;

    function Exist(FName : string; var F : file) : Boolean;
      {-Return true and assigned file handle if file exists}
    var
      I : Word;
    begin
      Assign(F, FName);
      Reset(F);
      Exist := (IoResult = 0);
      Close(F);
      I := IoResult;
    end;

    procedure MakeBakFile(NewName : string);
      {-Make a backup file}
    var
      NF, BF : file;
      BakName : string;
    begin
      if Exist(NewName, NF) then begin
        BakName := ForceExtension(NewName, 'BAK');
        if Exist(BakName, BF) then
          Erase(BF);
        Rename(NF, BakName);
      end;
    end;

  begin
    with EMCB do begin
      if MakeBackup then
        MakeBakFile(FName);

      Assign(F, FName);
      Rewrite(F, 1);
      if IoResult <> 0 then begin
        SaveMemoFile := mstCreationError;
        Close(F);
        I := IoResult;
        Exit;
      end;

      BlockWrite(F, BufPtr^, TotalBytes, BytesWritten);
      if (BytesWritten <> TotalBytes) or (IoResult <> 0) then begin
        SaveMemoFile := mstWriteError;
        Close(F);
        Exit;
      end;

      Close(F);
      if IoResult <> 0 then begin
        SaveMemoFile := mstCloseError;
        Exit;
      end;

      {reset modified flag}
      Modified := False;

      SaveMemoFile := mstOK;
    end;
  end;

begin
  {initialize pointer to keyboard input routine}
  MemoKeyPtr := @ReadKeyWord;
end.
