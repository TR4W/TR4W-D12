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

(* THE ITU-ZONE CONTESTS THAT STILL READ THE STATED MY ZONE -- issue 225,
   found by issue 222 (uTestIARUScoring).

   A STATED MY ZONE IS A CQ ZONE, and TStationContext.MyZone / MyZoneText
   carry it as stated in every zone mode (only an unstated zone is derived in
   the contest's ITU mode). So an ITU-zone contest that compares or SENDS it
   is wrong for an operator who typed MY ZONE = 5.

   1. THE BLACK SEA CUP INTERNATIONAL scores the same-zone point against MY
      ITU ZONE. Sponsor rule, as WA7BNM's calendar (ref 470, revised
      2026-02-16) states it: "1 point per QSO with same ITU Zone; 3 points
      per QSO with different ITU Zone same continent; 5 points per QSO with
      different ITU Zone different continent; 10 points per QSO with Black
      Sea Region countries or BSCC Members". DXLog's BSCC.txt says the same
      (CONFIG->ITUZONE). The sponsor's own page (bscc.ucoz.ru) could not be
      reached from here. Definitive, so the rule is built as IARU's
      (issue 222): the QSO's recorded my_itu_zone, else the session's ITU
      zone; 0 is unknown and earns no same-zone point.

   2. THE OZCHR (OZCR-Z) IS LEFT AS IT WAS, AND PINNED HERE. No sponsor text
      is in the tree, the QRZ.RU entry (182) could not be reached, WA7BNM has
      no entry and DXLog no file. Its point method is D7's
      IARUQSOPointMethod, transcribed -- but whether the sponsor's "own
      zone" is the ITU zone is not stated anywhere we can read, so it is NOT
      definitive and the transcribed comparison (Station.MyZone) stands
      until NY4I rules (issue 225). Change this pin with that ruling.

   3. THE DEFAULT CQ EXCHANGE of an ITU-zone contest sends the ITU zone --
      uContestBase.ZoneTextSent, the rule PostUnit.ZoneSentForThisContest
      (what the export prints) and FoundContest's default CW exchange
      messages use through uContestFactory.SessionZoneTextSent: the
      session's ITU zone when it has one, else the MY ZONE text. A CQ-zone
      contest sends the MY ZONE text, as before. *)
unit uTestITUZoneContests;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TITUZoneContestTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BSCIARecordedITUZoneScoresTheSameZonePoint;
      procedure Test_BSCILiveMyZoneDoesNotMoveARecordedScore;
      procedure Test_BSCIAnUnknownZoneEarnsNoSameZonePoint;
      procedure Test_BSCIContinentAndBlackSeaPoints;
      procedure Test_BSCIAnUncapturedQSOScoresFromTheSessionITUZone;
      procedure Test_OZCRZStillComparesTheStatedMyZone;
      procedure Test_ITUContestsCQExchangeSendsTheITUZone;
      procedure Test_CQZoneContestCQExchangeSendsMyZoneText;
      procedure Test_ZoneTextSentRule;
      procedure Test_SessionZoneTextSentFollowsTheRule;
   end;

implementation

uses
   SysUtils,
   VC,
   uSettingsModel,
   uContestBase,
   uQsoMyFacts,
   uContestFactory,
   uTestContestObjects;

var
   GSessionITUZone: integer;

(* THE SESSION'S ITU ZONE, as the engine would answer it -- see
   TStationContext.MyITUZone. *)
function StubMyITUZone: integer;
begin
   Result := GSessionITUZone;
end;

(* A NORTH AMERICAN ENTRANT WHO STATED MY ZONE 5 -- a CQ zone. *)
function StationWithStatedCQZone: TStationContext;
begin
   Result := NoStation;
   Result.MyCall := 'NY4I';
   Result.MyCountry := 'K';
   Result.MyContinent := NorthAmerica;
   Result.MyZone := 5;
   Result.MyZoneValid := True;
   Result.MyZoneText := '5';
end;

