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
unit ComPortEnumerator;

{
  Enumerates the serial ports Windows currently reports, with their friendly
  names, so the port drop-down can show "COM14 - Silicon Labs CP210x" instead of
  a fixed list of SERIAL 1..20 that may or may not exist.

  Also supports the persistence question in docs\COMPort_Persistence.md: remember
  the operator's last choice and show it even when the device is unplugged,
  rather than silently dropping it.  See TRememberedPort / MatchRemembered.

  ---------------------------------------------------------------------------
  THREE THINGS TO KNOW BEFORE USING THIS
  ---------------------------------------------------------------------------

  1. TR4W CANNOT ADDRESS EVERY PORT WINDOWS REPORTS.  PortType is an enum whose
     ordinals 1..20 mean COM1..COM20 (MainUnit.ConvertPortTypeToCOMString; the
     same enum also encodes 21 = socket and 22..25 = LPT1..LPT4).  Windows
     routinely hands a USB adapter COM23, and TR4W has no way to represent that
     today.  Enumerating a port the operator then cannot select would be WORSE
     than the current fixed list, so every record carries Addressable, and
     callers must show unaddressable ports as disabled with a reason rather than
     silently omitting them -- "my radio is on COM23 and TR4W won't list it" is
     a support question either way; better to answer it in the dialog.

  2. THIS UNIT DOES NOT OPEN, CLOSE OR RECONNECT ANYTHING.  It answers "what
     does Windows see right now".  TR4W already owns reconnection in the factory
     reading thread (RECONNECT_INITIAL_DELAY and friends in uFactoryRadioBase),
     and a second mechanism reacting to device arrival would race it.

  3. THERE IS DELIBERATELY NO WM_DEVICECHANGE WINDOW HERE.  A message-only
     window has thread affinity (it must live on the thread that pumps the
     message loop) and its handler can re-enter during modal dialogs, which is
     exactly when the port list is on screen.  Refreshing when the dialog opens
     -- and when the operator asks -- gets the same result for a setup dialog
     that is open for seconds at a time.  If live hot-plug updates are ever
     wanted, add the notification window in the DIALOG unit, which already owns
     a window handle and a thread, and have it call Refresh.

  Note on the RTL: Delphi 12 ships NO Winapi.SetupApi unit for Win32 (the only
  SetupAPI declarations in the product are private to System.Win.Bluetooth), so
  the handful of imports needed are declared below.  They are `delayed` so a
  machine without setupapi.dll still loads TR4W.
}

interface

uses
   Winapi.Windows,
   System.SysUtils,
   System.Classes,
   VC;   // for MAX_SERIAL_PORT -- see below

const
   // Highest COM number TR4W can address, taken from the PortType enum itself
   // rather than restated here.  A second copy of this number is precisely the
   // bug being fixed: the old ceiling of 20 lived in FIVE places (the enum, its
   // string array, ConvertPortTypeToCOMString, the dialog's combo loop and a
   // dozen range tests) and they had to be edited in lockstep.
   MAX_ADDRESSABLE_COM_PORT = MAX_SERIAL_PORT;

