{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-}

{$IFDEF Ver40}
  {$F-}
{$ELSE}
  {$F+,O+,A-}
{$ENDIF}

{*********************************************************}
{*                   TPRARRAY.PAS 5.22                   *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}


unit TpRarray;
  {-Dynamically allocated arrays larger than 64K in normal RAM}

interface

uses
  TpMemChk, TpInline;

type
  TpArray = Pointer;         {Generic type of TpArray}
  InitType =                 {Initialization options for new arrays}
  (ExactInit, FastInit);

const
  WriteError : Boolean = True; {Settings for Error handling}
  HaltOnError : Boolean = True;
  RangeCheck : Boolean = False;

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
                         ElementSize : Word);
  {-Allocate array memory, with full control over page structure}

procedure MakeA(var A : TpArray;
                Rows : Word;
                Cols : Word;
                ElementSize : Word);
  {-Allocate array the easy way}

procedure DisposeA(var A : TpArray);
  {-Deallocate array}

procedure StoreA(A : TpArray; FileName : string);
  {-Write array to disk}

procedure LoadA(var A : TpArray; FileName : string);
  {-Allocate and read array from disk}

procedure StoreVA(A : TpArray; FileName : string);
  {-Write array to disk in VARRAY format}

procedure LoadVA(var A : TpArray; FileName : string);
  {-Allocate and read array from disk in VARRAY format}

  {==========================================================================}

implementation

const
  MaxHeapBlock = 65519;      {Largest single block on heap, less one}
  RPPOfs = 0;                {Offsets within header record of each field}
  CPPOfs = 2;
  PDOfs = 4;
  PAOfs = 6;
  ESOfs = 8;
  PSOfs = 10;
  PCOfs = 12;
  IdString : string[6] = 'RARRAY'; {Written at the start of array files}

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
      ElSize : Word;
      PageSize : Word;
      PageCount : Word;
      ID : string[6];
    end;

  {Data storage}
  DataPage = array[0..MaxHeapBlock] of Byte;
  DataPagePtr = ^DataPage;
  PageIndex = array[0..16000] of DataPagePtr;
  TpArrayRec =
    record
      Header : ArrayHeader;
      Pages : PageIndex;
    end;
  TpArrayInternal = ^TpArrayRec;

  {Array storage on disk is:
     a copy of the header
     the data for each page}
  ArrayFile = file;

