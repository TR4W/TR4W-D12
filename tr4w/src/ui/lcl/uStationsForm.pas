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

{ THE STATIONS WINDOW, as an LCL form.

  Third tw_ window to convert, after the function keys and the band map, and it
  uses the same seam: OpenTR4WWindow forks to CreateTR4WStationsWindow before it
  reaches CreateDialogIndirectParam, and everything downstream keeps working
  because it only ever dealt in a handle and a rectangle.

  THIS UNIT OWNS THE VIEW AND NOTHING ELSE.  Which callsigns are listed, in what
  order, and which bands are worked is uStations' business -- see the model note
  there.  Every routine below addresses a row by INDEX, and that index is the
  model's, which is why nothing here reads a row back to find out what it is.
  That read-back is precisely what the Win32 version had to do and what this
  conversion removes. }
unit uStationsForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, ComCtrls, Graphics;

type
   TfrmStations = class(TForm)
      lvStations: TListView;
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure HandleResize(Sender: TObject);
   end;

var
   TR4WStationsForm: TfrmStations = nil;

   { WHAT WM_INITDIALOG USED TO DO, and it cannot be called from here.

     The dialog rebuilt its header and refilled its rows every time it opened.
     A form is created once and reshown, so OnShow is the equivalent moment --
     but this unit owns the VIEW and knows nothing about callsigns, so the work
     belongs to uStations and arrives as a seam it assigns at initialization.
     Same shape as uBandMapView, and the reason there is no uses cycle here. }
   StationsOnShow: procedure = nil;

function CreateTR4WStationsWindow: HWND;

{ The view operations.  All of them are no-ops when the window is not open --
  the headless /EXPORT path never builds a form, and uStations is reachable from
  there through the log load. }
procedure StationsClearColumns;
procedure StationsAddColumn(const aCaption: string; const aWidth: integer;
                            const aCentre: boolean);
procedure StationsSetColumnCaption(const aColumn: integer; const aCaption: string);

procedure StationsClearRows;
procedure StationsInsertRow(const aIndex: integer; const aCall: string);
procedure StationsDeleteRow(const aIndex: integer);
procedure StationsSetCell(const aRow, aColumn: integer; const aText: string);
procedure StationsSelectAndShow(const aRow: integer);

procedure StationsBeginUpdate;
procedure StationsEndUpdate;

procedure StationsSetCaption(const aCaption: string);

implementation

{$R *.lfm}

uses
   VC,                { tw_STATIONS_INDEX }
   MainUnit,          { CloseTR4WWindow }
   uLCLFormHelpers;   { OwnFormByMainWindow -- the LCL way to parent a tool window }

{ One guard for every routine below, and it has to be BOTH tests.  The form is
  nil on the headless export path, and a TListView exists from the moment it is
  constructed while its window does not -- the LCL creates that lazily.  The
  Win32 calls these replace were silent no-ops on handle 0; direct property
  access is not, and dropping the second half of this test is exactly how the
  main window crashed on startup on 2026-08-23. }
function ListUsable: boolean;
begin
   Result := (TR4WStationsForm <> nil) and
             (TR4WStationsForm.lvStations <> nil) and
             TR4WStationsForm.lvStations.HandleAllocated;
end;

{ Is this a row the list actually has?  Every caller addresses rows by MODEL
  index, so a disagreement between the model and the view would otherwise be a
  range error inside a window procedure -- which is a fatal process kill, not an
  exception (see the note on uMainWindowProc.WindowProc). }
function RowUsable(const aRow: integer): boolean;
begin
   Result := ListUsable and
             (aRow >= 0) and
             (aRow < TR4WStationsForm.lvStations.Items.Count);
end;

procedure TfrmStations.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // Route the close through the window manager exactly as WM_CLOSE did, so the
   // saved rectangle, the menu check mark and WndHandle stay in step.  caFree
   // would tear the form down behind CloseTR4WWindow's back.
   // caHIDE, NOT caNone.  caNone leaves the form VISIBLE as far as the LCL is
   // concerned, and CloseTR4WWindow then destroys the handle underneath it --
   // so the widget set recreates it and the window will not go away.  NY4I:
   // "Clicking on the X on the Stations window does not close it. Nor does
   // hitting the accelerator key again" (bench queue, 2026-08).  The six
   // windows converted later all use caHide and close correctly; these five
   // were the early ones.
   CloseAction := caHide;
   CloseTR4WWindow(tw_STATIONS_INDEX);
