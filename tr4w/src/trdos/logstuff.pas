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
unit LogStuff;
{$I ..\tr4w.inc}

{ This unit has a bunch of subroutines that are generic for the logging
  program.  They are stuck here because they can stand alone, or need
  very little VAR interfacing.  This is so they will be out of the way
  and be common to all programs.                                      }

{$IMPORTEDDATA OFF}
interface

uses {Dos, Printer,}Tree,
  uConfigValues,   // Settings.Cw.SpeedIncrement
  utils_text,
  uCallSignRoutines,
  uCTYDAT,
  TF,
  VC,
  utils_file,
  //Country9,
  ZoneCont,
  LogSCP, {Crt,}
  LogWind,
  LogCW,
  LogDupe,
  LogGrid,
  //  Help,
  LogK1EA,
  LOGDVP,
  LogDom, {SlowTree,}
  LogNet,
  LogRadio,
  (* Messages declared nothing here. MAXWORD is the only Win32 name left and
    LCLType -- already in this clause -- has it, same value (2026-09-08). *)
  IdUDPClient, // ny4i 4.44.9
  IdGlobal, // ny4i 4.44.9
  SysUtils, // ny4i 4.44.9
  StrUtils, // 4.90.11
  uMults,
  (* LCLType, for MAXWORD -- the only thing this unit still wanted from the
    Windows unit.

    THE NOTE THAT STOOD HERE WAS STALE: it said the entry was for
    ListView_DeleteAllItems, because "the previous-dupe window is still a raw
    Win32 list view". That window was converted; there is no ListView_ call
    left in this unit, or anywhere in the program. *)
  LCLType,
  FileUtil,       // CopyFile -- was Windows.CopyFileA (LazUtils, not LazFileUtils)
  uTR4WStrings,
  (* THE CONTEST-BLIND WORD CUTTING, lifted at M5b so the contest classes cut
    an exchange exactly as this unit does -- ParseExchange, the Sweepstakes
    word and its record (SSExchangeType). SSPrec went with it, as
    uExchangeTokens.SweepstakesPrecedences. *)
  uExchangeTokens;

var
  MRC: Str10;
  MyCo: string[14];

const

  { Control Byte Constants for Multi-Multi communications }

  MultiMessageBufferSize = 32;

  MultiTalkMessage = 1; { TR6.75 - Supported by K1EANetwork }
  MultiPacketReceivedSpot = 2; { No longer used.  Uses 4 all the time }
  MultiPacketMessageToSend = 3;
  MultiPacketReceivedMessage = 4;
  MultiQSOData = 5; { TR6.75 - Supported by CT Network }
  MultiBandMapMessage = 6; { TR6.76 - Supported by CT Network }
  MultiTimeMessage = 7; { TR6.75 - Reception only from CT Network }
  MultiInformationMessage = 8;
  MultiConfigurationMessage = 9; { Not supported on CT Network }

  DefaultTimeToLive = 30;
  LookForDupes = True;
  DoNotLookForDupes = not LookForDupes;

  ProcessedMultiMessageBufferLength = 256;

  (* ChampionshipRFPointsArray WAS HERE. It is uRFChampionshipPoints'
     RFChampionshipPoints now (M6), read by the Championship's two classes.
     The legacy ChampionshipRFMethod arm that also read it was deleted with
     the scoring case at M10 S3, and this unit no longer uses that one. *)

  ZeroZuluOffsetCQZoneArray: array[1..39] of Byte =
    (
    14,
    19,
    16,
    18,
    19,
    17,
    18,
    19,
    18,
    19,
    21,
    19,
    20,
    0,
    1,
    2,
    4,
    6,
    9,
    2,
    4,
    5,
    7,
    8,
    9,
    7,
    8,
    7,
    8,
    10,
    14,
    12,
    0,
    2,
    0,
    0,
    2,
    1,
    3

    );

  ZeroZuluOffsetITUZoneArray: array[1..66] of Byte =
    (
    14,
    16,
    17,
    18,
    19,
    16,
    18,
    19,
    19,
    17,

    19,
    19,
    21,
    19,
    21,
    20,
    23,
    1,
    2,
    4,

    4,
    5,
    6,
    7,
    8,
    9,
    1,
    2,
    3,
    4,

    5,
    6,
    7,
    8,
    9,
    1,
    1,
    3,
    3,
    4,

    5,
    5,
    6,
    8,
    9,
    0,
    1,
    2,
    6,
    8,

    9,
    0,
    3,
    7,
    9,
    12,
    2,
    8,
    10,
    11,

    13,
    13,
    13,
    10,
    10,
    22

    );

type

  FederalOkrugs =
    (
    UnKnownOkrug,
    DalneVostochnyiy,
    Privolzhskiy,
    SeveroZapadniy,
    Sibirskiy,
    Uralskiy,
    Centralniy,
    Yuzhniy
    );

  (* LIFTED TO uExchangeTokens AT M5b with the routine that fills it, so the
    Sweepstakes class reads an exchange the way this parser does. *)
  SSExchangeType = TSweepstakesFields;

  RememberRecord = record
    Frequency: LONGINT;
    Band: BandType;
    Mode: ModeType;
  end;

  RememberRadioType = array[RadioOne..RadioTwo] of RememberRecord;

  HelloRecPtr = ^HelloRec;

  HelloRec = record
    ID: string[6];
    Greeting: string[6];
    NextRecord: HelloRecPtr;
  end;

  EntryArray = array[1..10] of Str20;

  QuickQSLKeyType = (NoQuickQSLKey,
    QuickKey1,
    QuickKey2);

  ParameterOkayModeType = (
    NoParameterOkayMode,
    Standard,
    QSLButDoNotLog,
    QSLAndLog);

  EntryName = (Unknown,
    Number,
    Precedence,
    Call,
    Check,
    Section,
    NumberPrecedence,
    CheckSection,
    NumberPrecedenceCheckSection);

  KeyHistoryRecord = record
    Key: Char;
    Time: QWord {TimeRecord};   // GetTickCount64
  end;

  DirectionType = (DirectionDown, DirectionUp);

  TwoRadioAction = (CallPutUp,
    SpaceBarPressed,
    F1Pressed,
    F2Pressed,
    FootSwitchWasPressed,
    ReturnPressed,
    EscapePressed,
    ContactDone);

  DualingCQStates = (NoDualingCQs,
    DualGettingExchange,
    DualSendingCQ,
    DualSendingExchange,
    DualSendingQSL,
    SendingDupeMessage,
    WaitingForCallsignInput);

  (* DupeCheckSoundType MOVED to uSettingsModel, 2026-09-13, with its
    spelling table -- it describes a SETTING. *)

  ProcessedMultiMessageRecord = record
    Source: Byte;
    Serial: Byte;
    Check: integer;
  end;

  ProcessedMultiMessageBufferType = array[0..ProcessedMultiMessageBufferLength -
    1] of
    ProcessedMultiMessageRecord;

  ExchangeElementType = (eetUnknown, eetAlpha, eetNumber, eetMixed);

  ParserRecord = record
    prString: string[23];
    prType: ExchangeElementType;
    prInteger: integer;
  end;

  ParsedRecordType = record
    prTotalElements: Cardinal;
    prTotalNumbers: Cardinal;
    prTotalStrings: Cardinal;
    prNumbers: array[0..3] of Cardinal;
    prStrings: array[0..3] of array[0..31] of AnsiChar;
  end;

  // PaserArrayStatusType = array[0..3] of Byte;

  ParserArrayType = record
    paCount: integer;
    paStatus: array[0..3] of ExchangeElementType;
    paElements: array[0..3] of ParserRecord;
  end;

  MultiMessageMemoryRecord = record
    Message: string[100];
    TimeMark: QWord {TimeRecord};   // GetTickCount64
    RetryCount: Byte;
    QSL: boolean;
    Warnings: Byte;
  end;

  MultiMessageListArrayType = array[0..MultiMessageBufferSize - 1] of
    MultiMessageMemoryRecord;
  MultiMessageListPointer = ^MultiMessageListArrayType;

const
  ParameterOkayModeTypeStringArray: array[ParameterOkayModeType] of string = (
    'NONE',
    'STANDARD',
    'QSL BUT DO NOT LOG',
    'QSL AND LOG'
    );

