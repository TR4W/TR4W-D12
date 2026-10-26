unit uTestRadioDestructors;
{$I ..\..\src\tr4w.inc}

(*
  PINS THAT A FACTORY RADIO'S DESTRUCTOR RUNS, AND THAT RUNNING IT IS SAFE.

  THE DEFECT.  TFactoryRadioBase declared `Destructor Destroy; overload;
  Virtual;`.  That is a NEW virtual slot, and it HID TObject.Destroy (the
  compiler warned on every build).  Free and FreeAndNil call TObject's slot, so
  for the whole life of the factory NO radio destructor ever ran -- not the
  base's (socket, IOHandler, VFOs, serial port, lock), not TK4Radio's spectrum
  thread stop, not the Icom family's transport teardown, not HamLib's or
  TCI's.  The memory was released; nothing inside it was.

  THE FIX made the base destructor `override` and gave the base a
  BeforeDestruction that stops its reading thread while the object is whole.
  Code that has never run is new code, so these tests run it:

  - Test_FreeThroughBaseReferenceRunsTheDestructor -- the pin.  A probe whose
    destructor sets a flag, freed through a TFactoryRadioBase variable.  On the
    old declaration the probe's `override` overrode the base's private slot,
    Free went to TObject.Destroy, and the flag stays False.
  - Test_EveryRegisteredRadioFreesCleanly -- every registry entry, on every
    link it claims, built and freed.  Nothing may raise.
  - Test_EveryRegisteredRadioFreesAfterDisconnect -- the same after
    Disconnect, which is the production order (ShutDownRadioInterface,
    ExitProgram): every teardown step must be idempotent.
  - Test_ConnectedNetworkRadioWithReaderFrees -- a real TK4Radio connected to a
    loopback server, with its reading thread parked in a ReadLn that has no
    timeout.  Free must return, which needs the socket closed BEFORE the
    reader is joined -- the order the old, never-run body had backwards.  The
    Free runs on a helper thread under a watchdog, so a regression FAILS
    rather than hanging the run.

  NO TRANSPORT EXCEPT LOOPBACK.  Constructing a radio opens nothing (the
  existing uTestFlexRegistry test builds every one the same way); only the
  last test makes a connection, to 127.0.0.1 on an ephemeral port.
*)

interface

uses
   SysUtils, Classes, SyncObjs, IdTCPServer, IdContext, IdGlobal,
   uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4;

type
   (* Sets a flag from its destructor.  Nothing else. *)
   TDestructorFlagProbe = class(TFactoryRadioBase)
   public
      destructor Destroy; override;
   end;

   (* A real TK4Radio, connected through the SHIPPED path with OnConnected left
     in place -- so, unlike uTestRadioSocketNoRead's probe, it starts its
     reading thread. *)
   TConnectedK4Probe = class(TK4Radio)
   public
      procedure ConnectWithReader(const AHost: string; APort: Integer);
   end;

   (* Frees one object on its own thread and says when it is done, so the test
     thread can wait with a timeout instead of for ever. *)
   TBackgroundFree = class(TThread)
   private
      FTarget: TObject;
      FDone: TEvent;
      FError: string;
   protected
      procedure Execute; override;
   public
      constructor Create(ATarget: TObject);
      destructor Destroy; override;
      function WaitDone(AMs: Cardinal): Boolean;
      property Error: string read FError;
   end;

   TRadioDestructorTests = class(TTestCase)
   private
      FServer: TIdTCPServer;
      procedure HandleMessage(sMessage: string);
      procedure ServerExecute(AContext: TIdContext);
      function  StartServer: Word;
      procedure StopServer;
      function  FreeEveryRadio(disconnectFirst: Boolean; out checked: Integer): string;
   protected
      procedure Test_FreeThroughBaseReferenceRunsTheDestructor;
      procedure Test_EveryRegisteredRadioFreesCleanly;
      procedure Test_EveryRegisteredRadioFreesAfterDisconnect;
      procedure Test_ConnectedNetworkRadioWithReaderFrees;
   public
      procedure RunAllTests; override;
   end;

implementation

var
   gProbeDestroyed: Boolean = False;

(* ---- probes ----------------------------------------------------------------- *)

destructor TDestructorFlagProbe.Destroy;
begin
   gProbeDestroyed := True;
   inherited Destroy;
end;

procedure TConnectedK4Probe.ConnectWithReader(const AHost: string; APort: Integer);
begin
   radioAddress := AHost;
   radioPort := APort;
   Connect;
end;

constructor TBackgroundFree.Create(ATarget: TObject);
begin
   FTarget := ATarget;
   FDone := TEvent.Create(nil, True, False, '');
   FError := '';
   FreeOnTerminate := False;
   (* Suspended, then Start: the fields are set before Execute can run. *)
   inherited Create(True);
   Start;
end;

destructor TBackgroundFree.Destroy;
begin
   inherited Destroy;      // joins Execute first
   FreeAndNil(FDone);
end;

procedure TBackgroundFree.Execute;
begin
   try
      FTarget.Free;
   except
      on E: Exception do
         begin
         FError := E.ClassName + ': ' + E.Message;
         end;
   end;
   FTarget := nil;
   FDone.SetEvent;
end;

function TBackgroundFree.WaitDone(AMs: Cardinal): Boolean;
begin
   Result := FDone.WaitFor(AMs) = wrSignaled;
end;

(* ---- fixture ---------------------------------------------------------------- *)

procedure TRadioDestructorTests.HandleMessage(sMessage: string);
begin
   (* Nothing arrives: the probe opens no transport. *)
end;

(* Swallows whatever the radio sends and never answers, so the radio's reading
  thread stays parked in ReadLn -- the state that has to be broken out of. *)
