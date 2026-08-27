{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
 unit uRadioIcom9700;
{$I ..\tr4w.inc}

{
  Icom IC-9700 Radio Implementation

  The IC-9700 is a VHF/UHF/1.2GHz all-mode transceiver that uses the CI-V protocol.
  CI-V address: 0xA2

  Features:
  - Full CI-V command support via TIcomRadio base class
  - Polling-based operation (no auto-info mode like K4)
  - Standard polling interval: 100ms
  - Triple receivers (Main/Sub/Sub2)
  - Supports 2m, 70cm, and 23cm bands

  VFO tracking:
  - IC-9700 $07 $D2 selects Main/Sub band — it is NOT a VFO A/B query.
  - FSupportsActiveVFOQuery is therefore left False.
  - On $00 transceive push the base class issues $25 $00 / $25 $01 to read
    both VFO slots explicitly.  This correctly populates the display regardless
    of which VFO is currently active, without relying on knowing the active VFO.
  - $25/$26 return FA (NG) when the radio is in satellite mode; FMainBandProcessingOnly
    demotes that NAK from Warn to Debug so it does not spam the log.

  Usage:
    radio := TIcom9700Radio.Create;
    radio.Connect;  // Opens serial or network connection
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, uFactoryRadioBase, VC, uRadioRegistry;

type
  TIcom9700Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
    procedure PollRadioState; override;
    procedure QueryActiveVFO; override;
    // IC-9700 has no XIT — manual lists only $21 $00 (RIT offset) and $21 $01 (RIT on/off)
    procedure QueryXITState; override;
    procedure XITOn(vfo: TVFO); override;
    procedure XITOff(vfo: TVFO); override;
    procedure XITClear(vfo: TVFO); override;
    procedure SetXITFreq(vfo: TVFO; hz: integer); override;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom9700Radio.Create;
begin
  inherited Create;

  // Set IC-9700 specific CI-V address
  RadioAddress := $A2;

  // Radio identification
  radioModel := 'Icom IC-9700';

  // IC-9700 CI-V transceive is at menu item $0127, not the default $0150 (IC-7610/IC-7760)
  FTransceiveMenuBytes := #$01 + #$27;

  // IC-9700 and IC-9100: $25/$26 only address the MAIN band VFOs.
  // In satellite mode the radio returns FA (NG) for these commands — mark the flag
  // so the base class logs that NAK at Debug rather than Warn.
  FMainBandProcessingOnly := True;

  // IC-9700 $07 D2 selects Main Band vs Sub Band — it is NOT a VFO A/B query.
  // VFO A and VFO B both live on the Main Band. No active-VFO tracking needed.
  FSupportsActiveVFOQuery := False;  // No usable VFO A/B selection query on IC-9700

  // IC-9700 $25/$26: $00 = selected (active) VFO, $01 = unselected VFO.
  // Mapped straight to nrVFOA (top) and nrVFOB (bottom) — selected VFO always
  // displayed on top regardless of whether it is physically VFO A or VFO B.
  // This is a known CI-V limitation: no command exists to read which VFO is active.

  logger.Info('[TIcom9700Radio.Create] Created IC-9700 radio instance with CI-V address $A2');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     MEASURED ON A LIVE RADIO, not read from a guide -- 618 consecutive scope
     frames off an IC-9700 through the RS-BA1 CI-V stream, every one 475 points
     wide, with the frame's own bounds cross-checking (centre 439.864060 MHz at
     a 500 kHz span = 1052.6 Hz per pixel).  HamLib has no spectrum caps for
     this model, so that capture is the only evidence there is.

     Worth recording precisely BECAUSE it could not be assumed: the IC-7610
     below is the counter-example, and it differs in both numbers.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(475, 160);
end;

procedure TIcom9700Radio.QueryActiveVFO;
begin
  // IC-9700 has no queryable VFO A/B selection command:
  //   Plain $07 returns FB (not supported)
  //   $07 $D2 only reports Main/Sub band selection, not VFO A/B
  // No-op — rely on transceive pushes ($07 $00/$01) if the radio sends them on VFO toggle.
end;

procedure TIcom9700Radio.PollRadioState;
begin
  // IC-9700 freq/mode are not polled — $00 and $04 transceive pushes act as
  // triggers that request $25/$26 queries for both VFOs on demand.
  // Only states that the radio never pushes need periodic polling here.
  QueryRITState;    // $21 $01 + $21 $00
  QuerySplitState;  // $0F
  QueryTXStatus;    // $1C $00
end;

procedure TIcom9700Radio.QueryXITState;
begin
  // IC-9700 has no XIT — $21 $02 returns FA (NG). No-op.
end;

procedure TIcom9700Radio.XITOn(vfo: TVFO);
begin
  // IC-9700 has no XIT. No-op.
end;

procedure TIcom9700Radio.XITOff(vfo: TVFO);
begin
  // IC-9700 has no XIT. No-op.
end;

procedure TIcom9700Radio.XITClear(vfo: TVFO);
begin
  // IC-9700 has no XIT. No-op.
end;

procedure TIcom9700Radio.SetXITFreq(vfo: TVFO; hz: integer);
begin
  // IC-9700 has no XIT. No-op.
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom9700: TFactoryRadioBase;
begin
   Result := TIcom9700Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom9700');
  RegisterRadio(IC9700,
     CreateIcom9700,
     'Icom IC-9700', [rlSerial, rlNetwork], 50001, True,
     SerialParams(38400, 8, PARITY_NONE, 1)
     ,
     3081
     , 162);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC9700);

end.
