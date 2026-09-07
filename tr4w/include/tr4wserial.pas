(* FreePascal's OWN serial unit, vendored so that it also exists on macOS.

  This is packages/rtl-extra/src/{win,unix}/serial.pp from FPC 3.2.2, by
  Sebastian Guenther and MarkMLl, under the FPC RTL licence (modified LGPL
  with the static-linking exception). It is not TR4W code and is not to be
  improved; see the note at the top of each .inc.

  WHY VENDOR SOMETHING THE RTL ALREADY SHIPS. FPC builds this unit for a
  fixed list of targets -- packages/rtl-extra/fpmake.pp:

    SerialOSes = [android, linux, netbsd, openbsd, win32, win64];

  and DARWIN IS NOT IN IT, in 3.2.2 or in the fpcupdeluxe tree. So there is
  no serial.ppu on a stock macOS FPC and `uses Serial` does not compile
  there, which for a program that has to run on a Mac is the end of the
  discussion however good the code is.

  The omission looks like a build-list oversight rather than a technical
  one. Everything the unix body needs is present on Darwin -- rtl/darwin
  builds `termio`, and rtl/darwin/termios.inc defines TIOCM_DTR, TIOCM_RTS
  and TIOCMBIS/BIC/GET/SET -- and the body already guards B460800 with
  {$ifndef BSD}. UNVERIFIED, though: nobody has built this on a Mac. That
  is the one thing to check first when TR4W is first compiled there.

  WHY ONE UNIT AND NOT TWO. FPC picks between its two files by directory,
  which our build cannot do without carrying platform-specific unit paths.
  The interfaces differ in exactly four places -- the uses clause,
  TSerialHandle, TSerialState, and {$PACKRECORDS C} -- so they are merged
  here and the bodies are included untouched.

  NOTHING IN TR4W CALLS THIS DIRECTLY. uSerialPort.TSerialPort is the only
  caller and the only thing the rest of the program sees. If FPC ever adds
  darwin to SerialOSes, this unit becomes deletable: change uSerialPort to
  use Serial and drop these three files. *)

unit tr4wserial;

{$MODE objfpc}
{$H+}
{$IFDEF UNIX}
{$PACKRECORDS C}
{$ENDIF}

interface

uses
  {$IFDEF WINDOWS}
  Windows;
  {$ELSE}
  BaseUnix, termio, unix;
  {$ENDIF}

type

  {$IFDEF WINDOWS}
  TSerialHandle = THandle;
  {$ELSE}
  TSerialHandle = LongInt;
  {$ENDIF}

  TParityType = (NoneParity, OddParity, EvenParity);

  TSerialFlags = set of (RtsCtsFlowControl);

  {$IFDEF WINDOWS}
  TSerialState = TDCB;
  {$ELSE}
  TSerialState = record
    LineState: LongWord;
    tios: termios;
  end;
  {$ENDIF}

(* The device name is the platform's own: \\.\COM1 and friends on Windows,
  /dev/ttyS0, /dev/ttyUSB0 or /dev/cu.usbserial-* on a Unix. SerOpen returns
  0 -- NOT INVALID_HANDLE_VALUE -- when it fails. *)

{ Open the serial device with the given device name, for example:
    \COM1, \COM2 (strictly, \\.\COM1...) for normal serial ports.
    ISDN devices, serial port redirectors/virtualisers etc. normally
    implement names of this form, but refer to your OS documentation.
  Returns "0" if device could not be found }
function SerOpen(const DeviceName: String): TSerialHandle;

{ Closes a serial device previously opened with SerOpen. }
procedure SerClose(Handle: TSerialHandle);

{ Flushes the data queues of the given serial device. DO NOT USE THIS:
  use either SerSync (non-blocking) or SerDrain (blocking). }
procedure SerFlush(Handle: TSerialHandle); deprecated;

{ Suggest to the kernel that buffered output data should be sent. This
  is unlikely to have a useful effect except possibly in the case of
  buggy ports that lose Tx interrupts, and is implemented as a preferred
  alternative to the deprecated SerFlush procedure. }
