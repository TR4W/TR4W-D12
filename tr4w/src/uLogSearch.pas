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
unit uLogSearch;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  Windows,
  Tree,
  LogEdit,
  LogStuff,
  LogDupe,
  PostUnit,
  uCommctrl,
  uEditQSO,
utils_text,
  Messages
  ,
  uTR4WStrings;

function LogSearchDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
procedure EditLogInSearch;


// the log search window.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowLogSearch;

implementation
(* uLogSource: which store a log READ comes from -- step B4. *)
uses MainUnit, SysUtils, uLogSource;   // Issue #997: SysUtils for Format/StrPCopy
const
  MAXSEARCHINDEX                        = 255;
var
  LogSearchListView                     : HWND;
  LogSearchListViewIndex                : integer;
  LogSearchWndHandle                    : HWND;
  LogSearchIndexesArray                 : array[0..MAXSEARCHINDEX] of integer;

function LogSearchDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1, 2, SearchStart, NextRecord;
var
  bt                                    : BandType;
  mt                                    : ModeType;
  TempString                            : CallString;
  tMode                                 : ModeType;
  tBand                                 : BandType;
  CurrentRecord                         : LONGINT;
  Index                                 : integer;
  TempOperator                          : OperatorType;
  i                                     : integer;
  l                                     : array[0..3] of string;
begin
  // Filled here rather than at the declaration: these are resourcestrings
  // now, and a typed constant would fold whatever English the compiler saw.
  l[0] := RC_CALLSIGN;
  l[1] := RC_MODE;
  l[2] := RC_BAND;
  l[3] := RC_OPERATOR;
  Result := False;
  case Msg of

    WM_INITDIALOG:
      begin

        Windows.SetWindowTextW(hwnddlg, PWideChar(UnicodeString(RC_SEARCHLOG)));

        for i := 0 to 3 do
           begin
           CreateStatic(l[i], 5 + i * 170, 5, 50+10, hwnddlg, 0);
           if i in [1..2] then
              begin
              tCreateComboBoxWindow(CBS_DROPDOWNLIST or WS_CHILD or WS_VISIBLE or WS_TABSTOP, 55+10 + i * 170, 5, 100, hwnddlg, 200 + i)
              end
               else
                  begin
                  CreateEdit(ES_UPPERCASE, 55+10 + i * 170, 5, 100, 23, hwnddlg, 200 + i);
                  end;
           end;

        CreateButton(BS_DEFPUSHBUTTON, RC_SEARCH, 690, 5, 60, hwnddlg, 103);

        CreateStatic('', 0, 280, 775, hwnddlg, 104);

        LogSearchWndHandle := hwnddlg;
        LogSearchListView := CreateEditableLog(hwnddlg, 1, 35, 770, 245, True);
        for bt := Band160 to NoBand do
           begin
           tCB_ADDSTRING_PCHAR(hwnddlg, 202, BandStringsArray[bt]);
           end;
        tCB_SETCURSEL(hwnddlg, 202, Ord(AllBands));

        for mt := CW to FM do
           begin
           tCB_ADDSTRING_PCHAR(hwnddlg, 201, ModeStringArray[mt]);
           end;
        tCB_SETCURSEL(hwnddlg, 201, Ord(Both));

        Windows.ZeroMemory(@TempString, SizeOf(TempString));
        TempString := CallWindowString;
        if TempString = '' then
           begin
           TempString := EscapeDeletedCallEntry;
           end;
        Windows.SetDlgItemTextA(hwnddlg, 200, @TempString[1]);
        goto SearchStart;
      end;

    WM_COMMAND:
      begin
        if lParam = 0 then if LoWord(wParam) = 1 then EditLogInSearch;
        if HiWord(wParam) = CBN_SELCHANGE then goto SearchStart; //PreviousSearchString := '';
        case wParam of
          2: goto 1;
          103:
            begin
              SearchStart:

              TempString[0] := AnsiChar(Windows.GetDlgItemTextA(hwnddlg, 200, @TempString[1], CallstringLength - 1));
              Windows.GetDlgItemTextA(hwnddlg, 203, TempOperator, SizeOf(OperatorType));
              if (TempString[0] = #0) and (TempOperator[0] = #0) then Exit;

              LogSearchListViewIndex := 0;
              tMode := ModeType(tCB_GETCURSEL(hwnddlg, 201));
              tBand := BandType(tCB_GETCURSEL(hwnddlg, 202));
              if not LogSourceOpen then Exit;
              ListView_DeleteAllItems(LogSearchListView);
              CurrentRecord := -1;
              Index := 0;
              StartCPU := GetTickCount;
              LogSourceRewind;
              NextRecord:
              if LogSourceNext( TempRXData ) then
                 begin
                 inc(CurrentRecord);
                 if tBand <> AllBands then if TempRXData.Band <> tBand then goto NextRecord;
                 if tMode <> Both then if TempRXData.Mode <> tMode then goto NextRecord;
                 if TempString[0] <> #0 then if pos(TempString, TempRXData.Callsign) = 0 then goto NextRecord;
                 if TempOperator[0] <> #0 then
                   if StrComp(TempOperator, TempRXData.ceOperator) <> 0 then
                      begin
                      goto NextRecord;
                      end;

                 if not (TempRXData.ceRecordKind in [rkQSO, rkQTCR, rkQTCS]) then
                    begin
                    goto NextRecord;
                    end;

                 if Index <= MAXSEARCHINDEX then
                    begin
                    tAddContestExchangeToLog(TempRXData, LogSearchListView, LogSearchListViewIndex);
                    (* THE RECORD INDEX, not a byte offset into the .TRW.
                       CurrentRecord is already 0-based and counted per record
                       read, so the file layout does not need restating. *)
                    LogSearchIndexesArray[Index] := CurrentRecord;
                    inc(Index);
                    goto NextRecord;
                    end;
                 end;
              LogSourceClose;
              // Issue #997: asm-push wsprintf -> SysUtils.Format.
              // TC_ENTRIESPERMS = '%u entries per %u ms'; args = index, elapsed ms.
              StrPCopy(wsprintfBuffer, SysUtils.Format(TC_ENTRIESPERMS,
                [LogSearchListViewIndex, Windows.GetTickCount - StartCPU]));
              Windows.SetDlgItemTextA(hwnddlg, 104, wsprintfBuffer);
              if LogSearchListViewIndex > 0 then
                 begin
                 EnsureListViewColumnVisible(LogSearchListView);
                 end;
            end;

        end;

      end;

    WM_NOTIFY:
      begin
        with PNMHdr(lParam)^ do
           begin
           case code of
             NM_DBLCLK: EditLogInSearch;

           end;
           end;
      end;

    WM_CLOSE: 1: EndDialog(hwnddlg, 0);

  end;
end;

procedure EditLogInSearch;
var
  SearchInLogEditIndex                  : integer;
begin
  SearchInLogEditIndex := ListView_GetNextItem(LogSearchListView, -1, LVNI_SELECTED);
  if SearchInLogEditIndex = -1 then Exit;
  IndexOfItemInLogForEdit := LogSearchIndexesArray[SearchInLogEditIndex];
  OpenEditQSOWindow(LogSearchWndHandle);
  PostMessage(LogSearchWndHandle, WM_COMMAND, 103, 0);
end;


procedure ShowLogSearch;
begin
   CreateModalDialog(387, 150, tr4whandle, @LogSearchDlgProc, 0);
end;
end.

