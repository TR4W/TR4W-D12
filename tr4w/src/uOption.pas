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
 }unit uOption;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  uBMCF,
  uWinKey,
  uDialogs,
  uCFG,
  TF,
  VC,
  uNet,
  WinSock2,
  uCommctrl,
  Windows,
  LogWind,
  LogNet,
  Tree,
  Messages,
  uGradient
  ;

const

  COMMAND_FIELD                         = 0;
  VALUE_FIELD                           = 1;
  NUMBER_FIELD                          = 2;
  FILE_FIELD                            = 3;

var
  SomeCommandWasChanged                 : boolean;
  CommandsFilter                        : CFGFunc;
  CommandToSet                          : PAnsiChar;
  PreviousHelpRow                       : integer;
  settingswindowhandle                  : HWND;
  OldSLVProc                            : Pointer;
  tShouldRestartProgram                 : boolean;
  //  Buffer                                : array[1..250] of Char;
  //  lvi                                   : tagLVITEM;
  //  lvc                                   : tagLVCOLUMNA;
  //  lvc                                   : tagLVCOLUMNA;
  //  lvi                                   : TLVItem;

  //  c, V                                  : string;

      {SettingsListviev variables}
  Settingslvc                           : tagLVCOLUMNA;
  Settingslvi                           : TLVItem;
  SettingshLV                           : HWND;
