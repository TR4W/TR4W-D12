# Remaining Windows UI regression work

This ledger tracks the nine groups NY4I asked to take to a conclusion, using Python scripts with explicit assertions, saved evidence and process exit codes. Discovery captures do not count as passing regression cases. Scope is the isolated Windows VM and the user-selected main executable; other platforms and unavailable equipment remain separate requirements.

| Group | Status | Required automated observations |
| --- | --- | --- |
| Preferences hints and semantic focus | PASS | Six actual hover cases; 47-page forward/reverse Tab walk and reading-order assertions |
| Online scoring | PASS | Fields, certificate state, Save/Cancel, restart and three isolated HTTP Test requests without credentials |
| Offline external loggers | PASS | Five provider field sets, Club Log masking/reveal, inactive ordering/restart and reviewed empty-grid baseline |
| Radio definition editor | PASS | Polling-rate bounds, tooltip/Tab, HamLib toggle, blank default and restart; no active profile |
| Multi-band/mode log search | Incomplete: driver setup | Last run entered the intended new-10-m contact on 20 m; fix observed band selection, review baselines and verify columns |
| Log switching | FAIL: issue #306 | Valid new-log/back round trip passes; invalid database incorrectly causes restart |
| Locked/read-only logs | PASS, Windows scope | Real writer; Retry held/released, manual entry, read-only export/refusal, one warning, Quit/Escape/Close |
| ADIF import | PASS | Invalid rollback/warning, later manual entry, valid import and six-record ADIF re-export |
| Message banks | PASS, scoped | Standard/Control/Alt values and caption survive restart without transmission; chooser selection retention is separate |

`run_suite.py` will stage one identified build, create disposable fixture directories, run selected cases sequentially, and return 0 only when all selected tests pass. Failures and setup problems produce nonzero exit codes and a JSON summary. It will not depend on earlier exploratory VM runs. Screenshots remain supporting evidence.

## Current implementation checkpoint

- Runner: tools/gui_test/run_suite.py; portable seed passed with repository-owned settings and country data, no historical VM fixture dependency.
- Hints PASS: build-out/gui-regression/20261112T091420-9e54d0/hints.
- Focus and loggers PASS: build-out/gui-regression/20261112T142924-c855a4/summary.json.
- Messages and online PASS: build-out/gui-regression/20261112T092001-c7d2a2/summary.json.
- Radio PASS including tooltip/last-Tab: build-out/gui-regression/20261112T140847-1ce4bc/radio.
- Import PASS and switch round-trip PASS: build-out/gui-regression/20261112T143807-876920/summary.json. Invalid-file refusal fails: [#306](https://github.com/TR4W/TR4W-D12/issues/306).
- Locked PASS: build-out/gui-regression/20261112T144826-bb589e/locked. Search remains incomplete; see [turnover and exact next steps](GUI_TEST_HANDOFF.md).
- run_suite.py stages the latest selected main binary per suite; each case within that suite shares that exact snapshot. Archive previous per-phase artifacts before rerun and require result.run to match the fresh fixture name.
