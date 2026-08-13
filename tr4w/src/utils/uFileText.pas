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
   Windows,
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

procedure WriteAllTextUTF8(const aFileName: string; const aText: string);
var
   stream : TFileStream;
   raw    : RawByteString;
begin
   raw := UTF8Encode(aText);

   stream := TFileStream.Create(aFileName, fmCreate);
   try
      if Length(raw) > 0 then
         begin
         // raw[1] is only legal for a non-empty string.
         stream.WriteBuffer(raw[1], Length(raw));
         end;
   finally
      stream.Free;
   end;
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
var
   buf : array[0..MAX_PATH] of Char;
   n   : DWORD;
begin
   // GetTempPathW rather than either RTL's helper: Delphi's SysUtils has no
   // GetTempDir and FPC has no TPath, so the Win32 call is the only spelling
   // both compilers share.  It already returns a trailing backslash, but say
   // so explicitly rather than rely on it.
   n := Windows.GetTempPathW(Length(buf), @buf[0]);
   if (n = 0) or (n > DWORD(Length(buf))) then
      begin
      Result := '.\';
      Exit;
      end;

   SetString(Result, PChar(@buf[0]), n);   // lint:wide-ok -- buf is Char, filled by GetTempPathW
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
