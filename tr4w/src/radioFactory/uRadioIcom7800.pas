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
unit uRadioIcom7800;

{
  Icom IC-7800 -- CI-V address $6A.

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
  TIcom7800Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses Log4D;

var
  logger: TLogLogger;

constructor TIcom7800Radio.Create;
begin
  inherited Create;
  RadioAddress := $6A;
  radioModel := 'Icom IC-7800';
  logger.Info('[TIcom7800Radio.Create] Created IC-7800 instance with CI-V address $6A');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync];
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7800');
  RegisterRadio(IC7800,
     function: TFactoryRadioBase begin Result := TIcom7800Radio.Create end,
     'Icom IC-7800', [rlSerial], 0, False,
     SerialParams(9600, 8, PARITY_NONE, 1)
     );

end.
