{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$I TPDEFINE.INC}

{*********************************************************}
{*                  VBROWSE.PAS 5.22                     *}
{*                Virtual File Browser                   *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program VBrowse;
  {-Virtual file browser}
uses
  Dos,                       {standard DOS/BIOS routines}
  Printer,                   {standard print routines}
  TpString,                  {Turbo Professional string handling routines}
  TpDos,                     {Turbo Professional disk/file management, etc.}
  TpCrt,                     {Turbo Professional CRT unit}
  {$IFDEF UseMouse}
  TpMouse,                   {Turbo Professional mouse routines}
  {$ENDIF}
  TpEdit,                    {Turbo Professional line editor}
  TpWindow,                  {Turbo Professional popup window management}
  TpVArray;                  {Turbo Professional virtual arrays}

const
  ProgName : string[36] = ' VBROWSE: Virtual File Browser 5.22 ';

  {--------------- customization section ------------}
  MaxLines = 64000;          {maximum number of lines}
  MaxLineSize = 255;         {maximum size of a line} {!!.20}
  HScrollDelta = 20;         {^Left/^Right scroll horizontally this many columns}
  SwapName : string[64] =    {file used by TPVARRAY to store array elements}
  'VBROWSE.SWP';
  ExpandTabs = True;         {if True, tabs are expanded to spaces}
  TabSize = 8;               {distance between tab stops when expanding tabs}
  RulerOn : Boolean = False; {show ruler at top of screen?}
  IgnoreCase : Boolean = True; {ignore case when searching?}

  {messages}
  FileOpenError = 'Error while trying to open file';
  FileReadError = 'Error while trying to read file';
  FileCloseError = 'Error while trying to close file';
  SwapWriteError = 'Error while writing to swap file';
  SwapReadError = 'Error while reading from swap file';
  PrintError = 'Error while writing to printer';
  WindowError = 'Window manager''s data corrupted';
  FileNotFound = 'File not found';
  FilePrompt = 'File: ';
  FindPrompt = 'Find: ';
  GotoPrompt = 'Goto line: ';
  IgnoreCasePrompt = 'Ignore case?';
  PrintFromPrompt = 'Print from line: ';
  PrintToPrompt = 'Print to line: ';
  StringNotFound = 'String not found';
  InsufficientMemory = 'Insufficient memory';
  SearchingMsg = 'Searching...';
  PrintingMsg = 'Printing...';
  PressAnyKeyPrompt = '. Press any key...';
  AbortPrompt = '. Press any key to return to DOS.';

  {screen coordinates}
  InsideRow = 2;             {first row in viewing window}
  InsideCol = 2;             {first column in viewing window}
  PromptCol = 3;             {column for prompt messages}
  FNameCol = 3;              {column for filename}
  LinesCol = 17;             {column for current line display}
  ColCol = 39;               {column for current column display}
  TotalCol = 49;             {column for total lines display}
  BytesCol = 63;             {column for total bytes display}
  RulerRow = 1;              {row and column for ruler}
  RulerCol = 1;

  {help}
  HelpRow = 3;               {top row for help window}
  HelpCol = 16;              {left column for help window}
  HelpLines = 19;            {number of lines in help screen}
  HelpLength = 48;           {length of strings in help screen}
  HelpText : array[1..HelpLines] of string[HelpLength] = (
    ' Scroll up        <Up>        <CtrlE>   <CtrlW> ',
    ' Scroll down      <Down>      <CtrlX>   <CtrlZ> ',
    ' Scroll left      <Left>      <CtrlS>           ',
    ' Scroll right     <Right>     <CtrlD>           ',
    ' Scroll left 20   <CtrlLeft>  <CtrlA>           ',
    ' Scroll right 20  <CtrlRight> <CtrlF>           ',
    ' Page up          <PgUp>      <CtrlR>           ',
    ' Page down        <PgDn>      <CtrlC>           ',
    ' Top of file      <^PgUp>     <CtrlQ>R  <Home>  ',
    ' Bottom of file   <^PgDn>     <CtrlQ>C  <End>   ',
    ' Find string      <CtrlQ>F                      ',
    ' Repeat find      <CtrlL>                       ',
    ' Goto line        <CtrlQ>L                      ',
    ' Set marker 0..9  <CtrlK>n                      ',
    ' Goto marker 0..9 <CtrlQ>n                      ',
    ' Print lines      <AltP>      <CtrlK>P          ',
    ' Toggle ruler     <AltR>                        ',
    ' New file         <F3>        <CtrlK>D  <AltF>  ',
    ' Exit             <CtrlBreak> <Esc>             ');
type
  Line = string[MaxLineSize]; {a line of text}
var
  LineArray : TpArray;       {pointer to the virtual array}
  FName : string[64];        {file being browsed}
  FNameNP : string[13];      {" -- with no path}
  TotalLineStr : string[7];  {string representing line count}
  TotalByteStr : string[10]; {string representing byte count}
  RulerWindow : Pointer;     {ruler "window" at top of screen}
  HelpWindow,                {popup help window}
  MainWindow : WindowPtr;    {main window}
  CurrentCol : Integer;      {column being displayed at left edge of screen}
  CurrentLine,               {line number being displayed at top of window}
  LastLine,                  {last line that can be displayed}
  NumRows,                   {number of rows in viewing window}
  TotalLines,                {total # of lines in the file}
  LineWidth,                 {width of the browsing window}
  StatusLine : Word;         {row for status line}
  Reverse,                   {reverse video attribute}
  Bright,                    {bright video attribute}
  Highlight,                 {highlight video attribute}
  Dim : Byte;                {dim video attribute}
  TotalBytes : LongInt;      {total # of bytes in the file}
  SearchString : Line;       {last string searched for}
  LastCurrentLine : Word;    {used for search operations}
  SuppressStatus : Boolean;  {if False, status line not drawn}
  Markers : array[0..9] of
    record
      IsSet : Boolean;       {Is marker set?}
      Row, Col : Word;       {line and column}
    end;

  {$IFDEF UseMouse}
  function ReadKeyWord : Word;
    {-Get a key from the keyboard or mouse}
  begin
    ReadKeyWord := ReadKeyOrButton;
  end;
  {$ENDIF}

  procedure CleanUp;
    {-Delete swap file and restore screen}
  begin
    {get rid of the swap file}
    if LineArray <> nil then   {!!.11}
      DisposeA(LineArray, True);
    if ErrorA <> 0 then
      {do nothing} ;

    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {restore the screen}
    MainWindow := EraseTopWindow;
  end;

  procedure SetAttributes;
    {-Set video attribute variables based on the current video mode}
  var
    MonoColors : Boolean;
  begin
    {we're doing our own color mapping}
    MapColors := False;

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
      Highlight := $70;      {black on light gray}
      Reverse := $70;        {black on light gray}
      ShadowAttr := $70;     {black on light gray}
    end
    else begin
      Bright := $1C;         {light red on blue}
      Dim := $3E;            {yellow on cyan}
      Highlight := $4F;      {white on red}
      Reverse := $1F;        {white on blue}
      ShadowAttr := $7;      {light gray on black}
    end;
    TextAttr := Dim;
  end;

  function PaddedWordStr(W, Width : Word) : string;
    {-Return W as a string, padded to the specified width}
  var
    S : string;
  begin
    FillChar(S[1], Width, ' ');
    Str(W, S);
    S[0] := Chr(Width);
    PaddedWordStr := S;
  end;

  procedure ClearStatusLine;
    {-Clear the status line}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    FastWrite(Pad('', ScreenWidth-2), ScreenHeight, InsideCol, Reverse);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure DrawStatusLine;
    {-Display status information}
  var
    S : string;
    N : Word;
  begin
    {exit if status line suppressed}
    if SuppressStatus then
      Exit;

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    {show filename}
    FastWrite(FNameNP, StatusLine, FNameCol, Reverse);

    {show lines on screen}
    N := CurrentLine+Pred(NumRows);
    if N > TotalLines then
      N := TotalLines;
    S := 'Lines: '+Long2Str(CurrentLine)+' - '+Long2Str(N);
    FastWrite(Pad(S, 20), StatusLine, LinesCol, Reverse);

    {show leftmost column}
    FastWrite('Col: '+PaddedWordStr(CurrentCol, 3), StatusLine, ColCol, Reverse);

    {show total lines}
    FastWrite('Total: '+TotalLineStr, StatusLine, TotalCol, Reverse);

    {show total bytes}
    FastWrite('Bytes: '+TotalByteStr, StatusLine, BytesCol, Reverse);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure Prompt(Msg : string; var Escaped : Boolean; var S : string);
    {-Prompt for a string}
  begin
    ClearStatusLine;
    ReadString(Msg, StatusLine, PromptCol, 64, Reverse, Reverse, Reverse, Escaped, S);
    ClearStatusLine;
    DrawStatusLine;
  end;

  procedure PromptWord(Msg : string; Hi, Lo : Word; var Escaped : Boolean; var W : Word);
    {-Prompt for a word}
  begin
    ClearStatusLine;
    ReadWord(Msg, StatusLine, PromptCol, 6, Reverse, Reverse, Hi, Lo, Escaped, W);
    ClearStatusLine;
    DrawStatusLine;
  end;

  function PromptYesOrNo(Msg : string; Default : Char) : Boolean;
    {-Get a response to a yes-no question}
  begin
    ClearStatusLine;
    PromptYesOrNo := YesOrNo(Msg, StatusLine, PromptCol, Reverse, Default);
    ClearStatusLine;
    DrawStatusLine;
  end;

  procedure PromptMessage(Msg : string);
    {-Display a message on the prompt line}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    ClearStatusLine;
    FastWrite(Msg, StatusLine, PromptCol, Reverse);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure Abort(Msg : string);
    {-Show an error message and halt}
  var
    I : Word;
  begin
    PromptMessage(Msg+AbortPrompt);
    I := ReadKeyWord;
    CleanUp;
    Halt(1);
  end;

  procedure PressAnyKey(Msg : string);
    {-Display a message on the prompt line and wait for keypress}
  var
    I : Word;
  begin
    PromptMessage(Msg+PressAnyKeyPrompt);
    I := ReadKeyWord;
    ClearStatusLine;
    DrawStatusLine;
  end;

  procedure GetLine(Line : Word; var S : Line);
    {-Get the specified line into S}
  begin
    RetA(LineArray, Pred(Line), 0, S);
    if ErrorA <> 0 then
      Abort(SwapReadError);
  end;

  procedure DrawRuler; {!!.20} {rewritten}
    {-Display the ruler}
  type
    RulerType = array[-1..148] of Char; {!!.21}
  const
    Ruler10 : array[0..9] of Char = '000שששששש';
  var
    R : RulerType;
    I, J : Integer;
    Tens,
    Index : Word;

    procedure InsertDigitPair(W : Word; var DigitDest);
      {-Convert 10 to '10', 20 to '20', etc.}
    var
      Digits : record
                 Huns, Tens : Char;
               end absolute DigitDest;
    begin
      Digits.Huns := Chr((W div 10)+Ord('0'));
      Digits.Tens := Chr((W mod 10)+Ord('0'));
    end;

    procedure ShowRuler(var RS);
      {-Show the ruler}
    var
      S : string absolute RS;
    begin
      {$IFDEF UseMouse}
      HideMouse;
      {$ENDIF}

      S[0] := Chr(LineWidth);
      FastWrite(S, RulerRow, Succ(RulerCol), Reverse);

      {$IFDEF UseMouse}
      ShowMouse;
      {$ENDIF}
    end;

  begin
    {get a working pattern for the ruler}
    J := (ScreenWidth+9) div 10;
    for I := 0 to J do                             {!!.21}
      Move(Ruler10, R[Pred(I*10)], SizeOf(Ruler10));

    {get rid of '0' in column 1 if necessary}
    if CurrentCol = 1 then
      R[1] := #249;

    {figure out where to start working on it}
    Tens := CurrentCol div 10;
    if Tens > 0 then
      I := -1
    else begin
      I := 9;
      Inc(Tens);
    end;

    {add the 10x markers to the ruler}
    repeat
      InsertDigitPair(Tens, R[I]);
      Inc(Tens);
      Inc(I, 10);
    until I > Pred(ScreenWidth);

    {now display the ruler}
    Index := CurrentCol mod 10;
    ShowRuler(R[Pred(Index)]);
  end;

  procedure DrawLine(Row : Byte);
    {-Draw the line that goes at the specified Row (window-relative)}
  var
    S : Line;
    SLen : Byte absolute S;
    LineNum : Word;
  begin
    {calculate line number and get the string}
    LineNum := CurrentLine+Pred(Row);
    if LineNum <= TotalLines then
      GetLine(LineNum, S)
    else
      SLen := 0;

    {adjust for current column}
    if SLen < CurrentCol then
      SLen := 0
    else
      if CurrentCol <> 1 then begin
        Dec(SLen, Pred(CurrentCol));
        Move(S[CurrentCol], S[1], SLen);
      end;

    {pad the end of the line with blanks if necessary}
    if LineWidth > SLen then
      FillChar(S[Succ(SLen)], LineWidth-SLen, ' ');
    SLen := LineWidth;

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    {draw the line}
    FastWriteWindow(S, Row, 1, Dim);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure DrawFullScreen;
    {-Redraw the screen}
  var
    Row : Byte;
  begin
    {make sure the column is a legal value}
    if CurrentCol < 1 then
      CurrentCol := 1;

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    {draw the individual lines}
    for Row := 1 to NumRows do
      DrawLine(Row);

    {draw the ruler if it's on}
    if RulerOn then
      DrawRuler;

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure ToggleRuler;
    {-Turn the ruler on/off}
  begin
    RulerOn := not RulerOn;

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    if RulerOn then
      DrawRuler
    else
      RestoreWindow(RulerCol, RulerRow, ScreenWidth, RulerRow, False, RulerWindow);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure ReadNewFile(FN : string);
    {-Read the contents of the file into the array}
  const
    BufSize = 8192;
  var
    F : Text;
    Buffer : array[1..BufSize] of Byte;
    S : string;
  begin                      {ReadFile}
    {clean up filenames}
    FName := StUpcase(CleanPathName(FN));
    FNameNP := Pad(JustFilename(FName), 13);

    {reset column/line counters}
    CurrentCol := 1;
    CurrentLine := 1;
    TotalLines := 0;

    {assign the filename and allocate a buffer}
    Assign(F, FName);
    SetTextBuf(F, Buffer, BufSize);

    {open the file}
    Reset(F);
    if IoResult <> 0 then
      Abort(FileOpenError);

    {get size of file}
    TotalBytes := TextFileSize(F);
    if TotalBytes = -1 then
      Abort(FileReadError);
    TotalByteStr := Long2Str(TotalBytes);

    {show what we're doing}
    PromptMessage('Reading '+FName+'...');

    {read the file into the array}
    while not Eof(F) and (TotalLines < MaxLines) do begin
      {read next line}
      ReadLn(F, S);
      if IoResult <> 0 then
        Abort(FileReadError);

      {expand tabs if desired}
      if ExpandTabs then
        S := DeTab(S, TabSize);

      {make sure line isn't too long}
      if Length(S) > MaxLineSize then
        S[0] := Chr(MaxLineSize);

      {plug the line into the array}
      SetA(LineArray, TotalLines, 0, S);
      if ErrorA <> 0 then
        Abort(SwapWriteError);

      Inc(TotalLines);

      {update the screen when we have a screenful}
      if TotalLines = NumRows then
        DrawFullScreen;
    end;

    {convert total lines to a string}
    TotalLineStr := PaddedWordStr(TotalLines, 5);

    {set LastLine}
    if TotalLines < NumRows then begin
      LastLine := TotalLines;
      {screen not drawn yet--do it now}
      DrawFullScreen;
    end
    else
      LastLine := Succ(TotalLines-NumRows);

    {get rid of Reading... message}
    ClearStatusLine;

    {close the file}
    Close(F);
    if IoResult <> 0 then
      Abort(FileCloseError);

    {clear markers}
    FillChar(Markers, SizeOf(Markers), 0);

    {enable the status line}
    SuppressStatus := False;
  end;

  procedure GetNewFile;
    {-Get a new filename and read it in. Search path for it if necessary.}
  var
    OK, Escaped : Boolean;
    FN : string[64];
  begin
    FN := FName;
    OK := False;
    repeat
      if not OK then begin
        Prompt(FilePrompt, Escaped, FN);
        if Escaped then
          Exit;
      end;

      {look for the file}
      OK := ExistOnPath(FN, FN);
      if not OK then
        PressAnyKey(FileNotFound);
    until OK;

    {now read the file}
    ReadNewFile(FN);
  end;

  procedure ScrollUp;
    {-Scroll up one line}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    if CurrentLine > 1 then begin
      {$IFDEF UseMouse}
      HideMouse;
      {$ENDIF}

      Dec(CurrentLine);
      ScrollWindow(False, 1);
      DrawLine(1);

      {$IFDEF UseMouse}
      ShowMouse;
      {$ENDIF}
    end;

  end;

  procedure ScrollDown;
    {-Scroll down one line}
  begin
    if CurrentLine < TotalLines then begin
      {$IFDEF UseMouse}
      HideMouse;
      {$ENDIF}

      Inc(CurrentLine);
      ScrollWindow(True, 1);
      DrawLine(NumRows);

      {$IFDEF UseMouse}
      ShowMouse;
      {$ENDIF}
    end;
  end;

  procedure ScrollLeft;
    {-Scroll to the left 20 columns}
  begin
    if CurrentCol > 1 then begin
      if CurrentCol >= HScrollDelta then
        Dec(CurrentCol, HScrollDelta)
      else
        CurrentCol := 1;
      DrawFullScreen;
    end;
  end;

  procedure ScrollRight;
    {-Scroll to the right 20 columns}
  begin
    if CurrentCol < MaxLineSize then begin
      Inc(CurrentCol, HScrollDelta);
      if CurrentCol > MaxLineSize then
        CurrentCol := MaxLineSize;
      DrawFullScreen;
    end;
  end;

  procedure Left;
    {-Scroll to the left 1 column}
  begin
    if CurrentCol > 1 then begin
      Dec(CurrentCol);
      DrawFullScreen;
    end;
  end;

  procedure Right;
    {-Scroll to the right 1 column}
  begin
    if CurrentCol < MaxLineSize then begin
      Inc(CurrentCol);
      DrawFullScreen;
    end;
  end;

  procedure PageUp;
    {-Scroll up one full screen}
  var
    I : Word;                                                          {!!.22}
  begin
    if CurrentLine > 1 then begin
      I := CurrentLine-NumRows;
      if I > 1 then
        CurrentLine := I
      else
        CurrentLine := 1;
      DrawFullScreen;
    end;
  end;

  procedure PageDown;
    {-Scroll down one full screen}
  var
    I : Word;
  begin
    if CurrentLine < LastLine then begin
      I := CurrentLine+NumRows;
      if I < TotalLines then
        CurrentLine := I
      else
        CurrentLine := TotalLines;
      DrawFullScreen;
    end;
  end;

  procedure TopOfFile;
    {-Go to first line in file}
  begin
    if (CurrentLine > 1) or (CurrentCol > 1) then begin
      CurrentLine := 1;
      CurrentCol := 1;
      DrawFullScreen;
    end;
  end;

  procedure EndOfFile;
    {-Go to last line in file}
  begin
    if (CurrentLine < LastLine) or (CurrentCol > 1) then begin
      CurrentLine := LastLine;
      CurrentCol := 1;
      DrawFullScreen;
    end;
  end;

  procedure GotoLine;
    {-Process goto line command}
  var
    Escaped : Boolean;
  begin
    PromptWord(GotoPrompt, 1, TotalLines, Escaped, CurrentLine);
    if not Escaped then
      {redraw the screen}
      DrawFullScreen;
  end;

  procedure PrintBlock;
    {-Process print block command}
  const
    FormFeed = ^L;
  var
    L : Line;
    PrintFrom,
    I, PrintTo : Word;
    Escaped : Boolean;
  begin
    {keep the status line from flashing}
    SuppressStatus := True;

    {default to printing lines now on the screen}
    PrintFrom := CurrentLine;
    PrintTo := CurrentLine+Pred(NumRows);
    if PrintTo > TotalLines then
      PrintTo := TotalLines;

    {get line to start printing from}
    PromptWord(PrintFromPrompt, 1, TotalLines, Escaped, PrintFrom);
    if Escaped then
      Exit;

    {get line to print to -- must be >= PrintFrom}
    PromptWord(PrintToPrompt, PrintFrom, TotalLines, Escaped, PrintTo);
    if Escaped then
      Exit;

    {show status message}
    PromptMessage(PrintingMsg);

    {print the desired range of lines}
    for I := PrintFrom to PrintTo do begin
      {get next line}
      GetLine(I, L);

      {send it to the printer}
      WriteLn(Lst, L);
      if IoResult <> 0 then begin
        PressAnyKey(PrintError);
        Exit;
      end;
    end;

    {send a form feed to the printer}
    Write(Lst, FormFeed);
    if IoResult <> 0 then
      PressAnyKey(PrintError);
  end;

  procedure FindPrimitive;
    {-Primitive routine to find a string}
  const
    LCount : Word = 0;
  var
    BT : BTable;
    Index, I, J : Word;
    SearchFor, L : Line;
    Found : Boolean;
  begin
    {show status message}
    PromptMessage(SearchingMsg);

    {set up for search}
    if IgnoreCase then
      SearchFor := StUpcase(SearchString)
    else
      SearchFor := SearchString;
    BMMakeTable(SearchFor, BT);

    {start searching at current line, or line after last find}
    if LastCurrentLine <> CurrentLine then
      LCount := Pred(CurrentLine);

    Found := False;
    while (LCount < TotalLines) and not Found do begin
      {get next line}
      Inc(LCount);
      GetLine(LCount, L);

      {skip lines that are too short}
      if Length(L) >= Length(SearchFor) then begin
        {search for a match}
        if IgnoreCase then
          Index := BMSearchUC(L[1], Length(L), BT, SearchFor)
        else
          Index := BMSearch(L[1], Length(L), BT, SearchFor);

        {search routines return $FFFF if string not found}
        if (Index <> $FFFF) then begin
          Found := True;
          Inc(Index);
        end;
      end;
    end;

    {if not found, show error message}
    if not Found then begin
      PressAnyKey(StringNotFound);
      Exit;
    end;

    {set current line so that the line is clearly visible}
    if LCount >= (CurrentLine+NumRows) then
      CurrentLine := LCount-2;
    LastCurrentLine := CurrentLine;

    {set current column so that the line is clearly visible}
    I := Index+Length(SearchString)+2;
    if (I-Pred(CurrentCol)) > LineWidth then
      CurrentCol := I-LineWidth;
    if Integer(Index)-2 < CurrentCol then
      CurrentCol := Index-2;

    {redraw the screen}
    DrawFullScreen;

    {redraw the status line}
    ClearStatusLine;
    SuppressStatus := False;
    DrawStatusLine;

    {highlight the search string}
    I := InsideRow+(LCount-CurrentLine);
    J := InsideCol+(Index-CurrentCol);

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}
    ChangeAttribute(Length(SearchString), I, J, Highlight);
    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}

    {$IFDEF UseMouse}
    while not KeyPressed or MousePressed do
      {} ;
    {$ELSE}
  while not KeyPressed do
    {};
  {$ENDIF}

    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}
    ChangeAttribute(Length(SearchString), I, J, Dim);
    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure FindString;
    {-Prompt for a string and find it}
  const
    YorN : array[Boolean] of Char = ('N', 'Y');
  var
    Escaped : Boolean;
  begin
    {keep the status line from flashing}
    SuppressStatus := True;

    {get the search string}
    Prompt(FindPrompt, Escaped, SearchString);

    {exit if Escape pressed or no string}
    if Escaped or (Length(SearchString) = 0) then
      Exit;

    {case sensitive search?}
    IgnoreCase := PromptYesOrNo(IgnoreCasePrompt, YorN[IgnoreCase]);

    {new search string, start from current line}
    LastCurrentLine := 0;

    {do the search operation}
    FindPrimitive;
  end;

  procedure FindLast;
    {-Find the last search string again, if any}
  begin
    {if there's a search string, use it again}
    if Length(SearchString) <> 0 then
      FindPrimitive;
  end;

  procedure SetMarker(N : Byte);
    {-Set a marker}
  begin
    with Markers[N] do begin
      IsSet := True;
      Col := CurrentCol;
      Row := CurrentLine;
    end;
  end;

  procedure JumpMarker(N : Byte);
    {-Jump to a marker}
  begin
    with Markers[N] do
      if IsSet then begin
        {reset current line and column}
        CurrentCol := Col;
        CurrentLine := Row;

        {redraw}
        DrawFullScreen;
      end
      else
        PressAnyKey('Marker '+Chr(N+Ord('0'))+' not set');
  end;

  procedure Help;
    {-Show help screen}
  var
    P : Pointer;
    I : Word;
  begin
    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {display the help window}
    if not DisplayWindow(HelpWindow) then
      Abort(WindowError);

    {display the help text}
    for I := 1 to HelpLines do
      FastWriteWindow(HelpText[I], I, 1, TextAttr);

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}

    {wait for a keypress}
    I := ReadKeyWord;

    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {erase the help window}
    P := EraseTopWindow;

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}
  end;

  procedure Browse;
    {-Browse through the file}
  const
    Esc = #27;
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
    Done : Boolean;

    function WordStarCommand(Ch : Char) : Char;
      {-Return ^C, 'C', or 'c' as ^C, etc.}
    begin
      Ch := Upcase(Ch);
      case Ch of
        'A'..'Z' : WordStarCommand := Chr(Ord(Ch)-64);
      else WordStarCommand := Ch;
      end;
    end;

  begin
    Done := False;
    repeat
      {redraw the status line}
      SuppressStatus := False;
      DrawStatusLine;

      {get next key}
      ChWord := ReadKeyWord;

      {check for extended scan codes}
      if Ch = #0 then case Hi(ChWord) of
        $00 : Done := True;  {CtrlBreak}
        $13 : ToggleRuler;   {AltR - Ruler on/off}
        $19 : PrintBlock;    {AltP - Print}
        $21,                 {AltF}
        $3D : GetNewFile;    {F3 - New File}
        $3B : Help;          {F1 - Help}
        $47,                 {Home}
        $84 : TopOfFile;     {^PgUp}
        $48 : ScrollUp;      {Up}
        $49 : PageUp;        {PgUp}
        $4B : Left;          {Left}
        $4D : Right;         {Right}
        $4F,                 {End}
        $76 : EndOfFile;     {^PgDn}
        $50 : ScrollDown;    {Down}
        $51 : PageDown;      {PgDn}
        $73 : ScrollLeft;    {^Left - scroll left 20}
        $74 : ScrollRight;   {^Right - scroll right 20}
        {$IFDEF UseMouse}
        $EE : Done := True;  {click right = ESC}
        $ED : Help;          {click both  = F1}
        {$ENDIF}
      end
      else case Ch of
        {regular keys}
        ^K :                 {WordStar ^K commands}
          begin
            {get next key}
            ChWord := TpCrt.ReadKeyWord;
            case WordStarCommand(Ch) of
              '0'..'9' :     {set marker}
                SetMarker(Ord(Ch)-Ord('0'));
              ^D :           {New File}
                GetNewFile;
              ^P :           {Print}
                PrintBlock;
            end;
          end;
        ^Q :                 {WordStar ^Q commands}
          begin
            {get next key}
            ChWord := TpCrt.ReadKeyWord;
            case WordStarCommand(Ch) of
              '0'..'9' :     {jump to marker}
                JumpMarker(Ord(Ch)-Ord('0'));
              ^R : TopOfFile; {top of file}
              ^C : EndOfFile; {end of file}
              ^F : FindString; {search command}
              ^L : GotoLine; {goto line command}
            end;
          end;
        ^E,
        ^W : ScrollUp;       {scroll up}
        ^Z,
        ^X : ScrollDown;     {scroll down}
        ^S : Left;           {scroll left 1}
        ^D : Right;          {scroll right 1}
        ^A : ScrollLeft;     {scroll left 20}
        ^F : ScrollRight;    {scroll right 20}
        ^R : PageUp;         {page up}
        ^C : PageDown;       {page down}
        ^L : FindLast;       {find last search string}
        Esc : Done := True;  {Escape}
      end;
    until Done;
  end;

  procedure Initialize;
    {-Initialization code}
  var
    Escaped, OK : Boolean;
  begin
    {initialize variables}
    BiosScroll := False;
    CheckBreak := False;
    SuppressStatus := True;
    SearchString := '';
    FNameNP := '';
    NumRows := ScreenHeight-2;
    LineWidth := ScreenWidth-2;
    StatusLine := ScreenHeight;

    {set up video attributes}
    SetAttributes;

    {request shadowed, rapidly exploding windows, with no sound}
    Shadow := True;
    Explode := True;
    ExplodeDelay := 3;
    SoundFlagW := False;

    {make sure we can run under DesqView/TaskView}
    DetectMultitasking := True;
    ReinitCrt;

    {see if help is requested}
    if Pos('?', ParamStr(1)) <> 0 then begin
      WriteLn('File Browser. Copyright (c) 1992 by TurboPower Software. Version 5.22'^M^J);
      WriteLn('Usage: VBROWSE FileName [Options]'^M^J);
      WriteLn('Options:');
      WriteLn('  d:\path  Drive and directory for swap file.');
      Halt(0);
    end;

    {create main window}
    if not MakeWindow(MainWindow, Pred(InsideCol), Pred(InsideRow), ScreenWidth,
      ScreenHeight, True, True, False, Dim, Bright, Reverse, ProgName) then
      Abort(InsufficientMemory);

    {display the window}
    if not DisplayWindow(MainWindow) then
      Abort(WindowError);
    ClearStatusLine;

    {hide the cursor}
    HiddenCursor;

    {create help window}
    if not MakeWindow(HelpWindow, HelpCol, HelpRow, HelpCol+Succ(HelpLength),
      HelpRow+Succ(HelpLines), True, True, False, Dim, Bright, Reverse, ' Commands ') then
      Abort(InsufficientMemory);

    {hide the cursor}
    HiddenCursor;

    {save the top line of the screen}
    if not SaveWindow(RulerCol, RulerRow, ScreenWidth, RulerRow, True,
      RulerWindow) then
      Abort(InsufficientMemory);

    {$IFDEF UseMouse}
    if MouseInstalled then begin
      {use a diamond for our mouse cursor}
      SoftMouseCursor($0000, (Bright shl 8)+$04);
      ShowMouse;

      {enable mouse support}
      EnableEditMouse;
    end;
    {$ENDIF}

    {get filename}
    FName := ParamStr(1);
    OK := (Length(FName) <> 0);
    repeat
      if not OK then begin
        Prompt(FilePrompt, Escaped, FName);
        if Escaped then begin
          {$IFDEF UseMouse}
          HideMouse;
          {$ENDIF}
          MainWindow := EraseTopWindow;
          Halt;
        end;
      end;

      {look for the file}
      OK := ExistOnPath(FName, FName);
      if not OK then
        PressAnyKey(FileNotFound);
    until OK;

    {add path identifier to swap file name, if any}
    if ParamCount >= 2 then
      SwapName := JustPathName(ParamStr(2))+SwapName;

    {create the array}
    WriteError := False;
    HaltOnError := False;
    MakeA(LineArray, MaxLines, 1, SizeOf(Line), SwapName, MaxAvail shr 1);
    if ErrorA <> 0 then
      {presumably not enough memory}
      Abort(InsufficientMemory);

    {read in the file}
    ReadNewFile(FName);
  end;

begin
  {get command line parameters, if any, and initialize}
  Initialize;

  {browse through the file}
  Browse;

  {clean up the screen}
  CleanUp;
end.
