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

(* THE IARU HF CHAMPIONSHIP'S POINTS -- issue 222 (NY4I ruling, 2026-11-05).

   THE RULE (D7 LOGSTUFF IARUQSOPointMethod, and the class header):

      a society (HQ) station        1, wherever it is
      same ITU zone as mine         1
      same continent, other zone    3
      another continent             5

   THE ZONE IS MY ITU ZONE FOR THAT QSO -- what the export prints for it. NY4I:
   a QSO is scored and exported from its own recorded fields; live station
   state is immaterial. So a stated MY ZONE (a CQ zone: TStationContext.MyZone
   carries it as stated) must never decide the same-zone point:

      a captured QSO      its recorded my_itu_zone (ScoringMyFacts.ITUZone);
                          0 is UNKNOWN and earns no same-zone point
      a QSO never captured, or one being logged now
                          the session's ITU zone, TStationContext.MyITUZone --
                          the same engine answer the capture records

   W1AW is ITU 8, NA; VE3 ITU 4, NA; F4HQ ITU 27, EU. The QSO's received zone
   and continent are set by hand: scoring reads the record, not CTY.DAT. *)
unit uTestIARUScoring;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TIARUScoringTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ARecordedITUZoneScoresTheSameZonePoint;
      procedure Test_LiveMyZoneDoesNotMoveARecordedScore;
      procedure Test_AnUnknownRecordedZoneEarnsNoSameZonePoint;
      procedure Test_ContinentAndDXPoints;
      procedure Test_ASocietyStationIsOnePoint;
      procedure Test_AnUncapturedQSOScoresFromTheSessionITUZone;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uQsoMyFacts,
   uTestContestObjects;

var
   GSessionITUZone: integer;

(* THE SESSION'S ITU ZONE, as the engine would answer it -- see
   TStationContext.MyITUZone. *)
function StubMyITUZone: integer;
begin
   Result := GSessionITUZone;
end;

(* A NORTH AMERICAN ENTRANT WHO STATED MY ZONE 5 -- a CQ zone, which is what the
   setting holds. The stated value is exactly what used to win the same-zone
   test. *)
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

function IARUQso(const aCall: string; aZone: integer;
                 aContinent: ContinentType;
                 const aSociety: string): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Band := Band20;
   Result.Mode := CW;
   Result.ceRecordKind := rkQSO;
   Result.Callsign := CallString(aCall);
   Result.Zone := aZone;
   Result.QTH.Continent := aContinent;
   Result.DomesticQTH := ShortString(aSociety);
   Result.QTHString := ShortString(aSociety);
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

procedure TIARUScoringTests.RunAllTests;
begin
   Test_ARecordedITUZoneScoresTheSameZonePoint;
   Test_LiveMyZoneDoesNotMoveARecordedScore;
   Test_AnUnknownRecordedZoneEarnsNoSameZonePoint;
   Test_ContinentAndDXPoints;
   Test_ASocietyStationIsOnePoint;
   Test_AnUncapturedQSOScoresFromTheSessionITUZone;
end;

(* THE DEFECT ITSELF: a stated CQ zone 5, a recorded ITU zone 8, W1AW in ITU 8.
   Same ITU zone: 1 point. It scored 3 -- 8 is not 5, both in NA. *)
procedure TIARUScoringTests.Test_ARecordedITUZoneScoresTheSameZonePoint;
var
   obj: TContestBase;
begin
   BeginTest('Test_ARecordedITUZoneScoresTheSameZonePoint');
   obj := MakeContestOrNil(IARU, StationWithStatedCQZone);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(8)),
                  'stated CQ zone 5, recorded ITU zone 8, W1AW ITU 8: 1');
   finally
      obj.Free;
      end;
end;

(* THE OTHER DIRECTION: the live MY ZONE happens to equal the worked zone, but
   the QSO recorded ITU zone 7. Different zone, same continent: 3. *)
procedure TIARUScoringTests.Test_LiveMyZoneDoesNotMoveARecordedScore;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_LiveMyZoneDoesNotMoveARecordedScore');
   station := StationWithStatedCQZone;
   station.MyZone := 8;
   station.MyZoneText := '8';
   obj := MakeContestOrNil(IARU, station);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(7)),
                  'live MY ZONE 8, recorded ITU zone 7, W1AW ITU 8: 3');
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(8)),
                  'live MY ZONE 8, recorded ITU zone 8, W1AW ITU 8: 1');
   finally
      obj.Free;
      end;
end;

(* A CAPTURED ZONE OF 0 IS UNKNOWN, and a reader never borrows today's value
   for it (uQsoMyFacts). The export prints no zone for it; scoring awards no
   same-zone point -- even when the live MY ZONE matches. *)
