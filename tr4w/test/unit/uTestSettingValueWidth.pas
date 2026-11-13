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

(* A SETTING'S VALUE ARRIVES WHOLE -- issue 302, 2026-11-12.

  Every route a value took to the settings object went through
  CheckCommand(ShortString, ShortString), and each caller narrowed its command
  and value to fit: a value longer than 255 characters was cut in silence,
  and the value passed through AnsiString on the way. The contest .cfg was
  cut once more, earlier, by the line reader. CheckCommand takes strings now,
  the callers pass what they hold, the .cfg is read as string lines, and the
  settings object reads and writes a string property without an AnsiString
  hop.

  WHAT IS PINNED HERE, one route each:
    - CheckCommand, ApplyContestStatement, ApplyAndStoreCommand's contest arm
      and ApplyStoredCommands keep a 300-character value;
    - a name in three scripts (e-acute, Cyrillic, Chinese) survives the
      Preferences save (the call ApplyAndStoreCommand makes, then the settings
      file written and read back);
    - a contest .cfg keeps a 300-character line and the same name, upper-cased
      in ASCII only, as the .cfg reader always did;
    - a contest log's stored rows come back whole on open and are captured
      whole at close;
    - a refused value leaves the old one in place;
    - the two places that really are 255 bytes -- the multi-op parameter
      packet and the message editor -- answer "does not fit" for what they
      cannot hold, so the caller refuses instead of cutting.

  NOT DRIVEN HERE, and why: SetCFGCommandValue and ApplyPeerCommand persist
  through the radio store FILE, and ApplyAndStoreCommand saves the station
  settings file for an owned station setting -- both real files of the
  running program. They call the same CheckCommand with the strings they
  were given, which is what these tests pin. *)
unit uTestSettingValueWidth;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSettingValueWidthTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheTestProgramDecodesAsUTF8;
      procedure Test_EveryCommandRouteKeepsALongValue;
      procedure Test_ARefusedValueLeavesTheOldOne;
      procedure Test_ANonAsciiNameSurvivesThePreferencesSave;
      procedure Test_TheTextLineReaderDoesNotCut;
      procedure Test_AContestCfgKeepsALongValueAndANonAsciiName;
      procedure Test_AContestLogKeepsThemThroughOpenAndClose;
      procedure Test_TheWireAndTheMessageEditorSayWhatTheyHold;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   TF,
   LogCfg,
   uCFG,
   uNet,
   uEditMessageForm,
   uKeychain,
   uSettingsModel,
   uTR4WConfigFile,
   uRadioConfigStore,
   uRadioConfigApply,
   uContestRegistry,
   uLogDatabase,
   uLogRepository,
   uLogStore,
   utils_text,           (* CharBufferText / SetCharBuffer *)
   uTestLatestContest;   (* MakeTestContestLog / ScrubTestLog *)

const
   CALL_HISTORY = 'CALL HISTORY FILENAME';
   TAILCAT      = 'SERVER TAILCAT ADDRESS';
   MY_NAME      = 'MY NAME';

(* A name in three scripts: Latin with an e-acute, Cyrillic Zhe, and a
  Chinese character -- built from code points so the source file's encoding
  cannot change it. *)
function ThreeScriptName: string;
begin
   Result := 'Jos' + WideChar($00E9) + ' ' + WideChar($0416) + ' ' + WideChar($4E2D);
end;

(* What the .cfg reader makes of it: 'a'..'z' upper-cased, nothing else. *)
function ThreeScriptNameUpperCasedAsCfg: string;
begin
   Result := 'JOS' + WideChar($00E9) + ' ' + WideChar($0416) + ' ' + WideChar($4E2D);
end;

function LongValue(const aLetter: char): string;
begin
   Result := 'LONG' + StringOfChar(aLetter, 296);
end;

function CurrentValue(const aCommand: string): string;
begin
   if not Settings.TryGetByCommand(aCommand, Result) then
      begin
      Result := '';
      end;
end;

function TempPath(const aLeaf: string): string;
begin
   Result := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'tr4w_302_' +
             IntToStr(GetProcessID) + '_' + aLeaf;
end;

(* Writes aBytes exactly -- no line-ending translation, no encoding. *)
procedure WriteBytesFile(const aPath: string; const aBytes: RawByteString);
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

(* aCount copies of a UnicodeString character. *)
function Repeated(const aChar: WideChar; aCount: integer): string;
var
   i: integer;
