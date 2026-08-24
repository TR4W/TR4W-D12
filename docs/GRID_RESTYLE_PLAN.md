# Restyling the converted grids — deferred until the conversions are done

**Status: PARKED, deliberately.** NY4I raised it on 2026-08-24 while the
window conversions were running: *"On some of the grids in these windows where
different cells have different colors, is there a more modern design that could
be applied. These grids look very Win 95-ish."* Agreed, and deferred: *"Save the
info for a revisit when done."*

Do not do this window by window. The whole value of the pass is seeing them
together and judging consistency, which is impossible while half of them are
still Win32.

---

## Why they look like that, and it is worse than "dated"

The look is not a deliberate 1995 aesthetic. It is what fell out of Win32
owner-draw, and in at least one case it is provably nobody's decision:

**`uRemMultsForm` fades a worked multiplier by gradienting from
`tr4wColorsArray[tr4wColors(Ord(rmt))]`** — the MULTIPLIER TYPE's ordinal used
as an index into the COLOUR table. A faded prefix and a faded zone therefore
differ in colour because of the order of two unrelated enumerations. Nothing
states a relationship and there is no reason for one. It is reproduced exactly
in the LCL version (bench queue 36 asks NY4I whether operators have learned
those colours before anything changes).

**`uDupeSheetForm`'s "gradient" was a gradient between a colour and itself** —
`GradientRect` received the same stop twice, so it drew a flat fill. Its
alternative arm could never run: `Left` was set to 1 at the top of the procedure
and never changed.

So part of what reads as "Win 95" is machinery that was never doing what it
appears to be doing.

## The design principle, and why it matters for a contest display

Every one of these grids encodes ONE binary fact per cell — worked/needed,
dupe/not. Win32 encoded it with **saturated fills**. The modern convention is
the opposite: **state is carried by contrast and weight, not by area of
colour.**

That is not fashion. Filling worked multipliers with saturated colour puts the
most visual weight on the LEAST useful information. The operator's eye should
land on what they still NEED. Dimming inverts that for free.

| | now | proposed |
|---|---|---|
| worked multiplier | gradient fill, white text | dimmed text, no fill |
| SCP dupe | `SCPDupeColor` fill, white text | dimmed or struck through, no fill |
| dupe-sheet district | full-cell colour block per district | a tint band or a left rule |
| structure | implied by the colour blocks | 1px hairline grid in low-contrast grey |

## The open question NY4I raised, and where it actually lands

NY4I, 2026-08-24, on a shared "how do we paint state" helper:

> *"for maintenance I like the form controls' items to be set in the form but
> duplicating common properties is easy to miss one. It's just a concern and not
> a directive."*

Both halves of that are right, and they apply to **different things**, which is
what dissolves the tension:

- **What is a PROPERTY of a control** — font family and size, cell metrics,
  the control's own background, base text colour, alignment — belongs in the
  `.lfm`, where the designer shows it and `lintlfm` type-checks it. It is
  per-form by nature, so there is nothing to duplicate.
- **What is a DECISION ABOUT MEANING** — "worked looks like *this*" — cannot
  live in an `.lfm` at all. It is per-CELL and computed at paint time. That is
  the only part a shared helper would own, and it is exactly the part where
  drift would be invisible.

So the duplication NY4I is worried about lands entirely on the half that cannot
be in the form anyway. A helper there does not take anything away from the
designer.

**And this tree already has the answer for the other half: a lint.** When
`.lfm` files had to agree about something, the fix was never to centralise the
property — it was `Lint-FormDefaults` (every form has an Escape path),
`Lint-FormEvents` (every handler is wired), `Lint-FormFields`. If the restyle
leaves several forms needing to agree on a font or a metric, add a lint that
fails the build when one drifts, rather than hoisting the property out of the
designer.

## Shape of the work when it is picked up

1. One enum for cell state (`needed`, `worked`, `dupe`, ...) beside
   `TFlowGrid`, and one routine that paints it. Nothing else moves.
2. Each form keeps its own `OnDrawCell` and its own `.lfm`. It decides WHICH
   state a cell is in — that needs the multiplier tables and the log — and asks
   the helper to depict it.
3. Decide which colours stay operator-configurable. Several are settings today
   (`ColorColors.RemainingMultsWindow*`, `SCPDupeColor`, the `tr4wColors`
   scheme), and a restyle that silently stops honouring a setting is a
   regression, not a redesign. **This is a product decision and NY4I's.**
4. Add the lint for whatever the forms then have to agree about.

**The seam is already in place.** Every converted window has exactly one
`OnDrawCell`, and colour is the only thing in it — see `uDupeSheetForm`,
`uMasterForm`, `uRemMultsForm`, and the band map's `SpotsDrawCell`. This is the
cheapest this work will ever be; it does not get cheaper by starting early, and
it gets worse by starting piecemeal.
