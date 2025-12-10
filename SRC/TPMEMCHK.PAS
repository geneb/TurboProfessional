{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
  {$DEFINE FMinus}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{$I TPDEFINE.INC} {!!.11}

{*********************************************************}
{*                   TPMEMCHK.PAS 5.22                   *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpMemChk;
  {-Allocate heap space. This unit is for internal use only.}

interface

function GetMemCheck(var P; Bytes : Word) : Boolean;
  {-Allocate heap space, returning true if successful}

procedure FreeMemCheck(var P; Bytes : Word);
  {-Deallocate heap space}

  {==============================================================}

implementation

  {$F+}
  function HeapFunc(Size : Word) : Integer;
    {-Return nil pointer if insufficient memory}
  begin
    {$IFDEF Heap6}       {!!.11}
    if Size = 0 then     {!!.11}
      HeapFunc := 2      {!!.11}
    else                 {!!.11}
    {$ENDIF}             {!!.11}
      HeapFunc := 1;
  end;
  {$IFDEF FMinus}
  {$F-}
  {$ENDIF}

  function GetMemCheck(var P; Bytes : Word) : Boolean;
    {-Allocate heap space, returning true if successful}
  var
    Pt : Pointer absolute P;
    SaveHeapError : Pointer;
  begin
    {Take over heap error control}
    SaveHeapError := HeapError;
    HeapError := @HeapFunc;
    GetMem(Pt, Bytes);
    GetMemCheck := (Pt <> nil);
    {Restore heap error control}
    HeapError := SaveHeapError;
  end;

  procedure FreeMemCheck(var P; Bytes : Word);
    {-Deallocate heap space}
  var
    Pt : Pointer absolute P;
  begin
    if Pt <> nil then begin
      FreeMem(Pt, Bytes);
      Pt := nil;
    end;
  end;

end.