type
   TComPortInfo = record
      PortName: string;       // 'COM14' exactly as Windows reports it
      PortNumber: Integer;    // 14, or 0 when the name does not parse
      FriendlyName: string;   // 'Silicon Labs CP210x USB to UART Bridge (COM14)'
      DeviceDesc: string;     // 'USB Serial Port' -- fallback when no friendly name
      InstanceID: string;     // stable-ish device identity, e.g. 'FTDIBUS\VID_0403...'
      Addressable: Boolean;   // False when PortNumber is outside 1..MAX (see note 1)
      Present: Boolean;       // False = Windows still KNOWS this port (it is in the
                              // registry, and Device Manager shows it under "show
                              // hidden devices") but the hardware is unplugged.
                              // Its friendly name is still available, which is what
                              // lets the UI say WHICH radio used to be on that port
                              // instead of an anonymous "not connected".
      function Describe: string;   // 'COM14 - Silicon Labs CP210x...'
   end;

   TComPortInfoArray = TArray<TComPortInfo>;

   // What the caller persisted about the last-used port.  Persist as much as is
   // convenient: matching degrades gracefully when fields are empty.
   TRememberedPort = record
      PortName: string;
      InstanceID: string;
      FriendlyName: string;
   end;

   // How a remembered port was resolved against what is present now.  The order
   // mirrors docs\COMPort_Persistence.md: identity first, name last.
   TPortMatchKind = (
      pmNone,         // nothing remembered
      pmInstanceID,   // same physical device, even if its COM number moved
      pmPortName,     // same COM number; may or may not be the same device
      pmOffline       // remembered, but not present right now
   );

   TComPortEnumerator = class(TObject)
   private
      FPorts: TComPortInfoArray;
      function IndexOfPortName(const APortName: string): Integer;
      function IndexOfInstanceID(const AInstanceID: string): Integer;
   public
      constructor Create;

      // Re-read what Windows reports.  Cheap enough to call whenever a dialog
      // opens; does no I/O on the ports themselves.
      procedure Refresh;

      function Count: Integer;
      function PortByName(const APortName: string; out AInfo: TComPortInfo): Boolean;
      function PortNames: TArray<string>;

      // Resolve a remembered selection against the current list.  When the
      // result is pmOffline, AInfo is filled in from ARemembered so the caller
      // can still display it (marked "not connected") instead of dropping it.
      function MatchRemembered(const ARemembered: TRememberedPort;
                               out AInfo: TComPortInfo): TPortMatchKind;

      property Ports: TComPortInfoArray read FPorts;
   end;

// Parses 'COM14' -> 14.  Returns 0 for anything that is not a COM name, which is
// what makes a port unaddressable rather than accidentally selectable.
function ComPortNumber(const APortName: string): Integer;

implementation

// `delayed` raises W1002 (platform-specific symbol) on every import below.  That
// is exactly what we want here -- the point is to not require setupapi.dll at
// load time -- so silence the noise rather than leave six warnings in the build.
{$WARN SYMBOL_PLATFORM OFF}

const
   SetupApiDll = 'setupapi.dll';

   // Ports class -- covers COM and LPT devices that are PRESENT.
   GUID_DEVCLASS_PORTS: TGUID = '{4D36E978-E325-11CE-BFC1-08002BE10318}';

   DIGCF_PRESENT = $00000002;

   SPDRP_DEVICEDESC   = $00000000;
   SPDRP_FRIENDLYNAME = $0000000C;

   DICS_FLAG_GLOBAL = $00000001;
   DIREG_DEV        = $00000001;

type
   HDEVINFO = Pointer;

   SP_DEVINFO_DATA = record
      cbSize: DWORD;
      ClassGuid: TGUID;
      DevInst: DWORD;
      Reserved: UINT_PTR;
   end;
   PSP_DEVINFO_DATA = ^SP_DEVINFO_DATA;

