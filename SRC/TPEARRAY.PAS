{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$IFDEF Dpmi}
  !! ERROR - This unit is not compatible with Protected mode !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$R-,O+,A-}
{$ENDIF}

{*********************************************************}
{*                  TPEARRAY.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpEarray;
  {-Dynamically allocated arrays larger than 64K in Expanded memory}

interface

uses
  Dos,
  TpMemChk,
  TpEms;

type
  TpArray = Pointer;         {Generic type of TpArray}
  InitType =                 {Initialization options for new arrays}
    (ExactInit, FastInit);

const
  WriteError : Boolean = True; {Settings for Error handling}
  HaltOnError : Boolean = True;
  RangeCheck : Boolean = False;

var
  EmsAvailable : Boolean;    {True if EMS is available}

function ErrorA : Word;
  {-Return the last error number and reset the error variable}

procedure RetA(A : TpArray; R, C : Word; var Value);
  {-Return value of A[r,c]}

procedure SetA(A : TpArray; R, C : Word; var Value);
  {-Set array element A[r,c] to value}

procedure ClearA(A : TpArray; var Value; Initialize : InitType);
  {-Initialize all array values to Value}

procedure MakeA(var A : TpArray; Rows : Word; Cols : Word; ElementSize : Word);
  {-Allocate array}

procedure DisposeA(var A : TpArray);
  {-Deallocate array}

procedure StoreA(A : TpArray; FileName : string);
  {-Write array to disk}

procedure LoadA(var A : TpArray; FileName : string);
  {-Allocate and read array from disk}

  {==========================================================================}

implementation

const
  EmsPageSize = 16384;       {Number of bytes in EMS page}
  EmsPageSizeMax = 16383;    {EmsPageSize-1}
  EmsWinMax = 1;             {Highest two page window 0..EmsWinMax}
  ColsOfs = 0;               {Offsets within header record of each field}
  ElSiOfs = 2;
  RowsOfs = 4;
  IdString : string[6] = 'EARRAY'; {Written at the start of array files}

type

  {Data structures for management of large arrays}

  {Header for description of an array}
  {DO NOT CHANGE WITHOUT UPDATING RECORD OFFSETS ABOVE}
  ArrayHeader =
    record
      Cols : Word;
      ElSize : Word;
      Rows : Word;
      PageCount : Word;
      ID : string[6];
    end;

  {Data storage}
  TpArrayRec =
    record
      Handle : Word;
      Header : ArrayHeader;
    end;
  TpArrayInternal = ^TpArrayRec;

  {Window mapping - each window is two EMS pages}
  {Largest allowable array element is 16384 bytes}
  EmsRec =
    record
      Hand : Word;
      Page : Word;
      LastUsed : Word;
    end;
  EmsRecArray = array[0..EmsWinMax] of EmsRec;
  DataPage = array[0..EmsPageSizeMax] of Byte;
  DataPagePtr = ^DataPage;
  EmsPtr = array[0..EmsWinMax] of DataPagePtr;

var
  ArrayErrorLast : Word;     {Holds the last error number encountered}
  Pnum : Word;               {Global results of address calculations}
  Pofs : Word;
  EmsInfo : EmsRecArray;     {Information about each EMS window}
  EmsWindow : EmsPtr;        {Pointer to each window}
  LruCount : Word;           {Quasi-time counter}

  procedure Error(ErrNum : Word);
    {-Store, report and/or halt on errors}
  begin
    ArrayErrorLast := ErrNum;
    if WriteError then
      case ErrNum of
        1 : WriteLn('Row index out of range');
        2 : WriteLn('Column index out of range');
        3 : WriteLn('Invalid element size');
        4 : WriteLn('Invalid row or column limit');
        7 : WriteLn('Insufficient memory to allocate array');
        8 : WriteLn('File creation error');
        9 : WriteLn('File write error');
        10 : WriteLn('Error while closing file');
        11 : WriteLn('File not found');
        12 : WriteLn('File read error');
        13 : WriteLn('EMS page mapping error');
        14 : WriteLn('EMS driver and/or hardware not installed');
        15 : WriteLn('Insufficient EMS memory to allocate array');
        16 : WriteLn('Error deallocating EMS memory');
        17 : WriteLn('Invalid file format');
      end;
    if HaltOnError then
      Halt(1);
  end;

  function DivUp(X, Y : LongInt) : Word;
    {-Compute X div Y and round up}
  var
    result : Word;
  begin
    result := X div Y;
    if X mod Y <> 0 then
      Inc(result);
    DivUp := result;
  end;

  function ErrorA : Word;
    {-Return the last error number and reset the error variable}
  begin
    ErrorA := ArrayErrorLast;
    ArrayErrorLast := 0;
  end;

  function RangeError(var H : ArrayHeader; R, C : Word) : Boolean;
    {-Check for addressing range errors}
  begin
    RangeError := True;
    with H do begin
      if R >= Rows then begin
        Error(1);
        Exit;
      end;
      if C >= Cols then begin
        Error(2);
        Exit;
      end;
    end;
    RangeError := False;
  end;

  procedure ArrayAddress(H : ArrayHeader; R, C : Word);
    {-Return the page parameters for a given row and column}
  inline(
    $5B/                     {pop bx                     ;Save column in bx}
    $58/                     {pop ax                     ;Row in ax}
    $5F/                     {pop di                     ;Offset of array header}
    $07/                     {pop es                     ;Segment of array header}
    $26/                     {es:}
    $F7/$65/<ColsOfs/        {mul word ptr [di+<ColsOfs] ;R*Cols in dx:ax}
    $01/$D8/                 {add ax,bx                  ;Add in column}
    $81/$D2/$00/$00/         {adc dx,0                   ;Carry into high word}
    $26/                     {es:}
    $8B/$4D/<ElSiOfs/        {mov cx,[di+<ElSiOfs]       ;ElSize in cx}
    $89/$D7/                 {mov di,dx                  ;Save high word of multiplicand}
    $F7/$E1/                 {mul cx                     ;Multiply low word}
    $89/$C6/                 {mov si,ax                  ;Save low word result}
    $89/$D3/                 {mov bx,dx                  ;Save partial high word result}
    $89/$F8/                 {mov ax,di                  ;Get high word of multiplicand}
    $F7/$E1/                 {mul cx                     ;Multiply high word}
    $89/$C2/                 {mov dx,ax                  ;Save result in high word of output}
    $01/$DA/                 {add dx,bx                  ;Add other part of high word}
    $89/$F0/                 {mov ax,si                  ;Get low word result back}
    $81/$E6/$FF/$3F/         {and si,$3FFF               ;Mask off two top bits}
    $89/$36/>Pofs/           {mov [>Pofs],si             ;Save page offset}
    $D1/$D0/                 {rcl ax,1                   ;Top two bits of ax into dx}
    $D1/$D2/                 {rcl dx,1}
    $D1/$D0/                 {rcl ax,1}
    $D1/$D2/                 {rcl dx,1}
    $89/$16/>Pnum);          {mov [>Pnum],dx             ;Save page number}
  {Equivalent to}
  {  ByteOfs := H.ElSize*(C+H.Cols*R)}
  {  Pnum := ByteOfs div EmsPageSize}
  {  Pofs := ByteOfs mod EmsPageSize}

  function MapWindow(Handle, Pnum : Word) : Word;
    {-Return the EMS window number which has desired data mapped}
  var
    W : Word;
    Win : Word;
    MinLRU : Word;
  begin

    {Update quasi-time}
    Inc(LruCount);
    if LruCount = 0 then
      {Reset all LRU at wraparound}
      for W := 0 to EmsWinMax do
        EmsInfo[W].LastUsed := 0;

    MinLRU := $FFFF;
    Win := 0;

    {Scan for desired window, or least recently used one}
    for W := 0 to EmsWinMax do
      with EmsInfo[W] do
        if (Hand = Handle) and (Page = Pnum) then begin
          {Correct handle and page mapped into this window}
          LastUsed := LruCount;
          MapWindow := W;
          Exit;
        end else if LastUsed < MinLRU then begin
          {Get the least recently used page}
          MinLRU := LastUsed;
          Win := W;
        end;

    {Desired mapping was not found}
    with EmsInfo[Win] do begin
      W := Win shl 1;
      {Map two pages}
      if (MapEmsPage(Handle, Pnum, W) and
        MapEmsPage(Handle, Succ(Pnum), Succ(W))) then begin
        Hand := Handle;
        Page := Pnum;
        LastUsed := LruCount;
        MapWindow := Win;
      end else
        Error(13);
    end;
  end;

  procedure RetA(A : TpArray; R, C : Word; var Value);
    {-Return the value of A[r,c]}
  var
    AP : TpArrayInternal absolute A;
  begin
    with AP^, Header do begin
      {Range check if requested}
      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;

      {Compute page number and offset}
      ArrayAddress(Header, R, C);

      {Return the data from the mapped window}
      Move(EmsWindow[MapWindow(Handle, Pnum)]^[Pofs], Value, ElSize);
      inline($FC);
    end;
  end;

  procedure SetA(A : TpArray; R, C : Word; var Value);
    {-Set the array element A[r,c] to value}
  var
    AP : TpArrayInternal absolute A;
  begin
    with AP^, Header do begin
      {Range check if requested}
      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;

      {Compute page number and offset}
      ArrayAddress(Header, R, C);

      {Save the data to the mapped window}
      Move(Value, EmsWindow[MapWindow(Handle, Pnum)]^[Pofs], ElSize);
      inline($FC);
    end;
  end;

  procedure UnknownWindow(W : Word);
    {-Indicate that we don't know what information is in window W}
  begin
    with EmsInfo[W] do begin
      Hand := $FFFF;
      Page := $FFFF;
      LastUsed := 0;
    end;
  end;

  procedure ClearA(A : TpArray; var Value; Initialize : InitType);
    {-Reset all array values to Value}
  var
    AP : TpArrayInternal absolute A;
    B : Byte absolute Value;
    R : Word;
    C : Word;
    P : Word;
    Save : Boolean;
  begin
    with AP^, Header do
      case Initialize of
        FastInit :
          begin
            {The first page window will be wiped out}
            UnknownWindow(0);

            for P := 0 to PageCount-2 do begin
              if not MapEmsPage(Handle, P, 0) then begin
                Error(13);
                Exit;
              end;
              FillChar(EmsWindow[0]^, EmsPageSize, B);
            end;
          end;

        ExactInit :
          begin
            Save := RangeCheck;
            RangeCheck := False;
            for R := 0 to Pred(Rows) do
              for C := 0 to Pred(Cols) do begin
                SetA(A, R, C, Value);
                if ArrayErrorLast <> 0 then
                  Exit;
              end;
            RangeCheck := Save;
          end;
      end;
  end;

  procedure MakeA(var A : TpArray;
                  Rows : Word;
                  Cols : Word;
                  ElementSize : Word);
    {-Determine page structure and allocate array}
  var
    AP : TpArrayInternal absolute A;
    H : ArrayHeader;
  begin
    {Assure EMS is available}
    if not EmsAvailable then begin
      Error(14);
      Exit;
    end;

    {Assure at least one element on each axis}
    if (Rows = 0) or (Cols = 0) then begin
      Error(4);
      Exit;
    end;

    {Assure element size is valid}
    if ElementSize = 0 then begin
      Error(3);
      Exit;
    end;
    if ElementSize > EmsPageSize then begin
      Error(3);
      Exit;
    end;

    H.Rows := Rows;
    H.Cols := Cols;
    H.ElSize := ElementSize;
    H.ID := IdString;

    {Compute page count, adding one for overflow mapping}
    H.PageCount := Succ(DivUp(LongInt(Rows)*Cols*ElementSize, EmsPageSize));

    if H.PageCount > EmsPagesAvail then begin
      Error(15);
      Exit;
    end;

    {Allocate array control block in main memory}
    if not GetMemCheck(AP, SizeOf(TpArrayRec)) then begin
      Error(7);
      Exit;
    end;

    with AP^ do begin
      {Initialize header}
      Header := H;
      {Allocate data pages}
      Handle := AllocateEmsPages(H.PageCount);
      if Handle = $FFFF then
        Error(15);
    end;
  end;

  procedure DisposeA(var A : TpArray);
    {-Deallocate an array}
  var
    AP : TpArrayInternal absolute A;
    W : Word; {!!.10}
  begin
    with AP^ do begin
      {Mark windows that own this array as unknown} {!!.10}
      for W := 0 to EmsWinMax do                    {!!.10}
        if EmsInfo[W].Hand = Handle then            {!!.10}
          UnknownWindow(W);                         {!!.10}

      {Deallocate data pages}
      if not DeallocateEmsHandle(Handle) then begin
        Error(16);
        Exit;
      end;
      {Deallocate the array}
      FreeMemCheck(AP, SizeOf(TpArrayRec));
    end;
  end;

  procedure StoreA(A : TpArray; FileName : string);
    {-Write array to disk}
  var
    AP : TpArrayInternal absolute A;
    F : file;
    Bytes : Word;
    P : Word;
  begin
    {Open the output file}
    Assign(F, FileName);
    Rewrite(F, 1);
    if IoResult <> 0 then begin
      Error(8);
      Exit;
    end;

    {Write the header}
    BlockWrite(F, AP^.Header, SizeOf(ArrayHeader), Bytes);
    if (IoResult <> 0) or (Bytes <> SizeOf(ArrayHeader)) then begin
      Close(F);
      P := IoResult;
      Error(9);
      Exit;
    end;

    {The first page window will be wiped out}
    UnknownWindow(0);

    with AP^, Header do
      {Write data pages, skipping last page which is a dummy}
      for P := 0 to PageCount-2 do begin
        if not MapEmsPage(Handle, P, 0) then begin
          Error(13);
          Exit;
        end;
        BlockWrite(F, EmsWindow[0]^, EmsPageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> EmsPageSize) then begin
          Close(F);
          P := IoResult;
          Error(9);
          Exit;
        end;
      end;

    Close(F);
    if IoResult <> 0 then
      Error(10);
  end;

  procedure LoadA(var A : TpArray; FileName : string);
    {-Read array from disk}
  var
    AP : TpArrayInternal absolute A;
    F : file;
    H : ArrayHeader;
    Bytes : Word;
    P : Word;
  begin
    {Open the input file}
    Assign(F, FileName);
    Reset(F, 1);
    if IoResult <> 0 then begin
      Error(11);
      Exit;
    end;

    {Read the header}
    BlockRead(F, H, SizeOf(ArrayHeader), Bytes);
    if (IoResult <> 0) or (Bytes <> SizeOf(ArrayHeader)) then begin
      Close(F);
      P := IoResult;
      Error(12);
      Exit;
    end;

    {Check for proper file format}
    if H.ID <> IdString then begin
      Close(F);
      P := IoResult;
      Error(17);
      Exit;
    end;

    {Allocate array}
    with H do
      MakeA(A, Rows, Cols, ElSize);
    if ArrayErrorLast <> 0 then begin
      Close(F);
      P := IoResult;
      Exit;
    end;

    with AP^, Header do begin

      {The first page window will be wiped out}
      UnknownWindow(0);

      {Read data pages}
      for P := 0 to PageCount-2 do begin
        if not MapEmsPage(Handle, P, 0) then begin
          Error(13);
          Exit;
        end;
        BlockRead(F, EmsWindow[0]^, EmsPageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> EmsPageSize) then begin
          Close(F);
          P := IoResult;
          Error(9);
          Exit;
        end;
      end;
    end;

    Close(F);
    if IoResult <> 0 then
      Error(10);
  end;

  procedure InitEms;
    {-Initialize info about the EMS system}
  var
    W : Word;
  begin
    {Initialize quasi-clock}
    LruCount := 0;

    {Initialize pointers to the page windows}
    EmsWindow[0] := EmsPageFramePtr;
    for W := 1 to EmsWinMax do
      EmsWindow[W] := Ptr(Seg(EmsWindow[Pred(W)]^)+EmsPageSize shr 3, 0);

    {Indicate that we don't know what's in any window}
    for W := 0 to EmsWinMax do
      UnknownWindow(W);
  end;

begin
  ArrayErrorLast := 0;
  EmsAvailable := EmsInstalled;
  if EmsAvailable then
    InitEms;
end.
