unit uSerialPort;
{$I tr4w.inc}

(* THE ONE SERIAL PORT OBJECT. One instance per open port, owned by whatever
  opened it -- a radio, a rotator, a keyer -- never shared and never in a
  global table.

  IT SPEAKS NO WIN32. The body was CreateFileW / GetCommState / SetCommState /
  SetCommTimeouts / ReadFile / WriteFile / PurgeComm until 2026-09-07, which
  made every serial device in TR4W a Windows-only device. It now calls
  tr4wserial, which is FreePascal's own serial unit vendored so that it also
  exists on macOS -- see the header of tr4w\include\tr4wserial.pas for why a
  unit the RTL already ships had to be copied.

  WHAT CHANGED IN BEHAVIOUR, because two things did and neither is visible:

  1. DTR AND RTS ARE NOT ASSERTED BY OPENING A PORT. The Win32 body set the
     DCB's fDtrControl/fRtsControl bits itself; SerSetParams zeroes the DCB and
     never touches them, so both lines come up LOW. OpenRaw therefore sets them
     explicitly from ARts/ADtr, which is what the caller always passed and what
     the radio factory has always carried per radio. A rig powered or enabled
     off one of those lines would otherwise come up dead, silently.

  2. READS ARE TIMED, NOT NON-BLOCKING. SerRead sets ReadIntervalTimeout to
     MAXDWORD -- return immediately with whatever is buffered -- which would
     spin a reader thread at 100% CPU. SerReadTimeout is the form that waits,
     and ReadTimeoutMs (10 ms, the value the Win32 body used) is what it waits
     for. Any read here is on a reading thread, so blocking is correct; nothing
     sets tr4wserial's SerialIdle hook and nothing should, because that exists
     for calls made on the main thread.

  GONE, AND NOTHING CALLED THEM (checked across src, test and every .lpr):
  Open and its TSerialBaudRate / TSerialParity / TSerialStopBits enums, the
  untyped Read and Write, and the Handle property. The enums also declared
  Mark and Space parity and 1.5 stop bits, which no caller ever selected and
  which FreePascal's serial unit cannot express -- so they were a promise this
  class could not have kept anyway. *)

interface

uses
  SysUtils,
  (* THE ONLY WIN32 LEFT IN THIS UNIT, and it is confined to SetDTR/SetRTS:
    EscapeCommFunction, because FPC's own SerSetDTR costs 6.2x as much there
    and this is the CW keying path. The reasoning is beside those two methods.
    Every other Windows call -- CreateFileW, GetCommState, SetCommState,
    SetCommTimeouts, ReadFile, WriteFile, PurgeComm -- is gone. *)
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  tr4wserial;

