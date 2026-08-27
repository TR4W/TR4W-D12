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
unit uCT1BOHForm;
{$I ..\..\tr4w.inc}

{
  THE CT1BOH INFORMATION BOX, AS AN LCL FORM.  Phase 4b.

  A read-only report: time spent per band, then one row per continent showing
  QSOs and what share of that band they were.

  IT HAS NO BUTTONS, AND THAT IS FAITHFUL. The Win32 version never called
  CreateOKCancelButtons -- it closed on the window button or on Escape, which the
  dialog manager turned into IDCANCEL. An LCL form gets neither for free, so this
  uses KeyPreview and an Escape handler. Adding an OK button would have been the
  easy way to satisfy Lint-FormDefaults and would have changed the dialog.

  THE ROW ORDER FALLS OUT OF ContinentType, and it is worth stating because it
  looks accidental. The continents are inserted at `Ord(Continent)`, and the enum
  begins with UnknownContinent = 0, so NorthAmerica..Antartica land at 1..7 --
  directly under the Time ON row, which was inserted first. Sequential, not a
  coincidence to be preserved by luck.

  A WHOLE CLASS OF PROBLEM DISAPPEARS HERE. The original carried two long
  comments about `uCommctrl` versus FPC's own `commctrl`: the same type names
  declared in both units, binding differently depending on uses-clause order and
  surfacing as "Call by var has to match exactly: got tagLVCOLUMNA expected
  LV_COLUMN". It also needed a function-scoped AnsiString to keep `pszText`
  alive across ListView_SetItem. A TListView takes strings; none of that exists.
}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, LCLType,
  uTR4WStrings;

type
  TfrmCT1BOH = class(TForm)
    lvStats: TListView;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
  end;

// the CT1BOH information box.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowCT1BOHInfo;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  VC,          // RC_CT1BOHIS2, TC_TIMEON, tContinentArray, BandStrings...
  TF,          // MillisecondsToFormattedString
  PostUnit,    // CalculateTotals
  LogWind,     // TimeSpentByBand, ContinentQSOCount
  MainUnit,    // logger
  uHostedFormWindows,
  Log4D;

const
  // The seven columns of the report, in order.  AllBands is the total.
  REPORT_BANDS: array[1..7] of BandType =
    (Band160, Band80, Band40, Band20, Band15, Band10, AllBands);

var
  frmCT1BOH: TfrmCT1BOH = nil;

function QSOsAndShare(const aQSOs, aPercent: integer): string;
begin
   // Blank rather than "0 (0%)" when there are none -- the original returned an
   // empty buffer for a zero count, which is what keeps the grid readable.
   if aQSOs = 0 then
      begin
      Result := '';
      end
   else
      begin
      Result := Format('%d (%d%%)', [aQSOs, aPercent]);
      end;
end;

procedure TfrmCT1BOH.HandleShow(Sender: TObject);
var
  i: integer;
  c: ContinentType;
  col: TListColumn;
  item: TListItem;
  bandTotals: array[1..7] of integer;
  pct: integer;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := RC_CT1BOHIS2;

   CalculateTotals;

   lvStats.Items.BeginUpdate;
   try
      lvStats.Items.Clear;
      lvStats.Columns.Clear;

      // Column 0 carries the row label and is wider; the seven band columns
      // follow at the original's 75.
      col := lvStats.Columns.Add;
      col.Caption   := '';
      col.Width     := 130;
      col.Alignment := taCenter;

      for i := 1 to 7 do
         begin
         col := lvStats.Columns.Add;
         col.Caption   := string(BandStringsArrayWithOutSpaces[REPORT_BANDS[i]]);
         col.Width     := 75;
         col.Alignment := taCenter;
         end;

      // Row 0: time spent on each band.
      item := lvStats.Items.Add;
      item.Caption := string(TC_TIMEON);
      for i := 1 to 7 do
         begin
         item.SubItems.Add(
            MillisecondsToFormattedString(TimeSpentByBand[REPORT_BANDS[i]] * 1000, False));
         end;

      // Each band's total across the continents, so the shares below have a
      // denominator.
      for i := 1 to 7 do
         begin
         bandTotals[i] := 0;
         for c := NorthAmerica to High(ContinentType) do
            begin
            bandTotals[i] := bandTotals[i] + ContinentQSOCount[REPORT_BANDS[i], c];
            end;
         end;

      // One row per continent, from NorthAmerica -- UnknownContinent is index 0
      // in the enum and is deliberately not reported.
      for c := NorthAmerica to High(ContinentType) do
         begin
         item := lvStats.Items.Add;
         item.Caption := string(tContinentArray[c]);

         for i := 1 to 7 do
            begin
            if bandTotals[i] = 0 then
               begin
               pct := 0;
               end
            else
               begin
               pct := Round((ContinentQSOCount[REPORT_BANDS[i], c] / bandTotals[i]) * 100);
               end;

            item.SubItems.Add(
               QSOsAndShare(ContinentQSOCount[REPORT_BANDS[i], c], pct));
            end;
         end;
   finally
      lvStats.Items.EndUpdate;
   end;
end;

procedure TfrmCT1BOH.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmCT1BOH.HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   // The only way out, as it was: this report has no buttons.
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure ShowCT1BOHInfo;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmCT1BOH = nil then
         begin
         frmCT1BOH := TfrmCT1BOH.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmCT1BOH, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowCT1BOHInfo failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
