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

(* THE NEW MEXICO QSO PARTY -- a NEW contest, registered BY ID (2026-10-26,
  GitHub issue #125).

  ITS ID IS NM-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen (Lint-FrozenContestNumbers) -- so the contest is refused on
  the multi-op network and its UDP contest number is derived from its id
  (both the registry's, nothing here).

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and "Non-NM stations: Work NM stations
  for NM counties only" -- the base's host-area rule (design 7.10, Q107).
  Copied from uContestGeorgiaQP (ADDING_A_CONTEST's template), not from a
  nearby party; a copy it owns. D7 never had this contest.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/NewMexico/
                  NM-QSO-PARTY-Rules.txt -- "2026 New Mexico QSO Party Form
                  Packet", "Last modified: 09 April 2026" (rules, check
                  sheets, summary sheet; NMQP_Forms.pdf beside it), fetched
                  2026-10-26 from newmexicoqsoparty.org. No 2027 rules are
                  published yet.
    ADIF 3.1.6/7  Contest_ID NM-QSO-PARTY
    WA7BNM        ref 286, Cabrillo name NM-QSO-PARTY
    NY4I          his decisions on #125 (2026-10-26), quoted below.

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "Second Saturday of April, 8:00 MDT (1400 UTC) to 20:00 MDT (0200
    UTC)", 12 hours. Contest schedules are not built (design Q99); recorded
    only.

  BANDS -- "160-10 meters, plus 6 and 2 meters ... Not permitted: WARC
    bands, 60 meters, and bands above 2 meters": 160, 80, 40, 20, 15, 10, 6
    and 2 m. UsesBand; cfVHFBandsEnabled so 6 m and 2 m can be reached.
    (DXLog adds 432 MHz; the rules win.)

  MODES -- "Phone, CW, digital (any computer-to-computer mode is considered
    digital)". NY4I: every digital mode counts, FT8/FT4 included (the rules
    accept them with the full exchange). FM is phone ("146.52 MHz FM" is a
    phone frequency). UsesMode credits CW, Phone, FM and every submode of
    Digital.

  EXCHANGE -- "New Mexico stations: RS(T) + New Mexico county / Non-New
    Mexico stations: RS(T) + State/Province/DXCC entity".
    RSTDomesticOrDXQTHExchange; the three-letter county codes are
    newmexico_cty.dom. A DX ENTRANT SENDS ITS DXCC ENTITY ON THE AIR (NY4I):
    the CQ exchange is the party base's LocationOrOwnCountry, and the ADIF
    STX_STRING is the party base's SentLocation -- STX_STRING is a record of
    what was TRANSMITTED (ADIF: "contest QSO transmitted information"), so it
    holds what went on the air. THE CABRILLO COLUMNS ARE "DX" (NY4I): "QTH is
    three letter NM county abbreviation, or two-letter State/Province
    abbreviation, or "DX"", and the rules' sample line "599 BER LY2ZZ 599
    DX". Cabrillo is the sponsor's scoring format, so it carries their
    vocabulary: the DX entrant's sent column is CabrilloSentRSTStateOrDX, and
    a DX station received is CabrilloReceivedRSTDomesticQTHOrDX -- "DX"
    whenever the record holds no domestic QTH, whatever was typed for it
    (CabrilloReceivedRSTQTHDX, Georgia's, writes a typed "599 LY" as an
    empty column).

  QSO POINTS -- "Each Phone contact = 1 point / Each CW contact = 2 points /
    Each Digital contact = 2 points", the same for every entrant. Phone 1
    (FM is phone), CW 2, digital 2. CalculateQSOPoints.

  DUPES -- "Stations may be worked only once per mode, per band":
    cfQSOByBand, cfQSOByMode, with CW, Phone and Digital three dupe modes
    (the base's DupeModeOf, identity; FM shares Phone's slot -- DXLog agrees,
    MODE_GROUP=CW;PH;DG). "A New Mexico mobile station that travels into a
    new county is considered to be a new station and may be contacted again
    for point and multiplier credit"; W1AW/5 "may be worked multiple times on
    the same band and mode when operating from different New Mexico
    counties"; an Expedition station "relocates to a new county, it is
    considered a new station" -- the party base's received-QTH dupe key and
    rover strip/split, inherited.

  OUT-OF-STATE ENTRANTS -- "Non-NM stations: Work NM stations for NM
    counties only": the party base's host-area rule, refused when typed and
    an automatic X-QSO when logged any other way. Nothing here.

  MULTIPLIERS -- "Each multiplier may be counted ONLY ONCE, regardless of
    mode or band": neither cfMultByBand nor cfMultByMode.
      NM stations     newmexico.dom: "each different NM county worked (up to
                      33)" -- each its own multiplier (newmexico_cty.dom maps
                      none to the state); "states worked (up to 50)" -- New
                      Mexico among them (the state check sheet lists it), so
                      no CountsAsMultiplier override; "District of Columbia
                      (DC) counts as Maryland" (the file's Dc > Md, before
                      S50.DOM); "Canadian provinces/territories worked (up to
                      13)" (P13.DOM, after S50 so LA stays Louisiana; NF and
                      LB read as NL). "and DX entities worked ... Alaska and
                      Hawaii count as state multipliers only ... United States
                      and Canada do not count as DX entity multipliers": the
                      DX multiplier, IN STATE ONLY, every DXCC entity but K,
                      VE, KH6 and KL (uDXMultiplierKey's
                      DXCCKeyExceptUSACanadaHawaiiAlaska) -- NY4I: US
                      possessions such as KP4 count as DX -- on the ARRL list
                      ("See http://www.arrl.org/country-lists-prefixes"). One
                      private predicate, CountsDXMultiplier, asked by
                      HasDXMultiplier, DXMultiplierKey and CountryMode.
      Non-NM          newmexico_cty.dom: "each different NM county worked (up
                      to 33)", each its own multiplier (FCONTEST sets
                      MultipliersIsCounties). No DX multiplier.
    OPEN (NY4I's question on #125): does an NM station's QSO with another NM
    station earn the state NM as well as the county? Built as county-only:
    TR4W gives one domestic multiplier per QSO, so state NM is earned only
    when "NM" is what was received. If yes, it is South Carolina's
    two-multiplier seam (#111).

  POWER -- "Power multiplier based on maximum power used: QRP (5 watts or
    less): x5 / Low Power (> 5 - 150 watts): x2 / High Power: (> 150 watts):
    x1", from Station.MyPower (the entrant's CATEGORY-POWER: an operator at
    101-150 W declares LOW). NewMexicoPowerMultiplier is the mapping;
    CombineWithMultipliers applies it: "Total = (Sum of QSO points ... x power
    multiplier x location multiplier) + W1AW/5 contact bonus".

  THE W1AW/5 BONUS -- "W1AW/5 Bonus (new, for 2026 only): Add an additional
    250 points to your final score for a valid contact with W1AW/5. Bonus
    points are valid for one (1) W1AW/5 QSO only, regardless of band, mode,
    or W1AW/5's county." BonusPoints, so it is added AFTER multiplying
    (FinalScore = CombineScore + BonusPoints), once, for a contact
    IsCreditedContact accepts (not a dupe, not an X-QSO -- "a valid
    contact"). TIED TO THE YEAR (NY4I): the log's contest year,
    uContestBase.LogContestYear, never the clock -- Idaho's per-year
    pattern (Q35). NewMexicoW1AWBonusPoints is the one place a year is
    stated: 2026 pays 250; a year before it pays nothing (the 2026 packet
    calls the bonus "new"); a later year has NO RULING until the sponsor
    publishes one, so it pays nothing and logs ONE Error per year (the party
    base's ReportNoTableForYear). The yearly pin test reads the clock and
    fails on the first run of a year with no ruling.
    NOT MATCHED: a county-suffixed W1AW/5/BER. The base pays a bonus
    station by an exact comparison with the logged call
    (TContestBase.BonusStationWorked), and the logged call keeps its
    suffix. The base fix -- strip a suffix that is a county of the contest
    -- is South Carolina's (#111, "A bonus station logged with a county
    suffix ... pays"); not built here.

  COUNTY LINES -- "only one County Line at a time can be run ... only two
    counties at a time may be counted for the same contact" (an Expedition
    likewise): GetCountyLineCountiesMax = 2; TR4W's county-line entry logs
    one QSO per county.

  NOT BUILT (issues #133 and #87) -- THE MOBILE BONUS: "Add an additional
    5,000 points to the final score for every county from which at least 15
    valid QSOs were made" (NM mobile stations only; "Expedition stations are
    not eligible"); and A MOVING NM ENTRANT: "A New Mexico mobile station
    that travels into a new county may contact other stations again for
    point credit". Both need the entrant's station category in scoring
    (#133) and the county each QSO was SENT from (#87). Until then a mobile
    scores as a fixed station.

  NOT REPRESENTABLE, CONDUCT RULES ONLY -- "All contacts must be made
    without the assistance of intermediary stations"; the 50-meter county
    line tolerance; the Expedition's 30-QSO qualification. Nothing built.

  CABRILLO -- CONTEST: NM-QSO-PARTY, the rules' sample header. The rules'
    template "QSO: 14000 PH 2010-02-07 1501 KB5SXB/M 59 BER NK5W 59 SAN":
    the standard QSO line. "Modes are PH, CW, or RY. Use RY to designate all
    digital modes": CabrilloModeString, every digital submode RY and FM PH
    (uCabrilloFormat.FormatCabrilloModeDigitalAsRY). "The ARRL-SECTION: tag
    (Cabrillo v2.0) and LOCATION: tag (Cabrillo v3.0) is used to identify New
    Mexico stations for proper automated log checking and scoring":
    RequiresCabrilloLocation True (NY4I), the operator's value from the
    summary window. ADIF -- CONTEST_ID NM-QSO-PARTY (ADIF's own enumeration).

  SUBMISSION -- "Electronic logs should be emailed to
    logs@newmexicoqsoparty.org".

  3830 -- no 3830scores.com form for this contest was found, so the base's
    one "Mults" column; no Get3830Summary override until the form is seen. *)
unit uContestNewMexicoQP;

{$I tr4w.inc}

interface

uses
   (* cpLOW / cpQRP -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   NM_QSO_PARTY_CONTEST_ID = 'NM-QSO-PARTY';

   (* THE BONUS STATION, as the rules spell it -- see the header. *)
   NM_W1AW_BONUS_CALL = 'W1AW/5';

type
   TContestNewMexicoQP = class(TContestStateQSOPartyBase)
   private
      (* THE ONE PREDICATE for the DX multiplier -- an NM entrant counts DXCC
         entities; nobody else does. HasDXMultiplier, the key and the country
         list ask it, so the answers cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
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

      (* A county line is two counties -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* LOCATION: is required -- see the header. *)
      function GetRequiresCabrilloLocation: boolean; override;

      (* Phone 1, CW 2, digital 2 -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x MULTIPLIERS x THE POWER MULTIPLIER -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;

      (* "a valid contact with W1AW/5" -- not a dupe, not an X-QSO. *)
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      (* 160, 80, 40, 20, 15, 10, 6 and 2 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone (FM is phone) and every digital mode -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the county, state or province this station sends; its
         own DXCC entity when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* CW, PH and RY -- every digital mode is RY, FM is phone. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;

      (* THE W1AW/5 BONUS, 250, once, in its year -- the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;

      (* DOES THE CLASS HOLD A RULING ON THE W1AW/5 BONUS FOR aYear? The
         yearly pin test asks it of the current year, so the first run of a
         year with no ruling fails until the sponsor's word is added. *)
      class function HasW1AWBonusRuling(aYear: integer): boolean;

      (* THE MULTIPLIERS -- counties, or counties, states and provinces, from
         the domestic file; DXCC entities for an NM entrant; no zone or
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

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER -- QRP x5, LOW x2, HIGH x1.
   Public so the tests assert the mapping itself, not only a product. *)
function NewMexicoPowerMultiplier(aPower: tCategoryPower): longint;

(* THE W1AW/5 BONUS FOR A CONTEST YEAR -- the one place a year is stated.
   False when the year has no ruling (aPoints 0); True with what the bonus
   pays that year, 0 when it pays nothing. See the header. *)
function NewMexicoW1AWBonusPoints(aYear: integer; out aPoints: longint): boolean;

implementation

uses
   (* The "no ruling for this year" Error. *)
   Log4D,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* FormatCabrilloModeDigitalAsRY -- "Use RY to designate all digital
      modes". *)
   uCabrilloFormat,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska, DXCCCountryMode -- issue #136. *)
   uDXMultiplierKey,
   uContestRegistry;

const
   (* "Add an additional 250 points" (reduced from 500 on 09 April). *)
   NM_W1AW_BONUS_2026 = 250;

   (* The first year the bonus existed: "new, for 2026 only". *)
   NM_W1AW_BONUS_FIRST_YEAR = 2026;

var
   logger: TLogLogger;

function NewMexicoPowerMultiplier(aPower: tCategoryPower): longint;
begin
   case aPower of
      cpQRP:
         begin
         Result := 5;
         end;
      cpLOW:
         begin
         Result := 2;
         end;
      else
         begin
         Result := 1;
         end;
      end;
end;

function NewMexicoW1AWBonusPoints(aYear: integer; out aPoints: longint): boolean;
begin
   aPoints := 0;
   if aYear = NM_W1AW_BONUS_FIRST_YEAR then
      begin
      aPoints := NM_W1AW_BONUS_2026;
      Result := True;
      end
   else if (aYear > 0) and
           (aYear < NM_W1AW_BONUS_FIRST_YEAR) then
      begin
      (* Before the bonus was "new": no bonus, a ruling. *)
      Result := True;
      end
   else
      begin
      (* Year 0 (unknown) or a year after 2026: no ruling yet. *)
      Result := False;
      end;
end;

function TContestNewMexicoQP.GetDisplayName: string;
begin
   Result := 'New Mexico QSO Party';
end;

function TContestNewMexicoQP.GetHostState: string;
begin
   Result := 'NM';
end;

function TContestNewMexicoQP.GetCabrilloName: string;
begin
   (* The rules' sample header: "CONTEST: NM-QSO-PARTY". *)
   Result := 'NM-QSO-PARTY';
end;

function TContestNewMexicoQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.6 and 3.1.7's Contest_ID enumeration; export writes it,
      import matches it. *)
   Result := NM_QSO_PARTY_CONTEST_ID;
end;

function TContestNewMexicoQP.GetWA7BNMId: integer;
begin
   (* contestcalendar.com contestdetails.php?ref=286. *)
   Result := 286;
end;

function TContestNewMexicoQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewMexicoQP.GetSubmissionEmail: string;
begin
   (* "Electronic logs should be emailed to logs@newmexicoqsoparty.org". *)
   Result := 'logs@newmexicoqsoparty.org';
end;

function TContestNewMexicoQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a New Mexico county, and then loads newmexico.dom
      or this file. Lower case: the file's own name, which matters off
      Windows. *)
   Result := 'newmexico_cty';
end;

function TContestNewMexicoQP.GetFriendlyName: string;
begin
   Result := 'New Mexico QSO Party';
end;

function TContestNewMexicoQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewMexicoQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNewMexicoQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNewMexicoQP.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestNewMexicoQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* WHAT WENT ON THE AIR: a DX entrant has no MY STATE and sent its DXCC
   entity (rule 6, NY4I) -- the party base's SentLocation. STX_STRING is the
   transmitted information, not the sponsor's column; see the header. *)
function TContestNewMexicoQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(SentLocation(aMy), aQso);
end;

(* THE SPONSOR'S COLUMN: a DX entrant's QTH is "DX" (NY4I, the rules' "QTH
   is ... or "DX""). *)
function TContestNewMexicoQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

(* "599 BER LY2ZZ 599 DX": a DX station is "DX" whatever it sent. *)
function TContestNewMexicoQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

function TContestNewMexicoQP.GetInStateDomesticFileName: string;
begin
   Result := 'newmexico';
end;

function TContestNewMexicoQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE OVERALL (neither
      cfMultByBand nor cfMultByMode); 6 m and 2 m are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestNewMexicoQP.GetCountyLineCountiesMax: integer;
begin
   (* "only two counties at a time may be counted for the same contact". *)
   Result := 2;
end;

function TContestNewMexicoQP.GetRequiresCabrilloLocation: boolean;
begin
   (* "The ARRL-SECTION: tag (Cabrillo v2.0) and LOCATION: tag (Cabrillo
      v3.0) is used to identify New Mexico stations for proper automated
      log checking and scoring." *)
   Result := True;
end;

(* PHONE 1, CW 2, DIGITAL 2. FM is phone. An off-band QSO (UsesBand) and a
   station an out-of-state entrant may not credit (CreditsWorkedStation)
   never reach here. Both and NoMode are not modes a contact is made in. *)
procedure TContestNewMexicoQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
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

function TContestNewMexicoQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals) *
             NewMexicoPowerMultiplier(Station.MyPower);
end;

function TContestNewMexicoQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

(* THE ORDER IS DELIBERATE: the year is asked only once W1AW/5 was worked,
   so a log that never worked it is never reported as missing a ruling. *)
function TContestNewMexicoQP.BonusPoints(const aTotals: TScoreTotals;
                                         aView: TLoggedQSOView): longint;
var
   year: integer;
   points: longint;
begin
   Result := inherited BonusPoints(aTotals, aView);

   (* "regardless of band, mode, or W1AW/5's county" -- any mode; the mode
      argument is not read when aAnyMode is True. *)
   if not BonusStationWorked(aView, NM_W1AW_BONUS_CALL, True, CW) then
      begin
      Exit;
      end;

   year := LogContestYear(aTotals, aView);
   if not NewMexicoW1AWBonusPoints(year, points) then
      begin
      ReportNoTableForYear(logger, year, 'W1AW/5 bonus ruling', 'the W1AW/5 bonus',
                           'newmexicoqsoparty.org');
      Exit;
      end;

   Result := Result + points;
end;

class function TContestNewMexicoQP.HasW1AWBonusRuling(aYear: integer): boolean;
var
   points: longint;
begin
   Result := NewMexicoW1AWBonusPoints(aYear, points);
end;

function TContestNewMexicoQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10, Band6, Band2];
end;

(* "Phone, CW, digital (any computer-to-computer mode is considered
   digital)" -- every submode of each, FT8 and FT4 included (NY4I). FM is
   phone. An identity fact: no station is asked. *)
function TContestNewMexicoQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM, Digital];
end;

function TContestNewMexicoQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): an
      NM station's county, anyone else's state or province. A DX entrant has
      none and sends its DXCC entity -- the party base's
      LocationOrOwnCountry. *)
   Result := ' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry);
end;

function TContestNewMexicoQP.CabrilloModeString(aMode: ModeType;
                                                aExtMode: ExtendedModeType): string;
begin
   Result := FormatCabrilloModeDigitalAsRY(aMode, aExtMode);
end;

function TContestNewMexicoQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* "and DX entities worked" -- for "New Mexico participants" only; an
   out-of-state entrant counts "NM county worked (up to 33)" alone. *)
function TContestNewMexicoQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* "Alaska and Hawaii count as state multipliers only"; "United States and
   Canada do not count as DX entity multipliers" -- every DXCC entity but K,
   VE, KH6 and KL for an NM entrant (US possessions count, NY4I); none for
   anyone else. False is "leave the DX QTH as it was". *)
function TContestNewMexicoQP.DXMultiplierKey(const aQso: ContestExchange;
                                             out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* The ARRL DXCC list where the entrant counts the DX multiplier ("See
   http://www.arrl.org/country-lists-prefixes for valid list of entities");
   the CQ list for anyone else, who counts none. *)
function TContestNewMexicoQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

function TContestNewMexicoQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestNewMexicoQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

initialization
   logger := TLogLogger.GetLogger('uContestNewMexicoQP');
   RegisterContestById(NM_QSO_PARTY_CONTEST_ID, TContestNewMexicoQP);

end.