function LoggedFacts(aITUZone: integer): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;
   Result.Call := 'NY4I';
   Result.Continent := 'NA';
   Result.ITUZone := aITUZone;
end;

function ZoneQso(const aCall: string; const aCountry: string; aZone: integer;
                 aContinent: ContinentType; const aQTH: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Band := Band20;
   Result.Mode := CW;
   Result.ceRecordKind := rkQSO;
   Result.Callsign := CallString(aCall);
   Result.Zone := aZone;
   Result.QTH.CountryID := CallString(aCountry);
   Result.QTH.Continent := aContinent;
   (* A society or member text is recorded as both, as the parser records an
      HQ abbreviation (uTestIARUScoring's IARUQso). *)
   Result.DomesticQTH := ShortString(aQTH);
   Result.QTHString := ShortString(aQTH);
   Result.QSOPoints := 99;
end;

function ScoreWithFacts(aContest: TContestBase; aQso: ContestExchange;
                        const aFacts: TQsoMyFacts): integer;
begin
   aContest.ScoreQSO(aQso, aFacts);
   Result := aQso.QSOPoints;
end;

function ScoreUncaptured(aContest: TContestBase; aQso: ContestExchange): integer;
begin
   aContest.ScoreQSO(aQso);
   Result := aQso.QSOPoints;
end;

procedure TITUZoneContestTests.RunAllTests;
begin
   Test_BSCIARecordedITUZoneScoresTheSameZonePoint;
   Test_BSCILiveMyZoneDoesNotMoveARecordedScore;
   Test_BSCIAnUnknownZoneEarnsNoSameZonePoint;
   Test_BSCIContinentAndBlackSeaPoints;
   Test_BSCIAnUncapturedQSOScoresFromTheSessionITUZone;
   Test_OZCRZStillComparesTheStatedMyZone;
   Test_ITUContestsCQExchangeSendsTheITUZone;
   Test_CQZoneContestCQExchangeSendsMyZoneText;
   Test_ZoneTextSentRule;
   Test_SessionZoneTextSentFollowsTheRule;
end;

(* THE DEFECT: a stated CQ zone 5, a recorded ITU zone 8, W1AW in ITU 8. Same
   ITU zone: 1 point. It scored 3 -- 8 is not 5, both in NA. *)
procedure TITUZoneContestTests.Test_BSCIARecordedITUZoneScoresTheSameZonePoint;
var
   obj: TContestBase;
begin
   BeginTest('Test_BSCIARecordedITUZoneScoresTheSameZonePoint');
   obj := MakeContestOrNil(BSCI, StationWithStatedCQZone);
   CheckTrue(obj <> nil, 'BSCI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(1, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(8)),
                  'stated CQ zone 5, recorded ITU zone 8, W1AW ITU 8: 1');
   finally
      obj.Free;
      end;
end;

(* THE OTHER DIRECTION: the live MY ZONE equals the worked zone, but the QSO
   recorded ITU zone 7. Different zone, same continent: 3. *)
procedure TITUZoneContestTests.Test_BSCILiveMyZoneDoesNotMoveARecordedScore;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_BSCILiveMyZoneDoesNotMoveARecordedScore');
   station := StationWithStatedCQZone;
   station.MyZone := 8;
   station.MyZoneText := '8';
   obj := MakeContestOrNil(BSCI, station);
   CheckTrue(obj <> nil, 'BSCI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(7)),
                  'live MY ZONE 8, recorded ITU zone 7, W1AW ITU 8: 3');
      CheckEquals(1, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(8)),
                  'live MY ZONE 8, recorded ITU zone 8, W1AW ITU 8: 1');
   finally
      obj.Free;
      end;
end;

(* A RECORDED ZONE OF 0 IS UNKNOWN: no same-zone point, even when the live MY
   ZONE matches. *)
procedure TITUZoneContestTests.Test_BSCIAnUnknownZoneEarnsNoSameZonePoint;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_BSCIAnUnknownZoneEarnsNoSameZonePoint');
   station := StationWithStatedCQZone;
   station.MyZone := 8;
   obj := MakeContestOrNil(BSCI, station);
   CheckTrue(obj <> nil, 'BSCI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(0)),
                  'recorded ITU zone unknown, W1AW ITU 8, both NA: 3');
      CheckEquals(5, ScoreWithFacts(obj, ZoneQso('F4HQ', 'F', 27, Europe, ''), LoggedFacts(0)),
                  'recorded ITU zone unknown, F4HQ in EU: 5');
   finally
      obj.Free;
      end;
end;

(* THE CONTINENT ARMS, AND THE BLACK SEA 10 -- a Black Sea Region country or
   a BSCC member (a QTH starting BS) is 10 wherever it is, same zone
   included. *)
procedure TITUZoneContestTests.Test_BSCIContinentAndBlackSeaPoints;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_BSCIContinentAndBlackSeaPoints');
   obj := MakeContestOrNil(BSCI, StationWithStatedCQZone);
   CheckTrue(obj <> nil, 'BSCI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('VE3AAA', 'VE', 4, NorthAmerica, ''), LoggedFacts(8)),
                  'VE3 ITU 4, same continent, another zone: 3');
      CheckEquals(5, ScoreWithFacts(obj, ZoneQso('F4HQ', 'F', 27, Europe, ''), LoggedFacts(8)),
                  'F4HQ ITU 27, another continent: 5');
      CheckEquals(10, ScoreWithFacts(obj, ZoneQso('LZ1AAA', 'LZ', 28, Europe, ''), LoggedFacts(8)),
                  'LZ1AAA, a Black Sea Region country: 10');
      CheckEquals(10, ScoreWithFacts(obj, ZoneQso('W1BS', 'K', 8, NorthAmerica, 'BS123'), LoggedFacts(8)),
                  'a BSCC member in my own ITU zone: 10');

      (* A EUROPEAN ENTRANT, ITU 28, who stated CQ zone 14. *)
      station := StationWithStatedCQZone;
      station.MyCall := 'F1AAA';
      station.MyCountry := 'F';
      station.MyContinent := Europe;
      station.MyZone := 14;
      station.MyZoneText := '14';
      obj.SetStation(station);
      CheckEquals(1, ScoreWithFacts(obj, ZoneQso('F4HQ', 'F', 27, Europe, ''), LoggedFacts(27)),
                  'F entrant ITU 27, F4HQ ITU 27: 1');
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('F4HQ', 'F', 27, Europe, ''), LoggedFacts(28)),
                  'F entrant ITU 28, F4HQ ITU 27: 3');
      CheckEquals(5, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(27)),
                  'F entrant, W1AW in NA: 5');
      CheckEquals(10, ScoreWithFacts(obj, ZoneQso('LZ1AAA', 'LZ', 28, Europe, ''), LoggedFacts(28)),
                  'F entrant ITU 28, LZ1AAA ITU 28 -- Black Sea wins: 10');
   finally
      obj.Free;
      end;
