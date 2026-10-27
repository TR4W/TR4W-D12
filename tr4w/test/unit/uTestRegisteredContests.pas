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

(* WALKING THE REGISTERED CONTESTS, AND ASKING WHICH CLASS STATES A RULE --
  Q108 S1, 2026-10-16 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  TWO KINDS OF CROSS-CONTEST TEST, AND THEY WALK DIFFERENT THINGS.

  - A PIN TABLE freezes what each LEGACY contest answers, keyed by
    ContestType. It walks the enum, and a contest registered by its string id
    (Q108 S3) is invisible to it by construction -- that is a value freeze
    over the 188, and it never grows.
  - AN INVARIANT says something about EVERY contest: a key only where the
    multiplier exists, every party splits a rover call and nothing else does,
    every class states its identity. It must see a contest with no enum
    member too, so it walks ContestsToWalk, here -- the registry.

  "Does every contest ... " is never answered by a hand-maintained count of
  how many do. A count restates the set beside it and moves with every rule
  change to a legacy contest; the invariant it stood for is asserted instead.

  THE OVERRIDE QUESTION. A contest rule has no inherited default (NY4I): each
  contest states its bands, its columns, its parse format. "Did this class
  state it" is asked by comparing the CODE behind a virtual getter in the
  object with the code behind it in another object -- its parent class (the
  rule is stated in the leaf) or TContestBase (it is stated somewhere above
  the base, a family base included). Lifted from uTestContestDisplay's
  Test_EveryClassStatesItsIdentity, which was the first to ask it.

  THE CALLER SUPPLIES THE GETTER, because the getters are PROTECTED: only a
  unit that declares its own descendant of TContestBase (a "cracker" class)
  can name one. So a test declares `TFooCracker = class(TContestBase)` and a
  one-line function returning `TMethod(TFooCracker(aObj).GetFoo).Code`, and
  hands that function here. *)
unit uTestRegisteredContests;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC, uContestBase, uContestRegistry;

type
   (* The code behind one virtual method of aObj -- see the header. *)
   TContestMethodCode = function(aObj: TContestBase): CodePointer;

(* THE REGISTERED CONTESTS, for an invariant to walk -- uContestRegistry's
  RegisteredContests, the shared identity objects (never free one).

  RAISES when fewer than a hundred are registered: a walk over an emptied
  registry passes every assertion in it, and a guard that reports "0 found"
  and passes is not a guard. The floor is far below the real number, so no
  contest added or removed ever edits it. *)
function ContestsToWalk: TContestIdentityList;

(* The same, with "no contest" (NoContest, the plain TContestBase the
  registry answers for it) FIRST -- for an invariant about every identity the
  program can answer with, such as "no ADIF id is claimed twice". *)
function IdentitiesToWalk: TContestIdentityList;

(* EVERY REGISTERED STATE QSO PARTY -- each contest in ContestsToWalk whose
  class descends from TContestStateQSOPartyBase, legacy and by-id alike, in
  registry order (issue #135: a party walk over the frozen enum never saw
  Georgia, North Dakota, Oklahoma, New Mexico, Ontario or Quebec).

  RAISES when it finds none, for ContestsToWalk's reason. A test that walks
  it may also guard, with WalkIncludes, that a named by-id party is in it --
  a fixed guard against a walk gone back to the enum, never a list every
  new party must join. *)
function StatePartiesToWalk: TContestIdentityList;

(* IS THE CONTEST REGISTERED AS aId IN aContests? -- the pin a walk states so
  that it cannot go quietly empty of the contests it exists to reach. *)
function WalkIncludes(const aContests: TContestIdentityList; const aId: string): boolean;

(* A NEW object of aIdentity's class, for the same contest, holding aStation.
  The caller frees it. For a test that needs a station or must not touch the
  shared identity object. *)
function NewContestLike(aIdentity: TContestBase;
                        const aStation: TStationContext): TContestBase;

(* WHICH CONTEST aObj IS, as the registry's handle. TContestBase keeps
  Contest protected on purpose, so that no class branches on it; a test
  reads it through a descendant declared here (Q108 S2). *)
function HandleOf(aObj: TContestBase): TContestHandle;

(* THERE IS NO ContestOf ANY MORE -- issue #96, 2026-10-26.

  It answered the legacy member of aObj, and DUMMYCONTEST for a contest
  registered by its id (Q108 S3). Inside a registry walk that silently turned
  a by-id contest into "no contest": a station built for it, an identity
  asked about it, a name printed for it were all DUMMYCONTEST's, and the
  walk passed because nothing it asked happened to differ. So the walk now
  keeps the OBJECT (or HandleOf it), and reaches the frozen enum only through
  the two questions below, each of which answers a by-id contest truthfully.
  Lint-RegistryWalks fails the build if ContestOf, or the same thing spelled
  LegacyContestOf(HandleOf(...)), comes back in a test. *)

(* IS aObj THE LEGACY CONTEST aMember? -- a handle comparison. A contest
  registered by its id is no legacy contest, so it answers False for every
  member; "no contest" (NoContest) is DUMMYCONTEST. *)
