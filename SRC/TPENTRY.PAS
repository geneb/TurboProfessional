{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
  {$DEFINE FMinus}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{$I TPDEFINE.INC}
{.$N+}                       {enables support for 8087 reals}

{*********************************************************}
{*                   TPENTRY.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1988, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpEntry;
  {-Data entry routines}

interface

uses
  Dpmi, {!!.21}
  TpInline,
  TpMemChk,
  TpCrt,
  {$IFDEF UseMouse}
  TpMouse,
  {$ENDIF}
  TpCmd,
  TpString,
  {$IFDEF UseBCD}
  TpBcd,
  {$ENDIF}
  TpWindow,
  TpDate;

  {$I TPENTRY.IN0}           {Interfaced type declarations, constants, data}

  {-------main routines-------}

procedure InitESrecord(var ESR : ESrecord);
  {-Initialize an ESrecord}

procedure DrawEditScreen(var ESR : ESrecord);
  {-Redraw an entire edit screen}

function EditScreen(var ESR : ESrecord; StartField : Word; ReadOnly : Boolean) : EStype;
  {-Edit fields until an exit command is issued}

procedure EditString(Prompt : string; {edit prompt}
                     Row, Col : Byte; {coordinates for prompt}
                     EditLen : Byte; {width of edit field}
                     Picture : string; {edit mask}
                     HelpIndex : Word; {index to pass to help routine}
                     var Escaped : Boolean; {True if ESquit command given}
                     var EditSt : string); {string to edit}
  {-Use one of the field editors to edit a string. If Picture contains
    '$' or ',', numeric mode is selected automatically unless IncludeNumeric
    is unDEFINEd, in which case the program is aborted. In numeric mode,
    Picture characters are stripped from the string before it is returned.}

procedure DisposeEditScreen(var ESR : ESrecord);
  {-Deallocate all field records associated with ESR}

  {-------routines for adding fields-------}

procedure AddStringField(var ESR : ESrecord; {the edit screen to add to}
                         Prompt : string; {edit prompt}
                         pRow, pCol : Word; {coordinates for prompt}
                         Picture : string; {edit mask}
                         eRow, eCol : Word; {coordinates for edit field}
                         EditLen : Byte; {width of edit field}
                         HelpIndex : Word; {index to pass to help routine}
                         Validation : Pointer; {pointer to validation routine}
                         var EditSt : string); {string to edit}
  {-Add a field of type string}

procedure AddArrayField(var ESR : ESrecord; {the edit screen to add to}
                        Prompt : string; {edit prompt}
                        pRow, pCol : Word; {coordinates for prompt}
                        Picture : string; {edit mask}
                        eRow, eCol : Word; {coordinates for edit field}
                        EditLen : Byte; {width of edit field}
                        HelpIndex : Word; {index to pass to help routine}
                        Validation : Pointer; {pointer to validation routine}
                        var EditVar); {array to edit}
  {-Add a field of type array (of char)}

procedure AddCharField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       CharLo : Char; {lowest char}
                       CharHi : Char; {highest char}
                       var EditChar : Char); {char to edit}
  {-Add a field of type char}

procedure AddBooleanField(var ESR : ESrecord; {the edit screen to add to}
                          Prompt : string; {edit prompt}
                          pRow, pCol : Word; {coordinates for prompt}
                          Picture : string; {edit mask}
                          eRow, eCol : Word; {coordinates for edit field}
                          HelpIndex : Word; {index to pass to help routine}
                          var EditBool : Boolean); {boolean to edit}
  {-Add a field of type boolean}

procedure AddYesNoField(var ESR : ESrecord; {the edit screen to add to}
                        Prompt : string; {edit prompt}
                        pRow, pCol : Word; {coordinates for prompt}
                        Picture : string; {edit mask}
                        eRow, eCol : Word; {coordinates for edit field}
                        HelpIndex : Word; {index to pass to help routine}
                        var EditYesNo : Boolean); {boolean to edit}
  {-Add a field of type yes/no}

procedure AddLongField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       LongLo : LongInt; {low value}
                       LongHi : LongInt; {high value}
                       var EditLong : LongInt); {longint to edit}
  {-Add a field of type LongInt}

procedure AddWordField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       WordLo : Word; {low value}
                       WordHi : Word; {high value}
                       var EditWord : Word); {word to edit}
  {-Add a field of type word}

procedure AddIntField(var ESR : ESrecord; {the edit screen to add to}
                      Prompt : string; {edit prompt}
                      pRow, pCol : Word; {coordinates for prompt}
                      Picture : string; {edit mask}
                      eRow, eCol : Word; {coordinates for edit field}
                      HelpIndex : Word; {index to pass to help routine}
                      IntLo : Integer; {low value}
                      IntHi : Integer; {high value}
                      var EditInt : Integer); {integer to edit}
  {-Add a field of type integer}

procedure AddByteField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       ByteLo : Byte; {low value}
                       ByteHi : Byte; {high value}
                       var EditByte : Byte); {byte to edit}
  {-Add a field of type byte}

procedure AddShortField(var ESR : ESrecord; {the edit screen to add to}
                        Prompt : string; {edit prompt}
                        pRow, pCol : Word; {coordinates for prompt}
                        Picture : string; {edit mask}
                        eRow, eCol : Word; {coordinates for edit field}
                        HelpIndex : Word; {index to pass to help routine}
                        ShortLo : ShortInt; {low value}
                        ShortHi : ShortInt; {high value}
                        var EditShort : ShortInt); {shortint to edit}
  {-Add a field of type shortint}

procedure AddRealField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       RealLo : Real; {low value}
                       RealHi : Real; {high value}
                       Places : Byte; {max decimal places}
                       var EditReal : Real); {real to edit}
  {-Add a field of type real}

  {$IFDEF UseBCD}

procedure AddBcdField(var ESR : ESrecord; {the edit screen to add to}
                      Prompt : string;    {edit prompt}
                      pRow, pCol : Word;  {coordinates for prompt}
                      Picture : string;   {edit mask}
                      eRow, eCol : Word;  {coordinates for edit field}
                      HelpIndex : Word;   {index to pass to help routine}
                      BcdLo : BCD;        {low value}
                      BcdHi : BCD;        {high value}
                      Places : Byte;      {max decimal places}
                      var EditBcd : BCD); {BCD to edit}
  {-Add a field of type BCD}

{$ENDIF}

  {$IFOPT N+}

procedure AddExtField(var ESR : ESrecord;      {the edit screen to add to}
                      Prompt : string;         {edit prompt}
                      pRow, pCol : Word;       {coordinates for prompt}
                      Picture : string;        {edit mask}
                      eRow, eCol : Word;       {coordinates for edit field}
                      HelpIndex : Word;        {index to pass to help routine}
                      ExtLo : Extended;        {low value}
                      ExtHi : Extended;        {high value}
                      Places : Byte;           {max decimal places}
                      var EditExt : Extended); {extended to edit}
  {-Add a field of type extended}

procedure AddDblField(var ESR : ESrecord;    {the edit screen to add to}
                      Prompt : string;       {edit prompt}
                      pRow, pCol : Word;     {coordinates for prompt}
                      Picture : string;      {edit mask}
                      eRow, eCol : Word;     {coordinates for edit field}
                      HelpIndex : Word;      {index to pass to help routine}
                      DblLo : Double;        {low value}
                      DblHi : Double;        {high value}
                      Places : Byte;         {max decimal places}
                      var EditDbl : Double); {double to edit}
  {-Add a field of type double}

