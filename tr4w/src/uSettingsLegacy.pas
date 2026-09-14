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
unit uSettingsLegacy;
{$I tr4w.inc}

{
  ADAPTS ONE CFGCA ROW to the settings registry's interface.

  Split out of uSettingsBinding, which now holds only the FMX control bindings.
  The two had nothing to do with each other: registering a setting is about the
  CONFIG SYSTEM, binding one to a checkbox is about the UI FRAMEWORK.  Keeping
  them together meant uSettingsDeclarations -- 200 lines of pure registration --
  dragged FMX.StdCtrls, FMX.Edit and FMX.ListBox behind it, which is what made
  the unit-test executable un-buildable without a UI framework.

  THE LEGACY BRIDGE, and why it is one class rather than thirty closures.
  Most settings still live in CFGCA, whose crAddress is an untyped pointer that
  is sometimes not even an address -- the design NY4I objected to and the source
  of the SCP MINIMUM LETTERS access violation.  It cannot all be converted at
  once, so TLegacySetting adapts one CFGCA row to the registry's interface:
  reading through CFGCommandValueAsString, writing through CheckCommand so the
  row's bounds and crA hook still run.

  The point is CONTAINMENT.  That indirection now exists in exactly one class,
  behind the same interface as every other setting.  A panel cannot tell a
  legacy setting from a modern one, so when a row graduates -- to a typed
  closure over its global, or to a self-storing setting with no global at all --
  its registration changes and NOT ONE LINE of the panel does.
}

interface

uses
   uSettingsRegistry;

{ Registers a CFGCA row as a setting under a modern key.

  aKey is the JSON/store key ('operating.cw.sayHi'); aCommand is the CFGCA row
  ('SAY HI ENABLE').  The two are deliberately different: the key is ours and
  stable, the command is the legacy spelling and will eventually go.

  WRITES GO TO THE INI.  This is the un-migrated state: SetCFGCommandValue puts
  the value in tr4w.ini, the row stays visible in Ctrl-J, and the ini loader
  re-applies it at startup.  See RegisterStoredSetting for the migrated form. }
(* RegisterLegacySetting IS GONE -- 2026-09-14, with the last CFGCA row.

  It registered a setting whose value lived in the array, and its constructor
  read four of its own attributes out of the row (crJ, crP, crA, crNetwork) --
  so it could not register a setting whose row had moved. That split was
  deliberate, and it is why this unit could be unpicked cleanly rather than
  rewritten: a migrated setting went to RegisterModelSetting and an unmigrated
  one stayed here, and the two were never the same name.

  WHAT REMAINS IS NOT LEGACY. TStoredSetting writes settings/tr4w.json through
  the radio configuration store, which is where the radio, keyer, cluster and
  profile libraries keep their values. *)
function RegisterStoredSetting(const aKey, aCommand, aCaption: string): TSettingBase;

type
   { Returns the TRadioConfigStore currently being edited, or nil.  Typed as
     TObject so this unit does not have to pull in uRadioConfigStore's interface
     -- the implementation casts it back. }
   TActiveStoreProvider = function: TObject;

var
   { Set by Preferences while it is open, cleared when it closes.  Nil means
     "no store", and a stored setting then refuses the write rather than
     silently dropping it -- a settings screen that accepts a value it did not
     save is the failure this whole exercise is about. }
   ActiveStoreProvider: TActiveStoreProvider = nil;

implementation

uses
   SysUtils,
   MainUnit,               // logger -- see the config-change lines below
   uCFG,
   uSettingsModel,        // Settings.OwnsCommand -- the registration check
   uRadioConfigStore,     // TRadioConfigStore -- the cast in TStoredSetting
   uRadioConfigApply;     // ApplyAndStoreCommand

type
   { A SETTING THE CONFIGURATION STORE OWNS, wearing the registry's interface.

     ONE CLASS NOW, NOT TWO. It was TLegacySetting plus a descendant, and they
     differed only in WHERE a write went -- tr4w.ini, or the store. The ini
     path went with the array: there is no row for it to apply and no file for
     it to write. Folding the base in keeps the reading half beside its only
     user. }
   TStoredSetting = class(TSettingBase)
   private
      FCommand: string;
   protected
      { What happens AFTER a value is accepted: tell the form. }
      procedure AfterApplied;
   public
      constructor Create(const aKey, aCommand, aCaption: string);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;
      property Command: string read FCommand;
   end;

{ ----------------------------------------------------------- TStoredSetting - }

