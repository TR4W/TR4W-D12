# The first-run setup wizard

**Status:** DESIGN ONLY. Nothing is built. Agreed with NY4I 2026-09-11; the
page shape below is the part that was argued about and settled, so change it
deliberately rather than in passing.

---

## 1. Why this exists, and what it replaces

**TR4W already has a first-run wizard. It is spread across startup with no
shared state.** Four places ask the operator to set exactly one setting each:

| prompt | raised from |
|---|---|
| `MY GRID` | `uProgramMain` startup |
| `COMPUTER ID` | `MainUnit:6332` |
| `MMTTY ENGINE` | `MainUnit:6340` |
| `DVP RECORDER` | `uEditMessageForm:312` |

They fire at different moments, route to three different editors, and only one
of them remembers having asked. On 2026-09-11 two of them collided: a second,
unguarded `MY GRID` prompt fired on top of the Preferences window the first one
had just opened, so answering the question re-asked it. That is the defect this
design removes the cause of, rather than patching again.

**So this is consolidation, not a new feature.**

**MMTTY ENGINE and DVP RECORDER are deliberately NOT in the wizard** (NY4I):
they are the two that most look like configuration and least look like getting
on the air.

---

## 2. The page shape -- SETTLED

Six sequential pages was the first proposal and was rejected. Five of the six
were yes/no gates, and asking five times in a row reads as an interrogation.

**One Station page, then ONE checklist page, then only the pages ticked.**

```
  1. Station              (required -- the only page everyone sees)
  2. What else?           (checkboxes: Radio / CW keyer / DX cluster /
                           External logger / Rotator)
  3..n  one page per ticked item, in that order
  n+1  Commit
```

A new operator who wants to log gets **two pages**. A full station gets what
they asked for. Nothing is dropped.

---

## 3. THE TWO RULES THAT MATTER MORE THAN THE PAGES

### 3.1 The wizard must not redeclare a field

`uRadioEditForm`, `uKeyerEditForm`, the Preferences Station panel, and the
`radios[]` / `keyers[]` / `clusters[]` / `rotators[]` stores all exist. If the
wizard grows its own copy of "radio control port", there are two definitions of
it and they drift.

**That is not a hypothetical risk, it is the exact failure this tree spent
September unwinding** -- a settings value with two owners, where a fix lands in
one and not the other. See `docs/CFG_ARRAY_ELIMINATION.md`.

So each page either hosts the existing editor or writes through the existing
store's own API. No page declares a setting.

### 3.2 Order so that failure costs nothing

**Station commits first. Hardware last.**

A radio that will not open a COM port, or a cluster that will not resolve, must
not trap the operator in a wizard or lose the callsign they just typed. This is
the Aero Wizard commit-page rule doing real work rather than being ceremony.

---

## 4. The pages, and what each one writes to

### Page 1 -- Station (required)

**ONLY THE LEFT COLUMN OF THE STATION TAB.** That tab already splits visually
into *Station information* and *Contest exchange*, and the split is real: the
right-hand fields are per-contest, not per-station. The agent memory
`my-fields-station-vs-contest` records that line being drawn; the wizard
honours it.

| asked | command | note |
|---|---|---|
| Callsign | `MY CALL` | **the only genuinely required field in the program** -- `ConfigurationOkay` checks this and nothing else |
| First name | `MY NAME` | |
| Grid square | `MY GRID` | the one thing here that cannot be derived |
| Continent | (store-backed, `cbxMyContinent`) | **derived from the callsign** |
| CQ zone | `MY ZONE` | derived |
| ITU zone | `MY ITU ZONE` | derived |
| State/Province | `MY STATE` | derived where CTY.DAT knows |
| ARRL section | `MY SECTION` | |
| Country | `MY COUNTRY` | derived |
| Postal code | `MY POSTAL CODE` | |

**DERIVE, THEN LET THEM CORRECT IT.** `uCFG.pas:2521` and `fcontest.pas:1843`
already set `MyContinent` from a CTY.DAT lookup of the callsign. The page
should fill these in as the callsign is typed and present them as
confirm-or-correct, not as ten empty boxes. That is what makes a ten-field page
feel like a two-field page.

**NOT asked here:** `MY CHECK`, `MY PREC`, `MY FD CLASS`, `MY FOC NUMBER`,
`MY IOTA`, `MY PARK`. Contest exchange, not station identity.

