# Adding a contest to the TR4W contest factory

**Part A** is the procedure: follow it top to bottom and you have a contest.
**Part B** is the reference and the reasons, linked from the step that needs
them. You should not need Part B to finish Part A.

Worked examples, both in the tree and both registered by id:

| kind | class | its test |
|---|---|---|
| a single-state US QSO party | `tr4w/src/contestFactory/uContestGeorgiaQP.pas` | `tr4w/test/unit/uTestContestGeorgiaQP.pas` |
| any other contest | `tr4w/src/contestFactory/uContestURCDXRTTY.pas` | `tr4w/test/unit/uTestContestURCDXRTTY.pas` |

**Copy Georgia's CLASS, but not Georgia's TEST.** Georgia's test predates two
halves A5 asks for -- the shipped county file as the host-area table, and an
IN-STATE entrant through the real engine. The newer state parties, each a
by-id contest added from this guide, have both; copy the test of the one whose
exchange is closest to yours:

| party | commit | what it shows first |
|---|---|---|
| North Dakota | `5857a251` | a DX entrant sends its own country prefix; DXCC for points only |
| Oklahoma | `4f7e9892` | the same sent rule, lifted into the party base; a DX multiplier for in-state entrants only |
| New Mexico | `f2454a67` | a Cabrillo QTH column of "county, state/province or DX" while DX sends its entity; a bonus station for one year only |
| Ontario | `926617b3` | a Canadian host (no ADIF `CNTY`, its own New Contest prompt); a bonus keyed on the worked call |
| Quebec | `e751a346` | every QTH from the `.dom`, with ONE `Dx` entry as the DX multiplier; rules in two languages |

The design behind all of this is `docs/CONTEST_OWNERSHIP_DESIGN.md`: **a
contest class owns its rules outright**, through virtuals on `TContestBase`.
There are no shared strategy objects and no per-rule registries.

---

# Part A -- Adding a contest

**Before you start, three facts that are not negotiable:**

