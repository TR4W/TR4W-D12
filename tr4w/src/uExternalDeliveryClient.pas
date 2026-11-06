unit uExternalDeliveryClient;
{$I tr4w.inc}
interface
uses uExternalDelivery;
type
   TExternalDeliveryResult = record
      Outcome: TDeliveryOutcome;
      Status: integer;
      Deleted: boolean;
      RemoteId, ErrorCode, RequestId, DataJSON, NextCursor: string;
      RetrySeconds: Int64;
      Pause: boolean;
      (* Operator-facing text the worker hands to its owner, which shows it on
        the main thread. '' = nothing to say. Set by a client only for a
        condition the operator can cure (issue 221: the CA bundle is missing),
        and only the first time, so it is not shown on every retry. *)
      OperatorNotice: string;
   end;

   TExternalDeliveryClient = class
   public
      function RecoverUpdatesAsUncertain: boolean; virtual;
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; virtual; abstract;
   end;
implementation
function TExternalDeliveryClient.RecoverUpdatesAsUncertain: boolean;
begin
   Result := False;
end;
end.
