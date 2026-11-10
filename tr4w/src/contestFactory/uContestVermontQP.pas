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

(* THE VERMONT QSO PARTY -- a NEW contest, registered BY ID (2026-11-10,
  GitHub issue #130).

  ITS ID IS VT-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and "Stations outside Vermont work
  Vermont stations" -- the base's host-area rule (design 7.10, Q107). Copied
  from uContestOklahomaQP (itself a copy of the Georgia template), whose
  exchange is the nearest: a DX station with no MY STATE, in-state DXCC
  multipliers, DC as Maryland. A copy it owns; every rule below is
  Vermont's. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Vermont/vtqso.md -- "VERMONT
                  QSO PARTY RULES", the 2027 running, dated 30-OCT-2026
                  (NY4I's attachment on #130; ranv.org refuses automated
                  fetches). VT-QSO-PARTY-Rules.txt beside it is the
                  transcription with the source header. These rules override
                  the 2024 rules and the 2026 page the issue's first research
                  used.
    DXLog.net     VTQP.txt (updated 2026-09-06): the same 14 county codes and
                  CONTEST: VT-QSO-PARTY. Where it and the rules disagree, the
                  rules win (below).
    NY4I          his rulings, given with the build request (2026-11-10)
                  and to be posted on #130 beside the questions they
                  answer; quoted below.

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "first full weekend of February ... 0000 UTC on February 6, 2027
    and end 2400 UTC on February 8, 2027", 48 hours. Contest schedules are
    not built (design Q99); recorded only.

  BANDS -- 8): "Use of 30, 17 and 12 meters are prohibited except when
    operating FT8/FT4 on the recognized frequencies ... VHF and UHF
    frequencies are allowed, but repeaters may not be used. Otherwise,
    operators may use any frequency allowed by their license". So every band
    TR4W has except 30, 17 and 12 m: 160-10 m and every band from 6 m up
    (BandType has no 60 m). UsesBand; cfVHFBandsEnabled. DXLog lists 160-10,
    6 and 2 m only; the rules allow every VHF/UHF band, so the rules win.
    NOT BUILT -- WARC FOR FT8/FT4 ONLY: UsesBand and UsesMode are separate
    identity questions, so "30 m only on FT8" cannot be stated; a WARC QSO is
    an automatic X-QSO in every mode (NY4I: keep WARC out and say why).

  MODES -- 5): "Entrants may use any combination of modes." CW, phone (SSB,
    AM; FM is phone) and every digital submode. UsesMode credits them all.

  EXCHANGE -- 6): "(A) Vermont stations send signal report and Vermont
    county. (B) W/VE stations (including Alaska and Hawaii) send signal
    report and state or province. (C) DX stations (including U.S.
    Territories) send signal report. Properly configured contest software
    will determine the DXCC country and list the official prefix."
    RSTDomesticOrDXQTHExchange; the county codes are vermont_cty.dom.
      * A DX ENTRANT SENDS RST ONLY on the air, so the CQ exchange is ' 5NN'
        and the ADIF STX_STRING (what was transmitted) is the RST alone. Its
        CABRILLO sent column is its own DXCC prefix -- 10(C): logs carry the
        "sent exchange (signal report and state/county/province/DXCC
        prefix)" -- the party base's SentLocation. A DX entrant is one whose
        MY STATE is empty OR 'DX', which the New Contest dialog takes for a
        station outside every area (StatesNoLocation; without it the 'DX'
        went on the air and into both columns).
      * A DX STATION'S RECEIVED COLUMN is its DXCC prefix: as typed, else the
        DX QTH TR4W resolved from the call (CabrilloReceivedRSTQTHOrDXQTH) --
        not DXLog's literal "DX" (NY4I).

  QSO POINTS -- 7A): "Each complete non-duplicate Phone contact is worth 1
    point, per band. Each complete non-duplicate CW contact is worth 3
    points ... Each complete RTTY contact is worth 2 points ... Each complete
    non-duplicate Digital contact is worth 2 points ... All digital modes
    (WSJTx) count as a single mode." Phone 1 (FM is phone), CW 3, digital 2
    (RTTY and FT8/FT4 included). CalculateQSOPoints.

  DUPES -- 9(D): "Stations may be worked once per mode, per band. i.e.,
    WC4E may be worked on 20 CW, 20 SSB, and 20 digital for credit."
    cfQSOByBand, cfQSOByMode. The example names three modes and 7A says all
    digital modes "count as a single mode", so RTTY and FT8 are ONE digital
    dupe mode -- the base's DupeModeOf (identity) already gives that. The
    issue's gap "RTTY and WSJT as separate dupe modes" is moot under the 2027
    rules. 9(B): "No cross-mode contacts" -- nothing to build (a QSO has one
    mode). Mobiles that change counties are new stations -- the party base's
    received-QTH dupe key and rover strip/split, inherited.

  OUT-OF-STATE ENTRANTS -- 1): "Stations outside Vermont work Vermont
    stations": the party base's host-area rule, refused when typed and an
    automatic X-QSO when logged any other way.

  MULTIPLIERS -- 7B(1)/(2): "A multiplier can be counted only once per mode,
    regardless of the number of bands on which it is worked": cfMultByMode,
    not cfMultByBand.
      Vermont stations    vermont.dom: "14 Vermont Counties" (each its own
                          multiplier -- vermont_cty.dom maps none to Vt),
                          "50 U.S. States ... DC is counted as MD" (Dc > Md,
                          before S50.DOM), "13 Canadian Provinces and
                          Territories" (P13.DOM; NF and LB read as NL). "DXCC
                          Countries ... U.S., Canada, Alaska and Hawaii will
                          not count as DXCC multipliers": the DX multiplier,
                          IN STATE ONLY, every country but K, VE, KH6 and KL
                          (uDXMultiplierKey), on the ARRL list -- one private
                          predicate, CountsDXMultiplier.
      Non-Vermont         vermont_cty.dom: "Vermont Counties", each its own
                          multiplier (FCONTEST sets MultipliersIsCounties).
                          No DX multiplier.
    NOT BUILT -- A VT COUNTY ALSO EARNING THE STATE VT for an in-state
      entrant. NY4I ruled it (DXLog's VTQP.txt maps every county to VT in its
      state list; the rules are silent), but a QSO carries ONE domestic
      multiplier key and the DX sheet keys on the CTY country, so a county
      QSO cannot also add "VT". Faking it as bonus points or a prefix
      multiplier would make the shown multiplier counts wrong. An in-state
      entrant who logs a station sending "VT" itself gets VT from S50.DOM.
      Recorded as a gap for NY4I.
    NOT BUILT -- THE VERMONT CLUB-STATION MULTIPLIER, 7B(e): the stations are
      named by the QSO Party Manager each year, two weeks before the event;
      there is no list to state. A gap for NY4I.

  FT8 AND OTHER WSJT-X MODES -- 7B(f): "Participants in Vermont may count
    these QSOs for multiplier credit by totaling up the number of grid
    squares worked, dividing by 3, and rounding down ... Participants outside
    of Vermont may count the total number of Vermont grid squares worked,
    which is a maximum of 5 ... An FT8 or FT4 contact cannot count for county
    multiplier credit." A WSJT-X QSO (FT8, FT4, JT65, FST4, FST4W) scores 2
    points as digital and earns NO county, state, province or DXCC
    multiplier: its multipliers are grids only ("added to any other
    non-grid-square multipliers worked on other digital modes").
    CountsAsMultiplier refuses every kind for those submodes (IsWSJTXQSO).
    NOT BUILT -- THE FT8/FT4 GRID MULTIPLIERS THEMSELVES (grids / 3 in
      state, up to 5 VT grids outside): DEFERRED. This class counts NO grid
      multiplier, so a WSJT-X QSO adds points and nothing else. A gap for
      NY4I (with the FT8 exchange, a grid, which an out-of-state entrant's
      host-area rule does not know).

  COUNTY LINES -- 7B(c): "Vermont stations on a county line may be claimed
    as a QSO and a multiplier from each county (2 QSO's and 2 multipliers)":
    GetCountyLineCountiesMax = 2; TR4W's county-line entry already logs one
    QSO per county.

  SCORE -- 7D): "Multiply QSO Points by total multipliers by the power
    multiplier": "If all QSO's were made using 5W or less, multiply your
    score by 2 ... more than 5W and less than or equal to 150W output,
    multiply your score by 1.5 ... more than 150W, multiply your score by
    1". CATEGORY-POWER is the ONE value (design 7.6), Station.MyPower: QRP
    x2, LOW x1.5, HIGH x1; 4): "Logs not showing power output category will
    be listed as high power" -- unset is x1. CombineWithMultipliers.
    ROUNDING: Round, the convention of the other contests with a 1.5 factor
    (uContestStewPerry, uContestMakrothen). FPC's Round rounds a half to the
    EVEN neighbour (4.5 -> 4, 7.5 -> 8); a .5 arises only when points x
    multipliers is odd. The sponsor states no rounding -- recorded for NY4I.

  NOT BUILT -- MOBILE / ROVER (3C), issue #133: the entrant's station
    category does not reach scoring. Nothing in these rules scores a mobile
    differently, so only the category itself is unrepresented.

  CABRILLO -- CONTEST: VT-QSO-PARTY (DXLog; NY4I). The rules give no example
    line; 10(C) names the fields: band, mode, date, time, calls, sent
    exchange (RST and state/county/province/DXCC prefix), received exchange
    (the same) -- the standard QSO line. 10(B): "Logs must indicate the
    location (Vermont county, State or Province (NOT ARRL Section) ... Any
    log missing this information will not be acceptable": the LOCATION tag
    is required (RequiresCabrilloLocation). 10(A): "Contest logs with FT8 or
    FT4 contacts must be in ADIF format and are uploaded separately" -- TR4W
    writes one Cabrillo with every QSO; splitting it is the operator's
    (a gap note). ADIF -- CONTEST_ID VT-QSO-PARTY.

  SUBMISSION -- 10(A)(1): the web robot at
    https://www.b4h.net/vtqp/vtqpsubmitlog.php; no e-mail address (NY4I:
    logs go to the web robot only), so ''.

  WA7BNM -- 0: the calendar's reference was not found, and its terms bar
    automated access (a bench item for NY4I).

  3830 -- the base's one "Mults" column; the form was not checked (a bench
    item). *)
