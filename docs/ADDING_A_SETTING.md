# Adding a setting

**Written 2026-09-14, because NY4I tried to add one and could not tell where it
went:** *"look at the various lists of commands you have, it would not be very
clear where to put the entries if I wanted to add a new command… Optimally
there would be one place (or maybe two for json and contest db cfg). This may
be a by product of the iterative refactoring."*

He is right on both counts. There are fifteen places a command name can appear,
and that IS an artifact of migrating 415 rows out of `CFGCA` one batch at a
time. **Most of them are not for new settings at all** — they exist to REMOVE a
command or to IMPORT an old file — but nothing said so, so all fifteen looked
like candidates.

This is the short answer, and then the long one.

---

## The short answer: TWO places, and the second is one line

```pascal
(* 1. uSettingsModel.pas -- the setting itself, in the group it belongs to *)
published
   property SpotAgeLimit: TSpotAgeLimit read FSpotAgeLimit write FSpotAgeLimit;
```

```pascal
(* 2. uSettingsDeclarations.pas -- so Preferences shows it *)
RegisterModelSetting('bandmap.spotAgeLimit', 'SPOT AGE LIMIT',
                     RS_BANDMAP_SPOTAGELIMIT);
```

That is it. The command NAME is **derived from the property path** —
`BandMap.SpotAgeLimit` gives `BAND MAP SPOT AGE LIMIT` — so you do not write it
twice, and `CheckCommand` resolves it for a config file, the multi-op peer sync
and the log's own config table without being told.

**The bounds go in the TYPE, not in a list:**

```pascal
type TSpotAgeLimit = 1..120;     // what crMin/crMax used to be
```

**A side effect goes in the SETTER**, or in `uSettingsEffects` if it needs to
repaint or touch another subsystem. Never in a table of hook indices — that is
what `crP`/`crA` were, and a hand-typed index compiles when it is wrong.

---

## The third place, and it is a ratchet not a definition

`tr4w/test/unit/uTestSettingsModel.pas` freezes the entire command vocabulary
as a literal. **Your new name will fail that test**, deliberately: a derived
name that invents a command TR4W never had would start claiming a multi-op
peer's message, and the frozen list is what makes that visible.

Paste the actual list from the failure **after** checking your new name reads
like something an operator would type. Do not regenerate it blindly.

---

## When you ALSO need one of the optional four

| you need | when | where |
|---|---|---|
| `Alias('MY CALL', 'My.Call')` | the derived name is not the name TR4W has always used | `uSettingsModel.BuildCommandMap` |
| `RegisterSettingAllowedValues` | it accepts a fixed VOCABULARY (not a range) | `uCFG`'s initialization, or the subsystem that owns the vocabulary |
| `RegisterSettingValueCheck` | it needs a check a type cannot express (`MY COUNTRY` must be a CTY.DAT prefix) | same |
| `SHARED_WITH_PEERS` | the positions in a multi-op MUST agree about it | `uCFG` |

**`SHARED_WITH_PEERS` is the one that is genuinely a list and should probably
not be.** It is a statement about the multi-op protocol rather than about the
setting, which is why it is not an attribute today — but it is 45 hand-typed
names, and the new multi-station work is where that question gets answered
properly.

---

## The twelve places that are NOT for a new setting

This is the actual source of the confusion. Every one of these exists to
withdraw a command or to read an old file:

| list | size | what it is really for |
|---|---:|---|
| `uCFG.RETIRED_COMMANDS` | 85 | **removing** a command: accepted so an old file does not error, then ignored |
| `uCFG.OWNED_BY_A_STORE` | 39 | a name the RADIO / KEYER / CLUSTER library owns, not the settings model |
| `uCFG.ACCUMULATING_COMMANDS` | 4 | commands a file may legitimately repeat |
| `uCFG.TryApplyCommandAction` | 4 | commands that DO something rather than set something |
| `uRadioConfigApply.MIGRATED_COMMANDS` | 247 | seeding the store from a legacy `tr4w.ini` |
| `uRadioConfigLegacyMap` | 111 | legacy key → store field |
| `ApplyJSONOwnedRadioKey` arms | 29 | the radio library's own per-slot keys |

**None of them is where a new setting goes.** If you find yourself adding a
name to one of these, you are either removing a feature or teaching the
importer an old spelling.

### And two of them are easy to get wrong in the same way

`RETIRED_COMMANDS` and `OWNED_BY_A_STORE` both **accept and ignore**, so a name
in the wrong one breaks nothing and lies in the log. On 2026-09-14 seven live
settings were sitting in `RETIRED_COMMANDS` — `HAMLIB DEBUG`, `TELNET DEBUG`,
`TCI DEBUG` and four others — so a config line for a setting that is in
Preferences was logged as *"is a withdrawn command"*.

**THE TEST FOR "IS IT REALLY RETIRED", from NY4I:** look the command up in the
ORIGINAL `CFGCA` array, which still exists in the D7 tree at `C:\TR4W`.

> `crAddress: nil` means it was already obsolete THERE.

Of the 93 names checked that way, 49 were `nil` (correctly retired), 41 had a
real target, and 3 had no row at all because they postdate D7.

---

## Where the VALUE ends up, which is the "one place or two" question

Two stores, and the setting does not choose — its GROUP does:

| | |
|---|---|
| `settings/tr4w.json` | the station's durable identity and preferences |
| the contest `.db` | what was true for THIS contest, at this point in time |

A group marked contest-scoped (`IsContestScoped`) is excluded from
`tr4w.json` by `TR4WSettings.ToJSON` and captured into the log's `config`
table by `uLogStore.CaptureConfiguration`. That is the whole mechanism: **you
put the property in the right group and the routing follows.**

`tr4w.ini` and the contest `.cfg` are **import formats, read once and
converted**, and converting them is `tr4wconvert`'s job, not TR4W's (NY4I,
2026-09-12). Do not add anything for them.

---

## Removing a setting

1. Delete the property and its registration.
2. Add the command name to `RETIRED_COMMANDS` — otherwise an operator whose
   file still names it gets a **modal** *"invalid statement in config file"*,
   once per stale line. That is the only reason the list exists.
3. Update the frozen vocabulary literal and the `RetiredCommandCount` floor.
