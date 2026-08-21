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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uBandPlanForm;
{$I ..\..\tr4w.inc}

{
  THE BAND PLAN EDITOR, AS AN LCL FORM.  Phase 4b.

  Per band: the CW/SSB cutoff frequency the band map splits on, and the default
  CW and SSB frequency memories. Opened from the settings dialog.

  A GRID, NOT 33 EDIT BOXES. The Win32 version built one static and three
  ES_NUMBER edits per band in a nested loop -- 11 bands x 3 columns of controls
  addressed by a computed id, `integer(TempBand) + TempColumn * 100`. A
  TStringGrid is one designed control that says the same thing, and adding a band
  to BandType no longer means the dialog silently stops showing it.

  THE ROW YOU TYPE IN DOES NOT DECIDE THE BAND -- THE FREQUENCY DOES, and that is
  the surprise worth knowing here. Both loaders derive the band from the value:
  AddBandMapModeCutoffFrequency calls CalculateBandMode(Freq, ...)
  (LOGWIND.PAS:3177), and F_FREQUENCY_MEMORY does the same (uCFG.pas:1856).
  Typing a 20m frequency into the 80m row therefore updates 20m. Checked rather
  than assumed -- the first reading of this dialog suggested the band came from
  ROW ORDER, which would have made a skipped field shift every later band. It
  does not.

  A CELL THAT IS NOT A NUMBER IS SKIPPED, leaving that band's stored value alone.
  Same as the original, which tested GetDlgItemInt's pTranslated and did
  `Continue`.

  THIS STILL WRITES tr4w.ini, AND THAT IS NOT AN OVERSIGHT. [BAND PLAN] has no
  JSON home yet: its rows are ctFreqList, multi-valued, and uCFG.pas:1249 records
  that they are display-only in Preferences for exactly that reason. The whole
  section is replaced in one WritePrivateProfileSectionA because the keys REPEAT
  -- twelve `BAND MAP CUTOFF FREQUENCY=` lines, one per band -- which no
  single-value write can express.
}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Grids, LCLType;

const
  // IN THE INTERFACE because FMinColWidth's RANGE is written in terms of
  // them, and a class field's type is part of the interface -- the
  // implementation section cannot be seen from a declaration above it.
  // Kept as named columns rather than 0..3 so that adding a column is one
  // edit here and a compile error everywhere it matters.
  COL_BAND   = 0;
  COL_CUTOFF = 1;
  COL_CW     = 2;
  COL_SSB    = 3;

type
  TfrmBandPlan = class(TForm)
    grdBandPlan: TStringGrid;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure HandleResize(Sender: TObject);
  private
    // The measured widths from FitColumnsToText, kept because the spread has to
    // be recomputed from the MINIMUMS on every resize. Growing the current
    // widths instead compounds: drag the window wider twice and the columns end
    // up wider than the window.
    FMinColWidth: array[COL_BAND..COL_SSB] of integer;
    procedure SaveBandPlan;
    // Column widths come from the TEXT, not from a guess.  DefaultColWidth was
    // 110px and the widest heading, 'BAND MAP CUTOFF FREQUENCY', does not fit
    // in it -- so three of the four headings were clipped and the operator
    // could not tell which column was which (NY4I, 2026-08-21).
    procedure FitColumnsToText;
    // Widths follow the window; height is pinned to the row count. See the
    // implementations for why only one of the two dimensions is free.
    procedure SpreadColumnsAcrossWidth;
    procedure LockHeightToContent;
    // Bounds persistence, keyed LAYOUT_NAME in settings\tr4w.json -- the same
    // 'windows' section and the same store the main window's own windows use,
    // rather than a second mechanism for one dialog.
    function  RestoreSavedBounds: boolean;
    procedure SaveCurrentBounds;
  end;

// the band-plan editor.  Nested INSIDE the settings dialog, so its parent is
// the settings window.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowBandPlan(const aParent: HWND);

implementation

{$R *.lfm}

uses
  Windows,
  Types,               // TRect / IntersectRect
  uTR4WConfigFile,     // TR4WConfigFileName, Save/LoadWindowLayout
  uWindowLayoutStore,  // TWindowLayoutStore -- the same store the main windows use
  VC,              // RC_BANDPLAN, BandStringsArrayWithOutSpaces, TR4W_INI_FILENAME
  LogWind,         // BandMapModeCutoffFrequency, DefaultFreqMemory
  MainUnit,        // logger
  uLCLFormHelpers,
  uHostedFormWindows,
  Log4D;

