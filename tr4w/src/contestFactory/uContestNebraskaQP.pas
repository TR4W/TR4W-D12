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

(* NEBRASKA QSO PARTY -- a NEW ContestType, NEBRASKAQSO (2026-10-16).

  NY4I, design Q105: "It will have a NE qso party as I do want to implement
  all qso parties eventually." TR4W had none. Its names are NE-QSO-PARTY
  everywhere -- ContestTypeSA, Cabrillo and ADIF 3.1.7 alike -- and it is
  NOT 'NEQP': that spelling is the NEW ENGLAND QSO Party's, stored in every
  older New England log, and stays a read alias for it for good
  (uContestNames). DXLog's NEQP.txt IS Nebraska despite its name; its New
  England file is NEWEQP.txt.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and an out-of-state station may work
  only Nebraska stations -- the base's out-of-state refusal (design 7.10).
  Modelled on uContestDelawareQP, the nearest party (a power multiplier, a
  per-contest bonus); a copy it owns, not a shared base (design 1.4).

  ---------------------------------------------------------------------------
  SOURCES -- the sponsor wins where DXLog differs

    the sponsor     https://nebraskaqsoparty.com -- "Rules for 2026 Nebraska
                    QSO Party", as summarised by NY4I's coordinator,
                    2026-10-16 (the page renders its rules client-side and
                    was not re-read here)
    WA7BNM          ref 336: 1300Z Apr 25 to 0100Z Apr 27, 2026
    DXLog.net       Contest\NEQP.txt (updated 2026-06-04): the 93 county
                    abbreviations, the bonus calls, NF/LB written as NL
    ADIF 3.1.7      Contest_ID NE-QSO-PARTY

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- Saturday 25 April 2026, 1400 UTC, to Monday 27 April, 0200 UTC:
    the sponsor's UTC figures (NY4I, 2026-10-18, Q106: "Go with the
    sponsor's doc"; "utc is the gospel, not the rules author's mistaken
    conversion"). The sponsor's CDT times disagree by an hour, and WA7BNM
    follows the CDT times with 1300Z-0100Z; the stated UTC wins. Contest
    schedules are not built yet (design Q99); recorded only.

  MODES -- CW; phone (SSB, AM, FM); digital (RTTY, PSK and other digital
    modes) but NOT FT8 or FT4: "FT8/FT4 is a SEPARATE competition with a
    separate log". UsesMode credits CW, phone, FM and every digital submode
    but FT8 and FT4 (its ExtMode), so an FT8 or FT4 QSO is logged and is an
    automatic X-QSO (Q98, QSOIsXQSO): 0 points, no multiplier, no dupe, no
    bonus. CalculateQSOPoints and the multiplier sheet never see one.

  BANDS -- "160, 80, 40, 20, 15, 10 m; WARC contacts do not count; all
    VHF/UHF bands are allowed". UsesBand: those six and every band from 6 m
    up, light included; VHFBandsEnabled. DXLog lists only 50 MHz above 10 m;
    the sponsor wins. 60 m has no BandType.

  EXCHANGE -- out-of-state stations send their state, Canadian province or
    "DX"; Nebraska stations send their county (four-letter abbreviation).
    Signal report optional. RSTDomesticOrDXQTHExchange, as Delaware: the
    shape takes a county, state or province through the session's domestic
    table and a DX QTH otherwise; for an out-of-state entrant that table is
    the 93 counties, so the base's refusal does the rest.

  QSO POINTS -- digital 1, phone 2, CW 3 (FM is phone). Satellite QSOs are
    4 points, but TR4W has no notion of a satellite QSO -- NOT BUILT (Q106).

  DUPES -- "the same station counts again on another band, or another mode
    on the same band": QSOByBand and QSOByMode. "A mobile in a new county is
    a new station" is a dupe-KEY rule and there is no dupe-key seam (M8,
    design 8.2l) -- the same gap as Delaware's (design Q73).

  MULTIPLIERS -- counted ONCE PER CONTEST, not per band or mode (no
    MultByBand, no MultByMode).
      out of state  nebraska_cty.dom: the 93 counties, each its own
                    multiplier (FCONTEST sets MultipliersIsCounties). No DX
                    multiplier: such an entrant works only Nebraska.
      in state      nebraska.dom: the counties (each its OWN multiplier --
                    the county file maps none of them to Ne), the 50 states
                    (S50) and the 13 provinces (P13, NF and LB read as NL),
                    and DXCC entities but the USA, Canada, Alaska and Hawaii
                    as the DX multiplier (Alaska and Hawaii are states in
                    S50). OPEN: whether a Nebraska entrant's NE counts as a
                    STATE as well as its counties -- a QSO carries one
                    domestic multiplier, and a Nebraska station sends its
                    county, so S50's Ne is never reached. DXLog instead maps
                    every county to Nebraska; the sponsor's "NE counties +
                    US states" is what is built.

  POWER -- ONE multiplier on the whole score: every QSO at 5 W or less x5,
    under 100 W x2, otherwise x1. CATEGORY-POWER is the one value (design
    7.6), Station.MyPower: QRP x5, LOW x2, HIGH x1 -- CombineWithMultipliers,
    as Delaware's. LOW is "100 W or less" in Cabrillo, the sponsor's x2 is
    "under 100 W": exactly 100 W cannot be told apart, and scores x2. DXLog
    applies power per QSO; the sponsor's one multiplier is what is built.

  SCORE -- QSO points x power multiplier x multipliers, + bonus points.

  BONUS -- 100 points for a QSO with KA0BOJ (the sponsor writes it with a slashed zero), 50
    for a QSO with each of K0SMM, K0RPT, K0NEB, NF0N, N0FER and KE0XQ, PER
    QSO: every QSO with one of them that counts -- not a dupe, on a credited
    band, not FT8/FT4 -- pays. That is DXLog's per-band-and-mode count, since
    the dupe rule allows one QSO per band and mode. NEBRASKA_BONUS_STATIONS
    below; THE LIST CHANGES EVERY YEAR.

  COUNTY LINES AND MOBILES -- mobiles sign call/county; a county line is
    limited to TWO counties: GetCountyLineCountiesMax = 2. The rover strip
    and its ADIF split are the base's, as for every QSO party.

  MULTI-TRANSMITTER -- one combined log; nothing for TR4W to do.

  RARE GRID BONUS -- Q106(1), NY4I 2026-10-18: "yes to rare grid". The
    sponsor's 2026 text: "For the following grid squares (DN91CE, DN91DE,
    DN91EE) if you activate in them you will receive a bonus of 5 points per
    QSO. Example if you make a phone QSO that is 2 points and a CW QSO that
    is 3 points for a total of 5 points. Then you take your total score from
    the unique grid only QSO's. Take that total and in this example 5 points
    times the rare grid multiplier of 5 for a bonus of 25 points. (No mobile
    multiplier of 3 in the RARE GRID BONUS)". So the bonus is 5 x the QSO
    POINTS of the QSOs made FROM a rare subsquare, added BESIDE the other
    bonus points -- "(QSO Points x Power Multiplier x Geo Multiplier) plus
    Bonus points" -- so neither the power nor the county multiplier touches
    it. PER QSO: a rover pays only for the QSOs it made there.
      ASSUMPTION (recorded in Q106): the sentence "5 points per QSO"
      contradicts the sponsor's own example and its 2025 summary-sheet
      worksheet ("CW 3 points per QSO x 5 (Rare points multiplier)"); the
      example and the worksheet are what is built.
      "Unique" is read as a QSO that counts: not a dupe, on a credited band,
      not FT8/FT4 -- the station bonus's rule. The points are the QSO's
      SCORED points (QSOPoints), before the power multiplier, so a QSO the
      score does not count (a host-area refusal, an override of 0) pays
      nothing here either.
      WHOSE GRID: OURS, AS RECORDED FOR THAT QSO -- TLoggedQSOView.MyFacts
      (log schema 3), never today's setting; a row written before schema 3
      ("not captured") reads the session's grid (ruling A); a captured row
      with no grid is unknown and pays nothing. The first SIX characters,
      case-blind: the rule names subsquares, so a four-character DN91 is not
      a rare grid. The three 2026 subsquares lie in Keith County, Nebraska,
      so only a Nebraska station can earn it and no in-state test is needed.
      THE LIST CHANGES BY YEAR, so it is a table per contest year, chosen
      through uContestBase.LogContestYear as Idaho's (Q35): 2026 is the three
      above; 2025 is the 2025 summary sheet's EN01MI, EN01NI, EN01MH and
      EN01NH. That sheet also prints "Phone 1 points per QSO" -- the 2026
      rules say 2; NOTED, NOT BUILT (a 2025 log scores 2026 points). A year
      with no table pays no rare-grid bonus and logs ONE Error naming it.
      Also on the 2025 sheet and in no 2026 rule: "Mobile x 3", "NE0QP Bonus
      100" and "Mobile Bonus 100" -- not built (Q106).

  NOT BUILT (open question Q106): satellite points (NY4I, 2026-10-18:
    "leave satellite alone"), and the separate FT8/FT4 grid-square
    competition.

  CABRILLO -- CONTEST: NE-QSO-PARTY, the sponsor's and DXLog's. The QSO line
    is RST and the sent state or county, RST and the received QTH or DX, as
    DXLog writes it ("RST is optional but N1MM includes it so we do too").
    The mode column is the base's. ADIF -- CONTEST_ID NE-QSO-PARTY; export
    and import are the base's. *)