- **A new contest registers by its string id.** The `ContestType` enum is
  frozen (`Lint-FrozenContestNumbers`), so a new contest has **no `VC.pas`
  entry**. ([B5](#b5-ids-handles-and-names))
- **A new contest is its class plus its SQLite log. There is no `.cfg`.** A
  `.cfg` is only ever read, as an import of an old or external contest.
- **The sponsor's current rules are the source.** Where they are silent or
  contradict themselves, ask NY4I; record every decision you made in the
  class's header comment (Georgia's header lists each rule and where it
  landed).

## A1. Where the files go

| what | path | notes |
|---|---|---|
| the class | `tr4w/src/contestFactory/uContest<Name>.pas` | a QSO party is `uContest<State>QP`. One contest, one unit, one registration |
| its tests | `tr4w/test/unit/uTestContest<Name>.pas` | [A5](#a5-the-contests-tests) |
| its multiplier lists, if any | `tr4w/target/dom/<base>.dom` (and, for a state party, `<base>_cty.dom`) | lower-case names; format below. Shipped by the installer's wildcard -- no `full.nsi` edit |
| the sponsor's rules | `docs/ContestRules/<Contest>/` -- a QSO party under `docs/ContestRules/QSOParties/<State>/` | one folder per contest, **committed with the contest** -- shape below. A test may read it (Georgia's county table test does) |
| its frozen matrix record | `tr4w/test/contest-matrix/frozen/<ID>.matrix` | written by the freeze script in [A6](#a6-prove-it), never by hand. Blanks in the id become `_` |
| a generator, if a `.dom` is generated | `tools/<name>/` | only if the list will need regenerating (URC: `tools/urc/make_urc_dom.py`). Otherwise let a test check the `.dom` against the rules file, as Georgia does |

**Only the `.dom` files go under `tr4w/target/`.** The class, its tests and
everything else go where the table says. `tr4w/target/` is the program's run
folder, and git ignores almost all of it (`.gitignore`: `tr4w/target/*`, with
`dom/` and a few data files let back in): a unit saved there is never compiled and never committed,
and nothing reports it. NY4I's first new contest was saved there by mistake
(2026-10-26, the North Dakota QSO Party).

Then the edits to shared files listed in [A4](#a4-every-place-outside-the-class-that-names-the-contest).

### The rules folder

One folder per contest. It holds:

- **the sponsor's own document** -- the PDF, or whatever the sponsor
  publishes -- whenever it can be saved (`Oklahoma/okqp2026rules.pdf`,
  `Ontario/2026OQPRules.pdf`). Separate sponsor documents the class relies on
  go beside it (`Ontario/OQPMultList.pdf`, the multiplier list);
- **a text transcription**, `<Cabrillo name>-Rules.txt`, whose header gives
  the source URL, the fetch date, the Cabrillo name, the ADIF id and the
  WA7BNM number (with its `contestdetails.php?ref=` link), then the rules
  text. Where the sponsor gives a revision or "last modified" date, say so;
  where it states no Cabrillo `CONTEST:` value, say whose name you used.
  `Oklahoma/OK-QSO-PARTY-Rules.txt` is the model. This is the file a test and
  a reviewer read; a PDF alone (North Dakota's folder) cannot be grepped or
  diffed;
- **both languages where the sponsor publishes two**, each transcribed
  (`Quebec/QC-QSO-PARTY-Rules-EN.txt` and `-FR.txt`). If the two disagree
  and neither says which governs, that is a sponsor question (A4).

A table the class or its `.dom` is built from (counties, multipliers) may be
its own transcription beside the rules (`OK-QSO-PARTY-Counties.txt`).

### The `.dom` format

A `.dom` file maps what the operator TYPES to the MULTIPLIER it counts as.
The reader is `LOGDOM.EnumDOMFILE`:

```
Any line with no equals sign is ignored -- this is the only "comment" there is
INCLUDE FILE S50.DOM
CLB = CLB,^Colombia
APPL > Ga = APPL,^Appling
```

- **`KEY = alias,alias,^Name`** -- the multiplier is `KEY`; each alias is
  something the operator may type; `^Name` is the display name, not an alias.
- **`KEY > Mult = alias,^Name`** -- for an in-state entrant the multiplier is
  `Mult` (Georgia's 159 counties all count as `Ga`). For an out-of-state
  entrant `FCONTEST` sets `MultipliersIsCounties` and each `KEY` is its own
  multiplier.
- **Any line holding `=` is an entry, comments included.** There is no comment
  syntax, so a header line with an `=` in it becomes a bogus multiplier.
  Georgia's test pins "no `=` outside an entry" for `georgia.dom`.
- Aliases are matched exactly after upper-casing, are kept to ten characters,
  and **the first one added wins**. Order the file accordingly (Georgia's
  header explains why its county file is included first).
- **`INCLUDE FILE <name>`** reads another file from `target/dom`. Shared lists
  already exist -- `S50.DOM`, `DC.DOM`, `P13.DOM`, ... (`ls tr4w/target/dom`).
  Spell it exactly so, upper case: `INCLUDE S50.DOM` is NOT followed (the
  loader warns, `Lint-DomCoverage` fails it -- nc.dom lost every US state
  that way until #88 round 3). **Never edit a shared list for one contest**:
  if the sponsor leaves the host state out of an in-state entrant's states,
  list the 49 in the party's own file (missouri.dom, nc.dom) or refuse it in
  the class's `CountsAsMultiplier` with `DomesticMultiplierIsHostState`.
- **A rule that folds one QTH into another is an entry of your own, placed
  BEFORE the shared list** (the first alias added wins). "DC counts as
  Maryland" is `Dc > Md = DC` above `INCLUDE FILE S50.DOM`, with `DC.DOM` NOT
  included (`missouri.dom`, `oklahoma.dom`, `newmexico.dom`). Georgia
  includes `DC.DOM` because its sponsor counts DC on its own -- read your
  rules, not Georgia's file.
- **The shared lists carry aliases that collide.** `P13.DOM` includes
  `P12.DOM` and adds `LA` for Newfoundland and Labrador; `P12.DOM` gives
  Quebec `QUE`, `QU`, `PQ` and `VE2`, Manitoba `MAN`, Ontario `ONT`, and every
  province its call area (`VE1`..`VE9`, `VY0`..`VY2`). Before you include one,
  check each alias against your own codes and the other lists you include:
  - order decides a clash: North Dakota includes `S50.DOM` before `P13.DOM`
    so `LA` stays Louisiana; Ontario's file comes first so `MAN` is
    Manitoulin District, not Manitoba;
  - where order cannot fix it, do not include the list -- write the entries
    you need in your own file (Quebec: `QUE` is its Capitale-Nationale
    region, so `quebec.dom` writes the other provinces itself);
  - **a call-area alias in the session's table breaks the rover strip.** A
    `/suffix` the session's domestic table knows is taken as a rover's
    county and stripped from the call before the country lookup
    (`MainUnit.LocateCallStrippingRoverCounty`), so with `VE2` in the table
    `W2ABC/VE2` -- an American operating in Quebec -- loses its `/VE2`. This
    is why `quebec.dom` includes neither P12 nor P13.

**A state party ships two files, and their names are tied:**

| file | holds | loaded by |
|---|---|---|
| `<base>_cty.dom` | the counties -- `ABBR > St = ABBR,^Name` where the sponsor folds the counties into the state for an in-state entrant (Georgia), `ABBR = ABBR,^Name` where each county stands alone (`oklahoma_cty.dom`, `newmexico_cty.dom`) -- and **no `INCLUDE` line**: an out-of-state entrant's table must hold only counties, because the host-area rule reads it | an out-of-state entrant |
| `<base>.dom` | `INCLUDE FILE <base>_cty.dom`, then the states, DC and provinces the rules count (Georgia: `S50.DOM`, `DC.DOM`, `P13.DOM`) | an in-state entrant |

The county file's name **must** be the in-state name plus `_cty`
(`uTestContestFactory.Test_EveryQSOPartyNamesBothDomesticFiles`). Whether a
county maps to the state (`> Ga`) or stands alone is the sponsor's rule:
Nebraska's `nebraska_cty.dom` maps none, so an in-state Nebraska entrant
counts each county.

"No `INCLUDE`" means no line whose first word is `INCLUDE` -- that is all the
loader reads (`LogDom.DomLineIsAnUnfollowedInclude`). A header SENTENCE that
mentions the word ("No INCLUDE here: ...", as `oklahoma_cty.dom` says) is
harmless, because a line with no `=` is skipped. Pin it that way:
`Pos('INCLUDE', UpperCase(TrimLeft(line))) <> 1`, as Oklahoma's and later
parties' tests do -- North Dakota's looks for the word anywhere on the line,
which fails on such a header. `uTestContestParse.Test_EveryPartyCountyFileHoldsOnlyCounties`
walks the contest registry, so it checks your county file too -- but only for
`INCLUDE` lines, so your own test is still what checks the counties themselves.
(A real `INCLUDE FILE` line in a county file currently HANGS the unit suite
rather than failing it: issue #138.)

## A2. Choose the base class

| the contest is | inherit | copy |
|---|---|---|
| a single-state US QSO party: one host state, county multipliers, an out-of-state entrant works only the host state | `TContestStateQSOPartyBase` | `uContestGeorgiaQP` |
| anything else | `TContestBase` | `uContestURCDXRTTY` |
| another running of a family that already exists | that family's base: `TContestARRLDXBase`, `TContestARRLSSBase`, `TContestCQWWBase`, `TContestCQWPXBase`, `TContestNRAUBalticBase` | the sibling leaf |

Georgia's DX entrant sends the letters `DX`. If your sponsor has a DX
entrant send its own country prefix instead, or writes a different Cabrillo
QTH column for DX, the template is still Georgia: change the five exchange
statements to the row of [A3's exchange table](#which-exchange-helpers-go-together)
that matches your rules, and read the party named there for how.

**Copy the template, not the party that looks closest.** Every party class
carries its own sponsor's rules, AND whatever it inherited from the class it
was copied from -- Nebraska was copied from Delaware and keeps Delaware's
power multiplier, plus its own rare-grid bonus and DX multiplier. A new party
started from Nebraska therefore arrives with three rules its sponsor never
wrote, and each one compiles and scores without complaint (the North Dakota
QSO Party, 2026-10-26: its rules say "no power limitations" and "DXCC
countries for points only - no multipliers"). The templates above state the
fewest rules. Whatever you copy, read every override and delete each one your
own sponsor's rules do not state; then rewrite the header comment from your
rules, because a copied header describes the other contest and the next
reader will believe it.

**These are the only bases.** `Test_EveryClassSitsOnTheBaseOrAFamily` holds the
list closed: a new base fails it until it is added there, on evidence that its
members are one contest under one rule ([B1](#b1-design-rules)). Multi-state
parties (7QP, New England, IN7QPNE), NAQP and Locust are NOT on the party
base. A contest that merely resembles another starts as a **copy** it owns.

## A3. What the class overrides

Declare getters and `CalculateQSOPoints` in a **`protected`** section; the
public seams in `public`. Copy the declaration layout of your template.

### Required -- every contest

| override | how | what holds you to it |
|---|---|---|
| `initialization RegisterContestById('<ID>', TContest<Name>);` | the id is STORED DATA from that moment and is never given to another contest ([B5](#b5-ids-handles-and-names)) | `RegisterContestById` raises on a refused id (`uContestRegistry.ContestIdRefusal`) |
| `GetDisplayName`, `GetCabrilloName`, `GetADIFContestId` | literals, in the leaf class. The display name is the human name and must be unique; the Cabrillo name must be unique unless the sponsor says two events share it | `uTestContestDisplay.Test_EveryClassStatesItsIdentity`; `uTestContestUI` (no shared display name); `uTestContestIdentityPin.Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName` (no shared Cabrillo name); `uTestContestFactory.Test_EveryContestResolvesItsOwnADIFId` |
| `GetFriendlyName`, `GetWA7BNMId`, `GetQRZRUId`, `GetSubmissionEmail`, `GetDomesticFileName` | literals; `0` and `''` are statements too | none -- the base answers neutral (`0`, `''`), so an omission is silent. State every one |
| `GetExchangeKind`, `GetInitialExchangeKind` | the `ExchangeType` / `InitialExchangeType` member (table below) | none; the initial exchange and the matrix's `active.exchange` read them |
| `GetReceivedExchangeFields` | call the `uExchangeFields` helper for what the exchange carries. **This is also your ADIF export's received tags** | `uTestContestStatesItsRules` |
| `ParseReceivedExchangeFormat` | `Result := aParsers.Parse<Format>(aText, aExch);` | `uTestContestStatesItsRules` -- the base parses nothing |
| `GetADIFSentExchange` | call a `uADIFExchange` helper | `uTestContestStatesItsRules` -- the base raises |
| `GetCabrilloSentExchange`, `GetCabrilloReceivedExchange` | call `uCabrilloExchange` helpers | `uTestContestStatesItsRules` -- the base writes `ERROR EXCHANGE NOT HANDLED` |
| `GetFlags` | e.g. `[cfQSOByBand, cfQSOByMode, cfMultByMode, cfVHFBandsEnabled]`; `[]` if none applies. `cfVHFBandsEnabled` if 6 m or up is credited | `uTestContestStatesItsRules` |
| `CalculateQSOPoints` (protected) | the sponsor's points per QSO | `uTestContestStatesItsRules` -- the base scores 0 |
| `UsesBand` | `Result := aBand in [...]`, the rules' band list | **policy (NY4I), not yet gated**: the base still credits every band (Q98). Never omit it |
| `HasDXMultiplier`, `HasZoneMultiplier`, `HasPrefixMultiplier` | `False` unless the contest has one; if True, also the key/count virtuals ([B2](#b2-the-base-class-reference)). **A DX multiplier only some entrants have** (a party's in-state entrants): one private predicate (`CountsDXMultiplier`, reading `Station.InHostState`) answers `HasDXMultiplier`, `DXMultiplierKey` AND `CountryMode`, so they cannot disagree -- `uContestNebraskaQP`, `uContestOklahomaQP`. State `CountryMode` too: the base answers the CQ list, and a sponsor's "DXCC countries" is the ARRL list | the multiplier pin tests' registry walks |
| `ExchangeCarriesDomesticQTH` / `ExchangeCarriesZone` / `ExchangeCarriesGridSquare` | `True` for what the exchange carries | none; omitted, the readiness check does not ask for MY STATE / MY ZONE / MY GRID |
| `UsesDomesticFile` | `True` if the received QTH is looked up in your `.dom` (a state party inherits it) | `uTestDomesticMultiplier` (a domestic multiplier exactly where a QTH is read) |

### Required -- a state QSO party, in addition

| override | how | what holds you to it |
|---|---|---|
| `GetHostState` | the two-letter state | abstract on the party base: a party that omits it raises `EAbstractError` when asked |
| `GetInStateDomesticFileName` | **exactly** `begin Result := '<base>'; end;` -- one literal | `Lint-DomCoverage` reads this literal and fails if it cannot, or if `<base>.dom` or `<base>_cty.dom` is not in `target/dom` |
| `GetDomesticFileName` | `'<base>_cty'` | `Test_EveryQSOPartyNamesBothDomesticFiles` |
| `GetCountyLineCountiesMax` | the rules' maximum (Georgia: 2); `0` forbids county lines | none; the base allows any number |

**Inherited from `TContestStateQSOPartyBase` -- do not restate:**
`GetIsUSQSOParty`, `GetQSOPartyArea`, `UsesDomesticFile`, the rover rules
(`StripsRoverCountyFromCall`, `SplitsRoverCallOnExport`,
`DupeKeyIncludesReceivedQTH` -- a rover in a new county is a new QSO), ADIF
`STATE`/`CNTY` (`ADIFCountyState`, `ADIFWorkedStationState`,
`WritesADIFCounty`), `ValidateQTHCount` (enforces your county-line maximum),
and the host-area rule (`ParseReceivedExchange` refuses, `CreditsWorkedStation`
scores 0 -- [B1](#b1-design-rules)). `uTestContestGeorgiaQP.Test_GeorgiaIdentity`
pins what it inherits so a base change is seen.

**Except where the sponsor's codes are not ADIF's, or the host is not a US
state:**

- **`ADIFCountyState` may be overridden when your keys are not ADIF codes**,
  calling `inherited` for everything else. Quebec counts NF and LB as two
  multipliers, but ADIF's code for Newfoundland and Labrador is NL, so
  `TContestQuebecQP.ADIFCountyState` answers `NL` for those two keys and asks
  `inherited` for the rest. Know one inherited defect before you pin your
  ADIF: the base takes any key that is not two letters as a host county, so
  a DX station typed with a three-letter QTH (`KP4`, `UA9`) exports `STATE`
  as the HOST -- every party, found adding Ontario (open: issue 134). Pin today's answer with the issue named, or leave
  that case out; do not code around it in your class.
- **A Canadian host states `WritesADIFCounty` False** -- ADIF's `CNTY`
  enumeration defines nothing for Canada (British Columbia, Ontario,
  Quebec). The party base still writes `STATE`.
- **A host that is not a US state gives its own New Contest prompt.** The
  base's prompt for a party reads *"Enter your county if you are in ON
  state"*, and an entrant who answers `ON` instead of a county code is set up
  OUT of the host area, silently. Override `DescribeNewContestPrompts` with
  `aPrompts.AskFieldWithComment(<your string>, ncfMyState)` (Ontario,
  Quebec). The string is a new `resourcestring` in `tr4w/src/uAppStrings.pas`,
  named `S<Area><Thing>` (`SNewContestOntarioQPCountyOrLocation`) -- never a
  `TC_` constant. Its catalogue entry is harvested later, by
  `docs/I18N_TOOLS.md`'s "Only new RESOURCESTRINGS?" recipe; **never run
  `pas2po`** to pick it up (CLAUDE.md, "A converted window loses its
  translations"). Say in your hand-back that the harvest is not done.

**A helper two parties share goes on the party base, PROTECTED, and only a
class that calls it uses it** -- not a virtual the base wires in, because
whether it applies is each sponsor's rule. Lift it when the SECOND party
needs it, repoint the first in the same commit, and pin it in
`uTestContestStateQSOPartyBase` (an unregistered probe class). Today's:

| helper on `TContestStateQSOPartyBase` | what it is | callers |
|---|---|---|
| `LocationOrOwnCountry(location, country)`, `SentLocation(aMy)` | a station that states a location sends it; one that states none (a DX entrant) sends its own country | North Dakota, Oklahoma, New Mexico, Ontario |
| `DXCCKeyExceptUSACanadaHawaiiAlaska(counts, qso, key)`, `DXCCCountryMode(counts)` | the DX multiplier key -- every CTY country but K, VE, KH6, KL -- and the ARRL list it is counted on. The class passes WHO counts | Delaware, Florida, Nebraska, New Mexico, Oklahoma, Texas, Ontario |
| `ReportNoTableForYear(logger, year, table, rule, source)` | the once-per-year Error a year-table rule writes for a year it has no table for | Idaho, Nebraska, New Mexico |

The 7QP, New England and ARCI carry copies of the DX key but do not sit on
the party base (issue #136). A helper that is not about parties goes in a
leaf unit: `uCabrilloFormat.FormatCabrilloModeDigitalAsRY` (every digital
submode RY, called from a class's own `CabrilloModeString` -- Delaware, New
Mexico) and `uCabrilloExchange.CabrilloReceivedRSTDomesticQTHOrDX` (below).

**A rule keyed on the worked CALL must strip a rover's county itself.** The
engine strips a `/county` suffix only to look the call up; the LOGGED call
keeps it (`W1AW/5/BER`). Ontario's club-station points strip a suffix the
session's table knows (`Station.IsDomesticQTH`), as the engine does
(`TContestOntarioQP.IsClubStationCall`). A declared bonus station
(`GetBonusStations`, `BonusStationWorked`) matches the logged call EXACTLY,
so a suffixed bonus call is not paid -- New Mexico's header records it, and
the base fix is open with the South Carolina party (#111).

**Mobile and rover entrants are not built.** The entrant's station category
does not reach scoring, so a rule that depends on the ENTRANT being mobile
(a re-work from a new county, a multiplier sheet per county activated, a
per-county bonus) cannot be stated; record it in your header as NOT BUILT
and link issue #133 (Ontario's and Quebec's headers do).

### State only if the contest differs from the base

| override | base answer | example |
|---|---|---|
| `CountsAsMultiplier(aQso, aKind)` | every QSO counts | URC (MMS is no multiplier) |
| `ParseReceivedExchange` (call `inherited`) | the plain parse in your format | URC (reads `MMS`), the ARRL VHF runnings (`RequireReceivedGrid`) |
| `CQExchangeDefault(aStation)` | `''` | Georgia (`' 5NN ' + MyState`, or `DX`) |
| `DescribeSession(aStation, aSession)` | states nothing | URC (starts in Digital) |
| `WriteDefaultExchangeMessages(aMessages)` | writes none | URC |
| `DescribeNewContestPrompts(aPrompts)` | asks a US state party for county/state | URC (MY STATE is the territory code) |
| `CombineWithMultipliers`, `BonusPoints`, `GetBonusStations` | points x sum of multipliers, no bonus | `uContestWinterFieldDay`, `uContestMissouriQP` |
| `ApplyADIFImport`, `EmitADIFContestFields`, `EmitADIFExchangeFields` | the generic import / no extra tags | `uContestARRLFieldDay`, POTA |
| `GetRequiresCabrilloLocation`, `CabrilloQSOLineFormat`, `CabrilloModeString` | not required / the standard `QSO:` line / CW, PH, ... | Arktika Spring's line |
| `MarksDupes`, `GetIsActive`, `MinimumOffTimeMinutes` | True / True / 30 | `uContestInternetSprint`; `uContestSASprint`; `uContestCQWWBase` (60) |
| `RunsInMode(aMode)` | every mode -- an IDENTITY question for two contests sharing one ADIF id | the RoPoCo runnings |

Everything else in [B2](#b2-the-base-class-reference). **Do not** repeat the
band rule or the host-area rule in `CalculateQSOPoints` or
`CountsAsMultiplier` -- `ScoreQSO` and `SetMultFlags` ask them first.

### State your bands AND your modes -- `UsesBand` and `UsesMode`

There is no inherited default (Q98 S1, 2026-10-22; NY4I: *"I would feel
better if contest classes just explicitly listed the bands they allow"*), and
`uTestContestStatesItsRules.Test_EveryContestStatesItsBandsAndModes` fails a
new contest that does not state both -- the two `..._NOT_YET_STATED` sets hold
only the contests that predate the rule. A QSO off your bands or modes is an
**automatic X-QSO** (NY4I: *"automatic X-QSO is OK"*): logged, 0 points, no
multiplier, no dupe, out of every total, `X-QSO:` in the Cabrillo and
`APP_TR4W_CLAIMEDQSO` 0 in the ADIF -- derived each time, never stored, so the
class says nothing else about it. **Do not** also give such a QSO 0 in
`CalculateQSOPoints` or refuse it in `CountsAsMultiplier`.

In `UsesMode`, `eNoMode` and `eData` mean "some submode of aMode": answer True
for them if you credit any submode, and test the submode only to EXCLUDE one
you name. Both answers are identity facts -- never ask the station
(`Test_BandsAndModesAreAnIdentityFact`). A family base may state the bands its
whole family shares (CQ WW does); `TContestStateQSOPartyBase` never does.
`RunsInMode` is NOT this rule. Design doc 8.2v.

### Your 3830scores report -- `Get3830Summary`

The operator fills in the contest's form on 3830scores.com from
`3830Score.txt` (File > Reports > 3830 Score). The report has one row per
band, then the QSO columns (`CW Qs`, `Ph Qs`, `Dig Qs`), then the multiplier
columns. The class decides only the multiplier columns. Everything else comes
from what you have already stated:

| part of the report | where it comes from | you write |
|---|---|---|
| the band rows | your `UsesBand` bands that have QSOs | nothing more -- never a second band list |
| the QSO columns | the modes the log has QSOs in | nothing |
| the multiplier columns | `Get3830Summary` | an override **only if the form breaks the multipliers out** |

**First, look at the contest's real 3830 form.** On 3830scores.com, open
**Contest Summaries**, then the contest (a past running if the next is not
yet listed), then **Score Breakdowns**. That table's heading (`Band  QSOs
Zones  Countries` for CQ WW) names the columns, in order. A single
claimed-score post shows the same heading in its band table. Use the form, not a guess
or another contest's form: the operator copies the report across one column at
a time.

**If the form has one multiplier column, state nothing.** The base gives one
`Mults` column that adds every multiplier kind the contest has.

**If the form breaks them out, override `Get3830Summary` (protected).** Add one
`Make3830Column(<heading>, [<kinds>])` per form column, in the form's order,
with the heading spelled as the form spells it. The kinds are
`RemainingMultiplierType`: `rmDomestic` (state, province, county, section),
`rmDX` (country), `rmZone` and `rmPrefix`. CQ WW (`uContestCQWWBase`):

```pascal
function TContestCQWWBase.Get3830Summary: T3830SummaryLayout;
begin
   SetLength(Result.MultiplierColumns, 2);
   Result.MultiplierColumns[0] := Make3830Column('Zones', [rmZone]);
   Result.MultiplierColumns[1] := Make3830Column('Countries', [rmDX]);
end;
```

CQ WW RTTY (`uContestCQWWRTTY`) has three: `State/Prov` `[rmDomestic]`, `DX`
`[rmDX]`, then `Zones` `[rmZone]`.

**What `uTestScore3830Report.Test_EveryContestStatesAWellFormedLayout` fails,
for every registered contest:**
- no columns at all;
- a blank heading, or one that spans two lines;
- a column that adds no kind, or names `rmNoRemMultDisplay`;
- one kind in two columns (it would be counted twice).

A column may add two kinds together when the form does (`Mults` is all of
them). Name only kinds the contest actually has; a kind it never counts prints
a column of zeros.

**Pin your own layout** (A5): the column count, each heading and each column's
kinds, in order. Copy `Test_CQWWLayoutIsZonesThenCountries`, making the
contest from its handle rather than `ContestIdentity(<enum>)` if it is a by-id
contest. No automated test writes `3830Score.txt` from a real log, so add a
`docs/BENCH_QUEUE.md` item: export the report from a real log and check it
against the form. Design doc 8.2x.

### Which exchange helpers go together

The five exchange statements must agree. These sets are in use:

| exchange | `GetExchangeKind` | `GetReceivedExchangeFields` | `ParseReceivedExchangeFormat` | `GetADIFSentExchange` | Cabrillo sent / received | e.g. |
|---|---|---|---|---|---|---|
| RST + county/state/province, or DX -- **a DX entrant sends "DX"** | `RSTDomesticOrDXQTHExchange` | `ExchangeFieldsRSTQTH` | `ParseRSTDomesticOrDXQTH` | `ADIFSentRSTState` | `CabrilloSentRSTStateOrDX` / `CabrilloReceivedRSTQTHDX` | Georgia |
| same, but a DX station's received QTH is written as sent | as above | as above | as above | as above | `CabrilloSentRSTState` / `CabrilloReceivedRSTQTHOrDXQTH` | Nebraska |
| same, and **a DX entrant sends its own country prefix**, not "DX" (a state party) | as above | as above | as above | `ADIFSentRSTState(SentLocation(aMy), aQso)` | `CabrilloSentRSTState(SentLocation(aMy), ...)` / `CabrilloReceivedRSTQTHOrDXQTH`; `CQExchangeDefault` is `' 5NN ' + LocationOrOwnCountry(aStation.MyState, aStation.MyCountry)` -- both helpers are protected on `TContestStateQSOPartyBase` | North Dakota, Oklahoma |
| same, but a DX entrant sends its entity ON THE AIR while the Cabrillo QTH column is only "county, state/province or DX" | as above | as above | as above | `ADIFSentRSTState(SentLocation(aMy), aQso)` (STX_STRING is what was transmitted) | `CabrilloSentRSTStateOrDX` / `CabrilloReceivedRSTDomesticQTHOrDX` (DX whenever the record holds no domestic QTH -- `CabrilloReceivedRSTQTHDX` writes a typed `599 LY` as an empty column); `CQExchangeDefault` with `LocationOrOwnCountry` | New Mexico |
| RST + county/state/province or `DX`, where **"DX" is ONE multiplier** (a `Dx = DX` entry in the in-state `.dom`), a DX entrant sends "DX" | `RSTDomesticQTHExchange` -- every QTH, `DX` included, is looked up in the `.dom` | `ExchangeFieldsRSTQTH` | `ParseRSTDomesticQTH` | `ADIFSentRSTState` | `CabrilloSentRSTStateOrDX` / `CabrilloReceivedRSTQTHDX`; `HasDXMultiplier` False (the multiplier is the domestic `Dx` entry) | Quebec, as North Carolina and Missouri |
| RST + a code from your `.dom` only | `RSTDomesticQTHExchange` | `ExchangeFieldsRSTQTH` | `ParseRSTDomesticQTH` | `ADIFSentRSTState` | `CabrilloSentRSTState` / `CabrilloReceivedRSTQTH` | URC |

**Read these before you pick a row:**

- **A `Dx` entry counts only under `RSTDomesticQTHExchange`.** Under
  `RSTDomesticOrDXQTHExchange` a DX call goes to the free-text DX branch,
  which never looks the text up, so a `Dx` line in the `.dom` is never
  reached and the DX multiplier silently never counts. And because the
  multiplier is the TYPED `DX`, a DX QSO logged with no QTH earns none (as
  in North Carolina and Missouri).
- **Under `RSTDomesticQTHExchange` every call, US or DX, goes through the
  domestic parser**, so an out-of-area entrant's refusals all read as an
  improper domestic QTH (A5's traps).
- **`CabrilloReceivedRSTQTHDX` writes `DX` only when NOTHING was typed** --
  it tests `QTHString`. A DX station logged `599 DL` gets an EMPTY QTH
  column. If your rules want `DX` in that column whatever was typed, use
  `CabrilloReceivedRSTDomesticQTHOrDX` (`DX` whenever the record holds no
  domestic QTH -- New Mexico). Georgia's row carries this latent defect.
- **`ADIFSentRSTState` writes MY STATE as it is -- empty for a DX entrant**,
  while `CabrilloSentRSTStateOrDX` writes `DX`. So the "sends DX" rows give a
  DX entrant an ADIF `STX_STRING` with no location and a Cabrillo line with
  `DX`. Georgia, North Carolina, Missouri and Quebec all do this today; know
  it before you copy it, and pin what your class writes.
| RST + serial | `RSTQSONumberExchange` | `ExchangeFieldsRSTQSONumber` | `ParseRSTQSONumber` | `ADIFSentRSTQSONumber` | `CabrilloSentRSTQSONumber` / `CabrilloReceivedRSTQSONumber` | `uContestBaltic` |
| RST + zone | `RSTZoneExchange` | `ExchangeFieldsRSTZone` | `ParseRSTZone` | `ADIFSentRSTZone` | `CabrilloSentRSTZone` / `CabrilloReceivedRSTZone` | `uContestJIDXCW`, CQ WW |
| name + state | `NameAndDomesticOrDXQTHExchange` | `ExchangeFieldsNameQTH` | `ParseNameAndDomesticOrDXQTH` | `ADIFSentNameState` | `CabrilloSentNameState` / `CabrilloReceivedNameQTH` | `uContestNAQPCW`, `uContestCWOps` |
| RST and/or grid (VHF) | `RSTAndOrGridExchange` | `ExchangeFieldsRSTQTH` | `ParseRSTAndOrGrid` | `ADIFSentRSTGrid` | `CabrilloSentRSTGrid` / `CabrilloReceivedRSTQTH` | `uContestARRLVHFJan` |

For any other shape: list the helpers (`rg "^function (ADIFSent|Cabrillo(Sent|Received))" tr4w/src/uADIFExchange.pas tr4w/src/uCabrilloExchange.pas`,
`rg "^function ExchangeFields" tr4w/src/contestFactory/uExchangeFields.pas`,
the `Parse...` methods of `uContestBase.TExchangeParsers`), read the bodies,
and test the columns against the sponsor's own Cabrillo example line, as
Georgia's `Test_GeorgiaCabrilloLineIsTheRulesExample` does. If no helper fits,
format in your override; never add a contest's name to a helper.

## A4. Every place outside the class that names the contest

### Required

| file | the edit | if it is missing |
|---|---|---|
| `tr4w/tr4w.lpr` | `uContest<Name> in 'src\contestFactory\uContest<Name>.pas',` | the application has no such contest; `Lint-ContestUnitsLinked` fails the build |
| `tr4w/test/unit/tr4w_unit_tests.lpr` | the contest unit (`in '..\..\src\contestFactory\...'`) | `Lint-ContestUnitsLinked` fails; no registry walk sees it |
| same file | the test unit (`uTestContest<Name> in 'uTestContest<Name>.pas'`) **and** `RegisterSuite(TContest<Name>Tests.Create('Contest<Name>'));` | **nothing fails** -- your tests just never run. Check the suite's name appears in the test output -- **not** `Build-Tests.ps1 -Run`'s, which prints only the `PASSED:` total and the failures. Run the binary it built, from its own folder (`cd tr4w\test\unit`, then `.\tr4w_unit_tests_fpc.exe`), and look for `--- Contest<Name> ---` and your `[PASS]` lines |
| `tr4w/target/dom/*.dom` | the files your `GetDomesticFileName` / `GetInStateDomesticFileName` / `DescribeSession` name, and every file they `INCLUDE` | `Lint-DomCoverage` (a party); `Test_EveryDomesticFileAContestCanLoadExists` (every contest); at run time an empty table refuses every QTH |
| `docs/ContestRules/...` | the sponsor's rules | a test that reads them fails (file not found) |
| `tr4w/test/contest-matrix/frozen/<ID>.matrix` | written by the freeze in A6 | `run-contest-matrix.sh` fails closed: "a fresh record never frozen" |

**Never** add it to `tr4w/tr4wserver/tr4wserver.lpr` (`Lint-ContestUnitsLinked`
fails). **No** `VC.pas` line, `full.nsi` line, pin-table row, count, `case` arm
or exception list. A cross-contest test that seems to need your contest named
derives the answer from the class instead: `uTestContestExport.
Test_EveryPartyAndOnlyAPartyWritesAState` once named British Columbia as the
party that writes no `CNTY`, and since Ontario it judges every party by its
host (`IsADIFPrimarySubdivision('VE', HostState)`). If you find another such
name, make that test derive it, in your commit.

### Only when it applies

| file | when |
|---|---|
| `tr4w/src/uContestNames.pas` `LEGACY_CONTEST_NAMES` | you RENAME a contest's id -- the old id becomes a permanent read alias ([B5](#b5-ids-handles-and-names)) |
| `docs/BENCH_QUEUE.md` | recommended: typed entry on screen is seen by no gate (B4) |
| the contest's GitHub issue | **a sponsor question for NY4I, and every decision he gives** (the rules silent, ambiguous, or the two languages disagreeing). Ask it there, quote his answer in the class header, and name the issue in the header and the rules transcription (Ontario: #127, Quebec: #128). A question still open when you commit stays on the issue, and the header says so |
| `docs/CONTEST_FACTORY_OPEN_QUESTIONS.md` | **not** for one new contest's sponsor questions. It holds the factory's numbered design questions (Q1, Q2, ...) and the rulings on the legacy contests that the migration raised. Add to it only a question about the factory itself or one that reaches several contests |
| `tools/dom-crosscheck/crosscheck_dom_dxlog.py` `CABRILLO_OVERRIDES` | optional; only if your Cabrillo name differs from DXLog.net's for that contest |
| `docs/CONTEST_RULES_OUTSIDE_FACTORY.md` | regenerated by `python tools/contest-rules-inventory/generate.py` after the commit -- **but its `model.py` still refuses any by-id contest** (since URC), so it cannot run until that is extended. Say so in your hand-back |

### Not yours to edit (found by search, for the record)

Every enum-keyed pin table -- `uTestContestIdentityPin`, `uTestContestKindPin`,
the key and column pins, `uTestContestUI.INACTIVE_CONTESTS`, the band exception
list in `Test_EveryOtherContestStillCreditsEveryBand` -- covers the frozen
legacy contests and cannot name a by-id one; the registry walks hold yours.
Mentions in design docs and `docs/Q98_CONTEST_BANDS_MODES.csv` are records,
not wiring.

**If a registry-walk test fails for your contest only**, read it before
your contest: is the walk asking about YOUR contest? Until issue #96
(2026-10-26) the walks turned each object into its legacy member with
`ContestOf`, which is `DUMMYCONTEST` for a by-id contest, so they built
stations, asked identities and printed names for "no contest" and passed
without testing yours (found adding Georgia, `uTestContestExport.PartyQSO`).
`ContestOf` is deleted and `Lint-RegistryWalks` fails a test that brings it
back, or spells it `LegacyContestOf(HandleOf(...))`. A walk keeps the object
or `HandleOf` it; see A5's traps.

## A5. The contest's tests

Copy a test unit. For any other contest that is URC's. **For a state party
it is NOT Georgia's**, which has neither the shipped county file as its
host-area table (item 6) nor an in-state entrant through the real engine
(below): copy the newest party test whose exchange is closest to yours --
North Dakota's, Oklahoma's, New Mexico's, Ontario's or Quebec's (the table
at the top). A by-id contest has no `ContestType`, so use
the `TContestHandle` form of every helper: `uTestContestObjects.Make(handle,
station)`; for a QSO party, `uTestQSOPartyRules.InStateMultiplierOf`,
`CountsForEntrant` and `RoverDupeAnswers` (the real in-state `.dom` through the
real loader, the class's `CountsAsMultiplier`, the real dupe sheet); and
`uTestShippedDom.LoadShippedDomFollowingIncludes` to load a shipped `.dom` with
its INCLUDEs followed. Reuse them rather than copying a helper into your unit.
Georgia's own unit builds its objects by hand, like this:

```pascal
function GeorgiaHandle: TContestHandle;     (* FindContestById, raising if absent *)
function MakeGeorgia(const aStation: TStationContext): TContestBase;
begin
   Result := ContestClassFor(GeorgiaHandle).Create(GeorgiaHandle);
   Result.SetStation(aStation);
end;
```

**The unit tests are the only statement that the contest is RIGHT** -- the
matrix only says it is unchanged (A6). Pin, quoting the rule each test holds:

1. **Identity**: id resolves to the class; no legacy number
   (`ContestLegacyNumber` False, and `TryLegacyContestOf` False); refused on
   multi-op (`ContestCanUseMultiOp` False); every name and id; flags; files;
   and, for a party, what it inherits.
2. **Bands**: every `BandType`, credited exactly when on the rules' list.
3. **Points**: every mode, both sides of each edge, through **`ScoreQSO`**
   (never `CalculateQSOPoints` directly).
4. **Each multiplier rule**, including off-mode QSOs (`CountsAsMultiplier`).
5. **County lines**, for a party: the maximum, a county-line entry within it
   (the first county is this QSO, the next is queued -- `PendingCountiesCount`),
   and one county too many refused with `Format(TC_TOOMANYCOUNTIES, [max])`,
   nothing queued. Georgia's and North Dakota's tests do this.
6. **A party's host-area rule**: an out-of-state entrant's parse and score need
   a table that knows the host QTHs -- a `Station.IsDomesticQTH` stub
   (Georgia's `StubKnowsHostQTHs`) or `uTestContestObjects.WithHostAreaTable`.
   Better, back it with the SHIPPED county file, so the test also proves the
   real data: `uTestQSOPartyRules.LoadCountyTable('<base>_cty.dom', True)`,
   then `@CountyFileKnowsQTH` as the stub and `FreeCountyTable` in a
   `finally` (North Dakota's, Oklahoma's, New Mexico's, Ontario's and
   Quebec's tests do). Do not write a unit-local copy of it.
   **`WithHostAreaTable` knows EVERY QTH** (`StubEveryQTHIsAHostCounty`), so
   it suits a test about points and fails any test whose answer depends on
   what the table does NOT know: the host-area refusal, and a rule that
   strips a rover's county from a call -- with every suffix "known", `/M`
   and `/P` are stripped too. Those need the real county table.
7. **The final score** with a hand-built `TScoreTotals` and a `TLoggedQSOList`.
8. **The data**: the `.dom` against the rules' own table; the in-state file's
   `INCLUDE` list and "no `=` in the header" as text; the county file holds
   only counties and no line STARTS with `INCLUDE` (A1) -- the registry test
   checks only the `INCLUDE` part, so the counties are yours to pin.
9. **The Cabrillo line** against the sponsor's example, word for word. Where
   the rules give no example (North Dakota's list only the fields), pin the
   fields the rules name, in their order, and say so in the test.
10. **One real-engine test** (below).
11. **The 3830 layout**, if you override `Get3830Summary`: the column count,
    headings and kinds, in order, against the contest's 3830 form
    ([A3](#your-3830scores-report----get3830summary)).

**Traps a unit test falls into:**

- **A registry walk keeps the contest, never its legacy member** (issue #96).
  Inside a walk over `ContestsToWalk`/`IdentitiesToWalk`, name the contest
  with `ContestWho(obj)`, ask its identity with `ContestIdentity(HandleOf(obj))`,
  build its objects and stations through the `TContestHandle` overloads
  (`MakeContestOrNil`, `SessionContestName`, each unit's `PinStation`), and
  reach the frozen enum only through `uTestRegisteredContests.IsLegacyContest(obj,
  MEMBER)` or `TryLegacyContestOf(obj, member)` (False for a by-id contest).
  `ContestTypeSA[...]` of a member derived from an object is the same mistake.
  `Lint-RegistryWalks` gates the two derivations; the rest is review.
- **A plain `.dom` load does not follow `INCLUDE` in a unit test.** It
  resolves against the program directory, and the test binary's
  (`tr4w/test/unit`) has no `dom` folder: the file loads with no error and
  **none** of its includes. Use `uTestShippedDom.LoadShippedDomFollowingIncludes`,
  which follows them through the real loader, for the full in-state table;
  still pin the include list as text.
- **Look up a table entry with `TDomQTHTable.FindAlias(key, entry)`**, not
  `GetDomQTH`, which asks the active contest first and answers nothing useful
  without one.
- **A real-engine party test must set the domestic countries**
  (`DomesticCountries.Clear; Add_KVEKH6KL;`, saved and restored). Without them
  every US call is DX and goes to the DX parser.
- **What an out-of-state entrant sees when refused depends on the call AND
  the exchange kind.** Under `RSTDomesticOrDXQTHExchange` (Georgia) a US call
  goes to the domestic parser, which refuses a non-county as
  `TC_IMPROPERDOMESITCQTH`, and only a DX call reaches the party's own
  refusal, `SExchangeOutOfStateWorksHostOnly`. Under
  `RSTDomesticQTHExchange` (Quebec) EVERY call goes to the domestic parser,
  so the US and the DX refusals both read `Improper domestic QTH!! (<QTH>:
  work QC stations only)`. Pin each refusal your kind produces.
- **Read a captured log line with `Line(i)`**
  (`uTestLogCapture.TCaptureAppender.Line`), never `Lines[i]`. A report that
  was not written makes `Lines[i]` raise, which aborts the whole test binary
  with no summary -- so the fail-first check (below) shows a crash, not the
  one failure you caused. `Line(i)` answers `''`.
- **Set the engine's flags FROM THE CLASS** (`Settings.Mult.ByMode :=
  ContestIdentity(h).MultByMode`, ...), as `FCONTEST.ApplyContestTraits` does --
  hard-coding them makes the engine test blind to a wrong `GetFlags`.

**The real-engine test's globals** -- save each, set it, restore it in a
`finally` (copy a newer party's `Test_<Name>RealEngine`, which also covers
the in-state entrant; Georgia's `Test_GeorgiaRealEngineOutOfState` is the
out-of-state half only): `Contest` (then
`ReleaseActiveContest`), `Settings.Qso.ByBand/ByMode`,
`Settings.Mult.ByBand/ByMode`, `DomesticMultByBand`, `StationInHostState`,
`MultipliersIsCounties`, `ActiveMode`, `CallWindowString`,
`ExchangeErrorMessage`, `DomQTHTable`, `CallsignsList`, `QualifiedDupes`,
`DomesticCountries`, `DomesticQTHRefusalDomDir`, `Settings.My.Country`,
`Settings.Contest.DomesticFilename`, the multiplier sheet (`mo.ClearAllMults`)
and the county-line queue (`ClearPendingCounties`).

**Test an IN-STATE entrant in the real engine as well as an out-of-state
one** -- the in-state file, its includes and its alias order are only
exercised there (North Dakota's and later parties' `Test_<Name>RealEngine`).
It needs, besides the above:
`StationInHostState := True`, `MultipliersIsCounties := False` BEFORE the
load, the in-state file loaded through `LoadShippedDomFollowingIncludes`, and
`Settings.Contest.DomesticFilename` naming it. **A contest that refuses one
digital submode** (FT8, say) needs the submode in the QSO: Georgia's `Enter`
helper takes no submode, so add the parameter -- `ParametersOkay` keeps an
`ExtMode` set beforehand (North Dakota's test does). Load `cty.dat` from `tr4w/target`
with `ctyLoadInCountryFile`. Enter a QSO through `ParametersOkay`, then
`VisibleLog.QSOIsADupe`, `Sheet.SetMultFlags`, `Sheet.AddQSOToSheets` and
`AddQSOToDupeSheets`, as `LogContact` does.

**Prove the tests can fail**: break one rule at a time (a point value, a flag,
a band, the county-line maximum), rebuild, see a failure, restore.

## A6. Prove it

Close TR4W first (`Get-Process -Name tr4w` must find nothing). Run the corpus,
**read the result, then commit** -- never in one shell block.

| # | command | what it says about a NEW contest |
|---|---|---|
| 1 | `.\tr4w\build\Build-Tests.ps1 -Run` | your tests and every registry walk; **0 failures**. It also stages the runtime DLLs beside the test exe -- calling FPC directly does not, and the run then fails in SQLite |
| 2 | `.\tr4w\build\Run-Lints.ps1` | `Lint-ContestUnitsLinked`, `Lint-DomCoverage`, `Lint-FrozenContestNumbers`, `Lint-NoContestTables`, `Lint-ContestNameTests` among the rest |
| 3 | `.\tr4w\build\Build-App.ps1` (a FULL build, not `-Incremental`) | the binary the matrix records. **It FAILS if your code raises the count of narrowing string conversions above `$NARROW_CEILING`** (the script prints the count against the ceiling). The usual cause in a contest class: FPC 3.2.2's `SysUtils.Format` and `StrToIntDef` take `AnsiString`, so handing them this tree's `string` (UnicodeString) narrows. Use `UnicodeFormat` (as `uCabrilloExchange` does), compare the text, or `Val` -- do not raise the ceiling |
| 4 | `bash tr4w/test/contest-matrix/freeze-contest-matrix.sh --reason "new contest <ID>" "<ID>"` | writes YOUR record only. It demands a reason; put it in the commit message |
| 4a | `MATRIX_FRESH_DIR=build-out/contest-matrix-work/freeze bash tr4w/test/adif-validate/validate-adif-outputs.sh matrix` | **your record's ADIF against the independent validator, before you trust the freeze.** Step 5 validates only once every record matches, and a run made before step 4 stops at `UNFROZEN` without validating at all -- so without 4a a new contest's ADIF reaches the validator only after it is frozen. A `Compliance error` here means fix the class, rebuild and freeze again (the freeze overwrites your record) |
| 5 | `bash tr4w/test/contest-matrix/run-contest-matrix.sh` | every record: yours equals what you just froze, and **no other contest moved** |
| 6 | `bash tr4w/test/corpus/export-d12-corpus.sh` and `bash tr4w/test/corpus/test-contest-factory.sh` | **nothing about your contest** -- no corpus log is yours. They prove you broke no other contest. Green is `0 failed` with every known divergence pinned, AND exit 0 |

**Read the matrix record before you commit it.** It is your contest's own
first output, so it asserts "same as the first run", never "correct". Look at
the `us`, `us-host` (a party), `ve` and `dx` variants' set-up, scoring and
export lines and check them against the rules.

**One known matrix artifact (#137):** for a contest that counts multipliers
per band and not per mode, the `totals` section counts a multiplier worked on
CW and on phone on the same band TWICE (IARU-HF's, Ontario's and Quebec's
records show it). The `totals` are reloaded from flags the matrix's scoring
set one QSO at a time, so this is believed to be the matrix's, not the
engine's -- live entry is pinned correct by Ontario's and Quebec's real-engine
tests. Do not "fix" your class to match the matrix, and do not take the
matrix's `totals.mults` as your claimed score. (Open: issue 137.)

The PowerShell gates (1-3) cannot run where PowerShell is refused (an isolated
worktree). If you could not run one, say which in your hand-back; do not report
a gate you did not run.

---

# Part B -- Background and reference

## B1. Design rules

**A base class never asks which contest it is.** `if Contest = X` in shared
code is a contest rule living where the contest's own file cannot find it --
the same shape as a radio base testing its model. The contest overrides; the
base states the general case. `Lint-ContestNameTests` ratchets every remaining
legacy instance outside this directory (lower a file's ceiling when you move
one in).

**A contest RULE has no inherited default.** NY4I, 2026-10-15: *"inherited
default can get us in trouble for some future programming adding a new
contest."* The base answers neutral values and shared plumbing; a value that
decides scoring or credit is a line in your class (A3).

**One class per contest, even when two are identical today.** NY4I,
2026-09-02, of ARRL and Winter Field Day: *"They keep diverging with rule
changes each year."* A look-alike starts as a copy it owns; say so in the file
so nobody merges it.

**A family base is for two runnings of ONE contest**, where a rule change
reaches both by definition. A shared mechanism is a helper the class calls
(`FixedModePoints` in `uContestFixedPoints`, `LOGGRID.GetDistanceBetweenGrids`),
not a base. Before calling a helper, check it fits: Field Day scores FM with
phone and digital at two, which `FixedModePoints` cannot express.

**Properties for what a contest IS, methods for what it DOES.** A property is
declared once on `TContestBase` with a virtual getter; override the getter in
`protected`, never redeclare the property.

**`ScoreQSO` is the one public scoring entry** (non-virtual): zero, the band
check (`UsesBand`), the host-area check (`CreditsWorkedStation`), the four
`QSO POINTS ...` overrides, then your protected `CalculateQSOPoints`. Tests
call `ScoreQSO`.

**A QSO party's out-of-area entrant works only the host area** (Q107): one
predicate, `uContestBase.HostAreaRuleCredits`, behind both the typed refusal
and `CreditsWorkedStation` (logged any other way: 0 points, no multiplier).

**A rule reads the QSO, never live state.** A time-of-day rule reads
`aQso.tSysTime` (UTC as logged), never the clock (Croatian, UK/EI). A stored QSO
is scored with its own recorded grid (`ScoreQSO(aQso, aMyFacts)` overlays
`Station.MyGrid`), so never call `ActiveContest` inside a rule -- it would reset
the station. A class reads `Station` and its arguments, never `Settings`, a
global or CTY.DAT.

**Never test multi-op in a class.** A by-id contest is refused on the network
by the registry (B5).

## B2. The base class reference

Each row: the virtuals, what the base answers, and a class that overrides
them. `tr4w/src/contestFactory/uContestBase.pas` declares every one with a
comment; read it there.

### Identity and set-up

| virtuals | base answer | notes |
|---|---|---|
| `GetDisplayName`, `GetFriendlyName`, `GetCabrilloName`, `GetADIFContestId` | the contest's id | every class states the first three itself (A3). The ADIF id is what export writes AND import matches. `FormerADIFContestIds`: old ids import still accepts after a rename |
| `GetWA7BNMId`, `GetQRZRUId`, `GetSubmissionEmail`, `GetDomesticFileName` | 0, 0, `''`, `''` | |
| `GetFlags` | `[]` | `QSOByBand`, `QSOByMode`, `MultByBand`, `MultByMode`, `VHFBandsEnabled`, `CountsDomesticCountries`, `ErmakSpecification`, `RTCCapable`, `cfCQZoneMode` (else ITU) read from it. Set-up (`FCONTEST.ApplyContestTraits`) writes them; an operator's statement wins |
| `GetIsUSQSOParty`, `GetHostState`, `GetQSOPartyArea`, `GetInStateDomesticFileName` | False, `''`, `''`, `''` | the party base answers the first and third |
| `DescribeSession(aStation, aSession)` | states nothing | session values (bands, mode, memories, domestic countries, `SentState`, ...) on a `TSessionDefaults`. **A stated value is stated even when False**; state only what you set. A choice that depends on the entrant is stated both ways on `aStation` (`uContestARRLDXBase`). What you SEND where MY STATE goes is `SentState`, never MY STATE |
| `CQExchangeDefault`, `RepeatSPExchangeDefault` | `''` | used only where the operator has none |
| `WriteDefaultExchangeMessages` | none | call ONE engine writer by name (`WriteRSTQSONumber`, `WriteRSTZone`, ...) |
| `GetIsActive` | True | False only on NY4I's word; an inactive contest still opens old logs |

### Bands, dupes and multipliers

| virtuals | base answer | notes |
|---|---|---|
| `UsesBand` | every band | an off-band QSO is logged, scores 0, earns no multiplier and is not a dupe. Asked through `ContestCreditsBand` by scoring, `SetMultFlags`, the dupe sheet and the need-multiplier hint |
| `CreditsWorkedStation` | True | the party base: the host-area rule |
| `CountsAsMultiplier(aQso, aKind)` | True | about the QSO, never the log. `aKind` is `rmDomestic`, `rmDX`, `rmZone`, `rmPrefix` |
| `MarksDupes` | True | Internet Sprint and the Youth Championship of Russia say False |
| `DupeKeyIncludesReceivedQTH` | False | **True on the party base (Q118)**: the same call, band and mode is a new QSO when it sent a different county -- the rover rule |
| `DupeModeOf(aMode)` | the mode itself | groups modes for the DUPE sheet only (New England: Digital is CW). **FM needs no answer**: the dupe sheet already files FM under Phone (`uSortedStringList.DupeSlot`), so "SSB and FM are one phone contact" is true for every contest without a line in yours |
| `UsesDomesticFile`; `DomesticMultiplierFromQTH`, `DomesticMultiplierHint`, `HasGridSquareMultiplier`, `HasGridFieldMultiplier`, `DomesticQTHReplacesDXMultiplier`, `DomesticQTHIsNeverAGrid` | False; look the text up in the file | a `.dom` contest states the first; a grid/DOK/RDA/IOTA contest states its shape (helpers in `uDomesticKey`). `HasDomesticMultiplier` is composed from them; only a shape with no flag of its own (IOTA, WAG, DARC 10 m) overrides it. Pinned in `uTestDomesticMultiplier` |
| `HasDXMultiplier`, `DXMultiplierKey`, `CountryMode`, `ListsRemainingDXCountry` | False, none, CQ list, every country | a DX contest states the first two (`uDXMultiplierKey` lists). Where the entrant decides, one private predicate answers both. `uTestDXMultiplierKey` |
| `HasZoneMultiplier`, `ZoneMultiplierCount`, `ZoneMultiplierZones`, `NumbersZonesFromZero` | False, 0, not CQ/ITU, False | `HasZoneMultiplier` is True exactly where the count is above 0. The list is NOT `cfCQZoneMode`. `uTestZoneMultiplier` |
| `HasPrefixMultiplier`, `PrefixMultiplierKey` | False, none | False from the key means "leave the prefix as it was", True with `''` means "empty". `uPrefixMultiplierKey`; `uTestPrefixMultiplierKey` |
| `DomesticMultiplierFromCall(aCall, aLookups)` | `''` | the need-multiplier hint before an exchange is typed |
| `ValidateQTHCount` | True | the party base enforces `CountyLineCountiesMax` |

There is no multiplier "kind" to state any more: the four `Has*` answers are
read live against `Station` (`LOGEDIT.DoingDXMults` and its siblings).

### The received exchange

| virtuals | base answer | notes |
|---|---|---|
| `ParseReceivedExchangeFormat` | parses nothing, False | every contest states it (A3) |
| `ParseReceivedExchange(aText, aSession, var aExch, out aErrorMessage)` | the format parse | a RULE overrides it and calls `inherited`. A refusal's reason goes in `aErrorMessage`. The session (`TReceivedExchangeSession`) carries the parsers and services (`IsDomesticQTH`, `ZoneOfCall`, ...); a test hands it `uTestExchangeParserStub`. Never test the exchange kind. Word cutting is `uExchangeTokens` |
| `RequireReceivedGrid` (helper) | -- | a grid contest states what is required after `inherited` (Q115): a format never drops a word |
| `MayBeACallsign`, `InitialExchangeFromCall` | every word may be a call; none | the PCC's `N/X`; Russian DX's oblast |
| `ValidateClass`, `ValidateDXQTH` | accept anything; accept nothing | helpers `ValidateCountAndLetterClass`, `ValidateDXQTHAllowing` |
| `AcceptsBlankExchange`, `LogsSeveralQTHsFromOneEntry`, `SendsStateAfterZone`, `PerQSOExchangeLeadsWithSerial`, `ExchangeTextMayHoldGridSquare` | False | engine questions once asked of the exchange kind |

### Export and import

| virtuals | base answer | notes |
|---|---|---|
| `GetADIFSentExchange` | raises | the `STX_STRING` |
| `GetCabrilloSentExchange`, `GetCabrilloReceivedExchange` | the error marker | reproduce the column widths exactly |
| `EmitADIFReportFields`, `EmitADIFReceivedFields` | RST on every QSO; exactly what `GetReceivedExchangeFields` declares | so a field your list forgets silently leaves the ADIF file. `ADIFPowerTag` moves the power tag |
| `FormatADIFReceivedExchange`, `EmitADIFExchangeFields`, `EmitADIFContestFields` | the `SRX_STRING`; nothing more | override to write tags BESIDE it |
| `ADIFWorkedStationState`, `ADIFCountyState`, `WritesADIFCounty`, `SplitsRoverCallOnExport` | `''`, False | the party base answers them per QSO |
| `WritesADIFContestId` | True | General QSO and POTA say False |
| `ApplyADIFImport(aTemps, aSession, var aExch)` | grid, else the domestic QTH, else `SRX_STRING` | runs after the whole record is read, so tag order cannot matter. A new tag to capture is a `TADIFRecordTemps` field plus `uADIF` entries |
| `CabrilloQSOLineFormat`, `CabrilloModeString`, `CabrilloContestName`, `GetRequiresCabrilloLocation`, `CabrilloHeaderLinesBeforeTag` | the standard line; CW/PH/...; the Cabrillo name; False; none | |

### The final score

`LOGEDIT.TotalScore` asks `FinalScore(aTotals, aView)` = `CombineScore` +
`BonusPoints`; `FinalScore` and `CombineScore` are non-virtual, `BonusPoints`
is virtual. Override the protected
`CombineWithMultipliers` (helpers `ContestPoints`, `SummedMultipliers`) for
another formula; declare bonus stations in `GetBonusStations`
(`CountsTowardBonus`, `CreditsBonusMode`; each station's `Scope` says how
often it pays -- `bsOnce`, `bsOncePerMode` or `bsOncePerBandAndMode`, BC's
VA7ODX being the worked example of the last); otherwise override `BonusPoints`
and add `inherited`. **A bonus is decided over the whole log
(`TLoggedQSOView`), never as a QSO is logged.** A whole-log rule reads each
QSO's own station through `aView.MyFacts(i)`, not `Station.MyGrid`. A rule that
changes by year asks `uContestBase.LogContestYear`, never the clock
(`uContestIdahoQP`, `uContestNebraskaQP`, `uContestNewMexicoQP`): one function
states each year, a year with none pays nothing and a state party reports it
once through the party base's `ReportNoTableForYear`, and a clock-reading
test fails on the first run of a year with no table. A bonus STATION that
pays only in some years cannot be declared data (`GetBonusStations` has no
year): override `BonusPoints` and ask `BonusStationWorked` (New Mexico's
W1AW/5). Both match the LOGGED call exactly, so a rover's suffixed
`W1AW/5/BER` is not paid (A3; #111). The report and its year-table pin read
the log through `uTestLogCapture` -- with `Line(i)` (A5's traps). Pin in the
contest's own test (a legacy contest's in `uTestContestTotals`).

### Display and reports

Answered as data the UI renders; a class never touches a form.
`DescribeNewContestPrompts`, `NewContestValueRefusal`, `GetTotalsDisplay`,
`GetSummarySheet`, `GetReportsRunningScore`, `CanonicalReceivedExchange` /
`CanonicalSentExchange`, `ScorePostingMultiplierType`,
`GetPermittedOperatingAids`, `GetOffersQTCs`, `GetOffersParkTools`,
`GetShowsContestStatus`, `GetMaximumContestDates`, `GetBandStepIncludesWARC`,
`GetPowerFieldIsFOCNumber`, `CallEntryFrequencyWarning`. Base: what the UI does
for any contest. Pinned in `uTestContestDisplay` / `uTestContestUI`; no oracle
sees the screen, so a change here also gets a `docs/BENCH_QUEUE.md` item.

**The 3830scores report** (`Get3830Summary`, `Make3830Column`, design 8.2x):
the rows are your `UsesBand` bands, and the multiplier columns are what
`Get3830Summary` returns; the base gives one `Mults` column. What to write and
what the tests hold you to is in
[A3](#your-3830scores-report----get3830summary).

### `TStationContext` -- what a rule knows about the entrant

`Station` holds the RESOLVED station facts -- `MyCall`, `MyCountry`,
`MyContinent`, `MyZone` (in the contest's zone mode), `MyGrid`, `MyPower`,
`MyState` (the state SENT), `MyName`, `MyFDClass`, `MySection`, `MyPrec`,
`MyCheck`, `InHostState`, `MyCategoryMode`, `ContestName`, `PointOverrides` --
and services (nil-safe): `IsDomesticQTH`, `IsDomesticCountryCall`, `MyCQZone()`
(the CQ zone whatever the mode), `IsNewMultiplierAnywhere` (the sheet,
read-only). Filled by `uContestFactory.CurrentStation`. It carries no clock. A
field or service is added with the first contest that needs it.

### Adding a virtual

When a contest needs a rule no virtual expresses, add the virtual to
`TContestBase` with a base answer that is exactly what TR4W does today for
every other contest, ask it where the engine decides, pin it, and add its row
here in the same commit.

## B3. Where the truth lives

| question | answer |
|---|---|
| what a contest scores | its class's `ScoreQSO`, asked by `LOGSTUFF.CalculateQSOPoints` |
| its session | its traits (`FCONTEST.ApplyContestTraits`), the operator's statements, then its `DescribeSession` (`FCONTEST.ApplySessionDefaults`) |
| its final score | `FinalScore`, asked by `LOGEDIT.TotalScore` |
| its exchange | `LOGSTUFF.ProcessExchange` -> its `ParseReceivedExchange` |
| its names and ids | `uContestRegistry.ContestIdentity(h)` -- never nil, carries no station; ask it what a contest IS, never to score |
| what D7 did | the D7 tree at `C:\TR4W`; read it, never fix it |
| TR4QT | `C:\projects\tr4qt` -- useful for structure, not an authority on rules |

## B4. Which oracle sees what -- read this before believing a green run

(Cited elsewhere as "section 4".)

**The golden corpus is blind to scoring.** `/EXPORT` writes the points stored
in the log; changing a point value leaves `export-d12-corpus.sh` green.

| change | seen by |
|---|---|
| per-QSO scoring | `test-contest-factory.sh` over its 13 logs (rescored, diffed against frozen output); the contest matrix for every contest |
| Cabrillo/ADIF exchange columns | the golden corpus (13 logs); the matrix for every contest |
| Cabrillo header | only `CLAIMED-SCORE:` in the corpus; the matrix's `totals` |
| exchange parsing and refusals | the matrix's `parse` section; your unit tests. **Whether a refusal's message reaches the screen: no gate** -- `docs/BENCH_QUEUE.md` |
| set-up, scoring, export, import, totals of **every** contest | the contest matrix |
| whether any of it is RIGHT | **your unit tests, and nothing else** |

### The contest matrix

`tr4w.exe <cfg> /MATRIX <out> <id>` (`src/uContestMatrix.pas`), driven by
`tr4w/test/contest-matrix/`. For every contest `/MATRIXLIST` names, at four
stations (`us` K0AAA/KS, `us-host` for a contest with a host state, `ve`
VE3AAA/ON, `dx` DL1AAA), it records: `identity`; `setup` (every value set-up
writes); `scoring` of synthetic QSOs; `export.adif` / `export.cabrillo` through
the real exporters; `import` of those records and of synthetic foreign-logger
ones; `parse` of typed exchanges through `ParametersOkay`; `keys` (more QSOs and
exchanges, scored and parsed but not logged); `totals` after a reload; and
`initialexchange` with the matrix's OWN `MATRIX-TRMASTER.DTA`, never the
shipped one. The QSOs are stamped 12:xx UTC, so the run does not depend on the
time of day. Read `run-contest-matrix.sh`'s header for the exact table.

**It asserts "same as when frozen", never "correct".** It fails closed: no
contests captured, a record with no fresh run, a fresh run never frozen, or any
byte difference.

**Never re-freeze to clear a red run.** A record that moved is a finding: find
out why. Only a rule changed **on purpose** -- a sponsor's change, a defect
fixed deliberately -- justifies `freeze-contest-matrix.sh --reason "..."
NAME...`, for exactly the contests it reaches, with the reason and what moved
in the commit message. When a change is only a new `contest.class =` line,
diff the records excluding that line before believing it.

Headless runs cannot see two things: TRMASTER is not loaded for `/MATRIX` and
`/EXPORT`, and logged initial-exchange history is latched after the first log
load (`docs/CONTEST_FACTORY_M11_PLAN.md` F17, F18).

## B5. Ids, handles and names

(Cited elsewhere as "Step 3c" and "Step 5a".)

**The id is stored data.** It is what every SQLite log's `contest` row and
every `.cfg`'s `CONTEST =` line holds. `ContestIdRefusal` refuses an id that is
empty, blank-padded, not printable ASCII, a legacy contest's stored spelling,
a legacy alias, or another contest's id.

**A name that was ever written is never given to another contest.** To rename
an id, add the old one to `uContestNames.LEGACY_CONTEST_NAMES` (old name ->
the contest's CURRENT id) in the same commit. `TryContestFromName` is the one
resolver of a contest name; do not write another loop. `uTestContestNames`
pins that no alias equals a live id. The Cabrillo name is write-only (TR4W has
no Cabrillo import), so renaming it needs no alias; the ADIF id is matched by
import, so a renamed ADIF id keeps its old one in `FormerADIFContestIds`.

**A contest is a one-byte handle in memory** (`VC.TContestHandle`;
`NoContest` is 0). A legacy contest's handle is its legacy number; a by-id
contest is given one when the registry SEALS -- at the first question that
depends on which contests exist -- from `FirstByIdContestHandle` up in id
order. Every registration after the seal raises. The registry is the only
converter: `ContestHandleOf`, `LegacyContestOf`, `ContestLegacyNumber`,
`ContestId(h)`, `FindContestById`, `KnownContests`. Never index
`ContestTypeSA` by a handle.

**A by-id contest is refused on the multi-op network** (the V1 packet carries
only a legacy number, and is not being changed): `ContestCanUseMultiOp` is the
one predicate and every door in `uNet` asks it. Its UDP `<contestnr>` is
derived from the id (`ContestBroadcastNumber`), so renaming the id moves it.
Neither is written in a class.

**A test-only contest** (the unit tests' fixture, `uContestTestFixture`)
registers by id from `tr4w/test/unit`, is named in the test `.lpr` only, and
`Lint-ContestUnitsLinked`, `uTestContestById` and the matrix refuse it in the
application.

## B6. The legacy contests (the frozen enum)

The contests that existed before 2026-10-17 are `ContestType` members with a
`ContestTypeSA` spelling in `VC.pas`. **No member may be added, removed,
reordered or renamed** (`Lint-FrozenContestNumbers`): a member's position is
the contest number in every `.TRW` record and multi-op packet. Changing an
existing legacy contest differs from adding one in three ways:

- its identity values are pinned in `uTestContestIdentityPin` (and its kinds
  in `uTestContestKindPin`). Change its one row by hand, deliberately; never
  regenerate a pin to clear a failure;
- many pin tables and exception lists are keyed by its member -- a contest
  that gains a rule joins the list in the same commit;
- engine code that still names it compares `LegacyContestOf(Contest) = MEMBER`
  and is counted by `Lint-ContestNameTests`. Moving such a rule into the class
  lowers that file's ceiling in the same commit.

## B7. Engine facts that surprise

- **`ModeType = (CW, Digital, Phone, Both, NoMode, FM)`.** `Phone` is SSB and
  AM, not FM; `Digital` is every data mode. A rule that must tell FT8 from RTTY
  reads `aQso.ExtMode` (`ExtendedModeType`; Nebraska's FT8/FT4 test). `Both`
  and `NoMode` are not modes a contact is made in -- score them 0.
- **`BandType` is not in frequency order**: the WARC bands (`Band30`, `Band17`,
  `Band12`) come after `Band10`. Test a band list with `in [...]`, never a range.
- **`LOGGRID.GetDistanceBetweenGrids` is not Haversine** and does not take a
  4-character square's centre. A contest whose rules define the distance
  writes its own helper (`LOGGRID.RTCGridDistance`) and pins the rules'
  published example.

## B8. Not built yet

(Cited elsewhere as "section 6".) TR4QT's `ContestBase` has these; TR4W adds
each when the responsibility actually moves, never in advance:

- `getSentExchangeFields` -- a structured description of the sent exchange
  (the received one is `GetReceivedExchangeFields`; `parseReceivedExchange`,
  `formatSentExchange`, `calculateTotalScore` and most of `getMultiplierValue`
  are built);
- `getCabrilloHeaders` -- only the contest-specific lines are the class's; the
  general `CATEGORY-*` header is PostUnit's;
- an order-agnostic exchange parser as a shared facility;
- the mode-credit seam, `UsesMode` (A3).

One validator fact worth knowing: **`FL` is a valid state but not an ARRL
section** (Florida is NFL/WCF/SFL) -- a state test for ARRL DX and NAQP, a
section test for Sweepstakes and Field Day.
