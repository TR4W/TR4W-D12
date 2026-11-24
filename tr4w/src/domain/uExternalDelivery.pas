unit uExternalDelivery;
{$I ..\tr4w.inc}

interface

uses
   SysUtils, sqldb, uLogDatabase;

type
   TDeliveryKey = record
      Logger, Account, Logbook, Contact: string;
   end;

   TDeliveryJob = record
      Key: TDeliveryKey;
      Revision: Int64;
      RemoteId, Payload, ConfirmedPayload: string;
      Deleted: boolean;
   end;

   TDeliveryOutcome = (doConfirmed, doRetry, doUncertain, doFailed);

   TDeliveryCounts = record
      Pending, InFlight, Synced, Uncertain, Failed: Int64;
   end;

   (* ONE DESTINATION'S DELIVERY OF ONE QSO -- one external_delivery row, as
     Edit QSO's delivery window shows it; a value, so nothing of sqldb leaves
     this unit. Logger is the delivery key
     (TExternalLoggerDefinition.DeliveryId, or a bare provider id in a log
     written before definitions existed). LastSent is Unix seconds UTC, 0 when
     the destination never answered. *)
   TDeliveryStatus = record
      Logger, Account, Logbook, State, ErrorCode: string;
      LastSent: Int64;
   end;

   (* Every destination of one QSO, in key order (logger, account, logbook).
     Empty when the QSO has no delivery row. *)
   TDeliveryStatusList = array of TDeliveryStatus;

   (* WHAT A DESTINATION THAT GIVES NO REPLY (DXKeeper) REPORTS ABOUT ONE QSO:
     the command was written (Delivered), or it never was (ErrorCode says
     why). The QSO is named by its network key, which is all the sender knew
     when it was queued. Logger is the delivery key; Account and Logbook are
     fixed placeholders the key needs. A plain value built on the sender thread
     and consumed on the main thread. *)
   TExternalHandOff = class(TObject)
   public
      Logger, Account, Logbook, ErrorCode: string;
      SessionId, SessionSeq: Int64;
      Delivered: boolean;
   end;

(* An on-demand, read-only snapshot. Never commits a caller's live connection
   or leaves a WAL reader pinned while Preferences is open. *)
function ExternalDeliveryCounts(const aFileName, aLogger: string): TDeliveryCounts;
function ExternalDeliveryGapKey(const aLogger: string): string;

(* Every delivery of qso row aRowId -- TExternalDelivery.StatusesOfQso,
  through its own short-lived read-only connection for the same reason as the
  counts: the caller's live connection may hold a read transaction from an
  earlier read, and its snapshot would not show what the worker has written
  since. False, with an empty list, when the QSO has no delivery row. Raises
  if the file will not open. *)
function ExternalDeliveryStatusesOfQso(const aFileName: string; aRowId: Int64;
                                       out aStatuses: TDeliveryStatusList): boolean;

