unit uExternalLoggerService;
{$I tr4w.inc}

interface

uses
   VC, uQsoDispatcher, uLogDatabase, uLogRepository, uExternalDelivery;

type
   (* WHAT A LOGGER IS DOING NOW (issue 226), as the Preferences grid shows it.
      The state is DERIVED (DeriveExternalLoggerState) from a snapshot of the
      running service plus the configured flag; nothing stores it. *)
   TExternalLoggerState = (
      elsDisabled,       (* switched off, and the running service agrees *)
      elsRestartNeeded,  (* the configuration and the running service disagree *)
      elsIdle,           (* on, nothing pending, nothing wrong *)
      elsSending,        (* a request is out, or work is waiting its turn *)
      elsRetrying,       (* the last attempt failed in a way that will be retried *)
      elsPaused,         (* stopped until the operator acts (credentials, URL...) *)
      elsFailed);        (* the last delivery was refused, or the worker died *)

   (* A VALUE COPIED OUT OF A RUNNING SERVICE, on the main thread. Everything
      a worker thread owns is read under that worker's own lock; nothing here
      points back into the service. A record because it is only ever passed by
      value as an interface parameter. *)
   TExternalLoggerSnapshot = record
      (* The running service was started switched on. *)
      Active: boolean;
      (* The worker thread exists and has not exited. *)
      WorkerRunning: boolean;
      (* A request to the destination is out right now. *)
      Busy: boolean;
      (* Delivery has stopped and will not resume this session. Code says why. *)
      Halted: boolean;
      (* The worker has settled at least one delivery; LastOutcome is that one's. *)
      HasResult: boolean;
      LastOutcome: TDeliveryOutcome;
      (* The last delivery's error code, or the reason delivery halted. A fixed
         code, never text from a server. *)
      Code: string;
      (* Operations waiting in a service that keeps an in-memory queue. *)
      QueueDepth: integer;
   end;

   (* Protocol-neutral contract. The factory selects the implementation;
      callers neither select a wire format nor own a transport. *)
   TExternalLoggerService = class
   public
      DisplayName: string;
      (* Fills the parts of aSnapshot only this service knows. Main thread. *)
      procedure FillSnapshot(var aSnapshot: TExternalLoggerSnapshot); virtual;
      (* The snapshot of the destination aDeliveryId names; False when this
         service does not run it. Only the composite answers. Main thread. *)
      function StateSnapshot(const aDeliveryId: string;
         out aSnapshot: TExternalLoggerSnapshot): boolean; virtual;
      procedure SetActive(aActive: boolean); virtual;
      function QueuesCommands: boolean; virtual;
      procedure PrepareMessage(const aMessage: TQsoMessage;
                               const ce: ContestExchange); virtual;
      procedure SubmitMessage(const aMessage: TQsoMessage); virtual;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
                         out aCommand1: string; out aCommand2: string): TQsoExternalOp;
                         virtual; abstract;
      procedure SubmitOp(const aOp: TQsoExternalOp; const aCommand1: string;
                         const aCommand2: string; const aDescription: string);
                         virtual; abstract;
      function LookupCallsign(ce: ContestExchange): integer; virtual; abstract;
      (* Main-thread database hook. The row is saved but not committed yet.
         TCP loggers retain their dispatcher path; durable loggers override. *)
      procedure CaptureSavedQso(aDatabase: TLogDatabase; aRepository: TLogRepository;
                                aRowId: Int64; aNew: boolean); virtual;
      procedure AfterLogCommit(aDatabase: TLogDatabase); virtual;
      procedure LogClosed; virtual;
      procedure RequestStop; virtual;
      function StopFinished: boolean; virtual;
      procedure DetachOwner; virtual;
   end;

