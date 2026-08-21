# Retiring the ini: moving CFG commands to JSON

**Written 2026-08-14** after auditing the current state. This is the *how*; the per-setting status
table is at the end.

## The rule (NY4I)

When a setting moves from the old world to the new one it must, in one step:

1. be marked **`csJSON`**, so it disappears from Ctrl-J;
2. no longer be **read from or written to `tr4w.ini`**;
3. have every reference to its controlling variable go **through the config object**, so the
   global disappears.

### What still touches `tr4w.ini` (measured 2026-08-21 -- RERUN THIS, do not trust its age)

NY4I, 2026-08-17: *"Nothing should use the INI file again. I am not sure how much clearer I can
make that rule."*

**Measured with the lint's own reader** (`Lint-Win32Dialogs -Group platform`, which strips
comments and skips editor debris), not with a grep -- a grep over this tree counts commented-out
code and reports numbers 20-60% high. **26 sites outside `tr4wserver`**, and they are not one
kind of thing:

| Where | Sites | What it does | Verdict |
|---|---:|---|---|
| `uCAT.pas` | 11 | writes `[Radio]` keys | **the mirror** -- radios live in JSON; this is a second copy |
| `uRadioConfigApply.pas` | 2 | writes `[Radio]` keys | same mirror |
| `MainUnit.pas` | 4 | writes/reads `[COMMANDS]` (incl. a key-rename helper) | the `csOwned` remainder |
| `uCFG.pas` | 1 | `SetCFGCommandValue` writes `[COMMANDS]` | the legacy write path, still used by 153 settings |
| `uNewContest.pas` | 1 | reads `MAIN CALLSIGN` | the `csOwned` remainder |
| `uBandPlanForm.pas` | 1 | writes `[BAND PLAN]` as a section | multi-valued; no JSON home yet |
| `uOption.pas` | 3 | Ctrl-J: help `DESCRIPTION`/`DEFAULT`, and its own write | Ctrl-J is nearly empty now |
| `uCabrilloHeader.pas` | 1 | reads a section ONCE per installation | **legitimate** -- the JSON seed |
| `MainUnit.pas:8129`, `uEditMessageForm.pas` | 2 | write the contest `.cfg` | **not this rule** -- see below |

**The contest `.cfg` is deliberately excluded, and now has a stated reason** (NY4I,
2026-08-21): *"We left the contest.cfg as that will be going to an sqlite3 contest file."* So
those two sites are not ini debt at all; they are waiting on a different move.
`tr4wserver.ini` is a separate program's config and is out of scope (NY4I).

### The per-setting migration, which is the number that was drifting

The section above counts CALL SITES. The number that describes progress is how many SETTINGS
have graduated, and it is measurable in one line each:

| | count |
|---|---:|
| `RegisterStoredSetting` -- writes `settings\tr4w.json` | **77** |
| `RegisterLegacySetting` -- still writes `tr4w.ini` | **153** |
| `csJSON` CFGCA rows with no registered setting (radios, keyers, windows, UDP: owned by their own stores) | 89 |

**So "we moved to JSON" is true of the STORES and of 77 settings; it is not yet true of the
other 153.** `tr4w.ini` is still read at startup and still written by those. That gap is what
made this document's status drift: the stores moved wholesale and visibly, the settings move one
at a time.

**The two halves are IN SYNC, which is the good news** and was verified rather than assumed on
2026-08-21: cross-referencing every `RegisterLegacySetting` command against its CFGCA row found
**0** settings that write the ini while marked `csJSON` (the "appears to save, gone on restart"
failure this document warns about), and **0** graduated writers whose row is not `csJSON`. The
discipline in the rule below has held for all 230.

### The 41 settings still on the ini, 2026-08-21 -- and why each one is

**112 migrated overnight** (77 -> 189 stored, 153 -> 41 legacy). What is left is
not a queue of identical work; it is four different problems.

| what | count | why it is still on the ini |
|---|---:|---|
| `ckList` | 30 | **rendered READ-ONLY in Preferences** -- see below, this is the one worth doing |
| `ctMessage` (QUICK QSL x5) | 5 | `crJ: 2` -- read-only rows; nobody can edit them, so moving their storage moves nothing |
| `CLEAR DUPE SHEET` | 1 | **not a setting, and its stored value would be meaningless** -- see below |
| `CONTEST NAME`, `REMINDER` | 2 | `crJ: 2`, read-only; `CONTEST NAME` is set by the contest |
| `PADDLE PORT` | 1 | LPT, and LPT is settled as-is (section 17 of the bench queue) |
| `BAND MAP CUTOFF FREQUENCY`, `FREQUENCY MEMORY` | 2 | `ctFreqList`, multi-valued -- one ini line per band, no JSON home yet |

**`CLEAR DUPE SHEET` deserves its own paragraph, because the first write-up of
it here was wrong.** It said persisting `TRUE` would clear the dupe sheet on
every start. It would not: NY4I supplied the reference manual (4.2.49) --
*"Program will clear the dupesheet when this parameter is set to TRUE in a
*.CFG file that is executed with the ctrl-V command. TR4W does nothing if the
command is found in the *.CFG file during the start-up process"* -- and the
code implements exactly that, in the hook rather than the caller:

```pascal
function F_CLEAR_DUPE_SHEET: boolean;
begin
   ClearDupeSheetCommandGiven := RunningConfigFile;
   Result := True;
end;
```

The hook IGNORES the value in the file and sets the flag from
`RunningConfigFile` -- true only while a `.CFG` is being executed with Ctrl-V,
false at start-up. So the real reason not to migrate it is better than the
scary one: **whatever were stored could never be the value used.** It is a
transient action flag that lives in `CFGCA` only because that was the
mechanism available. It wants reclassifying, not moving.

**Nine of those eleven non-`ckList` rows should probably never migrate.** A
read-only row and an action trigger do not belong in a settings store at all; if
anything they want reclassifying, not moving.

### Unlocking the 30 `ckList` rows -- analysed, NOT done

These are the ones worth having: they are real settings an operator would want
to change, and today **Preferences renders them read-only** so nobody can. The
blocker is one function.

**What is already true, and was verified rather than assumed:**

* `CFGCommandValueAsString` ALREADY returns the right thing for `ckList` -- it
  reads the spelling straight out of `ListParamArray[..].lpArray` at the current
  `lpVar^`.
* `CheckCommand`'s `ckList` arm ALREADY accepts a spelling: it calls
  `GetValueFromArray`, which searches that same array.
* So the round trip is sound in principle. The only missing piece is
  `CFGCommandAllowedValues`, which handles `ckArray` and returns `nil` for
  `ckList` -- which is what makes `CFGCommandIsList` force the row read-only.

**THE TRAP, and it is why this was not done unattended.** `GetValueFromArray`
matches with `StrComp` -- an EXACT comparison. The spellings in these arrays are
SPACE-PADDED to a fixed width. That is the whole of the `SINGLE BAND SCORE`
incident recorded above: `AsText` returned the padded `'All '`, the generated
text box handed back the trimmed `'All'`, and `CheckCommand` refused it, writing
`SINGLE BAND SCORE=All` into `tr4w.ini` and breaking every later start with
"Invalid statement in config file".

So the work is:

1. Extend `CFGCommandAllowedValues` to enumerate `ckList` from `lpArray`,
   returning the spellings **exactly as stored, padding included**.
2. Make sure the Preferences binding hands the chosen item back **untrimmed** --
   this is the step that will bite, and it wants a test that round-trips a padded
   spelling through `TrySetText` and back.
3. Only then drop `ckList` from `CFGCommandIsList`, so the rows render as
   drop-downs instead of disabled boxes.
4. Then migrate all 30 with `tools`-style batching and the three-way lint.

Doing 1-3 without 2 proven is how `SINGLE BAND SCORE` happened, and it corrupts
the operator's ini rather than merely failing.

### Corrected 2026-08-21: two claims in the older table were wrong

* `uAutoCQ.pas` and `LPT.pas` were listed as writing `[COMMANDS]`. **They no longer do** -- both
  were repointed at some point after 2026-08-17 and the table was never updated.
