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

(* THE MISSISSIPPI QSO PARTY -- a NEW contest, registered BY ID (2026-11-18,
  GitHub issue #123).

  ITS ID IS MS-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state entrant works only
  Mississippi stations (the base's host-area rule, design 7.10, Q107). Its
  skeleton is the Louisiana class's (a DX entrant sends its country; DXCC is
  an in-state multiplier); its FT4/FT8 grids sit on the prefix sheet, as the
  South Dakota QSO Party's digital grids do. Louisiana's CW/digital grouping
  and bonus station were NOT carried: these rules state neither.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Mississippi/ -- the Vicksburg
                  ARC's 2026-MS-QSO-PARTY-RULES-FINAL.pdf, saved by NY4I
                  2026-11-18 (the arrlmiss.org link is 404), and msqp-rules.md
                  its text. MSQP-Counties.pdf is the sponsor's County Check
                  List (attached by NY4I to issue 123, 2026-11-18);
                  MS-QSO-PARTY-Counties.txt, the table the .dom is checked
                  against, was transcribed from DXLog and agrees with the
                  sponsor's list on all 82 codes and names.
    NY4I          issue 123, 2026-11-18: the rules over DXLog; no FM or AM; DC
                  counts as Maryland; out-of-state entrants score only
                  Mississippi stations; a rover in a new county is a new
                  station; county lines by DXLog's evidence. And, answering
                  the build's twelve questions (same day, later): the first
                  weekend of April; the nine grids credit whoever sends one;
                  every grid counts in the in-state total; "FTx always uses
                  Grid ... NO grid is a zero point qso"; two counties on a
                  line; the totals display shows both counts (NOT BUILT, see
                  SCORE); the call window's RTTY-after-FT8 DUPE is
                  acceptable; WA7BNM 308 confirmed.
    DXLog.net     MSQP.txt and MSQPMS.txt (updated 2026-09-07). A cross-check
                  only: its 82 county codes are N6TR's MSQPDX.MLT's and the
                  ham2k-msqp extension's.
    ADIF          MS-QSO-PARTY is in the Contest_ID enumeration (adifmt
                  v0.1.23, 2026-11-18).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "Starts: 1400z /4April 2026 Ends: 0200z /5April 2026 Duration: 12
    Hours". The rules state that date only; NY4I (issue 123, 2026-11-18): the
    first weekend of April, giving 1400Z Apr 4 - 0200Z Apr 5 2026, Apr 3-4
    2027, Apr 1-2 2028 and Apr 7-8 2029 -- each the 1st Saturday of April, so
    GetSchedule states that (Alabama's form), pinned at all four.

  BANDS -- "160m, 80m, 40m, 20m, 15m, 10m, 6m, 2m". UsesBand states those
    eight; cfVHFBandsEnabled. DXLog agrees.

  MODES -- "CW, SSB, RTTY, FT4/8". NY4I: no FM, no AM. UsesMode credits CW;
    phone only in an SSB submode (Hawaii's form); digital only as RTTY,
    FT8 or FT4. eNoMode and eData mean "some submode" (Q98 S1), so an old
    record is never proven off-mode. Any other submode (PSK, JS8 ...) is an
    automatic X-QSO -- a default; NY4I left that question (his 5) unanswered.

  AN FT QSO -- IsFTQSO, the ONE predicate every rule below asks: a Digital
    QSO in FT8 or FT4, or in an unknown digital submode (eNoMode, eData) whose
    received QTH is a grid square (FourCharacterGridSquareOf) -- "ALL FT4/8
    stations send signal report and Grid Square", so the grid says what the
    submode did not. RTTY (eRTTY, eRTTY_R) is never one.

  DUPES -- "Same station can be worked on each separate band/mode. Example,
    W5XX can work W1AW on 20m CW, 20m SSB, 20m RTTY, 20m FT4/8." cfQSOByBand
    and cfQSOByMode give CW, phone and digital; RTTY and FT4/8 share the dupe
    sheet's ONE digital slot (TDupesArray has no other), so DupeModeOf cannot
    split them. They are split by the party base's received-QTH dupe key
    instead: an FT QSO's received QTH is a grid, an RTTY QSO's a county,
    state, province or country, and the two can never be the same text --
    pinned through the real engine. Two gaps, both reported: an FT QSO
    logged with NO received QTH (an import with no GRIDSQUARE) asks the
    call-only sheet and is a dupe of an RTTY QSO on that band; and the call
    window, asked before the exchange exists, shows DUPE for the RTTY QSO
    after the FT8 one (the Q118 compromise -- information, not a gate; NY4I,
    2026-11-18: acceptable, the operator can still log it).
    A ROVER IN A NEW COUNTY IS A NEW STATION (NY4I): the same received-QTH
    key.

  EXCHANGE -- "W/VE stations send signal report and State or Province. DX
    stations send signal report and Country. MS stations send signal report
    and County. ALL FT4/8 stations send signal report and Grid Square."
      * CW, phone, RTTY: RSTDomesticOrDXQTHExchange, Louisiana's helper row:
        a DX entrant SENDS its own country (NY4I: the COUNTRY, not "DX" -- the
        party base's SentLocation); the received column of a DX station is
        its DXCC key, else what it sent.
      * FT4/FT8: typed "[report] GRID" (uGridShape.TryParseReportAndGrid,
        South Dakota's and Hawaii's); a grid is refused on RTTY (it is no
        county). From WSJT-X or an ADIF file, ApplyADIFImport makes an FT
        QSO's GRIDSQUARE its received QTH. AN FT QSO THAT CARRIES NO GRID
        SCORES ZERO (NY4I, 2026-11-18: "FTx always uses Grid as it has no way
        to convey other information. NO grid is a zero point qso"). It is
        NOT refused -- WSJT-X's hand-off runs the same parse, and a refusal
        there would lose the QSO: a county, state or country it carries
        parses as on RTTY and is judged by the host-area rule, and the QSO
        is logged at 0 points with NO multiplier. Only FT8 and FT4 by
        submode: an unknown digital submode (eNoMode, eData) with no grid is
        not identifiably FT, and scores as RTTY. STILL OPEN (NY4I's 7 said
        "see 4", which does not reach it): a BLANK exchange is refused, as in
        every party, so an FT QSO whose grid was skipped entirely is refused
        rather than logged at 0. The SENT exchange of an FT QSO is the
        report and THIS QSO's own grid (its captured MY GRID, four
        characters). With NO grid recorded it falls back to the county,
        state or country -- NOT APPROVED: NY4I's "FTx always uses Grid" says
        a grid is sent, and does not say what to write when the station
        recorded none.

  QSO POINTS -- "SSB = 1; CW = 2; RTTY = 2; FT4/8 = 2". Phone 1, CW and every
    credited digital submode 2 -- except an FT8 or FT4 QSO with no received
    grid, 0 (EXCHANGE above).

  OUT-OF-STATE ENTRANTS -- "score only MS stations" (NY4I, from the sponsor's
    spreadsheet). CW, phone and RTTY: the party base's host-area rule against
    the county file, refused when typed and an automatic X-QSO otherwise. FT:
    the received grid must be one of the nine Mississippi grids (EM41-44,
    EM50-54), DXLog's own test; an FT QSO holding no grid is judged by the
    host-area rule, like RTTY. Those grids also cover parts of Louisiana,
    Arkansas, Tennessee and Alabama, so a station there in one of them is
    credited -- confirmed by NY4I (2026-11-18: "not exact", but the sponsor
    likely scores it so).

  MULTIPLIERS -- "Earned ONCE regardless of band/mode worked" -- neither
    cfMultByBand nor cfMultByMode.
      W/VE and DX       "1 for each MS County worked in SSB/CW/RTTY (82
                        possible) + 1 for each MS Grid Square worked in FT8/4
                        (9 possible...EM41-44 and EM50-54)". The counties are
                        mississippi_cty.dom (each its own); the grids are the
                        PREFIX multiplier, keyed by PrefixMultiplierKey (the
                        host-area rule above keeps any other grid off it). No
                        DX multiplier.
      Mississippi       "1 for each MS County worked (82 possible), 1 for each
                        of the remaining States worked (49 possible), 1 for
                        each Canadian Province/Territory worked (13 possible),
                        1 for each remaining DX Country/Entity worked (336
                        possible) in SSB/CW/RTTY, then taking the total number
                        of Grid Squares worked in FT8/4 and dividing by 4 ...
                        (Round up to nearest whole number.)" mississippi.dom:
                        the counties, DC as Maryland, s50.dom, p13.dom (NF and
                        LB as NL). DXCC entities are the DX multiplier, IN
                        STATE ONLY, every entity but K, VE, KH6 and KL
                        (uDXMultiplierKey; DXLog's MULT3 excludes the same
                        four), on the ARRL list -- one private predicate,
                        CountsDXMultiplier. The grids are EVERY grid worked in
                        FT4/FT8, Mississippi's nine and the entrant's own
                        included (the rules say "the total number"; NY4I,
                        2026-11-18: yes).
    "remaining States": an in-state entrant's MS earns no multiplier --
      CountsAsMultiplier with DomesticMultiplierIsHostState (Louisiana's form).
    DECISION -- DC IS MARYLAND (NY4I, issue 123): "49 possible" is the 50
      states less Mississippi, so DC is no multiplier of its own.
    AN FT QSO EARNS ONLY A GRID; a CW, phone or RTTY QSO never one
      (CountsAsMultiplier) -- "in SSB/CW/RTTY" and "in FT8/4".

  SCORE -- "Final score equals the sum of QSO points multiplied by the total
    multipliers." Outside Mississippi the base's formula (counties + grids).
    In Mississippi CombineWithMultipliers counts the grids as their number
    divided by four, rounded UP: points x (domestic + DXCC + ceil(grids/4)).
    No engine seam: the grids are the prefix kind's count in TScoreTotals.
    DXLog's MSQPMS.txt divides its DXCC multiplier by four instead
    ($FIELDVALUE.Mult3/4) -- the rules win.
    NOT BUILT -- THE DISPLAY OF BOTH COUNTS (NY4I, 2026-11-18: "Show both").
      The totals window, the 3830 report and the summary sheet show the
      prefix sheet's RAW grid count; showing ceil(grids/4) beside it needs a
      display seam in uTotal, uScore3830Report and PostUnit that no class
      can supply.
    NOT BUILT -- "Portable/Mobile: Final score will be the sum of the scores
      from each County operated": the entrant's own county changes do not
      reach scoring (issue #133, which NY4I says has no open questions). A
      rover's log is scored as one log.

  COUNTY LINES -- the rules are silent; NY4I: DXLog's evidence decides, and
    on 2026-11-18 "allow two". DXLog's received-exchange pattern takes one
    county or two (COUNTY/COUNTY) and scores "one QSO per county, own and
    worked": GetCountyLineCountiesMax 2; the base's county-line entry logs
    one QSO per county.

  NOT ENFORCED -- "Self-spotting ... allowed by mobile/portable MS stations
    ONLY": the operator's. The categories are the Cabrillo header's.

  CABRILLO -- CONTEST: MS-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; the rules
    state none). The standard line. MODES: the base's CW, PH, RY for RTTY and
    DG for FT8/FT4 -- DXLog's CABRILLO_MODES. An FT QSO's received column is
    its grid.

  ADIF -- CONTEST_ID MS-QSO-PARTY. STATE: MS for a county (the party base's
    ADIFCountyState), the worked station's state or province otherwise, none
    for an FT QSO (a grid says nothing about the state). CNTY: the .dom
    display name, ADIF's county name for all 82 once blanks are dropped (the
    vendored validator's list: DeSoto, Jefferson Davis, Pearl River).
    SRX_STRING of an FT QSO: the report and the grid.

  SUBMISSION -- "E-mail entries to W5XX at ARRL.NET".

  WA7BNM -- 308, confirmed by NY4I (issue 123, 2026-11-18):
    https://www.contestcalendar.com/contestdetails.php?ref=308

  3830 -- the base's one "Mults" column; the form was not checked. *)
unit uContestMississippiQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   (* ITS ID -- stored data; see the header. *)
   MS_QSO_PARTY_CONTEST_ID = 'MS-QSO-PARTY';

(* IS aGrid ONE OF THE NINE MISSISSIPPI GRIDS -- EM41-44 and EM50-54, the
   rules' list; aGrid is a four-character square, any case. *)
function IsMississippiQPGrid(const aGrid: string): boolean;

type
   TContestMississippiQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a Mississippi entrant
         counts DXCC entities; nobody else does. HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
      (* AN FT4/FT8 QSO -- the header's AN FT QSO. *)
      function IsFTQSO(const aQso: ContestExchange): boolean;
      (* THE GRID AN FT QSO RECEIVED -- four characters, '' for any other QSO
         or an FT QSO that holds no grid. *)
      function ReceivedGridOf(const aQso: ContestExchange): string;
      (* MAY THIS ENTRANT CREDIT AN FT QSO WITH aGrid: in Mississippi any
         grid, outside only the nine Mississippi grids. *)
      function CreditsFTGrid(const aGrid: string): boolean;
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
      (* One county or two -- DXLog's pattern (the header). *)
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* SSB 1; CW, RTTY and FT4/8 2; FT8/FT4 with no grid 0 -- the
         header's QSO POINTS. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* IN MISSISSIPPI THE GRIDS COUNT DIVIDED BY FOUR, ROUNDED UP -- the
         header's SCORE. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
      (* THE TOTALS GRID'S PREFIX ROW SAYS GRIDS -- a label only. *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* A GRID ON FT4/FT8; THEN THE PARTY'S PARSE; THEN THE GRID KEY -- the
         header's EXCHANGE. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* A GRID WORD IS NOT A CALL. *)
      function MayBeACallsign(const aWord: string): boolean; override;
      (* AN FT QSO BY ITS GRID; any other (and an FT QSO with no grid) by the
         host-area rule. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;
      (* AN FT QSO EARNS ONLY ITS GRID; ANY OTHER NEVER ONE; an in-state
         entrant's MS is no state. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      (* THE FT GRIDS, on the prefix (string-key) sheet, at every station. *)
      function HasPrefixMultiplier: boolean; override;
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* ADIF: no STATE for an FT QSO; its SRX_STRING carries the grid. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
      (* AN IMPORTED OR WSJT-X QSO: an FT QSO's GRIDSQUARE is its grid. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_MS carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 46 of 46 non-state rows are county keys of its
         own county file; the rest are DX prefixes and a few spellings it lacks.
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
   (* IsGoodLookingGrid, TryParseReportAndGrid, FourCharacterGridSquareOf *)
   uGridShape,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   (* STotalsGridMults, SExchangeOutOfStateWorksHostOnly *)
   uAppStrings,
   uContestRegistry;

function IsMississippiQPGrid(const aGrid: string): boolean;
var
   grid: string;
begin
   grid := UpperCase(Trim(aGrid));
   Result := (grid = 'EM41') or (grid = 'EM42') or (grid = 'EM43') or (grid = 'EM44') or
             (grid = 'EM50') or (grid = 'EM51') or (grid = 'EM52') or (grid = 'EM53') or
             (grid = 'EM54');
end;

(* THE FT4/FT8 SUBMODES -- the WSJT-X modes the rules name. *)
function IsFTSubmode(aExtMode: ExtendedModeType): boolean;
begin
   Result := aExtMode in [eFT8, eFT4];
end;

(* THE RTTY SUBMODES -- never an FT QSO. *)
function IsRTTYSubmode(aExtMode: ExtendedModeType): boolean;
begin
   Result := aExtMode in [eRTTY, eRTTY_R];
end;

function TContestMississippiQP.GetDisplayName: string;
begin
   Result := 'Mississippi QSO Party';
end;

(* WHEN IT RUNS -- the sponsor's 2026 rules: "Starts: 1400z /4April 2026
   Ends: 0200z /5April 2026 Duration: 12 Hours" (the sponsor's page is
   https://arrlmiss.org/mississippi-qso-party/). The rules state no
   recurrence; NY4I (issue 123, 2026-11-18): the first weekend of April, with
   2026-2029's dates, each the 1st Saturday of April. *)
function TContestMississippiQP.GetSchedule: string;
begin
   Result := '1st Saturday of April at 14:00 UTC for 12h';
end;

function TContestMississippiQP.GetFriendlyName: string;
begin
   Result := 'Mississippi QSO Party';
end;

function TContestMississippiQP.GetHostState: string;
begin
   Result := 'MS';
end;

function TContestMississippiQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=MS-QSO-PARTY. *)
   Result := 'MS-QSO-PARTY';
end;

function TContestMississippiQP.GetADIFContestId: string;
begin
   (* The ADIF Contest_ID enumeration's MS-QSO-PARTY. Export writes it,
      import matches it. *)
   Result := MS_QSO_PARTY_CONTEST_ID;
end;

function TContestMississippiQP.GetWA7BNMId: integer;
begin
   (* Confirmed by NY4I, issue 123, 2026-11-18. *)
   Result := 308;
end;

function TContestMississippiQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMississippiQP.GetSubmissionEmail: string;
begin
   (* "E-mail entries to W5XX at ARRL.NET". *)
   Result := 'w5xx@arrl.net';
end;

function TContestMississippiQP.GetDomesticFileName: string;
begin
   Result := 'mississippi_cty';
end;

(* The sponsor: "DX stations send signal report and Country." *)
function TContestMississippiQP.GetDXExchangeRule: TDXExchangeRule;
begin
   Result := dxrPrefixOrDX;
end;

function TContestMississippiQP.GetInStateDomesticFileName: string;
begin
   Result := 'mississippi';
end;

function TContestMississippiQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMississippiQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestMississippiQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestMississippiQP.GetFlags: TContestFlags;
begin
   (* "Same station can be worked on each separate band/mode"; multipliers
      "Earned ONCE regardless of band/mode" (neither cfMultByBand nor
      cfMultByMode); 6 m and 2 m credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestMississippiQP.GetCountyLineCountiesMax: integer;
begin
   (* The rules are silent; DXLog takes one county or two -- the header. *)
   Result := 2;
end;

function TContestMississippiQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* AN FT QSO SENDS ITS GRID: "ALL FT4/8 stations send signal report and Grid
   Square" -- this QSO's own MY GRID, four characters. Otherwise the party
   base's SentLocation: a DX entrant with no MY STATE sends its own country.
   AN FT QSO WITH NO MY GRID RECORDED falls back to SentLocation too -- NOT
   APPROVED by NY4I (the header's EXCHANGE), kept so the column is never
   empty until he rules. *)
function SentGridOrLocation(aIsFT: boolean;
                            const aLocation: TMyStationExchange): TMyStationExchange;
var
   grid: string;
begin
   Result := aLocation;
   if aIsFT then
      begin
      grid := FourCharacterGridSquareOf(aLocation.MyGrid);
      if grid <> '' then
         begin
         Result.MyState := grid;
         end;
      end;
end;

function TContestMississippiQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentGridOrLocation(IsFTQSO(aQso), SentLocation(aMy)), aQso);
end;

function TContestMississippiQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentGridOrLocation(IsFTQSO(aQso), SentLocation(aMy)),
                                  aQso, aCtx);
end;

function TContestMississippiQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
var
   grid: string;
begin
   grid := ReceivedGridOf(aQso);
   if grid <> '' then
      begin
      (* The grid in the QTH column. *)
      Result := UnicodeFormat('%-3s %-7s', [aCtx.RSTReceived, grid]);
      end
   else
      begin
      (* A DX station sent its country: the received column is its DX QTH,
         else what it sent (review H4). *)
      Result := CabrilloReceivedLoggedLocation(aMy, aQso, aCtx);
      end;
end;

(* SSB 1; CW, RTTY AND FT4/8 2; AN FT8/FT4 QSO WITH NO GRID 0 (NY4I: "NO grid
   is a zero point qso"). An off-band or off-mode QSO (FM, AM, PSK ...) never
   reaches here, nor a station this entrant may not credit. *)
procedure TContestMississippiQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 2;
         end;
      Digital:
         begin
         if IsFTSubmode(aQso.ExtMode) and (ReceivedGridOf(aQso) = '') then
            begin
            aQso.QSOPoints := 0;
            end
         else
            begin
            aQso.QSOPoints := 2;
            end;
         end;
      Phone:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

(* POINTS x (DOMESTIC + DXCC + GRIDS), WHERE A MISSISSIPPI ENTRANT'S GRIDS
   COUNT AS ceil(grids / 4) -- the header's SCORE. Every count is the scored
   band's row, as the base's SummedMultipliers reads it. *)
function TContestMississippiQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   grids: longint;
begin
   if not Station.InHostState then
      begin
      Result := inherited CombineWithMultipliers(aTotals);
      Exit;
      end;
   grids := aTotals.Mults[aTotals.ScoredBand, Both, rmPrefix];
   Result := ContestPoints(aTotals) *
             (SummedMultipliers(aTotals) - grids + (grids + 3) div 4);
end;

function TContestMississippiQP.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.PrefixMultsCaption := STotalsGridMults;
   Result.PrefixMultsCaptionCW := 'CW Grids';
   Result.PrefixMultsCaptionPhone := 'Ph Grids';
end;

function TContestMississippiQP.UsesBand(aBand: BandType): boolean;
begin
   (* "160m, 80m, 40m, 20m, 15m, 10m, 6m, 2m". *)
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2];
end;

(* "CW, SSB, RTTY, FT4/8" -- NY4I: no FM, no AM. eNoMode and eData mean "some
   submode" (Q98 S1), so an old record is never proven off-mode. An identity
   fact: no station is asked. *)
function TContestMississippiQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW:
         begin
         Result := True;
         end;
      Phone:
         begin
         Result := aExtMode in [eNoMode, eData, eSSB, eUSB, eLSB];
         end;
      Digital:
         begin
         Result := (aExtMode in [eNoMode, eData]) or
                   IsRTTYSubmode(aExtMode) or
                   IsFTSubmode(aExtMode);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestMississippiQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): a
      Mississippi station's county, anyone else's state or province. A DX
      entrant has none and sends its country. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestMississippiQP.ParseReceivedExchange(const aText: string;
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
   (* A DIGITAL QSO THAT IS NOT RTTY MAY CARRY A GRID -- tried first, so a
      grid never reaches the domestic parser. *)
   if (aExch.Mode = Digital) and
      (not IsRTTYSubmode(aExch.ExtMode)) and
      TryParseReportAndGrid(aText, @IsGoodLookingGrid, grid, hasReport, report) then
      begin
      grid := FourCharacterGridSquareOf(grid);
      if not CreditsFTGrid(grid) then
         begin
         Result := False;
         aErrorMessage := UnicodeFormat(SExchangeOutOfStateWorksHostOnly, [HostState]);
         Exit;
         end;
      if hasReport then
         begin
         aExch.RSTReceived := report;
         end;
      aExch.QTHString := ShortString(grid);
      aExch.DomesticQTH := '';
      aExch.DomMultQTH := '';
      Result := True;
      end
   else
      begin
      Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
      end;

   (* THE GRID KEY, NOW THAT THE QTH IS KNOWN -- the engine asked before the
      parse (South Dakota's finding). '' for every QSO that is no FT QSO. *)
   if Result and PrefixMultiplierKey(aExch, key) then
      begin
      aExch.Prefix := key;
      end;
end;

function TContestMississippiQP.MayBeACallsign(const aWord: string): boolean;
begin
   Result := (not IsGoodLookingGrid(aWord)) and
             inherited MayBeACallsign(aWord);
end;

function TContestMississippiQP.IsFTQSO(const aQso: ContestExchange): boolean;
begin
   if aQso.Mode <> Digital then
      begin
      Result := False;
      end
   else if IsFTSubmode(aQso.ExtMode) then
      begin
      Result := True;
      end
   else if IsRTTYSubmode(aQso.ExtMode) then
      begin
      Result := False;
      end
   else
      begin
      (* An unknown digital submode: the grid says FT -- the header. *)
      Result := FourCharacterGridSquareOf(string(aQso.QTHString)) <> '';
      end;
end;

function TContestMississippiQP.ReceivedGridOf(const aQso: ContestExchange): string;
begin
   Result := '';
   if IsFTQSO(aQso) then
      begin
      Result := FourCharacterGridSquareOf(string(aQso.QTHString));
      end;
end;

function TContestMississippiQP.CreditsFTGrid(const aGrid: string): boolean;
begin
   Result := Station.InHostState or IsMississippiQPGrid(aGrid);
end;

function TContestMississippiQP.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   if ReceivedGridOf(aQso) <> '' then
      begin
      Result := CreditsFTGrid(ReceivedGridOf(aQso));
      end
   else
      begin
      Result := inherited CreditsWorkedStation(aQso);
      end;
end;

function TContestMississippiQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                  aKind: RemainingMultiplierType): boolean;
begin
   if IsFTQSO(aQso) then
      begin
      Result := aKind = rmPrefix;
      end
   else
      begin
      Result := (aKind <> rmPrefix) and
                not ((aKind = rmDomestic) and
                     Station.InHostState and
                     DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
      end;
end;

function TContestMississippiQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "MS stations earn ... 1 for each remaining DX Country/Entity worked";
   none outside, where an entrant works only Mississippi stations. *)
function TContestMississippiQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every entity but the USA (the states), Canada (the provinces), KH6 and KL7
   (states). False is "leave the DX QTH as it was". *)
function TContestMississippiQP.DXMultiplierKey(const aQso: ContestExchange;
                                               out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestMississippiQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestMississippiQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

(* THE GRIDS WORKED IN FT4/FT8, at every station -- the header. *)
function TContestMississippiQP.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* The grid of an FT QSO; '' (True) for any other, so a stored record never
   keeps a stale grid. *)
function TContestMississippiQP.PrefixMultiplierKey(const aQso: ContestExchange;
                                                   out aKey: PrefixMultiplierString): boolean;
begin
   aKey := ShortString(ReceivedGridOf(aQso));
   Result := True;
end;

function TContestMississippiQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestMississippiQP.ADIFCountyState(const aQso: ContestExchange): string;
begin
   (* A grid says nothing about where the station is; WSJT-X's hand-off
      copies it into DomesticQTH, which the base would take for a county. *)
   if IsFTQSO(aQso) then
      begin
      Result := '';
      end
   else
      begin
      Result := inherited ADIFCountyState(aQso);
      end;
end;

function TContestMississippiQP.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                          aExchangeCarriesRST: boolean): string;
var
   grid: string;
begin
   grid := ReceivedGridOf(aQso);
   if grid = '' then
      begin
      Result := inherited FormatADIFReceivedExchange(aQso, aExchangeCarriesRST);
      end
   else if aExchangeCarriesRST then
      begin
      Result := IntToStr(aQso.RSTReceived) + ' ' + grid;
      end
   else
      begin
      Result := grid;
      end;
end;

procedure TContestMississippiQP.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                                const aSession: TADIFImportSession;
                                                var aExch: ContestExchange);
var
   grid: string;
begin
   inherited ApplyADIFImport(aTemps, aSession, aExch);

   (* AN FT QSO'S GRIDSQUARE IS ITS GRID: over any other QTH in FT8/FT4, and
      for an unknown digital submode only when the record carried no other
      QTH. Never for RTTY, whose county stays. *)
   if aExch.Mode <> Digital then
      begin
      Exit;
      end;
   grid := FourCharacterGridSquareOf(Copy(Trim(string(aTemps.GridSquare)), 1, 4));
   if grid = '' then
      begin
      Exit;
      end;
   if IsFTSubmode(aExch.ExtMode) or
      ((not IsRTTYSubmode(aExch.ExtMode)) and (Trim(string(aExch.QTHString)) = '')) then
      begin
      aExch.QTHString := ShortString(grid);
      aExch.DomesticQTH := '';
      aExch.DomMultQTH := '';
      end;
end;

function TContestMississippiQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestMississippiQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_MS';
end;

initialization
   RegisterContestById(MS_QSO_PARTY_CONTEST_ID, TContestMississippiQP);

end.
