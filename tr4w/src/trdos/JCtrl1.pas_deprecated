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
unit JCtrl1;
{$I ..\tr4w.inc}

{$O+}
{$F+}
{$IMPORTEDDATA OFF}
interface

uses Tree,
  TF,
  VC,
  Windows,
  LogGrid,
  LogSCP,
  LogCW,
  LogWind,
  LogDupe,
  ZoneCont,
  LogCfg,
  LogDom,
  LOGDVP,
  Country9,
  LogEdit,
  LogK1EA,
  LOGWAE,
  LogPack,
  LOGDDX,
  LogRadio,
  LogNet,
  BeepUnit,
  LogStuff
{$IFDEF LANG_ENG}, TR4W_CONSTS_ENG{$ENDIF}
{$IFDEF LANG_RUS}, TR4W_CONSTS_RUS{$ENDIF}
{$IFDEF LANG_SER}, TR4W_CONSTS_SER{$ENDIF}
{$IFDEF LANG_ESP}, TR4W_CONSTS_ESP{$ENDIF}
  ;

type
  MenuEntryType = (NoMenuEntry,
    ACC,
    AAU,
    ABE,
    ABC,
    AFF,
    //    AIO,
    ACT,
    AAD,
    ADP,
    ADE,
    ADS,
    AQI,
    AQD,
    ASP,
    ASR, {KK1L: 6.72}
    Arc,
    asc,
    ATI,
    BEN,
    BAB,
    BAM,
    BCW,
    BMD,
    //    BMO, {KK1L: 6.xx}
    BCQ,
    BDD,
    BME,
    BMG,
    BSM,
    BNA,
    BET,
    //      BRL,wli
    BPD,
    SAS,
    CAU,
    CCA, //wli custom caret
    CLF,
    //      CDE,

    CID,
    CNA,
    CEC,
    CAS,
    CCO,
    CIF,
//    CKM,
    CWE,
    CWS,
    CSI, {KK1L: 6.72}
    CWT,
    DEE,
    DIG,
    DIS,
    //    DMF,
    DAR, //DUPE SHEET AUTO RESET
    DCS,
    //      DSE,
    //      DVK,
    DVE,
    //    DVP,
    EES,
    //    EEE,

    EME,
    FWE,
    FWS,
    FSF,
    FSE,
    FSM,
    FPR, {KK1L: 6.71a FrequencyPollRate}
    FME,
    FCR,
    GMC,
    HFE,
    HDP,
    //    HOF,{hour offset}
    //    ICP,
    ITE,
    //    IEX,wli
    IXO, {KK1L: 6.70}
    IEC,
    IFE,
    //    KNE,
    //    KSI,
    KCM,
    LDZ,
    LZC,
    LCI,
    LDQ,
    LFE,
    LRS,
    LRT,
    LSE,
    LFR,
    MSE,
    MCF,
    //      MEN,
    MRM,
    MIM,
    MMO,
    //    MMP,
    MRT,
    MUM,
    //    MBA,// ���� ���������� � *.cfg
    //    MMD,// ���� ���������� � *.cfg
    //    MCL,// ���� ���������� ������ � *.cfg
    MCN,
    MCU,
    MFD,
    MGR,
    MIO,
    MZN,
    NFE,
    NLQ,
    NPP,
    PAL,
    PAR,
    PBS,
    PBP,
    PLF,
    PRM,
    psc, {KK1L: 6.71 Coded for PacketSpotComment started in 6.68}
    PKD,
    PSE,
    SPO, {KK1L: 6.72}
    PSP,
    PBE,
    PMT,
    PHC,
    PSD,
    PCE,
    //    PCL,
    PCM,
    PCA,
    PCN,
    //W_L_I    PEN,
    PBL,
    PTT,
    PTD,
    PVC, {PTT VIA COMMANDS}
    QMD,
    QNB,
    QSX,
    QES,
    QRS,
    QMC,

    { Radio One things }

//    R1CP, { Command Pause }
    R1FA, { Frequency adder }
//    R1ID, { ID Character }
    //    R1PT, { Poll Timeout }
    //    R1TE, { Tracking Enable }
    //    R1US, { Update Seconds }

        { Radio Two things }

    //    R2CP, { Command Pause }
    R2FA, { Frequency adder }
//    R2ID, { ID Character }
    //    R2PT, { Poll Timeout }
    //    R2TE, { Tracking Enable }
    //    R2US, { Update Seconds }

    RCQ,
    RDS,
    RMD,
    SHE,
    SHC,
    SCS,
    SML,
    SAD,
    SCF,
    SQI,
    SIA,
    SPA,
    SEP,
    SKE,
    SIN,
    SLG,
    //    SSP,
    //    SEN,
    SRM,
    SAB,
    SMC,
    SBD,
    SQR,
    SSN, {2.01 wli start sending now key}
    SPS, {KK1L: 6.71 StereoPinState}
    SRP,
    SWP,
    SWR,
    //    TAB,
    TMR,
    TOT,
    TDE, {KK1L: 6.73 TuneDupeCheckEnable}
    TWD,
    TRM,
    URF,
    //      UBC,
    UIS,
    URS,
    VER,
    //      VDE,
    VBE,
    //      VDS,wli
    WFS,
    WUT,
    WBE,
    WEI,
    WCP,
    LastMenuEntry);

var
  FileRead                              : Text;
  ChangedRemainingMults                 : boolean;
  DisplayString                         : Str80;
//  Changed                               : array[MenuEntryType] of boolean;

function Description(Line: MenuEntryType): PAnsiChar;
function DisplayInfoLine(Line: MenuEntryType; Active: boolean): PAnsiChar;

implementation
uses MainUnit,
  uNet;

function Description(Line: MenuEntryType): PAnsiChar;