end;

(* A QSO NEVER CAPTURED scores from the session's ITU zone -- never the stated
   MY ZONE. With no answer there is no same-zone point. *)
procedure TITUZoneContestTests.Test_BSCIAnUncapturedQSOScoresFromTheSessionITUZone;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_BSCIAnUncapturedQSOScoresFromTheSessionITUZone');
   station := StationWithStatedCQZone;
   station.MyITUZone := @StubMyITUZone;
   GSessionITUZone := 8;
   obj := MakeContestOrNil(BSCI, station);
   CheckTrue(obj <> nil, 'BSCI has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(1, ScoreUncaptured(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, '')),
                  'stated CQ zone 5, session ITU zone 8, W1AW ITU 8: 1');
      CheckEquals(3, ScoreUncaptured(obj, ZoneQso('W5AAA', 'K', 7, NorthAmerica, '')),
                  'session ITU zone 8, W5 ITU 7: 3');
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(7)),
                  'a captured row wins over the session: 3');

      station.MyZone := 8;
      GSessionITUZone := 0;
      obj.SetStation(station);
      CheckEquals(3, ScoreUncaptured(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, '')),
                  'session ITU zone unknown, MY ZONE 8: 3');
      station.MyITUZone := nil;
      obj.SetStation(station);
      CheckEquals(3, ScoreUncaptured(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, '')),
                  'no service, MY ZONE 8: 3');
   finally
      obj.Free;
      end;
