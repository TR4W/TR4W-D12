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
unit LogDupe;
{$I ..\tr4w.inc}

{ This unit contains the objects DupeSheet and MultSheet.  It has all
  of the methods required to use them. }

{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  Classes,   // TStringList -- the cache in SaveRestartFile
utils_text,
  uCallSignRoutines,
  uMults,
  uCallsigns,
  (* LCLType, not Windows (2026-09-08): the four CloseHandle calls were every
    one on a FILE handle -- SysUtils.FileClose -- and MAXBYTE / MAXWORD are
    LCLType's, with the same values. *)
  LCLType,
  VC,
  TF,
  LogDom,
  Tree,
  utils_file,
  //Country9,
  ZoneCont,
  LogWind,
  LogRadio,
  LogSCP
  ,
  uTR4WStrings,
  uAnsiStr;

const
  MaxGridSquaresInList                  = 40;

//  TwoLetterPartialCallListLength        = 500;
//  DomesticMultArraySize                 = 400 + 300; {RDAC}
//  DXMultArraySize                       = MaxCountries {UA4WLI};
//  PrefixMultArraySize                   = 1500;

  MaxVisDupeCallTotal                   = 40;
  MaxInitialExchanges                   = 60000; // 4.86.4
  MaxLongPartialCalls                   = 150;

  { Note that the four byte and eight byte blocks must be the same
    size due to how the initial exchange stuff works.        }

  FourByteBlockSize                     = 200; { Used for both calls and prefixes }
  EightByteBlockSize                    = 100; { Used for calls > 6 characters }
  PartialCallBlockSize                  = 200;

  MaxCallBlocks                         = 50; { Per band mode }
  MaxBigCallBlocks                      = 20; { Total in dupesheet }
  MaxPartialCallBlocks                  = 100;

type
  RestartInfo = record
    riPTTOnTotalTime: Cardinal;
    riQSOByOpMode: array[OpModeType] of Cardinal;
    riTotalRecordsInLog: integer;
    riCQTotalCounter: Cardinal;
//    riGetScoresClassArray: array[101..103] of integer;
//    riColumnsWidthArray: array[LogColumnsType] of integer;
  end;

  {
    LongPartialCallListType = array[0..MaxLongPartialCalls] of EightBytes;
    LongPartialCallListPointer = ^LongPartialCallListType;
  }
  //  InitialExchangeArray = array[1..MaxInitialExchanges] of EightBytes;
  //  InitialExchangeArrayPointer = ^InitialExchangeArray;
  {
    PartialCallType = record
      Call: FourBytes;
      InitialExchangeIndex: integer;
    end;

    PartialCallArray = array[0..PartialCallBlockSize - 1] of PartialCallType;
    PartialCallArrayPtr = ^PartialCallArray;
  }
  CallDistrictRecord = record
    List: array[0..MaxVisDupeCallTotal] of string[6];
    Total: integer;
  end;

//  VisibleDupesheet = array[1..10] of CallDistrictRecord;

  StateType = (NoStates, State48, State49, State50);

  ProvinceType = (NoProvinces, Province8, Province11, Province12, Province13);

//  DomesticMultArray = array[0..DomesticMultArraySize - 1] of FourBytes;
//  DXMultArray = array[0..DXMultArraySize - 1] of FourBytes;
//  PrefixMultArray = array[0..PrefixMultArraySize - 1] of FourBytes;
//  ZoneMultArray = array[0..ZoneMultArraySize - 1] of FourBytes;

//  DomesticMultArrayPtr = ^DomesticMultArray;
//  DXMultArrayPtr = ^DXMultArray;
//  PrefixMultArrayPtr = ^PrefixMultArray;
//  ZoneMultArrayPtr = ^ZoneMultArray;

//  FourByteBlockArray = array[0..FourByteBlockSize - 1] of FourBytes;
  EightByteBlockArray = array[0..EightByteBlockSize - 1] of EightBytes;

//  CallBlockPtr = ^FourByteBlockArray;
//  BigCallBlockPtr = ^EightByteBlockArray;
//  FourBytePtr = ^FourBytes;
{
  MultTotals = record
    NumberDomesticMults: integer;
    NumberDXMults: integer;
    NumberPrefixMults: integer;
    NumberZoneMults: integer;
  end;
}
  QSOTotalArray = array[BandType, CW..Both] of integer;
//  MultTotalArrayType = array[BandType, CW..Both] of MultTotals;
{
  MultList = record
//    Totals: MultTotalArrayType;
//    DomesticList: array[BandType, CW..Both] of DomesticMultArrayPtr;
//    DXList: array[BandType, CW..Both] of DXMultArrayPtr;
//    PrefixList: array[BandType, CW..Both] of PrefixMultArrayPtr;
//    ZoneList: array[BandType, CW..Both] of ZoneMultArrayPtr;
  end;
}
  DupeList = record
    Totals: QSOTotalArray;
    //    NumberBigCalls: integer;
    //    DupeList: array[BandType, CW..Both, 1..MaxCallBlocks] of CallBlockPtr;
    //    BigCallList: array[1..MaxBigCallBlocks] of BigCallBlockPtr;
  end;

  VDEntry = record
    Callsign: string[6];
    NextEntry: Pointer;
  end;

  VDEntryPointer = ^VDEntry;

  //  CallDistrictTotalArray = array[1..11] of integer;

  DupeAndMultSheet = object
    DupeSheetEnable: boolean;
    tAutoReset: boolean;
    //    DupeSheet: DupeList;
//    MultSheet: MultList;

    function AddBigCallAddress(BigCall: EightBytes): integer;
    procedure AddCallToVisibleDupeSheet(Callsign: CallString);
    procedure AddCompressedCallToDupeSheet(Call: FourBytes; Band: BandType; Mode: ModeType);
    procedure AddQSOToSheets(RXData: ContestExchangePtr; AddToPartials: boolean);

    //    function CallIsADupe(Call: CallString; Band: BandType; Mode: ModeType): boolean;

//    procedure CancelOutNewDomesticMultWeHaveWorked(MultString: Str20;      Band: BandType;      Mode: ModeType);

//    procedure CancelOutNewDXMultWeHaveWorked(MultString: DXMultiplierString ;      Band: BandType;      Mode: ModeType);

//    procedure CancelOutNewZoneMultWeHaveWorked(MultString: integer; Band: BandType; Mode: ModeType);
//    procedure CancelOutRemainingMultsWeHaveWorked(Band: BandType; Mode: ModeType; multtype: RemainingMultiplierType);

    //    procedure ClearDupeSheet;

        //    procedure CreateVisibleDupeSheetArrays(var Band: BandType;      Mode: ModeType);

    function TwoLetterCrunchProcess(PartialCall: {Call} string): boolean;

    procedure DisposeOfMemoryAndZeroTotals;

    function IsADomesticMult(Mult: Str10; Band: BandType; Mode: ModeType): boolean;

    procedure DupeSheetTotals(var Totals: QSOTotalArray);

    //    function EntryExists(Entry: FourBytes; Band: BandType; Mode: ModeType): boolean;
    procedure ExamineLogForQSOTotals(var QTotals: QSOTotalArray);

    //    procedure MakePartialCallList(Call: CallString;      ActiveBand: BandType;      ActiveMode: ModeType;      var PossCallList: PossibleCallRecord);

    procedure MakePossibleCallList(Call: CallString; var PossCallList: PossibleCallRecord);

//    procedure MultSheetTotals(var Totals: MultTotalArrayType);

    function ReadInBinFiles {(JustDoIt: boolean)}: boolean;

    procedure SetMultFlags(var RXData: ContestExchange);
    procedure SetUpRemainingMultiplierArrays;

    procedure SaveRestartFile;

    procedure SheetInitAndLoad;
  end;

const
  DXMultTypenameArray                   : array[DXMultType] of PAnsiChar =
    (
//    'NO COUNT', //    NoCountDXMults,
    'NONE', //    NoDXMults,
    'ARRL DXCC WITH NO USA OR CANADA', //    ARRLDXCCWithNoUSAOrCanada,
    'ARRL DXCC WITH NO ARRL SECTIONS', //    ARRLDXCCWithNoARRLSections,
    'ARRL DXCC WITH NO USA CANADA KH6 OR KL7', //    ARRLDXCCWithNoUSACanadaKH6OrKL7,
    'ARRL DXCC WITH NO I OR IS0', //    ARRLDXCCWithNoIOrIS0,
    'ARRL DXCC WITH NO JT',
    'ARRL DXCC', //    ARRLDXCC,
    'CQ DXCC', //    CQDXCC,
    'CQ DXCC WITH NO USA OR CANADA', //    CQDXCCWithNoUSAOrCanada,
    'CQ DXCC WITH NO HB9', //    CQDXCCWithNoHB9,

    'CQ DXCC WITH NO OK',
    'CQ EUROPEAN COUNTRIES', //    CQEuropeanCountries,
    'CQ UBA EUROPEAN COUNTRIES', //    CQUBAEuropeanCountries,
    'CQ NON EUROPEAN COUNTRIES', //    CQNonEuropeanCountries,
    'NORTH AMERICAN ARRL DXCC WITH NO USA CANADA OR KL7', //    NorthAmericanARRLDXCCWithNoUSACanadaOrkL7,
    'NON SOUTH AMERICAN COUNTRIES', //    NonSouthAmericanCountries,
    'PACC COUNTRIES AND PREFIXES', //    PACCCountriesAndPrefixes,
 //   'CQ NON EUROPEAN COUNTRIES AND WAE', //    CQNonEuropeanCountriesAndWAECallRegions
    'BLACK SEA COUNTRIES'
    );
var

  InitialExCallsigns                    : integer;
  InitialExDupes                        : integer;

  tAllowDupeQSOs                        : boolean = False;
  // Issue #1034: ActiveDXMult moved to VC.pas (light home) so uMults can read it
  // without depending on LogDupe. All users resolve it via VC (universally used).
  ActivePrefixMult                      : PrefixMultType {= NoPrefixMults};

  AutoDupeEnableCQ                      : boolean = False;
  AutoDupeEnableSandP                   : boolean = True;


  CallsignUpdateEnable                  : boolean;
  CountDomesticCountries                : boolean;
//  CQP                                   : boolean;

  DoingDomesticMults                    : boolean;
  DoingDXMults                          : boolean;
  DoingPrefixMults                      : boolean;
  DoingZoneMults                        : boolean;

  DomQTHDataFileName                    : FileNameType;

  ExchangeInformation                   : ExchangeInformationRecord;
  ExchangeMemoryEnable                  : boolean = True;

  FirstVDEntry                          : VDEntryPointer;

  GridSquareList                        : array[0..MaxGridSquaresInList - 1] of string[4];


  //  InitialExchangeList              : InitialExchangeArrayPointer = nil;

  LastPartialCall                       : CallString;
  LastPartialCallBlock                  : integer;
  LastTwoLetterCrunchedAddress          : integer;
  LastTwoLettersCrunchedOn              : Str20 {= ''};
  //  LoadingInLogFile                      : boolean;
  //  LongPartialCallList              : LongPartialCallListPointer = nil;

  MultByBand                            : boolean;
  MultByMode                            : boolean;
  MultReset                             : boolean = False;
  MultiplierAlarm                       : boolean;

  NumberDifferentMults                  : Byte {= 0};
  NumberGridSquaresInList               : Byte;
  NumberInitialExchanges                : integer;
  NumberLongPartialCalls                : integer;
  NumberPartialCalls                    : integer;
  NumberTwoLetterPartialCalls           : integer;
  NumberVDCalls                         : integer;

  OffTimeStart                          : TimeRecord;

  //  PartialCallList                  : array[1..MaxPartialCallBlocks] of PartialCallArrayPtr;
  PartialCallLoadLogEnable              : boolean = {false} True;

  QSOByBand                             : boolean;
  QSOByMode                             : boolean;
  QSOTotals                             : QSOTotalArray; { This may not also be exactly the same as
  DupeList.Totals because of dupes read in }

  // Issue #954: highest serial (NumberSent) actually sent, tracked per band
  // (the AllBands index is the whole-station high-water mark).  The next serial
  // to send is this value + 1 -- see NextSerialToSend in LOGEDIT.  It is kept in
  // lockstep with QSOTotals (zeroed in the dupe-sheet reset, updated in LoadinLog
  // and in the live add), but UNLIKE QSOTotals it INCLUDES X-QSO records (they
  // consumed a number) and EXCLUDES deleted ones.  That is what stops marking a
  // QSO X-QSO -- or deleting a mid-log QSO -- from rolling the serial backward
  // and re-issuing a number already sent on the air.
  MaxSerialSent                         : array[BandType] of integer;

  RemainingMultDisplay                  : RemainingMultiplierType = rmNoRemMultDisplay;
  (* What SaveRestartFile last wrote, so it can write only what changed.
    Session-lifetime and deliberately NOT persisted -- it describes the
    database's contents, and on the next run the database speaks for
    itself. *)
  GLastWritten: TStringList = nil;
  GSessionDirty: boolean = False;

//  RemMultMatrix                         : array[Band160..All, CW..Both, RemainingMultiplierType] of RemainingMultListPointer;

  (* RestartVersionNumber DELETED 2026-09-12. It existed because the .RST
    file was a raw struct dump whose layout changed whenever a field did.
    A row per value needs no version: an absent row reads as a default. *)
  SingleBand                            : BandType = AllBands;
  StartHour, StartMinute, StartSecond, StartSec100: Word;

  TakingABreak                          : boolean;
  TotalOffTime                          : integer;

  TimeElasped                           : array[1..20] of LONGINT;

  TotalNamesSent                        : integer;
  TotalQSOPoints                        : LONGINT {= 0};
  MOQSOPartyW0MAWorked                  : Boolean;   // W0MA worked at least once (+100 flat bonus)
  MOQSOPartyK0GQWorked                  : Boolean;   // K0GQ worked at least once (+100 flat bonus)
  MOQSOPartyPeakHourCount               : Integer;   // 40/80m QSOs in 1400-2000 UTC window (max 250)
//  TwoLetterCrunchPartialCallList        : array[0..TwoLetterPartialCallListLength] of integer;

  //  tTotalRecordsInLog               : integer;
  tRestartInfo                          : RestartInfo;

  //  DTR, RTS                              : boolean;

//procedure AddCallToPartialList(Call: CallString; InitialExchange: CallString);

procedure CheckMOQSOPartyBonusStation(const Callsign: CallString);
function BigEntryAddress(Entry: FourBytes): integer;

function CallNotInPossibleCallList(Call: CallString; PossCallList: PossibleCallRecord): boolean;

procedure ClearContestExchange(var Exchange: ContestExchange);
procedure CreateGridSquareList(Call: CallString; Band: BandType);

procedure DupeInit;
//function FindProperPartialCallAddress(Call: CallString): integer;
function FoundDomesticQTH(var RXData: ContestExchange): boolean;

procedure GetDXQTH(var RXData: ContestExchange);
//function GetInitialExchange(Call: CallString): CallString;
function GetInitialExchangeStringFromContestExchange(RData: ContestExchange): string;
procedure GetMultsFromLogEntry(LogEntry: Str80; var RXData: ContestExchange);
//function GetPartialCall(CallAddress: integer): CallString;

procedure LoadInitialExchangeFile;
procedure EnumInitialEx(FileString: PShortString);

function ParseExchangeIntoContestExchange(LogEntry: string;
  var RXData: ContestExchange): boolean;

function PointsToBigCall(Entry: FourBytes): boolean;


procedure SetUpExchangeInformation(ActiveExchange: ExchangeType;
  var ExchangeInformation: ExchangeInformationRecord
  );

{procedure TransferLogEntryInfoToContestExchange(LogEntry: Str80; var RXData: ContestExchange); }
{
procedure SetDupeBit(var b: Byte);
procedure ResetDupeBit(var b: Byte);
function GetDupeBit(b: Byte): boolean;

function GetDeletedBit(b: Byte): boolean;
procedure SetDeletedBit(var b: Byte);
procedure ResetDeletedBit(var b: Byte);

function GetSPBit(b: Byte): boolean;
procedure SetSPBit(var b: Byte);
procedure ResetSPBit(var b: Byte);

function GetSendBit(b: Byte): boolean;
procedure SetSendBit(var b: Byte);
procedure ResetSendBit(var b: Byte);
}
//procedure SetStatusBit(var StatusByte: Byte; Bit: CEBits);
//procedure ResetStatusBit(var StatusByte: Byte; Bit: CEBits);
//function GetStatusBit(StatusByte: Byte; Bit: CEBits): boolean;

implementation

//{WLI}{$I RemMults}
uses
  //  OZCHR,
  uConfigValues,
  uSettingsModel,   // Settings.CallWindow
  (* The contest database replaced the .RST restart file -- see
    SaveRestartFile. IMPLEMENTATION-section, so no interface cycle. *)
  uLogStore,
  uLogRepository,   // CharArrayToAnsi -- NUL-aware, not a cast
  TypInfo,          // enum names, so an inserted band cannot shift a value
  uNet,
  uGetScores,
  PostUnit,
//  uStack,
  MainUnit;

procedure CreateGridSquareList(Call: CallString; Band: BandType);

//var
  //FileRead                              : Text;
 // TempString                            : string; //{WLI}
  //FileString                            : Str80;

begin
end;

function FoundDomesticQTH(var RXData: ContestExchange): boolean;

{ This function will look at the domestic QTH in the contest exchange and
  see if it can figure out what it is.  If so, it will be converted to
  the standard name for the QTH and a TRUE response generated.  Otherwise
  it will be cleared out and a FALSE response generated.  It looks at
  ActiveDomesticMultiplier to see what type of domestic mult it is.  }

var
  QTHString                             : ShortString {Str40}; //{WLI}
 // CharacterPointer                      : integer;

begin
  FoundDomesticQTH := False;

   if RXData.QTHString = '' then
      begin
      logger.error('[FoundDomesticQTH] RXData.QTHString is blank');
      Exit;
      end;

  QTHString := UpperCase(RXData.QTHString);

  if StringHas(QTHString, '/') then
     begin
     QTHString := PrecedingString(QTHString, '/');
     end;

  GetRidOfPrecedingSpaces(QTHString);
  GetRidOfPostcedingSpaces(QTHString);
  if QTHString = 'XXX' then
     begin
     FoundDomesticQTH := True;
     exit;
     end;
  FoundDomesticQTH := DomQTHTable.GetDomQTH(QTHString, RXData.DomMultQTH, RXData.DomesticQTH);


 end;

function GetInitialExchangeIndex(InitialExchange: CallString): integer;

{ This routine will return the appropriate InitialExchangeIndex for the
  initial exchange passed to it.  This is the address that the initial
  exchange can be found in the InitialExchangeList.  If the initial
  exchange can't be found in the list - it will be added to the end
  of the list (if there is room) and that address returned.

  If the initial exchange can't be added to the list (because it is
  full) it will return with zero.

  The initial exchange list starts at 1.

}

var
  TempBytes                             : EightBytes;
  //Address                               : integer;

begin
  GetInitialExchangeIndex := 0; { Default in case we can't do it }

  if InitialExchange = '' then Exit; { Nothing to do with this }

  BigCompressFormat(InitialExchange, TempBytes);

  { See if there is a list to look at.  If not, create the list and
    make this the first entry. }

  if NumberInitialExchanges = 0 then { First one - allocate memory }
     begin
     {WLI}
     //{WLI}        IF MaxAvail > SizeOf (InitialExchangeArray) THEN
   begin
       //        if InitialExchangeList = nil then New(InitialExchangeList);
       //        inc(NumberInitialExchanges);
       //        InitialExchangeList^[NumberInitialExchanges] := TempBytes;
       //        GetInitialExchangeIndex := NumberInitialExchanges;
   end;
     {        ELSE
                  BEGIN
                  DoABeep (Single);
                  QuickDisplay (TC_ENOUGHMEMORYINITIALEXCHANGEARRAY);
                  ReminderPostedCount := 30;
                  END;

              Exit;
             }
     end;

  { Search the list for this entry }

  if NumberInitialExchanges > MaxInitialExchanges then Exit; //wli
  {
    for Address := 1 to NumberInitialExchanges do
      if (TempBytes[1] = InitialExchangeList^[Address][1]) and
        (TempBytes[2] = InitialExchangeList^[Address][2]) and
        (TempBytes[3] = InitialExchangeList^[Address][3]) and
        (TempBytes[4] = InitialExchangeList^[Address][4]) and
        (TempBytes[5] = InitialExchangeList^[Address][5]) and
        (TempBytes[6] = InitialExchangeList^[Address][6]) and
        (TempBytes[7] = InitialExchangeList^[Address][7]) and
        (TempBytes[8] = InitialExchangeList^[Address][8]) then
        begin
          GetInitialExchangeIndex := Address; // Found it!!
          Exit;
        end;
  }
    { Not found in the list.  Add it to end if there is room. }

  if NumberInitialExchanges < MaxInitialExchanges then
     begin
     //      inc(NumberInitialExchanges);
     //      InitialExchangeList^[NumberInitialExchanges] := TempBytes;
     //      GetInitialExchangeIndex := NumberInitialExchanges;
     end;
end;

procedure AddCallToPartialList(Call: CallString; InitialExchange: CallString);

//var
  //ProperAddress                         : integer;
 // Index, BlockNumber, BlockAddress      : integer;

begin
 {
    ProperAddress := FindProperPartialCallAddress(Call);

    if GetPartialCall(ProperAddress) = Call then
      begin
        BlockNumber := ProperAddress div FourByteBlockSize + 1;
        BlockAddress := ProperAddress mod FourByteBlockSize;

        Index := GetInitialExchangeIndex(InitialExchange);

        PartialCallList[BlockNumber]^[BlockAddress].InitialExchangeIndex := Index;
        Exit;
      end;

    SqueezeInPartialCall(Call, InitialExchange, ProperAddress);
   }
end;
{
function GetInitialExchange(Call: CallString): CallString;
// This procedure will return the initial exchange for the callsign passed  to it.  If there is no initial exchange, a null string will be returned.
var
  CallIndex                        : integer;
begin

  if FindStringInInitCallsignListBox(Call, CallIndex) then
    begin
      CallIndex := SendMessage(IntitialExCallsignsList, LB_GETITEMDATA, CallIndex, 0);
      SetLength(Result, 12);
      CallIndex := SendMessageA(IntitialExExchangesList, LB_GETTEXT, CallIndex, integer(@Result[1]));
      if CallIndex = LB_ERR then
        SetLength(Result, CallIndex);
    end
  else
    Result := '';
end;
}

function CallNotInPossibleCallList(Call: CallString;
  PossCallList: PossibleCallRecord): boolean;

var
  Entry                                 : integer;

begin
  CallNotInPossibleCallList := True;

  if PossCallList.NumberPossibleCalls = 0 then Exit;

  for Entry := 0 to PossCallList.NumberPossibleCalls - 1 do
    if Call = PossCallList.List[Entry].Call then
       begin
       CallNotInPossibleCallList := False;
       Exit;
       end;
end;

function PointsToBigCall(Entry: FourBytes): boolean;

begin
  PointsToBigCall := (Entry[1] = 255) and (Entry[4] = 255);
end;


function BigEntryAddress(Entry: FourBytes): integer;

{ Converts big entry string found in the entry list to an address where
  the entry can be found in the BigEntryList.  Starts at zero.  If there
  is an error, it will return with -1.                                   }

begin
  BigEntryAddress := (Entry[3] * 256) + Entry[2];
end;

procedure ClearContestExchange(var Exchange: ContestExchange);

begin
  logger.Trace('>>> Entering ClearContestExchange');
  FillChar(Exchange, SizeOf(ContestExchange), 0);
  Exchange.Band := NoBand;
  Exchange.Mode := NoMode;
  Exchange.ExtMode := eNoMode;
  Exchange.NumberReceived := -1;
  Exchange.NumberSent := -1;
  Exchange.Prefecture := MAXBYTE;
  Exchange.QTH.Zone := DUMMYZONE;
  Exchange.Zone := DUMMYZONE;
//  Exchange.PrefixMult := False;
  Exchange.QTH.Continent := UnknownContinent;
  Exchange.QTH.Country := UNKNOWN_COUNTRY;
  Exchange.TenTenNum := MAXWORD;
  Exchange.ceContest := Contest;
end;

function GetNumber(Call: CallString): AnsiChar;

var
  TempString, NumberString              : CallString;

begin
  GetNumber := '0';

  if (Call = '') or not StringHasNumber(Call) then Exit;

  TempString := GetPrefix(Call);

  NumberString := '';

  while (TempString <> '') and
    (Copy(TempString, length(TempString), 1) >= '0') and
    (Copy(TempString, length(TempString), 1) <= '9') do
     begin
     NumberString := Copy(TempString, length(TempString), 1) + NumberString;
     Delete(TempString, length(TempString), 1);
     end;

  GetNumber := NumberString[1];
end;

procedure GetDXQTH(var RXData: ContestExchange);

//var
  //ID                                    : string[6];
  //NumberChar                            : Char; {KK1L: 6.70}

begin
  if not CountDomesticCountries then
     begin
     if ActiveDomesticMult = WYSIWYGDomestic then
       if RXData.DomesticQTH <> '' then Exit;

     if DomesticCountryCall(RXData.Callsign) then Exit;
     end;

//R3DSS/E9
  case ActiveDXMult of

//    NoCountDXMults:      RXData.DXQTH := RXData.QTH.CountryID; { 6.60 }

    NoDXMults:
      {RXData.DXQTH := RXData.QTH.CountryID}; { 6.30 }

    ARRLDXCCWithNoUSAOrCanada, CQDXCCWithNoUSAOrCanada:
      if (RXData.QTH.CountryID <> 'K') and (RXData.QTH.CountryID <> 'VE') then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    ARRLDXCCWithNoARRLSections:
      if pos(' ' + RXData.QTH.CountryID + ' ', ARRLSectionCountryString) = 0 then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    ARRLDXCCWithNoUSACanadaKH6OrKL7:
      if (RXData.QTH.CountryID <> 'K') and (RXData.QTH.CountryID <> 'VE') and
        (RXData.QTH.CountryID <> 'KH6') and (RXData.QTH.CountryID <> 'KL') then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    ARRLDXCCWithNoIOrIS0:
//      if (RXData.QTH.CountryID <> 'I') and (RXData.QTH.CountryID <> 'IS') and (RXData.QTH.CountryID <> 'IT9') then
      if RXData.QTH.CountryID[1] <> 'I' then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    CQDXCCWithNoHB9: if RXData.QTH.CountryID <> 'HB' then RXData.DXQTH := RXData.QTH.CountryID;
    CQDXCCWithNoOK: if RXData.QTH.CountryID <> 'OK' then RXData.DXQTH := RXData.QTH.CountryID;
    ARRLDXCCWithNoJT: if RXData.QTH.CountryID <> 'JT' then RXData.DXQTH := RXData.QTH.CountryID;

    NorthAmericanARRLDXCCWithNoUSACanadaOrkL7:
      if (RXData.QTH.Continent = NorthAmerica) then
        if (RXData.QTH.CountryID <> 'K') and
          (RXData.QTH.CountryID <> 'VE') and
          (RXData.QTH.CountryID <> 'KL') then
           begin
           RXData.DXQTH := RXData.QTH.CountryID;
           end;

    CQEuropeanCountries:
      if (RXData.QTH.Continent = Europe) then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    CQUBAEuropeanCountries:
      if UBACountry(RXData.QTH.CountryID) then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    CQNonEuropeanCountries:
      if (RXData.QTH.Continent <> Europe) then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    NonSouthAmericanCountries:
      if RXData.QTH.Continent <> SouthAmerica then
         begin
         RXData.DXQTH := RXData.QTH.CountryID;
         end;

    BlackSeaCountries:
      begin
        if BlackSeaRegionCountry(RXData.QTH.CountryID) then
           begin
           RXData.DXQTH := RXData.QTH.CountryID;
           end;
      end;

    PACCCountriesAndPrefixes:
      begin
        if RXData.QTH.CountryID = 'UA9' then
           begin
           if StringHas(RXData.Callsign, '9') then
              begin
              RXData.DXQTH := 'UA9'
              end
           else
              begin
              RXData.DXQTH := 'UA0';
              end;

           Exit;
           end;

        if (RXData.QTH.CountryID = 'CE') or
          (RXData.QTH.CountryID = 'JA') or (RXData.QTH.CountryID = 'LU') or
          (RXData.QTH.CountryID = 'PY') or (RXData.QTH.CountryID = 'VE') or
          (RXData.QTH.CountryID = 'K') or (RXData.QTH.CountryID = 'VK') or
          (RXData.QTH.CountryID = 'ZS') or (RXData.QTH.CountryID = 'ZL') then
           begin
           RXData.DXQTH := RXData.QTH.CountryID + AnsiChar(GetNumber(RXData.Callsign));
           Exit;
           end;

        RXData.DXQTH := RXData.QTH.CountryID;
      end;

  else
    RXData.DXQTH := RXData.QTH.CountryID;
  end;
end;

procedure GetMultsFromLogEntry(LogEntry: Str80; var RXData: ContestExchange);

{ This procedure will look at the log entry string passed to it and
  based upon the active mutliplier flags determine what, if any multipliers
  are contained in the mult string.  Any multipliers found will be returned
  in it's proper variable.  All other variables will be set to the null
  string.                                                                }

//var
  //MultString                            : Str20;
  //Mult, NumberMults                     : integer;
  //MultArray                             : array[1..2] of Str20;

begin

end;

(*procedure TransferLogEntryInfoToContestExchange(LogEntry: Str80; var RXData: ContestExchange);

begin
  ClearContestExchange(RXData);
  RXData.Band := GetLogEntryBand(LogEntry);
  RXData.Mode := GetLogEntryMode(LogEntry);
  RXData.Callsign := GetLogEntryCall(LogEntry);
  GetMultsFromLogEntry(LogEntry, RXData);
  RXData.QTH.Prefix := RXData.Prefix;
end;
*)
function DupeAndMultSheet.AddBigCallAddress(BigCall: EightBytes): integer;

{ This function will return the proper big call array address for the
  big call entered.  If the call already exists in the big call array,
  then its address is returned.  If it does not exist, it is added to
  the end of the array and that address is returned.  This is done to
  eliminate double entries of big calls in this list, saving memory and
  making it easier to determine if a big call is a dupe on any given
  band or mode.                                                      }

//var
 // NumberCalls, NumberDupeBlocks, NumberEntriesInLastBlock, Block, EndAddress{, Address}: integer;
  //MaxAvail                              : integer;

begin

end;

procedure DupeAndMultSheet.AddCompressedCallToDupeSheet(Call: FourBytes; Band: BandType; Mode: ModeType);

{var
  NumberCalls, DupeBlock, BlockAddress  : integer;
  DupeBand                              : BandType;
  DupeMode                              : ModeType;
}
begin
  
end;

procedure DupeAndMultSheet.AddQSOToSheets(RXData: ContestExchangePtr; AddToPartials: boolean);

{ This procedure will take the information from the contest exchange passed
  to it and add the contact to the DupeAndMultSheet.  This is normally done
  with information after it has gone through the EditableWindow or when
  reading in the LOG.DAT file at the start.                               }

//var
//  {MultBand, }TempDOMBand               : BandType;
//  MultMode                              : ModeType;
begin

  if RXData.ceSearchAndPounce then
     begin
     inc(tRestartInfo.riQSOByOpMode[SearchAndPounceOpMode])
     end
  else
     begin
     inc(tRestartInfo.riQSOByOpMode[CQOpMode]);
     end;

  if not RXData.ceClearMultSheet then
//    if RXData.DomesticMult or RXData.DXMult or RXData.PrefixMult or RXData.ZoneMult then
     begin

     if RXData.DomesticMult then
        begin
        //        TempDOMBand := RXData.Band;
        //        if Contest in [RDA, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB] then TempDOMBand := All;
        //        mo.SetDmMult(RXData.DomMultQTH, TempDOMBand, RXData.Mode);
              mo.SetDmMult(RXData.DomMultQTH, RXData.Band, RXData.Mode);
        end;

     if RXData.DXMult then
        begin
        mo.SetDXMult(RXData.QTH.Country, RXData.Band, RXData.Mode);
        end;

     if RXData.PrefixMult then
        begin
        mo.SetPxMult(RXData.Prefix, RXData.Band, RXData.Mode);
        end;

     if RXData.ZoneMult then
        begin
        mo.SetZnMult(RXData.Zone, RXData.Band, RXData.Mode);
        end;
     end;
end;

function DupeAndMultSheet.TwoLetterCrunchProcess(PartialCall: {Call} string): boolean;

{ This process will work on generating the TwoLetterPartialList based upon
  the input provided.  It will return TRUE if there is a change to the list
  which means there might be changes in the partial call list. }

var
  Address, FirstAddress, LastAddress, NumberCallsToCrunch: integer;
  {GotPartialCall,} TempString            : Str20;
  FileWrite                             : Text;

begin
  TwoLetterCrunchProcess := False; { Assume no changes }

  if length(PartialCall) < 2 then Exit; { We don't do anything yet }
  if NumberPartialCalls = 0 then Exit; { No partial calls to look at }

  { Look to see if we have different first two letters than the last time
    this function was called.  If so, set up a brand new process with an
    empty list of callsigns. }

  if LastTwoLettersCrunchedOn <> Copy(PartialCall, 1, 2) then
     begin
     LastTwoLettersCrunchedOn := Copy(PartialCall, 1, 2);
     LastTwoLetterCrunchedAddress := -1;
     NumberTwoLetterPartialCalls := 0;
     TwoLetterCrunchProcess := True;
     LastPartialCall := PartialCall;
     end;

  { Look to see if we have process the whole list.  If so, then, there isn't
    anything for us to do.  However, if the callsign has changed, we will
    report TRUE so that the partial call list can be recalculated based upon
    the new callsign.  }

  if LastTwoLetterCrunchedAddress >= NumberPartialCalls - 1 then
     begin
     TwoLetterCrunchProcess := PartialCall <> LastPartialCall;
     LastPartialCall := PartialCall;
     Exit;
     end;

  { Now we only care about the first two letters. }

  if length(PartialCall) > 2 then
     begin
     PartialCall := Copy(PartialCall, 1, 2);
     end;

  { Wildcard partials means the two letters can show up anywhere in the
    callsign. }

  if Settings.CallWindow.WildcardPartials then
     begin
     NumberCallsToCrunch := NumberPartialCalls - LastTwoLetterCrunchedAddress - 1;

       { We will only crunch up to 200 callsigns per call to this process.  Note
        that we might not get to all of them if the operator presses a key. }

 //wli ???? ???????????? initial.ex ? ????? ????????    if NumberCallsToCrunch > 200 then NumberCallsToCrunch := 200;

       { Now look through the partial call list, looking for any calls that have
        the partial string in it. }

     for Address := LastTwoLetterCrunchedAddress + 1 to LastTwoLetterCrunchedAddress + NumberCallsToCrunch do
        begin
        {
            if pos(PartialCall, GetPartialCall(Address)) > 0 then
              begin
                if NumberTwoLetterPartialCalls < TwoLetterPartialCallListLength then
                  begin
                    TwoLetterCrunchPartialCallList[NumberTwoLetterPartialCalls] := Address;
                    inc(NumberTwoLetterPartialCalls);
                    TwoLetterCrunchProcess := True; // We have changed the list
                  end;
              end;

            inc(LastTwoLetterCrunchedAddress);
          }
          //            IF NewKeyPressed THEN Exit;  { Went to NewKeyPressed in 6.27 }
        end;
     end

  else
     begin

      { Remember that the partial call list is in alphabetical order.  If we
        find the first and last address that partial calls will be found, our
        job is done.  First, we compute the first address for this partial call. }

//      FirstAddress := FindProperPartialCallAddress(PartialCall);

      { Since we back up one more, if the address is more than zero, decrement
        it by one. }

    if FirstAddress > 0 then
       begin
       dec(FirstAddress);
       end;

      { Now we find the last address for any partial calls.  We do this by finding
        the proper address for a call with the last character incremented by one. }
      { Generate a string that has the second character incremented }

    TempString := PartialCall;

    if TempString[2] = 'Z' then
       begin
       TempString[2] := '0';
       TempString[1] := AnsiChar(Ord(TempString[1]) + 1);
           {
                    if TempString[1] > 'Z' then
                      LastAddress := NumberPartialCalls
                    else
                      LastAddress := FindProperPartialCallAddress(TempString);
          }
       end
    else
       begin
       TempString[2] := AnsiChar(Ord(TempString[2]) + 1);
           //          LastAddress := FindProperPartialCallAddress(TempString);
       end;

    for Address := FirstAddress to LastAddress do
       begin
       {
            GotPartialCall := GetPartialCall(Address);

            if pos(PartialCall, GotPartialCall) = 1 then
              begin
                if NumberTwoLetterPartialCalls < TwoLetterPartialCallListLength then
                  begin
                    TwoLetterCrunchPartialCallList[NumberTwoLetterPartialCalls] := Address;
                    inc(NumberTwoLetterPartialCalls);
                    TwoLetterCrunchProcess := True;
                  end;
              end;

            inc(LastTwoLetterCrunchedAddress);
            }
       end;
    LastTwoLetterCrunchedAddress := NumberPartialCalls - 1;
  end;
end;

procedure DupeAndMultSheet.AddCallToVisibleDupeSheet(Callsign: CallString);

var
  SuffixString, NumberString            : CallString;
  NumberChar                            : AnsiChar;
  Character                             : Char;
  NextRecord, {Remember,} ActiveVDEntry : VDEntryPointer;
  Count                                 : integer;

begin
  //{WLI}    IF MaxAvail <= SizeOf (VDEntry) THEN Exit;

  {    StandardCall := StandardCallFormat (Callsign, True);

      IF StringHas (StandardCall, '/') THEN
          StandardCall := PostcedingString (StandardCall, '/');
  }
  Callsign := RootCall(Callsign);

  NumberString := NumberPartOfString(Callsign);
  NumberChar := NumberString[1];

  if FirstVDEntry = nil then { Set up entries with 1 to 10 }
     begin
     FirstVDEntry := New(VDEntryPointer);
     ActiveVDEntry := FirstVDEntry;

     ActiveVDEntry^.Callsign := '1';
     ActiveVDEntry^.NextEntry := New(VDEntryPointer);

     for Count := 2 to 10 do
        begin
        if Count < 10 then
           begin
           Character := CHR(Ord('0') + Count)
           end
        else
           begin
           Character := '0';
           end;

        ActiveVDEntry := ActiveVDEntry^.NextEntry;

        ActiveVDEntry^.Callsign := Character;

        if Character <> '0' then
           begin
           ActiveVDEntry^.NextEntry := New(VDEntryPointer)
           end
        else
           begin
           ActiveVDEntry^.NextEntry := nil;
           end;
        end;

     NumberVDCalls := 10;
     end;

  ActiveVDEntry := FirstVDEntry;

  while ActiveVDEntry^.Callsign <> NumberChar do
    if ActiveVDEntry^.NextEntry = nil then
       begin
       ActiveVDEntry^.NextEntry := New(VDEntryPointer);
       ActiveVDEntry := ActiveVDEntry^.NextEntry;

       ActiveVDEntry^.Callsign := Callsign;
       ActiveVDEntry^.NextEntry := nil;
       inc(NumberVDCalls);
       Exit;
       end
    else
       begin
       ActiveVDEntry := ActiveVDEntry^.NextEntry;
       end;

  { We have found the Number Entry that matches the call we are adding. }

  if ActiveVDEntry^.NextEntry = nil then { Adding the 1st 0 call? }
     begin
     if ActiveVDEntry^.Callsign <> '0' then
        begin
        //      SetWindow(WholeScreenWindow);
             //{WLI}            ClrScr;
    ShowMessage(TC_FINDINGZEROENDVISIBLEDUPESHEETLIST);
    logger.Fatal('Not finding zero at end visible dupesheet list!!');
    halt;
        end;

     ActiveVDEntry^.NextEntry := New(VDEntryPointer);
     ActiveVDEntry := ActiveVDEntry^.NextEntry;

     ActiveVDEntry^.Callsign := Callsign;
     ActiveVDEntry^.NextEntry := nil;
     inc(NumberVDCalls);
     Exit; { All done - 1st 0 call added }
     end;

  { See if it is the first for this number }

  NextRecord := ActiveVDEntry^.NextEntry;

  if (length(NextRecord^.Callsign) = 1) and StringIsAllNumbers(ActiveVDEntry^.Callsign) then
     begin
     ActiveVDEntry^.NextEntry := New(VDEntryPointer);

     ActiveVDEntry := ActiveVDEntry^.NextEntry;
     ActiveVDEntry^.Callsign := Callsign;
     ActiveVDEntry^.NextEntry := NextRecord;
     inc(NumberVDCalls);
     Exit;
     end;

  { We have to find the right place to squeeze it }

  SuffixString := GetSuffix(Callsign);

  while (SuffixString > GetSuffix(NextRecord^.Callsign)) and
    (length(NextRecord^.Callsign) > 1) and
    (ActiveVDEntry^.NextEntry <> nil) do
     begin
     ActiveVDEntry := NextRecord;
     NextRecord := ActiveVDEntry^.NextEntry;
     if NextRecord = nil then Break; {added by wli}
     end;

  if NextRecord <> nil then {added by wli}
     begin {added by wli}
     if (ActiveVDEntry^.NextEntry = nil) and (SuffixString > GetSuffix(NextRecord^.Callsign)) then
        begin
        ActiveVDEntry := NextRecord;

        ActiveVDEntry^.NextEntry := New(VDEntryPointer);
        ActiveVDEntry := ActiveVDEntry^.NextEntry;
        ActiveVDEntry^.Callsign := Callsign;
        ActiveVDEntry^.NextEntry := nil;
        Exit;
        end;
     end; {added by wli}

  ActiveVDEntry^.NextEntry := New(VDEntryPointer);

  ActiveVDEntry := ActiveVDEntry^.NextEntry;
  ActiveVDEntry^.Callsign := Callsign;
  ActiveVDEntry^.NextEntry := NextRecord;
  inc(NumberVDCalls);
end;

procedure DupeAndMultSheet.DisposeOfMemoryAndZeroTotals;

//var
  //Band                                  : BandType;
  //Mode                                  : ModeType;
 // NumberBlocks, Block                   : integer;
  //TempRemainingMultiplierType           : RemainingMultiplierType;
begin

  CallsignsList.ClearDupes;

  mo.ClearAllMults;
{
  for Band := Band160 to AllBands do
    for Mode := CW to Both do
    begin

      if MultSheet.DomesticList[Band, Mode] <> nil then Dispose(MultSheet.DomesticList[Band, Mode]);
      if MultSheet.DXList[Band, Mode] <> nil then Dispose(MultSheet.DXList[Band, Mode]);
      if MultSheet.PrefixList[Band, Mode] <> nil then Dispose(MultSheet.PrefixList[Band, Mode]);
      if MultSheet.ZoneList[Band, Mode] <> nil then Dispose(MultSheet.ZoneList[Band, Mode]);

      for TempRemainingMultiplierType := rmDomestic to rmZone do
        if RemMultMatrix[Band, Mode, TempRemainingMultiplierType] <> nil then
        begin
//          showint(integer(RemMultMatrix[Band, Mode, TempRemainingMultiplierType]));
//          ShowMessage(BandStringsArrayWithOutSpaces[Band]);
//          ShowMessage(ModeString[Mode]);
//          showint(integer(TempRemainingMultiplierType));
          Dispose(RemMultMatrix[Band, Mode, TempRemainingMultiplierType]);
        end;

    end;

  FillChar(RemMultMatrix, SizeOf(RemMultMatrix), 0);
}
  FillChar(QSOTotals, SizeOf(QSOTotals), 0);
  FillChar(MaxSerialSent, SizeOf(MaxSerialSent), 0);  // Issue #954: rebuilt by LoadinLog
  FillChar(ContinentQSOCount, SizeOf(ContinentQSOCount), 0);

//  FillChar(MultSheet, SizeOf(MultSheet), 0);

  if QTCsEnabled then
     begin
     if QTCDataArray <> nil then
        begin
        FillChar(QTCDataArray^, SizeOf(QTCDataArrayType), 0);
        end;
     NumberQTCBooksSent := 0;
     NumberQTCStations := 0;
     TotalNumberQTCsProcessed := 0;
     end;

  TotalQSOPoints := 0;
  MOQSOPartyW0MAWorked := False;
  MOQSOPartyK0GQWorked := False;
  MOQSOPartyPeakHourCount := 0;
  TotalNamesSent := 0;
  tRestartInfo.riTotalRecordsInLog := 0;
  tUSQ := 0;
  tUSQE := 0;
  FillChar(tRestartInfo.riQSOByOpMode, SizeOf(tRestartInfo.riQSOByOpMode), 0);
  tThisHourPreviousBand := NoBand;
end;

procedure CheckMOQSOPartyBonusStation(const Callsign: CallString);
begin
   if Callsign = 'W0MA' then
      begin
      MOQSOPartyW0MAWorked := True;
      end;
   if Callsign = 'K0GQ' then
      begin
      MOQSOPartyK0GQWorked := True;
      end;
end;

procedure DupeAndMultSheet.DupeSheetTotals(var Totals: QSOTotalArray);

begin
  //  Totals := DupeSheet.Totals;
end;

procedure DupeAndMultSheet.ExamineLogForQSOTotals(var QTotals: QSOTotalArray);

//var
  //FileRead                              : Text;
 // TempString                            : string {Str80}; {WLI}
//  Band                                  : BandType;
 // Mode                                  : ModeType;

begin

end;

procedure EnumInitialEx(FileString: PShortString);

var
  InitialExchangeString                 : ShortString;
  Call                                  : Str80;
begin
  if FileString^[1] = ';' then Exit;

  Call := RemoveFirstString(FileString^);
  if FileString^ <> '' then
     begin
     InitialExchangeString := '';
     while FileString^ <> '' do
        begin
        InitialExchangeString := InitialExchangeString + RemoveFirstString(FileString^) + ' ';
        end;

     GetRidOfPostcedingSpaces(InitialExchangeString);
     if not CallsignsList.AddIniitialExchange(Call, InitialExchangeString) then
        begin
        inc(InitialExDupes);
        end;
     inc(InitialExCallsigns);
     end;
end;

procedure LoadInitialExchangeFile;
begin

  if not EnumerateLinesInFile(TR4W_INITIALEX_FILENAME, EnumInitialEx, True) then
     begin
     Exit;
     end;

   { Changed this from the MessageBox to a QuickDisplay - Much less intrusive - NY4I 2026JUL07 }
  //TempInteger := TF.Format(wsprintfBuffer, '%s:'#13#10 + TC_THEREWERECALLS, TR4W_INITIALEX_FILENAME, InitialExCallsigns, InitialExDupes);
  if InitialExCallsigns > 0 then
     begin
     QuickDisplay(SysUtils.Format(AnsiString(LclText('%s:' + TC_THEREWERECALLS)), [TR4W_INITIALEX_FILENAME, InitialExCallsigns, InitialExDupes]));
     end;
 // ShowMessage(wsprintfBuffer);
end;

procedure DupeAndMultSheet.MakePossibleCallList(Call: CallString; var PossCallList: PossibleCallRecord);

label
  CallAlreadyInList;

//var
 // Band, StartBand, EndBand              : BandType;
 // Mode, StartMode, EndMode              : ModeType;
 // CallBytes                             : FourBytes;
 // NumberCalls, CallAddress, NumberDupeBlocks, EndAddress, Entry: integer;
  //NumberEntriesInLastBlock, Block       : integer;
  //TempCall                              : Str80;

begin
end;
{
procedure DupeAndMultSheet.MultSheetTotals(var Totals: MultTotalArrayType);

begin
  Totals := MultSheet.Totals;
end;
}


function DupeAndMultSheet.IsADomesticMult(Mult: Str10; Band: BandType; Mode: ModeType): boolean;

//var
  //NumberMults                           : integer;
  //CompressedMult                        : FourBytes;
 // DomQTH                                : Str20;

begin
  {    IsADomesticMult := False;

      IF Mult = '' THEN Exit;

      IF NOT MultByBand THEN Band := All;
      IF NOT MultByMode THEN Mode := Both;

      IF DoingDomesticMults THEN
          BEGIN
          NumberMults := MultSheet.Totals [Band, Mode].NumberDomesticMults;

          IF NumberMults = 0 THEN
              IsADomesticMult := True
          ELSE
              BEGIN
              CompressFormat (Mult, CompressedMult);

              IF NOT BytDupe (Addr (CompressedMult), NumberMults, MultSheet.DomesticList [Band, Mode]) THEN
                  IsADomesticMult := True;
              END;
          END;
     }
end;

procedure DupeAndMultSheet.SetMultFlags(var RXData: ContestExchange);
label
  SkipDomesticMult;
{ This procedure will look at the contest exchange passed to it and see
  if any multiplier flags should be set.  No updating of multiplier arrays
  of totals is done.        }

var
  //Mult, NumberMults                     : integer;
 // TempBand                              : BandType;
  MultBand                              : BandType;
  MultMode                              : ModeType;
  //CompressedMult                        : FourBytes;
  //DomQTH                                : Str20;
 // c                                     : integer;

begin
   logger.Trace('>>> Entering DupeAndMultSheet.SetMultFlags');
   if logger.IsDebugEnabled then
      begin
      logger.debug('DoingDomesticMults = ' + BooleanToStr(DoingDomesticMults));
      logger.debug('DoingDXMults       = ' + BooleanToStr(DoingDXMults));
      logger.debug('DoingPrefixMults   = ' + BooleanToStr(DoingPrefixMults));
      logger.debug('DoingZoneMults     = ' + BooleanToStr(DoingZoneMults));
      end;

  if RXData.ceClearMultSheet then Exit;
  RXData.DomesticMult := False;
  RXData.DXMult := False;
  RXData.PrefixMult := False;
  RXData.ZoneMult := False;

  if MultByBand then MultBand := RXData.Band else MultBand := AllBands;
  if MultByMode then MultMode := RXData.Mode else MultMode := Both;

  if (RXData.DomMultQTH = '') and (RXData.DomesticQTH <> '') then
     begin
     RXData.DomMultQTH := RXData.DomesticQTH;
     end;

  SkipDomesticMult:
  if (Contest = BCQP) and (RXData.DomMultQTH = 'dx') then         // 4.98.2
     begin
     exit;   // no mults for dx
     end;
  if (Contest = NYQP) and (RXData.DomMultQTH = 'DX') then         // 4.116.5
     begin
     exit;
     end;
   if (Contest = INQSOPARTY) and (RXData.DomMultQTH = 'DX') then         // 4.116.5
      begin
      exit;
      end;
  if (RXData.DomMultQTH <> '') and DoingDomesticMults then
     begin
     RXData.DomesticMult := mo.IsDmMult(RXData.DomMultQTH, GetAddMultBand(DomesticMultByBand, MultBand), MultMode, ActiveDomesticMult);
     end;

  if (RXData.DXQTH <> '') and DoingDXMults {and (ActiveDXMult <> NoCountDXMults)} then
 // if (activeqsopointmethod = DLRTTY then
     begin
     RXData.DXMult := mo.IsDXMult(RXData.QTH.Country, GetAddMultBand(DXCCMultByBand, MultBand), MultMode);
     end;

   if (RXData.Prefix <> '') and DoingPrefixMults then
      begin        // 4.83.6
      if (contest = PCC) and
         (RXData.QTH.CountryID = MyCountry) then
         begin
         RXData.PrefixMult := False
         end
      else
         begin
         RXData.PrefixMult := mo.IsPxMult(RXData.Prefix, MultBand, MultMode);
         end;
      end;
    if (Contest = NZFIELDDAY) then
    if (RXData.Zone = StrToIntDef(Settings.My.Zone, 0)) or (RXData.Zone = 00) then   exit;  //n4af 4.41.6


  if (RXData.Zone <> DUMMYZONE) and DoingZoneMults then              // n4af 4.42.1
     begin
     RXData.ZoneMult := mo.IsZnMult(RXData.Zone, MultBand, MultMode);
     end;
end;

(* WHERE THE OPERATOR LEFT OFF, INTO THE CONTEST DATABASE.

  THIS WAS A .RST FILE -- fourteen globals written raw with sWriteFile and read
  back by offset, guarded by a version string because the layout changed every
  time a field did. NY4I, 2026-09-12: "we should no longer use a restart file
  since we have a far more reliable database."

  TWO OF THE FOURTEEN ARE NOT HERE BECAUSE THEY ARE DERIVED. tRestartInfo holds
  the total record count and the QSO counts by operating mode, and LoadinLog
  rebuilds both by walking the log -- it increments riTotalRecordsInLog per row
  and AddQSOToSheets increments riQSOByOpMode. Writing them down as well is the
  two-stores problem the binary log already cost us once.

  ONE MORE IS NOT HERE BECAUSE THE CONTEST TABLE HOLDS IT. The file stored the
  contest name so the reader could refuse another contest's state. That guard is
  structural now: this state lives INSIDE the contest's own log, so there is no
  other contest's state to load by mistake and nothing to compare.

  AND THE VERSION STRING IS GONE WITH THE LAYOUT. A row per value means a field
  added later is an ABSENT ROW that reads as its default, where a blob meant the
  whole record became unreadable. That is why FreqMemory is one row per band and
  mode rather than one encoded array.

  ENUMS GO IN BY NAME, NOT BY ORDINAL. An ordinal is what the binary file
  stored, and it silently means something else the day a band is inserted into
  the middle of BandType. A name either resolves or it does not.

  ONLY WHAT CHANGED IS WRITTEN, and there is no commit when nothing did.

  NY4I, 2026-09-12: "The other items seem to be settings that can just be
  persisted to the database when they change." Right, and the obvious way to do
  that is wrong: these twelve are assigned from SEVENTEEN sites across seven
  units, so a save call beside each assignment would be complete on the day it
  was written and incomplete the first time somebody adds an eighteenth.

  A cached copy of what was last written gives the same behaviour from ONE call
  site and cannot be forgotten. The routine still runs per QSO -- which is when
  a band, mode or speed memory has usually just moved -- but a QSO that changed
  nothing writes no rows and opens no transaction, so it costs a comparison
  rather than an fsync.

  THE SEPARATION FROM THE QSO'S OWN COMMIT IS DELIBERATE, not an oversight. If
  this never happens the log is still complete and correct: what is lost is
  where the cursor was, not a contact. Holding a contact's durability hostage
  to a band memory would be the real defect. *)
procedure DupeAndMultSheet.SaveRestartFile;

   (* KEYS ARE BUILT AS UnicodeString AND ENCODED ONCE, at the call. An
     AnsiString CAST of an enum name is a NARROWING conversion the build
     counts, and it would drop anything the machine codepage cannot
     represent; UTF8Encode converts instead, and an enum name is ASCII by
     construction so the bytes are identical either way. The encode is
     LAST because concatenating anything onto a UTF8String promotes the
     result straight back to UnicodeString. *)
   (* True when the row was actually written, so the caller knows whether a
     commit is owed. GLastWritten is the cache; a key absent from it has never
     been written this session and so always differs. *)
   function Put(const aKey, aValue: string): boolean;
   var
      i: integer;
      k, v: UTF8String;
   begin
      (* ENCODED ONCE, INTO LOCALS. Classes is compiled without the Unicode
        modeswitch, so every TStringList member takes an AnsiString -- passing a
        UTF-16 key straight in narrows at each of the three calls below. The
        cache therefore holds exactly the bytes that go to the database. *)
      k := UTF8Encode(aKey);
      v := UTF8Encode(aValue);

      i := GLastWritten.IndexOfName(k);
      if (i >= 0) and (GLastWritten.ValueFromIndex[i] = v) then
         begin
         Result := False;
         Exit;
         end;
      LogStoreRepository.SaveSessionValue(k, v);
      GLastWritten.Values[k] := v;
      Result := True;
   end;

   procedure PutEnum(const aKey: string; aTypeInfo: PTypeInfo; aValue: integer);
   begin
      if Put(aKey, GetEnumName(aTypeInfo, aValue)) then
         begin
         GSessionDirty := True;
         end;
   end;

   procedure PutInt(const aKey: string; aValue: LONGINT);
   begin
      if Put(aKey, IntToStr(aValue)) then
         begin
         GSessionDirty := True;
         end;
   end;

var
   b: BandType;
   m: ModeType;
   op: string;
begin
   (* Nil when nothing has opened the log, or when a failure disabled it. The
     session position is worth exactly nothing without the log it describes, so
     there is no fallback to reach for. *)
   if LogStoreRepository = nil then
      begin
      Exit;
      end;

   if GLastWritten = nil then
      begin
      GLastWritten := TStringList.Create;
      GLastWritten.CaseSensitive := False;
      end;
   GSessionDirty := False;

   PutEnum('radio1.band', TypeInfo(BandType), Ord(Radio1.BandMemory));
   PutEnum('radio2.band', TypeInfo(BandType), Ord(Radio2.BandMemory));
   PutEnum('radio1.mode', TypeInfo(ModeType), Ord(Radio1.ModeMemory));
   PutEnum('radio2.mode', TypeInfo(ModeType), Ord(Radio2.ModeMemory));
   PutInt('radio1.speed', Radio1.SpeedMemory);
   PutInt('radio2.speed', Radio2.SpeedMemory);

   PutInt('lastCQ.frequency', LastCQFrequency);
   PutEnum('lastCQ.mode', TypeInfo(ModeType), Ord(LastCQMode));

   PutEnum('remainingMultDisplay', TypeInfo(RemainingMultiplierType),
           Ord(RemainingMultDisplay));

   for b := Low(BandType) to High(BandType) do
      begin
      for m := CW to Phone do
         begin
         PutInt('freqMemory.' + GetEnumName(TypeInfo(BandType), Ord(b))
                + '.' + GetEnumName(TypeInfo(ModeType), Ord(m)),
                FreqMemory[b, m]);
         end;
      end;

   op := string(CharArrayToAnsi(CurrentOperator));
   if Put('currentOperator', op) then
      begin
      GSessionDirty := True;
      end;

   (* NO COMMIT WHEN NOTHING MOVED. This is what makes a per-QSO call cheap:
     the common case writes no rows, so there is no transaction to end and no
     fsync to pay for. *)
   if GSessionDirty then
      begin
      LogStoreRepository.Commit;
      end;
end;

(* PUT BACK WHERE THE OPERATOR LEFT OFF.

  The counterpart of SaveRestartFile, and it keeps that routine's name --
  ReadInBinFiles -- because SheetInitAndLoad calls it and the name is about
  when it runs, not what it reads. There are no bin files left.

  EVERY FIELD IS OPTIONAL. An absent row means a log written before this
  existed, or a field added since, and both must leave the global at whatever
  the program already put there. That is the property a blob could not have and
  is why the old reader needed a version string and a contest-name check to
  refuse a file it could not trust.

  A VALUE THAT WILL NOT PARSE IS LEFT ALONE, not defaulted: the caller cannot
  tell those apart and "the band memory silently became 160m" is worse than
  "the band memory did not change". *)
function DupeAndMultSheet.ReadInBinFiles {(JustDoIt: boolean)}: boolean;

   function TakeEnum(const aKey: string; aTypeInfo: PTypeInfo;
                     var aOrdinal; aSize: integer): boolean;
   var
      text: AnsiString;
      v: integer;
   begin
      Result := False;
      text := LogStoreRepository.SessionValue(UTF8Encode(aKey));
      if text = '' then
         begin
         Exit;
         end;
      (* NO CONVERSION AT ALL. TypInfo is compiled without the Unicode
        modeswitch, so GetEnumValue takes an AnsiString -- decoding first
        would only narrow it back at the call. Enum names are ASCII, so the
        bytes stored are the bytes it wants. *)
      v := GetEnumValue(aTypeInfo, text);
      if v < 0 then
         begin
         Exit;
         end;
      (* The globals are one-byte enums and integers of differing width, so the
        assignment is by size rather than by a typed parameter -- the
        alternative is a routine per type for no gain. *)
      case aSize of
         1: byte(aOrdinal) := byte(v);
         2: word(aOrdinal) := word(v);
      else
         integer(aOrdinal) := v;
      end;
      Result := True;
   end;

   procedure TakeInt(const aKey: string; var aValue: LONGINT);
   var
      text: AnsiString;
      v: LONGINT;
      code: integer;
   begin
      text := LogStoreRepository.SessionValue(UTF8Encode(aKey));
      if text = '' then
         begin
         Exit;
         end;
      Val(UTF8Decode(text), v, code);
      if code = 0 then
         begin
         aValue := v;
         end;
   end;

var
   b: BandType;
   m: ModeType;
   op: AnsiString;
begin
   Result := False;
   if LogStoreRepository = nil then
      begin
      Exit;
      end;

   TakeEnum('radio1.band', TypeInfo(BandType), Radio1.BandMemory, SizeOf(BandType));
   TakeEnum('radio2.band', TypeInfo(BandType), Radio2.BandMemory, SizeOf(BandType));
   TakeEnum('radio1.mode', TypeInfo(ModeType), Radio1.ModeMemory, SizeOf(ModeType));
   TakeEnum('radio2.mode', TypeInfo(ModeType), Radio2.ModeMemory, SizeOf(ModeType));
   TakeInt('radio1.speed', Radio1.SpeedMemory);
   TakeInt('radio2.speed', Radio2.SpeedMemory);

   TakeInt('lastCQ.frequency', LastCQFrequency);
   TakeEnum('lastCQ.mode', TypeInfo(ModeType), LastCQMode, SizeOf(ModeType));

   TakeEnum('remainingMultDisplay', TypeInfo(RemainingMultiplierType),
            RemainingMultDisplay, SizeOf(RemainingMultiplierType));

   for b := Low(BandType) to High(BandType) do
      begin
      for m := CW to Phone do
         begin
         TakeInt('freqMemory.' + GetEnumName(TypeInfo(BandType), Ord(b))
                 + '.' + GetEnumName(TypeInfo(ModeType), Ord(m)),
                 FreqMemory[b, m]);
         end;
      end;

   op := LogStoreRepository.SessionValue('currentOperator');
   if op <> '' then
      begin
      AnsiToCharArray(CurrentOperator, op);
      end;

   (* tRestartInfo IS NOT READ BACK. LoadinLog rebuilds the record count and the
     per-operating-mode counts by walking the log, which runs immediately after
     this in SheetInitAndLoad. Restoring them here as well would have them
     counted twice. *)
   Result := True;
end;

procedure DupeAndMultSheet.SheetInitAndLoad;

{ This procedure will load in the LOG.DAT file and fill up all the sheets
  with the right stuff.  Make sure that QSOByBand, QSOByMode and the
  active multiplier globals are setup before executing this.         }

begin
  ReadInBinFiles;
  {?? ??????}
//  SetUpRemainingMultiplierArrays;
  LoadInitialExchangeFile;
  LoadinLog;
end;

procedure SetUpExchangeInformation(ActiveExchange: ExchangeType; var ExchangeInformation: ExchangeInformationRecord);

begin
  //FillChar(ExchangeInformation, sizeof(ExchangeInformation), 0);

  with ExchangeInformation do
     begin
     Age := False;
     Chapter := False;
     Check := False;
     ClassEI := False;
 //    FOCNumber := False;
     Name := False;
 //    PostalCode := False;
     Power := False;
     Precedence := False;
     QSONumber := False;
     QTH := False;
     RandomChars := False;
     RST := False;
     Zone := False;
     ZoneOrSociety := False;
     end;

  case ActiveExchange of
    CheckAndChapterOrQTHExchange:
      begin
        ExchangeInformation.Chapter := True;
        ExchangeInformation.Check := True;
        ExchangeInformation.QTH := True;
      end;

    ClassDomesticOrDXQTHExchange:
      begin
        ExchangeInformation.ClassEI := True;
        ExchangeInformation.QTH := True;
      end;

    KidsDayExchange:
      begin
        ExchangeInformation.Kids := True;
      end;

    RSTAndContinentExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
      end;

    NameQTHAndPossibleTenTenNumber:
      begin
        ExchangeInformation.Name := True;
        ExchangeInformation.QTH := True;
        ExchangeInformation.TenTenNum := True;
      end;

    NameAndDomesticOrDXQTHExchange:
      begin
        ExchangeInformation.Name := True;
        ExchangeInformation.QTH := True;
      end;

    NameAndPossibleGridSquareExchange:
      begin
        ExchangeInformation.Name := True;
        ExchangeInformation.QTH := True;
      end;

    NZFieldDayExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Zone := True;
      end;
  
    QSONumberAndCoordinatesSum, QSONumberAndGeoCoordinates:
      begin
        ExchangeInformation.QTH := True;
        ExchangeInformation.QSONumber := True;
      end;

    QSONumberAndPreviousQSONumber:
      begin
//        ExchangeInformation.RandomChars := True;
        ExchangeInformation.QSONumber := True;
      end;

    QSONumberAndZone:
      begin
        ExchangeInformation.Zone := True;
        ExchangeInformation.QSONumber := True;
      end;

    QSONumberAndNameExchange:
      begin
        ExchangeInformation.Name := True;
        ExchangeInformation.QSONumber := True;
      end;
    QSONumberAndGridSquare,
      QSONumberDomesticQTHExchange,
      QSONumberDomesticOrDXQTHExchange:
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.QTH := True;
      end;

    QSONumberNameChapterAndQTHExchange:
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Name := True;
        ExchangeInformation.Chapter := True;
        ExchangeInformation.QTH := True;
      end;

    QSONumberNameDomesticOrDXQTHExchange:
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Name := True;
        ExchangeInformation.QTH := True;
      end;

    QSONumberPrecedenceCheckDomesticQTHExchange:
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Precedence := True;
        ExchangeInformation.Check := True;
        ExchangeInformation.QTH := True;
      end;

    AgeAndQSONumberExchange:
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Age := True;
      end;

    QSONumberAndAgeExchange:             // 4.119.1
      begin
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.Age := True;
      end;
    RSTAndPOTAPark:
       begin
       ExchangeInformation.RST := true;
       ExchangeInformation.QTH := true;
       end;
       
    RSTAgeAndPossibleSK:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Age := True;
        ExchangeInformation.QTH := True;
      end;

    RSTAgeExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Age := True;
      end;

    RSTALLJAPrefectureAndPrecedenceExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Precedence := True;
        ExchangeInformation.QTH := True;
      end;

    RSTPossibleDomesticQTHAndPower:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
        ExchangeInformation.Power := True;
      end;

    Grid2Exchange:
      begin
        ExchangeInformation.QTH := True;
      end;

      RSTAndGrid3Exchange:      // 4.96.3
      begin
        ExchangeInformation.QTH := True;
      end;

       GridExchange:
      begin
        ExchangeInformation.QTH := True;
      end;

    RSTAndOrGridExchange, RSTAndGridExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
      end;

    RSTAndPostalCodeExchange:
      begin
        ExchangeInformation.RST := True;
//        ExchangeInformation.PostalCode := True;
        ExchangeInformation.QTH := True;
      end;

    RSTQTHExchange,
      RSTDomesticOrDXQTHExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
      end;

    RSTDomesticQTHExchange,
      RSTPrefectureExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
        ExchangeInformation.QSONumber := True;  // 4.97.5
      end;

    QSONumberAndPossibleDomesticQTHExchange, RSTDomesticQTHOrQSONumberExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.QTH := True;
      end;

    RSTNameAndQTHExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Name := True;
        ExchangeInformation.QTH := True;
      end;
  RSTAndFOCNumberExchange:
  begin
  ExchangeInformation.RST := True;
  ExchangeInformation.Power := True;
  end;

    RSTPowerExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Power := True;
      end;
    {WLI-DUBLICATE}
    {        NZFieldDayExchange:
                BEGIN
                ExchangeInformation.RST := True;
                ExchangeInformation.QSONumber := True;
                ExchangeInformation.Zone := True;
                END;
    }
    RSTQSONumberExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QSONumber := True;
      end;

    RSTAndQSONumberOrFrenchDepartmentExchange,
    RSTQSONumberOrDomesticQTHExchange, //n4af 04.40.5
      RSTQSONumberAndPossibleDomesticQTHExchange,
      RSTQSONumberAndDomesticQTHExchange,
      RSTQSONumberAndGridSquareExchange,
      RSTAndQSONumberOrDomesticQTHExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QSONumber := True;
        ExchangeInformation.QTH := True;
      end;

    RSTQTHNameAndFistsNumberOrPowerExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
        ExchangeInformation.Name := True;
        ExchangeInformation.Power := True;
        ExchangeInformation.QSONumber := True;
      end;

    RSTQSONumberAndRandomCharactersExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.RandomChars := True;
        ExchangeInformation.QSONumber := True;
      end;

    RSTZoneAndPossibleDomesticQTHExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Zone := True;
        ExchangeInformation.QTH := True;
      end;

    RSTZoneExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Zone := True;
      end;

    RSTZoneOrSocietyExchange:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
        ExchangeInformation.Zone := True;
      end;

    RSTLongJAPrefectureExchange: {KK1L: 6.72}
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.QTH := True;
      end;
      RSTZoneOrDomesticQTH:
      begin
        ExchangeInformation.RST := True;
        ExchangeInformation.Zone := True;
        ExchangeInformation.QTH := True;
      end;
  end;

end;

function ParseExchangeIntoContestExchange(LogEntry: string;
  var RXData: ContestExchange): boolean;

{ Returns TRUE if it looks like a good QSO }

var
  ExchangeString                        : ShortString {Str80}; {WLI}

begin
  ParseExchangeIntoContestExchange := False;
  logger.debug('Entering ParseEchangeIntoCOntestExchange with LogEntry = (%s)',[LogEntry]);

  ClearContestExchange(RXData);

  { See if it is a note }

  if Copy(LogEntry, 1, 1) = ';' then Exit;

  RXData.Callsign := GetLogEntryCall(LogEntry);
  RXData.Band := GetLogEntryBand(LogEntry);
  RXData.Mode := GetLogEntryMode(LogEntry);
  SetExtendedModeFromMode(RXData);
  RXData.QSOPoints := GetLogEntryQSOPoints(LogEntry);
  //  RXData.Date := GetLogEntryDateString(LogEntry);
  //  RXData.Time := GetLogEntryIntegerTime(LogEntry);

  if (RXData.Band = NoBand) or (RXData.Mode = NoMode) then Exit;

  ExchangeString := GetLogEntryExchangeString(LogEntry);

  if ExchangeInformation.RST then
     begin
     RXData.RSTSent := StrToIntDef(RemoveFirstString(ExchangeString), 0);

       { Sometimes the received RST is optional, so I only pull it
        off if it appears to be all there (numbers only). }

     if StringIsAllNumbers(GetFirstString(ExchangeString)) then
        begin
        RXData.RSTReceived := StrToIntDef(RemoveFirstString(ExchangeString), 0);
        end;
     end;


  if (ActiveExchange = RSTQTHNameAndFistsNumberOrPowerExchange) then {KK1L: 6.70 for FISTS funny exchange}
     begin

     RXData.QTHString := RemoveFirstString(ExchangeString);
     RXData.Name := RemoveFirstString(ExchangeString);
       {KK1L: 6.70 The power/number is right where the mults usually go}
     RXData.Power := GetLogEntryMultString(LogEntry); {KK1L: 6.70 I use power string for either number or power}
     end

  else {KK1L: 6.70 What follows is what was always here!}
     begin
     if ExchangeInformation.ClassEI then
        begin
        RXData.ceClass := RemoveFirstString(ExchangeString);
        end;

       { Sometimes the QSO number is optional - so only pull it off the
        exchange if it looks like it is there. }

     if ExchangeInformation.QSONumber and StringIsAllNumbers(GetFirstString(ExchangeString)) then
        begin
        RXData.NumberReceived := RemoveFirstLongInteger(ExchangeString);
        end;

     if ExchangeInformation.RandomChars then
        begin
        RXData.RandomCharsSent := RemoveFirstString(ExchangeString); { added in 6.27 }
        RXData.RandomCharsReceived := RemoveFirstString(ExchangeString);
        end;
 {
    if ExchangeInformation.PostalCode then
    begin
      RXData.PostalCode := RemoveFirstString(ExchangeString) + ' ' + RemoveFirstString(ExchangeString);
    end;
}
     if ExchangeInformation.Power then
        begin
        RXData.Power := RemoveFirstString(ExchangeString);
        end;

     if ExchangeInformation.Age then
        begin
        RXData.Age := StrToIntDef(RemoveFirstString(ExchangeString), 0);
        end;

     if ExchangeInformation.Name then
        begin
        RXData.Name := RemoveFirstString(ExchangeString);
        end;

     if ExchangeInformation.Chapter then
        begin
        RXData.Chapter := RemoveFirstString(ExchangeString);
        end;

     if ExchangeInformation.Precedence then
        begin
        RXData.Precedence := RemoveFirstString(ExchangeString)[1];
        end;

     if ExchangeInformation.Check then
        begin
        RXData.Check := StrToIntDef(RemoveFirstString(ExchangeString), 0);
        end;

     if ExchangeInformation.Zone and StringIsAllNumbersOrSpaces(ExchangeString) then
        begin
        RXData.Zone := StrToIntDef(RemoveFirstString(ExchangeString), 0);
        end;

     if ExchangeInformation.QTH then
        begin
        GetRidOfPrecedingSpaces(ExchangeString);
        GetRidOfPostcedingSpaces(ExchangeString);
        RXData.QTHString := ExchangeString;
        end;
     end;

  ParseExchangeIntoContestExchange := True;
end;

procedure DupeInit;

var
  //Block                                 : integer;
  NextEntry, ActiveVDEntry              : VDEntryPointer;
  //Band                                  : BandType;
  //Mode                                  : ModeType;

begin
  //  for Block := 1 to MaxPartialCallBlocks do PartialCallList[Block] := nil;
  ActiveVDEntry := FirstVDEntry;
  while ActiveVDEntry <> nil do
     begin
     NextEntry := ActiveVDEntry^.NextEntry;
     Dispose(ActiveVDEntry);
     ActiveVDEntry := NextEntry;
     end;
end;

function GetInitialExchangeStringFromContestExchange(RData: ContestExchange): string;

var
  QString                               : ShortString; {STR40} {WLI}
  TString, TempString                   : string[14];

begin
  GetInitialExchangeStringFromContestExchange := '';
  TempString := '';

  with RData do
     begin

     if ActiveExchange = RSTALLJAPrefectureAndPrecedenceExchange then
        begin
        GetInitialExchangeStringFromContestExchange := Precedence + ' ' + QTHString;
        Exit;
        end;

     if ActiveExchange = RSTDomesticQTHOrQSONumberExchange then
        begin
        QString := QTHString;

        while QString <> '' do
           begin
           TString := RemoveFirstString(QString);

                 //wli              if StringHasLowerCase(TString) then
           begin
             GetInitialExchangeStringFromContestExchange := TString;
             Exit;
           end;
           end;
        Exit;
        end;

     if ActiveExchange = RSTQTHNameAndFistsNumberOrPowerExchange then
        begin
        GetInitialExchangeStringFromContestExchange := QTHString + ' ' + Name + ' ' + Power;
        Exit;
        end;

     if ActiveExchange = RSTZoneOrSocietyExchange then
        begin
        if QTHString <> '' then
           begin
           GetInitialExchangeStringFromContestExchange := QTHString;
           Exit;
           end;
        end;

      if ActiveExchange = RSTZoneOrDomesticQTH then           // 4.95.6
         begin
         if QTHString <> '' then
            begin
            GetInitialExchangeStringFromContestExchange := QTHString;
           Exit;
            end;
         end;

     if ExchangeInformation.Zone then

        begin
        TempString := IntToStr(Zone);
        end;

     if ExchangeInformation.Name then
        begin
        TempString := Name;
        end;
     if ExchangeInformation.ClassEI then
        begin
        TempString := ceClass;
        end;
     if ExchangeInformation.Age then
        begin
        TempString := IntToStr(Age);
        end;
     if ExchangeInformation.Check then
        begin
        TempString := IntToStr(Check);
        end;

     if ExchangeInformation.Chapter then
        begin
        TempString := TempString + ' ' + Chapter;
        end;

     if ExchangeInformation.QTH then
        begin
        QString := QTHString;
  {//?
      if ((ActiveExchange = QSONumberNameChapterAndQTHExchange) or
        (ActiveDomesticMult <> NoDomesticMults) or
        (ActiveExchange = QSONumberAndGeoCoordinates) or
        (ActiveExchange = QSONumberAndCoordinatesSum) or
        (ActiveExchange = QSONumberDomesticQTHExchange) or
        (ActiveExchange = RSTAndQSONumberOrDomesticQTHExchange) or
        (ActiveExchange = RSTAndOrGridExchange)) then
}
        if (TempString = '') or (StrToIntDef(TempString, 0) = 255) then   // 4.85.6
           begin
           TempString := QString
           end
        else
           begin
           TempString := TempString + ' ' + QString;
           end;
        end;

     if ExchangeInformation.Power then
       if TempString = '' then
          begin
          TempString := Power
          end
       else
          begin
          TempString := TempString + ' ' + Power;
          end;

       //         if Contest = OLDNEWYEAR then if TempString = '' then TempString := IntToStr(RData.NumberReceived);
     end;

  GetInitialExchangeStringFromContestExchange := TempString;
end;
{
procedure DupeAndMultSheet.CancelOutNewDomesticMultWeHaveWorked(MultString: Str20;
  Band: BandType;
  Mode: ModeType);
var
  Address                               : integer;

begin
  if DomQTHTable.NumberRemainingMults = 0 then Exit;
  Address := DomQTHTable.GetDomMultInteger(MultString);
  if Address <> -1 then
    RemMultMatrix[Band, Mode, rmDomestic]^[Address] := False;
end;
}


procedure DupeAndMultSheet.SetUpRemainingMultiplierArrays;

var
  StartBand, FinishBand{, Band}           : BandType;
  StartMode, FinishMode{, Mode}           : ModeType;
  //TempString                            : Str20;
 // Address                               : integer;

begin
  if MultByBand then
     begin
     StartBand := Band160;
     FinishBand := Band2304;
     end
  else
     begin
     StartBand := AllBands;
     FinishBand := AllBands;
     end;

  if MultByMode then
     begin
     StartMode := CW;
     FinishMode := Phone;
     end
  else
     begin
     StartMode := Both;
     FinishMode := Both;
     end;
{
  if (DoingDXMults) then
  begin
    if CountryTable.NumberRemainingCountries > 0 then
      for Band := StartBand to FinishBand do
        for Mode := StartMode to FinishMode do
        begin
          if RemMultMatrix[Band, Mode, rmDX] = nil then
                //                        IF MaxAvail > SizeOf (RemainingMultList) THEN
          begin
            New(RemMultMatrix[Band, Mode, rmDX]);

            for Address := 0 to CountryTable.NumberRemainingCountries - 1 do
              RemMultMatrix[Band, Mode, rmDX]^[Address] := True;
          end;

          CancelOutRemainingMultsWeHaveWorked(Band, Mode, rmDX);
        end;
  end;
}
  if DoingZoneMults then
     begin
     case ActiveZoneMult of
       CQZones: MaxNumberOfZones := 40;
       EUHFCYear: MaxNumberOfZones := 100;
       ITUZones: MaxNumberOfZones := 75;
       JAPrefectures: MaxNumberOfZones := 50;
       BranchZones: MaxNumberOfZones := 99;
       RFChampionchipZones: MaxNumberOfZones := 7;
     else MaxNumberOfZones := 0;
     end;

     end;


end;

begin
  //{WLI}    HeapError := @HeapFunc;
  DupeInit;
end.


