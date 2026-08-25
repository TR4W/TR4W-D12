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

{ THE SUPER CHECK PARTIAL WINDOW, as an LCL form.  Fifth tw_ window to convert.

  The grid, the model and the down-then-across arithmetic are TFlowGrid, shared
  with the dupe sheet -- see uFlowGrid for why that was extracted rather than
  copied.  What is here is what is DIFFERENT about this window: it shows as many
  partial matches as fit and drops the rest, and it paints dupes.

  NO SCROLLBAR, AND THAT IS THE OLD BEHAVIOUR.  The Win32 list box was capped at
  MaxItemsInMasterListBox -- how many 80x16 cells the window could show,
  recomputed in its WM_SIZE handler -- and DisplaySCPCall simply stopped adding
  once it hit that.  TFlowGrid.LimitToVisible is that cap, and the commented-out
  '...' the old code never added is still not added. }
unit uMasterForm;

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, LCLType, Forms, Controls, Grids, Graphics, VC, uFlowGrid;

type
   TfrmMaster = class(TForm)
      grdMaster: TDrawGrid;
      procedure HandleCreate(Sender: TObject);
      procedure HandleDestroy(Sender: TObject);
      procedure HandleClose(Sender: TObject; var CloseAction: TCloseAction);
      procedure HandleShow(Sender: TObject);
      procedure HandleResize(Sender: TObject);
      procedure HandleKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure MasterDrawCell(Sender: TObject; aCol, aRow: integer;
                               aRect: TRect; aState: TGridDrawState);
   public
      Calls: TFlowGrid;
   end;

{ What WM_INITDIALOG did beyond building controls.  uMaster assigns it. }
var
   MasterOnShow: procedure = nil;

var
   TR4WMasterForm: TfrmMaster = nil;

function CreateTR4WMasterWindow: HWND;

implementation

{$R *.lfm}

uses
   MainUnit,          { CloseTR4WWindow }
   LogWind,           { SCPDupeColor }
   uLCLFormHelpers;   { OwnFormByMainWindow }

const
   { The cell the Win32 list box was given: tLB_SETCOLUMNWIDTH(hwnddlg, 80),
     and OneMasterItemWidtht / OneMasterItemHeight, which were the same two
     numbers written down a second time so WM_SIZE could divide by them. }
   CELL_WIDTH  = 80;
   CELL_HEIGHT = 16;

procedure TfrmMaster.HandleCreate(Sender: TObject);
begin
   Calls := TFlowGrid.Create(grdMaster, CELL_WIDTH, CELL_HEIGHT);
   Calls.LimitToVisible := True;
end;

procedure TfrmMaster.HandleDestroy(Sender: TObject);
begin
   FreeAndNil(Calls);
end;

procedure TfrmMaster.HandleClose(Sender: TObject; var CloseAction: TCloseAction);
begin
   // caHIDE, NOT caNone.  caNone leaves the form VISIBLE as far as the LCL is
   // concerned, and CloseTR4WWindow then destroys the handle underneath it --
   // so the widget set recreates it and the window will not go away.  NY4I:
   // "Clicking on the X on the Stations window does not close it. Nor does
   // hitting the accelerator key again" (bench queue, 2026-08).  The six
   // windows converted later all use caHide and close correctly; these five
   // were the early ones.
   CloseAction := caHide;
   CloseTR4WWindow(tw_MASTERWINDOW_INDEX);
end;

procedure TfrmMaster.HandleKeyDown(Sender: TObject; var Key: Word;
                                   Shift: TShiftState);
begin
   if Key = VK_ESCAPE then
      begin
      Key := 0;
      Close;
      end;
end;

procedure TfrmMaster.HandleShow(Sender: TObject);
begin
   if Assigned(MasterOnShow) then
      begin
      MasterOnShow;
      end;
end;

procedure TfrmMaster.HandleResize(Sender: TObject);
begin
   if Calls <> nil then
      begin
      Calls.LayOut;
      end;
end;

{ A DUPE IS GRADIENTED; EVERYTHING ELSE IS PLAIN.

  This is the one place the SCP window and the dupe sheet genuinely differ, and
  it is why uFlowGrid does not try to own the painting.  The gradient runs from
  SCPDupeColor to white and the text goes white on top of it -- an operator
  scanning partial matches needs the ones already worked to fall away, not to
  be colour-coded. }
procedure TfrmMaster.MasterDrawCell(Sender: TObject; aCol, aRow: integer;
                                    aRect: TRect; aState: TGridDrawState);
var
   idx: integer;
begin
   idx := Calls.IndexAt(aCol, aRow);

   grdMaster.Canvas.Brush.Style := bsSolid;

   if idx < 0 then
      begin
      grdMaster.Canvas.Brush.Color := clWindow;
      grdMaster.Canvas.FillRect(aRect);
      Exit;
      end;

   if Calls.TagAt(idx) <> 0 then
      begin
      // GradientFill rather than the uGradient helper: that one takes an HDC
      // and this is a TCanvas.  Same two stops, same direction.
      grdMaster.Canvas.Brush.Color := tr4wColorsArray[SCPDupeColor];
      grdMaster.Canvas.FillRect(aRect);
      grdMaster.Canvas.Font.Color := tr4wColorsArray[trWhite];
      end
   else
      begin
      grdMaster.Canvas.Brush.Color := clWindow;
      grdMaster.Canvas.FillRect(aRect);
      grdMaster.Canvas.Font.Color := tr4wColorsArray[trBlack];
      end;

   grdMaster.Canvas.Brush.Style := bsClear;      // SetBkMode(TRANSPARENT)
   grdMaster.Canvas.TextOut(aRect.Left + 2, aRect.Top, Calls.TextAt(idx));
end;

function CreateTR4WMasterWindow: HWND;
begin
   if TR4WMasterForm = nil then
      begin
      TR4WMasterForm := TfrmMaster.Create(nil);
      end;

   OwnFormByMainWindow(TR4WMasterForm);

   Result := TR4WMasterForm.Handle;
end;

end.
