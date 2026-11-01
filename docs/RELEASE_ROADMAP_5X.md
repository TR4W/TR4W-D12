# Roadmap to a public TR4W 5.x release

Written 2026-11-01 at `main` = `0371650c`. Version in the tree: 5.0.36 (a GitHub DRAFT; 5.0.35 is Latest).

**What this is.** A single list of what stands between this tree and "download TR4W 5.x from
tr4w.net". It is built from the issues opened since 2026-10-04 (66 issues, 39 still open), the
living lists (`docs/BENCH_QUEUE.md`, `docs/RADIO_BENCH_STATUS.md`), the contest-factory documents
(M10/M11 plans, open questions, Codex review, pointer audit) and the platform documents
(`MODERNIZATION_ROADMAP.md`, README, installer/wizard designs, `PORT_IDENTITY_PLAN.md`).

**What this is not.** It is not a replacement for `MODERNIZATION_ROADMAP.md` (last edited 2026-09-17, now
mostly overtaken) or for `BENCH_QUEUE.md` (the unfiltered backlog). Counts below are measured on the date
above and will drift; the commands to re-measure them are in section 9.

**How to read the labels.** "Fact" items cite a file, issue or commit. Everything marked *Judgment*
is a recommendation from the author of this document, not a finding. NY4I decides.

---

## 1. Where things stand

| | |
|---|---|
| Published | v5.0.35 is Latest (2026-10-27). v5.0.36 is a Draft. Drafts 5.0.31-34 also exist. |
| tr4w.net | Serves D7 4.x only (CLAUDE.md). Nothing in the tree says how, or when, it switches to 5.x. |
| Platforms that build | Windows i386, Linux x86_64 (AppImage + tarball), macOS aarch64 (signed, notarized `.dmg`/`.pkg`). CI run 41279930661 was green on all three, Linux unit tests 407,672 passed and 0 failed. |
| Windows tests | 420,730 unit tests passed, 0 failed. 52 lints. Corpus, ADIF round trip and matrix green at their last recorded gates. |
| Contests | About 195 registered (188 enum-keyed, 8 by string id; approximate). Matrix: 194 identical. M0-M10 of the factory migration are complete. |
| Issues | 105 open in total: 39 from the last four weeks (18 are unbuilt QSO-party requests) and about 66 older. |

**Fact worth noticing:** 5.0.35 cannot join a protocol-2 multi-op network (no HELLO message), so a release
that is meant to do multi-op needs 5.0.36 or later.

---

## 2. The first decision: what is "the release"?

Nearly every blocker below depends on this, so it comes first.

| Option | What it means |
|---|---|
| **A. Windows 5.x replaces 4.x on tr4w.net; Linux and macOS are published on the GitHub page as previews** | Linux/macOS limitations become disclosures, not blockers. |
| **B. All three platforms are presented as equals** | The Linux/macOS CW-keying and serial-port placeholders become blockers (section 4). Months, not weeks. |

*Judgment:* A. The Linux and macOS builds work for network radios and CAT, but CW element timing off
Windows is a plain `Sleep` that will not key a contest, serial ports are not selectable there, and nobody
has run the macOS GUI. Everything in section 3 assumes A.

---

## 3. Release gates (under option A)

A gate is something that has to be true before the 4.x download is replaced. Each says who must do it.
Items marked **[NY4I]** need the operator; **[agent]** can be done without hardware.

### G1. Upgrade from 4.x works on a real station's files **[NY4I]**

The whole purpose of the release is to replace 4.x, and the first thing a 4.x operator does is open their
old files. None of this has been run by a person (BENCH_QUEUE §18 at `:3139-3205`, `:3251`, `:4354`, `:4388`):

- a populated `tr4w.ini` converted once (`tr4wconvert`), with band-plan seeding;
- an existing contest `.cfg` opened;
- a real 4.x `.TRW` log migrated into SQLite;
- accented text surviving the `TF.Format` change.

### G2. A contest logged start to finish by a person, on the SQLite path **[NY4I, in progress]**

