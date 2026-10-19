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
  log-compare packet keep meaning exactly what they meant.

  A CONTEST WITH NO LEGACY NUMBER REGISTERS BY ITS ID (Q108 S3, 2026-10-17):
  RegisterContestById. It has no ContestType member -- that enum is FROZEN
  (Lint-FrozenContestNumbers) -- and its handle is assigned when the registry
  SEALS, from Ord(High(ContestType)) + 1 up, in id order (CompareText), so the
  same set of linked contests gives the same handles in every program. S4
  (2026-10-17) keeps such a handle off the V1 multi-op wire --
  ContestCanUseMultiOp, below, is the one question every door asks -- and
  gives it a derived <contestnr>, so a real contest MAY register this way.
  The unit-test program's fixture is the one that does today.

  THE SEAL. The first question that could depend on WHICH contests exist --
  an id, a class, an identity, the known list -- seals the registry. After
  that every registration RAISES, legacy or by id, so a unit that registers
  too late (or one that asks too early, from its initialization section)
  fails the program on launch instead of silently missing a contest. Only
  the legacy-number arithmetic (ContestHandleOf, ContestLegacyNumber,
  LegacyContestOf, ContestCanUseMultiOp) never seals: its answer does not
  depend on what is registered. (ContestBroadcastNumber seals only for a
  contest registered by id, whose number is derived from its id -- and such a
  handle exists only after the seal.)

  A CONTEST'S ID IS HELD HERE. For a legacy contest it IS its ContestTypeSA
  spelling -- the name every SQLite log's contest row and every .cfg stores
  -- so ContestId reads that table; nothing outside this unit should index
  ContestTypeSA by a handle. FindContestById is the reverse lookup, and
  uContestNames.TryContestFromName (the ONE resolver of a contest name) asks
  it.

  A DUPLICATE REGISTRATION IS REFUSED, and so is a registration after the
  seal -- the radio registry learned that the hard way, where a duplicate
  display name made a model invisible in the list rather than raising
  anything.

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

(* Registers aCls as the class serving the contest whose ID -- its stored
  name, what a log's contest row and a .cfg's CONTEST = line hold -- is aId.
  For a contest with NO legacy number (Q108 S3). Its handle is assigned at
  the seal (see the unit header).

  RAISES when ContestIdRefusal refuses aId, on a nil class, past the
  255-handle cap, and after the seal. *)
procedure RegisterContestById(const aId: string; aCls: TContestClass);

(* WHY aId CANNOT BE A NEW CONTEST'S ID, or '' when it can. Refused: an
  empty id; one with leading or trailing blanks (a name is trimmed when it is
  read back, so it could never be found); a character outside printable
  ASCII (it goes into a .cfg line and the matrix's file names); a legacy
  contest's ContestTypeSA spelling; a legacy alias in
  uContestNames.LEGACY_CONTEST_NAMES (an id once written to a file is never
  given to another contest -- Q105); and an id already registered by id.
  Every comparison ignores case, as the name resolver does. *)
function ContestIdRefusal(const aId: string): string;

(* THE FIRST HANDLE A CONTEST REGISTERED BY ID CAN HAVE -- one above the last
  legacy number. *)
function FirstByIdContestHandle: TContestHandle;

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
  8.2u, exit 5). A LEGACY CONTEST'S IS ITS LEGACY NUMBER -- what
  Ord(ceContest) wrote before S2, so the broadcast is byte-identical (pinned in
  uTestUDPDatagrams and uTestContestFactory). A CONTEST WITH NONE (Q108 S4,
  2026-10-17) GETS A DERIVED NUMBER:

      256 + CRC32(its id, UTF-8) mod (2^31 - 256)

  so it is never a byte value (no clash with a legacy number), fits a signed
  32-bit integer whatever a listener parses it into, and is the same on every
  machine and in every build that links the same id -- it depends on the id
  and on NOTHING that is assigned at the seal.

  WHAT N1MM SAYS <contestnr> IS (its "External UDP Broadcasts" appendix,
  read 2026-10-17): "a unique number assigned to this contest instance in this
  database. Do not expect the same contestnr to be assigned to another computer
  running the same contest name." It is a LOCAL log identifier, not a shared
  contest code, and no range is stated. So any stable per-contest number
  serves; ONE per contest is what the derivation guarantees up to a CRC32
  collision, and uTestContestById asserts no two registered contests share one.

  logsubs2 asks only this. *)
