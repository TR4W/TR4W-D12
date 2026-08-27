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
unit uRadioIcom7760;
{$I ..\tr4w.inc}

{
  Icom IC-7760 Radio Implementation

  The IC-7760 has several protocol differences from standard Icom radios:
    - CI-V address: 0xB2
    - Controller address: 0xE1 (NOT the typical 0xE0)
    - VFO B commands use $25/$26 extended format (FSupportsExtendedVFOBCommands = True,
      which is the base class default — no override needed)
    - Shared RIT/XIT offset (single offset for both)
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7760Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7760Radio.Create;
begin
  inherited Create;
  RadioAddress := $B2;
  ControllerAddress := $E1;  // NOT the typical $E0
  radioModel := 'Icom IC-7760';
  FSupportsActiveVFOQuery := True;  // IC-7760 supports $07 $D2 to read active VFO
  logger.Info('[TIcom7760Radio.Create] Created IC-7760 instance, CI-V=$B2, Controller=$E1');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK, rcSpectrum];

   { THE BANDSCOPE GEOMETRY.  Declared HERE because it is a per-model hardware
     fact that nothing else the radio says implies -- see
     TIcomRadio.DeclareScopeGeometry for why it is not in TRadioCapabilities.

     MEASURED ON THE RADIO, 2026-08-26, AND IT IS THE ONLY SOURCE THERE IS.
     HamLib carries no spectrum caps for the IC-7760 and AetherSDR's model
     table does not list it, so nothing published anywhere states this
     geometry.  It was read off NY4I's rig with
     tr4w/test/bench/bench_icomscope.dpr:

       LAN payload            704 bytes  =  15-byte header + 689 levels
       points                 689
       scope ids seen         0 only
       divisions              1 of 1     (whole sweep in one frame, as LAN does)
       mode                   00 = centre
       header cross-check     centre 1.816195 MHz, span +/-2.5 kHz -- which is
                              where the rig was tuned and what it displayed

     SO IT IS A 689-POINT RADIO, like the IC-7610 and the IC-785x, and NOT the
     475 the rest of the family uses.  The first run declared 475 and the bench
     REFUSED it -- "this radio sends 689 points, not 475" -- which is the whole
     reason that check exists.

     THE LEVEL RANGE IS INFERRED, NOT MEASURED.  Every sample in the capture
     was zero (the rig's scope was not showing signal), so the bench could only
     report a lower bound of 0.  200 is taken from the fact that both other
     689-point radios use it in both HamLib and AetherSDR -- a pairing, not an
     observation.  Re-run the bench with the scope live to settle it; the
     number to watch is "highest level seen".

     rcSpectrum above says the MODEL has a scope; whether THIS connection can
     deliver it is SpectrumAvailable's question, and it answers no on a serial
     link until someone has watched the divided path work. }
   DeclareScopeGeometry(689, 200);
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7760: TFactoryRadioBase;
begin
   Result := TIcom7760Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7760');
  RegisterRadio(IC7760,
     CreateIcom7760,
     'Icom IC-7760', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3092
     , 178);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC7760);

end.