//  SettingshLV2                          : HWND;
procedure ShowHelpMessageForCommand;
function SettingsDlgProc2(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword {BOOL}; stdcall;
procedure ChangeValue2;
procedure CommandsToListView2(f: CFGFunc);
procedure SaveValue2(Row: integer);
procedure SendParameterToNetwork;

function NewSLVProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;

implementation
uses MainUnit;

const
  // Issue #783 -- ctPassword fields display as this fixed mask in the
  // settings listview unless the operator ticks the "Show passwords"
  // checkbox.  Fixed length so we don't leak the actual password length.
  PASSWORD_MASK: PAnsiChar = '********';
  ID_SHOWPASSWORDS_CB = 210;   // free in this dialog (200..204 are buttons)

var
  IndexArray                            : array[1..CommandsArraySize] of Word;
  ShowPasswords                         : Boolean = False;  // per-session, resets every dialog open

procedure RefreshPasswordRows(hwnddlg: HWND); forward;   // Issue #783

function SettingsDlgProc2(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): longword {BOOL}; stdcall;
label
  1;
var
  TempInteger                           : integer;
  plvfi                                 : TLVFindInfo;
  St                                    : Cardinal;
  m                                     : HMENU;
const
  l                                     : array[0..4] of PAnsiChar = (RC_RETURNTOMOD, RC_ALTW, RC_ALTG, RC_ALTN, EXIT_WORD);
begin
  Result := 0; // False;
  case Msg of
//    WM_HELP: tWinHelp(61);
    WM_INITDIALOG:
      begin
        Windows.SetWindowTextA(hwnddlg, RC_OPTIONS);

        SettingshLV := tWM_SETFONT(CreateListView2(0, 0, 548, 432, hwnddlg), MainFixedFont);

        for TempInteger := 0 to 4 do
           begin
           St := 0;
           M := 200 + TempInteger;
           if TempInteger = 0 then
              begin
              St := BS_DEFPUSHBUTTON or BS_NOTIFY or BS_CENTER;
              m := 1;
              end;

           CreateButton(St, l[TempInteger], TempInteger * 110 + 5, 470, 107, hwnddlg, M);
           end;

        // Issue #783 -- "Show passwords" checkbox lives on the dialog itself
        // (NOT inside the listview), so it stays visible regardless of how far
        // the operator scrolls.  Defaults unchecked at every open; per-session
        // state, no persistence.
        ShowPasswords := False;
        CreateButton(BS_AUTOCHECKBOX or BS_NOTIFY,
                     TC_SHOW_PASSWORDS, 560, 472, 150, hwnddlg, ID_SHOWPASSWORDS_CB);
        Windows.SendDlgItemMessage(hwnddlg, ID_SHOWPASSWORDS_CB, BM_SETCHECK,
                                   BST_UNCHECKED, 0);

        CreateStatic(RC_ARROWTOSELIT, 0, 433, 548, hwnddlg, 106);

        CreateStatic(RC_DEFAULT, 560, 5, 210, hwnddlg, 103);
        CreateStatic(nil, 560, 30, 210, hwnddlg, 104);
        CreateStatic(RC_DESCRIPTION, 560, 55, 210, hwnddlg, 109);
        CreateEdit(ES_MULTILINE or ES_READONLY or WS_VSCROLL, 560, 80, 210, 350, hwnddlg, 105);

        EnableWindowFalse(hwnddlg, 202);

        SomeCommandWasChanged := False;
        tShouldRestartProgram := False;
        PreviousHelpRow := MAXWORD;
        settingswindowhandle := hwnddlg;

        tWM_SETFONT(GetDlgItem(hwnddlg, 105), MainFixedFont);
        tWM_SETFONT(GetDlgItem(hwnddlg, 104), MainFixedFont);

        CommandsToListView2(CFGFunc(lParam));
        OldSLVProc := Pointer(Windows.SetWindowLong(hwnddlg, GWL_WNDPROC, integer(@NewSLVProc)));

        TempInteger := 0;

        if CommandToSet <> nil then
           begin
           plvfi.Flags := LVFI_STRING;
           plvfi.psz := CommandToSet;
           TempInteger := ListView_FindItem(SettingshLV, -1, plvfi);
           if TempInteger = -1 then
              begin
              TempInteger := 0;
              end;
           CommandToSet := nil;
           end;

        Settingslvi.Mask := LVIF_STATE;
        Settingslvi.stateMask := LVIS_FOCUSED or LVIS_SELECTED;
        Settingslvi.State := LVIS_SELECTED or LVIS_FOCUSED;
        SendMessage(SettingshLV, LVM_SETITEMSTATE, TempInteger, LONGINT(@Settingslvi));
        uCommctrl.ListView_EnsureVisible(SettingshLV, TempInteger, False);
        Windows.ZeroMemory(@Changed, SizeOf(Changed));
      end;

    WM_COMMAND:
      begin
        case wParam of
          112: ShowHelp('ru_configcommandswindow');
          204, 2: goto 1; //Close

          1: ChangeValue2; //Modify

          202:
            begin
              for TempInteger := 0 to CommandsArraySize - 1 do if Changed[TempInteger] = True then
                                                                  begin
                                                                  SaveValue2(TempInteger);
                                                                  end;
              SendMessage(SettingshLV, LVM_UPDATE, 0, 0);

              EnableWindowFalse(hwnddlg, 202);
              EnableWindowFalse(hwnddlg, 201);
            end;

          201:
            begin
              SaveValue2(ListView_GetNextItem(SettingshLV, -1, LVNI_SELECTED));
              EnableWindowFalse(hwnddlg, 201);
//              EnableWindowFalse(hwnddlg, 202);
            end;

          203: SendParameterToNetwork;

          ID_SHOWPASSWORDS_CB:                                            // Issue #783
            begin
              ShowPasswords := SendDlgItemMessage(hwnddlg, ID_SHOWPASSWORDS_CB,
                                                 BM_GETCHECK, 0, 0) = BST_CHECKED;
              RefreshPasswordRows(hwnddlg);
            end;

        end;
      end;

    WM_CLOSE:
      begin
        1:
        settingswindowhandle := 0;

        if SomeCommandWasChanged then
          if CommandsFilter = cfWK then
             begin
             wkClose;
             wkOpen;
             end;

//        SendMessage(SettingshLV, LVM_FIRST + 160, 0, 0);
        EndDialog(hwnddlg, 0);
        if tShouldRestartProgram then ShowMessage(
//        'Restart of the program is required for configuration change to take effect.'
            'To apply the changes TR4W needs to restart.'
            );

      end;
{
    WM_NOTIFY:
      begin

        with PNMHdr(lParam)^ do
          if (hWndFrom = SettingshLV) then
            case code of
              NM_DBLCLK: ChangeValue;
            end;
      end;
}
  end;

end;

// Issue #783 -- update only the value-column text of every ctPassword row
// in the listview, switching between PASSWORD_MASK and the live value based
// on ShowPasswords.  Cheap: O(rows), but only touches password rows.  Called
// when the operator toggles the "Show passwords" checkbox.
procedure RefreshPasswordRows(hwnddlg: HWND);
var
  rowCount, row, cmd: Integer;
begin
  if SettingshLV = 0 then Exit;
  rowCount := ListView_GetItemCount(SettingshLV);
  for row := 0 to rowCount - 1 do
     begin
     cmd := IndexArray[row + 1];   // IndexArray is 1-based
     if (cmd <= 0) or (cmd > CommandsArraySize) then Continue;
     if CFGCA[cmd].crType <> ctPassword then Continue;

     if ShowPasswords then
       // D12: skip the leading marker byte; tLVSetText copies internally, so the
       // old writable-buffer (ZeroMemory + lstrcpynA into buf) is gone.
        begin
        tLVSetText(SettingshLV, row, VALUE_FIELD, string(PAnsiChar(Integer(CFGCA[cmd].crAddress) + 1)))
        end
     else
        begin
        tLVSetText(SettingshLV, row, VALUE_FIELD, string(PASSWORD_MASK));
        end;
     end;
end;

procedure CommandsToListView2(f:cfgfunc  );

var
  i                                     : integer;
  Command                               : integer;
  p                                     : Pointer;
  TempInteger                           : integer;
  TempWindowElement                     : TMainWindowElement;
  valueStr                              : string;   // D12: native-string VALUE-field text for tLVSetText
//  TempPchar                             : PChar;
begin

  ListView_SetExtendedListViewStyle(SettingshLV, LVS_EX_INFOTIP or LVS_EX_GRIDLINES or LVS_EX_FULLROWSELECT);

  Settingslvc.Mask := LVCF_TEXT or LVCF_WIDTH or LVCF_FMT;
  Settingslvc.pszText := TC_COMMAND;
  Settingslvc.cx := 225;
  if CommandsFilter = cfCol then
     begin
     Settingslvc.cx := 275;
     end;
  uCommctrl.ListView_InsertColumnA(SettingshLV, COMMAND_FIELD, Settingslvc);

  Settingslvc.pszText := TC_VALUE;
  Settingslvc.cx := 220;
  if CommandsFilter = cfCol then
     begin
     Settingslvc.cx := 170;
     end;
  uCommctrl.ListView_InsertColumnA(SettingshLV, VALUE_FIELD, Settingslvc);

  Settingslvc.pszText := '#';
  Settingslvc.cx := 35;
  uCommctrl.ListView_InsertColumnA(SettingshLV, NUMBER_FIELD, Settingslvc);

  Settingslvc.pszText := RC_FILE;
  Settingslvc.cx := 45;
  uCommctrl.ListView_InsertColumnA(SettingshLV, FILE_FIELD, Settingslvc);

  Settingslvi.Mask := LVIF_TEXT;
  i := 0;

  if CommandsFilter = cfCol then
     begin
     for TempWindowElement := Low(TMainWindowElement) to High(TMainWindowElement) do
        begin
        {color begin}
        inc(i);
        tLVInsertRow(SettingshLV, i - 1, SysUtils.Format('%s WINDOW COLOR', [string(TWindows[TempWindowElement].mweName)]));
        tLVSetText(SettingshLV, i - 1, VALUE_FIELD, string(tr4wColorsSA[TWindows[TempWindowElement].mweColor]));
        tLVSetText(SettingshLV, i - 1, NUMBER_FIELD, IntToStr(i));
        {color end}

        inc(i);
        {background begin}
        tLVInsertRow(SettingshLV, i - 1, SysUtils.Format('%s WINDOW BACKGROUND', [string(TWindows[TempWindowElement].mweName)]));
        tLVSetText(SettingshLV, i - 1, VALUE_FIELD, string(tr4wColorsSA[TWindows[TempWindowElement].mweBackG]));
        tLVSetText(SettingshLV, i - 1, NUMBER_FIELD, IntToStr(i));
        {background end}

        end;

     // ALERT COLOR — standalone entry (not a TMainWindowElement pair)
     inc(i);
     tLVInsertRow(SettingshLV, i - 1, 'ALERT COLOR');
     tLVSetText(SettingshLV, i - 1, VALUE_FIELD, string(tr4wColorsSA[AlertColor]));
     tLVSetText(SettingshLV, i - 1, NUMBER_FIELD, IntToStr(i));

     Exit;
     end;

  for Command := 1 to CommandsArraySize do
    // Three reasons a row is hidden from Ctrl-J, and they are NOT the same:
    //   csRem   withdrawn -- inert.
    //   csJSON  moved to settings\tr4w.json -- inert; Preferences owns it now.
    //   csOwned another dialog owns the UI, but CheckCommand STILL APPLIES it,
    //           so the ini value remains the transport.
    if not (CFGCA[Command].crS in [csRem, csOwned, csJSON]) then
      if CFGCA[Command].crType in [ctFreqList, ctURL, ctCaseSensitive, ctPassword, ctPortLPT, ctDirectory, ctFileName, ctAlphaChar, ctChar, ctBand, ctReal, ctByte, ctInteger, ctMessage, ctWord, ctString, ctBoolean, ctOther, ctMultiplier] then
         begin

         //        if CommandsFilter <> cfAll then
                 if CFGCA[Command].cfFunc <> CommandsFilter then Continue;

         //        if pos('WINDOW',CFGCA[Command].crCommand) = 0 then Continue;

                 inc(i);

                 IndexArray[i] := Command;

                 // D12: COMMAND field creates the row; VALUE/NUMBER/FILE set via the
                 // native-string helper (no PChar/AnsiString at the call site).
                 tLVInsertRow(SettingshLV, i - 1, string(CFGCA[Command].crCommand));
         {-----------------------------------------------}
                 valueStr := '';

                 if CFGCA[Command].crKind in [ckArray] then
                    begin
                    valueStr := IntToStr(ArrayRecordArray[integer(CFGCA[Command].crAddress)].arVar^);
                    end;

                 if CFGCA[Command].crKind in [ckNormal, ckList] then
                    begin

                    case CFGCA[Command].crType of
                      ctFreqList:
                        valueStr := '...';

                      ctDirectory, ctFileName:
                        valueStr := string(PAnsiChar(CFGCA[Command].crAddress));

                      ctURL, ctMessage, ctString, ctCaseSensitive:
                        // boundary: config value stored with a leading marker byte; skip it (was inc(pszText))
                        valueStr := string(PAnsiChar(CFGCA[Command].crAddress) + 1);

                      ctPassword:                                                   // Issue #783
                        // Mask the value unless the operator ticked "Show passwords".
                        // Initial population only -- toggling the checkbox later
                        // calls RefreshPasswordRows to update without rebuilding.
                        if ShowPasswords then
                           begin
                           valueStr := string(PAnsiChar(CFGCA[Command].crAddress) + 1)
                           end
                        else
                           begin
                           valueStr := string(PASSWORD_MASK);
                           end;

                      ctBoolean:
                        valueStr := string(BA[PBoolean(CFGCA[Command].crAddress)^]);

                      ctReal:
                        // D12: RealToStr2 returns string; was a dangling PAnsiChar(AnsiString(...)) temp
                        valueStr := RealToStr2(PDouble(CFGCA[Command].crAddress)^);

                      ctInteger:
                        valueStr := IntToStr(PInteger(CFGCA[Command].crAddress)^);

                      ctWord:
                        valueStr := IntToStr(PWORD(CFGCA[Command].crAddress)^);

                      ctByte:
                        valueStr := IntToStr(PByte(CFGCA[Command].crAddress)^);

                      ctChar, ctAlphaChar:
                        if PAnsiChar(CFGCA[Command].crAddress)^ = ' ' then
                           begin
                           valueStr := 'SPACE'
                           end
                        else
                           begin
                           valueStr := Char(PAnsiChar(CFGCA[Command].crAddress)^);
                           end;

                    end;

                    if CFGCA[Command].crKind = ckList then
                       begin
                       TempInteger := integer(CFGCA[Command].crAddress);
                       p := PAnsiChar(ListParamArray[TempInteger].lpArray) + (ListParamArray[TempInteger].lpVar^ * 4);
                       p := Pointer(p^);
                       valueStr := string(PAnsiChar(p));
                       end;

                    end;
                 tLVSetText(SettingshLV, i - 1, VALUE_FIELD, valueStr);
         {-----------------------------------------------}
                 tLVSetText(SettingshLV, i - 1, NUMBER_FIELD, IntToStr(i));

                 if CFGCA[Command].crC = 1 then
                    begin
                    tLVSetText(SettingshLV, i - 1, FILE_FIELD, 'CFG');
                    end;
         end;

end;

procedure ChangeValue2;
label
  Change, EnableButtons;
var
  Row                                   : integer;
  Index                                 : integer;
  Index2                                : integer;
  TempString                            : ShortString;
  TempInteger                           : integer;
  TempReal                              : REAL;
  p                                     : Pointer;
  cmdProc                               : procedure;   // Issue #997: typed call of a Pointer change-handler
  c                                     : integer;
//  h                                     :HWND;
  TempColor                             : Ptr4wColors;
begin

  Row := SendMessage(SettingshLV, LVM_GETNEXTITEM, -1, 1);

  if CommandsFilter = cfCol then
     begin
     // ALERT COLOR is the last row — past the end of the TMainWindowElement pairs
     if Row >= (Ord(High(TMainWindowElement)) + 1) * 2 then
        begin
        if AlertColor = High(tr4wColors) then
           begin
           AlertColor := Low(tr4wColors)
           end
        else
           begin
           Inc(AlertColor);
           end;
        tLVSetText(SettingshLV, Row, VALUE_FIELD, string(tr4wColorsSA[AlertColor]));
        goto EnableButtons;
        end;

     TempInteger := Row div 2; //window
     if (Row mod 2) = 0 then
        begin
        TempColor := @TWindows[TMainWindowElement(TempInteger)].mweColor //1-back
        end
     else
        begin
        TempColor := @TWindows[TMainWindowElement(TempInteger)].mweBackG;
        end;
     if TempColor^ = High(tr4wColors) then TempColor^ := Low(tr4wColors) else inc(TempColor^);

     if TWindows[TMainWindowElement(TempInteger)].mweiStyle = 1 then
 //   if TMainWindowElement(TempInteger) = mweEditableLog then
        begin
        SetListViewColor(TMainWindowElement(TempInteger))
        end
     else

        begin
        Windows.InvalidateRect(wh[TMainWindowElement(TempInteger)], nil, False);
        end;
 //    Windows.FlashWindow(wh[TMainWindowElement(TempInteger)], false);

     tLVSetText(SettingshLV, Row, VALUE_FIELD, string(tr4wColorsSA[TempColor^]));

     if TWindows[TMainWindowElement(TempInteger)].mweName = 'QSO B4' then
        begin
        logger.Debug('Change of Foreground QSOB4 color');
        // Send colors for Dupes (QSOB4)
        //rgb := ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweBackG]);
        if assigned(wsjtx) then
           begin
           wsjtx.SetDupeBackgroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweBackG]));
        //rgb := ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweColor]);
           wsjtx.SetDupeForegroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweQSOB4Status].mweColor]));
           end;
        end
     else if TWindows[TMainWindowElement(TempInteger)].mweName = 'MULT' then
        begin
        // Send colors for multipliers
        //rgb := ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweBackG]);
        if assigned(wsjtx) then
           begin
           wsjtx.SetMultBackgroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweBackG]));
        //rgb := ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweColor]);
           wsjtx.SetMultForegroundColor(ColorToRGB(tr4wColorsArray[TWindows[mweNewMultStatus].mweColor]));
           end;
        end;


 {
    Index2 := integer(CFGCA[Index].crAddress);
    if ListParamArray[Index2].lpVar^ = High(tr4wColors) then
      ListParamArray[Index2].lpVar^ := 0 else inc(ListParamArray[Index2].lpVar^);
    p := PAnsiChar(ListParamArray[Index2].lpArray) + (ListParamArray[Index2].lpVar^ * 4);
    p := Pointer(p^);
    tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(p)));
}
     goto EnableButtons;
     end;

  Index := IndexArray[Row + 1];

  if CFGCA[Index].crJ = 2 then Exit;

  if
    (CFGCA[Index].crType in [ctFreqList, ctURL, ctCaseSensitive, ctPassword, ctDirectory, ctFileName, ctAlphaChar, ctChar, ctBoolean, ctString, ctByte, ctInteger, ctReal, ctWord])
    or (CFGCA[Index].crKind in [ckArray, ckList]) then
     begin

     if CFGCA[Index].crKind = ckList then
        begin
        Index2 := integer(CFGCA[Index].crAddress);
        if ListParamArray[Index2].lpVar^ = ListParamArray[Index2].lpLength then
          ListParamArray[Index2].lpVar^ := 0 else inc(ListParamArray[Index2].lpVar^);
        p := PAnsiChar(ListParamArray[Index2].lpArray) + (ListParamArray[Index2].lpVar^ * 4);
        p := Pointer(p^);
        tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(p)));
        goto Change;
        end;

     if CFGCA[Index].crKind in [ckArray] then
        begin
        Index2 := integer(CFGCA[Index].crAddress);
        for c := 0 to ArrayRecordArray[Index2].arArrayLength do
           begin
           //        if PChar(PChar(ArrayRecordArray[Index2].arArrayPtr) + (c * 4))^ = Char(ArrayRecordArray[Index2].arVar^) then
                   if PInteger(integer(ArrayRecordArray[Index2].arArrayPtr) + (c * 4))^ = integer(ArrayRecordArray[Index2].arVar^) then
                      begin
                      Break;
                      end;
           end;

        if (c) = ArrayRecordArray[Index2].arArrayLength - 0 then c := 0 else inc(c);
        ArrayRecordArray[Index2].arVar^ := PInteger(PAnsiChar(ArrayRecordArray[Index2].arArrayPtr) + (c * 4))^;
        tLVSetText(SettingshLV, Row, 1, IntToStr(ArrayRecordArray[Index2].arVar^));
        goto Change;
        end;

     case CFGCA[Index].crType of
       ctBoolean:
         begin
           InvertBoolean(PBoolean(CFGCA[Index].crAddress)^);
           tLVSetText(SettingshLV, Row, 1, string(BA[PBoolean(CFGCA[Index].crAddress)^]));
         end;

       ctByte:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));
           tInputDialogPreviousValue := IntToStr(PByte(CFGCA[Index].crAddress)^);
           TempInteger := QuickEditInteger(TC_NEWVALUE, 5);
           if TempInteger = -1 then Exit;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           if CheckCommand(@TempBuffer1, IntToStr(TempInteger)) then
              begin
              PByte(CFGCA[Index].crAddress)^ := TempInteger;
              tLVSetText(SettingshLV, Row, 1, IntToStr(TempInteger));
              end
           else
              begin
              Exit;
              end;
         end;

       ctWord:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));
           tInputDialogPreviousValue := IntToStr(PWORD(CFGCA[Index].crAddress)^);
           TempInteger := QuickEditInteger(TC_NEWVALUE, 5);
           if TempInteger = -1 then Exit;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           if CheckCommand(@TempBuffer1, IntToStr(TempInteger)) then
              begin
              PWORD(CFGCA[Index].crAddress)^ := TempInteger;
              tLVSetText(SettingshLV, Row, 1, IntToStr(TempInteger));
              end
           else
              begin
              Exit;
              end;
         end;

       ctReal:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));

           Val(tInputDialogPreviousValue, PDouble(CFGCA[Index].crAddress)^, TempInteger);
           TempReal := QuickEditReal(TC_NEWVALUE, 9);
           if TempReal = -1 then Exit;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           Str(TempReal: 2: 2, TempString);
           if CheckCommand(@TempBuffer1, TempString) then
              begin
              PDouble(CFGCA[Index].crAddress)^ := TempReal;

              tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
              end
           else
              begin
              Exit;
              end;
         end;

       ctInteger:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));
           tInputDialogPreviousValue := IntToStr(PInteger(CFGCA[Index].crAddress)^);
           TempInteger := QuickEditInteger(TC_NEWVALUE, 9);
           if TempInteger = -1 then Exit;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           if CheckCommand(@TempBuffer1, IntToStr(TempInteger)) then
              begin
              PInteger(CFGCA[Index].crAddress)^ := TempInteger;
              tLVSetText(SettingshLV, Row, 1, IntToStr(TempInteger));
              end
           else
              begin
              Exit;
              end;
         end;

       ctAlphaChar, ctChar:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));
           TempString := QuickEditResponse(TC_NEWVALUE, 1);
           if TempString = '' then Exit;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           if CheckCommand(@TempBuffer1, TempString) then
              begin
              PAnsiChar(CFGCA[Index].crAddress)^ := TempString[1];
              if TempString[1] = ' ' then
                 begin
                 Windows.ZeroMemory(@TempString, SizeOf(TempString));
                 TempString := 'SPACE';
                 end;
              tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
              end;
         end;

       ctDirectory:
         begin
           SelectFolder(settingswindowhandle, FileNameType(CFGCA[Index].crAddress^));
           SetFocus(settingswindowhandle);
           tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(CFGCA[Index].crAddress)));
         end;

       ctFileName:
         begin
           if not OpenFileDlg(nil, settingswindowhandle, nil, FileNameType(CFGCA[Index].crAddress^), OFN_HideReadOnly) then Exit;   // issue 289
           tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(CFGCA[Index].crAddress)));
         end;

       ctFreqList:
         begin
 //          tDialogBox(44, @BMCFDlgProc);
 //          DialogBox(hInstance, MAKEINTRESOURCE(44), settingswindowhandle, @BMCFDlgProc);
           CreateModalDialog(200, 155, settingswindowhandle, @BMCFDlgProc, 0);
           Exit;
         end;

       ctURL, ctString, ctCaseSensitive, ctPassword:
         begin
           Windows.ZeroMemory(@TempString, SizeOf(TempString));

           if CFGCA[Index].crType in [ctURL, ctCaseSensitive, ctPassword] then
              begin
              tInputDialogLowerCase := True;
              end;

           // Issue #783 -- ctPassword + "Show passwords" off: pre-fill with the
           // password mask and tell the input dialog to mask its input field
           // with '*'.  Pre-fill is the mask only when there is an existing
           // value; an empty field stays empty so the operator does not see
           // misleading asterisks for a never-set password.
           if (CFGCA[Index].crType = ctPassword) and (not ShowPasswords) then
              begin
              tInputDialogPassword := True;
              if Length(pShortString(CFGCA[Index].crAddress)^) > 0 then
                 begin
                 tInputDialogPreviousValue := PASSWORD_MASK
                 end
              else
                 begin
                 tInputDialogPreviousValue := '';
                 end;
              end
           else
              begin
              tInputDialogPreviousValue := pShortString(CFGCA[Index].crAddress)^;
              end;

           TempString := QuickEditResponse(TC_NEWVALUE, CFGCA[Index].crMax);

           if TempString = '' then Exit;

           // If the operator hit OK without changing the masked pre-fill, we
           // would otherwise overwrite the real password with literal '****'.
           // Detect and skip.
           if (CFGCA[Index].crType = ctPassword) and (not ShowPasswords) and
              (TempString = PASSWORD_MASK) then
              begin
              Exit;
              end;

           ListView_GetItemText(SettingshLV, Row, 0, @TempBuffer1[1], 40);
           if CheckCommand(@TempBuffer1, TempString {CMD}) then
              begin
              pShortString(CFGCA[Index].crAddress)^ := TempString;
              // For ctPassword, route through RefreshPasswordRows so the
              // listview honours the current "Show passwords" state instead
              // of leaking the new value in the clear.
              if CFGCA[Index].crType = ctPassword then
                 begin
                 RefreshPasswordRows(settingswindowhandle)
                 end
              else
                 begin
                 tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
                 end;
              end;
         end;
     end;

     Change:
     if CFGCA[Index].crP <> 0 then
        begin
        // Issue #997: asm `call P` (untyped Pointer change-handler) -> typed
        // call, guarded against a nil entry in the CommandsProcArray definition.
        @cmdProc := CommandsProcArray[CFGCA[Index].crP];
        if Assigned(cmdProc) then
           begin
           cmdProc;
           end;
        end;

     EnableButtons:
     Changed[Row] := True;
     SomeCommandWasChanged := True;
 //    if CFGCA[Index].crJ = 1 then tShouldRestartProgram := True;
     EnableWindowTrue(settingswindowhandle, 201);
     EnableWindowTrue(settingswindowhandle, 202);
     end;
