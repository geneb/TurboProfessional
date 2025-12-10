{$IFDEF Windows}
  !! ERROR - This unit is not compatible with Windows !!
{$ENDIF}

{$S-,R-,V-,I-,B-,F+}

{$IFNDEF Ver40}
  {$R-,O+,A-}
{$ENDIF}

{Conditional defines that may affect this unit}
{$I TPDEFINE.INC}

{*********************************************************}
{*                    TPDIR.PAS 5.22                     *}
{*     Copyright (c) TurboPower Software 1987, 1992.     *}
{* Portions Copyright (c) Sunny Hill Software 1985, 1986 *}
{*     and used under license to TurboPower Software     *}
{*                 All rights reserved.                  *}
{*********************************************************}

unit TpDir;
  {-Use a pick window to select a filename}

interface

uses
  Dos,
  TpInline,
  TpDos,
  TPString,
  TPCrt,
  TPWindow,
  {$IFDEF AllowDateTime}
  TpDate,
  {$ENDIF}
  TpPick;

const
  UseFileFrame : Boolean = True; {True to draw frame around pick window}
  SeparateDirs : Boolean = True; {True to sort dirs and files apart}
  DirsUpper : Boolean = True; {True to display directories uppercase}
  FilesUpper : Boolean = False; {True to display files uppercase}
  ShowExtension : Boolean = True; {True to display file extension as well as name}
  ReturnCompletePath : Boolean = True; {True to return complete pathnames for files}

  {$IFDEF AllowDateTime}
  ShowSizeDateTime : Boolean = False; {True to show size/date/time}
  SizeDisplay : (SizeNone,   {Don't display the file size}
    SizeBytes,               {Display size in bytes}
    SizeKBytes)              {Display size in kilobytes}
  = SizeBytes;
  DirDisplayStr : string[5] = '<dir>'; {Displayed in size column for subdirs}
  DatePicture : string[12] = 'Mm/dd/yy'; {Format for file date}
  TimePicture : string[12] = 'Hh:mmt'; {Format for file time}
  {$ENDIF}

  {--------------------------------------------------------------------}

function GetFileName
  (Mask : string;            {Search mask}
    FileAttr : Byte;         {Search attribute for files}
    XLow, YLow : Byte;       {Upper left corner of window, including frame}
    YHigh, PickCols : Byte;  {Lower row, and number of columns of files}
    Colors : PickColorArray; {Video attributes to use}
    var FileName : string    {Full path of selected file}
    ) : Word;
  {-Given a mask (which may or may not contain wildcards),
    popup a directory window, let user choose, and return pathname.
    Returns zero for success, non-zero for error.
    Error codes:
      0 = Success
      1 = Path not found
      2 = No matching files
      3 = New file
      4 = Insufficient memory
      5 = Won't fit on screen
      6 = No pick orientation !!.10
    else  Turbo critical error code
  }

function ChangeDirectory
  (Mask : string;           {New directory or mask}
   XLow, YLow : Byte;       {Upper left corner of window, including frame}
   YHigh, PickCols : Byte;  {Lower row, and number of columns of files}
   Colors : PickColorArray  {Video attributes to use}
   ) : Word;
 {-Given a mask (which may or may not contain wildcards),
   change to that directory and if a wildcard is specified,
   show the directories there and allow selection.
   If no error occurs, the current directory will be the
   final selection when the routine exits. The returned
   status word is a Turbo IoResult value, with the following
   exceptions:
      4 = Insufficient memory
      5 = Won't fit on screen
 }

function CompleteFileName(Name : string) : string;
  {-Convert a potentially relative file name into a complete one}

  {====================================================================}

implementation

const
  MaxFiles = 500;            {Absolute maximum number of files found in one directory}
  MaxNameLength = 12;        {Maximum length of a file name}
  ChDirMode : Boolean = False;   {True to activate special mode for ChDir}

type
  FileString = string[MaxNameLength]; {Room for just name and extension}
  DirRec =                   {Stores info about each file}
    record                   {Variably sized}
      dAttr : Byte;          {File attribute}
      dName : FileString;    {File name}
      dOther : string[60];   {Other information, like size/date/time}
    end;
  DirRecPtr = ^DirRec;

var
  F : Pointer;               {Pointer to file array}
  MaxNumFiles : Word;        {Maximum number of files we have memory space for}
  NumFiles : Word;           {Actual number of files found}
  Frec : SearchRec;          {Used in directory operations}
  ItemSize : Word;           {Size of each directory item}
  ItemWidth : Word;          {Width of each displayed item}
  NameWidth : Word;          {Width of filename}
  Pivot : DirRec;            {Used during sorting}

  function HasWildCards(Mask : string) : Boolean;
    {-Return true if Mask has DOS wildcards}
  begin
    Mask := JustFilename(Mask);
    HasWildCards := (pos('*', Mask) <> 0) or (pos('?', Mask) <> 0);
  end;

  function AddFilePath(Mask : string; FName : FileString) : string;
    {-Concatenate a filemask and filename}
  begin
    AddFilePath := AddBackSlash(Mask)+FName;
  end;

  function AddWildCard(Mask : string) : string;
    {-Add a default wild card to Mask if it needs it}
  begin
    if HasWildCards(Mask) then
      AddWildCard := Mask
    else
      AddWildCard := AddFilePath(Mask, '*.*');
  end;

  function CompletePath(Path : string) : string;
    {-Convert a potentially relative path into a complete one}
  var
    ColPos : Byte;
    DrNum : Byte;
    I : Word;
    SaveDir : string[80];
    CurDir : string[80];
  begin
    GetDir(0, CurDir);
    ColPos := pos(':', Path);
    if ColPos > 1 then begin
      {Get current directory on specified drive}
      DrNum := pos(Upcase(Path[ColPos-1]), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
      if DrNum = 0 then
        ColPos := 0
      else
        GetDir(DrNum, SaveDir);
    end;
    ChDir(Path);
    if IoResult = 0 then begin
      GetDir(0, Path);
      if ColPos > 1 then begin
        {Restore current directory on other drive}
        ChDir(SaveDir);
        {Watch out! ChDir may set IoResult}
        I := IoResult;
      end;
    end;
    ChDir(CurDir);
    CompletePath := Path;
  end;

  function SafeChDir(Path : string) : Word;
    {-Change to a directory, restoring current directory if error}
  var
    Status : Word;
    CurDir : string[79];
  begin
    GetDir(0, CurDir);
    ChDir(Path);
    Status := IoResult;
    if Status <> 0 then
      ChDir(CurDir);
    SafeChDir := Status;
  end;

  function CompleteFileName(Name : string) : string;
    {-Convert a potentially relative file name into a complete one}
  var
    JustName : string[13];
  begin
    JustName := JustFilename(Name);
    Name := CompletePath(JustPathname(Name));
    CompleteFileName := AddFilePath(Name, JustName);
  end;

  function MultiDirs(var Mask : string) : Boolean;
    {-Return true if Mask potentially specifies more than one directory}
  begin
    MultiDirs := (Length(Mask) = 0) or HasWildCards(Mask);
  end;

  function MultiFiles(var Mask, SearchMask, FileName : string;
                      FileAttr : Byte; var Status : Word) : Boolean;
    {-Return True if Mask potentially specifies more than one file}
  begin
    Status := 0;
    MultiFiles := True;
    if (Length(Mask) <> 0) and not HasWildCards(Mask) then begin
      FindFirst(SearchMask, FileAttr, Frec);
      case DosError of
        0 :                  {Files found, it is a subdirectory}
          Exit;
        3 :                  {Path not found, invalid subdirectory}
          begin
            {See if Mask itself is a valid path}
            FindFirst(Mask, FileAttr, Frec);
            case DosError of
              3 : Status := 1; {Path not found}
            else
              {New or existing file}
              if ReturnCompletePath then
                FileName := CompleteFileName(Mask)
              else
                FileName := Mask;
              if not ExistFile(FileName) then
                {New file}
                Status := 3;
            end;
          end;
        18 :                 {No more files, not a subdirectory}
          begin
            case Mask[Length(Mask)] of
              ':', '\' : Status := 2; {No matching files}
            else
              {New or existing file}
              if ReturnCompletePath then
                FileName := CompleteFileName(Mask)
              else
                FileName := Mask;
              if not ExistFile(FileName) then
                {New file}
                Status := 3;
            end;
          end;
      else
        Status := DosError; {DOS critical error}
      end;
      MultiFiles := False;
    end;
  end;

  function DirPtr(Item : Word) : DirRecPtr;
    {-Return pointer to directory item}
  type
    SO =
      record
        O : Word;
        S : Word;
      end;
  var
    P : Pointer;
  begin
    P := F;
    Inc(SO(P).O, ItemSize*(Item-1));
    DirPtr := P;
  end;

  function FindFiles(SearchMask : string; FileAttr : Byte) : Word;
    {-Add any matched files to File arrays}
  {$IFDEF AllowDateTime}
  const
    NP : array[SizeNone..SizeKBytes] of Byte = (3, 12, 10);
  {$ENDIF}
  var
    DT : DateTime;
    NextPos : Byte;
    TS : string[12];
  begin
    FindFirst(SearchMask, FileAttr, Frec);
    while (DosError = 0) and (NumFiles < MaxNumFiles) do begin
      with Frec do
        if Attr and VolumeID = 0 then
          if (Attr and Directory) = (FileAttr and Directory) then
            {Matches directory type}
            if Name <> '.' then begin
              Inc(NumFiles);
              if Attr and Directory = Directory then begin
                {It's a directory}
                if not DirsUpper then
                  Name := StLocase(Name);
              end else if not FilesUpper then
                Name := StLocase(Name);

              {Store information for display}
              with DirPtr(NumFiles)^ do begin
                dAttr := Attr;

                {$IFDEF AllowDateTime}
                if ShowSizeDateTime then begin

                  dName := Pad(Name, NameWidth);
                  dOther := CharStr(' ', ItemWidth-NameWidth);
                  NextPos := NP[SizeDisplay];

                  {Add size string}
                  if dAttr and Directory <> Directory then
                    case SizeDisplay of
                      SizeBytes :
                        begin
                          Str(Size:8, TS);
                          Move(TS[1], dOther[2], 8);
                        end;
                      SizeKBytes :
                        begin
                          if Size <> 0 then
                            Size := (Size shr 10)+1;
                          Str(Size:5, TS);
                          Move(TS[1], dOther[2], 5);
                          dOther[7] := 'k';
                        end;
                    end
                  else
                    {Subdirectory}
                    case SizeDisplay of
                      SizeBytes, SizeKBytes :
                        Move(DirDisplayStr[1],
                          dOther[NextPos-Length(DirDisplayStr)-2],
                          Length(DirDisplayStr));
                    end;

                  {Add date and time strings}
                  UnpackTime(Time, DT);
                  with DT do begin
                    if Length(DatePicture) <> 0 then begin
                      TS := DateToDateString(DatePicture, DMYtoDate(Day, Month, Year));
                      Move(TS[1], dOther[NextPos], Length(TS));
                      Inc(NextPos, 2+Length(DatePicture));
                    end;
                    if Length(TimePicture) <> 0 then begin
                      TS := TimeToTimeString(TimePicture, HMStoTime(Hour, Min, Sec));
                      Move(TS[1], dOther[NextPos], Length(TS));
                    end;
                  end;

                end else
                  {$ENDIF}
                  begin
                    dName := Name;
                    if dAttr and Directory = Directory then
                      dOther := '\'
                    else
                      dOther := ' ';
                  end;
              end;
            end;
      FindNext(Frec);
    end;

    case DosError of
      3, 18 : FindFiles := 0;
    else
      FindFiles := DosError;
    end;
  end;

  function Less(var X, Y : DirRec) : Boolean;
    {-Return true if X < Y}
  var
    Xdir : Boolean;
    Ydir : Boolean;
  begin
    Xdir := (X.dAttr and Directory = Directory);
    Ydir := (Y.dAttr and Directory = Directory);
    if not SeparateDirs or (Xdir = Ydir) then
      Less := (X.dName < Y.dName)
    else
      Less := Xdir;
  end;

  {$S+}                      {Catch stack overflow during recursive sort}
  procedure Sort(L, R : Word);
    {-Sort symbols by increasing address in range L to R}
  var
    I : Word;
    J : Word;
  begin
    I := L;
    J := R;
    Move(DirPtr((L+R) shr 1)^, Pivot, ItemSize);
    repeat
      while Less(DirPtr(I)^, Pivot) do
        Inc(I);
      while Less(Pivot, DirPtr(J)^) do
        Dec(J);
      if I <= J then begin
        {Swap elements I and J}
        ExchangeStructs(DirPtr(I)^, DirPtr(J)^, ItemSize);
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      Sort(L, J);
    if I < R then
      Sort(I, R);
  end;
  {$S-}

  function SendFileName(Item : Word) : string;
    {-Pass each file name to the pick unit}
  var
    F : FileString;
  begin
    with DirPtr(Item)^ do begin
      if ShowExtension or (dName = '..') then
        F := dName
      else begin
        {Trim off extension}
        F := ForceExtension(dName, '');
        Dec(F[0]);
        {$IFDEF AllowDateTime}
        if ShowSizeDateTime then
          F := Pad(F, NameWidth);
        {$ENDIF}
      end;
      SendFileName := ' '+F+dOther;
      if dAttr and Directory = Directory then
        AltPickAttr := True;
    end;
  end;

  function InitChoice : Word;
    {-Return index of first non-subdirectory choice}
  var
    Choice : Word;
  begin
    for Choice := 1 to NumFiles do
      if DirPtr(Choice)^.dAttr and Directory <> Directory then begin
        {First non-directory name}
        InitChoice := Choice;
        Exit;
      end;
    {All are directories}
    InitChoice := 1;
  end;

  function GetFileName
    (Mask : string;          {Search mask}
      FileAttr : Byte;       {Search attribute for files}
      XLow, YLow : Byte;     {Upper left corner of window, including frame}
      YHigh, PickCols : Byte; {Lower row, and number of columns of files}
      Colors : PickColorArray; {Video attributes to use}
      var FileName : string  {Selected filename}
      ) : Word;
  label
    ExitPoint;
  var
    Done : Boolean;
    XHigh : Byte;
    Choice : Word;
    Status : Word;
    BufBytes : Word;
    ItemDispWidth : Word;
    Correction : Integer;
    Memory : LongInt;
    SavePickMatrix : Byte;
    SearchMask : string[79];
    PathName : string[79];
    RelPathName : string[79];
    WildCard : FileString;
    Selected : FileString;
  begin
    {Assume success}
    GetFileName := 0;
    FileName := '';

    {Get the default searchmask}
    Mask := StUpCase(Mask);
    SearchMask := AddWildCard(Mask);

    if ChDirMode then begin
      if not MultiDirs(Mask) then begin
        GetFileName := SafeChDir(Mask);
        Exit;
      end;
    end else
      {See if mask specifies more than one file}
      if not MultiFiles(Mask, SearchMask, FileName, FileAttr, Status) then begin
        GetFileName := Status;
        Exit;
      end;

    {$IFDEF EnablePickOrientations}                 {!!.10}
    {Make sure a pick orientation was selected}     {!!.10}
    if PickOrientation = PickOrientNone then begin  {!!.10}
      GetFileName := 6;                             {!!.10}
      Exit;                                         {!!.10}
    end;                                            {!!.10}
    {$ENDIF}                                        {!!.10}

    {Choose the window width}
    if ShowExtension then
      NameWidth := MaxNameLength
    else
      NameWidth := 8;
    {$IFDEF AllowDateTime}
    if ShowSizeDateTime then begin
      ItemWidth := NameWidth+1;
      case SizeDisplay of
        SizeBytes :
          Inc(ItemWidth, 9);
        SizeKBytes :
          Inc(ItemWidth, 7);
      end;
      if Length(DatePicture) <> 0 then
        Inc(ItemWidth, 2+Length(DatePicture));
      if Length(TimePicture) <> 0 then
        Inc(ItemWidth, 2+Length(TimePicture));
    end else
      {$ENDIF}
      ItemWidth := NameWidth+2;
    if ShowExtension then
      ItemSize := ItemWidth+3
    else
      ItemSize := ItemWidth+7;
    ItemDispWidth := ItemWidth+1;

    if UseFileFrame then
      Correction := -1
    else
      Correction := +1;
    repeat
      if not UseFileFrame or (PickCols*ItemDispWidth > Length(SearchMask)+2) then
        {Filenames set the width limit}
        XHigh := XLow+PickCols*ItemDispWidth-Correction
      else
        {Search path sets the width limit}
        XHigh := XLow+Length(SearchMask)+2-Correction;
      if XHigh > ScreenWidth then
        XHigh := ScreenWidth;
      if PickCols*ItemDispWidth > XHigh-XLow+Correction then begin
        Dec(PickCols);
        Done := False;
      end else
        Done := True;
    until Done;

    if PickCols = 0 then begin
      {Won't fit on screen}
      GetFileName := 5;
      Exit;
    end;

    {Get space for file array - reserve space for popup window}
    BufBytes := 2*(YHigh-YLow+1)*(XHigh-XLow+1);
    Memory := MaxAvail-BufBytes-100;
    if Memory > MaxFiles*ItemSize then
      {Room for MaxFiles}
      MaxNumFiles := MaxFiles
    else begin
      {Limited space available}
      MaxNumFiles := Memory div ItemSize;
      if (Memory < 0) or (MaxNumFiles < 2) then begin
        GetFileName := 4;    {Insufficient memory}
        Exit;
      end;
    end;
    GetMem(F, MaxNumFiles*ItemSize);

    SavePickMatrix := PickMatrix;
    PickMatrix := PickCols;

    Done := False;
    repeat

      {Separate wildcard from pathname}
      WildCard := JustFilename(SearchMask);
      RelPathName := JustPathname(SearchMask);
      PathName := CompletePath(RelPathName);
      SearchMask := AddFilePath(PathName, WildCard);

      {Build the file array}
      NumFiles := 0;
      if ChDirMode then begin
        {First change to the directory}
        Status := SafeChDir(PathName);
        if Status = 0 then begin
          {Reinitialize relative pathname}
          GetDir(0, RelPathName);
          {Find only directories}
          Status := FindFiles(SearchMask, Directory);
        end;
      end else begin
        {Find non-subdirectories}
        Status := FindFiles(SearchMask, FileAttr and not Directory);
        {Find subdirectories}
        if Status = 0 then
          if (FileAttr and Directory) = Directory then
            Status := FindFiles(AddWildCard(PathName), FileAttr);
      end;
      if Status <> 0 then begin
        GetFileName := Status;
        goto ExitPoint;
      end;

      if NumFiles = 0 then begin
        {No matching files}
        Done := True;
        GetFileName := 2;

      end else begin
        {Sort the directory}
        Sort(1, NumFiles);

        {Pick from the directory}
        if SeparateDirs then
          Choice := InitChoice
        else
          Choice := 1;

        if PickWindow(@SendFileName, NumFiles, XLow, YLow, XHigh, YHigh, UseFileFrame,
          Colors, ' '+SearchMask+' ', Choice) then
          case PickCmdNum of
            PKSExit :        {Escape - return empty file name}
              Done := True;
            PKSSelect :      {Enter}
              with DirPtr(Choice)^ do begin
                Selected := TrimTrail(dName);
                if dAttr and Directory = Directory then begin
                  {Selected a subdirectory}
                  {!!.09 - use PathName rather than RelPathName}
                  Mask := AddFilePath(PathName, Selected);
                  SearchMask := AddFilePath(Mask, WildCard);
                end else begin
                  {Not a directory, return the filename}
                  if ReturnCompletePath then
                    FileName := AddFilePath(PathName, StUpCase(Selected))
                  else
                    FileName := AddFilePath(RelPathName, StUpCase(Selected));
                  {Assure no default extension will be added}
                  if Length(JustExtension(FileName)) = 0 then
                    FileName := FileName+'.';
                  Done := True;
                end;
              end;
          else
            {Some other exit key - caller can check PickChar}
            Done := True;
            {!!.12} {Return filename even for user exit commands}
            with DirPtr(Choice)^ do begin
              Selected := StUpcase(TrimTrail(dName));
              if ReturnCompletePath then
                FileName := AddFilePath(PathName, Selected)
              else
                FileName := AddFilePath(RelPathName, Selected);
              if Length(JustExtension(FileName)) = 0 then
                FileName := FileName+'.';
            end;
          end
        else begin
          {Error occurred in PickWindow - most likely insufficient memory}
          GetFileName := 4;
          Done := True;
        end;
      end;
    until Done;

ExitPoint:
    PickMatrix := SavePickMatrix;

    {Free the memory space used for file array}
    FreeMem(F, MaxNumFiles*ItemSize);
  end;

  function ChangeDirectory
    (Mask : string;           {New directory or mask}
     XLow, YLow : Byte;       {Upper left corner of window, including frame}
     YHigh, PickCols : Byte;  {Lower row, and number of columns of files}
     Colors : PickColorArray  {Video attributes to use}
     ) : Word;
  var
    FileName : string[79];
  begin
    ChDirMode := True;
    ChangeDirectory := GetFileName(Mask, Directory,
                                   XLow, YLow, YHigh, PickCols,
                                   Colors, FileName);
    ChDirMode := False;
  end;

end.
