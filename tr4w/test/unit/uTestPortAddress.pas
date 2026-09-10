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
   CheckEquals('', SerialDeviceName(Network),   'a network port is not a COM port');
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
   CheckEquals(0, ComPortNumber(SerialDeviceName(Network)),
               'an unnamed port is not port zero');
end;

procedure TPortAddressTests.RunAllTests;
begin
   Test_EverySerialPortNamesItself;
   Test_NothingButASerialPortGetsAName;
   Test_TheNameParsesBackToTheSamePort;
end;

end.
