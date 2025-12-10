{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,I-}
{$V-}                        {<- required for TPENTRY}
{$M 16384,16384,600000}

{$I TPDEFINE.INC}

{*********************************************************}
{*                   BEST.PAS 5.22                       *}
{*       An example program for Turbo Professional       *}
{*********************************************************}

program BigEntryScreenTest;
  {-Demonstrates scrollable entry screens}
uses
  tpcrt,
  tpstring,
  {$IFDEF UseMouse}
  tpmouse,
  {$ENDIF}
  tpentry;
const
  MaxRows        = 69;       {absolute maximum number of rows}
  MinRows        = 1;        {absolute minimum number of rows}
  DefRows        = 69;       {default number of rows}
  RowsInUse      : Byte = DefRows; {current number of rows}
  MaxCols        = 6;        {number of columns across}
  MaxLen         = 5;
var
  ESR            : ESrecord;
  Scrap          : array[1..MaxRows, 1..MaxCols] of String[MaxLen];
  ExitCommand    : EStype;
  I, R, C, N     : Word;
  BoxAttr        : Byte;
  BoxTextAttr    : Byte;
  VideoMode      : Byte;

  procedure HideFields;
    {-Hide/unhide fields based on the current value of RowsInUse}
  const
    LastRowsInUse  : Byte = 0;
  var
    I, Row, Col    : Word;
  begin
    {don't do all this if we don't need to}
    if RowsInUse = LastRowsInUse then
      Exit;

    {Note:
      It is very important in this situation that we use ChangeProtectionFast
      rather than ChangeProtection because ChangeProtection automatically
      calls ResetEntryScreenFlags, a very time-consuming routine. By calling
      ChangeProtectionFast for all the individual changes in protection
      status, and calling ResetEntryScreenFlags "manually" a single time when
      we're finished, we can improve the performance of this routine by
      several orders of magnitude.
    }

    I := 1;
    for Row := 1 to RowsInUse do
      for Col := 1 to MaxCols do begin
        {unhide the field}
        ChangeProtectionFast(ESR, I, Off);
        {Note:
          These two statements aren't necessary here, because all protected
          fields were made invisible when we called 'SetProtectAttrs($00,$00)'.
          In some applications, however, we would need to change both the
          attributes and the protection status in order to hide or unhide a
          particular field.

            ChangePromptAttr(ESR, I, ESpromptAttr);
            ChangeFieldAttr(ESR, I, ESfieldAttr);
        }
        Inc(I);
      end;

    for Row := RowsInUse+1 to MaxRows do
      for Col := 1 to MaxCols do begin
        {hide the field}
        ChangeProtectionFast(ESR, I, On);
        {Note:
          Again, these two statements aren't necessary in this application,
          but they might be in others.

            ChangePromptAttr(ESR, I, $00);
            ChangeFieldAttr(ESR, I, $00);
        }
        Inc(I);
      end;

    {reset any flags affected by the changes in protection status}
    ResetEntryScreenFlags(ESR);

    {redraw entire entry screen}
    DrawEditScreen(ESR);

    {save this for later}
    LastRowsInUse := RowsInUse;
  end;

  {$F+}
  procedure UpdateHandler(var ESR : ESrecord);
    {-Called after a field has been edited}
  begin
    {update entry screen if RowsInUse changed}
    if ESR.CurrentID = 0 then
      HideFields;
  end;
  {$F-}

begin
  {initialize the strings we're editing}
  FillChar(Scrap, SizeOf(Scrap), 0);

  {initialize the ESrecord}
  InitESrecord(ESR);
  SetWrapMode(ESR, StopAtEdges);
  SetPostEditPtr(ESR, @UpdateHandler);
  SetTrimBlanks(On);
  SetAutoAdvance(On);
  SetClearFirstChar(On);

  {$IFDEF TpEntryScrolls}
    {scroll by page rather than line}
    ScrollByPage := True;
  {$ELSE}
    The conditional compilation directive TpEntryScrolls isn 't defined!
  {$ENDIF}

  {reassign <PgUp> and <PgDn>}
  if AddEntryCommand(ESpageUp,   1, $4900, 0) then {won' t fail};
  if AddEntryCommand(ESpageDown, 1, $5100, 0) then {won't fail} ;

  {AltS: toggle scrolling modes}
  if AddEntryCommand(ESuser0, 1, $1F00, 0) then {won't fail} ;

  {select colors based on current video mode}
  if WhichHerc = HercInColor then
    VideoMode := 3
  else
    VideoMode := CurrentMode;
  case VideoMode of
    3 :
      begin
        BoxAttr := $1D;
        BoxTextAttr := $1B;
        SetPromptAttr($1B);
        SetFieldAttr($1F);
        SetStringAttr($5F);
        SetCtrlAttr($5F);
        {make all protected fields invisible}
        SetProtectAttrs($11, $11);
      end;
    else
      begin
        BoxAttr := $0F;
        BoxTextAttr := $07;
        SetPromptAttr($0F);
        SetFieldAttr($7);
        SetStringAttr($70);
        SetCtrlAttr($70);
        {make all protected fields invisible}
        SetProtectAttrs($00, $00);
      end;
  end;

  {set up the entry window}
  SetEntryWindow(ESR, 1, 1, ScreenWidth, ScreenHeight, True, BoxTextAttr, BoxAttr);

  {delimit all fields with brackets}
  SetDelimiters(ESR, '[', ']', ESfieldAttr, ESstringAttr);

  {clear the screen before enabling mouse}
  TextAttr := 7;
  ClrScr;

  {$IFDEF UseMouse}
  if MouseInstalled then begin
    {use a diamond of the same color as field prompts for our mouse cursor}
    SoftMouseCursor($0000, (ESpromptAttr shl 8)+$04);
    ShowMouse;

    {enable mouse support}
    EnableEntryMouse;
  end;
  {$ENDIF}

  {first field allows user to change number of visible rows}
  AddByteField(ESR, 'Number of rows in data entry screen [1-69]:', 1, 1,
               '99', 1, 47, 0, MinRows, MaxRows, RowsInUse);

  {construct the rest of the entry screen}
  I := 1;
  for R := 1 to MaxRows do
    for C := 1 to MaxCols do begin
      N := Succ(20*Pred(C));
      AddStringField(ESR, 'Field '+Long2Str(I), R+1, N, '', R+1, N+11, MaxLen,
                     1, nil, Scrap[R, C]);
      Inc(I);
    end;

  {hide/unhide fields}
  HideFields;

  {edit until <Esc> or <^Enter> pressed}
  repeat
    ExitCommand := EditScreen(ESR, ESR.CurrentID, False);
    if ExitCommand = ESuser0 then
      ScrollByPage := not ScrollByPage;
  until (ExitCommand = ESdone) or (ExitCommand = ESquit);

  {clean up screen}
  {$IFDEF UseMouse}
  HideMouse;
  {$ENDIF}
  ClrScr;
end.
