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
unit uRadioIcomLegacy;

{
  Older / minimal-CI-V Icom radios (factory).

  TIcomLegacyRadio is the shared FAMILY BASE for the older Icoms whose CI-V command
  set omits the modern extras -- the conservative profile the IC-718 bench-proved
  (no data mode, no $25/$26 VFO-B, split set-only, mode-only set-mode, $03 keep-alive),
  minus the 718's one quirk (6..60 wpm CW keyer; these keep the base 6..48).  It is
  NOT registered directly; each model is its OWN thin subclass (one class per radio,
  per NY4I's clarity preference) that sets only its CI-V address + display name and
  inherits the minimal capability set.  A model a tester shows to deviate GRADUATES
  by overriding DefineCapabilities in its own class.  This mirrors the Kenwood
  (TKenwoodSerial) and Elecraft (TElecraftSerial) family-base + per-model pattern.

  Capability profile (declared once in TIcomLegacyRadio.DefineCapabilities):
    Flags = []  -> no VFO-B read, no RIT read, split set-only, no TX-status read,
                   no data mode ($1A06; RTTY is a first-class mode byte).
    CW keyer 6..48 wpm.
  CI-V mechanics (the "how"): FDirectFreqRoute (no $07 $D2), FModeSetIncludesFilter
  False ($06 mode byte only).  Only the active-VFO frequency ($03) is readable, so
  PollRadioState polls it as the keep-alive (liveness + serial power-cycle recovery).

  FIRST BATCH (hardware behind them -- NY4I testers IC-706 / IC-7000):
  IC-706, IC-706MkII, IC-706MkIIG, IC-7000.  IC-7000 capabilities confirmed by NY4I:
  no USB-D data mode (RTTY only), split set-only, no $25/$26 -> the minimal profile.
  The remaining Group-A siblings (IC-78/707/725/726/728/729/736/737/738/746/756/761/
  765/781/910/970D) fan out as more subclasses here once these validate; the VFO-B-
  capable IC-7700/IC-7800 are MODERN-profile (subclass TIcomRadio, not this base) and
  wait on hardware.  See [[radio-capability-model]].
}

interface

uses
  uRadioIcomBase, uFactoryRadioBase, VC, uRadioRegistry;

type
  // Shared minimal-Icom family base (not registered directly -- see the models below).
  TIcomLegacyRadio = class(TIcomRadio)
  protected
    procedure DefineCapabilities; override;
    // The active-VFO frequency ($03) is the only readable dynamic state; VFO B reads
    // ($25/$26) NAK, so no-op them to keep the CI-V bus clean (same as the IC-718).
    procedure QueryVFOAFrequency; override;
    procedure QueryVFOBFrequency; override;
    procedure QueryVFOBMode; override;
  public
    constructor Create; reintroduce;
    procedure PollRadioState; override;
  end;

  // ---- One class per radio: identity (CI-V address + name) only; caps inherited. ----
  TIcom706Radio = class(TIcomLegacyRadio)
  public
    constructor Create; reintroduce;
  end;

  TIcom706MkIIRadio = class(TIcomLegacyRadio)
  public
    constructor Create; reintroduce;
  end;

  TIcom706MkIIGRadio = class(TIcomLegacyRadio)
  public
    constructor Create; reintroduce;
  end;

  TIcom7000Radio = class(TIcomLegacyRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

// ---- Family base --------------------------------------------------------------
constructor TIcomLegacyRadio.Create;
begin
  inherited Create;
  radioModel := 'Icom (legacy CI-V)';     // each model subclass overrides this
  // ---- CI-V mechanics ("how"; capabilities are declared in DefineCapabilities). ----
  FDirectFreqRoute := True;                // no $07 $D2 active-VFO query
  FModeSetIncludesFilter := False;         // set-mode $06 takes the mode byte only
end;

procedure TIcomLegacyRadio.DefineCapabilities;
begin
  // Conservative minimal profile (see unit header): no VFO-B read ($25/$26), no RIT
  // read, split SET-ONLY, no TX-status read, no data mode ($1A06; RTTY is a mode byte).
  FCapabilities.Flags := [];
  FCapabilities.CWSpeedMin := 6;
  FCapabilities.CWSpeedMax := 48;
end;

procedure TIcomLegacyRadio.QueryVFOAFrequency;
begin
  // No $25 VFO-freq read -- read the ACTIVE VFO's frequency via $03.
  SendToRadio(BuildCIVCommand($03, ''));
end;

procedure TIcomLegacyRadio.QueryVFOBFrequency;
begin
  // Cannot read VFO B ($25 $01 NAKs) -- no-op, do not touch the bus.
end;

procedure TIcomLegacyRadio.QueryVFOBMode;
begin
  // Cannot read VFO B mode ($26 $01 NAKs) -- no-op.
end;

procedure TIcomLegacyRadio.PollRadioState;
begin
  // Slow state ($21 RIT, $0F split, $1C TX, $07 $D2 active-VFO) all NAK, so the only
  // readable dynamic state is the active-VFO frequency ($03).  Poll THAT as the
  // keep-alive: refreshes freq and stamps the liveness timestamp.  Mode rides $01.
  SendToRadio(BuildCIVCommand($03, ''));
end;

// ---- Per-model classes (identity only) ----------------------------------------
constructor TIcom706Radio.Create;
begin
  inherited Create;
  RadioAddress := $48;
  radioModel := 'Icom IC-706';
end;

constructor TIcom706MkIIRadio.Create;
begin
  inherited Create;
  RadioAddress := $4E;
  radioModel := 'Icom IC-706MkII';
end;

constructor TIcom706MkIIGRadio.Create;
begin
  inherited Create;
  RadioAddress := $58;
  radioModel := 'Icom IC-706MkIIG';
end;

constructor TIcom7000Radio.Create;
begin
  inherited Create;
  RadioAddress := $70;
  radioModel := 'Icom IC-7000';
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcomLegacy');

  RegisterRadio(IC706,
     function: TFactoryRadioBase begin Result := TIcom706Radio.Create end,
     'Icom IC-706', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     ,
     3009
     , 72);
  RegisterRadio(IC706II,
     function: TFactoryRadioBase begin Result := TIcom706MkIIRadio.Create end,
     'Icom IC-706MkII', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     ,
     3010
     , 78);
  RegisterRadio(IC706IIG,
     function: TFactoryRadioBase begin Result := TIcom706MkIIGRadio.Create end,
     'Icom IC-706MkIIG', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     ,
     3011
     , 88);
  RegisterRadio(IC7000,
     function: TFactoryRadioBase begin Result := TIcom7000Radio.Create end,
     'Icom IC-7000', [rlSerial], 0, False,
     SerialParams(9600, 8, PARITY_NONE, 1)
     ,
     3060
     , 112);

end.