end;

procedure SaveValue2(Row: integer);
label
  NoText;
var
  Index                                 : integer;
  p                                     : PAnsiChar;
  lpAppName                             : PAnsiChar;
begin
  Changed[Row] := False;
  Index := IndexArray[Row + 1];
  ListView_GetItemText(SettingshLV, Row, COMMAND_FIELD, @TempBuffer1, SizeOf(TempBuffer1));
  // Issue #997: asm `cmp eax,0 / jz NoText` tested the char count returned by
  // the VALUE_FIELD ListView_GetItemText -> test that result directly.
  if ListView_GetItemText(SettingshLV, Row, VALUE_FIELD, @TempBuffer2, SizeOf(TempBuffer2)) = 0 then
     begin
     goto NoText;
     end;

  p := TR4W_INI_FILENAME;
  lpAppName := _COMMANDS;

  case CommandsFilter of
    cfCol: lpAppName := 'COLORS';
    cfWK: lpAppName := 'WINKEYER';
  else
    begin
      tShouldRestartProgram := CFGCA[Index].crJ = 1;
      if CFGCA[Index].crC = 1 then
         begin
         p := TR4W_CFG_FILENAME;
         end;
    end;
  end;
{
  if CommandsFilter <> cfCol then
  begin
    tShouldRestartProgram := CFGCA[Index].crJ = 1;
    if CFGCA[Index].crC = 1 then p := TR4W_CFG_FILENAME;
  end
  else
    lpAppName := 'COLORS';
}
  Windows.WritePrivateProfileStringA(lpAppName, TempBuffer1, TempBuffer2, p);
  NoText:
