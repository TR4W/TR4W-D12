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
unit uCAT;
{$IMPORTEDDATA OFF}
interface

uses
  SysUtils,
  TF,
  VC,
  uCFG,
  Windows,
  Messages,
  LogRadio,
  LogCW,
  CFGCMD,
  LogWind,
  LogK1EA,
  Tree,
  Classes,
  uK4Discovery,
  uFlexDiscovery,
  uIcomNetworkDiscovery,
  uIcomNetworkTypes;

procedure CloseCATAndKeyerForThisRadio;
function CATDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
procedure RestartPollingThread(CATWndHWND: HWND);
// Published for uRadioConfigApply: any code that writes [Radio] keys has to run
// this afterwards, or newly-created keys stay stranded at the end of the
// section instead of beside their radio's block.  It was implementation-only
// while this dialog was the sole writer; it no longer is.
procedure GroupRadioIniKeys;

// Published for the Preferences window.  Broadcasts for K4, FlexRadio or Icom
// network radios and appends the IP addresses found.  BLOCKS for the discovery
// timeout (about 3 s), so callers with a UI must run it off the main thread --
// see uPrefsForm.HandleDiscover.
procedure DiscoverNetworkRadios(rt: InterfacedRadioType; Found: TStringList);

// Does this radio's NETWORK link require a user name and password?
//
// Published so the Preferences window and this dialog cannot disagree about it
// -- the membership used to be a set literal buried in a nested procedure, and
// a second copy elsewhere would have drifted the first time a model was added.
//
// The Elecraft K4, FlexRadio and TCI have no concept of network credentials
// today (NY4I); it is the Icom LAN radios, plus the TS-890 whose LAN link wants
// an Admin ID.
//
// NOTE: this is still a MODEL LIST, which is the shape this codebase has been
// moving away from.  The durable form is a capability the radio declares, the
// way rcCWByCAT works -- worth doing when something else touches these drivers.
// Naming it here at least means there is one list to convert rather than two.
function RadioUsesNetworkCredentials(rt: InterfacedRadioType): boolean;

var
  CATWTR                                : RadioPtr {= @Radio1};
  TempKeyerPortType                     : PortType;

implementation

uses
  uRadioPolling,
  uRadioFactory,   // Issue #1028 -- network metadata (port / is-network / discoverable)
  uRadioRegistry,  // string-id factory radios in the drop-down
  ComPortEnumerator,
  MainUnit;

var
  // String-id factory radios (no enum member) offered in the radio-type combo.
  // Their combo rows carry RADIOITEM_FACTORYID_FLAG or <index into this list>
  // as item data; the commit in RestartPollingThread maps the index back to
  // the registry id.  Rebuilt on each dialog populate.
  gComboFactoryIds: TStringList = nil;

  // Serial-port arrival/removal notification handle for the open radio dialog.
  // nil when not registered.  Released in WM_DESTROY.
  gPortNotify: Pointer = nil;

// Defined below RestartPollingThread; called from CATDlgProc's Apply/OK
// handlers, which appear earlier in the file.
function ConfirmPortConflicts(hwnddlg: HWND): Boolean; forward;

// ---------------------------------------------------------------------------
// Port combos (122 = CAT, 123 = keyer)
//
// These used to list SERIAL 1..N unconditionally, so a row's INDEX happened to
// equal its PortType ordinal and the code read the selection as a raw index.
// They are now FILTERED -- only the ports Windows actually reports, plus the
// configured one when it is unplugged -- so that coincidence is gone.  Every row
// therefore carries its PortType in the combo's ITEM DATA, and every read goes
// through ComboSelectedPort.  Do not reintroduce index arithmetic here.
//
// This also fixes a long-standing off-by-one: combo 123 omits TCP/IP, so its
// PARALLEL rows never sat at Ord(Parallel1..3) and SETCURSEL by ordinal selected
// the wrong one.  Item data removes the whole class of bug.
// ---------------------------------------------------------------------------

const
   // Item data = the PortType ordinal, OR'd with this flag when the port is not
   // currently present.  High(PortType) is well under $100, so the flag cannot
   // collide with a port value.  The flag drives ONLY the grey painting in
   // DrawPortComboItem -- the row stays fully selectable.
   PORTITEM_ABSENT = $1000;
   PORTITEM_MASK   = $0FFF;

procedure ComboAddPort(hwnddlg: HWND; ctl: integer; const caption: AnsiString;
   port: PortType; absent: Boolean = False);
var
   idx: integer;
   data: NativeInt;
begin
   idx := SendDlgItemMessageA(hwnddlg, ctl, CB_ADDSTRING, 0,
                              LPARAM(PAnsiChar(caption)));
   if idx >= 0 then
      begin
      data := Ord(port);
      if absent then
         begin
         data := data or PORTITEM_ABSENT;
         end;
      SendDlgItemMessageA(hwnddlg, ctl, CB_SETITEMDATA, idx, LPARAM(data));
      end;
end;

// Paint one row of an owner-draw port combo.  The ONLY difference from the
// default look is that a port Windows is not currently reporting is drawn in the
// system's grey-text colour -- matching how Windows' own Sound applet shows a
// disconnected device: faded, but still selectable.  Selection highlight and
// focus rectangle are drawn normally so the control behaves like any other combo.
procedure DrawPortComboItem(const dis: TDrawItemStruct);
var
   buf: array[0..511] of AnsiChar;
   len: integer;
   isAbsent: Boolean;
   isSelected: Boolean;
   textColour: COLORREF;
   backColour: COLORREF;
   r: TRect;
begin
   if integer(dis.itemID) < 0 then
      begin
      // Empty combo -- just paint the focus rectangle if asked.
      if (dis.itemAction and ODA_FOCUS) <> 0 then
         begin
         Windows.DrawFocusRect(dis.hDC, dis.rcItem);
         end;
      Exit;
      end;

   len := SendMessageA(dis.hwndItem, CB_GETLBTEXT, dis.itemID, LPARAM(@buf[0]));
   if len < 0 then
      begin
      len := 0;
      end;
   buf[len] := #0;

   isAbsent := (dis.itemData and PORTITEM_ABSENT) <> 0;
   isSelected := (dis.itemState and ODS_SELECTED) <> 0;

   if isSelected then
      begin
      backColour := GetSysColor(COLOR_HIGHLIGHT);
      textColour := GetSysColor(COLOR_HIGHLIGHTTEXT);
      end
   else
      begin
      backColour := GetSysColor(COLOR_WINDOW);
      textColour := GetSysColor(COLOR_WINDOWTEXT);
      end;
   // Grey ONLY when not highlighted.  Grey text on the system highlight blue is
   // barely legible -- the very low-contrast pairing the grey was meant to avoid.
   // Nothing is lost: the row still carries its "(not connected)" text in both
   // states, so the meaning never depended on the colour, and a highlighted row
   // is the one the operator is already looking at.
   if isAbsent and not isSelected then
      begin
      textColour := GetSysColor(COLOR_GRAYTEXT);
      end;

   Windows.SetBkColor(dis.hDC, backColour);
   Windows.SetTextColor(dis.hDC, textColour);
   r := dis.rcItem;
   Windows.ExtTextOutA(dis.hDC, r.Left + 2,
      r.Top + ((r.Bottom - r.Top) - 14) div 2,
      ETO_OPAQUE, @r, @buf[0], len, nil);

   if (dis.itemState and ODS_FOCUS) <> 0 then
      begin
      Windows.DrawFocusRect(dis.hDC, dis.rcItem);
      end;
end;

// Stamp the DIALOG's own font (WM_GETFONT -- what the dialog manager gave every
// template control) on a runtime-created control.  The generic creation helpers
// (CreateStatic/CreateEdit/CreateButton/tCreate*Window) stamp MSSansSerifFont,
// which tr4w.dpr creates at 15px -- LARGER than the ~13px derived from the
// template's 'FONT 8, MS Sans Serif' -- so runtime controls sat subtly oversized
// next to template ones, and a long one-row caption could wrap and clip
// (the DATA/PARITY/STOP label bench finding).  Call this after every runtime
// control creation in this dialog.
procedure ApplyDialogFont(hwnddlg: HWND; ctl: integer);
var
   f: LRESULT;
   w: HWND;
begin
   f := Windows.SendMessage(hwnddlg, WM_GETFONT, 0, 0);
   w := GetDlgItem(hwnddlg, ctl);
   if (f <> 0) and (w <> 0) then
      begin
      Windows.SendMessage(w, WM_SETFONT, WPARAM(f), 1);
      end;
end;

// Replace a resource-defined combo with an owner-draw one of the same id,
// position and size.  CBS_OWNERDRAWFIXED can only be set at CREATION, and these
// combos come from the binary .RES, so the control has to be rebuilt.
// CBS_HASSTRINGS is essential: it keeps CB_ADDSTRING/CB_GETLBTEXT working, which
// the width measuring and the rest of the dialog rely on.
procedure MakePortComboOwnerDraw(hwnddlg: HWND; ctl: integer);
var
   old: HWND;
   r: TRect;
   pt: TPoint;
   w: integer;
begin
   old := GetDlgItem(hwnddlg, ctl);
   if old = 0 then
      begin
      Exit;
      end;
   Windows.GetWindowRect(old, r);
   pt.x := r.Left;
   pt.y := r.Top;
   Windows.ScreenToClient(hwnddlg, pt);
   w := r.Right - r.Left;
   Windows.DestroyWindow(old);
   // tCreateComboBoxWindow supplies the dropped height (340) and the dialog font.
   tCreateComboBoxWindow(
      WS_CHILD or WS_VISIBLE or WS_TABSTOP or WS_VSCROLL or
      CBS_DROPDOWNLIST or CBS_OWNERDRAWFIXED or CBS_HASSTRINGS,
      pt.x, pt.y, w, hwnddlg, HMENU(ctl));
end;

// The port a combo is showing, from its item data.  NoPort when nothing is
// selected, which is the safe reading of "no answer".
function ComboSelectedPort(hwnddlg: HWND; ctl: integer): PortType;
var
   idx: integer;
   data: LRESULT;
begin
   Result := NoPort;
   idx := tCB_GETCURSEL(hwnddlg, ctl);
   if idx < 0 then
      begin
      Exit;
      end;
   data := SendDlgItemMessageA(hwnddlg, ctl, CB_GETITEMDATA, idx, 0);
   data := data and PORTITEM_MASK;   // strip PORTITEM_ABSENT
   if (data >= 0) and (data <= Ord(High(PortType))) then
      begin
      Result := PortType(data);
      end;
end;

procedure ComboSelectPort(hwnddlg: HWND; ctl: integer; port: PortType);
var
   count: integer;
   i: integer;
begin
   count := SendDlgItemMessageA(hwnddlg, ctl, CB_GETCOUNT, 0, 0);
   for i := 0 to count - 1 do
      begin
      if (SendDlgItemMessageA(hwnddlg, ctl, CB_GETITEMDATA, i, 0) and PORTITEM_MASK)
         = Ord(port) then
         begin
         tCB_SETCURSEL(hwnddlg, ctl, i);
         Exit;
         end;
      end;
   tCB_SETCURSEL(hwnddlg, ctl, 0);   // not offered -- fall back to NONE
end;

// Widen the DROP-DOWN LIST to fit its longest entry.  A Win32 combo sizes its
// list to the CONTROL's width, not its content, so the friendly names added here
// ('SERIAL 18 - Icom IC-7100') get clipped to 'SERIAL 18 - Icon IC...' -- which
// truncates exactly the text that makes the list worth having.  Measured in the
// combo's own font rather than guessed from character counts.
procedure ComboFitDroppedWidth(hwnddlg: HWND; ctl: integer);
var
   ctlWnd: HWND;
   dc: HDC;
   comboFont: HFONT;
   oldFont: HFONT;
   count: integer;
   i: integer;
   len: integer;
   widest: integer;
   buf: array[0..511] of AnsiChar;
   extent: TSize;
begin
   ctlWnd := GetDlgItem(hwnddlg, ctl);
   if ctlWnd = 0 then
      begin
      Exit;
      end;
   dc := GetDC(ctlWnd);
   if dc = 0 then
      begin
      Exit;
      end;
   try
      comboFont := HFONT(SendMessage(ctlWnd, WM_GETFONT, 0, 0));
      oldFont := 0;
      if comboFont <> 0 then
         begin
         oldFont := SelectObject(dc, comboFont);
         end;
      widest := 0;
      count := SendDlgItemMessageA(hwnddlg, ctl, CB_GETCOUNT, 0, 0);
      for i := 0 to count - 1 do
         begin
         len := SendDlgItemMessageA(hwnddlg, ctl, CB_GETLBTEXT, i, LPARAM(@buf[0]));
         if len > 0 then
            begin
            if GetTextExtentPoint32A(dc, @buf[0], len, extent) then
               begin
               if extent.cx > widest then
                  begin
                  widest := extent.cx;
                  end;
               end;
            end;
         end;
      if oldFont <> 0 then
         begin
         SelectObject(dc, oldFont);
         end;
   finally
      ReleaseDC(ctlWnd, dc);
   end;
   if widest > 0 then
      begin
      // Room for the scroll bar plus a little padding, so the text is not flush
      // against the frame.
      SendDlgItemMessageA(hwnddlg, ctl, CB_SETDROPPEDWIDTH,
         widest + GetSystemMetrics(SM_CXVSCROLL) + 8, 0);
      end;
end;

