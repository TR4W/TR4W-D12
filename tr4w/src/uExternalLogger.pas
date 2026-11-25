unit uExternalLogger;
{$I tr4w.inc}

interface
uses uExternalLoggerBase, uExternalLoggerActions, uLogDatabase, uLogRepository, StrUtils, SysUtils, Math, TF, VC, LOGSUBS2, LogWind, LogDupe, Tree, uCFG, PostUnit,
     IdTCPClient, uQsoDispatcher, uHostResolve, uQsoMyFacts;


Type TExternalLogger = class(TExternalLoggerBase)
   private
     // localCE: ContestExchange;
      procedure Initialize;
      procedure SendToLogger(sCmd: string; sData: string); overload;
      function AddADIFField(sFieldName: string; sValue: string): string; overload;
      function AddADIFField(sFieldName: string; nValue: integer): string; overload;

      // DXKeeper -- these now BUILD and return the DXKeeper message; the actual
      // send is queued (one connect-per-command op on the sender thread). Issue #957.
      function BuildDXKeeperLogMessage(const ce: ContestExchange;
                                       const aFacts: TQsoMyFacts;
                                       const aRecordedSent: AnsiString): string;
      function BuildDXKeeperDeleteMessage(ce: ContestExchange): string; // These functions should be changed to an interface so we just call one based on the interface (by log type). ny4i
      function LookupCallsignToDXKeeper(ce: ContestExchange): integer;

      // HRD
      function LogQSOToHRD(ce: ContestExchange): integer;



      // Add a QueueQSO to copy the record then return to the caller. This allows the actual sending of the TCP message ot be done from a different thread to not slow down the program.

      // I could also generalize this into post QSO Processing and let the UDP happen from the thread too. Worth exploring the actual amont of time per QSO to send to UDP and TCP. If it is very fast, this complication may not be necessary.
   protected
      // DXKeeper transport: one connect -> send one command -> let DXKeeper close
      // (its by-design model; confirmed with AA6YQ). Issue #957.
      function DeliverCommand(const cmd: string): boolean; override;
      (* The sender thread: leaves the hand-off record Edit QSO's delivery
         window lists. DXKeeper replies with nothing, so a delivered op means
         "written to DXKeeper", never "DXKeeper accepted it". *)
      procedure OpSettled(aOp: TExternalLogOp; aDelivered: boolean;
                          const aErrorCode: string); override;

   public
      Constructor Create(); overload;
      Constructor Create(logType: ExternalLoggerType{sLoggerType: string}); overload;

      function Connect: integer; overload;
      procedure ProcessMessage(sMessage: string);
      function LogQSO(ce: ContestExchange): integer;
      function DeleteQSO(ce: ContestExchange): integer;
      function ReplaceQSO(ce: ContestExchange): integer;   // Issue #957 -- edit = atomic delete + re-log
      function LookupCallsign(ce:ContestExchange): integer; override;
      procedure SubmitOpFor(const aDeliveryId: string; aSessionId, aSessionSeq: Int64;
                            const aOp: TQsoExternalOp; const aCommand1: string;
                            const aCommand2: string; const aDescription: string); override;

      (* THE SAME OPERATIONS, SPLIT AT THE THREAD BOUNDARY (2026-10-24).

        PrepareOp BUILDS the command text, which reads live state (the
        operator, MY CALL, the contest, the sent-exchange template), so it runs
        on the MAIN thread. SubmitOp only appends to this logger's own locked
        queue, so the QSO dispatcher thread calls it. LogQSO, DeleteQSO and
        ReplaceQSO are Prepare + Submit in a row. *)
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                         const aFacts: TQsoMyFacts; const aRecordedSent: AnsiString;
                         out aCommand1: string; out aCommand2: string): TQsoExternalOp; override;
      procedure SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                         const aCommand2: string; const aDescription: string); override;
      (* RESYNC FOR DXKEEPER (NY4I, 2026-11-25). DXKeeper keeps no delivery
         queue and cannot say whether a QSO is already there, so ONLY the QSOs
         whose hand-off row is FAILED are sent again, whatever aMode says (a
         synced one is never re-sent: it could duplicate). Main thread; it only
         READS and queues ops on the sender thread (ONE attempt each), so the UI
         never waits on a connect. The hand-off record each op leaves (OpSettled)
         marks the row synced, or leaves it failed with the reason. *)
      function ResendQsos(aDatabase: TLogDatabase; aRepository: TLogRepository;
         const aDeliveryId: string; aMode: TResendMode; const aTally: TResendTally;
         out aRefusal: string): boolean; override;

