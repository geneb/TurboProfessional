{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$IFDEF Dpmi}
  !! ERROR - This program is not compatible with Protected mode !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 2048,0,600000}

{$I TPDEFINE.INC}

{*********************************************************}
{*                   PREF.PAS 5.22                       *}
{*          Programmer's Quick Reference Chart           *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program PREF;
  {-Displays a quick reference chart for PC programmers}

uses
  Dos,                       {standard DOS/BIOS routines}
  TpCrt,                     {Turbo Professional CRT unit}
  {$IFDEF UseMouse}
  TpMouse,                   {Turbo Professional mouse routines}
  {$ENDIF}
  TpInt,                     {Turbo Professional ISR management}
  TpTsr,                     {Turbo Professional TSR management}
  TpString;                  {Turbo Professional string handling routines}

const
  {** keep the following together to allow easy patching **}
  ModuleName : string[4] = 'PREF'; {module name for standard interface}

  OurHotKey : Word = $0513;  {Ctrl + RightShift, 'R'}
 DisableScan : Char = #22;   {scan code for Alt-U, press twice in succession
                            to disable the popup}
  BlinkToggle : Char = #$30; {code for Alt-B, toggle blinking}
  SuppressBlink : Boolean = True; {suppress blinking when displaying attributes?}
  {******************* end of patch area ******************}

type
  String3 = string[3];
  String4 = string[4];
  String6 = string[6];
  String7 = string[7];
  String8 = string[8];
  String9 = string[9];
  String10 = string[10];
  String80 = string[80];
  DigitString = string[8];
  ScreenBuffer = array[0..1999] of Word;
  StringPointer = ^String9;

const
  {screen messages}
  ProgName : string[45] = 'PREF: Programmer''s Quick Reference Chart 5.22';
  Copyright : string[41] = 'Copyright (c) 1992 by TurboPower Software';
  LoadError : string[22] = 'Unable to install PREF';

  {Window border characters}
  LeftTee = #195;            {'Ã', left T}
  RtTee = #180;              {'´', right T}
  CrossBar = #196;           {'Ä', horizontal bar}

  {Window coordinates}
  LeftCol = 1;               {leftmost col on screen}
  RtCol = 80;                {rightmost col on screen}
  TopRow = 3;                {top row of window border}
  BotRow = 25;               {bottom row of window border}

  {For displaying video attributes}
  ColorBar : string[5] = '* * *'; {for samples of video attributes}
  ColorWheel : array[Black..White] of String8 =
  ('Black   ', 'Blue    ', 'Green   ', 'Cyan    ', 'Red     ', 'Magenta ',
    'Brown   ', 'Lt Gray ', 'Dk Gray ', 'Lt Blue ', 'Lt Green', 'Lt Cyan ',
    'Lt Red  ', 'Pink    ', 'Yellow  ', 'White   ');

  {For displaying keys}
  Shift = 'Sh';
  Ctrl = '^';
  Alt : string[3] = 'Alt';
  {For the main display}
  ColumnLabels : string[74] =
  {      1         2         3         4         5         6         7         8
   45678901234567890123456789012345678901234567890123456789012345678901234567890
   xxx  x  xxxxxxxx  xx  xxx  xxx xxxxxx    xxxxx  xxxxxxxx  xxxxxxx  xxxxxxx}
  'Dec Chr  Binary  Hex Ascii Key Extended  Color  Foregrnd  Backgrnd    Mono';

  {For translating keystrokes}
  Normal : String8 = ^Q^E^W^X^Z^R^C#27;
  IbmNormal : String8 = #0'H'#0'P'#0'IQ'#0;
  CtrlQs : String4 = ^S^D^R^C;
  IbmCtrlQs : String4 = 'GO'#132'v';
  Esc = #27;

  {initialized variables}
  AttrAtTop : Byte = 0;      {value at top of browse window}
  DisableOurselves : Boolean = False; {if true, disable the TSR}
