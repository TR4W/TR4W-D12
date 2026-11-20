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

(* THE NEW YORK QSO PARTY'S 2026 RULES (#88, checked 2026-11-19). The
  sponsor's text is docs/ContestRules/QSOParties/NewYork/
  NY-QSO-PARTY-Rules-2026-v1.1.md; each test quotes the rule it holds.

    * points: phone 1, CW 2, RTTY/digital 3 -- FM is phone;
    * "All FCC allocated amateur frequencies (excluding the 30, 17, and 12
      meter bands)" -- off them is an automatic X-QSO;
    * "Maximum of 125 multipliers" / "62 maximum" -- the multipliers count
      once, overall, while a QSO counts once per band and mode;
    * the 13 Canadian provinces, NT among them, for a New York entrant
      (newyork.dom, through the real loader). *)
unit uTestContestNewYorkQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNewYorkQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NewYorkPoints;
      procedure Test_NewYorkModes;
      procedure Test_NewYorkBands;
      procedure Test_NewYorkCountsMultipliersOnceOverall;
      procedure Test_NewYorkCountsAllThirteenProvinces;
      procedure Test_NewYorkCountyAlsoEarnsNY;
      procedure Test_NewYorkCabrilloHeader;
   end;

implementation

uses
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   LogDom,
   uTestContestObjects,
   uTestShippedDom,
   uCbrSum,    (* OverlayValuesWith -- the summary window's overlay list *)
   PostUnit;   (* OverlayCategory -- the standard overlay list *)

(* A New York entrant (Monroe) or one in Kansas; outside the state the
   host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'MON';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function NYQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K2ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'ULS';
   Result.DomesticQTH := 'ULS';
end;

(* What ScoreQSO gives -- the one public scoring entry, so an off-band QSO
   scores 0 before CalculateQSOPoints is asked. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(NYQP, Entrant(aInState));
   try
      qso := NYQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "Each complete, non-duplicate Phone contact is worth 1 point per band.
   ... CW contact is worth 2 points ... RTTY (or other valid digital mode)
   contact is worth 3 points per band." Phone is "SSB, FM, AM". Inside the
   state and outside it alike. *)
procedure TContestNewYorkQPTests.Test_NewYorkPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_NewYorkPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in NY';
         end
      else
         begin
         who := 'outside NY';
         end;
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), who + ': CW is 2');
      CheckEquals(1, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 1');
      CheckEquals(1, PointsFor(inState, Band2, FM, eFM), who + ': FM is phone, 1');
      CheckEquals(3, PointsFor(inState, Band40, Digital, eRTTY), who + ': RTTY is 3');
      CheckEquals(3, PointsFor(inState, Band20, Digital, ePSK31), who + ': other digital is 3');
      CheckEquals(3, PointsFor(inState, Band20, Digital, eNoMode), who + ': digital, submode unknown, is 3');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "Only digital modes that natively support the NYQP exchange are permitted
   for contest credit." NY4I, #88, 2026-11-19: "NOT FT8, FT4 or FT2". Every
   mode and submode is walked: CW, phone and FM whole, digital but the FT
   modes. An FT QSO is an automatic X-QSO and scores nothing. *)
procedure TContestNewYorkQPTests.Test_NewYorkModes;
var
   identity: TContestBase;
   mode: ModeType;
   ext: ExtendedModeType;
   credited: boolean;
begin
   BeginTest('Test_NewYorkModes');
   identity := ContestIdentity(NYQP);
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
   CheckTrue(QSOIsXQSO(identity, NYQso(Band20, Digital, eFT8)), 'FT8 is an X-QSO');
   CheckTrue(QSOIsXQSO(identity, NYQso(Band20, Digital, eFT4)), 'FT4 is');
   CheckTrue(QSOIsXQSO(identity, NYQso(Band20, Digital, eFT2)), 'FT2 is');
   CheckFalse(QSOIsXQSO(identity, NYQso(Band20, Digital, eJS8)), 'JS8 is not');
   CheckEquals(0, PointsFor(True, Band20, Digital, eFT8), 'FT8 scores 0');
   CheckEquals(0, PointsFor(False, Band20, Digital, eFT2), 'FT2 scores 0');
   CheckEquals(3, PointsFor(True, Band20, Digital, eJTTY), 'JTTY is a 3-point digital QSO');
   CheckEquals(1, PointsFor(True, Band2, FM, eC4FM), 'C4FM is phone: 1');
   CheckEquals(1, PointsFor(False, Band2, FM, eDStar), 'D-STAR is phone: 1');
