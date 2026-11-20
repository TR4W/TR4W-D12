{
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
}
unit uTestWritableRoot;
{$I ..\..\src\tr4w.inc}

(* A READ-ONLY INSTALL FOLDER (issue 165, 2026-11-20).

  NY4I installed TR4W in C:\Program Files\TR4W and ran it as a standard user:
  "could not open its log file", then a raw RTL exception when the setup
  wizard saved. These pin the parts a unit test can reach:

    * the decision, with the probe INJECTED -- a writable folder changes
      nothing and creates nothing; a refused one moves to <base>\TR4W\,
      created once; no base keeps today's answer and says why;
    * --settings still wins over the redirect;
    * the operator's notice is due once per per-user root;
    * the first redirected run carries the install's settings across and
      never overwrites one already there;
    * every written-file kind answers what its accessor answers, and the
      contest-log composition is plain string work (the same on every
      platform);
    * a settings save the disk refuses leaves the old file byte-identical,
      raises nothing, tells the operator once and logs the reason;
    * the diagnostic-log message names tr4w.log and says it is NOT the
      contest log.

  A real read-only install cannot be made here (a read-only attribute on a
  Windows directory does not stop a file being created in it); the bench
  steps are in docs/BENCH_QUEUE.md. *)

interface

uses
   SysUtils, Classes, uFileText, uTR4WTestFramework, uAppPaths,
   uTR4WConfigFile, uSettingsModel, uAppStrings;

type
   TWritableRootTests = class(TTestCase)
   private
      FScratch: string;
      function NewScratchDir(const aName: string): string;
   protected
      procedure Test_AWritableFolderChangesNothing;
      procedure Test_ARefusedFolderMovesUnderTheBase;
      procedure Test_NoBaseKeepsTodaysFolderAndSaysWhy;
      procedure Test_SettingsOverrideStillWins;
      procedure Test_TheNoticeIsDueOncePerRoot;
      procedure Test_TheFirstRunCarriesTheSettingsAcross;
      procedure Test_TheRealProbeLeavesNothingBehind;
      procedure Test_EveryKindAnswersItsAccessor;
      procedure Test_ExportsGoBesideTheContestLog;
      procedure Test_ARefusedSettingsSaveKeepsTheOldFile;
      procedure Test_TheLogMessageNamesTheDiagnosticLog;
   public
      constructor Create(const AName: string);
      destructor Destroy; override;
      procedure RunAllTests; override;
   end;

implementation

function ProbeSaysYes(const aDir: string): boolean;
begin
   Result := True;
end;

function ProbeSaysNo(const aDir: string): boolean;
begin
   Result := False;
end;

var
   GNoticeCount: integer = 0;
   GNoticeFile: string = '';

procedure CountNotice(const aFileName, aReason: string);
begin
   Inc(GNoticeCount);
   GNoticeFile := aFileName;
end;

procedure RemoveTree(const aDir: string);
var
   rec: TSearchRec;
   dir: string;
begin
   dir := IncludeTrailingPathDelimiter(aDir);
   if FindFirst(AnsiString(dir + '*'), faAnyFile, rec) = 0 then
      begin
      try
         repeat
            if (rec.Name = '.') or (rec.Name = '..') then
               begin
               Continue;
               end;
            if (rec.Attr and faDirectory) <> 0 then
               begin
               RemoveTree(dir + rec.Name);
               end
            else
               begin
               DeleteFile(dir + rec.Name);
               end;
         until FindNext(rec) <> 0;
      finally
         FindClose(rec);
      end;
      end;
   RemoveDir(aDir);
end;

constructor TWritableRootTests.Create(const AName: string);
begin
   inherited Create(AName);
   FScratch := IncludeTrailingPathDelimiter(
                  TempDirectory + 'tr4w_writableroot_' + TGUID.NewGuid.ToString);
   ForceDirectories(FScratch);
end;

destructor TWritableRootTests.Destroy;
begin
   RemoveTree(FScratch);
   inherited Destroy;
end;

function TWritableRootTests.NewScratchDir(const aName: string): string;
begin
   Result := IncludeTrailingPathDelimiter(FScratch + aName);
   ForceDirectories(Result);
end;

procedure TWritableRootTests.Test_AWritableFolderChangesNothing;
var
   install, base, root, problem: string;
   redirected, created: boolean;
