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

  THE CELLS CARRY NO TEXT, AND THAT IS FAITHFUL.  The Win32 list box was
  LBS_OWNERDRAWFIXED without strings, and ShowRemMultsInWindow passed
  MakeLong(Ord(rmt), i) as LB_ADDSTRING's lParam -- A PACKED PAIR, NEVER A
  STRING POINTER.  Its draw handler unpacked that and asked mo.PrfList,
  mo.DomList, CTY.ctyTable or a %02u format for the text on every paint.

  That is kept exactly, and not out of caution: those answers CHANGE AS THE
  CONTEST RUNS.  A multiplier worked between two rebuilds must fade on the next
  paint, and text or dupe state copied at rebuild time would not. }
unit uRemMultsForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, Grids, Graphics,
   VC, LogWind, LogDom, LogDupe, uFlowGrid;

type
   TfrmRemMults = class(TForm)
      grdMults: TDrawGrid;
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
   end;

var
   { What WM_INITDIALOG did beyond building controls: fill the window.
     uRemMults assigns it, because filling means knowing what a multiplier is. }
   RemMultsOnShow: procedure = nil;

   { Resolves one cell to its text and to whether it has been worked.  The form
     can answer neither -- both need the multiplier tables -- so uRemMults
     supplies this at initialization.  aTag is the packed (type, index) pair. }
   RemMultsResolve: procedure(const aTag: PtrInt; out aText: string;
                              out aWorked: boolean) = nil;

function CreateTR4WRemMultsWindow(const aIndex: WindowsType): HWND;
function RemMultsForm(const aIndex: WindowsType): TfrmRemMults;

{ Which multiplier type this window shows.  Four are pinned; the generic one
  follows the operator's RemainingMultDisplay. }
function MultTypeFor(const aIndex: WindowsType): RemainingMultiplierType;

implementation

{$R *.lfm}

uses
   MainUnit,          { CloseTR4WWindow }
   LogEdit,           { CleanSweep }
   uGradient,         { GradientRect -- the faded-multiplier fill }
   uLCLFormHelpers;   { OwnFormByMainWindow }

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
   Mults := TFlowGrid.Create(grdMults, BASECOLUMNWIDTH, CELL_HEIGHT);
end;

procedure TfrmRemMults.HandleDestroy(Sender: TObject);
begin
   FreeAndNil(Mults);
end;

procedure TfrmRemMults.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   CloseAction := caNone;
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

{ THE PAINTING IS REPRODUCED AS IT WAS, INCLUDING A COLOUR THAT LOOKS LIKE AN
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

  RemainingMultDisplayMode <> HiLight LEFT THE TEXT COLOUR UNSET in the
  original: neither arm of its `if` ran, so the DC kept whatever it held.  In
  that mode the builder only adds multipliers still NEEDED, so black is what it
  looked like -- black is what it is now, which is the same picture with the
  undefined part defined.

  CLEAN SWEEP takes the window.  It was drawn at 0,0 over whatever was there. }
procedure TfrmRemMults.MultsDrawCell(Sender: TObject; aCol, aRow: integer;
                                     aRect: TRect; aState: TGridDrawState);
var
   idx: integer;
   cellText: string;
   worked: boolean;
   rmt: RemainingMultiplierType;
begin
   grdMults.Canvas.Brush.Style := bsSolid;
   grdMults.Canvas.Brush.Color := clWindow;
   grdMults.Canvas.FillRect(aRect);
   grdMults.Canvas.Font.Color := tr4wColorsArray[trBlack];

   if CleanSweep then
      begin
      if (aCol = 0) and (aRow = 0) then
         begin
         grdMults.Canvas.Brush.Style := bsClear;
         grdMults.Canvas.TextOut(aRect.Left, aRect.Top,
                                 string(TC_CLEANSWEEPCONGRATULATIONS));
         end;
      Exit;
      end;

   idx := Mults.IndexAt(aCol, aRow);
   if (idx < 0) or (not Assigned(RemMultsResolve)) then
      begin
      Exit;
      end;

   RemMultsResolve(Mults.TagAt(idx), cellText, worked);
   if cellText = '' then
      begin
      Exit;
      end;

   if (RemainingMultDisplayMode = HiLight) and worked then
      begin
      // TCanvas.Handle IS the HDC uGradient wants, so this is the same call the
      // WM_DRAWITEM arm made: same two stops, same direction.
      rmt := RemainingMultiplierType(LoWord(Mults.TagAt(idx)));
      GradientRect(grdMults.Canvas.Handle, aRect,
                   tr4wColorsArray[tr4wColors(Ord(rmt))],
                   tr4wColorsArray[trWhite], gdHorizontal);
      grdMults.Canvas.Font.Color := tr4wColorsArray[trWhite];
      end;

   grdMults.Canvas.Brush.Style := bsClear;      // SetBkMode(TRANSPARENT)
   grdMults.Canvas.TextOut(aRect.Left + 2, aRect.Top, cellText);
end;

function CreateTR4WRemMultsWindow(const aIndex: WindowsType): HWND;
var
   slot: integer;
begin
   slot := SlotOf(aIndex);

   if GForms[slot] = nil then
      begin
      GForms[slot] := TfrmRemMults.Create(nil);
      GForms[slot].FIndex := aIndex;
      end;

   OwnFormByMainWindow(GForms[slot]);

   Result := GForms[slot].Handle;
end;

end.
