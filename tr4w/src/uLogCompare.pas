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
unit uLogCompare;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  VC,
  TF,
  uWin32Compat,   // IDI_WARNING -- the FPC gap list

  PostUnit,
  uCommctrl,
  Windows,
  LogDupe,
  Messages
  ;

function LogCompareDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;

var
  LogCompareListView                    : HWND;
  TimeDifference                        : integer;

implementation
uses
  uGetServerLog,
  MainUnit,
  uNet,
  uTelnet;

function LogCompareDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  ExitAndClose, setitem;
var
  OpenGetServerLogDlg                   : LongBool;
  s                                     : PLogFileInformation;
  elvi                                  : TLVItem;
  elvc                                  : tagLVCOLUMNA;
 
begin
  Result := False;
  case Msg of
    WM_INITDIALOG:
      begin

        Windows.SetWindowTextA(hwnddlg, RC_DIFFINLOG);

        LogCompareListView := tWM_SETFONT(CreateListView2(0, 0, 440, 150, hwnddlg), MainFixedFont);

        CreateButton(0, RC_SYNCHRONIZE, 55, 160, 160, hwnddlg, 1);
        CreateButton(0, RC_CLEARALLLOGS, 55, 190, 160, hwnddlg, 103);
        CreateButton(0, EXIT_WORD, 220, 160, 160, hwnddlg, 2);

        SendMessage(hwnddlg, WM_SETICON, ICON_SMALL, LoadIcon(0, IDI_WARNING));
        if not OpenLogFile then Exit;
//        b := Windows.GetFileInformationByHandle(LogHandle, c);
        CloseLogFile;

        s := PLogFileInformation(lParam);
        LogCompareListView := Get101Window(hwnddlg);
        // Issue #997: asm tWM_SETFONT -> TF helper (EAX = LogCompareListView above).
        tWM_SETFONT(LogCompareListView, MainFixedFont);
        ListView_SetExtendedListViewStyle(LogCompareListView, LVS_EX_GRIDLINES or LVS_EX_FULLROWSELECT);

        elvc.Mask := LVCF_TEXT or LVCF_WIDTH or LVCF_FMT;

        elvc.fmt := LVCFMT_CENTER;
        elvc.pszText := nil;
        elvc.cx := 130;
        uCommctrl.ListView_InsertColumnA(LogCompareListView, 0, elvc);

        elvc.pszText := TC_SERVERLOG;
        elvc.cx := 150;
        uCommctrl.ListView_InsertColumnA(LogCompareListView, 1, elvc);

        elvc.pszText := TC_LOCALLOG;
        elvc.cx := 150;
        uCommctrl.ListView_InsertColumnA(LogCompareListView, 2, elvc);

        elvi.Mask := LVIF_TEXT {+ LVIF_STATE};
{        if s^.liServerLogSize <> s^.liLocalLogSize then
          elvi.State := LVIS_SELECTED + LVIS_DROPHILITED
        else}
