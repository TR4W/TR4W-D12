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
      procedure Test_EveryRegisteredRadioRunsTheBaseConstructor;
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

// Every registered radio, on every transport it claims to support, must actually
// run TFactoryRadioBase.Create(ProcRef).
//
// This is not Flex-specific -- it lives here because the Flex is what exposed it.
// TFlexCAT was written with `inherited Create;` instead of
// `inherited Create(ProcessMsg);`.  Because the base constructor is `overload`ed
// that compiles cleanly and silently resolves to TObject.Create, so the radio got
// no baseProcMsg (every received frame discarded), FLastValidResponse = 0 (so it
// declared ~126 years of silence and reopened COM16 in a loop forever) and no
// SocketLock.  The compiler emits NO warning -- verified by building at /v:normal
// before and after the fix.
//
// So the only defence is to construct each radio and check.  A future radio that
// makes the same slip fails here instead of on someone's bench.
procedure TFlexRegistryTests.Test_EveryRegisteredRadioRunsTheBaseConstructor;
var
   ids: TArray<string>;
   id, bad: string;
   r: TFactoryRadioBase;
   link: TRadioLink;
   checked: integer;
begin
   BeginTest('every registered radio runs the base constructor on every link');
   bad := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;
   for id in ids do
      begin
      for link := Low(TRadioLink) to High(TRadioLink) do
         begin
         // Only build the transports the radio actually claims.
         if ((link = rlSerial) and not uRadioRegistry.SupportsSerialId(id)) or
            ((link = rlNetwork) and not uRadioRegistry.SupportsNetworkId(id)) then
            begin
            Continue;
            end;
         r := uRadioRegistry.CreateInstanceForLinkId(id, link);
         if r = nil then
            begin
            bad := bad + id + '(nil) ';
            Continue;
            end;
         try
            Inc(checked);
            if not r.BaseConstructorRan then
               begin
               bad := bad + id + '/' + r.ClassName + ' ';
               end;
         finally
            r.Free;
         end;
         end;
      end;
   // Guard against the loop silently checking nothing.
   CheckTrue(checked > 50, Format('expected to construct many radios, built only %d', [checked]));
   CheckEquals('', bad, 'radios whose base constructor did not run: ' + bad);
end;

procedure TFlexRegistryTests.RunAllTests;
begin
   Test_FlexSerialBuildsCATDriver;
   Test_FlexNetworkBuildsAPIDriver;
   Test_FlexIsOneEntrySupportingBothLinks;
   Test_SingleCtorRadioIsSameClassOnBothLinks;
   Test_EveryRegisteredRadioRunsTheBaseConstructor;
end;

end.