* `[REPORT]` and `[ERMAKREPORT]` were listed as **"Done and not to be reopened"**. The MIGRATION
  was done -- `uCabrilloHeader` reads them from JSON with a one-time ini seed -- but **four
  readers in `PostUnit.PAS` were missed** and went on reading `tr4w.ini` directly: the three
  Cabrillo-summary fields in the 3830 report (`_OPERATORS`, `_CATEGORY-OPERATOR`,
  `_CATEGORY-POWER`) and the Ermak operator-info loop.

  **That was a live defect, not a tidiness issue.** On any station that edited its Cabrillo
  summary after 2026-08-16 the values are in `settings\tr4w.json`, so the 3830 report was
  emitting the PRE-MIGRATION ini values -- or blank lines on a station with no `tr4w.ini` at
  all. Silent, because a blank there is indistinguishable from a field the operator left empty.
  Fixed 2026-08-21; `PostUnit` already imported `uCabrilloHeader`, so the fix was to call
  `HeaderTagText` like every other reader.

  **The lesson for the rest of this list:** migrating a section is not finished when the OWNER
  reads JSON. It is finished when every reader does, and readers in other units do not announce
  themselves. Grep for the section NAME, not for the unit.

### Two steps the rule implies but does not say, and both are silent when missed

**4a. …and the seeding has to actually run. It did not, for two weeks.** `SeedMigratedCommandsFromIni`
was called only from inside `ApplyActiveProfileToConfigAtStartup`, which **exited early when
`settings\tr4w.json` did not exist** (`uRadioConfigApply.pas:1461`) — "this station has never opened
Preferences, and must boot exactly as it always did".

That sentence stopped being achievable the moment the first row moved. A `csJSON` row is inert to
the ini loader, so on a station with a populated `tr4w.ini` and no `tr4w.json`, **every migrated
setting fell back to its compiled default** — all 161 of them — with no error and no log line.

Measured, not reasoned: same `tr4w.ini` with `HF BAND ENABLE=FALSE`, same binary. With no
`tr4w.json`, nothing seeded and the value was lost. With a `tr4w.json` containing nothing but `{}`,
all values carried across. **An empty object was the entire difference.**

Fixed 2026-08-16: the guard is about the *radio library*, so only radio work stays behind it. Seed
and apply now run against an empty store first — a no-op for a station that genuinely has nothing.
Verified with `CW SPEED INCREMENT = 2`, the very "2 becoming 3" case described below.

**4. Seed the existing ini value into the store, once.** A `csJSON` row is inert to the ini loader,
so on the first run after the flip nothing applies the value the operator set months ago — it is
still sitting in `tr4w.ini` and the setting reverts to its compiled default. For
`CW SPEED INCREMENT` that is 2 becoming 3. There is no error, no log line, and nothing for the
operator to notice until mid-contest. `SeedMigratedCommandsFromIni` (`uRadioConfigApply`) carries
each migrated command across once, and every flip adds its command to that list in the same commit.

**5. Check `crNetwork`.** A row with `crNetwork: 1` is propagated between multi-op positions, and
the receiving end (`uNet.pas:327`) applied it with a bare `CheckCommand` — which is inert for
`csJSON`. So flipping a network-synced row silently stopped peer propagation for it: the station
that made the change saw it work, the others neither applied it nor said anything. **Seventeen rows
were already in that state before this work started**, the whole UDP broadcast block among them.
Fixed at the layer that owns the question rather than per row: `ApplyPeerCommand` routes on the
row's own state and persists to whichever file is that row's system of record.

## Every parameter is a registry parameter (NY4I, 2026-08-16)

An earlier draft of this plan sorted rows by *who owns the value* and used that to decide whether a
row should migrate **at all**: category B was held back as "contest properties wearing a settings
costume", `LEADING ZEROS` because a contest `.cfg` writes it, `MY CONTINENT` because the contest
supplies it. **That line is artificial, and it is withdrawn.**

> "We are drawing an artificial line between contest parameters and others. All parameters should go
> into the registry. The only question today is where we set those." — NY4I, 2026-08-16

The registry is the **system of record for the value**. It is not a claim about who writes it, and
"something other than the operator writes this" was never a reason to leave a parameter in the ini.
So the migration question collapses to the five-step rule for **every** row, and what remains open is
a smaller, different question:

| question                                                      | answer                                                                       |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Does it live in the registry (`csJSON`, `settings\tr4w.json`)? | **Yes — always.**                                                            |
| Who sets it?                                                   | `FCONTEST` on contest selection, a contest `.cfg`, the operator, or the session |
| Where is it shown?                                             | its natural panel; contest-set values on the **Contest** panel for now       |

**Where a value is set is a UI and ownership question, not a storage question.** Most contest-driven
parameters are set by `FCONTEST` when a contest is selected. The rest go on the **Contest settings
panel for now**, and several of those will move into the contest factory later — but that is a later
move of the *editor*, not of the *storage*, and it does not block the row from migrating today.

What this does **not** dissolve: the layering question in A-bis. "Which layer does an edit write —
the station default or the event override?" is real, and it is about *write semantics*, not about
whether the row belongs in the registry. It is now the only genuine blocker in the set.

### The UI half, as it stands today

`NAV_CONTEST = 10` and a "Contest" nav item already exist (`uPrefsForm.pas:3107-3108`), but **no
panel carries Tag 10** — selecting it shows the placeholder. Building that panel is the work this
principle creates.

The band-enable rows show the point is already settled in shipped code: `layBands` (Tag 24) carries
`chkHFBands` / `chkWARCBands` / `chkVHFBands`, bound to `operating.bands.hf|warc|vhf`
(`uPrefsForm.pas:3356-3358`). The panel that the previous draft said should show those "read-only or
not at all" **already edits them**.

## What is actually true today

**Twenty-seven of the thirty have completed the move, and one has been removed rather than
migrated.** They are `csJSON`, gone from Ctrl-J, written by Preferences to
`settings\tr4w.json`, their existing ini values carried across once, and their globals are now
fields of `Config`.

`CW SPEED INCREMENT` went first because it is the one NY4I saw duplicated between Preferences and
Ctrl-J. Then the five HAMSCORE settings, then the thirteen of category A below — the SO2R/two-radio
group, the small CW settings, the scoreboard URLs and the cluster connect-at-startup flag. HAMSCORE went second on purpose: it is the first **string** group, and a `ctString` row
aimed at anything other than a `ShortString` would write 256 bytes into the next field with nothing
to report it — not the compiler, which sees only a pointer, and not a test, because the damage lands
elsewhere. The `Config` fields therefore carry the *exact* old types.

The remaining 3 are still `csOld`/`csNew`: they show in Ctrl-J, round-trip through the ini, and
drive a global each. The bridge they still use is:

```
Preferences -> TLegacySetting.TrySetText -> SetCFGCommandValue -> WritePrivateProfileStringA -> tr4w.ini
```

So the new UI writes the old store. A deliberate bridge, not a defect — but one that has now been
crossed twenty-four times and needs crossing 6 more.

### A password in the ini is not trustworthy as a password

Ctrl-J displays `ctPassword` rows as a fixed `********` mask. `uOption.pas:761` refuses to write that
mask back — but an existing file can already contain it, and **NY4I's does**:

```
HAMSCORE PASSWORD=********
```

Carrying that across would set the password to the literal mask and produce an authentication
failure that reads like a server problem. A masked value is indistinguishable from a real one, so seeding skips `ctPassword` rows entirely and logs that the operator should type it once in
Preferences. Note what this also says: that ini value is *already* useless to the running program,
so the migration lost nothing that was working.

Passwords in `settings\tr4w.json` are plaintext, exactly as they were in `tr4w.ini`, and that file
already holds cluster and server passwords. Not made worse here — but it is the open decision this
work should not finish without.

### Decided 2026-08-16 (NY4I): a secret store, not an encrypted config

The first form of this decision was "encrypt the passwords with a build-time key, held in GitHub
secrets and a local env var." **Superseded the same day**, for two reasons that came out of working
it through:

1. **A key inside the binary is obfuscation, not secrecy.** Every install ships the same key, so one
   extraction with a debugger breaks every user at once. It would have bought exactly one thing —
   that a password is not *readable* in a file the operator hands over — while requiring CI secrets,
   an env var, a rotation story, and an "unconfigured build" failure mode.
2. **The OS already does this properly, and for free.** No key to ship, rotate, or leak.

