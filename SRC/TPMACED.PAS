{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
  {$DEFINE FPlus}
{$ENDIF}

{*********************************************************}
{*                   TPMACED.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpMacEd;
  {-Macro editor for Turbo Professional macros}

interface

uses
  Dpmi, Dos, TpCrt, TpInt, TpMacro;  {!!.22}

var
  TempMacro : MacroRec;      {temporary macro used for editing}
  MacEdKeyPtr : Pointer;     {pointer to routine to return next keystroke}
  MacEdKeypressedPtr : Pointer; {pointer to keypressed routine}
const
 NonMacroKey = $FFFF;        {if passed to EditKeys, Key is not translated into
                              a string and displayed while editing}
 MacEdHelpPtr : Pointer = nil; {pointer to optional help routine}

function EditKeys(Key : Word; var Macro : MacroRec;
                  MinCol, MinRow, MaxCol, MaxRow,
                  Dim, Bright : Byte;
                  var Modified : Boolean) : MacroRecPtr;
  {-Edit the Macro associated with Key.}

  {==========================================================================}

implementation

const
  MaxScanCode = $A500;       {scan code for Alt-Tab}
var
  KnownKeyPtr,               {key whose location is known}
  KnownRow,                  {row for KnownKeyPtr}
  KnownCol,                  {column for KnownKeyPtr}
  LoCol,                     {dimensions for the editing window}
  HiCol,
  LoRow,
  HiRow,
  RowAtTop,                  {row currently displayed at top of window}
  RowAtBottom : Word;        {row currently displayed at bottom of window}

  {$IFDEF FPlus}
    {$F-}
  {$ENDIF}

  {$L TPMACED.OBJ}

  procedure ComputeScreenPos(KeyPtr : Word; var Row, Col : Word); external;
  {-Compute the Row and Col positions for KeyPtr}

  {$IFDEF FPlus}
    {$F+}
  {$ENDIF}

  function GetKey : Word;
    {-Call routine pointed to by MacEdKeyPtr}
  inline(
    $FF/$1E/>MacEdKeyPtr);   {call dword ptr [>MacEdKeyPtr]}

  function GetKeyPressed : Boolean;
    {-Call routine pointed to by MacEdKeypressedPtr}
  inline(
    $FF/$1E/>MacEdKeypressedPtr); {call dword ptr [>MacEdKeypressedPtr]}

  procedure CallHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Call routine pointed to by MacEdHelpPtr}
  inline(
    $FF/$1E/>MacEdHelpPtr);  {call dword ptr [>MacEdHelpPtr]}

  function EditKeys(Key : Word; var Macro : MacroRec;
                    MinCol, MinRow, MaxCol, MaxRow,
                    Dim, Bright : Byte;
                    var Modified : Boolean) : MacroRecPtr;
    {-Edit the Macro associated with Key.}
  const
    ScrollMask = $10;        {mask for scroll lock bit}
    Instructions : string[71] =
    ' '^[^X^Y^Z' to move, '^Q'Ù to accept, <Esc> to cancel, <ScrollLock> for literal ';
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
    KbFlag : ^Byte {absolute $40 : $17}; {!!.22}
    CurRow, CurCol, Width : Word;
    ScrollLock, LastScroll : Boolean;
    Done, Inserting : Boolean;
    KeyPtr : Word;
    KeyName : string[12];
    BlankLine : string[255]; {!!.22}
    SaveTextAttr : Byte;
    RP, CP : Word;
    SaveXY, SaveSL : Word;

    procedure ClrEol(Row, Col : Byte);
      {-Clear to end of line}
    begin
      BlankLine[0] := Chr(Succ(HiCol-Col));
      FastWrite(BlankLine, Row, Col, Dim);
    end;

    procedure ClrEow(Row, Col : Byte);
      {-Clear to end of window}
    begin
      ClrEol(Row, Col);
      for Row := Succ(Row) to HiRow do
        ClrEol(Row, LoCol);
    end;

    procedure ShowCommandMode;
      {-Indicate whether we're in Command or Literal mode}
    const
      ComLit : array[Boolean] of string[9] = (' Command ', ' Literal ');
    begin
      FastWrite(ComLit[ScrollLock], Pred(LoRow), HiCol-21, Dim);
    end;

    procedure ShowInsertMode;
      {-Indicate whether we're in Insert or Overtype mode}
    const
      InsOver : array[Boolean] of string[10] = (' Overtype ', '  Insert  ');
    begin
      if Inserting then
        FatCursor
      else
        NormalCursor;
      FastWrite(InsOver[Inserting], Pred(LoRow), HiCol-10, Dim);
    end;

    procedure DisplayKeys(Row, Col : Word; OneRow : Boolean; KeyPtr : Word);
      {-Write the macro to the screen}
    var
      Attr : Byte;
      S : string[11];
      Special : Boolean;
    begin
      if (Row < RowAtTop) then begin
        ScrollWindowDown(LoCol, LoRow, HiCol, HiRow, 1);
        Dec(RowAtTop);
        Dec(RowAtBottom);

        {point to first key on the row}
        ComputeScreenPos(KeyPtr, RP, CP);
        while (RP = Row) and (KeyPtr > 1) do begin
          Dec(KeyPtr);
          ComputeScreenPos(KeyPtr, RP, CP);
        end;
      end
      else
        if (Row > RowAtBottom) then begin
          ScrollWindowUp(LoCol, LoRow, HiCol, HiRow, 1);
          Inc(RowAtTop);
          Inc(RowAtBottom);

          {point to first key on the row}
          ComputeScreenPos(KeyPtr, RP, CP);
          while (RP = Row) and (KeyPtr > 1) do begin
            Dec(KeyPtr);
            ComputeScreenPos(KeyPtr, RP, CP);
          end;
        end;

      while (KeyPtr <= TempMacro.NumKeys) do begin
        {convert the key to a string}
        KeyToString(TempMacro.KeyArray[KeyPtr], S, Special);
        Inc(KeyPtr);

        {Check for wrap}
        if (Col+Length(S) > HiCol) then begin
          {String starts on next row}
          ClrEol(Row-(RowAtTop-LoRow), Col);
          Inc(Row);
          if (Row > RowAtBottom) or OneRow then
            Exit
          else
            Col := LoCol;
        end;
        if Special then
          Attr := Bright
        else
          Attr := Dim;

        FastWrite(S, Row-(RowAtTop-LoRow), Col, Attr);
        Inc(Col, Length(S));
      end;
      ClrEow(Row-(RowAtTop-LoRow), Col);
    end;

    procedure InsertKey(Key : Word; var KeyPtr : Word);
      {-Insert a key into the current macro at KeyPtr}
    var
      NextRP, NextCP : Word;
    begin
      with TempMacro do begin
        if ((NumKeys = MaxKeysInMacro) and Inserting) or (Key > MaxScanCode) then
          Exit;

        if not(Inserting) or (KeyPtr > NumKeys) then begin
          KeyArray[KeyPtr] := Key;
          if KeyPtr > NumKeys then begin
            NumKeys := KeyPtr;
            KeyArray[Succ(NumKeys)] := EndOfMacro;
          end;
        end
        else begin
          Inc(NumKeys);
          Move(KeyArray[KeyPtr], KeyArray[Succ(KeyPtr)],
            Succ(NumKeys-KeyPtr) shl 1);
          KeyArray[KeyPtr] := Key;
        end;

        {compute positions of current key and next key}
        ComputeScreenPos(KeyPtr, RP, CP);
        ComputeScreenPos(Succ(KeyPtr), NextRP, NextCP);

        {scroll window if key we're about to point to is off the screen}
        if (NextRP > RowAtBottom) then begin
          ScrollWindowUp(LoCol, LoRow, HiCol, HiRow, 1);
          Inc(RowAtTop);
          Inc(RowAtBottom);
        end;

        DisplayKeys(RP, CP, False, KeyPtr);
        if KeyPtr < MaxKeysInMacro then
          Inc(KeyPtr);
        Modified := True;
      end;
    end;

    procedure DeleteKey(KeyPtr : Word);
      {-Delete the key at KeyPtr}
    begin
      with TempMacro do begin
        if NumKeys = 0 then
          Exit;
        if KeyPtr < NumKeys then
          Move(KeyArray[Succ(KeyPtr)], KeyArray[KeyPtr],
            Succ(NumKeys-KeyPtr) shl 1);
        KeyArray[NumKeys] := EndOfMacro;
        Dec(NumKeys);
        ComputeScreenPos(KeyPtr, RP, CP);
        DisplayKeys(RP, CP, False, KeyPtr);
        Modified := True;
      end;
    end;

    procedure IncKeyPtr(var KeyPtr : Word);
      {-Move one key to the right}
    begin
      if KeyPtr <= TempMacro.NumKeys then begin
        Inc(KeyPtr);
        ComputeScreenPos(KeyPtr, RP, CP);
        if RP > RowAtBottom then
          DisplayKeys(RP, LoCol, True, KeyPtr);
      end;
    end;

    procedure DecKeyPtr(var KeyPtr : Word);
      {-Move one key to left}
    begin
      if KeyPtr > 1 then begin
        Dec(KeyPtr);
        ComputeScreenPos(KeyPtr, RP, CP);
        if RP < RowAtTop then
          DisplayKeys(RP, LoCol, True, KeyPtr);
      end;
    end;

  begin
    Modified := False;
    TempMacro := Macro;
    SaveTextAttr := TextAttr;
    TextAttr := Dim;

    {save cursor state}
    GetCursorState(SaveXY, SaveSL);

    {draw a frame around the window}
    FrameWindow(MinCol, MinRow, MaxCol, MaxRow, Bright, Bright, '');

    {show key being edited}
    if Key <> NonMacroKey then begin
      KeyToString(Key, KeyName, Done);
      FastWrite(' Macro: '+KeyName+' ', MinRow, MinCol+2, Dim);
    end;

    {adjust coordinates of window}
    Inc(MinCol);
    Dec(MaxCol);
    Inc(MinRow);
    Dec(MaxRow);

    {copy coordinates to data segment for fast access in subroutines}
    LoCol := MinCol;
    LoRow := MinRow;
    HiCol := MaxCol;
    HiRow := MaxRow;

    Done := False;
    Inserting := True;
    KnownKeyPtr := 1;
    KnownRow := MinRow;
    KnownCol := MinCol;
    ScrollLock := (KbFlag^ and ScrollMask) <> 0;   {!!.22}
    LastScroll := not ScrollLock;
    RowAtTop := MinRow;
    RowAtBottom := MaxRow;

    {show instructions centered at bottom if possible}
    Width := Succ(MaxCol-MinCol);
    if Width >= Length(Instructions) then
      FastWrite(Instructions, Succ(MaxRow),
        (Width-Length(Instructions)) shr 1+Succ(MinCol), Dim);

    KeyPtr := 1;
    FillChar(BlankLine[1], SizeOf(BlankLine)-1, ' ');                   {!!.22}
    DisplayKeys(MinRow, MinCol, False, KeyPtr);

    ShowInsertMode;

    with TempMacro do
      repeat
        ComputeScreenPos(KeyPtr, RP, CP);
        GotoXYabs(CP, RP-(RowAtTop-MinRow));
        repeat
          {Watch the scroll state while waiting for a keystroke}
          ScrollLock := (KbFlag^ and ScrollMask) <> 0;                  {!!.22}
          if ScrollLock <> LastScroll then begin
            ShowCommandMode;
            LastScroll := ScrollLock;
          end;
        until GetKeyPressed;

        ChWord := GetKey;
        if (Ch = #0) or (Ch = #$E0) then begin
          {if in literal mode, insert the key}
          if ScrollLock then
            InsertKey(ChWord, KeyPtr)
          else
            case Hi(ChWord) of
              59 :           {Help}
                if MacEdHelpPtr = nil then
                  InsertKey(ChWord, KeyPtr)
                else
                  CallHelp(HelpForMacEd, nil, 0);
              75 :           {Left arrow}
                DecKeyPtr(KeyPtr);
              77 :           {Right arrow}
                IncKeyPtr(KeyPtr);
              72 :           {Up arrow}
                if RP = MinRow then
                  KeyPtr := 1
                else begin
                  CurRow := Pred(RP);
                  CurCol := CP;
                  KeyPtr := 1;
                  repeat
                    Inc(KeyPtr);
                    ComputeScreenPos(KeyPtr, RP, CP);
                  until ((RP = CurRow) and (CP >= CurCol)) or (RP > CurRow);
                  if (CP > CurCol) or (RP > CurRow) then begin
                    Dec(KeyPtr);
                    ComputeScreenPos(KeyPtr, RP, CP);
                    {don't go up more than one row}
                    if RP < CurRow then begin
                      Inc(KeyPtr);
                      ComputeScreenPos(KeyPtr, RP, CP);
                    end;
                  end;
                  if RP < RowAtTop then
                    DisplayKeys(RP, MinCol, True, KeyPtr);
                end;
              80 :           {Down arrow}
                begin
                  CurRow := RP;
                  CurCol := CP;
                  repeat
                    IncKeyPtr(KeyPtr);
                    ComputeScreenPos(KeyPtr, RP, CP);
                  until (KeyPtr > NumKeys) or ((RP > CurRow) and (CP >= CurCol));
                end;
              82 :           {Ins}
                begin
                  Inserting := not Inserting;
                  ShowInsertMode;
                end;
              83 :           {Del}
                if KeyPtr <= NumKeys then
                  DeleteKey(KeyPtr);
            else
              {The key is to be part of the macro}
              InsertKey(ChWord, KeyPtr);
            end;
        end
        else                 {Not an extended scan code}
          if ScrollLock then
            InsertKey(ChWord, KeyPtr)
          else
            case Ch of
              ^H :           {Backspace}
                if KeyPtr > 1 then begin
                  DecKeyPtr(KeyPtr);
                  DeleteKey(KeyPtr);
                end;
              #27 :          {Escape}
                begin
                  {Restore TempMacro to original}
                  TempMacro := Macro;
                  Modified := False;
                  Done := True;
                end;
              ^M :           {Enter}
                Done := True;
              #127 :         {CtrlBkSp}
                begin
                  Modified := True;
                  KeyArray[1] := EndOfMacro;
                  NumKeys := 0;
                  KeyPtr := 1;
                  RowAtTop := MinRow;
                  RowAtBottom := MaxRow;
                  DisplayKeys(MinRow, MinCol, False, KeyPtr);
                end;
            else
              InsertKey(ChWord, KeyPtr);
            end;
      until Done;

    TextAttr := SaveTextAttr;
    RestoreCursorState(SaveXY, SaveSL);
    EditKeys := @TempMacro;
  end;

begin
  {initialize procedure pointer}
  MacEdKeyPtr := @ReadKeyWord;
  MacEdKeypressedPtr := @KeyPressed;
end.
