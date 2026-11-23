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

{ THE REMAINING-MULTIPLIER WINDOWS -- FIVE OF THEM, one form class.

  Sixth tw_ window through OpenTR4WWindow's seam, and the widest: one dialog
  procedure served tw_REMMULTSWINDOW_INDEX and the four fixed-type windows (DX,
  zone, domestic, prefix), telling them apart by the lParam they were created
  with.  Five instances of this class, addressed by tw_ index.

  THE GENERIC WINDOW'S TYPE IS NOT FIXED.  tw_REMMULTSWINDOW_INDEX shows
  RemainingMultDisplay, which the operator swaps at run time; the other four are
  pinned to one type each.  MultTypeFor is the one place that says so.

  THE CELLS CARRY THEIR TEXT, WRITTEN AT THE REBUILD (issue 216, decision A).
  The Win32 list box was LBS_OWNERDRAWFIXED without strings: each item was a
  packed (kind, index) pair and the draw handler looked the text and the
  worked state up on every paint, from mo.PrfList, mo.DomList, CTY.ctyTable
  or a %.2u format. Those answers change as the contest runs, which is why
  they were looked up late.

  NY4I chose to write them at the rebuild instead (issue 216): the builder,
  LOGEDIT.ShowRemMultsInWindow, resolves each multiplier as it adds it
  (uRemMults.ResolveRemainingMult) and the text goes into the grid's own
  Cells; the grid paints itself. So the window is right exactly when it has
  been rebuilt since the multiplier state changed -- a stale cell is a missing
  VisibleLog.ShowRemainingMultipliers call, never a repaint problem. The
  places that change that state and rebuild it are listed at
  ShowRemMultsInWindow. }
unit uRemMultsForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, Grids, Graphics,
   VC, LogWind, LogDom, LogDupe, uFlowGrid;

