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
unit uEditMessage;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface
//
uses
  uMessagesList,
  CFGCMD,
  TF,
  VC,
  uCommctrl,
  utils_file,
  Windows,
  Messages,
  MMSystem,
  Tree,
  LogWind

  ;

function EditMessageDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
function NewMsgEditProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;
procedure DeleteEscapeChars(var s: ShortString);


var
  flashreminder                         : boolean;
  ReminderDlgHandle                     : HWND;
  MsgEditHWND                           : HWND;
  OldMsgEditProc                        : Pointer;
  AllowEscapes                          : boolean;
  EditMessageWnd                        : HWND;
//  EditMessageWndRect                    : TRect;
  SelPos                                : array[102..103] of integer = (255, 255);

// the single-message editor.  Parent and message index both come from the
// caller (uAltP passes its own window and the selected message).
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else does.
procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);

implementation
uses
   uConfigValues, uCFG,
  uAltP,
  MainUnit;

function EditMessageDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1 {, 2};
var
  i                                     : Cardinal;
  ID                                    : Str80;
  CMD                                   : ShortString;
  h                                     : HWND;
  p                                     : PAnsiChar;
//  HDS                                   : PDrawItemStruct;
//  Color1                                : Cardinal;
const
  m                                     = 'Messages';

begin
  Result := False;
  case Msg of
    WM_INITDIALOG:
      begin

        Windows.SetWindowTextA(hwnddlg, RC_PROGRMESS);

        CreateStatic(nil, 5, 5, 450 + 40, hwnddlg, 101);
        CreateStatic(RC_MESSAGE, 5, 35, 60, hwnddlg, 107);
        CreateStatic(RC_CAPTION, 5, 60, 60, hwnddlg, 106);

        CreateEdit(0, 70, 35, 385 + 40, 23, hwnddlg, 102);
        CreateEdit(0, 70, 60, 385 + 40, 23, hwnddlg, 103);

        EditMessageWnd := hwnddlg;
        for i := 0 to 2 do
           begin
           ListView_GetItemText(AltPListView, lParam, i, TempBuffer1, SizeOf(TempBuffer1));
           Windows.SetDlgItemTextA(hwnddlg, 101 + i, TempBuffer1);
           //if I = 2 then Continue;

           // Issue #997: asm tWM_SETFONT (EAX = GetDlgItem result) -> direct call.
           tWM_SETFONT(GetDlgItem(hwnddlg, 101 + i), TerminalFont);

           end;
        if MesWindow = OtherMsgWin then
           begin
           EnableWindowFalse(hwnddlg, 103);
           end;
        MsgEditHWND := GetDlgItem(hwnddlg, 102);
        OldMsgEditProc := Pointer(Windows.SetWindowLong(MsgEditHWND, GWL_WNDPROC, integer(@NewMsgEditProc)));

        CreateOKCancelButtons(hwnddlg);
        CreateButton(0, TC_LIST_OF_COMMAND, 385, 105, 110, hwnddlg, 3);
        CreateButton(0, RC_EDIT_WORD, 5, 105, 110, hwnddlg, 109);

        if ActiveMode <> Phone then
           begin
           TF.EnableWindowFalse(hwnddlg, 109);
           end;

//        goto 2;
      end;

    WM_CLOSE: 1:
      begin
        //if ActiveMode = Phone then sndPlaySound(nil, SND_ASYNC or SND_NODEFAULT);
        EndDialog(hwnddlg, 0);
      end;

//    WM_MOUSEACTIVATE, WM_MOVING: begin DestroyHintListBox; end;
//    WM_MOVE: 2: Windows.GetWindowRect(EditMessageWnd, EditMessageWndRect);
    WM_COMMAND:
      begin

//        if HiWord(wParam) = LBN_DBLCLK then PutCommandFromHintListBox;
        if HiWord(wParam) = EN_SETFOCUS then
           begin
           Windows.SendDlgItemMessage(hwnddlg, LoWord(wParam), EM_SETSEL, SelPos[LoWord(wParam)], SelPos[LoWord(wParam)]);
           end;

        if HiWord(wParam) = EN_KILLFOCUS then
           begin
           Windows.SendDlgItemMessage(hwnddlg, LoWord(wParam), EM_GETSEL, integer(@SelPos[LoWord(wParam)]), integer(@SelPos[LoWord(wParam)]));
           end;
//        if lParam = integer(MsgEditHWND) then if HiWord(wParam) = EN_KILLFOCUS then DestroyHintListBox;

        case wParam of
          3:
            begin
            // SelPos[102] is saved by EN_KILLFOCUS when the edit field loses
            // focus to this button, so it already holds the cursor position.
            if ShowMessagesList(EditMessageWnd) = 1 then
               begin
               Windows.SendMessage(MsgEditHWND, EM_SETSEL, SelPos[102], SelPos[102]);
               Windows.SendMessageA(MsgEditHWND, EM_REPLACESEL, 1, Integer(PAnsiChar(AnsiString(LastSelectedCommand))));
               SetFocus(MsgEditHWND);
               end;
            end;
          109:
            begin
              i := Windows.GetDlgItemTextA(hwnddlg, 102, @TempBuffer2, SizeOf(ID));
              if i < 5 then Exit;
              if PInteger(@TempBuffer2[i - 4])^ <> 1447122734 then Exit;

              if Config.DVKRecorder[0] = #0 then
                 begin
                 SetCommand('DVP RECORDER');
                 Exit;
                 end;

              p := GetRealPath(Config.DVKPath, TempBuffer2, nil);
{
              asm
              lea  eax,TempBuffer2
              push eax
              lea  eax,TR4W_DVPPATH
              push eax
              end;
              wsprintf(TempBuffer1, '%s\%s');
              asm add esp,16
              end;
}
              if not FileExists(p) then
                 begin
                 if YesOrNo(hwnddlg, TC_THIS_FILE_DOES_NOT_EXIST) = IDno then Exit;
                 if tOpenFileForWrite(h, p) then
                    begin
                    sWriteFile(h, waveheader, length(waveheader));
                    CloseHandle(h);
                    end;
                 end;

              TF.Format(TempBuffer1, '"%s" "%s"', Config.DVKRecorder, p);
              WinExec(TempBuffer1, SW_SHOWNORMAL);
