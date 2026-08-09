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
unit uRadioConfigApply;

{
  Puts a station profile on the air.

  THE ONLY UNIT THAT KNOWS BOTH WORLDS.  uRadioConfigStore holds the operator's
  library and knows nothing about TR4W; uRadioConfigLegacyMap turns a definition
  into ini keys and knows nothing about the live application.  This unit is
  where those meet the running program: it writes the keys, tells CFGCA to
  re-read them, and restarts the radios.  Everything genuinely untestable lives
  here on purpose, and it is deliberately thin -- the decisions were all made in
  the two units below it.

  WHY WRITE THE INI AT ALL, RATHER THAN SET THE GLOBALS DIRECTLY.  Because
  CheckCommand is the only code that knows how to turn 'SERIAL 15' into a port
  type, how to validate a baud rate, and which of the sixty-odd globals a given
  key feeds.  Reproducing that here would be reimplementing the config parser
  and would drift from it the first time either side changed.  So the sequence
  is the same one the legacy dialog uses: write the key, then CheckCommand it.

  STARTUP -- THIS CHANGED, 2026-08-06.  It used to say that startup needed
  nothing from this unit: apply wrote the legacy keys, ReadInConfigFile read
  them back, and the JSON library was never consulted while booting.  That is
  true only while nothing else edits tr4w.ini.  NY4I hand-edited
  RADIO ONE CONTROL PORT to 'SERIAL 3' after the library had been saved as JSON
  and the program obeyed the INI -- the library and the live configuration had
  silently diverged, with nothing to tell the operator which was in force.

  So settings\tr4w.json is now the FORMAT OF RECORD for radio settings, and the
  [Radio] keys are a rendering of it.  ApplyActiveProfileToConfigAtStartup
  rewrites them from the library on every start, before anything reads them.
  A conflicting hand-edit is overwritten rather than obeyed, and the
  disagreement is logged.

  ON COEXISTENCE WITH THE OLD DIALOG.  Both write the same [Radio] keys, so
  within a session it is last-writer-wins.  ACROSS a restart it is not: the
  library wins, so a change made in the legacy dialog (CATLEGACY) does not
  survive the next start once a profile is active.  That is the intended
  direction of travel -- the legacy dialog is a transitional escape hatch, not a
  second place to configure radios -- but it is a real behaviour change and is
  the reason the override is logged rather than silent.

  ON THREADS.  ApplyProfile closes the CAT and keyer ports through the same
  CloseCATAndKeyerForThisRadio the dialog uses, and lets the polling thread
  notice and wind down.  It does NOT call TerminateThread -- the legacy dialog
  does, and it is wrong: terminating a thread mid-write leaves the serial handle
  and the radio object in whatever state they were in, which is how you get a
  port that cannot be reopened until TR4W restarts.
}

interface

uses
   System.SysUtils,
   System.IniFiles,
   uRadioConfigStore,
   uKeyerConfigStore,
   uRadioConfigLegacyMap;

// Resolve what the registry says about a definition's identity, so the pure
// renderer does not have to know the registry exists.
function ResolveTypeRendering(const aRegistryId: string): TRadioTypeRendering;

// Write one slot's keys and hand each to CheckCommand.  Does NOT touch ports;
// ApplyProfile sequences that.  aRadio may be nil, meaning "clear this slot".
// aPersist decides whether the rendered keys are also WRITTEN to tr4w.ini.
// The two halves are genuinely separate concerns: CheckCommand is what moves
// a value into TR4W's globals, and the ini write is only what makes it
// survive a restart.  Startup passes False -- the library is already the
// record, so persisting a copy of it would be writing to disk purely to
// configure memory, and on a read-only program directory that write fails
// or is redirected without anyone noticing.
procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile;
                           const aPersist: boolean = True;
                           const aNamesAKeyerDevice: boolean = False);

// The whole sequence: stop both radios, write both slots, regroup the ini,
// restart.  Returns False with aError set if the profile cannot be applied at
// all (unknown radio names); a radio that merely fails to CONNECT is not an
// error here -- that is reported by the normal connection path.
// aKeyers resolves a profile's CW-output choice when it names a keyer DEVICE.
// Optional so existing callers are unchanged; without it a named device cannot
// be resolved and its slot renders no keyer port.
function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string;
                      const aKeyers: TKeyerConfigStore = nil): boolean;

