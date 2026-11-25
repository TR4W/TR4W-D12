# Separate CQ zone and ITU zone fields -- plan (issue 225 follow-up)

Status: PLAN ONLY, 2026-11-22. Nothing here is built. Owner: contest-scoring;
touches log-database, file-formats, multi-op-network, lcl-ui, i18n,
contest-factory.

NY4I on issue 225: *"We need to specify ITU zone and CQ zone as their own
fields. This also applies to the edit qso dialog. We are using a generic zone
and it is not clear which zone it is."*

---

## REVISED 2026-11-22: THE MINIMAL VERSION (this supersedes sections 2.2, 2.5 and 3)

NY4I asked whether adding one database field and one Edit QSO field really
needs this plan, and an independent review agreed it does not. The size below
(sections 2.2, 2.5 and the seven stages) comes from ONE choice: carving two new
received-zone fields into the 376-byte in-memory record and the wire. That
drags in the census of every `Zone` writer, the reserved-byte measurement, the
dual-write for mixed versions, protocol 5 and TR4WServerPy.

**None of that is needed.** A QSO receives ONE zone. The contest decides whether
it is a CQ zone, an ITU zone or the contest's own number, and every station
knows the contest (the HELLO announces it). So the record and the wire stay
EXACTLY as they are, and the split is done only where it is shown and stored.

**Three small commits (about 1 to 2 days; to be confirmed against the code):**

1. **Classifier.** A pure `ReceivedZoneKind(contest)` returning CQ, ITU, the
   contest's own number, or none, with a registry-walk pin that PRINTS every
   zone-receiving contest's kind so NY4I can read it. Croatian and CW Open are
   pinned by name (their zone list and zone mode disagree). The six contests
   whose kind is not yet verified (R9W, RF Championship, Jock White, EUDX, KCJ,
   WRTC) are listed in the pin for NY4I to check.
2. **Schema 14.** New columns `rcvd_cq_zone` and `rcvd_itu_zone`, written when a
   row is bound from the one `Zone` byte through the classifier, plus a one-time
   backfill of existing rows. `rcvd_zone` and every reader stay as they are, so
   scoring, the exports, the corpus and the matrix do not move. Also add
   `cty_itu_zone` back and make `cty_cq_zone` hold the real CQ zone (it holds
   the ITU zone in ITU contests today, measured in section 1.5), after
   confirming that CTY.DAT gives both zones for a call whatever the contest's
   zone mode.
3. **Edit QSO and the log grid.** The received zone is labelled 'CQ zone' or
   'ITU zone' according to the classifier; if two boxes are wanted, the one the
   contest does not receive is read-only or blank. Saving still writes the one
   `Zone` value.

**Check first (the first task of commit 1):** (a) grep the scoring and
multiplier paths for any contest that needs BOTH received zones on the same QSO
in memory at once; (b) work out exactly what 'zone list and zone mode disagree'
means for Croatian and CW Open. If a CTY-derived zone covers every case, the
record stays unchanged. If one contest genuinely needs two received values in
memory, only that case justifies touching the record.

**Dropped from this issue (file separately if wanted):** the licence-year Edit
QSO box (Q3), writing both ADIF zone tags (Q2), stopping the legacy zone byte
and protocol 5 (Q1; with the record unchanged there is nothing to stop), and
OZCR-Z scoring on the ITU zone (Q6; a one-line change with its own question).

The rest of this document is kept as the EVIDENCE (sections 1.x are still
correct); sections 2.2, 2.5, 3 and the old size estimate are superseded.

---

## 0. Executive summary

1. The STATION side is already separate: `my_cq_zone` / `my_itu_zone` (schema
   3), `TQsoMyFacts.CQZone` / `ITUZone`, Edit QSO's `lblMyCQZone` /
   `lblMyITUZone`, Correct Station Facts' `sfZone` / `sfItuZone`.
