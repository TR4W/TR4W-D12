# Colour roles: a themeable palette that the operator still owns

**Status: DESIGN NOTE, nothing built.** Written 2026-08-31 after a UI critique of
the radio panel suggested replacing its cyan background with a dark neutral. That
suggestion is wrong in a way worth recording, and chasing down why exposed real
defects in the palette.

NY4I's constraint governs everything below: **we can suggest a default, but the
user gets to pick.**

---

## The critique that started it, and why it must not be applied literally

An external design review of the radio panel recommended, among other things:

> Replace the bright cyan background with a neutral dark charcoal or very light
> gray application surface.

and, three paragraphs later:

> Active VFO — *not immediately obvious* → blue outline/background or left accent
> bar.

Those contradict, and the code says which one is right. `uRadioPanelForm`:

```pascal
procedure TfrmRadioPanel.SyncActiveTint;
begin
   ...
   if mine then
      Color := TColor(tr4wColorsArray[trLightBlue])   // this radio is ACTIVE
   else
      Color := clBtnFace;                             // the other one
```

**The cyan IS the active-radio indicator.** Removing it deletes a state signal an
operator uses mid-contest; the review recommended adding the thing it had just
recommended removing, because a screenshot cannot show what a colour MEANS.

Two other items from that review are rejected here on domain grounds:

- **Frequency formatting.** `14074.00` is kHz to 10 Hz and is what `FreqToPChar`
  produces everywhere -- band map, main window, spot lines. The proposed
  `14.074.000 MHz` uses European dot grouping, reads as ambiguous to contesters,
  and would make this one panel disagree with every other frequency in the
  program.
- **"Reduce visual noise, remove the cell borders."** Good advice for a settings
  dialog. This window is glanced at during a run at 200 QSOs/hour, where borders
  delineate fields at speed and density is a feature. Worth trying, not worth
  assuming.

What the review got RIGHT, and what this note is about:

- **Do not rely on colour alone.** The active radio is signalled ONLY by tint.
- **A semantic palette, themeable light and dark.**

---

## What exists today

**18 entries**, `tr4wColors` / `tr4wColorsArray` in `VC.pas`, read from **52
sites** across the program.

**The operator already picks.** `uCFG.pas` accepts, per main-window element:

```
<ELEMENT NAME> COLOR      = <one of the 18 names>
<ELEMENT NAME> BACKGROUND = <one of the 18 names>
```

resolved through `tr4wColorsSA`. So the mechanism, the config surface and the
persistence are all in place. Two things are missing.

### 1. The enum names COLOURS, not ROLES -- and that is what blocks theming

`SyncActiveTint` asks for `trLightBlue` when it means *the active-radio tint*.
An operator who re-picks light blue for a dark theme changes every unrelated use
of light blue with it; and there is no way to change the active-radio tint
WITHOUT changing light blue everywhere. The vocabulary cannot express the
intent, so no amount of config solves it.

### 2. Tool windows are not covered at all

The config applies to `TMainWindowElement` rows. The radio panel, the cluster
console and the rest hardcode their palette entries. Half the program is
unthemeable no matter what the operator sets.

---

## Three defects found while measuring, worth fixing regardless

| entry | stored value | actually is | note |
|---|---|---|---|
| `trLightBlue` | `$FFFF00` | **pure cyan** | byte-identical to `trCyan`; the name lies, and it is the one the radio panel asks for |
| `trBtnFace` | `$0000FF` | **red** | overwritten at startup by `GetSysColor(COLOR_BTNFACE)` (`uCFG.pas:4352`). Correct only because that init runs -- a guard that FAILS OPEN. Skip it and every button face is red |
| `trLightMagenta` | `$800080` | **purple**, darker than `trMagenta` | misnamed |

`trBtnFace` is the one to fix first: the literal should be a sane grey so the
runtime assignment is a refinement rather than a rescue.

---

## The proposed model

Three layers, because the operator owns two of them.

**1. Swatches -- the 18 named colours.** Unchanged, and the names stay: existing
`.cfg` files say `CALL WINDOW COLOR = YELLOW` and must keep working.

