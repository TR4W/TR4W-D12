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

(* THE BAND MAP OR THE DUPE SHEET, CHOSEN BY CATEGORY-ASSISTED -- issue 201
  (TR4W/TR4W#1077, N4AF).

  NY4I, 2026-11-15: "if the operator class (in the cabrillo fields) is
  NON-ASSISTED, then we select the DUPESHEET since we do not use the bandmap
  unassisted." An ASSISTED entry gets the band map.

  WHEN: ONLY WHEN A CONTEST IS OPENED. MainUnit.RestoreToolWindows asks this
  once, before it replays the saved layout, so the chosen window opens with
  the rest. File > Open Log is a relaunch (issue 218), so it is an open too.
  A CATEGORY-ASSISTED change mid-contest (the Cabrillo summary window,
  Preferences) does NOT move a window.

  THE CHOSEN WINDOW IS OPENED; THE OTHER IS NOT CLOSED. Either can still be
  opened or closed by hand, and N4AF's request names operators who keep a
  band map without spots. A saved layout that had the other window open keeps
  it open.

  UNSET CHOOSES NOTHING: the category was left blank, so the saved layout
  stands as it always has.

  THIS UNIT IS THE DECISION ONLY -- no form, no window table -- so the rule
  is unit tested (uTestContestUI). *)
unit uCategoryWindow;

{$I tr4w.inc}

interface

uses
   VC,               (* WindowsType *)
   uSettingsModel;   (* tCategoryAssisted *)

(* THE WINDOW A CONTEST OPENS WITH FOR aAssisted: True with aWindow the dupe
  sheet for NON-ASSISTED and the band map for ASSISTED; False for UNSET, with
  aWindow set to the band map, meaning nothing. *)
function CategoryOpeningWindow(aAssisted: tCategoryAssisted;
                               out aWindow: WindowsType): boolean;

implementation

function CategoryOpeningWindow(aAssisted: tCategoryAssisted;
                               out aWindow: WindowsType): boolean;
begin
   aWindow := tw_BANDMAPWINDOW_INDEX;
   Result := True;
   case aAssisted of
      caNONASSISTED:
         begin
         (* Window 1 -- the dupe sheet the Windows menu opens. Window 2 is
            the second radio's. *)
         aWindow := tw_DUPESHEETWINDOW1_INDEX;
         end;
      caASSISTED:
         begin
         aWindow := tw_BANDMAPWINDOW_INDEX;
         end;
   else
      begin
      Result := False;
      end;
   end;
end;

end.
