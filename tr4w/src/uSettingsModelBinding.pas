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
unit uSettingsModelBinding;
{$I tr4w.inc}

(*
  PREFERENCES, EDITING A SETTING THAT HAS NO CFGCA ROW.

  ------------------------------------------------------------------------
  WHY THIS UNIT EXISTS
  ------------------------------------------------------------------------

  uSettingsLegacy has two setting classes and BOTH are bound to the array.
  TLegacySetting reads its value through CFGCommandValueAsString and takes
  four of its own attributes -- NeedsRestart, HasSideEffects, ReadOnly,
  Broadcast -- straight out of the row's crJ, crP, crA and crNetwork fields.
  TStoredSetting descends from it and changes only where the write goes.

  So a setting whose row has been DELETED cannot be registered at all: the
  constructor raises "no CFGCA command called ...", which is exactly what it
  is supposed to do for a typo, and exactly wrong for a setting that has
  graduated.  That is the bridge, and it is the last one holding the eleven
  band settings to the array.

  THIS IS THE NON-LEGACY BINDING, AND IT IS A SEPARATE UNIT ON PURPOSE.  Put
  in uSettingsLegacy it would be a class named for what it is not, in a unit
  named for what it is not either.  Here, the day the last row leaves CFGCA,
  uSettingsLegacy is deleted whole rather than unpicked.

  ------------------------------------------------------------------------
  THE FOUR ATTRIBUTES, AND WHY THEY ARE CONSTANTS HERE
  ------------------------------------------------------------------------

  They came from the row.  With no row they come from what the settings model
  IS, and three of the four are the same for every setting in it:

    NeedsRestart    FALSE.  crJ:1 meant "restart required", and a property
                    setter applies the value and raises its side effect on
                    the spot.  Needing a restart was a property of assigning
                    a global that nothing re-read.

    ReadOnly        FALSE.  crJ 2 and 3 marked rows that were displayed but
                    not editable.  A published property is editable; a
                    setting that should not be is not registered here.

    HasSideEffects  TRUE, always, and this is the one that changed MEANING.
                    crP and crA meant "writing this row happens to run code",
                    and it was false for most rows.  Every write here goes
                    through a setter, so the honest answer is always yes.

    Broadcast       TRUE.  All eleven carried crNetwork:1, and a display
                    filter or a band rule is exactly the kind of change the
                    other position at a multi-op needs.  It is a parameter
                    per setting rather than a constant, so a future setting
                    that must NOT leave the station can say so.
*)

interface

uses
   uSettingsRegistry;   // TSettingBase, RegisterSetting

(* Register a setting that lives in uSettingsModel and has no CFGCA row.

  aKey is the store key ('operating.bands.hf'), aCommand the config command
  name the settings object answers to ('HF BAND ENABLE'), aCaption the text
  Preferences shows. *)
function RegisterModelSetting(const aKey, aCommand, aCaption: string;
                              const aBroadcast: boolean = True): TSettingBase;

implementation

uses
   SysUtils,
   uSettingsModel,
   uTR4WConfigFile;   // TR4WConfigFileName, SaveSettings

type
   TModelSetting = class(TSettingBase)
   private
      FCommand: string;
   public
      constructor Create(const aKey, aCommand, aCaption: string;
                         const aBroadcast: boolean);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      property Command: string read FCommand;
   end;


constructor TModelSetting.Create(const aKey, aCommand, aCaption: string;
                                 const aBroadcast: boolean);
begin
   inherited Create(aKey, aCaption);
   FCommand := aCommand;
   LegacyCommand := aCommand;   // indexed by the Preferences search box

   (* LOUD AT REGISTRATION, for the same reason the legacy class is loud: a
     mistyped command name would otherwise present as a control that reads
     blank and silently discards what is typed into it, and only when that
     panel is opened. *)
   if not Settings.OwnsCommand(aCommand) then
      begin
      raise Exception.CreateFmt(
         'Setting "%s": the settings model does not own a command called "%s"',
         [aKey, aCommand]);
      end;

   NeedsRestart   := False;
   ReadOnly       := False;
   HasSideEffects := True;
   Broadcast      := aBroadcast;
end;


function TModelSetting.AsText: string;
begin
   if not Settings.TryGetByCommand(FCommand, Result) then
      begin
      (* Cannot happen -- the constructor proved the command resolves and
        nothing unregisters one -- but AsText is documented never to raise,
        because a setting that cannot render itself must not take a
        Preferences page down with it. *)
      Result := '';
      end;
end;


function TModelSetting.TrySetText(const aText: string; out aError: string): boolean;
begin
   aError := '';

   (* APPLY, THEN PERSIST, AND ONLY IF IT WAS TAKEN.

     The order matters and it is the same rule the stored form follows: a
     value the property's type refuses must never reach the file.  What is
     different is that there is no separate "apply" step -- assigning the
     property IS the application, and its setter raises the redraw. *)
   Result := Settings.TrySetByCommand(FCommand, aText);
   if not Result then
      begin
      aError := Format('%s does not accept "%s"', [FCommand, aText]);
      Exit;
      end;

   SaveSettings(TR4WConfigFileName, Settings);

   (* OnApply directly, NOT an AfterApplied helper.  That helper belongs to
     TLegacySetting, where it also runs the row's crA hook -- a setting with no
     row has no hook to run, and its side effect has already happened inside
     the property setter by the time we get here. *)
   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;


function RegisterModelSetting(const aKey, aCommand, aCaption: string;
                              const aBroadcast: boolean = True): TSettingBase;
begin
   Result := RegisterSetting(TModelSetting.Create(aKey, aCommand, aCaption,
                                                  aBroadcast));
end;

end.
