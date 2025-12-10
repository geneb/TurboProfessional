{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$IFDEF Dpmi}
  !! ERROR - This program is not compatible with Protected mode !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 2048,0,200}

{$I TPDEFINE.INC} {!!.21}

{*********************************************************}
{*                   PCALC.PAS 5.22                      *}
{*               Programmer's Calculator                 *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}
{* Define KB5151 to set up for Keytronics KB5151         *}
{* Lew Paper, 3/18/88                                    *}
{*********************************************************}

program PCalc;
  {-Programmer's calculator}

uses
  Dos,                       {standard DOS/BIOS routines}
  TpBCD,                     {Turbo Professional BCD math routines}
  TpString,                  {Turbo Professional string handling routines}
  TpCrt,                     {Turbo Professional CRT unit}
  TpInt,                     {Turbo Professional ISR management}
  TpTsr;                     {Turbo Professional TSR management}

const
  {** keep the following together to allow easy patching **}
  ModuleName : string[5] = 'PCALC'; {module name for standard interface}
  OurHotKey : Word = $052E;  {Ctrl + RightShift, 'C'}
  Div0Handle : Byte = 15;
  {******************* end of patch area ******************}

  DisableOurselves : Boolean = False; {if true, disable the TSR}

type
  String80 = string[80];
  VideoWord = record
                Ch : Char; Attr : Byte;
              end;
  ScreenType = array[1..43, 1..80] of VideoWord; {43 rows * 80 columns}
  ScreenBuffer = array[1..10, 1..45] of VideoWord; {10 rows * 45 columns}
  CalcType = (None, Add, Subtract, Multiply, Divide,
    AndOp, ModOp, NotOp, OrOp, XorOp, ShlOp, ShrOp);
  CalcMode = (Decimal, Hexadecimal, Binary, FloatPt, Exponential);
  CalcStatus = (Cleared, Done, Num1, Num2);
const
  ProgName : string[35] = 'PCALC: Programmer''s Calculator 5.22';
  Copyright : string[41] = 'Copyright (c) 1992 by TurboPower Software';
  CommandLabel1 : string[56] =
  ' Clr Entry Binary Dec Hex Float exP Key ';
  CommandLabel2 : string[58] =
  ' Save Insert And Mod Not Or Xor shL shR ';
  ModeStrings : array[CalcMode] of string[7] =
  ('Ä Dec Ä', 'Ä Hex Ä', 'Ä Bin Ä', ' Float ', 'Ä Exp Ä');
  CalcChars : array[CalcType] of string[3] =
  ('   ', '+  ', '-  ', '*  ', 'ö  ', 'and', 'mod', 'not', 'or ', 'xor',
    'shl', 'shr');
  DoneChars : array[Boolean] of string[1] = (' ', '=');
  LoadError : string[23] = 'Unable to install PCALC';

  {** key codes **}
  Esc = #27;
  F5 = 63;
  F6 = 64;
  F7 = 65;
  F8 = 66;
  F9 = 67;
  F10 = 68;
  DisableCode = 22;          {scan code for Alt-U, press twice in succession
                              to disable the popup}

  {** screen stuff **}
const
  LeftCol : Byte = 36;       {leftmost col on screen}
  RtCol : Byte = 80;         {rightmost col on screen}
  TopRow : Byte = 1;         {top row of window border}
  BotRow : Byte = 10;        {bottom row of window border}
  SaveRow : Byte = 6;        {row where saved number is displayed}
  LabelRow : Byte = 8;       {row where 1st line of command labels is displayed}
  NumRow : Byte = 3;         {row where numbers are entered}
  NumCol : Byte = 38;        {col where numbers are displayed}
  SymCol : Byte = 76;        {col where calculation symbols are displayed}

  CrossBar = 'Ä';            {if changed, ModeStrings must also be changed}
  LeftTee = 'Ã';
  RightTee = '´';
var
  OurScreenBuffer : ScreenBuffer; {for saving the screen}
  OurScreenPtr : Pointer;
  ScreenPtr : ^ScreenType;
  Span : String80;
  SpLen : Byte absolute Span; {its length}
  Reverse,                   {reverse video attribute}
  Command,                   {video attribute for commands}
  Bright,                    {bright video attribute}
  Dim : Byte;                {dim video attribute}
  FxAttrs : FlexAttrs;       {attributes for FlexWrite}

  {macro stuff}
const
  SmacsName : string[10] = 'SUPER MACS';
  {for SMACS function calls}
  GetMacroState = 3;
  SetMacroState = 4;
  MacroDefinedCheck = 5;
  DefineMacroFunc = 6;

  {calculator stuff}
type
  ExpStateType = (NoExp, DoingExp, HaveExp);
const
  DefaultMode = FloatPt;
  Digits : array[0..$F] of Char = '0123456789ABCDEF';
  HighDigit :                {highest digit allowed in given CalcMode}
  array[CalcMode] of Byte = (9, $F, 1, 9, 9);
  MaxDigits :                {number of digits allowed in given CalcMode}
  array[CalcMode] of Byte = (10, 8, 32, 35, 35);
  Base : array[Decimal..Binary] of LongInt = (10, 16, 2);
  ZeroString : string[1] = '0';
  MinusZero : string[2] = '-0';
  NullString : string[1] = '';
  NumStringWidth = 37;
  MaxLongIntDiv10 = 214748364;
var
  BcdMode,
  HaveDecimalPoint,
  MinusPending,
  DivideByZero,
  MathError : Boolean;
  CurrentCalcMode : CalcMode;
  CurrentCalcType : CalcType;
  DigitCount : Byte;
  NumString1,
  NumString2,
  SaveString : string[NumStringWidth];
  Result : string;
  Long1, Long2,
  LongResult,
  SaveLong : LongInt;
  Bcd1, Bcd2,
  BcdResult,
  SaveBcd : BCD;
  Status : CalcStatus;
  Exponent : Integer;
  ExponentSign,
  NegativeExponent : Boolean;
  ExponentState : ExpStateType;

  procedure Beep;
    {-Ring that obnoxious bell}
  begin
    Write(^G);
  end;

  procedure SetAttributes;
    {-Set video attribute variables based on the current video mode}
  begin
    case CurrentMode of
      2,                     {BW80}
      7 :                    {MONOCHROME}
        begin
          Bright := $F;      {white on black}
          Dim := $7;         {light gray on black}
          Command := $7;     {light gray on black}
          Reverse := $70;    {black on light gray}
        end;
    else                     {COLOR}
      begin
        Bright := $1F;       {white on blue}
        Dim := $1E;          {yellow on blue}
        Command := $13;      {light cyan on blue}
        Reverse := $71;      {blue on light gray}
      end;
    end;

    {set attributes for FlexWrite}
    FxAttrs[0] := Command;
    FxAttrs[1] := Bright;
  end;

  procedure DrawScreen;
    {-Draw initial screen}
  begin
    {draw main box, title, and command labels}
    FrameWindow(LeftCol, TopRow, RtCol, BotRow, Bright, Reverse,
      ' '+ProgName+' ');

    {draw crossbars}
    SpLen := Succ(RtCol-LeftCol);
    FillChar(Span[1], SpLen, CrossBar);
    Span[1] := LeftTee;
    Span[SpLen] := RightTee;
    FastWrite(Span, Pred(SaveRow), LeftCol, Bright);
    FastWrite(' Saved ', Pred(SaveRow), RtCol-11, Bright);
    FastWrite(Span, Pred(LabelRow), LeftCol, Bright);
    FastWrite(' Commands ', Pred(LabelRow), LeftCol+2, Bright);

    {draw command labels}
    FlexWrite(CommandLabel1, LabelRow, Succ(LeftCol), FxAttrs);
    FlexWrite(CommandLabel2, Succ(LabelRow), Succ(LeftCol), FxAttrs);
  end;

  procedure UpdateDisplay;
    {-Update the calculator display}
  begin
    FastWrite(LeftPad(NumString1, NumStringWidth), Pred(NumRow), NumCol, Dim);
    FastWrite(LeftPad(NumString2, NumStringWidth), NumRow, NumCol, Dim);
    FastWrite(CalcChars[CurrentCalcType], NumRow, SymCol, Bright);
    FastWrite(LeftPad(Result, NumStringWidth), Succ(NumRow), NumCol, Dim);
    FastWrite(DoneChars[Status = Done], Succ(NumRow), SymCol, Bright);
    FastWrite(LeftPad(SaveString, NumStringWidth), SaveRow, NumCol, Dim);
  end;

  procedure HighlightNumber(Which : Byte);
    {-Highlight the number specified by Which:
      1 = NumString1
      2 = NumString2
      3 = Result
      4 = SaveString}
  var
    Row : Byte;
  begin
    case Which of
      1 : Row := Pred(NumRow);
      2 : Row := NumRow;
      3 : Row := Succ(NumRow);
      4 : Row := SaveRow;
    end;
    ChangeAttribute(NumStringWidth, Row, NumCol, Bright);
  end;

  procedure ShowMode;
    {-Show the current calculation mode}
  begin
    FastWrite(ModeStrings[CurrentCalcMode], Pred(SaveRow), LeftCol+2, Bright);
  end;

  procedure ClearPromptLine;
    {-Clear the prompt line}
  begin
    SpLen := Pred(RtCol-LeftCol);
    FillChar(Span[1], SpLen, ' ');
    FastWrite(Span, SaveRow, Succ(LeftCol), Dim);
  end;

  procedure Prompt(Msg : String80);
    {-Display a prompt}
  begin
    ClearPromptLine;
    FastWrite(Msg, SaveRow, LeftCol+2, Dim);
  end;

  procedure PressAnyKey(Msg : String80);
    {-Display a message and wait for a keystroke}
  var
    I : Word;
  begin
    Prompt(Msg+'. Press any key...');
    I := ReadKeyWord;
  end;

  function YesNo(Msg : String80) : Boolean;
    {-Display a yes/no message and return true if Y is pressed}
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
  begin
    Prompt(Msg);
    repeat
      ChWord := ReadKeyWord;
      Ch := Upcase(Ch);
    until (Ch = 'Y') or (Ch = 'N');
    YesNo := (Ch = 'Y');
  end;

  procedure GetBcdVal(var S : string; var B : BCD);
    {-Convert string S to a BCD real}
  var
    Code : Word;
  begin
    ValBcd(S, B, Code);
    if Code <> 0 then begin
      S := ZeroString;
      B := ZeroBCD;
    end;
  end;

  procedure GetExpString(var B : BCD; var BcdSt : string);
    {-Convert a BCD to a string with an exponent, and delete 0's just before
      the 'E'}
  var
    I : Word;
  begin
    {convert to string}
    BcdSt := StrExpBcd(B, 0);

    {delete initial space, if any}
    if BcdSt[1] = ' ' then
      Delete(BcdSt, 1, 1);

    {delete 0's just before the 'E', if any}
    I := Pos('E', BcdSt);
    while BcdSt[Pred(I)] = '0' do begin
      Dec(I);
      Delete(BcdSt, I, 1);
    end;

    {delete '.' just before the 'E', if any}
    Dec(I);
    if BcdSt[I] = '.' then
      Delete(BcdSt, I, 1);
  end;

  procedure GetBcdString(var B : BCD; var BcdSt : string);
    {-Try to convert a BCD to a string without the exponent showing}
  var
    S : string;
    SLen : Byte absolute S;
  begin
    {convert B to a string}
    S := StrBcd(B, 0, 81);

    {delete any trailing 0's}
    while S[SLen] = '0' do
      Dec(SLen);

    {delete '.' at the end, if any}
    if S[SLen] = '.' then
      Dec(SLen);

    {if the string is still too large, convert to exponential format}
    if SLen > NumStringWidth then
      GetExpString(B, BcdSt)
    else
      BcdSt := S;
  end;

  function MakeBcdConstant : string;
    {-Return a typed constant representing the current BCD real of interest}
  var
    I : Word;
    B : BCD;
    S : string[42];
  begin
    if Status = Done then
      B := BcdResult
    else begin
      GetBcdVal(NumString2, Bcd2);
      B := Bcd2;
    end;
    S := '(';
    for I := 1 to 10 do
      S := S+'$'+HexB(B[I])+',';
    S[Length(S)] := ')';
    MakeBcdConstant := S;
  end;

  procedure MakeMacro;
    {-Turn a string into a macro}
  var
    MacroKey : Word;
    Ch : Char absolute MacroKey;
    Regs : IntRegisters;
    P : IfcPtr;
    DoTypedConstant,
    SaveMacroState : Boolean;
    S : string;
  label
    ExitPoint;
  begin
    {check for presence of SMACS}
    P := ModulePtrByName(SmacsName);
    if P = nil then begin
      PressAnyKey('Requires SMACS');
      goto ExitPoint;
    end;

    if Status = Done then
      HighlightNumber(3)
    else
      HighlightNumber(2);

    {save the current macro state and turn macros off -- we don't want a
     macro played back!}
    Regs.AH := GetMacroState;
    EmulateInt(Regs, P^.CmdEntryPtr);
    SaveMacroState := Boolean(Regs.AL);

    {now we can get the key}
    Prompt('Press the key for the SMACS macro');
    MacroKey := ReadKeyWord;
    if Ch = Esc then
      goto ExitPoint;

    {restore macro state}
    Regs.AH := SetMacroState;
    Regs.AL := Byte(SaveMacroState);
    EmulateInt(Regs, P^.CmdEntryPtr);

    {see if the key is already defined}
    Regs.AH := MacroDefinedCheck;
    Regs.BX := MacroKey;
    EmulateInt(Regs, P^.CmdEntryPtr);
    if Boolean(Regs.AL) then
      {see what to do about it}
      if not YesNo('Overwrite existing macro (Y/N)?') then
        goto ExitPoint;

    {if in BCD mode, see if user wants to create a typed constant array}
    if BcdMode then
      DoTypedConstant := YesNo('Create a BCD typed constant (Y/N)?')
    else
      DoTypedConstant := False;

    {define the macro}
    Regs.AH := DefineMacroFunc;
    {DS:DX points to a string to turn into a macro}
    if DoTypedConstant then
      S := MakeBcdConstant
    else begin
      if (Status = Done) then
        S := Result
      else
        S := NumString2;

      {add radix symbols for Turbo/MASM}
      case CurrentCalcMode of
        Hexadecimal : S := '$'+S; {presumably for Turbo}
        Binary : S := S+'b'; {presumably for MASM}
      end;
    end;
    Regs.DS := Seg(S);
    Regs.DX := Ofs(S);

    {ES:DI points to the name of the macro, BX has the Key}
    Regs.ES := Seg(NullString);
    Regs.DI := Ofs(NullString);
    Regs.BX := MacroKey;
    EmulateInt(Regs, P^.CmdEntryPtr);

    {check result in AL}
    if Regs.AL = 0 then
      Prompt('Macro defined')
    else
      Prompt('Unable to create macro');
    Delay(1000);
ExitPoint:
    ClearPromptLine;
  end;

  procedure ResetDigitCount;
    {-Reset the digit count, etc.}
  var
    Epos : Word;
    Estr : string[4];
  begin
    {get digit count}
    if (NumString2 = ZeroString) or (NumString2 = MinusZero) then
      DigitCount := 0
    else begin
      DigitCount := Length(NumString2);
      MinusPending := NumString2[1] = '-';
      if MinusPending then begin
        case CurrentCalcMode of
          Hexadecimal..Binary :
            begin
              {minus sign not allowed in Hex or Binary modes}
              Delete(NumString2, 1, 1);
              MinusPending := False;
            end;
        end;
        {doesn't count toward total number of digits in any case}
        Dec(DigitCount);
      end;
    end;

    {get exponent}
    if BcdMode then begin
      HaveDecimalPoint := Pos('.', NumString2) <> 0;
      Epos := Pos('E', NumString2);
      if (Epos = 0) then
        ExponentState := NoExp
      else begin
        {get exponent}
        Estr := Copy(NumString2, Succ(Epos), Length(NumString2));
        if not Str2Int(Estr, Exponent) then
          Exponent := 0;
        if Abs(Exponent) < 10 then
          ExponentState := DoingExp
        else
          ExponentState := HaveExp;
        NegativeExponent := (Pos('-', Estr) <> 0);
        ExponentSign := NegativeExponent or (Pos('+', Estr) <> 0);
      end;
    end;
  end;

  procedure TrimZeros(var S : string);
    {-Trim initial 0's from S}
  var
    SLen : Byte absolute S;
  begin
    while (S[1] = '0') and (SLen > 1) do begin
      Dec(SLen);
      Move(S[2], S[1], SLen);
    end;
  end;

  procedure UpdateOneString(Which : Byte);
    {-Update the string specified by Which:
      1 = NumString1
      2 = NumString2
      3 = Result
      4 = SaveString}
  var
    StPtr : ^String80;
    LongPtr : ^LongInt;
    BcdPtr : ^BCD;
  begin
    {set string, number pointers}
    case Which of
      1 : if (CurrentCalcType = NotOp) then begin
            NumString1 := NullString;
            Exit;
          end
          else begin
            StPtr := @NumString1;
            LongPtr := @Long1;
            BcdPtr := @Bcd1;
          end;
      2 : begin
            StPtr := @NumString2;
            LongPtr := @Long2;
            BcdPtr := @Bcd2;
          end;
      3 : begin
            StPtr := @Result;
            LongPtr := @LongResult;
            BcdPtr := @BcdResult;
          end;
      4 : begin
            StPtr := @SaveString;
            LongPtr := @SaveLong;
            BcdPtr := @SaveBcd;
          end;
    end;

    {convert string}
    if BcdMode and EqualBcd(BcdPtr^, ZeroBCD) then
      StPtr^ := ZeroString
    else
      case CurrentCalcMode of
        Decimal :
          StPtr^ := Long2Str(LongPtr^);
        Hexadecimal :
          StPtr^ := HexL(LongPtr^);
        Binary :
          StPtr^ := BinaryL(LongPtr^);
        FloatPt :
          GetBcdString(BcdPtr^, StPtr^);
        Exponential :
          GetExpString(BcdPtr^, StPtr^);
      end;

    {trim any initial 0's}
    if not BcdMode then
      TrimZeros(StPtr^);
  end;

  procedure UpdateStrings;
    {-Update all the strings that currently have values associated with them}
  begin
    case Status of
      Done :
        begin
          UpdateOneString(1);
          UpdateOneString(3);
        end;
      Num2 :
        UpdateOneString(1);
    end;
    if Status <> Cleared then
      UpdateOneString(2);
    UpdateOneString(4);
  end;

  function CheckMathError : Boolean;
    {-Returns true if a math error occurred}
  begin
    CheckMathError := MathError;
    if MathError then begin
      if DivideByZero then
        PressAnyKey('Result is undefined')
      else
        PressAnyKey('Overflow error');
      UpdateDisplay;
      MathError := False;
      DivideByZero := False;
    end;
  end;

  procedure SwitchMode(Mode : CalcMode);
    {-Switch calculation modes}
  begin
    {do nothing if we're already in correct mode}
    if Mode = CurrentCalcMode then
      Exit;

    {translate data types if necessary}
    if (Mode >= FloatPt) then begin
      {reject certain calculation types for real numbers}
      case CurrentCalcType of
        AndOp..ShrOp : if Status <> Done then
                         Exit;
      end;
      if not BcdMode then begin
        LongIntToBcd(Long1, Bcd1);
        LongIntToBcd(Long2, Bcd2);
        LongIntToBcd(LongResult, BcdResult);
      end
      else
        GetBcdVal(NumString2, Bcd2);
    end
    else
      if BcdMode then begin
        Long1 := RoundBcd(Bcd1);
        GetBcdVal(NumString2, Bcd2);
        Long2 := RoundBcd(Bcd2);
        LongResult := RoundBcd(BcdResult);
      end;

    {exit in case of error}
    if CheckMathError then
      Exit;

    {change the mode setting}
    CurrentCalcMode := Mode;
    BcdMode := (Mode >= FloatPt);
    ShowMode;

    {update strings, digit count, etc.}
    UpdateStrings;
    ResetDigitCount;
  end;

  procedure ClearCurrentEntry;
    {-Clear the current entry and reset related variables}
  begin
    DigitCount := 0;
    Long2 := 0;
    Bcd2 := ZeroBCD;
    NumString2 := ZeroString;
    MinusPending := False;
    HaveDecimalPoint := False;
    ExponentState := NoExp;
  end;

  procedure ClearAll;
    {-Reset everything}
  begin
    {clear the current entry}
    ClearCurrentEntry;
    Status := Num1;

    {indicate that we're all clear}
    CurrentCalcType := None;
    Status := Cleared;

    {clear numeric variables}
    Long1 := 0;
    LongResult := 0;
    Bcd1 := ZeroBCD;
    BcdResult := ZeroBCD;

    {clear strings}
    NumString1 := NullString;
    Result := NullString;
  end;

  procedure ClearEntry;
    {-Reset the current entry}
  begin
    {if Done with a calculation, clear everything...}
    if (Status = Done) then
      ClearAll
    else
      {otherwise just the current entry}
      ClearCurrentEntry;
  end;

  procedure PerformCalc;
    {-Perform a calculation of type CurrentCalcMode}
  begin
    if BcdMode then begin
      GetBcdVal(NumString2, Bcd2);
      case CurrentCalcType of
        Add :
          AddBcd(Bcd1, Bcd2, BcdResult);
        Subtract :
          SubBcd(Bcd1, Bcd2, BcdResult);
        Multiply :
          MultBcd(Bcd1, Bcd2, BcdResult);
        Divide :
          if EqualBcd(Bcd2, ZeroBCD) then begin
            MathError := True;
            DivideByZero := True;
            Exit;
          end
          else
            DivBcd(Bcd1, Bcd2, BcdResult);
      end;
    end
    else
      case CurrentCalcType of
        Add :
          LongResult := Long1+Long2;
        Subtract :
          LongResult := Long1-Long2;
        Multiply :
          LongResult := Long1*Long2;
        ModOp,                                  {!!.10}
        Divide :
          if (Long2 = 0) then begin
            MathError := True;
            DivideByZero := True;
            Exit;
          end
          else if CurrentCalcType = ModOp then  {!!.10}
            LongResult := Long1 mod Long2       {!!.10}
          else
            LongResult := Long1 div Long2;
        AndOp :
          LongResult := Long1 and Long2;
        (*                                      {!!.10}
        ModOp :
          LongResult := Long1 mod Long2;
        *)
        OrOp :
          LongResult := Long1 or Long2;
        XorOp :
          LongResult := Long1 xor Long2;
        ShlOp :
          if (Long2 > 31) or (Long2 < 0) then
            LongResult := 0
          else
            LongResult := Long1 shl Long2;
        ShrOp :
          if (Long2 > 31) or (Long2 < 0) then
            LongResult := 0
          else
            LongResult := Long1 shr Long2;
      end;

    {convert the result to a string}
    UpdateOneString(3);
  end;

  procedure DoCalc(CT : CalcType);
    {-Prepare for a calculation of the specified type}
  begin
    if (DigitCount = 0) and (Status <> Done) then
      Exit;

    {reject certain calculation types for real numbers}
    if BcdMode then
      case CT of
        AndOp..ShrOp : Exit;
      end;

    {NOT is a special case}
    if (CT = NotOp) then begin
      if (Status <> Num2) then begin
        CurrentCalcType := NotOp;
        if Status <> Num1 then
          Long2 := LongResult;
        LongResult := not Long2;
        Status := Done;
        UpdateOneString(1);
        UpdateOneString(2);
        UpdateOneString(3);
      end;
      Exit;
    end;

    {move strings and values as necessary}
    case Status of
      Done :
        begin
          {move Result to Num1}
          Long1 := LongResult;
          Bcd1 := BcdResult;
          NumString1 := Result;
          LongResult := 0;
          BcdResult := ZeroBCD;
          Result := NullString;
        end;
      Num1 :
        begin
          {move 1st number up}
          Long1 := Long2;
          if BcdMode then
            GetBcdVal(NumString2, Bcd2);
          Bcd1 := Bcd2;
          NumString1 := NumString2;
        end;
      Num2 :
        begin
          {do the calculation, then move result to first number}
          PerformCalc;

          {handle errors}
          if CheckMathError then begin
            ClearAll;
            Exit;
          end;

          Long1 := LongResult;
          Bcd1 := BcdResult;
          NumString1 := Result;
          LongResult := 0;
          BcdResult := ZeroBCD;
          Result := NullString;
        end;
    end;

    {reset}
    ClearCurrentEntry;

    {store calculation type}
    CurrentCalcType := CT;
    Status := Num2;
  end;

  procedure FinishCalc;
    {-Finish the current calculation}
  begin
    {exit if the status is wrong}
    if Status <> Num2 then
      Exit;

    {perform the actual calculation}
    PerformCalc;

    {handle errors}
    if CheckMathError then begin
      ClearAll;
      Exit;
    end;

    ExponentState := NoExp;

    {change the status}
    Status := Done;
  end;

  procedure SaveValue;
    {-Save the current entry. Or, if we've just finished a calculation, save
      the result.}
  begin
    case Status of
      Cleared : {do nothing} ;
      Done :                 {save result}
        begin
          if BcdMode then
            SaveBcd := BcdResult
          else
            SaveLong := LongResult;
          SaveString := Result;
        end;
    else                     {save 2nd num}
      begin
        if BcdMode then begin
          GetBcdVal(NumString2, Bcd2);
          SaveBcd := Bcd2;
        end
        else
          SaveLong := Long2;
        SaveString := NumString2;
      end;
    end;
  end;

  procedure InsertSavedValue;
    {-Insert a saved value into the current entry}
  begin
    case Status of
      {if Cleared or Done, clear all and change status}
      Cleared..Done :
        begin
          ClearAll;
          Status := Num1;
        end;
    else
      {just clear the current entry}
      ClearCurrentEntry;
    end;

    {insert the saved value}
    Long2 := SaveLong;
    Bcd2 := SaveBcd;

    {update the current entry string, digit count, etc.}
    UpdateOneString(2);
    ResetDigitCount;
  end;

  function AppendChar(Ch : Char) : Boolean;
    {-Append a character to NumString2}
  begin
    {check for overflow of digits}
    if DigitCount >= MaxDigits[CurrentCalcMode] then begin
      AppendChar := False;
      Exit;
    end
    else
      AppendChar := True;

    if (DigitCount = 0) and (Ch <> '.') then begin
      NumString2[Length(NumString2)] := Ch;
      DigitCount := 1;
    end
    else begin
      Inc(NumString2[0]);
      NumString2[Length(NumString2)] := Ch;
      Inc(DigitCount);
    end;
  end;

  procedure AddDigit(Digit : Integer);
    {-Add a digit to the current entry}
  var
    AbsLong2 : LongInt;
    AbsExp,
    DigitToAdd : Integer;
  begin
    {check for illegal digit}
    if (DigitCount >= MaxDigits[CurrentCalcMode]) or (Digit > HighDigit[CurrentCalcMode]) then
      Exit;

    {reject extra digits in an exponent}
    if ExponentState = HaveExp then
      Exit;

    {reset if ...}
    if Status = Done then
      ClearAll;

    if Status = Cleared then
      Status := Num1;

    {don't insert extra zeros}
    if ((DigitCount = 0) or (NumString2 = MinusZero)) and (Digit = 0) then
      Exit;

    case CurrentCalcMode of
      Decimal..Binary :      {longint operation}
        begin
          {check for potential overflow if we're in Decimal mode}
          if CurrentCalcMode = Decimal then begin
            AbsLong2 := Abs(Long2);
            if (AbsLong2 > MaxLongIntDiv10) or ((AbsLong2 = MaxLongIntDiv10) and (Digit > 7)) then
              Exit;
          end;

          {get digit to add}
          if MinusPending then
            DigitToAdd := -Digit
          else
            DigitToAdd := Digit;

          {add it}
          Long2 := (Long2*Base[CurrentCalcMode])+LongInt(DigitToAdd);
        end;
    else                     {floating point operation}
      if (ExponentState = DoingExp) then begin
        AbsExp := Abs(Exponent);
        if (AbsExp > 6) or ((AbsExp = 6) and (Digit > 3)) then
          Exit;
        if NegativeExponent then
          DigitToAdd := -Digit
        else
          DigitToAdd := Digit;
        if (Exponent = 0) then
          Exponent := DigitToAdd
        else begin
          Exponent := (Exponent*10)+DigitToAdd;
          ExponentState := HaveExp;
        end;
      end;
    end;

    {append the digit}
    if AppendChar(Digits[Digit]) then
      {won't fail -- error checking already done} ;
  end;

  procedure StartExponent;
    {-Handle entry of 'E'}
  begin
    if (ExponentState <> NoExp) or (DigitCount = 0) then
      Exit;
    if not AppendChar('E') then
      Exit;
    ExponentState := DoingExp;
    NegativeExponent := False;
    ExponentSign := False;
    Exponent := 0;
  end;

  procedure DoMinus;
    {-Handle entry of '-'}
  begin
    if (ExponentState = DoingExp) then begin
      if (Exponent = 0) and not ExponentSign then
        if AppendChar('-') then begin
          ExponentSign := True;
          NegativeExponent := True;
        end;
    end
    else
      if (CurrentCalcType <> ShlOp) and (CurrentCalcType <> ShrOp) and
      (DigitCount = 0) and (HighDigit[CurrentCalcMode] = 9) then begin
        if not MinusPending then
          NumString2 := '-'+NumString2;
        MinusPending := True;
      end
      else
        DoCalc(Subtract);
  end;

  procedure DoPlus;
    {-Handle entry of '+'}
  begin
    if (ExponentState = DoingExp) then begin
      if (Exponent = 0) and not ExponentSign then
        if AppendChar('+') then
          ExponentSign := True;
    end
    else
      DoCalc(Add);
  end;

  procedure DoDecimalPoint;
    {-Handle entry of '.'}
  begin
    if (not BcdMode) or HaveDecimalPoint or (ExponentState <> NoExp) then
      Exit;
    if AppendChar('.') then
      HaveDecimalPoint := True;
  end;

  procedure DoBackSpace;
    {-Handle entry of ^H (BkSp)}
  var
    Ch : Char;
  begin
    if (NumString2 = ZeroString) or (Status = Done) then
      Exit;
    if (Length(NumString2) = 1) then begin
      NumString2 := ZeroString;
      Long2 := 0;
    end
    else
      if (Length(NumString2) = 2) and (NumString2[1] = '-') then begin
        if NumString2 = MinusZero then begin
          NumString2 := ZeroString;
          MinusPending := False;
        end
        else
          NumString2 := MinusZero;
        Long2 := 0;
      end
      else begin
        Ch := NumString2[Length(NumString2)];
        Dec(NumString2[0]);
        if not BcdMode then
          case Ch of
            '0'..'9' : Long2 := Long2 div Base[CurrentCalcMode];
          end;
      end;
    ResetDigitCount;
  end;

  procedure Calculator;
    {-Main program loop}
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
  begin
    {initialize screen stuff}
    HiddenCursor;
    TextAttr := Bright;

    {draw initial screen}
    Window(LeftCol, TopRow, RtCol, BotRow);
    ClrScr;
    DrawScreen;
    ShowMode;

    {loop until Escape key pressed}
    repeat
      {update the screen}
      UpdateDisplay;

      {get the next key}
      ChWord := ReadKeyWord;
      Ch := Upcase(Ch);
      if (Ch = #0) then
        case Hi(ChWord) of
          {map function keys to hex digits like SideKick}
          F5 :               {F5 -> $A}
            AddDigit($A);
          F6 :               {F6 -> $B}
            AddDigit($B);
          F7 :               {F7 -> $C}
            AddDigit($C);
          F8 :               {F8 -> $D}
            AddDigit($D);
          F9 :               {F9 -> $E}
            AddDigit($E);
          F10 :              {F10 -> $F}
            AddDigit($F);

          DisableCode :      {AltU}
            {must be pressed twice in succession}
            if Hi(ReadKeyWord) = DisableCode then begin
              Ch := Esc;
              DisableOurselves := True;
            end;
        end
      else
        case Ch of
          {arithmetic operators}
          '*' : DoCalc(Multiply);
          '/' : DoCalc(Divide);

          {'+' and '-' are special cases}
          '+' : DoPlus;
          '-' : DoMinus;

          {normal digits}
          '0'..'9' :
            AddDigit(Ord(Ch) and $0F);

          {calculation modes}
          'B' :              {Binary}
            SwitchMode(Binary);
          'D' :              {Decimal}
            SwitchMode(Decimal);
          'F' :              {Floating point}
            SwitchMode(FloatPt);
          'H' :              {Hexadecimal}
            SwitchMode(Hexadecimal);
          'P' :              {exPonent (floating point)}
            SwitchMode(Exponential);

          {arithmetic/logical operations}
          'A' :              {And}
            DoCalc(AndOp);
          'L' :              {shL}
            DoCalc(ShlOp);
          'M' :              {Mod}
            DoCalc(ModOp);
          'N' :              {Not}
            DoCalc(NotOp);
          'O' :              {Or}
            DoCalc(OrOp);
          'R' :              {shR}
            DoCalc(ShrOp);
          'X' :              {Xor}
            DoCalc(XorOp);

          {commands}
          'C' :              {Clear all}
            ClearAll;
          'E' :              {clear Entry (or exponential 'E')}
            if BcdMode and (ExponentState = NoExp) and (Status <> Done) then
              StartExponent
            else
              ClearEntry;
          'I' :              {Insert saved value}
            InsertSavedValue;
          'K' :              {assign value to Key}
            MakeMacro;
          'S' :              {Save current value}
            SaveValue;

          {treat ^A-^F as hexadecimal digits}
          ^A : AddDigit($A);
          ^B : AddDigit($B);
          ^C : AddDigit($C);
          ^D : AddDigit($D);
          ^E : AddDigit($E);
          ^F : AddDigit($F);

          {other}
          '.' :              {decimal point}
            DoDecimalPoint;
          ^H :               {backspace}
            DoBackSpace;
          ^M, '=' :          {equals}
            FinishCalc;
        end;
    until (Ch = Esc);        {Escape}

    {check to see if we're disabling the TSR}
    if DisableOurselves then
      if not DisableTSR then begin
        {no go, exit but stay resident and active}
        DisableOurselves := False;
        Write(^G);
      end;
  end;

  procedure Div0Int(BP : Word); interrupt;
    {-Traps INT 0 for divide by zero and BCD math errors}
  begin
    MathError := True;
  end;

  {$F+}
  procedure PopupEntryPoint(var Regs : Registers);
    {-This is the entry point for the popup}
    {$IFNDEF KB5151}
  const
    NumLockBit = $20;
    {$ENDIF}
  var
    {$IFNDEF KB5151}
    KeyboardFlags : Byte absolute $40 : $17;
    SaveNumLock : Boolean;
    {$ENDIF}
    SaveXY, SaveSL : Word;   {for saving cursor position and shape}
  begin
    {reinitialize CRT}
    ReinitCrt;

    {don't pop up if not in 80-column text mode}
    if InTextMode and (ScreenWidth = 80) then begin
      {initialize screen stuff}
      SetAttributes;
      GetCursorState(SaveXY, SaveSL);
      ScreenPtr := Ptr(VideoSegment, 0);
      if SaveWindow(LeftCol, TopRow, RtCol, BotRow, False, OurScreenPtr) then
        {won't fail -- no memory being allocated} ;

      {$IFNDEF KB5151}
      {save NumLock state and force it on}
      SaveNumLock := (KeyboardFlags and NumLockBit) <> 0;
      KeyboardFlags := KeyboardFlags or NumLockBit;
      {$ENDIF}

      {trap INT 0 and call the calculator routine}
      if InitVector(0, Div0Handle, @Div0Int) then
        Calculator;

      {restore previous INT 0 handler}
      RestoreVector(Div0Handle);

      {$IFNDEF KB5151}
      {restore previous NumLock state}
      if SaveNumLock then
        KeyboardFlags := KeyboardFlags or NumLockBit
      else
        KeyboardFlags := KeyboardFlags and (not NumLockBit);
      {$ENDIF}

      {restore cursor and screen}
      RestoreCursorState(SaveXY, SaveSL);
      RestoreWindow(LeftCol, TopRow, RtCol, BotRow, False, OurScreenPtr);
    end
    else
      Beep;
  end;
  {$F-}

  procedure Abort(Message : string);
    {-Display message and Halt}
  begin
    WriteLn(Message);
    Halt(1);
  end;

  procedure InitPCalc;
    {-Basic initialization stuff}
  begin
    OurScreenPtr := @OurScreenBuffer;
    CurrentCalcMode := DefaultMode;
    BcdMode := (CurrentCalcMode >= FloatPt);
    MathError := False;
    DivideByZero := False;
    SaveLong := 0;
    SaveBcd := ZeroBCD;
    SaveString := ZeroString;
    ClearAll;
  end;

begin
  {signon message}
  HighVideo;
  WriteLn(ProgName, ^M^J, Copyright, ^M^J);
  LowVideo;

  {initialize}
  InitPCalc;

  {check to see if SideKick is loaded}
  if SideKickLoaded then
    Abort('Can''t be loaded after SideKick!');

  {check to see if we're already installed}
  if ModuleInstalled(ModuleName) then
    Abort('PCALC is already loaded. Aborting...');

  {install the module}
  InstallModule(ModuleName, nil);

  {go resident}
  if DefinePop(OurHotKey, @PopupEntryPoint, Ptr(SSeg, SPtr), True) then begin
    WriteLn('PCALC loaded, press Ctrl-RightShift-C to activate.');

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