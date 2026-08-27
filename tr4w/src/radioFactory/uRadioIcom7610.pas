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
unit uRadioIcom7610;
{$I ..\tr4w.inc}

{
  Icom IC-7610 Radio Implementation

  The IC-7610 is an HF/50MHz SDR transceiver that uses the CI-V protocol.
  CI-V address: 0x98

  Features:
  - Full CI-V command support via TIcomRadio base class
  - Polling-based operation (no auto-info mode like K4)
  - Standard polling interval: 100ms
  - Dual receivers (Main/Sub)
  - Supports all HF bands plus 6 meters

  Usage:
    radio := TIcom7610Radio.Create;
    radio.Connect;  // Opens serial or network connection
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7610Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7610Radio.Create;
begin
  inherited Create;

  // Set IC-7610 specific CI-V address
  RadioAddress := $98;

  // Radio identification
  radioModel := 'Icom IC-7610';
  FSupportsActiveVFOQuery := True;  // Supports $07 $D2 Main/Sub band selection

  logger.Info('[TIcom7610Radio.Create] Created IC-7610 radio instance with CI-V address $98');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     689 POINTS AND 0..200 -- BOTH different from the IC-7300 family, which is
     the whole reason geometry is per-model data and not a constant.  HamLib
     publishes it (rigs/icom/ic7610.c: 689 / 200 / -100..0 dBm) and AetherSDR
     carries the same numbers; NEITHER has verified them against this model's
     own CI-V guide, so this is two agreeing secondary sources rather than a
     primary one.

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(689, 200);
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7610: TFactoryRadioBase;
begin
   Result := TIcom7610Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7610');
  RegisterRadio(IC7610,
     CreateIcom7610,
     'Icom IC-7610', [rlSerial, rlNetwork], 50001, True,
     SerialParams(9600, 8, PARITY_NONE, 1)
     ,
     3078
     , 152);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC7610);

end.
