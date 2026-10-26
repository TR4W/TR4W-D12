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

(* THE FLORIDA QSO PARTY'S 2026 RULES (#88 round 2, checked 2026-10-26). The
  sponsor's texts are docs/ContestRules/QSOParties/Florida/; each test quotes
  the rule it holds.

    * points: CW 2, phone 1 -- FM is phone;
    * "No digital QSOs are allowed" -- an automatic X-QSO;
    * "No 160 or 80 meters, WARC or VHF bands" -- 40, 20, 15 and 10 m;
    * the power multiplier after points x multipliers: HIGH, LOW and QRP
      score an identical log 1:2:3;
    * the DXCC multiplier leaves out KH6 and KL7, which send a state;
    * florida.dom, the in-state file, through the real loader: the 50 states
      with Florida, DC, the 13 provinces (NS, NB and PE apart; NT, NL and NU
      known), each county counted as Florida, and no 'DX' entry. *)
unit uTestContestFloridaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestFloridaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_FloridaPoints;
      procedure Test_FloridaBands;
      procedure Test_FloridaDigitalIsAnXQSO;
      procedure Test_FloridaPowerMultiplier;
      procedure Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
      procedure Test_FloridaInStateFileIsTheSponsorsModel;
   end;

implementation

uses
   (* cpHIGH / cpLOW / cpQRP. Before VC, so VC's names win where they
      overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   uContestFloridaQP,
   LogDom,
   uTestContestObjects,
   uTestShippedDom;

(* A Florida entrant (Lee County) or one in Kansas; outside the state the
   host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'LEE';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function FloridaQso(aBand: BandType; aMode: ModeType;
                    aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K4ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'LEE';
   Result.DomesticQTH := 'Lee';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(FLORIDAQSOPARTY, Entrant(aInState));
   try
      qso := FloridaQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "Each complete non-duplicate Phone contact is worth 1 point per band. Each
   complete non-duplicate CW contact is worth 2 points per band." FM is
   phone. Inside Florida and outside it alike. *)
procedure TContestFloridaQPTests.Test_FloridaPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_FloridaPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in FL';
         end
      else
         begin
         who := 'outside FL';
         end;
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), who + ': CW is 2');
      CheckEquals(1, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 1');
      CheckEquals(1, PointsFor(inState, Band10, FM, eFM), who + ': FM is phone, 1');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "No 160 or 80 meters, WARC or VHF bands." Every BandType, both ways. *)