type

   (* All methods run on the database owner's thread. No method commits:
      Enqueue belongs in the QSO transaction; Claim must commit BEFORE HTTP.
      The HTTP client receives only TDeliveryJob values. SQLDB objects never
      cross their owning thread's boundary.
      Each instance borrows its database and must die before that database. *)
   TExternalDelivery = class
   private
      FDatabase: TLogDatabase;
      function Query(const aSQL: AnsiString): TSQLQuery;
      function KeyedQuery(const aSQL: AnsiString;
                          const aKey: TDeliveryKey): TSQLQuery;
   public
      constructor Create(aDatabase: TLogDatabase);
      procedure Enqueue(const aKey: TDeliveryKey; const aPayload: string;
                        aDeleted: boolean);
      (* RESEND (issue 356): put a FAILED or SYNCED contact back in the queue
         with a new revision and the payload it already has, so a worker sends
         it again (a failed create is created again; a synced one is UPDATED
         through its remote id, never created twice). Pending, inflight and
         uncertain rows are not touched: the WHERE names the two states, and
         an uncertain contact is never replayed blindly. Like Enqueue, belongs
         in the caller's transaction. *)
      procedure Requeue(const aKey: TDeliveryKey);
      function Claim(const aLogger, aAccount: string; aNow: Int64;
                     out aJob: TDeliveryJob): boolean;
      procedure Complete(const aJob: TDeliveryJob; aOutcome: TDeliveryOutcome;
                         const aRemoteId, aErrorCode, aRequestId: string;
                         aNextAttempt: Int64);
      procedure RecoverInterrupted(const aLogger, aAccount: string;
         aUnsafeUpdates: boolean = False);
      procedure MigrateLogger(const aOldLogger, aNewLogger, aAccount, aLogbook: string);
      function NextAttempt(const aLogger, aAccount: string): Int64;
      (* EVERY delivery of the qso row aRowId, joined through qso.guid (the
         contact key): one element per external_delivery row, so a QSO sent
         to three loggers answers three. Ordered by the rest of the primary
         key (logger, account, logbook), so the order is stable between
         reads. False, with an empty list, when none. *)
      function StatusesOfQso(aRowId: Int64;
                             out aStatuses: TDeliveryStatusList): boolean;
      (* UPSERTS the one row of the QSO aHandOff names: 'synced' when the
         command was written, 'failed' (with its code) when it was not, and
         last_sent set to now either way. A hand-off is NEVER 'pending' or
         'inflight': nothing here will send it again, and a pending row would
         count as work waiting in Preferences for ever. Does not commit. False,
         nothing written, when no QSO row carries the key (or it has no guid,
         or the key is (0, 0), which is every QSO that never had one). *)
      function RecordHandOff(aHandOff: TExternalHandOff): boolean;
   end;

implementation

function ExternalDeliveryGapKey(const aLogger: string): string;
begin
   if aLogger = 'WRL' then
      begin
      Result := 'external_delivery_gap';
      end
   else
      begin
      Result := 'external_delivery_gap/' + aLogger;
      end;
end;

procedure TExternalDelivery.MigrateLogger(const aOldLogger, aNewLogger,
   aAccount, aLogbook: string);
var
   q: TSQLQuery;
begin
   q := Query('UPDATE external_delivery SET logger = :newlogger ' +
      'WHERE logger = :oldlogger AND account = :account AND logbook = :logbook');
   try
      q.ParamByName('newlogger').AsUTF8String := UTF8Encode(aNewLogger);
      q.ParamByName('oldlogger').AsUTF8String := UTF8Encode(aOldLogger);
      q.ParamByName('account').AsUTF8String := UTF8Encode(aAccount);
      q.ParamByName('logbook').AsUTF8String := UTF8Encode(aLogbook);
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

const
   KEY_WHERE = 'logger = :logger AND account = :account ' +
      'AND logbook = :logbook AND contact = :contact';

   (* WHEN THE DESTINATION ANSWERED: confirmed or failed, the two outcomes in
     which the server took the request and said yes or no. A retry (often no
     answer at all) and an uncertain outcome leave last_sent alone. SQLite's
     own clock, which is Unix seconds UTC, so no caller passes a time and no
     local-time conversion can creep in. Part of Complete's guarded UPDATE,
     so a stale completion moves it no more than it moves the state. *)
   LAST_SENT_NOW = ', last_sent = CAST(strftime(''%s'', ''now'') AS INTEGER)';

function ExternalDeliveryCounts(const aFileName, aLogger: string): TDeliveryCounts;
var
   database: TLogDatabase;
   q: TSQLQuery;
begin
   Result := Default(TDeliveryCounts);
   database := TLogDatabase.Create;
   q := nil;
   try
      database.OpenReadOnly(aFileName);
      q := TSQLQuery.Create(nil);
      q.Database := database.Connection;
      q.Transaction := database.Transaction;
      q.UsePrimaryKeyAsKey := False;
      q.SQL.Text := 'SELECT ' +
         'COUNT(CASE WHEN state = ''pending'' THEN 1 END) AS pending, ' +
         'COUNT(CASE WHEN state = ''inflight'' THEN 1 END) AS inflight, ' +
         'COUNT(CASE WHEN state = ''synced'' THEN 1 END) AS synced, ' +
         'COUNT(CASE WHEN state = ''uncertain'' THEN 1 END) AS uncertain, ' +
         'COUNT(CASE WHEN state = ''failed'' THEN 1 END) AS failed ' +
         'FROM external_delivery WHERE logger = :logger';
      q.ParamByName('logger').AsUTF8String := UTF8Encode(aLogger);
      q.Open;
      Result.Pending := q.FieldByName('pending').AsLargeInt;
      Result.InFlight := q.FieldByName('inflight').AsLargeInt;
      Result.Synced := q.FieldByName('synced').AsLargeInt;
      Result.Uncertain := q.FieldByName('uncertain').AsLargeInt;
      Result.Failed := q.FieldByName('failed').AsLargeInt;
   finally
      q.Free;
      database.Free;
   end;
end;

function ExternalDeliveryStatusesOfQso(const aFileName: string; aRowId: Int64;
                                       out aStatuses: TDeliveryStatusList): boolean;
var
   database: TLogDatabase;
   delivery: TExternalDelivery;
begin
   aStatuses := nil;
   database := TLogDatabase.Create;
   delivery := nil;
   try
      database.OpenReadOnly(aFileName);
      delivery := TExternalDelivery.Create(database);
      Result := delivery.StatusesOfQso(aRowId, aStatuses);
   finally
      delivery.Free;
      database.Free;
   end;
end;

constructor TExternalDelivery.Create(aDatabase: TLogDatabase);
begin
   inherited Create;
   if aDatabase = nil then
      begin
      raise EArgumentException.Create('Delivery tracking requires a database');
      end;
   FDatabase := aDatabase;
end;

function TExternalDelivery.Query(const aSQL: AnsiString): TSQLQuery;
begin
   Result := TSQLQuery.Create(nil);
   try
      Result.Database := FDatabase.Connection;
      Result.Transaction := FDatabase.Transaction;
      Result.UsePrimaryKeyAsKey := False;
      Result.SQL.Text := aSQL;
   except
      Result.Free;
      raise;
   end;
end;

function TExternalDelivery.KeyedQuery(const aSQL: AnsiString;
                                     const aKey: TDeliveryKey): TSQLQuery;
begin
   Result := Query(aSQL);
   try
      Result.ParamByName('logger').AsUTF8String := UTF8Encode(aKey.Logger);
      Result.ParamByName('account').AsUTF8String := UTF8Encode(aKey.Account);
      Result.ParamByName('logbook').AsUTF8String := UTF8Encode(aKey.Logbook);
      Result.ParamByName('contact').AsUTF8String := UTF8Encode(aKey.Contact);
   except
      Result.Free;
      raise;
   end;
end;

procedure TExternalDelivery.Enqueue(const aKey: TDeliveryKey;
                                    const aPayload: string; aDeleted: boolean);
var
   q: TSQLQuery;
begin
   if (aKey.Logger = '') or (aKey.Account = '') or
      (aKey.Logbook = '') or (aKey.Contact = '') then
      begin
      raise EArgumentException.Create('A delivery requires a complete destination and contact identity');
      end;
   q := KeyedQuery('INSERT INTO external_delivery ' +
      '(logger, account, logbook, contact, revision, payload, deleted, state) ' +
      'VALUES (:logger, :account, :logbook, :contact, 1, :payload, :deleted, ''pending'') ' +
      'ON CONFLICT(logger, account, logbook, contact) DO UPDATE SET ' +
      'revision = revision + 1, payload = excluded.payload, deleted = excluded.deleted, ' +
      'state = CASE WHEN state IN (''inflight'', ''uncertain'') THEN state ' +
      'ELSE ''pending'' END, error_code = CASE WHEN state IN (''inflight'', ''uncertain'') ' +
      'THEN error_code ELSE '''' END ' +
      'WHERE payload <> excluded.payload OR deleted <> excluded.deleted', aKey);
   try
      q.ParamByName('payload').AsUTF8String := UTF8Encode(aPayload);
      q.ParamByName('deleted').AsInteger := Ord(aDeleted);
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TExternalDelivery.Requeue(const aKey: TDeliveryKey);
var
   q: TSQLQuery;
begin
   q := KeyedQuery('UPDATE external_delivery SET revision = revision + 1, ' +
      'state = ''pending'', error_code = '''', next_attempt = 0 WHERE ' + KEY_WHERE +
      ' AND state IN (''failed'', ''synced'')', aKey);
   try
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

function TExternalDelivery.Claim(const aLogger, aAccount: string; aNow: Int64;
                                 out aJob: TDeliveryJob): boolean;
var
   q: TSQLQuery;
begin
   aJob := Default(TDeliveryJob);
   Result := False;
   q := Query('SELECT logbook, contact, revision, remote_id, payload, confirmed_payload, deleted ' +
      'FROM external_delivery WHERE logger = :logger AND account = :account ' +
      'AND state = ''pending'' AND next_attempt <= :now ' +
      'ORDER BY next_attempt, logbook, contact LIMIT 1');
   try
      q.ParamByName('logger').AsUTF8String := UTF8Encode(aLogger);
      q.ParamByName('account').AsUTF8String := UTF8Encode(aAccount);
      q.ParamByName('now').AsLargeInt := aNow;
      q.Open;
      if q.EOF then
         begin
         Exit;
         end;
      aJob.Key.Logger := aLogger;
      aJob.Key.Account := aAccount;
      aJob.Key.Logbook := UTF8Decode(q.FieldByName('logbook').AsUTF8String);
      aJob.Key.Contact := UTF8Decode(q.FieldByName('contact').AsUTF8String);
      aJob.Revision := q.FieldByName('revision').AsLargeInt;
      aJob.RemoteId := UTF8Decode(q.FieldByName('remote_id').AsUTF8String);
      aJob.Payload := UTF8Decode(q.FieldByName('payload').AsUTF8String);
      aJob.ConfirmedPayload := UTF8Decode(q.FieldByName('confirmed_payload').AsUTF8String);
      aJob.Deleted := q.FieldByName('deleted').AsInteger <> 0;
   finally
      q.Free;
   end;
   q := KeyedQuery('UPDATE external_delivery SET state = ''inflight'', ' +
      'flight_revision = revision, flight_payload = payload, flight_deleted = deleted WHERE ' + KEY_WHERE +
      ' AND state = ''pending'' AND revision = :revision', aJob.Key);
   try
      q.ParamByName('revision').AsLargeInt := aJob.Revision;
      q.ExecSQL;
      Result := q.RowsAffected = 1;
   finally
      q.Free;
   end;
end;

procedure TExternalDelivery.Complete(const aJob: TDeliveryJob;
   aOutcome: TDeliveryOutcome; const aRemoteId, aErrorCode, aRequestId: string;
   aNextAttempt: Int64);
var
   q: TSQLQuery;
   remoteId, stateSQL, confirmationSQL: string;
begin
   remoteId := aJob.RemoteId;
   if aRemoteId <> '' then
      begin
      remoteId := aRemoteId;
      end;
   if (aOutcome = doConfirmed) and not aJob.Deleted and (remoteId = '') then
      begin
      raise EArgumentException.Create('Confirmed creation requires a remote contact ID');
      end;
   confirmationSQL := '';
   case aOutcome of
      doConfirmed:
         begin
         stateSQL := 'CASE WHEN revision = flight_revision THEN ''synced'' ELSE ''pending'' END';
         confirmationSQL := ', confirmed_revision = flight_revision, ' +
            'confirmed_payload = :confirmed_payload, flight_payload = ''''' +
            LAST_SENT_NOW;
         if aJob.Deleted then
            begin
            remoteId := '';
            end;
         end;
      doRetry:
         begin
         stateSQL := '''pending''';
         end;
      doUncertain:
         begin
         stateSQL := '''uncertain''';
         end;
      doFailed:
         begin
         stateSQL := 'CASE WHEN revision > flight_revision THEN ''pending'' ELSE ''failed'' END';
         confirmationSQL := LAST_SENT_NOW;
         end;
   end;
   q := KeyedQuery(UTF8Encode('UPDATE external_delivery SET state = ' + stateSQL +
      confirmationSQL + ', remote_id = :remote, error_code = :error, ' +
      'request_id = :request, next_attempt = :next WHERE ' + KEY_WHERE +
      ' AND state = ''inflight'' AND flight_revision = :revision'), aJob.Key);
   try
      if aOutcome = doConfirmed then
         begin
         q.ParamByName('confirmed_payload').AsUTF8String := UTF8Encode(aJob.Payload);
         end;
      q.ParamByName('remote').AsUTF8String := UTF8Encode(remoteId);
      q.ParamByName('error').AsUTF8String := UTF8Encode(aErrorCode);
      q.ParamByName('request').AsUTF8String := UTF8Encode(aRequestId);
      q.ParamByName('next').AsLargeInt := aNextAttempt;
      q.ParamByName('revision').AsLargeInt := aJob.Revision;
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

procedure TExternalDelivery.RecoverInterrupted(const aLogger, aAccount: string;
   aUnsafeUpdates: boolean = False);
var
   q: TSQLQuery;
begin
   (* Run once on opening the delivery service, never while a worker is active.
      A lost POST answer cannot be safely replayed without WRL's help. *)
   q := Query('UPDATE external_delivery SET state = CASE ' +
      'WHEN (remote_id = '''' OR :unsafe <> 0) AND flight_deleted = 0 THEN ''uncertain'' ' +
      'ELSE ''pending'' END WHERE logger = :logger AND account = :account ' +
      'AND state = ''inflight''');
   try
      q.ParamByName('logger').AsUTF8String := UTF8Encode(aLogger);
      q.ParamByName('account').AsUTF8String := UTF8Encode(aAccount);
      q.ParamByName('unsafe').AsInteger := Ord(aUnsafeUpdates);
      q.ExecSQL;
   finally
      q.Free;
   end;