begin
   BeginTest('Test_AWritableFolderChangesNothing');
   install := NewScratchDir('install-writable');
   base    := NewScratchDir('appdata-writable');
   root := ChooseWritableRoot(install, base, @ProbeSaysYes, redirected, created, problem);
   CheckEquals(install, root, 'a writable program folder is the answer, unchanged');
   CheckFalse(redirected, 'not redirected');
   CheckFalse(created, 'nothing created');
   CheckEquals('', problem, 'no problem');
   CheckFalse(DirectoryExists(base + 'TR4W'), 'no per-user folder was made');
end;

procedure TWritableRootTests.Test_ARefusedFolderMovesUnderTheBase;
var
   install, base, root, problem: string;
   redirected, created: boolean;
begin
   BeginTest('Test_ARefusedFolderMovesUnderTheBase');
   install := NewScratchDir('install-refused');
   base    := NewScratchDir('appdata-refused');
   root := ChooseWritableRoot(install, base, @ProbeSaysNo, redirected, created, problem);
   CheckEquals(base + 'TR4W' + PathDelim, root, 'the per-user root under the base');
   CheckTrue(redirected, 'redirected');
   CheckTrue(created, 'this call created the per-user root');
   CheckTrue(DirectoryExists(root), 'the per-user root exists');
   CheckEquals('', problem, 'no problem');

   root := ChooseWritableRoot(install, base, @ProbeSaysNo, redirected, created, problem);
   CheckTrue(redirected, 'still redirected on the next run');
   CheckFalse(created, 'and not created a second time');
end;

procedure TWritableRootTests.Test_NoBaseKeepsTodaysFolderAndSaysWhy;
var
   install, root, problem: string;
   redirected, created: boolean;
begin
   BeginTest('Test_NoBaseKeepsTodaysFolderAndSaysWhy');
   install := NewScratchDir('install-nobase');
   root := ChooseWritableRoot(install, '', @ProbeSaysNo, redirected, created, problem);
   CheckEquals(install, root, 'no APPDATA: the program folder, as before');
   CheckFalse(redirected, 'not redirected');
   CheckTrue(Pos('APPDATA', problem) > 0, 'the problem names APPDATA: ' + problem);
end;

procedure TWritableRootTests.Test_SettingsOverrideStillWins;
var
   named, redirectedDefault: string;
begin
   BeginTest('Test_SettingsOverrideStillWins');
   named := NewScratchDir('corpus-settings') + 'tr4w.json';
   redirectedDefault := NewScratchDir('appdata-default') + 'TR4W' + PathDelim
                        + 'settings' + PathDelim;
   CheckEquals(ExtractFilePath(named), WritableSettingsDirFor(named, redirectedDefault),
               '--settings names the folder even when the default is redirected');
   CheckEquals(redirectedDefault, WritableSettingsDirFor('', redirectedDefault),
               'no --settings: the default');
end;

procedure TWritableRootTests.Test_TheNoticeIsDueOncePerRoot;
var
   root: string;
