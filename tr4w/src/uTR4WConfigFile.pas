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
   uWindowLayoutStore;

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
function LoadUDPForStartup(const aFileName, aIniFileName: string): TUDPBroadcastConfig;

implementation

function TR4WConfigFileName: string;
begin
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))))
             + 'tr4w.json';
end;

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