end;

procedure TfrmStations.HandleShow(Sender: TObject);
begin
   if Assigned(StationsOnShow) then
      begin
      StationsOnShow;
      end;

   // The columns did not exist when the form was last resized -- StationsOnShow
   // is what builds them -- so the fill has to run again now that they do.
   HandleResize(Sender);
end;

{ THE WHOLE GRID SCALES WITH THE WINDOW -- COLUMNS AND FONT TOGETHER.

  Align = alClient stretches the CONTROL, which is not the same thing: the
  columns kept their designed widths and the operator got a grey strip to the
  right of the last band however wide the window was made (NY4I, screenshot
  2026-08-24).  NY4I: "as I resize stations, the fixed grid proportionally gets
  bigger including the font size."

  ONE SCALE DRIVES BOTH, and that is what makes it look right rather than
  merely stretched.  The design is 75px for the callsign and 36px per band at a
  9pt font; the scale is how much wider the window is than that total, the font
  takes it first, and THE COLUMNS ARE THEN SIZED FROM THE FONT THE CONTROL
  ACTUALLY GOT.  Sizing columns from the raw window width instead would let the
  two drift apart the moment the font hits a limit -- huge columns around small
  text, or clipped captions.

  THE MINIMUM IS THE OPERATOR'S (NY4I: "subject to a minimum font size").  THE
  MAXIMUM IS MINE, and is stated rather than assumed: without one, a maximised
  window on a wide monitor gives 40pt callsigns.  Both are one constant each.

  Row height needs no arithmetic -- a report-view TListView takes it from the
  font, so it follows for free. }
const
   { At DESIGN_FONT point size. }
   CALLSIGN_WIDTH = 75;
   BAND_WIDTH     = 36;

   DESIGN_FONT = 9;
   MIN_FONT    = 7;
   MAX_FONT    = 28;

procedure TfrmStations.HandleResize(Sender: TObject);
var
   bands, designed, avail, callW, bandW, fontSize, i: integer;
begin
   if (lvStations = nil) or (lvStations.Columns.Count < 2) then
      begin
      Exit;
      end;

   bands := lvStations.Columns.Count - 1;
   designed := CALLSIGN_WIDTH + (bands * BAND_WIDTH);

   // ClientWidth less a little, so the last column does not end up under a
   // vertical scrollbar and provoke a horizontal one.
   avail := lvStations.ClientWidth - 4;
   if avail < 1 then
      begin
      Exit;      // mid-layout, or minimised
      end;

   fontSize := (DESIGN_FONT * avail) div designed;
   if fontSize < MIN_FONT then
      begin
      fontSize := MIN_FONT;
      end;
   if fontSize > MAX_FONT then
      begin
      fontSize := MAX_FONT;
      end;

   if lvStations.Font.Size <> fontSize then
      begin
      // Assigning Size also clears ParentFont, which is what we want: this
      // control's font is computed, not inherited.
      lvStations.Font.Size := fontSize;
      end;

   // FROM THE FONT THAT WAS ACTUALLY APPLIED, not from the window.  When the
   // font is clamped the columns stop growing with it, so the text always has
   // the room it was designed to have.
   bandW := (BAND_WIDTH * fontSize) div DESIGN_FONT;
   callW := (CALLSIGN_WIDTH * fontSize) div DESIGN_FONT;

   // Any width left over after the scaled columns goes to the callsign column,
   // so the grid meets the right edge exactly instead of leaving a sliver.
   if (callW + (bandW * bands)) < avail then
      begin
      callW := avail - (bandW * bands);
      end;

   lvStations.Columns.BeginUpdate;
   try
      lvStations.Columns[0].Width := callW;
      for i := 1 to lvStations.Columns.Count - 1 do
         begin
         lvStations.Columns[i].Width := bandW;
         end;
   finally
      lvStations.Columns.EndUpdate;
   end;
end;

{ Escape closes the window.  The modeless dialog this replaces did NOT -- Escape
  reached its procedure as IDCANCEL and nothing acted on it -- so this is a small
  behaviour change, made deliberately: every designed form in this tree owes the
  operator a keyboard way out, and Lint-FormDefaults enforces it. }