// Where the radio library lives.  Here rather than in the preferences form
// because STARTUP needs it too and must not depend on a UI unit -- and not in
// uRadioConfigStore, which is deliberately RTL-only and knows no TR4W unit.
function RadioStoreFileName: string;
function LegacyRadioStoreFileName: string;

// The settings folder itself.  Exported because the UDP settings are seeded
// from settings\tr4w.ini and the Preferences form must reach it the SAME way
// startup does -- two spellings of one path is exactly the divergence this
// unit exists to prevent.
function SettingsDirectory: string;

// STARTUP ONLY.  Writes the active profile's keys into the configuration and
// CheckCommands them -- and does NOTHING to the radios, because at startup they
// do not exist yet and the normal CheckAndInitializePorts path is about to
// connect them with these values.
//
// WHY THIS EXISTS.  Until now the legacy [Radio] keys were the system of record
// AT STARTUP: apply wrote them, and ReadInConfigFile read them back, so the
// JSON library was never consulted while booting.  That works only while
// nothing else edits tr4w.ini.  NY4I hand-edited RADIO ONE CONTROL PORT to
// 'SERIAL 3' after the library had been written to JSON, and the program used
// the ini value -- the two stores had silently diverged with no way for the
// operator to tell which one was live.
//
// So the JSON library WINS.  It is the format of record; the [Radio] keys are
// now a rendering of it, rewritten from it on every start.  A conflicting
// hand-edit of those keys is overwritten rather than obeyed, and the
// disagreement is logged so "why did my ini change" has an answer.
//
// Returns False only when the store cannot be used at all.  No store, no active
// profile, or a profile naming a radio that no longer exists all return True
// having changed nothing -- an operator who has never opened Preferences must
// boot exactly as they always did.
// Library-owned settings that the PROGRAM (not a radio) acts on, published
// here by ApplyActiveProfileToConfigAtStartup.  The store is loaded once at
// startup and freed again, so a global is how a decision made in Preferences
// reaches tr4w.dpr without a second read of the file.
var
   RadioLibraryTCIServerEnabled: boolean = False;

function ApplyActiveProfileToConfigAtStartup(out aError: string): boolean;

// UI-free description of the port collisions a profile WOULD cause, '' when
// clean.  Advisory: unlike TRadioConfigStore.Validate, this also covers the
// keyer lines and CAT-versus-keyer sharing, which are warnings rather than
// certain failures.
function DescribePortConflicts(const aStore: TRadioConfigStore;
                               const aProfile: TStationProfile): string;

implementation

uses
   // Windows, not Winapi.Windows: the rest of the tree spells it the short way
   // and qualifies calls as Windows.<fn>, which only resolves if the unit is
   // named that way here too.
   Windows,
   VC,
   uCFG,
   uCAT,
   uRadioRegistry,
   uKeyerConfigApply,   // resolve a named keyer device and configure it
   uTR4WConfigFile,     // LoadConfig -- both libraries live in the one file
   LOGRADIO,
   LOGK1EA,    // ActiveRadio
   uCWKeyerBase,   // KeyerSelectionIsProfileDriven
   LogCW,
   LOGWIND,
   MainUnit;   // logger

function ResolveTypeRendering(const aRegistryId: string): TRadioTypeRendering;
var
   model: InterfacedRadioType;
begin
   // ModelForId answers NoInterfacedRadio for a string-id (factory) radio,
   // which is exactly the test the legacy dialog makes before deciding between
   // TYPE and FACTORY ID.  Same rule, one layer up.
   model := ModelForId(aRegistryId);

   Result.IsFactoryRadio := (model = NoInterfacedRadio);
   if Result.IsFactoryRadio then
      begin
      Result.LegacyTypeName := '';
      end
   else
      begin
      Result.LegacyTypeName := string(AnsiString(InterfacedRadioTypeSA[model]));
      end;

   // The model's own defaults, for every field the operator left blank.  The
   // renderer cannot look these up -- it has no registry, deliberately -- and
   // it must not render a blank number, because CFGCA reads a blank numeric as
   // "never set" and keeps the PREVIOUS radio's value.
   Result.DefaultBaudRate := 0;
   Result.DefaultTCPPort  := 0;
   if aRegistryId <> '' then
      begin
      Result.DefaultBaudRate := SerialParamsForId(aRegistryId).baud;
      Result.DefaultTCPPort  := RegisteredNetworkPortId(aRegistryId);
      end;

   Result.DefaultCIVAddress := 0;
   Result.DefaultHamLibID   := 0;
   if model <> NoInterfacedRadio then
      begin
      Result.DefaultCIVAddress := RegisteredCIVAddress(model);
      Result.DefaultHamLibID   := RegisteredHamLibID(model);
      end;
