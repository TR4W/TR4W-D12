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
unit uRadioIcom7851;
{$I ..\tr4w.inc}

{
  Icom IC-7851.

  Protocol-identical to the IC-7850 (CI-V address $8E, standard $25 VFO-B form,
  network capable, $07 $D2 Main/Sub selection).  It nevertheless derives from
  TIcomRadio directly and states its own facts, rather than descending from
  TIcom7850Radio.

  WHY NOT `class(TIcom7850Radio)` -- ONE RADIO PER CLASS, AND NEVER A MODEL AS A
  BASE.  It was written that way originally and it read as harmless: the two
  radios are the same protocol, so inheriting cost nothing and duplicated nothing.
  Three problems earned the change (NY4I):

    1. INVISIBLE BLAST RADIUS.  Editing TIcom7850Radio silently changed the
       IC-7851 too, with no signal at the edit site.  Now a change to a MODEL
       affects one radio and a change to the FAMILY BASE is explicitly a family
       change.

    2. THE TEMPLATE-COPY HAZARD.  Someone adding a new radio copies the nearest
       existing unit.  Copying a model that is also a base drags in overrides and
       trait fields the new author never reasoned about -- and it WORKS, right up
       until it does not.

    3. RESTRICTION IS NOT SPECIALIZATION.  This is the one that settles it.
       Elsewhere in the tree TYaesuFT847Radio descends from TYaesuFT817Radio and
       then has to set FHasSplit := False, FHasRIT := False,
       FModeDIGU := $FF -- flags whose ONLY purpose is to undo inherited
       behaviour the radio does not have.  A child that withdraws its parent's
       promises is not a subtype of it.  Deriving from the family base and adding
       what the radio HAS avoids needing flags to subtract what it has not.

  The cost is three restated lines below.  That is not the duplication worth
  fearing: a CI-V address and a VFO-query capability are facts about THIS radio,
  so stating them here is honest.  What belongs in the base is the universal
  material -- band edges, the radio-mode to TR4W-mode mapping, the CI-V framing.
}

interface

uses
  uRadioIcomBase, uRadioIcomModern, VC, uRadioRegistry;

type
  TIcom7851Radio = class(TIcomModernRadio)
  public
    constructor Create; reintroduce;
  end;

implementation

uses
  Log4D;

var
  logger: TLogLogger;

constructor TIcom7851Radio.Create;
begin
  inherited Create;
  RadioAddress := $8E;              // same address as the IC-7850
  radioModel := 'Icom IC-7851';
  FSupportsActiveVFOQuery := True;  // $07 $D2 Main/Sub band selection
  logger.Info('[TIcom7851Radio.Create] Created IC-7851 instance with CI-V address $8E');
   // Capabilities from LOGRADIO's RadioSupports* lists.  These say what the
   // RADIO can do; the operator's config setting says what they WANT.  Both
   // are required -- a user can enable CW-by-CAT on a radio that cannot do it.
   FCapabilities.Flags := FCapabilities.Flags + [rcCWByCAT, rcCWSpeedSync, rcPlayDVK];
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateIcom7851: TFactoryRadioBase;
begin
   Result := TIcom7851Radio.Create;
end;

initialization
  logger := TLogLogger.GetLogger('uRadioIcom7851');
  // Its OWN registry entry so a 7851 owner finds THEIR radio in the list -- a
  // 7850 standing in for both reads as "this build does not support my radio".
  // It also keeps radioModel honest, so their log and bug report say IC-7851.
  RegisterRadio(IC7851,
     CreateIcom7851,
     'Icom IC-7851', [rlSerial, rlNetwork], 50001, True,
     SerialParams(19200, 8, PARITY_NONE, 1)
     ,
     3075
     , 142);

  // This radio's NETWORK link authenticates, so the editor offers user and
  // password. ApplyNetworkCredentials on the class is what USES them; this is
  // what lets the UI ask before a radio object exists.
  MarkNetworkCredentials(IC7851);

end.
