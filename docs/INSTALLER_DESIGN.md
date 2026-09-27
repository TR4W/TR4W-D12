# The installer, and what it is allowed to decide

**Status:** DESIGN ONLY. No installer code is written. The `.pkg` is agreed in
principle (NY4I, 2026-09-27) and **the certificate is no longer a blocker** --
see 9.1. Every numbered decision below is either stated as decided or explicitly
owed from him.

**Read `docs/SETUP_WIZARD_DESIGN.md` first.** This document is its outer layer
and is deliberately written to not overlap it. The wizard document was reviewed
against `docs/Critique of Wizard Design Plan.md`, and the single most important
line it took from that review -- *the wizard must not redeclare a field* -- is
the line this document applies one layer further out.

---

## 1. The split this document exists to record

**The installer decides about the MACHINE and the PAYLOAD. The setup wizard
decides about the STATION.**

| question | who owns it | why it cannot be the other one |
|---|---|---|
| is there room on this volume | installer | asked before any byte is written; the app does not exist yet |
| which optional components get laid down | installer | it IS the act of laying them down |
| where the program goes | installer | the app cannot move the files it is running from |
| callsign, grid, zones, sections | **setup wizard** | derived from CTY.DAT, which the app owns and the installer has no reason to parse |
| radio, keyer, cluster, rotator | **setup wizard** | hardware is absent at install time as often as not |
| which contest, which exchange | **setup wizard** | per-contest, and the wizard does not ask it either |

The handoff is one sentence: **the installer finishes, the app launches, the
setup wizard runs.** Nothing is passed between them but files on disk.

### 1.1 THE PROHIBITION -- the installer must not redeclare a field the wizard owns

`SETUP_WIZARD_DESIGN.md` section 3.1 says the wizard must not grow its own copy
of a setting the stores already own, and gives the reason: a settings value with
two owners is one where a fix lands in one and not the other. September was
spent unwinding exactly that
(`docs/migration_interim_artifacts/CFG_ARRAY_ELIMINATION.md`).

**An installer is a third owner, and the worst of the three**, because it writes
once, before anything can validate what it wrote, from a process that has no
access to the settings model at all. Concretely, the installer must not:

- write `settings/tr4w.json`, or any key in it;
- write a contest `.cfg`;
- write `settings/tr4w.ini` -- that file is `tr4wconvert`'s INPUT and startup has
  not read it since 2026-09-19;
- ask for anything on the wizard's Station page, in any spelling;
- pre-create a radio, keyer, cluster or rotator definition.

**The failure mode is not that the installer's answer is wrong. It is that the
answer has no owner.** A callsign typed into an installer text box is validated
by nothing (`IsAGoodCall` lives in the app), normalised by nothing, and derives
nothing -- and the wizard, finding the field already populated, either re-asks it
(the duplicate-`MY GRID` defect of 2026-09-11 -- the surviving prompt is at
`uProgramMain.pas:2490-2527`) or trusts it.

**The one thing the installer may legitimately write outside its own payload is
a shortcut**, which is a property of the machine.

---

## 2. Why a `.pkg` at all

NY4I, 2026-09-27:

> *"i still want the pkg route as checking on disk space, asxking if we want to
> install the debug files, specifying a language, etc are all things I may want
> to do in the install. That can then roll into the basic information such as
> their Grid"*

Three of those four are in scope and one is not. Taking them in the order of how
well they justify the work:

