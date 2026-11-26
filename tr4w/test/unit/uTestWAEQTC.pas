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

(* THE WAE QTC RULES (2026-11-26), docs/ContestRules/WAE/rules.txt section 7.

  - a series is logged as '<series>/<QTCs transferred>' (a book offered as 10
    and stopped after 6 is 3/6);
  - a deleted QTC record counts nowhere, and the series number never goes back;
  - which QSOs a book may offer (deleted, dupe, X-QSO, zero points, already
    sent, the receiving station itself by base call);
  - the per-pair quota of ten is kept by base call;
  - a series and the marks on the QSOs it reported are ONE transaction;
  - the real Cabrillo export writes the sponsor's QTC: lines (nothing else in
    the unit tests, the corpus or the matrix produces one). *)
unit uTestWAEQTC;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TWAEQTCTests = class(TTestCase)
   private
      FDir: string;
      FTrw: string;
      FSavedLogName: string;
      FSavedLogPath: string;
      FSavedSilent: boolean;
      FSavedCall: string;
      procedure StartEmptyStore;
      procedure StopStore;
      function LogQso(const aCall: string; aMinute: integer): Int64;
      function CountRows(const aSql: string): Int64;
      procedure TrapTheCommitOn(const aEvent: string);
   protected
      procedure Test_TheSeriesIsTheQTCsTransferred;
      procedure Test_ADeletedQTCRecordCountsNowhere;
      procedure Test_TheBaseCallOfAStation;
      procedure Test_WhichQSOsABookMayOffer;
      procedure Test_TheQuotaIsKeptByBaseCall;
      procedure Test_ASeriesAndItsMarksAreOneCommit;
      procedure Test_AFailedCommitSavesNoQTCAndNoMark;
      procedure Test_TheCabrilloQTCLines;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, StrUtils, sqldb, VC, utils_text, uSettingsModel,
   uCallSignRoutines, uContestBase, uContestRegistry, uContestFactory,
   uLogDatabase, uLogStore, uLogSource, LogStuff, LogWind, PostUnit, MainUnit,
   uCabrilloFormat, uQTCSeries;

var
   GSavedContest: TContestHandle;

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

(* THE QSO A BOOK MAY OFFER, as a WAE CW log holds it. *)
function ValidQso(const aCall: string): ContestExchange;
begin
   Result.Clear;
   Result.ceRecordKind := rkQSO;
   Result.Callsign := CallString(aCall);
   Result.Band := Band20;
   Result.Mode := CW;
   Result.ExtMode := eCW;
   Result.QSOPoints := 1;
   Result.NumberReceived := 431;
end;

procedure TWAEQTCTests.StartEmptyStore;
begin
   LogStoreClose;
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_waeqtc_' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   FTrw := FDir + 'wae_qtc.trw';
   DeleteFile(LogDatabaseFileName(FTrw));
   DeleteFile(LogDatabaseFileName(FTrw) + '-wal');
   DeleteFile(LogDatabaseFileName(FTrw) + '-shm');
   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedLogPath := CharBufferText(TR4W_LOG_PATH_NAME);
   FSavedSilent := tSilentExport;
   FSavedCall := Settings.My.Call;
   GSavedContest := Contest;
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FDir);
   tSilentExport := True;
   Contest := ContestHandleOf(DARCWAEDCCW);
   ActiveContest(Contest);
end;

procedure TWAEQTCTests.StopStore;
var
   found: TSearchRec;
begin
   LogStoreClose;
   LogStoreForgetFailureForTests;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FSavedLogPath);
   tSilentExport := FSavedSilent;
   Settings.My.Call := FSavedCall;
   Contest := GSavedContest;
   ReleaseActiveContest;
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

function TWAEQTCTests.LogQso(const aCall: string; aMinute: integer): Int64;
var
   rx: ContestExchange;
begin
   rx := ValidQso(aCall);
   rx.id := 'waeqtc-' + aCall;
   rx.ceContest := Contest;
   rx.ceQSOID1 := 9000 + aMinute;
   rx.ceQSOID2 := 9100 + aMinute;
   rx.tSysTime.qtYear := 26;
   rx.tSysTime.qtMonth := 8;
   rx.tSysTime.qtDay := 8;
   rx.tSysTime.qtHour := 13;
   rx.tSysTime.qtMinute := aMinute;
   rx.RSTSent := 599;
   rx.RSTReceived := 599;
   rx.NumberSent := aMinute;
   CheckTrue(LogStoreAppendQSO(rx), aCall + ' is logged');
   Result := LogStoreNewestRowId;
