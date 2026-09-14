unit uTestPortAddress;
{$I ..\..\src\tr4w.inc}
(*
  The one place that turns a configured port into a device name.

  IT WAS FIVE PLACES until 2026-09-10, and the reason to pin it now is that
  the five had already drifted in the only way that mattered: three of them
  reached the formatter with a guard of `<> NoPort`, which a port configured
  as NETWORK satisfies.  The name that came out was 'COM65'.

  These are exhaustive over the enum rather than sampled.  A silently-defaulted
  or off-by-one arm in a formatter reads as a legal port name, and there is no
  compiler diagnostic and no bench symptom short of opening the wrong hardware.
*)

interface

uses
   SysUtils, uTR4WTestFramework, VC, uPortAddress, ComPortEnumerator;

type
   TPortAddressTests = class(TTestCase)
   protected
      procedure Test_EverySerialPortNamesItself;
      procedure Test_NothingButASerialPortGetsAName;
      procedure Test_TheNameParsesBackToTheSamePort;
      procedure Test_AConfiguredNameWinsOverTheOrdinal;
      procedure Test_EveryPortHasExactlyOneKind;
      procedure Test_ANamedPortIsSerialWhateverTheOrdinalSays;
      procedure Test_AStoredPortReadsWhicheverWayItWasWritten;
      procedure Test_TheLegacyTokenIsOnlyForTheBridge;
      procedure Test_ADeviceNameGivesBackItsOwnOrdinal;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TPortAddressTests.Test_EverySerialPortNamesItself;
var
   p: PortType;
begin
   (* Serial1 is ordinal 1 BY CONSTRUCTION of the enum, and the formatter is
     one line because of it.  Pin every member: the ceiling has already moved
     once, from 20 to 64, and an arithmetic slip at either end of the range is
     invisible until a radio opens the wrong port. *)
   BeginTest('every serial port yields its own COM name');
   for p := Low(TSerialPortRange) to High(TSerialPortRange) do
      begin
      CheckEquals('COM' + IntToStr(Ord(p)), SerialDeviceName(p),
                  Format('port ordinal %d', [Ord(p)]));
      end;
   CheckEquals('COM1',  SerialDeviceName(Serial1),  'the first');
   CheckEquals('COM64', SerialDeviceName(Serial64), 'the last');
end;

procedure TPortAddressTests.Test_NothingButASerialPortGetsAName;
begin
   (* THIS IS THE DEFECT THE MOVE FIXED.  Network is ordinal 65, one past
     Serial64, so a bare Format('COM%d', [Ord(port)]) turned it into 'COM65'
     and three call sites let it through.  An empty name is what makes a
     caller refuse instead. *)
   BeginTest('a port that is not serial has no device name');
   CheckEquals('', SerialDeviceName(NoPort),    'nothing configured');
   CheckEquals('', SerialDeviceName(VC.Network),   'a network port is not a COM port');
   (* THE THREE LPT CASES WENT with Parallel1..Parallel3 on 2026-09-13.
     Network is still the one that matters here: it is the LAST member, so an
     ordinal-based name formatter runs straight past the serial range into it,
     which is exactly the 'COM65' defect this test was written for. *)
end;

procedure TPortAddressTests.Test_TheNameParsesBackToTheSamePort;
var
   p: PortType;
begin
   (* The two halves of the round trip live in different units -- this one
     writes the name, ComPortEnumerator reads it -- and they are the two ends
     of the chain the settings file sits in the middle of.  Testing them
     separately is exactly how a pair like this drifts. *)
   BeginTest('the name a port is given parses back to that port');
   for p := Low(TSerialPortRange) to High(TSerialPortRange) do
      begin
      CheckEquals(Ord(p), ComPortNumber(SerialDeviceName(p)),
                  Format('round trip for ordinal %d', [Ord(p)]));
      end;

   (* And the empty name must NOT parse to a port, or refusing to name a
     network port would quietly become port zero somewhere downstream. *)
   CheckEquals(0, ComPortNumber(SerialDeviceName(VC.Network)),
               'an unnamed port is not port zero');
end;

