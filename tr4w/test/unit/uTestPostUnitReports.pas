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

(* THE POST-CONTEST REPORTS, PINNED TEXT FOR TEXT -- pointer audit 2.4 / P13.

  PostUnit's report builders tally into two module-level arrays
  (LogHourTotals, CountryMultTotals) that used to be heap blocks made with
  New and freed with Dispose. Nothing but the Cabrillo summary's country and
  zone halves (the corpus) covered them, and the Score by hour and QSOs by
  country reports had no test at all. These four reports are driven over a
  copy of the D7 CQ WW SSB fixture (101 QSOs, zones and countries) and
  compared with the text the pointer code wrote, kept in
  fixtures/postunit-reports. The goldens were made BY THE OLD CODE, before the
  arrays were changed, and are not to be regenerated to clear a red.

  Line endings are normalised before the comparison (Write/WriteLn gives CRLF
  on Windows and LF elsewhere). The country report names its countries from
  the shipped cty.dat, so it moves with that file -- as the corpus does. *)
unit uTestPostUnitReports;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TPostUnitReportsTests = class(TTestCase)
   private
      FDir: string;
      FSavedLogName: string;
      FSavedLogPath: string;
      FSavedSilent: boolean;
      procedure StartLog;
      procedure StopLog;
      function ReportText(const aFileName: string): RawByteString;
      procedure CheckReport(const aReportFile, aGolden: string);
   protected
      procedure TestScoreByHour;
      procedure TestQSOsByCountryByBand;
      procedure TestFirstCallInEachCountry;
      procedure TestFirstCallInEachZone;
      procedure TestTheReportsDoNotLeakIntoEachOther;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, VC, utils_text, uCTYDAT, uSettingsModel,
   uContestRegistry, uContestFactory, uLogDatabase, uLogStore, PostUnit;

const
   FIXTURE_SET = 'cqww_ssb_2025_ny4i';

var
   GSavedContest: TContestHandle;

function NormalisedLines(const aText: RawByteString): RawByteString;
begin
   Result := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
end;

(* THE FILE'S BYTES, as bytes: the reports are written in the system's ANSI
  code page and are compared that way, not decoded. *)
function ReadWhole(const aFileName: string): RawByteString;
var
   f: TFileStream;
begin
   Result := '';
   if not FileExists(aFileName) then
      begin
      Exit;
      end;
   f := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, f.Size);
      if f.Size > 0 then
         begin
         f.ReadBuffer(Result[1], f.Size);
         end;
   finally
      f.Free;
   end;
end;

procedure TPostUnitReportsTests.StartLog;
var
   source, target: TFileStream;
   trw: string;
   ctyPath: string;
begin
   LogStoreClose;
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_reports_' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   trw := FDir + FIXTURE_SET + '.trw';
   if FileExists(LogDatabaseFileName(trw)) then
      begin
      DeleteFile(LogDatabaseFileName(trw));
      end;

   source := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'fixtures' +
                                PathDelim + 'binarylog' + PathDelim +
                                FIXTURE_SET + '.trw',
                                fmOpenRead or fmShareDenyWrite);
   try
      target := TFileStream.Create(trw, fmCreate);
      try
         target.CopyFrom(source, 0);
      finally
         target.Free;
      end;
   finally
      source.Free;
   end;

   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedLogPath := CharBufferText(TR4W_LOG_PATH_NAME);
   FSavedSilent := tSilentExport;
   GSavedContest := Contest;
   SetCharBuffer(TR4W_LOG_FILENAME, trw);
   (* The reports are written under the log's path. *)
   SetCharBuffer(TR4W_LOG_PATH_NAME, FDir);
   (* No preview window, and a failure is a log line. *)
   tSilentExport := True;

   (* THE SHIPPED COUNTRY FILE, the table the reports name countries from. *)
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True),
             'the shipped cty.dat loads');

   Settings.Contest.Name := 'CQ WW SSB';
   Settings.Contest.Title := 'CQ WORLDWIDE SSB';
   Settings.My.Call := 'NY4I';
end;

procedure TPostUnitReportsTests.StopLog;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FSavedLogPath);
   tSilentExport := FSavedSilent;
   Contest := GSavedContest;
   ReleaseActiveContest;
   if FDir <> '' then
      begin
      (* Only the files this suite made. *)
      DeleteFile(FDir + FIXTURE_SET + '.trw');
      DeleteFile(LogDatabaseFileName(FDir + FIXTURE_SET + '.trw'));
      DeleteFile(LogDatabaseFileName(FDir + FIXTURE_SET + '.trw') + '-wal');
      DeleteFile(LogDatabaseFileName(FDir + FIXTURE_SET + '.trw') + '-shm');
      DeleteFile(FDir + 'HourTotals.txt');
      DeleteFile(FDir + 'qsosbycountry.txt');
      DeleteFile(FDir + 'firstcallineachcountry.txt');
      DeleteFile(FDir + 'FirstCallInEachZone.txt');
      RemoveDir(FDir);
      end;
