unit uTestComPortEnumerator;
{$I ..\..\src\tr4w.inc}
(*
  The serial-port enumerator.

  WHAT FINDS A PORT IS I/O -- SetupAPI on Windows, sysfs on Linux -- and its
  answer is a property of the machine, not of the code.  A test asserting "one
  FTDI adapter" would pass on the bench PC and fail everywhere else, which is
  worse than no test.

  So these pin the portable half: the name parse, how an entry describes
  itself, and the ordering.  Plus two invariants that hold on any machine with
  any hardware, which is what makes them worth asserting at all.
*)

interface

uses
   SysUtils, uTR4WTestFramework, ComPortEnumerator, uPortAddress;

type
   TComPortEnumeratorTests = class(TTestCase)
   protected
      procedure Test_ComPortNumberParsing;
      procedure Test_DescribeDoesNotRepeatThePortName;
      procedure Test_OrderingIsNumericNotAlphabetic;
      procedure Test_LiveListIsSelfConsistent;
   public
      procedure RunAllTests; override;
   end;

implementation

function MakePort(const aName, aFriendly, aDesc: string): TComPortInfo;
begin
   Result := Default(TComPortInfo);
   Result.PortName     := aName;
   Result.PortNumber   := ComPortNumber(aName);
   Result.FriendlyName := aFriendly;
   Result.DeviceDesc   := aDesc;
end;

procedure TComPortEnumeratorTests.Test_ComPortNumberParsing;
begin
   (* 0 IS THE IMPORTANT ANSWER, not the parse.  A name that does not yield a
     number is what marks a port unaddressable, so a spelling that parsed by
     accident would make an unstorable port look selectable. *)
   BeginTest('a COM number is parsed, and nothing else is');
   CheckEquals(14, ComPortNumber('COM14'), 'COM14');
   CheckEquals(3,  ComPortNumber('com3'),  'lower case is the same port');
   CheckEquals(7,  ComPortNumber('  COM7  '), 'surrounding blanks');
   CheckEquals(0,  ComPortNumber(''), 'an empty name is not a port');
   CheckEquals(0,  ComPortNumber('COM'), 'no number at all');
   CheckEquals(0,  ComPortNumber('COM3 (Silicon Labs)'), 'a decorated name');
   CheckEquals(0,  ComPortNumber('LPT1'), 'a parallel port is not a COM port');
   (* THE LINUX CASE, and the reason Addressable is False there today: a device
     node carries no COM number, and TR4W stores a port as SERIAL n. *)
   CheckEquals(0,  ComPortNumber('/dev/ttyUSB0'), 'a Linux device node');
   CheckEquals(0,  ComPortNumber('/dev/cu.usbserial-A50285BI'), 'a macOS node');
end;

procedure TComPortEnumeratorTests.Test_DescribeDoesNotRepeatThePortName;
var
   info: TComPortInfo;
begin
   (* Windows folds the port into the friendly name; Linux does not.  One rule
     covers both -- prefix unless the text already says which port it is. *)
   BeginTest('an entry names its port exactly once');

   info := MakePort('COM14', 'Silicon Labs CP210x USB to UART Bridge (COM14)', '');
   CheckEquals('Silicon Labs CP210x USB to UART Bridge (COM14)', info.Describe,
               'the Windows friendly name already contains the port');

   info := MakePort('/dev/ttyUSB0', 'FTDI FT232R USB UART', '');
   CheckEquals('/dev/ttyUSB0 - FTDI FT232R USB UART', info.Describe,
               'a Linux description names the adapter, so the node is prefixed');

   info := MakePort('COM3', '', 'USB Serial Port');
   CheckEquals('COM3 - USB Serial Port', info.Describe,
               'no friendly name falls back to the device description');

   info := MakePort('COM3', '', '');
   CheckEquals('COM3', info.Describe, 'with neither, the port name stands alone');
end;

procedure TComPortEnumeratorTests.Test_OrderingIsNumericNotAlphabetic;
var
   ports: TComPortInfoArray;
