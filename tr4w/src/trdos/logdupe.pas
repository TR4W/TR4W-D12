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
  (* TContestBase -- GetDXQTH's parameter (M11 S4). An interface leaf over
    VC and uSettingsModel; it was in the implementation uses until then. *)
  uContestBase,
  (* TCallHistoryAddResult -- LoadCallHistoryFile's store. A leaf. *)
  uCallHistory;

const
  MaxGridSquaresInList                  = 40;

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

  //  CallDistrictTotalArray = array[1..11] of integer;

  DupeAndMultSheet = class
    DupeSheetEnable: boolean;
    //    DupeSheet: DupeList;
//    MultSheet: MultList;

    function AddBigCallAddress(BigCall: EightBytes): integer;
    procedure AddCompressedCallToDupeSheet(Call: FourBytes; Band: BandType; Mode: ModeType);
    procedure AddQSOToSheets(RXData: ContestExchangePtr; AddToPartials: boolean);

    //    function CallIsADupe(Call: CallString; Band: BandType; Mode: ModeType): boolean;

//    procedure CancelOutNewDomesticMultWeHaveWorked(MultString: Str20;      Band: BandType;      Mode: ModeType);

//    procedure CancelOutNewDXMultWeHaveWorked(MultString: DXMultiplierString ;      Band: BandType;      Mode: ModeType);

//    procedure CancelOutNewZoneMultWeHaveWorked(MultString: integer; Band: BandType; Mode: ModeType);
//    procedure CancelOutRemainingMultsWeHaveWorked(Band: BandType; Mode: ModeType; multtype: RemainingMultiplierType);

    //    procedure ClearDupeSheet;

        //    procedure CreateVisibleDupeSheetArrays(var Band: BandType;      Mode: ModeType);

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

(* DXMultTypenameArray IS GONE -- M10 S2, 2026-10-14, with DX MULTIPLIER
  (uCFG.RETIRED_COMMANDS, NY4I's Q4). Nothing else read it. *)
var

  InitialExCallsigns                    : integer;
  InitialExDupes                        : integer;

  tAllowDupeQSOs                        : boolean = False;
  (* ActiveDXMult MOVED -- Issue #1034 took it from here to VC so uMults
    could read it without LogDupe's cone; M10 S9d (2026-10-14) took it to
    uContestSession.ContestSession.DXMult, as light (a leaf over VC),
    written only by FCONTEST's set-up path. *)
  (* ActivePrefixMult MOVED -- M10 S9b, 2026-10-14, to
    uContestSession.ContestSession.PrefixMult -- and is GONE since M11 S3
    part 2: the contest states its prefix key and whether it has one
    (TContestBase.PrefixMultiplierKey, HasPrefixMultiplier). *)


//  CQP                                   : boolean;

  (* DoingDomesticMults, DoingDXMults, DoingPrefixMults and DoingZoneMults
    MOVED -- M11 S2, 2026-10-14 (plan F9). They are ContestSession's,
    computed from the session's kinds on every read: LogCfg derived these
    once at start-up, so a contest changed without a restart left them
    describing the previous one. DoingPrefixMults left the session at M11
    S3 with the prefix kind: the contest answers it (LOGEDIT.DoingPrefixMults,
    TContestBase.HasPrefixMultiplier). *)

  ExchangeInformation                   : ExchangeInformationRecord;

  GridSquareList                        : array[0..MaxGridSquaresInList - 1] of string[4];


  //  InitialExchangeList              : InitialExchangeArrayPointer = nil;

  LastPartialCallBlock                  : integer;
  //  LoadingInLogFile                      : boolean;
  //  LongPartialCallList              : LongPartialCallListPointer = nil;

  MultiplierAlarm                       : boolean;

  NumberDifferentMults                  : Byte {= 0};
  NumberGridSquaresInList               : Byte;
  NumberInitialExchanges                : integer;
  NumberLongPartialCalls                : integer;
  NumberPartialCalls                    : integer;

  OffTimeStart                          : TimeRecord;

  //  PartialCallList                  : array[1..MaxPartialCallBlocks] of PartialCallArrayPtr;
  PartialCallLoadLogEnable              : boolean = {false} True;

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
  (* ~~LiveSessionTally~~ stood here (it was MOQSOPartyPeakHourCount):
     Missouri's peak-hour count, kept while the program ran and never by the
     log's loader. Deleted at Q32 (2026-10-17) -- the Missouri class counts
     the bonus over the whole log now, as it already counted its bonus
     stations (W0MA, K0GQ). *)

  //  tTotalRecordsInLog               : integer;
  tRestartInfo                          : RestartInfo;

  //  DTR, RTS                              : boolean;

//procedure AddCallToPartialList(Call: CallString; InitialExchange: CallString);

function BigEntryAddress(Entry: FourBytes): integer;

function CallNotInPossibleCallList(Call: CallString; PossCallList: PossibleCallRecord): boolean;

procedure ClearContestExchange(var Exchange: ContestExchange);
procedure CreateGridSquareList(Call: CallString; Band: BandType);

//function FindProperPartialCallAddress(Call: CallString): integer;
function FoundDomesticQTH(var RXData: ContestExchange): boolean;

(* DOES THE LOADED DOMESTIC QTH TABLE KNOW THIS QTH? -- uContestBase's
  TDomesticQTHTest, the engine's one answer. Handed to a contest in the typed
  exchange's session (LOGSTUFF, M5b) and in its station (uContestFactory.
  CurrentStation, Q107), so the host-area refusal and the host-area score ask
  the same thing. Moved here from LOGSTUFF (ParseSessionIsDomesticQTH) on
  2026-10-16 when it gained its second caller. *)
function DomesticTableKnowsQTH(const aQTH: string): boolean;

(* THE MULTIPLIER KEY THE LOADED DOMESTIC QTH TABLE GIVES THIS QTH -- the
  spelling the multiplier list holds it under (arrlsect.dom's `Ut = UT` is
  'Ut'), which is not the text that was asked: a token asked as 'UT' comes
  back 'Ut', and a multiplier list asked with 'UT' would miss it and answer
  "needed on every band". FoundDomesticQTH itself, on a scratch exchange, so
  no QSO is touched. DomesticTableKnowsQTH is this, without the key.

  The answer is TRUE when the table knows the text, and aKey can still be
  EMPTY then -- 'XXX' is accepted with no key, and a contest with no domestic
  multiplier answers True for anything. A caller that wants a multiplier
  tests aKey <> '' as well. aKey is empty when the answer is False. *)
function DomesticKeyOfQTH(const aQTH: string; out aKey: string): boolean;

(* DomesticKeyOfQTH WITH THE DOMESTIC QTH BESIDE THE KEY -- issue 265,
  2026-11-10. aDomesticQTH is what FoundDomesticQTH writes to the QSO's
  DomesticQTH (the file's left side, 'EMA' for 'EM'), aKey its DomMultQTH.
  uContestBase's TDomesticQTHResolve: the ADIF import's lookup
  (MainUnit.ParseADIFRecord hands it in), so an imported section is resolved
  by the very routine a typed one is. Both empty when the answer is False. *)
function DomesticQTHAndKeyOf(const aQTH: string;
                             out aDomesticQTH: string;
                             out aKey: string): boolean;

(* THE MULTIPLIER A REMEMBERED EXCHANGE NAMES -- issue 207, 2026-11-05.

  aText is the exchange the log REMEMBERS for a call (CallsignsList's initial
  exchange, built by GetInitialExchangeStringFromContestExchange for the
  PREFILL), so it joins every field the contest's field list marks: NAQP's
  'TOM CA', Field Day's '2A CT', a Sprint's '123 CT', ARCI's 'CT 599'. And it
  holds the QTH as TYPED, an alias -- 'WF' where arrlsect.dom files the
  multiplier as 'WcF = WC, WF, WCF'.

  aHint is the active contest's DomesticMultiplierHint of the text, upper-cased
  first -- the shape the contest reads (the Sweepstakes section, a DOK, a
  grid); the base answers the text whole.

  FOR A CONTEST THAT LOOKS ITS QTH UP IN ITS DOMESTIC FILE (UsesDomesticFile)
  the hint is then mapped through the loaded table to the MULTIPLIER KEY, as
  the multiplier list spells it ('Ut', 'WcF', 'vE3'):
    1. the whole hint, when the table knows it (DomesticKeyOfQTH -- a county
       line 'ANT/ARM' is its first county, as the QSO's DomMultQTH is);
    2. else the LAST word of the hint the table knows. The QTH follows every
       other field the remembered text can lead with, so a NAQP name that is
       also a state ('DE CA', Del in California) gives CA; a field after the
       QTH (ARCI's power or number) is not a key of any file measured.
  True, with aKey set, when either step found a key; False with aKey = ''
  otherwise -- and always False for a contest with no domestic file, whose
  hint is its own answer.

  MEASURED BEFORE IT WAS BUILT (issue 207): over the contest matrix's 66
  typed exchanges and the .dom files' aliases at every station, 58 contests
  showed a header that was not the multiplier; this rule fixed 851 rows,
  moved none that were right, and met no row where two words of a hint
  mapped. A text that names no QTH the file knows was left to the hint until
  issue 209 option 1 (2026-11-05): it is now EMPTIED, so the header names the
  call -- it was a bare field ('5 ' a zone, 'TOM ' a name, '2A ' a class:
  29 contests measured) -- unless the contest's UnmappedHintIsTheMultiplier
  says the field is its multiplier (YOTA's age).

  ONE ROUTINE FOR BOTH READERS: the "Mult needs for" header (LOGSTUFF.
  DomStringParse) and the cluster spot's section hint (LOGEDIT.
  DomesticKeyKnownForCall, issue 83). The key is never mapped a second time:
  a multiplier key is not always one of its own aliases (michigan_cty.dom's
  'Presq = PRES'), so mapping it again would lose it. *)
function DomesticMultiplierOfRememberedExchange(aText: Str14;
                                               out aHint: string;
                                               out aKey: string): boolean;

(* THE QSO'S DX QTH -- the engine's head, then the contest's own rule
  (TContestBase.DXMultiplierKey, M11 S4). aContest is ActiveContest(Contest),
  fetched ONCE by the caller and shared with whatever else it asks of the
  contest for the same QSO; nil is the classless DUMMYCONTEST. *)
procedure GetDXQTH(aContest: TContestBase; var RXData: ContestExchange);

type
  TMultiplierKinds = set of RemainingMultiplierType;

(* WHICH MULTIPLIER KINDS A QSO EARNS -- the credit half of SetMultFlags,
  LIFTED so the worked counts (issue 12) ask the same chain: no X-QSO, a band
  the contest credits, a worked station the entrant may credit, and per kind
  a key, the contest having that multiplier and its CountsAsMultiplier. It
  says nothing about NEW -- that is the sheet's. aRX.DomMultQTH must already
  be filled (SetMultFlags fills it from DomesticQTH first). aContest is
  ActiveContest(Contest), fetched once by the caller; ceClearMultSheet is the
  caller's test. *)
function MultiplierKindsCredited(aContest: TContestBase;
  const aRX: ContestExchange): TMultiplierKinds;

(* THE SHEET'S BAND AND MODE KEYS FOR A MULTIPLIER -- ONE statement for
  SetMultFlags' new-multiplier question and the spot hint's worked-count read
  (issue 12). The counts are WRITTEN on the QSO's real band and mode into the
  AllBands / Both cells as well (mo.CountWorked), as the bits are, so the
  scope is applied only here, when asked.
  Per band only where MULT BY BAND is on, per mode only where MULT BY MODE
  is; and a DX or domestic multiplier the contest counts once over all bands
  (DXCC / DOMESTIC MULT BY BAND = dmbbAllBand) is keyed on AllBands.

  THE CONTEST DECIDES ALL FOUR. Settings.Mult.ByBand / ByMode are written
  at FoundContest from the class: its trait (cfMultByBand / cfMultByMode,
  FCONTEST.ApplyContestTraits), then whatever its DescribeSession states for
  this station (svMultByBand -- Arizona in state, ALRS), and the operator's
  own MULT BY BAND / MULT BY MODE line wins over the trait. The dmbb pair is
  DescribeSession's too (CQMM, RDA, the RF Championships). The bit sheet has
  always keyed on exactly these; a count keyed on anything else would
  disagree with it. *)
function MultiplierSheetBand(aKind: RemainingMultiplierType; aBand: BandType): BandType;
function MultiplierSheetMode(aMode: ModeType): ModeType;

(* THE TEXT A WORKED COUNT IS KEYED ON for a domestic multiplier: the key
  itself, or its two-character grid FIELD where the contest's multiplier is
  the field (HasGridFieldMultiplier) -- what mo.IsDmMult compares. *)
function DomesticMultiplierCountKey(aContest: TContestBase; const aKey: string): string;

(* DOES THE QSO EARN A SECOND DOMESTIC MULTIPLIER, AND WHICH -- issue #317.
  TRUE WITH aKey when the QSO earns its domestic multiplier (rmDomestic in
  aKinds, so every exclusion the county has -- X-QSO, band, host area,
  CountsAsMultiplier -- is inherited, never restated) AND the contest names
  a second key (TContestBase.AdditionalDomesticMultiplierKey; the base and
  nil answer False). aRX is the copy AddQSOToSheets made, DomMultQTH filled.
  ONE predicate for the sheet mark and the worked count, both in
  AddQSOToSheets; the dupe and ceClearMultSheet tests are that caller's (a
  dupe still marks, as its county flag does; it does not count).

  NO FLAG IS STORED for this key: the sheet re-derives it every time a QSO
  reaches AddQSOToSheets (live, LoadinLog, the rescore), so a load that
  trusts the stored flags and a rescore that re-derives them agree. It is
  marked in the DOMESTIC scope (MultiplierSheetBand(rmDomestic) /
  MultiplierSheetMode) -- the county's -- which is load-bearing: the key is
  reached only through a credited county, so it is new exactly on the first
  credited county QSO of its scope. KNOWN UNDERCOUNT: a reader of the QSO's
  stored flags (UDP <ismultiplier2>, the hourly report's Mults column,
  uHamScore.CountMultipliers) shows one fewer multiplier on that QSO; MTotals
  and the score are right. *)
function AdditionalDomesticMultiplierCredited(aContest: TContestBase;
  const aRX: ContestExchange; aKinds: TMultiplierKinds; out aKey: string): boolean;

(* ADD ONE QSO TO THE WORKED COUNTS -- issue 12. Every kind the QSO earns
  (aKinds, MultiplierKindsCredited of aRX) counts once, new or not, and so
  does aAdditionalDomesticKey when it is not empty (#317); a dupe, an X-QSO
  and a ceClearMultSheet record count nothing. aRX has DomMultQTH filled.
  Called from AddQSOToSheets only, which computes aKinds once for both
  this and the additional key. *)
procedure CountWorkedMultipliers(aContest: TContestBase; const aRX: ContestExchange;
  aKinds: TMultiplierKinds; const aAdditionalDomesticKey: string);

//function GetInitialExchange(Call: CallString): CallString;
function GetInitialExchangeStringFromContestExchange(RData: ContestExchange): string;
procedure GetMultsFromLogEntry(LogEntry: Str80; var RXData: ContestExchange);
//function GetPartialCall(CallAddress: integer): CallString;

procedure LoadInitialExchangeFile;
procedure EnumInitialEx(var FileString: ShortString);

(* THE CALL HISTORY FILE INTO THE INITIAL-EXCHANGE STORE -- 2026-11-07
  (uCallHistory). Read at contest open, AFTER INITIAL.EX and BEFORE the log
  (SheetInitAndLoad), so INITIAL.EX's entry and the file's first row for a
  call win over a later row, and a QSO the log holds replaces the file's
  text (the loader's AddIniitialExchange overwrites). Each entry is stored
  as the FILE'S (TCallsignsList.AddCallHistoryExchange) so a spot comment
  can outrank it (LogEdit.SpotSectionHint).

  Reads nothing unless USE CALL HISTORY FILE is on AND the contest names the
  fields it prefills (TContestBase.CallHistoryFields). The file is CALL
  HISTORY FILENAME, else the contest's TContestBase.CallHistoryFileName. A file that is not
  there is a Warning in the log and nothing else -- never a dialog, never an
  exception. Answers how many entries were added. *)
function LoadCallHistoryFile: integer;

(* THE FILE A BLANK CALL HISTORY FILENAME MEANS: the running contest's own
   default (TContestBase.CallHistoryFileName), '' when it names none. Asked
   by LoadCallHistoryFile and shown by Preferences as the box's hint. *)
function ContestCallHistoryFileName: string;

function PointsToBigCall(Entry: FourBytes): boolean;


(* ~~SetUpExchangeInformation~~ IS DELETED (M11 S9a, 2026-10-14): each
  contest states the fields its received exchange carries,
  TContestBase.ReceivedExchangeFields, and start-up (uProgramMain) assigns
  ExchangeInformation from it. *)

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
  uLogDatabase,     // SQLiteIsBusy -- SaveRestartFile's retry on a busy log
  uLogRepository,   // AnsiToCharArray -- NUL-padded, not a cast
  TypInfo,          // enum names, so an inserted band cannot shift a value
  uNet,
  uGetScores,
  (* ActiveContest -- SetMultFlags asks the contest whether an off-band QSO
    earns a multiplier (ContestCreditsBand, uContestBase -- now in the
    interface uses, for GetDXQTH's parameter). *)
  uContestFactory,
  (* ContestIdentity -- which call history fields the contest prefills. *)
  uContestRegistry,
  (* ContestSession -- the zone kind set-up resolved (M10 S9c). *)
  uContestSession,
  (* ResetLoggedQSOs -- the final score's view of the log is emptied with
    the totals it is kept beside (M6). *)
  uScoreTotals,
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

(* FoundDomesticQTH itself, on a scratch exchange, so the answer is the
  table's own and no QSO is touched. See the declaration. *)
function DomesticQTHAndKeyOf(const aQTH: string;
                             out aDomesticQTH: string;
                             out aKey: string): boolean;
var
  scratch: ContestExchange;
begin
  aDomesticQTH := '';
  aKey := '';
  (* No QTH is no domestic QTH -- answered here so FoundDomesticQTH does not
    log its blank-QTH error for a question nobody typed. *)
  if aQTH = '' then
     begin
     Result := False;
     Exit;
     end;
  FillChar(scratch, SizeOf(ContestExchange), 0);
  (* The cast is a received QTH returning to the width it was typed in. *)
  scratch.QTHString := ShortString(aQTH);
  Result := FoundDomesticQTH(scratch);
  if Result then
     begin
     aDomesticQTH := string(scratch.DomesticQTH);
     aKey := string(scratch.DomMultQTH);
     end;
end;

function DomesticKeyOfQTH(const aQTH: string; out aKey: string): boolean;
var
  ignoredDomesticQTH: string;
begin
  Result := DomesticQTHAndKeyOf(aQTH, ignoredDomesticQTH, aKey);
end;

(* The last space-separated word of aText the table maps to a key -- see
  DomesticMultiplierOfRememberedExchange. Read from the end, so the first
  word found is the answer. *)
function LastWordDomesticKey(const aText: string; out aKey: string): boolean;
var
  wordEnd: integer;
  wordStart: integer;
begin
  Result := False;
  aKey := '';
  wordEnd := Length(aText);
  while wordEnd >= 1 do
     begin
     while (wordEnd >= 1) and (aText[wordEnd] = ' ') do
        begin
        Dec(wordEnd);
        end;
     wordStart := wordEnd;
     while (wordStart >= 1) and (aText[wordStart] <> ' ') do
        begin
        Dec(wordStart);
        end;
     if wordEnd > wordStart then
        begin
        if DomesticKeyOfQTH(Copy(aText, wordStart + 1, wordEnd - wordStart), aKey) and
           (aKey <> '') then
           begin
           Result := True;
           Exit;
           end;
        end;
     wordEnd := wordStart;
     end;
  aKey := '';
end;

function DomesticMultiplierOfRememberedExchange(aText: Str14;
                                               out aHint: string;
                                               out aKey: string): boolean;
var
  contestRules: TContestBase;
begin
  Result := False;
  aKey := '';
  strU(aText);
  (* ONE ActiveContest for the hint and the file question; each table
    lookup below (GetDomQTH) makes its own, as every lookup does. *)
  contestRules := ActiveContest(Contest);
  aHint := ContestDomesticMultiplierHint(contestRules, aText);
  if (aHint = '') or (not ContestUsesDomesticFile(contestRules)) then
     begin
     Exit;
     end;
  if DomesticKeyOfQTH(aHint, aKey) and (aKey <> '') then
     begin
     Result := True;
     Exit;
     end;
  Result := LastWordDomesticKey(aHint, aKey);
  (* NOTHING MAPS -- issue 209 option 1, NY4I 2026-11-05: the hint is a bare
    field (a zone, a name, a class sent with no QTH), not a multiplier, so
    it is emptied and the header names the call (ShowNeedsForCall), unless
    the contest says its unmapped hint IS the multiplier (YOTA's age). *)
  if (not Result) and (not ContestUnmappedHintIsTheMultiplier(contestRules)) then
     begin
     aHint := '';
     end;
end;

function DomesticTableKnowsQTH(const aQTH: string): boolean;
var
  key: string;
begin
  Result := DomesticKeyOfQTH(aQTH, key);
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

(* GetNumber IS GONE -- M11 S4, 2026-10-14. Its only caller was GetDXQTH's
  PACC arm, and it moved with that arm, verbatim, into TContestPACC as
  PACCCallAreaDigit. *)

(* THE QSO'S DX QTH -- M11 S4, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S4).

  THE HEAD IS THE ENGINE'S AND STAYS: COUNT DOMESTIC COUNTRIES is the
  operator's setting, and a domestic-country call earns no DX QTH. Under the
  same setting, whether a QSO's domestic QTH takes the DX multiplier's place
  is the contest's answer since M11 S6 part 1
  (TContestBase.DomesticQTHReplacesDXMultiplier -- the WYSIWYG contests); it
  was the session kind.

  THE REST IS THE CONTEST'S. This was `case ContestSession.DXMult of`, an
  enum choosing which countries count FOR the contest (fifteen arms and an
  `else`). Each DX contest states its own rule in
  TContestBase.DXMultiplierKey now (shared country lists in
  uDXMultiplierKey), and the arms are gone -- with them the four dead since
  M11 S2 (no HB9, no OK, non-European, non-South American). A False answer
  leaves the DX QTH as it was, exactly as an arm that did not match did.

  THE CONTEST IS HANDED IN, NOT FETCHED: ActiveContest rebuilds the station
  on every call, and every caller already asks the contest something else
  for the same QSO, so it fetches once and passes it here. *)
procedure GetDXQTH(aContest: TContestBase; var RXData: ContestExchange);
var
  key                                   : DXMultiplierString;
begin
  if not Settings.Contest.CountDomesticCountries then
     begin
     (* A DOMESTIC QTH TAKES THE PLACE OF THE DX MULTIPLIER where the contest
       says so (TContestBase.DomesticQTHReplacesDXMultiplier, M11 S6 part 1),
       asked of the contest handed in; it was `ContestSession.DomesticMult =
       WYSIWYGDomestic`. *)
     if ContestDomesticQTHReplacesDXMultiplier(aContest) and
        (RXData.DomesticQTH <> '') then
        begin
        Exit;
        end;

     if DomesticCountryCall(RXData.Callsign) then
        begin
        Exit;
        end;
     end;

  if ContestDXMultiplierKey(aContest, RXData, key) then
     begin
     RXData.DXQTH := key;
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

var
  contestRules                          : TContestBase;
  credited                              : ContestExchange;
  kinds                                 : TMultiplierKinds;
  additionalKey                         : string;
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

     (* THE SECOND DOMESTIC KEY (#317), which has no stored flag and is
        derived here, from the record, every time -- AND THE WORKED COUNTS
        (issue 12), every credited working, not only the first the flags
        above record. HERE because the loader, the rescore and LogContact
        all reach this routine, each in log order. One ActiveContest and one
        credit chain per QSO. *)
     contestRules := ActiveContest(Contest);

     (* SetMultFlags' DomMultQTH fill, on a copy: a row read back from the
        log carries what SetMultFlags stored, but a peer's or an imported one
        may hold only DomesticQTH. *)
     credited := RXData^;
     if (credited.DomMultQTH = '') and (credited.DomesticQTH <> '') then
        begin
        credited.DomMultQTH := credited.DomesticQTH;
        end;
     kinds := MultiplierKindsCredited(contestRules, credited);

     (* A DUPE IS NOT EXCLUDED HERE, on purpose: SetMultFlags does not ask
        ceDupe, so a dupe whose county was never credited before (Vermont: a
        WSJT-X QSO earns no county, and the same call, band, mode and county
        in RTTY is a dupe of it) still marks its county above -- and the
        state rides on the county exactly. For every other dupe the county,
        so the state, is already on the sheet and this marks nothing. *)
     if AdditionalDomesticMultiplierCredited(contestRules, credited, kinds, additionalKey) then
        begin
        (* NEW in the county's scope -> marked and totalled, exactly as a
           stored DomesticMult flag is above. *)
        if mo.IsDmMult(additionalKey,
                       MultiplierSheetBand(rmDomestic, credited.Band),
                       MultiplierSheetMode(credited.Mode),
                       ContestHasGridFieldMultiplier(contestRules)) then
           begin
           mo.SetDmMult(additionalKey, credited.Band, credited.Mode);
           end;
        end;

     (* A dupe counts nothing (CountWorkedMultipliers). *)
     if not RXData.ceDupe then
        begin
        CountWorkedMultipliers(contestRules, credited, kinds, additionalKey);
        end;
     end;
end;

procedure DupeAndMultSheet.DisposeOfMemoryAndZeroTotals;

//var
  //Band                                  : BandType;
  //Mode                                  : ModeType;
 // NumberBlocks, Block                   : integer;
  //TempRemainingMultiplierType           : RemainingMultiplierType;
begin

  ClearAllDupeSheets;

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

  if Settings.Qtc.Enable then
     begin
     QTCDataArray := Default(QTCDataArrayType);
     NumberQTCBooksSent := 0;
     NumberQTCStations := 0;
     TotalNumberQTCsProcessed := 0;
     end;

  TotalQSOPoints := 0;
  (* THE VIEW A BONUS RULE READS GOES WITH THE TOTALS -- see uScoreTotals. *)
  ResetLoggedQSOs;
  TotalNamesSent := 0;
  tRestartInfo.riTotalRecordsInLog := 0;
  tUSQ := 0;
  tUSQE := 0;
  FillChar(tRestartInfo.riQSOByOpMode, SizeOf(tRestartInfo.riQSOByOpMode), 0);
  tThisHourPreviousBand := NoBand;
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

procedure EnumInitialEx(var FileString: ShortString);

var
  InitialExchangeString                 : ShortString;
  Call                                  : Str80;
begin
  if FileString[1] = ';' then Exit;

  Call := RemoveFirstString(FileString);
  if FileString <> '' then
     begin
     InitialExchangeString := '';
     while FileString <> '' do
        begin
        InitialExchangeString := InitialExchangeString + RemoveFirstString(FileString) + ' ';
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

  if not EnumerateLinesInFile(Settings.Contest.InitialExchangeFilename, EnumInitialEx, True) then
     begin
     Exit;
     end;

   { Changed this from the MessageBox to a QuickDisplay - Much less intrusive - NY4I 2026JUL07 }
  //TempInteger := TF.Format(wsprintfBuffer, '%s:'#13#10 + TC_THEREWERECALLS, TR4W_INITIALEX_FILENAME, InitialExCallsigns, InitialExDupes);
  if InitialExCallsigns > 0 then
     begin
     QuickDisplay(SysUtils.Format(AnsiString(LclText('%s:' + TC_THEREWERECALLS)), [Settings.Contest.InitialExchangeFilename, InitialExCallsigns, InitialExDupes]));
     end;
 // ShowMessage(wsprintfBuffer);
end;

(* uCallHistory's store, here: CallsignsList, as the file's entry. *)
function AddCallHistoryToCallsignsList(const aCall: string; const aExchange: string): TCallHistoryAddResult;
begin
  Result := CallsignsList.AddCallHistoryExchange(aCall, aExchange);
end;

function ContestCallHistoryFileName: string;
begin
  Result := ContestIdentity(Contest).CallHistoryFileName;
end;

function LoadCallHistoryFile: integer;
var
  fields: TCallHistoryFields;
  name: string;
  path: string;
  legacy: string;
  legacyPath: string;
  lines: TStringList;
  reader: TCallHistoryReader;
  started: QWord;
begin
  Result := 0;
  if not Settings.Contest.UseCallHistoryFile then
     begin
     Exit;
     end;

  fields := ContestIdentity(Contest).CallHistoryFields;
  if Length(fields) = 0 then
     begin
     logger.Info('[CallHistory] USE CALL HISTORY FILE is on, but %s prefills nothing from one; no file read',
                 [ContestIdentity(Contest).DisplayName]);
     Exit;
     end;

  (* THE OPERATOR'S NAME, else the contest's own default. *)
  name := Trim(Settings.Contest.CallHistoryFilename);
  if name = '' then
     begin
     name := ContestCallHistoryFileName;
     end;
  path := CallHistoryFilePath(name);

  (* THE LEGACY NAME, only for the contest's own default: the file was
    SSCW.txt before the default became the site's ARRL-SS-CW.txt, and an
    operator's existing file must keep working. A name the operator typed is
    never second-guessed. *)
  if (Trim(Settings.Contest.CallHistoryFilename) = '') and (not FileExists(path)) then
     begin
     legacy := ContestIdentity(Contest).CallHistoryLegacyFileName;
     if legacy <> '' then
        begin
        legacyPath := CallHistoryFilePath(legacy);
        if FileExists(legacyPath) then
           begin
           logger.Info('[CallHistory] "%s" is not there; reading the legacy file "%s"',
                       [name, legacyPath]);
           name := legacy;
           path := legacyPath;
           end;
        end;
     end;
  lines := TStringList.Create;
  reader := TCallHistoryReader.Create;
  try
     started := GetTickCount64;
     if not ReadCallHistoryLines(path, lines) then
        begin
        logger.Warn('[CallHistory] no call history file read: CALL HISTORY FILENAME = "%s", file "%s" (looked for "%s")',
                    [Settings.Contest.CallHistoryFilename, name, path]);
        Exit;
        end;
     reader.ReadAll(lines, fields, AddCallHistoryToCallsignsList);
     Result := reader.Added;
     logger.Info('[CallHistory] %s: %d rows, %d entries added, %d already known, %d missing a field the contest prefills, in %d ms',
                 [path, reader.DataRows, reader.Added, reader.AlreadyKnown, reader.Incomplete,
                  integer(GetTickCount64 - started)]);
     if reader.UnknownDirectives <> '' then
        begin
        logger.Info('[CallHistory] directives not implemented, ignored: %s', [reader.UnknownDirectives]);
        end;
     if reader.StoreFull > 0 then
        begin
        logger.Warn('[CallHistory] the callsign list is full: %d rows were not stored', [reader.StoreFull]);
        end;
  finally
     reader.Free;
     lines.Free;
  end;
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

      IF NOT Settings.Mult.ByBand THEN Band := All;
      IF NOT Settings.Mult.ByMode THEN Mode := Both;

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
{ This procedure will look at the contest exchange passed to it and see
  if any multiplier flags should be set.  No updating of multiplier arrays
  of totals is done.        }

var
  //Mult, NumberMults                     : integer;
 // TempBand                              : BandType;
  MultMode                              : ModeType;
  contestRules                          : TContestBase;
  kinds                                 : TMultiplierKinds;
  //CompressedMult                        : FourBytes;
  //DomQTH                                : Str20;
 // c                                     : integer;

begin
   logger.Trace('>>> Entering DupeAndMultSheet.SetMultFlags');
   if logger.IsDebugEnabled then
      begin
      logger.debug('DoingDomesticMults = ' + BooleanToStr(ContestHasDomesticMultiplier(ActiveContest(Contest))));
      logger.debug('DoingDXMults       = ' + BooleanToStr(ContestHasDXMultiplier(ActiveContest(Contest))));
      logger.debug('DoingPrefixMults   = ' + BooleanToStr(ContestHasPrefixMultiplier(ActiveContest(Contest))));
      logger.debug('DoingZoneMults     = ' + BooleanToStr(ContestHasZoneMultiplier(ActiveContest(Contest))));
      end;

  if RXData.ceClearMultSheet then Exit;
  ClearMultiplierFlags(RXData);

  (* The band key is asked per kind below -- MultiplierSheetBand. *)
  MultMode := MultiplierSheetMode(RXData.Mode);

  if (RXData.DomMultQTH = '') and (RXData.DomesticQTH <> '') then
     begin
     RXData.DomMultQTH := RXData.DomesticQTH;
     end;

  (* NO MULTIPLIER CREDIT FOR A QSO ON A BAND THE CONTEST DOES NOT USE -- NY4I,
     2026-10-01: "correct, no multiplier credit for off-band QSOs". The points
     half is TContestBase.ScoreQSO (since M3), which asks the same question
     before the class ever sees the QSO.

     HERE, AFTER THE FOUR FLAGS ARE CLEARED, because every flag the program
     keeps is set in this routine: live entry, the rescore, the editable log
     and the multiplier alarm all come through it, and AddQSOToSheets only
     marks the multiplier sheet for a flag set here. So one exit leaves the
     QSO with no multiplier anywhere. AFTER the DomMultQTH fill, too, so the
     QSO still records the QTH it was worked with -- only its credit goes. *)
  contestRules := ActiveContest(Contest);
  (* THE CREDIT CHAIN -- X-QSO, band, worked station, and per kind the
     contest's declaration -- is MultiplierKindsCredited, shared with the
     worked counts (issue 12). WHETHER IT IS NEW is this sheet's. *)
  kinds := MultiplierKindsCredited(contestRules, RXData);

  if rmDomestic in kinds then
     begin
     (* The sheet's grid-field key -- the contest's answer (M11 S6 part 1),
       on the object this routine already holds; it was the session kind. *)
     RXData.DomesticMult := mo.IsDmMult(RXData.DomMultQTH, MultiplierSheetBand(rmDomestic, RXData.Band), MultMode,
                                        ContestHasGridFieldMultiplier(contestRules));
     end;

  if rmDX in kinds then
     begin
     RXData.DXMult := mo.IsDXMult(RXData.QTH.Country, MultiplierSheetBand(rmDX, RXData.Band), MultMode);
     end;

  if rmPrefix in kinds then
     begin
     RXData.PrefixMult := mo.IsPxMult(RXData.Prefix, MultiplierSheetBand(rmPrefix, RXData.Band), MultMode);
     end;

  if rmZone in kinds then
     begin
     RXData.ZoneMult := mo.IsZnMult(RXData.Zone, MultiplierSheetBand(rmZone, RXData.Band), MultMode);
     end;
end;

function MultiplierKindsCredited(aContest: TContestBase;
  const aRX: ContestExchange): TMultiplierKinds;
begin
  Result := [];
  (* NO MULTIPLIER CREDIT FOR ANY X-QSO -- off-band, off-mode or flagged by
     the operator: the ONE predicate ScoreQSO asks too (Q98 S1, design 8.2v). *)
  if QSOIsXQSO(aContest, aRX) then
     begin
     Exit;
     end;
  if not ContestCreditsBand(aContest, aRX.Band) then
     begin
     Exit;
     end;

  (* NOR FOR A WORKED STATION THE ENTRANT MAY NOT CREDIT -- a QSO party's
     host-area rule, Q107 (NY4I, 2026-10-16). The points half is ScoreQSO,
     which asks the same contest the same question; see
     TContestBase.CreditsWorkedStation. *)
  if not ContestCreditsWorkedStation(aContest, aRX) then
     begin
     Exit;
     end;

  (* WHETHER THE QSO EARNS A MULTIPLIER OF A KIND AT ALL IS THE CONTEST'S
     DECLARATION -- M8, design 7.7 stage 2. Five rules that named their
     contest in SetMultFlags went to their classes' CountsAsMultiplier: a
     'DX' QTH earns none in the BC (spelt 'dx'), New York and Indiana QSO
     parties, the PCC's own-country prefix earns none, and the Jock White
     Field Day's own branch and branch 00 earn no zone. *)
  if (aRX.DomMultQTH <> '') and ContestHasDomesticMultiplier(aContest) and
     ContestCountsMultiplier(aContest, aRX, rmDomestic) then
     begin
     Include(Result, rmDomestic);
     end;

  if (aRX.DXQTH <> '') and ContestHasDXMultiplier(aContest) and
     ContestCountsMultiplier(aContest, aRX, rmDX) then
     begin
     Include(Result, rmDX);
     end;

  if (aRX.Prefix <> '') and ContestHasPrefixMultiplier(aContest) and
     ContestCountsMultiplier(aContest, aRX, rmPrefix) then
     begin
     Include(Result, rmPrefix);
     end;

  if (aRX.Zone <> DUMMYZONE) and ContestHasZoneMultiplier(aContest) and
     ContestCountsMultiplier(aContest, aRX, rmZone) then
     begin
     Include(Result, rmZone);
     end;
end;

function MultiplierSheetBand(aKind: RemainingMultiplierType; aBand: BandType): BandType;
begin
  if Settings.Mult.ByBand then
     begin
     Result := aBand;
     end
  else
     begin
     Result := AllBands;
     end;

  if aKind = rmDomestic then
     begin
     Result := GetAddMultBand(DomesticMultByBand, Result);
     end
  else if aKind = rmDX then
     begin
     Result := GetAddMultBand(DXCCMultByBand, Result);
     end;
end;

function MultiplierSheetMode(aMode: ModeType): ModeType;
begin
  if Settings.Mult.ByMode then
     begin
     Result := aMode;
     end
  else
     begin
     Result := Both;
     end;
end;

function DomesticMultiplierCountKey(aContest: TContestBase; const aKey: string): string;
begin
  if ContestHasGridFieldMultiplier(aContest) then
     begin
     Result := Copy(aKey, 1, 2);
     end
  else
     begin
     Result := aKey;
     end;
end;

function AdditionalDomesticMultiplierCredited(aContest: TContestBase;
  const aRX: ContestExchange; aKinds: TMultiplierKinds; out aKey: string): boolean;
begin
  aKey := '';
  Result := False;
  if not (rmDomestic in aKinds) then
     begin
     Exit;
     end;
  Result := ContestAdditionalDomesticMultiplierKey(aContest, aRX, aKey) and
            (aKey <> '');
  if not Result then
     begin
     aKey := '';
     end;
end;

procedure CountWorkedMultipliers(aContest: TContestBase; const aRX: ContestExchange;
  aKinds: TMultiplierKinds; const aAdditionalDomesticKey: string);
begin
  if aRX.ceClearMultSheet or aRX.ceDupe then
     begin
     Exit;
     end;

  if aKinds = [] then
     begin
     Exit;
     end;

  (* THE REAL BAND AND MODE: mo.CountWorked fills the AllBands / Both cells
     too, and the reader's key applies the scope -- as the bits do. *)
  if rmDomestic in aKinds then
     begin
     mo.CountWorked(rmDomestic, DomesticMultiplierCountKey(aContest, string(aRX.DomMultQTH)),
                    aRX.Band, aRX.Mode);
     if aAdditionalDomesticKey <> '' then
        begin
        mo.CountWorked(rmDomestic, DomesticMultiplierCountKey(aContest, aAdditionalDomesticKey),
                       aRX.Band, aRX.Mode);
        end;
     end;
  if rmDX in aKinds then
     begin
     mo.CountWorked(rmDX, IntToStr(aRX.QTH.Country), aRX.Band, aRX.Mode);
     end;
  if rmPrefix in aKinds then
     begin
     mo.CountWorked(rmPrefix, string(aRX.Prefix), aRX.Band, aRX.Mode);
     end;
  if rmZone in aKinds then
     begin
     mo.CountWorked(rmZone, IntToStr(aRX.Zone), aRX.Band, aRX.Mode);
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

   procedure WriteAll;
   var
      b: BandType;
      m: ModeType;
      op: string;
   begin
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

   op := string(CharBufferBytes(CurrentOperator));
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

var
   attempt: integer;
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

   (* NEVER AN UNHANDLED EXCEPTION, AND TRIED AGAIN WHEN THE LOG IS BUSY
     (2026-10-31). This write ran with no handler at all: at 10:39:27 it met
     the WRL worker's commit from a stale read snapshot (see uLogStore's
     BeginMainWrite) and the "database is locked" took the program down at
     startup. LogStoreReadyToWrite ends that snapshot first; a busy failure is
     rolled back and tried again; and any failure that remains is a logged
     warning -- as the note above says, losing this costs where the cursor
     was, never a contact. GLastWritten is emptied after a failure, because it
     would otherwise describe rows the rollback took away, and the next save
     would skip them. *)
   for attempt := 1 to LOG_WRITE_ATTEMPTS do
      begin
      if not LogStoreReadyToWrite then
         begin
         Exit;
         end;
      try
         WriteAll;
         Exit;
      except
         on E: Exception do
            begin
            LogStoreAbandonWrite;
            GLastWritten.Clear;
            if (not SQLiteIsStaleSnapshot(E)) or (attempt = LOG_WRITE_ATTEMPTS) then
               begin
               logger.Warn('[Session] the session state was not saved: %s -- %s. ' +
                           'QSOs are unaffected; it is saved again at the next QSO.',
                           [E.ClassName, E.Message]);
               Exit;
               end;
            end;
      end;
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
      ValChecked(UTF8Decode(text), v, code);
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
  with the right stuff.  Make sure that Settings.Qso.ByBand, Settings.Qso.ByMode and the
  active multiplier globals are setup before executing this.         }

begin
  ReadInBinFiles;
  {?? ??????}
//  SetUpRemainingMultiplierArrays;
  LoadInitialExchangeFile;
  (* AFTER INITIAL.EX and BEFORE the log -- see LoadCallHistoryFile. *)
  LoadCallHistoryFile;
  LoadinLog;
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

     if ContestSession.Exchange = RSTALLJAPrefectureAndPrecedenceExchange then
        begin
        (* A logged QSO whose precedence was never entered holds #0 here. Joined
           in, it put a NUL and a space in front of the prefecture of the
           remembered exchange (issue 210): the QTH alone is the prefill. *)
        if Precedence = #0 then
           begin
           GetInitialExchangeStringFromContestExchange := QTHString;
           end
        else
           begin
           GetInitialExchangeStringFromContestExchange := Precedence + ' ' + QTHString;
           end;
        Exit;
        end;

     if ContestSession.Exchange = RSTDomesticQTHOrQSONumberExchange then
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

     if ContestSession.Exchange = RSTQTHNameAndFistsNumberOrPowerExchange then
        begin
        GetInitialExchangeStringFromContestExchange := QTHString + ' ' + Name + ' ' + Power;
        Exit;
        end;

     if ContestSession.Exchange = RSTZoneOrSocietyExchange then
        begin
        if QTHString <> '' then
           begin
           GetInitialExchangeStringFromContestExchange := QTHString;
           Exit;
           end;
        end;

      if ContestSession.Exchange = RSTZoneOrDomesticQTH then           // 4.95.6
         begin
         if QTHString <> '' then
            begin
            GetInitialExchangeStringFromContestExchange := QTHString;
           Exit;
            end;
         end;

     if ExchangeInformation.Zone then

        begin
        (* A RECEIVED YEAR IS READ FROM ITS OWN FIELD -- issue 298, stage 2.
          The European HF Championship's and KVP's year rides the zone slot of
          the field list; RcvdYearKnown is set only where a contest received a
          year (uContestBase.StoreLicenceYear), so a zone contest's record
          still gives its zone. What this remembers is what the class's
          ZoneMultiplierFromCall reads back for the need hint. *)
        if RcvdYearKnown then
           begin
           TempString := IntToStr(RcvdYear);
           end
        else
           begin
           TempString := IntToStr(Zone);
           end;
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
  (* The active contest, fetched once for the zone questions -- M11 S5
    part 2. *)
  zoneRules                               : TContestBase;

begin
  if Settings.Mult.ByBand then
     begin
     StartBand := Band160;
     FinishBand := Band2304;
     end
  else
     begin
     StartBand := AllBands;
     FinishBand := AllBands;
     end;

  if Settings.Mult.ByMode then
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
  zoneRules := ActiveContest(Contest);
  if ContestHasZoneMultiplier(zoneRules) then
     begin
     (* THE CONTEST SAYS HOW MANY ZONES -- M11 S5, 2026-10-14. This was
       `case ContestSession.ZoneMult of` (CQ 40, the year licensed 100, ITU
       75, the NZART branch 99, the RF Championship 7, and a JA-prefecture
       arm, 50, that ran for no contest). Once per set-up of the remaining
       mults, so one ActiveContest, which also answers whether there is a
       zone multiplier at all (M11 S5 part 2). *)
     MaxNumberOfZones := ContestZoneMultiplierCount(zoneRules);
     end;


end;

(* SaveRestartFile's cache of what it last wrote, made on its first call. Freed
  here so the checked unit-test run (heaptrc) sees no leak once a test saves
  the session state; the interactive program leaves through ExitProcess and
  never runs this, which costs nothing. *)
finalization
   FreeAndNil(GLastWritten);

end.