function SetupDiGetClassDevsW(ClassGuid: PGUID; Enumerator: PWideChar;
   hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
   external SetupApiDll name 'SetupDiGetClassDevsW' delayed;

function SetupDiEnumDeviceInfo(DeviceInfoSet: HDEVINFO; MemberIndex: DWORD;
   var DeviceInfoData: SP_DEVINFO_DATA): BOOL; stdcall;
   external SetupApiDll name 'SetupDiEnumDeviceInfo' delayed;

function SetupDiDestroyDeviceInfoList(DeviceInfoSet: HDEVINFO): BOOL; stdcall;
   external SetupApiDll name 'SetupDiDestroyDeviceInfoList' delayed;

function SetupDiGetDeviceRegistryPropertyW(DeviceInfoSet: HDEVINFO;
   const DeviceInfoData: SP_DEVINFO_DATA; Property_: DWORD;
   PropertyRegDataType: PDWORD; PropertyBuffer: PByte; PropertyBufferSize: DWORD;
   RequiredSize: PDWORD): BOOL; stdcall;
   external SetupApiDll name 'SetupDiGetDeviceRegistryPropertyW' delayed;

function SetupDiGetDeviceInstanceIdW(DeviceInfoSet: HDEVINFO;
   const DeviceInfoData: SP_DEVINFO_DATA; DeviceInstanceId: PWideChar;
   DeviceInstanceIdSize: DWORD; RequiredSize: PDWORD): BOOL; stdcall;
   external SetupApiDll name 'SetupDiGetDeviceInstanceIdW' delayed;

function SetupDiOpenDevRegKey(DeviceInfoSet: HDEVINFO;
   const DeviceInfoData: SP_DEVINFO_DATA; Scope, HwProfile, KeyType: DWORD;
   samDesired: REGSAM): HKEY; stdcall;
   external SetupApiDll name 'SetupDiOpenDevRegKey' delayed;

// ---------------------------------------------------------------------------

function ComPortNumber(const APortName: string): Integer;
var
   trimmed: string;
begin
   Result := 0;
   trimmed := UpperCase(Trim(APortName));
   if not trimmed.StartsWith('COM') then
      begin
      Exit;
      end;
   // Copy past 'COM'; StrToIntDef rejects 'COM3 (something)' by returning 0,
   // which is what we want -- an unparsed name must not look addressable.
   Result := StrToIntDef(Copy(trimmed, 4, MaxInt), 0);
   if Result < 0 then
      begin
      Result := 0;
      end;
end;

{ TComPortInfo }

function TComPortInfo.Describe: string;
begin
   if FriendlyName <> '' then
      begin
      Result := FriendlyName;
      end
   else if DeviceDesc <> '' then
      begin
      Result := PortName + ' - ' + DeviceDesc;
      end
   else
      begin
      Result := PortName;
      end;
end;

{ helpers }

// Reads one SPDRP_* string property.  Returns '' when the device has none,
// which is normal -- not every port reports a friendly name.
function DeviceRegistryString(ADeviceInfoSet: HDEVINFO;
   const ADeviceInfoData: SP_DEVINFO_DATA; APropertyCode: DWORD): string;
var
   required: DWORD;
   buffer: TBytes;
begin
   Result := '';
   required := 0;
   // First call sizes the buffer; it is EXPECTED to fail.
   SetupDiGetDeviceRegistryPropertyW(ADeviceInfoSet, ADeviceInfoData,
      APropertyCode, nil, nil, 0, @required);
   if required = 0 then
      begin
      Exit;
      end;
   SetLength(buffer, required);
   if SetupDiGetDeviceRegistryPropertyW(ADeviceInfoSet, ADeviceInfoData,
      APropertyCode, nil, PByte(buffer), required, nil) then
      begin
      Result := PWideChar(@buffer[0]);
      end;
end;

function DeviceInstanceID(ADeviceInfoSet: HDEVINFO;
   const ADeviceInfoData: SP_DEVINFO_DATA): string;
var
   buffer: array[0..1023] of WideChar;
   required: DWORD;
begin
   Result := '';
   required := 0;
   if SetupDiGetDeviceInstanceIdW(ADeviceInfoSet, ADeviceInfoData, @buffer[0],
      Length(buffer), @required) then
      begin
      Result := buffer;
      end;
end;

// The COM name lives in the device's own registry key, value 'PortName'.  This
// is the authoritative name; the friendly name merely tends to contain it in
// parentheses, which is not something to parse.
function DevicePortName(ADeviceInfoSet: HDEVINFO;
   const ADeviceInfoData: SP_DEVINFO_DATA): string;
var
   key: HKEY;
   valueType: DWORD;
   size: DWORD;
   buffer: array[0..255] of WideChar;
begin
   Result := '';
   key := SetupDiOpenDevRegKey(ADeviceInfoSet, ADeviceInfoData,
      DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_READ);
   if key = INVALID_HANDLE_VALUE then
      begin
      Exit;
      end;
   try
      size := SizeOf(buffer);
      valueType := 0;
      FillChar(buffer, SizeOf(buffer), 0);
      if RegQueryValueExW(key, 'PortName', nil, @valueType, PByte(@buffer[0]),
         @size) = ERROR_SUCCESS then
         begin
         if (valueType = REG_SZ) or (valueType = REG_EXPAND_SZ) then
            begin
            Result := buffer;
            end;
         end;
   finally
      RegCloseKey(key);
   end;
end;

{ TComPortEnumerator }

constructor TComPortEnumerator.Create;
begin
   inherited Create;
   Refresh;
end;

procedure TComPortEnumerator.Refresh;
var
   deviceInfoSet: HDEVINFO;
   deviceInfoData: SP_DEVINFO_DATA;
   index: DWORD;
   found: TComPortInfoArray;
   info: TComPortInfo;
   used: Integer;
   i: Integer;
   j: Integer;
   swap: TComPortInfo;
   presentPorts: set of Byte;   // port numbers reported by the DIGCF_PRESENT pass
begin
   SetLength(FPorts, 0);
   SetLength(found, 0);
   used := 0;
   presentPorts := [];

   // PASS 1 -- DIGCF_PRESENT: which ports are physically here right now.
   // Only the port NUMBERS are needed; pass 2 collects the detail.
   deviceInfoSet := SetupDiGetClassDevsW(@GUID_DEVCLASS_PORTS, nil, 0, DIGCF_PRESENT);
   if deviceInfoSet <> Pointer(INVALID_HANDLE_VALUE) then
      begin
      try
         index := 0;
         FillChar(deviceInfoData, SizeOf(deviceInfoData), 0);
         deviceInfoData.cbSize := SizeOf(SP_DEVINFO_DATA);
         while SetupDiEnumDeviceInfo(deviceInfoSet, index, deviceInfoData) do
            begin
            Inc(index);
            i := ComPortNumber(DevicePortName(deviceInfoSet, deviceInfoData));
            if (i > 0) and (i <= High(Byte)) then
               begin
               Include(presentPorts, Byte(i));
               end;
            FillChar(deviceInfoData, SizeOf(deviceInfoData), 0);
            deviceInfoData.cbSize := SizeOf(SP_DEVINFO_DATA);
            end;
      finally
         SetupDiDestroyDeviceInfoList(deviceInfoSet);
      end;
      end;

   // PASS 2 -- no DIGCF_PRESENT: every port Windows KNOWS, including devices that
   // are currently unplugged.  This is what Device Manager shows under "show
   // hidden devices", and it is why an absent port can still be named: the
   // friendly name lives in the registry and outlives the cable.  Without this
   // pass an unplugged adapter degrades to an anonymous "not connected" and the
   // operator cannot tell WHICH radio used to be there.
   deviceInfoSet := SetupDiGetClassDevsW(@GUID_DEVCLASS_PORTS, nil, 0, 0);
   if deviceInfoSet = Pointer(INVALID_HANDLE_VALUE) then
      begin
      Exit;
      end;
   try
      index := 0;
      FillChar(deviceInfoData, SizeOf(deviceInfoData), 0);
      deviceInfoData.cbSize := SizeOf(SP_DEVINFO_DATA);
      while SetupDiEnumDeviceInfo(deviceInfoSet, index, deviceInfoData) do
         begin
         Inc(index);
         info := Default(TComPortInfo);
         info.PortName := DevicePortName(deviceInfoSet, deviceInfoData);
         // The Ports class also contains LPT devices; keep only COM names.
         if ComPortNumber(info.PortName) > 0 then
            begin
            info.PortNumber   := ComPortNumber(info.PortName);
            info.FriendlyName := DeviceRegistryString(deviceInfoSet, deviceInfoData, SPDRP_FRIENDLYNAME);
            info.DeviceDesc   := DeviceRegistryString(deviceInfoSet, deviceInfoData, SPDRP_DEVICEDESC);
            info.InstanceID   := DeviceInstanceID(deviceInfoSet, deviceInfoData);
            info.Addressable  := info.PortNumber <= MAX_ADDRESSABLE_COM_PORT;
            info.Present      := (info.PortNumber <= High(Byte)) and
                                 (Byte(info.PortNumber) in presentPorts);
            if used = Length(found) then
               begin
               SetLength(found, used + 16);
               end;
            found[used] := info;
            Inc(used);
            end;
         FillChar(deviceInfoData, SizeOf(deviceInfoData), 0);
         deviceInfoData.cbSize := SizeOf(SP_DEVINFO_DATA);
         end;
   finally
      SetupDiDestroyDeviceInfoList(deviceInfoSet);
   end;

   SetLength(found, used);

   // Sort by port NUMBER, not by name: COM2 must precede COM10.  Insertion sort
   // -- this list is a handful of entries, never worth anything cleverer.
   for i := 1 to High(found) do
      begin
      swap := found[i];
      j := i - 1;
      while (j >= 0) and (found[j].PortNumber > swap.PortNumber) do
         begin
         found[j + 1] := found[j];
         Dec(j);
         end;
      found[j + 1] := swap;
      end;

   FPorts := found;
end;

function TComPortEnumerator.Count: Integer;
begin
   Result := Length(FPorts);
end;

function TComPortEnumerator.IndexOfPortName(const APortName: string): Integer;
var
   i: Integer;
begin
   Result := -1;
   if APortName = '' then
      begin
      Exit;
      end;
   for i := 0 to High(FPorts) do
      begin
      if SameText(FPorts[i].PortName, APortName) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TComPortEnumerator.IndexOfInstanceID(const AInstanceID: string): Integer;
var
   i: Integer;
begin
   Result := -1;
   if AInstanceID = '' then
      begin
      Exit;
      end;
   for i := 0 to High(FPorts) do
      begin
      if SameText(FPorts[i].InstanceID, AInstanceID) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

function TComPortEnumerator.PortByName(const APortName: string;
   out AInfo: TComPortInfo): Boolean;
var
   index: Integer;
begin
   index := IndexOfPortName(APortName);
   Result := index >= 0;
   if Result then
      begin
      AInfo := FPorts[index];
      end
   else
      begin
      AInfo := Default(TComPortInfo);
      end;
end;

function TComPortEnumerator.PortNames: TArray<string>;
var
   i: Integer;
begin
   SetLength(Result, Length(FPorts));
   for i := 0 to High(FPorts) do
      begin
      Result[i] := FPorts[i].PortName;
      end;
end;

function TComPortEnumerator.MatchRemembered(const ARemembered: TRememberedPort;
   out AInfo: TComPortInfo): TPortMatchKind;
var
   index: Integer;
begin
   AInfo := Default(TComPortInfo);

   if (ARemembered.PortName = '') and (ARemembered.InstanceID = '') then
      begin
      Result := pmNone;
      Exit;
      end;

   // 1. Same physical device, wherever Windows put it this time.
   index := IndexOfInstanceID(ARemembered.InstanceID);
   if index >= 0 then
      begin
      AInfo := FPorts[index];
      Result := pmInstanceID;
      Exit;
      end;

   // 2. Same COM number.  Deliberately weaker than identity: COM5 is a current
   //    assignment, not a device, so this can land on a DIFFERENT adapter that
   //    inherited the number.  Callers that care should show what they matched.
   index := IndexOfPortName(ARemembered.PortName);
   if index >= 0 then
      begin
      AInfo := FPorts[index];
      Result := pmPortName;
      Exit;
      end;

   // 3. Remembered but absent.  Hand back what was persisted so the caller can
   //    show "Last used: COM5 (not connected)" rather than silently forgetting
   //    the operator's choice -- see docs\COMPort_Persistence.md.
   AInfo.PortName     := ARemembered.PortName;
   AInfo.PortNumber   := ComPortNumber(ARemembered.PortName);
   AInfo.FriendlyName := ARemembered.FriendlyName;
   AInfo.InstanceID   := ARemembered.InstanceID;
   AInfo.Addressable  := (AInfo.PortNumber > 0) and
                         (AInfo.PortNumber <= MAX_ADDRESSABLE_COM_PORT);
   Result := pmOffline;
end;

end.
