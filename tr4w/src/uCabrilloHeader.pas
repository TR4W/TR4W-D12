unit uCabrilloHeader;
{$I tr4w.inc}
{
  THE EXPORT HEADERS -- name, club, location, address, the CATEGORY-* tags, and
  ERMAK's operator roster.

  These are tr4w.ini's [REPORT] and [ERMAKREPORT] sections, moved to
  settings\tr4w.json.  They were the LAST things keeping tr4w.ini load-bearing
  (NY4I, 2026-08-16: "I absolutely do not want the INI file coming back any
  more"; 2026-08-17, on ERMAK: "Nothing should use the INI file again").

  ONE PATH, N SECTIONS.  [REPORT] moved first and ERMAK was left behind for a
  day; the second move is a row in HEADER_SECTIONS rather than a second copy of
  load/save/seed, because two copies of a seed-once migration is exactly the
  shape that leaves one of them un-run.

  WHAT IT IS NOT.  These are not CFGCA rows and never were: no crS, no
  registration, absent from Preferences and from the search index.  The whole
  csOwned/csJSON migration was invisible to them, which is exactly why deleting
  tr4w.ini silently broke Cabrillo export -- PostUnit aborts a Winter Field Day
  or ARRL10 export when LOCATION is empty, and under headless /EXPORT there is
  no dialog to read it from, so [REPORT] was the only source.

  ONE GLOBAL HEADER, STILL.  Moving the storage does not change whose details
  these are: re-exporting a 2024 log stamps TODAY's address on it, exactly as
  before.  That is a real integrity problem and it is deliberately NOT fixed
  here -- doing both at once would mean a storage change and a behaviour change
  in one step, with the golden corpus unable to tell them apart because it
  normalises the header.  See docs/CFG_MIGRATION_PLAN.md.

  SEEDED ONCE, from whatever [REPORT] holds, so a station that has never opened
  the Cabrillo dialog keeps its header.  Without that the move would be the same
  silent data loss the settings migration had to fix twice.
}

interface

// The value for a header tag ('_LOCATION', '_CLUB', '_OP_INFO_101', ...) in one
// section ('REPORT', 'ERMAKREPORT'), or '' when unset.  Tag spellings are the
// ini's, so uCbrSum's tag table stays the one place that says what a header
// contains -- and ERMAK's roster keys keep the spelling uErmak already formats.
function HeaderValue(const aSection, aTag: string): string;

// Set one tag and persist immediately.  Immediately rather than on close: the
// Cabrillo dialog is the only writer and an operator who fills it in and then
// exports expects the export to see it.
procedure SetHeaderValue(const aSection, aTag, aValue: string);

// THE PAnsiChar FORM, for the Win32 dialog and export code that works in fixed
// buffers.  It lives here, once, because there were three copies of it by the
// time ERMAK moved -- uCbrSum, PostUnit and uErmak -- each pairing the same
// buffer conversion with its own if-ERMAK-then-ini fork, and the fork had
// already drifted (PostUnit's ini arm honoured the buffer size, the json arm
// did not).  aSize is the buffer size INCLUDING the terminator; the result is
// the length written, as GetPrivateProfileStringA returned.
function HeaderTagText(const aSection, aTag: PAnsiChar;
                       aBuffer: PAnsiChar; aSize: integer): cardinal;
procedure SetHeaderTagText(const aSection, aTag, aValue: PAnsiChar);

// Hold the save until EndHeaderBatch, for a caller that sets many tags at once.
// The ERMAK dialog writes 90 values (10 operators x 9 fields) when it closes,
// and SetHeaderValue's load-modify-save per tag would be 90 round trips through
// the whole config file.  Nestable, and End ALWAYS saves what Begin deferred --
// call it from a finally, or a cancelled dialog loses the roster it collected.
procedure BeginHeaderBatch;
procedure EndHeaderBatch;

// Drop the cache so the next read reloads.  For a caller that has replaced the
// store underneath us.
procedure InvalidateCabrilloHeader;

implementation

uses
   Windows,
   SysUtils,
   Classes,
   uAnsiStr,              // StrPLCopy / StrLen for the PAnsiChar form above
   Log4D,
   VC,                    // TR4W_INI_FILENAME, CABRILLOSECTION
   uRadioConfigStore,
   uKeyerConfigStore,
   uUDPBroadcastConfig,
   uTR4WConfigFile;       // LoadConfig / SaveConfig -- one file, three tenants

var
   // Own logger rather than MainUnit's global: this unit is linked by the
   // export path, which a standalone tool may drive without MainUnit.
   logger: TLogLogger;

   // Section name -> its Name=Value list, owned.  All sections load together:
   // the cost is one file read either way, and a per-section lazy load would
   // mean two code paths through the seed.
   GCache: TStringList = nil;
   GLoaded: boolean = False;
   GBatch: integer = 0;   // >0 while a caller is setting many tags at once

function StoreFileName: string;
begin
   // Derived the same way uRadioConfigApply derives it -- from the ini path, so
   // the two cannot disagree about which settings folder is in play.
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))))
             + 'tr4w.json';
