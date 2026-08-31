# Three things owed before TR4W leaves Windows

**Status: findings and plans. Nothing here is implemented.**

Raised by NY4I on 2026-08-30 while reviewing the DX Cluster page. Each was found
by asking an ordinary question of the running program, and each is the same
shape underneath: **a mechanism that works on one machine, in one language, on
one platform, and has no way to say when it does not.**

They are written up together because they share a deadline, not a cause. All
three are cheap now and expensive after the 64-bit and macOS/Linux work starts.

| # | item | size | urgency |
|---|---|---|---|
| 1 | Settings search misses whole classes of setting | small | now — it is silently wrong today |
| 2 | Searchable captions are not translatable | ~230 captions | with the i18n work |
| 3 | Two disagreeing file-path rules | 48 sites | before any non-Windows target |

---

## 1. The settings search cannot see three kinds of setting

**Symptom (NY4I):** searching Preferences for `TCI` returns nothing, though
"Enable the TCI Server" is plainly on the TCI Server page.

**Measured on the running program:**

```
[Prefs] search index: 255 entries (229 registered setting(s) exist)
```

The index is built from three sources and a setting reaches it only through one
of them:

1. **`FBindings`** — registered settings. Indexed **automatically**. This is the
   229, and it is the only path that cannot be forgotten.
2. **`AddHandWiredToSearchIndex`** — a **hand-maintained list**, currently 12
   lines, covering WSJT-X, the external logger and MMTTY. Anything else that
   edits a CFGCA command directly is absent until someone remembers.
3. **display-only rows** — resolved once their panel exists.

**TCI is in none of them, and could not be.** `chkTCIServer` is loaded from
`FStore.TCIServerEnabled` — a **store property**, not a CFGCA command.
`AddHandWiredToSearchIndex` takes a *command string*, so a store-backed control
has no way in even if someone tried. There are **17** such controls.

So there are three classes of setting and the index models two. TCI is not a
forgotten line; it is a missing category.

`SPOT COLLECTOR ENABLED` was the forgotten-line kind, and was registered on
2026-08-30 while moving it to the DXLab page — which is how this was noticed.

### What to do

**The route now exists** (2026-08-31). `AddStoreBackedToSearchIndex` registers a
control that has no command name, defaulting the searchable text to the
control's own caption so the index cannot drift from the screen, and leaving
`Command` EMPTY on purpose — that field is the legacy-name lookup key used by
`ShowPreferencesForCommand`, and inventing a name would make it answer for a
command that does not exist.

It turned out cheaper than it looked: `AddHandWiredToSearchIndex` never
*resolves* the command it is given, it stores the string and matches on it. The
blocker was only that there was no path for a control without one.

The four TCI controls are registered. **The remaining store-backed controls are
not** — they now have a route, but nobody has walked the pages.

### The size of it, measured from the settings file (2026-08-31)

Sectioning `commands` in `settings/tr4w.json` turned that file into an accidental
coverage report, because the section is derived from the registered key and a
command with no registration has none:

```
operating 60   contest 40   cw 20   appearance 16   audio 8   scoring 7
files 7        bandmap 6    ptt 5   network 4       scp 4     logging 3
hardware 3     advanced 2   cluster 2   voice 2     OTHER 54
```

**54 of 243 commands are unregistered** — `BAND MAP DECAY TIME`, `COMPUTER ID`,
`EXTERNAL LOGGER ADDRESS` and 51 more. They are real, live settings written
directly through `ApplyAndStoreCommand`; they simply never went through
`RegisterStoredSetting`, so they have no key, no declared caption and no
section.

That is the same population as this item's search gap, seen from another angle:
**the registry is the one place that knows a setting's identity, and a fifth of
them are not in it.** The `other` bucket is deliberately named rather than
merged into the sections, so the file keeps reporting the number.

54 is also the better figure to plan against than the 17 store-backed controls
counted earlier — different measure, related cause, and larger.

**What is still owed is the lint.** A hand-maintained registry that nothing
checks will drift again the day after it is corrected, and there is still no
proof there is not a fourth class of setting. `Lint-FormEvents` shows the
shape: walk every `TCheckBox` / `TEdit` / `TComboBox` on a section panel, and
fail the build if it is in neither `FBindings` nor the index.

---

## 2. Searchable captions are English-only, and search matches on them

`BuildSearchIndex` stores `s.Caption` and `s.LegacyCommand`, and `RunSearch`
scores against both. The captions come from the third argument of
`RegisterStoredSetting`:

```pascal
RegisterStoredSetting('appearance.ctrlj.showFrequencyInLog', 'SHOW FREQUENCY IN LOG',
                      'Show Frequency In Log');
```

**Plain Pascal string literals.** Not `resourcestring`, so not in
`uTR4WStrings`, so not in the catalogues, so never translated. There are
**230** of them.

The consequence is worse than an untranslated label:

- A German operator searching `Frequenz` gets nothing. The index holds
  `Show Frequency In Log`, so they must search in **English** for a setting
  whose on-screen label is German.
- `FSearchIndexBuilt` is a one-shot flag, so even once the captions translate,
  the index would keep whatever language was live when it was first built.