function ContestBroadcastNumber(aHandle: TContestHandle): integer;

(* MAY THIS CONTEST TRAVEL THE V1 MULTI-OP PACKET? -- Q108 S4, 2026-10-17.
  THE ONE QUESTION EVERY DOOR ASKS (uNet: connect, switch, a peer's CONTEST
  command, the send and the receive of a QSO packet; design 8.2u).

  ContestExchange.ceContest and TLogFileInformation.liContest are ONE BYTE that
  only a legacy contest has (its legacy number), and a D7 peer, the server's
  log and the log-compare packet read it as that number. A contest registered
  by id has none, so it must never reach the wire -- and the packet itself is
  NOT being converted (NY4I, P14): this is a guard, not a format change. It
  lasts until the row-based multi-station protocol replaces the packet.

  True for every legacy contest and for NoContest (a station with no contest
  chosen is not carrying one). Never seals. *)
function ContestCanUseMultiOp(aHandle: TContestHandle): boolean;

(* THE ONE MESSAGE an operator reads when a door refuses (SContestNotOnMultiOp,
  translatable), naming the contest by its display name. '' when the contest
  CAN use multi-op, so a caller can use the text as the question. *)
function MultiOpRefusalText(aHandle: TContestHandle): string;

(* THE CONTEST'S ID -- its stored name. For a legacy contest, its
  ContestTypeSA spelling; for one registered by id, that id; '' for a handle
  that names no contest. *)
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
  matrix's list, the New Contest choices). Every legacy number in order --
  the order the enum walks it replaced visited -- then every contest
  registered by id, in handle order, which is id order. *)
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
   uContestNames,      (* LEGACY_CONTEST_NAMES -- an alias is never a new id *)
   uCRC32,             (* ContestBroadcastNumber -- a by-id contest's number *)
   uAppStrings,        (* SContestNotOnMultiOp *)
   uContestStateQSOPartyBase;

type
   (* ONE REGISTRATION BY ID, HELD UNTIL THE SEAL gives it a handle. *)
   TByIdRegistration = class
   public
      Id: string;
      Cls: TContestClass;
   end;

var
   (* Indexed by the handle's byte: 256 slots, one per possible handle. *)
   GRegistry: array[Byte] of TContestClass;

   (* The id of each contest registered by id, at its handle; '' elsewhere.
      A legacy contest's id is ContestTypeSA's, read there. *)
   GById: array[Byte] of string;

   (* The registrations by id, in the order they arrived, until the seal. *)
   GPending: array of TByIdRegistration;
   GSealed: boolean;

   (* ContestIdentity's instances, one per handle asked about, built on first
      ask, and the lock that serialises building them -- and the seal. *)
   GIdentity: array[Byte] of TContestBase;
   GIdentityLock: TCriticalSection;

function FirstByIdContestHandle: TContestHandle;
begin
   Result := TContestHandle.FromByte(Ord(High(ContestType)) + 1);
end;

(* SEAL THE REGISTRY: give every contest registered by id its handle, in id
  order, from FirstByIdContestHandle up. Runs once, under the lock, from
  EnsureSealed. A simple insertion sort: there are at most 68. *)
procedure SealRegistry;
var
   i, j, b: integer;
   t: TByIdRegistration;
begin
   for i := 1 to High(GPending) do
      begin
      t := GPending[i];
      j := i - 1;
      (* CompareText: ASCII case folding, no locale, so the order is the same
         on every machine. The casts are lossless -- ContestIdRefusal admits
         printable ASCII only. *)
      while (j >= 0) and
            (CompareText(AnsiString(GPending[j].Id), AnsiString(t.Id)) > 0) do
         begin
         GPending[j + 1] := GPending[j];
         dec(j);
         end;
      GPending[j + 1] := t;
      end;

   for i := 0 to High(GPending) do
      begin
      b := FirstByIdContestHandle.ToByte + i;
      GRegistry[b] := GPending[i].Cls;
      GById[b] := GPending[i].Id;
      GPending[i].Free;
      end;
   GPending := nil;
   GSealed := True;
end;

(* THE FIRST LOOKUP SEALS. Double-checked: after the seal this is one read of
  a boolean, so a per-QSO question pays nothing. GSealed is written last,
  after every table it guards, and under the lock. *)
procedure EnsureSealed;
begin
   if GSealed then
      begin
      Exit;
      end;
   GIdentityLock.Acquire;
   try
      if not GSealed then
         begin
         SealRegistry;
         end;
   finally
      GIdentityLock.Release;
      end;
end;

(* A registration after the seal -- one message for both kinds. *)
procedure RefuseIfSealed(const aWhat: string; aCls: TContestClass);
begin
   if GSealed then
      begin
      raise Exception.CreateFmt(
         '%s registered for %s after the contest registry was sealed -- ' +
         'something already asked which contests exist. Register from the ' +
         'unit''s initialization section, and ask nothing of the registry ' +
         'from one.',
         [aCls.ClassName, aWhat]);
      end;
end;

function ContestIdRefusal(const aId: string): string;
var
   i: integer;
   c: ContestType;
begin
   Result := '';
   if aId = '' then
      begin
      Result := 'an empty id names no contest';
      Exit;
      end;
   if Trim(aId) <> aId then
      begin
      Result := 'an id with leading or trailing blanks could never be found -- ' +
                'a name is trimmed when it is read back';
      Exit;
      end;
   for i := 1 to Length(aId) do
      begin
      if (Ord(aId[i]) < 32) or (Ord(aId[i]) > 126) then
         begin
         Result := 'an id is printable ASCII -- it goes into a .cfg line, a ' +
                   'log''s contest row and a file name';
         Exit;
         end;
      end;
   for c := Low(ContestType) to High(ContestType) do
      begin
      if UnicodeSameText(string(ContestTypeSA[c]), aId) then
         begin
         Result := 'it is the stored name of a legacy contest, and a stored ' +
                   'name is never given to another contest (Q105)';
         Exit;
         end;
      end;
   for i := Low(LEGACY_CONTEST_NAMES) to High(LEGACY_CONTEST_NAMES) do
      begin
      if UnicodeSameText(LEGACY_CONTEST_NAMES[i].Name, aId) then
         begin
         Result := 'it is a legacy alias of ' + LEGACY_CONTEST_NAMES[i].Id +
                   ', and a stored name is never given to another contest (Q105)';
         Exit;
         end;
      end;
   for i := 0 to High(GPending) do
      begin
      if UnicodeSameText(GPending[i].Id, aId) then
         begin
         Result := 'another class has already registered it';
         Exit;
         end;
      end;
   for i := 0 to 255 do
      begin
      if UnicodeSameText(GById[i], aId) then
         begin
         Result := 'another class has already registered it';
         Exit;
         end;
      end;
end;

procedure RegisterContestById(const aId: string; aCls: TContestClass);
var
   refusal: string;
   r: TByIdRegistration;
begin
   if aCls = nil then
      begin
      raise Exception.CreateFmt('RegisterContestById(''%s'') was given a nil class.', [aId]);
      end;

   refusal := ContestIdRefusal(aId);
   if refusal <> '' then
      begin
      raise Exception.CreateFmt('%s cannot register as ''%s'': %s.',
                                [aCls.ClassName, aId, refusal]);
      end;

   RefuseIfSealed('''' + aId + '''', aCls);

   (* THE CAP: one byte of handle, so 256 handles, the legacy ones first.
      Design 8.2u: it lasts as long as ContestExchange is both the in-memory
      QSO and the wire record. *)
   if FirstByIdContestHandle.ToByte + Length(GPending) > 255 then
      begin
      raise Exception.CreateFmt(
         '%s cannot register as ''%s'': every one-byte contest handle is taken ' +
         '(the cap is 256, NoContest included -- design 8.2u).',
         [aCls.ClassName, aId]);
      end;

   r := TByIdRegistration.Create;
   r.Id := aId;
   r.Cls := aCls;
   SetLength(GPending, Length(GPending) + 1);
   GPending[High(GPending)] := r;
end;

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
const
   (* The derived numbers start here, above every byte value, and span the
      rest of a signed 32-bit integer. *)
   DERIVED_FLOOR = 256;
var
   n: integer;
   crc: longword;
begin
   if ContestLegacyNumber(aHandle, n) then
      begin
      Result := n;
      Exit;
      end;

   (* A contest registered by id: the CRC of its id. The id is printable ASCII
      (ContestIdRefusal), so the UTF-8 bytes ARE the characters. A handle that
      names no contest has the empty id and the number of an empty CRC (0); it
      is not a contest anybody can log under. *)
   crc := GetCRC32(TEncoding.UTF8.GetBytes(ContestId(aHandle)));
   Result := DERIVED_FLOOR +
             Integer(Int64(crc) mod (Int64(High(Integer)) - DERIVED_FLOOR + 1));
end;

function ContestCanUseMultiOp(aHandle: TContestHandle): boolean;
var
   n: integer;
begin
   Result := ContestLegacyNumber(aHandle, n);
end;

function MultiOpRefusalText(aHandle: TContestHandle): string;
begin
   Result := '';
   if not ContestCanUseMultiOp(aHandle) then
      begin
      Result := Format(SContestNotOnMultiOp, [ContestIdentity(aHandle).DisplayName]);
      end;
end;

function ContestId(aHandle: TContestHandle): string;
var
   n: integer;
begin
   EnsureSealed;
   if ContestLegacyNumber(aHandle, n) then
      begin
      Result := string(ContestTypeSA[ContestType(n)]);
      end
   else
      begin
      Result := GById[aHandle.ToByte];
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
   who: string;
begin
   h := ContestHandleOf(aContest);
   (* THE SPELLING, NOT ContestId -- asking the registry would seal it. *)
   who := string(ContestTypeSA[aContest]);

   if aCls = nil then
      begin
      raise Exception.CreateFmt(
         'RegisterContest(%s) was given a nil class.',
         [who]);
      end;

   if GRegistry[h.ToByte] <> nil then
      begin
      raise Exception.CreateFmt(
         'Two classes claim %s: %s is already registered and %s tried to ' +
         'register as well. One contest, one class.',
         [who, GRegistry[h.ToByte].ClassName, aCls.ClassName]);
      end;

   (* A REGISTRATION AFTER THE SEAL (Q108 S3; before it, after this contest's
      identity was asked). An identity already built would be a plain
      TContestBase answering neutrally for the contest, silently.
      Registration belongs in a unit's initialization, which runs before
      anything asks. *)
   RefuseIfSealed(who, aCls);

   GRegistry[h.ToByte] := aCls;
end;

function ContestClassFor(aContest: TContestHandle): TContestClass;
begin
   EnsureSealed;
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
   (* SEALED BEFORE THE LOCK is taken: the constructor below asks ContestId,
      which must then find the registry already sealed and take no lock. *)
   EnsureSealed;
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
   (* A program that never asked anything never sealed. *)
   for i := 0 to High(GPending) do
      begin
      GPending[i].Free;
      end;
   GPending := nil;
end;

initialization
   GIdentityLock := TCriticalSection.Create;

finalization
   FreeIdentities;
   FreeAndNil(GIdentityLock);

end.
