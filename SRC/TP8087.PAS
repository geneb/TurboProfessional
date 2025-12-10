{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$R-,O-,A-}
{$ENDIF}

{*********************************************************}
{*                    TP8087.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit Tp8087;
  {-Routines to add 80x87 support to pop-up routines}

interface

type
  SaveBuffer8087 =
    record
      Control : Word;        {control word}
      Status : Word;         {status word}
      Tag : Word;            {tags for stack}
      InstPtr : LongInt;     {instruction pointer}
      OpPtr : LongInt;       {data pointer}
      Regs8087 : array[0..7] of Extended; {stack}
    end;

  {$IFNDEF Ver40}
    {$IFOPT N+}
      {we're compiling with Turbo 5.0 or higher and $N+ is on}
      {$DEFINE UseEmulation}
    {$ENDIF}
  {$ENDIF}

procedure Save8087(var SaveBuf : SaveBuffer8087);
  {-Saves the 80x87 registers in the save buffer.}

procedure Restore8087(var SaveBuf : SaveBuffer8087);
  {-Restores the 80x87 registers from the save buffer.}

function Installed8087 : Boolean;
  {-Returns true if an 80x87 coprocessor is installed.}

procedure Exceptions8087(On : Boolean);
  {-Turn exception interrupts on or off}

function Error8087 : Word;
  {-Return (and clear) the error status of the 80x87}

procedure Reinit8087;
  {-Reinitialize the 8087 chip}
inline(
  $9B/$DB/$E3); {FINIT  ;actual}

{$IFNDEF Ver40}

  procedure ReinitEmulator;
    {-Reinitialize the emulator}
  inline(
    $CD/$37/$E3); {FINIT  ;emulated}

  function UseEmulator : Boolean;
    {-Return True if ReinitEmulator should be used rather than Reinit8087}

{$ENDIF}

  {==========================================================================}

implementation

  {$IFDEF UseEmulation}
    {$L TP8087e.OBJ}
  {$ELSE}
    {$L TP8087.OBJ}
    function Installed_8087 : Boolean; external;
  {$ENDIF}

  procedure Save8087(var SaveBuf : SaveBuffer8087); external;
  procedure Restore8087(var SaveBuf : SaveBuffer8087); external;
  procedure Exceptions8087(On : Boolean); external;
  function Error8087 : Word; external;

  {$IFDEF Ver40}
    function Installed8087 : Boolean;
    begin
      Installed8087 := Installed_8087;
    end;
  {$ELSE}
    function Installed8087 : Boolean;
    begin
     {Test8087 values: 0 = no 80x87, 1 = 8087, 2 = 80287, 3 = 80387}
     Installed8087 := (Test8087 > 0);
    end;
 {$ENDIF}

{$IFNDEF Ver40}
var
  OrigSS : Word;             {value of SSeg when program began}

  function UseEmulator : Boolean;
    {-Return True if ReinitEmulator should be used rather than Reinit8087}
  type
    Array3 = array[1..3] of Char;
  const
    EmuSignature : Array3 = 'emu';
  var
    A3P : ^Array3;
  begin
    {$IFDEF Dpmi}              {!!.20}
    A3P := Ptr(OrigSS, $F0);   {!!.20}
    {$ELSE}                    {!!.20}
    A3P := Ptr(OrigSS, $E0);
    {$ENDIF}                   {!!.20}
    {using emulator if Test8087 is 0 and emulator's signature is found}
    UseEmulator := (Test8087 = 0) and (A3P^ = EmuSignature);
  end;

begin
  OrigSS := SSeg;
{$ENDIF}
end.