**Two stores, and the split is the whole point:**

| file                     | holds                                       | safe to send? |
| ------------------------ | ------------------------------------------- | ------------- |
| `settings\tr4w.json`     | everything else — **no secrets, ever**      | **yes**       |
| the platform secret store | passwords only, machine- and user-bound     | it never leaves |

That makes `tr4w.json` a file the operator can attach to a bug report or hand to a fellow op without
thinking about it, which is worth more than encrypting it in place: an encrypted blob still travels
with the config, and the key travels in the download.

### The contract is a KEYRING, not a blob encryptor

The shape matters more than the mechanism, because the mechanism differs per platform and the shape
must not:

| platform | mechanism                                   | shape it offers        |
| -------- | ------------------------------------------- | ---------------------- |
| Windows  | DPAPI (`CryptProtectData`) over a small file | encrypt a blob         |
| Windows  | Credential Manager                          | store a **named secret** |
| macOS    | Keychain Services (generic password items)  | store a **named secret** |
| Linux    | Secret Service / libsecret                  | store a **named secret** |

**Two of the three platforms only offer a keyring.** DPAPI is the odd one out, so an interface in
DPAPI's shape would have to be emulated on macOS and Linux — an abstraction fighting the platform on
two of three targets, and the kind of mistake that only surfaces when the second platform lands,
which is when it is most expensive to fix.

```pascal
ISecretStore = interface
   function  Available: boolean;                                    // honest "no store here"
   function  Store (const aName, aSecret: string): boolean;
   function  Fetch (const aName: string; out aSecret: string): boolean;
   function  Delete(const aName: string): boolean;
end;
```

Names are stable identifiers, not UI labels: `hamscore`, `server`, `cluster/<node>`,
`radio/<name>/network`, `qrz`.

**The backend is then free to differ.** The caller asking for the cluster password does not care
whether that is a Keychain item or a DPAPI-decrypted line in `settings\tr4w.secrets`. So on Windows
use **DPAPI over a file**, not Credential Manager — it avoids CredMan's per-item naming layer, whose
target names are **case-insensitive**, so `TR4W/Cluster/NC7J` and `tr4w/cluster/nc7j` collide
silently. DPAPI has no naming layer to get wrong.

NY4I's compile-time key keeps a real role — as DPAPI's `pOptionalEntropy`, so another program
running as the same user cannot decrypt TR4W's blob merely by calling `CryptUnprotectData`. That is
what a baked constant can honestly provide; being *the* key is not.

**Only the Windows backend gets written now.** macOS and Linux ship as stubs returning
`Available = False` — truthful rather than broken. Settling the interface first is the entire point:
they drop in later without touching a caller.

### Failure is a normal state, not an exception

- **A DPAPI blob does not survive an admin password *reset*** on a local account (a password
  *change* is fine — Windows re-wraps the master key), nor a new user profile.
- **Linux has no guaranteed keyring**: Secret Service needs a D-Bus session and a running daemon,
  absent on a headless box or over SSH. `Available = False` is ordinary there.

So the UI must say *"the saved password can't be read on this machine — please re-enter it"*, once,
and **never fall back to sending an empty password**. A silent empty auth to a cluster or to QRZ
looks like a server fault and is precisely the silent downgrade this project treats as a defect.

A fourth backend — an encrypted file unlocked by a passphrase typed once per session — works
identically on all three platforms, is the honest floor when no OS store exists, and is the only
option that offers real secrecy. Worth having as opt-in; wrong as the default, because a contest
station must come up unattended and reconnect the cluster after a power blip.

**Also required:** a format version so existing plaintext files are read and upgraded rather than
rejected, and passwords stay out of the multi-op peer sync regardless — which the split enforces
structurally, since the ciphertext is useless on another position.

### Every secret TR4W holds — the inventory the split has to cover

Audited 2026-08-16. This is the list `ISecretStore` must serve, and the list that must be **absent
from `tr4w.json`** before anyone is told the file is safe to send.

| secret                        | today                                     | secret name              |
| ----------------------------- | ----------------------------------------- | ------------------------ |
| `HAMSCORE PASSWORD`           | `csJSON` → `tr4w.json`                    | `hamscore`               |
| `SERVER PASSWORD`             | `csJSON` → `tr4w.json`                    | `server`                 |
| `RADIO ONE NETWORK PASSWORD`  | `csJSON` → `tr4w.json`                    | `radio/<name>/network`   |
| `RADIO TWO NETWORK PASSWORD`  | `csJSON` → `tr4w.json`                    | `radio/<name>/network`   |
| radio library `networkPassword` | `tr4w.json` (`uRadioConfigStore:1633`)  | `radio/<name>/network`   |
| cluster library `password`    | `tr4w.json` (`uRadioConfigStore:1748`)    | `cluster/<node>`         |
| QRZ                           | **not implemented yet**                   | `qrz`                    |

`RADIO ONE/TWO ICOM NETWORK PASSWORD` are `csRem` back-compat aliases and need no entry.
`TRadioConfigStore.SaveTo(aIni)` writes `NetworkPassword` to an ini (`:1444`) but **has no callers** —
a dead path, confirmed by call-graph, not by inspection. Delete it rather than leave a plaintext
writer lying in the tree.

### Two exposures the split does NOT close

Both were checked rather than assumed, and neither is a reason to delay the split — but the claim
"send me your config" must be scoped to `tr4w.json` and no wider until they are fixed.

**1. Stale plaintext left behind in `tr4w.ini`.** Seeding deliberately **skips `ctPassword` rows**
(the `********` mask problem above), and nothing erases the old key. So an operator who set
`HAMSCORE PASSWORD=` before the flip still has that value sitting in `tr4w.ini`, orphaned and
unread. **Add a one-time scrub of migrated password keys from the ini**, in the same pass as the
secret store — otherwise the split produces a clean `tr4w.json` while the older file still carries
the secret.

**2. `tr4w.log` is the file operators actually send.** It is clean *today*, and that is by design
rather than luck — worth recording so it stays that way:

- the cluster password is sent by `SendClusterPasswordQuietly` (`uTelnet.pas:1456`), which writes
  `<password sent>` to the console instead of the value — and the console **is** logged
  (`uTelnet.pas:1638`), so the masking is load-bearing;
- HamScore puts the password in the HTTP **Basic-Auth header**
  (`http.Request.Password`, `uHamScore.pas:651`); the `payload=%s` logged at TRACE
  (`uHamScore.pas:659`) is the QSO XML, not credentials;
- the Icom network transport logs the session **token**, not the password
  (`uIcomNetworkTransport.pas:1019`).

The one remaining path is an operator **typing** a password into the telnet window by hand, which
is echoed to the console and therefore to the log. Operator-initiated rather than stored-credential
leakage, but it is the reason "the log is safe" should never be stated more strongly than "TR4W does
not write your stored passwords to it".

### Keeping it clean: `LogConfigParameter` and a lint (NY4I, 2026-08-16)

> "a string function called `LogConfigParameter()` that determines if it's secure to mask will be a
> good way to avoid logging info. Of course, if a patch decrypts a password and logs it, that is
> something we can catch with a commit hook."

Right on both counts, and the two halves cover different failure modes: the function makes the safe
thing the easy thing, and the lint catches the case where someone bypasses it.

```pascal
function LogConfigParameter(const aName, aValue: string): string;
// Renders "NAME=value" for a log line, masking the value when the parameter is
// a secret.  Use this instead of formatting a config name and value by hand.
```

**Derive the decision, do not maintain a list.** `CFGCA` already records `crType: ctPassword` for
every password row, and `FindCFGCommand` already looks a row up by name. A hand-kept list of secret
names would be a second source of truth that silently goes stale the day someone adds a row — the
same drift that put three copies of the HTTP downloader in this tree. So:

1. look the name up in `CFGCA`; `crType = ctPassword` → mask;
2. for names that are **not** CFGCA rows — the JSON store's `networkPassword`, the cluster
   library's `password`, `qrz` — fall back to a name test (`PASSWORD`, `PASSWD`, `SECRET`, `TOKEN`);
3. **unknown name → mask.** Fail closed. A parameter nobody recognises is far more likely to be a
   misspelling of a real one than something that had to be logged in full, and the cost is
   asymmetric: a masked value costs one debugging round-trip, a leaked one cannot be recalled.

