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
unit uTestSettingsConvert;
{$I ..\..\src\tr4w.inc}

(*
  THE CONVERTER, AGAINST FILES IT WRITES ITSELF.

  Every fixture here is built in the test's own temporary directory, so these
  run on a machine that has never had TR4W installed and cannot be affected by
  the developer's own settings -- which is the same reason the golden corpus
  was given its own settings file.

  THE CASE THAT MATTERS MOST IS THE NESTED ONE. A real tr4w.json groups its
  legacy commands by category, so 'MY GRID' is at commands/other/MY GRID. The
  startup seed this converter replaces looks for it with FindPath at the top of
  the object and therefore finds nothing at all; a test written only against a
  FLAT bucket would pass on both the broken code and the fixed code and would
  have caught nothing.
*)

interface

uses
   uTR4WTestFramework;

type
   TSettingsConvertTests = class(TTestCase)
   private
      procedure Test_NestedLegacyCommandsAreFound;
      procedure Test_DryRunWritesNothing;
      procedure Test_ApplyWritesAndIsIdempotent;
      procedure Test_ContestScopedCommandsAreLeftToTheDatabase;
      procedure Test_IniFillsAGapButDoesNotOverrideTheStore;
      procedure Test_AValueThePropertyRefusesIsReported;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, Classes,
   uSettingsModel,
   uSettingsConvert;


(* A settings file with the legacy commands NESTED the way the store writes
  them, and a settings section that is present but knows nothing about the
  group under test -- which is exactly the shape of the tracked corpus
  fixture, and the shape the old seed could not read. *)
function WriteNestedFixture(const aDir: string; const aGrid, aName: string): string;
var
   f: TStringList;
begin
   Result := IncludeTrailingPathDelimiter(aDir) + 'tr4w.json';
   f := TStringList.Create;
   try
      f.Add('{');
      f.Add('   "version" : 1,');
      f.Add('   "settings" : {');
      f.Add('      "ExternalLogger" : { "Port" : 52001 }');
      f.Add('   },');
      f.Add('   "commands" : {');
      f.Add('      "other" : {');
      f.Add('         "MY GRID" : "' + aGrid + '",');
      f.Add('         "MY NAME" : "' + aName + '"');
      f.Add('      }');
      f.Add('   }');
      f.Add('}');
      f.SaveToFile(Result);
   finally
      f.Free;
   end;
end;


function TempDirFor(const aWhat: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir)
             + 'tr4wconv_' + aWhat + PathDelim;
   ForceDirectories(Result);
end;


function OutcomeOf(const aReport: TConvertReport; const aCommand: string;
                   out aEntry: TConvertEntry): boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to High(aReport) do
      begin
      if SameText(aReport[i].Command, aCommand) then
         begin
         aEntry := aReport[i];
         Result := True;
         Exit;
         end;
      end;
end;


procedure TSettingsConvertTests.Test_NestedLegacyCommandsAreFound;
var
   dir, file_: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   e: TConvertEntry;
begin
   BeginTest('a legacy command nested under its category is found');

   dir := TempDirFor('nested');
   file_ := WriteNestedFixture(dir, 'EL88', 'TOM');
   s := TR4WSettings.Create;
   try
      CheckTrue(ConvertStationSettings(file_, '', False, s, report, err),
                'the conversion ran: ' + err);
      CheckTrue(OutcomeOf(report, 'MY GRID', e), 'MY GRID is in the report');
      (* THE WHOLE POINT. FindPath on the nested object returns nil, so the
        seed this replaces reported no old value here. *)
      CheckEquals(Ord(coConverted), Ord(e.Outcome),
                  'the nested value was found and applied');
      CheckEquals('EL88', e.NewValue, 'and it is the value from the file');
      CheckEquals('EL88', s.My.Grid, 'the property carries it');
   finally
      s.Free;
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.Test_DryRunWritesNothing;
var
   dir, file_: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   before, after: string;
   f: TStringList;
begin
   BeginTest('a dry run decides everything and writes nothing');

   dir := TempDirFor('dry');
   file_ := WriteNestedFixture(dir, 'FN20', 'JO');
   f := TStringList.Create;
   s := TR4WSettings.Create;
   try
      f.LoadFromFile(file_);
      before := f.Text;

      CheckTrue(ConvertStationSettings(file_, '', False, s, report, err),
                'the conversion ran: ' + err);
      CheckTrue(CountOutcome(report, coConverted) > 0, 'it had work to do');

      f.LoadFromFile(file_);
      after := f.Text;
      CheckEquals(before, after, 'the file is byte-for-byte what it was');
   finally
      s.Free;
      f.Free;
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.Test_ApplyWritesAndIsIdempotent;
var
   dir, file_: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   firstRun: integer;