begin
   Result := '';
   for i := 1 to aCount do
      begin
      Result := Result + aChar;
      end;
end;

var
   (* Strings, not a TStringList, so nothing on the way is an AnsiString. *)
   GTextLines: array of string;
   GShortLines: array of ShortString;

procedure CollectTextLine(var aLine: string);
begin
   SetLength(GTextLines, Length(GTextLines) + 1);
   GTextLines[High(GTextLines)] := aLine;
end;

procedure CollectShortLine(var aLine: ShortString);
begin
   SetLength(GShortLines, Length(GShortLines) + 1);
   GShortLines[High(GShortLines)] := aLine;
end;

(* ------------------------------------------------------------------------ *)

procedure TSettingValueWidthTests.Test_TheTestProgramDecodesAsUTF8;
begin
   (* THE PREMISE OF EVERY NON-ASCII CHECK BELOW. A line of a file and a
     ShortString are decoded by DefaultSystemCodePage; the LCL sets it to
     UTF-8 (65001) in the program, and this binary links the LCL too. If this
     fails, the failures below are about this binary, not the program. *)
   BeginTest('the test program decodes 8-bit text as UTF-8, as the program does');
   CheckEquals(65001, integer(DefaultSystemCodePage), 'DefaultSystemCodePage');
end;

procedure TSettingValueWidthTests.Test_EveryCommandRouteKeepsALongValue;
var
   saved: string;
   wasStated: boolean;
   store: TRadioConfigStore;