begin
  case Line of
    NoMenuEntry: Description := '0';

    ACC: Description := 'ALL CW MESSAGES CHAINABLE';
    AAU: Description := 'ALLOW AUTO UPDATE';
    ABE: Description := 'ALT-D BUFFER ENABLE';
    ABC: Description := 'ALWAYS CALL BLIND CQ';
    AFF: Description := 'ASK FOR FREQUENCIES';
    //    AIO: Description := 'ASK IF CONTEST OVER';
    ACT: Description := 'AUTO CALL TERMINATE';
    AAD: Description := 'AUTO ALT-D ENABLE';
    ADP: Description := 'AUTO DISPLAY DUPE QSO';
    ADE: Description := 'AUTO DUPE ENABLE CQ';
    ADS: Description := 'AUTO DUPE ENABLE S AND P';
    AQI: Description := 'AUTO QSL INTERVAL';
    AQD: Description := 'AUTO QSO NUMBER DECREMENT';
    ASP: Description := 'AUTO S&P ENABLE';
    ASR: Description := 'AUTO S&P ENABLE SENSITIVITY'; {KK1L: 6.72}
    Arc: Description := 'AUTO RETURN TO CQ MODE';
    asc: Description := 'AUTO SEND CHARACTER COUNT';
    ATI: Description := 'AUTO TIME INCREMENT';

    BEN: Description := 'BACKCOPY ENABLE';
    BAB: Description := 'BAND MAP ALL BANDS';
    BAM: Description := 'BAND MAP ALL MODES';
    BCW: Description := 'BAND MAP CALL WINDOW ENABLE';
    BMD: Description := 'BAND MAP DECAY TIME';
    BCQ: Description := 'BAND MAP DISPLAY CQ';
    BDD: Description := 'BAND MAP DUPE DISPLAY';
    BME: Description := 'BAND MAP ENABLE';
    BMG: Description := 'BAND MAP GUARD BAND';
    //    BMO: Description := 'BAND MAP MULTS ONLY';
    BSM: Description := 'BAND MAP SPLIT MODE';
    BNA: Description := 'BEEP ENABLE';
    BET: Description := 'BEEP EVERY 10 QSOS';
    //      BRL: Description := 'BIG REMAINING LIST';
    BPD: Description := 'BROADCAST ALL PACKET DATA';

    {KK1L: 6.65}
    SAS: Description := 'CALL WINDOW SHOW ALL SPOTS';
    CAU: Description := 'CALLSIGN UPDATE ENABLE';
    //    CAL: Description := 'CALLSIGN AS LOGIN';
    CCA: Description := 'CUSTOM CARET';
    CLF: Description := 'CHECK LOG FILE SIZE';
    //      CDE: Description := 'COLUMN DUPESHEET ENABLE';
    CID: Description := 'COMPUTER ID';
    CNA: Description := 'COMPUTER NAME';
    CEC: Description := 'CONFIRM EDIT CHANGES';
    CAS: Description := 'CONNECTION AT STARTUP';
    CCO: Description := 'CONNECTION COMMAND';

    CIF: Description := 'COUNTRY INFORMATION FILE';
//    CKM: Description := 'CURTIS KEYER MODE';
    CWE: Description := 'CW ENABLE';
    CWS: Description := 'CW SPEED FROM DATABASE';
    CSI: Description := 'CW SPEED INCREMENT'; {KK1L: 6.72}
    CWT: Description := 'CW TONE';

    DEE: Description := 'DE ENABLE';
    DIG: Description := 'DIGITAL MODE ENABLE';
    DIS: Description := 'DISTANCE MODE';
    //    DMF: Description := 'DOMESTIC FILENAME';

    DAR: Description := 'DUPE SHEET AUTO RESET';
    DCS: Description := 'DUPE CHECK SOUND';
    //      DSE: Description := 'DUPE SHEET ENABLE';
    //      DVK: Description := 'DVK PORT';
    DVE: Description := 'DVP ENABLE';
    //      DVP: Description := 'DVP PATH';

    EES: Description := 'ESCAPE EXITS SEARCH AND POUNCE';
    //    EEE: Description := 'ETHERNET NETWORK ENABLE';

    EME: Description := 'EXCHANGE MEMORY ENABLE';

    FWE: Description := 'FARNSWORTH ENABLE';
    FWS: Description := 'FARNSWORTH SPEED';

    FSF: Description := 'FLOPPY FILE SAVE FREQUENCY';
    FSE: Description := 'FLOPPY FILE SAVE NAME';
    FSM: Description := 'FOOT SWITCH MODE';
    FPR: Description := 'FREQUENCY POLL RATE'; {KK1L: 6.71a}
    FME: Description := 'FREQUENCY MEMORY ENABLE';
    FCR: Description := 'FT1000MP CW REVERSE';

    GMC: Description := 'GRID MAP CENTER';

    HFE: Description := 'HF BAND ENABLE';
    HDP: Description := 'HOUR DISPLAY';
    //    HOF: Description := 'HOUR OFFSET';

    //    ICP: Description := 'ICOM COMMAND PAUSE';
    ITE: Description := 'INCREMENT TIME ENABLE';
    IFE: Description := 'INTERCOM FILE ENABLE';
    //    IEX: Description := 'INITIAL EXCHANGE';
    IXO: Description := 'INITIAL EXCHANGE OVERWRITE'; {KK1L: 6.70}
    IEC: Description := 'INITIAL EXCHANGE CURSOR POS';

    //    KNE: Description := 'K1EA NETWORK ENABLE';
    //    KSI: Description := 'K1EA STATION ID';

    KCM: Description := 'KEYPAD CW MEMORIES';

    LDZ: Description := 'LEADING ZEROS';
    LZC: Description := 'LEADING ZERO CHARACTER';
    LCI: Description := 'LEAVE CURSOR IN CALL WINDOW';
    LDQ: Description := 'LITERAL DOMESTIC QTH';
    LFE: Description := 'LOG FREQUENCY ENABLE';
    LRS: Description := 'LOG RS SENT';
    LRT: Description := 'LOG RST SENT';
    LSE: Description := 'LOG WITH SINGLE ENTER';
    LFR: Description := 'LOOK FOR RST SENT';

    MSE: Description := 'MESSAGE ENABLE';
    MCF: Description := 'MISSINGCALLSIGNS FILE ENABLE';
    //      MEN: Description := 'MOUSE ENABLE';
    MRM: Description := 'MULT REPORT MINIMUM BANDS';
    MIM: Description := 'MULTI INFO MESSAGE';
    MMO: Description := 'MULTI MULTS ONLY';
    //    MMP: Description := 'MMTTY PATH';

    MRT: Description := 'MULTI RETRY TIME';
    MUM: Description := 'MULTI UPDATE MULT DISPLAY';
    //    MBA: Description := 'MULTIPLE BANDS';
    //    MMD: Description := 'MULTIPLE MODES';
    //    MCL: Description := 'MY CALL';
    MCN: Description := 'MY CONTINENT';
    MCU: Description := 'MY COUNTRY';
    MFD: Description := 'MY FD CLASS';
    MGR: Description := 'MY GRID';
    MIO: Description := 'MY IOTA';
    MZN: Description := 'MY ZONE';

    NFE: Description := 'NAME FLAG ENABLE';
    NLQ: Description := 'NO LOG';
    NPP: Description := 'NO POLL DURING PTT';

    PAL: Description := 'PACKET ADD LF';
    PAR: Description := 'PACKET AUTO CR';
    PBS: Description := 'PACKET BAND SPOTS';
    PBP: Description := 'PACKET BEEP';
    PLF: Description := 'PACKET LOG FILENAME';
    PRM: Description := 'PACKET RETURN PER MINUTE';
    psc: Description := 'PACKET SPOT COMMENT'; {KK1L: 6.71 Implimented what I started in 6.68}
    PKD: Description := 'PACKET SPOT DISABLE';
    PSE: Description := 'PACKET SPOT EDIT ENABLE';
    SPO: Description := 'PACKET SPOT PREFIX ONLY'; {KK1L: 6.72}
    PSP: Description := 'PACKET SPOTS';
    PBE: Description := 'PADDLE BUG ENABLE';
    PMT: Description := 'PADDLE MONITOR TONE';
    PHC: Description := 'PADDLE PTT HOLD COUNT';
    PSD: Description := 'PADDLE SPEED';
    PCE: Description := 'PARTIAL CALL ENABLE';
    //    PCL: Description := 'PARTIAL CALL LOAD LOG ENABLE';
    PCM: Description := 'PARTIAL CALL MULT INFO ENABLE';
    PCA: Description := 'POSSIBLE CALLS';
    PCN: Description := 'POSSIBLE CALL MODE';
    //W_L_I    PEN: Description := 'PRINTER ENABLE';
    PBL: Description := 'PTT LOCKOUT';
    PTT: Description := 'PTT ENABLE';
    PTD: Description := 'PTT TURN ON DELAY';
    PVC: Description := 'PTT VIA COMMANDS';

    QMD: Description := 'QSL MODE';
    QNB: Description := 'QSO NUMBER BY BAND';
    QSX: Description := 'QSX ENABLE';
    QES: Description := 'QTC EXTRA SPACE';
    QRS: Description := 'QTC QRS';
    QMC: Description := 'QUESTION MARK CHAR';

    //    R1CP: Description := 'RADIO ONE COMMAND PAUSE';
    R1FA: Description := 'RADIO ONE FREQUENCY ADDER';
