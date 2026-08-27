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
unit uRadioIcom7300MK2;
{$I ..\tr4w.inc}

{
  Icom IC-7300MK2 Radio Implementation

  The IC-7300MK2 is the network-capable version of the IC-7300.
  CI-V address: 0xB6 (Icom factory default)
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)

  Note: The original IC-7300 uses CI-V $94 and is serial-only (not network capable).
  Some users change their IC-7300MK2 CI-V address to $94 for compatibility with
  software that only knows the IC-7300. The transport-reported address (from the
  capabilities handshake) always overrides this class default at connect time, so
  both factory-default ($B6) and user-customised ($94 or other) configurations work.
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7300MK2Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7300MK2Radio.Create;
begin
  inherited Create;
  RadioAddress := $B6;
  radioModel := 'Icom IC-7300MK2';
  // IC-7300MK2 CI-V transceive is at menu item $0089, not the default $0150 (IC-7610/IC-7760)
  FTransceiveMenuBytes := #$00 + #$89;
  logger.Info('[TIcom7300MK2Radio.Create] Created IC-7300MK2 instance with CI-V address $B6');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     TIER 1 -- confirmed against Icom's own IC-7300MK2 CI-V Reference Guide.
     That guide states the LAN data length as 490 bytes, which independently
     confirms the 15-byte header this decoder computes: 15 + 475 = 490.  Its
     own words for the two transports are "it is sent all at once" over LAN and
     "divided into 11 segments" over USB.  HamLib's five IC-7300-family rows
     agree on 475/160.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(475, 160);
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7300MK2: TFactoryRadioBase;
begin
   Result := TIcom7300MK2Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7300MK2');
  RegisterRadio(IC7300MK2,
     CreateIcom7300MK2,
     'Icom IC-7300MK2', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     0
     , 182);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC7300MK2);

end.
