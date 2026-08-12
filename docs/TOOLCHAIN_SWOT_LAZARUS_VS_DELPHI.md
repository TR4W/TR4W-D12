# Toolchain SWOT: staying on Delphi 12 vs moving to Lazarus / Free Pascal

**Status:** analysis for review. No decision taken.
**Author:** drafted 2026-08-12 at NY4I's request, for a decision he owns.
**Question asked:** *"I may have made a mistake selecting D7 → D12. Consider switching to
Lazarus/FreePascal, including for cross-platform. I am not convinced FMX and the way Delphi handles
cross-platform is a good long-term strategy. Plus a hobbled Community Edition has long-term costs.
SWOT it, keeping in mind we are on a long tail. I certainly do not want to do these giant refactors
twice."*

---

## 1. The constraints that decide this

Four answers from NY4I, 2026-08-12, because every one of them moves the conclusion:

|                      |                                                                               |
| -------------------- | ----------------------------------------------------------------------------- |
| **Target platforms** | Windows **+ Linux + macOS**, full desktop parity                              |
| **Contributors**     | **Open to community contributors** — anyone should be able to clone and build |
| **Timing**           | **Now**, before more refactors land                                           |
| **Horizon**          | **10+ years, actively developed**                                             |

And one more, given unprompted and load-bearing:

> *"My intention was to always move from Win32 calls for cross-platform reasons. That also means any
> remaining asm has to be eradicated too."*

**That last statement is the most important sentence in this document.** It removes the largest
number from both sides of the ledger at once — see §3.

---

## 2. What the codebase actually is

Measured, not estimated (2026-08-12, `tr4w/src`):

| Area                                 | Units   | Lines       | Units touching Win32 |
| ------------------------------------ | -------:| -----------:| --------------------:|
| `src/` root — **the Win32 UI layer** | 146     | 97,657      | **53**               |
| `src/trdos/` — contest engine        | 34      | 65,903      | 13                   |
| `src/radioFactory/`                  | 118     | 27,319      | **1**                |
| `src/lang/`                          | 11      | 9,800       | 0                    |
| `src/utils/`                         | 7       | 1,015       | 1                    |
| **Total**                            | **304** | **152,357** | **68**               |

Other measurements that bear on portability:

- **73 inline `asm` blocks** across ~20 units, including `LOGSTUFF`, `LOGWIND`, `tree`, `TF`,
  `MainUnit` and `tr4w.dpr`.
- **19 units use Indy**; the vendored copy is 10.6.3.3.
- **451 `ShortString` / `string[n]` declarations**, concentrated in the TRDOS core.
- **7 units use anonymous methods** (`reference to`) — and they are the *newest* code: the radio
  registry's self-registration closures, `TProcessMsgRef`, the rotator factory, `uSettingsRegistry`.
- 12 units use `Generics.Collections`; 4 use `System.JSON`; 1 uses `System.Diagnostics`.
- **10 units use FMX**, backing **5 designed forms**.

### The three findings that matter most

**(a) The radio factory is already portable.** 118 units, 27k lines, and exactly *one* touches Win32.
That was not an accident — it is what the factory discipline bought. The same is broadly true of
`lang/` and `utils/`. Roughly **38k lines are portable today**.

**(b) The Win32 debt is concentrated, not smeared.** 53 of 68 Win32-touching units are in the `src/`
root — the UI layer — exactly where you would want it. The contest engine's 13 are mostly display
routines (`LOGWIND`) rather than contest logic.

**(c) The newest, most modern code is the code most at risk from FPC.** The closures that make the
registries elegant are the one feature where stable FPC has historically lagged. This is the reverse
of the usual expectation, and it is the single technical item that could sink a switch. See §6.

---

## 3. The decisive reframing

Because NY4I has already committed to removing Win32 **and** eradicating inline asm regardless of
toolchain, that work is a **constant, not a differentiator**:

```
Cost of Win32 removal + asm eradication   ≈ identical under Delphi and under Lazarus
```

It is by far the largest line item — on the order of 100k lines of UI-adjacent code — and it cancels
out of the comparison entirely.

