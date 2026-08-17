unit uCabrilloHeader;
{$I tr4w.inc}
{
  THE CABRILLO HEADER -- name, club, location, address, the CATEGORY-* tags.

  This is tr4w.ini's [REPORT] section, moved to settings\tr4w.json.  It was the
  LAST thing keeping tr4w.ini load-bearing (NY4I, 2026-08-16: "I absolutely do
  not want the INI file coming back any more").

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

// The value for a header tag ('_LOCATION', '_CLUB', ...), or '' when unset.
// Tag spellings are the ini's, so uCbrSum's tag table stays the one place that
// says what a header contains.
function CabrilloHeaderValue(const aTag: string): string;

// Set one tag and persist immediately.  Immediately rather than on close: the
// Cabrillo dialog is the only writer and an operator who fills it in and then
// exports expects the export to see it.
procedure SetCabrilloHeaderValue(const aTag, aValue: string);

// Drop the cache so the next read reloads.  For a caller that has replaced the
// store underneath us.
procedure InvalidateCabrilloHeader;

implementation

uses
   Windows,
   SysUtils,
   Classes,
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

   GCache: TStringList = nil;
   GLoaded: boolean = False;

function StoreFileName: string;
begin
   // Derived the same way uRadioConfigApply derives it -- from the ini path, so
   // the two cannot disagree about which settings folder is in play.
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))))
             + 'tr4w.json';
end;

// Read every key in the ini's [REPORT] section.  GetPrivateProfileSectionA
// returns the whole section as consecutive null-terminated 'KEY=VALUE' strings,
// so this needs no tag list of its own and cannot drift from uCbrSum's table.
procedure ReadIniReportSection(const aInto: TStringList);
var
   buf: array[0..8191] of AnsiChar;
   n: DWORD;
   p: PAnsiChar;
   entry: string;
begin
   Windows.ZeroMemory(@buf, SizeOf(buf));
   n := Windows.GetPrivateProfileSectionA(CABRILLOSECTION, @buf, SizeOf(buf),
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

procedure EnsureLoaded;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
   i: integer;
   seeded: boolean;
begin
   if GLoaded then
      begin
      Exit;
      end;

   if GCache = nil then
      begin
      GCache := TStringList.Create;
      end;
   GCache.Clear;
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

      for i := 0 to store.CabrilloHeader.Count - 1 do
         begin
         GCache.Values[store.CabrilloHeader.Names[i]] :=
            store.CabrilloHeader.ValueFromIndex[i];
         end;

      // SEED ONCE.  An empty section means this station has not migrated yet,
      // not that its header is empty -- so carry [REPORT] across and save it.
      // Anything already in the store wins, so this cannot undo a later edit.
      if GCache.Count = 0 then
         begin
         ReadIniReportSection(GCache);
         seeded := GCache.Count > 0;
         if seeded then
            begin
            store.CabrilloHeader.Assign(GCache);
            SaveConfig(StoreFileName, store, keyers, udp);
            logger.Info('[CabrilloHeader] seeded %d tag(s) from tr4w.ini [REPORT]',
                        [GCache.Count]);
            end;
         end;
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

function CabrilloHeaderValue(const aTag: string): string;
begin
   EnsureLoaded;
   Result := GCache.Values[aTag];
end;

procedure SetCabrilloHeaderValue(const aTag, aValue: string);
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   udp: TUDPBroadcastConfig;
   loadErr: string;
begin
   EnsureLoaded;
   GCache.Values[aTag] := aValue;

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
            logger.Error('[CabrilloHeader] not saving %s: %s could not be read (%s)',
                         [aTag, StoreFileName, loadErr]);
            Exit;
            end;
         end;

      store.CabrilloHeader.Assign(GCache);
      SaveConfig(StoreFileName, store, keyers, udp);
   finally
      udp.Free;
      keyers.Free;
      store.Free;
   end;
end;

procedure InvalidateCabrilloHeader;
begin
   GLoaded := False;
end;

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.CabrilloHeader');

finalization
   FreeAndNil(GCache);

end.
