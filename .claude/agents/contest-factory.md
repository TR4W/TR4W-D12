---
name: contest-factory
description: The contest factory — uContestBase, the contest registry, and one unit per contest under src/contestFactory/. Use when adding a contest, changing a contest's rules object, or working on the migration of contest behaviour out of the TRDOS engine into a contest class.
tools: Read, Grep, Glob, Bash, Edit, Write
model: opus
---

You own `tr4w/src/contestFactory/` — the strangler-pattern replacement for
contest behaviour hard-coded in the TRDOS engine.

## Your files

`uContestBase.pas`, `uContestRegistry.pas`, `uContestFactory.pas`, plus one unit
per contest (ARRL DX CW/Phone, ARRL SS CW/SSB, CQ WPX CW/SSB, CQ WW CW/SSB,
NRAU-Baltic CW/SSB, ARRL Field Day, Winter Field Day, IARU, NA Sprint CW/RTTY,
Sprint SSB, the state QSO parties, Florida QP, GeneralQSO, ...), the family
bases beneath them, and `uContestFixedPoints` -- which since M3 holds only the
`FixedModePoints` HELPER. **`TContestFixedPoints` is gone** (retired 2026-10-01):
a fixed-points contest sits on `TContestBase` and calls the helper from its own
`CalculateQSOPoints`. The family bases are a closed list held by
`Test_EveryClassSitsOnTheBaseOrAFamily` (state parties, ARRL DX, ARRL SS, CQ WW,
CQ WPX, NRAU-Baltic); adding one means adding it there, on evidence.

**Count them with `ls tr4w/src/contestFactory` — never write the number down.**