**What is left, once you cancel the constant, is a much smaller and much sharper question:**

> When that work is finished, which toolchain do you want to be standing on — and does the
> destination change *how* you should do the work between now and then?

**Revised 2026-08-12, after NY4I's verification pass.** The first draft answered "and it is not
close", on the grounds that Delphi could not reach Linux desktop at all. FMX Linux is available
again for 12.2/12.3, so that argument is withdrawn — the matrix is reachable under Delphi.

The answer is still Lazarus, but it now rests on different and less absolute ground: **contributor
access, vendor independence over ten years, and the quality of the UI framework** — not on a
capability gap. It is a judgement call rather than a forced move, and §6 is now closer to being
right than it was.

---

## 4. SWOT — staying on Delphi 12

### Strengths

- **Already working.** D12 compiles green, 3,795 unit tests pass, the golden corpus is 22/0/4, nine
  lints gate the build, and the release pipeline is msbuild end to end. This is real, banked value.
- **Best-in-class debugger and form designer.** The FMX designer round-trip is proven in this repo
  (`docs/fmx-designed-forms-work`), and the Delphi debugger remains materially better than GDB/LLDB
  for Pascal.
- **Commercial support and a defined release cadence.** Someone to escalate to.
- **The team knows it.** Twelve years of muscle memory, and every convention in `CLAUDE.md` is
  written in Delphi's dialect.
- **The D12 migration is nearly done.** Abandoning it now writes off the compile work, the string
  modernisation, and the build/lint infrastructure.

### Weaknesses

- **Linux desktop needs an add-on, and that add-on has already lapsed once.**
  **[RESOLVED 2026-08-12 — and this materially weakens the case against Delphi.]** NY4I found that
  FMX Linux *is* available again for RAD Studio 12.2 and 12.3. Embarcadero's own wording is worth
  reading closely: the library "is available **once again**". So Linux desktop is reachable — but
  through a separately-supplied component whose availability has already been interrupted at least
  once, on a 10-year horizon, and which a Community Edition contributor is unlikely to have.
  My original claim that the platform matrix was **unreachable** on Delphi was too strong and is
  withdrawn. It is reachable; it is a dependency rather than a wall.
- **Community Edition cannot serve a contributor community.** Revenue-capped, licence-activated,
  time-limited renewals, and — NY4I's specific point — no unrestricted command-line compiler. A
  contributor who cannot run the build is not a contributor. **[VERIFY current CE terms.]**
- **FMX is a draw-everything framework.** It renders its own controls rather than using native ones.
  For a contest logger judged on responsiveness and native feel, that is a real cost, and this
  session already spent hours on FMX-specific defects that would not exist in a native-widget
  toolkit: a 726-item combo costing 1.8 s to populate, `Enabled=False` items still selectable,
  `OnPopup` unable to fire on an empty list, the `Cursor` property silently not applying.
- **Licensing risk compounds over a 10-year horizon.** Pricing, edition boundaries and activation
  policy are one vendor's commercial decisions, and they have changed before.

### Opportunities

- Finish D12, ship it, and treat it as a *stepping stone* — the Win32 removal it enables is
  toolchain-neutral and would carry to Lazarus intact.
- The FMX/VCL coexistence work (`docs/VCL_WIN32_COEXISTENCE.md`) has already proven the hard part:
  that a designed-form layer can live alongside the Win32 loop. **That proof transfers to LCL.**

### Threats

- **Doing the refactor twice** — NY4I's stated fear. Every hour spent on an FMX form is an hour
  spent on the one layer that would *not* survive a later move, since LCL and FMX have different
  form formats, control sets and layout models.
- **The Linux gap does not close by waiting.** It is a strategy decision by the vendor, not a
  backlog item.
- **Contributor supply over ten years.** A project whose barrier to entry is a commercial licence
  has a smaller succession pool — and NY4I's answer to the succession question was that toolchain
  accessibility is the deciding factor.

---

## 5. SWOT — moving to Lazarus / Free Pascal

### Strengths