procedure TPortAddressTests.Test_AConfiguredNameWinsOverTheOrdinal;
begin
   (* THE WIDEN STEP, AND ITS WHOLE SAFETY PROPERTY IS THE FALLBACK.

     Every configured name is empty today, so EffectiveDeviceName must return
     exactly what SerialDeviceName returned, or step 1 has changed behaviour on
     every Windows station while claiming not to. *)
   BeginTest('an empty name falls through to the ordinal, unchanged');
   CheckEquals(SerialDeviceName(Serial7), EffectiveDeviceName('', Serial7),
               'empty gives the ordinal answer');
   CheckEquals('COM7', EffectiveDeviceName('', Serial7), 'and that is COM7');
   CheckEquals('', EffectiveDeviceName('', VC.Network),
               'a network port still has no device name');
   CheckEquals('', EffectiveDeviceName('', NoPort), 'nor does no port');

   (* AND A NAME THE ORDINAL COULD NEVER PRODUCE IS THE POINT.  No arithmetic
     on an ordinal yields a device node, so this is the only way one can ever
     reach TSerialPort. *)
   BeginTest('a configured name wins, including one no ordinal could produce');
   CheckEquals('/dev/ttyUSB0', EffectiveDeviceName('/dev/ttyUSB0', NoPort),
               'a device node, with no ordinal at all');
   CheckEquals('/dev/ttyUSB0', EffectiveDeviceName('/dev/ttyUSB0', Serial7),
               'the name beats a disagreeing ordinal');
   CheckEquals('COM23', EffectiveDeviceName('COM23', Serial7),
               'a COM number above what this enum could hold');

   // A name arrives from a file an operator can edit.
   CheckEquals('COM7', EffectiveDeviceName('  COM7  ', NoPort), 'trimmed');
   CheckEquals('COM7', EffectiveDeviceName('   ', Serial7),
               'blanks are not a name, so the ordinal still answers');
end;

procedure TPortAddressTests.Test_EveryPortHasExactlyOneKind;
var
   p: PortType;
   kind: TPortKind;
   serial, network, parallel, none: integer;
begin
   (* EXHAUSTIVE OVER THE ENUM, because a mis-mapped arm reads as a legal kind
     and no compiler will say so.  This replaces `in SerialPorts`, `= Network`
     and the LPT range test at eighteen sites on the radio path, and getting
     one wrong sends a radio down the wrong transport. *)
   BeginTest('every member of PortType classifies, and the counts are exact');
   serial := 0; network := 0; parallel := 0; none := 0;
   for p := Low(PortType) to High(PortType) do
      begin
      kind := PortKindOf('', p);
      case kind of
         pkSerial:   Inc(serial);
         pkNetwork:  Inc(network);
         (* pkParallel IS STILL A KIND and nothing answers it now -- counted
           so that stays true.  A port coming back parallel would mean the
           enum had grown a member this test does not know about. *)
         pkParallel: Inc(parallel);
         pkNone:     Inc(none);
      end;
      end;

   CheckEquals(MAX_SERIAL_PORT, serial, 'one serial kind per serial member');
   CheckEquals(1, network,  'exactly one network member');
   CheckEquals(0, parallel, 'the parallel port is gone from the program');
   CheckEquals(1, none,     'only NoPort is nothing');
   CheckEquals(Ord(High(PortType)) + 1, serial + network + parallel + none,
               'every member accounted for, none counted twice');

   // And the individual answers, so a count that is right by accident fails.
   CheckTrue(PortKindOf('', NoPort)    = pkNone,     'NoPort');
   CheckTrue(PortKindOf('', Serial1)   = pkSerial,   'the first serial');
   CheckTrue(PortKindOf('', Serial64)  = pkSerial,   'the last serial');
   CheckTrue(PortKindOf('', VC.Network)   = pkNetwork,  'Network');
end;

