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
      procedure Test_SeedMergesStreamsOntoOneEndpoint;
      procedure Test_ValidateRejectsBadPortsAndEmptyAddress;
      procedure Test_ValidateRejectsAnEmptyOrDuplicatedRow;
      procedure Test_JSONRoundTrip;
      procedure Test_LegacySingleStreamJSONStillLoads;
      procedure Test_OneSendReachesEveryDestination;
      procedure Test_OneDestinationCarriesSeveralStreams;
      procedure Test_MasterSwitchSilencesWithoutLosingDestinations;
      procedure Test_TestDestinationIgnoresTheMasterSwitch;
      procedure Test_TestDestinationRefusesWhatCannotBeSent;
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
   BeginTest('a stream nothing subscribes to sends nothing, and subscribing is all it takes');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      // No destination carrying the stream: nothing is listening.
      b.Configure(c);

      ResetRecorder;
      b.Send(usContact, 'payload');
      CheckEquals(0, gSends, 'a stream with no destination must not reach the transport');
      CheckFalse(b.Enabled(usContact), 'and it reports as not enabled');

      c.AddDestination('192.168.1.255', 12060, [usContact]);
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
      c.AddDestination('1.1.1.1', 1111, [usContact]);
      c.AddDestination('1.1.1.1', 2222, [usScore]);
      c.AddDestination('1.1.1.1', 3333, [usRadio]);
      c.AddDestination('1.1.1.1', 4444, [usRotor]);
      c.AddDestination('1.1.1.1', 5555, [usLookup]);
      c.AddDestination('1.1.1.1', 6666, [usAppInfo]);
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
      c.AddDestination('1.1.1.1', 1111, [usContact]);
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
      c.AddDestination('1.1.1.1', 12060, [usContact]);
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
      CheckTrue(c.Enabled,
                'a seeded configuration broadcasts: the master switch is not how the ini said no');
   finally
      ini.Free;
      c.Free;
      TFile.Delete(fn);
   end;
end;

procedure TUDPBroadcasterTests.Test_SeedMergesStreamsOntoOneEndpoint;
var
   c: TUDPBroadcastConfig;
   fn: string;
   ini: TIniFile;
   err: string;