var
  ArrayErrorLast : Word;     {Holds the last error number encountered}
  Pnum : Word;               {Global results of address calculations}
  Pofs : Word;

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

  procedure RetA(A : TpArray; R, C : Word; var Value);
    {-Return the value of A[r,c] as a VAR parameter}
  var
    AP : TpArrayInternal absolute A;
  begin
    with AP^, Header do begin
      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;
      ArrayAddress(Header, R, C);
      Move(Pages[Pnum]^[Pofs], Value, ElSize);
      inline($FC);
    end;
  end;

  procedure SetA(A : TpArray; R, C : Word; var Value);
    {-Set the array element A[r,c] to value}
  var
    AP : TpArrayInternal absolute A;
  begin
    with AP^, Header do begin
      if RangeCheck then
        if RangeError(Header, R, C) then
          Exit;
      ArrayAddress(Header, R, C);
      Move(Value, Pages[Pnum]^[Pofs], ElSize);
      inline($FC);
    end;
  end;

  procedure ClearA(A : TpArray;
                   var Value;
                   Initialize : InitType);
    {-Reset all array values to Value}
  var
    AP : TpArrayInternal absolute A;
    B : Byte absolute Value;
    Pofs : Word;
    R : Word;
    C : Word;
    P : Word;
  begin
    with AP^, Header do begin

      {Initialize the first page}
      case Initialize of
        FastInit :
          FillChar(Pages[0]^, PageSize, B);
        ExactInit :
          FillStruct(Pages[0]^, RowsInPage*ColsInPage, Value, ElSize);
      else
        Exit;
      end;

      {Initialize the rest of the pages}
      for P := 1 to Pred(PageCount) do
        Move(Pages[0]^, Pages[P]^, PageSize);
      inline($FC);
    end;
  end;

  procedure MakeAPrimitive(var A : TpArray;
                           RowsInPage : Word;
                           ColsInPage : Word;
                           PagesDown : Word;
                           PagesAcross : Word;
                           ElementSize : Word);
    {-Allocate array memory}
  var
    AP : TpArrayInternal absolute A;
    PageIndexSize : LongInt;
    PageCount : LongInt;
    PageSize : LongInt;
    P : Word;
    PU : Word;
  begin
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

    {Assure page size is valid}
    PageSize := LongInt(RowsInPage)*ColsInPage*ElementSize;
    if PageSize > MaxHeapBlock then begin
      Error(5);
      Exit;
    end;

    {Assure page index size is valid}
    PageCount := PagesDown*PagesAcross;
    PageIndexSize := SizeOf(Pointer)*PageCount;
    if PageIndexSize > MaxHeapBlock-SizeOf(ArrayHeader) then begin
      Error(6);
      Exit;
    end;

    {Allocate page array}
    if not GetMemCheck(AP, SizeOf(ArrayHeader)+PageIndexSize) then begin
      Error(7);
      Exit;
    end;

    with AP^ do begin

      {Initialize header}
      Header.RowsInPage := RowsInPage;
      Header.ColsInPage := ColsInPage;
      Header.PagesDown := PagesDown;
      Header.PagesAcross := PagesAcross;
      Header.ElSize := ElementSize;
      Header.PageSize := PageSize;
      Header.PageCount := PageCount;
      Header.ID := IdString;

      {Allocate data pages}
      for P := 0 to Pred(PageCount) do
        if not GetMemCheck(Pages[P], PageSize) then begin
          {Deallocate what was already allocated} {!!.07}
          if P > 0 then
            for PU := P-1 downto 0 do
              FreeMemCheck(Pages[PU], PageSize);
          Error(7);
          Exit;
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
    TotalBytes : LongInt;
    Pages : Word;
    Done : Boolean;
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
    if TotalBytes > MemAvail then begin {!!.07}
      Error(7);
      Exit;
    end;

    with H do begin
      {Store element size}
      ElSize := ElementSize;

      {Determine page organization}
      if TotalBytes <= MaxHeapBlock then begin
        {Whole array fits into one 64K page}
        RowsInPage := Rows;
        ColsInPage := Cols;
        PagesDown := 1;
        PagesAcross := 1;

      end else begin
        {Array larger than a page}
        {First estimate of number of pages required}
        Pages := DivUp(TotalBytes, MaxHeapBlock);

        {Iterate to find page organization with minimum waste}
        repeat
          RowsInPage := DivUp(Rows, Pages);
          ColsInPage := DivUp(Cols, Pages);

          {Determine whether to divide horizontally or vertically}
          if ((LongInt(RowsInPage)*Pages-Rows)*Cols <
            (LongInt(ColsInPage)*Pages-Cols)*Rows) then begin
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

          Done := (LongInt(RowsInPage)*ColsInPage*ElSize <= MaxHeapBlock);
          if not(Done) then
            {Add another page}
            Inc(Pages);

        until Done;
      end;

      {Allocate the array}
      MakeAPrimitive(A, RowsInPage, ColsInPage, PagesDown, PagesAcross, ElSize);
    end;
  end;

  procedure DisposeA(var A : TpArray);
    {-Deallocate an array}
  var
    AP : TpArrayInternal absolute A;
    P : Word;
  begin
    with AP^, Header do begin
      {Deallocate data pages}
      for P := 0 to Pred(PageCount) do
        FreeMemCheck(Pages[P], PageSize);
      {Deallocate the page array}
      FreeMemCheck(AP, SizeOf(ArrayHeader)+PageCount*SizeOf(Pointer));
    end;
  end;

  procedure StoreA(A : TpArray; FileName : string);
    {-Write array to disk}
  var
    AP : TpArrayInternal absolute A;
    F : ArrayFile;
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

    with AP^, Header do
      {Write data pages}
      for P := 0 to Pred(PageCount) do begin
        BlockWrite(F, Pages[P]^, PageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> PageSize) then begin
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
    F : ArrayFile;
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
      MakeAPrimitive(A, RowsInPage, ColsInPage, PagesDown, PagesAcross, ElSize);
    if ArrayErrorLast <> 0 then
      Exit;

    with AP^, Header do begin
      {Initialize the header}
      Header := H;

      {Read data pages}
      for P := 0 to Pred(PageCount) do begin
        BlockRead(F, Pages[P]^, PageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> PageSize) then begin
          Close(F);
          P := IoResult;
          Error(12);
          Exit;
        end;
      end;
    end;

    Close(F);
    if IoResult <> 0 then
      Error(10);
  end;

  {------ Reading and Writing VARRAY format files -------}

  const
    VidString : string[6] = 'VARRAY'; {Written at start of VARRAY files}

  type
    VArrayHeader =
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

  procedure StoreVA(A : TpArray; FileName : string);
    {-Write array to disk in VARRAY format}
  var
    AP : TpArrayInternal absolute A;
    Bytes : Word;
    P : Word;
    N : LongInt;
    VHeader : VArrayHeader;
    F : file;
  begin
    {Open the output file}
    Assign(F, FileName);
    Rewrite(F, 1);
    if IoResult <> 0 then begin
      Error(8);
      Exit;
    end;

    with AP^, Header do begin

      {Initialize a VARRAY header}
      move(Header, VHeader, SizeOf(ArrayHeader));
      inline($FC);
      VHeader.NextAvail := (SizeOf(VArrayHeader)+
                            LongInt(PageCount)*(SizeOf(LongInt)+PageSize));
      VHeader.ID := VidString;

      {Write the header}
      BlockWrite(F, VHeader, SizeOf(VArrayHeader), Bytes);
      if (IoResult <> 0) or (Bytes <> SizeOf(VArrayHeader)) then begin
        Close(F);
        P := IoResult;
        Error(9);
        Exit;
      end;

      {Write the index}
      N := SizeOf(VArrayHeader)+LongInt(PageCount)*SizeOf(LongInt);
      for P := 0 to Pred(PageCount) do begin
        BlockWrite(F, N, SizeOf(LongInt), Bytes);
        if (IoResult <> 0) or (Bytes <> SizeOf(LongInt)) then begin
          Close(F);
          P := IoResult;
          Error(9);
          Exit;
        end;
        inc(N, PageSize);
      end;

      {Write data pages}
      for P := 0 to Pred(PageCount) do begin
        BlockWrite(F, Pages[P]^, PageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> PageSize) then begin
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

  procedure LoadVA(var A : TpArray; FileName : string);
    {-Allocate and read array from disk in VARRAY format}
  var
    AP : TpArrayInternal absolute A;
    Bytes : Word;
    P : Word;
    N : LongInt;
    H : VArrayHeader;
    F : ArrayFile;
  begin
    {Open the input file}
    Assign(F, FileName);
    Reset(F, 1);
    if IoResult <> 0 then begin
      Error(11);
      Exit;
    end;

    {Read the header}
    BlockRead(F, H, SizeOf(VArrayHeader), Bytes);
    if (IoResult <> 0) or (Bytes <> SizeOf(VArrayHeader)) then begin
      Close(F);
      P := IoResult;
      Error(12);
      Exit;
    end;

    {Check for proper file format}
    if H.ID <> VidString then begin
      Close(F);
      P := IoResult;
      Error(17);
      Exit;
    end;

    {Allocate array}
    with H do
      MakeAPrimitive(A, RowsInPage, ColsInPage, PagesDown, PagesAcross, ElSize);
    if ArrayErrorLast <> 0 then
      Exit;

    with AP^, Header do begin
      {Initialize the header}
      move(H, Header, SizeOf(ArrayHeader));
      ID := IdString;

      {Read data pages}
      for P := 0 to Pred(PageCount) do begin
        {Get position of page}
        Seek(F, SizeOf(VarrayHeader)+LongInt(SizeOf(LongInt))*P);
        BlockRead(F, N, SizeOf(LongInt), Bytes);
        if (IoResult <> 0) or (Bytes <> SizeOf(LongInt)) then begin
          Close(F);
          P := IoResult;
          Error(12);
          Exit;
        end;
        {Read data}
        Seek(F, N);
        BlockRead(F, Pages[P]^, PageSize, Bytes);
        if (IoResult <> 0) or (Bytes <> PageSize) then begin
          Close(F);
          P := IoResult;
          Error(12);
          Exit;
        end;
      end;
    end;

    Close(F);
    if IoResult <> 0 then
      Error(10);
  end;

begin
  ArrayErrorLast := 0;
end.