Mask to a **fixed-width** `********` regardless of length — a mask that reveals the length is a mask
that leaks something.

**The lint: `Lint-SecretLogging.ps1`, added to the `Run-Lints.ps1` array**, not a separate commit
hook — the ten-lint array already gates the build on every path, which a hook does not.

The rule: in a `logger.Debug/Info/Warn/Error/Trace(fmt, [args])` call, examine **the argument array,
never the format string**. A literal that merely contains the word is fine and must not fire —
`uIcomNetworkTransport.pas:1009` legitimately logs `'Authentication failed - check
username/password'`. Firing on that would make the lint noise, and this project has already learned
where that ends: *"a linter that fires on commented-out code gets ignored"* (Lint-PCharAnsi's first
run reported five violations, all five false). So the check is narrow and about **identifiers**:
flag an argument matching `Password|Passwd|Secret|Token` unless it is a call to
`LogConfigParameter`, with an explicit `// lint:secret-ok` escape for a reviewed exception.

And per the guards-must-not-fail-open rule: **give it a floor.** If the scan finds fewer than a few
hundred `logger.` calls, the pattern is broken rather than the tree clean, and it must fail rather
than report success.

### Two additions that enforce it rather than ask for it

`LogConfigParameter` and the lint are both good and both stay. What they share is that they depend
on **discipline** — remembering to call one, and a text scan catching what the other misses. These
two remove the discipline.

**1. A test that asserts the promise. Cheapest, and do it first.**

The claim this whole design exists to support is *"`tr4w.json` is safe to send."* That should be a
test, not a promise:

> Build a config with **every** secret populated with a distinctive sentinel — `hamscore`, `server`,
> both radio network passwords, the radio library's `networkPassword`, a cluster definition's
> `password` — serialise it exactly as `SaveConfig` does, and **assert that no sentinel appears
> anywhere in the output text.**

It is deterministic, needs no OS store, runs in the existing 4165-test suite, and it fails the
moment someone adds a secret-bearing field to the serialiser. Nothing else on this page keeps the
claim true two years from now; this does. Pair it with the inverse — round-trip through
`ISecretStore` and assert the value comes back — so "no secret in the file" cannot be satisfied by
accidentally not saving it at all.

**2. Make a secret un-loggable by TYPE, so leaking it has to be deliberate.**

A masking function must be remembered. A type cannot be forgotten:

```pascal
type
   TSecret = record
   private
      FValue: string;
   public
      class operator Implicit(const aValue: string): TSecret;
      function Reveal: string;      // the ONLY way out -- and greppable
      function ToString: string;    // always the fixed-width mask
   end;
```

The property that makes this better than masking-at-the-call-site: **a record cannot go into an
`array of const`**, so `logger.Info('pw=%s', [FPassword])` stops *compiling* once `FPassword` is a
`TSecret`. Not masked at runtime — rejected at build time, in every branch, including the ones no
test covers.

That also collapses the lint into something precise. Instead of guessing at identifier names, it
audits `.Reveal` call sites, of which there should be a countable handful — the telnet send, the
HamScore Basic-Auth assignment, the Icom login packet, the server login. Any `.Reveal` in the same
statement as a `logger.` call is the actual defect, and any *new* `.Reveal` site is worth a review
comment. Fewer false positives, and it catches the "a patch decrypts a password and logs it" case
NY4I raised — because decrypting now means calling `Reveal`.

**Verify `class operator Implicit` on records under FPC 3.2.2 / `-Mdelphi` before committing to
this.** Advanced records with operators are supported, but confirm it compiles in this tree rather
than assume — that is the whole reason the spike existed.

**A smaller note while the types are being touched:** the plaintext currently lives in
process-lifetime globals (`TelnetPassword`, `FPassword`, `ServerPassword`). TR4W ships `tr4w.dbg`
and writes stack traces on a fault, not minidumps, so the exposure is small today — but fetching
from `ISecretStore` at point of use rather than holding it for the session is strictly better and
costs nothing while this code is open.

## The machinery for crossing it already exists, and it works

This is the important finding: **no new plumbing is needed.** The path is built, wired, and proven
by the radio rows.

| piece                                 | where                      | what it does                                                     |
| ------------------------------------- | -------------------------- | ---------------------------------------------------------------- |
| `ApplyAndStoreCommand`                | `uRadioConfigApply`        | applies via `CheckCommand(…, True)` **and** records in the store |
| `TRadioConfigStore.Commands`          | `uRadioConfigStore`        | persists as the `commands` section of `settings\tr4w.json`       |
| `ApplyStoredCommands`                 | `uRadioConfigApply:307`    | applies every stored command at startup                          |
| `ApplyActiveProfileToConfigAtStartup` | called from `tr4w.dpr:971` | **the live startup hook**                                        |
| `crS = csJSON`                        | `uCFG:1415`                | the ini loader skips the row                                     |
| `crS = csJSON`                        | `uOption:362`              | Ctrl-J hides the row                                             |
| `CommandIsJSONOwned`                  | `uCFG:965`                 | the ini writer skips the row                                     |

`ApplyStoredCommands` is **generic** — it applies whatever is in the store, not just radio keys —
and `settings\tr4w.json` already carries 52 commands through it. So steps 1 and 2 of the rule are a
two-line change per setting:

* register the setting so its writes go through `ApplyAndStoreCommand` instead of
  `SetCFGCommandValue`;
* flip the CFGCA row to `csJSON`.

Both must land in the **same commit**. A row flipped without the writer moving loses the value on
restart; a writer moved without the flip leaves the ini as a second, stale source.

## Step 3: the config object, and the constraint that shapes it

`uConfigValues.pas` holds `TR4WConfig` — one record variable, `Config`, one field per migrated
setting. `Config.CodeSpeedIncrement` is the first.

**It is a record variable and not a class, and that is forced, not preferred.** `CFGCA` and
`ArrayRecordArray` are *const* arrays holding the **address** of each setting's storage, and
`CheckCommand` writes through that address. A compile-time initialiser can take
`@Config.CodeSpeedIncrement`, whose offset is known at link time; it cannot take the address of a
field of an object that does not exist until run time. The pre-existing `@CD.CountryString` row is
the same construction and has always compiled, which is what established the technique before
anything was moved.

So while `CheckCommand` remains the applier, the storage must be statically addressable. Replacing
`CheckCommand` is the step that finally removes the address-taking — and it cannot happen until the
rows have moved, which is why this order.

**`Config` is itself one global, and that is the point.** The thirty settings are today thirty
unrelated variables scattered across `LOGWIND`, `VC` and the TRDOS core, writable from anywhere,
with nothing marking them as configuration and no way to enumerate them. One named record makes
every call site say `Config.X` out loud and leaves one place to change later.

### Migrating the reads: the parameterless-function swap

Eliminating the global is where the cost is, and it varies by three orders of magnitude:

```
 3 refs  tDitDahRatio, AltDCQEnable, HamScoreSendContactInfo, HamScoreUsername
 …
30 refs  CWEnable
34 refs  TwoRadioMode
93 refs  CWTone
```

Rewriting 93 call sites to `FindSetting('cw.tone')…` would churn the contest engine, turn a memory
read into a registry lookup, and put risk into code that currently works.

**Recommended instead — the parameterless-function swap.** In Pascal, replacing

```pascal
var CWTone: integer;                 // global
```

with

```pascal
function CWTone: integer; inline;    // reads the config object
```

leaves **every read compiling unchanged** — `if CWTone > 0` is still valid syntax — while **every
write becomes a compile error**. That is exactly the property wanted: the reads cost nothing to
migrate, and the compiler hands over the complete list of writers, which are the sites that must go
through a setter. The global is genuinely gone; no call site churns; nothing is missed.

Two things it does not survive, both of which the compiler also catches:

* `@CWTone` — the CFGCA row's `crAddress`. A migrated row is inert, but the table must still
  compile, so the row needs its address changed or the row removed.
* `var`/`out` parameters taking the global.

## Order of work

1. ~~**Foundation** — `RegisterStoredSetting`, routing writes through `ApplyAndStoreCommand`, using
   the *form's* store so Cancel still discards.~~ **Done.** Plus the two things it turned out to
   need: `SeedMigratedCommandsFromIni` and `ApplyPeerCommand`.
