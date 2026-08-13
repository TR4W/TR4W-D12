unit uSerialPort;
{$I tr4w.inc}

// The FPC mode and the UnicodeStrings modeswitch now come from tr4w.inc above,
// which every unit in the tree includes.  They are not optional here: without
// UnicodeStrings the unit compiles with an 8-bit `string`, and PWideChar(PortStr)
// below silently reinterprets AnsiString bytes as UTF-16 -- CreateFileW then
// fails with ERROR_INVALID_NAME (123) and no diagnostic anywhere.

interface

uses
  Windows, SysUtils;

type
  ESerialError = class(Exception);

  TSerialBaudRate = (
    sbr110, sbr300, sbr600, sbr1200, sbr2400, sbr4800,
    sbr9600, sbr19200, sbr38400, sbr57600, sbr115200
  );

  TSerialParity = (spNone, spOdd, spEven, spMark, spSpace);
  TSerialStopBits = (ssb1, ssb1_5, ssb2);

  TSerialPort = class
  private
    FHandle: THandle;
    FPortName: string;
    function GetIsOpen: Boolean;
    function BaudToConst(ABaud: TSerialBaudRate): DWORD;
    function ParityToConst(AParity: TSerialParity): Byte;
    function StopBitsToConst(AStopBits: TSerialStopBits): Byte;
    procedure CheckHandle;
  public
    constructor Create(const APortName: string);
    destructor Destroy; override;

    procedure Open(
      ABaud: TSerialBaudRate = sbr9600;
      ADataBits: Byte = 8;
      AParity: TSerialParity = spNone;
      AStopBits: TSerialStopBits = ssb1
    );
    procedure OpenRaw(
      ABaudRate: DWORD;
      ADataBits: Byte;
      AStopBits: Byte;
      AParity: Byte;
      ARts: Boolean = False;
      ADtr: Boolean = False
    );
    procedure Close;

    function Read(var Buffer; Count: DWORD): DWORD;
    function Write(const Buffer; Count: DWORD): DWORD;
    function ReadString(MaxLen: Integer): string;
    procedure WriteString(const S: string);
    // Byte-exact I/O for binary protocols (e.g. Icom CI-V). A serial port is a
    // byte stream: text goes through WriteString (encoded to ASCII bytes here),
    // binary goes through WriteBytes/ReadBytes. Never write a UTF-16 string's
    // code units as if they were wire bytes.
    procedure WriteBytes(const Data: TBytes);
    function ReadBytes(MaxLen: Integer): TBytes;

    property Handle: THandle read FHandle;
    property PortName: string read FPortName;
    property IsOpen: Boolean read GetIsOpen;
  end;

implementation

{ TSerialPort }

constructor TSerialPort.Create(const APortName: string);
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;
  FPortName := APortName;  // e.g. 'COM1', 'COM3', 'COM10'
end;

destructor TSerialPort.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TSerialPort.GetIsOpen: Boolean;
begin
  Result := FHandle <> INVALID_HANDLE_VALUE;
end;

procedure TSerialPort.CheckHandle;
begin
  if not IsOpen then
     begin
     raise ESerialError.Create('Serial port not open');
     end;
end;

function TSerialPort.BaudToConst(ABaud: TSerialBaudRate): DWORD;
begin
  case ABaud of
    sbr110:     Result := CBR_110;
    sbr300:     Result := CBR_300;
    sbr600:     Result := CBR_600;
    sbr1200:    Result := CBR_1200;
    sbr2400:    Result := CBR_2400;
    sbr4800:    Result := CBR_4800;
    sbr9600:    Result := CBR_9600;
    sbr19200:   Result := CBR_19200;
    sbr38400:   Result := CBR_38400;
    sbr57600:   Result := CBR_57600;
    sbr115200:  Result := CBR_115200;
  else
    Result := CBR_9600;
  end;
end;

function TSerialPort.ParityToConst(AParity: TSerialParity): Byte;
begin
  case AParity of
    spNone:  Result := NOPARITY;
    spOdd:   Result := ODDPARITY;
    spEven:  Result := EVENPARITY;
    spMark:  Result := MARKPARITY;
    spSpace: Result := SPACEPARITY;
  else
    Result := NOPARITY;
  end;
end;

function TSerialPort.StopBitsToConst(AStopBits: TSerialStopBits): Byte;
begin
  case AStopBits of
    ssb1:    Result := ONESTOPBIT;
    ssb1_5:  Result := ONE5STOPBITS;
    ssb2:    Result := TWOSTOPBITS;
  else
    Result := ONESTOPBIT;
  end;
