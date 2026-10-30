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

(* WHICH SPELLING A CATEGORY ROW NOW CHOOSES, OR -1 FOR "NO CHANGE" -- Q61.

  aSpellings is the category's spelling table (tCategoryAssistedSA and the
  rest), aCurrent the ordinal of the value in force, aChosen what the row
  shows. The index of the chosen spelling, matched without case or spaces;
  -1 when the text is no spelling at all (one of ERMAK's extra values such as
  MULTI-OP-2, which no setting can hold) or is the value already in force --
  so closing the window re-saves nothing and makes no statement the operator
  did not make.

  EMPTY TEXT IS A SPELLING NOW, NOT "NO CHANGE" (2026-10-29): it is the
  *UNSET member's, the blank "no category" choice, so '' answers that
  member's index. A row with NOTHING selected must therefore not be asked --
  the summary window checks the row's item index first.

  ASSISTED, BAND, MODE and OPERATOR use this alone: none of them changes a
  QSO's points, so a change is a set and never a rescore. (MODE does change
  Washington Salmon Run's W7DX bonus, but that bonus is computed from the
  setting each time the total is, not stored per QSO.) POWER rescores, which
  is DecideCategoryPowerChange, built on this. *)
function CategoryChoiceIndex(const aSpellings: array of string;
                             aCurrent: integer;
                             const aChosen: string): integer;

implementation

uses
   SysUtils;

function DecideCategoryPowerChange(aCurrent: tCategoryPower;
                                   const aChosen: string;
                                   aLoggedQSOs: integer;
                                   out aNewPower: tCategoryPower): TCategoryPowerChange;
var
   idx: integer;
begin
   aNewPower := aCurrent;
   Result := cpcUnchanged;

   (* BY THE SPELLINGS THE ROW OFFERS -- tCategoryPowerSA, the table it is
     filled from. Anything else changes nothing; '' is cpUNSET's spelling,
     so an empty row chooses "no power stated" (scored as each contest's
     own "no power indicated" rule -- every power case falls to HIGH). *)
   idx := CategoryChoiceIndex(tCategoryPowerSA, Ord(aCurrent), aChosen);
   if idx < 0 then
      begin
      Exit;
      end;
   aNewPower := tCategoryPower(idx);

   if aLoggedQSOs > 0 then
      begin
      Result := cpcSetAndRescore;
      end
   else
      begin
      Result := cpcSet;
      end;
end;

function CategoryChoiceIndex(const aSpellings: array of string;
                             aCurrent: integer;
                             const aChosen: string): integer;
var
   i: integer;
begin
   Result := -1;
   for i := 0 to High(aSpellings) do
      begin
      (* UnicodeSameText, NOT SameText: SysUtils' plain name takes
         AnsiString and this unit's string is UnicodeString. *)
      if UnicodeSameText(Trim(aChosen), aSpellings[i]) then
         begin
         if i <> aCurrent then
            begin
            Result := i;
            end;
         Exit;
         end;
      end;
end;

end.