### Page 2 -- What else would you like to set up now?

Five checkboxes, all default OFF, each with one line of plain description. This
page is the whole reason the wizard is short.

### Page 3 -- Radio (if ticked)

Collect the minimum for ONE working radio and offer the profile name
**`Default`**. `TStationProfile` and `ActiveProfileName` already exist in
`uRadioConfigStore`, so "Default" is an existing concept and not a new one.

Subsequent radios are the radio editor's job (NY4I). Writes `radios[]` and
`profiles[]`.

### Page 4 -- CW keyer (if ticked)

WinKeyer is the case worth handling. Writes `keyers[]` through the keyer
library, the same store `uKeyerEditForm` uses.

**Note for implementation:** a WinKeyer owns its OWN port; sharing it with the
CPU keyer port opens it twice. See the agent memory
`keyer-port-vs-cpu-keyer-port`.

### Page 5 -- DX cluster (if ticked)

One cluster, enough to connect. `TClusterDefinition` exists; the full list is
managed in the regular form afterwards, the same pattern as the radio.

### Page 6 -- External logger (if ticked)

Type (`elLogType`), address, port, enabled.

**These are already properties of the settings model** --
`Settings.ExternalLogger.Address` / `.Port` / `.Enabled`, migrated 2026-09-10 --
so this page writes typed properties and needs no command names at all.

### Page 7 -- Rotator (if ticked)

`TRotatorDefinition`, `rotators[]`.

### Final page -- Commit

Aero Wizard commit page. **The button says what it will do** -- "Create
configuration" -- not "Finish".

---

## 5. When it runs

**Gated on exactly the condition the `[Convert]` banner already computes: no
settings file.**

`uProgramMain.ReportConfigurationSources` already determines this and logs
`FIRST RUN -- no settings file yet`. The wizard uses the same test, so the
wizard and the conversion path are two answers to one question rather than two
features that can disagree.

**Never shown to an existing installation**, and never under `/EXPORT` or any
other headless switch (`tSilentExport`).

---

## 6. i18n

**Green field** (NY4I, 2026-09-11): *"whatever gets me to .po files my
translators can update it fine by me."*

That makes this easy, and it is worth saying why. The i18n damage during the
Win32-to-LCL conversion was **stranding**: a window's caption moved from a
`TC_` constant that had real translations into an `.lfm` that had none, so 469
captions silently shipped as English. A new form has no constants to strand.

Two rules:

1. **Design-time captions go in the `.lfm`.** Lazarus harvests them -- the
   `.lrj` beside every form in `src/ui/lcl` is the evidence that this is
   already working.
2. **Any string built in CODE is a `resourcestring`**, never a literal. That
   is every validation message and every derived label.

And one prohibition, which is not negotiable:

> **NEVER run `pas2po` to pick up new strings.** It rebuilds a catalogue from
> the `TC_`/`RC_` tables alone and drops every `.lfm` and resourcestring key
> the Lazarus harvest contributed -- measured 2026-08-29: **2,203 real
> translations destroyed across ten catalogues in one run**, with no warning
> and a clean exit. `po_merge --pot` is the additive tool and the only safe
> one.

---

## 7. Implementation notes

- A designed LCL form with a `TPageControl` whose tabs are hidden. Standard,
  and it keeps each page a designable surface.
- `uNewContestForm` is the precedent in this tree for a task-focused dialog.
- Every page independently valid, so Back never unwinds state.
- `.lfm` components that are not published fields need `RegisterClass` or the
  WHOLE form fails to stream -- see the agent memory
  `lfm-component-needs-registerclass`.
- `Lint-FormEvents` gates unwired designer events; an unwired handler is silent
  data loss.

## 8. Open, and worth deciding before code

1. **Does the checklist page remember its answers?** If an operator ticks
   Radio, backs out, and unticks it, the collected radio should be discarded
   rather than half-written.
2. **Is there a "skip the wizard entirely" exit**, and what does it leave
   behind? A station with no callsign cannot log -- `ConfigurationOkay` halts.
   The honest options are to require the callsign or to let them out and let
   the existing warning fire.
3. **Does the wizard set `COMPUTER ID`?** It is one of the four scattered
   prompts and is multi-op only. Probably belongs on the Network page of
   Preferences rather than here, which would retire a third prompt.