// ---------------------------------------------------------------------------
// Radio-type combo (121) -- registry-built, DISPLAY names, model in ITEM DATA.
//
// Until 2026-07-30 this combo showed raw enum names (IC7300MK2) in enum order,
// because the commit path wrote 'RADIO n TYPE = <combo text>' and the config
// parser matches enum names.  It is now built from the radio registry: friendly
// display names ('Icom IC-7300MK2'), sorted, with NONE pinned first -- and each
// row carries its identity in the combo ITEM DATA (the port combos' pattern:
// never index arithmetic, never display text as data).  The commit path maps
// item data back to the enum name, so the INI grammar is unchanged.
//
// Item data encoding: Ord(model) for an enum radio; RADIOITEM_FACTORYID_FLAG
// or <index into gComboFactoryIds> for a string-id factory radio (no enum
// member; identified by FACTORY ID instead of TYPE).
// ---------------------------------------------------------------------------
const
   RADIOITEM_FACTORYID_FLAG = $10000;   // far above Ord(High(InterfacedRadioType))
   RADIOITEM_MASK           = $FFFF;

procedure ComboAddRadio(hwnddlg: HWND; const caption: AnsiString; data: NativeInt);
var
   idx: integer;
begin
   idx := SendDlgItemMessageA(hwnddlg, 121, CB_ADDSTRING, 0,
                              LPARAM(PAnsiChar(caption)));
   if idx >= 0 then
      begin
      SendDlgItemMessageA(hwnddlg, 121, CB_SETITEMDATA, idx, LPARAM(data));
      end;
end;

function ComboSelectedRadioData(hwnddlg: HWND): NativeInt;
var
   idx: integer;
begin
   Result := -1;
   idx := tCB_GETCURSEL(hwnddlg, 121);
   if idx < 0 then
      begin
      Exit;
      end;
   Result := SendDlgItemMessageA(hwnddlg, 121, CB_GETITEMDATA, idx, 0);
end;

// The selected ENUM radio.  NoInterfacedRadio when nothing is selected, when
// NONE is selected, or when the selection is a string-id factory radio -- the
// safe reading in every consumer (not discoverable, no serial defaults, not
// HamLib-only).
function ComboSelectedRadioModel(hwnddlg: HWND): InterfacedRadioType;
var
   data: NativeInt;
begin
   Result := NoInterfacedRadio;
   data := ComboSelectedRadioData(hwnddlg);
   if (data >= 0) and (data <= Ord(High(InterfacedRadioType))) then
      begin
      Result := InterfacedRadioType(data);
      end;
end;

// Index into gComboFactoryIds when the selection is a string-id factory radio;
// -1 otherwise.
function ComboSelectedFactoryIdIndex(hwnddlg: HWND): integer;
var
   data: NativeInt;
begin
   Result := -1;
   data := ComboSelectedRadioData(hwnddlg);
   if (data >= 0) and ((data and RADIOITEM_FACTORYID_FLAG) <> 0) then
      begin
      Result := data and RADIOITEM_MASK;
      end;
end;

// Select the row whose item data equals `data`; falls back to NONE (index 0)
// when no row matches, so the combo never sits empty.
procedure ComboSelectRadioByData(hwnddlg: HWND; data: NativeInt);
var
   count, i: integer;
begin
   count := SendDlgItemMessageA(hwnddlg, 121, CB_GETCOUNT, 0, 0);
   for i := 0 to count - 1 do
      begin
      if SendDlgItemMessageA(hwnddlg, 121, CB_GETITEMDATA, i, 0) = LRESULT(data) then
         begin
         tCB_SETCURSEL(hwnddlg, 121, i);
         Exit;
         end;
      end;
   tCB_SETCURSEL(hwnddlg, 121, 0);
end;

// Build the radio list from the REGISTRY: every registered enum radio plus the
// string-id factory radios, sorted by display name, NONE pinned first.
procedure PopulateRadioTypeCombo(hwnddlg: HWND);
var
   names: TStringList;
   m: InterfacedRadioType;
   i, idx: integer;
   fid: string;
begin
   SendDlgItemMessageA(hwnddlg, 121, CB_RESETCONTENT, 0, 0);
   if gComboFactoryIds = nil then
      begin
      gComboFactoryIds := TStringList.Create;
      end;
   gComboFactoryIds.Clear;
   names := TStringList.Create;
   try
      for m := Low(InterfacedRadioType) to High(InterfacedRadioType) do
         begin
         if (m <> NoInterfacedRadio) and uRadioRegistry.IsRegistered(m) then
            begin
            names.AddObject(uRadioRegistry.DisplayName(m), TObject(Ord(m)));
            end;
         end;
      for fid in uRadioRegistry.RegisteredIds do
         begin
         if uRadioRegistry.ModelForId(fid) = NoInterfacedRadio then
            begin
            idx := gComboFactoryIds.Add(fid);
            names.AddObject(uRadioRegistry.DisplayNameId(fid),
                            TObject(RADIOITEM_FACTORYID_FLAG or idx));
            end;
         end;
      names.Sort;   // case-insensitive; groups manufacturers naturally
      ComboAddRadio(hwnddlg, AnsiString(InterfacedRadioTypeSA[NoInterfacedRadio]),
                    Ord(NoInterfacedRadio));
      for i := 0 to names.Count - 1 do
         begin
         ComboAddRadio(hwnddlg, AnsiString(names[i]), NativeInt(names.Objects[i]));
         end;
   finally
      names.Free;
   end;
   // The display names are longer than the raw enum names the drop-list was
   // sized for -- fit the LIST (the control keeps its dialog width).
   ComboFitDroppedWidth(hwnddlg, 121);
end;

// Widen the DIALOG ITSELF so the port combos can show a friendly name in their
// CLOSED state, not just in the drop-down list.
//
// Done at runtime rather than in res\Tr4w.rc because the eleven per-language
// .RES files are pre-built binaries checked into the repo -- nothing in the build
// compiles Tr4w.rc, and it carries language conditionals -- so a resource edit
// would mean hand-rebuilding eleven resources for languages that cannot be tested
// here.  Sizing at runtime also adapts to the longest name on THIS machine, which
// a fixed resource width cannot.
//
// Grows the dialog, the two group boxes, every combo and the name edit by one
// delta, and slides the button row across so it stays at the right edge.
procedure WidenDialogForPortNames(hwnddlg: HWND);
const
   GROW_CONTROLS: array[0..10] of integer =
      (90, 91, 121, 122, 123, 124, 125, 126, 127, 128, 129);
   SLIDE_CONTROLS: array[0..3] of integer = (116, 117, 118, 119);
   MAX_GROWTH = 320;   // sanity bound; a pathological device name must not
                       // produce a dialog wider than the screen
var
   ctlWnd: HWND;
   dc: HDC;
   comboFont: HFONT;
   oldFont: HFONT;
   i: integer;
   c: integer;
   len: integer;
   widest: integer;
   needed: integer;
   delta: integer;
   buf: array[0..511] of AnsiChar;
   extent: TSize;
   r: TRect;
   dlgRect: TRect;
