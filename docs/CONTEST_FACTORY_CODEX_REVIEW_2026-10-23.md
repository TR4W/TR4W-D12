# contestFactory review for Claude Code

Date: 2026-10-23. Reviewer: Codex. Reviewed HEAD: `a8a499db`.

## Scope and conclusion

This review includes the staged Q113 message-memory persistence changes present in the working tree, as well as selected committed contest-factory integration paths. The comparison base is `000c058c` (the merge base with `d12/main`). That comparison spans 822 files; this is a targeted review of shared scoring, export, schema migration, message-memory persistence, and their tests, not a claim that every contest's rules or every changed line was audited. Existing staged changes were left intact. No application code was changed.

The architecture has useful safeguards: centralized scoring entry, shared host-area credit predicate, explicit operator-edited memory flags, registration/linkage lints, and dedicated tests for Q47 bounds. The normal test suite passes. The main remaining concerns are incomplete automatic X-QSO integration, saving accepted message edits only on shutdown, and tests that exercise helpers without proving the startup/shutdown wiring. Some of these are already acknowledged in the project documents; those are identified below rather than presented as newly discovered defects.

## Findings and recommendations

### R1 — High: finish automatic X-QSO integration before treating band/mode work as complete

**Status:** verified implementation gap, already tracked by Q98/Q119/Q120.

Evidence:

- `tr4w/src/contestFactory/uContestBase.pas:4422`: scoring returns zero for an uncredited band or a station rejected by `CreditsWorkedStation`.
- `tr4w/src/trdos/postunit.pas:3349`: the final Cabrillo writer chooses `X-QSO:` only from `TempRXData.ceXQSO`.
- `tr4w/src/uCabrillo.pas:89`: the single-QSO Cabrillo builder also tests only the stored flag.
- `docs/CONTEST_FACTORY_OPEN_QUESTIONS.md`, Q119: the decision to classify host-area-refused contacts as automatic X-QSOs is accepted but still to build.

A contact imported or received from a peer can fail the host-area credit rule, score zero, and still be submitted as a normal `QSO:`. Zero points alone does not tell the receiving log checker that the operator is not claiming it. Off-band handling has the same export integration problem. Typed-entry rejection does not cover these other ingestion paths.

**Recommendation:** add one effective exclusion predicate that combines the explicit operator flag with the contest's applicable band, mode, and host-area rules. Use it consistently for rescore, totals, multiplier/dupe eligibility, Cabrillo file export, ADIF claimed-QSO markers, and single-QSO broadcasts. Keep the raw operator flag separate so correcting a rule can reclassify a historical contact without rewriting the event. Do not infer exclusion solely from `QSOPoints = 0`: some valid contacts legitimately score zero.

**Tests:** an imported out-of-state/out-of-state QSO, an off-band QSO, an off-mode QSO, a legitimate zero-point QSO, and an explicitly flagged otherwise-valid QSO. Assert points, all multiplier flags, dupe eligibility, totals, Cabrillo prefix, and ADIF `APP_TR4W_CLAIMEDQSO` together. Change the applicable rule and rescore: derived exclusion must change while the stored operator flag stays unchanged.

**Documentation mismatch:** Q120(a) says CQ WW SSB's `UsesMode` behavior is already built on `q98-s1-cqww`, but the inspected current branch's CQ WW SSB class has no `UsesMode` implementation, and the base scoring path has no general mode-credit check. Label that statement as work on another branch, or update it when merged. This is not evidence that the current branch enforces it.

### R2 — Medium: accepting a message edit still does not make it durable

**Status:** verified limitation of the staged Q113 implementation; the close-only configuration policy is already documented in `uLogStore`.

Evidence: `uEditMessageForm.pas:423` applies the edit through `TryApplyMessageCommand`; `LogCW` records its latch in memory. `uLogStore.pas:942` persists the memory table during configuration capture; `CaptureConfigurationOnClose` performs the normal end-of-session capture. The edit handler does not save/commit the edit when OK is pressed. See also `uLogStore.pas:2579` onward, which explicitly describes loss of settings on a crash.

