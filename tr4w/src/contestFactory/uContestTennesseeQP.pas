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

(* TENNESSEE QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'tennessee_cty';  WA7BNM: 115;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 8;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: TwoPhoneThreeCW;  ADIFName: 'TN-QSO-PARTY';
   CABName: 'TN-QSO-PARTY';  CountyLineAllowed: True;
   FriendlyName: 'Tennessee QSO Party'

  ---------------------------------------------------------------------------
  THE 2026 RULES, CHECKED AGAINST THE SPONSOR (2026-11-20; the text is
  docs/ContestRules/QSOParties/Tennessee/TN-QSO-PARTY-Rules.txt):

  POINTS -- "3 points per QSO regardless of mode." Until this audit the class
    scored 3 CW, 2 phone and 2 digital (the legacy TwoPhoneThreeCW arm).

  BANDS -- "All amateur bands are valid, with the exception of 60, 30, 17 and
    12 meters." UsesBand; cfVHFBandsEnabled so 6 m and up can be reached.

  MULTIPLIERS (per band) -- a Tennessee entrant counts the counties, the
    states but Tennessee (CountsAsMultiplier), the provinces and "DXCC
    entities ... less USA, Canada, Alaska & Hawaii" -- the DX multiplier,
    in state only, built now (it was confirmed in #88 round 3 and not built).
    An out-of-state entrant counts the counties alone.

  THE EXCHANGE -- "RS(T) and Tennessee County, U.S. state, Canadian
    province/territory, or DXCC entity": a Tennessee entrant is therefore
    given the domestic-or-DX parse (a typed "599 DL" is a DX station); an
    entrant elsewhere works Tennessee stations only.

  K4TCG -- "100 bonus points for each QSO (one per band/mode) with TCG
    headquarters station K4TCG ... All bonus points are added after the
    geographic multiplier": a declared bonus station, 100 once on each band in
    each mode, a credited contact only.

  COUNTY LINES -- "Three and four county lines may not be run
    simultaneously" and the line is "2 rows in the log file, one for each
    county": two counties, as Washington's.

  NOT BUILT, listed on #88: the Tennessee mobile and rover 500 points per
    county with 10 QSOs, and their one multiplier for such a county (the
    entrant's CATEGORY-STATION and county do not reach scoring, #133).

  MODES -- "Phone-SSB, FM (no repeater QSOs) / CW / Digital (Any digital mode
    that supports the required exchange)" -- FM is named, so it is credited
    (as phone). NY4I, 2026-11-20: "That phrase about supporting the exchange
    means FT8, FT4 nor FT2 are allowed" -- even though the sponsor's own dupe
    example names FT8. UsesMode credits CW, phone (FM is phone) and every
    digital submode but FT_SUBMODES; an FT QSO is an automatic X-QSO. The
    ruling covers every sponsor using the phrase (Louisiana, New York, New
    Jersey, Texas, Arkansas state the same list).
 *)
unit uContestTennesseeQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

type
   TContestTennesseeQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'TN' -- but the base makes it abstract
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
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* "Three and four county lines may not be run simultaneously" -- 2. *)
      function GetCountyLineCountiesMax: integer; override;

      (* K4TCG, 100 once on each band in each mode -- the header. *)
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      (* Every band but 60, 30, 17 and 12 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* CW, phone and every digital mode but FT8/FT4/FT2 -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession chooses the exchange by; HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree. *)
      function CountsDXMultiplier: boolean;
   public
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
   public
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* TENNESSEE IS NOT A STATE MULTIPLIER FOR A TENNESSEE ENTRANT --
         #88 round 3 (2026-10-26). See the implementation. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_TN carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 192 of 197 non-state rows are county keys of its
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
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestTennesseeQP.GetDisplayName: string;
begin
   Result := 'Tennessee QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row TENNESSEE QSO PARTY: status candidate; rules https://tnqp.org/rules/;
   rules year 2026. CANDIDATE: date from a calendar, not yet checked against
   the sponsor's rules. *)
function TContestTennesseeQP.GetSchedule: string;
begin
   Result := '1st Sunday of September at 17:00 UTC for 10h';
end;

function TContestTennesseeQP.GetHostState: string;
begin
   Result := 'TN';
end;

function TContestTennesseeQP.GetCabrilloName: string;
begin
   Result := 'TN-QSO-PARTY';
end;

function TContestTennesseeQP.GetADIFContestId: string;
begin
   Result := 'TN-QSO-PARTY';
end;

function TContestTennesseeQP.GetWA7BNMId: integer;
begin
   Result := 115;
end;

function TContestTennesseeQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTennesseeQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTennesseeQP.GetDomesticFileName: string;
begin
   Result := 'tennessee_cty';
