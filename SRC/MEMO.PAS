{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}
{$M 16384,16384,600000}

{*********************************************************}
{*                    MEMO.PAS 5.22                      *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1988, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program TpMemoTest;
  {-Test program for TPMEMO}

  {$I TPDEFINE.INC}

uses
  TpCrt,                     {Turbo Professional CRT unit}
  TpString,                  {Turbo Professional string handling}
  {$IFDEF UseMouse}
  TpMouse,                   {Turbo Professional mouse routines}
  {$ENDIF}
  TpMemo;                    {memo field editor}

const
  StatusA     : array[Boolean] of Byte = ($2F, $70);
  ErrorA      : array[Boolean] of Byte = ($1F, $0F);
  TextA       : array[Boolean] of Byte = ($1B, $07);
  CtrlA       : array[Boolean] of Byte = ($1C, $0F);
  MouseA      : array[Boolean] of Byte = ($4E, $70);
  UserCmds    : array[1..1] of EMtype = (EMnone);
var
  I, FSize    : LongInt;
  EMCB        : EMcontrolBlock;
  Buffer      : Pointer;
  BufSize     : Word;
  BandW       : Boolean;
  ExitCode    : EMtype;
  FName       : string[79];

  procedure Abort(Msg : string);
    {-Display an error message and halt}
  begin
    {$IFDEF UseMouse}
    {hide the mouse cursor}
    HideMouse;
    {$ENDIF}

    ClrScr;
    WriteLn(Msg);
    Halt(1);
  end;

  procedure ClearMessageLine;
    {-Clear the message line}
  begin
    FastWrite(CharStr(' ', ScreenWidth), ErrorRow, 1, ErrorAttr);
  end;

  procedure DisplayMessage(Msg : string);
    {-Display a message at the top of the screen}
  begin
    ClearMessageLine;
    FastWrite(Msg, ErrorRow, 1, ErrorAttr);
    GotoXYabs(Length(Msg)+2, ErrorRow);
  end;

  function YesNo(Msg : string) : Boolean;
    {-Get a response to a yes/no question. Return True for Y, False for N}
  var
    ChWord : Word;
    Ch : Char absolute ChWord;
  begin
    DisplayMessage(Msg);
    repeat
      ChWord := ReadKeyWord;
      Ch := Upcase(Ch);
    until (Ch = 'Y') or (Ch = 'N');
    YesNo := (Ch = 'Y');
    ClearMessageLine;
  end;

  procedure SaveFile;
    {-Save the file in the edit buffer}
  const
    MakeBackUp = True;
  begin
    DisplayMessage('Saving file...');
    case SaveMemoFile(EMCB, FName, MakeBackup) of
      mstOK :
        {file was saved} ;
      mstCreationError :
        Abort('Error creating '+FName);
      mstWriteError :
        Abort('Error writing to '+FName);
      mstCloseError :
        Abort('Error closing '+FName);
    end;
    ClearMessageLine;
  end;

begin
  {allocate edit buffer}
  I := MaxAvail;
  if I > $FFF1 then
    BufSize := $FFF1
  else
    BufSize := I;
  GetMem(Buffer, BufSize);

  {get name of file to edit}
  FName := ParamStr(1);
  if Length(FName) = 0 then begin
    Write('File to edit: ');
    BufLen := 64;
    ReadLn(FName);
  end;

  {halt if no filename specified}
  if Length(FName) = 0 then
    Halt(0);

  {don't allow reading of partial files}
  AllowTruncation := False;

  {open file}
  case ReadMemoFile(Buffer^, BufSize, FName, FSize) of
    mstOK :
      {file read in OK} ;
    mstInvalidName :
      Abort(FName + ' is an invalid pathname');
    mstNotFound :
      {file not found, we'll create it later} ;
    mstReadError :
      Abort('Error reading '+FName);
    mstTooLarge :
      Abort(FName+' is too large to edit');
    mstCloseError :
      Abort('Error closing '+FName);
  end;

  {use default status and error handlers}
  MemoStatusPtr := @MemoStatus;
  MemoErrorPtr := @MemoError;

  {set attribute for status and error lines}
  BandW := (CurrentMode = 7) or (CurrentMode = 2);
  StatusAttr := StatusA[BandW];
  ErrorAttr := ErrorA[BandW];

  {$IFDEF UseMouse}
  if MouseInstalled then begin
    {use a red diamond for our mouse cursor}
    SoftMouseCursor($0000, (MouseA[BandW] shl 8)+$04);
    ShowMouse;

    {enable mouse support}
    EnableMemoMouse;
  end;
  {$ENDIF}

  {EMuser0 = save file and continue: ^KS, F2}
  if not AddMemoCommand(EMuser0, 2, Ord(^K), Ord(^S)) then {};
  if not AddMemoCommand(EMuser0, 1, $3C00, 0) then {};

  {EMuser1 = save file and exit: ^KX, ^F2}
  if not AddMemoCommand(EMuser1, 2, Ord(^K), Ord(^X)) then {};
  if not AddMemoCommand(EMuser1, 1, $5F00, 0) then {};

  {EMuser2 = abandon file: ^KQ, AltF2}
  if not AddMemoCommand(EMuser2, 2, Ord(^K), Ord(^Q)) then {};
  if not AddMemoCommand(EMuser2, 1, $6900, 0) then {};

  {initialize the control block}
  InitControlBlock(
    EMCB,                    {control block}
    1,                       {left column of edit window}
    3,                       {top row of edit window}
    ScreenWidth-1,           {right column of edit window}
    ScreenHeight-1,          {bottom row of edit window}
    TextA[BandW],            {attribute for normal text}
    CtrlA[BandW],            {attribute for control characters}
    True,                    {insert mode on?}
    True,                    {auto-indent on?}
    True,                    {word wrap on?}
    8,                       {distance between tab stops}
    0,                       {help index}
    ScreenWidth-2,           {right margin}
    MaxInt,                  {maximum number of lines}
    BufSize,                 {size of edit buffer}
    Buffer^);                {edit buffer}

  {clear the message line}
  ClearMessageLine;

  repeat
    {start editing}
    ExitCode := EditMemo(EMCB, False, UserCmds);

    {process exit command}
    case ExitCode of
      EMuser0,               {save and continue}
      EMuser1 :              {save and quit}
        SaveFile;
      EMquit,                {quit}
      EMuser2 :              {abandon file}
        if not EMCB.Modified then
          ExitCode := EMquit
          {file was modified--verify that user wants to quit}
        else if YesNo('File modified. Quit anyway?') then
            ExitCode := EMquit
          else
            ExitCode := EMnone;
    end;
  until (ExitCode = EMquit) or (ExitCode = EMuser1);

  {$IFDEF UseMouse}
  {hide the mouse cursor}
  HideMouse;
  {$ENDIF}

  ClrScr;
end.