end;

function TWAEQTCTests.CountRows(const aSql: string): Int64;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   Result := -1;
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(LogDatabaseFileName(FTrw));
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
         q.Transaction := db.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := aSql;
         q.Open;
         if not q.EOF then
            begin
            Result := q.Fields[0].AsLargeInt;
            end;
         q.Close;
      finally
         q.Free;
      end;
   finally
      db.Free;
   end;
end;

(* THE R2 TRAP (uTestLogStore): a row breaking a DEFERRED foreign key on every
  aEvent ('INSERT' or 'UPDATE') on qso, which fails the COMMIT. Added with the
  store closed, so its statements are prepared with the trigger. *)
procedure TWAEQTCTests.TrapTheCommitOn(const aEvent: string);
var
   db: TLogDatabase;
begin
   LogStoreClose;
   db := TLogDatabase.Create;
   try
      db.Open(LogDatabaseFileName(FTrw));
      db.Connection.ExecuteDirect('CREATE TABLE commit_trap_parent (id INTEGER PRIMARY KEY)');
      db.Connection.ExecuteDirect(
         'CREATE TABLE commit_trap (parent_id INTEGER REFERENCES ' +
         'commit_trap_parent(id) DEFERRABLE INITIALLY DEFERRED)');
      db.Connection.ExecuteDirect(
         'CREATE TRIGGER commit_trap_on_' + LowerCase(aEvent) + ' AFTER ' + aEvent +
         ' ON qso BEGIN INSERT INTO commit_trap (parent_id) VALUES (-1); END');
      db.Transaction.Commit;
   finally
      db.Free;
   end;
   CheckTrue(LogStoreEnsureOpen, 'the store reopens the trapped log');
end;

(* SECTION 7: "the second figure denotes the number of QTCs in the series". *)
procedure TWAEQTCTests.Test_TheSeriesIsTheQTCsTransferred;
var
   rx: ContestExchange;
begin
   BeginTest('Test_TheSeriesIsTheQTCsTransferred');
   CheckEquals('3/6', QTCSeriesText(3, 6), 'series 3 of six QTCs');
   CheckEquals('12/10', QTCSeriesText(12, 10), 'two digits each');

   (* A book offered as 3/10 and stopped after 6 confirmed: the caller passes
     the confirmed count, and every row carries it. *)
   rx := SentQTCRecord('DL1XYZ', 3, 6, 1332, 'S59XYZ', 112);
   CheckTrue(rx.ceRecordKind = rkQTCS, 'a sent QTC');
   CheckEquals('DL1XYZ', string(rx.Callsign), 'Callsign: the station that received it');
   CheckEquals('3/6', string(rx.RandomCharsReceived), 'the group');
   CheckEquals(3, rx.QSOPoints, 'QSOPoints: the series number (the numbering reads it)');
   CheckEquals(1332, rx.NumberSent, 'the QSO''s time');
   CheckEquals('S59XYZ', string(rx.Kids), 'the QSO''s call');
   CheckEquals(112, rx.NumberReceived, 'the QSO''s serial');

   rx := ReceivedQTCRecord('K5XYZ', 7, 2, 1028, 'S51ABC', 9);
   CheckTrue(rx.ceRecordKind = rkQTCR, 'a received QTC');
   CheckEquals('K5XYZ', string(rx.Callsign), 'Callsign: the station that sent it');
   CheckEquals('7/2', string(rx.RandomCharsReceived), 'the group as received');
   CheckEquals(0, rx.QSOPoints, 'not our numbering');
end;

procedure TWAEQTCTests.Test_ADeletedQTCRecordCountsNowhere;
var
   rx: ContestExchange;
