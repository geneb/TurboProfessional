{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{$I TPDEFINE.INC}

{*********************************************************}
{*                   TPEDIT.PAS 5.22                     *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpEdit;
  {-Line editor and keyboard input routines}

interface

uses
  Dpmi,     {!!.22}
  TpCrt,
  {$IFDEF UseMouse}
  TpMouse,
  {$ENDIF}
  TpCmd,
  TpString;

  {.F-}
const
  RSnone      = 00; {Not a command}
  RSchar      = 01; {A character to enter the string}
  RSctrlChar  = 02; {Accept control character}
  RSenter     = 03; {Accept current string and quit}
  RSquit      = 04; {Restore default string and quit}
  RSrestore   = 05; {Restore default and continue}
  RShome      = 06; {Cursor to beginning of line}
  RSend       = 07; {Cursor to end of line}
  RSleft      = 08; {Cursor left by one character}
  RSright     = 09; {Cursor right by one character}
  RSwordLeft  = 10; {Cursor left one word}
  RSwordRight = 11; {Cursor right one word}
  RSback      = 12; {Backspace one character}
  RSdel       = 13; {Delete current character}
  RSdelEol    = 14; {Delete from cursor to end of line}
  RSdelBol    = 15; {Delete from beginning of line to cursor}
  RSdelLine   = 16; {Delete entire line}
  RSdelWord   = 17; {Delete word to right of cursor}
  RSins       = 18; {Toggle insert mode}
  RShelp      = 19; {Invoke help routine}
  RSuser0     = 20; {user-defined exit commands}
  RSuser1     = 21;
  RSuser2     = 22;
  RSuser3     = 23;
  RSuser4     = 24;
  RSuser5     = 25;
  RSuser6     = 26;
  RSuser7     = 27;
  RSuser8     = 28;
  RSuser9     = 29;
{.F+}

type
  RStype = RSnone..RSuser9;
  CharSet = set of Char;

const
  {the following govern the behavior of ReadString and the numeric reads}
  ForceUpper : Boolean = False; {force chars to uppercase?}
  CursorToEnd : Boolean = True; {start cursor at end of string? else at start}
  TrimBlanks : Boolean = True; {trim leading/trailing blanks? -- forced on
                                temporarily for the numeric reads}
  InsertByDefault : Boolean = True; {default to insert mode?}
  EditSize : Byte = 0;       {if NOT zero, this overrides MaxLen as edit field width}
  ClearFirstChar : Boolean = True; {clear string if first char entered is ASCII}
  PasswordMode : Boolean = False; {suppress display of actual string?}
  PasswordChar : Char = ^G;  {character used to represent text in password mode}
  EditMapCtrls : Boolean = True; {map control characters to alphabetics?}
  RSpadChar : Char = ' ';    {character used to pad strings being edited}
  HouseCursorAtEnd : Boolean = True; {extra character of width to hold cursor
                                      when string is full?}

  {the following govern the behavior of ReadCharacter and YesOrNo}
  ShowReadChar : Boolean = False; {display the character pressed?}
  HideCursorInReadChar : Boolean = False; {cursor hidden?}

 {the following governs whether coordinates of all TPEDIT routines are
  interpreted relative to the current window or to the entire screen.}
  WindowRelative : Boolean = False;

var
  EditKeyPtr : Pointer;      {pointer to routine to return next keystroke}
  EditHelpPtr : Pointer;     {pointer to routine to display help}
  EditHelpIndex : Word;      {current help topic}
  RSCommand : RStype;        {last command given in ReadString}
  RSChWord : Word;           {last key entered in ReadString}

  {$IFDEF UseMouse}
const
  {True if mouse support is enabled}
  EditMouseEnabled : Boolean = False;

  {.F-}
  {used to translate mouse buttons to keys}
  EditButtonCodes : array[$E9..$EF] of Word = (
    $011B,  {all three buttons         = ESC}
    $011B,  {right and center buttons  = ESC}
    $011B,  {left and center buttons   = ESC}
    $011B,  {center button             = ESC}
    $3B00,  {both buttons              = F1}
    $011B,  {right button              = ESC}
    $1C0D); {left button               = Enter}
  {$ENDIF}
{.F+}

procedure ReadString(Prompt : string;
                     Row, Col, MaxLen : Byte;
                     PromptAttr, StringAttr, CtrlAttr : Byte;
                     var Escaped : Boolean;
                     var S : string);
  {-Prompt for and receive a string}

procedure ReadLongInt(Prompt : string;
                      Row, Col, MaxLen : Byte;
                      PromptAttr, StringAttr : Byte;
                      LLo, LHi : LongInt;
                      var Escaped : Boolean;
                      var L : LongInt);
  {-Prompt for and receive a long integer argument in the range LLo to LHi}

procedure ReadInteger(Prompt : string;
                      Row, Col, MaxLen : Byte;
                      PromptAttr, StringAttr : Byte;
                      NLo, NHi : Integer;
                      var Escaped : Boolean;
                      var N : Integer);
  {-Prompt for and receive an integer argument in the range NLo to NHi}

procedure ReadWord(Prompt : string;
                   Row, Col, MaxLen : Byte;
                   PromptAttr, StringAttr : Byte;
                   WLo, WHi : Word;
                   var Escaped : Boolean;
                   var W : Word);
  {-Prompt for and receive a word argument in the range WLo to WHi}

procedure ReadReal(Prompt : string;
                   Row, Col, MaxLen : Byte;
                   PromptAttr, StringAttr : Byte;
                   DecimalPlaces : Byte;
                   RLo, RHi : TpString.Float;
                   var Escaped : Boolean;
                   var R : TpString.Float);
  {-Prompt for and receive a real argument in the range RLo to RHi}

procedure ReadCharacter(Prompt : string;
                        Row, Col : Byte;
                        PromptAttr : Byte;
                        Accept : CharSet;
                        var Ch : Char);
  {-Display a prompt and wait for a key in Accept}

function YesOrNo(Prompt : string;
                 Row, Col : Byte;
                 PromptAttr : Byte;
                 Default : Char) : Boolean;
  {-Return true for yes, false for no}

function AddEditCommand(Cmd : RStype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

  {$IFDEF UseMouse}
procedure EnableEditMouse;
  {-Enable mouse support in TPEDIT}

procedure DisableEditMouse;
  {-Disable mouse support in TPEDIT}
  {$ENDIF}

  {.F-}
const
  {Keystroke to command mapping}
  EditKeyMax = 150;   {last available slot in EditKeySet}
  {ID string for installation programs}
  EditKeyID : string[16] = 'tpedit key array';
  {default key assignments}
  EditKeySet : array[0..EditKeyMax] of Byte = (
   {length keys         command type      key sequence}
    3,     $00, $00,    RSquit,          {^Break}
    3,     $00, $3B,    RShelp,          {F1}
    3,     $00, $47,    RShome,          {Home}
    3,     $00, $4B,    RSleft,          {Left}
    3,     $00, $4D,    RSright,         {Right}
    3,     $00, $4F,    RSend,           {End}
    3,     $00, $52,    RSins,           {Ins}
    3,     $00, $53,    RSdel,           {Del}
    3,     $00, $73,    RSwordLeft,      {^Left}
    3,     $00, $74,    RSwordRight,     {^Right}
    3,     $00, $75,    RSdelEol,        {^End}
    3,     $00, $77,    RSdelBol,        {^Home}
    2,     $01,         RSwordLeft,      {^A}
    2,     $04,         RSright,         {^D}
    2,     $06,         RSwordRight,     {^F}
    2,     $07,         RSdel,           {^G}
    2,     $08,         RSback,          {^H, Bksp}
    2,     $0D,         RSenter,         {^M, Enter}
    2,     $10,         RSctrlChar,      {^P}
    2,     $12,         RSrestore,       {^R}
    2,     $13,         RSleft,          {^S}
    2,     $14,         RSdelWord,       {^T}
    2,     $18,         RSdelLine,       {^X}
    2,     $19,         RSdelLine,       {^Y}
    2,     $1B,         RSquit,          {Esc}
    2,     $7F,         RSback,          {^Bksp}
    3,     $11, $04,    RSend,           {^Q^D}
    3,     $11, $0C,    RSrestore,       {^Q^L}
    3,     $11, $13,    RShome,          {^Q^S}
    3,     $11, $19,    RSdelEol,        {^Q^Y}
  {$IFDEF UseMouse}
    3,     $00, $EF,    RSenter,         {click left  = Enter}
    3,     $00, $EE,    RSquit,          {click right = ESC}
    3,     $00, $ED,    RShelp,          {click both  = help}
  {$ELSE}
                   0, 0, 0, 0, 0,        {110}
    0, 0, 0, 0, 0, 0, 0,
  {$ENDIF}
    {-----------pad to end of array----------}
                         0, 0, 0,        {120}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {130}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,        {140}
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0);       {150}
{.F+}

  {==========================================================================}

implementation

type
  String80 = string[80];
const
  NumError : string[32] = 'Invalid number. Press any key...';

  procedure HelpRoutine(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Call routine pointed to by EditHelpPtr}
  inline(
    $FF/$1E/>EditHelpPtr);   {call dword ptr [>EditHelpPtr]}

  function GetKey : Word;
    {-Call routine pointed to by EditKeyPtr}
  inline(
    $FF/$1E/>EditKeyPtr);    {call dword ptr [>EditKeyPtr]}

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

  procedure ReadString(Prompt : string;
                       Row, Col, MaxLen : Byte;
                       PromptAttr, StringAttr, CtrlAttr : Byte;
                       var Escaped : Boolean;
                       var S : string);
    {-Prompt for and receive a string}
  var
    Ch : Char absolute RSChWord;
    St : string;
    StLen : Byte absolute St;
    CursorSL : Word;
    CursorXY : Word;
    StCol : Byte;
    Sp : Byte;
    DelEnd : Byte;
    Inserting : Boolean;
    FirstChar : Boolean;
    SaveBreak : Boolean;
    Done : Boolean;
    StOffset : Byte;
    EditLen : Byte;
    MaxBoxLen : Byte;
    RSC : RStype absolute RSCommand;
    {$IFDEF UseMouse}
    SaveWaitState : Boolean;
    SaveMouse : Boolean;
    {$ENDIF}

    function TrimSpaces(S : string) : string;
      {-Return a string with leading and trailing blanks removed}
    begin
      while (Length(S) > 0) and (S[1] = ' ') do
        Delete(S, 1, 1);
      while (Length(S) > 0) and (S[Length(S)] = ' ') do
        Dec(S[0]);
      TrimSpaces := S;
    end;

    procedure ToggleInsertMode;
     {-Toggle between insert and overtype mode, keeping BIOS keyboard flag up
       to date}
    var
      BiosKbdFlag : ^Byte {absolute $0040 : $0017};                   {!!.22}
    begin
      BiosKbdFlag := Ptr(BiosDataSele, $0017);                        {!!.22}
      {toggle insert flag}
      Inserting := not Inserting;

      {use fat cursor if inserting}
      if Inserting then begin
        FatCursor;
        BiosKbdFlag^ := BiosKbdFlag^ or $80;                          {!!.22}
      end
      else begin
        NormalCursor;
        BiosKbdFlag^ := BiosKbdFlag^ and $7F;                         {!!.22}
      end;
    end;

    procedure DrawString;
      {-Draw the string}
    var
      A, I, SaveStLen : Byte;
      C : Char;
      {$IFDEF UseMouse}
      SaveMouse : Boolean;
      {$ENDIF}
    begin
      {pad the end of the string}
      FillChar(St[Succ(StLen)], MaxBoxLen-StLen, RSpadChar);

      {make sure padding is drawn}
      SaveStLen := StLen;
      StLen := EditLen;

      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      {draw the string and restore the length byte}
      for I := 1 to StLen do begin
        if PasswordMode then begin
          if I <= SaveStLen then
            C := PasswordChar
          else
            C := RSpadChar;
          A := StringAttr;
        end
        else begin
          C := St[StOffset+I];
          if (C < ' ') then begin
            if EditMapCtrls then
              C := Chr(Ord(C) or $40);
            A := CtrlAttr;
          end
          else
            A := StringAttr;
        end;
        if WindowRelative then
          FastWriteWindow(C, Row, StCol+Pred(I), A)
        else
          FastWrite(C, Row, StCol+Pred(I), A);
      end;
      StLen := SaveStLen;

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}
    end;

  begin
    {Determine if EditSize is appropriate here}
    if MaxLen > 254 then
      MaxLen := 254;
    if HouseCursorAtEnd then
      MaxBoxLen := MaxLen+1
    else
      MaxBoxLen := MaxLen;
    if (EditSize = 0) or (EditSize >= MaxBoxLen) then
      EditLen := MaxBoxLen
    else
      EditLen := EditSize;

    {Store cursor position and shape}
    GetCursorState(CursorXY, CursorSL);

    {Save break checking state}
    SaveBreak := CheckBreak;
    CheckBreak := False;
    Escaped := False;
    StOffset := 0;

    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    {Write prompt}
    if WindowRelative then
      FastWriteWindow(Prompt, Row, Col, PromptAttr)
    else
      FastWrite(Prompt, Row, Col, PromptAttr);
    StCol := Col+Length(Prompt);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    {Get the default string}
    St := S;
    if StLen > MaxLen then
      StLen := MaxLen;
    if CursorToEnd then
      Sp := Succ(StLen)
    else
      Sp := 1;
    FirstChar := True;

    {default to insert mode on if InsertByDefault is true}
    Inserting := not InsertByDefault;
    ToggleInsertMode;

    {Loop reading keys}
    Done := False;
    repeat
      {Position cursor and redraw string}
      if Sp > MaxLen then
        if HouseCursorAtEnd then
          Sp := Succ(MaxLen)
        else
          Sp := MaxLen;
      if Sp > EditLen+StOffset then
        StOffset := Sp-EditLen
      else if Sp < Succ(StOffset) then
        StOffset := Pred(Sp);
      DrawString;
      if WindowRelative then
        GoToXY(StCol+Pred(Sp)-StOffset, Row)
      else
        GoToXYAbs(StCol+Pred(Sp)-StOffset, Row);

      {$IFDEF UseMouse}
      if EditMouseEnabled then begin
        SaveWaitState := WaitForButtonRelease;
        WaitForButtonRelease := True;
      end;
      {$ENDIF}

      RSC := GetCommand(EditKeySet, EditKeyPtr, RSChWord);

      {$IFDEF UseMouse}
      if EditMouseEnabled then
        WaitForButtonRelease := SaveWaitState;
      {$ENDIF}

      {deal with control characters if desired}
      if RSC = RSctrlChar then
        {don't allow control characters if attributes are the same}
        if (CtrlAttr = StringAttr) and EditMapCtrls then
          RSC := RSnone
        else begin
          BlockCursor;
          RSChWord := GetKey;
          RSC := RSchar;
          if Inserting then
            FatCursor
          else
            NormalCursor;
        end;

      if (RSC = RSchar) and ForceUpper then
        Ch := Upcase(Ch);

      {allow editing of the existing string}
      if FirstChar then begin
        FirstChar := False;

        if ClearFirstChar then
          {if first key is a character, clear the input string}
          if (RSC = RSchar) then begin
            StOffset := 0;
            StLen := 0;
            Sp := 1;
          end;
      end;

      case RSC of
        RSchar :             {A character to enter the string}
          if not Inserting then begin
            {overtype mode}
            if Sp <= MaxLen then begin
              St[Sp] := Ch;
              if Sp > StLen then
                StLen := Sp;
              Inc(Sp);
            end;
          end
          else
            {insert mode}
            if StLen < MaxLen then begin
              Insert(Ch, St, Sp);
              Inc(Sp);
            end;

        RSuser0..RSuser9,    {user-defined exit commands}
        RSenter :            {Accept current string and quit}
          Done := True;

        RSquit :             {Restore default string and quit}
          begin
            St := S;
            if CursorToEnd then
              Sp := Succ(StLen)
            else
              Sp := 1;
            if StLen > MaxLen then
              StLen := MaxLen;
            Done := True;
            Escaped := True;
          end;

        RShome :             {Cursor to beginning of line}
          Sp := 1;

        RSend :              {Cursor to end of line}
          Sp := Succ(StLen);

        RSdelEol :           {Delete from cursor to end of line}
          St := Copy(St, 1, Pred(Sp));

        RSdelBol :           {Delete from beginning of line to the cursor}
          begin
            Delete(St, 1, Pred(Sp));
            Sp := 1;
          end;

        RSdelLine :          {Delete entire line}
          begin
            StLen := 0;
            Sp := 1;
          end;

        RSrestore :          {Restore default and continue}
          begin
            St := S;
            if StLen > MaxLen then
              StLen := MaxLen;
            if CursorToEnd then
              Sp := Succ(StLen)
            else
              Sp := 1;
          end;

        RSleft :             {Cursor left by one character}
          if Sp > 1 then
            Dec(Sp);

        RSright :            {Cursor right by one character}
          if Sp <= StLen then
            Inc(Sp);

        RSwordLeft :         {Cursor left one word}
          if Sp > 1 then begin
            Dec(Sp);
            while (Sp >= 1) and ((Sp > StLen) or (St[Sp] = ' ')) do
              Dec(Sp);
            while (Sp >= 1) and (St[Sp] <> ' ') do
              Dec(Sp);
            Inc(Sp);
          end;

        RSwordRight :        {Cursor right one word}
          if Sp <= StLen then begin
            Inc(Sp);
            while (Sp <= StLen) and (St[Sp] <> ' ') do
              Inc(Sp);
            while (Sp <= StLen) and (St[Sp] = ' ') do
              Inc(Sp);
          end;

        RSdel :              {Delete current character}
          if Sp <= StLen then
            Delete(St, Sp, 1);

        RSback :             {Backspace one character}
          if Sp > 1 then begin
            Dec(Sp);
            Delete(St, Sp, 1);
            if StOffset > 0 then
              {String horizontally scrolled}
              if StOffset+EditLen >= StLen then
                {The rightmost portion of the string is displayed, so scroll}
                Dec(StOffset);
          end;

        RSdelWord :          {Delete word to right of cursor}
          if Sp <= StLen then begin
            {start deleting at the cursor}
            DelEnd := Sp;

            {delete all of the current word, if any}
            if St[Sp] <> ' ' then
              while (St[DelEnd] <> ' ') and (DelEnd <= StLen) do
                Inc(DelEnd);

            {delete any spaces prior to the next word, if any}
            while (St[DelEnd] = ' ') and (DelEnd <= StLen) do
              Inc(DelEnd);

            Delete(St, Sp, DelEnd-Sp);
          end;

        RSins :              {Toggle insert mode}
          ToggleInsertMode;

        RShelp :             {Help}
          if EditHelpPtr <> nil then
            HelpRoutine(HelpForEdit, nil, EditHelpIndex);
      end;
    until Done;

    {draw the string one last time}
    if Sp > MaxLen then
      if HouseCursorAtEnd then
        Sp := Succ(MaxLen)
      else
        Sp := MaxLen;
    if Sp > EditLen+StOffset then
      StOffset := Sp-EditLen
    else if Sp < Succ(StOffset) then
      StOffset := Pred(Sp);
    DrawString;

    {trim leading and trailing blanks if desired}
    if TrimBlanks then
      S := TrimSpaces(St)
    else
      S := St;

    {restore break checking status}
    CheckBreak := SaveBreak;

    {Restore cursor position and shape}
    RestoreCursorState(CursorXY, CursorSL);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}
  end;

  procedure ReadLongInt(Prompt : string;
                        Row, Col, MaxLen : Byte;
                        PromptAttr, StringAttr : Byte;
                        LLo, LHi : LongInt;
                        var Escaped : Boolean;
                        var L : LongInt);
    {-Prompt for and receive a long integer argument in the range LLo to LHi}
  var
    S : String80;
    Code, MaxWidth : Word;
    SaveTrimBlanks : Boolean;
    LTemp : LongInt;
    SaveMap : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  label
    ExitPoint;
  begin
    {Set default value}
    Str(L, S);

    {$IFDEF UseMouse}
    SaveMouse := MouseCursorOn;
    {$ENDIF}

    {force blank trimming}
    SaveTrimBlanks := TrimBlanks;
    TrimBlanks := True;

    {force control character mapping}
    SaveMap := EditMapCtrls;
    EditMapCtrls := True;

    repeat
      {read the string and convert back to longint}
      ReadString(Prompt, Row, Col, MaxLen, PromptAttr, StringAttr, StringAttr,
        Escaped, S);

      {if ESCaping, redisplay the number}
      if Escaped then begin
        Str(L, S);

        {$IFDEF UseMouse}
        HideMouse;
        {$ENDIF}

        if WindowRelative then
          FastWriteWindow(Pad(S, MaxLen), Row, Col+Length(Prompt), StringAttr)
        else
          FastWrite(Pad(S, MaxLen), Row, Col+Length(Prompt), StringAttr);

        goto ExitPoint;
      end;

      {don't range check if both bounds are 0}
      Val(S, LTemp, Code);
      if not(LLo = LHi) then
        {set error condition if answer not in valid range}
        if (LTemp < LLo) or (LTemp > LHi) then
          Code := 1;

      {validate entry}
      MaxWidth := Succ(Length(Prompt)+MaxLen);
      if Code <> 0 then
        {display an error message if possible}
        if MaxWidth >= SizeOf(NumError) then begin
          {$IFDEF UseMouse}
          HideMouse;
          {$ENDIF}

          if WindowRelative then
            FastWriteWindow(Pad(NumError, MaxWidth), Row, Col, StringAttr)
          else
            FastWrite(Pad(NumError, MaxWidth), Row, Col, StringAttr);

          {$IFDEF UseMouse}
          ShowMousePrim(SaveMouse);
          {$ENDIF}

          RSChWord := GetKey;
        end
        else
          {if not, beep}
          Write(^G);
    until (Code = 0);
    L := LTemp;

ExitPoint:
    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    {restore previous state}
    TrimBlanks := SaveTrimBlanks;
    EditMapCtrls := SaveMap;
  end;

  procedure ReadInteger(Prompt : string;
                        Row, Col, MaxLen : Byte;
                        PromptAttr, StringAttr : Byte;
                        NLo, NHi : Integer;
                        var Escaped : Boolean;
                        var N : Integer);
    {-Prompt for and receive an integer argument in the range NLo to NHi}
  var
    L : LongInt;
  begin
    L := LongInt(N);
    if (NLo = NHi) then begin
      NLo := -32768;
      NHi := MaxInt;
    end;
    ReadLongInt(Prompt, Row, Col, MaxLen, PromptAttr, StringAttr,
      LongInt(NLo), LongInt(NHi), Escaped, L);
    N := Integer(L);
  end;

  procedure ReadWord(Prompt : string;
                     Row, Col, MaxLen : Byte;
                     PromptAttr, StringAttr : Byte;
                     WLo, WHi : Word;
                     var Escaped : Boolean;
                     var W : Word);
    {-Prompt for and receive a word argument in the range WLo to WHi}
  var
    L : LongInt;
  begin
    L := LongInt(W);
    if (WLo = WHi) then begin
      WLo := 0;
      WHi := 65535;
    end;
    ReadLongInt(Prompt, Row, Col, MaxLen, PromptAttr, StringAttr,
      LongInt(WLo), LongInt(WHi), Escaped, L);
    W := Word(L);
  end;

  procedure ReadReal(Prompt : string;
                     Row, Col, MaxLen : Byte;
                     PromptAttr, StringAttr : Byte;
                     DecimalPlaces : Byte;
                     RLo, RHi : TpString.Float;
                     var Escaped : Boolean;
                     var R : TpString.Float);
    {-Prompt for and receive a real argument in the range RLo to RHi}
  var
    S : String80;
    Code, MaxWidth : Word;
    RTemp : TpString.Float;
    SaveTrimBlanks : Boolean;
    SaveMap : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  label
    ExitPoint;
  begin
    {Save original value}
    RTemp := R;

    {force blank trimming}
    SaveTrimBlanks := TrimBlanks;
    TrimBlanks := True;

    {force control character mapping}
    SaveMap := EditMapCtrls;
    EditMapCtrls := True;

    {$IFDEF UseMouse}
    SaveMouse := MouseCursorOn;
    {$ENDIF}

    {Set default value}
    S := Real2Str(R, 0, DecimalPlaces);

    repeat
      {read the string and convert back to real}
      ReadString(Prompt, Row, Col, MaxLen, PromptAttr, StringAttr, StringAttr,
        Escaped, S);

      {if ESCaping, redisplay the number}
      if Escaped then begin
        S := Real2Str(R, 0, DecimalPlaces);

        {$IFDEF UseMouse}
        HideMouse;
        {$ENDIF}

        if WindowRelative then
          FastWriteWindow(Pad(S, MaxLen), Row, Col+Length(Prompt), StringAttr)
        else
          FastWrite(Pad(S, MaxLen), Row, Col+Length(Prompt), StringAttr);

        goto ExitPoint;
      end;

      {don't range check if both bounds are 0}
      Code := 0;
      if not Str2Real(S, RTemp) then
        Code := 1
      else if not(RLo = RHi) then
        {set error condition if answer not in valid range}
        if (RTemp < RLo) or (RTemp > RHi) then
          Code := 1;

      {validate entry}
      MaxWidth := Succ(Length(Prompt)+MaxLen);
      if Code <> 0 then
        {display an error message if possible}
        if MaxWidth >= SizeOf(NumError) then begin

          {$IFDEF UseMouse}
          HideMouse;
          {$ENDIF}

          if WindowRelative then
            FastWriteWindow(Pad(NumError, MaxWidth), Row, Col, StringAttr)
          else
            FastWrite(Pad(NumError, MaxWidth), Row, Col, StringAttr);

          {$IFDEF UseMouse}
          ShowMousePrim(SaveMouse);
          {$ENDIF}

          RSChWord := GetKey;
        end
        else
          {if not, beep}
          Write(^G);
    until (Code = 0);
    R := RTemp;

ExitPoint:
    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    {restore previous state}
    TrimBlanks := SaveTrimBlanks;
    EditMapCtrls := SaveMap;
  end;

  procedure ReadCharacter(Prompt : string;
                          Row, Col : Byte;
                          PromptAttr : Byte;
                          Accept : CharSet;
                          var Ch : Char);
    {-Display a prompt and wait for a key in Accept}
  var
    CursorSL : Word;
    CursorXY : Word;
    C : Char absolute RSChWord;
    SaveBreak : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    {Store cursor position and shape}
    GetCursorState(CursorXY, CursorSL);

    {save break checking state}
    SaveBreak := CheckBreak;
    CheckBreak := False;

    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    {Write prompt - extra blank is a spot for the character to be read}
    if WindowRelative then
      FastWriteWindow(Prompt+RSpadChar, Row, Col, PromptAttr)
    else
      FastWrite(Prompt+RSpadChar, Row, Col, PromptAttr);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    {Display and position cursor}
    Inc(Col, Length(Prompt));
    if HideCursorInReadChar then
      HiddenCursor
    else begin
      NormalCursor;
      if WindowRelative then
        GoToXY(Col, Row)
      else
        GoToXYAbs(Col, Row);
    end;

    {read keys until valid response is given}
    repeat
      RSChWord := GetKey;

      {$IFDEF UseMouse}
      {translate mouse buttons to keys}
      if EditMouseEnabled and (RSChWord >= MouseThree) and (RSChWord <= MouseLft) then
        RSChWord := EditButtonCodes[Hi(RSChWord)];
      {$ENDIF}

      if C = #0 then
        {extended scan code--return high byte and set high bit}
        Ch := Char(Hi(RSChWord) or $80)
      else begin
        Ch := Upcase(C);
        if ShowReadChar and (Ch in Accept) then begin

          {$IFDEF UseMouse}
          HideMouse;
          {$ENDIF}

          if WindowRelative then
            FastWriteWindow(Ch, Row, Col, PromptAttr)
          else
            FastWrite(Ch, Row, Col, PromptAttr);

          {$IFDEF UseMouse}
          ShowMousePrim(SaveMouse);
          {$ENDIF}
        end;
      end;
    until (Ch in Accept);

    {restore break checking status}
    CheckBreak := SaveBreak;

    {Restore cursor position and shape}
    RestoreCursorState(CursorXY, CursorSL);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}
  end;

  function YesOrNo(Prompt : string;
                   Row, Col : Byte;
                   PromptAttr : Byte;
                   Default : Char) : Boolean;
    {-Return true for yes, false for no}
  var
    Ch : Char;
    SaveShow : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    {$IFDEF UseMouse}
    SaveMouse := MouseCursorOn;
    {$ENDIF}

    SaveShow := ShowReadChar;
    ShowReadChar := False;
    case Upcase(Default) of
      'Y', 'N' :
        begin
          {a default answer was specified, <Enter> accepts it}
          Prompt := Prompt+' ['+Upcase(Default)+'] ';
          ReadCharacter(Prompt, Row, Col, PromptAttr, ['Y', 'N', ^M], Ch);
          if Ch = ^M then
            Ch := Upcase(Default);
        end;
    else
      {no default answer, just prompt and wait for valid key}
      ReadCharacter(Prompt, Row, Col, PromptAttr, ['Y', 'N'], Ch)
    end;
    ShowReadChar := SaveShow;

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    if ShowReadChar then
      if WindowRelative then
        FastWriteWindow(Ch, Row, Col+Length(Prompt), PromptAttr)
      else
        FastWrite(Ch, Row, Col+Length(Prompt), PromptAttr);

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    YesOrNo := (Ch = 'Y');
  end;

  function AddEditCommand(Cmd : RStype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
    {-Add a new command key assignment or change an existing one}
  begin
    AddEditCommand :=
    AddCommandPrim(EditKeySet, EditKeyMax, Cmd, NumKeys, Key1, Key2);
  end;

  {$IFDEF UseMouse}
  procedure EnableEditMouse;
    {-Enable mouse support in TPEDIT}
  begin
    if MouseInstalled and not EditMouseEnabled then begin
      EditKeyPtr := @ReadKeyOrButton;
      EnableEventHandling;
      EditMouseEnabled := True;
    end;
  end;

  procedure DisableEditMouse;
    {-Disable mouse support in TPEDIT}
  begin
    if EditMouseEnabled then begin
      EditKeyPtr := @ReadKeyWord;
      DisableEventHandling;
      EditMouseEnabled := False;
    end;
  end;
  {$ENDIF}

begin
  {initialize procedure pointers}
  EditHelpPtr := nil;
  EditKeyPtr := @ReadKeyWord;
end.
