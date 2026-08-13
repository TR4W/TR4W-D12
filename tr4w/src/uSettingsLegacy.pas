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
  stable, the command is the legacy spelling and will eventually go. }
function RegisterLegacySetting(const aKey, aCommand, aCaption: string): TSettingBase;

implementation

uses
   SysUtils,
   uCFG;

type
   { A CFGCA row wearing the registry's interface.  See the unit header for why
     this is one class rather than a closure per row. }
   TLegacySetting = class(TSettingBase)
   private
      FCommand: string;
   public
      constructor Create(const aKey, aCommand, aCaption: string);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;
      property Command: string read FCommand;
   end;

{ ---------------------------------------------------------- TLegacySetting - }

constructor TLegacySetting.Create(const aKey, aCommand, aCaption: string);
var
   idx: integer;
begin
   inherited Create(aKey, aCaption);
   FCommand := aCommand;

   idx := FindCFGCommand(aCommand);
   if idx < 0 then
      begin
      // Loud at registration.  A mistyped command name would otherwise present
      // as a control that reads blank and silently discards what is typed into
      // it -- and it would do so only when that panel is opened.
      raise Exception.CreateFmt('Setting "%s": no CFGCA command called "%s"',
                                [aKey, aCommand]);
      end;

   // crJ:1 is the table's way of saying "restart required".  Lifting it here
   // means a UI can say so without every panel hard-coding which of its fields
   // are which.
   NeedsRestart := (CFGCA[idx].crJ = 1);
end;

function TLegacySetting.AsText: string;
begin
   Result := CFGCommandValueAsString(FCommand);
end;

function TLegacySetting.AllowedValues: TArray<string>;
begin
   // Only ckArray rows answer this today.  ckList rows have a spelling list
   // too, but it lives in a different array reached through a different index,
   // and those are being converted to TEnumSetting rather than taught here --
   // adding a second lookup would be extending the design we are leaving.
   Result := CFGCommandAllowedValues(FCommand);
end;

function TLegacySetting.TrySetText(const aText: string; out aError: string): boolean;
begin
   aError := '';

   // Through CheckCommand, not by assignment: it is what enforces crMin/crMax,
   // runs the row's crA hook, and knows which typed global the value belongs
   // in.  Bypassing it is what the SCP MINIMUM LETTERS access violation came
   // from.
   Result := SetCFGCommandValue(FCommand, aText);
   if not Result then
      begin
      aError := Format('%s does not accept "%s"', [FCommand, aText]);
      Exit;
      end;

   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function RegisterLegacySetting(const aKey, aCommand, aCaption: string): TSettingBase;
begin
   Result := RegisterSetting(TLegacySetting.Create(aKey, aCommand, aCaption));
end;

end.