end;

procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile;
                           const aPersist: boolean = True;
                           const aNamesAKeyerDevice: boolean = False);
var
   rendered: TConfigKeyValues;
   i: integer;
   typeRendering: TRadioTypeRendering;
   idKey, cmdValue: AnsiString;
   keyShort, valueShort: ShortString;
   accepted: boolean;
begin
   if aRadio <> nil then
      begin
      typeRendering := ResolveTypeRendering(aRadio.RegistryId);
      end
   else
      begin
      typeRendering := Default(TRadioTypeRendering);
      end;

   rendered := RenderRadioKeys(aSlot, aRadio, typeRendering, aProfile, aNamesAKeyerDevice);

   for i := 0 to High(rendered) do
      begin
      // A FRESH AnsiString per value, not a reused buffer.  The ini write takes
      // @s[1] as a null-terminated PAnsiChar, so a shorter value assigned over
      // a longer one in the same ShortString leaves the previous tail in place
      // and the FILE receives the leftover -- the corruption NY4I hit on the
      // port combo, where the log and the ini disagreed.
      idKey    := AnsiString(rendered[i].Key);
      cmdValue := AnsiString(rendered[i].Value);

      Windows.ZeroMemory(@keyShort, SizeOf(keyShort));
      Windows.ZeroMemory(@valueShort, SizeOf(valueShort));
      keyShort   := ShortString(idKey);
      valueShort := ShortString(cmdValue);

      // VALIDATE FIRST, PERSIST SECOND.  CheckCommand is what actually moves the
      // value into TR4W's globals; the ini write is only what makes it survive
      // a restart.  The order used to be the other way round, so a value CFGCA
      // REJECTED was still written to the operator's ini -- and the next
      // startup stopped on it with "Invalid statement in config file".  That is
      // not hypothetical: a cleared slot rendered RADIO TWO BAUD RATE=0, CFGCA
      // refused it (it is ckArray), the warning was logged, the line was
      // written anyway, and TR4W would not start (NY4I, 2026-08-08).
      //
      // A rejected key now leaves the ini untouched, so at worst the file keeps
      // its previous value for that one key -- a stale line beats an unstartable
      // program, and the warning still says the renderer and CFGCA have drifted.
      accepted := CheckCommand(@keyShort, valueShort);
      if not accepted then
         begin
         logger.Warn('[ApplyRadioToSlot] CFGCA did not accept "%s" = "%s" -- NOT written to the ini',
                     [rendered[i].Key, rendered[i].Value]);
         end;

      if aPersist then
         begin
         if rendered[i].Delete then
            begin
            // A DELETE is always safe to persist: removing a key cannot make
            // the file unparseable, and CheckCommand has no say in it.
            // nil, not '' -- a nil value REMOVES the key.  An empty string
            // would leave the key present with a blank value, which for
            // FACTORY ID is not the same thing at all.
            Windows.WritePrivateProfileStringA('Radio', @keyShort[1], nil,
                                               TR4W_INI_FILENAME);
            end
         else if accepted then
            begin
            Windows.WritePrivateProfileStringA('Radio', @keyShort[1], @valueShort[1],
                                               TR4W_INI_FILENAME);
            end;
         end;
      end;

   if aRadio <> nil then
      begin
      logger.Info('[ApplyRadioToSlot] Radio %s := %s (%s), %d keys',
                  [SlotWord(aSlot), aRadio.Name, aRadio.RegistryId, Length(rendered)]);
      end
   else
      begin
      logger.Info('[ApplyRadioToSlot] Radio %s cleared, %d keys',
                  [SlotWord(aSlot), Length(rendered)]);
      end;