| he asked for | verdict | section |
|---|---|---|
| ask whether to install the debug files | **yes, installer. This alone justifies the `.pkg`** | [4](#4-decision-1----optional-debug-symbols----installer) |
| check disk space | **no -- withdrawn by NY4I; the number is automatic anyway** | [5](#5-decision-2----disk-space----installer-and-automatic) |
| specify a language | **recommended: setup wizard, not installer** | [6](#6-decision-3----language----recommended-setup-wizard) |
| "roll into the basic information such as their Grid" | **no -- that is the wizard, and it already exists as a design** | [1.1](#11-the-prohibition----the-installer-must-not-redeclare-a-field-the-wizard-owns) |

The last row is the one worth being explicit about, because it is the natural
reading of his sentence and it is the thing that would rot. A `.pkg` CAN show a
custom pane and ask for a grid square. It should not, for the reason in 1.1, and
because the wizard's Station page derives nine of its ten fields from the
callsign through CTY.DAT (`uCFG.pas:2521`, `fcontest.pas:1843`) -- an installer
asking for a grid gets one field and no derivation.

**`.dmg` versus `.pkg` is not the same question as drag-install versus
scripted-install.** What a `.pkg` buys is a CHOICE UI and a payload the system
installs, and TR4W's case for one rests on having something real to choose. It
does, and it is 63 MB of it.

---

## 3. The measurements

Everything below was measured on 2026-09-27, with the command named. Nothing
here is an estimate.

### 3.1 What is installed today, per platform

| platform | artifact on disk | installed footprint | how measured |
|---|---|---|---|
| Windows | `tr4w_setup_5.0.11.exe`, 33,900,683 B | **128,251,564 B (122 MB)** | `7z x` the installer, then sum every extracted file |
| macOS | `tr4w-5.0.23-aarch64-darwin.dmg`, 26,116,929 B | **54,931,456 B (52 MB)** | `du -sk TR4W.app` on the staged bundle, mac-ci |
| macOS | `...tar.gz`, 21,688,093 B | same bundle | as above |
| Linux | `tr4w-5.0.23-x86_64-linux.tar.gz`, 32,785,456 B | **113,210,201 B (108 MB)** | `du -sb` the staged tree, linux-ci-build |
| Linux | `TR4W-5.0.23-x86_64.AppImage`, 31,926,776 B | mounted, not installed | `stat -c%s` |

The v5.0.11 installer is the newest one on this machine; v5.0.23's is
34,929,356 B and its `tr4w.dbg` is 70,468,851 B against 5.0.11's 70,190,410, so
the proportions below are current.

### 3.2 The symbols, which is what the checkbox is about

| platform | symbol payload | bytes | share of the install | separable today? |
|---|---|---|---|---|
| Windows | `tr4w.dbg` | 70,190,410 (**67 MB**) | **54.7%** | **yes** -- `-Xg` already writes it beside the exe |
| macOS | a `.dSYM` bundle | 66,105,344 (**63 MB**) | would be 55% | **not produced today** -- see 4.2 |
| Linux | none separable | -- | -- | **no** -- DWARF is inside the binary |

**Windows: more than half of what TR4W installs today is debug symbols.** That
is the whole argument in one number. `58,061,154 B (55 MB)` is what an install
without them costs -- measured by subtracting `tr4w.dbg` from the extracted
total.

**macOS: 66,105,344 B, and that is measured, not projected.** `dsymutil` was run
against the real v5.0.23 Darwin binary on mac-ci in a scratch directory; it took
2.8 seconds and produced `tr4w.dSYM` of which 58,646,354 B is the DWARF itself.
Nothing was added to the tree.

**Linux has no separable symbol file at all**, and the 108 MB above is why: the
staged `tr4w` binary is 64,674,296 B because `-gl` puts the DWARF INSIDE it.
`build-unix.sh` records the reason `-Xg` was not carried over -- it needs
`objcopy`, a binutils dependency the script declined to require. So "install the
debug files?" is a question Linux cannot currently be asked, and
[section 8](#8-parity-and-the-linux-gap-stated-plainly) says so plainly rather
than implying otherwise.

---

## 4. DECISION 1 -- optional debug symbols -- INSTALLER

**Decided. This is the strongest justification for a `.pkg`, and it retires a
pending decision rather than adding a feature.**

### 4.1 What it replaces

`tr4w/build/full.nsi` ships `tr4w.dbg` at `:134` inside `Section "tr4w.exe"
secexe` (`:116`), which is `SectionIn RO` -- not optional, not visible on the
components page. The comment above it is a standing IOU:

> *"SYMBOLS, WHILE WE ARE ON BENCH TESTERS (NY4I, 2026-08-16) ... A public
> release should be built with -ExcludeSymbols and ship without it"*

That is a decision deferred to release day, and release-day decisions are the
ones that get forgotten. **A checkbox retires it permanently**: the operator who
can send a useful crash report keeps the symbols, everyone else saves 67 MB, and
nobody has to remember a switch when beta ends.

Windows already has the mechanism. `full.nsi:94` is `Page components`, `:95` is
`Page directory`, and there is already one live `Section /o` to copy (`:284`;
a second at `:258` is commented out). Moving the `.dbg` out of
`secexe` into its own optional section is a small, local change -- but it is
still a change, and it is not made here because this document is a design.

### 4.2 macOS, and the honest state of it

**Today a macOS crash report cannot name a file and a line, and the
`-gw2` comment in `build-unix.sh` is wrong about that.** Measured 2026-09-27:
the shipped `TR4W.app` binary has **no `__DWARF` segment**, and neither does the
binary as the compiler left it in `build-out/app-aarch64-darwin/`. Nothing in
packaging removed it -- `ld64` never puts it there. It leaves the DWARF in the
`.o` files and writes a debug map into the symbol table (679 `N_OSO` entries,
counted with `nm -ap`), and those `.o` files do not ship.

`dsymutil` is what follows that map, and it works -- 2.8 seconds, 66,105,344 B.

### 4.2.1 CORRECTION: A `.dSYM` DOES NOT MAKE AN FPC 3.2.2 BACKTRACE RESOLVE

**The first version of this section said it did, citing
`rtl/inc/exeinfo.pp:1735` -- which opens
`<exe>.dSYM/Contents/Resources/DWARF/<exe>` and matches by UUID -- and concluded
that a `.dSYM` in the bundle "is read by the FPC runtime with no code change at
all". THAT IS FALSE, and it was tested rather than argued on 2026-09-27.**

**The mistake was reading the wrong file.** `exeinfo.pp:1735` is in an FPC
**main** checkout that happens to sit on mac-ci (`~/fpc_main`). It is not the RTL
this build uses. The installed FPC 3.2.2 source
(`~/fpcupdeluxe/fpcsrc/rtl/inc/exeinfo.pp`) contains **zero** occurrences of
`dSYM`, and registers ONE reader for every Darwin target:

```pascal
{$ifdef darwin}
   openproc : @OpenMachO32PPC;
   findproc : @FindSectionMachO32PPC;
{$endif darwin}
```

A **32-bit PowerPC** Mach-O reader, on aarch64. `OpenMachO32PPC` does not check
the magic -- it reads a 28-byte header and returns `true` unconditionally -- and
`FindSectionMachO32PPC` answers for `'.stab'` and `'.stabstr'` **and nothing
else**. A request for `.debug_line` can therefore never be satisfied on Darwin
under 3.2.2. It does not fail loudly; it silently finds nothing.

**Measured, four ways:**

| probe, built with `build-unix.sh`'s own Darwin flags | backtrace |
|---|---|
| `-gl -gw2`, no `.dSYM` | `$0000000102004738` -- bare |
| `-gl -gw2`, **matching `.dSYM` beside the binary** | `$0000000100E04738` -- **still bare** |
| `-gl -gs` (stabs instead) | bare |
| **the same probe, same flags, on Linux** | `$0000000000401094  INNERMOST,  line 20 of dwarfprobe.lpr` |

The Linux row is the control: the probe and `BackTraceStrFunc` are fine, and
Darwin is the difference.

**So the `.dSYM` must NOT be shipped inside the bundle.** It would add 66 MB --
roughly doubling `TR4W.app` -- to put a file on the operator's disk that the
runtime cannot read. Windows' 67 MB is a different bargain because the Windows
RTL *does* read `tr4w.dbg`.

### 4.2.2 What DOES work, and it is already half built

**Offline symbolisation, by us, with `atos`.** Proven the same day against the
real `.dSYM`:

```
atos -o tr4w.dSYM/Contents/Resources/DWARF/tr4w -arch arm64      -l 0x100000000 0x100000730
-> P$DWARFPROBE_$$_INNERMOST (in dwarfprobe) (dwarfprobe.lpr:20)
```

**And the crash log already carries what that needs.** `uCrashLog`'s
`ReportImageBase` logs the image path, the base, the dyld slide
(`_dyld_get_image_vmaddr_slide`) and a **ready-made command line**:

```
[CRASH] image <path> base $... slide $... -- resolve a frame with:
        atos -o "<path>" -l 0x<base> <address>
```

That was added because a logged frame sat above the top of the un-slid image, and
it is exactly the missing half of offline symbolisation. The ASLR problem is real
and visible in the table above -- the same probe printed `$102004738` and
`$100E04736` on two runs -- which is why the base must be logged and is.

**So the recommended shape is the Windows shape, not the bundle:** produce the
`.dSYM` at build time and **keep it beside the release**, the way `tr4w.dbg` is
kept and now attached as a release asset. `TR4W.app` does not grow, the operator
downloads nothing extra, and a crash report becomes resolvable by whoever has the
matching `.dSYM`. **This is a recommendation and not a decision -- NY4I approved
"ship it in the bundle", on the premise this section originally stated, and that
premise was wrong.**

**The other route is an RTL fix**, and it exists: FPC main has a 64-bit Mach-O
reader and the `.dSYM`-by-UUID lookup. Moving the Darwin toolchain to it, or
carrying a local `exeinfo.pp`/`lnfodwrf.pp`, would make in-process backtraces
resolve on macOS the way they already do on Linux -- and only then does shipping
a `.dSYM` in the bundle buy anything.

**The gate is already correct for either outcome.**
`tr4w/build/check-symbols.sh` validates a `.dSYM` and its UUID match when one is
present, and does **not require** one -- requiring it would fail every macOS
build over a file that cannot help.

### 4.3 What happens to `-ExcludeSymbols`

**It survives, as the CI default-setter, not as a release-day chore.**

`FullBuild.ps1:41` declares it and nothing passes it -- not `release.yml`, not
any script (checked by grep over the whole tree). So `/DINCLUDE_SYMBOLS` is
always on and the `.dbg` is provably in every installer: NSIS `File` fails the
build when the file is absent, and `7z l` on a built installer lists
`tr4w.dbg` beside `tr4w.exe`.

Once the operator chooses at install time, the switch's job changes from
*"whether TR4W ships symbols"* to *"whether this BUILD carries the optional
component at all"*, which is the right question for a build flag to answer. A
debug or experimental build can still drop 67 MB by passing it; a release build
does not, and the operator decides.

### 4.4 And the symbols are on the release page regardless

Since 2026-09-27 `tr4w-<version>.dbg` is attached to every GitHub release as an
asset of its own. That is deliberately independent of the installer choice: the
case it serves is a tester emailing a log that SOMEBODY ELSE symbolises, on a
machine that has the log and not the installer. An operator who declines the
component at install time is therefore not cut off from support -- the file is
one download away, and it is named with the version because a `.dbg` resolves
addresses for exactly one binary.

---

## 5. DECISION 2 -- disk space -- NOT A DESIGN CONCERN (NY4I, 2026-09-27)

**RULED OUT AS A REQUIREMENT.** NY4I named disk space as one of the things he
might want the installer to do, and then, once the rest was measured, withdrew
it: *"the disk space is not a factor"*. It is recorded here rather than deleted
because the sentence that raised it is quoted at the top of this document, and a
reader who finds it there and nothing here would reasonably conclude it was
forgotten.

**Nothing is owed either way**, which is what makes the withdrawal free: the
number is produced by building a `.pkg` at all. The rest of this section records
that measurement, because it is the answer to "do we need to state a size
somewhere" and the answer is no.

**Decided, and it turns out to cost nothing to implement, which is worth
knowing before anyone hand-writes a size constant.**

Probed on mac-ci 2026-09-27 by building a throwaway package from the real
v5.0.23 `TR4W.app` and expanding it (`/tmp` only, removed afterwards):

```
pkgbuild --identifier net.tr4w.app --version 5.0.23 \
         --root root --install-location / app.pkg
pkgutil --expand app.pkg exp
```

`exp/PackageInfo` contains, written by `pkgbuild` itself:

```xml
<payload numberOfFiles="162" installKBytes="53241"/>
```

**`installKBytes` is computed from the payload, per component.** Installer.app
uses it for the space requirement and for refusing a volume that cannot hold it.
So the disk-space check NY4I asked for is a property of building a `.pkg`
correctly, not a feature to add -- and, more to the point, **there is no
hand-maintained number to go stale**, which is the failure this tree documents
over and over. 53,241 KB against the 54,931,456 B `du` reported for the same
bundle is the block-overhead difference, not a discrepancy.

**An optional-component `.pkg` gets this per component**, which is exactly what
the symbols decision needs: the pane can state what the install costs with and
without the 63 MB because each sub-package carries its own figure.

**One thing deliberately NOT asserted here.** `<volume-check>` and
`<installation-check>` in the distribution XML are the hooks for other
preconditions -- a minimum macOS version, for instance -- and they are **not**
what the space check runs through. The synthesized distribution
(`productbuild --synthesize`) contains neither, and it does not need to. Before
writing either, generate one and read it; do not copy an element name out of
this document.

---

## 6. DECISION 3 -- language -- RECOMMENDED: SETUP WIZARD

**This is a decision for NY4I. The recommendation is the wizard, and here is the
argument rather than the assertion.**

### 6.1 The measurement that decides it

`src/ui/lcl/uEmbeddedTranslations.pas` -- NY4I chose this shape on 2026-08-26 --
compiles every `.po` into `res/tr4w_languages.res` as RCDATA and reads it back
at startup. Its own header states the size: **5.0 MB for twenty-two languages,
reviewed and unreviewed alike, inside the binary.**

**So there is no per-language payload.** Every language ships in every binary on
every platform. An install-time language question therefore selects nothing, lays
down nothing, and saves nothing -- which is the exact opposite of the symbols
question, where the answer is 67 MB.

What it would do instead is write a SETTING. `Settings.Display.Language`
(`uSettingsModel.pas:3226`) is a published property whose value is a catalogue
code, and `uTR4WConfigFile.StartupUILanguage` reads it **straight from
`tr4w.json`** before the first form streams (`uProgramMain.pas:1551`). So an
installer answering it has to create or edit `tr4w.json` before the app has ever
run -- which is precisely the prohibition in [1.1](#11-the-prohibition----the-installer-must-not-redeclare-a-field-the-wizard-owns),
and it collides with `uProgramMain.pas:1938` writing that file itself at startup
when it is absent.

### 6.2 Three more reasons, in decreasing order of force

**One answer versus three.** An installer answer has to be written three times
-- NSIS, the `.pkg` distribution, and **nothing at all** for the Linux tarball
and AppImage, which have no installer to ask. A wizard answer is one
implementation that covers all three platforms, and the wizard is already
designed and already has i18n rules written for it
(`SETUP_WIZARD_DESIGN.md` section 8).

**The default is already the macOS convention.** An empty
`Settings.Display.Language` means *follow the operating system*, stated in
`uSettingsModel.pas:3205`. macOS apps are expected to do that, and a `.pkg` pane
asking a Mac user to pick a UI language reads as a port of a Windows habit --
which is what it would be.

**The vocabulary is derived, not typed.** The list of offerable languages is
registered by `uEmbeddedTranslations` from the catalogues the binary actually
carries, *"so a hand-typed list cannot drift from what is loadable"*. An
installer cannot read that registration. It would need its own list, and that
list would be wrong the first time a catalogue is added or removed.

### 6.3 If NY4I chooses the installer anyway

Then the constraint is absolute and it is the same one either way: **the value
is written THROUGH the settings model, never into a store the installer
invents.** In practice that means the installer records the choice somewhere
inert -- a component selection, or a single file the app consumes once and
deletes -- and the APP writes `Settings.Display.Language`. Two stores for one
setting is the thing this whole document is about.

**A cheaper middle path, if the concern is really the first-run experience:** the
wizard's first page can offer the language, with the OS default preselected. That
is one page earlier than Station and still inside the one implementation.

---

## 7. DECISION 4 -- downloading CTY.DAT, TRMASTER.DTA, POTA parks -- ARGUE AGAINST

NY4I, 2026-09-27:

> *"We could also consider downloading the cty.dat, trmaster.dta, etc."*

**The recommendation is no, and the better shape already exists in the app.**

### 7.1 The app already does this, including the case the installer cannot handle

`uProgramMain.pas:602-620`: when TR4W cannot load a country file it **downloads
one**, to `DownloadedDataFilePath('CTY.DAT')`, and if that fails it says why --
naming the reason rather than guessing, because the one time anybody hit it the
real cause (a missing OpenSSL pair) was in the log and the advice on screen was
about network permissions. Alt-O does the same on demand, the Help menu does
TRMASTER.DTA (`MainUnit.pas:4849`) and the POTA park list (`uPOTAParks.pas:279`).

**So an installer that downloaded would be a second implementation of something
that works, and it would be the weaker one.** At install time there may be no
network; the app can ask again at every start, and does.

### 7.2 The rule it would have to copy, and copies drift

The resolution order is **downloaded -> contest directory -> shipped**, in
`FCONTEST.SetUpFileNames` (`fcontest.pas:196-220`), and it logs which tier
answered:

```
[FCONTEST] Country file: <path> (<tier>)
```

The writable tier is `uAppPaths.DownloadedDataDir`, and its definition is
platform-specific for three different reasons -- the settings directory on
Windows, `~/Library/Application Support/TR4W` on macOS, `$XDG_CONFIG_HOME/tr4w`
on Linux. **An installer downloading a country file would have to re-derive that
path itself**, in NSIS and in a `.pkg` script, from outside the program. That is
the same rule in three places, and this tree's standing finding is that copies
drift and the drift is invisible.

Worse, it would be writing into a directory the app owns, before the app has
established it.

### 7.3 Why the current shape is safe, and must stay that way

Two properties hold it together and an installer download endangers both:

- **The installer still ships the shipped tier.** `full.nsi` lays down
  `target/cty.dat` and `target/TRMASTER.DTA`, so a machine with no network has a
  working country file from the first launch. That is the floor, and it is why
  the download is an improvement rather than a prerequisite.
- **`--settings <path>` moves the writable directory with it**
  (`uAppPaths.pas:702-717`), which is what keeps the golden corpus
  deterministic: the corpus points TR4W at its own tracked fixture, which holds
  no country file, so the lookup falls through to the tracked shipped copy no
  matter what the developer has downloaded.

### 7.4 The better shape

**A wizard page offering "fetch current data now", calling the app's existing
download code.** It inherits the tier rule, the writable path, the failure
reporting and the `--settings` behaviour for free, because it is the same code.
It can be declined and retried. And it is one implementation for three
platforms, the same argument as the language decision.

Per `SETUP_WIZARD_DESIGN.md`'s own rule this is a new page and therefore a change
to a settled page shape, so it is **NY4I's decision, not a document edit** -- and
it is the one addition to that document this one proposes.

### 7.5 If he still wants it in the installer

What it costs, stated so the choice is informed:

| cost | detail |
|---|---|
| a second copy of the writable-path rule | in NSIS script, and again in a `.pkg` postinstall script |
| no-network handling, twice | the app's path already has it; the installer's would need its own |
| the installer writes into the app's data directory | before the app has created or validated it |
| a `.pkg` postinstall script runs as root | so a file lands with root ownership in a per-user directory unless the script is careful |
| notarization surface grows | a script in the package is more to sign, and more to explain |
| Linux gets nothing | there is no installer to put it in |

---

## 8. Parity, and the Linux gap stated plainly

**Whatever the `.pkg` gains, Windows gains, or the two platforms drift.** That is
not symmetry for its own sake: an operator-visible choice that exists on one
platform and not the other is a support answer that has to start by asking which
platform, and a release note that is wrong half the time.

| capability | Windows NSIS | macOS `.pkg` (proposed) | Linux tarball / AppImage |
|---|---|---|---|
| choose install location | `Page directory` (`full.nsi:95`) | destination select | **n/a** -- unpack where you like |
| optional components page | `Page components` (`full.nsi:94`) | `choices-outline` with `customize="always"` | **none** |
| optional debug symbols | **needs one change**: move `tr4w.dbg` out of `SectionIn RO` | needs a `dsymutil` stage first (4.2) | **impossible today** -- DWARF is inside the binary |
| disk space check | NSIS reports it | automatic, `installKBytes` (5) | **none** |
| language choice | recommended: not here (6) | recommended: not here (6) | **could not have it anyway** |

**Linux has no installer and this document does not pretend otherwise.** What a
Linux operator gets instead: a tarball to unpack, or an AppImage to mark
executable and run, with the prerequisites and the hard glibc floor documented in
`docs/INSTALL_LINUX.md`. They get the symbols whether they want them or not --
64,674,296 B of the binary is why -- and they get no choice pane. **If the
symbols checkbox matters enough on two platforms, the Linux answer is `-Xg` plus
`objcopy` and a second artifact, which is its own piece of work and is not
proposed here.**

---

## 9. The certificate, the build recipe, and shipping alongside

### 9.1 The certificate -- SORTED, and what was verified

**A `.pkg` is signed with a Developer ID *Installer* certificate, which is a
DIFFERENT certificate from the Developer ID *Application* one that already signs
the app and the `.dmg`.** When this document was first written mac-ci had only
the Application certificate and `macstudio` had none. **NY4I created the
Installer certificate on 2026-09-27**, and mac-ci's System keychain now holds
both -- confirmed non-interactively over ssh, which is the runner's own context:

| query | result | why it is the query that matters |
|---|---|---|
| `security find-identity -v` | **2** identities, 2 distinct fingerprints | the Installer certificate is present and usable unprompted |
| `security find-identity -v -p codesigning` | **exactly 1** (the Application cert) | so `mac-sign.sh`'s ambiguity check is provably unaffected |

**That second row is the one to keep.** An Installer certificate is not a
codesigning identity, so it does not appear in the `-p codesigning` list at all
and cannot collide with the app signing that already works. A `.pkg` check has to
query `-v` and filter by name -- and count **distinct fingerprints**, per 9.2.

The certificate stays in mac-ci's keychain, per the rule below. It was created
there, so no private key has ever moved.

**It stays in mac-ci's keychain and never becomes a repository secret**, for the
reason `release.yml` already records for the Application certificate: a
certificate exported into a secret is a signing key every workflow run can use
and that cannot be revoked without reissuing. Keeping it on the machine means
the worst a bad workflow can do is ask THAT machine to sign. The repo secrets
stay the notary API key only.

### 9.2 The build recipe

Verified against `man pkgbuild` and `man productbuild` on mac-ci, 2026-09-27,
and by building a throwaway package from the real v5.0.23 bundle.

```
pkgbuild  --identifier net.tr4w.app --version <version> \
          --component <staged>/TR4W.app --install-location /Applications \
          tr4w-app.pkg

productbuild --distribution Distribution.xml --package-path . \
             --sign "Developer ID Installer: ..." \
             tr4w-<version>-aarch64.pkg
```

Facts worth keeping, each from the man page rather than from habit:

- **Sign the PRODUCT, not the component.** `man pkgbuild`: *"if you are going to
  create a signed product with the resulting package, using productbuild(1),
  there is no reason to sign the individual package."*
- **The timestamp is already on.** A trusted timestamp is included by default
  when signing with a Developer ID identity.
- **`productbuild --synthesize` writes a starting distribution** and it defaults
  to `customize="never"`, so the optional-components UI of section 4 needs
  `customize="always"` and `visible` choices. Generate it and edit it; do not
  hand-write one from memory.
- **`productsign(1)` exists** if a package ever needs signing after the fact.
- The bundle identifier in the real `Info.plist` is `net.tr4w.TR4W`; the package
  identifier is a separate namespace and is chosen, not derived.
- **THE IDENTITY CHECK COUNTS DISTINCT FINGERPRINTS, NOT MATCHING LINES.** This
  is a rule, not a preference, and `mac-sign.sh` was fixed to obey it on
  2026-09-27: it counted rows with `grep -cF`, so **one** certificate reachable
  through **two** keychains on the search list counts as two and the build dies
  with *"ambiguous"* over a certificate that is not ambiguous. That is live risk
  on this machine -- mac-ci's search list holds **five** copies of one path
  (appended by a different project's runner, which never checks), and the only
  reason the count is still right is that the path is stale and the keychain is
  not there. A fingerprint IS the certificate; two rows sharing one are one
  certificate seen twice. Two rows with DIFFERENT fingerprints and the same name
  are genuinely ambiguous and must still fail -- verified both ways.
- **The Installer identity is not a codesigning identity**, so
  `security find-identity -v -p codesigning` does **not** list it -- verified,
  it returns exactly one row (the Application certificate) on mac-ci today. The
  `.pkg` check must query `-v` (or `-p basic`) and filter by name, and it must
  not "fix" `mac-sign.sh`'s existing `-p codesigning` query to find it.
- **`--component` and `--root` both work**; the probe in section 5 used `--root`
  with the app staged under `root/Applications`, which is the shape a scripted
  build wants when more than one thing is being laid down. `--component` is
  shorter for exactly one bundle. Pick one and say which in the script.

### 9.3 Notarization -- its own pass, and the same three traps

The `.pkg` is notarized and stapled exactly as the `.dmg` is, with the rules
`build/mac-sign.sh` already encodes:

- **Gate on the parsed `status: Accepted`, never on the exit code.**
  `notarytool --wait` can exit 0 on a rejected submission.
- **Capture each command's own status, never a pipeline's.**
  `stapler validate ... | tail -3` returns 0 while printing failure.
- **Signing sits between staging and archiving**, so a failure leaves no
  artifact. An unsigned build is an ABSENT build, not one a cleanup step is
  trusted to delete. A `.pkg` that failed to sign or notarize must not be
  uploaded.

And one that applies to the release job rather than the script: a new expected
artifact belongs in the release audit's list, which since 2026-09-27
distinguishes required from optional and fails on a missing required one.

### 9.4 Ship it ALONGSIDE the `.dmg`, for at least one release

**Recommended, and the reason is stronger than caution.** The `.dmg` is the
artifact NY4I has personally confirmed downloads and opens with no Gatekeeper
warning (5.0.13, 2026-09-20). **A `.pkg` is a different Gatekeeper path** --
installer signature plus a notarization ticket on the package, assessed by
`spctl -a -t install` rather than `-t open` -- and nothing in this tree has ever
exercised it.

Replacing the one proven artifact with an unproven one on the same release leaves
no way to tell a `.pkg` problem from a build problem. Shipping both costs one
more asset, the release audit already treats macOS artifacts as optional rows,
and NY4I can retire the `.dmg` on the release AFTER the one where he watched the
`.pkg` work.

---

## 10. Prior art -- OPEN, for NY4I to fill

NY4I, 2026-09-27: *"I am gong to get a few examples of other mac ham radio
packages to see what they do"*.

**Nothing is guessed at here.** This section exists so the survey has questions
to answer rather than a blank heading. What would actually change a decision
above:

| question | which decision it bears on | what would change our mind |
|---|---|---|
| `.pkg` or `.dmg`? | section 2 | if the well-regarded ones are all drag-install `.dmg`s, the optional-symbols case has to carry the `.pkg` on its own -- it can, but say so |
| do they ask ANYTHING at install time? | 1.1 | a convention of asking nothing is itself an argument for the wizard owning everything |
| do they ask for a callsign or grid in the installer? | 1.1 | if a respected package does, understand what it does with it before copying -- the objection is ownership, not the pane |
| bundled or fetched data files? | section 7 | a package that fetches at install time and handles no-network well is worth reading |
| `/Applications` fixed, or a destination choice? | section 8 | TR4W writes beside its settings, not beside the binary, so a non-standard location should be harmless -- confirm it is |
| per-user or system install? | section 7.5 | this decides whether a postinstall script runs as root, which is the ownership trap in 7.5 |
| do they offer a language choice? | section 6 | if macOS ham software conventionally does, the 6.2 convention argument weakens; the 6.1 payload argument does not |
| what does the uninstall story look like? | not yet discussed | a `.pkg` has no uninstaller; NSIS ships one. This is a real asymmetry nobody has raised |

**That last row is a question this document raises rather than answers.** `.pkg`
installs leave `pkgutil --forget` and a manual bundle delete; the NSIS installer
writes an uninstaller. Nobody has decided what a macOS uninstall should do with
`~/Library/Application Support/TR4W` -- which is where the log database, the
settings and the downloaded country file live, and therefore the one directory an
uninstaller must not remove without asking.

---

## 11. Decisions owed from NY4I

| # | decision | recommendation | blocked on |
|---|---|---|---|
| 1 | optional debug symbols in the installer | **yes** -- decided, 67 MB and 55% of the Windows install | nothing; needs the `full.nsi` change and the `.pkg` |
| 2 | disk-space check | **WITHDRAWN by NY4I** -- *"the disk space is not a factor"*. Free either way: `installKBytes` is computed | closed |
| 3 | language at install time | **no -- put it in the wizard** | his ruling |
| 4 | data-file download at install time | **no -- the app already does it; offer it in the wizard** | his ruling, and a wizard page he has not approved |
| 5 | macOS `.dSYM` -- produce it, but keep it BESIDE THE RELEASE, not in the bundle | **FPC 3.2.2 cannot read one; measured, see 4.2.1.** In the bundle it is 66 MB that does nothing. Beside the release it makes crashes resolvable with `atos`, which `uCrashLog` already prints the command for | his ruling -- he approved the bundle on a premise that proved false |
| 6 | Linux separable symbols | `-Xg` + `objcopy`, own piece of work | not proposed |
| 7 | `.pkg` alongside or instead of the `.dmg` | **alongside for at least one release** | his ruling |
| 8 | macOS uninstall story | none formed -- see section 10 | nobody has raised it |

---

## 12. Nothing in `SETUP_WIZARD_DESIGN.md` conflicts with this split

Checked clause by clause on 2026-09-27. Three places touch the boundary and all
three are compatible:

- **Section 6, "When it runs."** The wizard's gate is evaluated after the config
  files are read and asks whether `MyCall` is empty. An installer that wrote no
  settings -- which is the rule in 1.1 -- leaves that gate exactly as designed.
  **An installer that asked for a callsign would break it**, by making the
  upgrade row ("first run, and `MyCall` is non-empty after the config reads ->
  no wizard") fire for a brand-new station. That is the sharpest reason for the
  prohibition and it is a behaviour change, not a style objection.
- **Section 5, "What Cancel can and cannot do."** It already establishes that
  `tr4w.json` exists before the wizard is shown, written after
  `LoadSettingsForStartup` returns false -- `uProgramMain.pas:1935-1938` today;
  the wizard document cites `:1675-1681`, which has drifted (see the note at the
  end of this section). An installer writing that file first would make the
  file-exists question ambiguous in a way the wizard document has carefully
  reasoned around.
- **Section 8, i18n.** *"Green field"* -- a new form has no `TC_` constants to
  strand. The language decision in section 6 keeps it that way; an installer
  writing a language setting would not break i18n, but it would add a second
  writer of `Settings.Display.Language`.

**One thing NY4I has to resolve rather than us**: section 7.4 proposes a "fetch
current data now" page, and `SETUP_WIZARD_DESIGN.md` section 2 declares the page
shape SETTLED and says to reopen it with him rather than in a document edit.
This document therefore proposes it and does not add it.

**And two documentation gaps found in passing, one fixed and one not.**

`SETUP_WIZARD_DESIGN.md` was not in CLAUDE.md's Documentation map. Both documents
are now, because a design the map does not mention is one the next agent
re-derives.

**`SETUP_WIZARD_DESIGN.md`'s LINE NUMBERS HAVE DRIFTED and that is NOT fixed
here**, because refreshing citations inside a settled design document is an edit
somebody should make deliberately rather than as a side effect of writing a
different one. Measured 2026-09-27, against the three this document had reason to
follow:

| the wizard document says | where it actually is | drift |
|---|---|---|
| `uProgramMain.pas:1675-1681` -- the startup `tr4w.json` write | `:1935-1938` | +260 |
| `uProgramMain.pas:2115` -- the `MY GRID` startup prompt | `:2490-2527` | +375 |
| `uProgramMain.pas:1673`, `:1727`, `:1729` -- the first-run gate | not re-checked | presumably similar |

**The REASONING in that document is unaffected** -- every claim it makes about
what the code does still holds, and the identifiers it names (`LoadSettingsForStartup`,
`GridPromptAlreadyShown`, `MarkGridPromptShown`, `ConfigurationOkay`) all resolve.
Only the offsets moved. But an agent told to read `:1677` will read something
unrelated and may conclude the document is wrong about the program, which is the
more expensive failure. **Grep the identifier, not the line.**