end;

// Read every key in one ini section.  GetPrivateProfileSectionA returns the
// whole section as consecutive null-terminated 'KEY=VALUE' strings, so this
// needs no tag list of its own and cannot drift from uCbrSum's table.
//
// THE ONLY REMAINING READ OF tr4w.ini IN THIS UNIT, and it runs once per
// section per installation -- see the seed in EnsureLoaded.
procedure ReadIniSection(const aSection: string; const aInto: TStringList);
var
   buf: array[0..8191] of AnsiChar;
   sect: AnsiString;
   n: DWORD;
   p: PAnsiChar;
   entry: string;
begin
   Windows.ZeroMemory(@buf, SizeOf(buf));
   sect := AnsiString(aSection);
   n := Windows.GetPrivateProfileSectionA(PAnsiChar(sect), @buf, SizeOf(buf),
                                          @TR4W_INI_FILENAME[0]);
   if n = 0 then
      begin
      Exit;
      end;

   p := @buf;
   while p^ <> #0 do
      begin
      entry := string(AnsiString(p));
      if Pos('=', entry) > 1 then
         begin
         aInto.Values[Copy(entry, 1, Pos('=', entry) - 1)] :=
            Copy(entry, Pos('=', entry) + 1, MaxInt);
         end;
      Inc(p, Length(AnsiString(p)) + 1);
      end;
end;

// The cached list for one section, created on demand so a caller never has to
// test for nil and an unknown section reads as an empty header.
function CacheFor(const aSection: string): TStringList;
var
   idx: integer;
begin
   if GCache = nil then
      begin
      GCache := TStringList.Create;
      GCache.CaseSensitive := False;
      end;
   idx := GCache.IndexOf(aSection);
   if idx < 0 then
      begin
      Result := TStringList.Create;
      GCache.AddObject(aSection, Result);
      end
   else
      begin
      Result := TStringList(GCache.Objects[idx]);
      end;
end;

procedure ClearCache;
var
   i: integer;
begin
   if GCache = nil then
      begin
      Exit;
      end;
   for i := 0 to GCache.Count - 1 do
      begin
      GCache.Objects[i].Free;
      end;
   GCache.Clear;
end;

procedure EnsureLoaded;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
   i, s: integer;
   seededAny: boolean;
   mine: TStringList;