BENCH_QUEUE `:4330-4358` still lists "log a contest properly", Alt-Y, Edit-QSO in a log longer than the
window, and Create-a-new-contest as never seen by a person (the last was called the riskiest of its batch).
NY4I is running RTC 2026 live today with HamScore, which exercises most of this. *Judgment:* when the
RTC log is finished, walk those four items and tick them in the queue so the evidence is recorded.

### G3. A clean machine: install, first run, upgrade over 4.x, uninstall **[NY4I or a second person]**

- The installer has **no bench item at all** (BENCH_QUEUE mentions it only for a `dom\*.dom` wildcard).
- The first-run setup wizard is **design only** (`SETUP_WIZARD_DESIGN.md:3`). The roadmap's own exit test is
  "a new operator with an empty directory can configure TR4W and log a QSO without editing a file by hand"
  (`MODERNIZATION_ROADMAP.md:631`). Nobody has run that test.
- *Judgment:* run the test once on a clean Windows machine. If it passes, the wizard moves to section 6. If
  it fails, the wizard (or a minimal first-run prompt for call sign) becomes a gate.

### G4. A second operator, and a two-radio operator **[NY4I to recruit]**

NY4I's own note: more testing by a two-radio operator is needed. *Judgment (my reading of "tro-radio"):*
an SO2R operator. Things only they can judge:

- SO2R switching and focus-follows-radio (`uRadio12`), `KeyersSwapped`, the interlock;
- YCCC SO2R+ box (BENCH_QUEUE `:3137`, HID box never run);
- CW on two radios with CW-by-CAT messages extended mid-send (`:4239`);
- the second operator's first-run experience (feeds G3).

### G5. Scoring accuracy: finish the QSO-party audit and settle the owed rulings **[agent + NY4I]**

- **#88** (audit every state party against DXLog.net) is the biggest correctness exposure. Rounds 1, 2 and 3a
  have landed (`250d97da`, `32ba62ab`, `5643dd52`: Missouri, California, BC, Florida, Wisconsin, rover
  dupes, DX caps). Round 3 is still building. *Judgment:* finish the round in flight, then re-run the
  audit once and record which parties are verified, so the release notes can say so.
- **Rulings only NY4I can give** (`CONTEST_FACTORY_OPEN_QUESTIONS.md`, index near `:33-37`): Q8 (ten dropped
  cfg-only point methods), Q10 (withdraw the MINITEST and SOUTHAMERICANWW retirements?), Q70 (UA4W zone),
  Q111 (IRTS: D7 scored every QSO 10; the recommendation is the orphaned arm 8/4, 2/1, 0), Q40 (county-line
  limits not checked against D7). These are cheap and they change scores in contests D7 users already run.
- **County-line refusals** (BENCH_QUEUE `:4685-4739`: FQP, Michigan, California, Indiana) are new behaviour
  that changes what an operator can log. Bench them.

### G6. Destructive defaults **[agent, then NY4I]**

BENCH_QUEUE `:2724-2727`: Yes/No prompts must default to No, and 15 of 16 call sites are unverified. This is
a short, mechanical check, and a wrong default deletes data. Do it before release.

### G7. Multi-op: ship it labelled, or bench it **[NY4I]**

Phase 1 (protocol 2/HELLO, program-owned link, offline resend, insert-only catch-up, restock, share-spots)
is built and partly confirmed on real hardware on 2026-10-29: Windows restocked an empty TR4WServerPy on a
Pi with 83 QSOs and Mint caught up all of them; a spot reached the server and the Windows band map.

Still open: the rest of the Phase 1 bench list (BENCH_QUEUE `:26-270`, `:274`, `:369`, `:474`, `:1375`,
`:1434`), multi-op PTT/paddle settings sync (listed as safety-relevant, `MODERNIZATION_ROADMAP.md:651`), and
issue #149 part 2 (the in-tree `tr4wserver` once exited with no crash line).

*Judgment:* either run that list on the Mint + Windows + Pi rig, or ship multi-op as "beta" in the release
notes. Do not leave it unmarked: 4.x/D7 clients are deliberately refused by protocol 2, so a 4.x multi-op
shop cannot mix versions.

