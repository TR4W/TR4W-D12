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
unit uRadioFactory;

{
  Radio Factory Pattern Implementation

  Purpose: Centralized creation of radio instances based on model type

  Usage:
    var radio: TFactoryRadioBase;
    radio := TRadioFactory.CreateRadioNetwork(IC7610, '192.168.1.100', 50001);
    radio.Connect;
}

interface

uses
   Windows, uFactoryRadioBase, uRadioElecraftK4, uRadioFlexAPI, SysUtils, VC;

type
   TConnectionType = (ctNetwork, ctSerial);

   TRadioFactory = class
   public
      // Network connection.  Keyed on InterfacedRadioType -- the class, display
      // name and transport come from the radio registry (each radio unit
      // self-registers), so there is no per-model case to maintain here.
      class function CreateRadioNetwork(model: InterfacedRadioType;
                                         address: string;
                                         port: integer): TFactoryRadioBase;
      // Serial connection.  Returns nil for a model whose factory class is not
      // serial-capable, so the caller falls back to the legacy serial path.
      class function CreateRadioSerial(model: InterfacedRadioType;
                                        serialPort: PortType;
                                        baudRate: DWORD;
                                        dataBits: Byte;
                                        stopBits: Byte;
                                        parity: Byte;
                                        rts: Boolean = False;
                                        dtr: Boolean = False): TFactoryRadioBase;
      // HamLib Direct is not an InterfacedRadioType model -- any radio can select
      // it via its UseHamLib flag -- so it has its own constructor.
      class function CreateHamLibDirect(msgCallback: TProcessMsgRef): TFactoryRadioBase;
      // String-id variants -- for a factory radio with no InterfacedRadioType
      // member (registered via RegisterRadioById).  Mirror the enum versions.
      class function CreateRadioNetworkById(const id: string;
                                             address: string;
                                             port: integer): TFactoryRadioBase;
      class function CreateRadioSerialById(const id: string;
                                            serialPort: PortType;
                                            baudRate: DWORD;
                                            dataBits: Byte;
                                            stopBits: Byte;
                                            parity: Byte;
                                            rts: Boolean = False;
                                            dtr: Boolean = False): TFactoryRadioBase;
      class function GetSupportedModels: string;

      // Network metadata (Issue #1028) -- default TCP/UDP port, "is this a network
      // radio", and whether TR4W can auto-discover it on the LAN.  Keyed on
      // InterfacedRadioType; the values come from the radio registry (each radio
      // unit self-registers its port + discoverable flag).
      class function DefaultNetworkPort(model: InterfacedRadioType): integer;
      class function IsNetworkModel(model: InterfacedRadioType): boolean;
      class function IsDiscoverable(model: InterfacedRadioType): boolean;
   end;

   ERadioFactoryException = class(Exception);

implementation

uses Log4D, uRadioRegistry, uRadioHamLibDirect, uRadioIcomBase,
     uRadioIcom7300, uRadioIcom7610, uRadioIcom9700,
     uRadioIcom705, uRadioIcom7300MK2, uRadioIcom7600,
     uRadioIcom7760, uRadioIcom7850, uRadioIcom905, uRadioIcom7100,
     uRadioIcom718,
     uRadioKenwoodLAN, uRadioKenwoodTS890, uRadioKenwoodTS990;  // Issue #436
     // The uRadioIcom*/uRadioKenwood* units above are listed so their
     // initialization sections run and self-register in uRadioRegistry, even
     // though the factory no longer references their classes directly.

var
   logger: TLogLogger;

class function TRadioFactory.CreateRadioNetwork(model: InterfacedRadioType;
                                                 address: string;
                                                 port: integer): TFactoryRadioBase;
begin
   Result := nil;

   if not (uRadioRegistry.IsRegistered(model) and uRadioRegistry.SupportsNetwork(model)) then
      begin
      logger.Warn('[RadioFactory] %s is not a factory network radio',
                  [uRadioRegistry.DisplayName(model)]);
      Exit;
      end;

   Result := uRadioRegistry.CreateInstanceForLink(model, rlNetwork);
   if Result = nil then
      begin
      Exit;
      end;

   Result.radioAddress := address;
   Result.radioPort := port;
   Result.radioModel := uRadioRegistry.DisplayName(model);
   logger.Info('[RadioFactory] Created %s (network): Address=%s, Port=%d',
               [Result.radioModel, address, port]);
end;

class function TRadioFactory.CreateRadioSerial(model: InterfacedRadioType;
                                                serialPort: PortType;
                                                baudRate: DWORD;
                                                dataBits: Byte;
                                                stopBits: Byte;
                                                parity: Byte;
                                                rts: Boolean;
                                                dtr: Boolean): TFactoryRadioBase;
