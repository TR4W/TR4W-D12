(*
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
 *)
unit uSettingsEffects;
{$I tr4w.inc}

(*
  WHAT HAS TO HAPPEN ON SCREEN WHEN A SETTING CHANGES.

  ------------------------------------------------------------------------
  THIS UNIT IS THE REPLACEMENT FOR crP
  ------------------------------------------------------------------------

  Thirty CFGCA rows carry `crP`, an index into CommandsProcArray, and uCFG's
  own note is blunt about what it is for: the handler is "the ONLY thing that
  repaints for a changed setting".  Without it a setting takes effect at the
  next restart -- AUTO SEND CHARACTER COUNT is the worked example, where the
  arrow beside the call sign field appeared only after one (NY4I, 2026-08-21).

  NY4I, 2026-09-11: *"a property setter can do the side effect, which is better
  than a hook index."*  That is the design, and this unit is the other half of
  it: TSettingsGroup's setters RAISE the change, and this subscribes.

  ------------------------------------------------------------------------
  WHY THIS IS NOT JUST CommandsProcArray WEARING A HAT
  ------------------------------------------------------------------------

  The objection is fair on its face -- a table of settings to side effects has
  been replaced by a routine that branches on settings and does side effects.
  Three things are genuinely different, and each was a real defect class:

  1. IT CANNOT POINT AT THE WRONG HANDLER.  `crP: 1` and `crA: 23` are integers
     typed by hand into a 508-row table, and a wrong one compiles.  That has
     happened: EXTERNAL LOGGER ENABLED carried crA: 23, the WSJT-X
     colorization hook.  A path is a string derived from the property itself.

  2. IT FIRES HOWEVER THE VALUE WAS SET.  The crP handler ran only when
     CheckCommand applied the row, so a config file repainted and a menu
     toggle did not -- which is exactly why the band map form grew its own
     ToggleAndRepaint helper, hand-writing the repaint the table would have
     done.  Two spellings of one rule, and they can disagree.  A setter has
     one.

  3. IT IS ONE PLACE, AND IT NAMES WHAT IT DOES.  `crP: 1` is a number whose
     meaning is in another file.

  ------------------------------------------------------------------------
  THE RULE FOR ADDING TO IT
  ------------------------------------------------------------------------

  MATCH A GROUP, NOT A SETTING, wherever the whole group shares one effect.
  All eight band map filters redraw the band map, so the arm below tests the
  prefix and there are no eight cases to keep in step with eight properties.
  Reach for an exact path only where one setting in a group genuinely differs.

  AND NOTHING HERE MAY ASSUME ITS WINDOW EXISTS.  Every seam this unit calls is
  a procedure variable that is nil until the form opens, so a setting changed
  with the band map closed is a no-op rather than a fault.  That is not
  defensive coding: config load happens before any window is created.
*)

interface

(* Subscribe to the settings model.  Called once, from the startup sequence in
  uProgramMain, AFTER the settings are loaded -- assigning it earlier would
  repaint for every value the load assigns, against windows that do not exist
  yet. *)
procedure InstallSettingsEffects;

implementation

uses
   SysUtils,
   uSettingsModel,
   uBandMapView;   // BandMapRefresh -- the band map's own view seam

const
   (* The property path prefix that names a group.  Spelled once, here, and
     compared with the dot attached so a future group called 'BandMapExtra'
     cannot match it by accident. *)
   BAND_MAP = 'BandMap.';

   (* HF / VHF / WARC.  These reach the band map too -- two of the three
     carried the same crP: 1 -- but they are not display filters, so they are
     their own group and get their own arm rather than being folded in. *)
   BANDS = 'Bands.';


function InGroup(const aPath, aPrefix: string): boolean;
begin
   (* Case-insensitive: a path is built from Pascal identifiers, and Pascal
     does not distinguish their case.

     UnicodeSameText, NOT SameText.  This unit compiles with String =
     UnicodeString and SysUtils.SameText takes AnsiString, so the plain name
     narrows BOTH arguments at the call -- two of the conversions the build
     counts, for a comparison of two ASCII identifiers that can never lose a
     character.  Harmless here and still worth spelling correctly: the ceiling
     is a ratchet, and a conversion admitted because "this one is fine" is how
     it stops meaning anything. *)
   Result := UnicodeSameText(Copy(aPath, 1, Length(aPrefix)), aPrefix);
end;


procedure SettingChanged(const aPath: string);
begin
   if InGroup(aPath, BAND_MAP) or InGroup(aPath, BANDS) then
      begin
      (* A VIEW change: the filter moved, the list of spots did not.  The form
        coalesces these, so calling it per property is not per-frame work even
        when a whole group is assigned at once. *)
      if Assigned(BandMapRefresh) then
         begin
         BandMapRefresh;
         end;
      end;
end;


procedure InstallSettingsEffects;
begin
   Settings.OnChanged := @SettingChanged;
end;

end.
