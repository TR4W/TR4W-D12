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

(* THE SOUTH DAKOTA QSO PARTY -- a NEW contest, registered BY ID (2026-11-18,
  GitHub issue #129).

  ITS ID IS SD-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state entrant works
  only South Dakota stations (the base's host-area rule, design 7.10, Q107).
  Its skeleton is a copy of uContestKentuckyQP (issue 129's instruction); its
  exchange is Oklahoma's row (a DX entrant sends its country; DXCC is an
  in-state multiplier). Kentucky's power factor, K4KCG bonus and #317
  host-state key were NOT carried: these rules state none of them.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/SouthDakota/ -- the Prairie Dog
                  Amateur Radio Club's page (sdqsoparty.com redirects to
                  pdarc.org/sd-qso-party), fetched 2026-11-18: Rules.html as
                  served, SD-QSO-PARTY-Rules.txt its text, and
                  SD-QSO-PARTY-Counties.txt the 66-county table the .dom is
                  checked against. It presents the October 9-10, 2027 running.
    NY4I          issue 129, comments 6857555807 (the split score) and
                  6858796866 (four-character grids; no county for a digital
                  QSO; DX may work digital).
    DXLog.net     SDQP.txt (updated 2026-09-07). A cross-check only; where it
                  and the rules disagree, the rules win (below).
    ADIF          SD-QSO-PARTY is in the Contest_ID enumeration (adifmt
                  v0.1.23, ADIF 3.1.8, 2026-11-18).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "1 PM Central Daylight Time Saturday to 1 PM Central Daylight
    Time Sunday. GMT is 1800z ... the 2nd full weekend of October each
    year". One 24-hour period from 18:00 UTC Saturday (2027: Oct 9-10).

  BANDS -- "160m thru 70cm (no WARC bands)"; the suggested frequencies list
    160, 80, 40, 20, 15, 10, 6, 2 m, 1.25 m and 70 cm. UsesBand states those
    ten; cfVHFBandsEnabled. DXLog omits 222 MHz: the rules win.

  MODES AND CONTACTS -- "Modes are phone, CW, digital, and mixed. Stations may
    be worked only once per mode per band ... Repeater contacts do not
    qualify." CW, phone (any voice submode), FM and every digital submode;
    cfQSOByBand and cfQSOByMode. A repeater QSO cannot be told from a simplex
    one in the log; not enforced.
    "Digital exchanges are standard FT exchanges" -- the received grid (and
    report), see GRIDS. A digital QSO in another submode (RTTY, PSK) is still
    a digital QSO: it scores digital points and counts toward the digital
    product; it earns a grid only if a grid was received. A question for NY4I
    (whether non-FT digital QSOs are in the contest at all).
    A MOBILE IN A NEW COUNTY IS A NEW CONTACT ("considered a new contact each
    time they change counties"): the party base's received-QTH dupe key. For
    a digital QSO that key is the received GRID, so the same station from a
    new grid is a new digital contact.

  EXCHANGE -- "Stations outside South Dakota send signal report and state,
    province or DXCC country. South Dakota stations send signal report and
    county." RSTDomesticOrDXQTHExchange, Oklahoma's helper row
    (ADDING_A_CONTEST A3): a DX entrant SENDS its own country prefix (the
    party base's SentLocation / LocationOrOwnCountry, as DXLog's "DX stations
    send DXCC prefix"); the received column of a DX station is its DXCC key,
    replaced 2026-11-27 by the party base's DX rule: what was logged, else
    the prefix.

  QSO POINTS -- "Phone and digital contacts are worth 1 point. CW contacts
    are worth 2 points." CW 2, Phone and FM 1, every digital submode 1.
    DXLog gives digital 2: the rules win.

  MULTIPLIERS -- "Stations outside South Dakota multiply QSO points by total
    South Dakota counties worked. Stations inside South Dakota multiply QSO
    points by the total of the South Dakota counties worked, US States,
    Provinces and DXCC countries. South Dakota counties may only be used ONCE
    as a multiplier." ONCE OVERALL for every kind (neither cfMultByBand nor
    cfMultByMode).
      Outside SD        southdakota_cty.dom: the 66 counties, each its own
                        multiplier. No DX multiplier.
      Inside SD         southdakota.dom: the counties (each its own -- an
                        in-state station working another earns its county),
                        s50.dom, p13.dom (NF and LB read as NL). DXCC
                        countries are the DX multiplier, IN STATE ONLY, every
                        entity but K, VE, KH6 and KL (uDXMultiplierKey; DXLog's
                        MULT3 excludes the same four), on the ARRL list
                        (DXLog's DXCC_DB_USE_ARRL_LIST) -- one private
                        predicate, CountsDXMultiplier.
    DECISION -- DC IS MARYLAND: the rules count "US States", and DC is none;
      DXLog refuses DC outright ("just like N1MM"), which would refuse the
      QSO. `Dc > Md = DC` keeps it loggable (Oklahoma's and Vermont's form).
      A question for NY4I.
    DECISION -- SD STAYS ON THE STATE LIST: s50.dom includes it and DXLog
      accepts a received SD, so an in-state station that logs "SD" earns the
      state. A county does NOT also earn SD (no AdditionalDomesticMultiplierKey,
      #317): the rules list counties and states side by side, nothing folds
      one into the other. A question for NY4I.

  GRIDS -- THE DIGITAL MULTIPLIER (NY4I, comments 6857555807 and 6858796866):
    "Digital contacts multiply qso points by grids" -- "for the digital
    contacts on FT4/FT8, the points would be the total digital contacts
    multiplied by the total number of grids worked digitally. The CW and phone
    mults are calculated separately. Then the totals are added together." In
    FT8/FT4 the grids are FOUR characters.
      * The grid is the PREFIX (string-key) multiplier: PrefixMultiplierKey
        answers the received grid's first four characters, upper-cased, for a
        Digital QSO whose received QTH is a Maidenhead square
        (uGridShape.IsGoodLookingGrid -- ZZ00, Hawaii's "no grid", is none);
        True with '' for every other QSO, so a rescore after a mode or QTH
        edit never keeps a stale grid. Once overall, like every multiplier.
      * The live entry sets the key in ParseReceivedExchange, because the
        engine asks PrefixMultiplierKey (SetDXQTHAndPrefix) BEFORE the
        exchange is parsed, when the grid is not yet known.
      * A DIGITAL QSO EARNS ONLY A GRID; a CW or phone QSO never one
        (CountsAsMultiplier): "you would not have a county in this case ...
        we are not tracking county multipliers for them".
      * NO HOST-AREA TEST FOR A DIGITAL QSO (NY4I: "not an issue as we are not
        tracking county multipliers for them"; "the implementation will not
        infer a county from a grid center"). CreditsWorkedStation credits
        every digital QSO, so an out-of-state entrant's FT8 QSO with a station
        outside South Dakota is credited -- a question for NY4I.
      * DX ENTRANTS MAY WORK DIGITAL (NY4I), though the DX award category
        says CW/Phone: nothing refuses it.
      * Typed: "[report] GRID" in Digital (uGridShape.TryParseReportAndGrid,
        lifted from Hawaii). From WSJT-X or an ADIF file: ApplyADIFImport
        makes a Digital QSO's GRIDSQUARE its received grid, over any other
        QTH the record carried (a digital QSO's only multiplier is its grid).

  SCORE -- "QSO Points x Multipliers = Total + Bonus", split by NY4I's ruling:
    (CW and phone points x (counties + states + provinces + DXCC))
    + (digital points x grids) + bonus. CombineWithMultipliers reads the
    digital share of the points from TScoreTotals.DigitalQSOPoints (the
    engine seam built for this contest, issue 129). No power multiplier.

  BONUS -- (the sponsor writes the call with a slashed zero, W0OJY here)
    "Stations that work the Sponsoring Club (W0OJY) station during the
    event may claim an extra 100 points ... may only be used once";
    "The bonus station may only be worked once regardless of mode". W0OJY,
    100, bsOnce, after multiplication, a credited contact only (no dupe, no
    X-QSO). A county-suffixed W0OJY/xxxx is matched by the base's party
    county strip.

  COUNTY LINES -- "County line contacts will count as multiple contacts for
    both, but must be logged separately." No maximum stated: unlimited (the
    base's county-line entry logs one QSO per county).

  NOT BUILT -- MOBILE AND PORTABLE CATEGORIES, issue #133: the entrant's own
    category and county changes do not reach scoring. The in-state incentive
    drawing (100 valid QSOs) is the sponsor's, not a score.

  CABRILLO -- CONTEST: SD-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; the rules
    state none). The standard line. MODES: CW, PH, FM, and DG for every
    digital submode (Hawaii's precedent; DXLog writes RY, which describes
    RTTY, not FT8). A grid QSO's received column is its grid, as Hawaii's
    sponsor example; the SENT column is always the county, state or country
    this station sends -- a decision (FT8 transmits a grid), a question for
    NY4I.

  ADIF -- CONTEST_ID SD-QSO-PARTY. STATE: SD for a county (the party base's
    ADIFCountyState), the worked station's state or province otherwise, none
    for a grid QSO. CNTY: the .dom display name, which is ADIF's county name
    for all 66 (the validator's enumeration, spaces aside: Oglala Lakota,
    Bon Homme, Fall River ...). SRX_STRING of a grid QSO: report and grid.

  SUBMISSION -- logs e-mailed to w0ej@arrl.net.

  WA7BNM -- 0: the calendar's terms bar automated access (a bench item).

  3830 -- the base's one "Mults" column; the form was not checked (a bench
    item). *)
unit uContestSouthDakotaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   (* ITS ID -- stored data; see the header. *)
   SD_QSO_PARTY_CONTEST_ID = 'SD-QSO-PARTY';

type
   TContestSouthDakotaQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a South Dakota entrant
         counts DXCC countries; nobody else does. HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
      (* A DIGITAL QSO WHOSE RECEIVED QTH IS A MAIDENHEAD SQUARE -- the header. *)
      function IsGridQSO(const aQso: ContestExchange): boolean;
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      function GetFriendlyName: string; override;
      function GetHostState: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      (* THE DX STATION RULE -- see TDXExchangeRule. *)
      function GetDXExchangeRule: TDXExchangeRule; override;
      function GetInStateDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetFlags: TContestFlags; override;
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* CW 2, phone and FM 1, digital 1 -- the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* THE SPLIT SCORE -- the header's SCORE. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
      (* THE TOTALS GRID'S PREFIX ROW SAYS GRIDS -- a label only. *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* CW, PH, FM, and DG for every digital submode -- the header. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* A GRID IN DIGITAL; THEN THE PARTY'S PARSE; THEN THE GRID KEY -- the
         header. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* A GRID WORD IS NOT A CALL. *)
      function MayBeACallsign(const aWord: string): boolean; override;
      (* EVERY DIGITAL QSO; else the host-area rule -- the header. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;
      (* A DIGITAL QSO EARNS ONLY ITS GRID; ANY OTHER NEVER ONE. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      (* THE GRID MULTIPLIER, on the prefix (string-key) sheet. *)
      function HasPrefixMultiplier: boolean; override;
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* ADIF: no STATE for a grid QSO; its SRX_STRING carries the grid. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
      (* AN IMPORTED OR WSJT-X QSO: a Digital QSO's GRIDSQUARE is its grid. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_SD carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 26 of 26 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

(* THE FOUR-CHARACTER GRID A RECEIVED TEXT NAMES -- '' when it is no
   Maidenhead square (4 or 6 characters; uGridShape.IsGoodLookingGrid). *)
function SouthDakotaQPGridOf(const aText: string): string;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* FormatCabrilloMode *)
   uCabrilloFormat,
   (* IsGoodLookingGrid, TryParseReportAndGrid, FourCharacterGridSquareOf *)
   uGridShape,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   (* STotalsGridMults *)
   uAppStrings,
   uContestRegistry;

function SouthDakotaQPGridOf(const aText: string): string;
begin
   (* The rule is uGridShape's since the Mississippi QSO Party became its
      second user (issue 123). *)
   Result := FourCharacterGridSquareOf(aText);
end;

function TContestSouthDakotaQP.GetDisplayName: string;
begin
   Result := 'South Dakota QSO Party';
end;

(* WHEN IT RUNS -- https://pdarc.org/sd-qso-party, the 2027 running, CONTEST
   RULES: "1 PM Central Daylight Time Saturday to 1 PM Central Daylight Time
   Sunday. GMT is 1800z ... the 2nd full weekend of October each year". *)
function TContestSouthDakotaQP.GetSchedule: string;
begin
   Result := '2nd full weekend of October at 18:00 UTC for 24h';
end;

function TContestSouthDakotaQP.GetFriendlyName: string;
begin
   Result := 'South Dakota QSO Party';
end;

function TContestSouthDakotaQP.GetHostState: string;
begin
   Result := 'SD';
end;

function TContestSouthDakotaQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=SD-QSO-PARTY. *)
   Result := 'SD-QSO-PARTY';
end;

function TContestSouthDakotaQP.GetADIFContestId: string;
begin
   (* The ADIF Contest_ID enumeration's SD-QSO-PARTY. Export writes it,
      import matches it. *)
   Result := SD_QSO_PARTY_CONTEST_ID;
end;

function TContestSouthDakotaQP.GetWA7BNMId: integer;
begin
   (* Not looked up: the calendar bars automated access -- a bench item. *)
   Result := 0;
end;

function TContestSouthDakotaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSouthDakotaQP.GetSubmissionEmail: string;
begin
   (* "Logs are to be sent via email to Bill Nixon at w0ej@arrl.net." *)
   Result := 'w0ej@arrl.net';
end;

function TContestSouthDakotaQP.GetDomesticFileName: string;
begin
   Result := 'southdakota_cty';
end;

(* The sponsor: "signal report and state, province or DXCC country". *)
function TContestSouthDakotaQP.GetDXExchangeRule: TDXExchangeRule;
begin
   Result := dxrPrefixOrDX;
end;

function TContestSouthDakotaQP.GetInStateDomesticFileName: string;
begin
   Result := 'southdakota';
end;

function TContestSouthDakotaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSouthDakotaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestSouthDakotaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestSouthDakotaQP.GetFlags: TContestFlags;
begin
   (* "worked only once per mode per band"; multipliers ONCE OVERALL
      (neither cfMultByBand nor cfMultByMode); 6 m up to 70 cm credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestSouthDakotaQP.GetCountyLineCountiesMax: integer;
begin
   (* "County line contacts will count as multiple contacts" -- no maximum. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestSouthDakotaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* "Stations outside South Dakota send signal report and state, province or
   DXCC country" -- the party base's SentLocation: a DX entrant with no MY
   STATE sends its own country. *)
function TContestSouthDakotaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestSouthDakotaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestSouthDakotaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   if IsGridQSO(aQso) then
      begin
      (* The grid in the QTH column -- the header (Hawaii's sponsor form). *)
      Result := UnicodeFormat('%-3s %-7s',
                              [aCtx.RSTReceived, SouthDakotaQPGridOf(string(aQso.QTHString))]);
      end
   else
      begin
      (* A DX station sent its DXCC prefix: the received column is its DX
         QTH, else what it sent (review H4). *)
      Result := CabrilloReceivedLoggedLocation(aMy, aQso, aCtx);
      end;
end;

(* CW 2, PHONE AND FM 1, DIGITAL 1. An off-band or off-mode QSO never
   reaches here, nor a station this entrant may not credit. *)
procedure TContestSouthDakotaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM, Digital:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

(* (CW AND PHONE POINTS x GEOGRAPHIC MULTIPLIERS) + (DIGITAL POINTS x GRIDS)
   -- NY4I's ruling, the header. The geographic multipliers are the domestic
   kind (counties, states, provinces) and the DX kind (DXCC, in state); the
   grids are the prefix kind. Every count is the scored band's row, as the
   base's SummedMultipliers reads it. *)
function TContestSouthDakotaQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   geographic, grids, digitalPoints: longint;
begin
   geographic := aTotals.Mults[aTotals.ScoredBand, Both, rmDomestic] +
                 aTotals.Mults[aTotals.ScoredBand, Both, rmDX];
   grids := aTotals.Mults[aTotals.ScoredBand, Both, rmPrefix];
   digitalPoints := aTotals.DigitalQSOPoints;
   Result := (ContestPoints(aTotals) - digitalPoints) * geographic +
             digitalPoints * grids;
end;

function TContestSouthDakotaQP.GetBonusStations: TBonusStationList;
begin
   (* "work the Sponsoring Club (W0OJY) station ... extra 100 points ... may
      only be used once" -- the header. *)
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'W0OJY';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
end;

function TContestSouthDakotaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestSouthDakotaQP.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.PrefixMultsCaption := STotalsGridMults;
   Result.PrefixMultsCaptionCW := 'CW Grids';
   Result.PrefixMultsCaptionPhone := 'Ph Grids';
end;

function TContestSouthDakotaQP.UsesBand(aBand: BandType): boolean;
begin
   (* "160m thru 70cm (no WARC bands)" and the suggested frequencies. *)
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432];
end;

(* "phone, CW, digital" and the PH/FM column: every submode of each. An
   identity fact: no station is asked. *)
function TContestSouthDakotaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestSouthDakotaQP.CabrilloModeString(aMode: ModeType;
                                                  aExtMode: ExtendedModeType): string;
begin
   if aMode = Digital then
      begin
      Result := 'DG';
      end
   else
      begin
      Result := FormatCabrilloMode(aMode, aExtMode, False);
      end;
end;

function TContestSouthDakotaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): a South
      Dakota station's county, anyone else's state or province. A DX entrant
      has none and sends its country. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestSouthDakotaQP.ParseReceivedExchange(const aText: string;
                                                     const aSession: TReceivedExchangeSession;
                                                     var aExch: ContestExchange;
                                                     out aErrorMessage: string): boolean;
var
   grid: string;
   hasReport: boolean;
   report: integer;
   key: PrefixMultiplierString;
begin
   aErrorMessage := '';
   (* A DIGITAL QSO MAY CARRY A GRID -- tried first, so a grid never reaches
      the domestic parser, which would refuse it. *)
   if (aExch.Mode = Digital) and
      TryParseReportAndGrid(aText, @IsGoodLookingGrid, grid, hasReport, report) then
      begin
      if hasReport then
         begin
         aExch.RSTReceived := report;
         end;
      aExch.QTHString := ShortString(SouthDakotaQPGridOf(grid));
      aExch.DomesticQTH := '';
      aExch.DomMultQTH := '';
      Result := True;
      end
   else
      begin
      Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
      end;

   (* THE GRID KEY, NOW THAT THE QTH IS KNOWN -- the engine asked before the
      parse (the header). '' for every QSO that is no grid QSO. *)
   if Result and PrefixMultiplierKey(aExch, key) then
      begin
      aExch.Prefix := key;
      end;
end;

function TContestSouthDakotaQP.MayBeACallsign(const aWord: string): boolean;
begin
   Result := (not IsGoodLookingGrid(aWord)) and
             inherited MayBeACallsign(aWord);
end;

function TContestSouthDakotaQP.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   if aQso.Mode = Digital then
      begin
      (* No host-area test for a digital QSO -- the header (NY4I). *)
      Result := True;
      end
   else
      begin
      Result := inherited CreditsWorkedStation(aQso);
      end;
end;

function TContestSouthDakotaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                  aKind: RemainingMultiplierType): boolean;
begin
   if aQso.Mode = Digital then
      begin
      Result := aKind = rmPrefix;
      end
   else
      begin
      Result := aKind <> rmPrefix;
      end;
end;

function TContestSouthDakotaQP.IsGridQSO(const aQso: ContestExchange): boolean;
begin
   Result := (aQso.Mode = Digital) and
             (SouthDakotaQPGridOf(string(aQso.QTHString)) <> '');
end;

function TContestSouthDakotaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "Stations inside South Dakota multiply QSO points by ... DXCC countries";
   none outside, where an entrant works only South Dakota stations. *)
function TContestSouthDakotaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

function TContestSouthDakotaQP.DXMultiplierKey(const aQso: ContestExchange;
                                               out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestSouthDakotaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestSouthDakotaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

(* THE GRIDS WORKED DIGITALLY, at every station -- the header. *)
function TContestSouthDakotaQP.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* The grid of a grid QSO; '' (True) for any other, so a stored record never
   keeps a stale grid. *)
function TContestSouthDakotaQP.PrefixMultiplierKey(const aQso: ContestExchange;
                                                   out aKey: PrefixMultiplierString): boolean;
begin
   aKey := '';
   if IsGridQSO(aQso) then
      begin
      aKey := ShortString(SouthDakotaQPGridOf(string(aQso.QTHString)));
      end;
   Result := True;
end;

function TContestSouthDakotaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestSouthDakotaQP.ADIFCountyState(const aQso: ContestExchange): string;
begin
   (* A grid says nothing about where the station is; WSJT-X's hand-off
      copies it into DomesticQTH, which the base would take for a county. *)
   if IsGridQSO(aQso) then
      begin
      Result := '';
      end
   else
      begin
      Result := inherited ADIFCountyState(aQso);
      end;
end;

function TContestSouthDakotaQP.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                         aExchangeCarriesRST: boolean): string;
var
   grid: string;
begin
   if IsGridQSO(aQso) then
      begin
      grid := SouthDakotaQPGridOf(string(aQso.QTHString));
      if aExchangeCarriesRST then
         begin
         Result := IntToStr(aQso.RSTReceived) + ' ' + grid;
         end
      else
         begin
         Result := grid;
         end;
      end
   else
      begin
      Result := inherited FormatADIFReceivedExchange(aQso, aExchangeCarriesRST);
      end;
end;

procedure TContestSouthDakotaQP.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                                const aSession: TADIFImportSession;
                                                var aExch: ContestExchange);
var
   grid: string;
begin
   inherited ApplyADIFImport(aTemps, aSession, aExch);

   (* A DIGITAL QSO'S GRIDSQUARE IS ITS GRID, over any other QTH -- its only
      multiplier (the header). *)
   grid := SouthDakotaQPGridOf(Copy(Trim(aTemps.GridSquare), 1, 4));
   if (aExch.Mode = Digital) and (grid <> '') then
      begin
      aExch.QTHString := ShortString(grid);
      aExch.DomesticQTH := '';
      aExch.DomMultQTH := '';
      end;
end;

function TContestSouthDakotaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestSouthDakotaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_SD';
end;

initialization
   RegisterContestById(SD_QSO_PARTY_CONTEST_ID, TContestSouthDakotaQP);

end.
