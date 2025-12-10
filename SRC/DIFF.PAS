{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F-}

{$I TPDEFINE.INC} {!!.11}

{*********************************************************}
{*                     DIFF.PAS 5.22                     *}
{*                   Difference finder                   *}
{*       An example program for Turbo Professional       *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program Diff;
  {-Compare two text files}
  { Use Extended, Expanded, or Normal memory for storage}

uses
  Dos,
  TpString,
  TpDos,
  TpAsciiz                    {!!.20}
{$IFNDEF Dpmi}                {!!.20}
  , TpExtMem,                 {!!.20}
    TpEms                     {!!.20}
{$ENDIF}                      {!!.20}
  ;                           {!!.20}

const
  MaxFile = 6000;            {Max number of lines in each file - absolute max 13104}
  MaxOver = 6001;            {MaxFile+1}
  MaxSym = 6000;             {Symbol table size, set to ~MaxFile - absolute max 13104}
  TopSym = 5999;             {MaxSym-1}
  Unused = $FFFF;            {Implies symbol table entry not in use}
  FileBufSize = 8192;        {Size of input file buffer}

  MaxExtPages = 94;          {Maximum number of pages of Extended memory}
  ExtPageSize = 16384;       {Size of an Extended memory page in bytes}

  MaxEmsPages = 128;         {Maximum number of pages of Expanded memory}
  EmsPageSize = 16384;       {Size of an EMS memory page in bytes}
  PutPageWin = 0;            {Physical EMS page showing put buffer}
  GetPageWin = 1;            {Physical EMS page showing get buffer}

type

  SymNum = 0..TopSym;
  LineNum = 0..MaxOver;
  LineCnt = 0..MaxOver;

  LineRec =
    record
      Matched : Boolean;
      Index : Word;
      SymIndex : Word;
    end;

  {Text storage}
  StorageType = (Unknown, HeapMem, ExpMem, ExtMem);
  StorageRec =
    record
      case StorageType of
        Unknown,
        HeapMem : (Data : AsciizPtr);
        ExpMem : (EmsHandle, EmsOfs : Word);
        ExtMem : (ExtIndex, ExtOfs : Word);
    end;

{$IFNDEF Dpmi}  {!!.20}
  {EMS and Extended memory management}
  ExtBuffer = array[1..ExtPageSize] of Char;
  ExtBufferPtr = ^ExtBuffer;
  ExtPageArray = array[1..MaxExtPages] of HugePtr;
  ExtPageArrayPtr = ^ExtPageArray;
  EmsBuffer = array[1..EmsPageSize] of Char;
  EmsBufferPtr = ^EmsBuffer;
  EmsPageArray = array[1..MaxEmsPages] of Word;
  EmsPageArrayPtr = ^EmsPageArray;
{$ENDIF}  {!!.20}

  {Divide Symbol record into two parts so that an array of them
   can have as many elements as does the Line array}

  SymRec1 =
    record
      HashVal : Word;
      Oline : LineNum;
      Ocount : 0..2;
    end;

  SymRec2 =
    record
      Ncount : 0..2;
      Line : AsciizPtr;
    end;

  LineArray = array[LineNum] of LineRec;
  SymTable1 = array[SymNum] of SymRec1;
  SymTable2 = array[SymNum] of SymRec2;

  TextBuffer = array[1..FileBufSize] of Char;

var

  {Comparison algorithm}
  OldMax : Word;             {Line count in old file}
  NewMax : Word;             {Line count in new file}
  SymsAvail : Word;          {Free symbol entries}
  OA : ^LineArray;           {Points to array of old lines}
  NA : ^LineArray;           {Points to array of new lines}
  ST1 : ^SymTable1;          {Points to one half of symbol table}
  ST2 : ^SymTable2;          {Points to other half of symbol table}

  {File input}
  Oname : string[64];        {Old file name}
  Nname : string[64];        {New file name}
  F : Text;                  {Input file}
  FB : TextBuffer;           {Buffer for input file}
  CurLine : Asciiz;          {Current line of text}

  {Status reporting}
  StdErr : Text;             {Output for status reporting}
  Diffs : LongInt;           {Number of differences}
  LastStatLen : Word;        {Length of last line counter for status}
  NextStep : LongInt;        {Next order of magnitude where LastStatLen increases}
  TimeVal : LongInt;         {Timer reading in milliseconds}
  Debug : Boolean;           {True for debug output}

  {Extended storage management}
  DataLoc : StorageType;     {Where the text is stored}
  PB : Pointer;              {Put buffer for extended/expanded memory}
  GB : Pointer;              {Get buffer for extended/expanded memory}
  PutPage : Word;            {Current memory page in put buffer}
  GetPage : Word;            {Current memory page in get buffer}
  EP : Pointer;              {Index of extended/expanded memory pages}
  NextFree : Word;           {Next free location in current put page}
  EmsPages : Word;           {Number of EMS pages allocated}
  SaveExitProc : Pointer;    {ExitProc chain}

{$IFNDEF Dpmi}                                                  {!!.20}
  procedure DeallocateEms;
    {-Deallocate all EMS memory used}
  var
    i : Word;
  begin
    for i := 1 to EmsPages do
      if DeallocateEmsHandle(EmsPageArrayPtr(EP)^[i]) then
        ;
  end;
{$ENDIF}                                                        {!!.20}

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

  procedure MainExitProc;
    {-Clean up when DIFF is done}
  begin
    {Restore previous exit handler}
    ExitProc := SaveExitProc;

{$IFNDEF Dpmi}                                                     {!!.20}
    {Deallocate expanded/extended memory, if any}
    case DataLoc of
      ExpMem : DeallocateEms;
      ExtMem : {Deallocated by TpExtMem exitproc} ;
      HeapMem : {Deallocated by DOS} ;
    end;
{$ENDIF}                                                           {!!.20}
  end;
  {$F-}

  procedure OpenStdErr(var StdErr : Text);
    {-Open StdErr for status reporting}
  const
    StdErrBuf : Char = #0;   {Buffer for status reporting}
  begin
    if OpenStdDev(StdErr, 2) then
      {Force buffer flush every character}
      SetTextBuf(StdErr, StdErrBuf, 1)
    else begin
      WriteLn('Error opening StdErr');
      Halt(1);
    end;
  end;

  procedure FatalError(msg : string);
    {-Report error message and halt}
  begin
    WriteLn(StdErr);
    if msg <> '' then
      WriteLn(StdErr, msg);
    Halt(1);
  end;

  procedure Unrecognized(arg : string);
    {-Report a command line error}
  begin
    FatalError('Unrecognized command line argument '+arg);
  end;

  procedure OutOfSymbols;
    {-Report a common error}
  begin
    FatalError('Insufficient symbol table space to process files');
  end;

  procedure OutOfMemory;
    {-Report a common error}
  begin
    FatalError('Insufficient memory to process files');
  end;

  procedure UnableToMap;
    {-Report a common error}
  begin
    FatalError('Unable to map EMS page window');
  end;

  procedure WriteError;
    {-Report a common error}
  begin
    FatalError('Error writing output');
  end;

  function Ms2S(ms : LongInt) : string;
    {-Convert milliseconds to seconds in a string}
  var
    s : string;
  begin
    Str(ms, s);
    {Pad out to three decimal places}
    while Length(s) < 3 do
      s := '0'+s;
    {Truncate to nearest tenth of a second}
    Dec(s[0]);
    Dec(s[0]);
    {Insert decimal point}
    Insert('.', s, Length(s));
    {Insert leading zero}
    if Length(s) = 2 then
      s := '0'+s;
    Ms2S := s;
  end;

  procedure UpdateLineCount(Fline : LongInt);
    {-Update the line counter on the status line}
  begin
    Write(StdErr, CharStr(^H, LastStatLen), '(', Fline, ')');
    if Fline >= NextStep then
      repeat
        Inc(LastStatLen);
        NextStep := 10*NextStep;
      until NextStep > Fline;
  end;

  procedure GetParameters;
    {-Parse the command line for parameters}
  var
    i : Integer;
    arg : string;
  begin
    Oname := '';
    Nname := '';
    DataLoc := Unknown;
    Debug := False;

    i := 1;
    while i <= ParamCount do begin
      arg := ParamStr(i);

      if (Length(arg) = 2) and ((arg[1] = '-') or (arg[1] = '/')) then
        case Upcase(arg[2]) of
          'D' : Debug := True;
          'N' : DataLoc := HeapMem;
        else
          Unrecognized(arg);
        end
      else if Oname = '' then
        Oname := stupcase(arg)
      else if Nname = '' then
        Nname := stupcase(arg)
      else
        Unrecognized(arg);

      Inc(i);
    end;

    if (Oname = '') or (Nname = '') then begin
      WriteLn(StdErr, 'Usage: DIFF FileA FileB [/N] [>Differences]');
      FatalError('  /N  Force text storage to use normal memory');
    end;

  end;

  function MaxFreeLoc : StorageType;
    {-Return the storage location with largest free space}
  var
    HeapFree : LongInt;
    ExtFree : LongInt;
    EmsFree : LongInt;
  begin
{$IFDEF Dpmi}                                                     {!!.20}
    MaxFreeLoc := HeapMem;                                        {!!.20}
{$ELSE}                                                           {!!.20}
    ExtFree := LongInt(1024)*extmemavail;
    if Debug then
      WriteLn('extended storage: ', ExtFree, ' bytes');
    if EmsInstalled then begin
      EmsFree := EmsPagesAvail;
      if EmsFree = $FFFF then
        {Error}
        EmsFree := 00
      else
        EmsFree := LongInt(16384)*EmsFree;
    end else
      EmsFree := 00;
    if Debug then
      WriteLn('expanded storage: ', EmsFree, ' bytes');
    HeapFree := MemAvail;
    if Debug then
      WriteLn('normal storage: ', HeapFree, ' bytes');

    if (EmsFree > HeapFree) then
      {Give expanded memory priority over extended}
      MaxFreeLoc := ExpMem
    else if (ExtFree > HeapFree) then
      MaxFreeLoc := ExtMem
    else
      MaxFreeLoc := HeapMem;
{$ENDIF}                                                          {!!.20}
  end;

  procedure GetMemChk(var P; Size : Word);
    {-Allocate heap space, halting on error}
  var
    Pt : Pointer absolute P;
  begin
    GetMem(Pt, Size);
    if Pt = nil then
      OutOfMemory;
  end;

  procedure Initialize;
    {-Initialize globals}
  const
    DataName : array[StorageType] of string[8] =
    ('unknown', 'normal', 'ems', 'extended');
  var
    s : SymNum;
  begin

    {Take over heap error control - forcing nil return on failure of getmem}
    HeapError := @HeapFunc;

    {Set up exit proc}
    SaveExitProc := ExitProc;
    ExitProc := @MainExitProc;

    {Allocate space for symbol table and line arrays}
    GetMemChk(ST1, SizeOf(SymTable1));
    GetMemChk(ST2, SizeOf(SymTable2));
    GetMemChk(OA, SizeOf(LineArray));
    GetMemChk(NA, SizeOf(LineArray));

    {Initialize symbol table}
    for s := 0 to TopSym do
      with ST1^[s], ST2^[s] do begin
        HashVal := Unused;
        Oline := MaxOver;
        Ocount := 0;
        Ncount := 0;
      end;

    OldMax := 0;
    NewMax := 0;
    SymsAvail := MaxSym;
    Diffs := 00;
    PutPage := 0;
    GetPage := 0;

    if DataLoc = Unknown then
      {Determine where the input text is best stored}
      DataLoc := MaxFreeLoc;

    if Debug then
      WriteLn(StdErr, 'Using ', DataName[DataLoc], ' storage');

{$IFNDEF Dpmi}                                                        {!!.20}
    {Initialize expanded or extended memory work areas}
    case DataLoc of
      ExtMem :
        begin
          {Force allocation of extended page on first storage attempt}
          NextFree := Succ(ExtPageSize);
          {Allocate put and get buffers and extended page map array}
          GetMemChk(PB, SizeOf(ExtBuffer));
          GetMemChk(GB, SizeOf(ExtBuffer));
          GetMemChk(EP, SizeOf(ExtPageArray));
        end;

      ExpMem :
        begin
          {Force allocation of expanded page on first storage attempt}
          NextFree := Succ(EmsPageSize);
          {Initialize the page frame pointers}
          PB := EmsPageFramePtr;
          GB := Ptr(Seg(PB^), Ofs(PB^)+EmsPageSize);
          EmsPages := 0;
          {Allocate expanded page map array}
          GetMemChk(EP, SizeOf(EmsPageArray));
        end;
    end;
{$ENDIF}                                                              {!!.20}
  end;

{$IFNDEF Dpmi}                                                        {!!.20}
  procedure WritePage(Page : Word);
    {-Write put buffer from normal memory to extended memory}
  begin
    if Page > 0 then
      MoveExtMem(PtrToHuge(PB), ExtPageArrayPtr(EP)^[Page], ExtPageSize shr 1);
  end;

  procedure ReadPage(Page : Word);
    {-Read page from extended memory to get buffer in normal memory}
  begin
    MoveExtMem(ExtPageArrayPtr(EP)^[Page], PtrToHuge(GB), ExtPageSize shr 1);
  end;
{$ENDIF}                                                              {!!.20}

  function PutLine(var A : Asciiz) : AsciizPtr;
    {-Put line into text storage, returning a StorageRec}
  var
    Alen : Word;
    P : AsciizPtr;
{$IFNDEF Dpmi}                                                        {!!.20}
    HP : HugePtr;
{$ENDIF}                                                              {!!.20}
  begin
    Alen := Succ(LenAsc(A));

    case DataLoc of
      HeapMem :
        begin
          GetMemChk(P, Alen);
          Move(A, P^, Alen);
        end;

{$IFNDEF Dpmi}                                                        {!!.20}
      ExtMem :
        begin
          {Will new line fit into current page?}
          if NextFree+Alen > ExtPageSize then begin
            {No - Flush old put page to extended memory}
            WritePage(PutPage);
            {Allocate a new put page}
            HP := GetExtMem(ExtPageSize shr 10);
            if HP = nil then
              OutOfMemory;
            Inc(PutPage);
            ExtPageArrayPtr(EP)^[PutPage] := HP;
            NextFree := 1;
          end;
          {Store the data into the normal memory put buffer}
          Move(A, ExtBufferPtr(PB)^[NextFree], Alen);
          {Initialize the storage record for this line}
          with StorageRec(P) do begin
            ExtIndex := PutPage;
            ExtOfs := NextFree;
          end;
          {Update the next free index}
          Inc(NextFree, Alen);
        end;

      ExpMem :
        begin
          {Will new line fit into current page?}
          if NextFree+Alen > EmsPageSize then begin
            {No - Allocate a new storage element}
            PutPage := AllocateEmsPages(1);
            if PutPage = $FFFF then
              OutOfMemory;
            {Maintain a page array so we can deallocate what we allocated}
            Inc(EmsPages);
            EmsPageArrayPtr(EP)^[EmsPages] := PutPage;
            {Map put page window to point to new page}
            if not(MapEmsPage(PutPage, 0, PutPageWin)) then
              UnableToMap;
            NextFree := 1;
          end;
          {Store the line in expanded memory}
          Move(A, EmsBufferPtr(PB)^[NextFree], Alen);
          {Initialize the storage record for this line}
          with StorageRec(P) do begin
            EmsHandle := PutPage;
            EmsOfs := NextFree;
          end;
          {Update the next free index}
          Inc(NextFree, Alen);
        end;
{$ENDIF}                                                              {!!.20}
    end;

    PutLine := P;
  end;

  function GetLine(P : AsciizPtr) : AsciizPtr;
    {-Return a pointer to Asciiz}
  begin
    case DataLoc of
      HeapMem :
        GetLine := P;

{$IFNDEF Dpmi}                                                        {!!.20}
      ExtMem :
        with StorageRec(P) do
          if ExtIndex = PutPage then
            {Line is in the put buffer already (not flushed)}
            GetLine := @ExtBufferPtr(PB)^[ExtOfs]
          else begin
            if GetPage <> ExtIndex then begin
              {Get a different page from extended memory}
              GetPage := ExtIndex;
              ReadPage(GetPage);
            end;
            {Line is in the get buffer}
            GetLine := @ExtBufferPtr(GB)^[ExtOfs];
          end;

      ExpMem :
        with StorageRec(P) do begin
          if GetPage <> EmsHandle then begin
            {Map a different expanded memory page into the Get page}
            GetPage := EmsHandle;
            if not(MapEmsPage(GetPage, 0, GetPageWin)) then
              UnableToMap;
          end;
          GetLine := @EmsBufferPtr(GB)^[EmsOfs];
        end;
{$ENDIF}                                                              {!!.20}
    end;
  end;

  function Hash(var A : Asciiz) : Word;
    {-Compute hash of a}
  inline
  ($5E/                      {pop si           ;Offset of Asciiz into SI}
    $58/                     {pop ax           ;Segment into AX}
    $8C/$DA/                 {mov dx,ds        ;Save DS}
    $8E/$D8/                 {mov ds,ax        ;DS:SI => Asciiz}
    $FC/                     {cld              ;Forward}
    $31/$DB/                 {xor bx,bx        ;BX will hold hash}
    $31/$C0/                 {xor ax,ax        ;Assure AH clear}
    {next:}
    $AC/                     {lodsb            ;Next character of Asciiz}
    $09/$C0/                 {or ax,ax         ;Is it the last?}
    $74/$04/                 {jz done          ;Yes, we're done}
    $01/$C3/                 {add bx,ax        ;No, add to hash}
    $E2/$F7/                 {loop next        ;Get next character}
    {done:}
    $89/$D8/                 {mov ax,bx        ;Return result in AX}
    $09/$C0/                 {or  ax,ax        ;Is AX zero?}
    $74/$01/                 {jz  leave}
    $48/                     {dec ax           ;Don't return FFFF}
    {leave:}
    $8E/$DA);                {mov ds,dx        ;Get DS back}

  function Store(var A : Asciiz) : SymNum;
    {-Store text of line, and return symbol table entry}
  var
    s : SymNum;
    h : Word;
    symh : Word;
    done : Boolean;
  begin
    {Compute hash of a}
    h := Hash(A);

    {Probe symbol table for unused entry}
    s := h mod MaxSym;
    done := False;

    repeat
      with ST1^[s], ST2^[s] do begin
        symh := HashVal;
        if symh = Unused then begin
          {Empty symbol table entry}
          done := True;
          Dec(SymsAvail);
          HashVal := h;
          Line := PutLine(A);
        end else if symh = h then begin
          {Symbol entry used - chance or duplicate line?}
          if CompAsc(A, GetLine(Line)^) = AscEqual then
            {Duplicate line}
            done := True
          else if SymsAvail < 2 then
            OutOfSymbols
          else
            {Hash matched by chance, search for empty slot}
            s := Succ(s) mod MaxSym;
        end else if SymsAvail < 2 then
          OutOfSymbols
        else
          {Collision due to previous bumping, search for empty slot}
          s := Succ(s) mod MaxSym;
      end;
    until done;

    Store := s;
  end;

  procedure ReadFile(Fname : string; OldFile : Boolean; var LA : LineArray; var Max : Word);
    {-Read in file fname, build its linearray, and update the symbol table}
  var
    c : LineCnt;
    s : SymNum;
  begin

    {Assure file exists, and open it for reading}
    if not(existfile(Fname)) then
      FatalError(Fname+' not found');
    Assign(F, Fname);
    SetTextBuf(F, FB, FileBufSize);
    Reset(F);

    {Display line counter}
    Write(StdErr, Fname, '(0)');
    LastStatLen := 3;
    NextStep := 10;
    c := 0;

    repeat

      {Read next line}
      if not(ReadLnAsc(F, CurLine)) then
        FatalError('Error reading '+Fname);

      {Keep count of lines, report status}
      Inc(c);
      if c and 63 = 0 then
        UpdateLineCount(c);

      {Store the line, and return its symbol table entry}
      s := Store(CurLine);

      {Update counters in symbol table}
      with ST1^[s], ST2^[s] do
        if OldFile then begin
          Oline := c;
          if Ocount < 2 then
            Inc(Ocount);
        end else
          if Ncount < 2 then
            Inc(Ncount);

      {Update the line array}
      with LA[c] do begin
        Matched := False;
        Index := s;
        SymIndex := s;
      end;

    until eof(F) or (c >= MaxFile);

    {Create sentinel}
    with LA[Succ(c)] do begin
      Matched := True;
      Index := MaxOver;
      SymIndex := MaxOver;
    end;

    {Return maximum}
    Max := c;
    Close(F);

    {Complete status line}
    UpdateLineCount(c);
    WriteLn(StdErr);

  end;

  procedure MatchUp(o, n : LineNum);
    {-Mark two lines as matching each other}
  begin
    with OA^[o] do begin
      Matched := True;
      Index := n;
    end;
    with NA^[n] do begin
      Matched := True;
      Index := o;
    end;
  end;

  procedure FindUnique;
    {-Match up unique lines between old and new files}
  var
    s : SymNum;
    n : LineNum;
  begin
    for n := 1 to NewMax do begin
      s := NA^[n].Index;
      with ST1^[s], ST2^[s] do
        if (Ocount = 1) and (Ncount = 1) then
          MatchUp(Oline, n);
    end;
  end;

  procedure Resolve(var o, n : LineNum);
    {-Find the smaller block to move}
  var
    xo : LineNum;
    xn : LineNum;
    first : LineNum;
    last : LineNum;
    t : Word;
    s : SymNum;
  begin
    {Get length of block starting at OA^[o]}
    xo := o;
    repeat
      t := Succ(OA^[xo].Index);
      Inc(xo);
    until not(OA^[xo].Matched) or (t <> OA^[xo].Index);

    {Get length of block starting at NA^[n]}
    xn := n;
    repeat
      t := Succ(NA^[xn].Index);
      Inc(xn);
    until not(NA^[xn].Matched) or (t <> NA^[xn].Index);

    {Which block was smaller?}
    if (xo-o) < (xn-n) then begin
      {Move block down}
      first := o;
      last := Pred(xo);
      o := xo;
    end else begin
      {Move block up}
      first := NA^[n].Index;
      last := first+Pred(xn-n);
      n := xn;
    end;

    {Break the matches}
    for t := first to last do begin
      s := OA^[t].SymIndex;
      xo := ST1^[s].Oline;
      xn := OA^[xo].Index;
      with OA^[xo] do begin
        Matched := False;
        Index := s;
      end;
      with NA^[xn] do begin
        Matched := False;
        Index := s;
      end;
    end;
  end;

  procedure BlockMoves;
    {-Find apparent block moves and transform into single line differences}
  var
    o : LineNum;
    n : LineNum;
  begin
    o := 1;
    n := 1;

    repeat
      {Skip deletions from old file}
      while not(OA^[o].Matched) do
        Inc(o);

      {Skip insertions into new file}
      while not(NA^[n].Matched) do
        Inc(n);

      if (n > NewMax) or (o > OldMax) then
        {Done}
        Exit;

      if OA^[o].Index = n then begin
        {O and n match, skip over them}
        Inc(o);
        Inc(n);
      end else
        Resolve(o, n);

    until False;
  end;

  procedure Sweep;
    {-Spread unique line matches through the file}
  var
    o : LineNum;
    o1 : LineNum;
    n : LineNum;
    n1 : LineNum;
    nm1 : LineNum;
  begin

    {Set up seed matches at ends of new file}
    NA^[0].Index := 0;
    NA^[Succ(NewMax)].Index := Succ(OldMax);

    {Toward end of file}
    for n := 0 to Pred(NewMax) do
      if NA^[n].Matched or (n = 0) then begin
        n1 := Succ(n);
        if not(NA^[n1].Matched) then begin
          o := NA^[n].Index;
          if o < OldMax then begin
            o1 := Succ(o);
            if (OA^[o1].Matched = NA^[n1].Matched) and (OA^[o1].Index = NA^[n1].Index) then
              MatchUp(o1, n1);
          end;
        end;
      end;

    {Toward beginning of file}
    nm1 := Succ(NewMax);
    for n := nm1 downto 2 do
      if NA^[n].Matched or (n = nm1) then begin
        n1 := Pred(n);
        if not(NA^[n1].Matched) then begin
          o := NA^[n].Index;
          if o > 1 then begin
            o1 := Pred(o);
            if (OA^[o1].Matched = NA^[n1].Matched) and (OA^[o1].Index = NA^[n1].Index) then
              MatchUp(o1, n1);
          end;
        end;
      end;
  end;

  procedure WriteOutput(var A : Asciiz);
    {-Write one line of output}
  begin
    if not(WriteAsc(Output, A)) then
      WriteError;
    WriteLn(Output);
    if IoResult <> 0 then
      WriteError;
  end;

  procedure WriteBlocks;
    {-Output differences in groups of inserts and deletes}
  var
    o : LineNum;
    n : LineNum;
    t : LineNum;
  begin
    o := 1;
    n := 1;

    repeat

      if not(OA^[o].Matched) then begin
        {Old line was deleted}
        t := o;
        repeat
          Inc(o);
          Inc(Diffs);
        until OA^[o].Matched;
        WriteLn(Output, '****Delete lines ', long2str(t), '-', long2str(Pred(o)), ' of ', Oname);
        if IoResult <> 0 then
          WriteError;
        while t < o do begin
          WriteOutput(GetLine(ST2^[OA^[t].Index].Line)^);
          Inc(t);
        end;
      end;

      if not(NA^[n].Matched) then begin
        {New line was inserted}
        t := n;
        repeat
          Inc(n);
          Inc(Diffs);
        until NA^[n].Matched;
        WriteLn(Output, '****Insert lines ', long2str(t), '-', long2str(Pred(n)), ' from ', Nname);
        if IoResult <> 0 then
          WriteError;
        while t < n do begin
          WriteOutput(GetLine(ST2^[NA^[t].Index].Line)^);
          Inc(t);
        end;
      end;

      {Skip over matched lines}
      while OA^[o].Matched and NA^[n].Matched and (o <= OldMax) do begin
        Inc(o);
        Inc(n);
      end;

    until (OA^[o].SymIndex = MaxOver) and (NA^[n].SymIndex = MaxOver);
  end;

begin

  {Open StdErr for status reporting}
  OpenStdErr(StdErr);
  WriteLn(StdErr, 'File Compare. Copyright (c) 1987,92 by TurboPower Software. Version 5.22');
  WriteLn(StdErr);

  {Get parameters from command line}
  GetParameters;

  {Initialize the data structures}
  Initialize;

  TimeVal := timems;

  {Read in the files}
  ReadFile(Oname, True, OA^, OldMax);
  ReadFile(Nname, False, NA^, NewMax);

  {Compare the two files}
  FindUnique;
  BlockMoves;
  Sweep;

  {Get elapsed time for read-in and comparison}
  TimeVal := timems-TimeVal;

  WriteBlocks;

  Write(StdErr, Diffs, ' difference');
  if Diffs <> 1 then
    Write(StdErr, 's');
  WriteLn(StdErr, ' found in ', Ms2S(TimeVal), ' seconds');
  if Diffs <> 0 then
    {Return code to indicate differences}
    Halt(1);
end.
