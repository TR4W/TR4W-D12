unit uServerLogStore;
{$I tr4w.inc}

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

(*
  THE TR4WSERVER LOG BEHIND ONE SEAM (docs/TR4WSERVER_SQLITE_DESIGN.md, phase P1,
  2026-11-19).

  Until now tr4wserverUnit held a TFileStream on SERVERLOG.TRW and did thirty-odd
  things to it. This unit is that code MOVED, not rewritten: TServerLogStore says
  what the server asks of its log, TFileServerLogStore answers from the flat file,
  and the file is the ONLY implementation. A second one (SQLite, phase P2) is now
  possible without touching the server's message handling.

  NO BEHAVIOUR CHANGED. Not one byte on the wire or in the file: the file layout
  is a header record (SizeOfTLogHeader, 376 bytes) followed by whole
  ContestExchange records in arrival order, and every routine below is the body
  it had in tr4wserverUnit, open and close and hold included.

  A LEAF, like uServerQsoIndex and uServerLogHealth: it knows the record (VC), a
  stream, the held-QSO set and the CRC, and nothing of the server, the window or
  Indy, so it is unit tested on a scratch file. What the server does about a
  write that failed (the intercom notice, the window line) is handed in as three
  plain callbacks, so the order of events is the one the server always had.

  HOLD / RELEASE. The server holds the file open across a run of consecutive
  OFFLINEQSO packets (issue 149) and flushes once. While held, every internal
  open is satisfied by the open stream and a close does nothing; Release flushes
  and closes. Phase P2 maps the same pair onto one transaction.

  OpenImage IS THE SYNC PORT'S STREAM, AND IT IS NOT A SNAPSHOT (design 6.2). It
  returns a FRESH read stream over the live file; the sync port reads the size
  and then writes the stream in two separate reads while the main thread may be
  appending. THAT HAZARD IS DELIBERATELY NOT FIXED HERE (P1 changes nothing).
  It is called from an Indy connection thread, so it touches only the immutable
  file name. A SQLite store returns a snapshot.
*)

interface

uses
   SysUtils,
   Classes,
   VC,
   Log4D,
   uCRC32,
   uServerQsoIndex;

