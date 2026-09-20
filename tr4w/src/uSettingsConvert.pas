(*
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
 *)
unit uSettingsConvert;
{$I tr4w.inc}

(*
  CONVERTING AN OPERATOR'S OLD FILES INTO THE SETTINGS THE PROGRAM READS.

  ------------------------------------------------------------------------
  WHY THIS IS A SEPARATE ACT AND NOT PART OF STARTUP
  ------------------------------------------------------------------------

  NY4I, 2026-09-12: *"we needed a much clearer demarcation between the current
  program/contest settings and the import of old files. If it is getting too
  complicated, I am not adverse to a standalone conversion utility."*

  STARTUP READS SIX CONFIGURATION SOURCES, measured rather than guessed --
  the settings section, tr4w.ini, the contest .cfg, the common messages, the
  contest database, and finally the legacy flat `commands` bucket. The last
  one wins because it is applied last, which means it overrides even the
  contest's own database. The rules meant to contain that are spread across
  four units, and every setting migrated off the config array has to be
  reasoned about against all six.

  THE DESTINATION IS TWO SOURCES: settings\tr4w.json for the station and the
  contest .db for the contest. Everything else is CONVERSION, and a contest
  logger should not be doing conversion while an operator is working a
  contest.

  ------------------------------------------------------------------------
  WHAT THIS DOES TODAY, AND WHAT IT DELIBERATELY DOES NOT
  ------------------------------------------------------------------------

  IT CONVERTS THE STATION'S SETTINGS: for every command the settings model
  owns and that is not the contest's, it takes the value out of the legacy
  `commands` bucket (or out of tr4w.ini), puts it on the property and saves
  the settings section.

  IT CHANGES NOTHING ABOUT HOW THE PROGRAM STARTS. The legacy bucket is left
  exactly where it is and the startup path still reads it, so running this
  cannot alter how a station behaves -- it can only make the settings section
  say what the station already does. That is what makes it safe to land
  before the readers are removed, and removing them is the step this exists
  to make possible.

  CONTEST SETTINGS ARE NOT ITS BUSINESS. A contest-scoped command is skipped
  and reported as such: those belong in the contest database, which
  uLogStore.CaptureConfiguration already writes.

  ------------------------------------------------------------------------
  THE DEFECT THIS REPLACES
  ------------------------------------------------------------------------

  TR4WSettings.ImportLegacyCommands is called from LoadSettingsForStartup and
  looks each command up with FindPath on the `commands` object. THE REAL FILE
  NESTS COMMANDS BY CATEGORY -- 'MY GRID' lives at commands/other/MY GRID --
  and FindPath does not search, so on any file written in the current shape
  THE SEED IMPORTS NOTHING. The tracked corpus fixture proves it: it has a
  settings section with no My group at all, while commands/other still holds
  the callsign, the grid, the state and the zone.

  It is also called only when the settings section is ABSENT, so a setting
  migrated after that section first appeared was never seeded even in the
  flat case.

  This reads the store instead, which flattens the tree properly and is the
  same code the running program uses.

  IT IS IDEMPOTENT. Running it twice applies the same values a second time
  and reports the same thing, which is what makes it safe to tell an operator
  to just run it.
*)

interface

uses
   Classes,
   uSettingsModel;

