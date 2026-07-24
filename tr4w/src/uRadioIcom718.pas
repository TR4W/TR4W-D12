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
unit uRadioIcom718;

{
  Icom IC-718 Radio Implementation (factory)

  The IC-718 is a basic HF transceiver, serial CI-V only, default CI-V address
  0x5E. It is a MINIMAL Icom -- its CI-V COMMAND SET (not the CI-V protocol) omits
  a lot the modern factory base assumes:
    - no data mode        ($1A 06 is not in its command set -> SupportsDataMode False)
    - no $25/$26          extended VFO commands (FSupportsExtendedVFOBCommands False)
    - no $07 $D2          active-VFO query (FDirectFreqRoute True, like the IC-7100)
    - split/TX are        SET-ONLY ($0F/$1C reads NAK) and RIT ($21) is not readable
                          -> the only readable dynamic state is freq ($03), which
                             PollRadioState polls as a keep-alive (see there)
    - set-mode $06        takes the mode byte ONLY, no trailing filter byte
    - CW keyer range      is 6..60 wpm (the modern default is 6..48)
  Frequency and mode arrive via CI-V transceive pushes ($00/$01), which the 718
  does emit. Split/TX/RIT display are hard radio limits, same as the legacy path.
}

interface

uses
  uRadioIcomBase, VC, uRadioRegistry;

type
  TIcom718Radio = class(TIcomRadio)
  protected
    function SupportsDataMode: Boolean; override;
    // The 718 has no $25/$26 extended-VFO commands (the base sends them from the
    // first-message init query + $00/$04 handlers). Override the VFO queries to
    // speak the 718's dialect: read the ACTIVE VFO's freq via $03, and no-op the
    // VFO-B reads it cannot do -- otherwise it NAKs them, colliding the CI-V bus.
    procedure QueryVFOAFrequency; override;
    procedure QueryVFOBFrequency; override;
    procedure QueryVFOBMode; override;
  public
    constructor Create; reintroduce;
    procedure PollRadioState; override;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom718Radio.Create;
begin
  inherited Create;
  RadioAddress := $5E;                    // IC-718 default CI-V address
  radioModel := 'Icom IC-718';
  // No $07 $D2 active-VFO query -- route the $00 transceive frequency push
  // straight to the active VFO (same as the IC-7100/IC-9700).
  FDirectFreqRoute := True;
  // No $25/$26 extended VFO commands -- disable them so the base does not fire
  // $25/$26 VFO-B queries (which the 718 NAKs) off its mode responses.
  FSupportsExtendedVFOBCommands := False;
  // Set-mode ($06) takes the mode byte only; a trailing filter byte -> NAK.
  FModeSetIncludesFilter := False;
  // CW keyer speed range is 6..60 wpm (the modern default of 6..48 is too fast).
  FCWSpeedMax := 60;
  // Split is SET-ONLY on the 718 ($0F read NAKs, no $0F transceive push), so the
  // radio never reports split back. Track the commanded state locally in Split()
  // -- otherwise CurrentStatus.Split never flips and the "You are in SPLIT MODE"
  // warning never appears.
  FSplitStateReadable := False;
  logger.Info('[TIcom718Radio.Create] Created IC-718 instance with CI-V address $5E');
end;

function TIcom718Radio.SupportsDataMode: Boolean;
begin
  // The IC-718 has no $1A 06 data-mode command -- it NAKs it. Returning False
  // disables every data-mode send AND parse in the base (the $1A06 send in
  // SetMode and the $04 handler, and the $1A06 parse, are all gated on this).
  Result := False;
end;

procedure TIcom718Radio.PollRadioState;
begin
  // The 718 emits nothing on its own between VFO changes, so with NO poll its
  // liveness times out (radio window goes magenta) the moment the operator stops
  // tuning, then recovers on the next transceive push. Its slow state ($21 RIT,
  // $0F split, $1C TX, $07 $D2 active-VFO) all NAK, so its ONLY readable dynamic
  // state is the active-VFO frequency ($03). Poll THAT, and only that, as a
  // keep-alive: one command per cycle refreshes freq and stamps the liveness
  // timestamp (UpdateLastValidResponse) on the reply. Mode is deliberately NOT
  // polled -- it rides the $01 transceive push (on change) plus the one-time init
  // query. Polling $04 would only add bus traffic and, on a collision, mis-decode
  // to rmNone -- the old 40NON<->40CW flicker. (Collisions are now discarded by the
  // preamble-resync guard in TIcomRadio.ProcessCIVMessage, so a raced $03 reply is
  // dropped, not turned into a garbage frequency.)
  SendToRadio(BuildCIVCommand($03, ''));
end;

procedure TIcom718Radio.QueryVFOAFrequency;
begin
  // No $25 VFO-freq read on the 718 -- read the ACTIVE VFO's frequency via $03.
  SendToRadio(BuildCIVCommand($03, ''));
end;

procedure TIcom718Radio.QueryVFOBFrequency;
begin
  // The 718 cannot read VFO B ($25 $01 NAKs) -- no-op, do not touch the bus.
end;

procedure TIcom718Radio.QueryVFOBMode;
begin
  // The 718 cannot read VFO B mode ($26 $01 NAKs) -- no-op.
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom718');
  RegisterRadio(IC718,
     function: TNetRadioBase begin Result := TIcom718Radio.Create end,
     'Icom IC-718', [rlSerial], 0, False);

end.