end;

(* OZCR-Z: THE DECISION IS PINNED, NOT JUDGED (issue 225). No readable
   sponsor rule says which zone "own zone" is -- see the header, item 2 -- so
   the transcribed D7 comparison against Station.MyZone stands: a stated MY
   ZONE still decides the same-zone point, and a recorded ITU zone does not.
   When NY4I rules (the case for switching: its point method IS D7's
   IARUQSOPointMethod, which issue 222 ruled is the ITU zone; it multiplies
   and exports ITU zones), change this test with the class. *)
procedure TITUZoneContestTests.Test_OZCRZStillComparesTheStatedMyZone;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_OZCRZStillComparesTheStatedMyZone');
   station := StationWithStatedCQZone;
   station.MyITUZone := @StubMyITUZone;
   GSessionITUZone := 8;
   obj := MakeContestOrNil(OZCR_Z, station);
   CheckTrue(obj <> nil, 'OZCR_Z has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, ''), LoggedFacts(8)),
                  'pinned: stated MY ZONE 5, recorded ITU 8, W1AW 8 -- still 3');
      CheckEquals(1, ScoreWithFacts(obj, ZoneQso('W5AAA', 'K', 5, NorthAmerica, ''), LoggedFacts(8)),
                  'pinned: stated MY ZONE 5, a station sending 5 -- still 1');
      CheckEquals(1, ScoreWithFacts(obj, ZoneQso('W1AW', 'K', 8, NorthAmerica, 'RCC'), LoggedFacts(8)),
                  'a society station: 1');
      CheckEquals(5, ScoreWithFacts(obj, ZoneQso('F4HQ', 'F', 27, Europe, ''), LoggedFacts(8)),
                  'another continent: 5');
   finally
      obj.Free;
      end;
end;

