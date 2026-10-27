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

(* WHAT THE MULTI-OP TESTS THAT NEED A LOG HAVE IN COMMON (Phase 1, C6).

  uTestNetResend and uTestNetCatchUp both work against a REAL SQLite log in a
  scratch directory, with the contest set to a legacy one and a station's HELLO
  fed through the real receive arm. They were one copy; the second caller is the
  moment to lift it out, so there is one.

  A scratch log never touches a real one: the directory is under the system temp
  directory and named for the process, and TR4W_LOG_FILENAME is pointed at it
  for the length of the test and put back. *)
unit uTestNetSupport;

{$I ..\..\src\tr4w.inc}

interface

uses
   Classes, VC, uTR4WTestFramework;

type
   TNetStoreTestCase = class(TTestCase)
   protected
      FDir: string;
      FTrw: string;
      FDb: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
      FSavedContest: TContestHandle;

      (* A new, empty scratch log, open, with the contest set to ARRL DX CW and
        any earlier refusal forgotten. *)
      procedure OpenScratchStore;
      procedure CloseScratchStore;

      (* One row, stored the way a QSO the operator logged is: as the caller made
        it, with the flags it is to start with. Returns the record. *)
      function AppendRow(const aCall: string; aId1, aId2: Cardinal;
                         aSent, aDirty: boolean): ContestExchange;

      (* The stored row with this network key. *)
      function ReadRow(aId1, aId2: Cardinal; out aRec: ContestExchange): boolean;
      function ReadFlags(aId1, aId2: Cardinal; out aSent, aDirty: boolean): boolean;
      function RowSent(aId1, aId2: Cardinal): boolean;
      function RowDirty(aId1, aId2: Cardinal): boolean;

      (* How many rows the log holds. *)
      function LogRowCount: integer;

      (* A HELLO through the real receive arm: the server's own (station 0), or a
        station's with the contest it announces. *)
      procedure FeedHello(const aStation: Byte; const aContestId: string);
   end;

(* ONE NUMBER FROM ONE SQL STATEMENT, read from a log FILE on a connection of its
  own, read-only: how many rows a backup holds, what a row's my_source is. The
  live log is not asked, so what it says is what a second reader would see. *)
function ScalarOfLogFile(const aFileName, aSql: string): Int64;

implementation

uses
   SysUtils, sqldb, FileUtil, utils_text, TF, uNet, uNetHello, uLogStore, uLogDatabase,
   uLogRepository, uContestRegistry, PostUnit;

function ScalarOfLogFile(const aFileName, aSql: string): Int64;
var
   db: TLogDatabase;
   q: TSQLQuery;
begin
   Result := -1;
   db := TLogDatabase.Create;
   try
      db.OpenReadOnly(aFileName);
      q := TSQLQuery.Create(nil);
      try
         q.DataBase := db.Connection;
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

procedure TNetStoreTestCase.OpenScratchStore;
const
   SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   if FDir = '' then
      begin
      FDir := IncludeTrailingPathDelimiter(GetTempDir) +
              'tr4w_netstore_' + IntToStr(GetProcessID);
      ForceDirectories(FDir);
      end;

   (* THE STORE MUST START CLOSED, or EnsureOpen answers from whatever log an
     earlier suite left open and nothing below is about this scratch one. *)
   LogStoreClose;

   (* NOTHING AN EARLIER TEST LEFT: a backup folder, a backup. *)
   DeleteDirectory(FDir, True);
   ForceDirectories(FDir);

   FTrw := IncludeTrailingPathDelimiter(FDir) + 'netstore.trw';
   FDb := LogDatabaseFileName(FTrw);
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(FDb + SUFFIXES[i]) then
         begin
         DeleteFile(FDb + SUFFIXES[i]);
         end;
      end;

   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   (* No operator: a failure is a log line and a False, not a modal. *)
   FSavedSilent := tSilentExport;
   tSilentExport := True;
   FSavedContest := Contest;
   Contest := ContestHandleOf(ARRLDXCW);
   (* A refusal an earlier suite left standing would silence the catch-up. *)
   ForgetServerRefusal;

   CheckTrue(LogStoreEnsureOpen, 'the scratch log opens (a new log, no .trw)');
end;

procedure TNetStoreTestCase.CloseScratchStore;
const
   SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');
var
   i: integer;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   tSilentExport := FSavedSilent;
   Contest := FSavedContest;
   for i := Low(SUFFIXES) to High(SUFFIXES) do
      begin
      if FileExists(FDb + SUFFIXES[i]) then
         begin
         DeleteFile(FDb + SUFFIXES[i]);
         end;
      end;
   (* The whole scratch directory, backups and all. *)
   if (FDir <> '') and DeleteDirectory(FDir, False) then
      begin
      FDir := '';
      end;
end;

function TNetStoreTestCase.AppendRow(const aCall: string; aId1, aId2: Cardinal;
                                     aSent, aDirty: boolean): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := Contest;
   Result.Callsign := ShortString(aCall);
   Result.ceQSOID1 := aId1;
   Result.ceQSOID2 := aId2;
   Result.ceSendToServer := aSent;
   Result.ceNeedSendToServerAE := aDirty;
   Result.Band := Band20;
   Result.Mode := CW;
   Result.Frequency := 14025000;
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 6;
   Result.tSysTime.qtDay := 1;
   Result.tSysTime.qtHour := 12;
   Result.tSysTime.qtMinute := 30;
   Result.tSysTime.qtSecond := 15;
   CheckTrue(LogStoreAppendQSO(Result), 'row ' + aCall + ' is stored');
end;

function TNetStoreTestCase.ReadRow(aId1, aId2: Cardinal;
                                   out aRec: ContestExchange): boolean;
var
   repo: TLogRepository;
   rec: ContestExchange;
begin
   Result := False;
   aRec := Default(ContestExchange);
   repo := LogStoreRepository;
   if repo = nil then
      begin
      Exit;
      end;

   repo.OpenSequentialRead;
   try
      while repo.ReadNext(rec) do
         begin
         if (rec.ceQSOID1 = aId1) and (rec.ceQSOID2 = aId2) then
            begin
            aRec := rec;
            Result := True;
            Break;
            end;
         end;
   finally
      repo.CloseSequentialRead;
   end;
end;

function TNetStoreTestCase.ReadFlags(aId1, aId2: Cardinal;
                                     out aSent, aDirty: boolean): boolean;
var
   rec: ContestExchange;
begin
   Result := ReadRow(aId1, aId2, rec);
   aSent := Result and rec.ceSendToServer;
   aDirty := Result and rec.ceNeedSendToServerAE;
end;

function TNetStoreTestCase.RowSent(aId1, aId2: Cardinal): boolean;
var
   dirty: boolean;
begin
   CheckTrue(ReadFlags(aId1, aId2, Result, dirty),
             'row ' + IntToStr(aId1) + '/' + IntToStr(aId2) + ' is in the log');
end;

function TNetStoreTestCase.RowDirty(aId1, aId2: Cardinal): boolean;
var
   sent: boolean;
begin
   CheckTrue(ReadFlags(aId1, aId2, sent, Result),
             'row ' + IntToStr(aId1) + '/' + IntToStr(aId2) + ' is in the log');
end;

function TNetStoreTestCase.LogRowCount: integer;
begin
   Result := 0;
   if LogStoreRepository <> nil then
      begin
      Result := integer(LogStoreRepository.RecordCount);
      end;
end;

procedure TNetStoreTestCase.FeedHello(const aStation: Byte; const aContestId: string);
var
   hello: THelloMessage;
   desync: boolean;
begin
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, aStation, '5.0.99', aContestId, hello),
             'the hello can be built');
   THelloMessagePtr(@NetBuffer[1])^ := hello;
   CheckEquals(SizeOf(THelloMessage), ConsumeNetBuffer(SizeOf(THelloMessage), desync),
               'the whole hello was consumed');
   CheckFalse(desync, 'and the stream stayed on a message boundary');
end;

end.