//        elvi.State := LVIS_SELECTED;

        // D12: native-string ListView helpers (Unicode). No PChar/AnsiString at
        // the call site; the value flows as string, logged at TRACE for validation.
        tLVInsertRow(LogCompareListView, 0, TC_SIZEBYTES);
        tLVSetText(LogCompareListView, 0, 1, IntToStr(s^.liServerLogSize));
        tLVSetText(LogCompareListView, 0, 2, IntToStr(s^.liLocalLogSize));

        //----------------------------------------------------

        tLVInsertRow(LogCompareListView, 1, TC_RECORDS);
        tLVSetText(LogCompareListView, 1, 1, IntToStr(s^.liServerLogSize div SizeOf(ContestExchange) - 1));
        tLVSetText(LogCompareListView, 1, 2, IntToStr(s^.liLocalLogSize div SizeOf(ContestExchange) - 1));

        //----------------------------------------------------
{
        if s^.liSeverCRC32 <> s^.liLocalCRC32 then
          elvi.State := LVIS_SELECTED + LVIS_DROPHILITED
        else
          elvi.State := LVIS_SELECTED;
}
        tLVInsertRow(LogCompareListView, 2, 'CRC32');
        tLVSetText(LogCompareListView, 2, 1, '0x' + LowerCase(Format('%x', [integer(s^.liSeverCRC32)])));
        tLVSetText(LogCompareListView, 2, 2, '0x' + LowerCase(Format('%x', [integer(s^.liLocalCRC32)])));

        //----------------------------------------------------
{
        elvi.iItem := 3;
        elvi.iSubItem := 0;
        elvi.pszText := TC_MODIFIED;
        ListView_InsertItem(LogCompareListView, elvi);

        elvi.iSubItem := 1;
        Windows.FileTimeToSystemTime(s^.liInformation.ftLastWriteTime, St);
        elvi.pszText := SystemTimeToString(St);
        asm call setitem
        end;

        elvi.iSubItem := 2;
        Windows.FileTimeToSystemTime(c.ftLastWriteTime, St);
        elvi.pszText := SystemTimeToString(St);
        asm call setitem
        end;
}
        //----------------------------------------------------
{
        elvi.iItem := 3;
        elvi.iSubItem := 0;
        elvi.pszText := TC_TIMEDIFF;
        ListView_InsertItem(LogCompareListView, elvi);

        elvi.iSubItem := 2;
        if TimeDifference > 0 then p := '+' else p := '-';
        if TimeDifference = 0 then p := nil;
        TimeDifference := Abs(TimeDifference);
        Min := TimeDifference div 60;
        Sec := TimeDifference mod 60;
        asm
                push sec
                push min
                push p
        end;
        wsprintf(wsprintfBuffer, '%s %.2hd' + TC_M + ' %.2hd' + TC_S);
        asm add esp,20
        end;
        elvi.pszText := wsprintfBuffer;
        asm call setitem
        end;
}
        //----------------------------------------------------
{
        if tUSQ <> 0 then
          elvi.State := LVIS_SELECTED + LVIS_DROPHILITED
        else
          elvi.State := LVIS_SELECTED;
}
        tLVInsertRow(LogCompareListView, 3, 'USQ');
        tLVSetText(LogCompareListView, 3, 2, IntToStr(tUSQ));
        //----------------------------------------------------
{
        if tUSQE <> 0 then
          elvi.State := LVIS_SELECTED + LVIS_DROPHILITED
        else
          elvi.State := LVIS_SELECTED;
}
        tLVInsertRow(LogCompareListView, 4, 'USQE');
        tLVSetText(LogCompareListView, 4, 2, IntToStr(tUSQE));
        //----------------------------------------------------
{
        if s^.liContest <> Contest then
          elvi.State := LVIS_SELECTED + LVIS_DROPHILITED
        else
          elvi.State := LVIS_SELECTED;
}
        tLVInsertRow(LogCompareListView, 5, 'Contest');
        tLVSetText(LogCompareListView, 5, 1, string(ContestTypeSA[s^.liContest]));   // boundary: ANSI contest-name -> string
        tLVSetText(LogCompareListView, 5, 2, string(ContestTypeSA[Contest]));

        DifferentContests := s^.liContest <> Contest;
        if s^.liContest = DUMMYCONTEST then
           begin
           DifferentContests := False;
           end;
        if DifferentContests then
           begin
           EnableWindowFalse(hwnddlg, 1);
           end;
        //if DifferentContests then Windows.PostMessage(tr4w_WindowsArray[tw_NETWINDOW_INDEX].WndHandle, WM_CLOSE, 0, 0);
        Exit;
        // Issue #997: removed the `setitem:` label subroutine (was reached via
        // `asm call setitem` / returned via `asm ret`); call sites now inline
        // ListView_SetItem(LogCompareListView, elvi) directly.
       // OpenGetServerLogDlg := False;
      end;

//    WM_HELP: tWinHelp(48);

    WM_COMMAND:

      case wParam of
        1:
          begin
            OpenGetServerLogDlg := True;
            goto ExitAndClose;
          end;

        2:
          begin
            goto ExitAndClose;
          end;

        103:
          begin
            ProcessMenu(menu_clearserverlog);
            goto ExitAndClose;
          end;

      end;

    WM_CLOSE:
      begin
        ExitAndClose:

        EndDialog(hwnddlg, 0);
        if OpenGetServerLogDlg then
           begin
           tDialogBox(73, @GetServerLogDlgProc);
           end;
      end;

  end;

end;

end.

