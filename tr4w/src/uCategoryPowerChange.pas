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

(* WHAT A CATEGORY-POWER CHOICE DOES -- milestone M9b, 2026-10-02, design 7.6.

  NY4I, 2026-10-01: the entrant's power is ONE value and the last touch wins
  ("If they select QRP right before cabrillo generation, we have to assume
  they know what they are doing"); it may change mid-contest ("Maybe we remind
  them of that mid-contest but let it be changed").

  ONE VALUE: Settings.Contest.CategoryPower, the one scoring reads through
  TStationContext.MyPower. The New Contest dialog sets it; the Cabrillo
  summary window's CATEGORY-POWER row sets it too now, instead of a copy of
  its own in the header store (uCbrSum).

  THIS UNIT IS THE DECISION ONLY -- no form, no settings write, no rescore --
  so the rule is unit tested (uTestCategoryPower). The window does what it
  says: SetCFGCommandValue('CATEGORY-POWER', ...) -- the route every settings
  screen takes, which applies, records the statement and tells a multi-op
  peer -- then MainUnit.RescoreLog and a notice.

  THE THREE ANSWERS (DECIDED):
    unchanged        the same power, or text that is no power at all: nothing.
                     Every close of the window passes through here, and
                     re-saving what was already there must not rescore.
    set              changed, and the log has no QSOs: set it, and say
                     nothing. Nothing is scored yet, so there is no category
                     to have changed -- the same reason the New Contest dialog,
                     which only ever sets the first value, never reminds.
    set and rescore  changed with QSOs logged: set it, rescore the log through
                     the existing Rescore command, and show the reminder as a
                     NOTICE (the main window's 30-second strip) -- never a
                     modal question, because NY4I's ruling is that the change
                     is allowed; a dialog would be a block with extra steps. *)
unit uCategoryPowerChange;

{$I tr4w.inc}

interface

uses
   uSettingsModel;   (* tCategoryPower and its spellings *)

type
   TCategoryPowerChange = (cpcUnchanged, cpcSet, cpcSetAndRescore);

(* aChosen is what the window's row shows; aLoggedQSOs, how many QSOs the log
  holds. aNewPower is the power to set, meaningful unless cpcUnchanged. *)
function DecideCategoryPowerChange(aCurrent: tCategoryPower;
                                   const aChosen: string;
                                   aLoggedQSOs: integer;
                                   out aNewPower: tCategoryPower): TCategoryPowerChange;

implementation

uses
   SysUtils;

function DecideCategoryPowerChange(aCurrent: tCategoryPower;
                                   const aChosen: string;
                                   aLoggedQSOs: integer;
                                   out aNewPower: tCategoryPower): TCategoryPowerChange;
var
   p: tCategoryPower;
   found: boolean;
begin
   aNewPower := aCurrent;
   Result := cpcUnchanged;

   (* BY THE SPELLINGS THE ROW OFFERS -- tCategoryPowerSA, the table it is
     filled from. Anything else (an empty row) changes nothing. *)
   found := False;
   for p := Low(tCategoryPower) to High(tCategoryPower) do
      begin
      (* UnicodeSameText, NOT SameText: SysUtils' plain name takes
         AnsiString and this unit's string is UnicodeString. *)
      if UnicodeSameText(Trim(aChosen), tCategoryPowerSA[p]) then
         begin
         aNewPower := p;
         found := True;
         Break;
         end;
      end;

   if (not found) or (aNewPower = aCurrent) then
      begin
      aNewPower := aCurrent;
      Exit;
      end;

   if aLoggedQSOs > 0 then
      begin
      Result := cpcSetAndRescore;
      end
   else
      begin
      Result := cpcSet;
      end;
end;

end.
