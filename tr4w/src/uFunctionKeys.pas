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
  (* LCLIntf for GetKeyState and LCLType for VK_MENU / VK_CONTROL, not
    Windows -- the LCL declares the call for every widget set and each one
    answers for its own keyboard. Messages declared nothing. *)
  LCLIntf,
  LCLType,
  Types,      { TPoint -- was the Windows unit's, and they are the same record }
utils_text,
  uAltP,
  LogWind,
  LogCW,
  Tree,
  uTR4WStrings;

procedure ShowFMessages(VirtualKey: Byte);

const
  (* THE THREE BANKS, as the offset added to a key code (112..123) to reach its
    memory: F1..F12, CtrlF1..CtrlF12, AltF1..AltF12. *)
  FKEY_BANK_PLAIN = 0;
  FKEY_BANK_CTRL  = 12;
  FKEY_BANK_ALT   = 24;

(* WHICH BANK A FUNCTION KEY SENDS, for the modifiers held. Ctrl wins when both
  are held, because that is what GetRealVirtualKey has always sent; the labels,
  the right-click editor row and the send all ask this one rule (issue #3). *)
function BankForModifiers(const aCtrlDown, aAltDown: boolean): byte;

(* THE BANK FOR THE MODIFIERS THE KEYBOARD REPORTS, UNLESS THAT REPORT IS
  STALE: then the plain bank (review M11, issue #3). Pure, so it is pinned. *)
function EffectiveFunctionKeyBank(const aCtrlDown, aAltDown, aStale: boolean): byte;

(* The bank for the modifiers held NOW, asked of the keyboard -- what the labels,
  the editor row and EVERY send (a key, a click, a keypad memory) use.

  AFTER THE APPLICATION LOSES THE KEYBOARD, A HELD MODIFIER IS NOT BELIEVED until
  this program sees it pressed again (NoteFunctionKeyModifierPressed) or the
  keyboard reports none held. A key released in another program never reaches
  this one, and on Win32 GetKeyState is this thread's view, so after Alt-Tab it
  can still read Alt as held -- the labels were already put back to the plain
  bank then (uAppInputHooks.AppDeactivate), and the send now agrees with them.
  The cost, stated: a modifier held THROUGH the switch back is ignored until it
  is pressed again (on Windows a held Alt or Ctrl repeats its own key-down,
  which counts). Main thread only. *)
function LiveFunctionKeyBank: byte;

(* The application lost the keyboard: held modifiers are stale from now on. *)
procedure NoteFunctionKeyModifiersStale;

(* This program saw Ctrl or Alt pressed: the keyboard's report is fresh again. *)
procedure NoteFunctionKeyModifierPressed;

(* SHOW THIS BANK ON THE FUNCTION-KEY WINDOW, AND FOLLOW THE KEYBOARD UNTIL IT IS
  THE PLAIN ONE AGAIN (issue #3).

  The labels used to switch in the call and exchange fields' own OnKeyDown and
  switch back in their OnKeyUp, so with focus anywhere else -- the band map, the
  function-key window itself -- they never moved. The press is now seen by the
  application-wide key handler (uAppInputHooks), which every control reaches.
  The RELEASE has no application-wide event in the LCL (there is no key-up
  counterpart of AddOnKeyDownBeforeHandler), so while a Ctrl or Alt bank is up
  the window's own timer asks the keyboard and puts the plain bank back. At
  rest the timer is off.

  Redraws only when the bank changes: a held Ctrl auto-repeats its key-down. *)
procedure ShowFunctionKeyBank(const aBank: byte);

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
  ButtonsText                           : array[112..123] of Str40;

//  FKCloseButton                         : HWND;

implementation
uses
   uWindowTable,   { tr4w_WindowsArray, tWindowsExist -- moved out of VC/TF }
  Menus,          { TPopupMenu / TMenuItem -- the right-click menu }
  Controls,       { Mouse.CursorPos -- where to pop it }
  MainUnit,
  uFunctionKeysForm,   // the panels; this unit supplies what a key press MEANS
  uSettingsModel;   // Settings.Cw.IncludeFKeyNumber

(* FunctionKeysWindowDlgProc IS DELETED (2026-09-01).

   A hundred and fifty lines of WM_DRAWITEM owner-drawing, WM_COMMAND routing
   and hit-testing, for a window that has been an LCL form since 2026-08-24:
   OpenTR4WWindow tests tw_FUNCTIONKEYSWINDOW_INDEX first and builds
   uFunctionKeysForm, so the proc was unreachable from that day. The only thing
   that still named it was MainUnit's WndProcAdr assignment, written on every
   start-up and read by nothing.

   It was also the LAST window procedure in tr4w_WindowsArray. With it gone,
   OpenTR4WWindow's CreateDialogIndirectParam fallback had no id that could
   reach it, and that is deleted too -- so nothing in this program creates a
   tool window the Win32 way any more.

   In git history if the drawing is ever wanted as a reference;
   uFunctionKeysForm is what draws these keys now. *)

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

  // THE WINDOW KNOWS WHICH BANK IT SHOWS, so ShowFunctionKeyBank can ask it
  // rather than keep a copy beside it.
  if TR4WFunctionKeysForm <> nil then
     begin
     TR4WFunctionKeysForm.ShownBank := VirtualKey;
     end;

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
        (* One test, not two: the nil check went with the pointers. *)
        if CQCaptionMemory[TempMode, b] <> '' then
           begin
           s := CQCaptionMemory[TempMode, b]
           end
        else
           begin
           s := GetCQMemoryString(TempMode, b);
           end;
        end
     else
        begin
        (* One test, not two: the nil check went with the pointers. *)
        if EXCaptionMemory[TempMode, b] <> '' then
           begin
           s := EXCaptionMemory[TempMode, b]
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
     if Settings.Cw.IncludeFKeyNumber then
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

function BankForModifiers(const aCtrlDown, aAltDown: boolean): byte;
begin
   if aCtrlDown then
      begin
      Result := FKEY_BANK_CTRL;
      end
   else if aAltDown then
      begin
      Result := FKEY_BANK_ALT;
      end
   else
      begin
      Result := FKEY_BANK_PLAIN;
      end;
end;

function EffectiveFunctionKeyBank(const aCtrlDown, aAltDown, aStale: boolean): byte;
begin
   if aStale then
      begin
      Result := FKEY_BANK_PLAIN;
      end
   else
      begin
      Result := BankForModifiers(aCtrlDown, aAltDown);
      end;
end;

var
   (* Set when the application loses the keyboard, cleared by a modifier press
     this program sees or by the keyboard reporting none held. Main thread. *)
   GModifiersStale: boolean = False;

procedure NoteFunctionKeyModifiersStale;
begin
   GModifiersStale := True;
end;

procedure NoteFunctionKeyModifierPressed;
begin
   GModifiersStale := False;
end;

function LiveFunctionKeyBank: byte;
var
   ctrlDown, altDown: boolean;
begin
   // GetKeyState is LCLIntf's, which every widget set answers for its own
   // keyboard; the high bit (a negative SmallInt) means held.
   ctrlDown := GetKeyState(VK_CONTROL) < 0;
   altDown  := GetKeyState(VK_MENU) < 0;
   if (not ctrlDown) and (not altDown) then
      begin
      (* The keyboard has caught up: nothing held is nothing stale. *)
      GModifiersStale := False;
      end;
   Result := EffectiveFunctionKeyBank(ctrlDown, altDown, GModifiersStale);
end;

procedure ShowFunctionKeyBank(const aBank: byte);
begin
   if TR4WFunctionKeysForm = nil then
      begin
      Exit;
      end;

   if aBank <> TR4WFunctionKeysForm.ShownBank then
      begin
      ShowFMessages(aBank);
      end;

   TR4WFunctionKeysForm.WatchModifiers := (aBank <> FKEY_BANK_PLAIN);
end;

(* THE WINDOW'S TIMER, while a Ctrl or Alt bank is up: follow the keyboard. *)
procedure FollowLiveFunctionKeyBank;
begin
   ShowFunctionKeyBank(LiveFunctionKeyBank);
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
  // one.  Issue #1001.  The rule is BankForModifiers, the one the send uses:
  // this asked Alt first while the send asked Ctrl first, so with both held
  // the editor opened a different row from the one the key sends (issue #3).
  plus := LiveFunctionKeyBank;

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

(* THE RIGHT-CLICK MENU, and what it acts on.

  The menu was a raw HMENU: CreatePopupMenu, AppendMenuW, and TrackPopupMenu
  with TPM_RETURNCMD, which BLOCKS and returns the chosen command id. The code
  after it then did the work.

  A TPopupMenu cannot be used that way. PopUp is modal on Win32 but the LCL does
  not promise that everywhere, so anything that reads a result after PopUp
  returns is relying on a widgetset detail. The work moves into the item's
  OnClick instead, which is true on every widgetset -- and is what a menu item
  is for.

  WHICH KEY WAS CLICKED therefore has to survive the pop, hence GPopupRow. It is
  captured before the menu appears for the same reason the old code captured it:
  the operator releases Ctrl or Alt to reach the menu, so reading the modifier
  state afterwards gives the wrong bank (Issue #1001). *)
type
  TFKeyPopupHost = class(TObject)
     procedure EditClicked(Sender: TObject);
  end;

var
  GPopup:    TPopupMenu = nil;
  GPopupHost: TFKeyPopupHost = nil;
  GPopupRow: integer = -1;

procedure TFKeyPopupHost.EditClicked(Sender: TObject);
begin
  if GPopupRow < 0 then
     begin
     Exit;
     end;
  InitialAltPSelection := GPopupRow;    // captured before the modifier was released
  OpenListOfMessages;

  // Right-clicking the button + showing the menu (and the modal editor) leaves
  // focus off the Call window; put it back, as the left click does. (The
  // Ctrl/Alt bank switch no longer depends on that focus -- issue #3.)
  FrmSetFocus;
end;

procedure ShowFunctionKeyContextMenu(const aKey: integer);
var
  row                                   : integer;
  prefix                                : string;
  keyName                               : string;
  caption                               : string;
  p                                     : integer;
  pt                                    : TPoint;
begin
  // Issue #1007: ignore right-click while Alt or Ctrl is held. The window is
  // showing the Alt-F/Ctrl-F bank then, and popping the menu + the FrmSetFocus
  // that follows would flash the labels back to plain (WM_SETFOCUS ->
  // ShowFMessages(0)). Right-click edits the plain F-keys only; edit the
  // Alt-F/Ctrl-F messages via the Alt-P editor.
  if LiveFunctionKeyBank <> FKEY_BANK_PLAIN then
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

  if GPopup = nil then
     begin
     GPopupHost := TFKeyPopupHost.Create;
     GPopup := TPopupMenu.Create(nil);
     GPopup.Items.Add(NewItem('', 0, False, True, GPopupHost.EditClicked, 0, ''));
     end;

  // The caption names the key that was clicked, so it is rewritten every time.
  GPopup.Items[0].Caption := LclText(caption);
  GPopupRow := row;

  // NB: do NOT SetForegroundWindow here -- it fires the activate handler, which
  // calls ShowFMessages(0) and reverts the function-key window to the plain
  // bank while the menu is up (mismatching an "Edit Ctrl-Fn" label). The app is
  // already foreground on right-click, so the menu dismisses fine without it
  // (same as the band-map popup). Issue #1001.
  pt := Mouse.CursorPos;
  GPopup.PopUp(pt.X, pt.Y);
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
  uFunctionKeysForm.FunctionKeyBankTick           := @FollowLiveFunctionKeyBank;


(* The popup outlives any one right-click -- it is built once and re-captioned
  -- so it is freed here rather than after each PopUp. *)
finalization
  FreeAndNil(GPopup);
  FreeAndNil(GPopupHost);

end.