end;


(* THE ARRL_SECT THE DXKEEPER HAND-OFF SENDS, or '' for none -- issue 266,
  2026-11-10. (SINCE 2026-11-24 THE DXKEEPER RECORD IS THE ADIF EXPORT'S, built
  by the contest class, which writes ARRL_SECT by this same rule; this function
  is now the N1MM UDP <section>'s.)

  IN A CONTEST WHOSE QTH IS AN ARRL SECTION (uContestBase.
  ContestQTHIsAnARRLSection: both Sweepstakes, both Field Days, ARRL 160) it
  is uADIF.ADIFSectionOf, the rule the ADIF export writes: the section the
  domestic table resolved, so a typed EM sends EMA and a typed WF sends WCF.
  It sent the typed text when Tree.LooksLikeASection passed it -- EM went out
  as <ARRL_SECT:2>EM, not a section ADIF knows -- and nothing for WF, SN, NY
  or any Canadian section.

  IN EVERY OTHER CONTEST IT IS NONE (NY4I, 2026-11-11: "unless we know the
  ARRL section for certain, then we should not send that in ADIF to any ADIF
  consumer"). A state-party or NAQP 'OH' is an Ohio QTH, not a section the
  contest states, and ADIFSectionOf's DomesticQTH fallback reads another
  contest's domestic key as a section -- measured over the shipped .dom
  files, Wisconsin's county 'Mar' would go out as Maritime, xe.dom's Baja
  California 'BC' as British Columbia, ukraine.dom's 'Vi' as the Virgin
  Islands. This used to send the typed QTH when LooksLikeASection passed it. *)
function ExternalLoggerARRLSection(const ce: ContestExchange): string;

var
   firstProcessMessage: boolean = true;
implementation

Uses
   uExternalLoggerRegistry, uExternalLoggerConfig, uExternalLoggerService,
   uAppStrings,
   sqldb,            // the failed-row query of ResendQsos
   Forms,           // Application.QueueAsyncCall -- the hand-off record
   uExternalDelivery, // TExternalHandOff
   uLogStore,        // LogStoreRecordExternalHandOff
   uADIF,         // ADIFSectionOf (ExternalLoggerARRLSection)
   uSettingsModel,   // Settings.My.Call
   MainUnit,
   uContestBase,     // ContestQTHIsAnARRLSection
   uContestRegistry; // ContestIdentity -- the contest's ADIF id

function ExternalLoggerARRLSection(const ce: ContestExchange): string;
begin
   if ContestQTHIsAnARRLSection(ContestIdentity(ce.ceContest)) then
      begin
      Result := ADIFSectionOf(ce);
      end
   else
      begin
      Result := '';
      end;
end;

Constructor TExternalLogger.Create();
begin
   inherited Create(ProcessMessage);
end;

Constructor TExternalLogger.Create(logType: ExternalLoggerType) {sLoggerType: string)};
begin
  // Self.loggerID := sLoggerType;
  Self.logType := logType;
  Self.logTypeSet := true;
   Self.Create(ProcessMessage);
end;

function TExternalLogger.Connect: integer;
begin
   Self.readTerminator := ';';
   Result := Inherited Connect;
   if Self.IsConnected then
      begin
      end;
end;

procedure TExternalLogger.ProcessMessage(sMessage: string);
var
   sCommand: string;
  // i: integer;
begin
// This is called by the process that receives data on the socket - Event
   logger.Debug('[TExternalLogger.ProcessMessage] Received from external logger: (%s)',[sMessage]);
   sCommand := AnsiLeftStr(sMessage,2);

   
   if firstProcessMessage then
      begin
      firstProcessMessage := false;
      Initialize;
      end;
end;



procedure TExternalLogger.Initialize;
begin

end;

const
   DXK_CONNECT_TIMEOUT_MS = 2000;   // DXKeeper is normally local; fail fast and retry
   DXK_READ_TIMEOUT_MS    = 1000;   // bound the wait for a response / the close

function TExternalLogger.DeliverCommand(const cmd: string): boolean;
var
   client: TIdTCPClient;
   resp: string;
begin
   // Issue #957 -- DXKeeper reads exactly one command per connection, then closes
   // (its by-design model, confirmed with AA6YQ).  So each command gets its own
   // fresh connection: connect -> send -> read any response until DXKeeper closes.
   // Runs on the sender thread, never the main thread.  The caller (DeliverWithRetry)
   // handles bounded retry on failure.
   (* client is local to this call and this thread: no reading thread exists for
     it, so client.Connected below (a read) is a read by the socket's sole
     owner.  It must stay that way -- see the rule in uExternalLoggerBase. *)
   Result := False;
   client := TIdTCPClient.Create(nil);
   try
      client.Port := Self.loggerPort;
      client.ConnectTimeout := DXK_CONNECT_TIMEOUT_MS;
      client.ReadTimeout := DXK_READ_TIMEOUT_MS;
      try
         (* THE SENDER THREAD, which may wait: the name goes through the
           platform resolver (uHostResolve, issue 148; Windows is unchanged).
           A name that will not resolve raises with the host in the message and
           the handler below logs it with the others. *)
         client.Host := AnsiString(ResolveHostForConnect(Self.loggerAddress));
         client.Connect;
         try
            client.IOHandler.WriteLn(cmd);
            Result := True;   // the command is on the wire = success
            logger.Debug('[DXKeeper.DeliverCommand] sent: %s', [cmd]);
            // Best-effort: read any response until DXKeeper closes (bounded).
            try
               while client.Connected do
                  begin
                  resp := client.IOHandler.ReadLn(';', DXK_READ_TIMEOUT_MS);
                  if client.IOHandler.ReadLnTimedout then
                     begin
                     Break;
                     end;
                  if resp <> '' then
                     begin
                     logger.Debug('[DXKeeper.DeliverCommand] response: %s', [resp]);
                     Self.ProcessMessage(resp);
                     end;
                  end;
            except
               on Exception do
                  begin
                  // DXKeeper closing after the command is the normal/expected path.
                  end;
            end;
         finally
            try
               if client.Connected then
                  begin
                  client.Disconnect;
                  end;
            except
               on Exception do
                  begin
                  // ignore disconnect errors
                  end;
            end;
         end;
      except
         on E: Exception do
            begin
            logger.Warn('[DXKeeper.DeliverCommand] %s:%d failed: %s - %s',
                        [Self.loggerAddress, Self.loggerPort, E.ClassName, E.Message]);
            // Result stays False unless WriteLn already succeeded -> caller retries.
            end;
      end;
   finally
      client.Free;
   end;
end;

procedure TExternalLogger.SendToLogger(sCmd: string; sData: string);
begin
   if not Self.IsConnected then
      begin
      Self.Connect;
      end;
   Inherited SendTologger(Format('%s%s;',[sCmd,sData])); // Build the externalcommand ADIF here

end;

function TExternalLogger.PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                                   const aFacts: TQsoMyFacts; const aRecordedSent: AnsiString;
                                   out aCommand1: string; out aCommand2: string): TQsoExternalOp;
