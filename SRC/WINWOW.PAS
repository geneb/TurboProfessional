{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{*********************************************************}
{*                   WINWOW.PAS 5.22                     *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program WindowWOW;

uses
  TPString,
  TPCrt,
  TPWindow;

const
  MaxWindow = 8;             {One less than total random windows to display}
  MainWAttr = $3B;           {Window attribute for main window}
  MainFAttr = $3E;           {Frame attribute for main window}
  MainHAttr = $4E;           {Header attribute for main window}
  RandFAttr = $0E;           {Frame attribute for random windows}
  RandHAttr = $1E;           {Header attribute for random windows}
  RandUFttr = $07;           {Unselected frame attribute for random windows}
  RandUHttr = $07;           {Unselected header attribute for random windows}
  ActiveFrame : FrameArray = 'ÉÈ»¼Íº';
  InActiFrame : FrameArray = 'ÚÀ¿ÙÄ³';
  Tpro : string[19] = 'Turbo Professional ';

var
  W : array[0..MaxWindow] of WindowPtr;
  V : WindowPtr;
  Main : WindowPtr;
  CW : Integer;
  MaxLines : Integer;
  WidthBase : Integer;
  HeightBase : Integer;
  VS : VScreen;
  R : Word;
  C : Word;

  procedure ErrorMem;
    {-Report out of memory error}
  begin
    Window(1, 1, ScreenWidth, ScreenHeight);
    NormVideo;
    ClrScr;
    NormalCursor;
    SetBlink(True);
    WriteLn('Insufficient Memory');
    Halt(1);
  end;

  function RandomStr(Len : Byte) : string;
    {-Return a random string of characters of length Len}
  var
    B : Byte;
  begin
    for B := 1 to Len do
      RandomStr[B] := Chr(Random(96)+32);
    RandomStr[0] := Chr(Len);
  end;

  procedure RandomWindow(Num : Integer);
    {-Initialize random window coordinates}
  var
    Attr : Byte;
    XL, YL, XH, YH : Byte;
  begin
    repeat
      XL := Random(ScreenWidth);
      XH := XL+12+Random(WidthBase);
    until (XL > 1) and (XH < ScreenWidth);
    repeat
      YL := Random(ScreenHeight-1);
      YH := YL+3+Random(HeightBase);
    until (YL > 1) and (YH < ScreenHeight-1);
    repeat
      Attr := MapColor(Succ(Random(255)));
    until (Attr and $F) <> (Attr shr 4);
    if not MakeWindow(W[Num], XL, YL, XH, YH, True, False, True,
      Attr, RandFAttr, RandHAttr,
      ' Window '+Long2Str(Num)+' ') then ErrorMem;
    SetInactiveFrame(W[Num], InActiFrame, RandUFttr, RandUHttr);
  end;

  procedure WriteLine(Num, Sta, Wid : Integer);
    {-Write one line to a window}
  begin
    Write(RandomStr(Wid));
  end;

  procedure UpdateWindow(Num : Integer);
    {-Update the contents of one window}
  var
    R : Integer;
    C : Integer;
  begin
    GotoXY(1, 1);
    with WindowP(W[Num])^ do
      if Odd(Num) then begin
        R := (60-(YH-YL)) shr 1;
        C := (128-(XH-XL)) shr 1;
        MoveVScreenToWindow(VS, R, C);
        Delay(15);
      end else begin
        for R := 1 to YH-YL+1 do
          WriteLine(Num, R, XH-XL+1);
        WriteLine(Num, R+1, XH-XL);
      end;
  end;

  procedure DrawWindow(Num : Integer);
    {Initialize contents of one window}
  begin
    if not DisplayWindow(W[Num]) then
      ErrorMem;
    UpdateWindow(Num);
  end;

  function Min(X, Y : Integer) : Integer;
    {-Return lesser of two integers}
  begin
    if X < Y then
      Min := X
    else
      Min := Y;
  end;

  procedure ScrollAndMove(Num : Integer);
    {-Move window while scrolling it}
  const
    XDel : array[1..4] of Integer = (1, -1, -1, 1);
    YDel : array[1..4] of Integer = (-1, -1, 1, 1);
  var
    DMax : array[1..4] of Integer;
    D, O, I, J, K : Integer;
  begin
    with WindowP(W[Num])^, Draw do begin
      {Decide which direction to move}
      DMax[1] := Min(ScreenWidth-XH1-1, YL1-2);
      DMax[2] := Min(XL1-1, YL1-2);
      DMax[3] := Min(XL1-1, ScreenHeight-YH1-1);
      DMax[4] := Min(ScreenWidth-XH1-1, ScreenHeight-YH1-1);
      D := 0;
      if Random(2) = 0 then begin
        for I := 1 to 4 do
          if DMax[I] > D then begin
            O := I;
            D := DMax[I];
          end;
      end else begin
        for I := 4 downto 1 do
          if DMax[I] > D then begin
            O := I;
            D := DMax[I];
          end;
      end;
      {There's a small chance the window can't move at all}
      if D = 0 then
        Exit;

      {Choose a random distance to move}
      D := 1+Random(D);
      for I := 1 to D do begin
        {Scroll a while - controls speed of move}
        if not Odd(Num) then begin
          WriteLn;
          K := Min(MaxLines, Random(YH-YL));
          for J := 1 to K do
            WriteLine(Num, J, XH-XL+1);
          WriteLine(Num, K+1, XH-XL);
        end;
        {Move window one row/column diagonally}
        if not MoveWindow(XDel[O], YDel[O]) then
          Exit;
      end;
    end;
  end;

  function SetDelta(N, O : Integer) : Integer;
    {-Determine step size}
  begin
    if N > O then
      SetDelta := 1
    else if N < O then
      SetDelta := -1
    else
      SetDelta := 0;
  end;

  procedure SizeAndRedraw(Num : Integer);
    {-Change size and refill window}
  var
    nXH1, nYH1 : Integer;
    XDel, YDel : Integer;
  begin
    with WindowP(W[Num])^, Draw do begin
      repeat
        nXH1 := XL1+12+Random(WidthBase);
      until nXH1 < ScreenWidth;
      repeat
        nYH1 := YL1+3+Random(HeightBase);
      until nYH1 <= ScreenHeight-1;
      XDel := SetDelta(nXH1, XH1);
      YDel := SetDelta(nYH1, YH1);

      while (XH1 <> nXH1) or (YH1 <> nYH1) do begin
        if not ResizeWindow(XDel, YDel, ' ') then
          Exit;
        UpdateWindow(Num);
        if nXH1 = XH1 then
          XDel := 0;
        if nYH1 = YH1 then
          YDel := 0;
      end;
    end;
  end;

  procedure ScrollVScreen(Num : Integer);
    {-Scroll the virtual screen over the current window}
  var
    R, C : Word;
    NewR, NewC : Word;
    Rdel, Cdel : Integer;
  begin
    if Odd(Num) then
      with WindowP(W[Num])^, Draw do begin
        R := (60-(YH-YL)) shr 1;
        C := (128-(XH-XL)) shr 1;
        NewR := 1+Random(60-(YH-YL));
        NewC := 1+Random(128-(XH-XL));
        Rdel := SetDelta(NewR, R);
        Cdel := SetDelta(NewC, C);
        while (R <> NewR) or (C <> NewC) do begin
          MoveVScreenToWindow(VS, R, C);
          Delay(20);
          if R = NewR then
            Rdel := 0;
          if C = NewC then
            Cdel := 0;
          Inc(R, Rdel);
          Inc(C, Cdel);
        end;
      end;
  end;

  procedure WriteHunk(R, C : Word; A : Byte);
    {-Write one portion of the virtual screen}
  begin
    FastWrite('    Windows     ', R, C, A);
    FastWrite('  that can be   ', R+1, C, A);
    FastWrite(' Moved Stacked  ', R+2, C, A);
    FastWrite(' Scrolled Sized ', R+3, C, A);
  end;

begin
  {make sure we can run under a multitasking environment}
  DetectMultitasking := True;
  ReinitCrt;

  {smooth scrolling on CGA's}
  BiosScroll := False;

  {turn break checking off}
  CheckBreak := False;

  {use exploding windows, quietly}
  Explode := True;
  ExplodeDelay := 10;
  SoundFlagW := False;

  {set a reasonable number of lines to scroll per move}
  if CheckSnow then
    MaxLines := 5
  else
    MaxLines := 15;

  {cursor off}
  HiddenCursor;

  {turn blinking off to get more colors}
  SetBlink(False);

  {define frame characters for windows}
  FrameChars := ActiveFrame;

  {Make a main window}
  if not MakeWindow(Main, 1, 1, ScreenWidth, ScreenHeight, True, True,
    False, MainWAttr, MainFAttr, MainHAttr,
    ' Turbo Professional TPWINDOW Demonstration ') then ErrorMem;
  if not DisplayWindow(Main) then ErrorMem;

  {Make random events more random}
  Randomize;

  {Make and initialize the virtual screen}
  if not MakeVScreen(VS, 60, 128) then ErrorMem;
  ClearVScreen(VS, 0, ' ');
  ActivateVScreen(VS);
  for R := 0 to 14 do
    for C := 0 to 7 do
      WriteHunk(4*R+1, 16*C+1, 1+Random(255));
  DeactivateVScreen;

  {Make and display a pile of windows}
  WidthBase := ScreenWidth div 3;
  HeightBase := (2*ScreenHeight-1) div 3;
  for CW := 0 to MaxWindow do begin
    RandomWindow(CW);
    DrawWindow(CW);
  end;

  {Select random windows until key pressed}
  CW := MaxWindow;
  repeat

    {Choose among the various effects with weighted randomness}
    case Random(6) of
      0 : SizeAndRedraw(CW);
      1..4 : ScrollAndMove(CW);
      5 : ScrollVScreen(CW);
    end;

    if not KeyPressed then begin
      {Pick another window}
      CW := Random(MaxWindow+1);
      {Pull it to the top of stack}
      if not SetTopWindow(W[CW]) then ErrorMem;
    end;
  until KeyPressed;
  CW := ReadKeyWord;

  {Erase and dispose of the windows}
  repeat
    V := EraseTopWindow;
    DisposeWindow(V);
  until V = nil;

  {Restore the cursor and the pallette}
  NormalCursor;
  SetBlink(True);
end.