begin
   ctlWnd := GetDlgItem(hwnddlg, 122);
   if ctlWnd = 0 then
      begin
      Exit;
      end;

   // Widest caption across BOTH port combos, measured in the combo's own font.
   widest := 0;
   dc := GetDC(ctlWnd);
   if dc = 0 then
      begin
      Exit;
      end;
   try
      comboFont := HFONT(SendMessage(ctlWnd, WM_GETFONT, 0, 0));
      oldFont := 0;
      if comboFont <> 0 then
         begin
         oldFont := SelectObject(dc, comboFont);
         end;
      for c := 122 to 123 do
         begin
         for i := 0 to SendDlgItemMessageA(hwnddlg, c, CB_GETCOUNT, 0, 0) - 1 do
            begin
            len := SendDlgItemMessageA(hwnddlg, c, CB_GETLBTEXT, i, LPARAM(@buf[0]));
            if len > 0 then
               begin
               if GetTextExtentPoint32A(dc, @buf[0], len, extent) then
                  begin
                  if extent.cx > widest then
                     begin
                     widest := extent.cx;
                     end;
                  end;
               end;
            end;
         end;
      if oldFont <> 0 then
         begin
         SelectObject(dc, oldFont);
         end;
   finally
      ReleaseDC(ctlWnd, dc);
   end;

   if widest = 0 then
      begin
      Exit;
      end;

   // Room for the drop-down arrow and the frame.
   needed := widest + GetSystemMetrics(SM_CXVSCROLL) + 12;

   Windows.GetWindowRect(ctlWnd, r);
   delta := needed - (r.Right - r.Left);
   if delta <= 0 then
      begin
      Exit;      // already wide enough -- leave the dialog alone
      end;
   if delta > MAX_GROWTH then
      begin
      delta := MAX_GROWTH;
      end;

   Windows.GetWindowRect(hwnddlg, dlgRect);
   Windows.SetWindowPos(hwnddlg, 0, 0, 0,
      (dlgRect.Right - dlgRect.Left) + delta, dlgRect.Bottom - dlgRect.Top,
      SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);

   for i := Low(GROW_CONTROLS) to High(GROW_CONTROLS) do
      begin
      ctlWnd := GetDlgItem(hwnddlg, GROW_CONTROLS[i]);
      if ctlWnd <> 0 then
         begin
         Windows.GetWindowRect(ctlWnd, r);
         Windows.MapWindowPoints(0, hwnddlg, r, 2);
         Windows.SetWindowPos(ctlWnd, 0, 0, 0,
            (r.Right - r.Left) + delta, r.Bottom - r.Top,
            SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
         end;
      end;

   for i := Low(SLIDE_CONTROLS) to High(SLIDE_CONTROLS) do
      begin
      ctlWnd := GetDlgItem(hwnddlg, SLIDE_CONTROLS[i]);
      if ctlWnd <> 0 then
         begin
         Windows.GetWindowRect(ctlWnd, r);
         Windows.MapWindowPoints(0, hwnddlg, r, 2);
         Windows.SetWindowPos(ctlWnd, 0, r.Left + delta, r.Top, 0, 0,
            SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
         end;
      end;
end;

// Fill a port combo: NONE, the serial ports Windows reports right now, the
// configured port when it is NOT present, then the non-serial options.
//
// The configured-but-absent entry matters: someone who unplugs a USB adapter
// should not have their saved choice silently vanish from the dialog, which
// would look like TR4W forgetting the setting (docs\COMPort_Persistence.md).
// It is labelled so the list never claims a missing device is available.
procedure PopulatePortCombo(hwnddlg: HWND; ctl: integer; configured: PortType); forward;

// Rebuild a port combo in place, keeping the current selection.  Used by the
// drop-down refresh and by the device-arrival/removal handler.
//
// SKIPS a combo whose list is currently DROPPED.  Repopulating under an open list
// would yank it out from under the mouse -- the thing NY4I explicitly did not
// want.  Nothing is lost: CBN_DROPDOWN rebuilds the list every time it opens, so
// a change that arrives while the list is down is picked up the next time it is.
procedure RefreshPortCombo(hwnddlg: HWND; ctl: integer);
var
   current: PortType;
begin
   if SendDlgItemMessageA(hwnddlg, ctl, CB_GETDROPPEDSTATE, 0, 0) <> 0 then
      begin
      Exit;
      end;
   current := ComboSelectedPort(hwnddlg, ctl);
   PopulatePortCombo(hwnddlg, ctl, current);
   ComboSelectPort(hwnddlg, ctl, current);
   ComboFitDroppedWidth(hwnddlg, ctl);
end;

procedure PopulatePortCombo(hwnddlg: HWND; ctl: integer; configured: PortType);
var
   ports: TComPortEnumerator;
   i: integer;
   info: TComPortInfo;
   listed: set of Byte;          // port numbers added to the combo
   present: set of Byte;         // port numbers Windows is reporting
   friendly: array[1..MAX_SERIAL_PORT] of string;
   caption: AnsiString;
begin
   SendDlgItemMessageA(hwnddlg, ctl, CB_RESETCONTENT, 0, 0);
   present := [];
   ComboAddPort(hwnddlg, ctl, 'NONE', NoPort);
   listed := [];

   // Describe[n] is the friendly name of the port with that number, when present.
   for i := Low(friendly) to High(friendly) do
      begin
      friendly[i] := '';
      end;

   ports := TComPortEnumerator.Create;
   try
      for i := 0 to ports.Count - 1 do
         begin
         info := ports.Ports[i];
         if not info.Addressable then
            begin
            // Present, but outside PortType's range.  Logged rather than listed:
            // offering a row that cannot be stored would be worse than omitting
            // it, and the log answers "why isn't my COM port in the list?".
            logger.Warn('[PopulatePortCombo] %s is present but above COM%d, which TR4W cannot address',
                        [info.PortName, MAX_SERIAL_PORT]);
            Continue;
            end;
         // friendly[] is filled for every port Windows KNOWS -- including
         // unplugged ones -- so an absent port can still say which radio it was.
         friendly[info.PortNumber] := info.Describe;
         if info.Present then
            begin
            Include(present, Byte(info.PortNumber));
            end;
         end;
   finally
      ports.Free;
   end;

   if tShowAllSerialPorts then
      begin
      // SHOW ALL SERIAL PORTS = TRUE.  Escape hatch for ports that exist but do
      // not enumerate: com0com pairs, Bluetooth SPP that only appears once the
      // device connects, or setting a station up before the hardware is plugged
      // in.  Present ports still get their friendly name so the list stays
      // useful; the rest are bare so it is obvious which is which.
      for i := 1 to MAX_SERIAL_PORT do
         begin
         caption := AnsiString('SERIAL ' + IntToStr(i));
         if friendly[i] <> '' then
            begin
            // Named whether present or not -- an unplugged adapter keeps its
            // registry entry, so we can still say WHICH radio was on that port.
            caption := caption + AnsiString(' - ' + friendly[i]);
            end;
         if not (Byte(i) in present) then
            begin
            // Marked in TEXT rather than greyed.  Greying an item needs an
            // owner-draw combo (CBS_OWNERDRAWFIXED, set at CREATION -- these come
            // from the binary .RES), and grey conventionally reads as "cannot be
            // selected" -- which is the opposite of what Show All is for, since
            // choosing a port Windows is not reporting IS the whole point.
            caption := caption + AnsiString(' ' + TC_PORT_NOT_CONNECTED);
            end;
         // absent -> painted grey by DrawPortComboItem, still selectable.
         ComboAddPort(hwnddlg, ctl, caption, PortType(i), not (Byte(i) in present));
         Include(listed, Byte(i));
         end;
      end
   else
      begin
      for i := 1 to MAX_SERIAL_PORT do
         begin
         if Byte(i) in present then
            begin
            caption := AnsiString('SERIAL ' + IntToStr(i) + ' - ' + friendly[i]);
            ComboAddPort(hwnddlg, ctl, caption, PortType(i));   // Serial1 is ordinal 1
            Include(listed, Byte(i));
            end;
         end;
      end;

   if (configured in SerialPorts) and not (Byte(Ord(configured)) in listed) then
      begin
      // TC_PORT_NOT_CONNECTED, not a literal: this is new user-visible text and
      // TR4W localises UI strings (src\lang\tr4w_consts_<LANG>.pas).
      // NOTE the 'SERIAL n' part stays English on purpose -- it mirrors PortTypeSA,
      // which is what the operator sees in tr4w.ini.  Localising the whole caption
      // is now POSSIBLE for the first time (the commit path takes the canonical
      // name from item data rather than the displayed text), but it would divorce
      // the dialog from the config file, so it is a deliberate non-change.
      caption := AnsiString('SERIAL ' + IntToStr(Ord(configured)));
      if (Ord(configured) <= MAX_SERIAL_PORT) and (friendly[Ord(configured)] <> '') then
         begin
         caption := caption + AnsiString(' - ' + friendly[Ord(configured)]);
         end;
      caption := caption + AnsiString(' ' + TC_PORT_NOT_CONNECTED);
      ComboAddPort(hwnddlg, ctl, caption, configured, True);
      end;

   if ctl = 122 then
      begin
      ComboAddPort(hwnddlg, ctl, 'TCP/IP', Network);
      end
   else
      begin
      ComboAddPort(hwnddlg, ctl, 'PARALLEL 1', Parallel1);
      ComboAddPort(hwnddlg, ctl, 'PARALLEL 2', Parallel2);
      ComboAddPort(hwnddlg, ctl, 'PARALLEL 3', Parallel3);
      end;

   ComboFitDroppedWidth(hwnddlg, ctl);
end;

// Issue #968 / #1028 -- the default network port is a property of the radio
// model, owned by the radio registry (single source of truth, keyed by
// InterfacedRadioType).  Returns 0 for a radio that has no network port (serial-only).
function DefaultNetworkPortForRadio(rt: InterfacedRadioType): Integer;
begin
   Result := TRadioFactory.DefaultNetworkPort(rt);
end;

// Issue #1028 -- True if `port` is the default network port of SOME network
// radio model.  Lets us tell a stale leftover default (e.g. 50001 from a
// previously-selected Icom) apart from a custom port the operator deliberately
// typed.
function IsSomeModelDefaultPort(port: Integer): Boolean;
var
   rt: InterfacedRadioType;
begin
   Result := False;
   if port = 0 then
      begin
      Exit;
      end;
   for rt := Low(InterfacedRadioType) to High(InterfacedRadioType) do
      begin
      if DefaultNetworkPortForRadio(rt) = port then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

// Issue #968 / #1028 -- when the dialog is showing a network radio (control-port
// combo 122 = index 21), set the TCP-port edit (131) to the selected model's
// default port when the field is EMPTY or still holds a DIFFERENT model's
// default (a stale leftover from the previous radio type -- e.g. 50001 from an
// Icom when switching to a K4, which should become 9200).  Never clobbers a
// genuinely custom (non-default) port the operator typed.
procedure ApplyDefaultNetworkPort(hwnddlg: HWND);
var
   typeIdx : Integer;
   port    : UINT;
   def     : Integer;
   ok      : BOOL;
begin
   // Read the PORT, not a combo index: the list is filtered, so index means
   // nothing.  (This was a hard-coded 21 until the port ceiling moved Network to
   // ordinal 65 and turned it into "SERIAL 21".)
   if ComboSelectedPort(hwnddlg, 122) <> Network then
      begin
      Exit;
      end;

   // Selection identity comes from ITEM DATA, never the row index -- the list
   // is registry-built and sorted, so index means nothing (same rule as the
   // port combos).
   typeIdx := ComboSelectedFactoryIdIndex(hwnddlg);
   if (typeIdx >= 0) and Assigned(gComboFactoryIds) and
      (typeIdx < gComboFactoryIds.Count) then
      begin
      def := uRadioRegistry.RegisteredNetworkPortId(gComboFactoryIds[typeIdx]);
      end
   else
      begin
      // No selection / NONE resolves to NoInterfacedRadio -> port 0 -> Exit.
      def := DefaultNetworkPortForRadio(ComboSelectedRadioModel(hwnddlg));
      end;
   if def = 0 then                              // not a network radio -> no default
      begin
      Exit;
      end;

   port := Windows.GetDlgItemInt(hwnddlg, 131, ok, False);
   // Empty, or a stale default from a different model -> apply this model's
   // default.  A non-default custom port (not any model's default) is kept.
   if (port = 0) or (IsSomeModelDefaultPort(port) and (Integer(port) <> def)) then
      begin
      Windows.SetDlgItemInt(hwnddlg, 131, def, False);
      end;
end;

// Issue #853 -- run the right discovery engine for the radio type and copy the
// discovered IP addresses into Found.  Keeps the per-engine record types
// (PK4DiscoveredRadio vs PDiscoveredRadio) out of the dialog flow.  The caller
// has already confirmed rt is discoverable (K4 or an Icom network model).
// Index of a baud rate in the dialog's baud combo (populated from
// CAT_BAUDRATE_ARRAY at uCAT:1026).  The registry states a real baud rate --
// 4800, 19200 -- while the combo wants its position, so this converts.  An
// unknown rate falls back to 4800's slot rather than leaving the combo blank.
function BaudRateComboIndex(baud: Integer): Integer;
var
   i: Integer;
begin
   Result := 2;   // CAT_BAUDRATE_ARRAY[2] = 4800
   for i := Low(CAT_BAUDRATE_ARRAY) to High(CAT_BAUDRATE_ARRAY) do
      begin
      if CAT_BAUDRATE_ARRAY[i] = baud then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

// ---------------------------------------------------------------------------
// DATA/PARITY/STOP row (label 151, combo 152) -- created at RUNTIME, like the
// credential rows: the per-language dialog templates are sourceless binary
// .res files, so adding a control to the TEMPLATE would mean hand-editing
// eleven of them.  A runtime row covers every language; only the label caption
// (TC_SERIAL_FORMAT_LABEL) is per-language.
// ---------------------------------------------------------------------------
const
   SERIALFMT_LABEL_ID = 151;
   SERIALFMT_COMBO_ID = 152;

   // Every frame the dialog offers: data bits 7/8, parity N/O/E, stop bits 1/2.
   SerialFormatChoices: array[0..11] of PAnsiChar =
      ('8N1', '8N2', '8E1', '8E2', '8O1', '8O2',
       '7N1', '7N2', '7E1', '7E2', '7O1', '7O2');

// The frame string the combo should show for a model: its registered defaults,
// or 8N2 -- the long-standing program default -- when the registry does not
// know the model (HamLib-only radios, string-id radios).
function SerialFormatDefaultFor(model: InterfacedRadioType): string;
var
   sp: uRadioRegistry.TSerialParams;
begin
   Result := '8N2';
   if uRadioRegistry.IsRegistered(model) then
      begin
      sp := uRadioRegistry.SerialParamsFor(model);
      if uRadioRegistry.SerialFormatToString(sp.dataBits, sp.parity, sp.stopBits) <> '' then
         begin
         Result := uRadioRegistry.SerialFormatToString(sp.dataBits, sp.parity, sp.stopBits);
         end;
      end;
end;

procedure SelectSerialFormat(hwnddlg: HWND; const fmt: string);
begin
   // The choices are all exactly 3 characters, so CB_SELECTSTRING's prefix
   // match is an exact match here.
   SendDlgItemMessageA(hwnddlg, SERIALFMT_COMBO_ID, CB_SELECTSTRING,
      WPARAM(-1), LPARAM(PAnsiChar(AnsiString(fmt))));
end;

// Push every control below the BAUD RATE row down by one row pitch, grow the
// CAT groupbox and the dialog to match, then create the DATA/PARITY/STOP label
// and combo one pitch below BAUD RATE.  ALL geometry is measured from existing
// controls -- the eleven per-language dialogs are binary clones whose absolute
// layout must not be assumed (the checked-in Tr4w.rc is stale: the shipped
// dialogs contain controls it does not show).
procedure AddSerialFormatRow(hwnddlg: HWND);
var
   r104, r105, r108, r128, rGroup, rDlg, rChild: TRect;
   pt: TPoint;
   rowH, threshold: integer;
   labelX, labelY, labelW, labelH: integer;
   comboX, comboY, comboW: integer;
   child: HWND;
   i: integer;
   caption: string;
begin
   // Row pitch measured from the CAT RTS / CAT DTR rows.
   GetWindowRect(GetDlgItem(hwnddlg, 104), r104);
   GetWindowRect(GetDlgItem(hwnddlg, 105), r105);
   rowH := r105.Top - r104.Top;
   if rowH <= 0 then
      begin
      // A template without the expected rows -- leave the layout alone rather
      // than wreck it; the radio still works, only the combo is missing.
      Exit;
      end;

   GetWindowRect(GetDlgItem(hwnddlg, 108), r108);
   pt.x := r108.Left;
   pt.y := r108.Top;
   Windows.ScreenToClient(hwnddlg, pt);
   labelX := pt.x;
   labelY := pt.y + rowH;
   labelW := r108.Right - r108.Left;
   labelH := r108.Bottom - r108.Top;

   GetWindowRect(GetDlgItem(hwnddlg, 128), r128);
   pt.x := r128.Left;
   pt.y := r128.Top;
   Windows.ScreenToClient(hwnddlg, pt);
   comboX := pt.x;
   comboY := pt.y + rowH;
   comboW := r128.Right - r128.Left;
   threshold := pt.y + (rowH div 2);   // anything starting below the BAUD row

   // Generic child walk so per-language extras shift too.
   child := GetWindow(hwnddlg, GW_CHILD);
   while child <> 0 do
      begin
      GetWindowRect(child, rChild);
      pt.x := rChild.Left;
      pt.y := rChild.Top;
      Windows.ScreenToClient(hwnddlg, pt);
      if pt.y > threshold then
         begin
         SetWindowPos(child, 0, pt.x, pt.y + rowH, 0, 0,
            SWP_NOSIZE or SWP_NOZORDER);
         end;
      child := GetWindow(child, GW_HWNDNEXT);
      end;

   // The CAT groupbox starts above the threshold so the walk did not move it;
   // grow it to keep the new row inside its frame.
   child := GetDlgItem(hwnddlg, 90);
   if child <> 0 then
      begin
      GetWindowRect(child, rGroup);
      SetWindowPos(child, 0, 0, 0,
         rGroup.Right - rGroup.Left, rGroup.Bottom - rGroup.Top + rowH,
         SWP_NOMOVE or SWP_NOZORDER);
      end;

   GetWindowRect(hwnddlg, rDlg);
   SetWindowPos(hwnddlg, 0, rDlg.Left, rDlg.Top,
      rDlg.Right - rDlg.Left, rDlg.Bottom - rDlg.Top + rowH, SWP_NOZORDER);

   // Match the template's label rows exactly: PLAIN left-aligned static, the
   // measured height of the BAUD RATE label, and the same RADIO ONE/TWO prefix
   // the 101..111 label loop gives every other row.  (TF.CreateStatic is NOT
   // used here on purpose -- it hardcodes SS_SUNKEN + SS_CENTER + 23px, which
   // is the boxed look NY4I flagged on the bench.)
   //
   // FONT: the runtime helpers stamp MSSansSerifFont, which is created at
   // 15px -- BIGGER than the ~13px the dialog manager derives from the
   // template's 'FONT 8, MS Sans Serif'.  At 15px the caption wrapped inside
   // the one-row-high static and the second line was clipped, so the label
   // showed only 'RADIO ONE' (bench screenshot).  Ask the DIALOG for its own
   // font (WM_GETFONT) and stamp that on both new controls -- by definition
   // the same font every template control uses, in every language.
   // AnsiUpperCase for style consistency with the dialog's all-caps captions
   // (display-only; the lang const itself stays as the translator wrote it).
   if CATWTR = @Radio1 then
      begin
      caption := 'RADIO ONE ' + AnsiUpperCase(TC_SERIAL_FORMAT_LABEL);
      end
   else
      begin
      caption := 'RADIO TWO ' + AnsiUpperCase(TC_SERIAL_FORMAT_LABEL);
      end;
   // Single line (no wrap), and let the label run to the combo's edge rather
   // than stopping at label 108's width -- this caption is the longest in the
   // column.
   labelW := comboX - labelX - 5;
   tCreateStaticWindow(caption,
      SS_LEFTNOWORDWRAP or WS_CHILD or WS_VISIBLE,
      labelX, labelY, labelW, labelH, hwnddlg, SERIALFMT_LABEL_ID);
   ApplyDialogFont(hwnddlg, SERIALFMT_LABEL_ID);
   tCreateComboBoxWindow(
      WS_CHILD or WS_VISIBLE or WS_TABSTOP or WS_VSCROLL or CBS_DROPDOWNLIST,
      comboX, comboY, comboW, hwnddlg, HMENU(SERIALFMT_COMBO_ID));
   ApplyDialogFont(hwnddlg, SERIALFMT_COMBO_ID);
   for i := Low(SerialFormatChoices) to High(SerialFormatChoices) do
      begin
      tCB_ADDSTRING_PCHAR(hwnddlg, SERIALFMT_COMBO_ID, SerialFormatChoices[i]);
      end;
end;

// ---------------------------------------------------------------------------
// HAMLIB ID row (label 153, edit 154) -- one pitch below DATA/PARITY/STOP.
// 'RADIO n HAMLIB ID' has been a config command all along, but selecting
// 'HamLib (any supported rig)' in the drop-down gave the operator no way to
// SET the rig model from the dialog (NY4I bench).  Same runtime-row technique
// as AddSerialFormatRow (which must run FIRST -- this row anchors on it).
// The edit is enabled only for HAMLIBANY; for every other selection it greys
// and shows the model's fixed registered rig_model as information (blank for
// native radios).
// ---------------------------------------------------------------------------
const
   HAMLIBID_LABEL_ID = 153;
   HAMLIBID_EDIT_ID  = 154;

procedure AddHamLibIDRow(hwnddlg: HWND);
var
   r104, r105, rAnchorLabel, rAnchorCtl, rGroup, rDlg, rChild: TRect;
   pt: TPoint;
   rowH, threshold: integer;
   labelX, labelY, labelW, labelH: integer;
   editX, editY, editW: integer;
   child: HWND;
   caption: string;
begin
   // Same row pitch and shift technique as AddSerialFormatRow; anchored on the
   // serial-format row it just created.
   GetWindowRect(GetDlgItem(hwnddlg, 104), r104);
   GetWindowRect(GetDlgItem(hwnddlg, 105), r105);
   rowH := r105.Top - r104.Top;
   if rowH <= 0 then
      begin
      Exit;
      end;

   GetWindowRect(GetDlgItem(hwnddlg, SERIALFMT_LABEL_ID), rAnchorLabel);
   pt.x := rAnchorLabel.Left;
   pt.y := rAnchorLabel.Top;
   Windows.ScreenToClient(hwnddlg, pt);
   labelX := pt.x;
   labelY := pt.y + rowH;
   labelH := rAnchorLabel.Bottom - rAnchorLabel.Top;

   GetWindowRect(GetDlgItem(hwnddlg, SERIALFMT_COMBO_ID), rAnchorCtl);
   pt.x := rAnchorCtl.Left;
   pt.y := rAnchorCtl.Top;
   Windows.ScreenToClient(hwnddlg, pt);
   editX := pt.x;
   editY := pt.y + rowH;
   editW := rAnchorCtl.Right - rAnchorCtl.Left;
   threshold := pt.y + (rowH div 2);
   labelW := editX - labelX - 5;

   child := GetWindow(hwnddlg, GW_CHILD);
   while child <> 0 do
      begin
      GetWindowRect(child, rChild);
      pt.x := rChild.Left;
      pt.y := rChild.Top;
      Windows.ScreenToClient(hwnddlg, pt);
      if pt.y > threshold then
         begin
         SetWindowPos(child, 0, pt.x, pt.y + rowH, 0, 0,
            SWP_NOSIZE or SWP_NOZORDER);
         end;
      child := GetWindow(child, GW_HWNDNEXT);
      end;

   child := GetDlgItem(hwnddlg, 90);
   if child <> 0 then
      begin
      GetWindowRect(child, rGroup);
      SetWindowPos(child, 0, 0, 0,
         rGroup.Right - rGroup.Left, rGroup.Bottom - rGroup.Top + rowH,
         SWP_NOMOVE or SWP_NOZORDER);
      end;

   GetWindowRect(hwnddlg, rDlg);
   SetWindowPos(hwnddlg, 0, rDlg.Left, rDlg.Top,
      rDlg.Right - rDlg.Left, rDlg.Bottom - rDlg.Top + rowH, SWP_NOZORDER);

   if CATWTR = @Radio1 then
      begin
      caption := 'RADIO ONE ' + AnsiUpperCase(TC_HAMLIB_ID_LABEL);
      end
   else
      begin
      caption := 'RADIO TWO ' + AnsiUpperCase(TC_HAMLIB_ID_LABEL);
      end;
   tCreateStaticWindow(caption,
      SS_LEFTNOWORDWRAP or WS_CHILD or WS_VISIBLE,
      labelX, labelY, labelW, labelH, hwnddlg, HAMLIBID_LABEL_ID);
   ApplyDialogFont(hwnddlg, HAMLIBID_LABEL_ID);
   CreateEdit(ES_NUMBER or ES_AUTOHSCROLL, editX, editY, editW, 22,
      hwnddlg, HAMLIBID_EDIT_ID);
   ApplyDialogFont(hwnddlg, HAMLIBID_EDIT_ID);
end;

// Seed + enable state for the HAMLIB ID edit, driven by the radio-type combo:
// editable config value for HAMLIBANY; greyed informational rig_model for the
// other HamLib-only rows; greyed blank for native radios.
procedure UpdateHamLibIDRow(hwnddlg: HWND);
var
   model: InterfacedRadioType;
begin
   model := ComboSelectedRadioModel(hwnddlg);
   if model = HAMLIBANY then
      begin
      EnableWindowTrue(hwnddlg, HAMLIBID_EDIT_ID);
      Windows.SetDlgItemInt(hwnddlg, HAMLIBID_EDIT_ID, CATWTR^.HamLibID, False);
      end
   else
      begin
      EnableWindowFalse(hwnddlg, HAMLIBID_EDIT_ID);
      if uRadioRegistry.RegisteredHamLibID(model) > 0 then
         begin
         Windows.SetDlgItemInt(hwnddlg, HAMLIBID_EDIT_ID,
            uRadioRegistry.RegisteredHamLibID(model), False);
         end
      else
         begin
         Windows.SetDlgItemTextA(hwnddlg, HAMLIBID_EDIT_ID, '');
         end;
      end;
end;

function RadioUsesNetworkCredentials(rt: InterfacedRadioType): boolean;
begin
   // A string-id factory radio resolves to NoInterfacedRadio, which is not in
   // this set -- so TCI gets no credential fields, which is correct today.
   Result := rt in [IC705, IC7300MK2, IC7600, IC7610,
                    IC7760, IC7850, IC7851, IC9700, IC905,
                    TS890];   // Issue #436 -- TS-890 LAN requires Admin ID/Password
end;

procedure DiscoverNetworkRadios(rt: InterfacedRadioType; Found: TStringList);
var
  list : TList;
  i    : Integer;
begin
  if rt = K4 then
     begin
     list := TK4Discovery.DiscoverRadios(3000);
     try
        for i := 0 to list.Count - 1 do
           begin
           Found.Add(PK4DiscoveredRadio(list[i])^.IPAddress);
           end;
     finally
        for i := 0 to list.Count - 1 do
           begin
           Dispose(PK4DiscoveredRadio(list[i]));
           end;
        list.Free;
     end;
     end
  else if rt = FLEX then
     begin
     // Flex discovery is PASSIVE -- the radio broadcasts to UDP 4992 once a
     // second and we listen.  It must be tested BEFORE the rtICOM branch only in
     // the sense that FLEX is rt:rtKenwood and would otherwise match nothing:
     // before this branch existed the search fell through and always reported
     // "no Flex radios found".
     list := TFlexDiscovery.DiscoverRadios(FLEX_DISCOVERY_TIMEOUT_MS);
     try
        for i := 0 to list.Count - 1 do
           begin
           Found.Add(PFlexDiscoveredRadio(list[i])^.IPAddress);
           end;
     finally
        for i := 0 to list.Count - 1 do
           begin
           Dispose(PFlexDiscoveredRadio(list[i]));
           end;
        list.Free;
     end;
     end
  // Was `RadioParametersArray[rt].rt = rtICOM`.  This branch picks a DISCOVERY
  // MECHANISM, and it sits beside explicit K4 and FLEX branches doing the same,
  // so the honest question is who made the radio -- the registry's display name
  // already carries that and ManufacturerOf reads it, with no radio instance
  // needed (this runs in the dialog, before anything is connected).
  //
  // Note this is NARROWER than the old test in one harmless way: rt = rtICOM
  // also covered the Ten-Tec OMNI6, a CI-V rig -- but the OMNI6 is serial-only
  // and has no network discovery to run, so it never reached here meaningfully.
  else if SameText(uRadioRegistry.ManufacturerOf(rt), 'Icom') then
     begin
     list := TIcomNetworkDiscovery.DiscoverRadios(3000);
     try
        for i := 0 to list.Count - 1 do
           begin
           Found.Add(PDiscoveredRadio(list[i])^.IPAddress);
           end;
     finally
        for i := 0 to list.Count - 1 do
           begin
           Dispose(PDiscoveredRadio(list[i]));
           end;
        list.Free;
     end;
     end;
end;

// Issue #853 -- run network discovery for the radio type currently selected in
// the RADIO ONE/TWO dialog and, on a single hit, write its IP into the IP edit
// (control 130).  Dispatches to K4 or Icom discovery via DiscoverNetworkRadios.
procedure RunNetworkDiscoveryForRadio(hwnddlg: HWND);
var
  found        : TStringList;
  i            : Integer;
  msg          : string;
  savedCursor  : HCURSOR;
  radioName    : AnsiString;
  rt           : InterfacedRadioType;
  fidIdx       : Integer;
begin
  // Item-data read: a string-id factory radio resolves to NoInterfacedRadio,
  // which is "not auto-discoverable" -- same outcome as before, no index math.
  rt := ComboSelectedRadioModel(hwnddlg);

  // User-facing text takes the REGISTRY's display name ('Elecraft K4'), not the
  // raw enum spelling ('K4') this used to show.  Three distinct cases, and the
  // old single line got two of them wrong: a STRING-ID factory radio resolves to
  // NoInterfacedRadio, so the warning named the radio 'NONE'; and asking the
  // registry blindly would say 'Unknown', since DisplayName returns that for any
  // unregistered model -- including the NONE sentinel itself.
  fidIdx := ComboSelectedFactoryIdIndex(hwnddlg);
  if (fidIdx >= 0) and Assigned(gComboFactoryIds) and
     (fidIdx < gComboFactoryIds.Count) then
     begin
     radioName := AnsiString(uRadioRegistry.DisplayNameId(gComboFactoryIds[fidIdx]));
     end
  else if rt = NoInterfacedRadio then
     begin
     radioName := AnsiString(InterfacedRadioTypeSA[NoInterfacedRadio]);
     end
  else
     begin
     radioName := AnsiString(uRadioRegistry.DisplayName(rt));
     end;

  // Issue #1028 -- discoverability is now a radio-factory property (network
  // radios with LAN auto-discovery: K4, the network Icoms, FLEX).
  if not TRadioFactory.IsDiscoverable(rt) then
     begin
     Format(wsprintfBuffer, TC_DISCOVER_NOT_AVAILABLE, PAnsiChar(radioName));
     showwarning(wsprintfBuffer);
     Exit;
     end;

  found := TStringList.Create;
  try
     savedCursor := SetCursor(LoadCursor(0, IDC_WAIT));
     EnableWindowFalse(hwnddlg, 140);
     try
        DiscoverNetworkRadios(rt, found);
     finally
        EnableWindowTrue(hwnddlg, 140);
        SetCursor(savedCursor);
     end;

     if found.Count = 0 then
        begin
        Format(wsprintfBuffer, TC_DISCOVER_NONE_FOUND, PAnsiChar(radioName));
        showwarning(wsprintfBuffer);
        end
     else
        begin
        // Fill the IP edit (130) from the first (or only) radio found.
        Windows.SetDlgItemTextW(hwnddlg, 130, PChar(found[0]));
        // Issue #968 -- discovery gives us the IP but not the port; fill the
        // model default (K4=9200, Icom=50001, ...) so the radio is connectable.
        ApplyDefaultNetworkPort(hwnddlg);
        if found.Count > 1 then
           begin
           Format(wsprintfBuffer, TC_DISCOVER_MULTI_FOUND, PAnsiChar(radioName));
           msg := string(wsprintfBuffer) + #13#10;
           for i := 0 to found.Count - 1 do
              begin
              msg := msg + #13#10 + found[i];
              end;
           showwarning(msg);
           end;
        end;
  finally
     found.Free;
  end;
end;

function CATDlgProc(hwnddlg: HWND; Msg: UINT; wParam: wParam; lParam: lParam): BOOL; stdcall;
label
  1;
var
  i, I2                                 : integer;
  BRT                                   : BaudRateType;
  TempKeyerPortType                     : PortType;
//  TempByte                              : Byte;
  TempPchar                             : PAnsiChar;
  hamLibCheckBoxWind                    : HWnd;
  LabelX, LabelW, EditX, EditW, NewY   : Integer;
  Rect111, Rect131, HamLibCheckRect, RectIP : TRect;
  ptTemp                                : TPoint;
  DlgWindowRect                         : TRect;
  ShowAllRect                           : TRect;    // SHOW ALL SERIAL PORTS row
  ptGroup                               : TPoint;
  ShowAllRowH                           : Integer;
  SavedCATPort, SavedKeyerPort          : PortType; // preserved across a re-populate
  hDiscoverBmp                          : HBITMAP;
  hDiscoverBtn                          : HWND;
  fmtDb, fmtPar, fmtSb                  : Byte;     // parsed SERIAL FORMAT fields
  selRadioModel                         : InterfacedRadioType; // radio-type combo item-data reads

  procedure ButtonsEnable;
  begin
    EnableWindowTrue(hwnddlg, 117);
    EnableWindowTrue(hwnddlg, 118);
  end;

  // Move a dialog control down by DY screen pixels.
  // Used to shift the CW/PTT section down when Icom credential rows are inserted.
  procedure MoveCtrlDown(CtrlId: Integer; DY: Integer);
  var
     R: TRect;
     P: TPoint;
  begin
     GetWindowRect(GetDlgItem(hwnddlg, CtrlId), R);
     P.x := R.Left;
     P.y := R.Top;
     Windows.ScreenToClient(hwnddlg, P);
     SetWindowPos(GetDlgItem(hwnddlg, CtrlId), 0,
        P.x, P.y + DY, 0, 0,
        SWP_NOSIZE or SWP_NOZORDER);
  end;

  // Show NETWORK USERNAME/PASSWORD fields only when port is TCP/IP
  // AND the selected radio is a network model that requires credentials.
  // Issue #904 -- renamed from "Icom credentials"; same fields cover
  // Kenwood TS-890 (Issue #436) and any future credentialed network radio.
  procedure UpdateNetworkCredentialsVisibility;
  var
     ShowCmd: Integer;
  begin
     // Item-data read (string-id factory radios resolve to NoInterfacedRadio,
     // which is not in the credentialed set -- fields hidden, as before).
     if (ComboSelectedPort(hwnddlg, 122) = Network) and
        RadioUsesNetworkCredentials(ComboSelectedRadioModel(hwnddlg)) then
        ShowCmd := SW_SHOW
     else
        ShowCmd := SW_HIDE;
     ShowWindow(GetDlgItem(hwnddlg, 112), ShowCmd);
     ShowWindow(GetDlgItem(hwnddlg, 113), ShowCmd);
     ShowWindow(GetDlgItem(hwnddlg, 132), ShowCmd);
     ShowWindow(GetDlgItem(hwnddlg, 133), ShowCmd);
  end;

  // Guard a title-bar X close when there are changes that have not been
  // applied.  (Cancel/Escape discard immediately per the Win32 convention; the
  // X gets a safety net because it is easy to hit by accident.)
  // The OK button (118) is enabled exactly when such changes
  // exist (ButtonsEnable on any edit and on Reset; disabled at init and after
  // Apply), so its enabled state is the dirty flag.  Returns True when the
  // dialog may close now:
  //    no unapplied changes -> True (no prompt)
  //    Yes    -> apply the changes, then True
  //    No     -> discard, True
  //    Cancel -> False (keep the dialog open).  Cancel is the default button so
  //              an accidental Enter/Escape on the prompt loses nothing.
  function MayClose: Boolean;
  begin
     Result := True;
     if not IsWindowEnabled(GetDlgItem(hwnddlg, 118)) then
        begin
        Exit;
        end;
     case MessageBox(hwnddlg, TC_SAVECHANGES, tr4w_ClassName,
             MB_YESNOCANCEL or MB_ICONQUESTION or MB_TOPMOST or MB_DEFBUTTON3) of
        IDYES:
           begin
           RestartPollingThread(hwnddlg);
           end;
        IDCANCEL:
           begin
           Result := False;
           end;
     end;
  end;
begin

  Result := False;
  case Msg of
    // Owner-draw plumbing for the two port combos.  MEASUREITEM must be answered
    // or an owner-draw combo gets a zero-height list; DRAWITEM does the painting
    // (grey text for a port Windows is not reporting -- see DrawPortComboItem).
    WM_MEASUREITEM:
      begin
      if (PMeasureItemStruct(lParam)^.CtlID = 122) or
         (PMeasureItemStruct(lParam)^.CtlID = 123) then
         begin
         PMeasureItemStruct(lParam)^.itemHeight := 16;
         Result := True;
         end;
      end;

    WM_DRAWITEM:
      begin
      if (PDrawItemStruct(lParam)^.CtlID = 122) or
         (PDrawItemStruct(lParam)^.CtlID = 123) then
         begin
         DrawPortComboItem(PDrawItemStruct(lParam)^);
         Result := True;
         end;
      end;

    // A serial port appeared or disappeared while the dialog is open.  Update
    // both lists so the CLOSED combo stops claiming an unplugged port is present
    // -- refresh-on-drop-down alone cannot fix the collapsed control.
    // RefreshPortCombo skips a combo whose list is dropped, so nothing is ever
    // pulled out from under the mouse.
    WM_DEVICECHANGE:
      begin
      if IsComPortArrivalOrRemoval(wParam) then
         begin
         RefreshPortCombo(hwnddlg, 122);
         RefreshPortCombo(hwnddlg, 123);
         end;
      end;

    WM_DESTROY:
      begin
      UnregisterComPortNotification(gPortNotify);
      end;

    WM_INITDIALOG:

      begin
//        CATWTR := RadioPtr(lParam);
        if CATWTR = @Radio1 then
        begin
          TempKeyerPortType := Radio1.tKeyerPort;
          TempPchar := 'RADIO ONE ';
        end;

        if CATWTR = @Radio2 then
        begin
          TempKeyerPortType := Radio2.tKeyerPort;
          TempPchar := 'RADIO TWO ';
        end;
        SetWindowTextA(hwnddlg, TempPchar);

        {radio -- registry-built: display names, sorted, identity in item data}
        PopulateRadioTypeCombo(hwnddlg);

        // Rebuild both port combos as OWNER-DRAW before filling them, so a port
        // that is not present can be drawn grey while staying selectable.  Must
        // happen before PopulatePortCombo -- DestroyWindow would discard the items.
        MakePortComboOwnerDraw(hwnddlg, 122);
        MakePortComboOwnerDraw(hwnddlg, 123);
        // Font BEFORE populating: ComboFitDroppedWidth measures entries in the
        // combo's own font, so the width math must see the final font.
        ApplyDialogFont(hwnddlg, 122);
        ApplyDialogFont(hwnddlg, 123);

        // Port combos are filtered to what Windows reports (plus the configured
        // port when it is unplugged) and carry their PortType as item data --
        // see PopulatePortCombo.  The configured port must be passed in so it can
        // still be offered when the device is absent.
        PopulatePortCombo(hwnddlg, 122, CATWTR^.tCATPortType);
        PopulatePortCombo(hwnddlg, 123, TempKeyerPortType);
        // Both combos are filled, so the widest caption is now known -- size the
        // dialog to it (the drop-down list is sized inside PopulatePortCombo).
        WidenDialogForPortNames(hwnddlg);

        for I2 := 124 to 125 do
          for i := 1 to 2 do
            tCB_ADDSTRING_PCHAR(hwnddlg, I2, RTS_DTR_Values_Array[i]);

        for I2 := 126 to 127 do
          for i := 1 to 4 do
            tCB_ADDSTRING_PCHAR(hwnddlg, I2, RTS_DTR_Values_Array[i]);

        for BRT := BR1200 to BR115200 do
          tCB_ADDSTRING_PCHAR(hwnddlg, 128, inttopchar(CAT_BAUDRATE_ARRAY[integer(BRT)]));

        // DATA/PARITY/STOP row, one pitch below BAUD RATE.  Must run BEFORE
        // the credential rows below: it shifts everything under the CAT
        // groupbox down one row, and the credential code measures control 131
        // to place itself.
        AddSerialFormatRow(hwnddlg);
        // HAMLIB ID row, one pitch below that (anchors on the row above).
        AddHamLibIDRow(hwnddlg);

        // Create NETWORK USERNAME (label 112, edit 132) and NETWORK PASSWORD
        // (label 113, edit 133) dynamically. Positioned below control 131
        // (TCP port), sized to match. Used by Icom CI-V/IP, Kenwood TS-890,
        // and any future credentialed network radio (Issue #904).
        // The label prepend loop below will build the full command names.
        GetWindowRect(GetDlgItem(hwnddlg, 111), Rect111);
        GetWindowRect(GetDlgItem(hwnddlg, 131), Rect131);
        // LabelX: left edge of existing label column (from label 111)
        ptTemp.x := Rect111.Left;
        ptTemp.y := Rect111.Top;
        Windows.ScreenToClient(hwnddlg, ptTemp);
        LabelX := ptTemp.x;
        // EditX: left edge of edit column (from edit 131); also gives us NewY
        ptTemp.x := Rect131.Left;
        ptTemp.y := Rect131.Bottom;
        Windows.ScreenToClient(hwnddlg, ptTemp);
        EditX := ptTemp.x;
        EditW := Rect131.Right - Rect131.Left;
        NewY := ptTemp.y + 5;
        // LabelW spans from label left to edit left so the full text fits
        LabelW := EditX - LabelX - 5;
        GetWindowRect(hwnddlg, DlgWindowRect);
        SetWindowPos(hwnddlg, 0,
           DlgWindowRect.Left, DlgWindowRect.Top,
           DlgWindowRect.Right - DlgWindowRect.Left,
           DlgWindowRect.Bottom - DlgWindowRect.Top + 56,
           SWP_NOZORDER);
        // Short display text — saving is handled explicitly in RestartPollingThread.
        CreateStatic('NETWORK USERNAME', LabelX, NewY, LabelW, hwnddlg, 112);
        CreateEdit(ES_AUTOHSCROLL, EditX, NewY, EditW, 22, hwnddlg, 132);
        CreateStatic('NETWORK PASSWORD', LabelX, NewY + 28, LabelW, hwnddlg, 113);
        // ES_PASSWORD masks the text with bullets
        CreateEdit(ES_AUTOHSCROLL or ES_PASSWORD, EditX, NewY + 28, EditW, 22, hwnddlg, 133);
        ApplyDialogFont(hwnddlg, 112);
        ApplyDialogFont(hwnddlg, 132);
        ApplyDialogFont(hwnddlg, 113);
        ApplyDialogFont(hwnddlg, 133);

        // Issue #853: dynamic "Discover" button (ID 140), placed just to the
        // left of the IP-address edit (control 130, which lives in the dialog
        // resource), in the gap after the label.  Runs network discovery for the
        // selected radio type and fills in the IP.  Enabled only for network
        // radios -- see the cat-port enable blocks below.
        GetWindowRect(GetDlgItem(hwnddlg, 130), RectIP);
        ptTemp.x := RectIP.Left;
        ptTemp.y := RectIP.Top;
        Windows.ScreenToClient(hwnddlg, ptTemp);
        // Show the radar-sweep glyph (BITMAP resource 853, imported into each
        // tr4w_<lang>.res).  If the bitmap is not in the linked resources, fall
        // back to a '?' caption so the button still works before the import.
        hDiscoverBmp := LoadBitmap(hInstance, MAKEINTRESOURCE(853));
        if hDiscoverBmp <> 0 then
           begin
           hDiscoverBtn := CreateButton(BS_PUSHBUTTON or BS_BITMAP, '',
              ptTemp.x - 26, ptTemp.y, 22, hwnddlg, 140);
           Windows.SendMessage(hDiscoverBtn, BM_SETIMAGE, IMAGE_BITMAP,
              Integer(hDiscoverBmp));
           end
        else
           begin
           hDiscoverBtn := CreateButton(BS_PUSHBUTTON, '?', ptTemp.x - 26, ptTemp.y, 22, hwnddlg, 140);
           end;
        ApplyDialogFont(hwnddlg, 140);   // only visible on the '?' fallback, but keep every runtime control uniform

        // Hover tooltip for the Discover button (hardcoded for now -- a
        // TC_TOOLTIP_DISCOVERY resource string can replace the literal later).
        CreateToolTip(hDiscoverBtn, TC_TOOLTIP_DISCOVERY{'Discover radios on the network'});

        // The dialog was expanded 56px to make room for the two Icom credential
        // rows (USERNAME + PASSWORD), inserted at the position of the HamLib
        // checkbox. Without adjustment, the credential rows cover the checkbox
        // and the CW/PTT section overlaps the checkbox when moved.
        //
        // Fix: move the HamLib checkbox and every control at or below the
        // CW/PTT group box down by 56px, and expand the CAT group box height
        // by 56px to keep the checkbox inside the CAT frame visually.

        // Expand the CAT group box (ID 90) to contain USE HAMLIB after it moves.
        GetWindowRect(GetDlgItem(hwnddlg, 90), HamLibCheckRect);
        ptTemp.x := HamLibCheckRect.Left;
        ptTemp.y := HamLibCheckRect.Top;
        Windows.ScreenToClient(hwnddlg, ptTemp);
        SetWindowPos(GetDlgItem(hwnddlg, 90), 0,
           ptTemp.x, ptTemp.y,
           HamLibCheckRect.Right - HamLibCheckRect.Left,
           HamLibCheckRect.Bottom - HamLibCheckRect.Top + 56,
           SWP_NOZORDER);

        // Move USE HAMLIB checkbox below the PASSWORD row.
        MoveCtrlDown(1000, 56);

        // Move CW/PTT group box (91) and all its labels, combos,
        // plus the Name row and the four buttons below it, down 56px.
        // These IDs come from dialog resource 66 (tr4w_eng.rc):
        //   91            CW/PTT group box
        //   103/123       Output Port label + combo
        //   106/126       Keyer RTS label + combo
        //   107/127       Keyer DTR label + combo
        //   109/129       Name label + edit
        //   116-119       Reset / OK / Close / Apply buttons
        MoveCtrlDown(91,  56);
        MoveCtrlDown(103, 56);
        MoveCtrlDown(123, 56);
        MoveCtrlDown(106, 56);
        MoveCtrlDown(126, 56);
        MoveCtrlDown(107, 56);
        MoveCtrlDown(127, 56);
        MoveCtrlDown(109, 56);
        MoveCtrlDown(129, 56);
        MoveCtrlDown(116, 56);
        MoveCtrlDown(117, 56);
        MoveCtrlDown(118, 56);
        MoveCtrlDown(119, 56);

        // "Show all serial ports" (ID 150).  Inserted as one more row using the
        // same technique as the credential rows above: it takes the USE HAMLIB
        // checkbox's slot, USE HAMLIB and everything below shift down by a row,
        // and the CAT group box grows so the new row stays framed.
        // Created at RUNTIME for the same reason the dialog is widened at runtime
        // -- the eleven per-language .RES files are checked-in binaries and
        // nothing in the build compiles res\Tr4w.rc.
        GetWindowRect(GetDlgItem(hwnddlg, 1000), ShowAllRect);
        ptTemp.x := ShowAllRect.Left;
        ptTemp.y := ShowAllRect.Top;
        Windows.ScreenToClient(hwnddlg, ptTemp);
        ShowAllRowH := (ShowAllRect.Bottom - ShowAllRect.Top) + 4;

        GetWindowRect(hwnddlg, DlgWindowRect);
        SetWindowPos(hwnddlg, 0,
           DlgWindowRect.Left, DlgWindowRect.Top,
           DlgWindowRect.Right - DlgWindowRect.Left,
           (DlgWindowRect.Bottom - DlgWindowRect.Top) + ShowAllRowH,
           SWP_NOZORDER);

        GetWindowRect(GetDlgItem(hwnddlg, 90), ShowAllRect);
        ptGroup.x := ShowAllRect.Left;
        ptGroup.y := ShowAllRect.Top;
        Windows.ScreenToClient(hwnddlg, ptGroup);
        SetWindowPos(GetDlgItem(hwnddlg, 90), 0,
           ptGroup.x, ptGroup.y,
           ShowAllRect.Right - ShowAllRect.Left,
           (ShowAllRect.Bottom - ShowAllRect.Top) + ShowAllRowH,
           SWP_NOZORDER);

        MoveCtrlDown(1000, ShowAllRowH);
        MoveCtrlDown(91,  ShowAllRowH);
        MoveCtrlDown(103, ShowAllRowH);
        MoveCtrlDown(123, ShowAllRowH);
        MoveCtrlDown(106, ShowAllRowH);
        MoveCtrlDown(126, ShowAllRowH);
        MoveCtrlDown(107, ShowAllRowH);
        MoveCtrlDown(127, ShowAllRowH);
        MoveCtrlDown(109, ShowAllRowH);
        MoveCtrlDown(129, ShowAllRowH);
        MoveCtrlDown(116, ShowAllRowH);
        MoveCtrlDown(117, ShowAllRowH);
        MoveCtrlDown(118, ShowAllRowH);
        MoveCtrlDown(119, ShowAllRowH);

        // AnsiUpperCase: every caption in this dialog is ALL-CAPS ('RADIO ONE
        // USE HAMLIB', ...), and after the fonts were unified the sentence-case
        // caption still read as "smaller" (bench: NY4I).  Uppercasing at the
        // point of DISPLAY keeps the translated lang consts untouched and is
        // locale-aware (Cyrillic, diacritics).
        tCreateButtonWindow(0, AnsiUpperCase(TC_SHOW_ALL_SERIAL_PORTS),
           WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_AUTOCHECKBOX,
           ptTemp.x, ptTemp.y,
           GetSystemMetrics(SM_CXVSCROLL) * 12, 20, hwnddlg, HMENU(150));
        ApplyDialogFont(hwnddlg, 150);
        if tShowAllSerialPorts then
           begin
           Windows.SendDlgItemMessage(hwnddlg, 150, BM_SETCHECK, BST_CHECKED, 0);
           end;

        for i := 101 to 111 do
           begin
           tCB_SETCURSEL(hwnddlg, i + 20, 0);
           Windows.GetDlgItemTextA(hwnddlg, i, TempBuffer1, SizeOf(TempBuffer1));
           Format(wsprintfBuffer, '%s%s', TempPchar, TempBuffer1);         // This prepends RADIO ONE or RADIO TWO.
           if i = 103 then
              Format(wsprintfBuffer, 'KEYER %s%s', TempPchar, TempBuffer1);
           Windows.SetDlgItemTextA(hwnddlg, i, wsprintfBuffer);
           end;

        i := 1000;
        Windows.GetDlgItemTextA(hwnddlg, i, TempBuffer1, SizeOf(TempBuffer1));
        Format(wsprintfBuffer, '%s%s', TempPchar, TempBuffer1);         // This prepends RADIO ONE or RADIO TWO.
        Windows.SetDlgItemTextA(hwnddlg, i, wsprintfBuffer);


        {radio type -- select by ITEM DATA (the sorted list makes index useless)}
        if (CATWTR^.FactoryId <> '') and Assigned(gComboFactoryIds) and
           (gComboFactoryIds.IndexOf(string(CATWTR^.FactoryId)) >= 0) then
           begin
           ComboSelectRadioByData(hwnddlg,
              RADIOITEM_FACTORYID_FLAG or gComboFactoryIds.IndexOf(string(CATWTR^.FactoryId)));
           end
        else
           begin
           ComboSelectRadioByData(hwnddlg, Ord(CATWTR^.RadioModel));
           end;
        UpdateHamLibIDRow(hwnddlg);

        {keyer port}
        ComboSelectPort(hwnddlg, 123, TempKeyerPortType);

        {cat port}
        ComboSelectPort(hwnddlg, 122, CATWTR^.tCATPortType);
        if (CATWTR^.tCATPortType = NETWORK) then
           begin
           EnableWindowTrue(hwnddlg, 130);
           EnableWindowTrue(hwnddlg, 140);
           EnableWindowTrue(hwnddlg, 131);
           EnableWindowTrue(hwnddlg, 132);
           EnableWindowTrue(hwnddlg, 133);
           EnableWindowFalse(hwnddlg, 124);
           EnableWindowFalse(hwnddlg, 125);
           EnableWindowFalse(hwnddlg, 128);
           EnableWindowFalse(hwnddlg, SERIALFMT_COMBO_ID);
           end
        else
           begin
           EnableWindowTrue(hwnddlg, 124);
           EnableWindowTrue(hwnddlg, 125);
           EnableWindowTrue(hwnddlg, 128);
           EnableWindowTrue(hwnddlg, SERIALFMT_COMBO_ID);
           EnableWindowFalse(hwnddlg, 130);
           EnableWindowFalse(hwnddlg, 140);
           EnableWindowFalse(hwnddlg, 131);
           EnableWindowFalse(hwnddlg, 132);
           EnableWindowFalse(hwnddlg, 133);
           end;

        {keyer_rts}
        tCB_SETCURSEL(hwnddlg, 126, Ord(CATWTR^.tr4w_keyer_rts_state) - 1);

        {keyer_dtr}
        tCB_SETCURSEL(hwnddlg, 127, Ord(CATWTR^.tr4w_keyer_DTR_state) - 1);

        {cat_rts}
        tCB_SETCURSEL(hwnddlg, 124, Ord(CATWTR^.tr4w_cat_rts_state) - 1);

        {cat_dtr}
        tCB_SETCURSEL(hwnddlg, 125, Ord(CATWTR^.tr4w_cat_dtr_state) - 1);

        for BRT := BR1200 to BR115200 do
          if CATWTR^.RadioBaudRate = CAT_BAUDRATE_ARRAY[integer(BRT)] then
            tCB_SETCURSEL(hwnddlg, 128, Cardinal(brt));

        {data/parity/stop: the configured SERIAL FORMAT if valid, else the
         model's registered defaults (what the connect path will actually use)}
        if uRadioRegistry.TryParseSerialFormat(string(CATWTR^.SerialFormat),
              fmtDb, fmtPar, fmtSb) then
           begin
           SelectSerialFormat(hwnddlg,
              uRadioRegistry.SerialFormatToString(fmtDb, fmtPar, fmtSb));
           end
        else
           begin
           SelectSerialFormat(hwnddlg, SerialFormatDefaultFor(CATWTR^.RadioModel));
           end;
        {freq adder}

//        Windows.SetDlgItemInt(hwnddlg, 129, TempRadio^.FrequencyAdder, False);
        Windows.SetDlgItemTextW(hwnddlg, 129, PChar(CATWTR^.RadioName));

        Windows.SetDlgItemTextW(hwnddlg, 130, PChar(CATWTR^.IPAddress));
        Windows.SetDlgItemInt(hwnddlg, 131, CATWTR^.RadioTCPPort, False);
        Windows.SetDlgItemTextW(hwnddlg, 132, PChar(CATWTR^.NetworkUsername));
        Windows.SetDlgItemTextW(hwnddlg, 133, PChar(CATWTR^.NetworkPassword));
        hamLibCheckBoxWind := GetDlgItem(hwnddlg, 1000);

        // Test the CONFIGURED radio -- NOT the RadioType variable, which at this
        // point is a STALE LOOP COUNTER: the combo-population loop above leaves
        // it at High(InterfacedRadioType) = HAMLIBANY, which is HamLib-only, so
        // the old test was true for EVERY radio.  Bench symptom (NY4I, IC-718):
        // the checkbox came up force-checked and greyed for a native radio, and
        // Apply then persisted USE HAMLIB=TRUE -- silently routing a native
        // radio through HamLib (whose emulated VFO-B poll flips the rig's VFO
        // selection once a second on non-targetable rigs).
        if uRadioRegistry.IsHamLibOnly(CATWTR^.RadioModel) then
           begin
           if not CATWTR^.UseHamLib then
              begin
              logger.Info('Setting UseHamLib to true because radioModel is a Hamlib only radio');
              CATWTR^.UseHamLib := true;
              end;
           // These radios have no native CAT path in TR4W at all, so unchecking
           // the box does not select an alternative -- it silently leaves the
           // operator with no radio control.  Grey it out rather than let them
           // reach a state that cannot work.  (Same treatment as the COM port
           // drop-down, which greys ports that cannot be selected.)
           //
           // This is NOT the whole guard: 'RADIO ONE USE HAMLIB' is also a
           // config-file command, so a .cfg can clear the flag without this
           // dialog ever opening.  RadioObject.SetUpRadioInterface enforces the
           // same invariant on the runtime path.
           EnableWindowFalse(hwnddlg, 1000);
           end;

        if CATWTR^.UseHamLib then
           begin
           Windows.SendDlgItemMessage(hwnddlg, 1000, BM_SETCHECK, BST_CHECKED, 0);
           end;
        UpdateNetworkCredentialsVisibility;
        EnableWindowFalse(hwnddlg, 117);
        EnableWindowFalse(hwnddlg, 118);

        // Relabel the Close button (119) as "Cancel".  It already discards all
        // form changes (WM_CLOSE just EndDialog(0); nothing is persisted unless
        // OK/Apply call RestartPollingThread), so the new label simply makes the
        // edit-commit semantics explicit.  Done at runtime to cover all
        // languages without touching the per-language resources.
        Windows.SetDlgItemTextA(hwnddlg, 119, CANCEL_WORD);

        // Everything above moved, resized or recreated controls at runtime (the
        // credential rows, the Show-all row, the widening for port names, the
        // owner-draw combos).  Moving a child with SetWindowPos does not reliably
        // repaint the area it left behind or the control's own frame, which shows
        // up as clipped button captions.  One repaint of the whole dialog at the
        // end of layout is cheaper than reasoning about which rectangles are stale.
        Windows.InvalidateRect(hwnddlg, nil, True);
        Windows.UpdateWindow(hwnddlg);

        // Ask Windows to tell us when a serial port arrives or disappears, so an
        // adapter unplugged while this dialog is open stops being shown as
        // present.  Registered LAST: it targets this window, which must already
        // be built.  If it fails we simply never get the messages and behaviour
        // falls back to refresh-on-drop-down, which is not a failure worth
        // reporting to the operator.
        UnregisterComPortNotification(gPortNotify);   // paranoia: no leak on re-init
        gPortNotify := RegisterComPortNotification(hwnddlg);
      end;

    WM_COMMAND:
      begin
        // Re-enumerate just before a port list drops.  Without this the combos
        // hold whatever was true when the dialog opened, so unplugging or
        // plugging a USB adapter while the dialog is up shows stale information
        // until it is closed and reopened -- and the port dialog is exactly where
        // someone plugs a radio in to see it appear.
        // CBN_DROPDOWN fires BEFORE the list is shown, so rebuilding here is safe.
        // The selection is preserved by PORT, never by index: a port that vanished
        // is re-added by PopulatePortCombo as "(not connected)" rather than
        // silently changing what the radio is configured with.
        if (HiWord(wParam) = CBN_DROPDOWN) and
           ((LoWord(wParam) = 122) or (LoWord(wParam) = 123)) then
           begin
           SavedCATPort := ComboSelectedPort(hwnddlg, LoWord(wParam));
           PopulatePortCombo(hwnddlg, LoWord(wParam), SavedCATPort);
           ComboSelectPort(hwnddlg, LoWord(wParam), SavedCATPort);
           // List width only -- NOT WidenDialogForPortNames, which is cumulative.
           ComboFitDroppedWidth(hwnddlg, LoWord(wParam));
           end;

        if (HiWord(wParam) = CBN_SELCHANGE)
          or (HiWord(wParam) = EN_CHANGE)
          then
        begin
          ButtonsEnable;
          if LoWord(wParam) = 122 then   // 122 is port type (serial, network, etc).
             begin
             if ComboSelectedPort(hwnddlg, 122) = Network then
                begin
                EnableWindowTrue(hwnddlg, 130);
                EnableWindowTrue(hwnddlg, 140);
                EnableWindowTrue(hwnddlg, 131);
                EnableWindowTrue(hwnddlg, 132);
                EnableWindowTrue(hwnddlg, 133);
                EnableWindowFalse(hwnddlg,124);
                EnableWindowFalse(hwnddlg,125);
                EnableWindowFalse(hwnddlg,128);
                EnableWindowFalse(hwnddlg, SERIALFMT_COMBO_ID);
                ApplyDefaultNetworkPort(hwnddlg);   // Issue #968 -- default port on switch to Network
                end
             else
                begin
                EnableWindowTrue(hwnddlg, 124);
                EnableWindowTrue(hwnddlg, 125);
                EnableWindowTrue(hwnddlg, 128);
                EnableWindowTrue(hwnddlg, SERIALFMT_COMBO_ID);
                EnableWindowFalse(hwnddlg,130);
                EnableWindowFalse(hwnddlg,140);
                EnableWindowFalse(hwnddlg,131);
                EnableWindowFalse(hwnddlg,132);
                EnableWindowFalse(hwnddlg,133);
               end;
             UpdateNetworkCredentialsVisibility;
             end;
          if LoWord(wParam) = 121 then
          begin
            // Identity from ITEM DATA -- the registry-built list is sorted, so
            // the row index is meaningless.  A string-id factory radio (and
            // NONE) resolves to NoInterfacedRadio here.
            selRadioModel := ComboSelectedRadioModel(hwnddlg);
            // Baud default comes from the RADIO REGISTRY, not the legacy
            // RadioParametersArray.br.  A model the registry does not know
            // (NONE, string-id radios) still falls back to 4800 / 8N2.
            if uRadioRegistry.IsRegistered(selRadioModel) then
               begin
               tCB_SETCURSEL(hwnddlg, 128,
                  Cardinal(BaudRateComboIndex(
                     uRadioRegistry.SerialParamsFor(selRadioModel).baud)));
               // DATA/PARITY/STOP follows the model, exactly like the baud rate.
               SelectSerialFormat(hwnddlg, SerialFormatDefaultFor(selRadioModel));
               end
            else
               begin
               tCB_SETCURSEL(hwnddlg, 128, 2);   // 4800 default
               SelectSerialFormat(hwnddlg, '8N2');
               end;
            // The USE HAMLIB checkbox follows the selected model: forced ON and
            // greyed for a HamLib-only model (unchecking it would leave the
            // operator with no radio control at all), operator-controlled for
            // everything else -- including recovering from a greyed state after
            // switching AWAY from a HamLib-only model.
            if uRadioRegistry.IsHamLibOnly(selRadioModel) then
               begin
               Windows.SendDlgItemMessage(hwnddlg, 1000, BM_SETCHECK, BST_CHECKED, 0);
               EnableWindowFalse(hwnddlg, 1000);
               end
            else
               begin
               EnableWindowTrue(hwnddlg, 1000);
               end;
            UpdateHamLibIDRow(hwnddlg);
            UpdateNetworkCredentialsVisibility;
            ApplyDefaultNetworkPort(hwnddlg);   // Issue #968 -- default port when the radio type changes
          end;

        end;
        case wParam of
          2, 119: goto 1;   // Cancel / Escape -- discard immediately (per Win32 dialog convention)
          117: {Apply}
            begin
              // Conflict check BEFORE committing: a No answer aborts the apply
              // and leaves the dialog open (buttons still enabled) so the port
              // can be corrected right here.
              if ConfirmPortConflicts(hwnddlg) then
                 begin
                 EnableWindowFalse(hwnddlg, 117);
                 EnableWindowFalse(hwnddlg, 118);
                 RestartPollingThread(hwnddlg);
                 end;
            end;
          118: {OK}
            begin
              if ConfirmPortConflicts(hwnddlg) then
                 begin
                 RestartPollingThread(hwnddlg);
                 goto 1;
                 end;
            end;

          116: {Reset -- form only; nothing is persisted until OK/Apply}

            begin
              // Reset every combo to its first entry.  For the keyer RTS (126)
              // and DTR (127) combos this is index 0 = 'OFF'
              // (RTS_DTR_Values_Array = OFF/ON/CW/PTT), so they end up OFF.
              for i := 121 to 128 do tCB_SETCURSEL(hwnddlg, i, 0);
              tCB_SETCURSEL(hwnddlg, 128, 2);   // baud rate -> 4800 (default)
              SelectSerialFormat(hwnddlg, '8N2');   // frame -> the program default

              // Reset the network edits to defaults.  IP ADDRESS is a string
              // and may be blank.  TCP PORT is an integer (ctInteger): a blank
              // value triggers the Issue #968 "has no value" warning on apply,
              // so reset it to 0 -- the in-range default that means "no port".
              Windows.SetDlgItemTextA(hwnddlg, 130, '');     // IP ADDRESS
              Windows.SetDlgItemInt(hwnddlg, 131, 0, False);  // TCP PORT -> 0

              // NAME (control 129) is a freeform rig label; reset it to the
              // documented per-radio default ('Rig 1' / 'Rig 2').
              if CATWTR = @Radio1 then
                 begin
                 Windows.SetDlgItemTextA(hwnddlg, 129, 'Rig 1');
                 end
              else
                 begin
                 Windows.SetDlgItemTextA(hwnddlg, 129, 'Rig 2');
                 end;

              ButtonsEnable;
            end;

          140: {Discover -- Issue #853}
            RunNetworkDiscoveryForRadio(hwnddlg);

          150: {Show all serial ports}
             begin
             // A VIEW toggle, not a setting the dialog commits: it changes which
             // rows are offered, not what the radio is configured with.  Rebuild
             // both combos and restore each selection by PORT (its index will have
             // moved), so toggling never silently changes the operator's choice.
             tShowAllSerialPorts :=
                boolean(TF.SendDlgItemMessage(hwnddlg, 150, BM_GETCHECK));
             SavedCATPort := ComboSelectedPort(hwnddlg, 122);
             SavedKeyerPort := ComboSelectedPort(hwnddlg, 123);
             PopulatePortCombo(hwnddlg, 122, SavedCATPort);
             PopulatePortCombo(hwnddlg, 123, SavedKeyerPort);
             ComboSelectPort(hwnddlg, 122, SavedCATPort);
             ComboSelectPort(hwnddlg, 123, SavedKeyerPort);
             // Deliberately NOT WidenDialogForPortNames here.  That routine grows
             // the dialog and slides the button row right by its delta; calling it
             // again on every toggle is CUMULATIVE, so the buttons would walk
             // rightwards each time the box is ticked.  The dialog is sized once at
             // init; only the drop-down list needs re-fitting for the new captions,
             // and its width is independent of the control.
             ComboFitDroppedWidth(hwnddlg, 122);
             ComboFitDroppedWidth(hwnddlg, 123);
             end;

          1000:
             begin
             ButtonsEnable;
             // Warn if user is enabling HamLib for a radio that TR4W supports natively.
             // HamLib polling on natively-supported radios causes excessive CI-V traffic
             // that interferes with front-panel operation. Allow it but make the tradeoff clear.
             if boolean(TF.SendDlgItemMessage(hwnddlg, 1000, BM_GETCHECK)) then
                begin
                if not uRadioRegistry.IsHamLibOnly(ComboSelectedRadioModel(hwnddlg)) then
                   begin
                   MessageBox(hwnddlg,
                     'This radio has native TR4W support. Using HamLib is not recommended.' + #13#10 +
                     #13#10 +
                     'RIT and XIT status will update every 5 seconds due to the HamLib implementation on certain (Icom) rigs.' + #13#10 +
                     #13#10 +
                     'Querying RIT/XIT requires a physical VFO select command that could ' +
                     'interfere with front-panel operations.' + #13#10 +
                     #13#10 +
                     'All other values (frequency, mode, PTT, split) update every second.' + #13#10 +
                     #13#10 +
                     'Check this option only if you have a specific reason to use HamLib.',
                     'HamLib Not Recommended for This Radio',
                     MB_OK or MB_ICONWARNING);
                   end;
                end;
             end;
        end;
      end;

    WM_CLOSE:   // the title-bar X -- confirm if there are unapplied changes
      begin
        if not MayClose then Exit;   // Result is already False -> dialog stays open
        1:
        EndDialog(hwnddlg, 0);
      end;
  end;
end;

procedure CloseCATAndKeyerForThisRadio;
begin
  IcomResponseTimeout := 0;

  {Close CAT Port}
  // THE FACTORY OBJECT OWNS THE LINK, whatever the transport.  Only the network
  // arm disconnected it, so a SERIAL factory radio was left running here: the
  // handle closed below belongs to the legacy CPU-keyer table, which a factory
  // radio does not use.  It survived because SetUpRadioInterface frees the old
  // object when a slot is REPLACED -- but not when it is cleared.
  //
  // STOP THE POLLING THREAD, DO NOT MERELY DISCONNECT.  Disconnect closes the
  // port and ends the READING thread; the POLLING thread kept running, and its
  // MaintainSerialLink exists precisely to reopen a port that has gone quiet.
  // So it did its job on the port we had just closed, and the replacement
  // radio then met "Cannot open COM15 (error 5)".  Measured on NY4I's bench
  // while activating a profile:
  //
  //   22.604  Disconnect: closing serial port
  //   22.715  MaintainSerialLink - Elecraft K3 silent for 1000 ms, reopening
  //   22.735  ReopenSerialPort: reopened COM15          <- the OLD radio
  //   22.810  Connect: Cannot open COM15 (error 5)      <- the NEW one
  //
  // The Icom in slot two escaped only by timing.  ShutDownRadioInterface is
  // the one routine that does this in the right order -- request the poller
  // stop, WAIT for it, then disconnect and free -- so both the profile-apply
  // path and this dialog use it rather than each open-coding a teardown.
  // That matters more, not less, as Ctrl-J and uCFG are retired: the durable
  // behaviour belongs on the radio, not in a dialog that is going away.
  if CATWTR^.tFactoryObject <> nil then
     begin
     CATWTR^.ShutDownRadioInterface;
     end;

  // Still done for a serial port: a radio with no factory object (the legacy
  // fallback path) keeps its handle in that table, and closing an already
  // invalid handle is guarded.
  if CATWTR^.tCATPortType in SerialPorts then
     begin
     if CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tCATPortType] <> INVALID_HANDLE_VALUE then
        begin
        Windows.CloseHandle(CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tCATPortType]);
        CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tCATPortType] := INVALID_HANDLE_VALUE;
        end;
     end;
  CATWTR^.tCATPortHandle := INVALID_HANDLE_VALUE;

  {Close Keyer Port}
  if CATWTR^.tKeyerPort in SerialPorts then
     begin
     if CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tKeyerPort] <> INVALID_HANDLE_VALUE then
        begin
        Windows.CloseHandle(CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tKeyerPort]);
        CPUKeyer.SerialPortConfigured_Handle[CATWTR^.tKeyerPort] := INVALID_HANDLE_VALUE;
        end;
     end;
  CATWTR^.tKeyerPortHandle := INVALID_HANDLE_VALUE;

  //  if (RadioToClose^.tr4w_KeyerPort >= Parallel1) and (RadioToClose^.tr4w_KeyerPort <= Parallel3) then    DestroyDlPortio;

