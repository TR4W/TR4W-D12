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

(* THE WAE QTC-PER-STATION COUNTS -- pointer audit 2.5 / P13.

  How many QTCs have been sent to or taken from each station lives in
  logwind.QTCDataArray, which was a heap block made with New (LogCfg, when the
  QTC setting was on; logstuff.EnsureQTCDataArray, on demand). It is a module
  array now. These tests pin the behaviour the callers see -- counting,
  per-station lookup, decrement, and the 500-station edge -- through the
  routines they call (IncrementQTCCount, NumberQTCsThisStation,
  DecrementQTCCount), written against the pointer code first.

  They reset the two counters the table is read through (NumberQTCStations,
  TotalNumberQTCsProcessed) and never touch the table itself, which is how an
  earlier suite's entries stay out of the answer: only the first
  NumberQTCStations rows are ever read. *)
unit uTestQTCCounts;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TQTCCountsTests = class(TTestCase)
   private
      procedure Reset;
   protected
      procedure TestCountsAreKeptPerStation;
      procedure TestDecrementStopsAtZeroAndTouchesOnlyThatStation;
      procedure TestTheFiveHundredAndFirstStationIsNotKept;
      procedure TestAResetForgetsTheStations;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, VC, LogWind, LogStuff;

procedure TQTCCountsTests.Reset;
begin
   NumberQTCStations := 0;
   TotalNumberQTCsProcessed := 0;
end;

procedure TQTCCountsTests.TestCountsAreKeptPerStation;
begin
   BeginTest('QTCs are counted per station');
   Reset;
   IncrementQTCCount('DL1AAA');
   IncrementQTCCount('DL1AAA');
   IncrementQTCCount('DL1BBB');
   IncrementQTCCount('DL1AAA');
   CheckEquals(3, NumberQTCsThisStation('DL1AAA'), 'the station worked three times');
   CheckEquals(1, NumberQTCsThisStation('DL1BBB'), 'and the one worked once');
   CheckEquals(0, NumberQTCsThisStation('DL1CCC'), 'a station never worked');
   CheckEquals(2, NumberQTCStations, 'two stations are on the books');
   CheckEquals(4, TotalNumberQTCsProcessed, 'and four QTCs were processed');
end;

procedure TQTCCountsTests.TestDecrementStopsAtZeroAndTouchesOnlyThatStation;
begin
   BeginTest('a decrement takes QTCs back from that station, down to zero');
   Reset;
   IncrementQTCCount('DL1AAA');
   IncrementQTCCount('DL1AAA');
   IncrementQTCCount('DL1AAA');
   IncrementQTCCount('DL1BBB');
   DecrementQTCCount('DL1AAA', 2);
   CheckEquals(1, NumberQTCsThisStation('DL1AAA'), 'two taken back');
   DecrementQTCCount('DL1AAA', 5);
   CheckEquals(0, NumberQTCsThisStation('DL1AAA'), 'and no further than zero');
   CheckEquals(1, NumberQTCsThisStation('DL1BBB'), 'the other station untouched');
   DecrementQTCCount('DL1BBB', 0);
   CheckEquals(1, NumberQTCsThisStation('DL1BBB'), 'a count of none changes nothing');
end;

procedure TQTCCountsTests.TestTheFiveHundredAndFirstStationIsNotKept;
var
   i: integer;
begin
   BeginTest('the table holds 500 stations; the 501st is counted as processed but not kept');
   Reset;
   for i := 0 to 499 do
      begin
      IncrementQTCCount(ShortString('W' + IntToStr(i)));
      end;
   CheckEquals(500, NumberQTCStations, 'the table is full');
   CheckEquals(1, NumberQTCsThisStation('W0'), 'the first station kept');
   CheckEquals(1, NumberQTCsThisStation('W499'), 'and the last');
   IncrementQTCCount('W500');
   CheckEquals(500, NumberQTCStations, 'a 501st station adds no row');
   CheckEquals(0, NumberQTCsThisStation('W500'), 'so it has no count');
   CheckEquals(501, TotalNumberQTCsProcessed, 'though the QTC itself was processed');
   IncrementQTCCount('W7');
   CheckEquals(2, NumberQTCsThisStation('W7'), 'a station on the books still counts');
end;

procedure TQTCCountsTests.TestAResetForgetsTheStations;
begin
   BeginTest('a reset of the two counters forgets the stations');
   Reset;
   IncrementQTCCount('DL1AAA');
   Reset;
   CheckEquals(0, NumberQTCsThisStation('DL1AAA'), 'nothing is on the books');
   IncrementQTCCount('DL1BBB');
   CheckEquals(1, NumberQTCsThisStation('DL1BBB'), 'a new station starts at one');
   CheckEquals(0, NumberQTCsThisStation('DL1AAA'), 'and the old one is not remembered');
end;

(* THE TWO COUNTERS ARE THE APPLICATION'S: TotalNumberQTCsProcessed is the WAE
  QTC points, so a suite that left it at 1 would hand every later WAE score a
  stray point. Put back as found. *)
procedure TQTCCountsTests.RunAllTests;
var
   savedStations, savedProcessed: integer;
begin
   savedStations := NumberQTCStations;
   savedProcessed := TotalNumberQTCsProcessed;
   try
      TestCountsAreKeptPerStation;
      TestDecrementStopsAtZeroAndTouchesOnlyThatStation;
      TestTheFiveHundredAndFirstStationIsNotKept;
      TestAResetForgetsTheStations;
   finally
      NumberQTCStations := savedStations;
      TotalNumberQTCsProcessed := savedProcessed;
   end;
end;

end.
