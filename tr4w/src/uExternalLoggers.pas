unit uExternalLoggers;
{$I tr4w.inc}
interface
uses SysUtils, Generics.Collections, VC, uQsoDispatcher, uExternalLoggerService,
   uExternalLoggerConfig, uLogDatabase, uLogRepository;
type
   (* Immutable once started. The UI edits the persisted library; restart applies
      it. Thus queued messages cannot find a replacement object under an old ID. *)
   TExternalLoggers = class(TExternalLoggerService)
   private
      FServices: TObjectList<TExternalLoggerService>;
      FIds: array of string;
      FActive: array of boolean;
      FCommandCount: integer;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Add(const aId: string; aService: TExternalLoggerService;
         aActive: boolean = True);
      procedure PrepareMessage(const aMessage: TQsoMessage;
                               const ce: ContestExchange); override;
      procedure SubmitMessage(const aMessage: TQsoMessage); override;
      function PrepareOp(const aKind: TQsoMessageKind; const ce: ContestExchange;
         out aCommand1, aCommand2: string): TQsoExternalOp; override;
      procedure SubmitOp(const aOp: TQsoExternalOp;
         const aCommand1, aCommand2, aDescription: string); override;
      function LookupCallsign(ce: ContestExchange): integer; override;
      (* Issue 226. Keyed by the DELIVERY id the service was Added under. The
         list changes only in Add (start-up) and LogClosed, both main thread,
         and so does this. *)
      function StateSnapshot(const aDeliveryId: string;
         out aSnapshot: TExternalLoggerSnapshot): boolean; override;
      procedure CaptureSavedQso(aDatabase: TLogDatabase; aRepository: TLogRepository;
         aRowId: Int64; aNew: boolean); override;
      procedure AfterLogCommit(aDatabase: TLogDatabase); override;
      procedure LogClosed; override;
   end;
implementation
uses Log4D;
constructor TExternalLoggers.Create;
begin
   inherited Create;
   FServices := TObjectList<TExternalLoggerService>.Create(True);
end;
destructor TExternalLoggers.Destroy;
begin
   if FServices <> nil then
      begin
      LogClosed;
      end;
   FServices.Free;
   inherited Destroy;
end;
procedure TExternalLoggers.Add(const aId: string; aService: TExternalLoggerService;
   aActive: boolean = True);
begin
   SetLength(FIds, Length(FIds) + 1);
   SetLength(FActive, Length(FIds));
   FIds[High(FIds)] := aId;
   FActive[High(FActive)] := aActive;
   aService.SetActive(aActive);
   if aActive and aService.QueuesCommands then
      begin
      Inc(FCommandCount);
      end;
   FServices.Add(aService);
end;
procedure TExternalLoggers.PrepareMessage(const aMessage: TQsoMessage;
   const ce: ContestExchange);
var
   i, target: integer;
begin
   SetLength(aMessage.ExtDeliveries, FCommandCount);
   if FCommandCount = 0 then
      begin
      Exit;
      end;
   target := 0;
   for i := 0 to FServices.Count - 1 do
      begin
      if not FActive[i] or not FServices[i].QueuesCommands then
         begin
         Continue;
         end;
      aMessage.ExtDeliveries[target].TargetId := FIds[i];
      try
         aMessage.ExtDeliveries[target].Op := FServices[i].PrepareOp(aMessage.Kind, ce,
            aMessage.ExtDeliveries[target].Command1, aMessage.ExtDeliveries[target].Command2);
      except
         on E: Exception do
            begin
            aMessage.ExtDeliveries[target].Op := xoNone;
            TLogLogger.GetLogger('ExternalLoggers').Error(
               'Destination %s could not prepare its contact (%s)', [FIds[i], E.ClassName]);
            end;
      end;
      Inc(target);
      end;
end;
procedure TExternalLoggers.SubmitMessage(const aMessage: TQsoMessage);
var
   i, j: integer;