### G8. The release mechanics **[agent drafts, NY4I approves]**

- There is **no documented procedure for switching tr4w.net from 4.x to 5.x, nor a fallback to 4.x**. Write
  one (where the files go, what the download page says, how 4.x stays reachable).
- `RELEASE_WORKFLOW.md` section 6 still describes `v4.*` tags and a `4.147.18` example. Refresh it for 5.x.
- Decide the fate of the DRAFT v5.0.36 and cut 5.0.37 (the plan on the table: after Linux/Mac testing).
- Release notes must carry the disclosures in section 4.

### G9. Today's test pass closes three items **[NY4I]**

Fixed on `main`, awaiting a real run: **#142** (Linux status strip; builds deployed to Mint), **#143** (secret
store, Linux libsecret and macOS Keychain; builds deployed to Mint and mac-ci), **#150** (callsign read from
the connect thread, fixed in `138ba74d`, pinned by tests; open only because nobody closed it). Also the New
Contest left-pane fix (`530725dd`) on NY4I's machine. Close them as each is confirmed.

---

## 4. Disclose in the release notes (not gates under option A)

| Limitation | Source |
|---|---|
| Linux and macOS cannot key CW (element timing is a `Sleep` placeholder; `uHPTimer.pas` has the measuring half only) | `PLATFORM_CLOCK_ABSTRACTION.md` part 2; `uHPTimer.pas:21-27` |
| Linux/macOS cannot select a serial port (`Addressable := False` in `ComPortEnumerator.pas:985,1110`; port-identity steps 3-6 unbuilt) | `PORT_IDENTITY_PLAN.md` |
| HamLib-backed radios do not work from the AppImage (HamLib is not bundled) | CLAUDE.md |
| macOS GUI has never been run by a person; Win64 GUI unrun beyond headless | README, roadmap |
| Radios: one verified rig per family for Elecraft serial/network, Kenwood serial, Icom serial and LAN (two models, 7 h 52 m soak), Flex CAT, Yaesu binary. **HamLib, Yaesu ASCII, Kenwood LAN and ~89 of 99 models are untested.** CLAUDE.md still says Icom LAN is unproven; that is out of date. | `RADIO_BENCH_STATUS.md` |
| Translations: reviewed text only in part. Most catalogues are 60-99% fuzzy, and fuzzy text ships by design (`-ReviewedOnly` reverses it). Chinese is salvage-only. | `.po` counts, CLAUDE.md |
| Mobile, expedition and 1x1 station categories do not reach scoring (#133) | issue |
| Rover: cannot change our own county or grid mid-contest (#87) | issue |
| Serial numbers in Cabrillo are not padded to the log's width (#91); a DX entity may print empty in the received column for Tennessee, Wisconsin, PACC (#139) | issues |
| Backups are local and beside the log, with a shared name (#98) | issue |
| CW thread, WinKeyer reader and DVP playback touch the UI off the main thread (#132): worked on Windows for years, riskier on gtk2/Cocoa | issue |
| Multi-op: a late catch-up can skip a QSO whose author left on a different build (#146, counted and logged) | issue |
| WAE QTC windows have no operator who has judged them (owed to N4AF) | `QTC_BENCH_HANDOFF.md` |
| 18 requested QSO parties are not built (section 7) | issues #110-#131 |

---

## 5. Can follow after release

**Contest factory.** M11 S1 and S9e part 2 are internal cleanup that changes nothing an operator sees. **S8**
(moving the initial-exchange prefill into 46 contest classes) is the only remaining stage that touches
operator-visible behaviour, and it has no automated oracle (plan `:2042`: "risk: high"). Do not rush it.
Also: the guide-gap edits to `ADDING_A_CONTEST.md` (about 15 items), Codex R3's start-up ordering, and
NY4I's planned acceptance test of adding an unsupported QSO party by hand from Part A.

**Pointer audit (#89).** P0-P2, P4-P8, P10, P12 and P15 are done; P14 was skipped by decision; the rest is
code health.

**Platform work.** Delay half of the clock abstraction (CW keying off Windows); port identity steps 3-6;
HamLib `$ORIGIN`/bundling; AppImage `libsecret-1.so.0` in the dlopen list if `--deps` reports glib; a visible
in-app message for a locked vault (today only a `[Keychain]` log line).

**Other.** Setup wizard (if G3 passes); menus/action lists; accelerators; the `-O` decision (the program is
compiled unoptimised); the `Move`/`FillChar` sweep; i18n cutover, the Weblate review pass and the VC.pas
string cutover; control channel; installer symbol-size work; the HamScore dedup result; rotating the HamScore
and multi-op passwords.

---

## 6. Issue ledger

Open issues since 2026-10-04, other than the QSO-party requests. "Fixed" means fixed on `main` but not
closed.

| # | Subject | Status | Disposition |
|---|---|---|---|
| 85 | IN7QPNE county-line limit follows the county's party | deferred by NY4I (Q82) | after release |
| 86 | IN7QPNE per-party score display | deferred (Q77/Q78) | after release |
| 87 | Rover: change own county/grid | open | disclose |
| 88 | State-party audit vs DXLog.net | rounds 1, 2, 3a landed | **G5** |
| 89 | Pointer audit | mostly fixed (see section 5) | after release; update the checklist |
| 91 | Pad Cabrillo serials | decided, not built; changes exported bytes | disclose, or build with corpus pins |
| 93 | Add RUS-WW-DIGI | open | after release |
| 94 | Typed `rcvd_*` columns never written | open | decide before the schema is relied on, because dropping is cheaper early |
| 98 | Backups to a remote location + Restore | design only | disclose |
| 132 | Off-main-thread UI writes | open | disclose |
| 133 | Station category not scored | open | disclose |
| 139 | DX Cabrillo received column | lead, not traced | investigate; disclose until then |
| 140 | Test framework: one exception ends the run | open | after release |
| 142 | Linux status strip | fixed (`b88a0fdf`) | **G9**, close after the Mint test |
| 143 | No secret store on Linux/macOS | fixed (`8e236098`, `451c305d`, `21ff8392`) | **G9**, close after tests |
| 144 | i18n: no safe way to retire a string (`po_prune` would obsolete 2,168 live entries) | open | after release; warn people off `po_prune` |
| 145 | `.lfm` captions in no catalogue | open | after release |
| 146 | Multi-op: name the contest in the QSO record | open by design | disclose |
| 149 | In-tree server restock slow; one unexplained exit | part 1 fixed (`138ba74d`, 150 s to 3.8 s); part 2 open | **G7** |
| 150 | Connect thread reads the callsign field | fixed (`138ba74d`) | **G9**, close |
| 151 | Audit Tab order of every Preferences page | HamScore done (`562b41ca`) | after release |

**Housekeeping:** #111 and #113 are the same request (South Carolina); close one.

**Older open issues (about 66).** Titles only, not verified: #13 (ARRL-section contests store `EM` for `EMA`),
#37 (`cmDIGITAL` maps to `RTTY`), #28 (next serial jumps after a multi-county entry), #53 and #54 (Croatian 9A
points), #55, #56, #79 (ARRL 10 and RSGB-IOTA multiplier displays), #15 and #35 (Cabrillo coverage, RSGB-ROLO
validation), #44 (Multi-Unlimited serial per band), #34 (K4 split error with VFOs in different modes). None is
titled as data loss or a crash. *Judgment:* read #13, #37, #53 and #54 before release as the likeliest
wrong-score or wrong-Cabrillo items.

---

## 7. QSO-party requests (#110-#131)

Built and closed: New Mexico (#125), Oklahoma (#126), Ontario (#127), Quebec (#128), plus Georgia and North
Dakota earlier. **Open, unbuilt (17 parties in 18 requests):** Kentucky, South Carolina (#111, #113),
New Hampshire, Alabama, Arkansas, Atlantic Canada, Canadian Prairies, Hawaii, Illinois, Iowa, Kansas,
Louisiana, Mississippi, New Jersey, South Dakota, Vermont, West Virginia.

These are missing features, not defects. The plan of record is the batch in calendar order using the Georgia
template (memory `qso-party-batch-2026-10-26`). A contest that D7 offered and 5.x does not is a regression;
a QSO party that never existed in D7 is not. *Judgment:* check which of the 17 were in D7 and build only those
before release. The exact D7-versus-registry diff has not been done (`CONTEST_FACTORY_OPEN_QUESTIONS.md` Q10
says D7 offered every `ContestType`; run that comparison).

---

## 8. Stale documents found while reading (fix in a separate commit)

| Document | Problem |
|---|---|
| `MODERNIZATION_ROADMAP.md` | Dated 2026-09-17. Contest-factory section predates M0-M10; the "176 bench items" figure is now over 400; decisions #1-4 are partly overtaken. |
| `BENCH_QUEUE.md` | About 420 unchecked items. Stale sections: `:4183-4191` ("multi-op sync does not work, on purpose": superseded by Phase 1), `:4220-4237` (Icom LAN timer run: fixed and soaked), `:3174` and `:3237-3249` (CFGCA and `crS` are gone), `:2790-2807` (header dated 2026-08-24). Not read by the audit: `:1451-1514`, `:4538-4676`. Unfiltered; consider a pass that moves each item to "blocks release / after release". |
| `RADIO_BENCH_STATUS.md` | Footer says "5 with a test report"; ten rows carry a date. |
| `CLAUDE.md` | Says Icom LAN is unproven (a two-model soak passed 2026-09-27); says "no QSO has been logged" on Linux (unverified either way). |
| `README.md` | Linux test count (19,883) and the macOS unit-test access-violation note are from September; CI now reports 407,672 passed on Linux. |
| `RELEASE_WORKFLOW.md` | Section 6 is the D7 `v4.*` flow. |
| `CONTEST_FACTORY_CODEX_REVIEW_2026-10-23.md` | R1 is marked "still open" (`:210`) but Q119 records it built and merged (`47f85440`). |
| `POINTER_AUDIT.md` | Checklist is behind the fixes. |
| `SETUP_WIZARD_DESIGN.md`, `I18N_PLAN.md`, `ADDING_A_LANGUAGE.md` | Status lines dated August. |

---

## 9. Suggested order

1. **Now to the end of the RTC weekend:** NY4I tests the Linux/Mac builds (G9) and logs RTC (G2). Close #142, #143, #150 as confirmed.
2. **In parallel, no hardware needed:** finish #88 round 3 (G5); the destructive-default check (G6); the tr4w.net switch procedure and the `RELEASE_WORKFLOW` refresh (G8); read the four older issues in section 6; the D7-versus-registry contest diff (section 7).
3. **NY4I rulings, one sitting:** Q8, Q10, Q70, Q111, Q40; the option A/B choice in section 2; the draft 5.0.36 fate.
4. **Recruit and run:** clean-machine install and first run (G3), the 4.x upgrade files (G1), the SO2R operator (G4).
5. **Multi-op:** run the Phase 1 list or label it beta (G7).
6. **Cut 5.0.37** with the disclosures from section 4; then decide the tr4w.net switch.

**Re-measure commands.**

```sh
gh issue list --repo TR4W/TR4W-D12 --state open --limit 300 --json number | jq length
rg -c '^\s*- \[ \]' docs/BENCH_QUEUE.md
rg -c '^#, fuzzy' i18n/tr4w_*.po
gh release list --repo TR4W/TR4W-D12 --limit 10
```

## 10. What was not checked

- The bodies of the roughly 66 older open issues (titles only).
- Whether #88's remaining rounds are complete beyond the commit subjects.
- Which of the 17 unbuilt QSO parties existed in D7.
- Whether the first-run experience works today (no wizard; untested).
- Two BENCH_QUEUE ranges (section 8) and most of `BENCH_TEST_PLAN_2026-08-01.md`.
- Docs line numbers move; re-find a cited item by its heading if a line number is off.
