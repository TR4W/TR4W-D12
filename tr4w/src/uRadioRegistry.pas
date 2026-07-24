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

  The factory (uRadioFactory) and the connect path (LOGRADIO) then look a radio
  up by its InterfacedRadioType -- there is no second enum and no hand-maintained
  case/set to keep in sync.  Adding a radio to the factory is one RegisterRadio
  call in that radio's own unit; routing follows automatically.

  The registration is a CONSTRUCTOR FUNCTION, not a class reference, on purpose:
  a per-model subclass registers `... begin Result := TIcom718Radio.Create end`,
  while a future data-driven common-case radio can register
  `... begin Result := TIcomRadio.CreateConfigured(caps) end` -- same entry type,
  no rework.  The registry never needs to know which of the two it is.

  networkPort/discoverable feed TRadioFactory's DefaultNetworkPort /
  IsNetworkModel / IsDiscoverable (keyed on InterfacedRadioType); the old
  TRadioModel enum has been retired.
}

interface

uses
   uFactoryRadioBase, VC;

type
   // Re-export the factory radio base type so a registrant unit needs only
   // `uses uRadioRegistry` to name the constructor's return type -- it does not
   // also have to pull in uFactoryRadioBase just to spell the closure signature.
   TFactoryRadioBase = uFactoryRadioBase.TFactoryRadioBase;

   // A factory radio is created by invoking its registered constructor function.
   TRadioCtor = reference to function: TFactoryRadioBase;

   // Which transports the factory can build this radio for.  A radio configured
   // on the "wrong" transport (e.g. a network-only Kenwood on a serial port)
   // falls back to the legacy CAT path, exactly as before the registry.
   TRadioLink = (rlSerial, rlNetwork);
   TRadioLinks = set of TRadioLink;

procedure RegisterRadio(model: InterfacedRadioType;
                        const ctor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean);

function IsRegistered(model: InterfacedRadioType): Boolean;
function SupportsSerial(model: InterfacedRadioType): Boolean;
function SupportsNetwork(model: InterfacedRadioType): Boolean;
function CreateInstance(model: InterfacedRadioType): TFactoryRadioBase;
function DisplayName(model: InterfacedRadioType): string;

// Read by TRadioFactory's DefaultNetworkPort / IsNetworkModel / IsDiscoverable.
function RegisteredNetworkPort(model: InterfacedRadioType): integer;
function RegisteredDiscoverable(model: InterfacedRadioType): Boolean;

implementation

uses
   Generics.Collections;

type
   TRadioReg = record
      ctor: TRadioCtor;
      displayName: string;
      links: TRadioLinks;
      networkPort: integer;
      discoverable: Boolean;
   end;

var
   gRegistry: TDictionary<InterfacedRadioType, TRadioReg>;

procedure RegisterRadio(model: InterfacedRadioType;
                        const ctor: TRadioCtor;
                        const displayName: string;
                        links: TRadioLinks;
                        networkPort: integer;
                        discoverable: Boolean);
var
   reg: TRadioReg;
begin
   reg.ctor := ctor;
   reg.displayName := displayName;
   reg.links := links;
   reg.networkPort := networkPort;
   reg.discoverable := discoverable;
   gRegistry.AddOrSetValue(model, reg);
end;

function IsRegistered(model: InterfacedRadioType): Boolean;
begin
   Result := gRegistry.ContainsKey(model);
end;

function SupportsSerial(model: InterfacedRadioType): Boolean;
var
   reg: TRadioReg;
begin
   Result := gRegistry.TryGetValue(model, reg) and (rlSerial in reg.links);
end;

function SupportsNetwork(model: InterfacedRadioType): Boolean;
var
   reg: TRadioReg;
begin
   Result := gRegistry.TryGetValue(model, reg) and (rlNetwork in reg.links);
end;

function CreateInstance(model: InterfacedRadioType): TFactoryRadioBase;
var
   reg: TRadioReg;
begin
   Result := nil;
   if gRegistry.TryGetValue(model, reg) and Assigned(reg.ctor) then
      begin
      Result := reg.ctor();
      end;
end;

function DisplayName(model: InterfacedRadioType): string;
var
   reg: TRadioReg;
begin
   if gRegistry.TryGetValue(model, reg) then
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
   if gRegistry.TryGetValue(model, reg) then
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
   Result := gRegistry.TryGetValue(model, reg) and reg.discoverable;
end;

initialization
   gRegistry := TDictionary<InterfacedRadioType, TRadioReg>.Create;

finalization
   gRegistry.Free;

end.