begin
   BeginTest('Test_ADeletedQTCRecordCountsNowhere');
   rx := SentQTCRecord('DL1XYZ', 4, 1, 1200, 'S59XYZ', 1);
   CheckTrue(QTCRecordCounts(rx), 'a sent QTC counts');
   rx.ceQSO_Deleted := True;
   CheckFalse(QTCRecordCounts(rx), 'a deleted one does not');
   rx := ReceivedQTCRecord('K5XYZ', 1, 1, 1200, 'S59XYZ', 1);
   CheckTrue(QTCRecordCounts(rx), 'a received QTC counts');
   rx.ceQSO_Deleted := True;
   CheckFalse(QTCRecordCounts(rx), 'a deleted one does not');
   CheckFalse(QTCRecordCounts(ValidQso('K5XYZ')), 'a QSO is not a QTC record');

   (* THE SERIES NUMBER: the highest ever logged, deleted rows included, and
     never lowered by an older row. *)
   rx := SentQTCRecord('DL1XYZ', 4, 1, 1200, 'S59XYZ', 1);
   rx.ceQSO_Deleted := True;
   CheckEquals(4, QTCSeriesHighWater(2, rx), 'a deleted series 4 was announced: next is 5');
   CheckEquals(6, QTCSeriesHighWater(6, rx), 'an older row does not lower it');
   CheckEquals(2, QTCSeriesHighWater(2, ReceivedQTCRecord('K5XYZ', 9, 1, 1, 'A', 1)),
               'a received series is not our numbering');
end;

(* uCallSignRoutines.RootCall, measured: what the one-station rule uses. *)
procedure TWAEQTCTests.Test_TheBaseCallOfAStation;
begin
   BeginTest('Test_TheBaseCallOfAStation');
   CheckEquals('DL1AA', RootCall('DL1AA'), 'a plain call');
   CheckEquals('DL1AA', RootCall('DL1AA/P'), '/P');
   CheckEquals('DL1AA', RootCall('DL1AA/QRP'), '/QRP');
   CheckEquals('DL1AA', RootCall('EA8/DL1AA'), 'a prefix in front');
   CheckEquals('DL1AA', RootCall('DL1AA/EA8'), 'a prefix behind');
   CheckEquals('KC8UNP', RootCall('KC8UNP/6'), 'a call area');
   CheckTrue(SameQTCStation('DL1AA/P', 'dl1aa'), 'one station, whatever the case');
   CheckTrue(SameQTCStation('EA8/DL1AA', 'DL1AA'),
             'EA8/DL1AA is DL1AA for QTC purposes (the conservative reading)');
   CheckFalse(SameQTCStation('DL1AB', 'DL1AA'), 'two stations');
   CheckFalse(SameQTCStation('', ''), 'no call is no station');
   CheckEquals('', RootCall('W1'), 'RootCall gives nothing for two characters ...');
   CheckEquals('W1', QTCQuotaKey('W1'), '... so the quota key is the call itself');
   CheckFalse(SameQTCStation('W1', 'W2'), 'and W1 and W2 stay two stations');
end;

procedure TWAEQTCTests.Test_WhichQSOsABookMayOffer;
var
   rx: ContestExchange;