procedure SerSync(Handle: TSerialHandle);

{ Wait until all buffered output has been transmitted. It is the caller's
  responsibility to ensure that this won't block permanently due to an
  inappropriate handshake state. }
procedure SerDrain(Handle: TSerialHandle);

{ Discard all pending input. }
procedure SerFlushInput(Handle: TSerialHandle);

{ Discard all unsent output. }
procedure SerFlushOutput(Handle: TSerialHandle);

{ Reads a maximum of "Count" bytes of data into the specified buffer.
  Result: Number of bytes read. }
function SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;

{ Tries to write "Count" bytes from "Buffer".
  Result: Number of bytes written. }
function SerWrite(Handle: TSerialHandle; Const Buffer; Count: LongInt): LongInt;

procedure SerSetParams(Handle: TSerialHandle; BitsPerSec: LongInt;
  ByteSize: Integer; Parity: TParityType; StopBits: Integer;
  Flags: TSerialFlags);

{ Saves and restores the state of the serial device. }
function SerSaveState(Handle: TSerialHandle): TSerialState;
procedure SerRestoreState(Handle: TSerialHandle; State: TSerialState);

{ Getting and setting the line states directly. }
procedure SerSetDTR(Handle: TSerialHandle; State: Boolean);
procedure SerSetRTS(Handle: TSerialHandle; State: Boolean);
function SerGetCTS(Handle: TSerialHandle): Boolean;
function SerGetDSR(Handle: TSerialHandle): Boolean;
function SerGetCD(Handle: TSerialHandle): Boolean;
function SerGetRI(Handle: TSerialHandle): Boolean;

{ Set a line break state. If the requested time is greater than zero this is in
  mSec, in the case of unix this is likely to be rounded up to a few hundred
  mSec and to increase by a comparable increment; on unix if the time is less
  than or equal to zero its absolute value will be passed directly to the
  operating system with implementation-specific effect. If the third parameter
  is omitted or true there will be an implicit call of SerDrain() before and
  after the break.

  NOTE THAT on Linux, the only reliable mSec parameter is zero which results in
  a break of around 250 mSec. Might be completely ineffective on Solaris.
 }
(* THE DEFAULT DIFFERS BY PLATFORM, and upstream serial.pp declares it twice
  for that reason -- 250 on Windows, 0 on Unix.  The note above says why: zero
  is the only reliable value on Linux.  Merging the two interfaces into one
  file made that difference invisible, and the single Windows value did not
  match the Unix body: caught by Compile-Linux.ps1 on 2026-09-07. *)
{$IFDEF WINDOWS}
procedure SerBreak(Handle: TSerialHandle; mSec: LongInt= 250; sync: boolean= true);
{$ELSE}
procedure SerBreak(Handle: TSerialHandle; mSec: LongInt= 0; sync: boolean= true);
{$ENDIF}

type    TSerialIdle= procedure(h: TSerialHandle);

{ Set this to a shim around Application.ProcessMessages if calling SerReadTimeout(),
  SerBreak() etc. from the main thread so that it doesn't lock up a Lazarus app. }
var     SerialIdle: TSerialIdle= nil;

{ This is similar to SerRead() but adds a mSec timeout. Note that this variant
  returns as soon as a single byte is available, or as dictated by the timeout. }
function SerReadTimeout(Handle: TSerialHandle; var Buffer; mSec: LongInt): LongInt;

{ This is similar to SerRead() but adds a mSec timeout. Note that this variant
  attempts to accumulate as many bytes as are available, but does not exceed
  the timeout. Set up a SerIdle callback if using this in a main thread in a
  Lazarus app. }
function SerReadTimeout(Handle: TSerialHandle; var Buffer: array of byte; count, mSec: LongInt): LongInt;


{ ************************************************************************** }


{ ************************************************************************** }

implementation

{$IFDEF WINDOWS}
{$I tr4wserial_win.inc}
{$ELSE}
{$I tr4wserial_unix.inc}
{$ENDIF}

end.