procedure TfrmStations.HandleKeyDown(Sender: TObject; var Key: Word;
                                     Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      { Close, NOT CloseTR4WWindow.  Going straight to the primitive
        destroys the handle while the LCL still believes the form is
        shown, so the widget set recreates it and Escape appears to do
        nothing.  Close runs HandleClose, which sets caHide and calls
        CloseTR4WWindow itself -- every other converted form does this. }
      Close;
      end;
end;

procedure StationsClearColumns;
begin
   if not ListUsable then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Columns.Clear;
end;

procedure StationsAddColumn(const aCaption: string; const aWidth: integer;
                            const aCentre: boolean);
var
   col: TListColumn;
begin
   if not ListUsable then
      begin
      Exit;
      end;

   col := TR4WStationsForm.lvStations.Columns.Add;
   col.Caption := aCaption;
   col.Width := aWidth;
   if aCentre then
      begin
      col.Alignment := taCenter;
      end
   else
      begin
      col.Alignment := taLeftJustify;
      end;
end;

procedure StationsSetColumnCaption(const aColumn: integer; const aCaption: string);
begin
   if not ListUsable then
      begin
      Exit;
      end;
   if (aColumn < 0) or (aColumn >= TR4WStationsForm.lvStations.Columns.Count) then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Columns[aColumn].Caption := aCaption;
end;

procedure StationsClearRows;
begin
   if not ListUsable then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Items.Clear;
end;

{ INSERT AT THE MODEL'S INDEX, not append.  The rows are kept in the order the
  model holds them, so a callsign added mid-contest lands between its
  neighbours; the Win32 version got that from LVS_SORTASCENDING, which is also
  why it could no longer say which row was which. }
procedure StationsInsertRow(const aIndex: integer; const aCall: string);
var
   item: TListItem;
   i: integer;
begin
   if not ListUsable then
      begin
      Exit;
      end;
   if (aIndex < 0) or (aIndex > TR4WStationsForm.lvStations.Items.Count) then
      begin
      Exit;
      end;

   item := TR4WStationsForm.lvStations.Items.Insert(aIndex);
   item.Caption := aCall;

   // The band cells have to EXIST before anything can set one: SubItems is a
   // string list, not a fixed-width row, and writing past its end raises.
   for i := 1 to TR4WStationsForm.lvStations.Columns.Count - 1 do
      begin
      item.SubItems.Add('');
      end;
end;

procedure StationsDeleteRow(const aIndex: integer);
begin
   if not RowUsable(aIndex) then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Items.Delete(aIndex);
end;

procedure StationsSetCell(const aRow, aColumn: integer; const aText: string);
var
   item: TListItem;
begin
   if not RowUsable(aRow) then
      begin
      Exit;
      end;

   item := TR4WStationsForm.lvStations.Items[aRow];
   if aColumn = 0 then
      begin
      item.Caption := aText;
      Exit;
      end;

   // SubItems is 0-based over columns 1..n, and a row built before a column was
   // added would be short.  Grow rather than raise: a missing cell is a display
   // gap, an exception in here is the process.
   while item.SubItems.Count < aColumn do
      begin
      item.SubItems.Add('');
      end;
   item.SubItems[aColumn - 1] := aText;
end;

procedure StationsSelectAndShow(const aRow: integer);
var
   item: TListItem;
begin
   if not RowUsable(aRow) then
      begin
      Exit;
      end;

   item := TR4WStationsForm.lvStations.Items[aRow];
   TR4WStationsForm.lvStations.Selected := item;
   item.MakeVisible(False);
end;

procedure StationsBeginUpdate;
begin
   if not ListUsable then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Items.BeginUpdate;
end;

procedure StationsEndUpdate;
begin
   if not ListUsable then
      begin
      Exit;
      end;
   TR4WStationsForm.lvStations.Items.EndUpdate;
end;

procedure StationsSetCaption(const aCaption: string);
begin
   if TR4WStationsForm = nil then
      begin
      Exit;
      end;
   TR4WStationsForm.Caption := aCaption;
end;

function CreateTR4WStationsWindow: HWND;
begin
   if TR4WStationsForm = nil then
      begin
      TR4WStationsForm := TfrmStations.Create(nil);
      end;

   // PARENTED THE LCL WAY -- PopupParent / pmExplicit, not
   // SetWindowLongPtr(GWL_HWNDPARENT).  The same call the band map and the
   // function-keys window use, and the reason this unit needs no Windows uses
   // clause.
   OwnFormByMainWindow(TR4WStationsForm);

   Result := TR4WStationsForm.Handle;
end;

end.
