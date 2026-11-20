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

(* ONE CABRILLO PER ACTIVATION -- issues 133 and 87, rover step F (NY4I,
  2026-11-18 and 2026-11-19).

  A contest class says whether a rover's Cabrillo is split by the place each
  QSO was sent from (TContestBase.SplitsCabrilloByActivation). Only the Hawaii
  QSO Party does; the first test walks every registered contest to pin that.
  The rules (uCabrilloActivation) are pinned without a log; the last tests run
  the real export over small Hawaii logs: a rover's log is one file per
  activation, each headed by the activation's call and the WHOLE log's score,
  a boundary QSO one line in each of its two files; a rover that never left
  one place is one file whose header carries the call its lines carry. *)
unit uTestCabrilloActivation;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCabrilloActivationTests = class(TTestCase)
   private
      FDir: string;
      FTrw: string;
      FSavedLogName: string;
      FSavedLogPath: string;
      FSavedSilent: boolean;
      FSavedCall: string;
      FSavedState: string;
      procedure StartEmptyStore;
      procedure StopStore;
   protected
      procedure Test_OnlyHawaiiSplitsItsCabrillo;
      procedure Test_TheActivationRules;
      procedure Test_ARoverLogIsOneCabrilloPerActivation;
      procedure Test_ARoverInOnePlaceIsOneFileHeadedByItsCall;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, StrUtils, VC, utils_text, uSettingsModel,
   uContestBase, uContestRegistry, uContestFactory, uLogDatabase, uLogStore,
   LogEdit, PostUnit, MainUnit, uRoverState, uCabrilloActivation;

const
   HAWAII_ID = 'HI-QSO-PARTY';

var
   GSavedContest: TContestHandle;

function HawaiiHandle: TContestHandle;
begin
   if not FindContestById(HAWAII_ID, Result) then
      begin
      raise Exception.Create(HAWAII_ID + ' is not registered');
      end;
end;

function ReadWhole(const aFileName: string): string;
var
   lines: TStringList;
begin
   Result := '';
   if not FileExists(aFileName) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(aFileName);
      Result := lines.Text;
   finally
      lines.Free;
   end;
end;

function CountOf(const aNeedle, aText: string): integer;
var
   p: integer;
begin
   Result := 0;
   p := PosEx(aNeedle, aText, 1);
   while p > 0 do
      begin
      Inc(Result);
      p := PosEx(aNeedle, aText, p + Length(aNeedle));
      end;
end;

(* THE LINE OF aText THAT STARTS WITH aTag, without the tag; '' for none. *)
function HeaderValue(const aText, aTag: string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := '';
   lines := TStringList.Create;
   try
      lines.Text := aText;
      for i := 0 to lines.Count - 1 do
         begin
         if AnsiStartsStr(aTag, lines[i]) then
            begin
            Result := Trim(Copy(lines[i], Length(aTag) + 1, MaxInt));
            Exit;
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* THE QSO: (OR X-QSO:) LINE OF aText THAT NAMES aCall AS THE WORKED
  STATION. *)
function QSOLineOf(const aText, aCall: string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := '';
   lines := TStringList.Create;
   try
      lines.Text := aText;
      for i := 0 to lines.Count - 1 do
         begin
         (* X-QSO: too -- these rows are stored off-contest (not scored by the
           engine, which this test does not run), and the line is the same. *)
         if (AnsiStartsStr('QSO:', lines[i]) or AnsiStartsStr('X-QSO:', lines[i])) and
            (Pos(' ' + aCall + ' ', lines[i]) > 0) then
            begin
            Result := lines[i];
            Exit;
            end;
         end;
   finally
      lines.Free;
   end;
end;

procedure TCabrilloActivationTests.StartEmptyStore;
begin
   LogStoreClose;
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_activation_' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   FTrw := FDir + 'hi_rover.trw';
   DeleteFile(LogDatabaseFileName(FTrw));
   DeleteFile(LogDatabaseFileName(FTrw) + '-wal');
   DeleteFile(LogDatabaseFileName(FTrw) + '-shm');
   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedLogPath := CharBufferText(TR4W_LOG_PATH_NAME);
   FSavedSilent := tSilentExport;
   FSavedCall := Settings.My.Call;
   FSavedState := Settings.My.State;
   GSavedContest := Contest;
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FDir);
   (* No dialog, no preview, no prompt: a headless export. *)
   tSilentExport := True;
   Settings.My.Call := 'AH7RF';
   Contest := HawaiiHandle;
   ActiveContest(Contest);