end;

function TContestTennesseeQP.GetFriendlyName: string;
begin
   Result := 'Tennessee QSO Party';
end;

function TContestTennesseeQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTennesseeQP.GetExchangeKind: ExchangeType;
begin
   (* The in-state entrant's kind; an entrant elsewhere runs with
      RSTDomesticQTHExchange, stated in DescribeSession. *)
   Result := RSTDomesticOrDXQTHExchange;
end;

(* A TENNESSEE ENTRANT RECEIVES THE RST AND A COUNTY, STATE, PROVINCE OR
   COUNTRY (RSTDomesticOrDXQTH); ANYONE ELSE THE RST AND A COUNTY
   (RSTDomesticQTH) -- the two shapes DescribeSession chooses between, by the
   station test CountsDXMultiplier asks. *)
function TContestTennesseeQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   if CountsDXMultiplier then
      begin
      Result := ExchangeFieldsRSTQTH;
      end
   else
      begin
      Result := ExchangeFieldsRSTQSONumberQTH;
      end;
end;

function TContestTennesseeQP.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   if CountsDXMultiplier then
      begin
      Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
      end
   else
      begin
      Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
      end;
end;

procedure TContestTennesseeQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestTennesseeQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestTennesseeQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestTennesseeQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestTennesseeQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   (* In state a DX station's typed country is written, never an empty
      column (CabrilloReceivedRSTQTHDX tests QTHString). *)
   if CountsDXMultiplier then
      begin
      Result := CabrilloReceivedRSTDomesticQTHOrDXQTH(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
      end;
end;

function TContestTennesseeQP.GetInStateDomesticFileName: string;
begin
   Result := 'tennessee';
end;

function TContestTennesseeQP.GetFlags: TContestFlags;
begin
   (* Multipliers per band; the VHF bands are credited -- the header. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled];
end;

(* "3 points per QSO regardless of mode." A QSO off the bands never reaches
   here (UsesBand). *)
procedure TContestTennesseeQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 3;
end;

function TContestTennesseeQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

function TContestTennesseeQP.GetBonusStations: TBonusStationList;
begin
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'K4TCG';
   Result[0].Points := 100;
   Result[0].Scope := bsOncePerBandAndMode;
end;

function TContestTennesseeQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

(* "All amateur bands are valid, with the exception of 60, 30, 17 and 12
   meters" (60 m has no BandType). *)
function TContestTennesseeQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

(* "Any digital mode that supports the required exchange" -- not FT8, FT4 or
   FT2 (NY4I, 2026-11-20; the header). eNoMode and the generic data modes
   mean "some submode" and are credited. An identity fact: no station is
   asked. *)
function TContestTennesseeQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := DigitalSubmodeAllowed(aExtMode, EVERY_SUBMODE - FT_SUBMODES);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

(* SET-UP -- an entrant outside Tennessee works Tennessee stations only and
   receives a county. *)
procedure TContestTennesseeQP.DescribeSession(const aStation: TStationContext;
                                              aSession: TSessionDefaults);
begin
   if not aStation.InHostState then
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. *)
function TContestTennesseeQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "DXCC entities (see ARRL DXCC list - less USA, Canada, Alaska & Hawaii)":
   for a Tennessee entrant; none for anyone else. *)
function TContestTennesseeQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

function TContestTennesseeQP.DXMultiplierKey(const aQso: ContestExchange;
                                             out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestTennesseeQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestTennesseeQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + aStation.MyState;
end;

(* ONE SEARCH-AND-POUNCE ENTRY MAY CARRY SEVERAL QTHs, at every station --
   M11 S7, 2026-10-14. It was the session's RSTDomesticQTH shape; see
   TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestTennesseeQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := True;
end;

(* TENNESSEE IS NOT A STATE MULTIPLIER FOR A TENNESSEE ENTRANT -- #88
   round 3 (2026-10-26), the sponsor's 2026 rules:
   "U.S. states (49 max/band - do not count Tennessee as a state, District
   of Columbia counts as Maryland)".
   tennessee.dom includes the shared S50.DOM, which holds Tn; an
   in-state entrant's QSO whose domestic multiplier is the host state
   itself earns no multiplier and keeps its points. Outside Tennessee the
   multipliers are the counties, and none is spelled as the state. The
   shared file is never edited for this: other contests read it. *)
function TContestTennesseeQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                aKind: RemainingMultiplierType): boolean;
begin
   Result := not (Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

function TContestTennesseeQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestTennesseeQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_TN';
end;

initialization
   RegisterContest(TENNESSEEQSOPARTY, TContestTennesseeQP);

end.
