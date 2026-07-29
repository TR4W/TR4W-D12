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
         'Icom IC-718', [rlSerial], 0, False);

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

// Enum-based registration -- for radios that still carry an InterfacedRadioType
// member.  The string id is derived from the enum member name.
procedure RegisterRadio(model: InterfacedRadioType;
                        const ctor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean); overload;

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
                        discoverable: Boolean); overload;

// String-id registration -- for a NEW factory radio with no InterfacedRadioType
// member.  Its RadioModel is the sentinel NoInterfacedRadio.
procedure RegisterRadioById(const id: string;
                            const ctor: TRadioCtor;
                            const displayName: string;
                            links: TRadioLinks;
                            networkPort: integer;
                            discoverable: Boolean);

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
   Generics.Collections, TypInfo;

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
   end;

var
   gById: TDictionary<string, TRadioReg>;      // primary index
   gByModel: TDictionary<InterfacedRadioType, string>;   // enum -> id (bridge)
   gOrder: TList<string>;                       // ids in registration order (drop-down)

// ---- registration ----------------------------------------------------------

procedure DoRegister(const id: string; model: InterfacedRadioType;
                     const ctor: TRadioCtor; const serialCtor: TRadioCtor;
                     const displayName: string;
                     links: TRadioLinks; networkPort: integer; discoverable: Boolean);
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
                        discoverable: Boolean);
begin
   // Derive the string id from the enum member name (IC718 -> 'IC718').
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              ctor, nil, displayName, links, networkPort, discoverable);
end;

procedure RegisterRadio(model: InterfacedRadioType;
                        const networkCtor: TRadioCtor;
                        const serialCtor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean);
begin
   DoRegister(GetEnumName(TypeInfo(InterfacedRadioType), Ord(model)), model,
              networkCtor, serialCtor, displayName, links, networkPort, discoverable);
end;

procedure RegisterRadioById(const id: string;
                            const ctor: TRadioCtor;
                            const displayName: string;
                            links: TRadioLinks;
                            networkPort: integer;
                            discoverable: Boolean);
begin
   DoRegister(id, NoInterfacedRadio, ctor, nil, displayName, links, networkPort, discoverable);
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
   gById := TDictionary<string, TRadioReg>.Create;
   gByModel := TDictionary<InterfacedRadioType, string>.Create;
   gOrder := TList<string>.Create;

finalization
   gOrder.Free;
   gByModel.Free;
   gById.Free;

end.
