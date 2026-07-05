# TR4W golden-master corpus (D12 modernization — Phase 1)

Matched real-contest fixtures used to lock byte-exact behavior across the
ANSI→UnicodeString conversion (see `../../docs/D12_STRING_MODERNIZATION_PLAN.md`).

## Fixture = a matched set (log ↔ its own export)

Each set lives in its own `<slug>/` subdir and is the **whole** contest artifact —
the export was generated from *this exact* `.TRW`, so a byte diff is meaningful:

```
<slug>/
  log.trw        the contest log (input)
  log.cfg        its contest config (drives Cabrillo header + scoring context)
  ref.adi        fresh D7 ADIF export      — GOLDEN MASTER
  ref.cbr        fresh D7 Cabrillo export  — GOLDEN MASTER  (TR4W emits it as <CALL>.LOG)
  manifest.json  provenance: source dir, D7 version, QSO count, claimed score
```

Every `ref.*` MUST come from **one current D7 build (v4.149.x)** — the importer warns
on anything else. (An earlier attempt used a version patchwork spanning v4.127.5..v4.149;
the old ones predated the 4.147 ADIF fixes and would have enshrined since-fixed bugs.)

## Adding a set

You export from a single current D7 build, then:

```
bash tr4w/test/corpus/import-set.sh "/c/radio/TR4w/<CONTEST DIR>" <slug>
```

It picks the contest `.TRW`/`.CFG`, the `.ADI`, and the Cabrillo (`START-OF-LOG` file),
normalizes names, records provenance, and flags any non-v4.149 export.

## Tracking exception

The repo root ignores `*.TRW`/`*.CFG`/exports so real operating logs are never committed.
`./.gitignore` re-includes fixtures **for this folder only** — the one sanctioned test-data
exception (NY4I, 2026-07-05). The root ignores are unchanged everywhere else.

## How the oracle works

Ground truth is the log record, read by `../logdump/logdump.exe` (canonical `ContestExchange`).

1. **Self-consistency (build-agnostic):** `../python/verify_adif_export.py` checks the export
   faithfully represents the log record — run directly on the CURRENT-D12 export, no reference.
2. **D7↔D12 byte diff (golden master):** the D12 export of `log.trw` must equal `ref.adi`/`ref.cbr`
   after normalizing volatile lines (`CREATED-BY` version, export timestamp).
3. **Score:** each QSO record stores its points/mult (`VC.pas LogEntryPointsAddress=77`,
   `LogEntryMultAddress=69`); score = sum over the dumped log, cross-checked vs Cabrillo
   `CLAIMED-SCORE`. Build-agnostic.

## Sets (v4.149.0)

| slug | contest | path exercised | QSOs | score |
|---|---|---|---|---|
| `arrl_fd_2026_ny4i` | ARRL Field Day | class + section | 34 | 67 |
| `arrl_digi_2026_ny4i` | ARRL Digi | grid-based digital | 32 | 231 |
| `cqwpx_cw_2026_ny4i` | CQ WPX CW | serial + **prefix** mults | 6 | 78 |
| `florida_qp_2026_ny4i` | Florida QSO Party | county/state | 3 | 6 |
| `general_qso_2026_w1aw4` | General QSO (W1AW/4) | plain logging | 79 | 79 |
| `michigan_qp_2026_ny4i` | Michigan QSO Party | county/state | 4 | 32 |
| `winter_fd_2025_w4ta` | Winter Field Day (W4TA) | **volume stress**, multi-op | 1316 | 42364 |
| `cqww_ssb_2025_ny4i` | CQ WW SSB | **zone / DXCC mults** | 101 | 30912 |
| `arrl_ss_ssb_2024_w4ta` | ARRL Sweepstakes SSB | full serial+prec+**check+section** | 206 | 30192 |
| `arrl_dx_cw_2025_ny4i` | ARRL DX CW | **asymmetric** exchange (state/pwr ↔ DXCC) | 66 | 12474 |
| `iaru_hf_2026_ny4i` | IARU HF | ITU-zone / HQ mults | 2 | 12 |
| `na_sprint_cw_2026_ny4i` | NA Sprint CW | sprint (num + name + state) | 2 | 4 |
| `arktika_2026_ny4i` | Arktika Spring | international contest | 1 | 0 |

The major distinct engine paths are now covered. Note: every ref exports as **pure
ASCII** — even ARKTIKA (a Russian contest) has 0 non-ASCII bytes. Contest log data
(calls/zones/sections/RST) does not exercise the UTF-16 path; that risk lives in config
parsing + UI strings and needs its own coverage, not this log oracle.
