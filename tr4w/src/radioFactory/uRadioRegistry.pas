{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
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
unit uRadioRegistry;

{
  Radio Registry -- single source of truth for factory radio construction.

  Each factory radio unit registers itself here in its `initialization` section:

      RegisterRadio(IC718,
         function: TFactoryRadioBase begin Result := TIcom718Radio.Create end,
         'Icom IC-718', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     );

  The registration is a CONSTRUCTOR FUNCTION, not a class reference, on purpose:
  a per-model subclass registers `... begin Result := TIcom718Radio.Create end`,
  while a future data-driven common-case radio can register
  `... begin Result := TIcomRadio.CreateConfigured(caps) end` -- same entry type.

  IDENTITY (two indices, one entry):
    - Every radio has a STRING id -- its stable, self-declared name.  A radio that
      still has an InterfacedRadioType member registers with RegisterRadio(<enum>,
      ...) and the id is derived from the enum member name (IC718 -> 'IC718') via
      RTTI, so the existing registrations need no id literal.
    - A NEW radio with no InterfacedRadioType member registers with
      RegisterRadioById('MYID', ...); its in-memory RadioModel is the sentinel
      NoInterfacedRadio, so the legacy `RadioModel in [...]` gates all skip it.
  The registry indexes by BOTH id (primary) and enum (bridge for the legacy
  path).  The enum-facing lookups exist so the factory + LOGRADIO connect path
  keep working unchanged while the drop-down/config migrate to the id.

  networkPort/discoverable feed TRadioFactory's DefaultNetworkPort /
  IsNetworkModel / IsDiscoverable.
}

interface

uses
   uFactoryRadioBase, VC;

type
   // Re-export the factory radio base type so a registrant unit needs only
   // `uses uRadioRegistry` to name the constructor's return type.
   TFactoryRadioBase = uFactoryRadioBase.TFactoryRadioBase;

   // A factory radio is created by invoking its registered constructor function.
   TRadioCtor = reference to function: TFactoryRadioBase;

   // Which transports the factory can build this radio for.  A radio configured
   // on the "wrong" transport (e.g. a network-only Kenwood on a serial port)
   // falls back to the legacy CAT path, exactly as before the registry.
   TRadioLink = (rlSerial, rlNetwork);
   TRadioLinks = set of TRadioLink;

   // ---- SERIAL PORT DEFAULTS -----------------------------------------------
   // Every radio states ALL FOUR values explicitly, even when they match the
   // common 4800/8/N/2.  Stating only the deviations would hide the obvious:
   // a reader could not tell "this radio wants the common settings" from
   // "nobody has looked this up yet", and the ones that DO deviate would be
   // invisible until something misbehaved on the wire.
   //
   // These are DEFAULTS, not the values used.  The dialog seeds its controls
   // from them when the operator picks a radio, and whatever ends up in the
   // config is what CreateRadioSerial actually applies.
   //
   // They live here, not on the radio class, because the dialog must show them
   // for a model the operator is SELECTING -- before any radio object exists.
   // Keeping all four in one place beats splitting them between the registry
   // and the constructors.
   //
   // Replaces LOGRADIO's `if RadioModel in [IC78..IC9700, FT100, Orion] then 1
   // else 2`.  That construct was correct (the range means "the Icoms", with
   // non-Icom exceptions named explicitly), but membership of a set is a poor
   // way to carry a per-radio hardware fact: the Omni VI needs 1 stop bit per
   // its manual and was simply never added to the exception list.  A radio that
   // states its own parameters cannot be forgotten in that way.
   TSerialParams = record
      baud:     Integer;
      dataBits: Byte;
      parity:   Byte;    // Win32 values; serialParity on the radio is a Byte too
      stopBits: Byte;
   end;

const
   PARITY_NONE = 0;
   PARITY_ODD  = 1;
   PARITY_EVEN = 2;

   // ---- CAPABILITY MEMBERS, RE-EXPORTED ------------------------------------
   // A radio unit needs only `uses uRadioRegistry` to declare its capabilities.
   //
   // Delphi does NOT re-export enum MEMBERS through a type alias: aliasing
   // TRadioCapability makes the type nameable but leaves rcCWByCAT undefined in
   // the using unit.  Every Icom model unit uses `uRadioIcomBase, VC,
   // uRadioRegistry` and none of them uses uFactoryRadioBase directly, so a first
   // attempt at declaring capabilities in those units failed with
   // "E2003 Undeclared identifier: 'rcCWByCAT'".  Aliasing the members as typed
   // constants fixes it in ONE place instead of editing 25 unit headers.
   rcReadVFOB           = uFactoryRadioBase.rcReadVFOB;
   rcReadRIT            = uFactoryRadioBase.rcReadRIT;
   rcReadSplit          = uFactoryRadioBase.rcReadSplit;
   rcReadTXStatus       = uFactoryRadioBase.rcReadTXStatus;
   rcDataMode           = uFactoryRadioBase.rcDataMode;
   rcCWByCAT            = uFactoryRadioBase.rcCWByCAT;
   rcPlayDVK            = uFactoryRadioBase.rcPlayDVK;
   rcCWFlushDisruptsTiming = uFactoryRadioBase.rcCWFlushDisruptsTiming;
   rcCWSpeedSync        = uFactoryRadioBase.rcCWSpeedSync;
   rcSharedRITXITOffset = uFactoryRadioBase.rcSharedRITXITOffset;

// Reads as SerialParams(4800, 8, PARITY_NONE, 2) at each registration.
function SerialParams(baud: Integer; dataBits, parity, stopBits: Byte): TSerialParams;

// Enum-based registration -- for radios that still carry an InterfacedRadioType
// member.  The string id is derived from the enum member name.
procedure RegisterRadio(model: InterfacedRadioType;
                        const ctor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean;
                        const serial: TSerialParams); overload;

// Two-constructor registration -- ONE radio in the list, but a different driver
// class per transport.  Needed only when the two links speak genuinely different
// PROTOCOLS, not merely different pipes.
//
// Almost no radio needs this.  An IC-7610 speaks CI-V whether the bytes arrive
// over a COM port or TCP 50001, so it registers one ctor and the base class picks
// the transport (uFactoryRadioBase.Connect / SendToRadio).  That is the rule:
// one class = one protocol, the base owns the transport.
//
// FlexRadio is the exception: TCP 4992 is the SmartSDR Ethernet API (sequence
// numbers, client handle, status subscriptions) while the serial/5002 CAT port
// speaks Kenwood-style ZZ commands.  Two protocols, so two classes -- rather than
// one class that switches protocol on transport, which no other driver does.
procedure RegisterRadio(model: InterfacedRadioType;
                        const networkCtor: TRadioCtor;
                        const serialCtor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean;
                        const serial: TSerialParams); overload;

// String-id registration -- for a NEW factory radio with no InterfacedRadioType
// member.  Its RadioModel is the sentinel NoInterfacedRadio.
procedure RegisterRadioById(const id: string;
                            const ctor: TRadioCtor;
                            const displayName: string;
                            links: TRadioLinks;
                            networkPort: integer;
                            discoverable: Boolean;
                            const serial: TSerialParams);

// Enum-facing lookups (used by the factory + LOGRADIO connect path).
function IsRegistered(model: InterfacedRadioType): Boolean;
function SupportsSerial(model: InterfacedRadioType): Boolean;
function SupportsNetwork(model: InterfacedRadioType): Boolean;
function CreateInstance(model: InterfacedRadioType): TFactoryRadioBase;
// Transport-aware construction.  Identical to CreateInstance for every radio
// registered with a single ctor; only a two-ctor registration differs.
function CreateInstanceForLink(model: InterfacedRadioType; link: TRadioLink): TFactoryRadioBase;
function CreateInstanceForLinkId(const id: string; link: TRadioLink): TFactoryRadioBase;
function DisplayName(model: InterfacedRadioType): string;
function RegisteredNetworkPort(model: InterfacedRadioType): integer;
function RegisteredDiscoverable(model: InterfacedRadioType): Boolean;
// Default serial port settings for a model.  The radio dialog seeds its baud /
// data / parity / stop controls from these when the operator picks a radio.
// ---- CAPABILITIES BY MODEL, WITHOUT AN INSTANCE ----------------------------
// Capabilities live on the radio OBJECT (set in its constructor, possibly via the
// DefineCapabilities virtual), so the class stays the single source of truth.  But
// the callers that need them hold a LEGACY RadioObject, not a factory object:
// MainUnit's IsCWByCATActive, MainUnit's DVK check, LOGSUBS1's CW-flush guard.  A
// radio still on the legacy path has no factory object at all.
//
// So this builds ONE throwaway instance per model, on first ask, and remembers the
// answer.  Constructing a factory radio is side-effect free -- the constructor
// opens no port; Connect does -- and the cache means it happens at most once per
// model for the life of the process.  That matters: LOGSUBS1's caller is
// FlushCWBuffer, which runs on every function-key press.
function CapabilitiesFor(model: InterfacedRadioType): TRadioCapabilitySet;
// Convenience: `SupportsFor(m, rcCWByCAT)`.  False for an unregistered model,
// which is correct -- a radio the factory does not know cannot promise anything.
function SupportsFor(model: InterfacedRadioType; cap: TRadioCapability): Boolean;

function SerialParamsFor(model: InterfacedRadioType): TSerialParams;
function SerialParamsForId(const id: string): TSerialParams;

// ---- TAXONOMY, DERIVED FROM THE REGISTRY -----------------------------------
// These replace the InitRadios taxonomy sets (HamLibONLYRadios, YaesuRadios).
// The registry is the single source of truth for "what has a native driver":
// every model TR4W can drive natively is registered, so a real model that is
// NOT registered has no native CAT path and can only be driven through HamLib.
// A new HamLib-only model needs no list edit -- not registering it is the fact.
// (uTestRegistryTaxonomy pins this equivalence against the historical set.)
function IsHamLibOnly(model: InterfacedRadioType): Boolean;

// First word of the registered display name ('Yaesu FT-817' -> 'Yaesu').  The
// display names already state the manufacturer once per radio, so no separate
// per-registration manufacturer field is needed.  '' for an unregistered model
// -- a HamLib-only radio has no registration and therefore no manufacturer
// here; callers that care about those must handle '' explicitly.
function ManufacturerOf(model: InterfacedRadioType): string;

// Id-facing lookups (used by the drop-down + config).
function IsRegisteredId(const id: string): Boolean;
function SupportsSerialId(const id: string): Boolean;
function SupportsNetworkId(const id: string): Boolean;
function CreateInstanceId(const id: string): TFactoryRadioBase;
function DisplayNameId(const id: string): string;
function RegisteredNetworkPortId(const id: string): integer;
function RegisteredDiscoverableId(const id: string): Boolean;

// id <-> enum bridge and enumeration.
function ModelId(model: InterfacedRadioType): string;         // enum -> id ('' if unregistered)
function ModelForId(const id: string): InterfacedRadioType;   // id -> enum (NoInterfacedRadio if none)
function RegisteredIds: TArray<string>;                       // all ids, in registration order

implementation

uses
   Generics.Collections, TypInfo, SyncObjs;

type
   TRadioReg = record
      id: string;
      model: InterfacedRadioType;   // NoInterfacedRadio for id-only (non-enum) radios
      ctor: TRadioCtor;             // the default/network constructor
      serialCtor: TRadioCtor;       // nil => serial uses ctor as well (the normal case)
      displayName: string;
      links: TRadioLinks;
      networkPort: integer;
      discoverable: Boolean;
      serial: TSerialParams;
   end;

var
   gById: TDictionary<string, TRadioReg>;      // primary index
   gByModel: TDictionary<InterfacedRadioType, string>;   // enum -> id (bridge)
   gOrder: TList<string>;                       // ids in registration order (drop-down)

function SerialParams(baud: Integer; dataBits, parity, stopBits: Byte): TSerialParams;
begin
   Result.baud     := baud;
   Result.dataBits := dataBits;
   Result.parity   := parity;
   Result.stopBits := stopBits;
end;

// ---- registration ----------------------------------------------------------

procedure DoRegister(const id: string; model: InterfacedRadioType;
                     const ctor: TRadioCtor; const serialCtor: TRadioCtor;
                     const displayName: string;
                     links: TRadioLinks; networkPort: integer; discoverable: Boolean;
                     const serial: TSerialParams);
var
   reg: TRadioReg;
begin
   reg.id := id;
   reg.model := model;
   reg.ctor := ctor;
   reg.serialCtor := serialCtor;
   reg.displayName := displayName;
   reg.links := links;
   reg.networkPort := networkPort;
   reg.discoverable := discoverable;
   reg.serial := serial;
   if not gById.ContainsKey(id) then
      begin
      gOrder.Add(id);
      end;
   gById.AddOrSetValue(id, reg);
   if model <> NoInterfacedRadio then
      begin
      gByModel.AddOrSetValue(model, id);
      end;
end;

procedure RegisterRadio(model: InterfacedRadioType;
                        const ctor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean;
                        const serial: TSerialParams);
begin
   // Derive the string id from the enum member name (IC718 -> 'IC718').
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              ctor, nil, displayName, links, networkPort, discoverable, serial);
end;

