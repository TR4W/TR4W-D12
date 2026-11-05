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
