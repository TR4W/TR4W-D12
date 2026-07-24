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
    radio := TRadioFactory.CreateRadio(rmElecraftK4, '192.168.1.100', 7373, @MyProcessMsg);
    radio.Connect;
}

interface

uses
   Windows, uFactoryRadioBase, uRadioElecraftK4, uFlexRadio6000, SysUtils, VC;

type
   TRadioModel = (
      rmNone,
      rmElecraftK4,
      rmElecraftK3,
      rmYaesuFTdx101,
      rmYaesuFT991,
      rmIcomIC7610,
      rmIcomIC7300,
      rmIcomIC9700,
      rmIcomIC705,
      rmIcomIC7300MK2,
      rmIcomIC7600,
      rmIcomIC7760,
      rmIcomIC7850,
      rmIcomIC905,
      rmIcomIC7100,
      rmIcomIC718,      // IC-718 serial CI-V (addr $5E) -- minimal older Icom
      rmFlexRadio6000,
      rmKenwoodTS890,   // Issue #436 -- TS-890 network (Kenwood CAT over TCP + ##CN/##ID auth)
      rmKenwoodTS990,   // TS-990 network (reuses the TS-890 CAT/auth path)
      rmHamLibDirect
   );

   TConnectionType = (ctNetwork, ctSerial);

   TRadioFactory = class
   public
      class function ModelToString(model: TRadioModel): string;
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
      class function GetSupportedModels: string;
      class function IsModelSupported(model: TRadioModel): boolean;

      // Network metadata (Issue #1028) -- single source of truth for "is this a
      // network radio", its default TCP/UDP port, and whether TR4W can auto-
      // discover it on the LAN.  Keyed by TRadioModel; legacy InterfacedRadioType
      // callers bridge via ModelForInterfacedType.
      class function ModelForInterfacedType(rt: InterfacedRadioType): TRadioModel;
      class function DefaultNetworkPort(model: TRadioModel): integer;
      class function IsNetworkModel(model: TRadioModel): boolean;
      class function IsDiscoverable(model: TRadioModel): boolean;
   end;

   ERadioFactoryException = class(Exception);

implementation

uses Log4D, uRadioRegistry, uRadioHamLibDirect, uRadioIcomBase,
     uRadioIcom7300, uRadioIcom7610, uRadioIcom9700,
     uRadioIcom705, uRadioIcom7300MK2, uRadioIcom7600,
     uRadioIcom7760, uRadioIcom7850, uRadioIcom905, uRadioIcom7100,
     uRadioIcom718,
     uRadioKenwoodTS890;  // Issue #436
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

   Result := uRadioRegistry.CreateInstance(model);
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

   Result := uRadioRegistry.CreateInstance(model);
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

class function TRadioFactory.CreateHamLibDirect(msgCallback: TProcessMsgRef): TFactoryRadioBase;
begin
   Result := THamLibDirect.Create(msgCallback);
   Result.radioModel := 'HamLib Direct';
   logger.Info('[RadioFactory] Created HamLib Direct instance');
   logger.Info('[RadioFactory] Remember to set HamLibModelID and connection before connecting');
end;

class function TRadioFactory.ModelToString(model: TRadioModel): string;
begin
   case model of
      rmNone:           Result := 'None';
      rmElecraftK4:     Result := 'Elecraft K4';
      rmElecraftK3:     Result := 'Elecraft K3';
      rmYaesuFTdx101:   Result := 'Yaesu FTdx101';
      rmYaesuFT991:     Result := 'Yaesu FT-991';
      rmIcomIC7610:     Result := 'Icom IC-7610';
      rmIcomIC7300:     Result := 'Icom IC-7300';
      rmIcomIC9700:     Result := 'Icom IC-9700';
      rmIcomIC705:      Result := 'Icom IC-705';
      rmIcomIC7300MK2:  Result := 'Icom IC-7300MK2';
      rmIcomIC7600:     Result := 'Icom IC-7600';
      rmIcomIC7760:     Result := 'Icom IC-7760';
      rmIcomIC7850:     Result := 'Icom IC-7850';
      rmIcomIC905:      Result := 'Icom IC-905';
      rmIcomIC7100:     Result := 'Icom IC-7100';
      rmIcomIC718:      Result := 'Icom IC-718';
      rmFlexRadio6000:  Result := 'FlexRadio 6000';
      rmKenwoodTS890:   Result := 'Kenwood TS-890S';
      rmKenwoodTS990:   Result := 'Kenwood TS-990S';
      rmHamLibDirect:   Result := 'HamLib Direct (DLL)';
   else
      Result := 'Unknown';
   end;
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
             '  - Yaesu FT-991 (planned)'#13#10 +
             '  - FlexRadio 6000 (implemented)';