function IsLegacyContest(aObj: TContestBase; aMember: ContestType): boolean;

(* aObj's LEGACY MEMBER, for a pin keyed by the frozen enum: True with it for
  a legacy contest; FALSE (aMember DUMMYCONTEST) for a contest registered by
  its id, which no pin names -- so the caller must say what such a contest is
  held to, instead of asking about "no contest" without knowing it. *)
function TryLegacyContestOf(aObj: TContestBase; out aMember: ContestType): boolean;

(* "<contest> (<class>)" -- the name a failure message gives a contest. The
  one place that spells a contest for a message: its id, since Q108 S2. *)
function ContestWho(aObj: TContestBase): string;

(* DOES aObj's OWN CLASS STATE THE METHOD -- is the code behind it not the
  code its PARENT class runs? A rule stated on a family base answers False
  for each member. *)
function ClassStatesItself(aObj: TContestBase; aCodeOf: TContestMethodCode): boolean;

(* DOES ANYTHING ABOVE TContestBase STATE THE METHOD for aObj -- its class or
  a family base? False exactly when aObj runs TContestBase's own code. *)
function ClassOverridesTheBase(aObj: TContestBase; aCodeOf: TContestMethodCode): boolean;

implementation

uses
   SysUtils, uContestStateQSOPartyBase;

type
   (* Reaches the protected Contest property -- see HandleOf. *)
   TContestKeyReader = class(TContestBase);

const
   (* The floor ContestsToWalk enforces -- see its declaration. *)
   FEWEST_REGISTERED_CONTESTS = 100;

function ContestsToWalk: TContestIdentityList;
begin
   Result := RegisteredContests;
   if Length(Result) < FEWEST_REGISTERED_CONTESTS then
      begin
      raise Exception.CreateFmt(
         'only %d contests are registered (at least %d expected) -- is the ' +
         'factory linked into the test program?',
         [Length(Result), FEWEST_REGISTERED_CONTESTS]);
      end;
end;

function IdentitiesToWalk: TContestIdentityList;
var
   contests: TContestIdentityList;
   k: integer;
begin
   contests := ContestsToWalk;
   Result := nil;
   SetLength(Result, Length(contests) + 1);
   Result[0] := ContestIdentity(NoContest);
   for k := 0 to High(contests) do
      begin
      Result[k + 1] := contests[k];
      end;
end;

function StatePartiesToWalk: TContestIdentityList;
var
   contests: TContestIdentityList;
   k: integer;
   n: integer;
begin
   contests := ContestsToWalk;
   Result := nil;
   SetLength(Result, Length(contests));
   n := 0;
   for k := 0 to High(contests) do
      begin
      if contests[k] is TContestStateQSOPartyBase then
         begin
         Result[n] := contests[k];
         inc(n);
         end;
      end;
   SetLength(Result, n);
   if n = 0 then
      begin
      raise Exception.Create('no registered contest is a state QSO party -- ' +
                             'is the factory linked into the test program?');
      end;
end;

function WalkIncludes(const aContests: TContestIdentityList; const aId: string): boolean;
var
   k: integer;
begin
   Result := False;
   for k := 0 to High(aContests) do
      begin
      if ContestId(HandleOf(aContests[k])) = aId then
         begin
         Result := True;
         end;
      end;
end;

function HandleOf(aObj: TContestBase): TContestHandle;
begin
   Result := TContestKeyReader(aObj).Contest;
end;

function IsLegacyContest(aObj: TContestBase; aMember: ContestType): boolean;
begin
   Result := HandleOf(aObj) = ContestHandleOf(aMember);
end;

function TryLegacyContestOf(aObj: TContestBase; out aMember: ContestType): boolean;
var
   n: integer;
begin
   Result := ContestLegacyNumber(HandleOf(aObj), n);
   if Result then
      begin
      aMember := ContestType(n);
      end
   else
      begin
      aMember := DUMMYCONTEST;
      end;
end;

function NewContestLike(aIdentity: TContestBase;
                        const aStation: TStationContext): TContestBase;
begin
   Result := TContestClass(aIdentity.ClassType).Create(HandleOf(aIdentity));
   Result.SetStation(aStation);
end;

function ContestWho(aObj: TContestBase): string;
begin
   Result := ContestId(HandleOf(aObj)) + ' (' + aObj.ClassName + ')';
end;

function ClassStatesItself(aObj: TContestBase; aCodeOf: TContestMethodCode): boolean;
var
   parent: TContestBase;
begin
   parent := TContestClass(aObj.ClassParent).Create(HandleOf(aObj));
   try
      Result := aCodeOf(aObj) <> aCodeOf(parent);
   finally
      parent.Free;
      end;
end;

function ClassOverridesTheBase(aObj: TContestBase; aCodeOf: TContestMethodCode): boolean;
var
   base: TContestBase;
begin
   base := TContestBase.Create(HandleOf(aObj));
   try
      Result := aCodeOf(aObj) <> aCodeOf(base);
   finally
      base.Free;
      end;
end;

end.
