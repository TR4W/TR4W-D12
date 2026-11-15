unit uTestTenTecModeSet;
{$I ..\..\src\tr4w.inc}

(*
  Issue 181: "Ten-Tec Orion/Omni: Alt-M mode change sends no command".

  Alt-M reaches a radio as RadioObject.SetRadioFreq(freq, mode, 'A') (through
  DisplayBandMode), which calls the driver's SetFrequency with the mode.  These
  pin what each Ten-Tec driver then emits:

    - Orion: '*AF..' then '*RMM<d>' -- the mode set D7 had commented out until
      its own issue 683, and Hamlib's tt565_set_mode ("*R%cM%c": M main / S sub,
      0 USB 1 LSB 2 CW 3 CW-R 4 AM 5 FM 6 RTTY).
    - Omni VI (CI-V): $06 <mode> with NO filter byte in CW, as D7's
      `(RadioModel = OMNI6) and (Mode = CW)` arm sent it; other modes keep it.
    - every other Icom still sends the filter byte in CW (the trait is the
      Omni's alone).

  NO TRANSPORT: the probes override SendToRadio(s), so this proves what the
  DRIVER emits, never what a radio accepts.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioTenTecOrion,
   uRadioTenTecOmni6, uRadioIcom7610, VC, LogRadio;

type
   TTenTecModeSetTests = class(TTestCase)
   protected
      procedure Test_Orion_SetModeMainAndSub;
      procedure Test_Orion_SetFrequencyCarriesTheMode;
      procedure Test_Orion_AltMPath_SendsTheModeCommand;
      procedure Test_Omni6_CWHasNoFilterByte;
      procedure Test_Omni6_PhoneKeepsTheFilterByte;
      procedure Test_OtherIcom_CWKeepsTheFilterByte;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TOrionProbe = class(TTenTecOrionRadio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TOmni6Probe = class(TTenTecOmni6Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

   TIcom7610Probe = class(TIcom7610Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

(* CI-V bytes as the driver's string carries them: one Char per byte, by
  codepoint.  NOT an untyped literal such as #$FD -- passed as a string it is
  converted through the UTF-8 codepage and becomes U+FFFD (the trap recorded
  above CIV_EOM in uRadioIcomBase). *)
function CivBytes(const a: array of Byte): string;
var
   i: Integer;
begin
   Result := '';
   for i := Low(a) to High(a) do
      begin
      Result := Result + Char(a[i]);
      end;
end;

procedure TOrionProbe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TOmni6Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TIcom7610Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TTenTecModeSetTests.Test_Orion_SetModeMainAndSub;
var
   r: TOrionProbe;
begin
   BeginTest('Orion: SetMode sends *RMM<d> for A and *RSM<d> for B');
   r := TOrionProbe.Create;
   try
      r.SetMode(rmCW, nrVFOA);
      CheckEquals('*RMM2'#13, r.sent, 'CW on the main receiver');
      r.sent := '';
      r.SetMode(rmUSB, nrVFOB);
      CheckEquals('*RSM0'#13, r.sent, 'USB on the sub receiver');
      r.sent := '';
      r.SetMode(rmLSB, nrVFOA);
      CheckEquals('*RMM1'#13, r.sent, 'LSB on the main receiver');
   finally
      r.Free;
   end;
end;

procedure TTenTecModeSetTests.Test_Orion_SetFrequencyCarriesTheMode;
var
   r: TOrionProbe;
begin
   BeginTest('Orion: SetFrequency with a mode sends the frequency, then the mode');
   r := TOrionProbe.Create;
   try
      r.SetFrequency(14025000, nrVFOA, rmCW);
      CheckEquals('*AF14.02500'#13'*RMM2'#13, r.sent, 'frequency then mode');
      r.sent := '';
      r.SetFrequency(14025000, nrVFOA, rmNone);
      CheckEquals('*AF14.02500'#13, r.sent, 'rmNone leaves the mode alone');
   finally
      r.Free;
   end;
end;

(* The Alt-M path below DisplayBandMode: RadioObject.SetRadioFreq with the new
  mode.  Radio1 is borrowed and restored, as uTestKenwoodLANSplit does. *)
procedure TTenTecModeSetTests.Test_Orion_AltMPath_SendsTheModeCommand;
var
   r: TOrionProbe;
   savedFactory: TFactoryRadioBase;
   savedCommanded: integer;
begin
   BeginTest('Orion: the Alt-M path (SetRadioFreq with a new mode) sends *RMM');
   r := TOrionProbe.Create;
   savedFactory := Radio1.tFactoryObject;
   savedCommanded := Radio1.tCommandedQSYFreq;
   try
      Radio1.tFactoryObject := r;
      Radio1.SetRadioFreq(14200000, Phone, 'A');
      CheckTrue(Pos('*RMM0'#13, r.sent) > 0, 'phone above 10 MHz is USB -- got ' + r.sent);
      r.sent := '';
      Radio1.SetRadioFreq(14025000, CW, 'A');
      CheckTrue(Pos('*RMM2'#13, r.sent) > 0, 'CW -- got ' + r.sent);
   finally
      Radio1.tFactoryObject := savedFactory;
      Radio1.tCommandedQSYFreq := savedCommanded;
      r.Free;
   end;
end;

procedure TTenTecModeSetTests.Test_Omni6_CWHasNoFilterByte;
var
   r: TOmni6Probe;
begin
   BeginTest('Omni VI: CW mode set is $06 $03 with no filter byte (D7, n4af 4.43.3)');
   r := TOmni6Probe.Create;
   try
      r.SetMode(rmCW, nrVFOA);
      CheckTrue(Pos(CivBytes([$06, $03, $FD]), r.sent) > 0, 'CW: $06 $03 then end of message');
      CheckEquals(0, Pos(CivBytes([$06, $03, $01, $FD]), r.sent), 'CW must not carry the filter byte');
   finally
      r.Free;
   end;
end;

procedure TTenTecModeSetTests.Test_Omni6_PhoneKeepsTheFilterByte;
var
   r: TOmni6Probe;
begin
   BeginTest('Omni VI: USB mode set keeps the filter byte, as D7 sent it');
   r := TOmni6Probe.Create;
   try
      r.SetMode(rmUSB, nrVFOA);
      CheckTrue(Pos(CivBytes([$06, $01, $01, $FD]), r.sent) > 0, 'USB: $06 $01 $01');
   finally
      r.Free;
   end;
end;

procedure TTenTecModeSetTests.Test_OtherIcom_CWKeepsTheFilterByte;
var
   r: TIcom7610Probe;
begin
   BeginTest('IC-7610: CW mode set still carries the filter byte (the trait is the Omni''s)');
   r := TIcom7610Probe.Create;
   try
      r.SetMode(rmCW, nrVFOA);
      CheckTrue(Pos(CivBytes([$06, $03, $01, $FD]), r.sent) > 0, 'CW: $06 $03 $01 on a modern Icom');
   finally
      r.Free;
   end;
end;

procedure TTenTecModeSetTests.RunAllTests;
begin
   Test_Orion_SetModeMainAndSub;
   Test_Orion_SetFrequencyCarriesTheMode;
   Test_Orion_AltMPath_SendsTheModeCommand;
   Test_Omni6_CWHasNoFilterByte;
   Test_Omni6_PhoneKeepsTheFilterByte;
   Test_OtherIcom_CWKeepsTheFilterByte;
end;

end.