- **All three desktop platforms are first-party.** LCL targets Windows (Win32/WinAPI), Linux
  (GTK2/GTK3/Qt5/Qt6) and macOS (Cocoa, including Apple Silicon) as peers. The stated platform
  matrix is reachable.
- **Free and unrestricted, permanently.** GPL/LGPL with a linking exception. No licence server, no
  revenue cap, no activation. Any contributor can clone and build; CI can build all three platforms
  on stock GitHub runners with no licence provisioning. For "open to community contributors" this is
  not a preference, it is the requirement.
- **LCL is a closer conceptual match to TR4W than FMX is.** LCL wraps *native* widgets and is
  VCL-shaped — handle-backed controls, owner-draw, message-ish semantics. TR4W's UI is HWND and
  owner-draw throughout. Porting a Win32 app to a native-widget toolkit is a shorter conceptual leap
  than porting it to a render-everything framework, and it preserves the native look and the
  responsiveness budget in `CLAUDE.md`.
- **FPC is more comfortable with this code than modern Delphi is.** 451 `ShortString` sites,
  procedural style, records everywhere, a DOS heritage — FPC's dialect support is excellent and its
  `{$MODE DELPHI}` covers most of the tree. The `{$CODEPAGE}` directive the lang files wanted, and
  that Delphi rejects with `E1030`, is an FPC feature.
- **Longevity by construction.** No vendor can reprice, restrict or discontinue it. For a 10-year
  horizon whose real question is succession, that is the strongest single argument.
- **Translation tooling that still exists.** NY4I, 2026-08-12: Delphi has been deprecating its
  localisation tools (the Integrated Translation Environment / External Translation Manager), while
  FPC and Lazarus support **GNU gettext `.po` files** natively -- `resourcestring` values are
  extracted to `.po`, and Lazarus ships a translator unit that loads them at run time. This is not a
  small point for TR4W:
  - The **ENG + 8** language matrix currently costs **nine separate builds**, selected by the
    `LANG_xxx` compiler defines in `VC.pas`. `.po` files are loaded at run time, so that collapses to
    **one build per platform** -- which is exactly what the localisation brief
    (`docs/claude-code-localization-migration-prompt.md`) already specifies as the target, and it
    specifies it because resource DLLs have no FMX/macOS/Linux equivalent.
  - **Translators get Poedit**, a free, standard, cross-platform tool. For volunteer translators in
    the amateur radio community that is the difference between a contribution being possible and
    not -- and it is the same argument as the toolchain licence, one layer up.
  - The mechanism is already visible: the FPC spike emitted `.rsj` resource-string files beside the
    units without being asked. That is the input side of the `.po` pipeline.

- **Cross-compilation is routine**, so one machine can produce all three targets.

### Weaknesses

- **Anonymous methods.** The newest code leans on them. Stable FPC (3.2.x) has not supported
  `reference to`; support landed in the development branch. If the current stable release still
  lacks it, `uRadioRegistry`, `uSettingsRegistry`, `uRotatorControl` and `TProcessMsgRef` all need
  rework to interface-or-method-pointer form. **This is the #1 item to verify, and §8 says how.**
- **IDE and debugger are less polished** than Delphi's. Real, and felt daily.
- **The FMX forms would be redone in LCL.** 10 units, 5 designed forms — bounded, but it is the work
  most recently completed, so it is the most galling to redo.
- **The build and lint infrastructure needs a second implementation** (`lazbuild`/`fpmake` beside
  msbuild). The nine PowerShell lints are logic, not Delphi, and `pwsh` is cross-platform — so they
  port, but they need to actually be run on the other platforms.
- **Indy on FPC needs proving.** 19 units depend on it. Indy 10 has FPC support, but the vendored
  10.6.3.3 specifically must be tested, and the decision to vendor it (`CLAUDE.md`, 2026-08-04) was
  taken for Delphi-specific reasons that may not survive the move. **[VERIFY]**
- **Delphi RTL units need mapping**: `System.JSON` → `fpjson`, `System.Diagnostics` → `EpikTimer` or
  a small shim, `Generics.Collections` → FPC's own or `fgl`.

