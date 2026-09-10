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
   CheckEquals('', SerialDeviceName(Parallel1), 'LPT1');
   CheckEquals('', SerialDeviceName(Parallel2), 'LPT2');
   CheckEquals('', SerialDeviceName(Parallel3), 'LPT3');
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
         pkParallel: Inc(parallel);
         pkNone:     Inc(none);
      end;
      end;

   CheckEquals(MAX_SERIAL_PORT, serial, 'one serial kind per serial member');
   CheckEquals(1, network,  'exactly one network member');
   CheckEquals(3, parallel, 'LPT1..LPT3');
   CheckEquals(1, none,     'only NoPort is nothing');
   CheckEquals(Ord(High(PortType)) + 1, serial + network + parallel + none,
               'every member accounted for, none counted twice');

   // And the individual answers, so a count that is right by accident fails.
   CheckTrue(PortKindOf('', NoPort)    = pkNone,     'NoPort');
   CheckTrue(PortKindOf('', Serial1)   = pkSerial,   'the first serial');
   CheckTrue(PortKindOf('', Serial64)  = pkSerial,   'the last serial');
   CheckTrue(PortKindOf('', VC.Network)   = pkNetwork,  'Network');
   CheckTrue(PortKindOf('', Parallel1) = pkParallel, 'LPT1');
   CheckTrue(PortKindOf('', Parallel3) = pkParallel, 'LPT3');
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

procedure TPortAddressTests.RunAllTests;
begin
   Test_EverySerialPortNamesItself;
   Test_NothingButASerialPortGetsAName;
   Test_TheNameParsesBackToTheSamePort;
   Test_AConfiguredNameWinsOverTheOrdinal;
   Test_EveryPortHasExactlyOneKind;
   Test_ANamedPortIsSerialWhateverTheOrdinalSays;
end;

end.
