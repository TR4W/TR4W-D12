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

   (* ONE QSO'S DELIVERY, as Edit QSO shows it -- a value, so nothing of sqldb
     leaves this unit. Logger = '' means the QSO has no delivery row.
     LastSent is Unix seconds UTC, 0 when the destination never answered. *)
   TDeliveryStatus = record
      Logger, State, ErrorCode: string;
      LastSent: Int64;
   end;

(* An on-demand, read-only snapshot. Never commits a caller's live connection
   or leaves a WAL reader pinned while Preferences is open. *)
function ExternalDeliveryCounts(const aFileName, aLogger: string): TDeliveryCounts;

(* The delivery of qso row aRowId -- TExternalDelivery.StatusOfQso, through its
  own short-lived read-only connection for the same reason as the counts: the
  caller's live connection may hold a read transaction from an earlier read,
  and its snapshot would not show what the worker has written since. False,
  with Logger = '', when the QSO has no delivery row. Raises if the file will
  not open. *)
function ExternalDeliveryStatusOfQso(const aFileName: string; aRowId: Int64;
                                     out aStatus: TDeliveryStatus): boolean;

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
      function Claim(const aLogger, aAccount: string; aNow: Int64;
                     out aJob: TDeliveryJob): boolean;
      procedure Complete(const aJob: TDeliveryJob; aOutcome: TDeliveryOutcome;
                         const aRemoteId, aErrorCode, aRequestId: string;
                         aNextAttempt: Int64);
      procedure RecoverInterrupted(const aLogger, aAccount: string);
      function NextAttempt(const aLogger, aAccount: string): Int64;
      (* The delivery of the qso row aRowId, joined through qso.guid (the
         contact key). The key allows more than one destination row per
         contact, though CaptureSavedQso keeps edits on the first binding, so
         a second row today comes only from a hand edit or future code; the
         one answered most recently is returned. False, with Logger = '',
         when none. *)
      function StatusOfQso(aRowId: Int64; out aStatus: TDeliveryStatus): boolean;
   end;

implementation

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

function ExternalDeliveryStatusOfQso(const aFileName: string; aRowId: Int64;
                                     out aStatus: TDeliveryStatus): boolean;
var
   database: TLogDatabase;
   delivery: TExternalDelivery;
begin
   aStatus := Default(TDeliveryStatus);
   database := TLogDatabase.Create;
   delivery := nil;
   try
      database.OpenReadOnly(aFileName);
      delivery := TExternalDelivery.Create(database);
      Result := delivery.StatusOfQso(aRowId, aStatus);
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

procedure TExternalDelivery.RecoverInterrupted(const aLogger, aAccount: string);
var
   q: TSQLQuery;
begin
   (* Run once on opening the delivery service, never while a worker is active.
      A lost POST answer cannot be safely replayed without WRL's help. *)
   q := Query('UPDATE external_delivery SET state = CASE ' +
      'WHEN remote_id = '''' AND flight_deleted = 0 THEN ''uncertain'' ' +
      'ELSE ''pending'' END WHERE logger = :logger AND account = :account ' +
      'AND state = ''inflight''');
   try
      q.ParamByName('logger').AsUTF8String := UTF8Encode(aLogger);
      q.ParamByName('account').AsUTF8String := UTF8Encode(aAccount);
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

function TExternalDelivery.StatusOfQso(aRowId: Int64;
                                       out aStatus: TDeliveryStatus): boolean;
var
   q: TSQLQuery;
begin
   aStatus := Default(TDeliveryStatus);
   q := Query('SELECT d.logger, d.state, d.error_code, d.last_sent ' +
      'FROM external_delivery d JOIN qso ON qso.guid = d.contact ' +
      'WHERE qso.id = :id ' +
      'ORDER BY d.last_sent DESC, d.logger, d.account, d.logbook LIMIT 1');
   try
      q.ParamByName('id').AsLargeInt := aRowId;
      q.Open;
      Result := not q.EOF;
      if Result then
         begin
         aStatus.Logger := UTF8Decode(q.Fields[0].AsUTF8String);
         aStatus.State := UTF8Decode(q.Fields[1].AsUTF8String);
         aStatus.ErrorCode := UTF8Decode(q.Fields[2].AsUTF8String);
         aStatus.LastSent := q.Fields[3].AsLargeInt;
         end;
   finally
      q.Free;
   end;
end;

end.