end;

// Keep each radio's keys grouped in the ini.  WritePrivateProfileString can
// only UPDATE a key in place or APPEND a new one at the end of the section --
// insertion position is fixed at first creation -- so a key added to TR4W
// after a user's ini was first written lands stranded at the bottom, away
// from its radio's block (NY4I bench: RADIO ONE SERIAL FORMAT after all the
// RADIO TWO keys, KEYER RADIO ONE OUTPUT PORT after the RADIO TWO block).
// This pass moves the known strays back beside their anchors, editing the
// FILE TEXT so every other line -- including comment lines like
// '#RADIO ONE TYPE=K4' -- keeps its exact place.
procedure GroupRadioIniKeys;
var
   lines: TStringList;
   i, sectStart, sectEnd: integer;
   changed: Boolean;

   function KeyLine(const key: string; lineIdx: integer): Boolean;
   begin
      Result := SameText(Copy(Trim(lines[lineIdx]), 1, Length(key) + 1), key + '=');
   end;

   // Move `key` to sit directly after (afterAnchor=True) or directly before
   // (afterAnchor=False) `anchor`.  A missing key or anchor is a no-op.  One
   // delete + one insert inside the section leaves its length unchanged, so
   // sectStart/sectEnd stay valid across successive moves.
   procedure MoveKey(const key, anchor: string; afterAnchor: Boolean);
   var
      keyIdx, anchorIdx, j: integer;
      s: string;
   begin
      keyIdx := -1;
      anchorIdx := -1;
      for j := sectStart to sectEnd do
         begin
         if KeyLine(key, j) then
            begin
            keyIdx := j;
            end;
         if KeyLine(anchor, j) then
            begin
            anchorIdx := j;
            end;
         end;
      if (keyIdx < 0) or (anchorIdx < 0) then
         begin
         Exit;
         end;
      if (afterAnchor and (keyIdx = anchorIdx + 1)) or
         ((not afterAnchor) and (keyIdx = anchorIdx - 1)) then
         begin
         Exit;   // already in place
         end;
      s := lines[keyIdx];
      lines.Delete(keyIdx);
      if keyIdx < anchorIdx then
         begin
         Dec(anchorIdx);
         end;
      if afterAnchor then
         begin
         lines.Insert(anchorIdx + 1, s);
         end
      else
         begin
         lines.Insert(anchorIdx, s);
         end;
      changed := True;
   end;