procedure TRadioDestructorTests.ServerExecute(AContext: TIdContext);
begin
   AContext.Connection.IOHandler.ReadLn(';', 100, -1, IndyTextEncoding_8Bit);
end;

function TRadioDestructorTests.StartServer: Word;
begin
   FServer := TIdTCPServer.Create(nil);
   FServer.OnExecute := ServerExecute;

   with FServer.Bindings.Add do
      begin
      IP := '127.0.0.1';
      Port := 0;          // ephemeral: never collides with a real service
      end;

   FServer.Active := True;
   Result := FServer.Bindings[0].Port;
end;

procedure TRadioDestructorTests.StopServer;
begin
   if FServer <> nil then
      begin
      FServer.Active := False;
      FreeAndNil(FServer);
      end;
end;

(* Build every registered radio on every link it claims and free it, catching
  anything that escapes.  Returns the failures, one per entry; checked counts
  what was built, so a loop that silently built nothing cannot pass. *)
function TRadioDestructorTests.FreeEveryRadio(disconnectFirst: Boolean;
                                              out checked: Integer): string;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   link: TRadioLink;
   stage: string;
begin
   Result := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;
   for id in ids do
      begin
      for link := Low(TRadioLink) to High(TRadioLink) do
         begin
         if ((link = rlSerial) and not uRadioRegistry.SupportsSerialId(id)) or
            ((link = rlNetwork) and not uRadioRegistry.SupportsNetworkId(id)) then
            begin
            Continue;
            end;

         stage := 'create';
         try
            r := uRadioRegistry.CreateInstanceForLinkId(id, link);
            if r = nil then
               begin
               Result := Result + id + '(nil) ';
               Continue;
               end;
            Inc(checked);
            if disconnectFirst then
               begin
               stage := 'disconnect';
               r.Disconnect;
               end;
            stage := 'free';
            FreeAndNil(r);
         except
            on E: Exception do
               begin
               Result := Result + Format('%s[%s] %s: %s; ', [id, stage, E.ClassName, E.Message]);
               end;
         end;
         end;
      end;
end;

(* ---- tests ------------------------------------------------------------------ *)

procedure TRadioDestructorTests.Test_FreeThroughBaseReferenceRunsTheDestructor;
var
   handler: TProcessMsgRef;
   r: TFactoryRadioBase;
begin
   BeginTest('Free on a TFactoryRadioBase reference runs the radio''s destructor');
   (* A typed local and no @ -- see uTestRadioSocketProbe.MakeRadio. *)
   handler := HandleMessage;
   gProbeDestroyed := False;

   r := TDestructorFlagProbe.Create(handler);
   CheckTrue(r.BaseConstructorRan, 'precondition: the base constructor ran');
   (* Free, exactly as ShutDownRadioInterface and ExitProgram do it. *)
   r.Free;

   CheckTrue(gProbeDestroyed,
             'Free did not reach the radio''s destructor -- TFactoryRadioBase.Destroy ' +
             'must be `override`; `overload; Virtual;` hides TObject.Destroy and Free ' +
             'then runs no radio destructor at all');
end;

procedure TRadioDestructorTests.Test_EveryRegisteredRadioFreesCleanly;
var
   bad: string;
   checked: Integer;
begin
   BeginTest('every registered radio, on every link, frees without raising');
   bad := FreeEveryRadio(False, checked);
   CheckTrue(checked > 50, Format('expected to build many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose Free raised: ' + bad);
end;

procedure TRadioDestructorTests.Test_EveryRegisteredRadioFreesAfterDisconnect;
var
   bad: string;
   checked: Integer;
begin
   BeginTest('every registered radio frees cleanly after Disconnect (the production order)');
   bad := FreeEveryRadio(True, checked);
   CheckTrue(checked > 50, Format('expected to build many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose Disconnect-then-Free raised: ' + bad);
end;

procedure TRadioDestructorTests.Test_ConnectedNetworkRadioWithReaderFrees;
var
   probe: TConnectedK4Probe;
   freer: TBackgroundFree;
   finished: Boolean;
begin
   BeginTest('a connected network radio with a live reading thread frees, and promptly');

   probe := TConnectedK4Probe.Create;
   freer := nil;
   finished := False;
   try
      probe.ConnectWithReader('127.0.0.1', StartServer);
      CheckTrue(probe.IsConnected, 'precondition: the loopback connect succeeded');

      (* The reading thread is now parked in ReadLn: the server never answers.
        Free must close the socket before joining it.  The reader's own worst
        sleep is 1000 ms, so 5 s is generous; a hang is the failure. *)
      freer := TBackgroundFree.Create(probe);
      probe := nil;   // owned by the freer from here
      finished := freer.WaitDone(5000);

      CheckTrue(finished,
                'Free of a connected network radio did not return in 5 s -- the ' +
                'reading thread was joined while still blocked in ReadLn (the ' +
                'socket must be closed first)');
      if finished then
         begin
         CheckEquals('', freer.Error, 'Free raised');
         end;
   finally
      if finished then
         begin
         FreeAndNil(freer);
         end;
      (* else: the freer and the radio are deliberately LEAKED.  Freeing the
        freer would join a thread that is stuck, and the run would hang
        instead of reporting. *)
      if probe <> nil then
         begin
         FreeAndNil(probe);   // the connect raised before the hand-over
         end;
      StopServer;
   end;
end;

procedure TRadioDestructorTests.RunAllTests;
begin
   Test_FreeThroughBaseReferenceRunsTheDestructor;
   Test_EveryRegisteredRadioFreesCleanly;
   Test_EveryRegisteredRadioFreesAfterDisconnect;
   Test_ConnectedNetworkRadioWithReaderFrees;
end;

end.