var
  OurScreenBuffer : ScreenBuffer; {for saving the screen}

  Span : String80;           {for drawing boxes}
  SpLen : Byte absolute Span; {its length}
  Reverse,                   {reverse video attribute}
  Bright,                    {bright video attribute}
  Highlight,                 {highlight video attribute}
  Dim,                       {dim video attribute}
  FullPage : Byte;           {no. of rows in full page}
  LastLine : Word;           {last attribute that can be displayed at top of screen}
  CtrlQ : Boolean;           {true if ^Q pressed}
  {$IFDEF UseMouse}
  MSP : MouseStatePtr;
  MSPsize : Word;
  ScrollBarPos : Byte;
const
  {scroll bar coordinates}
  ScrollBarUp = 1;           {relative location of the up arrow}
  ScrollBarTop = 2;          {of the top of the bar}
  ScrollBarBot = 20;         {of the bottom of the bar}
  ScrollBarDn = 21;          {of the down arrow}
  ScrollBarHt = 19;          {the height of bar, excluding the arrows}
  {$ENDIF}

  {$L PREF.OBJ}

  {$F+}
  function EscapeSequence(B : Byte) : StringPointer; external;
  {-Return a pointer to a text string representing extended scan code B}
  {$F-}

  procedure Beep;
    {-Ring that obnoxious bell}
  begin
    Write(^G);
  end;

  procedure SetAttributes;
    {-Set video attribute variables based on the current video mode}
  var
    MonoColors : Boolean;
  begin
    {set video attributes}
    case CurrentMode of
      2, 7 :
        MonoColors := WhichHerc <> HercInColor;
      else
        MonoColors := False;
    end;

    if MonoColors then begin
      Bright := $F;          {white on black}
      Dim := $7;             {light gray on black}
      Highlight := $F;       {white on black}
      Reverse := $70;        {black on light gray}
    end
    else begin
      Bright := $E;          {yellow on black}
      Dim := $7;             {light gray on black}
      Highlight := $F;       {white on black}
      Reverse := $1E;        {yellow on blue}
    end;

    TextAttr := Dim;
  end;

  function DecimalByte(B : Byte) : DigitString;
    {-Return B in decimal}
  var
    S : string[3];
  begin
    Str(B:3, S);
    DecimalByte := S;
  end;

  function Monochrome(A : Byte) : String10;
    {-Return string representing a monochrome attribute}
  const
    MonoStrings : array[0..5] of String7 =
    ('Invis  ', 'Reverse', 'Int Und', 'Intense', 'Dim Und', 'Dim    ');
  var
    AttrType : Byte;
  begin
    case A and 127 of
      0, 8 : AttrType := 0;  {Invisible}
      $70,
      $78 : AttrType := 1;   {Reverse}
    else
      if A and 8 <> 0 then
        if A and 7 = 1 then
          AttrType := 2      {Intense Underline}
        else
          AttrType := 3      {Intense}
      else
        if A and 7 = 1 then
          AttrType := 4      {Dim Underline}
        else
          AttrType := 5;     {Dim}
    end;
    Monochrome := MonoStrings[AttrType];
  end;

  function Ascii(A : Byte) : String3;
    {-Return a string representing an ASCII character code}
  const
    AsciiChars : array[0..32] of String3 =
    ('NUL', 'SOH', 'STX', 'ETX', 'EOT', 'ENQ', 'ACK', 'BEL', 'BS ', 'HT ',
      'LF ', 'VT ', 'FF ', 'CR ', 'SO ', 'SI ', 'DLE', 'DC1', 'DC2', 'DC3',
      'DC4', 'NAK', 'SYN', 'ETB', 'CAN', 'EM ', 'SUB', 'ESC', 'FS ', 'GS ',
      'RS ', 'US ', 'SP ');
  begin
    Ascii := '   ';
    case A of
      0..32 : Ascii := AsciiChars[A];
      33..126 : Ascii[1] := Chr(A);
      127 : Ascii := 'DEL';
    end;
  end;

  function RegKey(K : Byte) : String3;
    {-Return a string representing a regular keystroke}
  begin
    RegKey := '   ';
    case K of
      1..31 : begin
                RegKey[1] := '^';
                RegKey[2] := Chr(K+64);
              end;
      32 : RegKey := 'SP ';
      33..126 : RegKey[1] := Chr(K);
      127 : RegKey := '^BS';
    end;
  end;

  function AuxKey(K : Byte; var A : Byte) : String9;
    {-Return a string representing an auxiliary keystroke}
  const
    Enhanced : array[0..165] of Byte = (
      0, 1, 0, 0, 0, 0, 0, 0, 0, 0, {000-009}
      0, 0, 0, 0, 1, 0, 0, 0, 0, 0, {010-019}
      0, 0, 0, 0, 0, 0, 1, 1, 1, 0, {020-029}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 1, {030-039}
      1, 1, 0, 1, 0, 0, 0, 0, 0, 0, {040-049}
      0, 1, 1, 1, 0, 0, 0, 0, 0, 0, {050-059}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {060-069}
      0, 0, 0, 0, 0, 0, 1, 0, 0, 0, {070-079}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {080-089}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {090-099}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {100-109}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {110-119}
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, {120-129}
      0, 0, 0, 1, 1, 1, 1, 1, 1, 1, {130-139}
      1, 1, 1, 1, 1, 1, 1, 1, 1, 0, {140-149}
      0, 1, 1, 1, 0, 1, 1, 1, 0, 1, {150-159}
      1, 1, 1, 1, 0, 1);     {160-165}
  var
    S : String9;
    SLen : Byte absolute S;
  begin
    {convert to a string}
    S := EscapeSequence(K)^;

    {pad the end of the string}
    if SLen < 9 then
      FillChar(S[Succ(SLen)], 9-SLen, ' ');

    {force length to 9 and return the string}
    SLen := 9;
    AuxKey := S;

    {fix the attribute}
    A := Dim;
    case K of
      0..165 : if Boolean(Enhanced[K]) then
                 A := Highlight;
      $E9..$EF : A := Bright;
    end;
  end;

  procedure DrawChartLine(Row, A : Byte);
    {-Draw one line in the chart}
  var
    NameAttr, A2 : Byte;
  begin
    {show attribute names as Highlight if blink bit set}
    if (A > 127) and SuppressBlink then
      NameAttr := Highlight
    else
      NameAttr := Dim;

    {draw the individual parts of the line}
    FastWrite(DecimalByte(A), Row, 04, Bright);
    FastWrite(Chr(A), Row, 09, Dim);
    FastWrite(BinaryB(A), Row, 12, Dim);
    FastWrite(HexB(A), Row, 22, Bright);
    FastWrite(Ascii(A), Row, 26, Dim);
    FastWrite(RegKey(A), Row, 31, Dim);
    FastWrite(AuxKey(A, A2), Row, 35, A2);
    if SuppressBlink then
      A2 := A and 127
    else
      A2 := A;
    FastWrite(ColorBar, Row, 45, A2);
    FastWrite(ColorWheel[A and $F], Row, 52, NameAttr);
    A2 := A shr 4;
    if SuppressBlink then
      A2 := A2 and $07;
    FastWrite(ColorWheel[A2], Row, 62, NameAttr);
    FastWrite(Monochrome(A), Row, 71, NameAttr);
  end;

  {$IFDEF UseMouse}

  procedure DrawScrollBar;
    {-Draw the scroll bar used by the mouse}
  const
    ScrollBarPtr : string[1] = ' ';
  var
    S : string[50];
    SLen : Byte absolute S;
  begin
    if not MouseInstalled then
      Exit;

    {make raw scroll bar string and display it}
    SLen := ScrollBarHt+2;
    FillChar(S[ScrollBarTop], ScrollBarHt, #176);
    S[ScrollBarUp] := #24;
    S[ScrollBarDn] := #25;
    FastVert(S, TopRow+1, LeftCol+1, Dim);

    {calculate ScrollBarPos}
    ScrollBarPos := ScrollBarTop+(AttrAtTop div ((LastLine+1) div ScrollBarHt));
    if ScrollBarPos > ScrollBarBot then
      ScrollBarPos := ScrollBarBot;

    {display scroll bar pointer}
    FastWrite(ScrollBarPtr, TopRow+ScrollBarPos, LeftCol+1, Reverse);
    {                       ^- actually (TopRow+1)+(ScrollBarPos-1)}
  end;

  {$ENDIF}

  procedure DrawFullChart;
    {-Draw the color chart}
  var
    Row : Word;
  begin
    for Row := Succ(TopRow) to Pred(BotRow) do
      DrawChartLine(Row, AttrAtTop+Row-Succ(TopRow));
    {$IFDEF UseMouse}
    DrawScrollBar;
    {$ENDIF}
  end;

  procedure DrawScreen;
    {-Draw initial screen}
  begin
    {Draw main box, title, and column labels}
    FrameWindow(LeftCol, 1, RtCol, BotRow, Bright, Reverse, ' '+ProgName+' ');
    FastWrite(ColumnLabels, 2, 4, Bright);

    {draw cross bar}
    SpLen := Succ(RtCol-LeftCol);
    FillChar(Span[1], 80, CrossBar);
    Span[1] := LeftTee;
    Span[SpLen] := RtTee;
    FastWrite(Span, TopRow, LeftCol, Bright);
  end;

  {$IFDEF UseMouse}

  function ReadKeyWord : Word;
    {-Special ReadKeyWord routine that accounts for mouse}
  var
    Key : Word;
    Status : ButtonStatus;
  begin
    if not MouseInstalled then
      ReadKeyWord := TpCrt.ReadKeyWord
    else begin
      Key := $FFFF;
      repeat
        {give priority to real keys}
        if KeyPressed then
          Key := TpCrt.ReadKeyWord
        else if MousePressed then begin
          Key := MouseKeyWord;
          if Key = MouseRt then
            Key := $001B     {ESC}
          else if Key = MouseLft then begin
            if MouseKeyWordY = 1 then
              Key := $4800   {Up}
            else if MouseKeyWordY = ScrollBarDn then
              Key := $5000   {Down}
            else if MouseKeyWordY <> ScrollBarPos then begin
              {scroll display based on scroll bar}
              Key := $FF00;  {special pseudokey}
              if MouseKeyWordY = ScrollBarTop then
                AttrAtTop := 0
              else if MouseKeyWordY = ScrollBarBot then
                AttrAtTop := LastLine
              else
                AttrAtTop :=
                (MouseKeyWordY-ScrollBarTop)*((LastLine+1) div ScrollBarHt);
            end;
          end;
        end
        else
          {give other TSR's a chance to pop up}
          inline($cd/$28);
      until Key <> $FFFF;
      ReadKeyWord := Key;
    end;
  end;

  function ReadKey : Char;
    {-Special ReadKey routine that accounts for mouse}
  const
    ScanCode : Char = #0;
  var
    Key : Word;
  begin
    if ScanCode <> #0 then begin
      {return the scan code}
      ReadKey := ScanCode;
      ScanCode := #0;
    end
    else begin
      {get the next keystroke}
      Key := ReadKeyWord;

      {return the low byte}
      ReadKey := Char(Lo(Key));

      {if it's 0, save the scan code for the next call}
      if Lo(Key) = 0 then
        ScanCode := Char(Hi(Key));
    end;
  end;

  {$ENDIF}

  function GetCursorCommand : Char;
  {-Get a cursor command. Translate IBM keypad commands to WordStar
    equivalents.}
  var
    C : Char;
    Posn : Byte;
    I : Word;
  begin
    repeat
      CtrlQ := False;
      C := ReadKey;
      if C = #0 then begin
        {translate IBM keypad into WordStar equivalents}
        C := ReadKey;

        {see if we're going to disable the TSR}
        if C = #$FF then
          {special mouse command}
          Posn := 1
        else if C = DisableScan then begin
          I := ReadKeyWord;
          if Hi(I) = Ord(DisableScan) then begin
            DisableOurselves := True;
            C := Esc;
            Posn := 1;
          end
          else
            Posn := 0;
        end
        else if C = BlinkToggle then begin
          SuppressBlink := not SuppressBlink;
          SetBlink(SuppressBlink);
          DrawFullChart;
          Posn := 0;
        end
        else begin
          Posn := Pos(C, IbmCtrlQs);
          CtrlQ := Posn <> 0;
          if CtrlQ then
            C := CtrlQs[Posn]
          else begin
            Posn := Pos(C, IbmNormal);
            C := Normal[Posn];
          end;
        end;
      end
      else
        if C = ^Q then begin
          CtrlQ := True;

          {read next character}
          C := ReadKey;

          {convert 's' and 'S' to ^S, etc.}
          C := Upcase(C);
          if C = #0 then begin
            Posn := 0;
            C := ReadKey;
          end
          else begin
            case C of
              'A'..'Z' : C := Chr(Ord(C)-64);
            end;
            Posn := Pos(C, CtrlQs);
          end;
        end
        else
          Posn := Pos(C, Normal);
    until Posn <> 0;         {wait for valid cursor command or ESC}
    GetCursorCommand := C;
  end;

  procedure BrowseThroughChart;
    {-Browse through chart until Done}
  var
    Ch : Char;
  begin
    {initialize screen stuff}
    FullPage := BotRow-TopRow-2;
    LastLine := 255-FullPage;

    {draw initial screen}
    Window(LeftCol, 1, RtCol, BotRow);
    ClrScr;
    DrawScreen;
    DrawFullChart;

    {$IFDEF UseMouse}
    if MouseInstalled then
      {force the mouse to stay in the far left column of the chart}
      MouseWindow(LeftCol+1, TopRow+1, LeftCol+1, BotRow-1);
    {$ENDIF}

    repeat
      Ch := GetCursorCommand;
      if CtrlQ then
        case Ch of
          ^S,
          ^R :               {Home, ^PgUp -- top of chart}
            if AttrAtTop <> 0 then begin
              AttrAtTop := 0;
              DrawFullChart;
            end;
          ^D,
          ^C :               {End, ^PgDn -- bottom of chart}
            if AttrAtTop <> LastLine then begin
              AttrAtTop := LastLine;
              DrawFullChart;
            end;
        end
      else
        case Ch of
          ^E,
          ^W :               {Scroll up}
            if AttrAtTop <> 0 then begin
              Dec(AttrAtTop);
              ScrollWindowDown(LeftCol+2, TopRow+1, RtCol-1, BotRow-1, 1);
              DrawChartLine(Succ(TopRow), AttrAtTop);
              {$IFDEF UseMouse}
              DrawScrollBar;
              {$ENDIF}
            end;
          ^Z,
          ^X :               {Scroll down}
            if AttrAtTop <> LastLine then begin
              Inc(AttrAtTop);
              ScrollWindowUp(LeftCol+2, TopRow+1, RtCol-1, BotRow-1, 1);
              DrawChartLine(Pred(BotRow), AttrAtTop+FullPage);
              {$IFDEF UseMouse}
              DrawScrollBar;
              {$ENDIF}
            end;

          ^R :               {PgUp}
            if AttrAtTop <> 0 then begin
              if AttrAtTop < FullPage then
                AttrAtTop := 0
              else
                AttrAtTop := AttrAtTop-FullPage;
              DrawFullChart;
            end;
          ^C :               {PgDn}
            if AttrAtTop <> LastLine then begin
              AttrAtTop := AttrAtTop+FullPage;
              if AttrAtTop > LastLine then
                AttrAtTop := LastLine;
              DrawFullChart;
            end;
          {$IFDEF UseMouse}
          #$FF :             {special mouse command}
            DrawFullChart;
          {$ENDIF}
        end;
    until Ch = Esc;          {Escape}

    {check to see if we're disabling the TSR}
    if DisableOurselves then
      if not DisableTSR then begin
        {no go, exit but stay resident and active}
        DisableOurselves := False;
        Write(^G);
      end;
  end;

  {$F+}
  procedure PopupEntryPoint(var Regs : Registers);
    {-This is the entry point for the popup}
  var
    SaveXY, SaveSL : Word;   {for saving cursor position and shape}
  begin
    {reinitialize CRT}
    ReInitCrt;

    {exit if not in 80-column text mode}
    if InTextMode and (ScreenWidth = 80) then begin
      {initialize screen stuff}
      SetAttributes;
      GetCursorState(SaveXY, SaveSL);
      HiddenCursor;
      MoveScreen(Mem[VideoSegment:0], OurScreenBuffer, 2000);

      {$IFDEF UseMouse}
      if MouseInstalled then begin
        {save the state of the mouse driver}
        SaveMouseState(MSP, False);

        {reinitialize the mouse}
        InitializeMouse;

        {install event handler so MousePressed and MouseKeyWord will work}
        EnableEventHandling;

        {we don't want to wait for buttons to be released}
        WaitForButtonRelease := False;

        {use the hardware cursor for the mouse}
        BlockMouseCursor;

        {make it visible}
        ShowMouse;
      end;
      {$ENDIF}

      {show the chart}
      if not SuppressBlink then
        SetBlink(SuppressBlink);
      BrowseThroughChart;
      if not SuppressBlink then
        SetBlink(not SuppressBlink);

      {restore cursor and screen}
      RestoreCursorState(SaveXY, SaveSL);
      MoveScreen(OurScreenBuffer, Mem[VideoSegment:0], 2000);

      {$IFDEF UseMouse}
      if MouseInstalled then begin
        {disable our event handler}
        DisableEventHandling;

        {restore the state of the mouse driver}
        RestoreMouseState(MSP, False);
      end;
      {$ENDIF}
    end
    else
      Beep;
  end;
  {$F-}

  procedure Abort(Message : string);
    {-Display Message and Halt with error code}
  begin
    WriteLn(Message);
    Halt(1);
  end;

begin
  {smooth scrolling on CGA's}
  BiosScroll := False;

  {signon message}
  HighVideo;
  WriteLn(ProgName, ^M^J, Copyright, ^M^J);
  LowVideo;

  {check to see if SideKick is loaded}
  if SideKickLoaded then
    Abort('Can''t be loaded after SideKick!');

  {check to see if we're already installed}
  if ModuleInstalled(ModuleName) then
    Abort('PREF is already loaded. Aborting...');

  {install the module}
  InstallModule(ModuleName, nil);

  {$IFDEF UseMouse}
  if MouseInstalled then begin
    {allocate the buffer used to save the state of the mouse}
    MSPsize := MouseStateBufferSize;

    {if the size is 0, assume that it's not safe to use the mouse}
    if MSPsize = 0 then
      MouseInstalled := False
    else
      GetMem(MSP, MSPsize);
  end;
  {$ENDIF}

  {go resident}
  if DefinePop(OurHotKey, @PopupEntryPoint, Ptr(SSeg, SPtr), True) then begin
    WriteLn('PREF loaded. Press Ctrl-RightShift-R to activate.');

    {Enable popups}
    PopupsOn;

    {$IFDEF Ver40}
    {restore INT $1B, captured by TPCRT}
    SetIntVec($1B, SaveInt1B);
    {$ENDIF}

    {terminate and stay resident}
    if not TerminateAndStayResident(ParagraphsToKeep, 0) then {} ;
  end;

  {if we get here we failed}
  Abort(LoadError);
end.