begin
   // Flush the profile cache so the file reflects every write made above.
   Windows.WritePrivateProfileStringA(nil, nil, nil, TR4W_INI_FILENAME);
   lines := TStringList.Create;
   try
      try
         lines.LoadFromFile(string(PAnsiChar(@TR4W_INI_FILENAME)), TEncoding.ANSI);
      except
         Exit;   // unreadable ini -- grouping is cosmetic, never fatal
      end;
      // Find the [Radio] section bounds.
      sectStart := -1;
      sectEnd := lines.Count - 1;
      for i := 0 to lines.Count - 1 do
         begin
         if SameText(Trim(lines[i]), '[Radio]') then
            begin
            sectStart := i + 1;
            end
         else if (sectStart >= 0) and (Copy(Trim(lines[i]), 1, 1) = '[') then
            begin
            sectEnd := i - 1;
            Break;
            end;
         end;
      if sectStart < 0 then
         begin
         Exit;
         end;
      changed := False;
      // SERIAL FORMAT belongs with the port settings, right after the baud.
      MoveKey('RADIO ONE SERIAL FORMAT', 'RADIO ONE BAUD RATE', True);
      MoveKey('RADIO TWO SERIAL FORMAT', 'RADIO TWO BAUD RATE', True);
      // HAMLIB ID follows the serial format (both are per-radio link settings).
      MoveKey('RADIO ONE HAMLIB ID', 'RADIO ONE SERIAL FORMAT', True);
      MoveKey('RADIO TWO HAMLIB ID', 'RADIO TWO SERIAL FORMAT', True);
      // The keyer output port heads its radio's keyer group, mirroring the
      // dialog's CW/PTT section order (output port, keyer RTS, keyer DTR).
      MoveKey('KEYER RADIO ONE OUTPUT PORT', 'RADIO ONE KEYER RTS', False);
      MoveKey('KEYER RADIO TWO OUTPUT PORT', 'RADIO TWO KEYER RTS', False);
      if changed then
         begin
         lines.SaveToFile(string(PAnsiChar(@TR4W_INI_FILENAME)), TEncoding.ANSI);
         end;
   finally
      lines.Free;
   end;