procedure RegisterRadio(model: InterfacedRadioType;
                        const networkCtor: TRadioCtor;
                        const serialCtor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean;
                        const serial: TSerialParams);
begin
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              networkCtor, serialCtor, displayName, links, networkPort, discoverable, serial);
end;

procedure RegisterRadioById(const id: string;
                            const ctor: TRadioCtor;
                            const displayName: string;
                            links: TRadioLinks;
                            networkPort: integer;
                            discoverable: Boolean;
                            const serial: TSerialParams);
begin
   DoRegister(id, NoInterfacedRadio, ctor, nil, displayName, links, networkPort, discoverable, serial);
end;

// ---- lookup helpers ---------------------------------------------------------

function RegById(const id: string; out reg: TRadioReg): Boolean;
begin
   Result := gById.TryGetValue(id, reg);
end;

function RegByModel(model: InterfacedRadioType; out reg: TRadioReg): Boolean;
var
   id: string;
begin
   Result := gByModel.TryGetValue(model, id) and gById.TryGetValue(id, reg);
end;

// ---- id-facing lookups ------------------------------------------------------

function IsRegisteredId(const id: string): Boolean;
begin
   Result := gById.ContainsKey(id);
end;

function SupportsSerialId(const id: string): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegById(id, reg) and (rlSerial in reg.links);
end;