2. The RECEIVED side is one byte, `ContestExchange.Zone`, stored as
   `qso.rcvd_zone` ("CQ **or** ITU: the contest decides"), plus contest-own
   numbers (RF Championship's zones, NZART branch, R9W) and the licence-year
   fallback.
3. NEW FINDING, measured: `cty_cq_zone` is ALSO mislabelled. It is written from
   `QTH.Zone`, which CTY.DAT fills in the contest's zone mode, so the IARU
   corpus log stores W1AW (CQ 5 / ITU 8) as `cty_cq_zone = 8`.
4. Target: two received fields, `RcvdCQZone` / `RcvdITUZone` (one Byte each,
   0 = none), carved from `sReserved` exactly as the year was; record stays
   376 bytes; new columns `rcvd_cq_zone` / `rcvd_itu_zone` (schema 14); the
   CTY ITU zone comes back as `cty_itu_zone` and `cty_cq_zone` becomes truly
   CQ.
5. ONE classifier decides which field a contest's received zone is
   (`zmzCQZones` -> CQ, `zmzITUZones` -> ITU, else field list has Zone -> the
   contest's `ZoneMode`, else none/own), ONE writer (`StoreReceivedZone`), and
   the multiplier sheet keeps its single chokepoint `ContestZoneMultiplierKey`.
6. Transition dual-writes the legacy `Zone` slot, so mixed versions need no
   protocol bump; a final stage that stops writing the slot (NY4I's #281
   ruling) is the one that needs protocol 5.
7. Edit QSO gets two received boxes (CQ zone, ITU zone) beside the existing
   two station boxes; the licence year gets its own box (question Q3).
8. Seven staged commits; corpus bytes do not move until the ADIF-both-tags
   question (Q2) is ruled; matrix records move only for the 28 zone-receiving
   contests.
9. Size: about 6 to 9 working days of agent time plus a bench session. The
   corpus and matrix prove "same as before" only; a real IARU and CQ WW log
   test is required.

---

## 1. Current state, with evidence

### 1.1 The record

`tr4w/src/VC.pas`, `ContestExchange` (376 bytes, pinned by
`uTestLogBinaryFile`):

- `{01} Zone: Byte;` (the received zone; `DUMMYZONE` = 255 is "none").
- `QTH: QTHRecord` (`VC.pas` ~1906, header "Don't touch!"):
  `CountryID`, `{01}Zone: Byte`, `{01}reserved: Byte`, `Prefix`, `Continent`,
  `StandardCall`. `QTH.Zone` is the CTY.DAT zone of the worked call.
- The tail carved from `sReserved` so far: `ceXQSO`, `RcvdYear` (Word, 324),
  `RcvdYearKnown` (326), `YearSentKnown` (327), `YearSent` (328),
  `ceOffContest` (330), `ceRoverQTH` (`string[10]`, 331..341),
  `sReserved: string[31]` at 342..373, padding 374..375.
- Two frozen older layouts (`ContestExchangev1_6`, `ContestExchangev1_5`)
  carry the same `Zone` byte; `MainUnit` 12932 / 13028 copy it across.

### 1.2 What decides the meaning of `Zone`

Nothing in the record. The meaning is the CONTEST's:

- `TContestBase.ZoneMultiplierZones` (`uContestBase` ~7689; enum
  `TZoneMultiplierZones` ~845): 13 classes override it.
  CQ: CQ WW (base, RTTY), GAC WW/WSA CW, JIDX CW/SSB, WWIH.
  ITU: IARU, BSCI, Croatian, Gagarin, LZDX, OZCR-O, OZCR-Z.
- `TContestBase.ZoneMode` (`cfCQZoneMode` in 26 classes, else ITU) decides
  which zone CTY.DAT gives a call. It is NOT the multiplier list; the two
  disagree for the Croatian and CW Open (plan F5, Q95 open).
- 28 contest units use a field list with `Zone := True`
  (`uExchangeFields`: `QSONumberZone`, `RSTQSONumberZone`, `RSTZone`,
  `RSTZoneQTH`): KVP, EU HFC, R9W, RF Champ CW/SSB, OZCR-Z, OZCR-O, Gagarin,
  CQ 160 CW/SSB, IARU, CQ WW RTTY, WWIH, CQ WW SSB/CW, WWPMC, Jock White FD,
  LZDX, KCJ, JIDX CW/SSB, IRTS, GAC WW/WSA, EUDX, Croatian, BSCI, WRTC, JTDX.
  Several of those number the slot themselves (RF Championship's seven
  zones, NZART branch, R9W; EU HFC/KVP years -- now in `RcvdYear`).

So `Zone` holds a CQ zone, an ITU zone, or a contest-own number, and only the
contest knows which.

### 1.3 Readers and writers (grep, `\.Zone\b`, case-blind, `tr4w/src`)

`\.Zone\b` gives 122 hits in 30 files, but that count MIXES FOUR THINGS and
must not be read as "122 readers". Split by kind:

**A. The received value (`RXData.Zone` / `rec.Zone` / `aQso.Zone`) -- the
target.**

| unit | sites | role |
|---|---|---|
| `trdos/logstuff.pas` | 2602, 2620, 2627, 5171, 5179, 6047, 6241 | parser WRITES (QSO-number+zone, RST+zone, CQ WW RTTY, licence-year/zone reader) |
| `uContestBase.pas` | `ContestZoneMultiplierKey` 5801 (+ year helpers) | the sheet key: ONE chokepoint since #298 stage 4 |
| `trdos/logdupe.pas` | 1016-1017 clear; sheet writes via the key | `MultiplierKindsCredited`, `SetMultFlags`, `AddQSOToSheets`, `CountWorkedMultipliers` |
| `trdos/logedit.pas` | 683-685 `SetLoggedZone` (#213); 1018, 1377, 1391 hint | prior-contact zone trumps CTY |
| `trdos/postunit.pas` | 2997-3019 ADIF CQZ/ITUZ tag; 4319 zone report | tag chosen from the SESSION's zone list / `CTY.ctyZoneMode` |
| `uCabrilloExchange.pas` | 943, 953, 1101, 1112 | Cabrillo received column |
| `trdos/logsubs2.pas` | 3324 | UDP `<zone>` (falls back from the year) |
| `MainUnit.pas` | 9525 (log grid text), 12932 / 13028 (v1.5/v1.6 conversion) | display, legacy import |
| `uEditQSO.pas` | 466-468 show; 782-819 save | ONE box, `FLD_ZONE`, relabelled "Year" for year contests |
| `uADIF.pas` | 1716 (`CQZ`), 1791 (`ITUZ`), 2027 clear | IMPORT: BOTH tags write `exch.Zone`, so the LAST TAG IN THE RECORD WINS (defect) |
| `uLogRepository.pas` | 2152 bind `rcvd_zone`; 2493 / 2534 read | storage |
| `uLogImport.pas` | 284-286 | .TRW import moves a year contest's slot to `RcvdYear` |
| `uContestMatrix.pas` | 855, 907, 1353 | matrix spec and print |
| classes | BSCI, CQWWBase x2, EU HFC, IARU x5, Jock White x3, OZCR-Z, R9W, RF Champ x2 each | scoring / parse rules |

`with RXData do Zone := ...` forms are invisible to `\.Zone\b`. The honest
complete list comes from the compiler at stage 1 (rename the field
temporarily, build, list every error, rename back) -- that is the first task
of stage 1, not a guess here.

**B. The CTY value (`QTH.Zone`).** `uctydat.pas` 1343-1352 fills it in
`CTY.ctyZoneMode`; `uLogRepository` 2199 binds it to `cty_cq_zone`, 2591
reads it back; `MainUnit` 10213-10277 rescore change log; `logstuff`
1387-1408 zulu offset (reads it as CQ 1..40 OR ITU 1..66 by mode);
`uContestMatrix` 903, 1372; `fcontest` 1152 (`DeriveZone` for MY ZONE).

**C. The field-list flag (`ExchangeInformation.Zone`, `aFields.Zone`).**
`cfgdef` 191, `logdupe` 2410, `MainUnit` 11031, `postunit` 3011,
`uExchangeHint` 136, `uExchangeFields` x5. A Boolean, not a zone.

**D. Station settings (`Settings.My.Zone`, `aKeys.Zone`).** `logcfg` 942,
`uSettingsEffects` 172, `uSettingsModel` x2.

### 1.4 The schema (`src/domain/uLogSchema.pas`, `LOG_SCHEMA_VERSION = 13`)

- `rcvd_zone INTEGER -- CQ **or** ITU: the contest decides` (~633).
- `cty_cq_zone INTEGER` (~677). `cty_itu_zone` was DROPPED in schema 11
  (`LOG_V11_DROPPED_QSO_COLUMNS`, "never filled"); the schema's own note says
  if it is wanted again it is an ADD COLUMN under a new version.
- `mult_zone INTEGER` (the per-QSO flag; the key is the contest's).
- `my_cq_zone`, `my_itu_zone` (schema 3), bound 0 -> NULL (`BindZone`,
  `uLogRepository` 2330).

### 1.5 Measured: `cty_cq_zone` holds an ITU zone in an ITU contest

```
sqlite3 -readonly tr4w/test/corpus/iaru_hf_2026_ny4i/log.db
  "select callsign, rcvd_zone, cty_cq_zone, dxcc_entity from qso"
W1AW|8|8|K        -- W1AW is CQ 5, ITU 8
F4HQ|27|27|F      -- France is CQ 14, ITU 27
```

The column is named CQ and holds the ITU zone, because `QTH.Zone` follows
`CTY.ctyZoneMode`. This is the received-side twin of the `rcvd_zone`
ambiguity, and the corpus logs are `user_version 2`, so every corpus export
already runs every migration.

### 1.6 Station side: verified already separate

- Settings: MY ZONE (a CQ zone when stated; `EngineMyCQZone`), MY ITU ZONE
  (`SessionMyITUZone`, else CTY.DAT). Issue 222.
- Row: `my_cq_zone`, `my_itu_zone`; Edit QSO shows both; Correct Station
  Facts (97c832798, #223) corrects both.
- One residual: `Station.MyZone` (the derived MY ZONE text) is derived in the
  contest's zone mode when unstated, so in an ITU contest it is an ITU zone.
  `TContestOZCRZ` compared it until NY4I ruled on 2026-11-25 (OZCHR follows
  the IARU HF rules, so its zones are ITU zones): it now uses
  `ScoringMyITUZone` (pinned by
  `uTestITUZoneContests.Test_OZCRZComparesTheITUZone`). Not part of this plan
  beyond question Q6.

### 1.7 Wire and binary constraints

- QSO packet 384 bytes carrying the 376-byte record whole; `SERVERLOG.TRW`
  stride 376; `NET_PROTOCOL_VERSION = 4` (`uNetHello` 86). Both servers
  (in-tree and TR4WServerPy) store and relay the record without reading it.
- `.TRW` reader (`uLogBinaryFile.ReadNext` 324-342) clears every carved
  field because a D7 log is somebody else's file.

---

## 2. Target design

### 2.1 Principle

A received zone is stored as WHAT IT IS (CQ or ITU), never as "the contest's
zone". A contest-own number (RF Championship zone, NZART branch, R9W) is NOT a
CQ or ITU zone and stays in the legacy `Zone` slot until its own field is
decided (question Q4). The licence year already has its field.

### 2.2 The record (no size change)

Carve two Bytes from `sReserved`, exactly the #298/#300 pattern:

```
{01} RcvdCQZone:  Byte;   offset 342   0 = none (1..40 valid)
{01} RcvdITUZone: Byte;   offset 343   0 = none (1..90 valid)
{30} sReserved:   string[29]           344..373, still ending at 374
```

- No `Known` Boolean: unlike the year, 0 is not a valid CQ or ITU zone, so a
  zero-filled record (FillChar, an older peer, an old server log) reads "none"
  with no conversion. Matches `my_*`'s 0 -> NULL.
- Bytes, so no alignment pad.
- Byte 342 was `sReserved`'s length byte (zero). Byte 343 was its first
  CONTENT byte -- the year work MEASURED 324..326 zero in the six binarylog
  fixtures (327 and 330 were later taken as former length bytes, inferred,
  not measured); 343 must be measured the same way in stage 1 and pinned. The
  `.TRW` reader clears both regardless.
- `uTestLogBinaryFile` pins offsets 342/343/344, end 374, total 376.

Alternative considered: put the CTY ITU zone in `QTHRecord.reserved` (the
byte after `QTH.Zone`). Recommended (2.6), but that byte must be measured in
the fixtures too -- "Don't touch!" is a layout warning, and nothing is known
to write it.

### 2.3 One classifier, one writer, one reader

In `uContestBase` (beside `ContestZoneMultiplierKey`):

```
TReceivedZoneKind = (rzkNone, rzkCQ, rzkITU, rzkContestOwn);
function ContestReceivedZoneKind(aContest: TContestBase): TReceivedZoneKind;
procedure StoreReceivedZone(aContest; var aQso; aZone: integer);
function TryReceivedZoneOf(aContest; const aQso; out aZone): boolean;
```

Classifier order (the one postunit's ADIF tag choice already uses, lines
2999-3019): `zmzCQZones` -> CQ; `zmzITUZones` -> ITU; else if the field list
marks Zone and the contest has no zone multiplier -> its `ZoneMode`; else if
the contest numbers its own zones -> `rzkContestOwn`; else none. A class may
override (`ReceivedZoneKind` virtual) -- the Croatian (ITU list, CQ mode) and
CW Open (CQ mode, no zone mult since #277) are the named cases where the
order matters, and both must be pinned.

- Parsers keep producing ONE number (no parser learns about CQ vs ITU).
  Every parser write site in 1.3 A becomes `StoreReceivedZone`, which writes
  the right typed field AND (during the transition, 2.5) the legacy slot.
- `TryReceivedZoneOf` reads the typed field, falling back to the legacy slot
  classified by the record's own contest (`ContestIdentity(ceContest)`) --
  the `TryLicenceYearOf` precedent, for older peers and server logs.
- `ContestZoneMultiplierKey` asks `TryReceivedZoneOf` for CQ/ITU contests;
  contest-own and year paths unchanged. No sheet change: no contest counts
  both lists, so `mo`'s numbered zone table stays one table.
- `SetLoggedZone` (#213) stores the zone with its kind, or (simpler) the
  zone of the active contest's kind only -- the hint compares like with like.

### 2.4 Schema 14

- `ADD COLUMN rcvd_cq_zone INTEGER`, `rcvd_itu_zone INTEGER`,
  `cty_itu_zone INTEGER` (NULL = none), guarded by `PRAGMA table_info`, last
  in `LOG_QSO_TABLE`, new `LOG_V14_QSO_COLUMNS`.
- Backfill cannot run in the migration: only the set-up contest can classify
  a row, and `uLogSchema`/`uLogDatabase` cannot see the factory. Use the
  store's one-shot pattern (`LOG_ZONE_FIELDS_BACKFILL_KEY`, like
  `LOG_OFF_CONTEST_BACKFILL_KEY`): after set-up, classify each row's
  `rcvd_zone` by its contest into the right column, NULL-only so a crash
  re-runs harmlessly.
- `cty_cq_zone` / `cty_itu_zone` backfill: re-derive from CTY.DAT by call?
  NO -- that rewrites history the column exists to freeze. Instead: for a
  row whose contest's `ZoneMode` is ITU, MOVE `cty_cq_zone` to
  `cty_itu_zone` and set `cty_cq_zone` NULL (it never held a CQ zone).
  A rescore of a prefix/zone/DX contest re-derives both anyway
  (`RecomputeQSOScoring`). Question Q5.
- `rcvd_zone` stays (contest-own numbers, and the legacy slot during
  transition). Its comment becomes "contest-own number; CQ/ITU live in
  rcvd_cq_zone / rcvd_itu_zone".
- Older builds refuse the migrated log (as for every version since 3).

### 2.5 Multi-op wire and mixed versions

- Stage 2-6: SENDERS DUAL-WRITE (typed field AND legacy `Zone`). An older
  (protocol 4) peer reads `Zone` as ever; a newer receiver seeing 0 in the
  typed bytes derives them from `Zone` through its own classifier. No
  protocol bump -- the `ceOffContest` precedent (schema 10). Both servers
  relay the bytes blind; TR4WServerPy needs no change.
- Stage 7 (optional, Q1): stop writing the legacy slot for CQ/ITU contests
  (NY4I on #281: "we should not reuse fields especially named as something
  else like Zone"). THAT is the meaning change that needs
  `NET_PROTOCOL_VERSION = 5`, TR4WServerPy and `tools/netprobe` moved
  together, as protocol 4 did.
- Receive paths to cover: live `NET_QSOINFO` (`LogContact`), a peer's edit
  (`LogStoreUpdateQSOBySessionIds`), catch-up (`LogStoreAppendQSOs`),
  server-log row (`uGetServerLog.TryGetServerLogRow` / `MergeServerLog`).

### 2.6 CTY zones of the worked station

`ctyLocateCall` already has both numbers in the prefix table; it writes one by
mode. Write `QTH.Zone` as today (every engine reader keeps its mode-dependent
meaning) and the OTHER into a typed home -- either `QTHRecord.reserved`
(after measurement) or two Bytes more from `sReserved`. The repository binds
`cty_cq_zone` / `cty_itu_zone` from the typed values, never from `QTH.Zone`.

### 2.7 Edit QSO

- `uEditQSOForm.lfm`: two received boxes "CQ zone" / "ITU zone" (reuse
  `SEditQSOMyCQZone` / `SEditQSOMyITUZone` captions if NY4I accepts the same
  words for both groups; else two new resourcestrings -> the 24 `.po` files,
  i18n agent). Ranges 1..40 / 1..90; empty = none.
- The contest-own number keeps the current `FLD_ZONE` box only where the
  contest is `rzkContestOwn`, labelled by `ZoneColumnHeading`; the year gets
  its own box (Q3). Hide the box a contest does not use, or show both and
  let either be edited (Q7).
- Save goes through `StoreReceivedZone` / direct typed writes, then the
  existing rescore.

### 2.8 Exports

- Cabrillo: the four `uCabrilloExchange` sites read `TryReceivedZoneOf` with
  the record's contest. Bytes unchanged.
- ADIF export: today one tag chosen from the SESSION's list (`postunit`
  2997). Target: `CQZ` from `rcvd_cq_zone`, `ITUZ` from `rcvd_itu_zone`,
  per record. With dual-write and only the received kind filled, bytes are
  unchanged. Emitting the CTY-derived other zone too would move every frozen
  D7 `ref.adi` (Q2).
- ADIF import: `CQZ` -> `RcvdCQZone`, `ITUZ` -> `RcvdITUZone` (fixes
  last-tag-wins), then `Zone` = the one the open contest counts.
- UDP `<zone>` (logsubs2 3324): `TryReceivedZoneOf`.
- Log grid column: the typed value of the contest's kind (one column, as
  now); a second column is a UI question (Q7).

### 2.9 Rescore, import, correction tool

- Rescore reads stored fields; nothing new to derive. `.TRW` import
  (`uLogImport` 284 precedent) classifies the slot by the file's contest.
- Correct Station Facts stays station-only by design: a received zone is the
  other station's fact, corrected per QSO in Edit QSO. A bulk "received zone"
  correction is Q8.

---

## 3. Staged commits

Each stage builds, has its own tests, and runs the quick loop; the full gate
(corpus, matrix, factory check, checked unit run) is marshalled once per
batch.

| # | stage | tests | corpus | matrix |
|---|---|---|---|---|
| 1 | Record: carve `RcvdCQZone` / `RcvdITUZone` (and the CTY ITU home); `.TRW` reader clears; compiler-guided census of every `Zone` writer, recorded in this doc | `uTestLogBinaryFile` offsets; fixture bytes 342/343 (and `QTHRecord.reserved`) measured zero | none | none |
| 2 | Classifier + `StoreReceivedZone` / `TryReceivedZoneOf` in `uContestBase`; every parser write repointed; dual-write | new `uTestReceivedZoneKind`: every ContestType at the seven stations, Croatian and CW Open named; parser pins | none (export still reads `Zone`) | parse records of the 28 zone contests gain `cqz=`/`ituz=` IF the parts are printed only when non-zero (Part always prints today, so add the calls conditionally or EVERY record moves) |
| 3 | Schema 14: columns, bind/read, store one-shot backfill | `uTestLogDatabase` migration shape; backfill per contest kind; crash re-run | none expected -- corpus logs are schema 2 and run the backfill; this is the proof | none |
| 4 | Readers: sheet key, Cabrillo, ADIF export/import, UDP, grid, `SetLoggedZone` | `uTestCabrilloColumns`, `uTestADIF` (both tags import), `uTestZoneMultiplier`, totals | none (same values, same tag) | none expected; any moved score line is a defect |
| 5 | CTY zones: write both, `cty_itu_zone` bound, `cty_cq_zone` truly CQ; backfill move for ITU-mode logs | IARU W1AW row: cty 5 / 8 | none (ADIF reads neither) | `cty=` part moves for ITU-mode contests only if it is changed to print the CQ zone -- keep it printing `QTH.Zone` so it does not |
| 6 | Edit QSO two boxes; year box (Q3); `.lfm`, strings, `.po` | `uTestEditQSO*` round-trip; i18n catalogue check | none | none |
| 7 | (Q1) stop writing the legacy slot for CQ/ITU contests; protocol 5; TR4WServerPy + netprobe | `uTestNetHello` 5; peer-without-typed-bytes fallback | none | `zone=` moves for CQ/ITU contests: refreeze with a written reason |

---

## 4. Risks and rollback

- Silent zero: a missed parser write leaves the typed field 0 while the slot
  holds the zone -> dual-write plus the fallback read hides it until stage 7.
  Stage 1's compiler census is the control; stage 7 must not start without a
  zero-hits grep of direct `Zone :=` in parsers.
- Resurrected zone: with dual-write, `TryReceivedZoneOf` falls back to the
  legacy slot whenever a typed byte is 0, so a CQ zone CLEARED in Edit QSO,
  or an ADIF import carrying only the other tag, would come back from `Zone`.
  `StoreReceivedZone` and every clear path must write the slot and the typed
  field TOGETHER, clearing both to none; stage 6 pins that a cleared box stays
  cleared after save and reload.
- Classifier edge cases: branch 3 gives `ZoneMode` to any zone-receiving
  contest with no zone multiplier; whether that is right for R9W, RF
  Championship, Jock White, EUDX, KCJ, WRTC is unverified. Stage 2's
  every-ContestType pin prints each contest's kind so NY4I can read the list.
- Classifier drift: postunit's tag choice and the new classifier must be ONE
  function at stage 4 (repoint postunit to it), or they drift.
- Backfill timing: a log opened and closed before contest set-up leaves the
  key pending; NULL-only re-run is safe.
- Older builds refuse a schema-14 log (accepted for every version since 3).
- Rollback: stages 1-6 are additive (dual-write); revert the commits and a
  schema-14 log is still refused by the reverted build -- keep a pre-14 copy
  (the existing restore engine's migration backup covers it).
- Scoring risk: the sheet key moves source in stage 4. The corpus is blind to
  scoring; `test-contest-factory.sh` and the matrix totals section are the
  nets; a real IARU and CQ WW log rescore before/after is required (bench
  queue).

---

## 5. Questions only NY4I can answer

- **Q1. Final stage: stop writing the legacy `Zone` slot for CQ/ITU contests
  (protocol 5)?** Recommend YES, as the last stage after a contest weekend
  on dual-write -- it is your #281 rule.
- **Q2. ADIF: write both `CQZ` and `ITUZ` when both are known (one received,
  one CTY-derived)?** Recommend NO: ADIF should carry what was received; CTY
  facts are not the exchange. Keeps the frozen references.
- **Q3. Edit QSO: give the licence year its own box instead of sharing the
  zone box?** Recommend YES, same commit as the two zone boxes.
- **Q4. Contest-own numbers (RF Championship zones, NZART branch, R9W): stay
  in `rcvd_zone` for now?** Recommend YES; a typed field each is a later
  decision.
- **Q5. Correct the mislabelled `cty_cq_zone` in existing ITU-mode logs by
  MOVING the value to `cty_itu_zone`?** Recommend YES (it is a move, not a
  re-derivation).
- **Q6. OZCR-Z's same-zone point: ITU (`ScoringMyITUZone`)?** Recommend YES
  unless you hold sponsor text otherwise (still open on #225).
- **Q7. Edit QSO and the log grid: show only the zone the contest uses, or
  always both?** Recommend: Edit QSO shows both, editable; the grid one
  column, the contest's kind.
- **Q8. A bulk received-zone correction tool?** Recommend NO; Edit QSO per
  QSO plus the rescore is enough.

---

## 6. Size estimate

About 6 to 9 working days of agent time across the seven commits: stages 2
(parser census and classifier pins over every ContestType), 3 (store
backfill) and 6 (designed form, strings, 24 catalogues) are the large ones;
1, 4 and 5 are a day or less each; 7 is a day plus TR4WServerPy. Then a bench
session: an IARU and a CQ WW log logged live, edited, exported, rescored,
and a two-station multi-op check with one old and one new build. The corpus
and matrix prove "same as before" only; they cannot prove a zone is the right
kind.
