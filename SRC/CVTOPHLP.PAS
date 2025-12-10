{*********************************************************}
{*                  CvtOpHlp.PAS 1.00                    *}
{*        Copyright (c) TurboPower Software 1993.        *}
{*                 All rights reserved.                  *}
{*            Written by: Julian M. Bucknall             *}
{*********************************************************}

{$A+,B-,F+,G+,I-,R-,S-,V-}

program CvtOpHlp;
  {-Convert Object (& Turbo) Professional's help text files to other formats}



{---------------------------------------------------------------------
NOTES:
  - This program can only be compiled with Turbo Pascal 6.0 and Borland
    Pascal 7.0 (real or protected mode).
  - This program can be compiled with either Object Professional or
    Turbo Professional - see the UseOPRO directive below.
  - At the time of writing CvtOpHlp only supports conversion of OPRO
    and TPRO help text files to Borland's THelp text format and to
    Ron Loewy's Help Development Toolkit (HLPDK) format. No other help
    text formats are being considered at this time. The input file(s)
    *must* be valid, in the sense that they can be compiled with
    MAKEHELP without errors.
  - The Help Development Toolkit is supported only as a step towards
    creating a Windows 3.1 help file. HLPDK's HELPC compiler has
    *only* been used to create an RTF file to be fed into Microsoft's
    HC31 help compiler. Output from this conversion utility has *not*
    been used with HELPC to create any other help text format.
  - Conceptually the data flow is as follows for creating a Borland
    THelp help file:
                      OPRO help text
                            |
                        (CvtOpHlp)
                            V
                     THelp help text
                            |
                         (HL.EXE)
                            V
                     THelp help file
  - Conceptually the data flow is as follows for creating a Windows
    WINHELP help file:
                       OPRO help text
                            |
                        (CvtOpHlp)
                            V
                      HLPDK help text
                            |
                        (HELPC.EXE)
                            V
                    RTF Help text file
                            |
                        (HC31.EXE)
                            V
                     Windows help file
  - The syntax for calling CvtOpHelp is as follows:
       CVTOPHLP options inputfile [outputfile]
    The only options allowed are -B (convert to Borland's THelp
    format) or -H (convert to HLPDK format). -B is assumed. The
    parameter 'inputfile' is the name of the input text file, possibly
    with path. 'outputfile', if given, is the name of the converted
    text file, possibly with path. If it isn't explicitly given, it
    will have the same name as the input file but with an 'OUT'
    extension and will be in the same directory.
  - This program works better if it has a response file to work from.
    This text file contains two sets of information: data that cannot
    be gleaned from OPRO's help text files, and topic title fixes to
    avoid clashes (OPRO and TPRO use discrete numeric topics, other
    formats use discrete topic names).
    The additional data uses lines in the following format:
       !IDENTIFIER some string value
    for example
       !DESCRIPTION Object Professional Help System
    There are six separate identifiers: !VERSION (the version number
    of the help text), !DESCRIPTION (a short description of the help
    text), !TITLE (the help text title), !TITLEATTR (the HLPDK
    TITLEATTR value), !LOPARA (the HLPDK general paragraph value for
    ATTRDEFAULTS), !HIPARA (the HLPDK paragraph value for highlit
    paragraphs - not supported at this time). Only the first three
    are used in the conversion to THelp format, all six are used by
    conversion to HLPDK format.
    The topic title fixes have the form
       9999 A new title for topic number 9999 to avoid clashes
    for example if the original !TOPIC line in the OPRO help text read
       !TOPIC 152 Init
    then a fix for this (there are bound to be many topics with Init
    as their title) would be
       152 Init,MyNewObject
  - The response file has the same name as the input file, but with
    extension RSP. It must be in the input file's directory.
  - When converting to THelp format the comma in a topic title is
    treated specially. Firstly the SCREEN name is the full title. Next
    two INDEX lines are created, one for the text up to the comma, and
    the other for the full title. Finally a SCREENTAG is created with
    the text after the comma, followed by a period, followed by the
    text up to the comma. An example will make this clear. Suppose the
    original topic was:
       !TOPIC 152 Init,MyNewObject
         ...text...
    then CvtOpHlp will create the following THelp SCREEN:
       ;SCREEN Init,MyNewObject
         ...text...
       ;KEYWORD Xxx
       ;SCREENTAG MyNewObject.Init
       ;INDEX Init
       ;INDEX Init,MyNewObject
       ;ENDSCREEN
    This mimics the way that the Borland IDE help files have been
    created.
  - A table of contents screen is always created with those topics
    that don't have the !NOINDEX line. Its name will use the !TITLE
    line in the response file.
  - For topics containing line draw characters that must be converted
    to Windows format (via HLPDK format), the original help text must
    contain a ;!TABLE line before the offending text. This is because
    (a) Windows help does not support line draw characters (CvtOpHlp
    will translate these characters to +, - and |), and (b) having
    this keyword makes identification of such tables easier to do, and
    hence make the conversion faster.
  - Once a help text file has been converted to THelp format, the
    Borland Help Compiler is called with a command line of the form:
      HL -e100 -x -i -p -oHelpFileName TextFileName
    The -p option is only required for Pascal help files. See the
    Borland Open Architecture Handbook for details on the other
    options (you need this anyway, as buying it is how you get the
    help compiler).
  - Note that HELPC always recreates a HPJ file when used with the
    /W31 switch. The one field in this you need to change is the
    TITLE= line, before compiling with HC31.

Final note! This program was developed in-house at TurboPower Software
for the single, express purpose of converting its products' help files
into help files for Borland's IDE and for Windows. This design brief
meant that we could tune the program for the way that we wrote the
original help text. Other styles of help text authoring *may* produce
funny/silly/just-plain-weird pages for these help programs: caveat
emptor.

We are releasing this program's source code into the public domain as
a service to our customers. You may use it as you see fit, and
distribute it for free (or a small disk duplication charge of less
than $10). You may not sell either the source code or a program
compiled from the source code. TurboPower Software retain all
copyright in this source code, and the executable built from it.

This program is provided on an as is basis, without support. If you do
find a bug in it, or you would like a new feature built into it,
please let us know. You can contact us via our forum on PCVENB section
6 on CompuServe, by direct e-mail to [100116,1572], by fax on (719)
260-7151, or by voice on (719) 260-6641.
----------------------------------------------------------------------}


{Undefine this compiler directive if you wish to use TPRO units}
{$DEFINE UseOPRO}


uses
  Dos,
  Objects,
{$IFDEF UseOPRO}
  OpString,
  OpDOS;
{$ELSE}
  TpString,
  TpDOS;
{$ENDIF}

const
  MaxNestingLevel = 2;          {Maximum nesting of include files}
  StartTopicsInDict = 1024;     {Starting size of the topic dictionary - MUST be a power of 2}

  VersionStr = '1.00';          {Version of this program}

  MinLD = #176;
  MaxLD = #223;
  LineDraw : array [MinLD..MaxLD] of char
           = '|||||||++||+++++++-|-+||++--|-+----++++++++|-||-';

type
  MetaCmd = (mcNone, mcBias, mcTopic, mcInc,
             mcNoWrap, mcWrap, mcNoIndex, mcLine,
             mcTable,
             mcLast);

  FileArray = array [0..MaxNestingLevel] of text;
  NameArray = array [0..MaxNestingLevel] of PathStr;
  LineArray = array [0..MaxNestingLevel] of longint;

  PTopic = ^TTopic;
  TTopic = record
    Num : word;
    Name: PString;
  end;

  PTopicPage = ^TTopicPage;
  TTopicPage = array [0..$3FFE] of PTopic;

  PTopicDict = ^TTopicDict;
  TTopicDict = object
    TopicCount : integer;
    Dict : PTopicPage;
    DSiz : integer;
    constructor Init;
    destructor Done; virtual;
    function  FindTopicName(var Title : string) : boolean;
    function  GetText(Index : integer) : string;
    procedure Insert(Topic : word; Title : string);
    function  Search(Topic : word; var Index : integer) : boolean;
    procedure PrintOut;
  end;

  PKeyword = ^TKeyword;
  TKeyword = record
    KW  : PString;
    Next: PKeyword;
  end;

  PKeywordQ = ^TKeywordQ;
  TKeywordQ = object
    Head : PKeyword;
    Tail : PKeyword;
    constructor Init;
    destructor Done;
    procedure Add(Keyword : string);
    function Delete : string;
    function IsEmpty : boolean;
  end;

  PTableOfContents = ^TTableOfContents;
  TTableOfContents = object(TStringCollection)
    LastIndex : integer;
    procedure Insert(Item : pointer); virtual;
    procedure RemoveLastItem;
  end;

var
  IOerror     : integer;          {saved IOresult value}

  Nest        : integer;          {current nesting level}
  InputBuffer : pointer;          {the input text buffer}
  InBufSize   : word;             {... and its size}
  OutputBuffer: pointer;          {the output text buffer}
  OutBufSize  : word;             {... and its size}
  InputPath   : PathStr;          {input file path}
  FN          : NameArray;        {input file names}
  InF         : FileArray;        {input file & include files}
  LA          : LineArray;        {current lines array}
  OutName     : PathStr;          {output file name}
  OutF        : text;             {output file}
  CvtToHDK    : boolean;          {create an HLPDK compatible file}
  CvtToTHelp  : boolean;          {create a THelp compatible file}

  TD          : PTopicDict;       {the topic dictionary}
  Bias        : word;             {the current topic number bias}
  TopicNames  : PStringCollection;{the topic names in alpha order}
  TOC         : PTableOfContents; {the topics in the table of contents}

  AmWrapping  : boolean;          {true if we're currently wrapping text}
  AmInTopic   : boolean;          {true if we're converting a topic}
  LookingForParagraph : boolean;  {true if we're looking for a new paragraph}
  LookingForEndPara   : boolean;  {true if we're looking for the end of a paragraph}
  InDataTable         : boolean;  {true if we're in a data table}

  CrtNewFix  : boolean;          {true if we've created a new fix file}
  NewFixName : PathStr;          {the name of the fix file}
  NewFix     : text;             {the new fix file variable}

                                  {These values come from the response file}
  TextVersion : string[10];       {the version number of the help text}
  TextDesc    : string[30];       {a brief description of the help system}
  TextTitle   : string[30];       {a brief title for the help system}
  HDKTitleAttr: string[80];       {the topic title attributes}
  HDKLoPara   : string[80];       {attributes for normal paragraphs}
  HDKHiPara   : string[80];       {attributes for highlit paragraphs}

  CurrentTopicIndex : integer;  {index of current topic in dictionary}
  CurrentKeywordQ   : PKeywordQ;{keywords for the current topic}
  CurrentKeyword    : string;   {the keyword for the current hotlink}

{---Helpful routines---}
procedure Abort(Msg : string);
  begin
    writeln;
    writeln('**ERROR: ', Msg);
    writeln('      at ', FN[Nest], ':', LA[Nest]);
    Halt(1);
  end;

procedure Warning(Msg : string);
  begin
    writeln;
    writeln('--WARNING: ', Msg);
    writeln('        at ', FN[Nest], ':', LA[Nest]);
  end;

procedure IOAbort;
  const
    ErrorMsg : array [1..26] of string[31] =
             ('Invalid function number',         'File not found',
              'Path not found',                  'Too many open files',
              'File access denied',              'Invalid file handle',
              'Disk read error',                 'Disk write error',
              'File not assigned',               'File not open',
              'File not open for input',         'File not open for output',
              'Invalid numeric format',          'Disk is write-protected',
              'Unknown unit',                    'Drive not ready',
              'Unknown command',                 'CRC error in data',
              'Bad drive request struct length', 'Disk seek error',
              'Unknown media type',              'Sector Not Found',
              'Printer out of paper',            'Device write fault',
              'Device read fault',               'Hardware failure');
  var
    Msg : string[31];
  begin
    case IOerror of
      1..6     : Msg := ErrorMsg[IOerror];
      100..106 : Msg := ErrorMsg[IOerror - 100+7];  {ie 7..13}
      150..162 : Msg := ErrorMsg[IOerror - 150+14]; {ie 14..26}
    else
      Msg := 'Unknown error ' + Long2Str(IOError);
    end;
    Abort(Msg);
  end;

function IOfailed : boolean;
  {-save and check IOresult}
  begin
    IOerror := IOresult;
    IOfailed := (IOerror <> 0);
  end;

procedure ShowCopyright;
  begin
    writeln('CvtOpHlp - Convert Object Professional help text files to other formats');
    writeln('           Version ', VersionStr);
    writeln('           Copyright (c) 1993, TurboPower Software');
    writeln;
  end;

procedure ShowSyntax;
  begin
    writeln('Syntax:');
    writeln('  CVTOPHLP [options] inputfile [outputfile]');
    writeln;
    writeln('where inputfile is the name of a valid text file that MAKEHELP can compile');
    writeln('      outputfile is the name of the converted help text file');
    writeln('                 (defaults to inputfile with extension OUT)');
    writeln('      options are:');
    writeln('         -B to create a Borland THelp text file (DEFAULT)');
    writeln('         -H to create a HLPDK compatible text file');
    Halt(1);
  end;

function IsDigit(Ch : char) : boolean;
  begin
    IsDigit := ('0' <= Ch) and (Ch <= '9');
  end;

{---Topic Dictionary routines---}
constructor TTopicDict.Init;
  {-creates a dictionary of topic numbers and titles}
  begin
    GetMem(Dict, sizeof(PTopic)*StartTopicsInDict);
    if (Dict = nil) then Fail;
    DSiz := StartTopicsInDict;
    TopicCount := 0;
  end;
{--------}
destructor TTopicDict.Done;
  {-destroys the topic dictionary}
  var
    i : integer;
  begin
    if (Dict <> nil) then
      begin
        if (TopicCount <> 0) then
          for i := 0 to TopicCount-1 do
            begin
              DisposeStr(Dict^[i]^.Name);
              Dispose(Dict^[i]);
            end;
        FreeMem(Dict, sizeof(PTopic)*DSiz);
      end;
  end;
{--------}
function  TTopicDict.FindTopicName(var Title : string) : boolean;
  {-given a topic title, returns true if it is in the dictionary}
  var
    Index : integer;
    UpperTitle : string;
  begin
    UpperTitle := StUpCase(Title);
    FindTopicName := TopicNames^.Search(@UpperTitle, Index);
  end;
{--------}
function  TTopicDict.GetText(Index : integer) : string;
  {-given an index to a topic, returns the title}
  begin
    if (0 <= Index) and (Index < TopicCount) then
      GetText := Dict^[Index]^.Name^;
  end;
{--------}
procedure TTopicDict.Insert(Topic : word; Title : string);
  {-inserts a new topic into the dictionary, returns the index}
  var
    T       : PTopic;
    i       : integer;
    Index   : integer;
    NewSize : integer;
    NewDict : PTopicPage;
    TempSt  : PString;
  begin
    TOC^.LastIndex := -1;

    if (Title = '') then Exit;

    for i := 1 to length(Title) do
      if (Title[i] = ' ') then
        Title[i] := '_';
    if FindTopicName(Title) then
      begin
        if not CrtNewFix then
          begin
            Assign(NewFix, NewFixName);
            Rewrite(NewFix);
            if IOfailed then IOAbort;
            CrtNewFix := true;
          end;
        writeln(NewFix, Topic:5, ' ', Title, ',', FN[Nest], '/', LA[Nest]);
        Exit;
      end;

    if Search(Topic, Index) then
      T := Dict^[Index]
    else
      begin
        if (TopicCount = DSiz) then
          begin
            {Dictionary is full: create another array, copy over
             current contents, dispose of old array}
            if (DSiz = 8192) then
              NewSize := 16383
            else if (DSiz = 16383) then
              Abort('Dictionary cannot be expanded')
            else
              NewSize := DSiz * 2;
            GetMem(NewDict, sizeof(PTopic)*NewSize);
            if (NewDict = nil) then
              Abort('Out of memory when expanding Dictionary');
            Move(Dict^, NewDict^, sizeof(PTopic)*DSiz);
            FreeMem(Dict, sizeof(PTopic)*DSiz);
            Dict := NewDict;
            DSiz := NewSize;
          end;
        if (Index <> TopicCount) then
          Move(Dict^[Index], Dict^[Index+1],
               sizeof(PTopic)*(TopicCount-Index));
        T := New(PTopic);
        if (T = nil) then
          Abort('Out of memory when creating new topic');
        T^.Num := Topic;
        T^.Name := NewStr(Title);
        if (T^.Name = nil) then
          Abort('Out of memory when creating new topic''s name');
        Dict^[Index] := T;
        inc(TopicCount);
        {Save name for alpha search}
        TempSt := NewStr(StUpCase(Title));
        if (TempSt = nil) then
          Abort('Out of memory when inserting topic title into list');
        TopicNames^.Insert(TempSt);
      end;
    TOC^.Insert(T^.Name);
  end;
{--------}
function TTopicDict.Search(Topic : word; var Index : integer) : boolean;
  {-searches the dictionary for a topic and returns its index if found}
  var
    L, R, M  : integer;
    CurTopic : word;
  begin
    if (TopicCount = 0) then
      begin
        Search := false;
        Index := 0;
      end
    else
      begin
        L := 0; R := TopicCount-1;
        repeat
          M := (L + R) shr 1;
          CurTopic := Dict^[M]^.Num;
          if (Topic < CurTopic) then
               R := M - 1
          else L := M + 1;
        until (Topic = CurTopic) or (L > R);
        if (Topic > CurTopic) then
          inc(M);
        Index := M;
        Search := Topic = CurTopic;
      end;
  end;
{--------}
procedure TTopicDict.PrintOut;
  {-a debug method that writes out all topics and titles}
  var
    i : integer;
  begin
    for i := 0 to TopicCount-1 do
      writeln(Dict^[i]^.Num:5, ' - ', GetText(i));
  end;
{---------------------------------------------------------------------}


{---Keyword queue routines---}
constructor TKeywordQ.Init;
  {-Initialises a KEYWORD queue for THelp conversion}
  begin
    New(Head);
    if (Head = nil) then Fail;
    Head^.Next := Head;
    Tail := Head;
  end;
{--------}
destructor TKeywordQ.Done;
  {-Destroys the KEYWORD queue}
  var
    S : string;
  begin
    while not IsEmpty do S := Delete;
    Dispose(Head);
  end;
{--------}
procedure TKeywordQ.Add(Keyword : string);
  {-Adds a keyword to the tail of the KEYWORD queue}
  var
    Node : PKeyword;
  begin
    New(Node);
    if (Node = nil) then
      Abort('Out of memory creating new node for keyword queue');
    Node^.Next := Tail^.Next;
    Tail^.Next := Node;
    Tail := Node;
    Node^.KW := NewStr(Keyword);
    if (Node^.KW = nil) then
      Abort('Out of memory adding keyword to queue');
  end;
{--------}
function TKeywordQ.Delete : string;
  {-Returns the top KEYWORD from the queue, after popping it}
  var
    Node : PKeyword;
  begin
    Node := Head^.Next;
    Delete := Node^.KW^;
    Head^.Next := Node^.Next;
    DisposeStr(Node^.KW);
    Dispose(Node);
    if IsEmpty then
      Tail := Head;
  end;
{--------}
function TKeywordQ.IsEmpty : boolean;
  {-Returns true if the queue is empty}
  begin
    IsEmpty := Head^.Next = Head;
  end;
{---------------------------------------------------------------------}


{---Table of Contents stuff---}
procedure TTableOfContents.Insert(Item : pointer);
  {-inserts a new topic into the Table of Contents}
  var
    I : integer;
  begin
    if not Search(KeyOf(Item), I) then
      AtInsert(I, Item);
    LastIndex := I;
  end;
{--------}
procedure TTableOfContents.RemoveLastItem;
  {-deletes the last topic inserted - a !NOINDEX was found}
  begin
    { NOT AtFree: the string belongs to the topic dictionary }
    if (LastIndex <> -1) then
      AtDelete(LastIndex);
  end;
{---------------------------------------------------------------------}


{---File handling stuff---}
procedure FlushTextIn(var F : Text);
  {-Flush text file opened for reading}
  type
    LH = record L, H : Word; end;
  var
    Bytes : LongInt;
    Regs : Registers;
  begin
    with TextRec(F), Regs do
      begin
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

procedure OpenInputFile;
  {-Opens the file at nesting level Nest}
  begin
    if (Nest > 0) then
      FlushTextIn(InF[Nest-1]);
    LA[Nest] := 0;
    Assign(InF[Nest], FN[Nest]);
    Reset(InF[Nest]);
    if IOfailed then IOAbort;
    write(^M, CharStr(' ', 79));
    SetTextBuf(InF[Nest], InputBuffer^, InBufSize);
  end;

procedure CloseInputFile;
  {-Closes the file at nesting level Nest}
  begin
    Close(InF[Nest]);
    if IOfailed then IOAbort;
    if (Nest > 0) then
      SetTextBuf(InF[Nest-1], InputBuffer^, InBufSize);
  end;

procedure OpenOutputFile;
  {-Opens the output file}
  begin
    Assign(OutF, OutName);
    Rewrite(OutF);
    if IOfailed then IOAbort;
    SetTextBuf(OutF, OutputBuffer^, OutBufSize);
  end;

procedure CloseOutputFile;
  {-Closes the output file}
  begin
    Close(OutF);
    if IOfailed then IOAbort;
  end;



function ClassifyMetaCommand(var Line : string) : MetaCmd;
  {-Converts a string beginning with ! to a meta command}
  const
    MetaCmdStr : array [MetaCmd] of string[9] =
                 ('', 'BIAS', 'TOPIC', 'INCLUDE',
                      'NOWRAP', 'WRAP', 'NOINDEX', 'LINE',
                      '!TABLE',
                  '');
  var
    PosBlank : integer;
    M        : MetaCmd;
    St : string[9];
  begin
    PosBlank := Pos(' ', Line);
    if (PosBlank = 0) then
      PosBlank := length(Line)+1;
    St := Copy(Line, 2, PosBlank-2);
    for M := mcNone to mcLast do
      if St = MetaCmdStr[M] then
        begin
          ClassifyMetaCommand := M;
          Exit;
        end;
    ClassifyMetaCommand := mcNone
  end;

procedure Initialise;
  {-Initialise various global variables}
  begin
    Nest := 0;
    Bias := 0;

    TextVersion := '0.00';
    TextDesc := '--UNKNOWN--';
    TextTitle := '--UNKNOWN--';
    HDKTitleAttr := '';
    HDKLoPara := '';
    HDKHiPara := '';

    FillChar(FN, sizeof(FN), 0);
    FillChar(InF, sizeof(InF), 0);
    FillChar(LA, sizeof(LA), 0);

    FillChar(OutF, sizeof(OutF), 0);
    FillChar(OutName, sizeof(OutName), 0);

    InBufSize := 2048;
    GetMem(InputBuffer, InBufSize);
    OutBufSize := 0;
    {###}
  end;

procedure ReadCommandLine;
  {-Read the command line, looking for options and filenames}
  procedure ParamError(Msg : string);
    begin
      writeln('**ERROR: ', Msg);
      ShowSyntax;
      Halt(1);
    end;
  var
    i     : word;
    Param : string;
    FName : PathStr;
    Name  : NameStr;
    Ext   : ExtStr;
  begin
    CvtToHDK := false;
    CvtToTHelp := true;
    for i := 1 to ParamCount do
      begin
        Param := ParamStr(i);
        if (Param[1] = '-') or (Param[1] = '/') then
          begin
            if (length(Param) <> 2) then
              ParamError('invalid option');
            case upcase(Param[2]) of
              'B' : begin
                      CvtToHDK := false;
                      CvtToTHelp := true;
                    end;
              'H' : begin
                      CvtToHDK := true;
                      CvtToTHelp := false;
                    end;
            else
              ParamError('unknown option');
            end;{case}
          end
        else {first char of Param is not - or /, it's a file name}
          begin
            FName := StUpCase(CleanPathName(Param));
            if (FN[Nest] = '') then
              begin
                FN[Nest] := FExpand(FName);
                FSplit(FN[Nest], InputPath, Name, Ext);
              end
            else if (OutName = '') then
              OutName := FExpand(FName)
            else
              ParamError('too many file names on command line');
          end;
      end;
    if (FN[Nest] = '') then
      ParamError('input file name not specified');
    if (OutName = '') then
      OutName := ForceExtension(FN[Nest], 'OUT');
  end;

procedure ReadResponseFile(var F : text);
  {-Read any fixes to topic names from the response file}
  var
    PosBlank : integer;
    ec       : integer;
    Topic    : word;
    Key      : String[15];
    Line     : string;
  begin
    {Lines in the response file consist of:
       ; Some comment or other text to be ignored
       9999 A new title for topic number 9999 to avoid clashes
       !VERSION 9.99                  <-- version number of the help
       !DESCRIPTION a short description of the help text
       !TITLE the help text title
       !TITLEATTR XXXX                <-- HLPDK TITLEATTR line
       !LOPARA XXXX                   <-- HLPDK general paragraph line
       !HIPARA XXXX                   <-- HLPDK highlit paragraph line
     Ignore all text errors}
    repeat
      readln(F, Line);
      if IOfailed then IOAbort;
      if (length(Line) > 0) then
        if (Line[1] = '!') then
          begin
            PosBlank := Pos(' ', Line);
            Key := StUpCase(Copy(Line, 2, PosBlank-2));
            if (Key = 'VERSION') then
              TextVersion := Copy(Line, PosBlank+1, 255)
            else if (Key = 'DESCRIPTION') then
              TextDesc := Copy(Line, PosBlank+1, 255)
            else if (Key = 'TITLE') then
              TextTitle := Copy(Line, PosBlank+1, 255);
            if CvtToHDK then
              begin
                if (Key = 'TITLEATTR') then
                  HDKTitleAttr := Copy(Line, PosBlank+1, 255)
                else if (Key = 'LOPARA') then
                  HDKLoPara := Copy(Line, PosBlank+1, 255)
                else if (Key = 'HIPARA') then
                  HDKHiPara := Copy(Line, PosBlank+1, 255);
              end
          end
        else if (Line[1] <> ';') then
          begin
            PosBlank := Pos(' ', Line);
            if (0 < PosBlank) and (PosBlank <= 6) then
              begin
                Val(Copy(Line, 1, PosBlank-1), Topic, ec);
                if (ec = 0) then
                  TD^.Insert(Topic, Trim(Copy(Line, PosBlank+1, 255)));
              end;
          end;
    until EOF(F);
  end;

function GetBias(var Line : string) : word;
  {-From an input !BIAS text line, get the bias value}
  var
    PosBlank : integer;
    ec       : integer;
    Value    : word;
  begin
    PosBlank := Pos(' ', Line);
    if (PosBlank > 0) then
      begin
        Val(Copy(Line, PosBlank+1, 255), Value, ec);
        if (ec = 0) then
          Bias := Value;
      end;
  end;

function ExtractTopicNumber(var Line : string) : word;
  {-gets the topic num from !TOPIC line, returns Line as the topic title}
  var
    i, ec : integer;
    Topic : word;
  begin
    {the topic number begins at character 8: eg !TOPIC 999}
    ExtractTopicNumber := $FFFF;
    i := 8;
    while IsDigit(Line[i]) do
      inc(i);
    if (i = 8) then
      Warning('Invalid !TOPIC line found')
    else
      begin
        Val(Copy(Line, 8, i-8), Topic, ec);
        if (ec <> 0) then
          Warning('Invalid !TOPIC number found (too large?)')
        else
          begin
            ExtractTopicNumber := Topic;
            Delete(Line, 1, i);
          end;
      end;
  end;

procedure InsertNewTopic(var Line : string);
  {-Inserts a new topic and title into the dictionary}
  var
    Topic : word;
  begin
    Topic := ExtractTopicNumber(Line);
    if (Topic <> $FFFF) then
      TD^.Insert(Topic+Bias, Trim(Line));
  end;


{---The Borland THELP conversion routines---}
procedure thFinishOffPreviousTopic;
  {-For THELP: closes off the previous topic screen, ready for a new one}
  var
    CommaPos: integer;
    St      : string;
    Keyword : string;
  begin
    with CurrentKeywordQ^ do
      while not IsEmpty do
        writeln(OutF, ';KEYWORD ', Delete);
    St := TD^.GetText(CurrentTopicIndex);
    CommaPos := Pos(',', St);
    if (CommaPos > 0) then
      begin
        writeln(OutF, ';SCREENTAG ', Copy(St, CommaPos+1, 255), '.',
                                     Copy(St, 1, CommaPos-1));
        writeln(OutF, ';INDEX ', Copy(St, 1, CommaPos-1));
      end;
    writeln(OutF, ';INDEX ', St);
    writeln(OutF, ';ENDSCREEN');
    writeln(OutF);
    if IOfailed then IOAbort;
  end;

procedure thConvertNewTopic(var Line : string);
  {-for THELP: convert OPRO help topic header into THELP header}
  var
    Topic : word;
  begin
    Topic := ExtractTopicNumber(Line);
    if (Topic <> $FFFF) then
      begin
        if AmInTopic then
          begin
            thFinishOffPreviousTopic;
          end;
        if not TD^.Search(Topic, CurrentTopicIndex) then
          Abort('A topic number has gone missing from the dictionary');
        writeln(OutF, ';SCREEN ', TD^.GetText(CurrentTopicIndex));
        writeln(OutF, ' ', Line, ' '#220);
        writeln(OutF, ' ', CharStr(#223, length(Line)+2));
        if IOfailed then IOAbort;
        AmInTopic := true;
      end;
  end;

procedure thOutputTextLine(var Line : string);
  {-for THELP: convert OPRO text line into THELP text line}
  var
    Topic      : word;
    Index,
    ec,
    InInx,
    OutInx,
    StartDigit : integer;
    OutLine : string;
  begin
    if AmWrapping then
         OutLine := ''
    else OutLine := ' ';
    OutInx := length(OutLine);
    InInx := 0;
    while (InInx < length(Line)) do
      begin
        inc(InInx);
        case Line[InInx] of
          ^A, ^B, ^C :
            begin
              inc(OutInx);
              OutLine[OutInx] := ^E;
            end;
          ^D :
            begin
              inc(InInx);
              StartDigit := InInx;
              while IsDigit(Line[InInx]) do
                inc(InInx);
              Val(Copy(Line, StartDigit, InInx-StartDigit), Topic, ec);
              if TD^.Search(Topic, Index) then
                CurrentKeywordQ^.Add(TD^.GetText(Index));
              inc(OutInx);
              OutLine[OutInx] := ^B;
            end;
          ^E :
            begin
              inc(OutInx);
              OutLine[OutInx] := ^B;
            end;
        else
          inc(OutInx);
          OutLine[OutInx] := Line[InInx];
        end;{case}
      end;
    OutLine[0] := char(OutInx);
    writeln(OutF, OutLine);
    if IOfailed then IOAbort;
  end;

procedure thCreateTOCScreen;
  {-For THELP: Creates the MAININDEX screen}
  var
    Index : integer;
    St : string;
  begin
    for Index := 1 to length(TextTitle) do
      if (TextTitle[Index] = ' ') then
        TextTitle[Index] := '_';

    writeln(OutF, ';SCREEN Index');
    writeln(OutF, ' ', TextTitle, ' '#220);
    writeln(OutF, ' ', CharStr(#223, length(TextTitle)+2));
    writeln(OutF);
    for Index := 0 to TOC^.Count-1 do
      begin
        St := PString(TOC^.At(Index))^;
        writeln(OutF, '  '^B, St, ^B);
        CurrentKeywordQ^.Add(St);
      end;
    with CurrentKeywordQ^ do
      while not IsEmpty do
        writeln(OutF, ';KEYWORD ', Delete);
    writeln(OutF, ';INDEX ', TextTitle);
    writeln(OutF, ';MAININDEX');
    writeln(OutF, ';ENDSCREEN');
    writeln(OutF);
    if IOfailed then IOAbort;
  end;


{---The HLPDK conversion routines---}
procedure hdTranslateLines(var Line : string);
  {-For HLPDK: converts linedraw characters}
  var
    i : integer;
    Ch: char;
  begin
    for i := 1 to length(Line) do
      begin
        Ch := Line[i];
        if (MinLD <= Ch) and (Ch <= MaxLD) then
          Line[i] := LineDraw[Ch];
      end;
  end;

function hdCheckForHotkeyTable(var Line : string) : boolean;
  {-Check whether Line is a line from a hot key table}
  var
    i : integer;
    BlanksSoFar   : boolean;
    Found1stCtrlE,
    Found2ndCtrlE : boolean;
  begin
    {Our OPRO help text hotlink tables cause problems in Windows
     because we line columns up with spaces. In a proportional
     font this is a no-no. We shall rewrite the hotlink table as a
     one-link-per-line table, but first we have to identify a
     line as a line in a hotlink table.
     A line in a hot key table must satisfy one of two conditions:
      - the first char is ' ', and the first non blank char is ^D
      - there must be at least 2 hot links in it and there must be
        just spaces between the hot links.
     These conditions satisfy both lines that are continuations of
     a hotlink table, and also first lines of hotlink tables that
     start with 'See also' (or something similar).}

    {Assume false for now.}
    hdCheckForHotkeyTable := false;

    {See if we can find (a) ^D as the first nonblank char after some
     blanks, or 2 ^E characters}
    i := 0;
    BlanksSoFar := true;
    Found1stCtrlE := false;
    Found2ndCtrlE := false;
    while (i < length(Line)) and (not Found2ndCtrlE) do
      begin
        inc(i);
        if (Line[i] <> ' ') then
          begin
            if BlanksSoFar and (i > 1) and (Line[i] = ^D) then
              begin
                hdCheckForHotkeyTable := true;
                Exit;
              end;
            BlanksSoFar := false;
            if (Line[i] = ^E) then
              if Found1stCtrlE then
                   Found2ndCtrlE := true
              else Found1stCtrlE := true;
          end;
      end;
    {Is there a hot link here in this line? If no, exit}
    if not Found2ndCtrlE then
      Exit;
    {At this point i points to the second ^E of the first hotlink,
     search for the next non blank character}
    inc(i);
    while (i <= length(Line)) and (Line[i] = ' ') do
      inc(i);
    {If the next non-blank char was not ^D then this wasn't a table}
    if (i > length(Line)) or (Line[i] <> ^D) then
      Exit;
    {if this point is reached, we have two hot links in a row}
    hdCheckForHotkeyTable := true;
  end;
{--------}
procedure hdFinishOffPreviousTopic;
  {-for HLPDK: completes a previously started topic}
  var
    Keyword : string;
  begin
    if LookingForEndPara then
      begin
        LookingForEndPara := false;
        if AmWrapping then
          begin
            writeln(OutF, '.END-PARAGRAPH');
            if IOfailed then IOAbort;
          end;
        LookingForParagraph := true;
      end;
    writeln(OutF, '.END-ENTRY');
    writeln(OutF);
    if IOfailed then IOAbort;
  end;

procedure hdConvertNewTopic(var Line : string);
  {-for HLPDK: convert OPRO help topic header into THELP header}
  var
    Topic : word;
  begin
    Topic := ExtractTopicNumber(Line);
    if (Topic <> $FFFF) then
      begin
        if AmInTopic then
          begin
            hdFinishOffPreviousTopic;
          end;
        if not TD^.Search(Topic, CurrentTopicIndex) then
          Abort('A topic number has gone missing from the dictionary');
        writeln(OutF, '.ENTRY ', TD^.GetText(CurrentTopicIndex));
        writeln(OutF, '.TITLE ', Line);
        if IOfailed then IOAbort;
        AmInTopic := true;
      end;
  end;
{--------}
procedure hdOutputHotKeyLine(var Line : string);
  {-for HLPDK: convert line of OPRO hot key table into HDK format}
  var
    Topic      : word;
    Index,
    ec,
    InInx,
    OutInx,
    StartDigit : integer;
    FirstLink : boolean;
    BlanksPrecede1stLink : boolean;
    OutLine : string;
  begin
    OutInx := 0;
    InInx := 0;
    FirstLink := true;
    BlanksPrecede1stLink := true;
    while (InInx < length(Line)) do
      begin
        inc(InInx);
        case Line[InInx] of
          ^A, ^B, ^C :
            begin
              {do nothing - don't even transfer them}
            end;
          ^D :
            begin
              if (not FirstLink) or (not BlanksPrecede1stLink) then
                begin
                  OutLine[0] := char(OutInx);
                  writeln(OutF, OutLine);
                  if IOfailed then IOAbort;
                end;
              FirstLink := false;
              OutLine[1] := ' ';
              OutLine[2] := ' ';
              OutInx := 2;
              inc(InInx);
              StartDigit := InInx;
              while IsDigit(Line[InInx]) do
                inc(InInx);
              Val(Copy(Line, StartDigit, InInx-StartDigit), Topic, ec);
              if TD^.Search(Topic, Index) then
                CurrentKeyword := TD^.GetText(Index);
              inc(OutInx);
              OutLine[OutInx] := '~';
            end;
          ^E :
            begin
              inc(OutInx);
              OutLine[OutInx] := '~';
              for Index := 1 to length(CurrentKeyword) do
                begin
                  inc(OutInx);
                  OutLine[OutInx] := CurrentKeyword[Index];
                end;
              inc(OutInx);
              OutLine[OutInx] := '~';
            end;
        else
          inc(OutInx);
          OutLine[OutInx] := Line[InInx];
          if FirstLink and (Line[InInx] <> ' ') then
            BlanksPrecede1stLink := false;
        end;{case}
      end;
    OutLine[0] := char(OutInx);
    writeln(OutF, OutLine);
    if IOfailed then IOAbort;
  end;
{--------}
procedure hdOutputTextLine(var Line : string);
  {-for HLPDK: convert OPRO text line into HDK text line}

  {WARNING - this code is NOT for the faint-hearted}

  var
    Topic      : word;
    Index,
    ec,
    InInx,
    OutInx,
    StartDigit : integer;
    LineIsInHotkeyTable : boolean;
    OutLine : string;
  begin
    LineIsInHotkeyTable := false;

    {Check for end of current paragraph}
    if LookingForEndPara then
      if (length(Line) = 0) or (Line[1] = ' ') then
        begin
          LookingForEndPara := false;
          if AmWrapping then
            begin
              writeln(OutF, '.END-PARAGRAPH');
              if IOfailed then IOAbort;
            end;
          LookingForParagraph := true;
        end;

    {Check for start of new paragraph}
    if LookingForParagraph then
      begin
        LineIsInHotkeyTable := hdCheckForHotKeyTable(Line);
        if (not LineIsInHotKeyTable) and
           (length(Line) > 0) and (Line[1] <> ' ') then
          begin
            LookingForParagraph := false;
            if AmWrapping then
              begin
                writeln(OutF, '.PARAGRAPH');
                if IOfailed then IOAbort;
              end;
            LookingForEndPara := true;
          end;
      end;

    if InDataTable then
      begin
        writeln(OutF, '.PARAGRAPH FONT 8');
        if IOfailed then IOAbort;
        hdTranslateLines(Line);
      end;


    if LineIsInHotKeyTable then
      hdOutputHotKeyLine(Line)
    else
      begin
        OutInx := 0;
        InInx := 0;
        while (InInx < length(Line)) do
          begin
            inc(InInx);
            case Line[InInx] of
              ^A, ^B, ^C :
                begin
                  {do nothing}
                end;
              ^D :
                begin
                  inc(InInx);
                  StartDigit := InInx;
                  while IsDigit(Line[InInx]) do
                    inc(InInx);
                  Val(Copy(Line, StartDigit, InInx-StartDigit), Topic, ec);
                  if TD^.Search(Topic, Index) then
                    CurrentKeyword := TD^.GetText(Index);
                  inc(OutInx);
                  OutLine[OutInx] := '~';
                end;
              ^E :
                begin
                  inc(OutInx);
                  OutLine[OutInx] := '~';
                  for Index := 1 to length(CurrentKeyword) do
                    begin
                      inc(OutInx);
                      OutLine[OutInx] := CurrentKeyword[Index];
                    end;
                  inc(OutInx);
                  OutLine[OutInx] := '~';
                end;
            else
              inc(OutInx);
              OutLine[OutInx] := Line[InInx];
            end;{case}
          end;
        OutLine[0] := char(OutInx);
        writeln(OutF, OutLine);
        if IOfailed then IOAbort;
      end;

    if InDataTable then
      begin
        writeln(OutF, '.END-PARAGRAPH');
        if IOfailed then IOAbort;
      end;

  end;

procedure hdCreateTOCScreen;
  {-For HLPDK: creates the Windows Table of Contents page}
  var
    Index : integer;
    St : string;
  begin
    writeln(OutF, '.ENTRY Overview');
    writeln(OutF, '.TITLE ', TextTitle, ' Table of Contents');
    writeln(OutF);
    for Index := 0 to TOC^.Count-1 do
      begin
        St := PString(TOC^.At(Index))^;
        writeln(OutF, '  ~', St, '~', St, '~');
      end;
    writeln(OutF, '.END-ENTRY');
    writeln(OutF);
    if IOfailed then IOAbort;
  end;



procedure StartNewIncludeFile(var Line : string);
  {-Get the include file name from a !INCLUDE line, open it}
  var
    PosBlank : integer;
    FName    : PathStr;
    Path     : PathStr;
    Name     : NameStr;
    Ext      : ExtStr;
  begin
    if (Nest = MaxNestingLevel) then
      begin
        Warning('Too many include file nesting levels');
        Exit;
      end;
    PosBlank := Pos(' ', Line);
    if (PosBlank = 0) then Exit;
    FName := StUpCase(CleanPathName(Copy(Line, PosBlank+1, 255)));
    FSplit(FName, Path, Name, Ext);
    if (Path = '') then
      FName := InputPath + Name + Ext;
    if ExistFile(FName) then
      begin
        inc(Nest);
        FN[Nest] := FName;
        OpenInputFile;
      end
    else
      begin
        Warning('Missing include file: ' + FName);
      end;
  end;

function ReadNextLine(var Line : string) : boolean;
  {-Reads the next line from the current input file (ignores comments,
    except if the comment starts with ;! in which case the semicolon
    is replaced by a !, and the line is returned)}
  var
    FileExhausted,
    RunOutOfLines : boolean;
  begin
    repeat
      FileExhausted := false;
      RunOutOfLines := false;
      repeat
        if EOF(InF[Nest]) then
          FileExhausted := true
        else
          begin
            readln(InF[Nest], Line);
            if IOfailed then IOAbort;
            inc(LA[Nest]);
            if ((LA[Nest] and $0F) = 0) then
              write(^M, FN[Nest], ':', LA[Nest]);
            if (length(Line) > 2) and
               (Line[1] = ';') and (Line[2] = '!') then
              Line[1] := '!';
          end;
      until FileExhausted or (length(Line) = 0) or (Line[1] <> ';');
      if FileExhausted then {ie reached EOF}
        begin
          writeln(^M, FN[Nest], ':', LA[Nest]);
          if (Nest = 0) then
            RunOutOfLines := true
          else
            begin
              CloseInputFile;
              dec(Nest);
              Line := ';';
            end;
        end;
    until RunOutOfLines or (length(Line) = 0) or (Line[1] <> ';');
    ReadNextLine := not RunOutOfLines;
  end;

procedure PrepareForPass1;
  {-Prepare for Pass1: open the input file, create the dictionary}
  var
    RSPName : PathStr;            {the name of the response file}
    RSP : text;                   {the file variable}
  begin
    TD := New(PTopicDict, Init);
    if (TD = nil) then Abort('Cannot create dictionary');

    TOC := New(PTableOfContents, Init(50, 20));
    if (TOC = nil) then Abort('Cannot create table of contents');

    TopicNames := New(PStringCollection, Init(1000, 500));
    if (TopicNames = nil) then Abort('Cannot create topic names list');

    RSPName := ForceExtension(FN[Nest], 'RSP');
    if ExistFile(RSPName) then
      begin
        writeln('Reading response file: ', RSPName);
        Assign(RSP, RSPName);
        Reset(RSP);
        if IOfailed then IOAbort;
        ReadResponseFile(RSP);
        Close(RSP);
        if IOfailed then IOAbort;
        writeln('..Done');
      end;

    CrtNewFix := false;
    NewFixName := ForceExtension(FN[Nest], 'NFX');

    OpenInputFile;
  end;

procedure PrepareForPass2;
  {-Prepare for Pass2: reset the input file, open the output file}
  begin
    OutBufSize := 2048;
    GetMem(OutputBuffer, OutBufSize);
    OpenInputFile;
    OpenOutputFile;
    if CvtToTHelp then
      begin
        writeln(OutF, ';STAMP TURBO PASCAL HELP FILE.');
        writeln(OutF, ';SIGNATURE $*$* &&&&$*$');
        writeln(OutF, ';VERSION ', TextVersion);
       {writeln(OutF, ';CASESENSE'); <== required for C/C++ help text}
        writeln(OutF, ';DESCRIPTION ', TextDesc);

        writeln(OutF, ';COMMENT   Created by CvtOpHlp version ', VersionStr);
        writeln(OutF, ';COMMENT   Input file: ', FN[0]);
        writeln(OutF, ';COMMENT   CvtOpHlp is Copyright (c) 1993, TurboPower Software');

        writeln(OutF);

        {For some reason not explicitly spelt out in the manual, the
         first screen in a THELP file must be a dummy}
        writeln(OutF, ';SCREEN dummy');
        writeln(OutF, 'Nothing important');
        writeln(OutF, ';ENDSCREEN');

        writeln(OutF);
        if IOfailed then IOAbort;
        CurrentKeywordQ := New(PKeywordQ, Init);
        if (CurrentKeywordQ = nil) then
          Abort('Out of memory when creating the keyword queue');

        thCreateTOCscreen;
        TOC^.DeleteAll;
        Dispose(TOC, Done);
      end
    else if CvtToHDK then
      begin
        writeln(OutF, TextDesc);
        writeln(OutF, 'Version ', TextVersion);

        writeln(OutF, 'Created by CvtOpHlp version ', VersionStr);
        writeln(OutF, 'Input file: ', FN[0]);
        writeln(OutF, 'CvtOpHlp is Copyright (c) 1993, TurboPower Software');

        writeln(OutF);

        if (HDKTitleAttr <> '') then
          begin
            writeln(OutF, '.TITLEDEFAULTS ', HDKTitleAttr);
            writeln(OutF);
          end;

        if (HDKLoPara <> '') then
          begin
            writeln(OutF, '.ATTRDEFAULTS ', HDKLoPara);
            writeln(OutF);
          end;

        writeln(OutF);
        if IOfailed then IOAbort;
        LookingForParagraph := true;
        LookingForEndPara := false;

        hdCreateTOCScreen;
        TOC^.DeleteAll;
        Dispose(TOC, Done);
      end;
    AmWrapping := false;
    AmInTopic := false;
  end;

procedure FillTopicDictionary;
  {-Reads the input file (and include files) for !TOPIC keywords}
  var
    StillReading : boolean;
    Cmd          : MetaCmd;
    Line         : string;
  begin
    writeln;
    writeln('Pass 1: reading topic numbers and names');
    StillReading := true;
    while StillReading do
      begin
        if not ReadNextLine(Line) then
          StillReading := false
        else
          if (length(Line) > 0) and (Line[1] = '!') then
            begin
              Cmd := ClassifyMetaCommand(Line);
              case Cmd of
                mcBias : Bias := GetBias(Line);
                mcTopic: InsertNewTopic(Line);
                mcInc  : StartNewIncludeFile(Line);
                mcNoIndex : TOC^.RemoveLastItem;
              else
                {ignore others}
              end;{case}
            end;
      end;
    writeln('..Done');
  end;

procedure ConvertToTHelp;
  {-Reads the input file (and include files) and converts to THelp text}
  var
    StillReading : boolean;
    Cmd          : MetaCmd;
    Line         : string;
  begin
    writeln;
    writeln('Pass 2: converting to THelp text format');
    StillReading := true;
    while StillReading do
      begin
        if not ReadNextLine(Line) then
          StillReading := false
        else
          if (length(Line) > 0) and (Line[1] = '!') then
            begin
              Cmd := ClassifyMetaCommand(Line);
              case Cmd of
                mcBias  : Bias := GetBias(Line);
                mcTopic : thConvertNewTopic(Line);
                mcInc   : StartNewIncludeFile(Line);
                mcNoWrap: AmWrapping := false;
                mcWrap  : AmWrapping := true;
              else
                {ignore others}
              end;{case}
            end
          else
            thOutputTextLine(Line);
      end;
    if AmInTopic then
      begin
        thFinishOffPreviousTopic;
      end;
    Dispose(CurrentKeywordQ, Done);
    writeln('..Done');
  end;

procedure ConvertToHDK;
  {-Reads the input file (and include files) and converts to HDK text}
  var
    StillReading : boolean;
    Cmd          : MetaCmd;
    Line         : string;
  begin
    writeln;
    writeln('Pass 2: converting to HLPDK text format');
    StillReading := true;
    while StillReading do
      begin
        if not ReadNextLine(Line) then
          StillReading := false
        else
          if (length(Line) > 0) and (Line[1] = '!') then
            begin
              Cmd := ClassifyMetaCommand(Line);
              case Cmd of
                mcBias  : Bias := GetBias(Line);
                mcTopic : hdConvertNewTopic(Line);
                mcInc   : StartNewIncludeFile(Line);
                mcNoWrap: AmWrapping := false;
                mcWrap  : begin
                            LookingForParagraph := true;
                            LookingForEndPara   := false;
                            AmWrapping := true;
                            InDataTable := false;
                          end;
                mcLine  : begin
                            Line := '';
                            hdOutputTextLine(Line);
                          end;
                mcTable : begin
                            InDataTable := true;
                            LookingForParagraph := false;
                            LookingForEndPara   := false;
                            AmWrapping := false;
                          end;
              else
                {ignore others}
              end;{case}
            end
          else
            hdOutputTextLine(Line);
      end;
    if AmInTopic then
      begin
        hdFinishOffPreviousTopic;
      end;
    writeln('..Done');
  end;

begin
  {Use StdOut so that redirection can occur}
  Assign(Output, '');
  Rewrite(Output);

  ShowCopyright;

  Initialise;
  ReadCommandLine;

  {Open the input file, create topic dictionary, read response file}
  PrepareForPass1;

  {Read input file (and includes), filling topic dictionary}
  FillTopicDictionary;

  {Dispose of the topic name list and all who sail in her}
  Dispose(TopicNames, Done);

  {Check whether we've had any problems with duplicate topic titles}
  if CrtNewFix then
    begin
      Close(NewFix);
      if IOfailed then {nothing};
      writeln('--WARNING. There were some duplicate topic titles in the text.');
      writeln('A log file has been created with the topic numbers and titles.');
      writeln('Its name is ', NewFixName);
      writeln
    end
  else
    begin
      {Reset the input file at the start, open the output file}
      PrepareForPass2;

      {Scan through the input file, convert to other format and write }
      if CvtToTHelp then
        ConvertToTHelp
      else if CvtToHDK then
        ConvertToHDK;

      CloseOutputFile;
    end;

  CloseInputFile;

  {TD^.PrintOut; debug purposes}
  Dispose(TD, Done);

  {Get rid of our text buffers}
  FreeMem(InputBuffer, InBufSize);
  if (OutBufSize <> 0) then
    FreeMem(OutputBuffer, OutBufSize);
end.
