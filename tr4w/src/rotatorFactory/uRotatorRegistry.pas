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
unit uRotatorRegistry;
{$I ..\tr4w.inc}

{
  WHICH ROTATORS EXIST -- the single source of truth, exactly as
  uRadioRegistry is for radios.

  Each driver unit registers itself from its own initialization section, so
  ADDING A ROTATOR TOUCHES ONE NEW UNIT plus the two project files.  No shared
  table to edit, no parallel arrays to keep in step -- those are what the radio
  factory removed, and repeating them here would be repeating the mistake for
  the sake of familiarity.

  IDs ARE STRINGS, not an enum.  The legacy RotatorType enum
  (logwind.pas:133) is what makes the current code a `case`, and an enum forces
  every new rotator through a shared type declaration -- which is precisely the
  shared file a factory exists to stop editing.  The ids here are deliberately
  the legacy SPELLINGS ('DCU1', 'ORION', 'YAESU', 'ALFA SPID', 'PSTROTATOR')
  from RotatorTypeSA, so an existing ROTATOR TYPE line in an operator's ini
  still names something real while the two systems overlap.

  SELF-REGISTRATION HAS ONE HAZARD and it is worth naming: a unit dropped from
  the project link registers nothing and fails SILENTLY -- the rotator simply
  is not offered.  RegisteredCount exists so a test can assert the number, the
  same guard uRadioRegistry uses, and that test is what turns a link-order
  accident into a failing build.
}

interface

uses
   SysUtils,
   Generics.Collections,
   uRotatorBase;

type
   (*
     WHICH ROTATORS EXIST, AS THE SUBSYSTEM'S OWN TAXONOMY.

     Moved here from trdos/logwind.pas, 2026-09-13. NY4I: the rotator is a
     subsystem, so its type parameters are "strictly supporting the factory
     objects (just like the radio works)" -- they belong with the factory and
     not in the settings model, which holds only a TOKEN.

     THE ENUM IS NEARLY VESTIGIAL ALREADY, and that is the point of the note
     below: ids are STRINGS here. What survives is the legacy seed, which
     turns an operator's ROTATOR TYPE into an id.
   *)
   RotatorType = (NoRotator, DCU1Rotator, OrionRotator, YaesuRotator,
                  AlfaSpidRotator, PSTRotator);

   { A PLAIN procedure pointer. Each driver registers a named unit-level
     function; none of them captured anything, so the anonymous form bought
     nothing and cost a closure-capable compiler. }
   TRotatorFactoryProc = function (const aSend: TRotatorSendProc): TRotatorBase;

const
   (* THE CONFIG-FILE TOKEN FOR EACH, IN ORDINAL ORDER. string, not PAnsiChar:
     nothing indexes it through a pointer since the CFGCA row went.

     REGISTERED BY NAME against Settings.Rotator.RotatorType, which is both
     what a config file is allowed to say and what the Preferences drop-down
     offers -- and what Lint-SpellingTables checks. *)
   RotatorTypeSA: array[RotatorType] of string =
      ('NONE', 'DCU1', 'ORION', 'YAESU', 'ALFA SPID', 'PSTROTATOR');

{ Called from a driver unit's initialization. }
procedure RegisterRotator(const aId, aDisplayName: string;
                          const aCreate: TRotatorFactoryProc);

{ Build one, or nil when the id is not registered.  nil is a legitimate answer
  -- an ini naming a rotator this build does not have -- and the caller reports
  it rather than the registry raising into a startup path. }
function CreateRotator(const aId: string; const aSend: TRotatorSendProc): TRotatorBase;

function IsRegistered(const aId: string): boolean;
function RotatorDisplayName(const aId: string): string;

{ Every registered id, in registration order, for a settings drop-down. }
function RegisteredRotatorIds: TArray<string>;
function RegisteredCount: integer;

implementation

uses
   uSettingsModel;   (* RegisterSettingAllowedValues -- this unit publishes
                       its own vocabulary; see the initialization section *)

type
   TRotatorEntry = record
      Id: string;
      DisplayName: string;
      Create: TRotatorFactoryProc;
   end;

var
   GEntries: TList<TRotatorEntry> = nil;

function IndexOfId(const aId: string): integer;
var
   i: integer;
begin
   Result := -1;
   if GEntries = nil then
      begin
      Exit;
      end;
   for i := 0 to GEntries.Count - 1 do
      begin
      if SameText(GEntries[i].Id, aId) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

procedure RegisterRotator(const aId, aDisplayName: string;
                          const aCreate: TRotatorFactoryProc);
var
   e: TRotatorEntry;
begin
   if GEntries = nil then
      begin
      GEntries := TList<TRotatorEntry>.Create;
      end;

   // A DUPLICATE ID IS A DEFECT, and a silent one: whichever unit initialised
   // last would win, and which that is depends on link order.  The radio
   // registry learned this as "a duplicate display name makes a model invisible
   // in the list"; here it would make a rotator answer with another's protocol.
   if IndexOfId(aId) >= 0 then
      begin
      raise Exception.CreateFmt('Rotator "%s" is registered twice', [aId]);
      end;

   e.Id          := aId;
   e.DisplayName := aDisplayName;
   e.Create      := aCreate;
   GEntries.Add(e);
end;

function CreateRotator(const aId: string; const aSend: TRotatorSendProc): TRotatorBase;
var
   i: integer;
begin
   Result := nil;
   i := IndexOfId(aId);
   if i >= 0 then
      begin
      Result := GEntries[i].Create(aSend);
      end;
end;

function IsRegistered(const aId: string): boolean;
begin
   Result := IndexOfId(aId) >= 0;
end;

function RotatorDisplayName(const aId: string): string;
var
   i: integer;
begin
   Result := '';
   i := IndexOfId(aId);
   if i >= 0 then
      begin
      Result := GEntries[i].DisplayName;
      end;
end;

function RegisteredRotatorIds: TArray<string>;
var
   i: integer;
begin
   if GEntries = nil then
      begin
      Result := nil;
      Exit;
      end;
   SetLength(Result, GEntries.Count);
   for i := 0 to GEntries.Count - 1 do
      begin
      Result[i] := GEntries[i].Id;
      end;
end;

function RegisteredCount: integer;
begin
   if GEntries = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := GEntries.Count;
      end;
end;

initialization
   (* THE VOCABULARY A CONFIG FILE MAY USE FOR ROTATOR TYPE.

     Published BY THE SUBSYSTEM, because the subsystem is what knows which
     rotators exist -- the settings model holds only the token. Registered by
     NAME so Lint-SpellingTables still checks it: a duplicate or blank here
     would make a rotator unreachable by name. *)
   RegisterSettingAllowedValues('Rotator.RotatorType', RotatorTypeSA);

finalization
   FreeAndNil(GEntries);

end.
