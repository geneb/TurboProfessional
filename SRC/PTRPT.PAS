{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 10000,5000,65500}

{$I TPDEFINE.INC}

{*********************************************************}
{*                    PTRPT.PAS 5.22                     *}
{*         Report Generator for PTIME Data Files         *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program PTime_Report;
  {-Report generator for PTIME data files}

uses
  Dos,                       {standard DOS/BIOS routines}
  Printer,                   {standard printer unit}
  TpInt24,                   {Turbo Professional critical error handler}
  TpString,                  {Turbo Professional string handling routines}
  TpDos,                     {Turbo Professional disk/file management, etc.}
  TpCrt,                     {Turbo Professional CRT unit}
  {$IFDEF UseMouse}
  TpMouse,                   {Turbo Professional mouse routines}
  {$ENDIF}
  TpDate,                    {Turbo Professional date/time routines}
  TpEntry,                   {Turbo Professional data entry routines}
  TpPick,                    {Turbo Professional pick list manager}
  TpDir,                     {Turbo Professional directory picker}
  TPMenu;                    {Turbo Professional menu system}

  {general declarations}
type
  String8 = string[8];
  String64 = string[64];
  String80 = string[80];

  {menu system}
const
  Color1 : MenuColorArray = ($09, $1F, $09, $1F, $0B, $09, $07, $07);
  Mono1 : MenuColorArray = ($0F, $70, $07, $70, $0F, $07, $07, $07);
  Frame1 : FrameArray = 'ÕÔ¸¾Í³';
var
  RootMenu : Menu;           {our menu}
  Key : MenuKey;             {key returned by menu system}
  MenuCh : Char;             {char pressed to exit menu system}
  AllDone : Boolean;         {true to exit main menu loop}
  ColorsPtr : ^MenuColorArray; {points to Mono1 or Color1}

  {database}
type
  BillingRec =               {this *must* agree with declaration in PTIME}
    record
      Starting : DateTimeRec;
      Stopping : DateTimeRec;
      Elapsed : Time;
      AllowUpdate : Boolean;
      Comment : string[76];
    end;
  SignatureType = string[7];
const
  Signature : SignatureType = 'PTime50';
  SecsPerHour = 3600;        {60 minutes * 60 seconds}
  DateFormat : string[08] = 'MM/dd/yy';
  AmPmFormat : string[11] = 'HH:mm:ss te';
  TimeFormat : string[08] = 'HH:mm:ss';
var
  BillingName : String64;    {name of current data file}
  BillingFile : file of BillingRec; {current data file}
  BlankBill : BillingRec;    {blank billing record}
  ESR : ESrecord;            {edit screen record}
  Rate : Float;              {hourly billing rate}
  TotalRecs,                 {total # of records in data file}
  CurrentRec : Word;         {record pointer for browsing}
  DataFileIsOpen : Boolean;  {true if a data file is open}

  {screen}
var
  InitSL : Word;             {initial scan lines for cursor}
  Dim,                       {video attributes}
  Bright,
  Reverse : Byte;
  PickColors : PickColorArray;

  {messages}
const
  ZeroEntries : string[24] = 'Data file has no entries';
  ChoosePrompt : string[64] =
  'Use <PgUp> and <PgDn> to move, <^Enter> to select, <Esc> to quit';
  BrowsePrompt : string[44] =
  'Use <PgUp> and <PgDn> to move, <Esc> to quit';
  ReportError : string[28] = 'Error writing to report file';
  PrintError : string[24] = 'Error writing to printer';

  {miscellaneous}
const
  Esc = #27;
  Enter = ^M;
  NullString : string[1] = '';
var
  Blank : String80;
  BlankLen : Byte absolute Blank;

  {$IFDEF UseMouse}
const
  {used to translate mouse buttons to keys}
  ButtonCodes : array[$E9..$EF] of Word = (
    $011B,                   {all three buttons         = ESC}
    $011B,                   {right and center buttons  = ESC}
    $011B,                   {left and center buttons   = ESC}
    $011B,                   {center button             = ESC}
    $011B,                   {both buttons              = ESC}
    $011B,                   {right button              = ESC}
    $1C0D);                  {left button               = Enter}
  {$ENDIF}

  {$IFDEF UseMouse}
  function ReadKeyWord : Word;
    {-Get a key from the keyboard or mouse}
  var
    I : Word;
  begin
    I := ReadKeyOrButton;
    case Hi(I) of
      $E9..$EF :
        ReadKeyWord := ButtonCodes[Hi(I)];
    else
      ReadKeyWord := I
    end;
  end;
  {$ENDIF}

  function Decimal(I, Width : Word; DoZero : Boolean) : String8;
    {-Return a string representing a decimal number}
  var
    S : String8;
    SLen : Byte absolute S;
  begin
    Str(I:Width, S);
    if DoZero then
      for I := 1 to SLen do
        if S[I] = ' ' then
          S[I] := '0';
    Decimal := S;
  end;

  function MoneyString(R : Float) : string;
    {-Return a string in $999,999,999.99 format}
  var
    S : string;
  begin
    S := Real2Str(R, 0, 2);
    MergePicture('$999,999,999.99', S, S, 0);
    MoneyString := Trim(S);
  end;

  function HoursMinsSecs(Days : Word; T : Time) : string;
    {-Return a string showing the number of hours, minutes, and seconds}
  var
    Hours, Minutes, Seconds : Byte;
  begin
    TimeToHMS(T, Hours, Minutes, Seconds);
    HoursMinsSecs := Decimal((Days*24)+Hours, 0, False)+' hrs, '+
    Decimal(Minutes, 0, False)+' mins, '+Decimal(Seconds, 0, False)+' secs';
  end;

  procedure ClearPromptLine;
    {-Clear prompt line at bottom of screen}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    BlankLen := 80;
    FastWrite(Blank, 25, 1, Dim);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure ClearDisplayWindow;
    {-Clear the window where records are displayed}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    Window(1, 4, 80, 24);
    ClrScr;

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure Prompt(Msg : String80);
    {-Display a prompt}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    FastWrite(Pad(Msg, 80), 25, 1, Bright);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure ErrorMessage(Msg : string; Beep : Boolean);
    {-Display an error message at the prompt line}
  var
    ChWord : Word;
  begin
    if Msg[Length(Msg)] <> '.' then begin
      Inc(Msg[0]);
      Msg[Length(Msg)] := '.';
    end;
    Prompt(Msg+' Press any key...');
    if Beep then
      RingBell;
    ChWord := ReadKeyWord;
    ClearPromptLine;
  end;

  {$F+}
  procedure ErrorHandler(var ESR : ESrecord; Code : Byte; Msg : string);
    {-Display error messages}
  var
    CursorSL, CursorXY : Word;
  begin
    {Store cursor position and shape, then hide it}
    GetCursorState(CursorXY, CursorSL);
    HiddenCursor;

    {display error message}
    ErrorMessage(Msg, True);

    case Code of
      InitError, OverflowError, MemoryError, ParamError :
        begin
          {a fatal error: unhide cursor and clear the screen}
          {$IFDEF UseMouse}
          HideMouse;
          {$ENDIF}
          NormalCursor;
          Window(1, 1, 80, 25);
          ClrScr;
        end;
    else
      {Restore cursor position and shape}
      RestoreCursorState(CursorXY, CursorSL);
    end;
  end;

  procedure DisplayHelpPrompt(var ESR : ESrecord);
    {-Display a help prompt for the current field}
  var
    S : string[80];
  begin
    {no prompts in read-only mode}
    if ESR.ReadOnlyFlag then
      Exit;

    case ESR.CurrentID of
      {--Field 0 is the name of the data file (protected)--}
      {--Field 1 is the record number (protected)--}
      02 : S := 'Enter the date when timing started';
      03 : S := 'Enter the time of day when timing started';
      04 : S := 'Enter the date when timing stopped';
      05 : S := 'Enter the time of day when timing stopped';
      06 : S := 'Enter the cumulative elapsed time, adjusted for pauses';
      07 : S := 'Allow PTIME to update this record?';
      08 : S := 'Enter comment indicating what work was done during this period';
    else S := '';
    end;
    Prompt(S);
  end;
  {$F-}

  function YesOrNo(Msg : string; Default : Boolean) : Boolean;
    {-Prompt for answer to yes/no question}
  const
    YorN : array[Boolean] of Char = ('N', 'Y');
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
  begin
    ClearPromptLine;
    Msg := Msg+' ['+YorN[Default]+']';
    Prompt(Msg);
    repeat
      ChWord := ReadKeyWord;
      Ch := Upcase(Ch);
      if Ch = ^M then
        Ch := YorN[Default];
    until (Ch = 'Y') or (Ch = 'N');
    YesOrNo := Ch = 'Y';
    ClearPromptLine;
  end;

  function GetFileNameShell(var FName : String64) : Boolean;
    {-Shell for TpDir.GetFileName}
  var
    I : Word;
  begin
    {use TPDIR to put up a directory list}
    ShowSizeDateTime := True;
    PickSrch := CharPickSrch;
    I := GetFileName(FName, AnyFile, 20, 5, 23, 1, PickColors, FName);
    GetFileNameShell := (I = 0) and (Length(FName) <> 0);
  end;

  function GetFName(Prompt : string; var FName : String64;
                    CheckForFile : Boolean) : Boolean;
    {-Get a filename from the user}
  const
    S : String64 = '';
  var
    Escaped : Boolean;
  begin
    ClearPromptLine;

    if Length(FName) <> 0 then
      S := FName
    else if CheckForFile and (Length(S) = 0) then
      S := '*.*';

    {edit FName}
    ESfieldAttr := ESstringAttr;
    ESctrlAttr := ESstringAttr;
    EditString(Prompt, 25, 1, 64, '', 0, Escaped, S);
    FName := S;

    if Escaped then
      GetFName := False
    else if CheckForFile then
      GetFName := GetFileNameShell(FName)
    else
      GetFName := Length(FName) <> 0;

    {clean up}
    ClearPromptLine;
  end;

  function ValidateBill : Boolean;
    {-Validate the contents of BlankBill}
  var
    Days : Word;
    Secs : LongInt;
  begin
    ValidateBill := False;

    with BlankBill do begin
      {compare starting and stopping times}
      if (Stopping.D < Starting.D) or
      ((Stopping.D = Starting.D) and (Stopping.T < Starting.T)) then begin
        ErrorMessage('Start time must be later than stop time', True);
        Exit;
      end;

      {check for excessive elapsed time}
      DateTimeDiff(Starting, Stopping, Days, Secs);
      if (Days > 0) then begin
        ErrorMessage('Stop time must be within 24 hours of start time', True);
        Exit;
      end;
      if Elapsed > Secs then begin
        ErrorMessage('Elapsed time exceeds actual difference in time', True);
        Exit;
      end;
    end;

    ValidateBill := True;
  end;

  function ReadRecord(RecNum : Word; var BR : BillingRec) : Boolean;
    {-Read the RecNum'th record into BR. Returns false for I/O error}
  begin
    {assume failure}
    ReadRecord := False;

    {seek to the RecNum'th record}
    Seek(BillingFile, RecNum);
    if (Int24Result <> 0) then
      ErrorMessage('Seek error reading record #'+Decimal(RecNum, 0, False), True)
    else begin
      Read(BillingFile, BR);
      if Int24Result <> 0 then
        ErrorMessage('Unable to read record #'+Decimal(RecNum, 0, False), True)
      else
        ReadRecord := True;
    end;
  end;

  function WriteRecord(RecNum : Word; var BR : BillingRec) : Boolean;
    {-Write BR as the RecNum'th record. Returns false for I/O error}
  begin
    {assume failure}
    WriteRecord := False;

    {seek to the RecNum'th record}
    Seek(BillingFile, RecNum);
    if (Int24Result <> 0) then
      ErrorMessage('Error seeking to record #'+Decimal(RecNum, 0, False), True)
    else begin
      Write(BillingFile, BR);
      if Int24Result <> 0 then
        ErrorMessage('Unable to write record #'+Decimal(RecNum, 0, False), True)
      else begin
        WriteRecord := True;
        if RecNum > TotalRecs then
          TotalRecs := RecNum;
      end;
    end;
  end;

  function DeleteRecord(RecNum : Word) : Boolean;
    {-Delete the RecNum'th record. Returns false for I/O error}
  var
    BR : BillingRec;
    I : Word;
  begin
    {assume failure}
    DeleteRecord := False;

    {shuffle the records after RecNum back}
    for I := Succ(RecNum) to TotalRecs do begin
      if not ReadRecord(I, BR) then
        Exit;
      if not WriteRecord(Pred(I), BR) then
        Exit;
    end;

    {position file pointer and truncate file}
    Seek(BillingFile, TotalRecs);
    if Int24Result <> 0 then
      Exit;
    Truncate(BillingFile);
    if Int24Result <> 0 then
      Exit;

    {decrement count of total records}
    Dec(TotalRecs);
    DeleteRecord := True;
  end;

  function OpenBilling : Boolean;
    {-Open the billing file, returning a success flag}
  var
    BR : BillingRec;
    BSig : string[5] absolute BR;
    I : Word;
  begin
    {assume failure}
    OpenBilling := False;
    DataFileIsOpen := False;

    {expand the name}
    BillingName := FullPathName(BillingName);

    {try to open the file}
    Assign(BillingFile, BillingName);
    Reset(BillingFile);
    if Int24Result <> 0 then begin
      ErrorMessage('Unable to open data file', True);
      Exit;
    end;

    {read the first entry}
    Read(BillingFile, BR);

    {check for read error}
    if Int24Result <> 0 then begin
      ErrorMessage('Error reading from data file', True);
      Close(BillingFile);
      I := Int24Result;
    end
    else if (BSig <> Signature) then begin
      {signature invalid}
      ErrorMessage('Not a valid data file', True);
      Close(BillingFile);
      I := Int24Result;
    end
    else begin
      {success}
      DataFileIsOpen := True;
      TotalRecs := Pred(FileSize(BillingFile));
      CurrentRec := 1;
      OpenBilling := True;
    end;
  end;

  function GetRate : Boolean;
    {-Get the user's billing rate. Returns true if Rate was specified.}
  var
    Escaped : Boolean;
    S : string[7];
  begin
    ClearPromptLine;

    {edit the rate}
    ESfieldAttr := ESstringAttr;
    ESctrlAttr := ESstringAttr;
    S := Real2Str(Rate, 0, 2);
    EditString('Enter rate per hour: ', 25, 1, 7, '$999.99', 0, Escaped, S);
    GetRate := not Escaped;
    if not Escaped then begin
      {get rid of blanks and floating dollar sign}
      S := Trim(S);
      Delete(S, 1, 1);

      if not Str2Real(S, Rate) then begin
        Rate := 0;
        GetRate := False;
      end;
    end;

    {clean up}
    ClearPromptLine;
  end;

  function ChooseRecord(var Escaped : Boolean; Browsing : Boolean) : Boolean;
    {-Choose a record. Returns false for I/O error}
  var
    LastRec : Word;
    Done : Boolean;
  begin
    ChooseRecord := False;
    Escaped := False;

    if CurrentRec > TotalRecs then
      CurrentRec := TotalRecs;

    {display help prompt}
    if Browsing then
      Prompt(Center(BrowsePrompt, 80))
    else
      Prompt(Center(ChoosePrompt, 80));

    Done := False;
    LastRec := 0;
    repeat
      {read the next record}
      if CurrentRec <> LastRec then
        if not ReadRecord(CurrentRec, BlankBill) then
          Exit;
      LastRec := CurrentRec;

      {display the record}
      case EditScreen(ESR, ESR.CurrentID, True) of
        ESquit :             {Esc}
          begin
            Escaped := True;
            Done := True;
          end;
        ESdone :             {^Enter, ^KD, ^KQ}
          Done := not Browsing;
        ESprevRec :          {PgUp}
          if CurrentRec > 1 then
            Dec(CurrentRec);
        ESnextRec :          {PgDn}
          if CurrentRec < TotalRecs then
            Inc(CurrentRec);
      end;

    until Done;

    ClearPromptLine;
    ChooseRecord := True;
  end;

  function DataFileOpen : Boolean;
    {-Return true if a file is already open, else prompt for file name
      and try to open the file}
  begin
    if DataFileIsOpen then
      {file already open}
      DataFileOpen := True
    else begin
      {no file open, get filename}
      ClearPromptLine;

      {if a name is specified, try to open the file}
      if GetFName('Data file: ', BillingName, True) then
        DataFileOpen := OpenBilling
      else
        DataFileOpen := False;
    end;
  end;

  procedure Append;
    {-Append a new database entry}
  var
    Result : EStype;
  begin
    {exit if we have no data}
    if not DataFileOpen then
      Exit;

    {create an empty record}
    CurrentRec := Succ(TotalRecs);
    FillChar(BlankBill, SizeOf(BlankBill), $FF);
    BlankBill.AllowUpdate := True;
    BlankBill.Comment[0] := #0;

    {edit the blank record}
    repeat
      Result := EditScreen(ESR, ESR.CurrentID, False);
    until (Result = ESquit) or ((Result = ESdone) and ValidateBill);

    {write it}
    if Result = ESquit then
      Dec(CurrentRec)
    else if not WriteRecord(CurrentRec, BlankBill) then begin
      AllDone := True;
      Exit;
    end;

    {clear the display window}
    ClearDisplayWindow;
  end;

  procedure Browse;
    {-Browse through database entries}
  var
    Escaped : Boolean;
  begin
    {exit if we have no data}
    if not DataFileOpen then
      Exit;

    {make sure there's something to browse through}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    {clear the display window}
    ClearDisplayWindow;

    {call ChooseRecord routine}
    if not ChooseRecord(Escaped, True) then begin
      AllDone := True;
      Exit;
    end;

    {clear the display window}
    ClearDisplayWindow;
  end;

  procedure Calculate;
    {-Calculate total hours, earnings}
  var
    I : Word;
    TotalSecs : LongInt;
    Earnings : Float;
    BR : BillingRec;
    St : String80;
    Days : Word;
  begin
    if not DataFileOpen then
      Exit;

    {make sure there's something to calculate}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    {get rate per hour}
    if not GetRate then
      Exit;

    {calculate total time}
    TotalSecs := 0;
    Days := 0;
    for I := 1 to TotalRecs do
      if ReadRecord(I, BR) then begin
        Inc(TotalSecs, BR.Elapsed);
        if TotalSecs > MaxTime then begin
          Inc(Days);
          Dec(TotalSecs, SecondsInDay);
        end;
      end
      else begin
        AllDone := True;
        Exit;
      end;

    {display time, earnings}
    Earnings := Rate*(((Days*1.0*SecondsInDay)+TotalSecs)/SecsPerHour);
    St := HoursMinsSecs(Days, TotalSecs)+' at '+MoneyString(Rate)+'/hr = '+
    MoneyString(Earnings);
    ErrorMessage(St, False);
  end;

  procedure DeleteEntries;
    {-Delete database entries}
  var
    Escaped : Boolean;
  begin
    if not DataFileOpen then
      Exit;

    {make sure there's something to delete}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    {clear the display window}
    ClearDisplayWindow;

    repeat
      {choose a record}
      if not ChooseRecord(Escaped, False) then begin
        AllDone := True;
        Exit;
      end;

      {confirm that it is to be deleted}
      if not Escaped then
        if YesOrNo('Are you sure you want to delete this record?', False) then
          if not DeleteRecord(CurrentRec) then begin
            AllDone := True;
            Exit;
          end;
    until Escaped;

    {clear the display window}
    ClearDisplayWindow;
  end;

  procedure EditEntries;
    {-Edit database entries}
  var
    Result : EStype;
  begin
    if not DataFileOpen then
      Exit;

    {make sure there's something to edit}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    {clear the display window}
    ClearDisplayWindow;

    repeat
      {read in the record}
      if not ReadRecord(CurrentRec, BlankBill) then begin
        AllDone := True;
        Exit;
      end;

      {edit the record}
      repeat
        Result := EditScreen(ESR, ESR.CurrentID, False);
      until (Result = ESquit) or ValidateBill;

      {write the record}
      if Result <> ESquit then
        if not WriteRecord(CurrentRec, BlankBill) then begin
          AllDone := True;
          Exit;
        end;

      {next/previous record?}
      case Result of
        ESnextRec :          {next record}
          if CurrentRec < TotalRecs then
            Inc(CurrentRec);
        ESprevRec :          {previous record}
          if CurrentRec > 1 then
            Dec(CurrentRec);
      end;
    until (Result = ESquit) or (Result = ESdone);

    {clear the display window}
    ClearDisplayWindow;
  end;

  procedure SelectFile;
    {-Select a new data file}
  var
    SaveBillingName : String64;
    SaveOpen : Boolean;
  begin
    {save the current file name, open status, etc.}
    SaveBillingName := BillingName;
    SaveOpen := DataFileIsOpen;
    if SaveOpen then begin
      Close(BillingFile);
      if Int24Result <> 0 then begin
        ErrorMessage('Error while closing current data file', True);
        AllDone := True;
        Exit;
      end;
    end;
    DataFileIsOpen := False;

    {if new name not selected, restore old one}
    if not DataFileOpen then begin
      BillingName := SaveBillingName;
      if SaveOpen then begin
        BillingName := SaveBillingName;
        if not OpenBilling then
          AllDone := True;
      end;
    end;
  end;

  function QuitProgram : Boolean;
    {-Returns true if user wants to quit or no data file is open}
  begin
    if not DataFileIsOpen then
      QuitProgram := True
    else
      QuitProgram := YesOrNo('Are you sure you wish to quit?', False);
  end;

  procedure Report(ToPrinter : Boolean);
    {-Write a report to disk}
  const
    FName : String64 = '';
  var
    F : Text;
    FP : ^Text;
    St : string;
    BR : BillingRec;
    TotalSecs : LongInt;
    Earnings : Float;
    DoRate : Boolean;
    Days, I, IoStat : Word;
  begin
    if not DataFileOpen then
      Exit;

    {make sure there's something to report}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    if ToPrinter then
      FP := @Lst
    else begin
      {get filename}
      if not GetFName('Report file: ', FName, False) then
        Exit;

      {check for overwrite}
      if ExistFile(FName) then
        if not YesOrNo('File exists. Overwrite it?', False) then
          Exit;

      {open file}
      Assign(F, FName);
      Rewrite(F);
      IoStat := Int24Result;
      if IoStat <> 0 then begin
        ErrorMessage('Error opening report file', True);
        AllDone := True;
        Exit;
      end;
      FP := @F;
    end;

    {get rate}
    DoRate := GetRate;

    {write header}
    WriteLn(FP^, 'Data from: ', BillingName, ^M^J);
    IoStat := Int24Result;
    if IoStat <> 0 then begin
      if ToPrinter then
        ErrorMessage(PrintError, True)
      else
        ErrorMessage(ReportError, True);
      AllDone := True;
      Exit;
    end;

    {write the report}
    TotalSecs := 0;
    Days := 0;
    for I := 1 to TotalRecs do begin
      if not ReadRecord(I, BR) then begin
        AllDone := True;
        Exit;
      end;

      {add to total}
      Inc(TotalSecs, BR.Elapsed);
      if TotalSecs > MaxTime then begin
        Inc(Days);
        Dec(TotalSecs, SecondsInDay);
      end;

      with BR do begin
        if DoRate then
          St := '  Earnings: '+MoneyString(Rate*(Elapsed/SecsPerHour))
        else
          St := NullString;
        if Length(Comment) <> 0 then
          St := St+^M^J+Comment;
        WriteLn(FP^, 'Record #', I, ^M^J,
          'Start: ', DateToDateString(DateFormat, Starting.D), ' at ',
          TimeToTimeString(AmPmFormat, Starting.T), ^M^J,
          'Stop:  ', DateToDateString(DateFormat, Stopping.D), ' at ',
          TimeToTimeString(AmPmFormat, Stopping.T), ^M^J,
          'Elapsed: ', TimeToTimeString(TimeFormat, Elapsed), St, ^M^J);
        IoStat := Int24Result;
        if IoStat <> 0 then begin
          if ToPrinter then
            ErrorMessage(PrintError, True)
          else
            ErrorMessage(ReportError, True);
          AllDone := True;
          Exit;
        end;

      end;
    end;

    {write totals}
    St := HoursMinsSecs(Days, TotalSecs);
    if DoRate then begin
      Earnings := Rate*(((Days*1.0*SecondsInDay)+TotalSecs)/SecsPerHour);
      St := St+' at '+MoneyString(Rate)+'/hr = '+MoneyString(Earnings);
    end
    else
      St := St+'.';
    WriteLn(FP^, 'Totals:'^M^J'-------'^M^J, St);
    IoStat := Int24Result;
    if IoStat <> 0 then begin
      if ToPrinter then
        ErrorMessage(PrintError, True)
      else
        ErrorMessage(ReportError, True);
      AllDone := True;
      Exit;
    end;

    if ToPrinter then begin
      {write a form feed}
      Write(FP^, ^L);
      IoStat := Int24Result;
    end
    else begin
      {close the file}
      Close(FP^);
      IoStat := Int24Result;
    end;

    {check for IO error}
    if IoStat <> 0 then begin
      ErrorMessage('Error closing report file', True);
      AllDone := True;
    end
    else begin
      {show that we're finished}
      Prompt('Report finished...');
      Delay(1500);
      ClearPromptLine;
    end;
  end;

  procedure Totals;
    {-Display number of records, total time}
  var
    Days, I : Word;
    TotalSecs : LongInt;
    BR : BillingRec;
  begin
    if not DataFileOpen then
      Exit;

    {make sure there's something to total}
    if TotalRecs = 0 then begin
      ErrorMessage(ZeroEntries, True);
      Exit;
    end;

    {calculate total time}
    TotalSecs := 0;
    Days := 0;
    for I := 1 to TotalRecs do
      if ReadRecord(I, BR) then begin
        Inc(TotalSecs, BR.Elapsed);
        if TotalSecs > MaxTime then begin
          Inc(Days);
          Dec(TotalSecs, SecondsInDay);
        end;
      end
      else begin
        AllDone := True;
        Exit;
      end;

    {display # of records, total time}
    ErrorMessage(Decimal(TotalRecs, 0, False)+' records. '+
      HoursMinsSecs(Days, TotalSecs), False);
  end;

  procedure InitMenu(var M : Menu);
    {-Initialize main menu}
  begin
    {Customize this call for special exit characters and custom item displays}
    M := NewMenu([], nil);

    {select color table}
    if WhichHerc = HercInColor then
      ColorsPtr := @Color1
    else case CurrentMode of
      2, 7 : ColorsPtr := @Mono1;
      else ColorsPtr := @Color1;
    end;

    SubMenu(1, 1, 25, Horizontal, Frame1, ColorsPtr^,
      ' PTRPT: Report Generator for PTIME Data Files 5.22 ');
    MenuItem(' Append ', 02, 2, 01, 'Append a database entry');
    MenuItem(' Browse ', 10, 2, 02, 'Browse through database entries');
    MenuItem(' Calculate ', 18, 2, 03, 'Calculate total hours, earnings');
    MenuItem(' Delete ', 29, 2, 04, 'Delete a database entry');
    MenuItem(' Edit ', 37, 2, 05, 'Edit a database entry');
    MenuItem(' File ', 43, 2, 06, 'Select a data file');
    MenuItem(' Print ', 49, 2, 07, 'Generate a printed report');
    MenuItem(' Quit ', 56, 2, 08, 'Quit the program');
    MenuItem(' Report ', 62, 2, 09, 'Generate a report on disk');
    MenuItem(' Totals ', 70, 2, 10, 'Display number of entries in database, total hours');
    PopSublevel;

    ResetMenu(M);
  end;

  procedure CleanUpScreen;
    {-Clean up screen at end of program}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    EraseMenu(RootMenu, False);
    NormVideo;
    ClrScr;
    RestoreCursorState($0101, InitSL);
  end;

  procedure Initialize;
    {-Initialize global variables, etc.}
  var
    Dummy : Word;
  begin
    {check screen mode, size}
    if not(InTextMode and (ScreenWidth = 80)) then begin
      WriteLn('This program runs only in 80-column text modes.');
      Halt(1);
    end;

    {initialize screen}
    if ScreenHeight > 25 then
      SelectFont8x8(False);
    ClrScr;
    CheckBreak := False;
    GetCursorState(Dummy, InitSL);
    HiddenCursor;

    {build the menu system}
    InitMenu(RootMenu);

    {$IFDEF EnablePickOrientations}
    {set the pick orientation}
    SetVerticalPick;
    {$ENDIF}

    {video attributes}
    Dim := ColorsPtr^[HelpColor];
    Bright := ColorsPtr^[HiliteColor];
    Reverse := ColorsPtr^[SelectColor];
    PickColors[WindowAttr] := Dim;
    PickColors[FrameAttr] := Bright;
    PickColors[HeaderAttr] := Reverse;
    PickColors[SelectAttr] := Reverse;
    PickColors[AltNormal] := Bright;
    PickColors[AltHigh] := Reverse;
    {$IFDEF PickItemDisable}
    PickColors[WindowAttr] := Dim;
    {$ENDIF}

    {$IFDEF UseMouse}
    if MouseInstalled then begin
      {use a diamond for our mouse cursor}
      SoftMouseCursor($0000, (Bright shl 8)+$04);
      ShowMouse;

      {enable mouse support}
      EnableEntryMouse;
      EnablePickMouse;
      EnableMenuMouse;
    end;
    {$ENDIF}

    {initialize global variables}
    TotalRecs := 0;
    CurrentRec := 0;
    Rate := 0.0;
    DataFileIsOpen := False;
    FillChar(Blank[1], 80, ' ');

    {initialize the edit screen record}
    InitESrecord(ESR);

    {install user-written event handlers}
    SetPreEditPtr(ESR, @DisplayHelpPrompt);
    SetErrorPtr(ESR, @ErrorHandler);

    {set edit screen options}
    SetWrapMode(ESR, WrapAtEdges);

    {set field editing options}
    SetClearFirstChar(On);
    SetPromptAttr(Bright);
    SetFieldAttr(Dim);
    SetStringAttr(Reverse);
    SetCtrlAttr(Reverse);

    {add each of the edit fields in order: left to right, top to bottom}
    SetProtection(On);
    AddStringField(ESR, 'Data file:', 7, 4, '', 7, 15, 64, 0, nil, BillingName);
    AddWordField(ESR, 'Record #', 9, 4, '99999', 9, 18, 1, 0, 0, CurrentRec);
    SetProtection(Off);

    AddDateField(ESR, 'Start date:', 10, 4, DateFormat, 10, 18, 2,
      MinDate, Today+1, BlankBill.Starting.D);
    AddTimeField(ESR, 'Start time:', 11, 4, AmPmFormat, 11, 18, 3,
      MinTime, MaxTime, BlankBill.Starting.T);
    AddDateField(ESR, 'Stop date:', 12, 4, DateFormat, 12, 18, 4,
      MinDate, Today+1, BlankBill.Stopping.D);
    AddTimeField(ESR, 'Stop time:', 13, 4, AmPmFormat, 13, 18, 5,
      MinTime, MaxTime, BlankBill.Stopping.T);
    AddTimeField(ESR, 'Elapsed time:', 14, 4, TimeFormat, 14, 18, 6,
      MinTime, MaxTime, BlankBill.Elapsed);
    AddYesNoField(ESR, 'Allow update:', 16, 4, '', 16, 18, 7,
      BlankBill.AllowUpdate);

    SetAutoAdvance(Off);
    AddStringField(ESR, 'Comment:', 18, 4, CharStr('X', 76), 18, 18, 58, 8, nil,
      BlankBill.Comment);

    {get name of data file, if any}
    BillingName := StUpcase(ParamStr(1));
    if Length(BillingName) <> 0 then
      if GetFileNameShell(BillingName) then
        if not OpenBilling then {} ;
  end;

begin
  {make sure we can run under a multitasking environment}
  DetectMultitasking := True;
  ReinitCrt;

  {initialize globals, menu system, etc}
  Initialize;

  AllDone := False;
  repeat
    {reset}
    CurrentRec := 1;
    ESR.CurrentID := 0;

    {Put up the menu and get a menu action}
    Key := MenuChoice(RootMenu, MenuCh);

    {Handle the command}
    if MenuCmdNum = MKSExit then
      AllDone := QuitProgram
    else if MenuCmdNum = MKSSelect then
      case Key of
        01 : Append;         {Append database entry}
        02 : Browse;         {Browse through database entries}
        03 : Calculate;      {Calculate total hours, earnings}
        04 : DeleteEntries;  {Delete database entries}
        05 : EditEntries;    {Edit database entries}
        06 : SelectFile;     {select data File}
        07 : Report(True);   {report to Printer}
        08 : AllDone := QuitProgram; {Quit}
        09 : Report(False);  {Report to disk}
        10 : Totals;         {display Totals}
      end;
  until AllDone;

  {clean up the screen}
  CleanUpScreen;
end.
