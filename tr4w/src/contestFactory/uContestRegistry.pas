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

(* WHICH CLASS SERVES WHICH CONTEST, AND WHAT EACH CONTEST IS CALLED -- the
  single source of truth, as uRadioRegistry is for radios.

  A contest unit registers itself from its own initialization section, so
  adding a contest touches its own unit and the two program files that list
  units, and nothing else. That property is the reason the radio factory is
  worth copying: it was verified there by adding TCI without changing a single
  shared file.

  A CONTEST IS A HANDLE HERE (VC.TContestHandle), NOT A ContestType -- Q108
  S2, 2026-10-16 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u). The handle is one
  byte, so the storage is three arrays of 256 indexed by it and a lookup is
  one index.

  THE ONE RULE THAT KEEPS EVERY PERSISTED BYTE CORRECT: A LEGACY CONTEST'S
  HANDLE IS ITS LEGACY NUMBER, Ord(member). ContestHandleOf and
  LegacyContestOf state it, and they are the only conversion between the two
  in the program. So a D7 .TRW, a D7 peer, the server's log and the
  log-compare packet keep meaning exactly what they meant. (S3 adds contests
  that register by id alone; they will get handles above the legacy range at
  the registry's seal, and S4 keeps those off the wire.)

  A CONTEST'S ID IS HELD HERE. For a legacy contest it IS its ContestTypeSA
  spelling -- the name every SQLite log's contest row and every .cfg stores
  -- so ContestId reads that table; nothing outside this unit should index
  ContestTypeSA by a handle. FindContestById is the reverse lookup, and
  uContestNames.TryContestFromName (the ONE resolver of a contest name) asks
  it.

  A DUPLICATE REGISTRATION IS REFUSED, and so is a registration after the
  contest's identity was asked for -- the radio registry learned that the
  hard way, where a duplicate display name made a model invisible in the list
  rather than raising anything.

  NOT EVERY CONTEST HAS A CLASS: DUMMYCONTEST ("no contest", NoContest) has
  none, and ContestClassFor answers nil for it. ContestIdentity still answers,
  with a plain TContestBase. *)