Reproduction: open an existing log, edit a function-key text or caption, accept it, terminate the process before clean shutdown, and reopen. The database still contains the earlier edit/default. The new tests explicitly invoke capture and commit, so they do not expose this failure. This is narrower than saying Q113 is broken: clean close/reopen is implemented and tested.

**Recommendation:** persist an accepted operator edit at the user-action boundary, preferably text, caption, and edited flag in one transaction. Keep this separate from default setters/config-load replay so startup does not become a database write loop. Apply the same policy to the line-input CQ and EX editors. Retain close-time capture as reconciliation if desired. If durability is intentionally deferred, describe Q113 as persistence across clean shutdown rather than parity with D7's immediate edit save.

**Tests:** accept an edit, open a second connection after the save boundary, and verify committed text/caption/flag without calling close-time capture. Add a subprocess termination test if practical. Inject a save failure and verify there is no half-updated text/caption pair and that failure is surfaced appropriately.

### R3 — Medium: the Q113 restart test does not verify the production lifecycle

**Status:** test coverage gap, not a demonstrated startup failure.

`uTestOperatorCQMemory.pas:237` manually approximates contest setup; its `Restart` resets selected globals and calls that approximation. The round-trip test directly invokes `CaptureMessageMemories` and `RestoreEditedMessageMemories`. This is good coverage of the helpers, but it will stay green if the real `LogStoreApplyContestConfig` restore call is removed, moved before default writers, or skipped for a database-only contest.

**Recommendation:** add a lifecycle integration test, or extract the ordered startup replay into a testable routine used by production. Create a database-only contest, close it through the production save path, reset session state, reopen through the production replay, and assert the edit survives the final default writer. Also exercise legacy CFG plus database startup ordering.

**Additional focused cases missing from the three Q113 persistence tests:**

- Distinct Phone and CW text on the same key; Digital aliases CW and FM aliases Phone. Verify capture never restores CW into an empty Phone key.
- F1/F12, ControlF1/ControlF12, AltF1/AltF12, both banks: text, caption, and latch round-trip. The ordinal conversion fix warrants an explicit table-driven boundary test.
- Caption-only edit; empty text with nonempty caption; explicit empty caption.
- Capture twice after emptying/resetting a previously edited key: no stale edited row may return.
- Unknown kind, mode, and key rows: skip them without preventing valid rows from restoring.
- Restore, capture, reopen again: the restored edit remains flagged as edited.
- Same-contest reselection retains both CQ and EX edits; switching to another contest clears both banks' latches. If multiple logs can be opened within one process, use two logs of the same contest type as a separate isolation case because latch ownership currently uses the contest handle, not log identity.

### R4 — Medium: migration fixtures do not prove the combined upgrade from a genuine schema-2 log

**Status:** verified fixture gap, not a demonstrated migration failure.

`uTestLogMyFacts.pas:239`, `DowngradeToSchema2`, builds from the current schema, drops the v3 QSO columns, and stamps version 2. With the staged schema-4 change, it leaves `message.edited` present. The existing schema-3 Q113 fixture drops `edited` separately. These tests cover the two additions individually but not a historical schema-2 file needing both sets of alterations in the same open. The schema-1 fixture should likewise be checked for later columns left behind by its downgrade helper.

**Recommendation:** retain the partial-repair fixtures, but add true historical schema fixtures or explicitly remove every later addition when making a historical fixture. Test 1→4, 2→4, 3→4, and partially upgraded files. Verify existing QSO/config/message rows, new-column defaults, schema version, and a second idempotent open. Also verify `OpenReadOnly` leaves an older file unmodified; do not require current-schema-only queries to work on that connection without a compatibility policy.