//    R1ID: Description := 'RADIO ONE ID CHARACTER';
    //    R1PT: Description := 'RADIO ONE RESPONSE TIMEOUT';
    //    R1TE: Description := 'RADIO ONE TRACKING ENABLE';
    //    R1US: Description := 'RADIO ONE UPDATE SECONDS';

    //    R2CP: Description := 'RADIO TWO COMMAND PAUSE';
    R2FA: Description := 'RADIO TWO FREQUENCY ADDER';
//    R2ID: Description := 'RADIO TWO ID CHARACTER';
    //    R2PT: Description := 'RADIO TWO RESPONSE TIMEOUT';
    //    R2TE: Description := 'RADIO TWO TRACKING ENABLE';
    //    R2US: Description := 'RADIO TWO UPDATE SECONDS';

    RCQ: Description := 'RANDOM CQ MODE';
    RDS: Description := 'RATE DISPLAY';
    RMD: Description := 'REMAINING MULT DISPLAY MODE';

    SHE: Description := 'SAY HI ENABLE';
    SHC: Description := 'SAY HI RATE CUTOFF';
    SCS: Description := 'SCP COUNTRY STRING';
    SML: Description := 'SCP MINIMUM LETTERS';
    SAD: Description := 'SEND ALT-D SPOTS TO PACKET';
    SCF: Description := 'SEND COMPLETE FOUR LETTER CALL';
    SQI: Description := 'SEND QSO IMMEDIATELY';

    SIA: Description := 'SERVER ADDRESS';
    SPA: Description := 'SERVER PASSWORD';
    SEP: Description := 'SERVER PORT';

    SKE: Description := 'SHIFT KEY ENABLE';
    SIN: Description := 'SHORT INTEGERS';
    SLG: Description := 'SHOW LOG GRIDLINES';
    //    SSP: Description := 'SHOW SEARCH AND POUNCE';
    //    SEN: Description := 'SIMULATOR ENABLE';
    SRM: Description := 'SINGLE RADIO MODE';
    SAB: Description := 'SKIP ACTIVE BAND';
    SMC: Description := 'SLASH MARK CHAR';
    SBD: Description := 'SPACE BAR DUPE CHECK ENABLE';
    SQR: Description := 'SPRINT QSY RULE';
    SSN: Description := 'START SENDING NOW KEY'; {KK1L: 6.71}
    SPS: Description := 'STEREO PIN HIGH'; {KK1L: 6.71}
    SRP: Description := 'SWAP PACKET SPOT RADIOS';
    SWP: Description := 'SWAP PADDLES';
    SWR: Description := 'SWAP RADIO RELAY SENSE';

    //    TAB: Description := 'TAB MODE';
    TMR: Description := 'TEN MINUTE RULE';
    TOT: Description := 'TOTAL OFF TIME';
    TDE: Description := 'TUNE ALT-D ENABLE'; {KK1L: 6.73}
    TWD: Description := 'TUNE WITH DITS';
    TRM: Description := 'TWO RADIO MODE';

    URF: Description := 'UPDATE RESTART FILE ENABLE';
    //      UBC: Description := 'USE BIOS KEY CALLS';
    UIS: Description := 'USER INFO SHOWN';
    URS: Description := 'USE RECORDED SIGNS';

    VER: Description := 'VERSION';
    //      VDE: Description := 'VGA DISPLAY ENABLE';
    VBE: Description := 'VHF BAND ENABLE';
    //      VDS: Description := 'VISIBLE DUPESHEET';

    WFS: Description := 'WAIT FOR STRENGTH';
    WUT: Description := 'WAKE UP TIME OUT';
    WBE: Description := 'WARC BAND ENABLE';
    WEI: Description := 'WEIGHT';
    WCP: Description := 'WILDCARD PARTIALS';

    LastMenuEntry: Description := 'ZZZ';
  else Description := '???';
  end;

