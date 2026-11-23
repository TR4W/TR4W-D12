{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uGetServerLog;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  Classes,
  IdGlobal,    // TIdBytes -- the password's wire form, in FetchServerLog
  TF,
  VC,
  uWireQso,    // TWireValues -- the server's rows
  uNetCatchUp;

(* CATCHING UP FROM THE SERVER'S LOG -- Phase 1, C6 (2026-10-27).

  NY4I: "Late catch-up has to be supported as it was ... to handle a station
  that comes up (reboots) in the middle of the contest." The rules, and why
  the D7 mechanism (a CRC32 of the .TRW, then REPLACE the log with the server's
  file) could not be kept, are uNetCatchUp's header. This unit is the part that
  has a socket, a thread and a log.

  WHAT THE OPERATOR SEES, as it was in D7:

    ON CONNECT, once the server's HELLO has proved the link (uNet.
      NetServiceCatchUp): the log is fetched and compared with this one. If the
      server holds QSOs this log lacks, SERVER AUTO SYNCHRONIZE LOG ON CONNECT
      adds them; with it off the operator is ASKED, with the count. Nothing is
      said when the log is already complete.
    NET > SYNCHRONIZE WITH THE SERVER opens the window (uServerLogForm): Get server
      log downloads and SHOWS the server's log, and the button that D7 called
      "Create and use new log" now ADDS the QSOs this log lacks. It no longer
      replaces anything. A second button SENDS the QSOs this log has that the
      server lacks (a server that lost its log), as OFFLINEQSO.

  BOTH DIRECTIONS COME FROM THE ONE DOWNLOAD (2026-10-28). The image answers
    "what does the server have that I lack" (pull) and "what do I have that the
    server lacks" (push, uNetCatchUp.TPushPlan). On connect they are decided
    TOGETHER (uNetCatchUp.SyncOnConnect): with SERVER AUTO SYNCHRONIZE LOG ON
    CONNECT both just happen; with it off the operator is asked ONCE.

  THE THREADS. The download is a worker (a socket read cannot be allowed to
  freeze the keyboard). It owns its own connection and only fills memory: no
  settings, no log, no widget. The comparison, the backup, the write and the
  rescore are the MAIN thread's, because the repository is not thread-safe. The
  worker hands over by RunOnMainThread. *)
type
  (* WHO ASKED FOR THE FETCH. *)
  TCatchUpOrigin = (
     cuOnConnect,    // the link came up: add on its own, or ask
     cuInWindow      // the Synchronize window's Get server log: show, and add on request
  );

(* START A CATCH-UP FETCH. MAIN THREAD. False, and nothing started, when one is
  already under way (it is the operator's to retry) or when no contest is
  selected. *)
function StartServerCatchUp(aOrigin: TCatchUpOrigin): boolean;

(* THE MERGE: add to the contest log every record of aImage that it lacks and
  that is for this contest (uNetCatchUp.BuildCatchUpPlan), INSERT ONLY.

  MAIN THREAD. The plan is made HERE, from the keys the log holds at this
  moment, so a QSO that reached the log between a question and its answer is
  not added twice. Nothing is changed unless there is something to add. If there
  is, it goes in this order: a verified backup of the log in aBackupDir (a log
  that cannot be backed up is not written to), then ONE transaction for every
  record (all or none). aAdded is how many went in; aSkippedContest how many were left
  out because they belong to another contest or to none that can be told. False
  says why in aWhy and the log is as it was. It does not rescore. *)
function MergeServerLog(aImage: TServerLogImage; const aBackupDir: string;
                        out aAdded: integer; out aWhy: string): boolean;

(* THE MERGE AND EVERYTHING AROUND IT, as the operator meets it: MergeServerLog
  into uAppPaths.BackupDir, then a rescore (the new rows are scored like any
  other import), the notice, and the log line; a failure is a warning and an
  Error line. True when the log was brought up to date (also when there was
  nothing to add). MAIN THREAD. *)
function AddServerLogToLog(aImage: TServerLogImage): boolean;

(* THE DOWNLOAD ITSELF, on a connection of its own to the server's second port.
  Exported for the unit tests, which run it against a socket they serve; the
  program calls it from the worker. Runs on the CALLING thread and reads no
  setting: the host, the port and the password's wire form are handed in. True
  when exactly the size the server stated has been written to aInto. False says
  why in aWhy and aInto holds whatever arrived. *)
function FetchServerLog(const aHost: AnsiString; aPort: integer;
                        const aPassword: TIdBytes; aInto: TServerLogImage;
                        out aWhy: string): boolean;

(* HOW MANY QSOS THE SERVER HOLDS THAT THIS LOG DOES NOT, without changing
  anything. False when the log could not be read. MAIN THREAD. *)
function CountMissingFromServer(aImage: TServerLogImage; out aMissing: integer): boolean;

(* THE OTHER DIRECTION (2026-10-28): WHAT THE SERVER LACKS OF THIS LOG.

  MakePushPlan judges this log's rows against the image (uNetCatchUp.TPushPlan:
  imports and owed rows are left out and counted, everything else the image does
  not hold is kept) and answers the plan, which the caller frees. False, with
  nil, when the log cannot be read. MAIN THREAD. Changes nothing.

  CountPushableToServer is the count alone.

  SendLogToServer makes the plan AGAIN from the log as it is now (an image shown
  in a window can be minutes old), posts it as OFFLINEQSO (uNet.RestockServer: no
  flag is written, the server does not relay it) and says so with ONE notice.
  aSent is how many were posted. False when a guard refused or the link dropped
  part way. MAIN THREAD. *)