end;

function NewSLVProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;
var
  lplvcd                                : PNMLVCustomDraw;
  Index                                 : integer;
begin
  if Msg = WM_NOTIFY then
     begin

     with PNMHdr(lParam)^ do
 //      if (hWndFrom = SettingshLV) then
        begin
        case code of
          LVN_ITEMCHANGED: ShowHelpMessageForCommand;
          NM_DBLCLK: ChangeValue2;
          NM_CUSTOMDRAW:
            begin
              lplvcd := PNMLVCustomDraw(lParam);

              case lplvcd.nmcd.dwDrawStage of
                CDDS_PREPAINT:
                  begin
                    Result := CDRF_NOTIFYITEMDRAW;
                    Exit;
                  end;
                CDDS_ITEMPREPAINT:
                  begin
                    if CommandsFilter <> cfCol then
                       begin
                       Index := IndexArray[lplvcd.nmcd.dwItemSpec + 1];
                       if (CFGCA[Index].crJ in [2, 3]) {RO} then lplvcd.clrText := $00B0B0B0;
                       if CFGCA[Index].crJ = 1 then
                          begin
                          lplvcd.clrText := $00FF0000;
                          end;
                       end;
                    if Changed[lplvcd.nmcd.dwItemSpec {Index}] then lplvcd.clrTextBk := $0000FFFF;
                  end;
              end;
            end;

        end;
        end;
     end;

  Result := CallWindowProc(OldSLVProc, hwnddlg, Msg, wParam, lParam);