unit uContestRegistry;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   (* A list of contests, as handles -- KnownContests' answer. *)
   TContestHandleList = array of TContestHandle;

   (* The registered contests' identity objects -- RegisteredContests' answer.
      The list is the caller's; the OBJECTS in it are this unit's, exactly as
      ContestIdentity's are. Never free one. *)
   TContestIdentityList = array of TContestBase;

(* Registers aCls as the class serving the legacy contest aContest, at the
  handle ContestHandleOf(aContest) -- its legacy number.

  RAISES on a duplicate. A second registration for one contest is a programming
  error -- two units both claiming ARRL-DX-CW -- and the alternatives are worse:
  last-wins hides it completely, and first-wins hides it while making the
  behaviour depend on unit initialisation order, which is the .lpr's uses clause
  and not something anyone reads as an ordering. *)
procedure RegisterContest(aContest: ContestType; aCls: TContestClass);

(* THE LEGACY NUMBER RULE, BOTH WAYS -- Q108 S2.

  ContestHandleOf: the handle of a legacy contest, which is its legacy number.
  Total: every ContestType member has one.

  ContestLegacyNumber: True with the number when aHandle is a legacy contest
  (today, every handle up to Ord(High(ContestType)); after S3, not one
  assigned at the seal). False, with aNumber 0, otherwise -- a byte above the
  legacy range read from a corrupt .TRW, for one.

  LegacyContestOf: the ContestType member for aHandle, or DUMMYCONTEST when it
  has no legacy number. FOR THE RULE SITES OUTSIDE THE FACTORY THAT STILL
  COMPARE MEMBERS (logedit, postunit, MainUnit -- Lint-ContestNameTests
  ratchets them) AND THE TESTS. A contest that is not a legacy one so becomes
  "none of the members compared", which is the right answer at those sites. *)
function ContestHandleOf(aContest: ContestType): TContestHandle;
function ContestLegacyNumber(aHandle: TContestHandle;
                             out aNumber: integer): boolean;
function LegacyContestOf(aHandle: TContestHandle): ContestType;

(* THE NUMBER THE N1MM-FORMAT UDP BROADCASTS CARRY IN <contestnr> (design
  8.2u, exit 5). TODAY, THE HANDLE'S BYTE -- the legacy number for every
  legacy contest, which is what Ord(ceContest) wrote before S2, so the
  broadcast is byte-identical. Q108 S4 gives a contest with no legacy
  number a derived number here, never a byte value; logsubs2 asks only
  this, so that change has one place to land. *)
function ContestBroadcastNumber(aHandle: TContestHandle): integer;

(* THE CONTEST'S ID -- its stored name. For a legacy contest, its
  ContestTypeSA spelling; '' for a handle that names no contest. *)
function ContestId(aHandle: TContestHandle): string;

(* True when aHandle names a contest -- i.e. it has an id. NoContest does
  (DUMMYCONTEST's 'DUMMY CONTEST'); a byte above the legacy range does not. *)
function IsKnownContest(aHandle: TContestHandle): boolean;

(* WHICH CONTEST HAS THIS ID? True with aHandle set when one does; False,
  with aHandle NoContest, when none does. CASE-INSENSITIVE (UnicodeSameText)
  and NOT trimmed -- exactly the match uContestNames made over ContestTypeSA
  before S2, which is now this. NoContest's own id matches like any other. *)
function FindContestById(const aId: string;
                         out aHandle: TContestHandle): boolean;

(* EVERY CONTEST THAT HAS AN ID, NoContest INCLUDED, IN HANDLE ORDER -- the
  walk for a question about every contest the program knows by name (the
  matrix's list, the New Contest choices). Today that is every legacy number
  in order, which is the order the enum walks it replaced visited. *)
function KnownContests: TContestHandleList;

(* The class serving aContest, or nil when nothing has been registered for it.
  nil is an ORDINARY ANSWER: NoContest has no class. The ContestType overload
  is for the tests and IN7QPNE, which name legacy contests. *)
function ContestClassFor(aContest: TContestHandle): TContestClass; overload;
function ContestClassFor(aContest: ContestType): TContestClass; overload;

(* EVERY REGISTERED CONTEST, AS THE OBJECT ContestIdentity ANSWERS WITH, IN
  REGISTRY ORDER -- Q108 S1, 2026-10-16 (design 8.2u).

  THE WALK FOR A QUESTION ABOUT THE WHOLE SET OF CONTESTS. A test that asks
  "does every contest ..." walks this, not `for c := Low(ContestType)`: today
  the two visit the same contests, but a contest that registers by its string
  id (Q108 S3) will have no ContestType member, so an enum walk can never see
  it and this can. A pin table keyed by the enum is the opposite case -- a
  frozen value check over the legacy contests -- and keeps its enum walk.

  ONLY CONTESTS WITH A CLASS. NoContest -- the one classless contest -- is not
  in the list; ContestIdentity still answers for it.

  Asking builds each identity object, as ContestIdentity does, so it belongs
  after every unit's initialization -- a registration after it raises.
  Nothing in production calls it today. *)
function RegisteredContests: TContestIdentityList;

(* THE OBJECT THAT SAYS WHAT aContest IS -- its names and ids, and the rest of
  its row. NEVER nil: a contest with a class answers from its class, one
  without is answered by a plain TContestBase, whose answers are neutral (the
  contest tables it once read are deleted -- M10 S6, S8). So every
  identity question -- the Cabrillo CONTEST: name, the ADIF CONTEST_ID, the
  friendly name, the WA7BNM and QRZ.RU ids -- has one answer per contest, and
  every consumer asks it here (M1, 2026-10-01). Contest SET-UP asks it too
  (M2, 2026-10-01): FCONTEST.ApplyContestTraits writes the engine's Active*
  values and set-up flags from this object, under the operator's
  statements -- what a contest IS, which is this accessor's whole job. And
  since M4 (2026-10-01) every EXPORTER asks it how the contest formats its
  Cabrillo columns, its ADIF exchange and its ADIF contest fields. THAT
  FORMATTING NEEDS THE STATION FOR NINE CONTESTS (JIDX's STX_STRING and the
  Cabrillo columns of the rest), so a caller with a station asks the object
  ActiveContest holds, not this one (F27, 2026-10-14: PostUnit.ExchangeContest).

  A HANDLE THAT NAMES NO CONTEST (a byte above the legacy range in a corrupt
  record) is answered too, by a plain TContestBase whose id is '' -- where an
  array[ContestType] used to be indexed out of range.

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
  one.

  The ContestType overload is for the tests and IN7QPNE. *)
function ContestIdentity(aContest: TContestHandle): TContestBase; overload;
function ContestIdentity(aContest: ContestType): TContestBase; overload;

(* WHICH CONTEST ANSWERS TO THIS ADIF CONTEST_ID? True with aContest set when
  one does; False, with aContest NoContest, when none does.

  IT ASKS EVERY KNOWN CONTEST, CLASS OR NOT, THROUGH ContestIdentity -- the
  object ADIF export asks too. So the id this matches IS the id export writes,
  by construction, and a file TR4W exported resolves to the contest it came
  from (inventory D9, closed by M1). The one current-id collision is
  RSGB-ROLO, which the CW and SSB rows share: it resolves to the CW running
  here, and an ADIF record is then told apart by its MODE --
  ContestOfADIFRecordMode, below (M7b batch 2).

  THE ORDER IS THE RULE:
    1. the input is TRIMMED, and an empty result matches NOTHING. A blank id
       means "this contest has none", so it can never identify one -- matching
       it is how an import used to land on the first blank row;
    2. every contest's CURRENT id is tried first, over every known contest;
    3. only then its FORMER ids (TContestBase.FormerADIFContestIds).
  So a rename can never let an old spelling steal a name another contest uses
  today. Within each pass the lowest handle wins, which is what the old
  lookup did for the one id two rows still share (RSGB-ROLO, CW and SSB).

  COMPARISON IS EXACT after the trim, as the lookup it replaces was.

  WHY IT LIVES HERE AND NOT IN uADIF. "Which contest is this" is a question
  about the whole set of contests, and this unit is the one that knows which
  class serves each. uADIF keeps its cache and calls this. *)
function FindContestByADIFContestId(const aId: string;
                                    out aContest: TContestHandle): boolean;

(* WHICH CONTEST SHARING aContest's ADIF ID RUNS IN aMode? -- M7b batch 2,
  2026-10-02.

  For a record whose CONTEST_ID resolved to aContest, once the WHOLE record
  -- its MODE included -- has been read. The contests whose CURRENT ADIF id
  equals aContest's are asked TContestBase.RunsInMode, in handle order; the
  first that says yes is the answer. When none does, aContest stands.

  THE ONE ID THAT NEEDS IT IS RSGB-ROLO, ADIF's id for both RSGB RoPoCo
  runnings: a phone record is the SSB running's, a CW record the CW
  running's. Every other contest's id is its own and the base runs in every
  mode, so for them this answers aContest, always. DECIDED on evidence, M7b
  batch 2 (design 8.2k): before it, a phone QSO that TR4W exported for the SSB
  running imported to the CW one. *)
function ContestOfADIFRecordMode(aContest: TContestHandle;
                                 aMode: ModeType): TContestHandle;

(* MAY AN IMPORTED REPEAT OF (call, band, mode) WITH A DIFFERENT QTH BE A
  COUNTY-LINE CONTACT RATHER THAN A DUPE? -- M10 S1, 2026-10-14.

  THE ONE QUESTION the log importer (MainUnit's ADIF import, which sets
  ceClearDupeSheet on such a repeat) and the contest matrix's
  `countyline.import.allowed` line ask, so that both move together.

  IT ANSWERS THE STATE-PARTY CLASS'S CountyLineAllowed (a county-line maximum
  above zero), since M10 S7 (DECIDED 2026-10-14, design 8.2s): the class owns
  the county-line rule, and the row it replaces disagreed with it for six
  parties. Michigan STOPPED clearing the dupe flag on import (its sponsor
  allows none); Arizona, BC, Virginia, the Salmon Run and New York STARTED.
  A contest that is not a state party answers False, as its row did.

  NOT the export side. uADIF.ResolveRoverCall composes a rover's call on
  EXPORT; that is a different question (is this a QSO party where a /COUNTY
  suffix names a rover) and S7 left it on the row -- plan S7 notes, open
  question Q90. It is ContestSplitsRoverCallOnExport, below, since S8. *)
function ContestAllowsCountyLineOnImport(aContest: TContestHandle): boolean;

(* DOES ADIF EXPORT WRITE A ROVER'S CALL AS THE BARE CALL PLUS
  APP_TR4W_ROVERCALL? -- M10 S8, 2026-10-14.

  The contest's own TContestBase.SplitsRoverCallOnExport. It replaced the
  deleted row's CountyLineAllowed, which uADIF.ResolveRoverCall read; a rover
  is not a county line (plan S7), so it is deliberately NOT
  ContestAllowsCountyLineOnImport. Since NY4I's ruling on Q90 with Q94
  (2026-10-14) every QSO party answers True -- the state parties on their
  base, 7QP, NEQP and IN7QPNE on their classes -- and every other contest
  False: there the slash call is the call. *)
function ContestSplitsRoverCallOnExport(aContest: TContestHandle): boolean;

implementation

uses
   SysUtils,
   SyncObjs,
   uContestStateQSOPartyBase;

var
   (* Indexed by the handle's byte: 256 slots, one per possible handle. *)
   GRegistry: array[Byte] of TContestClass;

   (* ContestIdentity's instances, one per handle asked about, built on first
      ask, and the lock that serialises building them. *)
   GIdentity: array[Byte] of TContestBase;
   GIdentityLock: TCriticalSection;

function ContestHandleOf(aContest: ContestType): TContestHandle;
begin
   Result := TContestHandle.FromByte(Ord(aContest));
end;

function ContestLegacyNumber(aHandle: TContestHandle;
                             out aNumber: integer): boolean;
begin
   aNumber := aHandle.ToByte;
   Result := aNumber <= Ord(High(ContestType));
   if not Result then
      begin
      aNumber := 0;
      end;
end;

function LegacyContestOf(aHandle: TContestHandle): ContestType;
var
   n: integer;
begin
   if ContestLegacyNumber(aHandle, n) then
      begin
      Result := ContestType(n);
      end
   else
      begin
      Result := DUMMYCONTEST;
      end;
end;

function ContestBroadcastNumber(aHandle: TContestHandle): integer;
begin
   Result := aHandle.ToByte;
end;

function ContestId(aHandle: TContestHandle): string;
var
   n: integer;
begin
   if ContestLegacyNumber(aHandle, n) then
      begin
      Result := string(ContestTypeSA[ContestType(n)]);
      end
   else
      begin
      Result := '';
      end;
end;

function IsKnownContest(aHandle: TContestHandle): boolean;
begin
   Result := ContestId(aHandle) <> '';
end;

function KnownContests: TContestHandleList;
var
   i, n: integer;
   h: TContestHandle;
begin
   Result := nil;
   SetLength(Result, 256);
   n := 0;
   for i := 0 to 255 do
      begin
      h := TContestHandle.FromByte(i);
      if IsKnownContest(h) then
         begin
         Result[n] := h;
         inc(n);
         end;
      end;
   SetLength(Result, n);
end;

function FindContestById(const aId: string;
                         out aHandle: TContestHandle): boolean;
var
   known: TContestHandleList;
   i: integer;
begin
   Result := False;
   aHandle := NoContest;
   known := KnownContests;
   for i := 0 to High(known) do
      begin
      if UnicodeSameText(ContestId(known[i]), aId) then
         begin
         aHandle := known[i];
         Result := True;
         Exit;
         end;
      end;
end;

procedure RegisterContest(aContest: ContestType; aCls: TContestClass);
var
   h: TContestHandle;
begin
   h := ContestHandleOf(aContest);

   if aCls = nil then
      begin
      raise Exception.CreateFmt(
         'RegisterContest(%s) was given a nil class.',
         [ContestId(h)]);
      end;

   if GRegistry[h.ToByte] <> nil then
      begin
      raise Exception.CreateFmt(
         'Two classes claim %s: %s is already registered and %s tried to ' +
         'register as well. One contest, one class.',
         [ContestId(h), GRegistry[h.ToByte].ClassName, aCls.ClassName]);
      end;

   (* A REGISTRATION AFTER THE CONTEST WAS ASKED ABOUT. ContestIdentity would
      already hold a plain TContestBase for it and keep answering from the
      row, silently. Registration belongs in a unit's initialization, which
      runs before anything asks. *)
   if GIdentity[h.ToByte] <> nil then
      begin
      raise Exception.CreateFmt(
         '%s registered for %s after the contest''s identity was already ' +
         'asked for. Register from the unit''s initialization section.',
         [aCls.ClassName, ContestId(h)]);
      end;

   GRegistry[h.ToByte] := aCls;
end;

function ContestClassFor(aContest: TContestHandle): TContestClass;
begin
   Result := GRegistry[aContest.ToByte];
end;

function ContestClassFor(aContest: ContestType): TContestClass;
begin
   Result := ContestClassFor(ContestHandleOf(aContest));
end;

function RegisteredContests: TContestIdentityList;
var
   known: TContestHandleList;
   i, n: integer;
begin
   Result := nil;
   known := KnownContests;
   SetLength(Result, Length(known));
   n := 0;
   for i := 0 to High(known) do
      begin
      if GRegistry[known[i].ToByte] <> nil then
         begin
         Result[n] := ContestIdentity(known[i]);
         inc(n);
         end;
      end;
   SetLength(Result, n);
end;

function ContestIdentity(aContest: TContestHandle): TContestBase;
var
   b: Byte;
begin
   b := aContest.ToByte;
   GIdentityLock.Acquire;
   try
      if GIdentity[b] = nil then
         begin
         if GRegistry[b] <> nil then
            begin
            GIdentity[b] := GRegistry[b].Create(aContest);
            end
         else
            begin
            GIdentity[b] := TContestBase.Create(aContest);
            end;
         end;
      Result := GIdentity[b];
   finally
      GIdentityLock.Release;
      end;
end;

function ContestIdentity(aContest: ContestType): TContestBase;
begin
   Result := ContestIdentity(ContestHandleOf(aContest));
end;

function FindContestByADIFContestId(const aId: string;
                                    out aContest: TContestHandle): boolean;
var
   id: string;
   known: TContestHandleList;
   obj: TContestBase;
   former: TContestIdList;
   i, k: integer;
   haveFormer: boolean;
   formerContest: TContestHandle;
begin
   Result := False;
   aContest := NoContest;

   id := Trim(aId);
   if id = '' then
      begin
      Exit;
      end;

   (* ONE WALK, TWO ANSWERS. A current-id match ends the search at once; a
      former-id match is only remembered, because a later contest's CURRENT id
      must still beat it. *)
   haveFormer := False;
   formerContest := NoContest;
   known := KnownContests;
   for k := 0 to High(known) do
      begin
      obj := ContestIdentity(known[k]);
      if obj.ADIFContestId = id then
         begin
         aContest := known[k];
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
               formerContest := known[k];
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

function ContestAllowsCountyLineOnImport(aContest: TContestHandle): boolean;
var
   obj: TContestBase;
begin
   (* THE CLASS'S, SINCE M10 S7. Only a state QSO party has a county-line rule
      at all, so any other contest answers False -- which is what the row said
      for every contest that is not a party. *)
   obj := ContestIdentity(aContest);
   Result := (obj is TContestStateQSOPartyBase) and
             TContestStateQSOPartyBase(obj).CountyLineAllowed;
end;

function ContestSplitsRoverCallOnExport(aContest: TContestHandle): boolean;
begin
   (* ContestIdentity is never nil; NoContest's plain TContestBase answers
      the base's False. *)
   Result := ContestIdentity(aContest).SplitsRoverCallOnExport;
end;

function ContestOfADIFRecordMode(aContest: TContestHandle;
                                 aMode: ModeType): TContestHandle;
var
   id: string;
   known: TContestHandleList;
   k: integer;
   obj: TContestBase;
begin
   Result := aContest;
   id := ContestIdentity(aContest).ADIFContestId;
   if id = '' then
      begin
      Exit;
      end;

   known := KnownContests;
   for k := 0 to High(known) do
      begin
      obj := ContestIdentity(known[k]);
      if (obj.ADIFContestId = id) and
         obj.RunsInMode(aMode)    then
         begin
         Result := known[k];
         Exit;
         end;
      end;
end;

procedure FreeIdentities;
var
   i: integer;
begin
   for i := 0 to 255 do
      begin
      FreeAndNil(GIdentity[i]);
      end;
end;

initialization
   GIdentityLock := TCriticalSection.Create;

finalization
   FreeIdentities;
   FreeAndNil(GIdentityLock);

end.
