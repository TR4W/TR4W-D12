{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uBMCF;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  VC,
  TF,
  Messages,
  Windows,
  Tree,
  LogWind;

{
  THE BAND-PLAN SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uBandPlanForm.pas -- and this unit is the entry point only.

  DELETED here, not wrapped (Phase 4b): BMCFDlgProc, its nested loop building a
  static and three ES_NUMBER edits per band addressed by the computed id
  `integer(TempBand) + TempColumn * 100`, and the two gotos.  A TStringGrid
  replaces 33 controls, and adding a band to BandType no longer means the
  dialog quietly stops showing it.
}

// the band-plan editor.  Nested INSIDE the settings dialog, so its parent is
// the settings window -- see the plan's rule about converting inner before
// outer.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
//
// Phase 4b, 2026-08-19: that is exactly what happened, and no call site moved.
procedure ShowBandPlan(const aParent: HWND);

implementation

uses
  uBandPlanForm;

procedure ShowBandPlan(const aParent: HWND);
begin
   uBandPlanForm.ShowBandPlan(aParent);
end;

end.