### Opportunities

- **The switch is cheapest right now, and gets monotonically more expensive.** The FMX investment is
  10 units. It will not stay that size — the Preferences form went from 67 controls to 347 in a
  single day this month.
- **The test suite is the safety net that makes this tractable.** 3,795 unit tests and 26 byte-diff
  golden-master comparisons are almost entirely toolchain-agnostic Pascal. Very few 150k-line
  legacy codebases can attempt a toolchain migration with that kind of oracle. **This is the single
  biggest de-risking asset TR4W has, and it argues for doing the move while the oracle is fresh.**
- **The unit-test project is a near-perfect spike target** — it links leaf units only, which is
  exactly the portable subset. See §8.
- **Removing the licence barrier may change who shows up.** NY4I's own answer to the contributor
  question was that contribution is currently limited *by* the toolchain cost.

### Threats

- **A long "neither works" period** if the move is attempted as a big bang. Mitigated by keeping the
  tree building under both toolchains during transition — feasible because most of the tree is
  plain Pascal, and `{$IFDEF FPC}` is the standard mechanism.
- **Lazarus/FPC release cadence is community-driven** and slower than a commercial vendor's. Slower,
  but not revocable — the opposite failure mode to Delphi's.
- **Loss of commercial escalation.** Real, though for a hobbyist-community contest logger the
  practical value of that escalation path is worth questioning honestly.
- **Sunk-cost pull.** The D12 work is recent and it was hard. That is not a reason to keep going,
  and it is the bias this document exists to counter.

---

## 6. The honest counter-argument to switching

Stated as strongly as it can be, because a SWOT that only argues one way is advocacy:

> The D12 port is nearly finished. The definition of done — a Win32 D12 build replacing D7 with no
> Delphi 7 in the pipeline — is close. Radios are bench-proven family by family. Switching now
> abandons a nearly-complete migration for a second migration whose scale is *also* underestimated,
> which is precisely the mistake being regretted about the first one. The cross-platform goal is
> aspirational: no user has asked for Linux or macOS, and the amateur radio contest community runs
> Windows almost universally. A rational plan is to ship D12, get the release out, and revisit.

**Why it half-carries, revised 2026-08-12.** The platform half of my rebuttal is gone: FMX Linux is
available again, so finishing D12 *can* lead to a Linux desktop build. That was the strongest
argument and it did not survive verification.

What remains is the **contributor** half, and it is unaffected. Community Edition's restrictions are
not something the project can engineer around, and NY4I raised a second-order version of the same
problem: as an open-source project, using his company's signing certificate on a Community-Edition
build "could get into a questionable area". A licence whose boundaries need legal thought before you
sign a release is a real cost on a ten-year horizon, separate from any technical merit.

So the honest position is narrower than the first draft's: **Delphi can do the job; the question is
whether the licence should be in the critical path of a community project for the next decade.**

If NY4I's real position is that cross-platform is aspirational and Windows is the honest target,
**this document's recommendation reverses** — stay on Delphi, finish D12, and the FMX concerns
become manageable rather than structural. That is the one input worth re-examining before acting,
because it is the hinge.

---

## 7. Recommendation

**Move to Lazarus/FPC, decided now, executed incrementally, and gated on one spike.**
*(Recommendation unchanged after the 2026-08-12 verification pass; the reasoning behind it is not.)*

The expensive work — removing Win32, eradicating asm, separating core from UI — is committed to and
is identical under both toolchains, so it cancels. What differs is the destination, and the case now
rests on three things rather than on a capability gap:

1. **Contributor access.** A free, unrestricted toolchain is a requirement of "open to community
   contributors", not a preference. Community Edition cannot serve it, and its boundaries are
   ambiguous enough that NY4I flags signing as a grey area.
2. **Vendor independence over ten years.** Nothing about FPC can be repriced, restricted or
   withdrawn. FMX Linux "available once again" is a live demonstration of the opposite property.
3. **Framework fit.** LCL wraps native widgets and is VCL-shaped, which is a shorter conceptual leap
   from TR4W's HWND/owner-draw UI than FMX's render-everything model — and it is FMX specifically
   that NY4I is unconvinced by.