begin
   aCommand1 := '';
   aCommand2 := '';
   Result := xoNone;
   // Only DXKeeper builds commands here; HRD is the incomplete type.
   if Self.logType <> lt_DxKeeper then
      begin
      Exit;
      end;
   case aKind of
      qmNew:
         begin
         aCommand1 := Self.BuildDXKeeperLogMessage(ce, aFacts, aRecordedSent);
         Result := xoSingle;
         end;
      qmDeleted:
         begin
         aCommand1 := Self.BuildDXKeeperDeleteMessage(ce);
         Result := xoSingle;
         end;
      qmEdited:
         begin
         // Delete of the original first, then the re-log: see ReplaceQSO.
         aCommand1 := Self.BuildDXKeeperDeleteMessage(ce);
         aCommand2 := Self.BuildDXKeeperLogMessage(ce, aFacts, aRecordedSent);
         Result := xoReplace;
         end;
   end;
end;

type
   (* The main-thread end of the hand-off record. A method because
      QueueAsyncCall takes one; it holds nothing of any logger, so a job that
      outlives its service is still safe to run. *)
   TDXKeeperHandOffRelay = class(TObject)
   public
      procedure Run(aData: PtrInt);
   end;

var
   GHandOffRelay: TDXKeeperHandOffRelay = nil;
   (* The notice throttle, main thread only (the relay runs there): one line per
      window, the QSOs held back in between are counted into the next. *)
   GUnreachableTick: QWord = 0;
   GUnreachableHeld: integer = 0;

