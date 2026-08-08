unit uTestUDPBroadcaster;

{
  The UDP broadcaster's RULES: is this stream on, where does it go, on which
  port.  Testable at all only because the transport is injected -- these run
  against a recording stub with no socket, which is the whole reason
  uUDPBroadcaster does not know Indy.

  The defect being pinned is not hypothetical.  Before the broadcaster existed
  the enable test lived at the CALL SITE, restated at seven of them, and they
  had already diverged: SendDeletedContactToUDP checked the flag,
  LogContactToUDP did not (NY4I 2026-08-08).
}

interface

uses
   System.SysUtils,
   uTR4WTestFramework,
   uUDPBroadcastConfig,
   uUDPBroadcaster;

type
   TUDPBroadcasterTests = class(TTestCase)
   private
      procedure Test_DisabledStreamSendsNothing;
      procedure Test_EachStreamUsesItsOwnPort;
      procedure Test_ConfigureIsACopyNotAReference;
      procedure Test_NoTransportIsNotAnError;
      procedure Test_SeedFromIniKeepsDefaultsForAbsentKeys;
      procedure Test_ValidateRejectsBadPortsAndEmptyAddress;
      procedure Test_JSONRoundTrip;
      procedure Test_OneSendReachesEveryDestination;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   System.IniFiles,
   System.IOUtils,
   System.JSON;

// The recording stub. A unit-level variable because TUDPSendProc is a plain
// procedure type -- see the note on its declaration.
var
   gSends: integer;
   gLastAddress: string;
   gLastPort: integer;
   gLastPayload: AnsiString;

procedure RecordSend(const aAddress: string; const aPort: integer;
                     const aPayload: AnsiString);
begin
   Inc(gSends);
   gLastAddress := aAddress;
   gLastPort    := aPort;
   gLastPayload := aPayload;
end;

procedure ResetRecorder;
begin
   gSends       := 0;
   gLastAddress := '';
   gLastPort    := 0;
   gLastPayload := '';
end;

procedure TUDPBroadcasterTests.Test_DisabledStreamSendsNothing;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   BeginTest('a disabled stream sends nothing, and enabling it is all it takes');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      // No destination for the stream: nothing is listening.
      b.Configure(c);

      ResetRecorder;
      b.Send(usContact, 'payload');
      CheckEquals(0, gSends, 'a stream with no destination must not reach the transport');
      CheckFalse(b.Enabled(usContact), 'and it reports as not enabled');

      c.AddDestination(usContact, '192.168.1.255', 12060);
      b.Configure(c);
      ResetRecorder;
      b.Send(usContact, 'payload');
      CheckEquals(1, gSends, 'a subscribed stream sends');
      CheckEquals('192.168.1.255', gLastAddress, 'to the configured address');
      CheckTrue(b.Enabled(usContact), 'enabled is emergent from having a destination');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_EachStreamUsesItsOwnPort;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   // The mapping used to live at the call sites, as the name of a global. A
   // stream routed to the wrong port is invisible at compile time and shows up
   // as "my logger sees contacts but not score".
   BeginTest('each stream goes to its own port');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.AddDestination(usContact, '1.1.1.1', 1111);
      c.AddDestination(usScore,   '1.1.1.1', 2222);
      c.AddDestination(usRadio,   '1.1.1.1', 3333);
      c.AddDestination(usRotor,   '1.1.1.1', 4444);
      c.AddDestination(usLookup,  '1.1.1.1', 5555);
      c.AddDestination(usAppInfo, '1.1.1.1', 6666);
      b.Configure(c);

      ResetRecorder; b.Send(usContact, 'x'); CheckEquals(1111, gLastPort, 'contact');
      ResetRecorder; b.Send(usScore,   'x'); CheckEquals(2222, gLastPort, 'score');
      ResetRecorder; b.Send(usRadio,   'x'); CheckEquals(3333, gLastPort, 'radio');
      ResetRecorder; b.Send(usRotor,   'x'); CheckEquals(4444, gLastPort, 'rotor');
      ResetRecorder; b.Send(usLookup,  'x'); CheckEquals(5555, gLastPort, 'lookup');
      ResetRecorder; b.Send(usAppInfo, 'x'); CheckEquals(6666, gLastPort, 'app info');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_ConfigureIsACopyNotAReference;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   // If Configure kept the caller's object, an edit in the Preferences dialog
   // would take effect mid-contest without anyone applying it -- and worse,
   // freeing that object would leave the broadcaster reading freed memory.
   BeginTest('Configure takes a copy, so the caller cannot mutate live settings');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.AddDestination(usContact, '1.1.1.1', 1111);
      b.Configure(c);

      // Mutate the caller's object AFTER configuring.
      c.Destination[0].Port := 9999;
      c.Clear;

      ResetRecorder;
      b.Send(usContact, 'x');
      CheckEquals(1, gSends, 'the broadcaster keeps the settings it was given');
      CheckEquals(1111, gLastPort, 'not the ones edited afterwards');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_NoTransportIsNotAnError;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   // The broadcaster is created before the socket exists, so a send during
   // startup must be a no-op rather than an AV.
   BeginTest('sending with no transport assigned does nothing, quietly');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      c.AddDestination(usContact, '1.1.1.1', 12060);
      b.Configure(c);
      b.Send(usContact, 'x');       // must not raise
      Check(True, 'no exception with no transport');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_SeedFromIniKeepsDefaultsForAbsentKeys;
