{
 Copyright Thomas M. Schaefer, NY4I (c) 2026.
 This file is part of TR4W  (SRC)
 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uTR4WConfigFile;
{$I tr4w.inc}

{
  Composes settings\tr4w.json from the several libraries that share it.

  WHY THIS EXISTS.  The radio library came first and, being the only tenant,
  owned the whole file -- TRadioConfigStore.SaveToFile wrote version, general,
  radios and profiles.  The keyer library is the second tenant, and Preferences
  advertises eleven more sections, so "whoever was here first owns the file"
  does not scale.  The alternatives were worse: teaching the radio store about
  keyers breaks the layering the radio track was careful to establish, and a
  second file means two things to keep in step, two migrations, and a
  half-written state when one save fails.

  So: each store serialises ITS OWN SECTION and knows nothing about the others;
  this unit owns the root, the version, and the single atomic write.

  A SAVE PRESERVES THE SECTIONS IT WAS NOT GIVEN.  SaveConfig reads the file
  that is already there and overlays only the tenants it was handed, so passing
  nil for a store means LEAVE THAT SECTION ALONE.  It did not always: the root
  used to be built from the radio store and the others merely added, which made
  a store the caller forgot to pass vanish from the file with nothing to show
  for it.  That held together only while every caller passed every store, and
  it stops being possible at all once a tenant is saved from somewhere that has
  no access to the others -- the window layout is written from ExitProgram.

  ON THE FILE FORMAT.  Formatted (not compact) because the point of leaving the
  ini was a file an operator can read and hand-edit, and written with
  uFileText.WriteAllTextUTF8, which never emits
  a BOM that RFC 8259 forbids at the start of JSON and that Python's json.load
  and jq both reject.  See uRadioConfigStore.SaveToFile for the full note; the
  rule is inverted from src\lang\*.pas, which must KEEP their BOM.

  BACKWARD COMPATIBLE BY CONSTRUCTION.  A file written before the keyer library
  existed simply has no 'keyers' key, and LoadConfig leaves that store empty
  rather than failing -- an absent section is a new tenant, not a corrupt file.
}

interface

uses
   SysUtils,
   Classes,
   uJSON,
   uFileText,            // whole-file UTF-8 read/write -- see the BOM note in that unit
   IniFiles,
   VC,                   // TR4W_INI_FILENAME -- see TR4WConfigFileName
   uRadioConfigStore,
   uKeyerConfigStore,
   uUDPBroadcastConfig,
   uWindowLayoutStore,
   uSettingsModel,
   utils_text;           // CharBufferText -- the ini name

const
   // The keyer library's section. The radio store's keys stay private to it;
   // this unit only needs to name what it adds.
   JSONKEY_KEYERS = 'keyers';
   // The UDP broadcast settings. One object, not a list: there is one
   // destination, unlike radios and keyers which are libraries of definitions.
   JSONKEY_UDP    = 'udpBroadcast';

   // Where each TR4W window was left. An object keyed by window name -- see
   // uWindowLayoutStore for why it is not the array of records it replaced.
   JSONKEY_WINDOWS = 'windows';

   (* THE SETTINGS OBJECT -- the destination CFGCA rows move to.

     A NESTED object, unlike every section above it: uSettingsModel groups by
     area, so this key holds { "ExternalLogger": { "Port": 52001, ... }, ... }
     rather than a flat list of names.  The nesting is the property tree, which
     is also what makes the JSON readable without a key list beside it. *)
   JSONKEY_SETTINGS = 'settings';

   // Where an existing file goes when it will not parse and is about to be
   // replaced. See ReadRootOrEmpty.
   BAD_SUFFIX     = '.bad';

// WHERE THE FILE IS.  One derivation, here, because this unit owns the file.
//
// It was written out twice before -- uRadioConfigApply.RadioStoreFileName and
// uCabrilloHeader.StoreFileName -- and the second carried a comment saying it
// was "derived the same way" as the first, which is the shape a drift takes
// just before it happens.  Both now delegate.
//
// The settings folder comes from the ini path rather than from TR4W_PATH_NAME,
// so a TR4W started with a different settings folder finds its own config.
function TR4WConfigFileName: string;

// Writes every library into one file, atomically. Creates the directory if it
// does not exist, exactly as the radio store did when it owned the file.
procedure SaveConfig(const aFileName: string;
                     const aRadios: TRadioConfigStore;
                     const aKeyers: TKeyerConfigStore;
                     const aUDP: TUDPBroadcastConfig = nil;
                     const aWindows: TWindowLayoutStore = nil);

(* THE SETTINGS OBJECT ON ITS OWN.

  Named rather than a SaveConfig call with four nils, for the same reason
  SaveWindowLayout is: the callers that save settings have no radio or keyer
  store in hand, and four nils of ceremony makes a reader wonder which of them
  mattered.

  It goes through SaveConfig, so the one-writer rule is intact -- every other
  section is preserved. *)
procedure SaveSettings(const aFileName: string;
                       const aSettings: TR4WSettings);

(* THE SETTINGS AS THEY SHOULD STAND AT STARTUP.

  Returns True when the file already carried a `settings` section, which is
  every start after the first.

  Returns FALSE having SEEDED aSettings from the legacy `commands` keys, which
  happens exactly once per installation.  NY4I, 2026-09-10: "Old settings are
  migrated once and never used again."  So this is not a fallback consulted at
  every start -- that is the arrangement where two stores disagree and nobody
  can say which is in force.  The caller SAVES on a False result, and from then
  on the legacy keys are dead.

  THE LEGACY BUCKET IS NOW IMPORTED BEFORE THE SECTION IS DE-STREAMED, and the
  section wins wherever it has a value -- see the body for why, and call
  CollapseLegacySettingHomes afterwards to finish the job.

  aImportLegacy FALSE SKIPS THAT IMPORT, and there is exactly one caller that
  needs it: the headless /EXPORT.

  WHY, MEASURED. The bucket is the STATION'S settings as they stand today, and
  an export must be configured the way the LOG is configured, not the way the
  station is. ApplyStoredCommands is skipped under /EXPORT for precisely this
  reason and its comment records the number -- applying it took the corpus from
  21/1/4 to 8/14/4. Importing the bucket here reintroduced a slice of the same
  thing and the corpus said so within the hour: the IARU sent exchange is
  RECONSTRUCTED from station state at export time, so the fixture's
  MY STATE = FL displaced its MY ITU ZONE = 8 and every QSO exported "59 FL"
  against a frozen D7 reference of "59 8".

  A CONVERSION IS SOMETHING A RUNNING STATION DOES ONCE. It is not something a
  batch export does to a log it was handed. *)
function LoadSettingsForStartup(const aFileName: string;
                                const aSettings: TR4WSettings;
                                aImportLegacy: boolean = True): boolean;

(* THE `settings` SECTION AND NOTHING ELSE -- the second half of
  LoadSettingsForStartup, on its own.

  FOR A CONVERTER, which needs the object to hold what the SECTION says and
  not what the legacy bucket says, because the difference between the two is
  exactly what it has to report. Going through the startup load would import
  the bucket first and every command would come back "unchanged".

  Returns whether the file carried a section at all. *)
function LoadSettingsSection(const aFileName: string;
                             const aSettings: TR4WSettings): boolean;

(* TWO HOMES BECOME ONE -- the write half of the import LoadSettingsForStartup
  has just done.

  For every command the settings object OWNS and that is not the contest's, the
  entry is deleted from the legacy `commands` bucket and the settings section is
  rewritten from the object. The value is not lost: the load above already put
  it on the property, so this only removes the second copy.

  WHY IT IS A SEPARATE CALL AND NOT PART OF THE LOAD. A load that writes is a
  surprise, and there is one caller that must NOT write -- the headless
  /EXPORT, which has no business editing an operator's settings file.

  A CONTEST-SCOPED COMMAND IS LEFT ALONE. ToJSON excludes it from the settings
  section, so removing it from the bucket would delete the only copy. Those
  belong in the contest database and that is a different migration.

  Returns the number of entries removed -- 0 on a station that has already been
  collapsed, which is every start after the first. *)
function CollapseLegacySettingHomes(const aFileName: string;
                                    const aSettings: TR4WSettings): integer;

(* ONE COMMAND'S VALUE OUT OF THE LEGACY `commands` BUCKET, or '' when the
  file, the bucket or the name is absent. Flattened, so a nested entry is
  found.

  FOR THE CALLER THAT MUST NOT IMPORT THE WHOLE BUCKET and still needs one
  named value out of it -- today that is the headless /EXPORT and COMPUTER ID,
  which decides the Cabrillo TRANSMITTER DIGIT. Naming the command at the call
  site, with the reason, is the point: a loop over the bucket is
  ApplyStoredCommands and is skipped there deliberately.

  Reads the file and nothing else. It assigns nothing and saves nothing. *)
function StoredLegacyCommand(const aFileName, aCommand: string): string;

(* MY CALL AS STORED, for the New Contest dialog -- which runs BEFORE
  LoadSettingsForStartup, so Settings.My.MainCallsign is always empty there and
  the pre-fill it was reading never once fired.

  Reads settings/My/MainCallsign, and falls back to the legacy `commands`
  bucket so a station that has not been collapsed yet still gets its callsign
  offered on the very first run after the upgrade.

  '' for an absent, blank or unreadable file, and the dialog then opens with an
  empty box. Same contract and same rule as StartupLogLevel and
  StartupUILanguage: it READS THE FILE, never assigns Settings and never
  saves. *)
function StartupMainCallsign(const aFileName: string): string;

// The window layout on its own -- what ExitProgram calls.
//
// It exists as a NAMED routine rather than as SaveConfig(fn, nil, nil, nil, w)
// because that call is three nils of pure ceremony at the one site in the
// program that has no config stores in hand, and a reader would reasonably
// wonder which of them mattered.
//
// READ-MODIFY-WRITE AT THE ROW LEVEL TOO, which the section-level merge does
// not give for free: the section is replaced whole, so a window name this build
// does not know -- a NEWER TR4W's window -- would be dropped by an older build
// saving over it. Loading the section first and overlaying the caller's entries
// keeps them.
procedure SaveWindowLayout(const aFileName: string;
                           const aWindows: TWindowLayoutStore);

// The window layout as the file holds it. False (with the store left empty)
// when the file is absent or unreadable, or simply has no 'windows' section --
// which is every file written before this format existed, and is the caller's
// cue to seed from settings/tr4w.pos.
function LoadWindowLayout(const aFileName: string;
                          const aWindows: TWindowLayoutStore): boolean;

// Reads every library from one file. Returns False with a reason when the file
// is unreadable or is not a JSON object; a MISSING SECTION is not an error --
// see the unit header.
function LoadConfig(const aFileName: string;
                    const aRadios: TRadioConfigStore;
                    const aKeyers: TKeyerConfigStore;
                    out aError: string;
                    const aUDP: TUDPBroadcastConfig = nil;
                    const aWindows: TWindowLayoutStore = nil): boolean;

// The UDP settings as they should stand at startup: from the JSON section when
// it is there, otherwise SEEDED from whatever the operator's ini already holds.
// One-time migration in the only place that can know it is needed -- without it
// the CFGCA rows going inert would silently reset every station's broadcast
// settings to the defaults.  Caller owns the result.
// The log level from settings\tr4w.json, or '' when the file, the section or
// the key is absent.
//
// FOR THE STARTUP BOOTSTRAP ONLY, and it exists because that moment is a
// chicken-and-egg: the logger has to be configured before the config system is
// up, so tr4w.lpr needs ONE value before anything else can supply it. It used
// to read that value from tr4w.ini -- which stopped being the system of record
// when DEBUG LOG LEVEL became csJSON, so an operator who set the level in
// Preferences got their old ini value for the earliest lines, or the compiled
// default on a station with no ini at all (NY4I, 2026-08-21: "the ini file is
// not there, so solve it another way with reading the json file").
//
// Deliberately NOT the full store: this runs before the logger, so it must not
// depend on anything that logs. ReadRootOrEmpty and a few lookups is the whole
// of it. ApplyLoggingSettings applies the real value moments later.
//
// THE SAME PRECEDENCE THE PROGRAM APPLIES A MOMENT LATER (2026-09-19), so the
// earliest log lines run at the level the rest of the run does:
//
//   1. logging.level -- present only when an operator chose one; it is
//      applied over the settings object by ApplyLoggingSettings.
//   2. settings.Log.DebugLevel -- the level's home, loaded by
//      LoadSettingsForStartup. Streamed as the enum's name ('llDebug'), and
//      returned here as its spelling ('DEBUG').
//   3. '' -- neither: the caller leaves the settings object's own default.
function StartupLogLevel(const aFileName: string): string;

(* THE DISPLAY LANGUAGE AS STORED -- settings.Display.Language -- or '' when
  the file, the section or the member is absent, or the file is unreadable.
  '' is also what "follow the operating system" is stored as, and the caller
  cannot and need not tell those apart.

  FOR THE STARTUP BOOTSTRAP ONLY, for the same reason as StartupLogLevel: the
  catalogue has to be in force before the first form streams, and that is
  before LoadSettingsForStartup. So this READS THE FILE and nothing else -- it
  never assigns Settings and never saves, which is the rule for any code that
  runs before the load (settings-config agent: "Nothing touches Settings
  before LoadSettingsForStartup").

  NOT VALIDATED HERE. Whether this build carries a catalogue for the code is
  uEmbeddedTranslations' question, and it reports a code it cannot load. *)
function StartupUILanguage(const aFileName: string): string;

function LoadUDPForStartup(const aFileName, aIniFileName: string): TUDPBroadcastConfig;

implementation

uses
   TypInfo,              // GetEnumValue -- StartupLogLevel reads a streamed enum name
   uAppPaths;            // SettingsFileOverride -- the --settings switch, parsed once

(* --settings <path> IS RESOLVED BY uAppPaths, NOT HERE.

  WHY IT EXISTS AT ALL.  Everything that runs TR4W without an operator -- the
  golden corpus above all -- was reading whatever settings file happened to be
  in the developer's target directory.  That is a test whose result depends on
  the machine it runs on, and it bit exactly that way: the corpus refused to
  run because a hand-staged first-run file had no _LOCATION, and the scoring
  oracle was unavailable for a day (NY4I, 2026-09-12: "you should have your own
  json file and feed that one to tr4w as a parameter for the corpus").

  WHY THE PARSE MOVED (2026-09-24).  The switch acquired a second consumer --
  a downloaded CTY.DAT lands beside the settings file, so uAppPaths has to know
  where that is -- and the choice was one parse in the path-owning unit or two
  copies free to disagree.  uAppPaths caches it for the same reason this unit
  did: TR4WConfigFileName is called from at least four places and the EARLIEST
  of them decides the log level, before most of startup has run.

  NO VALIDATION, THERE OR HERE.  A path that does not exist is a first run
  against that path, which is the same thing an absent default file means, and
  the loader already reports what it found. *)

function TR4WConfigFileName: string;
begin
   Result := SettingsFileOverride;
   if Result <> '' then
      begin
      Exit;
      end;

   Result := ExtractFilePath(CharBufferText(TR4W_INI_FILENAME))
             + 'tr4w.json';
end;

(* Declared here and written near the other startup readers, which is where it
  belongs to a reader -- StartupMainCallsign sits beside the settings loader
  and needs it a couple of hundred lines earlier. *)
function StoredSettingValue(const aRoot: TJSONObject;
                            const aGroup, aName: string): TJSONValue; forward;

// The document as it stands on disk, or an empty one.
//
// An ABSENT file is simply a first run.  A file that is PRESENT but does not
// parse is copied aside to <name>.bad before it is replaced -- the alternative
// is to destroy whatever the operator had and leave them nothing to look at,
// and a save must never be the thing that loses a configuration.  An
// unreadable file is not fatal either: falling through to a fresh document
// keeps the operator able to write settings at all, which refusing to save
// would not.
function ReadRootOrEmpty(const aFileName: string): TJSONObject;
var
   text: string;
   value: TJSONValue;
begin
   Result := nil;

   if FileTextExists(aFileName) then
      begin
      try
         text  := ReadAllTextUTF8(aFileName);
         value := TJSONObject.ParseJSONValue(text);
         if value is TJSONObject then
            begin
            Result := TJSONObject(value);
            end
         else
            begin
            // ParseJSONValue returns nil on malformed input, and Free tolerates
            // nil -- so this arm covers both "not JSON" and "JSON, but not an
            // object at the root".
            value.Free;
            WriteAllTextUTF8(aFileName + BAD_SUFFIX, text);
            end;
      except
         on E: Exception do
            begin
            Result := nil;
            end;
      end;
      end;

   if Result = nil then
      begin
      Result := TJSONObject.Create;
      end;
end;

procedure SaveConfig(const aFileName: string;
                     const aRadios: TRadioConfigStore;
                     const aKeyers: TKeyerConfigStore;
                     const aUDP: TUDPBroadcastConfig = nil;
                     const aWindows: TWindowLayoutStore = nil);
var
   root, tenant: TJSONObject;
   dir: string;
   i: integer;
begin
   dir := ExtractFilePath(aFileName);
   if (dir <> '') and (not DirectoryExists(dir)) then
      begin
      ForceDirectories(dir);
      end;

   // READ-MODIFY-WRITE, and this is the point of the routine.
   //
   // It used to build the root from aRadios.SaveToJSON and add whichever other
   // tenants it was handed -- which means a tenant NOT handed to it was
   // silently DELETED from the file.  That was survivable only for as long as
   // every caller happened to pass every store, an invariant held by nothing
   // but memory and one that no compiler, lint or test could see break.  It
   // does not survive a tenant saved from somewhere else in the program: the
   // window layout is written from ExitProgram, which has no radio or keyer
   // store in hand, so a naive fourth tenant would have made exit-save wipe the
   // radio library.
   //
   // Starting from what is already on disk and overlaying only the sections we
   // were given makes "not passed" mean LEFT ALONE, which is what every call
   // site already intended.
   root := ReadRootOrEmpty(aFileName);
   try
      if aRadios <> nil then
         begin
         // The radio store owns SEVERAL top-level keys -- version, general,
         // tci, logging, commands, rotators, clusters, radios, profiles and the
         // Cabrillo header sections -- and emits every one of them on every
         // save.  So overlaying its whole document key by key is exactly what
         // it used to do, with foreign keys left standing instead of dropped.
         tenant := aRadios.SaveToJSON;
         try
            for i := 0 to tenant.Count - 1 do
               begin
               JSONSetSection(root, JSONPairName(tenant, i),
                              JSONClone(JSONPairValue(tenant, i)));
               end;
         finally
            tenant.Free;
         end;
         end;

      if aKeyers <> nil then
         begin
         JSONSetSection(root, JSONKEY_KEYERS, aKeyers.ToJSON);
         end;

      if aUDP <> nil then
         begin
         JSONSetSection(root, JSONKEY_UDP, aUDP.ToJSON);
         end;

      if aWindows <> nil then
         begin
         JSONSetSection(root, JSONKEY_WINDOWS, aWindows.ToJSON);
         end;

      // See the unit header: formatted, and no BOM.
      WriteAllTextUTF8(aFileName, root.Format(2));
   finally
      root.Free;
   end;
end;

procedure SaveSettings(const aFileName: string;
                       const aSettings: TR4WSettings);
var
   root: TJSONObject;
   dir: string;
begin
   if aSettings = nil then
      begin
      Exit;
      end;

   dir := ExtractFilePath(aFileName);
   if (dir <> '') and (not DirectoryExists(dir)) then
      begin
      ForceDirectories(dir);
      end;

   // Read-modify-write, exactly as SaveConfig does: every other section is
   // preserved. See the one-writer note in the unit header.
   root := ReadRootOrEmpty(aFileName);
   try
      JSONSetSection(root, JSONKEY_SETTINGS, aSettings.ToJSON);
      WriteAllTextUTF8(aFileName, root.Format(2));
   finally
      root.Free;
   end;
end;

function LoadSettingsForStartup(const aFileName: string;
                                const aSettings: TR4WSettings;
                                aImportLegacy: boolean = True): boolean;
var
   root: TJSONObject;
   commands: TJSONValue;
begin
   Result := False;
   if aSettings = nil then
      begin
      Exit;
      end;

   root := ReadRootOrEmpty(aFileName);
   try
      (* THE LEGACY BUCKET FIRST, THE SETTINGS SECTION SECOND, AND THAT ORDER
        IS THE WHOLE FIX (2026-09-19).

        A setting the settings object owns could sit in BOTH homes, and the
        legacy one won -- not here, but at startup, where ApplyStoredCommands
        re-applied the whole `commands` bucket AFTER this load. Measured on
        NY4I's station: 229 entries in the bucket against a settings section
        holding one group, and 231 of the 247 names the importer seeds are
        names the settings object owns. The visible symptom was that clearing
        COMPUTER ID did not survive a restart.

        TWO HOMES COLLAPSE TO ONE BY IMPORTING RATHER THAN BY CHOOSING. The
        bucket is applied to the properties first, so nothing an operator had
        is lost; the settings section is then de-streamed over the top, and
        FromJSON leaves a property the section does not carry alone. So the
        settings section wins wherever it has an opinion and the old value
        fills the gap -- which is the precedence this program has always meant
        to have. CollapseLegacySettingHomes then removes what was consumed.

        An absent `commands` section is not an error -- it is a brand new
        installation, and the settings object keeps its constructor defaults.

        IT USED TO RUN ONLY WHEN THE SETTINGS SECTION WAS ABSENT, which meant
        a setting migrated after that section first appeared was never seeded
        at all. *)
      commands := root.FindValue('commands');
      if aImportLegacy and (commands is TJSONObject) then
         begin
         aSettings.ImportLegacyCommands(TJSONObject(commands));
         end;
   finally
      root.Free;
   end;

   (* AND THE SECTION OVER THE TOP, through the one routine that reads it. *)
   Result := LoadSettingsSection(aFileName, aSettings);
end;

function LoadSettingsSection(const aFileName: string;
                             const aSettings: TR4WSettings): boolean;
var
   root: TJSONObject;
   section: TJSONValue;
begin
   Result := False;
   if aSettings = nil then
      begin
      Exit;
      end;

   root := ReadRootOrEmpty(aFileName);
   try
      section := root.FindValue(JSONKEY_SETTINGS);
      if section is TJSONObject then
         begin
         aSettings.FromJSON(TJSONObject(section));
         Result := True;
         end;
   finally
      root.Free;
   end;
end;

function CollapseLegacySettingHomes(const aFileName: string;
                                    const aSettings: TR4WSettings): integer;
var
   root: TJSONObject;
   commands: TJSONValue;
   removed: integer;

   (* DEPTH FIRST AND BACKWARDS, because deleting shifts every later index
     down. An empty category object is left in place: it costs one line in the
     file, and removing containers while walking them is where this kind of
     routine goes wrong. *)
   procedure Prune(const aNode: TJSONObject);
   var
      i: integer;
      child: TJSONValue;
      name: string;
   begin
      for i := aNode.Count - 1 downto 0 do
         begin
         child := aNode.Items[i];
         name := string(aNode.Names[i]);
         if child is TJSONObject then
            begin
            Prune(TJSONObject(child));
            end
         else if aSettings.OwnsCommand(name) and
                 (not aSettings.CommandIsContestScoped(name)) then
            begin
            aNode.Delete(i);
            Inc(removed);
            end;
         end;
   end;

begin
   Result := 0;
   removed := 0;
   if (aSettings = nil) or (not FileExists(aFileName)) then
      begin
      Exit;
      end;

   root := ReadRootOrEmpty(aFileName);
   try
      commands := root.FindValue('commands');
      if not (commands is TJSONObject) then
         begin
         Exit;
         end;

      Prune(TJSONObject(commands));
      if removed = 0 then
         begin
         (* NOTHING TO DO IS THE NORMAL CASE, and it must not rewrite the
           file. A save on every start is a save that can fail on every
           start. *)
         Exit;
         end;

      (* BOTH HALVES IN ONE WRITE. The settings section carries the values
        that were just consumed, and the pruned bucket no longer does; writing
        one without the other would lose them if the process died in
        between. *)
      JSONSetSection(root, JSONKEY_SETTINGS, aSettings.ToJSON);
      WriteAllTextUTF8(aFileName, root.Format(2));
      Result := removed;
   finally
      root.Free;
   end;
end;

function StoredLegacyCommand(const aFileName, aCommand: string): string;
var
   root: TJSONObject;
   commands: TJSONValue;
   legacy: TStringList;
begin
   Result := '';

   root := ReadRootOrEmpty(aFileName);
   try
      commands := root.FindValue('commands');
      if not (commands is TJSONObject) then
         begin
         Exit;
         end;

      legacy := TStringList.Create;
      try
         FlattenLegacyCommands(TJSONObject(commands), legacy);
         Result := Trim(string(legacy.Values[AnsiString(aCommand)]));
      finally
         legacy.Free;
      end;
   finally
      root.Free;
   end;
end;

function StartupMainCallsign(const aFileName: string): string;
var
   root: TJSONObject;
   value: TJSONValue;
   commands: TJSONValue;
   legacy: TStringList;
begin
   Result := '';

   root := ReadRootOrEmpty(aFileName);
   try
      value := StoredSettingValue(root, 'My', 'MainCallsign');
      if value <> nil then
         begin
         Result := Trim(value.Value);
         end;

      if Result = '' then
         begin
         (* MY CALL AS THE FALLBACK, and the two are not the same setting.
           My.MainCallsign is the STATION'S own callsign, remembered across
           contests and written back by this dialog; My.Call is the callsign
           being OPERATED, which a contest .cfg overrides for a club call. A
           station that has never used this dialog has the second and not the
           first -- NY4I's file is exactly that -- and offering the callsign
           it plainly has beats offering an empty box. *)
         value := StoredSettingValue(root, 'My', 'Call');
         if value <> nil then
            begin
            Result := Trim(value.Value);
            end;
         end;

      if Result <> '' then
         begin
         Exit;
         end;

      (* THE LEGACY BUCKET, for the one run between an upgrade and the
        collapse. After that the settings section answers and this is never
        reached. *)
      commands := root.FindValue('commands');
      if not (commands is TJSONObject) then
         begin
         Exit;
         end;

      legacy := TStringList.Create;
      try
         FlattenLegacyCommands(TJSONObject(commands), legacy);
         Result := Trim(legacy.Values['MAIN CALLSIGN']);
         if Result = '' then
            begin
            Result := Trim(legacy.Values['MY CALL']);
            end;
      finally
         legacy.Free;
      end;
   finally
      root.Free;
   end;
end;

procedure SaveWindowLayout(const aFileName: string;
                           const aWindows: TWindowLayoutStore);
var
   onDisk: TWindowLayoutStore;
   i: integer;
   entry: TWindowLayoutEntry;
begin
   // Start from what the file already holds, so a window name this build does
   // not know about is carried through rather than dropped. See the interface
   // comment: the section is written whole, so preserving rows has to happen
   // here -- SaveConfig's merge only protects whole SECTIONS.
   onDisk := TWindowLayoutStore.Create;
   try
      LoadWindowLayout(aFileName, onDisk);

      for i := 0 to aWindows.EntryCount - 1 do
         begin
         entry := aWindows.Entry(i);
         onDisk.SetLayout(entry.Name, entry.Rect, entry.Visible);
         end;

      SaveConfig(aFileName, nil, nil, nil, onDisk);
   finally
      onDisk.Free;
   end;
end;

function LoadWindowLayout(const aFileName: string;
                          const aWindows: TWindowLayoutStore): boolean;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   err: string;
begin
   // Through LoadConfig rather than a private reader, so there is ONE place
   // that knows how this file is read -- the BOM tolerance, the not-an-object
   // check and the missing-file message included. The two throwaway stores are
   // the price of that, and they cost one parse of a settings file at startup.
   aWindows.Clear;
   radios := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      Result := LoadConfig(aFileName, radios, keyers, err, nil, aWindows) and
                (aWindows.EntryCount > 0);
   finally
      keyers.Free;
      radios.Free;
   end;
end;

function LoadConfig(const aFileName: string;
                    const aRadios: TRadioConfigStore;
                    const aKeyers: TKeyerConfigStore;
                    out aError: string;
                    const aUDP: TUDPBroadcastConfig = nil;
                    const aWindows: TWindowLayoutStore = nil): boolean;
var
   text: string;
   value: TJSONValue;
   root: TJSONObject;
   section: TJSONValue;
begin
   aError := '';
   Result := False;

   if not FileTextExists(aFileName) then
      begin
      aError := Format('%s does not exist.', [aFileName]);
      Exit;
      end;

   try
      // ReadAllText tolerates a BOM if some other tool put one back; we simply
      // never write one ourselves.
      text := ReadAllTextUTF8(aFileName);
   except
      on E: Exception do
         begin
         aError := Format('%s could not be read: %s', [aFileName, E.Message]);
         Exit;
         end;
   end;

   value := TJSONObject.ParseJSONValue(text);
   if not (value is TJSONObject) then
      begin
      // REPORTED, not silently treated as empty. Loading an unreadable file as
      // "no radios" would present as a lost configuration, and the operator
      // would have no way to tell that from a genuine first run.
      aError := Format('%s is not a JSON object.', [aFileName]);
      value.Free;
      Exit;
      end;

   root := TJSONObject(value);
   try
      aRadios.LoadFromJSON(root);

      if aKeyers <> nil then
         begin
         aKeyers.Clear;
         section := root.GetValue(JSONKEY_KEYERS);
         if section is TJSONArray then
            begin
            aKeyers.FromJSON(TJSONArray(section));
            end;
         // An absent 'keyers' key means a file written before the keyer library
         // existed. Not an error -- the store simply stays empty.
         end;

      if aUDP <> nil then
         begin
         section := root.GetValue(JSONKEY_UDP);
         if section is TJSONObject then
            begin
            aUDP.FromJSON(TJSONObject(section));
            end;
         // Absent means a file written before the UDP settings moved here. NOT
         // an error and NOT a reset: the object keeps the defaults it was
         // created with, and LoadUDPForStartup is what seeds the operator's
         // real values from the ini in that case.
         end;

      if aWindows <> nil then
         begin
         aWindows.Clear;
         section := root.GetValue(JSONKEY_WINDOWS);
         if section is TJSONObject then
            begin
            aWindows.FromJSON(TJSONObject(section));
            end;
         // Absent means a file written before the layout moved off tr4w.pos.
         // The store stays empty and the caller seeds from the old file.
         end;

      Result := True;
   finally
      root.Free;
   end;
end;

(* ONE MEMBER OF ONE GROUP OF THE SETTINGS SECTION -- settings.<group>.<name>
  -- or nil when any step is missing. The walk every startup reader makes; the
  document stays owned by the caller. *)
function StoredSettingValue(const aRoot: TJSONObject;
                            const aGroup, aName: string): TJSONValue;
var
   section: TJSONValue;
   group: TJSONValue;
begin
   Result := nil;
   section := aRoot.GetValue(JSONKEY_SETTINGS);
   if not (section is TJSONObject) then
      begin
      Exit;
      end;
   group := TJSONObject(section).GetValue(aGroup);
   if not (group is TJSONObject) then
      begin
      Exit;
      end;
   Result := TJSONObject(group).GetValue(aName);
end;

function StartupUILanguage(const aFileName: string): string;
var
   root: TJSONObject;
   value: TJSONValue;
begin
   Result := '';

   (* ReadRootOrEmpty answers an empty document for an absent, blank or
     unparseable file -- so all three fall through to '' here, and the
     program goes on to ask the operating system. It is the reader
     StartupLogLevel already ran on this same file moments earlier, so
     nothing about the file's handling is new. *)
   root := ReadRootOrEmpty(aFileName);
   try
      value := StoredSettingValue(root, 'Display', 'Language');
      if value <> nil then
         begin
         Result := Trim(value.Value);
         end;
   finally
      root.Free;
   end;
end;

function StartupLogLevel(const aFileName: string): string;
var
   root: TJSONObject;
   logging: TJSONValue;
   level: TJSONValue;
   ordinal: integer;
begin
   Result := '';

   root := ReadRootOrEmpty(aFileName);
   if root = nil then
      begin
      Exit;
      end;

   try
      // 1. An operator's explicit choice, in the store's logging section.
      logging := root.GetValue('logging');
      if logging is TJSONObject then
         begin
         level := TJSONObject(logging).GetValue('level');
         if level <> nil then
            begin
            Result := Trim(level.Value);
            end;
         end;
      if Result <> '' then
         begin
         Exit;
         end;

      // 2. The settings object's stored value.
      level := StoredSettingValue(root, 'Log', 'DebugLevel');
      if level = nil then
         begin
         Exit;
         end;
      (* EXPLICIT: TypInfo takes an AnsiString, and an enum identifier is
        ASCII by definition, so nothing can be lost -- saying so beats an
        implicit conversion the ratchet has to forgive. *)
      ordinal := GetEnumValue(TypeInfo(tLogLevels),
                              AnsiString(string(Trim(level.Value))));
      if (ordinal >= Ord(Low(tLogLevels))) and
         (ordinal <= Ord(High(tLogLevels))) then
         begin
         Result := LogLevelSpelling(tLogLevels(ordinal));
         end;
   finally
      root.Free;
   end;
end;

function LoadUDPForStartup(const aFileName, aIniFileName: string): TUDPBroadcastConfig;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   ini: TIniFile;
   err: string;
   hasSection: boolean;
   text: string;
   value: TJSONValue;
begin
   Result := TUDPBroadcastConfig.Create;   // documented defaults

   // Is there a udp section at all?  Asked directly rather than inferred from
   // LoadConfig succeeding, because a file that loads fine but predates this
   // section must still be seeded -- "loaded" and "has UDP settings" are not
   // the same question.
   hasSection := False;
   if FileTextExists(aFileName) then
      begin
      try
         text  := ReadAllTextUTF8(aFileName);
         value := TJSONObject.ParseJSONValue(text);
         try
            hasSection := (value is TJSONObject) and
                          (TJSONObject(value).GetValue(JSONKEY_UDP) is TJSONObject);
         finally
            value.Free;
         end;
      except
         // Unreadable is handled below by LoadConfig, which reports it.
         hasSection := False;
      end;
      end;

   if hasSection then
      begin
      radios := TRadioConfigStore.Create;
      keyers := TKeyerConfigStore.Create;
      try
         LoadConfig(aFileName, radios, keyers, err, Result);
      finally
         keyers.Free;
         radios.Free;
      end;
      Exit;
      end;

   // No section: this is the one-time move.  Read what the ini already holds,
   // key by key, defaulting to what the object already has -- see
   // TUDPBroadcastConfig.SeedFromLegacyIni for why an absent key must keep the
   // default rather than read as False or 0.
   if (aIniFileName <> '') and FileTextExists(aIniFileName) then
      begin
      ini := TIniFile.Create(aIniFileName);
      try
         Result.SeedFromLegacyIni(ini);
      finally
         ini.Free;
      end;
      end;
end;


end.
