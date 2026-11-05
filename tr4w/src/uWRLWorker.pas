unit uWRLWorker;
{$I tr4w.inc}
interface
uses uExternalDeliveryWorker, uExternalDeliveryClient, uWRLClient;
const
   WRL_WORKER_BUSY_TIMEOUT_MS = uExternalDeliveryWorker.DELIVERY_WORKER_BUSY_TIMEOUT_MS;
   WRL_WORKER_BUSY_ATTEMPTS = uExternalDeliveryWorker.DELIVERY_WORKER_BUSY_ATTEMPTS;
type
   TWRLWorker = class(TExternalDeliveryWorker)
   private
      FApiKey: string;
   protected
      function NewClient: TExternalDeliveryClient; override;
   public
      constructor Create(const aFileName, aAccount, aApiKey: string;
                         const aLoggerId: string = 'WRL');
   end;
implementation
constructor TWRLWorker.Create(const aFileName, aAccount, aApiKey: string;
                             const aLoggerId: string);
begin
   inherited Create(aFileName, aAccount, aLoggerId);
   FApiKey := aApiKey;
end;
function TWRLWorker.NewClient: TExternalDeliveryClient;
begin
   Result := TWRLClient.Create(FApiKey);
end;
end.
