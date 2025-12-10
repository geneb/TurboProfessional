{$IFDEF Windows}
  !! ERROR - This program is not compatible with Windows !!
{$ENDIF}

{$R-,S-,I-,V-,F-,B-}

{*********************************************************}
{*                  MAKEHELP.PAS 5.22                    *}
{*      Copyright (c) TurboPower Software 1987,1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

program MakeHelp;
  {-Build indexed binary help file from text file}
uses
  Dos,
  TPDos,
  TPMemChk,
  TPString,
  TPCrt,
  TPWindow,
  TPPick,
  TpHelp;

const
  FileBuffSize = 4096;       {Size of input and output file buffers}
  CommandMark = '!';         {Marks help metacommand in text file}
  CommentMark = ';';         {At start of line, marks comment in text file}
  MaxCompIndex = 14;         {Xlate table is 0..14}
  MaxIncludeNest = 1;        {Maximum depth of include nesting}

type
  FileBuff = array[1..FileBuffSize] of Byte;
  String80 = string[80];
  CountArray = array[0..255] of Word;
  StringPtr = ^string;
  SO =
    record
      O : Word;
      S : Word;
    end;
  FileArray = array[0..MaxIncludeNest] of Text;
  LineArray = array[0..MaxIncludeNest] of LongInt;

var
  InName : String80;         {Input file name}
  OutName : String80;        {Output file name}
  InF : FileArray;           {Input files (with include files)}
  OutF : file;               {Output file}
  InBuff : FileBuff;         {Buffer for input text}
  OutBuff : FileBuff;        {Buffer for binary output}
  OutPos : Word;             {Bytes used in output buffer}
  IncLev : Word;             {Include nesting level}
  LineNum : LineArray;       {Current input line number}
  TotLines : LongInt;        {Total number of lines}

  Hdr : HelpHeader;          {Header of help file}
  CP : CharArrayPtr;         {Points to pick array}
  FI : HelpIndexPtr;         {Points to help index}
  TM : TopicIndexPtr;        {Points to sorted topic map}
  IK : TopicIndexPtr;        {Points to index key override}

  C : String80;              {Command or command parameter}
  Clen : Byte absolute C;    {Length of parameter}
  S : string;                {Raw input line}
  Slen : Byte absolute S;    {Length of input line}
  Spos : Byte;               {Position in input line}
  SectPos : LongInt;         {File offset of current section}
  TextWid : Byte;            {Max characters in a line}
  CurSect : Word;            {Current section number}
  BiggestTopicSect : Word;   {Section of biggest topic}
  LineLen : Byte;            {Current line width}
  SectLen : Word;            {Bytes in current section}
  CompLen : Word;            {Compressed bytes in current section}
  TotalSect : LongInt;       {Total uncompressed bytes}
  TotalComp : LongInt;       {Total compressed bytes}
  MaxXrefs : Word;           {Maximum xrefs in one section} {!!.08}
  XrefsInSect : Word;        {Xrefs in current section}     {!!.08}
  MaxXrefSect : Word;        {Section with most xrefs}      {!!.08}

  Count : CountArray;        {Count for each character}
  I : Word;                  {Index used for compression}
  B : Word;                  {Index used for count table position}
  MFB : Word;                {Most frequent byte}
  TranslateTable : XlateArray; {Easy to access xlate table}

  WriteWarnings : Boolean;   {True to write wrap warnings}
  Warnings : Word;           {Number of warnings reported}
  Nibble : Boolean;          {True when a nibble is pending}
  InOrder : Boolean;         {True when a sort section is in sort order}
  InXref : Boolean;          {True while in midst of xref item}
  Wrapping : Boolean;        {True when word wrapping}

  procedure WriteCopyRight;
    {-Write the copyright line}
  begin
    WriteLn('Help Compiler. Copyright (c) 1987,92 by TurboPower Software. Version 5.22');
    WriteLn;
  end;

  procedure Error(Msg : string);
    {-Write error message and halt}
  begin
    WriteLn(^M'ERROR: ', Msg);
    Halt(1);
  end;

  procedure EraseOutFile;
    {-Close and erase output file}
  var
    IO : Word;
  begin
    Close(OutF);
    Erase(OutF);
    IO := IoResult;
  end;

  function FileName(var F : Text) : String;
    {-Return name of file}
  var
    NLen : Byte;
  begin
    with TextRec(F) do begin
      NLen := 0;
      while Name[NLen] <> #0 do begin
        FileName[NLen+1] := Name[NLen];
        inc(NLen);
      end;
      FileName[0] := Char(NLen);
    end;
  end;

  procedure WarnLine(Msg : string);
    {-Report error message, but continue}
  var
    KW : Word;
  begin
    if WriteWarnings then begin
      WriteLn(^M'WARNING: ', Msg);
      WriteLn('File: ', FileName(Inf[IncLev]));
      WriteLn('Line number: ', LineNum[IncLev]);
      WriteLn(S);
      Inc(Warnings);
      if Warnings and 7 = 0 then begin
        Write('Press any key to continue, <Esc> to quit');
        KW := ReadKeyWord;
        if KW = $011B then begin
          WriteLn;
          EraseOutFile;
          Halt(1);
        end else begin
          Write(^M);
          ClrEol;
        end;
      end;
    end;
  end;

  procedure ErrorLine(Msg : string);
    {-Report error position and message}
  begin
    WriteLn(^M'ERROR: ', Msg);
    WriteLn('File: ', FileName(Inf[IncLev]));
    WriteLn('Line number: ', LineNum[IncLev]);
    WriteLn(S);
    EraseOutFile;
    Halt(1);
  end;

  procedure FlushTextIn(var F : Text);
    {-Flush text file opened for reading}
  type
    LH = record L, H : Word; end;
  var
    Bytes : LongInt;
    Regs : Registers;
  begin
    with TextRec(F), Regs do begin
      Bytes := LongInt(BufPos)-BufEnd;
      if Bytes = 0 then
        Exit;

      {Position file pointer past last data used}
      AX := $4201;
      BX := Handle;
      CX := LH(Bytes).H;
      DX := LH(Bytes).L;
      MsDos(Regs);

      {Mark buffer empty}
      BufPos := 0;
      BufEnd := 0;
    end;
  end;

  procedure OpenInf(Name : String80);
    {-Open input file}
  begin
    if IncLev > 0 then
      FlushTextIn(InF[IncLev-1]);
    Assign(InF[IncLev], Name);
    Reset(InF[IncLev]);
    if IoResult <> 0 then
      Error(Name+' not found');
    LineNum[IncLev] := 0;
    Write(^M, CharStr(' ', 64), ^M, Pad(StUpcase(Name), 13), 0:5);
  end;

  procedure CloseInf;
    {-Close input file}
  begin
    WriteLn(^H^H^H^H^H, LineNum[IncLev]:5);
    Close(InF[IncLev]);
    inc(TotLines, LineNum[IncLev]);
    if IncLev > 0 then begin
      dec(IncLev);
      SetTextBuf(InF[IncLev], InBuff, FileBuffSize);
      Write(Pad(StUpcase(FileName(InF[IncLev])), 13), LineNum[IncLev]:5);
    end;
  end;

  procedure Initialize;
    {-Prepare for analysis of help file}
  var
    I : Word;
    Arg : string[127];
  begin
    WriteWarnings := True;
    InName := '';
    OutName := '';

    for I := 1 to ParamCount do begin
      Arg := ParamStr(I);
      if (Arg[1] = '/') or (Arg[1] = '-') then begin
        if Length(Arg) <> 2 then
          Error('Invalid command line option');
        case Upcase(Arg[2]) of
          'Q' : WriteWarnings := False;
        else
          Error('Invalid command line option');
        end;
      end else if Length(InName) = 0 then
        InName := DefaultExtension(StUpcase(CleanPathName(Arg)), 'TXT')
      else if Length(OutName) = 0 then
        OutName := StUpcase(CleanPathName(Arg))
      else
        Error('Too many filenames specified');
    end;

    if Length(InName) = 0 then begin
      WriteLn('Usage: MAKEHELP [/Q] InFile [OutFile]'^M^J);
      WriteLn('  If OutFile is not specified, MAKEHELP uses the InFile name');
      WriteLn('  with an extension of HLP');
      WriteLn;
      WriteLn('  /Q  keeps MAKEHELP from writing wrap warnings');
      Halt(1);
    end;

    if Length(OutName) = 0 then
      OutName := ForceExtension(InName, 'HLP');

    if InName = OutName then
      Error('Input and output filenames must differ');

    Assign(OutF, OutName);
    Rewrite(OutF, 1);
    if IoResult <> 0 then
      Error('Cannot create '+OutName);

    WriteLn('Pass 1 ...........');
    IncLev := 0;
    OpenInf(InName);

    {Default help header}
    FillChar(Hdr, SizeOf(HelpHeader), 0);
    with Hdr do begin
      ID := LongInt(HelpId);
      Width := 40;
    end;

    {No warnings yet}
    Warnings := 0;
    TotLines := 0;

    {Initialize character frequency count array}
    FillChar(Count, SizeOf(Count), 0);
  end;

  procedure ReadTextLine;
    {-Read next line from help text}
  begin
    Inc(LineNum[IncLev]);
    ReadLn(InF[IncLev], S);
    if IoResult <> 0 then
      ErrorLine('Error reading from '+InName);
    if Slen = 0 then
      S[1] := #0;
    if LineNum[IncLev] and $0F = 0 then
      Write(^H^H^H^H^H, LineNum[IncLev]:5);
  end;

  procedure SkipWhite;
    {-Advance Spos past white space}
  begin
    while (Spos <= Slen) and (S[Spos] <= ' ') do
      Inc(Spos);
  end;

  procedure ParseWord(var C : string; MaxLen : Byte);
    {-Parse next word from S, returning it in C}
  var
    Clen : Byte absolute C;
  begin
    SkipWhite;
    Clen := 0;
    while (Spos <= Slen) and (S[Spos] > ' ') and (S[Spos] <> CommentMark) do begin
      if Clen < MaxLen then begin
        Inc(Clen);
        C[Clen] := S[Spos];
      end;
      Inc(Spos);
    end;
  end;

  function ParseNumber(Name : string) : Word;
    {-Parse a word from the line}
  var
    C : string[8];
    N : Word;
  begin
    ParseWord(C, 8);
    if Length(C) = 0 then
      ErrorLine(Name+' expected');
    if not Str2Word(C, N) then
      ErrorLine('Invalid '+Name+' specified');
    ParseNumber := N;
  end;

  function ClassifyCommand(C : string) : Word;
    {-Classify valid help metacommands}
  const
    NumCommands = 9;
    CommandNames : array[1..NumCommands] of string[5] =
    ('TOPIC', 'LINE', 'PAGE', 'WIDTH', 'INDEX', 'NOIND',
     'INCLU', 'WRAP', 'NOWRA');
  var
    I : Integer;
  begin
    C := StUpcase(Copy(C, 1, 5));
    for I := 1 to NumCommands do
      if C = CommandNames[I] then begin
        ClassifyCommand := I;
        Exit;
      end;
    ClassifyCommand := 0;
  end;

  procedure BlockWriteChk(var B; Bytes : Word);
    {-Write a block to output and error check}
  var
    BytesWritten : Word;
  begin
    BlockWrite(OutF, B, Bytes, BytesWritten);
    if (IoResult <> 0) or (BytesWritten <> Bytes) then
      Error('Error writing to '+OutName);
  end;

  procedure WriteHeaders;
    {-Write the binary header structures to the help file}
  begin
    with Hdr do begin
      BlockWriteChk(Hdr, SizeOf(HelpHeader));
      BlockWriteChk(CP^, HighestTopic*NameSize);
      BlockWriteChk(FI^, HighestTopic*SizeOf(HelpIndexRec));
      BlockWriteChk(TM^, HighestTopic*SizeOf(Word));
    end;
  end;

  procedure FindMostFrequent;
    {-Find the most frequently occurring characters}
  begin
    with Hdr do
      for I := 0 to 15 do begin
        MFB := 0;
        {Find most frequently occurring byte in Count table}
        for B := 0 to 255 do
          if Count[B] > Count[MFB] then
            MFB := B;
        {Store it in XlateTable}
        XlateTable[I] := MFB;
        {Mark it out so we can find next MFB}
        Count[MFB] := 0;
      end;
  end;

  procedure AllocWorkSpace;
    {-Allocate space for work arrays and initialize them}
  var                     {!!.20}
    NASize : LongInt;     {!!.20}
  begin
    with Hdr do begin
      {Allocate space for names} {!!.20 - rewritten}
      NASize := LongInt(HighestTopic)*NameSize;
      if NASize > 65520 then
        Error('Topic name array exceeds 64K')
      else if NASize = 0 then
        {Perform a dummy allocation}
        NASize := 4;
      if not GetMemCheck(CP, NASize) then
        Error('Insufficient memory for name array');

      {Allocate space for file index}
      if LongInt(HighestTopic)*SizeOf(HelpIndexRec) > 65520 then
        Error('File index array exceeds 64K')
      else if not GetMemCheck(FI, HighestTopic*SizeOf(HelpIndexRec)) then
        Error('Insufficient memory for index array');

      {Allocate space for topic map}
      if not GetMemCheck(TM, HighestTopic*SizeOf(Word)) then
        Error('Insufficient memory for topic map');

      {Allocate space for index key}
      if not GetMemCheck(IK, HighestTopic*SizeOf(Word)) then
        Error('Insufficient memory for index key');

      {Initialize the arrays}
      FillChar(CP^, HighestTopic*NameSize, 0);
      FillChar(FI^, HighestTopic*SizeOf(HelpIndexRec), lo(NoHelpAvailable));
      FillChar(TM^, HighestTopic*SizeOf(Word), 0);
      FillChar(IK^, HighestTopic*SizeOf(Word), $77);
    end;
  end;

  procedure CountFile;
    {-Scan input file once to determine counts, sizes, frequencies}
  var
    Cnt : Word;
    Ch : Char;
    IncName : String80;
  begin
    with Hdr do begin
      SetTextBuf(InF[IncLev], InBuff, FileBuffSize);

      while not eof(InF[IncLev]) do begin
        ReadTextLine;
        case S[1] of
          CommandMark :      {Line is a help metacommand}
            begin
              Spos := 2;
              ParseWord(C, 8);
              case ClassifyCommand(C) of
                1 :          {TOPIC}
                  begin
                    {New section, get section number}
                    CurSect := ParseNumber('Topic number');
                    if CurSect > HighestTopic then
                      HighestTopic := CurSect;
                    {Get optional pick name}
                    SkipWhite;
                    C := Copy(S, Spos, 80);
                    if Length(C)+1 > NameSize then
                      NameSize := Length(C)+1;
                  end;
                7 :          {INCLUDE}
                  if IncLev = MaxIncludeNest then
                    Error('Too many nested files')
                  else begin
                    {Include file, get filename}
                    ParseWord(IncName, 79);
                    inc(IncLev);
                    OpenInf(IncName);
                    CountFile;
                  end;

                {Ignore other metacommands this pass}
              end;
            end;
          CommentMark :
            {Ignore comment lines}
            ;
        else
          {Part of help text, keep count for compression}
          Spos := 1;
          while Spos <= Slen do begin
            Ch := S[Spos];
            Cnt := Count[Byte(Ch)];
            if Cnt < $FFFF then
              Count[Byte(Ch)] := Cnt+1;
            if Ch = IndexMarker then
              {Skip over the cross-reference topic number}
              repeat
                Inc(Spos);
              until (Spos > Slen) or (S[Spos] = XrefToggle)
            else
              Inc(Spos);
          end;
          {Approximate the number of linebreak markers}
          Inc(Count[Byte(LineBrkMark)]);
        end;
      end;

      CloseInf;
    end;
  end;

  function TranslateIndex(Ch : Char) : Byte;
    {-If Ch is in translate table, return index, else return $0F}
  inline
  ($8C/$D8/                  {mov ax,ds}
    $8E/$C0/                 {mov es,ax}
    $BF/>TranslateTable/     {mov di,>TranslateTable  ;es:di -> TranslateTable}
    $89/$FE/                 {mov si,di               ;save start offset}
    $58/                     {pop ax                  ;al = Ch}
    $B9/>MaxCompIndex+1/     {mov cx,>MaxCompIndex+1  ;cx = bytes to scan}
    $FC/                     {cld                     ;forward}
    $F2/                     {repne                   ;search}
    $AE/                     {scasb                   ;  until match}
    $75/$01/                 {jne fail                ;jump if not found}
    $4F/                     {dec di                  ;point to match if found}
    {fail:}
    $29/$F7/                 {sub di,si               ;compute index of match}
    $89/$F8);                {mov ax,di               ;return index in al}

  procedure FlushBuffer;
    {-Write the output buffer to file}
  begin
    if OutPos > 0 then begin
      BlockWriteChk(OutBuff, OutPos);
      OutPos := 0;
      Nibble := False;
    end;
  end;

  procedure NibbleOut(N : Byte);
    {-Send next nibble to output}
  begin
    if Nibble then begin
      OutBuff[OutPos] := OutBuff[OutPos] or (N shl 4);
      Nibble := False;
      if OutPos = FileBuffSize then
        FlushBuffer;
    end else begin
      Inc(OutPos);
      Inc(CompLen);
      OutBuff[OutPos] := N;
      Nibble := True;
    end;
  end;

  procedure CharOut(Ch : Char);
    {-Compress a single character and write it}
  var
    T : Byte;
  begin
    T := TranslateIndex(Ch);
    if T > MaxCompIndex then begin
      {Not compressible - output 3 nibbles}
      NibbleOut($0F);
      NibbleOut(Ord(Ch) and $0F);
      NibbleOut(Ord(Ch) shr 4);
    end else
      {Store compression code in 1 nibble}
      NibbleOut(T);
    Inc(SectLen);
  end;

  procedure NewSection;
    {-End the current section and prepare for the new}
  begin
    CharOut(SectEndMark);
    FI^[CurSect].CompLen := CompLen;
    with Hdr do
      if SectLen > BiggestTopic then begin
        BiggestTopic := SectLen;
        BiggestTopicSect := CurSect;
      end;

    {Keep track of maximum xrefs in one section} {!!.08}
    if XrefsInSect > MaxXrefs then begin
      MaxXrefs := XrefsInSect;
      MaxXrefSect := CurSect;
    end;
    XrefsInSect := 0;

    Inc(TotalComp, CompLen);
    Inc(TotalSect, SectLen);

    Inc(SectPos, CompLen);
    SectLen := 0;
    CompLen := 0;
    LineLen := 0;
    Nibble := False;
    if OutPos = FileBuffSize then
      FlushBuffer;
  end;

  procedure NewPage;
    {-End the current page}
  begin
    CharOut(PageBrkMark);
    LineLen := 0;
  end;

  procedure NewLine;
    {-End the current line}
  begin
    if InXref then
      {Line break in xref}
      WarnLine('Cross-reference straddles line break');
    CharOut(LineBrkMark);
    LineLen := 0;
  end;

  function LenCount(Ch : Char) : Byte;
    {-Return length to count for character}
  begin
    case Ch of
      Attr1Toggle..XrefToggle :
        LenCount := 0;
    else
      LenCount := 1;
    end;
  end;

  procedure WordOut(var Spos : Byte; Tpos : Byte);
    {-Write line starting at Spos and continuing to Tpos}
  var
    Topic : Word;
    Code : Word;
    Ch : Char;
  begin
    while Spos < Tpos do begin
      Ch := S[Spos];
      CharOut(Ch);
      if Ch = IndexMarker then begin
        {Convert cross-reference topic number to binary}
        Clen := 0;
        repeat
          Inc(Spos);
          Inc(Clen);
          C[Clen] := S[Spos];
        until (Spos >= Tpos) or (S[Spos] = XrefToggle);
        Dec(Clen);
        Val(C, Topic, Code);
        if Code <> 0 then
          ErrorLine('Invalid cross-reference topic number');
        CharOut(Char(lo(Topic)));
        CharOut(Char(Hi(Topic)));
        Inc(XrefsInSect); {!!.08}
      end else begin
        if Ch = XrefToggle then
          InXref := not InXref;
        Inc(LineLen, LenCount(Ch));
        Inc(Spos);
      end;
    end;
  end;

  procedure LineOut;
    {-Wrap and write text lines}
  var
    Tpos : Byte;
    Tlen : Byte;
  begin
    if not Wrapping then begin
      {Write entire line without wrapping}
      SPos := 1;
      WordOut(SPos, Slen+1);
      NewLine;
      Exit;
    end;

    if Slen = 0 then begin
      {Empty line, finish previous line}
      if LineLen > 0 then
        NewLine;
      {Insert blank line}
      NewLine;
      Exit;
    end;

    {Non-empty line}
    if (S[1] = ' ') then
      {Finish previous line}
      if LineLen > 0 then
        NewLine;

    Spos := 1;
    repeat

      {Write white space}
      while (Spos <= Slen) and (S[Spos] = ' ') do begin
        if LineLen < TextWid then begin
          CharOut(' ');
          Inc(LineLen);
        end;
        Inc(Spos);
      end;
      if Spos > Slen then
        Exit;

      {See if next word fits on line}
      Tpos := Spos;
      Tlen := 0;
      repeat
        if S[Tpos] = IndexMarker then
          {Skip over the cross-reference topic number}
          repeat
            Inc(Tpos);
          until (Tpos > Slen) or (S[Tpos] = XrefToggle)
        else begin
          Inc(Tlen, LenCount(S[Tpos]));
          Inc(Tpos);
        end;
      until (Tpos > Slen) or (S[Tpos] = ' ');

      if LineLen+Tlen > TextWid then
        {Word won't fit on line, start a new one}
        NewLine;

      {Write the word}
      WordOut(Spos, TPos);

    until Spos > Slen;

    {End line with blank}
    if LineLen < TextWid then begin
      CharOut(' ');
      Inc(LineLen);
    end;
  end;

  function TopicPtr(Item : Word) : StringPtr;
    {-Return pointer to topic name}
  begin
    with Hdr do
      TopicPtr := Ptr(SO(CP).S, SO(CP).O+NameSize*(Item-1));
  end;

  procedure StorePickName(C : string);
    {-Store pick name for CurSect}
  begin
    Move(C, TopicPtr(CurSect)^, Length(C)+1);
  end;

  procedure Swap(I, J : Word);
    {-Swap topic map for I and J}
  var
    Tmp : Word;
  begin
    Tmp := TM^[J];
    TM^[J] := TM^[I];
    TM^[I] := Tmp;
    InOrder := False;
  end;

  procedure SortTopicMap;
    {-Sort the topic map into alphabetical order}
  var
    I : Word;
    J : Word;
    K : Word;
    Offset : Word;
    IM : Word;
    JM : Word;
    IPtr : StringPtr;
    JPtr : StringPtr;
  begin
    with Hdr do begin
      {Initialize topic map}
      for I := 1 to HighestTopic do
        TM^[I] := I;

      {Sort topic names via topic map}
      Offset := HighestTopic;
      while Offset > 1 do begin
        Offset := Offset shr 1;
        K := HighestTopic-Offset;
        repeat
          InOrder := True;
          for J := 1 to K do begin
            I := J+Offset;
            IM := TM^[I];
            JM := TM^[J];
            IPtr := TopicPtr(IM);
            JPtr := TopicPtr(JM);
            if Length(IPtr^) = 0 then
              {"I" is greater - sort empty names to end of list}
            else if Length(JPtr^) = 0 then
              {"J" is greater - sort empty names to end of list}
              Swap(I, J)
            else if IK^[IM] > IK^[JM] then
              {"I" is greater - no swap needed}
            else if IK^[IM] < IK^[JM] then
              {"J" is greater by index override}
              Swap(I, J)
            else if CompUCString(IPtr^, JPtr^) = Less then
              {"J" is greater alphabetically}
              Swap(I, J)
          end;
        until InOrder;
      end;

      {Find last selected, non-blank sorted topic name}
      for I := 1 to HighestTopic do begin
        IM := TM^[I];
        if (IK^[IM] = $FFFF) or (Length(TopicPtr(IM)^) = 0) then begin
          NamedTopics := I-1;
          Exit;
        end;
      end;
      NamedTopics := HighestTopic;
    end;
  end;

  procedure InitForScan;
    {-Initialize for the scan file pass}
  begin
    with Hdr do begin
      {Correct default text dimensions for frames and spacing}
      TextWid := Width-4;

      {Store position for first help section}
      SectPos := (SizeOf(HelpHeader)+
        LongInt(HighestTopic)*(NameSize+SizeOf(HelpIndexRec)+SizeOf(Word)));
       {^^^^^^^^            ^}
       {!!.07}

      {Initialize counters}
      TotalSect := 0;
      TotalComp := 0;
      CurSect := 0;
      BiggestTopicSect := 0;
      LineLen := 0;
      SectLen := 0;
      CompLen := 0;
      OutPos := 0;
      MaxXrefs := 0;         {!!.08}
      XrefsInSect := 0;      {!!.08}
      MaxXrefSect := 0;      {!!.08}
      Nibble := False;
      InXref := False;
      Wrapping := True;
      TranslateTable := XlateTable;

      WriteLn('Pass 2 ...........');
      TotLines := 0;
      IncLev := 0;
      OpenInf(InName);
    end;
  end;

  procedure ScanFile;
    {-Scan input file to create help text}
  var
    IncName : String80;
  begin
    with Hdr do begin
      LineNum[IncLev] := 0;
      SetTextBuf(InF[IncLev], InBuff, FileBuffSize);

      while not eof(InF[IncLev]) do begin
        ReadTextLine;
        case S[1] of
          CommandMark :      {A help metacommand}
            begin
              Spos := 2;
              ParseWord(C, 8);
              case ClassifyCommand(C) of
                1 :          {TOPIC}
                  begin
                    if CurSect <> 0 then
                      {Complete previous section}
                      NewSection;
                    {Get section number}
                    CurSect := ParseNumber('Topic number');
                    {Error check}
                    if FI^[CurSect].Start <> NoHelpAvailable then
                      ErrorLine('Duplicate help topic number');
                    {Store file index}
                    FI^[CurSect].Start := SectPos;
                    {Get optional pick name}
                    SkipWhite;
                    C := Copy(S, Spos, 80);
                    if Length(C) > 0 then
                      {Store pick name}
                      StorePickName(C);
                  end;

                2 :          {LINE}
                  NewLine;

                3 :          {PAGE}
                  NewPage;

                4 :          {WIDTH}
                  if CurSect <> 0 then
                    ErrorLine('WIDTH statement must precede first help topic')
                  else begin
                    {Parse width}
                    Width := ParseNumber('Width');
                    {Correct dimension for frame and spacing}
                    TextWid := Width-4;
                  end;

                5 :          {INDEX}
                  if CurSect = 0 then
                    ErrorLine('INDEX statement must follow TOPIC statement')
                  else
                    IK^[CurSect] := ParseNumber('Index number');

                6 :          {NOINDEX}
                  if CurSect = 0 then
                    ErrorLine('NOINDEX statement must follow TOPIC statement')
                  else
                    IK^[CurSect] := $FFFF;

                7 :          {INCLUDE}
                  if IncLev = MaxIncludeNest then
                    Error('Too many nested files')
                  else begin
                    {Include file, get filename}
                    ParseWord(IncName, 79);
                    inc(IncLev);
                    OpenInf(IncName);
                    ScanFile;
                  end;

                 8 :         {WRAP}
                   Wrapping := True;

                 9 :         {NOWRAP}
                   Wrapping := False;
              else
                ErrorLine('Unrecognized directive');
              end;
            end;
          CommentMark :
            {Ignore line} ;
        else
          {A text line - wrap and output}
          LineOut;
        end;
      end;

      CloseInf;
    end;
  end;

  procedure ScanDone;
    {-Clean up when scan pass is done}
  begin
    with Hdr do begin
      {Finalize status}
      if Warnings <> 0 then begin
        Write(^M);
        ClrEol;
        WriteLn;
      end;
      WriteLn('Summary ..........');
      WriteLn(TotLines:6, ' total lines in help file');

      {Store last section}
      if SectLen > 0 then
        NewSection;
      {Assure output goes to disk}
      FlushBuffer;

      {Sort the topic map}
      Write('Sorting...');
      SortTopicMap;
      Write(^M);

      {Leave extra room for biggest section's decompression}
      Inc(BiggestTopic, 64);

      {Write the updated header and indexes}
      Reset(OutF, 1);
      WriteHeaders;
      Close(OutF);
    end;
  end;

  procedure ShowStats;
    {-Show some interesting statistics}
  begin
    with Hdr do begin
      WriteLn(HighestTopic:6, ' topic slots used');
      WriteLn(NamedTopics:6, ' indexed topics');
      WriteLn(BiggestTopic:6, ' bytes in largest topic (topic ', BiggestTopicSect, ')');
      WriteLn(MaxXrefs:6, ' most cross-refs in a topic (topic ', MaxXrefSect, ')'); {!!.08}
      WriteLn((HighestTopic*SizeOf(Word)):6, ' bytes in sorted topic map');
      WriteLn((HighestTopic*SizeOf(HelpIndexRec)):6, ' bytes in help index');
      WriteLn((HighestTopic*NameSize):6, ' bytes in topic name table');
      WriteLn(TotalSect:6, ' uncompressed help bytes');
      WriteLn(TotalComp:6, ' compressed help bytes');
      WriteLn((TotalComp/TotalSect):6:2, ' compression factor');
    end;
  end;

begin
  WriteCopyRight;

  Initialize;

  {Perform counting pass}
  CountFile;
  if Hdr.HighestTopic = 0 then
    Error('No help topics specified');

  {Allocate heap space for help indexes}
  AllocWorkSpace;

  {Build the xlate table for compression}
  FindMostFrequent;

  {Reserve disk space for help indexes}
  WriteHeaders;

  {Prepare to reread the input file}
  InitForScan;

  {Perform the word wrap pass}
  ScanFile;

  {Clean up when scan done}
  ScanDone;

  {Show a summary}
  ShowStats;
end.
