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
{$I ..\tr4w.inc}

{
  Radio Registry -- single source of truth for factory radio construction.

  Each factory radio unit registers itself here in its `initialization` section:

      RegisterRadio(IC718,
         function: TFactoryRadioBase begin Result := TIcom718Radio.Create end,
         'Icom IC-718', [rlSerial], 0, False,
     SerialParams(1200, 8, PARITY_NONE, 1)
     ,
     3013
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
   //
   // A PLAIN procedure pointer, not `reference to`.  All 101 registrations name
   // a unit-level function that captures nothing -- the anonymous form bought
   // nothing here and cost a closure-capable compiler (FPC 3.2.2 stable has
   // none).  Same change, same reasoning, as the rotator factory.
   TRadioCtor = function: TFactoryRadioBase;

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
                        const serial: TSerialParams;
                        hamlibID: Integer = 0;
                        civAddress: Byte = 0); overload;

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
                        const serial: TSerialParams;
                        hamlibID: Integer = 0;
                        civAddress: Byte = 0); overload;

// String-id registration -- for a NEW factory radio with no InterfacedRadioType
// member.  Its RadioModel is the sentinel NoInterfacedRadio.
procedure RegisterRadioById(const id: string;
                            const ctor: TRadioCtor;
                            const displayName: string;
                            links: TRadioLinks;
                            networkPort: integer;
                            discoverable: Boolean;
                            const serial: TSerialParams);