constructor TStoredSetting.Create(const aKey, aCommand, aCaption: string);
begin
   inherited Create(aKey, aCaption);
   FCommand := aCommand;
   LegacyCommand := aCommand;   // indexed by the Preferences search box

   (* LOUD AT REGISTRATION. A mistyped command name would otherwise present as
     a control that reads blank and silently discards what is typed into it,
     and only when that panel is opened.

     ASKED OF THE SETTINGS OBJECT, not of a row: FindCFGCommand stood here and
     the array it searched is gone. Same guarantee, same failure mode. *)
   if not Settings.OwnsCommand(aCommand) then
      begin
      raise Exception.CreateFmt(
         'Setting "%s": the settings model does not own a command called "%s"',
         [aKey, aCommand]);
      end;

   (* THE FOUR ATTRIBUTES THAT CAME OUT OF THE ROW ARE NOW THE DEFAULTS, and
     each has a better home than a byte in a table:

       crJ:1  NeedsRestart   -- a parameter on RegisterModelSetting, because
                                it is true of almost nothing: a property
                                setter applies the value on the spot.
       crP/crA HasSideEffects -- a setter always has them, and it runs however
                                the value was set rather than only when a
                                config line applied a row.
       crJ 2/3 ReadOnly      -- set by the caller at registration.
       crNetwork Broadcast   -- uCFG.CommandIsSharedWithPeers, which is a
                                statement about the multi-op protocol rather
                                than about the setting. *)
   NeedsRestart   := False;
   ReadOnly       := False;
   HasSideEffects := True;
end;

procedure TStoredSetting.AfterApplied;
begin
   (* THE REDRAW RAN HERE UNTIL 2026-09-14, as RunCommandRedrawProc: thirty
     rows carried a crP handler and only the old Ctrl-J dialog ever ran it, so
     a setting changed in Preferences reached its global immediately and the
     screen at the next start. It is the property's setter now, which means it
     has already happened by the time we get here. *)
   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function TStoredSetting.AsText: string;
begin
   Result := CFGCommandValueAsString(FCommand);
end;

function TStoredSetting.AllowedValues: TArray<string>;
begin
   Result := CFGCommandAllowedValues(FCommand);
end;

function TStoredSetting.TrySetText(const aText: string; out aError: string): boolean;
var
   store: TObject;
   wasText: string;
begin
   aError := '';

   { WHAT IT SAID BEFORE, so the log below can report a CHANGE rather than a
     write. Preferences calls this twice for the same value on purpose -- once
     as the operator types, so accepted values apply immediately, and again on
     OK, so refusals can be reported together -- and both calls logged, which
     read as the program doing the work twice. NY4I, 2026-08-28: "I see two
     messages in the log as if we are going through this code twice."

     It IS going through it twice, and that is the design. What was wrong was
     saying so twice. }
   wasText := AsText;

   if not Assigned(ActiveStoreProvider) then
      begin
      // REFUSE, don't fall back to the ini. Falling back would write the value
      // to a file the row no longer reads (crS = csJSON), so the setting would
      // appear to save and be gone on restart -- silently, and only for the
      // settings that had graduated. Refusing is visible.
      aError := Format('%s cannot be saved: no configuration store is open', [Command]);
      Result := False;
      Exit;
      end;

   store := ActiveStoreProvider();
   if not (store is TRadioConfigStore) then
      begin
      aError := Format('%s cannot be saved: no configuration store is open', [Command]);
      Result := False;
      Exit;
      end;

   // APPLY THEN RECORD, and both through one call: ApplyAndStoreCommand runs
   // CheckCommand with aApplyJSONOwned = True -- which is what makes a csJSON
   // row accept the value at all -- and only records it in the store if CFGCA
   // took it. A rejected value never reaches the file.
   Result := ApplyAndStoreCommand(TRadioConfigStore(store), Command, aText);

   { SAY WHAT CHANGED, the same as the ini path does in
     SetCFGCommandValue.  NY4I asked for both (bench queue): with 226
     settings in the JSON store and 3 left on the ini, a log that covered
     only one of the two would answer 'which setting moved' for the
     smaller half and say nothing about the rest.

     DEBUG, not INFO: one OK on a Preferences page can write dozens of
     rows. And the REJECTION is the half worth having -- a refused value
     is otherwise discarded with nothing anywhere to say why. }
   if logger.IsDebugEnabled then
      begin
      if Result and (AsText <> wasText) then
         begin
         logger.Debug('[Config] %s = %s (was %s, stored in tr4w.json)',
                      [Command, aText, wasText]);
         end
      else if Result then
         begin
         { Re-applied with no change -- the second of the two calls above, or a
           keystroke that landed back on the same value. Nothing to say. }
         end
      else
         begin
         logger.Debug('[Config] %s = %s REJECTED -- not applied, not stored', [Command, aText]);
         end;
      end;

   if not Result then
      begin
      aError := Format('%s does not accept "%s"', [Command, aText]);
      Exit;
      end;

   AfterApplied;
end;

function RegisterStoredSetting(const aKey, aCommand, aCaption: string): TSettingBase;
begin
   Result := RegisterSetting(TStoredSetting.Create(aKey, aCommand, aCaption));
end;

end.