var
   c: TUDPBroadcastConfig;
   fn: string;
   ini: TIniFile;
begin
   // THE MIGRATION TRAP.  Most stations never wrote the port keys -- NY4I's own
   // ini holds six of the fourteen -- so seeding with a 0 or '' default would
   // turn "never configured" into "configured to nothing" and silently move
   // every broadcast off its port.
   BeginTest('seeding keeps the default for a key the ini never had');
   fn := TPath.Combine(TPath.GetTempPath, 'tr4w_udp_seed_test.ini');
   TFile.WriteAllText(fn,
      '[COMMANDS]'#13#10 +
      'UDP BROADCAST ADDRESS=192.168.73.255'#13#10 +
      'UDP BROADCAST CONTACT INFO=TRUE'#13#10);
   c := TUDPBroadcastConfig.Create;
   ini := TIniFile.Create(fn);
   try
      c.SeedFromLegacyIni(ini);

      CheckEquals(1, c.DestinationCount,
                  'one enabled stream in the ini becomes exactly one destination');
      CheckEquals(1, c.CountFor(usContact), 'and it is the contact stream');
      CheckEquals('192.168.73.255', c.Destination[0].Address,
                  'sharing the single address the ini had room for');
      CheckEquals(UDP_DEFAULT_PORT, c.Destination[0].Port,
                  'an ABSENT port keeps the compiled-in default, not 0');
      CheckEquals(0, c.CountFor(usScore),
                  'a stream that was OFF produces no destination at all');
   finally
      ini.Free;
      c.Free;
      TFile.Delete(fn);
   end;
end;

procedure TUDPBroadcasterTests.Test_ValidateRejectsBadPortsAndEmptyAddress;
var
   c: TUDPBroadcastConfig;
   err: string;
begin
   BeginTest('validation names the field that is wrong');
   c := TUDPBroadcastConfig.Create;
   try
      CheckTrue(c.Validate(err), 'an empty config is valid: ' + err);

      c.AddDestination(usScore, '10.0.0.1', 0);
      CheckFalse(c.Validate(err), 'port 0 is refused');
      CheckTrue(Pos('score', LowerCase(err)) > 0,
                'the message names WHICH destination, not just "a port": ' + err);

      c.Clear;
      c.AddDestination(usContact, '   ', 12060);
      CheckFalse(c.Validate(err), 'a blank address is refused');
   finally
      c.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_JSONRoundTrip;
var
   a, b: TUDPBroadcastConfig;
   o: TJSONObject;
begin
   BeginTest('every field survives a JSON round trip');
   a := TUDPBroadcastConfig.Create;
   b := TUDPBroadcastConfig.Create;
   try
      a.AllQSOs := True;
      a.AddDestination(usContact, '10.0.0.255', 1002);
      // THE CASE THE OLD SHAPE COULD NOT HOLD: one stream, three listeners.
      a.AddDestination(usContact, '10.0.0.5',   1102);
      a.AddDestination(usContact, '192.168.1.9', 5555);
      a.AddDestination(usScore,   '10.0.0.255', 1004);

      o := a.ToJSON;
      try
         b.FromJSON(o);
      finally
         o.Free;
      end;

      CheckTrue(a.SameAs(b), 'the round trip is lossless');
      CheckEquals(3, b.CountFor(usContact), 'all three contact listeners survive');

      // An EMPTY object must not zero anything: a file written by an older TR4W
      // is missing whatever was added since.
      o := TJSONObject.Create;
      try
         b.FromJSON(o);
      finally
         o.Free;
      end;
      CheckTrue(a.SameAs(b), 'absent members leave the current values alone');
   finally
      b.Free;
      a.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_OneSendReachesEveryDestination;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   // THE POINT OF THE LIST.  Three listeners for contacts must not mean three
   // calls at the call site: "a contact was logged" is ONE event, and how many
   // places want to hear it is configuration.  Making it three calls would put
   // the destination count back into the 40 call sites, which is the same
   // defect as the enable flag being restated at seven of them (NY4I).
   BeginTest('one Send reaches every destination for that stream');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.AddDestination(usContact, '10.0.0.1', 1001);
      c.AddDestination(usContact, '10.0.0.2', 1002);
      c.AddDestination(usContact, '10.0.0.3', 1003);
      c.AddDestination(usScore,   '10.0.0.9', 9999);
      b.Configure(c);

      ResetRecorder;
      b.Send(usContact, 'x');
      CheckEquals(3, gSends, 'one call, three destinations');

      // And the score listener is NOT among them.
      ResetRecorder;
      b.Send(usScore, 'x');
      CheckEquals(1, gSends, 'a different stream reaches only its own');
      CheckEquals(9999, gLastPort, 'on its own port');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.RunAllTests;
begin
   Test_DisabledStreamSendsNothing;
   Test_EachStreamUsesItsOwnPort;
   Test_ConfigureIsACopyNotAReference;
   Test_NoTransportIsNotAnError;
   Test_SeedFromIniKeepsDefaultsForAbsentKeys;
   Test_ValidateRejectsBadPortsAndEmptyAddress;
   Test_JSONRoundTrip;
   Test_OneSendReachesEveryDestination;
end;

end.