2. ~~**The worked example** — `CW SPEED INCREMENT`, all five steps.~~ **Done**, pending NY4I's
   on-screen check.
3. **Per setting, one commit each** — registration swap, row flip, seed-list entry, `crNetwork`
   check, global into `Config`. Verify the key leaves Ctrl-J, stops appearing in `tr4w.ini`, and
   survives a restart via `tr4w.json`.
4. **The `csOwned` batch** — row flip only, in small themed commits.
5. **The expensive globals** (`CWTone` at 93, `Weight` at 34, `TwoRadioMode` at 34) — the function
   swap, once the cheap ones have proved the shape.

### A setting that reaches the EXPORT must not be `csJSON` (proved 2026-08-16)

The warning below was right and still got past us. `COMPUTER ID` was migrated to `csJSON`, and
`PostUnit.PAS:3021` compares it against each QSO's stored id to decide the Cabrillo **transmitter
digit**. Under `/EXPORT` the ini loader skips a `csJSON` row and the JSON apply never runs, so the
value fell back to its compiled default and **2632 QSO lines in the Winter Field Day set exported
wrongly**. The corpus caught it: 21/1/4 against a 22/0/4 baseline.

**The fix is `csOwned`, not a change to the export path.** `csOwned` hides the row from Ctrl-J — the
point of the migration — while `CheckCommand` still applies the ini value, so export behaves as it
always did.

Making `/EXPORT` apply the JSON store instead was tried and is **wrong**: it takes the operator's
*current* settings over the log's own `.cfg`, which is the opposite of what re-exporting an old log
should do. Measured, not argued — it took the corpus from 21/1/4 to **8/14/4**.

**So the rule: if a setting is read by `PostUnit`, `uCabrillo*`, `uADIF` or `uCbrSum`, it may become
`csOwned` but never `csJSON`.** Swept the other 70 `csJSON` rows against those units on 2026-08-16 —
none is read by an export unit, so `COMPUTER ID` was the only one.

### The corpus cannot see a migrated setting

`tr4w.dpr:971` skips `ApplyActiveProfileToConfigAtStartup` under `/EXPORT` — deliberately, so
automated testing never touches the operator's live settings. The consequence for this work:
**headless export runs on compiled defaults, so a migrated setting is invisible to the corpus.**

That is fine for the six migrated so far — none of them changes ADIF or Cabrillo output — but it
means a green corpus is *not* evidence for a setting that affects an exported field. Anything in
that class has to be checked another way, and the check has to be named in the commit rather than
implied by "22 passed".

### What NY4I should check on screen

The build is green, 3978/0, corpus 22/0/4 — but none of that can see a settings screen. Worth
eyeballing once:

* `CW SPEED INCREMENT` is **gone from Ctrl-J**;
* Preferences → CW shows **Speed step: 2** (not 3) on first start after this build, and
  `tr4w.log` carries `[SeedMigratedCommands] CW SPEED INCREMENT = 2 carried over from tr4w.ini`;
* changing it in Preferences and restarting keeps the new value, and `settings\tr4w.json` — not
  `tr4w.ini` — is what changed;
* the speed-up/slow-down keys still step by that amount on air.

## A path setting gets a picker (NY4I, 2026-08-15)

> *"These file and folder options should have a file and folder picker behind them."*

A standing rule for the rest of the migration, not a one-off request. Any row typed `ctDirectory` or
`ctFileName` gets a **Browse...** button beside its edit — `TSelectDirectoryDialog` for a folder,
`TOpenDialog` for a file — following `btnBrowseMMTTYClick`, which was already doing this.

All six path settings now in Preferences comply: `BACKUP LOG FILE NAME`, `MMTTY ENGINE`, `DVK PATH`,
`DVK RECORDER`, `MP3 PATH`, `MP3 PLAYER`.

**Still to come, and each owes a picker when it lands:** `COUNTRY INFORMATION FILE`,
`UNKNOWN COUNTRY FILE NAME`, `DOMESTIC FILENAME` and `INITIAL EXCHANGE FILENAME` (the last two are
contest-scoped).

Two details worth keeping. The folder picker opens at `ExpandFileName` of the current value, because
the shipped defaults are RELATIVE (`DVK`, `MP3`) and expand against the program directory — opening
at the process working directory would send the operator somewhere the setting never meant. And the
DVK recorder filter offers `.dll` as well as `.exe`: NY4I's own station has `lame_enc.dll` in that
field, so an exe-only filter would hide the working answer.

## The Appearance menu folds into the Appearance page (NY4I, 2026-08-15)

**Correcting a misreading of mine.** I took an earlier remark to mean the Preferences Appearance
page was frozen, and stopped migrating to it. NY4I meant the **Appearance item on TR4W's own
Settings menu** — `RunOptionsDialog(cfAppearance)` (`MainUnit.pas:3749`), which is the Ctrl-J grid
filtered to one `cfFunc`.

> *"I did not mean to imply freeze the Appearance panel. I meant the items on the Appearance menu in
> the existing TR4W program. But I reconsidered. You can move these items to the Appearance tab and
> we can get rid of the old Appearance form in TR4W."*

So it is the opposite of blocked: it is a deliverable with an end state — **the menu item goes
away**.

The old form's nine rows:

| row                                                             | state                                                                                               |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `BOLD FONT`, `MAIN FONT`                                        | already migrated                                                                                    |
| `NO BORDER`, `NO CAPTION`, `NO COLUMN HEADER`, `SHOW GRIDLINES` | migrated 2026-08-15, "Main window" group                                                            |
| `ROW COUNT`, `WINDOW SIZE`                                      | **`ckArray`** — target is an `ArrayRecordArray` entry, not `crAddress`. Different move.             |
| `REMINDER`                                                      | **not a scalar setting** — Alt-O appends `REMINDER = …` lines (`HELP.PAS:855`); wants a list editor |

**The menu item cannot be removed until the last three land**, or it strips the only editor those
settings have.

### What is genuinely blocked, and why it is not the same thing

The grid painting itself, and colours.

Colours are stored as `tr4wColors` — a **16-value enum**, one per `TMainWindowElement`
(`TWindows[e].mweColor` / `.mweBackG`) — and edited through `uDialogs.SelectColor`, a hand-declared
wrapper over the Win32 `ChooseColorA` common dialog (`uDialogs.pas:165`, with its own
`TChooseColorA` record and API import). Under the LCL that becomes `TColorDialog` and the whole
hand-rolled block can go.

But a real picker returns RGB. Adopting one **widens the stored type**, and every consumer of
`tr4wColors` has to follow. That is a design step inside the LCL main-window work, not a settings
migration, and it should not be smuggled in as one.

**Not blocked despite reading like Appearance:** `DISTANCE MODE`, `RADIUS OF EARTH` and
`GRID MAP CENTER` are distance *arithmetic*, not painting. `INCLUDE F-KEY NUMBER` gates one string
prefix in `uFunctionKeys`, so it went to CW Settings where those messages are configured.

## Beyond the original 30 (2026-08-14)

The 30 above are done, **including item 5's "expensive globals"** — `CWTone`, `Weight` and
`TwoRadioMode` all reach `Config` and no standalone declaration survives. What follows is the work
after that list, and the method is the same two tests, applied before any code is touched:

1. **Does a contest `.cfg` claim it?** All 74 `.cfg` files under `target/` are scanned. This is not
   ceremony — it is how `LEADING ZEROS` was caught.
2. **Does anything else write the global?** Live assignments only. Half the apparent writers in
   `CFGDEF.PAS` are commented out and a naive grep reports them as real.

### The parallel-port wiring — station cabling, not radio settings

`RELAY CONTROL PORT`, `RADIO ONE/TWO BAND OUTPUT PORT`, `STEREO CONTROL PORT` → **Preferences >
Hardware**. NY4I placed the two band-output ports there deliberately, against his own "anything
addressing `Radio1`/`Radio2` goes on the radio form" rule, because what they name is which LPT pin
header drives the band decoder for an operating position. That follows the desk, not the radio.