type
   (* HOW THE LOG SHOULD BEHAVE WHEN IT IS NOT THERE. *)
   TServerLogOpenMode = (
      slOpenExisting,   // fail if the log is not there
      slOpenAlways);    // create it if it is not

   (* WHAT Initialize FOUND. *)
   TServerLogInit = (
      silReady,         // open, header present, ready for use
      silCannotOpen,    // the file could not be opened or created
      silBadSize);      // the size is not a whole number of records; left untouched

   TServerLogReasonEvent = procedure(const aReason: string);
   TServerLogNoticeEvent = procedure;
   TServerLogCountEvent = procedure(aCount: integer);

   TServerLogStore = class(TObject)
   public
      (* A write failed (the reason), a write worked, and the number of QSOs the
        log holds changed. All three are called at the point in the sequence where
        the server always made the same call; any may be nil. *)
      OnWriteFailed: TServerLogReasonEvent;
      OnWritten: TServerLogNoticeEvent;
      OnCountChanged: TServerLogCountEvent;
      (* The server's logger; nil in a test. *)
      Logger: TLogLogger;

      (* Open the log, creating it if need be; write the header into an empty one.
        aByteSize is the size found, for the bad-size message. *)
      function Initialize(out aByteSize: Int64): TServerLogInit; virtual; abstract;
      (* Keep the log open across a run of OFFLINEQSO packets. Release flushes once
        and closes; it does nothing when no hold is in force. *)
      procedure Hold; virtual; abstract;
      procedure Release; virtual; abstract;
      (* Append one record, all or nothing. False when nothing was stored. aFlush
        False is for a held run. *)
      function Append(const aRec: ContestExchange; aFlush: boolean): boolean; virtual; abstract;
      (* Rewrite the NEWEST record with this (ceQSOID1, ceQSOID2). False when the
        log could not be read or the record not written back; True otherwise,
        including when no record has the pair. *)
      function UpdateNewest(const aRec: ContestExchange): boolean; virtual; abstract;
      (* Does the log hold this pair? False for (0, 0) and for a log that cannot
        be opened. *)
      function Holds(aId1, aId2: Cardinal): boolean; virtual; abstract;
      (* Remove every QSO, keeping the header. False when the log cannot be opened. *)
      function Clear: boolean; virtual; abstract;
      (* Set the clear-dupesheet bit (actSetClearDupesheetBit) or clear the
        multiplier flags (actClearMults) on every QSO record. False when the log
        cannot be opened or holds no QSO. *)
      function ClearFlags(aAction: UpadateAction): boolean; virtual; abstract;
      (* The largest NumberSent in the log (0 for none). False when it cannot be
        opened. *)
      function MaxNumberSent(out aMax: integer): boolean; virtual; abstract;
      (* The size of the image, the first QSO's contest and the CRC32 of the whole
        image -- what the log-info packet carries. False when it cannot be opened. *)
      function Describe(out aSize: Int64; out aContest: TContestHandle;
                        out aCrc: Cardinal): boolean; virtual; abstract;
      (* The number of QSOs, or -1 when the log cannot be opened. *)
      function Count: integer; virtual; abstract;
      (* THE IMAGE THE SYNC PORT SENDS: header, then every record, in arrival
        order. A fresh stream the caller frees; raises when it cannot be made. *)
      function OpenImage: TStream; virtual; abstract;
   end;

   TFileServerLogStore = class(TServerLogStore)
   private
      FFileName: string;
      FStream: TFileStream;
      FOpened: boolean;
      FHeld: boolean;
      FIndex: TServerQsoIndex;
      FCrc: Cardinal;
      FCrcStale: boolean;
      function OpenLog(aMode: TServerLogOpenMode): boolean;
      procedure CloseLog;
      function AppendOpen(const aRec: ContestExchange): boolean;
      procedure NoteStored(const aRec: ContestExchange);
      procedure NoteChanged;
      function RecordsOpen: integer;
      function CurrentCrc: Cardinal;
      procedure ReportFailure(const aReason: string);
      procedure ReportWritten;
      procedure LogError(const aFormat: string; const aArgs: array of const);
   public
      constructor Create(const aFileName: string);
      destructor Destroy; override;
      function Initialize(out aByteSize: Int64): TServerLogInit; override;
      procedure Hold; override;
      procedure Release; override;
      function Append(const aRec: ContestExchange; aFlush: boolean): boolean; override;
      function UpdateNewest(const aRec: ContestExchange): boolean; override;
      function Holds(aId1, aId2: Cardinal): boolean; override;
      function Clear: boolean; override;
      function ClearFlags(aAction: UpadateAction): boolean; override;
      function MaxNumberSent(out aMax: integer): boolean; override;
      function Describe(out aSize: Int64; out aContest: TContestHandle;
                        out aCrc: Cardinal): boolean; override;
      function Count: integer; override;
      function OpenImage: TStream; override;
      property FileName: string read FFileName;
   end;

implementation

constructor TFileServerLogStore.Create(const aFileName: string);
begin
   inherited Create;
   FFileName := aFileName;
   FCrcStale := True;
end;

destructor TFileServerLogStore.Destroy;
begin
   FreeAndNil(FStream);
   FreeAndNil(FIndex);
   inherited Destroy;
end;

procedure TFileServerLogStore.ReportFailure(const aReason: string);
begin
   if Assigned(OnWriteFailed) then
      begin
      OnWriteFailed(aReason);
      end;
end;

procedure TFileServerLogStore.ReportWritten;
begin
   if Assigned(OnWritten) then
      begin
      OnWritten;
      end;
end;

procedure TFileServerLogStore.LogError(const aFormat: string; const aArgs: array of const);
begin
   if Logger <> nil then
      begin
      Logger.Error(aFormat, aArgs);
      end;
end;

(* THE CHANGE EVERY SUCCESSFUL WRITE MAKES: the cached CRC is stale and the
  window's QSO count is told. The count is (size - 4) div the record size, as it
  has always been; for a header plus N whole records that is N. The log must be
  open. *)
function TFileServerLogStore.RecordsOpen: integer;
begin
   Result := integer((FStream.Size - 4) div SizeOf(ContestExchange));
end;

procedure TFileServerLogStore.NoteChanged;
begin
   FCrcStale := True;
   if Assigned(OnCountChanged) then
      begin
      OnCountChanged(RecordsOpen);
      end;
end;

function TFileServerLogStore.OpenLog(aMode: TServerLogOpenMode): boolean;
begin
   Result := False;
   if FOpened then
      begin
      (* Open because it is held: the caller may use it. Open for any other
        reason: a re-entrant open, refused as it always was. *)
      Result := FHeld;
      Exit;
      end;

   try
      if (aMode = slOpenAlways) and (not FileExists(FFileName)) then
         begin
         FStream := TFileStream.Create(FFileName, fmCreate or fmShareDenyNone);
         end
      else
         begin
         FStream := TFileStream.Create(FFileName, fmOpenReadWrite or fmShareDenyNone);
         end;
      Result := True;
   except
      on E: Exception do
         begin
         LogError('[Log] cannot open %s: %s', [FFileName, E.Message]);
         FreeAndNil(FStream);
         Result := False;
         end;
   end;

   FOpened := Result;
end;

procedure TFileServerLogStore.CloseLog;
begin
   if FHeld then
      begin
      Exit;
      end;
   FreeAndNil(FStream);
   FOpened := False;
end;

function TFileServerLogStore.Initialize(out aByteSize: Int64): TServerLogInit;
begin
   Result := silCannotOpen;
   aByteSize := 0;
   if not OpenLog(slOpenAlways) then
      begin
      Exit;
      end;
   try
      aByteSize := FStream.Size;
      if (FStream.Size mod SizeOf(ContestExchange)) <> 0 then
         begin
         Result := silBadSize;
         Exit;
         end;
      if FStream.Size = 0 then
         begin
         FStream.WriteBuffer(LogHeader, SizeOfTLogHeader);
         end;
      NoteChanged;
      Result := silReady;
   finally
      CloseLog;
   end;
end;

procedure TFileServerLogStore.Hold;
begin
   if FHeld then
      begin
      Exit;
      end;
   if OpenLog(slOpenExisting) then
      begin
      FHeld := True;
      end;
end;

procedure TFileServerLogStore.Release;
begin
   if not FHeld then
      begin
      Exit;
      end;
   FHeld := False;
   try
      FileFlush(FStream.Handle);
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.Holds(aId1, aId2: Cardinal): boolean;
begin
   Result := False;
   if (aId1 = 0) and (aId2 = 0) then
      begin
      Exit;
      end;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      if FIndex = nil then
         begin
         FIndex := TServerQsoIndex.Create;
         end;
      (* THE FILE IS THE AUTHORITY: a set built from a log of another size is
        stale -- the file was cleared, replaced or appended to by someone else --
        and is built again. *)
      if not FIndex.ReflectsLog(FStream.Size) then
         begin
         FIndex.LoadFromLog(FStream, SizeOfTLogHeader);
         end;
      Result := FIndex.Contains(aId1, aId2);
   finally
      CloseLog;
   end;
end;

(* The server has just appended aRec to the log, which is OPEN. Keeps the set of
  held QSOs in step, when it has been built. *)
procedure TFileServerLogStore.NoteStored(const aRec: ContestExchange);
begin
   if FIndex = nil then
      begin
      Exit;
      end;
   FIndex.Add(aRec.ceQSOID1, aRec.ceQSOID2);
   FIndex.NoteLogSize(FStream.Size);
end;

(* ALL OR NOTHING (issue 314). A write that fails -- a full disk above all --
  raises from deep inside the stream, and a record cut short at the end of the
  file shifts every later record by the remainder. This trims the file back to
  the size it had before the write, logs the reason, and answers False; it never
  raises. The log must be open. *)
function TFileServerLogStore.AppendOpen(const aRec: ContestExchange): boolean;
var
   sizeBefore: Int64;
begin
   Result := False;
   sizeBefore := FStream.Size;
   try
      FStream.Seek(0, soEnd);
      FStream.WriteBuffer(aRec, SizeOf(ContestExchange));
      Result := True;
      ReportWritten;
   except
      on E: Exception do
         begin
         LogError('[Log] cannot append to the server log: %s -- the QSO %s (%d/%d) is NOT stored; trimming the file back to %d bytes',
                  [E.Message, string(aRec.Callsign), aRec.ceQSOID1, aRec.ceQSOID2, sizeBefore]);
         ReportFailure(E.Message);
         try
            FStream.Size := sizeBefore;
         except
            on E2: Exception do
               begin
               LogError('[Log] cannot trim the server log back to %d bytes: %s -- it may end in a partial record',
                        [sizeBefore, E2.Message]);
               end;
         end;
         end;
   end;
end;

function TFileServerLogStore.Append(const aRec: ContestExchange; aFlush: boolean): boolean;
begin
   Result := False;
   if not OpenLog(slOpenExisting) then
      begin
      ReportFailure('cannot open the log');
      Exit;
      end;
   try
      if AppendOpen(aRec) then
         begin
         if aFlush then
            begin
            FileFlush(FStream.Handle);
            end;
         NoteStored(aRec);
         NoteChanged;
         Result := True;
         end;
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.UpdateNewest(const aRec: ContestExchange): boolean;
var
   old: ContestExchange;
   bytesRead: integer;
   filePointer: integer;
   finished: boolean;
begin
   Result := True;
   if not OpenLog(slOpenExisting) then
      begin
      Result := False;
      ReportFailure('cannot open the log');
      Exit;
      end;
   (* CLOSED IN A FINALLY, AND NEVER RAISING (issue 314): an exception that skipped
     the close left the log open, and every later open was refused. The walk goes
     back from the end one record at a time and stops at the start of the file; a
     record that is rewritten and then fails is put back as it was. *)
   try
      try
         filePointer := -1;
         finished := False;
         while (not finished) and
               (Int64(-filePointer) * SizeOf(ContestExchange) <= FStream.Size) do
            begin
            FStream.Seek(Int64(filePointer) * SizeOf(ContestExchange), soEnd);
            bytesRead := FStream.Read(old, SizeOf(ContestExchange));
            if bytesRead <> SizeOf(ContestExchange) then
               begin
               finished := True;
               end
            else if (old.ceQSOID1 = aRec.ceQSOID1) and
                    (old.ceQSOID2 = aRec.ceQSOID2) then
               begin
               FStream.Seek(Int64(filePointer) * SizeOf(ContestExchange), soEnd);
               try
                  FStream.WriteBuffer(aRec, SizeOf(ContestExchange));
                  ReportWritten;
               except
                  on E: Exception do
                     begin
                     Result := False;
                     LogError('[Log] cannot rewrite the edited QSO %s (%d/%d) in the server log: %s',
                              [string(aRec.Callsign), aRec.ceQSOID1, aRec.ceQSOID2, E.Message]);
                     ReportFailure(E.Message);
                     try
                        FStream.Seek(Int64(filePointer) * SizeOf(ContestExchange), soEnd);
                        FStream.WriteBuffer(old, SizeOf(ContestExchange));
                     except
                        on E2: Exception do
                           begin
                           LogError('[Log] and the old record could not be put back: %s', [E2.Message]);
                           end;
                     end;
                     end;
               end;
               FCrcStale := True;
               finished := True;
               end
            else
               begin
               dec(filePointer);
               end;
            end;
      except
         on E: Exception do
            begin
            Result := False;
            LogError('[Log] cannot search the server log for an edited QSO: %s', [E.Message]);
            ReportFailure(E.Message);
            end;
      end;
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.Clear: boolean;
begin
   Result := False;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      FStream.Seek(Int64(SizeOfTLogHeader), soBeginning);
      FStream.Size := FStream.Position;
      if FIndex <> nil then
         begin
         FIndex.Clear;
         end;
      NoteChanged;
      Result := True;
   finally
      CloseLog;
   end;
end;

(* READ, MODIFY, WRITE BACK. The walk is an indexed one over a buffer this routine
  owns (never pointer arithmetic: that truncated to 32 bits on Win64, 2026-09-14);
  the file is written back in one write, and only when it holds a QSO record. *)
function TFileServerLogStore.ClearFlags(aAction: UpadateAction): boolean;
var
   buf: TBytes;
   records: ContestExchangeArrayPtr;
   rec: ContestExchangePtr;
   qsoCount: Int64;
   i: Int64;
begin
   Result := False;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      if FStream.Size <= SizeOf(TLogHeader) then
         begin
         Exit;
         end;
      qsoCount := (FStream.Size - SizeOf(TLogHeader)) div SizeOfContestExchange;

      SetLength(buf, FStream.Size);
      FStream.Position := 0;
      FStream.ReadBuffer(buf[0], Length(buf));
      records := ContestExchangeArrayPtr(@buf[SizeOfTLogHeader]);

      for i := 0 to qsoCount - 1 do
         begin
         rec := @records^[i];
         if rec^.ceRecordKind = rkQSO then
            begin
            if aAction = actSetClearDupesheetBit then
               begin
               rec^.ceClearDupeSheet := True;
               end;
            if aAction = actClearMults then
               begin
               rec^.ceClearMultSheet := True;
               rec^.DomesticMult := False;
               rec^.DXMult := False;
               rec^.PrefixMult := False;
               rec^.ZoneMult := False;
               end;
            end;
         end;

      Result := True;
      FCrcStale := True;

      FStream.Position := 0;
      FStream.WriteBuffer(buf[0], Length(buf));
      FileFlush(FStream.Handle);
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.MaxNumberSent(out aMax: integer): boolean;
var
   rec: ContestExchange;
begin
   Result := False;
   aMax := 0;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      FStream.Seek(Int64(SizeOf(ContestExchange)), soBeginning);
      while FStream.Read(rec, SizeOf(ContestExchange)) = SizeOf(ContestExchange) do
         begin
         if aMax < rec.NumberSent then
            begin
            aMax := rec.NumberSent;
            end;
         end;
      Result := True;
   finally
      CloseLog;
   end;
end;

(* THE CRC, READ INTO MEMORY: a contest log is a few megabytes (376 bytes a QSO),
  and the CRC touches every byte anyway. Cached until a write makes it stale.
  0 when the log cannot be opened. *)
function TFileServerLogStore.CurrentCrc: Cardinal;
var
   buf: TBytes;
begin
   if not FCrcStale then
      begin
      Result := FCrc;
      Exit;
      end;
   FCrc := 0;
   Result := 0;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      SetLength(buf, FStream.Size);
      if Length(buf) > 0 then
         begin
         FStream.Position := 0;
         FStream.ReadBuffer(buf[0], Length(buf));
         FCrc := uCRC32.GetCRC32(buf);
         end;
      FCrcStale := False;
      Result := FCrc;
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.Describe(out aSize: Int64; out aContest: TContestHandle;
                                      out aCrc: Cardinal): boolean;
var
   first: ContestExchange;
begin
   Result := False;
   aSize := 0;
   aContest := NoContest;
   aCrc := 0;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      aSize := FStream.Size;
      if aSize > SizeOfTLogHeader then
         begin
         first := Default(ContestExchange);
         FStream.Seek(Int64(SizeOfTLogHeader), soBeginning);
         FStream.Read(first, SizeOf(ContestExchange));
         aContest := first.ceContest;
         end;
   finally
      CloseLog;
   end;
   aCrc := CurrentCrc;
   Result := True;
end;

function TFileServerLogStore.Count: integer;
begin
   Result := -1;
   if not OpenLog(slOpenExisting) then
      begin
      Exit;
      end;
   try
      Result := RecordsOpen;
   finally
      CloseLog;
   end;
end;

function TFileServerLogStore.OpenImage: TStream;
begin
   Result := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
end;

end.
