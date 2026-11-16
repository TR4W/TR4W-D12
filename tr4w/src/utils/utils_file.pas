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
  alone. Every sWriteFile / sWriteFileFromString TO THAT HANDLE after it that
  fails or writes short is remembered AGAINST THAT HANDLE: a write to any other
  file, anywhere in the program, neither fails this report nor hides its
  failure. CloseReportFile flushes and closes, then, only when aKeep is True and
  nothing failed, REPLACES the old file with the new one in one operation (the
  old file survives if that fails -- there is no moment with neither) and
  answers True; otherwise it deletes the partial file and answers False.
  ReportFileProblem(h) is the first reason, in the OS's words ('' when there was
  none), valid after either call, and after a FAILED open too (h is then -1).

  A report is told apart by its handle, so at most REPORT_FILE_SLOTS may be open
  at once; the one after that is refused, with the reason. *)
const
   REPORT_FILE_SLOTS = 8;

function OpenReportFile(var h: TFileHandle; const FileName: string): boolean;
function CloseReportFile(h: TFileHandle; aKeep: boolean): boolean;
function ReportFileProblem(h: TFileHandle): string;

(* THE SAME, FOR A REPORT WRITTEN WITH Write / WriteLn -- the post-contest
  reports, the SCP ASCII dumps. OpenReportText makes t a Text file whose bytes
  go through the checked handle above, so the report's own code is unchanged
  and its output is byte for byte what a Text file to the target gave (the RTL
  formats it; this is only the device under it). Close it with CloseReportText,
  NOT Close(t): that flushes t, closes the handle and replaces the target, with
  the same answers as CloseReportFile. ReportTextProblem is its
  ReportFileProblem. *)
function OpenReportText(var t: Text; const FileName: string): boolean;
function CloseReportText(var t: Text; aKeep: boolean): boolean;
function ReportTextProblem(var t: Text): string;
function TextReportHandle(var t: Text): TFileHandle;

implementation