**2. Roles -- named by MEANING, each with a default swatch.** This is the new
layer and the whole point:

```
    RoleActiveRadioTint        default trLightBlue
    RoleInactiveRadio          default trBtnFace
    RoleAlert                  default trAlert
    RoleMultiplierNeeded       ...
    RoleDupe                   ...
```

Code asks for a ROLE. `SyncActiveTint` becomes `ColorForRole(RoleActiveRadioTint)`
and stops naming a colour it does not care about.

**3. Themes -- a named set of role defaults.** "Light" and "Dark" ship as
defaults. A theme sets role defaults ONLY; any role the operator has set
explicitly wins over the theme. That is what "suggest a default but the user gets
to pick" means in a form that survives adding a dark theme later.

Config grows one command shape, and the old one keeps working:

```
<ELEMENT> COLOR = YELLOW        # still valid, still a swatch
COLOR ROLE ACTIVE RADIO = CYAN  # a role, by swatch name
COLOR ROLE ACTIVE RADIO = #1E90FF   # or by explicit value -- new
COLOR THEME = DARK              # sets role defaults, overrides win
```

---

## Sequencing, and why this is NOT next

Do **not** restyle one form. The leverage is entirely in the palette, and a form
restyled ahead of it becomes the odd one out and then has to be redone.

Order:

1. Fix the three palette defects above. Small, independent, no design decision.
2. Give the active radio a NON-COLOUR signal as well -- a badge or text. This is
   the review's best point, it is cheap, and it is worth having whatever happens
   to the palette.
3. Introduce roles, with today's colours as their defaults, so nothing changes
   visually on the first commit. Repoint the 52 sites a unit at a time.
4. Extend the config to roles and explicit values; add themes last.

**Not before the LCL conversion finishes.** Eight hand-built Win32 dialogs are
still live (`CLAUDE.md`, "every dialog that used tDialogBox"), and a converted
window is restyled once rather than twice.

## Interaction with the resize scaler

`ApplyLayoutScale` (`uLCLFormHelpers`) owns control bounds, fonts and anchors on
the forms that use it. A restyle that introduces padding, cards or corner radii
changes the DESIGNED bounds it captures -- which is fine, since capture happens at
construction, but it means restyling and scaling must be tested together. LCL
`TPanel` has no corner radius, so the review's "4-6px rounded cards" needs
owner-draw or a custom control; that is real work, not a property.

---

## Picking this up cold

Everything below is reachable without the conversation that produced this note.

**Read first, and take it as a hard constraint:** the radio panel's cyan is not
styling. `uRadioPanelForm.SyncActiveTint` uses it to say WHICH RADIO IS ACTIVE.
Any restyle that changes it must replace the signal, not just the colour.

| what | where |
|---|---|
| the enum and the 18 values | `tr4w/src/VC.pas`, `tr4wColors` / `tr4wColorsArray` (~line 601) |
| the swatch NAMES the operator types | `tr4wColorsSA`, same unit |
| `trBtnFace` rescued at startup | `tr4w/src/uCFG.pas:4352` |
| the config parser for `<ELEMENT> COLOR` / `BACKGROUND` | `tr4w/src/uCFG.pas` ~1610 |
| the 52 read sites | `grep -rn tr4wColorsArray tr4w/src` |
| the hardcoded tool-window use | `uRadioPanelForm.SyncActiveTint` |
| the resize scaler this must not fight | `uLCLFormHelpers.ApplyLayoutScale` |

**Good first task, and it needs no design decision:** the three palette defects
in the table above. `trBtnFace` especially -- its literal is red and it is
correct only because startup overwrites it.

**Second task, independently useful:** give the active radio a signal that is not
colour. A badge or a word. It is the one point from the external review that is
unambiguously right, it is small, and it survives whatever happens to the
palette.

**Do not start with a restyle of one window.** The leverage is in the palette;
a window restyled ahead of it gets done twice.

House rules that apply here: new UI code is pure LCL, no Win32 and no HWND;
three-space indent, `begin`/`end` always, `begin` on its own line; source files
are CRLF. See `CLAUDE.md`.