unit uContestVermontQP;

{$I tr4w.inc}

interface

uses
   (* tCategoryPower -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   VT_QSO_PARTY_CONTEST_ID = 'VT-QSO-PARTY';

type
   TContestVermontQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a Vermont entrant counts
         DXCC countries; nobody else does. HasDXMultiplier, the key and the
         country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;

      (* THE ONE PREDICATE for "this entrant states no location" -- a DX
         entrant: MY STATE empty, or the 'DX' the New Contest dialog takes
         for a station outside every area (uNewContestHostArea). Asked by the
         CQ exchange and both sent columns, so they cannot disagree. *)
      class function StatesNoLocation(const aLocation: string): boolean;

      (* The sent exchange with a DX entrant's 'DX' cleared, so each column
         helper sees the empty location rule 6(C) means. *)
      class function WithoutDXLocation(const aMy: TMyStationExchange): TMyStationExchange;
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES. *)
      function GetHostState: string; override;

      (* WHAT THE CONTEST IS -- every value stated, none inherited. *)
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
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      function GetRequiresCabrilloLocation: boolean; override;

      (* A county line of two counties -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* Phone 1, CW 3, digital 2 -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x MULTIPLIERS x THE POWER MULTIPLIER -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* Every band but 30, 17 and 12 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* Every mode -- "Entrants may use any combination of modes". *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; ' 5NN'
         alone for a DX entrant ("DX stations ... send signal report"). *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* A WSJT-X QSO earns no county, state, province or DXCC multiplier --
         7B(f); its grid multipliers are not built (the header). *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* THE MULTIPLIERS -- counties, or counties, states and provinces, from
         the domestic file; DXCC countries for a Vermont entrant; no zone or
         prefix multiplier. *)
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER, applied to a score -- QRP x2,
   LOW x1.5 (Round, half to even), HIGH and unset x1. Public so the test can
   pin the edges without building a score. *)