function MakePushPlan(aImage: TServerLogImage; out aPlan: TPushPlan): boolean;
function CountPushableToServer(aImage: TServerLogImage; out aPush: integer): boolean;
function SendLogToServer(aImage: TServerLogImage; out aSent: integer): boolean;

(* HOW THE DOWNLOAD THREAD TALKS TO THE WINDOW.

  The worker may not touch an LCL control, so it calls this, and this queues
  the report to the main thread (RunOnMainThread) where the form's handler
  runs. A report is a field and a value; the worker overwrites its locals
  immediately, so the pair travels as a record.

  A no-op when no window is listening, which is both the on-connect path and the
  window having closed mid-download. *)
procedure ReportSyncProgress(aField: integer; aValue: integer);

(* THE LAST DOWNLOAD THE SYNCHRONIZE WINDOW SHOWS, as records, for its grid. The
  grid is virtual: it asks for the rows it paints, on the main thread, and the
  image behind it is only ever replaced or released on the main thread. The
  window releases it when it closes. *)
function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;
(* THE PRINCIPAL FIELDS OF A WIRE ROW AS A ContestExchange, for the window's grid
  only: callsign, time, band, mode, signal reports, serials, the received
  exchange text, points and the dupe, deleted and X-QSO marks. NOT the way a row
  reaches the log (that stores the wire columns whole). Exported for the unit
  tests. *)
procedure WireRowToDisplayRecord(const aValues: TWireValues; out aRecord: ContestExchange);
function ServerLogWindowImage: TServerLogImage;
procedure ReleaseServerLogImage;

type
  (* WHAT A PROGRESS REPORT IS. A plain procedure, not a method: the worker
    thread has no object to call and the form installs a unit-level wrapper. *)
  TSyncProgressProc = procedure(aField: integer; aValue: integer);

  (* One report, carried across the marshalling call. RunOnMainThread takes a
    single PtrInt, and a field plus a value do not fit in one without packing
    them -- and a byte count is too big to pack safely. *)
  PSyncProgress = ^TSyncProgress;
  TSyncProgress = record
     Field: integer;
     Value: integer;
  end;

var
  { Installed last in HandleShow and cleared FIRST in HandleClose. }
  (* WHERE A PROGRESS REPORT GOES, or nil while no window is listening.

    This was ServerLogFormWnd: HWND, and ReportSyncProgress SendMessage'd
    WM_USER_SYNC_PROGRESS at it. A callback says the same thing without a
    window handle, a private message id or a `message` directive -- and it is
    the form that installs it, so the form's behaviour is discoverable from the
    form. *)
  SyncProgressHandler                   : TSyncProgressProc = nil;
  showresverlogcontent                  : boolean = True;

const
  (* Progress, worker -> sync window. See ReportSyncProgress. The first four are
    reported ON THE MAIN THREAD once the download is whole. *)
  SYNC_FIELD_RECORDS        = 1;   // records in the server's log
  SYNC_FIELD_BYTES          = 2;   // bytes received so far (from the worker)
  SYNC_FIELD_QSOS           = 3;   // the QSOs among them that count
  SYNC_FIELD_ENABLE_REPLACE = 4;   // the log lacks QSOs; the value is how many
  SYNC_FIELD_FAILED         = 5;   // the download failed; Get server log may be pressed again
  SYNC_FIELD_ENABLE_SEND    = 6;   // this log has QSOs the server lacks; the value is how many

