{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{*********************************************************}
{*                  TPCMDLIN.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TPCmdLin;
  {-Accessing the command line}

interface

function CmdLineError : Integer;
  {-Return 0 for success,
    1 for missing argument,
    2 for invalid argument,
    3 for internal error}

function ParamCnt(P : string) : Integer;
  {-Return the number of parameters in the string P}

function ParamStrPos(P : string; Param : Integer; var StartPos : Integer) : string;
  {-Return the specified parameter and its position in the string at P^}

function ConvertArg(InStr : string; ConvertAsc : Boolean) : string;
  {-Return a string with asciis (#nnn) converted to characters}

function GetArgString(var I : Integer;
                      TakeQuoted : Boolean;
                      ConvertAscii : Boolean) : string;
  {-Get string argument following parameter i}

function GetArgNumber(var I : Integer) : Integer;
  {-Return number following argument i}

  {==========================================================================}

implementation

const
  Quote = #39;               {Single quote '}
  Dquote = #34;              {Double quote "}
const
  Numbers : set of Char = ['0'..'9'];
var
  CmdLineErrorLast : Integer;

  function CmdLineError : Integer;
    {-Return 0 for success,
    1 for missing argument,
    2 for invalid argument}
  begin
    CmdLineError := CmdLineErrorLast;
    CmdLineErrorLast := 0;
  end;

  function ParamCnt(P : string) : Integer;
    {-Return the number of parameters in the string P}
  var
    InWhite : Boolean;
    ParamNum : Integer;
    StartPos : Integer;
  begin
    StartPos := 0;
    InWhite := True;
    ParamNum := 0;

    {Count the parameters}
    repeat
      Inc(StartPos);
      if StartPos <= Length(P) then
        case P[StartPos] of
          #9, #32 : InWhite := True;
        else
          if InWhite then begin
            {Next parameter}
            Inc(ParamNum);
            InWhite := False;
          end;
        end;
    until (StartPos > Length(P));
    ParamCnt := ParamNum;
  end;

  function ParamStrPos(P : string; Param : Integer; var StartPos : Integer) : string;
    {-Return the specified parameter and its position in the string P}
  var
    InWhite : Boolean;
    ParamNum : Integer;
    EndPos : Integer;
  begin
    StartPos := 0;
    InWhite := True;
    ParamNum := 0;

    {Scan to find start of param'th parameter}
    repeat
      Inc(StartPos);
      if StartPos <= Length(P) then
        case P[StartPos] of
          #9, #32 : InWhite := True;
        else
          if InWhite then begin
            {Next parameter}
            Inc(ParamNum);
            InWhite := False;
          end;
        end;
    until (StartPos > Length(P)) or (ParamNum = Param);

    if ParamNum = Param then begin
      {Scan to find end of parameter}
      EndPos := StartPos;
      repeat
        Inc(EndPos);
        case P[EndPos] of
          #9, #32 : InWhite := True;
        end;
      until InWhite or (EndPos > Length(P));

      {Return the parameter}
      ParamStrPos := Copy(P, StartPos, EndPos-StartPos);

    end else
      {No such parameter}
      ParamStrPos := '';
  end;

  function ConvertAscii(InStr : string; var InPos : Word) : Char;
    {-Return character corresponding to numeric sequence starting at inpos}
  var
    Num : string;
    NumVal : Integer;
    Code : Word;
  begin
    Num := '';
    {Collect the numeric string}
    while (InStr[InPos] in Numbers) and (Length(Num) <= 3) do begin
      Num := Num+InStr[InPos];
      Inc(InPos);
    end;
    {Convert it to number}
    Val(Num, NumVal, Code);
    if Code <> 0 then begin
      CmdLineErrorLast := 2;
      Exit;
    end;
    ConvertAscii := Char(lo(NumVal));
  end;

  function ConvertArg(InStr : string; ConvertAsc : Boolean) : string;
    {-Analyze the argument, returning a string with escapes and asciis expanded}
  const
    Ascii = '#';
  var
    OutStr : string;
    InPos : Word;

    procedure AppendC(var OutStr : string; Ch : Char; var InPos : Word);
      {-Append a character to outstr}
    begin
      OutStr := OutStr+Ch;
      Inc(InPos);
    end;

  begin
    {Initialize position}
    InPos := 1;
    OutStr := '';

    {Scan the argument}
    while InPos <= Length(InStr) do
      case InStr[InPos] of
        Ascii :
          if not(ConvertAsc) then
            AppendC(OutStr, InStr[InPos], InPos)
          else if (InPos < Length(InStr)) and (InStr[Succ(InPos)] in Numbers) then begin
            Inc(InPos);
            OutStr := OutStr+ConvertAscii(InStr, InPos);
          end else
            AppendC(OutStr, InStr[InPos], InPos);
      else
        AppendC(OutStr, InStr[InPos], InPos);
      end;

    ConvertArg := OutStr;
  end;

  function GetQuoted(var I : Integer) : string;
    {-Return quoted region of command line, starting at parameter I.
      Return I pointing to last word parameter used.}
  var
    PS : ^string;
    QuoteChar : Char;
    Posn : Integer;
    SPosn : Integer;
    InWhite : Boolean;
  begin
    {Define pointer to command line string}
    PS := Ptr(PrefixSeg, $80);

    {Find position of start of quote}
    if ParamStrPos(PS^, I, Posn) = '' then begin
      CmdLineErrorLast := 2;
      Exit;
    end;

    {Store starting quote character}
    QuoteChar := PS^[Posn];
    SPosn := Posn;

    {Scan till end of quote}
    InWhite := False;
    repeat
      Inc(Posn);
      if Posn <= Length(PS^) then
        case PS^[Posn] of
          #9, #32 : InWhite := True;
        else
          if InWhite then begin
            {Next parameter}
            Inc(I);
            InWhite := False;
          end;
        end;
    until (Posn > Length(PS^)) or (PS^[Posn] = QuoteChar);

    {Return the quoted string}
    GetQuoted := Copy(PS^, Succ(SPosn), Pred(Posn-SPosn));
  end;

  function GetArgString(var I : Integer; TakeQuoted : Boolean;
                        ConvertAscii : Boolean) : string;
    {-Get string argument following parameter i}
  var
    Arg : string;
  begin
    if I >= ParamCount then begin
      CmdLineErrorLast := 2;
      Exit;
    end;
    Inc(I);
    Arg := ParamStr(I);
    if TakeQuoted then
      if (Arg[1] = Quote) or (Arg[1] = Dquote) then
        {Take entire command line until end quote}
        Arg := GetQuoted(I);
    GetArgString := ConvertArg(Arg, ConvertAscii);
  end;                       {GetArgString}

  function GetArgNumber(var I : Integer) : Integer;
    {-Return number following argument i}
  var
    Code : Word;
    Num : Integer;
  begin
    if I >= ParamCount then begin
      CmdLineErrorLast := 1;
      Exit;
    end;
    Inc(I);
    Val(ParamStr(I), Num, Code);
    if Code <> 0 then
      CmdLineErrorLast := 2;
    GetArgNumber := Num;
  end;

begin
  CmdLineErrorLast := 0;
end.
