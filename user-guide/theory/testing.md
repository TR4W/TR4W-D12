# Test methodology

TR4W uses several kinds of checks because one passing suite cannot establish that every contest, radio, desktop, and export works correctly.

## The layers

| Layer | What it exercises | Representative evidence |
| --- | --- | --- |
| Focused unit tests | Parsers, mappings, state transitions, and contest calculations | `uTestMults`, `uTestCWKeyer`, `uTestCWFraming`, `uTestDXClusterClient` |
| Real SQLite tests | Schema, identity, pragmas, writability, snapshots, and persistence | `uTestLogDatabase`, `uTestLogRepository` |
| Injected failure tests | Backup failures that are difficult to reproduce on demand | `uTestLogBackup` |
| Golden export corpus | A known contest database produces expected ADIF and Cabrillo | `tr4w/test/corpus/README.md` |
| UI checks | Control population, layout, and interaction in a running build | `tr4w/test/ui/` |
| Radio bench and operator tests | Actual transport, keying, timing, and contest workflow | Bench plans and status documents in `docs/` |

## Real data and independent expectations

The export corpus uses SQLite contest logs as input and retained D7-produced ADIF/Cabrillo files as expected output. Keeping those expected files independent matters: regenerating them from the implementation under test could preserve a new defect as the new expectation.

Legacy binary-log conversion is exercised by separate unit fixtures. The old Python export-verifier README describes an earlier `.TRW`-based workflow; it should not be mistaken for the current corpus input contract.

## Deliberately testing failure

Database tests create real temporary SQLite databases. Backup tests combine real files and real valid snapshots with injected failures, including corrupt staged output, snapshot exceptions, and failed publication. They check which files survive and the report given to the operator.

This is stronger evidence for those paths than testing only that the normal backup creates a file. It is still not a substitute for testing real storage loss or power interruption.

## How to read a test result

A useful result identifies the source revision, platform/toolchain, suite or corpus, and pass/fail/skip outcome. A skipped hardware or platform check is not a pass. An accepted export difference should be documented rather than silently changing the expected output.

This documentation update ran the documentation generator and strict MkDocs build, not the application test suites. The existence of a test in the repository is evidence of intended coverage, not evidence that it passed today.

## Supporting documents

- Current corpus methodology (`tr4w/test/corpus/README.md`)
- Database tests (`tr4w/test/unit/uTestLogDatabase.pas`)
- Backup failure tests (`tr4w/test/unit/uTestLogBackup.pas`)
- Hardware test plan (`tr4w/docs/D12_HARDWARE_TEST_PLAN.md`)

For operator validation, start with a practice contest: log and reopen a contact, make and inspect a backup, export it, and verify the intended radio and keying path. Record any difference between the instructions and the application.
