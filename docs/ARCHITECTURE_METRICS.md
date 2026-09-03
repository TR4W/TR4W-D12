# Architecture metrics — the god classes, measured

**Generated, not maintained.** `python tools/architecture-metrics.py` prints the
table below from the source; `--record` appends a dated row to the history.
NY4I, 2026-09-03: *"A script that generates the numbers is always preferable for
anything you do."*

That is also this repository's own rule. CLAUDE.md says of unit counts: *"they
drift, and a stale count is believed. Measure."* TR4QT keeps its equivalent
(`.claude/METRICS.md`) by hand and its baseline row is from January; a hand-kept
table is the thing that goes stale first.

---

## What is measured, and why each one

| column | what it tells you |
|---|---|
| **lines** | the blunt instrument, and what "God class" usually means |
| **routines** | a unit with 400 routines is a god class even if it is short |
| **public** | what the rest of the program can reach — the real coupling surface |
| **globals** | interface-section variables. **TR4W's coupling runs through these**, not through parameters |
| **used by** | how many other units name it |

**Cyclomatic complexity and test coverage are deliberately absent.** Both are
real and neither is measurable from a text scan. Printing a number for them
would be exactly the drift this script exists to prevent.

---

## Baseline, 2026-09-03

435 units, 251,172 lines of Pascal under `tr4w/src`.

| unit | lines | routines | public | globals | used by |
|---|---:|---:|---:|---:|---:|
| **MainUnit** | 11,710 | 226 | **187** | 42 | **123** |
| **LOGSTUFF** | 10,894 | 123 | 49 | **161** | 45 |
| uPrefsForm | 7,811 | 201 | 193 | 0 | 3 |
| uCommctrl | 5,851 | 341 | 340 | 0 | 19 |
| MMSystem | 4,670 | 203 | 203 | 0 | 8 |
| tree | 4,450 | 129 | 123 | 5 | 80 |
| **VC** | 4,399 | 1 | 1 | **182** | **302** |
| **LOGWIND** | 3,977 | 83 | 78 | **216** | 81 |
| PostUnit | 3,915 | 47 | 40 | 53 | 33 |
| uRadioIcomBase | 3,643 | 104 | 100 | 0 | 47 |

## What the numbers say that "MainUnit is too big" does not

**MainUnit is the god class by every measure at once** — most lines, 187 public
routines, and reached by **123 units**. Splitting it is not a matter of moving
code: 123 units have to keep compiling, and 187 entry points have to keep
resolving. That is why it has stayed big.

**But the worst coupling is not in MainUnit.** `VC` publishes **182 globals**
and is used by **302 of 435 units** — it is not a god *class*, it is a god
*namespace*, and it is where the program's shared state actually lives.
`LOGWIND` publishes **216**. Any plan that extracts services out of MainUnit
without deciding where those globals live will produce units that still can only
talk to each other through `VC`.

**Two of the biggest are not ours.** `uCommctrl` (341 routines) and `MMSystem`
(203) are Win32 API *declarations* — they are large because the API is, and
they shrink when the calls do, not before. `MMSystem`'s 189 declarations are
already known to serve 5 functions at 13 sites
(`PLATFORM_CLOCK_ABSTRACTION.md`).

**uPrefsForm is the one nobody names.** 7,811 lines and 193 public routines, and
it is only three years of settings screens. It is used by 3 units, so it is
big without being coupled — the cheapest of these to split, and the least
urgent.

## The target

TR4QT set MainWindow < 2,500 from 5,564. The equivalent here is harsher: **11,710
lines and 187 public routines.** A first honest milestone is not a line count but
a *surface* one — get the public routines down, because that is what 123 units
depend on and what makes every later move possible.

---

## History

Appended by `--record`. Columns are the top four units' line counts, in the order
the table above lists them.

| date | MainUnit | LOGSTUFF | uPrefsForm | uCommctrl |
|---|---:|---:|---:|---:|
| 2026-09-03 | 11710 | 10894 | 7811 | 5851 |
