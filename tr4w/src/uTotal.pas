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
  Windows,
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
   uMainGrids;

var
   // This unit's own reference to the program's log category, rather than
   // MainUnit's global.  GetLogger is a repository lookup, so this IS the same
   // instance tr4w.lpr configures -- and it keeps a display unit from dragging
   // the whole main-window unit graph in, which is what made dcc32 die with an
   // internal error on a cold build (see 8e4cafac).
   logger: TLogLogger;

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
{ string, not PAnsiChar: every caller passes a TC_ constant, and those are
  resourcestrings now. TotalTextOut below has taken a string all along, so
  this parameter was converting one to a pointer and straight back. }
begin
  inc(Row);
  TotalTextOut(Text, 0, Row);
end;

procedure iTotalTextOut(Number: integer);
var
  TempPchar                        : PAnsiChar;
begin
  inc(Row);

  if Number = 0 then TempPchar := nil else TempPchar := inttopchar(Number);
  TotalTextOut(TempPchar, Column, Row);
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
  SetTotalsHeader(Column, BandStringsArrayWithOutSpaces[Band]);

  Row := -1;
  MultDisplayEnable := True;

  if QSOByMode then
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

  if MultByMode then TempMode := ActiveMode else TempMode := Both;

  if (DoingDomesticMults) and (MultByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     {
    if MultByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberDomesticMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberDomesticMults);
}
         iTotalTextOut(mo.MTotals[Band, TempMode, rmDomestic]);
     end;

  if (DoingDXMults) and (MultByBand or (Band = AllBands)) and MultDisplayEnable {and (ActiveDXMult <> NoCountDXMults)} then
     begin
     {
    if MultByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberDXMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberDXMults);
}
         iTotalTextOut(mo.MTotals[Band, TempMode, rmDX]);
     end;

  if (DoingPrefixMults) and (MultByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     {
    if MultByMode then
      iTotalTextOut(MTotals[Band, ActiveMode].NumberPrefixMults)
    else
      iTotalTextOut(MTotals[Band, Both].NumberPrefixMults);
}
         iTotalTextOut(mo.MTotals[Band, TempMode, rmPrefix]);
     end;

  if (DoingZoneMults) and (MultByBand or (Band = AllBands)) and MultDisplayEnable then
     begin
     iTotalTextOut(mo.MTotals[Band, TempMode, rmZone]);
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
  CWp  : AnsiString;
  PHp : AnsiString;
  s1 : string;
  S2 : string;
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

//  Sheet.MultSheetTotals(MTotals);

//  CallsignsList.DisplayDupeSheet(@Radio1);
//  CallsignsList.DisplayDupeSheet(@Radio2);

  Row := -1;
  if QSOByMode then
     begin
     if Contest = OZCR_O   then      //n4af 04.34.8
     if (QTotals[AllBands,CW] > 0) and (QTotals[AllBands,Phone]> 0)   then
        begin
        CWi  := (QTotals[AllBands,CW]) / ((Qtotals[AllBands,CW])+(Qtotals[AllBands,Phone])) * 100;
        PHi  := ((QTotals[AllBands,Phone]) / (Qtotals[AllBands,CW]+Qtotals[AllBands,Phone]) * 100);
        Str(round(CWi),s1);
         S1 := concat('CW: ',s1,'%');
          CWp := AnsiString(S1);
         S2 := concat('PH: ',inttostr(round(PHi)),'%');
          PHp := AnsiString(S2);

        WriteLeftColumnText(PAnsiChar(CWp));
        WriteLeftColumnText(PAnsiChar(PHp));
         goto skip;
        end;
     end;
  if QSOByMode then
     begin
     if (ActiveMode = CW) or ((QTotals[AllBands, CW] > 0) and (NumberDifferentMults < 3)) then
        begin
        WriteLeftColumnText('CW - ');
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
  if DoingDomesticMults then
     begin
     if MultByMode then
        begin
        if Contest = IARU then
           begin
           if ActiveMode = CW then
              begin
              WriteLeftColumnText('CW HQ');
              end;
           if ActiveMode = Phone then
              begin
              WriteLeftColumnText('Ph HQ');
              end;
           end
        else
           begin
           if ActiveMode = CW then
              begin
              WriteLeftColumnText('CW Dom');
              end;
           if ActiveMode = Phone then
              begin
              WriteLeftColumnText('Ph Dom');
              end;
           end;
        end
     else
        begin
        begin
          if Contest = IARU then
             begin
             WriteLeftColumnText(TC_HQMULTS)
             end
          else
            if (Contest = RUSSIANDX) or (Contest = RU3AXMemorial) then
               begin
               WriteLeftColumnText(TC_OBLASTS)
               end
            else
               begin
               WriteLeftColumnText(TC_DOMMULTS);
               end;
        end;
        end;
     end;

  if DoingDXMults {and (ActiveDXMult <> NoCountDXMults)} then
     begin
     if MultByMode then
        begin
        if ActiveMode = CW then
           begin
           WriteLeftColumnText('CW DX');
           end;
        if ActiveMode = Phone then
           begin
           WriteLeftColumnText('Ph DX');
           end;
        end
     else
        begin
        WriteLeftColumnText(TC_DXMULTS);
        end;

     end;

  if DoingPrefixMults then
     begin
     if MultByMode then
        begin
        if ActiveMode = CW then
           begin
           WriteLeftColumnText('CW Pfxs');
           end;
        if ActiveMode = Phone then
           begin
           WriteLeftColumnText('Ph Pfxs');
           end;
        end
     else
        begin
        WriteLeftColumnText(TC_PREFIX);
        end;
     end;

  if DoingZoneMults then
     begin
     if MultByMode then
        begin
        if ActiveMode = CW then
           begin
           WriteLeftColumnText('CW Zone');
           end;
        if ActiveMode = Phone then
           begin
           WriteLeftColumnText('Ph Zone');
           end;
        end
     else
        begin
        WriteLeftColumnText(TC_ZONE);
        end;
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
  if QTCsEnabled then
     begin
     WriteLeftColumnText('QTCs');
     TotalTextOut(inttopchar(TotalNumberQTCsProcessed), Column, Row);
     if MyContinent <> Europe then
        begin
        WriteLeftColumnText(TC_QTCPENDING);
        TotalTextOut(inttopchar(TotalContacts - TotalNumberQTCsProcessed), Column, Row);
        end
     else
        begin

        //      TotalTextOut(inttopchar(TotalNumberQTCsProcessed), 1, col_counter);
        //      iTotalTextOut(TotalNumberQTCsProcessed);

        end;

 {
    WriteLeftColumnText('QTCs');
    TotalTextOut(inttopchar(TotalNumberQTCsProcessed), 1, col_counter);
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
