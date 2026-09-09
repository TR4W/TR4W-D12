unit uOpenSSLLoader;
{$I ..\tr4w.inc}
(*
  MAKE FPC'S OpenSSL LOADER FIND THE LIBRARY THIS MACHINE ACTUALLY HAS.

  Call EnsureOpenSSL once before the first HTTPS request.  It returns True when
  TLS is usable and False when it is not, and it never raises.

  WINDOWS NEEDS NOTHING AND GETS NOTHING.  FPC already looks for ssleay32.dll
  and libeay32.dll, which is exactly what the installer puts beside tr4w.exe --
  verified 2026-09-09 by fetching cty.dat with the bundled pair untouched.

  macOS HAS NO OpenSSL AT ALL, WHICH IS WORSE THAN A WRONG NAME.  Apple removed
  the shipped libssl years ago and there is no replacement in /usr/lib; the
  system's own TLS is LibreSSL reached through Security.framework, which FPC
  does not use.  Measured on an Apple Silicon Mac, 2026-09-09:

      ls /usr/lib/libssl*.dylib      no matches
      openssl version                LibreSSL 3.3.6   (the CLI, not a dylib)

  So FPC's default finds nothing and TR4W has no TLS on that platform at all.
  The Homebrew package supplies one, at a path this unit now looks in --
  measured, not guessed, which is the standard this unit was written to.  A Mac
  WITHOUT Homebrew still has no TLS: the durable answer is to ship the dylibs
  inside TR4W.app the way the Windows installer ships the DLLs, and that is a
  packaging decision rather than something to slip in here.

  LINUX IS THE PROBLEM, AND IT IS A NAME, NOT AN API.

  FPC 3.2.2 loads OpenSSL by trying `libssl.so` plus each entry of a hardcoded
  version list.  That list ends at .1.1 (openssl.pas:114) -- it predates
  OpenSSL 3 -- and the bare `libssl.so` it tries first is a symlink shipped by
  libssl-DEV, a package no operator installs.  A current distribution has

      libssl.so.3        libcrypto.so.3

  and nothing else, so TR4W could not fetch CTY.DAT on a machine whose SSL was
  in perfect order (NY4I, Linux Mint, 2026-09-09).

  THE API IS FINE.  Proved on the runner before this unit was written: with the
  NAME made resolvable and nothing else changed, FPC downloaded cty.dat from
  country-files.com, all 105,954 bytes of it.  OpenSSL 3 is API-compatible
  enough with 1.1 for FPC's bindings, so the only thing missing is a name FPC
  will try.

  SO WE GIVE IT ONE.  Find the real library, symlink it into a directory we own
  as plain `libssl.so`, and point DLLSSLName there -- FPC's first attempt is
  `<name>.so`, so it hits on the first try.  No root, no -dev package, no
  vendored copy of the RTL, and nothing written outside our own settings tree.

  WHY NOT PATCH FPC'S UNIT INSTEAD: DLLVersions is a const, so it cannot be
  changed at run time, and vendoring five thousand lines of RTL to alter one
  array is a maintenance burden that outlives the problem -- FPC fixed it
  upstream after 3.2.2.  When the toolchain moves, EnsureOpenSSL's first
  attempt simply succeeds and the rest of this unit stops running.

  WHY NOT INDY, which is what this program used before: Indy 10.6.3.3 does not
  fail to FIND OpenSSL 3, it REFUSES it -- "Unsupported SSL Library version:
  300000D0" -- with and without the symlink, measured both ways.  That is a
  hard version gate, and lifting it means Indy PR #529, which is unmerged and
  replaces the entire 22,000-line headers unit.  Indy keeps every other job it
  does here; only HTTPS moved.
*)

interface

(* True when TLS is usable.  Safe to call repeatedly -- the work happens once
  and the answer is remembered, including a negative one. *)
function EnsureOpenSSL: boolean;

(* What EnsureOpenSSL did, or could not do -- for the log and for the
  "Reason:" slot in the download failure dialog.  '' before the first call. *)
function OpenSSLDiagnostic: string;

implementation

uses
   SysUtils,
{$IFDEF UNIX}
   BaseUnix,
{$ENDIF}
   openssl,
   uAppPaths;

var
   GTried:      boolean = False;
   GUsable:     boolean = False;
   GDiagnostic: string  = '';

function OpenSSLDiagnostic: string;
begin
   Result := GDiagnostic;
