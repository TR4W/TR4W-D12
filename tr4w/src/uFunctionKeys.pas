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
unit uFunctionKeys;
{$I tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses
  SysUtils,
  uGradient,
  TF,
  VC,
  Windows,
  Messages,
utils_text,
  uAltP,
  LogWind,
  LogCW,
  Tree;

function FunctionKeysWindowDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
procedure ShowFMessages(VirtualKey: Byte);
procedure EditFunctionKeyMessage(const aKey: integer);
procedure ShowFunctionKeyContextMenu(const aKey: integer);

{ THE BEHAVIOUR BEHIND THE PANELS.  Installed into uFunctionKeysForm's procedure
  variables at unit initialisation -- see the note there for why the two units
  reach each other that way rather than by a uses clause.

  Each takes the KEY CODE (112..123), not a window handle: the panel's Tag says
  which key it is, so nothing has to scan twelve handles looking for a match. }
procedure FKeyClicked(const aKey: integer);
procedure FKeyRightClicked(const aKey: integer);
procedure FKeyRightDoubleClicked(const aKey: integer);

const
  ButtonsColor                          : array[112..123] of tcolor =

  (
    clwhite,
    clwhite,
    clwhite,
    clwhite,

    clYellow,
    clYellow,
    clYellow,
    clYellow,

    clwhite,
    clwhite,
    clwhite,
    clwhite
    );

{
  (
    clblue,
    clblue,
    clblue,
    clblue,

    clYellow,
    clYellow,
    clYellow,
    clYellow,

    clblue,
    clblue,
    clblue,
    clblue
    );
}
var
  KeysHandles                           : array[112..123] of HWND;
  ButtonsText                           : array[112..123] of Str40;

//  FKCloseButton                         : HWND;
  FKRButtonTimerHAndle                  : HWND;

implementation
uses
  MainUnit,
  uFunctionKeysForm,   // the panels; this unit supplies what a key press MEANS
  uConfigValues;   // Config.IncludeFKeyNumber

function FunctionKeysWindowDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1;
var
  i                                     : integer;
  Left                                  : integer;
  temprect                              : TRect;
  Width                                 : integer;
  Height                                : integer;
  FKDRAWITEMSTRUCT                      : PDrawItemStruct;
  TempCardinal                          : Cardinal;
  TempColor                             : tcolor;
//  b                                     : Byte;
const
//  fkbstleft                             = 26;
  delta                                 = 2;
//  FKCloseButtonID                       = 222;
//  ClosrButWidth                         = 14-14;
begin
  Result := False;
  case Msg of
    WM_LBUTTONDOWN, WM_WINDOWPOSCHANGING, WM_EXITSIZEMOVE: DefTR4WProc(Msg, lParam, hwnddlg);

    WM_DRAWITEM:
      begin
        Result := True;
        FKDRAWITEMSTRUCT := Pointer(lParam);
{
        if FKDRAWITEMSTRUCT^.hwndItem = FKCloseButton then
        begin
          TempCardinal := DFCS_CAPTIONCLOSE or DFCS_FLAT;
          if (lobyte(FKDRAWITEMSTRUCT^.itemState) = ODS_SELECTED or ODS_FOCUS) then TempCardinal := DFCS_CAPTIONCLOSE or DFCS_PUSHED;
          DrawFrameControl(FKDRAWITEMSTRUCT^.HDC, FKDRAWITEMSTRUCT^.rcItem, DFC_CAPTION, TempCardinal);
          Exit;
        end;
}
        if (lobyte(PDrawItemStruct(lParam).itemState) = ODS_SELECTED or ODS_FOCUS) then

           begin
           TempCardinal := EDGE_SUNKEN
           end
        else
           begin
           TempCardinal := {EDGE_RAISED; //} EDGE_ETCHED;
           end;

        DrawEdge(FKDRAWITEMSTRUCT^.HDC, FKDRAWITEMSTRUCT^.rcItem, TempCardinal, BF_TOPLEFT or BF_BOTTOMRIGHT);

//        DrawFrameControl(FKDRAWITEMSTRUCT^.HDC, FKDRAWITEMSTRUCT^.rcItem, DFC_BUTTON, DFCS_BUTTONPUSH	);

        FKDRAWITEMSTRUCT^.rcItem.Right := FKDRAWITEMSTRUCT^.rcItem.Right - delta;
        FKDRAWITEMSTRUCT^.rcItem.Left := FKDRAWITEMSTRUCT^.rcItem.Left + delta;
        FKDRAWITEMSTRUCT^.rcItem.Top := FKDRAWITEMSTRUCT^.rcItem.Top + delta;
        FKDRAWITEMSTRUCT^.rcItem.Bottom := FKDRAWITEMSTRUCT^.rcItem.Bottom - delta;

        SetBkMode(FKDRAWITEMSTRUCT^.HDC, TRANSPARENT);
        TempColor := ButtonsColor[FKDRAWITEMSTRUCT^.CtlID];
//        TempColor := tr4wColorsArray[tr4wColors(FKDRAWITEMSTRUCT^.CtlID - 112+4)];
        GradientRect(FKDRAWITEMSTRUCT^.HDC, FKDRAWITEMSTRUCT^.rcItem, TempColor, TempColor, gdVertical);

//        b := GetGValue(Cardinal(ButtonsColor[FKDRAWITEMSTRUCT^.CtlID]));
//        if b < 128 then
//        if TempColor = 0 then
        Windows.SetTextColor(FKDRAWITEMSTRUCT^.HDC, 0);

{
        TempColor := ButtonsColor[FKDRAWITEMSTRUCT^.CtlID];
        asm
        mov eax,TempColor
        cmp eax,0
        jnz @@1
        mov eax,clWhite
        @@1:
        bswap eax
        mov TempColor,eax
        end;
        Windows.SetTextColor(FKDRAWITEMSTRUCT^.HDC, TempColor);
}
        if (lobyte(FKDRAWITEMSTRUCT^.itemState) = ODS_SELECTED or ODS_FOCUS) then
           begin
           FKDRAWITEMSTRUCT^.rcItem.Bottom := FKDRAWITEMSTRUCT^.rcItem.Bottom + delta;
           FKDRAWITEMSTRUCT^.rcItem.Right := FKDRAWITEMSTRUCT^.rcItem.Right + delta;
           end;
        Windows.DrawTextA(
          FKDRAWITEMSTRUCT^.HDC,
          @ButtonsText[FKDRAWITEMSTRUCT^.CtlID][1],
          length(ButtonsText[FKDRAWITEMSTRUCT^.CtlID]),
          FKDRAWITEMSTRUCT^.rcItem,
          {DT_END_ELLIPSIS + }DT_EDITCONTROL + DT_WORDBREAK + DT_CENTER + DT_VCENTER);
      end;

    WM_SIZE:
      begin
        Windows.GetClientRect(hwnddlg, temprect);
        Width := (temprect.Right - temprect.Left - 30) div 12;
        Height := temprect.Bottom - temprect.Top;
        Left := 0;
        for i := 112 to 123 do
           begin

           Windows.MoveWindow(KeysHandles[i], Left, 0, Width, Height, True);
           inc(Left, Width + 1);
           if (i = 115) or (i = 119) then
              begin
              inc(Left, 10);
              end;
           end;
//        Windows.MoveWindow(FKCloseButton, temprect.Right - temprect.Left - ClosrButWidth, 0, ClosrButWidth, ClosrButWidth, True);
        InvalidateRect(hwnddlg, nil, False);
      end;

    WM_INITDIALOG:
      begin
        tr4w_WindowsArray[tw_FUNCTIONKEYSWINDOW_INDEX].WndHandle := hwnddlg;

        for i := 112 to 123 do
           begin
           KeysHandles[i] := tCreateButtonWindow(0, '', BS_OWNERDRAW or BS_AUTORADIOBUTTON or BS_PUSHLIKE or BS_LEFT or WS_CHILD or WS_VISIBLE or BS_NOTIFY, 0, 0, 0, 0, hwnddlg, i);
           // Issue #997: asm tWM_SETFONT -> TF helper (EAX = KeysHandles[i] above).
           tWM_SETFONT(KeysHandles[i], MainFixedFont);
           end;
//        FKCloseButton := tCreateButtonWindow(0, nil, BS_OWNERDRAW or BS_PUSHLIKE or WS_CHILD or WS_VISIBLE or BS_NOTIFY, 0, 0, 0, 0, hwnddlg, FKCloseButtonID);

        ShowFMessages(0);
//        for I := 112 to 115 do ButtonsColor[I] := $FFFFFF;
//        for I := 116 to 119 do ButtonsColor[I] := $FF0000;
//        for I := 120 to 123 do ButtonsColor[I] := $0000FF;
      end;

    WM_CLOSE: 1: CloseTR4WWindow(tw_FUNCTIONKEYSWINDOW_INDEX);

    WM_COMMAND:
      begin
//        if wParam = FKCloseButtonID then goto 1;
        if HiWord(wParam) = BN_CLICKED then
          if LoWord(wParam) in [112..123] then
             begin
             // FIRST instruction after Windows tells us the button was clicked.
             // Timestamp this against the '[ <radio> TX]' / '[wkSendByte]' trace
             // to measure the click -> CW latency NY4I reported (2026-07-31);
             // FrmSetFocus and ProcessFuntionKeys both run after this point, so
             // anything between the two timestamps is ours, not Windows'.
             logger.Trace('[FunctionKeysWindow] MOUSE CLICK on F%d received',
                          [LoWord(wParam) - 111]);
             FrmSetFocus;
             ProcessFuntionKeys(LoWord(wParam));
             logger.Trace('[FunctionKeysWindow] MOUSE CLICK on F%d dispatched',
                          [LoWord(wParam) - 111]);
             end;
      end;
  end;

end;

procedure ShowFMessages(VirtualKey: Byte);
var
  i                                     : integer;
  s                                     : string;
  plus                                  : Byte;
  PosOfAmp                              : integer;
  { AnsiChar, NOT Char -- and this was the Ctrl-P crash.

    Char is WideChar here (tr4w.inc turns on the UnicodeStrings mode
    switch) while the memory arrays are indexed by F1..AltF12, which are
    AnsiChar constants from tree.pas -- SizeOf(F1) is 1. CHR(139) stored in
    a WideChar does NOT hold 139: it round-trips through CP1252 and holds
    U+2039, ordinal 8249. Indexing an AnsiChar-ranged array with that reads
    roughly eight thousand elements past the row.

    Below 128 the two agree, which is why plain F1..F12 (112..123) always
    worked and only Ctrl (124..135) and Alt (136..147) faulted -- the range
    that crosses 128. With range checking off it does not raise; it just
    reads whatever is there and dereferences it. }
  b                                     : AnsiChar;
  TempMode                              : ModeType;
begin

  if not tWindowsExist(tw_FUNCTIONKEYSWINDOW_INDEX) then Exit;

  // THE COLOURS, applied here rather than at creation.  ButtonsColor is the same
  // table the owner-draw read; setting it on every refresh costs nothing (twelve
  // property writes, and the LCL skips a repaint when the value is unchanged)
  // and means the panels cannot drift from the table if it is ever made
  // configurable -- which is the obvious next thing to ask for.
  if TR4WFunctionKeysForm <> nil then
     begin
     for i := 112 to 123 do
        begin
        TR4WFunctionKeysForm.SetKeyColor(i, ButtonsColor[i]);
        end;
     end;
  TempMode := ActiveMode;
  if TempMode = FM then
     begin
     TempMode := Phone;
     end;
  if TempMode = Digital then
     begin
     TempMode := CW;
     end;

  if not (TempMode in [CW, Phone {, FM, Digital}]) then Exit;
  plus := VirtualKey;
  for i := 112 to 123 do
     begin
     b := CHR(i + plus);
     if OpMode2 {OpMode} = CQOpMode then
        begin
        if ((CQCaptionMemory[TempMode, b] <> nil) and (CQCaptionMemory[TempMode, b]^ <> '')) then
           begin
           s := CQCaptionMemory[TempMode, b]^
           end
        else
           begin
           s := GetCQMemoryString(TempMode, b);
           end;
        end
     else
        begin
        if ((EXCaptionMemory[TempMode, b] <> nil) and (EXCaptionMemory[TempMode, b]^ <> '')) then
           begin
           s := EXCaptionMemory[TempMode, b]^
           end
        else
           begin
           s := GetEXMemoryString(TempMode, b);
           end;
        end;
     PosOfAmp := tPos(s, '&');
     if PosOfAmp <> 0 then
        begin
        Insert('&', s, PosOfAmp);
        end;
     if Config.IncludeFKeyNumber then
        begin
        ButtonsText[i] := 'F' + IntToStr(i - 111) + #13#10 + s
        end
     else
        begin
        ButtonsText[i] := s;
        end;

     // ONTO THE PANEL.  This used to write ButtonsText[i] and invalidate the
     // owner-draw button; the caption IS the text now, and the LCL repaints.
     //
     // ButtonsText is kept because it is the value, and keeping it means this
     // loop still reads the same before and after -- but nothing draws from it
     // any more.
     if TR4WFunctionKeysForm <> nil then
        begin
        TR4WFunctionKeysForm.SetKeyCaption(i, ButtonsText[i]);
        end;
     end;
end;

// Resolve which Alt-P editor row the on-screen function-key button `h` maps to,
// and set the CQ vs S&P target window. The 12 buttons are labelled F1..F12 but
// display whichever shift bank the window currently shows (plain / Ctrl / Alt),
// so we read the live modifier state. The editor lists F1..AltF12, hence
// row = (button - 112) + bank offset (0/12/24). Returns -1 if `h` is not a
// function-key button. Caller must capture this BEFORE the modifier is released
// (e.g. before popping a menu). Issue #1001.
function ResolveFunctionKeyRow(const aKey: integer): integer;
var
  plus                                  : integer;
begin
  // BY KEY CODE, not by scanning twelve window handles.  The panels carry their
  // key in Tag, so the caller already knows which one was clicked -- the scan
  // existed only because a Win32 message handed us an HWND and nothing else.
  Result := -1;
  if (aKey < 112) or (aKey > 123) then
     begin
     Exit;
     end;

  if OpMode = SearchAndPounceOpMode then
     begin
     MesWindow := ExMsgWin
     end
  else
     begin
     MesWindow := CQMsgWin;
     end;

  // The bank comes from the LIVE modifier state, and the caller must read it
  // BEFORE anything lets the operator release Ctrl/Alt -- popping a menu, for
  // one.  Issue #1001.
  plus := 0;
  if (GetKeyState(VK_MENU) and $8000) <> 0 then
     begin
     plus := 24
     end
  else if (GetKeyState(VK_CONTROL) and $8000) <> 0 then
     begin
     plus := 12;
     end;

  Result := (aKey - 112) + plus;
end;

// Open the Alt-P message editor focused on the function key whose button is `h`
// (mode- and shift-bank-aware). Used by the legacy right-double-click path.
procedure EditFunctionKeyMessage(const aKey: integer);
var
  row                                   : integer;
begin
  row := ResolveFunctionKeyRow(aKey);
  if row < 0 then Exit;
  InitialAltPSelection := row;
//tDialogBox(72, @MemoryProgramDlgProc);
  OpenListOfMessages;
  FrmSetFocus;   // see note in ShowFunctionKeyContextMenu
end;

procedure FKeyRightDoubleClicked(const aKey: integer);
begin
  EditFunctionKeyMessage(aKey);
end;

procedure FKeyClicked(const aKey: integer);
begin
  // WM_COMMAND / BN_CLICKED used to arrive here with LoWord(wParam) as the
  // control id, which was the key code.  The panel's Tag is that same number.
  logger.Trace('[FunctionKeysWindow] MOUSE CLICK on F%d received', [aKey - 111]);
  FrmSetFocus;
  ProcessFuntionKeys(aKey);
  logger.Trace('[FunctionKeysWindow] MOUSE CLICK on F%d dispatched', [aKey - 111]);
end;

// Right-click a function-key button -> show a one-item context menu that opens
// the editor on that key. The target row is captured NOW (while any Alt/Ctrl
// modifier is still held) so the bank stays correct even after the user
// releases the modifier to click the menu. Label is composed from translated
// words; the key name (e.g. "F3") is not translated. Issue #1001.
procedure FKeyRightClicked(const aKey: integer);
begin
  ShowFunctionKeyContextMenu(aKey);
end;

procedure ShowFunctionKeyContextMenu(const aKey: integer);
const
  ID_EDITFKEY                           = 1;
var
  row                                   : integer;
  prefix                                : string;
  keyName                               : string;
  caption                               : string;
  p                                     : integer;
  hMenu                                 : Windows.HMENU;   // qualified: an 'HMENU' identifier in this unit's scope shadows the type
  pt                                    : Windows.TPoint;
  cmd                                   : integer;
begin
  // Issue #1007: ignore right-click while Alt or Ctrl is held. The window is
  // showing the Alt-F/Ctrl-F bank then, and popping the menu + the FrmSetFocus
  // that follows would flash the labels back to plain (WM_SETFOCUS ->
  // ShowFMessages(0)). Right-click edits the plain F-keys only; edit the
  // Alt-F/Ctrl-F messages via the Alt-P editor.
  if ((GetKeyState(VK_MENU) and $8000) <> 0)    or
     ((GetKeyState(VK_CONTROL) and $8000) <> 0) then
     begin
     Exit;
     end;
  row := ResolveFunctionKeyRow(aKey);
  if row < 0 then Exit;

  case row div 12 of            // 0 = plain, 1 = Ctrl, 2 = Alt
     1: prefix := 'Ctrl-F';
     2: prefix := 'Alt-F';
  else
     prefix := 'F';
  end;
  keyName := prefix + IntToStr((row mod 12) + 1);   // e.g. 'F3', 'Ctrl-F10' (not translated)
  // TC_EDITFUNCTIONKEY is the per-language 'Edit %s message' format; substitute
  // the key name for %s. Pos/Copy avoids a wsprintf varargs call.
  caption := TC_EDITFUNCTIONKEY;
  p := Pos('%s', caption);
  if p > 0 then
     begin
     caption := Copy(caption, 1, p - 1) + keyName + Copy(caption, p + 2, Length(caption));
     end;

  hMenu := Windows.CreatePopupMenu;
  Windows.AppendMenuW(hMenu, MF_STRING, ID_EDITFKEY, PChar(caption));
  Windows.GetCursorPos(pt);
  // NB: do NOT SetForegroundWindow here -- it fires WM_SETFOCUS, whose handler
  // calls ShowFMessages(0) and reverts the function-key window to the plain
  // bank while the menu is up (mismatching an "Edit Ctrl-Fn" label). The app is
  // already foreground on right-click, so the menu dismisses fine without it
  // (same as the band-map popup). Issue #1001.
  cmd := integer(Windows.TrackPopupMenu(hMenu,
                 TPM_RETURNCMD or TPM_LEFTALIGN or TPM_TOPALIGN or TPM_LEFTBUTTON,
                 pt.x, pt.y, 0, tr4whandle, nil));
  Windows.DestroyMenu(hMenu);

  if cmd = ID_EDITFKEY then
     begin
     InitialAltPSelection := row;    // captured before the modifier was released
     OpenListOfMessages;
     end;

  // Right-clicking the button + showing the menu (and the modal editor) leaves
  // focus off the Call window. Restore it -- the Ctrl/Alt bank-switch handler in
  // the main loop only fires when focus is the Call/Exchange window, so without
  // this those keys stop updating the F-key labels. Mirrors the left-click
  // (BN_CLICKED) handler above. Issue #1001.
  FrmSetFocus;
end;

initialization
  // THE PANELS CALL BACK IN HERE.  uFunctionKeysForm owns the widgets and knows
  // nothing about memories, banks or the Alt-P editor; this unit owns all of
  // that and nothing about TPanel.  Procedure variables rather than a uses
  // clause because the dependency genuinely runs both ways -- see the type
  // declaration in that unit.
  uFunctionKeysForm.FunctionKeyClicked            := @FKeyClicked;
  uFunctionKeysForm.FunctionKeyRightClicked       := @FKeyRightClicked;
  uFunctionKeysForm.FunctionKeyRightDoubleClicked := @FKeyRightDoubleClicked;

end.
