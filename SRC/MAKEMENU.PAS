{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}
{$M 16384,30000,655360}

{Conditional defines that may affect this program}
{$I TPDEFINE.INC}

{*********************************************************}
{*                   MAKEMENU.PAS 5.22                   *}
{*                 Menu building utility                 *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program MakeMenu;
  {-Utility to build Turbo Professional menu systems}

uses
  TPString,
  TPCrt,
  TPEdit,
  TPCmd,
  TPWindow,
  {$IFDEF UseMouse}
  TPMouse,
  {$ENDIF}
  TPMenu;

const
  {Colors for the make menu}
  ColorColors : MenuColorArray =
  ($17,                      {FrameColor}
    $4E,                     {HeaderColor}
    $1B,                     {BodyColor}
    $7E,                     {SelectColor}
    $1E,                     {HiliteColor}
    $0E                      {HelpColor}
    {$IFDEF Tpro5Menu}
    ,
    $17,                     {DisabledColor}
    $03                      {ShadowColor}
    {$ENDIF}
    );
  ColorPromptAttr : Byte = $0E;
  ColorStringAttr : Byte = $0E;

  MonoColors : MenuColorArray =
  ($07,                      {FrameColor}
    $70,                     {HeaderColor}
    $07,                     {BodyColor}
    $70,                     {SelectColor}
    $09,                     {HiliteColor}
    $07                      {HelpColor}
    {$IFDEF Tpro5Menu}
    ,
    $07,                     {DisabledColor}
    $07                      {ShadowColor}
    {$ENDIF}
    );
  MonoPromptAttr : Byte = $0F;
  MonoStringAttr : Byte = $0F;

  FirstColor = FrameColor;
  {$IFDEF Tpro5Menu}
  LastColor = ShadowColor;
  {$ELSE}
  LastColor = HelpColor;
  {$ENDIF}

  {Other properties of the make menu}
  UseExplode : Boolean = False;
  UseShadow : Boolean = True;
  MakeShadowMode : ShadowType = SmallShadow;
  ExpDelay : Word = 5;
  MouseAttr : Byte = $4F;
  Frame1 : FrameArray = '…»ªºÕ∫';
  Frame2 : FrameArray = 'À»ÀºÕ∫';
  EditKeys : MenuCharSet = [#32, #$BB..#$C4]; {space, F1..F10}
  AcceptSet : MenuCharSet = [#13, #27, #32];
  HotKeySet : MenuCharSet = [^A, ^C, ^S, ^I, ^N, ^R, ^W, ^G, ^Q, ^D, ^E, ^P, ^O];
  Frames : array[0..6] of FrameArray =
  ('…»ªºÕ∫',
    '⁄¿øŸƒ≥',
    NoFrame,
    'À»ÀºÕ∫',
    '¬¿¬Ÿƒ≥',
    '’‘∏æÕ≥',
    '—‘—æÕ≥'
    );

  {Factory defaults for user menu}
  DefColors : MenuColorArray =
  ($0E,                      {FrameColor}
    $2E,                     {HeaderColor}
    $03,                     {BodyColor}
    $1E,                     {SelectColor}
    $0B,                     {HiliteColor}
    $0E                      {HelpColor}
    {$IFDEF Tpro5Menu}
    ,
    $19,                     {DisabledColor}
    $78                      {ShadowColor}
    {$ENDIF}
    );
  DefExplode : Boolean = False;
  DefShadow : Boolean = False;
  DefShadowMode : ShadowType = BigShadow;
  DefExpDelay : Word = 10;
  DefHelpRow : Byte = 1;
  DefStartRow : Byte = 2;
  DefFrame : FrameArray = '…»ªºÕ∫';
  DefOrient : Orientation = Vertical;

  MaxKeysInMenu = 1000;      {maximum number of keys in one menu system}

  CursorKeyHelp : string[59] = 'Use cursor keys to move. Press <Enter> or <Space> to accept';

  {.F-}
type
  MakeCommands =             {codes returned by each menu selection}
  (Mnone,                    {no command}
   Mmenu,                    {main menu root}
     MmenuChoose,              {select item to edit}
     MmenuNew,                 {make a new menu}
     MmenuSettings,            {choose base settings for menu}
       MmenuColors,              {set base colors for menu}
         MmenuColorFrame,          {set base color for frame}
         MmenuColorHeader,         {set base color for header}
         MmenuColorBody,           {set base color for body}
         MmenuColorSelect,         {set base color for selected item}
         MmenuColorHilite,         {set base color for hilite character}
         MmenuColorHelp,           {set base color for help line}
         {$IFDEF Tpro5Menu}
         MmenuColorDisabled,       {set base color for disabled items}
         MmenuColorShadow,         {set base color for shadows}
         {$ENDIF}
       MmenuFrame,               {set base frame type for menu}
         MmenuFrame1,              {choose base frame type 1}
         MmenuFrame2,              {choose base frame type 2}
         MmenuFrame3,              {choose base frame type 3}
         MmenuFrame4,              {choose base frame type 4}
         MmenuFrame5,              {choose base frame type 5}
         MmenuFrame6,              {choose base frame type 6}
         MmenuFrame7,              {choose base frame type 7}
       MmenuHelpRow,             {set base help row}
       MmenuOrient,              {set orientation for submenu}
         MmenuHoriz,               {set horizontal orientation}
         MmenuVert,                {set vertical orientation}
       {$IFDEF Tpro5Menu}
       MmenuExplode,             {set default explosion state}
       MmenuShadow,              {set default shadow state}
       MmenuExpDelay,            {set default explode delay}
       {$ENDIF}
       MmenuRestore,             {restore factory defaults}
       MmenuMapColors,           {toggle color mapping}
     MmenuRedraw,              {redraw menu system}
     MmenuInfo,                {info about MAKEMENU}
     MmenuKeys,                {renumber all keys}
   Msubmenu,                 {sub menu root}
     MsubAdd,                  {add a new submenu}
     MsubDrag,                 {move existing submenu and its children}
     MsubMove,                 {move an existing submenu}
     MsubSettings,             {change settings for a submenu}
       MsubColors,               {set colors for submenu}
         MsubColorFrame,           {set color for frame}
         MsubColorHeader,          {set color for header}
         MsubColorBody,            {set color for body}
         MsubColorSelect,          {set color for selected item}
         MsubColorHilite,          {set color for hilite character}
         MsubColorHelp,            {set color for help line}
         {$IFDEF Tpro5Menu}
         MsubColorDisabled,        {set color for disabled item}
         MsubColorShadow,          {set base color for shadows}
         {$ENDIF}
       MsubFrame,                {set frame type for submenu}
         MsubFrame1,               {choose frame type 1}
         MsubFrame2,               {choose frame type 2}
         MsubFrame3,               {choose frame type 3}
         MsubFrame4,               {choose frame type 4}
         MsubFrame5,               {choose frame type 5}
         MsubFrame6,               {choose base frame type 6}
         MsubFrame7,               {choose base frame type 7}
       MsubHelpRow,              {set row for help information}
       MsubOrient,               {set orientation for submenu}
         MsubHoriz,                {set horizontal orientation}
         MsubVert,                 {set vertical orientation}
       {$IFDEF Tpro5Menu}
       MsubExplode,              {set default explosion state}
       MsubShadow,               {set default shadow state}
       {$ENDIF}
     MsubHeader,               {set header for submenu}
     MsubResize,               {resize a submenu}
     MsubRemove,               {remove a submenu}
   Mitem,                    {item root}
     MitemAdd,                 {add item to submenu}
     MitemEdit,                {edit the name of the item}
     MitemKey,                 {set key for item}
     MitemMove,                {move the position of the item}
     MitemOrder,               {change the order of the items}
     MitemHelp,                {edit help text for item}
     MitemSelectChar,          {set selectchar for item}
     MitemRemove,              {remove item from submenu}
   Mfile,                    {file root}
     MfileRead,                {read library file for current menu}
     MfileWrite,               {write library file for current menu}
     MfileGenerate,            {write source code for current menu}
     MfilePack,                {pack a menu library}
     MfileQuit                 {quit the menu maker}
  );
{.F+}

  KeyMapArray = array[1..MaxKeysInMenu] of Boolean;

const
  {$IFDEF Tpro5Menu}
  MmenuColorLast = MmenuColorShadow;
  MsubColorLast = MsubColorShadow;
  {$ELSE}
  MmenuColorLast = MmenuColorHelp;
  MsubColorLast = MsubColorHelp;
 {$ENDIF}

var
  Make : Menu;               {menu for make commands}
  User : Menu;               {menu being made by the user}
  MakeStack : MenuStackP;    {path to current selection on make menu}
  UserStack : MenuStackP;    {path to current selection on user menu}
  Colors : MenuColorArray;   {colors for the make menu}
  PromptAttr : Byte;
  StringAttr : Byte;

  Key : MenuKey;             {key returned by make command selection}
  Ch : Char;                 {character returned by selection of make command}
  Saved : Boolean;           {true when user menu has been saved to disk}
  Done : Boolean;            {true when menu editing is complete}
  ItemsDisabled : Boolean;   {true when certain make menu items are disabled}

  InitXY : Word;             {cursor x,y position on entry to program}
  InitSL : Word;             {cursor scan lines on entry to program}

  LastRead : string[79];     {last file name read from}
  LastWrote : string[79];    {last file name written to}
  LastId : string[79];       {last id string specified}

  Covers : Pointer;          {line buffer for prompts}
  MakeHR : Byte;             {help row for make menu}
  TmpDelay : Word;           {stores delay temporarily during redraw}
  NextKey : MenuKey;         {used while renumbering keys}

  {$IFDEF UseMouse}
  MouseScreenMask : Word;    {controls mouse cursor}
  MouseCursorMask : Word;
  MX : Byte;                 {temporarily saved mouse position}
  MY : Byte;
  {$ENDIF}

  UserColors : MenuColorArray; {current global defaults for user menu}
  UserExplode : Boolean;
  UserShadow : Boolean;
  UserShadowMode : ShadowType;
  UserExpDelay : Word;
  UserHelpRow : Byte;
  UserStartRow : Byte;
  UserFrame : FrameArray;
  UserOrient : Orientation;

  {$I MAKEMENU.INC}

  procedure GetItemPos(SubMnu : SubMenuP; Item : ItemP;
                       var Row, Col : Word);
    {-Return starting position for item}
  begin
    with SubMnu^, Item^ do
      if Orient = Vertical then begin
        Row := YL+DisplayPos-1+FrameDelta[LotusStyle];
        Col := XL+FrameDelta[LotusStyle];
      end else begin
        Row := YL+FrameDelta[LotusStyle];
        Col := XL+DisplayPos-1+FrameDelta[LotusStyle];
      end;
  end;

  procedure MoveItem(SubMnu : SubMenuP);
    {-Interactively move an item in a menu}
  var
    Ch : Char;
    Scan : Char;
    DispX : Word;
    DispY : Word;
    DelX : Integer;
    DelY : Integer;
    Delta : Integer;
    EDelay : Word;
  begin
    {Erase the Make menu}
    EraseMenuOntoStack(Make, MakeStack);
    {Write some help}
    Help(CursorKeyHelp);

    with SubMnu^, Items.Current^ do begin
      {Temporarily get rid of explosion delays}
      EDelay := Draw.ExploDelay;
      Draw.ExploDelay := 0;
      {$IFDEF UseMouse}
      SaveMousePos;
      {$ENDIF}

      repeat
        {$IFDEF UseMouse}
        if MouseInstalled then begin
          GetItemPos(SubMnu, Items.Current, DispY, DispX);
          MouseGotoXY(DispX, DispY);
        end;
        {$ENDIF}
        Ch := ReadChar(Scan);
        GetDirection(Scan, DelX, DelY);
        if Orient = Horizontal then begin
          Delta := DelX;
          if Delta > 0 then
            if XL+DisplayPos+Delta-2+Byte(Name^)+3*FrameDelta[LotusStyle] >
            ScreenWidth then
              Delta := 0;
        end else begin
          Delta := DelY;
          if Delta > 0 then
            if YL-1+2*FrameDelta[LotusStyle]+DisplayPos+Delta >
            ScreenHeight-ShadowDelta[Draw.Shadowed] then
              Delta := 0;
        end;
        if DisplayPos+Delta < 1 then
          Delta := 0;
        if Delta <> 0 then begin
          EraseSubMenu(SubMnu);
          Inc(DisplayPos, Delta);
          AdjustXY(SubMnu, False);
          DrawSubMenu(SubMnu, nil);
        end;

      until (Ch in AcceptSet);

      {$IFDEF UseMouse}
      RestoreMousePos;
      {$ENDIF}
      Draw.ExploDelay := EDelay;
    end;

    ClearHelp;
    DrawMenuFromStack(Make, MakeStack);
  end;

  procedure SwapItems(SubMnu : SubMenuP; P, N : ItemP);
    {-Swap two item records}
  var
    TPos : Byte;
  begin
    with SubMnu^ do begin
      EraseSubMenu(SubMnu);
      {Swap the two items in the linked list}
      if P <> Items.First then
        P^.Prev^.Next := N;
      if N <> Items.Last then
        N^.Next^.Prev := P;
      P^.Next := N^.Next;
      N^.Prev := P^.Prev;
      N^.Next := P;
      P^.Prev := N;
      if P = Items.First then
        Items.First := N;
      if N = Items.Last then
        Items.Last := P;
      TPos := P^.DisplayPos;
      P^.DisplayPos := N^.DisplayPos;
      N^.DisplayPos := TPos;
      AdjustXY(SubMnu, False);
      DrawSubMenu(SubMnu, nil);
    end;
  end;

  procedure OrderItems(SubMnu : SubMenuP);
    {-Interactively reorder items in a submenu}
  var
    Ch : Char;
    Scan : Char;
    DispX : Word;
    DispY : Word;
    DelX : Integer;
    DelY : Integer;
    Delta : Integer;
    Item : ItemP;
    EDelay : Word;
  begin
    {Erase the Make menu}
    EraseMenuOntoStack(Make, MakeStack);
    {Write some help}
    Help(CursorKeyHelp);

    with SubMnu^ do begin
      {Temporarily get rid of explosion delays}
      EDelay := Draw.ExploDelay;
      Draw.ExploDelay := 0;
      {$IFDEF UseMouse}
      SaveMousePos;
      {$ENDIF}
      Item := Items.Current;

      repeat
        {$IFDEF UseMouse}
        if MouseInstalled then begin
          GetItemPos(SubMnu, Item, DispY, DispX);
          MouseGotoXY(DispX, DispY);
        end;
        {$ENDIF}
        Ch := ReadChar(Scan);
        GetDirection(Scan, DelX, DelY);
        if Orient = Horizontal then
          Delta := DelX
        else
          Delta := DelY;
        if Delta > 0 then begin
          if Item <> Items.Last then
            SwapItems(SubMnu, Item, Item^.Next);
        end else if Delta < 0 then begin
          if Item <> Items.First then
            SwapItems(SubMnu, Item^.Prev, Item);
        end;
      until (Ch in AcceptSet);

      {$IFDEF UseMouse}
      RestoreMousePos;
      {$ENDIF}
      Draw.ExploDelay := EDelay;
    end;

    ClearHelp;
    DrawMenuFromStack(Make, MakeStack);
  end;

  procedure MoveSelect(SubMnu : SubMenuP);
    {-Interactively move the select char of an item in a menu}
  var
    Ch : Char;
    Scan : Char;
    ItemC : ItemP;
    DelX : Integer;
    DelY : Integer;
    X : Byte;
    Y : Byte;
  begin

    {Erase the Make menu}
    EraseMenuOntoStack(Make, MakeStack);

    {Save the current item, and force current item to nil}
    ItemC := SubMnu^.Items.Current;
    DrawItem(SubMnu, ItemC, nil);
    X := WhereXAbs-1;
    with SubMnu^ do
      if (Orient = Vertical) and not(LotusStyle) then
        Inc(X);
    Y := WhereYAbs;
    SubMnu^.Items.Current := nil;
    DrawItem(SubMnu, ItemC, nil);

    Help(CursorKeyHelp);

    {$IFDEF UseMouse}
    SaveMousePos;
    {$ENDIF}

    with ItemC^ do
      repeat
        {Update cursor}
        if X+SelectPos > 0 then
          GoToXYAbs(X+SelectPos, Y);
        {$IFDEF UseMouse}
        if MouseInstalled then
          MouseGotoXY(X+SelectPos, Y);
        {$ENDIF}
        Ch := ReadChar(Scan);
        GetDirection(Scan, DelX, DelY);
        if DelX <> 0 then begin
          if DelX+SelectPos < 0 then
            DelX := 0;
          if DelX+SelectPos > Byte(Name^) then
            DelX := 0;
          if DelX <> 0 then begin
            Inc(SelectPos, DelX);
            DrawItem(SubMnu, ItemC, nil);
          end;
        end;
      until (Ch in AcceptSet);

    SubMnu^.Items.Current := ItemC;
    DrawItem(SubMnu, ItemC, nil);

    {$IFDEF UseMouse}
    RestoreMousePos;
    {$ENDIF}

    ClearHelp;
    DrawMenuFromStack(Make, MakeStack);
  end;

  procedure SetKeysSubMenu(SubMnu : SubMenuP);
    {-Renumber all keys in submenu}
  var
    P : ItemP;
  begin
    with SubMnu^ do begin
      P := Items.First;
      while P <> nil do begin
        P^.Key := NextKey;
        Inc(NextKey);
        with P^ do
          if Sub <> nil then
            {Follow this item's submenu}
            SetKeysSubMenu(Sub);
        {Get next item}
        P := P^.Next;
      end;
    end;
  end;


  procedure KeysInSubMenu(SubMnu : SubMenuP; var KeyMap : KeyMapArray);
    {-Mark used item keys in submenu}
  var
    P : ItemP;
    KeyNum : Word;
  begin
    with SubMnu^ do begin
      {Scan the list of items}
      P := Items.First;
      while P <> nil do begin
        KeyNum := Ord(P^.Key);
        if (KeyNum > 0) and (KeyNum <= MaxKeysInMenu) then
          KeyMap[KeyNum] := True;
        with P^ do
          if Sub <> nil then
            {Follow this item's submenu}
            KeysInSubMenu(Sub, KeyMap);
        {Get next item}
        P := P^.Next;
      end;
    end;
  end;

  function FirstUniqueKey(Mnu : Menu) : MenuKey;
    {-Return the next unused key value in Mnu}
  var
    KeyMap : KeyMapArray;
    K : Word;
  begin
    FillChar(KeyMap, SizeOf(KeyMap), False);
    {Mark all used keys}
    KeysInSubMenu(Mnu^.Root, KeyMap);
    {Scan to find first unused item key}
    for K := 1 to MaxKeysInMenu do
      if not KeyMap[K] then begin
        FirstUniqueKey := K;
        Exit;
      end;
    FirstUniqueKey := 0;
  end;

  procedure AddItem(SubMnu : SubMenuP; var S, T : string);
    {-Add a new item to a submenu}
  var
    P : ItemP;
    DispPos : Byte;
    XLast : Byte;

    function EndOf(P : ItemP) : Byte;
      {-Return the DispPos displacement of the end of the item}
    begin
      EndOf := P^.DisplayPos+Byte(P^.Name^)+2;
    end;

  begin
    with SubMnu^ do begin
      {Determine a reasonable display offset for the item}
      with Items do
        if Current = nil then
          {First item in submenu}
          DispPos := 1

        else if Orient = Horizontal then begin
          {Get end of current item}
          DispPos := EndOf(Current);
          {Shift any other items as needed}
          XLast := DispPos+Length(S)+4;
          P := Current^.Next;
          while P <> nil do begin
            if P^.DisplayPos < XLast then
              P^.DisplayPos := XLast;
            XLast := EndOf(P);
            P := P^.Next;
          end;

        end else begin
          {Insert after the current item}
          DispPos := Current^.DisplayPos+1;
          {Shift any other items down}
          P := Current^.Next;
          while P <> nil do begin
            Inc(P^.DisplayPos);
            P := P^.Next;
          end;
        end;

      Undraw;
      MenuItem(S, DispPos, FirstNonBlank(S), FirstUniqueKey(User), T);
      if MenuStatus <> MenuSuccess then
        PressEsc('Unable to add new item.')
      else begin
        AdjustXY(SubMnu, False);
        MarkNotSaved;
      end;
      Redraw;
    end;
  end;

  procedure RemoveSubMenu(SubMnu : SubMenuP);
    {-Remove a submenu and its children from the user menu}
  begin
    with SubMnu^.Items do
      if Current <> nil then
        if Current^.Sub <> nil then
          DisposeSubMenu(Current^.Sub);
  end;

  procedure RemoveItem(SubMnu : SubMenuP);
    {-Remove the current item from a submenu}
  var
    P : ItemP;
  begin
    Undraw;
    with SubMnu^ do begin
      P := Items.Current;
      if P <> nil then begin

        {Dispose of the item}
        with P^ do begin
          if OnHeap then begin
            {Dispose heap space for item name and help}
            DisposeString(Name);
            DisposeString(Help);
          end;
          if Sub <> nil then begin
            {Dispose of this item's submenu}
            DisposeSubMenu(Sub);
            Sub := nil;
          end;
        end;

        {Link around the deleted item}
        if P^.Next <> nil then
          P^.Next^.Prev := P^.Prev;
        if P^.Prev <> nil then
          P^.Prev^.Next := P^.Next;
        if P = Items.First then
          Items.First := P^.Next;
        if P = Items.Last then
          Items.Last := P^.Prev;
        if P^.Next <> nil then
          Items.Current := P^.Next
        else
          Items.Current := P^.Prev;

        {Dispose of this item}
        FreeMem(P, SizeOf(ItemRec));

        {Adjust the menu for the loss of the item}
        AdjustXY(SubMnu, True);
      end;
    end;
    Redraw;
  end;

  procedure UpdateDrawColors(SubMnu : SubMenuP);
    {-Update second copy of colors in WinDrawRec}
  begin
    with SubMnu^, Draw do begin
      FAttr := MapColor(Colors[FrameColor]);
      WAttr := MapColor(Colors[BodyColor]);
      HAttr := MapColor(Colors[HeaderColor]);
      {$IFDEF TPro5Menu}
      SAttr := MapColor(Colors[ShadowColor]);
      {$ENDIF}
    end;
  end;

  procedure SetColorSubMenu(SubMnu : SubMenuP);
    {-Set colors for submenu and children to UserColor set}
  var
    P : ItemP;
  begin
    with SubMnu^ do begin
      Colors := UserColors;
      UpdateDrawColors(SubMnu);
      {Scan the list of items}
      P := Items.First;
      while P <> nil do begin
        with P^ do
          if Sub <> nil then
            {Recolor this item's submenu}
            SetColorSubMenu(Sub);
        {Get next item}
        P := P^.Next;
      end;
    end;
  end;

  procedure PromptForColor(Xw, Yw : Byte; var Color : Byte);
    {-Choose a color from a menu, using initial Color as default}
  label
    ExitPoint;
  const
    Unsel = #4;
    Sel = #8;
    Def = #254;
  var
    F : Integer;
    B : Integer;
    Fdef : Byte;
    Bdef : Byte;
    DelX : Integer;
    DelY : Integer;
    W : WindowPtr;
    Ch : Char;
    Scan : Char;

    procedure DrawColor(F, B : Byte; Ch : Char);
      {-Draw one entry of the color map}
    var
      SaveMap : Boolean;
    begin
      SaveMap := MapColors;
      MapColors := False;
      FastWriteWindow(Ch, B+1, F+1, (B shl 4) or F);
      MapColors := SaveMap;
    end;

    procedure DrawMap;
      {-Draw the complete color map}
    var
      F : Byte;
      B : Byte;
    begin
      for F := 0 to 15 do
        for B := 0 to 7 do
          DrawColor(F, B, Unsel);
    end;

  begin

    {Initialize the window}
    FrameChars := Frame1;
    Explode := UseExplode;
    Shadow := UseShadow;
    ShadowMode := MakeShadowMode;
    {$IFDEF Tpro5Menu}
    ShadowAttr := Colors[ShadowColor];
    {$ELSE}
    ShadowAttr := 0;
    {$ENDIF}
    SoundFlagW := False;
    ExplodeDelay := ExpDelay;
    if not MakeWindow(W, Xw, Yw, Xw+17, Yw+9,
      True, True, False,
      Colors[BodyColor], Colors[FrameColor], 0, '') then begin
      PressEsc('Insufficient memory');
      ShadowMode := DefShadowMode;
      Exit;
    end;
    ShadowMode := DefShadowMode;

    {$IFDEF UseMouse}
    if MouseInstalled then begin
      SaveMousePos;
      HideMouse;
    end;
    {$ENDIF}

    if not DisplayWindow(W) then begin
      PressEsc('Insufficient memory');
      goto ExitPoint;
    end;

    {Draw the initial color map}
    DrawMap;

    {Save default color}
    Fdef := Color and $F;
    Bdef := Color shr 4;
    F := Fdef;
    B := Bdef;

    repeat
      {Pass back currently selected color and mark current position}
      Color := (B shl 4) or F;
      DrawColor(F, B, Sel);
      FastWrite(Center(HexB(Color), 4), Yw, Xw+7, MapColor(Colors[FrameColor]));
      GoToXY(F+1, B+1);
      {$IFDEF UseMouse}
      if MouseInstalled then
        MouseGotoXY(Xw+F+1, Yw+B+1);
      {$ENDIF}
      Ch := ReadChar(Scan);

      {Clear the previous selection}
      if (F = Fdef) and (B = Bdef) then
        DrawColor(F, B, Def)
      else
        DrawColor(F, B, Unsel);

      GetDirection(Scan, DelX, DelY);
      if Ch = #27 then begin
        {Restore default color}
        F := Fdef;
        B := Bdef;
        Color := (B shl 4) or F;
      end else begin
        if DelX <> 0 then
          if (F+DelX >= 0) and (F+DelX <= 15) then
            Inc(F, DelX);
        if DelY <> 0 then
          if (B+DelY >= 0) and (B+DelY <= 7) then
            Inc(B, DelY);
      end;
    until (Ch in AcceptSet);

    {Restore the screen}
    DisposeWindow(EraseTopWindow);

ExitPoint:
    {$IFDEF UseMouse}
    if MouseInstalled then begin
      RestoreMousePos;
      ShowMouse;
    end;
    {$ENDIF}
  end;

  function MenuGenerate(Fname : string) : Boolean;
    {-Generate source code for the current user menu}
  const
    MaxFrames = 10;
    MaxColors = 40;
    Quote = #39;
  var
    F : Text;
    I : Word;
    OutLen : Word;
    NumFrames : Integer;
    OFrames : array[1..MaxFrames] of FrameArray;
    NumColors : Integer;
    OColors : array[1..MaxColors] of MenuColorArray;
    C : MenuColorType;
    Fr : FrameCharType;
    NestLevel : Integer;
    GotExploding : Boolean;

    function MatchesFrame(var Frame : FrameArray; var num : Integer) : Boolean;
      {-Return true and frame number if frame matches a frame already stored}
    var
      I : Integer;
    begin
      for I := 1 to NumFrames do
        if Frame = OFrames[I] then begin
          num := I;
          MatchesFrame := True;
          Exit;
        end;
      MatchesFrame := False;
    end;

    function MatchesColors(var Colors : MenuColorArray; var num : Integer) : Boolean;
      {-Return true and Colors number if Colors matches any Color already stored}
    var
      I : Integer;
      C : MenuColorType;
      Matches : Boolean;
    begin
      for I := 1 to NumColors do begin
        Matches := True;
        for C := FirstColor to LastColor do
          if Colors[C] <> OColors[I][C] then
            Matches := False;
        if Matches then begin
          num := I;
          MatchesColors := True;
          Exit;
        end;
      end;
      MatchesColors := False;
    end;

    procedure GetArrays(SubMnu : SubMenuP);
      {-Get colors and frame types for submenu and children}
    var
      P : ItemP;
      I : Integer;
    begin
      with SubMnu^ do begin

        {Add frame and color types to the lists}

        if not(MatchesFrame(Frame, I)) then begin
          Inc(NumFrames);
          if NumFrames <= MaxFrames then
            OFrames[NumFrames] := Frame;
        end;

        if not(MatchesColors(Colors, I)) then begin
          Inc(NumColors);
          if NumColors <= MaxColors then
            OColors[NumColors] := Colors;
        end;

        {Scan the list of items and follow submenus}
        P := Items.First;
        while P <> nil do begin
          with P^ do
            if Sub <> nil then
              GetArrays(Sub);
          {Get next item}
          P := P^.Next;
        end;
      end;
    end;

    function QuotedString(SPtr : Pointer) : string;
      {-Return a string (perhaps containing quotes) in Pascal format}
    var
      S : string;
      I : Integer;
    begin
      S := StringFromHeap(SPtr);
      I := 1;
      while I <= Length(S) do begin
        if S[I] = Quote then begin
          Insert(Quote, S, I);
          Inc(I);
        end;
        Inc(I);
      end;
      QuotedString := Quote+S+Quote;
    end;

    procedure WriteChkLen(S : string);
      {-Write to output file, assuring line length does not exceed 124}
    begin
      if OutLen+Length(S) > 124 then begin
        Write(F, ^M^J, Pad('', 2*NestLevel));
        OutLen := 2*NestLevel;
      end;
      Write(F, S);
      Inc(OutLen, Length(S));
    end;

    procedure WriteSubSource(var F : Text; SubMnu : SubMenuP);
      {-Write the source code for one submenu and its children}
    const
      OrientName : array[Orientation] of string[10] = ('Vertical', 'Horizontal', '');
      FT : array[Boolean] of string[5] = ('False', 'True');
    var
      P : ItemP;
      I : Integer;
      MinX : Byte;
      MinY : Byte;
    begin
      with SubMnu^ do begin

        {Write the submenu statement}
        OutLen := 0;
        WriteChkLen(Pad('', 2*NestLevel));
        WriteChkLen('SubMenu(');
        WriteChkLen(Long2Str(XL));
        WriteChkLen(',');
        WriteChkLen(Long2Str(YL));
        WriteChkLen(',');
        if YHelp = 25 then
          {Guess that the last screen line is desired in 43/50 line mode}
          WriteChkLen('ScreenHeight')
        else
          WriteChkLen(Long2Str(YHelp));
        WriteChkLen(',');
        WriteChkLen(OrientName[Orient]);
        WriteChkLen(',');
        if MatchesFrame(Frame, I) then begin
          WriteChkLen('Frame');
          WriteChkLen(Long2Str(I));
          WriteChkLen(',');
        end;
        if MatchesColors(Colors, I) then begin
          WriteChkLen('Color');
          WriteChkLen(Long2Str(I));
          WriteChkLen(',');
        end;
        WriteChkLen(QuotedString(Header));
        WriteChkLen(');');
        WriteLn(F);

        Inc(NestLevel);

        {Write the mode statement}
        with Draw do
          if Exploding or Shadowed then begin
            OutLen := 0;
            WriteChkLen(Pad('', 2*NestLevel));
            WriteChkLen('MenuMode(');
            WriteChkLen(FT[Exploding]);
            WriteChkLen(', ');
            WriteChkLen(FT[Shadowed]);
            WriteChkLen(', False);');
            WriteLn(F);
            if Exploding then
              GotExploding := True;
          end;

        {Write width and height if needed}
        GetMinXY(SubMnu, MinX, MinY);
        if XH > MinX then
          WriteLn(F, Pad('', 2*NestLevel), 'MenuWidth(', XH-XL+1, ');');
        if YH > MinY then
          WriteLn(F, Pad('', 2*NestLevel), 'MenuHeight(', YH-YL+1, ');');

        {Scan the list of items and follow submenus}
        P := Items.First;
        while P <> nil do begin
          with P^ do begin

            {Write source for this item}
            OutLen := 0;
            WriteChkLen(Pad('', 2*NestLevel));
            WriteChkLen('MenuItem(');
            WriteChkLen(QuotedString(Name));
            WriteChkLen(',');
            WriteChkLen(Long2Str(DisplayPos));
            WriteChkLen(',');
            WriteChkLen(Long2Str(SelectPos));
            WriteChkLen(',');
            WriteChkLen(Long2Str(Key));
            WriteChkLen(',');
            WriteChkLen(QuotedString(Help));
            WriteChkLen(');');
            WriteLn(F);

            {Write its submenu}
            if Sub <> nil then
              WriteSubSource(F, Sub);
          end;
          {Get next item}
          P := P^.Next;
        end;

        {Leave this level of submenu}
        WriteLn(F, Pad('', 2*NestLevel), 'PopSublevel;');
        Dec(NestLevel);

      end;
    end;

  begin
    MenuGenerate := False;

    {Open the output file}
    Assign(F, Fname);
    Rewrite(F);
    if IoResult <> 0 then begin
      PressEsc('Unable to create output file '+Fname+'.');
      Exit;
    end;

    {Scan the menu to find the various colors and frames}
    NumColors := 0;
    NumFrames := 0;
    GetArrays(User^.Root);

    {Write the boilerplate source}
    WriteLn(F, 'uses');
    WriteLn(F, '  TPString,');
    WriteLn(F, '  TPCrt,');
    WriteLn(F, '  TPCmd,');
    WriteLn(F, '  TPWindow,');
    WriteLn(F, '  TPMenu;');
    WriteLn(F);
    WriteLn(F, 'procedure InitMenu(var M : Menu);');
    WriteLn(F, 'const');

    {Write the list of color items}
    for I := 1 to NumColors do begin
      Write(F, '  Color', I, ' : MenuColorArray = (');
      for C := FirstColor to LastColor do begin
        Write(F, '$', HexB(OColors[I][C]));
        if C <> LastColor then
          Write(F, ', ');
      end;
      WriteLn(F, ');');
    end;

    {Write the list of frame items}
    for I := 1 to NumFrames do begin
      Write(F, '  Frame', I, ' : FrameArray = ');
      if OFrames[I] = LotusFrame then
        Write(F, 'NoFrame')
      else begin
        Write(F, Quote);
        for Fr := ULeft to Vert do
          Write(F, OFrames[I][Fr]);
        Write(F, Quote);
      end;
      WriteLn(F, ';');
    end;

    {More boilerplate}
    WriteLn(F);
    WriteLn(F, 'begin');
    WriteLn(F, '  {Customize this call for special exit characters and custom item displays}');
    WriteLn(F, '  M := NewMenu([], nil);');
    WriteLn(F);

    {Here we go, write the menu system source}
    NestLevel := 1;
    GotExploding := False;
    WriteSubSource(F, User^.Root);

    {More boilerplate}
    WriteLn(F);
    WriteLn(F, '  ResetMenu(M);');
    if GotExploding then
      WriteLn(F, '  SetMenuDelay(M, ', User^.Root^.Draw.ExploDelay, ');');
    WriteLn(F, 'end;');

    {Make it a testable program}
    WriteLn(F);
    WriteLn(F, 'var');
    WriteLn(F, '  M : Menu;');
    WriteLn(F, '  Ch : Char;');
    WriteLn(F, '  Key : MenuKey;');
    WriteLn(F);
    WriteLn(F, 'begin');
    WriteLn(F, '  InitMenu(M);');
    WriteLn(F, '  Key := MenuChoice(M, Ch);');
    WriteLn(F, '  EraseMenu(M, False);');
    WriteLn(F, '  Writeln(''Key='', Key, '' Ch=#'', Ord(Ch));');
    WriteLn(F, 'end.');

    Close(F);
    MenuGenerate := (IoResult = 0);
  end;

  function ExistFile(S : string) : Boolean;
    {-returns true if file exists according to Reset operation}
  var
    Anyfile : file;
  begin
    Assign(Anyfile, S);
    Reset(Anyfile);
    if IoResult = 0 then begin
      Close(Anyfile);
      ExistFile := True;
    end else
      ExistFile := False;
  end;

  procedure RotateFileNames(S : string);
    {-erase S.BAK, renames S.??? to S.BAK, renames S.$$$ to S}
  var
    Anyfile : file;
    BakName : string;
    DolName : string;
  begin
    BakName := ForceExtension(S, 'BAK');
    DolName := ForceExtension(S, '$$$');
    if (S = BakName) or (S = DolName) then begin
      PressEsc('Invalid name used: '+S);
      Exit;
    end;
    if ExistFile(BakName) then begin
      Assign(Anyfile, BakName);
      Erase(Anyfile);
      if IoResult <> 0 then begin
        PressEsc('Unable to delete old backup "'+BakName+'"');
        Exit;
      end;
    end;
    if ExistFile(S) then begin
      Assign(Anyfile, S);
      Rename(Anyfile, BakName);
      if IoResult <> 0 then begin
        PressEsc('Unable to rename old "'+S+'" to "'+BakName+'"');
        Exit;
      end;
    end;
    Assign(Anyfile, DolName);
    Rename(Anyfile, S);
    if IoResult <> 0 then begin
      PressEsc('Unable to rename new "'+DolName+'" to "'+S+'"');
      Exit;
    end;
  end;

  procedure UpdateGlobalColor(WhichColor : MenuColorType);
    {-Update a global color setting}
  var
    C : Byte;
  begin
    C := UserColors[WhichColor];
    PromptForColor(38, 14, UserColors[WhichColor]);
    if UserColors[WhichColor] <> C then
      if HaveActiveNoError then begin
        {Update colors of current menu and all children}
        SetColorSubMenu(User^.Active);
        Undraw;
        MarkNotSaved;
        Redraw;
      end;
  end;

  procedure UpdateSubColor(WhichColor : MenuColorType);
    {-Update color of current submenu}
  var
    C : Byte;
  begin
    if HaveActive then
      with User^.Active^ do begin
        C := Colors[WhichColor];
        PromptForColor(58, 14, Colors[WhichColor]);
        if Colors[WhichColor] <> C then begin
          Undraw;
          MarkNotSaved;
          UpdateDrawColors(User^.Active);
          Redraw;
        end;
      end;
  end;

  procedure UpdateSubOrient(O : Orientation);
    {-Update orientation of a submenu}
  begin
    if HaveActive then begin
      Undraw;
      with User^.Active^ do begin
        Orient := O;
        {Reset window dimensions, AdjustXY will recompute}
        XH := XL;
        YH := YL;
      end;
      AdjustXY(User^.Active, True);
      MarkNotSaved;
      Redraw;
    end;
  end;

  procedure AddSubmenu;
    {-Add a submenu to the user menu}
  var
    X, Y : Byte;
  begin
    if User^.Active = nil then begin
      {The first submenu}
      X := 1;
      Y := UserStartRow;
    end else with User^.Active^ do
      if Items.Current^.Sub <> nil then begin
        {A submenu already attached here}
        PressEsc('Submenu already attached.');
        Exit;
      end else if UserFrame = LotusFrame then begin
        {Assume submenus overwrite one another}
        X := XL;
        Y := YL;
      end else if Orient = Horizontal then begin
        {Attach new submenu to base of active one}
        X := XL+Items.Current^.DisplayPos;
        Y := YH;
      end else begin
        {Overlap active vertical menu}
        X := (XL+XH) shr 1;
        Y := YL+Items.Current^.DisplayPos+1;
      end;
    if X > ScreenWidth-5 then
      X := ScreenWidth-5;
    if Y > ScreenHeight-6 then
      Y := ScreenHeight-6;
    SubMenu(X, Y, UserHelpRow, UserOrient, UserFrame, UserColors, '');
    if MenuStatus <> MenuSuccess then
      PressEsc('Unable to add submenu.')
    else
      with User^.Active^, Draw do begin
        {Assure menu is visible even if unframed}
        if XH < XL then begin
          XH := XL;
          XH1 := XH;
        end;
        if YH < YL then begin
          YH := YL;
          YH1 := YH;
        end;
        {$IFDEF Tpro5Menu}
        Exploding := UserExplode;
        Shadowed := UserShadow;
        ShadowM := UserShadowMode;
        ExploDelay := UserExpDelay;
        {$ENDIF}
      end;
  end;

  function HandleChoice(Cmd : MakeCommands) : Boolean;
    {-Perform an action on the menu being built}
  var
    S : string;
    T : string;
    Ch : Char;
    Key : MenuKey;
    X, Y : Byte;
    Escaped : Boolean;
    TStatus : MenuStatusType;
  begin

    HandleChoice := False;

    case Cmd of

      MmenuChoose :          {select item to edit}
        if HaveActive then begin
          EraseMenuOntoStack(Make, MakeStack);
          User^.Visible := True;
          TmpDelay := User^.Active^.Draw.ExploDelay;
          Help('Use cursors, <Enter>, <Esc> to browse. Press <Space> to select item to edit');
          repeat
            {Put up the user menu and get a new position to edit}
            Key := MenuChoice(User, Ch);
          until (Ch in EditKeys) or (MenuCmdNum = MKSUser0);
          ClearHelp;
          SetMenuDelay(User, 0);
          EraseMenuOntoStack(User, UserStack);
          Redraw;
        end;

      MmenuNew :             {make a new menu}
        if NoSave then begin
          Undraw;
          DisposeMenu(User);
          ClearUserStack;
          User := NewMenu(EditKeys, nil);
          AddSubmenu;
          DrawSubMenu(User^.Active, nil);
          DisableMakeNoItems;
          DisableMakeWhenSaved;
          Redraw;
          if MenuStatus <> MenuSuccess then begin
            PressEsc('Unable to create new menu.');
            User := nil;
          end;
        end;

      MmenuColorFrame..MmenuColorLast : {set global color}
        UpdateGlobalColor(MenuColorType(Ord(Cmd)-Ord(MmenuColorFrame)));

      MmenuFrame1..MmenuFrame7 : {choose base frame type}
        begin
          UserFrame := Frames[Ord(Cmd)-Ord(MmenuFrame1)];
          if HaveActiveNoError then
            UpdateFrames;
        end;

      MmenuHelpRow :         {set base help row}
        begin
          UserHelpRow := PromptLongInt('Row number for help: ', 0, 60, UserHelpRow);
          if HaveActiveNoError then begin
            Undraw;
            SetHelpRowSubMenu(User^.Active, UserHelpRow);
            Redraw;
          end;
        end;

      MmenuHoriz :           {set horizontal orientation}
        begin
          {Change current submenu}
          UpdateSubOrient(Horizontal);
          {Set default for others}
          UserOrient := Horizontal;
        end;

      MmenuVert :            {set vertical orientation}
        begin
          {Change current submenu}
          UpdateSubOrient(Vertical);
          {Set default for others}
          UserOrient := Vertical;
        end;

      {$IFDEF Tpro5Menu}
      MmenuExplode :         {toggle explode state}
        if HaveActiveNoError then begin
          Undraw;
          UserExplode := not UserExplode;
          SetMenuMode(User, UserExplode, UserShadow, False);
          if User^.Active^.Draw.ExploDelay = 0 then
            SetMenuDelay(User, UserExpDelay);
          TmpDelay := User^.Active^.Draw.ExploDelay;
          Redraw;
        end else
          UserExplode := not UserExplode;

      MmenuShadow :          {toggle shadow state}
        if HaveActiveNoError then begin
          Undraw;
          UserShadow := not UserShadow;
          SetMenuMode(User, UserExplode, UserShadow, False);
          Redraw;
        end else
          UserExplode := not UserExplode;

      MmenuExpDelay :        {set explosion delay}
        begin
          UserExpDelay := PromptLongInt('Delay per stage in milliseconds: ', 0, 500, LongInt(UserExpDelay));
          if HaveActiveNoError then
            SetMenuDelay(User, UserExpDelay);
        end;
      {$ENDIF}

      MmenuRestore :         {restore factory default settings}
        begin
          SetFactoryDefaults;
          EraseMenuOntoStack(Make, MakeStack);
          DrawMenuFromStack(Make, MakeStack);
        end;

      MmenuMapColors :       {toggle color mapping}
        begin
          Undraw;
          MapColors := not MapColors;
          Redraw;
        end;

      MmenuRedraw :          {refresh screen}
        begin
          Undraw;
          ClrScr;
          Redraw;
        end;

      MmenuInfo :            {info about menu system}
        PressEsc(Long2Str(MemAvail)+' RAM bytes free.');

      MmenuKeys :
        if Confirm('Are you sure you want to renumber all keys?') then begin
          MarkNotSaved;
          NextKey := 1;
          SetKeysSubMenu(User^.Root);
          PressEsc('All keys renumbered.')
        end;

      MsubAdd :              {add a new submenu}
        if User = nil then
          PressEsc('Create new menu first.')
        else begin
          AddSubmenu;
          Undraw;
          {!!}
          MarkNotSaved;
          Redraw;
        end;

      MsubMove :             {move an existing submenu}
        if HaveActive then begin
          MarkNotSaved;
          DragMenu(User^.Active, False);
        end;

      MsubColorFrame..MsubColorLast : {set color for submenu}
        UpdateSubColor(MenuColorType(Ord(Cmd)-Ord(MsubColorFrame)));

      MsubFrame1..MsubFrame7 : {choose base frame type}
        if HaveActive then begin
          MarkNotSaved;
          SetActiveFrame(Frames[Ord(Cmd)-Ord(MsubFrame1)], User^.Active);
        end;

      MsubHelpRow :          {set row for help information}
        if HaveActive then
          with User^.Active^ do begin
            Y := PromptLongInt('Row number for help: ', 0, 60, YHelp);
            Undraw;
            YHelp := Y;
            MarkNotSaved;
            Redraw;
          end;

      MsubHoriz :            {set horizontal orientation}
        UpdateSubOrient(Horizontal);

      MsubVert :             {set vertical orientation}
        UpdateSubOrient(Vertical);

      MsubHeader :           {set header for submenu}
        if HaveActive then begin
          with User^.Active^ do begin
            S := PromptString('Title: ', StringFromHeap(Header), Escaped);
            if Escaped then
              S := StringFromHeap(Header);
            Undraw;
            if Length(S) = 0 then
              Header := nil
            else begin
              Header := StringToHeap(S);
              if Header = nil then
                PressEsc('Unable to store header string.');
            end;
          end;
          MarkNotSaved;
          Redraw;
        end;

      {$IFDEF Tpro5Menu}
      MsubExplode :          {toggle current menu explode}
        if HaveActive then
          with User^.Active^.Draw do begin
            Undraw;
            Exploding := not Exploding;
            if Exploding then
              if ExploDelay = 0 then begin
                ExploDelay := UserExpDelay;
                TmpDelay := ExploDelay;
              end;
            Redraw;
          end;

      MsubShadow :           {toggle current menu shadow}
        if HaveActive then begin
          Undraw;
          with User^.Active^.Draw do
            Shadowed := not Shadowed;
          Redraw;
        end;
      {$ENDIF}

      MsubDrag :             {move a submenu and its descendants}
        if HaveActive then begin
          MarkNotSaved;
          DragMenu(User^.Active, True);
        end;

      MsubResize :           {resize a submenu}
        if HaveActive then begin
          MarkNotSaved;
          ResizeMenu(User^.Active);
        end;

      MsubRemove :           {remove a submenu}
        if HaveActive then
          if HaveItem then
            with User^.Active^ do
              if Items.Current^.Sub = nil then
                PressEsc('No submenu attached to current item.')
              else if Confirm('Are you sure you want to remove submenu?') then begin
                MarkNotSaved;
                RemoveSubMenu(User^.Active);
                PressEsc('Child submenu(s) removed.')
              end;

      MitemAdd :             {add item to submenu}
        if HaveActive then begin
          S := PromptString('Item name: ', '', Escaped);
          if Escaped or (Length(S) = 0) then
            Exit;
          if User^.Active^.YHelp = 0 then
            T := ''
          else begin
            T := PromptString('Help string: ', '', Escaped);
            if Escaped then
              Exit;
          end;
          EnableMakeWhenItems;
          AddItem(User^.Active, S, T);
        end;

      MitemEdit :            {edit the name of the item}
        if HaveActive then
          if HaveItem then
            with User^.Active^, Items.Current^ do begin
              S := PromptString('Item name: ', StringFromHeap(Name), Escaped);
              if Escaped then
                Exit;
              if S = StringFromHeap(Name) then
                Exit;
              Undraw;
              {Store the new string}
              if OnHeap then
                DisposeString(Name);
              Name := StringToHeap(S);
              {Check the window size}
              case Orient of
                Horizontal : X := XL+FrameDelta[LotusStyle]+DisplayPos+Length(S);
                Vertical : X := XL+4*FrameDelta[LotusStyle]+Length(S)-1;
              end;
              if XH < X then begin
                XH := X;
                Draw.XH1 := X;
              end;
              {Update the select position}
              SelectPos := FirstNonBlank(S);
              MarkNotSaved;
              Redraw;
            end;

      MitemMove :            {move the position of the item}
        if HaveActive then
          if HaveItem then begin
            MarkNotSaved;
            MoveItem(User^.Active);
          end;

      MitemOrder :           {change the order of the items}
        if HaveActive then
          if HaveItem then
            with User^.Active^.Items do
              if First <> Last then begin
                MarkNotSaved;
                OrderItems(User^.Active);
              end;

      MitemHelp :            {edit help text for item}
        if HaveActive then
          if HaveItem then
            with User^.Active^, Items.Current^ do begin
              S := PromptString('Help string: ', StringFromHeap(Help), Escaped);
              if Escaped or (S = StringFromHeap(Help)) then
                Exit;
              Undraw;
              {Store the new string}
              if OnHeap then
                DisposeString(Help);
              Help := StringToHeap(S);
              MarkNotSaved;
              Redraw;
            end;

      MitemSelectChar :      {set selectchar for item}
        if HaveActive then
          if HaveItem then begin
            MarkNotSaved;
            MoveSelect(User^.Active);
          end;

      MitemKey :             {set key for item}
        if HaveActive then
          if HaveItem then
            with User^.Active^.Items.Current^ do begin
              Key := PromptLongInt('Key number to return: ', 0, 0, LongInt(Key));
              {Make sure the Make menu is updated}
              Undraw;
              MarkNotSaved;
              Redraw;
            end;

      MitemRemove :          {remove item from submenu}
        if HaveActive then
          if HaveItem then
            if User^.Active^.Items.Current^.Sub <> nil then
              PressEsc('Cannot remove an item with submenus still attached.')
            else if Confirm('Are you sure you want to remove item?') then begin
              MarkNotSaved;
              RemoveItem(User^.Active);
            end;

      MfileRead :            {read library file for current menu}
        if NoSave then begin
          {Get file to read from}
          S := PromptString('Library file name: ', LastRead, Escaped);
          if Escaped or (Length(S) = 0) then
            Exit;
          S := defaultextension(S, 'LIB');
          LastRead := StUpcase(S);
          {Get id within that file}
          T := PromptString('Menu library ID: ', LastId, Escaped);
          if Escaped or (Length(T) = 0) then
            Exit;
          LastId := T;

          {Erase and deallocate the previous user menu}
          Undraw;
          DisposeMenu(User);
          ClearUserStack;

          {Read in the user menu}
          User := ReadMenuLib(S, T, nil);
          if MenuStatus <> MenuSuccess then begin
            PressEsc('Unable to read menu.');
            {Create an empty new menu}
            User := NewMenu(EditKeys, nil);
            AddSubmenu;
            DrawSubMenu(User^.Active, nil);
            DisableMakeNoItems;
            DisableMakeWhenSaved;
          end else begin
            DisableMakeWhenSaved;
            SetMenuSelectKeys(User, EditKeys);
            PushRootMenuOntoStack;
            EnableMakeWhenItems;
            SetDefaultsFromRoot;
            TmpDelay := UserExpDelay;
          end;
          Redraw;
        end;

      MfileWrite :           {write library file for current menu}
        if HaveActive then begin
          if Length(LastWrote) = 0 then
            LastWrote := LastRead;
          if Length(LastWrote) <> 0 then
            LastWrote := ForceExtension(LastWrote, 'LIB');
          S := PromptString('Library file name: ', LastWrote, Escaped);
          if Escaped or (Length(S) = 0) then
            Exit;
          S := defaultextension(S, 'LIB'); {!!}
          LastWrote := StUpcase(S);

          {Get id within that file}
          T := PromptString('Menu library ID: ', LastId, Escaped);
          if Escaped or (Length(T) = 0) then
            Exit;
          LastId := T;

          {Disable the special keys we use for menu making}
          SetMenuSelectKeys(User, []);

          {Write the user menu}
          WriteMenuLib(User, S, T);
          TStatus := MenuStatus;                 {!!.07}
          if TStatus = MenuLibraryFull then      {!!.03}
            PressEsc('Library directory full.')  {!!.03}
          else if TStatus <> MenuSuccess then    {!!.07}
            PressEsc('Unable to write menu.')
          else begin
            PressEsc('Menu written.');
            SelectMenuItem(Make, Ord(MfileGenerate));
            {$IFDEF Tpro5Menu}
            EraseMenuOntoStack(Make, MakeStack);
            DisableMakeWhenSaved;
            DrawMenuFromStack(Make, MakeStack);
            {$ENDIF}
          end;

          {Re-enable the special keys we use for menu making}
          SetMenuSelectKeys(User, EditKeys);
        end;

      MfileGenerate :        {write source code for current menu}
        if User <> nil then begin
          {Get the file to write to}
          if Length(LastWrote) = 0 then
            LastWrote := LastRead;
          if Length(LastWrote) <> 0 then
            LastWrote := ForceExtension(LastWrote, 'PAS');
          S := PromptString('Source file to write: ', LastWrote, Escaped);
          if Escaped or (Length(S) = 0) then
            Exit;
          S := defaultextension(S, 'PAS'); {!!}
          LastWrote := StUpcase(S);
          if MenuGenerate(ForceExtension(S, '$$$')) then begin
            RotateFileNames(S);
            PressEsc('Menu source code generated.');
          end;
        end;

      MfilePack :            {pack a menu library}
        begin
          {Get file to read from}
          if Length(LastWrote) = 0 then
            LastWrote := LastRead;
          if Length(LastWrote) <> 0 then
            LastWrote := ForceExtension(LastWrote, 'LIB');
          S := PromptString('Library file to pack: ', LastWrote, Escaped);
          if Escaped or (Length(S) = 0) then
            Exit;
          S := defaultextension(S, 'LIB'); {!!}
          LastRead := StUpcase(S);
          LastWrote := LastRead;
          {Pack the library}
          PackMenuLib(S, ForceExtension(S, '$$$'));
          if MenuStatus = MenuSuccess then begin
            RotateFileNames(S);
            PressEsc('Library packed.');
          end else
            PressEsc('Unable to pack library, or no packing required.');
        end;

      MfileQuit :            {quit the menu maker}
        if NoSave then
          HandleChoice := True;

    end;
  end;

begin
  {Make sure we can run under a multitasking environment}
  DetectMultitasking := True;
  ReinitCrt;

  {Initialize MAKEMENU variables}
  Initialize;

  {Build the menu system for MakeMenu}
  BuildMakeMenu;

  {Initialize an empty menu system}
  User := NewMenu(EditKeys, nil);
  AddSubmenu;
  {Show it to provide some visual feedback}
  DrawSubMenu(User^.Active, nil);

  {Select an initial menu choice}
  SelectMenuItem(Make, Ord(MitemAdd));

  {$IFDEF UseMouse}
  if MouseInstalled then begin
    SoftMouseCursor(MouseScreenMask, MouseCursorMask);
    FullMouseWindow;
    EnableMenuMouse;
    EnableEditMouse;
    ShowMouse;
  end;
  {$ENDIF}

  Done := False;
  repeat
    {Put up the make menus and get a menu action}
    Key := MenuChoice(Make, Ch);
    with Make^ do
      {Update the cursor position}
      DrawItem(Active, Active^.Items.Current, @DisplayFunc);

    {Handle the command}
    case Ch of
      ^M : Done := HandleChoice(MakeCommands(Key));
      ^A : Done := HandleChoice(MitemMove);
      ^C : Done := HandleChoice(MmenuChoose);
      ^D : Done := HandleChoice(MsubDrag);
      ^E : Done := HandleChoice(MitemEdit);
      ^G : Done := HandleChoice(MfileGenerate);
      ^I : Done := HandleChoice(MitemAdd);
      ^N : Done := HandleChoice(MmenuNew);
      ^O : Done := HandleChoice(MitemOrder);
      ^P : Done := HandleChoice(MfilePack);
      ^Q : Done := HandleChoice(MfileQuit);
      ^R : Done := HandleChoice(MfileRead);
      ^S : Done := HandleChoice(MsubAdd);
      ^W : Done := HandleChoice(MfileWrite);
    end;
  until Done;

  {$IFDEF UseMouse}
  if MouseInstalled then
    HideMouse;
  {$ENDIF}

  {Restore the screen}
  EraseMenu(Make, False);
  RestoreCursorState($1901, InitSL);
end.
