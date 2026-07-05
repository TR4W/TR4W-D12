# TR4W golden-master corpus (D12 modernization — Phase 1)

Real `.TRW` contest logs curated to exercise the distinct exchange / multiplier /
scoring paths of the TRDOS engine end-to-end. Used to lock byte-exact behavior
before and during the ANSI→UnicodeString conversion (see
`../../docs/D12_STRING_MODERNIZATION_PLAN.md`).

## Logs (one per distinct engine path)

| File | Contest | Exercises |
|---|---|---|
| `cqww_cw` | CQ WW CW | RST+zone; DXCC/zone mults |
| `iaru_hf` | IARU HF | zone / HQ mults |
| `cqwpx_cw` | CQ WPX CW | serial + **prefix** mults |
| `arrl_dx_cw` | ARRL DX CW | asymmetric DX exchange (state/pwr ↔ DXCC) |
| `arrl_ss_cw` | ARRL Sweepstakes CW | serial+prec+call+check+section (hardest exchange) |
| `arrl_fd` | ARRL Field Day | class + section |
| `florida_qp` | Florida QSO Party | county/state, in-vs-out |
| `in7qpne` | IN/7QP/NE | multi-state QSO party |
| `arrl_digi` | ARRL Digi | grid-based digital |
| `naqp_rtty` | NAQP RTTY | name+state, RTTY (volume) |
| `stew_perry` | Stew Perry | grid + **distance** scoring |
| `na_sprint_cw` | NA Sprint CW | sprint format |
| `ukraine_champ` | Ukraine Championship | **international / Cyrillic** exchange (Unicode path) |
| `arrl_fd_big` | ARRL Field Day (W4TB) | volume stress (~870 KB log) |

## How the oracle works (mostly reference-free)

Ground truth is the **log record itself**, read by `../logdump/logdump.exe` (canonical
`ContestExchange` from `VC.pas`). Verification is *build-agnostic self-consistency*:

1. **Record-derived fields** (ADIF + Cabrillo QSO lines): `../python/verify_adif_export.py`
   checks the export faithfully represents the log record. Run on the CURRENT build's
   export — no D7 baseline needed.
2. **Score**: each QSO record stores its computed points (`LogEntryPointsAddress`) and
   mult (`LogEntryMultAddress`); the score = sum/count over the dumped log. Build-agnostic.
3. **MainUnit-global tail fields + Cabrillo header/summary** (contest-config-derived, not
   in the record) are the ONLY part needing a reference — a small **fresh current-D7 export**
   (deferrable; `verify_adif_export.py` currently scopes the tail out).

## `*.adi` / `*.cbr` here are NOT the golden master

The `.adi` (ADIF) and `.cbr` (Cabrillo) files are **sample D7 exports made at various
points** — versions span v4.127.5 → v4.149.0 (confirmed by their `CREATED-BY` lines).
The old ones predate the 4.147.x ADIF fixes, so they contain since-fixed bugs. They are
kept only as **format references** for developing the verifiers. The authoritative
reference for the tail/header fields, when needed, is a fresh export from a single CURRENT
D7 build.