procedure TIARUScoringTests.Test_AnUnknownRecordedZoneEarnsNoSameZonePoint;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_AnUnknownRecordedZoneEarnsNoSameZonePoint');
   station := StationWithStatedCQZone;
   station.MyZone := 8;
   obj := MakeContestOrNil(IARU, station);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(0)),
                  'recorded ITU zone unknown, W1AW ITU 8, both NA: 3');
      CheckEquals(5, ScoreWithFacts(obj, IARUQso('F4HQ', 27, Europe, ''), LoggedFacts(0)),
                  'recorded ITU zone unknown, F4HQ in EU: 5');
   finally
      obj.Free;
      end;
end;

(* THE CONTINENT ARMS, from a recorded ITU zone 8. *)
procedure TIARUScoringTests.Test_ContinentAndDXPoints;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_ContinentAndDXPoints');
   obj := MakeContestOrNil(IARU, StationWithStatedCQZone);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(3, ScoreWithFacts(obj, IARUQso('VE3AAA', 4, NorthAmerica, ''), LoggedFacts(8)),
                  'VE3 ITU 4, same continent, another zone: 3');
      CheckEquals(5, ScoreWithFacts(obj, IARUQso('F4HQ', 27, Europe, ''), LoggedFacts(8)),
                  'F4HQ ITU 27, another continent: 5');

      (* A EUROPEAN ENTRANT, ITU 28: F4HQ is the same continent, another zone. *)
      station := StationWithStatedCQZone;
      station.MyCall := 'DL1AAA';
      station.MyCountry := 'DL';
      station.MyContinent := Europe;
      station.MyZone := 14;
      obj.SetStation(station);
      CheckEquals(3, ScoreWithFacts(obj, IARUQso('F4HQ', 27, Europe, ''), LoggedFacts(28)),
                  'DL entrant ITU 28, F4HQ ITU 27: 3');
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('DL2BBB', 28, Europe, ''), LoggedFacts(28)),
                  'DL entrant ITU 28, DL2BBB ITU 28: 1');
      CheckEquals(5, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(28)),
                  'DL entrant, W1AW in NA: 5');
   finally
      obj.Free;
      end;
end;

(* A SOCIETY STATION IS ONE POINT WHEREVER IT IS -- the QSO carried an HQ
   abbreviation (DomesticQTH) rather than a zone. *)
procedure TIARUScoringTests.Test_ASocietyStationIsOnePoint;
var
   obj: TContestBase;
begin
   BeginTest('Test_ASocietyStationIsOnePoint');
   obj := MakeContestOrNil(IARU, StationWithStatedCQZone);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, 'ARRL'), LoggedFacts(8)),
                  'W1AW sending ARRL: 1');
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('TM0HQ', 27, Europe, 'REF'), LoggedFacts(8)),
                  'TM0HQ sending REF, another continent: 1');
      CheckEquals(1, ScoreUncaptured(obj, IARUQso('TM0HQ', 27, Europe, 'REF')),
                  'TM0HQ sending REF, never captured: 1');
   finally
      obj.Free;
      end;
end;

(* A QSO NEVER CAPTURED -- every corpus fixture, and the QSO being logged NOW
   (the entry path scores before the row is written) -- scores from the
   session's ITU zone, the value the capture records and the export prints.
   Never from the stated MY ZONE. With no answer (no service, or 0) there is
   no same-zone point. *)
procedure TIARUScoringTests.Test_AnUncapturedQSOScoresFromTheSessionITUZone;
var
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_AnUncapturedQSOScoresFromTheSessionITUZone');
   station := StationWithStatedCQZone;
   station.MyITUZone := @StubMyITUZone;
   GSessionITUZone := 8;
   obj := MakeContestOrNil(IARU, station);
   CheckTrue(obj <> nil, 'IARU has no registered class');
   if obj = nil then
      begin
      Exit;
      end;
   try
      CheckEquals(1, ScoreUncaptured(obj, IARUQso('W1AW', 8, NorthAmerica, '')),
                  'stated CQ zone 5, session ITU zone 8, W1AW ITU 8: 1');
      CheckEquals(1, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), NotCapturedMyFacts),
                  'the same, handed NotCapturedMyFacts: 1');
      CheckEquals(3, ScoreUncaptured(obj, IARUQso('W5AAA', 7, NorthAmerica, '')),
                  'session ITU zone 8, W5 ITU 7: 3');

      (* A CAPTURED ROW WINS OVER THE SESSION. *)
      CheckEquals(3, ScoreWithFacts(obj, IARUQso('W1AW', 8, NorthAmerica, ''), LoggedFacts(7)),
                  'session ITU 8, recorded ITU 7, W1AW ITU 8: 3');

      (* NO ANSWER: no same-zone point, never the stated MY ZONE. *)
      station.MyZone := 8;
      GSessionITUZone := 0;
      obj.SetStation(station);
      CheckEquals(3, ScoreUncaptured(obj, IARUQso('W1AW', 8, NorthAmerica, '')),
                  'session ITU zone unknown, MY ZONE 8: 3');
      station.MyITUZone := nil;
      obj.SetStation(station);
      CheckEquals(3, ScoreUncaptured(obj, IARUQso('W1AW', 8, NorthAmerica, '')),
                  'no service, MY ZONE 8: 3');
   finally
      obj.Free;
      end;
end;

end.
