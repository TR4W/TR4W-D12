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
  ;

var
  TotWinCurrrentColumn             : integer;
  Column                           : integer;
  Row                              : integer;

procedure DisplayBandTotals(Band: BandType);
procedure UpdateTotals2;
procedure ClearTotals(StartColumn: integer);

implementation

uses
   Log4D;

var
   // This unit's own reference to the program's log category, rather than
   // MainUnit's global.  GetLogger is a repository lookup, so this IS the same
   // instance tr4w.dpr configures -- and it keeps a display unit from dragging
   // the whole main-window unit graph in, which is what made dcc32 die with an
   // internal error on a cold build (see 8e4cafac).
   logger: TLogLogger;

procedure TotalTextOut(s: string; X, Y: integer);
begin
  // THE GRID IS FIXED AT 8 x 4 and the callers do not check.  MainUnit creates
  // exactly `for r := 0 to 3` x `for c := 0 to 7` static windows (~5310), and
  // VC.pas sizes both arrays [0..7, 0..3] to match -- so a cell outside that
  // has no window to write to.
  //
  // WriteLeftColumnText and iTotalTextOut both do a bare `inc(Row)` with no
  // bound, and enough conditional rows (CW + Phone + Digital, or the mult
  // labels) reach Row = 4.  NY4I hit exactly that at startup 2026-08-07:
  //   uTotal.TotalTextOut ('DX Mults', 0, 4)   <- Y is one past the end
  //
  // WITH RANGE CHECKING OFF -- this project's setting -- it does not raise, and
  // what it does instead depends on X, because Delphi lays array[0..7, 0..3]
  // out with the FIRST index outermost: [X,Y] is element X*4 + Y of 32.
  //
  //   X = 0 (the left column):  [0,4] is element 4, which IS [1,0].  The label
  //       silently overwrites the NEXT COLUMN's top cell.  Wrong, but contained.
  //
  //   X = 7 (DisplayBandTotals sets Column := 7 for AllBands):  [7,4] is
  //       element 32 -- ONE PAST THE LAST.  TotWinHandles[7,4] reads into
  //       TotWinHandlesFilled, and TotWinHandlesFilled[7,4] WRITES PAST IT INTO
  //       TotWinheadHandles[1] (VC.pas:2604), which is a live window handle.
  //
  // That second case is the dangerous one and it is why this guard exists: a
  // corrupted HWND fails later, somewhere else, depending on what the window
  // manager happens to be doing -- which matches "ran fine for many sessions,
  // then didn't" and a corpus set that failed only periodically.  Guarded here
  // rather than left to each caller to learn to count.
  if (X < Low(TotWinHandles)) or (X > High(TotWinHandles)) or
     (Y < Low(TotWinHandles[0])) or (Y > High(TotWinHandles[0])) then
     begin
     // REPORTED, not swallowed: a dropped label means the totals window is
     // showing fewer categories than the contest actually has, and an operator
     // needs some way to discover that beyond noticing a blank line.
     logger.Warn('[TotalTextOut] cell (%d,%d) is outside the %dx%d totals grid; ' +
                 'text "%s" not shown',
                 [X, Y, High(TotWinHandles) + 1, High(TotWinHandles[0]) + 1, s]);
     Exit;
     end;

  // D12: s is native string; '' is the "clear" signal nil used to be.
  if s = '' then
    if TotWinHandlesFilled[X, Y] = False then Exit;
  Windows.SetWindowTextW(TotWinHandles[X, Y], PChar(s));
  TotWinHandlesFilled[X, Y] := s <> '';
end;

procedure WriteLeftColumnText(Text: PAnsiChar);
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
{
  if Number = 0 then
    Windows.SetWindowTextA(TotWinHandles[Column, Row], nil)
  else
    Windows.SetWindowTextA(TotWinHandles[Column, Row], inttopchar(Number));
}
end;

procedure DisplayBandTotals(Band: BandType);

var
  MultDisplayEnable                : boolean;
//  col_title                             : PChar;
  ActiveMode                       : ModeType;
  TempMode                         : ModeType;
begin
  ActiveMode := LogWind.ActiveMode;
  if ActiveMode = FM then ActiveMode := Phone;
 

  if Band = NoBand then
  begin
    ClearTotals(1);
    Exit;
  end;