begin
   BeginTest('Test_WhichQSOsABookMayOffer');
   CheckTrue(QSOMayBeReportedInQTC(ValidQso('S59XYZ'), 'DL1AA'), 'a valid QSO');

   rx := ValidQso('S59XYZ');
   rx.ceQSO_Deleted := True;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'deleted');
   rx := ValidQso('S59XYZ');
   rx.ceDupe := True;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'a dupe');
   rx := ValidQso('S59XYZ');
   rx.ceXQSO := True;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'the operator''s X-QSO');
   rx := ValidQso('S59XYZ');
   rx.ceOffContest := True;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'the contest''s off-contest rule');
   rx := ValidQso('S59XYZ');
   rx.QSOPoints := 0;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'zero points: 160 m or not a contest QSO');
   rx := ValidQso('S59XYZ');
   rx.ceWasSendInQTC := True;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'already sent in a QTC');
   rx := ValidQso('S59XYZ');
   rx.Band := NoBand;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'no band');
   rx := ValidQso('S59XYZ');
   rx.ceRecordKind := rkNote;
   CheckFalse(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'a note');

   CheckFalse(QSOMayBeReportedInQTC(ValidQso('DL1AA'), 'DL1AA'),
              'the receiving station''s own QSO');
   CheckFalse(QSOMayBeReportedInQTC(ValidQso('DL1AA/P'), 'DL1AA'),
              'by base call: its /P QSO too (the old exact compare offered it)');
   CheckFalse(QSOMayBeReportedInQTC(ValidQso('DL1AA'), 'DL1AA/P'),
              'and the other way round');

   (* SERIAL 000 (section 5: "QSOs logged with 000 give only credit if a new
     multi is worked"). Not excluded: the rules do not say a 000 QSO may not
     be reported. OPEN QUESTION for NY4I; this pins today's answer. *)
   rx := ValidQso('S59XYZ');
   rx.NumberReceived := 0;
   CheckTrue(QSOMayBeReportedInQTC(rx, 'DL1AA'), 'serial 000 is offered (open question)');
end;

procedure TWAEQTCTests.Test_TheQuotaIsKeptByBaseCall;
begin
   BeginTest('Test_TheQuotaIsKeptByBaseCall');
   QTCDataArray := Default(QTCDataArrayType);
   NumberQTCStations := 0;
   TotalNumberQTCsProcessed := 0;
   IncrementQTCCount('DL1AA/P');
   IncrementQTCCount('DL1AA');
   CheckEquals(2, NumberQTCsThisStation('DL1AA'), 'one station, two QTCs');
   CheckEquals(2, NumberQTCsThisStation('DL1AA/QRP'), 'asked by another spelling');
   CheckEquals(1, NumberQTCStations, 'one row on the books');
   DecrementQTCCount('DL1AA/P', 1);
   CheckEquals(1, NumberQTCsThisStation('DL1AA'), 'the decrement finds the same row');
   QTCDataArray := Default(QTCDataArrayType);
   NumberQTCStations := 0;
   TotalNumberQTCsProcessed := 0;
end;

procedure TWAEQTCTests.Test_ASeriesAndItsMarksAreOneCommit;
var
   r1, r2, r3: Int64;
   records: array of ContestExchange;
   marked: TLogRowUpdates;
   rec: ContestExchange;
begin
   BeginTest('Test_ASeriesAndItsMarksAreOneCommit');
   StartEmptyStore;
   try
      r1 := LogQso('S59AAA', 1);
      r2 := LogQso('S59BBB', 2);
      r3 := LogQso('S59CCC', 3);
      SetLength(records, 2);
      records[0] := SentQTCRecord('DL1XYZ', 1, 2, 1301, 'S59AAA', 431);
      records[1] := SentQTCRecord('DL1XYZ', 1, 2, 1302, 'S59BBB', 431);
      records[0].ceContest := Contest;
      records[1].ceContest := Contest;
      marked := TLogRowUpdates.Create;
      try
         CheckTrue(LogStoreAppendQTCSeries(records, [r1, r2], marked), 'the series commits');
         CheckEquals(2, marked.Count, 'both QSOs marked, for the network');
      finally
         marked.Free;
      end;
      CheckEquals(2, CountRows('SELECT COUNT(1) FROM qso WHERE record_kind = ''QTCS'''),
                  'two QTC rows');
      CheckEquals(2, CountRows('SELECT COUNT(1) FROM qso WHERE sent_in_qtc = 1'),
                  'two QSOs marked');
      CheckTrue(LogStoreRepository.LoadQSO(r3, rec), 'the third QSO reads');
      CheckFalse(rec.ceWasSendInQTC, 'and was not in the series');
   finally
      StopStore;
   end;
end;

(* THE WRITE THAT FAILS LEAVES NOTHING: the marks' UPDATE breaks the commit,
  and the series' rows go with it. The old code committed the rows first and
  marked after, so the same trap left two QTC rows whose QSOs were unmarked --
  shown below with the two calls the old SaveQTCS made. *)
procedure TWAEQTCTests.Test_AFailedCommitSavesNoQTCAndNoMark;
var
   r1, r2: Int64;
   records: array of ContestExchange;
   marked: TLogRowUpdates;
begin
   BeginTest('Test_AFailedCommitSavesNoQTCAndNoMark');
   StartEmptyStore;
   try
      r1 := LogQso('S59AAA', 1);
      r2 := LogQso('S59BBB', 2);
      TrapTheCommitOn('UPDATE');
      SetLength(records, 2);
      records[0] := SentQTCRecord('DL1XYZ', 1, 2, 1301, 'S59AAA', 431);
      records[1] := SentQTCRecord('DL1XYZ', 1, 2, 1302, 'S59BBB', 431);
      records[0].ceContest := Contest;
      records[1].ceContest := Contest;
      marked := TLogRowUpdates.Create;
      try
         CheckFalse(LogStoreAppendQTCSeries(records, [r1, r2], marked),
                    'a series whose commit fails answers False');
         CheckEquals(0, marked.Count, 'and hands back no mark');
      finally
         marked.Free;
      end;
      LogStoreForgetFailureForTests;
      CheckEquals(0, CountRows('SELECT COUNT(1) FROM qso WHERE record_kind = ''QTCS'''),
                  'no QTC row on disk');
      CheckEquals(0, CountRows('SELECT COUNT(1) FROM qso WHERE sent_in_qtc = 1'),
                  'no QSO marked');

      (* THE OLD SHAPE, same trap: append each row, then mark. *)
      CheckTrue(LogStoreEnsureOpen, 'the store reopens');
      CheckTrue(LogStoreAppendQSO(records[0]), 'old shape: a row commits on its own');
      marked := TLogRowUpdates.Create;
      try
         CheckFalse(LogStoreMarkSentInQTC([r1], marked), 'old shape: the mark fails');
      finally
         marked.Free;
      end;
      LogStoreForgetFailureForTests;
      CheckEquals(1, CountRows('SELECT COUNT(1) FROM qso WHERE record_kind = ''QTCS'''),
                  'old shape: a QTC row is in the log ...');
      CheckEquals(0, CountRows('SELECT COUNT(1) FROM qso WHERE sent_in_qtc = 1'),
                  '... whose QSO is not marked -- what one commit prevents');
   finally
      StopStore;
   end;
end;

(* THE SPONSOR'S LINE: QTC: QRG, MODE, DATE, TIME, CALL-RX, QTC-GRP, CALL-TX,
  TIME-QSO, CALL-QSO, NR-QSO. *)
procedure TWAEQTCTests.Test_TheCabrilloQTCLines;
var
   records: array of ContestExchange;
   marked: TLogRowUpdates;
   cabrillo: string;
   lines, words: TStringList;
   i, qtcLines, qsoLines: integer;
   deleted: ContestExchange;

   procedure Stamp(var aRec: ContestExchange; aMinute: integer);
   begin
      aRec.ceContest := Contest;
      aRec.Band := Band20;
      aRec.Mode := CW;
      aRec.ExtMode := eCW;
      aRec.tSysTime.qtYear := 26;
      aRec.tSysTime.qtMonth := 8;
      aRec.tSysTime.qtDay := 8;
      aRec.tSysTime.qtHour := 14;
      aRec.tSysTime.qtMinute := aMinute;
      aRec.ceQSOID1 := 9500 + aMinute;
      aRec.ceQSOID2 := 9600 + aMinute;
   end;

   procedure SplitWords(const aLine: string);
   var
      p: integer;
      w: string;
   begin
      words.Clear;
      w := '';
      for p := 1 to Length(aLine) do
         begin
         if aLine[p] = ' ' then
            begin
            if w <> '' then
               begin
               words.Add(w);
               end;
            w := '';
            end
         else
            begin
            w := w + aLine[p];
            end;
         end;
      if w <> '' then
         begin
         words.Add(w);
         end;
   end;

begin
   BeginTest('Test_TheCabrilloQTCLines');
   StartEmptyStore;
   lines := TStringList.Create;
   words := TStringList.Create;
   try
      Settings.My.Call := 'K5ZZZ';
      LogQso('S59AAA', 1);
      LogQso('S59BBB', 2);

      (* SENT: series 3, offered as 10 and stopped after 6 confirmed. *)
      SetLength(records, 6);
      for i := 0 to 5 do
         begin
         records[i] := SentQTCRecord('DL1XYZ', 3, 6, 1330 + i,
                                     'S5' + IntToStr(i) + 'XYZ', 100 + i);
         Stamp(records[i], 20);
         end;
      marked := TLogRowUpdates.Create;
      try
         CheckTrue(LogStoreAppendQTCSeries(records, [], marked), 'the sent series commits');
      finally
         marked.Free;
      end;

      (* RECEIVED: series 7 of two lines. *)
      SetLength(records, 2);
      records[0] := ReceivedQTCRecord('K5XYZ', 7, 2, 1028, 'S51ABC', 9);
      records[1] := ReceivedQTCRecord('K5XYZ', 7, 2, 1029, 'S51ABD', 10);
      Stamp(records[0], 30);
      Stamp(records[1], 30);
      marked := TLogRowUpdates.Create;
      try
         CheckTrue(LogStoreAppendQTCSeries(records, [], marked), 'the received series commits');
      finally
         marked.Free;
      end;

      (* A DELETED QTC ROW (a peer's or an import's -- the windows cannot make
        one): it must not be a Cabrillo line. *)
      deleted := SentQTCRecord('DL1XYZ', 4, 1, 1340, 'S59DEL', 77);
      Stamp(deleted, 40);
      deleted.ceQSO_Deleted := True;
      CheckTrue(LogStoreAppendQSO(deleted), 'the deleted QTC row is stored');

      PostUnit.CreateCabrilloFile;
      cabrillo := ReadWhole(FDir + 'wae_qtc.log');
      CheckTrue(cabrillo <> '', 'the Cabrillo is written');
      lines.Text := cabrillo;

      CheckEquals(0, Pos('S59DEL', cabrillo), 'the deleted QTC row is not written');
      qtcLines := 0;
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('QTC: ', lines[i]) = 1 then
            begin
            Inc(qtcLines);
            SplitWords(lines[i]);
            CheckEquals(11, words.Count, 'eleven fields: ' + lines[i]);
            if words.Count <> 11 then
               begin
               Continue;
               end;
            CheckEquals(Trim(string(tCabrilloFreqString[Band20])), words[1], 'QRG: ' + lines[i]);
            CheckEquals('CW', words[2], 'MODE');
            CheckEquals('2026-08-08', words[3], 'DATE');
            if words[6] = '3/6' then
               begin
               CheckEquals('1420', words[4], 'TIME of the transfer');
               CheckEquals('DL1XYZ', words[5], 'CALL-RX of a sent QTC: the receiver');
               CheckEquals('K5ZZZ', words[7], 'CALL-TX: us');
               CheckTrue(AnsiStartsStr('13', words[8]), 'TIME-QSO');
               CheckTrue(AnsiStartsStr('S5', words[9]), 'CALL-QSO');
               end
            else
               begin
               CheckEquals('7/2', words[6], 'the received group');
               CheckEquals('K5ZZZ', words[5], 'CALL-RX of a received QTC: us');
               CheckEquals('K5XYZ', words[7], 'CALL-TX: the sender');
               CheckTrue((words[8] = '1028') or (words[8] = '1029'), 'TIME-QSO');
               end;
            end;
         end;
      CheckEquals(8, qtcLines, 'six sent and two received lines, the deleted one left out');
      CheckTrue(Pos('QTC: ' + Format('%5s', [string(tCabrilloFreqString[Band20])]) +
                    ' CW 2026-08-08 1420 DL1XYZ        3/6        K5ZZZ         1330 S50XYZ        100',
                    cabrillo) > 0, 'a whole sent line, the writer''s columns');
      qsoLines := 0;
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('QSO: ', lines[i]) = 1 then
            begin
            Inc(qsoLines);
            end;
         end;
      CheckEquals(2, qsoLines, 'the two QSO lines, and no QTC row written as one');
   finally
      words.Free;
      lines.Free;
      StopStore;
   end;
end;

procedure TWAEQTCTests.RunAllTests;
begin
   Test_TheSeriesIsTheQTCsTransferred;
   Test_ADeletedQTCRecordCountsNowhere;
   Test_TheBaseCallOfAStation;
   Test_WhichQSOsABookMayOffer;
   Test_TheQuotaIsKeptByBaseCall;
   Test_ASeriesAndItsMarksAreOneCommit;
   Test_AFailedCommitSavesNoQTCAndNoMark;
   Test_TheCabrilloQTCLines;
end;

end.
