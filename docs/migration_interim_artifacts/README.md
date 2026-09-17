# Migration interim artifacts

**READ THESE FOR *WHY*, NEVER FOR *STATUS*.**

Every document in this directory did its job and is finished. They were the
working notes of the Delphi 7 → Delphi 12 → FreePascal/LCL migration: surveys
taken once, plans that were executed, spikes that answered their question, and
comparisons whose decision has been made and acted on.

They are kept because the reasoning is the record of why the tree is shaped as
it is. They are moved out of `docs/` because a plan that reads as current, and
is not, costs more than it gives — this repository has repeatedly lost time to
an agent reading a stale status line and repeating it as fact.

**The live task list is [`../MODERNIZATION_ROADMAP.md`](../MODERNIZATION_ROADMAP.md).**
Archived 2026-09-17.

---

## What is here, and why it is finished

### Superseded roadmaps and strategy

| file | why it is here |
|---|---|
| `ROADMAP.md` | The previous roadmap. Self-flagged stale on 2026-09-08 — "wrong in every row" — and internally contradictory (one section claimed the main-window message proc was both done and open). Replaced by `MODERNIZATION_ROADMAP.md` |
| `D12_MIGRATION_ROADMAP.md` | Explicitly superseded 2026-08-13; its own banner already redirected to `ROADMAP.md`. Its whole CI premise (provision RAD Studio) died with Delphi |
| `tr4w-migration-strategy.md` | The route to Delphi 12. Historical since the 2026-08-13 toolchain pivot; kept for its phase-sequencing reasoning |
| `tr4w-analysis.md` | A 2026-03-13 architecture survey of the **pre-migration D7 tree**. Every count in it was an early estimate, corrected later |
| `PHASE_INVENTORIES.md` | asm / `wsprintf` inventories generated 2026-05-19. Live `asm` is now zero; the inventory script is in the doc if it is ever wanted again |
| `LEGACY_DEPENDENCY_AUDIT.md` | 2026-07-29 read-only audit taken before the legacy radio path was deleted. That deletion completed 2026-08-02 |

### Decisions already made

| file | why it is here |
|---|---|
| `TOOLCHAIN_SWOT_LAZARUS_VS_DELPHI.md` | FreePascal/Lazarus won on 2026-08-13. Its own banner says do not reopen the comparison from this document |
| `FPC_SPIKE_LOG.md` | The spike succeeded and `spike/` was deleted. The harness files it describes no longer exist |
| `VCL_WIN32_COEXISTENCE.md` | A technique for hosting **VCL** forms in the Win32 loop — an abandoned toolchain path. The live equivalent concern is in `BANDMAP_LCL_DESIGN.md` / `PANADAPTER_LCL_DESIGN.md` |
| `FMX Migration Discussion.md`, `FMX_WIN32_COEXISTENCE.md` | FMX was deleted from the tree on 2026-08-17; FPC cannot compile it at all |
| `D12_RELEASE_READINESS.md` | Assessed a Delphi 12 build that was abandoned. Only its *criteria* for "release ready" still apply |

### Work that is complete

| file | why it is here |
|---|---|
| `CFG_ARRAY_ELIMINATION.md` | **DONE 2026-09-14** — `CFGCA` went 415 rows → 0, and `Lint-ConfigArrays.ps1` now fails the build on any occurrence. The body is stale by design; only its top banner was ever current |
| `CFG_MIGRATION_PLAN.md`, `CFG_COMMAND_TABLE.md`, `CFG_REMAINING_ROWS.md` | Artifacts of that same array. A setting is a published property now — see `ADDING_A_SETTING.md` |
| `DISPLAY_STATE_MODEL_PLAN.md` | **DONE 2026-08-29/30** (`src/domain/` + `uStateBridge`). Its own header lagged reality by three days, which is exactly the failure this directory exists to prevent |
| `ACCELERATOR_AUDIT.md` | The measurement was consumed — the unified 97-row table was built 2026-08-17 and both open questions were answered. Its `Dump-Accelerators.ps1` no longer exists |
| `CAPTION_REVIEW.md` | A generated snapshot of every design-time caption. Its purpose — find what ships as literal English — was consumed by the `.lfm` harvest into the catalogues |
| `dialog_analysis.md` | Its three-step recommendation was measured **false** and corrected in place on 2026-08-17. The inventory tables remain useful as a lookup; the plan does not |
| `CORPUS_FRESH_CLONE_DEFECT.md` | **All three of its fixes shipped** (verified 2026-09-17): `tr4w/test/corpus/settings/tr4w.json` is a tracked, corpus-owned fixture carrying `_LOCATION: WCF`, the harness pre-checks it and fails with a named reason, and the app reads it through `--settings`. The LOCATION guard it warned against weakening was correctly left alone |
| `OWED_BEFORE_CROSS_PLATFORM.md` | **Done, and the lints prove it rather than a doc asserting it** (verified 2026-09-17): `uAppPaths.pas` provides the three accessors plus a fourth root the doc never asked for, and `Lint-AppPaths`, `Lint-SearchIndex` and `Lint-OneConfigWriter` all pass. Its one surviving item — ~230 searchable captions that are Pascal literals rather than `resourcestring` — moved to the roadmap's i18n phase |

### Superseded by the shipped design

| file | why it is here |
|---|---|
| `RADIO_FACTORY_README.md` | Dated December 2025. Describes a simple enum-keyed `TRadioFactory`/`TRadioManager`. The tree shipped a **self-registration registry** instead (`uRadioRegistry`, `uFactoryRadioBase`) |
| `NETWORK_RADIO_FACTORY_ANALYSIS.md` | The companion analysis that proposed those options. The registration pattern won |
| `CROSS_COMPILING.md` | A Windows-hosted cross-compile recipe. **We do not cross-compile** (NY4I, 2026-09-11) — `linux-ci` and `mac-ci` build natively, and `Lint-LinuxCompile` was retired because a cross-compile inherits case-insensitive unit lookup from its host and so fails *quieter* than no check at all |
| `WINDOWS_DEPENDENCY_SWEEP.md` | A 2026-09-08 generated sweep whose own instruction was "regenerate rather than trust it". Several rows were already stale within the week (it still scheduled work on the deleted parallel port) |

---

## If you are about to cite one of these

Don't. Measure instead — `MODERNIZATION_ROADMAP.md` §0 lists the oracles, and
each one answers in seconds. The numbers in this directory range from days to
six months old, and several were wrong when written.