const
  // The bands this dialog edits.  The original looped Band160..Band2 and the
  // loaders both guard on that same range.
  FIRST_BAND = Band160;
  LAST_BAND  = Band2;

  // The key this dialog's bounds are stored under in settings\tr4w.json.
  // Deliberately not one of VC.WindowNames -- those name the main window's
  // OWN windows and are indexed by WindowsType; this is a dialog, and the
  // store is keyed by name precisely so a newcomer needs no enum slot.
  LAYOUT_NAME     = 'BandPlan';

  // Cell text to cell edge, both sides, plus the grid line.
  CELL_PADDING    = 12;
  GRID_MARGIN     = 8;    // the grid's Left, mirrored on the right
  GRID_SLACK      = 4;    // rounding, so the last column never clips by a pixel
  GRID_BORDER          = 4;    // the grid's own frame, top and bottom
  // Grid bottom to the buttons (12), the buttons (25), and below them (10)
  // -- the .lfm geometry, stated once so LockHeightToContent cannot drift
  // from it silently.
  BUTTON_STRIP_HEIGHT  = 47;

var
  frmBandPlan: TfrmBandPlan = nil;

procedure TfrmBandPlan.HandleShow(Sender: TObject);
var
  b: BandType;
  row: integer;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := RC_BANDPLAN;

   grdBandPlan.RowCount := Ord(LAST_BAND) - Ord(FIRST_BAND) + 2;   // + the header

   grdBandPlan.Cells[COL_BAND,   0] := 'Band';
   grdBandPlan.Cells[COL_CUTOFF, 0] := 'BAND MAP CUTOFF FREQUENCY';
   grdBandPlan.Cells[COL_CW,     0] := 'FREQUENCY MEMORY CW';
   grdBandPlan.Cells[COL_SSB,    0] := 'FREQUENCY MEMORY SSB';

   row := 1;
   for b := FIRST_BAND to LAST_BAND do
      begin
      grdBandPlan.Cells[COL_BAND,   row] := string(BandStringsArrayWithOutSpaces[b]);
      grdBandPlan.Cells[COL_CUTOFF, row] := IntToStr(BandMapModeCutoffFrequency[b]);
      grdBandPlan.Cells[COL_CW,     row] := IntToStr(DefaultFreqMemory[b, CW]);
      grdBandPlan.Cells[COL_SSB,    row] := IntToStr(DefaultFreqMemory[b, Phone]);
      Inc(row);
      end;

   grdBandPlan.Col := COL_CUTOFF;
   grdBandPlan.Row := 1;

   // ORDER MATTERS: the columns are measured first because the width floor
   // is derived from them, and the saved bounds are applied last so the
   // operator's own size wins over the computed minimum (the constraint
   // still stops it going below readable).
   FitColumnsToText;
   LockHeightToContent;

   // CENTRED AFTER SIZING, and only when there is no saved position to
   // honour.  ShowModalOverWin32Parent centred this form before it was
   // shown, but the two calls above have changed its size since -- so that
   // centring is now stale by half the difference.
   if not RestoreSavedBounds then
      begin
      CentreOverMainWindow(Self);
      end;

   SpreadColumnsAcrossWidth;   // the restored width may be wider than measured
end;

procedure TfrmBandPlan.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   // SAVED ON EVERY CLOSE, Cancel included.  Where the operator put the
   // window is not part of the band plan they are cancelling.
   SaveCurrentBounds;

   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

// Fixed cells are drawn in TitleFont and data cells in Font, so each is measured
// with the font it will actually be painted in -- measuring both with one font
// is how a heading ends up one bold-space too narrow.
procedure TfrmBandPlan.FitColumnsToText;
var
   col, row, w, t, needed, frame: integer;
begin
   needed := 0;

   for col := 0 to grdBandPlan.ColCount - 1 do
      begin
      grdBandPlan.Canvas.Font := grdBandPlan.TitleFont;
      w := grdBandPlan.Canvas.TextWidth(grdBandPlan.Cells[col, 0]);

      grdBandPlan.Canvas.Font := grdBandPlan.Font;
      for row := 1 to grdBandPlan.RowCount - 1 do
         begin
         t := grdBandPlan.Canvas.TextWidth(grdBandPlan.Cells[col, row]);
         if t > w then
            begin
            w := t;
            end;
         end;

      grdBandPlan.ColWidths[col] := w + CELL_PADDING;
      FMinColWidth[col]          := grdBandPlan.ColWidths[col];
      needed := needed + grdBandPlan.ColWidths[col];
      end;

   // THE FORM IS GROWN TO FIT AND THEN FLOORED THERE.  goColSizing is not in
   // the grid's options, so the operator cannot drag a column narrow; the only
   // way a heading could be clipped again is the WINDOW being dragged narrow,
   // which the constraint now prevents.  Resizing wider still works -- it is a
   // floor, not a fixed size (NY4I asked for both).
   frame  := Width - ClientWidth;                        // borders
   needed := needed + (2 * GRID_MARGIN) + frame +
             Windows.GetSystemMetrics(SM_CXVSCROLL) + GRID_SLACK;

   Constraints.MinWidth  := needed;

   if Width < needed then
      begin
      Width := needed;
      end;