end;

{$IFDEF UNIX}
(* SHARED BY BOTH UNIXES. These were written for Linux and then needed by the
  macOS arm too -- so they live above both rather than being copied, which is
  the whole reason this file has one loader and not two. *)

(* THE NEWEST ONE, NOT THE FIRST ONE.  A machine can carry several -- a distro
  libssl.so.3 beside a libssl.so.1.1 left by something older -- and picking by
  directory order would take whichever the loop happened to reach first.

  Compares the version tail NUMERICALLY, component by component, so .10 ranks
  above .9 rather than below it on a string compare.  A non-numeric tail
  (libssl.so.1.0.2k) stops the parse and keeps what was read, which is enough
  to rank it. *)
function VersionRank(const aName, aStem: string): int64;
var
   tail, part: string;
   i, parts:   integer;
begin
   Result := -1;
   if Copy(aName, 1, Length(aStem)) <> aStem then
      begin
      Exit;
      end;

   tail := Copy(aName, Length(aStem) + 1, MaxInt);
   if tail = '' then
      begin
      Exit;
      end;

   Result := 0;
   parts  := 0;
   part   := '';
   for i := 1 to Length(tail) + 1 do
      begin
      if (i > Length(tail)) or (tail[i] = '.') then
         begin
         if parts >= 3 then
            begin
            Break;
            end;
         Result := Result * 1000 + StrToIntDef(part, 0);
         Inc(parts);
         part := '';
         end
      else if (tail[i] >= '0') and (tail[i] <= '9') then
         begin
         part := part + tail[i];
         end
      else
         begin
         Break;
         end;
      end;

   (* Pad to a fixed width so '3' outranks '1.1' instead of losing to it on
     digit count alone. *)
   while parts < 3 do
      begin
      Result := Result * 1000;
      Inc(parts);
      end;
end;

(* Link under an EXACT name, for the macOS case where the name FPC will try
  is not <base>.so. *)
function LinkAs(const aDir, aLinkName, aTarget: string): boolean;
var
   link:      string;
   linkBytes: AnsiString;
   destBytes: AnsiString;
begin
   link      := IncludeTrailingPathDelimiter(aDir) + aLinkName;
   linkBytes := AnsiString(link);
   destBytes := AnsiString(aTarget);
   fpUnlink(linkBytes);
   Result := fpSymlink(PAnsiChar(destBytes), PAnsiChar(linkBytes)) = 0;
end;

{$ENDIF}

{$IFDEF DARWIN}
(* WHERE A MAC KEEPS AN OpenSSL SOMEONE ELSE INSTALLED.  Homebrew on Apple
  Silicon lives under /opt/homebrew and on Intel under /usr/local, and it
  already provides the unversioned libssl.dylib symlink that FPC's loader
  wants -- so unlike Linux there is nothing to link, only a directory to name.
  MacPorts is included because it is the other common answer.

  Each of these was checked on a real machine or is the documented prefix of
  its package manager.  A directory that is not there is skipped. *)
function DarwinSSLDirs: TStringArray;
begin
   Result := TStringArray.Create(
      '/opt/homebrew/opt/openssl@3/lib',
      '/opt/homebrew/opt/openssl/lib',
      '/opt/homebrew/lib',
      '/usr/local/opt/openssl@3/lib',
      '/usr/local/opt/openssl/lib',
      '/usr/local/lib',
      '/opt/local/lib');
end;

(* The newest <base>.N.dylib in one directory, or '' -- Homebrew names them
  libssl.3.dylib. Ranked the same way as the Linux arm so a machine carrying
  both 1.1 and 3 gets 3. *)
function NewestDylib(const aDir, aBaseName: string): string;
var
   rec:  TSearchRec;
   rank: int64;
   best: int64;
begin
   Result := '';
   best   := -1;
   if not DirectoryExists(aDir) then
      begin
      Exit;
      end;

   if FindFirst(IncludeTrailingPathDelimiter(aDir) + aBaseName + '.*.dylib',
                faAnyFile, rec) = 0 then
      begin
      try
         repeat
            (* Reuse the shared ranker by handing it the same shape it expects:
              the stem it strips is "<base>." and the tail here ends '.dylib',
              which stops the numeric parse exactly as a letter suffix does. *)
            rank := VersionRank(rec.Name, aBaseName + '.');
            if rank > best then
               begin
               best   := rank;
               Result := IncludeTrailingPathDelimiter(aDir) + rec.Name;
               end;
         until FindNext(rec) <> 0;
      finally
         FindClose(rec);
      end;
      end;
