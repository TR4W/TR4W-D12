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
unit uRadioIcom905;
{$I ..\tr4w.inc}

{
  Icom IC-905 Radio Implementation

  The IC-905 is a VHF/UHF/SHF transceiver.
  CI-V address: 0xAC
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom905Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom905Radio.Create;
begin
  inherited Create;
  RadioAddress := $AC;
  radioModel := 'Icom IC-905';
  // IC-905 CI-V transceive is at menu item $0142, not the default $0150 (IC-7610/IC-7760)
  FTransceiveMenuBytes := #$01 + #$42;
  logger.Info('[TIcom905Radio.Create] Created IC-905 instance with CI-V address $AC');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     PROVISIONAL.  AetherSDR lists 475/160 and marks the model unverified;
     HamLib has no spectrum caps for it.  Nobody has watched this rig stream.

     AND IT IS THE ONE MODEL WHERE THE FREQUENCY WIDTH MATTERS: the IC-905 uses
     SIX-byte frequencies above 10 GHz, and a scope header decoded with five
     misaligns by two bytes and yields a plausible-looking wrong centre.
     TIcomScopeGeometry.FreqBytes exists for that, and this radio does not set
     it yet -- so the scope is right below 10 GHz and must be re-checked above
     it.  See uIcomScope.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(475, 160);
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom905: TFactoryRadioBase;
begin
   Result := TIcom905Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom905');
  RegisterRadio(IC905,
     CreateIcom905,
     'Icom IC-905', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     0
     , 172);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC905);

end.