end;

function DisplayInfoLine(Line: MenuEntryType; Active: boolean): PAnsiChar;
var
  I                                     : integer;
begin
  case Line of
    ACC: if AllCWMessagesChainable then RESULT := ACC1 else RESULT := ACC2;

    AAU: if tAllowAutoUpdate then RESULT := AAU1 else RESULT := AAU2;

    ABE: if AltDBufferEnable then RESULT := ABE1 else RESULT := ABE2;

    ABC: if AlwaysCallBlindCQ then RESULT := ABC1 else RESULT := ABC2;

    AFF: if AskForFrequencies then RESULT := AFF1 else RESULT := AFF2;
    {
        AIO:
          if AskIfContestOver then
            RESULT := ('When program exit, ask if contest over')
          else
            RESULT := ('Do not ask if contest over when exiting');
    }
    ACT:
      if AutoCallTerminate then
         begin
         RESULT := ACT1
         end
      else
         begin
         RESULT := ACT2;
         end;

    AAD:
      if K5KA.ModeEnabled then
         begin
         RESULT := AAD1
         end
      else
         begin
         RESULT := AAD2;
         end;

    ADP:
      if AutoDisplayDupeQSO then
         begin
         RESULT := ADP1
         end
      else
         begin
         RESULT := ADP2;
         end;

    ADE:
      if AutoDupeEnableCQ then
         begin
         RESULT := ADE1
         end
      else
         begin
         RESULT := ADE2;
         end;

    ADS:
      if AutoDupeEnableSandP then
         begin
         RESULT := ADS1
         end
      else
         begin
         RESULT := ADS2;
         end;

    AQI:
      if AutoQSLInterval > 0 then
         begin
         RESULT := AQI1
         end
      else
         begin
         RESULT := AQI2;
         end;

    AQD:
      if AutoQSONumberDecrement then
         begin
         RESULT := AQD1
         end
      else
         begin
         RESULT := AQD2;
         end;

    ASP:
      if AutoSAPEnable then
         begin
         RESULT := ASP1
         end
      else
         begin
         RESULT := ASP2;
         end;

    ASR: RESULT := ASR1;

    Arc:
      if AutoReturnToCQMode then
         begin
         RESULT := ARC1
         end
      else
         begin
         RESULT := ARC2;
         end;

    asc:
      if AutoSendCharacterCount = 0 then
         begin
         RESULT := ASC1
         end
      else
         begin
         RESULT := ASC2;
         end;

    ATI:
      if AutoTimeIncrementQSOs > 0 then
         begin
         RESULT := ATI1
         end
      else
         begin
         RESULT := ATI2;
         end;

    BEN:
      if BackCopyEnable then
         begin
         RESULT := BEN1
         end
      else
         begin
         RESULT := BEN2;
         end;

    BAB:
      if BandMapAllBands then
         begin
         RESULT := BAB1
         end
      else
         begin
         RESULT := BAB2;
         end;

    BAM:
      if BandMapAllModes then
         begin
         RESULT := BAM1
         end
      else
         begin
         RESULT := BAM2;
         end;

    BCW:
      if BandMapCallWindowEnable then
         begin
         RESULT := BCW1
         end
      else
         begin
         RESULT := BCW2;
         end;

    BMD: RESULT := BMD1;

    BCQ:
      if BandMapDisplayCQ then
         begin
         RESULT := BCQ1
         end
      else
         begin
         RESULT := BCQ2;
         end;

    BDD:
      if BandMapDupeDisplay then
         begin
         RESULT := BDD1
         end
      else
         begin
         RESULT := BDD2;
         end;

    BME:
      if BandMapEnable then
        //            Result := ('Band map enabled (needs 42/50 lines)')
         begin
         RESULT := BME1
         end
      else
         begin
         RESULT := BME2;
         end;

    BMG: RESULT := BMG1;

    BSM: case BandMapSplitMode of
        ByCutoffFrequency: RESULT := BSM1;
        AlwaysPhone: RESULT := BSM2;
      end;

    BNA:
      if BeepEnable then
         begin
         RESULT := BNA1
         end
      else
         begin
         RESULT := BNA2;
         end;
    BET:
      if BeepEvery10QSOs then
         begin
         RESULT := BET1
         end
      else
         begin
         RESULT := BET2;
         end;

    {      BRL:
             if BigRemainingList then
                Result := ('Large window for remaining mults')
             else
                Result := ('Normal remaining mults window');
    }
    BPD:
      if Packet.BroadcastAllPacketData then
         begin
         RESULT := BPD1
         end
      else
         begin
         RESULT := BPD2;
         end;

    SAS:
      if CallWindowShowAllSpots then
         begin
         RESULT := SAS1
         end
      else
         begin
         RESULT := SAS2;
         end;

    CAU:
      if CallsignUpdateEnable then
         begin
         RESULT := CAU1
         end
      else
         begin
         RESULT := CAU2;
         end;

    //    CAL: Result := ('Send your callsign to telnet server as login');

    CCA:
      if tr4w_CustomCaret then
         begin
         RESULT := CCA1
         end
      else
         begin
         RESULT := CCA2;
         end;

    CLF:
      if CheckLogFileSize then
         begin
         RESULT := CLF1
         end
      else
         begin
         RESULT := CLF2;
         end;

    {      CDE:
             if ColumnDupeSheetEnable then
                Result := ('Vis dupesheet uses new column/district')
             else
                Result := ('Visible sheet runs districts together');
    }

    CAS: RESULT := CAS1;

    CCO: RESULT := CCO1;

    CID:
      if ComputerID = CHR(0) then
         begin
         RESULT := ('No computer ID set (used for multi')
         end
      else
         begin
         RESULT := ('Computer ID as shown appears in log');
         end;

    CNA: RESULT := CNA1;

    CEC:
      if ConfirmEditChanges then
        //        Result := ('Prompt for Y key when exiting AltE')
         begin
         RESULT := CEC1
         end
      else
         begin
         RESULT := CEC2;
         end;

    CIF: RESULT := CIF1;

