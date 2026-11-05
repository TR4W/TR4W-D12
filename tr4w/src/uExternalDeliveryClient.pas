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