begin
   BeginTest('CheckCommand, ApplyContestStatement, ApplyAndStoreCommand and ' +
             'ApplyStoredCommands keep a 300-character value whole');
   saved := CurrentValue(CALL_HISTORY);
   wasStated := Settings.CommandIsStated(CALL_HISTORY);
   store := TRadioConfigStore.Create;
   try
      (* CheckCommand, as the trusted callers call it: the log replay, the
        Preferences save, the message editor's template arm. *)
      CheckTrue(CheckCommand(CALL_HISTORY, LongValue('A'), True), 'CheckCommand accepts it');
      CheckEquals(300, Length(CurrentValue(CALL_HISTORY)), 'CheckCommand: 300, not 255');
      CheckEquals(LongValue('A'), CurrentValue(CALL_HISTORY), 'CheckCommand: the same text');

      (* The .cfg / New Contest / log-row route for a command that is not a
        station fact. *)
      CheckTrue(ApplyContestStatement(CALL_HISTORY, LongValue('B')), 'ApplyContestStatement accepts it');
      CheckEquals(LongValue('B'), CurrentValue(CALL_HISTORY), 'ApplyContestStatement: whole');

      (* Preferences' and a peer's route for a contest-scoped command -- the
        arm that still narrowed after issue 293. A nil store: nothing is
        written anywhere. *)
      CheckTrue(ApplyAndStoreCommand(nil, CALL_HISTORY, LongValue('C')),
                'ApplyAndStoreCommand accepts it');
      CheckEquals(LongValue('C'), CurrentValue(CALL_HISTORY), 'ApplyAndStoreCommand: whole');

      (* The legacy bucket's contest-scoped entry, applied unstated. *)
      Settings.SetCommandStated(CALL_HISTORY, False);
      store.Commands.Values[AnsiString(CALL_HISTORY)] := AnsiString(LongValue('D'));
      ApplyStoredCommands(store);
      CheckEquals(LongValue('D'), CurrentValue(CALL_HISTORY), 'ApplyStoredCommands: whole');
   finally
      store.Free;
      Settings.TrySetByCommand(CALL_HISTORY, saved);
      Settings.SetCommandStated(CALL_HISTORY, wasStated);
   end;
end;

procedure TSettingValueWidthTests.Test_ARefusedValueLeavesTheOldOne;
var
   saved, kept, tooLong: string;
   savedZone: integer;
begin
   BeginTest('a value a setting refuses leaves the old one in place, on every route');
   InstallTestKeychain;
   saved := string(Settings.Server.TailcatAddress);
   kept := 'tc' + StringOfChar('k', 298);
   tooLong := 'tc' + StringOfChar('y', TAILCAT_ADDRESS_MAX_LENGTH - 1);
   try
      CheckTrue(ApplyOwnedSetting(TAILCAT, kept), 'a 300-character address is taken');

      (* The refusal is the registered 1024 check judging the WHOLE value --
        cut at 255 it would have passed. *)
      CheckFalse(CheckCommand(TAILCAT, tooLong, True), 'CheckCommand refuses 1025 characters');
      CheckEquals(kept, string(Settings.Server.TailcatAddress), 'CheckCommand: the old value stands');

      (* Refused before anything is saved: ApplyAndStoreCommand exits on a
        refusal, so no settings file is written by this line. *)
      CheckFalse(ApplyAndStoreCommand(nil, TAILCAT, tooLong), 'ApplyAndStoreCommand refuses it');
      CheckEquals(kept, string(Settings.Server.TailcatAddress), 'ApplyAndStoreCommand: the old value stands');
   finally
      Settings.Server.TailcatAddress := TSecretText(saved);
   end;

   (* A STATION FACT a contest states out of range: no override, the
     station's value is what the contest reads. *)
   savedZone := Settings.My.ResolvedItuZone;
   CheckFalse(ApplyContestStatement('MY ITU ZONE', '999'), 'an ITU zone of 999 is refused');
   CheckEquals(savedZone, Settings.My.ResolvedItuZone, 'and the zone in force is unchanged');
end;

procedure TSettingValueWidthTests.Test_ANonAsciiNameSurvivesThePreferencesSave;
var
   saved, fileName, loaded: string;
   fresh: TR4WSettings;
begin
   BeginTest('a name in three scripts survives the Preferences save and the settings file');
   InstallTestKeychain;
   saved := CurrentValue(MY_NAME);
   fileName := TempPath('prefs.json');
   fresh := nil;
   try
      (* The call ApplyAndStoreCommand makes for an owned station setting. *)
      CheckTrue(CheckCommand(MY_NAME, ThreeScriptName, True), 'the name is accepted');
      CheckEquals(ThreeScriptName, CurrentValue(MY_NAME), 'read back by name, unchanged');

      (* And what makes it survive a restart: the settings file. *)
      SaveSettings(fileName, Settings);
      fresh := TR4WSettings.Create;
      CheckTrue(LoadSettingsSection(fileName, fresh), 'the file has a settings section');
      if not fresh.TryGetByCommand(MY_NAME, loaded) then
         begin
         loaded := '';
         end;
      CheckEquals(ThreeScriptName, loaded, 'the file gives back the same name');
   finally
      fresh.Free;
      Settings.TrySetByCommand(MY_NAME, saved);
      DeleteFile(fileName);
   end;
end;

procedure TSettingValueWidthTests.Test_TheTextLineReaderDoesNotCut;
var
   path, long: string;
begin
   BeginTest('EnumerateTextLinesInFile delivers a 300-byte line whole; ' +
             'EnumerateLinesInFile still cuts at 255');
   long := 'name = ' + StringOfChar('x', 293);
   path := TempPath('lines.txt');
   SetLength(GTextLines, 0);
   try
      WriteBytesFile(path, UTF8Encode(#13#10'first'#10#10 + long +
                                      #13#10'Last ' + ThreeScriptName));
      CheckTrue(EnumerateTextLinesInFile(path, CollectTextLine, True), 'the file is read');
      CheckEquals(3, Length(GTextLines), 'three lines: breaks collapse, blank lines are skipped');
      if Length(GTextLines) = 3 then
         begin
         CheckEquals('FIRST', GTextLines[0], 'upper-cased');
         CheckEquals(300, Length(GTextLines[1]), 'the long line is whole');
         CheckEquals(UpperCase(long), GTextLines[1], 'and upper-cased in ASCII');
         CheckEquals('LAST ' + ThreeScriptNameUpperCasedAsCfg, GTextLines[2],
                     'a non-ASCII letter is left as it is');
         end;

      (* The ShortString reader is unchanged: same lines, cut at 255. *)
      SetLength(GShortLines, 0);
      CheckTrue(EnumerateLinesInFile(path, CollectShortLine, False), 'the ShortString reader reads it');
      CheckEquals(3, Length(GShortLines), 'the same three lines');
      if Length(GShortLines) = 3 then
         begin
         CheckEquals(255, Length(GShortLines[1]), 'cut at 255, as before');
         end;
   finally
      SetLength(GTextLines, 0);
      SetLength(GShortLines, 0);
      DeleteFile(path);
   end;
end;

procedure TSettingValueWidthTests.Test_AContestCfgKeepsALongValueAndANonAsciiName;
var
   path, savedCall, savedName, savedHistory, call: string;
   wasStated: boolean;
   savedFile: TCFGType;
   savedLine: integer;
begin
   BeginTest('a contest .cfg keeps a 300-character value and a three-script name');
   savedCall := Settings.My.Call;
   savedName := CurrentValue(MY_NAME);
   savedHistory := CurrentValue(CALL_HISTORY);
   wasStated := Settings.CommandIsStated(CALL_HISTORY);
   savedFile := CurrentConfigFile;
   savedLine := LineNumberInConfigFile;
   path := TempPath('contest.cfg');
   call := savedCall;
   if call = '' then
      begin
      call := 'N0CALL';
      end;
   try
      (* MY CALL FIRST: the reader halts on a .cfg whose first line is not. *)
      WriteBytesFile(path, UTF8Encode('MY CALL = ' + call + #13#10 +
                                      'my name = ' + ThreeScriptName + #13#10 +
                                      CALL_HISTORY + ' = ' + LongValue('E') + #13#10));
      CurrentConfigFile := cfgCFG;
      LineNumberInConfigFile := 0;
      CheckTrue(EnumerateTextLinesInFile(path, EnmuCFGFile, True), 'the .cfg is read');

      CheckEquals(LongValue('E'), CurrentValue(CALL_HISTORY), 'the long value is whole');
      CheckEquals(ThreeScriptNameUpperCasedAsCfg, Settings.My.ResolvedName,
                  'the name is this contest''s, upper-cased in ASCII only');
      CheckEquals(savedName, CurrentValue(MY_NAME), 'and the station''s name is not touched');
   finally
      CurrentConfigFile := savedFile;
      LineNumberInConfigFile := savedLine;
      ClearContestCFGCommands;
      Settings.My.Call := savedCall;
      Settings.TrySetByCommand(CALL_HISTORY, savedHistory);
      Settings.SetCommandStated(CALL_HISTORY, wasStated);
      DeleteFile(path);
   end;
end;

(* THE TEST'S CONTEST SET-UP: nothing -- the values do not depend on it. *)
function SetUpNothing302(const aContestId: ShortString): boolean;
begin
   Result := True;
end;

procedure SeedRows(const aDb: string; const aRows: array of string);
var
   db: TLogDatabase;
   repo: TLogRepository;
   i: integer;
begin
   db := TLogDatabase.Create;
   try
      db.Open(aDb);
      repo := TLogRepository.Create(db);
      try
         for i := 0 to High(aRows) div 2 do
            begin
            repo.SaveConfigValue(AnsiString(aRows[i * 2]), AnsiString(aRows[i * 2 + 1]),
                                 AnsiString('contest'));
            end;
         repo.Commit;
      finally
         repo.Free;
      end;
   finally
      db.Free;
   end;
end;

function StoredRow(const aDb, aCommand: string): string;
var
   db: TLogDatabase;
   repo: TLogRepository;
   rows: TStringList;
begin
   db := TLogDatabase.Create;
   rows := TStringList.Create;
   try
      db.Open(aDb);
      repo := TLogRepository.Create(db);
      try
         repo.LoadContestConfig(rows);
      finally
         repo.Free;
      end;
      Result := string(rows.Values[AnsiString(aCommand)]);
   finally
      rows.Free;
      db.Free;
   end;
end;

procedure TSettingValueWidthTests.Test_AContestLogKeepsThemThroughOpenAndClose;
var
   fn, savedHistory, savedLogName: string;
   wasStated, savedSilent: boolean;
begin
   BeginTest('a contest log''s stored rows come back whole on open and are captured whole at close');
   savedHistory := CurrentValue(CALL_HISTORY);
   wasStated := Settings.CommandIsStated(CALL_HISTORY);
   savedSilent := tSilentExport;
   savedLogName := CharBufferText(TR4W_LOG_FILENAME);
   fn := TempPath('replay.db');
   ScrubTestLog(fn);
   try
      MakeTestContestLog(fn, ContestHandleOf(CQWPXCW), '');
      SeedRows(fn, [CALL_HISTORY, LongValue('F'), MY_NAME, ThreeScriptName]);

      (* THE PRODUCTION OPEN: whatever an earlier suite left open is closed
        without a capture first. *)
      tSilentExport := True;
      LogStoreClose;
      SetCharBuffer(TR4W_LOG_FILENAME, ChangeFileExt(fn, '.trw'));
      tSilentExport := False;
      LogStoreApplyContestConfigWith(@SetUpNothing302);
      CheckTrue(LogStoreIsUsable, 'the store opened the log');
      CheckEquals(LongValue('F'), CurrentValue(CALL_HISTORY), 'the long row came back whole');
      CheckEquals(ThreeScriptName, Settings.My.ResolvedName, 'the name came back unchanged');

      (* THE CLOSE CAPTURE writes them back. *)
      LogStoreClose;
      CheckEquals(LongValue('F'), StoredRow(fn, CALL_HISTORY), 'captured whole');
      CheckEquals(ThreeScriptName, StoredRow(fn, MY_NAME), 'the name captured unchanged');
   finally
      tSilentExport := True;
      LogStoreClose;
      SetCharBuffer(TR4W_LOG_FILENAME, savedLogName);
      tSilentExport := savedSilent;
      ClearContestCFGCommands;
      Settings.TrySetByCommand(CALL_HISTORY, savedHistory);
      Settings.SetCommandStated(CALL_HISTORY, wasStated);
      ScrubTestLog(fn);
   end;
end;

procedure TSettingValueWidthTests.Test_TheWireAndTheMessageEditorSayWhatTheyHold;
var
   cyrillic127, cyrillic128: string;
begin
   BeginTest('the parameter packet and the message editor answer "does not fit" ' +
             'for more than 255 bytes, counting a non-ASCII character as its bytes');
   cyrillic127 := Repeated(WideChar($0416), 127);   (* 254 bytes *)
   cyrillic128 := Repeated(WideChar($0416), 128);   (* 256 bytes *)

   CheckTrue(ParameterFitsTheWire(MY_NAME, StringOfChar('a', 255)), 'wire: 255 ASCII fits');
   CheckFalse(ParameterFitsTheWire(MY_NAME, StringOfChar('a', 256)), 'wire: 256 does not');
   CheckTrue(ParameterFitsTheWire(MY_NAME, cyrillic127), 'wire: 127 Cyrillic (254 bytes) fits');
   CheckFalse(ParameterFitsTheWire(MY_NAME, cyrillic128), 'wire: 128 Cyrillic (256 bytes) does not');

   CheckTrue(MessageEditFits(AnsiString(StringOfChar('a', MESSAGE_EDIT_MAX_BYTES))),
             'message: 255 bytes fits');
   CheckFalse(MessageEditFits(AnsiString(StringOfChar('a', MESSAGE_EDIT_MAX_BYTES + 1))),
              'message: 256 does not');
   CheckFalse(MessageEditFits(UTF8Encode(cyrillic128)), 'message: 128 Cyrillic does not');

   (* WHAT THE OPERATOR IS TOLD -- the text, without the modal or the status
     line. Nothing when it fits; when it does not, the setting's name (wire),
     the length typed and the limit. *)
   CheckEquals('', ParameterNotSentText(MY_NAME, cyrillic127), 'wire: no notice when it fits');
   CheckEquals('MY NAME was not sent to the other stations: it is 256 bytes ' +
               'and the network carries 255.',
               ParameterNotSentText(MY_NAME, cyrillic128), 'wire: the notice names the setting and both sizes');
   CheckEquals('', MessageEditRefusalText(AnsiString('CQ TEST'), False), 'message: no text when it fits');
   CheckEquals('The message is 256 bytes long and a message holds 255. ' +
               'Shorten it and press OK again.',
               MessageEditRefusalText(UTF8Encode(cyrillic128), False), 'message: the refusal text');
   CheckEquals('The caption is 300 bytes long and a caption holds 255. ' +
               'Shorten it and press OK again.',
               MessageEditRefusalText(AnsiString(StringOfChar('c', 300)), True), 'caption: the refusal text');
end;

procedure TSettingValueWidthTests.RunAllTests;
begin
   Test_TheTestProgramDecodesAsUTF8;
   Test_EveryCommandRouteKeepsALongValue;
   Test_ARefusedValueLeavesTheOldOne;
   Test_ANonAsciiNameSurvivesThePreferencesSave;
   Test_TheTextLineReaderDoesNotCut;
   Test_AContestCfgKeepsALongValueAndANonAsciiName;
   Test_AContestLogKeepsThemThroughOpenAndClose;
   Test_TheWireAndTheMessageEditorSayWhatTheyHold;
end;

end.
