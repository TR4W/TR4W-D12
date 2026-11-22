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

(* THE ATLANTIC CANADA QSO PARTY -- a NEW contest, registered BY ID
  (2026-11-18, GitHub issue #116).

  ITS ID IS AC-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, THE SECOND WHOSE HOST IS SEVERAL PROVINCES (the
  Canadian Prairies, #117, was the first and made the base change): HostState
  is 'NB NS PE NL', acqp_cty.dom maps each county or division to its province
  with '>', and the ADIF STATE of a county is that province (the base's
  ADIFCountyState through CountyFileHostState). Its skeleton is the Canadian
  Prairies'; what this contest adds is the in-region province multiplier PER
  BAND AND MODE and its bonus stations (below).

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/AtlanticCanada/ --
                  ACQP-Rules-B-V26.0.1.pdf, "Last updated 2026-05-01 V 26.0.1"
                  (saved by NY4I 2026-11-18; acqp.ca refuses automated
                  fetches), and acqp-rules.md, its text.
    the codes     AC-QSO-PARTY-Counties.txt beside them. THE PDF DOES NOT LIST
                  THEM: it gives the counts (NS 18, NB 15, PE 3, NL 11 = 47)
                  and sends the reader to the acqp.ca resources page. The
                  codes are DXLog.net's ACQP.txt ("Updated 2026-09-06"), whose
                  counts are the sponsor's; the names are the ham2k qso-party
                  data's (unverified). A question for NY4I (issue 116).
    DXLog.net     ACQP.txt -- a cross-check only. Where it differs from the PDF
                  the PDF wins: the bonus call VE0CNM (DXLog VE0CMN), the
                  bonus paid per band and mode (DXLog per band), and the bonus
                  ADDED to the score (DXLog adds it to the points before the
                  multiplier).
    ADIF          no Contest_ID for this contest in ADIF 3.1.6's enumeration.
                  AC-QSO-PARTY, the Cabrillo name, is written (below).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "First Sunday of June each year", "1400Z Sunday until 0100Z
    Monday": GetSchedule, 11 hours from 14:00 UTC on the 1st Sunday of June.

  BANDS -- "80-40-20-15-10m only". UsesBand states those five; an off-band
    QSO is an automatic X-QSO.

  MODES -- "SSB, CW, or Mixed modes. No digital modes. No cross mode
    contacts." UsesMode credits CW, Phone and FM (FM is phone -- a choice; the
    rules also say "repeater QSOs are not permitted", a question for NY4I);
    a digital QSO is an automatic X-QSO.

  DUPES -- "Work Atlantic Canada stations once per band/mode": cfQSOByBand and
    cfQSOByMode; "Mobiles/portables that change counties/divisions are
    considered new stations": the party base's received-QTH dupe key.

  QSO POINTS -- "one point per QSO regardless of mode".

  OUT-OF-REGION ENTRANTS -- "Atlantic Canada stations work everyone"; the
    others work Atlantic Canada stations: the party base's host-area rule,
    refused when typed and an automatic X-QSO when logged any other way.

  EXCHANGE -- Atlantic Canada stations send "RS(T), 5-letter province +
    county/division code"; out of region "RS(T) AND province/state
    abbreviation"; "All other non-VE/W stations send RS(T) and "DX."".
    RSTDomesticOrDXQTHExchange, the Canadian Prairies' row: a DX entrant SENDS
    "DX" (ADIFSentRSTStateOrDX, CabrilloSentRSTStateOrDX), and a DX station's
    received column is "DX" (CabrilloReceivedRSTDomesticQTHOrDX).

  MULTIPLIERS -- PER BAND (cfMultByBand), and one kind per band AND MODE:
      Out of region  acqp_cty.dom: the 47 counties and divisions "on each of
                     the five bands" (FCONTEST sets MultipliersIsCounties, so
                     each is its own). No DX multiplier.
      In region      acqp.dom: "Canadian provinces/territories(13), and US
                     States(50)(count DC as MD) ... (63 mults/band)". The 50
                     states (DC as MD) and the other nine provinces and
                     territories are DOMESTIC multipliers, per band. The four
                     Atlantic provinces are earned only through a five-letter
                     code -- "They will receive a provincial multiplier for
                     the first VA/VE1,VE9, VO1/2, or VY2 station worked on each
                     band and mode, including their own province" -- so NB,
                     NS, PE and NL are no received exchange (a display name
                     only), and that province is kept on the PREFIX sheet with
                     the mode in its key ('NSCW', 'NSPH'; FM is PH):
                     PrefixMultiplierKey, set in ParseReceivedExchange because
                     the engine asks for the key before the parse (South
                     Dakota's pattern). The domestic sheet does NOT count it
                     too (CountsAsMultiplier). No engine seam: the sheet's one
                     mode scope (Settings.Mult.ByMode) stays per band, and two
                     keys per province are two slots on it.
                     THE RULES' "63 mults/band" IS A SINGLE-MODE COUNT (59
                     domestic + 4 provinces); a mixed entrant can reach 67.
                     Built from the note's "each band and mode", as DXLog
                     does; a question for NY4I (issue 116).
                     "DX stations do not count as multipliers": no DX
                     multiplier for any entrant.
    A province is the '>' target the in-region table resolved for the QSO
    (DomMultQTH, the sheet's own key -- live, imported and stored alike).

  BONUS STATIONS -- VE1RAC, VE9RAC, VY2RAC, VO1RAC, VO2RAC, VE0CNM, VE0MMA,
    VO1ACQ, VE9ACQ and VA1ACQ: "QSOs with each of these stations will add 5
    Bonus points once per band and mode." Declared data (GetBonusStations,
    bsOncePerBandAndMode); a dupe or an X-QSO earns none (CountsTowardBonus).
    "provide these additional bonus stations to logging vendors ahead of the
    event": the list is the 2026 rules', and changes in code.

  SCORE -- "Score = (QSO x mults) + Bonus": the base's formula (points times
    the sum of every kind) plus the base's bonus.

  COUNTY LINES -- "a separate QSO and complete exchange must be logged for each
    county/division", no maximum: CountyLineCountiesUnlimited, stated. Each
    leg's province key is refreshed by the engine's county-line drain
    (MainUnit.TEntryLegs.BuildLeg asks SetPrefix after the QTH lookup,
    2026-11-18), so an NB/NS line credits both provinces.

  MOBILE AND PORTABLE ENTRANTS -- NOT BUILT, issue #133: the entrant's own
    county changing during the contest. The WORKING side ("considered new
    stations") is the party base's dupe key, inherited.

  "CW contacts must not be made in the phone band segments" -- not checked:
    TR4W knows no band segments.

  CABRILLO -- CONTEST: AC-QSO-PARTY (the rules' example). The line is RST and
    the sent QTH, RST and the received QTH: "QSO: 3799 CW 2024-06-06 1211
    VE1RGO 599 NSANP VE3YT 599 ON" (pinned). MODES CW and PH; FM is PH
    (FormatCabrilloModeDigitalAsRY). The example's "59 NLKGS" is no division
    (KGS is a PE, NB and NS county), so it is pinned through the formatter
    only.

  ADIF -- CONTEST_ID AC-QSO-PARTY. STATE: a county's province (NB, NS, PE or
    NL) from acqp_cty.dom; another station's state or province as itself; none
    for DX. CNTY: NOT written -- ADIF's CNTY enumeration defines nothing for
    Canada.

  THE NEW CONTEST DIALOG -- its own prompt (a five-letter county or division
    code), the host-area box with the area 'NB/NS/PE/NL' and the county file's
    keys, and the outside rule "a state, a province or DX" -- NB, NS, PE and
    NL are refused there (HostState's codes; NF and LB are not, a question).

  SUBMISSION -- "We will only accept logs uploaded via https://www.acqp.ca/logs":
    no address, so ''.

  3830 -- the base's one "Mults" column; the form was not checked. *)
unit uContestAtlanticCanadaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   (* ITS ID -- stored data; see the header. *)
   AC_QSO_PARTY_CONTEST_ID = 'AC-QSO-PARTY';

type
   TContestAtlanticCanadaQP = class(TContestStateQSOPartyBase)
   private
      (* THE ATLANTIC PROVINCE A QSO'S RECEIVED CODE COUNTS AS -- NB, NS, PE
         or NL, the '>' target the session's table resolved (DomMultQTH); ''
         for any other QSO. In region only a five-letter code resolves to one
         of them: the four two-letter codes are no received exchange. *)
      function AtlanticProvinceOf(const aQso: ContestExchange): string;
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      function GetFriendlyName: string; override;
      (* THE FOUR PROVINCES, blank-separated -- see the header. *)
      function GetHostState: string; override;
      (* The words of the New Contest box, "I am in NB/NS/PE/NL". *)
      function GetQSOPartyArea: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetInStateDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetFlags: TContestFlags; override;
      (* "a separate QSO ... for each county/division", no maximum. *)
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* 1 point on CW, phone and FM. Protected, as on TContestBase: ScoreQSO
         is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* THE TEN BONUS STATIONS, 5 points once per band and mode. *)
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
      (* THE TOTALS GRID'S PREFIX ROW SAYS PROVINCES -- a label only. *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   public
      (* 80, 40, 20, 15 and 10 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* CW and PH; FM is PH -- the header. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;
      (* ' 5NN ' and the county, state or province this station sends; DX
         when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* THE PARTY'S PARSE, THEN THE PROVINCE KEY -- the header. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* IN REGION, AN ATLANTIC PROVINCE IS THE PREFIX SHEET'S, NOT THE
         DOMESTIC SHEET'S -- the header. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      (* THE MULTIPLIERS -- counties, or states and provinces, from the
         domestic file; the Atlantic provinces per band and mode in region;
         no DX or zone multiplier for any entrant. *)
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      (* In region only -- the province key. *)
      function HasPrefixMultiplier: boolean; override;
      (* In region: True, with the province and mode ('NSCW', 'NSPH') or ''.
         Out of region: False, as HasPrefixMultiplier is. *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* NO ADIF CNTY -- the header. *)
      function WritesADIFCounty: boolean; override;
      (* ITS OWN NEW CONTEST PROMPT. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_AC carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 41 of 41 non-state rows are county keys of its
         own county file (Pennsylvania: its in-state file pa.dom, which holds the ARRL sections); the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* FormatCabrilloModeDigitalAsRY -- FM is PH. *)
   uCabrilloFormat,
   (* SNewContestACQPCountyOrLocation, STotalsProvinceMults *)
   uAppStrings,
   uContestRegistry;

function TContestAtlanticCanadaQP.GetDisplayName: string;
begin
   Result := 'Atlantic Canada QSO Party';
end;

(* WHEN IT RUNS -- the rules V 26.0.1: "First Sunday of June each year",
   "1400Z Sunday until 0100Z Monday" (11 hours). *)
function TContestAtlanticCanadaQP.GetSchedule: string;
begin
   Result := '1st Sunday of June at 14:00 UTC for 11h';
end;

function TContestAtlanticCanadaQP.GetFriendlyName: string;
begin
   Result := 'Atlantic Canada QSO Party';
end;

function TContestAtlanticCanadaQP.GetHostState: string;
begin
   (* New Brunswick, Nova Scotia, Prince Edward Island, Newfoundland and
      Labrador -- each county names its own in acqp_cty.dom. *)
   Result := 'NB NS PE NL';
end;

function TContestAtlanticCanadaQP.GetQSOPartyArea: string;
begin
   Result := 'NB/NS/PE/NL';
end;

function TContestAtlanticCanadaQP.GetCabrilloName: string;
begin
   (* The rules' Cabrillo example, "CONTEST: AC-QSO-PARTY"; DXLog's too. *)
   Result := 'AC-QSO-PARTY';
end;

function TContestAtlanticCanadaQP.GetADIFContestId: string;
begin
   (* Not in ADIF's Contest_ID enumeration -- the header. Export writes it,
      import matches it. *)
   Result := AC_QSO_PARTY_CONTEST_ID;
end;

function TContestAtlanticCanadaQP.GetWA7BNMId: integer;
begin
   (* Not known: the calendar bars automated access, and no research has
      recorded one (issue 116). *)
   Result := 0;
end;

function TContestAtlanticCanadaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestAtlanticCanadaQP.GetSubmissionEmail: string;
begin
   (* "We will only accept logs uploaded via https://www.acqp.ca/logs" -- no
      address takes logs. *)
   Result := '';
end;

function TContestAtlanticCanadaQP.GetDomesticFileName: string;
begin
   (* The county and division file. FCONTEST.FoundMyStateInDomFile reads it
      to decide whether MY STATE is an Atlantic Canada code, and then loads
      acqp.dom or this file; the ADIF export reads its '>' provinces. *)
   Result := 'acqp_cty';
end;

function TContestAtlanticCanadaQP.GetInStateDomesticFileName: string;
begin
   Result := 'acqp';
end;

function TContestAtlanticCanadaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestAtlanticCanadaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestAtlanticCanadaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestAtlanticCanadaQP.GetFlags: TContestFlags;
begin
   (* "once per band/mode"; multipliers "on each of the five bands" and "63
      mults/band" -- the per-mode province is the prefix key's, not a flag. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestAtlanticCanadaQP.GetCountyLineCountiesMax: integer;
begin
   (* "a separate QSO and complete exchange must be logged for each
      county/division" -- no maximum. The base's value, stated so the rule is
      read here. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestAtlanticCanadaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* "All other non-VE/W stations send RS(T) and "DX."" -- a DX entrant sends
   DX (Georgia's row). *)
function TContestAtlanticCanadaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestAtlanticCanadaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestAtlanticCanadaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* DX whenever the record holds no domestic QTH. *)
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

(* ONE POINT, CW, PHONE OR FM. An off-band or off-mode QSO never reaches
   here, nor a station this entrant may not credit. *)
procedure TContestAtlanticCanadaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestAtlanticCanadaQP.GetBonusStations: TBonusStationList;
const
   (* The rules V 26.0.1, "Bonus Stations": the RAC club calls, then the
      "specific station callsigns". VE0CNM is the PDF's spelling (DXLog's
      VE0CMN is not followed). *)
   CALLS: array[0..9] of string = (
      'VE1RAC', 'VE9RAC', 'VY2RAC', 'VO1RAC', 'VO2RAC',
      'VE0CNM', 'VE0MMA', 'VO1ACQ', 'VE9ACQ', 'VA1ACQ');
var
   i: integer;
begin
   Result := nil;
   SetLength(Result, Length(CALLS));
   for i := 0 to High(CALLS) do
      begin
      Result[i].Call := CALLS[i];
      Result[i].Points := 5;
      Result[i].Scope := bsOncePerBandAndMode;
      end;
end;

function TContestAtlanticCanadaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   (* A valid contact: no dupe, no X-QSO. *)
   Result := IsCreditedContact(aQso);
end;

function TContestAtlanticCanadaQP.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.PrefixMultsCaption := STotalsProvinceMults;
   Result.PrefixMultsCaptionCW := 'CW Provs';
   Result.PrefixMultsCaptionPhone := 'Ph Provs';
end;

function TContestAtlanticCanadaQP.UsesBand(aBand: BandType): boolean;
begin
   (* "Bands: 80-40-20-15-10m only." *)
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

(* CW and phone, FM being phone. Any submode of CW, Phone or FM is credited
   -- eNoMode and eData included, as the contract asks -- and no submode of
   Digital is. An identity fact: no station is asked. *)
function TContestAtlanticCanadaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestAtlanticCanadaQP.CabrilloModeString(aMode: ModeType;
                                                     aExtMode: ExtendedModeType): string;
begin
   Result := FormatCabrilloModeDigitalAsRY(aMode, aExtMode);
end;

function TContestAtlanticCanadaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): an
      Atlantic Canada station's five-letter code, anyone else's state or
      province. A DX entrant states none, or DX, and sends DX. *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

function TContestAtlanticCanadaQP.AtlanticProvinceOf(const aQso: ContestExchange): string;
begin
   Result := UpperCase(Trim(string(aQso.DomMultQTH)));
   if (Length(Result) <> 2) or
      (Pos(' ' + Result + ' ', ' ' + HostState + ' ') = 0) then
      begin
      Result := '';
      end;
end;

function TContestAtlanticCanadaQP.ParseReceivedExchange(const aText: string;
                                                        const aSession: TReceivedExchangeSession;
                                                        var aExch: ContestExchange;
                                                        out aErrorMessage: string): boolean;
var
   key: PrefixMultiplierString;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);

   (* THE PROVINCE KEY, NOW THAT THE QTH IS RESOLVED -- the engine asked
      before the parse (the header). *)
   if Result and PrefixMultiplierKey(aExch, key) then
      begin
      aExch.Prefix := key;
      end;
end;

function TContestAtlanticCanadaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                     aKind: RemainingMultiplierType): boolean;
begin
   Result := inherited CountsAsMultiplier(aQso, aKind);
   if Result and
      (aKind = rmDomestic) and
      Station.InHostState and
      (AtlanticProvinceOf(aQso) <> '') then
      begin
      (* The province is the prefix sheet's, per band and mode. *)
      Result := False;
      end;
end;

function TContestAtlanticCanadaQP.HasDXMultiplier: boolean;
begin
   (* "DX stations do not count as multipliers". *)
   Result := False;
end;

function TContestAtlanticCanadaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestAtlanticCanadaQP.HasPrefixMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

function TContestAtlanticCanadaQP.PrefixMultiplierKey(const aQso: ContestExchange;
                                                      out aKey: PrefixMultiplierString): boolean;
var
   province: string;
begin
   aKey := '';
   Result := HasPrefixMultiplier;
   if not Result then
      begin
      Exit;
      end;
   province := AtlanticProvinceOf(aQso);
   if province = '' then
      begin
      Exit;
      end;
   case aQso.Mode of
      CW:
         begin
         aKey := ShortString(province + 'CW');
         end;
      Phone, FM:
         begin
         aKey := ShortString(province + 'PH');
         end;
      else
         begin
         aKey := '';
         end;
      end;
end;

function TContestAtlanticCanadaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* ADIF's CNTY enumeration defines nothing for Canada (British Columbia,
   Ontario, Quebec): a county or division here is no ADIF county. *)
function TContestAtlanticCanadaQP.WritesADIFCounty: boolean;
begin
   Result := False;
end;

procedure TContestAtlanticCanadaQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestACQPCountyOrLocation, ncfMyState);
end;

function TContestAtlanticCanadaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestAtlanticCanadaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_AC';
end;

initialization
   RegisterContestById(AC_QSO_PARTY_CONTEST_ID, TContestAtlanticCanadaQP);

end.