end;

procedure ShowHelpMessageForCommand;
var
  Row                                   : integer;
  Index                                 : integer;
 // returnLen                             : integer;
begin
  Row := SendMessage(SettingshLV, LVM_GETNEXTITEM, -1, LVNI_SELECTED or LVNI_FOCUSED);
  if Row = -1 then Exit;
  if Row = PreviousHelpRow then Exit;
  PreviousHelpRow := Row;
  Index := IndexArray[Row + 1];
  Windows.EnableWindow(GetDlgItem(settingswindowhandle, 203), (NetSocket <> 0) and (CFGCA[Index].crJ <> 2) and (CFGCA[Index].crNetwork <> 0));  // Issue 610 ny4i
  Windows.EnableWindow(GetDlgItem(settingswindowhandle, 201), Changed[Row] = True);

  // Changes here are Issue 610 to show if parameter is sent to network or not
  ListView_GetItemText(SettingshLV, Row, COMMAND_FIELD, @TempBuffer1, SizeOf(TempBuffer1));
  //GetPrivateProfileStringA(TempBuffer1, 'DESCRIPTION', nil, wsprintfBuffer, SizeOf(wsprintfBuffer), TR4W_COMM_HELP_FILENAME);
  GetPrivateProfileStringA(TempBuffer1, 'DESCRIPTION', nil, tempprintfBuffer, SizeOf(tempprintfBuffer), TR4W_COMM_HELP_FILENAME);

  if CFGCA[Index].crNetwork = 0 then
     begin
     TF.Format(wsprintfBuffer, '%s %s %s', tempprintfBuffer, #13#10#13#10, 'NOT sent to network');
     end
  else
     begin
     TF.Format(wsprintfBuffer, '%s %s %s', tempprintfBuffer, #13#10#13#10, 'Sent to Network');
     end;
  Windows.SetDlgItemTextA(settingswindowhandle, 105, wsprintfBuffer);
  GetPrivateProfileStringA(TempBuffer1, 'DEFAULT', nil, wsprintfBuffer, SizeOf(wsprintfBuffer), TR4W_COMM_HELP_FILENAME);
  Windows.SetDlgItemTextA(settingswindowhandle, 104, wsprintfBuffer);

end;

procedure SendParameterToNetwork();
var
  Row                                   : integer;
begin
  if NetSocket = 0 then Exit;
  Row := ListView_GetNextItem(SettingshLV, -1, LVNI_SELECTED);
  if CommandsFilter <> cfCol then
    if CFGCA[IndexArray[Row + 1]].crJ = 2 then Exit; // 2 is read-only

  if CFGCA[IndexArray[Row + 1]].crNetwork = 0 then     // Issue 610 ny4i
     begin
     logger.debug('[SendParameterToNetwork] Exiting before network send for command %s due to crNetwork = 0',[CFGCA[IndexArray[Row + 1]].crCommand]);
     Exit;
     end;
  Windows.ZeroMemory(@ParameterToNetwork.pnCommand, SizeOf(ParameterToNetwork.pnCommand) + SizeOf(ParameterToNetwork.pnValue));
{(*}
  ParameterToNetwork.pnCommand[0] := AnsiChar(ListView_GetItemText(SettingshLV, Row, COMMAND_FIELD, @ParameterToNetwork.pnCommand[1], SizeOf(ParameterToNetwork.pnCommand)));
  ParameterToNetwork.pnValue[0]   := AnsiChar(ListView_GetItemText(SettingshLV, Row, VALUE_FIELD,   @ParameterToNetwork.pnValue[1],   SizeOf(ParameterToNetwork.pnValue)));
{*)}
  SendToNet(ParameterToNetwork, SizeOf(ParameterToNetwork));
end;

end.

