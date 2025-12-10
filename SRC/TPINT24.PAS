{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$IFNDEF Ver40}
  {$R-,O-,A-}
{$ENDIF}

{*********************************************************}
{*                   TPINT24.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpInt24;
  {-DOS critical error handler}

interface

function Int24Result : Word;
  {-Returns DOS critical error code in high byte, IoResult in low byte.}

procedure Int24On;
  {-Install DOS critical error handler.}

procedure Int24Off(RestoreDosHandler : Boolean);
  {-Restore DOS's critical error handler or Turbo's.}

  {==============================================================================}

implementation

var
  SaveExitProc : Pointer;

{$IFDEF Dpmi}  {!!.20 -- Modified to use the RTL's int $24 handler and map}
               {returned codes to the numbers Int24Result normally returns}

  function Int24Result : Word;
  var
    W : Word;
  begin
    W := IOResult;
    if W >= 150 then begin
      {critical error; map TP codes to values returned by Int24Result}
      Dec(W, 150);
      if W = 0 then
        W := $000D;
      W := (W shl 8);
    end;
    Int24Result := W;
  end;

  procedure Int24On;
  begin
    {do-nothing proc for protected mode}
  end;

  procedure Int24Off(RestoreDosHandler : Boolean);
  begin
    {do-nothing proc for protected mode}
  end;

{$ELSE}

  function IoResultPrimitive : Word;
    {-Calls IoResult for Int24Result}
  begin
    IoResultPrimitive := IoResult;
  end;

  {$L TPINT24.OBJ}

  function Int24Result : Word; external;
  procedure Int24On; external;
  procedure Int24Off(RestoreDosHandler : Boolean); external;
  procedure Int24Init; external;
  {-Save Turbo's vector}

  {$F+}
  procedure Int24ExitProc;
    {-Disable critical error handler on exit.}
  begin
    ExitProc := SaveExitProc;
    Int24Off(False);
  end;
  {$F-}

begin
  {activate critical error handler}
  Int24Init;
  Int24On;

  {set up exit handler}
  SaveExitProc := ExitProc;
  ExitProc := @Int24ExitProc;

{$ENDIF}

end.