type
   (* What happened to one command.  Reported for EVERY command the model owns,
     including the ones nothing was done to, because "there was no old value
     for this" is an answer an operator needs as much as "converted". *)
   TConvertOutcome = (
      coConverted,      // a legacy value was found and applied
      coSameAlready,    // a legacy value was found and the model already had it
      coRefused,        // a legacy value was found and the property would not take it
      coNoLegacyValue,  // nothing in the old files named this command
      coContestScoped   // belongs in the contest database, not here
   );

   TConvertEntry = record
      Command: string;
      OldValue: string;
      NewValue: string;
      Outcome: TConvertOutcome;
   end;

   TConvertReport = array of TConvertEntry;

(* Human-readable, one word, for a report line. *)
function ConvertOutcomeName(aOutcome: TConvertOutcome): string;

(* CONVERT, and say what happened.

  aSettingsFile is settings\tr4w.json -- read for both the legacy bucket and
  the settings section, and written back when aApply is True and anything
  actually changed.

  aIniFile is the legacy tr4w.ini, or '' to skip it. Its [COMMANDS] section is
  read the same way and loses to the JSON bucket, which is the order the
  program itself applies them in.

  aApply False is a DRY RUN: everything is decided and reported and nothing is
  written. That is the default an operator should see first.

  A SETTINGS FILE THAT DOES NOT EXIST YET IS THE NORMAL CASE and is CREATED on
  apply, from the model's defaults plus whatever the old files hold. That is
  the whole intended sequence -- install, convert, start TR4W.

  Returns False only when the settings file is there and could not be read or
  parsed; a file with nothing to convert is a success with an empty-handed
  report. *)
function ConvertStationSettings(const aSettingsFile: string;
                                const aIniFile: string;
                                aApply: boolean;
                                const aSettings: TR4WSettings;
                                out aReport: TConvertReport;
                                out aError: string): boolean;

(* How many entries in the report have this outcome. *)
function CountOutcome(const aReport: TConvertReport;
                      aOutcome: TConvertOutcome): integer;

implementation

uses
   SysUtils, IniFiles,
   uRadioConfigStore,
   uKeyerConfigStore,   (* LoadConfig takes one, even though nothing here reads it *)
   uTR4WConfigFile;


function ConvertOutcomeName(aOutcome: TConvertOutcome): string;
begin
   case aOutcome of
      coConverted:     Result := 'converted';
      coSameAlready:   Result := 'unchanged';
      coRefused:       Result := 'REFUSED';
      coNoLegacyValue: Result := 'no old value';
      coContestScoped: Result := 'contest';
   else
      Result := '?';
   end;
end;


function CountOutcome(const aReport: TConvertReport;
                      aOutcome: TConvertOutcome): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to High(aReport) do
      begin
      if aReport[i].Outcome = aOutcome then
         begin
         Inc(Result);
         end;
      end;
end;


(* THE OLD VALUES, FLATTENED, FROM BOTH OLD FILES.

  The JSON bucket is read through TRadioConfigStore because that is what
  understands the nested shape -- see the unit header for what happens to code
  that assumes it is flat. The ini is read after it and does NOT overwrite,
  because tr4w.json is the newer of the two and the program applies it last. *)
function CollectLegacyValues(const aSettingsFile, aIniFile: string;
                             const aInto: TStringList;
                             out aError: string): boolean;
var
   radios: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   i: integer;
   ini: TIniFile;
   iniNames: TStringList;
   name: string;
begin
   Result := False;
   aError := '';
   aInto.Clear;

   (* NO SETTINGS FILE AT ALL IS THE PRIMARY CASE, NOT AN ERROR (2026-09-20).

     NY4I: "the only reason tr4wconvert should run is if the tr4w.json does not
     exist so how could we have a settings conflict?" -- the intended sequence
     is install, convert, THEN start TR4W. A file that is not there has no
     legacy `commands` bucket to read, so there is simply nothing to collect
     from it and the ini below is the whole of the old configuration.

     It used to fail here, and that precondition is what forced the installer
     to tell an operator to start TR4W and close it again just to bring the
     file into existence. An error should mean something is wrong, not that
     the thing this tool exists to create is absent. *)
   if FileExists(aSettingsFile) then
      begin
      radios := TRadioConfigStore.Create;
      keyers := TKeyerConfigStore.Create;
      try
         if not LoadConfig(aSettingsFile, radios, keyers, aError) then
            begin
            Exit;
            end;
         for i := 0 to radios.Commands.Count - 1 do
            begin
            aInto.Values[radios.Commands.Names[i]] :=
               radios.Commands.ValueFromIndex[i];
            end;
      finally
         keyers.Free;
         radios.Free;
      end;
      end;

   if (aIniFile <> '') and FileExists(aIniFile) then
      begin
      ini := TIniFile.Create(aIniFile);
      iniNames := TStringList.Create;
      try
         ini.ReadSection('COMMANDS', iniNames);
         for i := 0 to iniNames.Count - 1 do
            begin
            name := iniNames[i];
            (* THE JSON BUCKET WINS. It is the newer store and the one the
              program applies last, so an ini line only fills a gap. *)
            if aInto.Values[name] <> '' then
               begin
               Continue;
               end;
            aInto.Values[name] := ini.ReadString('COMMANDS', name, '');
            end;
      finally
         iniNames.Free;
         ini.Free;
      end;
      end;

   Result := True;
end;


function ConvertStationSettings(const aSettingsFile: string;
                                const aIniFile: string;
                                aApply: boolean;
                                const aSettings: TR4WSettings;
                                out aReport: TConvertReport;
                                out aError: string): boolean;
var
   legacy: TStringList;
   names: TStringList;
   i: integer;
   cmd: string;
   oldValue: string;
   current: string;
   after: string;
   changed: boolean;
begin
   Result := False;
   aError := '';
   SetLength(aReport, 0);
   if aSettings = nil then
      begin
      aError := 'no settings object';
      Exit;
      end;

   legacy := TStringList.Create;
   names := nil;
   try
      (* THE SETTINGS SECTION IS LOADED FIRST, AND THAT IS NOT A DETAIL.

        SaveSettings replaces the WHOLE section from this object, so converting
        into a model that still holds its constructor defaults would write those
        defaults over everything the operator already had in there. A converter
        that resets the settings it was asked to populate is worse than no
        converter.

        It is also what makes a second run a no-op: the values the first run
        wrote are read back, so the legacy value matches and is reported as
        unchanged rather than converted again.

        THE SECTION ONLY, NOT THE STARTUP LOAD -- changed 2026-09-19 when
        LoadSettingsForStartup began importing the legacy bucket itself. Going
        through it would apply the bucket to the object before the comparison
        below, so every command would come back "unchanged" and a converter
        that reports nothing is a converter that cannot be checked. The
        difference between the two homes is the whole of what this reports. *)
      LoadSettingsSection(aSettingsFile, aSettings);

      if not CollectLegacyValues(aSettingsFile, aIniFile, legacy, aError) then
         begin
         Exit;
         end;

      (* WALKS THE MODEL, NOT THE OLD FILE. A command in the old file that no
        property owns is not this unit's business -- it has not migrated yet,
        and the config array still reads it. Walking the model also means a
        property added tomorrow is converted with no edit here. *)
      names := aSettings.CommandNames;
      SetLength(aReport, names.Count);
      changed := False;

      for i := 0 to names.Count - 1 do
         begin
         cmd := string(names[i]);
         aReport[i].Command := cmd;
         aReport[i].OldValue := '';
         aReport[i].NewValue := '';

         if aSettings.CommandIsContestScoped(cmd) then
            begin
            aReport[i].Outcome := coContestScoped;
            Continue;
            end;

         oldValue := legacy.Values[cmd];
         if (oldValue = '') and (legacy.IndexOfName(cmd) < 0) then
            begin
            aReport[i].Outcome := coNoLegacyValue;
            Continue;
            end;

         aReport[i].OldValue := oldValue;
         if not aSettings.TryGetByCommand(cmd, current) then
            begin
            current := '';
            end;

         if not aSettings.TrySetByCommand(cmd, oldValue) then
            begin
            (* THE PROPERTY REFUSED IT. Out of range, unparseable, or a value
              a registered check rejects. Reported rather than forced: the
              old file is not the authority on what the type permits. *)
            aReport[i].Outcome := coRefused;
            Continue;
            end;

         if not aSettings.TryGetByCommand(cmd, after) then
            begin
            after := '';
            end;
         aReport[i].NewValue := after;

         if after = current then
            begin
            aReport[i].Outcome := coSameAlready;
            end
         else
            begin
            aReport[i].Outcome := coConverted;
            changed := True;
            end;
         end;

      if aApply and changed then
         begin
         SaveSettings(aSettingsFile, aSettings);
         end;

      Result := True;
   finally
      names.Free;
      legacy.Free;
   end;
end;

end.
