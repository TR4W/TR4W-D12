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

(* THE OHIO QSO PARTY'S 2026 RULES (#88 round 3, checked
  2026-10-26). The sponsor's text is docs/ContestRules/QSOParties/
  Ohio/OH-QSO-PARTY-Rules.txt; the test quotes the rule it holds:
  Ohio is not one of a Ohio entrant's state multipliers. *)
unit uTestContestOhioQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestOhioQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_OhioIsNoStateMultiplierInState;
      procedure Test_OhioExchangeHasNoSerial;
      procedure Test_OhioNoCountyLines;
      procedure Test_OhioBands;
      procedure Test_OhioModes;
      procedure Test_OhioInStateFileHasDCAndDX;
      procedure Test_OhioCanadianMultipliersAreTheSponsorsEleven;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uMults,
   LogDom,
   uContestBase,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uTestContestObjects,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   uTestQSOPartyRules;

function OHQso(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K8ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'ADAM';
   Result.DomesticQTH := 'ADAM';
   Result.DomMultQTH := 'ADAM';
end;

function OHPoints(aBand: BandType; aMode: ModeType; aExtMode: ExtendedModeType): integer;
var
   station: TStationContext;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   station := WithHostAreaTable(NoStation);
   station.InHostState := True;
   contestObject := Make(OHIOQSOPARTY, station);
   try
      qso := OHQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "For OHIO STATIONS - multipliers are the 49 American States (excluding
   Ohio), 1 Washington DC, 11 Canadian Provinces (NL, PE, NS, NB,VE2-7, NT),
   88 Ohio Counties and 1 DX."
   ohio.dom includes the shared S50.DOM, so it gives OH the
   multiplier OH; a Ohio entrant's QSO with it earns none.
   Another state and a county still count, and outside Ohio the
   rule is not asked. *)
procedure TContestOhioQPTests.Test_OhioIsNoStateMultiplierInState;
var
   host: string;
begin
   BeginTest('Test_OhioIsNoStateMultiplierInState');
   host := InStateMultiplierOf(OHIOQSOPARTY, 'OH');
   CheckEquals('OH', host, 'ohio.dom gives OH the multiplier OH (S50.DOM)');
   CheckFalse(CountsForEntrant(OHIOQSOPARTY, True, host, rmDomestic),
              'in state: Ohio is no multiplier');
   CheckFalse(CountsForEntrant(OHIOQSOPARTY, True, 'Oh', rmDomestic),
              'in the file''s own spelling either');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, True, InStateMultiplierOf(OHIOQSOPARTY, 'MI'), rmDomestic),
             'MI is');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, True, InStateMultiplierOf(OHIOQSOPARTY, 'ADAM'), rmDomestic),
             'a county is');
   CheckTrue(CountsForEntrant(OHIOQSOPARTY, False, host, rmDomestic),
             'outside Ohio the rule is not asked');
end;

(* "Ohio stations send RST and their Ohio county. Non Ohio W/VE stations ...
   send RST and their state or province. DX stations outside of W/VE send RST
   and "DX"." No serial number: the exchange is RST and a domestic QTH, and
   the received fields (also the ADIF export) hold no serial. *)
procedure TContestOhioQPTests.Test_OhioExchangeHasNoSerial;
var
   identity: TContestBase;
begin
   BeginTest('Test_OhioExchangeHasNoSerial');
   identity := ContestIdentity(OHIOQSOPARTY);
   CheckTrue(identity.ExchangeKind = RSTDomesticQTHExchange, 'RST and the county');
   CheckTrue(identity.ReceivedExchangeFields.RST, 'the RST is carried');
   CheckTrue(identity.ReceivedExchangeFields.QTH, 'and the QTH');
end;

