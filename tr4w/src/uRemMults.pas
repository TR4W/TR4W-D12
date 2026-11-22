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
    WM_DRAWITEM   -> the grid's own drawing; TfrmRemMults.MultsPrepareCanvas
                     colours each cell from the worked flag the REBUILD stored:
                     LOGEDIT.ShowRemMultsInWindow asks ResolveRemainingMult
                     below for each cell (issue 216).
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
  TF,
  VC,
  uCTYDAT,
  uMults,
  LogEdit,
  LogWind,
  LogDom,
  LogDupe,
  LOGSUBS2,
  uContestBase   (* TContestBase -- ResolveRemainingMult's aContest, issue 357 *)
  ;

procedure UpdateRemainingMultsWindows;

(* ONE REMAINING MULTIPLIER'S TEXT, AND WHETHER IT HAS BEEN WORKED, as the
  multiplier sheets say NOW. LOGEDIT.ShowRemMultsInWindow asks it for each
  cell as it rebuilds the window, and the text goes into the grid's Cells
  (issue 216, decision A). It was asked at paint time, through the
  RemMultsResolve procedure variable, until then.

  aCount IS HOW MANY TIMES IT IS WORKED on the window's band and mode
  (issue 357): the sheet's count, mo.WorkedCount, asked with the keys the
  sheet writes it under (LOGDUPE.MultiplierSheetBand on MultBand, and
  MultMode, which is already LOGDUPE.MultiplierSheetMode of the active mode)
  -- the band map's DetermineMultStatus asks the same cell. aText is the bare
  name; uRemMultWorkState decides what the count adds to it. aContest is the
  active contest (nil for the classless one), asked once by the caller per
  rebuild rather than once per cell: it shapes the domestic count key. *)
procedure ResolveRemainingMult(const aKind: RemainingMultiplierType; const aIndex: integer;
                               aContest: TContestBase;
                               out aText: string; out aWorked: boolean; out aCount: integer);

implementation

uses
  SysUtils,   { Format -- replaced TF.Format/wsprintfA }
  Tree,
  MainUnit,
  uSettingsModel,   { Settings.RemainingMults -- was tShowDomesticMultiplierName }
  uRemMultsForm;

var
  RemMultsBuf                           : array[0..7] of AnsiChar;

(* ONE CELL, RESOLVED WHEN THE WINDOW IS REBUILT (issue 216).

  A multiplier is the pair (kind, index into that kind's table), and it
  arrives as the pair. It used to arrive as MakeLong(Ord(rmt), index), what
  the Win32 list box's one lParam per item forced, and was unpacked here with
  LoWord/HiWord (pointer audit P9, item 5.1). *)
procedure ResolveRemainingMult(const aKind: RemainingMultiplierType; const aIndex: integer;
                               aContest: TContestBase;
                               out aText: string; out aWorked: boolean; out aCount: integer);
var
  rmt      : RemainingMultiplierType;
  Index    : integer;
  TempCall : CallString;
begin
  aText := '';
  aWorked := False;
  aCount := 0;

  rmt := aKind;
  Index := aIndex;

  case rmt of

    rmPrefix:
      begin
        TempCall := mo.PrfList.Get(Index);
        aText := string(TempCall);
        aWorked := mo.PrfList.StringIsDupeByIndex(Index, MultBand, MultMode);
        aCount := mo.WorkedCount(rmPrefix, string(TempCall),
                                 MultiplierSheetBand(rmPrefix, MultBand), MultMode);
      end;

    rmDomestic:
      begin
        if Settings.RemainingMults.ShowDomesticName and
           (mo.DomList.AltName[Index] <> '') then
           begin
           TempCall := mo.DomList.AltName[Index];
           end
        else
           begin
           TempCall := mo.DomList.Get(Index);
           end;
        aText := string(TempCall);
        aWorked := mo.DomList.StringIsDupeByIndex(Index,
                     GetAddMultBand(DomesticMultByBand, MultBand), MultMode);
        (* The KEY, never the AltName shown in its place: the count is keyed
          as LOGDUPE.CountWorkedMultipliers writes it. *)
        aCount := mo.WorkedCount(rmDomestic,
                                 DomesticMultiplierCountKey(aContest,
                                                            string(mo.DomList.Get(Index))),
                                 MultiplierSheetBand(rmDomestic, MultBand), MultMode);
      end;

    rmDX:
      begin
        aText := string(CTY.ctyTable[Index].ID);
        aWorked := not mo.IsDXMult(Index, MultBand, MultMode);
        (* Index is the CTY country number, the one SetDXMult and
          CountWorkedMultipliers take from the QSO's QTH.Country. *)
        aCount := mo.WorkedCount(rmDX, IntToStr(Index),
                                 MultiplierSheetBand(rmDX, MultBand), MultMode);
      end;

    rmZone:
      begin
        aWorked := not mo.IsZnMult(Index, MultBand, MultMode);
        (* Index is the zone number itself (mo.RemainingZoneIndices), the
          one SetZnMult and CountWorkedMultipliers take from the QSO. *)
        aCount := mo.WorkedCount(rmZone, IntToStr(Index),
                                 MultiplierSheetBand(rmZone, MultBand), MultMode);
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
end.
