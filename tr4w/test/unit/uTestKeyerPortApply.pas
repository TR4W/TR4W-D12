unit uTestKeyerPortApply;
{$I ..\..\src\tr4w.inc}

(*
  Pins the keyer port a slot is given, for a radio of EITHER transport, and the
  words the CPU keyer uses when it cannot key.

  THE DEFECT (2026-11-26, NY4I's K4D-278): a NETWORK radio with its keyer
  output port on COM6, keyer DTR = CW, profile CW output RADIOPORT. F1 chose
  the CPU keyer and ran its thread, and COM6 never keyed -- in silence. The
  keyer port name, ordinal and invert flag were assigned only inside
  `if aRadio.Transport = rtSerial`, beside the CAT port, so LOGK1EA saw no
  keyer port, OpenKeyerPortFor exited without a word and DriveCWLine had no
  port to drive.

  uRadioConfigApply.SlotPortNamesFor is the decision now, pure, and these pin
  it: the keyer port for any transport, the CAT port for serial only, the
  release to a WinKeyer and to CAT unchanged. uCWKeyerCPU.CPUKeyerCannotKeyReason
  is what the one throttled Warn says.

  NO HARDWARE. The TSerialPort below is created and never opened.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework,
   VC,                 (* PortType, Serial1 *)
   LogRadio,           (* Radio2, RtsDtr_* *)
   uPortAddress,       (* PortValueFromDeviceName *)
   uRadioConfigStore,  (* TRadioDefinition, TStationProfile, CWOUTPUT_* *)
   uKeyerConfigStore,  (* CWOUT_RADIOPORT *)
   uRadioConfigApply;  (* SlotPortNamesFor *)

type
   TKeyerPortApplyTests = class(TTestCase)
   private
      function MakeNetworkRadio: TRadioDefinition;
      function MakeSerialRadio: TRadioDefinition;
   protected
      procedure Test_NetworkRadioGetsItsKeyerPort;
      procedure Test_NetworkRadioGetsNoCATPort;
      procedure Test_NetworkRadioReleasesThePortToAKeyerDeviceOrCAT;
      procedure Test_SerialRadioIsUnchanged;
      procedure Test_NoRadioGetsNothing;
      procedure Test_TheCPUKeyerSaysWhyItCannotKey;
      procedure Test_TheCannotKeyWarnIsOncePerInitialisation;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Log4D,           (* TLogLevel, ILogAppender *)
   MainUnit,        (* logger *)
   uTestLogCapture, (* TCaptureAppender *)
   uSerialPort,   (* TSerialPort -- created, never opened *)
   LogK1EA,       (* CPUKeyerCannotKeyReported *)
   uCWKeyerCPU;   (* CPUKeyerCannotKeyReason, WarnIfCPUKeyerCannotKey *)

function TKeyerPortApplyTests.MakeNetworkRadio: TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name            := 'K4D-278';
   Result.RegistryId      := 'K4';
   Result.Transport       := rtNetwork;
   (* A stale serial control port, left behind by a switch to network: it must
     not become a CAT port name. *)
   Result.ControlPort     := 'COM3';
   Result.IPAddress       := '192.168.73.108';
   Result.TCPPort         := 9200;
   Result.KeyerOutputPort := 'COM6';
   Result.KeyerDTR        := 'CW';
   Result.KeyerRTS        := 'PTT';
   Result.KeyerInvert     := True;
end;

function TKeyerPortApplyTests.MakeSerialRadio: TRadioDefinition;
begin
   Result := TRadioDefinition.Create;
   Result.Name            := 'K3 Serial';
   Result.RegistryId      := 'K3';
   Result.Transport       := rtSerial;
   Result.ControlPort     := 'COM3';
   Result.BaudRate        := 38400;
   Result.KeyerOutputPort := 'SERIAL 6';   (* a pre-2026-09-10 store spelling *)
   Result.KeyerInvert     := False;
end;

procedure TKeyerPortApplyTests.Test_NetworkRadioGetsItsKeyerPort;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   catPort, keyerPort: string;
   invert: boolean;
begin
   BeginTest('Test_NetworkRadioGetsItsKeyerPort');
   radio := MakeNetworkRadio;
   prof  := TStationProfile.Create;
   try
      prof.CWOutput1 := CWOUT_RADIOPORT;

      SlotPortNamesFor(1, radio, prof, False, catPort, keyerPort, invert);

      CheckEquals('COM6', keyerPort,
                  'a network radio keys DTR/RTS on its own keyer port');
      CheckEquals(Ord(Serial1) + 5, Ord(PortValueFromDeviceName(keyerPort)),
                  'and the ordinal LOGK1EA indexes its port table by is Serial6');
      CheckTrue(invert, 'the inverted-interface flag comes with it');

      (* Slot 2 the same, through CWOutput2. *)
      prof.CWOutput2 := CWOUT_RADIOPORT;
      SlotPortNamesFor(2, radio, prof, False, catPort, keyerPort, invert);
      CheckEquals('COM6', keyerPort, 'slot 2 likewise');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TKeyerPortApplyTests.Test_NetworkRadioGetsNoCATPort;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   catPort, keyerPort: string;
   invert: boolean;
begin
   BeginTest('Test_NetworkRadioGetsNoCATPort');
   radio := MakeNetworkRadio;
   prof  := TStationProfile.Create;
   try
      prof.CWOutput1 := CWOUT_RADIOPORT;

      SlotPortNamesFor(1, radio, prof, False, catPort, keyerPort, invert);

      (* CATPortKind reads the NAME first, so a stale COM3 here would make a
        TCP radio claim to be a serial one. *)
      CheckEquals('', catPort, 'a network radio has no serial CAT port');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TKeyerPortApplyTests.Test_NetworkRadioReleasesThePortToAKeyerDeviceOrCAT;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   catPort, keyerPort: string;
   invert: boolean;
begin
   BeginTest('Test_NetworkRadioReleasesThePortToAKeyerDeviceOrCAT');
   radio := MakeNetworkRadio;
   prof  := TStationProfile.Create;
   try
      (* A WinKeyer or YCCC box owns its port: LOGK1EA must key nothing, or it
        opens the port first and the device gets "Access is denied". *)
      prof.CWOutput1 := 'WinKeyer';
      SlotPortNamesFor(1, radio, prof, True, catPort, keyerPort, invert);
      CheckEquals('', keyerPort, 'a keyer device releases the port');

      prof.CWOutput1 := CWOUTPUT_CAT;
      SlotPortNamesFor(1, radio, prof, False, catPort, keyerPort, invert);
      CheckEquals('', keyerPort, 'CW by CAT releases the port');

      prof.CWOutput1 := CWOUTPUT_NONE;
      SlotPortNamesFor(1, radio, prof, False, catPort, keyerPort, invert);
      CheckEquals('', keyerPort, 'no CW output releases the port');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TKeyerPortApplyTests.Test_SerialRadioIsUnchanged;
var
   radio: TRadioDefinition;
   prof: TStationProfile;
   catPort, keyerPort: string;
   invert: boolean;
begin
   BeginTest('Test_SerialRadioIsUnchanged');
   radio := MakeSerialRadio;
   prof  := TStationProfile.Create;
   try
      prof.CWOutput1 := CWOUT_RADIOPORT;

      SlotPortNamesFor(1, radio, prof, False, catPort, keyerPort, invert);

      CheckEquals('COM3', catPort,   'the serial CAT port');
      CheckEquals('COM6', keyerPort, 'the keyer port, normalised from SERIAL 6');
      CheckFalse(invert, 'not inverted');

      prof.CWOutput1 := 'WinKeyer';
      SlotPortNamesFor(1, radio, prof, True, catPort, keyerPort, invert);
      CheckEquals('COM3', catPort,   'the CAT port stays with a keyer device');
      CheckEquals('',     keyerPort, 'and the keyer port is released');
   finally
      prof.Free;
      radio.Free;
   end;
end;

procedure TKeyerPortApplyTests.Test_NoRadioGetsNothing;
var
   catPort, keyerPort: string;
   invert: boolean;
begin
   BeginTest('Test_NoRadioGetsNothing');
   catPort   := 'stale';
   keyerPort := 'stale';
   invert    := True;

   SlotPortNamesFor(1, nil, nil, False, catPort, keyerPort, invert);

   CheckEquals('', catPort,   'an emptied slot has no CAT port');
   CheckEquals('', keyerPort, 'and no keyer port');
   CheckFalse(invert, 'and no inversion');
end;

procedure TKeyerPortApplyTests.Test_TheCPUKeyerSaysWhyItCannotKey;
var
   savedName: string;
   savedPort: PortType;
   savedSerial: TSerialPort;
   savedDTR, savedRTS: tr4w_RTSDTRType;
   port: TSerialPort;
begin
   BeginTest('Test_TheCPUKeyerSaysWhyItCannotKey');
   savedName   := Radio2.tKeyerPortName;
   savedPort   := Radio2.tKeyerPort;
   savedSerial := Radio2.tKeyerSerialPort;
   savedDTR    := Radio2.tr4w_keyer_DTR_state;
   savedRTS    := Radio2.tr4w_keyer_rts_state;
   port := TSerialPort.Create('COM6');
   try
      CheckTrue(Pos('no radio', CPUKeyerCannotKeyReason(nil)) > 0, 'nil radio');

      Radio2.tKeyerPortName   := '';
      Radio2.tKeyerPort       := NoPort;
      Radio2.tKeyerSerialPort := nil;
      CheckTrue(Pos('no keyer port is configured', CPUKeyerCannotKeyReason(@Radio2)) > 0,
                'no port configured -- the K4D-278 case before the fix');

      Radio2.tKeyerPortName := 'COM6';
      Radio2.tKeyerPort     := PortValueFromDeviceName('COM6');
      CheckTrue(Pos('COM6 is configured but not open', CPUKeyerCannotKeyReason(@Radio2)) > 0,
                'configured, not open, and the port is NAMED');

      Radio2.tKeyerSerialPort     := port;
      Radio2.tr4w_keyer_DTR_state := RtsDtr_Nothing;
      Radio2.tr4w_keyer_rts_state := RtsDtr_PTT;
      CheckTrue(Pos('neither DTR nor RTS is set to CW', CPUKeyerCannotKeyReason(@Radio2)) > 0,
                'open, but no line keys CW');

      Radio2.tr4w_keyer_DTR_state := RtsDtr_CW;
      CheckEquals('', CPUKeyerCannotKeyReason(@Radio2), 'DTR = CW on an open port keys');

      Radio2.tr4w_keyer_DTR_state := RtsDtr_PTT;
      Radio2.tr4w_keyer_rts_state := RtsDtr_CW;
      CheckEquals('', CPUKeyerCannotKeyReason(@Radio2), 'RTS = CW on an open port keys');
   finally
      Radio2.tKeyerPortName       := savedName;
      Radio2.tKeyerPort           := savedPort;
      Radio2.tKeyerSerialPort     := savedSerial;
      Radio2.tr4w_keyer_DTR_state := savedDTR;
      Radio2.tr4w_keyer_rts_state := savedRTS;
      port.Free;
   end;
end;

function CannotKeyWarnings(const aCapture: TCaptureAppender): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aCapture.Lines.Count - 1 do
      begin
      if Pos('CW will not key', aCapture.Lines[i]) > 0 then
         begin
         Inc(Result);
         end;
      end;
end;

procedure TKeyerPortApplyTests.Test_TheCannotKeyWarnIsOncePerInitialisation;
var
   savedName: string;
   savedPort: PortType;
   savedSerial: TSerialPort;
   savedReported: boolean;
   savedLevel: TLogLevel;
   capture: TCaptureAppender;
   keep: ILogAppender;
begin
   BeginTest('Test_TheCannotKeyWarnIsOncePerInitialisation');
   savedName     := Radio2.tKeyerPortName;
   savedPort     := Radio2.tKeyerPort;
   savedSerial   := Radio2.tKeyerSerialPort;
   savedReported := CPUKeyerCannotKeyReported[2];

   capture := TCaptureAppender.Create('cpu-keyer-cannot-key');
   keep := capture;
   savedLevel := logger.Level;
   logger.Level := Log4D.Warn;
   logger.AddAppender(keep);
   try
      Radio2.tKeyerPortName   := '';
      Radio2.tKeyerPort       := NoPort;
      Radio2.tKeyerSerialPort := nil;

      CPUKeyerCannotKeyReported[2] := False;
      capture.Lines.Clear;
      WarnIfCPUKeyerCannotKey(@Radio2);
      WarnIfCPUKeyerCannotKey(@Radio2);
      CheckEquals(1, CannotKeyWarnings(capture), 'two messages, ONE Warn');

      (* What InitializeKeyer does: a new configuration reports again. *)
      CPUKeyerCannotKeyReported[2] := False;
      WarnIfCPUKeyerCannotKey(@Radio2);
      CheckEquals(2, CannotKeyWarnings(capture), 'and once more after re-initialisation');
   finally
      logger.RemoveAppender(keep);
      logger.Level := savedLevel;
      keep := nil;
      Radio2.tKeyerPortName        := savedName;
      Radio2.tKeyerPort            := savedPort;
      Radio2.tKeyerSerialPort      := savedSerial;
      CPUKeyerCannotKeyReported[2] := savedReported;
   end;
end;

procedure TKeyerPortApplyTests.RunAllTests;
begin
   Test_NetworkRadioGetsItsKeyerPort;
   Test_NetworkRadioGetsNoCATPort;
   Test_NetworkRadioReleasesThePortToAKeyerDeviceOrCAT;
   Test_SerialRadioIsUnchanged;
   Test_NoRadioGetsNothing;
   Test_TheCPUKeyerSaysWhyItCannotKey;
   Test_TheCannotKeyWarnIsOncePerInitialisation;
end;

end.