(* "No station may claim simultaneous operation in more than one county,
   state, or province." One QTH in an exchange is accepted, two are refused. *)
procedure TContestOhioQPTests.Test_OhioNoCountyLines;
var
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_OhioNoCountyLines');
   party := ContestIdentity(OHIOQSOPARTY) as TContestStateQSOPartyBase;
   CheckEquals(0, party.CountyLineCountiesMax, 'no county line');
   CheckFalse(party.CountyLineAllowed, 'county lines are not allowed');
   CheckTrue(party.ValidateQTHCount(1, msg), 'one county is fine');
   CheckFalse(party.ValidateQTHCount(2, msg), 'two counties in one exchange are refused');
end;

(* "CW and SSB on 160, 80, 40, 20, 15, and 10 meters." Every band is walked. *)
procedure TContestOhioQPTests.Test_OhioBands;
const
   CREDITED = [Band160, Band80, Band40, Band20, Band15, Band10];
var
   identity: TContestBase;
   b: BandType;
begin
   BeginTest('Test_OhioBands');
   identity := ContestIdentity(OHIOQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      CheckTrue(identity.UsesBand(b) = (b in CREDITED),
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor allows it');
      CheckTrue(QSOIsXQSO(identity, OHQso(b, CW, eCW)) = ((not (b in CREDITED)) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      end;
   CheckEquals(2, OHPoints(Band160, CW, eCW), '160 m CW: 2');
   CheckEquals(0, OHPoints(Band30, CW, eCW), '30 m scores nothing');
   CheckEquals(0, OHPoints(Band6, Phone, eUSB), '6 m scores nothing');
end;

(* "CW and SSB": CW 2, phone 1; a digital QSO is no mode of the contest, and
   neither is FM (NY4I, 2026-11-20: "Just CW and SSB"). *)
procedure TContestOhioQPTests.Test_OhioModes;
var
   identity: TContestBase;
   mode: ModeType;
   ext: ExtendedModeType;
begin
   BeginTest('Test_OhioModes');
   identity := ContestIdentity(OHIOQSOPARTY);
   for mode := Low(ModeType) to High(ModeType) do
      begin
      for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
         begin
         CheckTrue(identity.UsesMode(mode, ext) = (mode in [CW, Phone]),
                   ModeStringArray[mode] + '/' + ExtendedModeStringArray[ext]);
         end;
      end;
   CheckEquals(2, OHPoints(Band20, CW, eCW), 'CW is 2');
   CheckEquals(1, OHPoints(Band20, Phone, eUSB), 'SSB is 1');
   CheckEquals(0, OHPoints(Band20, Digital, eRTTY), 'RTTY is an X-QSO: 0');
   CheckTrue(QSOIsXQSO(identity, OHQso(Band20, Digital, ePSK31)), 'PSK31 is an X-QSO');
   CheckEquals(0, OHPoints(Band10, FM, eFM), 'FM is an X-QSO: 0');
   CheckTrue(QSOIsXQSO(identity, OHQso(Band10, FM, eFM)), 'FM is an X-QSO');
end;

(* THE SPONSOR'S 11 CANADIAN MULTIPLIERS -- "11 Canadian Provinces (NL, PE,
   NS, NB,VE2-7, NT)", and from the party's site (NY4I, 2026-11-20): "NT =
   Yukon-NWT-Nu". ohio.dom includes ohio_ve.dom, not the shared P13.DOM: a
   Yukon or Nunavut station keeps its own QTH (YT, NU) and counts as NT, so
   the eleven are all there are. Through the shipped files and the real
   loader. *)
procedure TContestOhioQPTests.Test_OhioCanadianMultipliersAreTheSponsorsEleven;
const
   SPONSOR_VE: array[0..10] of string = (
      'NL', 'PE', 'NS', 'NB', 'QC', 'ON', 'MB', 'SK', 'AB', 'BC', 'NT');
   (* Every other spelling of a Canadian QTH the file knows. *)
   OTHER_VE: array[0..9] of string = (
      'YT', 'NU', 'VY0', 'VY1', 'VE8', 'NF', 'LB', 'VO1', 'VO2', 'PEI');
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   multipliers: TStringList;
   i: integer;
begin
   BeginTest('Test_OhioCanadianMultipliersAreTheSponsorsEleven');
   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   multipliers := TStringList.Create;
   try
      multipliers.Sorted := True;
      multipliers.Duplicates := dupIgnore;
      LoadShippedDomFollowingIncludes(table, 'ohio.dom', True, 0);
      for i := Low(SPONSOR_VE) to High(SPONSOR_VE) do
         begin
         CheckEquals(SPONSOR_VE[i], MultiplierOf(table, SPONSOR_VE[i]),
                     SPONSOR_VE[i] + ' is its own multiplier');
         multipliers.Add(MultiplierOf(table, SPONSOR_VE[i]));
         end;
      for i := Low(OTHER_VE) to High(OTHER_VE) do
         begin
         CheckTrue(MultiplierOf(table, OTHER_VE[i]) <> '', OTHER_VE[i] + ' is known');
         multipliers.Add(MultiplierOf(table, OTHER_VE[i]));
         end;
      CheckEquals(11, multipliers.Count, 'eleven Canadian multipliers, no more');

      CheckEquals('NT', MultiplierOf(table, 'YT'), 'Yukon counts as NT');
      CheckEquals('YT', QTHOf(table, 'YT'), 'and keeps its own QTH');
      CheckEquals('NT', MultiplierOf(table, 'NU'), 'Nunavut counts as NT');
      CheckEquals('NU', QTHOf(table, 'NU'), 'and keeps its own QTH');
      CheckEquals('NT', MultiplierOf(table, 'VY1'), 'a VY1 prefix is Yukon, NT');
      CheckEquals('NL', MultiplierOf(table, 'NF'), 'NF is Newfoundland and Labrador');
      CheckEquals('NL', MultiplierOf(table, 'LB'), 'and so is LB');
      CheckEquals('LA', MultiplierOf(table, 'LA'), 'LA is Louisiana, not Labrador');
      CheckTrue(CountsForEntrant(OHIOQSOPARTY, True, 'NT', rmDomestic), 'NT counts in state');
   finally
      multipliers.Free;
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* "49 American States (excluding Ohio), 1 Washington DC ... and 1 DX":
   ohio.dom had neither DC nor DX, so an Ohio entrant could not log them. *)
procedure TContestOhioQPTests.Test_OhioInStateFileHasDCAndDX;
begin
   BeginTest('Test_OhioInStateFileHasDCAndDX');
   CheckEquals('DC', InStateMultiplierOf(OHIOQSOPARTY, 'DC'), 'DC is its own multiplier');
   CheckEquals('DX', InStateMultiplierOf(OHIOQSOPARTY, 'DX'), 'DX is the one DX multiplier');
   CheckEquals('MD', InStateMultiplierOf(OHIOQSOPARTY, 'MD'), 'Maryland is Maryland');
   CheckEquals('ADAM', InStateMultiplierOf(OHIOQSOPARTY, 'ADAM'), 'a county is a multiplier');
end;

procedure TContestOhioQPTests.RunAllTests;
begin
   Test_OhioIsNoStateMultiplierInState;
   Test_OhioExchangeHasNoSerial;
   Test_OhioNoCountyLines;
   Test_OhioBands;
   Test_OhioModes;
   Test_OhioInStateFileHasDCAndDX;
   Test_OhioCanadianMultipliersAreTheSponsorsEleven;
end;

end.