Read **`docs/ADDING_A_CONTEST.md`** before touching this -- **Part A is the
step-by-step procedure for a new contest** (files, base, overrides, every
outside reference, tests, gates), Part B the reference -- and **B4 ("section
4") before believing a green run**.

## The thing that will burn you

**THE GOLDEN CORPUS IS BLIND TO SCORING.** It byte-diffs ADIF and Cabrillo
artifacts; a contest class that computes points wrongly can pass all 24
comparisons. `tr4w/test/corpus/test-contest-factory.sh` sees scoring over the 13
corpus logs, and **the contest matrix** (`tr4w/test/contest-matrix/run-contest-matrix.sh`,
M0, 2026-10-01) sees set-up, scoring, export, ADIF import (M5a) and typed-exchange
parsing (M5b) for **every** `ContestType` on synthetic QSOs -- and since M11 S0c
its `keys` section (19 more QSOs and 8 more exchanges, scored and parsed but NOT
logged, so export/import/totals are untouched -- each scored on a band the
contest CREDITS since Q98 S0, `CreditedMatrixQSO`, as is the host-area QSO 37,
so stating a band list never silently drops key coverage) and its `initialexchange` section
(`InitialExchangeEntry` with no file, with the matrix's OWN
`MATRIX-TRMASTER.DTA` -- never the shipped one -- with logged history, and with a
custom string). Run them, and say which ones you ran. **Never re-freeze the matrix
to clear a red run** -- `freeze-contest-matrix.sh` demands a written reason.

This is mid-flight work. The engine (`src/trdos/`) still owns most behaviour —
see `contest-scoring`, whose territory this is progressively taking over. Know
which side of that seam you are on before you change anything.

## Adding a contest — two different jobs

| job | doc |
|---|---|
| the **data** — its `.dom` files in `target/dom/` (no `.cfg` -- that folder is `.dom` only, NY4I 2026-10-15), their format and the state-party pair. **No `VC.pas` entry since Q108 S3: the `ContestType` enum is FROZEN** | `docs/ADDING_A_CONTEST.md` A1 |
| the **class** in this factory | `docs/ADDING_A_CONTEST.md` A2-A6 |

The legacy enum-model guide is archived at
`docs/migration_interim_artifacts/ADDING_A_NEW_CONTEST.md` (2026-10-23); do
not follow its checklist.

**No `.cfg` borrows another contest's type** (NY4I, 2026-10-01: *"The only
contest that should say CONTEST = NEQP is the NEQP."*). A new event is a new
CONTEST plus a class -- and **since Q108 S3 (2026-10-17) it is NOT a new
`ContestType`**: the enum is frozen (`Lint-FrozenContestNumbers` fails on any
member added -- appended included -- removed, reordered or renamed, because a
member's position is the persisted number in the `.TRW` record and the
multi-op packet). A new contest registers by its id (`RegisterContestById`),
and **a real contest may since Q108 S4** (2026-10-17, below): its `<contestnr>`
is derived, and since network protocol 2 (2026-10-27) it WORKS on the multi-op
network, announced by its id string in the HELLO. **The worked examples of a
by-id addition are the Georgia QSO Party (`uContestGeorgiaQP`, a state party)
and URC (`uContestURCDXRTTY`, anything else).** Copy Georgia's CLASS but
NOT its test, which lacks the shipped county table and the in-state
real-engine half: a new party copies the test of North Dakota (`5857a251`),
Oklahoma (`4f7e9892`), New Mexico (`f2454a67`), Ontario (`926617b3`) or
Quebec (`e751a346`) -- `ADDING_A_CONTEST.md`'s top table says which shows
what. A new contest's sponsor questions go on its GitHub issue, not
`CONTEST_FACTORY_OPEN_QUESTIONS.md`. A state party states its
`InStateDomesticFileName` as ONE literal and puts both `.dom` files in
`target/dom`; the installer ships that folder by wildcard (`full.nsi`: `File
..\target\dom\*.*`), so there is NO `full.nsi` edit -- `Lint-DomCoverage` reads
the literal and checks `<base>.dom` and `<base>_cty.dom` are on disk. Idaho and
Delaware were the last LEGACY (enum) additions. **A `.dom` line holding `=` is
an ENTRY, comments included** (`logdom.EnumDOMFILE` has no comment syntax), so
a header must not contain one. **Only `INCLUDE FILE <name>` (upper case)
includes a file**: any other line whose first word is INCLUDE is skipped --
nc.dom's `INCLUDE S50.DOM` was, from D7 until #88 round 3 (2026-10-26) -- so
the loader WARNS on one (`LogDom.DomLineIsAnUnfollowedInclude`) and
`Lint-DomCoverage` FAILS any `.dom` in `target/dom` holding one. A county file an
in-state file INCLUDEs maps each county with `KEY > Mult = ...` (Idaho's and
Delaware's), or each county becomes its own in-state multiplier -- which is
what Nebraska (`uContestNebraskaQP`, 2026-10-16, design Q105) wants: its
`nebraska_cty.dom` maps none, so an in-state entrant counts each county.
**A `ContestTypeSA` spelling is STORED DATA and is never given to another
contest** (Q105): every SQLite log's `contest` row and every `.cfg` holds it.
New England was `NEQP` and is `NEWEQP`; `NEQP` is a permanent READ alias in
`uContestNames.LEGACY_CONTEST_NAMES` (a name -> the contest's current ID
string, since Q108 S2) -- the ONE resolver of a contest name
(`TryContestFromName` over `uContestRegistry.FindContestById`, behind the
log repository's `ContestFromName` and, through
`uSettingsModel.RegisterSettingValueSpelling`, the CONTEST setting;
`TF.GetContestFromString` is deleted -- it dragged the registry into
`tr4wserver` through TF). Nebraska
is `NE-QSO-PARTY` (Cabrillo and ADIF too); New England's Cabrillo is
`NEWE-QSO-PARTY` and its ADIF id stays `NEQP`, stated in its class. A rename
adds its alias in the same commit (`ADDING_A_CONTEST.md` B5).
`docs/CONTEST_RULES_OUTSIDE_FACTORY.md` is generated from `git ls-files`, so it
cannot see a new unit until it is committed -- regenerate after the commit.

`Lint-DomCoverage.ps1` reads every party class's `GetInStateDomesticFileName`
literal (a floor, not a count to raise; fails on one it cannot read) and checks
that `<base>.dom` and `<base>_cty.dom` are in `target/dom/` -- `full.nsi`'s dom
section is a wildcard, which the lint honours. It is in `Run-Lints.ps1` since M10 S8 -- before that
nothing had run it since the FPC FullBuild rewrite (2026-08-13).
`Lint-ContestNameTests.ps1` ratchets per file every use of a `ContestType` member as
a comparison operand (any operand, not just the global `Contest`), an `in [...]`
member, or a `case` arm label — one per arm — outside this directory. A new arm in an
existing `case` now fails it. When you move a branch into a class, lower that
file's ceiling in the same commit.
`Lint-NoContestTables.ps1` (M10 S0) fails a hand-typed `array[ContestType]` table
with an initialiser anywhere in `src`, except its allow-list -- `ContestTypeSA`
alone since M10 S8 deleted the other two. An allow-listed table that is no
longer found FAILS it, so the commit that deletes a table deletes its entry.
`docs/CONTEST_RULES_OUTSIDE_FACTORY.md` lists every contest rule still outside this directory, by category, seam and contest; it is GENERATED by `python tools/contest-rules-inventory/generate.py` (judgements in its `judgements.py`; hand-written findings live between its `HAND-MAINTAINED` markers) -- regenerate it when you move a rule in.

## Standing constraint

**This is a port, and we want to do this once.** Getting the object model right
outranks refactoring convenience — the factory is a classic factory pattern with
proper inheritance, like the radio factory. Build to that standard rather than a
`case` statement.

## The model -- a contest OWNS its rules (NY4I, 2026-10-01)

Read **`docs/CONTEST_OWNERSHIP_DESIGN.md`** before moving any rule. It covers
the target shape, the M-step migration order and the open questions.

- **A contest class owns its rules outright**, through virtuals on
  `TContestBase`: scoring, exchange parsing and validation, ADIF import
  interpretation, ADIF and Cabrillo export, setup, and total score and bonuses.
- **No shared strategy objects and no registries** for point methods, exchange,
  multiplier or initial-exchange kinds. Nothing is picked from a shared set.
  `docs/QSO_POINT_METHOD_DESIGN.md` proposed exactly that and is
  **SUPERSEDED**. Do not build from it.
- **Family bases only for one family under one rule** (`TContestStateQSOPartyBase`,
  the CW/SSB pairs, NRAU-Baltic). Extending NY4I's NRAU ruling to every
  two-mode pair is his open Q7 -- so the NA Sprint CW/RTTY stay siblings (M3,
  design §8.2d). The SSB Sprint is NOT an NA Sprint (different sponsor) and
  Locust is NOT a state party (P 0, no counties); both sit on `TContestBase`.
- **A newly registered class changes the matrix's `contest.class =` line and
  NOTHING else.** At M3 five held contests gained classes: every other line of
  their records stayed byte-identical, which is the transcription proof. Diff
  the records excluding that line before believing a red run is only that;
  the identity line then needs a re-freeze WITH that reason, for those
  contests only.
- **A contest that resembles another starts as a COPY and owns it.** That is
  ownership, not drift, so never merge such copies.
- **Helpers only for genuinely shared computation**, called by the class's own
  code. `uContestARRLDigi` calling `LOGGRID.GetDistanceBetweenGrids` is the
  worked example. A helper the state parties share sits PROTECTED on
  `TContestStateQSOPartyBase` and is asked only by a class that calls it:
  `SentLocation` / `LocationOrOwnCountry` (a DX entrant sends its own country,
  not "DX"), lifted from North Dakota when Oklahoma became the second user
  (2026-10-26), pinned by `uTestContestStateQSOPartyBase` through an
  unregistered probe class. Beside it since New Mexico (2026-10-26):
  `ReportNoTableForYear(logger, year, table, rule, source)`, the
  once-per-year "no table for this year" Error a year-table rule writes
  (lifted from Idaho and Nebraska, which carried it word for word; the
  caller passes its own unit logger, so tests capture by unit name). NY4I:
  identical code is one routine -- "a contest owns its copy" covers rules
  that DIFFER, not identical lines. So the DXCC key (every CTY country but
  K, VE, KH6, KL) and its ARRL/CQ list are ONE LEAF ROUTINE since #136
  (2026-10-27): `uDXMultiplierKey.DXCCKeyExceptUSACanadaHawaiiAlaska(aCounts,
  aQso, aKey)` and `DXCCCountryMode(aCounts)`, called by ten contests --
  Delaware, Florida, Nebraska, New Mexico, Oklahoma, Texas, Ontario, the
  7QP, New England and ARCI (lifted to the party base at Ontario, then to
  the leaf so the three on `TContestBase` could reach it; the party base no
  longer holds it). The class keeps WHO counts (its own
  `CountsDXMultiplier` / `HasDXMultiplier`; Florida and ARCI pass True,
  New England only for a New England entrant). Pinned by
  `uTestDXMultiplierKey.Test_ADXCCKeyIsEveryCountryButKVEKH6KL`. Two
  leaf helpers came with New Mexico: `uCabrilloFormat.FormatCabrilloModeDigitalAsRY`
  (every digital submode RY, FM PH -- Delaware and New Mexico) and
  `uCabrilloExchange.CabrilloReceivedRSTDomesticQTHOrDX` ("DX" whenever the
  record holds no `DomesticQTH`). **`CabrilloReceivedRSTQTHDX` tests
  `QTHString`, so under `RSTDomesticOrDXQTHExchange` a DX station whose entity
  was TYPED exports an empty QTH column** (non-literal `HisQTH` is
  `DomesticQTH`); Georgia used it until 2026-10-27 and now states
  `CabrilloReceivedRSTDomesticQTHOrDX`, as do Kentucky, Iowa and South
  Carolina since review H4 (2026-11-16) -- they were the only classes left
  pairing `ParseRSTDomesticOrDXQTH` with `RSTQTHDX` (the conditional
  classes pair the OrDX parse with an OrDXQTH export). `ARRL 160` reads
  `DomesticQTH` too (issue 333): `CabrilloReceivedRSTDomesticQTHOrDXQTH`
  (domestic, else its DX QTH, else what was sent, else DX) for a W/VE
  entrant, `...DomesticQTHOrDX` for the others. North Dakota, Oklahoma,
  Ontario and Vermont use `...DomesticQTHOrDXQTH` too since the H4
  follow-up: through the real engine their typed `599 DL` exported an EMPTY
  column under `CabrilloReceivedRSTQTHOrDXQTH` (their tests hand-set
  `HisQTH` and hid it). That helper still tests `QTHString`; its remaining
  users (Alabama, Arizona in state, Delaware, Idaho, LABRE, Nebraska, New
  England, 7QP, Texas, Salmon Run, West Virginia) are unaudited. Under `RSTDomesticQTHExchange` (NC,
  Missouri, Quebec ...) a DX station is looked up in the `.dom`, so the
  record carries a `DomesticQTH` and the helper is right. **A DX entrant's
  ADIF `STX_STRING` says what was sent (2026-10-27):**
  `uADIFExchange.ADIFSentRSTStateOrDX` asks the same
  `uCabrilloExchange.SentStateOrDX` as `CabrilloSentRSTStateOrDX`, so a party
  whose DX entrant sends "DX" exports `599 DX`; a party that chooses between
  the plain and OrDX helpers by station (Arizona, Texas, New England, 7QP,
  Salmon Run, ARRL 160) mirrors the choice in its ADIF statement. The parties
  whose DX entrant sends its country (ND, OK, NM, ON) are unchanged.
- **`QSO POINT METHOD` IS RETIRED (M10 S2, 2026-10-14)**, with `EXCHANGE
  RECEIVED`, `INITIAL EXCHANGE` and the four multiplier commands -- names in
  `uCFG.RETIRED_COMMANDS`, no effect. The class decides all seven. The four
  `QSO POINTS ...` overrides stay and run before the class.
- **THE POINT METHOD IS GONE AS A CONCEPT (M10 S4, 2026-10-14).**
  `QSOPointMethodType`, the row's `QP` column, `TContestBase.QSOPointMethod`
  / `GetQSOPointMethod` (and every class's override) and `ActiveQSOPointMethod`
  are deleted. A class scores in `CalculateQSOPoints` and states nothing
  else about points. Do not reintroduce a point-method trait.
- **M10 IS COMPLETE (2026-10-14, plan S9f; "M10 COMPLETE" at the top of
  `docs/CONTEST_FACTORY_M10_PLAN.md`).** The six `Active*` KIND globals are
  gone: the session's kinds are read-only properties of
  `uContestSession.ContestSession` (`Exchange`, `InitialExchange`;
  `PrefixMult` was deleted at M11 S3, `DXMult` at M11 S4, `ZoneMult` at
  M11 S5 and `DomesticMult` at M11 S6 -- NO MULTIPLIER KIND IS LEFT),
  written only by
  FCONTEST's set-up through `Write*`. They are SESSION facts -- 27 contests
  run a kind their trait does not state -- so never answer one from
  `ContestIdentity`. **M11 is next:** the six kind enums and their ~80 engine
  arms, all reading `ContestSession`, move into the classes, and the kind
  traits and enums are then deleted.
- **M11 RUNS AS `docs/CONTEST_FACTORY_M11_PLAN.md` (S0-S10); S0a, S0b, S0d
  DONE 2026-10-14.** Three durable facts from S0:
  - **`uTestContestKindPin` freezes the kinds every contest RUNS** (six; four since M11 S3 and S4 removed the prefix and DX columns) (trait,
    then `DescribeSession`, as FCONTEST resolves them) at every matrix
    station, generated once and proved equal to all 580 frozen matrix
    records first. Same rule as `uTestContestIdentityPin`: NEVER regenerate
    it to clear a failure; a failure is a kind that changed. A stage that
    deletes a kind's enum deletes that column; a new contest adds its row by
    hand. Only the matrix's stations are pinned -- JA, OK, UA, YB and the
    rest of the plan's roster are not.
  - **The inventory's reach includes `DescribeSession`**
    (`scan.describe_session_statements`, fail-closed), and the exchange-SHAPE
    machines' arms are class SHAPE (`judgements.SHAPE_MACHINES`), counted,
    never tabled. `tools/contest-factory-m11/kind-reach.py --inventory` is
    the cross-check: every record must reclassify to its own class.
  - **Headless runs are blind in two ways the matrix cannot report:** no
    TRMASTER (`CD.MasterFileExists` is set at `uProgramMain` after the
    `/MATRIX` and `/EXPORT` halts, plan F17). (F18, the `IntitialExLoaded`
    latch that kept every `LoadinLog` after the first from feeding the
    initial-exchange history, is deleted -- issue 267.)
    And `Doing*` is derived ONCE at start-up while a peer's run-time
    `CONTEST` re-runs `FoundContest` -- measured to diverge (F9).
- **Q108 S1 IS BUILT (2026-10-16, design 8.2u): A CROSS-CONTEST INVARIANT
  WALKS THE REGISTRY, A PIN WALKS THE ENUM, AND NO TEST KEEPS A COUNT.**
  `uContestRegistry.RegisteredContests` answers the registered contests'
  identity objects in registry order (unused by production); tests walk it
  through `uTestRegisteredContests.ContestsToWalk` (raises below 100 --
  an emptied registry cannot pass) or `IdentitiesToWalk` (with "no
  contest"). `HandleOf` reads an object's handle (the property is
  protected on purpose); **`ContestOf` IS DELETED (issue #96, 2026-10-26)**
  -- it gave a by-id contest's walk "no contest" -- so a walk reaches the
  enum only through `IsLegacyContest(obj, MEMBER)` / `TryLegacyContestOf`,
  and `Lint-RegistryWalks` fails `ContestOf` or
  `LegacyContestOf(HandleOf(...))` in a test. `ContestWho` names it in a message, and
  `ClassStatesItself` / `ClassOverridesTheBase` ask whether a class states a
  virtual (the identity test's `GetterCode` technique, lifted, not copied).
  `uTestContestStatesItsRules` holds every registered contest to stating its
  Cabrillo columns, STX_STRING, parse format, received fields, `GetFlags`
  and `CalculateQSOPoints` -- no exception was needed.
  `Test_EveryDomesticFileAContestCanLoadExists` checks every `.dom` any
  contest can load (and every `INCLUDE`) is in `target/dom`. The 35
  hand-kept counts (`HAS_DX_COUNT`, `HAS_PREFIX_COUNT`, the zone totals, the
  domestic `COUNTS`, `uTestExchangeRules`' `COUNTS`/`COUNT_ANYWHERE`, "24
  parties split", "188 members", ...) are deleted or became the per-contest
  assertion they stood for; **never add one back**. A new invariant walks
  `ContestsToWalk`; a frozen pin over the legacy contests keeps its enum
  walk. Since S3 a new contest has no member, so it adds NO pin row and joins
  no enum-keyed set; the walks hold it. The measuring scripts are
  `tools/contest-factory-q108/`.
- **Q108 S2 IS BUILT (2026-10-16, design 8.2u): A CONTEST IS A ONE-BYTE
  HANDLE IN MEMORY, AND A LEGACY CONTEST'S HANDLE IS ITS LEGACY NUMBER.**
  `VC.TContestHandle` (packed record, `=`/`<>`, so a band, a mode or a
  number is refused where a contest goes) and `NoContest` (handle 0) are
  what the global `Contest`, `ceContest` and `liContest` hold; the record
  is still 376 bytes with the byte at 265 (pinned). The registry is the
  ONLY converter: `ContestHandleOf(member)`, `LegacyContestOf(h)`,
  `ContestLegacyNumber`, `ContestId(h)` (the stored name -- never index
  `ContestTypeSA` by a handle), `FindContestById`, `KnownContests`,
  `ContestBroadcastNumber` (`<contestnr>`). `TContestBase.Create(aHandle)`
  (a test: `Create(ContestHandleOf(X))`); `ContestIdentity`,
  `ContestClassFor` and `ActiveContest` keep a `ContestType` overload for
  the tests and IN7QPNE. A rule site outside the factory compares
  `LegacyContestOf(Contest) = MEMBER` (the lint still counts it). The
  CONTEST vocabulary is a lazy provider (`RegisterSettingAllowedValuesProvider`)
  because contest units register AFTER uCFG initialises; the CONTEST token
  resolves through `TryContestFromName`, never by position. A `.TRW` naming
  a number above the legacy range is refused. `Test_AContestHandleIsItsLegacyNumber`.
- **Q108 S3 IS BUILT (2026-10-17, design 8.2u): A CONTEST CAN REGISTER BY ITS
  ID, THE ENUM IS FROZEN, AND THE REGISTRY SEALS.**
  `RegisterContestById(id, cls)` (`ContestIdRefusal`: empty, blank-padded,
  non-ASCII, a legacy spelling, a legacy alias, a duplicate). THE SEAL: the
  first question that depends on which contests exist (an id, a class, an
  identity, `KnownContests`) assigns every by-id contest a handle from
  `FirstByIdContestHandle` (188) up in `CompareText` id order, and EVERY later
  registration -- legacy too -- raises; only the legacy-number arithmetic
  never seals. Such a contest has no legacy number (`LegacyContestOf` =
  DUMMYCONTEST); the `.TRW` import refuses its byte (`ContestLegacyNumber`,
  not `IsKnownContest`). ~~NO REAL CONTEST MAY REGISTER BY ID UNTIL S4~~ --
  **S4 IS IN (below)**. The FIRST REAL by-id contest is `URC-DX-RTTY`
  (`uContestURCDXRTTY`, 2026-10-22; Cabrillo URCDX, `urc.dom` generated by
  `tools/urc/make_urc_dom.py`). The unit tests' fixture,
  `test/unit/uContestTestFixture` (`TR4W-TEST-FIXTURE`), is the other one,
  pinned by `uTestContestById`; it is NEVER in `tr4w.lpr`. **The rules
  inventory (`tools/contest-rules-inventory/model.py`) still refuses a by-id
  contest -- S5 extends it, and it is owed now that URC exists.**
  `Lint-FrozenContestNumbers` (SHA-256 of the ordered member list) and
  `Lint-ContestUnitsLinked` (a factory contest unit in BOTH `.lpr` files and
  not the server's; a test fixture in the test `.lpr` only) gate it. THE
  MATRIX IS KEYED BY ID: `/MATRIX <out> <id>`, `/MATRIXLIST` lists
  `record-name|id|class-unit|P|DF|host` and refuses a contest whose class
  unit is not in `src/contestFactory`; a record is `<id, blanks as _>.matrix`
  (`uContestMatrix.MatrixRecordName`, the ONE derivation), its identity
  lines `contest.requested/selected = <id> (legacy number N)`; readers take
  the id from that line, never the file name. The inventory's `model.py`
  REFUSES a by-id contest in the factory (S5 extends it). **Every "a NEW
  contest adds rows to `<PIN>`" in the bullets below describes a LEGACY
  addition**: a by-id contest adds no pin row -- the registry walks hold it.
- **Q108 S4 IS BUILT (2026-10-17, design 8.2u): A CONTEST WITH NO LEGACY
  NUMBER HAS A DERIVED `<contestnr>`; A REAL CONTEST MAY REGISTER BY ID. IT
  WAS REFUSED ON THE MULTI-OP NETWORK UNTIL NETWORK PROTOCOL 2 (2026-10-27),
  AND IS NOT NOW.** (Verified 2026-11-13 against `uContestRegistry.pas`'s own
  header: a by-id handle "never crosses the multi-op wire as a contest";
  protocol 2 announces the contest by its ID STRING in the HELLO and the
  receiver stamps its own handle on a record it accepts.) S4's six doors --
  `ContestCanUseMultiOp`, `MultiOpRefusalText`, `SContestNotOnMultiOp`,
  `NetCarriesContest`, `PeerContestRefusal`, `Test_EveryMultiOpDoorIsWired` --
  are GONE; `uNetHello.JudgePeerContest` and `uNet.PeerRecordInOurContest`
  replaced them (see multi-op-network.md). `<contestnr>` is
  `ContestBroadcastNumber`: the legacy number, else `256 + CRC32(id) mod (2^31
  - 256)`; N1MM defines it as local to a log (no range), the fixture's is
  1862707066 and a legacy contest's did not move. `model.py` still REFUSES a
  by-id contest (S5 extends it with the first real one). A contest class never
  tests multi-op; do not add one.
- **A contest owns its bands: `TContestBase.UsesBand`** (base: every band).
  An off-band QSO is logged normally, scores 0 and earns no multiplier (NY4I,
  2026-10-01). It is asked through `ContestCreditsBand` at every place a QSO
  could affect the contest: `ScoreQSO`, **before** the overrides,
  `logdupe.SetMultFlags`, and since M8 the dupe sheet
  (`TCallsignsList.AddCallsign` / `CallsignIsDupe`) and the need-multiplier
  hint (`LogEdit`, `uContestBase.CreditedBands`). So `CalculateQSOPoints`
  never sees an off-band QSO, and a class must not repeat the band rule
  there, nor in `CountsAsMultiplier`. ~~When a contest states its bands, add it
  to the exception list in `Test_EveryOtherContestStillCreditsEveryBand`.~~
  (deleted at Q98 S1 -- see the next bullet). Design doc §7.4.
  `uTestOffBandCredit` pins the multiplier half through the real sheet, and
  since M8 the dupe half and the hint.
- **Q98 S1 IS BUILT (2026-10-22, design 8.2v): A CONTEST STATES ITS BANDS
  AND ITS MODES, AND AN OFF-BAND OR OFF-MODE QSO IS AN AUTOMATIC X-QSO**
  (NY4I: *"automatic X-QSO is OK"*). `TContestBase.UsesMode(aMode, aExtMode)`
  (base True) beside `UsesBand`; `eNoMode`/`eData` mean "some submode", so an
  old record is never proven off-mode. ONE predicate,
  `uContestBase.QSOIsXQSO(contest, qso)` = the operator's `ceXQSO` OR
  `QSOIsOffContest` (band or mode refused; or -- since #269, 2026-11-15 --
  `UsesBandInMode(band, mode, ext)` refused, the one place a band rule that
  depends on the mode is stated: Vermont credits 30/17/12 m in `UsesBand`
  and refuses all but FT8/FT4 there; base True; or -- since Q119, 2026-10-23 --
  `CreditsWorkedStation` refused, asked ONLY of an object that `HasStation`)
  -- ~~DERIVED, NEVER STORED~~ **STORED SINCE LOG SCHEMA 10 (NY4I,
  2026-11-19)**: the rule's answer is stamped on the record
  (`ceOffContest`, `qso.is_off_contest`) by `uContestRegistry.StampOffContest`
  where a QSO is logged, rescored, imported or saved from Edit QSO, and
  EVERY READER asks `uContestRegistry.StoredQSOIsXQSO` /
  `StoredQSOCountsTowardTotals` and works no rule out; a changed rule moves
  nothing until the next rescore; nothing writes `is_xqso` from the rule
  (`docs/LOG_SCHEMA.md`, log-database.md "SCHEMA 10"). What follows is the
  JUDGE, asked only at those setting points and in scoring.
  `uContestRegistry.LoggedQSOIsXQSO` judges a record by its own
  `ceContest`, through `LoggedQSOContest`: the session's object when it is
  the session's contest -- `uContestFactory` registers the provider and
  hands `GActive` as it is -- else the station-less identity, which judges
  bands and modes only). The loader and the summary sheet ask
  `LoggedQSOContest` too; never `ContestIdentity` for an X-QSO question. `QSOCountsTowardTotals(contest, qso)` asks it; so do
  `ScoreQSO` (0 points, the operator flag included), `SetMultFlags`, the
  live `LogContact` (totals, sheets, view, dupe -- the serial and the
  initial-exchange history stay OUTSIDE, Q44), the loader, the rescore's X
  arm, the Cabrillo `X-QSO:` prefix, ADIF `APP_TR4W_CLAIMEDQSO` 0, HamScore's
  line, the score-posting XML, the five grid fills, the summary sheet; the
  dupe sheet and the hint ask `ContestCreditsModeKey`. (Since schema 10 the
  loader, the rescore's X arm, Cabrillo, ADIF, HamScore/XML, the grids and
  the summary sheet read the STORED answer instead; `ScoreQSO`,
  `SetMultFlags` and live `LogContact` still judge, at the moment the stamp
  is set.) **`Lint-XQSOReads` fails a code read of `ceXQSO` or
  `ceOffContest` outside their owners, and a call of the judge routines
  outside the setting-point units.** ~~NOT the host-area rule
  (Q119 open).~~ The host-area rule IS in it since Q119 (above). **A RECORD
  RULE THAT REFUSES INPUT IS NOT AN X-QSO**: RTC's serial 0 (2026-10-23,
  NY4I: *"should have never made it past input editing (or import)"*) is
  ONE virtual, `TContestBase.LoggedQSORefusal(aQso): string` ('' accepts;
  nil-safe `ContestLoggedQSORefusal`; station-less, asked of
  `ContestIdentity`), asked by typed entry (the class's own
  `ParseReceivedExchange` after `inherited`, caret through the session's
  `MarkRefusedWord`), Edit QSO's save (shown like the bad-call refusal,
  before anything leaves) and `ImportFromADIF` (first refusal stops the WHOLE
  import, nothing written -- Q112's ruling). A missing serial (-1, ADIF
  $FFFF) is not 0. NOT asked: the binary `.TRW` import, a multi-op peer's
  QSO. A test that parses an exchange must give the record a sent serial
  (live entry sets it before the parse) -- `uTestExchangeParse.RowExchange`.
  `LoggedQSOContest`'s provider is MAIN-THREAD ONLY (audited 2026-10-23):
  IN7QPNE's answer writes its component's station. **The in-host-area
  answer is ONE value, `FCONTEST.StationInHostState`, decided by
  FoundContest from the RESOLVED MY STATE** -- so a log's own station facts
  (source 'contest') must be applied BEFORE its CONTEST:
  `uLogStore.LogStoreApplyContestConfigWith` hoists them beside MY CALL
  (2026-10-23; the corpus's michigan_qp, MY STATE = WAYN, was set up OUT of
  state and exported X-QSO: lines until then).
  `uTestHostAreaRule.Test_ALogsOwnMyStateDecidesInStateAtOpen` pins it. **THE RATCHET:** `uTestContestStatesItsRules.
  Test_EveryContestStatesItsBandsAndModes` -- `BANDS_NOT_YET_STATED` and
  `MODES_NOT_YET_STATED` (literal ids); a NEW contest, in neither, states
  both from its first commit; a stage takes its ids out in the same commit;
  `TContestStateQSOPartyBase` never states a list.
  `Test_BandsAndModesAreAnIdentityFact` holds them station-free.
  **CQ WW states its own** (S4a early, for NY4I's dry run): 160-10 m on
  `TContestCQWWBase`, CW / Phone (FM refused until Q120(a)) on the leaves,
  and CQ WW RTTY 80-10 m, RTTY only. Georgia (CW, phone, FM; no digital),
  Nebraska (every mode but FT8/FT4) and URC (RTTY only) state their own
  modes since the merge into contestFactory (2026-10-23). ARRL Sweepstakes
  states its modes on each leaf since 2026-11-18 (sponsor rule 2.4,
  `docs/ContestRules/ARRL/ARRL-SS-Rules.txt`): CW only / Phone only, FM NOT
  credited in Phone until NY4I rules; its bands are still unstated. The
  corpus's `arrl_ss_ssb_2024_w4ta` QSO 206 (N0TST, 160 m CW) became an
  X-QSO with it. **A mode rule is
  `UsesMode`, never a 0-point arm in `CalculateQSOPoints` or
  `CountsAsMultiplier`** -- those never see an off-mode QSO. **A CLASS STATES
  THE DIGITAL SUBMODES IT ALLOWS, not the ones it refuses** (NY4I, issue
  122, 2026-11-19: "the contest class should indicate the allowed modes"):
  its `UsesMode` Digital arm calls `uContestBase.DigitalSubmodeAllowed(ext,
  allowed)` (`TExtendedModeSet`, `RTTY_SUBMODES`), which also passes the
  "some submode" values -- eNoMode and the three generic data modes
  (eData, eData_R from CAT's DATA-R, eData_FM), so a submode appended later
  (JTTY was) is refused until a contest names it. Iowa (RTTY, PSK31/63,
  JS8, JTTY) names its list. **"Any digital mode that carries the exchange"
  is `EVERY_SUBMODE - FT_SUBMODES`** (NY4I, issues 88 and 122, 2026-11-19:
  "Same as other QSO parties ... specifically NOT FT8, FT4 or FT2"):
  Louisiana and New York, and the former deny-lists Illinois, Nebraska and
  Wisconsin (Missouri also takes out JT65/FST4/FST4W) -- identical answers
  plus FT2. **The phrase rule** (NY4I, 2026-11-20, on Tennessee: "That
  phrase about supporting the exchange means FT8, FT4 nor FT2 are allowed.
  That applies to all uses of that phrase"): a sponsor whose digital mode
  must "support/carry/accomplish the exchange" states that list --
  Tennessee and Arkansas since then, beside LA, NY, NJ and Texas. New
  Mexico is the exception: its rules let an FT8/FT4 QSO count when the log
  is hand-edited to the exchange, and NY4I's earlier NM ruling credits FT,
  so it was left as it is (asked on the report). **"CW and SSB" refuses
  FM** (NY4I, 2026-11-20: Ohio, the 7QP, Florida -- `uContestBase.ModeIsCWOrSSB`,
  which also refuses Phone in an `FM_SUBMODES` submode, because ADIF import
  reads MODE FM as Phone/eFM); a sponsor that says "Phone" (Salmon Run) or
  names FM (Tennessee) credits it. ARRL SS SSB and CQ WW SSB (`aMode =
  Phone`) still credit an imported Phone/eFM QSO -- not audited.
  `FT_SUBMODES` = FT8, FT4 and **FT2, appended to
  `ExtendedModeType` after JTTY (ADIF 3.1.8 MFSK/FT2)**. NOT moved, on
  purpose: Mississippi's `IsFTSubmode` and Vermont's WARC exception
  (`UsesBandInMode`) are ALLOW rules naming FT8/FT4 only, so FT2 stays
  refused there until a sponsor names it; Vermont's `VERMONT_WSJTX_MODES`
  gained FT2. JTTY is approved only where a
  sponsor's rule allows free-form digital (NY4I: Iowa and Winter Field Day).
  Winter Field Day uses it since 2026-11-19 (its 2027 rules, v3, in
  `docs/ContestRules/WinterFieldDay/`: "All modes, except WSJT modes"): RTTY,
  PSK31/63/-R, MFSK, JS8, JTTY; it states its bands (all but 30/17/12 m) and
  scores the QSO points alone -- the objective multiplier is selected on
  submission, and D7's band-mode x power formula was an earlier year's.
  `uTestAutomaticXQSO` pins it all;
  `tools/contest-factory-q98/classify_matrix.py` classifies a stage's
  matrix movement against its prediction.
- **Multipliers and dupes: the sheet keeps the state, the class declares
  the rules** (M8, 2026-10-02, design §8.2l; `ADDING_A_CONTEST.md` B2 "Bands,
  dupes and multipliers"). `CountsAsMultiplier(aQso, aKind)`
  (base True) is asked by `SetMultFlags` before the sheet; the BC, NY and
  Indiana parties, the PCC and the Jock White Field Day override it.
  `DomesticMultiplierFromCall(aCall, aLookups)` (base `''`) is the hint's;
  Russian DX, both RF Championships, Ural Cup, RDA and YO DX override it.
  `uTestContestMultipliers` holds both, with every other contest as a
  ratchet. ~~No dupe-key virtual~~ -- **the dupe rule IS the class's now**:
  `DupeKeyIncludesReceivedQTH` / `DupeKeyTour` (Q118, Q136) add to the key,
  and `DupeModeOf(aMode)` (2026-10-23, base: the mode itself) groups modes --
  New England answers CW for Digital. FM needs no answer: the sheet's
  `uSortedStringList.DupeSlot` already files FM under Phone (pinned by the
  Oklahoma and Ontario real-engine tests), so no class states FM -> Phone. It is asked ONLY by the dupe sheets,
  through `uCallsigns.ContestDupeSlot` (nil-safe `ContestDupeModeOf` keeps
  the keys Both/NoMode), never the multiplier sheets;
  `uTestContestNewEnglandQP`'s walk holds every other contest to identity.
  **The multiplier sheet's twin is `MultiplierModeOf(aMode)`** (issue 122,
  2026-11-18, base: the mode itself; nil-safe `ContestMultiplierModeOf`):
  the Louisiana QSO Party answers CW for Digital (rule 9.1, "CW/Digital and
  Phone contacts count as separate multipliers"). It is asked ONLY through
  `LOGDUPE.MultiplierSlotMode` (over `ContestIdentity(Contest)`), which EVERY
  write to `mo` uses (`AddQSOToSheets`' four flags and the #317 key,
  `CountWorkedMultipliers`, `TAdditionalDomesticMultiplierReplay.Feed`) and
  which `MultiplierSheetMode` reads through (SetMultFlags, the #317 test, the
  spot hint, `LOGWIND`'s `MultMode` for the remaining-multipliers window,
  `uTotal`'s per-mode cell) -- a mapping on the read side alone
  over-counts. A new write or read of the sheet goes through them. NOT
  mapped, on purpose: per-mode BREAKDOWNS that walk every slot (PostUnit's
  summary sheet, `uGetScores`, the matrix) -- they show a grouping contest's
  digital multipliers under CW. Never inherit it from `DupeModeOf` (Illinois
  groups for dupes only). `uTestMultiplierMode.GROUPS_MULTIPLIER_MODES` is
  the closed list. Mississippi (#123) did NOT need the mirror (built
  2026-11-18): `TDupesArray` has one digital slot, so no `DupeModeOf` can
  split RTTY from FT4/8, and the party base's received-QTH dupe key already
  does -- an FT QSO's QTH is a grid, an RTTY QSO's a county/state/country
  (`uTestContestMississippiQP.Test_RealEngineFourDupeModes`). Its gaps: an FT
  QSO with no QTH asks the call-only sheet, and the call window shows DUPE
  before the exchange (Q118). Its in-state "grids / 4" is the class's own
  `CombineWithMultipliers` over the prefix count -- no engine seam; the
  four-character square is the leaf `uGridShape.FourCharacterGridSquareOf`
  (lifted from South Dakota).
  A multiplier KIND's arm stays in the sheet until Q4 -- except the
  PREFIX kind's, below.
  **#88 round 3 (2026-10-26)**: the received-QTH dupe key is every state
  party's, New England's, the 7QP's and IN7QPNE's (their sponsors' rover
  rules; `uTestNYQPRover`'s walk). "The host state is no multiplier for an
  in-state entrant" is ONE predicate, `uContestBase.DomesticMultiplierIsHostState`,
  asked in each class's own `CountsAsMultiplier` (IN, MI, OH, TN, TX, VA,
  the Salmon Run; Delaware for its DE-to-DE QSOs) -- never by editing the
  shared S50.DOM, and never on the party base (FL, WI and the 7QP count
  their own state). A party test asks the REAL in-state file through
  `test/unit/uTestQSOPartyRules` (`InStateMultiplierOf`, `CountsForEntrant`,
  `RoverDupeAnswers`). Each takes a `TContestHandle` too (2026-10-26, the
  North Dakota QSO Party), as does `uTestContestObjects.Make`, so a by-id
  party reuses them; the `ContestType` forms delegate. A test that needs the
  real COUNTY file as the host-area table calls
  `uTestQSOPartyRules.LoadCountyTable('<base>_cty.dom', countiesAreMults)`
  / `FreeCountyTable` (in a finally) and hands `@CountyFileKnowsQTH` as the
  `TDomesticQTHTest`; `CountyTable` is the loaded table. Lifted 2026-10-27
  (Quebec, #128) from North Dakota, Oklahoma, New Mexico and Ontario, which
  carried it word for word but the file name -- never a unit-local copy.
- **THE PREFIX MULTIPLIER KEY IS THE CLASS'S (M11 S3 part 1, 2026-10-14).**
  `PrefixMultiplierKey(aQso, out aKey: PrefixMultiplierString): boolean`
  (base False) is stated by the 32 prefix contests; `LOGEDIT.SetPrefix`
  asks `ContestPrefixMultiplierKey(ActiveContest(Contest), ...)` once per
  QSO and its `case` on the kind is gone. **False is "leave the prefix as
  it was", True with `''` is "the key is empty"** -- the rescore runs over a
  stored record, so the two are not interchangeable. A rule that depends on
  the entrant asks `Station` exactly as its `DescribeSession` asks
  `aStation` (UBA, SAC, WAEDC, All Asian, OK DX, CQ MM, SAWW, YB DX); keep
  a station-dependent class's `PrefixMultiplierKey` asks its own
  `HasPrefixMultiplier` for that test (M11 S3 part 2, which deleted the
  kind and closed F20). Shared
  computation lives in the leaf `uPrefixMultiplierKey` (WAE call regions,
  SAC and YB districts); a one-field rule is written in the class. A NEW
  prefix contest overrides `PrefixMultiplierKey` AND `HasPrefixMultiplier`
  (base False -- there is no prefix kind to state any more), adds rows to
  `uTestPrefixMultiplierKey`'s `KEY_PINS` and adds itself to its
  `HAS_PREFIX` sets (and counts): `Test_EveryContestHasItsPinnedPrefixMultiplier`
  fails on a missing answer and on a key given where `HasPrefixMultiplier`
  is False. `LOGEDIT.DoingPrefixMults` is that answer for the active
  contest; there is no session flag for it.
- **THE DX MULTIPLIER IS THE CLASS'S (M11 S4, 2026-10-14).** Four
  virtuals, each with a nil-safe `Contest...` free function:
  `HasDXMultiplier: boolean` (base False -- part 2, which DELETED
  `DXMultType`, the `DXMultiplierType` trait, the session's `DXMult` and
  every `DescribeSession` DX statement; there is no DX kind to state),
  `DXMultiplierKey(aQso, out aKey: DXMultiplierString): boolean` (base
  False; False = "leave the DX QTH as it was", as for the prefix),
  `CountryMode: CountryModeType` (base CQ -- the North American kind was
  never ARRL) and `ListsRemainingDXCountry(aCountryID, aContinent)` (base
  True; WAE and UBA only -- the window's old filters, not the DX rule, F7).
  79 contests in 77 classes state a key (CQ WW and ARRL DX once, on their
  family bases; the SSB Sprint joined at Q16, 2026-10-16); 35 classes answer ARRL for some entrant. A rule that
  depends on the entrant asks `Station` as its `DescribeSession` asks
  `aStation`; where the key and the list both ask, ONE private predicate
  holds the test (`CountsDXMultiplier`, WAE's `CountsEuropeanCountries`,
  UBA's `CountsUBACountries`, ALRS's `CountsRDADistricts`, which
  `DescribeSession` calls too). Shared country lists are the leaf
  `uDXMultiplierKey` (K/VE; K/VE/KH6/KL; the ARRL section countries; North
  America but K/VE/KL); every-country, a continent, one excluded country and
  PACC's split are written in the class. WAE's `CombineWithMultipliers`
  asks its station (`TScoreTotals.SessionDXMult` is deleted). Where the
  entrant decides, `HasDXMultiplier` returns the SAME private predicate the
  key and the list ask (the Croatian and WAG hold the test in
  `HasDXMultiplier` and their keys ask it; PACC's is the private
  `IsDutchEntrant`, which its DX answers, received AND sent exchange columns
  ask since Q22), so the answers cannot disagree.
  A NEW DX contest overrides `HasDXMultiplier` AND `DXMultiplierKey` (and
  `CountryMode` if it counts DXCC only), adds rows to
  `uTestDXMultiplierKey`'s `KEY_PINS` (and `MODE_PINS`) and adds itself to
  its `HAS_DX` sets (and `ARRL_LIST_SOMEWHERE` if it chooses the ARRL
  list). No count moves -- they were deleted at Q108 S1.
  `Test_EveryContestHasItsPinnedDXMultiplier` fails on a missing answer and
  on a key given where `HasDXMultiplier` is False. `LOGEDIT.DoingDXMults`
  is that answer for the active contest -- live, so F21 is closed; there is
  no session flag for it.
  **THE KEY IS A GATE AND A DISPLAY VALUE, NOT THE SHEET'S KEY (measured
  2026-11-20, Florida maritime mobile).** `LOGDUPE.SetMultFlags` asks
  `mo.IsDXMult(RXData.QTH.Country, ...)` -- the CTY COUNTRY INDEX of the
  worked call -- and only requires `DXQTH <> ''`. So a DX multiplier that is
  not a CTY country (the FQP's ITU regions R1/R2/R3 for a /MM station, which
  has no country of its own) cannot be carried by `DXMultiplierKey`: setting
  `DXQTH` for it would credit ONE spurious multiplier, the call's country. The
  string-keyed sheet is the PREFIX one, which needs `HasPrefixMultiplier`
  and so changes `uTestPrefixMultiplierKey`'s frozen sets; Florida's maritime
  multiplier waits for a ruling on that seam.
- **THE ZONE MULTIPLIER IS THE CLASS'S (M11 S5, 2026-10-14).** Four
  virtuals, each with a nil-safe `Contest...` free function:
  `HasZoneMultiplier: boolean` (base False -- part 2, which DELETED
  `ZoneMultType`, the `ZoneMultiplierType` trait, the session's
  `ZoneMult` and JIDX's two `DescribeSession` zone statements; there is
  no zone kind to state), `ZoneMultiplierCount: integer` (base 0), `ZoneMultiplierZones:
  TZoneMultiplierZones` (base `zmzNotCQOrITU` -- also the answer for a
  contest that numbers its own zones) and `NumbersZonesFromZero: boolean`
  (base False; the European HFC and KVP). **`TZoneMultiplierZones` IS NOT
  `ZoneModeType`**: it is the list the multiplier counts, `ZoneMode`
  (`cfCQZoneMode`) is which zone CTY.DAT gives a call, and they disagree for
  the Croatian today (plan F5, Q95 open; CW Open was the inverse until its
  sponsor's rule took its zones away, issue 277, 2026-11-11) -- never derive
  one from the other. 19 contests in 18 units state it (CQ WW on its family
  base; JIDX for a Japanese entrant only, through `IsJapaneseEntrant`, the
  renamed `CountsDXMultiplier` its DX answers also ask). A NEW zone contest
  overrides `ZoneMultiplierCount` (and `ZoneMultiplierZones` for CQ or ITU
  zones, `NumbersZonesFromZero` if zero-based), adds rows to
  `uTestZoneMultiplier`'s `ZONE_PINS` and itself to its sets (no count
  moves since Q108 S1). It overrides
  `HasZoneMultiplier` too -- True exactly where the count is above 0, an
  invariant `Test_EveryContestHasItsPinnedZoneMultiplier` asserts for every
  registered contest at every station (a registry walk since Q108 S1).
  Where the entrant decides, it returns the SAME
  predicate the count asks (JIDX: `IsJapaneseEntrant`).
  `LOGEDIT.DoingZoneMults` is that answer for the active contest; there is
  no session flag for it.
- **THE DOMESTIC QTH'S SHAPE IS THE CLASS'S (M11 S6 part 1, first half,
  2026-10-14).** Six virtuals, each with a nil-safe `Contest...` free
  function: `DomesticMultiplierFromQTH(aText, var aMultiplier, var aQTH,
  var aFound): TDomesticQTHAnswer` (base `dqaLookUpDomesticFile`, writing
  nothing -- every domestic-FILE contest states nothing), the hint's
  `DomesticMultiplierHint(aText): string` (base: the text; and since issue
  209 `IsValidDomesticMultiplier(aText)`, whether the "Mult needs for"
  header may show it -- base non-empty, two or more characters for a grid
  contest, composed from the two grid answers; no override), and four
  yes/no answers, base False: `HasGridSquareMultiplier` (the six VHF
  contests), `HasGridFieldMultiplier` (five), `DomesticQTHReplacesDXMultiplier`
  (the eleven WYSIWYG contests at the stations that run it) and
  `DomesticQTHIsNeverAGrid` (RDA; the ALRS cup for an RDA entrant). 25
  contests state them; shared shapes (RDA district, DOK, grid square, grid
  field) are the leaf `uDomesticKey`, the IOTA reference is the RSGB IOTA's
  own. **`dqaLookUpDomesticFile` WITH A KEY IS REAL** -- the RSGB IOTA's
  valid reference falls through to the file lookup already found (plan F6,
  transcribed). **The DOK hint reads an unassigned local** when the text has
  no letter, in WAG and the DARC 10 m -- F6, transcribed on purpose; the fix
  is `Result := ''` in both, in its own commit. A new contest with such a
  shape overrides the answers and adds rows to `uTestDomesticMultiplier`
  (`KEY_PINS`, `HINT_PINS`, its sets; no count, since Q108 S1).
- **THE DOMESTIC FILE IS THE CLASS'S ANSWER TOO (M11 S6 part 1b,
  2026-10-14).** `UsesDomesticFile: boolean` (base False; nil-safe
  `ContestUsesDomesticFile`) is True for the 94 contests whose domestic QTH
  is looked up in their `.dom` -- stated ONCE on `TContestStateQSOPartyBase`
  (every state party), `TContestARRLSSBase` and `TContestNRAUBalticBase`,
  per class for 61 more, and by the station test its `DescribeSession`
  uses for ARRL DX, JIDX, OK DX, UBA, the Ukrainian DX and YU DX. A new
  domestic-file contest overrides it (or inherits it from its family) and
  joins `uTestDomesticMultiplier`'s `DOMESTIC_FILE_EVERYWHERE` or
  `PinnedUsesFile` (no count, since Q108 S1). A
  contest that answers True must state NO shape -- pinned. It CANNOT be
  derived from the domestic file name (plan 2.6).
- **"DOES IT COUNT A DOMESTIC MULTIPLIER" IS THE CLASS'S (M11 S6 part 2,
  2026-10-14), and `DomesticMultType` IS DELETED** -- the enum, the
  `DomesticMultiplierType` trait and its 178 overrides, `TSessionDefaults`'
  `DomesticMult`/`svDomesticMult`, the session's field, `DoingDomesticMults`
  and `WriteDomesticMult`, FCONTEST's two writes, the 13 `DescribeSession`
  statements and the matrix's `active.domesticmult` line. The answer is
  `HasDomesticMultiplier` (nil-safe `ContestHasDomesticMultiplier`),
  COMPOSED ONCE IN THE BASE: `UsesDomesticFile` or one of the four shape
  answers. A contest states nothing more -- unless its shape has no flag of
  its own: the RSGB IOTA (True), WAG (`MyCountry <> 'DL'`) and the DARC 10 m
  (True) override it. A new shape contest with no flag overrides it too,
  and `uTestDomesticMultiplier.Test_ADomesticMultiplierIsWhereAQTHIsRead`
  fails if it does not (True exactly where a QTH is read). Read live against
  `Station` (F23 closed): `LOGEDIT.DoingDomesticMults`, or
  `ContestHasDomesticMultiplier` on an object in hand. All four multiplier
  KINDS are gone; only `ExchangeType` and `InitialExchangeType` remain.
- **THE EXCHANGE RULES ARE THE CLASS'S (M11 S7, 2026-10-14)** -- what the
  engine decided by testing `ContestSession.Exchange` outside the four shape
  machines. `TContestBase` (base False, nil-safe `Contest...` functions):
  `StripsRoverCountyFromCall` (MainUnit's two rover routines),
  `LogsSeveralQTHsFromOneEntry` (`ReturnInSAPOpMode`; 21),
  `AcceptsBlankExchange` (`ParametersOkay`, `LOGSTUFF.ProcessExchange`;
  BWQP, General QSO, POTA), `RefusesCallFromExchangeWord` (2026-11-04;
  `ParametersOkay` asks it of the word the call-window correction would take
  as the call, before it is taken, and a True refuses the entry with the
  contest's message; only Sweepstakes overrides it, for `A99CT`) and
  `SendsStateAfterZone` (FCONTEST's zone
  messages; CQ WW RTTY). The park lookup asks the existing
  `OffersParkTools`; FISTS overrides `CombineWithMultipliers`. STATED PER
  CLASS, and where the entrant decides the shape, through the station test
  its `DescribeSession` uses (NEQP, 7QP, Arizona, the Salmon Run, Texas for
  the several-QTH rule). S9d (2026-10-15) added four more on the same
  pattern, transcribed from kind sets: `ExchangeCarriesDomesticQTH`,
  `ExchangeCarriesZone`, `ExchangeCarriesGridSquare` (the readiness check;
  the first also LOGSTUFF's improper-QTH attribution) and
  `PerQSOExchangeLeadsWithSerial` (`MainUnit.PerQSOExchString`) -- plan F28
  says why they are transcriptions. **S9e part 1 (2026-10-15) moved the last
  readers outside the initial exchange:** `WriteDefaultExchangeMessages(
  aMessages: TExchangeMessageWriters)` (protected; the base writes none) --
  the default CW exchange messages FoundContest's closing `case` chose by
  kind, now a call to one of five engine writers BY NAME
  (`WriteNameAndState`, `WriteRSTQSONumber`, `WriteRSTStateOrQSONumber`,
  `WriteRSTZone`, `WriteRSTStateOrZone`; FCONTEST's
  `TEngineExchangeMessageWriters`, the S9d technique), asked of
  `ActiveContest`, 92 overrides; `ExchangeTextMayHoldGridSquare` (base
  False, 18 overrides) -- `TREE.LooksLikeAGrid`'s first question, asked of
  the IDENTITY because no station decides it (pinned); and the log's
  Sweepstakes columns ask the field list (`uExchangeFields`). Pinned by
  `uTestExchangeKindReaders`. `SuppressZoneExchangeMessages` and
  `uGridShape.GRID_CARRYING_EXCHANGES` are deleted. **THE ROVER IS A QSO PARTY'S (Q94 with Q90, NY4I,
  2026-10-14: "yes QSO parties allow it but in any contest NY4I/7 or
  VP9/NY4I is a valid call")**: `StripsRoverCountyFromCall` and the export's
  `SplitsRoverCallOnExport` (a `TContestBase` virtual since then) are True
  for every state party ONCE on `TContestStateQSOPartyBase`, and on the 7QP,
  NEQP and IN7QPNE classes; County Hunter strips and does not split (a
  recorded decision, not the ruling); nothing else does either -- 24 strip,
  23 split, at every station. A new QSO party inherits both or states both;
  never add a strip to a contest that is not a QSO party. A new contest with a rover or a blank exchange
  overrides them and joins `uTestExchangeRules`' literal sets (its counts
  went at Q108 S1). The rover strip takes the contest the
  rescore and the ADIF record parse already hold
  (`MainUnit.LocateCallStrippingRoverCounty`); a caller with none fetches it
  only for a call with a '/'. **OUR OWN rover (issue 133, step F):**
  `TContestBase.SplitsCabrilloByActivation` (base False, Hawaii ALONE True,
  pinned over the registry by `uTestCabrilloActivation`) splits a roving
  log's Cabrillo into one file per sent place -- see file-formats.md. A new
  party whose rules ask for a log per activation overrides it.
- **`ScoreQSO` is the ONE public scoring entry point** (M3, 2026-10-01):
  non-virtual on `TContestBase` -- zero, band check, the host-area check
  (`CreditsWorkedStation`, Q107), the four `QSO POINTS ...`
  overrides (`TStationContext.PointOverrides`, filled by
  `uContestFactory.CurrentQSOPointOverrides`, applied by
  `uContestBase.ApplyQSOPointOverride` -- the same function the classless
  engine path calls), then the **protected** `CalculateQSOPoints`. Declare an
  override of it `protected`, never `public`. Tests call `ScoreQSO`. Design
  doc §7.7, §8.2d.
- **A STORED QSO IS SCORED BY ITS OWN RECORDED GRID (log schema 3, stage 3,
  2026-10-18; D1).** `ScoreQSO(aQso, aMyFacts)` lays the row's `my_grid` over
  `Station.MyGrid` for that one call and restores it in a `finally`, so a
  rule reads `Station.MyGrid` and never knows. The rescore, ADIF import and
  Edit QSO pass the row's facts; live entry calls the one-argument form. **A
  row that recorded none (`my_source` NULL) is scored by the session's, as
  before.** A captured row with no grid gets `''`, never the session's.
  - **Only the grid is overlaid.** `Station.MyState` is the SENT state, not
    `my_state`; country and call would go unknown for every imported row that
    names no MY_DXCC or STATION_CALLSIGN. Each wants its own ruling.
  - **The SENT exchange is the row's for every my-value (log schema 9,
    2026-11-17).** `aMy.MyName/MyFDClass/MyCheck/MyPrec/MyPostalCode/
    MyFOCNumber`, which the Cabrillo/ADIF sent formatters read, now come from
    the row through `MyStationExchangeOfQSO` (they were today's settings, so
    a Sweepstakes precedence changed after logging rewrote the sent line). A
    formatter keeps reading `aMy`; it never reads `Settings` itself.
    `CanonicalSentExchange` (HamScore's line) still rebuilds from today's CQ
    template -- not yet the row's.
  - **Never call `ActiveContest` inside a rule**: it runs `SetStation` and
    would wipe the overlay (the engine already avoids it, see
    `EngineIsNewMultiplierAnywhere`).
  - **A delegating contest passes `ScoringMyFacts` on** (IN/7QP/NE does).
  - **`TLoggedQSOView.MyFacts(i)`** is each QSO's own station, for a whole-log
    rule (the Nebraska rare-grid bonus). It is filled at log load and live
    entry. `NotCapturedMyFacts` means "use the session's".
  - **A whole-log bonus reads `MyFacts(i)`, NOT `Station.MyGrid`.**
    `BonusPoints` runs outside `ScoreQSO`, so no overlay is in force there and
    `Station.MyGrid` is the SESSION'S grid -- correct only for a
    never-captured row. Nebraska's rare grid bonus (Q106, built 2026-10-18,
    `RareGridBonus`) is the worked example: the row's grid when captured, the
    session's when not, nothing for a captured empty grid; a per-year list
    through `LogContestYear` with Idaho's once-per-year Error and the
    clock-reading yearly pin (`Test_NebraskaHasARareGridTableForTheCurrentYear`).
  - **With no grid, StewPerry and WWL score 1 and Tesla scores 10** (a distance
    of 0 falls in its 0..600 km band), not Q116's 0. Unchanged here; Q116's
    build settles it.
- **A QSO PARTY'S HOST-AREA RULE IS TYPED AND SCORED (Q107, NY4I
  2026-10-16).** An out-of-area entrant's QSO whose received QTH the session's
  domestic table does not know is refused when typed AND, logged any other way
  (import, peer, the Rescore menu, the matrix), scores 0 with no multiplier --
  the off-band shape. ~~but the dupe sheet is NOT asked.~~ Since Q119
  (2026-10-23) it is an automatic X-QSO (Cabrillo `X-QSO:`, CLAIMEDQSO 0, off
  the totals and the dupe sheet) wherever it is judged with the entrant --
  see Q98 S1 above. ONE predicate,
  `uContestBase.HostAreaRuleCredits(inArea, QTHString, table)`, called by the
  refusal (`aSession.IsDomesticQTH`) and by `CreditsWorkedStation` (base True;
  `Station.IsDomesticQTH`, a new `TStationContext` service) -- both are
  `LOGDUPE.DomesticTableKnowsQTH`. Stated once on `TContestStateQSOPartyBase`;
  the 7QP (`InHostState`) and NEQP (MY STATE in New England) state it
  themselves with their own in-area test; IN7QPNE asks its judging party.
  Locust (not a party), NAQP, County Hunter, BWQP: no host area, not applied.
  `SetMultFlags` exits on `ContestCreditsWorkedStation` after the band. A test
  that scores party QSOs out of state needs a table: `uTestContestObjects.
  WithHostAreaTable` (knows every QTH); `uTestHostAreaRule` pins the rule,
  the one-answer property and the rescore through `RecomputeQSOScoring`.
  THE MATRIX LOGS ONE HOST-AREA QSO FOR AN OUT-OF-AREA ENTRANT (QSO 37,
  `K9HQP`, 2026-10-16): added only when the active contest refuses to credit
  a station that sent no QTH (`ContestCreditsWorkedStation`), its QTH taken
  from the file the session's domestic table was actually loaded from
  (`SessionDomesticFileKeys`) -- nothing names a contest. Without it every
  party's out-of-area record scored 0 after Q107, and out-of-area points
  were seen by the unit tests only.
- **The domestic (.dom) table is a CLASS over a dictionary** (`TDomQTHTable`
  in `trdos/logdom.pas`, 2026-10-16): `TObjectDictionary` keyed by the
  alias, which owns its entries. The DOS linked list (`PrefixRec`,
  `NextRecord`, 36 buckets, `New`/`Dispose`) is deleted; its dispose loop
  read through nil on any reload. Lookup is EXACT (uppercased, no prefix
  match), FIRST ADDED WINS, aliases kept to ten characters, an empty alias is
  never stored. A top-level load clears the table; INCLUDE FILE adds.
  `uTestDomQTHTableReload` pins all of it.
- **The domestic COUNTRY list is a CLASS over a list too** (`TDomesticCountryList`
  in `trdos/zonecont.pas`, the global `DomesticCountries`; pointer audit P5,
  2026-10-16). The linked list (`DomesticCountryRecord`, `NextRecord`,
  `FirstDomesticCountryRecord`) is deleted. Kept exactly: insertion ORDER,
  DUPLICATES kept, ASCII upper-case on add, EXACT case-sensitive compare,
  stored as six characters, an empty ID stored (and matching an unknown
  country), and only `Clear` resets it (re-arming the once-only "list is
  EMPTY" log) -- `FoundContest` APPENDS. The matrix's `domestic.countries`
  line reads `DomesticCountries.IDs[]`. `uTestDomesticCountryList` pins it.
- **The dupe policy is `MarksDupes`** (M3): `logsubs2` asks
  `ContestIdentity(Contest).MarksDupes`, not `ActiveQSOPointMethod`. Since
  M10 S4 the base answers True; Internet Sprint and the Youth Championship
  of Russia (the only two `AlwaysOnePointPerQSO` rows) say False. Exchange
  parsing (RAC, PCC, Arktika) and RussianDX's initial exchange moved at M5b
  (below); `logedit.TotalScore`'s five formulas moved at M6 (below).
- **A contest parses and validates its own received exchange** (M5b,
  2026-10-02). `LOGSTUFF.ProcessExchange` runs the contest-blind gate, then
  asks `TContestBase.ParseReceivedExchange(aText, aSession, var aExch, out
  aErrorMessage)` of the active contest (its identity when classless). The
  session is DATA (`TReceivedExchangeSession`): the engine's parsers
  (`Parsers`, a `TExchangeParsers` -- one named method per format, since M11
  S9d), `ExchangeFormatOf` (nil but in IN7QPNE's party hand-off), and
  services `ZoneOfCall`, `IsDomesticQTH`, `CallWindowHasCall`,
  `AbandonEntry` -- the class reads no global and the tests hand it the
  shared stub `uTestExchangeParserStub`. **The base parses in the contest's
  FORMAT: `ParseReceivedExchangeFormat`, a protected virtual every registered
  contest states (184 overrides, M11 S9d) by calling the parser for its format
  by name -- testing the station where its field list does, the text where the
  format is chosen by the text (Arktika Spring, the PCC). The base format
  parses nothing and answers False.** A RULE overrides `ParseReceivedExchange`
  and calls `inherited`, or a parser by name (RAC's VE0 serial, LABRE's PY
  state); it never tests a kind -- the session has none since S9d. Until then
  the base parsed the session's kind through one machine
  (`LOGSTUFF.ParseExchangeShape`, deleted). A refusal's reason goes in `aErrorMessage` and shows
  like an improper county. Seven contests gained classes for it (Canada Day,
  Canada Winter, SAC CW/SSB, LABRE, Russian DX, RU3AX -- siblings, copies,
  design 1.4); NY4I's two rulings (design 7.10) live on
  `TContestARRLSSBase` (no precedence) and `TContestStateQSOPartyBase`
  (out-of-state works only the host state, judged by `IsDomesticQTH` against
  the host's county file, never by a `DomesticQTH` left in the record).
  `TStationContext` grew `MyCall` and `InHostState` (FCONTEST's own in-state
  answer). New seams beside it: `MayBeACallsign`, `InitialExchangeFromCall`,
  `FormatADIFReceivedExchange` (the SRX_STRING; Field Day DX writes `1D DX`).
  Word cutting is `uExchangeTokens`, lifted from LOGSTUFF line for line. The
  matrix's `parse` section (66 typed exchanges per contest and variant, no
  points) gates it. UA4W's parse rule, held in LOGSTUFF at M5b, is its
  class's `ParseReceivedExchange` since 2026-10-14 (design 8.2p).
- **A CONTEST STATES WHAT ITS EXCHANGE REQUIRES; A FORMAT NEVER DROPS A
  WORD** (Q115, NY4I 2026-10-18: *"The contest class should be stating what
  is required. Some contests could allow just rst but most require more
  data."*). The format parser refuses a word it cannot read, names it in
  `ExchangeErrorMessage` and makes it `ExchangeErrorToken`; what must be
  present is the class's rule in its own `ParseReceivedExchange` after
  `inherited` -- no "required fields" virtual (`ReceivedExchangeFields` says
  what is CARRIED, and is the ADIF export). Built for the RST-and/or-grid
  format: the ARRL VHF runnings, CQ VHF and the Stew Perry call
  `RequireReceivedGrid` (grid required, RST optional, all five sponsors), and
  each says a grid word is not a call (`MayBeACallsign` -- `FN31PR` was being
  logged as the CALL). `uTestGridExchange` drives the REAL engine per
  contest. The sibling grid formats (`ParseRSTAndGrid` WWL,
  `ParseRSTAndGridSquareOrRDA` UA4W, `ParseNameAndPossibleGridSquare` GridLoc)
  still drop an unreadable word, and the positional ones refuse without a
  message -- reported, not changed. Import has no refusal seam yet (Q112
  wants one for both).
- **A contest owns its final score and its bonuses** (M6, 2026-10-02).
  `LOGEDIT.TotalScore` -- what every score reader reads -- gathers a
  `TScoreTotals` (a record: the interface-parameter exemption) and asks
  `FinalScore(aTotals, aView)` = `CombineScore` + `BonusPoints`; both public
  entries are NOT virtual, `CombineScore` being a template (a session with no
  multiplier scores its points) over the protected
  `CombineWithMultipliers` -- FISTS's points-alone is ITS OWN override since
  M11 S7 (`TScoreTotals.SessionExchange` went with it). **The view is read-only** (`TLoggedQSOView`, an
  abstract class; `TLoggedQSOList` for tests) and the application keeps it in
  memory beside the totals (`uScoreTotals`), because reading the database per
  score was measured at ~130 us a row. Bonuses: **declared data**
  where they share a shape (`GetBonusStations` -> `TBonusStation`, paid by the
  base, qualified by `CountsTowardBonus` / `CreditsBonusMode`, paid as often
  as its `Scope: TBonusStationScope` says -- `bsOnce` (Missouri's W0MA/K0GQ),
  `bsOncePerMode` (the Salmon Run's W7DX, with the single-mode rule from
  `Station.MyCategoryMode`), `bsOncePerBandAndMode` (BC's VA7ODX since #88,
  2026-10-26, and Wisconsin's W9FK below 50 MHz since round 2; each excludes
  dupes and X-QSOs in its `CountsTowardBonus` through the base's
  `IsCreditedContact`, the one statement of "a valid contact"). A new pay-out shape is a new `Scope` member in the base,
  never a class-local copy; `uTestContestTotals.Test_BonusStationScopes` pins
  all three over one log), otherwise the class's own `BonusPoints` over
  the view, adding `inherited` (NC's Rarest-of-NC sweep, Idaho's dormant
  county, and since Q32 -- 2026-10-17 -- Missouri's peak-hour bonus: one
  point per valid 80/40 m QSO logged 1400-1959 UTC, to 250, from each QSO's
  own logged time; `TalliesLiveQSO` and the live-only tally it fed are
  DELETED, so no bonus is counted as QSOs are logged). Nine contests gained classes
  for their formula (RF Cup x3, RF Championship x2, WAE x2, OZHCR, ALRS);
  the RF Championship's table is the leaf `uRFChampionshipPoints`. The matrix
  gained a `totals` section (reload, counts, `TotalScore`, `CLAIMED-SCORE`)
  frozen first; `uTestContestTotals` pins every formula and every bonus edge.
  ~~ALRS's empty-QTH QSO scores from heap garbage~~ (`LOGGRID`, design Q37,
  §8.2h) -- **fixed at Q37 (2026-10-17)**: LOGGRID measures only what
  `uGridShape.IsGoodLookingGrid` calls a grid, so a malformed grid has no
  distance and each class scores it by its own rule at distance 0 (ALRS
  guards its logarithm; WWL and the Stew Perry give 1).
- **A RULE THAT CHANGES BY YEAR ASKS THE LOG'S YEAR, NEVER THE CLOCK**
  (Q35, built 2026-10-17). `uContestBase.LogContestYear(aTotals, aView)` is
  the one statement: `TScoreTotals.LogStartTime` (the contest row's
  `start_time`, read ONCE at open by `TLogRepository.LoadContest` /
  `LogStartTime`, filled by `uScoreTotals.GatherScoreTotals`), else the
  EARLIEST dated QSO in the view, else 0 (unknown). Nothing writes
  `start_time` until Q99, so today the QSO dates decide. Live, reload,
  rescore, matrix and `/EXPORT` all reach it through `LOGEDIT.TotalScore`,
  so they agree. Idaho is the first reader: one typed table per contest year
  (`IdahoBonusCounties2026` -- registered for 2026 ONLY; whether it also
  covers 2027 is the sponsor's open question) chosen in
  `IdahoBonusCountyPoints`; a year with no table pays no county bonus and
  logs ONE Error naming the year (once per year per session --
  `uTestLogCapture.TCaptureAppender` proves it). `Test_IdahoHasATableForTheCurrentYear`
  reads the clock ON PURPOSE and fails on the first run of a year with no
  table: that is the yearly reminder -- add the sponsor's table, never
  register an old one for a new year without their word. The matrix's QSOs
  are all 2026-01-15, so its records sit in the 2026 table year.
- **A CONTEST OWNS WHICH ADIF EXCHANGE TAGS ITS RECORD CARRIES (2026-10-17,
  design 8.2w).** `TContestBase.EmitADIFReportFields` (RST_SENT/RST_RCVD: EVERY QSO'S, NY4I
  "Every QSO", not declared by the class) and
  `EmitADIFReceivedFields` (QTH, PRECEDENCE, CHECK, NAME, the `ADIFPowerTag`,
  SRX, STX, TEN_TEN, AGE) writes exactly what the class's
  `ReceivedExchangeFields` declares -- so **a new contest's field list is also
  its ADIF export**, and a field the list forgets silently leaves the file.
  STX is ours and is not gated. `uADIF` no longer writes any of them itself.
  A class with a rule of its own overrides either method; one that only moves
  the power to another tag states `ADIFPowerTag`. Pinned by
  `uTestADIFReceivedFields` over the registry -- no row to add per contest.
- **A contest owns its identity, and everyone asks it** (M1, 2026-10-01).
  `uContestRegistry.ContestIdentity(h)` answers for EVERY contest handle --
  the class, else a plain `TContestBase` (only NoContest, and a byte that names
  no contest); never nil, owned by
  the registry, thread-safe, and carrying no station (ask it what a contest
  IS, never to score). The Cabrillo `CONTEST:` line, ADIF `CONTEST_ID`, both
  UDP broadcasts, both score-posting clients, the external logger, the
  summary sheet, the log database's friendly name and the calendar menus all
  ask it. `CabrilloName`, `ADIFContestId` and `FriendlyName` default to the
  enum's spelling, stated ONCE in the base -- do not restate that fallback at
  a call site, and do not transcribe a blank as `''` in a class. `ADIFContestId` is what export writes AND what import matches,
  which closed inventory D9. Use `ActiveContest` (nil for a classless
  contest) only for behaviour. **Since M9a every class STATES
  `DisplayName`, `CabrilloName` and `ADIFContestId` itself** (NY4I's ruling)
  -- in the leaf, never a family base -- and `DisplayName` is the human name,
  the `FriendlyName` where the row has one.
  `uTestContestDisplay.Test_EveryClassStatesItsIdentity` compares each
  getter with the parent class's (a negative control proves it can fail)
  and holds the enum-spelled display names as a ratchet (design Q53).
  **Q53 was applied 2026-10-17**: 24 contests got NY4I's names (and 14 their
  WA7BNM refs); the 17 with no name keep their internal one. A name change
  is the class's two getters plus its `uTestContestIdentityPin` row, by hand.
  **THE CABRILLO NAME IS WRITE-ONLY, SO RENAMING IT NEEDS NO READ ALIAS**
  (2026-10-19, NY4I's 18 WA7BNM renames, e.g. CQMM -> CQMMDX): TR4W has no
  Cabrillo import, and every `CabrilloName` reader WRITES it (PostUnit's
  `CONTEST:` line and EDI fallback, LOGSUBS2's UDP `<contestname>`). Only the
  ID (`ContestTypeSA`, stored) and the ADIF id (import matches it) need the
  never-reuse rule. **Two DIFFERENT events never share a Cabrillo name**:
  only the pairs the sponsor states share one (WRTC and IARU write
  `IARU-HF`; the RoLo CW and SSB write `RSGB-ROLO`, WA7BNM 77/361), and
  `Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName` walks the registry and
  fails any other pair -- a new shared pair joins its `IsSharedOnPurpose`
  table only on a source. TR4W's XMAS is the SSA Jultest, NOT the DARC
  Christmas (NY4I, 2026-10-19): it writes the sponsor's `SSA-JULTEST`, the
  DARC contest WA7BNM's `XMAS`; XMAS's QRZ.RU id 100 is DARC's page, a
  known defect left until the Jultest's id is found.
  The matrix's `export.cabrillo` lines hold every other Cabrillo name.
- **A NON-ASCII literal in a class is written as `#$xxxx` code points**
  (Q42, 2026-10-17: the OZCHR session names in Cyrillic). The factory's units
  carry no BOM, and a non-ASCII literal in a BOM-less unit is read in the
  build machine's ANSI codepage (`Lint-BOM.ps1`); code points keep the source
  ASCII. The session's `ContestName` is for people (title bar, summary sheet,
  hour report): the Cabrillo `CONTEST:` line is `CabrilloName`, and the EDI
  `TName` falls back to it for a non-ASCII name (`PostUnit.EDIContestName`).
- **Set-up reads the contest** (M2, 2026-10-01). `FCONTEST.ApplyContestTraits`
  is the ONE writer (with `ApplySessionDefaults` after it) of the session's
  kinds (four since M11 S3 and S4) -- `ContestSession`, the `Active*` globals until M10 S9 -- the QSO/mult by band/mode
  flags, VHF, count-domestic-countries, the CTY zone list and (in the head)
  the domestic file: **the operator's statement (`CommandIsStated`), else
  `ContestIdentity(Contest)`** -- the tables it once could read are deleted
  (M10 S8). ~~The seven tokens are replayed through
  `uSettingsEffects.ReplayContestStatements`~~ -- gone at M10 S2 with the
  seven settings; the kinds are written from the contest
  unconditionally. So **a trait override changes set-up now** -- the matrix sees it. What a
  contest states in `DescribeSession` runs after and wins (M7a, below); a
  classless contest's `FoundContest` arm still does. New traits:
  `ZoneMode` (stated, never a Boolean cast -- that gave 255),
  `QSOByBand/Mode`, `MultByBand/Mode`, `VHFBandsEnabled`,
  `CountsDomesticCountries`, `InStateDomesticFileName`. **Since M10 S5 the
  nine flag properties (with ERMAK and RTC) are ONE set every class states,
  `GetFlags: TContestFlags`** (`cf...` members in bit order; the five CW/SSB
  pair families state it on their base); the per-flag getters are not
  virtual. Every party states `InStateDomesticFileName`, and
  `QSOPartyArea` (the prompt's area) is its HostState on the state-party
  base. **Since M10 S6 THE BASE READS NO TABLE**: its row getters answer
  DUMMYCONTEST's neutral row (`[]`, `No*Mults`, `UnknownExchange`, `''`, 0,
  the enum's spelling), so a value a class does not state is NEUTRAL, not its
  row; `VC.USQSOPartyStateName` and `QSOPartyAreaName` are deleted, and the
  outside readers (MainUnit ERMAK, uHamScore RTC, `postunit.ZoneSentForThisContest`,
  `/MATRIXLIST`) ask the class. **ADIF STATE IS THE WORKED STATION'S, PER
  QSO (Q76/Q89, NY4I 2026-10-16)** -- `TContestBase.ADIFWorkedStationState`
  (base `''`), through `uADIF.GetADIFStateForQSO`: a party county gives its
  state (`ADIFCountyState` -- HostState on `TContestStateQSOPartyBase` for a
  key that is not two letters, BC's `BC` included; the 7QP, NEQP and IN7QPNE
  read their own key spellings), an out-of-state station's state or a VE's
  province is written as itself when `uADIF.IsADIFPrimarySubdivision` allows
  it for the station's country, DX gets none (`uADIF.ADIFStateOfPartyQSO`
  composes it). CNTY: `WritesADIFCounty`, every state party with a US host;
  a Canadian host (BC, Ontario since #127) states False -- ADIF has no
  Canadian CNTY. **The county NAME is `TContestBase.ADIFCountyName(aQso,
  aDomesticName)`** (#118, 2026-11-17, the PostUnit seam): base = the
  `.dom` display name -- the party's OWN county file's `^Name`, through
  `CountyFileCountyName` (2026-11-20; it was the session's multiplier list,
  which an in-state session never fills with counties). **A new party's
  `_cty.dom` names every county `KEY = KEY,^Name`, the name spelled as the
  ADIF county list spells it** (the K1MU validator's `adiftags.sas`), from a
  sponsor table committed under `docs/ContestRules`; `uTestRoverState.
  CheckEveryCountyNamed` holds it. Hawaii maps its 14 DISTRICTS to ADIF's five Hawaii
  counties (`HI,Honolulu`); `''` writes none. A party whose multipliers are
  not counties maps them there, never by `WritesADIFCounty` False.
  **A RECEIVED GRID IN PLACE OF THE QTH is Hawaii's worked example** (its
  header): Digital + grid shape (two letters A-Z, two digits, ZZ00 a fake)
  parsed before `inherited`, points but no multiplier, WSJT-X's GRIDSQUARE
  through `ApplyADIFImport`; uWSJTX copies the QTH into `DomesticQTH`, so
  test the QTH's SHAPE. **A GRID THAT IS A MULTIPLIER is South Dakota's**
  (`uContestSouthDakotaQP`, #129, 2026-11-18): a Digital QSO's four-character
  Maidenhead square on the PREFIX sheet (`PrefixMultiplierKey`, True with
  `''` otherwise), the key set by the class in `ParseReceivedExchange`
  because `SetDXQTHAndPrefix` runs before the parse; digital QSOs earn only
  the grid, CW/phone never one (`CountsAsMultiplier`); the score is
  (points - `TScoreTotals.DigitalQSOPoints`) x (domestic + DX) +
  `DigitalQSOPoints` x grids. Both grid parties read "[report] GRID" through
  `uGridShape.TryParseReportAndGrid`. `Test_EveryPartyAndOnlyAPartyWritesAState`
  holds CNTY only for a US-host state party (judged by
  `IsADIFPrimarySubdivision('VE', HostState)`, not by name) and, for every
  contest whose OWN class does not state `WritesADIFCounty`
  (`ClassStatesItself`), exactly there -- a class that states it is taken
  at its word and pins it in its own test. **A party base name is not
  always the state's name**: `hawaii.dom` is the Hawaii-STATE line `s50.dom`
  includes, so Hawaii's files are `hawaiiqp.dom` / `hawaiiqp_cty.dom` --
  check `ls tr4w/target/dom` before naming. `uTestQSOPartyEngine.Activate`
  applies a `DescribeSession`-stated `MultByBand` per entrant since Hawaii
  (lifted from New Hampshire's `ApplyFlagsFor`). **A
  `ADIFCountyState` KEY IS A HOST COUNTY ONLY WHEN THE PARTY'S TABLE
  RESOLVED IT** (issue 134, fixed 2026-10-27): the record's `DomesticQTH`,
  else the typed `QTHString` when `Station.IsDomesticQTH` knows it (a rover
  QSO has no `DomesticQTH`). A typed DX QTH (`KP4`, `UA9`) is no county: no
  STATE, no CNTY. The export therefore asks the object that HOLDS THE STATION
  -- `uADIF.ContestForRecord(rec, ActiveContest)`, for STATE (EmitADIFRecord)
  and for PostUnit's CNTY block -- never `ContestIdentity`, which has no
  table; `GetADIFStateForQSO` is the identity-only form, for tests. (Issue
  137 holds the matrix totals' double count.) In a commit message, never put
  "fixed:" or another closing word before an issue number the commit does not
  fix: GitHub closed both from "Found, not fixed: #134". D7's
  host-state-on-every-QSO and `GetStateForContest` are gone; a new QSO party
  states both answers and joins `uTestContestExport`'s pins (no count:
  STATE exactly where it splits a rover call is walked over the registry
  since Q108 S1). **THE TABLES ARE DELETED (M10 S8,
  2026-10-14)** -- `ContestsArray`, `ContestsBooleanArray`, `QSOParties`,
  `TContestInfo` and the `ci*`/`*_BIT` constants; `ContestTypeSA` stays. The
  county-line import asks the party class (S7); the rover split on ADIF
  export asks `TContestBase.SplitsRoverCallOnExport` through
  `uContestRegistry.ContestSplitsRoverCallOnExport` -- True for every QSO
  party since NY4I's ruling on Q90/Q94 (2026-10-14;
  `Test_EveryQSOPartySplitsARoverCallOnExport`, 23), NOT derived from the
  county line (a rover is not a county line; the old row's fifteen and the
  class's county line still disagree for six, which the import pin holds). The S0 pin went
  with the tables; **`uTestContestIdentityPin` replaced it** -- every
  contest's WA7BNM / QRZ.RU ids, e-mail, friendly, display and domestic file
  name as literals, generated ONCE at S8 from classes proven equal to the
  table and NEVER regenerated to clear a failure (a failure is a class
  changing an identity value; change its one row by hand, deliberately). A
  NEW contest adds its row by hand. A QSO party's
  `DomesticFileName` is its COUNTY file (out-of-state load, in-state test);
  `Test_EveryQSOPartyNamesBothDomesticFiles` holds the two names together.
  In-state detection reads it through `uAppPaths.ShippedDomFilePath` and
  `uDomFileKeys`. Design doc §7.9, §8.2c.
- **A contest describes its own session** (M7a, 2026-10-02).
  `FCONTEST.FoundContest` asks `ContestIdentity(Contest).DescribeSession(
  CurrentStation, aSession)` after the head (traits, the operator's
  statements, the in-state decision) and `FCONTEST.ApplySessionDefaults` --
  the ONE writer -- applies it, where the arms used to run, before the closing
  `case ContestSession.Exchange` (was `case ActiveExchange`). **`TSessionDefaults` is a class** because every value
  has a third state, NOT STATED: the applier writes only what was stated, and
  a stated value overwrites unconditionally (today's precedence: it beats a
  pre-`CONTEST` statement, loses to a later line). The class writes no global
  and reads only `aStation` -- the identity object carries no station, so
  `uContestFactory.CurrentStation` is exported and passed in. Memory keys are
  named (`TSessionMemoryKey`), never Tree's codes; the domestic-country groups
  are `uContestBase` constants FCONTEST's own `Add_KVE`-style helpers read too.
  **All 55 arms naming a registered contest are gone**, and FoundContest's
  `case` with them: POTA's arm left 2026-10-13, the UA4W Championship's -- the
  last -- 2026-10-14, and LogCfg's `case` went too. LogCfg's per-contest
  CQ-exchange defaults are the sibling `CQExchangeDefault(aStation)` -- asked
  later, once the whole config is read -- and the ARRL DX one is on the CW
  class only (LogCfg never named the phone running). **D8 is resolved by
  stating both branches** on `aStation.InHostState` / country / continent.
  Winter Field Day's row and class now say `ARRLDXCCWithNoARRLSections`, the
  value its arm always set (Q38 asks whether it should count one at all).
  The matrix was 185 identical with no re-freeze; `uTestContestSession` pins
  the base stating nothing, the three-state values, and D8's four state lines.
  Design §8.2i; `ADDING_A_CONTEST.md` B2 "Identity and set-up".
  **What a contest SENDS where MY STATE goes is `TSessionDefaults.SentState`**
  (was `MyState`; M9a, design 7.11): the applier holds it as the SESSION's
  (`FCONTEST.SentMyState`, cleared at FoundContest's head) and **never writes
  MY STATE** -- the operator's setting. Every reader of the sent exchange
  (set-up's messages, LogCfg, the CW `&` macro, PostUnit's Cabrillo and ADIF
  sent columns, uGetScores, the readiness check, `CurrentStation.MyState`)
  asks `SentMyState`; the in-state test, uTelnet's `MY_STATE` token and
  Preferences read the station's. `Test_SetUpNeverWritesMyState` pins it for
  every contest. **Since 7.12 `SentMyState` falls back to the RESOLVED MY
  STATE**, and the in-state test and the telnet token read `ResolvedState`.
  The operator's override says where the station is; SentState says what
  the rule sends. They are two layers, and SentState is never stored.
  `SetUpRSTMyZoneExchange` no longer writes MY ZONE (Q57).
- **The classless contests gain classes** (M7b; batch 1, 2026-10-02 --
  thirty-nine contests, design §8.2j). Each transcribes its row and EVERY arm
  that named it, and the arm is deleted. **No new family base**: CQ WPX RTTY
  and CQ WW RTTY score by other arms than their CW/SSB families; 7QP and NEQP
  are multi-state parties on `TContestBase` (7QP stays a party to set-up by
  its row, `IsUSQSOParty`; Q40); the JIDX/All Asian/Oceania pairs, EU Sprints
  and ARRL VHF runnings are copies until Q7. New seams it added:
  `TStationContext.IsDomesticCountryCall` (a SERVICE -- ARRL 160's CTY lookup;
  nil means not domestic) and `.ContestName`; `TSessionDefaults.InitialExchange`,
  `ZoneMult`, ~~`DXMultLimit`~~ (DELETED at #88 round 3, 2026-10-26, with
  LOGWIND's global and the matrix's `dxmultlimit` line: nothing, in D7 or
  here, ever READ it -- a sponsor's cap on one multiplier kind is the class's
  `CombineWithMultipliers` over the base's `SummedMultipliersWithKindCapped`,
  the 7QP's and the Salmon Run's 10 DX), `R150SMode`, `SuppressZoneExchangeMessages` (the
  JIDX name test in FoundContest's closing `case`; deleted at M11 S9e part 1 --
  the JIDX state no `WriteDefaultExchangeMessages`); the sibling
  `RepeatSPExchangeDefault` (the EU Sprints). The CQ-M okrug test was lifted to
  `uCallSignRoutines.InSameFederalOkrug(aMyCall, aHisCall)`. Tesla's arm's
  `DisplayTotalScore` repaint did not move (display, not a rule).
  **Batch 2 (2026-10-02, design §8.2k) gave the other forty classes** -- no
  new family again (UCG and WWIH COPY CQ's arms; the King of Spain, REF,
  RoPoCo and Region 1 RCC pairs are siblings until Q7). It added
  `TSessionDefaults.InitialExchangeCursorAtStart`, `DXCCMultByBand` and
  caption memories (`SetExchangeCaptionMemory`, the RTC's); lifted
  `PortableStation` from Tree to `uCallSignRoutines`; and, a DECIDED behaviour
  change, `TContestBase.RunsInMode` -- the RoPoCo runnings share ADIF id
  `RSGB-ROLO`, and `uContestRegistry.ContestOfADIFRecordMode` picks the one
  that runs in the record's mode once the record is read (the matrix moves
  only their phone import lines). Ten-Ten's arm always scored 2 (a Word
  against -1, Q46): the class says 2. **M7b is done, and exactly ONE
  contest is classless on purpose** -- DUMMYCONTEST, "no contest";
  `Test_M7bBatch2ContestsAreSiblingsOnTheBase` fails if a second appears.
  POTA (Q6, 2026-10-13), the UA4W Championship (Q28), RSGB 1.8 (Q33, both
  2026-10-14, design 8.2p) and IN7QPNE (2026-10-14, design 8.2r) left the
  list. Sites still naming a batch-2 contest were seams
  not built -- ~~M9 display/HamScore: WRTC, SST, CW Open, RTC~~ done at
  M9a (§8.2m); Radio YOC's loader stays (engine state) -- listed in §8.2k. ~~M8 multipliers: YB DX, RDA, YO DX~~ -- done
  at M8: RDA's and YO DX's hint arms are their classes', YB DX's was a no-op
  and is deleted (§8.2l). RDA's initial-exchange fallback in LOGEDIT is an
  EXCHANGE rule and stays (Q50).
- **IN7QPNE is a COMPOSITE** (NY4I 7.14; built 2026-10-14, design 8.2r).
  `TContestIN7QPNE` owns one instance each of the Indiana, 7QP, NEQP and
  Delaware classes (made via `ContestClassFor`, NOT `ContestIdentity` --
  those are shared and station-less) and judges each QSO by the party of
  the worked station's county: `DomesticQTH`, routed by the spelling of
  `in7qpne_cty.dom`'s keys (`IN`+3, the 7QP states+3, the NE states+3,
  `NDE/KDE/SDE`; `IN7QPNEPartyOfQTH`). No party -> the entrant's own party
  (MY STATE routed, when in state); neither -> 0 points, no multiplier,
  refused when typed. It delegates `ScoreQSO`, `CountsAsMultiplier` (with
  the party's bands) and `ParseReceivedExchange`; everything asked without
  a QSO (`ValidateQTHCount`, set-up traits, which multiplier a QTH counts
  as) stays the composite's, recorded as findings (Q79-Q82). **`UsesBand`
  is the UNION of the four parties' own `UsesBand`** (2026-10-16, asked of
  the owned components, never copied): New England 80-10 m, 7QP and
  Indiana 160-10 m, Delaware 160-10 m and 6 m up, all without WARC -- so
  IN7QPNE states `cfVHFBandsEnabled`; a QSO still scores only on its
  judging party's bands. `uTestQSOPartyBands` pins all five.
  The NE spellings of `in7qpne_cty.dom` and `neqso.dom` AGREE since Q81
  (2026-10-17): `neqso.dom` carries the combined file's 68 New England
  entries exactly (state first, `MEAnd`; Connecticut's planning regions,
  `CTCap`) and `neqsow1.dom` the same keys mapped to their states, so New
  England's `ADIFCountyState` reads the FIRST two letters. Still route on
  the combined file's keys -- it is the one the session loads. No score
  posting: `PermittedOperatingAids`, and since 8.2r `uHamScore` asks it too
  (`ContestPermitsScorePosting` -- it asked nothing before, so WRTC's rule
  never reached HamScore; Q83).
- **A contest tells the display and the reports what to show, as DATA the
  UI renders** (M9a, 2026-10-02, design §8.2m; `ADDING_A_CONTEST.md` B2 "Display
  and reports"). No class touches a form, a
  canvas or a global. Seams: `DescribeNewContestPrompts(TNewContestPrompts)`
  -- the New Contest dialog's two `case`s, ordered steps (rows go out in the
  order asked, the last comment wins), the QSO-party head on the base from
  `QSOPartyArea` (not `HostState`: 7QP's area is '7th area'); a step may
  NAME ITS ROW (`AskFieldWithCommentAndLabel`, `TNewContestPrompt.RowLabel`,
  2026-11-11: EUHFC and KVP label their MY ZONE row "MY LICENSE YEAR", the
  CWT its MY STATE row "MY QTH OR MEMBER NO" -- `uAppStrings`
  resourcestrings. The Jock White Field Day's branch row reads MY ZONE ON
  PURPOSE (issue 287, 2026-11-15; NY4I on issue 320: a label over the zone
  value says Zone -- its 2026-11-12 "MY BRANCH NUMBER" label is withdrawn;
  the branch gets its own MY BRANCH NUMBER setting under issue 320); Locust and the NCCC Sprint take no member
  number (issue 290, sponsor rules), so they ask `SNewContestEnterNameAndQTH`
  -- the CWT's text without "or member number" -- and keep the MY STATE
  label; the CWT alone keeps `TC_ENTERYOURNAMEANDQTH`; the prompts table
  renders a label, `StepCommentLabelled`) -- the label is only what is read,
  the command queued is still the field's (`uNewContest.RowCommand`);
  `NewContestValueRefusal(field, value)` (Q104, 2026-10-17: '' accepts, any
  other answer is the message `uNewContest.BeginNewContest` shows while OK stays
  disabled; the base accepts everything, IN7QPNE refuses an in-area MY STATE);
  `DescribeNewContestHostArea(out TNewContestHostArea)` (issue 217,
  2026-11-05: the box "I am in <area>"; ticked, the MY STATE row becomes a
  MY COUNTY drop-down of the county file's KEYS -- set-up's in-state test's
  own -- else free entry taking a state, a province or DX, `uNewContestHostArea`;
  the queued command stays MY STATE, the row's FIELD, never its label;
  the base answers for every `IsUSQSOParty`, BC/ON/QC/IN7QPNE state False
  with their reason; `uTestNewContestHostArea` walks the registry; a party
  whose outside stations send their ARRL/RAC SECTION sets
  `OutsideTakesSection` (Pennsylvania, NY4I 2026-11-20: "send WCF, not FL")
  -- the row is labelled MY SECTION, prefilled from the station's MY SECTION
  by `uTR4WConfigFile.StartupMySection` (the dialog can run before the
  settings load), and judged by `HostAreaOutsideSectionRefusal` (a section
  or DX; PA lists `PA EPA WPA` as inside));
  `DescribeNewContestHome(out TNewContestHome)` (issue 167, 2026-11-15: an
  `OfferIAmIn` box's region in CTY terms -- `Countries`, or `Continent`
  (no class states a continent since review M16, 2026-11-16: the North
  American boxes of ARRL 10, ARRL 160, RTTY Roundup and CQ 160 read their own
  domestic list, CQ WW RTTY states `K VE`; since NY4I's ruling of 2026-11-19
  those six boxes are CAPTIONS naming the exchange -- "I send a state or
  province", ARRL 160 "I send an ARRL/RAC section" -- not "I am in North
  America", which told a KP4 or XE entrant the wrong thing; ARRL 10's
  mexico.dom key for Mexico City is the sponsor's CMX); `HomeIsInside` False for a box
  that is only PART of its countries, New England in K;
  `HomeIsDomesticCountries` reads the class's own `DescribeSession` list on a
  country-less station, so PACC states `PA` itself, JIDX `JA` and UBA `ON`
  (their own station tests); the base states nothing. A box with no region
  is an EXEMPTION with its reason in `uTestNewContestHome.
  OffersABoxWithNoRegionOnPurpose` (IARU/BSCI HQ-or-member, Arktika/PCC
  clubs, Gagarin, WWPMC, REF, RSGB 1.8, IRTS, EU DX, and the caption boxes
  of the IOTA and POTA since the walk counts captions) -- the walk fails a box
  with no region that is not listed, and a listed contest that states one);
  `TotalsDisplay` (uTotal; the domestic and, since issue 277 2026-11-11, the
  PREFIX row's captions -- the CW Open says `Calls`, its key being the whole
  callsign; every other contest `Prefixes`, pinned -- and since 2026-11-11
  the ZONE row's, `Years` -- answered BY THE BASE for any contest that states
  a `ReceivedYearKind` since issue 298 stage 3; EUHFC and KVP no longer
  override it); `ZoneColumnHeading` (2026-11-11: the log grid's heading over
  the zone column, asked by `uLogGrid.HeaderText` and, since stage 3, Edit
  QSO's year label; base = ColumnsArray's `Zn`, and `Year` for a stated year
  kind, again from the base -- ColumnsArray's text NEVER changes, it is also the
  COLUMN WIDTH token uCFG matches; `Test_ZoneColumnHeading` walks the
  registry); `MyZoneLabel` (2026-11-11: Preferences > Station information's
  label beside MY ZONE, asked by `uPrefsForm.ShowContestStationLabels` on
  load, show and Station-page selection; base `SPrefsMyZoneLabel` 'CQ zone:',
  which shares the `.lfm` caption's catalogue entry, EUHFC/KVP
  `SPrefsMyLicenseYearLabel`; `Test_MyZoneLabel`); `MyZoneHelp` (its
  tooltip on the label and box; base '' = keep the MY ZONE command's help,
  EUHFC/KVP `SPrefsMyLicenseYearHelp`; reapplied after `BuildSearchIndex`,
  which sets the command help); `MyZoneIsAStationZone` (2026-11-12, base
  True, EUHFC/KVP False: a logged QSO's captured zone never replaces a
  licence year in the SENT exchange -- their Cabrillo and STX_STRING sent the
  QSO's ITU zone until then. ONE rule picks the zone a stored QSO sends,
  `uContestBase.SentZoneKindOfQSO(contest, zoneMode)` -> `TSentZoneKind`,
  handed to `MyStationExchangeOfQSO`; never key it on `ZoneMultiplierZones`,
  whose `zmzNotCQOrITU` is also CQ 160, WRTC, EU DX ... which send a real
  zone; `uTestLogMyFacts` walks the registry for the exact set);
  `ReceivedYearKind` (issue 298 stage 2, 2026-11-12: base `rykNone`,
  EUHFC/KVP `rykTwoDigitYear`; `VC.TReceivedYearKind` also has
  `rykFourDigitYear` (1900..the QSO's own year) and `rykYearsLicensed` (0..99),
  from DXLog's files, no class yet -- a four-digit one needs stage 4's sheet.
  The RECEIVED side: the parser's digits and range
  (`ParseRSTLicenceYear(aText, ReceivedYearKind, aExch)`), the base
  `ApplyADIFImport`'s year, Edit QSO and `ContestKeepsYearInZoneSlot` all ask
  it; the year is `RcvdYear`, read by `TryLicenceYearOf`, written by
  `StoreLicenceYear` / `ClearLicenceYear` only. `MyZoneIsAStationZone` stays
  the SENT side; `uTestLogReceivedYear.Test_ExactlyTheYearContestsStateAKind`
  walks the registry holding the two equal. STAGE 3 (2026-11-12): display
  and export read the field too, through ONE answer --
  `uContestBase.ReceivedYearTextOf` / `TryReceivedZoneOrYear` /
  `RSTAndReceivedYearText`, asked with the RECORD's contest's kind; the base's
  `ZoneColumnHeading`, `TotalsDisplay`, `FormatADIFReceivedExchange` and
  `CanonicalReceivedExchange` follow a stated kind, so a year contest states
  only `CabrilloReceivedRSTYear(ReceivedYearKind, ...)` for its received
  column -- never `CabrilloReceivedRSTZone`, which reads the slot. And
  `my_cq_zone` is `uContestFactory.SessionMyCQZone(contest)`: MY CALL's CTY
  zone where `MyZoneIsAStationZone` is False, never the year;
  `uTestReceivedYearDisplay` walks the registry proving the field reaches no
  other contest's output). THE SENT YEAR IS THE ROW'S since log schema 8
  (issue 300, 2026-11-13): `SentLicenseYearValue` is the number
  `SentLicenseYearText` formats and `qso.year_sent` stores;
  `MyStationExchangeOfQSO(..., aYearKind)` puts the row's year in the zone
  slot; and the base `CanonicalSentExchange` BRANCHES ON `ReceivedYearKind` --
  a year contest's canonical sent exchange is the QSO's sent RST and
  `TCanonicalExchangeContext.SentYearText`, not the CW template (which said
  `599` on phone). The licence-year parser names a YEAR in its refusals
  (`SExchangeNoLicenseYear` / `SExchangeImproperLicenseYear`), never the
  zone parser's `TC_IMPROPERZONENUMBER`; `SummarySheet` (PostUnit);
  `ReportsRunningScore` (hour totals); `CabrilloContestName`,
  `RequiresCabrilloLocation`, `CabrilloHeaderLinesBeforeTag` (keyed on the
  Cabrillo tag NAME -- `CabrilloTags` is a UI unit's),
  `CabrilloModeString` (the base calls `uCabrilloFormat.FormatCabrilloMode`;
  PostUnit's inline copy is deleted); `CanonicalReceived/SentExchange`
  (uExchangeBuilder dispatches and collapses; the shared pieces are the leaf
  `uCanonicalExchange`); `ScorePostingMultiplierType` (LOGSUBS2's XML);
  `PermittedOperatingAids` (WRTC: no SCP, cluster or score posting --
  `MainUnit.OperatingAidOfWindow` is the UI's window-to-aid wiring);
  `OffersQTCs` (the WAE QTC menu); `OffersParkTools` (POTA's two menu
  rows, since its class); `SubmitsLogToARRL` (2026-11-11, base False: Tools >
  Submit ARRL Log opens the ARRL's portal and is greyed otherwise -- True on
  `TContestARRLDXBase`, `TContestARRLSSBase` and every other
  `uContestARRL*` class; IARU HF and ARRL Kids Day NOT stated, on no
  sponsor word; the `ARRL_PORTAL` list in
  `uTestContestUI.Test_OnlyARRLContestsOfferTheARRLLogPortal` is the exact set);
  `CabrilloOverlayCategories` (issue 122, 2026-11-18, base empty: the
  CATEGORY-OVERLAY values a sponsor names, in its spelling -- the Cabrillo
  summary offers the standard list, then those it lacks, then the blank,
  composed by `uCbrSum.OverlayValuesWith` and REFILLED at every opening of
  the session-long window, before `LoadValues`, from `ContestIdentity(Contest)`;
  the row stays closed. Louisiana is the first, `WIRES TB-WIRES POTA`;
  `OVERLAY_SPONSORS` in `uTestContestUI.Test_OnlyNamedContestsAddCabrilloOverlays`
  is the exact set. ~~The chosen overlay is stored in the GLOBAL header
  section~~ -- since 2026-11-19 (NY4I: Cabrillo header fields are "a contest
  item seeded by the station default") it is the contest-scoped
  `Settings.Contest.CategoryOverlay` (CATEGORY-OVERLAY), read by
  `uCbrSum.CabrilloTagText` and committed by the summary window through
  `ApplyContestEdit` + `LogStoreRecordContestStatement`, as the five
  categories are (Q61); `uCbrSum.OverlayChoiceToCommit` is the decision);
  `CabrilloStationCategories` (2026-11-20, the Florida QSO Party's
  Cabrillo specification, base empty: the sponsor's WHOLE CATEGORY-STATION
  set -- unlike the overlay a stated list REPLACES the standard one,
  `uCbrSum.StationValuesWith`, refilled at every opening by
  `FillStationItems`; Florida's `FIXED MOBILE EXPEDITION SCHOOL`;
  `STATION_SPONSORS` in
  `uTestContestUI.Test_OnlyNamedContestsStateCabrilloStationCategories` is
  the exact set. The value is the contest-scoped
  `Settings.Contest.CategoryStation` (CATEGORY-STATION), committed as the
  overlay is; UNLIKE THE OVERLAY the old global `_CATEGORY-STATION` is still
  READ as the station default when the setting holds none and nothing stated
  it -- `uCbrSum.StationCategoryInForce` -- which keeps the 13 D7 corpus refs'
  `CATEGORY-STATION: FIXED`);
  `ContestOpenNotice(aCurrentYear)` (issue 270, base `''`: what the operator
  is told when the contest opens -- asked once by
  `LOGDUPE.ShowContestOpenNotice` at the end of `SheetInitAndLoad`, shown
  as a notice and logged; the year is the engine's clock, display only; the
  Vermont QSO Party's stale club-station file is the first). **uNewContest names no contest**: `ClasslessPrompts`
  was deleted with RSGB 1.8's and UA4W's classes (2026-10-14). `uTestContestDisplay`
  pins every seam and compares every contest's prompts with a table
  generated from the dialog's own arms.
- **A CALL HISTORY FILE'S PREFILL IS THE CONTEST'S (2026-11-07, NY4I, for
  Sweepstakes).** `TContestBase.CallHistoryFields: TCallHistoryFields`
  (base `nil` = reads no file) names the N1MM call-history fields a row
  prefills, IN THE ORDER the remembered exchange is written -- the shape the
  log remembers for a worked station (`TContestARRLSSBase`: `[chfCK,
  chfSect]` -> `'72 SCV'`, as the log's `'18 UT'`); `CallHistorySiteName`
  (base `''` = no site file, no download) is supercheckhistory.com's file stem
  (`TContestARRLSSBase`: its `CabrilloName`, `ARRL-SS-CW` / `ARRL-SS-SSB`);
  `CallHistoryFileName` is DERIVED (`SiteName + '.txt'`, never overridden) and
  is the running's default file when CALL HISTORY FILENAME is blank, and what the
  Help-menu download (`uCallHistoryDownload`, manual only) writes (2026-11-08);
  `CallHistoryLegacyFileName` (`SSCW.txt` / `SSSSB.txt`, N1MM's names, NY4I
  2026-11-07) is the fallback `LoadCallHistoryFile` reads when the blank-named
  default file is absent. A site stem needs `CallHistoryFields` (a pinned
  invariant). The engine spells none. A row missing a named field is skipped; the file's
  `!!Order!!` decides the columns (the two SS layouts in circulation differ).
  The reader is the leaf
  `src/uCallHistory.pas`; the loader `LOGDUPE.LoadCallHistoryFile` runs in
  `SheetInitAndLoad` after INITIAL.EX and before the log, gated by USE CALL
  HISTORY FILE, and stores each row with `TCallsignsList.AddCallHistoryExchange`
  (never over an existing exchange; marked `FromCallHistoryFile`, which any
  `AddIniitialExchange` -- a logged QSO -- clears). **A spot comment outranks a
  history-FILE entry** in `LogEdit.SpotSectionHint` and the needs strip, while
  the log's and INITIAL.EX's still outrank the comment (NY4I: the file may be
  stale). FLUSH INITIAL EX skips history entries. Pinned by
  `uTestCallHistory` (registry walk: only the two SS runnings answer),
  `uTestSpotCommentMultiplier.Test_Hint_ACommentOutranksTheCallHistoryFile`
  and `uTestStatusAndNotice.Test_ACallHistoryEntryPrefillsAndYieldsToASpot`.
- **A CONTEST STATES WHEN IT RUNS: `GetSchedule` / `Schedule` (Q99 step A,
  2026-11-16).** One string of UTC operating periods (`;`-separated clauses)
  or the deliberate `'unscheduled'`; the base's `''` is NOT YET STATED. Data
  only -- the class never reads a clock, parses or refuses a QSO by it. The
  grammar and resolver are the leaf `src/uContestSchedule.pas` over the leaf
  `src/uContestDates.pas` (calendar arithmetic, `SortContestDates`); the key is
  "now" for a running period, else the next period start (a QSO party's
  overnight gap keys on the Sunday start), else undated -- an ISO-date list
  runs out and never repeats. `+Nd` is the day after the SAME anchor (Florida
  2029: the 29th, not the 4th Sunday the 22nd). There is no `-Nd`; the
  readable form is `the <Weekday> before <anchor>` (NY4I, 2026-11-17): the
  last such weekday STRICTLY before the anchor's date -- ARRL-160 (Friday
  before the first full weekend of December, Nov 30 in 2029), Hawaii
  (Saturday before the 4th Sunday of August). State
  it on the LEAF class (`uTestContestSchedule` asks `ClassStatesItself`).
  `SCHEDULE_NOT_YET_STATED` there is the ratchet, only ever down; the intake
  is `docs/CONTEST_SCHEDULES.csv` (never read at run time) with its
  sponsor-style `until` cells converted by
  `tools/contest-schedules/convert_sponsor_times.py`; a candidate row's class
  comment says CANDIDATE. **Step B, the New Contest list's "Upcoming
  contests first" box, READS IT** (`uContestChoices.SoonestFirstOrder`). A
  string that does not parse there is listed undated and logged as a Warn
  naming the contest. So a typo in a class's `GetSchedule` is caught by
  `uTestContestSchedule`, not by the dialog.
- **THE 3830SCORES REPORT'S TABLE IS THE CONTEST'S (2026-10-25, design
  §8.2x).** Rows = the bands `UsesBand` credits (the form's standard 160-10/6/2
  always, any other credited band only with QSOs -- so WARC QSOs now reach the
  Total row); columns = `Summary3830` (`Get3830Summary`, protected virtual):
  `T3830MultiplierColumn = (Title, Kinds)` over the sheet's kinds, built with
  `Make3830Column`. A DISPLAY LAYOUT, so the base has a default (one `Mults`
  column, every kind -- the old report byte for byte); NOT the bands, which
  stay the ratcheted rule. CQ WW CW/SSB (on `TContestCQWWBase`): Zones,
  Countries; CQ WW RTTY: State/Prov, DX, Zones -- both read from 3830 claimed
  posts. Values are `mo.MTotals` and `RawQSOTotals`, never recounted; the leaf
  renderer is `src/uScore3830Report.pas` (`Render3830Summary`), PostUnit keeps
  the header block and asks `ActiveContest` (identity for "no contest").
  `uTestScore3830Report` pins it; no oracle writes this report. State a
  contest's columns only from its actual 3830 form.
- **A PARTY'S HOST MAY BE SEVERAL PROVINCES (2026-11-18, the Canadian
  Prairies, #117; Atlantic Canada #116 the same day).** `HostState` is ADIF codes,
  blank-separated (`'AB SK MB'`); the county file names each county's own
  code with `>`, and the party base writes ADIF STATE from it
  (`HostSpansSeveralStates` -> `CountyFileHostState`, a lazily read map on
  the object, main thread only, through `uDomFileKeys.DomFileOnDiskKeyTargets`
  and `uAppPaths.ShippedDomFilePath`). A single-code host is unchanged. The
  multi-code parties are a closed list (`uTestContestFactory`
  `MULTI_PROVINCE_PARTIES`); `Test_EveryPartyAndOnlyAPartyWritesAState`
  checks every county of every party's file. A test exporting through the
  identity sets `uAppPaths.ShippedDomDirOverride` (the test exe's working
  directory has no `dom`). ADDING_A_CONTEST A3 "A multi-province host".
  **A MULTIPLIER PER BAND AND MODE BESIDE ONES PER BAND needs no seam**
  (Atlantic Canada, #116): the sheet has ONE mode scope
  (`Settings.Mult.ByMode`), so the in-region Atlantic province rides the
  PREFIX sheet with the mode in its key (`NSCW`/`NSPH`, set in the class's
  `ParseReceivedExchange` -- South Dakota's pattern) and the class's
  `CountsAsMultiplier` refuses it on the domestic sheet. The county-line
  leg builder (`MainUnit.TEntryLegs.BuildLeg`, the drain until issue 348) re-asks `SetPrefix` after
  the QTH lookup since then, so each leg carries its own key.
- **THE VERMONT QSO PARTY (2026-11-10, #130) SETTLED FOUR THINGS A PARTY
  WILL MEET AGAIN.** (1) A DX station that sends RST ONLY needs no override:
  under `RSTDomesticOrDXQTHExchange` a DX call typed `599` is taken with its
  RST (an EMPTY exchange is refused, pinned), and
  `CabrilloReceivedRSTQTHOrDXQTH` writes the DXCC key as the received
  column. A DX ENTRANT'S MY STATE MAY BE `DX`, not empty: the New Contest
  host-area row takes `DX` (`uNewContestHostArea.HOST_AREA_DX`) and
  `SentMyState` passes it on, so `LocationOrOwnCountry` sends "DX" for it.
  Vermont tests both spellings (`StatesNoLocation`); North Dakota,
  Oklahoma, New Mexico and Ontario do not -- suspected, not changed. (2) The first x1.5 power
  multiplier on a final score: `VermontScoreWithPower`, `Round` -- half to
  EVEN, the Stew Perry/Makrothen convention -- pinned at 13.5 and 22.5.
  (3) "A WSJT-X QSO earns no county multiplier" IS representable: the
  class's `CountsAsMultiplier` on `aQso.ExtMode` (stored as `submode`, set by
  ADIF import). Grid multipliers and "WARC for FT8 only" are not
  (`UsesBand` cannot see the mode). (4) ONE QSO CARRIES ONE DOMESTIC KEY --
  "a county also earns its state" (DXLog's MULT1 + MULT2) cannot be built
  without a new seam; do not fake it with bonus points or the prefix kind.
  (#317 built that seam since, and it carries ONE extra key a QSO.) (5) THE
  CLUB-STATION MULTIPLIER (issue 270, 2026-11-19) is on the PREFIX sheet,
  keyed on the club call (CW Open's whole-call key), because #317's one key
  is already the county's VT and an in-state first club QSO earns three.
  The list is the OPERATOR'S FILE `vtqp_club_stations.txt`
  (`uAppPaths.PreferredDataFilePath`; `YEAR 2027` header, one call a line,
  `ParseVermontClubStations`), credited only to a QSO made in the file's
  year; a stale or yearless file is `ContestOpenNotice`'s. Read lazily on
  the object, main thread only; `UseClubStationLines` is the seam a test
  hands lines to.
- **NEW HAMPSHIRE (2026-11-10, #112)**: a multiplier scope that differs by
  entrant goes in `DescribeSession`, stating `MultByBand` BOTH ways (Arizona's
  pattern), and the real-engine test must apply that answer per half (guide
  A5) -- the identity's flag alone stays green on a broken in-state rule.
- **The UI itself asks the contest** (M9b, 2026-10-02, design §8.2n).
  `IsActive` (base True; SA Sprint and Locust False, on NY4I's word only --
  `uTestContestUI.INACTIVE_CONTESTS` is the ratchet) places a contest in the
  New Contest drop-down, which shows `DisplayName` (`uContestChoices`;
  a shared display name gets its token in brackets -- no pair shares one
  since WRTC became "World Radiosport Team Championship", Q58, 2026-10-16;
  the ratchet holds the count at zero). General QSO, a log, says False to `ShowsContestStatus`, 0 to
  `MaximumContestDates` (base 10) and True to `BandStepIncludesWARC`; the FOC
  Marathon says True to `PowerFieldIsFOCNumber`; WAG answers
  `CallEntryFrequencyWarning(aFreqKHz)` from its seven exclusive windows.
  **CATEGORY-POWER is ONE value** (design 7.6): the summary window writes
  `Settings.Contest.CategoryPower`, so `TStationContext.MyPower` is what the
  Cabrillo header declares, and a change with QSOs logged rescores. **The
  off-time minimum is the contest's** (Q60, 2026-10-15):
  `MinimumOffTimeMinutes`, base 30, 60 on `TContestCQWWBase` and
  `TContestCQWWRTTY` (IARU HF is 30). `PostUnit.CalculateTotals` -- the
  summary sheet's OPERATING TIME, the CT1BOH window's band times -- asks it
  through `GapIsOperatingTime`; it no longer reads `CONTEST NAME`. MainUnit's
  60-for-IARU copy was a dead store (its reader commented out since D7) and
  is deleted; the on-air counter has no break rule. `uTestContestUI` pins
  it; no oracle sees the summary sheet.
- **The station's facts arrive in `TStationContext`**, filled by
  `uContestFactory.CurrentStation`. The entrant's `CATEGORY-POWER` is
  `MyPower`, read from `Settings.Contest.CategoryPower`; the New Contest dialog
  and (since M9b) the Cabrillo summary window write that setting. A field is added when the first contest needs it
  (M4 added `MyState` and `ContestTitle`). **Every station fact in it is
  RESOLVED** (design 7.12, 2026-10-13): the contest's override, stated at New
  Contest, in its `.cfg` or in its log, else the station's value
  (`Settings.My.Resolved<X>`). **`MyZone` / `MyZoneValid` / `MyZoneText` are
  MY ZONE resolved -- and an UNSTATED MY ZONE is derived in the CONTEST'S zone
  mode**, so in an ITU-zone contest it is the ITU zone (measured 2026-10-14:
  K0AAA carries 7 in the UA4W Championship; IARU relies on it). 7.12 said
  "MY CQ ZONE" and was wrong for those contests. **A rule that needs the CQ
  zone asks the SERVICE `MyCQZone()`** -- the stated zone, else MY CALL's CQ
  zone; UA4W is its reader (Q69 asks whether MY ZONE should always be CQ).
  **A STATED MY ZONE IS CARRIED AS STATED (a CQ zone), so a rule that needs
  MY ITU ZONE asks `TContestBase.ScoringMyITUZone`** (issue #222,
  2026-11-05): the QSO's recorded `my_itu_zone` when the row captured its
  station, else the SERVICE `MyITUZone()` (`uContestFactory.SessionMyITUZone`
  -- the one answer the capture and the export's zone also use); 0 is unknown.
  IARU and the Black Sea Cup (issue #225, WA7BNM's "same ITU Zone") are its
  readers; OZCR-Z still compares `MyZone` ON PURPOSE -- no readable sponsor
  rule, pinned in `uTestITUZoneContests`, NY4I to rule. **A zone a contest
  SENDS is `TContestBase.SentZoneText(aStation)`** (issue #225): the ITU zone
  in a `zmzITUZones` contest, else `MyZoneText` -- the rule
  `uContestBase.ZoneTextSent`, shared with the export and FoundContest's
  default CW messages (`uContestFactory.SessionZoneTextSent`). A
  `CQExchangeDefault` that sends a zone calls it, never `MyZoneText`.
  **A rule may ASK the multiplier sheet read-only: `IsNewMultiplierAnywhere(aQso,
  nmkDomestic | nmkDX)`** (design 7.13) -- the sheet's all-band, both-mode row;
  RSGB 1.8 is its reader (7 for a new multiplier). Never a write, never the
  log. A class never reads `Settings` or CTY.DAT for a station fact.
  **It carries NO clock**:
  ~~`LogClockUTCHour`~~ is deleted (design Q21).
- **A time-of-day rule reads the QSO's recorded time, never the clock**
  (NY4I, 2026-10-01: *"the event source is the wall clock recorded in the
  QSO"*). `aQso.tSysTime` is UTC, stamped at logging or read from `TIME_ON`.
  Croatian (23:00-04:59, `uContestCroatian`) and UK/EI (01:00-04:59, a UK/EI
  station) are the two; their tests assert both sides of the window in one
  run and pin the edges. `MainUnit.ParametersOkay` stamps the live QSO
  BEFORE scoring it -- a scoring path that runs before the stamp would see a
  cleared record's hour 00, which is inside both windows.
- **A contest formats its own export, and every exporter asks it** (M4,
  2026-10-01). PostUnit's Cabrillo writer and ADIF tail and
  `uADIF.EmitADIFRecord` call `ContestIdentity(c)`; **`FormatsExchange` is
  gone.** Seams: `FormatCabrilloSentExchange` / `...Received...` (with a
  `TCabrilloQSOContext`), `FormatADIFSentExchange` (the class states `GetADIFSentExchange` -- a
  `uADIFExchange` helper since M11 S9b), `EmitADIFContestFields`,
  `ADIFPowerTag`, `WritesADIFContestId`, `CabrilloQSOLineFormat`. **Both exports are the
  classes' own since M11 S9b/S9c**: a class states `GetADIFSentExchange` and
  `GetCabrilloSentExchange` / `GetCabrilloReceivedExchange` by calling a named
  helper (`uADIFExchange`, `uCabrilloExchange`); the base prints the error
  marker. A contest whose columns move with the entrant (nine) tests the
  station itself, as `DescribeSession` does. **The helpers name no contest and
  must not start to**: a contest's export rule is an override on its class, and
  one that only changes an input copies the context and calls the helper
  itself (there is no `inherited` to call).
  No contest is named in PostUnit's ADIF tail any more (ARRL 160 left at
  M7b, POTA with its class); the `'TRC'`/`'PGA'` tests (no contest named)
  are `uCabrilloExchange`'s and `uADIFExchange`'s. **The his-QTH decision
  is `PostUnit.CabrilloReceivedQTH`** (issue #109, 2026-10-26), and since
  2026-11-20 it NAMES NO CONTEST: its `'LABRE'` / `'EURASIA'` name tests and
  `Contest in [CUPRFCW, CUPRFSSB]` are deleted -- LABRE states LITERAL
  DOMESTIC QTH in its `DescribeSession`, the RF Cups always did, and EURASIA
  is European VHF under another CONTEST NAME, which counts no domestic
  multiplier (a `DescribeSession` cannot see that name: FoundContest sets
  `Settings.Contest.Name := CMD` before it runs). Pinned by
  `uTestCabrilloReceivedQTH`. With LITERAL
  DOMESTIC QTH -- the SESSION setting `Settings.Contest.LiteralDomesticQth`,
  which FCONTEST fills from the classes' `DescribeSession` and the operator
  may state, and which the log window reads too -- it writes `QTHString`, else
  the resolved `DomesticQTH` (D7's rule). It read LOGDOM's global, unwritten
  since 2026-09-12, so NAQP exported "vE3" for ON and "Ct" for CT; that global
  is deleted. **`EmitADIFExchangeFields`**
  (POTA's class) is the tail's exchange block -- base: the `SRX_STRING` from
  `FormatADIFReceivedExchange`; override it only to write tags BESIDE it.
- **A contest interprets its own ADIF import** (M5a, 2026-10-01).
  `TContestBase.ApplyADIFImport(aTemps, aSession, var aExch)` is the other
  half of `EmitADIFContestFields`: the generic importer captures, the contest
  named by `CONTEST_ID` interprets once the whole record is read, so tag order
  cannot matter. The base's default is the old classless `else` (grid kinds,
  then the domestic QTH, then raw SRX_STRING), keyed on the session data
  passed in -- never a global. An override states its contest's rule and calls
  `inherited` only for the cases it does not handle. Class arms that named
  several contests were copied into each (design 1.4), and the Field Days
  carry N1MM's class tag (standard `CLASS` wins, N1MM fills a gap). Thirteen
  contests gained classes for this: CQ 160 CW/SSB, UBA CW/SSB, the ARRL RTTY
  Roundup, CWOPS, NAQP CW/SSB/RTTY, the NCCC Sprint, Ukrainian DX, OK/OM DX and
  LZ DX. `MainUnit.ApplyClasslessADIFImport` is DELETED: ARRL 160's arm
  moved at M7b and POTA's, its last, with POTA's class (2026-10-13).
  **AN IMPORT NEVER READS THE RAW SRX_STRING (issues 275 and 328,
  2026-11-15)**: TR4W's own export writes the received RST first (`599 CT`,
  or just `599`), so a copy of `aTemps.SRX_String` stores the RST as the QTH.
  The received text is `uContestBase.ImportedReceivedText` (the QTH tag, else
  SRX_STRING less the RST), and a domestic QTH goes through
  `ImportDomesticQTH` for an EXPLICIT field (QTH tag, ARRL_SECT): resolved
  when the lookup knows it, else KEPT AS WRITTEN -- an explicit ADIF field is
  authoritative (review M5 follow-up, 2026-11-16). A QTH DERIVED from
  SRX_STRING goes through `ImportDerivedDomesticQTH`, **TYPED ENTRY'S WORD
  RULE (review M5)**: the words that are not all digits, asked whole, else
  the FIRST of them the lookup (`FoundDomesticQTH`, the probe typed entry's
  word split asks) knows; a text it knows no word of stores NO `DomesticQTH`
  (it stored `8`, `123`, `FN31`, `59 DARC`). No lookup
  (`NeutralADIFImportSession`) keeps the text as written in both. The
  received text stays in `ExchString`. A party test that exports a column
  asks `uTestQSOPartyRules.PartyReceivedCabrilloColumn` (the writer's own
  HisQTH), never a hand-set `HisQTH`. Where the other words are numbers (RST, zone, serial),
  `ImportDomesticQTHWords` drops them first -- CQ 160, UBA, LZ, OK/OM DX and
  Ukrainian DX call it; WAG reads `ImportedReceivedText`; ARRL 160 hands
  over the whole remainder. Note `ImportedReceivedText`'s strip is exact
  (`IntToStr(RSTReceived)`), so `59 CT` on a 599 record keeps its `59`.
  **The base's own domestic arm calls `ImportDomesticQTHWords` too when
  there is no QTH tag (issue 329)** -- it took the ALPHA PREFIX of the raw
  SRX_STRING (`'599 CT'` gave `''`, `'MO12'` gave `MO`). Its QTH-tag branch
  is deliberately NOT the helper: a QTH tag of digits (`45`) is kept.
  `DupeKeyQualifier` reads `DomesticQTH`, else `QTHString`, so an unknown
  QTH TAG still enters a party's dupe key (unchanged, by decision).
  Still open (NY4I's decision): NAQP CW/SSB/RTTY and the NCCC Sprint copy the
  STATE tag into DomesticQTH unresolved.
- **POTA is a class** (NY4I, 2026-10-13, design Q6 and §8.2o: *"while it is
  not a contest per se, just like with GENERAL QSO, we treat it that way"*).
  `TContestPOTA` sits on `TContestBase`, writes no CONTEST_ID, and owns its
  set-up, import, export, prompts and park menu rows. Its three TRDOS helpers
  are LEAVES now -- `uPOTAReference` (`IsValidPOTAPark`,
  `ResolvePOTAParkFromADIF`, `LooksLikeAState`) and `uGridShape`
  (`LooksLikeGridSquare`; `GRID_CARRYING_EXCHANGES` was deleted at M11 S9e
  part 1 for the class answer `ExchangeTextMayHoldGridSquare`, which Tree's
  `LooksLikeAGrid` asks first). **The exchange SHAPE `RSTAndPOTAPark` and its parser stay
  LOGSTUFF's** until M10 (Q4): the base's `ParseReceivedExchange` hands the
  shape to it, and the n-fer -- one contact, one row per park in one QSO set,
  like a county line -- is the engine's queue and `TryLogContact`'s drain.
  The set-up's `InitOperatorNameSet` is a REQUEST,
  `TSessionDefaults.UseOperatorNameSet`, built last by the applier.
  `uTestContestPOTA` pins every branch the matrix's park-less QSOs cannot
  reach.
- **Creating a class to hold ONE rule means transcribing the whole contest**
  -- the row, AND its scoring arm, because a registered class is that
  contest's scorer from the moment it exists. M4 did that for eleven
  contests and M5a for thirteen; the matrix proved each by changing only
  `contest.class =`.
- ~~**The matrix is wall-clock dependent for CROATIAN**~~ -- **fixed
  2026-10-01** (design Q21): the matrix is independent of the time of day,
  verified by a run at 23:45 UTC. A CROATIAN record whose points all doubled
  is now a real regression.

The contest `.cfg` is **deliberately exempt** from the JSON destination: its
parameters go to the **contest SQLite database**, not to `settings/tr4w.json`.

## Oracles

```bash
bash tr4w/test/corpus/export-d12-corpus.sh        # 24 passed / 0 failed / 2 known-divergence, AND exit 0
bash tr4w/test/corpus/test-contest-factory.sh     # scoring, over the 13 corpus logs
bash tr4w/test/contest-matrix/run-contest-matrix.sh  # every ContestType: set-up, scoring, export
```

```powershell
.\tr4w\build\Build-Tests.ps1 -Run
```

**The exit code is part of the corpus result.** For two days all thirteen
`/EXPORT` runs died with an `EAccessViolation` while reporting `24 passed, 0
failed` — artifacts are written before the exit, so the byte comparison could not
see it.

Rebuild the app first, and confirm TR4W is not running (`Get-Process -Name tr4w`)
or every set reports a false FAIL. **Run the corpus, read the result, then
commit — never chain the run and `git commit` in one shell block.**

## A `.dom` name and its file agree in CASE (issue #141, 2026-10-27)

`IDAHO.DOM`, `IDAHO_CTY.DOM` and `IN7QPNE.dom` shipped while the classes named
`idaho`, `idaho_cty` and `in7qpne`. The PROGRAM was never broken: every reader
(`ShippedDomFilePath`, `DomFileInDirHasAlias`, `INCLUDE` following) goes through
`uAppPaths.ExistingDataFile`, which matches case off Windows. Three unit tests used a
bare `FileExists` and failed on Linux. The files are renamed to the classes' spelling
(`git mv` through a temp name: Windows is case-insensitive) and
`Lint-DomFileCase` gates it: a NEW class name or INCLUDE line must match its file
exactly. Ten legacy upper-case class names (`S48P14DC`, `EUDX`, `GC`, `JIDX`,
`NEQSOW1`, `NEQSO`, `OKOM`, `PACCPA`, `PACC`, `YOTA`) and the D7-era upper-case INCLUDE lines (a ceiling that only falls, `$INCLUDE_CEILING`) stay
pinned, because changing a class literal changes a value saved settings and tests pin.
**A new file in `target\dom` is lower case, always.**

## The Field Day class rule is a leaf's (2026-11-16)

`TContestBase.ValidateCountAndLetterClass` maps
`uStationFieldCheck.CheckCountAndLetterClass` (lifted line for line, so the
Preferences Station page can check MY FD CLASS with the same rule) to the
contest's message; the letters are `FIELD_DAY_CLASS_LETTERS` /
`WINTER_FIELD_DAY_CLASS_LETTERS` there. A new class-carrying contest passes
its own letters, as before.

## Coordinate with

`contest-scoring` (the engine side of the same seam) · `log-database` (contest
parameters land in SQLite) · `file-formats` (Cabrillo export is scored output).
