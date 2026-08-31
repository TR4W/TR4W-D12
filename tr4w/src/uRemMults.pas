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

{ THE REMAINING-MULTIPLIER WINDOWS -- what the rest of the program says to them,
  and the one thing only this unit can answer.

  RemainingMultsDlgProc IS GONE; the five windows are uRemMultsForm.  Where each
  arm went:

    WM_INITDIALOG -> the .lfm for the control, MultTypeFor for which type the
                     window shows, and RemMultsWindowShown for the fill.  Its
                     per-window tLB_SETCOLUMNWIDTH calls are the grid's cell
                     width; SetRemMultsColumnWidth still decides it.
    WM_DRAWITEM   -> TfrmRemMults.MultsDrawCell, which asks ResolveMult below
                     for the text and the worked flag.  The unpacking of
                     MakeLong(Ord(rmt), i) stays with the packing.
    WM_SIZE       -> Align = alClient plus TFlowGrid.LayOut.
    WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE -> DefTR4WProc.  Not reproduced, as
                     with every converted window before it.
    WM_CLOSE      -> TfrmRemMults.HandleClose.  It used to call
                     GetWindowByHandle to work out WHICH window it was; the
                     form knows.

  RESOLVING A CELL LIVES HERE because it needs mo.PrfList, mo.DomList,
  CTY.ctyTable and the dupe tests -- and the form must not learn what a
  multiplier is. }
unit uRemMults;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  Windows,      { LoWord / HiWord -- unpacking what MakeLong packed }
  TF,
  VC,
  uCTYDAT,
  uMults,
  LogEdit,
  LogWind,
  LogDom,
  LogDupe,
  LOGSUBS2
  ;

procedure UpdateRemainingMultsWindows;

implementation

uses
  SysUtils,   { Format -- replaced TF.Format/wsprintfA }
  Tree,
  MainUnit,
  uRemMultsForm;

var
  RemMultsBuf                           : array[0..7] of AnsiChar;

{ ONE CELL, RESOLVED AT PAINT TIME.

  aTag is MakeLong(Ord(rmt), index) -- exactly what ShowRemMultsInWindow packed
  into LB_ADDSTRING's lParam, unpacked exactly as WM_DRAWITEM unpacked it.

  THE OLD HANDLER READ THE PACKED VALUE TWICE, once for each half, sending
  LB_GETITEMDATA both times.  One argument now, split once. }
procedure ResolveMult(const aTag: PtrInt; out aText: string; out aWorked: boolean);
var
  rmt      : RemainingMultiplierType;
  Index    : integer;
  TempCall : CallString;
begin
  aText := '';
  aWorked := False;

  rmt := RemainingMultiplierType(LoWord(aTag));
  Index := HiWord(aTag);

  case rmt of

    rmPrefix:
      begin
        TempCall := mo.PrfList.Get(Index);
        aText := string(TempCall);
        aWorked := mo.PrfList.StringIsDupeByIndex(Index, MultBand, MultMode);
      end;

    rmDomestic:
      begin
        if tShowDomesticMultiplierName and
           (mo.DomList.FList[Index].FAltName <> '') then
           begin
           TempCall := mo.DomList.FList[Index].FAltName;
           end
        else
           begin
           TempCall := mo.DomList.Get(Index);
           end;
        aText := string(TempCall);
        aWorked := mo.DomList.StringIsDupeByIndex(Index,
                     GetAddMultBand(DomesticMultByBand, MultBand), MultMode);
      end;

    rmDX:
      begin
        aText := string(CTY.ctyTable[Index].ID);
        aWorked := not mo.IsDXMult(Index, MultBand, MultMode);
      end;

    rmZone:
      begin
        aWorked := not mo.IsZnMult(Index, MultBand, MultMode);
        { '%.2u', not '%02u' -- Delphi's Format has no zero-pad flag and would
          space-pad. The buffer goes with the call: aText is already a string. }

        aText := SysUtils.Format('%.2u', [Index]);
      end;
  end;
end;

{ What WM_INITDIALOG did after building its list box. }
procedure RemMultsWindowShown;
begin
  SetRemMultsColumnWidth;
  VisibleLog.ShowRemainingMultipliers;
end;

procedure UpdateRemainingMultsWindows;
begin
  SetRemMultsColumnWidth;
  VisibleLog.ShowRemainingMultipliers;
end;

begin
  RemMultsOnShow := @RemMultsWindowShown;
  RemMultsResolve := @ResolveMult;
end.
