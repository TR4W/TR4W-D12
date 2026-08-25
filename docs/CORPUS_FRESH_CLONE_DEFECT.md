# The corpus fails Winter Field Day on a fresh clone, and blames the wrong thing

**Status:** open, not started. Found 2026-08-25 from the K4-Spectrum worktree.
Pre-existing -- nothing to do with the panadapter work that surfaced it.

## Symptom

On a freshly created worktree or clone, the golden-master corpus reports

```
=== 21 passed, 1 failed, 4 known-divergence, 0 awaiting-candidate ===
FAIL  winter_fd_2025_w4ta  cbr  (no fresh D12 candidate -- export aborted or produced no output)
```

against a documented baseline of 22 / 0 / 4. The ADIF for the same log passes;
only the Cabrillo aborts.

## Cause

Not a code defect. `tr4w/target/settings/` is runtime state and is gitignored,
so a fresh checkout has NO `tr4w.json`. The Cabrillo LOCATION tag is read from
that file:

`tr4w/src/trdos/PostUnit.PAS:2552` already says so, and says why it matters --

> FROM `settings\tr4w.json`, seeded once from the ini. This read is what the
> LOCATION guard below depends on, and it is why deleting `tr4w.ini` used to
> abort every Winter Field Day and ARRL10 batch export in silence.

and the guard at `PostUnit.PAS:2567`:

```pascal
if ( Contest = ARRL10 ) or ( Contest = WINTERFIELDDAY ) then
  if GetCabrilloTagText( ctLocation ) = 0 then
     begin
     showwarning( 'LOCATION field is empty.' );
     Exit;
     end;
```

With no settings file the tag is empty, the export declines, and no `cand.cbr`
is written. The program exits 0 -- it did not crash, it refused.

Copying a populated `settings/tr4w.json` into the worktree's `tr4w/target/`
restores the documented 22 / 0 / 4. That was verified, not assumed.

## Why this is worth fixing rather than remembering

**The message points at the wrong component.** "no fresh D12 candidate --
export aborted or produced no output" reads as a defect in the exporter. The
actual cause is a missing configuration file, and the program logged exactly
that (`LOCATION field is empty.`) where the harness did not look.

**It contradicts the definition of done.** NY4I's criterion is: clone from
GitHub onto any PC, run `FullBuild.ps1`, get the setup exe -- re-verifiable
with `build/Test-FreshClone.ps1`. A fresh clone that fails a corpus set for
environmental reasons undermines the one test that is supposed to prove a
fresh clone works.

**It costs a real investigation every time.** A failure on the regression
oracle is exactly the failure nobody is allowed to wave through, so each
encounter is a full diagnosis.

## What the guard work turned up

Verified while implementing the guard, and it widens the problem:

**`LOCATION` is not just a gate, it is CONTENT.** Every one of the 13 frozen
`ref.cbr` files carries `LOCATION: WCF`, and that value comes from the
operator's `settings/tr4w.json` (`"_LOCATION" : "WCF"`, line 522 here). It is
NOT in any staged `log.cfg` -- checked.

So the abort on Winter Field Day is the LOUD half. The quiet half is that the
other twelve Cabrillo sets embed whatever the operator's LOCATION happens to
be, and the refs were frozen against one particular value. **An operator whose
LOCATION is not `WCF` would see Cabrillo diffs on sets that have nothing to do
with whatever they changed** -- on the regression oracle, which is the one place
a false failure is most expensive.

That makes fix 3 the actual fix rather than a nicety: the corpus is
environment-dependent TODAY, on this machine, and passes only because this
machine's settings happen to match the refs.

## Suggested fix, cheapest first

1. **Make the harness detect it.** Before the run, check that
   `tr4w/target/settings/tr4w.json` exists and carries a LOCATION tag; if not,
   fail with that as the reason instead of running 26 exports and mislabelling
   one. This alone converts an hour into a sentence.
2. **Surface the app's own words.** When an export produces no candidate, tail
   `target/tr4w.log` for the last warning and print it. The program already
   said what was wrong.
3. **Consider a checked-in corpus settings file** used only by the harness --
   the exports are headless and deterministic, so the header tags they need are
   part of the fixture, not part of the operator's environment. This is the
   real fix; 1 and 2 are worth doing regardless.

## What NOT to do

Do not weaken the LOCATION guard. Winter Field Day and ARRL10 Cabrillo files
genuinely require it, and refusing to write a header-invalid file is correct
behaviour -- the bug is that the harness cannot say so.