(* Windows ONLY for MoveFileExW in ReplaceReportFile, and only by qualified
  name: its DeleteFile, CreateFile ... would otherwise shadow SysUtils' here. *)
{$IFDEF WINDOWS}
uses
   Windows;
{$ENDIF}

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

(* THE REPORT FILES THAT ARE OPEN (issue 313), ONE SLOT EACH, KEYED BY HANDLE.
  A slot holds a report's target, its partial file and the FIRST reason a write
  to ITS handle failed -- so the failure belongs to the report, where it used
  to be one unit-level string that every sWriteFile in the program could set
  (an unrelated log write could fail an export, and a later open cleared a
  failure the export had not yet reported). A slot stays, Active False, after
  its report is closed so that ReportFileProblem can still say why; it is
  reused by the next open. A private record: nothing outside this unit sees it.

  The slots are guarded by a critical section because sWriteFile is called from
  any thread; only a FAILED write, an open and a close take it. *)
type
   (* The text device keeps its handle in the RTL's TextRec.UserData bytes;
     reading and writing that slot goes through a typed pointer, not Move. *)
   PReportHandle = ^TFileHandle;

   TReportSlot = record
      Used: boolean;
      Active: boolean;
      Handle: TFileHandle;
      Target: string;
      Partial: string;
      Failure: string;
   end;

var
   (* ONE MORE THAN REPORT_FILE_SLOTS: the last is reserved for the reason a
     report was refused because every other slot was an open report. *)
   GReportSlots: array[0..REPORT_FILE_SLOTS] of TReportSlot;
   GReportLock: TRTLCriticalSection;

(* The slot holding aHandle, or -1. The caller holds GReportLock. *)
function FindReportSlot(aHandle: TFileHandle): integer;
var
   i: integer;
begin
   Result := -1;
   for i := Low(GReportSlots) to High(GReportSlots) do
      begin
      if GReportSlots[i].Used and (GReportSlots[i].Handle = aHandle) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

(* THE SLOT A NEW REPORT GOES IN, or -1 when every one is an open report: the
  one already holding this handle (a report closed behind our back, its number
  reused, or a second failed open, whose handle is -1), else a never-used one,
  else one whose report is finished. The caller holds GReportLock. *)
function ClaimReportSlot(aHandle: TFileHandle): integer;
var
   i: integer;
begin
   Result := FindReportSlot(aHandle);
   if Result >= 0 then
      begin
      Exit;
      end;
   for i := 0 to REPORT_FILE_SLOTS - 1 do
      begin
      if not GReportSlots[i].Used then
         begin
         Result := i;
         Exit;
         end;
      end;
   for i := 0 to REPORT_FILE_SLOTS - 1 do
      begin
      if not GReportSlots[i].Active then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

(* The first reason a report's file could not be written; later ones are
  consequences. A handle that is no open report's is not a report: nothing is
  recorded. *)
procedure NoteReportFailure(aHandle: TFileHandle; const aReason: string);
var
   i: integer;
begin
   EnterCriticalSection(GReportLock);
   try
      i := FindReportSlot(aHandle);
      if (i >= 0) and GReportSlots[i].Active and (GReportSlots[i].Failure = '') then
         begin
         GReportSlots[i].Failure := aReason;
         end;
   finally
      LeaveCriticalSection(GReportLock);
   end;
end;

(* THE RESULT OF ONE WRITE: aWritten is what FileWrite returned. A write that
  returns less than was asked, or -1, did not put the data on the disk -- a full
  disk gives a short count, not an error -- and is remembered, with the OS's
  words for it, against aHandle if that is an open report. *)
function NoteWrite(aHandle: TFileHandle; aWritten, aWanted: LongInt): boolean;
var
   reason: string;
begin
  Result := aWritten = aWanted;
  if not Result then
     begin
     (* GetLastOSError FIRST: nothing between FileWrite and here may disturb it. *)
     if aWritten < 0 then
        begin
        reason := SysUtils.SysErrorMessage(GetLastOSError);
        end
     else
        begin
        reason := 'only ' + IntToStr(aWritten) + ' of ' + IntToStr(aWanted) +
                  ' bytes were written (the disk may be full)';
        end;
     NoteReportFailure(aHandle, reason);
     end;
end;

function sWriteFile(hFile: TFileHandle; const Buffer; nNumberOfBytesToWrite: DWORD): boolean;
begin
  Result := NoteWrite(hFile, FileWrite(hFile, Buffer, nNumberOfBytesToWrite),
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
   Result := NoteWrite(hFile, FileWrite(hFile, sBuffer[1], Length(sBuffer)), Length(sBuffer));
end;

(* PUT A COMPLETE FILE IN PLACE OF THE OLD ONE IN A SINGLE OPERATION, so a
  failure leaves the old file as it was and there is no moment with neither
  (the earlier delete-then-rename had one: a crash or a sharing violation
  between the two lost the previous good report).

  Unix: RenameFile is rename(2), which replaces the target atomically.
  Windows: the RTL's RenameFile is MoveFileW, which REFUSES to replace -- that
  is why the old code deleted first -- so this asks for MoveFileExW with
  MOVEFILE_REPLACE_EXISTING, the OS's own replace. It is a raw call because the
  RTL has no replacing rename on Windows (verified in rtl/win/sysutils.pp), and
  it is one the FPC Windows unit already declares; no new external is added.
  On NTFS the replace is atomic; on a file system without that guarantee
  (FAT) it is still one call, and still never leaves neither file when it
  fails. *)
function ReplaceReportFile(const aPartial, aTarget: string): boolean;
begin
{$IFDEF WINDOWS}
   Result := Windows.MoveFileExW(PWideChar(UnicodeString(aPartial)),
                                 PWideChar(UnicodeString(aTarget)),
                                 Windows.MOVEFILE_REPLACE_EXISTING);
{$ELSE}
   Result := RenameFile(aPartial, aTarget);
{$ENDIF}
end;

function OpenReportFile(var h: TFileHandle; const FileName: string): boolean;
var
   partial: string;
   reason: string;
   i: integer;
begin
   partial := FileName + '.partial';
   Result := tOpenFileForWrite(h, partial);
   reason := '';
   if not Result then
      begin
      reason := SysUtils.SysErrorMessage(GetLastOSError);
      end;

   EnterCriticalSection(GReportLock);
   try
      i := ClaimReportSlot(h);
      if i < 0 then
         begin
         (* Every slot is an open report: refuse rather than lose track of one.
           The reason is kept in the slot reserved for it, under handle -1. *)
         if Result then
            begin
            FileClose(h);
            SysUtils.DeleteFile(partial);
            h := TFileHandle(feInvalidHandle);
            Result := False;
            end;
         i := REPORT_FILE_SLOTS;
         reason := 'too many report files are open at once';
         end;

      GReportSlots[i].Used := True;
      GReportSlots[i].Active := Result;
      GReportSlots[i].Handle := h;
      GReportSlots[i].Target := FileName;
      GReportSlots[i].Partial := partial;
      GReportSlots[i].Failure := reason;
   finally
      LeaveCriticalSection(GReportLock);
   end;
end;

function CloseReportFile(h: TFileHandle; aKeep: boolean): boolean;
var
   i: integer;
   target: string;
   partial: string;
   failure: string;
begin
   Result := False;
   EnterCriticalSection(GReportLock);
   try
      i := FindReportSlot(h);
      if (i < 0) or (not GReportSlots[i].Active) then
         begin
         (* Not an open report: all there is to do is close what was handed in. *)
         if h <> TFileHandle(feInvalidHandle) then
            begin
            FileClose(h);
            end;
         Exit;
         end;
      target := GReportSlots[i].Target;
      partial := GReportSlots[i].Partial;
      failure := GReportSlots[i].Failure;
   finally
      LeaveCriticalSection(GReportLock);
   end;

   if aKeep and (failure = '') and (not FileFlush(h)) then
      begin
      failure := SysUtils.SysErrorMessage(GetLastOSError);
      end;
   FileClose(h);

   if aKeep and (failure = '') then
      begin
      (* The old file is replaced only now that the new one is complete and
        flushed, and in one operation -- see ReplaceReportFile. *)
      if ReplaceReportFile(partial, target) then
         begin
         Result := True;
         end
      else
         begin
         failure := SysUtils.SysErrorMessage(GetLastOSError);
         end;
      end;

   if (not Result) and FileExists(partial) then
      begin
      SysUtils.DeleteFile(partial);
      end;

   EnterCriticalSection(GReportLock);
   try
      i := FindReportSlot(h);
      if i >= 0 then
         begin
         GReportSlots[i].Active := False;
         GReportSlots[i].Failure := failure;
         end;
   finally
      LeaveCriticalSection(GReportLock);
   end;
end;

function ReportFileProblem(h: TFileHandle): string;
var
   i: integer;
begin
   Result := '';
   EnterCriticalSection(GReportLock);
   try
      i := FindReportSlot(h);
      if i >= 0 then
         begin
         Result := GReportSlots[i].Failure;
         end;
   finally
      LeaveCriticalSection(GReportLock);
   end;
end;

(* A TEXT FILE WHOSE DEVICE IS THE CHECKED HANDLE. FPC lets a Text be bound to
  any device by giving it its own open / write / close functions (the Text file
  reference's "assigning a text device"); the RTL still does all the
  formatting, buffering and line endings, so what Write and WriteLn produce is
  unchanged -- only where the bytes go is. The device keeps the report's
  handle in the TextRec's UserData. TextRec is the RTL's record, and reaching
  into it is how the RTL documents a custom device. *)
function TextReportHandle(var t: Text): TFileHandle;
begin
   Result := PReportHandle(@TextRec(t).UserData)^;
end;

function ReportTextWrite(var t: TextRec): LongInt;
var
   h: TFileHandle;
begin
   h := PReportHandle(@t.UserData)^;
   if t.BufPos > 0 then
      begin
      (* The result is remembered against h by sWriteFile; the RTL is told
        nothing, so a failing report does not raise in the middle of it. *)
      sWriteFile(h, t.BufPtr^, t.BufPos);
      end;
   t.BufPos := 0;
   Result := 0;
end;

function ReportTextClose(var t: TextRec): LongInt;
begin
   (* The handle is closed by CloseReportFile, which knows whether to keep. *)
   Result := 0;
end;

function ReportTextOpen(var t: TextRec): LongInt;
begin
   t.InOutFunc := @ReportTextWrite;
   t.FlushFunc := @ReportTextWrite;
   t.CloseFunc := @ReportTextClose;
   Result := 0;
end;

function OpenReportText(var t: Text; const FileName: string): boolean;
var
   h: TFileHandle;
begin
   Result := OpenReportFile(h, FileName);
   Assign(t, EmptyStr);
   PReportHandle(@TextRec(t).UserData)^ := h;
   if not Result then
      begin
      Exit;
      end;
   TextRec(t).OpenFunc := @ReportTextOpen;
{$I-}
   Rewrite(t);
{$I+}
   if IOResult <> 0 then
      begin
      NoteReportFailure(h, 'the report could not be started');
      CloseReportFile(h, False);
      Result := False;
      end;
end;

function CloseReportText(var t: Text; aKeep: boolean): boolean;
var
   h: TFileHandle;
begin
   h := TextReportHandle(t);
   if TextRec(t).Mode = fmOutput then
      begin
      (* Flush the RTL's buffer through the device, then let it go. *)
{$I-}
      Close(t);
{$I+}
      IOResult;
      end;
   Result := CloseReportFile(h, aKeep);
end;

function ReportTextProblem(var t: Text): string;
begin
   Result := ReportFileProblem(TextReportHandle(t));
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

initialization
   InitCriticalSection(GReportLock);

finalization
   DoneCriticalSection(GReportLock);

end.


