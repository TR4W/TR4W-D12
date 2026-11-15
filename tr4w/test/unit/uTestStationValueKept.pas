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
unit uTestStationValueKept;
{$I ..\..\src\tr4w.inc}

(*
  A CONTEST'S VALUE NEVER REACHES settings\tr4w.json (NY4I, 2026-11-15).

  NE4C operates at NY4I's house: the station stays NY4I, the contest's MY CALL
  is NE4C. When a contest states a station-scoped setting the station's value
  is KEPT (TR4WSettings.KeepStationValue), and ToJSON -- every writer of the
  settings section -- writes the kept value. A Preferences edit meanwhile is
  the STATION'S: it replaces the kept value and leaves the contest's live
  value alone. A contest-parameter edit (Tools > Edit Cabrillo Summary,
  uCFG.ApplyContestEdit) is the CONTEST'S and writes nothing to the file.
  The exit save writes the whole object; a derived zone or country is not
  written.

  EVERY FILE IS THIS TEST'S OWN. The program's settings file is redirected
  into a temp folder, and a test that would save there refuses to run unless
  TR4WConfigFileName really landed in it (a --settings switch would win).
*)

interface

uses
   uTR4WTestFramework;

type
   TStationValueKeptTests = class(TTestCase)
   private
      FDir: string;
      FOldIni: string;
      FSavedCall: string;
      FSavedZeros: string;
      FSavedOperator: string;
      FOperatorWasStated: boolean;
      function Redirect: boolean;
      procedure Restore;
      procedure Test_AContestCallNeverReachesTheFile;
      procedure Test_ACfgLeadingZerosDoesNotReachTheFile;
      procedure Test_APreferencesEditDuringTheContestChangesOnlyTheStation;
      procedure Test_ADerivedZoneOrCountryIsNotWritten;
      procedure Test_TheExitSaveWritesWhatNoDoorSaved;
      procedure Test_ASaveWithNothingHeldIsUnchanged;
      procedure Test_AContestParameterEditLeavesTheFileAlone;
      procedure Test_AToggleOfAStatedSettingIsTheStations;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   TF,
   LogCfg,
   uCFG,
   uSettingsModel,
   uTR4WConfigFile,
   uRadioConfigApply,
   utils_text;

function CurrentValue(const aCommand: string): string;
begin
   if not Settings.TryGetByCommand(aCommand, Result) then
      begin
      Result := '';
      end;
end;

function FileBytes(const aPath: string): RawByteString;
var
   fs: TFileStream;
begin
   Result := '';
   if not FileExists(aPath) then
      begin
      Exit;
      end;
   fs := TFileStream.Create(AnsiString(aPath), fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, fs.Size);
      if fs.Size > 0 then
         begin
         fs.ReadBuffer(Result[1], fs.Size);
         end;
   finally
      fs.Free;
   end;
end;

procedure WriteBytes(const aPath: string; const aBytes: RawByteString);
var
   fs: TFileStream;
begin
   fs := TFileStream.Create(AnsiString(aPath), fmCreate);
   try
      if Length(aBytes) > 0 then
         begin
         fs.WriteBuffer(aBytes[1], Length(aBytes));
         end;
   finally
      fs.Free;
   end;
end;

(* What the FILE says for a command: a fresh object, the section alone. *)
function FileValue(const aFile, aCommand: string): string;
var
   fresh: TR4WSettings;
begin
   Result := '';
   fresh := TR4WSettings.Create;
   try
      LoadSettingsSection(aFile, fresh);
      if not fresh.TryGetByCommand(aCommand, Result) then
         begin
         Result := '';
         end;
   finally
      fresh.Free;
   end;
end;

function TStationValueKeptTests.Redirect: boolean;
var
   fn: string;
