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

(* THE LOUISIANA QSO PARTY -- a NEW contest, registered BY ID (2026-11-18,
  GitHub issue #122).

  ITS ID IS LA-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, parish
  multipliers for everyone outside it, and an out-of-state entrant works
  only Louisiana stations (rule 1.2; the base's host-area rule, design 7.10,
  Q107). Its skeleton is the Illinois class's; its exchange is Oklahoma's
  row (a DX entrant sends its country; DXCC is an in-state multiplier).
  Illinois's DXCC cap and its two bonus stations were NOT carried: these
  rules state neither.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Louisiana/ -- the Jefferson
                  Amateur Radio Club's and Louisiana Contest Club's rules page
                  (laqp.w5gad.org/rules, "Revised February 18, 2026", fetched
                  2026-11-18): Rules.html as served, LA-QSO-PARTY-Rules.txt its
                  text; the parish page Abbreviations.html, transcribed as
                  LA-QSO-PARTY-Parishes.txt, which the .dom is checked
                  against. laqp-rules-sections-7-9.md is NY4I's earlier paste
                  of sections 7 to 9 (the same text).
    NY4I          issue 122, 2026-11-18, "proceed" on the defaults: DC counts
                  as Maryland; rule 9.6 is left to the sponsor's checker; the
                  overlays only if the sponsor asks for them (it does -- see
                  CABRILLO). The multiplier-mode seam (rule 9.1) is built with
                  this class.
    DXLog.net     LAQP.txt (updated 2026-09-05). A cross-check only: its 64
                  parish codes are the sponsor's 64 exactly.
    ADIF          LA-QSO-PARTY is in the Contest_ID enumeration (adifmt
                  v0.1.23, ADIF 3.1.8, 2026-11-18; "LA QSO PARTY" is refused).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- rule 2: "14:00 UTC April 4, 2026 to 02:00 UTC April 5, 2026"
    (April 4, 2026 is a Saturday); the rules state no recurrence. NY4I, issue
    122, 2026-11-18: "first weekend of April". GetSchedule states the 1st
    Saturday of April at 14:00 UTC for 12h -- the first weekend's Saturday,
    which is always the 1st full weekend's too (a month's first Saturday
    always has its Sunday in the month), and the party runs on that Saturday
    only (09:00 to 21:00 CDT). In 2029, when April 1 is a Sunday, it is
    April 7.

  BANDS -- rule 1: "the 160, 80, 40, 20, 15, 10, 6 and 2 meter bands"; 3.4:
    "No WARC band contacts". UsesBand states those eight; cfVHFBandsEnabled.
    The same list as DXLog's.

  MODES -- phone, CW and digital; 3.3: "Digital -- includes RTTY and any
    digital mode that supports the required exchange". NY4I, issue 122,
    2026-11-19: the class states the ALLOWED modes, and "for th eLA QSO
    PArty ... that would be CW, Phone (including FM, AM, SSB[USB,LSB]),
    RTTY, JTTY, PSK31" -- the free-form exchange modes. NY4I's later ruling
    on issues 88 and 122 (2026-11-19) generalises it: a QSO party disallows
    only the modes that cannot convey its exchange, "functionally
    specifically NOT FT8, FT4 or FT2". So UsesMode credits CW, phone and FM
    whole (C4FM and D-STAR are phone), and every digital submode but FT8,
    FT4 and FT2 (EVERY_SUBMODE - FT_SUBMODES); an FT QSO is logged and is
    an automatic X-QSO (Q98). JS8, PSK63, MFSK, reversed PSK, JT65, FST4 and
    FST4W, X-QSOs under the earlier list, are credited since.
    9.2: "NO repeater contacts": a repeater QSO cannot be told
    from a simplex one in the log; not enforced.

  DUPES -- 9.4: "All fixed stations may be worked once on CW/Digital and
    once on Phone PER BAND". cfQSOByBand and cfQSOByMode; DupeModeOf files
    Digital under CW (New England's and Illinois's seam); FM is already phone
    on the dupe sheet. 9.4.1: "Rovers may be worked once on CW/Digital and
    once on Phone per band, in EACH parish activated": the party base's
    received-QTH dupe key.

  EXCHANGE -- 7.1: "Non-Louisiana stations send call, signal report and
    state/province/country"; 7.2: "Louisiana stations send call, signal
    report and parish abbreviation". RSTDomesticOrDXQTHExchange, Oklahoma's
    helper row (ADDING_A_CONTEST A3): a DX entrant SENDS its own country
    prefix (the party base's SentLocation / LocationOrOwnCountry; DXLog's
    "DX stations send DXCC prefix"); the received column of a DX station is
    what was logged, else the prefix (the party base's DX rule,
    2026-11-27).

  QSO POINTS -- 8.1.1: "two (2) points for each complete PHONE QSO"; 8.1.2:
    "four (4) points for each complete CW/Digital QSO". CW and every credited
    digital submode 4, Phone and FM 2.

  OUT-OF-STATE ENTRANTS -- 1.2: "Non-Louisiana stations work Louisiana
    stations only": the party base's host-area rule, refused when typed and
    an automatic X-QSO when logged any other way.

  MULTIPLIERS -- 8.2.1: "For Non-Louisiana stations, multipliers are
    Louisiana Parishes (64 possible per band/mode)"; 8.2.2: "For Louisiana
    stations, multipliers are: Louisiana Parishes, States (other than
    Louisiana), Provinces, and DXCC, per band/mode"; 8.2.3: the 13 provinces
    "AB, BC, MB, NB, NL, NS, NT, NU, ON, PE, QC, SK, and YT ... Maritime
    regions will not be recognized as multipliers". PER BAND AND MODE:
    cfMultByBand and cfMultByMode.
      Outside LA        louisiana_cty.dom: the 64 parishes, each its own
                        multiplier. No DX multiplier.
      Inside LA         louisiana.dom: the parishes (each its own), DC as
                        Maryland, s50.dom, p13.dom (NF and LB read as NL).
                        s50 is included before p13, which also spells
                        Newfoundland LA, so LA stays Louisiana. DXCC countries
                        are the DX multiplier, IN STATE ONLY, every entity but
                        K, VE, KH6 and KL (uDXMultiplierKey; DXLog's MULT3
                        excludes the same four), on the ARRL list (DXLog's
                        DXCC_DB_USE_ARRL_LIST) -- one private predicate,
                        CountsDXMultiplier.
    "States (other than Louisiana)": an in-state entrant's LA earns no
      multiplier -- CountsAsMultiplier with DomesticMultiplierIsHostState
      (North Dakota's form; DXLog's MULT2 excludes K-for-LA the same way).
      The QSO still scores.
    DC IS MARYLAND -- NY4I, issue 122, 2026-11-19: "this contest considers
      DC as MD so we should use the appropriate DOM file without DC". The
      in-state file includes s50.dom, which has no DC entry, and maps DC to
      Md ahead of it (`Dc > Md = DC`), so DC is no multiplier of its own and
      a DC station is logged as Maryland; dc.dom is not included. DXLog
      refuses DC outright, which would refuse the QSO.
    9.1 -- "Multipliers: CW/Digital and Phone contacts count as separate
      multipliers": CW AND DIGITAL ARE ONE MULTIPLIER MODE. MultiplierModeOf
      files Digital under CW (the seam built for this contest,
      TContestBase.MultiplierModeOf through LOGDUPE.MultiplierSlotMode), so a
      parish worked on CW and again on RTTY on one band is one multiplier,
      and on phone it is another. FM is already phone on the sheet.

  SCORE -- 8.3: points x the sum of the multipliers, the base's formula;
    plus the bonus. No power multiplier (rule 6 sets categories only).

  BONUS -- 9.5: "Any station working N5LCC, the Louisiana Contest Club
    station, may claim a one-time 100 POINT BONUS. You may contact N5LCC
    additional times but will not receive additional points." N5LCC, 100,
    bsOnce, after multiplication (WA7BNM's formula, issue 122), a credited
    contact only (no dupe, no X-QSO). A parish-suffixed N5LCC/xxxx is
    matched by the base's party county strip.

  COUNTY LINES -- 9.4.3: "Rovers who are PRECISELY on a parish line may give
    contacts for both parishes, however, a separate and complete QSO and log
    entry must be made for each contact": GetCountyLineCountiesMax 2 ("both
    parishes"); the base's county-line entry logs one QSO per parish.

  NOT BUILT -- THE ROVER CATEGORY, issue #133: 8.3.3 "PLUS 50 points per
    Parish activated" and 9.6's "Louisiana stations will not receive the
    parish bonus points unless their CATEGORY-STATION is ROVER" need the
    entrant's own category and parish changes in scoring, which do not
    reach it.
  NOT SCORED -- 9.6, "QSOs that do not match a CATEGORY-MODE of SSB or
    CW/DIGITAL in the Cabrillo file are not counted": left to the sponsor's
    cross-check (NY4I's default, issue 122). So is the rest of 9.6 (broken
    QSOs, QSOs not in the other log). 9.3 (no self-spotting) is the
    operator's. CW/DIGITAL is no Cabrillo CATEGORY-MODE value: an entrant
    who works CW and digital declares MIXED, which section 5 lists (NY4I,
    issue 122, 2026-11-18: "Mixed is in the list so use that. No need to
    offer CW/Digital."). The summary's CATEGORY-MODE list is unchanged.

  CABRILLO -- CONTEST: LA-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; the rules
    state none). The standard line; the rules print no example line. MODES:
    the base's CW, PH, FM, RY for RTTY and DG for any other digital submode
    (DXLog writes RY for every digital mode; the rules state none).
    OVERLAYS -- 5.4 names CATEGORY-OVERLAY WIRES, TB-WIRES and POTA. NY4I,
    issue 122, 2026-11-18: "if the rules list POTA as an overlay, we have
    to honor it for this contest". CabrilloOverlayCategories states the
    three, in the sponsor's order and spelling; the Cabrillo summary offers
    the standard list (TB-WIRES is on it already) then WIRES and POTA, for
    this contest only (uCbrSum.OverlayValuesWith). The row stays a CLOSED
    drop-down.
    CATEGORY-MODE -- MIXED for a CW and digital entrant; see NOT SCORED.

  ADIF -- CONTEST_ID LA-QSO-PARTY. STATE: LA for a parish (the party base's
    ADIFCountyState), the worked station's state or province otherwise.
    CNTY: the .dom display name -- the sponsor's spelling, which is ADIF's
    county name for 63 of the 64 once the validator drops blanks and reads
    "St." as Saint; ADIFCountyName maps the 64th, the sponsor's "St. John
    Baptist", to ADIF's "St John the Baptist" (Hawaii's seam, #118).

  SUBMISSION -- 10.1: logs are uploaded at laqp.contesting.com; no e-mail
    address takes logs (laqp@w5gad.org is for questions), so ''.

  WA7BNM -- 250 (issue 122's research, 2026-10-26; confirmed by NY4I, issue
    122, 2026-11-18: "250 confirmed").

  3830 -- the base's one "Mults" column; the form was not checked. *)
unit uContestLouisianaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

const
   (* ITS ID -- stored data; see the header. *)
   LA_QSO_PARTY_CONTEST_ID = 'LA-QSO-PARTY';

type
   TContestLouisianaQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a Louisiana entrant
         counts DXCC countries; nobody else does. HasDXMultiplier, the key and
         the country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      (* 5.4's three overlays -- the Cabrillo summary offers them. *)
      function GetCabrilloOverlayCategories: TArray<string>; override;
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
      (* "contacts for both parishes" -- two at most. *)
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* CW and digital 4, phone and FM 2 -- the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      function GetBonusStations: TBonusStationList; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* 9.4 "once on CW/Digital and once on Phone PER BAND": Digital is CW. *)
      function DupeModeOf(aMode: ModeType): ModeType; override;
      (* 9.1 "CW/Digital and Phone contacts count as separate multipliers":
         Digital is CW on the multiplier sheet too. *)
      function MultiplierModeOf(aMode: ModeType): ModeType; override;
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* "States (other than Louisiana)": an in-state entrant's LA is none. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* ADIF CNTY: the sponsor's "St. John Baptist" is ADIF's "St John the
         Baptist"; every other parish name is ADIF's already. *)
      function ADIFCountyName(const aQso: ContestExchange;
                              const aDomesticName: string): string; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_LA carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 30 of 30 non-state rows are county keys of its
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
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestLouisianaQP.GetDisplayName: string;
begin
   Result := 'Louisiana QSO Party';
end;

(* WHEN IT RUNS -- https://laqp.w5gad.org/rules, "Revised February 18, 2026",
   rule 2: "14:00 UTC April 4, 2026 to 02:00 UTC April 5, 2026"; the
   recurrence is NY4I's, issue 122, 2026-11-18: "first weekend of April". *)
function TContestLouisianaQP.GetSchedule: string;
begin
   Result := '1st Saturday of April at 14:00 UTC for 12h';
end;

(* 5.4: "CATEGORY-OVERLAY: WIRES", "TB-WIRES", "CATEGORY:OVERLAY: POTA" --
   the sponsor's three, in its order (issue 122). *)
function TContestLouisianaQP.GetCabrilloOverlayCategories: TArray<string>;
begin
   Result := nil;
   SetLength(Result, 3);
   Result[0] := 'WIRES';
   Result[1] := 'TB-WIRES';
   Result[2] := 'POTA';
end;

function TContestLouisianaQP.GetFriendlyName: string;
begin
   Result := 'Louisiana QSO Party';
end;

function TContestLouisianaQP.GetHostState: string;
begin
   Result := 'LA';
end;

function TContestLouisianaQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=LA-QSO-PARTY. *)
   Result := 'LA-QSO-PARTY';
end;

function TContestLouisianaQP.GetADIFContestId: string;
begin
   (* The ADIF Contest_ID enumeration's LA-QSO-PARTY. Export writes it,
      import matches it. *)
   Result := LA_QSO_PARTY_CONTEST_ID;
end;

function TContestLouisianaQP.GetWA7BNMId: integer;
begin
   (* issue 122's research (2026-10-26); NY4I, 2026-11-18: "250 confirmed". *)
   Result := 250;
end;

function TContestLouisianaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestLouisianaQP.GetSubmissionEmail: string;
begin
   (* 10.1: "To upload a Cabrillo log go to the https://laqp.contesting.com/"
      -- no address takes logs. *)
   Result := '';
end;

function TContestLouisianaQP.GetDomesticFileName: string;
begin
   Result := 'louisiana_cty';
end;

(* The sponsor: "send call, signal report and state/province/country". *)
function TContestLouisianaQP.GetDXExchangeRule: TDXExchangeRule;
begin
   Result := dxrPrefixOrDX;
end;

function TContestLouisianaQP.GetInStateDomesticFileName: string;
begin
   Result := 'louisiana';
end;

function TContestLouisianaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestLouisianaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestLouisianaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestLouisianaQP.GetFlags: TContestFlags;
begin
   (* 9.4 "once on CW/Digital and once on Phone PER BAND"; multipliers "per
      band/mode" (8.2); 6 m and 2 m credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfMultByMode, cfVHFBandsEnabled];
end;

function TContestLouisianaQP.GetCountyLineCountiesMax: integer;
begin
   (* 9.4.3: "Rovers who are PRECISELY on a parish line may give contacts for
      both parishes". *)
   Result := 2;
end;

function TContestLouisianaQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* 7.1 "Non-Louisiana stations send call, signal report and
   state/province/country" -- the party base's SentLocation: a DX entrant
   with no MY STATE sends its own country. *)
function TContestLouisianaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

function TContestLouisianaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(aMy), aQso, aCtx);
end;

function TContestLouisianaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX station sent its country: the received column is its DX QTH,
      else what it sent (review H4). *)
   Result := CabrilloReceivedLoggedLocation(aMy, aQso, aCtx);
end;

(* CW AND DIGITAL 4, PHONE AND FM 2. An off-band or off-mode QSO (FT8, FT4
   ...) never reaches here, nor a station this entrant may not credit. *)
procedure TContestLouisianaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 4;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestLouisianaQP.GetBonusStations: TBonusStationList;
begin
   (* 9.5: "Any station working N5LCC ... may claim a one-time 100 POINT
      BONUS" -- once. *)
   Result := nil;
   SetLength(Result, 1);
   Result[0].Call := 'N5LCC';
   Result[0].Points := 100;
   Result[0].Scope := bsOnce;
end;

function TContestLouisianaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

function TContestLouisianaQP.UsesBand(aBand: BandType): boolean;
begin
   (* 1: "the 160, 80, 40, 20, 15, 10, 6 and 2 meter bands"; 3.4 "No WARC
      band contacts". *)
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2];
end;

(* THE MODES THIS CONTEST ALLOWS -- NY4I, issue 122, 2026-11-19: "the
   contest class should indicate the allowed modes. Then if the modes is not
   valid for that contest, it is an X-QSO. So for the LA QSO Party, that
   would be CW, Phone (including FM, AM, SSB[USB,LSB]), RTTY, JTTY, PSK31."
   GENERALISED THE SAME DAY (issues 88 and 122): "Same as other QSO
   parties. This functionally means specifically NOT FT8, FT4 or FT2." So
   every digital submode is credited but the FT modes, which are an
   automatic X-QSO (uContestBase.DigitalSubmodeAllowed over
   EVERY_SUBMODE - FT_SUBMODES). CW, phone and FM are credited whole:
   phone's submodes are not tested, so C4FM and D-STAR count as phone. An
   identity fact: no station is asked. *)
function TContestLouisianaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
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

function TContestLouisianaQP.DupeModeOf(aMode: ModeType): ModeType;
begin
   if aMode = Digital then
      begin
      Result := CW;
      end
   else
      begin
      Result := aMode;
      end;
end;

function TContestLouisianaQP.MultiplierModeOf(aMode: ModeType): ModeType;
begin
   if aMode = Digital then
      begin
      Result := CW;
      end
   else
      begin
      Result := aMode;
      end;
end;

function TContestLouisianaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): a
      Louisiana station's parish, anyone else's state or province. A DX
      entrant has none and sends its country. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestLouisianaQP.CountsAsMultiplier(const aQso: ContestExchange;
                                                aKind: RemainingMultiplierType): boolean;
begin
   Result := not ((aKind = rmDomestic) and
                  Station.InHostState and
                  DomesticMultiplierIsHostState(string(aQso.DomMultQTH), HostState));
end;

function TContestLouisianaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* 8.2.2 "For Louisiana stations, multipliers are ... DXCC"; none outside,
   where an entrant works only Louisiana stations. *)
function TContestLouisianaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every entity but the USA (the states), Canada (the provinces), KH6 and KL7
   (states). False is "leave the DX QTH as it was". *)
function TContestLouisianaQP.DXMultiplierKey(const aQso: ContestExchange;
                                             out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

function TContestLouisianaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestLouisianaQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestLouisianaQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestLouisianaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestLouisianaQP.ADIFCountyName(const aQso: ContestExchange;
                                            const aDomesticName: string): string;
var
   key: string;
begin
   key := UpperCase(Trim(string(aQso.DomesticQTH)));
   if key = '' then
      begin
      key := UpperCase(Trim(string(aQso.QTHString)));
      end;
   if key = 'SJB' then
      begin
      Result := 'St John the Baptist';
      end
   else
      begin
      Result := inherited ADIFCountyName(aQso, aDomesticName);
      end;
end;

function TContestLouisianaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestLouisianaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_LA';
end;

initialization
   RegisterContestById(LA_QSO_PARTY_CONTEST_ID, TContestLouisianaQP);

end.
