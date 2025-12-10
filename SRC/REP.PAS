{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 4000,65536,655360}

{*********************************************************}
{*                      REP.PAS 5.22                     *}
{*                    Command repeater                   *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program Rep;
  {-Repeat commands}

uses
  Dos,                       {standard DOS/BIOS routines}
  TpString,                  {Turbo Professional string handling routines}
  TpCmdLin,                  {Turbo Professional command line parsing routines}
  TpDos,                     {Turbo Professional DOS call routines}
  TpInt,                     {Turbo Professional ISR management}
  TpMacro;                   {Turbo Professional macro engine}

var
  StdErr : Text;             {File for screen status}
  StdErrBuf : Char;          {Buffer for writing to StdErr}
  ConIn : Boolean;           {True if input is from keyboard}
  Query : Boolean;           {True to prompt before processing each command}
  HaveKeys : Boolean;        {True if macro keystrokes specified}
  Command : string;          {Mask for command to execute}
  ActualCommand : string;    {Actual command after tokens inserted}
  Keys : string;             {Keys to send to command}
  InputLine : string;        {Line from input stream}
  Repeats : Integer;         {Number of times to repeat}
  R : Integer;               {Which repeat is happening}

  procedure FatalError(msg : string);
    {-Report message and halt}
  begin
    RemoveMacros;
    WriteLn(StdErr);
    if msg <> '' then
      WriteLn(StdErr, msg);
    Halt(1);
  end;

  procedure WriteHelp;
    {-Show a brief help screen and halt}
  begin
    WriteLn('Usage: REP "Command" [Options] [<InputStream]');
    WriteLn('Options:');
    WriteLn('   /K KeyList - Pass keys in KeyList to Command');
    WriteLn('   /Q - Query before proceeding');
    WriteLn('   /R n - Repeat Command n times');
    WriteLn('Command:');
    WriteLn('  May not directly specify input or output redirection, but may');
    WriteLn('  contain the following parser symbols:');
    WriteLn('     @n - nth word in the input line (for n in 1..9)');
    WriteLn('     @0 - whole input line');
    WriteLn('     @B - discretionary DOS backslash \');
    WriteLn('     @D - directory name from first word of input line');
    WriteLn('     @F - filename from first word of input line');
    WriteLn('     @I - input redirection symbol <');
    WriteLn('     @O - output redirection symbol >');
    WriteLn('     @P - piping symbol |');
    WriteLn('KeyList:');
    WriteLn('  May contain normal ASCII characters or specify them by number.');
    WriteLn('     #nnn - ASCII character nnn (decimal)');
    WriteLn('  Enter #0#Scan for extended scan codes (e.g., #0#59 = <F1>).');
    WriteLn('  May also contain parser symbols as described above.');
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

    {Is standard input coming from keyboard?}
    ConIn := HandleIsConsole(0);

    Command := '';
    Keys := '';
    Query := False;
    Repeats := 1;
  end;

  procedure GetParameters;
    {-Analyze command line for parameters}
  var
    I : Integer;
    Arg : string;
  begin
    I := 1;
    while I <= ParamCount do begin
      Arg := ParamStr(I);

      if (Length(Arg) = 2) and ((Arg[1] = '/') or (Arg[1] = '-')) then
        {A command directive}
        case Upcase(Arg[2]) of
          'K' : Keys := GetArgString(I, True, True);
          'R' : Repeats := GetArgNumber(I);
          'Q' : Query := True;
        else
          FatalError('Unrecognized option: '+Arg);
        end

      else if Command = '' then begin
        {Convert escapes and ascii numerals into a full match string}
        Dec(I);
        Command := GetArgString(I, True, False);

      end else
        FatalError('More than one command string specified');

      case CmdLineError of
        1 : FatalError('Missing argument after '+ParamStr(I));
        2 : FatalError('Invalid argument: '+ParamStr(I));
        3 : FatalError('Program error in unit TpCmdLin');
      end;

      {On to next parameter}
      Inc(I);
    end;

    if Command = '' then
      FatalError('No command specified');

    HaveKeys := (Keys <> '');
  end;

  procedure RunExec(var Command : string; HaveKeys : Boolean);
    {-Execute the specified command and check for error}
  var
    ExecStatus : Integer;
  begin
    if not(Query) then
      WriteLn(StdErr, Command, ^M^J);

    if HaveKeys then begin
      {Play the macro for the command}
      MacrosOn;
      StartMacro(@ScrapMacro);
    end;

    {Run the command}
    ExecStatus := execdos(Command, True, nil);

    {Check for errors}
    case ExecStatus of
      0 : {Success} ;
      -1 : FatalError('Insufficient free list memory');
      -2 : FatalError('DOS setblock error');
      -3 : FatalError('DOS setblock error after EXEC');
      -4 : FatalError('Insufficient DOS memory');
    else
      FatalError('DOS error '+long2str(ExecStatus));
    end;

    {Turn off macros until next time}
    if HaveKeys then
      MacrosOff;

  end;

  function ConvertTokens(var Mask, Line : string) : string;
    {-Replace tokens in mask with counterparts from line}
  var
    Mpos : Word;
    Lpos : Integer;
    OutStr : string;
  begin
    {Scan the mask}
    Mpos := 1;
    OutStr := '';
    while Mpos <= Length(Mask) do begin
      if Mask[Mpos] = '@' then begin
        Inc(Mpos);

        case Upcase(Mask[Mpos]) of
          '@' :              {Single at sign}
            OutStr := OutStr+'@';
          '0' :              {Whole line}
            OutStr := OutStr+Line;
          '1'..'9' :         {Nth word}
            OutStr := OutStr+ParamStrPos(Line, Ord(Mask[Mpos])-Ord('0'), Lpos);
          'B' :              {Discretionary backslash}
            OutStr := addbackslash(OutStr);
          'D' :              {Directory of first word}
            OutStr := OutStr+justpathname(ParamStrPos(Line, 1, Lpos));
          'F' :              {Filename of first word}
            OutStr := OutStr+justfilename(ParamStrPos(Line, 1, Lpos));
          'I' :              {Input redirection symbol}
            OutStr := OutStr+'<';
          'O' :              {Output redirection symbol}
            OutStr := OutStr+'>';
          'P' :              {Piping symbol}
            OutStr := OutStr+'|';
        else
          OutStr := OutStr+Mask[Mpos];
        end;

      end else
        OutStr := OutStr+Mask[Mpos];

      Inc(Mpos);
    end;

    ConvertTokens := OutStr;
  end;

  procedure BuildMacro(Line : string);
    {-Convert line into a macro, stored in TempMacro}
  var
    ActualKeys : string;
    Alen : Byte absolute ActualKeys;
    I : Word;
  begin
    {Replace tokens with their values}
    ActualKeys := ConvertTokens(Keys, Line);

    {Convert to macro format, storing in the ScrapMacro}
    with ScrapMacro do begin
      numkeys := 0;
      I := 1;
      while I <= Alen do begin
        if (ActualKeys[I] = #0) and (I < Alen) then begin
          Inc(I);
          Inc(numkeys);
          {Scan code in high byte, #0 in low}
          keyarray[numkeys] := Ord(ActualKeys[I]) shl 8;
        end else begin
          Inc(numkeys);
          keyarray[numkeys] := chartomacro(ActualKeys[I]);
        end;
        Inc(I);
      end;
      keyarray[Succ(numkeys)] := endofmacro;
    end;
  end;

  function ReadKeyIn(List : string) : Char;
    {-Read via BIOS until key matches one in list}
  var
    C : Char;
    Regs : registers;
  begin
    with Regs do
      repeat
        ah := 0;
        intr($16, Regs);
        C := Upcase(Char(al));
        if pos(C, List) <> 0 then begin
          ReadKeyIn := C;
          Exit;
        end;
      until False;
  end;

  function DoQuery(Command : string) : Char;
    {-Assure we should go ahead with command}
  var
    C : Char;
  begin
    if Query then begin
      WriteLn(StdErr, 'Command: ', stupcase(Command));
      Write(StdErr, 'OK to proceed? Y/N/Q ');
      C := ReadKeyIn('YNQ');
      WriteLn(StdErr);
      DoQuery := C;
    end else
      DoQuery := 'Y';
  end;

begin

  Initialize;
  WriteLn(StdErr, 'Command Repeater. Copyright (c) 1992 by TurboPower Software. Version 5.22');
  WriteLn(StdErr);

  if ParamCount = 0 then
    WriteHelp
  else
    GetParameters;

  if ConIn then begin
    {Std input not redirected, just repeat the command}
    for R := 1 to Repeats do begin
      if HaveKeys then
        BuildMacro('');
      RunExec(Command, HaveKeys);
    end;

  end else begin
    {Std input redirected}
    while not(eof) do begin
      ReadLn(InputLine);
      if IoResult <> 0 then
        FatalError('Error reading input stream');
      if InputLine <> '' then begin
        ActualCommand := ConvertTokens(Command, InputLine);
        if HaveKeys then
          BuildMacro(InputLine);
        case DoQuery(ActualCommand) of
          'Q' : FatalError('');
          'Y' : RunExec(ActualCommand, HaveKeys);
          'N' : ;
        end;
      end;
    end;

  end;

  {Give back interrupts we took}
  RemoveMacros;
end.