end;

function TPostUnitReportsTests.ReportText(const aFileName: string): RawByteString;
begin
   Result := NormalisedLines(ReadWhole(FDir + aFileName));
end;

(* The report the code wrote against the golden beside the suite. A missing
  golden FAILS and leaves the text in the temp folder's .actual, so a golden
  is only ever made by looking at it. *)
procedure TPostUnitReportsTests.CheckReport(const aReportFile, aGolden: string);
var
   goldenPath: string;
   expected, actual: RawByteString;
   o: TFileStream;
begin
   actual := ReportText(aReportFile);
   CheckTrue(actual <> '', aReportFile + ' was written');
   goldenPath := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
                 'postunit-reports' + PathDelim + aGolden;
   if not FileExists(goldenPath) then
      begin
      o := TFileStream.Create(IncludeTrailingPathDelimiter(GetTempDir) +
                              aGolden + '.actual', fmCreate);
      try
         o.WriteBuffer(actual[1], Length(actual));
      finally
         o.Free;
      end;
      CheckTrue(False, 'no golden ' + goldenPath + ' (text saved as ' +
                aGolden + '.actual in the temp folder)');
      Exit;
      end;
   expected := NormalisedLines(ReadWhole(goldenPath));
   CheckTrue(expected = actual, aReportFile + ' is the text the old code wrote');
end;

procedure TPostUnitReportsTests.TestScoreByHour;
begin
   BeginTest('Score by hour is the text the heap-block code wrote');
   StartLog;
   try
      Contest := ContestHandleOf(CQWWSSB);
      ActiveContest(Contest);
      ScoreByHour;
      CheckReport('HourTotals.txt', 'HourTotals.txt');
   finally
      StopLog;
   end;
end;

procedure TPostUnitReportsTests.TestQSOsByCountryByBand;
begin
   BeginTest('QSOs by country by band is the text the heap-block code wrote');
   StartLog;
   try
      Contest := ContestHandleOf(CQWWSSB);
      ActiveContest(Contest);
      QSOsByCountryByBand;
      CheckReport('qsosbycountry.txt', 'qsosbycountry.txt');
   finally
      StopLog;
   end;
end;

procedure TPostUnitReportsTests.TestFirstCallInEachCountry;
begin
   BeginTest('First call in each country is the text the heap-block code wrote');
   StartLog;
   try
      Contest := ContestHandleOf(CQWWSSB);
      ActiveContest(Contest);
      tFirstCallInEachCountry;
      CheckReport('firstcallineachcountry.txt', 'firstcallineachcountry.txt');
   finally
      StopLog;
   end;
end;

procedure TPostUnitReportsTests.TestFirstCallInEachZone;
begin
   BeginTest('First call in each zone is the text the heap-block code wrote');
   StartLog;
   try
      Contest := ContestHandleOf(CQWWSSB);
      ActiveContest(Contest);
      tFirstCallInEachZone;
      CheckReport('FirstCallInEachZone.txt', 'FirstCallInEachZone.txt');
   finally
      StopLog;
   end;
end;

(* THE COUNTRY AND ZONE REPORTS SHARE ONE TALLY, and each starts it from zero:
  a report run after another must give the text it gives alone. *)
procedure TPostUnitReportsTests.TestTheReportsDoNotLeakIntoEachOther;
var
   alone, after: RawByteString;
begin
   BeginTest('a report run after another gives the text it gives alone');
   StartLog;
   try
      Contest := ContestHandleOf(CQWWSSB);
      ActiveContest(Contest);
      tFirstCallInEachZone;
      tFirstCallInEachCountry;
      alone := ReportText('firstcallineachcountry.txt');
      ScoreByHour;
      QSOsByCountryByBand;
      tFirstCallInEachZone;
      tFirstCallInEachCountry;
      after := ReportText('firstcallineachcountry.txt');
      CheckTrue(alone = after, 'the country report, run again after the others');
   finally
      StopLog;
   end;
end;

procedure TPostUnitReportsTests.RunAllTests;
begin
   TestScoreByHour;
   TestQSOsByCountryByBand;
   TestFirstCallInEachCountry;
   TestFirstCallInEachZone;
   TestTheReportsDoNotLeakIntoEachOther;
end;

end.