(* THE STATE, FROM ITS INPUTS, AND NOTHING ELSE (so a table test pins it).
   aConfigEnabled is the Preferences flag; aKnown says the running service
   has this destination, and aSnapshot is meaningful only then. aCounts are the
   durable queue counts (zero when the log is not open).

   In order: a destination the service does not run, or one whose started
   switch differs from the flag, needs a restart to mean what the flag says;
   switched off is Disabled; a halted worker is Paused, unless it died
   (DELIVERY_STOPPED), which is Failed; a request out is Sending; the last
   delivery refused is Failed, and one to be retried is Retrying; work waiting
   is Sending; otherwise Idle. Old failed or uncertain rows do NOT make a row
   Failed -- the text carries their counts instead. *)
function DeriveExternalLoggerState(aConfigEnabled, aKnown: boolean;
   const aSnapshot: TExternalLoggerSnapshot;
   const aCounts: TDeliveryCounts): TExternalLoggerState;

const
   (* The worker's code when it stopped on a fault rather than on a refusal. *)
   DELIVERY_STOPPED_CODE = 'DELIVERY_STOPPED';

implementation

function DeriveExternalLoggerState(aConfigEnabled, aKnown: boolean;
   const aSnapshot: TExternalLoggerSnapshot;
   const aCounts: TDeliveryCounts): TExternalLoggerState;
begin
   if (not aKnown) or (aConfigEnabled <> aSnapshot.Active) then
      begin
      if aConfigEnabled or (aKnown and aSnapshot.Active) then
         begin
         Result := elsRestartNeeded;
         end
      else
         begin
         Result := elsDisabled;
         end;
      Exit;
      end;
   if not aConfigEnabled then
      begin
      Result := elsDisabled;
      end
   else if aSnapshot.Halted then
      begin
      if aSnapshot.Code = DELIVERY_STOPPED_CODE then
         begin
         Result := elsFailed;
         end
      else
         begin
         Result := elsPaused;
         end;
      end
   else if aSnapshot.Busy then
      begin
      Result := elsSending;
      end
   else if aSnapshot.HasResult and (aSnapshot.LastOutcome = doFailed) then
      begin
      Result := elsFailed;
      end
   else if aSnapshot.HasResult and (aSnapshot.LastOutcome = doRetry) then
      begin
      Result := elsRetrying;
      end
   else if (aCounts.Pending + aCounts.InFlight + aSnapshot.QueueDepth) > 0 then
      begin
      Result := elsSending;
      end
   else
      begin
      Result := elsIdle;
      end;
end;

procedure TExternalLoggerService.FillSnapshot(var aSnapshot: TExternalLoggerSnapshot);
begin
end;

function TExternalLoggerService.StateSnapshot(const aDeliveryId: string;
   out aSnapshot: TExternalLoggerSnapshot): boolean;
begin
   aSnapshot := Default(TExternalLoggerSnapshot);
   Result := False;
end;

function TExternalLoggerService.QueuesCommands: boolean;
begin
   Result := True;
end;

procedure TExternalLoggerService.SetActive(aActive: boolean);
begin
end;

procedure TExternalLoggerService.RequestStop;
begin
end;

function TExternalLoggerService.StopFinished: boolean;
begin
   Result := True;
end;

procedure TExternalLoggerService.DetachOwner;
begin
end;

procedure TExternalLoggerService.PrepareMessage(const aMessage: TQsoMessage;
   const ce: ContestExchange);
begin
   aMessage.ExtOp := PrepareOp(aMessage.Kind, ce,
      aMessage.ExtCommand1, aMessage.ExtCommand2);
end;

procedure TExternalLoggerService.SubmitMessage(const aMessage: TQsoMessage);
begin
   SubmitOp(aMessage.ExtOp, aMessage.ExtCommand1, aMessage.ExtCommand2,
      aMessage.Description);
end;

procedure TExternalLoggerService.CaptureSavedQso(aDatabase: TLogDatabase;
   aRepository: TLogRepository; aRowId: Int64; aNew: boolean);
begin
end;

procedure TExternalLoggerService.AfterLogCommit(aDatabase: TLogDatabase);
begin
end;

procedure TExternalLoggerService.LogClosed;
begin
end;

end.