end;

procedure TCabrilloActivationTests.StopStore;
var
   found: TSearchRec;
begin
   (* THE ROVING STATE IS THE PROGRAM'S: left on, every later test's call and
     captured facts would rove. *)
   RoverState.TurnOff;
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FSavedLogPath);
   tSilentExport := FSavedSilent;
   Settings.My.Call := FSavedCall;
   Settings.My.State := FSavedState;
   Contest := GSavedContest;
   ReleaseActiveContest;
   (* Only the files this suite made: its own folder, emptied. *)
   if (FDir <> '') and (FindFirst(FDir + '*', faAnyFile, found) = 0) then
      begin
      repeat
         if (found.Attr and faDirectory) = 0 then
            begin
            DeleteFile(FDir + found.Name);
            end;
      until FindNext(found) <> 0;
      FindClose(found);
      RemoveDir(FDir);
      end;
end;

(* ROVE FROM aPlaces ('' turns roving off), as the ROVER dialog does. *)
procedure Rove(const aPlaces: string);
var
   units: TStringList;
begin
   units := TStringList.Create;
   try
      if SplitRoverUnitsText(aPlaces, units) then
         begin
         RoverState.SetUnits(units);
         end
      else
         begin
         RoverState.TurnOff;
         end;
   finally
      units.Free;
   end;
end;

(* THE BASE SAYS NO, AND SO DOES EVERY CONTEST BUT HAWAII. *)
procedure TCabrilloActivationTests.Test_OnlyHawaiiSplitsItsCabrillo;
var
   handles: TContestHandleList;
   i, hawaii: integer;
begin
   BeginTest('Test_OnlyHawaiiSplitsItsCabrillo');
   handles := KnownContests;
   CheckTrue(Length(handles) > 100, 'the walk sees the registered contests');
   hawaii := 0;
   for i := 0 to High(handles) do
      begin
      if ContestId(handles[i]) = HAWAII_ID then
         begin
         Inc(hawaii);
         CheckTrue(ContestIdentity(handles[i]).SplitsCabrilloByActivation,
                   'Hawaii: a separate log for each activation');
         end
      else
         begin
         CheckFalse(ContestIdentity(handles[i]).SplitsCabrilloByActivation,
                    ContestId(handles[i]) + ' writes one Cabrillo');
         end;
      end;
   CheckEquals(1, hawaii, 'Hawaii is registered once');
end;

(* THE RULES, WITHOUT A LOG. *)
procedure TCabrilloActivationTests.Test_TheActivationRules;
var
   a: TCabrilloActivations;
