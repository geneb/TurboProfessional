{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{*********************************************************}
{*                  WINEXMPL.PAS 5.22                    *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program WinExample;
  {-This demonstrates windowing techniques using virtual screens.}

uses
  TpCrt,                     {basic screen routines}
  Dos,                       {needed by TpScreen}
  TpScreen;                  {virtual screen routines}

var
  X, Y : Byte;
  Key,
  ScanLines : Word;
  NeedDelay : Boolean;

  procedure WindowAll;
    {-Selects a window the size of the selected screen.}
  begin
    Window(1, 1, CurrentCols, CurrentRows);
  end;

  procedure WindowRel(X, Y, Cols, Rows : Byte);
    {-Creates a window with an upper left corner of X,Y and Cols columns and
      Rows rows.  Any part of the window which is out of bounds is clipped.}
  var
    X1, Y1 : Byte;
  begin
    X1 := Pred(X+Cols);
    Y1 := Pred(Y+Rows);
    if X1 > CurrentCols then
      X1 := CurrentCols;
    if Y1 > CurrentRows then
      Y1 := CurrentRows;
    Window(X, Y, X1, Y1);
  end;

  procedure DisplayFromBuf(BufNum, X, Y : Byte);
    {-Displays as much as possible of screen buffer number bufnum in the current
    screen window. The coordinate X,Y on the source buffer is mapped to the
    upper left hand corner of the currently selected window on the real screen.
    Any of the source extending outside the current window coordinates is
    clipped.}
  begin
    SelectScreen(BufNum);
    WindowRel(X, Y, Succ(CurrentCols-X), Succ(CurrentRows-Y));
    SelectScreen(0);
    CopyWindow(BufNum);
  end;

  procedure CreateBackDisplay;
    {-Creates our TURBO PROFESSIONAL display.}
  var
    I : Byte;
  begin
    {This selects an 80 x 25 RAM screen for us}
    SelectScreen(1);

    {write to our ram screen background}
    TextBackGround(White);
    TextColor(Black);
    SetFrameChars('º', 'Í', '¼', '»', 'È', 'É');
    FrameWindow(1, 1, 80, 25, TextAttr, TextAttr,
      ' TURBO PROFESSIONAL 5.2, Copyright (c) TurboPower Software 1992. ');
    TextColor(Yellow);
    TextBackGround(Blue);
    for I := 1 to 11 do begin
      Gotoxy(1, I shl 1);
      SpeedWrite(' TURBO PROFESSIONAL TURBO PROFESSIONAL TURBO PROFESSIONAL TURBO PROFESSIONAL  ');
    end;
    for I := 0 to 11 do begin
      Gotoxy(1, Succ(I shl 1));
      SpeedWrite(' PROFESSIONAL TURBO PROFESSIONAL TURBO PROFESSIONAL TURBO PROFESSIONAL TURBO  ');
    end;
    Gotoxy(1, 1);
  end;

  procedure CreateSmallWindow;
    {-Sets up the display in a small window.}
  var
    I : Word;
  begin
    {Write to our small screen}
    SelectScreen(3);
    HighVideo;
    TextBackGround(Blue);
    FrameWindow(1, 1, 30, 12, TextAttr, TextAttr, ' Fast windows. ');
    TextBackGround(LightGray);
    TextColor(Green);
    ClrScr;
    for I := 1 to 10 do begin
      Gotoxy(1, I);
      CenterWrite('FAST FAST FAST FAST FAST');
    end;
    Gotoxy(1, 1);
    {Select the full window that we'll copy to the screen}
    WindowAll;
  end;

  procedure FlashSmallWindows;
    {-Flashes lots of small windows on the screen.}
  var
    FC : Char;
    UPx, UPy, I : Word;
  begin
    I := 1;
    while (I < 100) and (not Keypressed) do begin

      {Select our small screen buffer.}
      SelectScreen(3);

      {Set our frame to a random block style.  By mixing background
       foreground and background colors using blocks, you can achieve
       hundreds of colors on a standard color monitor.}
      FC := Chr(Random(4)+176);
      if FC = #179 then
        FC := ' ';
      SetFrameChars(FC, FC, FC, FC, FC, FC);

      {Set a random color for background and foreground.}
      TextBackGround(Succ(Random(15)));
      TextColor(Succ(Random(31)));

      {Add a frame with a different color every time.}
      FrameWindow(1, 1, 30, 12, TextAttr, TextAttr, ' Fast windows. ');

      SelectScreen(0);
      {Select a random window on the real screen to display}
      UPx := Succ(Random(51));
      UPy := Succ(Random(14));
      WindowRel(UPx, UPy, 30, 12);

      {Display our small screen on it}
      DisplayFromBuf(3, 1, 1);

      {Increment I counter}
      Inc(I);
    end;

    {Leave a window just inside the frame}
    WindowRel(Succ(UPx), Succ(UPy), 28, 10);
  end;

  procedure ScrollOrigScreen;
    {-Scrolls the original screen around in a window.}
  var
    I : Word;
  begin
    if (not Keypressed) then begin

      {Select our fourth screen buffer (it holds the real screen)}
      SelectScreen(4);
      {Define a window the size of our small window less the frame.}
      WindowRel(1, 1, 28, 10);

      {Copy the window onto the real screen.}
      SelectScreen(0);
      CopyWindow(4);

      {Move the original screen around.}
      Delay(500);

      {First to the right}
      for I := 1 to 52 do begin
        {If monochrome monitor, then delay so its visible}
        if NeedDelay then
          Delay(20);
        DisplayFromBuf(4, Succ(I), 1);
      end;

      {Then down the right side}
      for I := 1 to 15 do begin
        {For horizontal moves, delay on all screens}
        Delay(20);
        DisplayFromBuf(4, 53, Succ(I));
      end;

      {Move it across the bottom}
      for I := 1 to 52 do begin
        {If monochrome monitor, then delay so its visible}
        if NeedDelay then
          Delay(20);
        DisplayFromBuf(4, 53-I, 16);
      end;

      {Then up the left}
      for I := 1 to 15 do begin
        Delay(20);
        DisplayFromBuf(4, 1, 16-I);
      end;
    end;
  end;

  procedure MoveSmallWindowAround;
    {-Moves our small buffer, non-destructively over the real screen, then
    restores the TURBO PROFESSIONAL buffer.}
  var
    I, J : Word;
  begin
    if (not Keypressed) then begin

      {Select our small window}
      SelectScreen(3);
      {Frame it}
      FrameWindow(1, 1, 30, 12, TextAttr, TextAttr, ' Motion ');
      {Window the whole thing}
      WindowAll;

      {Select real screen}
      SelectScreen(0);
      {Create a window the size of our small buffer on it}
      Window(1, 1, 30, 12);

      {Copy small buffer to upper left corner of our real screen.}
      CopyWindow(3);

      {Move the window non-destructively over the current screen}
      for I := 1 to 13 do
        MoveWindowVertical(2, 1, True);
      for I := 1 to 10 do
        MoveWindowHorizontal(2, 5, True);
      for I := 1 to 13 do
        MoveWindowVertical(2, 1, False);
      for I := 1 to 10 do
        MoveWindowHorizontal(2, 5, False);
    end;

    {Move the window over the old buffer, to restore TURBO PROFESSIONAL}
    I := 1;
    if not Keypressed then
      while (I < 6) and (not Keypressed) do begin
        for J := 1 to 13 do
          MoveWindowVertical(1, 1, True);
        MoveWindowHorizontal(1, 5, True);
        for J := 1 to 13 do
          MoveWindowVertical(1, 1, False);
        MoveWindowHorizontal(1, 5, True);
        I := Succ(I);
      end;
    for I := 1 to 13 do
      MoveWindowVertical(1, 1, True);
    if (not Keypressed) then
      Delay(1500);
  end;

begin
  Turbo3StyleColors := True;
  CheckBreak := False;

  {smooth scrolling on CGA's}
  BiosScroll := False;

  {make sure we can run under a multitasking environment}
  DetectMultitasking := True;
  ReinitScreen;

  {turn blinking off to get more colors}
  SetBlink(False);

  {save screen info}
  X := WhereX;
  Y := WhereY;
  ScanLines := CursorTypeSL;
  NeedDelay := (CurrentMode = 7) or not CheckSnow;

  if CurrentMode in [2, 3, 7] then begin
    if (AllocateScreen(1, 80, 25) and AllocateScreen(2, 80, 25))
    and (AllocateScreen(3, 30, 12) and AllocateScreen(4, 80, 25)) then begin

      {Make our background buffer}
      CreateBackDisplay;

      {Make a little buffer}
      CreateSmallWindow;

      {This selects one of our 80 x 25 RAM screens}
      SelectScreen(4);

      {Copy the real screen to buffer number 4}
      CopyScreen(0);

      {This selects our real video screen}
      SelectScreen(0);

      {hide the cursor}
      SetCursorSize($20, 0);

      {This loops forever until a key is pressed.}
      repeat
        {Copy our TURBO PROFESSIONAL background to it first}
        CopyScreen(1);

        {This is so you can see it in monochrome as well as color}
        Delay(1000);

        {Flash lots of small windows that say "FAST WINDOWS" on the screen.}
        FlashSmallWindows;

        {Scroll original screen around.}
        ScrollOrigScreen;

        {store the current screen to our background.}
        SelectScreen(2);
        CopyScreen(0);

        MoveSmallWindowAround;

      until Keypressed;

      {Clear out key from keyboard buffer.}
      Key := ReadKeyWord;

      {Select the real screen}
      SelectScreen(0);

      {Restore the original screen}
      CopyScreen(4);
      WindowAll;
      Gotoxy(X, Y);
      SetCursorSize(Hi(ScanLines), Lo(ScanLines));

      {Deallocate our buffers -- not really necessary for this program}
      DeallocateScreen(1);
      DeallocateScreen(2);
      DeallocateScreen(3);
      DeallocateScreen(4);
    end;
  end;
end.
