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

(* PENNSYLVANIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'pa_cty';  WA7BNM: 153;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 14;  AE: QSONumberDomesticQTHExchange;
   XM: NoDXMults;  QP: PAQSOPointMethod;  ADIFName: 'PA-QSO-PARTY';
   CABName: 'PA-QSO-PARTY';  CountyLineAllowed: True;
   FriendlyName: 'Pennsylvania QSO Party'

  ITS POINT METHOD WAS SHARED WITH ANOTHER CONTEST. PAQSOPointMethod is also
  the QP in IN7QPNE's row, the combined Indiana / 7th call area / New England
  / Delaware entry -- which scored every QSO through the legacy arm until it
  gained its composite class on 2026-10-14 (design 8.2r) and now scores each
  QSO by its party's class. The arm stayed only for an operator's QSO POINT
  METHOD, and was deleted with the legacy scoring case at M10 S3 (design
  7.15).

  AUDITED AGAINST THE SPONSOR'S 2026 RULES (revision 09/20/26,
  docs/ContestRules/QSOParties/Pennslyvania/PAQSO_Rules.md), 2026-11-20:
  the exchange is a serial plus a PA county, ARRL section, Canadian section
  or DX (5.a), so pa.dom includes arrlsect.dom, not the states and
  provinces; bands are all but WARC (3.b); modes CW 2 and Phone 1 (6), no
  digital; QRP doubles the points (10.d); the 2026 bonus station K3ZMC pays
  200 (11). NOT BUILT: the category matrix.

  THE ROVER AND ELECTRONIC-SUBMISSION BONUSES ARE THE OPERATOR'S, NOT OURS
  (NY4I, 2026-11-20): "That is not something we could know unless we
  calculate the different counties the rover operated from. That just like
  the electronic submission is something the user needs to add at log
  submission time." BonusPoints pays the bonus station alone; nothing here
  computes 10.e's 500 points or the e-submission bonus, and a test pins it.

  SECTION MULTIPLIERS FOR AN IN-STATE ENTRANT (NY4I, 2026-11-20, quoting the
  sponsor): "For in-state stations, the first EPA and WPA county worked will
  count both the county and the section multiplier in the score. Likewise,
  the first DXCC station worked counts as the single DX multiplier." The
  section is the #317 second domestic key (AdditionalDomesticMultiplierKey):
  a credited PA county also earns EPA or WPA, on the domestic sheet, once
  (no cfMultByBand / cfMultByMode). Both are keys of the in-state file
  through arrlsect.dom (`EPA = EP,EPA`, `WPa = WP,WPA`; the sheet compares
  without case). The DX multiplier is pa.dom's single `dx = dx` key, already.

  THE COUNTY-TO-SECTION CROSSWALK is tr4w/tools/trmaster/
  arrl-sections-counties.json (keyed by county NAME, read by the Python
  county_section.py; there is no Pascal reader). PA_COUNTY_SECTIONS below
  was generated from it by joining its names to pa_cty.dom's ^Name on
  county_section.county_key: 66 of 67 joined, and the 67th is pa_cty.dom's
  misspelling "Northhampton" (Northampton, EPA in the JSON). A test pins
  every pa_cty.dom key to a section.

  A STATION OUTSIDE PA SENDS ITS ARRL OR RAC SECTION (NY4I, 2026-11-20:
  "Rather than an op in Florida sending FL to the PA station, I would send
  WCF"). MY STATE holds it -- DescribeNewContestHostArea asks the New
  Contest dialog for a section (OutsideTakesSection) -- and the sent
  columns write MY STATE as they always did.

  NO COUNTY-LINE MAXIMUM IS ESTABLISHED FOR THIS PARTY, so it inherits
  TContestStateQSOPartyBase's CountyLineCountiesUnlimited -- exactly what TR4W
  does today, because nothing in the program has ever counted the queued
  counties.

  (Rule 9.e, 2026-11-20: a county line station sits on "two or more
  adjacent counties" and logs a QSO for each; the rules state NO maximum, so
  unlimited is the sponsor's, not a gap.)

  THAT WAS "NOT LOOKED UP YET", NOT "UNLIMITED BY DECISION". Its row does carry
  CountyLineAllowed: True, and that boolean carries no LIMIT at all: reading
  its False arm as zero is the defect that made a contest start refusing a
  two-QTH exchange the moment it got a class, and reading its True arm as some
  particular number would be an invention. A number must come from the
  sponsor's published rules the way Florida's two and California's four did.
 *)
unit uContestPennsylvaniaQP;

{$I tr4w.inc}

interface

uses
   VC,
   uContestBase,   (* TContestFlags (M10 S5) *)
   uContestStateQSOPartyBase,
   (* TCallHistoryFields, chf... -- CallHistoryFields. *)
   uCallHistory;

type
   TContestPennsylvaniaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same answer -- but the base makes it
         abstract for state parties precisely so that answer is never an
         accident. *)
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
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
      function CountsTowardBonus(const aQso: ContestExchange): boolean; override;
   public
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFWorkedStationState(const aQso: ContestExchange): string; override;
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
      function PerQSOExchangeLeadsWithSerial: boolean; override;
      (* AN IN-STATE COUNTY ALSO EARNS ITS SECTION, EPA or WPA -- the header
         (#317). *)
      function AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
                                               out aKey: string): boolean; override;
      (* OUTSIDE PA, MY STATE IS AN ARRL OR RAC SECTION -- the header. *)
      function DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean; override;
   public
      (* WHAT THE CALL HISTORY FILE PREFILLS --
         THE COUNTY OR STATE -- the site file QSOP_PA carries Call, Exch1, UserText
         (read 2026-11-20): the QTH the station sent (a county code, a state
         or a DX prefix). This party remembers the QTH alone (its received
         fields carry no name). 1632 of 1633 non-state rows are county keys of its
         own county file (Pennsylvania: its in-state file pa.dom, which holds the ARRL sections); the rest are DX prefixes and a few spellings it lacks.
         See TContestBase.CallHistoryFields. *)
      function CallHistoryFields: TCallHistoryFields; override;

      (* THE SITE'S FILE STEM. See TContestBase.CallHistorySiteName. *)
      function CallHistorySiteName: string; override;
   end;

(* THE ARRL SECTION OF A PA COUNTY KEY of pa_cty.dom -- 'EPA' or 'WPA', in
   any case and trimmed; '' for anything that is no PA county (a section, a
   state, DX). Public so the tests assert the crosswalk itself. *)
function PennsylvaniaSectionOfCounty(const aCountyKey: string): string;

implementation

uses
   uSettingsModel,        (* cpQRP *)
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   SysUtils,
   uADIF,                 (* IsADIFPrimarySubdivision *)
   uARRLSections,         (* StateFromARRLSection, IsADIFARRLSection *)
   uContestRegistry;

function TContestPennsylvaniaQP.GetDisplayName: string;
begin
   Result := 'Pennsylvania QSO Party';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-16). CSV
   row PA QSO PARTY: status verified; rules https://paqso.org/; rules year
   2027. *)
