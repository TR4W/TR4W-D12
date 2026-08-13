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
   uRadioConfigStore,
   uKeyerConfigStore,
   uUDPBroadcastConfig;

const
   // The keyer library's section. The radio store's keys stay private to it;
   // this unit only needs to name what it adds.
   JSONKEY_KEYERS = 'keyers';
   // The UDP broadcast settings. One object, not a list: there is one
   // destination, unlike radios and keyers which are libraries of definitions.
   JSONKEY_UDP    = 'udpBroadcast';

// Writes every library into one file, atomically. Creates the directory if it
// does not exist, exactly as the radio store did when it owned the file.
procedure SaveConfig(const aFileName: string;
                     const aRadios: TRadioConfigStore;
                     const aKeyers: TKeyerConfigStore;
                     const aUDP: TUDPBroadcastConfig = nil);

// Reads every library from one file. Returns False with a reason when the file
// is unreadable or is not a JSON object; a MISSING SECTION is not an error --
// see the unit header.
function LoadConfig(const aFileName: string;
                    const aRadios: TRadioConfigStore;
                    const aKeyers: TKeyerConfigStore;
                    out aError: string;
                    const aUDP: TUDPBroadcastConfig = nil): boolean;

// The UDP settings as they should stand at startup: from the JSON section when
// it is there, otherwise SEEDED from whatever the operator's ini already holds.
// One-time migration in the only place that can know it is needed -- without it
// the CFGCA rows going inert would silently reset every station's broadcast
// settings to the defaults.  Caller owns the result.
function LoadUDPForStartup(const aFileName, aIniFileName: string): TUDPBroadcastConfig;

implementation

procedure SaveConfig(const aFileName: string;
                     const aRadios: TRadioConfigStore;
                     const aKeyers: TKeyerConfigStore;
                     const aUDP: TUDPBroadcastConfig = nil);
var
   root: TJSONObject;
   dir: string;
begin
   dir := ExtractFilePath(aFileName);
   if (dir <> '') and (not DirectoryExists(dir)) then
      begin
      ForceDirectories(dir);
      end;

   // The radio store still builds the root -- it owns version and general, and
   // moving those here would be churn for its own sake. This unit's job is to
   // ADD the other tenants' sections and own the write.
   root := aRadios.SaveToJSON;
   try
      if aKeyers <> nil then
         begin
         root.AddPair(JSONKEY_KEYERS, aKeyers.ToJSON);
         end;

      if aUDP <> nil then
         begin
         root.AddPair(JSONKEY_UDP, aUDP.ToJSON);
         end;

      // See the unit header: formatted, and no BOM.
      WriteAllTextUTF8(aFileName, root.Format(2));
   finally
      root.Free;
   end;
end;

function LoadConfig(const aFileName: string;
                    const aRadios: TRadioConfigStore;
                    const aKeyers: TKeyerConfigStore;
                    out aError: string;
                    const aUDP: TUDPBroadcastConfig = nil): boolean;
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