begin
   if GLoaded then
      begin
      Exit;
      end;

   ClearCache;
   GLoaded := True;      // set first: a failure below must not retry per tag

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      if FileExists(StoreFileName) then
         begin
         if not LoadConfig(StoreFileName, store, keyers, loadErr, udp) then
            begin
            logger.Warn('[CabrilloHeader] %s could not be read (%s); falling back to tr4w.ini',
                        [StoreFileName, loadErr]);
            end;
         end;

      seededAny := False;
      for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
         begin
         mine := CacheFor(HEADER_SECTIONS[s].Section);
         for i := 0 to store.Header(HEADER_SECTIONS[s].Section).Count - 1 do
            begin
            mine.Values[store.Header(HEADER_SECTIONS[s].Section).Names[i]] :=
               store.Header(HEADER_SECTIONS[s].Section).ValueFromIndex[i];
            end;

         // SEED ONCE, PER SECTION.  An empty section means this station has not
         // migrated yet, not that its header is empty -- so carry the ini
         // section across and save it.  Anything already in the store wins, so
         // this cannot undo a later edit.  Per section rather than "if nothing
         // at all is set": a station that has a Cabrillo header but no ERMAK
         // roster is the normal case, and an all-or-nothing test would leave
         // the ERMAK operators stranded in an ini nothing reads any more.
         if mine.Count = 0 then
            begin
            ReadIniSection(HEADER_SECTIONS[s].Section, mine);
            if mine.Count > 0 then
               begin
               store.Header(HEADER_SECTIONS[s].Section).Assign(mine);
               seededAny := True;
               logger.Info('[CabrilloHeader] seeded %d tag(s) from tr4w.ini [%s]',
                           [mine.Count, HEADER_SECTIONS[s].Section]);
               end;
            end;
         end;

      if seededAny then
         begin
         SaveConfig(StoreFileName, store, keyers, udp);
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

function HeaderValue(const aSection, aTag: string): string;
begin
   EnsureLoaded;
   Result := CacheFor(aSection).Values[aTag];
end;

// Write every cached section back to the store file.
procedure PersistHeaders;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
   s: integer;
begin
   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   udp    := TUDPBroadcastConfig.Create;
   try
      // All three libraries load and save together: they share one file, and
      // saving a store loaded without the others would drop their sections.
      if FileExists(StoreFileName) then
         begin
         if not LoadConfig(StoreFileName, store, keyers, loadErr, udp) then
            begin
            // REFUSE rather than write over a file we could not read.
            logger.Error('[CabrilloHeader] not saving: %s could not be read (%s)',
                         [StoreFileName, loadErr]);
            Exit;
            end;
         end;

      // Write back EVERY cached section, not just the one that changed: the
      // store was just re-loaded from disk, so a section left un-assigned would
      // be saved from the file rather than from the cache the program has been
      // reading -- and a set of REPORT would silently revert an unsaved ERMAK.
      for s := Low(HEADER_SECTIONS) to High(HEADER_SECTIONS) do
         begin
         store.Header(HEADER_SECTIONS[s].Section).Assign(
            CacheFor(HEADER_SECTIONS[s].Section));
         end;
      SaveConfig(StoreFileName, store, keyers, udp);
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure SetHeaderValue(const aSection, aTag, aValue: string);
begin
   EnsureLoaded;
   CacheFor(aSection).Values[aTag] := aValue;
   if GBatch = 0 then
      begin
      PersistHeaders;
      end;
end;

function HeaderTagText(const aSection, aTag: PAnsiChar;
                       aBuffer: PAnsiChar; aSize: integer): cardinal;
begin
   // BOUNDED.  GetPrivateProfileStringA honoured aSize and the callers pass
   // SizeOf(a stack array); the json arm each of them grew was written with
   // StrPCopy, which does not, so a header value longer than the buffer would
   // have run off the end.  Nothing in a header is that long today -- which is
   // exactly why it would have gone unnoticed.
   uAnsiStr.StrPLCopy(aBuffer,
                      AnsiString(HeaderValue(string(aSection), string(aTag))),
                      aSize - 1);
   Result := uAnsiStr.StrLen(aBuffer);
end;

procedure SetHeaderTagText(const aSection, aTag, aValue: PAnsiChar);
begin
   SetHeaderValue(string(aSection), string(aTag), string(aValue));
end;

procedure BeginHeaderBatch;
begin
   // Load INSIDE the batch, not at the first Set: EnsureLoaded may itself save
   // (the one-time ini seed), and a seed deferred to the end of the batch would
   // be overwritten by the batch's own write.
   EnsureLoaded;
   Inc(GBatch);
end;

procedure EndHeaderBatch;
begin
   if GBatch > 0 then
      begin
      Dec(GBatch);
      end;
   if GBatch = 0 then
      begin
      PersistHeaders;
      end;
end;

procedure InvalidateCabrilloHeader;
begin
   GLoaded := False;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.CabrilloHeader');

finalization
   ClearCache;
   FreeAndNil(GCache);

end.
