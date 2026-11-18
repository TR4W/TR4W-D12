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

(* THE HAWAII QSO PARTY -- a NEW contest, registered BY ID (2026-11-17,
  GitHub issue #118).

  ITS ID IS HI-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so its UDP contest number is
  derived from its id (the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, district
  multipliers for everyone outside it, and an out-of-state entrant works
  only Hawaii stations -- the base's host-area rule (design 7.10, Q107).
  Copied from uContestNewHampshireQP, whose multiplier scopes are the same
  shape (once in state with DXCC, per band outside); a copy it owns. NH's
  10-DXCC cap, its host-state refusal and its schedule were NOT carried:
  Hawaii's rules state none of them. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/Hawaii/hawaii-qso-party-rules.md
                  -- the rules page, multiplier map and grid-square page of
                  hawaiiqsoparty.org, pasted by NY4I into issue 118 on
                  2026-11-17 (the site refuses automated fetches).
                  HI-QSO-PARTY-Rules.txt beside it is the transcription with
                  the source header; HI-QSO-PARTY-Districts.txt the district
                  table the .dom is checked against.
    NY4I          his rulings on the nine build questions, 2026-11-17 (below,
                  each where it landed), and the sponsor's contact rule.
    DXLog.net     HIQP.txt (stations outside Hawaii) and HIQPHI.txt (Hawaii
                  stations), both updated 2026-09-05. A cross-check only;
                  where they and the rules disagree, the rules win.
    ADIF          HI-QSO-PARTY is in the Contest_ID enumeration (checked with
                  adifmt v0.1.23, ADIF 3.1.8, 2026-11-17).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- 1: "36 hours from 1600 UTC". NY4I: the pasted "Aug 21 2026" is a
    sponsor typo; the event is the Saturday of the weekend -- 2026 Sat Aug 22
    1600Z to Mon Aug 24 0400Z, 2027 Sat Aug 21. No "Nth full weekend" or
    "Nth Saturday" gives both (the 3rd full weekend of August 2026 is Aug
    15; the 4th of 2027 is Aug 28); both are the Saturday before the 4th
    Sunday of August, the grammar form NY4I approved for this and ARRL 160:
    'the Saturday before the 4th Sunday of August at 16:00 UTC for 36h'.

  BANDS -- 2: "only on the 10, 15, 20, 40, 80, and 160 meter bands". UsesBand;
    no WARC, nothing above 10 m, no cfVHFBandsEnabled. DXLog agrees.

  MODES AND CONTACTS -- "Each station can be worked three times per band.
    Once each on CW, SSB, digital (digital is any binary mode including
    RTTY, FT8, FT4, Winlink P2P, etc.)" (NY4I, 2026-11-17, the sponsor's
    rule). UsesMode credits CW, SSB and every digital submode; cfQSOByBand
    and cfQSOByMode, and the dupe sheet's three slots (CW, Phone, Digital --
    one Digital slot for every submode) give exactly three per band.
    RULING -- FM IS NOT PHONE (NY4I): the rules name SSB only. A Phone QSO
      in an SSB submode (SSB, USB, LSB -- or none recorded) scores 2; FM,
      AM, C4FM and D-STAR voice are off-mode: an automatic X-QSO, 0 points,
      no multiplier, no dupe.
    A MOBILE IN A NEW DISTRICT IS A NEW STATION (the party base's
      received-QTH dupe key, NY4I's Q118 ruling for every state party), so a
      mobile may be worked more than three times on a band from different
      districts. A question for NY4I against the "three times per band".

  EXCHANGE -- 8: "Hawai'i stations send signal report plus Hawai'i Multiplier
    ... Non-Hawai'i stations send signal report plus State or Province ...
    Non-USA / Canada stations send "DX"". RSTDomesticOrDXQTHExchange; the
    district codes are hawaiiqp_cty.dom. New Hampshire's helper row
    (ADDING_A_CONTEST A3):
      * A DX ENTRANT SENDS "DX": the CQ exchange is ' 5NN DX' (MY STATE empty
        or the New Contest dialog's 'DX' -- uCabrilloExchange.SentStateOrDX),
        and so are the ADIF STX_STRING and the Cabrillo sent column.
      * A DX STATION'S RECEIVED COLUMN is "DX", what it sent -- also when its
        entity was typed (CabrilloReceivedRSTDomesticQTHOrDX).
      * NF AND LB ARE NL EVERYWHERE (NY4I; DXLog: "just like N1MM"): `Nl =
        NF,LB` in hawaiiqp.dom, the received QTH rewritten to NL at the parse
        and the import (NormalizeProvinceAlias), and the SRX_STRING's word.
      * A HAWAII ENTRANT WORKING ANOTHER PARTY'S STATION that sends a county
        (KS, OH ...) enters the STATE (NY4I): the county is refused as an
        improper QTH, as any non-multiplier text is.
      * BLANK SCORES ZERO (the sponsor's grid page): a QSO logged with no
        received QTH is not credited (CreditsWorkedStation) -- an automatic
        X-QSO. A DX station that sent only its report is such a QSO.

  GRID SQUARES -- BUILT (NY4I, 2026-11-17). The sponsor: a QSO in a mode
    that cannot send a QTH name (FT8, FT4 ...) may log the received
    4-character grid instead of the district, state, province or DX; with
    no grid received, a fake one such as ZZ00; any 4 characters of grid
    shape are accepted. The sponsor determines such a QSO's multiplier from
    the call's mailing address, so TR4W cannot credit one live: A GRID QSO
    EARNS ITS QSO POINTS AND NO MULTIPLIER, and is not an X-QSO.
      * A GRID QSO is a DIGITAL QSO whose received QTH is two letters A-Z
        and two digits (IsGridQSO) -- ZZ00 included, which is no Maidenhead
        square, so uGridShape's test is not used.
      * Typed: ParseReceivedExchange takes "[report] GRID" in Digital (a
        signed report such as -10 is the received report). Any other mode
        parses as before, so a grid typed on CW is refused.
      * From WSJT-X or an ADIF file: ApplyADIFImport takes the GRIDSQUARE's
        first four characters as the received QTH of a Digital QSO that
        carries no other.
      * The host-area rule still holds: an out-of-state entrant's grid QSO
        is credited only with a Hawaii (KH6) station, DXLog's own test.
      * CountsAsMultiplier refuses every kind; no ADIF STATE or CNTY.
      * Cabrillo writes the grid in the received QTH column, the sponsor's
        example: "QSO: 14080 DG 2020-08-22 0528 KH6TU -04 MAU W6OAT -10
        CN87"; the SRX_STRING is the report and the grid.
    OUR OWN QTH IS NEVER A GRID: the New Contest dialog takes a district
      from the list inside Hawaii and refuses anything but a state, a
      province or DX outside (uNewContestHostArea.HostAreaOutsideRefusal),
      so a grid cannot be set there. A MY STATE set another way
      (Preferences, an imported .cfg) is not checked -- a gap, reported.

  QSO POINTS -- "SSB: 2 points CW: 3 points digital: 3 points". SSB 2, CW 3,
    every digital submode 3. CalculateQSOPoints.

  OUT-OF-STATE ENTRANTS -- the multiplier list for them is Hawaii's 14
    districts and DXLog scores "Non-KH6 stations are invalid" (-1 points).
    Here that is the party base's host-area rule: refused when typed, an
    automatic X-QSO (0 points, not -1) when logged any other way.

  MULTIPLIERS -- the two kinds of entrant count them differently:
      Non-Hawaii        "14 Hawai'i districts per band. Maximum of 84 (6
                        bands x 14 districts)". hawaiiqp_cty.dom, each
                        district its own multiplier (FCONTEST sets
                        MultipliersIsCounties), per band, NOT per mode. The 84
                        is 14 x the 6 bands UsesBand credits. No DX
                        multiplier.
      Hawaii            "14 Hawai'i districts plus US states (including DC),
                        plus Canadian provinces, plus DXCC entities. ONCE ONLY
                        - NOT PER BAND". hawaiiqp.dom: the districts (each its
                        own multiplier -- a Hawaii-to-Hawaii QSO earns its
                        district, as DXLog's OWN_MULT_VALID says), s48.dom and
                        alaska.dom, dc.dom (DC on its own: "including DC"),
                        p13.dom. DXCC entities are the DX multiplier, IN STATE
                        ONLY, every entity but K, VE, KH6 and KL
                        (uDXMultiplierKey; DXLog's MULT2_EXCEPTION excludes
                        the same four), on the ARRL list (DXLog's
                        DXCC_DB_USE_ARRL_LIST) -- one private predicate,
                        CountsDXMultiplier. A DX station's "DX" is never a
                        domestic multiplier: under DomesticOrDX its text is
                        not looked up, and its entity is the multiplier.
    SO MULT-BY-BAND DEPENDS ON THE ENTRANT: GetFlags states cfMultByBand (an
    out-of-state entrant's, and the identity's) and DescribeSession states
    MultByBand both ways on aStation.InHostState -- False in Hawaii, True
    outside (New Hampshire's and Arizona's pattern). Never cfMultByMode.
    RULING -- HI IS NO STATE MULTIPLIER: a Hawaii station sends its district,
      never "HI", and DXLog's list omits it. hawaiiqp.dom therefore includes
      s48.dom and alaska.dom rather than s50.dom, so a typed HI is refused as
      an improper QTH; and a district does not also earn HI (no
      AdditionalDomesticMultiplierKey -- the rules list districts and states
      side by side, with nothing folding one into the other).

  DISTRICT LINES -- the homepage notes (NY4I, 2026-11-17): "HI stations may
    activate multiple districts by sitting on the boundary ... identify each
    such as AH7RF/KOH/KON. Log such contacts as TWO contacts, one from each
    location. Each is scored separately and not considered a duplicate."
    GetCountyLineCountiesMax = 2. The worked side already does that: the
    party base's county-line entry logs the first district through the
    parse and queues the second, which MainUnit.DrainPendingMultiQSORefs
    logs through LogContact (its own multiplier flags, the first QSO's
    points, ceClearDupeSheet so it is no dupe).
    NOT BUILT -- THE ROVER'S OWN SIDE: "AH7RF/KOH is a different station than
      AH7RF/KON ... Such mobile stations must submit a separate log for each
      activation." The dupe key (DupeKeyQualifier) holds the WORKED
      station's QTH, never our own district, so a rover that changes MY
      STATE in one log gets a dupe for a station it works again from the new
      district; and no export writes a log per activation. One log per
      activation (a new contest log per district) is what works today.
      Issue #133 (station category) is related; a question for NY4I.

  SCORE -- "Final Score is the total number of QSO points times the number of
    earned multipliers". The base's points x multipliers. No power
    multiplier, no bonus station, no cap.

  NOT BUILT -- MOBILE AND PORTABLE CATEGORIES, issue #133: the entrant's
    station category does not reach scoring. Nothing in these rules scores a
    mobile differently.

  CABRILLO -- CONTEST: HI-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; the rules
    state none). DXLog's CABRILLO_LINE is the standard one (freq, mode, date,
    time, my call, sent, call, received). MODES (NY4I): CW, PH, and DG for
    every digital submode (CabrilloModeString). The report columns are never
    empty: PostUnit writes a number, an FT8 SNR converted to an RST
    (uWSJTXReport) -- the sponsor's example shows the raw "-04", which the
    writer does not print. The LOCATION tag is not required by the rules.

  ADIF -- CONTEST_ID HI-QSO-PARTY. STATE: HI for a district (the party base's
    ADIFCountyState), the worked station's state or province otherwise
    (NL for a typed NF or LB), none for a grid QSO.
    CNTY (NY4I): the COUNTY the district lies in, by reverse lookup
      (ADIFCountyName, the PostUnit seam this contest added): HON, LHN, PRL,
      WHN Honolulu; KAU, NII Kauai; LNI, MAU, MOL Maui; KAL Kalawao; HIL,
      KOH, KON, VOL Hawaii -- ADIF's five Hawaii counties, written
      "HI,Honolulu" as every party writes "<state>,<county>". A worked
      station that is no Hawaii district gets none (the party base's
      ADIFCountyState: a two-letter state or province is no county).

  SUBMISSION -- logs are uploaded at hqp.contesting.com; no e-mail address,
    so ''.

  WA7BNM -- 0: the calendar's terms bar automated access (a bench item).

  3830 -- the base's one "Mults" column; the form was not checked (a bench
    item). *)
