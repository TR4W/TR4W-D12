unit uWRLExternalLogger;
{$I tr4w.inc}

interface

uses
   VC, uQsoDispatcher, uExternalLoggerService, uLogDatabase, uLogRepository,
   uWRLWorker;

type
   TWRLExternalLogger = class(TExternalLoggerService)
   private
      FAccount, FLogbook, FApiKey, FFileName: string;
      FComputerId: AnsiChar;
      FEnabled, FPaused: boolean;
      FWorker: TWRLWorker;
      FReported: boolean;
      FLocalNotice: string;
      procedure QueueDeliveryNotice;
      procedure ShowDeliveryNotice(aData: PtrInt);
   public
      constructor Create(const aAccount, aLogbook, aApiKey: string;
                         aComputerId: AnsiChar; aEnabled: boolean);
      destructor Destroy; override;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                         out aCommand1: string; out aCommand2: string): TQsoExternalOp; override;
      procedure SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                         const aCommand2: string; const aDescription: string); override;
      function LookupCallsign(ce: ContestExchange): integer; override;
      procedure CaptureSavedQso(aDatabase: TLogDatabase; aRepository: TLogRepository;
                                aRowId: Int64; aNew: boolean); override;
      procedure AfterLogCommit(aDatabase: TLogDatabase); override;
      procedure LogClosed; override;
   end;

implementation

uses
   SysUtils, sqldb, uQsoMyFacts, uExternalDelivery, uWRLContact, PostUnit, Log4D,
   uAppStrings, TF, Forms;

constructor TWRLExternalLogger.Create(const aAccount, aLogbook, aApiKey: string;
   aComputerId: AnsiChar; aEnabled: boolean);
begin
   inherited Create;
   FAccount := aAccount;
   FLogbook := aLogbook;
   FApiKey := aApiKey;
   FComputerId := aComputerId;
   FEnabled := aEnabled;
end;

destructor TWRLExternalLogger.Destroy;
begin
   LogClosed;
   inherited Destroy;
end;

function TWRLExternalLogger.PrepareOp(const aKind: TQsoMessageKind;
   const ce: ContestExchange; out aCommand1: string; out aCommand2: string): TQsoExternalOp;
begin
   aCommand1 := '';
   aCommand2 := '';
   Result := xoNone;  (* Delivery was captured with the QSO, not in this volatile queue. *)
end;

procedure TWRLExternalLogger.SubmitOp(const aOp: TQsoExternalOp;
   const aCommand1, aCommand2, aDescription: string);
begin
end;

function TWRLExternalLogger.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
end;

procedure TWRLExternalLogger.CaptureSavedQso(aDatabase: TLogDatabase;
   aRepository: TLogRepository; aRowId: Int64; aNew: boolean);
var
   rec: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
   key: TDeliveryKey;
   destinations: array of TDeliveryKey;
   i: integer;
   payload: string;
   q: TSQLQuery;
   delivery: TExternalDelivery;
   savepointOpen: boolean;
