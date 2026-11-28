(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* ARIZONA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: 'info@azqp.org';  DF: 'arizona_cty';  WA7BNM: 482;
   QRZRUID: 0;  Pxm: NoPrefixMults;  ZnM: NoZoneMults;
   AIE: NoInitialExchange;  DM: DomesticFile;  P: 19;
   AE: RSTDomesticOrDXQTHExchange;  XM: ARRLDXCCWithNoUSAOrCanada;
   QP: OnePhoneTwoCW;  ADIFName: 'AZ-QSO-PARTY';
   CABName: 'AZ-QSO-PARTY';  FriendlyName: 'Arizona QSO Party'

  THE ONE OF THE TEN WHOSE ROW CARRIES NO CountyLineAllowed FIELD AT ALL, so it
  reads as False. THAT MEANS UNKNOWN, NOT ZERO. A missing field is the record's
  default and not a decision anybody made -- four other single-state parties are
  in the same position -- so inferring "no county line permitted" from it would
  invent a rule out of an absence. Michigan's none came from the sponsor's own
  words; nothing comparable has been read for Arizona, so it inherits unlimited
  with every other unlooked-up party and TR4W's behaviour is unchanged.

  IT IS ALSO THE ONLY ONE OF THE TEN WITH DX MULTIPLIERS: XM is
  ARRLDXCCWithNoUSAOrCanada, where the other nine are NoDXMults. Stated as a
  literal like the rest of the row; nothing else about it moves here.

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- which is exactly
  what TR4W does today, because nothing in the program has ever counted the
  queued counties.

  THAT IS "NOT LOOKED UP YET", NOT "UNLIMITED BY DECISION", and the difference
  matters: a number here would have to come from the sponsor's published rules,
  the way Florida's two and California's four did. It must NOT be derived from
  ContestsArray's CountyLineAllowed boolean, which carries no limit at all --
  reading it as a number is the defect that made a class of any kind start
  refusing a two-QTH exchange. (The 2026 rules, below, now say so: county
  lines are logged as several contacts, with no maximum stated.)

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (2026-11-20; "AZQP Rules
  2026, Rev 2502 10/05/2026", the PDF NY4I saved to
  docs/ContestRules/QSOParties/Arizona/, beside the county list).

  PERIOD -- "1500z Oct 10 to 0500z Oct 11, 2026 [2nd October Saturday]":
    GetSchedule, unchanged.

  BANDS AND MODES -- "MODES: CW, Phone"; "BANDS: 160, 80, 40, 20, 15, 10
    meters". UsesBand, UsesMode (FM is phone); a digital or WARC QSO is an
    automatic X-QSO. Neither was stated before: digital scored 1.

  POINTS -- "CW=2; Phone=1". Unchanged.

  EXCHANGE -- an Arizona station sends "RS(T) and 3-letter county
    abbreviation"; anyone else "RS(T) and 2-letter state or Canadian
    province / territory", a DX station "RS(T) and DXCC prefix". No serial:
    the received fields are RST and QTH at every station (they declared a
    QSO number outside Arizona, so ADIF wrote an SRX).

  MULTIPLIERS -- "Arizona stations: ... the 50 US states, the 13 Canadian
    provinces and territories, and DXCC countries. Multipliers count again
    for each mode" (MultByBand False in state, DescribeSession); "Stations
    outside of Arizona: ... the 15 Arizona counties. Multipliers count again
    for each band and mode." So:
      - the DX multiplier is an Arizona entrant's only (HasDXMultiplier),
        and keyed on every country but the USA, Canada, Hawaii and Alaska --
        KH6 and KL7 are two of the 50 states;
      - "A valid contact consists of ... an Arizona station (AZ) and any
        other station (Non-AZ or AZ)": an Arizona entrant's QSO with an
        Arizona county earns the state AZ. arizona.dom listed the counties
        behind a bracketed, never-followed include line, so an in-state
        county was not in the table at all; each county now maps to Az
        there (Idaho's form), and arizona_cty.dom -- the out-of-state
        file, where each county is its own multiplier -- is unchanged.

  BONUS -- "a one-time bonus of 100 points for a QSO with K7A on any band or
    mode", added after multiplying: GetBonusStations, bsOnce, valid contacts
    only (CountsTowardBonus).

  RECEIVED COLUMN, IN STATE -- the party base's
    CabrilloReceivedLoggedLocation: what was logged, else the DX prefix
    (2026-11-27).

  A DX ENTRANT SENDS ITS DXCC PREFIX (2026-11-27; until then these sent
    columns wrote "DX" for one). *)
unit uContestArizonaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

type
   TContestArizonaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'AZ' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      (* THE DX STATION RULE -- see TDXExchangeRule. *)
      function GetDXExchangeRule: TDXExchangeRule; override;
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* K7A, 100 points once -- the header. *)
      function GetBonusStations: TBonusStationList; override;

      (* A K7A contact pays only if it is neither a dupe nor an X-QSO. *)
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      (* 160-10 m without WARC; CW and phone -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_AZ carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 99 of 105 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestArizonaQP.GetDisplayName: string;
begin
   Result := 'Arizona QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row ARIZONA QSO PARTY: status verified; rules https://www.azqp.org/rules;
   rules year 2026. *)