type
  ESerialError = class(Exception);

  TSerialPort = class
  private
    FHandle: TSerialHandle;
    FPortName: string;
    FReadTimeoutMs: integer;
    function GetIsOpen: Boolean;
    procedure CheckHandle;
    function DeviceName: string;
  public
    constructor Create(const APortName: string);
    destructor Destroy; override;

    (* Open with the numbers the radio registry stores.

      AParity is 0/1/2 -- uRadioRegistry's PARITY_NONE/ODD/EVEN, whose ordinals
      happen to be TParityType's as well, which is why this takes a byte rather
      than the enum. Anything else raises rather than silently opening a port
      with parity the caller did not ask for. *)
    procedure OpenRaw(
      ABaudRate: DWORD;
      ADataBits: Byte;
      AStopBits: Byte;
      AParity: Byte;
      ARts: Boolean = False;
      ADtr: Boolean = False
    );
    procedure Close;

    (* DRIVE DTR AND RTS DIRECTLY, for the CPU keyer.

      These are not I/O -- they assert a modem control line -- and they are the
      keyer's element clock: at 40 WPM a dit is about 30 ms and each one is two
      edges, so what an edge costs is not academic.

      NOT SerSetDTR / SerSetRTS ON WINDOWS, and that is the whole reason these
      exist. FreePascal implements them there as GetCommState + SetCommState
      (serial.pp:334-364): it reads the entire device control block back from
      the driver, flips two bits, and writes baud, parity, byte size and flow
      control back down again -- on every keying edge. Measured on NY4I's
      WinKeyer port, 2000 edges each way:

        EscapeCommFunction   75.10 us per edge
        SerSetRTS           465.78 us per edge   -- 6.2x

      So Windows keeps the single call it has always used and CW timing does
      not change. Every other platform gets FPC's unix arm, which is already
      the right primitive: one fpioctl(TIOCMBIS/TIOCMBIC), not a termios
      round-trip. *)
    procedure SetDTR(aOn: Boolean);
    procedure SetRTS(aOn: Boolean);

    function ReadString(MaxLen: Integer): string;
    procedure WriteString(const S: string);
    (* Byte-exact I/O for binary protocols (e.g. Icom CI-V). A serial port is a
      byte stream: text goes through WriteString (encoded to ASCII bytes here),
      binary goes through WriteBytes/ReadBytes. Never write a UTF-16 string's
      code units as if they were wire bytes. *)
    procedure WriteBytes(const Data: TBytes);
    function ReadBytes(MaxLen: Integer): TBytes;

    property PortName: string read FPortName;
    property IsOpen: Boolean read GetIsOpen;
    (* How long a read waits for the first byte. Ten milliseconds is what the
      Win32 body's COMMTIMEOUTS asked for and what the reading threads were
      written against. *)
    property ReadTimeoutMs: integer read FReadTimeoutMs write FReadTimeoutMs;
  end;

implementation

const
  (* SerOpen answers 0 on failure, NOT INVALID_HANDLE_VALUE -- it maps the
    Windows sentinel onto zero itself so that one test works on both
    platforms. *)
  NO_PORT = TSerialHandle(0);

  READ_TIMEOUT_MS_DEFAULT = 10;

{ TSerialPort }

constructor TSerialPort.Create(const APortName: string);
begin
   inherited Create;
   FHandle := NO_PORT;
   FPortName := APortName;          (* 'COM1', 'COM10', '/dev/ttyUSB0' *)
   FReadTimeoutMs := READ_TIMEOUT_MS_DEFAULT;
end;

destructor TSerialPort.Destroy;
begin
   Close;
   inherited Destroy;
end;

function TSerialPort.GetIsOpen: Boolean;
begin
   Result := FHandle <> NO_PORT;
end;

procedure TSerialPort.CheckHandle;
begin
   if not IsOpen then
      begin
      raise ESerialError.Create('Serial port not open');
      end;
end;

(* THE PORT NAME THE PLATFORM WANTS.

  On Windows a COM port above 9 can only be opened through the \\.\ device
  namespace -- 'COM10' fails and '\\.\COM10' works -- and the prefix is
  harmless below 10, so it is applied to every COMn name. A name that already
  carries it, or that is not a COMn at all, is passed through untouched.

  Everywhere else the name is a path and there is nothing to decorate. *)