function VermontScoreWithPower(aScore: longint; aPower: tCategoryPower): longint;

(* IS aQso A WSJT-X QSO -- 7B(f)'s "FT8 and other WSJTx modes": a digital QSO
   in FT8, FT4, JT65, FST4 or FST4W. *)
function IsWSJTXQSO(const aQso: ContestExchange): boolean;

implementation

uses
   (* Trim, SameText -- StatesNoLocation. *)
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

function VermontScoreWithPower(aScore: longint; aPower: tCategoryPower): longint;
begin
   case aPower of
      cpQRP:
         begin
         Result := aScore * 2;
         end;
      cpLOW:
         begin
         Result := Round(aScore * 1.5);
         end;
      else
         begin
         (* cpHIGH, and cpUNSET: "Logs not showing power output category will
            be listed as high power". *)
         Result := aScore;
         end;
      end;
end;

function IsWSJTXQSO(const aQso: ContestExchange): boolean;
begin
   Result := (aQso.Mode = Digital) and
             (aQso.ExtMode in [eFT8, eFT4, eJT65, eFST4, eFST4W]);
end;

function TContestVermontQP.GetDisplayName: string;
begin
   Result := 'Vermont QSO Party';
end;

function TContestVermontQP.GetHostState: string;
begin
   Result := 'VT';
end;

function TContestVermontQP.GetCabrilloName: string;
begin
   (* DXLog's CABRILLO_CONTEST_NAME=VT-QSO-PARTY; NY4I on #130. *)
   Result := 'VT-QSO-PARTY';
end;

function TContestVermontQP.GetADIFContestId: string;
begin
   (* Export writes it, import matches it. *)
   Result := VT_QSO_PARTY_CONTEST_ID;
end;

function TContestVermontQP.GetWA7BNMId: integer;
begin
   (* Not found; the calendar bars automated access -- a bench item. *)
   Result := 0;
end;

function TContestVermontQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestVermontQP.GetSubmissionEmail: string;
begin
   (* "VTQSO logs to be submitted on line at this site:
      https://www.b4h.net/vtqp/vtqpsubmitlog.php" -- the web robot only. *)
   Result := '';
end;

function TContestVermontQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Vermont county, and then loads vermont.dom or
      this file. Lower case: the file's own name, which matters off
      Windows. *)
   Result := 'vermont_cty';
end;

function TContestVermontQP.GetFriendlyName: string;
begin
   Result := 'Vermont QSO Party';
end;

function TContestVermontQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestVermontQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestVermontQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestVermontQP.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestVermontQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* WHAT WAS TRANSMITTED: "DX stations ... send signal report" -- a DX
   entrant's MY STATE is empty, so the STX_STRING is the RST alone; anyone
   else sends the county, state or province it stated. *)
function TContestVermontQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(WithoutDXLocation(aMy), aQso);
end;

(* THE LOG'S SENT COLUMN: 10(C), "sent exchange (signal report and
   state/county/province/DXCC prefix)". The party base's SentLocation: a DX
   entrant has no MY STATE, so its column is its own DXCC prefix. *)
function TContestVermontQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(SentLocation(WithoutDXLocation(aMy)), aQso, aCtx);
end;

function TContestVermontQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   (* "Properly configured contest software will determine the DXCC country
      and list the official prefix": what was typed, else the DX QTH the
      call resolved to. *)
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestVermontQP.GetInStateDomesticFileName: string;
begin
   Result := 'vermont';
end;

function TContestVermontQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers once PER MODE (cfMultByMode,
      not cfMultByBand); 6 m and up are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode, cfVHFBandsEnabled];
end;

function TContestVermontQP.GetRequiresCabrilloLocation: boolean;
begin
   (* 10(B): "Logs must indicate the location ... Any log missing this
      information will not be acceptable." *)
   Result := True;
end;

function TContestVermontQP.GetCountyLineCountiesMax: integer;
begin
   (* "Vermont stations on a county line may be claimed as a QSO and a
      multiplier from each county (2 QSO's and 2 multipliers)". *)
   Result := 2;
end;

(* PHONE 1, CW 3, DIGITAL 2 (RTTY and WSJT-X included). FM is phone. An
   off-band QSO (UsesBand) and a station an out-of-state entrant may not
   credit (CreditsWorkedStation) never reach here. Both and NoMode are not
   modes a contact is made in. *)
procedure TContestVermontQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 3;
         end;
      Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestVermontQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := VermontScoreWithPower(inherited CombineWithMultipliers(aTotals),
                                   Station.MyPower);
end;

function TContestVermontQP.UsesBand(aBand: BandType): boolean;
begin
   (* "Use of 30, 17 and 12 meters are prohibited" (their FT8/FT4 exception
      cannot be stated -- the header); "VHF and UHF frequencies are allowed";
      "Otherwise, operators may use any frequency allowed by their license". *)
   Result := not (aBand in [Band30, Band17, Band12, AllBands, NoBand]);
end;

(* "Entrants may use any combination of modes." An identity fact: no station
   is asked. *)
function TContestVermontQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestVermontQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Vermont station's county, anyone else's state or province. A DX
      entrant has none and sends the signal report only. *)
   if StatesNoLocation(aStation.MyState) then
      begin
      Result := ' 5NN';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

(* "An FT8 or FT4 contact cannot count for county multiplier credit", and its
   multipliers are grid squares only, "added to any other non-grid-square
   multipliers worked on other digital modes" -- so a WSJT-X QSO earns no
   multiplier of any kind TR4W counts. Every other QSO counts. *)
function TContestVermontQP.CountsAsMultiplier(const aQso: ContestExchange;
                                              aKind: RemainingMultiplierType): boolean;
begin
   Result := not IsWSJTXQSO(aQso);
end;

function TContestVermontQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

class function TContestVermontQP.StatesNoLocation(const aLocation: string): boolean;
begin
   Result := (Trim(aLocation) = '') or (UpperCase(Trim(aLocation)) = 'DX');
end;

class function TContestVermontQP.WithoutDXLocation(const aMy: TMyStationExchange): TMyStationExchange;
begin
   Result := aMy;
   if StatesNoLocation(aMy.MyState) then
      begin
      Result.MyState := '';
      end;
end;

(* "For Vermont stations, the multipliers are: U.S. States, Canadian
   Provinces, DXCC Countries, Vermont Counties ..." -- DXCC yes inside
   Vermont; none outside, where an entrant works only Vermont stations. *)
function TContestVermontQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* "DXCC Countries, as designated by the official ARRL DXCC listing. U.S.,
   Canada, Alaska and Hawaii will not count as DXCC multipliers." False is
   "leave the DX QTH as it was". *)
function TContestVermontQP.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* The ARRL DXCC list where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestVermontQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestVermontQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestVermontQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

initialization
   RegisterContestById(VT_QSO_PARTY_CONTEST_ID, TContestVermontQP);

end.