implementation
uses SysUtils,
   IdTCPClient, // the log download -- see FetchServerLog
   LCLType,     // IDYES
   LogWind,     // QuickDisplay
   PostUnit,    // Contest
   uMainThread,  { RunOnMainThread -- the finished handoff, see CatchUpFetched }
   MainUnit,     // RescoreLog, YesOrNo, logger
   uNet,         // NetPeers, NetIsConnected
   uHostResolve, // TryResolveHost -- the server's name, issue 148
   uNetTunnel,   // the Tailcat tunnel's local door for the sync port, issue 293
   uNetClient,       (* ServerPasswordOnWire -- the one wire form *)
   uSettingsModel,   (* Settings.Server *)
   uAppStrings,
   uTR4WStrings,     (* TC_FAILEDTORECEIVESERVERLOG *)
   uAppPaths,        (* BackupDir *)
   uContestRegistry,
   uContestBase,     (* ContestReceivedYearKind -- does the contest send a year *)
   uLogStore,
   uGuidSet,
   uNetFraming,      (* TakeSyncHeader, TakeSyncRow, NET_WIRE_MAX_PAYLOAD *)
   uNetHello,        (* NET_PROTOCOL_VERSION *)
   uNetResend,       (* NextQsoSequence *)
   uQsoColumns,      (* QsoWireColumns *)
   uADIF,            (* GetADIFBand *)
   uLogBinaryFile,   (* UnixUTCToQSOTime *)
   uLogRepository;   (* TokenToMode, GetADIFBand, UnixUTCToQSOTime ... as found *)

{ GetServerLogDlgProc STOOD HERE and went with dialog template 73 on
  2026-08-29 -- the last Win32 dialog in the program. Its window is
  ui\lcl\uServerLogForm now, and every arm of that case statement is a method
  on the form. }

var
   (* The download the Synchronize window is showing. MAIN thread only. *)
   GWindowImage: TServerLogImage = nil;
   (* A fetch is under way, or the question it raised is open. MAIN thread only.
     The worker's thread id is not used for this: it is written by the starter
     after BeginThread returns, and a thread that finishes first would clear it
     before it was set. *)
   GCatchUpBusy: boolean = False;
   GCatchUpThreadID: TThreadID;

