# Why a `rescored.*` baseline was re-frozen

`rescored.adi` / `rescored.cbr` are TR4W's OWN output (see the header of
`freeze-rescore-baseline.sh`), not an independent reference. Since `/NOFACTORY`
was deleted (2026-09-29, `20943bc1`), a re-freeze writes the factory's own bytes
into its own gate, so **every re-freeze needs a written reason here, per set, in
the same commit as the new bytes**. The D7 `ref.adi` / `ref.cbr` are never
regenerated, and nothing here touches them.

Each entry gives: the date, the set, what changed, why the change is
intended, and how it was checked.

---

## 2026-11-05 -- issue 206: the baselines had frozen the developer's station

**The cause, for both sets below.** The 2026-09-29 freeze ran the app without
`--settings`, so it read the developer's own `tr4w.json`. Its `settings.My`
held `Grid EL88`, `State FL`, `Zone 5` (his CQ zone), `ItuZone 8` and
`Name TOM`. Under `/RESCORE` and `/EXPORT` only the `settings` section of a
settings file is read; the legacy `commands` bucket is not imported. So the
corpus fixture's `MY ...` rows never reached a run, and those personal values
were frozen into every set.

**The proof.** Run against a scratch copy of the fixture carrying that `My`
block, the current build reproduces **all 13** frozen baselines byte for byte.
So the factory's scoring did not change, and today's IARU commits (`30b76edb`,
`46593a4e`) moved nothing here.

**The fixture fix (`5868115e`) took eleven sets back to identical.** It gave
`settings.My` the grid only. Ten sets differed only in the
`GRID-LOCATOR: EL88` header line, and `arrl_digi` already matched. The other
station facts stay out of the fixture, because each one moves an export away
from its D7 reference (`README.md`, "The settings fixture"). That leaves the two
sets below, whose frozen bytes held a value the fixture will not hold.

### `iaru_hf_2026_ny4i` -- CLAIMED-SCORE 16 -> 12; sent `59 FL` -> `59 8`

- **Sent exchange.** `TContestIARU` sends MY STATE when it is set, the society
  form, and the ITU zone otherwise. The frozen `FL` was the developer's
  `MY STATE`. The fixture states none, so the ITU zone derived for NY4I (8) is
  sent, as D7's `ref.cbr` / `ref.adi` send it (`59 8`).
- **Score.** `TContestIARU.CalculateQSOPoints` compares the received zone with
  `Station.MyZone`. Stored per-QSO points after a rescore:

  | settings | W1AW (ITU 8) | F4HQ (ITU 27) | x 2 zone mults |
  |---|---|---|---|
  | corpus fixture | 1 (same zone) | 5 | **12** |
  | fixture + only `Zone: "5"` | 3 (same continent) | 5 | 16 |

  So the frozen 16 came from comparing a CQ zone with an ITU zone. **12 is D7's
  `CLAIMED-SCORE`**, an independent check that the new figure is the right one.
- Nothing else in either artifact changed.
- **Not fixed here, reported:** with a stated `MY ZONE` (CQ), a real IARU
  session still scores against the CQ zone. That is a latent scoring defect in
  `src`, outside this re-freeze.

### `general_qso_2026_w1aw4` -- sent `59 TOM FL` -> `59`; CLAIMED-SCORE 79 unchanged

- The frozen `TOM FL` was the developer's `MY NAME` and `MY STATE`. The
  fixture states neither, so the sent exchange is `59`.
- That is the behaviour `known-divergences.txt` already records for this set's
  golden comparison: "event-source: sent name missing (MyName '' under /EXPORT;
  D7 sent TOM)".
- Checked line by line: all 79 QSO lines of each artifact differ by exactly
  that substitution, and no other line changed.

---

## 2026-11-19 -- all 13 sets: the overlay; plus Sweepstakes, Winter Field Day and issue 275

The gate was 0 identical / 13 differing on the HEAD build (489e53f9). Every
differing line was taken apart below; nothing else in any artifact moved. The
new bytes were checked to equal a separate scratch run of the same binary.

### All 13 sets -- `CATEGORY-OVERLAY: CLASSIC` -> `CATEGORY-OVERLAY:`

