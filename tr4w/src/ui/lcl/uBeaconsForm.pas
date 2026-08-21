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
unit uBeaconsForm;
{$I ..\..\tr4w.inc}

{
  THE NCDXF/IBP BEACON MONITOR, AS AN LCL FORM.  Phase 4b.

  Eighteen beacons share five frequencies on a three-minute cycle: each beacon
  transmits for ten seconds on one band, then moves up a band while the next
  beacon takes the one it left. At any instant FIVE beacons are on the air, one
  per band, and they sit on a diagonal of the schedule. This window shows that
  diagonal moving.

  NINETY STATIC CONTROLS BECOME ONE GRID. The Win32 version built an 18x5 array
  of SS_SUNKEN statics -- BeaconsHandle -- and expressed "who is transmitting"
  by calling EnableWindow on each of the ninety: False for all, then True for
  the five on the diagonal, so an ENABLED control meant an ACTIVE beacon. That
  is an unusual thing for enablement to mean, and it cost ninety window handles
  and ninety CreateWindow calls to say it.

  A TStringGrid says it in a colour, from OnPrepareCanvas, with no handles at
  all. BeaconsHandle is gone and with it the array's only reason to exist.

  THE TIMER NOW WATCHES THE SLOT, NOT THE SECOND. The original ticked once a
  second and refreshed only when it happened to observe `UTC.wSecond mod 10 = 0`
  -- so a tick that arrived late, or was coalesced away, lost the update and the
  display stayed a slot behind for the next ten seconds. This recomputes the
  slot on every tick and redraws when the SLOT CHANGES. The displayed content is
  a pure function of the slot, so it is the same picture for every tick the
  original got right, and correct for the ones it did not.

  OPENING THIS WINDOW MOVES THE RADIO, and always has: WM_INITDIALOG selected
  button 101 and called SetBeaconFreq, which QSYs Radio 1 to 14100 kHz CW. That
  is preserved deliberately -- it is the point of the window rather than a side
  effect -- but it is worth knowing before opening it mid-QSO.

  DELETED, not carried across:
    * `FC` -- assigned on every frequency click and READ NOWHERE, in this unit
      or any other. Write-only state.
    * `BeaconsHandle` -- see above; no external reader either.
    * the `h: HWND` parameter of SetBeaconFreq and ShowBeaconsNames, which
      neither routine ever used, and their place in the interface: nothing
      outside the unit called either of them.
    * the commented-out `BeaconsGrids` locator table, the commented `asm`
      SETFONT block, and the progress-bar arms (controls 98 and 99) for a
      control the dialog never created.
  The IBP schedule table at the foot of uBeacons.pas is kept -- that is
  documentation, not dead code.
}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Buttons, Grids, ExtCtrls,
  LCLType;

type
  TfrmBeacons = class(TForm)
    sbFreq1, sbFreq2, sbFreq3, sbFreq4, sbFreq5: TSpeedButton;
    sbFreq6, sbFreq7, sbFreq8, sbFreq9, sbFreq10: TSpeedButton;
    grdBeacons: TStringGrid;
    tmrSlot: TTimer;
    procedure HandleShow(Sender: TObject);
    procedure HandleClose(Sender: TObject; var Action: TCloseAction);
    procedure HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure HandleSlotTimer(Sender: TObject);
    procedure FrequencyClick(Sender: TObject);
    procedure GridPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                aState: TGridDrawState);
  private
    // FActiveRow[c] is the row transmitting on column c's band right now, or
    // -1 before the first slot has been computed.
    FActiveRow: array[0..4] of integer;
    FSlot: integer;
    function CurrentSlot: integer;
    procedure ApplySlot(const aSlot: integer);
    procedure RefreshIfSlotChanged;
  end;

// the Beacon Monitor window.
//
// THE SEAM established in Phase 1: the caller does not know what this is, only
// that the window opens.
procedure ShowBeaconsMonitor;

implementation

{$R *.lfm}

uses
  uLCLFormHelpers,   // ShowModalOverWin32Parent -- ownership and centring
  VC,           // UTC, RC_BEACONSM, CW
  LogRadio,     // SetRadioFreq, RadioOne
  uBeacons,     // BEACONS, BeaconsNames, FreqArray -- the data stayed put
  MainUnit,     // logger
  uHostedFormWindows,
  Log4D;

const
  // The five columns are the five IBP frequencies, and they are the first five
  // buttons -- so column c sits directly under button 101 + c by construction
  // rather than by coincidence.
  BEACON_COLUMNS = 5;

  // Ten seconds per beacon per band, so eighteen slots fill the three-minute
  // cycle and the slot number IS the row transmitting on the first band.
  SLOTS_PER_CYCLE = BEACONS;

var
  frmBeacons: TfrmBeacons = nil;

// The slot is a pure function of the clock: (minute mod 3) * 6 + second div 10,
// giving 0..17.  UTC is refreshed by the main window's one-second CALLBACK
// timer, which keeps running while this form is modal -- reading the global is
// what the original did, and is why no clock call happens here.  Calling
// tGetSystemTime instead would be WRONG: it is suppressed in hand-log mode,
// where the operator's chosen time is deliberately not the wall clock.
function TfrmBeacons.CurrentSlot: integer;
begin
   Result := (UTC.wMinute mod 3) * 6 + UTC.wSecond div 10;