var
  ParserArray: ParserArrayType;
  ParsedRecord: ParsedRecordType;

  SSEx: SSExchangeType;

  //  _showstarttime                        : boolean;
  //  _networktest                          : boolean;

  //  AskIfContestOver                      : boolean = True;
  AutoAltDWindowString: Str20;
  AutoAltDEnable: boolean;
  AutoQSLCount: Byte {= 0};

  BandMapInfoCall: CallString {= ''};
  BeSilent: boolean;

  CallAlreadySent: boolean;
  CallWindowString: CallString {string};
  tCallWindowStringIsDupe: boolean;
  CallWindowEmpty: boolean = True;
  CallsignIsPastedFromBandMap: boolean;
  CallsignIsTypedByOperator: boolean;

  CallsignICameBackTo: CallString;
  ColumnDupeSheetColor: boolean;
  ColumnDupeSheetEnable: boolean = False;
  ControlBreakStatus: boolean;

  DebugFlag: boolean;
  DefaultRST: Word;
  DisplayRefresh: integer = 1;
  //  DoingRescore                     : boolean; {KK1L: 6.71}
  DualingCQState: DualingCQStates {= NoDualingCQs};
  DupeInfoCall: CallString;
  DupeInfoCallPrompt: CallString; {KK1L: 6.73}
  DupeSheetFileEnable: boolean;
  DVKPlaying: boolean;
  DVKStartTime: QWord {TimeRecord};   // GetTickCount64

  EscapeDeletedCallEntry: CallString;
  EscapeDeletedExchangeEntry: Str40;
  ExchangeHasBeenSent: boolean;
  { string, not PAnsiChar: its 22 assignments are all TC_ constants, which
    are resourcestrings now. Its one reader tested it against nil and now
    tests for empty -- see MainUnit. }
  ExchangeErrorMessage: string;
  ExchangeErrorToken: Str40;   // Issue #1010: the offending exchange token, so the caller can place the caret right after it
  ExchangeMemoryFileEnable: boolean;
  ExchangeWindowString: Str40;
  (* THE EXTERNAL LOGGER'S THREE SETTINGS MOVED, 2026-09-10.

    They are Settings.ExternalLogger.Address / .Port / .Enabled in
    uSettingsModel -- published properties of a class, streamed by RTTI, which
    is what an FPC application would have done from the start.  The defaults
    these typed constants carried moved with them, into that class's
    constructor.

    THIS WAS THE SMALLEST COMPLETE CASE IN THE TREE, which is why it went
    first: three settings, no competing structured store, no contest .cfg
    writes them, no multi-op peer sync, and exactly two reading sites.  The UDP
    and WinKeyer groups look similar by reference count and are not -- both
    already have a structured store of their own, so moving them is a merge of
    two models rather than a migration of one.

    See docs\CFG_ARRAY_ELIMINATION.md. *)

  FakePacket: boolean;
  FakeBandMap: boolean;
  FirstHelloRecord: HelloRecPtr;
  FirstMultiMessage: integer;
  //  FloppyFileSaveName                    : ShortString = 'LOGBACK.TRW';
  ForcedEntry: boolean;
  {KK1L: 6.70 switch used in JCTRL2 to add comments to LOGCFG}


  InactiveRigCallingCQ: boolean;
  InitialExchangePutUp: boolean;
  //  IntercomFileOpen                 : boolean;
  //  IntercomFileWrite                : Text;

  KeyHistory: KeyHistoryRecord;

  //   LastDeletedLogEntry             : Str160;
  tLastLogEntryIsDeleted: boolean;
  //  LastDeletedContestExchange       : ContestExchange;
  LastDisplayedBreakTime: integer = -1;
  LastHelloRecord: HelloRecPtr;
  LastMultiMessage: integer;
  LastMultiInfoMessageSum: array[BandType, ModeType] of Byte;
  //  LastQSOLogged                    : ContestExchange;


  LogFileRead: Text;

  LookingForCQExchange: boolean;

  //   ModemPortBaudRate               : integer;
  MultiInfoMessageTimeout: TimeRecord;
  MultiplierFileEnable: boolean;
  //  MultiMessageBuffer               : array[1..5] of Str80;
  MultiRememberBuffer: MultiMessageListPointer;
  MultiRetryTime: integer = 30;
  MultiSerialNumber: integer;
  MultiUpdateMultDisplay: boolean = True;
  (* MultReportMinimumBands DELETED 2026-09-14 -- it is
    Settings.Contest.MultReportMinimumBands now. It had NO READER: the
    declaration and the CFGCA row were the whole of it, so the setting is
    carried rather than withdrawn, per NY4I's ruling on MY IOTA. *)

  NameCallsignPutUp: CallString;


  OldCWTone: integer;

  PacketAutoCR: boolean;
  PacketFile: boolean;
  PacketFileRead: file;
  PacketSpotDisable: boolean;
  PacketSpotEditEnable: boolean;
  ParameterOkayMode: ParameterOkayModeType = Standard;
  PartialCallFileEnable: boolean;
  //  PartialCallMultsEnable                : boolean = True;
  PreviousQSOReceivedData: ContestExchange;
  //W_L_I  PrinterEnabled: boolean;
  ProcessedMultiMessages: ProcessedMultiMessageBufferType;

  ProcessedMultiMessagesStart: integer;
  ProcessedMultiMessagesEnd: integer;


  QuickQSL: QuickQSLKeyType; { to indicate a quick QSL is desired }
  (* RadioServerTCPPort MOVED, 2026-09-10 -- Settings.Radio.TcpServerPort in
    uSettingsModel.  Its default moved into that class's constructor. *)
  // Commander Interface (inbound for WSJT-X)

  RadioSetFreq: LONGINT;
  RandomNameEnable: boolean;
  ReadInCallsign: CallString;
  ReadInLogComputerID: AnsiChar;
  //  ReadInLog                        : boolean;
  ReadInLogBand: BandType;
  ReadInLogDateString: Str10;
  ReadInLogExchange: ShortString {Str40};
  ReadInLogFileName: Str40;
  ReadInLogFileOpen: boolean;
  ReadInLogFileRead: Text;
  ReadInLogMode: ModeType;
  ReadInLogRST: Str10;
  ReadinLogTimeString: Str10;

  ReceivedData: ContestExchange;
  Remember: RememberRadioType;
  RememberBand: BandType;
  RememberMode: ModeType;
  {
    RemoteTerminalBand                    : BandType;
    RemoteTerminalMode                    : ModeType;
    RemoteTerminalPort                    : PortType = NoPort;
  }

  SendQSOImmediately: boolean = True;
  SeventyThreeMessageSent: boolean;

  SendExchangeKeyWhenCWHasStopped: Char = NullKey;

  (* NO INITIALISER ANY MORE. The only field this one named, tAutoReset,
    is Settings.DupeSheet.AutoReset, and the constructor there carries the
    True. DupeSheetEnable was zeroed by the typed constant and is assigned
    by cfgdef before anything reads it, so it is unchanged. *)
  Sheet: DupeAndMultSheet;
  ShowQSOStatusCall: CallString;
  //  ShowSearchAndPounce                   : boolean;

  StationInformationCall: CallString;
  SwitchRadioKey: Char;

  TailEnding: boolean;
  TailEndKey: Char = ']';
  TailEndCallString: CallString;

  TotalDomesticContacts: integer;
  TotalDXContacts: integer;
  TotalIntermediateContacts: integer;


  (* THE FIFTEEN UDP BROADCAST GLOBALS ARE GONE (2026-09-12). Six per-stream
    enables, six ports, an address, an all-QSOs flag, and a UDPBroadcastPort
    that had said "no longer used" beside it for years.

    They were the config array's copy of settings that moved into
    settings\tr4w.json and TUDPBroadcaster in 87ad2fc3, and the two copies
    had drifted exactly as copies do: the contact, score and lookup streams
    asked the broadcaster, while the RadioInfo and rotor broadcasts still
    read these -- so moving a listener in Preferences moved four streams and
    left two aimed wherever a config file last pointed them.

    Ask UDPBroadcaster.Enabled(stream) and UDPBroadcaster.Send(stream, ...).
    There is no address to look up: a stream fans out to every destination
    subscribed to it, which is what makes two listeners expressible. *)

  // Issue #732 -- PSTRotator native UDP interface (separate from the N1MM
  // broadcast above).  Active when ActiveRotatorType = PSTRotator.  PstRotator
  // listens on its "UDP Control Port" (default 12000) at the configured host.


  WindowDupeCheckCall: CallString;

  (* WSJTXUDPPort and WSJTXMulticastGroup are gone (2026-09-12) --
    Settings.Wsjtx.BroadcastPort and .MulticastGroup. The second was a
    Str20 and is an ordinary string now. *)
  psw: integer = 0;
  tPreviousDupeQSOsShowed: boolean;
  //const  tr4w_StartSendingNowKey                    : ;
  udp: TIdUDPClient; // ny4i 4.44.9 Uses to broadcast info
  //procedure AgeReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
  //procedure AgeReceivedHeader(var LogString: Str80; var Underline: Str80);
procedure BandChange(var ActiveBand: BandType; Direction: DirectionType;
                     Radio: RadioPtr = nil);

procedure CalculateQSOPoints(var RXData: ContestExchange);
//procedure ChapterReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure ChapterReceivedHeader(var LogString: Str80; var Underline: Str80);

procedure CheckForLostMultiMessages;
procedure CreateAndSendCQMultiInfoMessage;
procedure CreateAndSendSAPMultiInfoMessage;

procedure DisplayGridSquareStatus(Call: CallString);
function DomStringParse(InputString: Str14): string; //Gav 4.44.8

function DVKRecentlyStarted(MaxElaspedSec100: LONGINT): boolean;
procedure DVKStamp;

function GetCorrectedCallFromExchangeString(var ExchangeString: OpenString
  {Str80}): Str80;
function GetMultiPortCommand: string;
function GetSentRSTFromExchangeString(var ExchangeString: OpenString {Str40}):
  smallInt {Word};

procedure IncrementQTCCount(Call: CallString);
(* IsValidPOTAPark and ResolvePOTAParkFromADIF went to the leaf uPOTAReference
  on 2026-10-13, when POTA gained its class -- see that unit. *)
function IsValidGUID(const guid: string): boolean;
function KeyRecentlyPressed(Key: Char; MaxElaspedSec100: LONGINT): boolean;
procedure KeyStamp(Key: Char);

procedure LoadSpecialHelloFile;
procedure EnumHelloDAT(FileString: PShortString);

function LogFileLooksOkay: boolean;
procedure LogStringToRXData(LogString: Str80; var RXData: ContestExchange);
function LooksLikeACallSign(Call: Str40): boolean;

(* MarineOrAirMobileStation MOVED to uCallSignRoutines on 2026-09-29 -- it
   is a pure suffix test on a callsign, and the Virginia QSO Party class
   needs it without the TRDOS engine behind it. Its two call sites here
   were legacy scoring arms, deleted at M10 S3. *)

{
procedure NewBandMapEntry(Call: CallString;
  Frequency: LONGINT;
  QSXFrequency: LONGINT;
  Mode: ModeType;
  Dupe: boolean;
  Mult: boolean;
  MinutesLeft: integer;
  SendToMulti: boolean;
  Source: CallString);
}
function NumberQTCsThisStation(Call: CallString): integer;
//procedure NameReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure NameReceivedHeader(var LogString: Str80; var Underline: Str80);

procedure ParseFourFields(sExch: Str80; var s1, s2, s3, s4: Str20);
//procedure PrintLogHeader;
function ProcessClassAndDomesticOrDXQTHExchange(Exchange: string {Str80}; var
  RXData: ContestExchange): boolean;
function ProcessExchange(ExchangeString: Str80; var RData: ContestExchange):
  boolean;
function ParseArray(e: Str80): boolean;
function ParseArray2(ExchangeString: Str80): boolean;
function SetRST(Ex: integer; var RST: smallInt {Word}): boolean;

procedure ProcessPartialCallAndInitialExchange(RXData: ContestExchange);
function ProperSalutation(Call: CallString): string;


procedure ReviewBackCopyFiles;
procedure RotorControl(Heading: integer);

procedure BackupLogNow;
procedure SayHello(Call: CallString);
procedure SayName(Call: CallString);
procedure SendMultiInfoMessage(Band: BandType; Mode: ModeType; Message: Str80);
procedure SendMultiCommand(Source: Byte; Destination: Byte; ControlByte: Byte;
  Message: string);

procedure SendSalutation(Call: CallString);
procedure ShowName(Call: CallString);

procedure ShowPreviousDupeQSOs(Call: CallString;
  Band: BandType;
  Mode: ModeType);
procedure SlowDown;
procedure SpeedUp;

procedure StuffInit;
procedure SendUDPRotorCommand(Heading: integer);
procedure SendPSTRotorCommand(Heading: integer;
                              const IPAddress: string;
                              UDPPort: integer);   // Issue #732
function ValidClass(sClass: Str10): boolean;

{ Header and Stamp routines - used when generating a log string }

//procedure BandModeDateTimeNumberCallNameSentStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure BandModeDateTimeNumberCallNameSentHeader(var LogString: Str80; var Underline: Str80);
//procedure CheckReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure CheckReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure ClassReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure ClassReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure KidsReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure KidsReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure MultiplierHeader(var LogString: Str80; var Underline: Str80);
//procedure MultiplierStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure PowerReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure PowerReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure PrecedenceReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure PrecedenceReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure QSONumberReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure QSONumberReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure QSOPointHeader(var LogString: Str80; var Underline: Str80);
//procedure QSOPointStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure QTHReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure QTHReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure PostalCodeReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure PostalCodeReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure RandomCharsSentAndReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure RandomCharsSentAndReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure RSTReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure RSTReceivedStamp(Exchange: ContestExchange; var LogString: Str80);
//procedure RSTSentHeader(var LogString: Str80; var Underline: Str80);
//procedure RSTSentStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure TenTenNumReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure TenTenNumReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure ZoneReceivedHeader(var LogString: Str80; var Underline: Str80);
//procedure ZoneReceivedStamp(Exchange: ContestExchange; var LogString: Str80);

//procedure WriteLogEntry(Entry: Str80);

//function GetFederalOkrug(OblastDigit, OblastChar: Char): FederalOkrugs;
(* ~~InSameFederalOkrug~~ IS uCallSignRoutines.InSameFederalOkrug since M7b --
   lifted so the CQ-M class and the legacy CQMQSOPointMethod arm (deleted at
   M10 S3) asked one function. *)

(* IS THIS BAND IN PLAY FOR THIS CONTEST?

  WARC BANDS ENABLE and VHF BANDS ENABLE, against the WARC/VHF classification
  in BandChangeArray. Exposed as a QUESTION rather than as the table, so no
  caller can get the classification subtly different.

  It answers for the BANDS AN OPERATOR MAY WORK, which is what the Search
  window's band list needs when there is nothing to search: without it that
  list offered 10G and 24G to a station working 20m and 15m (NY4I,
  2026-09-04). *)
function BandIsEnabledForContest(const aBand: BandType): boolean;
//function IsR150Country(OblastDigit, OblastChar: Char): boolean;

implementation

uses uNet,
   uUDPBroadcastConfig, (* TUDPStream / usRotor *)
   uUDPBroadcaster,     (* the one place that knows where a stream goes *)
   uSettingsModel,     // Settings.Bands -- HF / VHF / WARC enables
   (* The B4 list is an LCL grid on the main form -- TR4WPreviousDupesSet. *)
   uMainForm,
   (* Which store a log READ comes from -- step B4.  See uLogSource. *)
   uLogSource,
   (* LogStoreBackup -- the verified SQLite snapshot BackupLogNow publishes. *)
   uLogStore,
   (* The contest factory -- phase F. *)
   uContestBase,
   uContestFactory,
   (* ContestIdentity -- the contest a classless session parses and validates
     an exchange through (M5b). *)
   uContestRegistry,
   (* ContestSession -- the zone kind set-up resolved (M10 S9c). *)
   uContestSession,
  PostUnit,
  MainUnit,
  uRotatorControl,   // RotorControl delegates here -- see its body
  uPOTAParks,
  (* IsValidPOTAPark and LooksLikeAState -- the POTA exchange shape's two
    recognisers, in a leaf since POTA gained its class (2026-10-13). *)
  uPOTAReference,
  uPendingCounties,
  (* ExchangeModeAttribution -- which SETTING put this contest in
    domestic-QTH mode. See the rejections below. *)
  uContestReadiness,
  Classes; // TStringList — used by ProcessRSTAndDomesticQTHExchange

(* THE CONTEST THAT PARSES AND VALIDATES AN EXCHANGE -- M5b, 2026-10-02.

  The active contest's object, which carries the station (a state party asks
  whether we are in its host state), else the contest's identity: a plain
  TContestBase for a contest with no class, whose answers are the shared
  ones. Never nil, so no caller keeps a fallback of its own -- the two that
  did (ValidClass's letter loop and the Field Day DX check, inventory D1 and
  D2) are deleted. *)
function ExchangeContest: TContestBase;
begin
  Result := ActiveContest(Contest);
  if Result = nil then
     begin
     Result := ContestIdentity(Contest);
     end;
end;

(* THE BAND TABLE, AT UNIT LEVEL.

  IT WAS A LOCAL CONST OF RadioCanWorkBand, which is why nothing outside that
  one routine could ask what it knows -- and the Search window needs exactly
  that.

  MOVED, NOT COPIED. A second table of which bands are WARC and which are VHF
  is the kind of duplicate that drifts in silence: the copy is only wrong the
  day somebody adds 60m to one of them. *)
(* THE COUNT IS COMPILER-ENFORCED, so it does not need "hardening".

  MAXBANDS is the array's own BOUND, which means the initialiser below cannot
  quietly disagree with it. Measured on FPC 3.2.2, both directions:

    too many initialisers -> Fatal: Syntax error, ")" expected but "," found
    too few               -> Error: Expected another 1 array elements

  So uncommenting the Band60 row below without bumping the 21 fails the build,
  at that line. It does not truncate and it does not drift.

  Written down because the shape -- a hand-looking count above a long literal
  list -- reads like the classic drift hazard, and the tempting "fix" of
  deriving MAXBANDS := High(BandChangeArray) only moves the same literal into
  the bound while losing the name. The genuinely unbounded form, `array of`,
  would make this a dynamic array and MAXBANDS a RUNTIME value, which the wrap
  arithmetic and the `attempts > MAXBANDS * 2` belt below would both still
  accept -- silently. That would be a step backwards. *)
const
  MAXBANDS = 21;
  BandChangeArray: array[1..MAXBANDS] of BandChangeType =
    (

    (bcBand: Band160; bcWARC: False; bcVHF: False),
    (bcBand: Band80; bcWARC: False; bcVHF: False),
//    (bcBand: Band60; bcWARC: True; bcVHF: False),
    (bcBand: Band40; bcWARC: False; bcVHF: False),
    (bcBand: Band30; bcWARC: True; bcVHF: False),
    (bcBand: Band20; bcWARC: False; bcVHF: False),
    (bcBand: Band17; bcWARC: True; bcVHF: False),
    (bcBand: Band15; bcWARC: False; bcVHF: False),
    (bcBand: Band12; bcWARC: True; bcVHF: False),
    (bcBand: Band10; bcWARC: False; bcVHF: False),
    (bcBand: Band6; bcWARC: False; bcVHF: True),
    (bcBand: Band2; bcWARC: False; bcVHF: True),
    (bcBand: Band222; bcWARC: False; bcVHF: True),
    (bcBand: Band432; bcWARC: False; bcVHF: True),
    (bcBand: Band902; bcWARC: False; bcVHF: True),
    (bcBand: Band1296; bcWARC: False; bcVHF: True),
    (bcBand: Band2304; bcWARC: False; bcVHF: True),
    (bcBand: Band3456; bcWARC: False; bcVHF: True),
    (bcBand: Band5760; bcWARC: False; bcVHF: True),
    (bcBand: Band10G; bcWARC: False; bcVHF: True),
    (bcBand: Band24G; bcWARC: False; bcVHF: True),
    (bcBand: BandLight; bcWARC: False; bcVHF: True)
    );

function BandIsEnabledForContest(const aBand: BandType): boolean;
var
   i: integer;
begin
   Result := False;

   for i := Low(BandChangeArray) to High(BandChangeArray) do
      begin
      if BandChangeArray[i].bcBand <> aBand then
         begin
         Continue;
         end;

      if BandChangeArray[i].bcWARC and (not Settings.Bands.WarcEnabled) then
         begin
         Exit;
         end;

      if BandChangeArray[i].bcVHF and (not Settings.Bands.VhfEnabled) then
         begin
         Exit;
         end;

      Result := True;
      Exit;
      end;
end;


// Can this radio transmit on the frequency TR4W would tune for `Band`?
//
// EffectiveBandFreq is the right thing to test: it is the frequency a band
// change would actually use -- the last one used on that band, or the built-in
// default for a band not yet visited.
//
// Answers True whenever it cannot know: no radio, no driver, or a band with no
// default frequency (the microwave rows are 0).  Coverage is a filter, and a
// filter that guesses would silently remove bands the operator can really work.
function RadioCanWorkBand(Radio: RadioPtr; Band: BandType): boolean;
var
  f: LongInt;
begin
  Result := True;
  if Radio = nil then
     begin
     Exit;
     end;
  if Radio^.tFactoryObject = nil then
     begin
     Exit;
     end;
  f := EffectiveBandFreq(Band, ActiveMode);
  if f <= 0 then
     begin
     Exit;
     end;
  Result := Radio^.tFactoryObject.CoversFrequency(f);
end;

procedure BandChange(var ActiveBand: BandType; Direction: DirectionType;
                     Radio: RadioPtr = nil);

label
  NextBand;

var
  TempInteger: integer;
  attempts: integer;
  startBand: BandType;
begin
  if Radio = nil then
     begin
     Radio := ActiveRadioPtr;
     end;

  // The walk below is a `goto` loop with no bound: every filter (WARC, VHF,
  // Settings.So2r.SkipActiveBand, and now radio coverage) can send it round again, and if
  // between them they reject EVERY band it never returns.  That was survivable
  // while the filters were all operator settings; one driven by what the radio
  // reports deserves a belt.  Two full cycles is far more than any legitimate
  // walk needs.
  startBand := ActiveBand;
  attempts := 0;

  NextBand:

  Inc(attempts);
  if attempts > MAXBANDS * 2 then
     begin
     logger.Warn('[BandChange] No band available after %d attempts -- every band ' +
                 'is filtered out by the WARC/VHF settings or by the radio''s ' +
                 'reported coverage.  Staying put.', [attempts]);
     ActiveBand := startBand;
     Exit;
     end;

  for TempInteger := 1 to MAXBANDS do
    if BandChangeArray[TempInteger].bcBand = ActiveBand then
       begin
       Break;
       end;

  if ActiveBand = NoBand then
     begin
     TempInteger := MAXBANDS;
     end;

  if Direction = DirectionDown then
     begin
     TempInteger := TempInteger - 1;
     if TempInteger = 0 then
        begin
        TempInteger := MAXBANDS;
        end;
     end;

  if Direction = DirectionUp then
     begin

     TempInteger := TempInteger + 1;
     if TempInteger >= MAXBANDS + 1 then
        begin
        TempInteger := 1;
        end;

     end;

  ActiveBand := BandChangeArray[TempInteger].bcBand;

  // A band this radio cannot TRANSMIT on is not a band to change to.  Nothing
  // checked before: on an IC-7100 -- HF, 6 m, 2 m, 70 cm -- band-up from 2 m
  // landed on 222, TR4W sent 222.100 MHz, the radio ignored a frequency it
  // cannot tune, and only the display moved (NY4I bench, 2026-08-04).
  // CoversFrequency answers True for any radio that has not reported its
  // coverage, so this filters nothing it should not.
  if not RadioCanWorkBand(Radio, ActiveBand) then
     begin
     goto NextBand;
     end;

  (* A CONTEST IS NOT HELD ON WARC, so band stepping skips it -- unless the
    contest says it steps there: General QSO, a log (n4af 04.37.11;
    TContestBase.BandStepIncludesWARC, M9b). *)
  if (BandChangeArray[TempInteger].bcWARC) and
     (not ContestIdentity(Contest).BandStepIncludesWARC) then
     begin
     goto NextBand;
     end;
  if (not Settings.Bands.WarcEnabled) and (BandChangeArray[TempInteger].bcWARC) then
     begin
     goto NextBand; // n4af 04.40.7
     end;
  if (not Settings.Bands.VhfEnabled) and (BandChangeArray[TempInteger].bcVHF) then
     begin
     goto NextBand;
     end;

  if Settings.Bands.VhfEnabled then
    if (not Settings.Bands.HfEnabled) and (not BandChangeArray[TempInteger].bcVHF) then
       begin
       goto NextBand;
       end;

  if Settings.So2r.SkipActiveBand then
     begin
     if (Radio1.BandMemory = ActiveBand) then
        begin
        goto NextBand;
        end;
     if (Radio2.BandMemory = ActiveBand) then
        begin
        goto NextBand;
        end;
     end;

  SendStationStatus(sstBandModeFreq);

  //{WLI}
  DisplayBandMode(ActiveBand, ActiveMode, True);

  //?? ??? ???? ?????? ? ?????????
  {
      IF ((ActiveRadio = RadioOne) AND (Radio1Type <> NoInterfacedRadio)) OR
         ((ActiveRadio = RadioTwo) AND (Radio2Type <> NoInterfacedRadio)) THEN
             DisplayBandMode (ActiveBand, ActiveMode, True)
         ELSE
             DisplayBandMode (ActiveBand, ActiveMode, False);
  }

end;

{ THE QTC-PER-STATION TABLE EXISTS WHEN IT IS USED.

  ACCESS VIOLATION SAVING A QTC BOOK (NY4I, 2026-09-01, crash log naming
  IncrementQTCCount <- SaveQTCS <- QTCSendCommand). QTCDataArray is a POINTER
  and had exactly one allocation site -- `if Settings.Qtc.Enable then New(QTCDataArray)`
  in LogCfg -- so whether the table exists depended on a config flag read at
  config-load time, while whether it is USED depends on the operator pressing a
  button in a window whose menu item is enabled by the CONTEST alone
  (MainUnit's `Contest in [DARCWAEDCCW..DARCWAEDCSSB]`). Two different gates for
  one feature, and nothing checked they agreed.

  NOT A PORT REGRESSION: the D7 tree at C:\TR4W has the same single gated
  allocation, the same nil guard in LOGDUPE, and the same UNGUARDED
  dereferences here (checked 2026-09-01). Somebody knew -- LOGDUPE tests
  `QTCDataArray <> nil` before zeroing it -- but the knowledge stayed in the one
  routine that had it.

  ALLOCATED ON DEMAND, BY THE CODE THAT USES IT, which removes the ordering
  question rather than answering it. LogCfg's line is left alone: it is harmless
  and it is where the table is sized for a contest that declares QTCs up front.

  AND ZEROED, which New alone does not do. LOGDUPE zeroes it when clearing the
  dupe sheet, so the uninitialised case was survivable only because
  NumberQTCStations happens to start at 0 and the code never reads past it. That
  is an invariant held by two globals that nothing keeps in step. }
procedure EnsureQTCDataArray;
begin
  if QTCDataArray <> nil then
     begin
     Exit;
     end;

  New(QTCDataArray);
  FillChar(QTCDataArray^, SizeOf(QTCDataArrayType), 0);

  { A table that has just been created holds no stations.  Said here rather than
    assumed, because the count is a SEPARATE global and this is the one place
    that can know the two are consistent. }
  NumberQTCStations := 0;
end;

function NumberQTCsThisStation(Call: CallString): integer;

var
  Station: integer;
begin
  NumberQTCsThisStation := 0;
  if NumberQTCStations = 0 then
     begin
     Exit;
     end;

  EnsureQTCDataArray;

  for Station := 0 to NumberQTCStations - 1 do
    if QTCDataArray^[Station].Call = Call then
       begin
       Result := QTCDataArray^[Station].NumberQTCs;
       Exit;
       end;
end;

procedure IncrementQTCCount(Call: CallString);
var
  Station: integer;
begin
  inc(TotalNumberQTCsProcessed);
  EnsureQTCDataArray;

  if NumberQTCStations = 0 then
     begin
     QTCDataArray^[NumberQTCStations].Call := Call;
     QTCDataArray^[NumberQTCStations].NumberQTCs := 1;
     inc(NumberQTCStations);
     Exit;
     end;

  for Station := 0 to NumberQTCStations - 1 do
    if QTCDataArray^[Station].Call = Call then
       begin
       inc(QTCDataArray^[Station].NumberQTCs);
       Exit;
       end;

  { THE TABLE IS array[0..499] AND THIS IS THE ONLY THING THAT WRITES PAST ITS
    END.  The bound check stood here as two commented-out `showint` calls --
    somebody saw it, reached for a debug print, and left it.  A 500th station is
    not reachable in any real contest, but the consequence if it ever were is a
    silent write over whatever follows the table, which is the worst outcome
    available.  Counted, reported once, and the QSO still logs. }
  if NumberQTCStations > High(QTCDataArrayType) then
     begin
     if logger <> nil then
        begin
        logger.Warn('[QTC] more than %d stations have sent QTCs; ' +
                    'the per-station count for %s is not being kept',
                    [Length(QTCDataArrayType), string(Call)]);
        end;
     Exit;
     end;

  QTCDataArray^[NumberQTCStations].Call := Call;
  QTCDataArray^[NumberQTCStations].NumberQTCs := 1;
  inc(NumberQTCStations);
end;

function ProperSalutation(Call: CallString): string;

var
  TempQTHData: QTHRecord;
  Hours, ZeroZuluOffset: Word;
  CurrentHelloRecord: HelloRecPtr;
  ID: CallString;

begin
  ctyLocateCall(Call, TempQTHData);

  if FirstHelloRecord <> nil then
     begin
     ID := TempQTHData.CountryID;
     CurrentHelloRecord := FirstHelloRecord;

     repeat
       if UpperCase(CurrentHelloRecord^.ID) = ID then
          begin
          ProperSalutation := CurrentHelloRecord^.Greeting;
          Exit;
          end;

       CurrentHelloRecord := CurrentHelloRecord^.NextRecord;
     until CurrentHelloRecord = nil;
     end;

  if CTY.ctyZoneMode = CQZoneMode then
     begin
     if (TempQTHData.Zone >= 1) and (TempQTHData.Zone <= 39) then
        begin
        ZeroZuluOffset := ZeroZuluOffsetCQZoneArray[TempQTHData.Zone];
        end;

     if TempQTHData.Zone = -1 then
        begin
        ZeroZuluOffset := 18;
        end;
     if TempQTHData.Zone = 40 then
        begin
        ProperSalutation := 'TU';
        Exit;
        end;

     end
  else
     begin
     if (TempQTHData.Zone >= 1) and (TempQTHData.Zone <= 66) then
        begin
        ZeroZuluOffset :=
          ZeroZuluOffsetITUZoneArray[TempQTHData.Zone]
        end
     else
        begin
        ProperSalutation := 'TU';
        Exit;
        end;

     end;

  Hours := GetIntegerTime div 100;
  Hours := (Hours + ZeroZuluOffset) mod 24;

  if (Hours >= 2) and (Hours <= 11) then
     begin
     ProperSalutation := 'GM';
     end;
  if (Hours >= 12) and (Hours <= 17) then
     begin
     ProperSalutation := 'GA';
     end;
  if (Hours >= 18) or (Hours <= 1) then
     begin
     ProperSalutation := 'GE';
     end;
end;

procedure EnumHelloDAT(FileString: PShortString);
var
  Greeting, ID: Str20;
begin
  GetRidOfPrecedingSpaces(FileString^);
  ID := RemoveFirstString(FileString^);
  GetRidOfPrecedingSpaces(FileString^);
  GetRidOfPostcedingSpaces(FileString^);
  Greeting := FileString^;

  if FirstHelloRecord = nil then
     begin
     FirstHelloRecord := New(HelloRecPtr);
     FirstHelloRecord^.ID := ID;
     FirstHelloRecord^.Greeting := Greeting;
     FirstHelloRecord^.NextRecord := nil;
     LastHelloRecord := FirstHelloRecord;
     end
  else
     begin
     LastHelloRecord^.NextRecord := New(HelloRecPtr);
     LastHelloRecord := LastHelloRecord^.NextRecord;
     LastHelloRecord^.ID := ID;
     LastHelloRecord^.Greeting := Greeting;
     LastHelloRecord^.NextRecord := nil;
     end;
end;

procedure LoadSpecialHelloFile;

begin
  if FirstHelloRecord <> nil then
     begin
     Exit;
     end;
  EnumerateLinesInFile('HELLO.DAT', EnumHelloDAT, True);
end;

procedure SendSalutation(Call: CallString);

begin
  if Call = '' then
     begin
     Exit;
     end;
  AddStringToBuffer(ProperSalutation(Call), Config.CWTone);
end;

procedure SayHello(Call: CallString);

var
  Salutation, Name: Str20;
  RandomNumber: integer;

begin
  Call := RootCall(Call);
  Name := UpperCase(CD.GetName(Call));

  if (Name <> '') and (Name <> 'CLUB') then
     begin
     Salutation := ProperSalutation(Call);
     if Salutation = 'TU' then
        begin
        Salutation := 'HI';
        end;
     RandomNumber := Random(10);
     if RandomNumber >= 7 then
        begin
        Salutation := 'HI';
        end;
     AddStringToBuffer(Salutation + ' ' + Name + ' ', Config.CWTone);
     ReceivedData.NameSent := True;
     end
  else
    //    ReceivedData.NameSent := False;
end;

procedure ShowName(Call: CallString);

var
  Name: CallString;
begin
  Call := RootCall(Call);

  NameCallsignPutUp := Call;
  Name := CD.GetName(Call);

  (* THE NAME ITSELF. A pointer to Name[1] stood here, read as a C string --
    which is why the FillChar above it existed: to leave a zero after the
    text. An empty name was a nil pointer, which the caption read as ''. *)
  TR4WMainForm.pnlName.Caption := Name;
end;

procedure SayName(Call: CallString);

var
  Name: Str20;

begin
  Call := RootCall(Call);
  Name := UpperCase(CD.GetName(Call));

  if (Name <> '') and (Name <> 'CLUB') then
     begin
     AddStringToBuffer(Name + ' ', Config.CWTone);
     ReceivedData.NameSent := True;
     end
  else
    //    RemoveWindow(NameSentWindow);
end;

function DVKRecentlyStarted(MaxElaspedSec100: LONGINT): boolean;

begin
  if not DVKPlaying then
     begin
     DVKRecentlyStarted := False;
     Exit;
     end;

  DVKRecentlyStarted := MaxElaspedSec100 >= ElaspedSec100(DVKStartTime);
end;

procedure DVKStamp;

begin
  //???? ?? ???? ??? ??? ???? ??????? ??? ????????
  {
    DVKPlaying := True;

    GetTime(DVKStartTime.Hour,
      DVKStartTime.Minute,
      DVKStartTime.Second,
      DVKStartTime.Sec100);
  }
end;

function KeyRecentlyPressed(Key: Char; MaxElaspedSec100: LONGINT): boolean;

begin
  KeyRecentlyPressed := False;
  if Key <> KeyHistory.Key then
     begin
     Exit;
     end;
  KeyRecentlyPressed := MaxElaspedSec100 >= ElaspedSec100(KeyHistory.Time);
end;

procedure KeyStamp(Key: Char);

begin
  KeyHistory.Key := Key;
  KeyHistory.Time := GetTickCount64;
  {  with KeyHistory do
    begin
      GetTime(Time.Hour, Time.Minute, Time.Second, Time.Sec100);
    end;
  }
end;

procedure ParseExchange(Exchange: ShortString {Str80} {WLI}; var FirstString,
  SecondString, ThirdString: Str10 {Str20});

begin
  (* LIFTED TO uExchangeTokens AT M5b (2026-10-02), line for line, so a contest
    class can split an exchange the way the engine does -- UK/EI's rule needs
    the second word. One copy; this name stays for its twenty callers here. *)
  SplitExchangeInThree(Exchange, FirstString, SecondString, ThirdString);
end;

function ProcessKidsExchange(ExchangeString: Str80; var RData: ContestExchange):
  boolean;

begin
  RData.Kids := ExchangeString;
  ProcessKidsExchange := True;
end;

function ProcessClassAndDomesticOrDXQTHExchange(Exchange: string {Str80}; var
  RXData: ContestExchange): boolean;

{ If the call is a domestic call, there must be a space with the Class
  before the space and the Domestic QTH after it.  If it is a not a domestic
  call the exchange must just be the Class.  In both cases, the Class must
  be at least two characters in length. }
{KK1L: 6.68 This needed to change for the new FD rules which allow all of Region 2 to participate.}
{           Now DX can send a class. Let's still force a check for domesticity and require both a }
{           class and section. For others if the second string of the exchange is blank I will }
{           "let it slide" and assume the first string is class (likely "DX"). }

var
  TempString, TempString2: Str10 {Str20};
  isClassValid: boolean;
  dx: boolean;
  factoryError: string;
  resolvedQTH: string;

  // ParseExchange writes up to 10 characters through a `var Str10`, and
  // RXData.ceClass is a string[3] -- FOUR bytes.  The two calls below used to
  // pass Str10(RXData.ceClass), a variable typecast that Delphi accepts
  // silently and that lets ParseExchange write SEVEN BYTES PAST the field,
  // over ZERO_04, Precedence, ceRadio and Check.  Parsing into a correctly
  // sized local and assigning back truncates instead, which is the defined
  // Pascal behaviour and what the 3-character field was asking for.
  // (FPC rejects the cast outright: "Typecast has different size (4 -> 11)".)
  classTemp: Str10;
begin
  ProcessClassAndDomesticOrDXQTHExchange := False;
  logger.debug('Entered ProcessClassAndDomesticOrDXQTHExchange with Exchange of (%s)', [Exchange]);
  if DomesticCountryCall(RXData.Callsign) then
     begin
     dx := false;
     FillChar(RXData.ceClass, SizeOf(RXData.ceClass), 0);
     // Both ZOT added to prevent errors with bad data in log from corrected entry ny4i
     FillChar(RXData.QTHString, SizeOf(RXData.QTHString), 0);
     classTemp := '';
     ParseExchange(Exchange, classTemp, RXData.QTHString, TempString);
     RXData.ceClass := classTemp;   // truncates to 3; see classTemp's note

     if RXData.QTHString[1] in ['0'..'9'] then
       // This is the code that flips it around if given in section class order // ny4i
        begin
        FillChar(TempString, SizeOf(TempString), 0);
        FillChar(TempString2, SizeOf(TempString2), 0);

        TempString := RXData.ceClass;
        TempString2 := RXData.QTHString;

        FillChar(RXData.ceClass, SizeOf(RXData.ceClass), 0);
        FillChar(RXData.QTHString, SizeOf(RXData.QTHString), 0);

        RXData.ceClass := TempString2;
        RXData.QTHString := TempString;
        end;
     // if I enter 999D wtx, then correct it to 99d wtx, then length is of class is still 4. Fix that.
     logger.debug('Calling FoundDomesticQTH from ProcessClassAndDomesticOrDXQTHExchange - QTHString = (%s)', [RXData.QTHString]);
     if not FoundDomesticQTH(RXData) then
        begin
        ExchangeErrorMessage := 'Invalid ARRL Section'; {TC_IMPROPERDOMESITCQTH;}
        ExchangeErrorToken := RXData.QTHString;   // Issue #1010: caret goes after the bad section
        logger.error('[ProcessClassAndDomesticOrDXQTHExchange] Improper Domestic QTH = Exchange = (%s), DomesticQTH = (%s)', [Exchange, RXData.QTHString]);
        // misspelled in the constants file //ny4i 4.45.3
        Exit; // This was before the above code that flips the values. // ny4i 4.45.3
        end;
     isClassValid := ValidClass(RXData.ceClass);
     if not isClassValid then
        begin
        ExchangeErrorToken := RXData.ceClass;   // Issue #1010: caret goes after the bad class
        end;
     Result := IsClassValid;
     end
  else
     begin
     dx := true;
     {ParseExchange (Exchange, RXData.Class, RXData.QTHString, TempString);} {pre 6.68 statement}
     FillChar(RXData.ceClass, SizeOf(RXData.ceClass), 0);
     // Both ZOT added to prevent errors with bad data in log from corrected entry ny4i
     FillChar(RXData.QTHString, SizeOf(RXData.QTHString), 0);

     classTemp := '';
     ParseExchange(Exchange, classTemp, TempString, TempString2);
     RXData.ceClass := classTemp;   // truncates to 3; see classTemp's note
     // It used to be that only IARu Region 2 send a class butr the current ARRL FD rules simpl;y
     // state the following:
     //  DX stations send operating class and the term DX (i.e. 2A DX).
     if true {RxData.QTH.Continent in [NorthAmerica, SouthAmerica] } then
       // If IARU Region 2 then we get class (most likely 1D if they are home).
        begin
        isClassValid := ValidClass(RxData.ceClass);
        Result := isClassValid;
        end
     else
        begin
        Result := length(RXData.ceClass) in [2, 3];
        // If it is non-Region 2 DX, just make sure it is two or three characters.
        if not Result then
           begin
           ExchangeErrorMessage := TC_NOTENOUGHINFOINEXCHANGE;
           end;
        end;
     if Result then // If class passes, check QTH is DX
        begin
        (* WHAT A DX STATION MAY SEND IS THE CONTEST'S RULE -- phase F.

           This was the last `if contest = ...` in this routine: Winter Field
           Day accepts 'MX' where ARRL Field Day does not. Both now answer for
           themselves, so the two contests differ in two separate files rather
           than in one branch here.

           The contest returns what to STORE as well as whether it is legal,
           because an EMPTY exchange resolves to 'DX' -- a DX station sending
           only a class means DX -- and that substitution is a decision, not
           formatting.

           EVERY CONTEST IS ASKED SINCE M5b (2026-10-02) -- ExchangeContest,
           which answers a classless contest with its identity. The
           `TempString = 'DX'` chain that stood below, a copy of the Field
           Days' rule for a contest with no class, is deleted (inventory D2):
           only the two Field Days run this exchange, and both have a
           class. *)
        Result := ExchangeContest.ValidateDXQTH(string(TempString),
                                                resolvedQTH,
                                                factoryError);
        (* VIA AnsiString: a UnicodeString assigned straight to a
           ShortString narrows, but an AnsiString to a ShortString does not
           -- CLAUDE.md states exactly that, and it is why the step is here
           rather than a cast. The values are 'DX', 'MX' or what the operator
           typed into a Str10, so nothing can be lost. *)
        RXData.QTHString := AnsiString(resolvedQTH);
        if not Result then
           begin
           ExchangeErrorMessage := factoryError;
           end;
        end;
     //if TempString <> '' then RXData.QTHString := TempString;
     end;

  // Result is set in one of two paths above...

  //  ProcessClassAndDomesticOrDXQTHExchange :=
   // ProcessClassAndDomesticOrDXQTHExchange := (length(RXData.ceClass) in [2, 3]) and ((RxData.ceClass = 'A') or (RxData.ceClass = 'B') or (RxData.ceClass = 'C') or (RxData.ceClass = 'D') or (RxData.ceClass = 'E') or (RxData.ceClass = 'F'));
  logger.debug('Leaving ProcessClassAndDomesticOrDXQTHExchange with ceClass = (%s) and QTHString = (%s)', [RXData.ceclass, RXData.QTHString]);
end;

function ProcessRSTAgeAndPossibleSK(Exchange: ShortString; var RXData:
  ContestExchange): boolean;
const
  exNNUU: array[0..3] of ExchangeElementType = (eetNumber, eetNumber,
    eetUnknown, eetUnknown);
  exNMNU: array[0..3] of ExchangeElementType = (eetNumber, eetMixed, eetNumber,
    eetUnknown);
  exNNMN: array[0..3] of ExchangeElementType = (eetNumber, eetNumber, eetMixed,
    eetNumber);
begin
  Result := False;
  if ParseArray2(Exchange) then // 4.66.2
     begin
     case ParserArray.paCount of
       1:
         if ParserArray.paElements[0].prType = eetNumber then
            begin
            RXData.Age := ParserArray.paElements[0].prInteger;
            Result := True;
            end;

       2:
         if Cardinal(ParserArray.paStatus) = Cardinal(exNNUU) then
            begin
            if not SetRST(ParserArray.paElements[0].prInteger, RXData.RSTReceived)
              then
               begin
               Exit;
               end;
            RXData.Age := ParserArray.paElements[1].prInteger;
            Result := True;
            end;

       3:
         if Cardinal(ParserArray.paStatus) = Cardinal(exNMNU) then
            begin
            RXData.Age := ParserArray.paElements[0].prInteger;
            if not IsAGoodCall(ParserArray.paElements[1].prString) then
               begin
               Exit;
               end;
            if not (ParserArray.paElements[2].prInteger in [0..255]) then
               begin
               Exit;
               end;
            RXData.QTHString := ParserArray.paElements[1].prString + ' ' +
              IntToStr(ParserArray.paElements[2].prInteger);
            Result := True;
            end;

       4:
         if Cardinal(ParserArray.paStatus) = Cardinal(exNNMN) then
            begin
            if not SetRST(ParserArray.paElements[0].prInteger, RXData.RSTReceived)
              then
               begin
               Exit;
               end;
            RXData.Age := ParserArray.paElements[1].prInteger;
            if not IsAGoodCall(ParserArray.paElements[2].prString) then
               begin
               Exit;
               end;
            if not (ParserArray.paElements[3].prInteger in [0..255]) then
               begin
               Exit;
               end;
            RXData.QTHString := ParserArray.paElements[2].prString + ' ' +
              IntToStr(ParserArray.paElements[3].prInteger);
            Result := True;
            end;
     end;
     end;
end;

function ProcessRSTAndContinentExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

{ Any digits found at the start of the exchange will be used to determine
  the RS(T).  If the first character is not a digit, the default RS(T)
  will be used and the whole exchange will be used as the QTH. }

var
  TempString: Str80;
  QTHFound: boolean;
  ContPrefix: Str20;

begin
  QTHFound := False;
  RXData.QTH.Continent := UnknownContinent;

  ProcessRSTAndContinentExchange := False;
  GetRidOfPrecedingSpaces(Exchange);
  GetRidOfPostcedingSpaces(Exchange);

  if not StringHas(Exchange, ' ') and not StringIsAllNumbers(Exchange) then
     begin
     RXData.RSTReceived := DefaultRST;

     ContPrefix := UpperCase(Copy(Exchange, 1, 2));
     RXData.QTH.Continent := GetContinentFromString(ContPrefix);
     RXData.QTHString := Exchange;

     Result := RXData.QTH.Continent <> UnknownContinent;

     if not Result then
        begin
        ExchangeErrorMessage := TC_IMPROPERCONTINENT;
        end;

     Exit;
     end;

  while Exchange <> '' do
     begin
     TempString := RemoveLastString(Exchange);

     if StringIsAllNumbers(TempString) and (RXData.RSTReceived = 0) then
        begin
        if length(TempString) = 1 then
           begin
           case ActiveMode of
             CW: RXData.RSTReceived := 509 + (Ord(TempString[1]) - 48) * 10;
             Phone: RXData.RSTReceived := 5 + (Ord(TempString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TempString, 0)
           end
        end
     else if not QTHFound then
        begin
        ContPrefix := UpperCase(Copy(Exchange, 1, 2));
        RXData.QTH.Continent := GetContinentFromString(ContPrefix);
        {
                  if ContPrefix = 'AF' then RXData.QTH.Continent := Africa;
                  if ContPrefix = 'AS' then RXData.QTH.Continent := Asia;
                  if ContPrefix = 'OC' then RXData.QTH.Continent := Oceania;
                  if ContPrefix = 'EU' then RXData.QTH.Continent := Europe;

                  if (ContPrefix = 'SO') or (ContPrefix = 'SA') then RXData.QTH.Continent := SouthAmerica;
                  if (ContPrefix = 'NO') or (ContPrefix = 'NA') then RXData.QTH.Continent := NorthAmerica;
      }
        RXData.QTHString := Exchange;

        if RXData.QTH.Continent <> UnknownContinent then
           begin
           QTHFound := True;
           RXData.QTHString := TempString;
           end;
        end;
     end;

  if QTHFound then
     begin
     if RXData.RSTReceived = 0 then
        begin
        RXData.RSTReceived := DefaultRST;
        end;
     ProcessRSTAndContinentExchange := True;
     end;
end;

function ProcessNameQTHAndPossibleTenTenNumberExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

var
  TempString: ShortString {Str80};
  ThirdString, NumberString: Str10 {Str20};
  Result1: integer;
  //   tempstr20                       : Str20;
begin
  ProcessNameQTHAndPossibleTenTenNumberExchange := False;

  if Exchange = '' then
     begin
     Exit;
     end;

  TempString := Exchange;
  Exchange := '';

  RXData.TenTenNum := MAXWORD {-1};

  while TempString <> '' do
     begin
     NumberString := RemoveFirstString(TempString);

     if StringIsAllNumbers(NumberString) then
        begin
        Val(NumberString, RXData.TenTenNum, Result1)
        end
     else
        begin
        Exchange := Exchange + NumberString + ' ';
        end;
     end;

  ParseExchange(Exchange, RXData.Name, RXData.QTHString, ThirdString);

  if not DomesticCountryCall(RXData.Callsign) then
     begin
     ProcessNameQTHAndPossibleTenTenNumberExchange := True
     end
  else
     begin
     ProcessNameQTHAndPossibleTenTenNumberExchange := FoundDomesticQTH(RXData);
     end;

end;

function ProcessNameAndDomesticOrDXQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Two entries with space, name is first. IF DX, then no QTH. }

var
  FirstString: Str10;
  SecondString: Str10;
  ThirdString: Str10;

begin
  ProcessNameAndDomesticOrDXQTHExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;
  // ParseExchange(Exchange, RXData.Name, RXData.QTHString, ThirdString);   // old parse
  ParseExchange(Exchange, FirstString, SecondString, ThirdString); //4.51.7
  // check for a corrected number
  if StringIsAllNumbers(ThirdString) then // n4af 4.51.7
     begin
     RXData.Name := FirstString;
     RXData.QTHString := ThirdString;
     end
  else
    {// check for a corrected name}if IsAlpha(ThirdString) then // 4.51.7
       begin
       RXData.Name := ThirdString;
       RXData.QTHString := SecondString;
       end
    else
       begin
       RXData.Name := FirstString;
       RXData.QTHString := SecondString;
       end;
  if not DomesticCountryCall(RXData.Callsign) then
     begin
     ProcessNameAndDomesticOrDXQTHExchange := True
     end
  else
     begin
     logger.debug('Calling FoundDomesticQTH from ProcessNameAndDomesticOrDXQTHExchange');
     ProcessNameAndDomesticOrDXQTHExchange := FoundDomesticQTH(RXData);
     end;
  if Result = False then
     begin
     ExchangeErrorMessage := TC_IMPROPERDOMESITCQTHORMISSINGNAME;
     end;

end;

{ ---------------------------------------------------------------------------
  Shared county-line exchange helpers.

  Two exchange parsers accept more than one domestic QTH for a single QSO:
  ProcessRSTAndDomesticQTHExchange ("599 DAL/BAY") and
  ProcessQSONumberAndDomesticQTHExchange ("123 SLUI/MONT" -- the California
  and Pennsylvania QSO Party form).  Everything the two share about that
  lives here so they cannot drift apart: the tokenizer, the domestic-mults
  probe, and the "first county belongs to this QSO, the rest are queued" rule.

  What they do NOT share is what a numeric token means -- RS(T) for one, the
  received serial number for the other -- so numbers are handed back to the
  caller instead of being interpreted here.

  Issue #885 (county-line bridging), extended to the serial-number exchanges
  for CQP 2026.
  --------------------------------------------------------------------------- }

procedure SplitExchangeIntoNumbersAndDomesticQTHs(Exchange: ShortString;
  NumericTokens: TStringList; ValidQTHs: TStringList;
  UnknownTokens: TStringList);

{ Classify every token in Exchange as an all-numeric token, a valid domestic
  QTH, or neither -- returning each group in user-typed (left to right) order.

  A token that is NEITHER is handed back in UnknownTokens rather than dropped.
  It used to be discarded in silence, so "32 SLUI/MTY" -- a mistyped second
  county, and MTY is exactly the abbreviation people reach for when the file
  wants MONT -- logged one QSO for SLUI and lost the other leg with nothing
  said.  The operator cannot see a QSO that was never written.

  All '/' characters are mapped to spaces first, so a county-line exchange may
  be given either way: "SLUI/MONT" and "SLUI MONT" travel the same path. }

var
  TempString                            : Str80;
  ProbeRX                               : ContestExchange;
  i                                     : integer;

begin
  for i := 1 to Length(Exchange) do
     begin
     if Exchange[i] = '/' then
        begin
        Exchange[i] := ' ';
        end;
     end;

  { RemoveLastString returns the rightmost token, so the walk runs right to
    left; Insert(0, ...) rebuilds user-typed order in both lists. }

  while Exchange <> '' do
     begin
     TempString := RemoveLastString(Exchange);

     if TempString = '' then
        begin
        Continue;
        end;

     if StringIsAllNumbers(TempString) then
        begin
        NumericTokens.Insert(0, TempString);
        end
     else
        begin
        { Probe with a scratch ContestExchange so the walk can continue past
          the first match without disturbing the caller's record --
          FoundDomesticQTH writes DomMultQTH / DomesticQTH onto whatever
          record it is handed. }

        FillChar(ProbeRX, SizeOf(ProbeRX), 0);
        ProbeRX.QTHString := TempString;

        if FoundDomesticQTH(ProbeRX) then
           begin
           ValidQTHs.Insert(0, TempString);
           end
        else
           begin
           UnknownTokens.Insert(0, TempString);
           end;
        end;
     end;
end;

procedure ReportIgnoredQTHTokens(const aCaller: string;
  UnknownTokens: TStringList);

{ Say what was thrown away.  Both parsers need this and they name themselves
  differently in the log, so the caller is passed in rather than the message
  being written out twice.

  DELIBERATELY NOT FATAL.  The valid counties in the exchange are real and the
  QSO should stand; refusing the whole entry would also change behaviour for
  the thirteen QSO parties on the RST parser, where a stray token has always
  been tolerated.  The operator is told and the QSO is logged, which is the
  difference between a warning and a silent loss.

  QuickDisplayError, not QuickDisplay: it beeps.  A message that only appears
  in a corner of the screen during a run rate is a message nobody reads. }

var
  i                                     : integer;
  IgnoredList                           : string;

begin
  if UnknownTokens.Count = 0 then
     begin
     Exit;
     end;

  IgnoredList := '';

  for i := 0 to UnknownTokens.Count - 1 do
     begin
     if IgnoredList <> '' then
        begin
        IgnoredList := IgnoredList + ' ';
        end;

     IgnoredList := IgnoredList + UnknownTokens[i];
     end;

  logger.Error('[%s] Ignored unrecognised QTH token(s): %s', [aCaller, IgnoredList]);
  QuickDisplayError(TC_IGNOREDUNKNOWNQTH + ' ' + IgnoredList);
end;

function ApplyFirstQTHAndQueueRest(ValidQTHs: TStringList;
  var RXData: ContestExchange): boolean;

{ The first valid QTH in user-typed order belongs to the QSO being built: put
  it on RXData and re-run FoundDomesticQTH against the real record so that
  DomMultQTH / DomesticQTH carry the canonical name.  Every further QTH is
  queued for TryLogContact, which drains the queue immediately after writing
  this QSO and logs one more QSO per queued county -- all of them sharing the
  one transmitted serial number.

  Returns False, with ExchangeErrorMessage set, when the exchange named no
  recognisable domestic QTH at all.  The caller logs the failure, because the
  two callers name themselves differently in the log. }

var
  i                                     : integer;
  contestObject                         : TContestBase;
  countyCountError                      : string;

begin
  Result := False;

  if ValidQTHs.Count = 0 then
     begin
     ExchangeErrorMessage := TC_IMPROPERDOMESITCQTH;
     Exit;
     end;

  (* HOW MANY QTHs MAY THIS CONTEST'S EXCHANGE CLAIM?

     THE COUNT IS OURS AND THE LIMIT IS THE CONTEST'S. We have just tokenised
     the exchange, so the number is in hand; the rule about it belongs to the
     contest object, which is handed the NUMBER and never the list -- a
     contest that could see the QTHs would be one step from being handed the
     log to count them in.

     EVERYTHING EXCEPT A STATE QSO PARTY IS UNCHANGED, AND THAT SENTENCE USED
     TO BE WRONG. It read "a contest with no class, and any contest that has
     not established its limit, is unchanged ... this gate opens for everything
     TR4W accepted before" -- which was false the moment any contest acquired a
     class, because the inherited answer read ContestsArray's CountyLineAllowed
     boolean and a row without that field answered ZERO, refusing a second QTH.
     Arktika Spring hit it (fixed 2026-09-29).

     TContestBase.ValidateQTHCount now always passes, so ActiveContest being
     nil and ActiveContest being a non-QSO-party class give the SAME answer as
     each other and as TR4W before the factory existed. Only
     TContestStateQSOPartyBase overrides it, and only where a number was
     actually read out of a sponsor's rulebook. *)
  contestObject := ActiveContest(Contest);
  if contestObject <> nil then
     begin
     if not contestObject.ValidateQTHCount(ValidQTHs.Count,
                                           countyCountError) then
        begin
        ExchangeErrorMessage := countyCountError;
        logger.Error('[ApplyFirstQTHAndQueueRest] %s Counties = %d',
                     [countyCountError, ValidQTHs.Count]);
        Exit;
        end;
     end;

  RXData.QTHString := ValidQTHs[0];
  Result := FoundDomesticQTH(RXData);

  if not Result then
     begin
     ExchangeErrorMessage := TC_IMPROPERDOMESITCQTH;
     Exit;
     end;

  for i := 1 to ValidQTHs.Count - 1 do
     begin
     QueuePendingCounty(ValidQTHs[i]);
     end;
end;

function ProcessQSONumberAndDomesticQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ The QSO number and the domestic QTH may appear in either order.

  Multi-county handling: the operator can name more than one county in a
  single exchange when working a station that bridges a county line --

    "123 SLUI/MONT"   slash-separated
    "123 SLUI MONT"   space-separated
    "123SLUI/MONT"    number typed hard against the county, as always
    "SLUI/MONT 123"   either order

  The first valid county stays with THIS QSO; the rest are pushed onto
  uPendingCounties so TryLogContact writes one further QSO per county.

  A run of digits is split off as its own token, which reproduces the
  digit/letter split this function has always performed for "123SLUI".  That
  split is unambiguous for this exchange: no abbreviation in any domestic file
  used by the contests that select it (california_cty, pa_cty, va_cty,
  ukraine, grids) contains a digit -- re-verified against target/dom in this
  tree on 2026-08-31. }

var
  Normalized                            : ShortString;
  NumericTokens                         : TStringList;
  ValidQTHs                             : TStringList;
  UnknownTokens                         : TStringList;
  ConversionResult                      : integer;
  i                                     : integer;

begin
  Result := False;
  ClearPendingCounties;

  if Length(Exchange) = 0 then
     begin
     Exit;
     end;

  RXData.QTHString := '';

  { Insert a space at every digit <-> non-digit boundary so the QSO number is
    its own token even when typed hard against the county.  Separation on
    spaces and on '/' is handled by the splitter. }

  Normalized := '';

  for i := 1 to Length(Exchange) do
     begin
     if (i > 1)                                                                      and
        (Exchange[i] <> ' ')                                                         and
        (Exchange[i - 1] <> ' ')                                                     and
        (tCharIsNumbers(Char(Exchange[i])) <> tCharIsNumbers(Char(Exchange[i - 1]))) then
        begin
        Normalized := Normalized + ' ';
        end;

     Normalized := Normalized + Exchange[i];
     end;

  NumericTokens := TStringList.Create;
  ValidQTHs := TStringList.Create;
  UnknownTokens := TStringList.Create;

  try
     SplitExchangeIntoNumbersAndDomesticQTHs(Normalized, NumericTokens, ValidQTHs,
                                             UnknownTokens);

     { This exchange is "number and QTH": a bare QTH with no number has always
       been rejected here, and still is. }

     if NumericTokens.Count = 0 then
        begin
        ExchangeErrorMessage := TC_IMPROPERDOMESITCQTH;
        logger.Error('[ProcessQSONumberAndDomesticQTHExchange] No QSO number in exchange (%s)', [Exchange]);
        Exit;
        end;

     Val(NumericTokens[0], RXData.NumberReceived, ConversionResult);

     if ConversionResult <> 0 then
        begin
        ExchangeErrorMessage := TC_IMPROPERDOMESITCQTH;
        logger.Error('[ProcessQSONumberAndDomesticQTHExchange] Bad QSO number (%s)', [NumericTokens[0]]);
        Exit;
        end;

     Result := ApplyFirstQTHAndQueueRest(ValidQTHs, RXData);

     if not Result then
        begin
        logger.Error('[ProcessQSONumberAndDomesticQTHExchange] Improper Domestic QTH - Exchange = (%s)', [Exchange]);
        end
     else
        begin
        { Only once the exchange stands.  A rejected exchange already reports
          itself above, and two complaints about one entry is noise. }

        ReportIgnoredQTHTokens('ProcessQSONumberAndDomesticQTHExchange', UnknownTokens);
        end;
  finally
     NumericTokens.Free;
     ValidQTHs.Free;
     UnknownTokens.Free;
     end;
end;

function ProcessQSONumberAndGridSquareExchange(Exchange: ShortString; var
  RXData: ContestExchange): boolean;
var
  TempString, NumberString: Str40;
  GridString: Str20;
  Result1: integer;

begin
  NumberString := '';
  GridString := '';

  Result := False;

  while (Exchange <> '') and ((NumberString = '') or (GridString = '')) do
     begin
     TempString := RemoveLastString(Exchange);

     if StringIsAllNumbers(TempString) then
        begin
        NumberString := TempString
        end
     else
        begin
        GridString := TempString;
        end;

     end;

  if GridString = '' then
     begin
     Exit;
     end;
  if NumberString = '' then
     begin
     NumberString := Copy(GridString, 1, length(GridString) - 4);
     if not StringIsAllNumbers(NumberString) then
        begin
        Exit;
        end;
     GridString := Copy(GridString, length(GridString) - 3, 4);
     end;

  if not GoodLookingGrid(GridString) then
     begin
     Exit;
     end;

  RXData.QTHString := GridString;

  Val(NumberString, RXData.NumberReceived, Result1);

  if Result1 <> 0 then
     begin
     Exit;
     end;

  Result := FoundDomesticQTH(RXData);
end;

function ProcessQSONumberAndNameExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

var
  TempString, NumberString, NameString: Str40;
  Result1: integer;

begin
  NumberString := '';
  NameString := '';

  ProcessQSONumberAndNameExchange := False;

  while (Exchange <> '') and ((NumberString = '') or (NameString = '')) do
     begin
     TempString := RemoveLastString(Exchange);

     if StringIsAllNumbers(TempString) then
        begin
        NumberString := TempString
        end
     else
        begin
        NameString := TempString;
        end;

     end;

  if (NumberString = '') or (NameString = '') then
     begin
     Exit;
     end;

  RXData.Name := NameString;

  Val(NumberString, RXData.NumberReceived, Result1);

  ProcessQSONumberAndNameExchange := Result1 = 0;
end;

function ProcessQSONumberAndZoneExchange(Exchange: ShortString; var RXData:
  ContestExchange): boolean;
var
  string1, string2, string3: Str10;
begin

  Result := False;

  if StringIsAllNumbersOrSpaces(Exchange) then
     begin
     ParseExchange(Exchange, string1, string2, string3);
     if string2 <> '' then
        begin
        RXData.Zone := StrToIntDef(string1, 0);
        RXData.NumberReceived := StrToIntDef(string2, 0);
        Result := True;
        Exit;
        end;
     end;

  if length(Exchange) < 4 then
     begin
     ExchangeErrorMessage := TC_NOTENOUGHINFOINEXCHANGE;
     Exit;
     end;

  if not StringIsAllNumbers(Exchange) then
     begin
     Exit;
     end;

  RXData.Zone := Ord(Exchange[1]) - 48;
  RXData.NumberReceived := StrToIntDef(Copy(Exchange, 2, 4), 0);
  {
    if (Contest = UA4N) then
    begin
      if length(Exchange) > 4 then
      begin
        RXData.Zone := StrToIntDef(Copy(Exchange, 1, 2), 0);
        RXData.NumberReceived := StrToIntDef(Copy(Exchange, 3, 4), 0);
      end
      else
        Exit;
    end;
  }
  Result := True;
end;

function ProcessQSONumberAndGeoCoordinatesExchange(Exchange: ShortString
  {Str80}; var RXData: ContestExchange): boolean;

var
  TempString, NumberString, QTHString: Str20;
  Result1: integer;
  Lat, Long: integer;
begin

  NumberString := '';
  QTHString := '';

  Result := False;

  while (Exchange <> '') and ((NumberString = '') or (QTHString = '')) do
     begin
     TempString := RemoveLastString(Exchange);

     if StringIsAllNumbers(TempString) then
        begin
        NumberString := TempString
        end
     else
        begin
        //      if Contest = RUSSIAN160 then if LooksLikeRadio160Square(TempString) then QTHString := TempString;
        if LooksLikeAGeoCoordinates(TempString, Lat, Long) then
           begin
           QTHString := TempString;
           end;
        end;

     end;

  if (NumberString = '') or (QTHString = '') then
     begin
     Exit;
     end;

  RXData.QTHString := QTHString;

  Val(NumberString, RXData.NumberReceived, Result1);

  Result := Result1 = 0;

end;

function ProcessQSONumberAndCoordinatesSumExchange(Exchange: ShortString; var
  RXData: ContestExchange): boolean;
var
  NumberString, QTHString: Str20;
  Result1, i: integer;

begin

  NumberString := '';
  QTHString := '';

  Result := False;

  NumberString := RemoveLastString(Exchange);
  QTHString := RemoveLastString(Exchange);
  if not StringIsAllNumbers(NumberString) then
     begin
     Exit;
     end;
  if not StringIsAllNumbers(QTHString) then
     begin
     if length(NumberString) < 3 then
        begin
        Exit;
        end;
     if (NumberString[1] = '1') or (NumberString[2] = '1') then
        begin
        i := 3
        end
     else
        begin
        i := 2;
        end;

     QTHString := Copy(NumberString, 1, i);
     NumberString := Copy(NumberString, i + 1, 10);
     if QTHString = '' then
        begin
        Exit;
        end;
     end;

  if length(QTHString) = 1 then
     begin
     Exit;
     end;
  if length(QTHString) > 3 then
     begin
     Exit;
     end;

  RXData.QTHString := QTHString;
  Val(NumberString, RXData.NumberReceived, Result1);
  Result := Result1 = 0;
end;

{
function ProcessQSONumberAndCoordinatesSumExchange(Exchange: string; var RXData: ContestExchange): boolean;
var
  NumberString, QTHString          : Str20;
  Result1                          : integer;
begin

  NumberString := '';
  QTHString := '';

  Result := False;

  NumberString := RemoveLastString(Exchange);
  QTHString := RemoveLastString(Exchange);
  if not StringIsAllNumbers(NumberString) then Exit;
  if not StringIsAllNumbers(QTHString) then Exit;
  if length(QTHString) = 1 then Exit;
  if length(QTHString) > 3 then Exit;

  RXData.QTHString := QTHString;
  Val(NumberString, RXData.NumberReceived, Result1);
  Result := Result1 = 0;
end;
}

function ProcessRSTAndOrGridSquareExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

var
  TestString: Str20;

begin
  ProcessRSTAndOrGridSquareExchange := False;
  RXData.DomesticQTH := '';
  //RXData.RSTReceived := 0;  // This seems like it should not be here. If it is set, why would we zero it out?   // ny4i

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  while Exchange <> '' do
     begin
     TestString := RemoveLastString(Exchange);

     if GoodLookingGrid(TestString) then
        begin
        if RXData.DomesticQTH = '' then
           begin
           RXData.DomesticQTH := TestString;
           RXData.QTHString := TestString;
           ProcessRSTAndOrGridSquareExchange := True;
           end;
        end
     else if (RXData.RSTReceived = 0) and StringIsAllNumbers(TestString) then
        begin
        if length(TestString) = 1 then
           begin

           case ActiveMode of
             CW: RXData.RSTReceived := 509 + (Ord(TestString[1]) - 48) * 10;
             Phone: RXData.RSTReceived := 50 + (Ord(TestString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TestString, 0);
           end;

        ProcessRSTAndOrGridSquareExchange := True;
        end;
     end;

  {ua4wli}
  if (RXData.DomesticQTH <> '') and (RXData.RSTReceived = 0) then
     begin
     case ActiveMode of
       Phone: RXData.RSTReceived := 59;
     else
       RXData.RSTReceived := 599;
     end;
     end;

end;

function ProcessGridSquareExchange(Exchange: ShortString {Str80}; var RXData:
  ContestExchange): boolean;
begin
  Result := False;
  RXData.DomesticQTH := '';

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  if GoodLookingGrid(Exchange) then
     begin
     if RXData.DomesticQTH = '' then
        begin
        RXData.DomesticQTH := Exchange;
        RXData.QTHString := Exchange;
        Result := True;
        end;
     end

end;

function ProcessGrid2Exchange(Exchange: ShortString {Str80}; var RXData:
  // 4.90.11
  ContestExchange): boolean;
begin
  Result := False;
  RXData.DomesticQTH := '';

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  if GoodLookingGrid2(Exchange) then
     begin
     if RXData.DomesticQTH = '' then
        begin
        RXData.DomesticQTH := LeftStr(Exchange, 2);
        RXData.QTHString := Exchange;
        Result := True;
        end;
     end

end;

function ProcessRSTAndGrid3Exchange(Exchange: ShortString {Str80}; var RXData:
  // 4.96.3
  ContestExchange): boolean;
var
  FirstString, SecondString, ThirdString: Str10;

begin

  Result := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);
  if SecondString = '' then
     begin
     Exchange := FirstString;
     RXData.RSTReceived := DefaultRST;
     end
  else
     begin
     RXData.RSTReceived := StrToIntDef(FirstString, 0);
     Exchange := SecondString;
     end;

  if GoodLookingGrid3(Exchange) then
     begin
     //    if RXData.DomesticQTH = '' then
     RXData.DomesticQTH := leftstr(Exchange, 2);

     RXData.QTHString := Exchange;
     Result := True;

     end

end;

function ProcessRSTAndGridSquareExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

var
  TestString: Str20;

begin
  ProcessRSTAndGridSquareExchange := False;
  RXData.DomesticQTH := '';
  RXData.RSTReceived := 0;

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  while Exchange <> '' do
     begin
     TestString := RemoveLastString(Exchange);

     if GoodLookingGrid(TestString) then
        begin
        if RXData.QTHString = '' then
           begin
           RXData.QTHString := TestString;
           end;
        end
     else if (RXData.RSTReceived = 0) and StringIsAllNumbers(TestString) then
        begin
        if length(TestString) = 1 then
           begin
           case ActiveMode of
             CW: RXData.RSTReceived := 509 + (Ord(TestString[1]) - 48) * 10;
             Phone: RXData.RSTReceived := 50 + (Ord(TestString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TestString, 0);
           end;

        end;
     end;

  if (RXData.DomesticQTH <> '') and (RXData.RSTReceived = 0) then
     begin
     case ActiveMode of
       Phone: RXData.RSTReceived := 59;
     else
       RXData.RSTReceived := 599;
     end;
     end;

  ProcessRSTAndGridSquareExchange := FoundDomesticQTH(RXData);
end;

function ProcessNameAndPossibleGridSquareExchange(Exchange: ShortString {Str80};
  var RXData: ContestExchange): boolean;

var
  TestString: Str80;

begin
  ProcessNameAndPossibleGridSquareExchange := False;
  RXData.DomesticQTH := '';
  RXData.Name := '';

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  while Exchange <> '' do
     begin
     TestString := RemoveLastString(Exchange);

     if GoodLookingGrid(TestString) then
        begin
        if RXData.DomesticQTH = '' then
           begin
           RXData.DomesticQTH := TestString;
           RXData.QTHString := TestString;
           end;
        end
     else if RXData.Name = '' then
        begin
        RXData.Name := TestString;
        end;
     end;

  ProcessNameAndPossibleGridSquareExchange := RXData.Name <> '';
end;

function ProcessQSONumberAndDomesticOrDXQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

var
  Result1: integer;
  FirstString, SecondString, ThirdString: Str10 {Str20};

begin
  ProcessQSONumberAndDomesticOrDXQTHExchange := False;

  { The DX branch below never queues counties, so clear the queue here
    rather than only in the domestic branch -- otherwise a DX call worked
    right after a county-line entry would inherit the stale queue. }

  ClearPendingCounties;

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  if not DomesticCountryCall(RXData.Callsign) then
     begin
     ParseExchange(Exchange, FirstString, SecondString, ThirdString);
     getridofprecedingspaces(FirstString);
     getridofprecedingspaces(SecondString);
     getridofprecedingspaces(ThirdString);
     if StringIsAllNumbers(FirstString) then
        begin
        Val(FirstString, RXData.NumberReceived, Result1);
        ProcessQSONumberAndDomesticOrDXQTHExchange := Result1 = 0;
        end
     else if StringIsAllNumbers(SecondString) then
        begin
        Val(SecondString, RXData.NumberReceived, Result1);
        ProcessQSONumberAndDomesticOrDXQTHExchange := Result1 = 0;
        end;

     RXData.QTHString := RXData.QTH.CountryID;
     end
  else
     begin
     ProcessQSONumberAndDomesticOrDXQTHExchange :=
       ProcessQSONumberAndDomesticQTHExchange(Exchange, RXData);
     end;

end;

procedure ParseExchangeIntoFields(Exchange: ShortString {Str80};
  var Entries: EntryArray;
  var NumberEntries: integer);

begin
  NumberEntries := 0;

  while Exchange <> '' do
     begin
     inc(NumberEntries);
     Entries[NumberEntries] := RemoveFirstString(Exchange);
     if NumberEntries = 10 then
        begin
        Exit;
        end;
     end;
end;

procedure ParseFourFields(sExch: Str80; var s1, s2, s3, s4: Str20);

type
  pSTRING = ^string;

var
  CharIndex, iDstPtrIndex: integer;
  bInField: boolean;
  aps: array[0..3] of pShortString;
  ps: pShortString;
  c: AnsiChar;

begin

  s1 := '';
  s2 := '';
  s3 := '';
  s4 := '';

  aps[0] := @s1;
  aps[1] := @s2;
  aps[2] := @s3;
  aps[3] := @s4;

  CharIndex := 1;
  iDstPtrIndex := 0;
  bInField := False;

  while (CharIndex <= length(sExch)) and (iDstPtrIndex <= 3) do
     begin
     c := sExch[CharIndex];
     inc(CharIndex);
     if c <> ' ' then
        begin
        if not bInField then
           begin
           bInField := True;
           ps := aps[iDstPtrIndex];
           ps^ := ps^ + c;
           end
        else
           begin
           ps^ := ps^ + c;
           end;
        end
     else if bInField then
        begin
        bInField := False;
        inc(iDstPtrIndex);
        end
     end;

end;

function LooksLikeACallSign(Call: Str40): boolean;

type
  GOT = (gotNIL, gotLETTER, gotNUMBER);

var
  CharIndex, nChanges: integer;
  gotWhat: GOT;

begin
  LooksLikeACallSign := false;
  (* A WORD THE CONTEST SAYS IS NOT A CALL -- the PCC's 'N/X' (4.83.7) stood
    here as `if contest = PCC`. TContestPCC.MayBeACallsign says it since M5b;
    every other contest has no objection to any word.

    ContestIdentity, NOT the active contest: the rule is what the contest IS
    and needs no station, and LOGDVP calls this routine too -- the identity is
    the registry's thread-safe answer, where ActiveContest rebuilds the
    station on every call. *)
  if not ContestIdentity(Contest).MayBeACallsign(string(Call)) then
     begin
     Exit;
     end;

  {MMAA contest}
  if length(Call) > 3 then
     begin
     if Call[1] in ['S', 'N'] then
       if Call[2] = 'A' then
         if Call[3] = '/' then
           if Call[4] in ['M', 'Y', 'Q', 'C'] then
              begin
              Exit;
              end;
     end;

  gotWhat := gotNIL;
  nChanges := 0;

  for CharIndex := 1 to length(Call) do
     begin
     if (Call[CharIndex] >= 'A') and (Call[CharIndex] <= 'Z') then
        begin
        if gotWhat = gotNUMBER then
           begin
           inc(nChanges);
           end;
        gotWhat := gotLETTER;
        end
     else if (Call[CharIndex] >= '0') and (Call[CharIndex] <= '9') then
        begin
        { Calls don't end with numbers unless already have '/' }

        if CharIndex = length(Call) then
           begin
           Exit;
           end;

        { Calls don't start with two numbers }

        if (gotWhat = gotNUMBER) and (CharIndex = 2) then
           begin
           Exit;
           end;

        if gotWhat = gotLETTER then
           begin
           inc(nChanges);
           end;

        gotWhat := gotNUMBER;
        end
     else if Call[CharIndex] = '/' then
        begin
        // A '/' at the very start or very end of the token cannot belong
        // to a callsign (no prefix or no body to suffix).
        if (CharIndex = 1) or (CharIndex = length(Call)) then
           begin
           LooksLikeACallSign := False;
           Exit;
           end;
        // Otherwise: do NOT return True here just because we found a '/'.
        // The legacy code returned True at the first interior '/' which
        // misfires for state-QP multi-county exchanges like "PIN/HIL" --
        // both halves are all-letter county codes that resemble nothing
        // like a real callsign.  Real callsigns require a letter<->digit
        // transition in the prefix/body, which the end-of-function
        // `nChanges >= 2` check enforces.  Tokens like "PIN/HIL" have
        // nChanges = 0 and correctly fail that check.  See the
        // Callsign-Update-Enable / Howie / county-line discussion.
        end;
     end;

  LooksLikeACallSign := (nChanges >= 2) and (gotWhat = gotLETTER);

end;

function ProcessQSONumberNameChapterAndQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Used for the QCWA contest.  The Chapter might be 2 or 3 integers, of AL
  for At Large.

  Valid formats:
      QSO# NAME CHAPTER QTH or NAME CHAPTER QTH QSO#

  }

var
  FirstString, SecondString, ThirdString, FourthString: Str20;
  Result1: integer;

begin
  ProcessQSONumberNameChapterAndQTHExchange := False;

  if length(Exchange) < 9 then
     begin
     Exit;
     end;

  ParseFourFields(Exchange, FirstString, SecondString, ThirdString,
    FourthString);

  if StringIsAllNumbers(FirstString) then
     begin
     if not (StringIsAllNumbers(ThirdString) or (UpperCase(ThirdString) = 'AL'))
       then
        begin
        Exit;
        end;

     Val(FirstString, RXData.NumberReceived, Result1);

     RXData.Name := SecondString;
     RXData.Chapter := UpperCase(ThirdString);
     RXData.DomesticQTH := FourthString;
     end

  else { Number at end? }

     begin
     if not StringIsAllNumbers(FourthString) then
        begin
        Exit;
        end;
     if not (StringIsAllNumbers(SecondString) or (UpperCase(SecondString) = 'AL'))
       then
        begin
        Exit;
        end;

     Val(FourthString, RXData.NumberReceived, Result1);

     RXData.Name := FirstString;
     RXData.Chapter := UpperCase(SecondString);
     RXData.DomesticQTH := ThirdString;
     end;

  ProcessQSONumberNameChapterAndQTHExchange := True;
end;

function ProcessCheckAndChapterOrQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Used for the QCWA Golden Anniversay contest.  The Chapter might be 2 or 3
  integers, or AL for At Large with QTH.  The CHECK is two numbers (year).

  Valid formats:
      CHECK CHAPTER or CHECK QTH

  }

var
  FirstString, SecondString, ThirdString, FourthString: Str20;
  //    Result1: INTEGER;

begin
  ProcessCheckAndChapterOrQTHExchange := False;

  if length(Exchange) < 4 then
     begin
     Exit;
     end;

  ParseFourFields(Exchange, FirstString, SecondString, ThirdString,
    FourthString);

  if StringIsAllNumbers(FirstString) then
     begin
     RXData.Check := StrToIntDef(FirstString, 0);

     if SecondString <> '' then
        begin
        RXData.DomesticQTH := SecondString;
        RXData.QTHString := SecondString;
        ProcessCheckAndChapterOrQTHExchange := True;
        Exit;
        end;
     end;
end;

function ProcessQSONumberNameAndDomesticOrDXQTHExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ $Id: proc-nas.pas 1.2 94/09/09 01:48:52 jzap Exp $ }

{ The exchange must be at least 6 characters in length, with each entry
  separated by a space.

  > The new parse routine will put the first four exchange fields into
  > separate strings.  Each is checked to see if it looks like a callsign.
  > If it does, it is used to update the call and is removed; the other
  > strings move up.  What's left constitute the first, second, and third
  > entries described below.

  If the first entry is the QSO number, the second
  entry must be the name and the last entry the QTH string.  If the second
  entry is the QSO number, the first entry must be the name and the last
  entry the QTH.  If the last entry is to be the QSO number (this is
  normal if the program already knew the name and QTH as an initial
  exchange), then the first entry is the name, the second the QTH.  The
  QTH string is ignored if the call is outside the 49 states or Canada.
  If the name is different than that in the name database, it will be
  changed.  }

var
  TempString: Str20;
  NumberEntries, Result1: integer;
  DX: boolean;
  EntryList: EntryArray;

begin
  ProcessQSONumberNameAndDomesticOrDXQTHExchange := False;

  if length(Exchange) < 4 then
     begin
     ExchangeErrorMessage := TC_NOTENOUGHINFOINEXCHANGE;
     Exit;
     end;

  DX := not DomesticCountryCall(RXData.Callsign);

  ParseExchangeIntoFields(Exchange, EntryList, NumberEntries);

  { If we have multiple number entries at the end of the exchange,
    filter out the previous ones }

  while (NumberEntries > 3) and
    StringIsAllNumbers(EntryList[NumberEntries]) and
    StringIsAllNumbers(EntryList[NumberEntries - 1]) do
     begin
     EntryList[NumberEntries - 1] := EntryList[NumberEntries];
     dec(NumberEntries);
     end;

  if NumberEntries <= 3 then { Use old method }
     begin
     if StringIsAllNumbers(EntryList[1]) then
        begin
        Val(EntryList[1], RXData.NumberReceived, Result1);
        RXData.Name := EntryList[2];
        if NumberEntries >= 3 then
           begin
           RXData.QTHString := EntryList[3];
           end;
        end
     else if StringIsAllNumbers(EntryList[2]) then
        begin
        Val(EntryList[2], RXData.NumberReceived, Result1);
        RXData.Name := EntryList[1];
        if NumberEntries >= 3 then
           begin
           RXData.QTHString := EntryList[3];
           end;
        end
     else if StringIsAllNumbers(EntryList[3]) then
        begin
        Val(EntryList[3], RXData.NumberReceived, Result1);
        RXData.Name := EntryList[1];
        RXData.QTHString := EntryList[2];
        end
     else
        begin
        ExchangeErrorMessage := TC_NOQSONUMBERFOUND;
        Exit;
        end;
     end

  else
    { We have four or more entries, use new procedure }if (NumberEntries = 4)
      then
       begin
       if StringIsAllNumbers(EntryList[2]) then
          begin
          Val(EntryList[2], RXData.NumberReceived, Result1);
          RXData.Name := EntryList[3];
          RXData.QTHString := EntryList[4];
          end
       else if StringIsAllNumbers(EntryList[3]) then
          begin
          Val(EntryList[3], RXData.NumberReceived, Result1);
          RXData.Name := EntryList[4];
          RXData.QTHString := EntryList[2];
          end
       else if StringIsAllNumbers(EntryList[1]) and
         StringIsAllNumbers(EntryList[4]) then
          begin
          Val(EntryList[4], RXData.NumberReceived, Result1);
          RXData.Name := EntryList[2];
          RXData.QTHString := EntryList[3];

          end
       else

         { Last chance - five or more entries }if
         StringIsAllNumbers(EntryList[NumberEntries - 2]) then
            begin
            Val(EntryList[NumberEntries - 2], RXData.NumberReceived, Result1);
            RXData.Name := EntryList[NumberEntries - 1];
            RXData.QTHString := EntryList[NumberEntries];
            end
         else if (NumberEntries = 4) then // n4af 4.51.6 allow name correction
           if ((IsAlpha(EntryList[4])) and (StringIsAllNumbers(EntryList[1])))
             then
              begin
              Val(EntryList[1], RXData.NumberReceived, Result1);
              RXData.Name := EntryList[4];
              RXData.QTHString := EntryList[3];
              end;
       end;
  if (RXData.Name = '') or ((RXData.QTHString = '') and not DX) then
     begin
     ExchangeErrorMessage := TC_MISSINGQTHANDORNAME;
     Exit;
     end;

  if length(RXData.Name) < length(RXData.QTHString) then
     begin
     if RXData.Name <> CD.GetName(RXData.Callsign) then
       if (length(RXData.Name) = 2) or (length(RXData.Name) = 3) then
          begin
          TempString := RXData.Name;
          RXData.Name := RXData.QTHString;
          RXData.QTHString := TempString;
          end;
     end;

  { The DX QTH gets put in by the GetDXQTH routine in LogDupe when the mult
    check was performmed.  Otherwise, FoundDomesticQTH will put the domestic
    QTH in there for us.  }

  if not DomesticCountryCall(RXData.Callsign) then
     begin
     ProcessQSONumberNameAndDomesticOrDXQTHExchange := True
     end
  else if FoundDomesticQTH(RXData) then
     begin
     ProcessQSONumberNameAndDomesticOrDXQTHExchange := True
     end
  else
     begin
     TempString := RXData.Name;
     RXData.Name := RXData.QTHString;
     RXData.QTHString := TempString;

     if FoundDomesticQTH(RXData) then
        begin
        ProcessQSONumberNameAndDomesticOrDXQTHExchange := True
        end
     else
        begin
        ExchangeErrorMessage := TC_IMPROPERDOMESITCQTHORMISSINGNAME;
        end;

     end;
end;

procedure ProcessSSEntry(InputString: Str80);

begin
  (* LIFTED TO uExchangeTokens AT M5b (2026-10-02), line for line, so the
    Sweepstakes class reads a word the way this parser does when it decides
    whether a refused exchange was missing its precedence (NY4I, design 7.10).
    One copy of the rule; this unit's SSEx is the record it fills. *)
  ProcessSweepstakesEntry(InputString, SSEx);
end;

function ProcessQSONumberPrecedenceCheckDomesticQTHExchange(Exchange: ShortString
  {Str80};
  var RXData: ContestExchange): boolean;

{ A new improved version!  It tries to maintain compatability with the old
  version, but allows the following:

  If an entry has one, two, three or four digits and the letter A, B or Q
  at the end, then it is assumed to be a number and a precedence.  The last
  of any of these type of entries is used.

  If an entry has two numbers and then at least two letters after it, it is
  assumed to be a check and a section.  Again, the last of any of these type
  of entries is used.

  If an entry is at least four chars long and does not start or end with a
  number or if it has a / in it, then it is assumed to be a callsign.  The
  call will override the callsign window call if it is different.  Again,
  the last on of these is used.
}

var
  Entries: array[0..10] of Str20;
  NumberEntries: integer;
  Entry, Result1: integer;

begin
  ProcessQSONumberPrecedenceCheckDomesticQTHExchange := False;

  FillChar(SSEx, SizeOf(SSEx), 0);
  FillChar(Entries, SizeOf(Entries), 0);
  if length(Exchange) < 6 then
     begin
     Exit;
     end;

  NumberEntries := 0;

  while (Exchange <> '') and (NumberEntries <= 10) do
     begin
     Entries[NumberEntries] := RemoveFirstString(Exchange);
     inc(NumberEntries);
     end;

  for Entry := NumberEntries - 1 downto 0 do
     begin
     ProcessSSEntry(Entries[Entry]);

     if (SSEx.Number <> '') and
       (SSEx.Prec <> CHR(0)) and
       (SSEx.Check <> '') and
       (SSEx.Section <> '') then
        begin
        Val(SSEx.Number, RXData.NumberReceived, Result1);
        if Result1 <> 0 then
           begin
           Exit;
           end;

        RXData.Precedence := SSEx.Prec;
        RXData.Check := StrToIntDef(SSEx.Check, 0);

        if (length(SSEx.Check) <> 2) or not StringIsAllNumbers(SSEx.Check) then
           begin
           Exit;
           end;

        RXData.QTHString := SSEx.Section;

        if FoundDomesticQTH(RXData) then
           begin
           ProcessQSONumberPrecedenceCheckDomesticQTHExchange := True;
           Exit;
           end;
        end;
     end;
end;

function LooksLikeRST(Ex: Str80; var RST: smallInt {Word} {RSTString}; Mode:
  ModeType):
  boolean;

begin
  LooksLikeRST := False;
  if Mode = DIGITAL then
     begin
     LooksLikeRST := true;
     RST := StrToIntDef(Ex, -86);
     Exit;
     end;
  if Mode = CW then
     begin
     if length(Ex) <> 3 then
        begin
        Exit;
        end;

     if (Ex[1] >= '1') and (Ex[1] <= '5') and
       (Ex[2] >= '1') and (Ex[2] <= '9') and
       (((Ex[3] >= '1') and (Ex[3] <= '9')) or (UpCase(Ex[3]) = 'A')) then
        begin
        LooksLikeRST := True;
        RST := StrToIntDef(Ex, 0);
        end;
     Exit;
     end
  else
     begin
     case length(Ex) of

       2:
         if (Ex[1] >= '1') and (Ex[1] <= '5') and
           (Ex[2] >= '1') and (Ex[2] <= '9') then
            begin
            LooksLikeRST := True;
            RST := StrToIntDef(Ex, 0);
            end;

       3:
         if UpperCase(Copy(Ex, length(Ex), 1)) = 'A' then
           if (ActiveBand = Band6) or (ActiveBand = Band2) then
             if (Ex[1] >= '1') and (Ex[1] <= '5') and
               (Ex[2] >= '1') and (Ex[2] <= '9') then
                begin
                LooksLikeRST := True;
                RST := StrToIntDef(Ex, 0);
                end;
     end;
     end;

end;

function ValidAllJAPrefecture(Prefecture: Str20): boolean;

var
  PrefectureValue, Result1: integer;

begin
  if Copy(Prefecture, 1, 1) = 'p' then
     begin
     Delete(Prefecture, 1, 1);
     end;

  Val(Prefecture, PrefectureValue, Result1);

  if Result1 <> 0 then
     begin
     ValidAllJAPrefecture := False;
     Exit;
     end;

  ValidAllJAPrefecture := ((PrefectureValue > 1) and (PrefectureValue < 51)) or
    ((PrefectureValue > 100) and (PrefectureValue < 115));
end;

function ProcessRSTAllJAPrefectureAndPrecedenceExchange(Exchange: ShortString
  {Str80}; var RXData: ContestExchange): boolean;

{ Updated for new rules.  Exchange now RS(T) + Prefixture # + Power (A/B/C) }

var
  ExchangeString: ShortString; {STR20} {WLI}
  Entries: array[0..10] of ShortString {Str20}; {WLI}
  NumberEntries: integer;

begin
  Exchange := UpperCase(Exchange);
  //su(Exchange);

  RXData.RSTReceived := DefaultRST;

  ProcessRSTAllJAPrefectureAndPrecedenceExchange := False;

  { Get power out of the way }

  if StringHas(Exchange, 'H') then
     begin
     RXData.Precedence := 'H';
     Delete(Exchange, pos('H', Exchange), 1);
     end
  else if StringHas(Exchange, 'M') then
     begin
     RXData.Precedence := 'M';
     Delete(Exchange, pos('M', Exchange), 1);
     end
  else if StringHas(Exchange, 'L') then
     begin
     RXData.Precedence := 'L';
     Delete(Exchange, pos('L', Exchange), 1);
     end
  else if StringHas(Exchange, 'P') then
     begin
     RXData.Precedence := 'P';
     Delete(Exchange, pos('P', Exchange), 1);
     end;

  GetRidOfPostcedingSpaces(Exchange);

  NumberEntries := 0;

  ExchangeString := Exchange;

  while ExchangeString <> '' do
     begin
     Entries[NumberEntries] := RemoveFirstString(ExchangeString);
     GetRidOfPrecedingSpaces(Entries[NumberEntries]);
     inc(NumberEntries);
     end;

  if NumberEntries = 1 then { Everything as one entry }
     begin
     if ActiveMode = CW then
        begin
        case length(Entries[0]) of
          2, 3:
            if ValidAllJAPrefecture(Entries[0]) then
               begin
               RXData.QTHString := 'p' + Entries[0];
               end;

          4:
            if Copy(Entries[0], 2, 1) = '1' then { S + 3 dig Pref? }
              if ValidAllJAPrefecture(Copy(Entries[0], 2, 3)) then
                 begin
                 RXData.QTHString := 'p' + Copy(Entries[0], 2, 3);
                 //              RXData.RSTReceived[2] := Entries[0][1];
                 end;

          5:
            if ValidAllJAPrefecture(Copy(Entries[0], 4, 2)) then
               begin
               RXData.QTHString := 'p' + Copy(Entries[0], 4, 2);
               //            RXData.RSTReceived := Copy(Entries[0], 1, 3);
               end;

          6:
            if ValidAllJAPrefecture(Copy(Entries[0], 4, 3)) then
               begin
               RXData.QTHString := 'p' + Copy(Entries[0], 4, 3);
               //            RXData.RSTReceived := Copy(Entries[0], 1, 3);
               end;

        end;
        end
     else
        begin { SSB }
        case length(Entries[0]) of

          2:
            if ValidAllJAPrefecture(Entries[0]) then
               begin
               RXData.QTHString := 'p' + Entries[0];
               end;

          3:
            if ValidAllJAPrefecture(Entries[0]) then
               begin
               RXData.QTHString := 'p' + Entries[0]
               end
            else if ValidAllJAPrefecture(Copy(Entries[0], 2, 2)) then
               begin
               RXData.QTHString := Copy(Entries[0], 2, 2);
               //              RXData.RSTReceived[2] := Entries[0][1];
               end;

          4:
            if Copy(Entries[0], 2, 1) = '1' then
               begin
               if ValidAllJAPrefecture(Copy(Entries[0], 2, 3)) then
                  begin
                  RXData.QTHString := 'p' + Copy(Entries[0], 2, 3);
                  //              RXData.RSTReceived[2] := Entries[0][1];
                  end;
               end
            else if ValidAllJAPrefecture(Copy(Entries[0], 3, 2)) then
               begin
               RXData.QTHString := 'p' + Copy(Entries[0], 3, 2);
               //              RXData.RSTReceived := Copy(Entries[0], 1, 2);
               end;

          5:
            if ValidAllJAPrefecture(Copy(Entries[0], 3, 3)) then
               begin
               RXData.QTHString := 'p' + Copy(Entries[0], 3, 3);
               //            RXData.RSTReceived := Copy(Entries[0], 1, 2);
               end;

        end;

        end;
     end;

  { Two entries to look at }

  if NumberEntries = 2 then
     begin
     if ValidAllJAPrefecture(Entries[0]) then
       if not ValidAllJAPrefecture(Entries[1]) then
          begin
          {
                RXData.QTHString := Entries[0];

                case length(Entries[1]) of
                  1: RXData.RSTReceived[2] := Entries[1][1];

                  2:
                    if ActiveMode = Phone then
                      RXData.RSTReceived := Entries[1];

                  3:
                    if ActiveMode = CW then
                      RXData.RSTReceived := Entries[1];
                end;
        }
          end;

     if ValidAllJAPrefecture(Entries[1]) then
       if not ValidAllJAPrefecture(Entries[0]) then
          begin
          RXData.QTHString := Entries[1];
          {
                case length(Entries[0]) of
                  1: RXData.RSTReceived[2] := Entries[0][1];

                  2:
                    if ActiveMode = Phone then
                      RXData.RSTReceived := Entries[0];

                  3:
                    if ActiveMode = CW then
                      RXData.RSTReceived := Entries[0];

                end;
              }
          end;

     if ValidAllJAPrefecture(Entries[0]) then
       if ValidAllJAPrefecture(Entries[1]) then { Both valid }
          begin
          {
                case length(Entries[0]) of
                  1: RXData.RSTReceived[2] := Entries[0][1];
                  2:
                    if ActiveMode = Phone then RXData.RSTReceived := Entries[0];
                  3:
                    if ActiveMode = CW then RXData.RSTReceived := Entries[0];
                end;
        }
          RXData.QTHString := Entries[1];
          end;

     end;

  if not ValidAllJAPrefecture(RXData.QTHString) then
     begin
     Exit;
     end;
  if not FoundDomesticQTH(RXData) then
     begin
     Exit;
     end;

  ProcessRSTAllJAPrefectureAndPrecedenceExchange := RXData.Precedence <> '';
end;

function ProcessRSTAndAgeExchange(Exchange: Str80; var RXData: ContestExchange):
  boolean;

{ The exchange must be made of only digits and spaces.  If the exchange has
  a space, the RS(T) is assumed to be the first entry, and the age the
  second.  You can enter just the strength of the RS(T) or the full report.
  The age must be two digits.  You can omit the space if you like.  The
  last two digits will be used for the age and the digits before that for
  the RS(T) information.                        }

var
  ExchangeString: ShortString;
  Entries: array[0..10] of ShortString {Str20};
  NumberEntries: integer;
  TempInt: integer;
begin
  RXData.RSTReceived := DefaultRST;

  ProcessRSTAndAgeExchange := False;

  if not StringIsAllNumbersOrSpaces(Exchange) then
     begin
     Exit;
     end;

  NumberEntries := 0;

  ExchangeString := Exchange;

  while ExchangeString <> '' do
     begin
     Entries[NumberEntries] := RemoveFirstString(ExchangeString);
     GetRidOfPrecedingSpaces(Entries[NumberEntries]);
     inc(NumberEntries);
     end;

  if (NumberEntries = 1) and ((length(Entries[0]) = 1) or (length(Entries[0]) =
    // 4.99.3
    2)) then
     begin
     TempInt := StrToIntDef(Entries[0], 0);
     if TempInt > 255 then
        begin
        Exit;
        end;
     RXData.Age := Byte(TempInt);
     ProcessRSTAndAgeExchange := True;
     Exit;
     end;

  if NumberEntries = 2 then
     begin
     if LooksLikeRST(Entries[0], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.Age := StrToIntDef(Entries[1], 0)
        end
     else if LooksLikeRST(Entries[1], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.Age := StrToIntDef(Entries[0], 0)
        end
     else
        begin
        RXData.Age := StrToIntDef(Entries[1], 0);
        end;

     ProcessRSTAndAgeExchange := RXData.Age <> 0 {length(RXData.Age) = 2};
     Exit;
     end;

  if NumberEntries = 3 then
     begin
     if LooksLikeRST(Entries[1], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.Age := StrToIntDef(Entries[2], 0)
        end
     else if LooksLikeRST(Entries[2], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.Age := StrToIntDef(Entries[1], 0)
        end
     else
        begin
        RXData.Age := StrToIntDef(Entries[2], 0);
        end;

     ProcessRSTAndAgeExchange := RXData.Age <> 0 {length(RXData.Age) = 2};
     Exit;
     end;

  case length(Exchange) of
    2:
      begin
        RXData.Age := StrToIntDef(Exchange, 0);
        ProcessRSTAndAgeExchange := True;
      end;

    3:
      begin
        //        Delete(DefaultRST, 2, 1);
        //        Insert(Exchange[1], DefaultRST, 2);
        //        RXData.RSTReceived := DefaultRST;
        Delete(Exchange, 1, 1);
        RXData.Age := StrToIntDef(Exchange, 0);
        ProcessRSTAndAgeExchange := RXData.Age <> 0 {length(RXData.Age) = 2};
      end;

    4:
      begin
        if ActiveMode <> Phone then
           begin
           Exit;
           end;
        //        RXData.RSTReceived := Copy(Exchange, 1, 2);
        RXData.Age := StrToIntDef(Copy(Exchange, 3, 2), 0);
        ProcessRSTAndAgeExchange := True;
      end;

    5:
      begin
        if ActiveMode <> CW then
           begin
           Exit;
           end;
        //        RXData.RSTReceived := Copy(Exchange, 1, 3);
        RXData.Age := StrToIntDef(Copy(Exchange, 4, 2), 0);
        ProcessRSTAndAgeExchange := True;
      end;
  end; { of case Length (Exchange) }
end;

function ProcessRSTAndPrefectureExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

var
  ExchangeString: Str80;
  Entries: array[0..3] of Str80;
  NumberEntries: integer;

begin
  RXData.RSTReceived := DefaultRST;

  ProcessRSTAndPrefectureExchange := False;

  if not StringIsAllNumbersOrSpaces(Exchange) then
     begin
     Exit;
     end;

  if length(RXData.QTH.CountryID) < 2 then
     begin
     Exit;
     end;
  if not ((RXData.QTH.CountryID[1] = 'J') and (RXData.QTH.CountryID[2] in ['A',
    'D'])) then
     begin
     Exit;
     end;

  NumberEntries := 0;

  ExchangeString := Exchange;

  while ExchangeString <> '' do
     begin
     Entries[NumberEntries] := RemoveFirstString(ExchangeString);
     GetRidOfPrecedingSpaces(Entries[NumberEntries]);
     inc(NumberEntries);
     end;

  if (NumberEntries = 1) then
     begin
     RXData.QTHString := {'p' +}Entries[0];
     ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
     Exit;
     end;

  if NumberEntries = 2 then
     begin
     if LooksLikeRST(Entries[0], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.QTHString := Entries[1]
        end
     else if LooksLikeRST(Entries[1], RXData.RSTReceived, ActiveMode) then
        begin
        RXData.QTHString := Entries[0]
        end
     else
        begin
        RXData.QTHString := Entries[1];
        end;

     ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
     Exit;
     end;

  {
    if NumberEntries = 3 then
    begin
      if LooksLikeRST(Entries[1], RXData.RSTReceived, ActiveMode) then
        RXData.QTHString := 'p' + Entries[2]
      else
        if LooksLikeRST(Entries[2], RXData.RSTReceived, ActiveMode) then
          RXData.QTHString := 'p' + Entries[1]
        else
          RXData.QTHString := 'p' + Entries[2];

      ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
      Exit;
    end;
  }
  case length(Exchange) of
    2:
      begin
        //        RXData.QTHString := 'p' + Exchange;
        //        ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
      end;

    3:
      begin
        {
                Delete(DefaultRST, 2, 1);
                Insert(Exchange[1], DefaultRST, 2);
                RXData.RSTReceived := DefaultRST;
                Delete(Exchange, 1, 1);
                RXData.QTHString := 'p' + Exchange;
                ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
        }
      end;

    4:
      begin
        {
                if ActiveMode <> Phone then Exit;
                RXData.RSTReceived := Copy(Exchange, 1, 2);
                RXData.QTHString := 'p' + Copy(Exchange, 3, 2);
                ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
        }
      end;

    5:
      begin
        {
                if ActiveMode <> CW then Exit;
                RXData.RSTReceived := Copy(Exchange, 1, 3);
                RXData.QTHString := 'p' + Copy(Exchange, 4, 2);
                ProcessRSTAndPrefectureExchange := FoundDomesticQTH(RXData);
        }
      end;
  end; { of case Length (Exchange) }
end;


function ProcessAgeAndQSONumberExchange(Exchange: ShortString; var RXData:
  ContestExchange): boolean;
var
  firststring, secondstring, thirdstring: str10;

begin
  ParseExchange(exchange, FirstString, SecondString, ThirdString); //n4af 04.42.4
  Result := False;
  if (SecondString = '') and (ThirdString = '') then
     begin
     exit; // n4af 4.45.7
     end;
  if length(Exchange) < 3 then
     begin
     Exit;
     end;
  if not StringIsAllNumbers(FirstString) then
     begin
     Exit;
     end;
  RXData.Age := StrToIntDef(FirstString, 0);
  if ThirdString <> '' then
     begin
     RXData.DomesticQTH := SecondString;
     RXData.NumberReceived := StrToIntDef(ThirdString, 0)
     end
  else
     begin
     RXData.NumberReceived := StrToIntDef(SecondString, 0);
     RXData.DomesticQTH := '';
     end;
  { if (ActiveMode = CW) or (ActiveMode = Digital) then  // 4.1193
   begin
     RXData.RSTReceived := 599;
     RXData.RSTSent := 599;
   end
   else
   begin
     RXData.RSTReceived := 59;
     RXData.RSTSent := 59;
   end;  }
  Result := True;
end;

function ProcessQSONumberAndAgeExchange(Exchange: ShortString; var RXData:
  ContestExchange): boolean;
var
  firststring, secondstring, thirdstring: str10;

begin
  ParseExchange(exchange, FirstString, SecondString, ThirdString);
  Result := False;
  if (SecondString = '') then
     begin
     exit; //
     end;
  if length(Exchange) < 3 then
     begin
     Exit;
     end;
  if (not StringIsAllNumbers(FirstString)) or (not
    StringIsAllNumbers(SecondString)) then
     begin
     Exit;
     end;
  RXData.NumberReceived := StrToIntDef(FirstString, 0);
  RXData.Age := StrToIntDef(SecondString, 0);
  if (ActiveMode = CW) or (ActiveMode = Digital) then
     begin
     RXData.RSTReceived := 599;
     RXData.RSTSent := 599;
     end
  else
     begin
     RXData.RSTReceived := 59;
     RXData.RSTSent := 59;
     end;
  Result := True;
end;

function ProcessRSTAndDomesticQTHExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

{ Any digits found at the start of the exchange will be used to determine
  the RS(T).  If the first character is not a digit, the default RS(T)
  will be used and the whole exchange will be used as the QTH.

  Multi-county handling (Issue #885): the operator can give more than one
  county in a single exchange when working a station bridging county lines:
    "DAL/BAY"      -- slash-separated
    "DAL BAY"      -- space-separated
    "599 DAL/BAY"  -- with RST
    "DAL/BAY CIT"  -- mixed forms / three counties
  All '/'-characters are mapped to spaces before tokenizing so both formats
  travel the same code path.  Every valid domestic QTH found in user-typed
  order is collected; the first becomes RXData.QTHString for THIS QSO and
  the rest are pushed onto uPendingCounties so TryLogContact can drain the
  queue and write a separate QSO for each. }

var
  TempString    : Str80;
  i             : Integer;
  NumericTokens : TStringList;
  ValidQTHs     : TStringList;
  UnknownTokens : TStringList;

begin
  ProcessRSTAndDomesticQTHExchange := False;
  ClearPendingCounties;

  GetRidOfPrecedingSpaces(Exchange);
  GetRidOfPostcedingSpaces(Exchange);

  // Treat slash-separated counties as space-separated (e.g. "DAL/BAY" =>
  // "DAL BAY") so a single tokenizer handles both formats.
  for i := 1 to Length(Exchange) do
    if Exchange[i] = '/' then
       begin
       Exchange[i] := ' ';
       end;

  // Single-token, non-numeric branch: still a single QTH after slash mapping
  // (e.g. plain "DAL").  Behavior unchanged from prior code.
  (* THE TEST IS uExchangeTokens's SINCE M5b, so the IARU class -- whose rule
    applies exactly when this branch is taken -- asks the same question. On
    the already trimmed and slash-mapped text here it is the test that stood
    here, character for character. *)
  if IsSingleNonNumericToken(string(Exchange)) then
     begin
     RXData.RSTReceived := DefaultRST;
     RXData.QTHString := Exchange;
     if length(Exchange) < 9 then // n4af 4.43.12
        begin
        ProcessRSTAndDomesticQTHExchange := FoundDomesticQTH(RXData)
        end
     else
        begin
        Result := False;
        end;
     if Result = False then
        begin
        (* NAME THE SETTING THAT PUT THE CONTEST IN THIS MODE -- 2026-09-20.

          "Improper domestic QTH" is a complete description of what was
          refused and says nothing about WHY the contest wanted one. In ARRL
          DX the answer is MY COUNTRY, which the operator never typed --
          FCONTEST derives it from the callsign -- so there is nothing on
          screen connecting the refusal to a setting. NY4I typed K for a
          kilowatt into a correctly-configured ARRL DX SSB contest and got
          this line (2026-09-20).

          The attribution is empty for the exchanges no setting chose, and
          then the message is exactly what it was. *)
        logger.Error('[ProcessRSTAndDomesticQTHExchange] Improper domestic ' +
                     'QTH - Exchange = (%s). %s',
                     [Exchange,
                      ExchangeModeAttribution(ContestSession.Exchange,
                                              Settings.My.Country, False)]);
        (* THE BRIEF FORM ON SCREEN. QuickDisplayError writes into a
          main-window element, not a dialog, so what goes there has to be a
          few words -- '(MY COUNTRY is empty)' rather than the sentence the
          log gets. *)
        ExchangeErrorMessage := TC_IMPROPERDOMESITCQTH +
           ExchangeModeAttribution(ContestSession.Exchange, Settings.My.Country, True);
        end;
     (* IARU's ZONE FROM THE CALL, for a member society's single-word exchange,
       stood here as `if Contest = IARU` (NY4I 2026JUL07). It is the IARU
       class's rule since M5b: TContestIARU.ParseReceivedExchange, under the
       same shape and the same single-word test. *)
     Exit;
     end;

  { Multi-token branch.  The tokenizing, the domestic-mults probe and the
    "first county belongs to this QSO, the rest are queued" rule are shared
    with ProcessQSONumberAndDomesticQTHExchange -- see the helpers above.
    Here a numeric token is the RS(T). }

  NumericTokens := TStringList.Create;
  ValidQTHs := TStringList.Create;
  UnknownTokens := TStringList.Create;

  try
     SplitExchangeIntoNumbersAndDomesticQTHs(Exchange, NumericTokens, ValidQTHs,
                                             UnknownTokens);

     { The RIGHTMOST numeric token is the RS(T).  That is what the previous
       right-to-left walk selected: it took the first number it met, and its
       "RSTReceived = 0" guard stopped any further number overwriting it.
       The guard is kept here for the same reason -- an RS(T) already on the
       record is left alone. }

     if (NumericTokens.Count > 0)  and
        (RXData.RSTReceived = 0)   then
        begin
        TempString := NumericTokens[NumericTokens.Count - 1];

        if Length(TempString) = 1 then
           begin
           case ActiveMode of
             CW    : RXData.RSTReceived := 509 + (Ord(TempString[1]) - 48) * 10;
             Phone : RXData.RSTReceived := 50  + (Ord(TempString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TempString, 0);
           end;
        end;

     if RXData.RSTReceived = 0 then
        begin
        RXData.RSTReceived := DefaultRST;
        end;

     Result := ApplyFirstQTHAndQueueRest(ValidQTHs, RXData);

     if not Result then
        begin
        logger.Error('[ProcessRSTAndDomesticQTHExchange] Improper Domestic QTH - Exchange = (%s)', [Exchange]);
        end
     else
        begin
        ReportIgnoredQTHTokens('ProcessRSTAndDomesticQTHExchange', UnknownTokens);
        end;
  finally
     NumericTokens.Free;
     ValidQTHs.Free;
     UnknownTokens.Free;
     end;
end;

function ProcessRSTAndJAPrefectureExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

{ A single entry is assumed to be the exchange and not RST. Two entries assume }
{ the RS(T) is the first provided it is 3 characters or less                   }

var
  TempString: Str80;
  QTHFound: boolean;

begin
  QTHFound := False;

  ProcessRSTAndJAPrefectureExchange := False;
  GetRidOfPrecedingSpaces(Exchange);
  GetRidOfPostcedingSpaces(Exchange);

  if not StringHas(Exchange, ' ') then
     begin
     RXData.RSTReceived := DefaultRST;
     RXData.QTHString := Exchange;
     ProcessRSTAndJAPrefectureExchange := FoundDomesticQTH(RXData);
     Exit;
     end;

  while Exchange <> '' do
     begin
     TempString := RemoveLastString(Exchange);

     if StringIsAllNumbers(TempString) and (RXData.RSTReceived = 0) and
       (length(TempString) < 4) then
        begin
        if length(TempString) = 1 then
           begin
           case ActiveMode of
             CW: RXData.RSTReceived := 509 + (Ord(TempString[1]) - 48) * 10;
             Phone: RXData.RSTReceived := 5 + (Ord(TempString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TempString, 0)
           end

        end
     else if not QTHFound then
        begin
        RXData.QTHString := TempString;
        if FoundDomesticQTH(RXData) then
           begin
           QTHFound := True;
           end;
        end;
     end;

  if QTHFound then
     begin
     if RXData.RSTReceived = 0 then
        begin
        RXData.RSTReceived := DefaultRST;
        end;
     ProcessRSTAndJAPrefectureExchange := True;
     Exit;
     end;

end;

function ProcessRSTAndQTHExchange(Exchange: ShortString {Str80}; var RXData:
  ContestExchange): boolean;

var
  RSTString: Str20;

begin
  GetRidOfPrecedingSpaces(Exchange);
  GetRidOfPostcedingSpaces(Exchange);

  if Exchange = '' then
     begin
     ProcessRSTAndQTHExchange := False;
     Exit;
     end;

  ProcessRSTAndQTHExchange := True;

  RSTString := PrecedingString(Exchange, ' ');

  if StringIsAllNumbersOrSpaces(RSTString) then
     begin
     RXData.RSTReceived := StrToIntDef(RSTString, 0);
     RXData.QTHString := PostcedingString(Exchange, ' ');
     end
  else
     begin
     RSTString := Exchange;

     while StringHas(RSTString, ' ') do
        begin
        RSTString := PostcedingString(RSTString, ' ');
        end;

     if StringIsAllNumbersOrSpaces(RSTString) then
        begin
        RXData.RSTReceived := StrToIntDef(RSTString, 0);
        RXData.QTHString := Copy(Exchange, 1, length(Exchange) - length(RSTString)
          - 1);
        end
     else
        begin
        RXData.RSTReceived := DefaultRST;
        RXData.QTHString := Exchange;
        end;
     end;
end;

function ProcessRSTAndDomesticOrDXQTHExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;
var
  // State-QP rover detection (KG1S/MON): the country lookup in
  // ParametersOkay treats /M as a Great Britain prefix indicator and
  // sets RXData.QTH.Country to G, which causes DomesticCountryCall
  // below to return False and routes the exchange to the DX parser
  // (which discards the county).  Detect the rover form here and
  // force the domestic-parser route so MON gets logged as the county.
  RoverSlashPos : Integer;
  RoverProbeRX  : ContestExchange;
begin
  ProcessRSTAndDomesticOrDXQTHExchange := False;

  // Rover-form override: if the call has a /COUNTY suffix and COUNTY
  // validates as a domestic QTH, treat as domestic regardless of
  // DomesticCountryCall's verdict on the slashed form.
  RoverSlashPos := Pos('/', string(RXData.Callsign));
  if RoverSlashPos > 0 then
     begin
     FillChar(RoverProbeRX, SizeOf(RoverProbeRX), 0);
     RoverProbeRX.QTHString := UpperCase(
        Copy(string(RXData.Callsign), RoverSlashPos + 1,
             Length(string(RXData.Callsign)) - RoverSlashPos));
     if FoundDomesticQTH(RoverProbeRX) then
        begin
        ProcessRSTAndDomesticOrDXQTHExchange :=
          ProcessRSTAndDomesticQTHExchange(Exchange, RXData);
        Exit;
        end;
     end;

  if DomesticCountryCall(RXData.Callsign) then
     begin
     ProcessRSTAndDomesticOrDXQTHExchange :=
       ProcessRSTAndDomesticQTHExchange(Exchange, RXData);
     Exit;
     end;

  //  if not ValidRST(Exchange, RXData.RSTReceived, ActiveMode) then Exit;
  //  ProcessRSTAndDomesticOrDXQTHExchange := True;

  ProcessRSTAndDomesticOrDXQTHExchange := ProcessRSTAndQTHExchange(Exchange,
    RXData);
end;

function ProcessRSTNameAndQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
                                         (RS(T) = default, no QTH or name)
   Name                                  (RS(T) = default, no QTH)
   Name        QTH                       (RS(T) = default)
   Name        QTH         RS(T)         (Enter whole RS(T))
   Name        RS(T)                     (No QTH)
   Name        RS(T)       QTH           (Enter whole RS(T))
   RS(T)                                 (Enter whole RS(T), no QTH or name)
   RS(T)       Name                      (Enter whole RS(T), no QTH)
   RS(T)       QTH         Name          (Enter whole RS(T))             }

var
  FirstString, SecondString, ThirdString: Str10 {Str20};

begin
  ProcessRSTNameAndQTHExchange := True;

  if Exchange = '' then
     begin
     if RXData.RSTReceived = 0 then
        begin
        RXData.RSTReceived := DefaultRST;
        end;
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if StringIsAllNumbers(FirstString) then
     begin
     RXData.RSTReceived := StrToIntDef(FirstString, 0);
     if ThirdString <> '' then
        begin
        RXData.QTHString := ThirdString;
        RXData.Name := SecondString;
        end
     else
        begin
        RXData.Name := SecondString;
        end;
     Exit;
     end;

  if StringIsAllNumbers(SecondString) then
     begin
     RXData.Name := FirstString;
     RXData.RSTReceived := DefaultRST;
     RXData.QTHString := SecondString;
     Exit;
     end;

  if StringIsAllNumbers(ThirdString) then
     begin
     RXData.Name := FirstString;
     RXData.QTHString := SecondString;
     RXData.RSTReceived := StrToIntDef(ThirdString, 0);
     Exit;
     end;

  if ThirdString <> '' then
     begin
     {
        ProcessRSTNameAndQTHExchange := False;
        Exit;
    }
     SecondString := SecondString + ' ' + ThirdString;
     end;

  RXData.Name := FirstString;
  RXData.QTHString := SecondString;
  RXData.RSTReceived := DefaultRST;
end;

procedure LookForCutNumbers(var Exchange: ShortString {Str80});

var
  TempString, NewExchange: ShortString {Str80};
  Address: integer;

begin
  NewExchange := '';

  while Exchange <> '' do
     begin
     TempString := RemoveFirstString(Exchange);

     if not StringIsAllNumbers(TempString) then
        begin
        for Address := 1 to length(TempString) do
           begin
           case TempString[Address] of

             'T', 'O': TempString[Address] := '0';
             'A': TempString[Address] := '1';
             'U': TempString[Address] := '2';
             'E': TempString[Address] := '5';
             'N': TempString[Address] := '9';
           end;
           end;
        end;

     NewExchange := NewExchange + TempString + ' '
     end;

  GetRidOfPostcedingSpaces(NewExchange);
  Exchange := NewExchange;
end;

function ProcessRSTAndQSONumberExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2
   ---------   ---------
   RS(T)       QSO Number
   QSO Number                (RS(T) = default)

  You can enter just the strength of the RS(T) if you like.

  Cut QSO numbers are changed to numeric. }

var
  code: integer;

begin
  ProcessRSTAndQSONumberExchange := False;
  (* SAC'S RUSSIAN-STATION RULE (4.123.10) stood here as
    `if (contest = SACCW) or (contest = SACSSB)`. It is the SAC classes' rule
    since M5b -- TContestSACCW / TContestSACSSB.ParseReceivedExchange, under
    this shape, with live entry abandoned through the session exactly as
    initializeqso did here. *)
  LookForCutNumbers(Exchange);

  if StringIsAllNumbers(Exchange) then
     begin
     Val(Exchange, RXData.NumberReceived, code);
     if code <> 0 then
        begin
        Exit;
        end;
     RXData.RSTReceived := DefaultRST;
     ProcessRSTAndQSONumberExchange := True;
     end
  else if ValidRST(Exchange, RXData.RSTReceived, ActiveMode) then
     begin
     Exchange := RemoveFirstString(Exchange);
     Val(Exchange, RXData.NumberReceived, code);
     if code <> 0 then
        begin
        exit;
        end;
     ProcessRSTAndQSONumberExchange := True;
     end
  else
     begin
     ExchangeErrorMessage := TC_NOQSONUMBERFOUND;
     end;

end;

function LooksLikePower(TestString: Str20): boolean;

{ Returns true if entry is all numbers, or all numbers with a W at the end }

var
  CharPos: integer;

begin
  LooksLikePower := False;

  if TestString = '' then
     begin
     Exit;
     end;

  TestString := UpperCase(TestString);

  for CharPos := 1 to length(TestString) do
     begin
     if not (TestString[CharPos] in ['0'..'9', 'W', 'M', 'R']) then
        begin
        Exit;
        end;
     {
    if ((TestString[CharPos] < '0') or (TestString[CharPos] > '9')) and
      (TestString[CharPos] <> 'W') and (TestString[CharPos] <> 'M') and
      (TestString[CharPos] <> 'R') then Exit;
    }
     end;

  LooksLikePower := True;
end;

function ProcessRSTPossibleDomesticQTHAndPowerExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ RST MaybeQTH and Power.  Power will either have numbers and a W in it, or
  four numbers (for ARCI member number) }

var
  FirstString, SecondString, ThirdString: {STRING}Str10;
  ThirdStringRST, SecondStringRST, FirstStringRST: ShortString;

begin
  ProcessRSTPossibleDomesticQTHAndPowerExchange := False;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if StringIsAllNumbers(ThirdString) and (length(ThirdString) <= 3) then
     begin
     ThirdStringRST := ThirdString;
     if not ValidRST(ThirdStringRST, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     end
  else if StringIsAllNumbers(SecondString) and (length(SecondString) <= 3) then
     begin
     SecondStringRST := SecondString;
     if not ValidRST(SecondStringRST, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     end
  else if StringIsAllNumbers(FirstString) and (length(FirstString) <= 3) then
     begin
     FirstStringRST := FirstString;
     if not ValidRST(FirstStringRST, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     end
  else if ActiveMode = CW then
     begin
     RXData.RSTReceived := 599
     end
  else
     begin
     RXData.RSTReceived := 59;
     end;

  if LooksLikePower(ThirdString) then
     begin
     RXData.Power := ThirdString
     end
  else if LooksLikePower(SecondString) then
     begin
     RXData.Power := SecondString
     end
  else if LooksLikePower(FirstString) then
     begin
     RXData.Power := FirstString;
     end;

  if (ThirdString <> '') and (not LooksLikePower(ThirdString)) then
     begin
     RXData.QTHString := ThirdString
     end
  else if (SecondString <> '') and (not LooksLikePower(SecondString)) then
     begin
     RXData.QTHString := SecondString
     end
  else if (FirstString <> '') and (not LooksLikePower(FirstString)) then
     begin
     RXData.QTHString := FirstString;
     end;

  if RXData.Power = '' then
     begin
     Exit;
     end;

  { RXData.DXQTH is only there if it is a DX call }

  if RXData.DXQTH = '' then
     begin
     ProcessRSTPossibleDomesticQTHAndPowerExchange := FoundDomesticQTH(RXData)
     end
  else
     begin
     ProcessRSTPossibleDomesticQTHAndPowerExchange := True;
     end;
end;

function ProcessQSONumberAndPreviousQSONumber(Exchange: Str80; var RXData:
  ContestExchange): boolean;
var
  l: integer;

begin
  Result := False;
  l := length(Exchange);
  if not (l in [4..6]) then
     begin
     ExchangeErrorMessage := TC_NOTENOUGHINFOINEXCHANGE;
     Exit;
     end;
  if not StringIsAllNumbers(Exchange) then
     begin
     Exit;
     end;
  temprxdata.NumberReceived := StrToIntDef(Exchange, 0);
  rxdata.NumberReceived := StrToIntDef(Exchange, 0);
  PrevNr := Copy(Exchange, 1, 3); // 4.53.2

  Result := True;
end;

function ProcessRSTQSONumberAndDomesticQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   QTH                                    (RS(T) = default, QSO number = 1)
   QTH         QSO Number                 (RS(T) = default)
   QTH         RS(T)       QSO Number
   QSO Number  QTH                        (RS(T) = default)
   RS(T)       QTH         QSO Number
   RS(T)       QSO Number  QTH

  You can enter just the strength of the RS(T) if desired.      }

var
  NumberString, FirstString, SecondString, ThirdString: Str10;

begin
  ProcessRSTQSONumberAndDomesticQTHExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if not StringIsAllNumbers(FirstString) then
     begin
     RXData.QTHString := FirstString;
     if ThirdString <> '' then
        begin
        NumberString := SecondString + ' ' + ThirdString
        end
     else
        begin
        NumberString := SecondString;
        end;
     end
  else if not StringIsAllNumbers(SecondString) then
     begin
     RXData.QTHString := SecondString;
     if ThirdString <> '' then
        begin
        NumberString := FirstString + ' ' + ThirdString
        end
     else
        begin
        NumberString := FirstString;
        end;
     end
  else
     begin
     RXData.QTHString := ThirdString;
     NumberString := FirstString + ' ' + SecondString;
     end;

  if ProcessRSTAndQSONumberExchange(NumberString, RXData) then
    if RXData.QTHString <> '' then
       begin
       ProcessRSTQSONumberAndDomesticQTHExchange := FoundDomesticQTH(RXData);
       end;
end;

function ProcessRSTQSONumberAndGridSquareExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   Grid                                    (RS(T) = default, QSO number = 1)
   Grid        QSO Number                  (RS(T) = default)
   Grid        RS(T)       QSO Number
   QSO Number  Grid                        (RS(T) = default)
   RS(T)       Grid        QSO Number
   RS(T)       QSO Number  Grid

  You can enter just the strength of the RS(T) if desired.      }

var
  NumberString, FirstString, SecondString, ThirdString: Str10;

begin
  ProcessRSTQSONumberAndGridSquareExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if not StringIsAllNumbers(FirstString) then
     begin
     RXData.QTHString := FirstString;

     if ThirdString <> '' then
        begin
        NumberString := SecondString + ' ' + ThirdString
        end
     else
        begin
        NumberString := SecondString;
        end;
     end
  else if not StringIsAllNumbers(SecondString) then
     begin
     RXData.QTHString := SecondString;
     if ThirdString <> '' then
        begin
        NumberString := FirstString + ' ' + ThirdString
        end
     else
        begin
        NumberString := FirstString;
        end;
     end
  else
     begin
     RXData.QTHString := ThirdString;
     NumberString := FirstString + ' ' + SecondString;
     end;

  if ProcessRSTAndQSONumberExchange(NumberString, RXData) then
    if GoodLookingGrid(RXData.QTHString) then
       begin
       ProcessRSTQSONumberAndGridSquareExchange := FoundDomesticQTH(RXData);
       end;
end;
// n4af 4.51.2

function ProcessRSTQSONumberOrDomesticQTHExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;
var
  NumberString, FirstString, SecondString, ThirdString: Str10;
  //n: integer;
begin
  ProcessRSTQSONumberOrDomesticQTHExchange := False;

  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);
  { n := pos('/',SecondString) ;
   if n > 0 then

     RXData.QTHString := Rightstr(SecondString,n+1)
     else
      rxdata.QTHString := SecondString;

  }
  if not StringIsAllNumbers(FirstString) then // n4af 4.40.5
    if SecondString = '' then
       begin
       ProcessRSTAndDomesticQTHExchange(Exchange, RXData); // n4af 4.40.5
       Result := True;
       exit;
       end;
  if not StringIsAllNumbers(FirstString) then // n4af 4.42.7
     begin
     RXData.QTHString := FirstString;
     RXData.NumberReceived := StrToIntDef(SecondString, 0);
     ProcessRSTQSONumberOrDomesticQTHExchange := FoundDomesticQTH(RXData);
     Result := True;
     exit;
     end;
  if ThirdString <> '' then
     begin
     NumberString := SecondString + ' ' + ThirdString;
     end;
  //  else                                           // N4AF 4.42.9
  //    NumberString := SecondString;

  if (not StringIsAllNumbers(SecondString)) and (SecondString <> '') then
     begin
     RXData.QTHString := SecondString;
     if ThirdString <> '' then
        begin
        NumberString := FirstString + ' ' + ThirdString
        end
     else
        begin
        NumberString := FirstString;
        end;
     end
  else
     begin
     RXData.QTHString := ThirdString;
     NumberString := FirstString + ' ' + SecondString;
     end;

  if ProcessRSTAndQSONumberExchange(NumberString, RXData) then
     begin
     if RXData.QTHString = '' then
        begin
        ProcessRSTQSONumberOrDomesticQTHExchange := True
        end
     else
        begin
        ProcessRSTQSONumberOrDomesticQTHExchange := FoundDomesticQTH(RXData)
        end
     end
  else
     begin
     ExchangeErrorMessage := TC_NOQSONUMBERFOUND;
     end;
end;

function ProcessRSTQSONumberAndPossibleDomesticQTHExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   QSO Number                             (RS(T) = default, No QTH)
   QTH                                    (RS(T) = default, QSO number = 1)
   QTH         QSO Number                 (RS(T) = default)
   QTH         RS(T)       QSO Number
   QSO Number  QTH                        (RS(T) = default)
   RS(T)       QTH         QSO Number
   RS(T)       QSO Number                 (No QTH)
   RS(T)       QSO Number  QTH

  You can enter just the strength of the RS(T) if desired.      }

var
  NumberString, FirstString, SecondString, ThirdString: Str10;
begin

  ProcessRSTQSONumberAndPossibleDomesticQTHExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);
  (* UK/EI's RULE -- a UK or Irish station must send more than one word --
    stood here as `if Contest = UKEI`. It is TContestUKEI's since M5b, made
    before this shape is parsed, as it was here. *)
  if not stringisallnumbers(FirstString) then //   n4af 4.42.9
    if not stringisallnumbers(SecondString) then
      if not stringisallnumbers(ThirdString) then
         begin
         ExchangeErrorMessage := TC_NOQSONUMBERFOUND;
         exit;
         end;

  if not StringIsAllNumbers(FirstString) then // n4af 4.40.5
    if SecondString = '' then
       begin
       ProcessRSTAndDomesticQTHExchange(Exchange, RXData); // n4af 4.40.5
       Result := True;
       exit;
       end;
  if not StringIsAllNumbers(FirstString) and StringIsAllNumbers(SecondString)
    then // n4af 4.42.7
     begin
     RXData.QTHString := FirstString;
     RXData.NumberReceived := StrToIntDef(SecondString, 0);
     ProcessRSTQSONumberAndPossibleDomesticQTHExchange :=
       FoundDomesticQTH(RXData);
     Result := True;
     exit;
     end;
  if ThirdString <> '' then
     begin
     NumberString := SecondString + ' ' + ThirdString;
     end;
  //  else                                           // N4AF 4.42.9
  //    NumberString := SecondString;

  if not StringIsAllNumbers(SecondString) then
     begin
     RXData.QTHString := SecondString;
     if ThirdString <> '' then
        begin
        NumberString := FirstString + ' ' + ThirdString
        end
     else
        begin
        NumberString := FirstString;
        end;
     end
  else
     begin
     RXData.QTHString := ThirdString;
     NumberString := FirstString + ' ' + SecondString;
     end;

  if ProcessRSTAndQSONumberExchange(NumberString, RXData) then
     begin
     if RXData.QTHString = '' then
        begin
        ProcessRSTQSONumberAndPossibleDomesticQTHExchange := True
        end
     else
        begin
        ProcessRSTQSONumberAndPossibleDomesticQTHExchange :=
          FoundDomesticQTH(RXData)
        end
     end;

end;
{KK1L: 6.73 For Michigan QSO Party NOT WORKING!!!!!!}

function ProcessQSONumberAndPossibleDomesticQTHExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   QSO Number                             (No QTH)
   QTH                                    (QSO number = 1)
   QTH         QSO Number
   QSO Number  QTH                                            }

var
  NumberString, FirstString, SecondString, ThirdString: Str10;

begin
  ProcessQSONumberAndPossibleDomesticQTHExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if not StringIsAllNumbers(FirstString) then
     begin
     RXData.QTHString := FirstString;
     NumberString := SecondString;
     end
  else if (not StringIsAllNumbers(FirstString)) then
    if SecondString = '' then
       begin
       RXData.QTHString := FirstString;
       NumberString := '';
       Result := False;
       end;
  if not StringIsAllNumbers(SecondString) then // 4,93.2
     begin
     RXData.QTHString := SecondString;
     NumberString := FirstString;
     end;

  if StringIsAllNumbers(NumberString) then
    if RXData.QTHString = '' then
       begin
       ProcessQSONumberAndPossibleDomesticQTHExchange := True
       end
    else
       begin
       ProcessQSONumberAndPossibleDomesticQTHExchange :=
         FoundDomesticQTH(RXData);
       end;

  if Result = True then
     begin
     RXData.NumberReceived := StrToIntDef(NumberString, 0);
     end;
end;

function ProcessNZFieldDayExchange(Exchange: ShortString {Str80}; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The RST is
  optional.  The following formats will work:

  If in New Zealand:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   RST         QSO Number  Zone
   QSO Number  Zone

  You can enter just the strength of the RS(T) if desired.

  If not in New Zealand:

   Entry  #1   Entry  #2
   ---------   ---------
   RST         QSO Number
   QSO Number

    }

var
  FirstString, SecondString, ThirdString: Str10;

begin
  ProcessNZFieldDayExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  if RXData.QTH.CountryID = 'ZL' then
     begin
     ParseExchange(Exchange, FirstString, SecondString, ThirdString);

     if ThirdString <> '' then
        begin
        if length(ThirdString) > 2 then
           begin
           Exit;
           end;
        RXData.Zone := StrToIntDef(ThirdString, 0);
        end
     else
        begin
        if (SecondString = '') or (length(SecondString) > 2) then
           begin
           Exit;
           end;
        RXData.Zone := StrToIntDef(SecondString, 0);
        //      if length(RXData.Zone) = 1 then RXData.Zone := '0' + RXData.Zone;
        end;

     //    if length(RXData.Zone) = 1 then RXData.Zone := '0' + RXData.Zone;
     RemoveLastString(Exchange);

     //    if not StringIsAllNumbers(RXData.Zone) then Exit;
     end;

  if ProcessRSTAndQSONumberExchange(Exchange, RXData) then
     begin
     ProcessNZFieldDayExchange := True;
     end;

end;

function ProcessRSTQTHNameAndFistsNumberOrPowerExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ 599 QTH NAME FISTS# or 599 QTH NAME POWER.  Assumed to be FISTS # unless
  the number has a W at the end of it.  RST is optional.  QTH is required
  even for DX.  Name can only be one word.  Spaces required for each entry. }

var
  NumberEntries, Address, Result1: integer;
  DX: boolean;
  EntryList: EntryArray;

begin
  ProcessRSTQTHNameAndFistsNumberOrPowerExchange := False;

  if length(Exchange) < 4 then
     begin
     ExchangeErrorMessage := TC_NOTENOUGHINFOINEXCHANGE;
     Exit;
     end;

  DX := not DomesticCountryCall(RXData.Callsign);

  ParseExchangeIntoFields(Exchange, EntryList, NumberEntries);

  if StringIsAllNumbers(EntryList[1]) then
     begin
     RXData.RSTReceived := StrToIntDef(EntryList[1], 0);

     { Remove the RST from the entry list }

     if NumberEntries > 1 then
        begin
        for Address := 1 to NumberEntries - 1 do
           begin
           EntryList[Address] := EntryList[Address + 1];
           end;
        end;
     dec(NumberEntries);
     end
  else
     begin
     RXData.RSTReceived := 599; { Use default RST }
     end;

  { We have removed the RST if it was there.  Should have QTH, Name
    and power or member # }

  if NumberEntries < 2 then
     begin
     Exit; { Not enough data }
     end;

  if (NumberEntries = 2) and DX then
     begin
     RXData.QTHString := RXData.QTH.CountryID;
     RXData.Name := EntryList[1];

     if NumberEntries > 1 then
        begin
        for Address := 1 to NumberEntries - 1 do
           begin
           EntryList[Address] := EntryList[Address + 1];
           end;
        end;
     dec(NumberEntries);
     end
  else
     begin
     RXData.QTHString := EntryList[1];
     RXData.Name := EntryList[2];

     for Address := 1 to NumberEntries - 2 do
        begin
        EntryList[Address] := EntryList[Address + 2];
        end;
     NumberEntries := NumberEntries - 2;
     end;

  { We should now just have the power or member number left }

  if NumberEntries <> 1 then
     begin
     Exit;
     end;

  if StringIsAllNumbers(EntryList[1]) then { member number }
     begin
     Val(EntryList[1], RXData.NumberReceived, Result1)
     end
  else
     begin
     RXData.Power := EntryList[1];
     end;

  if DX then
     begin
     ProcessRSTQTHNameAndFistsNumberOrPowerExchange := True
     end
  else
     begin
     ProcessRSTQTHNameAndFistsNumberOrPowerExchange := FoundDomesticQTH(RXData);
     end;
end;

function ProcessRSTQSONumberAndRandomCharactersExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   Chars                                  (RS(T) = default, QSO number = 1)
   Chars       QSO Number                 (RS(T) = default)
   Chars       RS(T)       QSO Number
   QSO Number  Chars                      (RS(T) = default)
   RS(T)       Chars       QSO Number
   RS(T)       QSO Number  Chars

  You can enter just the strength of the RS(T) if desired.      }

var
  NumberString, FirstString, SecondString, ThirdString: Str10;

begin
  ProcessRSTQSONumberAndRandomCharactersExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if not StringIsAllNumbers(FirstString) then
     begin
     RXData.RandomCharsReceived := FirstString;
     if ThirdString <> '' then
        begin
        NumberString := SecondString + ' ' + ThirdString
        end
     else
        begin
        NumberString := SecondString;
        end;
     end
  else if not StringIsAllNumbers(SecondString) then
     begin
     RXData.RandomCharsReceived := SecondString;
     if ThirdString <> '' then
        begin
        NumberString := FirstString + ' ' + ThirdString
        end
     else
        begin
        NumberString := FirstString;
        end;
     end
  else
     begin
     RXData.RandomCharsReceived := ThirdString;
     NumberString := FirstString + ' ' + SecondString;
     end;

  if ProcessRSTAndQSONumberExchange(NumberString, RXData) then
     begin
     ProcessRSTQSONumberAndRandomCharactersExchange :=
       (length(RXData.RandomCharsReceived) = 5) and
       (length(RXData.RandomCharsSent) = 5);
     end;

end;

function ProcessRSTAndPostalCodeExchange(Exchange: Str80; var RXData:
  ContestExchange): boolean;

{ Legal entries HA1 1TA, RS(T) HA1 1TA or HA1 1TA RS(T) }

var
  FirstString, SecondString, ThirdString: Str10;

begin
  Result := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  if not StringIsAllNumbers(FirstString) then
     begin
     RXData.QTHString {PostalCode} := FirstString + ' ' + SecondString;
     RXData.RSTReceived := StrToIntDef(ThirdString, 0);

     if RXData.RSTReceived = 0 then
        begin
        RXData.RSTReceived := DefaultRST;
        end;
     Result := True;
     end
  else
     begin
     RXData.QTHString {PostalCode} := SecondString + ' ' + ThirdString;
     RXData.RSTReceived := StrToIntDef(FirstString, 0);
     Result := True;
     end;

  //  RXData.QTHString := Copy(RXData.PostalCode, 1, 2);

  //  ProcessRSTAndPostalCodeExchange := FoundDomesticQTH(RXData);
end;

function ProcessRSTAndQSONumberOrFrenchDepartmentExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;
begin
  Result := False;

  if ParserArray.paCount = 2 then
     begin
     if (ParserArray.paElements[0].prType <> eetNumber) or not
       (sETrst(ParserArray.paElements[0].prInteger, RXData.RSTReceived)) then
        begin
        Exit;
        end;
     end;

  if FrenchID(RXData.QTH.CountryID) then
     begin
     RXData.QTHString := Exchange; //n4af 4.36.5
     //    RXData.QTHString := ParserArray.paElements[ParserArray.paCount - 1].prString;
     if length(RXData.QTHString) = 1 then
        begin
        RXData.QTHString := '0' + RXData.QTHString;
        end;
     if FoundDomesticQTH(RXData) then
        begin
        Result := True;
        end;
     end
  else
     begin
     if ParserArray.paElements[ParserArray.paCount - 1].prType = eetNumber then
        begin
        RXData.NumberReceived := ParserArray.paElements[ParserArray.paCount -
          1].prInteger;
        Result := True;
        end;
     end;
end;

function ProcessRSTAndQSONumberOrDomesticQTHExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

begin
  (* THREE POINT-METHOD TESTS STOOD HERE AND ARE THE CONTESTS' OWN SINCE M5b
    (2026-10-02): RAC (a VE0 station sends a serial), the PCC (letters are a
    QTH, digits a serial) and Arktika Spring (digits and blanks are a serial).
    Each read ActiveQSOPointMethod, so an operator's QSO POINT METHOD line
    reached them; each is now an override of ParseReceivedExchange on the
    contest's class -- the Canada Day and Canada Winter contests, TContestPCC
    and TContestArktikaSpring -- under this shape. What is left is the shape
    itself: a domestic station's QTH, anybody else's serial. *)
  if DomesticCountryCall(RXData.Callsign) then
     begin
     ProcessRSTAndQSONumberOrDomesticQTHExchange :=
       ProcessRSTAndDomesticQTHExchange(Exchange, RXData)
     end
  else
     begin
     ProcessRSTAndQSONumberOrDomesticQTHExchange :=
       ProcessRSTAndQSONumberExchange(Exchange, RXData);
     end;
end;

function ProcessRSTAndPOTAPark(Exchange: ShortString; var RXData:
  ContestExchange): boolean;
// Parses a POTA exchange of the form:
//   RST PARK              e.g. "57 US-0663"
//   RST PARK PARK         e.g. "57 US-0663 US-1234"   (2fer)
//   RST PARK PARK PARK    e.g. "57 US-0663 US-1234 US-5678"  (3fer, etc.)
//   PARK                  e.g. "US-0663"              (no RST)
//
// We tokenize the raw exchange string ourselves rather than using ParseExchange,
// which is hard-limited to three tokens and truncates the third field to
// Str10 (10 chars).  That truncation makes it impossible to carry two park
// refs in one field (e.g. "US-0663 US-1234" = 15 chars).
//
// Delimiter rules:
//   - Tokens are separated by spaces and/or commas, so the operator can type
//     "57 US-0663 US-1234" or "57 US-0663, US-1234" interchangeably.
//
// Multi-park handling:
//   - The first valid park found becomes RXData.QTHString (logged in this QSO).
//   - Any additional valid parks are pushed onto the FPendingParks queue in
//     uPOTAParks.  TryLogContact checks HasPendingParks after writing the QSO
//     and auto-refills the exchange for the next park so the operator just
//     presses Enter again.
//
// RST handling:
//   - The first numeric token is RSTSent; the second (rare in POTA) is RSTReceived.
//   - Non-numeric, non-park tokens are silently ignored.
var
  S          : string;    // Working copy of the exchange for easy manipulation
  Token      : string;    // Current token being examined
  Normalized : string;    // Token after NormalizePOTAPark()
  SpacePos   : Integer;   // Index of the next space delimiter
  RSTFound   : Boolean;   // True once we have consumed the RST token
  AllParks   : string;    // Space-separated list of all parks (for SetLastPOTAExchange)
begin
  // POTA is free-form — any exchange (including empty) is valid. Always True.
  Result             := True;
  RXData.RSTReceived := DefaultRST;
  RXData.RSTSent     := DefaultRST;
  RXData.QTHString   := '';
  RXData.DomesticQTH := '';
  RXData.Name        := '';
  RXData.ExchString  := '';

  if Length(Exchange) = 0 then
     begin
     // Empty exchange is acceptable in POTA (defaults apply).
     Result := True;
     Exit;
     end;

  // Always rebuild the queue from this exchange.  TryLogContact drains the
  // queue inline immediately after the first LogContact, so by the time we
  // re-enter for the next contact the queue is empty already.
  ClearPendingParks;

  // Normalise delimiters: replace commas with spaces so the main loop only
  // needs to handle space-separated tokens.
  S := Exchange;
  for SpacePos := 1 to Length(S) do
     if S[SpacePos] = ',' then
        begin
        S[SpacePos] := ' ';
        end;

  RSTFound  := False;
  AllParks  := '';

  // Walk token by token until the string is exhausted.
  while S <> '' do
     begin
     // Skip any run of leading spaces left by the previous iteration.
     while (S <> '') and (S[1] = ' ') do
        begin
        Delete(S, 1, 1);
        end;
     if S = '' then
        begin
        Break;
        end;

     // Extract the next whitespace-delimited token.
     SpacePos := Pos(' ', S);
     if SpacePos > 0 then
        begin
        Token := Copy(S, 1, SpacePos - 1);
        Delete(S, 1, SpacePos);
        end
     else
        begin
        Token := S;
        S := '';
        end;

     if Token = '' then
        begin
        Continue;
        end;

     // Try to interpret the token as a park reference.
     // NormalizePOTAPark returns the original token unchanged when it is not
     // a park reference (e.g. an RST value like "57" or "599").
     Normalized := NormalizePOTAPark(Token, Settings.My.ResolvedPark);

     if IsValidPOTAPark(Normalized) then
        begin
        if RXData.QTHString = '' then
           begin
           // First park found — this is the QTH for the QSO being logged.
           RXData.QTHString := Normalized;
           Result := True;
           end
        else
           begin
           // Additional park (2fer/Nfer) — queue for inline drain in
           // TryLogContact: one extra LogContact per queued ref, no refill.
           QueuePendingPark(Normalized);
           end;
        // Accumulate all parks for SetLastPOTAExchange below.
        if AllParks = '' then
           begin
           AllParks := Normalized
           end
        else
           begin
           AllParks := AllParks + ' ' + Normalized;
           end;
        end
     else if StringIsAllNumbers(Token) then
        begin
        // Numeric token — treat as signal report.
        // POTA operators give one RST for the contact regardless of how many
        // parks the station is activating.
        if not RSTFound then
           begin
           RXData.RSTSent := StrToIntDef(Token, DefaultRST);
           RSTFound := True;
           end
        else
           begin
           // A second numeric token is RSTReceived (uncommon in POTA but valid).
           RXData.RSTReceived := StrToIntDef(Token, DefaultRST);
           end;
        end
     else if LooksLikeAState(UpperCase(Token)) then
        begin
        // State abbreviation (US or Canadian province) — store in DomesticQTH.
        // First one wins; extras fall through to ExchString below.
        if RXData.DomesticQTH = '' then
           begin
           RXData.DomesticQTH := UpperCase(Token)
           end
        else
           begin
           if RXData.ExchString = '' then
              begin
              RXData.ExchString := UpperCase(Token)
              end
           else
              begin
              RXData.ExchString := RXData.ExchString + ' ' + UpperCase(Token);
              end;
           end;
        end
     else if LooksLikeASection(UpperCase(Token)) then
        begin
        // ARRL section — store in DomesticQTH if not already taken by a state.
        if RXData.DomesticQTH = '' then
           begin
           RXData.DomesticQTH := UpperCase(Token)
           end
        else
           begin
           if RXData.ExchString = '' then
              begin
              RXData.ExchString := UpperCase(Token)
              end
           else
              begin
              RXData.ExchString := RXData.ExchString + ' ' + UpperCase(Token);
              end;
           end;
        end
     else
        begin
        // Check the token against the TRMASTER.DTA name database.
        // If it matches a known operator name, store it in Name (first match
        // wins).  Unknown tokens go to ExchString as free-form notes.
        // Either way the QSO is always saved — POTA exchange is free-form.
        if NameInOperatorSet(Token) and (RXData.Name = '') then
           begin
           RXData.Name := Token
           end
        else
           begin
           if RXData.ExchString = '' then
              begin
              RXData.ExchString := Token
              end
           else
              begin
              RXData.ExchString := RXData.ExchString + ' ' + Token;
              end;
           end;
        end;
     end;

  // Store the full exchange (RST + all parks) so "Repeat POTA Parks (2nd Op)"
  // can re-fill it for a second operator at the same station.
  if AllParks <> '' then
     begin
     SetLastPOTAExchange(IntToStr(RXData.RSTSent) + ' ' + AllParks);
     end;
end;

function ProcessRSTZoneAndPossibleDomesticQTHExchange(Exchange: Str80; var
  RXData: ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2   Entry  #3
   ---------   ---------   ---------
   RS(T)       Zone        QTH
   RS(T)       Zone                      (No QTH)
   Zone                                  (RS(T) = default, no QTH)
   Zone        QTH                       (RS(T) = default)

  You can enter just the strength of the RS(T) if you like.       }

var

  FirstString, SecondString, ThirdString: Str10;
  FirstStringRST: ShortString;

begin
  ProcessRSTZoneAndPossibleDomesticQTHExchange := False;
  if Exchange = '' then
     begin
     Exit;
     end;

  RXData.QTHString := '';

  ParseExchange(Exchange, FirstString, SecondString, ThirdString);

  (* THE RS(T) IS THE FIRST TOKEN IN BOTH BRANCHES BELOW, AND IT IS SET HERE.
    Only the three-token branch used to assign it; the two-token branch
    handed ValidRST whatever the stack held, so "599 14" from a DX station --
    refused either way, by the length test below -- left a different RS(T)
    and zone behind on every run. The same in the D7 source. Found by the
    contest matrix's parse capture (M5b), whose records came out different on
    two runs of the same binary. *)
  FirstStringRST := FirstString;

  if (IsAlpha(FirstString) and (StringIsAllNumbers(SecondString))) then
    // n4af 4.52.2
     begin
     RXData.RSTReceived := DefaultRST;
     RXData.QTHString := FirstString;
     RXData.Zone := StrtoInt(SecondString);
     ProcessRSTZoneAndPossibleDomesticQTHExchange := FoundDomesticQTH(RXData);
     exit;
     end;

  if ThirdString <> '' then
     begin
     if not ValidRST(FirstStringRST, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     RXData.Zone := StrToIntDef(SecondString, 0);
     RXData.QTHString := ThirdString;
     end
  else if SecondString <> '' then
     begin
     if IsAlpha(SecondString) then
        begin
        RXData.RSTReceived := DefaultRST;
        RXData.Zone := StrToIntDef(FirstString, 0);
        RXData.QTHString := SecondString;
        end
     else
        begin
        if not ValidRST(FirstStringRST, RXData.RSTReceived, ActiveMode) then
           begin
           Exit;
           end;
        RXData.Zone := StrToIntDef(SecondString, 0);
        end;
     end;

  if ((length(FirstString) > 2) or (isalpha(Firststring))) then
     begin
     QuickDisplay(TC_INVALID);
     exit
     end
  else if (SecondString = '') and (ThirdString = '') then // 4.52.5
     begin
     RXData.RSTReceived := DefaultRST;
     RXData.Zone := StrToIntDef(Exchange, 0);
     end;

  if RXData.QTHString <> '' then
     begin
     ProcessRSTZoneAndPossibleDomesticQTHExchange := FoundDomesticQTH(RXData)
     end
  else
     begin
     ProcessRSTZoneAndPossibleDomesticQTHExchange := True;
     end;
end;

function ProcessRSTAndPowerExchange(Exchange: ShortString {Str80}; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2
   ---------   ---------
   RS(T)       Power
   Power                     (RS(T) = default)

  You can enter just the strength of the RS(T) if you like.       }

begin
  ProcessRSTAndPowerExchange := False;

  if StringHas(Exchange, ' ') then
     begin
     if not ValidRST(Exchange, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     GetRidOfPrecedingSpaces(Exchange);
     RXData.Power := Exchange;
     end
  else
     begin
     RXData.RSTReceived := DefaultRST;
     RXData.Power := Exchange;
     end;

  ProcessRSTAndPowerExchange := RXData.Power <> '';
end;

function ProcessRSTAndZoneExchange(Exchange: ShortString {Str80}; var RXData:
  ContestExchange): boolean;

{ Each entry of the exchange must be separated by spaces.  The following
  formats work:

   Entry  #1   Entry  #2
   ---------   ---------
   RS(T)       Zone
   Zone                       (RS(T) = default)
   Zone        RST            (RST must be three characters, CW only)

  You can enter just the strength of the RS(T) if you like.    }

var
  FirstString, SecondString, ThirdString: Str10;

begin
  ExchangeErrorMessage := TC_IMPROPERZONENUMBER;
  ProcessRSTAndZoneExchange := False;
  if not StringIsAllNumbersOrSpaces(Exchange) then
     begin
     Exit;
     end;
  RXData.RSTReceived := DefaultRST;

  if StringHas(Exchange, ' ') then
     begin
     if ActiveMode = CW then
        begin
        ParseExchange(Exchange, FirstString, SecondString, ThirdString);

        if (length(SecondString) = 3) and (length(FirstString) < 3) then
           begin
           RXData.RSTReceived := StrToIntDef(SecondString, 0);
           RXData.Zone := StrToIntDef(FirstString, 0);
           //        if length(RXData.Zone) = 1 then          Insert('0', RXData.Zone, 1);
           ProcessRSTAndZoneExchange := True;
           ExchangeErrorMessage := '';
           Exit;
           end;
        end;

     if not ValidRST(Exchange, RXData.RSTReceived, ActiveMode) then
        begin
        Exit;
        end;
     GetRidOfPrecedingSpaces(Exchange);
     end;

  case length(Exchange) of
    1:
      begin
        RXData.Zone := StrToIntDef(Exchange, 0);
        ProcessRSTAndZoneExchange := True;
        ExchangeErrorMessage := '';
      end;

    2:
      begin
        RXData.Zone := StrToIntDef(Exchange, 0);

        (* THREE ZONE-KIND ARMS STOOD HERE, AND NONE IS A RULE ANY CONTEST
          RUNS -- M11 S5, 2026-10-14.

          `ZoneMult = EUHFCYear` accepted the two digits as 0..99 and exited
          before the CQ-zone limit below. Two digits are always 0..99, and
          the limit applies only in CQ zone mode, while the European HF
          Championship and KVP -- the only EUHFCYear contests -- both run
          ITU zone mode (their own GetFlags, no cfCQZoneMode), which is the
          only mode their session ever sets. So the arm and the fall-through
          gave the same answer for every input; the matrix's "599 45"
          (accepted, zone 45) pins it for both. Nothing moved into their
          parse because there was no rule to move.

          `ZoneMult <> JAPrefectures` and `= JAPrefectures` (a prefecture-number limit)
          read a kind no contest's trait or DescribeSession states: dead
          since M11 S2 (plan 2.4), so the first test was always true and
          the second never. *)
        if CTY.ctyZoneMode = CQZoneMode then
           begin
           if (Exchange[1] > '5')                          or
              ((Exchange[1] = '4') and (Exchange[2] >= '1')) then
              begin
              Exit;
              end;
           end;

        ProcessRSTAndZoneExchange := True;
        ExchangeErrorMessage := '';
      end;

  end;
end;

(* BACK THE CONTEST LOG UP, NOW.

  IT USED TO COPY THE .TRW AND THAT STOPPED MEANING ANYTHING. This routine was
  SaveLogFileToFloppy and it did CopyFile(TR4W_LOG_FILENAME, ...) -- the binary
  log. QSO appends stopped writing that file when the log became SQLite, so on
  a new contest the copy failed for want of a source, and on a contest upgraded
  from an older version it SUCCEEDED and saved a stale file containing not one
  contact from the session in progress (Codex review, 2026-09-11).

  The second case is the dangerous one. A backup that reports success and holds
  the wrong bytes is worse than one that fails, because the failure is what
  makes somebody look.

  WHY THE WHOLE BODY MOVED TO uLogStore rather than the file name being
  swapped: a SQLite database in WAL mode cannot be backed up by copying its
  .db, because committed QSOs can still be in the -wal. LogStoreBackup takes a
  consistent snapshot through SQLite, verifies it by opening it separately, and
  only then publishes it over the previous one. None of that belongs in a TRDOS
  display routine; what belongs here is showing the operator what happened.

  THE NAME. Floppy disks are not a thing any more, and the config commands have
  said BACKUP LOG FILE NAME and BACKUP LOG FREQUENCY since 4.56.11 -- only the
  identifiers were still stuck in 1995. *)
procedure BackupLogNow;
var
  report: string;
begin
  if Settings.Log.BackupFileName = '' then
     begin
     Exit;
     end;

  (* SysUtils.Format STRAIGHT INTO QuickDisplay, which takes a string.

    TF.Format wrote into QuickDisplayBuffer -- a 256-byte global AnsiChar
    array -- and QuickDisplay then converted it back. The buffer was never
    wanted here: it is a leftover from when TF.Format was `external user32
    name 'wsprintfA'` and the destination had to be memory the API could
    write. It is pure Pascal now and already builds a string internally, so
    the round trip through a global bought nothing and capped the result at
    1023 bytes on the way. *)
  QuickDisplay(SysUtils.Format(AnsiString(LclText(TC_SAVINGTO)),
                               [CharBufferText(TR4W_LOG_FILENAME), Settings.Log.BackupFileName]));

  (* THE REPORT IS THE ROUTINE'S OUTPUT, success or failure, and it names the
    file either way -- a periodic backup runs unattended and the only place an
    operator will ever see it is this line. *)
  if LogStoreBackup(Settings.Log.BackupFileName, report) then
     begin
     QuickDisplay(AnsiString(report));
     end
  else
     begin
     QuickDisplay(AnsiString(report));
     logger.Error('[Backup] %s', [report]);
     DoABeep(Warning);
     end;
end;


procedure ReviewBackCopyFiles;

begin
  {WLI}

end;

function GetCorrectedCallFromExchangeString(var ExchangeString: OpenString
  {Str80}): Str80;

var
  PotentialCall, TempString: ShortString {Str40};

begin
  GetCorrectedCallFromExchangeString := '';

  TempString := ExchangeString;

  if Settings.CallWindow.CallsignUpdateEnable {and StringHas(TempString, ' ')} then
     begin
     while TempString <> '' do
        begin
        PotentialCall := RemoveLastString(TempString);

        if LooksLikeACallSign(PotentialCall) then
           begin
           GetCorrectedCallFromExchangeString := PotentialCall;

           { Delete all the stuff we have }

           Delete(ExchangeString, 1, length(TempString));

           { Remove the callsign }

           RemoveFirstString(ExchangeString);

           { Rebuild the exchange string without the callsign }

           ExchangeString := TempString + ' ' + ExchangeString;
           Exit;
           end;
        end;
     end;
end;

function ISentThisMultiMessage(MultMessage: string): boolean;

{ Works for both N6TR and K1EA network }

begin
  ISentThisMultiMessage := False;

  if NetDebug then
     begin
     //    SaveSetAndClearActiveWindow(DupeSheetWindow);

     WriteLn('ISentThisMultiMessage called with : ');

     WriteLn;
     WriteLn('The following messages are in the message list : ');
     end;

  if NetDebug then
     begin
     WriteLn('Entry not found.');
     //RestorePreviousWindow;
     end;
end;

procedure CheckForLostMultiMessages;

{ This procedure will look at the MultiMessageMemory and see if there are
  any entries that should either be resent or deleted.  It will stop after
  it finds one to send so it doesn't hog the computer too long. }

var
  LookAddress: integer;

begin
  LookAddress := LastMultiMessage;

  while LookAddress <> FirstMultiMessage do
     begin
     with MultiRememberBuffer^[LookAddress] do
       if not QSL then
          begin
          if RetryCount <= 10 then
             begin

             if ((RetryCount < 2) and (ElaspedSec100(TimeMark) > MultiRetryTime *
               100) or
               (RetryCount >= 2) and (ElaspedSec100(TimeMark) > 3000)) then
                begin
                if RetryCount >= 3 then
                   begin
                   DoABeep(Beepsingle);
                   end;
                SendMultiMessage(Message);
                MarkTime(TimeMark);
                inc(RetryCount);
                end;
             end;

          if (RetryCount >= 5) and (Warnings = 0) then
             begin
             DoABeep(Warning);
             QuickDisplay(TC_PLEASECHECKMULTINETWORK);
             //                        ReminderPostedCount := 60;
             Warnings := 1;
             end;

          if (RetryCount > 10) and (Warnings = 1) then
             begin
             DoABeep(Warning);
             QuickDisplay(TC_POSSIBLEDATALOSSMULTINETWORK);
             //                        ReminderPostedCount := 60;
             Warnings := 2;
             end;

          end;

     LookAddress := (LookAddress + 1) mod MultiMessageBufferSize;
     end;
end;

function ValidCheckSum(Message: string): boolean;

{ Returns TRUE if the check sum looks valid for the message.  Works for
  both K1EA and N6TR network. }

var
  CharPointer: integer;
  CheckSum: Word;
  K1EACheckSum: Byte;
  TempString: string;

begin
  if length(Message) < 8 then
     begin
     ValidCheckSum := False;
     Exit;
     end;

  if 1 = 1 {K1EANetworkEnable} then { K1EA network }
     begin
     K1EACheckSum := 0;

     { We count up to all but the last character }

     for CharPointer := 1 to length(Message) - 1 do
        begin
        K1EACheckSum := K1EACheckSum + Ord(Message[CharPointer]);
        end;

     K1EACheckSum := K1EACheckSum or $80;

     ValidCheckSum := K1EACheckSum = Ord(Message[length(Message)]);

     {       ValidCheckSum := True;}

     if K1EACheckSum <> Ord(Message[length(Message)]) then
       if NetDebug then
          begin
          TempString := '*** NOT VALID CHECKSUM BUT USED ANYWAY ***';
          BlockWrite(NetDebugBinaryInput, TempString[1], length(TempString));
          end;
     end

  else { TR network }
     begin
     CheckSum := 0;

     for CharPointer := 1 to 5 do
        begin
        CheckSum := CheckSum + Ord(Message[CharPointer]);
        end;

     for CharPointer := 8 to length(Message) do
        begin
        CheckSum := CheckSum + Ord(Message[CharPointer]);
        end;

     ValidCheckSum := (Hi(CheckSum) = Ord(Message[6])) and
       (Lo(CheckSum) = Ord(Message[7]));
     end;
end;

function TimeToDie(var Message: string): boolean;

{ This function will decrement the hop count in the message.  If it has
  expired, it will return TRUE.  Will always return False if we are in
  the K1EANetworkMode }

var
  TimeToLive: Byte;
  CheckSum: Word;

begin
  {
    if K1EANetworkEnable then
    begin
      TimeToDie := False;
      Exit;
    end;
  }
  TimeToLive := Ord(Message[9]);
  dec(TimeToLive);

  if TimeToLive <= 0 then
     begin
     TimeToDie := True;
     Exit;
     end;

  TimeToDie := False;
  Message[9] := CHR(TimeToLive);

  CheckSum := Ord(Message[6]);
  CheckSum := Swap(CheckSum);
  CheckSum := CheckSum + Ord(Message[7]);
  dec(CheckSum);
  Message[6] := CHR(Hi(CheckSum));
  Message[7] := CHR(Lo(CheckSum));
end;

function ThisMessageIsForMe(Message: string): boolean;
var
  Destination: Byte;
  { This function will return TRUE if the message is addressed to us or is
    a broadcast message. }

begin
  if not 1 = 1 {K1EANetworkEnable} then { N6TR Network mode }
     begin
     Destination := Ord(Message[2]);

     ThisMessageIsForMe := (Destination = $FF) or
       (Destination = MultiBandAddressArray[ActiveBand]);
     end
  else
    { At this point, I am not aware of any commands on the K1EA network
      that would not be for me.  This might change as I get into it
      more }

     begin
     ThisMessageIsForMe := True;
     end;
end;

function Trim(const s: string; c: Char): string;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(s);
  while (First <= Last) and (s[First] = c) do
     begin
     Inc(First);
     end;
  while (First < Last) and (s[Last] = c) do
     begin
     Dec(last);
     end;
  Result := Copy(s, First, Last - First + 1);
end;

function WeHaveProcessedThisMessage(Message: string): boolean;

{ This function will look at the message passed to it and see if we have
  seen this message before.  If we have, it will return TRUE.  If not, it
  will add it to the list of messages we have seen and return FALSE. }

var
  Source, Serial: Byte;
  ActiveMessage: integer;
  CheckSum: Word;

begin
  {
    if K1EANetworkEnable then // Do not expect repeat messages without retries
    begin
      WeHaveProcessedThisMessage := False;
      Exit;
    end

    else
    begin // N6TR Network Mode
      Source := ord(message[1]);
      Serial := ord(message[5]);

      CheckSum := ord(message[6]);
      CheckSum := Swap(CheckSum);
      CheckSum := CheckSum + ord(message[7]);

      CheckSum := CheckSum - ord(message[9]); // Make sure TTL isn't a factor
    end;
  }
  (* ZERO, BECAUSE THE BLOCK THAT USED TO FILL THESE IS COMMENTED OUT ABOVE.

    Source, Serial and CheckSum are read straight into the dedupe table below
    and compared against it, and nothing assigns them -- so this table was
    being filled and searched with whatever was on the stack.  FPC reports all
    three.

    THIS MAKES IT DETERMINISTIC, NOT CORRECT.  With the N6TR parse commented
    out every message now looks like (0, 0, 0), so the dedupe matches
    everything after the first rather than matching at random.  Both are wrong;
    only one is diagnosable.  The real fix is to restore the parse or delete
    the feature, and that is a multi-network decision -- see
    docs/UNINITIALISED_LOCALS_AUDIT.md finding 3. *)
  Source   := 0;
  Serial   := 0;
  CheckSum := 0;

     { See if we have a virgin list.  If so, add the entry }

  if ProcessedMultiMessagesStart = ProcessedMultiMessagesEnd then
     begin
     WeHaveProcessedThisMessage := False;
     ProcessedMultiMessages[ProcessedMultiMessagesStart].Source := Source;
     ProcessedMultiMessages[ProcessedMultiMessagesStart].Serial := Serial;
     ProcessedMultiMessages[ProcessedMultiMessagesStart].Check := CheckSum;
     inc(ProcessedMultiMessagesEnd); { Increments to one }
     Exit;
     end;

  { Start at the end of the list }

  ActiveMessage := ProcessedMultiMessagesEnd - 1;

  if ActiveMessage < 0 then
     begin
     ActiveMessage := ProcessedMultiMessageBufferLength - 1;
     end;

  repeat
    if (ProcessedMultiMessages[ActiveMessage].Source = Source) and
      (ProcessedMultiMessages[ActiveMessage].Serial = Serial) and
      (ProcessedMultiMessages[ActiveMessage].Check = CheckSum) then
       begin
       WeHaveProcessedThisMessage := True;
       Exit;
       end;

    if ActiveMessage = ProcessedMultiMessagesStart then { End of list }
       begin
       ActiveMessage := ProcessedMultiMessagesEnd;
       ProcessedMultiMessages[ActiveMessage].Source := Source;
       ProcessedMultiMessages[ActiveMessage].Serial := Serial;
       ProcessedMultiMessages[ActiveMessage].Check := CheckSum;

       inc(ProcessedMultiMessagesEnd);

       if ProcessedMultiMessagesEnd >= ProcessedMultiMessageBufferLength then
          begin
          ProcessedMultiMessagesEnd := 0;
          end;

       if ProcessedMultiMessagesEnd = ProcessedMultiMessagesStart then
          begin
          inc(ProcessedMultiMessagesStart);

          if ProcessedMultiMessagesStart >= ProcessedMultiMessageBufferLength then
             begin
             ProcessedMultiMessagesStart := 0;
             end;
          end;

       WeHaveProcessedThisMessage := False;
       Exit;
       end;

    dec(ActiveMessage);

    if ActiveMessage < 0 then
       begin
       ActiveMessage := ProcessedMultiMessageBufferLength - 1;
       end;

  until False;
end;

function ThisIsAMultiTalkMessage(MessageString: string): boolean;

begin
  {
    if K1EANetworkEnable then
      ThisIsAMultiTalkMessage := MessageString[1] = 'T'
    else
      ThisIsAMultiTalkMessage := ord(MessageString[3]) = MultiTalkMessage;
     }
end;

function GetMultiPortCommand: string;

{ This will retrieve a multi command string from the MultiReceiveCharBuffer.
  It works for either K1EA or N6TR network modes!! }

var
  TempString: string;

begin
  //WLI ????????
//  Result := TR4W_MULTIMESSAGE_STRING;
  Exit;

  GetMultiPortCommand := '';

  if TempString = '' then
     begin
     Exit;
     end;

  if NetDebug then
     begin
     BlockWrite(NetDebugBinaryInput, TempString[1], length(TempString));
     end;

  if not ValidCheckSum(TempString) then { Works for TR and CT }
     begin
     if NetDebug then
        begin
        TempString := '*** NOT VALID CHECKSUM ***';
        BlockWrite(NetDebugBinaryInput, TempString[1], length(TempString));
        end;

     Exit;
     end;

  { Okay, we have a valid message to deal with.  If it is one of ours,
    we will ignore it, unless it was MultiTalkMessage }

  if ISentThisMultiMessage(TempString) then { It is one of ours }
     begin
     if ThisMessageIsForMe(TempString) then
       if not WeHaveProcessedThisMessage(TempString) then
         if ThisIsAMultiTalkMessage(TempString) then
            begin
            GetMultiPortCommand := TempString; { Process my own message }
            end;

     Exit;
     end;

  { If this message has been hoping around too long, ignore it }

  if TimeToDie(TempString) then
     begin
     Exit;
     end;

  { Okay, we have a valid message, and it isn't ours, pass it on. }

  if not ThisMessageIsForMe(TempString) then
     begin
     Exit;
     end;

  { We have a message for me to act on (unless I have already seen it) }

  if WeHaveProcessedThisMessage(TempString) then
     begin
     if NetDebug then
        begin
        TempString := '*** PROCESSED BEFORE ***';
        BlockWrite(NetDebugBinaryInput, TempString[1], length(TempString));
        end;

     Exit;
     end;

  GetMultiPortCommand := TempString;
end;


procedure SendMultiCommand(Source: Byte; Destination: Byte; ControlByte: Byte;
  Message: string);

begin

end;

procedure StuffInit;
begin
  DVKStamp;
end;

procedure SpeedUp;
begin
  if CodeSpeed < (99 - Settings.Cw.SpeedIncrement) then {KK1L: 6.72}
     begin
     SetSpeed(CodeSpeed + Settings.Cw.SpeedIncrement); {KK1L: 6.72}
     DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
     end;
end;

procedure ShowPreviousDupeQSOs(Call: CallString;
  Band: BandType;
  Mode: ModeType);
label
  1;
  { This routine will display previous duplicate QSOs with the station
    indicated. }

var
  found: array of ContestExchange;
  count: integer;
begin
  if Call = '' then
     begin
     Exit;
     end;

  if not LogSourceOpen then
     begin
     Exit;
     end;

  count := 0;
  LogSourceRewind;
  1:
  if LogSourceNext( TempRXData ) then
     begin

     if ((Band = TempRXData.Band) or not Settings.Qso.ByBand) and
       ((Mode = TempRXData.Mode) or not Settings.Qso.ByMode) then

       if TempRXData.Callsign = Call then
          begin
          (* COLLECTED, THEN HANDED OVER ONCE.

            This used to add each QSO to a list view as it found it, through
            tPreviousDupeQSOsWndHandle -- a handle NOTHING EVER ASSIGNED. It
            was always 0, so every call on it was a no-op and this window has
            never shown anything; the only visible effect was the editable log
            being hidden to make room for it. See TR4WPreviousDupesSet. *)
          SetLength(found, count + 1);
          found[count] := TempRXData;
          Inc(count);
          end;
     goto 1;
     end;

  LogSourceClose;

  if count > 0 then
     begin
     TR4WPreviousDupesSet(found);
     TR4WPreviousDupesShow(True);
     end;
end;

procedure SlowDown;

begin
  {IF CodeSpeed > 4 THEN}
  if CodeSpeed > (Settings.Cw.SpeedIncrement + 1) then {KK1L: 6.72}
     begin
     {SetSpeed (CodeSpeed - 3);}
  //   CW_SPEED1 := CW_SPEED1 - Settings.Cw.SpeedIncrement;
     SetSpeed(CodeSpeed - Settings.Cw.SpeedIncrement); {KK1L: 6.72}
     DisplayCodeSpeed {(CodeSpeed, CWEnabled, DVPOn, ActiveMode)};
     end;
end;



procedure DisplayGridSquareStatus(Call: CallString);

var
  Range, Address: integer;
  Change: boolean;
  TempCall: CallString;

begin
  NumberGridSquaresInList := 0;

  (* THE CONTEST SAYS WHETHER ITS MULTIPLIER IS THE GRID SQUARE -- M11 S6
    part 1 (TContestBase.HasGridSquareMultiplier). It asked
    `ContestSession.DomesticMult = GridSquares`. *)
  if ContestHasGridSquareMultiplier(ActiveContest(Contest)) (* wli: and RoverCall(Call) *) then
     begin
     CreateGridSquareList(Call, ActiveBand);

     if NumberGridSquaresInList > 0 then
        begin
        if NumberGridSquaresInList > 1 then
           begin
           Range := NumberGridSquaresInList - 2;

           repeat
             Change := False;

             for Address := 0 to Range do
               if GridSquareList[Address] > GridSquareList[Address + 1] then
                  begin
                  TempCall := GridSquareList[Address];
                  GridSquareList[Address] := GridSquareList[Address + 1];
                  GridSquareList[Address + 1] := TempCall;
                  Change := True;
                  end;

             dec(Range);
           until (not Change) or (Range < 0);
           end;

        //      SaveSetAndClearActiveWindow(EditableLogWindow);

        for Address := 0 to NumberGridSquaresInList - 1 do
           begin
           //{WLI}                IF WhereX >= 76 THEN WriteLn;

           //{WLI}                IF WhereX > 1 THEN Write (' ');

           //{WLI}                Write (GridSquareList [Address]);

           //   FRM.POSSIBLECALLWINDOW.Items.Add(GridSquareList [Address]);
           end;

        //            //RestorePreviousWindow;

        GridSquareListShown := True;
        end;
     end;
end;

function LogFileLooksOkay: boolean;

{ Returns TRUE if the LOG.DAT file looks about right for the number of
  QSOs the program thinks we have }

begin
  Result := False;
  if not LogSourceOpen then
     begin
     Exit;
     end;
  (* A COUNT, NOT A FILE SIZE.  This asked GetFileSize whether the log held
    exactly riTotalRecordsInLog records, by reconstructing the byte length the
    file ought to have.  That is three assumptions about the store -- that it is
    a file, that its records are fixed width, and that its header is one record
    long -- to answer a question about HOW MANY.  Same test, asked directly, and
    it now means the same thing whichever store is behind it. *)
  if LogSourceRecordCount = tRestartInfo.riTotalRecordsInLog then
     begin
     Result := True;
     end;
  LogSourceClose;

  
end;


procedure CalculateQSOPoints(var RXData: ContestExchange);
begin
   RXData.QSOPoints := 0;

   (* A CONTEST WITH A CLASS IS SCORED BY ITS ScoreQSO, AND NOTHING HERE RUNS
      -- M3, 2026-10-01 (docs/CONTEST_OWNERSHIP_DESIGN.md 7.7).

      ScoreQSO is the contest's one public scoring entry point, and it runs
      the order this routine used to: an off-band QSO scores 0 (UsesBand, NY4I
      2026-10-01), then the four QSO POINTS ... overrides, then the contest's
      own rule. Asking it here, FIRST, is what makes that order the class's
      rather than a convention every caller has to repeat. *)
   if ActiveContest(Contest) <> nil then
      begin
      ActiveContest(Contest).ScoreQSO(RXData);
      Exit;
      end;

   (* THE CLASSLESS PATH: DUMMYCONTEST, THE ONE ContestType WITH NO CLASS.
      The four QSO POINTS ... overrides, then 0 -- what
      Test_DummyContestScoresOnlyTheOverrides pins for its identity's
      ScoreQSO. The same function ScoreQSO applies, fed the same settings, so
      the two paths cannot read them differently. No band check: a classless
      contest uses every band (ContestCreditsBand answers True for nil). The
      result is not needed: no match leaves the 0 set above.

      THE LEGACY `case ActiveQSOPointMethod of` THAT STOOD HERE IS DELETED
      (M10 S3, 2026-10-14; design 7.15, plan section 3). Every registered
      contest is scored by its class, and the arms no class took were reached
      only through QSO POINT METHOD, retired at M10 S2 -- so only DUMMYCONTEST
      still reached the case, reading a point method FoundContest never
      resets for it: a stale value from the previous contest (plan F6). The
      arms are in git history and in the D7 tree. *)
   ApplyQSOPointOverride(CurrentQSOPointOverrides, RXData);
end;

procedure SendMultiInfoMessage(Band: BandType; Mode: ModeType; Message: Str80);

var
  Sum: Byte;

begin
  Sum := CheckSum(Message);

  if Sum = LastMultiInfoMessageSum[Band, Mode] then
     begin
     Exit;
     end;

  LastMultiInfoMessageSum[Band, Mode] := Sum;

  Message := AddBand(Band) + AddMode(Mode) + Message;

  SendMultiCommand(MultiBandAddressArray[Band], $FF, MultiInformationMessage,
    Message);
end;

procedure RotorControl(Heading: integer);
begin
  // DELEGATED to the rotator factory.  What stood here was a
  // `case ActiveRotatorType of` picking a printf format per rotator, wrapped in
  // two special cases that said plainly it had outgrown its shape: PstRotator
  // returned EARLY because it is UDP and has no port, and AlfaSpid formatted
  // like the others and then reached back into the buffer to patch two bytes
  // and force the length to 13.
  //
  // Each protocol is now one driver, and every frame is pinned byte-for-byte by
  // unit tests that need no hardware.  This routine survives as the NAME the
  // rest of TR4W calls -- the strangler shape the radio and CW keyer factories
  // used -- so no caller had to move.
  //
  // THE ROTOR BROADCAST STAYS HERE.  It is not a rotator: it is a broadcast
  // of the heading for whatever else is listening, and it fires whether or not
  // any rotator is configured (ny4i 4.44.9).  Moving it into the factory would
  // tie a broadcast to owning hardware.
  (* ASKED OF THE BROADCASTER, NOT OF A GLOBAL -- see SendUDPRotorCommand
    itself for why the endpoint moved with it. *)
  if UDPBroadcaster.Enabled(usRotor) then
     begin
     SendUDPRotorCommand(Heading);
     end;

  // The BAND travels with the heading now, because a rotator may claim only
  // some bands -- NY4I's case where 20 m turns the Orion and 40 m the Yaesu.
  // With one rotator defined, which is nearly every station, its claim is blank
  // and it answers for everything.
  uRotatorControl.TurnRotator(Heading,
    string(BandStringsArrayWithOutSpaces[ActiveBand]));
end;

{
}

function SetRST(Ex: integer; var RST: smallInt {Word}): boolean;
begin
  Result := False;

  case ActiveMode of
    CW:
      begin
        if Ex in [1..9] then
           begin
           RST := 509 + Ex;
           Result := True;
           end
        else
           begin
           if (Ex >= 111) and (Ex <= 599) then
              begin
              RST := Ex;
              Result := True;
              end;
           end;
      end;
    Phone:
      begin
        if Ex in [1..9] then
           begin
           RST := 50 + Ex;
           Result := True;
           end
        else if Ex in [11..59] then
           begin
           RST := Ex;
           Result := True;
           end
      end;
  end;
  {
    if Ex in [1..9] then
    begin
      case ActiveMode of
        CW: RST := 509 + Ex;
        Phone: RST := 5 + Ex;
      end;
      Result := True;
    end;

    if Ex in [111..599] then
    begin
      case ActiveMode of
        CW: RST := 509 + Ex;
        Phone: RST := 5 + Ex;
      end;
      Result := True;
    end;
  }
end;

function ParseArray(e: Str80): boolean;
var
  i: integer;
  TmpBuf: array[0..31] of AnsiChar;
  St: Cardinal;
  en: Cardinal;
  copyCounter: Cardinal;
  isN: boolean;
begin
  FillChar(ParsedRecord, SizeOf(ParsedRecord), 0);

  if e = '' then
     begin
     Result := False;
     Exit;
     end;

  St := 0;
  en := 0;

  for i := 1 to length(e) do
     begin
     if (e[i] <> ' ') and (St = 0) then
        begin
        St := i;
        Continue;
        end;

     if St > 0 then
        begin
        if e[i] = ' ' then
           begin
           en := i - 1;
           end
        else if i = length(e) then
           begin
           en := i;
           end;

        if en > 0 then
           begin
           isN := True;
           FillChar(TmpBuf, SizeOf(TmpBuf), 0);
           for copyCounter := St to en do
              begin
              if not (e[copyCounter] in ['0'..'9']) then
                 begin
                 isN := False;
                 end;
              TmpBuf[copyCounter - St] := e[copyCounter];
              end;
           inc(ParsedRecord.prTotalElements);
           if (isN) then
              begin
              ParsedRecord.prNumbers[ParsedRecord.prTotalNumbers] :=
                LeadingInt(CharBufferText(TmpBuf));
              inc(ParsedRecord.prTotalNumbers);
              end
           else
              begin
              Move(TmpBuf, ParsedRecord.prStrings[ParsedRecord.prTotalStrings], SizeOf(TmpBuf));
              inc(ParsedRecord.prTotalStrings);
              end;

           en := 0;
           St := 0;
           end;
        end;

     end;

  Result := True;

end;

function ParseArray2(ExchangeString: Str80): boolean;
var
  Element: integer;
  i: integer;
  Alpha: boolean;
  Number: boolean;
  PositionCounter: integer;
begin
  FillChar(ParserArray, SizeOf(ParserArray), 0);
  if ExchangeString = '' then
     begin
     Result := False;
     Exit;
     end;
  Element := 0;
  PositionCounter := 0;
  Alpha := False;
  Number := False;

  for i := 1 to length(ExchangeString) + 1 do
     begin
     if (ExchangeString[i] = ' ') or (i = length(ExchangeString) + 1) then
        begin
        if PositionCounter = 0 then
           begin
           Continue;
           end;

        ParserArray.paElements[Element].prString[0] := AnsiChar(PositionCounter);

        inc(ParserArray.paCount);

        if Alpha then
           begin
           ParserArray.paElements[Element].prType := eetAlpha;
           end;
        if Number then
           begin
           ParserArray.paElements[Element].prType := eetNumber;
           end;
        if Alpha and Number then
           begin
           ParserArray.paElements[Element].prType := eetMixed;
           end;

        if ParserArray.paElements[Element].prType = eetNumber then
           begin
           ParserArray.paElements[Element].prInteger :=
             StrToIntDef(ParserArray.paElements[Element].prString, 0);
           end;

        ParserArray.paStatus[Element] := ParserArray.paElements[Element].prType;

        inc(Element);
        PositionCounter := 0;
        Alpha := False;
        Number := False;

        if (Element = 4) or (i = length(ExchangeString) + 1) then
           begin
           Result := True;
           Exit;
           end
        else
           begin
           Continue;
           end;

        end;
     inc(PositionCounter);
     ParserArray.paElements[Element].prString[PositionCounter] :=
       ExchangeString[i];
     if ExchangeString[i] in ['0'..'9'] then
        begin
        Number := True
        end
     else
        begin
        Alpha := True;
        end;
     end;
end;

function ProcessRSTAndGridSquareOrRDAExchange(Exchange: ShortString {Str80}; var
  RXData: ContestExchange): boolean;
var
  TestString: Str20;
begin
  Result := False;
  //RXData.DomesticQTH := '';
  RXData.RSTReceived := 0;

  if length(Exchange) = 0 then
     begin
     Exit;
     end;

  while Exchange <> '' do
     begin
     TestString := RemoveLastString(Exchange);

     if (GoodLookingGrid(TestString) or GoodLookingRDA(TestString)) then
        begin
        if RXData.QTHString = '' then
           begin
           RXData.QTHString := TestString;
           end;
        end
     else if (RXData.RSTReceived = 0) and StringIsAllNumbers(TestString) then
        begin
        if length(TestString) = 1 then
           begin
           case ActiveMode of
             CW: RXData.RSTReceived := 509 + (Ord(TestString[1]) - 48) * 10;
             Phone: RXData.RSTReceived := 50 + (Ord(TestString[1]) - 48);
           end;
           end
        else
           begin
           RXData.RSTReceived := StrToIntDef(TestString, 0);
           end;

        end;
     end;

  Result := RXData.QTHString <> '';

  (* The UA4W Championship's rule -- the QTH is the domestic QTH -- is its
    class's ParseReceivedExchange since 2026-10-14 (design Q28). *)

  (* `if Contest = ALRS_UA1DZ_CUP` worked out an oblast-based domestic QTH. It
    was DEAD BY DEFAULT and is deleted, not moved: the ALRS-UA1DZ Cup runs
    RSTDomesticQTHExchange in every station variant (its row, and the contest
    matrix), so this shape -- and the branch inside it -- was reached only
    by an operator stating EXCHANGE RECEIVED = RST AND GRID SQUARE OR RDA for
    it. The same rule as the dead export arms M4 deleted. *)
end;

(* ONE EXCHANGE SHAPE, PARSED -- the engine's half of M5b (2026-10-02).

  THIS IS ProcessExchange's OLD `case ActiveExchange of`, keyed on the shape it
  is HANDED rather than on the global, and with the one contest test it held
  (LABRE) moved to LABRE's class. One parser per exchange shape, none naming a
  contest. A contest reaches it only through the TReceivedExchangeSession the
  engine hands it (its ParseShape) -- the base's default parses the session's
  own shape, and an override may ask for another (RAC, the PCC, Arktika
  Spring and LABRE do).

  THE TEXT ARRIVES AS A string AND IS PUT BACK INTO THE Str80 IT WAS TYPED AS
  -- a typed exchange, ANSI and at most 80 characters, so the explicit cast
  loses nothing. *)
function ParseExchangeShape(aShape: ExchangeType; const aText: string;
  var RData: ContestExchange): boolean;
var
  ExchangeString: Str80;
begin
  Result := False;
  ExchangeString := ShortString(aText);

  case aShape of

    RSTAndGridSquareOrRDAExchange:
      ParseExchangeShape := ProcessRSTAndGridSquareOrRDAExchange(ExchangeString,
        RData);

    CheckAndChapterOrQTHExchange:
      ParseExchangeShape := ProcessCheckAndChapterOrQTHExchange(ExchangeString,
        RData);

    ClassDomesticOrDXQTHExchange:
      begin
        logger.debug('Calling ProcessClassAndDomesticOrDXQTHExchange from ParseExchangeShape');
        ParseExchangeShape :=
          ProcessClassAndDomesticOrDXQTHExchange(ExchangeString, RData);
      end;

    KidsDayExchange:
      ParseExchangeShape := ProcessKidsExchange(ExchangeString, RData);

    NameQTHAndPossibleTenTenNumber:
      ParseExchangeShape :=
        ProcessNameQTHAndPossibleTenTenNumberExchange(ExchangeString, RData);

    NameAndDomesticOrDXQTHExchange:
      ParseExchangeShape := ProcessNameAndDomesticOrDXQTHExchange(ExchangeString,
        RData);

    NameAndPossibleGridSquareExchange:
      ParseExchangeShape :=
        ProcessNameAndPossibleGridSquareExchange(ExchangeString, RData);

    QSONumberAndNameExchange:
      ParseExchangeShape := ProcessQSONumberAndNameExchange(ExchangeString, RData);

    QSONumberAndGeoCoordinates:
      ParseExchangeShape :=
        ProcessQSONumberAndGeoCoordinatesExchange(ExchangeString, RData);

    QSONumberAndCoordinatesSum:
      ParseExchangeShape :=
        ProcessQSONumberAndCoordinatesSumExchange(ExchangeString, RData);

    QSONumberAndZone:
      ParseExchangeShape := ProcessQSONumberAndZoneExchange(ExchangeString, RData);

    QSONumberDomesticOrDXQTHExchange:
      ParseExchangeShape :=
        ProcessQSONumberAndDomesticOrDXQTHExchange(ExchangeString, RData);

    QSONumberDomesticQTHExchange:
      ParseExchangeShape := ProcessQSONumberAndDomesticQTHExchange(ExchangeString,
        RData);

    QSONumberAndGridSquare:
      ParseExchangeShape := ProcessQSONumberAndGridSquareExchange(ExchangeString,
        RData);

    QSONumberNameChapterAndQTHExchange:
      ParseExchangeShape :=
        ProcessQSONumberNameChapterAndQTHExchange(ExchangeString, RData);

    QSONumberNameDomesticOrDXQTHExchange:
      ParseExchangeShape :=
        ProcessQSONumberNameAndDomesticOrDXQTHExchange(ExchangeString, RData);

    RSTAgeExchange:
      ParseExchangeShape := ProcessRSTAndAgeExchange(ExchangeString, RData);

    RSTAndFOCNumberExchange: //n4af
      ParseExchangeShape := ProcessRSTAndPowerExchange(ExchangeString, RData);
    //n4af

    AgeAndQSONumberExchange: ParseExchangeShape :=
      ProcessAgeAndQSONumberExchange(ExchangeString, RData);

    QSONumberAndAgeExchange: ParseExchangeShape :=
      ProcessQSONumberAndAgeExchange(ExchangeString, Rdata);

    RSTAgeAndPossibleSK:
      ParseExchangeShape := ProcessRSTAgeAndPossibleSK(ExchangeString, RData);

    RSTAndContinentExchange:
      ParseExchangeShape := ProcessRSTAndContinentExchange(ExchangeString, RData);

    RSTALLJAPrefectureAndPrecedenceExchange:
      ParseExchangeShape :=
        ProcessRSTAllJAPrefectureAndPrecedenceExchange(ExchangeString, RData);

    RSTAndGridExchange:
      ParseExchangeShape := ProcessRSTAndGridSquareExchange(ExchangeString, RData);

    RSTAndOrGridExchange:
      ParseExchangeShape := ProcessRSTAndOrGridSquareExchange(ExchangeString,
        RData);

    GridExchange:
      ParseExchangeShape := ProcessGridSquareExchange(ExchangeString, RData);

    Grid2Exchange:
      ParseExchangeShape := ProcessGrid2Exchange(ExchangeString, RData);

    RSTAndGrid3Exchange:
      ParseExchangeShape := ProcessRSTAndGrid3Exchange(ExchangeString, RData);
    // 4.96.3

    RSTAndPostalCodeExchange:
      ParseExchangeShape := ProcessRSTAndPostalCodeExchange(ExchangeString, RData);

    RSTAndPOTAPark:
      ParseExchangeShape := ProcessRSTAndPOTAPark(ExchangeString, RData);

    RSTAndQSONumberOrDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessRSTAndQSONumberOrDomesticQTHExchange(ExchangeString, RData);

    RSTAndQSONumberOrFrenchDepartmentExchange:
      ParseExchangeShape :=
        ProcessRSTAndQSONumberOrFrenchDepartmentExchange(ExchangeString, RData);

    RSTDomesticQTHExchange:
      ParseExchangeShape := ProcessRSTAndDomesticQTHExchange(ExchangeString, RData);

    RSTDomesticOrDXQTHExchange:
      (* LABRE's 'a PY station sends a state' stood here as
        `if Contest = LABRE`; it is TContestLABRE's rule since M5b. *)
      ParseExchangeShape := ProcessRSTAndDomesticOrDXQTHExchange(ExchangeString,
        RData);

    RSTDomesticQTHOrQSONumberExchange:
      if DomesticCountryCall(RData.Callsign) and
        (StringHasLetters(ExchangeString)) then //n4af 4.44.4 HADX
         begin
         ParseExchangeShape := ProcessRSTAndDomesticQTHExchange(ExchangeString,
           RData)
         end
      else
         begin
         ParseExchangeShape := ProcessRSTAndQSONumberExchange(ExchangeString,
           RData);
         end;

    RSTNameAndQTHExchange:
      ParseExchangeShape := ProcessRSTNameAndQTHExchange(ExchangeString, RData);

    RSTPossibleDomesticQTHAndPower:
      ParseExchangeShape :=
        ProcessRSTPossibleDomesticQTHAndPowerExchange(ExchangeString, RData);

    RSTPowerExchange:
      ParseExchangeShape := ProcessRSTAndPowerExchange(ExchangeString, RData);

    RSTPrefectureExchange:
      ParseExchangeShape := ProcessRSTAndPrefectureExchange(ExchangeString, RData);

    RSTQSONumberExchange:
      ParseExchangeShape := ProcessRSTAndQSONumberExchange(ExchangeString, RData);

    NZFieldDayExchange:
      ParseExchangeShape := ProcessNZFieldDayExchange(ExchangeString, RData);

    RSTQSONumberAndDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessRSTQSONumberAndDomesticQTHExchange(ExchangeString, RData);

    QSONumberAndPreviousQSONumber:
      ParseExchangeShape := ProcessQSONumberAndPreviousQSONumber(ExchangeString,
        RData);

    RSTQSONumberAndGridSquareExchange:
      ParseExchangeShape :=
        ProcessRSTQSONumberAndGridSquareExchange(ExchangeString, RData);

    RSTQSONumberOrDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessRSTQSONumberorDomesticQTHExchange(ExchangeString, RData);
    // 4.53.2

    RSTQSONumberAndPossibleDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessRSTQSONumberAndPossibleDomesticQTHExchange(ExchangeString,
        RData);

    QSONumberAndPossibleDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessQSONumberAndPossibleDomesticQTHExchange(ExchangeString, RData);
    {KK1L: 6.73}

    RSTQSONumberAndRandomCharactersExchange:
      ParseExchangeShape :=
        ProcessRSTQSONumberAndRandomCharactersExchange(ExchangeString, RData);

    RSTQTHNameAndFistsNumberOrPowerExchange:
      ParseExchangeShape :=
        ProcessRSTQTHNameAndFistsNumberOrPowerExchange(ExchangeString, RData);

    RSTQTHExchange:
      ParseExchangeShape := ProcessRSTAndQTHExchange(ExchangeString, RData);

    RSTZoneAndPossibleDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessRSTZoneAndPossibleDomesticQTHExchange(ExchangeString, RData);

    RSTZoneExchange:
      ParseExchangeShape := ProcessRSTAndZoneExchange(ExchangeString, RData);

    RSTZoneOrSocietyExchange:
      if StringIsAllNumbersOrSpaces(ExchangeString) then
         begin
         ParseExchangeShape := ProcessRSTAndZoneExchange(ExchangeString, RData)
         end
      else
         begin
         ExchangeString := UpperCase(ExchangeString);
         ParseExchangeShape := ProcessRSTAndDomesticQTHExchange(ExchangeString,
           RData);
         end;

    QSONumberPrecedenceCheckDomesticQTHExchange:
      ParseExchangeShape :=
        ProcessQSONumberPrecedenceCheckDomesticQTHExchange(ExchangeString,
        RData);

    RSTLongJAPrefectureExchange: {KK1L: 6.72 JA}
      begin
        ExchangeString := UpperCase(ExchangeString);
        ParseExchangeShape := ProcessRSTAndJAPrefectureExchange(ExchangeString,
          RData);
      end;

    RSTZoneOrDomesticQTH:
      if (DomesticCountryCall(RData.Callsign) or (not
        (StringisAllNumbersorSpaces(exchangestring)))) then // 4.77.6
         begin
         ParseExchangeShape := ProcessRSTAndDomesticQTHExchange(ExchangeString,
           RData)
         end
      else
         begin
         ParseExchangeShape := ProcessRSTAndZoneExchange(ExchangeString, RData);
         end;

  end; { of case }
end;

(* CTY.DAT's zone for a call -- the TReceivedExchangeSession service IARU's
  rule asks for. *)
function ParseSessionZoneOfCall(const aCall: string): Byte;
begin
  Result := ctyGetZone(aCall);
end;

(* What live entry does to give up on the QSO being typed -- the
  TReceivedExchangeSession service SAC's rule asks for. *)
procedure ParseSessionAbandonEntry;
begin
  InitializeQSO;
end;

(* Does the loaded domestic QTH table know this QTH? -- the
  TReceivedExchangeSession service a state party's out-of-state rule asks
  for. FoundDomesticQTH itself, on a scratch exchange, so the answer is the
  table's own and the QSO being parsed is not touched. *)
function ParseSessionIsDomesticQTH(const aQTH: string): boolean;
var
  scratch: ContestExchange;
begin
  (* No QTH is no domestic QTH -- answered here so FoundDomesticQTH does not
    log its blank-QTH error for a question nobody typed. *)
  if aQTH = '' then
     begin
     Result := False;
     Exit;
     end;
  FillChar(scratch, SizeOf(scratch), 0);
  (* The cast is a received QTH returning to the width it was typed in. *)
  scratch.QTHString := ShortString(aQTH);
  Result := FoundDomesticQTH(scratch);
end;

(* THE CONTEST PARSES AND VALIDATES ITS RECEIVED EXCHANGE -- M5b, 2026-10-02.

  The tokenising gate stays here, contest-blind: an exchange ParseArray cannot
  cut is refused for every shape but the two that allow a blank exchange.
  Then the CONTEST is asked (TContestBase.ParseReceivedExchange), handed the
  session -- its exchange, the shape parser above and two engine services --
  as data. A refusal it names goes where every exchange error goes,
  ExchangeErrorMessage, which ParametersOkay shows exactly as it shows an
  improper county. *)
function ProcessExchange(ExchangeString: Str80; var RData: ContestExchange):
  boolean;
var
  session: TReceivedExchangeSession;
  refusal: string;
begin
  Result := False;
  if (not ParseArray(ExchangeString))                                  and
     (not (ContestSession.Exchange in [RSTNameAndQTHExchange, RSTAndPOTAPark])) then
     begin
     Exit;
     end;

  session.Exchange := ContestSession.Exchange;
  session.ParseShape := @ParseExchangeShape;
  session.ZoneOfCall := @ParseSessionZoneOfCall;
  session.IsDomesticQTH := @ParseSessionIsDomesticQTH;
  session.CallWindowHasCall := CallWindowString <> '';
  session.AbandonEntry := @ParseSessionAbandonEntry;

  Result := ExchangeContest.ParseReceivedExchange(string(ExchangeString),
                                                  session, RData, refusal);
  if refusal <> '' then
     begin
     ExchangeErrorMessage := refusal;
     end;
end;


procedure LogStringToRXData(LogString: Str80; var RXData: ContestExchange);

var
  ExchangeString: ShortString {Str80};

begin
  ExchangeString := GetLogEntryExchangeString(LogString);

  if ExchangeInformation.RST then
     begin
     RemoveFirstString(ExchangeString);
     end;
  logger.debug('Calling ProcessExchange from LogStringToRXData - LogString = (%s)', [LogString]);
  ProcessExchange(ExchangeString, RXData);
end;

procedure ProcessPartialCallAndInitialExchange(RXData: ContestExchange);

begin
  if Settings.CallWindow.PartialCallEnable or Settings.Contest.ExchangeMemoryEnable then // n4af 40.40.1
    //     AddCallToPartialList(RXData.Callsign, GetInitialExchangeStringFromContestExchange(RXData));
     begin
     GetInitialExchangeStringFromContestExchange(RXData); // n4af 40.40.1       }
     end;
end;

procedure CreateAndSendSAPMultiInfoMessage;

begin
  {
    if K1EANetworkEnable then Exit;

    TempString := MultiInfoMessage;

    if TempString = '' then Exit;

    if pos('$', TempString) > 0 then
    begin
      Index := pos('$', TempString);
      Delete(TempString, Index, 1);
      Insert('S&P', TempString, Index);
    end;

    if pos('%', MultiInfoMessage) > 0 then
    begin
      Index := pos('%', TempString);
      Delete(TempString, Index, 1);
      Str(Rate, NumberString);
      Insert(NumberString, TempString, Index);
    end;

    SendMultiInfoMessage(ActiveBand, ActiveMode, TempString);
  }
end;

procedure CreateAndSendCQMultiInfoMessage;

begin
end;

function DomStringParse(InputString: Str14): string;
//Gav 4.44.8     Formats DOM from Initial Exchange to be used for Mult Needed display. Most DOM pass through untouched

(* THE CONTEST'S RULE -- M11 S6 part 1, 2026-10-14. Five arms stood here,
  `if ContestSession.DomesticMult = ...` -- RDA, DOK, IOTA, grid square, grid
  field -- a drifted copy of LOGDOM.GetDomQTH's (plan F6). Each contest
  states its own now (TContestBase.DomesticMultiplierHint, the shared shapes
  in uDomesticKey); every other answers the text itself, as this did for
  every other session. The IOTA arm's scratch use of LOGWIND.ContinentString
  went with it -- nothing read that global -- and the DOK arm's unassigned
  local is transcribed into the two DOK classes, not fixed (F6).

  ONE ActiveContest per hint: its one caller (LOGEDIT's station
  information) asks once per call shown, and holds no contest object. *)
begin
  strU(InputString);
  Result := ContestDomesticMultiplierHint(ActiveContest(Contest), InputString);
end;

function GetSentRSTFromExchangeString(var ExchangeString: OpenString {Str40}):
  smallInt {Word};

var
  PotentialRSTSent: Str80 {40};
  TempString: ShortString {Str40};
  //  RSTString                   : string[3] {Str20};

begin
  GetSentRSTFromExchangeString := 0;

  if not Settings.Log.LookForRstSent then
     begin
     Exit;
     end;

  TempString := ExchangeString;

  while TempString <> '' do
     begin
     PotentialRSTSent := RemoveLastString(TempString);

     if Copy(PotentialRSTSent, 1, 1) = 'S' then
        begin
        Delete(PotentialRSTSent, 1, 1);

        if StringIsAllNumbers(PotentialRSTSent) then
          if LooksLikeRST(PotentialRSTSent, Result, ActiveMode) then
             begin
             GetSentRSTFromExchangeString := Result;

             { Delete all the stuff we have }

             Delete(ExchangeString, 1, length(TempString));

             { Remove the callsign }

             RemoveFirstString(ExchangeString);

             { Rebuild the exchange string without the callsign }

             ExchangeString := TempString + ' ' + ExchangeString;
             Exit;
             end;

        end;
     end;
end;

function SpecAndExchangeMatch(Spec: Str40; Exchange: Str40): boolean;

begin
  SpecAndExchangeMatch := False;
end;

function FoundExchangeFromTemplate(Template: string; ExchangeString: Str40; var
  RData: ContestExchange): boolean;

var
  FormatSpec, Exchange: ShortString;
  TestSpec, TestExchange: Str40;

begin
  FoundExchangeFromTemplate := False;

  FormatSpec := PrecedingString(Template, '|');

  Exchange := ExchangeString;

  while (FormatSpec <> '') and (Exchange <> '') do
     begin
     TestSpec := RemoveFirstString(FormatSpec);
     TestExchange := RemoveFirstString(Exchange);

     if not SpecAndExchangeMatch(TestSpec, TestExchange) then
        begin
        Exit;
        end;
     end;

  { We have found that the format spec and the exchange match up }

end;

function ProcessTemplateExchange(ExchangeString: Str40; var RData:
  ContestExchange): boolean;

var
  Entry: integer;

begin
  ProcessTemplateExchange := False;

  if NumberExchangeTemplates = 0 then
     begin
     Exit;
     end;

  for Entry := 0 to NumberExchangeTemplates - 1 do
    if FoundExchangeFromTemplate(ExchangeTemplateList[Entry]^, ExchangeString,
      RData) then
       begin
       ProcessTemplateExchange := True;
       Exit;
       end;

end;

function GoodLookingRDA(rda: Str20): boolean;

{ Verifies that the grid square is legitimate }

var
  CharPosition: integer;

begin
  result := False;

  if not ((length(rda) = 4)) then
     begin
     Exit;
     end;

  strU(rda);

  for CharPosition := 1 to 4 do
     begin
     case CharPosition of
       1, 2:
         if not (rda[CharPosition] in ['A'..'Z']) then
            begin
            Exit;
            end;

       3, 4:
         if not (rda[CharPosition] in ['0'..'9']) then
            begin
            Exit;
            end;

     end;
     end;

  result := True;
end;

procedure SendUDPRotorCommand(Heading: integer); // ny4i 4.44.9
var
  // msg: TIdBytes;
  sBuf: AnsiString;
  freq: integer;
  sFreqBand: AnsiString;
begin
  case ActiveRadio of
    radioone: freq := Radio1.FilteredStatus.Freq;
    RadioTwo: freq := Radio2.FilteredStatus.Freq;
  else
    freq := 0;
  end; // case

  case freq of
    1800000..1899999: sFreqBand := '1.8';
    3500000..3999999: sFreqBand := '3.5';
    7000000..7999999: sFreqBand := '7';
    10000000..10100000: sFreqBand := '10';
    14201000..14999999: sFreqBand := '14';
    18000000..18999999: sFreqBand := '18';
    21000000..21999999: sFreqBand := '21';
    24000000..24999999: sFreqBand := '24';
    28000000..29999999: sFreqBand := '28';
  else
    sFreqBand := ' ';
  end; // case
  sBuf := '<N1MMRotor>' +
    '<rotor>rotor name</rotor>' +
    '<goazi>' + SysUtils.Format('%0.0d', [Heading]) + '</goazi>' +
    '<offset>0.0</offset>' +
    '<bidirectional>0</bidirectional>' +
    '<freqband>' + sFreqBand + '<freqband>' +
    '</N1MMRotor>';
  (* EVERY DESTINATION SUBSCRIBED TO THE ROTOR STREAM. The two globals this
    replaces were the last readers of the legacy UDP settings, and they had
    already drifted from the rest of the program: the contact, score and
    lookup streams have gone through the broadcaster since 87ad2fc3, so an
    operator who moved their listener in Preferences moved four streams and
    not the other two. *)
  logger.Trace('[SendUDPRotorCommand] N1MM rotor -> %s',   // Issue #989
    [sBuf]);
  UDPBroadcaster.Send(usRotor, sBuf);

end; // SendUDPRotatorCommand

procedure SendPSTRotorCommand(Heading: integer;
                              const IPAddress: string;
                              UDPPort: integer); // Issue #732
// Send an azimuth to PstRotator via its native UDP interface.  PstRotator
// listens on its "UDP Control Port", 12000 by default, at the address the
// CALLER nominates.  Reuses the shared 'udp' Indy client, same as the N1MM
// path above.  Command format per the PstRotator UDP spec:
//   <PST><AZIMUTH>nnn</AZIMUTH></PST>
var
  sBuf: AnsiString;
begin
  sBuf := '<PST><AZIMUTH>' + SysUtils.Format('%d', [Heading]) + '</AZIMUTH></PST>';
  // THE ENDPOINT IS A PARAMETER, not a global this looks up for itself. Reading
  // Settings.Rotator.IpAddress/Settings.Rotator.UdpPort here made the rotator library's own
  // per-definition address unreachable, and two PstRotator hosts inexpressible.
  // The caller nominates the rotator; the transport only sends.
  logger.Trace('[SendPSTRotorCommand] -> %s:%d %s',   // Issue #989
    [IPAddress, UDPPort, sBuf]);
  udp.Send(IPAddress, UDPPort, sBuf);
end; // SendPSTRotorCommand

function ValidClass(sClass: Str10): boolean; // ny4i 4.45.3
var
  factoryError: string;
begin
  (* THE CONTEST DECIDES WHAT ITS CLASS LOOKS LIKE -- phase F, and only the
     contest since M5b (2026-10-02).

     NY4I, 2026-09-02: "Shouldn't this class have a function called
     ValidExchange where we move the exchange rules? Basically, anywhere the
     main program goes through a case statement on the contest type."

     The letter loop that followed the class's answer named both Field Days
     (A-F for ARRL Field Day, I/O/H/M for Winter Field Day) and ran only for a
     contest with NO class -- and the two contests that run this exchange both
     have one (inventory D1). It is deleted: every contest is asked, a
     classless one through its identity, whose base answer accepts any class.
     That differs from the loop only for an operator who states the Field Day
     exchange for a classless contest, which the loop refused. *)
  Result := ExchangeContest.ValidateClass(string(sClass), factoryError);
  if not Result then
     begin
     ExchangeErrorMessage := factoryError;
     end;
end;

(* ---------------------------------------------------------------------------
  THE TWO VALIDATORS, HAND WRITTEN -- AND WHY THEY ARE NOT REGULAR EXPRESSIONS
  ANY MORE (2026-09-17).

  These were RX_GUID and RX_POTA_PARK run through FPC's TRegExpr. They are
  character tests now, because that engine is WRONG on aarch64-darwin and
  wrong in a way that reaches an operator:

      a counted quantifier on a SIMPLE atom -- a{2}, \d{4,5}, [A-Za-z]{2} --
      discards its bounds and behaves as +, so /^a{2}$/ matched 'a', 'aa'
      AND 'aaa'. On a GROUP, (ab){2}, the same construct is correct.

  Measured, not inferred: probes on i386-win32, x86_64-win64 and
  aarch64-darwin, all TRegExpr 0.987, same source. The two Windows targets
  pass every case; the Mac fails six. That split matches the engine's own
  EmitSimpleBraces / EmitComplexBraces fork, so it is an upstream defect and
  not something this tree can spell around -- the grouped rewrite was tried
  and rejects a legitimate five-digit park.

  WHAT IT COST US ON macOS: IsValidPOTAPark ACCEPTED 'U-1234', 'USA-1234' and
  'US-123', and IsValidGUID REJECTED a well-formed GUID. Four live callers
  each -- the POTA reference and SIG_Info on entry, logstuff, tree -- and the
  ADIF import path for the GUID.

  IsValidPOTAPark IS IN uPOTAReference SINCE 2026-10-13, with the two
  character tests only it used, and ResolvePOTAParkFromADIF beside it: POTA's
  class reads both, and a class reads no TRDOS unit. This note stays with
  IsValidGUID, the validator left here.

  FIDELITY IS THE RULE HERE, NOT TIDINESS. These accept exactly what the
  patterns accepted, including their looseness: every hyphen in a GUID is
  INDEPENDENTLY optional, and so is each brace, so '{6B29...' with no closing
  brace still validates. Tightening any of that would change what TR4W
  accepts on Windows, which this rewrite must not do. uTestRegexValidators
  pins both directions.

  RANGE COMPARISONS, NOT `in ['0'..'9']`: this unit's `string` is a
  UnicodeString, so its elements are WideChar, and a WideChar tested against
  an AnsiChar set is the silent size-mismatch this tree has paid for before.
  --------------------------------------------------------------------------- *)

function IsHexDigit(aCh: Char): boolean;
begin
   Result := ((aCh >= '0') and (aCh <= '9')) or
             ((aCh >= 'A') and (aCh <= 'F')) or
             ((aCh >= 'a') and (aCh <= 'f'));
end;

function IsValidGUID(const guid: string): boolean;
var
   idx:  integer;
   last: integer;

   (* Consumes exactly aCount hex digits, or reports failure without moving
     past what it could not take. *)
   function TakeHex(aCount: integer): boolean;
   var
      n: integer;
   begin
      Result := False;
      for n := 1 to aCount do
         begin
         if (idx > last) or (not IsHexDigit(guid[idx])) then
            begin
            Exit;
            end;
         Inc(idx);
         end;
      Result := True;
   end;

   (* Each separator is optional ON ITS OWN, which is what the four `-?` in
     the old pattern meant: fully hyphenated, bare, or mixed all validate. *)
   procedure TakeOptionalHyphen;
   begin
      if (idx <= last) and (guid[idx] = '-') then
         begin
         Inc(idx);
         end;
   end;

begin
   logger.debug('Checking if %s is a valid guid', [guid]);

   Result := False;
   idx    := 1;
   last   := Length(guid);

   if last = 0 then
      begin
      Exit;
      end;

   (* Braces optional and independent of each other -- see the note above. *)
   if guid[idx] = '{' then
      begin
      Inc(idx);
      end;
   if (last >= idx) and (guid[last] = '}') then
      begin
      Dec(last);
      end;

   if not TakeHex(8) then
      begin
      Exit;
      end;
   TakeOptionalHyphen;
   if not TakeHex(4) then
      begin
      Exit;
      end;
   TakeOptionalHyphen;
   if not TakeHex(4) then
      begin
      Exit;
      end;
   TakeOptionalHyphen;
   if not TakeHex(4) then
      begin
      Exit;
      end;
   TakeOptionalHyphen;
   if not TakeHex(12) then
      begin
      Exit;
      end;

   (* The pattern was anchored at both ends, so anything left over fails. *)
   Result := idx > last;

   if Result then
      begin
      logger.debug('%s is a valid GUID', [guid]);
      end;
end;

begin
  CD.CellBuffer.MaximumMemoryToUse := 40000 * ua4wliscpconst {*4 - ua4wli};
  StuffInit;
end.

