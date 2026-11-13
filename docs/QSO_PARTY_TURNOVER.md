# QSO party turnover — 2026-11-13

## Stop point and integration

NY4I asked to stop new-party work here, prepare this worktree for another
agent to bring into main, and resume the remaining parties after the session
limit resets. Do not start more parties during integration. Do not use Graphify.

- Worktree: `C:\tr4w-d12\.worktrees\new-qso-parties`
- Branch: `codex/new-qso-parties`
- Common ancestor with main: `58678f7393312f8f9fded1183f2e1fed7f40ad35`.
- Main was at `68e0a232` during preparation. Its licence-year/schema-8 work
  and `8706893b` are not on this branch. Rebuild and rerun checks after integration.
- Main's checkout contains unrelated tracked and untracked work, including
  `TRMASTER.DTA` and documentation. Preserve it. No merge/rebase, push, PR or
  issue closure has been performed by this agent.
- Integration should take the complete branch, including source-rule data,
  shared test helpers, generated matrix records and documentation. Do not
  copy only leaf classes. Review conflict resolution against both parents.

Validation results and the final commit are recorded below when preparation
finishes. `build-out/` logs are local ignored evidence, not shipped artifacts.

## What is added

Five new registered parties: Alabama (`AL-QSO-PARTY`, #114), New Jersey
(`NJ-QSO-PARTY`, #124), West Virginia (`WV-QSO-PARTY`, #131), Arkansas
(`AR-QSO-PARTY`, #115), Kentucky (`KY-QSO-PARTY`, #110).

Each leaf derives directly from `TContestStateQSOPartyBase`, registers by
string ID and owns its rules and DOMs. No new frozen enum member or CFG.
Saved sponsor originals and transcriptions accompany the data. The shared
`uTestQSOPartyEngine` fixture supplies isolated real parser/sheet sessions;
`EnterPartyQSO` is reused rather than copied into older party tests.

Current-batch shared changes:

- Bonus counting uses one view scan for all declared scopes, including new
  `bsPerQSO` for Arkansas's WR5P (200 per valid contact). Existing once,
  per-mode and per-band/mode semantics remain covered by tests.
- State-party bonus matching strips only verified trailing county suffixes;
  portable/district suffixes remain. Ontario club-station scoring reuses the
  same helper. WV W8WVA/BAR and NM W1AW/5/BER now pay their declared bonuses.
- Wisconsin LOW x1.5 / QRP x2, standard Free Pascal `Round`, before adding
  bonus points: NY4I #88 comment 6861756129. Typed WI DX refusal is still open.
- Shared live-entry string-key ordering is unchanged. An attempted earlier
  global reorder broke refusal behavior in unrelated contests and was reverted.

Architecture and detailed history: `QSO_PARTY_ADDITIONS.md` and
`CONTEST_OWNERSHIP_DESIGN.md`. Screen/3830 work: `BENCH_QUEUE.md`.

## Specialist handoff: double domestic multipliers #317

NY4I explicitly assigned this broader engine work to the Claude specialist
agents. Issue #317 has been updated with all affected additions and paths:

- AL: current local implementation uses a prefix/string key for extra AL,
  per mode. It must migrate to proper domestic keys/totals/needs displays.
- WV: same interim approach for extra WV, once overall; also must migrate.
- KY: NY4I #110 comment 6862605577 confirms county + KY state. The new leaf
  **does not implement the extra KY credit** and does not add another prefix
  workaround. Its current 183 in-state keys become 184 after #317.
- SC (#111/#113) is already listed on #317 and remains unimplemented here.

The shared `CountyStateMultiplierKey` only computes a validated county's host
key; it is not an implementation of multiple domestic multipliers. AL/WV
tests currently expect the interim prefix flags and must migrate with the
leaves. Passing tests do not certify correct domestic multiplier UI.
Arkansas explicitly excludes AR from its 49 state multipliers; NJ excludes
NJ and never receives DC (NY4I). Neither should gain an extra host-state key.

Other explicit dependencies: own-mobile/category support and activation
bonuses (#133/#87); Arkansas mobile/portable/rover two-point scoring;
successful submission/live-stream bonuses require facts not stored by the
logger and remain adjudication adjustments. KY uses the **2027 draft** by
NY4I's direction, not an assumed finalized 2026 rule set.

## Remaining punchlist — resume later

Ten events remain without registered classes:

- South Carolina #111/#113 (one event)
- Atlantic Canada #116
- Canadian Prairies #117
- Hawaii #118
- Illinois #119
- Iowa #120
- Kansas #121
- Louisiana #122
- Mississippi #123
- South Dakota #129

`QSO_PARTY_CHALLENGE_COVERAGE.md` maps all 46 Challenge events. Registered
coverage is 36/46 locally versus the audited v5.0.40 release's 31/46. This is
not a claim that every category, screen, report or sponsor rule is complete.
IN7QPNE already combines Indiana, 7QP, New England and Delaware; all four
also have standalone registrations. The combined option is not a 47th event.
Do not contact the Challenge team claiming all 46 are supported yet.

Important retained rulings:

- SD #129: FT4/FT8 contacts x distinct four-character grids is a separate
  digital score, added to CW/phone geographic scoring. No digital county
  requirement/credit, no grid-centre inference; DX entrants may work SD digital.
- WV #131: all multiplier kinds once overall, without repetition by mode.
- KY #110: approved 2027 draft, and extra KY state confirmed/deferred to #317.
- #88 still has older unresolved BC retired-alias and Missouri electronic
  submission-bonus questions; `Agent Question` remains there.

Post issue findings/comments as authorized. Put genuine questions on the
issue with `Agent Question`; remove it when all questions there are answered.
#110's questions are resolved and its label has been removed. No requests
were closed merely because a class compiled.

## Local PDF converter and research tools

Use the local checkout **`C:\projects\pdftomarkdown`**, never an unqualified
`npx pdftomarkdown` (that resolves a different cloud OCR product).
Codex's `pdftomarkdown` MCP entry runs Bun with the explicit local
`bin\cli.js --mcp`; tool: `convert_to_markdown`. CLI fallback:

```powershell
bun C:\projects\pdftomarkdown\bin\cli.js input.pdf -o output.md
```

Conversion was verified on all four WV pages with network access disabled,
and on the KY/AR county tables. Verify tables independently against the
original PDF before making DOM data. Keep originals beside Markdown.

The separate converter repo has **uncommitted** runtime compatibility changes
in `src/lib/pdfConverter.ts` and notes in `README.md`; they are not part of
this TR4W branch. Its `bin/cli.js` was already dirty and was preserved:
SHA256 `7F64A0B143458DB7D31FDEC6161B2DDAC91B7F394BF8F4CC76ADE4A99EDF1288`.
Runtime dependencies were installed with Bun without manifest/lock changes.

Read installed DXLog definitions at `C:\Program Files (x86)\DXLog.net\Contest`.
Reuse `tools/dom-crosscheck/crosscheck_dom_dxlog.py`; NY4I directs using
`CABRILLO_CONTEST_NAME` when the sponsor is silent. Rules override scoring
differences in DXLog. The field reference is currently an untracked file in
the base checkout: `C:\tr4w-d12\docs\DXLOG_CONTEST_FIELD_DEFINITIONS_REFERENCE.md`.
Arkansas's server returns 406 to some clients; Bun `fetch` retrieved its
public documents successfully. Do not substitute another event's rules.

## Validation at turnover

Preparation in progress; replace this paragraph with the final results before
handing over. The full unit suite passed 480,898 checks, zero failures. The focused
run passed 7,097 checks across 12 suites.
The full app build passed with 3/3 range and 1187/1187 narrowing warnings;
all 58 lints passed. Full unit/matrix/export gates are being finalized.

Use `C:\Program Files\Git\bin\bash.exe` for shell scripts, not PATH's WSL
`bash`. Matrix and corpus runs must be sequential. Respect the running-TR4W
guard; never kill an operator's app. Only generate frozen records with the
freeze script and a reason. Preserve `.matrix` CRLF bytes and Pascal BOMs.
Whitespace check: `git diff --check -- . ':!*.matrix' ':!*.html'`.