procedure AddSglField(var ESR : ESrecord;    {the edit screen to add to}
                      Prompt : string;       {edit prompt}
                      pRow, pCol : Word;     {coordinates for prompt}
                      Picture : string;      {edit mask}
                      eRow, eCol : Word;     {coordinates for edit field}
                      HelpIndex : Word;      {index to pass to help routine}
                      SglLo : Single;        {low value}
                      SglHi : Single;        {high value}
                      Places : Byte;         {max decimal places}
                      var EditSgl : Single); {single to edit}
  {-Add a field of type single}

procedure AddCompField(var ESR : ESrecord;   {the edit screen to add to}
                       Prompt : string;      {edit prompt}
                       pRow, pCol : Word;    {coordinates for prompt}
                       Picture : string;     {edit mask}
                       eRow, eCol : Word;    {coordinates for edit field}
                       HelpIndex : Word;     {index to pass to help routine}
                       CompLo : Comp;        {low value}
                       CompHi : Comp;        {high value}
                       var EditComp : Comp); {comp to edit}
  {-Add a field of type comp}

{$ENDIF}

procedure AddDateField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : DateString; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       DateLo : Date; {low value}
                       DateHi : Date; {high value}
                       var EditDate : Date); {date to edit}
  {-Add an edit field of type date}

procedure AddDateStField(var ESR : ESrecord; {the edit screen to add to}
                         Prompt : string; {edit prompt}
                         pRow, pCol : Word; {coordinates for prompt}
                         Picture : DateString; {edit mask}
                         eRow, eCol : Word; {coordinates for edit field}
                         HelpIndex : Word; {index to pass to help routine}
                         var EditDate : DateString); {date string to edit}
  {-Add an edit field of type date string}

procedure AddTimeField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : DateString; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       TimeLo : Time; {low value}
                       TimeHi : Time; {high value}
                       var EditTime : Time); {time variable to edit}
  {-Add an edit field of type time}

procedure AddUserField(var ESR : ESrecord; {the edit screen to add to}
                       Prompt : string; {edit prompt}
                       pRow, pCol : Word; {coordinates for prompt}
                       Picture : string; {edit mask}
                       eRow, eCol : Word; {coordinates for edit field}
                       EditLen : Byte; {width of edit field}
                       HelpIndex : Word; {index to pass to help routine}
                       Validation : Pointer; {pointer to validation routine}
                       Conversion : Pointer; {pointer to conversion routine}
                       UserPtr1 : Pointer; {pointers to user-defined data}
                       UserPtr2 : Pointer; {    structures (optional)    }
                       var EditVar); {variable to edit}
  {-Add a field of a user-defined type}

procedure AddNestedField(var ESR : ESrecord; {the edit screen to add to}
                         Prompt : string; {edit prompt}
                         pRow, pCol : Word; {coordinates for prompt}
                         Picture : string; {edit mask}
                         eRow, eCol : Word; {coordinates for edit field}
                         EditLen : Byte; {width of edit field}
                         HelpIndex : Word); {index to pass to help routine}
  {-Add a field that is associated with a nested form}

  {$IFDEF IncludeChoice}
procedure AddChoiceField(var ESR : ESrecord; {the edit screen to add to}
                         Prompt : string; {edit prompt}
                         pRow, pCol : Word; {coordinates for prompt}
                         Picture : string; {edit mask}
                         eRow, eCol : Word; {coordinates for edit field}
                         HelpIndex : Word; {index to pass to help routine}
                         DataSize : Byte; {size of the data type}
                         Increment : Pointer; {pointer to incrementing routine}
                         var EditVar); {variable to edit}
  {-Add a multiple choice field}
  {$ENDIF}

  {-------option settings for edit screen records-------}

procedure SetWrapMode(var ESR : ESrecord; WrapMode : WrapModeType);
  {-Select the wrap mode for an edit screen}

procedure SetEntryWindow(var ESR : ESrecord; XLow, YLow, XHigh, YHigh : Byte;
                         Framed : Boolean; BackAttr, FrameAttr : Byte);
  {-Set coordinates and background color for a data entry window}

procedure SetBeepOnError(var ESR : ESrecord; On : Boolean);
  {-Beep when illegal char entered?}

procedure SetDelimiters(var ESR : ESrecord;
                        Left, Right : Char;
                        FieldAttr : Byte;
                        SelectAttr : Byte);
  {-Set field delimiters for the edit screen (null = none)}

procedure SetPreEditPtr(var ESR : ESrecord; P : Pointer);
  {-Pointer to routine to display help message just before field is edited}

procedure SetPostEditPtr(var ESR : ESrecord; P : Pointer);
  {-Set pointer to routine to call after each edit}

procedure SetErrorPtr(var ESR : ESrecord; P : Pointer);
  {-Set pointer to routine to call after error}

procedure SetUpdatePtr(var ESR : ESrecord; P : Pointer);
  {-Set pointer to routine to call after entry screen redrawn}

procedure SetAllFieldLinks(var ESR : ESrecord; var LinksMap);
  {-Set the forward and backward links for all fields in an entry screen}

  {-------option settings for individual fields-------}

procedure SetPromptAttr(A : Byte);
  {-Set prompt attribute}

procedure SetFieldAttr(A : Byte);
  {-Set field attribute (attribute when field is not selected)}

procedure SetStringAttr(A : Byte);
  {-Set string attribute (attribute when field IS selected)}

procedure SetCtrlAttr(A : Byte);
  {-Set attribute for control characters}

procedure SetProtectAttrs(PromptA, FieldA : Byte);
  {-Set prompt and field attributes for protected fields}

  {$IFDEF IncludeNumeric}
procedure SetNumeric(On : Boolean);
  {-Activate/deactivate use of numeric (right-left) editor}
  {$ENDIF}

procedure SetAutoAdvance(On : Boolean);
  {-Turn AutoAdvance on/off}

procedure SetCursorToEnd(On : Boolean);
  {-Turn CursorToEnd on/off}

procedure SetTrimBlanks(On : Boolean);
  {-Turn blank trimming on/off}

procedure SetRightJustify(On : Boolean);
  {-Turn right justification on/off}

procedure SetPadChar(Ch : Char);
  {-Set character used to pad ends of strings}

procedure SetClearFirstChar(On : Boolean);
  {-Turn ClearFirstChar on/off}

procedure SetInsertPushes(On : Boolean);
  {-Turn InsertPushes flag on/off}

procedure SetAutoNumLock(On : Boolean);
  {-Turn AutoNumLock on/off}

procedure SetRequired(On : Boolean);
  {-Turn required field flag on/off}

procedure SetPasswordMode(On : Boolean);
  {-Turn password mode on/off}

procedure SetProtection(On : Boolean);
  {-Turn protection on/off}

procedure SetForceMode(Force, Overtype : Boolean);
  {-Force insert or overtype mode, else use previous setting}

  {$IFDEF UseMouse}
procedure SetExitOnSecondClick(On : Boolean);
  {-Allow double-clicking on a field to produce the ESclickExit exit command?}
  {$ENDIF}

procedure SetFieldLinks(var ESR : ESrecord; FieldID, Next, Prev : Word);
  {-Specify the fields to jump to when <Enter> or <ShTab> pressed on a given
    field}

  {-------miscellaneous routines-------}

  {$IFDEF UseMouse}
procedure EnableEntryMouse;
  {-Enable mouse support in TPENTRY}

procedure DisableEntryMouse;
  {-Disable mouse support in TPENTRY}
  {$ENDIF}

procedure ClearEntryWindow(var ESR : ESrecord);
  {-Clear the window for the entry screen}

procedure SetBell(Pitch, Duration : Word);
  {-Set pitch and duration for bell}