end;

// Cross-radio serial port conflict check, run BEFORE the dialog commits.
// Returns True when the ports chosen in the dialog may be applied: either they
// do not collide with the OTHER radio's ports, or the operator saw the named
// conflict and chose to apply anyway (swapping ports between the radios has to
// pass through a conflicting state, so a hard block would trap them).
// Returning False cancels the commit AND KEEPS THE DIALOG OPEN so the port can
// be corrected on the spot -- the first version warned from inside the commit
// path, after which OK closed the dialog with the conflict already applied
// (NY4I bench).  Sharing CAT and keyer on the SAME radio is legitimate
// (keying DTR/RTS on the CAT port) and is deliberately not flagged.
function ConfirmPortConflicts(hwnddlg: HWND): Boolean;
var
   otherRadio: RadioPtr;
   otherPrefix: string;
   conflicts: string;

   procedure CheckPort(chosen: PortType);
   var
      othersUse: string;
   begin
      if not (chosen in SerialPorts) then
         begin
         Exit;
         end;
      othersUse := '';
      if chosen = otherRadio^.tCATPortType then
         begin
         othersUse := otherPrefix + ' CONTROL PORT';
         end
      else if chosen = otherRadio^.tKeyerPort then
         begin
         othersUse := 'KEYER ' + otherPrefix + ' OUTPUT PORT';
         end;
      if othersUse <> '' then
         begin
         if conflicts <> '' then
            begin
            conflicts := conflicts + #13#10;
            end;
         conflicts := conflicts + SysUtils.Format(TC_PORT_CONFLICT_DIALOG,
            [string(AnsiString(PortTypeSA[chosen])), othersUse]);
         end;
   end;

