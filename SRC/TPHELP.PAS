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

{Conditional defines that may affect this unit}
{$I TPDEFINE.INC}

{*********************************************************}
{*                    TPHELP.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpHelp;
  {-General purpose help facility}

interface

uses
  Dos,
  TPDos,
  TPMemChk,
  TPString,
  TpCrt,
  TPWindow,
  {$IFDEF UseMouse}
  TpMouse,
  {$ENDIF}
  TpPick,
  TpCmd;

const
  NoHelpAvailable = $FFFFFFFF; {Flag that no help is available for topic}
  MaxPagesPerSection = 100;   {Maximum number of pages of help per section}
  MaxXrefsPerSection = 50;   {Maximum number of topic xrefs per section}
  MaxTopics = 10000;         {Maximum number of topics in one help file}
  MaxHelpStack = 19;         {Highest stacked topic}

  Attr1Toggle = ^A;          {Character toggles special attribute 1}
  Attr2Toggle = ^B;          {Character toggles special attribute 2}
  Attr3Toggle = ^C;          {Character toggles special attribute 3}
  IndexMarker = ^D;          {Character marks topic number that follows}
  XrefToggle = ^E;           {Character toggles xref highlight}
  LineBrkMark = ^M;          {Denotes end of line of help}
  PageBrkMark = ^L;          {Denotes end of page of help}
  SectEndMark = #0;          {Denotes end of help section}

  HelpId : array[0..3] of Char = 'TPH2'; {Identifier at start of help file}

  {Command values for help system}
  HKSNone = 0;               {Not a command}
  HKSAlpha = 1;              {An alphanumeric character, ignored}
  HKSUp = 2;                 {Cursor up to previous cross-reference}
  HKSDown = 3;               {Cursor down to next cross-reference}
  HKSPgUp = 4;               {Display previous help page}
  HKSPgDn = 5;               {Display next help page}
  HKSLeft = 6;               {Cursor left to previous cross-reference}
  HKSRight = 7;              {Cursor right to next cross-reference}
  HKSExit = 8;               {Exit the help system}
  HKSSelect = 9;             {Select the current cross-reference and display topic}
  HKSPrev = 10;              {Display the most recent help topic}
  HKSHome = 11;              {Display first help page}
  HKSEnd = 12;               {Display last help page}
  HKSIndex = 13;             {Display an index of all help topics}
  HKSProbe = 14;             {Mouse selection}
  HKSUser0 = 15;             {User-defined exit commands}
  HKSUser1 = 16;
  HKSUser2 = 17;
  HKSUser3 = 18;

  {.F-}
  {Keystroke to command mapping}
  HelpKeyMax = 99;
  HelpKeyID : string[16] = 'tphelp key array';
  HelpKeySet : array[0..HelpKeyMax] of Byte =
  (
  3, $00, $48, HKSUp,       {Up}
  3, $00, $50, HKSDown,     {Down}
  3, $00, $49, HKSPgUp,     {PgUp}
  3, $00, $51, HKSPgDn,     {PgDn}
  3, $00, $4B, HKSLeft,     {Left}
  3, $00, $4D, HKSRight,    {Right}
  3, $00, $68, HKSPrev,     {Alt-F1}
  3, $00, $47, HKSHome,     {Home}
  3, $00, $4F, HKSEnd,      {End}
  3, $00, $3B, HKSIndex,    {F1}
  2, $05,      HKSUp,       {^E}
  2, $17,      HKSUp,       {^W}
  2, $18,      HKSDown,     {^X}
  2, $1A,      HKSDown,     {^Z}
  2, $12,      HKSPgUp,     {^R}
  2, $03,      HKSPgDn,     {^C}
  2, $13,      HKSLeft,     {^S}
  2, $04,      HKSRight,    {^D}
  2, $1B,      HKSExit,     {Esc}
  2, $0D,      HKSSelect,   {Enter}
  3, $11, $12, HKSHome,     {^QR}
  3, $11, $03, HKSEnd,      {^QC}
  {$IFDEF UseMouse}
  3, $00, $EF, HKSProbe,    {Click left}
  3, $00, $EE, HKSExit,     {Click right}
  3, $00, $ED, HKSIndex,    {Click both}
  {$ELSE}
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0,
  {$ENDIF}
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0 {Space for customization}
  );
  {.F+}

  HelpTitle : string[39] = ' Topics '; {Displayed at top of help pick window}
  UseHelpFrame : Boolean = True; {True to draw frame around help window}
  HelpMore : Boolean = True; {True to display PgUp/PgDn in help frame}
  HideCursor : Boolean = True; {False to leave hardware cursor on screen}

  IndexXrefTopic : Word = 0;  {Topic number which brings up index when used as xref}

  {$IFDEF UseMouse}
  HelpMouseScroll : Boolean = True; {True to support mouse scrolling}
  {$ENDIF}

type
  HKtype = HKSNone..HKSUser3; {Valid help commands}

  HelpColorType = (
    FrAttr,                  {Frame and more prompt}
    TeAttr,                  {Normal text}
    HeAttr,                  {Header}
    XsAttr,                  {Selected cross-reference item}
    XrAttr,                  {Unselected cross-reference item}
    SpAtt1,                  {Special attribute #1}
    SpAtt2,                  {Special attribute #2}
    SpAtt3);                 {Special attribute #3}
  HelpColorArray = array[HelpColorType] of Byte;
  HelpToggleArray = array[Attr1Toggle..XrefToggle] of Byte;


  XlateArray = array[0..15] of Byte; {Most common characters in help text}

  HelpHeader =               {At start of help file}
    record
      ID : LongInt;          {Marks file as help file}
      HighestTopic : Word;   {Highest topic number}
      BiggestTopic : Word;   {Size of largest topic in uncompressed bytes}
      NamedTopics : Word;    {Number of topics in help index}
      NameSize : Byte;       {Size of each entry in pick table, 0 for none}
      Width : Byte;          {Width of help window, with frame if any}
      XlateTable : XlateArray; {Table for decompression}
    end;
  HelpHeaderPtr = ^HelpHeader;

  CharArray = array[0..65520] of Char; {List of names of help entries}
  CharArrayPtr = ^CharArray;

  HelpIndexRec =
    record
      Start : LongInt;       {File position of topic}
      CompLen : Word;        {Compressed length of topic}
    end;                     {Index of file positions}
  HelpIndex = array[1..MaxTopics] of HelpIndexRec;
  HelpIndexPtr = ^HelpIndex;

  TopicIndex = array[1..MaxTopics] of Word;
  TopicIndexPtr = ^TopicIndex;

  Xrefs = 0..MaxXrefsPerSection;
  Pages = 0..MaxPagesPerSection;

  HelpStackRec =
    record
      STopic : Word;         {Which topic}
      SPage : Pages;         {Which page in that topic}
      SXnum : Xrefs;         {Which xref item selected}
    end;
  HelpStackIndex = 0..MaxHelpStack;
  HelpStackArray = array[HelpStackIndex] of HelpStackRec;

  HelpPtr = ^HelpDesc;       {The user hook to the help system}
  HelpDesc =                 {Holds parameters of help system}
    record
      BufP : CharArrayPtr;   {Points to a buffer that will hold largest section}
      Hdr : HelpHeader;      {Copy of header for fast reference}
      RowH : Byte;           {Upper left corner of help window - Row}
      ColH : Byte;           {Upper left corner of help window - Col}
      Height : Byte;         {Height of help window, with frame}
      PickCs : Byte;         {Columns of items to use in help index}
      A : HelpColorArray;    {Attributes used to draw help}
      Frame : FrameArray;    {Frame characters to use}
      ShowFrame : Boolean;   {True to display frame}
      ShowMore : Boolean;    {True to display More prompt in frame}
      MouseScroll : Boolean; {True to display mouse scroll bar}
      Stack : HelpStackArray; {Topics previously accessed}
      St : HelpStackIndex;   {Top of help stack}
      Sb : HelpStackIndex;   {Bottom of help stack}
      case InRAM : Boolean of {True if help file is bound into code}
        False :
          (Fil : file);      {Untyped file variable for help}
        True :
          (HdrP : HelpHeaderPtr; {Points to base of structure in RAM}
            NamP : CharArrayPtr; {Points to pick name array in RAM}
            IndP : HelpIndexPtr); {Points to help section index in RAM}
    end;

var
  HelpKeyPtr : Pointer;      {Points to Kbd routine like ReadKeyWord}
  HelpCmdNum : HKtype;       {Last help command entered}
  HelpOnScreen : Boolean;    {True when help system is displayed}
  {$IFDEF UseMouse}
  HelpMouseEnabled : Boolean; {True if mouse is enabled}
  {$ENDIF}

  {-----------------------------------------------------------------}

function OpenHelpFile(HelpFileName : string;
                      XLow, YLow, YHigh, PickCols : Byte;
                      Colors : HelpColorArray;
                      var Help : HelpPtr) : Word;
  {-Find and open help file, returning 0 or error code, and
    an initialized help descriptor if successful}

function OpenHelpMem(HPtr : Pointer;
                     XLow, YLow, YHigh, PickCols : Byte;
                     Colors : HelpColorArray;
                     var Help : HelpPtr) : Word;
  {-Initialize help descriptor for a help structure bound into code}

procedure CloseHelp(var Help : HelpPtr);
  {-Close help file and/or deallocate buffer space}

procedure SetHelpPos(Help : HelpPtr; XLow, YLow, YHigh : Byte);
  {-Change the position and height of a help window}

function ShowHelp(Help : HelpPtr; Topic : Word) : Boolean;
  {-Display help screen for item Topic, returning true if successful}

function FindHelp(Help : HelpPtr; Name : string; MatchFunc : Pointer) : Word;
  {-Return Topic number of help with specified Name, 0 if not found}

function ScreenHelp(Help : HelpPtr; XPos, YPos : Byte;
                    ScanBack : Boolean; MatchFunc : Pointer) : Word;
  {-Return topic matching screen contents at position (XPos,YPos) or 0 if none}

function PickHelp(Help : HelpPtr; XLow, YLow, YHigh, PickCols : Byte) : Word;
  {-Display help pick list, returning Topic number, or 0 for none}

function ShowPrevHelp(Help : HelpPtr) : Boolean;
  {-Display help screen for topic most recently selected}

function AddHelpCommand(Cmd : HKtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

procedure DisableHelpIndex;
  {-Disable the F1 help index inside of a help screen}

procedure EnableHelpIndex;
  {-Enable the F1 help index inside of a help screen}

  {$IFDEF UseMouse}
procedure EnableHelpMouse;
  {-Enable mouse control of help screens}

procedure DisableHelpMouse;
  {-Disable mouse control of help screens}
  {$ENDIF}

  {=================================================================}

implementation

const
  FlexStackSize = 6;         {Max number of nested attributes}
  MouseUpMark = #24;         {Characters in scroll bar}
  MouseDnMark = #25;
  MousePrevMark = #4;
  ScrollMark = #178;

  FrameDelta : array[Boolean] of Byte = (1, 0);

  HelpIndexDisabled : Boolean = False; {True when F1 inside of help is disabled}

type
  SO =
    record
      O : Word;
      S : Word;
    end;

  StringPtr = ^string;

  PageIndex = array[Pages] of Word; {Offset into text for each page}

  FlexStack = array[0..FlexStackSize] of Byte; {Stacks current attributes}
  PageAttrRec =
    record
      FlexSp : Byte;         {Current stack pointer}
      FlexSt : FlexStack;    {Stack of active attributes}
    end;
  PageAttr = array[Pages] of PageAttrRec;

  XrefRec =
    record
      Page : Pages;          {Which page the xref displays on}
      Row : Byte;            {Which row of window}
      Col : Byte;            {Which col of window}
      Len : Byte;            {Length of highlight}
      Bofs : Word;           {Offset in uncompressed text buffer}
      Topic : Word;          {Which topic is cross-referenced}
    end;
  XrefIndex = array[Xrefs] of XrefRec;

  HelpStateRec =
    record
      ColMin : Byte;         {Min window-relative col where text appears}
      ColMax : Byte;         {Max window-relative col where text appears}
      Pnum : Pages;          {Currently displayed help page}
      Pcnt : Pages;          {Number of pages in topic}
      P : PageIndex;         {Buffer offset of each page}
      PA : PageAttr;         {Starting attribute state of each page}
      Xnum : Xrefs;          {Currently selected cross-reference}
      Xcnt : Xrefs;          {Number of cross-references in topic}
      X : XrefIndex;         {Index of cross-references}
      AC : HelpToggleArray;  {Attributes for each toggle character}
      ShowMoreNow : Boolean; {True to display More prompt in frame}
      MouseScrollNow : Boolean; {True to display mouse scroll bar}
      Lnum : Pages;          {Last active page number}
      Lslid : Byte;          {Last slider position}
      W : WindowPtr;         {Pointer to window in which help appears}
    end;

var
  SPtr : CharArrayPtr;       {Source pointer}
  Dptr : CharArrayPtr;       {Destination pointer}
  SI : Word;                 {Source index during decompression}
  DI : Word;                 {Destination index during decompression}
  BN : Byte;                 {Buffered nibble}
  Nibble : Boolean;          {True when partial byte entered during decompress}
  PBuff : CharArrayPtr;      {Pointer to buffer of pick names}
  TBuff : TopicIndexPtr;     {Pointer to buffer of topic index}
  NSize : Byte;              {Size of array element in pick buffer}

  {$IFDEF FMinus}
  {$F+}
  {$ENDIF}
  function SendHelpName(Topic : Word) : string;
    {-Pass each help Topic to the pick unit}
  begin
    SendHelpName := ' '+string(Ptr(SO(PBuff).S, SO(PBuff).O+NSize*(TBuff^[Topic]-1))^);
  end;

  function Match(S1, S2 : string) : Boolean;
    {-Default match function}
  begin
    Match := (CompUCstring(S1, S2) = Equal);
  end;
  {$IFDEF FMinus}
  {$F-}
  {$ENDIF}

  function OpenHelpFile(HelpFileName : string;
                        XLow, YLow, YHigh, PickCols : Byte;
                        Colors : HelpColorArray;
                        var Help : HelpPtr) : Word;
    {-Find and open help file, returning 0 or error code, and
      an initialized help descriptor if successful}
  label
    ErrorExit;
  var
    IO : Word;
    BytesRead : Word;
    IsOpen : Boolean;
    MaxCols : Byte;
  begin
    {Initialize the result}
    Help := nil;
    IsOpen := False;

    {Find the help file}
    if not ExistOnPath(HelpFileName, HelpFileName) then begin
      OpenHelpFile := 2;
      goto ErrorExit;
    end;

    {Allocate space for help descriptor}
    if not GetMemCheck(Help, SizeOf(HelpDesc)) then begin
      OpenHelpFile := 203;
      goto ErrorExit;
    end;

    {Initialize the help descriptor}
    with Help^ do begin
      {Most help information is on disk}
      InRAM := False;

      {Open the help file}
      Assign(Fil, HelpFileName);
      Reset(Fil, 1);
      IO := IoResult;
      if IO <> 0 then begin
        OpenHelpFile := IO;
        goto ErrorExit;
      end;
      IsOpen := True;

      {Get header from file}
      BlockRead(Fil, Hdr, SizeOf(HelpHeader), BytesRead);
      IO := IoResult;
      if IO <> 0 then begin
        OpenHelpFile := IO;
        goto ErrorExit;
      end;
      if BytesRead <> SizeOf(HelpHeader) then begin
        OpenHelpFile := 100;
        goto ErrorExit;
      end;

      with Hdr do begin
        {Check file ID}
        if ID <> LongInt(HelpId) then begin
          {"Invalid numeric format" - used as error code for invalid ID}
          OpenHelpFile := 106;
          goto ErrorExit;
        end;
        {Get buffer space for reading help sections}
        if not GetMemCheck(BufP, BiggestTopic) then begin
          OpenHelpFile := 203;
          goto ErrorExit;
        end;

        {Validate number of pick columns}
        if NameSize <= 1 then {!!.07}
          MaxCols := 0        {!!.07}
        else                  {!!.07}
          MaxCols := (Width-4) div (NameSize-1);
        if PickCols > MaxCols then
          PickCs := MaxCols
        else
          PickCs := PickCols;
      end;

      {Initialize remaining fields}
      RowH := YLow;
      ColH := XLow;
      Height := YHigh-YLow+1;
      A := Colors;
      Frame := FrameChars;
      ShowFrame := UseHelpFrame;
      ShowMore := UseHelpFrame and HelpMore;
      {$IFDEF UseMouse}
      MouseScroll := UseHelpFrame and HelpMouseScroll;
      {$ENDIF}
      St := 0;
      Sb := 0;

      {Successful initialization}
      OpenHelpFile := 0;
      Exit;
    end;

ErrorExit:
    if IsOpen then begin
      Close(Help^.Fil);
      IO := IoResult;
    end;
    FreeMemCheck(Help, SizeOf(HelpDesc));
  end;

  function OpenHelpMem(HPtr : Pointer;
                       XLow, YLow, YHigh, PickCols : Byte;
                       Colors : HelpColorArray;
                       var Help : HelpPtr) : Word;
    {-Initialize help descriptor for a help structure bound into code}
  label
    ErrorExit;
  var
    MaxCols : Byte;
  begin
    {Initialize the result in case of failure}
    Help := nil;

    {Allocate space for help descriptor}
    if not GetMemCheck(Help, SizeOf(HelpDesc)) then begin
      OpenHelpMem := 203;
      goto ErrorExit;
    end;

    {Initialize the help descriptor}
    with Help^ do begin
      {Help information is in RAM}
      InRAM := True;

      {Check out header}
      HdrP := HPtr;
      Hdr := HdrP^;
      with Hdr do begin
        if ID <> LongInt(HelpId) then begin
          {"Invalid numeric format" - used as error code for invalid ID}
          OpenHelpMem := 106;
          goto ErrorExit;
        end;
        {Get buffer space for decompressing help sections}
        if not GetMemCheck(BufP, BiggestTopic) then begin
          OpenHelpMem := 203;
          goto ErrorExit;
        end;
        NamP := HPtr;
        Inc(SO(NamP).O, SizeOf(HelpHeader));
        IndP := HelpIndexPtr(NamP);
        Inc(SO(IndP).O, HighestTopic*NameSize);

        {Validate number of pick columns}
        if NameSize <= 1 then {!!.07}
          MaxCols := 0
        else
          MaxCols := (Width-4) div (NameSize-1);
        if PickCols > MaxCols then
          PickCs := MaxCols
        else
          PickCs := PickCols;
      end;

      {Initialize remaining fields}
      RowH := YLow;
      ColH := XLow;
      Height := YHigh-YLow+1;
      A := Colors;
      Frame := FrameChars;
      ShowFrame := UseHelpFrame;
      ShowMore := UseHelpFrame and HelpMore;
      {$IFDEF UseMouse}
      MouseScroll := UseHelpFrame and HelpMouseScroll;
      {$ENDIF}
      St := 0;
      Sb := 0;

      {Successful initialization}
      OpenHelpMem := 0;
      Exit;
    end;

ErrorExit:
    FreeMemCheck(Help, SizeOf(HelpDesc));
  end;

  procedure CloseHelp(var Help : HelpPtr);
    {-Close help file and/or deallocate buffer space}
  var
    IO : Word;
  begin
    with Help^, Hdr do begin
      if ID <> LongInt(HelpId) then
        {Not a valid help pointer}
        Exit;
      if not InRAM then
        if FileRec(Fil).Mode = fmInOut then begin
          {Close help file}
          Close(Fil);
          IO := IoResult;
        end;
      FreeMem(BufP, BiggestTopic);
    end;
    FreeMem(Help, SizeOf(HelpDesc));
    Help := nil;
  end;

  procedure SetHelpPos(Help : HelpPtr; XLow, YLow, YHigh : Byte);
    {-Change the position of a help window}
  begin
    with Help^ do
      if Hdr.ID = LongInt(HelpId) then begin
        RowH := YLow;
        ColH := XLow;
        Height := YHigh-YLow+1;
      end;
  end;

  function GetNameString(Help : HelpPtr; Topic : Word) : string;
    {-Return name string for help item, if any}
  var
    S : string;
  begin
    GetNameString := '';
    with Help^, Hdr do
      if NameSize <> 0 then
        if InRAM then
          GetNameString := string(Ptr(SO(NamP).S, SO(NamP).O+NameSize*(Topic-1))^)
        else if FileRec(Fil).Mode = fmInOut then begin
          Seek(Fil, LongInt(SizeOf(HelpHeader))+NameSize*(Topic-1));
          if IoResult <> 0 then
            Exit;
          BlockRead(Fil, S, NameSize);
          if IoResult <> 0 then
            Exit;
          GetNameString := S;
        end;
  end;

  procedure InitTopic(Help : HelpPtr; var HelpState : HelpStateRec);
    {-Paginate topic and find xref points}
  var
    Bpos : Word;
    Pofs : Word;
    Prow : Word;
    Pcol : Word;
    Mrow : Word;
    WordP : ^Word;
    Done : Boolean;
    Ch : Char;
    HA : PageAttrRec;
    LA : PageAttrRec;

    procedure NewPage;
      {-Store information about previous page}
    begin
      with HelpState do
        if Pcnt+1 >= MaxPagesPerSection then
          Done := True
        else begin
          Inc(Pcnt);         {Increment page count}
          P[Pcnt] := Pofs;   {Character offset at start of page}
          PA[Pcnt] := LA;    {Attribute state at start of page}
          Pofs := Bpos+1;    {Start of next page}
          P[Pcnt+1] := Pofs; {Sentinel to end last page}
          Prow := 0;         {New page has no lines}
          LA := HA;          {Attribute state at start of new page}
        end;
    end;

  begin
    with Help^, Hdr, HelpState do begin
      Lnum := 0;
      Pnum := 1;
      Xnum := 0;
      ColMin := 2;
      ColMax := Width-3;
      Bpos := 0;
      Pcnt := 0;
      Pofs := 0;
      Prow := 0;
      Pcol := ColMin;
      Mrow := Height-2;
      Xcnt := 0;

      {No special attributes initially active}
      FillChar(HA, SizeOf(PageAttrRec), 0);
      HA.FlexSt[0] := A[TeAttr];
      LA := HA;

      Done := False;
      repeat
        Ch := BufP^[Bpos];
        case Ch of
          Attr1Toggle..Attr3Toggle : {Modifying video attribute}
            with HA do
              if (FlexSp > 0) and (FlexSt[FlexSp] = AC[Ch]) then
                {Toggling current state off}
                Dec(FlexSp)
              else if FlexSp < FlexStackSize then begin
                {Changing to new attribute}
                Inc(FlexSp);
                FlexSt[FlexSp] := AC[Ch];
              end;

          XrefToggle :       {Marking a cross-reference}
            with HA do
              if (FlexSp > 0) and (FlexSt[FlexSp] = A[XrAttr]) then begin
                {Toggling current state off}
                Dec(FlexSp);
                {Store length of highlight}
                with X[Xcnt] do
                  Len := Bpos-Bofs-1;
              end else if FlexSp < FlexStackSize then begin
                {Changing to new attribute}
                Inc(FlexSp);
                FlexSt[FlexSp] := A[XrAttr];
              end;

          IndexMarker :      {Indicating cross-reference topic}
            begin
              if Xcnt < MaxXrefsPerSection then begin
                Inc(Xcnt);
                with X[Xcnt] do begin
                  Page := Pcnt+1;
                  Row := Prow+1;
                  Col := Pcol;
                  Bofs := Bpos+3;
                  WordP := @BufP^[Bpos+1];
                  Topic := WordP^;
                end;
              end;
              Inc(Bpos, 2);
            end;

          LineBrkMark :      {End of line}
            begin
              Inc(Prow);
              Pcol := ColMin;
              if Prow >= Mrow then
                NewPage;
            end;

          PageBrkMark :      {End of page}
            if Bpos = Pofs then
              Inc(Pofs)
            else begin
              Pcol := ColMin;
              NewPage;
            end;

          SectEndMark :      {End of section}
            begin
              if Bpos <> Pofs then
                NewPage;
              Done := True;
            end;
        else
          Inc(Pcol);
        end;
        Inc(Bpos);
      until Done;
    end;
  end;

  procedure ShowPrompt(Help : HelpPtr; var HelpState : HelpStateRec);
    {-Show information about help}
  const
    MoreLen = 11;
    Up : string[4] = 'PgUp';
    Dn : string[4] = 'PgDn';
  var
    MoreMsg : string[11];
  begin
    with Help^, Hdr, HelpState do begin
      if (Width < MoreLen+6) then
        Exit;
      FillChar(MoreMsg[1], MoreLen, FrameChars[Horiz]);
      MoreMsg[0] := Char(MoreLen);
      MoreMsg[6] := ' ';
      if Pnum > 1 then begin
        Move(Up[1], MoreMsg[2], 4);
        MoreMsg[1] := ' ';
      end;
      if Pnum < Pcnt then begin
        Move(Dn[1], MoreMsg[7], 4);
        MoreMsg[11] := ' ';
        if Pnum > 1 then
          MoreMsg[6] := '/'
      end;
      FastWrite(MoreMsg, RowH+Height-1, ColH+Width-MoreLen-3, A[FrAttr]);
    end;
  end;

  procedure DrawPage(Help : HelpPtr; var HelpState : HelpStateRec);
    {-Draw one page of help}
  var
    Bpos : Word;
    Bend : Word;
    Attr : Byte;
    R : Byte;
    C : Byte;
    Ch : Char;
    AtSt : PageAttrRec;
  begin
    with Help^, HelpState, AtSt do begin
      Bpos := P[Pnum];
      Bend := P[Pnum+1];
      R := 1;
      C := ColMin;

      AtSt := PA[Pnum];
      Attr := FlexSt[FlexSp];
      ClrScr;

      repeat
        Ch := BufP^[Bpos];
        case Ch of
          LineBrkMark :
            begin
              Inc(R);
              C := ColMin;
            end;

          Attr1Toggle..Attr3Toggle :
            if (FlexSp > 0) and (FlexSt[FlexSp] = AC[Ch]) then begin
              {Toggling current state off}
              Dec(FlexSp);
              Attr := FlexSt[FlexSp];
            end else if FlexSp < FlexStackSize then begin
              {Changing to new attribute}
              Inc(FlexSp);
              Attr := AC[Ch];
              FlexSt[FlexSp] := Attr;
            end;

          XrefToggle :
            if (FlexSp > 0) and (FlexSt[FlexSp] = A[XrAttr]) then begin
              {Toggling current state off}
              Dec(FlexSp);
              Attr := FlexSt[FlexSp];
            end else if FlexSp < FlexStackSize then begin
              {Changing to new attribute}
              Inc(FlexSp);
              if Bpos = X[Xnum].Bofs then
                {Selected cross-ref}
                Attr := A[XsAttr]
              else
                {Deselected cross-ref}
                Attr := A[XrAttr];
              FlexSt[FlexSp] := A[XrAttr];
            end;

          IndexMarker :
            {Skip over topic number}
            Inc(Bpos, 2);

          PageBrkMark, SectEndMark :
            Exit;
        else
          if C <= ColMax then
            FastWriteWindow(Ch, R, C, Attr);
          Inc(C);
        end;
        Inc(Bpos);
      until Bpos >= Bend;
    end;
  end;

  procedure DrawXref(Help : HelpPtr; var HelpState : HelpStateRec; Num : Xrefs);
    {-Draw Xref in appropriate attribute}
  var
    Bpos : Word;
    Bend : Word;
    Attr : Byte;
    R : Byte;
    C : Byte;
    Ch : Char;
  begin
    with Help^, HelpState, X[Num] do begin
      Bpos := Bofs+1;
      Bend := P[Pnum+1];
      R := Row;
      C := Col;
      if Num = Xnum then
        Attr := A[XsAttr]
      else
        Attr := A[XrAttr];

      repeat
        Ch := BufP^[Bpos];
        case Ch of
          LineBrkMark :
            begin
              Inc(R);
              C := ColMin;
            end;
          XrefToggle :
            Exit;
          PageBrkMark, SectEndMark :
            Exit;
        else
          if C <= ColMax then
            FastWriteWindow(Ch, R, C, Attr);
          Inc(C);
        end;
        Inc(Bpos);
      until Bpos >= Bend;
    end;
  end;

  function GetNibble : Byte;
    {-Return next nibble from source}
  begin
    if Nibble then begin
      {Buffered nibble available}
      GetNibble := BN shr 4;
      Nibble := False;
      Inc(SI);
    end else begin
      {First nibble of byte}
      BN := Ord(SPtr^[SI]);
      GetNibble := BN and $0F;
      Nibble := True;
    end;
  end;

  procedure Decompress(var X : XlateArray; Len : Word; S, D : CharArrayPtr);
    {-Decompress text of length Len at S to position D, using X for translation}
  var
    N : Byte;
    C : Char;
  begin
    Nibble := False;
    SI := 0;
    DI := 0;
    SPtr := S;
    Dptr := D;
    while SI < Len do begin
      N := GetNibble;
      if N < $0F then
        C := Char(X[N])
      else begin
        N := GetNibble;
        C := Char((GetNibble shl 4) or N);
      end;
      Dptr^[DI] := C;
      Inc(DI);
    end;
  end;

  function LoadHelp(Help : HelpPtr; Topic : Word) : Boolean;
    {-Load and decompress one help topic}
  var
    BytesRead : Word;
    Frec : HelpIndexRec;
    Comp : CharArrayPtr;
  begin
    LoadHelp := False;

    with Help^, Hdr do begin
      if InRAM then begin
        {Already in memory, just compute the pointer}
        Frec := IndP^[Topic];
        {Check for available help}
        if Frec.Start = NoHelpAvailable then
          Exit;
        Comp := Ptr(SO(HdrP).S, SO(HdrP).O+Frec.Start);

      end else if FileRec(Fil).Mode = fmInOut then begin
        {On disk, first read the index}
        Seek(Fil, (SizeOf(HelpHeader)+
          LongInt(NameSize)*HighestTopic+
          SizeOf(HelpIndexRec)*(Topic-1)));
        if IoResult <> 0 then
          Exit;
        BlockRead(Fil, Frec, SizeOf(HelpIndexRec), BytesRead);
        if (IoResult <> 0) or (BytesRead <> SizeOf(HelpIndexRec)) then
          Exit;
        {Check for available help}
        if Frec.Start = NoHelpAvailable then
          Exit;
        {Now read the help section}
        Seek(Fil, Frec.Start);
        if IoResult <> 0 then
          Exit;
        {Put compressed version at top of buffer}
        Comp := @BufP^[BiggestTopic-Frec.CompLen];
        BlockRead(Fil, Comp^, Frec.CompLen, BytesRead);
        if (IoResult <> 0) or (BytesRead <> Frec.CompLen) then
          Exit;
      end else
        {Help file not open}
        Exit;

      {Decompress text into BufP^[0]}
      Decompress(XlateTable, Frec.CompLen, Comp, BufP);

      LoadHelp := True;
    end;
  end;

  function FirstXref(var HelpState : HelpStateRec) : Xrefs;
    {-Return index of first xref on page, 0 if none}
  var
    Inum : Xrefs;
  begin
    with HelpState do
      for Inum := 1 to Xcnt do
        if X[Inum].Page = Pnum then begin
          FirstXref := Inum;
          Exit;
        end;
    FirstXref := 0;
  end;

  {$IFDEF UseMouse}
  function MatchXref(Help : HelpPtr; var HelpState : HelpStateRec;
                     Num : Xrefs; MX, MY : Byte) : Boolean;
    {-Return true if any portion of xref intersects MX, MY}
  var
    Bpos : Word;
    Bend : Word;
    R : Byte;
    C : Byte;
  begin
    MatchXref := False;
    with Help^, HelpState, X[Num] do begin
      Bpos := Bofs+1;
      Bend := P[Pnum+1];
      R := Row;
      C := Col;
      repeat
        case BufP^[Bpos] of
          LineBrkMark :
            begin
              Inc(R);
              C := ColMin;
            end;
          XrefToggle :
            Exit;
          PageBrkMark, SectEndMark :
            Exit;
        else
          {Check for a match}
          if (R = MY) and (C = MX) then begin
            MatchXref := True;
            Exit;
          end;
          Inc(C);
        end;
        Inc(Bpos);
      until Bpos >= Bend;
    end;
  end;

  function IsXRef(Help : HelpPtr; var HelpState : HelpStateRec;
                  MX, MY : Byte) : Xrefs;
    {-Select xref, if any, at position MX,MY}
  var
    Inum : Xrefs;
  begin
    with HelpState do
      for Inum := 1 to Xcnt do
        if X[Inum].Page = Pnum then
          if MatchXref(Help, HelpState, Inum, MX, MY) then begin
            IsXRef := Inum;
            Exit;
          end;
    IsXRef := 0;
  end;

  function SliderPos(var HelpState : HelpStateRec) : Byte;
    {-Calculate the slider position in absolute coordinates}
  begin
    with HelpState, WindowP(W)^ do
      SliderPos := YL+((Pnum-1)*(YH-YL)) div (Pcnt-1);
  end;

  procedure UpdateMouseFrame(Help : HelpPtr;
                             var HelpState : HelpStateRec);
    {-Set mouse window coordinates and scroll bar}
  begin
    with Help^, HelpState, WindowP(W)^, Draw do begin
      MouseScrollNow := MouseScroll and (Pcnt > 1);
      if MouseScrollNow then begin
        {Let mouse move into frame}
        MouseWindow(XL1, YL1, XH1, YH1);
        {Draw scroll marks}
        FastWrite(MouseUpMark, YL1, XH1, FAttr);
        FastWrite(MouseDnMark, YH1, XH1, FAttr);
        ShowMoreNow := False;
        Lslid := 0;
      end else
        {Don't let mouse move into frame}
        MouseWindow(XL1, YL1, XH, YH);
      {Draw previous help mark}
      FastWrite(MousePrevMark, YL1, XL1, FAttr);
    end;
  end;
  {$ENDIF}

  procedure IncPrim(var HelpState : HelpStateRec; Delta : Integer);
    {-Increment or decrement to next valid Xref}
  var
    Inum : Xrefs;
  begin
    with HelpState do
      if Xnum <> 0 then begin
        Inum := Xnum;
        repeat
          Inc(Xnum, Delta);
          if Xnum < 1 then
            Xnum := Xcnt
          else if Xnum > Xcnt then
            Xnum := 1;
        until (Xnum = Inum) or (X[Xnum].Page = Pnum);
      end;
  end;

  procedure IncXref(Help : HelpPtr; var HelpState : HelpStateRec;
                    Delta : Integer);
    {-Increment or decrement to next valid Xref and update screen}
  var
    Inum : Xrefs;
  begin
    with HelpState do begin
      Inum := Xnum;
      IncPrim(HelpState, Delta);
      if Inum <> Xnum then begin
        {Update highlights}
        DrawXref(Help, HelpState, Inum);
        DrawXref(Help, HelpState, Xnum);
      end;
    end;
  end;

  procedure IncVertXref(Help : HelpPtr; var HelpState : HelpStateRec;
                        Delta : Integer);
    {-Increment or decrement to next valid Xref}
  var
    Inum : Xrefs;
    Jnum : Xrefs;
  begin
    with HelpState do begin
      {Move to a different row}
      Inum := Xnum;
      repeat
        IncPrim(HelpState, Delta);
      until (Xnum = Inum) or (X[Xnum].Row <> X[Inum].Row);

      {Move to appropriate field on that row}
      if Delta*X[Xnum].Col < Delta*X[Inum].Col then
        repeat
          {Store previous xref}
          Jnum := Xnum;
          IncPrim(HelpState, Delta);
          if (Xnum <> Jnum) then
            {Able to move}
            if X[Xnum].Row <> X[Jnum].Row then
              {Moved to new row, back up}
              Xnum := Jnum
            else if Delta*X[Xnum].Col >= Delta*X[Inum].Col then {!!.07}
              {Far enough, force exit}
              Jnum := Xnum;
        until (Xnum = Jnum);

      if Inum <> Xnum then begin
        {Update highlights}
        DrawXref(Help, HelpState, Inum);
        DrawXref(Help, HelpState, Xnum);
      end;
    end;
  end;

  procedure GetHeaderString(Help : HelpPtr; Topic : Word;
                            var HeaderStr : string);
    {-Return string for header of window}
  begin
    HeaderStr := GetNameString(Help, Topic);
    if Length(HeaderStr) > 0 then
      HeaderStr := ' '+HeaderStr+' ';
  end;

  procedure FrameHelp(Help : HelpPtr; var HelpState : HelpStateRec;
                      Title : string);
    {-Draw titled frame around help window}
  begin
    with Help^, Hdr, HelpState do
      if ShowFrame then
        FrameWindow(ColH, RowH, ColH+Width-1, RowH+Height-1,
          A[FrAttr], A[HeAttr], Title);
  end;

  function LoadNewTopic(Help : HelpPtr; var HelpState : HelpStateRec;
                        Topic : Word) : Boolean;
    {-Return true if specified topic successfully loaded}
  var
    HeaderStr : string[80];
  begin
    with Help^, Hdr, HelpState do
      if LoadHelp(Help, Topic) then begin
        InitTopic(Help, HelpState);
        GetHeaderString(Help, Topic, HeaderStr);
        FrameHelp(Help, HelpState, HeaderStr);
        LoadNewTopic := True;
      end else
        LoadNewTopic := False;
  end;

  procedure IncSp(var Sp : HelpStackIndex);
    {-Increment and wrap}
  begin
    if Sp = MaxHelpStack then
      Sp := 0
    else
      Inc(Sp);
  end;

  procedure DecSp(var Sp : HelpStackIndex);
    {-Decrement and wrap}
  begin
    if Sp = 0 then
      Sp := MaxHelpStack
    else
      Dec(Sp);
  end;

  procedure PushStack(Help : HelpPtr;
                      Topic : Word;
                      Page : Pages;
                      Xnum : Xrefs);
    {-Push a help topic onto stack}
  begin
    with Help^ do
      if Topic <> 0 then begin {!!.06}
        with Stack[St] do begin
          STopic := Topic;
          SPage := Page;
          SXnum := Xnum;
        end;
        IncSp(St);
        if St = Sb then
          IncSp(Sb);
      end;
  end;

  procedure PopStack(Help : HelpPtr;
                     var Topic : Word;
                     var Page : Pages;
                     var Xnum : Xrefs);
    {-Pop help topic from stack}
  begin
    with Help^ do
      if St = Sb then {!!.07}
        Topic := 0    {!!.07}
      else begin      {!!.07}
        DecSp(St);
        with Stack[St] do begin
          Topic := STopic;
          Page := SPage;
          Xnum := SXnum;
        end;
      end;            {!!.07}
  end;

  function GetBuffer(Help : HelpPtr;
                     var P;
                     SeekOfs : LongInt;
                     SizeReq : Word;
                     var SizeAlloc : Word) : Boolean;
    {-Return pointer to loaded array of help data}
  var
    Pt : Pointer absolute P;
    BytesRead : Word;
  begin
    GetBuffer := False;
    SizeAlloc := 0;

    with Help^, Hdr do
      if InRAM then
        {Already in memory, just compute the pointer}
        Pt := Ptr(SO(HdrP).S, SO(HdrP).O+Word(SeekOfs))

      else if FileRec(Fil).Mode = fmInOut then begin
        {On disk, first allocate space}
        if not GetMemCheck(P, SizeReq) then
          Exit;
        SizeAlloc := SizeReq;
        {Read names into buffer}
        Seek(Fil, SeekOfs);
        if IoResult <> 0 then
          Exit;
        BlockRead(Fil, Pt^, SizeReq, BytesRead);
        if (IoResult <> 0) or (BytesRead <> SizeReq) then
          Exit;

      end else
        {Help file not open}
        Exit;

    GetBuffer := True;
  end;

  function ShowHelpPrim(Help : HelpPtr;
                        Topic : Word;
                        Page : Pages;
                        XrefNum : Xrefs) : Boolean;
    {-Display help screen, returning true if successful}
  label
    SelectATopic,
    LoadPrevTopic,
    ShowIndex,
    ExitPoint;
  var
    Done : Boolean;
    HaveBuffers : Boolean;
    Choice : Word;
    Row : Word;
    ChWord : Word;
    SizeAlloc1 : Word;
    SizeAlloc2 : Word;
    SavePickMatrix : Word;
    Key1 : Word;
    Key2 : Word;
    SavePickHelp : Pointer;  {!!.09}
    NumKeys : Byte;

    {$IFDEF UseMouse}
    MX : Byte;               {Mouse absolute X position}
    MY : Byte;               {Mouse absolute Y position}
    SaveMX : Byte;           {Saved mouse state}
    SaveMY : Byte;
    SaveMXL : Byte;
    SaveMXH : Byte;
    SaveMYL : Byte;
    SaveMYH : Byte;
    SaveWaitFor : Boolean;   {Saved WaitForButtonRelease variable}
    SaveMouseOn : Boolean;   {Was mouse cursor on at entry}
    SavePickMouseEnabled : Boolean; {Was pick enabled for mouse}
    Slid : Byte;             {Slider position}
    NewXnum : Xrefs;
    TmpXnum : Xrefs;
    {$ENDIF}

    PC : PickColorArray;
    HelpState : HelpStateRec;
    SaveFrameChars : FrameArray;
    HeaderStr : string[80];
  begin
    ShowHelpPrim := False;
    with Help^, Hdr, HelpState do begin

      {Validate request}
      if ID <> LongInt(HelpId) then
        Exit;
      if (Topic = 0) or (Topic > HighestTopic) then
        Exit;

      {Set colors and frame}
      AC[Attr1Toggle] := A[SpAtt1];
      AC[Attr2Toggle] := A[SpAtt2];
      AC[Attr3Toggle] := A[SpAtt3];
      AC[IndexMarker] := 0;
      AC[XrefToggle] := A[XsAttr];
      PC[WindowAttr] := A[TeAttr];
      PC[FrameAttr] := A[FrAttr];
      PC[HeaderAttr] := A[HeAttr];
      PC[SelectAttr] := A[XsAttr];
      PC[AltNormal] := A[TeAttr];
      PC[AltHigh] := A[XsAttr];
      SaveFrameChars := FrameChars;

      {Get help text into memory and initialize pointer to it}
      if not LoadHelp(Help, Topic) then
        Exit;
      {Scan help text to find page boundaries and xref markers}
      InitTopic(Help, HelpState);

      {Validate the page in case window was resized}
      if Page > Pcnt then {!!.06}
        Page := Pcnt;

      Pnum := Page;
      ShowMoreNow := ShowMore and (Pcnt > 1);
      HelpOnScreen := True;

      {Amount of space allocated for index buffers}
      SizeAlloc1 := 0;
      SizeAlloc2 := 0;
      HaveBuffers := False;

      {$IFDEF UseMouse}
      SaveMouseOn := MouseCursorOn;
      if SaveMouseOn then
        HideMouse;
      {$ENDIF}

      {Display window}
      FrameChars := Frame;
      GetHeaderString(Help, Topic, HeaderStr);
      if not MakeWindow(W,
        ColH, RowH,
        ColH+Width-1-2*FrameDelta[ShowFrame], RowH+Height-1,
        ShowFrame, True, False,
        A[TeAttr], A[FrAttr], A[HeAttr],
        HeaderStr) then
        goto ExitPoint;
      if not DisplayWindow(W) then
        goto ExitPoint;
      if HideCursor then
        HiddenCursor;

      {$IFDEF UseMouse}
      if HelpMouseEnabled then
        with WindowP(W)^, Draw do begin
          {Save current mouse parameters}
          SaveMX := MouseWhereX;
          SaveMY := MouseWhereY;
          SaveMXL := MouseXLo+1;
          SaveMXH := MouseXHi;
          SaveMYL := MouseYLo+1;
          SaveMYH := MouseYHi;
          SaveWaitFor := WaitForButtonRelease;
          {Set new mouse parameters}
          WaitForButtonRelease := True;
          UpdateMouseFrame(Help, HelpState);
          {Position to top left corner of window}
          MouseGoToXY(1, 1);
        end;
      {$ENDIF}

      {Allow user to browse help}
      Done := False;
      repeat

        {Draw a new help page if necessary}
        if Pnum <> Lnum then begin
          if XrefNum = 0 then
            Xnum := FirstXref(HelpState)
          else begin
            {Validate the Xref in case page size was changed}
            if X[XrefNum].Page <> Pnum then           {!!.06}
              XrefNum := FirstXref(HelpState);
            Xnum := XrefNum;
            XrefNum := 0;
          end;
          DrawPage(Help, HelpState);
          if ShowMoreNow then
            ShowPrompt(Help, HelpState);
          {$IFDEF UseMouse}
          if HelpMouseEnabled then
            if MouseScrollNow then
              {Draw slider}
              with WindowP(W)^.Draw do begin
                Slid := SliderPos(HelpState);
                if Lslid <> 0 then
                  FastWrite(Frame[Vert], Lslid, XH1, FAttr);
                FastWrite(ScrollMark, Slid, XH1, FAttr);
                Lslid := Slid;
              end;
          {$ENDIF}
          Lnum := Pnum;
        end;

        {$IFDEF UseMouse}
        if HelpMouseEnabled then
          ShowMouse;
        {$ENDIF}

        HelpCmdNum := GetCommand(HelpKeySet, HelpKeyPtr, ChWord);

        {$IFDEF UseMouse}
        if HelpMouseEnabled then
          HideMouse;
        {$ENDIF}

        case HelpCmdNum of

          {Commands to move xref highlight}
          HKSUp :
            IncVertXref(Help, HelpState, -1);
          HKSDown :
            IncVertXref(Help, HelpState, +1);
          HKSLeft :
            IncXref(Help, HelpState, -1);
          HKSRight :
            IncXref(Help, HelpState, +1);

          {Commands to select another page of help}
          HKSPgUp :
            if Pnum > 1 then
              Dec(Pnum);
          HKSPgDn :
            if Pnum < Pcnt then
              Inc(Pnum);
          HKSHome :
            Pnum := 1;
          HKSEnd :
            Pnum := Pcnt;

          {$IFDEF UseMouse}
          {Mouse probe}
          HKSProbe :
            if HelpMouseEnabled then
              with WindowP(W)^, Draw do begin
                {Get absolute mouse coordinate}
                MX := MouseXLo+MouseKeyWordX;
                MY := MouseYLo+MouseKeyWordY;
                if (MX = XL1) and (MY = YL1) then begin
                  {Request for previous help topic}
                  if St <> Sb then
                    goto LoadPrevTopic;
                end else if MouseScrollNow and (MX = XH1) then begin
                  {In the scroll bar region}
                  if MY = YL1 then begin
                    {Move up one page}
                    if Pnum > 1 then
                      Dec(Pnum);
                  end else if MY = YH1 then begin
                    {Move down one page}
                    if Pnum < Pcnt then
                      Inc(Pnum);
                  end else if MY <> Lslid then begin
                    {Move proportional to mouse position}
                    Pnum := 1+((MY-YL)*(Pcnt-1)) div (YH-YL);
                    {Assure the slider moves at least one notch in the right direction}
                    if MY > Lslid then
                      while (SliderPos(HelpState) <= MY) and (Pnum < Pcnt) do
                        Inc(Pnum)
                    else if MY < Lslid then
                      while (SliderPos(HelpState) >= MY) and (Pnum > 1) do
                        Dec(Pnum);
                  end;
                end else if (MY >= YL) and (MY <= YH) then begin
                  {In the active pick region, convert to window relative}
                  Dec(MX, XL-1);
                  Dec(MY, YL-1);
                  {Select another xref if possible}
                  NewXnum := IsXRef(Help, HelpState, MX, MY);
                  if NewXnum <> 0 then
                    if NewXnum = Xnum then
                      {Second click on item, select it}
                      goto SelectATopic
                    else begin
                      {Move highlight to item}
                      TmpXnum := Xnum;
                      Xnum := NewXnum;
                      DrawXref(Help, HelpState, TmpXnum);
                      DrawXref(Help, HelpState, Xnum);
                    end;
                end;
              end;
          {$ENDIF}

          {Commands to exit help or select another topic}
          HKSExit, HKSUser0..HKSUser3 :
            begin
              {Save current help topic and page}
              PushStack(Help, Topic, Pnum, Xnum);
              Done := True;
              ShowHelpPrim := True;
            end;
          HKSSelect :
            if Xnum <> 0 then begin
SelectATopic:
              {Show the help index if a special topic number is specified}
              if X[Xnum].Topic = IndexXrefTopic then {!!.08}
                GoTo ShowIndex;

              {Save current help topic and page}
              PushStack(Help, Topic, Pnum, Xnum);
              Topic := X[Xnum].Topic;

              Done := not LoadNewTopic(Help, HelpState, Topic);
              if not Done then begin
                ShowMoreNow := ShowMore and (Pcnt > 1);
                {$IFDEF UseMouse}
                if HelpMouseEnabled then
                  UpdateMouseFrame(Help, HelpState);
                {$ENDIF}
              end;
            end;
          HKSPrev :
            if St <> Sb then begin
LoadPrevTopic:
              {Restore previous displayed topic and page}
              PopStack(Help, Topic, Page, XrefNum);
              Done := not LoadNewTopic(Help, HelpState, Topic);
              if not Done then begin
                Pnum := Page;
                ShowMoreNow := ShowMore and (Pcnt > 1);
                {$IFDEF UseMouse}
                if HelpMouseEnabled then
                  UpdateMouseFrame(Help, HelpState);
                {$ENDIF}
              end;
            end;
          HKSIndex :
ShowIndex:
            if (NamedTopics > 0) and (PickCs > 0)
            {$IFDEF EnablePickOrientations}                {!!.10}
            and (PickOrientation <> PickOrientNone)        {!!.10}
            {$ENDIF}                                       {!!.10}
            then begin
              {Find keystroke for previous help topic}
              GetKeysForCommand(HelpKeySet, HKSPrev, NumKeys, Key1, Key2);
              if NumKeys <> 0 then
                {Temporarily add command to pick set for previous help topic}
                if AddPickCommand(PKSUser3, NumKeys, Key1, Key2) then begin
                  if not HaveBuffers then
                    {Allocate and read index tables}
                    if GetBuffer(Help, PBuff,
                      SizeOf(HelpHeader),
                      HighestTopic*NameSize, SizeAlloc1) then
                      if GetBuffer(Help, TBuff,
                        SizeOf(HelpHeader)+
                        LongInt(HighestTopic)*(NameSize+SizeOf(HelpIndexRec)),
                        HighestTopic*SizeOf(Word), SizeAlloc2) then
                        HaveBuffers := True;
                  if HaveBuffers then begin
                    Choice := 1;
                    Row := 1;
                    SavePickMatrix := PickMatrix;
                    PickMatrix := PickCs;
                    NSize := NameSize;
                    {Temporarily disable help within pick}
                    SavePickHelp := PickHelpPtr; {!!.09}
                    PickHelpPtr := nil;          {!!.09}

                    {$IFDEF UseMouse}
                    if HelpMouseEnabled then begin
                      {Assure mouse is also on in TPPICK}
                      SavePickMouseEnabled := PickMouseEnabled;
                      if not PickMouseEnabled then
                        EnablePickMouse;
                    end;
                    {$ENDIF}

                    FrameHelp(Help, HelpState, HelpTitle);
                    ClrScr;
                    FillPickWindow(W, @SendHelpName, NamedTopics,
                      PC, Choice, Row);
                    PickBar(W, @SendHelpName, NamedTopics, PC, False,
                      Choice, Row);
                    PickMatrix := SavePickMatrix;
                    PickHelpPtr := SavePickHelp; {!!.09}

                    {$IFDEF UseMouse}
                    if HelpMouseEnabled then
                      if not SavePickMouseEnabled then begin
                        {Assure mouse is now off in TPPICK}
                        DisablePickMouse;
                        {But that it stays on for TPHELP}
                        EnableHelpMouse;
                      end;
                    {$ENDIF}

                    case PickCmdNum of
                      PKSSelect :
                        begin
                          {Save current help topic and page}
                          PushStack(Help, Topic, Pnum, Xnum);
                          {Prepare to display new topic}
                          Topic := TBuff^[Choice];
                          Done := not LoadNewTopic(Help, HelpState, Topic);
                          if not Done then begin
                            ShowMoreNow := ShowMore and (Pcnt > 1);
                            {$IFDEF UseMouse}
                            if HelpMouseEnabled then
                              UpdateMouseFrame(Help, HelpState);
                            {$ENDIF}
                          end;
                        end;
                      PKSUser3 :
                        begin
                          {Redisplay previous topic}
                          GetHeaderString(Help, Topic, HeaderStr);
                          FrameHelp(Help, HelpState, HeaderStr);
                          Lnum := 0;
                          XrefNum := Xnum;
                          if not Done then begin
                            ShowMoreNow := ShowMore and (Pcnt > 1);
                            {$IFDEF UseMouse}
                            if HelpMouseEnabled then {!!}
                              UpdateMouseFrame(Help, HelpState);
                            {$ENDIF}
                          end;
                        end;
                    else
                      Done := True;
                      ShowHelpPrim := True;
                    end;
                    {Deactivate special added command}
                    if AddPickCommand(PKSNone, NumKeys, Key1, Key2) then ;
                  end;
                end;
            end;

        end;
      until Done;

      {Deallocate index buffer space}
      if SizeAlloc1 <> 0 then
        FreeMem(PBuff, SizeAlloc1);
      if SizeAlloc2 <> 0 then
        FreeMem(TBuff, SizeAlloc2);
      {Restore the screen}
      DisposeWindow(EraseTopWindow);

      {$IFDEF UseMouse}
      if HelpMouseEnabled then begin
        {Restore mouse position and window}
        MouseWindow(SaveMXL, SaveMYL, SaveMXH, SaveMYH);
        MouseGoToXY(SaveMX, SaveMY);
        WaitForButtonRelease := SaveWaitFor;
      end;
      if SaveMouseOn then
        ShowMouse;
      {$ENDIF}

ExitPoint:
      FrameChars := SaveFrameChars;
      HelpOnScreen := False;
    end;
  end;

  function ShowHelp(Help : HelpPtr; Topic : Word) : Boolean;
    {-Display help screen, returning true if successful}
  begin
    ShowHelp := ShowHelpPrim(Help, Topic, 1, 0);
  end;

  function ShowPrevHelp(Help : HelpPtr) : Boolean;
    {-Display help screen for topic most recently selected}
  var
    Topic : Word;
    Page : Pages;
    XrefNum : Xrefs;
  begin
    ShowPrevHelp := False;
    with Help^ do
      if St <> Sb then begin
        PopStack(Help, Topic, Page, XrefNum);
        ShowPrevHelp := ShowHelpPrim(Help, Topic, Page, XrefNum);
      end;
  end;

  function FindHelp(Help : HelpPtr; Name : string; MatchFunc : Pointer) : Word;
    {-Return topic number of help with specified Name, 0 if not found}
  label
    ExitPoint;
  var
    P : CharArrayPtr;
    NP : StringPtr;
    SizeAlloc : Word;
    I : Word;

    function CallMatch(S1, S2 : string) : Boolean;
      {-Call routine pointed to by MatchFunc}
    inline($FF/$5E/<MatchFunc); {Call dword ptr [bp+<MatchFunc]}

  begin
    FindHelp := 0;
    if MatchFunc = nil then
      MatchFunc := @Match;
    with Help^, Hdr do begin
      {Validate help structure}
      if ID <> LongInt(HelpId) then
        Exit;
      if GetBuffer(Help, P, SizeOf(HelpHeader), HighestTopic*NameSize, SizeAlloc) then begin
        {Match the name}
        NP := StringPtr(P);
        for I := 1 to HighestTopic do
          if CallMatch(NP^, Name) then begin
            FindHelp := I;
            goto ExitPoint;
          end else
            Inc(SO(NP).O, NameSize);
      end;
    end;
ExitPoint:
    if SizeAlloc <> 0 then
      FreeMem(P, SizeAlloc);
  end;

  function WordChar(Ch : Char) : Boolean;
    {-Return true if Ch is a character in a word}
  begin
    case Upcase(Ch) of
      'A'..'Z', '_', '0'..'9' : WordChar := True;
    else
      WordChar := False;
    end;
  end;

  function ScreenHelp(Help : HelpPtr; XPos, YPos : Byte;
                      ScanBack : Boolean; MatchFunc : Pointer) : Word;
    {-Return topic matching screen contents at position (XPos,YPos) or 0 if none}
  var
    Bpos : Byte;
    EPos : Byte;
    SName : string;
  begin
    ScreenHelp := 0;

    {Read entire screen row at YPos}
    FastRead(ScreenWidth, YPos, 1, SName);

    EPos := XPos;
    if ScanBack then
      {Back up until in a word}
      while (EPos > 1) and not WordChar(SName[EPos]) do
        Dec(EPos);

    {Get out if no word available}
    if not WordChar(SName[EPos]) then
      Exit;

    {Find beginning of word}
    Bpos := EPos;
    while (Bpos > 0) and WordChar(SName[Bpos]) do
      Dec(Bpos);

    {Find end of word}
    while (EPos <= Length(SName)) and WordChar(SName[EPos]) do
      Inc(EPos);

    {Search for help by that name}
    SName := Copy(SName, Bpos+1, EPos-Bpos-1);
    ScreenHelp := FindHelp(Help, SName, MatchFunc);
  end;

  function PickHelp(Help : HelpPtr; XLow, YLow, YHigh, PickCols : Byte) : Word;
    {-Display help pick list, returning Topic number, or 0 for none}
  var
    SizeAlloc1 : Word;
    SizeAlloc2 : Word;
    Choice : Word;
    XHigh : Byte;
    SaveFrameChars : FrameArray;
    SavePickMatrix : Byte;
    SavePickMouseEnabled : Boolean;
    PC : PickColorArray;
  begin
    PickHelp := 0;
    SizeAlloc2 := 0; {!!.11}
    with Help^, Hdr do begin
      {Validate help structure}
      if ID <> LongInt(HelpId) then
        Exit;
      if GetBuffer(Help, PBuff,
        SizeOf(HelpHeader),
        HighestTopic*NameSize, SizeAlloc1) then
        if GetBuffer(Help, TBuff,
          SizeOf(HelpHeader)+
          LongInt(HighestTopic)*(NameSize+SizeOf(HelpIndexRec)),
          HighestTopic*SizeOf(Word), SizeAlloc2) then begin
          {Set colors and frame}
          PC[WindowAttr] := A[TeAttr];
          PC[FrameAttr] := A[FrAttr];
          PC[HeaderAttr] := A[HeAttr];
          PC[SelectAttr] := A[XsAttr];
          PC[AltNormal] := A[TeAttr];
          PC[AltHigh] := A[XsAttr];
          SaveFrameChars := FrameChars;
          SavePickMatrix := TpPick.PickMatrix;

          {Set up global with NameSize}
          NSize := NameSize;

          {Choose the window width}
          XHigh := XLow+PickCols*(NSize+1)+1;
          if XHigh > ScreenWidth then
            XHigh := ScreenWidth;

          FrameChars := Frame;
          TpPick.PickMatrix := PickCols;
          Choice := 1;

          {$IFDEF UseMouse}
          if HelpMouseEnabled then begin
            {Assure mouse is also on in TPPICK}
            SavePickMouseEnabled := PickMouseEnabled;
            if not PickMouseEnabled then
              EnablePickMouse;
          end;
          {$ENDIF}

          {Pick from list}
          if PickWindow(@SendHelpName, NamedTopics,
            XLow, YLow, XHigh, YHigh, UseHelpFrame,
            PC, HelpTitle, Choice) then
            if PickCmdNum = PKSSelect then
              PickHelp := TBuff^[Choice];

          {$IFDEF UseMouse}
          if HelpMouseEnabled then
            if not SavePickMouseEnabled then begin
              {Assure mouse is now off in TPPICK}
              DisablePickMouse;
              {But that it stays on for TPHELP}
              EnableHelpMouse;
            end;
          {$ENDIF}
          FrameChars := SaveFrameChars;
          TpPick.PickMatrix := SavePickMatrix;
        end;
    end;

    if SizeAlloc1 <> 0 then
      FreeMem(PBuff, SizeAlloc1);
    if SizeAlloc2 <> 0 then
      FreeMem(TBuff, SizeAlloc2);
  end;

  function AddHelpCommand(Cmd : HKtype; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
    {-Add a new command key assignment or change an existing one}
  begin
    AddHelpCommand := AddCommandPrim(HelpKeySet, HelpKeyMax, Cmd, NumKeys, Key1, Key2);
  end;

  procedure DisableHelpIndex;
    {-Disable the F1 help index inside of a help screen}
  var
    Junk : Boolean;
  begin
    Junk := AddHelpCommand(HKSNone, 1, $3B00, 0);
    {$IFDEF UseMouse}
    Junk := AddHelpCommand(HKSNone, 1, $ED00, 0);
    {$ENDIF}
    HelpIndexDisabled := True;
  end;

  procedure EnableHelpIndex;
    {-Enable the F1 help index inside of a help screen}
  var
    Junk : Boolean;
  begin
    Junk := AddHelpCommand(HKSIndex, 1, $3B00, 0);
    {$IFDEF UseMouse}
    Junk := AddHelpCommand(HKSIndex, 1, $ED00, 0);
    {$ENDIF}
    HelpIndexDisabled := False;
  end;

  {$IFDEF UseMouse}
  procedure EnableHelpMouse;
    {-Enable mouse control of the help system}
  begin
    if MouseInstalled then begin
      HelpKeyPtr := @TpMouse.ReadKeyOrButton;
      EnableEventHandling;
      HelpMouseEnabled := True;
    end;
  end;

  procedure DisableHelpMouse;
    {-Disable mouse control of the help system}
  begin
    if HelpMouseEnabled then begin
      HelpKeyPtr := @ReadKeyWord;
      DisableEventHandling;
      HelpMouseEnabled := False;
    end;
  end;
  {$ENDIF}

begin
  HelpKeyPtr := @ReadKeyWord;
  HelpOnScreen := False;
  {$IFDEF UseMouse}
  HelpMouseEnabled := False;
  {$ENDIF}
end.