end;

function TExternalDelivery.NextAttempt(const aLogger, aAccount: string): Int64;
var
   q: TSQLQuery;
begin
   Result := -1;
   q := Query('SELECT MIN(next_attempt) AS due FROM external_delivery ' +
      'WHERE logger = :logger AND account = :account AND state = ''pending''');
   try
      q.ParamByName('logger').AsUTF8String := UTF8Encode(aLogger);
      q.ParamByName('account').AsUTF8String := UTF8Encode(aAccount);
      q.Open;
      if not q.FieldByName('due').IsNull then
         begin
         Result := q.FieldByName('due').AsLargeInt;
         end;
   finally
      q.Free;
   end;
end;

function TExternalDelivery.RecordHandOff(aHandOff: TExternalHandOff): boolean;
var
   q: TSQLQuery;
   key: TDeliveryKey;
   stateText: string;
begin
   Result := False;
   if (aHandOff.SessionId = 0) and (aHandOff.SessionSeq = 0) then
      begin
      Exit;
      end;
   key.Logger := aHandOff.Logger;
   key.Account := aHandOff.Account;
   key.Logbook := aHandOff.Logbook;
   key.Contact := '';
   (* The contact key is the QSO's guid; the same lookup UpdateQSOBySessionIds
      makes (the newest row of the pair). *)
   q := Query('SELECT guid FROM qso WHERE session_id = :sid ' +
      'AND session_seq = :sseq ORDER BY id DESC LIMIT 1');
   try
      q.ParamByName('sid').AsLargeInt := aHandOff.SessionId;
      q.ParamByName('sseq').AsLargeInt := aHandOff.SessionSeq;
      q.Open;
      if not q.EOF then
         begin
         key.Contact := UTF8Decode(q.Fields[0].AsUTF8String);
         end;
   finally
      q.Free;
   end;
   if (key.Contact = '') or (key.Logger = '') or (key.Account = '') or
      (key.Logbook = '') then
      begin
      Exit;
      end;
   if aHandOff.Delivered then
      begin
      stateText := 'synced';
      end
   else
      begin
      stateText := 'failed';
      end;
   q := KeyedQuery('INSERT INTO external_delivery ' +
      '(logger, account, logbook, contact, revision, payload, state, error_code, last_sent) ' +
      'VALUES (:logger, :account, :logbook, :contact, 1, '''', :state, :error, ' +
      'CAST(strftime(''%s'', ''now'') AS INTEGER)) ' +
      'ON CONFLICT(logger, account, logbook, contact) DO UPDATE SET ' +
      'revision = revision + 1, state = excluded.state, ' +
      'error_code = excluded.error_code, last_sent = excluded.last_sent', key);
   try
      q.ParamByName('state').AsUTF8String := UTF8Encode(stateText);
      q.ParamByName('error').AsUTF8String := UTF8Encode(aHandOff.ErrorCode);
      q.ExecSQL;
   finally
      q.Free;
   end;
   Result := True;
end;

function TExternalDelivery.StatusesOfQso(aRowId: Int64;
                                         out aStatuses: TDeliveryStatusList): boolean;
var
   q: TSQLQuery;
   n: integer;
begin
   aStatuses := nil;
   q := Query('SELECT d.logger, d.account, d.logbook, d.state, d.error_code, ' +
      'd.last_sent ' +
      'FROM external_delivery d JOIN qso ON qso.guid = d.contact ' +
      'WHERE qso.id = :id ' +
      'ORDER BY d.logger, d.account, d.logbook');
   try
      q.ParamByName('id').AsLargeInt := aRowId;
      q.Open;
      n := 0;
      while not q.EOF do
         begin
         SetLength(aStatuses, n + 1);
         aStatuses[n].Logger := UTF8Decode(q.Fields[0].AsUTF8String);
         aStatuses[n].Account := UTF8Decode(q.Fields[1].AsUTF8String);
         aStatuses[n].Logbook := UTF8Decode(q.Fields[2].AsUTF8String);
         aStatuses[n].State := UTF8Decode(q.Fields[3].AsUTF8String);
         aStatuses[n].ErrorCode := UTF8Decode(q.Fields[4].AsUTF8String);
         aStatuses[n].LastSent := q.Fields[5].AsLargeInt;
         Inc(n);
         q.Next;
         end;
      Result := n > 0;
   finally
      q.Free;
   end;
end;

end.