// HamLib-only registration -- a model with NO native TR4W driver, driven
// through THamLibDirect (the software bridges FLRig/TRXManager/TCI/ACLog/
// rigctl-any, plus real rigs whose only driver is a HamLib backend).  The
// ctor should return a THamLibDirect preconfigured with hamlibID; the row is
// flagged hamlibOnly, which IsHamLibOnly and the CAT dialog read.  Links are
// fixed [rlSerial, rlNetwork]: HamLib itself decides transport per rig.
procedure RegisterHamLibOnlyRadio(model: InterfacedRadioType;
                                  const ctor: TRadioCtor;
                                  const displayName: string;
                                  hamlibID: Integer;
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

// THE ID-KEYED FORM, and it is not a convenience -- it is the one that is
// CORRECT for every registered radio.  CapabilitiesFor/SupportsFor take an
// InterfacedRadioType, so a STRING-ID radio (TCI has no enum member) resolves to
// NoInterfacedRadio and answers False to everything.  That is exactly how TCI
// once ended up with no CW at all: the CW-by-CAT gate was model-keyed.  Anything
// asking "can this radio do X" from a registry id must come through here.
function CapabilitiesForId(const id: string): TRadioCapabilitySet;
function SupportsForId(const id: string; cap: TRadioCapability): Boolean;

function SerialParamsFor(model: InterfacedRadioType): TSerialParams;
function SerialParamsForId(const id: string): TSerialParams;

// ---- TAXONOMY, DERIVED FROM THE REGISTRY -----------------------------------
// These replace the InitRadios taxonomy sets (HamLibONLYRadios, YaesuRadios).
// The registry is the single source of truth.  HamLib-only models (no native
// TR4W driver -- the software bridges, plus rigs whose only driver is a HamLib
// backend) REGISTER like every other radio, via RegisterHamLibOnlyRadio in
// uRadioHamLibOnly.pas, carrying their default HamLib rig_model; IsHamLibOnly
// reads that registration FLAG.  (Before 2026-07-30 the derivation was "not
// registered = HamLib-only"; registering the bridges so the radio drop-down
// can be built from the registry required the explicit flag.
// uTestRegistryTaxonomy still pins the answer against the historical set.)
function IsHamLibOnly(model: InterfacedRadioType): Boolean;

// The registration's default HamLib rig_model (riglist.h numbering).  0 when
// the model is not registered or carries no ID; for HAMLIBANY the meaningful
// ID always comes from the RADIO n HAMLIB ID config command instead.
function RegisteredHamLibID(model: InterfacedRadioType): Integer;

// The model's default Icom CI-V receiver address; 0 for anything that is not a
// CI-V radio.  The operator can still override it with RADIO n RECEIVER
// ADDRESS -- this is only the default that command starts from.
function RegisteredCIVAddress(model: InterfacedRadioType): Byte;

// First word of the registered display name ('Yaesu FT-817' -> 'Yaesu').  The
// display names already state the manufacturer once per radio, so no separate
// per-registration manufacturer field is needed.  '' for an unregistered model
// -- a HamLib-only radio has no registration and therefore no manufacturer
// here; callers that care about those must handle '' explicitly.
function ManufacturerOf(model: InterfacedRadioType): string;

// ---- SERIAL FRAME FORMAT ('8N2') -------------------------------------------
// The compact terminal-program notation for data bits / parity / stop bits:
// digit 7 or 8, parity letter N/O/E, digit 1 or 2.  Used by the radio dialog's
// DATA/PARITY/STOP combo and the 'RADIO ONE/TWO SERIAL FORMAT' config command.
// The parity byte is the Win32 value (PARITY_NONE/ODD/EVEN above) -- callers on
// the legacy path must convert to/from Tree.ParityType, whose ordinals differ
// (legacy 1 = even, 2 = odd; Win32 1 = odd, 2 = even).
function SerialFormatToString(dataBits, parity, stopBits: Byte): string;
function TryParseSerialFormat(const s: string;
                              out dataBits, parity, stopBits: Byte): Boolean;

// Id-facing lookups (used by the drop-down + config).
function IsRegisteredId(const id: string): Boolean;
function SupportsSerialId(const id: string): Boolean;
function SupportsNetworkId(const id: string): Boolean;
function CreateInstanceId(const id: string): TFactoryRadioBase;
function DisplayNameId(const id: string): string;
function RegisteredNetworkPortId(const id: string): integer;
function RegisteredDiscoverableId(const id: string): Boolean;

{ Does this radio's NETWORK link authenticate -- should a UI offer user+password?

  NOT the same question as "is it a network radio". The Elecraft K4 is reached
  over TCP 9200 with no credentials at all, while every network Icom and the
  Kenwood LAN radios want both. The editor offered the fields to all of them, so
  adding a K4 asked for a username it can never use (NY4I).

  The BEHAVIOUR already existed: ApplyNetworkCredentials is a no-op on
  TFactoryRadioBase and overridden by TIcomRadio and TKenwoodLAN. What was
  missing is a way to ASK before a radio object exists -- and the editor needs
  the answer while the operator is still choosing a model, with no transport to
  construct one with. }
function RegisteredNetworkCredentials(model: InterfacedRadioType): Boolean;
function RegisteredNetworkCredentialsId(const id: string): Boolean;

{ Declare that this radio's network link authenticates. Called from the radio's
  own initialization right after RegisterRadio, so the fact stays in the same
  file as the model: one radio, one unit, one registration. }
procedure MarkNetworkCredentials(const id: string); overload;
procedure MarkNetworkCredentials(model: InterfacedRadioType); overload;

// id <-> enum bridge and enumeration.
function ModelId(model: InterfacedRadioType): string;         // enum -> id ('' if unregistered)
function ModelForId(const id: string): InterfacedRadioType;   // id -> enum (NoInterfacedRadio if none)
function RegisteredIds: TArray<string>;                       // all ids, in registration order

implementation

uses
   SysUtils,   // Trim, for the id-keyed capability lookup
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
      networkCredentials: Boolean;  // the network link authenticates: offer user+password
      serial: TSerialParams;
      hamlibOnly: Boolean;          // True => no native TR4W driver; driven through HamLib
      civAddress: Byte;             // default CI-V receiver address (Icom); 0 = not a CI-V radio
      hamlibID: Integer;            // default HamLib rig_model for hamlibOnly rows
                                    // (the RADIO n HAMLIB ID config command overrides at connect)
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
                     const serial: TSerialParams;
                     hamlibID: Integer = 0;
                     civAddress: Byte = 0);
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
   // OFF unless the radio says otherwise (MarkNetworkCredentials). A radio that
   // authenticates but forgets to declare it shows no credential fields and then
   // simply fails to connect -- which is why the pin test exists rather than a
   // comment asking people to remember.
   reg.networkCredentials := False;
   reg.serial := serial;
   reg.hamlibOnly := False;   // RegisterHamLibOnlyRadio patches this after the call
   // The HamLib rig_model for THIS radio, used when the operator drives an
   // ordinary rig through HamLib ("Use HamLib").  0 means "not stated"; every
   // enum radio should state one, and uTestHamLibIDs pins them against the
   // legacy RadioParametersArray so a transcription slip cannot pass.
   reg.hamlibID := hamlibID;
   // Icom CI-V receiver address.  Per-model DATA -- every CI-V rig has its own
   // default -- so it lives on the registration, not in a table LOGRADIO owns.
   reg.civAddress := civAddress;
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
                        const serial: TSerialParams;
                        hamlibID: Integer = 0;
                        civAddress: Byte = 0);
begin
   // Derive the string id from the enum member name (IC718 -> 'IC718').
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              ctor, nil, displayName, links, networkPort, discoverable, serial,
              hamlibID, civAddress);
end;

procedure RegisterRadio(model: InterfacedRadioType;
                        const networkCtor: TRadioCtor;
                        const serialCtor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean;
                        const serial: TSerialParams;
                        hamlibID: Integer = 0;
                        civAddress: Byte = 0);
begin
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              networkCtor, serialCtor, displayName, links, networkPort, discoverable, serial,
              hamlibID, civAddress);
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

procedure RegisterHamLibOnlyRadio(model: InterfacedRadioType;
                                  const ctor: TRadioCtor;
                                  const displayName: string;
                                  hamlibID: Integer;
                                  const serial: TSerialParams);
var
   id: string;
   reg: TRadioReg;
begin
   id := GetEnumName(TypeInfo(InterfacedRadioType), Ord(model));
   DoRegister(id, model, ctor, nil, displayName, [rlSerial, rlNetwork], 0, False, serial);
   // Patch the hamlib fields onto the stored row (DoRegister defaults them off).
   if gById.TryGetValue(id, reg) then
      begin
      reg.hamlibOnly := True;
      reg.hamlibID := hamlibID;
      gById.AddOrSetValue(id, reg);
      end;
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

