{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$R-,O-,A-}
{$ENDIF}

{$I TPDEFINE.INC} {!!.21}

{*********************************************************}
{*                   TPSCREEN.PAS 5.22                   *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpScreen;
  {-Enhanced CRT module with virtual screens}

interface

uses
  Dos,
  Dpmi,   {!!.20}
  TpCrt;

const
  MaxScreens = 10;
  Turbo3StyleColors : Boolean = False; {set to true for yellow on black, etc}

const
  {allows remapping of colors}
  Black : Byte = 0;
  Blue : Byte = 1;
  Green : Byte = 2;
  Cyan : Byte = 3;
  Red : Byte = 4;
  Magenta : Byte = 5;
  Brown : Byte = 6;
  LightGray : Byte = 7;
  DarkGray : Byte = 8;
  LightBlue : Byte = 9;
  LightGreen : Byte = 10;
  LightCyan : Byte = 11;
  LightRed : Byte = 12;
  LightMagenta : Byte = 13;
  Yellow : Byte = 14;
  White : Byte = 15;

type
  {record used to save/restore window coordinates}
  WindowCoordinates =
    record
      XL, YL, XH, YH : Byte;
    end;

  {screen descriptor}
  ScreenRec =
    record
      Alloc : Boolean;       {is it allocated ?}
      Size : Word;           {Size in words}
      SCols,                 {Number of columns}
      SRows,                 {Number of Rows}
      {Window coordinates}
      XLo,                   {0..79 format}
      YLo,                   {0..24/42 format}
      XHi,                   {1..80 format}
      YHi,                   {1..25/43 format}
      Col,                   {Cursor coordinates}
      Row : Byte;
      BPtr : Pointer;        {Pointer to screen buffer}
    end;
var
  VisiblePage : Byte absolute CurrentPage; {the display page on screen}
  ActivePage : Byte;         {the display page we're writing to}
  CurrentScreen : Byte;      {handle for current screen. 0 = real screen.}
  OutputToScreen : Boolean;  {true if output is going to the physical screen}
  Screens : array[0..MaxScreens] of ScreenRec;

procedure HighVideo;
  {-Select high intensity}

procedure NormVideo;
  {-Select 'normal' intensity}

procedure LowVideo;
  {-Select low intensity}

procedure TextColor(Color : Byte);
  {-Set foreground color for screen writes}

procedure TextBackGround(Color : Byte);
  {-Set background color for screen writes}

function WhereXY : Word;
 {-Return absolute row and column coordinates of cursor. High byte has current
   row (Y), low byte has current column (X).}

function WhereXAbs : Byte;
  {-Return absolute column coordinate of cursor}

function WhereyAbs : Byte;
  {-Return absolute row coordinate of cursor}

function WhereX : Byte;
  {-Return column coordinate of cursor, relative to Window}

function WhereY : Byte;
  {-Return row coordinate of cursor, relative to Window}

procedure GotoxyAbs(X, Y : Byte);
  {-Move cursor to column X, row Y.}

procedure GoToXY(X, Y : Byte);
  {-Move cursor to column X, row Y, relative to Window}

procedure ClrScr;
  {-Clear the active window. Uses special background character, if not ' '.}

procedure ClrEol;
  {-Clear to end of line}

procedure TextMode(Mode : Word);
  {-Switch to/set text mode}

procedure Window(X1, Y1, X2, Y2 : Byte);
  {-Sets window coordinates for active screen.}

procedure ScrollWindowUp(X1, Y1, X2, Y2, Lines : Byte);
 {-Scrolls the designated window up the specified number of lines. Always
   affects the active page of the physical screen.}

procedure ScrollWindowDown(X1, Y1, X2, Y2, Lines : Byte);
  {-Same as ScrollWinUp but scrolls the window down instead.}

procedure AssignCrt(var F : Text);
  {-Initialize the File Interface Block}

procedure MonoColors;
  {-Switches the color map to monochrome/black and white}

procedure ColorColors;
  {-Switches the color map to color}

procedure SetBackGroundChar(Ch : Char);
  {-Sets a character to use for ClrScr and ClrEol}

function CurrentRows : Byte;
  {-Returns the number of rows in the current screen}

function CurrentCols : Byte;
  {-Returns the number of columns in the current screen}

procedure FastWriteMem(St : string; var Address; Attr : Byte);
  {-Write St at Address in Attr (video attribute) without snow}

procedure FillAttribChar(var Dest; Number : Word; Ch : Char; Attr : Byte);
  {-Fills Dest with Number character/attribute pairs}

procedure FillVideoChar(R, C : Byte; Number : Word; Ch : Char; Attr : Byte);
  {-Fills Number character/attribute pairs at row R, column C}

procedure FillWindow(Ch : Char);
  {-Fills the active window with the specified character}

procedure SpeedWrite(S : string);
 {-This routine writes a string onto the screen at the current cursor location
   with the current attributes. If the cursor is not inside the boundaries of
   the active window, the string is not written. If it extends beyond the
   window, it is clipped. After the string is written, the cursor is updated to
   the end of the string.}

procedure CenterWrite(S : string);
  {-Centers a string on the current line in the active window}

function FastReadLine(Handle, Row : Byte) : string;
  {-Reads one row of text from the specified screen and returns it.}

procedure DefineScreen(BufAddr : Pointer; Handle, Cols, Rows : Byte);
 {-Defines a virtual screen. Should be used only when you want to manage your
   own buffer storage.}

procedure DeallocateScreen(Handle : Byte);
  {-Deallocate the buffer for a virtual screen.}

function AllocateScreen(Handle, Cols, Rows : Byte) : Boolean;
  {-Defines a virtual screen and allocates a buffer for it. If a buffer has
    already been allocated for Handle, the old buffer is destroyed.}

procedure StoreWindowCoordinates(var WC : WindowCoordinates);
  {-Store the window coordinates for the active window}

procedure RestoreWindowCoordinates(WC : WindowCoordinates);
  {-Restore previously saved window coordinates}

procedure SetActivePage(PageNo : Byte);
 {-Selects the video page that will be written to with subsequent operations on
   the screen. It does not select the physical screen if it isn't selected
   already. To do that, you must use 'SelectScreen(0);'}

procedure SelectScreen(Handle : Byte);
  {-Selects the screen to be written to. Handle=0 selects the physical screen.}

procedure ReinitScreen;
 {-Must be called after every mode change before trying to write to the
   physical screen. ReinitScreen automatically selects the physical screen as
   the active screen, the visual page as the active page, and the full screen
   as the active window.}

procedure CopyScreen(Handle : Byte);
 {-Copies a screen buffer to the active screen. If the destination buffer isn't
   the same size as the source, it tries to change the dimensions.}

procedure CopyWindow(Handle : Word);
  {-Copies a window from the specified screen to the active screen.}

procedure MoveWindowHorizontal(Handle, Cols : Byte; MoveRight : Boolean);
 {-Moves the active window Cols columns to the left/right, filling in the
   background with text from the specified screen (must be the same size as
   the active screen.}

procedure MoveWindowVertical(Handle, Lines : Byte; MoveDown : Boolean);
 {-Moves the active window Lines rows up or down, filling in the background
   with text from the specified screen (must be the same size as the active
   screen.}

procedure FrameWindow(LeftCol, TopRow, RightCol, BotRow, FAttr, HAttr : Byte;
                      Header : string);
  {-Draws a frame around a window}

procedure InitVideo;
  {-Procedure to initialize our data structures}

procedure ReleaseVideo;
 {-Routes all output through TpCrt. This may need to be called in error
   handlers to disable buffering.}

  {==========================================================================}

implementation

type
  {text buffer}
  TextBuffer = array[1..65521] of Char;

  {structure of a Turbo File Interface Block}
  FIB =
    record
      Handle : Word;
      Mode : Word;
      BufSize : Word;
      Private : Word;
      BufPos : Word;
      BufEnd : Word;
      BufPtr : ^TextBuffer;
      OpenProc : Pointer;
      InOutProc : Pointer;
      FlushProc : Pointer;
      CloseProc : Pointer;
      UserData : array[1..16] of Byte;
      Name : array[0..79] of Char;
      Buffer : array[1..128] of Char;
    end;
  ColorMap = array[0..15] of Byte;

const
  FMClosed = $D7B0;
  FMInput = $D7B1;
  FMOutput = $D7B2;
const
  MonoTable : ColorMap = (0, 1, 2, 2, 4, 4, 4, 7, 8, 9, 10, 11, 12, 12, 15, 15);
const
  ColorTable : ColorMap = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
const
  BackgroundChar : Char = ' ';

var
  OldCrtOut : Pointer;       {pointer to CrtOut routine in CRT unit}
  CurrentBackground : Byte;  {current background color}
  CurrentForeground : Byte;  {current foreground color}
  Initialized : Boolean;
  CurrentColorTable : ColorMap absolute Black;
  SaveExitProc : Pointer;

  procedure TextColor(Color : Byte);
    {-Set foreground color for screen writes}
  begin
    if (CurrentMode <> 7) or (WhichHerc = HercInColor) then
      TpCrt.TextColor(Color)
    else begin
      CurrentForeground := Color and $0F;
      if (CurrentBackground or CurrentForeground) = 0 then
        TextAttr := 0
      else if CurrentForeground = 0 then
        TextAttr := $70
      else if CurrentBackground = 0 then
        TextAttr := CurrentForeground
      else
        TextAttr := CurrentForeground or $07;

      {set blink bit}
      if (Color and $10) <> 0 then
        TextAttr := TextAttr or $80;
    end;
  end;

  procedure TextBackGround(Color : Byte);
    {-Set background color for screen writes}
  begin
    if (CurrentMode <> 7) or (WhichHerc = HercInColor) then
      TpCrt.TextBackGround(Color)
    else begin
      CurrentBackground := Color and $07;
      if (CurrentBackground or CurrentForeground) = 0 then
        TextAttr := 0
      else
        TextColor(CurrentForeground or ((TextAttr and $80) shr 3))
    end;
  end;

  procedure HighVideo;
    {-Select high intensity}
  begin
    if Turbo3StyleColors then begin
      TextColor(Yellow);
      TextBackGround(Black);
    end
    else
      TpCrt.HighVideo;
  end;

  procedure NormVideo;
    {-Select 'normal' intensity}
  begin
    if Turbo3StyleColors then
      HighVideo
    else
      TpCrt.NormVideo;
  end;

  procedure LowVideo;
    {-Select low intensity}
  begin
    if Turbo3StyleColors then
      TextAttr := $07
    else
      TpCrt.LowVideo;
  end;

  function WhereXY : Word;
    {-Return absolute row and column coordinates of cursor. High byte has
      current row (Y), low byte has current column (X).}
  var
    SavePage : Word;
  begin
    if Initialized and InTextMode and not OutputToScreen then
      with Screens[CurrentScreen] do
        WhereXY := (Succ(Row) shl 8) or Succ(Col)
    else begin
      SavePage := VisiblePage;
      VisiblePage := ActivePage;
      WhereXY := TpCrt.WhereXY;
      VisiblePage := SavePage;
    end;
  end;

  function WhereXAbs : Byte;
    {-Return absolute column coordinate of cursor}
  begin
    WhereXAbs := Lo(WhereXY);
  end;

  function WhereyAbs : Byte;
    {-Return absolute row coordinate of cursor}
  begin
    WhereyAbs := Hi(WhereXY);
  end;

  function WhereX : Byte;
    {-Return column coordinate of cursor, relative to Window}
  begin
    if Initialized then
      WhereX := Lo(WhereXY)-Screens[CurrentScreen].XLo
    else
      WhereX := Lo(WhereXY);
  end;

  function WhereY : Byte;
    {-Return row coordinate of cursor, relative to Window}
  begin
    if Initialized and InTextMode then
      WhereY := Hi(WhereXY)-Screens[CurrentScreen].YLo
    else
      WhereY := Hi(WhereXY);
  end;

  procedure GotoxyAbs(X, Y : Byte);
    {-Move cursor to column X, row Y.}
  type                                                                 {!!.20}
    CursorsA = Array[0..7] of Word;                                    {!!.20}
    CursorsP = ^CursorsA;                                              {!!.20}
  var
    Cursors : CursorsP; {array[0..7] of Word absolute $40 : $50;}      {!!.20}
  begin
    Cursors := Ptr(BiosDataSele, $50);                                 {!!.20}
    if Initialized and InTextMode then
      with Screens[CurrentScreen] do
        if (X > 0) and (Y > 0) and (X <= SCols) and (Y <= SRows) then begin
          Col := Pred(X);
          Row := Pred(Y);
        end;
    if OutputToScreen or not Initialized then
      if ActivePage = VisiblePage then
        TpCrt.GotoxyAbs(X, Y)
      else
        Cursors^[ActivePage] := (Pred(Y) shl 8) or Pred(X);           {!!.20}
  end;

  procedure GoToXY(X, Y : Byte);
    {-Move cursor to column X, row Y, relative to Window}
  begin
    if Initialized then
      with Screens[CurrentScreen] do
        GotoxyAbs(X+XLo, Y+YLo)
    else
      TpCrt.GoToXY(X, Y);
  end;

  procedure ClrScr;
    {-Clear the active window. Uses special background character, if not ' '.}
  var
    A : Byte;
  begin
    if Initialized and InTextMode then
      with Screens[CurrentScreen] do
        if (ActivePage = VisiblePage) and OutputToScreen and (BackgroundChar = ' ') then
          TpCrt.ClrScr
        else begin
          FillWindow(BackgroundChar);
          GoToXY(1, 1);
        end
    else
      TpCrt.ClrScr;
  end;

  procedure ClrEol;
    {-Clear to end of line}
  var
    XY : Word;
    X : Byte;
  begin
    if Initialized and InTextMode then
      with Screens[CurrentScreen] do
        if (ActivePage = VisiblePage) and OutputToScreen and (BackgroundChar = ' ') then
          TpCrt.ClrEol
        else begin
          XY := WhereXY;
          X := Pred(Lo(XY));
          if X < XHi then
            FillVideoChar(Hi(XY), Lo(XY), XHi-X, BackgroundChar, TextAttr);
        end
    else
      TpCrt.ClrEol;
  end;

  procedure TextMode(Mode : Word);
    {-Switch to/set text mode}
  begin
    {call regular TextMode routine}
    TpCrt.TextMode(Mode);

    {reinitialize}
    ReinitScreen;
  end;

  procedure Window(X1, Y1, X2, Y2 : Byte);
    {-Sets window coordinates for active screen.}
  begin
    if Initialized then
      if (X1 > 0) and (X2 >= X1) and (Y1 > 0) and (Y2 >= Y1) then
        with Screens[CurrentScreen] do
          if (X2 <= SCols) and (Y2 <= SRows) then begin
            XLo := Pred(X1);
            YLo := Pred(Y1);
            XHi := X2;
            YHi := Y2;
            Row := YLo;
            Col := XLo;
          end
          else
            Exit;
    if OutputToScreen then
      TpCrt.Window(X1, Y1, X2, Y2);
  end;

  procedure ScrollWindowUp(X1, Y1, X2, Y2, Lines : Byte);
    {-Scrolls the designated window up the specified number of lines. Always
      affects the active page of the physical screen.}
  var
    SavePage : Word;
  begin
    if InTextMode then begin
      {may need to change video pages temporarily}
      SavePage := VisiblePage;
      VisiblePage := ActivePage;
      TpCrt.ScrollWindowUp(X1, Y1, X2, Y2, Lines);
      VisiblePage := SavePage;
    end;
  end;

  procedure ScrollWindowDown(X1, Y1, X2, Y2, Lines : Byte);
    {-Same as ScrollWinUp but scrolls the window down instead.}
  var
    SavePage : Word;
  begin
    if InTextMode then begin
      {may need to change video pages temporarily}
      SavePage := VisiblePage;
      VisiblePage := ActivePage;
      TpCrt.ScrollWindowDown(X1, Y1, X2, Y2, Lines);
      VisiblePage := SavePage;
    end;
  end;

  procedure WriteOneChar(Ch : Char);
    {-Write one character to the active screen}
  var
    XY, X, Y : Word;
    TB, TB1 : Byte;
  begin
    with Screens[CurrentScreen] do begin

      {if we're on the physical screen, get the position of the cursor}
      if OutputToScreen then begin
        XY := WhereXY;
        Row := Pred(Hi(XY));
        Col := Pred(Lo(XY));
      end;

      {get Row and Col into local storage for faster access}
      Y := Row;
      X := Col;

      {process the character}
      case Ch of
        ^M :                 {carriage return}
          GotoxyAbs(Succ(XLo), Succ(Y));
        ^H : if X > XLo then {backspace}
               GotoxyAbs(X, Succ(Y))
             else if Y > YLo then
               GotoxyAbs(XHi, Y);
        ^J : begin           {line feed}
               TB := Y+2;
               if (TB > YHi) then
                 ScrollWindowUp(Succ(XLo), Succ(YLo), XHi, YHi, 1)
               else
                 GotoxyAbs(Succ(X), TB);
             end;
        ^I :                 {tab}
          {clip to lower edges for safety}
          if (X < XHi) and (Y < YHi) then begin
            TB := XHi-Succ(X);
            TB1 := TB and 7;
            if (TB1 = 0) and (TB > 8) then
              TB1 := 8;
            FillVideoChar(Succ(Y), Succ(X), TB1, ' ', TextAttr);
            if (TB and $F8) = 0 then begin
              WriteOneChar(^M);
              WriteOneChar(^J);
            end
            else
              GotoxyAbs(XHi-(TB and $F8), Succ(Y));
          end;
        ^G :                 {bell}
          inline(
            $B4/$0E/         {MOV AH,$0E}
            $8A/$46/<Ch/     {MOV AL,[BP+<Ch]}
            $CD/$10);        {INT $10}
      else                   {normal character}
        {clip to lower edges for safety}
        if (Succ(X) <= XHi) and (Succ(Y) <= YHi) then begin
          FillVideoChar(Succ(Y), Succ(X), 1, Ch, TextAttr);

          {see if we need a CR/LF}
          if (X+2) > XHi then begin
            {carriage return}
            GotoxyAbs(Succ(XLo), Succ(Y));
            {line feed}
            if (Y+2) > YHi then
              ScrollWindowUp(Succ(XLo), Succ(YLo), XHi, YHi, 1)
            else
              GotoxyAbs(Succ(XLo), Y+2);
          end
          else
            GotoxyAbs(X+2, Succ(Y));
        end;
      end;
    end;
  end;

  procedure JumpFar(var P : Pointer);
    {-Reset stack and JMP FAR to P^}
  inline(
    $5F/                     {pop di          ;offset into di}
    $07/                     {pop es          ;segment into es}
    $89/$EC/                 {mov sp,bp       ;restore sp}
    $5D/                     {pop bp          ;restore bp}
    $26/$FF/$2D);            {jmp far es:[di] ;jump to address in ES:DI}

  {$F+}
  function CrtOut(var F : FIB) : Word;
    {-Move data from F's text buffer to active screen}
  var
    Ch : Char;
    I, N : Word;
    P : ^Char;
    POfs : Word absolute P;
  begin
    if not InTextMode then
      JumpFar(OldCrtOut);

    {write the string}
    with F do begin
      N := BufPos;
      P := @BufPtr^[1];
      if N <> 0 then begin
        for I := 1 to N do begin
          WriteOneChar(P^);
          Inc(POfs);
        end;

        {reset F's buffer pointer}
        BufPos := 0;
      end;
    end;

    {check for ^Break}
    if CheckBreak and CtrlBreakFlag then begin
      {force a write to the physical screen}
      CurrentScreen := 0;
      OutputToScreen := True;

      {flush the keyboard buffer}
      while KeyPressed do
        Ch := ReadKey;

      {write a '^C'}
      WriteOneChar('^');
      WriteOneChar('C');

      {abort with an INT $23}
      inline($CD/$23);
    end;

    {return success flag}
    CrtOut := 0;
  end;

  function CrtZero(var F : FIB) : Word;
    {-Return success flag, but do nothing}
  begin
    CrtZero := 0;
  end;

  function CrtOpen(var F : FIB) : Word;
    {-Initialize the proc pointers}
  begin
    with F do
      if Mode = FMOutput then begin
        InOutProc := @CrtOut;
        FlushProc := @CrtOut;
      end;
    CrtOpen := 0;
  end;
  {$F-}

  procedure AssignCrt(var F : Text);
    {-Initialize the File Interface Block}
  begin
    if Initialized then
      Exit;
    with FIB(F) do begin
      Mode := FMClosed;
      OldCrtOut := InOutProc;
      OpenProc := @CrtOpen;
      CloseProc := @CrtZero;
      BufEnd := 0;
      BufPos := 0;
      Name[0] := #0;
      BufPtr := @Buffer;
      BufSize := SizeOf(Buffer);
    end;
  end;

  procedure MonoColors;
    {-Switches the color map to monochrome/black and white}
  begin
    CurrentColorTable := MonoTable;
  end;

  procedure ColorColors;
    {-Switches the color map to color}
  begin
    CurrentColorTable := ColorTable;
  end;

  procedure SetBackGroundChar(Ch : Char);
    {-Sets a character to use for ClrScr and ClrEol}
  begin
    BackgroundChar := Ch;
  end;

  function CurrentRows : Byte;
    {-Returns the number of rows in the active screen.}
  begin
    if Initialized then
      CurrentRows := Screens[CurrentScreen].SRows
    else
      CurrentRows := ScreenHeight;
  end;

  function CurrentCols : Byte;
    {-Returns the number of columns in the active screen.}
  begin
    if Initialized then
      CurrentCols := Screens[CurrentScreen].SCols
    else
      CurrentCols := ScreenWidth;
  end;

  {$L TPSCREEN.OBJ}

  procedure FastWriteMem(St : string; var Address; Attr : Byte); external;
  procedure FillAttribChar(var Dest; Number : Word; Ch : Char; Attr : Byte);
  external;

  procedure FillVideoChar(R, C : Byte; Number : Word; Ch : Char; Attr : Byte);
    {-Fills Number character/attribute pairs at row R, column C.}
    {-Note: Although the routine checks to see if the starting point is inside
      the active window, it does not verify that row R, column C + Number
      will fit in the window.}
  var
    P : Pointer;
    PO : Word absolute P;
  begin
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do
      if (R <= YHi) and (R > YLo) and (C <= XHi) and (C > XLo) then begin
        P := BPtr;
        {change P to point to R, C in the active window}
        Inc(PO, ((Word(R-1)*SCols)+Word(C-1)) shl 1);
        FillAttribChar(P^, Number, Ch, Attr);
      end;
  end;

  procedure FillWindow(Ch : Char);
    {-Fills the active window with the specified character.}
  var
    P : Pointer;
    POfs : Word absolute P;
    I, BytesPerRow : Word;
  begin
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do begin
      BytesPerRow := Word(SCols) shl 1;
      P := BPtr;
      Inc(POfs, ((Word(YLo)*SCols)+XLo) shl 1);
      for I := 1 to (YHi-YLo) do begin
        FillAttribChar(P^, XHi-XLo, Ch, TextAttr);
        Inc(POfs, BytesPerRow);
      end;
    end;
  end;

  procedure SpeedWrite(S : string);
    {-This routine writes a string onto the active screen at the current cursor
      location with the current attributes. If the cursor is not inside the
      boundaries of the active window, the string is not written. If it extends
      beyond the window, it is clipped. After the string is written, the cursor
      is updated to the end of the string.}
  var
    P : Pointer;
    POfs : Word absolute P;
    I, XY : Word;
    X, Y : Word;
    SLen : Byte absolute S;
  begin
    if not(Initialized and InTextMode) then
      Exit;

    XY := WhereXY;
    X := Pred(Lo(XY));
    Y := Pred(Hi(XY));
    with Screens[CurrentScreen] do
      {Make sure cursor is inside the active window}
      if (Y < YHi) and (Y >= YLo) and (X < XHi) and (X >= XLo) then begin
        {if string would extend past the window, clip it}
        if SLen > (XHi-X) then
          SLen := XHi-X;

        {check for supported modes before writing}
        if InTextMode then begin
          P := BPtr;
          Inc(POfs, ((Y*SCols)+X) shl 1);
          FastWriteMem(S, P^, TextAttr);
          GotoxyAbs(Lo(XY)+SLen, Hi(XY));
        end
        else
          Write(S);
      end;
  end;

  procedure CenterWrite(S : string);
    {-Centers a string on the current line in the active window}
  begin
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do
      GoToXY(Succ(((XHi-XLo)-Length(S)) shr 1), WhereY);
    SpeedWrite(S);
  end;

  function FastReadLine(Handle, Row : Byte) : string;
    {-Reads one row of text from the specified screen and returns it.}
  var
    St : string;
    StLen : Byte absolute St;
    P : ^Char;
    POfs : Word absolute P;
    AbsRow, I : Word;
    R : Word;
  begin
    R := Row;
    FastReadLine := '';
    if not(Initialized and InTextMode) then
      Exit;

    StLen := 0;
    with Screens[Handle] do
      case Handle of
        0 : begin
              {calculate absolute screen row}
              AbsRow := YLo+R;

              {read from the screen if Line is in the window}
              if AbsRow <= YHi then
                FastRead(SCols, AbsRow, 1, St);
            end;
        1..MaxScreens :
          begin
            {point to the start of the desired line}
            P := BPtr;
            Inc(POfs, (SCols*Pred(R)) shl 1);

            {grab the characters one at a time}
            for I := 1 to SCols do begin
              Inc(StLen);
              St[StLen] := P^;
              Inc(POfs, 2);
            end;
          end;
      end;

    {trim any trailing blanks}
    while St[StLen] = ' ' do
      Dec(StLen);
    FastReadLine := St;
  end;

  procedure DefineScreen(BufAddr : Pointer; Handle, Cols, Rows : Byte);
    {-Defines a virtual screen. Should be used only when you want to manage your
      own buffer storage.}
  begin
    if Initialized then
      case Handle of
        0..MaxScreens :
          with Screens[Handle] do begin
            BPtr := BufAddr;
            Size := Word(Cols)*Rows;
            SCols := Cols;
            SRows := Rows;
            XLo := 0;
            YLo := 0;
            XHi := Cols;
            YHi := Rows;
            Col := 0;
            Row := 0;
          end;
      end;
  end;

  procedure DeallocateScreen(Handle : Byte);
    {-Deallocate the buffer for a virtual screen.}
  begin
    if not Initialized then
      Exit;

    case Handle of
      1..MaxScreens :
        with Screens[Handle] do
          if Alloc then begin
            {Deallocate the memory}
            FreeMem(BPtr, Size shl 1);

            {zero out all the entries}
            FillChar(Screens[Handle], SizeOf(ScreenRec)-4, 0);
          end;
    end;
  end;

  function AllocateScreen(Handle, Cols, Rows : Byte) : Boolean;
    {-Defines a virtual screen and allocates a buffer for it. If a buffer has
      already been allocated for Handle, the old buffer is destroyed.}
  var
    BufferSize : LongInt;
  begin
    {assume failure}
    AllocateScreen := False;
    if not Initialized then
      Exit;

    case Handle of
      1..MaxScreens :
        begin
          BufferSize := (LongInt(Cols)*Rows) * 2;
          if (BufferSize <= 65521) and (MaxAvail >= BufferSize) then
            with Screens[Handle] do begin
              {Deallocate old buffer, if necessary}
              DeallocateScreen(Handle);

              {allocate memory for new buffer}
              GetMem(BPtr, Word(BufferSize));

              {define the screen}
              DefineScreen(BPtr, Handle, Cols, Rows);

              {fill the buffer with blanks}
              FillAttribChar(BPtr^, Size, ' ', TextAttr);

              Alloc := True;
              AllocateScreen := True;
            end;
        end;
    end;
  end;

  function ResizeScreenBuffer(Handle, NewCols, NewRows : Byte) : Boolean;
    {-Attempts to resize a screen buffer. If successful, it clears the buffer
      with the current background attributes. If not, it returns false.}
  var
    NewSize : Word;
  begin
    {assume failure}
    ResizeScreenBuffer := False;
    if not Initialized then
      Exit;

    case Handle of
      0..MaxScreens :
        with Screens[Handle] do begin
          NewSize := Word(NewCols)*NewRows;
          if (NewSize <= Size) then begin
            SCols := NewCols;
            SRows := NewRows;
            XLo := 0;
            YLo := 0;
            XHi := NewCols;
            YHi := NewRows;
            Col := 1;
            Row := 1;
            FillAttribChar(BPtr^, NewSize, ' ', TextAttr);
            ResizeScreenBuffer := True;
          end;
        end;
    end;
  end;

  procedure StoreWindowCoordinates(var WC : WindowCoordinates);
    {-Store the window coordinates for the active window}
  begin
    with WC, Screens[CurrentScreen] do begin
      XL := Succ(XLo);
      YL := Succ(YLo);
      XH := XHi;
      YH := YHi;
    end;
  end;

  procedure RestoreWindowCoordinates(WC : WindowCoordinates);
    {-Restore previously saved window coordinates}
  begin
    with WC do
      Window(XL, YL, XH, YH);
  end;

  procedure SetActivePage(PageNo : Byte);
   {-Selects the video page that will be written to with subsequent operations
     on the screen. It does not select the physical screen if it isn't selected
     already. To do that, you must use 'SelectScreen(0);'}
  var
    CrtLen : Word {absolute $40 : $4C};         {!!.20}
  begin
    CrtLen := Word(Ptr(BiosDataSele, $4C)^);    {!!.20}
    with Screens[0] do begin
      case CurrentMode of
        0..1 :
          if (PageNo < 8) then begin
            ActivePage := PageNo;
            BPtr := Ptr(ColorSele, ActivePage*$800); {!!.20}
          end;
        2..3 :
          if (PageNo < 4) then begin
            ActivePage := PageNo;
            {EGA is quirky about video pages}
            if CurrentDisplay > CGA then
              BPtr := Ptr(ColorSele, ActivePage*CrtLen) {!!.20}
            else
              BPtr := Ptr(ColorSele, ActivePage*$1000); {!!.20}
          end;
        7 :
          begin
            ActivePage := 0;
            BPtr := Ptr(MonoSele, 0); {!!.20}
          end;
      end;

      {override if we're running under a multitasker}
      if MultitaskingOn then
        BPtr := Ptr(VideoSegment, 0);
    end;
  end;

  procedure SelectScreen(Handle : Byte);
    {-Selects the screen to be written to. Handle=0 selects the physical screen.}
  begin
    if not Initialized then
      Exit;

    case Handle of
      0..MaxScreens :
        with Screens[Handle] do begin
          {save window coordinates}
          if CurrentScreen = 0 then
            with Screens[0] do begin
              Col := Pred(WhereX);
              Row := Pred(WhereY);
            end;
          CurrentScreen := Handle;
          OutputToScreen := (Handle = 0);
          if OutputToScreen then
            with Screens[0] do
              GoToXY(Succ(Col), Succ(Row));
        end;
    end;
  end;

  procedure ReinitScreen;
    {-Must be called after every mode change before trying to write to the
      physical screen. ReinitScreen automatically selects the physical screen as
      the active screen, the visual page as the active page, and the full screen
      as the active window.}
  var
    I, CurScr : Word;
  begin
    TpCrt.ReinitCrt;
    SetActivePage(VisiblePage);
    OutputToScreen := True;
    if not Initialized then
      Exit;

    with Screens[0] do begin
      case CurrentMode of
        0, 1 :
          begin
            DefineScreen(BPtr, 0, 40, ScreenHeight);
            if CurrentMode = 0 then
              MonoColors
            else
              ColorColors;
          end;
        2, 3 :
          begin
            DefineScreen(BPtr, 0, 80, ScreenHeight);
            if CurrentMode = 2 then
              MonoColors
            else
              ColorColors;
          end;
        7 :
          begin
            DefineScreen(BPtr, 0, 80, 25);
            if WhichHerc = HercInColor then
              ColorColors
            else
              MonoColors;
          end;
      end;
      CurScr := CurrentScreen;
      CurrentScreen := 0;
      I := WhereXY;
      Col := Pred(Lo(I));
      Row := Pred(Hi(I));
      CurrentScreen := CurScr;
      if Turbo3StyleColors then
        HighVideo;
    end;
  end;

  procedure CopyScreen(Handle : Byte);
  {-Copies a screen buffer to the active screen. If the destination buffer
    isn't the same size as the source, it tries to change the dimensions.}
  var
    CopyIt : Boolean;
  begin
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[Handle] do begin
      {Check for wrong size}
      if (Screens[CurrentScreen].SCols <> SCols) or (Screens[CurrentScreen].SRows <> SRows) then
        CopyIt := ResizeScreenBuffer(CurrentScreen, SCols, SRows)
      else
        CopyIt := True;
      if CopyIt then begin
        {move cursor to same position it was in in the inactive window}
        GotoxyAbs(Succ(Col), Succ(Row));
        MoveScreen(BPtr^, Screens[CurrentScreen].BPtr^, Word(SCols)*SRows);
      end;
    end;
  end;

  procedure CopyWindow(Handle : Word);
    {-Copies a window from the specified screen to the active screen.}
  var
    BytesPerRowSrc,
    BytesPerRowDes,
    WordsToMove,
    RowsToMove,
    I : Word;
    SrcPtr,
    DesPtr : Pointer;
    SrcOfs : Word absolute SrcPtr;
    DesOfs : Word absolute DesPtr;
  begin
    {check for text mode}
    if not(Initialized and InTextMode) then
      Exit;

    {get information about the active window}
    with Screens[CurrentScreen] do begin
      {calculate words per row, rows to move, bytes per row}
      WordsToMove := XHi-XLo;
      RowsToMove := YHi-YLo;
      BytesPerRowDes := Word(SCols) shl 1;

      {Set up destination pointer}
      DesPtr := BPtr;
      Inc(DesOfs, ((YLo*Word(SCols))+XLo) shl 1);
    end;

    with Screens[Handle] do begin
      {don't move more columns than the source window contains}
      if (XHi-XLo) <= WordsToMove then
        WordsToMove := XHi-XLo;

      {don't move more rows than the source window contains}
      if (YHi-YLo) <= RowsToMove then
        RowsToMove := YHi-YLo;

      {Set up source pointer}
      SrcPtr := BPtr;
      Inc(SrcOfs, ((YLo*Word(SCols))+XLo) shl 1);

      {try to move cursor to same position it was in the inactive window}
      if ((Col >= XLo) and (Col-XLo < WordsToMove))
      and ((Row >= YLo) and (Row-YLo < RowsToMove)) then
        GoToXY(Succ(Col-XLo), Succ(Row-YLo));

      {calculate bytes per row}
      BytesPerRowSrc := Word(SCols) shl 1;

      {move the window}
      for I := 1 to RowsToMove do begin
        {move to or from the screen}
        MoveScreen(SrcPtr^, DesPtr^, WordsToMove);

        {increment pointers}
        Inc(SrcOfs, BytesPerRowSrc);
        Inc(DesOfs, BytesPerRowDes);
      end;
    end;
  end;

  procedure MoveWindowHorizontal(Handle, Cols : Byte; MoveRight : Boolean);
  {-Moves the active window Cols columns to the left/right, filling in the
    background with text from the specified screen (must be the same size as
    the active screen.}
  var
    BytesPerRow,
    BColsToMove,
    WColsToMove,
    WinCols, I : Word;
    WSource,
    WDest,
    BSource,
    BDest : Pointer;
    WSourceOfs : Word absolute WSource;
    WDestOfs : Word absolute WDest;
    BSourceOfs : Word absolute BSource;
    BDestOfs : Word absolute BDest;
  begin
    {check for text mode}
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do
      {Make sure the background screen is same size as the current screen}
      if (SCols = Screens[Handle].SCols)
      and (SRows = Screens[Handle].SRows) then begin

        {point WSource to top left corner of active window}
        WSource := BPtr;
        Inc(WSourceOfs, ((YLo*Word(SCols))+XLo) shl 1);

        {no. of columns in active window}
        WinCols := XHi-XLo;

        {no. of columns to move from background buffer}
        BColsToMove := Cols;

        {can't be more than the size of the active window}
        if BColsToMove > WinCols then
          BColsToMove := WinCols;

        {assume that move is to the right (background goes to top left corner)}
        BDest := WSource;

        {if moving to the left, point BDest to the appropriate column}
        if not MoveRight then
          Inc(BDestOfs, Word(WinCols-Cols) shl 1);

        {point BSource to top left corner of window used for background}
        BSource := Screens[Handle].BPtr;
        Inc(BSourceOfs, BDestOfs-Ofs(BPtr^));

        if MoveRight then begin
          {nothing to move if background window is replacing active window entirely}
          if (XLo+Cols) >= SCols then
            WColsToMove := 0
          else
            {Clip to lower right}
            if (XHi+Cols) > SCols then
              WColsToMove := SCols-(XLo+Cols)
            else
              WColsToMove := WinCols;

          {point WDest Cols columns to the right of WSource}
          WDest := WSource;
          Inc(WDestOfs, Cols shl 1);
        end
        else begin
          {nothing to move if background window is replacing it entirely}
          if (XHi-Cols) <= 0 then
            WColsToMove := 0
          else
            {Clip on left side}
            if (Cols-XLo) > 0 then begin
              WColsToMove := XHi-Cols;
              Inc(WSourceOfs, Word(Cols-XLo) shl 1);
            end
            else
              WColsToMove := WinCols;

          {point WDest Cols columns to the left of WSource}
          WDest := WSource;
          Dec(WDestOfs, Word(Cols) shl 1);
        end;

        {move the window and fill in the background}
        BytesPerRow := Word(SCols) shl 1;
        for I := 1 to (YHi-YLo) do begin
          MoveScreen(WSource^, WDest^, WColsToMove);
          MoveScreen(BSource^, BDest^, BColsToMove);
          Inc(WSourceOfs, BytesPerRow);
          Inc(WDestOfs, BytesPerRow);
          Inc(BSourceOfs, BytesPerRow);
          Inc(BDestOfs, BytesPerRow);
        end;

        {adjust the cursor and window coordinates}
        if not MoveRight then
          Cols := -Cols;
        GoToXY(WhereX+Cols, WhereY);
        Window(Succ(XLo+Cols), Succ(YLo), XHi+Cols, YHi);
      end;
  end;

  procedure MoveWindowVertical(Handle, Lines : Byte; MoveDown : Boolean);
    {-Moves the active window Lines rows up or down, filling in the background
      with text from the specified screen (must be the same size as the active
      screen.}
  var
    BytesToMove,
    WinRows,
    BytesPerRow,
    BRowsToMove,
    WRowsToMove,
    I, J : Word;
    WSource,
    WDest,
    BSource,
    BDest : Pointer;
    WSourceOfs : Word absolute WSource;
    WDestOfs : Word absolute WDest;
    BSourceOfs : Word absolute BSource;
    BDestOfs : Word absolute BDest;
  begin
    {check for text mode}
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do begin
      {Make sure the background screen is same size as the current screen}
      if (SCols = Screens[Handle].SCols)
      and (SRows = Screens[Handle].SRows) then begin

        {point WSource to top left corner of active window}
        WSource := BPtr;
        Inc(WSourceOfs, ((YLo*Word(SCols))+XLo) shl 1);

        {no. of rows in current window and bytes per row}
        WinRows := YHi-YLo;
        BytesPerRow := Word(SCols) shl 1;

        {assume that move is down (background goes to top left corner)}
        BDest := WSource;

        {Check to see if we're not off active window}
        if Lines < WinRows then begin
          {if moving up, point BDest to the appropriate row}
          if not MoveDown then
            Inc(BDestOfs, ((WinRows-Lines)*Word(SCols)) shl 1);
          BRowsToMove := Lines;
        end
        else
          BRowsToMove := WinRows;

        {point BSource to top left corner of window used for background}
        BSource := Screens[Handle].BPtr;
        Inc(BSourceOfs, BDestOfs-Ofs(BPtr^));

        {no. of columns in active window}
        BytesToMove := (XHi-XLo);

        {assume active window is going nowhere}
        WDest := WSource;

        if MoveDown then begin
          {nothing to move if background window is replacing it entirely}
          if (YLo+Lines) < SRows then begin
            {Clip to the bottom}
            if (YHi+Lines) > SRows then
              WRowsToMove := WinRows-((YHi+Lines)-SRows)
            else
              WRowsToMove := WinRows;

            {point WDest to the start of the appropriate row}
            Inc(WDestOfs, (Lines*Word(SCols)) shl 1);

            {move the bottom row of the window down first, top row last}
            J := (Pred(WRowsToMove)*SCols) shl 1;
            Inc(WSourceOfs, J);
            Inc(WDestOfs, J);

            {move the active window}
            for I := 1 to WRowsToMove do begin
              MoveScreen(WSource^, WDest^, BytesToMove);
              Dec(WSourceOfs, BytesPerRow);
              Dec(WDestOfs, BytesPerRow);
            end;
          end;
        end
        else                 {move window up}
          {nothing to move if background window is replacing it entirely}
          if (YHi-Lines) > 0 then begin
            {Clip on top}
            if (Lines-YLo) > 0 then begin
              WRowsToMove := YHi-Lines;
              Inc(WSourceOfs, ((Lines-YLo)*SCols) shl 1);
            end
            else
              WRowsToMove := WinRows;

            {point WDest to the start of the appropriate row}
            WDestOfs := WSourceOfs-(Lines*BytesPerRow);

            {move the active window}
            for I := 1 to WRowsToMove do begin
              MoveScreen(WSource^, WDest^, BytesToMove);
              Inc(WSourceOfs, BytesPerRow);
              Inc(WDestOfs, BytesPerRow);
            end;
          end;

        {move the background into place}
        for I := 1 to BRowsToMove do begin
          MoveScreen(BSource^, BDest^, BytesToMove);
          Inc(BSourceOfs, BytesPerRow);
          Inc(BDestOfs, BytesPerRow);
        end;

        {adjust the cursor and window coordinates}
        if not MoveDown then
          Lines := -Lines;
        GoToXY(WhereX, WhereY+Lines);
        Window(Succ(XLo), Succ(YLo+Lines), XHi, YHi+Lines);
      end;
    end;
  end;

  procedure FrameWindow(LeftCol, TopRow, RightCol, BotRow, FAttr, HAttr : Byte;
                        Header : string);
    {-Draws a frame around a window}
  var
    HeaderPos,
    Span, I : Integer;
    HeaderLen : Byte absolute Header;
    S : string;
    SLen : Byte absolute S;
    SaveAttr : Byte;
  begin
    if not(Initialized and InTextMode) then
      Exit;

    with Screens[CurrentScreen] do
      {check for valid coordinates}
      if (((LeftCol > 0) and (TopRow > 0)) and ((RightCol <= SCols) and (BotRow <= SRows)))
      and ((BotRow >= TopRow) and (RightCol >= LeftCol)) then begin
        {change the video attribute}
        SaveAttr := TextAttr;
        TextAttr := FAttr;

        {define the window border}
        Window(1, 1, SCols, SRows);

        {calculate width of window and position of header}
        SLen := Succ(RightCol-LeftCol);
        Span := SLen-2;

        {construct the upper border}
        S[1] := FrameChars[ULeft];
        S[SLen] := FrameChars[URight];
        FillChar(S[2], Span, FrameChars[Horiz]);

        {draw the upper border}
        GotoxyAbs(LeftCol, TopRow);
        SpeedWrite(S);

        {draw the vertical bars}
        for I := Succ(TopRow) to Pred(BotRow) do begin
          GotoxyAbs(LeftCol, I);
          SpeedWrite(FrameChars[Vert]);
          GotoxyAbs(RightCol, I);
          SpeedWrite(FrameChars[Vert]);
        end;

        {draw the lower border}
        S[1] := FrameChars[LLeft];
        S[SLen] := FrameChars[LRight];
        GotoxyAbs(LeftCol, BotRow);
        SpeedWrite(S);

        if HeaderLen > 0 then begin
          TextAttr := HAttr;
          if HeaderLen > Span then
            HeaderLen := Span;
          HeaderPos := (SLen-HeaderLen) shr 1;
          GotoxyAbs(LeftCol+HeaderPos, TopRow);
          SpeedWrite(Header);
        end;

        {adjust the size of the window}
        Window(Succ(LeftCol), Succ(TopRow), Pred(RightCol), Pred(BotRow));

        {reset the video attribute}
        TextAttr := SaveAttr;
      end;
  end;

  procedure InitVideo;
    {-Procedure to initialize our data structures}
  var
    I : Word;
  begin
    {get out if we're already initialized}
    if Initialized then
      Exit;

    {switch to new CRT output}
    AssignCrt(Output);
    Rewrite(Output);

    Initialized := True;
    for I := 0 to MaxScreens do
      FillChar(Screens[I], SizeOf(ScreenRec)-4, 0);
    CurrentBackground := (TextAttr and $70) shr 4;
    CurrentForeground := TextAttr and $0F;
    ReinitScreen;
    SelectScreen(0);
  end;

  procedure ReleaseVideo;
    {-Routes all output through TpCrt. This may need to be called in error
      handlers to disable buffering.}
  begin
    {get out if we're already uninitialized}
    if not Initialized then
      Exit;

    {switch to old CRT output}
    TpCrt.AssignCrt(Output);
    Rewrite(Output);

    {reset flags}
    Initialized := False;
    CurrentScreen := 0;
    ActivePage := VisiblePage;
  end;

  {$F+}
  procedure OurExitProc;
    {-Disable buffering}
  begin
    ExitProc := SaveExitProc;
    ReleaseVideo;
  end;
  {$F-}

begin
  {check for presence of TPWINDOW or other potentially conflicting unit}
  if TpUnitsFlag >= TpWindowFlag then begin
    WriteLn('TPWINDOW/TPSCREEN conflict');
    Halt(1);
  end;

  {signal that we're installed}
  TpUnitsFlag := TpScreenFlag;

  {set up exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @OurExitProc;

  {default to the physical screen}
  CurrentScreen := 0;

  {reset TextAttr if appropriate}
  if Turbo3StyleColors then
    HighVideo;

  {set flag to False so that InitVideo won't abort}
  Initialized := False;

  {other initialization}
  InitVideo;
end.
