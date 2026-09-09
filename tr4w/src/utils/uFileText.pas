unit uFileText;

// Whole-file UTF-8 text I/O for the JSON config stores, owned rather than
// borrowed.
//
// The stores were written against System.IOUtils (TFile.ReadAllText /
// TFile.WriteAllBytes over TEncoding.UTF8).  FPC has no System.IOUtils, and
// the two operations actually used are a dozen lines each -- so this follows
// the same call uStrSearch and uAnsiStr already made in this tree: own the
// handful of routines rather than shim one RTL onto another and leave the
// semantics decided by whichever unit happened to be compiled in which mode.
//
// There is NO conditional compilation here by design.  Both compilers see
// identical source, so both produce identical bytes.
//
// ---------------------------------------------------------------------------
// The BOM rule, which is the whole reason this is not one line of code
// ---------------------------------------------------------------------------
// WRITING: no BOM, ever.  RFC 8259 forbids a byte-order mark at the start of
// JSON, and both Python's json.load and jq reject one.  That is why the stores
// called WriteAllBytes over GetBytes rather than WriteAllText, which would have
// emitted the encoding's preamble.  The rule here is INVERTED from
// src\lang\*.pas, which must KEEP their BOM -- see CLAUDE.md.
//
// READING: tolerate one.  We never write a BOM, but an operator editing the
// file by hand in Notepad can easily save one back, and a leading U+FEFF turns
// the first key into an unrecognised name with no error anywhere.  Stripping it
// on read is what Delphi's TFile.ReadAllText(path, encoding) did for us.

{$I ..\tr4w.inc}

interface

uses
   SysUtils;   // TBytes

// Reads the whole file as UTF-8 and returns it as the program's string type.
// A leading UTF-8 BOM is stripped.  Raises on I/O failure, exactly as
// TFile.ReadAllText did -- callers already guard with FileTextExists.
function ReadAllTextUTF8(const aFileName: string): string;

// Writes aText as UTF-8 with NO byte-order mark, replacing any existing file.
procedure WriteAllTextUTF8(const aFileName: string; const aText: string);

// Thin wrapper so callers do not need SysUtils just for the existence test,
// and so the whole file-access vocabulary of the config stores lives in one
// place.
function FileTextExists(const aFileName: string): Boolean;

// The rest of what System.IOUtils was being used for, mostly by the config
// store's own tests: whole-file bytes, deletion, and temp-file paths.  FPC's
// SysUtils has near-equivalents for some of these but not all (there is no
// GetTempDir in Delphi's SysUtils, and no TPath in FPC's), so both compilers
// get the same three lines rather than a conditional at every call site.
function ReadAllBytesFile(const aFileName: string): TBytes;
function DeleteFileIfExists(const aFileName: string): Boolean;

// Always ends with a path delimiter, so CombinePath is a plain concatenation.
function TempDirectory: string;
function CombinePath(const aDir, aName: string): string;

implementation

uses
   Classes;

function FileTextExists(const aFileName: string): Boolean;
begin
   Result := SysUtils.FileExists(aFileName);
end;

function ReadAllTextUTF8(const aFileName: string): string;
var
   stream : TFileStream;
   raw    : RawByteString;
   size   : Int64;
begin
   Result := '';

   stream := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite);
   try
      size := stream.Size;
      if size <= 0 then
         begin
         Exit;
         end;

      SetLength(raw, size);
      stream.ReadBuffer(raw[1], size);
   finally
      stream.Free;
   end;

   // EF BB BF -- see the BOM note in the unit header.
   if (Length(raw) >= 3) and
      (Byte(raw[1]) = $EF) and
      (Byte(raw[2]) = $BB) and
      (Byte(raw[3]) = $BF) then
      begin
      Delete(raw, 1, 3);
      end;

   Result := UTF8ToString(raw);
end;