//  col_title := BandStringsArrayWithOutSpaces[Band];
  inc(Column);
  if Band = AllBands then Column := 7;
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
  Windows.SetWindowTextA(TotWinheadHandles[Column], {col_title} BandStringsArrayWithOutSpaces[Band]);

  Row := -1;
  MultDisplayEnable := True;

  if QSOByMode then
  begin

    if (ActiveMode = CW) or ((QTotals[AllBands, CW] > 0) and (NumberDifferentMults < 3)) then iTotalTextOut(QTotals[Band, CW]);
    if (ActiveMode = Phone) or ((QTotals[AllBands, Phone] > 0) and (NumberDifferentMults < 3)) then iTotalTextOut(QTotals[Band, Phone]);
    if (ActiveMode = Digital) or ((QTotals[AllBands, Digital] > 0) and (NumberDifferentMults < 3)) then iTotalTextOut(QTotals[Band, Digital]);
  end
  else
    iTotalTextOut(QTotals[Band, Both]);

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
    iTotalTextOut(mo.MTotals[Band, TempMode, rmZone]);

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
  if ActiveMode = FM then ActiveMode := Phone;
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
    if (ActiveMode = CW) or ((QTotals[AllBands, CW] > 0) and (NumberDifferentMults < 3)) then WriteLeftColumnText('CW - ');
    if (ActiveMode = Phone) or ((QTotals[AllBands, Phone] > 0) and (NumberDifferentMults < 3)) then WriteLeftColumnText(TC_SSBQSOS);
    if (ActiveMode = Digital) or ((QTotals[AllBands, Digital] > 0) and (NumberDifferentMults < 3)) then WriteLeftColumnText(TC_DIGQSOS);
  end
  else
    WriteLeftColumnText(TC_QSOS);
  skip:
  if DoingDomesticMults then
  begin
    if MultByMode then
    begin
      if Contest = IARU then
      begin
        if ActiveMode = CW then WriteLeftColumnText('CW HQ');
        if ActiveMode = Phone then WriteLeftColumnText('Ph HQ');
      end
      else
      begin
        if ActiveMode = CW then WriteLeftColumnText('CW Dom');
        if ActiveMode = Phone then WriteLeftColumnText('Ph Dom');
      end;
    end
    else
    begin
      begin
        if Contest = IARU then WriteLeftColumnText(TC_HQMULTS)
        else
          if (Contest = RUSSIANDX) or (Contest = RU3AXMemorial) then WriteLeftColumnText(TC_OBLASTS)
          else
            WriteLeftColumnText(TC_DOMMULTS);
      end;
    end;
  end;

  if DoingDXMults {and (ActiveDXMult <> NoCountDXMults)} then
  begin
    if MultByMode then
    begin
      if ActiveMode = CW then WriteLeftColumnText('CW DX');
      if ActiveMode = Phone then WriteLeftColumnText('Ph DX');
    end
    else
      WriteLeftColumnText(TC_DXMULTS);

  end;

  if DoingPrefixMults then
  begin
    if MultByMode then
    begin
      if ActiveMode = CW then WriteLeftColumnText('CW Pfxs');
      if ActiveMode = Phone then WriteLeftColumnText('Ph Pfxs');
    end
    else
      WriteLeftColumnText(TC_PREFIX);
  end;

  if DoingZoneMults then
  begin
    if MultByMode then
    begin
      if ActiveMode = CW then WriteLeftColumnText('CW Zone');
      if ActiveMode = Phone then WriteLeftColumnText('Ph Zone');
    end
    else
      WriteLeftColumnText(TC_ZONE);
  //    WriteLeftColumnText('CW-Ratio');
  //    WriteLeftColumnText('PH-Ratio');
  end;

  {--------------------------------------------------}

  if ActiveBand in [Band160..Band10] then
  begin
     for TempBand := Band160 to Band10 do DisplayBandTotals(TempBand);
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
        for TempBand := Band6 to Band1296 do DisplayBandTotals(TempBand);
      end
      else
        if
          ActiveBand in [Band2304..BandLight] then
        begin
          for TempBand := Band2304 to BandLight do DisplayBandTotals(TempBand);
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
  for i := 1 to 6 do InvalidateRect(TotWinheadHandles[i], nil, True);
end;

procedure ClearTotals(StartColumn: integer);
var
  c, r                             : integer;
begin
   // Bounds from the arrays, not literals -- see VC.pas:2601. Clearing fewer
   // rows than exist would leave a stale label behind when a contest with more
   // categories is followed by one with fewer.
   for c := StartColumn to High(TotWinHandles) do
      begin
      for r := 0 to High(TotWinHandles[0]) do
         begin
         TotalTextOut('', c, r);
         end;
      end;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog');

end.