(* THE DEFAULT CQ EXCHANGE OF EVERY ITU-ZONE CONTEST THAT OFFERS ONE sends the
   session's ITU zone, never the stated CQ zone -- and, when the session has
   none, the MY ZONE text as before. A sent state (an HQ's society) is sent
   instead of either. *)
procedure TITUZoneContestTests.Test_ITUContestsCQExchangeSendsTheITUZone;

   procedure Check(aContest: ContestType);
   var
      obj: TContestBase;
      station: TStationContext;
      name: string;
   begin
      name := ContestTypeSA[aContest];
      station := StationWithStatedCQZone;
      station.MyITUZone := @StubMyITUZone;
      obj := MakeContestOrNil(aContest, station);
      CheckTrue(obj <> nil, name + ' has no registered class');
      if obj = nil then
         begin
         Exit;
         end;
      try
         CheckTrue(obj.ZoneMultiplierZones = zmzITUZones, name + ': an ITU-zone contest');

         GSessionITUZone := 8;
         CheckEquals(' 5NN 8', obj.CQExchangeDefault(station),
                     name + ': stated CQ zone 5, session ITU zone 8');

         GSessionITUZone := 0;
         CheckEquals(' 5NN 5', obj.CQExchangeDefault(station),
                     name + ': no session ITU zone, the MY ZONE text');

         station.MyITUZone := nil;
         CheckEquals(' 5NN 5', obj.CQExchangeDefault(station),
                     name + ': no service, the MY ZONE text');

         station.MyITUZone := @StubMyITUZone;
         GSessionITUZone := 8;
         station.MyState := 'ARRL';
         CheckEquals(' 5NN ARRL', obj.CQExchangeDefault(station),
                     name + ': a sent state wins');
      finally
         obj.Free;
         end;
   end;

begin
   BeginTest('Test_ITUContestsCQExchangeSendsTheITUZone');
   Check(IARU);
   Check(OZCR_Z);
   Check(OZCR_O);
   Check(LZDX);
end;

(* A CQ-ZONE CONTEST IS UNCHANGED: CQ 160 sends the MY ZONE text whatever the
   session's ITU zone. *)
procedure TITUZoneContestTests.Test_CQZoneContestCQExchangeSendsMyZoneText;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_CQZoneContestCQExchangeSendsMyZoneText');
   station := StationWithStatedCQZone;
   station.MyITUZone := @StubMyITUZone;
   GSessionITUZone := 8;
   obj := MakeContestOrNil(CQ160CW, station);
   CheckTrue(obj <> nil, 'CQ160CW has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(' 5NN 5', obj.CQExchangeDefault(station), 'CQ 160 CW: the MY ZONE text');
   finally
      obj.Free;
      end;
end;

(* THE RULE ITSELF -- uContestBase.ZoneTextSent. *)
procedure TITUZoneContestTests.Test_ZoneTextSentRule;
begin
   BeginTest('Test_ZoneTextSentRule');
   GSessionITUZone := 8;
   CheckEquals('8', ZoneTextSent(zmzITUZones, @StubMyITUZone, '05'),
               'ITU zones, session ITU zone 8');
   CheckEquals('05', ZoneTextSent(zmzCQZones, @StubMyITUZone, '05'),
               'CQ zones: the MY ZONE text, never the ITU zone');
   CheckEquals('05', ZoneTextSent(zmzNotCQOrITU, @StubMyITUZone, '05'),
               'neither: the MY ZONE text');
   CheckEquals('05', ZoneTextSent(zmzITUZones, nil, '05'),
               'ITU zones, no service: the MY ZONE text');
   GSessionITUZone := 0;
   CheckEquals('05', ZoneTextSent(zmzITUZones, @StubMyITUZone, '05'),
               'ITU zones, session ITU zone unknown: the MY ZONE text');
end;

(* THE SESSION'S ANSWER -- uContestFactory.SessionZoneTextSent, which
   PostUnit.ZoneSentForThisContest (the export) returns -- IS THE SAME RULE
   over the session's settings: a stated
   CQ zone 5 and a stated ITU zone 8 (as this contest's overrides, withdrawn
   after). The default CW exchange messages FoundContest writes ask exactly
   this (FCONTEST's TEngineExchangeMessageWriters). *)
procedure TITUZoneContestTests.Test_SessionZoneTextSentFollowsTheRule;
var
   iaruObj: TContestBase;
   cqwwObj: TContestBase;
   hadZone: boolean;
   hadItu: boolean;
   savedZone: string;
   savedItu: string;
begin
   BeginTest('Test_SessionZoneTextSentFollowsTheRule');
   hadZone := Settings.My.HasContestOverride(sfZone);
   hadItu := Settings.My.HasContestOverride(sfItuZone);
   savedZone := Settings.My.ContestOverride(sfZone);
   savedItu := Settings.My.ContestOverride(sfItuZone);
   iaruObj := MakeContestOrNil(IARU, NoStation);
   cqwwObj := MakeContestOrNil(CQWWCW, NoStation);
   try
      Settings.My.SetContestOverride(sfZone, '5');
      Settings.My.SetContestOverride(sfItuZone, '8');
      CheckEquals('8', SessionZoneTextSent(iaruObj), 'IARU: the stated ITU zone');
      CheckEquals('5', SessionZoneTextSent(cqwwObj), 'CQ WW: the stated CQ zone');
      CheckEquals('5', SessionZoneTextSent(nil), 'no contest: the MY ZONE text');
   finally
      if hadZone then
         begin
         Settings.My.SetContestOverride(sfZone, savedZone);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfZone);
         end;
      if hadItu then
         begin
         Settings.My.SetContestOverride(sfItuZone, savedItu);
         end
      else
         begin
         Settings.My.ClearContestOverride(sfItuZone);
         end;
      iaruObj.Free;
      cqwwObj.Free;
      end;
end;

end.
