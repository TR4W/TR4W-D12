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
      procedure Test_NewYorkBands;
      procedure Test_NewYorkCountsMultipliersOnceOverall;
      procedure Test_NewYorkCountsAllThirteenProvinces;
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
   uTestShippedDom;

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
   2026-11-19: NT was missing, so a New York entrant could not log it. *)
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
      CheckEquals('NEWYORK_CTY.DOM S50.DOM PROV12.DOM',
                  LoadShippedDomFollowingIncludes(table, 'newyork.dom', True, 0),
                  'newyork.dom includes the counties, the 50 states and the provinces');
      for i := Low(PROVINCES) to High(PROVINCES) do
         begin
         CheckEquals(PROVINCES[i], MultiplierOf(table, PROVINCES[i]),
                     PROVINCES[i] + ' is a multiplier for a New York entrant');
         end;
      CheckEquals('MON', MultiplierOf(table, 'MON'), 'and a county is one');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TContestNewYorkQPTests.RunAllTests;
begin
   Test_NewYorkPoints;
   Test_NewYorkBands;
   Test_NewYorkCountsMultipliersOnceOverall;
   Test_NewYorkCountsAllThirteenProvinces;
end;

end.