**It was already a defect.** `BandOutputPort` was a field on `TRadioDefinition`, so activating a
radio re-rendered the CFG key and clearing a slot blanked it to `NONE` — any Hardware edit would
have been silently reverted by the next activation. The field is removed, and
`Test_BandOutputPortIsNotRadioScoped` pins both render paths including the empty slot.

**Before putting any setting on a station-level panel, check whether something else RENDERS its CFG
key.** `RenderedKeyNames` in `uRadioConfigLegacyMap` is the list.

### CW keying, paddle and PTT — ten settings, all category A

`ALL CW MESSAGES CHAINABLE`, `TUNE WITH DITS`, `SEND COMPLETE FOUR LETTER CALL`, `PADDLE SPEED`,
`PADDLE MONITOR TONE`, `SWAP PADDLES`, `PADDLE PTT HOLD COUNT`, `PTT ENABLE`, `PTT TURN ON DELAY`,
`NO POLL DURING PTT`. No contest names one; the config table was their only writer.

**Four were typed constants with non-zero values** (`PTTEnable = True`, `PTTTurnOnDelay = 15`,
`PaddleMonitorTone = 700`, `PaddlePTTHoldCount = 13`) and **a record field defaults to zero**. Losing
those means PTT disabled, a 0 Hz sidetone, and PTT dropping between characters — hot switching, on an
amplifier. Neither the compiler nor the corpus can see it (headless export skips the settings apply,
`tr4w.dpr:971`). `test/unit/uTestConfigDefaults.pas` pins every default and was proved to fail.

UI: three checkboxes on **CW Settings**, the other seven on a new **Paddle and PTT** page made a
*child* of it — collapsed by default, so the nav gains no height.

**Open, reported not fixed:** the two consumers of `PTT TURN ON DELAY` disagree about its unit.
`MainUnit.pas:9646` does `Sleep(Config.PTTTurnOnDelay)` — plain milliseconds — while `LOGK1EA` counts
it down in keyer ticks, which the help documents as × 1.7 ms. Both readings are live. Correcting
either changes amplifier sequencing on air, so it needs bench evidence.

**Held back:** `AUTO SEND CHARACTER COUNT` (`ckArray` via `pointer(2)` — a different mechanism).

### `CODE SPEED` does not belong in `Config` at all (NY4I, 2026-08-14)

> *"CodeSpeed is a global for all keyers to access."*

Stopped before the repoint on that instruction, and it is the right call for a reason worth writing
down: **`CodeSpeed` is not a setting that happens to be mutable — it is live shared runtime state.**
Every keyer reads it, the speed keys move it ±6% (`uCWKeyerCAT`), it is reloaded from
`RadioN.SpeedMemory` on every change of active radio, and `CW SPEED FROM DATABASE` sets it from the
station's last-worked speed.

`Config` holds what the operator configured. Pointing 151 keyer reads at `Config.CodeSpeed` would
work mechanically and would quietly redefine the config record as a place runtime state lives — the
same category error as putting the current frequency there.

**The distinction to keep:** `CODE SPEED` the *stored setting* is the speed a session STARTS at;
`CodeSpeed` the *global* is the speed it is at now. Those are two values, and today one variable does
both jobs. If the setting is wanted in Preferences, it wants its own stored field seeding the global
at startup — not a repoint. Left `csOld` until that is designed.

**A per-radio CW speed already exists**, which is worth knowing before anyone designs one.
`SetUpToSendOnRadioOne/Two` (`LogCW.pas:2142+`, tagged KK1L 6.73) does
`CodeSpeed := RadioN.SpeedMemory` on every change of active radio, and `LOGWIND.PAS:1587` writes the
live speed back with `ActiveRadioPtr.SpeedMemory := CodeSpeed`. So set 30 WPM on radio one and 22 on
radio two and each is restored as you switch. This is *not* SO2R-gated — it runs on any active-radio
change. What is missing is only that the two speeds are invisible: nothing displays or configures
them, and `CWSpeedSync` changes whether the speed is pushed to the rig.

**Pre-existing and unfixed:** `Radio1/2.SpeedMemory` default to `InitialCodeSpeed` (35,
`tree.pas:742`) independently of the configured `CODE SPEED`, so a station configured to 28 WPM jumps
to 35 on its first radio switch, self-correcting after one manual change. Worth settling when the
setting is.

### Still `csOld`, and mostly not Preferences work

178 rows remain. The bulk are **contest properties** — `QSO POINTS *`, the `* MULTIPLIER` family, the
CQ/S&P/QSL message set, `MULT BY BAND`, `DOMESTIC MULTIPLIER` — and belong with the contest factory,
not in a settings dialog. NY4I said he would identify those. What is left that is genuinely
station-scoped is a short list: the remaining LPT rows (blocked on the LPT decision), `CODE SPEED`,
and a handful of display and keyboard preferences.

## Where each of the 30 stands

`refs` counts live references to the backing global, excluding the dead `JCtrl1`/`JCTRL2` units and
the CFGCA table binding itself.

| key                                 | CFGCA command              | row        | backing global                      | refs                               |
| ----------------------------------- | -------------------------- | ---------- | ----------------------------------- | ---------------------------------- |
| operating.cw.serial.ditDahRatio     | DIT DAH RATIO              | **csJSON** | Config.tDitDahRatio                 | **migrated**                       |
| operating.tworadio.altDCQ           | ALT-D CQ ENABLE            | **csJSON** | Config.AltDCQEnable                 | **migrated**                       |
| scoring.hamscore.contactInfo        | HAMSCORE SEND CONTACT INFO | **csJSON** | Config.HamScoreSendContactInfo      | **migrated**                       |
| scoring.hamscore.username           | HAMSCORE USERNAME          | **csJSON** | Config.HamScoreUsername             | **migrated**                       |
| operating.cw.keypadMemories         | KEYPAD CW MEMORIES         | **csJSON** | Config.KeypadCWMemories             | **migrated**                       |
| operating.tworadio.blindCQ          | ALWAYS CALL BLIND CQ       | **csJSON** | Config.AlwaysCallBlindCQ            | **migrated**                       |
| scoring.board.postingUrl            | SCORE POSTING URL          | **csJSON** | Config.GetScoresSeverPostingAddress | **migrated**                       |
| scoring.board.readingUrl            | SCORE READING URL          | **csJSON** | Config.GetScoresSeverReadingAddress | **migrated**                       |
| scoring.hamscore.enable             | HAMSCORE ENABLE            | **csJSON** | Config.HamScoreEnable               | **migrated**                       |
| scoring.hamscore.password           | HAMSCORE PASSWORD          | **csJSON** | Config.HamScorePassword             | **migrated**                       |
| cluster.connectAtStartup            | CONNECTION AT STARTUP      | **csJSON** | Config.tConnectionAtStartup         | **migrated**                       |
| scoring.hamscore.url                | HAMSCORE URL               | **csJSON** | Config.HamScoreURL                  | **migrated**                       |
| cluster.connectCommand              | CONNECTION COMMAND         | csNew      | *(cluster definition)*              | **removed from the flat registry** |
| cw.speedFromDatabase                | CW SPEED FROM DATABASE     | **csJSON** | Config.CWSpeedFromDataBase          | **migrated**                       |
| operating.cw.leadingZeroChar        | LEADING ZERO CHARACTER     | **csJSON** | Config.LeadingZeroCharacter         | **migrated**                       |
| operating.tworadio.altDBuffer       | ALT-D BUFFER ENABLE        | **csJSON** | Config.AltDBufferEnable             | **migrated**                       |
| operating.cw.sayHiRateCutoff        | SAY HI RATE CUTOFF         | **csJSON** | Config.SayHiRateCutOff              | **migrated**                       |
| operating.cw.serial.farnsworth      | FARNSWORTH ENABLE          | **csJSON** | Config.FarnsworthEnable             | **migrated**                       |
| operating.tworadio.skipActiveBand   | SKIP ACTIVE BAND           | **csJSON** | Config.SkipActiveBand               | **migrated**                       |
| operating.bands.hf                  | HF BAND ENABLE             | csOld      | HFBandEnable                        | 8                                  |
| operating.cw.leadingZeros           | LEADING ZEROS              | **csJSON** | Config.LeadingZeros                 | **migrated**                       |
| **cw.speedIncrement**               | **CW SPEED INCREMENT**     | **csJSON** | **Config.CodeSpeedIncrement**       | **migrated**                       |
| operating.cw.sayHi                  | SAY HI ENABLE              | **csJSON** | Config.SayHiEnable                  | **migrated**                       |
| operating.bands.warc                | WARC BAND ENABLE           | csOld      | WARCBandsEnabled                    | 16                                 |
| operating.cw.serial.farnsworthSpeed | FARNSWORTH SPEED           | **csJSON** | Config.FarnsworthSpeed              | **migrated**                       |
| operating.bands.vhf                 | VHF BAND ENABLE            | csOld      | VHFBandsEnabled                     | 25                                 |
| operating.cw.serial.weight          | WEIGHT                     | **csJSON** | Config.Weight                       | **migrated**                       |
| cw.enable                           | CW ENABLE                  | **csJSON** | Config.CWEnable                     | **migrated**                       |
| operating.tworadio.enable           | TWO RADIO MODE             | **csJSON** | Config.TwoRadioMode                 | **migrated**                       |
| cw.tone                             | CW TONE                    | **csJSON** | Config.CWTone                       | **migrated**                       |