type
   (* A REMAINING MULTIPLIER, AS A TYPE: the pair (kind, index into that
     kind's table) is its identity. It existed nowhere as a type and lived
     only as two 16-bit halves of the grid's Objects[] slot, packed in
     logedit and unpacked here and in uRemMults with LoWord/HiWord --
     WIN32_ARTIFACT_SWEEP.md's worked example (pointer audit P9, item 5.1).
     A cell the grid owns now. *)
   TRemainingMult = class
   private
      FKind: RemainingMultiplierType;
      FIndex: integer;
      FWorked: boolean;
      FBackupWanted: boolean;
   public
      constructor Create(const aKind: RemainingMultiplierType; const aIndex: integer;
                         const aWorked, aBackupWanted: boolean);
      property Kind: RemainingMultiplierType read FKind;
      property Index: integer read FIndex;
      (* Whether it had been worked WHEN THE WINDOW WAS REBUILT -- the text
        beside it is the grid's Cells, written then too (issue 216). *)
      property Worked: boolean read FWorked;
      (* Whether, at the rebuild, it was worked fewer times than BAND MAP
        WORKED MULT LIMIT -- a backup wanted, drawn in BAND MAP WORKED MULT
        COLOR (issue 357; the rule is uRemMultWorkState's). *)
      property BackupWanted: boolean read FBackupWanted;
   end;

   TfrmRemMults = class(TForm)
      grdMults: TStringGrid;
      procedure HandleCreate(Sender: TObject);
      procedure HandleDestroy(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure MultsPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                   aState: TGridDrawState);
   private
      FIndex: WindowsType;
      procedure ApplyGridLineColor;
   public
      Mults: TFlowGrid;

      (* ONE CELL: a multiplier, which IS the pair (kind, index into that
        kind's table), with its text and whether it has been worked, as
        they stand at this rebuild (the builder resolves them). Between
        Mults.BeginRebuild and Mults.EndRebuild. aBackupWanted: worked, but
        fewer times than BAND MAP WORKED MULT LIMIT (issue 357). *)
      procedure AddMult(const aKind: RemainingMultiplierType; const aIndex: integer;
                        const aText: string; const aWorked: boolean;
                        const aBackupWanted: boolean = False);

      (* The multiplier in cell aCellIndex; False for a cell past the end --
        the paint handler asks for every cell and the last column is rarely
        full. *)
      function  MultAt(const aCellIndex: integer; out aKind: RemainingMultiplierType;
                       out aIndex: integer): boolean;

      (* Whether the multiplier in cell aCellIndex had been worked at the
        rebuild; False for a cell past the end. *)
      function  WorkedAt(const aCellIndex: integer): boolean;

      (* Whether the multiplier in cell aCellIndex wanted a backup at the
        rebuild; False for a cell past the end. *)
      function  BackupWantedAt(const aCellIndex: integer): boolean;
   end;

var
   { What WM_INITDIALOG did beyond building controls: fill the window.
     uRemMults assigns it, because filling means knowing what a multiplier is. }
   RemMultsOnShow: procedure = nil;

   (* RemMultsResolve, THE PAINT-TIME LOOKUP, IS GONE (issue 216): the builder
     resolves each multiplier when it adds it -- uRemMults.ResolveRemainingMult,
     called from LOGEDIT.ShowRemMultsInWindow -- so this form still never
     learns what a multiplier is. *)

procedure CreateTR4WRemMultsWindow(const aIndex: WindowsType);
function RemMultsForm(const aIndex: WindowsType): TfrmRemMults;

{ Which multiplier type this window shows.  Four are pinned; the generic one
  follows the operator's RemainingMultDisplay. }
function MultTypeFor(const aIndex: WindowsType): RemainingMultiplierType;

implementation

{$R *.lfm}

uses
   MainUnit,          { CloseTR4WWindow }
   uSettingsModel,    (* Settings.RemainingMults.DisplayMode, and HiLight --
                        the type moved here with the setting *)
   uSpots,            (* WorkedMultColor -- BAND MAP WORKED MULT COLOR, issue 357 *)
   uRemMultWorkState, (* TRemMultWorkState, RemainingMultCellStyle *)
   uLogGrid,          (* LogSoftRuleColor -- the log's light rule, shared *)
   uLCLFormHelpers;   // LeaveFormUnowned

const
   CELL_HEIGHT = 16;

var
   { Slots in tw_ order: generic, DX, domestic, zone, prefix. }
   GForms: array[0..4] of TfrmRemMults = (nil, nil, nil, nil, nil);

function SlotOf(const aIndex: WindowsType): integer;
begin
   case aIndex of
      tw_STATIONS_RM_DX:     Result := 1;
      tw_STATIONS_RM_DOM:    Result := 2;
      tw_STATIONS_RM_ZONE:   Result := 3;
      tw_STATIONS_RM_PREFIX: Result := 4;
   else
      Result := 0;                      // tw_REMMULTSWINDOW_INDEX
   end;
end;

function MultTypeFor(const aIndex: WindowsType): RemainingMultiplierType;
begin
   case aIndex of
      tw_STATIONS_RM_DX:     Result := rmDX;
      tw_STATIONS_RM_DOM:    Result := rmDomestic;
      tw_STATIONS_RM_ZONE:   Result := rmZone;
      tw_STATIONS_RM_PREFIX: Result := rmPrefix;
   else
      Result := RemainingMultDisplay;
   end;
end;

function RemMultsForm(const aIndex: WindowsType): TfrmRemMults;
begin
   Result := GForms[SlotOf(aIndex)];
end;

procedure TfrmRemMults.HandleCreate(Sender: TObject);
begin
   Mults := TFlowGrid.Create(grdMults, BASECOLUMNWIDTH, CELL_HEIGHT);   // owns its TRemainingMult cells
   ApplyGridLineColor;
end;

(* A LIGHT LINE BETWEEN CELLS (NY4I, 2026-11-22). Two neighbouring backups
  wanted are flat fills of BAND MAP WORKED MULT COLOR and ran together into one
  block. The lines themselves are the grid's own (goVertLine ALONE, in the .lfm:
  vertical only, like the log -- NY4I, 2026-11-22, the horizontal ones went, drawn by the LCL's DrawCellGrid after OnPrepareCanvas's fill); this
  only picks their colour, from the window colour MultsPrepareCanvas fills a
  needed cell with, through the main log's rule (uLogGrid.LogSoftRuleColor) so
  the two windows cannot drift. SHOW GRIDLINES is the main log's setting
  (Settings.MainWindow) and does not govern this window: the line is always
  shown here.

  Called at create and again at every show, because the form is hidden and
  reused (caHide) and the system window colour can change between opens. Never
  from MultsPrepareCanvas: assigning GridLineColor invalidates the grid. *)
procedure TfrmRemMults.ApplyGridLineColor;
begin
   grdMults.GridLineColor := TColor(LogSoftRuleColor(longint(ColorToRGB(clWindow))));
end;

procedure TfrmRemMults.HandleDestroy(Sender: TObject);
var
   slot: integer;
begin
   FreeAndNil(Mults);

   (* A FREED FORM LEAVES NO SLOT POINTING AT IT. The program never frees
     these, but a test that opens one through CreateTR4WRemMultsWindow does,
     and the next CreateTR4WRemMultsWindow would hand back freed memory. *)
   for slot := Low(GForms) to High(GForms) do
      begin
      if GForms[slot] = Self then
         begin
         GForms[slot] := nil;
         end;
      end;
end;

constructor TRemainingMult.Create(const aKind: RemainingMultiplierType;
                                  const aIndex: integer;
                                  const aWorked, aBackupWanted: boolean);
begin
   inherited Create;
   FKind := aKind;
   FIndex := aIndex;
   FWorked := aWorked;
   FBackupWanted := aBackupWanted;
end;

(* The text goes into the grid's Cells at EndRebuild (TFlowGrid.LayOut). *)
procedure TfrmRemMults.AddMult(const aKind: RemainingMultiplierType;
                               const aIndex: integer; const aText: string;
                               const aWorked: boolean;
                               const aBackupWanted: boolean);
begin
   Mults.AddCell(aText, TRemainingMult.Create(aKind, aIndex, aWorked, aBackupWanted));
end;

function TfrmRemMults.BackupWantedAt(const aCellIndex: integer): boolean;
var
   cell: TObject;
begin
   cell := Mults.CellAt(aCellIndex);
   Result := (cell is TRemainingMult) and TRemainingMult(cell).BackupWanted;
end;

function TfrmRemMults.WorkedAt(const aCellIndex: integer): boolean;
var
   cell: TObject;
begin
   cell := Mults.CellAt(aCellIndex);
   Result := (cell is TRemainingMult) and TRemainingMult(cell).Worked;
end;

function TfrmRemMults.MultAt(const aCellIndex: integer;
                             out aKind: RemainingMultiplierType;
                             out aIndex: integer): boolean;
var
   cell: TObject;
begin
   aKind := rmNoRemMultDisplay;
   aIndex := 0;
   cell := Mults.CellAt(aCellIndex);
   Result := cell is TRemainingMult;
   if Result then
      begin
      aKind := TRemainingMult(cell).Kind;
      aIndex := TRemainingMult(cell).Index;
      end;
end;

procedure TfrmRemMults.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // caHIDE, NOT caNone.  caNone leaves the form VISIBLE as far as the LCL is
   // concerned, and CloseTR4WWindow then destroys the handle underneath it --
   // so the widget set recreates it and the window will not go away.  NY4I:
   // "Clicking on the X on the Stations window does not close it. Nor does
   // hitting the accelerator key again" (bench queue, 2026-08).  The six
   // windows converted later all use caHide and close correctly; these five
   // were the early ones.
   CloseAction := caHide;
   CloseTR4WWindow(FIndex);
end;

procedure TfrmRemMults.HandleKeyDown(Sender: TObject; var Key: Word;
                                     Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmRemMults.HandleShow(Sender: TObject);
begin
   ApplyGridLineColor;
   if Assigned(RemMultsOnShow) then
      begin
      RemMultsOnShow;
      end;
end;

procedure TfrmRemMults.HandleResize(Sender: TObject);
begin
   if Mults <> nil then
      begin
      Mults.LayOut;
      end;
end;

(* THE GRID DRAWS ITS OWN CELLS; THIS ONLY SETS THEIR COLOURS (2026-11-22, the
  UI refresh proposal's "Multiplier and related grids"). The text is the
  grid's Cells, written at the rebuild (issue 216), so the grid knows when it
  changed and no Invalidate is forced.

  THE GRADIENT IS GONE, and with it the draw handler and DefaultDrawing =
  False. A worked multiplier used to fade from a colour INDEXED BY THE
  MULTIPLIER TYPE'S ORDINAL (tr4wColorsArray[tr4wColors(Ord(rmt))]) to white,
  under white text -- a colour nobody chose, and the most visual weight on the
  least useful cell. Now (uRemMultWorkState.RemainingMultCellStyle, unit
  tested): a needed multiplier is the window's own text with no fill, a
  worked one is a FLAT fill of the window's text colour under the window's
  colour (black under white by default -- NY4I's ruling of 2026-11-22: the
  pre-refresh black, without the fade), and a backup wanted (issue 357) is a
  FLAT fill of BAND MAP WORKED MULT COLOR -- the band map's orange M, the
  same meaning -- with black or white text, whichever reads on the
  operator's colour.

  Every colour is resolved with ColorToRGB before the leaf sees it: clWindow,
  clWindowText and a BTNFACE or HIGHLIGHT the operator may have picked are
  system colours, not RGB values.

  A cell past the end (idx < 0) is drawn as an empty needed cell: the window,
  no text.

  CLEAN SWEEP IS GONE. Its message was drawn when LOGEDIT.CleanSweep was True,
  and nothing ever set it: the D7 routine that did (LOGWIND
  DisplayRemainingMults) sat inside a REMOVECANDIDATE comment there too. *)
procedure TfrmRemMults.MultsPrepareCanvas(Sender: TObject; aCol, aRow: integer;
                                          aState: TGridDrawState);
var
   idx: integer;
   state: TRemMultWorkState;
   backRGB: longint;
   foreRGB: longint;
   bold: boolean;
begin
   state := rwsNeeded;
   idx := Mults.IndexAt(aCol, aRow);
   if idx >= 0 then
      begin
      if BackupWantedAt(idx) then
         begin
         state := rwsBackupWanted;
         end
      else if WorkedAt(idx) then
         begin
         state := rwsWorked;
         end;
      end;

   RemainingMultCellStyle(state,
                          Settings.RemainingMults.DisplayMode = HiLight,
                          ColorToRGB(clWindow),
                          ColorToRGB(clWindowText),
                          ColorToRGB(tr4wColorsArray[WorkedMultColor]),
                          backRGB, foreRGB, bold);

   grdMults.Canvas.Brush.Color := TColor(backRGB);
   grdMults.Canvas.Font.Color := TColor(foreRGB);
   if bold then
      begin
      grdMults.Canvas.Font.Style := grdMults.Canvas.Font.Style + [fsBold];
      end
   else
      begin
      grdMults.Canvas.Font.Style := grdMults.Canvas.Font.Style - [fsBold];
      end;
end;

procedure CreateTR4WRemMultsWindow(const aIndex: WindowsType);
var
   slot: integer;
begin
   slot := SlotOf(aIndex);

   if GForms[slot] = nil then
      begin
      GForms[slot] := TfrmRemMults.Create(nil);
      GForms[slot].FIndex := aIndex;
      end;

   LeaveFormUnowned(GForms[slot]);

end;

end.