(* ------------------------------------------------------------ the window's rows *)

function ServerLogWindowImage: TServerLogImage;
begin
   Result := GWindowImage;
end;

function TryGetServerLogRow(const aIndex: integer;
                            out aRecord: ContestExchange): boolean;
begin
   Result := False;
   aRecord := Default(ContestExchange);
   if (GWindowImage <> nil) and (aIndex >= 0) and (aIndex < GWindowImage.Count) then
      begin
      WireRowToDisplayRecord(GWindowImage.Row(aIndex), aRecord);
      Result := True;
      end;
   (* A RECORD FROM THE SERVER'S LOG ARRIVES HERE, so it is judged here -- log
     schema 10: the window reads the stored predicate like every other grid; so
     this station's contest stamps it on the way in. *)
   if Result then
      begin
      StampOffContest(aRecord);
      end;
end;

procedure WireRowToDisplayRecord(const aValues: TWireValues; out aRecord: ContestExchange);
var
   cols: TWireColumns;

   function V(const aName: string): string;
   begin
      Result := '';
      if Length(aValues) = cols.Count then
         begin
         Result := aValues[cols.IndexOfName(aName)];
         end;
   end;

   function N(const aName: string; aDefault: Int64): Int64;
   var
      n: Int64;
   begin
      Result := aDefault;
      if TryCanonicalInt64(V(aName), n) then
         begin
         Result := n;
         end;
   end;

begin
   cols := QsoWireColumns;
   aRecord := Default(ContestExchange);
   aRecord.Band := NoBand;
   aRecord.Mode := NoMode;
   aRecord.ExtMode := eNoMode;
   aRecord.NumberReceived := -1;
   aRecord.NumberSent := -1;
   aRecord.ceRecordKind := TokenToRecordKind(AnsiString(V('record_kind')));
   aRecord.tSysTime := UnixUTCToQSOTime(N('qso_at', 0));
   aRecord.Callsign := AnsiString(V('callsign'));
   aRecord.Frequency := N('freq_tx_hz', 0);
   aRecord.Band := GetADIFBand(V('band'));
   aRecord.Mode := TokenToMode(AnsiString(V('mode')));
   aRecord.ExchString := AnsiString(V('exchange_received'));
   aRecord.RSTSent := N('rst_sent', 0);
   aRecord.RSTReceived := N('rst_received', 0);
   aRecord.NumberSent := N('serial_sent', -1);
   aRecord.NumberReceived := N('serial_received', -1);
   aRecord.QTHString := AnsiString(V('rcvd_qth'));
   aRecord.Name := AnsiString(V('rcvd_name'));
   aRecord.DomesticQTH := AnsiString(V('domestic_qth'));
   aRecord.QSOPoints := word(N('qso_points', 0));
   aRecord.ceDupe := N('is_dupe', 0) <> 0;
   (* NOT is_xqso / is_off_contest: Lint-XQSOReads reserves the X-QSO rule to the
     units that set it, so the grid does not grey a server row as an X-QSO. *)
   aRecord.ceQSO_Deleted := (N('deleted', 0) <> 0) or (N('is_skipped', 0) <> 0);
   if V('computer_id') <> '' then
      begin
      aRecord.ceComputerID := AnsiChar(V('computer_id')[1]);
      end;
   aRecord.ceContest := Contest;
end;

procedure ReleaseServerLogImage;
begin
   FreeAndNil(GWindowImage);
end;

(* Delivers one report on the main thread, and owns the record it was handed. *)
procedure DeliverSyncProgress(aData: PtrInt);
var
   p: PSyncProgress;
begin
   p := PSyncProgress(aData);
   try
      if Assigned(SyncProgressHandler) then
         begin
         SyncProgressHandler(p^.Field, p^.Value);
         end;
   finally
      Dispose(p);
   end;
end;

(* CALLED FROM THE WORKER THREAD, which is why this marshals.

  It was SendMessage to the form's HWND -- which crosses to the window's thread
  and BLOCKS the worker until the labels have been repainted. RunOnMainThread
  does not block, and a progress report is exactly the kind of thing that should
  not hold up the work it is reporting on. A report that arrives LATE
  understates the count, which is the safe side. *)
procedure ReportSyncProgress(aField: integer; aValue: integer);
var
   p: PSyncProgress;
begin
   if not Assigned(SyncProgressHandler) then
      begin
      Exit;
      end;
   New(p);
   p^.Field := aField;
   p^.Value := aValue;
   RunOnMainThread(@DeliverSyncProgress, PtrInt(p));
end;

(* --------------------------------------------------------------- the download *)

(* THE LOG DOWNLOAD, ON INDY -- into MEMORY, on the worker's own connection.

  THE PROTOCOL (design 13.7): connect to the server's port PLUS ONE, write ten
  bytes of password, then read a header frame {"contest":..,"rows":N,"schema":5}
  and N row frames. A frame is a four-byte length in NATIVE (little-endian) byte
  order and that many bytes of UTF-8 JSON; a row frame is the on-wire row of a
  live QSO message without the sender byte. Each frame is read EXACTLY, so how TCP
  cuts the stream does not matter.

  A frame over NET_RECEIVE_BUFFER_SIZE (NOT the 60000 live-message cap: the server writes a spaced JSON, so an at-cap row frame can exceed it), a header that does not parse, a schema other
  than this build's protocol, more rows than SERVER_LOG_MAX_ROWS, or a row whose
  checksum does not match ends the download with the reason: nothing is guessed.
  A server that closes early is a read that fails, naming how many rows arrived.

  ReadInt32(AConvert := False): Indy converts from NETWORK byte order by default;
  these four bytes are native.

  NO SETTINGS ARE READ HERE: the starter captured the address, port and the
  password's wire form. Runs on the worker; progress is reported from it. *)
function FetchServerLog(const aHost: AnsiString; aPort: integer;
                        const aPassword: TIdBytes; aInto: TServerLogImage;
                        out aWhy: string): boolean;
const
   CONNECT_TIMEOUT_MS = 5000;
   IDLE_TIMEOUT_MS    = 15000;   // nothing arriving for this long ends the transfer
var
   Client:      TIdTCPClient;
   Body:        TIdBytes;
   Bytes:       TBytes;
   Length32:    integer;
   resolved:    string;
   resolveWhy:  string;
   contest:     string;
   rows, schema: integer;
   i, n:        integer;
   values:      TWireValues;
   rowWhy:      string;
   received:    Int64;

   function ReadFrame: boolean;
   var
      k: integer;
   begin
      Result := False;
      Length32 := Client.IOHandler.ReadInt32(False);   // native order
      if (Length32 < 0) or (Length32 > NET_RECEIVE_BUFFER_SIZE) then
         begin
         aWhy := 'the server sent a frame of ' + IntToStr(Length32) +
                 ' bytes (the limit is ' + IntToStr(NET_RECEIVE_BUFFER_SIZE) + ')';
         Exit;
         end;
      SetLength(Body, 0);
      if Length32 > 0 then
         begin
         Client.IOHandler.ReadBytes(Body, Length32, False);
         end;
      SetLength(Bytes, Length(Body));
      for k := 0 to High(Body) do
         begin
         Bytes[k] := Body[k];
         end;
      Inc(received, 4 + Length(Body));
      Result := True;
   end;

begin
   Result   := False;
   aWhy     := '';
   received := 0;
   n        := 0;

   (* THE SERVER'S NAME, through the platform resolver (uHostResolve, issue 148;
     Windows is unchanged). Here on the WORKER thread, which may wait on the
     C library -- the starter captured the name on the main thread and resolves
     nothing. The reason already names the host. *)
   if not TryResolveHost(string(aHost), resolved, resolveWhy) then
      begin
      aWhy := resolveWhy;
      Exit;
      end;

   Client := TIdTCPClient.Create(nil);
   try
      Client.Host           := AnsiString(resolved);
      Client.Port           := aPort;
      Client.ConnectTimeout := CONNECT_TIMEOUT_MS;
      Client.ReadTimeout    := IDLE_TIMEOUT_MS;

      try
         Client.Connect;
      except
         on E: Exception do
            begin
            (* REPORTED, not silent: a wrong address and a refused connection
              are different answers. *)
            aWhy := 'could not connect to ' + string(aHost) + ':' +
                    IntToStr(aPort) + ' -- ' + E.Message;
            Exit;
            end;
      end;

      try
         Client.IOHandler.Write(aPassword);

         if not ReadFrame then
            begin
            Exit;
            end;
         if (not TakeSyncHeader(Bytes, contest, rows, schema)) or
            (rows < 0) or (rows > SERVER_LOG_MAX_ROWS) then
            begin
            aWhy := 'the server sent a sync header this station cannot read';
            Exit;
            end;
         if schema <> NET_PROTOCOL_VERSION then
            begin
            aWhy := 'the server sent schema ' + IntToStr(schema) +
                    ', this station speaks ' + IntToStr(NET_PROTOCOL_VERSION);
            Exit;
            end;
         aInto.StartImage(contest, rows);

         for i := 1 to rows do
            begin
            if not ReadFrame then
               begin
               Exit;
               end;
            if TakeSyncRow(QsoWireColumns, Bytes, values, rowWhy) <> wtOk then
               begin
               aWhy := 'row ' + IntToStr(i) + ' of ' + IntToStr(rows) +
                       ' is refused: ' + rowWhy;
               Exit;
               end;
            aInto.AddRow(values);
            Inc(n);
            if (i mod 200) = 0 then
               begin
               ReportSyncProgress(SYNC_FIELD_BYTES, received);
               end;
            end;
         ReportSyncProgress(SYNC_FIELD_BYTES, received);

         Result := True;
      except
         on E: Exception do
            begin
            aWhy := 'the transfer failed after ' + IntToStr(n) + ' of ' +
                    IntToStr(rows) + ' row(s) -- ' + E.Message;
            end;
      end;
   finally
      try
         Client.Disconnect;
      except
         (* Closing a connection that already failed has nothing to add. *)
      end;
      Client.Free;
   end;
end;

type
   (* ONE FETCH, from the main thread that asked to the worker and back. *)
   TFetchJob = class(TObject)
   public
      Origin:   TCatchUpOrigin;
      Host:     AnsiString;
      Port:     integer;
      Password: TIdBytes;
      Image:    TServerLogImage;
      Ok:       boolean;
      Why:      string;
      destructor Destroy; override;
   end;

destructor TFetchJob.Destroy;
begin
   Image.Free;
   inherited Destroy;
end;

(* THE SERVER'S CONTEST AGAINST OURS, ONCE (design 13.7 ruling 4). True when the
  rows may be used; False, reported once per call site's caller, when the server
  holds another contest. The notice is the existing contest-mismatch one. *)
function ServerContestMatches(aImage: TServerLogImage; out aWhy: string): boolean;
var
   ours, theirsName: string;
   theirHandle: TContestHandle;
begin
   Result := True;
   aWhy := '';
   ours := ContestId(Contest);
   if JudgeSyncContest(aImage.Contest, ours) <> scOther then
      begin
      Exit;
      end;

   Result := False;
   theirsName := aImage.Contest;
   if FindContestById(aImage.Contest, theirHandle) then
      begin
      theirsName := ContestIdentity(theirHandle).DisplayName;
      end;
   aWhy := SysUtils.Format(SPeerOnAnotherContest,
                           ['(the server)', theirsName,
                            ContestIdentity(Contest).DisplayName]);
   logger.Error('[Net] catch-up: the server holds contest "%s" and this station is ' +
                'on "%s": nothing was compared, added or sent', [aImage.Contest, ours]);
end;

(* THE PLAN against the log as it is NOW. False, with nil, when the log's guids
  cannot be read: a plan made without them would add what is already there. *)
function MakePlan(aImage: TServerLogImage; out aPlan: TCatchUpPlan): boolean;
var
   guids: TGuidArray;
   held: TGuidSet;
   i: integer;
begin
   Result := False;
   aPlan := nil;

   if not LogStoreCollectGuids(guids) then
      begin
      Exit;
      end;

   held := TGuidSet.Create;
   try
      for i := 0 to High(guids) do
         begin
         held.Add(guids[i]);
         end;
      aPlan := BuildCatchUpPlan(aImage, held);
      Result := True;
   finally
      held.Free;
   end;
end;

function CountMissingFromServer(aImage: TServerLogImage; out aMissing: integer): boolean;
var
   plan: TCatchUpPlan;
begin
   aMissing := 0;
   Result := MakePlan(aImage, plan);
   if Result then
      begin
      try
         aMissing := plan.Count;
         logger.Info('[Net] catch-up: %s', [CatchUpSummary(plan)]);
      finally
         plan.Free;
      end;
      end;
end;

(* THIS LOG'S ROWS THE SERVER MAY LACK, judged. The repository leaves out the
  rows whose key the image holds (before it parses them); Consider judges the
  rest. *)
function MakePushPlan(aImage: TServerLogImage; out aPlan: TPushPlan): boolean;
var
   rows: TWireRows;
   i: integer;
   computerId: string;
begin
   Result := False;
   computerId := string(Settings.Computer.Id);
   aPlan := TPushPlan.Create(aImage, computerId, NetResentThisLink);
   rows := TWireRows.Create;
   try
      (* ONLY ROWS LOGGED HERE (the wire computer_id is this station's) whose
        guid the server lacks: the repository asks the plan before it reads a
        row's other columns. *)
      if not LogStoreCollectWireRowsForServer(rows, computerId, aPlan.ServerHolds) then
         begin
         FreeAndNil(aPlan);
         Exit;
         end;

      for i := 0 to rows.Count - 1 do
         begin
         aPlan.Consider(rows.RowId(i), rows.Values(i), rows.Owed(i));
         end;
      Result := True;
   finally
      rows.Free;
   end;
end;

function CountPushableToServer(aImage: TServerLogImage; out aPush: integer): boolean;
var
   plan: TPushPlan;
begin
   aPush := 0;
   Result := MakePushPlan(aImage, plan);
   if Result then
      begin
      try
         aPush := plan.Count;
         logger.Info('[Net] restock: %s', [PushSummary(plan)]);
      finally
         plan.Free;
      end;
      end;
end;

function SendLogToServer(aImage: TServerLogImage; out aSent: integer): boolean;
var
   plan: TPushPlan;
begin
   aSent := 0;
   Result := False;

   if not MakePushPlan(aImage, plan) then
      begin
      logger.Error('[Net] restock: the log could not be read; nothing was sent');
      Exit;
      end;

   try
      logger.Info('[Net] restock: %s', [PushSummary(plan)]);
      if plan.Count = 0 then
         begin
         Result := True;
         Exit;
         end;

      Result := RestockServer(plan, aSent);
      if aSent > 0 then
         begin
         (* THE WHOLE COUNT (NY4I, 2026-11-22): the QSOs logged while disconnected
           went out by the resend on this link, the rest by this push; saying
           only the push said 5 when 25 had gone. *)
         if NetResentQsoCount > 0 then
            begin
            QuickDisplay(SysUtils.Format(SNetPushedToServerTotal,
                                         [NetResentQsoCount + aSent, NetResentQsoCount, aSent]));
            end
         else
            begin
            QuickDisplay(SysUtils.Format(SNetPushedToServer, [aSent]));
            end;
         end;
   finally
      plan.Free;
   end;
end;

function MergeServerLog(aImage: TServerLogImage; const aBackupDir: string;
                        out aAdded: integer; out aWhy: string): boolean;
var
   plan: TCatchUpPlan;
   rows: array of TWireValues;
   keys: TQsoSessionKeys;
   i, n: integer;
   backupPath, backupReport: string;
begin
   Result := False;
   aAdded := 0;
   aWhy := '';

   (* THE CONTEST IS COMPARED ONCE, from the sync header (design 13.7 ruling 4):
     a server on another contest is refused whole. *)
   if not ServerContestMatches(aImage, aWhy) then
      begin
      Exit;
      end;

   if not MakePlan(aImage, plan) then
      begin
      aWhy := 'the log could not be read to find what it lacks';
      Exit;
      end;

   try
      logger.Info('[Net] catch-up: %s', [CatchUpSummary(plan)]);

      if plan.Count = 0 then
         begin
         Result := True;
         Exit;
         end;

      (* A VERIFIED BACKUP FIRST, AND NO WRITE WITHOUT ONE. This only inserts, but
        it inserts into the contest log from rows this station did not make. *)
      if not LogStoreBackupBeforeCatchUp(aBackupDir, backupPath, backupReport) then
         begin
         aWhy := 'the backup of the log taken first failed -- ' + backupReport;
         logger.Error('[Net] catch-up: not added: %s', [aWhy]);
         Exit;
         end;
      logger.Info('[Net] catch-up: log backed up to %s', [backupPath]);

      (* EVERY ROW IS STORED VERBATIM, under the sender's guid, with the sender's
        station facts and my_source as they were sent (NY4I ruling 2). Only this
        database's own columns are set here: a fresh local pair (so an edit
        made to the row here can be sent), sent and clean (it came from the
        server, so it is not owed back). *)
      n := plan.Count;
      SetLength(rows, n);
      SetLength(keys, n);
      for i := 0 to n - 1 do
         begin
         rows[i] := aImage.Row(plan.RowIndex(i));
         keys[i].SessionId := STARTTIMEOFTHETR4W;
         keys[i].SessionSeq := NextQsoSequence(Cardinal(GetTickCount64));
         end;

      if not LogStoreSaveWireRows(rows, keys, aAdded) then
         begin
         aWhy := 'the QSOs could not be written to the log';
         logger.Error('[Net] catch-up: not added: %s', [aWhy]);
         Exit;
         end;
      Result := True;
   finally
      plan.Free;
   end;
end;

function AddServerLogToLog(aImage: TServerLogImage): boolean;
var
   added: integer;
   why: string;
begin
   Result := MergeServerLog(aImage, BackupDir, added, why);

   if not Result then
      begin
      showwarning(SysUtils.Format(SCatchUpMergeFailed, [why]));
      Exit;
      end;

   if added > 0 then
      begin
      (* The new rows are scored like any other import: the rescore walks the
        whole log, recomputes dupes and multipliers in log order, and reloads
        every display. *)
      RescoreLog;
      logger.Info('[Net] catch-up: %d QSO(s) added from the server', [added]);
      QuickDisplay(SysUtils.Format(SNetCaughtUp, [added]));
      end;
end;

(* -------------------------------------------------------------- the worker *)

procedure CatchUpFetched(aData: PtrInt); forward;

function CatchUpThread(aParameter: Pointer): DWORD; stdcall;
var
   job: TFetchJob;
   why: string;
begin
   Result := 0;   (* the thread exit code -- see TF.TTR4WThreadStart *)
   job := TFetchJob(aParameter);

   try
      job.Ok := FetchServerLog(job.Host, job.Port, job.Password, job.Image, why);
      job.Why := why;
   except
      on E: Exception do
         begin
         job.Ok := False;
         job.Why := E.ClassName + ': ' + E.Message;
         end;
   end;

   RunOnMainThread(@CatchUpFetched, PtrInt(job));
end;

(* ON CONNECT: ADD ON ITS OWN, OR ASK, OR SAY NOTHING.

  Nothing is said when the log is already complete -- a link that comes up and
  goes down all night would otherwise announce it every time. *)
procedure DecideOnConnect(aImage: TServerLogImage);
var
   missing, toSend, sent: integer;
   question: string;
begin
   if not CountMissingFromServer(aImage, missing) then
      begin
      logger.Error('[Net] catch-up: the log could not be read; nothing was added');
      Exit;
      end;

   (* THE OTHER DIRECTION, from the same image: what this log has that the server
     lacks (a server that lost its log). If the log cannot be read for it, the
     pull still goes ahead on its own. *)
   if not CountPushableToServer(aImage, toSend) then
      begin
      logger.Error('[Net] restock: the log could not be read; nothing was sent');
      toSend := 0;
      end;

   (* A SEND THAT CANNOT GO IS NOT OFFERED: the link may have changed while the
     log was being fetched, and the operator must not be asked to send
     something the link would refuse. *)
   if (toSend > 0) and (not NetCanRestock) then
      begin
      logger.Info('[Net] restock: %d QSO(s) the server lacks, but the link is not ' +
                  'usable now; they are planned again on the next link', [toSend]);
      toSend := 0;
      end;

   (* ONE QUESTION FOR BOTH DIRECTIONS, or none (uNetCatchUp.SyncOnConnect). *)
   case SyncOnConnect(missing, toSend, Settings.Server.AutoSynchronizeLogOnConnect) of
      socNothing:
         begin
         Exit;
         end;
      socDoNow:
         begin
         question := '';
         end;
      socAskPull:
         begin
         question := SysUtils.Format(SCatchUpAsk, [missing]);
         end;
      socAskPush:
         begin
         question := SysUtils.Format(SPushAsk, [toSend]);
         end;
   else
      begin
      question := SysUtils.Format(SSyncAskBoth, [missing, toSend]);
      end;
   end;

   if question <> '' then
      begin
      if YesOrNo(question) <> IDYES then
         begin
         logger.Info('[Net] catch-up: %d QSO(s) on the server were not added and ' +
                     '%d of this log were not sent (the operator declined)',
                     [missing, toSend]);
         Exit;
         end;
      end;

   if toSend > 0 then
      begin
      SendLogToServer(aImage, sent);
      end;
   if missing > 0 then
      begin
      AddServerLogToLog(aImage);
      end;
end;

(* IN THE WINDOW: SHOW WHAT WAS FETCHED and say how many the log lacks. The
  image is the window's from here, until it is replaced or the window closes. *)
procedure ShowFetchedInWindow(aJob: TFetchJob);
var
   missing, toSend: integer;
begin
   ReleaseServerLogImage;
   GWindowImage := aJob.Image;
   aJob.Image := nil;

   SyncProgressHandler(SYNC_FIELD_RECORDS, GWindowImage.Count);
   SyncProgressHandler(SYNC_FIELD_QSOS, GWindowImage.QsoCount);

   if CountMissingFromServer(GWindowImage, missing) then
      begin
      if missing > 0 then
         begin
         SyncProgressHandler(SYNC_FIELD_ENABLE_REPLACE, missing);
         end;
      end
   else
      begin
      logger.Error('[Net] catch-up: the log could not be read, so what it lacks ' +
                   'is not known');
      end;

   (* THE COUNT GOES TO THE WINDOW EITHER WAY; the window enables Send only while
     the link is usable (uNet.NetCanRestock) and follows the link afterwards, so a
     link that drops or comes back while the window is open changes the button. *)
   if CountPushableToServer(GWindowImage, toSend) then
      begin
      if toSend > 0 then
         begin
         SyncProgressHandler(SYNC_FIELD_ENABLE_SEND, toSend);
         end;
      end;
end;

(* THE WORKER HAS FINISHED -- ON THE MAIN THREAD. *)
procedure CatchUpFetched(aData: PtrInt);
var
   job: TFetchJob;
   contestWhy: string;
begin
   job := TFetchJob(aData);
   try
      if not job.Ok then
         begin
         logger.Error('[Net] catch-up: could not read the server log -- %s', [job.Why]);
         if job.Origin = cuInWindow then
            begin
            if Assigned(SyncProgressHandler) then
               begin
               SyncProgressHandler(SYNC_FIELD_FAILED, 0);
               end;
            showwarning(TC_FAILEDTORECEIVESERVERLOG + LineEnding + job.Why);
            end
         else
            begin
            QuickDisplay(SysUtils.Format(SCatchUpFetchFailed, [job.Why]));
            end;
         Exit;
         end;

      logger.Info('[Net] catch-up: the server log holds %d row(s), %d QSO(s), contest ' +
                  '"%s"', [job.Image.Count, job.Image.QsoCount, job.Image.Contest]);

      (* ANOTHER CONTEST ON THE SERVER IS REFUSED WHOLE, ONCE, with the existing
        contest-mismatch notice: nothing is compared, added or sent. *)
      if not ServerContestMatches(job.Image, contestWhy) then
         begin
         if (job.Origin = cuInWindow) and Assigned(SyncProgressHandler) then
            begin
            SyncProgressHandler(SYNC_FIELD_FAILED, 0);
            showwarning(contestWhy);
            end
         else
            begin
            QuickDisplay(contestWhy);
            end;
         Exit;
         end;

      if job.Origin = cuInWindow then
         begin
         (* The window may have been closed while the bytes came. *)
         if Assigned(SyncProgressHandler) then
            begin
            ShowFetchedInWindow(job);
            end;
         end
      else
         begin
         DecideOnConnect(job.Image);
         end;
   finally
      GCatchUpBusy := False;
      job.Free;
   end;
end;

function StartServerCatchUp(aOrigin: TCatchUpOrigin): boolean;
var
   job: TFetchJob;
   tunnelPort: word;
begin
   Result := False;

   if GCatchUpBusy then
      begin
      logger.Info('[Net] catch-up: one is already under way');
      Exit;
      end;

   if Contest = NoContest then
      begin
      logger.Info('[Net] catch-up: no contest is selected, so there is nothing ' +
                  'to compare the server log with');
      Exit;
      end;

   job := TFetchJob.Create;
   job.Origin := aOrigin;
   (* CAPTURED HERE, on the main thread: the worker reads no settings. AnsiString,
     because Indy is built without UnicodeStrings and a string would be widened
     and narrowed again. *)
   job.Host := AnsiString(Settings.Server.Address);
   job.Port := Settings.Server.Port + 1;
   (* THROUGH THE TAILCAT TUNNEL (issue 293) the server's second port has a
     local door of its own. A catch-up runs over a live link, so the tunnel is
     open; if it is not, there is no way to the server and nothing is tried at
     SERVER ADDRESS, which is not the server the operator asked for. *)
   if Settings.Server.UseTailcat then
      begin
      job.Host := NET_TUNNEL_HOST;
      if NetTunnelSyncPort(tunnelPort) then
         begin
         job.Port := tunnelPort;
         end
      else
         begin
         logger.Warn('[Net] catch-up: the Tailcat tunnel is not open');
         job.Free;
         Exit;
         end;
      end;
   job.Password := ServerPasswordOnWire(AnsiString(Settings.Server.Password));
   job.Image := TServerLogImage.Create;

   GCatchUpBusy := True;
   if not ThreadStarted(tCreateThread(CatchUpThread, GCatchUpThreadID, False, job)) then
      begin
      logger.Error('[Net] catch-up: could not start the download thread');
      GCatchUpBusy := False;
      job.Free;
      Exit;
      end;

   Result := True;
end;

initialization

finalization
   FreeAndNil(GWindowImage);

end.