function SupportsNetworkId(const id: string): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegById(id, reg) and (rlNetwork in reg.links);
end;

function CreateInstanceId(const id: string): TFactoryRadioBase;
var
   reg: TRadioReg;
begin
   Result := nil;
   if RegById(id, reg) and Assigned(reg.ctor) then
      begin
      Result := reg.ctor();
      end;
end;

// Pick the constructor for a transport.  serialCtor is nil for every radio whose
// two links speak the same protocol, so this collapses to reg.ctor.
function CtorForLink(const reg: TRadioReg; link: TRadioLink): TRadioCtor;
begin
   if (link = rlSerial) and Assigned(reg.serialCtor) then
      begin
      Result := reg.serialCtor;
      end
   else
      begin
      Result := reg.ctor;
      end;
end;

function CreateInstanceForLinkId(const id: string; link: TRadioLink): TFactoryRadioBase;
var
   reg: TRadioReg;
   ctor: TRadioCtor;
begin
   Result := nil;
   if RegById(id, reg) then
      begin
      ctor := CtorForLink(reg, link);
      if Assigned(ctor) then
         begin
         Result := ctor();
         end;
      end;
end;

function CreateInstanceForLink(model: InterfacedRadioType; link: TRadioLink): TFactoryRadioBase;
var
   reg: TRadioReg;
   ctor: TRadioCtor;
