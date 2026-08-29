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
{$I tr4w.inc}
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
  uIcomNetworkTypes,
  uTR4WStrings,
  uAnsiStr,
  LCLStrConsts;

procedure CloseCATAndKeyerForThisRadio;
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


var
  // The radio currently being configured.  Still live: uRadioConfigApply sets
  // it around a slot apply, which is how the surviving helpers here know which
  // radio they are working on.
  CATWTR                                : RadioPtr {= @Radio1};

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
  // as item data, and the commit maps the index back to the registry id.
  gComboFactoryIds: TStringList = nil;


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


// Stamp the DIALOG's own font (WM_GETFONT -- what the dialog manager gave every
// template control) on a runtime-created control.  The generic creation helpers
// (CreateStatic/CreateEdit/CreateButton/tCreate*Window) stamp MSSansSerifFont,
// which tr4w.lpr creates at 15px -- LARGER than the ~13px derived from the
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




// Fill a port combo: NONE, the serial ports Windows reports right now, the
// configured port when it is NOT present, then the non-serial options.
//
// The configured-but-absent entry matters: someone who unplugs a USB adapter
// should not have their saved choice silently vanish from the dialog, which
// would look like TR4W forgetting the setting (docs\COMPort_Persistence.md).
// It is labelled so the list never claims a missing device is available.
procedure PopulatePortCombo(hwnddlg: HWND; ctl: integer; configured: PortType); forward;


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


// The DATA/PARITY/STOP row (label 151, combo 152) and the HAMLIB ID row (label
// 153, edit 154) stood here as runtime-built control rows, with their ids and
// the twelve frame strings as constants.  Both went with the dialog on
// 2026-08-29: they were built by AddSerialFormatRow and AddHamLibIDRow into a
// template that no longer exists.
//
// The technique is worth remembering even though the code is gone.  Those rows
// were assembled at RUNTIME because the per-language dialog templates were
// sourceless binary .res files -- adding one control to the design meant
// hand-editing eleven of them.  A designed .lfm has neither problem, which is
// most of the argument for the conversion.


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



end.