//    CKM: RESULT := CKM1;

    CWE:
      if CWEnable then
         begin
         RESULT := CWE1
         end
      else
         begin
         RESULT := CWE2;
         end;

    CWS:
      if CWSpeedFromDataBase then
         begin
         RESULT := CWS1
         end
      else
         begin
         RESULT := CWS2;
         end;

    CSI: RESULT := CSI1;

    CWT:
      begin
        if CWTone > 0 then
           begin
           RESULT := CWT1
           end
        else
          RESULT := CWT2; NoSound;
      end;

    DEE:
      if DEEnable then
         begin
         RESULT := DEE1
         end
      else
         begin
         RESULT := DEE2;
         end;

    DIG:
      if DigitalModeEnable then
         begin
         RESULT := DIG1
         end
      else
         begin
         RESULT := DIG2;
         end;

    DIS: case DistanceMode of
        NoDistanceDisplay: RESULT := DIS1;
        DistanceMiles: RESULT := DIS2;
        DistanceKM: RESULT := DIS3;
      end;

    //    DMF: Result := ('Name of domestic mult file');

    DAR:
      if Sheet.tAutoReset then
         begin
         RESULT := DAR1
         end
      else
         begin
         RESULT := DAR2;
         end;

    DCS: case DupeCheckSound of
        DupeCheckNoSound: RESULT := DCS1;
        DupeCheckBeepIfDupe: RESULT := DCS2;
        DupeCheckGratsIfMult: RESULT := DCS3;
      end;

    {      DSE:
             if Sheet.DupeSheetEnable then
                Result := ('Calls will be added to dupesheet')
             else
                Result := ('Calls will not be added to dupesheet');
    }
    {      DVK:
             if ActiveDVKPort = Tree.NoPort then
                Result := ('No DVK port selected')
             else
                Result := ('DVK enabled on the port shown');
    }
    DVE:
      begin
        if DVPEnable then
           begin
           RESULT := DVE1
           end
        else
           begin
           RESULT := DVE2;
           end;
        DisplayCodeSpeed;
      end;
    //      DVP: Result := ('DVP PATH = ');

    EES:
      if EscapeExitsSearchAndPounce then
         begin
         RESULT := EES1
         end
      else
         begin
         RESULT := EES2;
         end;
    {
  EEE:
    if EthernetNetworkEnable then
      Result := ('TCP network is enabled')
    else
      Result := ('TCP network is disabled');
     }

    EME:
      if ExchangeMemoryEnable then
         begin
         RESULT := EME1
         end
      else
         begin
         RESULT := EME2;
         end;

    FWE:
      if FarnsworthEnable then
         begin
         RESULT := FWE1
         end
      else
         begin
         RESULT := FWE2;
         end;

    FWS: RESULT := FWS1;
    FSF:
      if FloppyFileSaveFrequency = 0 then
         begin
         RESULT := FSF1
         end
      else
         begin
         RESULT := FSF2;
         end;

    FSE: RESULT := FSE1;

    FSM: case FootSwitchMode of
        FootSwitchF1: RESULT := FSM1;
        FootSwitchDisabled: RESULT := FSM2;
        FootSwitchLastCQFreq: RESULT := FSM3;
        FootSwitchNextBandMap: RESULT := FSM4; FootSwitchNextDisplayedBandMap: RESULT := FSM5;
        FootSwitchNextMultBandMap: RESULT := FSM6;
        FootSwitchNextMultDisplayedBandMap: RESULT := FSM7;
        FootSwitchUpdateBandMapBlinkingCall: RESULT := FSM8;
        FootSwitchDupecheck: RESULT := FSM9;
        Normal: RESULT := FSM10;
        QSONormal: RESULT := FSM11;
        QSOQuick: RESULT := FSM12;
        FootSwitchControlEnter: RESULT := FSM13;
        StartSending: RESULT := FSM14;
        SwapRadio: RESULT := FSM15;
        CWGrant: RESULT := FSM16;
      end;

    FPR: RESULT := FPR1;

    FME:
      if FrequencyMemoryEnable then
         begin
         RESULT := FME1
         end
      else
         begin
         RESULT := FME2;
         end;

    FCR:
      if Radio1.FT1000MPCWReverse then
         begin
         RESULT := FCR1
         end
      else
         begin
         RESULT := FCR2;
         end;

    GMC:
      if GridMapCenter = '' then
         begin
         RESULT := GMC1
         end
      else
         begin
         RESULT := GMC2;
         end;

    HFE:
      if HFBandEnable then
         begin
         RESULT := HFE1
         end
      else
         begin
         RESULT := HFE2;
         end;

    HDP: case HourDisplay of
        ThisHour: RESULT := HDP1;
        LastSixtyMins: RESULT := HDP2;
      end;

    //    HOF: RESULT := ('Offset from computer time to UTC time');

    //    ICP: Result := ('Command delay in ms (default = 300)');

    ITE:
      if IncrementTimeEnable then
         begin
         RESULT := ITE1
         end
      else
         begin
         RESULT := ITE2;
         end;

    IFE:
      if IntercomFileenable then
         begin
         RESULT := IFE1
         end
      else
         begin
         RESULT := IFE2;
         end;

    {    IEX: case ActiveInitialExchange of
            NoInitialExchange: Result := ('Only exchange memory used');
            NameInitialExchange: Result := ('Name from TRMASTER database');
            NameQTHInitialExchange: Result := ('Name and QTH from TRMASTER database');
            CheckSectionInitialExchange: Result := ('Check section from TRMASTER database');
            SectionInitialExchange: Result := ('ARRL Section from TRMASTER database');
            QTHInitialExchange: Result := ('QTH from TRMASTER database');
            FOCInitialExchange: Result := ('FOC number from TRMASTER database');
            GridInitialExchange: Result := ('Grid from TRMASTER database');
            ZoneInitialExchange: Result := ('Compute zone from callsign');
            User1InitialExchange: Result := ('Use TRMASTER user 1 field initial ex');
            User2InitialExchange: Result := ('Use TRMASTER user 2 field initial ex');
            User3InitialExchange: Result := ('Use TRMASTER user 3 field initial ex');
            User4InitialExchange: Result := ('Use TRMASTER user 4 field initial ex');
            User5InitialExchange: Result := ('Use TRMASTER user 5 field initial ex');
            CustomInitialExchange: Result := ('Uses CUSTOM INITIAL EXCHANGE STRING');
          end;
    }
          //KK1L: 6.70 KK1L: 6.73 Changed wording to cover expansion of feature to ALL initial exhanges
    IXO:
      if InitialExchangeOverwrite then
         begin
         RESULT := IXO1
         end
      else
         begin
         RESULT := IXO2;
         end;

    IEC: case InitialExchangeCursorPos of
        AtStart: RESULT := IEC1;
        AtEnd: RESULT := IEC2;
      end;
    {
        KNE:
          if K1EANetworkEnable then
            RESULT := ('Use K1EA network protocol')
          else
            RESULT := ('Use N6TR network protocol');
    }
    //    KSI: RESULT := ('Station ID used on K1EA network');

    KCM:
      if KeypadCWMemories then
         begin
         RESULT := KCM1
         end
      else
         begin
         RESULT := KCM1;
         end;

    LDZ:
      if LeadingZeros > 0 then
         begin
         RESULT := LDZ1
         end
      else
         begin
         RESULT := LDZ2;
         end;

    LZC: RESULT := LZC1;

    LCI:
      if LeaveCursorInCallWindow then
         begin
         RESULT := LCI1
         end
      else
         begin
         RESULT := LCI2;
         end;

    LFE:
      if LogFrequencyEnable then
         begin
         RESULT := LFE1
         end
      else
         begin
         RESULT := LFE2;
         end;

    LRS: RESULT := LRS1;

    LDQ:
      if LiteralDomesticQTH then
         begin
         RESULT := LDQ1
         end
      else
         begin
         RESULT := LDQ2;
         end;

    LRT: RESULT := LRT1;

    LSE:
      if LogWithSingleEnter then
         begin
         RESULT := LSE1
         end
      else
         begin
         RESULT := LSE2;
         end;

    LFR:
      if LookForRSTSent then
         begin
         RESULT := LFR1
         end
      else
         begin
         RESULT := LFR2;
         end;

    MSE:
      if MessageEnable then
         begin
         RESULT := MSE1
         end
      else
         begin
         RESULT := MSE2;
         end;

    MCF:
      if tMissCallsFileEnable then
         begin
         RESULT := MCF1
         end
      else
         begin
         RESULT := MCF2;
         end;

    {      MEN:
             if MouseEnable then
                Result := ('Mouse activity enabled')
             else
                Result := ('Mouse disabled');
    }
    MRM: RESULT := MRM1;

    MIM: RESULT := MIM1;

    //    MMP:      Result := 'Full file name of MMTTY.exe';

    MMO:
      if MultiMultsOnly then
         begin
         RESULT := MMO1
         end
      else
         begin
         RESULT := MMO2;
         end;
    MRT: RESULT := MRT1;

    MUM:
      if MultiUpdateMultDisplay then
         begin
         RESULT := MUM1
         end
      else
         begin
         RESULT := MUM2;
         end;

    {    MBA:
          if MultipleBandsEnabled then
            Result := ('You can change bands after 1st QSO')
          else
            Result := ('You can''t change bands after 1st QSO');

        MMD:
          if MultipleModesEnabled then
            Result := ('You can change modes after 1st QSO')
          else
            Result := ('You can''t change modes after 1st QSO');
    }
    //    MCL: Result := ('Call as set by MY CALL in cfg file');
    MCN: RESULT := MCN1;
    MCU: RESULT := MCU1;
    MFD: RESULT := MFD1;
    MGR: RESULT := MGR1;
    MIO: RESULT := MIO1;
    MZN: RESULT := MZN1;
    NFE:
      if NameFlagEnable then
         begin
         RESULT := NFE1
         end
      else
         begin
         RESULT := NFE2;
         end;

    NLQ:
      if NoLog then
         begin
         RESULT := NLQ1
         end
      else
         begin
         RESULT := NLQ2;
         end;

    NPP:
      if NoPollDuringPTT then
         begin
         RESULT := NPP1
         end
      else
         begin
         RESULT := NPP2;
         end;

    PAL:
      if PacketAddLF then
         begin
         RESULT := PAL1
         end
      else
         begin
         RESULT := PAL2;
         end;

    PAR:
      if PacketAutoCR then
         begin
         RESULT := PAR1
         end
      else
         begin
         RESULT := PAR2;
         end;

    PBS:
      if Packet.PacketBandSpots then
         begin
         RESULT := PBS1
         end
      else
         begin
         RESULT := PBS2;
         end;

    PBP:
      if Packet.PacketBeep then
         begin
         RESULT := PBP1
         end
      else
         begin
         RESULT := PBP2;
         end;

    PLF:
      if Packet.PacketLogFileName = '' then
         begin
         RESULT := PLF1
         end
      else
         begin
         RESULT := PLF2;
         end;

    PRM:
      if PacketReturnPerMinute = 0 then
         begin
         RESULT := PRM1
         end
      else
         begin
         // Issue #997: asm wsprintf-push -> TF.Format (PRM2 = '...%u minutes').
         TF.Format(wsprintfBuffer, PRM2, PacketReturnPerMinute);
         RESULT := wsprintfBuffer;
         end;

    psc: RESULT := PSC1;