begin
   Result := True;
   if CATWTR = @Radio1 then
      begin
      otherRadio := @Radio2;
      otherPrefix := 'RADIO TWO';
      end
   else
      begin
      otherRadio := @Radio1;
      otherPrefix := 'RADIO ONE';
      end;
   conflicts := '';
   CheckPort(ComboSelectedPort(hwnddlg, 122));
   CheckPort(ComboSelectedPort(hwnddlg, 123));
   if conflicts = '' then
      begin
      Exit;
      end;
   logger.Warn('[ConfirmPortConflicts] ' + conflicts);
   Result := MessageBoxA(hwnddlg,
      PAnsiChar(AnsiString(conflicts + #13#10#13#10 + TC_PORT_CONFLICT_PROCEED)),
      'TR4W',
      MB_YESNO or MB_ICONWARNING or MB_DEFBUTTON2) = IDYES;
end;

procedure RestartPollingThread(CATWndHWND: HWND);
var
  lpExitCode                            : DWORD;
  i                                     : integer;
  ID, CMD                               : ShortString;
  sel                                   : integer;
begin

{ TODO: The radio settings changed so restart the thread. If there was a network connection, we have to disconnect and clean that up.
Otherwise, we have to start that up.
}

if (CATWTR^.tCATPortHandle <> INVALID_HANDLE_VALUE) or
   (CATWTR^.tCATPortType = Network)                 then
  begin

    GetExitCodeThread(CATWTR^.tRadioInterfaceThreadHandle, lpExitCode);
    Windows.TerminateThread(CATWTR^.tRadioInterfaceThreadHandle, lpExitCode);
    logger.Info('Terminated Radio %s thread',[CATWTR^.RadioName] );
    CloseCATAndKeyerForThisRadio;
  end;

  { Labels 101-111 come from the resource file. Value controls have IDs = label
    ID + 20 (121-131). The label text (already prefixed with "RADIO ONE/TWO "
    at init) is used as the config command name passed to CheckCommand.
    Username (132) and password (133) are saved explicitly below.
    }
  for i := 101 to 111 do
  begin
    Windows.ZeroMemory(@ID, SizeOf(ID));
    Windows.ZeroMemory(@CMD, SizeOf(CMD));
    ID := GetDialogItemText(CATWndHWND, i);
    CMD := GetDialogItemText(CATWndHWND, i + 20);
    // Controls whose DISPLAYED text is friendly rather than canonical emit
    // their config value from the row's ITEM DATA instead of what is drawn:
    //   101/121 radio type -- shows 'Icom IC-7300MK2', config wants 'IC7300MK2'
    //   102/122, 103/123 ports -- show 'SERIAL 14 - Silicon Labs CP210x',
    //     config wants 'SERIAL 14' (CheckCommand matches against PortTypeSA).
    if i = 101 then
       begin
       // For a string-id factory radio ComboSelectedRadioModel resolves to
       // NoInterfacedRadio => TYPE=NONE, matching the FACTORY ID block below.
       Windows.ZeroMemory(@CMD, SizeOf(CMD));
       CMD := ShortString(AnsiString(
          InterfacedRadioTypeSA[ComboSelectedRadioModel(CATWndHWND)]));
       end;
    if (i = 102) or (i = 103) then
       begin
       // ZeroMemory FIRST -- this is not belt-and-braces, it is required.
       // CMD is a ShortString, and the line below is written out by
       // WritePrivateProfileStringA as @CMD[1], i.e. as a NULL-TERMINATED
       // PAnsiChar.  Assigning a SHORTER value only updates the length byte and
       // the leading characters; the tail of the previous, longer value survives.
       // So 'SERIAL 17' assigned over 'SERIAL 17 - USB-CI-V (COM17)' logs as
       // 'SERIAL 17' (logger honours the length byte) while the ini receives the
       // whole leftover string -- which is exactly the corruption seen in
       // testing, and why the trace and the file disagreed.
       Windows.ZeroMemory(@CMD, SizeOf(CMD));
       CMD := ShortString(StrPas(PortTypeSA[ComboSelectedPort(CATWndHWND, i + 20)]));
       end;
    logger.Trace('[RestartPollingThread] ID = %s, CMD = %s',[ID, CMD]);
    Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
//    if not
    CheckCommand(@ID, CMD)
//    then      showwarning(@id[1])
    ;
  end;

  // Radio identity (Stage 2 string-id factory radios).  The TYPE row already
  // committed the canonical enum name from item data (NONE for a string-id
  // radio).  Here: write FACTORY ID for a string-id selection, or delete any
  // stale FACTORY ID key for an enum radio.
  sel := ComboSelectedFactoryIdIndex(CATWndHWND);
  Windows.ZeroMemory(@ID, SizeOf(ID));
  Windows.ZeroMemory(@CMD, SizeOf(CMD));
  if CATWTR = @Radio1 then
     begin
     ID := 'RADIO ONE FACTORY ID';
     end
  else
     begin
     ID := 'RADIO TWO FACTORY ID';
     end;
  if (sel >= 0) and Assigned(gComboFactoryIds) and (sel < gComboFactoryIds.Count) then
     begin
     CMD := gComboFactoryIds[sel];
     Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
     CheckCommand(@ID, CMD);
     end
  else
     begin
     // enum radio -- delete any stale FACTORY ID key; clear it in memory.
     Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);
     CheckCommand(@ID, CMD);
     end;

  // This handles a checkbox for USE HAMLIB but could be used for any checkbox configuration item. ny4i
  i := 1000;
  Windows.ZeroMemory(@ID, SizeOf(ID));
  Windows.ZeroMemory(@CMD, SizeOf(CMD));
  ID := GetDialogItemText(CATWndHWND, i);
  if boolean(TF.SendDlgItemMessage(CATWndHWND, i, BM_GETCHECK)) then
     begin
     CMD := 'TRUE';
     end
  else
     begin
     CMD := 'FALSE';
     end;

  logger.Trace('[RestartPollingThread] ID = %s, CMD = %s',[ID, CMD]);
  Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
  CheckCommand(@ID, CMD);


  // Save NETWORK USERNAME (control 132) and PASSWORD (control 133)
  // explicitly -- these use short display labels, so command names are hardcoded.
  // Issue #904: write the canonical NETWORK names; migrate legacy
  // "ICOM NETWORK ..." keys by deleting them (CFGCA still parses the old
  // names from any .cfg / .ini files that still have them).
  Windows.ZeroMemory(@ID, SizeOf(ID));
  Windows.ZeroMemory(@CMD, SizeOf(CMD));
  if CATWTR = @Radio1 then
     ID := 'RADIO ONE NETWORK USERNAME'
  else
     ID := 'RADIO TWO NETWORK USERNAME';
  CMD := GetDialogItemText(CATWndHWND, 132);
  Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
  CheckCommand(@ID, CMD);
  // Delete the legacy ICOM NETWORK USERNAME key (nil value = delete).
  if CATWTR = @Radio1 then
     ID := 'RADIO ONE ICOM NETWORK USERNAME'
  else
     ID := 'RADIO TWO ICOM NETWORK USERNAME';
  Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);

  Windows.ZeroMemory(@ID, SizeOf(ID));
  Windows.ZeroMemory(@CMD, SizeOf(CMD));
  if CATWTR = @Radio1 then
     ID := 'RADIO ONE NETWORK PASSWORD'
  else
     ID := 'RADIO TWO NETWORK PASSWORD';
  CMD := GetDialogItemText(CATWndHWND, 133);
  Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
  CheckCommand(@ID, CMD);
  // Delete the legacy ICOM NETWORK PASSWORD key.
  if CATWTR = @Radio1 then
     ID := 'RADIO ONE ICOM NETWORK PASSWORD'
  else
     ID := 'RADIO TWO ICOM NETWORK PASSWORD';
  Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);

  // Save the DATA/PARITY/STOP combo (runtime-created, so outside the 101..111
  // label loop) explicitly.  CheckAndInitializePorts below re-runs
  // ResolveSerialFrameSettings, which applies the new value to the connection.
  Windows.ZeroMemory(@ID, SizeOf(ID));
  Windows.ZeroMemory(@CMD, SizeOf(CMD));
  if CATWTR = @Radio1 then
     begin
     ID := 'RADIO ONE SERIAL FORMAT';
     end
  else
     begin
     ID := 'RADIO TWO SERIAL FORMAT';
     end;
  CMD := GetDialogItemText(CATWndHWND, SERIALFMT_COMBO_ID);
  logger.Trace('[RestartPollingThread] ID = %s, CMD = %s', [ID, CMD]);
  Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
  CheckCommand(@ID, CMD);

  // Save the HAMLIB ID edit only when it is the OPERATOR'S value -- i.e. the
  // selection is HamLib-any.  For every other selection the edit shows a
  // greyed informational number that must not overwrite the config.
  if ComboSelectedRadioModel(CATWndHWND) = HAMLIBANY then
     begin
     Windows.ZeroMemory(@ID, SizeOf(ID));
     Windows.ZeroMemory(@CMD, SizeOf(CMD));
     if CATWTR = @Radio1 then
        begin
        ID := 'RADIO ONE HAMLIB ID';
        end
     else
        begin
        ID := 'RADIO TWO HAMLIB ID';
        end;
     CMD := GetDialogItemText(CATWndHWND, HAMLIBID_EDIT_ID);
     logger.Trace('[RestartPollingThread] ID = %s, CMD = %s', [ID, CMD]);
     Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
     CheckCommand(@ID, CMD);
     end;
  GroupRadioIniKeys;

  CATWTR^.CheckAndInitializePorts_ForThisRadio;
  InitializeKeyer;
//  tActiveKeyerHandle := ActiveRadioPtr.tKeyerPortHandle;
  DisplayRadio(ActiveRadio);
end;

end.