procedure TContestFloridaQPTests.Test_FloridaBands;
const
   SPONSOR_BANDS = [Band40, Band20, Band15, Band10];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_FloridaBands');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in SPONSOR_BANDS;
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor allows it');
      qso := FloridaQso(b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(2, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 2');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores 0');
         end;
      end;
end;

(* "No digital QSOs are allowed in the FQP." No digital submode is credited;
   CW, phone and FM are, whatever the submode. *)
procedure TContestFloridaQPTests.Test_FloridaDigitalIsAnXQSO;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_FloridaDigitalIsAnXQSO');
   identity := ContestIdentity(FLORIDAQSOPARTY);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      qso := FloridaQso(Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso), 'a digital QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckEquals(0, PointsFor(True, Band20, Digital, eRTTY), 'in FL, an RTTY QSO scores 0');
   CheckEquals(0, PointsFor(False, Band20, Digital, eNoMode), 'outside FL, a digital QSO scores 0');
end;

(* "If all QSOs were made using 5 watts output or less, use a Power
   Multiplier of 3. ... greater 5 watts and less than 100 watts ... 2. ...
   more than 100 watts ... no Power Multiplier." "Calculate the Power
   Multiplier after you have calculated your QSO Points times Multiplier."
   "If no power is indicated ... it will default to High Power." *)
procedure TContestFloridaQPTests.Test_FloridaPowerMultiplier;
var
   view: TLoggedQSOList;
   t: TScoreTotals;
   unstated: TContestBase;

   function ScoreAt(aPower: tCategoryPower): longint;
   var
      station: TStationContext;
      contestObject: TContestBase;
   begin
      station := Entrant(True);
      station.MyPower := aPower;
      contestObject := Make(FLORIDAQSOPARTY, station);
      try
         Result := contestObject.FinalScore(t, view);
      finally
         contestObject.Free;
      end;
   end;

begin
   BeginTest('Test_FloridaPowerMultiplier');
   CheckEquals(1, FloridaPowerMultiplier(cpHIGH), 'HIGH: x1');
   CheckEquals(2, FloridaPowerMultiplier(cpLOW), 'LOW: x2');
   CheckEquals(3, FloridaPowerMultiplier(cpQRP), 'QRP: x3');

   t := Default(TScoreTotals);
   t.QSOPoints := 150;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   t.Mults[AllBands, Both, rmDomestic] := 40;
   t.Mults[AllBands, Both, rmDX] := 7;
   view := TLoggedQSOList.Create;
   try
      CheckEquals(150 * 47, ScoreAt(cpHIGH), 'HIGH: points x multipliers');
      CheckEquals(150 * 47 * 2, ScoreAt(cpLOW), 'LOW: then x2');
      CheckEquals(150 * 47 * 3, ScoreAt(cpQRP), 'QRP: then x3');
      CheckEquals(ScoreAt(cpHIGH) * 2, ScoreAt(cpLOW), 'HIGH:LOW is 1:2');
      CheckEquals(ScoreAt(cpHIGH) * 3, ScoreAt(cpQRP), 'HIGH:QRP is 1:3');
      (* NO POWER STATED: a station that sets none holds the zero value,
         cpHIGH -- "it will default to High Power". *)
      unstated := Make(FLORIDAQSOPARTY, Entrant(True));
      try
         CheckEquals(150 * 47, unstated.FinalScore(t, view), 'no power stated: HIGH');
      finally
         unstated.Free;
      end;
   finally
      view.Free;
   end;
end;

(* "DXCC Countries (outside the US and Canada)" and "US (including KH6/KL7)
   operators send State": Hawaii and Alaska are the states HI and AK, never
   also a DXCC multiplier. Asked of the class directly -- the engine's
   domestic-country list happens to keep KH6 and KL away from the key today,
   and the rule must not depend on that. *)
procedure TContestFloridaQPTests.Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
var
   contestObject: TContestBase;

   function KeyOf(const aCountry: string; out aKey: DXMultiplierString): boolean;
   var
      qso: ContestExchange;
   begin
      qso := FloridaQso(Band20, CW, eCW);
      qso.QTH.CountryID := ShortString(aCountry);
      Result := contestObject.DXMultiplierKey(qso, aKey);
   end;

var
   key: DXMultiplierString;
begin
   BeginTest('Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska');
   contestObject := Make(FLORIDAQSOPARTY, Entrant(True));
   try
      CheckTrue(contestObject.HasDXMultiplier, 'Florida counts DXCC countries');
      CheckFalse(KeyOf('K', key), 'the USA is not a DXCC multiplier');
      CheckFalse(KeyOf('VE', key), 'nor Canada');
      CheckFalse(KeyOf('KH6', key), 'nor Hawaii: it sends HI');
      CheckFalse(KeyOf('KL', key), 'nor Alaska: it sends AK');
      CheckTrue(KeyOf('KP4', key), 'Puerto Rico is: "DX (including KP4, etc.)"');
      CheckEquals('KP4', string(key), 'keyed by its DXCC country');
      CheckTrue(KeyOf('DL', key), 'Germany is');
      CheckEquals('DL', string(key), 'keyed by its DXCC country');
   finally
      contestObject.Free;
   end;
end;

(* "For Florida entrants: 50 States (including Florida); District of Columbia
   (DC); 13 Canadian Provinces NS (VE1), NB (VE1, VE9), NL (VO1, VO2), PE
   (VY2), QC (VE2), ON (VE3), MB (VE4), SK (VE5), AB (VE6), BC (VE7), NT
   (VE8), NU (VY0), YT (VY1); DXCC Countries ...; There is no in-state County
   multiplier." florida.dom, through the real loader with its INCLUDEs: each
   county counts as Florida, and nothing in it is 'DX' -- the DXCC country is
   the DX multiplier, so a 'DX' domestic entry would count a DX station twice
   (the import path looked one up). *)
procedure TContestFloridaQPTests.Test_FloridaInStateFileIsTheSponsorsModel;
const
   STATES = 'AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI ' +
            'MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT ' +
            'VT VA WA WV WI WY';
   PROVINCES = 'NS NB NL PE QC ON MB SK AB BC NT NU YT';
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   words: TStringList;
   seen: TStringList;
   counties: TStringList;
   i: integer;
   key: string;
begin
   BeginTest('Test_FloridaInStateFileIsTheSponsorsModel');
   CheckEquals('florida', ContestIdentity(FLORIDAQSOPARTY).InStateDomesticFileName,
               'florida.dom is the in-state file');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   words := TStringList.Create;
   seen := TStringList.Create;
   counties := TStringList.Create;
   try
      CheckEquals('S50.DOM P13.DOM',
                  LoadShippedDomFollowingIncludes(table, 'florida.dom', True, 0),
                  'florida.dom includes the 50 states and the 13 provinces');

      seen.Sorted := True;
      seen.Duplicates := dupIgnore;
      words.Delimiter := ' ';
      words.DelimitedText := STATES;
      CheckEquals(50, words.Count, 'the sponsor lists 50 states');
      for i := 0 to words.Count - 1 do
         begin
         CheckEquals(words[i], MultiplierOf(table, words[i]), 'state ' + words[i]);
         seen.Add(MultiplierOf(table, words[i]));
         end;
      CheckEquals('DC', MultiplierOf(table, 'DC'), 'DC is its own multiplier');
      seen.Add('DC');

      words.DelimitedText := PROVINCES;
      CheckEquals(13, words.Count, 'the sponsor lists 13 provinces and territories');
      for i := 0 to words.Count - 1 do
         begin
         CheckEquals(words[i], MultiplierOf(table, words[i]), 'province ' + words[i]);
         seen.Add(MultiplierOf(table, words[i]));
         end;
      CheckEquals(64, seen.Count, '50 states, DC and 13 provinces: 64 distinct multipliers');
      CheckEquals('NB', MultiplierOf(table, 'VE9'), 'VE9 is New Brunswick');
      CheckEquals('NL', MultiplierOf(table, 'VO2'), 'VO2 is Newfoundland and Labrador');
      CheckEquals('NU', MultiplierOf(table, 'VY0'), 'VY0 is Nunavut');

      (* EVERY COUNTY OF THE OUT-OF-STATE FILE COUNTS AS FLORIDA HERE. *)
      counties.LoadFromFile(ShippedDomDir + 'florida_cty.dom');
      for i := counties.Count - 1 downto 0 do
         begin
         if Pos('=', counties[i]) = 0 then
            begin
            counties.Delete(i);
            end;
         end;
      CheckEquals(67, counties.Count, 'the 67 counties');
      for i := 0 to counties.Count - 1 do
         begin
         key := UpperCase(Trim(Copy(counties[i], Pos('=', counties[i]) + 1, MaxInt)));
         CheckEquals('FL', MultiplierOf(table, key), 'county ' + key + ' counts as Florida');
         end;

      CheckEquals('', MultiplierOf(table, 'DX'), 'no DX domestic entry');
   finally
      counties.Free;
      seen.Free;
      words.Free;
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TContestFloridaQPTests.RunAllTests;
begin
   Test_FloridaPoints;
   Test_FloridaBands;
   Test_FloridaDigitalIsAnXQSO;
   Test_FloridaPowerMultiplier;
   Test_FloridaDXMultiplierLeavesOutHawaiiAndAlaska;
   Test_FloridaInStateFileIsTheSponsorsModel;
end;

end.