procedure TPortAddressTests.Test_ANamedPortIsSerialWhateverTheOrdinalSays;
begin
   (* THE REASON THIS TYPE EXISTS.  A device node has no ordinal, so a Linux
     radio's enum is NoPort while its port is perfectly real.  Asking the
     ordinal would call it unconfigured, the serial arm would never run, and
     the name would never be read -- a radio that is set up and invisible. *)
   BeginTest('a configured name is serial even with no ordinal at all');
   CheckTrue(PortKindOf('/dev/ttyUSB0', NoPort) = pkSerial,
             'a device node with the enum at NoPort');
   CheckTrue(PortKindOf('/dev/cu.usbserial-A50285BI', NoPort) = pkSerial,
             'a macOS device node');
   CheckTrue(PortKindOf('COM23', NoPort) = pkSerial,
             'a COM number above what the enum can hold');

   // Blanks are not a name, so the ordinal still decides.
   CheckTrue(PortKindOf('   ', VC.Network) = pkNetwork, 'blanks do not make it serial');
   CheckTrue(PortKindOf('', VC.Network) = pkNetwork,   'nor does an empty name');

   (* A NETWORK RADIO CANNOT BE SWALLOWED BY THE NAME ARM, because it is
     configured with an address and a port number and never with a device
     name.  If that ever changes, this test is where it will be noticed. *)
   CheckTrue(PortKindOf('', VC.Network) <> pkSerial, 'network stays network');
end;

procedure TPortAddressTests.Test_AStoredPortReadsWhicheverWayItWasWritten;
begin
   (* THE UPGRADE PATH, AND A TEST ALREADY CAUGHT IT ONCE.

     The store holds the OS name now.  A file written before 2026-09-10 holds
     'SERIAL 7'.  A first version of this change translated only the new
     spelling, so a store holding 'SERIAL 5' rendered NO legacy key at all --
     an upgrading station would have come up with no port and no error. *)
   BeginTest('a stored port reads whichever spelling it was written in');
   CheckEquals('COM7', DeviceNameFromStoredPort('SERIAL 7'), 'the old spelling');
   CheckEquals('COM7', DeviceNameFromStoredPort('serial 7'), 'case-folded');
   CheckEquals('COM7', DeviceNameFromStoredPort('  SERIAL 7  '), 'trimmed');
   CheckEquals('COM7', DeviceNameFromStoredPort('COM7'), 'the new spelling');
   CheckEquals('COM64', DeviceNameFromStoredPort('SERIAL 64'), 'the last port');

   (* PASSED THROUGH UNCHANGED, which is what lets a device node work at all
     and what stops this mangling a spelling it does not recognise. *)
   BeginTest('anything that is not SERIAL n passes through untouched');
   CheckEquals('/dev/ttyUSB0', DeviceNameFromStoredPort('/dev/ttyUSB0'),
               'a Linux device node');
   CheckEquals('/dev/cu.usbserial-A50285BI',
               DeviceNameFromStoredPort('/dev/cu.usbserial-A50285BI'),
               'a macOS device node');
   CheckEquals('COM23', DeviceNameFromStoredPort('COM23'),
               'a COM number above what the enum holds');

   (* NO PORT MUST NOT BECOME A NAME, or a cleared slot would read as a
     configured serial radio -- PortKindOf trusts a name over the ordinal. *)
   BeginTest('nothing configured stays nothing');
   CheckEquals('', DeviceNameFromStoredPort(''), 'empty');
   CheckEquals('', DeviceNameFromStoredPort('   '), 'blanks');
   CheckEquals('', DeviceNameFromStoredPort('NONE'), 'NONE');
   CheckEquals('', DeviceNameFromStoredPort('none'), 'none, case-folded');
   CheckEquals('', DeviceNameFromStoredPort('SERIAL 0'), 'there is no port 0');
   CheckEquals('', DeviceNameFromStoredPort('SERIAL 65'),
               'past the last port the enum has');
   CheckEquals('', DeviceNameFromStoredPort('SERIAL x'), 'not a number');
end;