procedure TDXKeeperHandOffRelay.Run(aData: PtrInt);
var
   job: TExternalHandOff;
   now: QWord;
begin
   job := TExternalHandOff(aData);
   try
      LogStoreRecordExternalHandOff(job);
      (* THE OPERATOR IS TOLD IN PLAIN WORDS (NY4I, 2026-11-25), once a minute,
         on the quick-command panel and never a dialog. Not from the sender
         thread: the panel is the main thread's. *)
      if not job.Delivered then
         begin
         Inc(GUnreachableHeld);
         now := GetTickCount64;
         if NotDeliverableNoticeDue(now, GUnreachableTick) and (not tSilentExport) then
            begin
            if GUnreachableHeld = 1 then
               begin
               QuickDisplay(UnicodeFormat(SLoggerDXKeeperUnreachable,
                  [job.Description, job.Account, job.Port]));
               end
            else
               begin
               QuickDisplay(UnicodeFormat(SLoggerDXKeeperUnreachableMany,
                  [GUnreachableHeld, job.Description, job.Account,
                   job.Port]));
               end;
            GUnreachableTick := now;
            GUnreachableHeld := 0;
            end;
         end;
   finally
      job.Free;
   end;
end;

procedure TExternalLogger.OpSettled(aOp: TExternalLogOp; aDelivered: boolean;
                                    const aErrorCode: string);
var
   job: TExternalHandOff;
begin
   (* A lookup, a delete, or a QSO with no network key names no row. *)
   if (aOp.DeliveryId = '') or ((aOp.SessionId = 0) and (aOp.SessionSeq = 0)) then
      begin
      Exit;
      end;
   job := TExternalHandOff.Create;
   job.Logger := aOp.DeliveryId;
   job.Account := Self.loggerAddress;
   job.Logbook := IntToStr(Self.loggerPort);
   job.Description := aOp.Description;
   job.Port := Self.loggerPort;
   job.SessionId := aOp.SessionId;
   job.SessionSeq := aOp.SessionSeq;
   job.Delivered := aDelivered;
   if aDelivered then
      begin
      job.ErrorCode := '';
      end
   else
      begin
      job.ErrorCode := 'DXKEEPER_' + aErrorCode;
      end;
   (* The sender thread never touches the log: the main thread writes. QueueAsyncCall
      RAISES on a shut-down queue; the record is then simply not made. *)
   try
      if (Application = nil) or Application.Terminated then
         begin
         job.Free;
         Exit;
         end;
      Application.QueueAsyncCall(GHandOffRelay.Run, PtrInt(job));
   except
      on E: Exception do
         begin
         job.Free;
         logger.Warn('[DXKeeper] could not queue the delivery record for %s: %s',
                     [aOp.Description, E.ClassName]);
         end;
   end;
end;

procedure TExternalLogger.SubmitOpFor(const aDeliveryId: string; aSessionId, aSessionSeq: Int64;
                                      const aOp: TQsoExternalOp; const aCommand1: string;
                                      const aCommand2: string; const aDescription: string);
begin
   case aOp of
      xoSingle:
         begin
         Self.QueueSingleCommand(aCommand1, aDescription, aDeliveryId, aSessionId, aSessionSeq);
         end;
      xoReplace:
         begin
         Self.QueueReplace(aCommand1, aCommand2, aDescription, aDeliveryId, aSessionId, aSessionSeq);
         end;
   end;
end;

procedure TExternalLogger.SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                                   const aCommand2: string; const aDescription: string);
begin
   case aOp of
      xoSingle:
         begin
         Self.QueueSingleCommand(aCommand1, aDescription);
         end;
      xoReplace:
         begin
         Self.QueueReplace(aCommand1, aCommand2, aDescription);
         end;
   end;