- **The cause is a1890e32 (issue 122, NY4I 2026-11-19): the overlay is the
  contest's setting, `Settings.Contest.CategoryOverlay`.** The frozen
  `CLASSIC` came from the GLOBAL header store, `cabrilloHeader._CATEGORY-OVERLAY`
  in the settings fixture. That row is inert since a1890e32, on purpose, as
  `_CATEGORY-MODE` became at Q61 (BENCH_QUEUE records it).
- **The log itself says blank.** Every fixture `log.db` holds a `config` row
  `CATEGORY-OVERLAY = ''`, source `contest` -- this contest's own statement. So
  no seeding could give CLASSIC here, and the blank is the right answer.
- **Not a seeding defect on this path.** Under `/RESCORE` and `/EXPORT` the
  station's stored contest-scoped values (the `commands` bucket) are not
  applied to ANY of the categories: measured with a new log made from
  arktika's `.cfg` with its ASSISTED and TRANSMITTER lines removed and the
  station bucket saying ASSISTED / TWO / CLASSIC, the export wrote
  NON-ASSISTED / ONE / blank. The overlay takes exactly the categories' path.
- The golden corpus does not see it: `/EXPORT` of the arktika `.db` writes the
  same bare `CATEGORY-OVERLAY:`, and `golden_diff.py` ignores the Cabrillo
  header. D7's `ref.cbr` still says CLASSIC (D7's global store).
- Scores unchanged in all eleven sets that moved on this line alone.

### `arrl_ss_ssb_2024_w4ta` -- CLAIMED-SCORE 30192 -> 30044; QSO 206 is an X-QSO

- Sweepstakes states its modes (46882b81, 2026-11-18; sponsor rule 2.4):
  ARRL-SS-SSB credits phone only, so QSO 206 (N0TST, 160 m CW) is an automatic
  X-QSO -- Cabrillo `X-QSO:`, ADIF `APP_TR4W_CLAIMEDQSO 0`. The golden corpus
  already pins the same two lines (`known.adi.diff`, `known.cbr.diff`).
- Arithmetic: 30192 = 2 x 204 x 74 and 30044 = 2 x 203 x 74 -- one QSO's two
  points gone, the 74 multipliers unchanged (OK is worked elsewhere).

### `winter_fd_2025_w4ta` -- CLAIMED-SCORE 42364 -> 1513; VE records gain `<STATE>`

- **Score.** Winter Field Day's 2027 rules (v3, 27e5844b): the claimed score is
  the QSO points; the objective multiplier is chosen on the submission form.
  42364 = 1513 x 28 exactly, and 42364 is D7's own `CLAIMED-SCORE`, so the
  points (1513) are unchanged and only the old x28 factor went.
- **STATE -- pre-existing, NOT from today's work.** 32 ADIF records of VE
  stations gain `<STATE:2>`: AB, BC, MB, NB, NS, PE, QC, SK as themselves, GH
  as ON. That is ed126e42 (2026-11-15, issue 275 item 4: the single-province
  RAC sections map to their province), "accepted by NY4I for issue 275" in
  that commit's message, which updated the golden `known.adi.diff` but not
  this baseline -- so this gate was already red on that set from 2026-11-15.
  Checked: each of the 32 changed lines is the frozen line with exactly one
  `<STATE:2>XX ` inserted, XX the section's province; no other line changed.

### `florida_qp_2026_ny4i` -- rescored.adi: a county-line contact is one record, and CNTY is written (2026-11-20)

- **What moved.** The header count `2 QSO(s) logged in an unspecified DATA mode`
  becomes `1`; W4THY's two rows (PIN and HIL, one `qso_set_id`) are ONE record
  carrying `<CNTY:11>FL,PINELLAS`, `<USACA_COUNTIES>` with both counties and
  `<APP_TR4W_CNTY_ALT>`; KG1S gains `<CNTY:9>FL,MONROE`. No other line changed.
- **Why.** NY4I's rulings of 2026-11-20 (issues 133, 87, 338): one ADIF record
  per linked contact, grouped by `qso_set_id`, with the first county in CNTY,
  the standard USACA_COUNTIES for two counties and the application-defined
  APP_TR4W_CNTY_ALT for the list; the county name comes from the party's own
  county file (`^Name` in the .dom), which in-state sessions never loaded into
  the multiplier list. `known.adi.diff` of the golden corpus carries the same
  lines (the D7 reference holds two records and is never regenerated).
- **Cabrillo is unchanged**: the two QSO lines stay.
