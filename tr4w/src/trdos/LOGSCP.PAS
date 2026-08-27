{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit LogSCP;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  utils_text,
  utils_file,
  Windows,
  Messages,
  Classes,
  uCallSignRoutines,
  uCTYDAT,
  //Country9,
  Tree {, Crt, DOS},
  uTR4WStrings;

const
  ua4wliscpconst                        = 4;

  ASCIIFileName                         = 'TRMASTER.ASC'; { ASCII file used for making changes }
  //n6tr  BufferArraySize                       = 65000; { Largest cell that can be read in }

    {ua4wli}
  BufferArraySize                       = 65000 * ua4wliscpconst; { Largest cell that can be read in }

  TempFileName                          = 'TEMPDTA.TMP';
  AVeryBigNumber                        = 1000000000;
  MaxBlocks                             = 10;
  MaximumPossibleCalls                  = 50;
  MemoryBlockSize                       = 65000 * ua4wliscpconst;
  MaximumCallsAlreadSaved               = 3000;

type
  EntryArrayType = array[0..300] of AnsiChar;
  EntryArrayPtr = ^EntryArrayType;

  CallsAlreadySavedArray = array[0..MaximumCallsAlreadSaved - 1] of CallString;
  CallsAlreadySavedArrayPtr = ^CallsAlreadySavedArray;

  PossibleCallActionType = (AnyCall, OnlyCallsWithNames, LogOnly); {KK1L: 6.69 added LogOnly}

  PossibleCallEntry = record
    Call: CallString;
    Dupe: boolean;
  end;

  PossibleCallRecord = record
    NumberPossibleCalls: integer;
    List: array[0..MaximumPossibleCalls - 1] of PossibleCallEntry;
    CursorPosition: integer;
  end;

  DataListEntryPointer = ^DataListEntryRecord;

  DataListEntryRecord = record
    data: DataBaseEntryRecord;
    NextEntry: DataListEntryPointer;
  end;

  MemoryBlock = array[0..MemoryBlockSize - 1] of Byte;
  MemoryBlockPtr = ^MemoryBlock;

  BufferArray = array[0..BufferArraySize - 1] of AnsiChar;
  BufferPtr = ^BufferArray;

  CellBufferObject = object
    MaximumMemoryToUse: LONGINT; { TR should set this to a low # }
    ReadAddress: LONGINT;
    MemoryAllocated: LONGINT;
    Key: Str20;

    NumberBufferEntries: LONGINT;

    Buffer1Bytes: LONGINT;
    Buffer2Bytes: LONGINT;
    Buffer3Bytes: LONGINT;

    Buffer1: BufferPtr;
    Buffer2: BufferPtr;
    Buffer3: BufferPtr;

    Buffer1Used: boolean;
    Buffer2Used: boolean;
    Buffer3Used: boolean;

    procedure FigureOutBufferSizes(NumberBytes: LONGINT);
    function GetNextEntry(var EntryString: ShortString {string}): boolean;
    function GetNextEntryAddress(var EntryAddress: Pointer): boolean;
    procedure Initialize(var NumberBytes: LONGINT);
    procedure GoAway;
    procedure LoadCellIntoBuffer(KeyString: CallString; {var } FileRead: HWND {file}; NumberBytes: LONGINT);
  end;

  PartialCallListEntryPtr = ^PartialCallListEntryType;

  PartialCallListEntryType = record
    Call: CallString;
    NextEntry: PartialCallListEntryPtr;
  end;

  BytesWrittenArrayPtr = ^SCPIndexArrayType;

  CallDatabase = object
    ActiveASCIIFileName: Str80; { For ASCII file }
    ActiveFilename: FileNameType {str80}; { Database filename }

    ASCIIFileCrunchCallToRemove: CallString;
    ASCIIFileCrunchRead: Text;
    ASCIIFileCrunchWrite: Text;
    ASCIIFileIsCurrent: boolean; { Handy if successive AddEntries }

    CellBuffer: CellBufferObject; { The big and great File Buffer }
    CountryString: Str80;

    DTAFileSize: LONGINT;

    DeleteCallList: array[0..19] of CallString;
    MasterFileExists: boolean;
    NumberDeleteCalls: integer;

    { Used by TransferMergeDataToASCIIFile to delete some calls }

    EntryPointerList: EntryPointerListPtr;

    FirstMergeDataListEntry: DataListEntryPointer;

    IndexArrayAllocated: boolean;

    InitialPartialCall: CallString;
    InitialPartialList: PartialCallListEntryPtr;

    LastCallRecord: DataBaseEntryRecord;
    LastPartialCall: CallString;
    LastPartialList: PartialCallListEntryPtr;

    MemoryBlocks: array[0..MaxBlocks - 1] of MemoryBlockPtr;
    NumberEntries: LONGINT;

    SectionOverwrite: boolean;
    CQZoneOverwrite: boolean;
    FOCOverwrite: boolean;
    GridOverwrite: boolean;
    HitsOverwrite: boolean;
    ITUZoneOverwrite: boolean;
    CheckOverwrite: boolean;
    NameOverwrite: boolean;
    OldCallOverwrite: boolean;
    QTHOverwrite: boolean;
    SpeedOverwrite: boolean;
    TenTenOverwrite: boolean;
    User1Overwrite: boolean;
    User2Overwrite: boolean;
    User3Overwrite: boolean;
    User4Overwrite: boolean;
    User5Overwrite: boolean;

    PossibleCallAction: PossibleCallActionType;

    SCPDisabledByApplication: boolean; { If TRUE - memory deallocated }

    SCPIndexArray: SCPIndexArrayPtr; { Table of cell addresses }
    SCPEndOfFile: LONGINT; { Address for end of last entry }
    WorkingDirectory: Str40;

    TRMasterFileRead: HWND {file};
    TRMasterFileOpen: boolean;

    procedure AddInBytes(NumberBytes, X, Y: integer);
    procedure AddRecordToMergeList(data: DataBaseEntryRecord);
    procedure ASCIIFileEditor;
    function BestTwoLetters(Partial: CallString): Str20;
    procedure BlowAwayFirstLettersList;
    procedure CheckDTAFile;
    procedure ClearDataEntry(var data: DataBaseEntryRecord);
    procedure ClearField;
    procedure DeleteLowHitCalls;

    function FirstCellForThisCall(Call: CallString; X, Y: integer): boolean;

    procedure GeneratePossibleCallList(Call: CallString);

    procedure GetBestOffsets(Call: CallString;
      var StartingOffset, EndingOffset: LONGINT;
      var X, Y: integer);

    function GetEntry(Call: CallString; var data: DataBaseEntryRecord): boolean;
    function GetCodeSpeed(Call: CallString): integer;
    procedure GetDataFromASCIIEntry(FileString: ShortString; var data: DataBaseEntryRecord; Ignore: Char);
    function GetFOCNumber(Call: CallString): CallString;
    function GetName(Call: CallString): CallString;
//    function GetNextPartialCall: CallString;
    procedure GetNextPartialCall(var Call: CallString);
    function GetRandomCall: CallString; { Use this one }

    function GoodCountry(Call: CallString): boolean;
    function RandomCall: CallString; { Might get FOC number calls }

    function LoadInIndexArray: boolean;

    procedure MergeArrays(var FirstArray: EntryArrayPtr;
      var SecondArray: EntryArrayPtr;
      var OutputArray: EntryArrayPtr);

    procedure MovePossibleCallsFromBufferIntoCallList(Call: CallString);
    procedure NewTwoLetters(PartialCall: CallString {Str20});
    function NumberOfBytesAtThisAddress(TwoLetters: Str20): LONGINT;
    function OverwriteFlagStatus: boolean;
    procedure ParseEntryToDataRecord(EntryString: ShortString {string}; var DataRecord: DataBaseEntryRecord);

    procedure PushChar(InChar: Char; var BlockNumber: Word; var BlockAddress: Word);

    function PartialCallSetup(PartialCall: CallString): boolean;

    procedure SaveCallsAndNamesToFile(FileName: string);
    procedure SaveDataToASCIIFile(var FileWrite: Text; NewData: DataBaseEntryRecord);
    procedure SaveToASCIIFile;

    procedure SCPDisableAndDeAllocateFileBuffer;

    procedure ShowStatistics;
    procedure TransferNewData(OldData: DataBaseEntryRecord; var NewData: DataBaseEntryRecord);

    { Iterates every entry in TRMASTER.DTA and collects non-empty operator
      names (uppercased) into Names.  Uses a private file handle so it does
      not disturb the shared TRMasterFileRead state used by SCP lookups. }
    procedure BuildOperatorNameSet(Names: TStringList);
  end;

const
  PossibleCallActionTypeStringArray     : array[PossibleCallActionType] of PAnsiChar =
    (
    'ALL',
    'NAMES',
    'LOG ONLY'
    );

var
  CD                                    : CallDatabase {=


 };
  CallsAlreadySaved                     : CallsAlreadySavedArrayPtr;
  NumberCallsAlreadySaved               : integer;
  PossibleCallList                      : PossibleCallRecord {= (NumberPossibleCalls: 0)};

  { Sorted list of unique operator names (uppercased) built from TRMASTER.DTA.
    Nil until InitOperatorNameSet is called.  Supports fast binary-search
    lookups via NameInOperatorSet. }
  OperatorNameSet                       : TStringList;

procedure InitOperatorNameSet;
function NameInOperatorSet(const AName: string): Boolean;

function GetRandomLetter: Char;
function GetRandomNumber: Char;

implementation
uses LogWind,
  uMaster,
  MainUnit,
  SysUtils;

function DoubleIndexCall(Call: CallString): boolean;

begin
  while length(Call) >= 3 do
     begin
     if pos(Copy(Call, 1, 2), Copy(Call, 2, length(Call) - 1)) > 0 then
        begin
        DoubleIndexCall := True;
        Exit;
        end;

     Delete(Call, 1, 1);
     end;

  DoubleIndexCall := False;
end;

procedure CellBufferObject.Initialize(var NumberBytes: LONGINT);
begin
  if MaximumMemoryToUse = 3 * BufferArraySize then { POST mode }
     begin
     if MemoryAllocated = 0 then
        begin
        //{WLI}            IF MaxAvail > BufferArraySize THEN
    begin
      Buffer1Used := True;
      New(Buffer1);
    end;

        //{WLI}            IF MaxAvail > BufferArraySize THEN
    begin
      Buffer2Used := True;
      New(Buffer2);
    end;

        //{WLI}            IF MaxAvail > BufferArraySize THEN
    begin
      Buffer3Used := True;
      New(Buffer3);
    end;
        end;

     MemoryAllocated := 3 * BufferArraySize;
     end

  else { TR has set the max memory to something else }
     begin
     if MemoryAllocated > 0 then
        begin
        FreeMem(Buffer1, MemoryAllocated);
        end;
       {wli ������ 216 �� FreeMem}
     if (NumberBytes > MaximumMemoryToUse) or
       (NumberBytes < 0) then
        begin
        NumberBytes := MaximumMemoryToUse;
        end;

       { Runtime error 201 here with K5KG - 0D73:0139 }

    //{WLI}        IF NumberBytes < MaxAvail THEN
     begin
       GetMem(Buffer1, NumberBytes);
       MemoryAllocated := NumberBytes;
     end
       //{WLI}        ELSE
       //{WLI}            MemoryAllocated := 0;
     end;

  Key := '';
  NumberBufferEntries := 0;
  Buffer1Bytes := 0;
  Buffer2Bytes := 0;
  Buffer3Bytes := 0;
end;

procedure CellBufferObject.GoAway;

begin
  if MaximumMemoryToUse = 3 * BufferArraySize then { Post mode }
     begin
     if MemoryAllocated > 0 then
        begin
        if Buffer1Used then
           begin
           Dispose(Buffer1);
           end;
        if Buffer2Used then
           begin
           Dispose(Buffer2);
           end;
        if Buffer3Used then
           begin
           Dispose(Buffer3);
           end;

        Buffer1Used := False;
        Buffer2Used := False;
        Buffer3Used := False;
        end;
     end
  else
    if MemoryAllocated > 0 then
       begin
       FreeMem(Buffer1, MemoryAllocated);
       end;

  MemoryAllocated := 0;
  Key := '';
  NumberBufferEntries := 0;
  Buffer1Bytes := 0;
  Buffer2Bytes := 0;
  Buffer3Bytes := 0;
end;

procedure CellBufferObject.FigureOutBufferSizes(NumberBytes: LONGINT);

begin
  Buffer2Bytes := 0;
  Buffer3Bytes := 0;

  if NumberBytes > BufferArraySize then
     begin
     Buffer1Bytes := BufferArraySize;

     NumberBytes := NumberBytes - BufferArraySize;

     if NumberBytes > BufferArraySize then
        begin
        Buffer2Bytes := BufferArraySize;
        NumberBytes := NumberBytes - BufferArraySize;

        if NumberBytes > BufferArraySize then
           begin
           //{WLI}                ReportError ('This cell is too big!');
     logger.Fatal('In FigureOutBufferSizes, the cell is too big');
     halt;
           end
        else
           begin
           Buffer3Bytes := NumberBytes;
           end;

        end
     else
        begin
        Buffer2Bytes := NumberBytes;
        end;
     end
  else
     begin
     Buffer1Bytes := NumberBytes;
     end;

end;

procedure CellBufferObject.LoadCellIntoBuffer(KeyString: CallString;
  {var }FileRead: HWND {file};
  NumberBytes: LONGINT);

var
  BytesRead                             : integer {WORD} {WLI};

begin
  Initialize(NumberBytes);

  if MaximumMemoryToUse <= BufferArraySize then { TR mode }
     begin
     sReadFile(FileRead, Buffer1^, NumberBytes);
 //    BlockRead(FileRead, Buffer1^, NumberBytes, BytesRead);
     Key := KeyString;
     NumberBufferEntries := NumberBytes;
     ReadAddress := 0;
     Exit;
     end;

  FigureOutBufferSizes(NumberBytes);

  if (Buffer1Bytes > 0) and Buffer1Used then
     begin
     sReadFile(FileRead, Buffer1^, Buffer1Bytes);

     if BytesRead < Buffer1Bytes then
        begin
        //{WLI}            ReportError ('File read error!!  Line #721 in LOGSCP.PAS.');
    halt;
        end;
     end;

  if (Buffer2Bytes > 0) and Buffer2Used then
     begin
     sReadFile(FileRead, Buffer2^, Buffer2Bytes);

     if BytesRead < Buffer2Bytes then
        begin
        //                 ReportError ('File read error!!  Line #721 in LOGSCP.PAS.');
    halt;
        end;
     end;

  if (Buffer3Bytes > 0) and Buffer3Used then
     begin
     sReadFile(FileRead, Buffer3^, Buffer3Bytes);

     if BytesRead < Buffer3Bytes then
        begin
        //{WLI}            ReportError ('File read error!!  Line #721 in LOGSCP.PAS.');
    halt;
        end;
     end;

  Key := KeyString;
  NumberBufferEntries := NumberBytes;
  ReadAddress := 0;
end;

function CellBufferObject.GetNextEntry(var EntryString: ShortString {string}): boolean;

{ Returns FALSE when no more entries left in the cell buffer }

var
  CellChar                              : AnsiChar;

begin
  EntryString := '';

  while ReadAddress <= NumberBufferEntries - 1 do
     begin
     if ReadAddress < BufferArraySize then
        begin
        CellChar := Buffer1^[ReadAddress]
        end
     else
       if ReadAddress < BufferArraySize * 2 then
          begin
          CellChar := Buffer2^[ReadAddress - BufferArraySize]
          end
       else
          begin
          CellChar := Buffer3^[ReadAddress - (2 * BufferArraySize)];
          end;

     inc(ReadAddress);

     if CellChar = CHR(0) then
        begin
        GetNextEntry := True;
        Exit;
        end;

     EntryString := EntryString + CellChar;
     end;

  { We didn't find a null character at the end - return a null string }

  EntryString := '';
  GetNextEntry := False;
end;

function CellBufferObject.GetNextEntryAddress(var EntryAddress: Pointer): boolean;

{ Returns FALSE when no more entries left in the cell buffer }

var
  CellChar                              : AnsiChar;

begin
  { Find address of first byte in the record to be read }

  if ReadAddress < BufferArraySize then
     begin
     EntryAddress := Addr(Buffer1^[ReadAddress])
     end
  else
    if ReadAddress < BufferArraySize * 2 then
       begin
       if not Buffer2Used then
          begin
          GetNextEntryAddress := False;
          Exit;
          end;

       EntryAddress := Addr(Buffer2^[ReadAddress - BufferArraySize])
       end
    else
       begin
       if not Buffer3Used then
          begin
          GetNextEntryAddress := False;
          Exit;
          end;

       EntryAddress := Addr(Buffer3^[ReadAddress - (2 * BufferArraySize)]);
       end;

  while ReadAddress <= NumberBufferEntries - 1 do
     begin
     if ReadAddress < BufferArraySize then
        begin
        CellChar := Buffer1^[ReadAddress]
        end
     else
       if ReadAddress < BufferArraySize * 2 then
          begin
          CellChar := Buffer2^[ReadAddress - BufferArraySize]
          end
       else
          begin
          CellChar := Buffer3^[ReadAddress - (2 * BufferArraySize)];
          end;

     inc(ReadAddress);

     if CellChar = CHR(0) then
        begin
        GetNextEntryAddress := True;
        Exit;
        end;
     end;

  { We didn't find a null character at the end - return a null string }

  GetNextEntryAddress := False;
end;

function GetRandomLetter: Char;

begin
  GetRandomLetter := CHR(Ord('A') + Random(26));
end;

function GetRandomNumber: Char;

begin
  GetRandomNumber := CHR(Ord('0') + Random(10));
end;

procedure CallDatabase.PushChar(InChar: Char; var BlockNumber: Word; var BlockAddress: Word);

begin
  MemoryBlocks[BlockNumber]^[BlockAddress] := Ord(InChar);

  inc(BlockAddress);

  if BlockAddress = SizeOf(MemoryBlock) then
     begin
     BlockAddress := 0;
     inc(BlockNumber);
     end;
end;

function KeyInRange(X, Y, FirstKeyX, FirstKeyY, LastKeyX, LastKeyY: integer): boolean;

{ Returns TRUE if the key is >= FirstKey and < LastKey }

begin
  KeyInRange := False;

  if (X < 0) or (X > 36) or (Y < 0) or (Y > 36) then Exit;

  if (X < FirstKeyX) or (X > LastKeyX) then Exit;

  if (X = FirstKeyX) and (Y < FirstKeyY) then Exit;

  if (X = LastKeyX) and (Y >= LastKeyY) then Exit;

  KeyInRange := True;
end;

function NumberOfDataBytes(data: DataBaseEntryRecord): integer;

var
  NumberBytes                           : integer;

begin
  with data do
     begin
     NumberBytes := length(Call);

     if Section <> '' then
        begin
        NumberBytes := NumberBytes + length(Section) + 1;
        end;
     if CQZone <> '' then
        begin
        NumberBytes := NumberBytes + length(CQZone) + 1;
        end;
     if FOC <> '' then
        begin
        NumberBytes := NumberBytes + length(FOC) + 1;
        end;
     if Hits > 0 then
        begin
        NumberBytes := NumberBytes + 2;
        end;
     if Grid <> '' then
        begin
        NumberBytes := NumberBytes + length(Grid) + 1;
        end;
     if ITUZone <> '' then
        begin
        NumberBytes := NumberBytes + length(ITUZone) + 1;
        end;
     if Check <> '' then
        begin
        NumberBytes := NumberBytes + length(Check) + 1;
        end;
     if mName <> '' then
        begin
        NumberBytes := NumberBytes + length(mName) + 1;
        end;
     if OldCall <> '' then
        begin
        NumberBytes := NumberBytes + length(OldCall) + 1;
        end;
     if QTH <> '' then
        begin
        NumberBytes := NumberBytes + length(QTH) + 1;
        end;
     if Speed > 0 then
        begin
        NumberBytes := NumberBytes + 2;
        end;
     if TENTEN <> '' then
        begin
        NumberBytes := NumberBytes + length(TENTEN) + 1;
        end;
     if User1 <> '' then
        begin
        NumberBytes := NumberBytes + length(User1) + 1;
        end;
     if User2 <> '' then
        begin
        NumberBytes := NumberBytes + length(User2) + 1;
        end;
     if User3 <> '' then
        begin
        NumberBytes := NumberBytes + length(User3) + 1;
        end;
     if User4 <> '' then
        begin
        NumberBytes := NumberBytes + length(User4) + 1;
        end;
     if User5 <> '' then
        begin
        NumberBytes := NumberBytes + length(User5) + 1;
        end;
     end;

  NumberBytes := NumberBytes + 1; { for the null character at the end }
  NumberOfDataBytes := NumberBytes;
end;

function GetSize(EntryArray: EntryArrayPtr): integer;

var
  EntrySize                             : integer;

begin
  EntrySize := 0;

  while (EntryArray^[EntrySize] <> CHR(0)) do
     begin
     inc(EntrySize);
     end;

  inc(EntrySize); { Give me the null character too }

  GetSize := EntrySize;
end;

function GetCall(EntryArray: EntryArrayPtr): CallString;

var
  TempCall                              : Str20;
  CharPointer                           : integer;

begin
  TempCall := '';

  CharPointer := 0;

  while EntryArray^[CharPointer] > ControlZ do
     begin
     TempCall := TempCall + EntryArray^[CharPointer];
     inc(CharPointer);
     end;

  GetCall := TempCall;
end;

function GetArrayString(var InputArray: EntryArrayPtr): string;

var
  TempString                            : string;
  Address                               : integer;

begin
  TempString := '';
  Address := 0;

  while InputArray^[Address] <> CHR(0) do
     begin
     TempString := TempString + InputArray^[Address];
     inc(Address);
     end;

  GetArrayString := TempString;
end;

procedure ConvertDatbaseEntryRecordToEntryArray(InputRecord: DataBaseEntryRecord;
  var OutputArray: EntryArrayPtr);

var
  InputAddress, OutputAddress           : integer;

begin
  OutputAddress := 0;

  with InputRecord do
     begin
     for InputAddress := 1 to length(Call) do
        begin
        OutputArray^[OutputAddress] := Call[InputAddress];
        inc(OutputAddress);
        end;

     if Section <> '' then
        begin
        OutputArray^[OutputAddress] := ControlA;
        inc(OutputAddress);

        for InputAddress := 1 to length(Section) do
           begin
           OutputArray^[OutputAddress] := Section[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if CQZone <> '' then
        begin
        OutputArray^[OutputAddress] := ControlC;
        inc(OutputAddress);

        for InputAddress := 1 to length(CQZone) do
           begin
           OutputArray^[OutputAddress] := CQZone[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if FOC <> '' then
        begin
        OutputArray^[OutputAddress] := ControlF;
        inc(OutputAddress);

        for InputAddress := 1 to length(FOC) do
           begin
           OutputArray^[OutputAddress] := FOC[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if Hits > 0 then
        begin
        OutputArray^[OutputAddress] := ControlH;
        inc(OutputAddress);
        OutputArray^[OutputAddress] := AnsiChar(Hits);
        inc(OutputAddress);
        end;

     if Grid <> '' then
        begin
        OutputArray^[OutputAddress] := ControlG;
        inc(OutputAddress);

        for InputAddress := 1 to length(Grid) do
           begin
           OutputArray^[OutputAddress] := Grid[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if ITUZone <> '' then
        begin
        OutputArray^[OutputAddress] := ControlI;
        inc(OutputAddress);

        for InputAddress := 1 to length(ITUZone) do
           begin
           OutputArray^[OutputAddress] := ITUZone[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if Check <> '' then
        begin
        OutputArray^[OutputAddress] := ControlK;
        inc(OutputAddress);

        for InputAddress := 1 to length(Check) do
           begin
           OutputArray^[OutputAddress] := Check[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if mName <> '' then
        begin
        OutputArray^[OutputAddress] := ControlN;
        inc(OutputAddress);

        for InputAddress := 1 to length(mName) do
           begin
           OutputArray^[OutputAddress] := mName[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if OldCall <> '' then
        begin
        OutputArray^[OutputAddress] := ControlO;
        inc(OutputAddress);

        for InputAddress := 1 to length(OldCall) do
           begin
           OutputArray^[OutputAddress] := OldCall[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if QTH <> '' then
        begin
        OutputArray^[OutputAddress] := ControlQ;
        inc(OutputAddress);

        for InputAddress := 1 to length(QTH) do
           begin
           OutputArray^[OutputAddress] := QTH[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if Speed <> 0 then
        begin
        OutputArray^[OutputAddress] := ControlS;
        inc(OutputAddress);
        OutputArray^[OutputAddress] := AnsiChar(Speed);
        inc(OutputAddress);
        end;

     if TENTEN <> '' then
        begin
        OutputArray^[OutputAddress] := ControlT;
        inc(OutputAddress);

        for InputAddress := 1 to length(TENTEN) do
           begin
           OutputArray^[OutputAddress] := TENTEN[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if User1 <> '' then
        begin
        OutputArray^[OutputAddress] := ControlU;
        inc(OutputAddress);

        for InputAddress := 1 to length(User1) do
           begin
           OutputArray^[OutputAddress] := User1[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if User2 <> '' then
        begin
        OutputArray^[OutputAddress] := ControlV;
        inc(OutputAddress);

        for InputAddress := 1 to length(User2) do
           begin
           OutputArray^[OutputAddress] := User2[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if User3 <> '' then
        begin
        OutputArray^[OutputAddress] := ControlW;
        inc(OutputAddress);

        for InputAddress := 1 to length(User3) do
           begin
           OutputArray^[OutputAddress] := User3[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if User4 <> '' then
        begin
        OutputArray^[OutputAddress] := ControlX;
        inc(OutputAddress);

        for InputAddress := 1 to length(User4) do
           begin
           OutputArray^[OutputAddress] := User4[InputAddress];
           inc(OutputAddress);
           end;
        end;

     if User5 <> '' then
        begin
        OutputArray^[OutputAddress] := ControlY;
        inc(OutputAddress);

        for InputAddress := 1 to length(User5) do
           begin
           OutputArray^[OutputAddress] := User5[InputAddress];
           inc(OutputAddress);
           end;
        end;
     end;

  OutputArray^[OutputAddress] := NullCharacter;
  inc(OutputAddress);
end;

procedure CallDatabase.MergeArrays(var FirstArray: EntryArrayPtr;
  var SecondArray: EntryArrayPtr;
  var OutputArray: EntryArrayPtr);

{ This will move any data from the first array into the second one. }

var
  FirstDataRecord, SecondDataRecord, OutputDataRecord: DataBaseEntryRecord;

begin
  ParseEntryToDataRecord(GetArrayString(FirstArray), FirstDataRecord);
  ParseEntryToDataRecord(GetArrayString(SecondArray), SecondDataRecord);

  ClearDataEntry(OutputDataRecord);

  { Start with the contents of the first record }

  OutputDataRecord := FirstDataRecord;

  { We add the hits together }

  if FirstDataRecord.Hits + SecondDataRecord.Hits > 255 then
     begin
     OutputDataRecord.Hits := 255
     end
  else
     begin
     OutputDataRecord.Hits := FirstDataRecord.Hits + SecondDataRecord.Hits;
     end;

  { If the second record has any data - put it into the output record }

  if SecondDataRecord.Section <> '' then
     begin
     OutputDataRecord.Section := SecondDataRecord.Section;
     end;
  if SecondDataRecord.CQZone <> '' then
     begin
     OutputDataRecord.CQZone := SecondDataRecord.CQZone;
     end;
  if SecondDataRecord.FOC <> '' then
     begin
     OutputDataRecord.FOC := SecondDataRecord.FOC;
     end;
  if SecondDataRecord.Grid <> '' then
     begin
     OutputDataRecord.Grid := SecondDataRecord.Grid;
     end;
  if SecondDataRecord.ITUZone <> '' then
     begin
     OutputDataRecord.ITUZone := SecondDataRecord.ITUZone;
     end;
  if SecondDataRecord.Check <> '' then
     begin
     OutputDataRecord.Check := SecondDataRecord.Check;
     end;
  if SecondDataRecord.mName <> '' then
     begin
     OutputDataRecord.mName := SecondDataRecord.mName;
     end;
  if SecondDataRecord.OldCall <> '' then
     begin
     OutputDataRecord.OldCall := SecondDataRecord.OldCall;
     end;
  if SecondDataRecord.QTH <> '' then
     begin
     OutputDataRecord.QTH := SecondDataRecord.QTH;
     end;
  if SecondDataRecord.Speed <> 0 then
     begin
     OutputDataRecord.Speed := SecondDataRecord.Speed;
     end;
  if SecondDataRecord.TENTEN <> '' then
     begin
     OutputDataRecord.TENTEN := SecondDataRecord.TENTEN;
     end;
  if SecondDataRecord.User1 <> '' then
     begin
     OutputDataRecord.User1 := SecondDataRecord.User1;
     end;
  if SecondDataRecord.User2 <> '' then
     begin
     OutputDataRecord.User2 := SecondDataRecord.User2;
     end;
  if SecondDataRecord.User3 <> '' then
     begin
     OutputDataRecord.User3 := SecondDataRecord.User3;
     end;
  if SecondDataRecord.User4 <> '' then
     begin
     OutputDataRecord.User4 := SecondDataRecord.User4;
     end;
  if SecondDataRecord.User5 <> '' then
     begin
     OutputDataRecord.User5 := SecondDataRecord.User5;
     end;

  { Convert the output record back into a packed array in the format used
    in the TRMASTER.DTA file }

  ConvertDatbaseEntryRecordToEntryArray(OutputDataRecord, OutputArray);
end;

function AlreadySaved(Call: CallString): boolean;

var
  Address                               : integer;

begin
  if NumberCallsAlreadySaved > 0 then
     begin
     for Address := 0 to NumberCallsAlreadySaved - 1 do
       if Call = CallsAlreadySaved^[Address] then
          begin
          AlreadySaved := True;
          Exit;
          end;
     end;

  AlreadySaved := False;

  if NumberCallsAlreadySaved < MaximumCallsAlreadSaved then
     begin
     CallsAlreadySaved^[NumberCallsAlreadySaved] := Call;
     inc(NumberCallsAlreadySaved);
     end;
end;

procedure CallDatabase.SaveCallsAndNamesToFile(FileName: string);

var
  CellSize                              : LONGINT;
  FileRead                              : file;
  FileWrite                             : Text;
  //BytesRead                             : Word;
  X, Y, NextX, NextY, StartingOffset, EndingOffset: LONGINT;
  KeyString, TempString                 : Str40;
  EntryString                           : ShortString {string};
  DataRecord                            : DataBaseEntryRecord;

begin
  if not LoadInIndexArray then Exit;
  if FileName = '' then Exit;

  OpenFileForWrite(FileWrite, FileName);

  //{WLI}    GoToXY (1, WhereY);
  //{WLI}    Write ('Saving .DTA file to ASCII file.  Processing cell   ');

  CellBuffer.Initialize(CellSize); { Only works in POST mode }

  New(CallsAlreadySaved);

  for X := 0 to 36 do
     begin
     for Y := 0 to 36 do
        begin
        NumberCallsAlreadySaved := 0; { Set to zero for each cell }

          //{WLI}            GoToXY (WhereX - 2, WhereY);

        KeyString := GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y);

          //      Write(KeyString);

        StartingOffset := SCPIndexArray^[X, Y];

        NextY := Y + 1;
        NextX := X;

        if NextY > 36 then
           begin
           if X < 36 then
              begin
              NextX := X + 1;
              NextY := 0;
              EndingOffset := SCPIndexArray^[NextX, NextY];
              end
           else
              begin
              EndingOffset := SCPEndOfFile;
              end;
           end
        else
           begin
           EndingOffset := SCPIndexArray^[NextX, NextY];
           end;

        if (X <> 0) or (Y <> 0) then
           begin
           if FilePos(FileRead) <> StartingOffset then
              begin
              Close(FileRead);
              Assign(FileRead, string(ActiveFilename));
              Reset(FileRead, 1);
              Seek(FileRead, StartingOffset);
              end;
           end
        else
           begin
           Assign(FileRead, string(ActiveFilename));
           Reset(FileRead, 1);
           Seek(FileRead, StartingOffset);
           end;

        if StartingOffset < EndingOffset then
           begin
           CellSize := EndingOffset - StartingOffset;

           if CellSize > 3 * BufferArraySize then
              begin
              WriteLn;
                    //{WLI}                    ReportError (GetSCPCharFromInteger (X) + GetSCPCharFromInteger (Y) + ' cell is too large!!!');
              halt;
              end;

   //        CellBuffer.LoadCellIntoBuffer(KeyString, FileRead, CellSize);

           while CellBuffer.GetNextEntry(EntryString) do
              begin
              ParseEntryToDataRecord(EntryString, DataRecord);

              if DataRecord.mName <> '' then
                if FirstCellForThisCall(DataRecord.Call, X, Y) then
                  if DoubleIndexCall(DataRecord.Call) then
                     begin
                     if not AlreadySaved(DataRecord.Call) then
                        begin
                        TempString := DataRecord.Call;
                        while length(TempString) < 15 do
                           begin
                           TempString := TempString + ' ';
                           end;
                        TempString := TempString + DataRecord.mName;
                        WriteLn(FileWrite, TempString);
                        end;
                     end
                  else
                     begin
                     TempString := DataRecord.Call;
                     while length(TempString) < 15 do
                        begin
                        TempString := TempString + ' ';
                        end;
                     TempString := TempString + DataRecord.mName;
                     WriteLn(FileWrite, TempString);
                     end;
              end;

           end;
        end;
     end;

  CellBuffer.GoAway;
  Dispose(CallsAlreadySaved);

  Close(FileWrite);
  ASCIIFileIsCurrent := True;
  //{WLI}    GoToXY (1, WhereY);
  //{WLI}    ClrEol;
  //{WLI}    TextColor (Cyan);
  //{WLI}    WriteLn ('Data successfully saved to ASCII file.');
end;

procedure CallDatabase.AddInBytes(NumberBytes, X, Y: integer);

{ Will increment the totals in the SCPIndexArray starting for the cell
  indicated }

var
  XAddress, YAddress                    : integer;

begin
  { We start at the end of the specified cell }

  inc(Y);

  if Y > 36 then
     begin
     inc(X);
     Y := 0;
     end;

  if X <= 36 then
     begin
     for XAddress := X to 36 do
        begin
        for YAddress := Y to 36 do
           begin
           SCPIndexArray^[XAddress, YAddress] := SCPIndexArray^[XAddress, YAddress] + NumberBytes;
           end;
        end;
     end;

  SCPEndOfFile := SCPEndOfFile + NumberBytes;
end;

procedure CallDatabase.GetBestOffsets(Call: CallString;
  var StartingOffset, EndingOffset: LONGINT;
  var X, Y: integer);

var
  BestTwoLetterString                   : Str20;
  NextX, NextY                          : integer;

begin
  BestTwoLetterString := BestTwoLetters(Call);

  if BestTwoLetterString = '' then { No calls found in array }
     begin
     StartingOffset := 0;
     EndingOffset := 0;
     Exit;
     end;

  X := GetSCPIntegerFromChar(BestTwoLetterString[1]);
  Y := GetSCPIntegerFromChar(BestTwoLetterString[2]);

  if (X <> -1) and (Y <> -1) then
     begin
     StartingOffset := SCPIndexArray^[X, Y];

     NextY := Y + 1;
     NextX := X;

     if NextY > 36 then
        begin
        if X < 36 then
           begin
           NextX := X + 1;
           NextY := 0;
           EndingOffset := SCPIndexArray^[NextX, NextY];
           end
        else
           begin
           EndingOffset := SCPEndOfFile;
           end;
        end
     else
        begin
        EndingOffset := SCPIndexArray^[NextX, NextY];
        end;
     end;

end;

function CallDatabase.BestTwoLetters(Partial: CallString): Str20;

{ This routine will return the best two letters to be used when looking
  for the specified callsign/partial. }

var
  CharPos                               : integer;
  MinimumBytes                          : LONGINT;
  NumberBytes                           : array[1..11] of LONGINT;

begin
  BestTwoLetters := ''; { Default if we fall out }

  if not LoadInIndexArray then Exit;

  if length(Partial) < 2 then Exit; { Can't deal with this }

  MinimumBytes := AVeryBigNumber;

  for CharPos := 1 to length(Partial) - 1 do
     begin
     if Copy(Partial, CharPos, 2) = 'JA' then Continue;

     NumberBytes[CharPos] := NumberOfBytesAtThisAddress(Copy(Partial, CharPos, 2));

       { We get zero if we had an illegal character - like a question mark }

     if NumberBytes[CharPos] > 0 then
       if NumberBytes[CharPos] < MinimumBytes then
          begin
          MinimumBytes := NumberBytes[CharPos];
          end;
     end;

  { Now, which pair had the minimum cell size? }

  for CharPos := 1 to length(Partial) - 1 do
    if NumberBytes[CharPos] = MinimumBytes then
       begin
       BestTwoLetters := Copy(Partial, CharPos, 2);
       Exit;
       end;

  { We fall through leaving a null string if we couldn't process the
    data.  This might occure if someone called us with a string that
    didn't have two non wildcard entries in a row (like N?6). }

end;

procedure CallDatabase.BlowAwayFirstLettersList;

{ This procedure will clear out the InitialPartialList }

var
  NextRecord, ActiveRecord              : PartialCallListEntryPtr;

begin
  ActiveRecord := InitialPartialList;

  while ActiveRecord <> nil do
     begin
     NextRecord := ActiveRecord^.NextEntry;
     Dispose(ActiveRecord);
     ActiveRecord := NextRecord;
     end;

  InitialPartialCall := '';
  InitialPartialList := nil;
end;

procedure CallDatabase.ClearField;

//var  Key: Char;

begin
end;

procedure CallDatabase.ClearDataEntry(var data: DataBaseEntryRecord);

begin

  Windows.ZeroMemory(@data, SizeOf(DataBaseEntryRecord));
  {
    with data do
    begin
      Call := '';
      Section := '';
      CQZone := '';
      FOC := '';
      Grid := '';
      Hits := 0;
      ITUZone := '';
      Check := '';
      mName := '';
      OldCall := '';
      QTH := '';
      Speed := 0;
      TENTEN := '';
      User1 := '';
      User2 := '';
      User3 := '';
      User4 := '';
      User5 := '';
    end;
   }
end;

function CallDatabase.FirstCellForThisCall(Call: CallString; X, Y: integer): boolean;

{ This function will return TRUE if X Y values passed to it point to the
  first cell this call would be found in when using a typical FOR X FOR Y
  loop to go through the database. }

var
  LeastX, LeastY, TestX, TestY, CharPointer: integer;

begin
  if length(Call) < 2 then
     begin
     FirstCellForThisCall := False;
     Exit;
     end;

  LeastX := 37;
  LeastY := 37;

  for CharPointer := 1 to length(Call) - 1 do
     begin
     TestX := GetSCPIntegerFromChar(Call[CharPointer]);
     TestY := GetSCPIntegerFromChar(Call[CharPointer + 1]);

     if (TestX < LeastX) or ((TestX = LeastX) and (TestY < LeastY)) then
        begin
        LeastX := TestX;
        LeastY := TestY;
        end;
     end;

  FirstCellForThisCall := (X = LeastX) and (Y = LeastY);
end;

function CallDatabase.GetCodeSpeed(Call: CallString): integer;

var
  data                                  : DataBaseEntryRecord;

begin
  if GetEntry(Call, data) then
     begin
     GetCodeSpeed := data.Speed
     end
  else
     begin
     GetCodeSpeed := 0;
     end;
end;

function CallDatabase.GetName(Call: CallString): CallString;

var
  data                                  : DataBaseEntryRecord;
  tName                                 : CallString;

begin
  {  Name := '';

    if Name <> '' then
    begin
      GetName := Name;
      Exit;
    end;
  }

  if GetEntry(Call, data) then
     begin
     //    GetName := data.mName;
   tName := LowerCase(data.mName);
   tName[1] := UpCase(data.mName[1]);
   GetName := tName;
     end
  else
     begin
     GetName := '';
     end;
end;

function CallDatabase.GetFOCNumber(Call: CallString): CallString;

var
  data                                  : DataBaseEntryRecord;

begin
  if GetEntry(RootCall(Call), data) then
     begin
     GetFOCNumber := data.FOC
     end
  else
     begin
     GetFOCNumber := '';
     end;
end;

function CallDatabase.GetEntry(Call: CallString; var data: DataBaseEntryRecord): boolean;

{ This function will fetch all the data for the callsign indicated.  It
  returns TRUE if the callsign was found. }

var
  EntryString                           : ShortString {string};

begin
  if Call = LastCallRecord.Call then
     begin
     data := LastCallRecord;
     GetEntry := True;
     Exit;
     end;

  GetEntry := False;

  ClearDataEntry(data);

  if not LoadInIndexArray then Exit;

  if not PartialCallSetup(Call) then Exit;

  while CellBuffer.GetNextEntry(EntryString) do
     begin
     ParseEntryToDataRecord(EntryString, data);

     if data.Call = Call then
        begin
        GetEntry := True;
        LastCallRecord := data;
        Exit;
        end;
     end;

  { Didn't find anything }

  ClearDataEntry(data);
end;

procedure CallDatabase.GetDataFromASCIIEntry(FileString: ShortString; var data: DataBaseEntryRecord; Ignore: Char);

{ This function will decode the ASCII string and put the proper data into
  the Data variable }

var
  TestName, Command                     : Str40;
  ID                                    : AnsiChar;
  Result                                : integer;

begin
  ClearDataEntry(data);

  data.Call := UpperCase(RemoveFirstString(FileString));

  while (FileString <> '') and (FileString[1] = '=') do
     begin
     ID := FileString[2];

     Delete(FileString, 1, 2);

     if StringHas(FileString, '=') then { Another command in waiting }
        begin
        Command := PrecedingString(FileString, ' =');

        FileString := Copy(FileString,
          pos('=', FileString),
          (length(FileString) - pos('=', FileString)) + 1);

        end
     else
        begin
        Command := FileString;
        FileString := '';
        end;

     with data do
        begin
        case ID of
          'A':
            if Ignore <> 'A' then
               begin
               Section := Command;
               end;
          'C':
            if Ignore <> 'C' then
               begin
               CQZone := Command;
               end;
          'F':
            if Ignore <> 'F' then
               begin
               FOC := Command;
               end;
          'G':
            if Ignore <> 'G' then
               begin
               Grid := Command;
               end;

          'H':
            if Ignore <> 'H' then
               begin
               Val(Command, Hits, Result);
               end;

          'I':
            if Ignore <> 'I' then
               begin
               ITUZone := Command;
               end;
          'K':
            if Ignore <> 'K' then
               begin
               Check := Command;
               end;

          'N':
            if Ignore <> 'N' then
               begin
               if length(Command) = 1 then
                  begin
                  Continue;
                  end;

               if length(Command) = 2 then
                  begin
                  TestName := UpperCase(Command);

                  if (TestName <> 'AL') and (TestName <> 'ED') and
                    (TestName <> 'OZ') and (TestName <> 'BO') and
                    (TestName <> 'TY') and (TestName <> 'JO') and
                    (TestName <> 'GO') and (TestName <> 'OX') and
                    (TestName <> 'CY') and (TestName <> 'JP') and
                    (TestName <> 'MO') and (TestName <> 'HI') and
                    (TestName <> 'OJ') then
                     begin
                     Continue;
                     end;
                  end;

               mName := Command;
               end;

          'O':
            if Ignore <> 'O' then
               begin
               OldCall := Command;
               end;
          'Q':
            if Ignore <> 'Q' then
               begin
               QTH := Command;
               end;

          'S':
            if Ignore <> 'S' then
               begin
               Val(Command, Speed, Result);
               end;

          'T':
            if Ignore <> 'T' then
               begin
               TENTEN := Command;
               end;
          'U':
            if Ignore <> 'U' then
               begin
               User1 := Command;
               end;
          'V':
            if Ignore <> 'V' then
               begin
               User2 := Command;
               end;
          'W':
            if Ignore <> 'W' then
               begin
               User3 := Command;
               end;
          'X':
            if Ignore <> 'X' then
               begin
               User4 := Command;
               end;
          'Y':
            if Ignore <> 'Y' then
               begin
               User5 := Command;
               end;
        end;
        end;
     end;

end;

function CountryStringPresent(CountryID: Str20; CountryString: ShortString {Str80} {WLI}): boolean;

var
  CString                               : Str20;
  CommaPosition                         : integer;

begin
  while pos(',', CountryString) > 0 do
     begin
     CommaPosition := pos(',', CountryString);

     if CommaPosition > 1 then
        begin
        CString := Copy(CountryString, 1, CommaPosition - 1);

        if CString = CountryID then
           begin
           CountryStringPresent := True;
           Exit;
           end;

        Delete(CountryString, 1, CommaPosition);
        GetRidOfPrecedingSpaces(CountryString);
        end;
     end;

  if CountryString <> '' then
     begin
     CountryStringPresent := CountryID = CountryString
     end
  else
     begin
     CountryStringPresent := False;
     end;
end;

function CallDatabase.GoodCountry(Call: CallString): boolean;

var
  CountryID                             : DXMultiplierString {Str20};
  TempString                            : Str80;
  QTH                                   : QTHRecord;
begin
  GoodCountry := True;
  if CountryString = '' then Exit;

  TempString := CountryString;

  ctyLocateCall(Call, QTH);
  CountryID := QTH.CountryID;

  if (Copy(CountryString, 1, 1) = '!') or
    (Copy(CountryString, 1, 1) = '-') then { Exclude countries }
     begin
     Delete(TempString, 1, 1); { Get rid of ! or - }

     if CountryStringPresent(CountryID, TempString) then
        begin
        GoodCountry := False;
        end;

     Exit;
     end
  else

    { Include countries}

     begin
     GoodCountry := CountryStringPresent(CountryID, TempString);
     end;
end;

//function CallDatabase.GetNextPartialCall: CallString;

procedure CallDatabase.GetNextPartialCall(var Call: CallString);

{ Returns the next possible call and puts it in the InitialPartialCallList }

var
  EntryString                           : ShortString {string};
  data                                  : DataBaseEntryRecord;

begin
//  GetNextPartialCall := '';
  Call := '';

  if SCPDisabledByApplication then Exit;
  if CellBuffer.Key = '' then Exit;

  while CellBuffer.GetNextEntry(EntryString) do
     begin
     ParseEntryToDataRecord(EntryString, data);

     if (length(InitialPartialCall) = 2) or (PartialCall(InitialPartialCall, data.Call)) then
       if CountryString <> '' then
          begin
          if GoodCountry(data.Call) then
             begin
             {GetNextPartial}Call := data.Call;
             Exit;
             end;
          end
       else
          begin
          {GetNextPartial}Call := data.Call;
          Exit;
          end;
     end;
end;

function CallDatabase.LoadInIndexArray: boolean;

{ This procedure will go read in the index array for the active file.
  It is saved in SCPIndexArray. Returns TRUE if it thinks it worked. }

//var
  //Directory                             : Str40;
  //Result1                               : integer {WORD} {WLI};

begin
  WorkingDirectory := '';
  LoadInIndexArray := False;
  if (SCPDisabledByApplication) or (PossibleCallAction = LogOnly) then Exit;

  {KK1L 6.69 added LogOnly check}

  if TRMasterFileOpen then
     begin
     LoadInIndexArray := True;
     Exit;
     end;

  //{WLI}    IF SizeOf (SCPIndexArray^) + 5000 >= MaxAvail THEN Exit;

//  if ActiveFilename <> '' then
  if ActiveFilename[0] <> #0 then
     begin

      { If the file does not appear in the active directory, we need
        to search around for it and come up with a complete path for
        it. }
    if not MasterFileExists then Exit;


      //{WLI}
         {DosError := 0;}
           { Seems to be necessary in some cases as the
                                value will be 18 - indicating "no more files"
                                which might be because of the FindFirst that
                                was executed.  Doesn't seem to get reset by
                                the next two statements...  weird. }

    if tOpenFileForRead(TRMasterFileRead, ActiveFilename) then

//      Assign(TRMasterFileRead, ActiveFilename);
//    Reset(TRMasterFileRead, 1);
//    if IORESULT {DosError} {WLI} = 0 then
       begin
       DTAFileSize := Windows.GetFileSize(TRMasterFileRead, nil) {FileSize(TRMasterFileRead)};

       New(SCPIndexArray);
       sReadFile(TRMasterFileRead, SCPIndexArray^, SizeOf(SCPIndexArray^));
       sReadFile(TRMasterFileRead, SCPEndOfFile, SizeOf(SCPEndOfFile));
 //      BlockRead(TRMasterFileRead, SCPIndexArray^, SizeOf(SCPIndexArray^), Result1);
 //      BlockRead(TRMasterFileRead, SCPEndOfFile, SizeOf(SCPEndOfFile), Result1);
       LoadInIndexArray := True;
       TRMasterFileOpen := True;
       IndexArrayAllocated := True;
       end;

  end;

end;

procedure CallDatabase.NewTwoLetters(PartialCall: CallString {Str20});

{ This procedure will setup the GetNextPartialCall function for a
  new two letter key.  }

var
  StartingOffset, EndingOffset, NumberBytes: LONGINT;
  X, Y                                  : integer;
  KeyString                             : CallString;

begin
  BlowAwayFirstLettersList;

  { Get rid of old file buffer }

  GetBestOffsets(PartialCall, StartingOffset, EndingOffset, X, Y);

  KeyString := GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y);

  if StartingOffset = EndingOffset then { No calls found }
     begin
     CellBuffer.GoAway;
     Exit;
     end;

  CellBuffer.Key := GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y);

  if EndingOffset - StartingOffset > BufferArraySize then
     begin
     EndingOffset := StartingOffset + BufferArraySize;
     end;

  //{WLI}    IF EndingOffset - StartingOffset >= MaxAvail THEN
  //{WLI}        EndingOffset := StartingOffset + (MaxAvail - 5000);

  NumberBytes := EndingOffset - StartingOffset;

//  Seek(TRMasterFileRead, StartingOffset);
  Windows.SetFilePointer(TRMasterFileRead, StartingOffset, nil, FILE_BEGIN);

  CellBuffer.LoadCellIntoBuffer(KeyString, TRMasterFileRead, NumberBytes);
  InitialPartialCall := PartialCall;
end;

function CallDatabase.NumberOfBytesAtThisAddress(TwoLetters: Str20): LONGINT;

var
  X, Y                                  : integer;
  Difference, StartingOffset, EndingOffset: LONGINT;

begin
  if TwoLetters = '//' then
     begin
     NumberOfBytesAtThisAddress := 0;
     Exit;
     end;

  if not LoadInIndexArray then Exit;

  X := GetSCPIntegerFromChar(TwoLetters[1]);
  Y := GetSCPIntegerFromChar(TwoLetters[2]);

  if (X = -1) or (Y = -1) then
     begin
     NumberOfBytesAtThisAddress := 0;
     Exit;
     end;

  StartingOffset := SCPIndexArray^[X, Y];

  inc(Y);

  if Y > 36 then
     begin
     Y := 0;
     inc(X);
     end;

  EndingOffset := SCPIndexArray^[X, Y];
  Difference := EndingOffset - StartingOffset;
  NumberOfBytesAtThisAddress := Difference;
end;

procedure CallDatabase.ParseEntryToDataRecord(EntryString: ShortString {string}; var DataRecord: DataBaseEntryRecord);

{ This procedure will take a null terminated entry from the .DTA file
  and parse the data into the data record. }

var
  CharAddress                           : integer;

begin
  ClearDataEntry(DataRecord);

  with DataRecord do
     begin
     CharAddress := 1;

     repeat
       while EntryString[CharAddress] > ControlZ do
          begin
          Call := Call + EntryString[CharAddress];
          inc(CharAddress);
          if CharAddress > length(EntryString) then Exit;
          end;

       case EntryString[CharAddress] of

         ControlA:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                Section := Section + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlC:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                CQZone := CQZone + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlF:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                FOC := FOC + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlG:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                Grid := Grid + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlH:
           begin
             inc(CharAddress);
             Hits := Ord(EntryString[CharAddress]);
             inc(CharAddress);
           end;

         ControlI:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                ITUZone := ITUZone + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlK:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                Check := Check + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlN:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                mName := mName + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlO:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                OldCall := OldCall + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlQ:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                QTH := QTH + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlS:
           begin
             inc(CharAddress);
             Speed := Ord(EntryString[CharAddress]);
             inc(CharAddress);
           end;

         ControlT:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                TENTEN := TENTEN + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlU:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                User1 := User1 + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlV:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                User2 := User2 + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlW:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                User3 := User3 + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlX:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                User4 := User4 + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

         ControlY:
           begin
             inc(CharAddress);

             while EntryString[CharAddress] > ControlZ do
                begin
                User5 := User5 + EntryString[CharAddress];
                inc(CharAddress);
                if CharAddress > length(EntryString) then Exit;
                end;
           end;

       else Exit; { This should not happen! }
       end;

     until CharAddress >= length(EntryString);
     end;
end;

procedure CallDatabase.SaveDataToASCIIFile(var FileWrite: Text;
  NewData: DataBaseEntryRecord);

{ Saves the data in NewData to the file opened in FileWrite.  }

begin
  Write(FileWrite, NewData.Call);

  with NewData do
     begin
     if Section <> '' then
        begin
        Write(FileWrite, ' =A', Section);
        end;
     if CQZone <> '' then
        begin
        Write(FileWrite, ' =C', CQZone);
        end;
     if FOC <> '' then
        begin
        Write(FileWrite, ' =F', FOC);
        end;
     if Grid <> '' then
        begin
        Write(FileWrite, ' =G', Grid);
        end;
     if Hits > 0 then
        begin
        Write(FileWrite, ' =H', Hits);
        end;
     if ITUZone <> '' then
        begin
        Write(FileWrite, ' =I', ITUZone);
        end;
     if Check <> '' then
        begin
        Write(FileWrite, ' =K', Check);
        end;
     if mName <> '' then
        begin
        Write(FileWrite, ' =N', mName);
        end;
     if OldCall <> '' then
        begin
        Write(FileWrite, ' =O', OldCall);
        end;
     if QTH <> '' then
        begin
        Write(FileWrite, ' =Q', QTH);
        end;
     if Speed > 0 then
        begin
        Write(FileWrite, ' =S', Speed);
        end;
     if TENTEN <> '' then
        begin
        Write(FileWrite, ' =T', TENTEN);
        end;
     if User1 <> '' then
        begin
        Write(FileWrite, ' =U', User1);
        end;
     if User2 <> '' then
        begin
        Write(FileWrite, ' =V', User2);
        end;
     if User3 <> '' then
        begin
        Write(FileWrite, ' =W', User3);
        end;
     if User4 <> '' then
        begin
        Write(FileWrite, ' =X', User4);
        end;
     if User5 <> '' then
        begin
        Write(FileWrite, ' =Y', User5);
        end;
     end;

  WriteLn(FileWrite);

end;

procedure CallDatabase.SaveToASCIIFile;

{ This procedure will save the active file to the file ASCIIFileName.
  It will set the variable ASCIIFileIsCurrent to TRUE }

var
  CellSize         : LONGINT;
  FileRead                              : file;
  FileWrite                             : Text;
  X, Y, NextX, NextY, StartingOffset, EndingOffset: LONGINT;
  EntryString                           : ShortString {string};
  KeyString                             : CallString;
  DataRecord                            : DataBaseEntryRecord;

begin
  if not LoadInIndexArray then
     begin
     ShowMessage(TC_UNABLESAVEDTAASCIIFILE);
     Exit;
     end;

  OpenFileForWrite(FileWrite, { WorkingDirectory + } ActiveASCIIFileName);

  //{WLI}    GoToXY (1, WhereY);
  ShowMessage(TC_SAVINGDTAFILEASCIIFILEPROCESSINGCE);

  New(CallsAlreadySaved);

  for X := 0 to 36 do
     begin
     for Y := 0 to 36 do
        begin
        NumberCallsAlreadySaved := 0;

          //{WLI}            GoToXY (WhereX - 2, WhereY);
        KeyString := GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y);
          //      Write(KeyString);

        StartingOffset := SCPIndexArray^[X, Y];

        NextY := Y + 1;
        NextX := X;

        if NextY > 36 then
           begin
           if X < 36 then
              begin
              NextX := X + 1;
              NextY := 0;
              EndingOffset := SCPIndexArray^[NextX, NextY];
              end
           else
              begin
              EndingOffset := SCPEndOfFile;
              end;
           end
        else
           begin
           EndingOffset := SCPIndexArray^[NextX, NextY];
           end;

        if (X <> 0) or (Y <> 0) then
           begin
           if FilePos(FileRead) <> StartingOffset then
              begin
              Close(FileRead);
              Assign(FileRead, string(ActiveFilename));
              Reset(FileRead, 1);
              Seek(FileRead, StartingOffset);
              end;
           end
        else
           begin
           Assign(FileRead, string(ActiveFilename));
           Reset(FileRead, 1);
           Seek(FileRead, StartingOffset);
           end;

        if StartingOffset < EndingOffset then
           begin
           CellSize := EndingOffset - StartingOffset;

           if CellSize > BufferArraySize * 3 then
              begin

              ShowMessage(GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y) + ' cell is too large - 3!!');
              halt;
              end;

   //        CellBuffer.LoadCellIntoBuffer(KeyString, FileRead, CellSize);

           while CellBuffer.GetNextEntry(EntryString) do
              begin
              ParseEntryToDataRecord(EntryString, DataRecord);

              if FirstCellForThisCall(DataRecord.Call, X, Y) then
                if DoubleIndexCall(DataRecord.Call) then
                   begin
                   if not AlreadySaved(DataRecord.Call) then
                      begin
                      SaveDataToASCIIFile(FileWrite, DataRecord);
                      end;

                   end
                else
                   begin
                   SaveDataToASCIIFile(FileWrite, DataRecord);
                   end;
              end;
           end;
        end;
     end;

  Dispose(CallsAlreadySaved);
  CellBuffer.GoAway;

  Closefile(FileWrite);
  Closefile(FileRead);

  ASCIIFileIsCurrent := True;
  ShowMessage(TC_DATASUCCESSFULLYSAVEDASCIIFILE);

end;

procedure CallDatabase.TransferNewData(OldData: DataBaseEntryRecord; var NewData: DataBaseEntryRecord);

{ Moves any data found in OldData into the NewData variable if not found
  in the NewData entry }

begin
  if HitsOverwrite and (OldData.Hits < 255) then
     begin
     NewData.Hits := OldData.Hits + 1
     end
  else
     begin
     NewData.Hits := OldData.Hits;
     end;

  with NewData do
     begin
     if (not SectionOverwrite) and (OldData.Section <> '') or (NewData.Section = '') then
        begin
        Section := OldData.Section;
        end;
     if (not CQZoneOverwrite) and (OldData.CQZone <> '') or (NewData.CQZone = '') then
        begin
        CQZone := OldData.CQZone;
        end;
     if (not FOCOverwrite) and (OldData.FOC <> '') or (NewData.FOC = '') then
        begin
        FOC := OldData.FOC;
        end;
     if (not GridOverwrite) and (OldData.Grid <> '') or (NewData.Grid = '') then
        begin
        Grid := OldData.Grid;
        end;
     if (not ITUZoneOverwrite) and (OldData.ITUZone <> '') or (NewData.ITUZone = '') then
        begin
        ITUZone := OldData.ITUZone;
        end;
     if (not CheckOverwrite) and (OldData.Check <> '') or (NewData.Check = '') then
        begin
        Check := OldData.Check;
        end;
     if (not NameOverwrite) and (OldData.mName <> '') or (NewData.mName = '') then
        begin
        mName := OldData.mName;
        end;
     if (not OldCallOverwrite) and (OldData.OldCall <> '') or (NewData.OldCall = '') then
        begin
        OldCall := OldData.OldCall;
        end;
     if (not QTHOverwrite) and (OldData.QTH <> '') or (NewData.QTH = '') then
        begin
        QTH := OldData.QTH;
        end;
     if (not SpeedOverwrite) and (OldData.Speed > 0) or (NewData.Speed = 0) then
        begin
        Speed := OldData.Speed;
        end;
     if (not TenTenOverwrite) and (OldData.TENTEN <> '') or (NewData.TENTEN = '') then
        begin
        TENTEN := OldData.TENTEN;
        end;
     if (not User1Overwrite) and (OldData.User1 <> '') or (NewData.User1 = '') then
        begin
        User1 := OldData.User1;
        end;
     if (not User2Overwrite) and (OldData.User2 <> '') or (NewData.User2 = '') then
        begin
        User2 := OldData.User2;
        end;
     if (not User3Overwrite) and (OldData.User3 <> '') or (NewData.User3 = '') then
        begin
        User3 := OldData.User3;
        end;
     if (not User4Overwrite) and (OldData.User4 <> '') or (NewData.User4 = '') then
        begin
        User4 := OldData.User4;
        end;
     if (not User5Overwrite) and (OldData.User5 <> '') or (NewData.User5 = '') then
        begin
        User5 := OldData.User5;
        end;
     end;
end;

function CallDatabase.PartialCallSetup(PartialCall: CallString): boolean;

{ Just call this routine, then call GetNextPartialCall until it returns
  nothing }

var
  CharPos                               : integer;

begin
  if not LoadInIndexArray then
     begin
     PartialCallSetup := False;
     Exit;
     end;

  PartialCallSetup := True;

  for CharPos := 1 to length(PartialCall) do
    if Copy(PartialCall, CharPos, 2) = CellBuffer.Key then
       begin { We have already read in a cell with this call }
       CellBuffer.ReadAddress := 0; { Rewind list }
       InitialPartialCall := PartialCall;
       Exit;
       end;

  NewTwoLetters(PartialCall);
end;

procedure CallDatabase.ASCIIFileEditor;
{
var
  ChangesMade, NeedToSaveLastRecord: boolean;
  data: DatabaseEntryRecord;
  Key: Char;
  Call: CallString;
  FileWrite: Text;
}
begin

end;

procedure CallDatabase.AddRecordToMergeList(data: DataBaseEntryRecord);

var
  ActiveRecord                          : DataListEntryPointer;

begin
  if FirstMergeDataListEntry = nil then
     begin
     FirstMergeDataListEntry := New(DataListEntryPointer);
     FirstMergeDataListEntry^.NextEntry := nil;
     FirstMergeDataListEntry^.data := data;
     Exit;
     end;

  { We have some entries already - make sure it isn't a dupe }

  ActiveRecord := FirstMergeDataListEntry;

  repeat
    if ActiveRecord^.data.Call = data.Call then Exit; { dupe - ignore it }
    if ActiveRecord^.NextEntry = nil then Break;
    ActiveRecord := ActiveRecord^.NextEntry;
  until False;

  { Okay, this call does not appear in the merge list, so add it }

  ActiveRecord^.NextEntry := New(DataListEntryPointer);
  ActiveRecord := ActiveRecord^.NextEntry;
  ActiveRecord^.NextEntry := nil;
  ActiveRecord^.data := data;
end;

function CallDatabase.OverwriteFlagStatus: boolean;
begin

end;

procedure CallDatabase.DeleteLowHitCalls;
begin

end;

procedure CallDatabase.MovePossibleCallsFromBufferIntoCallList(Call: CallString);

label
  CallFound;

var
  EntryString                           : ShortString {string};
  Address                               : integer;
  data                                  : DataBaseEntryRecord;

begin
  if CellBuffer.NumberBufferEntries = 0 then Exit; { No calls to move }

  CellBuffer.ReadAddress := 0; { Rewind list }

  while CellBuffer.GetNextEntry(EntryString) do
     begin
     ParseEntryToDataRecord(EntryString, data);

     if SimilarCall(Call, data.Call) then
       if (PossibleCallAction <> OnlyCallsWithNames) or (data.mName <> '') then
         if PossibleCallList.NumberPossibleCalls < MaximumPossibleCalls then
            begin
            if PossibleCallList.NumberPossibleCalls > 0 then
               begin
               for Address := 0 to PossibleCallList.NumberPossibleCalls - 1 do
                 if PossibleCallList.List[Address].Call = data.Call then
                    begin
                    goto CallFound;
                    end;
               end;

                { Call not in list and there is room for it }

            with PossibleCallList do
               begin
               List[NumberPossibleCalls].Call := data.Call;
               List[NumberPossibleCalls].Dupe := False;
               inc(NumberPossibleCalls);
               end;
            end;

     CallFound:
     end;
end;

procedure CallDatabase.GeneratePossibleCallList(Call: CallString);

{ This procedure will generate a list of possible callsigns for the one
  entered.  The list will be stored in the PossibleCalls list with
  NumberPossibleCalls indicating the number of callsigns found. }

var
  FirstKeyPos, SecondKeyPos, CharPos    : integer;
  LowestCell, SecondLowestCell, ThirdLowestCell, BytesAtThisPos: LONGINT;
  LowestKeyPos, SecondLowestKeyPos, ThirdLowestKeyPos: integer;
  TempDupe, Change                      : boolean;
  Range, CallAddress              : integer;
  TempString                            : CallString;

begin
  PossibleCallList.NumberPossibleCalls := 0;

  if not LoadInIndexArray then Exit;

  FirstKeyPos := 0;
  LowestKeyPos := 0;
  SecondLowestKeyPos := 0;
  ThirdLowestKeyPos := 0;

  LowestCell := AVeryBigNumber;
  SecondLowestCell := AVeryBigNumber;
  ThirdLowestCell := AVeryBigNumber;

  for CharPos := 1 to length(Call) - 1 do
     begin
     BytesAtThisPos := NumberOfBytesAtThisAddress(Copy(Call, CharPos, 2));

     if BytesAtThisPos < LowestCell then
        begin
        ThirdLowestCell := SecondLowestCell;
        ThirdLowestKeyPos := SecondLowestKeyPos;

        SecondLowestCell := LowestCell;
        SecondLowestKeyPos := LowestKeyPos;

        LowestCell := BytesAtThisPos;
        LowestKeyPos := CharPos;
        end
     else
       if BytesAtThisPos < SecondLowestCell then
          begin
          ThirdLowestCell := SecondLowestCell;
          ThirdLowestKeyPos := SecondLowestKeyPos;

          SecondLowestCell := BytesAtThisPos;
          SecondLowestKeyPos := CharPos;
          end
       else
         if BytesAtThisPos < ThirdLowestCell then
            begin
            ThirdLowestCell := BytesAtThisPos;
            ThirdLowestKeyPos := CharPos;
            end;
     end;

  for CharPos := 1 to length(Call) - 1 do
    if Copy(Call, CharPos, 2) = CellBuffer.Key then
       begin { We have already read in a cell for this call }
       MovePossibleCallsFromBufferIntoCallList(Call);
       FirstKeyPos := CharPos;
       Break;
       end;

  if FirstKeyPos = 0 then { Current buffer was no help }
     begin
     if Abs(LowestKeyPos - SecondLowestKeyPos) >= 2 then
        begin
        FirstKeyPos := LowestKeyPos;
        SecondKeyPos := SecondLowestKeyPos;
        end
     else
       if Abs(LowestKeyPos - ThirdLowestKeyPos) >= 2 then
          begin
          FirstKeyPos := LowestKeyPos;
          SecondKeyPos := ThirdLowestKeyPos;
          end
       else
          begin
          FirstKeyPos := SecondLowestKeyPos;
          SecondKeyPos := ThirdLowestKeyPos;
          end;

     NewTwoLetters(Copy(Call, FirstKeyPos, 2));
     MovePossibleCallsFromBufferIntoCallList(Call);
     end
  else
    if Abs(FirstKeyPos - LowestKeyPos) >= 2 then
       begin
       SecondKeyPos := LowestKeyPos
       end
    else
      if Abs(FirstKeyPos - SecondLowestKeyPos) >= 2 then
         begin
         SecondKeyPos := SecondLowestKeyPos
         end
      else
         begin
         SecondKeyPos := ThirdLowestKeyPos;
         end;

  NewTwoLetters(Copy(Call, SecondKeyPos, 2));
  MovePossibleCallsFromBufferIntoCallList(Call);

  { Sort the calls into alphabetical order }

  if PossibleCallList.NumberPossibleCalls < 2 then Exit; { No sorting needed }

  Range := PossibleCallList.NumberPossibleCalls - 2;

  repeat
    with PossibleCallList do
       begin
       Change := False;

       for CallAddress := 0 to Range do
         if List[CallAddress].Call > List[CallAddress + 1].Call then
            begin
            TempString := List[CallAddress].Call;
            List[CallAddress].Call := List[CallAddress + 1].Call;
            List[CallAddress + 1].Call := TempString;

            TempDupe := List[CallAddress].Dupe;
            List[CallAddress].Dupe := List[CallAddress + 1].Dupe;
            List[CallAddress].Dupe := TempDupe;

            Change := True;
            end;
       end;

    dec(Range);
  until (not Change) or (Range < 0);
end;


function CallDatabase.GetRandomCall: CallString;

var
  Call                                  : CallString;

begin
  repeat
    Call := RandomCall;
  until not StringIsAllNumbers(Call);

  GetRandomCall := Call;
end;

function CallDatabase.RandomCall: CallString;

var
  NextX, NextY, X, Y                    : Word;
  StartingOffset, Address, EndingOffset, Range: LONGINT;
  MiniBuffer                            : array[0..63] of AnsiChar;
  Call                                  : CallString;

begin
  if not LoadInIndexArray then
     begin
     case Random(4) of
       0: RandomCall := GetRandomLetter +
         GetRandomNumber +
           GetRandomLetter +
           GetRandomLetter;

       1: RandomCall := GetRandomLetter +
         GetRandomNumber +
           GetRandomLetter +
           GetRandomLetter +
           GetRandomLetter;

       2: RandomCall := GetRandomLetter +
         GetRandomLetter +
           GetRandomNumber +
           GetRandomLetter +
           GetRandomLetter +
           GetRandomLetter;

       3: RandomCall := GetRandomLetter +
         GetRandomLetter +
           GetRandomNumber +
           GetRandomLetter;

     end;

     Exit;
     end;

  X := Random(37);
  Y := Random(36);

  StartingOffset := SCPIndexArray^[X, Y];

  NextY := Y + 1;
  NextX := X;

  if NextY > 36 then
     begin
     if X < 36 then
        begin
        NextX := X + 1;
        NextY := 0;
        EndingOffset := SCPIndexArray^[NextX, NextY];
        end
     else
        begin
        EndingOffset := SCPEndOfFile;
        end;
     end
  else
     begin
     EndingOffset := SCPIndexArray^[NextX, NextY];
     end;

  Range := EndingOffset - StartingOffset;

  while Range > 65000 do
     begin
     Range := Range - 32000;
     end;

  Address := Random(Range) + StartingOffset;

  if Address + SizeOf(MiniBuffer) >=
//  FileSize(TRMasterFileRead)
  Windows.GetFileSize(TRMasterFileRead, nil)
    then
     begin
     Address := (Windows.GetFileSize(TRMasterFileRead, nil) {FileSize(TRMasterFileRead)} - SizeOf(MiniBuffer)) - 5;
     end;

//  Seek(TRMasterFileRead, Address);
  Windows.SetFilePointer(TRMasterFileRead, Address, nil, FILE_BEGIN);

  sReadFile(TRMasterFileRead, MiniBuffer, SizeOf(MiniBuffer));

  Address := 0;

  while MiniBuffer[Address] <> NullCharacter do
     begin
     inc(Address);

     if Address = 64 then
        begin
        RandomCall := 'N6TR';
        Exit;
        end;

     end;

  inc(Address);

  Call := '';

  while MiniBuffer[Address] > ControlZ do
     begin
     Call := Call + MiniBuffer[Address];
     inc(Address);

     if Address = 64 then
        begin
        while length(Call) < 4 do
           begin
           Call := Call + 'A';
           end;

        RandomCall := Call;
        Exit;
        end;
     end;

  RandomCall := Call;
end;

procedure CallDatabase.SCPDisableAndDeAllocateFileBuffer;

begin
  {   IF FileBuffer    <> nil THEN Dispose (FileBuffer);    6.43 }

  if TRMasterFileOpen then
     begin
     CloseHandle(TRMasterFileRead);
     Dispose(SCPIndexArray);
     TRMasterFileOpen := False;
     IndexArrayAllocated := False;
     end;

  SCPDisabledByApplication := True;
end;

procedure CallDatabase.ShowStatistics;

var
  Address, FileOffset                   : LONGINT;
  FileRead                              : file;
  BytesRead                             : Word;
  X, Y, Entry, NextX, NextY, StartingOffset, EndingOffset: LONGINT;
  EntryString                           : ShortString {string};
  DataRecord                            : DataBaseEntryRecord;

  TotalNames, TotalGrids, TotalSections, TotalCQZones, TotalFocs: LONGINT;
  TotalITUZones, TotalCalls, TotalChecks, TotalQTHs, TotalTenTens: LONGINT;
  NumberBytes, TotalOldCalls, TotalSpeeds: LONGINT;
  TotalUser1s, TotalUser2s, TotalUser3s, TotalUser4s, TotalUser5s: LONGINT;
  HitList                               : array[0..51] of LONGINT;
  KeyString, TempString                 : Str20;

begin
  //  ShowMessage('TRMASTER DATABASE STATISTICS');

  //  Write('Computing totals for cell AA');

  if SCPIndexArray = nil then { Make sure index array is loaded }
    if not LoadInIndexArray then
       begin
       //{WLI}            GoToXY (1, WhereY);
       //{WLI}            ClrEol;
     ShowMessage(TC_NOTRMASTERDTAFILEFOUND);
       //{WLI}            WaitForKeyPressed;
     Exit;
       end;

  { Initialize counts }

  TotalCalls := 0;
  TotalNames := 0;
  TotalGrids := 0;
  TotalSections := 0;
  TotalCQZones := 0;
  TotalFocs := 0;
  TotalITUZones := 0;
  TotalChecks := 0;
  TotalOldCalls := 0;
  TotalQTHs := 0;
  TotalTenTens := 0;
  TotalSpeeds := 0;
  TotalUser1s := 0;
  TotalUser2s := 0;
  TotalUser3s := 0;
  TotalUser4s := 0;
  TotalUser5s := 0;

  for Entry := 0 to 51 do
     begin
     HitList[Entry] := 0;
     end;

  for X := 0 to 36 do
     begin
     for Y := 0 to 36 do
        begin
        //{WLI}            GoToXY (WhereX - 2, WhereY);
      KeyString := GetSCPCharFromInteger(X) + GetSCPCharFromInteger(Y);
        //{WLI}            Write (KeyString);

      StartingOffset := SCPIndexArray^[X, Y];

      NextY := Y + 1;
      NextX := X;

      if NextY > 36 then
         begin
         if X < 36 then
            begin
            NextX := X + 1;
            NextY := 0;
            EndingOffset := SCPIndexArray^[NextX, NextY];
            end
         else
            begin
            EndingOffset := SCPEndOfFile;
            end;
         end
      else
         begin
         EndingOffset := SCPIndexArray^[NextX, NextY];
         end;

      if (X <> 0) or (Y <> 0) then
         begin
         if FilePos(FileRead) <> StartingOffset then
            begin
            Close(FileRead);
            Assign(FileRead, string(ActiveFilename));
            Reset(FileRead, 1);
            Seek(FileRead, StartingOffset);
            end;
         end
      else
         begin
         Assign(FileRead, string(ActiveFilename));
         Reset(FileRead, 1);
         Seek(FileRead, StartingOffset);
         end;

      if StartingOffset < EndingOffset then
         begin
         NumberBytes := EndingOffset - StartingOffset;

         if NumberBytes > BufferArraySize * 3 then
            begin
                 //        WriteLn;
 //          showmessage(GetSCPCharFromInteger(x) + GetSCPCharFromInteger(y) + ' cell is too large - 5!!');
           halt;
         end;

 //        CellBuffer.LoadCellIntoBuffer(KeyString, FileRead, NumberBytes);

         while CellBuffer.GetNextEntry(EntryString) do
            begin
            ParseEntryToDataRecord(EntryString, DataRecord);

            if FirstCellForThisCall(DataRecord.Call, X, Y) then
               begin
               inc(TotalCalls);

               with DataRecord do
                  begin
                  if mName <> '' then
                     begin
                     inc(TotalNames);
                     end;
                  if Grid <> '' then
                     begin
                     inc(TotalGrids);
                     end;
                  if Section <> '' then
                     begin
                     inc(TotalSections);
                     end;
                  if CQZone <> '' then
                     begin
                     inc(TotalCQZones);
                     end;
                  if FOC <> '' then
                     begin
                     inc(TotalFocs);
                     end;
                  if ITUZone <> '' then
                     begin
                     inc(TotalITUZones);
                     end;
                  if Check <> '' then
                     begin
                     inc(TotalChecks);
                     end;
                  if QTH <> '' then
                     begin
                     inc(TotalQTHs);
                     end;
                  if OldCall <> '' then
                     begin
                     inc(TotalOldCalls);
                     end;
                  if Speed > 0 then
                     begin
                     inc(TotalSpeeds);
                     end;
                  if TENTEN <> '' then
                     begin
                     inc(TotalTenTens);
                     end;
                  if User1 <> '' then
                     begin
                     inc(TotalUser1s);
                     end;
                  if User2 <> '' then
                     begin
                     inc(TotalUser2s);
                     end;
                  if User3 <> '' then
                     begin
                     inc(TotalUser3s);
                     end;
                  if User4 <> '' then
                     begin
                     inc(TotalUser4s);
                     end;
                  if User5 <> '' then
                     begin
                     inc(TotalUser5s);
                     end;

                  if Hits <= 50 then
                     begin
                     inc(HitList[Hits])
                     end
                  else
                     begin
                     inc(HitList[51]);
                     end;
                  end;
               end;
            end;
         end;
        end;
     end;

  ShowMessage(TC_HITCOUNTHISTOGRAM050);
  {
      FOR Entry := 0 TO 51 DO
          BEGIN
          IF WhereX > 68 THEN WriteLn;

          IF Entry < 51 THEN
              Write (Entry:3, ': ', HitList [Entry])
          ELSE
              Write ('More than 50 = ', HitList [51]);

          WHILE ((WhereX MOD 12) <> 0) AND (WhereX < 77) DO Write (' ');
          END;
  }
  //{WLI}    WriteLn;
  //{WLI}    WaitForKeyPressed;
end;

procedure ShowNameEditorCommands;

begin
  {    ClearScreenAndTitle ('TRMASTER NAME EDITOR PROGRAM');

      WriteLn ('This editor allows you to quickly edit the names in your TRMASTER database.');
      WriteLn;
      WriteLn ('Since the TRMASTER.DTA file can''t be edited quickly, this procedure will');
      WriteLn ('stop occasionally to update the files.  Because of this, the changes you');
      WriteLn ('had just typed in will not take effect until this process occurs.');
      WriteLn;
      WriteLn ('Changes are first made to the TRMASTER.ASC file.  They are not saved in');
      WriteLn ('the TRMASTER.DTA file until the end of this procedure.');
      WriteLn;
      WriteLn ('Single letter commands: C - Toggle CW sending of names.');
      WriteLn ('                        D - Delete a call from the database.');
      WriteLn ('                        F - Make ASCII file with calls and names.');
      WriteLn ('                        X - Quit editing and save changes.');
      WriteLn;
     }
end;

function CallHasNoNumber(Call: CallString): boolean;

var
  CharPointer                           : integer;

begin
  if Call = '' then
     begin
     CallHasNoNumber := True;
     Exit;
     end;

  CallHasNoNumber := False;

  for CharPointer := 1 to length(Call) do
    if ((Call[CharPointer] >= '0') and (Call[CharPointer] <= '9')) then
       begin
       Exit;
       end;

  CallHasNoNumber := True;
end;

procedure CallDatabase.CheckDTAFile;

{ This procedure will do the following:

    1. Load in the index file of the TRMASTER.DTA file.

    2. Check to see if the JA cell has stuff in it - if so, the .DTA
       file will be rewritten with no calls in the JA cell.

    3. Check to make sure no remaining cell is over BufferArraySize
       bytes and if so - truncate it.

  The result is a new .DTA file.  The .ASC file is not changed. }

begin

end;

{ --------------------------------------------------------------------------
  Operator name set — built once from TRMASTER.DTA, searched by callers
  that need to recognise a token as an operator name.
  -------------------------------------------------------------------------- }

procedure CallDatabase.BuildOperatorNameSet(Names: TStringList);
{ Opens a private read handle to TRMASTER.DTA, walks every 37×37 cell,
  and adds each non-empty operator name (uppercased) to Names.
  The shared TRMasterFileRead handle and CellBuffer state are untouched. }
var
   FileHandle  : HWND;
   LocalBuf    : CellBufferObject;
   X           : Integer;
   Y           : Integer;
   StartOffset : LONGINT;
   EndOffset   : LONGINT;
   NumBytes    : LONGINT;
   EntryStr    : ShortString;
   Rec         : DataBaseEntryRecord;
begin
   if not LoadInIndexArray then
      begin
      Exit;
      end;
   if not tOpenFileForRead(FileHandle, ActiveFilename) then
      begin
      Exit;
      end;
   FillChar(LocalBuf, SizeOf(LocalBuf), 0);
   LocalBuf.MaximumMemoryToUse := BufferArraySize;
   try
      for X := 0 to 36 do
         begin
         for Y := 0 to 36 do
            begin
            StartOffset := SCPIndexArray^[X, Y];
            { End offset = start of the next cell; the very last cell uses SCPEndOfFile }
            if Y < 36 then
               begin
               EndOffset := SCPIndexArray^[X, Y + 1]
               end
            else if X < 36 then
               begin
               EndOffset := SCPIndexArray^[X + 1, 0]
               end
            else
               begin
               EndOffset := SCPEndOfFile;
               end;
            NumBytes := EndOffset - StartOffset;
            if NumBytes <= 0 then
               begin
               Continue;
               end;
            if NumBytes > BufferArraySize then
               begin
               NumBytes := BufferArraySize;
               end;
            Windows.SetFilePointer(FileHandle, StartOffset, nil, FILE_BEGIN);
            LocalBuf.LoadCellIntoBuffer('', FileHandle, NumBytes);
            while LocalBuf.GetNextEntry(EntryStr) do
               begin
               ParseEntryToDataRecord(EntryStr, Rec);
               if Rec.mName <> '' then
                  begin
                  Names.Add(UpperCase(Rec.mName));
                  end;
               end;
            end;
         end;
   finally
      LocalBuf.GoAway;
      CloseHandle(FileHandle);
      end;
end;

procedure InitOperatorNameSet;
{ Builds OperatorNameSet from TRMASTER.DTA on first call (idempotent).
  MasterFileExists is set at startup before ActiveFilename is populated,
  so we do a live check here now that the contest has set the filename. }
begin
   if OperatorNameSet <> nil then
      begin
      Exit;
      end;
   CD.MasterFileExists := (CD.ActiveFilename[0] <> #0) and
      FileExists(CD.ActiveFilename);
   if not CD.MasterFileExists then
      begin
      logger.Debug('InitOperatorNameSet: TRMASTER.DTA not found — name lookup disabled');
      Exit;
      end;
   OperatorNameSet            := TStringList.Create;
   OperatorNameSet.Sorted     := True;
   OperatorNameSet.Duplicates := dupIgnore;
   CD.BuildOperatorNameSet(OperatorNameSet);
   logger.Debug('OperatorNameSet: ' + IntToStr(OperatorNameSet.Count) +
      ' names loaded from TRMASTER.DTA');
end;

function NameInOperatorSet(const AName: string): Boolean;
begin
   Result := (OperatorNameSet <> nil) and
      (OperatorNameSet.IndexOf(UpperCase(AName)) >= 0);
end;

begin

//  CD.CellBuffer.Buffer1Used := False;
//  CD.CellBuffer.Buffer2Used := False;
//  CD.CellBuffer.Buffer3Used := False;

  CD.CellBuffer.MaximumMemoryToUse := 3 * BufferArraySize;

//  CD.CellBuffer.MemoryAllocated := 0;

//  CD.SCPDisabledByApplication := False;

//  CD.ASCIIFileCrunchCallToRemove := '';
//  CD.ASCIIFileIsCurrent := False;
  CD.ActiveASCIIFileName := ASCIIFileName;
//  CD.CountryString := '';

//  CD.CellBuffer.Key := '';
//  CD.PossibleCallAction := OnlyCallsWithNames;
//  CD.FirstMergeDataListEntry := nil;
//  CD.InitialPartialList := nil;
//  CD.SCPIndexArray := nil;
//  CD.SectionOverwrite := False;
//  CD.CQZoneOverwrite := False;
//  CD.FOCOverwrite := False;
//  CD.GridOverwrite := False;
  CD.HitsOverwrite := True;
//  CD.TRMasterFileOpen := False;
//  CD.IndexArrayAllocated := False;
//  CD.ITUZoneOverwrite := False;
//  CD.CheckOverwrite := False;
//  CD.NameOverwrite := False;
//  CD.NumberDeleteCalls := 0;
//  CD.OldCallOverwrite := False;
//  CD.QTHOverwrite := False;
//  CD.SpeedOverwrite := False;
//  CD.TenTenOverwrite := False;
//  CD.User1Overwrite := False;
//  CD.User2Overwrite := False;
//  CD.User3Overwrite := False;
//  CD.User4Overwrite := False;
//  CD.User5Overwrite := False;

end.

