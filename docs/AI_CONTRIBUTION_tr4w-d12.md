---
project: TR4W (TRLOG 4 Windows) — branch `delphi12`
one_liner: A free contest logging program for Windows that does dupe checking, live scoring, band mapping, CW/FT8 sending, and radio control for 120+ contests, with the whole exchange typed into one field.
language_stack: Object Pascal (Delphi), ~172k lines across ~117 units, direct Win32 API (no VCL); Python + bash test harnesses; PowerShell/NSIS build scripts.
base_or_fork: Not greenfield. TR4W is a long-running open-source app (history back to 2014-04) descended from N6TR's DOS-era TRLOG — the `src/trdos/` layer is that original engine ported to Windows. The AI-assisted work documented here is one branch (`delphi12`) off that codebase, not the codebase itself.
repo_evidence: >
  git log 1,879 commits total (2014-04-25 → 2026-07-11). No CHANGELOG (normal for this repo;
  it documents via `tr4w/docs/*.md` and commit bodies instead). ~172k lines of Pascal source;
  ~9.3k lines of test code (`tr4w/test/`) plus a 13-set binary golden-master corpus.
  AI attribution: the D12 work IS attributed, but via a non-standard trailer — `Claude-Session:
  <url>` appears in 60 of the 82 commits on `master..delphi12` (2026-07-03 → 2026-07-11), all
  pointing at one session ID. A conventional `Co-Authored-By: Claude` trailer appears on only 4
  commits, and all 4 are on `master`, unrelated to this branch (HamLib factory work, 2025-12;
  a translation pass, 2026-05). Every D12 commit is authored "Tom Schaefer" — the trailer marks
  AI assistance, not authorship. I also read this project's agent-memory directory
  (`~/.claude/projects/c--tr4w-d12/memory/`), which records human decisions and AI corrections;
  that is agent-side evidence, not repo evidence, and every claim sourced from it below was
  re-verified against a commit before being stated. The ~22 D12 commits without the trailer
  include the most recent ones; for those, AI involvement is inference from commit shape.
---

## What AI helped build or change

- **Ported the app from Delphi 7 to Delphi 12 Athens** — the branch's whole reason to exist. 82 commits, 2026-07-03 (`22d4240` "Delphi 12 Phase 1") → 2026-07-11, 282 files changed. The hard part is that D12 strings are UTF-16 while this code assumed 8-bit `ShortString`/`PAnsiChar` everywhere, so every byte-oriented path had to be found and fixed.

- **Fixed real byte-corruption bugs the compiler change exposed in radio control.** `8e0bb61`: `TSerialPort.WriteString` did `Write(S[1], Length(S))`, which under D12 sent `F<00>A<00>` instead of `FA` — that breaks *every* serial-connected radio. `df0017a`: the Icom LAN transport carried CI-V frames in UTF-16 buffers, corrupting the login packet's sequence patch (radio stuck at WaitingForLogin) and mangling any byte ≥ $80 ($99 became U+2122).

- **Built the regression safety net that made the port checkable at all** (`ddb32cd`, `c1392ca`, `61e7eb1`): a golden-master corpus of 13 real contest logs (ARRL DX CW, Field Day, Sweepstakes, IARU HF, ARKTIKA…) where the D12 build re-exports each log and byte-diffs the Cabrillo and ADIF against frozen Delphi 7 output. Baseline is 22 passed / 0 failed / 4 known-divergence (`tr4w/docs/D12_BUILD.md:69`). This is what lets a ham trust that a compiler change didn't quietly alter their log.

- **Found a latent out-of-bounds bug that predated the port** (`b7648de`): FM contacts indexed one slot past the multiplier arrays. D7's release build had range checks off and did it silently for years; D12's build had them on and errored on the first FM QSO (Winter Field Day, 2m FM). Fixed the write sites, and confirmed a 1,316-QSO W4TA log then exported byte-for-byte identical to D7 including claimed score.

- **Fixed the multi-language build** (`8dd9ef8`, `1ff2053`, `49637d4`): the 11 UI-string files were legacy 8-bit with no BOM, which D12 decodes using whatever codepage the *build machine* happens to use — silently mangling non-English text. Transcoded 9 files to UTF-8+BOM using each language's true codepage. All 8 non-English variants now build clean; Polish and Chinese remain excluded as known-corrupt.

- **Deleted a large amount of genuinely dead code**, each removal compiler-confirmed: 25 unused units (`e709c89`, `45a9c83`) and ~55 unused functions (`d9d2ed3`, `ea55652`, `91946aa`). Net across the branch: 71k insertions vs 96k deletions.

## Where the human stayed in control