begin
   Result := nil;
   if RegByModel(model, reg) then
      begin
      ctor := CtorForLink(reg, link);
      if Assigned(ctor) then
         begin
         Result := ctor();
         end;
      end;
end;

function DisplayNameId(const id: string): string;
var
   reg: TRadioReg;
begin
   if RegById(id, reg) then
      begin
      Result := reg.displayName;
      end
   else
      begin
      Result := 'Unknown';
      end;
end;

function RegisteredNetworkPortId(const id: string): integer;
var
   reg: TRadioReg;
begin
   if RegById(id, reg) then
      begin
      Result := reg.networkPort;
      end
   else
      begin
      Result := 0;
      end;
end;

function RegisteredDiscoverableId(const id: string): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegById(id, reg) and reg.discoverable;
end;

// ---- enum-facing lookups (bridge for the legacy path) -----------------------

function IsRegistered(model: InterfacedRadioType): Boolean;
begin
   Result := gByModel.ContainsKey(model);
end;

function SupportsSerial(model: InterfacedRadioType): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegByModel(model, reg) and (rlSerial in reg.links);
end;

function SupportsNetwork(model: InterfacedRadioType): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegByModel(model, reg) and (rlNetwork in reg.links);
end;

function CreateInstance(model: InterfacedRadioType): TFactoryRadioBase;
var
   reg: TRadioReg;
