{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,I-}
{$V-}                        {<- required for TPENTRY}
{$M 16384,16384,600000}

{$I TPDEFINE.INC}

{*********************************************************}
{*                   ENTRY.PAS 5.22                      *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1988, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program TpEntryDemo;
  {-Demonstrates use of TPENTRY unit}

uses
  TpString,                  {string handling}
  TpCrt,                     {basic screen handling}
  {$IFDEF UseMouse}
  TpMouse,                   {mouse routines}
  {$ENDIF}
  TpDate,                    {date and time variables}
  TpEntry,                   {data entry}
  TpMemo,                    {memo field editor}
  TpWindow,                  {window management}
  TpPick,                    {pick lists}
  TpHelp;                    {popup help}

const
  TitleLine = 02;
  StatusLine = 04;
  HelpLine = 22;
  KeyInfoLine = 24;
  Title : string[38] = 'Demonstration Program for TPENTRY 5.22';
  KeyInfoText : string[78] =
  ' <F1> Help '^G' '^[^X^Y^Z' move cursor '^G' <Enter> Accept '^G' <Esc> Cancel '^G' <^Enter> Quit ';
type
  GenderType = (Unknown, Male, Female);
  MemoField = array[1..2048] of Char;
  Info =
    record
      Name : string[30];     {string field}
      Address : string[30];  {string field}
      City : string[25];     {string field}
      State : string[02];    {string field w/ special validation}
      Zip : string[10];      {string field w/ special validation}
      WPhone : string[14];   {string field w/ special validation}
      HPhone : string[14];   {string field w/ special validation}
      Gender : GenderType;   {multiple choice field}
      Married : Boolean;     {yes/no field}
      Born : Date;           {date field}
      Age : Byte;            {calculated field, based on Born}
      Wage : Real;           {numeric field w/ range checking}
      Weekly : Real;         {calculated field (= Wage * Hours)}
      Hours : Byte;          {multiple choice field, incremental}
      Yearly : Real;         {calculated field (= Weekly * 52)}
      Notes : MemoField;     {a memo field}
    end;
const
  MaxRec = 20;
  PhoneMask : string[14] = '(999) 999-9999';
  ValidPhone : string[14] = '(ppp) uuu-uuuu';
  ZipMask : string[10] = '99999-9999';
  ValidZip : string[10] = 'uuuuu-pppp';
  Genders : array[GenderType] of string[7] = (
    'Unknown', 'Male   ', 'Female ');
  EmptyString : string[1] = '';
  OurHelpColorAttr : HelpColorArray = ($1D, $1B, $5F, $5F, $3F, $1E, $1F, $1B);
  OurHelpMonocAttr : HelpColorArray = ($0F, $07, $70, $70, $09, $0F, $0F, $0F);
var
  InfoRecs : array[1..MaxRec] of Info; {the "database"}
  Scrap : Info;              {blank record used for editing}
  CurrentRec : Byte;         {current index into InfoRecs}
  ExitCommand : EStype;      {exit command returned by editor}
  ESR1 : ESrecord;            {our main edit screen}
  ESR2 : ESrecord;           {our nested edit screen}
  BoxAttr : Byte;            {color of boxes}
  BoxTextAttr : Byte;        {color of text in boxes}
  ProtectAttr : Byte;        {attribute used for protected fields}
  BlankWageAttr : Byte;      {special attribute used for Wage field}
  PickColors : PickColorArray; {colors for TPPICK}
  HelpColors : HelpColorArray; {colors for TPHELP}
  AllDone : Boolean;         {done with demo program}
  HelpP : HelpPtr;           {pointer to help system}
  WP1 : WindowPtr;           {points to window for second entry screen}
  WP2 : WindowPtr;           {points to window for memo field editor}
  DateMask : string[10];     {picture mask for date strings}
  TimeMask : string[11];     {picture mask for time strings}
  WageMask : string[10];     {picture mask for wage field}
  CurrMask : string[15];     {picture mask for totals based on wages}

const
  StateStrings : array[1..51] of string[19] = (
    {01} 'AK Alaska',
    {02} 'AL Alabama',
    {03} 'AR Arkansas',
    {04} 'AZ Arizona',
    {05} 'CA California',
    {06} 'CO Colorado',
    {07} 'CT Connecticut',
    {08} 'DC Dist of Columbia',
    {09} 'DE Delaware',
    {10} 'FL Florida',
    {11} 'GA Georgia',
    {12} 'HI Hawaii',
    {13} 'IA Iowa',
    {14} 'ID Idaho',
    {15} 'IL Illinois',
    {16} 'IN Indiana',
    {17} 'KS Kansas',
    {18} 'KY Kentucky',
    {19} 'LA Louisana',
    {20} 'MA Massachusetts',
    {21} 'MD Maryland',
    {22} 'ME Maine',
    {23} 'MI Michigan',
    {24} 'MN Minnesota',
    {25} 'MO Missouri',
    {26} 'MS Mississippi',
    {27} 'MT Montana',
    {28} 'NC North Carolina',
    {29} 'ND North Dakota',
    {30} 'NE Nebraska',
    {31} 'NH New Hampshire',
    {32} 'NJ New Jersey',
    {33} 'NM New Mexico',
    {34} 'NV Nevada',
    {35} 'NY New York',
    {36} 'OH Ohio',
    {37} 'OK Oklahoma',
    {38} 'OR Oregon',
    {39} 'PA Pennsylvania',
    {40} 'RI Rhode Island',
    {41} 'SC South Carolina',
    {42} 'SD South Dakota',
    {43} 'TN Tennessee',
    {44} 'TX Texas',
    {45} 'UT Utah',
    {46} 'VA Virginia',
    {47} 'VT Vermont',
    {48} 'WA Washington',
    {49} 'WI Wisconsin',
    {50} 'WV West Virginia',
    {51} 'WY Wyoming');

  {$F+}
  function ValidatePhone(var FR : FieldRec;
                         var ErrCode : Byte;
                         var ErrorSt : StringPtr) : Boolean;
    {-Validate a phone number}
  begin
    ValidatePhone := ValidateSubfields(ValidPhone, FR, ErrCode, ErrorSt);
  end;

  function ValidateZip(var FR : FieldRec;
                       var ErrCode : Byte;
                       var ErrorSt : StringPtr) : Boolean;
    {-Validate a zip code}
  begin
    ValidateZip := ValidateSubfields(ValidZip, FR, ErrCode, ErrorSt);
  end;

  function ValidateState(var FR : FieldRec;
                         var ErrCode : Byte;
                         var ErrorSt : StringPtr) : Boolean;
    {-Validate a state abbreviation}
  const
    BadState : String[37] = 'Not a valid abbreviation for a state.';
  var
    I : Word;
    S : String[2];
  begin
    {don't validate if user pressed <F2> or clicked on the field}
    if (LastEntryCommand = ESuser1) or (LastEntryCommand = ESclickExit) then
      ValidateState := True
    {check for partial entry}
    else if ValidateNotPartial(FR, ErrCode, ErrorSt) then begin
      {not partial--is it empty?}
      ValidateState := True;
      S := Trim(FR.EditSt^);
      if Length(S) = 0 then
        Exit;

      {check list of valid abbreviations}
      for I := 1 to 51 do
        {exit if it's a match}
        if (S[1] = StateStrings[I][1]) and (S[2] = StateStrings[I][2]) then
          Exit;

      {not a valid abbreviation}
      ErrCode := 10; {arbitrary}
      ErrorSt := @BadState;
      ValidateState := False;
    end
    else
      ValidateState := False;
  end;

  function StateChoice(I : Word) : string;
    {-Return a state string given an index}
  begin
    StateChoice := StateStrings[I];
  end;
  {$F-}

  procedure DisplayCentered(S : string; Row : Byte);
    {-Display S centered on the specified Row}
  begin
    {$IFDEF UseMouse}
    HideMouse;
    {$ENDIF}

    FastWrite(Center(S, 78), Row, 2, BoxTextAttr);

    {$IFDEF UseMouse}
    ShowMouse;
    {$ENDIF}
  end;

  procedure ClearHelpLine;
    {-Clear the help line}
  begin
    DisplayCentered(EmptyString, HelpLine);
  end;

  {$F+}
  function GetKey : Word;
    {-Display current date and time while waiting for keypress}
  begin
    {$IFDEF UseMouse}
    while not(KeyPressed or MousePressed) do begin
    {$ELSE}
    while not KeyPressed do begin
    {$ENDIF}
      {make sure TSR's can pop up}
      inline($CD/$28);

      {display the current date and time}
      FastWrite(TodayString(DateMask), StatusLine, 38, ESfieldAttr);
      FastWrite(CurrentTimeString(TimeMask), StatusLine, 57, ESfieldAttr);
    end;

    {$IFDEF UseMouse}
    if KeyPressed then
      GetKey := ReadKeyWord
    else
      GetKey := MouseKeyWord;
    {$ELSE}
      GetKey := ReadKeyWord
    {$ENDIF}
  end;

  procedure IncChoice(var Value; FieldID : Word; Factor : Integer; var St : string);
    {-Increment a multiple choice field value and convert it to a string}
  var
    Gender : GenderType absolute Value;
    Hours : Byte absolute Value;
  begin
    if FieldID = 7 then begin
      {Gender}
      case Factor of
        01 :                 {increment}
          if Gender = Female then
            Gender := Unknown
          else
            Inc(Gender);
        -1 :                 {decrement}
          if Gender = Unknown then
            Gender := Female
          else
            Dec(Gender);
      end;
      St := Genders[Gender];
    end
    else if FieldID = 13 then begin
      {Hours}
      case Factor of
        01 :                 {increment}
          if Hours < 99 then
            Inc(Hours);
        -1 :                 {decrement}
          if Hours > 0 then
            Dec(Hours);
      end;
      Str(Hours:2, St);
    end;
  end;

  procedure DisplayErrorMessage(Msg : string);
    {-Display an error message}
  var
    W, CursorSL, CursorXY : Word;
  begin
    {Store cursor position and shape, then make it a fat cursor}
    GetCursorState(CursorXY, CursorSL);
    FatCursor;

    {add to default message, if possible}
    if Length(Msg) < 60 then
      Msg := Msg+' Press any key...';

    {display error message and ring bell}
    DisplayCentered(Msg, HelpLine);
    RingBell;

    {flush keyboard buffer}
    while KeyPressed do
      W := GetKey;

    {wait for keypress, then clear the help line}
    W := GetKey;
    ClearHelpLine;

    {Restore cursor position and shape}
    RestoreCursorState(CursorXY, CursorSL);
  end;

  procedure ErrorHandler(var ESR : ESrecord; Code : Byte; Msg : string);
    {-Display messages for errors reported by TPENTRY}
  begin
    DisplayErrorMessage(Msg);
    case Code of
      InitError, OverflowError, MemoryError, ParamError :
        begin
          {a fatal error: set normal cursor and clear the screen}
          NormalCursor;
          ClrScr;
        end;
    end;
  end;

  procedure SetAgeFieldAttribute(var ESR : ESrecord);
    {-Set the attributes for the Age field such that the field is hidden if
      Age = 0}
  begin
    if Scrap.Age = 0 then begin
      {hide the entire field}
      ChangePromptAttr(ESR, 10, 0);
      ChangeFieldAttr(ESR, 10, 0);
    end
    else begin
      {unhide the field}
      ChangePromptAttr(ESR, 10, ESpromptAttr);
      ChangeFieldAttr(ESR, 10, ProtectAttr);
    end;
  end;

  procedure SetWageFieldAttribute(var ESR : ESrecord);
    {-Set the attributes for the Wage field such that the field is blanked out
      if Wage = 0}
  begin
    if Scrap.Wage = 0 then
      ChangeFieldAttr(ESR, 11, BlankWageAttr)
    else
      ChangeFieldAttr(ESR, 11, ESfieldAttr);
  end;

  procedure UpdateHandler(var ESR : ESrecord);
    {-Called after a field has been edited}
  var
    Days, Months, Years : Integer;
    ThisDate : Date;         {today's date in julian format}
  begin
    ThisDate := Today;
    with Scrap do
      case ESR.CurrentID of
{!!}    01 :
{!!}      if Name = '' then
{!!}        ChangeProtection(ESR, 2, True)
{!!}      else
{!!}        ChangeProtection(ESR, 2, False);
        09 :                 {Born}
          begin
            {calculate Age field}
            if (Born = BadDate) or (Born > ThisDate) then
              Age := 0
            else begin
              DateDiff(Born, ThisDate, Days, Months, Years);
              Age := Years;
            end;

            {redraw the Age and field}
            SetAgeFieldAttribute(ESR);
            DrawField(ESR, 10);
          end;
        11,                  {Wage}
        13 :                 {Hours}
          begin
            {calculate weekly and yearly earnings}
            Weekly := Wage*Hours;
            Yearly := Weekly*52;

            {redraw Wage field if appropriate}
            if ESR.CurrentID = 11 then begin
              SetWageFieldAttribute(ESR);
              DrawField(ESR, 11);
            end;

            {redraw Weekly}
            DrawField(ESR, 12);

            {redraw Yearly}
            DrawField(ESR, 14);
          end;
      end;
  end;

  procedure DisplayHelpPrompt(var ESR : ESrecord);
    {-Display a help prompt for the current field}
  var
    S : string[80];
  begin
    case ESR.CurrentID of
      {--Field 0 is the record number (protected)--}
      01 : S := 'Enter first name, middle initial, last name';
      02 : S := 'Enter street address or post office box';
      03 : S := 'Enter city of residence';
      04 : S := 'Enter state of residence or press <F2> to select from list';
      05 : S := 'Enter a five- or nine-digit zip code';
      06 : S := 'Press <Enter> to edit work and home phone numbers';
      07 : S := 'Press space bar, "+" or "-" to select gender';
      08 : S := 'Enter "N" if marital status is unknown, else "N" or "Y"';
      09 : S := 'Enter date of birth';
      {--Field 10 is Age (protected, calculated)--}
      11 : S := 'Enter hourly wage ($0-$99.99)';
      {--Field 12 is Weekly (protected, calculated)--}
      13 : S := 'Press "+" or "-" to adjust hours worked per week';
      {--Field 14 is Yearly (protected, calculated)--}
      15 : S := 'Press <Enter> to edit notes field';
    end;
    DisplayCentered(S, HelpLine);
  end;

  procedure DisplayHelpPrompt2(var ESR : ESrecord);
    {-Display a help prompt for the current field}
  var
    S : string[80];
  begin
    case ESR.CurrentID of
      00 : S := 'Enter work phone number (area code is optional)';
      01 : S := 'Enter home phone number (area code is optional)';
    end;
    DisplayCentered(S, HelpLine);
  end;

  procedure DisplayHelp(UnitCode : Byte; IdPtr : Pointer; HelpIndex : Word);
    {-Display context sensitive help}
  begin
    {do nothing if help index is illegal}
    if HelpIndex <> 0 then begin
      {ignore the help index passed by TPPICK}
      if UnitCode = HelpForPick then
        if IdPtr = @StateChoice then
          HelpIndex := 4
        else
          {in help system displaying topic index--do nothing}
          Exit;

      {display the help screen}
      if not ShowHelp(HelpP, HelpIndex) then
        RingBell;
    end;
  end;

  procedure MemoFieldStatus(var EMCB : EMcontrolBlock);
    {-Display status line for memo field}
                              {         1         2         }
  const                       {12345678901234567890123456789}
    StatusLine : string[29] = ' Line: xxx Column: xxx 100% ';
  var
    S : string[5];
  begin
    with EMCB do begin
      {insert line number}
      S := Long2Str(CurLine);
      S := Pad(S, 3);
      Move(S[1], StatusLine[8], 3);

      {insert column number}
      S := Long2Str(CurCol);
      S := Pad(S, 3);
      Move(S[1], StatusLine[20], 3);

      {insert percentage of buffer used}
      S := Real2Str(Trunc((TotalBytes*100.0)/(BufSize-2)), 3, 0);
      Move(S[1], StatusLine[24], 3);

      {$IFDEF UseMouse}
      HideMouse;
      {$ENDIF}

      {display status line}
      FastWrite(StatusLine, 19, 27, BoxTextAttr);

      {$IFDEF UseMouse}
      ShowMouse;
      {$ENDIF}
    end;
  end;

  procedure MemoPrompt;
    {-Display the prompt for the memo editor}
  begin
    DisplayCentered('Press <Esc> when finished entering notes', HelpLine);
  end;

  procedure MemoErrorHandler(var EMCB : EMcontrolBlock; ErrorCode : Word);
    {-Display error message and wait for key press}
  begin
    case ErrorCode of
      tmBufferFull :
        DisplayErrorMessage('Edit buffer is full.');
      tmLineTooLong :
        DisplayErrorMessage('Line too long, carriage return inserted.');
      tmTooManyLines :
        DisplayErrorMessage('Limit on number of lines has been reached.');
      tmOverLineLimit :
        DisplayErrorMessage('Limit on number of lines has been exceeded');
      else
        DisplayErrorMessage('Unknown error.');
    end;

    {redisplay our prompt}
    MemoPrompt;
  end;
  {$F-}

  procedure EditMemoField;
    {-Edit a memo field}
  const
    NullCmdList : EMtype = EMnone;
  var
    ExitCommand : EMtype;
    EMCB : EMcontrolBlock;
  begin
    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {display the window}
    if not DisplayWindow(WP2) then {} ;

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}

    {initialize the edit control block}
    InitControlBlock(
      EMCB,                  {control block}
      9,                     {left column of edit window}
      8,                     {top row of edit window}
      72,                    {right column of edit window}
      18,                    {bottom row of edit window}
      BoxTextAttr,           {attribute for normal text}
      BoxTextAttr,           {attribute for control characters}
      True,                  {insert mode on?}
      True,                  {auto-indent on?}
      True,                  {word wrap on?}
      8,                     {distance between tab stops}
      15,                    {help index}
      63,                    {right margin}
      999,                   {maximum number of lines}
      SizeOf(MemoField),     {size of edit buffer}
      Scrap.Notes);          {edit buffer}

    {start editing}
    MemoPrompt;
    ExitCommand := EditMemo(EMCB, False, NullCmdList);
    ClearHelpLine;

    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {erase the window}
    WP2 := EraseTopWindow;

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}
  end;

  function ConfirmQuitting : Boolean;
    {-Confirm that the user wants to quit}
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
  begin
    while KeyPressed do
      ChWord := ReadKeyWord;

    {$IFDEF UseMouse}
    while MousePressed do
      ChWord := MouseKeyWord;
    {$ENDIF}

    HiddenCursor;
    DisplayCentered(
      'Are you sure you want to quit? (Press "Y" or <Esc> to confirm.)', HelpLine);
    ChWord := GetKey;

    {$IFDEF UseMouse}
      ConfirmQuitting := (Upcase(Ch) = 'Y') or (Ch = #27) or (ChWord = MouseRt);
    {$ELSE}
      ConfirmQuitting := (Upcase(Ch) = 'Y') or (Ch = #27);
    {$ENDIF}

    ClearHelpLine;
    NormalCursor;
  end;

  procedure PickAState;
    {-Pick a state name from a pick list}
  const
    Choice : Word = 1;
  var
    B : Boolean;
  begin
    {uncomment the following line to home the cursor each time}
    {Choice := 1;}

    PickMatrix := 3;
    PickSrch := CharPickSrch;
    PickHelpPtr := @DisplayHelp;

    {choose a state from the list}
    B := PickWindow(@StateChoice, 51, 8, 7, 73, 19, True, PickColors,
      ' Abbreviated State Names ', Choice);

    {do nothing if ESC was pressed}
    if PickCmdNum = PKSSelect then
      {put the name in the actual variable, not Scrap}
      InfoRecs[CurrentRec].State := StateChoice(Choice);
  end;

  procedure DrawMainScreen;
    {-Draw the outline of the screen. Fields filled in later}

    procedure DrawBox(Row : Byte);
      {-Draw a divided box starting at the specified Row}
    var
      I : Word;
    begin
      {draw the main box}
      for I := Row to Row+4 do
        FastFill(80, ' ', I, 1, BoxAttr);
      FrameWindow(1, Row, 80, Row+4, BoxAttr, BoxAttr, EmptyString);
      FastWrite('Ã'+CharStr('Ä', 78)+'´', Row+2, 1, BoxAttr);
    end;

  begin
    ClrScr;
    FrameChars := 'ÕÔ¸¾Í³';

    {draw the box at the top of the screen}
    DrawBox(TitleLine-1);
    DisplayCentered(Title, TitleLine);
    FastWrite('Date', StatusLine, 32, BoxTextAttr);
    FastWrite('Time', StatusLine, 51, BoxTextAttr);

    {draw the box at the bottom of the screen}
    DrawBox(HelpLine-1);
    DisplayCentered(KeyInfoText, KeyInfoLine);
  end;

  procedure OpenHelp;
    {-Open ENTRY.HLP}
  var
    Status : Word;
  begin
    {open the help file}
    Status := OpenHelpFile('ENTRY.HLP', 8, 7, 19, 2, HelpColors, HelpP);
    if Status <> 0 then begin
      case Status of
        002 : WriteLn('Help file ENTRY.HLP not found');
        100 : WriteLn('Unexpected end of file reading ENTRY.HLP');
        106 : WriteLn('Help file has invalid format');
        203 : WriteLn('Insufficient heap space available');
        else WriteLn('Help initialization error ', Status);
      end;
      Halt(1);
    end;
  end;

  function SecondaryEditScreen : Boolean;
    {-Display secondary edit screen in a popup window. Returns True to advance
      cursor for main edit screen forward, False for backward.}
  var
    ExitCommand : EStype;
    Done : Boolean;
  begin
    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {display the window}
    if not DisplayWindow(WP1) then {} ;

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}

    Done := False;
    repeat
      {start editing}
      ExitCommand := EditScreen(ESR2, ESR2.CurrentID, False);

      {copy the edited data back if ESC wasn't pressed}
      if ExitCommand <> ESquit then begin
        InfoRecs[CurrentRec].WPhone := Scrap.WPhone;
        InfoRecs[CurrentRec].HPhone := Scrap.HPhone;
      end;

      {see if we need to edit another record}
      case ExitCommand of
        ESuser0 :            {toggle Bell on/off}
          begin
            SetBeepOnError(ESR1, not ESR1.BeepOnError);
            SetBeepOnError(ESR2, not ESR2.BeepOnError);
          end;
        ESnextRec,
        ESprevRec,
        ESquit, ESdone :
          begin
            Done := True;
            SecondaryEditScreen := ExitCommand <> ESprevRec;
          end;
      end;
    until Done;

    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    {erase the window}
    WP1 := EraseTopWindow;

    {$IFDEF UseMouse}
    {reveal the mouse cursor}
    ShowMouse;
    {$ENDIF}
  end;

begin
  {initialize the database}
  FillChar(Scrap, SizeOf(Scrap), 0);
  FillChar(InfoRecs, SizeOf(InfoRecs), 0);
  for CurrentRec := 1 to MaxRec do begin
    InfoRecs[CurrentRec].Born := BadDate;
    InfoRecs[CurrentRec].Hours := 40;
    InfoRecs[CurrentRec].Notes[1] := ^Z;
  end;

  {get international picture mask formats}
  DateMask := InternationalDate(False, False);
  TimeMask := InternationalTime(True, False, True, True);
  WageMask := InternationalCurrency('9', 2, True, False);
  CurrMask := InternationalCurrency('#', 6, True, True);

  {handle color mapping manually}
  MapColors := False;

  {break checking off}
  CheckBreak := False;

  {make sure we're in 80*25 mode}
  case CurrentMode of
    0..1 : TextMode(CurrentMode+2);
    else
     if Hi(LastMode) <> 0 then
       SelectFont8x8(False);
  end;

  {set colors based on video mode}
  if WhichHerc = HercInColor then
    CurrentMode := 3;
  case CurrentMode of
    2 : begin
          BoxAttr := $0F;
          BoxTextAttr := $07;
          SetPromptAttr($0F);
          SetFieldAttr($70);
          SetStringAttr($70);
          SetCtrlAttr($70);
          ProtectAttr := $07;
          BlankWageAttr := $77;
          HelpColors := OurHelpMonocAttr;
        end;
    3 : begin
          BoxAttr := $1D;
          BoxTextAttr := $1B;
          SetPromptAttr($0B);
          SetFieldAttr($1F);
          SetStringAttr($5F);
          SetCtrlAttr($5F);
          ProtectAttr := $0F;
          BlankWageAttr := $11;
          HelpColors := OurHelpColorAttr;
        end;
    7 : begin
          BoxAttr := $0F;
          BoxTextAttr := $07;
          SetPromptAttr($0F);
          SetFieldAttr($70);
          SetStringAttr($70);
          SetCtrlAttr($70);
          ProtectAttr := $07;
          BlankWageAttr := $77;
          HelpColors := OurHelpMonocAttr;
        end;
  end;
  if WhichHerc = HercInColor then
    CurrentMode := GetCrtMode;
  TextAttr := ESpromptAttr;
  SetProtectAttrs(ESpromptAttr, ProtectAttr);
  PickColors[WindowAttr] := BoxTextAttr;
  PickColors[FrameAttr] := BoxAttr;
  PickColors[HeaderAttr] := ESstringAttr;
  PickColors[SelectAttr] := ESstringAttr;
  PickColors[AltNormal] := BoxTextAttr;
  PickColors[AltHigh] := ESstringAttr;
  {$IFDEF PickItemDisable}
  PickColors[UnpickableAttr] := BoxTextAttr;
  {$ENDIF}

  {make a window for the secondary edit screen}
  if not MakeWindow(WP1, 17, 12, 63, 15, True, True, True, BoxTextAttr,
    BoxAttr, ESstringAttr, ' Phone Numbers ') then
    Halt(1);

  {make a window for the memo editor}
  if not MakeWindow(WP2, 8, 7, 73, 19, True, True, True, BoxTextAttr,
    BoxAttr, ESstringAttr, ' Notes ') then
    Halt(1);

  {open the help file}
  OpenHelp;

  {draw basic outline of the screen}
  DrawMainScreen;

  {$IFDEF UseMouse}
  if MouseInstalled then begin
    {use a diamond of the same color as field prompts for our mouse cursor}
    SoftMouseCursor($0000, (ESpromptAttr shl 8)+$04);
    ShowMouse;

    {enable mouse support}
    EnableEntryMouse;
    EnablePickMouse;
    EnableHelpMouse;
    EnableMemoMouse
  end;
  {$ENDIF}

  {$IFDEF EnablePickOrientations}
  {initialize the pick orientation}
  SetSnakingPick;
  {$ENDIF}

  {initialize the edit screen record}
  InitESrecord(ESR1);

  {install user-written event handlers}
  SetPreEditPtr(ESR1, @DisplayHelpPrompt);
  SetPostEditPtr(ESR1, @UpdateHandler);
  SetErrorPtr(ESR1, @ErrorHandler);
  EntryKeyPtr := @GetKey;
  HelpKeyPtr := @GetKey;
  PickKeyPtr := @GetKey;
  MemoKeyPtr := @GetKey;
  EntryHelpPtr := @DisplayHelp;
  MemoHelpPtr := @DisplayHelp;
  MemoStatusPtr := @MemoFieldStatus;
  MemoErrorPtr := @MemoErrorHandler;

  {set up user exit keys}
  {<AltB> turns bell on/off}
  if not AddEntryCommand(ESuser0, 1, $3000, 0) then ;
  {<F2> pops up pick list for State field}
  if not AddEntryCommand(ESuser1, 1, $3C00, 0) then ;

  {set edit screen options}
  SetWrapMode(ESR1, WrapAtEdges);
  SetBeepOnError(ESR1, On);

  {set field editing options}
  SetClearFirstChar(On);

  {add each of the edit fields in order: left to right, top to bottom}
  {                              Prompt                     Field   Fld Hlp Val}
  {Range     Range     Prompt    Row Col Picture            Row Col Len Ndx Ptr}
  {Low       High      Decimals  Field                                         }

  SetProtectAttrs(BoxTextAttr, ESfieldAttr);
  SetProtection(On);
  AddByteField(ESR1,   'Record', 04, 17, '99',              04, 25,     0,
   0,        0,                  CurrentRec);  {** <-- not part of Scrap! **}
  SetProtection(Off);
  SetProtectAttrs(ESpromptAttr, ProtectAttr);
  AddStringField(ESR1, 'Name',   07, 19, '',                07, 25, 30, 1,  nil,
                                 Scrap.Name);

  SetRequired(On);
  AddStringField(ESR1, 'Address',08, 16, '',                08, 25, 30, 2,  nil,
                                 Scrap.Address);
  SetRequired(Off);

  SetInsertPushes(Off);
  AddStringField(ESR1, 'City',   09, 19, '',                09, 25, 25, 3,  nil,
                                 Scrap.City);
  SetInsertPushes(On);

  {$IFDEF UseMouse}
  SetExitOnSecondClick(On);
  {$ENDIF}
  AddStringField(ESR1, 'State',  10, 18, 'AA',              10, 25, 02, 4, @ValidateState,
                                 Scrap.State);
  {$IFDEF UseMouse}
  SetExitOnSecondClick(Off);
  {$ENDIF}

  AddStringField(ESR1, 'Zip',    10, 52, ZipMask,           10, 57, 10, 5, @ValidateZip,
                                 Scrap.Zip);

  AddNestedField(ESR1, 'Phones', 11, 17, '',                11, 25,  2, 6);

  {multiple-choice field}
  AddChoiceField(ESR1, 'Gender', 13, 17, 'XXXXXXX',         13, 25,     7,
   1,        @IncChoice,         Scrap.Gender);

  AddYesNoField(ESR1, 'Married', 13, 48, '',                13, 57,     8,
                                 Scrap.Married);
  AddDateField(ESR1, 'Born',     14, 19, DateMask,          14, 25,     9,
   0,        0,                  Scrap.Born);

  {a calculated field}
  SetProtection(On);
  AddByteField(ESR1, 'Age',      14, 52, '999',             14, 57,     10,
   0,        0,                  Scrap.Age);
  SetProtection(Off);

  {a numeric field}
  SetNumeric(On);
  AddRealField(ESR1, 'Hourly wage',16,12,WageMask,          16, 25,     11,
   0,        999.99,   0,        Scrap.Wage);
  SetNumeric(Off);

  {a calculated field}
  SetProtection(On);
  SetPadChar('*');
  AddRealField(ESR1, 'Weekly',   16, 49, CurrMask,          16, 57,     12,
   0,        0,        0,        Scrap.Weekly);
  SetPadChar(' ');
  SetProtection(Off);

  {multiple-choice field}
  AddChoiceField(ESR1, 'Hours/week',17,13,'99',             17, 25,     13,
   1,        @IncChoice,         Scrap.Hours);

  {a calculated field}
  SetProtection(On);
  SetPadChar('*');
  AddRealField(ESR1, 'Yearly',   17, 49, CurrMask,          17, 57,     14,
   0,        0,        0,        Scrap.Yearly);
  SetPadChar(' ');
  SetProtection(Off);

  AddNestedField(ESR1, 'Notes',  19, 18, '',                19, 25, 2,  15);

  {now set up the secondary edit screen}
  InitESrecord(ESR2);
  SetPreEditPtr(ESR2, @DisplayHelpPrompt2);
  SetErrorPtr(ESR2, @ErrorHandler);
  SetWrapMode(ESR2, ExitAtEdges);
  SetAutoAdvance(On);
  SetBeepOnError(ESR2, On);
  SetPadChar('_');
  SetPromptAttr(BoxTextAttr);
  AddStringField(ESR2, 'Work phone number', 13, 25, PhoneMask, 13, 43, 14, 16,
    @ValidatePhone, Scrap.WPhone);
  AddStringField(ESR2, 'Home phone number', 14, 25, PhoneMask, 14, 43, 14, 17,
    @ValidatePhone, Scrap.HPhone);
  SetPromptAttr(TextAttr);
  SetPadChar(' ');

  CurrentRec := 1;
  AllDone := False;
  repeat
    {copy the current record into the scrap record used for editing}
    Scrap := InfoRecs[CurrentRec];

    {reset the attributes for the Age and Wage fields}
    SetAgeFieldAttribute(ESR1);
    SetWageFieldAttribute(ESR1);

    {start editing}
    ExitCommand := EditScreen(ESR1, ESR1.CurrentID, False);

    if ExitCommand = ESquit then
      {confirm that the user wants to quit}
      if not ConfirmQuitting then
        ExitCommand := ESnone;

    {copy the edited record back if ESC wasn't pressed}
    if ExitCommand <> ESquit then
      InfoRecs[CurrentRec] := Scrap;

    {see if we need to edit another record}
    case ExitCommand of
      ESdone,                {^Enter, ^KD, or ^KQ}
      ESquit :               {ESC}
        AllDone := True;
      ESnextRec :            {next record}
        if CurrentRec < MaxRec then
          Inc(CurrentRec);
      ESprevRec :            {previous record}
        if CurrentRec > 1 then
          Dec(CurrentRec);
      ESuser0 :              {toggle Bell on/off}
        begin
          SetBeepOnError(ESR1, not ESR1.BeepOnError);
          SetBeepOnError(ESR2, not ESR2.BeepOnError);
        end;
      {$IFDEF UseMouse}
      ESclickExit,
      {$ENDIF}
      ESuser1 :              {pick a state}
        if ESR1.CurrentID = 4 then
          PickAState;
      ESnested :             {handle nested form}
        if ESR1.CurrentID = 15 then begin
          {edit the notes field}
          EditMemoField;

          {copy the notes field}
          InfoRecs[CurrentRec].Notes := Scrap.Notes;
        end
        {switch to secondary edit screen}
        else if SecondaryEditScreen then
          {advance to next field in main screen (Gender)}
          Inc(ESR1.CurrentID)
        else
          {back up to State field}
          Dec(ESR1.CurrentID, 2);
    end;
  until AllDone;

  {$IFDEF UseMouse}
  {hide the mouse cursor}
  HideMouse;
  {$ENDIF}

  {these calls are unnecessary in this case}
  DisposeEditScreen(ESR1);
  DisposeEditScreen(ESR2);
  DisposeWindow(WP1);
  DisposeWindow(WP2);

  {clean up display}
  NormVideo;
  ClrScr;
end.
