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
   public
      constructor Create(const aKind: RemainingMultiplierType; const aIndex: integer;
                         const aWorked: boolean);
      property Kind: RemainingMultiplierType read FKind;
      property Index: integer read FIndex;
      (* Whether it had been worked WHEN THE WINDOW WAS REBUILT -- the text
        beside it is the grid's Cells, written then too (issue 216). *)
      property Worked: boolean read FWorked;
   end;

   TfrmRemMults = class(TForm)
      grdMults: TStringGrid;
      procedure HandleCreate(Sender: TObject);
      procedure HandleDestroy(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure MultsDrawCell(Sender: TObject; aCol, aRow: integer;
                              aRect: TRect; aState: TGridDrawState);
   private
      FIndex: WindowsType;
   public
      Mults: TFlowGrid;

      (* ONE CELL: a multiplier, which IS the pair (kind, index into that
        kind's table), with its text and whether it has been worked, as
        they stand at this rebuild (the builder resolves them). Between
        Mults.BeginRebuild and Mults.EndRebuild. *)
      procedure AddMult(const aKind: RemainingMultiplierType; const aIndex: integer;
                        const aText: string; const aWorked: boolean);

      (* The multiplier in cell aCellIndex; False for a cell past the end --
        the paint handler asks for every cell and the last column is rarely
        full. *)
      function  MultAt(const aCellIndex: integer; out aKind: RemainingMultiplierType;
                       out aIndex: integer): boolean;

      (* Whether the multiplier in cell aCellIndex had been worked at the
        rebuild; False for a cell past the end. *)
      function  WorkedAt(const aCellIndex: integer): boolean;
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
                                  const aIndex: integer; const aWorked: boolean);
begin
   inherited Create;
   FKind := aKind;
   FIndex := aIndex;
   FWorked := aWorked;
end;

(* The text goes into the grid's Cells at EndRebuild (TFlowGrid.LayOut). *)
procedure TfrmRemMults.AddMult(const aKind: RemainingMultiplierType;
                               const aIndex: integer; const aText: string;
                               const aWorked: boolean);
begin
   Mults.AddCell(aText, TRemainingMult.Create(aKind, aIndex, aWorked));
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

(* THE PAINTING IS REPRODUCED AS IT WAS, INCLUDING A COLOUR THAT LOOKS LIKE AN
  ACCIDENT.

  A worked entry is gradiented to white with white text on top, and the colour
  it starts from is INDEXED BY THE MULTIPLIER TYPE'S ORDINAL -- the original
  reads `tr4wColorsArray[tr4wColors(Ord(rmt) * 1)]`.  So which colour a faded
  prefix gets, versus a faded zone, falls out of the order of two unrelated
  enumerations.  Nothing states a relationship and there is no reason for one.

  IT IS REPRODUCED ANYWAY.  This is a conversion; the rule here is prove
  equivalence before a behaviour-preserving swap, and I cannot prove from the
  code that operators have not learned these colours.  It goes to the bench
  queue as a question for NY4I rather than being answered by me.

  Settings.RemainingMults.DisplayMode <> HiLight LEFT THE TEXT COLOUR UNSET in the
  original: neither arm of its `if` ran, so the DC kept whatever it held.  In
  that mode the builder only adds multipliers still NEEDED, so black is what it
  looked like -- black is what it is now, which is the same picture with the
  undefined part defined.

  STILL A DRAW HANDLER, FOR THE GRADIENT ALONE (issue 216). The text and the
  worked state are the cell's, written at the rebuild: the text is the grid's
  Cells, so the grid knows when it changed and no Invalidate is forced. What
  OnPrepareCanvas cannot express is a gradient -- it sets a brush, and a flat
  fill would be a visible change -- so this handler stays until NY4I rules on
  the fade (issue 216). With a flat fill it becomes the
  dupe sheet's OnPrepareCanvas and DefaultDrawing goes back on.

  CLEAN SWEEP IS GONE. Its message was drawn when LOGEDIT.CleanSweep was True,
  and nothing ever set it: the D7 routine that did (LOGWIND
  DisplayRemainingMults) sat inside a REMOVECANDIDATE comment there too. *)
procedure TfrmRemMults.MultsDrawCell(Sender: TObject; aCol, aRow: integer;
                                     aRect: TRect; aState: TGridDrawState);
var
   idx: integer;
   multIndex: integer;
   cellText: string;
   rmt: RemainingMultiplierType;
begin
   grdMults.Canvas.Brush.Style := bsSolid;
   grdMults.Canvas.Brush.Color := clWindow;
   grdMults.Canvas.FillRect(aRect);
   grdMults.Canvas.Font.Color := tr4wColorsArray[trBlack];

   idx := Mults.IndexAt(aCol, aRow);
   if (idx < 0) or (not MultAt(idx, rmt, multIndex)) then
      begin
      Exit;
      end;

   cellText := grdMults.Cells[aCol, aRow];
   if cellText = '' then
      begin
      Exit;
      end;

   if (Settings.RemainingMults.DisplayMode = HiLight) and WorkedAt(idx) then
      begin
      // THE LCL'S OWN GRADIENT, as the band map's mult flag uses: the same
      // two stops and the same left-to-right direction the WM_DRAWITEM arm
      // asked uGradient.GradientRect for, without handing it the canvas's
      // HDC (TCanvas.Handle) to do it.
      grdMults.Canvas.GradientFill(aRect,
                                   tr4wColorsArray[tr4wColors(Ord(rmt))],
                                   tr4wColorsArray[trWhite], gdHorizontal);
      grdMults.Canvas.Font.Color := tr4wColorsArray[trWhite];
      end;

   grdMults.Canvas.Brush.Style := bsClear;      // SetBkMode(TRANSPARENT)
   grdMults.Canvas.TextOut(aRect.Left + 2, aRect.Top, cellText);
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