begin
   (* THIS IS THE WHOLE REASON THE SORT EXISTS.  Plain string order puts COM10
     before COM2 and /dev/ttyUSB10 before /dev/ttyUSB2, and an operator hunting
     for their adapter reads the list top to bottom. *)
   BeginTest('ports order by number, not by spelling');

   SetLength(ports, 4);
   ports[0] := MakePort('COM10', '', '');
   ports[1] := MakePort('COM2',  '', '');
   ports[2] := MakePort('COM1',  '', '');
   ports[3] := MakePort('COM21', '', '');
   SortPorts(ports);
   CheckEquals('COM1',  ports[0].PortName, 'first');
   CheckEquals('COM2',  ports[1].PortName, 'second');
   CheckEquals('COM10', ports[2].PortName, 'COM10 comes after COM2');
   CheckEquals('COM21', ports[3].PortName, 'last');

   SetLength(ports, 3);
   ports[0] := MakePort('/dev/ttyUSB10', '', '');
   ports[1] := MakePort('/dev/ttyUSB2',  '', '');
   ports[2] := MakePort('/dev/ttyACM0',  '', '');
   SortPorts(ports);
   CheckEquals('/dev/ttyACM0',  ports[0].PortName, 'a different stem sorts by name');
   CheckEquals('/dev/ttyUSB2',  ports[1].PortName, 'ttyUSB2 before ttyUSB10');
   CheckEquals('/dev/ttyUSB10', ports[2].PortName, 'ttyUSB10 last');
end;

procedure TComPortEnumeratorTests.Test_LiveListIsSelfConsistent;
var
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   info: TComPortInfo;
   i: integer;
begin
   (* Environment-independent: whatever this machine has -- including nothing --
     the two entry points must agree, and Addressable must mean exactly what it
     says.  A machine with no serial port satisfies all of it. *)
   BeginTest('the enumerated list agrees with itself');
   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;

      if not ComPortEnumerationSupported then
         begin
         (* macOS reaches here.  An empty list is the CORRECT answer, and the
           constant is how a caller tells it apart from "no ports fitted". *)
         CheckEquals(0, enumerator.Count,
                     'an unimplemented platform must report nothing, not guess');
         Exit;
         end;

      names := enumerator.PortNames;
      CheckEquals(enumerator.Count, Length(names),
                  'PortNames must name every port Count claims');

      for i := 0 to High(names) do
         begin
         CheckTrue(enumerator.PortByName(names[i], info),
                   Format('PortByName cannot find its own entry "%s"', [names[i]]));
         CheckEquals(names[i], info.PortName, 'the entry found is the one asked for');
         CheckEquals(ComPortNumber(names[i]), info.PortNumber,
                     Format('the recorded number disagrees with the name "%s"',
                            [names[i]]));
         (* Addressable is a statement about TR4W's config vocabulary, not
           about the port: it is true exactly when the port can be stored as
           SERIAL n. *)
         if info.Addressable then
            begin
            CheckTrue((info.PortNumber >= 1) and
                      (info.PortNumber <= MAX_ADDRESSABLE_COM_PORT),
                      Format('"%s" is addressable but its number is %d',
                             [names[i], info.PortNumber]));
            end
         else
            begin
            CheckFalse((info.PortNumber >= 1) and
                       (info.PortNumber <= MAX_ADDRESSABLE_COM_PORT) and
                       (Pos('/', info.PortName) = 0),
                       Format('"%s" is storable as SERIAL %d but marked unaddressable',
                              [names[i], info.PortNumber]));
            end;
         end;
   finally
      enumerator.Free;
   end;
end;

procedure TComPortEnumeratorTests.RunAllTests;
begin
   Test_ComPortNumberParsing;
   Test_DescribeDoesNotRepeatThePortName;
   Test_OrderingIsNumericNotAlphabetic;
   Test_LiveListIsSelfConsistent;
end;

end.
