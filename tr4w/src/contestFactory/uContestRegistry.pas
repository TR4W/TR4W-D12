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

(* WHICH CLASS SERVES WHICH CONTEST -- the single source of truth, as
  uRadioRegistry is for radios.

  A contest unit registers itself from its own initialization section, so
  adding a contest touches its own unit and the two program files that list
  units, and nothing else. That property is the reason the radio factory is
  worth copying: it was verified there by adding TCI without changing a single
  shared file.

  AN ARRAY INDEXED BY ContestType, NOT A LIST. There are ~200 contests and the
  enum is dense, so the lookup is one index. It also means a registration for a
  contest that already has one is a DUPLICATE this can see and refuse -- the
  radio registry learned that the hard way, where a duplicate display name made
  a model invisible in the list rather than raising anything.

  NOT EVERY CONTEST HAS A CLASS, AND THAT IS THE POINT. This is a strangler:
  Lookup answers nil for a contest nobody has moved yet, and the caller falls
  through to the legacy path unchanged. *)
unit uContestRegistry;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

(* Registers aCls as the class serving aContest.

  RAISES on a duplicate. A second registration for one contest is a programming
  error -- two units both claiming ARRL-DX-CW -- and the alternatives are worse:
  last-wins hides it completely, and first-wins hides it while making the
  behaviour depend on unit initialisation order, which is the .lpr's uses clause
  and not something anyone reads as an ordering. *)
procedure RegisterContest(aContest: ContestType; aCls: TContestClass);

(* The class serving aContest, or nil when nothing has been registered for it.
  nil is an ORDINARY ANSWER during the migration, not a failure. *)
function ContestClassFor(aContest: ContestType): TContestClass;

(* How many contests have a class. For a lint or a test to assert against, so
  that "the factory is empty" cannot be mistaken for "the factory agrees with
  the legacy path". *)
function RegisteredContestCount: integer;

implementation

uses
   SysUtils;

var
   GRegistry: array[ContestType] of TContestClass;

procedure RegisterContest(aContest: ContestType; aCls: TContestClass);
begin
   if aCls = nil then
      begin
      raise Exception.CreateFmt(
         'RegisterContest(%s) was given a nil class.',
         [string(ContestTypeSA[aContest])]);
      end;

   if GRegistry[aContest] <> nil then
      begin
      raise Exception.CreateFmt(
         'Two classes claim %s: %s is already registered and %s tried to ' +
         'register as well. One contest, one class.',
         [string(ContestTypeSA[aContest]),
          GRegistry[aContest].ClassName, aCls.ClassName]);
      end;

   GRegistry[aContest] := aCls;
end;

function ContestClassFor(aContest: ContestType): TContestClass;
begin
   Result := GRegistry[aContest];
end;

function RegisteredContestCount: integer;
var
   c: ContestType;
begin
   Result := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if GRegistry[c] <> nil then
         begin
         inc(Result);
         end;
      end;
end;

end.
