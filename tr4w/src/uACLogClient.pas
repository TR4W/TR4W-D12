unit uACLogClient;
{$I tr4w.inc}
(* THE AC LOG (N3FJP) CLIENT (issue 33). AC Log is the TCP server: the operator
   turns on "TCP API Enabled" and the program listens, by default on port 1100.
   One command is one line, `<CMD>...</CMD>` ended by CR LF, and a bare CR LF
   tells AC Log to end the connection. The command used here is

      <CMD><ADDADIFRECORD><VALUE> one ADIF record ending <EOR> </VALUE></CMD>

   (docs/N3FJP Application Program Interface (API).md, "Add ADIF Record", API
   2.0). It writes the record straight to the log: callbook lookup, contest
   scoring and the dupe sheet are bypassed, so this targets AC Log itself, not
   the N3FJP contest programs.

   WHAT IS NOT KNOWN, and the code does not pretend otherwise: no reply to
   ADDADIFRECORD is documented, so nothing is read. A fully written command is
   a HAND-OFF to the TCP stack, the same standing as DXKeeper's -- not an
   acknowledgement that AC Log stored the record. The API has no call to edit
   or delete a logged record and returns no record id, so (like Cloudlog) an
   edit or delete of a contact already delivered fails VISIBLY and sends
   nothing. One connection per delivery, owned by the worker thread alone
   (the connection is never shared, so no thread reads the socket but its
   owner). *)
interface
uses uExternalDeliveryClient, uExternalDelivery, IdTCPClient;
const
   (* Local delivery marker, never sent anywhere: the outbox needs a nonempty
      remote identity on a confirmed creation and AC Log returns none. It also
      tells a later edit or delete "handed over" from "never sent". *)
   ACLOG_ADDED_MARKER = 'aclog:added';
   (* AC Log not running, or its API switched off: try again in a minute. *)
   ACLOG_RETRY_SECONDS = 60;
type
   TACLogClient = class(TExternalDeliveryClient)
   private
      FHost: string;
      FPort: integer;
      function Send(const aAdif: string): TExternalDeliveryResult;
   protected
      (* The one place bytes go to the open connection: a seam, so a test can
         fail a delivery AFTER the connection was established. *)
      procedure SendFrames(aClient: TIdTCPClient; const aCommand: RawByteString); virtual;
   public
      constructor Create(const aHost: string; aPort: integer);
      function Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult; override;
   end;
(* The ADD command for one ADIF record, as it goes on the wire: UTF-8, ended by
   CR LF. The record's own trailing CR LF is dropped and any other CR or LF
   inside it becomes a space (same length, so ADIF lengths hold), because a
   CR LF anywhere in the line would end the command early. *)
function ACLogAddFrame(const aAdif: string): RawByteString;
(* The bare CR LF that ends the connection. *)
function ACLogEndFrame: RawByteString;
implementation
uses SysUtils, IdGlobal, Log4D, uIndyLink, uHostResolve;
const
   ACLOG_CRLF = #13#10;
var
   logger: TLogLogger;

function ACLogAddFrame(const aAdif: string): RawByteString;
var
   value: string;
   i: integer;