begin
   BeginTest('Test_TheNoticeIsDueOncePerRoot');
   root := NewScratchDir('appdata-notice');
   CheckFalse(WritableRootNoticeDue(False, root), 'never due when not redirected');
   CheckTrue(WritableRootNoticeDue(True, root), 'due the first time');
   RecordWritableRootNotice(root, 'C:\Program Files\TR4W\');
   CheckTrue(FileExists(root + WRITABLE_ROOT_NOTE), 'the note is written');
   CheckFalse(WritableRootNoticeDue(True, root), 'not due once the note is there');
end;

procedure TWritableRootTests.Test_TheFirstRunCarriesTheSettingsAcross;
var
   install, root, copied: string;
   lines: TStringList;
begin
   BeginTest('Test_TheFirstRunCarriesTheSettingsAcross');
   install := NewScratchDir('install-seed');
   root    := NewScratchDir('appdata-seed');
   ForceDirectories(install + 'settings');
   ForceDirectories(root + 'settings');
   lines := TStringList.Create;
   try
      lines.Text := '{"from":"install"}';
      lines.SaveToFile(AnsiString(install + 'settings' + PathDelim + 'tr4w.json'));
      lines.Text := 'pos';
      lines.SaveToFile(AnsiString(install + 'settings' + PathDelim + 'tr4w.pos'));
      lines.Text := 'already here';
      lines.SaveToFile(AnsiString(root + 'settings' + PathDelim + 'tr4w.pos'));

      copied := SeedPerUserSettings(install, root);
      CheckEquals('tr4w.json', copied, 'only the file the root did not have');
      lines.LoadFromFile(AnsiString(root + 'settings' + PathDelim + 'tr4w.json'));
      CheckEquals('{"from":"install"}', Trim(lines.Text), 'the settings came across');
      lines.LoadFromFile(AnsiString(root + 'settings' + PathDelim + 'tr4w.pos'));
      CheckEquals('already here', Trim(lines.Text), 'an existing file is never overwritten');
      CheckTrue(FileExists(install + 'settings' + PathDelim + 'tr4w.json'),
                'the install''s copy is left where it was');
      CheckEquals('', SeedPerUserSettings(install, root), 'a second seed copies nothing');
   finally
      lines.Free;
   end;
end;

procedure TWritableRootTests.Test_TheRealProbeLeavesNothingBehind;
var
   dir: string;
   rec: TSearchRec;
   found: integer;
begin
   BeginTest('Test_TheRealProbeLeavesNothingBehind');
   dir := NewScratchDir('probe');
   CheckTrue(DirectoryIsWritable(dir), 'a temp folder accepts a file');
   found := 0;
   if FindFirst(AnsiString(dir + '*'), faAnyFile, rec) = 0 then
      begin
      try
         repeat
            if (rec.Name <> '.') and (rec.Name <> '..') then
               begin
               Inc(found);
               end;
         until FindNext(rec) <> 0;
      finally
         FindClose(rec);
      end;
      end;
   CheckEquals(0, found, 'the probe deleted its file');
   CheckFalse(DirectoryIsWritable(dir + 'no-such-folder'), 'a missing folder is not writable');
   CheckFalse(DirectoryIsWritable(''), 'no folder is not writable');
end;

procedure TWritableRootTests.Test_EveryKindAnswersItsAccessor;
begin
   BeginTest('Test_EveryKindAnswersItsAccessor');
   (* Platform-neutral: on every platform each kind must be its accessor, so
     routing a writer through WrittenFilePath can never move a file. *)
   CheckEquals(IncludeTrailingPathDelimiter(SettingsDir), WrittenFileDir(wfSettings), 'settings');
   CheckEquals(IncludeTrailingPathDelimiter(LogDir), WrittenFileDir(wfDiagnosticLog), 'diagnostic log');
   CheckEquals(IncludeTrailingPathDelimiter(LogDir), WrittenFileDir(wfCrashLog), 'crash log');
   CheckEquals(IncludeTrailingPathDelimiter(ContestDir), WrittenFileDir(wfContestLog), 'contest log');
   CheckEquals(IncludeTrailingPathDelimiter(BackupDir), WrittenFileDir(wfBackup), 'backup');
   CheckEquals(IncludeTrailingPathDelimiter(DownloadedDataDir), WrittenFileDir(wfDownload), 'download');
   CheckEquals(IncludeTrailingPathDelimiter(StationStateDir), WrittenFileDir(wfStationState), 'station state');
   CheckEquals(WrittenFileDir(wfStationState) + 'bandmap.bin',
               WrittenFilePath(wfStationState, 'bandmap.bin'), 'the path is the folder plus the name');
{$IFNDEF WINDOWS}
   (* Off Windows the old station-state files stay exactly where
     TR4W_PATH_NAME (DataDir) put them. *)
   CheckEquals(IncludeTrailingPathDelimiter(DataDir), WrittenFileDir(wfStationState),
               'off Windows the station state is DataDir, unchanged');
   CheckFalse(WritableFilesRedirected, 'off Windows nothing is ever redirected');
   CheckEquals('', WritableFilesRoot, 'off Windows there is no single root');
{$ELSE}
   (* The test binary runs from a writable folder: nothing moves. *)
   CheckFalse(WritableFilesRedirected, 'the test folder is writable, so not redirected');
   CheckEquals(IncludeTrailingPathDelimiter(GetCurrentDir), WritableFilesRoot,
               'and the root is the working directory, as before');
   CheckEquals(DataDir, StationStateDir, 'station state is the program folder, as before');
{$ENDIF}
end;

procedure TWritableRootTests.Test_ExportsGoBesideTheContestLog;
begin
   BeginTest('Test_ExportsGoBesideTheContestLog');
   CheckEquals('/home/op/tr4w/a.adi', BesideContestLogFilePath('/home/op/tr4w/a.db', 'a.adi'),
               'a Unix-spelled log');
   CheckEquals('C:\Users\op\AppData\Roaming\TR4W\a.log',
               BesideContestLogFilePath('C:\Users\op\AppData\Roaming\TR4W\a.db', 'a.log'),
               'a redirected Windows log takes its exports with it');
   CheckEquals('a.log', BesideContestLogFilePath('a.db', 'a.log'),
               'a bare name stays a bare name');
end;

procedure TWritableRootTests.Test_ARefusedSettingsSaveKeepsTheOldFile;
var
   dir, fn, before, after: string;
   settings: TR4WSettings;
   saved, escaped: boolean;
begin
   BeginTest('Test_ARefusedSettingsSaveKeepsTheOldFile');
   dir := NewScratchDir('refused-save');
   fn  := dir + 'tr4w.json';
   WriteAllTextUTF8(fn, '{"settings":{"marker":"the old file"}}');
   before := ReadAllTextUTF8(fn);

   (* A FOLDER WHERE THE .new FILE MUST GO: creating the file fails exactly
     as an access-denied folder does, and a unit test can make it. *)
   ForceDirectories(fn + '.new');

   GNoticeCount := 0;
   ForgetConfigWriteNotice;
   SetConfigWriteNotice(CountNotice);
   settings := TR4WSettings.Create;
   try
      escaped := False;
      saved   := True;
      try
         saved := SaveSettings(fn, settings);
         SaveSettings(fn, settings);
      except
         on E: Exception do
            begin
            escaped := True;
            end;
      end;
      CheckFalse(escaped, 'no exception escaped the refused save');
      CheckFalse(saved, 'the save answered False');
      after := ReadAllTextUTF8(fn);
      CheckEquals(before, after, 'the previous file is byte-identical');
      CheckEquals(1, GNoticeCount, 'two failures, one notice');
      CheckEquals(fn, GNoticeFile, 'the notice names the file');
      CheckTrue(LastConfigWriteFailure <> '', 'the reason is kept: ' + LastConfigWriteFailure);
   finally
      settings.Free;
      SetConfigWriteNotice(nil);
      ForgetConfigWriteNotice;
      RemoveDir(fn + '.new');
   end;

   (* And once the folder is fixed, a save works and clears the reason. *)
   settings := TR4WSettings.Create;
   try
      CheckTrue(SaveSettings(fn, settings), 'a save into a writable folder works');
      CheckEquals('', LastConfigWriteFailure, 'and clears the reason');
   finally
      settings.Free;
   end;
end;

procedure TWritableRootTests.Test_TheLogMessageNamesTheDiagnosticLog;
var
   text: string;
begin
   BeginTest('Test_TheLogMessageNamesTheDiagnosticLog');
   text := UnicodeFormat(SDiagnosticLogUnavailable, ['Access is denied', 'C:\somewhere\']);
   CheckTrue(Pos('diagnostic log', text) > 0, 'it says diagnostic log');
   CheckTrue(Pos('tr4w.log', text) > 0, 'it names tr4w.log');
   CheckTrue(Pos('NOT your contest log', text) > 0, 'it says it is not the contest log');
   CheckTrue(Pos('its log file', text) = 0, 'the ambiguous old wording is gone');
   CheckTrue(Pos('C:\somewhere\', text) > 0, 'it names the folder TR4W writes to');
   CheckTrue(Pos('Access is denied', text) > 0, 'it carries the system''s reason');
   text := UnicodeFormat(SSettingsNotSaved, ['C:\x\tr4w.json', 'Access is denied']);
   CheckTrue(Pos('C:\x\tr4w.json', text) > 0, 'the settings notice names the file');
   CheckTrue(Pos('was not changed', text) > 0, 'and says the file on disk was not changed');
   text := UnicodeFormat(SWritableRootMoved, ['C:\Program Files\TR4W\', 'C:\AppData\TR4W\']);
   CheckTrue((Pos('C:\Program Files\TR4W\', text) > 0) and (Pos('C:\AppData\TR4W\', text) > 0),
             'the move notice names both folders');
end;

procedure TWritableRootTests.RunAllTests;
begin
   Test_AWritableFolderChangesNothing;
   Test_ARefusedFolderMovesUnderTheBase;
   Test_NoBaseKeepsTodaysFolderAndSaysWhy;
   Test_SettingsOverrideStillWins;
   Test_TheNoticeIsDueOncePerRoot;
   Test_TheFirstRunCarriesTheSettingsAcross;
   Test_TheRealProbeLeavesNothingBehind;
   Test_EveryKindAnswersItsAccessor;
   Test_ExportsGoBesideTheContestLog;
   Test_ARefusedSettingsSaveKeepsTheOldFile;
   Test_TheLogMessageNamesTheDiagnosticLog;
end;

end.