procedure SetPasswordChar(C : Char);
  {-Set character used in password mode}

procedure RingBell;
  {-Ring the bell}

procedure ChangeProtection(var ESR : ESrecord; FieldID : Word; OnOff : Boolean);
  {-Modify the protection status of a field.}

procedure ChangeProtectionFast(var ESR : ESrecord;
                               FieldID : Word;
                               OnOff : Boolean);
  {-Modify the protection status of a field. Must be used in conjunction with
    ResetEntryScreenFlags}

procedure ResetEntryScreenFlags(var ESR : ESrecord);
  {-Flags the first/last rows in the entry screen. Needs to be called only if
    ChangeProtectionFast is used.}

function CurrentFieldModified(var ESR : ESrecord) : Boolean;
  {-Return True if current field was modified. Call only from within a
    post-edit routine.}

procedure ChangeRequired(var ESR : ESrecord; FieldID : Word; OnOff : Boolean);
  {-Modify the required status of a field after it has been added}

procedure ChangeValidation(var ESR  : ESrecord;
                           FieldID  : Word;
                           Validate : Pointer);
  {-Change the validation routine for the specified field}

procedure ChangePromptAttr(var ESR : ESrecord; FieldID : Word; A : Byte);
  {-Change the prompt attribute for the specified field}

procedure ChangeFieldAttr(var ESR : ESrecord; FieldID : Word; A : Byte);
  {-Change the field attribute for the specified field}

procedure ChangeStringAttr(var ESR : ESrecord; FieldID : Word; A : Byte);
  {-Change the string attribute for the specified field}