begin
   // The ini had ONE address, so four streams left on the default port are one
   // listener wanting four kinds of data -- not four destinations that happen
   // to be identical.  Four rows would also be four rows the operator has to
   // tidy by hand, and Validate now refuses the same endpoint twice, so an
   // unmerged seed would produce a configuration that cannot be saved.
   BeginTest('seeding merges streams sharing an address and port into one destination');
   fn := TPath.Combine(TPath.GetTempPath, 'tr4w_udp_seed_merge_test.ini');
   TFile.WriteAllText(fn,
      '[COMMANDS]'#13#10 +
      'UDP BROADCAST ADDRESS=10.0.0.255'#13#10 +
      'UDP BROADCAST CONTACT INFO=TRUE'#13#10 +
      'UDP BROADCAST SCORE=TRUE'#13#10 +
      'UDP BROADCAST RADIO INFO=TRUE'#13#10 +
      'UDP BROADCAST ROTOR=TRUE'#13#10);
   c := TUDPBroadcastConfig.Create;
   ini := TIniFile.Create(fn);
   try
      c.SeedFromLegacyIni(ini);

      // Contact, score and radio share the default port; rotor has its own.
      CheckEquals(2, c.DestinationCount,
                  'three streams on one port and one on another is TWO endpoints');
      CheckEquals(1, c.CountFor(usContact), 'contact is carried once');
      CheckEquals(1, c.CountFor(usScore),   'score is carried once');
      CheckEquals(1, c.CountFor(usRotor),   'rotor is carried once');
      CheckEquals(UDP_DEFAULT_ROTORPORT, c.Destination[1].Port,
                  'and rotor keeps its own default port');
      CheckTrue(c.Destination[0].Carries(usContact) and
                c.Destination[0].Carries(usScore)   and
                c.Destination[0].Carries(usRadio),
                'the shared endpoint carries all three');
      CheckTrue(c.Validate(err), 'a seeded configuration is one that can be saved: ' + err);
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
   BeginTest('validation names the row that is wrong');
   c := TUDPBroadcastConfig.Create;
   try
      CheckTrue(c.Validate(err), 'an empty config is valid: ' + err);

      c.AddDestination('10.0.0.1', 0, [usScore]);
      CheckFalse(c.Validate(err), 'port 0 is refused');
      CheckTrue(Pos('10.0.0.1', err) > 0,
                'the message names WHICH destination, not just "a port": ' + err);

      c.Clear;
      c.AddDestination('   ', 12060, [usContact]);
      CheckFalse(c.Validate(err), 'a blank address is refused');
   finally
      c.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_ValidateRejectsAnEmptyOrDuplicatedRow;
var
   c: TUDPBroadcastConfig;
   err: string;
begin
   BeginTest('a row that carries nothing, and the same endpoint twice, are both refused');
   c := TUDPBroadcastConfig.Create;
   try
      // Not the same as "switched off": it is an address and a port that will
      // never be sent anything, while looking configured on the panel.
      c.AddDestination('10.0.0.1', 12060, []);
      CheckFalse(c.Validate(err), 'a destination with no streams is refused');

      // The same endpoint twice sends everything it carries twice, and the
      // remote logger's duplicate QSOs look like a TR4W bug.
      c.Clear;
      c.AddDestination('10.0.0.1', 12060, [usContact]);
      c.AddDestination('10.0.0.1', 12060, [usScore]);
      CheckFalse(c.Validate(err), 'the same address and port twice is refused');
      CheckTrue(Pos('12060', err) > 0, 'and the message names it: ' + err);

      // A different PORT at the same address is a different endpoint, which is
      // exactly the N1MM case (RadioInfo 12060, ContactInfo 12061).
      c.Clear;
      c.AddDestination('10.0.0.1', 12060, [usRadio]);
      c.AddDestination('10.0.0.1', 12061, [usContact]);
      CheckTrue(c.Validate(err), 'one address on two ports is legitimate: ' + err);
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
      a.Enabled := False;
      a.AddDestination('10.0.0.255', 1002, [usContact, usScore]);
      // THE CASE THE OLD SHAPE COULD NOT HOLD: one stream, three listeners.
      a.AddDestination('10.0.0.5',   1102, [usContact]);
      a.AddDestination('192.168.1.9', 5555, [usContact, usRadio, usRotor]);

      o := a.ToJSON;
      try
         b.FromJSON(o);
      finally
         o.Free;
      end;

      CheckTrue(a.SameAs(b), 'the round trip is lossless');
      CheckEquals(3, b.CountFor(usContact), 'all three contact listeners survive');
      CheckFalse(b.Enabled, 'the master switch survives too');

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

procedure TUDPBroadcasterTests.Test_LegacySingleStreamJSONStillLoads;
var
   c: TUDPBroadcastConfig;
   o: TJSONObject;
   err: string;
begin
   // The first cut of this format stored ONE stream per row.  A settings file
   // written by it must not lose its destinations -- that reads to an operator
   // as "TR4W forgot my UDP settings", not as a format change.  And because the
   // same endpoint now appears once per stream, loading has to merge or the
   // result is a configuration that will not pass Validate.
   BeginTest('a settings file in the first destinations format still loads, merged');
   c := TUDPBroadcastConfig.Create;
   o := TJSONObject(TJSONObject.ParseJSONValue(
      '{"allQSOs":true,"destinations":[' +
      '{"stream":"contact","address":"10.0.0.7","port":12060},' +
      '{"stream":"score","address":"10.0.0.7","port":12060},' +
      '{"stream":"rotor","address":"10.0.0.7","port":12040}]}'));
   try
      c.FromJSON(o);

      CheckEquals(2, c.DestinationCount, 'three legacy rows on two endpoints');
      CheckTrue(c.Destination[0].Carries(usContact) and c.Destination[0].Carries(usScore),
                'the two streams sharing a port merged onto one destination');
      CheckEquals(1, c.CountFor(usRotor), 'and the one on its own port stayed separate');
      CheckTrue(c.AllQSOs, 'the other members still read');
      CheckTrue(c.Enabled, 'a file with no master switch broadcasts, as it always did');
      CheckTrue(c.Validate(err), 'and what was loaded can be saved again: ' + err);
   finally
      o.Free;
      c.Free;
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
      c.AddDestination('10.0.0.1', 1001, [usContact]);
      c.AddDestination('10.0.0.2', 1002, [usContact]);
      c.AddDestination('10.0.0.3', 1003, [usContact]);
      c.AddDestination('10.0.0.9', 9999, [usScore]);
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

procedure TUDPBroadcasterTests.Test_OneDestinationCarriesSeveralStreams;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
begin
   // The row an operator thinks in is an ENDPOINT that wants several kinds of
   // data. One send per stream still goes to it, and a stream it did NOT ask
   // for must not.
   BeginTest('one destination carries several streams, and only those');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.AddDestination('10.0.0.5', 12060, [usContact, usScore]);
      b.Configure(c);

      ResetRecorder; b.Send(usContact, 'x');
      CheckEquals(1, gSends, 'contact is carried');
      ResetRecorder; b.Send(usScore, 'x');
      CheckEquals(1, gSends, 'score is carried');
      ResetRecorder; b.Send(usRadio, 'x');
      CheckEquals(0, gSends, 'radio was not asked for and must not be sent');
      CheckFalse(b.Enabled(usRadio), 'and it reports as not enabled');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_MasterSwitchSilencesWithoutLosingDestinations;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
   snap: TUDPBroadcastConfig;
begin
   // WHY THE MASTER SWITCH IS NOT THE PER-STREAM FLAG COMING BACK: it answers
   // "not right now" without the operator deleting the endpoints they typed.
   // The failure it prevents is an operator emptying the list to go quiet and
   // having nothing to put back afterwards.
   BeginTest('the master switch silences every stream and keeps the destinations');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.AddDestination('10.0.0.1', 1001, [usContact, usScore]);
      c.Enabled := False;
      b.Configure(c);

      ResetRecorder;
      b.Send(usContact, 'x');
      b.Send(usScore, 'x');
      CheckEquals(0, gSends, 'nothing goes out while the master switch is off');
      CheckFalse(b.Enabled(usContact), 'and every stream reports as not enabled');
      CheckFalse(b.MasterEnabled, 'which the UI can distinguish from "no destination"');

      snap := b.Snapshot;
      try
         CheckEquals(1, snap.DestinationCount, 'the destination is still configured');
      finally
         snap.Free;
      end;

      // Switching it back on is all it takes -- nothing had to be retyped.
      c.Enabled := True;
      b.Configure(c);
      ResetRecorder;
      b.Send(usContact, 'x');
      CheckEquals(1, gSends, 'and it broadcasts again');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_TestDestinationIgnoresTheMasterSwitch;
var
   b: TUDPBroadcaster;
   c: TUDPBroadcastConfig;
   err: string;
begin
   // "Does this address and port work" is a different question from "am I
   // broadcasting right now".  Requiring broadcasting to be on before the Test
   // button does anything is the coupling that gets it reported as broken.
   BeginTest('Test sends to an address that is not configured, master switch or not');
   b := TUDPBroadcaster.Create;
   c := TUDPBroadcastConfig.Create;
   try
      b.SetTransport(RecordSend);
      c.Enabled := False;               // broadcasting off...
      b.Configure(c);                   // ...and no destinations at all

      ResetRecorder;
      CheckTrue(b.TestDestination('10.0.0.42', 12070, err), 'the test packet was sent: ' + err);
      CheckEquals(1, gSends, 'exactly one packet');
      CheckEquals('10.0.0.42', gLastAddress, 'to the address under test');
      CheckEquals(12070, gLastPort, 'on the port under test');
      CheckTrue(Pos(AnsiString('TR4WTest'), gLastPayload) > 0,
                'under a root of its own, so a test can never land in a log');
   finally
      c.Free;
      b.Free;
   end;
end;

procedure TUDPBroadcasterTests.Test_TestDestinationRefusesWhatCannotBeSent;
var
   b: TUDPBroadcaster;
   err: string;
begin
   // Reachable from a dialog with half-typed fields in it.
   BeginTest('Test reports a blank address, a bad port, and no socket');
   b := TUDPBroadcaster.Create;
   try
      CheckFalse(b.TestDestination('  ', 12060, err), 'a blank address is refused');
      CheckTrue(err <> '', 'with a message');

      CheckFalse(b.TestDestination('10.0.0.1', 0, err), 'port 0 is refused');
      CheckTrue(Pos('65535', err) > 0, 'saying what is legal: ' + err);

      // No transport: unlike Send, this REPORTS it. A silent no-op is right for
      // a broadcast during startup and wrong for a button just pressed.
      CheckFalse(b.TestDestination('10.0.0.1', 12060, err), 'no socket is reported');
      CheckTrue(err <> '', 'rather than quietly claiming success');
   finally
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
   Test_SeedMergesStreamsOntoOneEndpoint;
   Test_ValidateRejectsBadPortsAndEmptyAddress;
   Test_ValidateRejectsAnEmptyOrDuplicatedRow;
   Test_JSONRoundTrip;
   Test_LegacySingleStreamJSONStillLoads;
   Test_OneSendReachesEveryDestination;
   Test_OneDestinationCarriesSeveralStreams;
   Test_MasterSwitchSilencesWithoutLosingDestinations;
   Test_TestDestinationIgnoresTheMasterSwitch;
   Test_TestDestinationRefusesWhatCannotBeSent;
end;

end.