begin
   for i := 0 to High(aMessage.ExtDeliveries) do
      begin
      if aMessage.ExtDeliveries[i].Op = xoNone then
         begin
         Continue;
         end;
      for j := 0 to FServices.Count - 1 do
         begin
         if FIds[j] = aMessage.ExtDeliveries[i].TargetId then
            begin
            try
               FServices[j].SubmitOp(aMessage.ExtDeliveries[i].Op,
                  aMessage.ExtDeliveries[i].Command1, aMessage.ExtDeliveries[i].Command2,
                  aMessage.Description);
            except
               on E: Exception do
                  begin
                  TLogLogger.GetLogger('ExternalLoggers').Error(
                     'Destination %s could not enqueue (%s)', [FIds[j], E.ClassName]);
                  end;
            end;
            Break;
            end;
         end;
      end;
end;
function TExternalLoggers.PrepareOp(const aKind: TQsoMessageKind;
   const ce: ContestExchange; out aCommand1, aCommand2: string): TQsoExternalOp;
begin
   aCommand1 := '';
   aCommand2 := '';
   Result := xoNone;
end;
procedure TExternalLoggers.SubmitOp(const aOp: TQsoExternalOp;
   const aCommand1, aCommand2, aDescription: string);
begin
   raise EInvalidOp.Create('Use destination-addressed external logger messages');
end;
function TExternalLoggers.LookupCallsign(ce: ContestExchange): integer;
begin
   Result := -1;
end;
function TExternalLoggers.StateSnapshot(const aDeliveryId: string;
   out aSnapshot: TExternalLoggerSnapshot): boolean;
var
   i: integer;
begin
   aSnapshot := Default(TExternalLoggerSnapshot);
   Result := False;
   for i := 0 to FServices.Count - 1 do
      begin
      if FIds[i] = aDeliveryId then
         begin
         aSnapshot.Active := FActive[i];
         FServices[i].FillSnapshot(aSnapshot);
         Result := True;
         Exit;
         end;
      end;
end;

procedure TExternalLoggers.CaptureSavedQso(aDatabase: TLogDatabase;
   aRepository: TLogRepository; aRowId: Int64; aNew: boolean);
var
   service: TExternalLoggerService;
begin
   for service in FServices do
      begin
      service.CaptureSavedQso(aDatabase, aRepository, aRowId, aNew);
      end;
end;
procedure TExternalLoggers.AfterLogCommit(aDatabase: TLogDatabase);
var
   i: integer;
begin
   for i := 0 to FServices.Count - 1 do
      begin
      try
         FServices[i].AfterLogCommit(aDatabase);
      except
         on E: Exception do
            begin
            TLogLogger.GetLogger('ExternalLoggers').Error(
               'Destination %s could not start delivery (%s)', [FIds[i], E.ClassName]);
            end;
      end;
      end;
end;
procedure TExternalLoggers.LogClosed;
var
   service: TExternalLoggerService;
   deadline: QWord;
   i, j: integer;
begin
   for service in FServices do
      begin
      service.RequestStop;
      end;
   deadline := GetTickCount64 + 1000;
   for i := FServices.Count - 1 downto 0 do
      begin
      service := FServices[i];
      while not service.StopFinished and (GetTickCount64 < deadline) do
         begin
         Sleep(10);
         end;
      if service.StopFinished then
         begin
         service.LogClosed;
         end
      else
         begin
         service.DetachOwner;
         if FActive[i] and service.QueuesCommands then
            begin
            Dec(FCommandCount);
            end;
         FServices.Extract(service);
         TLogLogger.GetLogger('ExternalLoggers').Error(
            'Destination %s did not stop within the shared deadline; retained until process exit',
            [FIds[i]]);
         for j := i to High(FIds) - 1 do
            begin
            FIds[j] := FIds[j + 1];
            FActive[j] := FActive[j + 1];
            end;
         SetLength(FIds, Length(FIds) - 1);
         SetLength(FActive, Length(FIds));
         end;
      end;
end;
end.
