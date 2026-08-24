{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uDupesheet;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  uCallsigns,
  VC,
  LogRadio,
  Windows,
  LogEdit,
  LogStuff,
  LogWind,
  uGradient,
  Messages;

procedure ClearAltD;
const
  VDColorsArray                         : array[Ord('0')..Ord('9') + 1] of tr4wColors =
    (
    trWhite, //0 //issue 256
    trRed, //1
    trGreen, //2
    trMagenta, //3
    trLightGray, //4
    trWhite, //5      // issue 256
    trRed, //6
    trGreen, //7
    trMagenta, //8
    trLightGray, ///9
    trWhite  ///10           // issue 256
    );

implementation
uses MainUnit;

 var
    VDCurrentCallDistrict                 : Byte;
procedure ClearAltD;

begin
DupeInfoCallWindowState := diNone;
SetMainWindowText(mweDupeInfoCall, '');
DupeInfoCallWindowCleared := True;
Windows.ShowWindow(wh[mweDupeInfoCall], SW_RESTORE);


end;

{ DupesheetDlgProc IS GONE, and with it every Win32 control this window had.
  Where each arm went, so the next reader does not go looking:

    WM_INITDIALOG    -> DupeSheetWindowShown in uCallsigns, through the form's
                        OnShow seam.  It also built the controls; they are in
                        uDupeSheetForm.lfm.
    WM_DRAWITEM      -> TfrmDupeSheet.DupesDrawCell.  The gradient it called
                        used the SAME colour for both stops, and its white
                        `else` arm could never run (`Left` was 1 and never
                        changed), so what it drew was a solid fill.
    WM_CTLCOLORLISTBOX -> nothing.  Both arms of its `if` returned the same
                        black brush, and it then called GetClientRect and threw
                        the answer away.
    WM_SIZE          -> Align = alClient plus LayOutGrid; the ten-column arm
                        went with COLUMN DUPESHEET ENABLE.
    WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE -> DefTR4WProc.  Not reproduced, as
                        with the stations window: no converted form wires one.
    WM_CLOSE         -> TfrmDupeSheet.HandleClose plus the DupeSheetOnClose
                        seam, which is what clears Radio.tDupeSheetWnd.

  VDColorsArray STAYS HERE.  It is the district colour table and the form reads
  it; moving it would be a second change in a commit that already moves enough. }

end.