procedure TPortAddressTests.Test_TheLegacyTokenIsOnlyForTheBridge;
begin
   (* SerialTokenFor exists ONLY so the rendered CFGCA key still sets the
     ordinal.  It must produce nothing for a port no ordinal can express --
     that absence is correct, and the NAME is what carries such a port. *)
   BeginTest('the legacy token renders only what an ordinal can express');
   CheckEquals('SERIAL 7', SerialTokenFor('COM7'), 'a COM name');
   CheckEquals('SERIAL 64', SerialTokenFor('COM64'), 'the last one');
   CheckEquals('', SerialTokenFor('/dev/ttyUSB0'),
               'a device node has no token, and that is not a failure');
   CheckEquals('', SerialTokenFor('COM65'), 'past the enum');
   CheckEquals('', SerialTokenFor(''), 'nothing');

   (* AND THE ROUND TRIP CLOSES: whatever the store held, what the bridge
     renders and what the port opens agree. *)
   BeginTest('store, bridge and open path agree on the same port');
   CheckEquals('SERIAL 7', SerialTokenFor(DeviceNameFromStoredPort('SERIAL 7')),
               'an old store value survives the trip');
   CheckEquals('SERIAL 7', SerialTokenFor(DeviceNameFromStoredPort('COM7')),
               'and so does a new one');
   CheckEquals('COM7',
               EffectiveDeviceName(DeviceNameFromStoredPort('SERIAL 7'), NoPort),
               'the open path gets a name even with no ordinal set');
end;

procedure TPortAddressTests.Test_ADeviceNameGivesBackItsOwnOrdinal;
var
   p: PortType;
begin
   (* THE INVERSE OF SerialDeviceName, AND THE ROUND TRIP MUST CLOSE BOTH WAYS.

     This rule was written a second time inside uKeyerConfigApply before it was
     moved here, which is the drift this unit exists to stop -- five copies of
     the forward direction are what created it. *)
   BeginTest('a device name gives back the ordinal that names it');
   for p := Serial1 to Serial64 do
      begin
      CheckTrue(PortValueFromDeviceName(SerialDeviceName(p)) = p,
                'COM name round-trips to its own port');
      end;

   (* NoPort, NOT SOME OTHER PORT, for anything an ordinal cannot express.
     Answering a neighbouring port would open the wrong hardware. *)
   BeginTest('what no ordinal can express comes back as NoPort');
   CheckTrue(PortValueFromDeviceName('/dev/ttyUSB0') = NoPort,
             'a Linux device node has no ordinal');
   CheckTrue(PortValueFromDeviceName('/dev/cu.usbserial-A50285BI') = NoPort,
             'nor a macOS one');
   CheckTrue(PortValueFromDeviceName('COM65') = NoPort, 'past the last port');
   CheckTrue(PortValueFromDeviceName('COM0') = NoPort, 'there is no port 0');
   CheckTrue(PortValueFromDeviceName('') = NoPort, 'nothing configured');
   CheckTrue(PortValueFromDeviceName('COM3 (Silicon Labs)') = NoPort,
             'a caption is not a port name');

   (* THE KEYER PATH, WHICH WAS BROKEN. The editor stores what
     FillSerialPortCombo tags an item with, and that is the OS name; the apply
     path matched it against PortTypeSA's 'SERIAL n' and refused it, so a
     WinKeyer configured through the editor reported "unrecognised port COM7"
     and was never set up. Both halves meet here now. *)
   BeginTest('what the keyer editor stores is what the apply path reads');
   CheckTrue(PortValueFromDeviceName(DeviceNameFromStoredPort('COM7')) = Serial7,
             'a port chosen in the editor today');
   CheckTrue(PortValueFromDeviceName(DeviceNameFromStoredPort('SERIAL 7')) = Serial7,
             'and one stored before the ruling');
   CheckEquals('/dev/ttyUSB0',
               EffectiveDeviceName(DeviceNameFromStoredPort('/dev/ttyUSB0'),
                                   PortValueFromDeviceName('/dev/ttyUSB0')),
               'a device node survives with no ordinal to carry it');
end;

procedure TPortAddressTests.RunAllTests;
begin
   Test_EverySerialPortNamesItself;
   Test_NothingButASerialPortGetsAName;
   Test_TheNameParsesBackToTheSamePort;
   Test_AConfiguredNameWinsOverTheOrdinal;
   Test_EveryPortHasExactlyOneKind;
   Test_ANamedPortIsSerialWhateverTheOrdinalSays;
   Test_AStoredPortReadsWhicheverWayItWasWritten;
   Test_TheLegacyTokenIsOnlyForTheBridge;
   Test_ADeviceNameGivesBackItsOwnOrdinal;
end;

end.