//KK1L: 6.71 Implimented what I started in 6.68

    PKD:
      if PacketSpotDisable then
         begin
         RESULT := PKD1
         end
      else
         begin
         RESULT := PKD2;
         end;

    PSE:
      if PacketSpotEditEnable then
         begin
         RESULT := PSE1
         end
      else
         begin
         RESULT := PSE2;
         end;

    SPO:
      if PacketSpotPrefixOnly then
         begin
         RESULT := SPO1
         end
      else
         begin
         RESULT := SPO2;
         end;

    PSP:
      if Packet.PacketSpots = AllSpots then
         begin
         RESULT := PSP1
         end
      else
         begin
         RESULT := PSP2;
         end;

    PBE:
      if PaddleBug then
         begin
         RESULT := PBE1
         end
      else
         begin
         RESULT := PBE2;
         end;

    PHC: RESULT := PHC1;

    PMT: RESULT := PMT1;

    PSD:
      if PaddleSpeed = 0 then
         begin
         RESULT := PSD1
         end
      else
         begin
         RESULT := PSD2;
         end;

    PCE:
      if PartialCallEnable then
         begin
         RESULT := PCE1
         end
      else
         begin
         RESULT := PCE2;
         end;
    {
        PCL:
          if PartialCallLoadLogEnable then
            RESULT := ('If new LOG.TRW, partial calls loaded')
          else
            RESULT := ('Partials not loaded from new LOG.TRW');
    }
    PCM:
      if PartialCallMultsEnable then
         begin
         RESULT := PCM1
         end
      else
         begin
         RESULT := PCM2;
         end;

    PCA:
      if PossibleCallEnable then
         begin
         RESULT := PCA1
         end
      else
         begin
         RESULT := PCA2;
         end;

    PCN: case CD.PossibleCallAction of
        AnyCall: RESULT := PCN1;
        OnlyCallsWithNames: RESULT := PCN2;
        LogOnly: RESULT := PCN3;
      end;

    //W_L_I    PEN:      if PrinterEnabled then        Result:=('Each QSO off editable window is printed')      else        Result:=('Real time printing is disabled');
    PBL:
      if PTTLockout then
         begin
         RESULT := PBL1
         end
      else
         begin
         RESULT := PBL2;
         end;

    PTT:
      if PTTEnable then
         begin
         RESULT := PTT1
         end
      else
         begin
         RESULT := PTT2;
         end;

    //      PTD: Result := ('PTT delay before CW sent (* 1.7 ms)');
    PTD: RESULT := PTD1;

    PVC:
      if tPTTViaCommand then
         begin
         RESULT := PVC1
         end
      else
         begin
         RESULT := PVC2;
         end;

    QMD: case ParameterOkayMode of
        Standard: RESULT := QMD1;
        QSLButDoNotLog: RESULT := QMD2;
        QSLAndLog: RESULT := QMD3;
      end;

    QNB:
      if QSONumberByBand then
         begin
         RESULT := QNB1
         end
      else
         begin
         RESULT := QNB2;
         end;

    QES:
      if QTCExtraSpace then
         begin
         RESULT := QES1
         end
      else
         begin
         RESULT := QES2;
         end;

    QRS:
      if QTCQRS then
         begin
         RESULT := QRS1
         end
      else
         begin
         RESULT := QRS2;
         end;

    QSX:
      if QSXEnable then
         begin
         RESULT := QSX1
         end
      else
         begin
         RESULT := QSX2;
         end;

    QMC: RESULT := QMC1;

    //    R1CP: Result := ('Time between commands to radio 1');

    R1FA:
      if Radio1.FrequencyAdder <> 0 then
         begin
         RESULT := R1FA1
         end
      else
         begin
         RESULT := R1FA2;
         end;

