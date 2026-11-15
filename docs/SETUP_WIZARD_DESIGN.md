# The first-run setup wizard

**Status (2026-11-14): BUILT -- Station, Radio, WinKeyer and DX cluster.** The
page shape below is the part that was argued about and settled (NY4I,
2026-09-11), so change it deliberately rather than in passing. What exists:

| piece | where |
|---|---|
| the rules: page plan, startup gate, staging into the stores | `tr4w/src/uSetupWizard.pas` (no LCL; pinned by `test/unit/uTestSetupWizard.pas`) |
| the window | `tr4w/src/ui/lcl/uSetupWizardForm.pas` + `.lfm` (driven off screen by `test/unit/uTestSetupWizardForm.pas`) |
| when startup offers it | `uSetupWizard.SetupWizardDueAtStartup(aHeadless, aStationHasCallsign)`: not headless and **no callsign stored**. There is **no once-only flag** any more -- `general.setupWizardShown` is no longer written (the key stays in the known-keys list so an old file drops it quietly) |
| startup | `uProgramMain.RunTR4W`, **before New Contest**: a Yes/No question (Yes is the default), then the wizard **modally** -- see [section 6](#6-when-it-runs) |
| one window | the Radio and WinKeyer pages **host the existing editors' content panels** (`TRadioEditForm.EditRadioIn`, `TfrmKeyerEdit.EditKeyerIn`); there is no second window. The Station page carries its own country-file status line and **Download country file** button |
| on request | **Tools -> Setup Wizard...** (`menu_setup_wizard`, NY4I 2026-11-14: "also selectable under Tools menu") |
| where a radio and keyer go | slot 1 and CW output 1 of the **active** profile, or of a new profile `Default` when none is active; a name already used is made unique the store's way, so a second run adds rather than fails |
| Preferences open | the wizard refuses to open, and "Create configuration" refuses while Preferences shows (both edit the libraries from their own copies); after a commit a hidden Preferences re-reads the file (`PreferencesReloadAfterExternalSave`) |
| colliding ports | asked BEFORE anything is written, with Preferences' own question and its default of No (`PortsAcceptable`); a later start would otherwise put a saved, active profile on the air regardless |

**One known gap against section 5's "each item independently":** the radio
and keyer libraries are validated as a whole before they are saved, so a
`Validate` refusal keeps the station but drops all three items, not only the
one at fault. The editors validate what they accept, so this needs a library
that was already invalid on disk; it is reported on the result page.

**NOT BUILT: the External logger and Rotator pages** (sections 4 and 2 list
them). The request that built this named station, radio, WinKeyer and cluster;
adding a page is a new `TSetupItem` member (its ordinal is its canonical place),
a sheet, and a branch in `StageSetupItems`.

**Section 6's gate was wrong when this was built, and was replaced** -- read
the correction there before reasoning from the table.

**Reviewed 2026-09-11** against an external critique, written from this document
alone by an agent with no access to the tree. Its accepted points are folded into
the sections below; everything it got wrong about TR4W is recorded in
[section 12](#12-considered-and-rejected) with the evidence, so that a
plausible-sounding recommendation does not arrive again next month with nothing
to argue against it.

> **The critique itself is NOT in the repository and is not coming.** It lives on
> NY4I's machine as `docs/Critique of Wizard Design Plan.md`, is **untracked and
> deliberately so** — it carries pre-signed URLs and **TR4W-D12 is public** — and
> three tracked files cited it as though a reader could open it (corrected
> 2026-09-28). **Section 12 is the record**; it exists precisely so the critique
> does not have to be readable to be answered. Do not go looking for the file on
> a fresh clone, and do not commit it if you find it on this one.

---

## 1. Why this exists, and what it replaces

**TR4W already has a first-run wizard. It is spread across startup with no
shared state.** Four places ask the operator to set exactly one setting each:

| prompt | raised from | fires when |
|---|---|---|
| `MY GRID` | `uProgramMain.pas:2115` | **at startup**, once per installation |
| `COMPUTER ID` | `MainUnit.pas:6327` | opening the **Network** window |
| `MMTTY ENGINE` | `MainUnit.pas:6340` | opening the **MMTTY** window |
| `DVP RECORDER` | `uEditMessageForm.pas:312` | editing a message that names a `.WAV` |

**ONLY ONE OF THE FOUR IS A STARTUP PROMPT**, and an earlier version of this
table implied all four were. That correction matters, because it changes what
consolidation buys: the other three already fire at the moment the operator
reaches for the feature, which is the behaviour a wizard would otherwise have
to invent. `MainUnit.pas:6327` gates `COMPUTER ID` on
`ID = tw_NETWINDOW_INDEX`; `uEditMessageForm.pas:305` gates `DVP RECORDER` on
the message text ending in `.WAV`.

What is genuinely wrong is the `MY GRID` one, and it was wrong twice over. On
2026-09-11 a second, unguarded `MY GRID` prompt fired on top of the Preferences
window the first one had just opened, so answering the question re-asked it.
That duplicate is deleted (`uProgramMain.pas:2263`, which records the incident
and the wrong diagnosis that was nearly committed with it). The surviving
prompt is the complete one: it honours `tSilentExport`, and it asks **once per
installation** through `GridPromptAlreadyShown` / `MarkGridPromptShown`
(`uRadioConfigApply.pas:1202`, `:1230`).

**So this is consolidation, not a new feature** -- and the thing being
consolidated is a single startup prompt plus the ability to offer the other
three up front to an operator who wants them.

**MMTTY ENGINE and DVP RECORDER are deliberately NOT in the wizard** (NY4I):
they are the two that most look like configuration and least look like getting
on the air. `COMPUTER ID` is not in it either -- see
[section 11](#11-decided-formerly-open).

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

**The order is canonical, not click order** -- Radio, CW keyer, DX cluster,
External logger, Rotator, always in that sequence whatever order the boxes were
ticked in. Next and Back are then deterministic, and a support instruction
("the third page") means one thing.

**Navigation runs off an explicit page plan, not off tab indexes.** The plan is
recomputed when the checklist changes:

```
  [Station, Checklist] + <ticked pages in canonical order> + [Commit]
```

The `TPageControl` in section 9 is how the plan is *displayed*. It is not where
the plan lives, and a page is a view -- never the place a value is stored
between pages. That is what section 5 is for.

---

## 3. THE TWO RULES THAT MATTER MORE THAN THE PAGES

### 3.1 The wizard must not redeclare a field

`uRadioEditForm`, `uKeyerEditForm`, the Preferences Station panel, and the
`radios[]` / `keyers[]` / `clusters[]` / `rotators[]` stores all exist. If the
wizard grows its own copy of "radio control port", there are two definitions of
it and they drift.

**That is not a hypothetical risk, it is the exact failure this tree spent
September unwinding** -- a settings value with two owners, where a fix lands in
one and not the other. See `docs/migration_interim_artifacts/CFG_ARRAY_ELIMINATION.md`.

So each page either hosts the existing editor or writes through the existing
store's own API. No page declares a setting.

**Stated as a reviewable rule:** the wizard owns *intent and navigation*. The
stores and editors own *validation, normalisation, defaults and
serialisation*. Concretely, the wizard does not get to decide which serial
frame is legal for a radio, whether a cluster definition is complete, what a
valid external-logger endpoint looks like, or which station fields are derived.
`TRadioEditForm.SaveToRadio(out aError: string): boolean`
(`uRadioEditForm.pas:247`) is what that ownership looks like in code today --
the editor already returns the reason a definition is not saveable, and the
wizard's job is to display it, not to reproduce it.

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
right-hand fields are per-contest, not per-station
(`uPrefsForm.pas:3904-3919`). The agent memory
`my-fields-station-vs-contest` records that line being drawn; the wizard
honours it.

| asked | command | note |
|---|---|---|
| Callsign | `MY CALL` | **the only genuinely required field in the program** -- `ConfigurationOkay` (`LogCfg.pas:230`) checks this and nothing else |
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

**And the derivation has rules, because "fills in as you type" is how a
correction gets eaten.** All five accepted from the critique:

- Lookup is **debounced**, not per keystroke. CTY.DAT lookup is cheap, but a
  half-typed callsign resolves to the wrong entity and flickering the answer
  while the operator is still typing reads as a bug.
- A derived field is overwritten **only while it is still derived**. The moment
  the operator edits one, that field is theirs; a later callsign change does
  not take it back.
- Derived values are **marked as such** in the UI, so "confirm or correct" is a
  visible instruction rather than an assumption about what the operator infers
  from pre-filled boxes.
- A lookup that finds nothing **changes nothing** and blocks nothing. It leaves
  what is there, says why in one non-modal line, and lets the page commit. An
  operator with a special-event or newly issued call must not be stopped by
  CTY.DAT being behind.
- Nothing is persisted **because it was displayed**. Only what survives to the
  commit page is written -- see the session model in section 5.

**Callsign validation reuses `IsAGoodCall`** (`uCallSignRoutines.pas:98`,
body at `:596`), not a wizard-local regex. The critique's warning about
over-rigid validation is right in principle and is already answered in this
tree: the benchmark note at `uCallSignRoutines.pas:84` records it accepting
**234,466 of 234,467** calls from a real corpus, so it is a syntax screen and
not a gate an unusual call can fail.

**The grid stays optional.** Non-derivable does not mean mandatory, and the
program agrees -- `ConfigurationOkay` requires `MyCall` and nothing else. An
empty grid at commit is fine; the existing `MY GRID` startup prompt is what the
wizard retires, not what it re-implements.

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
`keyer-port-vs-cpu-keyer-port`. `uKeyerEditForm.pas:36` states the same line
from the other side -- only a device with its own settings is edited there at
all, and keying on a radio's own port belongs to that radio.

### Page 5 -- DX cluster (if ticked)

One cluster, enough to connect. `TClusterDefinition` exists; the full list is
managed in the regular form afterwards, the same pattern as the radio.

### Page 6 -- External logger (if ticked)

Type (`elLogType`, `uExternalLoggerBase.pas:159`), address, port, enabled.

**These are already properties of the settings model** --
`Settings.ExternalLogger.Address` / `.Port` / `.Enabled` in `uSettingsModel`,
migrated 2026-09-10 -- so this page writes typed properties and needs no
command names at all.

### Page 7 -- Rotator (if ticked)

`TRotatorDefinition`, `rotators[]`.

### Final page -- Commit

Aero Wizard commit page. **The button says what it will do** -- "Create
configuration" -- not "Finish".

**And it becomes the result page** rather than closing on a cheerful noise.
Because station identity commits before the optional hardware, the outcome can
legitimately be partial, and hiding that behind "Finish" is how an operator
ends up believing a cluster is configured when it is not:

> Configuration created for N0CALL.
> Radio saved.
> DX cluster could not be verified -- set it up later in Preferences > DX Cluster.

The operator-facing text stays at that level. The diagnostic detail goes to
`tr4w.log`, where support already looks for it.

---

## 5. The session, and what commit means

The critique's strongest point, accepted: "Station first, hardware last" says
an *order* and not a *mechanism*, and the two plausible mechanisms -- write as
you go, or stage everything -- are different programs.

**Staged, with one commit.** While the operator navigates, the wizard holds a
session object: the station fields, which checkboxes are ticked, a draft per
ticked item, per-field validity, and per-field derived-or-edited state. Nothing
reaches a store until "Create configuration".

Then, in this order:

1. Station identity.
2. Each ticked item's draft, **independently** -- one failure does not abandon
   the rest.
3. The result page reports what landed and what did not.

Four states are enough to describe it and are worth naming because they are
what a test asserts on: `Editing`, `Committing`, `Completed` (possibly with
warnings), `Cancelled`.

**Back retains the draft.** Unticking an item **destroys** its draft, removes
its page from the plan, and excludes it from the commit -- not merely hides it.
Hiding it is how a half-written radio gets written by a later run.

### What Cancel can and cannot do

**Cancel cannot leave the disk untouched, and the critique's recommendation
that it should is not implementable here.** `uProgramMain.pas:1675-1681` writes
`settings\tr4w.json` during startup, six lines after the first-run test, before
any wizard could run:

```pascal
  if not LoadSettingsForStartup(TR4WConfigFileName, Settings) then
     begin
     SaveSettings(TR4WConfigFileName, Settings);
```

So by the time the operator sees a wizard page the settings file exists. Cancel
means **the wizard contributed nothing**, not **no file was created** -- and
the file-exists test therefore cannot be what suppresses the wizard next time.
Section 6 says what does instead.

---

## 6. When it runs

> **CURRENT (2026-11-14, final).** Everything below this block was written
> earlier the same day and is **history where it differs from this block** --
> in particular every mention of a `setupWizardShown` / `gridPromptShown` flag
> for the wizard, and of `EnsureCountryFile` being the wizard's download.
>
> - **The rule is "no callsign stored", not "no settings file" and not a flag.**
>   `SetupWizardDueAtStartup(tSilentExport, StartupMainCallsign(TR4WConfigFileName) <> '')`.
>   Nothing is written before the operator answers. A Cancel (or a No) configures
>   nothing, so the next start asks again; the moment a callsign is stored -- by
>   the wizard or by New Contest, which will not take an empty one -- the question
>   stops by itself. This is why there is no "do not ask me again" box: an
>   operator who wants none simply uses New Contest. (An earlier version set a
>   flag first; a Cancel left a blank `tr4w.json` behind and the next start never
>   asked again.)
> - **The question is a Yes/No with Yes as the default** (`AskSetupWizardAtStartup`).
> - **One window.** Radio and WinKeyer are pages of the wizard, not buttons that
>   open the editors (NY4I: *"MY idea of a wizard is it steps you through things
>   in one window with frames."* -- the editor opened behind the wizard and the
>   operator lost it). Each editor form wraps everything but its footer buttons
>   in `pnlContent`; the wizard re-parents that panel into its page, calls
>   `AcceptEdits` on Next (the editor's own validation, shared with its Save
>   button), and grows the window to fit. Preferences still shows the same
>   editors as their own windows -- one implementation, two hosts.
> - **The country file is the wizard's own page business.** At startup the file
>   is loaded quietly from `fcontest.ResolveCountryFile` (downloaded -> shipped).
>   If there is none, the Station page says so and offers **Download country
>   file** (`uCTYUpdate.DownloadCTYAsync` into the downloaded-data directory,
>   `LoadCountryFileFrom` to adopt it -- also what `EnsureCountryFile` uses).
>   Back, Next and Cancel are disabled while it runs, and the window refuses to
>   close, because the completion event is a method of the form. The old
>   question from outside the wizard ("takes me out of it", NY4I) is gone from
>   this path; if the operator leaves the file undownloaded, `EnsureCountryFile`
>   asks a few steps later, as it always has.
> - **Re-running from Tools -> Setup Wizard** replaces slot 1 of the **active**
>   profile with the new radio (existing behaviour of `StageSetupItems`); the
>   Done page names the profile.

> **CHANGED AGAIN 2026-11-14 (NY4I, issue 81): the wizard is OFFERED BEFORE
> New Contest, not after the main window.** Run on a brand-new install in an
> empty directory, the first thing seen was New Contest, and the wizard only
> appeared after the operator had typed their callsign there. Now, just before
> `ShowNewContest`, a Yes/No asks "This looks like a new installation. Would
> you like to run the Setup Wizard first?" (No is the default). Yes runs the
> whole wizard **modally** (`OfferSetupWizardAtStartup`); New Contest then
> opens with the callsign already filled in, because it reads `My.Call` from
> the settings file the wizard has just written.
>
> What that changed, and why each part is safe:
>
> - **Nothing is put into use.** No radio, CW or contest state exists yet, so a
>   startup-mode run SAVES the station, radio, keyer and cluster and stops;
>   `ApplyActiveProfileToConfigAtStartup` applies the saved active profile and
>   cluster a few steps later, the road every start takes.
> - **Country file.** The callsign lookup needs it and `SetUpFileNames` only
>   resolves it after a contest is chosen, so the tier rule was extracted as
>   `fcontest.ResolveCountryFile(aUseContestDir, aSource)` -- downloaded, then
>   (optionally) the contest directory, then shipped -- and the wizard asks it
>   without the contest tier. Missing file: the lookup says "unknown call" and
>   never blocks. Support-file download is deliberately NOT offered by the
>   wizard: both files ship in the installer and `EnsureCountryFile` already
>   offers the download.
> - **Flags.** The offer sets only `setupWizardShown` (`MarkSetupWizardOffered`),
>   so a No leaves the one-off MY GRID prompt able to ask; a Yes also sets
>   `gridPromptShown`, because the Station page asks for the grid.
> - **Profile.** The radio and keyer go into the active profile, or a new one
>   named `Default` on a new install, and the Done page now says so and points
>   at Preferences > Hardware (`SWizResProfile`).
> - **Shared with Preferences, not copied:** the "ports collide, continue?"
>   question is now `uPrefsForm.ConfirmPortConflicts` for both; Preferences
>   had a differently-wrapped copy of the same dialog.
> - The command-line-contest-file start skips the offer (no New Contest), so
>   the modeless post-main-window open below remains for that case.
>
> **CORRECTED 2026-11-14, when it was built. The gate below never fires.**
> The table's "first run, and `MyCall` is empty" row assumes the callsign can
> still be empty at `ConfigurationOkay`. It cannot: on a brand-new install the
> first window is **New Contest**, which keeps OK disabled until a callsign
> passes `IsAGoodCall` (`uNewContest.BeginNewContest`), and
> `ApplyNewContestChoices` puts it in `MY CALL` and `MainCallsign` before
> `ConfigurationOkay` runs. This document predates that dialog asking.
>
> **What was built instead** (`uSetupWizard.SetupWizardDueAtStartup`):
>
> | condition | wizard |
> |---|---|
> | headless (`tSilentExport`) | never |
> | `settings\tr4w.json` existed when startup began | no -- an existing station |
> | `general.setupWizardShown` already set | no -- Tools -> Setup Wizard reopens it |
> | otherwise | **yes** |
>
> "Existed when startup began" is **captured** in `RunTR4W` right after the
> legacy-ini conversion offer (an operator who converts has a file and is not
> new) and before New Contest and `LoadSettingsForStartup` (which saves the
> file, after which the answer is always yes). The wizard opens where the MY
> GRID prompt did -- after the main window exists, with settings and CTY.DAT
> loaded -- with the callsign New Contest took already filled in, and
> **modeless**, so startup carries on into the message loop. The flag is set
> **before** it shows, and setting it sets `gridPromptShown` too: the Station
> page asks for the grid. The original reasoning follows, kept because its
> points about capture, cancel and `.bad` files still hold.

**The first-run condition is already computed and the wizard uses that one.**
`uProgramMain.ReportConfigurationSources` (`:857`, called at `:1673`) logs
`FIRST RUN -- no settings file yet` when `TR4WConfigFileName` is absent. The
wizard and the conversion banner must be two answers to one question rather
than two features that can disagree.

But the raw condition is not sufficient on its own, in two directions that the
critique was right to press on.

**First: the file is created moments later.** The test at `:1673` is true
exactly once, and `:1677` makes it false. So the flag has to be **captured**
there, not re-evaluated later, and a wizard the operator cancelled must be
suppressed by something durable.

**That mechanism already exists and has a working example.**
`TRadioConfigStore.GridPromptShown` is a persisted boolean read by
`GridPromptAlreadyShown` (`uRadioConfigApply.pas:1202`) and written by
`MarkGridPromptShown` (`:1230`) -- and written *before* the modal opens, so a
crash mid-prompt does not re-arm it. A `WizardShown` flag beside it, set before
the wizard is displayed, gives the same guarantee for the same reason. Copy its
refusal rule too: `MarkGridPromptShown` will not write over a store it could
not read, and logs that it declined (`:1247`).

**Second: "no settings file" is not the same as "no configuration".** An
operator upgrading from 4.x has no `tr4w.json` and a complete `tr4w.ini` and
contest `.cfg`, and those are read unconditionally at `uProgramMain.pas:1687`,
`:1689` and `:1690`. Showing them a Station page is asking for a callsign they
have already given.

So the gate is evaluated **after** the configuration files are read, and the
question it asks is the same one the program is about to ask itself:

| condition at `uProgramMain.pas:~1727` | wizard |
|---|---|
| `tSilentExport` (or any headless switch) | **never** -- there is no operator, and a modal is a hang |
| `WizardShown` already set | no |
| first-run flag false (a settings file was there at `:1673`) | no |
| first run, and `MyCall` is non-empty after the config reads | **no** -- this is a conversion, not a new station |
| first run, and `MyCall` is empty | **yes** |

That last row is precisely the input to `ConfigurationOkay`
(`uProgramMain.pas:1729`), which is the next statement and which `halt`s on the
same condition. **So the wizard's natural home is immediately before it**: the
operator who completes it proceeds, and the operator who cancels meets the
existing "no callsign specified" warning and the existing halt. Nothing new
needs inventing for the cancel path, and nothing silently weakens the check.

**A corrupt or unreadable settings file is already handled and needs no
recovery flow of its own.** `ReadRootOrEmpty` (`uTR4WConfigFile.pas:216`)
copies unparseable content aside to `<file>.bad` (`:238`) and continues from an
empty object. The file is preserved, so nothing recoverable is destroyed, and
the run then looks like a first run -- which, with `MyCall` still coming from
the `.cfg`, lands on the "conversion, not a new station" row above.

---

## 7. Validation, and whether the wizard touches hardware

Three levels, and the distinction between the second and the third is the one
that matters:

| level | example | effect |
|---|---|---|
| required | `MY CALL` empty | cannot commit |
| format | TCP port out of range; a serial frame the radio cannot accept | cannot leave that page until corrected or the item is unticked |
| operational | COM port will not open; cluster host will not resolve | **commit proceeds**, the result page says so |

**The wizard does not open hardware by visiting a page.** A contest operator
sets TR4W up at a desk, on a laptop, with the radio at the other end of the
house and the USB-serial adapter still in a bag. A configuration that is
correct today and untestable today must still be creatable today.

**An explicit "Test connection" per hardware page is allowed** where the
existing code already supports it safely, and it is always optional and always
a warning rather than a gate. Whatever it opens it must close before Next,
Back, Cancel or commit -- and it must never open a WinKeyer through a CPU-keyer
port configuration, which is the double-open in section 4's keyer note.

**The format level is the editors' answer, not ours.** `SaveToRadio(out
aError)` already returns it (`uRadioEditForm.pas:247`); rule 3.1 means the
wizard shows that string and does not second-guess it.

---

## 8. i18n

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
   is every validation message, every derived label, and every line of the
   result page in section 4.

And one prohibition, which is not negotiable:

> **NEVER run `pas2po` to pick up new strings.** It rebuilds a catalogue from
> the `TC_`/`RC_` tables alone and drops every `.lfm` and resourcestring key
> the Lazarus harvest contributed -- measured 2026-08-29: **2,203 real
> translations destroyed across ten catalogues in one run**, with no warning
> and a clean exit. `po_merge --pot` is the additive tool and the only safe
> one.

---

## 9. Implementation notes

- A designed LCL form with a `TPageControl` whose tabs are hidden. Standard,
  and it keeps each page a designable surface. The page plan of section 2 is
  what decides which page is shown; the control does not hold the plan.
- `uNewContestForm` is the precedent in this tree for a task-focused dialog.
- **The radio and keyer editors are HOSTED, not copied** (changed 2026-11-14;
  the first build opened them as second windows and an operator lost one behind
  the wizard). Each editor form keeps its controls, handlers, translation and
  Preferences behaviour exactly, but everything except its footer buttons sits in
  one `pnlContent` panel. `EditRadioIn` / `EditKeyerIn` load the definition and
  move that panel into the wizard's page; `AcceptEdits` is the validation-and-write
  that the Save button also calls. The editors are still modeless in Preferences
  (`ShowModal` would run a second message loop and stop TR4W's key handling, CW
  timing and radio servicing), and the **wizard's startup run is modal** only
  because at that point nothing is being serviced yet.
- Every page independently valid, so Back never unwinds state.
- `.lfm` components that are not published fields need `RegisterClass` or the
  WHOLE form fails to stream -- see the agent memory
  `lfm-component-needs-registerclass`.
- `Lint-FormEvents` gates unwired designer events; an unwired handler is silent
  data loss.

---

## 10. Acceptance criteria

Written before the code, because most of these are about paths nobody exercises
by hand.

1. A station with no `tr4w.json` and no callsign gets **exactly one** wizard,
   and the `MY GRID` startup prompt does not also fire.
2. A station with an existing valid `tr4w.json` never sees it.
3. **A station with no `tr4w.json` but a `tr4w.ini`/`.cfg` carrying `MY CALL`
   never sees it** -- the upgrade case, and the one a file-exists gate gets
   wrong.
4. `/EXPORT` and every other headless switch create no UI and block on nothing.
   Run it with `MSYS_NO_PATHCONV=1`, or Git Bash rewrites the switch into a
   path and the test silently proves nothing (`uProgramMain.pas:2283`).
5. Cancelling commits no wizard value, and does not suppress the wizard on the
   next start unless `WizardShown` was set -- which it is, before the form is
   shown, so the suppression is deliberate rather than accidental.
6. Station only, no checkboxes: Station -> Checklist -> Commit, with no empty
   pages in between, and a usable configuration at the end.
7. Derived fields populate from the callsign and do **not** overwrite a field
   the operator has edited.
8. Each checkbox alone presents exactly its own page, and its values arrive in
   the existing store -- asserted by reading the store back, not by reading the
   form.
9. Multiple checkboxes produce canonical order regardless of click order.
10. Unticking discards the draft: re-ticking gives an empty page, and the
    commit writes nothing for it.
11. A radio, keyer, cluster or rotator failure at commit cannot discard the
    station identity already written.
12. A `.bad`-inducing corrupt `tr4w.json` preserves the original file and does
    not destroy a recoverable configuration.
13. The form streams in a clean build, including any non-published `.lfm`
    component class.
14. Every caption and every runtime string reaches the catalogues through the
    Lazarus harvest and `po_merge --pot`, and no step in the build runs
    `pas2po`.

---

## 11. Decided (formerly open)

All three of the open questions this document carried are closed.

**1. Does the checklist page remember its answers?** Yes, while the item stays
ticked. Unticking destroys the draft outright. Section 5 has the rule and the
reason: a retained-but-hidden draft is a half-written configuration waiting for
a later run to commit it. No confirmation prompt on unticking unless there is
real data in the draft -- a checkbox that argues back is worse than the data it
saves.

**2. Is there a "skip the wizard entirely" exit?** No, and there is no need to
invent one. **Cancel** is always available and contributes nothing; the
operator then meets `ConfigurationOkay`'s existing warning and halt
(`LogCfg.pas:239-243`, `uProgramMain.pas:1729`), which is exactly what happens
today to a station with no callsign. A callsign is required to commit. A path
labelled "Skip" that leaves the program unable to log would be a lie about what
it does.

**3. Does the wizard set `COMPUTER ID`?** No -- **and the premise that it is a
scattered first-run prompt was wrong.** `MainUnit.pas:6327` raises it only when
the operator opens the Network window, which is already the
ask-when-it-is-needed behaviour a wizard would otherwise have to build. It is
multi-op only; a single operator should not answer a networking identity
question to type their callsign. It stays where it is, and it stays out of the
wizard.

---

## 12. Considered and rejected

Recorded with the evidence, because a rejected recommendation that leaves no
trace gets re-proposed. All of these are from the 2026-09-11 critique, whose
author could not read the tree.

**"Permit three integration levels, because hosting an existing editor is risky
when it is a modal Apply/Cancel form."** The premise does not hold here. Both
editors are **modeless with a completion callback** and were built that way
deliberately -- `uKeyerEditForm.pas:30` states the reason (a `ShowModal` runs a
second message loop and stops TR4W's CW timing and radio servicing), and
`uRadioEditForm.pas:255` is the callback signature. There is no
Apply/Cancel lifecycle to be trapped by, so no three-level ladder is needed:
section 9 says host the editor's panel.

**"Cancel discards everything and creates no settings file."** Not
implementable. `uProgramMain.pas:1677` writes `tr4w.json` during startup,
before the wizard could be shown. Section 5 has what Cancel can actually
guarantee, and section 6 has the durable flag that replaces the file-exists
test the recommendation assumed.

**"An existing but invalid or corrupt settings file needs a separate recovery
flow, not first-run treatment."** Already answered, and better than a new flow
would be: `ReadRootOrEmpty` (`uTR4WConfigFile.pas:216`) copies the unparseable
file to `<file>.bad` (`:238`) and proceeds from empty. Nothing recoverable is
lost, and the operator's own configuration is still on disk to hand to support.
A recovery UI would be a second opinion about a file this unit already owns.

**"If a conversion source exists, run or offer the conversion path rather than
the wizard."** Half right, and the half that is wrong matters. Conversion in
TR4W is not a path that can be offered or declined -- `ReadInConfigFile(cfgCFG)`
runs unconditionally in `uProgramMain`. (~~`(cfgINI)`~~ was beside it until
2026-09-19; the legacy `tr4w.ini` is `tr4wconvert`'s input now and startup
does not read it, so a leftover ini is NOT a conversion this program
performs -- and deliberately not one it prompts about either.) So
the wizard is not an *alternative* to conversion; it is evaluated *after* it,
on whether a callsign arrived. That is the table in section 6, and it is why
the gate asks about `MyCall` and not about which files exist.

**"Remove the scattered first-run `COMPUTER ID` prompt and validate it when a
feature needs it."** The second half is already how it works, so the first half
has nothing to remove -- `MainUnit.pas:6327` gates it on
`ID = tw_NETWINDOW_INDEX`. See section 11.

**Any change to the page shape.** The critique endorsed the Station /
checklist / selected-pages / commit shape, so nothing was proposed against it,
but the rule stands for the next reviewer: six sequential pages was proposed
and rejected on 2026-09-11, and the shape is settled. Reopen it with NY4I, not
in a document edit.

**A nine-state lifecycle enum.** Over-specified for what this is. Four states
cover everything a test can observe -- section 5 names them. States like
"FailedBeforeStationCommit" describe a JSON write that the program already
performs at startup without ceremony; giving it a state name implies a failure
mode the code does not have.