//              if FileExists(TempBuffer1) then if sndPlaySound(TempBuffer1, SND_ASYNC or SND_NODEFAULT) then Exit;
//              ShowSysErrorMessage('PLAY FILE');
            end;

          2: goto 1;
          1: //if not PutCommandFromHintListBox then
            begin
              ID[0] := AnsiChar(Windows.GetDlgItemTextA(hwnddlg, 101, @ID[1], 80));
              CMD[0] := AnsiChar(Windows.GetDlgItemTextA(hwnddlg, 102, @CMD[1], 255));
              DeleteEscapeChars(CMD);
              Windows.WritePrivateProfileStringA(m, @ID[1], @CMD[1], @TR4W_CFG_FILENAME);
              CheckCommand(@ID, CMD);

              if MesWindow <> OtherMsgWin then
                 begin
                 i := Windows.GetDlgItemTextA(hwnddlg, 103, @CMD[1], 255);
 //              if I <> 0 then
                 begin
                   CMD[0] := AnsiChar(i);
                   Windows.lstrcatA(@ID[1], ' CAPTION');
                   inc(Byte(ID[0]), 8);
                   p := @CMD[1];
                   if CMD = '' then
                      begin
                      p := nil;
                      end;
                   Windows.WritePrivateProfileStringA(m, @ID[1], p, @TR4W_CFG_FILENAME);
                   CheckCommand(@ID, CMD);
                 end;
                 end;

              DisplaymessagesList(MesWindow, ActiveMode);
              goto 1;
            end;
        end;
      end;
  end;
end;

function NewMsgEditProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): UINT; stdcall;
var
  c                                     : Cardinal;
  Selection                             : TSelection;
  i                                     : integer;
begin
  Result := 0;
  if Msg = WM_PASTE then if GetKeyState(VK_CONTROL) < -126 then Exit;

  if Msg = WM_KEYDOWN then
     begin
         if GetKeyState(VK_CONTROL) < -126 then
            begin

            //      if wParam = 32 then
            //      begin
            //        ControlSpace := True;
            //        CreateHintListBox;
            //      end;

                  if wParam <> 17 then
                     begin

                     if wParam = 80 then
                       if not AllowEscapes then
                          begin
                          AllowEscapes := True;
                          Exit;
                          end;
                     if not AllowEscapes then Exit;

                     SendMessage(MsgEditHWND, EM_GETSEL, LONGINT(@Selection.StartPos), LONGINT(@Selection.EndPos));
                     c := Windows.GetWindowTextA(MsgEditHWND, TempBuffer1, 255);

                     TempBuffer1[c + 1] := #0;
                     if c <> 0 then
                        begin
                        for i := c - 1 downto Selection.EndPos do
                           begin
                           TempBuffer1[i + 1] := TempBuffer1[i];
                           end;
                        end;
                     TempBuffer1[Selection.StartPos] := AnsiChar(wParam - 64);

                     Windows.SetWindowTextA(MsgEditHWND, TempBuffer1);
                     Windows.SendMessage(MsgEditHWND, EM_SETSEL, Selection.StartPos + 1, Selection.EndPos + 1);
                     AllowEscapes := False;
                     end;
            end;
     end;

  Result := CallWindowProc(OldMsgEditProc, hwnddlg, Msg, wParam, lParam);

//  if Msg = WM_CHAR then showint(RESULT);
end;

// DELETED HERE (Phase 4b): CreateHintListBox, DestroyHintListBox,
// AddHintsToHintListBox and MoveSelectedItemInHintListBox -- the whole
// command-hint / autocomplete popup, about 125 lines.
//
// IT WAS NOT MERELY UNREACHABLE, IT COULD NOT COMPILE IF IT WERE.  Its only
// live call was inside a brace comment, so HintListBoxCreated was never set
// and every guard on it was dead -- but the proof is stronger than that:
// AddHintsToHintListBox referenced HintMessageArray, an identifier that exists
// NOWHERE in this tree (checked across src, tr4w.dpr and every .inc).  FPC
// would refuse it.  The program builds; therefore that text was a comment.
procedure DeleteEscapeChars(var s: ShortString);
const
  HexChars                              : array[0..$F] of AnsiChar = '0123456789ABCDEF';
var
  TempString                            : ShortString;
  i                                     : integer;
  l                                     : integer;
begin
  l := 0;
  for i := 1 to length(s) do
     begin
     inc(l);
     if s[i] > CHR(31) then
        begin
        TempString[l] := s[i];
        end
     else
        begin
        TempString[l] := '<';
        TempString[l + 1] := HexChars[Ord(s[i]) shr $4];
        TempString[l + 2] := HexChars[Ord(s[i]) and $F];
        TempString[l + 3] := '>';
        inc(l, 3);
        end;
     end;
  TempString[0] := AnsiChar(l);
  s := TempString;
  s[l + 1] := #0;
end;


procedure ShowEditMessage(const aParent: HWND; const aMessage: lParam);
begin
   CreateModalDialog(250, 70, aParent, @EditMessageDlgProc, aMessage);
end;
end.

