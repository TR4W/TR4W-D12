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
unit uColumnHeaders;
{$I tr4w.inc}

(*
  NO COLUMN HEADER -- WHICH WINDOWS LOSE THEIR HEADING ROW (issue 352).

  D7 read the setting in exactly two window creators, and this keeps the
  same two families:

  - CreateEditableLog (the main window's log, View/Edit Log, Log Search and
    the downloaded server log). Every one of those is a TLogGrid now, and so
    is the B4 list that stands in for the main log, so the rule is simply
    "every TLogGrid". TLogGrid.ShowHeader owns the row arithmetic.
  - CreateListView (the Network window and the Stations window). Those are
    TListViews in vsReport, and the LCL's own ShowColumnHeaders is the
    switch.

  ONE DECISION, ColumnHeadersShown, read by both overloads. A window applies
  it when it is built; uSettingsEffects re-applies it to whatever is open
  when the setting changes, so a change in Preferences shows at once.

  Nothing else reads the setting. A list window that D7 did not build through
  either creator (Alt-P, the multipliers, the cluster) is deliberately not
  touched: it never honoured NO COLUMN HEADER. *)

interface

uses
   ComCtrls,
   uLogGrid;

(* True unless NO COLUMN HEADER is set. *)
function ColumnHeadersShown: boolean;

(* Give one control the heading row the setting asks for. *)
procedure ApplyColumnHeaders(const aGrid: TLogGrid); overload;
procedure ApplyColumnHeaders(const aList: TListView); overload;

(* Every such control that exists now: each TLogGrid owned by an open form,
  and the Network and Stations list views. Safe before any window exists. *)
procedure ApplyColumnHeadersToOpenWindows;

implementation

uses
   Forms,
   uSettingsModel,   (* Settings.MainWindow.NoColumnHeader *)
   uNetworkForm,     (* TR4WNetworkForm.lvClients -- D7's mweNetwork *)
   uStationsForm;    (* TR4WStationsForm.lvStations -- D7's mweStations *)

function ColumnHeadersShown: boolean;
begin
   Result := not Settings.MainWindow.NoColumnHeader;
end;

procedure ApplyColumnHeaders(const aGrid: TLogGrid);
begin
   if aGrid = nil then
      begin
      Exit;
      end;
   aGrid.ShowHeader := ColumnHeadersShown;
end;

procedure ApplyColumnHeaders(const aList: TListView);
begin
   if aList = nil then
      begin
      Exit;
      end;
   aList.ShowColumnHeaders := ColumnHeadersShown;
end;

procedure ApplyColumnHeadersToOpenWindows;
var
   f: integer;
   c: integer;
   form: TCustomForm;
begin
   if Screen <> nil then
      begin
      for f := 0 to Screen.CustomFormCount - 1 do
         begin
         form := Screen.CustomForms[f];
         for c := 0 to form.ComponentCount - 1 do
            begin
            if form.Components[c] is TLogGrid then
               begin
               ApplyColumnHeaders(TLogGrid(form.Components[c]));
               end;
            end;
         end;
      end;

   if TR4WNetworkForm <> nil then
      begin
      ApplyColumnHeaders(TR4WNetworkForm.lvClients);
      end;

   if TR4WStationsForm <> nil then
      begin
      ApplyColumnHeaders(TR4WStationsForm.lvStations);
      end;
end;

end.
