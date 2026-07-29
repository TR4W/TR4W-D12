unit uTestFlexRegistry;

{
  Guards the TWO-CONSTRUCTOR registration -- the registry mechanism that lets ONE
  radio entry build a different driver class per transport.

  WHY THIS EXISTS.  FlexRadio is the only radio in the tree whose two links speak
  genuinely different PROTOCOLS: TCP 4992 is the SmartSDR Ethernet API, while the
  serial/TCP-5002 CAT port speaks Kenwood-style 2-char + Flex ZZxx commands.
  Every other dual-transport radio (IC-7610, K4, TS-890 ...) speaks ONE protocol
  over two pipes and registers a single ctor, letting TFactoryRadioBase.Connect
  pick the pipe.

  The failure mode this guards is SILENT and total: if the serial ctor is dropped,
  or CreateInstanceForLink stops consulting it, a Flex on a COM port is built as
  the TCP-API driver.  It would then emit SmartSDR API command lines down a serial
  port and NOTHING would ever decode -- exactly the "no display at all" symptom
  NY4I hit on the bench for a different reason (a missing readTerminator).

  PAIRED OPPOSITES.  Asserting only "serial gives TFlexCAT" would still pass if
  CreateInstanceForLink ignored its link argument and the default ctor happened to
  be TFlexCAT.  So each transport is asserted, AND a single-ctor control radio is
  asserted to yield the SAME class on both links -- proving the link argument is
  read, not that one branch is hard-wired.

  NO TRANSPORT.  These construct radio objects only; nothing is opened, so this
  runs in CI.
}

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioRegistry,
   uRadioFlexAPI, uRadioFlexCAT, uRadioFlex6000, uRadioIcom7610, VC;

type
   TFlexRegistryTests = class(TTestCase)
   protected
      procedure Test_FlexSerialBuildsCATDriver;
      procedure Test_FlexNetworkBuildsAPIDriver;
      procedure Test_FlexIsOneEntrySupportingBothLinks;
      procedure Test_SingleCtorRadioIsSameClassOnBothLinks;
   public
      procedure RunAllTests; override;
   end;

implementation

// Build for a transport and report the concrete class name, freeing the object.
function ClassForLink(model: InterfacedRadioType; link: TRadioLink): string;
var
   r: TFactoryRadioBase;
begin
   Result := '<nil>';
   r := uRadioRegistry.CreateInstanceForLink(model, link);
   if r <> nil then
      begin
      try
         Result := r.ClassName;
      finally
         r.Free;
      end;
      end;
end;

procedure TFlexRegistryTests.Test_FlexSerialBuildsCATDriver;
begin
   // A Flex on a COM port must get the ZZ CAT driver, never the 4992 API driver.
   BeginTest('a serial Flex is built as TFlexCAT');
   CheckEquals(TFlexCAT.ClassName, ClassForLink(FLEX, rlSerial),
               'serial Flex must use the SmartSDR CAT (ZZ) driver');
end;

procedure TFlexRegistryTests.Test_FlexNetworkBuildsAPIDriver;
begin
   // ...and the opposite, so the test above cannot pass by the link being ignored.
   BeginTest('a network Flex is built as TFlexAPI');
   CheckEquals(TFlexAPI.ClassName, ClassForLink(FLEX, rlNetwork),
               'network Flex must use the SmartSDR Ethernet API driver');
end;

procedure TFlexRegistryTests.Test_FlexIsOneEntrySupportingBothLinks;
begin
   // NY4I: "The radio type should be the standard Flex entry. There should not be
   // a new one."  One list entry, both transports -- not two entries.
   BeginTest('FLEX is a single entry offering serial AND network');
   CheckTrue(uRadioRegistry.IsRegistered(FLEX), 'FLEX must be registered');
   CheckTrue(uRadioRegistry.SupportsSerial(FLEX), 'FLEX must offer serial');
   CheckTrue(uRadioRegistry.SupportsNetwork(FLEX), 'FLEX must offer network');
end;

procedure TFlexRegistryTests.Test_SingleCtorRadioIsSameClassOnBothLinks;
begin
   // The control.  An IC-7610 speaks CI-V on either transport and registers ONE
   // ctor, so both links must yield the same class.  If this ever diverges, the
   // two-ctor path is leaking into radios that never asked for it.
   BeginTest('a single-ctor radio builds the same class on both links');
   CheckEquals(ClassForLink(IC7610, rlNetwork), ClassForLink(IC7610, rlSerial),
               'a one-protocol radio must not vary its class by transport');
end;

procedure TFlexRegistryTests.RunAllTests;
begin
   Test_FlexSerialBuildsCATDriver;
   Test_FlexNetworkBuildsAPIDriver;
   Test_FlexIsOneEntrySupportingBothLinks;
   Test_SingleCtorRadioIsSameClassOnBothLinks;
end;

end.