begin
   BeginTest('Test_TheActivationRules');

   (* A LOG THAT NEVER ROVED: never split, and MY CALL heads its one file,
     whatever the places and calls. *)
   a := TCabrilloActivations.Create;
   try
      a.Add('hil', False, 'AH7RF');
      a.Add('KOH', False, 'AH7RF');
      CheckEquals(2, a.Count, 'two places');
      CheckFalse(a.AnyRoved, 'no row roved');
      CheckFalse(a.ShouldSplit(True), 'no split without roving, even for Hawaii');
      CheckEquals('MYCALL', a.SingleFileHeaderCall('MYCALL'), 'the header is MY CALL');
   finally
      a.Free;
   end;

   (* A ROVER IN TWO PLACES, BEFORE-ROVING ROWS FIRST. *)
   a := TCabrilloActivations.Create;
   try
      a.Add(' hil ', False, 'AH7RF');
      a.Add('KOH', True, 'AH7RF/KOH');
      a.Add('koh', True, 'AH7RF/KOH/KON');
      a.Add('KON', True, 'AH7RF/KOH/KON');
      CheckEquals(3, a.Count, 'three activations, a place once in any case');
      CheckEquals('HIL', a.Place(0), 'in the order first met, upper cased, trimmed');
      CheckEquals('KOH', a.Place(1), 'second');
      CheckEquals('KON', a.Place(2), 'third');
      CheckEquals(1, a.IndexOfPlace(' koh'), 'found in any case');
      CheckFalse(a.Roved(0), 'HIL was before roving');
      CheckTrue(a.Roved(1), 'KOH roved');
      CheckTrue(a.ShouldSplit(True), 'Hawaii splits it');
      CheckFalse(a.ShouldSplit(False), 'a contest without the option does not');

      CheckEquals('AH7RF', a.ActivationCall(0, 'AH7RF'),
                  'a place that never roved signed the plain call');
      CheckEquals('AH7RF/KOH', a.ActivationCall(1, 'AH7RF'),
                  'a roved place signs the call with its place');
      CheckEquals('AH7RF/KON', a.ActivationCall(2, 'AH7RF'),
                  'the boundary''s second place its own, never the joined call');
      CheckEquals('KH6/NY4I/KOH', a.ActivationCall(1, 'KH6/NY4I'),
                  'a portable call keeps its own slash');

      CheckEquals('hil', a.FileTag(0), 'the tag is the place in lower case');
      CheckEquals('MYCALL', a.SingleFileHeaderCall('MYCALL'),
                  'rows with different calls: the header stays MY CALL');
   finally
      a.Free;
   end;

   (* ONE PLACE, ROVED: one file, headed by the call every line carries. *)
   a := TCabrilloActivations.Create;
   try
      a.Add('KOH', True, 'AH7RF/KOH');
      a.Add('KOH', True, 'ah7rf/koh');
      CheckFalse(a.ShouldSplit(True), 'one activation is one file');
      CheckEquals('AH7RF/KOH', a.SingleFileHeaderCall('AH7RF'),
                  'the header is the call the lines carry');
   finally
      a.Free;
   end;

   (* A FILE TAG IS SAFE IN A FILE NAME, AND AN EMPTY PLACE HAS ONE. *)
   a := TCabrilloActivations.Create;
   try
      a.Add('A B/C', True, 'X');
      a.Add('', False, 'X');
      CheckEquals('a_b_c', a.FileTag(0), 'no space or slash in a name');
      CheckEquals('noqth', a.FileTag(1), 'an empty place is named');
      CheckEquals('X', a.ActivationCall(1, 'X'), 'no place, no suffix');
   finally
      a.Free;
   end;
end;

(* THE REAL EXPORT OVER A ROVER'S HAWAII LOG: one QSO at home in HIL before
  roving, two from KOH, a boundary QSO from KOH/KON (two rows, one id), one
  from KON. *)
procedure TCabrilloActivationTests.Test_ARoverLogIsOneCabrilloPerActivation;
var
   rx: ContestExchange;
   n: integer;
   hil, koh, kon: string;
   adif: string;
   score: integer;

   procedure Log(const aCall, aRoverQTH: string; aMinute: integer; const aId: string);
   begin
      Inc(n);
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.Callsign := CallString(aCall);
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Band := Band20;
      rx.id := aId;
      rx.ceContest := Contest;
      rx.ceComputerID := Settings.Computer.Id;
      rx.ceQSOID1 := 7100 + n;
      rx.ceQSOID2 := 8100 + n;
      rx.ceRoverQTH := ShortString(aRoverQTH);
      rx.tSysTime.qtYear := 27;
      rx.tSysTime.qtMonth := 8;
      rx.tSysTime.qtDay := 22;
      rx.tSysTime.qtHour := 18;
      rx.tSysTime.qtMinute := aMinute;
      rx.Frequency := 14030000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'TX';
      rx.DomesticQTH := 'TX';
      rx.DomMultQTH := 'TX';
      CheckTrue(LogStoreAppendQSO(rx), aCall + ' is logged');
   end;