begin
   BeginTest('applying writes the settings section, and running twice is safe');

   dir := TempDirFor('apply');
   file_ := WriteNestedFixture(dir, 'JN58', 'HANS');
   s := TR4WSettings.Create;
   try
      CheckTrue(ConvertStationSettings(file_, '', True, s, report, err),
                'the first run: ' + err);
      firstRun := CountOutcome(report, coConverted);
      CheckTrue(firstRun > 0, 'the first run converted something');
   finally
      s.Free;
   end;

   (* A SECOND RUN AGAINST A FRESH SETTINGS OBJECT reads the file the first one
     wrote. Nothing should be left to convert, which is what makes it safe to
     tell an operator to just run it again. *)
   s := TR4WSettings.Create;
   try
      CheckTrue(ConvertStationSettings(file_, '', True, s, report, err),
                'the second run: ' + err);
      CheckEquals('JN58', s.My.Grid, 'the value survived the round trip');
      CheckEquals(0, CountOutcome(report, coConverted),
                  'and the second run had nothing left to convert');
   finally
      s.Free;
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.Test_ContestScopedCommandsAreLeftToTheDatabase;
var
   dir, file_: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   e: TConvertEntry;
begin
   BeginTest('a contest setting is left to the contest database');

   dir := TempDirFor('scope');
   file_ := WriteNestedFixture(dir, 'EM12', 'SAM');
   s := TR4WSettings.Create;
   try
      CheckTrue(ConvertStationSettings(file_, '', False, s, report, err),
                'the conversion ran: ' + err);
      (* HF BAND ENABLE is contest-scoped and has been since the band enables
        moved; it must never be written into the station's settings file. *)
      CheckTrue(OutcomeOf(report, 'HF BAND ENABLE', e),
                'the contest-scoped command is still reported');
      CheckEquals(Ord(coContestScoped), Ord(e.Outcome),
                  'and it is reported as the contest''s');
      CheckTrue(CountOutcome(report, coContestScoped) > 1,
                'it is not the only one');
   finally
      s.Free;
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.Test_IniFillsAGapButDoesNotOverrideTheStore;
var
   dir, file_, iniFile: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   e: TConvertEntry;
   f: TStringList;
begin
   BeginTest('the old ini fills a gap but does not beat the newer store');

   dir := TempDirFor('ini');
   file_ := WriteNestedFixture(dir, 'IO91', 'ANNE');
   iniFile := dir + 'tr4w.ini';
   f := TStringList.Create;
   try
      f.Add('[COMMANDS]');
      (* MY GRID is in BOTH files and they disagree. The store is newer and is
        what the program applies last, so it wins. *)
      f.Add('MY GRID=AA00');
      (* MY SECTION is only in the ini, so it fills a gap. *)
      f.Add('MY SECTION=WCF');
      f.SaveToFile(iniFile);
   finally
      f.Free;
   end;

   s := TR4WSettings.Create;
   try
      CheckTrue(ConvertStationSettings(file_, iniFile, False, s, report, err),
                'the conversion ran: ' + err);

      CheckTrue(OutcomeOf(report, 'MY GRID', e), 'MY GRID is reported');
      CheckEquals('IO91', e.NewValue, 'the store won over the ini');

      CheckTrue(OutcomeOf(report, 'MY SECTION', e), 'MY SECTION is reported');
      CheckEquals('WCF', e.NewValue, 'and the ini filled the gap');
   finally
      s.Free;
      DeleteFile(iniFile);
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.Test_AValueThePropertyRefusesIsReported;
var
   dir, file_: string;
   s: TR4WSettings;
   report: TConvertReport;
   err: string;
   e: TConvertEntry;
   f: TStringList;
begin
   BeginTest('a value the property will not take is reported, not forced');

   dir := TempDirFor('refuse');
   file_ := IncludeTrailingPathDelimiter(dir) + 'tr4w.json';
   f := TStringList.Create;
   try
      f.Add('{');
      f.Add('   "version" : 1,');
      f.Add('   "settings" : { },');
      f.Add('   "commands" : {');
      (* A port is an integer property and this is not a number. *)
      f.Add('      "other" : { "EXTERNAL LOGGER PORT" : "not a number" }');
      f.Add('   }');
      f.Add('}');
      f.SaveToFile(file_);
   finally
      f.Free;
   end;

   s := TR4WSettings.Create;
   try
      s.ExternalLogger.Port := 52001;
      CheckTrue(ConvertStationSettings(file_, '', False, s, report, err),
                'the conversion ran: ' + err);
      CheckTrue(OutcomeOf(report, 'EXTERNAL LOGGER PORT', e),
                'the refused command is reported');
      CheckEquals(Ord(coRefused), Ord(e.Outcome), 'and it says REFUSED');
      CheckEquals(52001, s.ExternalLogger.Port,
                  'and the property is untouched');
   finally
      s.Free;
      DeleteFile(file_);
   end;
end;


procedure TSettingsConvertTests.RunAllTests;
begin
   Test_NestedLegacyCommandsAreFound;
   Test_DryRunWritesNothing;
   Test_ApplyWritesAndIsIdempotent;
   Test_ContestScopedCommandsAreLeftToTheDatabase;
   Test_IniFillsAGapButDoesNotOverrideTheStore;
   Test_AValueThePropertyRefusesIsReported;
end;

end.