unit uContestHawaiiQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   HI_QSO_PARTY_CONTEST_ID = 'HI-QSO-PARTY';

(* IS aText A RECEIVED GRID AS THE SPONSOR ACCEPTS ONE -- two letters A-Z
   then two digits, either case, ZZ00 included. See the header. *)
function IsHawaiiQPGridText(const aText: string): boolean;

type
   TContestHawaiiQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- a Hawaii entrant counts
         DXCC entities; nobody else does. HasDXMultiplier, the key and the
         country list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
      (* A DIGITAL QSO WHOSE RECEIVED QTH IS A GRID -- the header. *)
      function IsGridQSO(const aQso: ContestExchange): boolean;
      (* MAY THIS ENTRANT CREDIT A GRID QSO: in Hawaii any station, outside
         only a Hawaii (KH6) one -- the host-area rule's DXLog form. *)
      function CreditsGridQSO(const aQso: ContestExchange): boolean;
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE DISTRICTS THIS CONTEST'S EXCHANGE NAMES. *)
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

      (* No district-line limit: the sponsor states none -- the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* SSB 2, CW 3, digital 3 -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 160, 80, 40, 20, 15 and 10 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, SSB and every digital submode; FM and AM are not SSB. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* CW, PH, and DG for every digital submode -- the header. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;

      (* SET-UP -- see TContestBase.DescribeSession. Only MultByBand, stated
         both ways: once in Hawaii, per band outside it. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;

      (* ' 5NN ' and the district, state or province this station sends; DX
         when it states none, or states DX. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* A GRID IN DIGITAL; THEN THE PARTY'S PARSE, WITH NF AND LB AS NL --
         the header. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;

      (* A GRID WORD IS NOT A CALL -- the call window's correction must not
         take CN87 for the call. *)
      function MayBeACallsign(const aWord: string): boolean; override;

      (* A GRID QSO for an entrant who may work its station; no blank QTH;
         else the host-area rule -- the header. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;

      (* A GRID QSO EARNS NO MULTIPLIER of any kind -- the header. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; override;

      (* THE MULTIPLIERS -- districts, or districts, states, DC and provinces,
         from the domestic file; DXCC entities for a Hawaii entrant; no zone
         or prefix multiplier. *)
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;

      (* WHAT THE EXCHANGE CARRIES -- a domestic QTH (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;

      (* ADIF: no STATE for a grid QSO; CNTY is the district's county; the
         SRX_STRING carries the grid, and NL for NF and LB -- the header. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFCountyName(const aQso: ContestExchange;
                              const aDomesticName: string): string; override;
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;

      (* AN IMPORTED OR WSJT-X QSO: NF/LB as NL, and a Digital QSO's
         GRIDSQUARE as its received grid -- the header. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* THE NEW CONTEST DIALOG SAYS DISTRICT (NY4I) -- the prompt, and the
         host-area row's label and notice. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
      function DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* FormatCabrilloMode *)
   uCabrilloFormat,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   (* SExchangeOutOfStateWorksHostOnly, the New Contest district texts. *)
   uAppStrings,
   uContestRegistry;

function IsHawaiiQPGridText(const aText: string): boolean;
var
   grid: string;
begin
   grid := UpperCase(Trim(aText));
   Result := (Length(grid) = 4) and
             (grid[1] >= 'A') and (grid[1] <= 'Z') and
             (grid[2] >= 'A') and (grid[2] <= 'Z') and
             (grid[3] >= '0') and (grid[3] <= '9') and
             (grid[4] >= '0') and (grid[4] <= '9');
end;

(* NF AND LB ARE NL -- the received QTH as the province code, as DXLog logs
   it. Only those two words; a district line ('HON/WHN') is left alone. *)
procedure NormalizeProvinceAlias(var aExch: ContestExchange);
var
   qth: string;
begin
   qth := UpperCase(Trim(string(aExch.QTHString)));
   if (qth = 'NF') or (qth = 'LB') then
      begin
      aExch.QTHString := 'NL';
      end;
end;

type
   TWords = array of string;

(* THE BLANK-SEPARATED WORDS OF aText, empty ones dropped. *)
function WordsOf(const aText: string): TWords;
var
   i: integer;
   current: string;
begin
   Result := nil;
   current := '';
   for i := 1 to Length(aText) + 1 do
      begin
      if (i > Length(aText)) or (aText[i] = ' ') then
         begin
         if current <> '' then
            begin
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := current;
            current := '';
            end;
         end
      else
         begin
         current := current + aText[i];
         end;
      end;
end;

(* THE SAME RULE OVER A LINE OF WORDS (the SRX_STRING). *)
function ProvinceAliasWordsAsNL(const aText: string): string;
var
   words: TWords;
   i: integer;
   word: string;
begin
   words := WordsOf(aText);
   Result := '';
   for i := 0 to High(words) do
      begin
      word := words[i];
      if (UpperCase(word) = 'NF') or (UpperCase(word) = 'LB') then
         begin
         word := 'NL';
         end;
      if i > 0 then
         begin
         Result := Result + ' ';
         end;
      Result := Result + word;
      end;
end;

(* "[report] GRID": one word, the grid; or two, a signed whole-number report
   and the grid. The report, when given, is the received report. *)
function TryParseGridExchange(const aText: string; var aExch: ContestExchange): boolean;
var
   words: TWords;
   report: integer;
begin
   Result := False;
   words := WordsOf(aText);
   if (Length(words) < 1) or (Length(words) > 2) then
      begin
      Exit;
      end;
   if not IsHawaiiQPGridText(words[High(words)]) then
      begin
      Exit;
      end;
   if Length(words) = 2 then
      begin
      if not TryStrToInt(words[0], report) or
         (report < Low(SmallInt)) or (report > High(SmallInt)) then
         begin
         Exit;
         end;
      aExch.RSTReceived := report;
      end;
   aExch.QTHString := ShortString(UpperCase(words[High(words)]));
   aExch.DomesticQTH := '';
   aExch.DomMultQTH := '';
   Result := True;
end;

function TContestHawaiiQP.GetDisplayName: string;
begin
   Result := 'Hawaii QSO Party';
end;

(* WHEN IT RUNS -- the sponsor's rules (issue 118, NY4I 2026-11-17), rule 1:
   36 hours from 1600 UTC on the Saturday before the 4th Sunday of August
   (Aug 22 2026, Aug 21 2027 -- the header). *)
function TContestHawaiiQP.GetSchedule: string;
begin
   Result := 'the Saturday before the 4th Sunday of August at 16:00 UTC for 36h';
end;

function TContestHawaiiQP.GetHostState: string;
begin
   Result := 'HI';
end;

function TContestHawaiiQP.GetCabrilloName: string;
begin
   (* The rules state none; DXLog's CABRILLO_CONTEST_NAME=HI-QSO-PARTY. *)
   Result := 'HI-QSO-PARTY';
end;

function TContestHawaiiQP.GetADIFContestId: string;
begin
   (* The ADIF Contest_ID enumeration's HI-QSO-PARTY. Export writes it,
      import matches it. *)
   Result := HI_QSO_PARTY_CONTEST_ID;
end;

function TContestHawaiiQP.GetWA7BNMId: integer;
begin
   (* Not looked up: the calendar bars automated access -- a bench item. *)
   Result := 0;
end;

function TContestHawaiiQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestHawaiiQP.GetSubmissionEmail: string;
begin
   (* Logs are uploaded at hqp.contesting.com. *)
   Result := '';
end;

function TContestHawaiiQP.GetDomesticFileName: string;
begin
   (* The district file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Hawaii district, and then loads hawaiiqp.dom or
      this file. Not 'hawaii': hawaii.dom is the Hawaii-state line s50.dom
      includes. Lower case: the file's own name, which matters off Windows. *)
   Result := 'hawaiiqp_cty';
end;

function TContestHawaiiQP.GetFriendlyName: string;
begin
   Result := 'Hawaii QSO Party';
end;

function TContestHawaiiQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestHawaiiQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestHawaiiQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestHawaiiQP.ParseReceivedExchangeFormat(const aText: string;
                                                      aParsers: TExchangeParsers;
                                                      var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestHawaiiQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* WHAT WAS TRANSMITTED: "Non-USA / Canada stations send "DX"" -- the same
   SentStateOrDX the Cabrillo column asks, so the two cannot spell it
   differently. *)
function TContestHawaiiQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestHawaiiQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   (* A DX entrant sends "DX" -- the header. *)
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestHawaiiQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange;
                                                      const aCtx: TCabrilloQSOContext): string;
begin
   if IsGridQSO(aQso) then
      begin
      (* The grid in the QTH column, the sponsor's example -- the header. *)
      Result := UnicodeFormat('%-3s %-7s',
                              [aCtx.RSTReceived, UpperCase(Trim(string(aQso.QTHString)))]);
      end
   else
      begin
      (* A DX station's column is "DX", what it sent -- also when its entity
         was TYPED: the DX branch keeps that text in QTHString and the table
         resolves nothing, so the record has no DomesticQTH.
         CabrilloReceivedRSTQTHDX tests QTHString and would leave the column
         empty. *)
      Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
      end;
end;

function TContestHawaiiQP.GetInStateDomesticFileName: string;
begin
   Result := 'hawaiiqp';
end;

function TContestHawaiiQP.GetFlags: TContestFlags;
begin
   (* "three times per band. Once each on CW, SSB, digital"; an out-of-state
      entrant's districts "per band" (cfMultByBand -- DescribeSession states
      it False in Hawaii); never per mode. No band above 10 m. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestHawaiiQP.GetCountyLineCountiesMax: integer;
begin
   (* "identify each such as AH7RF/KOH/KON. Log such contacts as TWO
      contacts" -- the homepage notes (NY4I, 2026-11-17). *)
   Result := 2;
end;

(* SSB 2, CW 3, DIGITAL 3. An off-band or off-mode QSO never reaches here
   (UsesBand, UsesMode), nor a station this entrant may not credit
   (CreditsWorkedStation). *)
procedure TContestHawaiiQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 3;
         end;
      Phone:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestHawaiiQP.UsesBand(aBand: BandType): boolean;
begin
   (* "only on the 10, 15, 20, 40, 80, and 160 meter bands". *)
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* "CW, SSB, digital (digital is any binary mode ...)". Phone only in an
   SSB submode; eNoMode and eData mean "some submode", so an old record is
   never proven off-mode (Q98 S1). FM is its own ModeType and is refused. An
   identity fact: no station is asked. *)
function TContestHawaiiQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Digital:
         begin
         Result := True;
         end;
      Phone:
         begin
         Result := aExtMode in [eNoMode, eData, eSSB, eUSB, eLSB];
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestHawaiiQP.CabrilloModeString(aMode: ModeType;
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

(* "Non-Hawaiian stations: 14 Hawai'i districts per band ... Hawai'i
   stations: ... ONCE ONLY - NOT PER BAND". Stated both ways (design D8). *)
procedure TContestHawaiiQP.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   if aStation.InHostState then
      begin
      aSession.MultByBand := False;
      end
   else
      begin
      aSession.MultByBand := True;
      end;
end;

function TContestHawaiiQP.CQExchangeDefault(const aStation: TStationContext): string;
var
   my: TMyStationExchange;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Hawaii station's district, anyone else's state or province. A DX
      entrant has none, or the New Contest dialog's DX, and sends DX --
      SentStateOrDX, the export's own rule. *)
   my := Default(TMyStationExchange);
   my.MyState := aStation.MyState;
   Result := ' 5NN ' + SentStateOrDX(my);
end;

function TContestHawaiiQP.ParseReceivedExchange(const aText: string;
                                                const aSession: TReceivedExchangeSession;
                                                var aExch: ContestExchange;
                                                out aErrorMessage: string): boolean;
begin
   aErrorMessage := '';
   (* A DIGITAL QSO MAY CARRY A GRID -- the header. Tried first, so a grid
      never reaches the domestic parser, which would refuse it. *)
   if (aExch.Mode = Digital) and
      TryParseGridExchange(aText, aExch) then
      begin
      Result := CreditsGridQSO(aExch);
      if not Result then
         begin
         aErrorMessage := UnicodeFormat(SExchangeOutOfStateWorksHostOnly, [HostState]);
         end;
      Exit;
      end;

   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if Result then
      begin
      NormalizeProvinceAlias(aExch);
      end;
end;

function TContestHawaiiQP.MayBeACallsign(const aWord: string): boolean;
begin
   Result := (not IsHawaiiQPGridText(aWord)) and
             inherited MayBeACallsign(aWord);
end;

function TContestHawaiiQP.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   if IsGridQSO(aQso) then
      begin
      Result := CreditsGridQSO(aQso);
      end
   else if Trim(string(aQso.QTHString)) = '' then
      begin
      (* "a blank received QTH scores zero" -- the header. *)
      Result := False;
      end
   else
      begin
      Result := inherited CreditsWorkedStation(aQso);
      end;
end;

function TContestHawaiiQP.CountsAsMultiplier(const aQso: ContestExchange;
                                             aKind: RemainingMultiplierType): boolean;
begin
   (* The sponsor decides a grid QSO's multiplier -- the header. *)
   Result := not IsGridQSO(aQso);
end;

function TContestHawaiiQP.IsGridQSO(const aQso: ContestExchange): boolean;
begin
   Result := (aQso.Mode = Digital) and
             IsHawaiiQPGridText(string(aQso.QTHString));
end;

function TContestHawaiiQP.CreditsGridQSO(const aQso: ContestExchange): boolean;
begin
   Result := Station.InHostState or
             (aQso.QTH.CountryID = 'KH6');
end;

function TContestHawaiiQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "Hawai'i stations: ... plus DXCC entities"; none outside, where an
   entrant works only Hawaii stations. *)
function TContestHawaiiQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every DXCC entity but the USA, Canada, Hawaii and Alaska: the districts,
   states and provinces are multipliers of their own. False is "leave the DX
   QTH as it was". *)
function TContestHawaiiQP.DXMultiplierKey(const aQso: ContestExchange;
                                          out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* The ARRL DXCC list where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestHawaiiQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestHawaiiQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestHawaiiQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestHawaiiQP.ADIFCountyState(const aQso: ContestExchange): string;
begin
   (* A grid says nothing about where the station is. WSJT-X's hand-off
      copies the grid into DomesticQTH, which the base would take for a
      county. *)
   if IsGridQSO(aQso) then
      begin
      Result := '';
      end
   else
      begin
      Result := inherited ADIFCountyState(aQso);
      end;
end;

(* THE COUNTY A DISTRICT LIES IN -- ADIF's five Hawaii counties, by the
   district key the record resolved. *)
function TContestHawaiiQP.ADIFCountyName(const aQso: ContestExchange;
                                         const aDomesticName: string): string;
var
   key: string;
begin
   key := UpperCase(Trim(string(aQso.DomesticQTH)));
   if key = '' then
      begin
      key := UpperCase(Trim(string(aQso.QTHString)));
      end;
   if (key = 'HON') or (key = 'LHN') or (key = 'PRL') or (key = 'WHN') then
      begin
      Result := 'Honolulu';
      end
   else if (key = 'KAU') or (key = 'NII') then
      begin
      Result := 'Kauai';
      end
   else if (key = 'LNI') or (key = 'MAU') or (key = 'MOL') then
      begin
      Result := 'Maui';
      end
   else if key = 'KAL' then
      begin
      Result := 'Kalawao';
      end
   else if (key = 'HIL') or (key = 'KOH') or (key = 'KON') or (key = 'VOL') then
      begin
      Result := 'Hawaii';
      end
   else
      begin
      Result := '';
      end;
end;

function TContestHawaiiQP.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                     aExchangeCarriesRST: boolean): string;
var
   grid: string;
begin
   if IsGridQSO(aQso) then
      begin
      grid := UpperCase(Trim(string(aQso.QTHString)));
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
      Result := ProvinceAliasWordsAsNL(
         inherited FormatADIFReceivedExchange(aQso, aExchangeCarriesRST));
      end;
end;

procedure TContestHawaiiQP.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                           const aSession: TADIFImportSession;
                                           var aExch: ContestExchange);
var
   grid: string;
begin
   inherited ApplyADIFImport(aTemps, aSession, aExch);
   NormalizeProvinceAlias(aExch);

   (* WSJT-X's GRIDSQUARE is the received grid of a Digital QSO that carries
      no other QTH -- the header. *)
   grid := UpperCase(Copy(Trim(aTemps.GridSquare), 1, 4));
   if (aExch.Mode = Digital) and
      (Trim(string(aExch.QTHString)) = '') and
      IsHawaiiQPGridText(grid) then
      begin
      aExch.QTHString := ShortString(grid);
      aExch.DomesticQTH := '';
      aExch.DomMultQTH := '';
      end;
end;

procedure TContestHawaiiQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestHawaiiQPDistrictOrLocation, ncfMyState);
end;

function TContestHawaiiQP.DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean;
begin
   Result := inherited DescribeNewContestHostArea(aArea);
   aArea.PlaceLabel := SNewContestHostAreaDistrictLabel;
   aArea.InsideNotice := SNewContestHostAreaInsideDistrictNotice;
end;

initialization
   RegisterContestById(HI_QSO_PARTY_CONTEST_ID, TContestHawaiiQP);

end.