`refs` is a case-**insensitive** count over the compiled tree, `.PAS` and `.pas` alike, excluding the
uncompiled `JCTRL1`/`JCTRL2`. A case-sensitive `--include=*.pas` misses every TRDOS file spelled
`.PAS` and reports a fraction of the truth — it showed `CodeSpeedIncrement` as 5 when it is 14.
`Weight` is a generic word and its 34 will include unrelated identifiers; count it again before
believing it.

## The csOwned batch — ~~22 settings, already half-migrated~~ **21 DONE, 1 held back**

The **hand-wired** Preferences panels (SCP, network, fonts, backup, band map, WSJT-X, external
logger, MMTTY, …) already call `ApplyAndStoreCommand`, so 22 commands are already written to JSON.
All 22 rows are `csOwned`, which is a real state and not an oversight:

|           | hidden from Ctrl-J | applied from the ini | written to the ini |
| --------- | ------------------ | -------------------- | ------------------ |
| `csOwned` | yes                | **yes**              | yes                |
| `csJSON`  | yes                | no                   | no                 |

So `csOwned` satisfies step 1 but not step 2: the value is in both files and the ini is still a
second, staler source that the loader applies before `ApplyStoredCommands` overrides it. They are a
cheaper batch — the writer has already moved — but **not a blind sweep**: 45 of the 86 `csOwned`
rows are `crNetwork: 1`, so each one has to be checked against the peer path above, and each needs
its seed-list entry. Do them in small themed commits (backup, band map, WSJT-X …), not one change of
22.

**Done 2026-08-14.** Twenty-one flipped to `csJSON`, each added to the ini→store seed list so a
station that has never opened Preferences keeps its values: backup (2), band map (3), external
logger (3), fonts (2), MMTTY, SCP (2), server/network (4), radio TCP port, telnet, WSJT-X (2).

**`MY CONTINENT` was held back.** Two reasons were given; only one survives.

*Withdrawn:* "it belongs to the station-vs-contest question, not to a batch of UI-owned settings."
Per *Every parameter is a registry parameter*, that is not a reason to hold a row out of the
registry — it is a question about which panel edits it.

*Stands, and is the actual blocker:* **`MY CONTINENT` reaches the export.** With 71 references in
`LOGSTUFF.PAS` driving scoring, multipliers and DX/domestic decisions, it is squarely in the class
that *"A setting that reaches the EXPORT must not be `csJSON`"* below already governs — and that
section is not a warning, it is a measured result: `COMPUTER ID` went `csJSON`, and 2632 Winter
Field Day QSO lines exported wrongly.

So the answer for this row is already decided by that rule, and it is **not** "hold it back":

> **`MY CONTINENT` belongs at `csOwned`, never `csJSON` — and checking the code on 2026-08-16, it
> is already `csOwned`. Nothing to do.**

`csOwned` hides it from Ctrl-J — which is the point of the migration — while `CheckCommand` still
applies the ini value, so `/EXPORT` behaves exactly as it always did. The row moves out of the
operator's way without changing a single exported byte.

Do **not** reach for "make `/EXPORT` apply the store" — that was tried and measured wrong
(21/1/4 → 8/14/4), because re-exporting an old log must honour that log's own `.cfg`, not the
operator's current settings.

## What is left, and where each of it lands

NY4I asked to see "what is left and where it lands in either settings or some other location".
This is that answer for the 24 not yet migrated, decided by **who else writes the variable** —
scanned for live assignments only, because half the apparent writers in `CFGDEF.PAS` are
commented-out lines and a naive grep reports them as real.

### A. Nothing else writes them — migrate as flat settings (13, see A-bis)

The stored value is the only source, so these were pure Preferences settings and the cheapest work.
**All thirteen migrated 2026-08-14** (the fourteenth, `LEADING ZERO CHARACTER`, went with them; only
`LEADING ZEROS` is held back — see A-bis):

`DIT DAH RATIO`, `ALT-D CQ ENABLE`, `KEYPAD CW MEMORIES`, `ALWAYS CALL BLIND CQ`,
`SCORE POSTING URL`, `SCORE READING URL`, `CONNECTION AT STARTUP`, `CW SPEED FROM DATABASE`,
`ALT-D BUFFER ENABLE`, `SAY HI RATE CUTOFF`, `SKIP ACTIVE BAND`, `LEADING ZEROS`,
`LEADING ZERO CHARACTER`, `SAY HI ENABLE`.

(`LEADING ZERO CHARACTER` is assigned in `CFGDEF.PAS:487`, but `SetConfigurationDefaultValues`
runs **once** at startup and **before** the config files — it is an initial default, not a
competing owner. Checked rather than assumed, because a defaults procedure that ran on contest
change would silently reset the setting instead.)

### A-bis. `LEADING ZEROS` — **already `csJSON`**; only the write layer is open

Measured, not assumed: of the 30, **only `LEADING ZEROS` appears in a contest `.cfg`** — 6 of 137
scanned files, including `CQ-WPX-CW.CFG` and `CQ-WPX-SSB.CFG`, which fits a serial-number contest.
The other 29 appear in none.

**NY4I, 2026-08-16: "Move LEADING ZEROS from Contest and into the cfg registry."** It goes in like
everything else. No code writes it; a loaded contest does, and a `.cfg` winning while loaded is the
agreed semantics rather than a precedence bug.

What is *not* dissolved by that, and is the reason this row is still called out separately: the
**write path**. Editing it in Preferences during WPX must update either the station default or the
event override, and `CheckCommand` has no concept of layers — it writes one value to one place. So:

- **Storage: done.** Checked in the code rather than taken from this page — the row is already
  `csJSON` and already in `MIGRATED_COMMANDS`. This section previously read "held back"; it was
  stale.
- **Read:** already built, and built *for this row*. `ApplyStoredCommands` skips any command the
  loaded contest claimed — `CommandCameFromContestCFG` (`uRadioConfigApply.pas:584`) — so the
  contest wins while loaded and the stored value returns untouched the moment a contest that does
  not claim it is loaded. The comment there names `LEADING ZEROS` as the case that forced it.
- **Write:** the open decision. Until it is settled, an edit made while a contest that overrides the
  value is loaded is ambiguous, and the honest interim is to say which layer the editor is writing
  rather than let it look like it changed the value the contest is using.

This is the same station-default ← event-override shape as the `MY *` family, and the two should be
settled together rather than each inventing an answer.

### B. ~~Set by the contest~~ **MIGRATED 2026-08-16** (3)

`HF BAND ENABLE`, `WARC BAND ENABLE`, `VHF BAND ENABLE` are assigned by `FCONTEST.PAS` when a
contest is selected — `ARRLVHFJUN` sets `HFBandEnable := False` (`FCONTEST.PAS:634`), and there are
fourteen such sites.

**Superseded 2026-08-16.** The previous text called these "contest properties wearing a settings
costume" and proposed showing them read-only or not at all. Per *Every parameter is a registry
parameter*, being contest-set is not a reason to keep a row in the ini — these migrate like any
other. `FCONTEST` is simply one of the writers, and it writes through the same applier everything
else does.

Two things this makes explicit rather than leaving implicit:

