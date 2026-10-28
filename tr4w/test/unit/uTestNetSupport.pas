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
   SysUtils, Classes, SyncObjs, VC, uTR4WTestFramework, uNetCatchUp;

type
   TNetStoreTestCase = class(TTestCase)
   protected
      FDir: string;
      FTrw: string;
      FDb: string;
      FSavedLogName: string;
      FSavedSilent: boolean;
      FSavedContest: TContestHandle;
      (* The author (ceComputerID) AppendRow gives each row it stores; #0, which is
        what a station's own QSO carries here, unless a test names another. *)
      FRowAuthor: AnsiChar;

      (* A server log image: a header, then these records. Checked whole. *)
      function NewImage(const aRecords: array of ContestExchange): TServerLogImage;

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

type
   (* A WRITER WITH NO SOCKET. Records each packet it was asked to write, and can
     fail from the Nth write on or hold writes at a gate. Runs on the queue's
     writer thread. *)
   TStubLink = class
   private
      FLock: TCriticalSection;
      FWritten: TStringList;
      FLast: TNetQSOInformation;
      FAttempts: integer;
   public
      (* The 1-based number of the write from which writes fail; 0 never. *)
      FailFrom: integer;
      (* When assigned, a write waits here (5 s at most) before it does anything. *)
      Gate: TEvent;
      constructor Create;
      destructor Destroy; override;
      function Write(const aBytes: TBytes): boolean;
      function Attempts: integer;
      (* One text per packet written: Q, E, O or S, then the QSO's key. *)
      function WrittenText: string;
      function WrittenCount: integer;
      function CountOf(const aPrefix: string): integer;
      function Last: TNetQSOInformation;
   end;

(* Waits (5 s at most) until the stub has been asked to write aCount packets of
  any kind. A QSO packet's outcome is reported before the next write begins, so
  when the LAST packet is not a QSO or an edit this also means every outcome is
  in. *)
function WaitWrites(aLink: TStubLink; aCount: integer): boolean;

(* ONE NUMBER FROM ONE SQL STATEMENT, read from a log FILE on a connection of its
  own, read-only: how many rows a backup holds, what a row's my_source is. The
  live log is not asked, so what it says is what a second reader would see. *)
function ScalarOfLogFile(const aFileName, aSql: string): Int64;

implementation

uses
   sqldb, FileUtil, utils_text, TF, uNet, uNetHello, uLogStore, uLogDatabase,
   uLogRepository, uContestRegistry, PostUnit;

constructor TStubLink.Create;
begin
   inherited Create;
   FLock := TCriticalSection.Create;
   FWritten := TStringList.Create;
end;

destructor TStubLink.Destroy;
begin
   FWritten.Free;
   FLock.Free;
   inherited Destroy;
end;

function TStubLink.Write(const aBytes: TBytes): boolean;
var
   id: Word;
   kind: string;
   pkt: NetQSOInformationPtr;
begin
   if Gate <> nil then
      begin
      Gate.WaitFor(5000);
      end;

   FLock.Enter;
   try
      Inc(FAttempts);
      Result := (FailFrom = 0) or (FAttempts < FailFrom);
      if not Result then
         begin
         Exit;
         end;

      id := Word(aBytes[0]) or (Word(aBytes[1]) shl 8);
      case id of
         NET_QSOINFO_ID:        kind := 'Q';
         NET_EDITEDQSO_ID:      kind := 'E';
         NET_OFFLINEQSO_ID:     kind := 'O';
         NET_SERVERMESSAGE_ID:  kind := 'S';
      else
         kind := 'X';
      end;

      if (kind = 'Q') or (kind = 'E') or (kind = 'O') then
         begin
         pkt := NetQSOInformationPtr(@aBytes[0]);
         FLast := pkt^;
         FWritten.Add(kind + IntToStr(pkt^.qiInformation.ceQSOID1) + '/' +
                      IntToStr(pkt^.qiInformation.ceQSOID2));
         end
      else
         begin
         FWritten.Add(kind);
         end;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.Attempts: integer;
begin
   FLock.Enter;
   try
      Result := FAttempts;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.WrittenText: string;
begin
   FLock.Enter;
   try
      Result := FWritten.CommaText;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.WrittenCount: integer;
begin
   FLock.Enter;
   try
      Result := FWritten.Count;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.CountOf(const aPrefix: string): integer;
var
   i: integer;
begin
   Result := 0;
   FLock.Enter;
   try
      for i := 0 to FWritten.Count - 1 do
         begin
         if Copy(FWritten[i], 1, Length(aPrefix)) = aPrefix then
            begin
            Inc(Result);
            end;
         end;
   finally
      FLock.Leave;
   end;
end;

function TStubLink.Last: TNetQSOInformation;
begin
   FLock.Enter;
   try
      Result := FLast;
   finally
      FLock.Leave;
   end;
end;

(* Waits (5 s at most) until the stub has been asked to write aCount packets of
  any kind. A QSO packet's outcome is reported before the next write begins, so
  when the LAST packet is not a QSO or an edit this also means every outcome is
  in. *)
function WaitWrites(aLink: TStubLink; aCount: integer): boolean;
var
   started: QWord;
begin
   started := GetTickCount64;
   repeat
      Result := aLink.Attempts >= aCount;
      if not Result then
         begin
         Sleep(5);
         end;
   until Result or (GetTickCount64 - started > 5000);
end;

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

   FRowAuthor := #0;
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

function TNetStoreTestCase.NewImage(const aRecords: array of ContestExchange): TServerLogImage;
var
   header: TBytes;
   i: integer;
   why: string;
begin
   Result := TServerLogImage.Create;
   SetLength(header, SizeOfTLogHeader);
   Result.Data.WriteBuffer(header[0], SizeOfTLogHeader);
   for i := Low(aRecords) to High(aRecords) do
      begin
      Result.Data.WriteBuffer(aRecords[i], SizeOf(ContestExchange));
      end;
   CheckTrue(Result.Accept(Result.Data.Size, why), 'the image is whole: ' + why);
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
   Result.ceComputerID := FRowAuthor;
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
