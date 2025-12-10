{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{*********************************************************}
{*                    BSORT.PAS 5.22                     *}
{*                 File sorting utility                  *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program BigSort;
  {-DOS filter to sort text files}

uses
  Dos,
  TpString,
  TpDos,
  TpSort;

const
  BufSize = 8192;

type
  TextBuffer = array[1..BufSize] of Char;
  PartialLineRec =
    record
      fpos : LongInt;        {Position of line in input file}
      key : string;          {Portion of input line used as key}
    end;
  PartialP = ^PartialLineRec;

var
  Status : SortStatus;       {Success of sort}
  Start : LongInt;           {Gets time in milliseconds}
  StdErr : Text;             {For status reporting}
  TextBuf : TextBuffer;      {Speeds input and output}
  GetProc : Pointer;         {Points to Input procedure to use}
  PutProc : Pointer;         {Points to Output procedure to use}
  LessFunc : Pointer;        {Points to Less function to use}
  IgnoreCase : Boolean;      {True to sort ignoring case}
  Reverse : Boolean;         {True to sort in reverse order}
  Partial : Boolean;         {True to use partial lines as keys}
  StartCol : Integer;        {First column of key}
  KeyLen : Integer;          {Length of key}
  ElSize : Word;             {Size of each sort element}
  StdErrBuf : Char;          {Forces StdErr to write a char at a time}
  Elements : Word;           {Number of elements we can sort}
  SaveExitProc : Pointer;    {Saved value of ExitProc}

  function Ms2S(ms : LongInt) : string;
    {-Convert milliseconds to seconds in a string}
  var
    s : string;
  begin
    Str(ms, s);
    {Pad out to three decimal places}
    while Length(s) < 3 do
      s := '0'+s;
    {Truncate to nearest tenth of a second}
    Dec(s[0]);
    Dec(s[0]);
    {Insert decimal point}
    Insert('.', s, Length(s));
    {Insert leading zero}
    if Length(s) = 2 then
      s := '0'+s;
    Ms2S := s;
  end;

  procedure Error(msg : string);
    {-Report error through StdErr and halt}
  begin
    WriteLn(StdErr, ^M^J, msg);
    Close(StdErr);
    Halt(1);
  end;

  {$F+}

  procedure GetStr;
    {-Read all of the strings from the standard input}
  var
    s : string;
  begin
    Start := TimeMs;
    Write(StdErr, 'Reading ');

    SetTextBuf(Input, TextBuf, BufSize);
    while not(eof) do begin
      ReadLn(s);
      if IoResult <> 0 then
        Error('Error reading input');
      {Add the element to the sort set}
      if not(PutElement(s)) then
        Exit;
    end;

    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');

    {Prepare for sorting phase}
    Write(StdErr, 'Sorting ');
    Start := TimeMs;
  end;

  procedure PutStr;
    {-Write the sorted strings to the standard output}
  var
    s : string;
  begin
    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');

    {Prepare for writing phase}
    Write(StdErr, 'Writing ');
    Start := TimeMs;

    SetTextBuf(Output, TextBuf, BufSize);
    while GetElement(s) do begin
      WriteLn(s);
      if IoResult <> 0 then
        Error('Error writing output');
    end;
    Write(^Z);

    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');
  end;

  function Less(var X, Y) : Boolean;
    {-Compare two strings}
  var
    Xs : string absolute X;
    Ys : string absolute Y;
  begin
    if IgnoreCase then begin
      if Reverse then
        Less := (StUpcase(Ys) < StUpcase(Xs))
      else
        Less := (StUpcase(Xs) < StUpcase(Ys));
    end else begin
      if Reverse then
        Less := (Ys < Xs)
      else
        Less := (Xs < Ys);
    end;
  end;

  procedure PartialGetStr;
    {-Read all of the strings from the standard input}
  var
    s : string;
    p : PartialP;
    posn : LongInt;
  begin
    Start := TimeMs;
    Write(StdErr, 'Reading ');

    SetTextBuf(Input, TextBuf, BufSize);
    while not(eof) do begin
      {Get position before reading line}
      posn := textpos(Input);
      if posn = -1 then
        {Error getting textpos}
        Error('Error reading input');
      ReadLn(s);
      if IoResult <> 0 then
        Error('Error reading input');
      {Allocate the partial line record}
      GetMem(p, 5+KeyLen);
      if p = nil then
        Error('Insufficient memory');
      with p^ do begin
        {Store where the line is in the input file}
        fpos := posn;
        {Extract the key}
        if IgnoreCase then
          key := StUpcase(Copy(s, StartCol, KeyLen))
        else
          key := Copy(s, StartCol, KeyLen);
      end;
      {Add the element to the sort set}
      if not(PutElement(p)) then
        Exit;
    end;

    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');

    {Prepare for sorting phase}
    Write(StdErr, 'Sorting ');
    Start := TimeMs;
  end;

  procedure PartialPutStr;
    {-Write the sorted strings to the standard output}
  var
    s : string;
    p : PartialP;
  begin
    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');
    {Prepare for writing phase}
    Write(StdErr, 'Writing ');
    Start := TimeMs;

    {Use a small buffer to avoid reading wasted bytes}
    SetTextBuf(Input, TextBuf, 256);
    while GetElement(p) do begin
      with p^ do begin
        if not(textseek(Input, fpos)) then
          Error('Error writing output');
        ReadLn(s);
      end;
      WriteLn(s);
      if IoResult <> 0 then
        Error('Error writing output');
    end;
    Write(^Z);

    WriteLn(StdErr, Ms2S(TimeMs-Start), ' seconds');
  end;

  function PartialLess(var X, Y) : Boolean;
    {-Compare two strings}
  var
    Xp : PartialP absolute X;
    Yp : PartialP absolute Y;
  begin
    if Reverse then
      PartialLess := (Yp^.key < Xp^.key)
    else
      PartialLess := (Xp^.key < Yp^.key);
  end;

  {$F-}

  procedure Unrecognized(msg : string);
    {-Report error for unrecognized command line option}
  begin
    Error('Unrecognized option: '+msg);
  end;

  function GetArgNumber(var I : Integer) : Integer;
    {-Return number following argument i}
  var
    Code : Word;
    Num : Integer;
  begin
    if I >= ParamCount then
      Error('Numeric value does not follow '+ParamStr(I));
    Inc(I);
    Val(ParamStr(I), Num, Code);
    if Code <> 0 then
      Error('Invalid numeric value '+ParamStr(I));
    GetArgNumber := Num;
  end;

  procedure GetOptions;
    {-Analyze the command line for options}
  var
    Arg : string;
    I : Integer;
  begin

    {Default state}
    IgnoreCase := False;
    Reverse := False;
    Partial := False;
    StartCol := 1;
    KeyLen := 255;

    I := 1;
    while I <= ParamCount do begin

      Arg := ParamStr(I);
      if Length(Arg) <> 2 then
        Unrecognized(Arg);
      if (Arg[1] <> '/') and (Arg[1] <> '-') then
        Unrecognized(Arg);

      case Upcase(Arg[2]) of
        'R' : Reverse := True;
        'I' : IgnoreCase := True;
        'B' : begin
                StartCol := GetArgNumber(I);
                Partial := True;
              end;
        'L' : begin
                KeyLen := GetArgNumber(I);
                Partial := True;
              end;
      else
        Unrecognized(Arg);
      end;

      Inc(I);
    end;

    if Partial then begin
      {Special routines for partial lines}
      GetProc := @PartialGetStr;
      PutProc := @PartialPutStr;
      LessFunc := @PartialLess;
      ElSize := SizeOf(Pointer);
    end else begin
      {Default user-defined routines}
      GetProc := @GetStr;
      PutProc := @PutStr;
      LessFunc := @Less;
      ElSize := 0;
    end;

    {Make best use of available memory}
    Elements := MaxElements;
    if MemAvail < LongInt(Elements)*SizeOf(Pointer) then
      Elements := MemAvail div (SizeOf(Pointer) shl 1);

  end;

  {$F+}
  procedure ExitHandler;
    {-Restore cooked mode for standard input/output}
  begin
    ExitProc := SaveExitProc;
    SetRawMode(Input, False);
    SetRawMode(Output, False);
  end;
  {$F-}

begin

  {Open StdErr for status reporting}
  if not(OpenStdDev(StdErr, 2)) then begin
    WriteLn('Error opening StdErr');
    Halt(1);
  end else
    {Force buffer flush every character}
    SetTextBuf(StdErr, StdErrBuf, 1);
  WriteLn(StdErr, 'Big Sort. Copyright (c) 1987,92 by TurboPower Software. Version 5.22');

  {Make sure input was redirected}
  if HandleIsConsole(0) then begin
    {It wasn't, write some help}
    WriteLn(StdErr);
    WriteLn(StdErr, 'Usage: BSORT [Options] <InputFile >OutputFile');
    WriteLn(StdErr);
    WriteLn(StdErr, 'Options:');
    WriteLn(StdErr, '  /R    Sort in reverse order');
    WriteLn(StdErr, '  /I    Sort ignoring case');
    WriteLn(StdErr, '  /B n  Sort with key starting in column n');
    WriteLn(StdErr, '  /L n  Sort with maximum key length of n characters');
    Error('');
  end;

  {Analyze the command line and set defaults}
  GetOptions;

  {install exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @ExitHandler;

  {select raw mode for standard input/output}
  SetRawMode(Input, True);
  SetRawMode(Output, True);

  {Sort strings}
  Status := Sort(Elements, ElSize, GetProc, LessFunc, PutProc);

  {Were we successful?}
  case Status of
    SortSuccess : WriteLn(StdErr, ElementsSorted, ' elements sorted');
    SortOutOfMemory : Error('Insufficient memory');
    SortTooManyElements : Error('Too many elements to sort');
  end;

  Close(StdErr);
end.