end;
{$ENDIF}

{$IFDEF LINUX}
(* The directories a distribution puts its shared libraries in.  Multiarch
  first, because that is where Debian and its derivatives keep them.  A wrong
  guess costs nothing -- a directory that is not there is skipped. *)
function LibrarySearchDirs: TStringArray;
begin
   Result := TStringArray.Create(
      '/usr/lib/' + {$I %FPCTARGETCPU%} + '-linux-gnu',
      '/usr/lib64',
      '/usr/lib',
      '/lib/' + {$I %FPCTARGETCPU%} + '-linux-gnu',
      '/lib64',
      '/lib',
      '/usr/local/lib');
end;

function NewestLibrary(const aBaseName: string): string;
var
   dirs: TStringArray;
   stem: string;
   rec:  TSearchRec;
   d:    integer;
   rank: int64;
   best: int64;
begin
   Result := '';
   best   := -1;
   stem   := aBaseName + '.so.';
   dirs   := LibrarySearchDirs;

   for d := 0 to High(dirs) do
      begin
      if not DirectoryExists(dirs[d]) then
         begin
         Continue;
         end;

      if FindFirst(IncludeTrailingPathDelimiter(dirs[d]) + aBaseName + '.so.*',
                   faAnyFile, rec) = 0 then
         begin
         try
            repeat
               rank := VersionRank(rec.Name, stem);
               if rank > best then
                  begin
                  best   := rank;
                  Result := IncludeTrailingPathDelimiter(dirs[d]) + rec.Name;
                  end;
            until FindNext(rec) <> 0;
         finally
            FindClose(rec);
            end;
         end;
      end;
end;

(* Point a plain `<dir>/<base>.so` at the real file.  REPLACES an existing link
  rather than trusting it: the machine may have been upgraded since we last
  ran, and a symlink to a library that is gone is worse than no link at all. *)
function LinkInto(const aDir, aBaseName, aTarget: string): boolean;
var
   link:      string;
   linkBytes: AnsiString;
   destBytes: AnsiString;
