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
  preserved deliberately.

  FileExists, the one routine whose preserved semantics were arguably wrong (a
  directory counted as a file), is DELETED (2026-09-15). It shadowed
  SysUtils.FileExists by uses order; a census -- the routine marked deprecated
  for one build -- found four calls bound to it, and they now call
  SysUtils.FileExists by name.

  It is worth doing because this unit is TWO LEVELS DOWN: uCTYDAT could not
  compile off Windows while utils_file could not, and uCallSignRoutines could
  not while uCTYDAT could not. Ninety-seven lines here unblock a chain. *)

uses SysUtils;

(* THE FILE-HANDLE TYPE, NAMED HERE BECAUSE `THandle` IS AMBIGUOUS (2026-09-08).

  There are TWO types spelled THandle reachable from ordinary TR4W code, and
  which one a unit gets depends on the ORDER of its uses clause:

     System.THandle    the RTL's, what SysUtils' FileOpen/FileRead/FileClose
                       take, and what every routine below actually wants
     LCLType.THandle   `type PtrUInt`, a distinct type that Lazarus's own
                       source marks `deprecated 'Use TLCLHandle instead of
                       this redefined THandle'`

  A unit that names LCLType after SysUtils silently gets the second one. On
  32-bit Windows both are 32 bits and every call still compiles, so the tree
  carried the mix for as long as there was one target. Compiling for
  x86_64-linux produced `Call by var for arg no. 1 has to match exactly: Got
  "THandle" expected "LongInt"` in unit after unit -- six sites in postunit
  alone -- and THE SAME DIVERGENCE IS WAITING FOR 64-BIT WINDOWS.

  Naming it here rather than qualifying at 49 declaration sites has one
  concrete advantage: every caller of these routines ALREADY imports this unit
  in order to call them, so the type arrives with no uses-clause change and no
  chance of picking up the wrong THandle on the way in. It also says what the
  value IS, which `THandle` never did -- a window, a thread, a mutex and a file
  were all the same word. *)
type
  TFileHandle = System.THandle;

function sWriteFile(hFile: TFileHandle; const Buffer; nNumberOfBytesToWrite: DWORD): boolean;
function sWriteFileFromString(hFile: TFileHandle; sBuffer: AnsiString): boolean;
function tWriteFile(hFile: TFileHandle; const Buffer; nNumberOfBytesToWrite: DWORD; var lpNumberOfBytesWritten: DWORD): boolean;
function sReadFile(hFile: TFileHandle; var Buffer; nNumberOfBytesToRead: DWORD): boolean;
{ How many bytes the open file holds, WITHOUT moving the read position. }
function sFileSize(hFile: TFileHandle): Int64;

function tOpenFileForWrite(var h: TFileHandle; const FileName: string): boolean;
function OpenFileForWrite(var FileHandle: Text; FileName: string): boolean;

(* A REPORT OR EXPORT FILE THAT CANNOT LOOK COMPLETE WHEN IT IS NOT (issue 313).
  OpenReportFile opens FileName + '.partial' -- the previous good file is left
  alone -- and forgets any earlier failure. Every sWriteFile / sWriteFileFromString
  after it that fails or writes short is remembered. CloseReportFile flushes and
  closes, then, only when aKeep is True and nothing failed, puts the new file in
  place of the old and answers True; otherwise it deletes the partial file and
  answers False. ReportFileProblem is the first reason, in the OS's words ('' when
  there was none), valid after either call. *)
function OpenReportFile(var h: TFileHandle; const FileName: string): boolean;
function CloseReportFile(h: TFileHandle; aKeep: boolean): boolean;
function ReportFileProblem: string;

implementation

function tWriteFile(hFile: TFileHandle; const Buffer; nNumberOfBytesToWrite: DWORD; var lpNumberOfBytesWritten: DWORD): boolean;
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

(* SIZE WITHOUT MOVING THE POSITION, WHICH IS THE WHOLE DIFFICULTY.

  Callers had Windows.GetFileSize, which answers the question and leaves the
  file pointer alone. The RTL has no such call -- FileSeek is how you ask, and
  asking MOVES the pointer. A naive swap therefore looks right and silently
  changes where the next read starts; logscp does exactly that, taking the
  size and then reading the index array from the current position.

  So this saves the position, seeks to the end, and puts it back. *)
