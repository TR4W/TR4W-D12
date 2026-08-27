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
unit uRadioIcom705;
{$I ..\tr4w.inc}

{
  Icom IC-705 Radio Implementation

  The IC-705 is a portable HF/VHF/UHF all-mode transceiver with WiFi/USB.
  CI-V address: 0xA4
  Controller address: 0xE0 (standard)
  Network capable: Yes (WiFi or Ethernet via USB)
  VFO B format: Standard ($25)

  Supported bands: 160m-6m (HF), 2m, 70cm.
  Does NOT support 4m (70 MHz band). ToggleBand skips rb4m to avoid sending
  a frequency the radio will reject (leaving the display out of sync).
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, uFactoryRadioBase, uRadioBand, VC, uRadioRegistry;

type
  TIcom705Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
    function ToggleBand(vfo: TVFO = nrVFOA): TRadioBand; override;
  end;

implementation

uses
  SysUtils, Log4D;

var
  logger: TLogLogger;

constructor TIcom705Radio.Create;
begin
  inherited Create;
  RadioAddress := $A4;
  radioModel := 'Icom IC-705';
  // IC-705 CI-V transceive is at menu item $0131, not the default $0150 (IC-7610/IC-7760)
  FTransceiveMenuBytes := #$01 + #$31;
  logger.Info('[TIcom705Radio.Create] Created IC-705 instance with CI-V address $A4');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     TIER 1 -- confirmed against Icom's own IC-705 CI-V Reference Guide, which
     is the only Icom scope geometry anyone has verified that way (AetherSDR
     records it as its single `verified` model).  HamLib carries no spectrum
     caps for this radio at all.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(475, 160);
end;

function TIcom705Radio.ToggleBand(vfo: TVFO = nrVFOA): TRadioBand;
var
  currentBand: TRadioBand;
  nextBand: TRadioBand;
begin
  currentBand := Self.vfo[vfo].Band;

  // IC-705 supports: 160m-6m (HF), 2m, 70cm. No 4m (70 MHz).
  // Skip rb4m in the cycle to avoid sending a frequency the radio rejects.
  case currentBand of
    rbNone, rb160m: nextBand := rb80m;
    rb80m:  nextBand := rb60m;
    rb60m:  nextBand := rb40m;
    rb40m:  nextBand := rb30m;
    rb30m:  nextBand := rb20m;
    rb20m:  nextBand := rb17m;
    rb17m:  nextBand := rb15m;
    rb15m:  nextBand := rb12m;
    rb12m:  nextBand := rb10m;
    rb10m:  nextBand := rb6m;
    rb6m:   nextBand := rb2m;   // Skip rb4m — IC-705 has no 4m band
    rb4m:   nextBand := rb2m;   // If somehow on rb4m, step to 2m
    rb2m:   nextBand := rb70cm;
    rb70cm: nextBand := rb160m;
  else
    nextBand := rb20m;
  end;

  SetBand(nextBand, vfo);
  logger.debug('[TIcom705Radio.ToggleBand] %s -> %s (skipping 4m)',
    [IntToStr(Ord(currentBand)), IntToStr(Ord(nextBand))]);
  Result := nextBand;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom705: TFactoryRadioBase;
begin
   Result := TIcom705Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom705');
  RegisterRadio(IC705,
     CreateIcom705,
     'Icom IC-705', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3085
     , 164);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC705);

end.