### What to do

Move those captions into `uTR4WStrings` as `resourcestring`, which puts them in
the catalogues by the existing route, and **rebuild the index on a language
change** rather than caching it for the session.

### Performance: it is imperceptible, and here is why

NY4I asked whether assigning captions from resourcestrings each time would
cost anything. Two halves, and only one is real.

**Reading a resourcestring is free.** `uTR4WStrings`'s own header explains it:
the compiler emits a string table, and LazUtils' `Translations` unit
**replaces** the entries at run time from the `.po`. That happens once, when
the language loads. Afterwards a reference is a global string-variable read — a
refcounted pointer copy. It is not a per-access resource lookup, so it costs no
more than a `const`.

**Assigning `.Caption` is the real cost**, and it is identical whatever the
text's origin: a property setter that may invalidate and repaint. `uMainForm`
already guards exactly this:

```pascal
if GElements[aElement].Caption <> aText then
   GElements[aElement].Caption := aText;
```

A string compare is far cheaper than a repaint, and on a second show nothing
changes so nothing happens.

**Against what actually hurt in this tree:** opening Preferences once cost
**3943 ms**, cut to **268 ms**, and the cause was combo-box item counts — fixed
by filling on `OnEnter`. The Telnet host list cost **1741 ms** for 726 items,
because a Win32 `TComboBox`'s `Items` proxy the native control and every add is
a round trip. Those are hundreds of thousands of window messages.

~230 guarded caption assignments on in-process LCL controls, once per show, is
not in that universe. `uServerLogForm` already assigns all of its captions in
`HandleShow` and nobody has noticed.

**The one thing that would be slow** is rebuilding the *search index* per show —
it walks bindings and resolves panels and nav nodes. Keep it one-shot; the
correct trigger is a language change, which happens approximately never.

---

## 3. Two file-path rules that disagree

**Symptom (NY4I):** the Server drop-down on the DX Cluster page was empty, while
the DX Cluster *window* listed servers from the same file.

```
[Prefs] cluster directory: 0 entries in 16 ms (once per run)
```

Both read `TRCLUSTER.DAT`. They resolve it differently:

| mechanism | resolves to | used by | sites |
|---|---|---|---|
| `TR4W_PATH_NAME` | `GetCurrentDirectory` — the **working directory** | the legacy tree: `EnumerateLinesInFile`, CTY.DAT, TRMASTER, band map, history | 39 |
| `ExtractFilePath(ParamStr(0))` | the **binary's** directory | the Preferences cluster picker | 7 |

Running `build-out\...\tr4w_fpc.exe` with the working directory `tr4w\target`
sends those to different places. The window found the file; the picker did not.
**Same filename, two answers, neither wrong on its own.**

The shipped layout hides it: `FullBuild.ps1` puts `tr4w.exe` in `target\`
beside the data, so both rules agree there. It only shows up when testing a
binary from `build-out`, which is exactly what a developer does.

### Why neither rule survives the move

- **Working directory is the weaker one.** It depends on how the program was
  launched — a shortcut, `Run`, a file association or a debugger each give a
  different answer, and TR4W then silently reads nothing.
- **`ParamStr(0)` at least means "where I am installed"**, which on Windows *is*
  the data directory.
- **Neither works off Windows.** On macOS the binary is in
  `App.app/Contents/MacOS/` while read-only data belongs in
  `Contents/Resources/`; on Linux it is `/usr/bin` against `/usr/share/tr4w`.
  Neither location is writable, so `settings/` and the logs need a third answer
  again — the same conclusion the settings-location/APPDATA question reached
  and tabled.

### What to do

**One accessor per KIND of file, not one accessor.** The kinds genuinely
differ and collapsing them is how this recurs:

- `DataFilePath(name)` — shipped, read-only: `TRCLUSTER.DAT`, `CTY.DAT`,
  `TRMASTER.DTA`, `dom\`
- `SettingsFilePath(name)` — writable per-operator: `tr4w.json`, `tr4w.ini`,
  window positions
- `LogFilePath(name)` — writable, possibly large: `tr4w.log`, contest logs

One Windows implementation today, both returning what they already return, so
the change is behaviour-preserving. Then **one place** grows a platform arm.

**And a lint**, for the same reason as item 1: a raw `ParamStr(0)` or
`GetCurrentDirectory` will reappear the moment someone needs a file, and it
will work on their machine.

### One fix worth doing immediately, independent of the rest

`LoadClusterServerList` has no `else` on its `FileTextExists` check. A missing
directory file produces an empty picker and an `info` line reading
`0 entries`, which looks like an empty file rather than an absent one. It
should log **the path it looked in and that nothing was there**. That is the
difference between an operator reading one log line and asking someone.

---

## Suggested order

1. **The `LoadClusterServerList` else-branch.** Minutes, and it makes the next
   instance of item 3 self-diagnosing.
2. **Decide the store-backed-setting route**, then write the search-index lint
   (item 1). It is silently wrong today, in a feature operators are told to use.
3. **Item 3's three accessors**, before any non-Windows work rather than during.
4. **Item 2 with the i18n effort**, since it is the same catalogues and the
   same tooling.