end;

// Walks the diagonal: the slot's beacon is on the first band, the one before it
// on the second, and so on -- wrapping at the top of the list.
procedure TfrmBeacons.ApplySlot(const aSlot: integer);
var
  c: integer;
  r: integer;
begin
   r := aSlot;

   for c := 0 to BEACON_COLUMNS - 1 do
      begin
      FActiveRow[c] := r;

      if r = 0 then
         begin
         r := SLOTS_PER_CYCLE;
         end;
      Dec(r);
      end;
end;

procedure TfrmBeacons.RefreshIfSlotChanged;
var
  slot: integer;
begin
   slot := CurrentSlot;

   if slot = FSlot then
      begin
      Exit;
      end;

   FSlot := slot;
   ApplySlot(slot);
   grdBeacons.Invalidate;
end;

// The only thing that distinguishes a transmitting beacon from a silent one.
// The original said it with EnableWindow; grey against black is what that
// actually LOOKED like, so this is the same picture by a shorter route.
procedure TfrmBeacons.GridPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                        aState: TGridDrawState);
begin
   if (aCol < 0) or (aCol > High(FActiveRow)) then
      begin
      Exit;
      end;

   if aRow = FActiveRow[aCol] then
      begin
      grdBeacons.Canvas.Font.Color := clWindowText;
      end
   else
      begin
      grdBeacons.Canvas.Font.Color := clGrayText;
      end;
end;

procedure TfrmBeacons.HandleShow(Sender: TObject);
var
  r, c: integer;
  i: integer;
  ts: TTextStyle;
  btn: TSpeedButton;
begin
   RegisterHostedFormHandle(Self.Handle);

   Caption := RC_BEACONSM;

   // The button captions come from FreqArray, so that table stays the single
   // statement of which frequency each button means -- the .lfm carries the
   // position and the Tag, never the number.
   for i := 0 to 9 do
      begin
      btn := FindComponent('sbFreq' + IntToStr(i + 1)) as TSpeedButton;
      btn.Caption := IntToStr(FreqArray[101 + i]);
      end;

   ts := grdBeacons.DefaultTextStyle;
   ts.Alignment := taCenter;
   ts.Layout    := tlCenter;
   grdBeacons.DefaultTextStyle := ts;

   grdBeacons.RowCount := BEACONS;
   grdBeacons.ColCount := BEACON_COLUMNS;

   // Every column shows the same name in a given row, exactly as the ninety
   // statics did.  That is not redundancy: the ROW names the beacon and the
   // COLUMN names the band, so reading down one column answers "who is on
   // 21150 right now".
   for r := 0 to BEACONS - 1 do
      begin
      for c := 0 to BEACON_COLUMNS - 1 do
         begin
         grdBeacons.Cells[c, r] := string(AnsiString(BeaconsNames[r]));
         end;
      end;

   // -1 is not a slot, so the first recompute always draws.
   FSlot := -1;
   for c := 0 to High(FActiveRow) do
      begin
      FActiveRow[c] := -1;
      end;
   RefreshIfSlotChanged;

   sbFreq1.Down := True;
   SetRadioFreq(RadioOne, FreqArray[101] * 1000, CW, 'A');

   tmrSlot.Enabled := True;
end;

procedure TfrmBeacons.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   tmrSlot.Enabled := False;
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
end;

procedure TfrmBeacons.HandleKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
   // Escape was the only way out of the Win32 dialog too -- the dialog manager
   // turned it into IDCANCEL, which the WM_COMMAND arm caught as wParam = 2.
   // This window has no OK and no Cancel, and never did.
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmBeacons.HandleSlotTimer(Sender: TObject);
begin
   RefreshIfSlotChanged;
end;

procedure TfrmBeacons.FrequencyClick(Sender: TObject);
var
  id: integer;
begin
   // The Tag IS the original control id, 101..110, which is also FreqArray's
   // index.  Keeping that numbering rather than renumbering 0..9 means the
   // table did not have to move, and the two halves cannot drift apart.
   id := (Sender as TSpeedButton).Tag;

   if (id < Low(FreqArray)) or (id > High(FreqArray)) then
      begin
      Exit;
      end;

   SetRadioFreq(RadioOne, FreqArray[id] * 1000, CW, 'A');
end;

procedure ShowBeaconsMonitor;
begin
   // The try/except is permanent and deliberate: under FPC an exception that
   // escapes into the main loop is a bare RTE with no class, and it takes the
   // contest log down with it.
   try
      if frmBeacons = nil then
         begin
         frmBeacons := TfrmBeacons.Create(Application);
         end;
      // THROUGH THE ONE DOOR, parent 0.  There is no raw Win32 parent to
      // disable here, but ShowModalOverWin32Parent is also where the main
      // window is made the owner and the form is centred over it -- see
      // OwnFormByMainWindow.  A bare ShowModal skips both.
      ShowModalOverWin32Parent(frmBeacons, 0);
   except
      on E: Exception do
         begin
         if logger <> nil then
            begin
            logger.Error('ShowBeaconsMonitor failed: ' + E.ClassName + ': ' + E.Message);
            end;
         end;
   end;
end;

end.
