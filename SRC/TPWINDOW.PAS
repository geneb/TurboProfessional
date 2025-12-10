{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{Conditional defines that may affect this unit}
{$I TPDEFINE.INC}

{*********************************************************}
{*                  TPWINDOW.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TPWindow;
  {-High level support for text windows}

  {Special thanks to David Gerrold (yes, _the_ David Gerrold) for his help
   in optimizing the aesthetics of the exploding windows in this unit.}

interface

uses
  TPInline, {!!.12}
  TPMemChk,
  TPCrt;

type
  ShadowType = (SmallShadow, BigShadow);

const
  Shadow : Boolean = False;  {True to make shadowed windows}
  ShadowMode : ShadowType = BigShadow; {Kind of shadow to draw}
  ShadowAttr : Byte = $07;   {Attribute to apply to shadow}

  Explode : Boolean = False; {True to make exploding windows}
  ExplodeDelay : Word = 15;  {Milliseconds per stage of explosion}
  SoundFlagW : Boolean = True; {True to make sound during explosions}

type
  WindowPtr = Pointer;       {Generic type of a window}
  WindowP = ^WindowRec;      {Detailed type of a window}

  BufferArray = array[0..$7FF0] of Char; {Will hold screen image}
  BufP = ^BufferArray;

  SaveRec =
    record
      WMin : Word;           {Window coordinates}
      WMax : Word;
      CS : Byte;             {Cursor scan lines}
      CE : Byte;
      CX : Byte;             {Absolute cursor position}
      CY : Byte;
      Attr : Byte;           {TextAttr}
    end;

  WinDrawRec =               {Used while drawing and undrawing window}
    record
      Framed : Boolean;      {True to draw frame around window}
      Exploding : Boolean;   {True if window displays and erases in stages}
      Shadowed : Boolean;    {True to draw shadow around window}
      Noisy : Boolean;       {True to make noise while exploding}
      ExploDelay : Word;     {Milliseconds per stage of explosion}
      ShadowM : ShadowType;  {Type of shadow to draw}

      XL1, YL1 : Byte;       {Overall window coordinates (frame included)}
      XH1, YH1 : Byte;

      FAttr : Byte;          {Attribute for frame}
      WAttr : Byte;          {Attribute for window contents}
      HAttr : Byte;          {Attribute for header}
      SAttr : Byte;          {Attribute for window shadow}

      Covers : BufP;         {Points to buffer of what window covers}
      BufSize : Word;        {Size of screen buffers}

      Shadows : BufP;        {Points to buffer of what shadow covers}
      ShadowSize : Word;     {Size of buffer for shadow region}
    end;
  WinDrawPtr = ^WinDrawRec;

  WindowRec =                {Details of a window}
    record                   {74 bytes}
      Draw : WinDrawRec;     {Used while drawing and erasing window}

      XL, YL : Byte;         {Turbo window coordinates (no frame included)}
      XH, YH : Byte;

      HeaderP : ^string;     {Stores frame title, nil if none}
      Frame : FrameArray;    {Frame characters for this window}
      Current : SaveRec;     {Values to restore when this window is displayed}
      Previous : SaveRec;    {Values to restore when this window is erased}

      Holds : BufP;          {Points to buffer of what window holds if Save is True}

      Clear : Boolean;       {True to clear window when it is displayed}
      Save : Boolean;        {True to save contents when window is erased}
      Active : Boolean;      {True if window is currently on screen}
      DisplayedOnce : Boolean; {True if window displayed at least once}

      UFrame : FrameArray;   {Frame to draw when unselected}
      UFAttr : Byte;         {Attribute for unselected frame}
      UHAttr : Byte;         {Attribute for unselected header}
      FrameDiff : Boolean;   {True if select and unselect frames differ}
    end;

  VScreen =                  {Describes a virtual screen}
    record
      VRows : Word;          {Rows in the screen}
      VCols : Word;          {Columns in the screen}
      VSeg : Word;           {Segment where it's located}
      VEnd : Word;           {One past last valid offset in segment}
      VPtr : BufP;           {Allocated buffer}
    end;

var
  CurrentWindow : WindowPtr; {Currently active window}

function MakeWindow
  (var W : WindowPtr;        {Window identifier returned}
    XLow, YLow : Byte;       {Window coordinates, including frame if any}
    XHigh, YHigh : Byte;     {Window coordinates, including frame if any}
    DrawFrame : Boolean;     {True to draw a frame around window}
    ClearWindow : Boolean;   {True to clear window when displayed}
    SaveWindow : Boolean;    {True to save window contents when erased}
    WindowAttr : Byte;       {Video attribute for body of window}
    FrameAttr : Byte;        {Video attribute for frame}
    HeaderAttr : Byte;       {Video attribute for header}
    Header : string          {Title for window}
    ) : Boolean;             {Returns True if successful}
  {-Allocate and initialize, but do not display, a new window}

function DisplayWindow(W : WindowPtr) : Boolean;
  {-Display the specified window, returning true if successful}

function EraseTopWindow : WindowPtr;
  {-Erase the most recently displayed window, returning a pointer to it}

procedure DisposeWindow(W : WindowPtr);
  {-Deallocate heap space for specified window}

procedure KillWindow(var W : WindowPtr);
  {-Erase and dispose of window no matter where it is}

procedure KillTiledWindow(var W : WindowPtr);
  {-Erase and dispose of tiled window no matter where it is}

function WindowIsActive(W : WindowPtr) : Boolean;
  {-Return true if specified window is currently active}

procedure ScrollWindow(Up : Boolean; Lines : Byte);
  {-Scroll current window Up or down (Up=False) the designated number of Lines}

function MoveWindow(XDelta, YDelta : Integer) : Boolean;
  {-Move current window by specified distance. Positive means right or down.}

function ResizeWindow(XDelta, YDelta : Integer; Fill : Char) : Boolean;
  {-Resize right and/or lower edges of window. Positive means right or down.}

function SetTopWindow(W : WindowPtr) : Boolean;
  {-Make an already active, stacked window the current one}

function SetTopTiledWindow(W : WindowPtr) : Boolean;
  {-Make an already active, tiled window the current one}

function ActivateWindow(W : WindowPtr) : Boolean;
  {-Display or reselect a stacked window}

function ActivateTiledWindow(W : WindowPtr) : Boolean;
  {-Display or reselect a tiled window}

procedure SetInactiveFrame(W : WindowPtr;
                           Fr : FrameArray;
                           FrameAttr : Byte;
                           HeaderAttr : Byte);
  {-Set the specified frame type and attribute for selected windows}

procedure FastWriteClip(S : string; Row, Col, Attr : Byte);
  {-Write S in active window, using window-relative coordinates,
    clipping at right edge}

procedure FastWriteStack(W : WindowPtr;
                         S : string; Row, Col, Attr : Byte);
  {-Write to specified window, whether or not it's hidden under a stack}

  {-----------------------------------------------------------------------}
  {The following routines are for managing virtual screens, TPWINDOW style}

function MakeVScreen(var V : VScreen; Rows, Cols : Word) : Boolean;
  {-Return true after allocating a virtual screen}

procedure DisposeVScreen(var V : VScreen);
  {-Deallocate space for virtual screen}

procedure ClearVScreen(V : VScreen; Attr : Byte; Fill : Char);
  {-Clear a virtual screen with specified attribute and character}

procedure WriteVScreen(V : VScreen; S : string; Row, Col : Word; Attr : Byte);
  {-Write a string to specified virtual screen}

procedure ReadVScreen(V : VScreen; Number : Byte;
                      Row, Col : Word; var S : string);
  {-Read number characters from the virtual screen starting at Row,Col}

procedure ActivateVScreen(V : VScreen);
  {-Switch fastwriting to the specified virtual screen}

  {After calling ActivateVScreen, the following routines will write to
   the virtual screen:
     FastWrite         FastText        FastVert         FastFill
     FastRead          ReadAttribute   ChangeAttribute  FlexWrite
     FrameWindow

   Do NOT attempt to use the following calls to write to the virtual screen:
     Write             WriteLn
     FastWriteWindow   FastTextWindow  FastVertWindow   FastFillWindow
     FastCenter        FastFlush       FastReadWindow   ReadAttributeWindow
     ChangeAttributeWindow             FlexWriteWindow
  }

procedure DeactivateVScreen;
  {-Restore fastwriting to the physical screen}

procedure MoveVScreenToWindow(V : VScreen; Row, Col : Word);
  {-Copy contents of virtual screen at Row,Col to current window}

procedure MoveWindowToVScreen(V : VScreen; Row, Col : Word);
  {-Copy contents of current window to virtual screen at Row, Col}

function VScreenRows(V : VScreen) : Word;
  {-Return number of rows in virtual screen}

function VScreenCols(V : VScreen) : Word;
  {-Return number of columns in virtual screen}

  {--------------------------------------------------------------------}
  {The following routines are interfaced for the primary use of TPMENU }

procedure ExplodeFrame(W : WinDrawPtr);
  {-Explode a window frame}

procedure ImplodeFrame(W : WinDrawPtr);
  {-Erase an exploding window from the screen}

procedure SaveShadowFrame(W : WinDrawPtr);
  {-Save the screen region under the window shadow}

procedure DrawShadowFrame(W : WinDrawPtr);
  {-Shadow a window by changing the attributes of underlying text}

procedure RestoreShadowFrame(W : WinDrawPtr);
  {-Restore screen region under shadow}

  {===================================================================}

implementation

const
  ShadowXofs : array[ShadowType] of Byte = (1, 2);

type
  WindowStackP = ^WindowStackRec;
  WindowStackRec =           {Manages stack of active windows}
    record
      Top : WindowPtr;
      Next : WindowStackP;
    end;

  VWindow =                  {Virtual image of a window}
    record
      XLv : Byte;            {Coordinates of real window}
      XHv : Byte;
      YLv : Byte;
      YHv : Byte;
      VWid : Word;           {Bytes in one row, including attributes}
      VSiz : Word;           {Bytes in virtual buffer}
      VP : BufP;             {Pointer to virtual buffer}
    end;

  SO =
    record
      O : Word;
      S : Word;
    end;

var
  WindowStack : WindowStackP; {Stack of active windows}

  function StringFromHeap(P : Pointer) : string;
    {-Return a string, empty if pointer is nil}
  var
    Pt : ^string absolute P;
  begin
    if Pt = nil then
      StringFromHeap := ''
    else
      StringFromHeap := Pt^;
  end;

  function PushStack(var WindowStack : WindowStackP; W : WindowPtr) : Boolean;
    {-Put a new window onto specified stack}
  var
    WS : WindowStackP;
  begin
    if not GetMemCheck(WS, SizeOf(WindowStackRec)) then begin
      PushStack := False;
      Exit;
    end;
    WS^.Top := W;
    WS^.Next := WindowStack;
    WindowStack := WS;
    PushStack := True;
  end;

  function PopStack(var WindowStack : WindowStackP) : WindowPtr;
    {-Pop window stack and return window at top of stack}
  var
    WS : WindowStackP;
  begin
    PopStack := nil;
    if WindowStack = nil then
      Exit;
    WS := WindowStack;
    WindowStack := WS^.Next;
    FreeMemCheck(WS, SizeOf(WindowStackRec));
    if WindowStack <> nil then
      PopStack := WindowStack^.Top;
  end;

  procedure DisposeWindow(W : WindowPtr);
    {-Deallocate heap space for specified window}
  begin
    if W = nil then
      Exit;
    with WindowP(W)^, Draw do begin
      if HeaderP <> nil then                         {!!.20}
        FreeMemCheck(HeaderP, Length(HeaderP^)+1);
      FreeMemCheck(Holds, BufSize);
      FreeMemCheck(Covers, BufSize);
      {$IFDEF ShadowedWindows}
      FreeMemCheck(Shadows, ShadowSize);
      {$ENDIF}
    end;
    FreeMemCheck(W, SizeOf(WindowRec));
  end;

  procedure SaveCurrentState(W : WindowPtr; ResetXY : Boolean);
    {-Store window-relative state information}
  begin
    with WindowP(W)^, Current do begin
      CS := CursorStartLine;
      CE := CursorEndLine;
      if ResetXY then begin
        CX := XL;
        CY := YL;
      end else begin
        CX := WhereXAbs;
        CY := WhereYAbs;
      end;
    end;
  end;

  procedure SetCurrentState(W : WindowPtr);
    {-Set the parameters for the current window}
  begin
    with WindowP(W)^, Current do begin
      Window(XL, YL, XH, YH);
      SetCursorSize(CS, CE);
      GoToXYAbs(CX, CY);
    end;
    CurrentWindow := W;
  end;

  procedure SavePreviousState(var Previous : SaveRec);
    {-Get settings for the current screen state}
  begin
    with Previous do begin
      CS := CursorStartLine;
      CE := CursorEndLine;
      CX := WhereXAbs;
      CY := WhereYAbs;
      Attr := TextAttr;
      WMin := WindMin;
      WMax := WindMax;
    end;
  end;

  function MakeWindow
    (var W : WindowPtr;      {Window identifier returned}
      XLow, YLow : Byte;     {Window coordinates, including frame if any}
      XHigh, YHigh : Byte;   {Window coordinates, including frame if any}
      DrawFrame : Boolean;   {True to draw a frame around window}
      ClearWindow : Boolean; {True to clear window when displayed}
      SaveWindow : Boolean;  {True to save window contents when erased}
      WindowAttr : Byte;     {Video attribute for body of window}
      FrameAttr : Byte;      {Video attribute for frame}
      HeaderAttr : Byte;     {Video attribute for header}
      Header : string        {Title for window}
      ) : Boolean;           {Returns True if successful}
    {-Allocate and initialize, but do not display, a new window}
  var
    Wd, Ht : Word;
  begin
    {Prepare for the worst}
    MakeWindow := False;

    {Allocate the window descriptor}
    if not GetMemCheck(W, SizeOf(WindowRec)) then
      Exit;

    with WindowP(W)^, Draw do begin
      {Compute screen buffer size}
      Wd := XHigh-XLow+1;
      Ht := YHigh-YLow+1;
      BufSize := 2*Wd*Ht;

      {Initialize pointers to screen buffers}
      Covers := nil;
      Holds := nil;
      HeaderP := nil;
      {$IFDEF ShadowedWindows}
      Shadows := nil;
      {$ENDIF}

      {Allocate the Covers buffer}
      if not GetMemCheck(Covers, BufSize) then begin
        DisposeWindow(W);
        Exit;
      end;

      {Allocate the Holds buffer if desired}
      if SaveWindow then
        if not GetMemCheck(Holds, BufSize) then begin
          DisposeWindow(W);
          Exit;
        end;

      {Store header string if specified}
      if Header <> '' then begin
        if not GetMemCheck(HeaderP, Length(Header)+1) then begin
          DisposeWindow(W);
          Exit;
        end;
        HeaderP^ := Header;
      end;

      {$IFDEF ShadowedWindows}
      if (XHigh+ShadowXOfs[ShadowMode] > ScreenWidth) or (YHigh >= ScreenHeight) then  {!!.13}
        {Shadow won't fit on screen}
        Shadowed := False
      else begin
        if Shadow then begin
          ShadowSize := 2*(Wd+2*Ht);
          if not GetMemCheck(Shadows, ShadowSize) then begin
            DisposeWindow(W);
            Exit;
          end;
          SAttr := MapColor(ShadowAttr);
          ShadowM := ShadowMode;
        end;
        Shadowed := Shadow;
      end;
      {$ENDIF}

      {Initialize remaining fields}
      WAttr := MapColor(WindowAttr);
      HAttr := MapColor(HeaderAttr);
      if (Wd <= 2) or (Ht <= 2) then
        DrawFrame := False;
      if DrawFrame then begin
        {Correct for size of frame}
        XL := XLow+1;
        XH := XHigh-1;
        YL := YLow+1;
        YH := YHigh-1;
        {Store current frame array}
        Frame := FrameChars;
        FAttr := MapColor(FrameAttr);
      end else begin
        XL := XLow;
        XH := XHigh;
        YL := YLow;
        YH := YHigh;
        Frame := '      ';
        FAttr := WAttr;
      end;
      {Unselected frame same as selected by default}
      UFrame := Frame;
      UFAttr := FAttr;
      UHAttr := HAttr;
      FrameDiff := False;
      XL1 := XLow;
      XH1 := XHigh;
      YL1 := YLow;
      YH1 := YHigh;
      {Make sure window coordinates are legal}
      if (XL > XH) or (YL > YH) then begin
        DisposeWindow(W);
        Exit;
      end;
      Framed := DrawFrame;
      Clear := ClearWindow;
      Save := SaveWindow;
      Active := False;
      DisplayedOnce := False;
      with Current do begin
        WMin := XL or Swap(YL);
        WMax := XH or Swap(YH);
      end;

      {$IFDEF ExplodingWindows}
      {Initialize for exploding windows}
      if (XH1-XL1 < 2) and (YH1-YL1 < 2) then
        Exploding := False
      else
        Exploding := Explode;
      ExploDelay := ExplodeDelay;
      Noisy := SoundFlagW;
      {$ENDIF}

      {Store initial state for this window}
      SaveCurrentState(W, True);
    end;

    {Success}
    MakeWindow := True;
  end;

  procedure RestoreRect(W : WinDrawPtr; XLc, YLc, XHc, YHc : Byte);
    {-Restore a rectangular screen chunk from the Covers buffer}
  var
    fBPR, cBPR, R : Byte;
    fOfs, cOfs : Word;
  begin
    with W^ do begin
      {Get the bytes per row in full window and in chunk}
      fBPR := 2*(XH1-XL1+1);
      cBPR := XHc-XLc+1;
      {Get the first address to use in the Covers buffer}
      fOfs := fBPR*(YLc-YL1)+2*(XLc-XL1);
      {Get the first address on the screen to restore}
      cOfs := 2*(ScreenWidth*(YLc-1)+(XLc-1));
      {Restore row by row}
      for R := YLc to YHc do begin
        MoveScreen(Covers^[fOfs], MemW[VideoSegment:cOfs], cBPR);
        Inc(fOfs, fBPR);
        Inc(cOfs, 2*ScreenWidth);
      end;
    end;
  end;

  procedure ClearRegion(XL, YL, XH, YH, Attr : Byte);
    {-Clear a region with specified attribute}
  var
    WordsPerRow, Row : Word;
    Span : string;
  begin
    WordsPerRow := XH-XL+1;
    Span[0] := Chr(WordsPerRow);
    FillChar(Span[1], WordsPerRow, ' ');
    for Row := YL to YH do
      FastWrite(Span, Row, XL, Attr);
  end;

  procedure SetDeltas(var SD, BD : Real; var Frames : Integer);
    {-Compute dimensions for exploding frame}
  begin
    Frames := Round(BD);
    if SD < 1.0 then
      SD := 1.0/(Frames+1);
    SD := SD/BD;
    BD := 1.0;
  end;

  procedure ComputeDeltas(W : WinDrawPtr;
                          var XD, YD : Real;
                          var Frames : Integer);
    {-Compute information for exploding frame boundaries}
  begin
    with W^ do begin
      XD := (XH1-XL1+1)/2.0-0.55; {Fudge factor}
      YD := (YH1-YL1+1)/2.0-0.55;
      if XD < YD then
        SetDeltas(XD, YD, Frames)
      else
        SetDeltas(YD, XD, Frames);
    end;
  end;

  procedure ExplodeFrame(W : WinDrawPtr);
    {-Explode a window frame}
  var
    XD, YD, dX, dY : Real;
    Frames, F : Integer;
    cXL, cXH, cYL, cYH : Byte;
  begin
    with W^ do begin
      {Compute the smallest frame that will fit}
      ComputeDeltas(W, XD, YD, Frames);

      {Draw a series of frames}
      F := Frames-1;
      while F >= 0 do begin
        {Erase region}
        dX := F*XD;
        dY := F*YD;
        cXL := Trunc(XL1+dX);
        cYL := Trunc(YL1+dY);
        cXH := Round(XH1-dX);
        cYH := Round(YH1-dY);
        ClearRegion(cXL, cYL, cXH, cYH, WAttr);
        if Framed then
          {Draw frame around window}
          FrameWindow(cXL, cYL, cXH, cYH, FAttr, HAttr, '');
        {Make a sound}
        if Noisy then
          Sound(1320-F*35);
        if (Frames > 10) and (F > 1) then
          {Use only half the frames for big windows}
          Dec(F);
        Dec(F);
        Delay(ExploDelay);
      end;
      if Noisy then {!!.11}
        NoSound;
    end;
  end;

  procedure ImplodeFrame(W : WinDrawPtr);
    {-Erase an exploding window from the screen}
  var
    XD, YD, dX, dY : Real;
    Frames, F : Integer;
    pXL, pXH, pYL, pYH : Byte;
    cXL, cXH, cYL, cYH : Byte;
  begin
    with W^ do begin

      {Compute the smallest frame that will fit}
      ComputeDeltas(W, XD, YD, Frames);

      {Restore underlying screen in stages}
      pXL := XL1;
      pXH := XH1;
      pYL := YL1;
      pYH := YH1;

      F := 1;
      while F < Frames do begin
        dX := F*XD;
        dY := F*YD;
        cXL := Trunc(XL1+dX);
        cYL := Trunc(YL1+dY);
        cXH := Round(XH1-dX);
        cYH := Round(YH1-dY);
        if YL1 <> YH1 then begin
          RestoreRect(W, pXL, pYL, pXH, cYL);
          RestoreRect(W, pXL, cYH, pXH, pYH);
        end;
        if XL1 <> XH1 then begin
          RestoreRect(W, pXL, cYL, cXL, cYH);
          RestoreRect(W, cXH, cYL, pXH, cYH);
        end;
        if Framed then
          {Draw frame around window}
          FrameWindow(cXL, cYL, cXH, cYH, FAttr, HAttr, '');
        pXL := cXL;
        pXH := cXH;
        pYL := cYL;
        pYH := cYH;
        if Noisy then
          {Make a sound}
          Sound(1320-F*35);
        if (Frames > 10) and (F < Frames-2) then
          {Use only half the frames for big windows}
          Inc(F);
        Inc(F);
        Delay(ExploDelay);
      end;
      if Noisy then {!!.11}
        NoSound;
    end;
  end;

  procedure SaveShadowFrame(W : WinDrawPtr);
    {-Save the screen region under the window shadow}
  var
    P : Pointer;
    XOfs : Byte;
  begin
    with W^ do begin
      XOfs := ShadowXofs[ShadowM];
      {Save horizontal strip}
      P := Shadows;
      if SaveWindow(XL1+XOfs, YH1+1, XH1+XOfs, YH1+1, False, P) then ;
      {Save vertical strip}
      P := @Shadows^[2*(XH1-XL1+1)];
      if SaveWindow(XH1+1, YL1, XH1+XOfs, YH1, False, P) then ;
    end;
  end;

  procedure DrawShadowFrame(W : WinDrawPtr);
    {-Shadow a window by changing the attributes of underlying text}
  var
    Row : Byte;
    Strip : string;
  begin
    with W^ do
      case ShadowM of
        SmallShadow:
          begin
            {Draw horizontal strip}
            Strip[0] := Char(XH1-XL1+1);
            FillChar(Strip[1], Byte(Strip[0]), #223);
            FastWrite(Strip, YH1+1, XL1+1, SAttr);
            {Draw vertical strip}
            for Row := YL1+1 to YH1 do
              FastWrite(#219, Row, XH1+1, SAttr);
          end;
        BigShadow:
          begin
            {Change attribute of horizontal strip}
            ChangeAttribute(XH1-XL1+1, YH1+1, XL1+2, SAttr);
            {Change attribute of vertical strip}
            for Row := YL1+1 to YH1 do
              ChangeAttribute(2, Row, XH1+1, SAttr);
          end;
      end;
  end;

  procedure RestoreShadowFrame(W : WinDrawPtr);
    {-Restore screen region under shadow}
  var
    P : Pointer;
    XOfs : Byte;
  begin
    with WindowP(W)^, Draw do begin
      XOfs := ShadowXofs[ShadowM];
      {Restore horizontal strip}
      P := Shadows;
      RestoreWindow(XL1+XOfs, YH1+1, XH1+XOfs, YH1+1, False, P);
      {Restore vertical strip}
      P := @Shadows^[2*(XH1-XL1+1)];
      RestoreWindow(XH1+1, YL1, XH1+XOfs, YH1, False, P);
    end;
  end;

  function DisplayWindow(W : WindowPtr) : Boolean;
    {-Display the specified window, returning true if successful}
  var
    SaveFrame : FrameArray;
  begin
    DisplayWindow := False;

    if W = nil then
      Exit;

    with WindowP(W)^, Draw do begin
      if Active then
        {Window already on screen - can't do it twice}
        Exit;

      {Put window on active stack}
      if not PushStack(WindowStack, W) then
        Exit;

      {Save window information prior to displaying current window}
      SavePreviousState(Previous);

      {Turn off the cursor while drawing occurs}
      HiddenCursor;

      {Save the frame characters}
      SaveFrame := FrameChars;

      {Draw unselected frame on currently active window}
      if CurrentWindow <> nil then
        with WindowP(CurrentWindow)^, Draw do
          if FrameDiff then begin
            FrameChars := UFrame;
            FrameWindow(XL1, YL1, XH1, YH1, UFAttr, UHAttr, StringFromHeap(HeaderP));
          end;

      {!!.09 the following block was moved down}
      {Save what window will cover}
      if SaveWindow(XL1, YL1, XH1, YH1, False, Pointer(Covers)) then ;
      {$IFDEF ShadowedWindows}
      if Shadowed then
        SaveShadowFrame(WinDrawPtr(W));
      {$ENDIF}
      {!!.09}

      {Set the new text attribute and window coordinates}
      TextAttr := WAttr;
      Window(XL, YL, XH, YH);

      {Set the frame chars for this window}
      FrameChars := Frame;

      {$IFDEF ExplodingWindows}
      if Exploding then
        ExplodeFrame(WinDrawPtr(W));
      {$ENDIF}

      if Save and DisplayedOnce then
        {Previous image of window available to restore}
        RestoreWindow(XL1, YL1, XH1, YH1, False, Pointer(Holds))
      else begin
        if Framed then
          {Draw frame around window}
          FrameWindow(XL1, YL1, XH1, YH1, FAttr, HAttr, StringFromHeap(HeaderP));
        if Clear then
          {Clear the window}
          ClrScr;
      end;

      {$IFDEF ShadowedWindows}
      if Shadowed then
        DrawShadowFrame(W);
      {$ENDIF}

      SetCurrentState(W);
      Active := True;
      DisplayedOnce := True;

    end;

    FrameChars := SaveFrame;
    DisplayWindow := True;
  end;

  function EraseTopWindow : WindowPtr;
    {-Erase the most recently displayed window, returning a pointer to it}
  var
    SaveFrame : FrameArray;
  begin
    EraseTopWindow := CurrentWindow;
    if CurrentWindow = nil then
      {No Professional windows on screen now}
      Exit;

    with WindowP(CurrentWindow)^, Draw do begin
      {Save cursor information to restore when window is reselected}
      SaveCurrentState(CurrentWindow, Clear and not Save); {!!.05}

      {Turn off the cursor while drawing occurs}
      HiddenCursor;

      if Save then
        {Save what window currently holds}
        if SaveWindow(XL1, YL1, XH1, YH1, False, Pointer(Holds)) then ;

      {Remove window from screen}
      {$IFDEF ShadowedWindows}
      if Shadowed then
        RestoreShadowFrame(WinDrawPtr(CurrentWindow));
      {$ENDIF}

      SaveFrame := FrameChars;
      FrameChars := Frame;

      {$IFDEF ExplodingWindows}
      if Exploding then
        ImplodeFrame(WinDrawPtr(CurrentWindow));
      {$ENDIF}
      {Restore screen}
      RestoreWindow(XL1, YL1, XH1, YH1, False, Pointer(Covers));

      {Restore settings as they were when this window popped up}
      with Previous do begin
        TextAttr := Attr;
        WindMin := WMin;
        WindMax := WMax;
        SetCursorSize(CS, CE);
        GoToXYAbs(CX, CY);
      end;
      Active := False;
    end;

    {Pop the window stack}
    CurrentWindow := PopStack(WindowStack);

    {Draw selected frame on currently active window}
    if CurrentWindow <> nil then
      with WindowP(CurrentWindow)^, Draw do
        if FrameDiff then begin
          FrameChars := Frame;
          FrameWindow(XL1, YL1, XH1, YH1, FAttr, HAttr, StringFromHeap(HeaderP));
        end;

    FrameChars := SaveFrame;
  end;

  function WindowIsActive(W : WindowPtr) : Boolean;
    {-Return true if specified window is currently active}
  begin
    with WindowP(W)^ do
      WindowIsActive := Active;
  end;

  procedure ScrollWindow(Up : Boolean; Lines : Byte);
    {-Scroll current window Up or down (Up=False) the designated number of Lines}
  begin
    with WindowP(CurrentWindow)^ do
      if Up then
        ScrollWindowUp(XL, YL, XH, YH, Lines)
      else
        ScrollWindowDown(XL, YL, XH, YH, Lines);
  end;

  function ScreenPtr(R, C : Byte) : Pointer;
    {-Return pointer to screen memory at position R,C}
  begin
    ScreenPtr := Ptr(VideoSegment, 2*(ScreenWidth*(R-1)+C-1));
  end;

  function Min(A, B : Integer) : Integer;
    {-Return lesser of A and B}
  begin
    if A < B then
      Min := A
    else
      Min := B;
  end;

  function Max(A, B : Integer) : Integer;
    {-Return greater of A and B}
  begin
    if A > B then
      Max := A
    else
      Max := B;
  end;

  function InitVWindow(var V : VWindow; XL, YL, XH, YH : Byte) : Boolean;
    {-Allocate and initialize virtual screen}
  var
    vOfs : Word;
    R : Byte;
  begin
    InitVWindow := False;
    with V do begin
      XLv := XL;
      YLv := YL;
      XHv := XH;
      YHv := YH;
      VWid := 2*(XHv-XLv+1);
      VSiz := VWid*(YHv-YLv+1);
      {Allocate heap space}
      if not GetMemCheck(VP, VSiz) then
        Exit;
      {Copy existing screen to virtual buffer}
      vOfs := 0;
      for R := YLv to YHv do begin
        MoveScreen(ScreenPtr(R, XLv)^, VP^[vOfs], VWid shr 1);
        Inc(vOfs, VWid);
      end;
    end;
    InitVWindow := True;
  end;

  procedure UndoVWindow(var V : VWindow);
    {-Copy virtual screen to physical screen and deallocate its space}
  var
    R : Byte;
    vOfs : Word;
  begin
    with V do begin
      {Copy buffer back to screen}
      vOfs := 0;
      for R := YLv to YHv do begin
        MoveScreen(VP^[vOfs], ScreenPtr(R, XLv)^, VWid shr 1);
        Inc(vOfs, VWid);
      end;
      {Release virtual screen space}
      FreeMemCheck(VP, VSiz);
    end;
  end;

  procedure TransferVWindow(XL, YL, XH, YH : Byte; V : VWindow;
                            P : BufP; ToV : Boolean);
    {-Transfer screen data from P^ into or out of the virtual screen}
  var
    R : Byte;
    POfs, vOfs : Word;
    Bytes : Word;
  begin
    with V do begin
      vOfs := VWid*(YL-YLv)+2*(XL-XLv);
      POfs := 0;
      Bytes := 2*(XH-XL+1);
      for R := YL to YH do begin
        if ToV then
          Move(P^[POfs], VP^[vOfs], Bytes)
        else
          Move(VP^[vOfs], P^[POfs], Bytes);
        Inc(POfs, Bytes);
        Inc(vOfs, VWid);
      end;
    end;
  end;

  procedure WriteVWindow(S : string; Row, Col : Byte;
                         Attr : Byte; V : VWindow);
    {-"Write" a string to a virtual screen}
  var
    SOfs : Word;
    vOfs : Word;
  begin
    with V do begin
      vOfs := VWid*(Row-YLv)+2*(Col-XLv);
      for SOfs := 1 to Length(S) do begin
        VP^[vOfs] := S[SOfs];
        Inc(vOfs);
        VP^[vOfs] := Char(Attr);
        Inc(vOfs);
      end;
    end;
  end;

  procedure TransferVShadow(XL, YL, XH, YH, XOfs : Byte; V : VWindow;
                            Shadows : BufP; ToV : Boolean);
    {-Transfer window shadow to or from virtual window}
  var
    P : BufP;
  begin
    P := Shadows;
    TransferVWindow(XL+XOfs, YH+1, XH+XOfs, YH+1, V, P, ToV);
    P := @Shadows^[2*(XH-XL+1)];
    TransferVWindow(XH+1, YL, XH+XOfs, YH, V, P, ToV);
  end;

  procedure ShadowVWindow(XL, YL, XH, YH : Byte; V : VWindow;
                          Mode : ShadowType; ShChar : Char; ShAttr : Byte);
    {-Shadow a rectangular region of virtual window}
  var
    R, C : Byte;
    vOfs, SOfs : Word;
  begin
    with V do begin
      vOfs := VWid*(YL-YLv)+2*(XL-XLv);
      for R := YL to YH do begin
        SOfs := vOfs;
        for C := XL to XH do begin
          if Mode = SmallShadow then
            VP^[vOfs] := ShChar;
          VP^[vOfs+1] := Char(ShAttr);
          Inc(vOfs, 2);
        end;
        vOfs := SOfs+VWid;
      end;
    end;
  end;

  procedure CopyToVWindow(V : VWindow; W : WindowPtr);
    {-Copy window W to virtual screen V}
  var
    ShDX : Byte;
  begin
    with WindowP(W)^, Draw, V do begin
      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Save the new Shadows buffer}
        ShDX := ShadowXofs[ShadowM];
        TransferVShadow(XL1, YL1, XH1, YH1, ShDX, V, Shadows, False);
      end;
      {$ENDIF}
      {Save the new Covers buffer from virtual buffer}
      TransferVWindow(XL1, YL1, XH1, YH1, V, Covers, False);
      if Save then
        {Write the window Save buffer to the virtual buffer}
        TransferVWindow(XL1, YL1, XH1, YH1, V, Holds, True);
      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Draw new shadows}
        ShadowVWindow(XL1+shDX, YH1+1, XH1+shDX, YH1+1, V, ShadowM, #223, SAttr);
        ShadowVWindow(XH1+1, YL1+1, XH1+shDX, YH1, V, ShadowM, #219, SAttr); {!!.12}
      end;
      {$ENDIF}
    end;
  end;

  procedure FrameVWindow(V : VWindow; XL, YL, XH, YH : Byte;
                         FAttr, HAttr : Byte; Header : string);
    {-Frame a window on the virtual screen}
  var
    HeaderLen : Byte absolute Header;
    Row, Width, HeaderPos : Byte;
    Span : string[132];
    SpanLen : Byte absolute Span;
  begin
    with V do begin
      {calculate width of window and position of header}
      SpanLen := (XH-XL+1);
      Width := SpanLen-2;

      {construct the upper border and draw it}
      FillChar(Span[2], Width, FrameChars[Horiz]);
      Span[1] := FrameChars[ULeft];
      Span[SpanLen] := FrameChars[URight];
      WriteVWindow(Span, YL, XL, FAttr, V);

      {draw the vertical bars}
      for Row := YL+1 to YH-1 do begin
        WriteVWindow(FrameChars[Vert], Row, XL, FAttr, V);
        WriteVWindow(FrameChars[Vert], Row, XH, FAttr, V);
      end;

      {draw the bottom border}
      Span[1] := FrameChars[LLeft];
      Span[SpanLen] := FrameChars[LRight];
      WriteVWindow(Span, YH, XL, FAttr, V);

      if HeaderLen > 0 then begin
        if HeaderLen > Width then
          HeaderLen := Width;
        HeaderPos := (SpanLen-HeaderLen) shr 1;
        WriteVWindow(Header, YL, XL+HeaderPos, HAttr, V);
      end;
    end;
  end;

  function MoveWindow(XDelta, YDelta : Integer) : Boolean;
    {-Move current window by specified distance. Positive means right or down}
  var
    R, ShDX, ShDY : Byte;
    nXL1, nXH1, nYL1, nYH1 : Integer;
    XH2, YH2, nXH2, nYH2 : Integer;
    Wid, vOfs : Word;
    V : VWindow;
  begin
    MoveWindow := False;
    if CurrentWindow = nil then
      Exit;

    with WindowP(CurrentWindow)^, Draw, V do begin

      {Compute new window position}
      nXL1 := XL1+XDelta;
      nXH1 := XH1+XDelta;
      nYL1 := YL1+YDelta;
      nYH1 := YH1+YDelta;

      {Subscript 2 also includes space for shadow, if any}
      ShDX := 0;
      ShDY := 0;
      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        ShDX := ShadowXofs[ShadowM];
        ShDY := 1;
      end;
      {$ENDIF}
      YH2 := YH1+ShDY;
      XH2 := XH1+ShDX;
      nYH2 := nYH1+ShDY;
      nXH2 := nXH1+ShDX;

      {Assure legal window}
      if (nXL1 < 1) or (nYL1 < 1) then
        Exit;
      if (nXH2 > ScreenWidth) or (nYH2 > ScreenHeight) then
        Exit;

      {Initialize virtual screen}
      if not InitVWindow(V, Min(XL1, nXL1), Min(YL1, nYL1),
        Max(XH2, nXH2), Max(YH2, nYH2)) then
        Exit;

      {Update cursor state before moving}
      SaveCurrentState(CurrentWindow, False); {!!.07}

      {Erase window from virtual buffer}
      TransferVWindow(XL1, YL1, XH1, YH1, V, Covers, True);

      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Erase shadow from virtual buffer}
        TransferVShadow(XL1, YL1, XH1, YH1, ShDX, V, Shadows, True);
        {Save the new Shadows buffer}
        TransferVShadow(nXL1, nYL1, nXH1, nYH1, ShDX, V, Shadows, False);
      end;
      {$ENDIF}

      {Save the new Covers buffer from virtual buffer}
      TransferVWindow(nXL1, nYL1, nXH1, nYH1, V, Covers, False);

      {Copy contents of window to virtual buffer in new position}
      vOfs := VWid*(nYL1-YLv)+2*(nXL1-XLv);
      Wid := XH1-XL1+1;
      for R := YL1 to YH1 do begin
        MoveScreen(ScreenPtr(R, XL1)^, VP^[vOfs], Wid);
        Inc(vOfs, VWid);
      end;

      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Draw new shadows}
        ShadowVWindow(nXL1+shDX, nYH1+1, nXH1+shDX, nYH1+1, V, ShadowM, #223, SAttr);
        ShadowVWindow(nXH1+1, nYL1+1, nXH1+shDX, nYH1, V, ShadowM, #219, SAttr);
      end;
      {$ENDIF}

      {Copy virtual screen back to physical, and deallocate virtual}
      UndoVWindow(V);

      {Update window information}
      with Current do begin
        CX := WhereXAbs;
        CY := WhereYAbs;
        if (CX >= XL) and (CX <= XH) and (CY >= YL) and (CY <= YH) then begin
          {Cursor is in window, shift it with the window}
          Inc(CX, XDelta);
          Inc(CY, YDelta);
        end;
      end;
      XL1 := nXL1;
      XH1 := nXH1;
      YL1 := nYL1;
      YH1 := nYH1;
      Inc(XL, XDelta);
      Inc(XH, XDelta);
      Inc(YL, YDelta);
      Inc(YH, YDelta);
      {Update window coordinates and cursor position}
      SetCurrentState(CurrentWindow);
    end;
    MoveWindow := True;
  end;

  procedure SetBufSize(OldSize : Word; var Size : Word);
    {-Adjust buffer size on granular boundaries to minimize reallocation}
  const
    BufFactor = 2;           {Amount to increase or decrease buffer sizes}
  begin
    if Size > OldSize then
      {Must allocate a new buffer, make it BufFactor bigger}
      {Buffers are never larger than full screen}
      Size := MinWord(Size*BufFactor, 2*ScreenWidth*ScreenHeight) {!!.12}
    else if Size > (OldSize div BufFactor) then
      {New buffer is not significantly smaller}
      Size := 0;
  end;

  function ResizeWindow(XDelta, YDelta : Integer; Fill : Char) : Boolean;
    {-Resize right and/or lower edges of window. Positive means right or down.}
  type
    LH =
      record
        L : Byte;
        H : Byte;
      end;
  var
    R, ShDX, ShDY : Byte;
    nXH1, nYH1 : Integer;
    nXH, nYH : Integer;
    XH2, YH2, nXH2, nYH2 : Integer;
    MinSize : Integer; {!!.21}
    Wid, nWid, nHgt, vOfs : Word;
    nBufSize, nShadowSize : Word;
    FillWord : Word;
    nCovers, nHolds, nShadows : BufP;
    V : VWindow;
    FillArray : array[0..199] of Word;
    SaveFrame : FrameArray;
  begin
    ResizeWindow := False;
    if CurrentWindow = nil then
      Exit;

    with WindowP(CurrentWindow)^, Draw, V do begin

      {Compute new window boundaries}
      nXH1 := XH1+XDelta;
      nYH1 := YH1+YDelta;
      nXH := XH+XDelta;
      nYH := YH+YDelta;

      {Subscript 2 variables include space for shadow, if any}
      ShDX := 0;
      ShDY := 0;
      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        ShDX := ShadowXofs[ShadowM];
        ShDY := 1;
      end;
      {$ENDIF}
      YH2 := YH1+ShDY;
      XH2 := XH1+ShDX;
      nYH2 := nYH1+ShDY;
      nXH2 := nXH1+ShDX;

      {Assure legal window}
      if Framed then     {!!.21}
        MinSize := 2     {!!.21}
      else               {!!.21}
        MinSize := 0;    {!!.21}
      if (nXH1-XL1 < MinSize) or (nYH1-YL1 < MinSize) then {!!.21}
        Exit;
      if (nXH2 > ScreenWidth) or (nYH2 > ScreenHeight) then
        Exit;

      {Compute new window dimensions}
      nWid := nXH1-XL1+1;
      nHgt := nYH1-YL1+1;

      {Get new buffers if needed}
      nBufSize := 2*nWid*nHgt;
      SetBufSize(BufSize, nBufSize);
      if nBufSize <> 0 then begin
        {Allocate new buffers}
        if not GetMemCheck(nCovers, nBufSize) then
          Exit;
        if Save then
          if not GetMemCheck(nHolds, nBufSize) then
            Exit;
      end;

      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        nShadowSize := 2*(nWid+2*nHgt);
        SetBufSize(ShadowSize, nShadowSize);
        if nShadowSize <> 0 then
          if not GetMemCheck(nShadows, nShadowSize) then
            Exit;
      end;
      {$ENDIF}

      {Initialize virtual screen}
      if not InitVWindow(V, XL1, YL1, Max(XH2, nXH2), Max(YH2, nYH2)) then
        Exit;

      {Update cursor state before resizing}
      SaveCurrentState(CurrentWindow, False); {!!.07}

      {Erase window from virtual buffer}
      TransferVWindow(XL1, YL1, XH1, YH1, V, Covers, True);
      if nBufSize <> 0 then begin
        {Dispose of existing buffers}
        FreeMemCheck(Covers, BufSize);
        Covers := nCovers;
        if Save then begin
          FreeMemCheck(Holds, BufSize);
          Holds := nHolds;
        end;
        {Store new buffer size}
        BufSize := nBufSize;
      end;

      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Erase shadow from virtual buffer}
        TransferVShadow(XL1, YL1, XH1, YH1, ShDX, V, Shadows, True);
        if nShadowSize <> 0 then begin
          {Dispose of existing Shadows buffer}
          FreeMemCheck(Shadows, ShadowSize);
          {Store new buffer information}
          ShadowSize := nShadowSize;
          Shadows := nShadows;
        end;
        {Save the new Shadows buffer}
        TransferVShadow(XL1, YL1, nXH1, nYH1, ShDX, V, Shadows, False);
      end;
      {$ENDIF}

      {Save the new Covers buffer from virtual buffer}
      TransferVWindow(XL1, YL1, nXH1, nYH1, V, Covers, False);

      {Copy valid contents of window to virtual buffer}
      Wid := Min(XH, nXH)-XL+1;
      vOfs := VWid*(YL-YLv)+2*(XL-XLv);
      for R := YL to Min(YH, nYH) do begin
        MoveScreen(ScreenPtr(R, XL)^, VP^[vOfs], Wid);
        Inc(vOfs, VWid);
      end;

      {Fill new areas}
      LH(FillWord).L := Byte(Fill);
      LH(FillWord).H := WAttr;
      if nYH > YH then begin
        {Rows to fill at bottom}
        Wid := nXH-XL+1;
        for R := 0 to Wid-1 do
          FillArray[R] := FillWord;
        vOfs := VWid*(YH+1-YLv)+2*(XL-XLv);
        for R := YH+1 to nYH do begin
          Move(FillArray, VP^[vOfs], 2*Wid);
          Inc(vOfs, VWid);
        end;
      end;

      if nXH > XH then begin
        {Columns to fill at right}
        Wid := nXH-XH;
        for R := 0 to Wid-1 do
          FillArray[R] := FillWord;
        vOfs := VWid*(YL-YLv)+2*(XH-XLv+1); {!!.09}
        for R := YL to Min(YH, nYH) do begin
          Move(FillArray, VP^[vOfs], 2*Wid);
          Inc(vOfs, VWid);
        end;
      end;

      {$IFDEF ShadowedWindows}
      if Shadowed then begin
        {Draw new shadows}
        ShadowVWindow(XL1+shDX, nYH1+1, nXH1+shDX, nYH1+1, V, ShadowM, #223, SAttr);
        ShadowVWindow(nXH1+1, YL1+1, nXH1+shDX, nYH1, V, ShadowM, #219, SAttr);
      end;
      {$ENDIF}

      {Draw new frame}
      if Framed then begin
        SaveFrame := FrameChars;
        FrameChars := Frame;
        FrameVWindow(V, XL1, YL1, nXH1, nYH1, FAttr, HAttr, StringFromHeap(HeaderP));
        FrameChars := SaveFrame;
      end;

      {Copy virtual screen back to physical, and deallocate virtual}
      UndoVWindow(V);

      {Update window information}
      with Current do begin
        {Assure cursor remains within window}
        CX := WhereXAbs;
        CY := WhereYAbs;
        if CX > nXH then
          CX := nXH;
        if CY > nYH then
          CY := nYH;
      end;
      XH1 := nXH1;
      YH1 := nYH1;
      XH := nXH;
      YH := nYH;
      {Update window coordinates and cursor position}
      SetCurrentState(CurrentWindow);
    end;
    ResizeWindow := True;
  end;

  function SetTopWindow(W : WindowPtr) : Boolean;
    {-Make an already active, stacked window the current one}
  var
    TempStack : WindowStackP;
    V : VWindow;
    T : WindowPtr;
    P, C : SaveRec;
    SaveFrame : FrameArray;
  begin
    SetTopWindow := False;

    if not WindowIsActive(W) then
      {Specified window is nowhere on-screen}
      Exit;

    if WindowStack^.Top = W then begin
      {Specified window already on top of stack}
      SetTopWindow := True;
      Exit;
    end;

    {Initialize virtual screen to hide swapping activity}
    if not InitVWindow(V, 1, 1, ScreenWidth, ScreenHeight) then
      Exit;

    SaveFrame := FrameChars;

    with V do begin

      {Draw current window's frame in unselected attribute}
      with WindowP(WindowStack^.Top)^, Draw do
        if FrameDiff then begin
          FrameChars := UFrame;
          FrameVWindow(V, XL1, YL1, XH1, YH1, UFAttr, UHAttr, StringFromHeap(HeaderP));
        end;

      {Pop windows onto a temporary stack}
      TempStack := nil;
      repeat
        T := WindowStack^.Top;
        with WindowP(T)^, Draw do begin
          if Save then
            {Save contents of window}
            TransferVWindow(XL1, YL1, XH1, YH1, V, Holds, False);
          {Erase window from virtual buffer}
          TransferVWindow(XL1, YL1, XH1, YH1, V, Covers, True);
          {$IFDEF ShadowedWindows}
          if Shadowed then
            TransferVShadow(XL1, YL1, XH1, YH1, ShadowXofs[ShadowM],
                            V, Shadows, True);
          {$ENDIF}
          if T = W then begin
            {Temporarily save state of screen underneath W}
            P := Previous;
            {Update screen state of W}
            Current := C;
          end else if not PushStack(TempStack, T) then
            {Shouldn't get here, force exit from loop in case}
            T := W;
          C := Previous;
        end;
        if PopStack(WindowStack) = nil then
          {Shouldn't get here, force exit from loop in case}
          T := W;
      until T = W;

      {Draw stacked windows back again}
      T := TempStack^.Top;
      WindowP(T)^.Previous := P;
      while T <> nil do begin
        {Straighten out state of underlying screens}
        {Put window on active stack}
        if PushStack(WindowStack, T) then
          CopyToVWindow(V, T);
        T := PopStack(TempStack);
      end;

      {Draw the new top window on the virtual screen}
      SavePreviousState(WindowP(W)^.Previous);
      if PushStack(WindowStack, W) then begin
        CopyToVWindow(V, W);

        {Draw current window's frame in selected attribute}
        with WindowP(W)^, Draw do
          if FrameDiff then begin
            FrameChars := Frame;
            FrameVWindow(V, XL1, YL1, XH1, YH1, FAttr, HAttr, StringFromHeap(HeaderP));
          end;
      end;

      {Copy virtual screen back to physical, and deallocate virtual}
      UndoVWindow(V);

      {Update window information}
      with WindowP(W)^, Draw do
        TextAttr := WAttr;
      SetCurrentState(W);

    end;

    FrameChars := SaveFrame;

    SetTopWindow := True;
  end;

  function SetTopTiledWindow(W : WindowPtr) : Boolean;
    {-Make an already active, tiled window the current one}
  var
    TempStack : WindowStackP;
    T : WindowPtr;
    P, C : SaveRec;
    SaveFrame : FrameArray;
  begin
    SetTopTiledWindow := False;

    if not WindowIsActive(W) then
      {Specified window is nowhere on-screen}
      Exit;

    if WindowStack^.Top = W then begin
      {Specified window already on top of stack}
      SetTopTiledWindow := True;
      Exit;
    end;

    SaveFrame := FrameChars;

    {Draw current window's frame in unselected attribute}
    with WindowP(CurrentWindow)^, Draw do
      if FrameDiff then begin
        FrameChars := UFrame;
        FrameWindow(XL1, YL1, XH1, YH1, UFAttr, UHAttr, StringFromHeap(HeaderP));
      end;

    {Pop windows onto a temporary stack}
    TempStack := nil;
    repeat
      T := WindowStack^.Top;
      with WindowP(T)^ do begin
        if T = W then begin
          {Temporarily save state of screen underneath W}
          P := Previous;
          {Update screen state of W}
          Current := C;
        end else if not PushStack(TempStack, T) then
          {Shouldn't get here, force exit from loop in case}
          T := W;
        C := Previous;
      end;
      if PopStack(WindowStack) = nil then
        {Shouldn't get here, force exit from loop in case}
        T := W;
    until T = W;

    {Stack windows up again}
    T := TempStack^.Top;
    WindowP(T)^.Previous := P;
    while T <> nil do
      {Put window on active stack}
      if PushStack(WindowStack, T) then
        T := PopStack(TempStack)
      else
        T := nil;

    {Select the new top window}
    SavePreviousState(WindowP(W)^.Previous);
    if PushStack(WindowStack, W) then
      with WindowP(W)^, Draw do
        if FrameDiff then begin
          FrameChars := Frame;
          FrameWindow(XL1, YL1, XH1, YH1, FAttr, HAttr, StringFromHeap(HeaderP));
        end;

    {Update window information}
    with WindowP(W)^, Draw do
      TextAttr := WAttr;
    SetCurrentState(W);

    FrameChars := SaveFrame;

    SetTopTiledWindow := True;
  end;

  function ActivateTiledWindow(W : WindowPtr) : Boolean;
    {-Display or reselect tiled window}
  begin
    if WindowIsActive(W) then
      ActivateTiledWindow := SetTopTiledWindow(W)
    else
      ActivateTiledWindow := DisplayWindow(W);
  end;

  function ActivateWindow(W : WindowPtr) : Boolean;
    {-Display or reselect stacked window}
  begin
    if WindowIsActive(W) then
      ActivateWindow := SetTopWindow(W)
    else
      ActivateWindow := DisplayWindow(W);
  end;

  procedure KillWindow(var W : WindowPtr);
    {-Erase and dispose of window no matter where it is}
  begin
    if W <> nil then begin
      if WindowIsActive(W) and SetTopWindow(W) then
        DisposeWindow(EraseTopWindow)
      else
        DisposeWindow(W);
      W := nil;
    end;
  end;

  procedure KillTiledWindow(var W : WindowPtr);
    {-Erase and dispose of tiled window no matter where it is}
  begin
    if W <> nil then begin
      if WindowIsActive(W) and SetTopTiledWindow(W) then
        DisposeWindow(EraseTopWindow)
      else
        DisposeWindow(W);
      W := nil;
    end;
  end;

  procedure SetInactiveFrame(W : WindowPtr;
                             Fr : FrameArray;
                             FrameAttr : Byte;
                             HeaderAttr : Byte);
    {-Set the specified frame type and attribute for selected windows}
  begin
    with WindowP(W)^, Draw do begin
      UFrame := Fr;
      UFAttr := FrameAttr;
      UHAttr := HeaderAttr;
      FrameDiff := Framed and ((FAttr <> UFAttr) or
        (HAttr <> UHAttr) or
        (Frame <> UFrame));
    end;
  end;

  procedure FastWriteStack(W : WindowPtr;
                           S : string; Row, Col, Attr : Byte);
    {-Write to specified window, whether or not it's hidden under a stack}
  var
    T : WindowPtr;
    TempStack : WindowStackP;
    V : VWindow;
  begin
    if not WindowIsActive(W) then
      {Specified window is nowhere on-screen}
      Exit;

    if W = CurrentWindow then begin
      {Specified window already current}
      FastWriteWindow(S, Row, Col, Attr);
      Exit;
    end;

    {Initialize virtual screen to hide swapping activity}
    if not InitVWindow(V, 1, 1, ScreenWidth, ScreenHeight) then
      Exit;

    with V do begin

      {Pop windows onto a temporary stack}
      TempStack := nil;
      repeat
        T := WindowStack^.Top;
        if T <> W then
          with WindowP(T)^, Draw do begin
            if Save then
              {Save contents of window}
              TransferVWindow(XL1, YL1, XH1, YH1, V, Holds, False);
            {Erase window from virtual buffer}
            TransferVWindow(XL1, YL1, XH1, YH1, V, Covers, True);
            {$IFDEF ShadowedWindows}
            if Shadowed then
              TransferVShadow(XL1, YL1, XH1, YH1, ShadowXofs[ShadowM],
                              V, Shadows, True);
            {$ENDIF}
            if not PushStack(TempStack, T) then
              {Shouldn't get here, force exit from loop in case}
              T := W;
            if PopStack(WindowStack) = nil then
              {Shouldn't get here, force exit from loop in case}
              T := W;
          end;
      until T = W;

      {Write the string onto the virtual screen}
      with WindowP(W)^, Draw do
        WriteVWindow(S, YL+Row-1, XL+Col-1, Attr, V);

      {Draw stacked windows back again}
      T := TempStack^.Top;
      while T <> nil do begin
        {Put window on active stack}
        if PushStack(WindowStack, T) then
          CopyToVWindow(V, T);
        T := PopStack(TempStack);
      end;

      {Copy virtual screen back to physical, and deallocate virtual}
      UndoVWindow(V);
    end;
  end;

  procedure FastWriteClip(S : string; Row, Col, Attr : Byte);
    {-Write S in active window, using window-relative coordinates,
      clipping at right edge}
  var
    SLen : Byte absolute S;
    MaxLen : Byte;
  begin
    MaxLen := lo(WindMax)-lo(WindMin)+2-Col;
    if SLen > MaxLen then
      SLen := MaxLen;
    FastWriteWindow(S, Row, Col, Attr);
  end;

  function MakeVScreen(var V : VScreen; Rows, Cols : Word) : Boolean;
    {-Return true after allocating a virtual screen}
  var
    Size : LongInt;
{$IFDEF Dpmi}                                                        {!!.22}
    SaveSize : LongInt;                                              {!!.22}
{$ENDIF}                                                             {!!.22}
  begin
    {Assume failure}
    MakeVScreen := False;

    {Initialize for safety}
    FillChar(V, SizeOf(VScreen), 0);

    with V do begin
      {Validate request}
      if (Rows = 0) or (Cols = 0) then
        Exit;
      Size := LongInt(2)*Rows*Cols;
      if Size > $FFF0 then
        Exit;
{$IFDEF Dpmi}                                              {begin}   {!!.22}
      {set HeapLimit to our allocation size to force a 0-offset selector}
      SaveSize := HeapLimit;
      HeapLimit := Size;
      if not GetMemCheck(VPtr, Size) then begin
        HeapLimit := SaveSize;
        Exit;
      end;
      HeapLimit := SaveSize;
{$ELSE}                                                    {end}     {!!.22}
      if not GetMemCheck(VPtr, Word(Size+15)) then
        Exit;
{$ENDIF}                                                             {!!.22}
      VSeg := SO(VPtr).S;
{$IFNDEF Dpmi}                                                       {!!.22}
      if SO(VPtr).O <> 0 then
        Inc(VSeg);
{$ENDIF}                                                             {!!.22}
      VRows := Rows;
      VCols := Cols;
      VEnd := Size;
    end;

    MakeVScreen := True;
  end;

  procedure DisposeVScreen(var V : VScreen);
    {-Deallocate space for virtual screen}
  var
    Size : Word;
  begin
    with V do begin
      if VSeg = 0 then
        {Already deallocated}
        Exit;
      FreeMem(VPtr, 2*VRows*VCols+15);
      FillChar(V, SizeOf(VScreen), 0);
    end;
  end;

  procedure ClearVScreen(V : VScreen; Attr : Byte; Fill : Char);
    {-Clear a virtual screen with specified attribute and character}
  var
    FW : Word;
    Segm : Word;
    Size : Word;
  begin
    with V do begin
      if (VSeg = 0) then
        Exit;
      {Word value to fill with}
      FW := (Word(Attr) shl 8) or Word(Fill);
      {Segment to fill}
      Segm := VSeg;
      {Words to fill}
      Size := VEnd shr 1;

      {Fill it fast}
      inline
      ($8B/$46/<FW/          {mov ax,[BP+<FW]}
        $8E/$46/<Segm/       {mov es,[BP+<Segm]}
        $31/$FF/             {xor di,di}
        $8B/$4E/<Size/       {mov cx,[BP+<Size]}
        $FC/                 {cld}
        $F2/$AB);            {rep stosw}
    end;
  end;

  procedure WriteVScreen(V : VScreen; S : string; Row, Col : Word; Attr : Byte);
    {-Write a string to specified virtual screen}
  var
    Segm : Word;
    Lofs : Word;
    Cols : Word;
  begin
    with V do begin
      if VSeg = 0 then
        Exit;
      {Put record fields in inline-accessible variables}
      Segm := VSeg;
      Lofs := VEnd;
      Cols := VCols;
      inline
      (
        $1E/                 {push    ds                  ;save DS}
        $16/                 {push    ss}
        $1F/                 {pop     ds}
        $8D/$B6/>S/          {lea     si,[bp+>S]          ;DS:SI -> string to write}
        $8A/$0C/             {mov     cl,[si]}
        $30/$ED/             {xor     ch,ch               ;CX = length to write}
        $E3/$30/             {jcxz    done                ;get out if empty string}
        $8B/$86/>Row/        {mov     ax,[bp+>Row]        ;row number}
        $48/                 {dec     ax                  ;zero-based}
        $F7/$A6/>Cols/       {mul     word ptr [bp+>Cols] ;multiply by columns in virtual screen}
        $03/$86/>Col/        {add     ax,[bp+>Col]        ;add column}
        $48/                 {dec     ax                  ;zero-based}
        $D1/$E0/             {shl     ax,1                ;account for attributes}
        $89/$C7/             {mov     di,ax               ;store destination offset}
        $2B/$86/>Lofs/       {sub     ax,[bp+>Lofs]}
        $77/$18/             {ja      done                ;jump if destination is beyond end of buffer}
        $F7/$D8/             {neg     ax}
        $D1/$E8/             {shr     ax,1                ;AX = number of chars left on virtual screen}
        $39/$C8/             {cmp     ax,cx               ;compare to characters to write}
        $73/$02/             {jae     leavelen            ;jump if space}
        $89/$C1/             {mov     cx,ax               ;only write what fits}
        {leavelen:}
        $8A/$A6/>Attr/       {mov     ah,[bp+>attr]       ;get attribute to write with}
        $8E/$86/>Segm/       {mov     es,[bp+>segm]       ;ES:DI -> output destination}
        $46/                 {inc     si                  ;skip length byte}
        $FC/                 {cld                         ;forward}
        {next:}
        $AC/                 {lodsb                       ;load character from string}
        $AB/                 {stosw                       ;store character and attribute}
        $E2/$FC/             {loop    next                ;write 'em all}
        {done:}
        $1F);                {pop     ds                  ;restore ds}
    end;
  end;

  procedure ReadVScreen(V : VScreen; Number : Byte;
                        Row, Col : Word; var S : string);
    {-Read number characters from the virtual screen starting at Row,Col}
  var
    Segm : Word;
    Lofs : Word;
    Cols : Word;
  begin
    with V do begin
      if VSeg = 0 then
        Exit;
      {Put record fields in inline-accessible variables}
      Segm := VSeg;
      Lofs := VEnd;
      Cols := VCols;
      inline
      (
        $1E/                 {push ds}
        $8E/$5E/<Segm/       {mov  ds,[bp+<Segm]       ;DS -> virtual screen}
        $C4/$7E/<S/          {les  di,[bp+<S]          ;ES:DI -> string S}
        $8A/$4E/<Number/     {mov  cl,[bp+<Number]}
        $30/$ED/             {xor  ch,ch               ;CX = number of characters to read}
        $8B/$46/<Row/        {mov  ax,[bp+<Row]        ;AX = row number}
        $48/                 {dec  ax                  ;zero-based}
        $F7/$66/<Cols/       {mul  word ptr [bp+<Cols] ;multiply by columns in virtual screen}
        $03/$46/<Col/        {add  ax,[bp+<Col]        ;add column}
        $48/                 {dec  ax                  ;zero-based}
        $D1/$E0/             {shl  ax,1                ;account for attributes}
        $89/$C6/             {mov  si,ax               ;store starting source offset}
        $2B/$46/<Lofs/       {sub  ax,[bp+<Lofs]}
        $F7/$D8/             {neg  ax}
        $D1/$E8/             {shr  ax,1                ;AX = characters left on virtual screen}
        $39/$C8/             {cmp  ax,cx               ;compare characters left to requested}
        $73/$02/             {jae  storelen            ;jump if enough left}
        $89/$C1/             {mov  cx,ax               ;only return what there are}
        {storelen:}
        $FC/                 {cld                      ;forward}
        $88/$C8/             {mov  al,cl}
        $AA/                 {stosb                    ;store length of string}
        $E3/$04/             {jcxz done                ;get out if no characters to transfer}
        {next:}
        $AD/                 {lodsw                    ;load next character/attribute pair}
        $AA/                 {stosb                    ;store just the character}
        $E2/$FC/             {loop next                ;get as many as requested}
        {done:}
        $1F);                {pop  ds                  ;restore DS}
    end;
  end;

  procedure ActivateVScreen(V : VScreen);
    {-Switch fastwriting to the specified virtual screen}
  begin
    with V do begin
      if VSeg = 0 then
        Exit;
      {TPCRT routines won't work for really large screens}
      if (VRows > 255) or (VCols > 255) then
        Exit;
      VirtualSegment := VSeg;
      VirtualWidth := VCols;
    end;
  end;

  procedure DeactivateVScreen;
    {-Restore fastwriting to the physical screen}
  begin
    VirtualSegment := VideoSegment;
    VirtualWidth := ScreenWidth;
  end;

  procedure MoveVScreenToWindow(V : VScreen; Row, Col : Word);
    {-Copy contents of virtual screen at Row,Col to current window}
  var
    CMin : Integer;
    CWid : Integer;
    RMin : Integer;
    RMax : Integer;
    cOfs : Word;
    vOfs : Word;
    R : Word;
  begin
    with V do begin
      if VSeg = 0 then
        Exit;
      if (Row = 0) or (Col = 0) then
        Exit;
      if (Row > VRows) or (Col > VCols) then
        Exit;
      CMin := lo(WindMin);
      CWid := 1+Min(lo(WindMax)-lo(WindMin), VCols-Col);
      RMin := hi(WindMin);
      RMax := RMin+Min(hi(WindMax)-hi(WindMin), VRows-Row);
      vOfs := 2*((Row-1)*VCols+(Col-1));
      cOfs := 2*(RMin*ScreenWidth+CMin);

      for R := RMin to RMax do begin
        MoveScreen(mem[VSeg:vOfs], mem[VideoSegment:cOfs], CWid);
        Inc(vOfs, 2*VCols);
        Inc(cOfs, 2*ScreenWidth);
      end;
    end;
  end;

  procedure MoveWindowToVScreen(V : VScreen; Row, Col : Word);
    {-Copy contents of current window to virtual screen at Row, Col}
  var
    CMin : Integer;
    CWid : Integer;
    RMin : Integer;
    RMax : Integer;
    vOfs : Word;
    cOfs : Word;
    R : Word;
  begin
    with V do begin
      if VSeg = 0 then
        Exit;
      if (Row = 0) or (Col = 0) then
        Exit;
      if (Row > VRows) or (Col > VCols) then
        Exit;
      CMin := lo(WindMin);
      CWid := 1+Min(lo(WindMax)-lo(WindMin), VCols-Col);
      RMin := hi(WindMin);
      RMax := RMin+Min(hi(WindMax)-hi(WindMin), VRows-Row);
      vOfs := 2*((Row-1)*VCols+(Col-1));
      cOfs := 2*(RMin*ScreenWidth+CMin);

      for R := RMin to RMax do begin
        MoveScreen(mem[VideoSegment:cOfs], mem[VSeg:vOfs], CWid);
        Inc(vOfs, 2*VCols);
        Inc(cOfs, 2*ScreenWidth);
      end;
    end;
  end;

  function VScreenRows(V : VScreen) : Word;
    {-Return number of rows in virtual screen}
  begin
    VScreenRows := V.VRows;
  end;

  function VScreenCols(V : VScreen) : Word;
    {-Return number of columns in virtual screen}
  begin
    VScreenCols := V.VCols;
  end;

begin
  {check for presence of TPSCREEN}
  if TpUnitsFlag and TpScreenFlag <> 0 then begin
    WriteLn('TPWINDOW/TPSCREEN conflict');
    Halt(1);
  end;

  {signal that we're installed}
  TpUnitsFlag := TpUnitsFlag or TpWindowFlag;

  {No windows are active}
  CurrentWindow := nil;
  WindowStack := nil;
end.