**What is no longer claimed:** that Delphi cannot reach Windows + Linux + macOS. It can.

The cost of switching is at its historic minimum today and rises with every FMX form.

**But do not act on this until the spike in §8 passes.** If stable FPC cannot compile the registry
closures, the picture changes and the sequencing needs rethinking.

### What to do differently starting tomorrow, spike or no spike

These are all *no-regret* moves — correct under either toolchain:

1. **Pause new FMX form work.** Not the settings *architecture* — `uSettingsRegistry`, the config
   store and the JSON work are portable and valuable. Pause the *designed forms*, which are the one
   artifact that does not survive.
2. **Keep the factory discipline.** It is why the radio factory is already portable and is the
   single best predictor of migration cost.
3. **Treat every new `asm` block and every new Win32 call as a defect**, since both are already
   slated for removal.
4. **Add a portability lint** in the style of the existing nine: flag new Win32 API calls and new
   `asm` blocks outside a declared platform-services directory. The project's culture is to gate
   what it cares about, and this would stop the debt growing while the decision is settled.
5. **Do not stop the bench programme.** Radio verification is protocol-level and toolchain-neutral;
   every rig proven is proven under Lazarus too.

---

## 8. The spike that decides it — bounded, ~1 day

**Target: compile and run `tr4w/test/unit` under FPC — on Windows, then Linux, then macOS.**
It links leaf units only, and carries 3,795 assertions that say whether the semantics survived.

NY4I's extension — run it on all three platforms, not just under FPC on Windows — is what makes this
a portability test rather than only a dialect test. The three legs answer different questions and
should be run in this order:

| Leg                       | What it isolates                                                                                                                                                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **FPC on Windows**        | The **dialect** alone — anonymous methods, generics, RTL units. Platform held constant.                                                                                                                                      |
| **Linux**                 | **Platform semantics**: path separators, a case-sensitive filesystem, line endings in the config-file tests, `AnsiString` codepage behaviour. The failures that compile clean and go wrong at runtime.                       |
| **macOS (Apple Silicon)** | The strictest leg. ARM64 and **64-bit only**, so it forces both things D12 explicitly scoped out — 64-bit correctness and the total absence of x86 `asm` — against a suite that answers pass/fail rather than "it compiled". |

### What actually stands in the way — measured, 2026-08-12

Of the **148 `src` units the test project links**:

| Blocker                            | Count | Units                                                                                              |
| ---------------------------------- | -----:| -------------------------------------------------------------------------------------------------- |
| Win32 API calls                    | **2** | `uCTYDAT`, `utils_file`                                                                            |
| Inline `asm`                       | **2** | `uCRC32`, `utils_text`                                                                             |
| Indy                               | **5** | `uFactoryRadioBase`, `uWebSocketClient`, `uWebSocketFraming`, `uWebSocketServer`, `uFlexDiscovery` |
| Names the `Windows` unit in `uses` | 14    | mostly for types                                                                                   |

That is a short and specific list, and it makes the spike smaller than the one-day estimate:

- **Stage it internally.** Exclude the 5 Indy/WebSocket units and their tests first — ~143 units
  should compile with very little in the way, giving a signal in *hours*. Then add them back, which
  turns "does Indy 10.6.3.3 work on FPC" into a separate, answerable question instead of a blocker
  on everything else.
- **The two `asm` units are already covered by tests.** `uCRC32` and `utils_text` can be rewritten
  in pure Pascal and verified byte-exact immediately — asm eradication with a built-in oracle,
  exactly the "write the pin test with the move" rule the project already follows. **Worth doing
  regardless of the decision**, since the asm is slated for removal either way.

### The plan — agreed 2026-08-12, branch `fpc-spike`

Branched from `config-json`, **not** from `master`: master's copy of the test project is from
2026-08-02 and predates `uSettingsRegistry`, the rotator factory and the newest registry work —
which are precisely the anonymous-method users the spike exists to test. Spiking against master
would return a comfortable answer to the wrong question.