function RegisteredNetworkCredentialsId(const id: string): Boolean;
var
   reg: TRadioReg;
begin
   Result := RegById(id, reg) and reg.networkCredentials;
end;

function RegisteredNetworkCredentials(model: InterfacedRadioType): Boolean;
var
   id: string;
begin
   Result := False;
   if gByModel.TryGetValue(model, id) then
      begin
      Result := RegisteredNetworkCredentialsId(id);
      end;
end;

procedure MarkNetworkCredentials(model: InterfacedRadioType);
begin
   // The enum form, so a radio unit writes MarkNetworkCredentials(IC705) instead
   // of spelling the id through TypInfo. The id IS the enum name, and the
   // registry is the one place that should know that.
   //
   // GetEnumName, NOT a call with `model` -- that is a call to THIS procedure and
   // recurses until the stack runs out. It happened: a blanket "simplify the call
   // sites" rewrite included the unit that defines them, and the unit tests died
   // with an access violation before printing a single line.
   MarkNetworkCredentials(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)));
end;

procedure MarkNetworkCredentials(const id: string);
var
   reg: TRadioReg;
begin
   // LOUD if the id is unknown. This is called from a radio's initialization
   // section immediately after its own RegisterRadio, so a miss means the id was
   // mistyped or the calls were ordered wrongly -- and the symptom would
   // otherwise be a radio that silently offers no credential fields and then
   // cannot log in.
   if not gById.TryGetValue(id, reg) then
      begin
      raise Exception.CreateFmt(
         'MarkNetworkCredentials: no radio registered as "%s"', [id]);
      end;

   reg.networkCredentials := True;
   gById.AddOrSetValue(id, reg);
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
var
   reg: TRadioReg;
begin
   // Registration flag (see the interface note): a HamLib-only model registers
   // with RegisterHamLibOnlyRadio and carries hamlibOnly = True.  Everything
   // else -- native radios, NoInterfacedRadio, anything unregistered -- is False.
   Result := RegByModel(model, reg) and reg.hamlibOnly;
end;

function RegisteredHamLibID(model: InterfacedRadioType): Integer;
var
   reg: TRadioReg;
begin
   Result := 0;
   if RegByModel(model, reg) then
      begin
      Result := reg.hamlibID;
      end;
end;

function RegisteredCIVAddress(model: InterfacedRadioType): Byte;
var
   reg: TRadioReg;
begin
   Result := 0;
   if RegByModel(model, reg) then
      begin
      Result := reg.civAddress;
      end;
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

function SerialFormatToString(dataBits, parity, stopBits: Byte): string;
const
   ParityLetter: array[PARITY_NONE..PARITY_EVEN] of Char = ('N', 'O', 'E');
begin
   if (dataBits in [7, 8]) and (parity <= PARITY_EVEN) and (stopBits in [1, 2]) then
      begin
      Result := Chr(Ord('0') + dataBits) + ParityLetter[parity] +
                Chr(Ord('0') + stopBits);
      end
   else
      begin
      Result := '';
      end;
end;

function TryParseSerialFormat(const s: string;
                              out dataBits, parity, stopBits: Byte): Boolean;
begin
   Result := False;
   dataBits := 0;
   parity := 0;
   stopBits := 0;
   if Length(s) <> 3 then
      begin
      Exit;
      end;
   if (s[1] <> '7') and (s[1] <> '8') then
      begin
      Exit;
      end;
   if (s[3] <> '1') and (s[3] <> '2') then
      begin
      Exit;
      end;
   case UpCase(s[2]) of
      'N': parity := PARITY_NONE;
      'O': parity := PARITY_ODD;
      'E': parity := PARITY_EVEN;
   else
      Exit;
   end;
   dataBits := Ord(s[1]) - Ord('0');
   stopBits := Ord(s[3]) - Ord('0');
   Result := True;
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

function CapabilitiesForId(const id: string): TRadioCapabilitySet;
var
   r: TFactoryRadioBase;
   model: InterfacedRadioType;
begin
   Result := [];
   if Trim(id) = '' then
      begin
      Exit;
      end;

   // An enum-backed radio goes through the CACHED path -- CapabilitiesFor
   // constructs one instance per model and remembers the answer.
   model := ModelForId(id);
   if model <> NoInterfacedRadio then
      begin
      Result := CapabilitiesFor(model);
      Exit;
      end;

   // A STRING-ID radio has no enum to cache against, so ask an instance
   // directly. Uncached, but there is exactly one such radio today (TCI) and
   // this is called from dialogs, not from a polling loop.
   if not IsRegisteredId(id) then
      begin
      Exit;
      end;

   r := CreateInstanceId(id);
   if r <> nil then
      begin
      try
         Result := r.Capabilities.Flags;
      finally
         r.Free;
      end;
      end;
end;

function SupportsForId(const id: string; cap: TRadioCapability): Boolean;
begin
   Result := cap in CapabilitiesForId(id);
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