(* WRITTEN BESIDE, THEN SWAPPED IN. NEVER STRAIGHT OVER THE TARGET.

  This opened the destination with fmCreate, which TRUNCATES IT TO ZERO BYTES
  before writing any. Every byte of the operator's configuration was destroyed
  at the start of each save, and only restored if the write then completed. A
  crash, a power cut or a full disk in that window left settings\tr4w.json
  empty or half-written -- the station's entire configuration, radios, keyers,
  messages and all, gone with nothing to recover from.

  It is not a hypothetical: this is the file TR4W rewrites every time a
  preference changes, so the window opens many times in a session.

  THE SEQUENCE KEEPS A COMPLETE COPY AT EVERY INSTANT:

      write   <file>.new     the new content, complete and closed
      rename  <file>     ->  <file>.bak
      rename  <file>.new ->  <file>
      delete  <file>.bak

  Interrupt it anywhere and a whole file exists as one of the three names.
  Compare with the old behaviour, where the interesting instant had a
  zero-byte file and nothing else.

  WHY NOT ONE rename OVER THE TOP, which is atomic on POSIX: it is not on
  Windows, where MoveFile refuses an existing destination and the atomic form
  is a Win32 call this program is trying to stop making. Two renames behave
  the same on all three platforms and need no conditional.

  THE .bak IS LEFT BEHIND IF THE SECOND RENAME FAILS, deliberately, and the
  exception names it. A stray file the operator can copy back beats a tidy
  directory with no configuration in it.

  This does not make the write transactional -- SQLite would, and that is the
  argument for the contest log. It removes the window in which a save destroys
  what it is replacing, which is the part that costs an operator their
  station. *)
procedure WriteAllTextUTF8(const aFileName: string; const aText: string);
var
   stream  : TFileStream;
   raw     : RawByteString;
   newName : string;
   bakName : string;
begin
   raw     := UTF8Encode(aText);
   newName := aFileName + '.new';
   bakName := aFileName + '.bak';

   (* A .new left by an earlier failure is not evidence of anything -- the
     content it holds was superseded by whatever is in the target now. *)
   DeleteFileIfExists(newName);

   stream := TFileStream.Create(newName, fmCreate);
   try
      if Length(raw) > 0 then
         begin
         // raw[1] is only legal for a non-empty string.
         stream.WriteBuffer(raw[1], Length(raw));
         end;
   finally
      (* Closed BEFORE the rename: the bytes must be handed to the filesystem
        while the old file is still the one on disk. *)
      stream.Free;
   end;

   if FileExists(aFileName) then
      begin
      DeleteFileIfExists(bakName);
      if not RenameFile(aFileName, bakName) then
         begin
         raise EInOutError.CreateFmt(
            'Could not set aside "%s" before replacing it. The new content is '
            + 'in "%s" and nothing has been lost.', [aFileName, newName]);
         end;
      end;

   if not RenameFile(newName, aFileName) then
      begin
      raise EInOutError.CreateFmt(
         'Could not put "%s" into place. The previous version is in "%s" and '
         + 'the new content is in "%s".', [aFileName, bakName, newName]);
      end;

   DeleteFileIfExists(bakName);
end;

function ReadAllBytesFile(const aFileName: string): TBytes;
var
   stream : TFileStream;
   size   : Int64;
begin
   SetLength(Result, 0);

   stream := TFileStream.Create(aFileName, fmOpenRead or fmShareDenyWrite);
   try
      size := stream.Size;
      if size <= 0 then
         begin
         Exit;
         end;

      SetLength(Result, size);
      stream.ReadBuffer(Result[0], size);
   finally
      stream.Free;
   end;
end;

function DeleteFileIfExists(const aFileName: string): Boolean;
begin
   Result := False;
   if SysUtils.FileExists(aFileName) then
      begin
      Result := SysUtils.DeleteFile(aFileName);
      end;
end;

function TempDirectory: string;
begin
   (* SysUtils.GetTempDir, NOT Windows.GetTempPathW.

     The comment that stood here justified the Win32 call by saying "Delphi's
     SysUtils has no GetTempDir and FPC has no TPath, so the Win32 call is the
     only spelling both compilers share". Both halves were true and the premise
     is not: this tree has one compiler now, and FPC's SysUtils declares
     GetTempDir on every platform it targets.

     It appends the trailing delimiter itself, so the extra
     IncludeTrailingPathDelimiter and the MAX_PATH buffer both go with it.

     ONE BEHAVIOUR DIFFERENCE, and it is worth naming rather than discovering:
     GetTempPathW falls back through TMP, TEMP, USERPROFILE and finally the
     Windows directory; FPC's reads TEMP then TMP and stops. A Windows machine
     with neither set would previously have got the Windows directory and now
     gets the '.\' below -- which is the same answer the old code gave when
     GetTempPathW failed outright, and a better one than %WINDIR%. *)
   Result := SysUtils.GetTempDir;
   if Result = '' then
      begin
      Result := '.' + PathDelim;
      Exit;
      end;

   Result := IncludeTrailingPathDelimiter(Result);
end;

function CombinePath(const aDir, aName: string): string;
begin
   if aDir = '' then
      begin
      Result := aName;
      Exit;
      end;

   Result := IncludeTrailingPathDelimiter(aDir) + aName;
end;

end.
