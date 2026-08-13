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
unit uRadioIcom7700;
{$I ..\tr4w.inc}

{
  Icom IC-7700 -- CI-V address $74.

  One of only TWO radios in this migration batch that get the FULL Icom profile
  rather than the read-limited one.  That is not a guess from the model number:
  LOGRADIO's IcomRadiosThatSupportRIT and IcomRadiosThatSupportVFOB both list
  IC7700 and IC7800, and no other unmigrated CI-V model appears in either set.
  Those sets were built from bench work over years, so they decide it.

  Full profile means the inherited TIcomRadio behaviour: $25/$26 VFO-B frequency
  and mode reads, $21 RIT read, $0F split read, $1C TX status -- all the things
  uRadioIcomLegacy has to no-op for the older radios.

  SERIAL ONLY.  These predate Icom's LAN control (the RS-BA generation covered by
  uIcomNetworkTransport), so unlike the IC-7610/7850/9700/705 there is no network
  link to register.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES: confirm the four reads above actually answer rather than NAK.  If
  any of them NAKs, this radio belongs on the read-limited profile for that
  command instead -- which is a capability change, not a protocol rewrite.
}

interface

uses uFactoryRadioBase, uRadioIcomBase, uRadioIcomModern, uRadioRegistry, VC;

type
  TIcom7700Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses Log4D;

var
  logger: TLogLogger;

constructor TIcom7700Radio.Create;
begin
  inherited Create;
  RadioAddress := $74;
  radioModel := 'Icom IC-7700';
  logger.Info('[TIcom7700Radio.Create] Created IC-7700 instance with CI-V address $74');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7700: TFactoryRadioBase;
begin
   Result := TIcom7700Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7700');
  RegisterRadio(IC7700,
     CreateIcom7700,
     'Icom IC-7700', [rlSerial], 0, False,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3062
     , 116);

end.
