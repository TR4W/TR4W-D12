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
unit LogWind;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface
uses
  uConfigValues,   // Config -- migrated settings
  SysUtils,
utils_text,
  uWinKey,
  uMults,
  uCTYDAT,
  uCallsigns,
  TF,
  uCommctrl,
  Messages,
  Version,
  VC,
  uInputQuery,
  LogNet,
  LogGrid,
  LogDom,
  LogRadio,
  LogK1EA, {SlowTree,}
  Tree, {Crt, Dos,}
  LogSCP,
  ZoneCont,
  Windows,
  utils_file,
  BeepUnit,
  uGradient
  ;

const
  tBaseFrequencys                       : array[Band160..Band12] of integer =
    (1000, 3000,  7000, 14000, 21000, 28000, 10000, 18000, 24000);
//T1 : Cardinal = 1800000;
var
  TMult                                 : str10 = ' ';
  BufLine                               : integer = 0;
  ie_check                              : boolean = false;
  tBandMapCutoffFrequency               : integer;
  IE_Switch                             : boolean = False;
  tBandMapPlaceHolder                   : CallString;
  tB4IndicatorPrevState                 : integer;
  tNewMultIndicatorPrevState            : integer;
  tQSOsWithThisStationPrevState         : integer;
  tCountryNamePrevState                 : Word;
  tBeamHeadingPrevState                 : GridString;
  tLocalTimePrevState                   : Word;
  Gate                                  : boolean = False;
  a                                     : cardinal = 0;
  b                                     : cardinal = 0;
  c                                     : cardinal = 0;
  e                                    : cardinal = 0;
  T2                                    : cardinal = 0;
  d2                                    : cardinal = 0;
  d3                                    : cardinal = 0;
 // d4                                    : cardinal = 0;
  Start                                 : boolean = False;
  Save                                  : cardinal = 0;
  d1                                    : cardinal = 0;
  BMp                                   : integer = 0;
  const
  PendingQTCArraySize                   = 600;

  Blink                                 = 128;

  NumberEditableLines                   = 5;
  MaximumReminderRecords                = 100;
  MaxExchangeTemplateEntries            = 20;

  QSOInformationWindowLX                = 55;
  QSOInformationWindowLY                = 4;
  QSOInformationWindowRX                = 80;
  QSOInformationWindowRY                = 7;

  RemainingMultsWindowLX                = 1;
  RemainingMultsWindowLY                = 8;
  RemainingMultsWindowRX                = 54;
  RemainingMultsWindowRY                = 13;

  BigRemainingMultsWindowLX             = 1;
  BigRemainingMultsWindowLY             = 8;
  BigRemainingMultsWindowRX             = 80;
  BigRemainingMultsWindowRY             = 13;

  MultiplierInformationWindowLX         = 55;
  MultiplierInformationWindowLY         = 8;
  MultiplierInformationWindowRX         = 80;
  MultiplierInformationWindowRY         = 12;

  EditableLogWindowLX                   = 1;
  EditableLogWindowLY                   = 14;
  EditableLogWindowRX                   = 80;
  EditableLogWindowRY                   = 18;

  BigWindowLX                           = 1;
  BigWindowLY                           = 2;
  BigWindowRX                           = 80;
  BigWindowRY                           = 18;