end;

// The keyer DEVICE a slot's CW-output choice names, or nil.  CAT, RADIOPORT and
// NONE are the renderer's business and are not devices, so they resolve to nil.
function KeyerDeviceForSlot(const aKeyers: TKeyerConfigStore;
                            const aProfile: TStationProfile;
                            const aSlot: integer): TKeyerDefinition;
var
   cwChoice: string;
begin
   Result := nil;
   if (aKeyers = nil) or (aProfile = nil) then
      begin
      Exit;
      end;

   if aSlot = 2 then
      begin
      cwChoice := Trim(aProfile.CWOutput2);
      end
   else
      begin
      cwChoice := Trim(aProfile.CWOutput1);
      end;

   Result := aKeyers.FindKeyer(cwChoice);
end;

// Configures every keyer device the profile names, and settles whether the
// WinKeyer is enabled AT ALL.
//
// PROFILE-LEVEL, not per-slot, for two reasons.  The enable flag is one flag
// for the whole program, so deciding it inside a per-slot loop would let slot 2
// undo what slot 1 asked for.  And it must be decided in BOTH directions: WK
// ENABLE is csJSON and so inert in the ini, which means nothing but this
// routine can ever turn the WinKeyer back off -- a profile switched from a
// WinKeyer to CW-by-CAT would otherwise keep opening the keyer's port for the
// rest of the session.
procedure ApplyKeyersForProfile(const aKeyers: TKeyerConfigStore;
                                const aProfile: TStationProfile);
var
   slot: integer;
   keyerDef: TKeyerDefinition;
   winKeyer: TKeyerDefinition;
   keyerErr: string;
begin
   winKeyer := nil;

   for slot := 1 to 2 do
      begin
      keyerDef := KeyerDeviceForSlot(aKeyers, aProfile, slot);
      if (keyerDef = nil) or (keyerDef.Kind <> kkWinKeyer) then
         begin
         Continue;
         end;

      // TR4W has ONE WinKeyer: a single WinKeySettings, a single port, a single
      // thread.  Two slots naming two DIFFERENT WinKeyers cannot both be
      // honoured, and silently letting the second win would be a keyer on the
      // wrong port with nothing said about it.
      if (winKeyer <> nil) and (not SameText(winKeyer.Name, keyerDef.Name)) then
         begin
         logger.Warn('[Keyer] profile "%s" names two different WinKeyers ("%s" and "%s"); ' +
                     'TR4W supports one, so "%s" is used',
                     [aProfile.Name, winKeyer.Name, keyerDef.Name, winKeyer.Name]);
         Continue;
         end;

      // REPORTED, not swallowed: a WinKeyer silently keeping the previous
      // settings is a fault an operator blames on the box.
      if ApplyKeyerToWinKey(keyerDef, keyerErr) then
         begin
         winKeyer := keyerDef;
         end
      else
         begin
         logger.Warn('[Keyer] %s', [keyerErr]);
         end;
      end;

   // False when the profile names none, or when the one it named could not be
   // configured -- enabling a keyer we failed to set up would start its thread
   // against a port we never validated.
   SetWinKeyerEnabled(winKeyer <> nil);

   // A profile STATED the CW output for each slot, so the CW-by-CAT versus
   // hardware-keyer combination is no longer an ambiguity to warn about: the
   // per-slot choice is written as the per-radio CWByCAT that ActiveCWKeyer
   // already tests, so it resolves by radio.  The warning predates profiles.
   KeyerSelectionIsProfileDriven := True;

   if winKeyer <> nil then
      begin
      logger.Info('[Keyer] profile "%s" uses WinKeyer "%s" on %s',
                  [aProfile.Name, winKeyer.Name, winKeyer.Port]);
      end;
end;

function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string;
                      const aKeyers: TKeyerConfigStore = nil): boolean;
var
   slot: integer;
   radioDef: TRadioDefinition;
   // NOT named radioPtr: Delphi is case-insensitive, so a variable of that name
   // shadows the TYPE RadioPtr in its own declaration.
   slotRadio: RadioPtr;
   previousCATWTR: RadioPtr;
