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

(* THE DIGITAL QSOs' SHARE OF THE POINTS -- issue 129 (2026-11-18), pinned
  in its own right, as #317's second domestic key was.

  The seam: LOGDUPE.AddToTotalQSOPoints is the one statement of "a scored
  QSO's points count" -- the log's loader and live entry both call it where
  each summed TotalQSOPoints itself -- and it sums the digital QSOs' points
  beside the total, under the same band rule. uScoreTotals.GatherScoreTotals
  hands both to the contest (TScoreTotals.QSOPoints, .DigitalQSOPoints).
  Nothing is stored.

  What is held here:
    * every mode's points reach QSOPoints, a Digital QSO's reach
      DigitalQSOPoints too, so the CW and phone points are the difference;
    * a single-band entry counts its band only, in both;
    * an automatic X-QSO (scored 0 by ScoreQSO) and a dupe (0) add nothing;
    * the reset with the other totals zeroes both;
    * GatherScoreTotals copies it;
    * NO OTHER CONTEST'S SCORE MOVES: every registered contest combines the
      same score whatever DigitalQSOPoints says, except the closed list of
      contests whose rules read it. *)
unit uTestDigitalQSOPoints;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDigitalQSOPointsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_DigitalPointsArePartOfTheTotal;
      procedure Test_ASingleBandEntryCountsItsBandOnly;
      procedure Test_AnXQSOAndADupeAddNothing;
      procedure Test_TheResetZeroesBoth;
      procedure Test_GatherScoreTotalsCopiesIt;
      procedure Test_OnlyItsReadersScoreDifferently;
   end;

implementation

