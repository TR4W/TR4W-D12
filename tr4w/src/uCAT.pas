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
  (* LCLType, not Windows: types and constants only, and Messages
    declared nothing at all (2026-09-08). *)
  LCLType,
  LogRadio,
  LogCW,
  CfgCmd,
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

  (* THE CAT PORT IS THE FACTORY OBJECT'S, and by the time this runs it is
    already closed -- ShutDownRadioInterface above does it. The block that
    stood here also reached into the CW keyer's handle table for a CAT port,
    which was only ever true on the legacy fallback path; that path is gone,
    every radio goes through the factory, and the factory owns its own
    TSerialPort.

    So this closes the KEYER port and nothing else, which is the only thing
    that table has ever legitimately held.

    AND THE LAST LINE OF IT IS GONE TOO (2026-09-08): tCATPortHandle was
    assigned here and in one other place, both to INVALID_HANDLE_VALUE, and
    nothing ever opened it. The field and everything that read it are deleted;
    see the note in logradio. *)

  {Close Keyer Port}
  if CATWTR^.tKeyerPort in SerialPorts then
     begin
     CATWTR^.tKeyerSerialPort := nil;
     FreeAndNil(CPUKeyer.SerialPortObject[CATWTR^.tKeyerPort]);
     end;
  CATWTR^.tKeyerPortHandle := LPT_NO_PORT;   (* an LPT address, not a handle *)

  //  if (RadioToClose^.tr4w_KeyerPort >= Parallel1) and (RadioToClose^.tr4w_KeyerPort <= Parallel3) then    DestroyDlPortio;

end;

(* GroupRadioIniKeys WAS DELETED HERE (2026-09-08) -- it LOADED tr4w.ini,
  re-ordered the keys in its [Radio] section, and SAVED THE FILE BACK.

  The reordering was cosmetic by its own admission ("grouping is cosmetic,
  never fatal"). What made it worth removing is the SAVE. Settings live in
  settings\tr4w.json; what remains of tr4w.ini is a file read ONCE per
  installation to carry an old configuration into the store and never again,
  and a routine that writes it keeps it alive.

  OFF WINDOWS IT WOULD HAVE CREATED ONE, on a platform where no operator has an
  ini to import -- which is the same shape as the binary log: a Windows
  migration artifact that should not follow the program to a new platform.

  NY4I, 2026-09-08: "we really do not need a tr4w.ini." *)

end.