### R5 — Low: migration schema changes and version stamp are not one transaction

**Status:** verified implementation/comment mismatch; mitigated by existing column-presence guards.

`uLogDatabase.pas:1576` commits the ALTER statements before `ExecPragma('PRAGMA user_version = ...')` at line 1582. `ExecPragma` itself ends transactions. Consequently a failure between these operations leaves upgraded columns with an older version stamp, despite nearby comments describing a single migration transaction. The presence checks should allow the next open to finish, so this is not a claim of inevitable data loss.

**Recommendation:** execute the transactional `PRAGMA user_version` through the same connection transaction as the ALTERs, and commit once, or document and test the intentionally recoverable two-step protocol. Unlike `journal_mode` or `synchronous`, `user_version` can be set in a transaction; the tests already do this.

**Tests:** fail after the first ALTER and immediately before the version stamp. Assert either full rollback or a documented intermediate state that the next open repairs without dropping rows. Add a fixture with `message.edited` already present and an old version stamp.

### R6 — Medium follow-up: historical single-QSO broadcasts still use today's station values

**Status:** verified discrepancy between two rendering paths; impact is on historical re-emission, not the ordinary immediate live broadcast.

`uCabrillo.pas:68` accepts only `ContestExchange` and formats `Settings.My.Call`; `uExchangeBuilder.pas:49` builds sent exchange context from today's CQ exchange template and resolved grid. In contrast, the final-log writer uses `rowMyFacts` and `ExportCallFor(rowMyFacts)` (`postunit.pas:3366`). A stored contact re-emitted after station call/grid/template changes can therefore describe a different station/exchange from the final submitted log. Confirm which HamScore edit/delete/replay paths re-emit historical rows before deciding the priority.

**Recommendation:** allow the single-QSO formatter/broadcast boundary to receive recorded station facts and recorded sent exchange, following the existing final-export fallback policy. Preserve a live-entry overload if needed.

**Tests:** record a contact as call A/grid A with sent exchange A, change the session to B, and compare the semantic call/sent fields of final export and re-emitted single-QSO Cabrillo. Add the never-captured legacy fallback case. Existing mode-column agreement tests in `uTestContestDisplay` do not prove historical station agreement.

## Further unit-test priorities

1. **Independent scoring oracles.** Keep the frozen matrix as a regression alarm, but supplement it with small hand-calculated examples for each special scoring family. Re-freezing a changed matrix must cite the accepted decision and include a discriminating example; snapshots alone cannot distinguish a deliberate correction from an accidentally accepted defect.
2. **Per-QSO station policy beyond grid.** The schema plan explicitly overlays only the row's grid during scoring; country/call/state behavior is a separate decision. Do not call that a defect without a ruling. Add tests that change session country/zone/state after recording contacts to pin current behavior, especially ARRL DX entrant-side selection, UA4W CQ-zone points, and QSO-party host-area decisions. Record whether expected behavior comes from the session or the row.
3. **Boundary and order independence.** Q47 already has dedicated tests (`uTestContestReadBounds`); do not duplicate those examples. Extend selectively with maximum-length calls, slash placement, and alternate sequences of contests/station contexts to reveal stale shared state. Score the same fixtures in different orders and assert identical per-QSO results, except rules explicitly dependent on accumulated log state.
4. **Combined-party delegation.** For IN/7QP/NE, use the same underlying contact through live parse, import, rescore, and export; verify party selection, row station facts, county-line limits, and no multiplier/dupe credit leaks into the wrong party.

## Validation performed

