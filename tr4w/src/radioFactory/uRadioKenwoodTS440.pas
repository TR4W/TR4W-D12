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
unit uRadioKenwoodTS440;
{$I ..\tr4w.inc}

{
  Kenwood TS-440 (serial CAT).  A per-model subclass of TKenwoodSerial that is
  NOT quite a plain standard-Kenwood radio: its split command differs.

  SPLIT IS `SP1;` / `SP0;`, NOT `FR0;FT1;`.  The TS-440 uses the older Kenwood
  IC-10 interface, where split is its own flag rather than a consequence of the
  FR/FT (receive-VFO / transmit-VFO) relationship.  Confirmed by NY4I from the
  command reference, and independently by HamLib, which routes this radio through
  ic10.c -- `ic10_set_split_vfo` sends exactly "SP1;" or "SP0;" and nothing else.
  It is one of only three backends in HamLib's tree using IC-10 at all.

  DO NOT call the inherited Split.  TKenwoodSerial sends `FR0;FT1;` followed by
  SetActiveVFO(nrVFOA), because on a modern Kenwood that FR0 really does move the
  receive VFO.  Neither applies here: no FR is sent, so the active VFO does not
  move, and claiming it did would put the driver out of step with the radio and
  misfile the next IF frequency.

  ** THE LEGACY IS WRONG HERE AND IS DELIBERATELY LEFT WRONG. **
  RadioObject.PutRadioIntoSplit (LOGRADIO:2066) sends `FR0;FT1;` to the TS-440
  along with every other Kenwood.  NY4I confirmed that is incorrect for this
  radio.  It is not fixed there because the legacy radio path is being deleted --
  patching it would be throwaway work.  The factory is the fix.

  NOT BENCH-TESTED.

  Serial-only (default 4800 baud, set from the .cfg via the factory).  Registers
  itself so the factory + drop-down pick it up with no parallel array.
}

interface

uses
  uRadioKenwoodSerial, uFactoryRadioBase, uRadioRegistry, VC;

type
  TKenwoodTS440Radio = class(TKenwoodSerial)
  public
    constructor Create; reintroduce;
    // IC-10 split: SP1;/SP0;.  See the unit header for why this does not chain
    // to the inherited FR0;FT1; version.
    procedure Split(splitOn: boolean); override;
  end;

implementation

constructor TKenwoodTS440Radio.Create;
begin
  inherited Create;
  radioModel := 'Kenwood TS-440';
end;

procedure TKenwoodTS440Radio.Split(splitOn: boolean);
begin
  // NOT `inherited` -- the base sends FR0;FT1; and moves the active VFO.
  if splitOn then
     begin
     Self.SendToRadio('SP1;');
     end
  else
     begin
     Self.SendToRadio('SP0;');
     end;
end;

// NAMED unit-level constructors, not anonymous functions.  None of these
// captured anything, so the anonymous form bought nothing and cost a
// closure-capable compiler; TRadioCtor is a plain procedure pointer now.
function CreateKenwoodTS440: TFactoryRadioBase;
begin
   Result := TKenwoodTS440Radio.Create;
end;

initialization
  RegisterRadio(TS440,
     CreateKenwoodTS440,
     'Kenwood TS-440', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     ,
     2002
     );

end.