begin
   BeginTest('Test_ARoverLogIsOneCabrilloPerActivation');
   StartEmptyStore;
   try
      n := 0;
      (* AT HOME, BEFORE ROVING: MY STATE HIL, the plain call. *)
      Settings.My.State := 'HIL';
      Rove('');
      Log('W1HOM', '', 1, 'act1');
      (* ROVING IN KOH. *)
      Rove('KOH');
      Log('W2KOA', 'KOH', 2, 'act2');
      Log('W3KOB', 'KOH', 3, 'act3');
      (* ON THE KOH/KON BOUNDARY: one contact, two rows, one id. *)
      Rove('KOH KON');
      Log('W5BND', 'KOH', 5, 'act5');
      Log('W5BND', 'KON', 5, 'act5');
      (* ROVING IN KON. *)
      Rove('KON');
      Log('W6KON', 'KON', 6, 'act6');
      Rove('');

      score := ClaimedScore;
      PostUnit.CreateCabrilloFile;

      hil := ReadWhole(LogExportFileNameTagged(FTrw, lekCabrillo, 'hil'));
      koh := ReadWhole(LogExportFileNameTagged(FTrw, lekCabrillo, 'koh'));
      kon := ReadWhole(LogExportFileNameTagged(FTrw, lekCabrillo, 'kon'));
      CheckFalse(FileExists(LogExportFileName(FTrw, lekCabrillo)),
                 'no whole-log file: one per activation');
      CheckTrue(hil <> '', 'the HIL file is written');
      CheckTrue(koh <> '', 'the KOH file is written');
      CheckTrue(kon <> '', 'the KON file is written');

      (* EACH HEADED BY ITS ACTIVATION'S CALL, AND EVERY LINE CARRIES IT. *)
      CheckEquals('AH7RF', HeaderValue(hil, 'CALLSIGN:'),
                  'HIL was before roving: the plain call');
      CheckEquals('AH7RF/KOH', HeaderValue(koh, 'CALLSIGN:'), 'KOH');
      CheckEquals('AH7RF/KON', HeaderValue(kon, 'CALLSIGN:'), 'KON');
      CheckEquals(1, CountOf('QSO: ', hil), 'HIL holds its one QSO');
      CheckEquals(3, CountOf('QSO: ', koh), 'KOH: two, and its leg of the boundary');
      CheckEquals(2, CountOf('QSO: ', kon), 'KON: its leg of the boundary, and one');
      CheckEquals(3, CountOf(' AH7RF/KOH ', koh), 'every KOH line signs AH7RF/KOH');
      CheckEquals(2, CountOf(' AH7RF/KON ', kon), 'every KON line signs AH7RF/KON');
      CheckEquals(0, CountOf('KOH/KON', koh + kon), 'never the joined boundary call');
      CheckEquals(0, CountOf('KON', koh), 'nothing of KON in the KOH file');
      CheckEquals(0, CountOf('KOH', kon), 'nothing of KOH in the KON file');
      CheckEquals(0, CountOf(' W2KOA ', hil + kon), 'a KOH QSO is in no other file');

      (* THE BOUNDARY QSO: ONE LINE IN EACH FILE, SAME TIME, ITS OWN SENT QTH. *)
      CheckTrue(Pos(' 1805 AH7RF/KOH ', QSOLineOf(koh, 'W5BND')) > 0,
                'the boundary in KOH: 1805, signed from KOH [' + QSOLineOf(koh, 'W5BND') + ']');
      CheckTrue(Pos(' KOH ', QSOLineOf(koh, 'W5BND')) > 0,
                'sent KOH [' + QSOLineOf(koh, 'W5BND') + ']');
      CheckTrue(Pos(' 1805 AH7RF/KON ', QSOLineOf(kon, 'W5BND')) > 0,
                'the boundary in KON: 1805, signed from KON [' + QSOLineOf(kon, 'W5BND') + ']');
      CheckTrue(Pos(' KON ', QSOLineOf(kon, 'W5BND')) > 0,
                'sent KON [' + QSOLineOf(kon, 'W5BND') + ']');
      CheckTrue(Pos(' HIL ', QSOLineOf(hil, 'W1HOM')) > 0,
                'HIL sent its MY STATE [' + QSOLineOf(hil, 'W1HOM') + ']');

      (* EVERY FILE CLAIMS THE WHOLE LOG'S SCORE. *)
      CheckEquals(IntToStr(score), HeaderValue(hil, 'CLAIMED-SCORE:'), 'HIL: the log''s score');
      CheckEquals(IntToStr(score), HeaderValue(koh, 'CLAIMED-SCORE:'), 'KOH: the log''s score');
      CheckEquals(IntToStr(score), HeaderValue(kon, 'CLAIMED-SCORE:'), 'KON: the log''s score');

      (* THE ADIF STAYS ONE FILE -- AND ONE RECORD PER CONTACT (issue 338,
         NY4I 2026-11-20): the boundary's two rows are one record, so six
         rows are five records. KOH and KON both lie in Hawaii county, so it
         names no second county. *)
      PostUnit.ExportToADIF;
      adif := ReadWhole(LogExportFileName(FTrw, lekADIF));
      CheckEquals(5, CountOf('<CALL:', adif), 'the ADIF holds every contact once');
      CheckEquals(1, CountOf('W5BND', adif), 'the boundary contact is one record');
      CheckEquals(0, CountOf('USACA_COUNTIES', adif) + CountOf('CNTY_ALT', adif),
                  'two districts of one county: no second county written');
      CheckFalse(FileExists(LogExportFileNameTagged(FTrw, lekADIF, 'koh')),
                 'and is not split');
   finally
      StopStore;
   end;
end;

(* A ROVER THAT STAYED IN ONE PLACE: one file, as ever, but its CALLSIGN is
  the call its lines carry (it said MY CALL while the lines said AH7RF/KOH). *)
procedure TCabrilloActivationTests.Test_ARoverInOnePlaceIsOneFileHeadedByItsCall;
var
   rx: ContestExchange;
   cabrillo: string;
begin
   BeginTest('Test_ARoverInOnePlaceIsOneFileHeadedByItsCall');
   StartEmptyStore;
   try
      Settings.My.State := 'HIL';
      Rove('KOH');
      rx := Default(ContestExchange);
      rx.ceRecordKind := rkQSO;
      rx.Callsign := CallString('W7ONE');
      rx.Mode := CW;
      rx.ExtMode := eCW;
      rx.Band := Band40;
      rx.id := 'one1';
      rx.ceContest := Contest;
      rx.ceComputerID := Settings.Computer.Id;
      rx.ceQSOID1 := 7201;
      rx.ceQSOID2 := 8201;
      rx.ceRoverQTH := 'KOH';
      rx.tSysTime.qtYear := 27;
      rx.tSysTime.qtMonth := 8;
      rx.tSysTime.qtDay := 22;
      rx.tSysTime.qtHour := 19;
      rx.tSysTime.qtMinute := 1;
      rx.Frequency := 7030000;
      rx.RSTSent := 599;
      rx.RSTReceived := 599;
      rx.QTHString := 'OR';
      rx.DomesticQTH := 'OR';
      rx.DomMultQTH := 'OR';
      CheckTrue(LogStoreAppendQSO(rx), 'W7ONE is logged');
      Rove('');

      PostUnit.CreateCabrilloFile;
      cabrillo := ReadWhole(LogExportFileName(FTrw, lekCabrillo));
      CheckTrue(cabrillo <> '', 'the one file is written');
      CheckEquals('AH7RF/KOH', HeaderValue(cabrillo, 'CALLSIGN:'),
                  'headed by the call its line carries');
      CheckTrue(Pos(' AH7RF/KOH ', QSOLineOf(cabrillo, 'W7ONE')) > 0,
                'the line signs AH7RF/KOH [' + QSOLineOf(cabrillo, 'W7ONE') + ']');
      CheckFalse(FileExists(LogExportFileNameTagged(FTrw, lekCabrillo, 'koh')),
                 'one activation is not split');
   finally
      StopStore;
   end;
end;

procedure TCabrilloActivationTests.RunAllTests;
begin
   Test_OnlyHawaiiSplitsItsCabrillo;
   Test_TheActivationRules;
   Test_ARoverLogIsOneCabrilloPerActivation;
   Test_ARoverInOnePlaceIsOneFileHeadedByItsCall;
end;

end.