function TContestPennsylvaniaQP.GetSchedule: string;
begin
   Result := '2nd full weekend of October at 16:00 UTC for 12h; ' +
             '2nd full weekend of October +1d at 13:00 UTC for 9h';
end;

function TContestPennsylvaniaQP.GetHostState: string;
begin
   Result := 'PA';
end;

function TContestPennsylvaniaQP.GetCabrilloName: string;
begin
   Result := 'PA-QSO-PARTY';
end;

function TContestPennsylvaniaQP.GetADIFContestId: string;
begin
   Result := 'PA-QSO-PARTY';
end;

function TContestPennsylvaniaQP.GetWA7BNMId: integer;
begin
   Result := 153;
end;

function TContestPennsylvaniaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestPennsylvaniaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestPennsylvaniaQP.GetDomesticFileName: string;
begin
   Result := 'pa_cty';
end;

function TContestPennsylvaniaQP.GetFriendlyName: string;
begin
   Result := 'Pennsylvania QSO Party';
end;

function TContestPennsylvaniaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestPennsylvaniaQP.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticQTHExchange;
end;

function TContestPennsylvaniaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberQTH;
end;

function TContestPennsylvaniaQP.ParseReceivedExchangeFormat(const aText: string;
                                                            aParsers: TExchangeParsers;
                                                            var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseQSONumberDomesticQTH(aText, aExch);
end;

function TContestPennsylvaniaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestPennsylvaniaQP.PerQSOExchangeLeadsWithSerial: boolean;
begin
   Result := True;
end;

function TContestPennsylvaniaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange): string;
begin
   (* "Sequential serial number plus PA county, ARRL section, Canadian
      section, or DX" (rule 5.a): a DX entrant with no MY STATE sends DX.
      The field order is the class's long-standing one (state first), kept. *)
   Result := Format('%-4s %-6d', [Copy(SentStateOrDX(aMy), 1, 20), aQso.NumberSent]);
end;

function TContestPennsylvaniaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4d %-6s', [aQso.NumberSent, SentStateOrDX(aMy)]);
end;

function TContestPennsylvaniaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                            const aQso: ContestExchange;
                                                            const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedQSONumberQTH(aMy, aQso, aCtx);
end;

function TContestPennsylvaniaQP.GetInStateDomesticFileName: string;
begin
   Result := 'pa';
end;

function TContestPennsylvaniaQP.GetFlags: TContestFlags;
begin
   (* Dupes once per band and mode (rule 5.d); multipliers once, "not once
      per band" (10.a, 10.b), so no cfMultByBand. VHF bands are credited
      (rule 3.a), so cfVHFBandsEnabled lets 6 m and up be reached. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

(* PAQSOPointMethod -- `if Mode = PHONE then 1 else 2`.

   THE INVERTED SHAPE, AND THE THIRD ARGUMENT IS WHERE IT SHOWS. The test is
   PHONE-versus-not, so DIGITAL takes the CW value of 2, not the phone value of
   1. Most of the state parties test CW-versus-not and their digital number is
   the phone one; writing 1 here would reproduce the phone and CW arms
   perfectly and be silently wrong about every digital QSO. *)
procedure TContestPennsylvaniaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   (* RULES 6.a and 6.c (2026-11-20): CW 2, Phone 1 -- "SSB, FM, AM, etc.".
      The legacy arm gave every non-phone mode 2 (FM and digital too); a
      digital QSO is now off-mode (UsesMode) and never reaches here. *)
   case aQso.Mode of
      CW:
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

(* RULE 3: "all ham band allocations authorized ... except the WARC bands
   (12m, 17m, 30m, or 60m)". 160 m through 24 GHz are credited; BandLight is
   no amateur allocation. *)
function TContestPennsylvaniaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := (aBand in [Band160..Band24G]) and
             not (aBand in [Band30, Band17, Band12]);
end;

(* RULES 6.a and 6.c: CW and Phone (SSB, FM, AM, any voice mode) only. The
   2019 change log removed digital modes and the current rules name none, so
   a digital QSO is an automatic X-QSO (Q98). *)
function TContestPennsylvaniaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

(* RULE 10.d: "QRP Operation Multiplier: Multiply QSO Points times 2", for a
   QRP entry. The entrant's CATEGORY-POWER is Station.MyPower. *)
function TContestPennsylvaniaQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals);
   if Station.MyPower = cpQRP then
      begin
      Result := Result * 2;
      end;
end;

(* A BONUS QSO MUST BE A VALID ONE. *)
function TContestPennsylvaniaQP.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := IsCreditedContact(aQso);
end;

const
   (* RULE 11.d, rules year 2026: the Bonus Station is K3ZMC (the Pottstown
      Area Amateur Radio Club); 11.c: "Valid QSOs with the bonus station are
      worth 200 points". The sponsor names a new one each year (11.a), so
      the pay-out is for the 2026 log year only. *)
   PABonusStationYear = 2026;
   PABonusStationCall = 'K3ZMC';
   PABonusStationPoints = 200;

(* 200 points for each band-and-mode QSO with the bonus station (rule 5.d's
   dupe unit; the rules do not say per QSO or per band and mode, so the
   dupe unit is taken). Added after the multipliers (10.c). *)
function TContestPennsylvaniaQP.BonusPoints(const aTotals: TScoreTotals;
                                            aView: TLoggedQSOView): longint;
begin
   Result := inherited BonusPoints(aTotals, aView);
   if LogContestYear(aTotals, aView) = PABonusStationYear then
      begin
      Result := Result + PABonusStationPoints *
                BonusStationBandModesWorked(aView, PABonusStationCall);
      end;
end;

(* A SECTION IS NO COUNTY. The base takes any resolved key longer than two
   letters for a county; the in-state file also holds ARRL and Canadian
   sections (NTX, ONS ...), which are no PA county, so their STATE is not PA. *)
function TContestPennsylvaniaQP.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
begin
   Result := inherited ADIFCountyState(aQso);
   key := Trim(string(aQso.DomesticQTH));
   if key = '' then
      begin
      key := Trim(string(aQso.QTHString));
      end;
   if (Result <> '') and IsADIFARRLSection(key) then
      begin
      Result := '';
      end;
end;

(* A WORKED SECTION'S STATE, when it has exactly one (NTX gives TX). *)
function TContestPennsylvaniaQP.ADIFWorkedStationState(const aQso: ContestExchange): string;
begin
   Result := inherited ADIFWorkedStationState(aQso);
   if Result = '' then
      begin
      Result := StateFromARRLSection(Trim(string(aQso.DomesticQTH)));
      if Result = '' then
         begin
         Result := StateFromARRLSection(Trim(string(aQso.QTHString)));
         end;
      (* Only a subdivision of the worked station's own DXCC, as the base asks. *)
      if (Result <> '') and
         not IsADIFPrimarySubdivision(string(aQso.QTH.CountryID), Result) then
         begin
         Result := '';
         end;
      end;
end;

type
   TPennsylvaniaCountySection = record
      Key: string[3];
      Section: string[3];
   end;

const
   (* GENERATED FROM tr4w/tools/trmaster/arrl-sections-counties.json -- see
      the header. One row per pa_cty.dom key, in its order. NHA is the file's
      "Northhampton", the JSON's Northampton. *)
   PA_COUNTY_SECTIONS: array[0..66] of TPennsylvaniaCountySection = (
      (Key: 'ADA'; Section: 'EPA'),   (* Adams *)
      (Key: 'ALL'; Section: 'WPA'),   (* Allegheny *)
      (Key: 'ARM'; Section: 'WPA'),   (* Armstrong *)
      (Key: 'BEA'; Section: 'WPA'),   (* Beaver *)
      (Key: 'BED'; Section: 'WPA'),   (* Bedford *)
      (Key: 'BER'; Section: 'EPA'),   (* Berks *)
      (Key: 'BLA'; Section: 'WPA'),   (* Blair *)
      (Key: 'BRA'; Section: 'EPA'),   (* Bradford *)
      (Key: 'BUT'; Section: 'WPA'),   (* Butler *)
      (Key: 'BUX'; Section: 'EPA'),   (* Bucks *)
      (Key: 'CAR'; Section: 'EPA'),   (* Carbon *)
      (Key: 'CEN'; Section: 'WPA'),   (* Centre *)
      (Key: 'CHE'; Section: 'EPA'),   (* Chester *)
      (Key: 'CLA'; Section: 'WPA'),   (* Clarion *)
      (Key: 'CLE'; Section: 'WPA'),   (* Clearfield *)
      (Key: 'CLI'; Section: 'WPA'),   (* Clinton *)
      (Key: 'CMB'; Section: 'WPA'),   (* Cambria *)
      (Key: 'COL'; Section: 'EPA'),   (* Columbia *)
      (Key: 'CRA'; Section: 'WPA'),   (* Crawford *)
      (Key: 'CRN'; Section: 'WPA'),   (* Cameron *)
      (Key: 'CUM'; Section: 'EPA'),   (* Cumberland *)
      (Key: 'DAU'; Section: 'EPA'),   (* Dauphin *)
      (Key: 'DCO'; Section: 'EPA'),   (* Delaware *)
      (Key: 'ELK'; Section: 'WPA'),   (* Elk *)
      (Key: 'ERI'; Section: 'WPA'),   (* Erie *)
      (Key: 'FAY'; Section: 'WPA'),   (* Fayette *)
      (Key: 'FOR'; Section: 'WPA'),   (* Forest *)
      (Key: 'FRA'; Section: 'WPA'),   (* Franklin *)
      (Key: 'FUL'; Section: 'WPA'),   (* Fulton *)
      (Key: 'GRE'; Section: 'WPA'),   (* Greene *)
      (Key: 'HUN'; Section: 'WPA'),   (* Huntingdon *)
      (Key: 'INN'; Section: 'WPA'),   (* Indiana *)
      (Key: 'JEF'; Section: 'WPA'),   (* Jefferson *)
      (Key: 'JUN'; Section: 'EPA'),   (* Juniata *)
      (Key: 'LAC'; Section: 'EPA'),   (* Lackawanna *)
      (Key: 'LAN'; Section: 'EPA'),   (* Lancaster *)
      (Key: 'LAW'; Section: 'WPA'),   (* Lawrence *)
      (Key: 'LEB'; Section: 'EPA'),   (* Lebanon *)
      (Key: 'LEH'; Section: 'EPA'),   (* Lehigh *)
      (Key: 'LUZ'; Section: 'EPA'),   (* Luzerne *)
      (Key: 'LYC'; Section: 'EPA'),   (* Lycoming *)
      (Key: 'MCK'; Section: 'WPA'),   (* McKean *)
      (Key: 'MER'; Section: 'WPA'),   (* Mercer *)
      (Key: 'MGY'; Section: 'EPA'),   (* Montgomery *)
      (Key: 'MIF'; Section: 'WPA'),   (* Mifflin *)
      (Key: 'MOE'; Section: 'EPA'),   (* Monroe *)
      (Key: 'MTR'; Section: 'EPA'),   (* Montour *)
      (Key: 'NHA'; Section: 'EPA'),   (* Northampton *)
      (Key: 'NUM'; Section: 'EPA'),   (* Northumberland *)
      (Key: 'PER'; Section: 'EPA'),   (* Perry *)
      (Key: 'PHI'; Section: 'EPA'),   (* Philadelphia *)
      (Key: 'PIK'; Section: 'EPA'),   (* Pike *)
      (Key: 'POT'; Section: 'WPA'),   (* Potter *)
      (Key: 'SCH'; Section: 'EPA'),   (* Schuylkill *)
      (Key: 'SNY'; Section: 'EPA'),   (* Snyder *)
      (Key: 'SOM'; Section: 'WPA'),   (* Somerset *)
      (Key: 'SUL'; Section: 'EPA'),   (* Sullivan *)
      (Key: 'SUS'; Section: 'EPA'),   (* Susquehanna *)
      (Key: 'TIO'; Section: 'EPA'),   (* Tioga *)
      (Key: 'UNI'; Section: 'EPA'),   (* Union *)
      (Key: 'VEN'; Section: 'WPA'),   (* Venango *)
      (Key: 'WAR'; Section: 'WPA'),   (* Warren *)
      (Key: 'WAS'; Section: 'WPA'),   (* Washington *)
      (Key: 'WAY'; Section: 'EPA'),   (* Wayne *)
      (Key: 'WES'; Section: 'WPA'),   (* Westmoreland *)
      (Key: 'WYO'; Section: 'EPA'),   (* Wyoming *)
      (Key: 'YOR'; Section: 'EPA')    (* York *)
      );

function PennsylvaniaSectionOfCounty(const aCountyKey: string): string;
var
   key: string;
   i: integer;
begin
   Result := '';
   key := UpperCase(Trim(aCountyKey));
   for i := Low(PA_COUNTY_SECTIONS) to High(PA_COUNTY_SECTIONS) do
      begin
      if key = string(PA_COUNTY_SECTIONS[i].Key) then
         begin
         Result := string(PA_COUNTY_SECTIONS[i].Section);
         Exit;
         end;
      end;
end;

(* THE SECTION AS A SECOND DOMESTIC KEY -- the header.

   NOT InStateCountyEarnsHostState: that helper relies on "every key longer
   than two letters is a host county", which is false here -- pa.dom includes
   arrlsect.dom, so NTX and ONS are three-letter keys the table knows. The
   crosswalk is the county test: only a PA county key has a section. The key
   read is the sheet's own (DomMultQTH, else DomesticQTH), as the helper's. *)
function TContestPennsylvaniaQP.AdditionalDomesticMultiplierKey(const aQso: ContestExchange;
                                                                out aKey: string): boolean;
var
   county: string;
begin
   aKey := '';
   Result := False;
   if not Station.InHostState then
      begin
      Exit;
      end;

   county := Trim(string(aQso.DomMultQTH));
   if county = '' then
      begin
      county := Trim(string(aQso.DomesticQTH));
      end;

   aKey := PennsylvaniaSectionOfCounty(county);
   Result := aKey <> '';
end;

(* OUTSIDE PA THE ROW TAKES AN ARRL OR RAC SECTION -- the header. EPA and WPA
   are inside the area: the base's HostStates list carries them so the
   dialog refuses them as "inside" (they would name a PA station). *)
function TContestPennsylvaniaQP.DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean;
begin
   Result := inherited DescribeNewContestHostArea(aArea);
   if Result then
      begin
      aArea.HostStates := HostState + ' EPA WPA';
      aArea.OutsideTakesSection := True;
      end;
end;

function TContestPennsylvaniaQP.CallHistoryFields: TCallHistoryFields;
begin
   Result := CallHistoryFieldList([chfExch1]);
end;

function TContestPennsylvaniaQP.CallHistorySiteName: string;
begin
   Result := 'QSOP_PA';
end;

initialization
   RegisterContest(PAQSOPARTY, TContestPennsylvaniaQP);

end.