end;

function TExternalLogger.ResendQsos(aDatabase: TLogDatabase; aRepository: TLogRepository;
   const aDeliveryId: string; aMode: TResendMode; const aTally: TResendTally;
   out aRefusal: string): boolean;
var
   q: TSQLQuery;
   ids: array of Int64;
   codes: array of string;
   n, i: integer;
   rec: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
   cmd1, cmd2: string;
begin
   Result := False;
   aRefusal := '';
   if Self.logType <> lt_DxKeeper then
      begin
      aRefusal := 'RESEND_NOT_SUPPORTED';
      Exit;
      end;
   try
      (* The failed rows first, the cursor closed before the loads below use
         the connection. *)
      n := 0;
      q := TSQLQuery.Create(nil);
      try
         q.Database := aDatabase.Connection;
         q.Transaction := aDatabase.Transaction;
         q.UsePrimaryKeyAsKey := False;
         q.SQL.Text := 'SELECT q.id, MAX(d.error_code) FROM qso q ' +
            'JOIN external_delivery d ON d.contact = q.guid AND d.logger = :logger ' +
            'WHERE q.record_kind = ''QSO'' AND q.deleted = 0 AND d.state = ''failed'' ' +
            'AND d.error_code IN (''DXKEEPER_NOT_DELIVERED'', ''DXKEEPER_REPLACE_NOT_SENT'', ' +
            '''DXKEEPER_REPLACE_HALF_DONE'') GROUP BY q.id ORDER BY q.id';
         q.ParamByName('logger').AsUTF8String := UTF8Encode(aDeliveryId);
         q.Open;
         while not q.EOF do
            begin
            SetLength(ids, n + 1);
            SetLength(codes, n + 1);
            ids[n] := q.Fields[0].AsLargeInt;
            codes[n] := UTF8Decode(q.Fields[1].AsUTF8String);
            Inc(n);
            q.Next;
            end;
         q.Close;
      finally
         q.Free;
      end;
      for i := 0 to n - 1 do
         begin
         if not aRepository.LoadQSO(ids[i], rec) or (rec.ceRecordKind <> rkQSO) then
            begin
            Continue;
            end;
         aRepository.LoadQSOMyFacts(ids[i], facts, sent);
         cmd1 := Self.BuildDXKeeperLogMessage(rec, facts, sent);
         if codes[i] = 'DXKEEPER_REPLACE_NOT_SENT' then
            begin
            (* The edit never left: DXKeeper still holds the original, so the
               edit is made again as it was, delete then re-log. *)
            cmd2 := cmd1;
            cmd1 := Self.BuildDXKeeperDeleteMessage(rec);
            Self.QueueReplace(cmd1, cmd2, string(rec.Callsign), aDeliveryId,
               rec.ceQSOID1, rec.ceQSOID2, True);
            end
         else
            begin
            (* NOT_DELIVERED, and HALF_DONE (the old record is already gone):
               a plain new log. *)
            if codes[i] = 'DXKEEPER_REPLACE_HALF_DONE' then
               begin
               Inc(aTally.HalfDone);
               end;
            Self.QueueSingleCommand(cmd1, string(rec.Callsign), aDeliveryId,
               rec.ceQSOID1, rec.ceQSOID2, True);
            end;
         aTally.Add(rvRequeue);
         end;
      Result := True;
   except
      on E: Exception do
         begin
         aRefusal := 'RESEND_FAILED';
         logger.Error('[DXKeeper] Resend failed (%s); nothing more was queued.', [E.ClassName]);
         end;
   end;
end;

function TExternalLogger.LogQSO(ce: ContestExchange): integer;
var
   cmd1, cmd2: string;
begin
   case Self.logType of
      lt_NoExternalLogger:
         begin
         Result := -1;
         logger.Error('Within TExternalLogger.LogQSO, logType set to NoExternalLogger');
         end;
      lt_DxKeeper:
         begin
         Self.SubmitOp(Self.PrepareOp(qmNew, ce, NotCapturedMyFacts, '', cmd1, cmd2),
                       cmd1, cmd2, 'Log ' + ce.Callsign);
         Result := 0;
         end;
      lt_HRD: Result := Self.LogQSOToHRD(ce);
   else
      begin
      (* ACLog is a durable provider now (uACLogExternalLogger); this volatile
         class never carried it. *)
      Result := -1;
      end;
   end;
end;

function TExternalLogger.DeleteQSO(ce: ContestExchange): integer;
var
   cmd1, cmd2: string;
begin
   Result := -1;   // HRD has no arm: not supported, never garbage
   case Self.logType of
      lt_NoExternalLogger:
         begin
         Result := -1;
         logger.Error('Within TExternalLogger.DeleteQSO, logType set to NoExternalLogger');
         end;
      lt_DxKeeper:
         begin
         Self.SubmitOp(Self.PrepareOp(qmDeleted, ce, NotCapturedMyFacts, '', cmd1, cmd2),
                       cmd1, cmd2, 'Delete ' + ce.Callsign);
         Result := 0;
         end;
      //lt_HRD: Result := Self.LogQSOToHRD(ce);
   end;
end;

function TExternalLogger.ReplaceQSO(ce: ContestExchange): integer;
var
   cmd1, cmd2: string;
begin
   // Issue #957 -- an edit is a delete of the original followed by a re-log of the
   // edited QSO.  Queue it as ONE atomic replace so the re-log is sent only if the
   // delete succeeds, and so the two never share a TCP connection (DXKeeper reads
   // exactly one command per connection, then closes).
   case Self.logType of
      lt_NoExternalLogger:
         begin
         Result := -1;
         logger.Error('Within TExternalLogger.ReplaceQSO, logType set to NoExternalLogger');
         end;
      lt_DxKeeper:
         begin
         Self.SubmitOp(Self.PrepareOp(qmEdited, ce, NotCapturedMyFacts, '', cmd1, cmd2),
                       cmd1, cmd2, 'Replace ' + ce.Callsign);
         Result := 0;
         end;
      else
         begin
         // Other loggers: best-effort delete then re-log (no atomic guarantee yet).
         Self.DeleteQSO(ce);
         Self.LogQSO(ce);
         Result := 0;
         end;
   end;
end;

(* Result: 0 = the lookup was queued for the logger; -1 = this logger type does
  not support a lookup (none, HRD, and the legacy ACLog token).  Assigned up front so no path of
  the case can return an unassigned value (garbage under -gt). *)
function TExternalLogger.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
   case Self.logType of
      lt_NoExternalLogger:
         begin
         logger.Error('Within TExternalLogger.LookupCallsign, logType set to NoExternalLogger');
         end;
      lt_DxKeeper:
         begin
         (* This arm called LookupCallsign, i.e. ITSELF, until 2026-10-26
           (issue #101); the D7 tree has the same self-call. *)
         Result := Self.LookupCallsignToDXKeeper(ce);
         end;
      lt_ACLog,
      lt_HRD:
         begin
         logger.Info('Callsign lookup is not implemented for this external logger type');
         end;
   end;
end;

function TExternalLogger.BuildDXKeeperLogMessage(const ce: ContestExchange;
                                                 const aFacts: TQsoMyFacts;
                                                 const aRecordedSent: AnsiString): string;
var sCoreADIF: string;
    nCoreADIFLength: integer;
    sOptions: string;
    nOptionsLength: integer;
    sMessage: string;
begin
(*   This is the example from https://www.dxlabsuite.com/Interoperation.htm
<command:11>externallog<parameters:341><ExternalLogADIF:187><CALL:4>P5DX <RST_SENT:3>599
<RST_RCVD:3>599 <FREQ:6>14.004 <BAND:3>20M <MODE:2>CW <QSO_DATE:8>20220411 <TIME_ON:6>072800
<STATION_CALLSIGN:5>AA6YQ <TX_PWR:4>1000 <GRIDSQUARE:4>PM29 <EOR><UploadeQSL:1>Y
<UploadLoTW:1>Y<UploadClubLog:1>Y<DeduceMissing:1>Y<QueryCallbook:1>Y<UpdateeQSL:1>Y<UpdateLoTW:1>Y<CheckOverrides:1>Y

This is all we need to send as we DO NOT want to send every contact to any of the online QSL services like LOTW, QRZ, eQSL or ClubLog.

<command:11>externallog<parameters:341><ExternalLogADIF:187><CALL:4>P5DX <RST_SENT:3>599
<RST_RCVD:3>599 <FREQ:6>14.004 <BAND:3>20M <MODE:2>CW <QSO_DATE:8>20220411 <TIME_ON:6>072800
<STATION_CALLSIGN:5>AA6YQ <TX_PWR:4>1000 <GRIDSQUARE:4>PM29 <EOR><UploadeQSL:1>N
<UploadLoTW:1>N<UploadClubLog:1>N<DeduceMissing:1>Y<QueryCallbook:1>Y<UpdateeQSL:1>N<UpdateLoTW:1>N<CheckOverrides:1>Y
*)
   (* THE RECORD IS THE ADIF EXPORT'S, NOT ANOTHER ONE (NY4I, 2026-11-24: "the
      contest class hook should be building the adif record ... The same
      contest class adif generator should be what is used to export the adif.
      This ensures the adif process does not diverge."). ADIFContactForExternal
      is what the durable loggers (Club Log, WRL, Cloudlog, QRZ, ACLog) hand
      their payload through: uADIF.EmitADIFContact with the export's tail and
      the QSO's own station and sent exchange. NO FIELD IS BUILT HERE -- a field
      that is missing from a DXKeeper record is missing from the contest class's
      emitter, and is fixed there for the export too.

      Only the record's closing CR LF is dropped: it ends in <EOR>, and the
      framing below counts exactly what DXKeeper is sent. *)
   sCoreADIF := TrimRight(ADIFContactForExternal(ce, aFacts, aRecordedSent));
   nCoreADIFLength := length(sCoreADIF);
   sCoreADIF := '<ExternalLogADIF:' + IntToStr(nCoreADIFLength) + '>' + sCoreADIF;
   nCoreADIFLength := length(sCoreADIF); // Update to include the ExternalLogADIF field
  // Issue #957 -- option flags for the externallog command.
  // Enrichment + membership lookups are ON (Y): DeduceMissing, QueryCallbook,
  // CheckOverrides, UpdateeQSL, UpdateLoTW.  These only fill in or annotate
  // DXKeeper's local copy of the record, so they add useful data without the
  // edit-window concern below.  (An earlier "command in progress" rejection that
  // these appeared to trigger turned out to be a DXKeeper-side bug, since fixed.)
  // QSL-server UPLOADS are OFF (N): UploadeQSL, UploadLoTW, UploadClubLog,
  // UploadQRZ.  Uploading the instant the QSO is logged would leave no window to
  // edit it first; the operator uploads later (or via DXKeeper's own workflow).
  // NOTE: if DXKeeper's AutoUpload options are checked, the Upload* N values are
  // not honored.
  sOptions :=   AddADIFField('DeduceMissing','Y')
              + AddADIFField('QueryCallbook','Y')
              + AddADIFField('CheckOverrides','Y')
              + AddADIFField('UpdateeQSL','Y')
              + AddADIFField('UpdateLoTW','Y')
              + AddADIFField('UploadeQSL','N')
              + AddADIFField('UploadLoTW','N')
              + AddADIFField('UploadClubLog','N')
              + AddADIFField('UploadQRZ','N')
              ;
  nOptionsLength := length(sOptions);
  sMessage := '<command:11>externallog<parameters:' + IntToStr(nCoreADIFLength + nOptionsLength) + '>' + sCoreADIF + sOptions;
  Result := sMessage;
end;

//-------------------------------
function TExternalLogger.BuildDXKeeperDeleteMessage(ce: ContestExchange): string;
var sCoreADIF: string;
    //n: integer;

    nCoreADIFLength: integer;

    sMessage: string;

   // sTemp: string;

begin

  sCoreADIF :=   AddADIFField('CALL',ce.Callsign)
               + AddADIFField('QSO_DATE',SysUtils.format('20%0.2d%0.2d%0.2d',
                                                         [ce.tSysTime.qtYear,
                                                          ce.tSysTime.qtMonth,
                                                          ce.tSysTime.qtDay]))
               + AddADIFField('TIME_ON',SysUtils.format('%0.2d%0.2d%0.2d',
                                                        [ce.tSysTime.qtHour,
                                                         ce.tSysTime.qtMinute,
                                                         ce.tSysTime.qtSecond]))
               ;

  sCoreADIF := sCoreADIF + '<EOR>';
  //nCoreADIFLength := length(sCoreADIF);
 // sCoreADIF := '<ExternalLogADIF:' + IntToStr(nCoreADIFLength) + '>' + sCoreADIF;
  nCoreADIFLength := length(sCoreADIF); // Update to include the ExternalLogADIF field
  sMessage := '<command:9>deleteqso<parameters:' + IntToStr(nCoreADIFLength {+ nOptionsLength}) + '>' + sCoreADIF;
  Result := sMessage;
end;

function TExternalLogger.LookupCallsignToDXKeeper(ce: ContestExchange): integer;
var sMessage: string;
begin
  sMessage := '<command:5>check<parameters:' + IntToStr(length(ce.Callsign)) + '>' + ce.Callsign;
  logger.Debug('[TExternalLogger.LookupQSOToDXKeeper] Queueing message to external logger: [%s]',[sMessage]);
  (* DXKeeper takes one command per connection, so the lookup goes through the
    same queue and connect-per-command transport as a log or a delete.  The
    base SendToLogger it used would have opened the PERSISTENT socket, which
    DXKeeper never uses (see the rule in uExternalLoggerBase). *)
  Self.QueueSingleCommand(sMessage, 'Lookup ' + ce.Callsign);
  Result := 0;
end;
//--------------------------------
function TExternalLogger.LogQSOToHRD(ce: ContestExchange): integer;
begin
   logger.Info('Logging to HRD not yet implemented');
   Result := -1;
end;

function TExternalLogger.AddADIFField(sFieldName: string; sValue: string): string;
begin
   result := '<' + sFieldName + ':' + IntToStr(length(sValue)) + '>' + sValue + ' ';
end;

function TExternalLogger.AddADIFField(sFieldName: string; nValue: integer): string;
begin
   result := '<' + sFieldName + ':' + IntToStr(DigitsIn(nValue)) + '>' + IntToStr(nValue) + ' ';
end;

function CreateDXKeeper(const aDefinition: TExternalLoggerDefinition;
   aComputerId: AnsiChar): TExternalLoggerService;
var
   service: TExternalLogger;
begin
   service := TExternalLogger.Create(lt_DXKeeper);
   service.loggerAddress := aDefinition.Address;
   service.loggerPort := aDefinition.Port;
   service.loggerID := aDefinition.Name;
   Result := service;
end;
procedure DeclareDXKeeperFields(const aFields: TLoggerFieldList);
begin
   aFields.AddText(LF_ADDRESS, SLoggerFieldHost, True);
   aFields.AddPort(LF_PORT, SLoggerFieldPort);
end;
initialization
   GHandOffRelay := TDXKeeperHandOffRelay.Create;
   RegisterExternalLogger('DXKEEPER', 'DXKeeper', CreateDXKeeper, DeclareDXKeeperFields,
      DXKEEPER_DEFAULT_PORT, True);
finalization
   (* Calls still queued must not reach a freed relay. *)
   if (Application <> nil) and (GHandOffRelay <> nil) then
      begin
      Application.RemoveAsyncCalls(GHandOffRelay);
      end;
   FreeAndNil(GHandOffRelay);
end.