begin
   aError := '';
   Result := False;

   if (aStore = nil) or (aProfile = nil) then
      begin
      aError := 'No profile to apply';
      Exit;
      end;

   // Resolve BOTH slots before touching anything.  Half-applying a profile --
   // slot one swapped, slot two failed -- would leave the station in a state
   // that matches neither the old profile nor the new one.
   for slot := 1 to 2 do
      begin
      if Trim(aProfile.RadioNameForSlot(slot)) = '' then
         begin
         Continue;
         end;
      if aStore.FindRadio(aProfile.RadioNameForSlot(slot)) = nil then
         begin
         aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                          [aProfile.Name, aProfile.RadioNameForSlot(slot)]);
         Exit;
         end;
      end;

   logger.Info('[ApplyProfile] Applying profile "%s"', [aProfile.Name]);

   // CATWTR is the "radio being configured" that uCAT's helpers work through.
   // Save and restore it: this unit is not the CAT dialog and must not leave
   // that global pointing somewhere the dialog does not expect.
   previousCATWTR := CATWTR;
   try
      for slot := 1 to 2 do
         begin
         if slot = 1 then
            begin
            slotRadio := @Radio1;
            end
         else
            begin
            slotRadio := @Radio2;
            end;

         CATWTR := slotRadio;

         // Stop first, for every slot, BEFORE any key is written.  If slot two
         // is about to take over slot one's COM port -- which is exactly what
         // swapping two radios on one interface looks like -- then writing and
         // reopening slot by slot would try to open a port the other radio has
         // not released yet.
         CloseCATAndKeyerForThisRadio;
         end;

      // Once, across both slots -- the enable flag is one flag for the program.
      ApplyKeyersForProfile(aKeyers, aProfile);

      for slot := 1 to 2 do
         begin
         radioDef := aStore.FindRadio(aProfile.RadioNameForSlot(slot));
         // radioDef is nil for an empty slot, and the renderer treats that as
         // "clear it" -- necessary, or the slot keeps whatever the previously
         // active profile left there.
         ApplyRadioToSlot(radioDef, slot, aProfile, True,
                          KeyerDeviceForSlot(aKeyers, aProfile, slot) <> nil);
         end;

      // The ini keys are correct but possibly scattered: WritePrivateProfileString
      // appends a newly-created key at the END of the section, so keys added to
      // TR4W after the operator's ini was first written land away from their
      // radio's block.  This puts them back.
      GroupRadioIniKeys;

      for slot := 1 to 2 do
         begin
         if slot = 1 then
            begin
            slotRadio := @Radio1;
            end
         else
            begin
            slotRadio := @Radio2;
            end;

         CATWTR := slotRadio;
         // A radio that fails to connect is NOT an apply failure: the port may
         // be busy, the rig may be off.  That is reported the same way it is
         // for any other connection attempt, and the profile is still active.
         slotRadio^.CheckAndInitializePorts_ForThisRadio;
         end;
   finally
      CATWTR := previousCATWTR;
   end;

   // Once, at the end: the keyer serves both radios, so re-initialising it per
   // slot would tear down the one just built.
   InitializeKeyer;
   DisplayRadio(ActiveRadio);

   aStore.ActiveProfileName := aProfile.Name;
   Result := True;
end;

{ ------------------------------------------------------- the store on disk - }

function SettingsDirectory: string;
begin
   Result := ExtractFilePath(string(AnsiString(PAnsiChar(@TR4W_INI_FILENAME[0]))));
end;

function RadioStoreFileName: string;
begin
   Result := SettingsDirectory + 'tr4w.json';
end;

function LegacyRadioStoreFileName: string;
begin
   Result := SettingsDirectory + 'tr4wradios.ini';
end;

function ReadRadioKey(const aKey: string): string;
var
   ini: TIniFile;
begin
   // TIniFile, not GetPrivateProfileString: under D12 the generic name
   // binds to the W variant and a bare buffer would compile silently while
   // reading UTF-16 into ANSI (see CLAUDE.md).  The RTL wrapper sidesteps
   // the whole question.
   ini := TIniFile.Create(SettingsDirectory + 'tr4w.ini');
   try
      Result := ini.ReadString('Radio', aKey, '');
   finally
      ini.Free;
   end;
end;