- **The next contest selection overwriting an operator edit is the intended behaviour**, not the
  defect the old text feared. It is the same semantics already agreed for a contest `.cfg` winning
  while that contest is loaded. What it needs is *visibility* — the Bands panel should say the value
  came from the contest, in the same greyed-hint idiom agreed for the `MY *` family, so an edit that
  is about to be overwritten does not look permanent.
- **The editors already exist.** `layBands` binds all three to `operating.bands.hf|warc|vhf`
  (`uPrefsForm.pas:3356-3358`), so the UI half of this row group is done and the migration is the
  ordinary five-step flip plus a seed-list entry.

**Done 2026-08-16.** `RegisterLegacySetting` → `RegisterStoredSetting`, rows `csOld` → `csJSON`,
three seed-list entries (bound `0..98` → `0..101`). All three are `crNetwork: 1` and needed no
per-row peer work — `ApplyPeerCommand` routes on `CommandIsJSONOwned`. Checked against the export
rule first: none of the globals is read by `PostUnit`, `uCbrSum`, `uADIF` or `uCabrillo*`, so
`csJSON` rather than `csOwned`.

**A search trap worth recording**, because the first check returned a false clean: the globals are
spelled **inconsistently** — `HFBandEnable` but `VHFBandsEnabled` and `WARCBandsEnabled`. A sweep
that derives the identifier from the command name finds nothing for two of the three and reports
them safe. Read the row's `crAddress`; do not guess the global from the command.

Still owed (UI, not storage): the Bands panel should say the value came from the contest, in the
greyed-hint idiom agreed for the `MY *` family.

### C. ~~The session mutates them~~ **MIGRATED 2026-08-14** (5)

| setting             | live writer                                    | what changes it                      |
| ------------------- | ---------------------------------------------- | ------------------------------------ |
| `WEIGHT`            | `LOGK1EA.PAS:2120`                             | CW-buffer control codes, mid-message |
| `FARNSWORTH SPEED`  | `LOGK1EA.PAS:2125+`                            | same                                 |
| `FARNSWORTH ENABLE` | `LOGK1EA.PAS:2124`                             | same                                 |
| `CW ENABLE`         | `MainUnit.pas:2845`, `LogCW.pas:2289`          | live keystroke toggle                |
| `CW TONE`           | `MainUnit.pas:2766`, `uProcessCommand.pas:354` | live keystroke toggle                |

These can migrate, but the semantics have to be **stated rather than assumed**: Preferences sets the
value the session *starts* with, and a live change is not written back. Today that is also true and
nobody has said so. `CW TONE` at 93 references is the single most expensive item in the whole
exercise and should go last, with the function swap.

### D. ~~A library already owns it~~ **DONE — duplicate editor removed** (1)

`CONNECTION COMMAND`. `ApplyActiveCluster` assigns `ConnectionCommand` from the active cluster
definition (`uRadioConfigApply.pas:601`), and it runs **after** `ApplyStoredCommands`. So there are
two owners and the cluster wins.

**This is a live defect, not a future one:** editing "Connection command" in Preferences today writes
the ini, and the cluster library overwrites it on the next start. Migrating it to JSON would not fix
that — it would move the losing value to a different file. The fix is to drop `cluster.connectCommand`
from the flat registry and let the cluster editor own it, which is where the operator already expects
to find it.

### E. ~~Two commands feed one variable~~ **DONE — alias withdrawn** (1)

`TWO RADIO MODE` also receives the deprecated `SINGLE RADIO MODE` alias (`uCFG.pas:1359`, inverted).
Migrating one row without the other leaves the alias writing the ini into a variable the JSON store
also claims. Retire the alias in the same commit.

## The `MY *` family is not a station setting (NY4I, 2026-08-14)

There is a **line** between the MY... fields in Station settings and the MY info a
contest uses. Home state Florida, but operating a contest from Georgia: the state
*sent* comes from the contest setup, while the Cabrillo header still carries the
operator's real details. In NAQP people send a short made-up name — `JO` rather
than `Joseph` — purely because it is faster to key.

So three values, not one:

|                        | value                                        |
| ---------------------- | -------------------------------------------- |
| station identity       | the operator's own details                   |
| what the contest sends | set at contest setup; legitimately different |
| the Cabrillo header    | the real details again, not the exchange     |

The header is already structurally separate: `uCbrSum.pas` marks the address tags
`ctrCFG: False` / `ctrSave: True`, so it keeps its own storage rather than reading
the exchange globals.

**The rule** is *what did the contest setup ask for* — the contest value when the
setup collected one, the station value otherwise, with the station value shown as
**greyed hint text rather than pre-filled**, so blank reads as "use my default"
instead of as an omission. Same idiom the radio editor uses for the CI-V default.

**Deferred to the contest factory**, deliberately. The consequence here and now is
that `MY CONTINENT` was excluded from the `csOwned` batch: 71 references in
`LOGSTUFF.PAS`, and `/EXPORT` skips the JSON apply, so a row flip could silently
change an exported log for anyone who had overridden it.

The read side already exists — a contest `.cfg` naming a migrated command applies
it and wins while that contest is loaded. What is missing is the UI half.

## The function-key messages belong to the CONTEST, not to the settings store (NY4I, 2026-08-19)

While the Program message editor was being converted, NY4I: *"It occurs to me
that these items would go into the contest.sqlite since they are related to the
contest -- just to keep that in mind. But fixing this so the CFG works for now is
good."*

Recording it because it settles a question this plan does not otherwise answer,
and because the answer is **not** "another key in tr4w.json".

**Where they live today.** `CQ CW MEMORY F1..F12`, their `... CAPTION` twins, and
the exchange and other-message banks are written to the **contest `.cfg`**
(`TR4W_CFG_FILENAME`, `[Messages]` section) by the Program message editor, and
read back through `CheckCommand`. They are *not* in `tr4w.json` -- checked,
2026-08-19: that file has no `MEMORY` key at all.

**Why that is right rather than an oversight.** A CQ message contains the
contest's exchange. It is not a station preference that should follow the
operator between contests, which is what `tr4w.json` is for. The same argument
this plan already makes for the `MY *` family -- station identity is not contest
configuration -- runs the other way here: contest configuration is not station
identity.

**Where they are going.** The contest database, alongside the log, when log
storage moves to SQLite. Not `tr4w.json`, and not a fourth store invented for
them.

**What that means for work done now.** Nothing is blocked. The `.cfg` write is a
legitimate target under the "nothing uses the ini" rule (`c823c055` classified
every remaining `WritePrivateProfileString` call site, and this is one of the
contest-config ones). Fixing it in place is correct; it simply should not grow a
JSON mirror on the way past.

## What does not belong in Preferences

Not every CFGCA row is a *setting*. Some are per-contest state, some are commands rather than
configuration. Sorting those is the last step, once the genuine settings have moved and what remains
is visible.

**Read that as a question about the UI only.** Since 2026-08-16 it is not a question about storage:
a row that turns out to be per-contest state or a command still lives in the registry, and "this
does not belong on a Preferences panel" is never a reason to leave it in `tr4w.ini`. The three
possible answers are *which panel*, *read-only or editable*, and *set by whom* — not *whether it
migrates*.

## What the 2026-08-16 principle adds to the order of work

These follow the numbered list under [Order of work](#order-of-work); they do not replace it, and
they inherit its rules — in particular *"a setting that reaches the EXPORT must not be `csJSON`"*,
which decides the storage class for several of them.

1. **Settle the write-layer question** — station default vs event override — once, for
   `LEADING ZEROS` and the `MY *` family together. The read side already exists
   (`CommandCameFromContestCFG`, `uRadioConfigApply.pas:584`); only the write side is undecided.
   This is the one genuine design blocker the principle did *not* dissolve.
2. ~~**Migrate category B**~~ **Done 2026-08-16** — the three band-enable rows are `csJSON` and
   seeded. The greyed "the contest set this" hint on `layBands` is still owed.
3. ~~**`MY CONTINENT` → `csOwned`**~~ **Already there** — verified in the code, not assumed.
4. **Build the Contest panel.** `NAV_CONTEST = 10` has a nav item and no panel, and it is where
   contest-set parameters are shown until the contest factory takes them.
5. **The secret store**, per the decision above, before this work is called finished — starting with
   the serialiser test, which is cheap and guards the claim everything else rests on.
