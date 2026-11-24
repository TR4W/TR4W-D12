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
unit uTotal;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  TF,
  VC,
  uMults,
  PostUnit,
  LogWind,
  LogDupe,
  LogEdit,
  Tree
  ,
  uTR4WStrings;

var
  TotWinCurrrentColumn             : integer;
  Column                           : integer;
  Row                              : integer;

procedure DisplayBandTotals(Band: BandType);
procedure UpdateTotals2;
procedure ClearTotals(StartColumn: integer);

implementation

uses
   Log4D,
   (* The totals grid itself. It was eight columns of Win32 STATICs whose
     handles this unit reached through a global array; it is designed LCL
     panels now and this unit addresses cells by (column, row).

     THE NOTE BELOW ABOUT NOT DRAGGING IN MainUnit still holds as intent, and
     uMainGrids is deliberately narrow -- but the compiler bug that made it
     urgent was dcc32's, and dcc32 has been gone from this tree since August. *)
   uMainGrids,
   uSettingsModel,   // Settings.Qso / .Mult / .Qtc -- the contest's own rules
   (* ContestIdentity(Contest).TotalsDisplay -- what the contest shows
     differently (M9a). *)
   uContestBase,
   uContestRegistry,
   (* Both modes' multipliers in one cell -- issue 55. *)
   uTotalsModeText;
   (* uContestSession STOOD HERE for ContestSession.Doing*Mults (M11 S2);
     all four are the contest's answers since M11 S6 part 2
     (LOGEDIT.Doing*Mults). *)

var
   // This unit's own reference to the program's log category, rather than
   // MainUnit's global.  GetLogger is a repository lookup, so this IS the same
   // instance tr4w.lpr configures -- and it keeps a display unit from dragging
   // the whole main-window unit graph in, which is what made dcc32 die with an
   // internal error on a cold build (see 8e4cafac).
   logger: TLogLogger;

   (* THE MULTIPLIER SLOTS THE TOTALS SHOW, IN ORDER -- issue 55. Chosen once
     per UpdateTotals2 by ChooseTotalsMultModes and read by both of its
     passes: the row labels (WriteMultRowLabel) and DisplayBandTotals' values
     (WriteMultRowValue), whose only caller is UpdateTotals2. One list, so a
     label and its numbers cannot name different modes. Count 0 when the
     contest does not count multipliers by mode. *)
   GMultSlots: array[0..2] of ModeType;
   GMultSlotCount: integer;

procedure TotalTextOut(s: string; X, Y: integer);
begin
   (* THE GRID IS FIXED AT 8 x 4 AND THE CALLERS DO NOT CHECK.

     WriteLeftColumnText and iTotalTextOut both do a bare `inc(Row)` with no
     bound, and enough conditional rows -- CW plus Phone plus Digital, or the
     mult labels -- reach Row = 4. NY4I hit exactly that at startup
     2026-08-07:  uTotal.TotalTextOut ('DX Mults', 0, 4).

     THE GUARD, AND THE ACCOUNT OF WHAT IT PREVENTED, MOVED TO
     uMainGrids.SetTotalsCell -- with the grid, so that one place knows the
     grid's shape. It is still reported and still not swallowed. *)
   SetTotalsCell(X, Y, s);
end;

procedure WriteLeftColumnText(Text: string);
(* string, not PAnsiChar: every caller passes a TC_ constant, and those are
  resourcestrings now. TotalTextOut above has taken a string all along, so
  this parameter was converting one to a pointer and straight back. *)
begin
   inc(Row);
   TotalTextOut(Text, 0, Row);
end;

procedure iTotalTextOut(Number: integer);
var
   TempText: string;
begin
   inc(Row);

   if Number = 0 then
      begin
      TempText := '';
      end
   else
      begin
      TempText := IntToStr(Number);
      end;
   TotalTextOut(TempText, Column, Row);
end;

(* WHICH MULTIPLIER MODES THE TOTALS SHOW -- issue 55, NY4I's option (a).

  The active mode, and every other mode the contest credits that has QSOs,
  in the QSO rows' order (CW, phone, digital) -- the rule the QSO rows above
  already use to show a mode. Each is the multiplier sheet's SLOT for that
  mode (LOGDUPE.MultiplierSheetMode), listed once: the Louisiana QSO Party
  counts digital multipliers with CW (issue 122), so its digital QSOs add no
  third number.

  The active mode is always included, so with one slot that slot is
  MultiplierSheetMode(active mode) -- what the cell showed before this. *)
procedure ChooseTotalsMultModes(const aActiveMode: ModeType);
const
   CANDIDATES: array[0..2] of ModeType = (CW, Phone, Digital);
var
   i, j: integer;
   mode: ModeType;
   slot: ModeType;
   listed: boolean;
begin
   GMultSlotCount := 0;

   if not Settings.Mult.ByMode then
      begin
      Exit;
      end;

   for i := Low(CANDIDATES) to High(CANDIDATES) do
      begin
      mode := CANDIDATES[i];
      if (mode = aActiveMode) or
         ((QTotals[AllBands, mode] > 0) and
          ContestCreditsModeKey(ContestIdentity(Contest), mode)) then
         begin
         slot := MultiplierSheetMode(mode);

         listed := False;
         for j := 0 to GMultSlotCount - 1 do
            begin
            if GMultSlots[j] = slot then
               begin
               listed := True;
               end;
            end;

         if not listed then
            begin
            GMultSlots[GMultSlotCount] := slot;
            Inc(GMultSlotCount);
            end;
         end;
      end;
end;

(* The tag a slot is shown under: uTotalsModeText's. *)
function MultSlotTag(const aSlot: ModeType): string;
begin
   case aSlot of
      CW:
         begin
         Result := TOTALS_TAG_CW;
         end;
      Phone:
         begin
         Result := TOTALS_TAG_PHONE;
         end;
   else
      begin
      Result := TOTALS_TAG_DIGITAL;
      end;
   end;
end;

(* THE LABEL OF ONE MULTIPLIER ROW. Not by mode: the all-modes caption, as
  before. By mode with ONE slot: the CW or phone caption, as before -- and
  for a digital slot 'Dig' and the shared word, where before NO label was
  written and the numbers below slid up a row. By mode with several slots:
  'CW/Ph Dom' (uTotalsModeText.TotalsByModeCaption). *)
procedure WriteMultRowLabel(const aCWCaption, aPhoneCaption, aAllModesCaption: string);
var
   tags: array of string;
   i: integer;
begin
   if not Settings.Mult.ByMode then
      begin
      WriteLeftColumnText(aAllModesCaption);
      Exit;
      end;

   if GMultSlotCount = 0 then
      begin
      (* No CW, phone or digital active mode: no label, as before. *)
      Exit;
      end;

   if GMultSlotCount = 1 then
      begin
      if GMultSlots[0] = CW then
         begin
         WriteLeftColumnText(aCWCaption);
         end
      else if GMultSlots[0] = Phone then
         begin
         WriteLeftColumnText(aPhoneCaption);
         end
      else
         begin
         WriteLeftColumnText(TotalsByModeCaption([MultSlotTag(GMultSlots[0])],
                                                 aCWCaption, aPhoneCaption,
                                                 aAllModesCaption));
         end;
      Exit;
      end;

   SetLength(tags, GMultSlotCount);
   for i := 0 to GMultSlotCount - 1 do
      begin
      tags[i] := MultSlotTag(GMultSlots[i]);
      end;
   WriteLeftColumnText(TotalsByModeCaption(tags, aCWCaption, aPhoneCaption,
                                           aAllModesCaption));
end;

(* THE NUMBERS OF ONE MULTIPLIER ROW IN Band's column. With one slot (or not
  by mode) exactly what the cell always showed: aSheetMode's count, blank for
  0. With several: every slot's count in one cell, '12/6'. *)
procedure WriteMultRowValue(const aBand: BandType; const aSheetMode: ModeType;
                            const aKind: RemainingMultiplierType);
var
   counts: array of integer;
   i: integer;
begin
   if (not Settings.Mult.ByMode) or (GMultSlotCount <= 1) then
      begin
      iTotalTextOut(mo.MTotals[aBand, aSheetMode, aKind]);
      Exit;
      end;

   SetLength(counts, GMultSlotCount);
   for i := 0 to GMultSlotCount - 1 do
      begin
      counts[i] := mo.MTotals[aBand, GMultSlots[i], aKind];
      end;

   inc(Row);
   TotalTextOut(TotalsModeCountsText(counts), Column, Row);
end;

procedure DisplayBandTotals(Band: BandType);

var
  MultDisplayEnable                : boolean;
//  col_title                             : PChar;
  ActiveMode                       : ModeType;
  TempMode                         : ModeType;
begin
  ActiveMode := LogWind.ActiveMode;
  if ActiveMode = FM then
     begin
     ActiveMode := Phone;
     end;
 

  if Band = NoBand then
     begin
     ClearTotals(1);
     Exit;
     end;
//  col_title := BandStringsArrayWithOutSpaces[Band];
  inc(Column);
  if Band = AllBands then
     begin
     Column := 7;
     end;
  {
    if Band in [Band160..Band10] then Column := integer(Band) + 1;

    if Band in [Band30..Band12] then
      begin
        if Band = Band30 then Column := 1;
        if Band = Band20 then Column := 2;
        if Band = Band17 then Column := 3;
        if Band = Band15 then Column := 4;
        if Band = Band12 then Column := 5;
        if Band = Band10 then Column := 6;
      end;

    if Band > Band10 then
      begin
        if Band in [Band6..Band1296] then Column := integer(Band) - 8;
      end;

    if Band > Band1296 then
      begin
        if Band in [Band2304..BandLight] then Column := integer(Band) - 14;
      end;
  }
  if Band = ActiveBand then
     begin
     //      Windows.SendMessage(TotWinheadHandles[Column], BM_SETCHECK, BST_CHECKED, 0);
   TotWinCurrrentColumn := Column;
     end;

  (* A BAND THE CONTEST DOES NOT USE HAS NO HEADER AND NO NUMBERS -- its column
     stays where it is, empty, so no band moves under another's header. Its
     cells could only read 0 (QSOCountsTowardTotals counts no off-band QSO),
     but the header still named 160 and 80 in the Florida QSO Party (NY4I,
     2026-11-07). Real bands only: AllBands is a key, not a band, and a
     contest's UsesBand answers False for it. *)
  if (Band <> AllBands) and
     (not ContestCreditsBand(ContestIdentity(Contest), Band)) then
     begin
     SetTotalsHeader(Column, '');
     Exit;
     end;

  SetTotalsHeader(Column, BandStringsArrayWithOutSpaces[Band]);

  Row := -1;
  MultDisplayEnable := True;

  if Settings.Qso.ByMode then
     begin

     if (ActiveMode = CW) or ((QTotals[AllBands, CW] > 0) and (NumberDifferentMults < 3)) then
        begin
        iTotalTextOut(QTotals[Band, CW]);
        end;
     if (ActiveMode = Phone) or ((QTotals[AllBands, Phone] > 0) and (NumberDifferentMults < 3)) then
        begin
        iTotalTextOut(QTotals[Band, Phone]);
        end;
     if (ActiveMode = Digital) or ((QTotals[AllBands, Digital] > 0) and (NumberDifferentMults < 3)) then
        begin
        iTotalTextOut(QTotals[Band, Digital]);
        end;
     end
  else
     begin
     iTotalTextOut(QTotals[Band, Both]);
     end;

  (* The multiplier sheet's mode key -- LOGDUPE's one statement of it, which
     applies the contest's multiplier mode (issue 122): in RTTY a Louisiana
     operator sees the CW/digital multipliers, the slot they were written to. *)
  TempMode := MultiplierSheetMode(ActiveMode);

  if (DoingDomesticMults) and (Settings.Mult.ByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     {
    if Settings.Mult.ByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberDomesticMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberDomesticMults);
}
     WriteMultRowValue(Band, TempMode, rmDomestic);
     end;

  if (DoingDXMults) and (Settings.Mult.ByBand or (Band = AllBands)) and MultDisplayEnable {and (ActiveDXMult <> NoCountDXMults)} then
     begin
     {
    if Settings.Mult.ByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberDXMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberDXMults);
}
     WriteMultRowValue(Band, TempMode, rmDX);
     end;

  if (DoingPrefixMults) and (Settings.Mult.ByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     {
    if Settings.Mult.ByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberPrefixMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberPrefixMults);
}
     WriteMultRowValue(Band, TempMode, rmPrefix);
     end;

  if (DoingZoneMults) and (Settings.Mult.ByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     WriteMultRowValue(Band, TempMode, rmZone);
     end;

end;

procedure UpdateTotals2;

{ This procedure will update the QSO and score information.  This is a
  generic six band total summary with both modes shown.  Someone should
  put a case statement in here someday and make it more appropriate to
  different contest.                                                    }
label
skip;
var
  i                                : integer;
  TempBand                         : BandType;
  ActiveMode                       : ModeType;
  CWi: real;
  PHi :  real;
//  CWR : integer;
//  PHR : integer;
  s1 : string;
  S2 : string;
  display : TTotalsDisplay;
begin
  ActiveMode := LogWind.ActiveMode;
  if ActiveMode = FM then
     begin
     ActiveMode := Phone;
     end;
  TotWinCurrrentColumn := -1;
  Column := 0;
  ClearTotals(0);
  QTotals := QSOTotals;

  (* Which modes' multipliers this pass shows -- issue 55. After QTotals,
    which it reads; before both passes, which read it. *)
  ChooseTotalsMultModes(ActiveMode);

//  Sheet.MultSheetTotals(MTotals);

//  CallsignsList.DisplayDupeSheet(@Radio1);
//  CallsignsList.DisplayDupeSheet(@Radio2);

  (* WHAT THIS CONTEST SHOWS DIFFERENTLY -- asked of the contest since M9a
    (2026-10-02), where it was three tests of its name (the OZCHR teams' mode
    shares, IARU's and the Russian contests' domestic-multiplier labels). *)
  display := ContestIdentity(Contest).TotalsDisplay;

  Row := -1;
  if Settings.Qso.ByMode then
     begin
     if display.ShowsModeShares      and                           //n4af 04.34.8
        (QTotals[AllBands,CW] > 0)   and
        (QTotals[AllBands,Phone] > 0) then
        begin
        CWi  := (QTotals[AllBands,CW]) / ((Qtotals[AllBands,CW])+(Qtotals[AllBands,Phone])) * 100;
        PHi  := ((QTotals[AllBands,Phone]) / (Qtotals[AllBands,CW]+Qtotals[AllBands,Phone]) * 100);
        Str(round(CWi),s1);
        S1 := concat('CW: ',s1,'%');
        S2 := concat('PH: ',inttostr(round(PHi)),'%');

        WriteLeftColumnText(S1);
        WriteLeftColumnText(S2);
        goto skip;
        end;
     end;
  if Settings.Qso.ByMode then
     begin
     if (ActiveMode = CW) or ((QTotals[AllBands, CW] > 0) and (NumberDifferentMults < 3)) then
        begin
        WriteLeftColumnText(TC_CWQSOS);
        end;
     if (ActiveMode = Phone) or ((QTotals[AllBands, Phone] > 0) and (NumberDifferentMults < 3)) then
        begin
        WriteLeftColumnText(TC_SSBQSOS);
        end;
     if (ActiveMode = Digital) or ((QTotals[AllBands, Digital] > 0) and (NumberDifferentMults < 3)) then
        begin
        WriteLeftColumnText(TC_DIGQSOS);
        end;
     end
  else
     begin
     WriteLeftColumnText(TC_QSOS);
     end;
  skip:
  (* EACH MULTIPLIER ROW'S LABEL NAMES THE MODES ITS CELLS SHOW (issue 55):
    WriteMultRowLabel, from the list DisplayBandTotals reads too. *)
  if DoingDomesticMults then
     begin
     WriteMultRowLabel(display.DomesticMultsCaptionCW,
                       display.DomesticMultsCaptionPhone,
                       display.DomesticMultsCaption);
     end;

  if DoingDXMults {and (ActiveDXMult <> NoCountDXMults)} then
     begin
     WriteMultRowLabel('CW DX', 'Ph DX', TC_DXMULTS);
     end;

  (* THE PREFIX ROW'S LABEL IS THE CONTEST'S (issue 277, 2026-11-11): it said
    'Prefixes' for every contest, and the CW Open's key is the whole worked
    callsign. *)
  if DoingPrefixMults then
     begin
     WriteMultRowLabel(display.PrefixMultsCaptionCW,
                       display.PrefixMultsCaptionPhone,
                       display.PrefixMultsCaption);
     end;

  (* THE ZONE ROW'S LABEL IS THE CONTEST'S TOO (2026-11-11): the European HF
    Championship's and KVP's "zone" is the year of first license. *)
  if DoingZoneMults then
     begin
     WriteMultRowLabel(display.ZoneMultsCaptionCW,
                       display.ZoneMultsCaptionPhone,
                       display.ZoneMultsCaption);
   //    WriteLeftColumnText('CW-Ratio');
   //    WriteLeftColumnText('PH-Ratio');
     end;

  {--------------------------------------------------}

  if ActiveBand in [Band160..Band10] then
     begin
     for TempBand := Band160 to Band10 do
        begin
        DisplayBandTotals(TempBand);
        end;
     end
  else
    if ActiveBand in [Band30..Band12] then
       begin
       DisplayBandTotals(Band30);
       DisplayBandTotals(Band20);
       DisplayBandTotals(Band17);
       DisplayBandTotals(Band15);
       DisplayBandTotals(Band12);
       DisplayBandTotals(Band10);
       end
    else
      if
        ActiveBand in [Band6..Band1296] then
         begin
         for TempBand := Band6 to Band1296 do
            begin
            DisplayBandTotals(TempBand);
            end;
         end
      else
        if
          ActiveBand in [Band2304..BandLight] then
           begin
           for TempBand := Band2304 to BandLight do
              begin
              DisplayBandTotals(TempBand);
              end;
           end;
  if ActiveBand = NoBand then
     begin
     DisplayBandTotals(NoBand);
     end;
   DisplayBandTotals(AllBands);
 //  TotalTextOut('Ratio',column+1,0);
  if Settings.Qtc.Enable then
     begin
     WriteLeftColumnText('QTCs');
     TotalTextOut(IntToStr(TotalNumberQTCsProcessed), Column, Row);
     if MyContinent <> Europe then
        begin
        WriteLeftColumnText(TC_QTCPENDING);
        TotalTextOut(IntToStr(TotalContacts - TotalNumberQTCsProcessed), Column, Row);
        end
     else
        begin

        //      TotalTextOut(inttopchar(TotalNumberQTCsProcessed), 1, col_counter);
        //      iTotalTextOut(TotalNumberQTCsProcessed);

        end;

 {
    WriteLeftColumnText('QTCs');
    TotalTextOut(IntToStr(TotalNumberQTCsProcessed), 1, col_counter);
    if MyContinent <> Europe then
    begin
          //          inc(col_counter);
      WriteLeftColumnText('Pending');
          //          TotalTextOut(inttopchar(TotalPendingQTCs), 1, col_counter);
    end
    else
    begin

          //      TotalTextOut('QTCs received', 0, col_counter);
          //      TotalTextOut(inttoPChar(TotalNumberQTCsProcessed), 1, col_counter);
          //      Write ('Number QTCs received = ', TotalNumberQTCsProcessed);
    end;
}
     end;
  (* REPAINT THE BAND HEADERS SO THE CURRENT COLUMN IS THE HIGHLIGHTED ONE.

    This was an InvalidateRect loop that forced a WM_CTLCOLORSTATIC and let
    DrawWindows decide the colours from TotWinCurrrentColumn. Setting the
    colour directly says the same thing in one step -- and fixes a gap the loop
    had: it ran 1 to 6 of seven headers, so the All column never repainted and
    its highlight could be left behind. *)
  HighlightTotalsColumn(TotWinCurrrentColumn);
end;

procedure ClearTotals(StartColumn: integer);
var
  c, r                             : integer;
begin
   (* Bounds from uMainGrids' constants, not literals. Clearing fewer rows than
     exist would leave a stale label behind when a contest with more categories
     is followed by one with fewer. *)
   for c := StartColumn to TOTALS_COLUMNS - 1 do
      begin
      for r := 0 to TOTALS_ROWS - 1 do
         begin
         TotalTextOut('', c, r);
         end;
      end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog');

end.