//    R1ID: Result := ('Char appended to QSO number for rig 1');

    //    R1PT: Result := ('Response timeout in milliseconds');
    {
        R1TE:
          if Radio1.TrackingEnable then
            Result := ('Radio 1 band/mode tracking enabled')
          else
            Result := ('Radio 1 band/mode tracking disabled');
    }
    {
        R1US:
          if Radio1.UpdateSeconds = 0 then
            Result := ('Normal operation')
          else
            Result := ('# seconds between frequency updates');
    }
    //    R2CP: Result := ('Time between commands to radio 2');

    R2FA:
      if Radio2.FrequencyAdder <> 0 then
         begin
         RESULT := R2FA1
         end
      else
         begin
         RESULT := R2FA2;
         end;

//    R2ID: Result := ('Char appended to QSO number for rig 2');

    //    R2PT: Result := ('Response timeout in milliseconds');
    {
        R2TE:
          if Radio2.TrackingEnable then
            Result := ('Radio 2 band/mode tracking enabled')
          else
            Result := ('Radio 2 band/mode tracking disabled');
    }
    {
        R2US:
          if Radio2.UpdateSeconds = 0 then
            Result := ('Normal operation')
          else
            Result := ('# seconds between frequency updates');
    }
    RCQ:
      if RandomCQMode then
         begin
         RESULT := RCQ1
         end
      else
         begin
         RESULT := RCQ2;
         end;

    RDS: case RateDisplay of
        QSOs: RESULT := RDS1;
        Points: RESULT := RDS2;
        BandQSOs: RESULT := RDS3;
      end;

    RMD: case RemainingMultDisplayMode of
        NoRemainingMults: RESULT := RMD1;
        Erase: RESULT := RMD2;
        HiLight: RESULT := RMD3;
      end;

    SHE:
      if SayHiEnable then
         begin
         RESULT := SHE1
         end
      else
         begin
         RESULT := SHE2;
         end;

    SHC: RESULT := SHC1;

    SCS:
      if CD.CountryString = '' then
         begin
         RESULT := SCS1
         end
      else
         begin
         RESULT := SCS2;
         end;

    SML:
      if SCPMinimumLetters = 0 then
         begin
         RESULT := SML1
         end
      else
         begin
         RESULT := SML2;
         end;

    SAD:
      if SendAltDSpotsToPacket then
         begin
         RESULT := SAD1
         end
      else
         begin
         RESULT := SAD2;
         end;

    SCF:
      if SendCompleteFourLetterCall then
         begin
         RESULT := SCF1
         end
      else
         begin
         RESULT := SCF2;
         end;

    SSN:
      if StartSendingNowKey <> ' ' then
         begin
         // Issue #997: asm wsprintf-push -> TF.Format. SSN1 = 'Use a %c key...';
         // the Format(...; c: Char) overload handles %c (StartSendingNowKey is Char).
         TF.Format(wsprintfBuffer, SSN1, StartSendingNowKey);
         RESULT := wsprintfBuffer;
         end
      else
         begin
         RESULT := SSN2;
         end;

    SPS:
      if StereoPinState then
         begin
         RESULT := SPS1
         end
      else
         begin
         RESULT := SPS2;
         end;

    SQI:
      if SendQSOImmediately then
         begin
         RESULT := SQI1
         end
      else
         begin
         RESULT := SQI2;
         end;

    SIA: RESULT := SIA1;
    SPA: RESULT := SPA1;
    SEP: RESULT := SEP1;
    SKE:
      if ShiftKeyEnable then
         begin
         RESULT := SKE1
         end
      else
         begin
         RESULT := SKE2;
         end;

    SIN:
      if ShortIntegers then
         begin
         RESULT := SIN1
         end
      else
         begin
         RESULT := SIN2;
         end;
    SLG:
      if tLogLogGridlines then
         begin
         RESULT := SLG1
         end
      else
         begin
         RESULT := SLG2;
         end;

    {
        SSP:
          if ShowSearchAndPounce then
            RESULT := ('S&P QSOs marked with "s" in log')
          else
            RESULT := ('S&P QSOs not marked in log');
    }
    {    SEN:
          if DDXState = Off then
            Result := ('Simulator operation disabled')
          else
            Result := ('Simulator operation enabled');
    }

    SRM:
      if not TwoRadioMode then
         begin
         RESULT := SRM1
         end
      else
         begin
         RESULT := SRM2;
         end;

    SAB:
      if SkipActiveBand then
         begin
         RESULT := SAB1
         end
      else
         begin
         RESULT := SAB2;
         end;

    SMC: RESULT := SMC1;

    SBD:
      if SpaceBarDupeCheckEnable then
         begin
         RESULT := SBD1
         end
      else
         begin
         RESULT := SBD2;
         end;

    SQR:
      if SprintQSYRule then
         begin
         RESULT := SQR1
         end
      else
         begin
         RESULT := SQR2;
         end;

    SRP:
      if SwapPacketSpotRadios then
         begin
         RESULT := SRP1
         end
      else
         begin
         RESULT := SRP2;
         end;

    SWP:
      if SwapPaddles then
         begin
         RESULT := SWP1
         end
      else
         begin
         RESULT := SWP2;
         end;

    SWR:
      if SwapRadioRelaySense then
         begin
         RESULT := SWR1
         end
      else
         begin
         RESULT := SWR2;
         end;
    {
        TAB: case TabMode of
            NormalTabMode: RESULT := ('When edit, tab moves to next field');
            ControlFTabMode: RESULT := ('When edit, tab moves to next word');
          end;
    }
    TMR: case TenMinuteRule of
        NoTenMinuteRule: RESULT := TMR1;
        TimeOfFirstQSO: RESULT := TMR2;
      end;

    TOT: RESULT := TOT1;

    TDE:
      if TuneDupeCheckEnable then
         begin
         RESULT := TDE1
         end
      else
         begin
         RESULT := TDE2;
         end;

    TWD:
      if TuneWithDits then
         begin
         RESULT := TWD1
         end
      else
         begin
         RESULT := TWD2;
         end;

    TRM:
      if TwoRadioMode {TwoRadioState <> TwoRadiosDisabled} then
         begin
         RESULT := TRM1
         end
      else
         begin
         RESULT := TRM2;
         end;

    URF:
      if UpdateRestartFileEnable then
         begin
         RESULT := URF1
         end
      else
         begin
         RESULT := URF2;
         end;

    {      UBC:
             if UseBIOSKeyCalls then
                Result := ('Use BIOS for keys - no F11 or F12')
             else
                Result := ('Bypass BIOS - enable F11 and F12 keys');
    }
    URS:
      if tUseRecordedSigns then
         begin
         RESULT := URS1
         end
      else
         begin
         RESULT := URS2;
         end;

    UIS: case UserInfoShown of
        NoUserInfo: RESULT := UIS1;
        NameInfo: RESULT := UIS2;
        QTHInfo: RESULT := UIS3;
        CheckSectionInfo: RESULT := UIS4;
        SectionInfo: RESULT := UIS5;
        OldCallInfo: RESULT := UIS6;
        FocInfo: RESULT := UIS7;
        GridInfo: RESULT := UIS8;
        CQZoneInfo: RESULT := UIS9;
        ITUZoneInfo: RESULT := UIS10;
        User1Info..User5Info:
          begin
            I := Cardinal(UserInfoShown) - 9;
            // Issue #997: asm wsprintf-push -> TF.Format (UIS11 = '...USER %u shown').
            TF.Format(wsprintfBuffer, UIS11, i);
            RESULT := wsprintfBuffer;
          end;
        {
        User1Info: Result := ('Data from TRMASTER USER 1 shown');
        User2Info: Result := ('Data from TRMASTER USER 2 shown');
        User3Info: Result := ('Data from TRMASTER USER 3 shown');
        User4Info: Result := ('Data from TRMASTER USER 4 shown');
        User5Info: Result := ('Data from TRMASTER USER 5 shown');
       }
        CustomInfo: RESULT := UIS12;
      end;

    VER: RESULT := VER1;

    {      VDE:
             if VGADisplayEnable then
                Result := ('VGA mode enabled at program start')
             else
                Result := ('VGA mode disabled at program start');
    }
    VBE:
      if VHFBandsEnabled then
         begin
         RESULT := VBE1
         end
      else
         begin
         RESULT := VBE2;
         end;

    {      VDS:
             if VisibleDupesheetEnable then
                Result := ('Visible dupesheet is displayed')
             else
                Result := ('Visible dupesheet is not displayed');
    }
    WFS:
      if WaitForStrength then
         begin
         RESULT := WFS1
         end
      else
         begin
         RESULT := WFS2;
         end;

    WUT:
      if WakeUpTimeOut = 0 then
         begin
         RESULT := WUT1
         end
      else
         begin
         RESULT := WUT2;
         end;

    WBE:
      if WARCBandsEnabled then
         begin
         RESULT := WBE1
         end
      else
         begin
         RESULT := WBE2;
         end;

    WEI: RESULT := WEI1;

    WCP:
      if WildCardPartials then
         begin
         RESULT := WCP1
         end
      else
         begin
         RESULT := WCP2;
         end;

  end;

  if Active then
     begin
     //W_L_I         TextColor (ActiveColor);
     //W_L_I         TextBackground (ActiveBackground);
     end;

end;

begin

end.