unit uContestNebraskaQP;

{$I tr4w.inc}

interface

uses
   (* cpLOW / cpQRP -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestNebraskaQP = class(TContestStateQSOPartyBase)
   private
      (* THE RARE GRID BONUS -- the header. *)
      function RareGridBonus(const aTotals: TScoreTotals;
                             aView: TLoggedQSOView): longint;
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

      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x THE POWER MULTIPLIER x MULTIPLIERS -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* 160-10 m without WARC, and 6 m up -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* CW, phone, FM and digital but FT8/FT4 -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;

      (* ' 5NN ' and the state or county this station sends. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* THE BONUS STATIONS, per QSO, and the rare grid bonus -- the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;

      (* DOES aYear HAVE A RARE-GRID TABLE? The yearly pin test asks it of the
         current year, so the first run of a new year fails until the
         sponsor's list for it is added. *)
      class function HasRareGridTable(aYear: integer): boolean;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the one station test
         HasDXMultiplier, the key and the country list ask, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

const
   (* THE 2026 BONUS STATIONS -- THE SPONSOR CHANGES THIS LIST EVERY YEAR.
      TBonusStation's shape, but NOT declared through GetBonusStations: the
      base pays a declared station once, once per mode or once per band and
      mode (TBonusStationScope), and Nebraska pays every counting QSO --
      BonusPoints walks this list itself, so Scope is not read here.
      The sponsor writes KA0BOJ with a slashed zero; the call is KA0BOJ. *)
   NEBRASKA_BONUS_STATIONS: array[0..6] of TBonusStation = (
      (Call: 'KA0BOJ'; Points: 100; Scope: bsOnce),
      (Call: 'K0SMM';  Points: 50; Scope: bsOnce),
      (Call: 'K0RPT';  Points: 50; Scope: bsOnce),
      (Call: 'K0NEB';  Points: 50; Scope: bsOnce),
      (Call: 'NF0N';   Points: 50; Scope: bsOnce),
      (Call: 'N0FER';  Points: 50; Scope: bsOnce),
      (Call: 'KE0XQ';  Points: 50; Scope: bsOnce)
   );

   (* "5 points times the rare grid multiplier of 5" -- the header. *)
   NEBRASKA_RARE_GRID_MULTIPLIER = 5;

(* IS aGrid ONE OF aYear's RARE SUBSQUARES? False when aYear has no table
   (aRare False); True with aRare saying whether the grid's first six
   characters, case-blind, are on that year's list. Shorter than six is never
   rare. Public so the tests assert the table itself. *)
function NebraskaRareGrid(aYear: integer; const aGrid: string;
                          out aRare: boolean): boolean;

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER -- HIGH x1, LOW x2, QRP x5.
   Public so the tests assert the mapping itself, not only a product. *)
function NebraskaPowerMultiplier(aPower: tCategoryPower): longint;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* TQsoMyFacts -- each QSO's recorded station, for the rare grid. *)
   uQsoMyFacts,
   (* The "no rare-grid table for this year" Error. *)
   Log4D,
   SysUtils, uContestRegistry;

const
   (* THE 2026 CONTEST'S RARE SUBSQUARES -- the sponsor's "Rules for 2026
      Nebraska QSO Party". A NEW YEAR IS A NEW TABLE BESIDE THESE and one arm
      in NebraskaRareGrid -- never an edit to one of them, which a log of
      that year reopened later must still be paid from. *)
   NebraskaRareGrids2026: array[0..2] of string = ('DN91CE', 'DN91DE', 'DN91EE');

   (* THE 2025 CONTEST'S -- the sponsor's "Nebraska QSO Party SummarySheet
      2025.pdf", its Rare Grid Worksheet. *)
   NebraskaRareGrids2025: array[0..3] of string = ('EN01MI', 'EN01NI', 'EN01MH', 'EN01NH');

var
   logger: TLogLogger;

(* Is aSubsquare (already six upper-case characters) in aTable? *)
function GridInTable(const aTable: array of string; const aSubsquare: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aTable) to High(aTable) do
      begin
      if aTable[i] = aSubsquare then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE YEARS THAT HAVE A TABLE -- the one place a contest year is added. *)
function NebraskaRareGrid(aYear: integer; const aGrid: string;
                          out aRare: boolean): boolean;
var
   subsquare: string;
begin
   aRare := False;
   subsquare := UpperCase(Trim(aGrid));
   if Length(subsquare) < 6 then
      begin
      subsquare := '';
      end
   else
      begin
      subsquare := Copy(subsquare, 1, 6);
      end;

   case aYear of
      2025:
         begin
         aRare := (subsquare <> '') and GridInTable(NebraskaRareGrids2025, subsquare);
         Result := True;
         end;
      2026:
         begin
         aRare := (subsquare <> '') and GridInTable(NebraskaRareGrids2026, subsquare);
         Result := True;
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function NebraskaPowerMultiplier(aPower: tCategoryPower): longint;
begin
   case aPower of
      cpLOW:
         begin
         Result := 2;
         end;
      cpQRP:
         begin
         Result := 5;
         end;
      else
         begin
         Result := 1;
         end;
      end;
end;

function TContestNebraskaQP.GetDisplayName: string;
begin
   Result := 'Nebraska QSO Party';
end;

function TContestNebraskaQP.GetHostState: string;
begin
   Result := 'NE';
end;

function TContestNebraskaQP.GetCabrilloName: string;
begin
   Result := 'NE-QSO-PARTY';
end;

function TContestNebraskaQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration. NOT 'NEQP' -- New England's. *)
   Result := 'NE-QSO-PARTY';
end;

function TContestNebraskaQP.GetWA7BNMId: integer;
begin
   Result := 336;
end;

function TContestNebraskaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNebraskaQP.GetSubmissionEmail: string;
begin
   Result := 'nebraskaqsoparty@gmail.com';
end;

function TContestNebraskaQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Nebraska county, and then loads nebraska.dom or
      this file. *)
   Result := 'nebraska_cty';
end;

function TContestNebraskaQP.GetFriendlyName: string;
begin
   Result := 'Nebraska QSO Party';
end;

function TContestNebraskaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNebraskaQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNebraskaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestNebraskaQP.ParseReceivedExchangeFormat(const aText: string;
                                                        aParsers: TExchangeParsers;
                                                        var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

function TContestNebraskaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestNebraskaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTState(aMy, aQso);
end;

function TContestNebraskaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTState(aMy, aQso, aCtx);
end;

function TContestNebraskaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
end;

function TContestNebraskaQP.GetInStateDomesticFileName: string;
begin
   Result := 'nebraska';
end;

function TContestNebraskaQP.GetFlags: TContestFlags;
begin
   (* Dupes per band and per mode; multipliers ONCE PER CONTEST (neither
      cfMultByBand nor cfMultByMode); 6 m and up are credited. *)
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

function TContestNebraskaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* DIGITAL 1, PHONE 2, CW 3. FM is phone. An FT8 or FT4 QSO never reaches
   here (UsesMode), nor an off-band one (UsesBand); Both and NoMode are not
   modes a contact is made in. *)
procedure TContestNebraskaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 3;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      Digital:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestNebraskaQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals) *
             NebraskaPowerMultiplier(Station.MyPower);