Nothing in `tr4w/src` is edited to make it compile. The spike is a **measurement**, and every
`{$IFDEF FPC}` added to force a pass is a result thrown away. Findings go in a log; fixes come after
the decision.

**Step 0 — record the ground truth.** `fpc -iV` and `lazbuild --version`, into
`docs/FPC_SPIKE_LOG.md`. NY4I has Lazarus **4.8** installed. **This matters more than it looks:**
the anonymous-functions announcement he found (fpc-announce, May 2022) describes work landing in the
FPC *development* branch. Whether the FPC that ships with Lazarus 4.8 is a 3.2.x stable or a 3.3.x
development build decides item 1 of §9 outright. Record it before anything else.

**Step 1 — the smallest thing that can fail: one leaf unit.** Compile `uCRC32` alone. It is 1 of the
2 `asm` units in the test set, so it fails immediately if x86 assembly is a problem, and it costs
minutes. A quick, clear failure here is worth more than an hour of link errors.

**Step 2 — the anonymous-method question, in isolation.** Before the full project, compile a
ten-line probe using `reference to procedure` in `{$MODE DELPHI}`. That single answer determines
whether the spike is a formality or a redesign, and it should not be buried in a hundred other
errors.

**Step 3 — the portable core, Indy excluded.** Build the test project minus the 5 Indy units
(`uFactoryRadioBase`, `uWebSocketClient`, `uWebSocketFraming`, `uWebSocketServer`, `uFlexDiscovery`)
and their suites. ~143 units. Record every failure **by category** — anonymous methods, generics,
RTL units, `ShortString`, `AnsiString`/codepage, `asm` — not as a list of messages. Categories are
what can be costed; messages cannot.

**Step 4 — run them.** `PASSED: n FAILED: m` is the deliverable. **"It compiled" is not a result.**

**Step 5 — Linux, then macOS.** Same project, same commands. Diff the pass/fail sets *between*
platforms: a test that passes on Windows and fails on Linux is a portability defect with an exact
address, and that diff is the single most valuable artefact the spike can produce.

**Step 6 — Indy, as its own question.** Add the 5 units back. NY4I's research says the community
recommends the upstream Indy over the RAD-Studio-supplied one, and that Indy reportedly works on
macOS — untested. Note that this collides with the 2026-08-04 decision to vendor 10.6.3.3, which was
taken for Delphi-specific reasons (source-level SSL debugging) that may not survive the move.

**Timebox: one day.** If step 3 turns into an open-ended repair job, that *is* the finding — stop
and write it down rather than pushing through, because "how much resistance did it give" is the
number the decision actually needs.

### The prize beyond the decision

Once the suite builds and runs on three platforms, **make it a CI matrix and keep it forever.** FPC
needs no licence provisioning, so ubuntu/macos/windows runners can build it on every push. That
turns a one-off spike into a permanent portability gate, in exactly the style of the nine lints that
already gate this build — every future commit checked for portability regressions rather than
discovering them years later. That gate is valuable **even if the project stays on Delphi**: it
would keep the core honest while the Win32 removal proceeds.

Decision rule, agreed before the spike so the result cannot be rationalised afterwards:

- **All or nearly all tests pass** → the core is portable; proceed to plan the move in earnest.
- **Compiles but fails at runtime** → string/codepage semantics differ; this is the dangerous
  outcome and needs a deeper look before any commitment.
- **Anonymous methods are the only structural blocker** → cost the rework of 7 units. Small, and
  arguably worth doing anyway for the strangler-pattern reasons the project already believes in.
- **Widespread structural failure** → stay on Delphi, ship D12 Windows-only, and re-examine the
  platform goal honestly.

Then, and only then, a phased plan: platform-services layer → core proven under both toolchains in
CI → UI rewritten once, in LCL, replacing the Win32 windows that were going to be replaced anyway.

---

## 9. Facts to verify before deciding — all of them load-bearing

I have flagged these rather than asserted them, because each could change the recommendation and
none should be taken on my word:

| #   | To verify                                                                                | Why it matters                                                                               | NY4I Reply                                                                                                                                                                                                                                                                                                                                                                |
| --- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Does **current stable FPC support `reference to`** / anonymous methods?                  | The #1 technical risk. Settled by the §8 spike.                                              | FPC does supports anonymous functions per https://lists.freepascal.org/fpc-announce/2022-May/000620.html                                                                                                                                                                                                                                                                  |
| 2   | **Delphi's current Linux desktop GUI story** — first-party FMX Linux, or still FmxLinux? | The central argument against Delphi. If this has changed, re-weigh.                          | From an Embarcadero blog post, "Embarcadero is very happy to announce that the FMX Linux UI library for building Linux client applications with Delphi is available once again for RAD Studio 12.3 and also for RAD Studio 12.2, along with older versions" (Retreived from https://blogs.embarcadero.com/fmx-linux-for-delphi-12-3-is-now-available/ on 12 August 2026)) |
| 3   | **Current Community Edition terms** — revenue cap, command-line compiler, renewal.       | The contributor argument.                                                                    | This is an open source project but for example if I ever wanted to use my company's Signing certtificate, I could get into a questionable area.                                                                                                                                                                                                                           |
| 4   | **Vendored Indy 10.6.3.3 under FPC** — or the cost of moving to Synapse/lNet.            | 19 units.                                                                                    | The Indy recommendation and thus from the community is to not use th eDelphi 12 supplied Indy. Instead, all recommendations I have read suggest to use the one downloaded from Indy. Also, my research indicates that Indy does work on the Mac but that remains to be tested.                                                                                            |
| 5   | **hamlib, OpenSSL** on Linux/macOS.                                                      | Expected fine — both are natively cross-platform, which is a quiet point in favour.          | Agreed                                                                                                                                                                                                                                                                                                                                                                    |
| 6   | **LPT keying (`inpout32.dll`, `DLPortIO.pas`)**.                                         | Windows-only and legacy. Likely a documented Windows-only feature rather than a port target. | That will be a Windows only idea.                                                                                                                                                                                                                                                                                                                                         |
| 7   | **macOS code signing / notarisation** burden.                                            | Applies under either toolchain; a real cost nobody enjoys.                                   | I would handle that as I do it for other apps. We can script the notary tool as needed.                                                                                                                                                                                                                                                                                   |

---

### Where §9 stands after NY4I's pass

Five of the seven are answered, and they move in **Delphi's** favour more than mine:

- **Anonymous functions exist in FPC** (fpc-announce, May 2022) — the #1 risk is probably not a
  risk. Caveat: that announcement is development-branch work, so the installed FPC version still
  decides it. Step 0.
- **FMX Linux is available again** for 12.2/12.3 — my central argument, withdrawn.
- **Indy** is expected to work, and the community view is to prefer upstream Indy over the bundled
  copy — which weakens both the Indy risk *and* the reason we vendored 10.6.3.3.
- **hamlib/OpenSSL** agreed portable; **LPT keying** accepted as Windows-only; **notarisation**
  is a solved problem for NY4I, scriptable.

Read plainly: the technical objections to Lazarus mostly dissolved, and so did my strongest
objection to Delphi. What is left is a governance question — licence in the critical path or not —
plus the framework-fit argument. That is a narrower and more honest basis for the decision than the
first draft had, and it is why the spike matters: it converts the last technical unknown into a
number.

---

## 10. What this document does not claim

- It does not claim the D12 work was wasted. The string modernisation, the factories, the test
  suite, the corpus and the lints are all toolchain-neutral and are the reason a move is even
  discussable.
- It does not claim Lazarus is a better *IDE*. It is not.
- It does not claim the move is cheap. It claims the *expensive part is already committed to* and
  is identical either way.
- It does not settle the platform question. If Windows-only is the honest target, §6 wins and this
  recommendation reverses. **That is the one input worth re-examining before acting.**
- **It no longer claims Delphi cannot reach Linux.** That claim was the spine of the first draft and
  it did not survive verification. Recording the correction here rather than quietly editing it out,
  because the next reader deserves to know which arguments held up and which did not.