begin
   value := aAdif;
   while (value <> '') and
         ((value[Length(value)] = #13) or (value[Length(value)] = #10)) do
      begin
      Delete(value, Length(value), 1);
      end;
   for i := 1 to Length(value) do
      begin
      if (value[i] = #13) or (value[i] = #10) then
         begin
         value[i] := ' ';
         end;
      end;
   Result := UTF8Encode('<CMD><ADDADIFRECORD><VALUE>' + value + '</VALUE></CMD>' + ACLOG_CRLF);
end;

function ACLogEndFrame: RawByteString;
begin
   Result := ACLOG_CRLF;
end;

(* Indy writes bytes; the frames are byte strings. *)
function ToWireBytes(const aText: RawByteString): TIdBytes;
var
   i: integer;
begin
   Result := nil;
   SetLength(Result, Length(aText));
   for i := 1 to Length(aText) do
      begin
      Result[i - 1] := Byte(aText[i]);
      end;
end;

constructor TACLogClient.Create(const aHost: string; aPort: integer);
begin
   inherited Create;
   FHost := aHost;
   FPort := aPort;
end;

procedure TACLogClient.SendFrames(aClient: TIdTCPClient; const aCommand: RawByteString);
begin
   aClient.IOHandler.Write(ToWireBytes(aCommand));
   (* The command is fully written. The bare CR LF only asks AC Log to end the
      connection; if it cannot be written the record is already handed over. *)
   try
      aClient.IOHandler.Write(ToWireBytes(ACLogEndFrame));
   except
      on E: Exception do
         begin
         logger.Debug('[ACLog] the closing CR LF was not written (%s)', [E.ClassName]);
         end;
   end;
end;

function TACLogClient.Send(const aAdif: string): TExternalDeliveryResult;
var
   client: TIdTCPClient;
   connected: boolean;
begin
   Result := Default(TExternalDeliveryResult);
   connected := False;
   client := TIdTCPClient.Create(nil);
   try
      IndyLinkOwnHandler(client, nil);
      client.ConnectTimeout := INDY_LINK_CONNECT_TIMEOUT_MS;
      client.Port := FPort;
      try
         (* Worker thread, which may wait: the name goes through the platform
            resolver (uHostResolve). A name that will not resolve raises here,
            before a byte is written. *)
         client.Host := AnsiString(ResolveHostForConnect(FHost));
         client.Connect;
         connected := True;
         SendFrames(client, ACLogAddFrame(aAdif));
         Result.Outcome := doConfirmed;
         Result.RemoteId := ACLOG_ADDED_MARKER;
      except
         on E: Exception do
            begin
            Result.Status := 0;
            if connected then
               begin
               (* Established, then the write failed part-way: AC Log may or
                  may not have the record. Never replayed blindly. *)
               Result.Outcome := doUncertain;
               Result.Pause := True;
               Result.ErrorCode := 'ACLOG_SEND_REQUIRES_REVIEW';
               end
            else
               begin
               (* Nothing was written: AC Log is not running, or its TCP API is
                  off. A retry is safe and it does not pause the destination. *)
               Result.Outcome := doRetry;
               Result.Pause := False;
               Result.RetrySeconds := ACLOG_RETRY_SECONDS;
               Result.ErrorCode := 'ACLOG_NOT_REACHABLE';
               end;
            logger.Warn('[ACLog] %s:%d delivery failed (%s): %s',
               [FHost, FPort, E.ClassName, Result.ErrorCode]);
            end;
      end;
   finally
      try
         if IndyLinkIsOpen(client) then
            begin
            client.Disconnect(False);
            end;
      except
         on Exception do
            begin
            (* The record is handed over or not already; a close error changes neither. *)
            end;
      end;
      client.Free;
   end;
end;

function TACLogClient.Deliver(const aJob: TDeliveryJob): TExternalDeliveryResult;
begin
   Result := Default(TExternalDeliveryResult);
   (* Pause is False on every local outcome below, on purpose: the worker halts
      the whole destination on Pause, and one unsupported edit must not. Status
      0 spends no budget and adds no back-off. *)
   Result.Outcome := doFailed;
   Result.Pause := False;
   if aJob.Deleted and (aJob.RemoteId = '') then
      begin
      (* Never handed over: nothing to delete. *)
      Result.Outcome := doConfirmed;
      Exit;
      end;
   if aJob.Deleted then
      begin
      Result.ErrorCode := 'ACLOG_DELETE_UNSUPPORTED';
      Exit;
      end;
   if aJob.RemoteId <> '' then
      begin
      Result.ErrorCode := 'ACLOG_EDIT_UNSUPPORTED';
      Exit;
      end;
   if (Trim(FHost) = '') or (FPort < 1) or (FPort > 65535) then
      begin
      Result.Pause := True;
      Result.ErrorCode := 'ACLOG_SETUP_REQUIRED';
      Exit;
      end;
   Result := Send(aJob.Payload);
end;
initialization
   logger := TLogLogger.GetLogger('uACLogClient');
end.