begin
   Result := nil;
   if RegByModel(model, reg) and Assigned(reg.ctor) then
      begin
      Result := reg.ctor();
      end;
end;

function DisplayName(model: InterfacedRadioType): string;
var
   reg: TRadioReg;
begin
   if RegByModel(model, reg) then
      begin
      Result := reg.displayName;
      end
   else
      begin
      Result := 'Unknown';
      end;
end;

function IsHamLibOnly(model: InterfacedRadioType): Boolean;
begin
   // NoInterfacedRadio is "no radio configured", not a radio that needs HamLib.
   Result := (model <> NoInterfacedRadio) and (not IsRegistered(model));
end;

function ManufacturerOf(model: InterfacedRadioType): string;
var
   reg: TRadioReg;
   spacePos: integer;
begin
   Result := '';
   if RegByModel(model, reg) then
      begin
      spacePos := Pos(' ', reg.displayName);
      if spacePos > 0 then
         begin
         Result := Copy(reg.displayName, 1, spacePos - 1);
         end
      else
         begin
         Result := reg.displayName;
         end;
      end;
end;

function RegisteredNetworkPort(model: InterfacedRadioType): integer;
var
   reg: TRadioReg;
begin
   if RegByModel(model, reg) then
      begin
      Result := reg.networkPort;
      end
   else
      begin
      Result := 0;
      end;
end;

// Cache, indexed by the enum: 100-odd members, so an array beats a dictionary.
// Guarded because the first ask can come from the main thread (a function key) or
// the polling thread, and two threads constructing the same radio at once would
// race on the ctor's allocations.
var
   gCapCache: array[InterfacedRadioType] of TRadioCapabilitySet;
   gCapKnown: array[InterfacedRadioType] of Boolean;
   gCapLock: TCriticalSection;

function CapabilitiesFor(model: InterfacedRadioType): TRadioCapabilitySet;
var
   r: TFactoryRadioBase;
begin
   gCapLock.Enter;
   try
      if not gCapKnown[model] then
         begin
         gCapCache[model] := [];
         if IsRegistered(model) then
            begin
            r := CreateInstance(model);
            if r <> nil then
               begin
               try
                  gCapCache[model] := r.Capabilities.Flags;
               finally
                  r.Free;
               end;
               end;
            end;
         gCapKnown[model] := True;
         end;
      Result := gCapCache[model];
   finally
      gCapLock.Leave;
   end;
end;

function SupportsFor(model: InterfacedRadioType; cap: TRadioCapability): Boolean;
begin
   Result := cap in CapabilitiesFor(model);
end;

function SerialParamsForId(const id: string): TSerialParams;
var
   reg: TRadioReg;
begin
   // A model with no registration falls back to what LOGRADIO's else-branch gave
   // every non-Icom: 4800 8 N 2.
   Result := SerialParams(4800, 8, PARITY_NONE, 2);
   if RegById(id, reg) then
      begin
      Result := reg.serial;
      end;
end;

function SerialParamsFor(model: InterfacedRadioType): TSerialParams;
var
   reg: TRadioReg;
begin
   Result := SerialParams(4800, 8, PARITY_NONE, 2);
   if RegByModel(model, reg) then
      begin
      Result := reg.serial;
      end;
end;

function RegisteredDiscoverable(model: InterfacedRadioType): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegByModel(model, reg) and reg.discoverable;
end;

// ---- id <-> enum bridge + enumeration ---------------------------------------

function ModelId(model: InterfacedRadioType): string;
begin
   if not gByModel.TryGetValue(model, Result) then
      begin
      Result := '';
      end;
end;

function ModelForId(const id: string): InterfacedRadioType;
var
   reg: TRadioReg;
begin
   if RegById(id, reg) then
      begin
      Result := reg.model;
      end
   else
      begin
      Result := NoInterfacedRadio;
      end;
end;

function RegisteredIds: TArray<string>;
begin
   Result := gOrder.ToArray;
end;

initialization
   gCapLock := TCriticalSection.Create;
   gById := TDictionary<string, TRadioReg>.Create;
   gByModel := TDictionary<InterfacedRadioType, string>.Create;
   gOrder := TList<string>.Create;

finalization
   gOrder.Free;
   gByModel.Free;
   gById.Free;

end.
