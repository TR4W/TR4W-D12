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

type
  TfrmBandPlan = class(TForm)
    grdBandPlan: TStringGrid;
    btnOK: TButton;
    btnCancel: TButton;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure btnOKClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
  private
    procedure SaveBandPlan;
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

  COL_BAND   = 0;
  COL_CUTOFF = 1;
  COL_CW     = 2;
  COL_SSB    = 3;

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
end;

procedure TfrmBandPlan.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
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
