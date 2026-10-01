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

(* THE OBJECT THAT SAYS WHAT aContest IS -- its names and ids, and the rest of
  its row. NEVER nil: a contest with a class answers from its class, one
  without is answered by a plain TContestBase reading ContestsArray. So every
  identity question -- the Cabrillo CONTEST: name, the ADIF CONTEST_ID, the
  friendly name, the WA7BNM and QRZ.RU ids -- has one answer per contest, and
  every consumer asks it here (M1, 2026-10-01). Contest SET-UP asks it too
  (M2, 2026-10-01): FCONTEST.ApplyContestTraits writes the engine's Active*
  values and set-up flags from this object, under the operator's
  statements -- what a contest IS, which is this accessor's whole job.

  OWNED BY THIS UNIT. Do not free it. Built the first time a contest is asked
  about and kept until the program ends, so a caller asking per QSO -- ADIF
  export, the UDP broadcast -- allocates nothing.

  SAFE FROM ANY THREAD. The score-posting clients ask from their worker
  threads, so building an instance is serialised; the getters themselves read
  constant tables.

  IT HAS NO STATION, AND IS NOT THE SCORING OBJECT. Ask it what a contest IS,
  never to score a QSO: uContestFactory.ActiveContest is the object that
  carries the station, and answers nil for a contest with no class so its
  callers keep the legacy path. That nil is right for scoring and wrong for a
  name, which is why this is a separate accessor rather than a mode of that
  one. *)
function ContestIdentity(aContest: ContestType): TContestBase;

(* WHICH CONTEST ANSWERS TO THIS ADIF CONTEST_ID? True with aContest set when
  one does; False, with aContest at Low(ContestType), when none does.

  IT ASKS EVERY CONTEST, CLASS OR NOT, THROUGH ContestIdentity -- the object
  ADIF export asks too. So the id this matches IS the id export writes, by
  construction, and a file TR4W exported resolves to the contest it came from
  (inventory D9, closed by M1). The one current-id collision is RSGB-ROLO,
  which the CW and SSB rows share: it resolves to the CW running, as it
  always has.

  THE ORDER IS THE RULE:
    1. the input is TRIMMED, and an empty result matches NOTHING. A blank id
       means "this contest has none", so it can never identify one -- matching
       it is how an import used to land on the first blank row;
    2. every contest's CURRENT id is tried first, over the whole table;
    3. only then its FORMER ids (TContestBase.FormerADIFContestIds).
  So a rename can never let an old spelling steal a name another contest uses
  today. Within each pass the lowest ContestType wins, which is what the old
  lookup did for the one id two rows still share (RSGB-ROLO, CW and SSB).

  COMPARISON IS EXACT after the trim, as the lookup it replaces was.

  WHY IT LIVES HERE AND NOT IN uADIF. "Which contest is this" is a question
  about the whole set of contests, and this unit is the one that knows which
  class serves each. uADIF keeps its cache and calls this. *)
function FindContestByADIFContestId(const aId: string;
                                    out aContest: ContestType): boolean;

implementation

uses
   SysUtils,
   SyncObjs;

var
   GRegistry: array[ContestType] of TContestClass;

   (* ContestIdentity's instances, one per contest, built on first ask, and
      the lock that serialises building them. *)
   GIdentity: array[ContestType] of TContestBase;
   GIdentityLock: TCriticalSection;

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

   (* A REGISTRATION AFTER THE CONTEST WAS ASKED ABOUT. ContestIdentity would
      already hold a plain TContestBase for it and keep answering from the
      row, silently. Registration belongs in a unit's initialization, which
      runs before anything asks. *)
   if GIdentity[aContest] <> nil then
      begin
      raise Exception.CreateFmt(
         '%s registered for %s after the contest''s identity was already ' +
         'asked for. Register from the unit''s initialization section.',
         [aCls.ClassName, string(ContestTypeSA[aContest])]);
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

function ContestIdentity(aContest: ContestType): TContestBase;
begin
   GIdentityLock.Acquire;
   try
      if GIdentity[aContest] = nil then
         begin
         if GRegistry[aContest] <> nil then
            begin
            GIdentity[aContest] := GRegistry[aContest].Create(aContest);
            end
         else
            begin
            GIdentity[aContest] := TContestBase.Create(aContest);
            end;
         end;
      Result := GIdentity[aContest];
   finally
      GIdentityLock.Release;
      end;
end;

function FindContestByADIFContestId(const aId: string;
                                    out aContest: ContestType): boolean;
var
   id: string;
   c: ContestType;
   obj: TContestBase;
   former: TContestIdList;
   i: integer;
   haveFormer: boolean;
   formerContest: ContestType;
begin
   Result := False;
   aContest := Low(ContestType);

   id := Trim(aId);
   if id = '' then
      begin
      Exit;
      end;

   (* ONE WALK, TWO ANSWERS. A current-id match ends the search at once; a
      former-id match is only remembered, because a later contest's CURRENT id
      must still beat it. *)
   haveFormer := False;
   formerContest := Low(ContestType);
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := ContestIdentity(c);
      if obj.ADIFContestId = id then
         begin
         aContest := c;
         Result := True;
         Exit;
         end;

      if not haveFormer then
         begin
         former := obj.FormerADIFContestIds;
         for i := 0 to High(former) do
            begin
            if former[i] = id then
               begin
               haveFormer := True;
               formerContest := c;
               Break;
               end;
            end;
         end;
      end;

   if haveFormer then
      begin
      aContest := formerContest;
      Result := True;
      end;
end;

procedure FreeIdentities;
var
   c: ContestType;
begin
   for c := Low(ContestType) to High(ContestType) do
      begin
      FreeAndNil(GIdentity[c]);
      end;
end;

initialization
   GIdentityLock := TCriticalSection.Create;

finalization
   FreeIdentities;
   FreeAndNil(GIdentityLock);

end.