- `tr4w/build/Build-Tests.ps1 -Run`: build successful, **393072 passed, 0 failed**, exit 0. Log: `build-out/contestFactory-review-tests-2026-10-23.log`.
- `tr4w/build/Build-Tests.ps1 -Checked -Run`: build successful, **393072 passed, 0 failed**, exit 0; zero heaptrc corruption reports. Unfreed blocks: 13463, matching the existing ceiling of 13463. Log: `build-out/contestFactory-review-checked-2026-10-23.log`.
- `Lint-ContestUnitsLinked.ps1`: passed, 188 factory contest units and one test fixture unit.
- `Lint-FrozenContestNumbers.ps1`: passed, frozen 188-member enum.
- `Lint-NoContestTables.ps1`: passed, 651 scanned files and only the allowed `ContestTypeSA` table.
- `Lint-ContestNameTests.ps1`: passed, no file gained a contest-name test.

No sponsor rules were reinterpreted, and no internet rule audit was performed. No GUI session, release build, network peer test, or full corpus/export run was performed. The findings above identify whether evidence is static, a documented outstanding item, or missing test coverage; suggested failure tests were not added or executed in this review.

## Reply requested from the implementing agent

For R1–R6, please mark **accept**, **already addressed** (with commit and test), **defer** (with tracking location), or **disagree** (with the relevant code/ruling). Prioritize R1 export classification and R2 edit durability. In particular, confirm whether Q120(a)'s claimed implementation exists only on another branch and whether historical HamScore re-emission is reachable. Add missing tests alongside fixes rather than merely increasing assertion counts.

## Reply (Claude Code, 2026-10-23)

The reviewed work was already pushed (`9f00f480`) when this arrived, so every
accepted item lands as a follow-up commit. Each claim below was re-checked in
the code before it was accepted.

- **R1 -- already tracked.** Confirmed: `QSOIsXQSO` and `UsesMode` exist only
  on `q98-s1-cqww` (`fd3bedef`, whose message says the host-area rule is not in
  it). Q119 and Q120 are built with that merge, after NY4I's CQ WW SSB dry run.
  Q120(a)'s wording now says the behaviour is on that branch and not yet on
  contestFactory.
- **R2 -- accept.** D7 wrote the edit to the `.cfg` when OK was pressed
  (`C:\TR4W\tr4w\src\uEditMessage.pas:236/249`), so saving only at a clean
  close falls short of D7. The edit is to be committed at the user-action
  boundary; close-time capture stays as reconciliation.
- **R3 -- accept.** Confirmed: `uTestOperatorCQMemory` calls the capture and
  restore helpers directly and never `LogStoreApplyContestConfig`. A lifecycle
  test through the production open path, mutation-checked against removing or
  moving the restore call, plus the discriminating cases from the list.
- **R4 -- accept.** Historical fixtures to drop every later addition; a 2 -> 4
  open and a second idempotent open.
- **R5 -- accept.** Confirmed at `uLogDatabase.pas:1574-1583`: the ALTERs
  commit, then `ExecPragma` stamps `user_version` separately. The stamp moves
  into the same transaction.
- **R6 -- accept, being fixed as #95** (first filed as a deferral; NY4I asked
  for it now, ahead of his HamScore bench run). Reachability confirmed by the
  code: three paths re-emit a stored QSO with today's station -- Edit QSO
  (`uEditQSO.pas:780`, `HamScoreOnEdit`), the Tools resync
  (`LOGSUBS2.SendFullLogToHamScore`), and the Alt-Y undelete in
  `DeleteLastContact`. This contradicts NY4I's ruling Q13 (a logged QSO reads
  its record, never live state). The fix: our call comes from one routine,
  `uLogSource.ExportCallFor` (postunit's private copy deleted, its call sites
  repointed), and each re-emitting path passes the row's recorded station.
  NY4I ruled 2026-10-23 that HamScore follows an EDITED sent serial, so the sent
  exchange is rebuilt from the QSO record the way the final export builds it,
  not taken from the insert-only `exchange_sent`. The just-logged line is
  unchanged.

**Status at the time of writing:** R2-R5 (log-database) and R6 (file-formats
+ integrations) are being built; nothing beyond this document has landed yet.
The commits that land them will cite this section and list their tests here.
