unit utils_file;
{$I ..\tr4w.inc}

interface

(* THE RTL'S FILE HANDLES, NOT WIN32'S (2026-09-07).

  Every routine here was a thin wrapper over CreateFileA / ReadFile /
  WriteFile / FindFirstFileA, and SysUtils has an exact counterpart for each
  that works on every platform FPC targets -- FileCreate, FileRead, FileWrite,
  FileGetAttr -- all of them already taking the same THandle.

  So this is a swap, not a redesign: the interface is unchanged except that
  BOOL (a Windows type) becomes boolean, and the semantics of each routine are
  preserved deliberately, including one that is arguably wrong. See FileExists.

  It is worth doing because this unit is TWO LEVELS DOWN: uCTYDAT could not
  compile off Windows while utils_file could not, and uCallSignRoutines could
  not while uCTYDAT could not. Ninety-seven lines here unblock a chain. *)

uses SysUtils;

function FileExists(FileName: PAnsiChar): boolean;

function sWriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD): boolean;
function sWriteFileFromString(hFile: THandle; sBuffer: AnsiString): boolean;
function tWriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD; var lpNumberOfBytesWritten: DWORD): boolean;
function sReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD): boolean;

function tOpenFileForWrite(var h: THandle; FileName: PAnsiChar): boolean;
function OpenFileForWrite(var FileHandle: Text; FileName: string): boolean;

implementation

(* FileGetAttr, NOT SysUtils.FileExists, AND THE DIFFERENCE IS DELIBERATE.

  This was FindFirstFileA, which succeeds for a DIRECTORY as well as a file.
  SysUtils.FileExists does not -- it excludes directories on Windows -- so the
  obvious substitution would quietly change the answer for 76 call sites, in a
  function whose name makes that change invisible at every one of them.

  FileGetAttr returns -1 only when the name resolves to nothing, so it matches
  the old behaviour exactly and is portable. Whether "a directory exists as a
  file" is the RIGHT answer is a separate question, and not one to settle by
  accident inside a cross-platform sweep.

  The one thing genuinely lost is wildcards: FindFirstFileA('*.dat') would
  have succeeded. No caller passes one -- checked, all 76. *)
function FileExists(FileName: PAnsiChar): boolean;
begin
  Result := FileGetAttr(AnsiString(FileName)) <> -1;
end;

function tWriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD; var lpNumberOfBytesWritten: DWORD): boolean;
var
  written: LongInt;
begin
  (* FileWrite RETURNS THE COUNT, where WriteFile returned a flag and filled
    the count in through a var parameter -- so the two halves swap places.
    -1 is the failure, and a SHORT write is a success in both (WriteFile
    returned True having written fewer bytes; so does this). *)
  written := FileWrite(hFile, Buffer, nNumberOfBytesToWrite);
  Result  := written >= 0;
  if Result then
     begin
     lpNumberOfBytesWritten := written;
     end
  else
     begin
     lpNumberOfBytesWritten := 0;
     end;
end;

function sReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD): boolean;
begin
  (* A read of zero bytes at end of file is SUCCESS, exactly as ReadFile
    reported it -- the count was already discarded here, so callers have
    always distinguished EOF some other way. *)
  Result := FileRead(hFile, Buffer, nNumberOfBytesToRead) >= 0;
end;

function sWriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD): boolean;
begin
  Result := FileWrite(hFile, Buffer, nNumberOfBytesToWrite) >= 0;
end;

function sWriteFileFromString(hFile: THandle; sBuffer: AnsiString): boolean;
// Write the entire string to hFile.  Bug history: prior versions copied
// sBuffer into a fixed 256-byte stack buffer via StrLCopy and then asked
// WriteFile to write length(sBuffer) bytes -- which read random stack
// data past the end of the buffer for any input >= 256 chars.  Old code
// happened to work because every caller passed a short fragment; the
// ADIF export refactor (Issue #887) writes the whole document in one
// call and immediately tripped the bug.  Write the string contents
// directly -- no fixed buffer, no length cap.
begin
   if sBuffer = '' then
      begin
      Result := True;
      Exit;
      end;
   Result := FileWrite(hFile, sBuffer[1], Length(sBuffer)) >= 0;
end;

function tOpenFileForWrite(var h: THandle; FileName: PAnsiChar): boolean;
begin
  (* FileCreate IS CREATE_ALWAYS: it makes the file, or truncates one that is
    already there, and opens it read/write -- which is what the flags this
    replaces spelled out. It returns feInvalidHandle (-1) on failure. *)
  h := FileCreate(AnsiString(FileName), fmShareDenyNone, 438 {rw-rw-rw-});
  Result := h <> THandle(feInvalidHandle);
end;

function OpenFileForWrite(var FileHandle: Text; FileName: string): boolean;

begin
  Assign(FileHandle, FileName);
{$I-}
  ReWrite(FileHandle);
{$I+}
  OpenFileForWrite := IORESULT = 0;
end;


end.