type

  TFreqMemoryType = array[BandType, CW..Phone] of LONGINT;

  K5KAStateType = (KAIdle, KAMessageStarted, KASendingMessage);
  K5KAObject = record // Used for fancy stuff with AltD while sending
    AltDString: Str20; // Working string of AltD contents
    CQOrExchangeStarted: boolean; // Tells WindowEditor to do something
    ModeEnabled: boolean; // On/Off switch for this mode
    State: K5KAStateType;
  end;

  RotatorType = (NoRotator, DCU1Rotator, OrionRotator, YaesuRotator, AlfaSpidRotator, PSTRotator); {KK1L: 6.71 Added YaesuRotator} {Issue #732: PSTRotator (UDP)}

  RateBandArrayType = array[Band160..Band10] of Byte;

  SpecialCommandType = (NoSpecialCommand, SendF1Message, AutoAltDSpaceBar);

  //  OpModeType = (CQOpMode, SearchAndPounceOpMode);

  MultiMessage = ^Str80;

  TenMinuteRuleType = (NoTenMinuteRule, TimeOfFirstQSO);

  TenMinuteTimeRecord = record
    Band: BandType;
    Mode: ModeType;
    Time: Cardinal {TimeRecord};
  end;

  UserInfoType = (
    NoUserInfo,
    NameInfo,
    QTHInfo,
    CheckSectionInfo,
    SectionInfo,
    OldCallInfo,
    FocInfo,
    GridInfo,
    CQZoneInfo,
    ITUZoneInfo,
    User1Info,
    User2Info,
    User3Info,
    User4Info,
    User5Info,
    CustomInfo);

  TwoRadioStates = (TwoRadiosDisabled, Idle, CallReady, StationCalled, SendingExchange);

  BandMapEntry = record
    Call: EightBytes;
    Frequency: LONGINT;
    QSXOffset: LONGINT; { + or - offset from Frequency }
    StatusByte: Byte; { Bits 0-5 = # minutes remaining (0-63)
    Bit 6   = Dupe   Bit 7 = Mult   }
//    Band: BandType;
    TelnetSpot: Byte;
    bmBand: BandType;
    bmMode: ModeType;
    NextEntry: Pointer;
    Source: CallString;
  end;

  tr4wBandMapEntry = record

    bmFrequency: LONGINT;
    bmQSXOffset: LONGINT; { + or - offset from Frequency }
    bmCall: CallString;
    bmTelnetSpot: Byte;
    bmMinutesRem: Byte;
    bmDupe: boolean;

    bmSource: CallString;
    bmMult: boolean;
    bmBand: BandType;
    bmMode: ModeType;
  end;

//  BandMapArray = array of {tr4wBandMapEntry} BandMapEntry;

  BandMapEntryPointer = ^BandMapEntry;

  BandMapSplitModeType = (ByCutoffFrequency, AlwaysPhone); {KK1L: 6.64}

  RateDisplayType = (QSOs, Points, BandQSOs);
  HourDisplayType = (ThisHour, LastSixtyMins, BandChanges, BandChangesThisComputer);

  K1EAStationInfoFieldType = (Pass, Run);

  K1EAMultiInfoRecord = record
    RunFreq, PassFreq: LONGINT;
  end;

  TotalScoreMessageRecord = record
    Score: LONGINT;
    MessageString: Str40;
  end;

  KeyerType = (NoKeyer, CPU, MM3);

//  PendingQTCArrayType = array[0..PendingQTCArraySize - 1] of PendingQTCDataType;
//  PendingQTCArrayPtr = ^PendingQTCArrayType;

  QTCDataType = record
    Call: CallString {EightBytes};
    NumberQTCs: Byte {integer};
  end;

  QTCDataArrayType = array[0..500 - 1] of QTCDataType;
  QTCDataArrayPtr = ^QTCDataArrayType;

  WindowType = (NoWindow,
    AlarmWindow,
    AltCallWindow, //KK1L: 6.73
    BandMapWindow,
    BandModeWindow,
    BeamHeadingWindow,
    BigWindow,
    CallWindow,
    ClockWindow,
    CodeSpeedWindow,
    ContestTitleWindow,
    DATEWINDOW,
    DupeInfoWindow,
    DupeSheetWindow,
    EditableLogWindow,
    ExchangeWindow,
    ExtraTimeWindow,
    FreeMemoryWindow,
    FrequencyOneWindow,
    FrequencyTwoWindow, //KK1L: 6.73
    FunctionKeyWindow,
    HourRateWindow,
    InsertWindow,
    MultiplierInformationWindow,
    NamePercentageWindow,
    NameSentWindow,
    POSSIBLECALLWINDOW,
    QSOInformationWindow,
    QSONumberWindow,
    QTCNumberWindow,
    UserInfoWindow,
    CountryNameWindow,
    QUICKCOMMANDWINDOW,
    QuickCommand2Window,
    RadioWindow,
    REMAININGMULTSWINDOW,
    RateWindow,
    RTTYWindow,
    RTTYInverseWindow,
    TotalScoreWindow,
    TotalWindow,
    WholeScreenWindow);

  LogEntryArray = array[1..NumberEditableLines] of string {[100]};

//  RemainingMultList = array[0..MaxNumberRemainingDomQTHs] of boolean;
//  RemainingMultListPointer = ^RemainingMultList;

  ColorRecord = record
    AlarmWindowBackground: tr4wColors;
    AlarmWindowColor: tr4wColors;
    AltCallWindowBackground: tr4wColors; {KK1L: 6.73}
    AltCallWindowColor: tr4wColors; {KK1L: 6.73}

    AutoSendArrowWindowBackground: tr4wColors;
    AutoSendArrowWindowColor: tr4wColors;

    BandMapWindowBackground: tr4wColors;
    BandMapWindowColor: tr4wColors;

    BandModeWindowBackground: tr4wColors;
    BandModeWindowColor: tr4wColors;
    BeamHeadingWindowBackground: tr4wColors;
    BeamHeadingWindowColor: tr4wColors;
    BigWindowBackground: tr4wColors;
    BigWindowColor: tr4wColors;

    CallWindowBackground: tr4wColors;
    CallWindowColor: tr4wColors;
    ClockWindowBackground: tr4wColors;
    ClockWindowColor: tr4wColors;
    CodeSpeedWindowBackground: tr4wColors;
    CodeSpeedWindowColor: tr4wColors;
    ContestTitleWindowBackground: tr4wColors;
    ContestTitleWindowColor: tr4wColors;
    CountryNameWindowBackground: tr4wColors;
    CountryNameWindowColor: tr4wColors;

    DateWindowBackground: tr4wColors;
    DateWindowColor: tr4wColors;
    DupeInfoWindowBackground: tr4wColors;
    DupeInfoWindowColor: tr4wColors;
    DupeSheetWindowBackground: tr4wColors;
    DupeSheetWindowColor: tr4wColors;

    EditableLogWindowBackground: tr4wColors;
    EditableLogWindowColor: tr4wColors;
    ExchangeWindowBackground: tr4wColors;
    ExchangeWindowColor: tr4wColors;
    ExchangeSAndPWindowBackground: tr4wColors;

    FreeMemoryWindowBackground: tr4wColors;
    FreeMemoryWindowColor: tr4wColors;

    FrequencyOneWindowBackground: tr4wColors;
    FrequencyTwoWindowBackground: tr4wColors; {KK1L: 6.73}

//    FrequencyOneWindowHighlight: tr4wColors; {KK1L: 6.73}
//    FrequencyTwoWindowHighlight: tr4wColors; {KK1L: 6.73}

    FrequencyOneWindowColor: tr4wColors;
    FrequencyTwoWindowColor: tr4wColors; {KK1L: 6.73}

    FunctionKeyWindowBackground: tr4wColors;
    FunctionKeyWindowColor: tr4wColors;

    InsertWindowBackground: tr4wColors;
    InsertWindowColor: tr4wColors;

    MultiplierInformationWindowBackground: tr4wColors;
    MultiplierInformationWindowColor: tr4wColors;

    NamePercentageWindowBackground: tr4wColors;
    NamePercentageWindowColor: tr4wColors;
    NameSentWindowBackground: tr4wColors;
    NameSentWindowColor: tr4wColors;

    PossibleCallWindowBackground: tr4wColors;
    PossibleCallWindowColor: tr4wColors;
    PossibleCallWindowDupeBackground: tr4wColors;
    PossibleCallWindowDupeColor: tr4wColors;

    QSOInformationWindowBackground: tr4wColors;
    QSOInformationWindowColor: tr4wColors;

    QSONumberWindowBackground: tr4wColors;
    QSONumberWindowColor: tr4wColors;

    QTCNumberWindowBackground: tr4wColors;
    QTCNumberWindowColor: tr4wColors;
    QuickCommandWindowBackground: tr4wColors;
    QuickCommandWindowColor: tr4wColors;

    RadioOneWindowBackground: tr4wColors; {KK1L: 6.73 Changed from RadioWindowBackground}
    RadioOneWindowColor: tr4wColors; {KK1L: 6.73 Changed from RadioWindowColor}
    RadioTwoWindowBackground: tr4wColors; {KK1L: 6.73}
    RadioTwoWindowColor: tr4wColors; {KK1L: 6.73}

    RateWindowBackground: tr4wColors;
    RateWindowColor: tr4wColors;

    RemainingMultsWindowSubdue: tr4wColors;
    RemainingMultsWindowBackground: tr4wColors;
    RemainingMultsWindowColor: tr4wColors;
    TotalScoreWindowBackground: tr4wColors;
    TotalScoreWindowColor: tr4wColors;
    TotalWindowBackground: tr4wColors;
    TotalWindowColor: tr4wColors;

    UserInfoWindowColor: tr4wColors;
    UserInfoWindowBackground: tr4wColors;

    WholeScreenColor: tr4wColors;
    WholeScreenBackground: tr4wColors;
  end;

  ReminderRecord = record
    Time: integer;
    DateString: string[10];
    DayString: string[10];
    RemMessage: Str80;
    Alarm: boolean;
  end;

  ReminderArray = array[0..MaximumReminderRecords - 1] of ReminderRecord;
  ReminderArrayPointer = ^ReminderArray;

  RateRecord = record
    TotalQSOs: integer {Byte};
    TotalPoints: integer {Byte};
    BandQSOs: RateBandArrayType;
  end;

  StringPointer = ^string;

  InitialExchangeCursorPosType = (AtEnd, AtStart);

  CallWindowPositionType = (NormalCallWindowPosition, UpOneCallWindowPosition);

const
  ZoneMultTypeSA                        : array[ZoneMultType] of PAnsiChar =
    (
    'NONE',
    'CQ ZONES',
    'ITU ZONES',
    'JA PREFECTURES',
    'BRANCH ZONES',
    'EU HFC YEAR',
    'RF CHAMP ZONES'
    );

  TenMinuteRuleTypeSA                   : array[TenMinuteRuleType] of PAnsiChar = ('NONE', 'TIME OF FIRST QSO');

  RotatorTypeSA                         : array[RotatorType] of PAnsiChar = ('NONE', 'DCU1', 'ORION', 'YAESU', 'ALFA SPID', 'PSTROTATOR');

  CallWindowPositionTypeSA              : array[CallWindowPositionType] of PAnsiChar = ('NORMAL', 'UP');

  BandMapSplitModeTypeSA                : array[BandMapSplitModeType] of PAnsiChar = ('BY CUTOFF FREQ', 'ALWAYS PHONE');

  HourDisplayTypeSA                     : array[HourDisplayType] of PAnsiChar = ('THIS HOUR', 'LAST SIXTY MINUTES', 'BAND CHANGES', 'BAND CHANGES ON THIS COMPUTER');

  RateDisplayTypeStringArray            : array[RateDisplayType] of PAnsiChar = ('QSOS', 'QSO POINTS', 'BAND QSOS');

  IECursorPosTypeStringArray            : array[InitialExchangeCursorPosType] of PAnsiChar = ('AT END', 'AT START');

  InitialExchangeTypeStringArray        : array[InitialExchangeType] of PAnsiChar =
    (
    'NONE',
    'NAME',
    'NAME QTH',
    'CHECK SECTION',
    'SECTION',
    'QTH',
    'FOC NUMBER',
    'GRID',
    'ZONE',
    'USER 1',
    'USER 2',
    'USER 3',
    'USER 4',
    'USER 5',
    'CUSTOM'
    );
  UserInfoTypeSA                        : array[UserInfoType] of PAnsiChar =
    (
    'NONE',
    'NAME',
    'QTH',
    'CHECK SECTION',
    'SECTION',
    'OLD CALL',
    'FOC NUMBER',
    'GRID',
    'CQ ZONE',
    'ITU ZONE',
    'USER 1',
    'USER 2',
    'USER 3',
    'USER 4',
    'USER 5',
    'CUSTOM'
    );
var

  k                                     : integer;
  //  BMDrawCounter                    : integer;

  ActiveBackground                      : Byte;
  ActiveBand                            : BandType {= Band160};
  ActiveColor                           : Byte;
  ActiveExchange                        : ExchangeType {= NoExchangeReceived};
  ActiveInitialExchange                 : InitialExchangeType {= NoInitialExchange};
  ActiveMode                            : ModeType = Digital;

  //  ActiveModemPort: PortType;
  ActiveQSOPointMethod                  : QSOPointMethodType {= NoQSOPointMethod};
  ActiveRotatorPort                     : PortType;
  ActiveRotatorType                     : RotatorType {= NoRotator};
  //  ActiveRTTYPort                        : PortType;
  ActiveWindow                          : WindowType;
  ActiveZoneMult                        : ZoneMultType {= NoZoneMults};
  AlarmSet                              : boolean;
  AlarmMinute                           : integer;
  AlarmHour                             : integer;
  AskForFrequencies                     : boolean;
  AutoSAPEnableRate                     : LONGINT = 500;
  AutoSendCharacterCount                : integer;
  AutoSendEnable                        : boolean;
  AutoTimeIncrementQSOs                 : integer;
  AutoTimeQSOCount                      : Byte;

  BandMapSO2RDisplay                    : boolean;
  BandMapAllBands                       : boolean;
  BandMapAllModes                       : boolean;
  BandMapBand                           : BandType {= Band160};
  BandMapMode                           : ModeType {= CW};
  BandMapBlinkingCall                   : CallString;
  BandMapBlinkingCallRecord             : BandMapEntryPointer;
  BandMapCursorData                     : BandMapEntryPointer;
  BandMapCursorFrequency                : LONGINT;
  BandMapDisplayCQ                      : boolean = True;
  BandMapModeCutoffFrequency            : array[Band160..Band2] of LONGINT =
    (
    1840000,
    3700000,
    7100000,
    14100000,
    21150000,
    28300000,
    10150000,
    18110000,
    24930000,
    50100000,
    144200000
    );

  BandMapDecayTime                      : integer = 60;
  BandMapDecayValue                     : integer = 60; {KK1L: 6.65}
  BandMapDecayMultiplier                : integer = 1; {KK1L: 6.65}
  BandMapDupeDisplay                    : boolean = True;
  BandMapEntryInCallWindow              : boolean;
  BandMapFileVersion                    : AnsiChar = '1';
  {KK1L: 6.65 Expanded array to cover all cases to keep BM from going whacko when tuning out of band}
  BandMapFirstEntryList                 : array[Band160..NoBand, CW..FM] of BandMapEntryPointer;
  BandMapGuardBand                      : integer; // = 200;
  BandMapDisplayLimit                   : integer = 164;   //GAV added for centred   bandmap
  BandMapMultsOnly                      : boolean; {KK1L: 6.68}
  BandMapSplitMode                      : BandMapSplitModeType {= ByCutoffFrequency}; {KK1L: 6.64}
  BandMapTotalCalls                     : integer;
  BandMapWindowRY                       : integer;
  BandSave                              : BandType;

//  BandMemory                  : array[RadioType] of BandType;

  CalledFromCQMode                      : boolean = True; {KK1L: 6.73}
  CallLastTimeIWasHere                  : CallString; {KK1L: 6.73 Used in LOGSUBS2 to trigger band map info update}
  CallWindowPosition                    : CallWindowPositionType {= NormalCallWindowPosition};

  CommandUseInactiveRadio               : boolean; {KK1L: 6.73}
  ContactsPerPage                       : integer = 50;
  ContinentString                       : Str20;
  //  tr4w_contest                          : string;

  ContestName                           : Str80; {KK1L: 6.68 shortened from Str80}
  ContestTitle                          : ShortString;
  ContinentQSOCount                     : array[BandType, ContinentType] of Word;
  ControlBMemory                        : CallString;
  CountryString                         : Str20;
  //   CQMenu                          : Str80;
  CustomInitialExchangeString           : Str40; {KK1L: 6.67 was Str80;}
  CustomUserString                      : Str40; {KK1L: 6.68 shortened from Str80}
  CWEnabled                             : boolean  = True;
 // CWByCAT                               : boolean  = False;   // ny4i 4.44.5

  DigitalModeEnable                     : boolean;

  DisplayBandMapEnable                  : boolean = True; {KK1L: 6.73}
  DisplayedCodeSpeed                    : Byte;

//  DVPEnabled                            : boolean = True;
  DXMultLimit                           : integer = 32766; {KK1L: 6.65}

//  EditableLogDisplayed                  : boolean;
  EscapeFromEditBandMap                 : boolean;
  NeedToSynchBandMap                    : boolean = True; {KK1L: 6.69}
  //   EightBitRTTYPort                : boolean;
     //   ExchangeFunctionKeyMenu         : Str80;
  ExchangeTemplateList                  : array[0..MaxExchangeTemplateEntries - 1] of StringPointer;
  ExchangeWindowCursorPosition          : Byte;

  //   FirstDisplayableBandMapFrequency: LONGINT; {KK1L: 6.64}
  FirstDisplayedBandMapColumn           : integer; {KK1L: 6.64 allows tracking of bandmap display overflow}
  //  FirstDisplayedBandMapFrequency   : LONGINT; {KK1L: 6.64}

    {KK1L: 6.65 Made FoundCursor global. DisplayBandMap will set false if not within guardband}
  FoundCursor                           : boolean;

  FrequencyDisplayed                    : boolean;

  tFrequencyMemory                      : integer;

  FreqMemory                            : TFreqMemoryType;

  DefaultFreqMemory                     : TFreqMemoryType =
    (
    (0001820000, 1840000, 0001840000),
    (0003525000, 3580000, 0003850000),
    (0007025000, 7040000, 0007070000),
    (0014025000, 14080000, 0014225000),
    (0021025000, 21080000, 0021300000),
    (0028050000, 28080000, 0028400000),

    (0010105000, 10125000, 0010105000),
    (0018068000, 18110000, 0018110000),
    (0024890000, 24920000, 0024930000),
    (0050125000, 50125000, 0050125000),
    (0144100000, 144200000, 0144200000),
    (0222100000, 0, 0222100000),
    (0433100000, 0, 0433200000),
    (0902000000, 0, 0902000000),
    (1296200000, 0, 1296200000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000),
    (0000000000, 0, 0000000000)
    );

  FrequencyMemoryEnable                 : boolean = True;
  FreqPollRate                          : integer = 10; {KK1L: 6.71a Frequency Poll Rate in milliseconds}
  GridSquareListShown                   : boolean;

  HourDisplay                           : HourDisplayType {= ThisHour};

  tHandLogMode                          : boolean;
  InactiveSwapRadio                     : boolean;  // n4af 4.41.3
  IncrementTimeEnable                   : boolean;
  InEditBandMap                         : boolean; {KK1L 6.65}
  InitialExchangeCursorPos              : InitialExchangeCursorPosType { = AtEnd};

  JustLoadingBandMapWithNoRadio         : boolean; {KK1L: 6.68}

  K1EAMultiInfo                         : array[Band160..Band10] of K1EAMultiInfoRecord;

  K5KA                                  : K5KAObject {= (AltDString: ''; State: KAIdle)};
//  K5KAAltDString                        : Str20;

  LastCQFrequency                       : LONGINT;
  LastSPFrequency                       : LONGINT;

  LastCQMode                            : ModeType {= CW};
  LastSPMode                            : ModeType {= CW};
  //  LastDisplayableBandMapFrequency  : LONGINT; {KK1L: 6.64}
  LastDisplayedBand                     : BandType = NoBand;
  //  LastDisplayedBandMapFrequency    : LONGINT; {KK1L: 6.64}
    //  LastDisplayedDate                     : Str20;
  LastDisplayedFMMode                   : boolean;
//  LastDisplayedFreq           : array[RadioType] of LONGINT; {KK1L: 6.73}
  LastDisplayedMode                     : ModeType {= NoMode};
  //  LastDisplayedTime                     : Str20;
  //  LastDisplayedHour                     : Str20;
  LastEditedBandMapEntry                : integer;
  LastFullTimeString                    : Str20;
  LastSecond100                         : Word {= 0}; {KK1L: 6.71a Will store the hundredths of seconds since UpdateTimeAndRateDisplays }
  {           was called. Used to support wicked fast radio checking               }
  LastHeadingShown                      : integer;
//  LastQTCTimeSent                  : Str20;
//  LogConfigFileName           : string {Str80};
//  LogFileName                           : string {40};

//  LogRestartFileName          : string;
  LogSubTitle                           : Str40; {KK1L: 6.68 shortened from Str80}
  //  LogTempFileName                       : string {Str40};

  MaximumDisplayableRemainingMults      : Byte;
  MaxNumberOfZones                      : integer;
  MinutesSinceLastBMUpdate              : integer; {KK1L: 6.65}

  //  ModeMemory                        : array[RadioType] of ModeType;
  //  MonoColors                        : ColorRecord;
  //  MouseEnable                       : boolean;
  MultiInfoMessage                      : Str20;
//  MultiStatus                           : array[BandType, ModeType] of MultiMessage;
  MultipleBandsEnabled                  : boolean = True;
  MultipleModesEnabled                  : boolean = True;

  MyCall                                : CallString;
  DEPlusMyCall                          : Str160;
  MyCheck                               : Str10; {KK1L: 6.67 Was Str20}
  MultiplierItemWidth                   : integer = 40; // 4.91.4
  MyContinent                           : ContinentType {= UnknownContinent};
  MyCountry                             : Str20;
  MyZone                                : Str20; //ZoneMultiplierString;
  MyContinentIsSet                      : boolean;
  MyCountryIsSet                        : boolean;
  MyZoneIsSet                           : boolean;

//  MyZoneCustom                          : ZoneMultiplierString;

  //MyCounty                              : Str20 = '';
  MyFDClass                             : Str10;
  MyFOCNumber                           : Str10;
  MyName                                : Str20;
  MyPark                                : Str10;
  MyPostalCode                          : Str20;
  MyPrec                                : Str10; {KK1L: 6.67 Was Str20}
  MySection                             : Str10; {KK1L: 6.67 Was Str20}
  MyState                               : Str20; {KK1L: 6.67 Was Str20}

  NoMultMarineMobile                    : boolean; {KK1L: 6.68 Added for WRTC 2002 as flag to not count /MM or /AM as mults or countries}
  NumberBandMapEntries                  : integer; {KK1L: 6.64 needed a global version of NumberVisibleBMEntries}

  NumberBandQSOsThisMinute              : RateBandArrayType;

  NumberContactsThisMinute              : integer;
  NumberExchangeTemplates               : SHORTINT;
  NumberQSOPointsThisMinute             : integer;

  NextQTCToBeAdded                      : integer;
//  NextQTCToBeSent                  : integer;
  NumberQTCBooksSent                    : integer;
  NumberQTCStations                     : integer;

  NumberReminderRecords                 : Byte;
  NumberTotalScoreMessages              : Byte;

  OkayToPutUpBandMapCall                : boolean = True;
  OnDeckCall                            : CallString;
  OpMode                                : OpModeType;
  OpMode2                               : OpModeType;

  PacketAddLF                           : boolean;
  PacketMessMode                        : boolean;
  PacketReturnCount                     : integer = 2;
  PacketReturnPerMinute                 : integer;
  PacketSpotComment                     : Str20; {KK1L: 6.68 Need to change when added to LOGCFG.DAT read.}
//  PendingQTCArray                  : PendingQTCArrayPtr;
  //  PrefixInfoFileName               : String='';

  QSOPointsDomesticCW                   : integer = -1;
  QSOPointsDomesticPhone                : integer = -1;
  QSOPointsDXCW                         : integer = -1;
  QSOPointsDXPhone                      : integer = -1;

  QTCDataArray                          : QTCDataArrayPtr;
  QTCsEnabled                           : boolean;
  QTCMinutes                            : boolean;

  RadioOnTheMove                        : array[RadioType] of boolean; {KK1L: 6.73 slowly changing over to arrayed radio varibles}
  RadioMovingInBandMode                 : array[RadioType] of boolean; {KK1L: 6.73}

//  RadioOneName                : string[10] = 'Rig 1';
//  RadioTwoName                : string[10] = 'Rig 2';

  Rate                                  : integer;
  RateDisplay                           : RateDisplayType {= QSOs};
  RateMinuteArray                       : array[1..60] of RateRecord;
  //   ReminderPostedCount             : integer;
  Reminders                             : ReminderArrayPointer;

 S2SW                                   : boolean = False;


  SCPDupeBackground                     : tr4wColors = trCyan;
  SCPDupeColor                          : tr4wColors = trRed;

  ScreenHeight                          : integer;
  SearchAndPounceMode                   : boolean;
  SelectedColors                        : ColorRecord;
  SendAltDSpotsToPacket                 : boolean;
  SCount                                : integer = 0;
  SpecialCommand                        : SpecialCommandType {= NoSpecialCommand};
  SplitFreq                             : LONGINT;
  Spotcnt                               : integer = 0;
//  SpeedMemory                 : array[RadioType] of integer; {KK1L: 6.73}
  SpeedString                           : Str10; {KK1L: 6.73}

  SprintQSYRule                         : boolean;

  StartingFrequencies                   : array[BandType] of LONGINT =
    (
    1800000,
    3500000,
    7000000,
    14000000,
    21000000,
    28000000,

    10000000,
    18000000,
    24000000,
    50000000,
    144000000,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0
    );

  //  StoppingFrequencies                   : array[BandType] of LONGINT;
  //  SuperDupeSheet                        : boolean;
  SuperDupeSheetWindowRY                : integer;

  TenMinuteRule                         : TenMinuteRuleType {= NoTenMinuteRule};
  TenMinuteTime                         : TenMinuteTimeRecord = (Band: NoBand; Mode: NoMode);
  TimeSpentByBand                       : array[BandType] of integer;

  tThisHourBandChanges                  : integer;
  tThisHourPreviousBand                 : BandType {= NoBand};
  TotalThisHour                         : integer;
  TotalLastSixty                        : integer;

  TotalScoreMessages                    : array[0..10] of TotalScoreMessageRecord;
  //  TRFree                                : boolean;
  TwoRadioState                         : TwoRadioStates {= TwoRadiosDisabled};
  TuneDupeCheckEnable                   : boolean; {KK1L: 6.73}

  UnknownCountryFileName                : ShortString {= 'UNKNOWN.CTY'};
  UserInfoShown                         : UserInfoType {= NoUserInfo};

  //   VGADisplayEnable                : boolean;
  VHFBandsEnabled                       : boolean;
  VisibleDupeSheetChanged               : boolean = True;
  //   VisibleDupesheetEnable          : boolean;
  VisibleDupeSheetRemoved               : boolean;

  WakeUpTimeOut                         : integer;
  WakeUpCount                           : Byte;
  WARCBandsEnabled                      : boolean;
//  WideFreqDisplay                  : boolean; {KK1L: 6.73}

  DisplayedFreq                         : Str10; {wli}

  TourDuration                          : integer;
  //   tUpdateWindow                   : boolean;

procedure ActivateExchangeWindow;

procedure AddBandMapModeCutoffFrequency(Freq: LONGINT);



procedure AddBandMapPlaceHolder; {KK1L: 6.65}

//procedure AddQSOToPendingQTCList(Time: integer; Call: CallString; QSONumber: integer);

// THE BAND MAP IS ON WHEN ITS WINDOW IS OPEN.  Was a boolean global, and it
// was also the storage of the setting BAND MAP ENABLE -- two jobs, one
// variable.  WM_DESTROY set it False, so CLOSING THE WINDOW TURNED THE SETTING
// OFF and the next settings save persisted that.  NY4I's store held
// "BAND MAP ENABLE" : "FALSE" on 2026-08-22 and the band map was dead on every
// start, with spots arriving (FCount=49) and every one refused at the gate.
//
// The 4.01 manual says the setting "determines whether the bandmap is
// displayed", and warns you must restart "for it to be in the correct video
// mode to display the bandmap" -- a DOS artifact with no meaning here.  So the
// setting and the window were always the same fact, and this is the one that
// cannot go stale.  The command is retired to csRem in uCFG.pas (2026-08-22),
// following the CUSTOM CARET precedent.
function BandMapEnable: boolean;

function BandMapExpandedString(Call: EightBytes): CallString;


procedure ClearAutoSendDisplay;
procedure DecrementQTCCount(Call: CallString; Count: integer);
procedure DisplayAutoSendCharacterCount;

procedure DisplayBandMap;
procedure DisplayLocalTime(Country: Word);
//procedure DisplayQuickMemoryMode;

// The frequency a band change to `Band` would actually tune: the last one used
// there, or the built-in default for a band not yet visited.  Exported because
// BandChange needs it to ask the radio whether it can transmit on that band --
// see LOGSTUFF.RadioCanWorkBand.
function EffectiveBandFreq(Band: BandType; Mode: ModeType): longint;

procedure DisplayBandMode(Band: BandType; Mode: ModeType; UpdateRadio: boolean);
procedure DisplayBeamHeading(Call: CallString; Grid: GridString);
procedure DispalyGrid(Grid: GridString);

procedure DisplayCodeSpeed {(WPM: integer;
SendingEnabled: boolean;
DVPEnabled: boolean;
Mode: ModeType)};

procedure DisplayContestTitle;
procedure DisplayCountryName(Call: CallString);
procedure DisplayQSOsWithThisStation(QSOs: integer);
//procedure DisplayCT1BOHData;
//procedure DisplayEditableLog(EditableLog: LogEntryArray);
//procedure DisplayFreeMemory;
//procedure DisplayFrequency(Freq: LONGINT; Radio: RadioType); {KK1L: 6.73 Added Radio}
procedure DisplayFrequency(RSR: RadioStatusRecord {Freq: LONGINT}; Radio: RadioType);
procedure DisplayInsertMode;
procedure DisplayNamePercentage({TotalNamesSent: integer; QSONumber: integer});
procedure DisplayNextQSONumber {(QSONumber: integer)};
//procedure DisplayPossibleCalls(Call: CallString);
//procedure DisplayPrefixInfo(Prefix: Str20);
procedure DisplayQTCNumber(QTCNumber: integer);
procedure DisplayRadio(Radio: RadioType);
procedure DisplayRate(Rate: Cardinal);
procedure DisplayQSOsByOpMode;
procedure DisplayHour;

//procedure DisplayRemainingMults({RemainingMults: RemainingMultListPointer;}RemMultDisplay: RemainingMultiplierType);
//procedure DisplayAdditionalRemainingMults;
procedure DisplayTotalScore {(Score: LONGINT)};
procedure DisplayUserInfo(Call: CallString);

{KK1L: 6.64 Created procedure because I needed to get this info more than once}
procedure GetBandMapBandModeFromFrequency(Frequency: LONGINT;
  var Band: BandType;
  var Mode: ModeType);

{KK1L: 6.64 created a function for this step used in EditBandMap}
function GetRecordForBandMapCursor(var Entry: BandMapEntryPointer;
  CursorEntryNumber: integer): boolean;

procedure IncrementTime(Count: integer);
procedure tCalculateRate();
procedure LoadBandMap;
procedure LookForOnDeckCall(var ExchangeString: OpenString {Str80});
procedure NextBandMapEntry ;
procedure BMFirst;
function NextNonDupeEntryInBandMap(Band: BandType; Mode: ModeType): boolean;
function NextMultiplierEntryInBandMap(Band: BandType; Mode: ModeType): boolean; {KK1L: 6.68}
{KK1L: 6.64 created to allow traversal of entrire displayed bandmap}
function NextNonDupeEntryInDisplayedBandMap(Band: BandType; Mode: ModeType): boolean;
function NextMultiplierEntryInDisplayedBandMap(Band: BandType; Mode: ModeType): boolean; {KK1L: 6.68}


//function PopNextQTCToBeSent(var FullString: string; tQTCNR: integer): Str80;

//procedure PutUpCQMenu;
//procedure PutUpExchangeWindow;

procedure SetTextInQuickCommandWindow(Text: string);
procedure ClearQuickDisplayText;
procedure QuickDisplay(Prompt: string);

procedure QuickDisplayError(Prompt: string);

function QuickEditInteger(Prompt: PAnsiChar {str80}; MaxInputLength: integer): LONGINT;
function QuickEditFreq(Prompt: PAnsiChar {str80}; MaxInputLength: integer): LONGINT;
function QuickEditReal(Prompt: PAnsiChar {str80}; MaxInputLength: integer): REAL;
function QuickEditResponse(Prompt: PAnsiChar {str80}; MaxInputLength: Byte): ShortString;

//procedure RemoveAndRestorePreviousWindow;
//procedure RemoveWindow(WindowName: WindowType);
//procedure ResetBandMapTimes; {KK1L: 6.70}
//procedure ResetBandMapDupes;
procedure ResetSavedWindowListAndPutUpCallWindow;
//procedure RestorePreviousWindow;

//procedure SaveActiveWindow;
procedure SaveBandMap;
procedure SetColor(Color: integer);
//procedure SaveAndSetActiveWindow(WindowName: WindowType);
//procedure SaveSetAndClearActiveWindow(WindowName: WindowType);
procedure SetUpBandMapEntry(BandMapData: BandMapEntryPointer; Radio: RadioType); {KK1L: 6.73 Added Radio}
//procedure SetWindow(WindowName: WindowType);
//procedure SetActiveWindow(WindowName: WindowType); { Does not clear window }
{wli}

//function TotalNumberQTCsProcessed: integer;
var
  TotalNumberQTCsProcessed              : integer;
//function TotalPendingQTCs: integer;

procedure UpdateBlinkingBandMapCall;

procedure UpdateK1EAStationInfo(Field: K1EAStationInfoFieldType;
  StationIDChar: AnsiChar;
  MessageString: ShortString {Str20});

procedure UpdateTenMinuteDate(Band: BandType; Mode: ModeType);

procedure UpdateTimeAndRateDisplays(ShowTime: boolean; DoRadios: boolean);
procedure WindInit;

procedure DispalayLogGridLines;
procedure DispalayB4(nCmdShow: integer);
procedure DispalayDupe;
procedure DispalayNewMult(nCmndShow: integer);
procedure tDisplayAutoCQStatus;

procedure tDispalyPaddleAndFootSwitchStatus;
procedure tDisplayCQTotal;
procedure tDispalyOnAirTime;
procedure tDispalyMyComputerID;
procedure tDispalyTimeFromLastQSO;
function CQLabel(Callsign: CallString): boolean;
procedure tSetStartStopBandMode;
procedure DisplayCountryInformation(FileName: Str80; Call: CallString);
procedure FlashQickDisplay;
procedure ShowTourDuration;
procedure DisplayAutoQSLInterval;
procedure SetListViewColor(Window: TMainWindowElement);

{ WHICH ELEMENTS ARE LIST VIEWS, recorded by the one routine that makes them.

  CreateListView adds itself here.  Nothing else should: the point is that the
  fact is stated by the code that knows it, so it cannot drift the way a list
  written out somewhere else would.

  RefreshMainWindowColors is the reader -- see there for why it has to know. }
var
   ListViewElements: set of TMainWindowElement = [];

// Put a changed set of element colours on screen NOW.  See the implementation
// for why an InvalidateRect alone is not enough.
procedure RefreshMainWindowColors;
procedure UpadateMainWindow;
procedure UpadateAutoSend;
//function GetInitialExchangeFromString(CMD: pShortString): InitialExchangeType;
//procedure write_in_BM(s1, s2: string);

implementation

uses
  //  OZCHR,
//  uStack,
  uNet,
  uMP3Recorder,
//  uRemMults_DX,
//  uRemMults_DOM,
//  uRemMults_Zone,
  uStations,
  uSpots,
  uRemMults,
 // uReminder,
  uFunctionKeys,
  LogPack,
  uTelnet,
  uBandmap,
  MainUnit,
  LogEdit,
  uTotal,
  LogCW,
  LogStuff,
  PostUnit,
  LogDupe;


type
  SavedWindow = record
    CursorX: integer;
    CursorY: integer;
    UpperLeftCorner: Word;
    LowerRightCorner: Word;
    Color: integer;
    Background: integer;
    SavedActiveWindow: WindowType;
  end;

var
  //Band                                  : BandType;
 // Continent                             : ContinentType;

  //DupeSheetWindowX                      : integer;
  //DupeSheetWindowY                      : integer;

  NumberMinutesProgramRunning           : integer;

//  Radio1InquireCount               : integer;
//  Radio2InquireCount               : integer;

//  Radio1PollCount                  : integer;
//  Radio2PollCount                  : integer;

  //SavedWindowList                       : array[0..12] of SavedWindow;

  StartBand, StopBand                   : BandType;
  StartMode, StopMode                   : ModeType;

procedure LookForOnDeckCall(var ExchangeString: OpenString {Str80});

var
  TempString, WordString                : Str40;

begin
  OnDeckCall := '';

  if pos(' /', ExchangeString) > 0 then
     begin
     TempString := '';

     while length(ExchangeString) > 0 do
        begin
        WordString := RemoveFirstString(ExchangeString);

        if Copy(WordString, 1, 1) <> '/' then
           begin
           TempString := TempString + WordString + ' '
           end
        else
           begin
           OnDeckCall := WordString;
           Delete(OnDeckCall, 1, 1);
           end;
        end;

     ExchangeString := TempString;
     Exit;
     end;

  { Added in 6.61 }

  if Copy(ExchangeString, 1, 1) = '/' then
     begin
     OnDeckCall := RemoveFirstString(ExchangeString);
     Delete(OnDeckCall, 1, 1);
     end;
end;

function BandMapExpandedString(Call: EightBytes): CallString;

var
  TempString                            : CallString;

begin
  TempString := BigExpandedString(Call);

  while pos(' ', TempString) > 0 do
     begin
     TempString[pos(' ', TempString)] := '/';
     end;

  BandMapExpandedString := TempString;
end;

procedure DisplayFrequency(RSR: RadioStatusRecord {Freq: LONGINT}; Radio: RadioType); {KK1L: 6.73 Added Radio switch}

var
  TempFreq                              : REAL;
  TempString                            : string[40];
  ch                                    : AnsiChar;

begin
  ch := '.';
//  if (RSR.Freq = LastDisplayedFreq[RadioOne]) and (Radio = RadioOne) then    Exit; {KK1L: 6.73 Added Radio}
//  if (RSR.Freq = LastDisplayedFreq[RadioTwo]) and (Radio = RadioTwo) then    Exit; {KK1L: 6.73}

//  LastDisplayedFreq[Radio] := RSR.Freq;

  case Radio of {KK1L: 6.73}
    RadioOne:
      begin

        {            IF ActiveRadio = RadioOne THEN
                        SetColor (SelectedColors.FrequencyOneWindowHighlight)
                    ELSE
                        SetColor (SelectedColors.FrequencyOneWindowColor);
        }
      end;

    RadioTwo:
      begin

        {            IF ActiveRadio = RadioTwo THEN
                        SetColor (SelectedColors.FrequencyTwoWindowHighlight)
                    ELSE
                        SetColor (SelectedColors.FrequencyTwoWindowColor);
        }
      end;
  end;

  TempString := IntToStr(RSR.VFO[VFOA].Frequency);
  Insert(ch, TempString, length(TempString) - 2);
  //   RIF.R1VFOA . Caption := TempString + ' kHz';

  TempString := IntToStr(RSR.VFO[VFOB].Frequency);
  Insert(ch, TempString, length(TempString) - 2);
  //   RIF.R1VFOB . Caption := TempString + ' kHz';

  if RSR.Freq <> 0 then
     begin
     TempFreq := RSR.Freq div 100;
     RSR.Freq := Trunc(TempFreq);
     TempString := '.';
     DisplayedFreq := IntToStr(RSR.Freq);
     Insert(TempString, DisplayedFreq, length(DisplayedFreq) - 0);
       //   t.label10 . Caption := DisplayedFreq; // + ' kHz';
 //    length(IntToStr(RSR.Freq));
     FrequencyDisplayed := True;
     end
  else
    if FrequencyDisplayed then
       begin
       FrequencyDisplayed := False;
       end;

end;

procedure DispalyGrid(Grid: GridString);
begin
  Grid[5] := #0;
  // Grid is a GridString -- a ShortString -- so PAnsiChar(@Grid[1]) read past
  // its length into whatever followed.  See the radio-name fix (56a8ae97).
  SetMainWindowText(mweLocator, string(Grid));
//windows.CopyMemory(@TempBuffer1,
{  asm
  mov eax,Grid
  mov dword ptr TempBuffer1,eax
  end;
  TempBuffer1[4] := #0;
  Windows.SetWindowTextA(LocatorWindowHandle, @TempBuffer1);
}
end;

procedure DisplayBeamHeading(Call: CallString; Grid: GridString);

var
  Heading, Distance{, Country}            : integer;
  HeadingString, DistanceString         : Str20;
  HisGrid                               : GridString;
  CountryID                             : DXMultiplierString; //string[CallstringLength] {20};
  Lat, Lon                              : REAL;
  TempString                            : Str40;

begin
  if MyGrid <> '' then
     begin

     if Grid <> '' then
        begin
        HisGrid := Grid
        end
     else
        begin
        HisGrid := ctyGetGrid(Call, CountryID);
        end;

     if HisGrid = '' then Exit;

     if tBeamHeadingPrevState = HisGrid then Exit;
     tBeamHeadingPrevState := HisGrid;

 //    tSetWindowText(LocatorWindowHandle, 'string(HisGrid)');
     DispalyGrid(HisGrid);
     if Call = MyCall then
        begin
        GetLatLon(MyGrid, Lat, Lon)
        end
     else
        begin
        GetLatLon(ctyGetGrid(Call, CountryID), Lat, Lon);
        end;

       //       SaveSetAndClearActiveWindow (BeamHeadingWindow);

     if HisGrid <> '' then
        begin
        Heading := round(GetBeamHeading(MyGrid, HisGrid));

        LastHeadingShown := Heading;

        Str(Heading, HeadingString);

        Windows.ZeroMemory(@TempString, SizeOf(TempString));
        TempString := CountryID + '   ' + HeadingString + '';

        if DistanceMode <> NoDistanceDisplay then
           begin
           Distance := GetDistanceBetweenGrids(MyGrid, HisGrid);

           if DistanceMode = DistanceMiles then
              begin
              Distance := round(Distance / 1.609344);
              Str(Distance, DistanceString);
              DistanceString := DistanceString + 'm';
              end
           else
              begin
              Str(Distance, DistanceString);
              DistanceString := DistanceString + 'km';
              end;

           TempString := TempString + '   ' + DistanceString;
           end;

        TempString := TempString + '   ' + GetSunriseSunsetString(Lat, Lon);
        end
     else
        begin
        TempString := TC_UNKNOWNCOUNTRY;
        end;

       //        WHILE Length (TempString) < (BeamHeadingWindowRX - BeamHeadingWindowLX) DO
       //            TempString := ' ' + TempString;

     // TempString is a Str40 local; same ShortString hazard.
     SetMainWindowText(mweBeamHeading, string(TempString));
       //        Showmessage (TempString);
       //        RestorePreviousWindow;
     end;
end;

procedure SetColor(Color: integer);

begin
  //    ActiveColor := Color;
  //    TextColor (Color);
end;



function EffectiveBandFreq(Band: BandType; Mode: ModeType): longint;
begin
  // FreqMemory holds the last-used frequency per band/mode and is 0 until a
  // band has been visited. Fall back to the built-in DefaultFreqMemory so a
  // band change to an un-visited band tunes to that band's default instead of
  // 0 Hz (which the radio rejects). Microwave rows with no default stay 0 and
  // are caught by the freq<=0 guard in SetRadioFreq.
  Result := FreqMemory[Band, Mode];
  if Result = 0 then
     begin
     Result := DefaultFreqMemory[Band, Mode];
     end;
end;

procedure DisplayBandMode(Band: BandType; Mode: ModeType; UpdateRadio: boolean);
begin

  if (Band = LastDisplayedBand) and
    (Mode = LastDisplayedMode)
    //    and (FMMode = LastDisplayedFMMode)
  then
     begin
     Exit;
     end;

  LastDisplayedBand := Band;
  LastDisplayedMode := Mode;  
  //  LastDisplayedFMMode := FMMode;

  UpdateTotals2;

  TF.Format(wsprintfBuffer, TWO_STRINGS, BandStringsArray[Band], ModeStringArray[Mode]);

  SetMainWindowText(mweBandMode, wsprintfBuffer);

  if MultByBand then MultBand := ActiveBand else MultBand := AllBands;
  if MultByMode then MultMode := ActiveMode else MultMode := Both;

         { Update the band output port for this radio }

  ActiveRadioPtr.BandMemory {BandMemory[ActiveRadio]} := Band; {UA4WLI: 2.26}
  ActiveRadioPtr.ModeMemory {ModeMemory[ActiveRadio]} := Mode; {UA4WLI: 2.26}

  wkSetKeyerOutput(ActiveRadioPtr);

  if ActiveRadio = RadioOne then
     begin
     Radio1.UpdateBandOutputInfo(Band, Mode);
     if UpdateRadio then
        begin
        Radio1.SetRadioFreq(EffectiveBandFreq(Band, Mode), ActiveMode, 'A');
        end;
     end
  else
     begin
     Radio2.UpdateBandOutputInfo(Band, Mode);
     if UpdateRadio then
        begin
        Radio2.SetRadioFreq(EffectiveBandFreq(Band, Mode), ActiveMode, 'A');
        end;
     end;
  UpdateAllStationsList;
  SendStationStatus(sstBandModeFreq);
end;

procedure DisplayContestTitle;
begin
  TF.Format(wsprintfBuffer, TR4W_CURRENTVERSION + ' - %s'{$IF tDebugMode} + ' - DEBUG MODE'{$IFEND}, @ContestTitle[1]);
  Windows.SetWindowTextA(tr4whandle, wsprintfBuffer);
end;

procedure DisplayCodeSpeed {(WPM: integer; SendingEnabled: boolean; DVPEnabled: boolean; Mode: ModeType)};
var
  tPChar                                : PAnsiChar;
begin
  DisplayedCodeSpeed := CodeSpeed;
  if ActiveMode = CW then
     begin
     // CW-state desync fix: show the ACTUAL transmit gate (CWEnabled), not
     // Config.CWEnable OR CWEnabled.  The OR let a stale Config.CWEnable mask a disabled gate,
     // so the display read "WPM" while Enter sent nothing.  Config.CWEnable and
     // CWEnabled are now kept in step at config load (see ReadInConfigFile), so
     // this matches Config.CWEnable too -- but keying off the gate the sender checks
     // means the UI can never claim CW is on when it will not transmit.
     if CWEnabled then
        begin
        tPChar := '%u WPM';
        end
     else
        begin
        tPChar := '%u NO CW';
        end;
     TF.Format(wsprintfBuffer, tPChar, CodeSpeed);
     SetMainWindowText(mweCodeSpeed, wsprintfBuffer);
     ActiveRadioPtr.SpeedMemory := CodeSpeed;
     end;

  if ActiveMode in [Phone, FM] then
     begin
     if Config.DVKEnable then
        begin
        if DVPOn then
           begin
           tPChar := 'DVK ON'
           end
        else
           begin
           tPChar := 'DVK OFF';
           end;
        end
     else
        begin
        tPChar := 'DVK Dis.';
        end;
     SetMainWindowText(mweCodeSpeed, tPChar);
     end;


    //        RestorePreviousWindow;
  //      end;

  {IF ActiveRadio = RadioOne THEN  }
  {    RadioOneSpeed := WPM        }
  {ELSE                            }
  {    RadioTwoSpeed := WPM;       }

  //  end;

  //  tSetWindowText(CodeSpeedWindowHandle, TempString);
  //end;
  //procedure DisplayFreeMemory;

  //begin
   {    SaveSetAndClearActiveWindow (FreeMemoryWindow);
       Write ('Mem =', MemAvail:7);
       RestorePreviousWindow;
  }
end;


procedure DisplayInsertMode;
const
  InsertModeStringArray                 : array[boolean] of PAnsiChar = (TC_OVERRIDE, TC_INSERT);
begin
  SetMainWindowText(mweInsert, InsertModeStringArray[InsertMode]);
end;

procedure DisplayNamePercentage({TotalNamesSent: integer; QSONumber: integer});

//var
  //Percentage                            : REAL;
  //TNS                                   : integer;
begin
{
  if (TotalContacts > 0) and Config.SayHiEnable then
  begin
    TNS := TotalNamesSent ;
    Percentage := TNS / TotalContacts;
    Percentage := Percentage * 100;
      //    SaveSetAndClearActiveWindow(NamePercentageWindow);
      //    SetTR4WWindowText(NameSentWindowHandle, IntToStr(Trunc(Percentage))+' %');
      //    Write(' ', Percentage: 3: 1, '%');
      //    RestorePreviousWindow;
  end;
}
end;

procedure DisplayNextQSONumber;
const
  QSONumberStringArray                  : array[boolean] of PAnsiChar = ('%d', '*%d');   
begin
  // Issue #954: show the next serial we will actually send (high-water mark of
  // numbers sent + 1), NOT a QSO count.  Count-based display reverted the number
  // whenever a QSO stopped counting (X-QSO, mid-log delete).  NextSerialToSend
  // also returns ServerSerialNumber in networked mode, matching the old value.
  TF.Format(wsprintfBuffer, QSONumberStringArray[Config.AutoQSONumberDecrement], NextSerialToSend);
  if ServerSerialNumber <> 0 then
    if PreviousSerialNumberType = sntReserved then
       begin
       Windows.lstrcatA(wsprintfBuffer, 'L');
       end;
  SetMainWindowText(mweQSONumber, wsprintfBuffer);
end;


procedure DisplayQTCNumber(QTCNumber: integer);
begin
  TF.Format(wsprintfBuffer, TC_HAVEQTCS, QTCNumber);
  SetMainWindowText(mweUserInfo, wsprintfBuffer);
end;

procedure DisplayCountryName(Call: CallString);
var
  Country                               : Word;
begin

  Country := ctyGetCountry(Call);
  DisplayLocalTime(Country);
  if tCountryNamePrevState = Country then Exit;
  tCountryNamePrevState := Country;
  SetMainWindowText(mweCountryName, ctyGetCountryNamePchar(Country));
end;

procedure DisplayQSOsWithThisStation(QSOs: integer);
var
  p                                     : PAnsiChar;
begin
//  if tQSOsWithThisStationPrevState = QSOs then Exit;
  tQSOsWithThisStationPrevState := QSOs;

  if QSOs <> 0 then
     begin
     p := inttopchar(QSOs)
     end
  else
     begin
     p := nil;
     end;
  SetMainWindowText(mweQSOsWithThisStation, p);
end;

procedure DisplayRadio(Radio: RadioType);
begin
  // RadioName IS A ShortString (Str20, LOGRADIO.PAS:154), so it is NOT
  // null-terminated -- its length lives in byte 0.  PAnsiChar(@RadioName[1])
  // ignored that and read from byte 1 until it happened to find a #0, which
  // means it read STALE BYTES LEFT BY A LONGER PREVIOUS VALUE.
  //
  // Assigning 'K3S' over 'Radio 2' sets the length to 3 and copies 3 bytes; the
  // 'io 2' behind it is untouched.  The field then displayed "K3Sio 2", and
  // "K4Zio 1" for 'K4Z' over 'Radio 1'.  NY4I saw exactly that, 2026-08-18.
  //
  // Converting the ShortString directly uses the length byte, which is the
  // whole fix.  Not a port regression: D7 passes @Radio1.RadioName[1] the same
  // way (LOGWIND.PAS:1845) and has the same defect.
  SetMainWindowText(mweRadioOne, string(Radio1.RadioName));
  SetMainWindowText(mweRadioTwo, string(Radio2.RadioName));
end;

procedure DisplayQSOsByOpMode;
begin

  TF.Format(wsprintfBuffer, ' CQ: %u', tRestartInfo.riQSOByOpMode[CQOpMode]);
  SetMainWindowText(mweCQQSOCounter, wsprintfBuffer);

  TF.Format(wsprintfBuffer, ' SP: %u', tRestartInfo.riQSOByOpMode[SearchAndPounceOpMode]);
  SetMainWindowText(mweSPQSOCounter, wsprintfBuffer);
end;

procedure DisplayHour;
var
  TempInteger                           : integer;
begin
  if AlarmSet then Exit;
  case HourDisplay of
    ThisHour:
      begin
        TempInteger := TotalThisHour;
        TF.Format(wsprintfBuffer, TC_THISHR, TotalThisHour);
      end;
    LastSixtyMins:
      begin
        TempInteger := TotalLastSixty;
        TF.Format(wsprintfBuffer, TC_LAST60, TotalLastSixty);
      end;
    BandChanges, BandChangesThisComputer:
      begin
        TempInteger := tThisHourBandChanges;
        TF.Format(wsprintfBuffer, TC_BAND_CHANGES, tThisHourBandChanges);
      end;
  end;
  SetMainWindowText(mweHourRate, wsprintfBuffer);
  SendMessage(LastProgressBar, PBM_SETPOS, TempInteger, 0);
end;

procedure DisplayRate(Rate: Cardinal);
//var  TempString                            : string;

begin
  if not AlarmSet then
     begin

     {        REMOVECANDIDATE
          case HourDisplay of
            ThisHour:
              begin
                TempString := 'This hr = ' + IntToStr(TotalThisHour);
                SendMessage(LastProgressBar, PBM_SETPOS, TotalThisHour, 0);
              end;
            LastSixtyMins:
              begin
                TempString := 'Last 60 = ' + IntToStr(TotalLastSixty);
                SendMessage(LastProgressBar, PBM_SETPOS, TotalLastSixty, 0);
              end;
          end;

          tSetWindowText(HourRateWindowHandle, TempString);
      }
     //    tSetWindowText(RateWindowHandle, 'Rate = ' + IntToStr(Rate));

   TF.Format(wsprintfBuffer, TC_RATE, Rate);

   SetMainWindowText(mweRate, wsprintfBuffer);
   SendMessage(RateProgressBar, PBM_SETPOS, Rate, 0);
     end;
end;

procedure DisplayAutoQSLInterval;
begin
  TF.Format(QuickDisplayBuffer, 'AUTO QSL INTERVAL = %u', AutoQSLInterval);
  SetTextInQuickCommandWindow(QuickDisplayBuffer);
end;

procedure DisplayTotalScore {(Score: LONGINT)};

var
  i                                     : integer;
  Score                                 : integer;
begin

  Score := TotalScore;
  // Issue #997: asm-push wsprintf -> Format (the TF.Format idiom already used
  // ~18x in this unit; LOGWIND deliberately avoids SysUtils -- see the BoolToStr
  // note below).  The old code relied on `Score := TotalScore` leaving the value
  // in EAX for the `push eax` -- a fragile Delphi-7 codegen assumption that 64-bit
  // would break.  TC_PTS = '%d Pts'.
  TF.Format(wsprintfBuffer, TC_PTS, Score);
  SetMainWindowText(mweTotalScore, wsprintfBuffer);

  //  tSetWindowText(TotalScoreWindowHandle, IntToStr(Score) + ' Pts');

  if NumberTotalScoreMessages > 0 then
     begin
     for i := 0 to NumberTotalScoreMessages - 1 do
       if TotalScoreMessages[i].Score < Score then
         if TotalScoreMessages[i].Score >= 0 then
            begin
            //                  SaveSetAndClearActiveWindow (QuickCommandWindow);

//          if WindowsOSversion = 2 then
//            ShowTrayTips(TotalScoreMessages[i].MessageString)
//          else
         QuickDisplay(string(PAnsiChar(@TotalScoreMessages[i].MessageString[1])));
            //          ShowAlarmWakeUpWindow(TotalScoreMessages[message].MessageString);
          DoABeep(Congrats);

          TotalScoreMessages[i].Score := -1;
            //                  RestorePreviousWindow;
            end;
     end;

end;

procedure QuickDisplay(Prompt: string);
begin
  SetTextInQuickCommandWindow(Prompt);
  logger.Info('[QuickDisplay] (' + Prompt + ')');
  if length(Prompt) > 0 then
     begin
     logger.Debug('Calling tCreateThread from QuickDisplay');
     if tFlashQDThreadID = 0 then
        begin
        tCreateThread(@FlashQickDisplay, tFlashQDThreadID);
        end;
     if ClearQuickDisplayTimer <> 0 then
        begin
        Windows.KillTimer(tr4whandle, ClearQuickDisplayTimer);
        end;
     ClearQuickDisplayTimer := Windows.SetTimer(tr4whandle, QUICK_REPORT_TIMER_HANDLE, 30000, @ClearQuickDisplayText);
     end;
end;

procedure SetTextInQuickCommandWindow(Text: string);
begin
  SetMainWindowText(mweQuickCommand, Text);
end;

procedure ClearQuickDisplayText;
begin
  SetTextInQuickCommandWindow('');
//  Windows.AnimateWindow(wh[mweQuickCommand], 500, AW_HIDE or AW_HOR_POSITIVE);
  Windows.KillTimer(tr4whandle, ClearQuickDisplayTimer);
  ClearQuickDisplayTimer := 0;
end;

procedure QuickDisplayError(Prompt: string);
begin
  QuickDisplay(Prompt);
  DoABeep(Warning);
end;

function QuickEditResponse(Prompt: PAnsiChar; MaxInputLength: Byte): ShortString;
var
  h                                     : HWND;
 // Window                                : Byte;
begin
  TF.Format(IQPrompt, TC_ENTER, Prompt);
  IQMaxInputLength := MaxInputLength;
  // ALWAYS the main window.  This used to prefer settingswindowhandle, which
  // was non-zero only while the old Win32 settings dialog was open so that a
  // prompt raised from it got the right parent.  That dialog is gone
  // (uOption.pas deleted 2026-08-21), so the handle was always 0 and the
  // branch always took this arm.
  h := tr4whandle;
  //DialogBox(hInstance, MAKEINTRESOURCE(41 {Window}), h, @IQDlgProc);
  ShowInputQuery(h);
  Result := IQresult;
end;

function QuickEditInteger(Prompt: PAnsiChar {str80}; MaxInputLength: integer): LONGINT;

{ This function will put up the prompt specified and get the numeric input
  that is put in.  Only integers will be processed and if the number of
  integers specified is entered, a return will not be waited for.  The
  characters are converted to an integer.  If an escape is hit, the
  response will be -1.                                                }

var
  InputString                           : Str80;
  InputValue                            : LONGINT;
  Result1                               : integer;
begin
  tInputDialogInteger := True;
  QuickEditInteger := -1;
  InputString := QuickEditResponse(Prompt, MaxInputLength);

  if InputString <> '' then
     begin
     Val(InputString, InputValue, Result1);
     if Result1 = 0 then
        begin
        QuickEditInteger := InputValue;
        end;
     end;
end;

function QuickEditFreq(Prompt: PAnsiChar {str80}; MaxInputLength: integer): LONGINT;

{ This function will put up the prompt specified and get the numeric input
  that is put in.  Only integers will be processed and if the number of
  integers specified is entered, a return will not be waited for.  The
  characters are converted to an integer.  If an escape is hit, the
  response will be -1.                                                }

{KK1L: 6.73 Result will be negative if CTRL-Enter was used to enter the frequency}
{           and two radios are active. This is used to set the inactive radio.}

var
  InputString                           : Str80;
  KHzString, HertzString                : Str20;
  InputValue                            : LONGINT;
  Result1                               : integer;
//  Key                              : Char;
  CTRLStr{, TempStr}                      : Str80; {KK1L: 6.73}

begin
  QuickEditFreq := -1;

  {KK1L: 6.73 Changed to return a 'CTRL' at the end if CTRL-Enter was used and two radios are active.}

  InputString := QuickEditResponse(Prompt, MaxInputLength);
  if {(InputString = EscapeKey) or }(InputString = '') then
     begin
     Exit;
     end;

  CTRLStr := InputString; {KK1L: 6.73}
  Delete(CTRLStr, 1, (length(CTRLStr) - 4));

  if CTRLStr = 'CTRL' then
     begin
     Delete(InputString, (length(InputString) - 3), 4); {KK1L: 6.73}
     end;

  if StringHas(InputString, '.') then
     begin
     KHzString := PrecedingString(InputString, '.');
     HertzString := PostcedingString(InputString, '.');

     while length(HertzString) < 3 do
        begin
        HertzString := HertzString + '0';
        end;

     Val(KHzString + HertzString, InputValue, Result1);
     end
  else
     begin
     InputString := InputString + '000';
     Val(InputString, InputValue, Result1);
     end;

  if (CTRLStr = 'CTRL') and (Result1 = 0) then
     begin
     InputValue := InputValue * (-1) {KK1L: 6.73}
     end
  else
    if Result1 <> 0 then
       begin
       Exit;
       end;

  { This used to be all over LOGSUBS2, I moved it here }

  if (InputValue > 1000) and (InputValue < 1000000) then
     begin
     case ActiveBand of
       Band160: InputValue := InputValue + 1000000;
       Band80: InputValue := InputValue + 3000000;
       Band40: InputValue := InputValue + 7000000;
       Band20: InputValue := InputValue + 14000000;
       Band15: InputValue := InputValue + 21000000;
       Band10: InputValue := InputValue + 28000000;
     end;
     end;

  QuickEditFreq := InputValue;
end;

function QuickEditReal(Prompt: PAnsiChar {str80}; MaxInputLength: integer): REAL;

{ This function will put up the prompt specified and get the numeric input
  that is put in.  Only integers will be processed and if the number of
  integers specified is entered, a return will not be waited for.  The
  characters are converted to an integer.  If an escape is hit, the
  response will be -1.                                                }

var
  InputString                           : Str80;
  Result1                               : integer;
  InputValue                            : REAL;
  //  Key                                   : Char;

begin
  QuickEditReal := -1;

  InputString := QuickEditResponse(Prompt, MaxInputLength);
  //wli  if InputString = EscapeKey then    Exit;

  if InputString <> '' then
     begin
     Val(InputString, InputValue, Result1);

     if Result1 = 0 then
        begin
        QuickEditReal := InputValue;
        end;
     end;
end;

procedure ResetSavedWindowListAndPutUpCallWindow;

begin
  {    ExchangeWindowCursorPosition := 0;
      NumberSavedWindows := 0;
      SetActiveWindow (CallWindow);
      ClrScr;
 }
end;

procedure PutUpExchangeWindow;

begin
  //  SaveSetAndClearActiveWindow(ExchangeWindow);
  //  RestorePreviousWindow;
end;

procedure ActivateExchangeWindow;

{ This procedure will make the exchange window active with the cursor
  at position it was at before.                                    }

begin
  {    SaveAndSetActiveWindow (ExchangeWindow);
      GoToXY (ExchangeWindowCursorPosition, WhereY)
 }
end;
{  REMOVECANDIDATE
}

{
}

procedure DecrementBandMapTimes;

{ Decrements all times by one.  Any that were at zero get deleted. }

var
  BandMapEntryRecord, {EntryToBeDisposed,} PreviousBandMapEntryRecord: BandMapEntryPointer;
  MinutesLeft                           : Byte;
  Band                                  : BandType;
  Mode                                  : ModeType;

begin
  for Band := Band160 to Band2 do
    for Mode := CW to Phone do
      if BandMapFirstEntryList[Band, Mode] <> nil then
         begin
         PreviousBandMapEntryRecord := nil;
         BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

         while BandMapEntryRecord <> nil do
            begin
            MinutesLeft := BandMapEntryRecord^.StatusByte and $3F;

            if MinutesLeft = 0 then { Time to die }
               begin
               if PreviousBandMapEntryRecord = nil then { This is the first one in list }
                  begin
                  BandMapFirstEntryList[Band, Mode] := BandMapEntryRecord^.NextEntry;
                  Dispose(BandMapEntryRecord);
                  BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];
                  Continue;
                  end;

                     { Wasn't the first record - change NextExtry of previous
                    record to point to the NextEntry }

               PreviousBandMapEntryRecord^.NextEntry := BandMapEntryRecord^.NextEntry;

                     { Free up the memory }

               Dispose(BandMapEntryRecord);

                     { We want to process the next band map entry next }

               BandMapEntryRecord := PreviousBandMapEntryRecord^.NextEntry;
               Continue;
               end;

                { We aren't going to delete this entry - decrement the minute count }

            dec(MinutesLeft);

            BandMapEntryRecord^.StatusByte := BandMapEntryRecord^.StatusByte and $C0;
            BandMapEntryRecord^.StatusByte := BandMapEntryRecord^.StatusByte or MinutesLeft;

                { Move to the next entry.  Remember the address of this entry in
                case I need to link its NextEntry to a different place }

            PreviousBandMapEntryRecord := BandMapEntryRecord;
            BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
            end;
         end;
end;

procedure UpdateTimeAndRateDisplays(ShowTime: boolean; DoRadios: boolean);

label
  IgnoreRadioOneFreq, IgnoreRadioTwoFreq;

var
  DateString, DayString                 : Str20;
  Hour, Minute{, Second, Hundredths}      : Word;
  AlarmInteger, RecordNumber, IntegerTime {, RateMinute}: integer;
//  TempBand                              : BandType;
  TempPchar                             : PAnsiChar;
begin

  if DoRadios then
     begin

     end;

  //-----------------------time------------------------------------

  //  tGetSystemTime;

  if ShowTime then
     begin
     SetMainWindowText(mweFullTime, GetFullTimeString(False));

     if tElapsedTimeFromLastQSO <> 0 then
        begin
        tDispalyTimeFromLastQSO;
        end;

     // D12: ElaspedTimeString + SetMainWindowText are both native string now,
     // so the PAnsiChar TempPchar intermediary is gone; '' is the empty signal.
     if TenMinuteRule <> NoTenMinuteRule then
        begin
        SetMainWindowText(mweTenMinuts, ElaspedTimeString(TenMinuteTime.Time))
        end
     else
        begin
        SetMainWindowText(mweTenMinuts, '');
        end;
     end;

  {reminder}
  if UTC.wSecond = 1 then
     begin
     ShowTourDuration;
     end;

  if UTC.wSecond = 0 then { See if new minute }
     begin
     inc(MinutesSinceLastBMUpdate); {KK1L: 6.65}

       {if tDupesInteval > 0 then RefreshOZHRBandMap;}
    if ActiveBand in [Band160..Band10] then
       begin
       inc(TimeSpentByBand[ActiveBand]);
       end;

     AutoTimeQSOCount := 0;
       {KK1L: 6.65 Added this check to allow for > 63 minute BM decay}
     if MinutesSinceLastBMUpdate >= BandMapDecayMultiplier then
        begin
        MinutesSinceLastBMUpdate := 0;
            //DecrementBandMapTimes;
        // The DisplayBandMap that stood here is redundant AND unconditional.
        // DecrementSpotsTimes bumps the repaint token itself now, so the
        // refresh timer picks the decay up -- and unlike a direct call, it
        // respects the "no window" and "not visible" tests, so a minimised
        // TR4W no longer repaints the band map once a minute for nobody.
        SpotsList.DecrementSpotsTimes;
        end;
     SetMainWindowText(mweClock, GetTimeString);

     if UTC.wMinute = 0 then
        begin
        SetMainWindowText(mweDate, GetDateString);
        TotalThisHour := 0;
        tThisHourBandChanges := 0;

        if MP3RecorderMode = mprRec then
          if RecorderDuration = rdEachHour then
             begin
             CloseTempMP3File;
             OpenTempMP3File;
             end;
        end;

     if NumberReminderRecords > 0 then
        begin
        IntegerTime := GetIntegerTime;
        DayString := UpperCase(GetDayString);
        DateString := UpperCase(GetDateString);

        for RecordNumber := 0 to NumberReminderRecords - 1 do
          if Reminders^[RecordNumber].Time = IntegerTime then
            if (Reminders^[RecordNumber].DateString = DateString) or
              (Reminders^[RecordNumber].DayString = DayString) or
              (Reminders^[RecordNumber].DayString = 'ALL') then
               begin

               if Reminders^[RecordNumber].Alarm then
                  begin
                  DoABeep(WakeUp)
                  end
               else
                  begin
                  DoABeep(Congrats);
                  end;
   //            if WindowsOSversion = 2 then
   //              ShowTrayTips(Reminders^[RecordNumber].RemMessage)
   //            else
               QuickDisplay(string(PAnsiChar(@Reminders^[RecordNumber].RemMessage[1])));
               end;
        end;

     if AlarmSet then
        begin
        AlarmInteger := AlarmHour * 100 + AlarmMinute;

        if AlarmInteger = GetIntegerTime then
           begin
           //{WLI}                WakeUp;
     AlarmMinute := AlarmMinute + 4;

     if AlarmMinute > 59 then
        begin
        AlarmMinute := AlarmMinute - 60;
        AlarmHour := AlarmHour + 1;
        if AlarmHour > 23 then
           begin
           AlarmHour := AlarmHour - 24;
           end;
        end;
           end;

        if (Hour = AlarmHour) and (Minute = AlarmMinute) then
           begin
           //{WLI}                WakeUp;
     AlarmMinute := AlarmMinute + 4;

     if AlarmMinute > 59 then
        begin
        AlarmMinute := AlarmMinute - 60;
        AlarmHour := AlarmHour + 1;
        if AlarmHour > 23 then
           begin
           AlarmHour := AlarmHour - 24;
           end;
        end;
           end;
        end;

     if (NumberContactsThisMinute = 0) and (WakeUpTimeOut > 0) then
        begin
        inc(WakeUpCount);
        if (WakeUpCount >= WakeUpTimeOut) and not AlarmSet then
           begin
           DoABeep(WakeUp);
           end;
        end
     else
        begin
        WakeUpCount := 0;
        end;
     tCalculateRate();

 //            if PacketReturnCount = 0 then
 //            begin
 //              CPUKeyer.AddSerialPortCharacter(Packet.PacketSerialPort, CarriageReturn);
 //              QuickDisplay('Carriage return sent to packet port.  (per PACKET RETURN PER MINUTE)');
 //              PacketReturnCount := PacketReturnPerMinute;
 //            end;
 //          end;
     end;
end;

procedure tCalculateRate();
var
  RateMinute                            : integer;
  TempBand                              : BandType;
begin
//       Fix up the rate array. First, shuffle the minutes

  for RateMinute := 60 downto 2 do
     begin
     RateMinuteArray[RateMinute].TotalQSOs := RateMinuteArray[RateMinute - 1].TotalQSOs;
     RateMinuteArray[RateMinute].TotalPoints := RateMinuteArray[RateMinute - 1].TotalPoints;
     RateMinuteArray[RateMinute].BandQSOs := RateMinuteArray[RateMinute - 1].BandQSOs;
     end;

//       Put new values on top

  RateMinuteArray[1].TotalQSOs := NumberContactsThisMinute;
  RateMinuteArray[1].TotalPoints := NumberQSOPointsThisMinute;
  RateMinuteArray[1].BandQSOs := NumberBandQSOsThisMinute;

//       Compute rate = # QSOs or points in last 10 minutes

  Rate := 0;

  for RateMinute := 1 to 10 do
     begin
     case RateDisplay of
       QSOs: Rate := Rate + RateMinuteArray[RateMinute].TotalQSOs;
       Points: Rate := Rate + RateMinuteArray[RateMinute].TotalPoints;
       BandQSOs: if ActiveBand in [Band160..Band10] then Rate := Rate + RateMinuteArray[RateMinute].BandQSOs[ActiveBand] +  RateMinuteArray[RateMinute].BandQSOs[InactiveRadioPtr.BandMemory];  // n4af 4.76.4
     end;
     end;

//       Compute last sixty minute totals

  TotalLastSixty := 0;

  for RateMinute := 1 to 60 do
     begin
     case RateDisplay of
       QSOs: TotalLastSixty := TotalLastSixty + RateMinuteArray[RateMinute].TotalQSOs;
       Points: TotalLastSixty := TotalLastSixty + RateMinuteArray[RateMinute].TotalPoints;
       BandQSOs: if ActiveBand in [Band160..Band10] then TotalLastSixty := TotalLastSixty + RateMinuteArray[RateMinute].BandQSOs[ActiveBand];
     end;
     end;

  case RateDisplay of
    QSOs: TotalThisHour := TotalThisHour + NumberContactsThisMinute;
    Points: TotalThisHour := TotalThisHour + NumberQSOPointsThisMinute;
    BandQSOs: if ActiveBand in [Band160..Band10] then TotalThisHour := TotalThisHour + NumberBandQSOsThisMinute[ActiveBand];
  end;

//       Zero out minute totals

  NumberContactsThisMinute := 0;
  NumberQSOPointsThisMinute := 0;
  for TempBand := Band160 to Band10 do
     begin
     NumberBandQSOsThisMinute[TempBand] := 0;
     end;

//       Compute rate

  if NumberMinutesProgramRunning >= 10 then
     begin
     Rate := Rate * 6
     end
  else
     begin
     inc(NumberMinutesProgramRunning);

     if NumberMinutesProgramRunning > 0 then
        begin
        Rate := round(Rate * (60 / NumberMinutesProgramRunning))
        end
     else
        begin
        Rate := 0;
        end;
     end;
  DisplayHour;
  DisplayRate(Rate);
end;                          

procedure IncrementTime(Count: integer);

//var
 // LoopCount                             : integer;
 // Hours, Minutes, Seconds, Hundredths   : Word;
 // Year, Month, Day, DayOfWeek           : Word;

begin
  AutoTimeQSOCount := 0;
  IncSystemTime(UTC, 60 * 1000 * Count);
  UTC.wSecond := 0;
{
  GetTime(Hours, Minutes, Seconds, Hundredths);
  Minutes := Minutes + Count;

  if Minutes > 59 then
  begin
    Minutes := Minutes - 60;
    inc(Hours);

    if Hours > 23 then
    begin
      Hours := Hours - 24;
      GetDate(Year, Month, Day, DayOfWeek);
      inc(Day);
          //WLI            SetDate (Year, Month, Day);
    end;
  end;
}
  //WLI    SetTime (Hours, Minutes, 0, 0);
//  LastDisplayedTime := '';
//  LastDisplayedDate := '';
  SystemTimeChanging;
//  UpdateTimeAndRateDisplays(True, False);
end;

procedure ClearAutoSendDisplay;

begin
  //  SaveAndSetActiveWindow(WholeScreenWindow);
   //{WLI}    GoToXY (CallWindowLX, CallWindowLY - 1);
   //{WLI}    Write ('          ');
   //{WLI}    RestorePreviousWindow;
end;

procedure DisplayAutoSendCharacterCount;
var
  h                                     : HWND;
  nCmdShow                              : integer;
begin

  h := wh[mweAutoSendCount];
  if (AutoSendCharacterCount > 0) and AutoSendEnable and (ActiveMode = CW) and not SearchAndPounceMode then
     begin
     nCmdShow := SW_SHOW;
     tSetWindowLeft(h, (AutoSendCharacterCount - 1) * ws2 * 3 + ws * 15 {col4});
     end
  else
     begin
     nCmdShow := SW_HIDE;
     end;
  Windows.ShowWindow(h, nCmdShow);
end;


procedure SetUpBandMapEntry(BandMapData: BandMapEntryPointer; Radio: RadioType); {KK1L: 6.73 Added Radio}

{KK1L: 6.64 Added sense of mode from frequency so radio would be set to mode}
{      when bandmapentry is selected}
{KK1L: 6.64 Added taking radio out of split when QSXOffset=0}
{KK1L: 6.64 Added QSXOffset scaling to make range within INTEGER}

var
  EntryBand                             : BandType;
  EntryMode                             : ModeType;
  QSXOffsetInHertz                      : LONGINT;
  TempCallsign                          : Str20;
begin
  if BandMapData = nil then Exit;
  BandMapCursorData := BandMapData;

  with BandMapData^ do
    if Frequency > 0 then
       begin
       GetBandMapBandModeFromFrequency(Frequency, EntryBand, EntryMode);

         //      ClearCallWindowAtSPMove := false;
       if QSXOffset <> 0 then
          begin
          {KK1L: 6.64 Scaling added to keep offset within INTEGER range.}
          {QSXOffsetInHertz := QSXOffset * 10;}
          {KK1L: 6.64 Not needed. Only LONGINT seems to work as QSXOffset type}
      QSXOffsetInHertz := QSXOffset;
          {KK1L: 6.64 Trying to add resonable functionality to split stuff}
      case BandMapSplitMode of
        ByCutoffFrequency:
          begin
                {KK1L: 6.71 moved ahead of 'A' because for TS850 need to make B active to change mode}
            SetRadioFreq(Radio, {wli Frequency +} QSXOffsetInHertz, EntryMode, 'B');
            SetRadioFreq(Radio, Frequency, EntryMode, 'A');
          end;
        AlwaysPhone:
          begin
                {KK1L: 6.71 moved ahead of 'A' because for TS850 need to make B active to change mode}
            SetRadioFreq(Radio, {wli Frequency +} QSXOffsetInHertz, Phone, 'B');
            SetRadioFreq(Radio, Frequency, Phone, 'A');
          end;
      end;
      PutRadioIntoSplit(Radio); {KK1L: 6.71 Moved here from before case for TS850 change}
          end
       else {KK1L: 6.64 Takes radio back out of split if not required for next entry}
          begin
          SetRadioFreq(Radio, Frequency, EntryMode, 'A');
          PutRadioOutOfSplit(Radio);
          end;
         {wli}
 //      Escape_proc;
 //      SetOpMode(SearchAndPounceOpMode);
       CallAlreadySent := False;
       ExchangeHasBeenSent := False;
       tCleareExchangeWindow;
       TempCallsign := BandMapExpandedString(Call);
       if CQLabel(TempCallsign) then
          begin
          Windows.SetWindowTextA(wh[mweCall], nil);
          SetOpMode(CQOpMode);
          end
       else
          begin
          SetOpMode(SearchAndPounceOpMode);
          if Copy(TempCallsign, 1, 3) <> 'NEW' then
             begin
             tSetWindowText(wh[mweCall], TempCallsign);
             end;
          end;
         //      Frm.CallWindow . SetFocus;
       tCallWindowSetFocus;
         //        SendMessage(CallWindowHandle, EM_SETSEL, 16, 16);
       PlaceCaretToTheEnd(wh[mweCall]);
       DisplayCountryName(CallWindowString);
       DisplayBeamHeading(CallWindowString, '');

         //        DispalayB4; //???????

       if Contest <> GENERALQSO then
          begin
          VisibleLog.ShowMultiplierStatus(@CallWindowString);
          VisibleLog.ShowQSOStatus(@CallWindowString);
          end;
         //      FRM.CallWindowChange(nil);
         //      CallAlreadySent := False;

       end;
end;

function NextNonDupeEntryInDisplayedBandMap(Band: BandType; Mode: ModeType): boolean;

{ Data will be in BandMapCursorData record }
{KK1L: 6.64 Added to allow stepping through the displayed bandmap rather than just in}
{      current band and mode.}

var
  BandMapEntryRecord                    : BandMapEntryPointer;
  Callsign                              : CallString;
  //  StartBand, StopBand              : BandType;
  //  StartMode, StopMode              : ModeType;
  RadioToUse                            : RadioType; {KK1L: 6.73}

begin
  NextNonDupeEntryInDisplayedBandMap := False;

  if CommandUseInactiveRadio then {KK1L: 6.73}
     begin
     RadioToUse := InactiveRadio
     end
  else
     begin
     RadioToUse := ActiveRadio;
     end;
  tSetStartStopBandMode;
  for Band := StartBand to StopBand do
     begin
     for Mode := StartMode to StopMode do
        begin

        if (not WARCBandsEnabled) and
          ({(Band = Band60) or} (Band =Band30) or (Band = Band17) or (Band = Band12)) then
           begin
           Continue; {KK1L: 6.64 Keep band map within contest limits}
           end;

        BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

        while BandMapEntryRecord <> nil do
           begin
           Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
               {KK1L: 6.73 Use LastDisplayedFreq instead of DisplayedFrequency to support control-A}
   //       if BandMapEntryRecord^.Frequency > LastDisplayedFreq[RadioToUse] then
   //        if Abs(LastDisplayedFreq[RadioToUse] - BandMapEntryRecord^.Frequency) > BandMapGuardBand then
           if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
             if ((BandMapEntryRecord^.StatusByte and $40) = 0) then
                begin
                SetUpBandMapEntry(BandMapEntryRecord, RadioToUse); {KK1L: 6.73}
                NextNonDupeEntryInDisplayedBandMap := True;
                Exit;
                end;

           BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
           end;
        end;
     end;

  { Got to the end of the list without finding anything.  Start at the
    beginning and find the first non dupe entry }

  for Band := StartBand to StopBand do
     begin
     for Mode := StartMode to StopMode do
        begin
        BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

        while BandMapEntryRecord <> nil do
           begin
           Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
           if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
             if ((BandMapEntryRecord^.StatusByte and $40) = 0) then
                begin
                BandMapCursorData := BandMapEntryRecord;
                NextNonDupeEntryInDisplayedBandMap := True;
                Exit;
                end;

           BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
           end;
        end;
     end;
end;

{KK1L: 6.68}

function NextMultiplierEntryInDisplayedBandMap(Band: BandType; Mode: ModeType): boolean;

{ Data will be in BandMapCursorData record }
{KK1L: 6.68 Added to allow stepping through the displayed bandmap rather than just in}
{      current band and mode.}

var
  BandMapEntryRecord                    : BandMapEntryPointer;
  Callsign                              : CallString;
  //  StartBand, StopBand              : BandType;
  //  StartMode, StopMode              : ModeType;
  RadioToUse                            : RadioType; {KK1L: 6.73}

begin
  NextMultiplierEntryInDisplayedBandMap := False;

  if CommandUseInactiveRadio then {KK1L: 6.73}
     begin
     RadioToUse := InactiveRadio
     end
  else
     begin
     RadioToUse := ActiveRadio;
     end;
  tSetStartStopBandMode;
  for Band := StartBand to StopBand do
     begin
     for Mode := StartMode to StopMode do
        begin

        if (not WARCBandsEnabled) and
          ({(Band = Band60) or }(Band = Band30) or (Band = Band17) or (Band = Band12)) then
           begin
           Continue; {KK1L: 6.64 Keep band map within contest limits}
           end;

        BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

        while BandMapEntryRecord <> nil do
           begin
           Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
               {KK1L: 6.73 Use LastDisplayedFreq instead of DisplayedFrequency to support control-A}
   //????????        if BandMapEntryRecord^.Frequency > LastDisplayedFreq[RadioToUse] then
   //????????          if Abs(LastDisplayedFreq[RadioToUse] - BandMapEntryRecord^.Frequency) > BandMapGuardBand then
           if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
             if ((BandMapEntryRecord^.StatusByte and $80) <> 0) then
                begin
                SetUpBandMapEntry(BandMapEntryRecord, RadioToUse); {KK1L: 6.73}
                NextMultiplierEntryInDisplayedBandMap := True;
                Exit;
                end;

           BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
           end;
        end;
     end;

  { Got to the end of the list without finding anything.  Start at the
    beginning and find the first non dupe entry }

  for Band := StartBand to StopBand do
     begin
     for Mode := StartMode to StopMode do
        begin
        BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

        while BandMapEntryRecord <> nil do
           begin
           Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
           if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
             if ((BandMapEntryRecord^.StatusByte and $80) <> 0) then
                begin
                BandMapCursorData := BandMapEntryRecord;
                NextMultiplierEntryInDisplayedBandMap := True;
                Exit;
                end;

           BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
           end;
        end;
     end;
end;

function NextNonDupeEntryInBandMap(Band: BandType; Mode: ModeType): boolean;

{ Data will be in BandMapCursorData record }
var
  BandMapEntryRecord                    : BandMapEntryPointer;
  Callsign                              : CallString;
  RadioToUse                            : RadioType; {KK1L: 6.73}

begin
  NextNonDupeEntryInBandMap := False;

  if CommandUseInactiveRadio then {KK1L: 6.73}
     begin
     RadioToUse := InactiveRadio
     end
  else
     begin
     RadioToUse := ActiveRadio;
     end;

  if BandMapFirstEntryList[Band, Mode] = nil then
     begin
     Exit;
     end;

  BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

  { Search through the bandmap to find the next non dupe entry. }

  while BandMapEntryRecord <> nil do
     begin
     Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
       {KK1L: 6.73 Use LastDisplayedFreq instead of DisplayedFrequency to support control-A}
 //????????    if BandMapEntryRecord^.Frequency > LastDisplayedFreq[RadioToUse] then
 //????????      if Abs(LastDisplayedFreq[RadioToUse] - BandMapEntryRecord^.Frequency) > BandMapGuardBand then
     if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
       if ((BandMapEntryRecord^.StatusByte and $40) = 0) then
          begin
          SetUpBandMapEntry(BandMapEntryRecord, RadioToUse); {KK1L: 6.73}
          NextNonDupeEntryInBandMap := True;
          Exit;
          end;

     BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
     end;

  { Got to the end of the list without finding anything.  Start at the
    beginning and find the first non dupe entry }

  BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

  while BandMapEntryRecord <> nil do
     begin
     Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
     if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
       if ((BandMapEntryRecord^.StatusByte and $40) = 0) then
          begin
          BandMapCursorData := BandMapEntryRecord;
          NextNonDupeEntryInBandMap := True;
          Exit;
          end;

     BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
     end;
end;

{KK1L: 6.68}

function NextMultiplierEntryInBandMap(Band: BandType; Mode: ModeType): boolean;

{ Data will be in BandMapCursorData record }
var
  BandMapEntryRecord                    : BandMapEntryPointer;
  Callsign                              : CallString;
  RadioToUse                            : RadioType; {KK1L: 6.73}

begin
  NextMultiplierEntryInBandMap := False;

  if CommandUseInactiveRadio then {KK1L: 6.73}
     begin
     RadioToUse := InactiveRadio
     end
  else
     begin
     RadioToUse := ActiveRadio;
     end;

  if BandMapFirstEntryList[Band, Mode] = nil then
     begin
     Exit;
     end;

  BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

  { Search through the bandmap to find the next non dupe entry. }

  while BandMapEntryRecord <> nil do
     begin
     Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
       {KK1L: 6.73 Use LastDisplayedFreq instead of DisplayedFrequency to support control-A}
 //????????    if BandMapEntryRecord^.Frequency > LastDisplayedFreq[RadioToUse] then
 //????????      if Abs(LastDisplayedFreq[RadioToUse] - BandMapEntryRecord^.Frequency) > BandMapGuardBand then
     if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
       if ((BandMapEntryRecord^.StatusByte and $80) <> 0) then
          begin
          SetUpBandMapEntry(BandMapEntryRecord, RadioToUse); {KK1L: 6.73}
          NextMultiplierEntryInBandMap := True;
          Exit;
          end;

     BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
     end;

  { Got to the end of the list without finding anything.  Start at the
    beginning and find the first non dupe entry }

  BandMapEntryRecord := BandMapFirstEntryList[Band, Mode];

  while BandMapEntryRecord <> nil do
     begin
     Callsign := BandMapExpandedString(BandMapEntryRecord^.Call);
     if CQLabel(Callsign) then {KK1L: 6.69 added to skip CQ frequency}
       if ((BandMapEntryRecord^.StatusByte and $80) <> 0) then
          begin
          BandMapCursorData := BandMapEntryRecord;
          NextMultiplierEntryInBandMap := True;
          Exit;
          end;

     BandMapEntryRecord := BandMapEntryRecord^.NextEntry;
     end;
end;

procedure GetBandMapBandModeFromFrequency(Frequency: LONGINT;
  var Band: BandType;
  var Mode: ModeType);

{ Mode might be setup by someone else - in which case, don't mess with it }

//var
 // TempMode                              : ModeType;
  //TempStr                               : Str20;
begin
  CalculateBandMode(Frequency, Band, {Temp} Mode);
//  if not (Mode in [CW, Phone]) then
  begin
    if Band = NoBand then Exit;
    if Frequency >= BandMapModeCutoffFrequency[Band] then
       begin
       Mode := Phone
       end
    else
       begin
       Mode := CW;
       end;
  end;
end;

procedure AddBandMapModeCutoffFrequency(Freq: LONGINT);

var
  TempBand                              : BandType;
  TempMode                              : ModeType;
begin
  CalculateBandMode(Freq, TempBand, TempMode);
  if TempBand in [Band160..Band2] then
     begin
     BandMapModeCutoffFrequency[TempBand] := Freq;
     end;
end;

procedure AddBandMapPlaceHolder;

{KK1L: 6.65 Created proc to add a dummy call to the BM. It is invoked by CTRL-INS.}
{           Its purpose is to put a unique ID in the BM with multiplier set when you}
{           tune across a station, catch a partial call, and don't want to wait.}

begin
  tBandMapPlaceHolder[0] := CHR(8);
  tGetSystemTime;

  TF.Format(@tBandMapPlaceHolder[1], 'NEW %02u%02u', UTC.wMinute, UTC.wSecond);

  tCreateAndAddNewSpot(tBandMapPlaceHolder, False, ActiveRadioPtr);
  DisplayBandMap;
end;



procedure SaveBandMap;

{ Saves the band map data to BandMapFileName }

var
  i                                     : integer;
  Spot                                  : TSpotRecord;
  h                                     : HWND;
begin
  if not tOpenFileForWrite(h, TR4W_BANDMAPBIN_FILENAME) then Exit;
  if SpotsList.Count > 0 then
     begin
     sWriteFile(h, BandMapFileVersion, SizeOf(BandMapFileVersion));
     sWriteFile(h, SpotsList.Count, SizeOf(SpotsList.Count));
     for i := 0 to SpotsList.Count - 1 do
        begin
        Spot := SpotsList.Get(i);
        sWriteFile(h, Spot, SizeOf(TSpotRecord));
        end;
     end;
  CloseHandle(h);

end;

procedure LoadBandMap;
{ Loads band map data from BandMapFileName.  Please only call when the
  program has just started and there isn't any possibility of any band
  map information already being there. }
label
  1;
var
  TempChar                              : AnsiChar;
  i                                     : integer;
  c                                     : integer;
  Spot                                  : TSpotRecord;
  h                                     : HWND;
  lpNumberOfBytesRead                   : Cardinal;
begin
  if not TF.tOpenFileForRead(h, TR4W_BANDMAPBIN_FILENAME) then Exit;
  Windows.ReadFile(h, TempChar, SizeOf(TempChar), lpNumberOfBytesRead, nil);
  if lpNumberOfBytesRead <> SizeOf(TempChar) then
     begin
     goto 1;
     end;
  if TempChar <> BandMapFileVersion then
     begin
     goto 1;
     end;
  Windows.ReadFile(h, c, SizeOf(SpotsList.Count), lpNumberOfBytesRead, nil);
  if c > 0 then
     begin
     for i := 1 to c do
        begin
        ReadFile(h, Spot, SizeOf(TSpotRecord), lpNumberOfBytesRead, nil);
        if lpNumberOfBytesRead = SizeOf(TSpotRecord) then
           begin
           SpotsList.AddSpot(Spot, False);
           end;
        end;
     end;
  1: CloseHandle(h);
end;


procedure UpdateBlinkingBandMapCall;

begin
  if not BandMapEnable then Exit;

  if BandMapBlinkingCallRecord <> nil then
     begin
     with BandMapBlinkingCallRecord^ do
        begin
        StatusByte := StatusByte and $C0;
        StatusByte := (BandMapDecayTime and $3F) or StatusByte;
        end;
     end;

  DisplayBandMap;
end;


procedure UpdateTenMinuteDate(Band: BandType; Mode: ModeType);   //n4af 4.40.9

begin
  if (Band <> TenMinuteTime.Band) or (Mode <> TenMinuteTime.Mode) then
     begin
     TenMinuteTime.Band := Band;
     TenMinuteTime.Mode := Mode;
     TenMinuteTime.Time := GetTickCount;
     end;
end;



function GetRecordForBandMapCursor(var Entry: BandMapEntryPointer; CursorEntryNumber: integer): boolean;
{ KK1L: 6.64 Rewritten as function for possible multiple use. Code updated to work properly }
{       when displaying dupes or not.                                                  }
{ KK1L: 6.65 CursorEntryNumber did not need to be "pass by reference". Changed to "pass by value"}
label
  1, 2;
var
  EntryNumber                           : integer;
  FoundRecord                           : boolean;
  Band {, StartBand, StopBand}          : BandType;
  Mode {, StartMode, StopMode}          : ModeType;

begin

  tSetStartStopBandMode;
  EntryNumber := 0;
  GetRecordForBandMapCursor := False;
  FoundRecord := False;

  for Band := StartBand to StopBand do
     begin
     for Mode := StartMode to StopMode do
        begin

        if (not WARCBandsEnabled) and
          ((Band = Band30) or (Band = Band17) or (Band = Band12)) then
           begin
           Continue; {KK1L: 6.64 Keep band map within contest limits}
           end;

        Entry := BandMapFirstEntryList[Band, Mode];
        while Entry <> nil do
           begin

           if (EntryNumber = CursorEntryNumber) then
              begin {KK1L: 6.64 found a cursor match. Get Entry^ in synch then set BandMapCursorData}
              //          if (not BandMapDupeDisplay) then {KK1L: 6.64 if not displaying dupes find the next non-dupe}
              //            while ((Entry^.StatusByte and $40) <> 0)
              //              and (Entry <> nil) do Entry := Entry^.NextEntry;

      if BandMapDupeDisplay = False then
         begin
         1: if (Entry^.StatusByte and $40) <> 0 then
               begin
               Entry := Entry^.NextEntry;
               if Entry <> nil then
                  begin
                  goto 1;
                  end;
               end;
         end;

      if (Entry <> nil) then
         begin {KK1L: 6.64 Only set data if not nil}
         BandMapCursorData := Entry;
         GetRecordForBandMapCursor := True;
         FoundRecord := True;
         Exit; {KK1L: 6.64 Found a match. Let's get out of here}
         end;
      Break; {KK1L: 6.64 Ran out of entries. Jump out of WHILE Entry <> nil to next Mode/Band}
              end

           else {KK1L: 6.64 not a cursor match. Go to next keeping Entry^ and EntryNumber in synch with display}
              begin
              if BandMapDupeDisplay = False then
                 begin
                 2: if (Entry^.StatusByte and $40) <> 0 then
                       begin
                       Entry := Entry^.NextEntry;
                       if Entry <> nil then
                          begin
                          goto 2;
                          end;
                       end;
                 end;

                      //          if (not BandMapDupeDisplay) then {KK1L: 6.64 if not displaying dupes find the next non-dupe}
                      //            while ((Entry^.StatusByte and $40) <> 0) and (Entry <> nil) do
                      //              Entry := Entry^.NextEntry; {KK1L: 6.64 non-dupe of current cursor}

              if Entry <> nil then {KK1L: 6.64 Only increment if not starting a new band/mode}
                 begin
                 Entry := Entry^.NextEntry;
                 inc(EntryNumber);
                 end;
              end;

           end;
        end;
     end;
end;

procedure DecrementQTCCount(Call: CallString; Count: integer);

var
  Station                               : integer;
//  CompressedCall                   : EightBytes;

begin
//  BigCompressFormat(Call, CompressedCall);

  if (NumberQTCStations = 0) or (Count = 0) then Exit;

  for Station := 0 to NumberQTCStations - 1 do
//    if BigCompressedCallsAreEqual(QTCDataArray^[Station].Call, CompressedCall) then
    if QTCDataArray^[Station].Call = Call then
       begin
       while (QTCDataArray^[Station].NumberQTCs > 0) and (Count > 0) do
          begin
          dec(QTCDataArray^[Station].NumberQTCs);
          dec(Count);
          end;
       end;

end;




procedure DisplayUserInfo(Call: CallString);

var
  data                                  : DataBaseEntryRecord;
  TempString, InfoString, Command       : Str40;
  CustomString                          : ShortString {str40};
  Zone                                  : integer;
  FoundCall                             : boolean;
  Heading                               : integer;
  //qe                                   : pChar;
  //pstr                                 : str80;

begin
  if UserInfoShown = NoUserInfo then Exit;
  if Call = '' then Exit;
  FoundCall := CD.GetEntry(Call, data);

  Windows.ZeroMemory(@InfoString, SizeOf(InfoString));
//  InfoString := '';

  case UserInfoShown of
    NameInfo:
      if FoundCall then
         begin
         InfoString := data.mName;
         end;
    QTHInfo:
      if FoundCall then
         begin
         InfoString := data.QTH;
         end;
    CheckSectionInfo:
      if FoundCall then
         begin
         InfoString := data.Check + data.Section;
         end;
    SectionInfo:
      if FoundCall then
         begin
         InfoString := data.Section;
         end;
    OldCallInfo:
      if FoundCall then
         begin
         InfoString := data.OldCall;
         end;
    FocInfo:
      if FoundCall then
         begin
         InfoString := data.FOC;
         end;
    GridInfo:
      if FoundCall then
         begin
         InfoString := data.Grid;

         if (MyGrid <> '') and LooksLikeAGrid(data.Grid) then
            begin
            //          SaveSetAndClearActiveWindow(BeamHeadingWindow);
        Heading := round(GetBeamHeading(MyGrid, data.Grid));
            //          Write(data.Grid, ' at ', Heading, '?');
                                 //          RestorePreviousWindow;
            end;
         end;

    CQZoneInfo:
      if FoundCall and (data.CQZone <> '') then
         begin
         InfoString := data.CQZone
         end
      else
         begin
         Zone := ctyGetCQZone(Call);
         if Zone > 0 then
            begin
            Str(Zone, InfoString);
            end;
         end;

    ITUZoneInfo:
      if FoundCall and (data.ITUZone <> '') then
         begin
         InfoString := data.ITUZone
         end
      else
         begin
         Zone := ctyGetITUZone(Call);
         if Zone > 0 then
            begin
            Str(Zone, InfoString);
            end;
         end;

    User1Info:
      if FoundCall then
         begin
         InfoString := data.User1;
         end;
    User2Info:
      if FoundCall then
         begin
         InfoString := data.User2;
         end;
    User3Info:
      if FoundCall then
         begin
         InfoString := data.User3;
         end;
    User4Info:
      if FoundCall then
         begin
         InfoString := data.User4;
         end;
    User5Info:
      if FoundCall then
         begin
         InfoString := data.User5;
         end;

    CustomInfo:
      begin
        InfoString := '';
        CustomString := CustomUserString;

        while CustomString <> '' do
           begin
           Command := RemoveFirstString(CustomString);

           if Command = 'CQZONE' then
             if FoundCall and (data.CQZone <> '') then
                begin
                InfoString := InfoString + data.CQZone + ' '
                end
             else
                begin
                Zone := ctyGetCQZone(Call);

                if Zone > 0 then
                   begin
                   Str(Zone, TempString);
                   InfoString := InfoString + TempString + ' ';
                   end;
                end;

           if Command = 'ITUZONE' then
             if FoundCall and (data.ITUZone <> '') then
                begin
                InfoString := InfoString + data.ITUZone + ' '
                end
             else
                begin
                Zone := ctyGetITUZone(Call);

                if Zone > 0 then
                   begin
                   Str(Zone, TempString);
                   InfoString := InfoString + TempString + ' ';
                   end;
                end;

           if Command = 'NAME' then
             if FoundCall and (data.mName <> '') then
                begin
                InfoString := InfoString + data.mName + ' ';
                end;

           if Command = 'QTH' then
             if FoundCall and (data.QTH <> '') then
                begin
                InfoString := InfoString + data.QTH + ' ';
                end;

           if Command = 'SECTION' then
             if FoundCall and (data.Section <> '') then
                begin
                InfoString := InfoString + data.Section + ' ';
                end;

             { If they entered USER # instead of USER#, make it work - 6.75 }

           if Command = 'USER' then
              begin
              Command := RemoveFirstString(CustomString);

              if (Command >= '1') and (Command <= '5') then
                 begin
                 case Command[1] of
                   '1':
                     if FoundCall and (data.User1 <> '') then
                        begin
                        InfoString := InfoString + data.User1 + ' ';
                        end;
                   '2':
                     if FoundCall and (data.User2 <> '') then
                        begin
                        InfoString := InfoString + data.User1 + ' ';
                        end;
                   '3':
                     if FoundCall and (data.User3 <> '') then
                        begin
                        InfoString := InfoString + data.User1 + ' ';
                        end;
                   '4':
                     if FoundCall and (data.User4 <> '') then
                        begin
                        InfoString := InfoString + data.User1 + ' ';
                        end;
                   '5':
                     if FoundCall and (data.User5 <> '') then
                        begin
                        InfoString := InfoString + data.User1 + ' ';
                        end;
                 end;
                 end
              else
                 begin
                 CustomString := Command + ' ' + CustomString; { put it back }
                 end;
              end;

           if Command = 'USER1' then
             if FoundCall and (data.User1 <> '') then
                begin
                InfoString := InfoString + data.User1 + ' ';
                end;

           if Command = 'USER2' then
             if FoundCall and (data.User2 <> '') then
                begin
                InfoString := InfoString + data.User2 + ' ';
                end;

           if Command = 'USER3' then
             if FoundCall and (data.User3 <> '') then
                begin
                InfoString := InfoString + data.User3 + ' ';
                end;

           if Command = 'USER4' then
             if FoundCall and (data.User4 <> '') then
                begin
                InfoString := InfoString + data.User4 + ' ';
                end;

           if Command = 'USER5' then
             if FoundCall and (data.User5 <> '') then
                begin
                InfoString := InfoString + data.User5 + ' ';
                end;

           if Command = 'GRID' then
             if FoundCall and (data.Grid <> '') then
                begin
                InfoString := InfoString + data.Grid + ' ';

                    //              if (MyGrid <> '') and LooksLikeAGrid(data.Grid) then
                    //              begin
                    //                SaveSetAndClearActiveWindow(BeamHeadingWindow);
                    //                Heading := round(GetBeamHeading(MyGrid, data.Grid));
                    //                Write(data.Grid, ' at ', Heading, '?');
                    //    SetTR4WWindowText(BeamHeadingWindowHandle, data.Grid+ ' at '+ inttostr(Heading)+ '*');
                    //                RestorePreviousWindow;
                    //              end;
                end;

           if Command = 'FOC' then
             if FoundCall and (data.FOC <> '') then
          //   begin
                begin
                InfoString := InfoString + data.FOC + ' ';
                end;
         {       pStr := InfoString;
               qe := @pStr;
               QuickDisplay(qe);
               end;       }
           if Command = 'CHECK' then
             if FoundCall and (data.Check <> '') then
                begin
                InfoString := InfoString + data.Check + ' ';
                end;

           if Command = 'OLDCALL' then
             if FoundCall and (data.OldCall <> '') then
                begin
                InfoString := InfoString + data.OldCall + ' ';
                end;

           if Command = 'TENTEN' then
             if FoundCall and (data.TENTEN <> '') then
                begin
                InfoString := InfoString + data.TENTEN + ' ';
                end;
           end;
      end;

  end;

  if InfoString <> '' then
     begin
     //         while length(InfoString) < 32 do
     //            InfoString := ' ' + InfoString + ' ';

   // InfoString is a Str40 local.  The ZeroMemory above was a WORKAROUND for
   // this very read -- zeroing the buffer so the PAnsiChar scan would find a
   // terminator -- and it is left in place as an initializer, no longer as the
   // thing that makes this line correct.
   SetMainWindowText(mweUserInfo, string(InfoString));

     //         Write(InfoString);
     end
  else
     begin
     SetMainWindowText(mweUserInfo, '');
     end;

  //  RestorePreviousWindow;
end;

function RTTYInverse(InputString: string): string;

var
  Address                               : integer;

begin
  if InputString = '' then
     begin
     RTTYInverse := '';
     Exit;
     end;

  for Address := 0 to length(InputString) do
     begin
     case InputString[Address] of
       'E': InputString[Address] := '3';
       'A': InputString[Address] := '-';
       'S': InputString[Address] := ' ';
       'I': InputString[Address] := '8';
       'U': InputString[Address] := '7';
       'D': InputString[Address] := '$';
       'R': InputString[Address] := '4';
       'J': InputString[Address] := '''';
       'N': InputString[Address] := ',';
       'F': InputString[Address] := '!';
       'C': InputString[Address] := ':';
       'K': InputString[Address] := '(';
       'T': InputString[Address] := '5';
       'Z': InputString[Address] := '"';
       'L': InputString[Address] := ')';
       'W': InputString[Address] := '2';
       'H': InputString[Address] := '#';
       'Y': InputString[Address] := '6';
       'P': InputString[Address] := '0';
       'Q': InputString[Address] := '1';
       'O': InputString[Address] := '9';
       'B': InputString[Address] := '?';
       'G': InputString[Address] := '@';
       'M': InputString[Address] := '.';
       'X': InputString[Address] := '/';
       'V': InputString[Address] := ';';

       '3': InputString[Address] := 'E';
       '-': InputString[Address] := 'A';
       ' ': InputString[Address] := 'S';
       '8': InputString[Address] := 'I';
       '7': InputString[Address] := 'U';
       '$': InputString[Address] := 'D';
       '4': InputString[Address] := 'R';
       '''': InputString[Address] := 'J';
       ',': InputString[Address] := 'N';
       '!': InputString[Address] := 'F';
       ':': InputString[Address] := 'C';
       '(': InputString[Address] := 'K';
       '5': InputString[Address] := 'T';
       '"': InputString[Address] := 'Z';
       //{WLI-dup}            '(': InputString [Address] := 'L';
       '2': InputString[Address] := 'W';
       '#': InputString[Address] := 'H';
       '6': InputString[Address] := 'Y';
       '0': InputString[Address] := 'P';
       '1': InputString[Address] := 'Q';
       '9': InputString[Address] := 'O';
       '?': InputString[Address] := 'B';
       '@': InputString[Address] := 'G';
       '.': InputString[Address] := 'M';
       '/': InputString[Address] := 'X';
       ';': InputString[Address] := 'V';
     end;
     end;

  RTTYInverse := InputString;
end;

procedure UpdateK1EAStationInfo(Field: K1EAStationInfoFieldType;
  StationIDChar: AnsiChar;
  MessageString: ShortString {Str20});

var
  Freq                                  : LONGINT;
  {Index,} Result                         : integer;
  //TempString                            : Str20;
  Band                                  : BandType;
  Mode                                  : ModeType;

begin
  GetRidOfPostcedingSpaces(MessageString);
  Val(MessageString, Freq, Result);

  if Result <> 0 then
     begin
     //{WLI}        SendMorse ('ooops');
   Exit;
     end;

  Band := NoBand;

  CalculateBandMode(Freq, Band, Mode);

  if Band = NoBand then
     begin
     Exit;
     end;

  if Field = Pass then
     begin
     K1EAMultiInfo[Band].PassFreq := Freq;
     end;

  if Field = Run then
     begin
     K1EAMultiInfo[Band].RunFreq := Freq;
     end;
end;

procedure WindInit;

//var
 // Band                                  : BandType;
 // Mode                                  : ModeType;
begin
  {
  for Band := Band160 to AllBands do
    for Mode := CW to Both do
    begin
      if MultiStatus[Band, Mode] <> nil then
        Dispose(MultiStatus[Band, Mode]);
      MultiStatus[Band, Mode] := nil;
    end;
    }
  MarkTime(TenMinuteTime.Time);
end;

procedure DispalayDupe;
begin
  TF.Format(QuickDisplayBuffer, TC_ISADUPE, @CallWindowString[1]);

//  DispalayB4(SW_HIDE);
  QuickDisplay(QuickDisplayBuffer);
  if DupeCheckSound <> DupeCheckNoSound then
     begin
     DoABeep(ThreeHarmonics);
     end;
//  SendMessage(wh[mweCall], EM_SETSEL, 0, -1);
//  EscapeDeletedCallEntry := CallWindowString;
  tCleareCallWindow;
end;

procedure DispalayB4(nCmdShow: integer);
begin
  if tB4IndicatorPrevState = nCmdShow then Exit;
  tB4IndicatorPrevState := nCmdShow;
  Windows.ShowWindow(wh[mweQSOB4Status], nCmdShow);
end;

procedure DispalayLogGridLines;
var
  Style                                 : integer;
begin
  if Config.ShowGridlines then
     begin
     Style := LVS_EX_GRIDLINES or LVS_EX_FULLROWSELECT
     end
  else
     begin
     Style := LVS_EX_FULLROWSELECT;
     end;

  ListView_SetExtendedListViewStyle(wh[mweEditableLog], Style);
  Windows.SetWindowLong(wh[mweEditableLog], GWL_STYLE, $5000A005);

  CheckEditableWindowHeight;
end;

procedure DispalayNewMult(nCmndShow: integer);
begin
  if nCmndShow = tNewMultIndicatorPrevState then Exit;
  tNewMultIndicatorPrevState := nCmndShow;
  Windows.ShowWindow(wh[mweNewMultStatus], nCmndShow);
end;

procedure DisplayLocalTime(Country: Word);
label
  1;
var
//  i                                     : integer;
  UTC, LOCAL                            : SYSTEMTIME;
  //Offset                                : LONGINT;
//  p                                     : PChar;
 // SummerTimeIncrementation              : integer;
 // r                                     : integer;
  TZ                                    : TIME_ZONE_INFORMATION;
begin


  if tLocalTimePrevState = Country then Exit;
  tLocalTimePrevState := Country;

  if Country = UNKNOWN_COUNTRY then
     begin
     wsprintfBuffer[0] := #0;
     goto 1;
     end;
  GetSystemTime(UTC);
  Windows.ZeroMemory(@tz, SizeOf(tz));
  TZ.Bias := ctyGetCountryUTCOffset(Country);
  Windows.ZeroMemory(@LOCAL, SizeOf(LOCAL));
  if not SystemTimeToTzSpecificLocalTime(@tz, UTC, LOCAL) then
     begin
     //    ShowSysErrorMessage('TZ');
     end;

//  SummerTimeIncrementation := 0;
//  if (UTC.wMonth > 3) and (UTC.wMonth < 11) then SummerTimeIncrementation := 1000;
//  r := round(ctyGetCountryUTCOffset(Country));
//  i := round(ctyGetCountryUTCOffset(Country) * -1000) + SummerTimeIncrementation;
//  IncSystemTime(UTC, 1 {const} * 6 {minuts} * 6 {hours/10} * i); //1 sec = 1000
{
  asm
  movzx eax,word ptr LOCAL.wDayOfWeek
  mov   eax,[eax*4+PCharDayTags]
  push  eax

  xor  eax ,eax

  mov ax,word ptr LOCAL.wMinute
  push eax

  mov ax,word ptr LOCAL.wHour
  push eax
  end;
  wsprintf(wsprintfBuffer, '%02u:%02u %s');

  asm add esp,20
  end;
}
  TF.Format(wsprintfBuffer, '%02u:%02u %s', integer(LOCAL.wHour), integer(LOCAL.wMinute), PCharDayTags[LOCAL.wDayOfWeek]);
  1:
  SetMainWindowText(mweLocalTime, wsprintfBuffer);
end;


function BandMapEnable: boolean;
begin
  Result := tWindowsExist(tw_BANDMAPWINDOW_INDEX);
end;

procedure DisplayBandMap;
begin
  // Diagnostic: trace every entry into DisplayBandMap so we can see who
  // is calling and what state the gates are in.  Useful for tracking
  // down "bandmap clears unexpectedly" symptoms (issue: bandmap-startup-clear).
  // Booleans rendered as 0/1 via Ord() to avoid pulling SysUtils.BoolToStr
  // through this unit's tangled uses chain.
  logger.Trace('[DisplayBandMap] enter: ' +
               'BandMapEnable=%d, BandMapWindowExists=%d, ' +
               'BandMapPreventRefresh=%d, ' +
               'BandMapBand=%d, BandMapMode=%d, ' +
               'BandMapAllBands=%d, BandMapAllModes=%d, ' +
               'BandMapDupeDisplay=%d, BandMapDisplayCQ=%d, ' +
               'BandMapMultsOnly=%d, WARCBandsEnabled=%d, VHFBandsEnabled=%d, ' +
               'FCount=%d',
    [Ord(BandMapEnable),
     Ord(tWindowsExist(tw_BANDMAPWINDOW_INDEX)),
     Ord(BandMapPreventRefresh),
     Ord(BandMapBand), Ord(BandMapMode),
     Ord(BandMapAllBands),
     Ord(BandMapAllModes),
     Ord(BandMapDupeDisplay),
     Ord(BandMapDisplayCQ),
     Ord(BandMapMultsOnly),
     Ord(WARCBandsEnabled),
     Ord(VHFBandsEnabled),
     SpotsList.Count]);
  if not BandMapEnable then
     begin
     logger.Trace('[DisplayBandMap] exit: BandMapEnable=False');
     Exit;
     end;
  if not tWindowsExist(tw_BANDMAPWINDOW_INDEX) then
     begin
     logger.Trace('[DisplayBandMap] exit: bandmap window does not exist');
     Exit;
     end;
//  if  BandMapPreventRefresh then  Exit;             // GAV  4.45.6
  SpotsList.Display;
  end;

 procedure NextBandMapEntry;
var
  //BandMapEntryRecord                    : BandMapEntryPointer;
 // NumberEntriesDisplayed                : integer;
  Band                                  : BandType;
 // Mode                                  : ModeType;
  CC                                    : integer;
 // CurCursorPosData                      : integer;
 // numberbandentries                     : integer;
  //i: integer;
  j                                  : integer;
  Spot                                  : TSpotRecord;
  //d                                     : pChar;
  //str1                                   : str10;

begin
   TempSpot.FBand := NoBand;
              BMp := 0;
  //            tLB_SETCURSEL(BandMapListBox, 0);
  CC := Windows.SendMessage(BandMapListBox, LB_GETCOUNT, 0, 0);
    if CC = LB_ERR then Exit;
     if Config.TwoRadioMode and Config.QSYInactiveRadio then
        begin
        Band := InactiveRadioptr.BandMemory
        end
       else
          begin
          Band := ActiveRadioptr.BandMemory;
          end;

  //k := Windows.SendMessage(BandMapListBox, LB_GETCURSEL, 0, 0);   // K contains real cursor displacement from top (0)
 //  i := GetBMSelItemData; //SendMessage(BandMapListBox, LB_GETITEMDATA, tLB_GETCURSEL(BandMapListBox), 0);
//  if k = LB_ERR then Exit;

//  Spot := SpotsList.Get(j);



if (K = -1) or (k > CC) then
   begin
   k := 0;
   end;
    for j := k to CC do      // loop thru bm entries looking for match to band and mode
       begin
       CC := Windows.SendMessage(BandMapListBox, LB_GETCOUNT, 0, 0);     // Current Cursor
        Spot := SpotsList.Get(j);                                       // get current spot
     //   GetBandMapBandModeFromFrequency(TempSpot.FFrequency, TempSpot.FBand, TempSpot.FMode);
        CallWindowString := Spot.FCall;
        SetOpMode(SEARCHAndPOUNCEOpMode);
        logger.info('[NEXTBM] CALL = '+ SPOT.FCALL);
        logger.info('Freq = ' + IntToStr(Spot.ffrequency));
        if (Spot.FBand =  InactiveRadioptr.BandMemory) and (Spot.FMode = ActiveMode) and (Config.QSYInactiveRadio) then
           begin
           logger.Info('Enter NextBandMap INACTIVE-Radio: ' + spot.fcall );
           LOGGER.INFO('Freq = ' + IntToStr(Spot.ffrequency));
           PutCallToCallWindow(OnDeckCall);
           TuneRadioToSpot(Spotslist.Get(k), InActiveRadio);
           inc(k);
           break;
           end
         else
        if (Spot.FBand = ActiveRadioptr.BandMemory) and (Spot.FMode = ActiveMode) then
        if not (Config.QSYInactiveRadio) then
           begin
           logger.info('[NEXTBM-Active] CALL = '+ SPOT.FCALL);
           LOGGER.INFO('Freq = ' + IntToStr(Spot.ffrequency));
           PutCallToCallWindow(CallWindowString);
           TuneRadioToSpot(Spotslist.Get(j), ActiveRadio);
           inc(k);
           break;
           end ;


         if j = k then
            begin
            inc(k);
            end;

            if k > CC then
               begin
               k := 0;
               CC := Windows.SendMessage(BandMapListBox, LB_GETCOUNT, 0, 0);
               end;
       end;     // end loop
           if k > CC-1 then
              begin
              k := 0;
              CC := Windows.SendMessage(BandMapListBox, LB_GETCOUNT, 0, 0);
              end;

end;     // end procedure

procedure BMFirst;
begin
              BMp := 0;
              tLB_SETCURSEL(BandMapListBox, 0);

end;


procedure tDisplayAutoCQStatus;
var
  ID                                    : Str10;
begin
  Windows.ZeroMemory(@ID, SizeOf(ID));
  ID := KeyId(AutoCQMemory);
  TF.Format(QuickDisplayBuffer, TC_REPEATING, @ID[1], AutoCQDelayTime);
  SetTextInQuickCommandWindow(QuickDisplayBuffer);
end;


procedure tDispalyOnAirTime;
var
d              : Cardinal;
//OperatingTime                        : integer;
 // PreviousQSOTime                       : TQSOTime;
 // Switch : boolean;

 begin
  if (CallWinKeyDown) and (not Begin_QSO) then              // 4.115.3   dont start timeer until first entry
     begin
     Begin_QSO := True;
     StartCPU := Windows.GetTickCount;
     end;

if (T2 > 0)  then
   begin
   d := Windows.GetTickCount;
    if (d div 1000) mod 2 = 0 then
       begin
       SetMainWindowText(mweOnAirTimeCounter,MillisecondsToFormattedString(d - StartCPU, False)) ;     //  4.115.3
       end;
   end
   else
      begin
      SetMainWindowText(mweOnAirTimeCounter,MillisecondsToFormattedString(0, False))
      end
//  SetMainWindowText(mweOnAirTimeCounter,MillisecondsToFormattedString(TimeSpentByBand[AllBands] * 1000, False));
end;


procedure tDispalyTimeFromLastQSO;      // n4af 4.35.5
{ Try keying on tElapsedTimeFromLastQSO.
Procedure modified by N4AF to also display total OFF TIME.
If it total elapsed drops, enter was pressed so
 save into var d2 contents of tElapsedTimeFromLastQSO on procedure exit to compare to value on entry.
set Constant T1 to length of break time
normally onairtime = elapse since firstSetMainWindowText(mweOnAirTimeCounter,MillisecondsToFormattedString(Windows.GetTickCount-StartCPU, False));  qso. But when elapsed > break, we must save the elapsed time and
subtract break time from it.
Then when elapsed next drops below break length, add saved elapsed to current elapsed.
}
var
  d                                    : Cardinal;
  k                                    : Cardinal;
  //l                                    : Cardinal;
  //TimeDifference                       : Integer;
 //n4af 4.35.5
 begin
 // 4.115.2 remove commented code below
 begin
 T2 := tElapsedTimeFromLastQSO;  // T2 = initial elapsed
 Start := True;
 end;

  d := Windows.GetTickCount - T2;
 //d := a;
 k := Windows.GetTickCount - tElapsedTimeFromLastQSO;     // time from last qso

  if (k div 1000) mod 2 = 0 then         // if 5 seconds elapsed
     begin
     SetMainWindowText(mweLastQSOTime, MillisecondsToFormattedString(k, False));     // display elapsed since last qso
     end;
     tDispalyOnAirTime;
end;

procedure tDispalyMyComputerID;
begin
  CID_TWO_BYTES[0] := ComputerID;
  SetMainWindowText(mweComputerID, string(PAnsiChar(@CID_TWO_BYTES)));
end;

procedure tDispalyPaddleAndFootSwitchStatus;
var
  TempBool                              : LongBool;
begin

  if not DoingPaddle then TempBool := False else TempBool := True;
 // Windows.EnableWindow(wh[mwePaddle], TempBool); //n4af 4.36.7

  if not tDoingFootSwitchEnable then TempBool := False else TempBool := True;
  Windows.EnableWindow(wh[mweFootSwitch], TempBool);
end;

procedure tDisplayCQTotal;
begin
  TF.Format(wsprintfBuffer, TC_CQTOTAL, tRestartInfo.riCQTotalCounter);
  SetMainWindowText(mweCQTotal, wsprintfBuffer);
end;

function CQLabel(Callsign: CallString): boolean;
begin
  Result := False;
  if length(Callsign) < 3 then Exit;
  if (Callsign[1] = 'C') and (Callsign[2] = 'Q') and (Callsign[3] = '/') then
     begin
     Result := True;
     end;
end;


procedure tSetStartStopBandMode;
begin
  if BandMapAllBands then
     begin
     if VHFBandsEnabled then
        begin
        StartBand := Band160;
        StopBand := Band2;
        end
     else
        begin
        StartBand := Band160;
        StopBand := Band12; // Band12 comes after Bands160-10
        end;
     end
  else
     begin
     StartBand := BandMapBand;
     StopBand := BandMapBand;
     end;

  if BandMapAllModes then
     begin
     StartMode := CW;
     StopMode := Phone;
     end
  else
     begin
     StartMode := BandMapMode;
     StopMode := BandMapMode;
     end;

end;

procedure DisplayCountryInformation(FileName: Str80; Call: CallString);

{ This procedure will go search through the file specified and if it
  finds an entry with the country ID for the callsign indicated, it
  will display the data contained after that line, until the next blank
  line if found (up to five lines).  The information will be displayed
  in the editable log window. }

//var
  //FileRead                              : Text;
  //CountryID                             : Str20;
  //FileString                            : Str80;
  //WhereY                                : integer;
begin
end;

procedure FlashQickDisplay;
var
  i                                     : integer;
begin
//  Windows.AnimateWindow(wh[mweQuickCommand], 1000, AW_ACTIVATE or AW_VER_NEGATIVE);
  for i := 0 to 5 do
     begin
     Windows.EnableWindow(wh[mweQuickCommand], LongBool(i mod 2));
     Sleep(100);
     end;

  tFlashQDThreadID := 0;
end;

procedure ShowTourDuration;
var
  IntegerTime                           : integer;
begin
  if TourDuration = 0 then Exit;
  IntegerTime := UTC.wMinute mod TourDuration;
  Windows.SendMessage(TorDurationPrBarWindow, PBM_SETPOS, IntegerTime, 0);

  TF.Format(TempBuffer2, TC_NEWTOUR, IntegerTime, TourDuration);

//  Windows.SetDlgItemTextA(ReminderDlgHandle, 102, TempBuffer2);
  Windows.SetWindowTextA(TorDurationWindow, TempBuffer2);

  if IntegerTime = 1 then
     begin
     SendMessage(TorDurationPrBarWindow, PBM_SETMARQUEE, wParam(False), 40);
     Windows.SetWindowLong(TorDurationPrBarWindow {GetDlgItem(ReminderDlgHandle, 101)}, GWL_STYLE, $50000001);
     end;

  if IntegerTime = 0 then
     begin
     if Sheet.tAutoReset then
        begin
        tClearDupesheet;
        end;
     if (Sheet.tAutoReset and MultReset) then tClearMultsheet; // 4.52.11
     SendMessage(TorDurationPrBarWindow, PBM_SETMARQUEE, wParam(True), 40);
     Windows.SetWindowLong(TorDurationPrBarWindow {GetDlgItem(ReminderDlgHandle, 101)}, GWL_STYLE, $50000009);
     end;
end;

procedure SetListViewColor(Window: TMainWindowElement);
//var rgb: cardinal;
begin
  if wh[Window] = 0 then Exit;
  ListView_SetTextBkColor(wh[Window], tr4wColorsArray[TWindows[Window].mweBackG]);
  ListView_SetBkColor(wh[Window], tr4wColorsArray[TWindows[Window].mweBackG]);
  ListView_SetTextColor(wh[Window], tr4wColorsArray[TWindows[Window].mweColor]);
  

//  Windows.SendMessage(wh[Window], LVM_REDRAWITEMS, 0, LinesInEditableLog - 1);
  Windows.InvalidateRect(wh[Window], nil, True);
end;

procedure UpadateMainWindow;
begin
  Windows.InvalidateRect(tr4whandle, nil, True);
end;

procedure RefreshMainWindowColors;
var
  e: TMainWindowElement;
begin
  // TWO KINDS OF ELEMENT, and only one of them repaints from TWindows.
  //
  // An ordinary element reads tr4wColorsArray[TWindows[e].mweColor] while it is
  // PAINTING (MainUnit ~8470), so invalidating is all it needs.  A LIST VIEW
  // does not: CreateListView pushes the colours into the control with
  // ListView_SetTextBkColor and friends, and the control keeps its own copy.
  // Repainting one redraws it in the colours it was given at creation, which is
  // why changing a colour appeared to do nothing until the next start
  // (NY4I, 2026-08-22).
  //
  // RECORDED AT CREATION, not asked of Windows.  The first version of this
  // called GetClassNameA and compared against 'SysListView32' -- a magic Win32
  // class name and a new Win32 call, added on the day we agreed to stop adding
  // Win32 surface (NY4I, 2026-08-22: "it looks windows-like").  CreateListView
  // already knows which elements it made; having it say so costs nothing, works
  // on any widgetset, and cannot drift.
  if tr4whandle = 0 then
     begin
     Exit;      // startup, before the main window exists
     end;

  for e in ListViewElements do
     begin
     if wh[e] <> 0 then
        begin
        SetListViewColor(e);
        end;
     end;

  Windows.InvalidateRect(tr4whandle, nil, True);
end;

procedure UpadateAutoSend;
begin
  AutoSendEnable := AutoSendCharacterCount > 0;
  DisplayAutoSendCharacterCount;
end;


begin
  WindInit;
end.