// The value the library WOULD render for one key -- read-only, so the startup
// path can report a disagreement without writing anything.  '' when the slot
// is empty or the key is not in the rendered set.
function RenderedValueFor(const aStore: TRadioConfigStore;
                          const aProfile: TStationProfile;
                          const aSlot: integer;
                          const aKey: string): string;
var
   radioDef: TRadioDefinition;
   rendered: TConfigKeyValues;
   i: integer;
begin
   Result := '';
   radioDef := aStore.FindRadio(aProfile.RadioNameForSlot(aSlot));
   if radioDef = nil then
      begin
      Exit;
      end;
   rendered := RenderRadioKeys(aSlot, radioDef,
                               ResolveTypeRendering(radioDef.RegistryId), aProfile);
   for i := 0 to High(rendered) do
      begin
      if SameText(rendered[i].Key, aKey) then
         begin
         Result := rendered[i].Value;
         Exit;
         end;
      end;
end;

function ApplyActiveProfileToConfigAtStartup(out aError: string): boolean;
var
   store: TRadioConfigStore;
   keyers: TKeyerConfigStore;
   profile: TStationProfile;
   slot: integer;
   radioDef: TRadioDefinition;
   previousCATWTR: RadioPtr;
   loadErr: string;
   before, after: string;
begin
   aError := '';
   Result := True;

   if not FileExists(RadioStoreFileName) then
      begin
      // No library: this station has never opened Preferences, and must boot
      // exactly as it always did.
      Exit;
      end;

   store  := TRadioConfigStore.Create;
   keyers := TKeyerConfigStore.Create;
   try
      // BOTH libraries, from the one file.  LoadConfig rather than the radio
      // store's own loader: a profile's CW output may name a keyer DEVICE, and
      // without the keyer library that name resolves to nothing -- the slot
      // would render no keyer port and the device would never be configured.
      // A file with no keyers section is not an error; the store stays empty.
      if not LoadConfig(RadioStoreFileName, store, keyers, loadErr) then
         begin
         // Readable-but-broken is worth saying out loud, because the legacy
         // keys are about to be used instead and the operator's library is
         // effectively ignored for this run.
         aError := loadErr;
         Result := False;
         Exit;
         end;

      // Published BEFORE the profile check: whether TR4W offers a TCI server
      // is a station-wide decision and does not depend on a profile
      // resolving, which is a separate failure with its own message.
      RadioLibraryTCIServerEnabled := store.TCIServerEnabled;

      profile := store.ActiveProfile;
      if profile = nil then
         begin
         logger.Debug('[Startup] radio library has no active profile -- leaving the [Radio] keys alone');
         Exit;
         end;

      // Both slots must resolve before anything is written.  A half-applied
      // profile at startup would leave the station matching neither the library
      // nor the ini, which is the exact confusion this whole change is about.
      for slot := 1 to 2 do
         begin
         if Trim(profile.RadioNameForSlot(slot)) = '' then
            begin
            Continue;
            end;
         if store.FindRadio(profile.RadioNameForSlot(slot)) = nil then
            begin
            aError := Format('Profile "%s" refers to radio "%s", which does not exist',
                             [profile.Name, profile.RadioNameForSlot(slot)]);
            logger.Warn('[Startup] %s -- leaving the [Radio] keys alone', [aError]);
            Result := False;
            Exit;
            end;
         end;

      // Once, across both slots -- see ApplyKeyersForProfile.  This is the path
      // that matters: the WK command rows are csJSON and inert, so a normal
      // start configures the WinKeyer here or not at all.
      ApplyKeyersForProfile(keyers, profile);

      previousCATWTR := CATWTR;
      try
         for slot := 1 to 2 do
            begin
            if slot = 1 then
               begin
               CATWTR := @Radio1;
               end
            else
               begin
               CATWTR := @Radio2;
               end;

            radioDef := store.FindRadio(profile.RadioNameForSlot(slot));
            // nil for an empty slot, which the renderer treats as "clear it" --
            // necessary, or the slot keeps whatever was last in the ini.
            //
            // aPersist=False: CONFIGURE, do not persist.  The library is
            // already the record, so writing a copy of it into tr4w.ini on
            // every start would be writing to disk purely to set globals --
            // and it would fail silently on a read-only program directory.
            // It also means a start CANNOT damage the operator's ini.
            ApplyRadioToSlot(radioDef, slot, profile, False,
                             KeyerDeviceForSlot(keyers, profile, slot) <> nil);
            end;

         // No GroupRadioIniKeys: nothing was written to group.
      finally
         CATWTR := previousCATWTR;
      end;

      // REPORT a stale ini; do not fix it.  Nothing above wrote to the file,
      // so the [Radio] keys may still say something the program is no longer
      // doing.  That is the intended answer to "ignore the ini where they
      // conflict" (NY4I) -- but silence would leave an operator reading a
      // file that has not been true since they last used Preferences, so the
      // disagreement is named, with the value that actually won.
      //
      // One representative key rather than all of them: this is a signpost
      // pointing at Preferences, not a diff.
      before := ReadRadioKey('RADIO ONE CONTROL PORT');
      after  := RenderedValueFor(store, profile, 1, 'RADIO ONE CONTROL PORT');
      if (after <> '') and (not SameText(before, after)) then
         begin
         logger.Warn('[Startup] tr4w.ini disagrees with the radio library and is being IGNORED: ' +
                     'RADIO ONE CONTROL PORT says "%s", profile "%s" uses "%s". ' +
                     'settings\tr4w.json is the format of record -- edit radios in Preferences. ' +
                     'The ini is rewritten only when a profile is applied there.',
                     [before, profile.Name, after]);
         end
      else
         begin
         logger.Info('[Startup] radio profile "%s" applied from the library',
                     [profile.Name]);
         end;
   finally
      keyers.Free;
      store.Free;
   end;