end;

function TfrmBandPlan.RestoreSavedBounds: boolean;
var
   store: TWindowLayoutStore;
   saved: TRect;
   visible: boolean;
   desktop, overlap: TRect;
begin
   Result := False;

   store := TWindowLayoutStore.Create;
   try
      if not LoadWindowLayout(TR4WConfigFileName, store) then
         begin
         Exit;
         end;

      if not store.TryGetLayout(LAYOUT_NAME, saved, visible) then
         begin
         Exit;
         end;

      // OFF-SCREEN IS NOT RESTORED.  A monitor that is no longer attached
      // leaves a perfectly well-formed rect that puts the dialog where nobody
      // can reach it, and this one is modal -- the operator would be looking at
      // a dead application.  Any overlap with the virtual desktop is enough;
      // Windows itself will nudge a partly-off window back.
      desktop := Rect(Screen.DesktopLeft, Screen.DesktopTop,
                      Screen.DesktopLeft + Screen.DesktopWidth,
                      Screen.DesktopTop  + Screen.DesktopHeight);
      if not IntersectRect(overlap, saved, desktop) then
         begin
         logger.Warn('[BandPlan] saved bounds are off-screen -- centring instead');
         Exit;
         end;

      // poDesigned FIRST: with poMainFormCenter still set, the LCL re-centres
      // the form when it is shown and the restored position is thrown away.
      Position := poDesigned;
      // HEIGHT IS NOT RESTORED -- it is computed from the row count and pinned
      // by LockHeightToContent, which has already run.  Passing the saved
      // height would be silently clamped by the constraint; passing the real
      // one says so.  Position and WIDTH are the operator's to keep.
      SetBounds(saved.Left, saved.Top, saved.Right - saved.Left, Height);
      Result := True;
   finally
      store.Free;
   end;
end;

procedure TfrmBandPlan.SaveCurrentBounds;
var
   store: TWindowLayoutStore;
begin
   // A minimised or maximised window reports bounds that are not what to
   // restore.  This form has no maximise box, so this is a guard rather than a
   // live case -- and a cheap one next to writing a -32000 sentinel into the
   // config, which is the failure it prevents.
   if WindowState <> wsNormal then
      begin
      Exit;
      end;

   store := TWindowLayoutStore.Create;
   try
      // SetLayout on an EMPTY store, not the file's contents: SaveWindowLayout
      // re-reads the file and overlays these entries, so every other window's
      // row is preserved without this dialog having to know they exist.
      store.SetLayout(LAYOUT_NAME,
                      Rect(Left, Top, Left + Width, Top + Height), True);
      SaveWindowLayout(TR4WConfigFileName, store);
   finally
      store.Free;
   end;
end;
// THE GRID FILLS, NOT JUST THE CONTROL.  The grid was already anchored on all
// four sides, so it did follow the window -- but its COLUMNS kept their measured
// widths, and the surplus showed as a band of dead white inside the grid (NY4I,
// 2026-08-21, screenshot after widening).
//
// The surplus goes to the three FREQUENCY columns only. 'Band' is a label column
// two or three characters wide; stretching it would put '160' adrift in the
// middle of a wide cell and buy nothing.
procedure TfrmBandPlan.SpreadColumnsAcrossWidth;
var
   col, total, avail, surplus, share: integer;
begin
   // Before FitColumnsToText has run there is nothing to spread -- OnResize
   // fires during form construction, well before HandleShow.
   if FMinColWidth[COL_SSB] = 0 then
      begin
      Exit;
      end;

   total := 0;
   for col := COL_BAND to COL_SSB do
      begin
      grdBandPlan.ColWidths[col] := FMinColWidth[col];
      total := total + FMinColWidth[col];
      end;

   avail := grdBandPlan.ClientWidth - GRID_SLACK;
   if avail <= total then
      begin
      Exit;                      // narrower than the text: the minimums stand
      end;

   surplus := avail - total;
   share   := surplus div 3;

   grdBandPlan.ColWidths[COL_CUTOFF] := FMinColWidth[COL_CUTOFF] + share;
   grdBandPlan.ColWidths[COL_CW]     := FMinColWidth[COL_CW]     + share;
   // The remainder lands on the last column rather than being lost to integer
   // division, so the columns always add up to the full width.
   grdBandPlan.ColWidths[COL_SSB]    := FMinColWidth[COL_SSB] + surplus - (2 * share);