function TContestArizonaQP.GetSchedule: string;
begin
   Result := '2nd Saturday of October at 15:00 UTC for 14h';
end;

function TContestArizonaQP.GetHostState: string;
begin
   Result := 'AZ';
end;

function TContestArizonaQP.GetCabrilloName: string;
begin
   Result := 'AZ-QSO-PARTY';
end;

function TContestArizonaQP.GetADIFContestId: string;
begin
   Result := 'AZ-QSO-PARTY';
end;

function TContestArizonaQP.GetWA7BNMId: integer;
begin
   Result := 482;
end;

function TContestArizonaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestArizonaQP.GetSubmissionEmail: string;
begin
   Result := 'info@azqp.org';
end;

function TContestArizonaQP.GetDomesticFileName: string;
begin
   Result := 'arizona_cty';
end;

function TContestArizonaQP.GetFriendlyName: string;
begin
   Result := 'Arizona QSO Party';
end;

function TContestArizonaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestArizonaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

(* THE RST AND A QTH, ON BOTH SIDES OF THE STATE LINE -- "Arizona stations:
   Send signal report RS(T) and 3-letter county abbreviation"; "Stations
   outside of Arizona: Send signal report RS(T) and 2-letter state or
   Canadian province / territory. DX stations send signal report RS(T) and
   DXCC prefix." No serial is sent by anyone (2026-11-20 audit: an entrant
   outside Arizona declared a QSO number since M11 S9a, transcribed from
   the RSTDomesticQTH shape, so its ADIF wrote an SRX the sponsor never
   sends). *)
function TContestArizonaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestArizonaQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   if Station.InHostState then
      begin
      Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
      end
   else
      begin
      Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
      end;
end;

procedure TContestArizonaQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   (* The station test the parse format chooses by: an entrant inside
      the host state receives the domestic-or-DX exchange and gets no
      default messages (the old `case` had no arm for its shape). *)
   if not Station.InHostState then
      begin
      aMessages.WriteRSTStateOrQSONumber;
      end;
end;

function TContestArizonaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestArizonaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   (* WHAT THE CABRILLO SENT COLUMN SAYS (below): the host state's entrant
      sends its state, anyone else its state, or its prefix when it has none. *)
   if Station.InHostState then
      begin
      Result := ADIFSentRSTState(aMy, aQso);
      end
   else
      begin
      (* A DX entrant has no state and sends its prefix. *)
      Result := ADIFSentRSTState(SentLocation(aMy), aQso);
      end;
end;

function TContestArizonaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   if Station.InHostState then
      begin
      Result := CabrilloSentRSTState(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
      end;
end;

function TContestArizonaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   (* In state: what was logged, else the DX station's prefix (the party
      base). Out of state every QSO is with an Arizona county. *)
   if Station.InHostState then
      begin
      Result := CabrilloReceivedLoggedLocation(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
      end;
end;

(* The sponsor: "DX stations send signal report RS(T) and DXCC prefix." *)
function TContestArizonaQP.GetDXExchangeRule: TDXExchangeRule;
begin
   Result := dxrPrefixOrDX;
end;

function TContestArizonaQP.GetInStateDomesticFileName: string;
begin
   Result := 'arizona';
end;

function TContestArizonaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode];
end;

(* "QSO POINTS: CW=2; Phone=1". FM is phone. A digital QSO never reaches
   here since the 2026-11-20 audit (UsesMode: "MODES: CW, Phone"); the
   third number stays the phone value D7's OnePhoneTwoCW gave it. *)
procedure TContestArizonaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* "Receive a one-time bonus of 100 points for a QSO with K7A on any band or
   mode during the contest." "Total Score = (QSO POINTS x MULTIPLIERS) +
   BONUS POINTS." *)
function TContestArizonaQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'K7A';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
end;

(* A VALID CONTACT ONLY: not a dupe, and not an X-QSO (IsCreditedContact,
   the base's one statement of it -- British Columbia's form). *)
function TContestArizonaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

(* "BANDS: 160, 80, 40, 20, 15, 10 meters". *)
function TContestArizonaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* "MODES: CW, Phone". Any submode of CW, Phone or FM -- FM is a phone mode,
   simplex; the sponsor's "repeater contacts are not permitted" is the
   operator's to observe -- and no submode of Digital. An identity fact: no
   station is asked. *)
function TContestArizonaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestArizonaQP.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.SetCQMemory(CW, smkF1, 'CQ AZ \ \ AZ');
   aSession.SetCQMemory(CW, smkF2, 'CQ^AZ CQ^AZ \ \ AZQP');
   aSession.CQExchangeCW := aStation.MyState;
   aSession.SPExchangeCW := aStation.MyState;
   aSession.QSLCW := '73 \/AZ ';

   (* BOTH SIDES OF THE STATE LINE, STATED (inventory D8). The trait is the
      row's RSTDomesticOrDXQTHExchange, and an in-state station keeps it;
      out of state the exchange is the county alone. *)
   if aStation.InHostState then
      begin
      aSession.MultByBand := False;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

(* A DX MULTIPLIER FOR AN ARIZONA STATION ONLY -- the 2026-11-20 audit:
   "Arizona stations: Multipliers are the 50 US states, the 13 Canadian
   provinces and territories, and DXCC countries"; "Stations outside of
   Arizona: Multipliers are the 15 Arizona counties." It was True at every
   station (the trait ARRLDXCCWithNoUSAOrCanada, M11 S4 part 2), so an
   entrant outside Arizona could count a DX entity. HasDXMultiplier, the key
   and the country list ask this one test, so they cannot disagree. *)
function TContestArizonaQP.HasDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* THE DX MULTIPLIER KEY -- every country but the USA, Canada, Hawaii and
   Alaska (uDXMultiplierKey's one routine, issue #136): Hawaii and Alaska are
   two of "the 50 US states", so a KH6 or KL7 station is a state multiplier
   and not also a DXCC one. Until the 2026-11-20 audit the key was every
   country but the USA and Canada, which counted KH6 and KL twice. *)
function TContestArizonaQP.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(HasDXMultiplier, aQso, aKey);
end;

(* THE CTY COUNTRY LIST -- DXCC where the entrant counts the DX multiplier,
   the CQ list where it counts none. *)
function TContestArizonaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(HasDXMultiplier);
end;

(* OUT OF THE HOST STATE ONE ENTRY MAY CARRY SEVERAL QTHs (RSTDomesticQTH);
   in it, not (RSTDomesticOrDXQTH) -- M11 S7, 2026-10-14. It was the
   session's shape, and this is the station test DescribeSession chooses the
   shape by; see TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestArizonaQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := not Station.InHostState;
end;

function TContestArizonaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestArizonaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_AZ';
end;

initialization
   RegisterContest(ArizonaQsoParty, TContestArizonaQP);

end.
