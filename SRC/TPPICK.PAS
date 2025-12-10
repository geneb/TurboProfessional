{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$R-,O+,A-}
{$ENDIF}

{Conditional defines that may affect this unit}
{$I TPDEFINE.INC}

{*********************************************************}
{*                    TPPICK.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

{
 Special thanks to Dan T. Davis for his numerous contributions to this unit.
}

unit TpPick;
  {-Pick items from lists}

interface

uses
  TPCrt,
  TPString,
  TPWindow,
  {$IFDEF UseMouse}
  TPMouse,
  {$ENDIF}
  TpCmd;

const
  PKSNone = 0;                    {Command values accepted by pick manager}
  PKSAlpha = 1;
  PKSUp = 2;
  PKSDown = 3;
  PKSPgUp = 4;
  PKSPgDn = 5;
  PKSLeft = 6;
  PKSRight = 7;
  PKSExit = 8;
  PKSSelect = 9;
  PKSHelp = 10;
  PKSHome = 11;
  PKSEnd = 12;
  PKSProbe = 13;
  PKSUser0 = 14;                  {User-defined exit commands}
  PKSUser1 = 15;
  PKSUser2 = 16;
  PKSUser3 = 17;
  PKSUser4 = 18;                  {!!.21}
  PKSUser5 = 19;                  {!!.21}
  PKSUser6 = 20;                  {!!.21}
  PKSUser7 = 21;                  {!!.21}
  PKSUser8 = 22;                  {!!.21}
  PKSUser9 = 23;                  {!!.21}

  MaxSearchLen = 16;              {Maximum length of incremental search string}

type
  PKType = PKSNone..PKSUser9;     {All of the pick commands} {!!.21}

  PickColorType =
  (WindowAttr,                    {Color for normal unselected items}
   FrameAttr,                     {Color for window frame}
   HeaderAttr,                    {Color for window header}
   SelectAttr,                    {Color for normal selected item}
   AltNormal,                     {Color for alternate unselected items}
   AltHigh                        {Color for alternate selected item}
   {$IFDEF PickItemDisable}
   ,
   UnpickableAttr                 {Color for unpickable item}
   {$ENDIF}
   );
  PickColorArray = array[PickColorType] of Byte;

  SrchString = String[MaxSearchLen]; {Maximum search string size}

  SrchType =
  (NoPickSrch,                    {Alpha characters ignored}
   StringPickSrch,                {Incremental search}
   StringAltSrch,                 {Alternate incremental search}
   CharPickSrch,                  {Single char search}
   CharPickNow);                  {Single char search, exit on match}

  PickOrientType =
  (PickOrientNone,                {No orientation selected}
   PickVertical,                  {Items arranged vertically}
   PickHorizontal,                {Items arranged horizontally}
   PickSnaking);                  {Items arranged vertically, snaking}

const
  {Size control for picklist}
  PickMinRows : Word = 0;         {Minimum rows in window}
  PickMaxRows : Word = 9999;      {Maximum rows in window}
  PickMatrix : Byte = 1;          {Number of items across in window}

  {Appearance control for picklist}
  PickStick : Boolean = True;     {True to "stick" at top/bottom on scrolling picklists}
  PickMore : Boolean = True;      {Show "more" markers for items out of window}
  PickAlterPageRow : Boolean = True; {False to leave row fixed after PgUp/PgDn}

  {Search control for picklist}
  PickSrch : SrchType = NoPickSrch; {Disable character and string searches}
  SrchStart : Byte = 1;           {Starting position of search in item string}
  PickSrchStat : Boolean = True;  {True to show status of incremental searches}

  {Cursor control for picklist}
  HideCursor : Boolean = True;    {False to leave hardware cursor on screen}

  {$IFDEF UseMouse}
  {Mouse control for picklist}
  PickMouseScroll : Boolean = True; {True to support mouse scrolling}
  PickMousePage : Boolean = False; {True to scroll by one page per click}
  PickMouseEnabled : Boolean = False; {True if mouse is enabled}
  PrevSlid : Byte = 0;            {Previous scroll bar slider position}
  PickMouseWindow : Boolean = True; {True if mouse window around pick window} {!!.21}
  {$ENDIF}

  {Color control for picklist}
  AltPickAttr : Boolean = False;  {If True, special color attributes used to pick item}

  {$IFDEF PickItemDisable}
  {User control as to whether the choice is pickable}
  Pickable : Boolean = True;      {User controlled variable for pickable items}
  {$ENDIF}

  {.F-}
  {Keystroke to command mapping}
  PickKeyMax = 111;
  PickKeyID : string[16] = 'tppick key array';
  PickKeySet : array[0..PickKeyMax] of Byte =
  (
  3, $00, $48, PKSUp,       {Up}
  3, $00, $50, PKSDown,     {Down}
  3, $00, $49, PKSPgUp,     {PgUp}
  3, $00, $51, PKSPgDn,     {PgDn}
  3, $00, $4B, PKSLeft,     {Left}
  3, $00, $4D, PKSRight,    {Right}
  3, $00, $3B, PKSHelp,     {F1}
  3, $00, $47, PKSHome,     {Home}
  3, $00, $4F, PKSEnd,      {End}
  2, $05,      PKSUp,       {^E}
  2, $17,      PKSUp,       {^W}
  2, $18,      PKSDown,     {^X}
  2, $1A,      PKSDown,     {^Z}
  2, $12,      PKSPgUp,     {^R}
  2, $03,      PKSPgDn,     {^C}
  2, $13,      PKSLeft,     {^S}
  2, $04,      PKSRight,    {^D}
  2, $1B,      PKSExit,     {Esc}
  2, $0D,      PKSSelect,   {Enter}
  3, $11, $12, PKSHome,     {^QR}
  3, $11, $03, PKSEnd,      {^QC}
  {$IFDEF UseMouse}
  3, $00, $EF, PKSProbe,    {Click left}
  3, $00, $EE, PKSExit,     {Click right}
  3, $00, $ED, PKSHelp,     {Click both}
  {$ELSE}
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0,
  {$ENDIF}
  0, 0, 0, 0, 0, 0,         {Space for customization}
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  );
  {.F+}

var
  {External control pointers for picklist}
  PickKeyPtr : Pointer;           {User defined keyboard function}
  PickUserPtr : Pointer;          {User defined routine for each pick move}
  PickHelpPtr : Pointer;          {If not nil, routine is called when help key pressed}
  PickSrchPtr : Pointer;          {User defined routine for pick searching}

  PickCmdNum : PKType;            {Command number used to exit pick}
  PickChar : Char;                {Character used to exit pick}

  SStr : SrchString;              {Holder for search string}
  Slen : Byte absolute SStr;      {Length of search string}


function PickWindow
  (StringFunc : Pointer;          {Pointer to function to return each item string}
   NumItems : Word;               {Number of items to pick from}
   XLow, YLow : Byte;             {Window coordinates, including frame if any}
   XHigh, YHigh : Byte;           {Window coordinates, including frame if any}
   DrawFrame : Boolean;           {True to draw a frame around window}
   Colors : PickColorArray;       {Video attributes to use}
   Header : String;               {Title for window}
   var Choice : Word              {The item selected, in the range 1..NumItems}
   ) : Boolean;                   {True if PickWindow was successful}
  {-Display a window, let user scroll around in it, and return choice.
    Choice returned is in the range 1..NumItems.}

procedure FillPickWindow
  (W : WindowPtr;                 {Which window to display pick list}
   StringFunc : Pointer;          {Pointer to function to return each item string}
   NumItems : Word;               {Number of items in PickArray}
   Colors : PickColorArray;       {Video attributes to use}
   Choice : Word;                 {Choice,FirstChoice tell how items should be drawn}
   FirstChoice : Word);           {...in a manner consistent with PickBar}
  {-Display a window, fill it with choices, and return.
    Choice specifies the initial item highlighted.}

procedure PickBar
  (W : WindowPtr;                 {The window to operate in}
   StringFunc : Pointer;          {Pointer to function to return items}
   NumItems : Word;               {The number of items to pick from}
   Colors : PickColorArray;       {Video attributes to use}
   EraseBar : Boolean;            {Should we recolor the bar when finished?}
   var Choice : Word;             {The item selected, range 1..NumItems}
   var FirstChoice : Word);       {Choice appearing in upper left corner of window}
  {-Choose from a pick list already displayed on the screen}

procedure EvaluatePickCommand
  (W : WindowPtr;                 {The window to operate in}
   StringFunc : Pointer;          {Pointer to function to return items}
   NumItems : Word;               {The number of items to pick from}
   var Choice : Word;             {The item selected, range 1..NumItems}
   var FirstChoice : Word;        {The item in the upper left corner}
   var Cmd : PKType);             {Command to evaluate, modified only if mouse select}
  {-Evaluate a pick command}

{$IFDEF EnablePickOrientations}
procedure SetVerticalPick;
procedure SetHorizontalPick;
procedure SetSnakingPick;
  {-Select a pick orientation}

function PickOrientation : PickOrientType;
  {-Return the current pick orientation}
{$ENDIF}

function AddPickCommand(Cmd : PKType; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
  {-Add a new command key assignment or change an existing one}

  {$IFDEF UseMouse}
procedure EnablePickMouse;
  {-Enable mouse control of pick lists}

procedure DisablePickMouse;
  {-Disable mouse control of pick lists}
  {$ENDIF}

  {the following variables are reserved for internal use by TurboPower}
const
  PrivatePick : Boolean = False;
  PrivatePickAttr : Byte = 0;

  {====================================================================}

implementation

const
  PickFunc : Pointer = nil;       {Pointer to function that returns each string}
  ChoiceFunc : Pointer = nil;     {Pointer to proc that set current choice}
  RowColProc : Pointer = nil;     {Pointer to proc that returns row,col of a choice}

  UpArr : array[Boolean] of Char = (' ', ^X);
  DnArr : array[Boolean] of Char = (' ', ^Y);

  PickOrient : PickOrientType = PickOrientNone; {Orientation currently selected}

  {$IFDEF UseMouse}
  SliderFunc : Pointer = nil;     {Pointer to routine that gets mouse slider pos}
  ScrollProc : Pointer = nil;     {Pointer to routine that scrolls using slider pos}
  MouseUpMark = #24;              {Characters in scroll bar}
  MouseDnMark = #25;
  ScrollMark = #178;
  MouseUpCmd : array[Boolean] of PKType = (PKSUp, PKSPgUp);
  MouseDownCmd : array[Boolean] of PKType = (PKSDown, PKSPgDn);
  {$ENDIF}

type
  {.F-}
  PickMoveType = (   LeftTop,   UpLeft,   UpMiddle,   UpRight, RightTop,
                  LeftMiddle,                                  RightMiddle,
                  LeftBottom, DownLeft, DownMiddle, DownRight, RightBottom,
                  PgUp,
                  PgDn);
  {.F+}
  PickMoveArray = array[PickMoveType] of Pointer;

  PickStateRec =                  {Used to make TpPick re-entrant}
    record                        {Should have fields for all globals in unit}
      sPickMinRows : Word;
      sPickMaxRows : Word;
      sPickMatrix : Byte;
      sPickStick : Boolean;
      sPickMore : Boolean;
      sPickAlterPageRow : Boolean;
      sPickSrch : SrchType;
      sSrchStart : Byte;
      sPickSrchStat : Boolean;
      sHideCursor : Boolean;
      sAltPickAttr : Boolean;
      sPickFunc : Pointer;
      sChoiceFunc : Pointer;
      sRowColProc : Pointer;
      sPickOrient : PickOrientType;
      sPickColors : PickColorArray;
      sgFirstChoice : Word;
      sgChoice : Word;
      sgRow : Word;
      sgCol : Word;
      sX1 : Word;
      sY1 : Word;
      sXSize : Word;
      sYSize : Word;
      sgNumItems : Word;
      sItemWidth : Word;
      sItemRows : Word;
      sMaxFirstChoice : Word;
      sYMesg : Word;
      sXMore : Word;
      sHasMore : Boolean;
      sMoreSpace : Byte;
      sPickIsFramed : Boolean;
      sItemWrap : Boolean;
      sHorizChar : Char;
      sVertChar : Char;
      sPickMovePtr : PickMoveArray;
      sgChangeAmount : Word;
      {$IFDEF UseMouse}
      sMouseScroll : Boolean;
      sPickMouseScroll : Boolean;
      sPickMousePage : Boolean;
      sPickMouseEnabled : Boolean;
      sSliderFunc : Pointer;
      sScrollProc : Pointer;
      sPrevSlid : Byte;           {!!.12}
      sPickMouseWindow : Boolean; {!!.21}
      {$ENDIF}
      {$IFDEF PickItemDisable}
      sPickable : Boolean;
      {$ENDIF}
    end;

var
  PickColors : PickColorArray;    {Current colors}
  gFirstChoice : Word;            {Global copies of main state variables}
  gChoice : Word;
  gRow : Word;
  gCol : Word;
  X1 : Word;                      {Top left corner of current pick window}
  Y1 : Word;
  XSize : Word;                   {Active size of pick window}
  YSize : Word;
  gNumItems : Word;               {Total items being considered}
  ItemWidth : Word;               {Width of each item}
  ItemRows : Word;                {Offset between items in different cols}
  MaxFirstChoice : Word;          {Highest acceptable value for FirstChoice}
  YMesg : Word;                   {Y position where messages are written}
  XMore : Word;                   {X position where "more" message is written}
  HasMore : Boolean;              {Need to display More notification}
  MoreSpace : Byte;               {Space Used by More notification}
  PickIsFramed : Boolean;         {True when pick window is framed}
  ItemWrap : Boolean;             {True to wrap when hitting window periphery}
  HorizChar : Char;               {Char for horizontal portion of frame}
  VertChar : Char;                {Char for vertical portion of frame}
  PickMovePtr : PickMoveArray;    {Routines for each move category}
  gChangeAmount : Word;           {Amount to change by for a given move}

  {$IFDEF UseMouse}
  MouseScroll : Boolean;          {True when mouse scrolling is available}
  {$ENDIF}


  {$I TPPICK.IN1}                 {Low-level pick routines}


  procedure InitPickPrim(W : WindowPtr;
                         StringFunc : Pointer;
                         NumItems : Word);
    {-Initialize non-display oriented variables used for display of picklist}
  begin
    with WindowP(W)^, Draw do begin
      {Save attributes of the window}
      X1 := XL;
      Y1 := YL;
      XSize := XH-XL+1;
      YSize := YH-YL+1;
      YMesg := YH+1;
      PickIsFramed := Framed;
      HorizChar := Frame[Horiz];
      VertChar := Frame[Vert];
    end;

    {Store global copies of various parameters}
    gNumItems := NumItems;
    ItemWidth := XSize div PickMatrix;

    {YSize is the number of rows actually used in window}
    Lower(YSize, gNumItems);
    Lower(YSize, PickMaxRows);

    {ItemRows is the total rows used by items in each column}
    ItemRows := (gNumItems+PickMatrix-1) div PickMatrix;
    Raise(ItemRows, PickMinRows);
    Lower(ItemRows, gNumItems);
    Lower(YSize, ItemRows);

    {Initialize orientation-specific variables}
    {$IFDEF EnablePickOrientations}
    case PickOrient of
      PickVertical : InitPickVert;
      PickHorizontal : InitPickHoriz;
      PickSnaking : InitPickSnake;
    end;
    {$ELSE}
    InitPickVert;
    {$ENDIF}

    {Should cursor wrap when it reaches corners of window?}
    ItemWrap := (MaxFirstChoice = 1) or not PickStick;
    {$IFDEF UseMouse}
    {Can a mouse scroll bar be used?}
    MouseScroll := (MaxFirstChoice > 1) and PickMouseScroll and PickIsFramed;
    {$ENDIF}

    PickFunc := StringFunc;
  end;

  function InitPickVars(W : WindowPtr;
                        StringFunc : Pointer;
                        NumItems : Word;
                        Colors : PickColorArray
                        ) : Boolean;
    {-Initialize variables used for display of picklist}
    {$IFDEF UseMouse}
  var
    SaveMouseOn : Boolean;
    {$ENDIF}
  begin
    InitPickVars := False;

    {Make sure an orientation was selected}
    if PickOrient = PickOrientNone then
      Exit;

    {Make sure StringFunc and window are specified}
    if (StringFunc = nil) or (W = nil) then
      Exit;

    {Make sure the window is on screen}
    with WindowP(W)^ do begin
      {$IFDEF UseMouse}
      SaveMouseOn := MouseCursorOn;
      if SaveMouseOn then
        HideMouse;
      {$ENDIF}
      if DisplayWindow(W) then
        ;
      {$IFDEF UseMouse}
      if SaveMouseOn then
        ShowMouse;
      {$ENDIF}

      {Were we able to show the window?}
      if not Active then
        Exit;
    end;

    PickColors := Colors;

    {Assure the Pickable constant hasn't been messed up} {!!.10}
    {$IFDEF PickItemDisable}                             {!!.10}
    Pickable := True;                                    {!!.10}
    {$ENDIF}                                             {!!.10}

    {Initialize lower level variables}
    InitPickPrim(W, StringFunc, NumItems);

    {Anything to display?}
    if YSize = 0 then
      Exit;

    {Determine position of "more" message, if any}
    HasMore := (PickMore and PickIsFramed and
                (ItemRows > YSize) and (XSize > 5));
    if not HasMore then
      MoreSpace := 0
    else if XSize <= 14 then
      MoreSpace := 5
    else
      MoreSpace := 14;
    XMore := X1+XSize-MoreSpace;

    InitPickVars := True;
  end;

  procedure DrawItem(ItemNum : Word; Row, Col : Byte; Selected : Boolean);
    {-Draw the specified item}
  var
    A : Byte;
    ARow : Byte;
    ACol : Byte;
    S : String;
    Slen : Byte absolute S;
  begin
    {Build the item name}
    if ItemNum <= gNumItems then
      S := GetString(ItemNum)
    else
      Slen := 0;
    if Slen < ItemWidth then
      S := Pad(S, ItemWidth)
    else
      Slen := ItemWidth;

    {Select attribute for display}
    if PrivatePick then
      A := PrivatePickAttr
      {$IFDEF PickItemDisable}
    else if not Pickable then
      A := PickColors[UnpickableAttr]
      {$ENDIF}
    else if AltPickAttr then begin
      if Selected then
        A := PickColors[AltHigh]
      else
        A := PickColors[AltNormal];
    end else if Selected then
      A := PickColors[SelectAttr]
    else
      A := PickColors[WindowAttr];

    {Reset pick flags}
    PrivatePick := False;
    AltPickAttr := False;
    {$IFDEF PickItemDisable}
    Pickable := True;
    {$ENDIF}

    {Write it}
    ARow := Y1+Row-1;
    ACol := X1+ItemWidth*(Col-1);
    FastWrite(S, ARow, ACol, A);

    {Position the cursor}
    if Selected then
      GotoXYAbs(ACol, ARow);
  end;

  procedure DrawPage;
    {-Draw the entire page}
  var
    R : Byte;
    C : Byte;
  begin
    for C := 1 to PickMatrix do
      for R := 1 to YSize do
        DrawItem(CurrentChoice(gFirstChoice, R, C),
                 R, C, (R = gRow) and (C = gCol));
  end;

  procedure DrawMore;
    {-Draw the more marker if needed}
  const
    More : String[13] = ' || for more ';
  begin
    if HasMore then begin
      More[0] := Chr(MoreSpace-1);
      More[2] := UpArr[(gFirstChoice > 1)];
      More[3] := DnArr[(gFirstChoice < MaxFirstChoice)];
      FastWrite(More, YMesg, XMore, PickColors[FrameAttr]);
    end;
  end;

  {$IFDEF UseMouse}
  procedure DrawMouseMarks(W : WindowPtr);
    {-Draw the mouse scroll marks in the frame}
  begin
    with WindowP(W)^, Draw do begin
      FastWrite(MouseUpMark, YL1, XH1, PickColors[FrameAttr]);
      FastWrite(MouseDnMark, YH1, XH1, PickColors[FrameAttr]);
    end;
    {Don't draw more markers now}
    HasMore := False;
  end;

  procedure EraseMouseMarks(W : WindowPtr); {!!.13}
    {-Erase the mouse scroll marks in the frame}
  begin
    with WindowP(W)^, Draw do begin
      FastWrite(Frame[URight], YL1, XH1, PickColors[FrameAttr]);
      FastWrite(Frame[LRight], YH1, XH1, PickColors[FrameAttr]);
    end;
  end;

  procedure EvaluateMousePosition(W : WindowPtr; var Cmd : PKType);
    {-Evaluate effect of a mouse selection}
  var
    mX : Byte;                    {Mouse absolute X position}
    mY : Byte;                    {Mouse absolute Y position}
    mCol : Word;                  {Logical column where mouse is located}
    mChoice : Word;               {Possible choice using mouse}
    MaxXinItem : Integer;         {Highest column to select item with mouse}
    S : String; {!!.08}           {String used determining if item is pickable}
  begin
    if PickMouseEnabled then begin

      {Compute absolute mouse coordinates}
      mX := MouseXLo+MouseKeyWordX;
      mY := MouseYLo+MouseKeyWordY;

      with WindowP(W)^, Draw do
        if MouseScroll and (mX = XH1) then begin
          {In the scroll bar region, scroll to new row}
          if mY = YL1 then
            {Treat like Up arrow or PgUp}
            EvaluateCommand(MouseUpCmd[PickMousePage])
          else if mY = YH1 then
            {Treat like Down arrow or PgDn}
            EvaluateCommand(MouseDownCmd[PickMousePage])
          else begin
            {Scroll proportional to slider bar}
            ScrollMouse(mY-YL);
            gChoice := CurrentChoice(gFirstChoice, gRow, gCol); {!!.08}
          end;
        end else if (mY >= YL) and (mY <= YH) then begin
          {In the active pick region, convert to window-relative}
          Dec(mX, X1-1);
          Dec(mY, Y1-1);
          {Leave a small dead space between columns}
          MaxXinItem := ItemWidth-2;
          if MaxXinItem < 1 then
            MaxXinItem := 1;
          if ((mX-1) mod ItemWidth) <= MaxXinItem then begin
            {Cursor is within an item}
            mCol := ((mX-1) div ItemWidth)+1;
            if (mCol <= PickMatrix) and (mY <= YSize) then begin {!!.08}
              mChoice := CurrentChoice(gFirstChoice, mY, mCol);
              if mChoice <= gNumItems then
                {Mouse points to a valid choice}
                if mChoice = gChoice then
                  {Select the item on the second click}
                  Cmd := PKSSelect
                else begin
                  {$IFDEF PickItemDisable} {!!.08}
                  {Determine if item is pickable}
                  S := GetString(mChoice);
                  if Pickable then begin
                  {$ENDIF}
                    {Move the highlight over the item}
                    gRow := mY;
                    gCol := mCol;
                    gChoice := mChoice;
                  {$IFDEF PickItemDisable} {!!.08}
                  end else
                    {Reset the Pickable flag}
                    Pickable := True;
                  {$ENDIF}
                end;
            end; {!!.08}
          end;
        end;
    end;
  end;

  procedure MouseDefaultXY(X, Y, CurX, CurY : Byte);
    {-Move mouse to absolute X,Y if it is outside of mouse window,
      else assure mouse remains unmoved}
  begin
    {Move mouse cursor only if mouse is outside window}
    if ((CurX <= MouseXLo) or (CurX > MouseXHi) or
        (CurY <= MouseYLo) or (CurY > MouseYHi)) then
      MouseGoToXY(X-MouseXLo, Y-MouseYLo)
    else
      MouseGoToXY(CurX-MouseXLo, CurY-MouseYLo);
  end;
  {$ENDIF}

  procedure FillPickWindow
    (W : WindowPtr;               {Which window to display pick list}
     StringFunc : Pointer;        {Pointer to function to return each item string}
     NumItems : Word;             {Number of items in PickArray}
     Colors : PickColorArray;     {Video attributes to use}
     Choice : Word;               {Choice,FirstChoice tell how to draw items}
     FirstChoice : Word);         {...in a manner consistent with PickBar}
    {-Display a window, fill it with choices, and return.
      Choice specifies the initial item highlighted.}
  var
    SaveMouseOn : Boolean;
    PickState : PickStateRec;
  begin
    {$IFDEF UseMouse}
    SaveMouseOn := MouseCursorOn;
    if SaveMouseOn then
      HideMouse;
    {$ENDIF}

    SavePickState(PickState);

    if InitPickVars(W, StringFunc, NumItems, Colors) then
      with WindowP(W)^, Draw do begin
        {Set global state variables <gChoice, gFirstChoice, gRow, gCol>}
        SetGlobalRowCol(Choice, FirstChoice);

        {Draw entire page}
        DrawPage;

        {$IFDEF UseMouse}
        if PickMouseEnabled and MouseScroll then begin
          {Draw scroll marks}
          DrawMouseMarks(W);
          FastWrite(ScrollMark, SliderPos, XH1, FAttr);
        end else                                             {!!.13}
          EraseMouseMarks(W);                                {!!.13}
        {$ENDIF}

        {Update the frame}
        DrawMore;
      end;

    RestorePickState(PickState);

    {$IFDEF UseMouse}
    if SaveMouseOn then
      ShowMouse;
    {$ENDIF}
  end;

  procedure EvaluatePickCommand
    (W : WindowPtr;               {The window to operate in}
     StringFunc : Pointer;        {Pointer to function to return items}
     NumItems : Word;             {The number of items to pick from}
     var Choice : Word;           {The item selected, range 1..NumItems}
     var FirstChoice : Word;      {The item in the upper left corner}
     var Cmd : PKType);           {Command to evaluate, modified only if mouse select}
    {-Evaluate a pick command}
  var
    PickState : PickStateRec;     {Entry values of pick globals}
  begin
    {Save current global state of pick system}
    SavePickState(PickState);

    {Initialize lower level variables}
    InitPickPrim(W, StringFunc, NumItems);

    {Set global state variables <gChoice, gFirstChoice, gRow, gCol>}
    SetGlobalRowCol(Choice, FirstChoice);

    case Cmd of
      PKSUp..PKSRight, PKSHome..PKSEnd :
        EvaluateCommand(Cmd);
      {$IFDEF UseMouse}
      PKSProbe :
        EvaluateMousePosition(W, Cmd);
      {$ENDIF}
    end;

    {Return the new values}
    Choice := gChoice;
    FirstChoice := gFirstChoice;

    RestorePickState(PickState);
  end;

  function CheckMatch(SItem : Word) : Boolean;
    {-Return true if item SItem matches SStr}
  var
    CmpStr : String[80];
  begin
    CmpStr := GetString(SItem);
    {$IFDEF PickItemDisable}
    if Pickable then begin
      {$ENDIF}
      CmpStr := TrimLead(CmpStr);
      CmpStr := Copy(CmpStr, SrchStart, Slen);
      CheckMatch := (CompUCString(SStr, CmpStr) = Equal);
      {$IFDEF PickItemDisable}
    end else begin
      CheckMatch := False;
      Pickable := True;
    end;
    {$ENDIF}
  end;

  function DefaultPickSrch(PickChar : Char; var Item : Word) : Boolean;
    {-Called to search for item using alphanumeric character}
  var
    SMatch : Boolean;
    SItem : Word;
  begin
    SMatch := False;
    SItem := Item;
    repeat
      if SItem > gNumItems then
        SItem := 0
      else
        SMatch := CheckMatch(SItem);
      if not SMatch then
        Inc(SItem);
    until SMatch or (SItem = Item);
    DefaultPickSrch := SMatch;
    Item := SItem;
  end;

  procedure DrawStringText(SStr : SrchString; Attr : Byte);
    {-Draw search string if we are doing string search}
  var
    Slen : Byte absolute SStr;
  begin
    if X1+Slen >= XMore then {!!.07}
      Slen := XMore-X1;      {!!.07}
    FastWrite(SStr, YMesg, X1, Attr);
  end;

  procedure PickBar
    (W : WindowPtr;               {The window to operate in}
     StringFunc : Pointer;        {Pointer to function to return items}
     NumItems : Word;             {The number of items to pick from}
     Colors : PickColorArray;     {Video attributes to use}
     EraseBar : Boolean;          {Should we recolor the bar when finished?}
     var Choice : Word;           {The item selected, range 1..NumItems}
     var FirstChoice : Word);     {Choice appearing in upper left corner of window}
    {-Choose from a pick list already displayed on the screen}
  label
    ExitPoint;
  var
    KW : Word;                    {Last key read by GetCommand}
    pFirstChoice : Word;          {Previous positions}
    pChoice : Word;
    pRow : Word;
    pCol : Word;
    SItem : Word;
    pSlen : Byte;
    Done : Boolean;               {True when ready to exit routine}
    SMatch : Boolean;             {True when search matches}
    SaveBreak : Boolean;          {Saved state of CheckBreak}
    XY : Word;                    {Cursor position on entry}
    CursorScanLines : Word;       {Cursor scan lines on entry}
    PickState : PickStateRec;     {Entry values of pick globals}
    DoneSearching : Boolean;      {True when alpha search loop completes}

    {$IFDEF PickItemDisable}
    GetNewCmd : Boolean;
    BadChoice : Word;
    InitialBadChoice : Word; {!!.10}
    {$ENDIF}

    {$IFDEF UseMouse}
    SaveMX : Byte;                {Saved mouse state}
    SaveMY : Byte;
    SaveMXL : Byte;
    SaveMXH : Byte;
    SaveMYL : Byte;
    SaveMYH : Byte;
    Slid : Byte;                  {Current scroll bar slider position}
    SaveWaitFor : Boolean;        {Saved WaitForButtonRelease variable}
    SaveMouseOn : Boolean;        {Was mouse cursor on at entry}
    {$ENDIF}

  begin
    {Save current global state of pick system}
    SavePickState(PickState);

    {Initialize the global variables for display}
    if not InitPickVars(W, StringFunc, NumItems, Colors) then
      goto ExitPoint;

    with WindowP(W)^, Draw do begin

      {Save cursor and break state}
      GetCursorState(XY, CursorScanLines);
      if HideCursor then
        HiddenCursor;
      SaveBreak := CheckBreak;
      CheckBreak := False;

      {$IFDEF UseMouse}
      if MouseInstalled then
        SaveMouseOn := MouseCursorOn;
      if PickMouseEnabled then begin
        {Save mouse position and window}
        SaveMX := MouseWhereX+MouseXLo; {Absolute}
        SaveMY := MouseWhereY+MouseYLo;
        SaveMXL := MouseXLo+1;
        SaveMXH := MouseXHi;
        SaveMYL := MouseYLo+1;
        SaveMYH := MouseYHi;
        SaveWaitFor := WaitForButtonRelease;
        WaitForButtonRelease := True;
        HideMouse;
        {Set mouse window around the pick list}
        if MouseScroll then begin
          {Let mouse move into frame}
          if PickMouseWindow then             {!!.21}
            MouseWindow(XL, YL1, XH1, YH1);
          {Draw scroll marks}
          DrawMouseMarks(W);
          MouseDefaultXY(MouseXLo+1, MouseYLo+2, SaveMX, SaveMY);
        end else begin
          {Don't let mouse move into frame}
          if PickMouseWindow then             {!!.21}
            MouseWindow(XL, YL, XH, YH);
          {Erase scroll marks} {!!.13}
          EraseMouseMarks(W);  {!!.13}
          MouseDefaultXY(MouseXLo+1, MouseYLo+1, SaveMX, SaveMY);
        end;
      end;
      {$ENDIF}

      {Set global state variables <gChoice, gFirstChoice, gRow, gCol>}
      SetGlobalRowCol(Choice, FirstChoice);

      {Initialize for loop}
      Done := False;
      pFirstChoice := 0;
      pSlen := 255;
      SMatch := False;
      {$IFDEF PickItemDisable}
      GetNewCmd := True;
      {$ENDIF}

      {Loop getting commands}
      repeat

        {$IFDEF PickItemDisable}
        if UnPickable(gChoice) then begin
          {Current choice is disabled}
          if GetNewCmd then begin
            {Repeat the last command to try another choice}
            BadChoice := gChoice;
            InitialBadChoice := BadChoice;                        {!!.10}
            GetNewCmd := False;
          end else begin
            {Repeating last command didn't get a pickable choice}
            if gChoice = BadChoice then begin
              {Repeating last command didn't change the choice}
              GetPickableChoice(PickCmdNum);
              GetNewCmd := True;
            end else begin                                        {!!.10}
              {Choice changed, try again}
              BadChoice := gChoice;
              if BadChoice = InitialBadChoice then begin          {!!.10}
                {Back to initial bad choice, search exhaustively} {!!.10}
                GetPickableChoice(PickCmdNum);                    {!!.10}
                GetNewCmd := True;                                {!!.10}
              end;
            end;                                                  {!!.10}
          end;
        end else
          {Got a pickable choice, let user input next command}
          GetNewCmd := True;
        {$ENDIF}

        {$IFDEF UseMouse}
        HideMouse;
        if PickMouseEnabled and MouseScroll then begin
          {Update slider in frame}
          Slid := SliderPos;
          if Slid <> PrevSlid then begin
            if PrevSlid <> 0 then
              FastWrite(VertChar, PrevSlid, XH1, PickColors[FrameAttr]);
            FastWrite(ScrollMark, Slid, XH1, PickColors[FrameAttr]);
            PrevSlid := Slid;
          end;
        end;
        {$ENDIF}

        {Update item display}
        if pFirstChoice <> gFirstChoice then begin
          {Window scrolled, redraw entire page}
          DrawPage;
          DrawMore;
          pFirstChoice := gFirstChoice;
        end else if (pRow <> gRow) or (pCol <> gCol) then begin
          {Unhighlight the previous item and highlight the new one}
          DrawItem(pChoice, pRow, pCol, False);
          DrawItem(gChoice, gRow, gCol, True);
        end;
        pChoice := gChoice;
        pRow := gRow;
        pCol := gCol;

        {Display search string if appropriate}
        if not SMatch or (PickSrch = CharPickSrch) then
          Slen := 0;
        case PickSrch of
          StringPickSrch, StringAltSrch :
            if PickSrchStat and PickIsFramed and (Slen <> pSlen) then begin
              if Slen = 0 then
                {Redraw the window frame}
                DrawStringText(CharStr(HorizChar, XSize), PickColors[FrameAttr])
              else
                {Draw the current search string}
                DrawStringText(' '+SStr+' ', PickColors[HeaderAttr]);
              pSlen := Slen;
            end;
        end;

        {Call user defined routine prior to each pick command}
        if PickUserPtr <> nil then
          MoveUserProc(gChoice);

        {$IFDEF UseMouse}
        if PickMouseEnabled then
          ShowMouse;
        {$ENDIF}

        if SMatch and (PickSrch = CharPickNow) then begin
          {Exit with last match found, forcing command to PKSSelect}
          PickCmdNum := PKSSelect;
          Done := True;

        end else begin
          {Clear previous search match}
          SMatch := False;

          {$IFDEF PickItemDisable}
          if GetNewCmd then begin
            {$ENDIF}
            {Get next command}
            PickCmdNum := GetCommand(PickKeySet, PickKeyPtr, KW);

            {Prepare character for return}
            PickChar := Char(Lo(KW));
            if PickChar = #0 then
              PickChar := Char(Hi(KW) or $80);
            {$IFDEF PickItemDisable}
          end;
          {$ENDIF}

          case PickCmdNum of
            PKSNone :             {Matches no known command}
              ;

            PKSAlpha :            {Alphanumeric, possibly used for searching}
              if PickSrch <> NoPickSrch then
                if (PickChar >= #32) and (PickChar <= #127) then begin
                  {Add to the search string}
                  if Slen < MaxSearchLen then begin
                    Inc(Slen);
                    SStr[Slen] := Upcase(PickChar);
                  end;

                  {Initial item to search}
                  case PickSrch of
                    CharPickSrch : SItem := gChoice+1;
                  else
                    SItem := gChoice;
                  end;

                  {Search each item for a match}
                  repeat
                    SMatch := SearchFunc(PickChar, SItem);
                    DoneSearching := True;
                    if SMatch then
                      {Set current choice to match}
                      SetGlobalRowCol(SItem, gFirstChoice)
                    else if (PickSrch = StringAltSrch) and (Slen > 1) then begin
                      {Reset the search, starting on the next item}
                      if PickSrchStat and PickIsFramed then
                        DrawStringText(CharStr(HorizChar, Slen+1), {!!.07}
                                       PickColors[FrameAttr]);
                      SStr[1] := SStr[Slen];
                      Slen := 1;
                      pSlen := 255; {!!.07}
                      SItem := gChoice+1;
                      DoneSearching := False;
                    end;
                  until DoneSearching;
                  {Reset pick flags, which GetString may have set True}
                  AltPickAttr := False;
                  PrivatePick := False;
                end;

            PKSUp..PKSRight, PKSHome..PKSEnd :
              EvaluateCommand(PickCmdNum);

            {$IFDEF UseMouse}
            PKSProbe :
              begin
                EvaluateMousePosition(W, PickCmdNum);
                {Mouse may have selected an item}
                if PickCmdNum = PKSSelect then
                  Done := True;
              end;
            {$ENDIF}

            PKSExit, PKSSelect,
            PKSUser0..PKSUser3 :  {Exit, Select}
              Done := True;

            PKSHelp :             {Help}
              if PickHelpPtr <> nil then
                HelpProc(HelpForPick, PickFunc, gChoice); {!!.07}

          end;                    {case PickCmdNum of}
        end;
      until Done;

      {Return the new values}
      Choice := gChoice;
      FirstChoice := gFirstChoice;

      {$IFDEF UseMouse}
      HideMouse;
      {$ENDIF}

      {Clean up the screen}
      if EraseBar then begin  {!!.07}
        DrawItem(gChoice, gRow, gCol, False);
        if HasMore then
          FastWrite(CharStr(HorizChar, MoreSpace), YMesg, XMore,
                    PickColors[FrameAttr]);
        {$IFDEF UseMouse}                                               {!!.13}
        if PickMouseEnabled and MouseScroll then                        {!!.13}
          if PrevSlid <> 0 then                                         {!!.13}
            FastWrite(VertChar, PrevSlid, XH1, PickColors[FrameAttr]);  {!!.13}
        {$ENDIF}                                                        {!!.13}
      end;

      {$IFDEF UseMouse}
      if PickMouseEnabled then begin
        {Restore mouse state}
        SaveMX := MouseWhereX+MouseXLo; {Absolute}
        SaveMY := MouseWhereY+MouseYLo;
        if PickMouseWindow then             {!!.21}
          MouseWindow(SaveMXL, SaveMYL, SaveMXH, SaveMYH);
        MouseDefaultXY((MouseXLo+MouseXHi) shr 1,
                       (MouseYLo+MouseYHi) shr 1,
                       SaveMX, SaveMY);
        WaitForButtonRelease := SaveWaitFor;
      end;
      if SaveMouseOn then
        ShowMouse;
      {$ENDIF}

      CheckBreak := SaveBreak;
      RestoreCursorState(XY, CursorScanLines);
    end;

ExitPoint:
    RestorePickState(PickState);
  end;

  function PickWindow
    (StringFunc : Pointer;        {Pointer to function to return each item string}
     NumItems : Word;             {Number of items to pick from}
     XLow, YLow : Byte;           {Window coordinates, including frame if any}
     XHigh, YHigh : Byte;         {Window coordinates, including frame if any}
     DrawFrame : Boolean;         {True to draw a frame around window}
     Colors : PickColorArray;     {Video attributes to use}
     Header : String;             {Title for window}
     var Choice : Word            {The item selected, in the range 1..NumItems}
     ) : Boolean;                 {True if PickWindow was successful}
    {-Display a window, let user scroll around in it, and return choice.
      Choice returned is in the range 1..NumItems.}
  label
    ExitPoint;
  var
    Correction : Integer;
    FirstChoice : Word;
    YWin : Word; {!!.07}
    W : WindowPtr;
    SaveMouseOn : Boolean;
    PickState : PickStateRec;
  begin
    {Assume failure}
    PickWindow := False;

    SavePickState(PickState); {!!.12} {Moved up}

    {$IFDEF UseMouse}
    SaveMouseOn := MouseCursorOn;
    if SaveMouseOn then
      HideMouse;
    PrevSlid := 0;
    {$ENDIF}

    {Get a value for YHigh}
    if DrawFrame then
      Correction := -1
    else
      Correction := +1;
    XSize := XHigh-XLow+Correction;
    YSize := YHigh-YLow+Correction;
    Lower(YSize, NumItems);
    Lower(YSize, PickMaxRows);
    ItemRows := (NumItems+PickMatrix-1) div PickMatrix;
    Raise(ItemRows, PickMinRows);
    Lower(ItemRows, NumItems);
    Lower(YSize, ItemRows);
    YWin := YSize;                 {!!.07}
    Raise(YWin, PickMinRows);      {!!.07}
    YHigh := YLow+YWin-Correction; {!!.07}

    {Initialize the window}
    if not MakeWindow(W, XLow, YLow, XHigh, YHigh,
                      DrawFrame, True, False,
                      Colors[WindowAttr], Colors[FrameAttr], Colors[HeaderAttr],
                      Header) then
      goto ExitPoint;

    {Reinitialize the pick variables and display the window}
    if not InitPickVars(W, StringFunc, NumItems, Colors) then
      goto ExitPoint;

    {Initial item is the one we say if legal}
    if (Choice < 1) or (Choice > NumItems) then
      Choice := 1;
    FirstChoice := 1;
    PickBar(W, PickFunc, NumItems, Colors, False, Choice, FirstChoice);

    {Restore the screen and deallocate the window}
    DisposeWindow(EraseTopWindow);

    {If we get to here, all was well}
    PickWindow := True;

ExitPoint:
    RestorePickState(PickState);

    {$IFDEF UseMouse}
    if SaveMouseOn then
      ShowMouse;
    {$ENDIF}
  end;

  function AddPickCommand(Cmd : PKType; NumKeys : Byte; Key1, Key2 : Word) : Boolean;
    {-Add a new command key assignment or change an existing one}
  begin
    AddPickCommand := AddCommandPrim(PickKeySet, PickKeyMax, Cmd, NumKeys, Key1, Key2);
  end;

  {$IFDEF UseMouse}
  procedure EnablePickMouse;
    {-Enable mouse control of pick lists}
  begin
    if MouseInstalled then begin
      PickKeyPtr := @TPMouse.ReadKeyOrButton;
      EnableEventHandling;
      PickMouseEnabled := True;
    end;
  end;

  procedure DisablePickMouse;
    {-Disable mouse control of pick lists}
  begin
    if PickMouseEnabled then begin
      PickKeyPtr := @ReadKeyWord;
      DisableEventHandling;
      PickMouseEnabled := False;
    end;
  end;
  {$ENDIF}

begin
  {Define procedure pointers}
  PickKeyPtr := @ReadKeyWord;
  PickUserPtr := nil;
  PickHelpPtr := nil;
  PickSrchPtr := @DefaultPickSrch;
  {$IFNDEF EnablePickOrientations}
  SetVerticalPick;
  {$ENDIF}
end.