function AddEntryCommand(Cmd : EStype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

function InternationalCurrency(FormChar : Char; MaxDigits : Byte;
                               FloatIfPossible : Boolean;
                               AddCommas : Boolean) : string;
  {-Return a picture mask for a currency string, based on DOS's country info}

function EvaluateESCommand(var ESR : ESrecord; ESC : EStype) : FieldRecPtr;
  {-Given a command, return a pointer to the field the cursor will move to
    next. This routine is intended to be called only from within a post-edit
    routine!}

  {-------low-level routines-------}

procedure DrawField(var ESR : ESrecord; FieldID : Word);
  {-Draw the edit field corresponding to FieldID}

procedure InitPictureFlags(var Picture : string; var PFlags : PictureFlags);
  {-Initialize a picture flags table}

procedure MergePicture(Picture, St : string; var S : string; EditFlags : Word);
  {-Merge St with Picture and return result in S}

procedure MergePictureReal(Picture, St : string; var S : string; {!!.09}
                           EditFlags : Word);
  {-Merge St with Picture and return result in S--for real fields only}

procedure StripPicture(var Picture, EditSt, S : string);
  {-Strip picture characters out of EditSt and return in S}

procedure AddFieldPrim(var ESR : ESrecord;
                       var FR : FieldRec;
                       var PictureSt : string;
                       var PromptSt : string);
  {-Low level routine to allocate and finish initializing a FieldRec}

function FindFieldID(var ESR : ESrecord; FieldID : Word) : FieldRecPtr;
  {-Return a pointer to the FieldRec with the specified ID, or nil if not found}

function ValidateSubfields(SubfieldMask : string;
                           var FR : FieldRec;
                           var ErrCode : Byte;
                           var ErrorSt : StringPtr) : Boolean;
  {-Validate that subfields in a string meet the requirements of SubfieldMask.
    Note: This is NOT a regular validation routine. It should be called only
    by a higher-level validation routine that has a SubfieldMask to give it.}

function ValidateNoBlanks(var FR : FieldRec;
                          var ErrCode : Byte;
                          var ErrorSt : StringPtr) : Boolean;
  {-Validate that no usable subfields in a string contain spaces}

function ValidateNotPartial(var FR : FieldRec;
                            var ErrCode : Byte;
                            var ErrorSt : StringPtr) : Boolean;
  {-Validate that no usable subfields in a string contain spaces unless all do}

{$IFDEF TpEntryScrolls}
function EntryScrollCheck(var ESR : ESrecord) : Boolean;
  {-Determine if window is scrollable. If so, allocate and initialize virtual
    screen. Returns False only in case of insufficient memory}

procedure CopyVirtualScreenToWindow(var ESR : ESrecord);
  {-Copy the virtual screen to the edit window}
{$ENDIF}

  {==========================================================================}

implementation

  {.F-}
const
  MaxFields         = 2000;  {max number of fields in an edit screen}
  MaxFieldRow       = 255;   {maximum row value}
  MaxFieldCol       = 255;   {maximum column value}
  ValidESRsig       = $2B32; {magic value}
const
  InvalidFormat     : string[22] = 'Invalid number format.';
const
  OutOfRange        : string[23] = 'Number is out of range.';
const
  TooManyFields     : string[21] = 'Too many edit fields.';
const
  BlanksErrorMsg    : string[30] = 'Blank spaces not allowed here.';
const
  PartialErrorMsg   : string[33] = 'Partial entries not allowed here.';
const
  BadCharMsg        : string[26] = 'Illegal character entered.';
const
  InsufficientMemory : string[19] = 'Insufficient memory';
const
  NullMsgLen        : Byte = 0;
var
  NullErrorMsg      : string absolute NullMsgLen;
  ESvalidatePtr     : Pointer;
  ESconvertPtr      : Pointer;
  ESpostEditPtr     : Pointer;
  ESerrorPtr        : Pointer;
  ESpreEditPtr      : Pointer;
  {$IFDEF IncludeChoice}
  ESchoicePtr       : Pointer;
  {$ENDIF}

  {$I TPENTRY.IN1}           {Validation/conversion routines, misc.}
  {$I TPENTRY.IN2}           {Routines to add fields, misc.}
  {$I TPENTRY.IN3}           {Field editors}

  procedure InitESrecord(var ESR : ESrecord);
    {-Initialize an ESrecord}
  begin
    FillChar(ESR, SizeOf(ESR), 0);
    ESR.Signature := ValidESRsig;

    {default to entire screen as window}
    ESR.YH := ScreenHeight-1;
    ESR.XH := ScreenWidth-1;

    {$IFDEF TpEntryScrolls}
      {need to check for scrolling}
      ESR.WindowScrolls := -1;
    {$ENDIF}

    {use TextAttr as filler}
    ESR.BackAttr := TextAttr;
  end;

  procedure ClearEntryWindow(var ESR : ESrecord);
    {-Clear the window for the entry screen}
  var
    SaveScroll : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    with ESR do begin
      {set up for scroll}
      SaveScroll := BiosScroll;
      BiosScroll := False;
      ExchangeBytes(TextAttr, BackAttr);

      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      {scroll the window}
      ScrollWindowUp(XL+1, YL+1, XH+1, YH+1, 0);

      {$IFDEF UseMouse}
      ShowMousePrim(SaveMouse);
      {$ENDIF}

      {restore previous settings}
      ExchangeBytes(TextAttr, BackAttr);
      BiosScroll := SaveScroll;
    end;
  end;

  function OnScreen(var ESR : ESrecord;
                    Row, Col : Integer;
                    Width : Byte) : Boolean;
    {-Return true if field of specified coordinates/width is on screen}
  begin
    with ESR do
      if (Row < Succ(YL)) or
         (Row > Succ(YH)) or
         (Col < Succ(XL)) or
         (Col+Width-1 > Succ(XH)) then
       OnScreen := False
      else
       OnScreen := True;
  end;

  procedure DrawFieldPrim(var ESR : ESrecord;
                          FRP : FieldRecPtr;
                          Convert : Boolean);
    {-Redraw the specified field}
  var
    Attr, CAttr : Byte;
    Row, Col : Word;
    PFlags : PictureFlags;
    LD, HD : Byte;  {!!.08}
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    with ESR, FRP^ do begin
      {adjust coordinates}
      Row := eRow;
      Col := eCol;
      HD := Ord((LeftD <> #0) and (RightD <> #0));
      LD := Byte( (HD = 1) and (Col > 1) );                    {!!.08}

      if VirtualSegment = VideoSegment then begin
        FixCoordinates(ESR, Row, Col);

        {exit if this field is not currently on the screen}
        if not OnScreen(ESR, Row, Col-LD, EditLen-1+HD+HD) then  {!!.08}
          Exit;
      end;

      if Convert then begin
        {do the conversion}
        ESconvertPtr := ConvertPtr;
        ConversionRoutine(FRP^, False);
      end;

      {$IFDEF UseMouse}
      if VirtualSegment = VideoSegment then
        HideMousePrim(SaveMouse);
      {$ENDIF}

        {draw field delimiters if desired}
        if (HD = 1) then begin
          {hide field delimiters if the whole field is hidden}
          if FieldIsProtected(FRP) and (SwapNibble(PrFieldAttr) = PrFieldAttr) then
            Attr := PrFieldAttr
          else if CurrentID = FieldID then
            Attr := AttrDS
          else
            Attr := AttrD;
          if LD = 1 then                       {!!.08}
            FastWrite(LeftD, Row, Col-1, Attr);
          FastWrite(RightD, Row, Col+EditLen, Attr);
        end;

      {set up for DrawEditString}
      InitPictureFlags(Picture^, PFlags);

      {draw the string}
      if FieldIsProtected(FRP) then begin
        Attr := prFieldAttr;
        CAttr := prFieldAttr;
      end
      else begin
        Attr := FieldAttr;
        CAttr := CtrlAttr;
      end;
      DrawEditString(Pad(EditSt^, EditLen), Row, Col, EditLen, 0, Attr,
        CAttr, PadChar, EditFlags, Picture^, PFlags);

      {$IFDEF UseMouse}
      if VirtualSegment = VideoSegment then
        ShowMousePrim(SaveMouse);
      {$ENDIF}
    end;
  end;

  procedure DrawKnownField(var ESR : ESrecord; FRP : FieldRecPtr);
    {-Draw a field when the FieldRecPtr is known}
  var
    A : Byte;
    Row, Col : Word;
    VirtualWrite : Boolean;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    if FRP <> nil then
      with ESR, FRP^ do begin
        {writing to a virtual screen?}
        VirtualWrite := VirtualSegment <> VideoSegment;

        {adjust coordinates if desired}
        Row := pRow;
        Col := pCol;
        if not VirtualWrite then
          FixCoordinates(ESR, Row, Col);

        {$IFDEF UseMouse}
        if not VirtualWrite then
          HideMousePrim(SaveMouse);
        {$ENDIF}

        if FieldIsProtected(FRP) then
          A := prPromptAttr
        else
          A := PromptAttr;

        {draw the prompt}
        if VirtualWrite or OnScreen(ESR, Row, Col, Length(Prompt^)) then {!!}
          FastWrite(Prompt^, Row, Col, A);

        {draw the string being edited}
        DrawFieldPrim(ESR, FRP, True);

        {$IFDEF UseMouse}
        if not VirtualWrite then
          ShowMousePrim(SaveMouse);
        {$ENDIF}
      end;
  end;

  procedure DrawField(var ESR : ESrecord; FieldID : Word);
    {-Draw the field corresponding to FieldID}
  var
    FRP : FieldRecPtr;
  begin
    with ESR do begin
      {find the field}
      FRP := FindFieldID(ESR, FieldID);

      with ESR do begin
        {$IFDEF TpEntryScrolls}
          {need to check for scrolling}
          if (WindowScrolls = 1) and (VirtualSegment = VideoSegment) then begin
            {switch to the virtual screen}
            ActivateVScreen(VS);

            {draw the field on the virtual screen}
            DrawKnownField(ESR, FRP);

            {switch to the physical screen}
            DeactivateVScreen;
          end;

          {draw the field on the physical screen}
          DrawKnownField(ESR, FRP);
        {$ELSE}
          {draw the field on the physical screen}
          DrawKnownField(ESR, FRP);
        {$ENDIF}
      end;
    end;
  end;

  {$IFDEF TpEntryScrolls}
  procedure CopyVirtualScreenToWindow(var ESR : ESrecord);
    {-Copy the virtual screen to the edit window}
  type
    XY = record
           X, Y : Byte;
         end;
  var
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
    SaveWindMin : Word;
    SaveWindMax : Word;
  begin
    {$IFDEF UseMouse}
    HideMousePrim(SaveMouse);
    {$ENDIF}

    with ESR do begin
      {save/reset current window coordinates}
      SaveWindMin := WindMin;
      SaveWindMax := WindMax;
      XY(WindMin).X := XL;
      XY(WindMin).Y := YL;
      XY(WindMax).X := XH;
      XY(WindMax).Y := YH;

      {copy the virtual screen to the edit window}
      MoveVScreenToWindow(VS, Succ(RowOffset), Succ(ColOffset));

      {restore current window coordinates}
      WindMin := SaveWindMin;
      WindMax := SaveWindMax;
    end;

    {$IFDEF UseMouse}
    ShowMousePrim(SaveMouse);
    {$ENDIF}
  end;

  procedure FixEditWindow(var ESR : ESrecord; Redraw, ScrollByPage : Boolean);
    {-Fix the edit window if necessary}
  var
    FRP : FieldRecPtr;
    Scrolled : Boolean;
    RowAtTop : Integer;
    RowAtBottom : Integer;
    ColAtLeft : Integer;
    ColAtRight : Integer;
    LCol : Integer;
    HCol : Integer;
    Width1 : Word;
    HavePrompt : Boolean;
    TargetRow : Integer;
    SaveRowOffset : Integer;

    procedure ScrollRight(Cols : Integer);
    begin
      if Cols <> 0 then begin
        Scrolled := True;
        with ESR do begin
          {make sure we don't scroll too far}
          if Cols < -ColOffset then
            ColOffset := 0
          else
            Inc(ColOffset, Cols);
        end;
      end;
    end;

    procedure ScrollDown(Rows : Integer);
    var
      WHeight : Integer;
      StartOfLastPage : Word;
      NewRowAtBottom : Integer; {!!.10}
    begin
      if Rows <> 0 then
        with ESR do begin
          WHeight := Succ(YH-YL);
          StartOfLastPage := VS.VRows-Pred(WHeight);
          if ScrollByPage then
            {round to nearest page boundary}
            RowOffset := (Pred(TargetRow) div WHeight) * WHeight
          else
            Inc(RowOffset, Rows);

          {make sure we don't scroll too far}
          if RowOffset < 0 then
            RowOffset := 0
          else if RowOffset >= StartOfLastPage then
            {make sure end of last page is displayed at bottom of window}
            RowOffset := Pred(StartOfLastPage)
          else if RowOffset > Pred(TargetRow) then
            if (TargetRow >= RowAtTop) and (TargetRow <= RowAtBottom) then
              RowOffset := SaveRowOffset
            else
              RowOffset := Pred(TargetRow);

          {make sure we scroll far enough}               {!!.10}
          NewRowAtBottom := Succ(RowOffset)+(YH-YL);     {!!.10}
          if TargetRow > NewRowAtBottom then             {!!.10}
            Inc(RowOffset, TargetRow - NewRowAtBottom);  {!!.10}
        end;
    end;

  begin
    {exit if the window isn't scrollable}
    if ESR.WindowScrolls <> 1 then
      Exit;

    FRP := FindFieldID(ESR, ESR.CurrentID);
    with ESR, VS, FRP^ do begin
      SaveRowOffset := RowOffset;
      RowAtTop := Succ(RowOffset);
      RowAtBottom := RowAtTop+(YH-YL);
      Width1 := (XH-XL);
      ColAtLeft := Succ(ColOffset);
      ColAtRight := ColAtLeft+Width1;
      TargetRow := eRow;

      {figure out which columns we need displayed}
      HavePrompt := Length(Prompt^) <> 0;
      if eCol > 1 then                                     {!!.08}
        LCol := eCol-Ord((LeftD <> #0) and (RightD <> #0)) {!!.08}
      else                                                 {!!.08}
        LCol := eCol;                                      {!!.08}
      HCol := eCol+Pred(EditLen)+Ord((LeftD <> #0) and (RightD <> #0));
      if HavePrompt then
        {try to get both the prompt and the edit field on screen at once}
        if (Integer(HCol)-pCol) <= Integer(Width1) then
          LCol := pCol;

      {scroll the window vertically if necessary}            {!!.10 ---------------------}
      if FlagIsSet(XFlags, FirstRowMask) and (RowOffset > 0) and (TargetRow < Succ(YH-YL)) then
        {force original alignment if this row has first unprotected field}
        ScrollDown(-RowOffset)
      else if FlagIsSet(XFlags, LastRowMask) and (VRows > RowAtBottom) then
        {force last row to be displayed if this row has last unprotected field}
        ScrollDown(VRows-RowAtBottom)
      else if TargetRow < RowAtTop then
        {scroll window to allow hidden field to be displayed}
        ScrollDown(TargetRow-RowAtTop)
      else if TargetRow > RowAtBottom then
        {scroll window to allow hidden field to be displayed}
        ScrollDown(TargetRow-RowAtBottom)
      else if HavePrompt and (pRow < RowAtTop) and not ScrollByPage then
        {scroll window to allow prompt for field to be displayed}
        ScrollDown(Integer(pRow)-RowAtTop);
      Scrolled := (RowOffset <> SaveRowOffset);

      {force original alignment horizontally if appropriate}          {!!.10}
      if (LCol <= FirstField^.eCol) and (Width1 >= HCol-1) then begin {!!.10}
        ScrollRight(-ColOffset);                                      {!!.10}
        ColAtLeft := Succ(ColOffset);                                 {!!.10}
      end;                                                            {!!.10}

      {scroll the window horizontally if necessary}
      if LCol < ColAtLeft then
        {force leftmost column to be displayed at left edge of window}
        ScrollRight(LCol-ColAtLeft)
      else if HCol > ColAtRight then
        {make sure rightmost column is in view}
        ScrollRight(HCol-ColAtRight);

      if Redraw and Scrolled then
        {copy the virtual screen to the edit window}
        CopyVirtualScreenToWindow(ESR);
    end;
  end;

  function EntryScrollCheck(var ESR : ESrecord) : Boolean;
    {-Determine if window is scrollable. If so, allocate and initialize virtual
      screen. Returns False only in case of insufficient memory}
  var
    HighRow, HighCol : Word;
    FRP : FieldRecPtr;
  begin
    EntryScrollCheck := True;
    with ESR do begin
      {do this only once}
      if WindowScrolls <> -1 then
        Exit
      else
        WindowScrolls := 0;

      {scan the linked list looking for the extreme bounds of the edit screen}
      HighRow := 0;
      HighCol := 0;
      FRP := FirstField;
      while FRP <> nil do
        with FRP^ do begin
          {check prompt}
          if Length(Prompt^) <> 0 then begin
            HighRow := MaxWord(HighRow, pRow);
            HighCol := MaxWord(HighCol, pCol+Length(Prompt^)-1);
          end;

          {check edit field}
          HighRow := MaxWord(HighRow, eRow);
          HighCol := MaxWord(HighCol, eCol+EditLen-1+Ord((LeftD <> #0) and (RightD <> #0)));

          {follow link}
          FRP := FRP^.NextField;
        end;

      {see if anything is outside the bounds of the window}
      if (HighRow > Succ(YH-YL)) or (HighCol > Succ(XH-XL)) then begin
        WindowScrolls := 1;

        {try to allocate the virtual screen}
        if not MakeVScreen(VS, HighRow, HighCol) then begin
          EntryScrollCheck := False;
          Exit;
        end;

        {clear the virtual screen}
        ClearVScreen(VS, BackAttr, ' ');
      end;
    end;
  end;

  procedure UpdateVScreen(var ESR : ESrecord; FRP : FieldRecPtr);
    {-Update a virtual screen after an edit}
  begin
    with ESR do begin
      {switch to the virtual screen}
      ActivateVScreen(VS);

      {redraw the specified field on the virtual screen}
      DrawFieldPrim(ESR, FRP, False);

      {switch to the physical screen}
      DeactivateVScreen;
    end;
  end;
  {$ENDIF}

  procedure DrawEditScreen(var ESR : ESrecord);
    {-Redraw an entire edit screen}
  var
    FRP : FieldRecPtr;
    SaveCurrentID : Word;
    {$IFDEF UseMouse}
    SaveMouse : Boolean;
    {$ENDIF}
  begin
    with ESR do begin
      {$IFDEF UseMouse}
      HideMousePrim(SaveMouse);
      {$ENDIF}

      {draw frame if desired}
      if Framed then begin
        ExchangeStructs(FrameChars, Frame, SizeOf(FrameArray));
        FrameWindow(XL, YL, XH+2, YH+2, FrameAttr, FrameAttr, '');
        ExchangeStructs(Frame, FrameChars, SizeOf(FrameArray));
      end;

      {$IFDEF TpEntryScrolls}
      {determine if window is scrollable}
      if WindowScrolls = -1 then
        if not EntryScrollCheck(ESR) then
          FatalError(ESR, MemoryError, InsufficientMemory);
      {$ENDIF}

      {$IFDEF TpEntryScrolls}
      {switch to virtual screen}
      if WindowScrolls = 1 then
        ActivateVScreen(VS);
      {$ENDIF}

      {$IFDEF UseMouse}
      if VirtualSegment <> VideoSegment then
        ShowMousePrim(SaveMouse);
      {$ENDIF}

      {draw all the fields}
      SaveCurrentID := CurrentID;
      CurrentID := MaxFields;
      FRP := FirstField;
      while FRP <> nil do begin
        DrawKnownField(ESR, FRP);
        FRP := FRP^.NextField;
      end;
      CurrentID := SaveCurrentID;

      if UpdatePtr <> nil then begin
        ESpostEditPtr := UpdatePtr;
        ScreenUpdateRoutine(ESR);
      end;

      {$IFDEF UseMouse}
      if VirtualSegment = VideoSegment then
        ShowMousePrim(SaveMouse);
      {$ENDIF}

      {$IFDEF TpEntryScrolls}
      if WindowScrolls = 1 then begin
        {make sure the current field is on the screen}
        FixEditWindow(ESR, False, ScrollByPage);

        {switch to physical screen}
        DeactivateVScreen;

        {copy virtual screen to physical screen}
        CopyVirtualScreenToWindow(ESR);
      end;
      {$ENDIF}
    end;
  end;

  function EditScreen(var ESR : ESrecord; StartField : Word; ReadOnly : Boolean) : EStype;
    {-Edit fields until an exit command is issued}
  const
    ReqErrorMsg : string[18] = 'Field is required.';
  var
    ESC : EStype absolute LastEntryCommand;
    SaveESC : EStype;
    FRP : FieldRecPtr;
    I, J : Word;
    Done, OK : Boolean;
    PosCode : Byte;
    Row, Col : Word;
    {$IFDEF UseMouse}
    SaveMX : Byte;
    SaveMY : Byte;
    SaveMXL : Byte;
    SaveMXH : Byte;
    SaveMYL : Byte;
    SaveMYH : Byte;
    SaveMouse : Boolean;
    {$ENDIF}
  label
    Retry1, Retry2, TopOfLoop;

    function IDisValid(ID : Word) : Boolean;
      {-Return True if ID is a valid ID number for an unprotected field}
    var
      FRP : FieldRecPtr;
    begin
      if ID = BadFieldID then
        IDisValid := False
      else begin
        FRP := FindFieldID(ESR, ID);
        IDisValid := (FRP <> nil) and not FieldIsProtected(FRP);
      end;
    end;

    procedure SeekToFirst;
      {-Move to first unprotected field}
    begin
      with ESR do begin
        CurrentField := FirstField;
        while FieldIsProtected(CurrentField) do
          CurrentField := CurrentField^.NextField;
      end;
    end;

    procedure SeekToLast;
      {-Move to last unprotected field}
    begin
      with ESR do begin
        CurrentField := LastField;
        while FieldIsProtected(CurrentField) do
          CurrentField := CurrentField^.PrevField;
      end;
    end;

    procedure WrapAtTop;
      {-Deal with wrap at top of edit screen}
    begin
      case ESR.WrapMode of
        WrapAtEdges :
          SeekToLast;
        ExitAtEdges :
          begin
            ESC := ESprevRec;
            Done := True;
          end;
        StopAtEdges :
          {do nothing} ;
      end;
    end;

    procedure WrapAtBottom;
      {-Deal with wrap at bottom of edit screen}
    begin
      case ESR.WrapMode of
        WrapAtEdges :
          SeekToFirst;
        ExitAtEdges :
          begin
            ESC := ESnextRec;
            Done := True;
          end;
        StopAtEdges :
          {do nothing} ;
      end;
    end;

    procedure TrimSpaces(var Picture, S : string);
      {-Return a string with leading and trailing blanks removed}
    var
      I : Word;
      Flags : PictureFlags;
    begin
      {make sure it's safe to trim}
      InitPictureFlags(Picture, Flags);
      for I := 1 to Length(Picture) do
        if not Flags[I] then
          Exit;
      TrimSpacesPrim(S);
    end;

    function FieldIsEmpty(var Picture, S : string) : Boolean;
      {-Return true if S is empty}
    var
      I : Word;
      Flags : PictureFlags;
    begin
      FieldIsEmpty := False;
      InitPictureFlags(Picture, Flags);
      for I := 1 to Length(Picture) do
        if Flags[I] and (S[I] <> ' ') then
          Exit;
      FieldIsEmpty := True;
    end;

    function FindBestFieldOnRow(var FRP : FieldRecPtr; Row, Col : Word) : Boolean;
      {-Find the best field on current row for the cursor when moving up or
        down}
    var
      SaveFRP : FieldRecPtr;
    begin
      FindBestFieldOnRow := True;
      SaveFRP := nil;

      {find the last field on the row with an eCol <= Col}
      while (FRP^.NextField <> nil) and (FRP^.NextField^.eRow = Row) and (FRP^.NextField^.eCol <= Col) do begin
        {save the current field if it's not protected}
        if not FieldIsProtected(FRP) then
          SaveFRP := FRP;

        {point to next field}
        FRP := FRP^.NextField;
      end;

      {OK if not protected}
      if FieldIsProtected(FRP) then
        {use the last unprotected field if there is one}
        if SaveFRP <> nil then
          FRP := SaveFRP
        else begin
          {try the rest of the row}
          while (FRP^.NextField <> nil) and (FRP^.NextField^.eRow = Row) and (SaveFRP = nil) do begin
            FRP := FRP^.NextField;
            {save the current field if it's not protected}
            if not FieldIsProtected(FRP) then
              SaveFRP := FRP;
          end;

          {no luck if all fields on this row are protected}
          if SaveFRP = nil then
            FindBestFieldOnRow := False;
        end;
    end;

    procedure PageUpOrDown(Delta : Integer);
      {-Process PgUp/PgDn commands}
      {-Note: Page calculations treat 0 as first page #}
    var
      WHeight : Integer;
      MaxPage : Integer;
      CurPage : Integer;
      NewPage : Integer;
      NewRow  : Integer;
      CurCol  : Integer;
      FRP     : FieldRecPtr;
    begin
      with ESR, CurrentField^ do begin
        WHeight := Succ(YH-YL);
        {$IFDEF TpEntryScrolls}
        if WindowScrolls = 1 then
          MaxPage := Pred(VS.VRows) div WHeight
        else
        {$ENDIF}
          MaxPage := 0;
        CurPage := Pred(eRow) div WHeight;

        {don't switch pages on PgUp if start of CurPage not on screen}
        if (Delta = -1) and (RowOffset > (CurPage * WHeight)) then
          NewPage := CurPage
        else
          NewPage := CurPage + Delta;

        {don't go too far}
        if (NewPage < 0) then
          NewPage := 0
        else if (NewPage > MaxPage) then
          NewPage := MaxPage;

        if (NewPage = MaxPage) and (CurPage = MaxPage) and (Delta > 0) then
          {special case--PgDn while already on last page}
          NewRow := LastRow
        else
          NewRow := Succ(NewPage * WHeight);

        CurCol := Word(WhereXAbs-XL)+ColOffset;

        if NewRow >= CurrentField^.eRow then
          FRP := CurrentField
        else
          FRP := FirstField;
        repeat
          {find first field on row}
          while (FRP <> nil) and (FRP^.eRow < NewRow) do
            FRP := FRP^.NextField;

          if FRP = nil then
            Exit
          else begin
            NewRow := FRP^.eRow;
            if FindBestFieldOnRow(FRP, NewRow, CurCol) then begin
              CurrentField := FRP;
              CurrentID := FRP^.FieldID;
              {$IFDEF TpEntryScrolls}
                {update screen, forcing page alignment}
                if WindowScrolls = 1 then
                  FixEditWindow(ESR, True, True);
              {$ENDIF}
              Exit;
            end
            else
              Inc(NewRow);
          end;
        until (FRP = nil) or (NewRow > LastRow);
      end;
    end;

    procedure PositionCursor;
      {-Puts the cursor on the beginning of the current field}
    var
      Row, Col : Word;
      StBgn : Byte;
      PFlags : PictureFlags;
    begin
      with ESR.CurrentField^ do begin
        {fix the Row and Col}
        Row := eRow;
        Col := eCol;
        FixCoordinates(ESR, Row, Col);

        {find the first non-literal}
        InitPictureFlags(Picture^, PFlags);
        for StBgn := 1 to Length(Picture^) do
          if PFlags[StBgn] then begin
            GoToXYabs(Col+Pred(StBgn), Row);
            Exit;
          end;
      end;
    end;

    function RequiredFieldsOK : Boolean;
      {-Make sure all required fields are filled in}
    var
      SaveCurrentField : FieldRecPtr;
    begin
      {start with first unprotected field}
      SaveCurrentField := ESR.CurrentField;
      SeekToFirst;
      while (ESR.CurrentField <> nil) do
        with ESR do begin
          {check only unprotected fields}
          if not FieldIsProtected(CurrentField) then
            with CurrentField^ do begin
              {if it's a required field, it can't be empty}
              if FlagIsSet(EditFlags, RequiredMask) then
                if FieldIsEmpty(Picture^, EditSt^) then begin
                  {put the cursor on the field that caused the error}
                  PositionCursor;

                  RequiredFieldsOK := False;
                  if (ErrorPtr <> nil) then begin
                    {display error message}
                    ESerrorPtr := ErrorPtr;
                    ErrorRoutine(ESR, ReqFldError, ReqErrorMsg);
                  end
                  else
                    {signal error with bell}
                    RingBell;
                  Exit;
                end;
            end;

          {next field}
          CurrentField := CurrentField^.NextField;
        end;

      {restore current field}
      ESR.CurrentField := SaveCurrentField;
      RequiredFieldsOK := True;
    end;

    function CurrentFieldOK : Boolean;
      {-Make sure the current field isn't protected}
    begin
      with ESR do begin
        CurrentFieldOK := True;
        while (CurrentField <> nil) and FieldIsProtected(CurrentField) do
          CurrentField := CurrentField^.NextField;
        if CurrentField = nil then begin
          {wrap around to first field}
          CurrentField := FirstField;
          while (CurrentField <> nil) and FieldIsProtected(CurrentField) do
            CurrentField := CurrentField^.NextField;
          if CurrentField = nil then begin
            CurrentFieldOK := False;
            Exit;
          end;
        end;
      end;
    end;

    procedure GotoNextField;
      {-Move cursor to next field}
    begin
      with ESR do begin
        FRP := CurrentField^.NextField;
        while (FRP <> nil) and FieldIsProtected(FRP) do
          FRP := FRP^.NextField;
        if FRP = nil then
          WrapAtBottom
        else
          CurrentField := FRP;
      end;
    end;

    procedure GotoPrevField;
      {-Move cursor to previous field}
    begin
      with ESR do begin
        FRP := CurrentField^.PrevField;
        while (FRP <> nil) and FieldIsProtected(FRP) do
          FRP := FRP^.PrevField;
        if FRP = nil then
          WrapAtTop
        else
          CurrentField := FRP;
      end;
    end;

  begin
    Done := False;
    EditScreen := ESnone;
    ESC := ESnone;

    with ESR do begin
      {check for valid signature}
      if Signature <> ValidESRsig then
        Exit;

      {set read-only flag}
      ReadOnlyFlag := ReadOnly;

      {find field to start with}
      if StartField >= FieldCount then
        StartField := 0;
      CurrentField := FindFieldID(ESR, StartField);

      {don't start on a protected field}
      if not CurrentFieldOK then
        Exit;

      {flag the first/last rows in the entry screen}
      ResetEntryScreenFlags(ESR);

      {field count of 1 is special case}
      if (FieldCount = 1) then begin
        WrapMode := ExitAtEdges;
        with CurrentField^ do
          SetFlag(XFlags, ProhibitNextField+ProhibitPrevField+SingleFieldMask);
      end;

      {redraw the edit screen}
      CurrentID := CurrentField^.FieldID;
      DrawEditScreen(ESR);

      {$IFDEF UseMouse}
      SaveMouse := MouseCursorOn;
      if EntryMouseEnabled then begin
        if Framed then begin
          SaveMX := MouseWhereX;
          SaveMY := MouseWhereY;
          SaveMXL := MouseXLo+1;
          SaveMXH := MouseXHi;
          SaveMYL := MouseYLo+1;
          SaveMYH := MouseYHi;              {!!.12}
          MouseWindow(XL, YL, XH+2, YH+2);  {!!.12}
        end;
        ShowMouse;
      end;
      {$ENDIF}

    end;

    repeat

TopOfLoop:
      {with ESR, ESR.CurrentField^ do begin} {!!.12}
        {make sure the current field is OK}
        if not CurrentFieldOK then begin
          EditScreen := ESnone;
          ESC := ESnone;
          Exit;
        end;

      with ESR, ESR.CurrentField^ do begin   {!!.12}
        {save the current ID}
        CurrentID := FieldID;

        {$IFDEF TpEntryScrolls}
        {make sure current field is on the screen}
        FixEditWindow(ESR, True, ScrollByPage);
        {$ENDIF}

        {do the conversion}
        ESconvertPtr := ConvertPtr;
        ConversionRoutine(CurrentField^, False);

        repeat
          {call help prompt routine if desired}
          SaveESC := ESC;
          ESC := ESnone;
          if PreEditPtr <> nil then begin
            {save CurrentField}
            FRP := CurrentField;

            {call the pre-edit routine}
            ESpreEditPtr := PreEditPtr;
            HelpPromptRoutine(ESR);

            {make sure CurrentField wasn't changed}
            if CurrentField <> FRP then begin
              SaveESC := ESnone;
              goto TopOfLoop;
            end;
          end;

          {set position code if necessary}
          case SaveESC of
            ESleft :
              PosCode := 1;
            ESbackTab :
              PosCode := 2;
            ESwordLeft :
              PosCode := 3;
            else
              PosCode := 0;
          end;

          {$IFDEF TpEntryScrolls}
            {$IFDEF UseMouse}
            UpdateScrollBar(ESR);
            {$ENDIF}
          {$ENDIF}

          {edit the current field}
          DrawFieldPrim(ESR, CurrentField, False);
          {$IFDEF IncludeChoice}
          if FlagIsSet(EditFlags, MultChoiceMask) then
            ESC := ChoiceEditor(ESR, CurrentField^)
          else
          {$ENDIF}
            {$IFDEF IncludeNumeric}
            if FlagIsSet(EditFlags, NumericMask) then
              ESC := NumberEditor(ESR, CurrentField^)
            else
            {$ENDIF}
              ESC := StringEditor(PosCode, ESR, CurrentField^);

          {if Escape not pressed, validate and convert}
          OK := True;
          if (ESC <> ESquit) and not ReadOnlyFlag then begin
            {if it's a required field, it can't be empty}
            case ESC of
              ESnested..ESuser9, ESclickExit..ESmouse : {don't check} ;
              else if FlagIsSet(EditFlags, RequiredMask) then
                if FieldIsEmpty(Picture^, EditSt^) then begin
                  OK := False;
                  if (ErrorPtr <> nil) then begin
                    {display error message}
                    ESerrorPtr := ErrorPtr;
                    ErrorRoutine(ESR, ReqFldError, ReqErrorMsg);
                  end
                  else
                    {signal error with bell}
                    RingBell;
                end;
            end;

            {trim leading and trailing blanks if desired}
            if OK and FlagIsSet(EditFlags, TrimBlanksMask) then
              TrimSpaces(Picture^, EditSt^);

            if OK and CurrentFieldModified(ESR) then begin {!!.12}
              {do the conversion}
              ESconvertPtr := ConvertPtr;
              ConversionRoutine(CurrentField^, True);
            end;
          end;

          {redraw the field}
          I := CurrentID;
          CurrentID := MaxFields;
          DrawFieldPrim(ESR, CurrentField, True);
          {$IFDEF TpEntryScrolls}
          if WindowScrolls = 1 then
            UpdateVScreen(ESR, CurrentField);
          {$ENDIF}
          CurrentID := I;
        until OK;

        {call user-defined screen update routine if desired}
        if PostEditPtr <> nil then begin
          ESpostEditPtr := PostEditPtr;
          ScreenUpdateRoutine(ESR);
        end;

        {special case if only one field}
        if FieldCount = 1 then
          case ESC of
            ESdownField :
              begin
                ESC := ESnone;
                WrapAtBottom;
              end;
            ESupField,
            ESbackTab,
            ESprevField,
            ESwordLeft,
            ESleft :
              begin
                ESC := ESnone;
                WrapAtTop;
              end;
          end;

        {move from field to field if appropriate}
        case ESC of
          ESupField :
            if PrevField <> nil then begin
              {find next unprotected field with coordinates above this one}
              FRP := CurrentField;
              Row := FRP^.eRow;
              Col := Word(WhereXAbs-XL)+ColOffset;

Retry1:       {find the next row up with a field on it}
              repeat
                FRP := FRP^.PrevField;
              until (FRP = nil) or (FRP^.eRow < Row);

              {find anything?}
              if FRP = nil then
                WrapAtTop
              else begin
                {we've found the next row up--now find the first field on it}
                Row := FRP^.eRow;
                while (FRP^.PrevField <> nil) and (FRP^.PrevField^.eRow = Row) do
                  FRP := FRP^.PrevField;

                {find the best field}
                if FindBestFieldOnRow(FRP, Row, Col) then
                  CurrentField := FRP
                else
                  goto Retry1;
              end;
            end
            else
              WrapAtTop;

          ESdownField :
            if NextField <> nil then begin
              {find next unprotected field with coordinates below this one}
              FRP := CurrentField;
              Row := FRP^.eRow;
              Col := Word(WhereXAbs-XL)+ColOffset;

Retry2:       {find the next row down with a field on it}
              repeat
                FRP := FRP^.NextField;
              until (FRP = nil) or (FRP^.eRow > Row);

              {find anything?}
              if FRP = nil then
                WrapAtBottom
              else begin
                {reset current row}
                Row := FRP^.eRow;

                {find the best field}
                if FindBestFieldOnRow(FRP, Row, Col) then
                  CurrentField := FRP
                else
                  goto Retry2;
              end;
            end
            else
              WrapAtBottom;

          ESleft,
          ESwordLeft :
            GotoPrevField;

          ESbackTab,
          ESprevField :
            if IDisValid(PrevID) then
              CurrentField := FindFieldID(ESR, PrevID)
            else
              GotoPrevField;

          ESright,
          ESwordRight :
            GotoNextField;

          EStab,
          ESnextField :
            if IDisValid(NextID) then
              CurrentField := FindFieldID(ESR, NextID)
            else
              GotoNextField;

          ESfirstFld :
            SeekToFirst;

          ESlastFld :
            SeekToLast;

          ESpageUp :
            PageUpOrDown(-1);

          ESpageDown :
            PageUpOrDown(1);

          ESnextRec..ESquit :
            Done := True;

          {$IFDEF UseMouse}
          ESmouse :             {new field was selected by the mouse}
            begin
              {ID of new field is in CurrentField^.NewFieldID}
              CurrentID := NewFieldID;
              CurrentField := FindFieldID(ESR, CurrentID);
              if FlagIsSet(CurrentField^.EditFlags, NestedMask) then begin
                {jump right to the nested field}
                ESC := ESnested;
                Done := True;
              end;
            end;

          ESclickExit :
            with CurrentField^ do
              if FlagIsSet(XFlags, BooleanFieldMask) then
                Boolean(VarPtr^) := not Boolean(VarPtr^)
              else
                Done := True;
          {$ENDIF}
        end;
      end;

      {if we're exiting, make sure all required fields are filled in}
      if Done then
        case ESC of
          ESnested..ESuser9, ESquit, ESclickExit : {don't check} ;
          else Done := RequiredFieldsOK;
        end;

    until Done;

    {$IFDEF UseMouse}
    if EntryMouseEnabled and ESR.Framed then begin
      {Restore mouse position and window}
      MouseWindow(SaveMXL, SaveMYL, SaveMXH, SaveMYH);
      MouseGotoXY(SaveMX, SaveMY);
    end;
    ShowMousePrim(SaveMouse);
    {$ENDIF}

    EditScreen := ESC;
  end;

  procedure DisposeEditScreen(var ESR : ESrecord);
    {-Deallocate all field records associated with ESR}
  var
    FRP, Next : FieldRecPtr;
    I : Word;
  begin
    FRP := ESR.FirstField;
    while FRP <> nil do
      with FRP^ do begin
        Next := FRP^.NextField;
        I := Length(Picture^)+1;
        FreeMemCheck(Picture, I);
        FreeMemCheck(EditSt, I);
        FreeMemCheck(Prompt, Length(Prompt^)+1);
        FreeMemCheck(FRP, SizeOf(FieldRec));
        FRP := Next;
      end;

    {$IFDEF TpEntryScrolls}
    {dispose of virtual screen, if any}
    if ESR.VS.VPtr <> nil then
      DisposeVScreen(ESR.VS);
    {$ENDIF}

    {zero out everything}
    InitESrecord(ESR);
  end;

  procedure EditString(Prompt : string;
                       Row, Col : Byte;
                       EditLen : Byte;
                       Picture : string;
                       HelpIndex : Word;
                       var Escaped : Boolean;
                       var EditSt : string);
    {-Use one of the field editors to edit a string.}
  var
    ESR : ESrecord;
    SaveCommands : CommandSet;
    SaveFlags : Word;
    ExitCommand : Word;
  begin
    {initialize edit screen record}
    InitESrecord(ESR);

    {save current flags and disable ones we can't allow}
    SaveFlags := ESeditFlags;
    ClearFlag(ESeditFlags, MultChoiceMask+NestedMask+RequiredMask+
      ProtectedMask+AutoAdvanceBgn+AutoAdvanceEnd);

    {force numeric mode if there's a floating dollar sign or comma}
    if (Pos(FloatDollar, Picture) <> 0) or (Pos(Comma, Picture) <> 0) then begin
      {$IFDEF IncludeNumeric}
        SetNumeric(On);

        {save existing commands and disable exit commands we don't want}
        SaveCommands := NumberCommands;
        NumberCommands := NumberCommands-[ESprevField..ESdone];
      {$ELSE}
        {don't allow it}
        RingBell;
        Halt(1);
      {$ENDIF}
    end
    {$IFDEF IncludeNumeric}
    else if FlagIsSet(ESeditFlags, NumericMask) then begin
      {save existing commands and disable exit commands we don't want}
      SaveCommands := NumberCommands;
      NumberCommands := NumberCommands-[ESprevField..ESdone];
    end
    {$ENDIF}
    else begin
      {save existing commands and disable exit commands we don't want}
      SaveCommands := StringCommands;
      StringCommands := StringCommands-[ESprevField..ESdone];
    end;

    {add the field}
    AddStringField(ESR, Prompt, Row, Col, Picture, Row, Col+Length(Prompt),
      EditLen, HelpIndex, nil, EditSt);

    {restore edit flags}
    ESeditFlags := SaveFlags;

    {edit the string}
    ExitCommand := EditScreen(ESR, 0, False);
    Escaped := (ExitCommand = ESquit);

    {$IFDEF IncludeNumeric}
      {if numeric, strip picture}
      if FlagIsSet(ESeditFlags, NumericMask) then begin
        StripPicture(ESR.FirstField^.Picture^, EditSt, EditSt);
        NumberCommands := SaveCommands;
      end
      else
        StringCommands := SaveCommands;
    {$ELSE}
      StringCommands := SaveCommands;
    {$ENDIF}

    {clean up}
    DisposeEditScreen(ESR);
  end;

begin
  {set default value for EntryKeyPtr}
  EntryKeyPtr := @ReadKeyWord;
end.