begin
   link := IncludeTrailingPathDelimiter(aDir) + aBaseName + '.so';

   (* A REAL C BOUNDARY, so PAnsiChar here is the justified kind -- fpSymlink
     is a thin wrapper over the symlink(2) system call and takes NUL-terminated
     bytes by definition. Two things about it are not obvious:

     PChar WOULD BE WRONG. `string` in this program is UnicodeString, so PChar
     means PWideChar, and the compiler says so:

         Incompatible type for arg no. 2: Got "PWideChar", expected "PChar"

     NAMED LOCALS, NOT PAnsiChar(AnsiString(expr)). A pointer taken from a
     temporary is valid only until the compiler decides the temporary is dead,
     which this tree has been bitten by before. Holding the AnsiString in a
     variable makes the lifetime the variable's, which outlives the call. *)
   linkBytes := AnsiString(link);
   destBytes := AnsiString(aTarget);

   fpUnlink(linkBytes);
   Result := fpSymlink(PAnsiChar(destBytes), PAnsiChar(linkBytes)) = 0;
end;
{$ENDIF}

function EnsureOpenSSL: boolean;
{$IFDEF LINUX}
var
   sslPath:    string;
   cryptoPath: string;
   dir:        string;
{$ENDIF}
{$IFDEF DARWIN}
var
   dir:        string;
   linkDir:    string;
   sslPath:    string;
   cryptoPath: string;
   i:          integer;
{$ENDIF}
begin
   if GTried then
      begin
      Result := GUsable;
      Exit;
      end;
   GTried := True;

   (* FIRST, JUST ASK.  On Windows, on macOS, on a Linux box that has the -dev
     symlink, and on any future FPC whose version list has caught up, this
     succeeds and nothing below ever runs. *)
   if InitSSLInterface then
      begin
      GUsable     := True;
      GDiagnostic := 'OpenSSL loaded as ' + DLLSSLName;
      Result      := True;
      Exit;
      end;

{$IFDEF LINUX}
   sslPath    := NewestLibrary('libssl');
   cryptoPath := NewestLibrary('libcrypto');

   if (sslPath = '') or (cryptoPath = '') then
      begin
      GDiagnostic := 'no OpenSSL library found -- looked for libssl.so.* and '
                     + 'libcrypto.so.* in the usual library directories';
      Result := False;
      Exit;
      end;

   dir := IncludeTrailingPathDelimiter(SettingsDir) + 'ssl';
   if not ForceDirectories(dir) then
      begin
      GDiagnostic := 'found ' + sslPath + ' but could not create ' + dir;
      Result := False;
      Exit;
      end;

   if not (LinkInto(dir, 'libssl', sslPath) and
           LinkInto(dir, 'libcrypto', cryptoPath)) then
      begin
      GDiagnostic := 'found ' + sslPath + ' but could not link it into ' + dir;
      Result := False;
      Exit;
      end;

   (* FPC appends '.so' to this, so name the STEM and not the file. *)
   DLLSSLName  := IncludeTrailingPathDelimiter(dir) + 'libssl';
   DLLUtilName := IncludeTrailingPathDelimiter(dir) + 'libcrypto';

   if InitSSLInterface then
      begin
      GUsable     := True;
      GDiagnostic := 'OpenSSL loaded from ' + sslPath + ' via ' + DLLSSLName;
      Result      := True;
      Exit;
      end;

   GDiagnostic := 'found ' + sslPath + ' and linked it, but OpenSSL still '
                  + 'would not initialise';
   Result := False;
{$ELSE}
{$IFDEF DARWIN}
   (* THE LINK IS NAMED .1.1 ON PURPOSE, AND IT IS NOT A MISTAKE.

     FPC will not try the unversioned name on this platform. LoadLibraries
     does this before it looks for anything (openssl.pas:5620):

         {$IFDEF DARWIN}
           // Mac OS no longer allows you to load the unversioned one.
           DLLVERSIONS[1]:=DLLVERSIONS[2];
         {$ENDIF}

     -- it OVERWRITES the empty first entry with '.1.1'. So on macOS the names
     FPC ever attempts are libssl.1.1.dylib, .11, .10, .1.0.2 and older. Plain
     libssl.dylib is deliberately skipped, and .3 is not in the list at all,
     because the list predates OpenSSL 3.

     Homebrew ships exactly the two forms FPC will not try: libssl.dylib and
     libssl.3.dylib. That is why a Mac with a perfectly good OpenSSL installed
     still had no TLS -- measured on an Apple Silicon Mac, 2026-09-09, where
     FPC's own LoadLibrary opened the file happily when handed the full name.

     So we hand it a name it WILL try. The link says 1.1 and points at
     OpenSSL 3; nothing reads that number as a version -- it is a file name
     FPC's search happens to attempt first, and the library reports its real
     version once loaded. Renaming a library to be found is ugly. Shipping our
     own copy inside TR4W.app is the answer that removes the need, and that is
     packaging work with notarization consequences. *)
   for i := 0 to High(DarwinSSLDirs) do
      begin
      dir := DarwinSSLDirs[i];
      sslPath    := NewestDylib(dir, 'libssl');
      cryptoPath := NewestDylib(dir, 'libcrypto');
      if (sslPath = '') or (cryptoPath = '') then
         begin
         Continue;
         end;

      linkDir := IncludeTrailingPathDelimiter(SettingsDir) + 'ssl';
      if not ForceDirectories(linkDir) then
         begin
         GDiagnostic := 'found ' + sslPath + ' but could not create ' + linkDir;
         Result := False;
         Exit;
         end;

      if LinkAs(linkDir, 'libssl.1.1.dylib', sslPath) and
         LinkAs(linkDir, 'libcrypto.1.1.dylib', cryptoPath) then
         begin
         DLLSSLName  := IncludeTrailingPathDelimiter(linkDir) + 'libssl';
         DLLUtilName := IncludeTrailingPathDelimiter(linkDir) + 'libcrypto';
         if InitSSLInterface then
            begin
            GUsable     := True;
            GDiagnostic := 'OpenSSL loaded from ' + sslPath + ' via ' + DLLSSLName;
            Result      := True;
            Exit;
            end;
         end;
      end;

   GDiagnostic := 'no OpenSSL found. macOS does not ship one -- install it '
                  + 'with "brew install openssl@3", or use a TR4W.app that '
                  + 'carries its own copy.';
   Result := False;
{$ELSE}
   GDiagnostic := 'OpenSSL could not be initialised (' + DLLSSLName + ')';
   Result := False;
{$ENDIF}
{$ENDIF}
end;

end.