end;

class function TRadioFactory.IsModelSupported(model: TRadioModel): boolean;
begin
   Result := (model = rmElecraftK4) or
             (model = rmIcomIC7610) or
             (model = rmIcomIC7300) or
             (model = rmIcomIC9700) or
             (model = rmIcomIC705) or
             (model = rmIcomIC7300MK2) or
             (model = rmIcomIC7600) or
             (model = rmIcomIC7760) or
             (model = rmIcomIC7850) or
             (model = rmIcomIC905) or
             (model = rmIcomIC7100) or
             (model = rmIcomIC718) or
             (model = rmFlexRadio6000) or
             (model = rmKenwoodTS890) or
             (model = rmKenwoodTS990) or
             (model = rmHamLibDirect);
end;

// Maps the legacy InterfacedRadioType (LOGRADIO RadioParametersArray order) to
// the factory's TRadioModel.  Single source of truth -- RadioObject.MapRadio
// ModelToFactory delegates here.  Radios with no factory model -> rmNone.
class function TRadioFactory.ModelForInterfacedType(rt: InterfacedRadioType): TRadioModel;
begin
   case rt of
      K4:             Result := rmElecraftK4;
      IC7610:         Result := rmIcomIC7610;
      IC7300:         Result := rmIcomIC7300;
      IC9700:         Result := rmIcomIC9700;
      IC705:          Result := rmIcomIC705;
      IC7300MK2:      Result := rmIcomIC7300MK2;
      IC7600:         Result := rmIcomIC7600;
      IC7760:         Result := rmIcomIC7760;
      IC7850, IC7851: Result := rmIcomIC7850;
      IC905:          Result := rmIcomIC905;
      IC7100:         Result := rmIcomIC7100;
      IC718:          Result := rmIcomIC718;
      FLEX:           Result := rmFlexRadio6000;
      TS890:          Result := rmKenwoodTS890;
      TS990:          Result := rmKenwoodTS990;
   else
      Result := rmNone;
   end;
end;

// The default network port per model.  0 means "not a network radio".
class function TRadioFactory.DefaultNetworkPort(model: TRadioModel): integer;
begin
   case model of
      rmElecraftK4:     Result := 9200;
      rmFlexRadio6000:  Result := 4992;
      rmKenwoodTS890:   Result := 60000;
      rmKenwoodTS990:   Result := 50000;
      rmIcomIC7610, rmIcomIC9700, rmIcomIC705, rmIcomIC7300MK2,
      rmIcomIC7600, rmIcomIC7760, rmIcomIC7850, rmIcomIC905:
                        Result := 50001;   // Icom network models (CI-V over UDP)
   else
      Result := 0;                          // serial-only / not a network radio
   end;
end;

// A model is a network radio iff it carries a default network port.
class function TRadioFactory.IsNetworkModel(model: TRadioModel): boolean;
begin
   Result := DefaultNetworkPort(model) > 0;
end;

// Discoverable = a network radio with LAN auto-discovery.  Every network radio
// qualifies EXCEPT the Kenwoods (network, but no discovery protocol wired yet).
class function TRadioFactory.IsDiscoverable(model: TRadioModel): boolean;
begin
   Result := IsNetworkModel(model)
             and (model <> rmKenwoodTS890)
             and (model <> rmKenwoodTS990);
end;

initialization
   logger := TLogLogger.GetLogger('uRadioFactory');
   logger.Info('Radio Factory initialized');

finalization
   logger.Info('Radio Factory finalized');

end.