end;

function TContestNebraskaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

(* "FT8/FT4 is a SEPARATE competition with a separate log": every other
   digital submode is credited, eNoMode and eData included ("some submode of
   Digital", the contract); CW, phone and FM are. An identity fact: no
   station is asked. *)
function TContestNebraskaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := not (aExtMode in [eFT8, eFT4]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

function TContestNebraskaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Nebraska station's county, anyone else's state or province. *)
   Result := ' 5NN ' + aStation.MyState;
end;

(* EVERY COUNTING QSO WITH A BONUS STATION PAYS -- not a dupe, on a band the
   contest credits, not FT8/FT4. Decided from the whole log, never as a QSO
   is logged (design 7.7). Then the rare grid bonus, beside it. *)
function TContestNebraskaQP.BonusPoints(const aTotals: TScoreTotals;
                                        aView: TLoggedQSOView): longint;
var
   i, s: integer;
   qso: ContestExchange;
begin
   Result := inherited BonusPoints(aTotals, aView);
   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if qso.ceDupe                                              or
         (not ContestCreditsMode(Self, qso.Mode, qso.ExtMode)) or
         (not ContestCreditsBand(Self, qso.Band))               then
         begin
         Continue;
         end;
      for s := Low(NEBRASKA_BONUS_STATIONS) to High(NEBRASKA_BONUS_STATIONS) do
         begin
         if string(qso.Callsign) = NEBRASKA_BONUS_STATIONS[s].Call then
            begin
            Result := Result + NEBRASKA_BONUS_STATIONS[s].Points;
            Break;
            end;
         end;
      end;

   Result := Result + RareGridBonus(aTotals, aView);
end;

(* 5 x THE SCORED POINTS OF EVERY COUNTING QSO MADE FROM A RARE SUBSQUARE --
   the header. The year is asked only once a QSO counts, so a log still being
   started (no QSO, no year yet) is not reported as missing a table. *)
function TContestNebraskaQP.RareGridBonus(const aTotals: TScoreTotals;
                                          aView: TLoggedQSOView): longint;
var
   i: integer;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   grid: string;
   year: integer;
   yearKnown: boolean;
   rare: boolean;
   rarePoints: longint;
begin
   Result := 0;
   rarePoints := 0;
   year := 0;
   yearKnown := False;

   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if qso.ceDupe                                              or
         (not ContestCreditsMode(Self, qso.Mode, qso.ExtMode)) or
         (not ContestCreditsBand(Self, qso.Band))               or
         (qso.QSOPoints <= 0)                                   then
         begin
         Continue;
         end;

      if not yearKnown then
         begin
         year := LogContestYear(aTotals, aView);
         if not HasRareGridTable(year) then
            begin
            (* The party base's once-per-year Error (lifted 2026-10-26). *)
            ReportNoTableForYear(logger, year, 'rare-grid list',
                                 'the rare grid bonus', 'nebraskaqsoparty.com');
            Exit;
            end;
         yearKnown := True;
         end;

      (* OUR GRID FOR THIS QSO: the row's, else -- never captured -- the
         session's (ruling A). A captured empty grid stays empty. *)
      facts := aView.MyFacts(i);
      if facts.Source = mfsNotCaptured then
         begin
         grid := Station.MyGrid;
         end
      else
         begin
         grid := string(facts.Grid);
         end;

      if NebraskaRareGrid(year, grid, rare) and rare then
         begin
         rarePoints := rarePoints + qso.QSOPoints;
         end;
      end;

   Result := rarePoints * NEBRASKA_RARE_GRID_MULTIPLIER;
end;

class function TContestNebraskaQP.HasRareGridTable(aYear: integer): boolean;
var
   rare: boolean;
begin
   Result := NebraskaRareGrid(aYear, '', rare);
end;

(* THE STATION TEST -- a Nebraska entrant counts DXCC entities. *)
function TContestNebraskaQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* Yes inside Nebraska; none outside, where an entrant works only Nebraska
   stations. *)
function TContestNebraskaQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* Every country but the USA, Canada, Hawaii and Alaska (those are states
   and provinces here), for a Nebraska entrant; none for anyone else. *)
function TContestNebraskaQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* DXCC where the entrant counts the DX multiplier; the CQ list for anyone
   else, who counts none. *)
function TContestNebraskaQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;

initialization
   logger := TLogLogger.GetLogger('uContestNebraskaQP');
   RegisterContest(NEBRASKAQSO, TContestNebraskaQP);

end.