end;

{ --------------------------------------------------------- port conflicts - }

// A serial port value that actually names a port.  '' and 'NONE' do not, and
// treating them as ports would report a conflict on every station that leaves
// a keyer line unset -- the false positive that trains people to ignore the
// warning.
function IsRealPort(const aPort: string): boolean;
begin
   Result := (Trim(aPort) <> '') and (not SameText(Trim(aPort), PORT_NONE));
end;

function DescribePortConflicts(const aStore: TRadioConfigStore;
                               const aProfile: TStationProfile): string;
var
   radio1, radio2: TRadioDefinition;

   procedure Note(const aText: string);
   begin
      if Result <> '' then
         begin
         Result := Result + sLineBreak;
         end;
      Result := Result + aText;
   end;

   // CAT and keyer on the SAME port within one radio is not a conflict -- that
   // is CW by CAT, or a keyer sharing the CAT cable's control lines, and both
   // are normal.  Between two different radios it is.
   procedure CheckAcross(const aLabel1, aPort1, aLabel2, aPort2: string);
   begin
      if IsRealPort(aPort1) and SameText(Trim(aPort1), Trim(aPort2)) then
         begin
         Note(Format('%s and %s both use %s', [aLabel1, aLabel2, Trim(aPort1)]));
         end;
   end;

begin
   Result := '';
   if (aStore = nil) or (aProfile = nil) then
      begin
      Exit;
      end;

   radio1 := aStore.FindRadio(aProfile.Radio1Name);
   radio2 := aStore.FindRadio(aProfile.Radio2Name);

   if (radio1 = nil) or (radio2 = nil) then
      begin
      // One radio cannot collide with itself, and a dangling reference is
      // Validate's business, not this function's.
      Exit;
      end;

   if radio1.Transport = rtSerial then
      begin
      if radio2.Transport = rtSerial then
         begin
         CheckAcross(radio1.Name + ' CAT', radio1.ControlPort,
                     radio2.Name + ' CAT', radio2.ControlPort);
         end;
      CheckAcross(radio1.Name + ' CAT', radio1.ControlPort,
                  radio2.Name + ' keyer', radio2.KeyerOutputPort);
      end;

   if radio2.Transport = rtSerial then
      begin
      CheckAcross(radio2.Name + ' CAT', radio2.ControlPort,
                  radio1.Name + ' keyer', radio1.KeyerOutputPort);
      end;

   CheckAcross(radio1.Name + ' keyer', radio1.KeyerOutputPort,
               radio2.Name + ' keyer', radio2.KeyerOutputPort);
end;

end.