end;

(* "All FCC allocated amateur frequencies (excluding the 30, 17, and 12
   meter bands) are available for QSO credit." *)
procedure TContestNewYorkQPTests.Test_NewYorkBands;
const
   NOT_CREDITED = [Band30, Band17, Band12, AllBands, NoBand];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_NewYorkBands');
   identity := ContestIdentity(NYQP);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := not (b in NOT_CREDITED);
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor allows it');
      qso := NYQso(b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(2, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 2');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores nothing');
         end;
      end;
end;

(* "Count US states (50), New York Counties (62) and Canadian provinces (13)
   ... Maximum of 125 multipliers" and "Count New York counties for a
   maximum of 62 multipliers": a maximum that is the size of the list means
   each multiplier counts once in the contest, not once per band or mode.
   "You may contact each station once on each band and mode" -- a QSO still
   counts per band and per mode. *)
procedure TContestNewYorkQPTests.Test_NewYorkCountsMultipliersOnceOverall;
var
   identity: TContestBase;
begin
   BeginTest('Test_NewYorkCountsMultipliersOnceOverall');
   identity := ContestIdentity(NYQP);
   CheckFalse(identity.MultByBand, 'a multiplier is not counted again on another band');
   CheckFalse(identity.MultByMode, 'nor again in another mode');
   CheckTrue(identity.QSOByBand, 'a QSO counts once on each band');
   CheckTrue(identity.QSOByMode, 'and once in each mode');
end;

(* "Canadian provinces (13): AB, BC, MB, NB, NL, NT, NS, NU, ON, PE, QC, SK,
   YT" for a New York entrant -- newyork.dom, the in-state file, read
   through the real loader with its INCLUDEs. prov12.dom held twelve until
   2026-11-19: NT was missing, so a New York entrant could not log it.

   "US states (50)", no DC: NY4I (#88, 2026-11-19) names s50p13.dom, the
   file without DC, which includes prov13.dom (prov12.dom renamed for what it
   holds). The counties come FIRST, so ALB, which prov13 also gives Alberta,
   stays Albany; the old s50p13 list's NF and LB are Newfoundland and
   Labrador's NL. *)
procedure TContestNewYorkQPTests.Test_NewYorkCountsAllThirteenProvinces;
const
   PROVINCES: array[0..12] of string = (
      'AB', 'BC', 'MB', 'NB', 'NL', 'NT', 'NS', 'NU', 'ON', 'PE', 'QC', 'SK', 'YT');
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   i: integer;
begin
   BeginTest('Test_NewYorkCountsAllThirteenProvinces');
   CheckEquals('newyork', ContestIdentity(NYQP).InStateDomesticFileName,
               'newyork.dom is the in-state file');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckEquals('NEWYORK_CTY.DOM S50P13.DOM',
                  LoadShippedDomFollowingIncludes(table, 'newyork.dom', True, 0),
                  'newyork.dom includes the counties, then the 50 states and 13 provinces');
      for i := Low(PROVINCES) to High(PROVINCES) do
         begin
         CheckEquals(PROVINCES[i], MultiplierOf(table, PROVINCES[i]),
                     PROVINCES[i] + ' is a multiplier for a New York entrant');
         end;
      CheckEquals('MON', MultiplierOf(table, 'MON'), 'and a county is one');
      CheckEquals('ALB', MultiplierOf(table, 'ALB'), 'ALB is Albany County, not Alberta');
      CheckEquals('AB', MultiplierOf(table, 'ALT'), 'ALT is Alberta');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'NF is Newfoundland and Labrador''s NL');
      CheckEquals('NL', MultiplierOf(table, 'LB'), 'and so is LB');
      CheckEquals('NT', MultiplierOf(table, 'NW'), 'NW is the Northwest Territories');
      CheckEquals('ON', MultiplierOf(table, 'VE3'), 'a call prefix names its province');
      CheckEquals('LA', MultiplierOf(table, 'LA'), 'LA is Louisiana');
      CheckEquals('PA', MultiplierOf(table, 'PA'), 'a state is a multiplier');
      CheckEquals('', MultiplierOf(table, 'DC'), '"US states (50)": no DC');
      CheckEquals('DX', MultiplierOf(table, 'DX'), 'DX is known (and earns no multiplier)');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* "The first valid New York county logged will count as the multiplier for
   New York" -- NY4I (#88): a double multiplier, county and NY, for a New
   York entrant (#317's second domestic key). Only a county earns it: a
   state, a province or DX does not, and outside New York nothing does. The
   sheet side -- the 126-key in-state list, the scope, load and rescore -- is
   uTestAdditionalDomesticMultiplier's, which walks New York with the other
   parties. *)
procedure TContestNewYorkQPTests.Test_NewYorkCountyAlsoEarnsNY;

   function KeyFor(aInState: boolean; const aQTH: string; out aKey: string): boolean;
   var
      contestObject: TContestBase;
      qso: ContestExchange;
   begin
      contestObject := Make(NYQP, Entrant(aInState));
      try
         qso := NYQso(Band20, CW, eCW);
         qso.QTHString := aQTH;
         qso.DomesticQTH := aQTH;
         qso.DomMultQTH := aQTH;
         aKey := 'stale';
         Result := contestObject.AdditionalDomesticMultiplierKey(qso, aKey);
      finally
         contestObject.Free;
      end;
   end;

var
   key: string;
begin
   BeginTest('Test_NewYorkCountyAlsoEarnsNY');
   CheckTrue(KeyFor(True, 'MON', key), 'in NY, a county QSO earns a second key');
   CheckEquals('NY', key, 'and it is NY');
   CheckTrue(KeyFor(True, 'ALB', key), 'Albany too');
   CheckFalse(KeyFor(True, 'PA', key), 'a state earns no second key');
   CheckEquals('', key, 'and writes none');
   CheckFalse(KeyFor(True, 'AB', key), 'nor a province');
   CheckFalse(KeyFor(True, 'DX', key), 'nor DX');
   CheckFalse(KeyFor(False, 'MON', key), 'outside NY, a county earns only itself');
   CheckEquals('', key, 'and writes none');
end;

(* "Only these values are valid in the Overlay field: Rookie, Youth12,
   Youth17, YL"; the LOCATION header is specified. The summary window offers
   the standard list (which holds ROOKIE and YL), then YOUTH12 and YOUTH17. *)
procedure TContestNewYorkQPTests.Test_NewYorkCabrilloHeader;
var
   identity: TContestBase;
   overlays: TArray<string>;
   offered: TArray<string>;
   i, youth12, youth17, rookies: integer;
begin
   BeginTest('Test_NewYorkCabrilloHeader');
   identity := ContestIdentity(NYQP);
   CheckTrue(identity.RequiresCabrilloLocation, 'no Cabrillo file without a LOCATION');
   overlays := identity.CabrilloOverlayCategories;
   CheckEquals(4, Length(overlays), 'the sponsor names four overlays');
   CheckEquals('Rookie', overlays[0], 'Rookie');
   CheckEquals('Youth12', overlays[1], 'Youth12');
   CheckEquals('Youth17', overlays[2], 'Youth17');
   CheckEquals('YL', overlays[3], 'YL');

   offered := OverlayValuesWith(OverlayCategory, overlays);
   youth12 := 0;
   youth17 := 0;
   rookies := 0;
   for i := 0 to High(offered) do
      begin
      if SameText(offered[i], 'Youth12') then
         begin
         Inc(youth12);
         end;
      if SameText(offered[i], 'Youth17') then
         begin
         Inc(youth17);
         end;
      if SameText(offered[i], 'Rookie') then
         begin
         Inc(rookies);
         end;
      end;
   CheckEquals(1, youth12, 'Youth12 is offered once');
   CheckEquals(1, youth17, 'Youth17 is offered once');
   CheckEquals(1, rookies, 'Rookie is the standard ROOKIE, offered once');
   CheckEquals(Length(OverlayCategory) + 2 + 1, Length(offered),
               'the standard list, the two youth overlays, then the blank');
   CheckEquals('', offered[High(offered)], 'the blank is last');
end;

procedure TContestNewYorkQPTests.RunAllTests;
begin
   Test_NewYorkPoints;
   Test_NewYorkModes;
   Test_NewYorkBands;
   Test_NewYorkCountsMultipliersOnceOverall;
   Test_NewYorkCountsAllThirteenProvinces;
   Test_NewYorkCountyAlsoEarnsNY;
   Test_NewYorkCabrilloHeader;
end;

end.