end;

// VERTICAL DEAD SPACE IS MADE IMPOSSIBLE RATHER THAN TIDIED UP.  There are
// exactly eleven bands and no scrolling to do, so height is not a dimension the
// operator has anything to gain from: any extra is empty grid under the last
// row. The height is therefore computed from the rows and pinned with equal Min
// and Max constraints. Width stays free -- that is the one that matters, since
// it decides whether the headings are readable.
procedure TfrmBandPlan.LockHeightToContent;
var
   row, rows: integer;
begin
   rows := 0;
   for row := 0 to grdBandPlan.RowCount - 1 do
      begin
      rows := rows + grdBandPlan.RowHeights[row];
      end;

   // The grid is anchored top AND bottom, so its height follows the form's --
   // setting ClientHeight is what sizes it, and setting grdBandPlan.Height
   // directly would be undone by the next layout pass.
   ClientHeight := grdBandPlan.Top + rows + GRID_BORDER + BUTTON_STRIP_HEIGHT;

   Constraints.MinHeight := Height;
   Constraints.MaxHeight := Height;
end;

procedure TfrmBandPlan.HandleResize(Sender: TObject);
begin
   SpreadColumnsAcrossWidth;
end;
procedure TfrmBandPlan.SaveBandPlan;
var
  b: BandType;
  col, row, freq, err: integer;
  section: AnsiString;

  procedure Emit(const aLine: AnsiString);
  begin
     // The section is a run of null-separated "key=value" strings ending in a
     // SECOND null -- the shape WritePrivateProfileSectionA wants.  The original
     // built it by stepping a write position past each terminator inside one
     // buffer; an AnsiString holds embedded nulls perfectly well.
     section := section + aLine + #0;
  end;

begin
   section := '';

   // COLUMN-MAJOR, exactly as the original: every cutoff, then every CW memory,
   // then every SSB memory.  The loaders do not care about order -- each value
   // carries its own band -- but keeping it means an unchanged edit rewrites a
   // byte-identical section, which is worth having when diffing a config.
   for col := COL_CUTOFF to COL_SSB do
      begin
      row := 1;
      for b := FIRST_BAND to LAST_BAND do
         begin
         Val(Trim(grdBandPlan.Cells[col, row]), freq, err);
         Inc(row);

         // NOT A NUMBER: skip it, leaving that band's stored value alone. The
         // original tested GetDlgItemInt's pTranslated and did Continue.
         if err <> 0 then
            begin
            Continue;
            end;

         case col of
            COL_CUTOFF:
               begin
               BandMapModeCutoffFrequency[b] := freq;
               Emit(AnsiString('BAND MAP CUTOFF FREQUENCY=' + IntToStr(freq)));
               end;
            COL_CW:
               begin
               DefaultFreqMemory[b, CW] := freq;
               Emit(AnsiString('FREQUENCY MEMORY=' + IntToStr(freq)));
               end;
            COL_SSB:
               begin
               DefaultFreqMemory[b, Phone] := freq;
               // The 'SSB ' prefix is what selects Phone on the way back in --
               // F_FREQUENCY_MEMORY looks for it (uCFG.pas:1850). Without it the
               // value silently becomes a CW memory.
               Emit(AnsiString('FREQUENCY MEMORY=SSB ' + IntToStr(freq)));
               end;
         end;
         end;
      end;

   section := section + #0;   // the terminating second null

   Windows.WritePrivateProfileSectionA('BAND PLAN', PAnsiChar(section),
                                       TR4W_INI_FILENAME);
end;

procedure TfrmBandPlan.btnOKClick(Sender: TObject);
begin
   SaveBandPlan;
   Close;
end;

procedure TfrmBandPlan.btnCancelClick(Sender: TObject);
begin
   Close;
end;

procedure ShowBandPlan(const aParent: HWND);
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmBandPlan = nil then
         begin
         frmBandPlan := TfrmBandPlan.Create(Application);
         end;

      // The parent is the settings dialog, which is still a raw Win32 window,
      // so it needs the explicit disable -- LCL ShowModal only disables LCL
      // forms.  This is the inner half of that pair; the outer is Phase 4c.
      ShowModalOverWin32Parent(frmBandPlan, aParent);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowBandPlan failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
