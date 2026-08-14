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
unit uRadioIcom7850;
{$I ..\tr4w.inc}

{
  Icom IC-7850.

  The IC-7851 is protocol-identical but lives in uRadioIcom7851.pas with its own
  class deriving from TIcomRadio -- NOT from this one.  See that unit's header for
  why a model is never another model's base.

  CI-V address: 0x8E
  Controller address: 0xE0 (standard)
  Network capable: Yes
  VFO B format: Standard ($25)
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7850Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;


implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7850Radio.Create;
begin
  inherited Create;
  RadioAddress := $8E;
  radioModel := 'Icom IC-7850';
  FSupportsActiveVFOQuery := True;  // Supports $07 $D2 Main/Sub band selection
  logger.Info('[TIcom7850Radio.Create] Created IC-7850 instance with CI-V address $8E');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;


// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7850: TFactoryRadioBase;
begin
   Result := TIcom7850Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7850');
  RegisterRadio(IC7850,
     CreateIcom7850,
     'Icom IC-7850', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3075
     , 142);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC7850);

end.
