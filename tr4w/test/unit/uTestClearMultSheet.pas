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

(* CLEAR MULT SHEET AND THE SCORE ALREADY EARNED -- issue 164 (from the D7
  repository's TR4W/TR4W#224, the Ukraine Championship).

  THE REPORT. The Ukraine Championship is run in mini-tours: 2 points a QSO
  and 10 points for each NEW oblast in each tour. Between tours the operator
  clears the dupe sheet and the multiplier sheet (CLEARMULTSHEET / Ctrl-C) so
  the oblasts count again. The QSO points survive the clear; the 10 a
  multiplier already earned does not.

  WHAT THIS PINS IS WHAT THE PROGRAM DOES TODAY, and it is D7's behaviour
  line for line (C:\TR4W MainUnit tUpdateLog's actClearMults arm, LOGDUPE
  AddQSOToSheets' ceClearMultSheet exit, LOGEDIT TotalScore's
  `QPoints + 10 * TotalMults`). It is NOT a ruling that this is right: the
  rule wanted is open on issue 164. When NY4I rules, the assertions named
  "ISSUE 164 TODAY" are the ones that flip.

  THROUGH THE REAL ENGINE: a scratch SQLite log, the Ukraine class scoring
  each QSO (ScoreQSO), the real sheet deciding each new multiplier
  (Sheet.SetMultFlags), the real Clear Mult Sheet pass (MainUnit.tUpdateLog
  (actClearMults) -- what tClearMultSheet runs before LoadinLog) and the real
  rescore pass (tUpdateLog(actRescore)), and the final score asked of the
  contest (GatherScoreTotals + ContestFinalScore, what LogEdit.TotalScore
  calls, without its main-thread cache).

  THE ONE HAND-WRITTEN STEP IS THE RELOAD. LoadinLog ends in UpdateWindows,
  the editable-log refresh and SaveRestartFile -- window work this binary
  does not boot -- so ReloadSheetsFromTheLog replays its scoring half
  exactly: DisposeOfMemoryAndZeroTotals, then for every stored row
  QSOCountsTowardTotals, TotalQSOPoints, AddQSOToSheets and AddLoggedQSO, in
  log order. It runs no SetMultFlags, as LoadinLog runs none: the loader
  trusts the stored flags (issue 137).

  The two tours use DIFFERENT calls, so no QSO is a dupe and the dupe-sheet
  clear the reporter also runs is not needed: what moves is the multiplier
  sheet's clear alone. *)
unit uTestClearMultSheet;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC, uTR4WTestFramework;

type
   TClearMultSheetTests = class(TTestCase)
   private
      FDir: string;
      FTrw: string;
      FDb: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
      FSavedByBand: boolean;
      FSavedByMode: boolean;
      FSavedSingleBand: BandType;
      FNextSeed: integer;
      (* An EMPTY scratch log as the store's open log, and back. *)
      procedure StartEmptyStore;
      procedure StopStore;
      procedure Scrub(const aFileName: string);
      (* One QSO with a Ukrainian station on 40 m CW from oblast aKey,
         scored by the contest and flagged by the sheet as live entry does,
         added to the sheet, and written to the log. *)
      procedure LogUkrainianQSO(const aCall: string; const aKey: string);
      (* LoadinLog's scoring half -- see the header. *)
      procedure ReloadSheetsFromTheLog;
      (* The final score, as TotalScore asks it. *)
      function FinalScore: longint;
      (* The stored rows' flags and points, counted. *)
      procedure CountStoredRows(out aRows: integer; out aCleared: integer;
                                out aFlagged: integer; out aPoints: integer);
   protected
      procedure Test_ClearingTheMultSheetDropsTheEarnedMultiplierPoints;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   utils_text,
   uSettingsModel,
   uQsoMyFacts,
   uLogDatabase,
   uLogStore,
   uLogSource,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uScoreTotals,
   uMults,
   LogDupe,
   LogStuff,
   PostUnit,
   MainUnit,
   (* LAST, so its session set-up wins any name the engine units share. *)
   uTestEngineEntry;

const
   UKRAINIAN_COUNTRIES: array[0..0] of string = ('UR');

procedure TClearMultSheetTests.Scrub(const aFileName: string);
const
   SUFFIXES: array[0..4] of string = ('', '-wal', '-shm', '-journal', '.importing');
var
   i: integer;
begin
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(aFileName + SUFFIXES[i]) then
         begin
         DeleteFile(aFileName + SUFFIXES[i]);
         end;
      end;
end;

procedure TClearMultSheetTests.StartEmptyStore;
begin
   LogStoreClose;
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_clearmult_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;
   (* NO .TRW BESIDE IT: the open makes a new, empty log (as
      uTestLogStore.TestAnEmptyLogIsBackedUpBeforeClear relies on). *)
   FTrw := IncludeTrailingPathDelimiter(FDir) + 'ukraine_clearmult.trw';
   FDb := LogDatabaseFileName(FTrw);
   Scrub(FDb);
   if FileExists(FTrw) then
      begin
      DeleteFile(FTrw);
      end;

   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedSilent := tSilentExport;
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   tSilentExport := True;
end;

procedure TClearMultSheetTests.StopStore;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   Scrub(FDb);
   if FileExists(FTrw) then
      begin
      DeleteFile(FTrw);
      end;
   if FDir <> '' then
      begin
      RemoveDir(FDir);
      end;
end;

procedure TClearMultSheetTests.LogUkrainianQSO(const aCall: string; const aKey: string);
var
   rx: ContestExchange;
begin
   Inc(FNextSeed);
   rx := Default(ContestExchange);
   rx.ceRecordKind := rkQSO;
   rx.ceContest := Contest;
   rx.id := 'clearmult' + IntToStr(FNextSeed);
   rx.ceQSOID1 := 5000 + FNextSeed;
   rx.ceQSOID2 := 6000 + FNextSeed;
   rx.tSysTime.qtYear := 26;
   rx.tSysTime.qtMonth := 11;
   rx.tSysTime.qtDay := 1;
   rx.tSysTime.qtHour := 12;
   rx.tSysTime.qtMinute := FNextSeed;
   rx.Callsign := CallString(aCall);
   rx.Frequency := 7025000;
   rx.Band := Band40;
   rx.Mode := CW;
   rx.ExtMode := eCW;
   rx.NumberSent := FNextSeed;
   rx.NumberReceived := FNextSeed;
   rx.Prefecture := 255;
   rx.QTH.CountryID := 'UR';
   rx.QTHString := UpperCase(aKey);
   rx.DomesticQTH := aKey;
   rx.DomMultQTH := aKey;

   (* LIVE ENTRY'S ORDER (LogContact): the sheet decides NEW, the contest
      scores, the QSO goes on the sheet and into the totals, then the log. *)
   Sheet.SetMultFlags(rx);
   ActiveContest(Contest).ScoreQSO(rx);
   Sheet.AddQSOToSheets(@rx, True);
   CheckTrue(LogStoreAppendQSO(rx), aCall + ' is logged');
end;

procedure TClearMultSheetTests.ReloadSheetsFromTheLog;
var
   rx: ContestExchange;
   facts: TQsoMyFacts;
begin
   Sheet.DisposeOfMemoryAndZeroTotals;
   CheckTrue(LogSourceOpen, 'the log source opens for the reload');
   try
      LogSourceRewind;
      while LogSourceNext(rx, facts) do
         begin
         if (rx.ceRecordKind = rkQSO)    and
            (not rx.ceQSO_Deleted)       and
            QSOCountsTowardTotals(LoggedQSOContest(rx.ceContest), rx) then
            begin
            if (SingleBand = rx.Band) or (SingleBand = AllBands) then
               begin
               TotalQSOPoints := TotalQSOPoints + rx.QSOPoints;
               end;
            Sheet.AddQSOToSheets(@rx, True);
            AddLoggedQSO(rx, facts);
            end;
         end;
   finally
      LogSourceClose;
   end;
end;

function TClearMultSheetTests.FinalScore: longint;
var
   totals: TScoreTotals;
begin
   GatherScoreTotals(Contest, totals);
   Result := ContestFinalScore(Contest, totals);
end;

procedure TClearMultSheetTests.CountStoredRows(out aRows: integer; out aCleared: integer;
                                               out aFlagged: integer; out aPoints: integer);
var
   rx: ContestExchange;
begin
   aRows := 0;
   aCleared := 0;
   aFlagged := 0;
   aPoints := 0;
   CheckTrue(LogSourceOpen, 'the log source opens for the count');
   try
      LogSourceRewind;
      while LogSourceNext(rx) do
         begin
         Inc(aRows);
         if rx.ceClearMultSheet then
            begin
            Inc(aCleared);
            end;
         if rx.DomesticMult then
            begin
            Inc(aFlagged);
            end;
         aPoints := aPoints + rx.QSOPoints;
         end;
   finally
      LogSourceClose;
   end;
end;

procedure TClearMultSheetTests.Test_ClearingTheMultSheetDropsTheEarnedMultiplierPoints;
var
   rows, cleared, flagged, points: integer;
begin
   BeginTest('Test_ClearingTheMultSheetDropsTheEarnedMultiplierPoints');

   SetUpSession(UKRAINECHAMPIONSHIP, UKRAINIAN_COUNTRIES, 'ukraine.dom');
   FSavedByBand := Settings.Mult.ByBand;
   FSavedByMode := Settings.Mult.ByMode;
   FSavedSingleBand := SingleBand;
   (* THE CLASS'S TRAIT (cfMultByBand), as FoundContest writes it. *)
   Settings.Mult.ByBand := True;
   Settings.Mult.ByMode := False;
   SingleBand := AllBands;
   FNextSeed := 0;
   StartEmptyStore;
   try
      CheckTrue(LogStoreEnsureOpen, 'an empty scratch log opens');
      Sheet.DisposeOfMemoryAndZeroTotals;

      (* TOUR 1: five QSOs, four oblasts -- the reporter's 2 x 5 and 10 x 4. *)
      LogUkrainianQSO('UR1AAA', 'Ki');
      LogUkrainianQSO('UR1BBB', 'Ch');
      LogUkrainianQSO('UR1CCC', 'Dn');
      LogUkrainianQSO('UR1DDD', 'Ha');
      LogUkrainianQSO('UR1EEE', 'Ki');
      ReloadSheetsFromTheLog;
      CountStoredRows(rows, cleared, flagged, points);
      CheckEquals(5, rows, 'tour 1: five rows');
      CheckEquals(4, flagged, 'tour 1: four rows carry the new-oblast flag');
      CheckEquals(10, points, 'tour 1: 2 points a QSO, stored');
      CheckEquals(10, TotalQSOPoints, 'tour 1: the loader sums them');
      CheckEquals(4, mo.MTotals[AllBands, Both, rmDomestic], 'tour 1: four oblasts on the sheet');
      CheckEquals(10 + 10 * 4, FinalScore, 'tour 1: 10 + 10 x 4');

      (* THE CLEAR, as tClearMultSheet runs it: the pass, then the reload. *)
      tUpdateLog(actClearMults);
      ReloadSheetsFromTheLog;
      CountStoredRows(rows, cleared, flagged, points);
      CheckEquals(5, cleared, 'every tour-1 row is marked ceClearMultSheet');
      CheckEquals(10, points, 'the stored QSO points are untouched by the clear');
      CheckEquals(10, TotalQSOPoints, 'and the loader still sums them');
      (* ISSUE 164 TODAY -- D7 identical. The flags are WRITTEN AWAY in the
         rows, and the loader puts no ceClearMultSheet row on the sheet, so
         the 10 x 4 the first tour earned is gone. *)
      CheckEquals(0, flagged, 'ISSUE 164 TODAY: the clear erases the stored multiplier flags');
      CheckEquals(0, mo.MTotals[AllBands, Both, rmDomestic], 'ISSUE 164 TODAY: the sheet is empty');
      CheckEquals(10, FinalScore, 'ISSUE 164 TODAY: the score falls from 50 to 10');

      (* TOUR 2: the same four oblasts count again, which is the clear's
         purpose and works. *)
      LogUkrainianQSO('UR2AAA', 'Ki');
      LogUkrainianQSO('UR2BBB', 'Ch');
      LogUkrainianQSO('UR2CCC', 'Dn');
      LogUkrainianQSO('UR2DDD', 'Ha');
      LogUkrainianQSO('UR2EEE', 'Ki');
      ReloadSheetsFromTheLog;
      CountStoredRows(rows, cleared, flagged, points);
      CheckEquals(10, rows, 'tour 2: ten rows');
      CheckEquals(4, flagged, 'tour 2: its four oblasts are new again');
      CheckEquals(20, points, 'tour 2: 2 points a QSO, twenty stored');
      CheckEquals(4, mo.MTotals[AllBands, Both, rmDomestic], 'tour 2: four oblasts on the sheet');
      (* The reporter's expectation is 20 + 10 x 8 = 100. *)
      CheckEquals(20 + 10 * 4, FinalScore, 'ISSUE 164 TODAY: 60, not the 100 two tours earned');

      (* A RESCORE CANNOT GIVE IT BACK: SetMultFlags exits for a
         ceClearMultSheet row, and the flag it would need is gone anyway. *)
      tUpdateLog(actRescore);
      ReloadSheetsFromTheLog;
      CountStoredRows(rows, cleared, flagged, points);
      CheckEquals(5, cleared, 'after a rescore: still five cleared rows');
      CheckEquals(4, flagged, 'after a rescore: still only tour 2''s four flags');
      CheckEquals(20, points, 'after a rescore: the points are as stored');
      CheckEquals(20 + 10 * 4, FinalScore, 'ISSUE 164 TODAY: a rescore keeps 60');
   finally
      StopStore;
      Settings.Mult.ByBand := FSavedByBand;
      Settings.Mult.ByMode := FSavedByMode;
      SingleBand := FSavedSingleBand;
      Sheet.DisposeOfMemoryAndZeroTotals;
      RestoreSession;
   end;
end;

procedure TClearMultSheetTests.RunAllTests;
begin
   Test_ClearingTheMultSheetDropsTheEarnedMultiplierPoints;
end;

end.
