unit uExternalLoggers;
{$I tr4w.inc}
interface
uses SysUtils, Generics.Collections, VC, uQsoDispatcher, uExternalLoggerService,
   uExternalLoggerConfig, uLogDatabase, uLogRepository;
type
   (* THE SET OF SERVICES IS FIXED once started; THEIR SWITCHES ARE NOT (issue
      233). Every saved definition gets a service at start-up (an inactive one
      owns no worker), and Save then applies two things live, on the main
      thread: each service's Enabled flag and the delivery order
      (ApplyConfiguration). Nothing is added, removed or rebuilt, so a queued
      message can never find a replacement object under its destination id, and
      the QSO dispatcher thread -- which reads FServices and FIds, and nothing
      else here -- sees a list that never changes. A definition added since
      start, or whose connection settings (anything its provider reads,
      secrets included) changed, keeps what it was started with until restart.

      MAIN-THREAD ONLY: FActive, FStale, FOrder, FCommandCount and every
      method but SubmitMessage. SubmitMessage runs on the dispatcher thread
      and works from the message's own targets. *)
   TExternalLoggers = class(TExternalLoggerService)
   private
      FServices: TObjectList<TExternalLoggerService>;
      FIds: array of string;
      FActive: array of boolean;
      (* The SettingsStamp each service was started with, and whether the
         last applied configuration differs from it. *)
      FStamps: array of string;
      FStale: array of boolean;
      (* Delivery order, as delivery ids; PrepareMessage walks this. Keyed by
         id, not by index, because LogClosed can extract a stuck service. *)
      FOrder: array of string;
      FCommandCount: integer;
      function IndexOfId(const aId: string): integer;
      procedure RemoveEntry(aIndex: integer);
      procedure RecountCommands;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Add(const aId: string; aService: TExternalLoggerService;
         aActive: boolean = True; const aStamp: string = '');
      function ApplyConfiguration(const aConfig: TExternalLoggerConfig): integer; override;
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
function TExternalLoggers.IndexOfId(const aId: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(FIds) do
      begin
      if FIds[i] = aId then
         begin
         Result := i;
         Exit;
         end;
      end;
end;
procedure TExternalLoggers.RecountCommands;
var
   i: integer;
begin
   FCommandCount := 0;
   for i := 0 to FServices.Count - 1 do
      begin
      if FActive[i] and FServices[i].QueuesCommands then
         begin
         Inc(FCommandCount);
         end;
      end;
end;
procedure TExternalLoggers.Add(const aId: string; aService: TExternalLoggerService;
   aActive: boolean = True; const aStamp: string = '');
begin
   SetLength(FIds, Length(FIds) + 1);
   SetLength(FActive, Length(FIds));
   SetLength(FStamps, Length(FIds));
   SetLength(FStale, Length(FIds));
   SetLength(FOrder, Length(FIds));
   FIds[High(FIds)] := aId;
   FActive[High(FActive)] := aActive;
   FStamps[High(FStamps)] := aStamp;
   FStale[High(FStale)] := False;
   FOrder[High(FOrder)] := aId;
   aService.SetActive(aActive);
   if aActive and aService.QueuesCommands then
      begin
      Inc(FCommandCount);
      end;
   FServices.Add(aService);
end;
(* Removes the bookkeeping of entry aIndex (not the service: the caller has
   already extracted or freed it). *)
procedure TExternalLoggers.RemoveEntry(aIndex: integer);
var
   j, k: integer;
   id: string;
begin
   id := FIds[aIndex];
   for j := aIndex to High(FIds) - 1 do
      begin
      FIds[j] := FIds[j + 1];
      FActive[j] := FActive[j + 1];
      FStamps[j] := FStamps[j + 1];
      FStale[j] := FStale[j + 1];
      end;
   SetLength(FIds, Length(FIds) - 1);
   SetLength(FActive, Length(FIds));
   SetLength(FStamps, Length(FIds));
   SetLength(FStale, Length(FIds));
   for k := 0 to High(FOrder) do
      begin
      if FOrder[k] = id then
         begin
         for j := k to High(FOrder) - 1 do
            begin
            FOrder[j] := FOrder[j + 1];
            end;
         SetLength(FOrder, Length(FOrder) - 1);
         Break;
         end;
      end;
end;
(* THE ONE RULE (issue 233), applied to every running service in turn:

   - the saved definition for it is found by its delivery id; failing that, by
     the definition's own id (the destination changed, so it is the same
     definition under a new delivery id); failing that it was REMOVED;
   - REMOVED switches it off; a definition whose settings differ from what the
     service was started with is STALE;
   - the wanted flag is the saved one, EXCEPT that a stale service is never
     switched ON (it would send to the old settings the operator just edited):
     off always applies, on waits for the restart;
   - the delivery order is the saved active list, then whatever else is still
     on, in its previous relative order.

   Returns how many definitions still need a restart: stale ones that are
   switched on, plus switched-on definitions that no running service matches.
   A service only has its flag flipped, so queued work is neither dropped nor
   redirected; a durable one drains or keeps it as the lifecycle already says. *)
function TExternalLoggers.ApplyConfiguration(const aConfig: TExternalLoggerConfig): integer;
var
   i, k, index: integer;
   definition, candidate: TExternalLoggerDefinition;
   exact, want: boolean;
   id: AnsiString;
   newOrder: array of string;
   function InOrder(const aEntryId: string): boolean;
   var
      n: integer;
   begin
      Result := False;
      for n := 0 to High(newOrder) do
         begin
         if newOrder[n] = aEntryId then
            begin
            Result := True;
            Exit;
            end;
         end;
   end;
   function EntryFor(const aDefinition: TExternalLoggerDefinition): integer;
   var
      n: integer;
   begin
      Result := -1;
      for n := 0 to High(FIds) do
         begin
         if (FIds[n] = aDefinition.DeliveryId) or
            (Pos('/' + aDefinition.Id + '/', FIds[n]) > 0) then
            begin
            Result := n;
            Exit;
            end;
         end;
   end;
begin
   Result := 0;
   for i := 0 to FServices.Count - 1 do
      begin
      definition := nil;
      exact := False;
      for k := 0 to aConfig.Definitions.Count - 1 do
         begin
         candidate := aConfig.Definitions[k];
         if candidate.DeliveryId = FIds[i] then
            begin
            definition := candidate;
            exact := True;
            Break;
            end;
         if (definition = nil) and (Pos('/' + candidate.Id + '/', FIds[i]) > 0) then
            begin
            definition := candidate;
            end;
         end;
      if definition = nil then
         begin
         FStale[i] := False;
         want := False;
         end
      else
         begin
         FStale[i] := (not exact) or (definition.SettingsStamp <> FStamps[i]);
         want := aConfig.ActivePosition(definition.Id) > 0;
         if FStale[i] then
            begin
            if want then
               begin
               Inc(Result);
               end;
            want := want and FActive[i];
            end;
         end;
      if want <> FActive[i] then
         begin
         FActive[i] := want;
         FServices[i].SetActive(want);
         TLogLogger.GetLogger('ExternalLoggers').Info(
            'Destination %s switched %s without a restart',
            [FIds[i], BoolToStr(want, 'on', 'off')]);
         end;
      end;
   (* Definitions switched on that no running service knows: start-up built
      none for them. *)
   for id in aConfig.ActiveIds do
      begin
      definition := aConfig.Find(string(id));
      if (definition <> nil) and (EntryFor(definition) < 0) then
         begin
         Inc(Result);
         end;
      end;
   RecountCommands;
   newOrder := nil;
   for id in aConfig.ActiveIds do
      begin
      definition := aConfig.Find(string(id));
      if definition = nil then
         begin
         Continue;
         end;
      index := EntryFor(definition);
      if (index >= 0) and not InOrder(FIds[index]) then
         begin
         SetLength(newOrder, Length(newOrder) + 1);
         newOrder[High(newOrder)] := FIds[index];
         end;
      end;
   for k := 0 to High(FOrder) do
      begin
      if not InOrder(FOrder[k]) then
         begin
         SetLength(newOrder, Length(newOrder) + 1);
         newOrder[High(newOrder)] := FOrder[k];
         end;
      end;
   FOrder := newOrder;
end;
procedure TExternalLoggers.PrepareMessage(const aMessage: TQsoMessage;
   const ce: ContestExchange);
var
   k, i, target: integer;
begin
   SetLength(aMessage.ExtDeliveries, FCommandCount);
   if FCommandCount = 0 then
      begin
      Exit;
      end;
   target := 0;
   for k := 0 to High(FOrder) do
      begin
      i := IndexOfId(FOrder[k]);
      if (i < 0) or not FActive[i] or not FServices[i].QueuesCommands then
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
         aSnapshot.Stale := FStale[i];
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
   i: integer;
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
         RemoveEntry(i);
         end;
      end;
end;
end.