begin
   FDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4wkept_' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   FOldIni := CharBufferText(TR4W_INI_FILENAME);
   SetCharBuffer(TR4W_INI_FILENAME, FDir + 'tr4w.ini');
   fn := TR4WConfigFileName;
   Result := Pos(FDir, fn) = 1;
   if not Result then
      begin
      CheckTrue(False, 'the settings file was not redirected (' + fn +
                       ') -- a --settings switch? This check is skipped');
      SetCharBuffer(TR4W_INI_FILENAME, FOldIni);
      Exit;
      end;
   DeleteFile(fn);

   (* A CLEAN START: no statement of an earlier suite is held, and the
     station's values are put back afterwards. *)
   ClearContestCFGCommands;
   FSavedCall := Settings.My.Call;
   FSavedZeros := CurrentValue('LEADING ZEROS');
   FSavedOperator := CurrentValue('CATEGORY-OPERATOR');
   FOperatorWasStated := Settings.CommandIsStated('CATEGORY-OPERATOR');
end;

procedure TStationValueKeptTests.Restore;
begin
   ClearContestCFGCommands;
   Settings.My.Call := FSavedCall;
   Settings.TrySetByCommand('LEADING ZEROS', FSavedZeros);
   Settings.TrySetByCommand('CATEGORY-OPERATOR', FSavedOperator);
   Settings.SetCommandStated('CATEGORY-OPERATOR', FOperatorWasStated);
   DeleteFile(TR4WConfigFileName);
   SetCharBuffer(TR4W_INI_FILENAME, FOldIni);
   RemoveDir(FDir);
end;

(* (1) THE NE4C CASE. *)
procedure TStationValueKeptTests.Test_AContestCallNeverReachesTheFile;
var
   fn: string;
begin
   BeginTest('a contest''s MY CALL never reaches tr4w.json; the station''s does');
   if not Redirect then
      begin
      Exit;
      end;
   try
      fn := TR4WConfigFileName;
      Settings.My.Call := 'NY4I';
      SaveSettings(fn, Settings);
      CheckEquals('NY4I', FileValue(fn, 'MY CALL'), 'the station is NY4I');

      (* The log's MY CALL hoist, a .cfg line and the New Contest club call
        all come through here. *)
      CheckTrue(ApplyContestStatement('MY CALL', 'NE4C'), 'the contest states NE4C');
      CheckEquals('NE4C', Settings.My.Call, 'the contest operates NE4C');
      CheckTrue(Settings.StationValueIsKept('MY CALL'), 'the station''s call is kept');

      SaveSettings(fn, Settings);
      CheckEquals('NY4I', FileValue(fn, 'MY CALL'), 'a save writes the station''s call');
      CheckEquals('NE4C', Settings.My.Call, 'and the contest still operates NE4C');

      (* A second statement keeps nothing new: the kept value is the station's,
        not the first contest value. *)
      CheckTrue(ApplyContestStatement('MY CALL', 'W4AFC'), 'a second statement');
      SaveSettings(fn, Settings);
      CheckEquals('NY4I', FileValue(fn, 'MY CALL'), 'still the station''s call');

      (* The contest's configuration starts afresh: the station's call is back
        in force and nothing is held. *)
      ClearContestCFGCommands;
      CheckEquals('NY4I', Settings.My.Call, 'the station''s call is live again');
      CheckFalse(Settings.StationValueIsKept('MY CALL'), 'nothing kept');
   finally
      Restore;
   end;
end;

(* (2) A .cfg LINE, THROUGH THE REAL .cfg READER. *)
procedure TStationValueKeptTests.Test_ACfgLeadingZerosDoesNotReachTheFile;
var
   fn, cfg, station, stated: string;
   savedFile: TCFGType;
   savedLine: integer;
begin
   BeginTest('a .cfg-stated LEADING ZEROS is in force and is not written to tr4w.json');
   if not Redirect then
      begin
      Exit;
      end;
   savedFile := CurrentConfigFile;
   savedLine := LineNumberInConfigFile;
   cfg := FDir + 'contest.cfg';
   try
      fn := TR4WConfigFileName;
      Settings.My.Call := 'NY4I';
      CheckTrue(Settings.TrySetByCommand('LEADING ZEROS', '1'), 'the station pads to 1');
      station := CurrentValue('LEADING ZEROS');
      SaveSettings(fn, Settings);
      stated := '3';

      (* MY CALL FIRST: the reader halts on a .cfg whose first line is not. *)
      WriteBytes(cfg, 'MY CALL = NY4I'#13#10'LEADING ZEROS = ' +
                      RawByteString(stated) + #13#10);
      CurrentConfigFile := cfgCFG;
      LineNumberInConfigFile := 0;
      CheckTrue(EnumerateTextLinesInFile(cfg, EnmuCFGFile, True), 'the .cfg is read');
      CheckEquals(stated, CurrentValue('LEADING ZEROS'), 'the contest''s value is in force');

      SaveSettings(fn, Settings);
      CheckEquals(station, FileValue(fn, 'LEADING ZEROS'), 'the file keeps the station''s');
   finally
      CurrentConfigFile := savedFile;
      LineNumberInConfigFile := savedLine;
      DeleteFile(cfg);
      Restore;
   end;
end;

(* (3) DECISION E: the zip code on the application template. *)
procedure TStationValueKeptTests.Test_APreferencesEditDuringTheContestChangesOnlyTheStation;
var
   fn, shown: string;
begin
   BeginTest('a Preferences edit during the NE4C contest changes the station, not the contest');
   if not Redirect then
      begin
      Exit;
      end;
   try
      fn := TR4WConfigFileName;
      Settings.My.Call := 'NY4I';
      SaveSettings(fn, Settings);
      CheckTrue(ApplyContestStatement('MY CALL', 'NE4C'), 'the contest states NE4C');

      (* WHAT THE DOORS SHOW is the station's call, so re-applying a shown
        value can never make the contest's call the station's. *)
      CheckEquals('NY4I', StationCommandValue(nil, 'MY CALL'),
                  'the Station page and the wizard show the station''s call');
      CheckTrue(ApplyAndStoreCommand(nil, 'MY CALL', StationCommandValue(nil, 'MY CALL')),
                'the shown value applied back');
      CheckEquals('NY4I', FileValue(fn, 'MY CALL'), 'leaves the file at NY4I');
      CheckEquals('NE4C', Settings.My.Call, 'and the contest at NE4C');

      (* The Station page's door; it saves. *)
      CheckTrue(ApplyAndStoreCommand(nil, 'MY CALL', 'K1ABC'), 'the station edit is taken');
      CheckEquals('K1ABC', FileValue(fn, 'MY CALL'), 'the file has the new station call');
      CheckEquals('NE4C', Settings.My.Call, 'the open contest still operates NE4C');

      (* The registry-bound Preferences door (TModelSetting.TrySetText) calls
        this, then SaveSettings. *)
      CheckTrue(Settings.TrySetStationValue('MY CALL', 'K2XYZ'), 'the bound control''s edit');
      SaveSettings(fn, Settings);
      CheckEquals('K2XYZ', FileValue(fn, 'MY CALL'), 'the file has that one');
      CheckTrue(Settings.TryGetStationValue('MY CALL', shown), 'the bound control reads it');
      CheckEquals('K2XYZ', shown, 'and shows the station''s call (TModelSetting.AsText)');
      CheckEquals('NE4C', Settings.My.Call, 'and the contest is still NE4C');

      (* A refused value changes neither. *)
      CheckFalse(Settings.TrySetStationValue('LEADING ZEROS', '99'), 'out of range');

      (* When the contest's configuration starts afresh, the STATION'S value --
        the edited one -- is what comes back. *)
      ClearContestCFGCommands;
      CheckEquals('K2XYZ', Settings.My.Call, 'the edited station call is live again');

      (* With nothing held, the door is exactly what it was. *)
      CheckTrue(ApplyAndStoreCommand(nil, 'MY CALL', 'NY4I'), 'an ordinary station edit');
      CheckEquals('NY4I', Settings.My.Call, 'applied live');
      CheckEquals('NY4I', FileValue(fn, 'MY CALL'), 'and saved');
   finally
      Restore;
   end;
end;

(* (4) DECISION F. *)
procedure TStationValueKeptTests.Test_ADerivedZoneOrCountryIsNotWritten;
var
   s, fresh: TR4WSettings;
   fn: string;
begin
   BeginTest('a derived zone or country is not written, a stated one is, and a reload latches neither');
   fn := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4wkept_zone_' +
         IntToStr(GetProcessID) + '.json';
   s := TR4WSettings.Create;
   fresh := TR4WSettings.Create;
   try
      s.My.DeriveZone('15');
      s.My.DeriveCountry('K');
      SaveSettings(fn, s);
      LoadSettingsSection(fn, fresh);
      CheckEquals('', fresh.My.Zone, 'a derived zone is not written');
      CheckEquals('', fresh.My.Country, 'a derived country is not written');
      CheckFalse(fresh.My.ZoneWasSet, 'and the reload does not latch the zone');
      CheckFalse(fresh.My.CountryWasSet, 'nor the country');
      CheckEquals('15', s.My.Zone, 'the derived zone stays in force for the session');

      s.My.Zone := '5';
      SaveSettings(fn, s);
      fresh.Free;
      fresh := TR4WSettings.Create;
      LoadSettingsSection(fn, fresh);
      CheckEquals('5', fresh.My.Zone, 'a stated zone is written');
      CheckTrue(fresh.My.ZoneWasSet, 'and reads back as stated');
   finally
      fresh.Free;
      s.Free;
      DeleteFile(fn);
   end;
end;

(* (5) DECISION C, plus a run-time force's station half. *)
procedure TStationValueKeptTests.Test_TheExitSaveWritesWhatNoDoorSaved;
var
   s, fresh: TR4WSettings;
   fn: string;
   allBands: boolean;
begin
   BeginTest('the exit save writes a toggle no door saved, and a forced value''s station half');
   fn := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4wkept_exit_' +
         IntToStr(GetProcessID) + '.json';
   s := TR4WSettings.Create;
   fresh := TR4WSettings.Create;
   try
      s.BandMap.So2rDisplay := True;
      SaveSettings(fn, s);
      LoadSettingsForStartup(fn, s, True);

      allBands := s.BandMap.AllBands;
      s.BandMap.AllBands := not allBands;   (* assigned, never saved *)

      (* SO2R off because radio 2 has no frequency (uBandmap). *)
      s.KeepStationValue('BAND MAP SO2R DISPLAY', True);
      s.BandMap.So2rDisplay := False;

      SaveSettingsAtExit(fn, s);
      LoadSettingsSection(fn, fresh);
      CheckTrue((not allBands) = fresh.BandMap.AllBands, 'the unsaved toggle is in the file');
      CheckTrue(fresh.BandMap.So2rDisplay, 'the operator''s SO2R display, not the forced off');

      (* A station edit of a forced value follows live too. *)
      CheckTrue(s.TrySetStationValue('BAND MAP SO2R DISPLAY', 'FALSE'), 'the station edit');
      CheckFalse(s.BandMap.So2rDisplay, 'live');
      SaveSettings(fn, s);
      fresh.Free;
      fresh := TR4WSettings.Create;
      LoadSettingsSection(fn, fresh);
      CheckFalse(fresh.BandMap.So2rDisplay, 'and the file');

      (* A forced entry survives the contest's fresh start. *)
      s.RevertKeptStationValues;
      CheckTrue(s.StationValueIsKept('BAND MAP SO2R DISPLAY'), 'still kept');
   finally
      fresh.Free;
      s.Free;
      DeleteFile(fn);
   end;
end;

(* (6) NOTHING HELD, NOTHING CHANGED -- and a value kept equal to the live one
  writes the same bytes, member order included. Zone and country are stated
  (empty), so decision F does not enter into it. *)
procedure TStationValueKeptTests.Test_ASaveWithNothingHeldIsUnchanged;
var
   s: TR4WSettings;
   fn: string;
   before, after: RawByteString;
begin
   BeginTest('a save with nothing held is unchanged, byte for byte');
   fn := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4wkept_same_' +
         IntToStr(GetProcessID) + '.json';
   s := TR4WSettings.Create;
   try
      CheckTrue(s.TrySetByCommand('LEADING ZEROS', '2'), 'an ordinary setting');
      s.My.Call := 'NY4I';
      SaveSettings(fn, s);
      before := FileBytes(fn);

      s.KeepStationValue('LEADING ZEROS');
      s.KeepStationValue('MY CALL');
      SaveSettings(fn, s);
      after := FileBytes(fn);
      CheckTrue(before = after, 'kept values equal to the live ones write the same bytes');

      s.RevertKeptStationValues;
      SaveSettings(fn, s);
      after := FileBytes(fn);
      CheckTrue(before = after, 'and so does the object after the revert');
      CheckEquals('2', FileValue(fn, 'LEADING ZEROS'), 'the value itself');
   finally
      s.Free;
      DeleteFile(fn);
   end;
end;

(* NY4I'S CLARIFICATION: Tools > Edit Cabrillo Summary edits the CONTEST. *)
procedure TStationValueKeptTests.Test_AContestParameterEditLeavesTheFileAlone;
var
   fn, choice: string;
   before: RawByteString;
begin
   BeginTest('a contest-parameter edit changes the contest and leaves tr4w.json alone');
   if not Redirect then
      begin
      Exit;
      end;
   try
      fn := TR4WConfigFileName;
      Settings.My.Call := 'NY4I';
      SaveSettings(fn, Settings);
      before := FileBytes(fn);

      choice := 'MULTI-OP';
      if CurrentValue('CATEGORY-OPERATOR') = choice then
         begin
         choice := 'SINGLE-OP';
         end;
      (* The summary window's category row. *)
      CheckTrue(ApplyContestEdit('CATEGORY-OPERATOR', choice), 'the category edit is taken');
      CheckEquals(choice, CurrentValue('CATEGORY-OPERATOR'), 'the contest''s value changed');
      CheckTrue(Settings.CommandIsStated('CATEGORY-OPERATOR'), 'as the operator''s statement');
      CheckTrue(before = FileBytes(fn), 'nothing was written to tr4w.json');

      (* And a station-scoped value through the same door is the contest's. *)
      CheckTrue(ApplyContestEdit('MY CALL', 'NE4C'), 'MY CALL for this contest');
      CheckEquals('NE4C', Settings.My.Call, 'in force');
      CheckTrue(before = FileBytes(fn), 'still nothing written');

      (* Nor by the next save of anything else. *)
      SaveSettings(fn, Settings);
      CheckTrue(before = FileBytes(fn), 'a later save writes the station''s values unchanged');
   finally
      Restore;
   end;
end;

(* NY4I, 2026-11-15: a band-map toggle on a setting the contest states changes
  the live value AND the station's. *)
procedure TStationValueKeptTests.Test_AToggleOfAStatedSettingIsTheStations;
var
   fn, savedAllBands: string;
begin
   BeginTest('a band-map toggle of a contest-stated setting changes the live and the station value');
   if not Redirect then
      begin
      Exit;
      end;
   savedAllBands := CurrentValue('BAND MAP ALL BANDS');
   try
      fn := TR4WConfigFileName;
      CheckTrue(Settings.TrySetByCommand('BAND MAP ALL BANDS', 'FALSE'), 'the station: off');
      SaveSettings(fn, Settings);
      CheckTrue(ApplyContestStatement('BAND MAP ALL BANDS', 'FALSE'), 'the contest states off');
      CheckTrue(Settings.StationValueIsKept('BAND MAP ALL BANDS'), 'the station value is kept');

      CheckTrue(ToggleAndStoreCommand('BAND MAP ALL BANDS'), 'the B hotkey');
      CheckEquals('TRUE', CurrentValue('BAND MAP ALL BANDS'), 'live is on');
      CheckEquals('TRUE', FileValue(fn, 'BAND MAP ALL BANDS'), 'and the file is on');

      SaveSettings(fn, Settings);
      CheckEquals('TRUE', FileValue(fn, 'BAND MAP ALL BANDS'), 'and stays on at the next save');
   finally
      Restore;
      Settings.TrySetByCommand('BAND MAP ALL BANDS', savedAllBands);
   end;
end;

procedure TStationValueKeptTests.RunAllTests;
begin
   Test_AContestCallNeverReachesTheFile;
   Test_ACfgLeadingZerosDoesNotReachTheFile;
   Test_APreferencesEditDuringTheContestChangesOnlyTheStation;
   Test_ADerivedZoneOrCountryIsNotWritten;
   Test_TheExitSaveWritesWhatNoDoorSaved;
   Test_ASaveWithNothingHeldIsUnchanged;
   Test_AContestParameterEditLeavesTheFileAlone;
   Test_AToggleOfAStatedSettingIsTheStations;
end;

end.