uses
   SysUtils, Classes, VC, uContestBase, uContestRegistry, uContestKentuckyQP,
   uScoreTotals, LogDupe,
   (* Sheet, the engine's dupe and multiplier sheet. *)
   LogStuff,
   (* Contest, the session's contest. *)
   PostUnit,
   uTestContestObjects,
   uTestRegisteredContests;

const
   (* THE CONTESTS WHOSE FORMULA READS TScoreTotals.DigitalQSOPoints -- a
      CLOSED list, by id and sorted: a contest joins it in the commit that
      gives it the rule, with its sponsor's words in its class header.
      SD-QSO-PARTY (issue 129): CW/phone points x geographic multipliers,
      plus digital points x the grids worked digitally. *)
   READS_DIGITAL_QSO_POINTS = 'SD-QSO-PARTY';

type
   (* The engine globals these tests change, saved and put back. *)
   TSavedTotals = record
      Points: longint;
      DigitalPoints: longint;
      Band: BandType;
   end;

function SaveTotals: TSavedTotals;
begin
   Result.Points := TotalQSOPoints;
   Result.DigitalPoints := TotalDigitalQSOPoints;
   Result.Band := SingleBand;
end;

procedure RestoreTotals(const aSaved: TSavedTotals);
begin
   TotalQSOPoints := aSaved.Points;
   TotalDigitalQSOPoints := aSaved.DigitalPoints;
   SingleBand := aSaved.Band;
end;

function ScoredQSO(aBand: BandType; aMode: ModeType; aPoints: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.QSOPoints := aPoints;
end;

procedure TDigitalQSOPointsTests.Test_DigitalPointsArePartOfTheTotal;
var
   saved: TSavedTotals;
begin
   BeginTest('Test_DigitalPointsArePartOfTheTotal');
   saved := SaveTotals;
   try
      SingleBand := AllBands;
      TotalQSOPoints := 0;
      TotalDigitalQSOPoints := 0;
      AddToTotalQSOPoints(ScoredQSO(Band20, CW, 2));
      AddToTotalQSOPoints(ScoredQSO(Band20, Phone, 1));
      AddToTotalQSOPoints(ScoredQSO(Band2, FM, 1));
      AddToTotalQSOPoints(ScoredQSO(Band40, Digital, 1));
      AddToTotalQSOPoints(ScoredQSO(Band80, Digital, 3));
      CheckEquals(8, TotalQSOPoints, 'every mode''s points reach the total');
      CheckEquals(4, TotalDigitalQSOPoints, 'the two Digital QSOs'' points, and only theirs');
      CheckEquals(4, TotalQSOPoints - TotalDigitalQSOPoints,
                  'the CW, phone and FM points are the difference');
   finally
      RestoreTotals(saved);
   end;
end;

procedure TDigitalQSOPointsTests.Test_ASingleBandEntryCountsItsBandOnly;
var
   saved: TSavedTotals;
begin
   BeginTest('Test_ASingleBandEntryCountsItsBandOnly');
   saved := SaveTotals;
   try
      SingleBand := Band20;
      TotalQSOPoints := 0;
      TotalDigitalQSOPoints := 0;
      AddToTotalQSOPoints(ScoredQSO(Band20, Digital, 1));
      AddToTotalQSOPoints(ScoredQSO(Band40, Digital, 1));
      AddToTotalQSOPoints(ScoredQSO(Band20, CW, 2));
      AddToTotalQSOPoints(ScoredQSO(Band40, CW, 2));
      CheckEquals(3, TotalQSOPoints, 'the scored band''s points only, as before');
      CheckEquals(1, TotalDigitalQSOPoints, 'the same band rule for the digital share');
   finally
      RestoreTotals(saved);
   end;
end;

procedure TDigitalQSOPointsTests.Test_AnXQSOAndADupeAddNothing;
var
   saved: TSavedTotals;
   handle: TContestHandle;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_AnXQSOAndADupeAddNothing');
   if not FindContestById(KY_QSO_PARTY_CONTEST_ID, handle) then
      begin
      Check(False, 'KY-QSO-PARTY is registered');
      Exit;
      end;
   saved := SaveTotals;
   (* A contest that credits no digital mode: Kentucky, whose rules have
      none, so a Digital QSO is an automatic X-QSO there and ScoreQSO
      scores it 0 -- the value live entry adds, outside its X-QSO test. *)
   contestObject := Make(handle, WithHostAreaTable(NoStation));
   try
      SingleBand := AllBands;
      TotalQSOPoints := 0;
      TotalDigitalQSOPoints := 0;
      qso := ScoredQSO(Band20, Digital, 5);
      qso.ExtMode := eFT8;
      qso.ceContest := handle;
      qso.QTHString := 'FAY';
      qso.DomesticQTH := 'FAY';
      contestObject.ScoreQSO(qso);
      CheckEquals(0, Integer(qso.QSOPoints), 'the X-QSO is scored 0');
      AddToTotalQSOPoints(qso);
      (* A dupe: LogContact and the loader carry it at 0 points. *)
      qso := ScoredQSO(Band20, Digital, 0);
      qso.ceDupe := True;
      AddToTotalQSOPoints(qso);
      CheckEquals(0, TotalQSOPoints, 'neither adds to the total');
      CheckEquals(0, TotalDigitalQSOPoints, 'nor to the digital share');
   finally
      contestObject.Free;
      RestoreTotals(saved);
   end;
end;

procedure TDigitalQSOPointsTests.Test_TheResetZeroesBoth;
var
   saved: TSavedTotals;
begin
   BeginTest('Test_TheResetZeroesBoth');
   saved := SaveTotals;
   try
      TotalQSOPoints := 7;
      TotalDigitalQSOPoints := 3;
      (* The reset every reload and rescore starts with (MainUnit.LoadinLog
         through DisposeOfMemoryAndZeroTotals). *)
      Sheet.DisposeOfMemoryAndZeroTotals;
      CheckEquals(0, TotalQSOPoints, 'the total is zeroed');
      CheckEquals(0, TotalDigitalQSOPoints, 'and its digital share with it');
   finally
      RestoreTotals(saved);
   end;
end;

procedure TDigitalQSOPointsTests.Test_GatherScoreTotalsCopiesIt;
var
   saved: TSavedTotals;
   totals: TScoreTotals;
begin
   BeginTest('Test_GatherScoreTotalsCopiesIt');
   saved := SaveTotals;
   try
      TotalQSOPoints := 9;
      TotalDigitalQSOPoints := 4;
      GatherScoreTotals(Contest, totals);
      CheckEquals(9, totals.QSOPoints, 'the total');
      CheckEquals(4, totals.DigitalQSOPoints, 'its digital share');
   finally
      RestoreTotals(saved);
   end;
end;

(* EVERY REGISTERED CONTEST combines the same score whatever the digital
   share says -- except READS_DIGITAL_QSO_POINTS, each of which must move
   (or the list names a contest that no longer reads it). *)
procedure TDigitalQSOPointsTests.Test_OnlyItsReadersScoreDifferently;
var
   contests: TContestIdentityList;
   contestObject: TContestBase;
   k: integer;
   totals: TScoreTotals;
   withoutDigital, withDigital: longint;
   readers: TStringList;
   joined: string;
begin
   BeginTest('Test_OnlyItsReadersScoreDifferently');
   totals := Default(TScoreTotals);
   totals.ScoredBand := AllBands;
   totals.SessionCountsMultipliers := True;
   totals.QSOPoints := 20;
   totals.Mults[AllBands, Both, rmDomestic] := 3;
   totals.Mults[AllBands, Both, rmDX] := 2;
   totals.Mults[AllBands, Both, rmPrefix] := 7;
   totals.Mults[AllBands, Both, rmZone] := 5;
   readers := TStringList.Create;
   try
      contests := ContestsToWalk;
      for k := 0 to High(contests) do
         begin
         contestObject := NewContestLike(contests[k], NoStation);
         try
            totals.DigitalQSOPoints := 0;
            withoutDigital := contestObject.CombineScore(totals);
            totals.DigitalQSOPoints := 6;
            withDigital := contestObject.CombineScore(totals);
            if withDigital <> withoutDigital then
               begin
               readers.Add(AnsiString(ContestId(HandleOf(contests[k]))));
               end;
         finally
            contestObject.Free;
         end;
         end;
      readers.Sort;
      joined := '';
      for k := 0 to readers.Count - 1 do
         begin
         if k > 0 then
            begin
            joined := joined + '|';
            end;
         joined := joined + string(readers[k]);
         end;
      CheckEquals(READS_DIGITAL_QSO_POINTS, joined,
                  'the contests whose score the digital share moves');
   finally
      readers.Free;
   end;
end;

procedure TDigitalQSOPointsTests.RunAllTests;
begin
   Test_DigitalPointsArePartOfTheTotal;
   Test_ASingleBandEntryCountsItsBandOnly;
   Test_AnXQSOAndADupeAddNothing;
   Test_TheResetZeroesBoth;
   Test_GatherScoreTotalsCopiesIt;
   Test_OnlyItsReadersScoreDifferently;
end;

end.