begin
   if not FEnabled or FPaused or (FAccount = '') or (FLogbook = '') then
      begin
      Exit;
      end;
   if not aRepository.LoadQSO(aRowId, rec) or (rec.ceRecordKind <> rkQSO) then
      begin
      Exit;
      end;
   savepointOpen := False;
   try
      aDatabase.Connection.ExecuteDirect('SAVEPOINT external_capture');
      savepointOpen := True;
      key.Logger := 'WRL';
      key.Account := FAccount;
      key.Logbook := FLogbook;
      q := TSQLQuery.Create(nil);
      try
         q.Database := aDatabase.Connection;
         q.Transaction := aDatabase.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT guid FROM qso WHERE id = :id';
         q.ParamByName('id').AsLargeInt := aRowId;
         q.Open;
         key.Contact := UTF8Decode(q.Fields[0].AsUTF8String);
         q.Close;
         (* An existing binding is the original uploader's durable ownership.
            It survives an edited computer ID and a changed setup destination. *)
         q.SQL.Text := 'SELECT account, logbook FROM external_delivery ' +
            'WHERE logger = ''WRL'' AND contact = :contact';
         q.ParamByName('contact').AsUTF8String := UTF8Encode(key.Contact);
         q.Open;
         SetLength(destinations, 0);
         while not q.EOF do
            begin
            i := Length(destinations);
            SetLength(destinations, i + 1);
            destinations[i] := key;
            destinations[i].Account := UTF8Decode(q.FieldByName('account').AsUTF8String);
            destinations[i].Logbook := UTF8Decode(q.FieldByName('logbook').AsUTF8String);
            q.Next;
            end;
         q.Close;
         if Length(destinations) = 0 then
            begin
            if not aNew or not QsoWasLoggedHere(rec.ceComputerID, FComputerId) then
               begin
               (* No implicit backfill and no upload of a peer-owned row. *)
               aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
               Exit;
               end;
            SetLength(destinations, 1);
            destinations[0] := key;
            end;
      finally
         q.Free;
      end;
      payload := '{}';
      if not rec.ceQSO_Deleted then
         begin
         aRepository.LoadQSOMyFacts(aRowId, facts, sent);
         payload := WRLContactFromADIF(ADIFContactForExternal(rec, facts, sent),
            UTF8Decode(facts.Call));
         end;
      delivery := TExternalDelivery.Create(aDatabase);
      try
         for i := 0 to High(destinations) do
            begin
            delivery.Enqueue(destinations[i], payload, rec.ceQSO_Deleted);
            end;
      finally
         delivery.Free;
      end;
      aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
   except
      on E: Exception do
         begin
         FPaused := True;
         if savepointOpen then
            begin
            (* If SQLite aborted the outer transaction, this raises too: the
               caller must then report LOCAL save failure rather than success. *)
            aDatabase.Connection.ExecuteDirect('ROLLBACK TO SAVEPOINT external_capture');
            aDatabase.Connection.ExecuteDirect('RELEASE SAVEPOINT external_capture');
            aRepository.ReprepareAfterSavepointRollback;
            end;
         try
            aDatabase.Connection.ExecuteDirect(
               'INSERT OR REPLACE INTO session_state(key, value) ' +
               'VALUES (''external_delivery_gap'', ''1'')');
         except
            on markerError: Exception do
               begin
               TLogLogger.GetLogger('WRL').Error(
                  '[WRL] Could not persist the synchronization-gap marker (%s)',
                  [markerError.ClassName]);
               end;
         end;
         TLogLogger.GetLogger('WRL').Error(
            '[WRL] Delivery capture paused (%s); local logging continues. ' +
            'Review delivery before resuming synchronization.', [E.ClassName]);
         end;
   end;
end;

procedure TWRLExternalLogger.AfterLogCommit(aDatabase: TLogDatabase);
begin
   if FPaused then
      begin
      if FWorker <> nil then
         begin
         FWorker.RequestStop;
         end;
      ShowDeliveryNotice(0);
      Exit;
      end;
   if not FEnabled then
      begin
      Exit;
      end;
   if (FAccount = '') or (FLogbook = '') or (FApiKey = '') then
      begin
      (* A temporarily unavailable vault must not discard delivery intent.
         Capture still queues contacts when their destination is known. *)
      FLocalNotice := 'WRL_SETUP_REQUIRED';
      ShowDeliveryNotice(0);
      Exit;
      end;
   if (FWorker <> nil) and (FFileName <> aDatabase.FileName) then
      begin
      LogClosed;
      end;
   if FWorker = nil then
      begin
      (* SQLite has one writer. Worker metadata transactions are short and
         never span HTTP; allow a bounded local-lock wait rather than treating
         a concurrent state update as loss of the contest log. This setting
         belongs to this connection only and vanishes on close. *)
      aDatabase.Connection.ExecutePragma('PRAGMA busy_timeout = 250');
      FFileName := aDatabase.FileName;
      FWorker := TWRLWorker.Create(FFileName, FAccount, FApiKey);
      FWorker.OnNotice := QueueDeliveryNotice;
      FWorker.Start;
      end;
   FWorker.Wake;
end;

procedure TWRLExternalLogger.QueueDeliveryNotice;
begin
   (* Called on the worker. The callback only queues a main-thread notice.
      LogClosed joins the worker before removing this owner's queued calls. *)
   Application.QueueAsyncCall(ShowDeliveryNotice, 0);
end;

procedure TWRLExternalLogger.ShowDeliveryNotice(aData: PtrInt);
var
   notice: string;
begin
   if FReported then
      begin
      Exit;
      end;
   notice := '';
   if FLocalNotice <> '' then
      begin
      notice := FLocalNotice;
      end
   else if FPaused then
      begin
      notice := 'SYNCHRONIZATION_GAP';
      end
   else if FWorker <> nil then
      begin
      notice := FWorker.TakeNotice;
      end;
   if notice <> '' then
      begin
      FReported := True;
      if not tSilentExport then
         begin
         showwarning(UTF8Decode(Format(SWRLDeliveryIssue, [UTF8Encode(notice)])));
         end;
      end;
end;

procedure TWRLExternalLogger.LogClosed;
begin
   FreeAndNil(FWorker);
   Application.RemoveAsyncCalls(Self);
   FFileName := '';
   FPaused := False;
   FReported := False;
   FLocalNotice := '';
end;

end.