begin
   Result := nil;

   // A model whose factory class is network-only (FlexRadio, the Kenwoods) is
   // not built here -- returning nil sends the caller to the legacy serial path,
   // exactly as before the registry.
   if not (uRadioRegistry.IsRegistered(model) and uRadioRegistry.SupportsSerial(model)) then
      begin
      logger.Warn('[RadioFactory] %s is not a factory serial radio',
                  [uRadioRegistry.DisplayName(model)]);
      Exit;
      end;

   Result := uRadioRegistry.CreateInstanceForLink(model, rlSerial);
   if Result = nil then
      begin
      Exit;
      end;

   Result.serialPort := serialPort;
   Result.serialBaudRate := baudRate;
   Result.serialDataBits := dataBits;
   Result.serialStopBits := stopBits;
   Result.serialParity := parity;
   Result.serialRts := rts;
   Result.serialDtr := dtr;
   Result.radioModel := uRadioRegistry.DisplayName(model);
   logger.Info('[RadioFactory] Created %s (serial): Port=%d, Baud=%d, %dN%d',
               [Result.radioModel, Ord(serialPort), baudRate, dataBits, stopBits]);
end;

class function TRadioFactory.CreateRadioNetworkById(const id: string;
                                                     address: string;
                                                     port: integer): TFactoryRadioBase;
begin
   Result := nil;
   if not (uRadioRegistry.IsRegisteredId(id) and uRadioRegistry.SupportsNetworkId(id)) then
      begin
      Exit;
      end;
   Result := uRadioRegistry.CreateInstanceForLinkId(id, rlNetwork);
   if Result = nil then
      begin
      Exit;
      end;
   Result.radioAddress := address;
   Result.radioPort := port;
   Result.radioModel := uRadioRegistry.DisplayNameId(id);
   logger.Info('[RadioFactory] Created %s (network id): Address=%s, Port=%d',
               [Result.radioModel, address, port]);
end;

class function TRadioFactory.CreateRadioSerialById(const id: string;
                                                    serialPort: PortType;
                                                    baudRate: DWORD;
                                                    dataBits: Byte;
                                                    stopBits: Byte;
                                                    parity: Byte;
                                                    rts: Boolean;
                                                    dtr: Boolean): TFactoryRadioBase;
begin
   Result := nil;
   if not (uRadioRegistry.IsRegisteredId(id) and uRadioRegistry.SupportsSerialId(id)) then
      begin
      Exit;
      end;
   Result := uRadioRegistry.CreateInstanceForLinkId(id, rlSerial);
   if Result = nil then
      begin
      Exit;
      end;
   Result.serialPort := serialPort;
   Result.serialBaudRate := baudRate;
   Result.serialDataBits := dataBits;
   Result.serialStopBits := stopBits;
   Result.serialParity := parity;
   Result.serialRts := rts;
   Result.serialDtr := dtr;
   Result.radioModel := uRadioRegistry.DisplayNameId(id);
   logger.Info('[RadioFactory] Created %s (serial id): Port=%d, Baud=%d, %dN%d',
               [Result.radioModel, Ord(serialPort), baudRate, dataBits, stopBits]);
end;

class function TRadioFactory.CreateHamLibDirect(msgCallback: TProcessMsgRef): TFactoryRadioBase;
begin
   Result := THamLibDirect.Create(msgCallback);
   Result.radioModel := 'HamLib Direct';
   logger.Info('[RadioFactory] Created HamLib Direct instance');
   logger.Info('[RadioFactory] Remember to set HamLibModelID and connection before connecting');
end;

class function TRadioFactory.GetSupportedModels: string;
begin
   Result := 'Supported radio models:'#13#10 +
             '  - Elecraft K4 (implemented)'#13#10 +
             '  - Icom IC-7610 (implemented)'#13#10 +
             '  - Icom IC-7300 (implemented)'#13#10 +
             '  - Icom IC-9700 (implemented)'#13#10 +
             '  - Icom IC-705 (implemented)'#13#10 +
             '  - Icom IC-7300MK2 (implemented)'#13#10 +
             '  - Icom IC-7600 (implemented)'#13#10 +
             '  - Icom IC-7760 (implemented)'#13#10 +
             '  - Icom IC-7850 (implemented)'#13#10 +
             '  - Icom IC-905 (implemented)'#13#10 +
             '  - Kenwood TS-890S (implemented, Issue #436)'#13#10 +
             '  - Kenwood TS-990S (implemented, via TS-890 class)'#13#10 +
             '  - HamLib Direct via DLL (implemented)'#13#10 +
             '  - Elecraft K3 (planned)'#13#10 +
             '  - Yaesu FTdx101 (planned)'#13#10 +
             '  - Yaesu FT-991 (implemented)'#13#10 +
             '  - Flex 6000+ (6000/8000/Aurora 500 series) (implemented)';
end;

// Network metadata now lives in the radio registry -- each radio unit
// self-registers its default port + discoverable flag.  These read it, keyed
// on InterfacedRadioType.  A 0 port means "not a network radio"; an unregistered
// (legacy, non-factory) radio reads 0 / False.
class function TRadioFactory.DefaultNetworkPort(model: InterfacedRadioType): integer;
begin
   Result := uRadioRegistry.RegisteredNetworkPort(model);
end;

class function TRadioFactory.IsNetworkModel(model: InterfacedRadioType): boolean;
begin
   Result := uRadioRegistry.RegisteredNetworkPort(model) > 0;
end;

class function TRadioFactory.IsDiscoverable(model: InterfacedRadioType): boolean;
begin
   Result := uRadioRegistry.RegisteredDiscoverable(model);
end;

initialization
   logger := TLogLogger.GetLogger('uRadioFactory');
   logger.Info('Radio Factory initialized');

finalization
   logger.Info('Radio Factory finalized');

end.
