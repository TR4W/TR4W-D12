# The control channel: driving TR4W over WebSocket

**Status: DESIGN, nothing built. 2026-09-06.**
Decided so far: the transport is the existing `uWebSocketServer`, not a new one, and not AutoIt.
Everything under [Open decisions](#open-decisions) is NY4I's call and is not settled here.

This describes a second consumer of a WebSocket server TR4W already ships — a channel that can
inject input and issue semantic commands, for **test harnesses and for external clients**, which are
deliberately two different things.

---

## 1. Why

Two problems, and it is worth being clear that only one of them is about testing.

### 1.1 The UI harness is nailed to Win32, and one nail is already loose

`tr4w/test/ui/` is 4,077 lines across 17 scripts and it works: it launches the binary, finds the
main window by PID, posts keystrokes, and asserts on TR4W's own log lines. `Test-CountyLineEntry.ps1`
caught a real defect that nothing else could see — a county-line exchange logging one QSO instead of
four in the serial-number QSO parties.

It reaches the callsign and exchange fields by `EnumChildWindows` + `GetDlgCtrlID`, looking for the
ids `VC.pas` declares (73 callsign, 88 exchange). Those ids exist on the controls **only** because
`uMainForm.CreateTR4WEntryField` ends with

```pascal
   {$IFDEF WINDOWS}
   Windows.SetWindowLong(Result, GWL_ID, aId);
   {$ENDIF}
```

That line is a raw Win32 call surviving inside an otherwise-converted LCL form, and the Win32/HWND
removal work wants it gone. It cannot go while the harness needs it.

**And the id is only half the problem.** The harness drives the program with
`PostMessage(hwnd, WM_CHAR, ...)`, which has no macOS or Linux equivalent at all. Gating the id on
`{$IFDEF WINDOWS}` buys no portability — it only makes a Windows-only dependency compile cleanly
elsewhere. Both halves go together or neither does.

**AutoIt closes the Windows half of this, and does nothing for the other half.** Getting that
right took two corrections, so both are recorded here.

AutoIt's `ControlID` *is* `GetDlgCtrlID`, so its id-based targeting dies with the line above. Its
`ClassNameNN` targeting does not: **a `TEdit` is a native Win32 `EDIT` control under the win32
widgetset**, so AutoIt reads class `Edit` and can take the callsign field as instance 2 of it. NY4I
demonstrated exactly that against a running v5.0.2 on 2026-09-06. An earlier draft of this document
claimed every LCL control reports class `Window`; that was an over-generalisation from the *form's*
class and is false for this control.

Measured the same day by attaching `test/ui/Dump-WindowTree.ps1` to the running program — 167
windows in the process:

| class | count | where |
|---|---:|---|
| `Window` | 140 | the form and every `TElementPanel` |
| `Button` | 8 | |
| **`Edit`** | **4** | ids 1001, 1001 on DX Cluster; **88 (exchange), 73 (callsign)** on the main window |

**What the id buys is the failure mode, not the access.** An instance number is enumeration order,
and enumeration order is not creation order: `MainUnit` creates the callsign field *before* the
exchange field, and the callsign field enumerates **second**. The number is a z-order artifact.

That matters because assigning `Font` after the `SetWindowLong` **recreates the TEdit's handle** — a
trap `Test-Typing.ps1` has already caught once. A recreated handle moves in the z-order, so the same
event that produced `"no control with id 73 (the callsign window)"` would instead silently renumber
the instances. Keystrokes would land in the exchange field, `ExchangeWindowKeyDownProc` does not emit
the trace `Test-Typing.ps1` asserts on, and the test would fail as *"the keyboard is not routed"* —
loud, plausible, and aimed at the wrong subsystem.

So AutoIt is a **legitimate tactical option** if the goal is to delete the `GWL_ID` line today: it
trades a truthful failure for a misleading one, and costs a second language in the tree. It is
**not** a strategic answer, because it is Windows-only — it leaves §1.1's second half exactly where
it was. Nothing below this section changes either way.

### 1.2 The uses outside testing are the better half of the argument

A channel that can set band and mode, log a QSO, read the running score and receive spot
notifications is a **companion-app surface**, not a test hook. TR4W already accepts that premise
once: `uTCIServer` exists because only one program can hold a radio's COM port, so anything else
that wants the radio has to come through TR4W. A control channel is the same argument applied to the
contest state rather than the radio.

That is why this is worth doing properly rather than building `/SCRIPT` — a switch that reads a file
of keystrokes would close the harness gap and nothing else.

---

## 2. What already exists — measured 2026-09-06

| unit | lines | what it is |
|---|---:|---|
| `src/uWebSocketServer.pas` | 756 | *"A MINIMAL RFC 6455 WEBSOCKET SERVER — TRANSPORT ONLY, NO TCI KNOWLEDGE"* |
| `src/uWebSocketFraming.pas` | 609 | framing, shared with the client |
| `src/uWebSocketClient.pas` | 469 | the mirror, used by the TCI *radio* |
| `src/uTCIServer.pas` | 2,037 | one consumer of that transport |
| `src/uTCIProtocol.pas` | 631 | that consumer's command vocabulary |

**The split is already the right one.** The server unit's own header says it carries no TCI
knowledge, and the protocol lives in a separate unit. A control channel is therefore a new
`uControlProtocol` + a thin server shim, not new infrastructure.

The transport also already made the decisions that are painful to retrofit:

- **A reader thread and a per-session sender thread.** `SendText` never touches a socket; it appends
  to a per-session queue and signals. A client on a dropped Wi-Fi link cannot stall the radio poller.
- **The queue is bounded** (`WSS_MAX_QUEUED_MSGS = 512`, `WSS_MAX_CLIENTS = 8`,
  `WSS_MAX_FRAME_BYTES = 64 KB`). Past the cap the session is closed and says why.
- **Loopback by default**, with the reasoning written down: *"an unauthenticated radio-control socket
  on every interface is not something to switch on without being asked. uWSJTX's Commander server
  binds all interfaces unconditionally; that is not a precedent worth following."*

**Portability note:** `uWebSocketServer` and `uWebSocketFraming` both name `Windows` in their uses
clause and **neither contains a single `Windows.`-qualified call** (measured). That is a uses-clause
tidy, not a port. Indy itself is cross-platform.

---

## 3. The protocol: two namespaces, deliberately not one

This is the central design decision and the easiest one to get wrong.

A test harness wants to inject **input** — the point is to exercise the real path, keystroke routing
and all. `Test-Typing.ps1` exists precisely to prove a character travels through TR4W's actual
routing and reaches `CallWindowKeyDownProc`; a command that set the field's text directly would pass
while the routing was broken.

An external client wants **semantics** — `log-qso`, `set-band`, `get-score`. It does not want to know
that the callsign field is a `TEdit`, and a protocol that made it type characters would break every
time the UI changed.

**These are not the same protocol, and merging them produces a channel that is a weak API and a
dishonest test.** So:

| namespace | audience | example | stability |
|---|---|---|---|
| `input.*` | the UI harness, and only it | `input.key`, `input.text`, `input.focus` | internal; may change with the UI |
| `state.*` | external clients | `state.subscribe`, `state.get` | versioned, public |
| `command.*` | external clients | `command.setBand`, `command.logQso` | versioned, public |

`input.*` is **off unless explicitly enabled** — see §4. An external client has no business
synthesising keystrokes into a contest station, and a station that has not asked for a test harness
should not be running one.

### 3.1 Assertions do not come back over this channel

The harness asserts on `[LogContact] QSO call=%s qth=%s rst=%d nr=%d points=%d` (`LOGSUBS2.PAS`) and
the other trace lines. **Keep it that way.** Reading state back over the socket to assert on it is
the `WM_GETTEXT` mistake in a new costume — `Test-Typing.ps1` records that reading the Edit back
reported an empty field while the keystrokes were being routed perfectly, because a cross-process
post cannot give the control real focus. A test written against the channel's own view of the world
can pass for the wrong reason; a test written against the engine's log cannot.

`state.*` exists for external clients, not for the harness.

---

## 4. Security — decide this first, not last

A channel that can type into the call field, log a QSO, change band and key the radio is **remote
station control**. TR4W is public GPL software. Three rules, from the first commit:

1. **Off by default.** No listener unless the operator turns it on.
2. **Loopback by default when on.** Following `uWebSocketServer`'s existing stance, not `uWSJTX`'s.
3. **A token on every connection**, checked before the first command is dispatched — not only when
   bound to a non-loopback interface. "It's only loopback" stops being true the moment someone wants
   it from a tablet, which is exactly the motivating use case.

`input.*` needs a **separate** switch from `state.*`/`command.*`. A companion logger app should not
be able to synthesise keystrokes because the operator enabled score sharing.

Retrofitting authentication onto a shipped protocol is how a permanently insecure default happens —
the first client that ships without it becomes the compatibility constraint.

**Open, and it blocks nothing yet:** where the token lives. Password storage in `settings/tr4w.json`
is already an unresolved item (see the config notes in CLAUDE.md); this adds a second caller to that
decision rather than a new problem.

---

## 5. Threading: use `QueueAsyncCall`, not a posted message

Commands arrive on an Indy connection thread and must be applied on the main thread. TR4W has three
mechanisms and the choice is not free.

| mechanism | verdict here |
|---|---|
| `TThread.Queue` | **No.** FPC 3.2.2 stamps every entry with the calling thread's id even when the thread argument is nil (`classes.inc:562`) and `TThread.Destroy` purges by that id (`:603`) — **a thread that queues and then exits deletes its own callback.** A client that sends a command and immediately disconnects is ordinary. |
| `TThread.Synchronize` | **No.** Immune to the purge, but it blocks the connection thread until the main thread runs the method, and stopping the server — on the main thread — waits for those same connection threads. Deadlock, not a trade-off. |
| `PostMessage` to a window | Works, and is what `uTCIServer` does. **But it needs an HWND**, which is the half of this that does not survive the port. |
| `Application.QueueAsyncCall` | **Yes.** Lifetime-independent, non-blocking, no window handle. |

**`QueueAsyncCall` was genuinely unavailable when `uTCIServer` was written and is not any more.**
That unit's header argued against it on the grounds that *"TR4W runs its own GetMessage loop rather
than Application.Run [so] it would never be delivered"* — true then, false since Phase 3c deleted
that loop on 2026-08-23. `uNet.pas` now hands its received bytes to the main thread exactly this
way, and so does `MainUnit`'s deferred startup work. The comment was corrected 2026-09-06; the
posted message stays in `uTCIServer` because re-marshalling live radio control for tidiness buys
nothing, but **new code should not copy it.**

One caution that applies to `QueueAsyncCall` and not to `PostMessage`: it **raises** if `Application`
is gone, which happens on the way out. `uMainForm` already guards for this; the channel must too.

---

## 6. What this retires, and what it does not

**Retires:**

- `SetWindowLong(Result, GWL_ID, aId)` in `uMainForm.CreateTR4WEntryField` — the last reason it
  exists.
- `PostMessage(WM_CHAR)` and the `EnumChildWindows` walk in `UiDriver.psm1`.
- The harness's dependency on the LCL's Win32 class name.

**Does not retire, and must not be read as retiring:**

- The log-based assertions. They get *more* important, not less (§3.1).
- `Find-TR4WMainWindow` for the tests that legitimately inspect windows —
  `Dump-WindowTree.ps1` / `Compare-WindowTree.ps1` exist to compare the window tree against a
  baseline. That is Windows-only by its nature and is fine.
- `/FIELDCHECK`. It is the precedent this design copies (in-process, no window handle, reports
  through an exit code) and it stays as it is.

---

## 7. Phasing

Each phase has an exit criterion that is a thing you can run, not a thing you can read.

**Phase 1 — the shim.** A `TControlServer` over `uWebSocketServer`, `command.ping` only, off by
default, loopback, token-checked, marshalling through `QueueAsyncCall`.
*Exit: a `wscat`-equivalent connects, is refused without a token, and gets a pong with one.*

**Phase 2 — `input.*`.** `input.key` and `input.text` delivered to the focused LCL control, plus
`input.focus` naming a field symbolically (`call`, `exchange`) rather than by id.
*Exit: `Test-Typing.ps1` ported to the channel, passing, asserting on the same
`[CallWindowKeyDownProc]` trace line as today.*

**Phase 3 — the harness moves.** `Test-CountyLineEntry.ps1` ported; both scripts stop calling
`GetDlgCtrlID`.
*Exit: both green, and the `GWL_ID` line deleted from `uMainForm` with no test failing.*

**Phase 4 — `state.*` / `command.*`.** The external-client surface, versioned, separately switched.
*Exit: a client can subscribe to score and band changes without being able to send `input.*`.*

**Phase 1–3 are the ones that pay for the Win32 removal.** Phase 4 is the strategic half and can
follow at its own pace.

---

## 8. Open decisions

These are NY4I's, and this document does not pre-empt them.

1. **Token storage.** Shares a decision with the unresolved password-storage item.
2. **Does `command.*` reach the contest engine directly, or go through the same path the UI uses?**
   Directly is faster and is a second way to log a QSO — a second definition of what logging means,
   which is the drift CLAUDE.md warns about repeatedly. Through the UI path is slower and honest.
   Recommend: through the UI path.
3. **Protocol version policy.** TCI's vocabulary is inherited from someone else's spec; this one is
   ours and needs an explicit compatibility rule before the first external client exists.
4. **Whether `input.*` ships in release builds at all**, or is compiled out. Compiling it out is
   safest and makes the harness need a special build — which is a real cost, because then the thing
   under test is not the thing that ships.

---

## Related

| topic | document |
|---|---|
| The transport's own design | `docs/TCI_SERVER_DESIGN.md` |
| Why the harness asserts on the log | headers of `tr4w/test/ui/Test-Typing.ps1`, `Test-CountyLineEntry.ps1` |
| The in-process precedent | `RunEditQSOFieldCheck` in `src/ui/lcl/uEditQSOForm.pas`, invoked from `src/uProgramMain.pas` |
| Marshalling history | the header comment in `src/uTCIServer.pas` |
