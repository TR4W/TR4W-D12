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

{ THE SUPER CHECK PARTIAL WINDOW -- what the rest of the program says to it.

  MasterDlgProc IS GONE; the window is uMasterForm.  This unit stays because it
  is the surface LOGEDIT, MainUnit and the Alt-D form already call, and turning
  three callers into direct users of a form would spread the conversion for no
  gain.  Where each arm of the dialog procedure went:

    WM_INITDIALOG   -> MasterWindowShown, through the form's OnShow seam.  It
                       also built the list box and set its font and column
                       width; those are the .lfm and TCallGrid's cell size.
    WM_DRAWITEM     -> TfrmMaster.MasterDrawCell.
    WM_SIZE         -> Align = alClient plus TCallGrid.LayOut.  Its other job
                       was recomputing MaxItemsInMasterListBox from a
                       GetWindowRect; that is TCallGrid.Capacity, asked rather
                       than cached.
    WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE -> DefTR4WProc.  Not reproduced, as
                       with the stations window and the dupe sheet.
    WM_CLOSE        -> TfrmMaster.HandleClose.

  FOUR GLOBALS GO WITH IT.  MasterListBox was doing two jobs -- the write target
  and the is-it-open flag -- and MaxItemsInMasterListBox / ItemsInMasterListBox
  were a cached capacity and a running count that only agreed with the control
  because one procedure kept them in step.  masterrect was scratch. }
unit uMaster;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  VC;

{ Is the window open?  Was `MasterListBox = 0`, which meant "the handle the
  dialog stored for its list box", i.e. the same question asked of a variable
  that had to be cleared by hand in WM_CLOSE. }
function  MasterWindowOpen: boolean;

procedure ClearMasterListBox;

{ Adds one partial match.  Returns False when the window is full -- the caller
  stops, which is what DisplaySCPCall did with ItemsInMasterListBox. }
function  MasterAddCall(const aCall: string; const aIsDupe: boolean): boolean;

{ Puts the rebuilt list on screen.  Separate from MasterAddCall because SCP adds
  in a loop and one repaint at the end is the point. }
procedure MasterCallsUpdated;

implementation

uses
  LogStuff,          { SCPMinimumLetters }
  uMasterForm;

function MasterForm: TfrmMaster;
begin
   Result := nil;
   if (TR4WMasterForm <> nil) and TR4WMasterForm.HandleAllocated then
      begin
      Result := TR4WMasterForm;
      end;
end;

function MasterWindowOpen: boolean;
begin
   Result := (MasterForm <> nil) and TR4WMasterForm.Visible;
end;

procedure ClearMasterListBox;
var
  f: TfrmMaster;
begin
  f := MasterForm;
  if f = nil then
     begin
     Exit;
     end;
  f.Calls.BeginRebuild;
  f.Calls.EndRebuild;
end;

function MasterAddCall(const aCall: string; const aIsDupe: boolean): boolean;
var
  f: TfrmMaster;
begin
  Result := False;
  f := MasterForm;
  if f = nil then
     begin
     Exit;
     end;
  Result := f.Calls.AddItem(aCall, PtrInt(Ord(aIsDupe)));
end;

procedure MasterCallsUpdated;
var
  f: TfrmMaster;
begin
  f := MasterForm;
  if f = nil then
     begin
     Exit;
     end;
  f.Calls.EndRebuild;
end;

{ What WM_INITDIALOG did that was not control construction.

  THE SCPMinimumLetters NUDGE IS KEPT AS IT WAS.  Opening this window with the
  setting at zero used to set it to 3, because zero means "never super check"
  and an operator who has just opened the SCP window plainly wants one.  It is a
  config write from a window-open, which is not a shape to copy -- but removing
  it would change behaviour in a commit that is not about that. }
procedure MasterWindowShown;
begin
  if SCPMinimumLetters = 0 then
     begin
     SCPMinimumLetters := 3;
     end;
end;

begin
  MasterOnShow := @MasterWindowShown;
end.