end;

procedure TSerialPort.Open(
  ABaud: TSerialBaudRate;
  ADataBits: Byte;
  AParity: TSerialParity;
  AStopBits: TSerialStopBits);
var
  DCB: TDCB;
  Timeouts: COMMTIMEOUTS;
  PortStr: string;
begin
  if IsOpen then
     begin
     Exit;
     end;

  // For COM10+ you MUST use the \\.\ prefix
  if Pos('\\.\', FPortName) = 0 then
     begin
     PortStr := '\\.\' + FPortName
     end
  else
     begin
     PortStr := FPortName;
     end;

  FHandle := CreateFileW(
    PWideChar(PortStr),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0
  );
  if FHandle = INVALID_HANDLE_VALUE then
     begin
     raise ESerialError.CreateFmt('Cannot open %s (error %d)',
       [FPortName, GetLastError]);
     end;

  // Configure line settings
  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  if not GetCommState(FHandle, DCB) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('GetCommState failed');
     end;

  DCB.BaudRate := BaudToConst(ABaud);
  DCB.ByteSize := ADataBits;
  DCB.Parity   := ParityToConst(AParity);
  DCB.StopBits := StopBitsToConst(AStopBits);
  // Flags are set via Flags field in Delphi 7
  DCB.Flags := DCB.Flags or $0001;  // fBinary = 1
  if AParity <> spNone then
     begin
     DCB.Flags := DCB.Flags or $0002;  // fParity = 1
     end;
  // Disable DTR and RTS - not used for CAT control, raising them can interfere with radio
  DCB.Flags := DCB.Flags and not $0030;  // fDtrControl bits 4-5 = 0 (DTR_CONTROL_DISABLE)
  DCB.Flags := DCB.Flags and not $3000;  // fRtsControl bits 12-13 = 0 (RTS_CONTROL_DISABLE)

  if not SetCommState(FHandle, DCB) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('SetCommState failed');
     end;

  // Non-blocking timeouts for thread-based reading
  FillChar(Timeouts, SizeOf(Timeouts), 0);
  Timeouts.ReadIntervalTimeout         := 10;   // Max 10ms between characters
  Timeouts.ReadTotalTimeoutMultiplier  := 0;    // No per-byte timeout
  Timeouts.ReadTotalTimeoutConstant    := 10;   // Max 10ms total wait
  Timeouts.WriteTotalTimeoutMultiplier := 10;
  Timeouts.WriteTotalTimeoutConstant   := 50;

  if not SetCommTimeouts(FHandle, Timeouts) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('SetCommTimeouts failed');
     end;

  // Clear buffers
  PurgeComm(FHandle, PURGE_RXCLEAR or PURGE_TXCLEAR);
end;

procedure TSerialPort.OpenRaw(
  ABaudRate: DWORD;
  ADataBits: Byte;
  AStopBits: Byte;
  AParity: Byte;
  ARts: Boolean;
  ADtr: Boolean);
var
  DCB: TDCB;
  Timeouts: COMMTIMEOUTS;
  PortStr: string;
begin
  if IsOpen then
     begin
     Exit;
     end;

  // For COM10+ you MUST use the \\.\ prefix
  if Pos('\\.\', FPortName) = 0 then
     begin
     PortStr := '\\.\' + FPortName
     end
  else
     begin
     PortStr := FPortName;
     end;

  FHandle := CreateFileW(
    PWideChar(PortStr),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0
  );
  if FHandle = INVALID_HANDLE_VALUE then
     begin
     raise ESerialError.CreateFmt('Cannot open %s (error %d)',
       [FPortName, GetLastError]);
     end;

  // Configure line settings
  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  if not GetCommState(FHandle, DCB) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('GetCommState failed');
     end;

  // Use raw values directly
  DCB.BaudRate := ABaudRate;
  DCB.ByteSize := ADataBits;
  DCB.Parity   := AParity;

  // Convert stop bits: 1=ONESTOPBIT(0), 2=TWOSTOPBITS(2)
  if AStopBits = 1 then
     begin
     DCB.StopBits := ONESTOPBIT
     end
  else if AStopBits = 2 then
     begin
     DCB.StopBits := TWOSTOPBITS
     end
  else
     begin
     DCB.StopBits := ONESTOPBIT;  // Default to 1
     end;

  // Flags are set via Flags field in Delphi 7
  DCB.Flags := DCB.Flags or $0001;  // fBinary = 1
  if AParity <> 0 then  // 0 = no parity
     begin
     DCB.Flags := DCB.Flags or $0002;  // fParity = 1
     end;
  // DTR control: bits 4-5. 0=$00=DISABLE, 1=$10=ENABLE
  DCB.Flags := DCB.Flags and not $0030;  // clear fDtrControl bits first
  if ADtr then
     begin
     DCB.Flags := DCB.Flags or $0010;     // DTR_CONTROL_ENABLE
     end;
  // RTS control: bits 12-13. 0=$0000=DISABLE, 1=$1000=ENABLE
  DCB.Flags := DCB.Flags and not $3000;  // clear fRtsControl bits first
  if ARts then
     begin
     DCB.Flags := DCB.Flags or $1000;     // RTS_CONTROL_ENABLE
     end;

  if not SetCommState(FHandle, DCB) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('SetCommState failed');
     end;

  // Non-blocking timeouts for thread-based reading
  FillChar(Timeouts, SizeOf(Timeouts), 0);
  Timeouts.ReadIntervalTimeout         := 10;   // Max 10ms between characters
  Timeouts.ReadTotalTimeoutMultiplier  := 0;    // No per-byte timeout
  Timeouts.ReadTotalTimeoutConstant    := 10;   // Max 10ms total wait
  Timeouts.WriteTotalTimeoutMultiplier := 10;
  Timeouts.WriteTotalTimeoutConstant   := 50;

  if not SetCommTimeouts(FHandle, Timeouts) then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     raise ESerialError.Create('SetCommTimeouts failed');
     end;

  // Clear buffers
  PurgeComm(FHandle, PURGE_RXCLEAR or PURGE_TXCLEAR);
end;

procedure TSerialPort.Close;
begin
  if IsOpen then
     begin
     CloseHandle(FHandle);
     FHandle := INVALID_HANDLE_VALUE;
     end;
end;

function TSerialPort.Read(var Buffer; Count: DWORD): DWORD;
begin
  CheckHandle;
  if not ReadFile(FHandle, Buffer, Count, Result, nil) then
     begin
     raise ESerialError.CreateFmt('ReadFile failed (error %d)', [GetLastError]);
     end;
end;

function TSerialPort.Write(const Buffer; Count: DWORD): DWORD;
begin
  CheckHandle;
  if not WriteFile(FHandle, Buffer, Count, Result, nil) then
     begin
     raise ESerialError.CreateFmt('WriteFile failed (error %d)', [GetLastError]);
     end;
end;

function TSerialPort.ReadString(MaxLen: Integer): string;
var
  Buffer: array[0..1023] of AnsiChar;
  BytesRead: DWORD;
  Len: Integer;
begin
  Result := '';
  if MaxLen > SizeOf(Buffer) then
     begin
     Len := SizeOf(Buffer)
     end
  else
     begin
     Len := MaxLen;
     end;

  BytesRead := Read(Buffer, Len);
  if BytesRead > 0 then
     begin
     SetString(Result, Buffer, BytesRead);
     end;
end;

procedure TSerialPort.WriteString(const S: string);
begin
  // Serial is a byte stream. Encode the (ASCII CAT) text to its wire bytes
  // rather than writing UTF-16 code units. D12: Length(S) is a code-unit
  // count, not a byte count -- the old Write(S[1], Length(S)) sent
  // "F<00>A<00>..." for "FA...", breaking every serial radio.
  WriteBytes(TEncoding.ASCII.GetBytes(S));
end;

procedure TSerialPort.WriteBytes(const Data: TBytes);
begin
  if Length(Data) > 0 then
     begin
     Write(Data[0], Length(Data));
     end;
end;

function TSerialPort.ReadBytes(MaxLen: Integer): TBytes;
var
  Buffer: array[0..1023] of Byte;
  BytesRead: DWORD;
  Len: Integer;
begin
  if MaxLen > SizeOf(Buffer) then
     begin
     Len := SizeOf(Buffer)
     end
  else
     begin
     Len := MaxLen;
     end;

  BytesRead := Read(Buffer, Len);
  SetLength(Result, BytesRead);
  if BytesRead > 0 then
     begin
     Move(Buffer[0], Result[0], BytesRead);
     end;
end;

end.