function sFileSize(hFile: TFileHandle): Int64;
var
  saved: Int64;
begin
  saved  := FileSeek(hFile, Int64(0), fsFromCurrent);
  Result := FileSeek(hFile, Int64(0), fsFromEnd);
  FileSeek(hFile, saved, fsFromBeginning);
end;

function sReadFile(hFile: TFileHandle; var Buffer; nNumberOfBytesToRead: DWORD): boolean;
begin
  (* A read of zero bytes at end of file is SUCCESS, exactly as ReadFile
    reported it -- the count was already discarded here, so callers have
    always distinguished EOF some other way. *)
  Result := FileRead(hFile, Buffer, nNumberOfBytesToRead) >= 0;
end;

var
  (* WHY THE LAST REPORT FILE COULD NOT BE WRITTEN, '' while nothing has gone
    wrong (issue 313). Set by the first failed or SHORT write through sWriteFile
    / sWriteFileFromString, cleared by OpenReportFile. One report is written at
    a time, on the main thread. *)
  GReportWriteFailure: string = '';
  GReportTarget: string = '';
  GReportPartial: string = '';

(* THE RESULT OF ONE WRITE: aWritten is what FileWrite returned. A write that
  returns less than was asked, or -1, did not put the data on the disk -- a full
  disk gives a short count, not an error -- and is remembered, with the OS's
  words for it. *)
function NoteWrite(aWritten, aWanted: LongInt): boolean;
begin
  Result := aWritten = aWanted;
  if (not Result) and (GReportWriteFailure = '') then
     begin
     if aWritten < 0 then
        begin
        GReportWriteFailure := SysUtils.SysErrorMessage(GetLastOSError);
        end
     else
        begin
        GReportWriteFailure := 'only ' + IntToStr(aWritten) + ' of ' + IntToStr(aWanted) +
                               ' bytes were written (the disk may be full)';
        end;
     end;
end;

function sWriteFile(hFile: TFileHandle; const Buffer; nNumberOfBytesToWrite: DWORD): boolean;
begin
  Result := NoteWrite(FileWrite(hFile, Buffer, nNumberOfBytesToWrite),
                      nNumberOfBytesToWrite);
end;

function sWriteFileFromString(hFile: TFileHandle; sBuffer: AnsiString): boolean;
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
   Result := NoteWrite(FileWrite(hFile, sBuffer[1], Length(sBuffer)), Length(sBuffer));
end;

function OpenReportFile(var h: TFileHandle; const FileName: string): boolean;
begin
   GReportTarget := FileName;
   GReportPartial := FileName + '.partial';
   GReportWriteFailure := '';
   Result := tOpenFileForWrite(h, GReportPartial);
   if not Result then
      begin
      GReportWriteFailure := SysUtils.SysErrorMessage(GetLastOSError);
      end;
end;

function CloseReportFile(h: TFileHandle; aKeep: boolean): boolean;
begin
   Result := False;
   if aKeep and (GReportWriteFailure = '') and (not FileFlush(h)) then
      begin
      GReportWriteFailure := SysUtils.SysErrorMessage(GetLastOSError);
      end;
   FileClose(h);

   if aKeep and (GReportWriteFailure = '') then
      begin
      (* The old file goes only now that the new one is complete and flushed.
        RenameFile will not replace on Windows, hence the delete. *)
      if FileExists(GReportTarget) then
         begin
         SysUtils.DeleteFile(GReportTarget);
         end;
      if RenameFile(GReportPartial, GReportTarget) then
         begin
         Result := True;
         end
      else
         begin
         GReportWriteFailure := SysUtils.SysErrorMessage(GetLastOSError);
         end;
      end;

   if (not Result) and FileExists(GReportPartial) then
      begin
      SysUtils.DeleteFile(GReportPartial);
      end;
end;

function ReportFileProblem: string;
begin
   Result := GReportWriteFailure;
end;

function tOpenFileForWrite(var h: TFileHandle; const FileName: string): boolean;
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


