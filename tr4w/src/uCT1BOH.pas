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
unit uCT1BOH;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
uses
  TF,
  VC,
  PostUnit,
  Windows,
  Messages,
  LogWind,
  //Country9,
  Tree,
  // LAST deliberately.  FPC's `windows` pulls in its own commctrl declarations,
  // and in Pascal the last unit in the clause wins -- so listed earlier, the
  // ListView_* calls bound to FPC's overloads while the record variables kept
  // uCommctrl's types, giving "Call by var has to match exactly".  TR4W's
  // uCommctrl is the one this code is written against, so it goes last.
  uCommctrl
  ;
function ct1bohDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
function CT1BOHInfoString(QSOs: integer; Percents: integer): PAnsiChar;

// the CT1BOH information box.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowCT1BOHInfo;

implementation
uses MainUnit;
function ct1bohDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1;
var
  Band                                  : integer;
  Continent                             : ContinentType;
  hLV                                   : HWND;
  // Unit-qualified deliberately.  FPC's own commctrl declares types of these
  // same names, so an unqualified declaration can bind to FPC's while the
  // ListView_* call binds to uCommctrl's -- two distinct types spelled
  // identically, which surfaces as "Call by var has to match exactly: got
  // tagLVCOLUMNA expected LV_COLUMN".  Delphi resolves both to uCommctrl
  // either way, so naming the unit costs nothing and removes the ambiguity.
  lvi                                   : uCommctrl.TLVItem;
  lvc                                   : uCommctrl.tagLVCOLUMNA;
  TimeAnsi                              : AnsiString;   // D12: persistent buffer for pszText (see below)
//  TotalTimeOn                           : integer;
  Percent                               : integer;
  BandTotals                            : array[Band160..Band10] of integer;
  counter                               : integer;
const
  ca                                    : array[1..7] of BandType = (Band160, Band80, Band40, Band20, Band15, Band10, AllBands);
begin
  Result := False;
  case Msg of
    WM_INITDIALOG:
      begin
        Windows.SetWindowTextA(hwnddlg, RC_CT1BOHIS2);
        hLV := CreateListView2(0, 0, 655+20, 132+20, hwnddlg);
//        hLV := Get101Window(hwnddlg);
        // Issue #997: asm tWM_SETFONT -> TF helper (EAX = hLV above).
        tWM_SETFONT(hLV, MainFixedFont);
        ListView_SetExtendedListViewStyle(hLV, LVS_EX_GRIDLINES or LVS_EX_FULLROWSELECT);
        {Insert Header}
        lvc.Mask := LVCF_TEXT or LVCF_WIDTH or LVCF_FMT;
        lvc.cx := 130;
        lvc.fmt := LVCFMT_CENTER;
        lvc.pszText := nil;
        ListView_InsertColumn(hLV, 0, lvc);
        counter := 0;
        for Band := 1 to 7 do
           begin

           lvc.pszText := BandStringsArrayWithOutSpaces[ca[Band]];
           lvc.cx := 75;
           ListView_InsertColumn(hLV, counter + 1, lvc);
           inc(counter);
           end;
        {Time ON}
        lvi.iItem := 1;
        lvi.iSubItem := 0;
        lvi.Mask := LVIF_TEXT or LVIF_STATE;
        lvi.State := LVIS_SELECTED {or LVIS_DROPHILITED};
        lvi.pszText := TC_TIMEON;
        ListView_InsertItem(hLV, lvi);
        lvi.Mask := LVIF_TEXT;
        CalculateTotals;
        for Band := 1 to 7 do
           begin
           {
          if TotalTimeOn = 0 then
            Percent := 0
          else
            Percent := round((TimeSpentByBand[ca[Band]] / TotalTimeOn) * 100);
}
                     lvi.iItem := 0;
                     lvi.iSubItem := Band;
           //          lvi.pszText := CT1BOHInfoString(TimeSpentByBand[Band], Percent);
                     // boundary: this ListView is still LV_ITEMA; hold the time text in a
                     // function-scoped AnsiString so pszText stays valid through
                     // ListView_SetItem (the string result is a statement-scoped temporary).
                     // W-flip tracked with the ListView A->W surface.
                     TimeAnsi := AnsiString(MillisecondsToFormattedString(TimeSpentByBand[ca[Band]] * 1000, False));
                     lvi.pszText := PAnsiChar(TimeAnsi);
                     ListView_SetItem(hLV, lvi);
                     BandTotals[ca[Band]] := 0;
           //          for Continent := NorthAmerica to Oceania do
                     for Continent := NorthAmerica to High(ContinentType) do
                        begin
                        BandTotals[ca[Band]] := BandTotals[ca[Band]] + ContinentQSOCount[ca[Band], Continent];
                        end;
           end;
        for Continent := NorthAmerica to High(ContinentType) do
//        for Continent := NorthAmerica to Oceania do
           begin
           lvi.iSubItem := 0;
           lvi.iItem := Ord(Continent);
           lvi.pszText := tContinentArray[Continent];
           ListView_InsertItem(hLV, lvi);
           for Band := 1 to 7 do
              begin
              if BandTotals[ca[Band]] = 0 then
                 begin
                 Percent := 0
                 end
              else
                 begin
                 Percent := round((ContinentQSOCount[ca[Band], Continent] / BandTotals[ca[Band]]) * 100);
                 end;
              lvi.iItem := Ord(Continent);
              lvi.iSubItem := Band;
              lvi.pszText := CT1BOHInfoString(ContinentQSOCount[ca[Band], Continent], Percent);
              ListView_SetItem(hLV, lvi);
              end;
           end;
      end;
    WM_COMMAND:
      if wParam = 2 then
         begin
         goto 1;
         end;
    WM_CLOSE: 1: EndDialog(hwnddlg, 0);
  end;
end;
function CT1BOHInfoString(QSOs: integer; Percents: integer): PAnsiChar;
begin
  if QSOs = 0 then
     begin
     wsprintfBuffer[0] := #0
     end
  else
     begin
     TF.Format(wsprintfBuffer, '%u (%u%%)', QSOs, Percents);
     end;
  Result := wsprintfBuffer;
end;

procedure ShowCT1BOHInfo;
begin
   CreateModalDialog(330 + 10, 68 + 10, tr4whandle, @ct1bohDlgProc, 0);
end;
end.