- **NY4I defined the finish line, not the AI.** The done-criterion for the string work is his: eliminate `PAnsiChar(AnsiString(...))` double-casts *except* where a real Win32 or binary/radio boundary requires one. That's a greppable test the human can audit — recorded in the project memory as his definition and visible in the commit series (`3df372e`, `a3b4da1`).

- **The human repeatedly said "not yet" to AI-proposed scope.** He deferred the MainUnit log renderer conversion to a later SQLite phase (converting it now would spray decodes across ~15 fields), deferred telnet socket-I/O centralization, and accepted one tagged exception rather than let the AI chase purity. Those deferrals are documented in `tr4w/docs/D12_STRING_MODERNIZATION_PLAN.md` and the memory notes.

- **Hardware testing was the human's gate, and it caught what tests could not.** The Icom fix (`df0017a`) is marked "Validated on hardware: IC-7760 network connects and freq/mode/RIT/XIT/split all work." No unit test in this repo can assert that.

- **Domain knowledge came from the human.** `61e7eb1` is explicitly "per NY4I guidance": because these exports go to contest sponsors (Cabrillo) and other loggers (ADIF), he required a *validity* gate — output must be 7-bit ASCII, no NULs — separate from the fidelity diff. That gate catches corruption with no reference file at all, and it immediately caught UTF-16 `END-OF-LOG` bytes at `PostUnit.PAS:2621`.

- **Process discipline imposed after AI mistakes.** Two examples now enforced mechanically: a PreToolUse hook forces the `git -C` command form, and the corpus rule "run it, READ the result, THEN commit" exists because chaining them hid failures.

## A concrete example (the "wow" moment)

Reconstructed from commit `b7648de` and its message — **the original ask is not recorded in the repo**, so treat the phrasing as inference. The observable facts: the D12 build range-errored on the first FM QSO of a Winter Field Day log. Rather than switch range checking off and move on (the junior fix — and D7 had indeed shipped with it off for years), the work traced it to a real out-of-bounds write: FM's mode ordinal falls outside the multiplier arrays, the *readers* already remapped FM→Phone but the *writers* never did. It fixed the write sites, matched D7's range-check settings deliberately rather than accidentally, and then proved the fix with the oracle — a 1,316-QSO log exporting byte-for-byte identical to Delphi 7, claimed score included. The verification is the wow, not the diagnosis: a human can check "identical to the old build" without reading a line of Pascal.

## What AI was BAD at / where it was wrong

- **Confidently transcoded Serbian with the wrong codepage** (`8dd9ef8`, fixed in `1ff2053`). The AI trusted `FullBuild.ps1`'s language table, which says `Name='Serbian (Latin)'` but `CodePage=1251` — self-contradictory, and the 1251 is a bug in that table. The tell it missed: the Serbian file has ~22 non-ASCII bytes, while a genuinely Cyrillic file has ~13,000. It had used a "the decode didn't throw" heuristic instead of reading the decoded words. Corrupting a translation is exactly the kind of thing that ships unnoticed to non-English users.

- **A prior agent tried `{$CODEPAGE nnnn}`, which is FreePascal-only — Delphi rejects it with E1030.** It had to be reverted, and the wrong guidance survived in the checked-in plan doc until `636e064` corrected it. Plausible-looking, wrong, and it outlived the mistake in documentation.

- **The AI would have accepted an ambiguity the human caught.** Replacing `TF.StrToInt` with `StrToIntDef(s, 0)` is behavior-preserving across all ~114 call sites — correct as far as it goes. NY4I pointed out the returned 0 is ambiguous: it means either "the input was '0'" or "the parse failed." The swap preserves that ambiguity rather than fixing it. The AI was optimizing for "don't change behavior" and needed a human to name what the code should *eventually* do (a sentinel like `Low(Integer)`), separate from the mechanical change.

## Reusable pattern (for cross-project synthesis)

- **Build the oracle before the refactor.** The single highest-value thing on this branch isn't a fix, it's the golden-master corpus: real user data in, byte-diff against the known-good old build out. It converts "the AI says this refactor is safe" into a check the human can run and read in one line. On a codebase whose core engine has no unit tests, that was the only honest way to move.

- **Two gates, not one: is it valid, and does it match?** Fidelity-vs-reference catches regressions; a separate validity gate (7-bit ASCII, no NULs) catches corruption even where no reference exists. Domain-specific, human-supplied, and it caught a real bug immediately.

- **AI is strong at breadth, weak at knowing which authority to trust.** Sweeping 172k lines for byte-oriented string bugs is exactly what it's good at. Deciding that a checked-in config table is *itself* wrong about Serbian required reading the actual data — the AI reached for the convenient authority instead. The generalizable rule: make it verify against ground truth (the bytes, the hardware, the exported file), never against another document.
