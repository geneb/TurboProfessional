{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{*********************************************************}
{*                  TPVARRAY.PAS 5.22                    *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpVarray;
  {-Dynamically allocated arrays with virtual memory support}

interface

uses
  Dos,
  TpMemChk;

type
  TpArray = Pointer;         {Generic type of TpArray}
  InitType =                 {Initialization options for new arrays}
  (ExactInit, FastInit);

const
  {Settings for error handling}
  WriteError : Boolean = True; {Display an error message}
  HaltOnError : Boolean = True; {Halt when any error encountered}
  RangeCheck : Boolean = False; {Check array indices - up to 40% performance penalty}
  KeepDiskCurrent : Boolean = False; {If true, force disk update after every operation}

function ErrorA : Word;
  {-Return the last error number and reset the error variable}

procedure RetA(A : TpArray; R, C : Word; var Value);
  {-Return value of A[r,c]}

procedure SetA(A : TpArray; R, C : Word; var Value);
  {-Set array element A[r,c] to value}

procedure ClearA(A : TpArray; var Value; Initialize : InitType);
  {-Initialize all array values to Value}

procedure MakeAPrimitive(var A : TpArray;
                         RowsInPage : Word;
                         ColsInPage : Word;
                         PagesDown : Word;
                         PagesAcross : Word;
                         ElementSize : Word;
                         FileName : string;
                         RamBytesForData : LongInt);
  {-Allocate array memory, with full control over page structure}

procedure MakeA(var A : TpArray;
                Rows : Word;
                Cols : Word;
                ElementSize : Word;
                FileName : string;
                RamBytesForData : LongInt);
  {-Allocate array the easy way}

procedure FlushA(A : TpArray);
  {-Update the disk image of the array}

procedure StoreA(A : TpArray);
  {-Write array to disk and close file}

procedure DisposeA(var A : TpArray; DeleteFile : Boolean);
  {-Deallocate array in memory, and delete array file if requested}

procedure LoadA(var A : TpArray; FileName : string; RamBytesForData : LongInt);
  {-Allocate and read array from disk}

  {==========================================================================}

implementation

const
  MaxHeapBlock = 65519;      {Largest single block on heap, less one}
  NotInRAM = $FFFF;          {Flag that a page is not currently in RAM}
  RPPOfs = 0;                {Offsets within header record of each field}
  CPPOfs = 2;                {  used within inline macro below}
  PDOfs = 4;
  PAOfs = 6;
  ESOfs = 8;
  IdString : string[6] = 'VARRAY'; {Written at the start of array files}

type

  {Data structures for management of large arrays}

  {Header for description of an array}
  {DO NOT CHANGE WITHOUT UPDATING RECORD OFFSETS ABOVE}
  ArrayHeader =
    record
      RowsInPage : Word;
      ColsInPage : Word;
      PagesDown : Word;
      PagesAcross : Word;
      ElSize : Word;         {Bytes in one array element}
      PageSize : Word;       {Bytes of data in one page}
      PageCount : Word;      {Number of pages in entire array}
      NextAvail : LongInt;   {Next file position for new page}
      ID : string[6];        {Identifies array files}
    end;

  {Data storage}
  DataPage = array[0..MaxHeapBlock] of Byte;

  {Descriptor of a page kept in RAM}
  PageRec =
    record
      PageNum : Word;        {Index into disk pointer table}
      LRU : Word;            {Quasi-time when page last used}
      Used : Boolean;        {True when page is loaded with data}
      Dirty : Boolean;       {True when RAM page differs from disk page}
      Data : DataPage;       {Actual data for page}
    end;
  PageRecPtr = ^PageRec;

  RamPageType = 0..16000;
  DiskPageType = 0..16000;

  {Pointers to pages in RAM}
  RamPageIndex = array[RamPageType] of PageRecPtr;

  {Map between disk page and RAM page, holds NotInRAM if not in RAM}
  RamPageMap = array[DiskPageType] of Word;

  {Offset within disk file of each page}
  DiskPageMap = array[DiskPageType] of LongInt;

  TpArrayRec =
    record
      RamPages : ^RamPageIndex; {Points to pages of data in RAM}
      RamIndex : ^RamPageMap; {Index of pages currently in RAM}
      DiskIndex : ^DiskPageMap; {Index of pages on disk}
      PagesInRam : Word;     {Number of pages in RAM}
      Header : ArrayHeader;  {Descriptor of array configuration}
      F : file;              {File variable}
      Opened : Boolean;      {True when file open}
      LRUcount : Word;       {Current quasi-time}
    end;
  TpArrayInternal = ^TpArrayRec;

var
  ArrayErrorLast : Word;     {Holds the last error number encountered}
  Pnum : Word;               {Global results of address calculations}
  Pofs : Word;

  procedure Flush(var F : file);
    {-Flush DOS file buffers}
  var
    handle : Word absolute F;
    regs : registers;
  begin
    with regs do begin
      ah := $45;
      bx := handle;
      msdos(regs);
      if Odd(flags) then
        Exit;
      bx := ax;
      ah := $3E;
      msdos(regs);
    end;
  end;

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
        5 : WriteLn('Invalid page size');
        6 : WriteLn('Invalid page index size');
        7 : WriteLn('Insufficient memory to allocate array');
        8 : WriteLn('File creation error');
        9 : WriteLn('File write error');
        10 : WriteLn('Error while closing file');
        11 : WriteLn('File not found');
        12 : WriteLn('File read error');
        13 : WriteLn('Number of in-RAM pages less than 1');
        17 : WriteLn('Invalid file format');
      end;
    if HaltOnError then
      Halt(1);
  end;

  procedure DisposePrimitive(var A : TpArray; Level, Pages : Word);
    {-Deallocate RAM space for selected components of array}
  var
    AP : TpArrayInternal absolute A;
    P : Word;
  begin
    with AP^, Header do begin
      if (Level >= 5) and (Pages > 0) then {!!.10}
        for P := 0 to Pred(Pages) do
          FreeMemCheck(RamPages^[P], PageSize+(SizeOf(PageRec)-SizeOf(DataPage)));
      if Level >= 4 then
        FreeMemCheck(RamPages, SizeOf(Pointer)*PagesInRam);
      if Level >= 3 then
        FreeMemCheck(DiskIndex, SizeOf(LongInt)*PageCount);
      if Level >= 2 then
        FreeMemCheck(RamIndex, SizeOf(Word)*PageCount);
      if Level >= 1 then
        FreeMemCheck(A, SizeOf(TpArrayRec));
    end;
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
      if R >= RowsInPage*PagesDown then begin
        Error(1);
        Exit;
      end;
      if C >= ColsInPage*PagesAcross then begin
        Error(2);
        Exit;
      end;
    end;
    RangeError := False;
  end;

  function WriteIndex(A : TpArray) : Boolean;
    {-Write the current header and page index to disk}
  var
    AP : TpArrayInternal absolute A;
    Bytes : Word;
    DiskIndexSize : Word;
  begin
    WriteIndex := False;
    with AP^ do begin
      if not Opened then
        Exit;
      Reset(F, 1);
      BlockWrite(F, Header, SizeOf(ArrayHeader), Bytes);
      if (IoResult <> 0) or (Bytes <> SizeOf(ArrayHeader)) then begin
        Error(9);
        Exit;
      end;
      DiskIndexSize := SizeOf(LongInt)*Header.PageCount;
      BlockWrite(F, DiskIndex^, DiskIndexSize, Bytes);
      if (IoResult <> 0) or (Bytes <> DiskIndexSize) then begin
        Error(9);
        Exit;
      end;
    end;
    WriteIndex := True;
  end;

  procedure InitRamIndex(A : TpArray);
    {-Initialize the RAM page index}
  var
    AP : TpArrayInternal absolute A;
    P : Word;
  begin
    with AP^, Header do begin
      {Mark all pages as not in RAM}
      FillChar(RamIndex^, SizeOf(Word)*PageCount, $FF);

      {Initialize each in-RAM page descriptor}
      for P := 0 to Pred(PagesInRam) do
        with RamPages^[P]^ do begin
          PageNum := 0;
          LRU := 0;
          Used := False;
          Dirty := False;
        end;
    end;
  end;

  function WritePage(A : TpArray; PIR, Pnum : Word) : Boolean;
    {-Write from RAM page PIR to disk page Pnum}
  var
    AP : TpArrayInternal absolute A;
    Bytes : Word;
  begin
    WritePage := False;
    with AP^, Header do begin

      {Allocate disk space for page if needed}
      if DiskIndex^[Pnum] = 00 then begin
        DiskIndex^[Pnum] := NextAvail;
        Inc(NextAvail, PageSize);
        {Update file image of index immediately if desired}
        if KeepDiskCurrent then
          if not WriteIndex(A) then
            Exit;
      end;

      {Seek and write}
      Seek(F, DiskIndex^[Pnum]);
      BlockWrite(F, RamPages^[PIR]^.Data, PageSize, Bytes);
      if (IoResult <> 0) or (Bytes <> PageSize) then begin
        Error(9);
        Exit;
      end;

      {Page is no longer dirty}
      RamPages^[PIR]^.Dirty := False;

      {Flush DOS file buffers if requested}
      if KeepDiskCurrent then
        Flush(F);
    end;
    WritePage := True;
  end;

  function GetPage(A : TpArray; Pnum : Word) : Word;
    {-Read disk page into RAM and return page number there}
  var
    AP : TpArrayInternal absolute A;
    P : Word;
    PIR : Word;
    MinLRU : Word;
    Bytes : Word;
    PageUsed : Boolean;
  begin
    with AP^, Header do begin

      {Find the next unused or oldest page in RAM}
      MinLRU := $FFFF;
      P := 0;
      PIR := 0;
      PageUsed := True;

      while P < PagesInRam do begin
        with RamPages^[P]^ do
          if not(Used) then begin
            PIR := P;
            PageUsed := False;
            {Force exit from loop}
            P := PagesInRam;
          end else if LRU < MinLRU then begin
            PIR := P;
            MinLRU := LRU;
          end;
        Inc(P);
      end;

      with RamPages^[PIR]^ do begin

        if PageUsed then begin
          {A previous page was in this location}
          if Dirty then begin
            if not WritePage(A, PIR, PageNum) then
              Exit;
          end;
          {Indicate that the page is no longer in RAM}
          RamIndex^[PageNum] := NotInRAM;
        end;

        {Read in the new page}
        if DiskIndex^[Pnum] <> 00 then begin
          {There is already data stored on disk}
          Seek(F, DiskIndex^[Pnum]);
          BlockRead(F, Data, PageSize, Bytes);
          if (IoResult <> 0) or (Bytes <> PageSize) then begin
            Error(12);
            Exit;
          end;
        end;

        {Indicate that the new page is in RAM}
        RamIndex^[Pnum] := PIR;

        {Update page flags}
        Used := True;
        Dirty := False;
        PageNum := Pnum;

      end;                   {With RamPages^[PIR]^}
    end;                     {With AP^, Header}

    {Return the page number where the data was loaded}
    GetPage := PIR;
  end;

  procedure ArrayAddress(H : ArrayHeader; R, C : Word);
    {-Return the page parameters for a given row and column}
  inline
  ($5B/                      {pop bx                    ;save column in bx}
    $58/                     {pop ax                    ;save row in ax}
    $5F/                     {pop di                    ;offset of array header}
    $07/                     {pop es                    ;segment of array header}
    $31/$D2/                 {xor dx,dx                 ;prepare to divide}
    $26/                     {es:}
    $F7/$75/<RPPOfs/         {div word ptr [di+<RPPOfs] ;divide by RowsInPage (POR in DX, PR in AX)}
    $89/$D1/                 {mov cx,dx                 ;save POR in cx}
    $89/$C6/                 {mov si,ax                 ;save PR in si}
    $89/$D8/                 {mov ax,bx                 ;col into ax}
    $31/$D2/                 {xor dx,dx                 ;prepare to divide}
    $26/                     {es:}
    $F7/$75/<CPPOfs/         {div word ptr [di+<CPPOfs] ;divide by ColsInPage (POC in DX, PC in AX)}
    $89/$C3/                 {mov bx,ax                 ;save PC in BX}
    $26/                     {es:}
    $8B/$45/<PDOfs/          {mov ax,[di+<PDOfs]        ;get PagesDown in AX}
    $52/                     {push dx                   ;save POC a moment}
    $F7/$E3/                 {mul bx                    ;PagesDown*PC}
    $01/$F0/                 {add ax,si                 ;Pnum = PR+PagesDown*PC}
    $A3/>Pnum/               {mov [>Pnum],ax            ;Store Pnum}
    $58/                     {pop ax                    ;get POC back}
    $26/                     {es:}
    $F7/$65/<RPPOfs/         {mul word ptr [di+<RPPOfs] ;RowsPerPage*POC}
    $01/$C8/                 {add ax,cx                 ;POR+RowsPerPage*POC}
    $26/                     {es:}
    $F7/$65/<ESOfs/          {mul word ptr [di+<ESOfs]  ;ElSize*(POR+RowsPerPage*POC)}
    $A3/>Pofs);              {mov [>Pofs],ax            ;Store Pofs}

  function ChangesWereWritten(A : TpArray) : Boolean;
    {-Write any changed pages and return true if any were written}
  var
    AP : TpArrayInternal absolute A;
    PIR : Word;
  begin
    ChangesWereWritten := False;
    with AP^ do
      for PIR := 0 to Pred(PagesInRam) do
        with RamPages^[PIR]^ do
          if Dirty then begin
            if not WritePage(A, PIR, PageNum) then
              Exit;
            ChangesWereWritten := True;
          end;
  end;

  procedure FlushA(A : TpArray);
    {-Update the disk image of the array}
  var
    AP : TpArrayInternal absolute A;
    Changed : Boolean;
  begin
    with AP^ do begin
      if not Opened then
        Exit;
      {Write any changed pages}
      Changed := ChangesWereWritten(A);
      {if not(KeepDiskCurrent) then} {!!.11}
        {Update the index if WritePage didn't already do so}
        if not WriteIndex(A) then
          Exit;
      if Changed or not(KeepDiskCurrent) then
        {Assure DOS buffers are flushed}
        Flush(F);
    end;
  end;

  procedure ResetLRU(A : TpArray);
    {-Reset the LRU values for all pages in RAM}
  var
    AP : TpArrayInternal absolute A;
    P : Word;
  begin
    with AP^ do
      for P := 0 to Pred(PagesInRam) do
        RamPages^[P]^.LRU := 0;
  end;

  procedure RetA(A : TpArray; R, C : Word; var Value);
    {-Return the value of A[R,C]}
  var
    AP : TpArrayInternal absolute A;
    PIR : Word;
    P : Word;
  begin
    with AP^, Header do begin

      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;

      {Compute page number and offset into page - returned in globals}
      ArrayAddress(Header, R, C);

      {Is page in RAM? If not, put it there now}
      PIR := RamIndex^[Pnum];
      if PIR = NotInRAM then
        PIR := GetPage(A, Pnum);

      {Update quasi-time}
      Inc(LRUcount);
      if LRUcount = 0 then
        ResetLRU(A);

      {Update LRU for this page, and pass back data value}
      with RamPages^[PIR]^ do begin
        LRU := LRUcount;
        Move(Data[Pofs], Value, ElSize);
        inline($FC);
      end;
    end;
  end;

  procedure SetA(A : TpArray; R, C : Word; var Value);
    {-Set array element A[R,C] to value}
  var
    AP : TpArrayInternal absolute A;
    PIR : Word;
    P : Word;
  begin
    with AP^, Header do begin

      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;

      {Compute page number and offset into page - returned in globals}
      ArrayAddress(Header, R, C);

      {Is page in RAM? If not, put it there now}
      PIR := RamIndex^[Pnum];
      if PIR = NotInRAM then
        PIR := GetPage(A, Pnum);

      {Update quasi-time}
      Inc(LRUcount);
      if LRUcount = 0 then
        ResetLRU(A);

      {Update LRU for this page, and pass back data value}
      with RamPages^[PIR]^ do begin
        Dirty := True;
        LRU := LRUcount;
        Move(Value, Data[Pofs], ElSize);
        inline($FC);
      end;
    end;
  end;

  procedure ClearA(A : TpArray;
                   var Value;
                   Initialize : InitType);
    {-Reset all array values to Value}
  var
    AP : TpArrayInternal absolute A;
    B : Byte absolute Value;
    R : Word;
    C : Word;
    P : Word;
    Save : Boolean;
  begin
    {Don't waste time on updating disk index until done}
    Save := KeepDiskCurrent;
    KeepDiskCurrent := False;
    with AP^, Header do
      if Initialize = FastInit then begin
        {Initialize in blocks by page}
        FillChar(RamPages^[0]^.Data, PageSize, B);
        {Write all the pages to disk}
        for P := 0 to Header.PageCount-1 do
          if not WritePage(A, 0, P) then
            Exit;
        {Mark in-RAM pages as available}
        InitRamIndex(A);
      end else
        {Initialize one element at a time}
        for R := 0 to Pred(RowsInPage*PagesDown) do
          for C := 0 to Pred(ColsInPage*PagesAcross) do
            SetA(A, R, C, Value);
    {Update index and buffers if requested}
    KeepDiskCurrent := Save;
    FlushA(A);
  end;

  function AllocateA(var A : TpArray;
                     RowsInPage : Word;
                     ColsInPage : Word;
                     PagesDown : Word;
                     PagesAcross : Word;
                     ElementSize : Word;
                     RamBytesForData : LongInt) : Boolean;
    {-Validate and allocate heap space for array}
  var
    AP : TpArrayInternal absolute A;
    RamIndexSize : LongInt;
    DiskIndexSize : LongInt;
    PageCount : LongInt;
    PageSize : LongInt;
    PagesInRamL : LongInt;
    PageOverHead : LongInt;
    P : Word;
    {$IFDEF debug}
    HeapUsage : LongInt;
    {$ENDIF}

  begin
    AllocateA := False;

    {Assure element size is valid}
    if ElementSize = 0 then begin
      Error(3);
      Exit;
    end;

    {Assure row and column dimensions are valid}
    if (PagesDown or RowsInPage = 0) or (PagesAcross or ColsInPage = 0) then begin
      Error(4);
      Exit;
    end;
    if LongInt(PagesDown)*RowsInPage > 65535 then begin
      Error(4);
      Exit;
    end;
    if LongInt(PagesAcross)*ColsInPage > 65535 then begin
      Error(4);
      Exit;
    end;

    {Assure page size is valid}
    PageOverHead := SizeOf(PageRec)-SizeOf(DataPage);
    PageSize := LongInt(RowsInPage)*ColsInPage*ElementSize;
    if PageSize+PageOverHead > MaxHeapBlock then begin
      Error(5);
      Exit;
    end;

    {Assure page index sizes are valid}
    PageCount := PagesDown*PagesAcross;
    RamIndexSize := SizeOf(Word)*PageCount;
    DiskIndexSize := SizeOf(LongInt)*PageCount;
    if DiskIndexSize > MaxHeapBlock then begin
      Error(6);
      Exit;
    end;

    {Compute number of pages to be kept in RAM}
    PagesInRamL := RamBytesForData div (SizeOf(Pointer)+PageSize+PageOverHead);
    {Don't allocate more pages in RAM than the whole array needs}
    if PagesInRamL > PageCount then
      PagesInRamL := PageCount;
    if PagesInRamL < 1 then begin
      Error(13);
      Exit;
    end;

    {Allocate the base array pointer}
    if not GetMemCheck(AP, SizeOf(TpArrayRec)) then begin
      Error(7);
      Exit;
    end;

    with AP^ do begin

      {Initialize simple fields}
      PagesInRam := PagesInRamL;
      LRUcount := 0;

      {Initialize header}
      Header.RowsInPage := RowsInPage;
      Header.ColsInPage := ColsInPage;
      Header.PagesDown := PagesDown;
      Header.PagesAcross := PagesAcross;
      Header.ElSize := ElementSize;
      Header.PageSize := PageSize;
      Header.PageCount := PageCount;
      Header.ID := IdString;

      {$IFDEF debug}
      WriteLn('RowsInPage=', RowsInPage);
      WriteLn('ColsInPage=', ColsInPage);
      WriteLn('PagesDown=', PagesDown);
      WriteLn('PagesAcross=', PagesAcross);
      WriteLn('PageSize=', PageSize);
      WriteLn('PageCount=', PageCount);
      WriteLn('PagesInRam=', PagesInRam);
      HeapUsage :=
      LongInt(SizeOf(TpArrayRec))+RamIndexSize+DiskIndexSize+
      PagesInRam*(SizeOf(Pointer)+PageSize+PageOverHead);
      WriteLn('RAM efficiency=', (LongInt(100)*PagesInRam*PageSize) div HeapUsage, '%');
      {$ENDIF}

      {Allocate ram index}
      if not GetMemCheck(RamIndex, RamIndexSize) then begin
        DisposePrimitive(A, 1, 0);
        Error(7);
        Exit;
      end;

      {Allocate disk index}
      if not GetMemCheck(DiskIndex, DiskIndexSize) then begin
        DisposePrimitive(A, 2, 0);
        Error(7);
        Exit;
      end;

      {Allocate in-RAM data pointers}
      if not GetMemCheck(RamPages, SizeOf(Pointer)*PagesInRam) then begin
        DisposePrimitive(A, 3, 0);
        Error(7);
        Exit;
      end;

      {Allocate in-RAM data pages}
      for P := 0 to Pred(PagesInRam) do
        if not GetMemCheck(RamPages^[P], PageSize+PageOverHead) then begin
          DisposePrimitive(A, 5, P);
          Error(7);
          Exit;
        end;

    end;
    AllocateA := True;
  end;

  procedure MakeAPrimitive(var A : TpArray;
                           RowsInPage : Word;
                           ColsInPage : Word;
                           PagesDown : Word;
                           PagesAcross : Word;
                           ElementSize : Word;
                           FileName : string;
                           RamBytesForData : LongInt);
    {-Allocate array memory}
  var
    AP : TpArrayInternal absolute A;
  begin
    {Validate and allocate heap space for array}
    if not AllocateA(A, RowsInPage, ColsInPage, PagesDown, PagesAcross, ElementSize, RamBytesForData) then
      Exit;

    with AP^ do begin
      Opened := False;

      {Create the disk file}
      Assign(F, FileName);
      Rewrite(F, 1);
      if IoResult <> 0 then begin
        DisposePrimitive(A, 5, PagesInRam);
        Error(8);
        Exit;
      end;
      Opened := True;

      {Initialize the disk index}
      with Header do begin
        NextAvail := LongInt(SizeOf(ArrayHeader))+SizeOf(LongInt)*PageCount;
        FillChar(DiskIndex^, SizeOf(LongInt)*PageCount, 0);
      end;

      {Write header and index to disk}
      if not WriteIndex(A) then
        Exit;

      {Initialize the in-RAM index and page descriptors}
      InitRamIndex(A);
    end;
  end;

  procedure MakeA(var A : TpArray;
                  Rows : Word;
                  Cols : Word;
                  ElementSize : Word;
                  FileName : string;
                  RamBytesForData : LongInt);
    {-Determine page structure and allocate array}
  var
    H : ArrayHeader;
    TotalBytes : LongInt;
    Pages : Word;
    PageOverHead : Word;
    Done : Boolean;
    MaxPageSize : Word;
  begin
    {Be sure at least one element on each axis}
    if (Rows = 0) or (Cols = 0) then begin
      Error(4);
      Exit;
    end;

    {Be sure element size is valid}
    if ElementSize = 0 then begin
      Error(3);
      Exit;
    end;

    {Compute total bytes in array}
    TotalBytes := LongInt(Rows)*Cols*ElementSize;
    PageOverHead := SizeOf(PageRec)-SizeOf(DataPage);

    {Assure MemAvail is at least as big as RamBytesForData}
    if RamBytesForData > (9*MemAvail) div 10 then
      RamBytesForData := (9*MemAvail) div 10;

    {Determine largest page size we'll accept}
    MaxPageSize := MaxHeapBlock;
    if MaxPageSize > RamBytesForData shr 1 then
      MaxPageSize := RamBytesForData shr 1;

    if (((LongInt(Rows)*ElementSize)+PageOverhead) > MaxPageSize) and  {!!.10}
       (((LongInt(Cols)*ElementSize)+PageOverhead) > MaxPageSize) then {!!.10}
    begin                                                              {!!.10}
      Error(13);                                                {!!.09}
      Exit;                                                     {!!.09}
    end;                                                        {!!.09}

    with H do begin
      {Store element size}
      ElSize := ElementSize;

      {Determine page organization}
      if TotalBytes+PageOverHead <= MaxPageSize then begin
        {Whole array fits into one page}
        RowsInPage := Rows;
        ColsInPage := Cols;
        PagesDown := 1;
        PagesAcross := 1;

      end else begin
        {Array larger than a page}
        {Get first estimate of number of pages required}
        Pages := DivUp(TotalBytes, MaxPageSize);

        {Iterate to find page organization with minimum waste that fits}
        repeat
          RowsInPage := DivUp(Rows, Pages);
          ColsInPage := DivUp(Cols, Pages);

          {Determine whether to divide horizontally or vertically}
          if ((LongInt(RowsInPage)*Pages-Rows)*Cols <=
            (LongInt(ColsInPage)*Pages-Cols)*Rows)
          or (LongInt(RowsInPage)*ElSize > MaxPageSize) then begin
            {Divide up the rows}
            ColsInPage := Cols;
            PagesAcross := 1;
            PagesDown := Pages;
          end else begin
            {Divide up the columns}
            RowsInPage := Rows;
            PagesDown := 1;
            PagesAcross := Pages;
          end;

          Done := (LongInt(RowsInPage)*ColsInPage*ElSize+PageOverHead <= MaxPageSize);
          if not(Done) then
            {Add another page}
            Inc(Pages);
          if Pages = 0 then begin                                     {!!.11}
            Error(13);                                                {!!.11}
            Exit;                                                     {!!.11}
          end;                                                        {!!.11}
        until Done;
      end;

      {$IFDEF debug}
      WriteLn('Total bytes=', TotalBytes);
      WriteLn('Page efficiency=',
      (LongInt(100)*TotalBytes) div (LongInt(Pages)*RowsInPage*ColsInPage*ElSize), '%');
      {$ENDIF}

      {Allocate the array}
      MakeAPrimitive(A, RowsInPage, ColsInPage, PagesDown, PagesAcross,
        ElSize, FileName, RamBytesForData);

    end;
  end;

  procedure StoreA(A : TpArray);
    {-Write array to disk}
  var
    AP : TpArrayInternal absolute A;
  begin
    with AP^ do begin
      if not Opened then
        Exit;
      {Assure disk is fully updated}
      FlushA(A);
      if ArrayErrorLast <> 0 then
        Exit;
      {Close up}
      Close(F);
      Opened := False;
      if IoResult <> 0 then
        Error(10);
    end;
  end;

  {.$DEFINE OLDSTYLE}
  procedure DisposeA(var A : TpArray; DeleteFile : Boolean);
    {-Deallocate an array}
  var
    AP : TpArrayInternal absolute A;
  begin
    {$IFDEF OLDSTYLE}
    with AP^ do begin
     if Opened then begin
      {Store the array in case it is wanted later}
      StoreA(A);
      if DeleteFile then
       if ArrayErrorLast = 0 then
        {File was closed in StoreA, safe to erase here}
        Erase(F);
     end;
     {Deallocate its space}
     DisposePrimitive(A, 5, PagesInRam);
    end;
  {$ELSE}
    with AP^ do begin
(*
      if Opened then begin
        if DeleteFile then begin
          Close(F);
          if IoResult = 0 then
            {File was closed in StoreA, safe to erase here}
            Erase(F)
          else
            Error(10);
        end
        else
          {Store the array in case it is wanted later}
          StoreA(A);
      end;
*)
      {!!.12} {Reorganized to delete file even if already closed}
      if Opened then begin
        if DeleteFile then begin
          Close(F);
          if IoResult <> 0 then
            Error(10);
        end else
          {Store the array in case it is wanted later}
          StoreA(A);
      end;
      if DeleteFile then begin
        Erase(F);
        if IoResult <> 0 then
          Error(10);
      end;

      {Deallocate its space}
      DisposePrimitive(A, 5, PagesInRam);
    end;
    {$ENDIF}
  end;

  procedure LoadA(var A : TpArray; FileName : string; RamBytesForData : LongInt);
    {-Allocate and read array from disk}
  var
    AP : TpArrayInternal absolute A;
    FT : file;
    H : ArrayHeader;
    Bytes : Word;
    DiskIndexSize : Word;
  begin
    {Open the input file}
    Assign(FT, FileName);
    Reset(FT, 1);
    if IoResult <> 0 then begin
      Error(11);
      Exit;
    end;

    {Read the header}
    BlockRead(FT, H, SizeOf(ArrayHeader), Bytes);
    if (IoResult <> 0) or (Bytes <> SizeOf(ArrayHeader)) then begin
      Close(FT);
      Bytes := IoResult;
      Error(12);
      Exit;
    end;
    Close(FT);

    {Make sure file is properly formatted}
    if H.ID <> IdString then begin
      Error(17);
      Exit;
    end;

    with H do
      {Allocate heap space}
      if not AllocateA(A, RowsInPage, ColsInPage, PagesDown, PagesAcross, ElSize, RamBytesForData) then
        Exit;

    with AP^ do begin

      Opened := False;

      {Reopen the disk file}
      Assign(F, FileName);
      Reset(F, 1);
      if IoResult <> 0 then begin
        Error(11);
        Exit;
      end;
      Opened := True;

      {Initialize the disk index}
      Header.NextAvail := H.NextAvail;
      DiskIndexSize := SizeOf(LongInt)*Header.PageCount;
      Seek(F, SizeOf(ArrayHeader));
      BlockRead(F, DiskIndex^, DiskIndexSize, Bytes);
      if (IoResult <> 0) or (Bytes <> DiskIndexSize) then begin
        Close(F);
        Bytes := IoResult;
        Error(12);
        Exit;
      end;

      {Initialize the in-RAM index}
      InitRamIndex(A);

    end;
  end;

begin
  ArrayErrorLast := 0;
end.
