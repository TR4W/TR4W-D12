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

  It also means STARTUP NEEDS NOTHING FROM THIS UNIT.  The legacy keys were
  written at the last apply, so ReadInConfigFile loads them exactly as it always
  did and the existing CheckAndInitializePorts calls connect the radios.  There
  is no second initialisation path to keep in step, and an operator who never
  opens the new dialog is running the code they were running before.

  ON COEXISTENCE WITH THE OLD DIALOG.  Both write the same [Radio] keys, so it
  is last-writer-wins.  That is a deliberate non-goal for this increment: no
  sync-back, no locking.  The UI is expected to say so when the active profile's
  rendered keys differ from what is actually in the ini.

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
   uRadioConfigStore,
   uRadioConfigLegacyMap;

// Resolve what the registry says about a definition's identity, so the pure
// renderer does not have to know the registry exists.
function ResolveTypeRendering(const aRegistryId: string): TRadioTypeRendering;

// Write one slot's keys and hand each to CheckCommand.  Does NOT touch ports;
// ApplyProfile sequences that.  aRadio may be nil, meaning "clear this slot".
procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile);

// The whole sequence: stop both radios, write both slots, regroup the ini,
// restart.  Returns False with aError set if the profile cannot be applied at
// all (unknown radio names); a radio that merely fails to CONNECT is not an
// error here -- that is reported by the normal connection path.
function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string): boolean;

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
   LOGRADIO,
   LOGK1EA,    // ActiveRadio
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
end;

procedure ApplyRadioToSlot(const aRadio: TRadioDefinition;
                           const aSlot: integer;
                           const aProfile: TStationProfile);
var
   rendered: TConfigKeyValues;
   i: integer;
   typeRendering: TRadioTypeRendering;
   idKey, cmdValue: AnsiString;
   keyShort, valueShort: ShortString;
begin
   if aRadio <> nil then
      begin
      typeRendering := ResolveTypeRendering(aRadio.RegistryId);
      end
   else
      begin
      typeRendering := Default(TRadioTypeRendering);
      end;

   rendered := RenderRadioKeys(aSlot, aRadio, typeRendering, aProfile);

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

      if rendered[i].Delete then
         begin
         // nil, not '' -- a nil value REMOVES the key.  An empty string would
         // leave the key present with a blank value, which for FACTORY ID is
         // not the same thing at all.
         Windows.WritePrivateProfileStringA('Radio', @keyShort[1], nil,
                                            TR4W_INI_FILENAME);
         end
      else
         begin
         Windows.WritePrivateProfileStringA('Radio', @keyShort[1], @valueShort[1],
                                            TR4W_INI_FILENAME);
         end;

      // CheckCommand is what actually moves the value into TR4W's globals; the
      // ini write above is only what makes it survive a restart.  A key CFGCA
      // does not recognise answers False -- worth a warning, because it means
      // the renderer and CFGCA have drifted apart.
      if not CheckCommand(@keyShort, valueShort) then
         begin
         logger.Warn('[ApplyRadioToSlot] CFGCA did not accept "%s" = "%s"',
                     [rendered[i].Key, rendered[i].Value]);
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

function ApplyProfile(const aStore: TRadioConfigStore;
                      const aProfile: TStationProfile;
                      out aError: string): boolean;
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

      for slot := 1 to 2 do
         begin
         radioDef := aStore.FindRadio(aProfile.RadioNameForSlot(slot));
         // radioDef is nil for an empty slot, and the renderer treats that as
         // "clear it" -- necessary, or the slot keeps whatever the previously
         // active profile left there.
         ApplyRadioToSlot(radioDef, slot, aProfile);
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