function TSerialPort.DeviceName: string;
begin
   Result := FPortName;
   {$IFDEF WINDOWS}
   if (Pos('\\.\', Result) = 0) and (Copy(UpperCase(Result), 1, 3) = 'COM') then
      begin
      Result := '\\.\' + Result;
      end;
   {$ENDIF}
end;

procedure TSerialPort.OpenRaw(
  ABaudRate: DWORD;
  ADataBits: Byte;
  AStopBits: Byte;
  AParity: Byte;
  ARts: Boolean;
  ADtr: Boolean);
var
   parity: TParityType;
begin
   if IsOpen then
      begin
      Exit;
      end;

   if AParity > Ord(High(TParityType)) then
      begin
      raise ESerialError.CreateFmt(
         'Cannot open %s: parity %d is not none, odd or even',
         [FPortName, AParity]);
      end;
   parity := TParityType(AParity);

   (* EXPLICIT, not implicit. tr4wserial is FPC RTL code and compiles without
     the UnicodeStrings modeswitch, so its String is an AnsiString and the
     assignment would narrow silently. A device name is ASCII on every
     platform TR4W runs on -- COMn, /dev/ttyUSB0, /dev/cu.usbserial-A50285BI
     -- so there is nothing to lose, but the conversion is written down. *)
   FHandle := SerOpen(AnsiString(DeviceName));
   if FHandle = NO_PORT then
      begin
      raise ESerialError.CreateFmt('Cannot open %s', [FPortName]);
      end;

   (* No flow control, which is what the Win32 body asked for: it set fBinary
     and nothing else, so neither CTS output control nor XON/XOFF was ever in
     play on a TR4W serial link. *)
   SerSetParams(FHandle, ABaudRate, ADataBits, parity, AStopBits, []);

   (* EXPLICIT, because SerSetParams leaves both lines low. See the note at the
     top of the unit -- this is the one behaviour that does not survive the
     move on its own. *)
   SerSetDTR(FHandle, ADtr);
   SerSetRTS(FHandle, ARts);

   SerFlushInput(FHandle);
   SerFlushOutput(FHandle);
end;

procedure TSerialPort.SetDTR(aOn: Boolean);
begin
   if not IsOpen then
      begin
      Exit;
      end;
   {$IFDEF WINDOWS}
   if aOn then
      begin
      Windows.EscapeCommFunction(FHandle, Windows.SETDTR);
      end
   else
      begin
      Windows.EscapeCommFunction(FHandle, Windows.CLRDTR);
      end;
   {$ELSE}
   SerSetDTR(FHandle, aOn);
   {$ENDIF}
end;

procedure TSerialPort.SetRTS(aOn: Boolean);
begin
   if not IsOpen then
      begin
      Exit;
      end;
   {$IFDEF WINDOWS}
   if aOn then
      begin
      Windows.EscapeCommFunction(FHandle, Windows.SETRTS);
      end
   else
      begin
      Windows.EscapeCommFunction(FHandle, Windows.CLRRTS);
      end;
   {$ELSE}
   SerSetRTS(FHandle, aOn);
   {$ENDIF}
end;

procedure TSerialPort.Close;
begin
   if IsOpen then
      begin
      SerClose(FHandle);
      FHandle := NO_PORT;
      end;
end;

function TSerialPort.ReadString(MaxLen: Integer): string;
begin
   Result := string(TEncoding.ASCII.GetString(ReadBytes(MaxLen)));
end;

procedure TSerialPort.WriteString(const S: string);
begin
   (* Serial is a byte stream. Encode the (ASCII CAT) text to its wire bytes
     rather than writing the string's own code units: with UnicodeStrings,
     Length(S) is a code-unit count and not a byte count, and writing S[1]
     directly sent "F<00>A<00>..." for "FA...", breaking every serial radio. *)
   WriteBytes(TEncoding.ASCII.GetBytes(S));
end;

procedure TSerialPort.WriteBytes(const Data: TBytes);
begin
   if Length(Data) = 0 then
      begin
      Exit;
      end;
   CheckHandle;
   if SerWrite(FHandle, Data[0], Length(Data)) <> Length(Data) then
      begin
      raise ESerialError.CreateFmt('Short write on %s (%d byte(s))',
                                   [FPortName, Length(Data)]);
      end;
end;

function TSerialPort.ReadBytes(MaxLen: Integer): TBytes;
var
   buffer: array[0..1023] of byte;
   want:   Integer;
   got:    LongInt;
begin
   Result := nil;
   CheckHandle;

   want := MaxLen;
   if want > SizeOf(buffer) then
      begin
      want := SizeOf(buffer);
      end;
   if want <= 0 then
      begin
      Exit;
      end;

   (* SerReadTimeout, not SerRead: SerRead returns whatever happens to be
     buffered, immediately, which turns a reading thread into a spin loop. *)
   got := SerReadTimeout(FHandle, buffer, want, FReadTimeoutMs);
   if got <= 0 then
      begin
      Exit;
      end;

   SetLength(Result, got);
   Move(buffer[0], Result[0], got);
end;

end.
