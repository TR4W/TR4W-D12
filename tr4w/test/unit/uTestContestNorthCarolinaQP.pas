(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* THE NORTH CAROLINA QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  NorthCarolina/NC-QSO-PARTY-Rules.txt; the test quotes the rule it holds.

  An NC entrant's multipliers are DATA, in nc.dom, read here through the
  real loader with its INCLUDEs. Until #88 round 3 that file wrote INCLUDE
  without FILE, which the loader skipped, so no US state and no province
  of P13 was a multiplier -- the frozen matrix showed "CT not in nc.dom". *)
unit uTestContestNorthCarolinaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNorthCarolinaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
      procedure Test_NCBands;
      procedure Test_NCModes;
      procedure Test_NCFMIsPhone;
      procedure Test_NCSweepNeedsCreditedQSOs;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects,
   uTestQSOPartyRules;

function NCQso(const aCall, aQTH: string; aBand: BandType; aMode: ModeType;
               aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := CallString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := aQTH;
   Result.DomesticQTH := aQTH;
   Result.DomMultQTH := aQTH;
end;

(* What ScoreQSO gives an NC entrant -- the one public scoring entry, so an
   off-band or off-mode QSO scores 0 before CalculateQSOPoints is asked. *)
function NCPoints(const aQTH: string; aBand: BandType; aMode: ModeType;
                  aExtMode: ExtendedModeType): integer;
var
   station: TStationContext;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   contestObject := Make(NCQSOPARTY, station);
   try
      qso := NCQso('K4ABC', aQTH, aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "NC participants: Work 100 North Carolina Counties, 49 US States (not NC)
   plus DC, 13 Canadian Provinces/Territories (AB, BC, MB, NB, NL, NS, NT, NU,
   ON, PE, QC, SK, and YT), plus one DX." *)
procedure TContestNorthCarolinaQPTests.Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
const
   PROVINCES: array[0..12] of string =
      ('AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');
var
   i: integer;
begin
   BeginTest('Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX');
   CheckEquals('nc', ContestIdentity(NCQSOPARTY).InStateDomesticFileName, 'nc.dom is the in-state file');

   (* "49 US States (not NC)" *)
   CheckEquals('CT', InStateMultiplierOf(NCQSOPARTY, 'CT'), 'Connecticut is a multiplier');
   CheckEquals('GA', InStateMultiplierOf(NCQSOPARTY, 'GA'), 'Georgia is a multiplier');
   CheckEquals('AK', InStateMultiplierOf(NCQSOPARTY, 'AK'), 'Alaska is');
   CheckEquals('HI', InStateMultiplierOf(NCQSOPARTY, 'HI'), 'Hawaii is');
   CheckEquals('LA', InStateMultiplierOf(NCQSOPARTY, 'LA'), 'LA is Louisiana, not Labrador');
   CheckEquals('', InStateMultiplierOf(NCQSOPARTY, 'NC'), 'North Carolina is NOT a multiplier');

   (* "plus DC" -- its own, not Maryland. *)
   CheckEquals('DC', InStateMultiplierOf(NCQSOPARTY, 'DC'), 'DC is its own multiplier');
   CheckEquals('MD', InStateMultiplierOf(NCQSOPARTY, 'MD'), 'and Maryland is Maryland');

   (* THE 13, EACH ITS OWN -- the old file merged NS, NB and PE into one and
      had no NU. *)
   for i := Low(PROVINCES) to High(PROVINCES) do
      begin
      CheckEquals(PROVINCES[i], InStateMultiplierOf(NCQSOPARTY, PROVINCES[i]),
                  PROVINCES[i] + ' is its own multiplier');
      end;
   CheckEquals('NL', InStateMultiplierOf(NCQSOPARTY, 'NF'), 'the old NF still means Newfoundland and Labrador');

   (* "plus one DX" and the 100 counties. *)
   CheckEquals('DX', InStateMultiplierOf(NCQSOPARTY, 'DX'), 'all DX is one multiplier');
   CheckEquals('ALA', InStateMultiplierOf(NCQSOPARTY, 'ALA'), 'Alamance County is a multiplier');
   CheckEquals('WAK', InStateMultiplierOf(NCQSOPARTY, 'WAK'), 'Wake County is');
end;

(* "Operate on 80/75, 40, 20, 15, 10, 6, and 2 meters. No 160, WARC, or above
   2 meters." Every band is walked: off the list is an automatic X-QSO and
   scores nothing. *)
procedure TContestNorthCarolinaQPTests.Test_NCBands;
const
   CREDITED = [Band80, Band40, Band20, Band15, Band10, Band6, Band2];
var
   identity: TContestBase;
   b: BandType;
   qso: ContestExchange;
begin
   BeginTest('Test_NCBands');
   identity := ContestIdentity(NCQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      CheckTrue(identity.UsesBand(b) = (b in CREDITED),
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor allows it');
      qso := NCQso('K4ABC', 'WAK', b, CW, eCW);
      (* NoBand names no band, so it is never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not (b in CREDITED)) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if b in CREDITED then
         begin
         CheckEquals(3, NCPoints('WAK', b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 3');
         end
      else
         begin
         CheckEquals(0, NCPoints('WAK', b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores nothing');
         end;
      end;
end;

(* "Phone - Includes SSB, AM, and FM voice"; "Digital - Except for FT-8/4 ...
   all other digital modes are allowed"; "QSO's made using FT-8/4 should not
   be included." NY4I's standing ruling adds FT2 to the FT modes. Every mode
   and submode is walked. *)
procedure TContestNorthCarolinaQPTests.Test_NCModes;
var
   identity: TContestBase;
   mode: ModeType;
   ext: ExtendedModeType;
   credited: boolean;
begin
   BeginTest('Test_NCModes');
   identity := ContestIdentity(NCQSOPARTY);
   for mode := Low(ModeType) to High(ModeType) do
      begin
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         credited := (mode in [CW, Phone, FM]) or
                     ((mode = Digital) and not (ext in [eFT8, eFT4, eFT2]));
         CheckTrue(identity.UsesMode(mode, ext) = credited,
                   ModeStringArray[mode] + '/' + ExtendedModeStringArray[ext] +
                   ': every mode but the FT ones');
         end;
      end;
   CheckTrue(QSOIsXQSO(identity, NCQso('K4ABC', 'WAK', Band20, Digital, eFT8)), 'FT8 is an X-QSO');
   CheckTrue(QSOIsXQSO(identity, NCQso('K4ABC', 'WAK', Band20, Digital, eFT4)), 'FT4 is');
   CheckFalse(QSOIsXQSO(identity, NCQso('K4ABC', 'WAK', Band20, Digital, ePSK31)), 'PSK31 is not');
   CheckEquals(0, NCPoints('WAK', Band20, Digital, eFT8), 'FT8 scores nothing');
   CheckEquals(5, NCPoints('WAK', Band20, Digital, eRTTY), 'RTTY scores 5');
end;

(* "Phone - Includes SSB, AM, and FM voice" and "Phone - 2 points each": FM
   scores the phone 2, not digital's 5 -- and 20 in a rare county. *)
procedure TContestNorthCarolinaQPTests.Test_NCFMIsPhone;
begin
   BeginTest('Test_NCFMIsPhone');
   CheckEquals(2, NCPoints('WAK', Band2, FM, eFM), 'FM is phone: 2');
   CheckEquals(2, NCPoints('WAK', Band6, Phone, eSSB), 'SSB is 2');
   CheckEquals(20, NCPoints('CAB', Band2, FM, eFM), 'FM in a rare county: 20');
   CheckEquals(2, NCPoints('WAK', Band2, FM, eC4FM), 'C4FM is FM in TR4W: 2');
end;

(* "If at least one QSO is made with a station in five of the 'Rarest of NC'
   counties, 500 additional bonus points": the QSOs must be valid ones. A
   dupe, or a QSO on 160 m ("No 160"), is no contact for the sweep. *)
procedure TContestNorthCarolinaQPTests.Test_NCSweepNeedsCreditedQSOs;
const
   FIVE: array[0..4] of string = ('CAB', 'GRM', 'VAN', 'MAC', 'DAV');
var
   station: TStationContext;
   contestObject: TContestBase;
   view: TLoggedQSOList;
   totals: TScoreTotals;
   i: integer;
begin
   BeginTest('Test_NCSweepNeedsCreditedQSOs');
   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   contestObject := Make(NCQSOPARTY, station);
   view := TLoggedQSOList.Create;
   try
      totals := Default(TScoreTotals);
      for i := 0 to 3 do
         begin
         view.Add(NCQso('K4ABC', FIVE[i], Band20, CW, eCW));
         end;
      view.Add(NCQso('K4ABC', FIVE[4], Band160, CW, eCW));
      CheckEquals(0, contestObject.BonusPoints(totals, view),
                  'the fifth rare county worked on 160 m is no contact: no sweep');
      view.Add(NCQso('K4ABC', FIVE[4], Band40, CW, eCW));
      CheckEquals(500, contestObject.BonusPoints(totals, view),
                  'five rare counties on credited bands: the 500 sweep');
   finally
      view.Free;
      contestObject.Free;
   end;
end;

procedure TContestNorthCarolinaQPTests.RunAllTests;
begin
   Test_NCEntrantCountsTheOtherStatesDCProvincesAndDX;
   Test_NCBands;
   Test_NCModes;
   Test_NCFMIsPhone;
   Test_NCSweepNeedsCreditedQSOs;
end;

end.
