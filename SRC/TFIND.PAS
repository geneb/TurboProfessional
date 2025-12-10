{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{Lots of stack space for recursion, heap not used}
{$M 65000,0,0}

{*********************************************************}
{*                     TFIND.PAS 5.22                    *}
{*                   Text find utility                   *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program TextFind;
  {-Search a group of files, reporting matches to a string}

uses
  Dos,
  TPString,
  TPCmdLin,
  TPdos,
  TPAsciiz;

const
  BufSize = 8192;            {Size of input file buffer}
  MaxAvoids = 13;            {Max number of extensions to avoid analyzing}

type
  TextBuffer = array[1..BufSize] of Char;
  PathName = string[64];
  AvoidArray = array[1..MaxAvoids] of string[3];

const
  Avoids : AvoidArray =      {Extensions to avoid during searching}
  ('COM', 'EXE', 'OBJ', 'TPU', 'TPL', 'TPM', 'BIN', 'WKS',
   'TPP', 'TPW', 'ARC', 'ZIP', 'LZH');

var
  StdErr : Text;             {File for screen status}
  TextBuf : TextBuffer;      {For speeding input reads}
  StartDir : PathName;       {Drive:directory where searching starts}
  FileMask : PathName;       {Mask to decide which files to match}
  FileCount : Word;          {Number of files searched}
  LineCount : LongInt;       {Number of lines searched}
  MatchCount : LongInt;      {Number of matches found}
  Recursive : Boolean;       {True to search all subdirectories of StartDir}
  IgnoreCase : Boolean;      {True to ignore case while searching}
  ShowLines : Boolean;       {True to display each line of text that matches}
  ConOut : Boolean;          {True if all output is to screen}
  CheckAvoid : Boolean;      {True to avoid certain file extensions}
  MsgLen : Word;             {Number of characters currently on status line}
  Match : string;            {String to match against}
  BT : BTable;               {Search table for Boyer-Moore}
  CurLine : Asciiz;          {Current line of text being checked}
  StdErrBuf : Char;          {Buffer for writing to StdErr}
  ElTime : LongInt;          {Elapsed time for statistics}
  LastStatLen : Word;        {Length of last line counter for status}
  NextStep : LongInt;        {Next order of magnitude where LastStatLen increases}

  procedure ClearMessage;
    {-Clear the message line}
  begin
    if MsgLen > 0 then begin
      Write(StdErr, ^M, CharStr(' ', MsgLen), ^M);
      MsgLen := 0;
    end;
  end;

  procedure Message(msg : string);
    {-Write a message to StdErr}
  begin
    Write(StdErr, msg);
    Inc(MsgLen, Length(msg));
  end;

  procedure FatalError(msg : string);
    {-Write error message and halt}
  begin
    ClearMessage;
    Message(msg+^M^J);
    Halt(1);
  end;

  function Avoid(Ext : PathName) : Boolean;
    {-Return true if ext falls in the AVOIDS list}
  var
    I : Integer;
  begin
    Avoid := False;
    Ext := StUpcase(Ext);
    for I := 1 to MaxAvoids do
      if Avoids[I] = '' then
        Exit
      else if Ext = Avoids[I] then begin
        Avoid := True;
        Exit;
      end;
  end;

  procedure UpdateLineCount(Fline : LongInt; Backup : Boolean);
    {-Update the line counter on the status line}
  begin
    if Backup then begin
      Write(StdErr, CharStr(^H, LastStatLen));
      Dec(MsgLen, LastStatLen);
    end;
    Message('('+Long2Str(Fline)+')');
    if Fline >= NextStep then
      repeat
        Inc(LastStatLen);
        NextStep := 10*NextStep;
      until NextStep > Fline;
  end;

  procedure SearchFile(FName : PathName);
    {-Search a file for matches to the match string}
  label
    exitpoint;
  var
    f : Text;
    Fline : LongInt;
    Posn : Word;
    Len : Word;
  begin

    {See if this file is to be avoided}
    if CheckAvoid then
      if Avoid(JustExtension(FName)) then
        Exit;

    if Match = '' then begin
      {Just report the file name}
      WriteLn(Output, FName);
      Exit;
    end;

    {Open the file}
    Assign(f, FName);
    Reset(f);
    if IoResult <> 0 then
      Exit;
    SetTextBuf(f, TextBuf, BufSize);

    {Status for file we're searching}
    LastStatLen := 3;
    NextStep := 10;
    ClearMessage;
    Message(FName);
    UpdateLineCount(0, False);
    Fline := 00;

    while not(eof(f)) do begin

      {Read the next line from the file - up to max length of Asciiz}
      if not(ReadLnAsc(f, CurLine)) then
        goto exitpoint;

      Inc(LineCount);
      Inc(Fline);
      if Fline and 255 = 0 then
        UpdateLineCount(Fline, True);

      {Search the line}
      Len := LenAsc(CurLine);
      if IgnoreCase then
        Posn := BMSearchUC(CurLine, Len, BT, Match)
      else
        Posn := BMSearch(CurLine, Len, BT, Match);

      if Posn <> NotFound then begin
        {Found it, write the output}
        Inc(MatchCount);

        if ConOut then begin
          {All output going to console}
          UpdateLineCount(Fline, True);
          WriteLn(StdErr);
          MsgLen := 0;
          if ShowLines then begin
            if not(WriteAsc(StdErr, CurLine)) then
              goto exitpoint;
            Write(StdErr, ^M^J^M^J);
            Message(FName);
            UpdateLineCount(Fline, False);
          end else
            goto exitpoint;
        end else begin
          {Only status is written to console}
          if ShowLines then begin
            WriteLn(Output, ^M^J, FName, '(', Fline, ') ', Succ(Posn));
            if not(WriteAsc(Output, CurLine)) then
              goto exitpoint;
            WriteLn(Output);
            if IoResult <> 0 then
              goto exitpoint;
          end else begin
            {Just display the file name and exit}
            WriteLn(Output, FName);
            goto exitpoint;
          end;
        end;
      end;

    end;

exitpoint:
    Close(f);
    Inc(FileCount);
  end;

  procedure SearchDir(FDir : PathName);
    {-search files in one directory}
  var
    Frec : SearchRec;
  begin

    {Scan all the files in the current directory}
    findfirst(AddBackSlash(FDir)+FileMask, anyfile, Frec);
    while doserror = 0 do begin
      with Frec do
        if attr and 24 = 0 then
          {Not a subdirectory or volume label}
          SearchFile(FullPathName(AddBackSlash(FDir)+Name));
      {Try again for next file}
      findnext(Frec);
    end;

    {Scan the subdirectories of the current directory}
    if Recursive then begin
      findfirst(AddBackSlash(FDir)+'*.*', anyfile, Frec);
      while doserror = 0 do begin
        with Frec do
          if (attr and 16 <> 0) and (Name[1] <> '.') then begin
            {Search subdirectory}
            SearchDir(AddBackSlash(FDir)+Name);
            {Restore DTA}
            SetDta(@Frec);
          end;
        {Try again for next file}
        findnext(Frec);
      end;
    end;
  end;

  procedure WriteHelp;
    {-Show a brief help screen and halt}
  begin
    WriteLn('Usage: TFIND [Options] MatchString');
    WriteLn;
    WriteLn('Options:');
    WriteLn('   /C - Make searching case sensitive');
    WriteLn('   /F - Show matching file names only');
    WriteLn('   /N - Exclude no file extensions from search');
    WriteLn('   /R - Recursively search all subdirectories');
    WriteLn('   /S [d:][path\][mask] - Start search in d:path and');
    WriteLn('        search only files matching mask');
    WriteLn;
    WriteLn('MatchString:');
    WriteLn('   If MatchString is empty, TFIND reports all files matching mask.');
    WriteLn('   If surrounded by quotes (""), MatchString may contain white space.');
    WriteLn('   It also may contain ASCII characters specified numerically:');
    WriteLn('     #nnn - ASCII character nnn (decimal)');
    Halt(1);
  end;

  procedure Initialize;
    {-Initialize globals}
  begin
    {Open StdErr for status reporting}
    if not(OpenStdDev(StdErr, 2)) then begin
      WriteLn('Error opening StdErr');
      Halt(1);
    end else
      {Force buffer flush every character}
      SetTextBuf(StdErr, StdErrBuf, 1);

    {Is standard output going to screen?}
    ConOut := HandleIsConsole(1);

    {Set default search parameters}
    StartDir := '';
    FileMask := '*.*';
    Match := '';
    MsgLen := 0;
    FileCount := 0;
    LineCount := 00;
    MatchCount := 00;
    Recursive := False;
    IgnoreCase := True;
    ShowLines := True;
    CheckAvoid := True;
  end;

  procedure GetParameters;
    {-Analyze command line for parameters}
  var
    I : Integer;
    Arg : string;
    DirMask : string;
  begin
    DirMask := '';

    I := 1;
    while I <= ParamCount do begin
      Arg := ParamStr(I);
      if (Length(Arg) = 2) and ((Arg[1] = '/') or (Arg[1] = '-')) then
        case Upcase(Arg[2]) of
          'C' : IgnoreCase := False;
          'F' : ShowLines := False;
          'N' : CheckAvoid := False;
          'R' : Recursive := True;
          'S' : DirMask := GetArgString(I, False, False);
        else
          FatalError('Unrecognized option: '+Arg);
        end

      else if Match = '' then begin
        Dec(I);
        Match := GetArgString(I, True, True);

      end else
        FatalError('More than one match string specified');

      {On to next parameter}
      Inc(I);
    end;

    if IgnoreCase then
      Match := StUpcase(Match);

    if Match <> '' then
      {Build the Boyer-Moore search table}
      BMMakeTable(Match, BT);

    if DirMask <> '' then begin
      StartDir := StUpcase(JustPathname(DirMask));
      FileMask := StUpcase(JustFilename(DirMask));
    end;
  end;

  procedure ShowStats;
    {-Show statistics at the end of run}
  begin
    ClearMessage;
    WriteLn(StdErr, 'Files searched: ', FileCount);
    WriteLn(StdErr, 'Lines searched: ', LineCount);
    WriteLn(StdErr, 'Matches found : ', MatchCount);
    if (LineCount > 0) and (ElTime > 0) then
      WriteLn(StdErr, 'Lines per sec : ', (1000*LineCount) div ElTime);
  end;

begin
  Initialize;
  WriteLn(StdErr, 'Text Finder. Copyright (c) 1987,92 by TurboPower Software. Version 5.22');
  WriteLn(StdErr);

  if ParamCount = 0 then
    WriteHelp
  else
    GetParameters;

  ElTime := TimeMs;
  SearchDir(StartDir);
  ElTime := TimeMs-ElTime;

  if Match <> '' then
    ShowStats;
end.
