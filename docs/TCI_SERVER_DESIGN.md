# TCI Server for TR4W

## Context

TR4W already owns the serial/network link to the radio, and only one program can hold a COM port.
So external programs (WSJT-X and friends) have to get radio data *through* TR4W. Today that is done
by `uWSJTX.pas`, which stands up a `TIdTCPServer` on port 52002 and impersonates **DXLab Commander**
(`<Tag:Len>Value` ADIF-ish framing, `IdTCPServer1Execute` at `tr4w/src/uWSJTX.pas:1040-1390`). It
works, but it is a single-client, protocol-by-accident bridge with a documented lie in it — the
`KLUDGESECONDSV` block (`uWSJTX.pas:1073-1080, 117`) reports *commanded* TX state for 2 seconds
because WSJT-X drops the link if a PTT command is not reflected within ~1 s and TR4W only learns TX
state on the next poll.

TCI is the better shape for exactly this job: a published protocol, multi-client, with a
state-change broadcast model instead of polling. TR4W already speaks it as a **client**
(`tr4w/src/radioFactory/uRadioTCI.pas`, 874 lines, over `tr4w/src/uWebSocketClient.pas`, 640 lines),
and `c:\projects\AetherSDR` is a working reference **server** we can read for the contract.

**Intended outcome:** TR4W offers a TCI server so any TCI client can connect and drive whatever radio
TR4W is controlling — including rigs (Icom, Yaesu, Kenwood…) that have no TCI of their own.

### Decisions taken (NY4I, this session)

| | |
|---|---|
| **Coexistence** | New listener **alongside** the uWSJTX Commander server. Nothing in `uWSJTX.pas` is deleted. Retiring it is a later, separate decision. |
| **Receiver mapping** | `trx 0` = Radio1, `trx 1` = Radio2. `trx_count` reflects how many radios are configured. Split is expressed the clean way — `split_enable:<trx>,<b>` + `vfo:<trx>,1,<hz>` — **not** AetherSDR's second-receiver-with-`tx_enable` idiom. |
| **Audio / IQ** | **Out of scope.** Text frames only. TR4W bridges a rig and has no audio to offer; clients keep their soundcard. `audio_*`/`iq_*` are acknowledged per the contract but no binary frame is ever emitted. |
| **Framing** | Extract a **shared** RFC 6455 unit used by both client and server. |

---

## Design

### Unit layout

```
uWebSocketFraming.pas   NEW  RFC 6455 frame encode/decode + handshake digest. Role-aware. No sockets.
uWebSocketClient.pas    MOD  keeps its TIdTCPClient + reader thread; framing now comes from above.
uWebSocketServer.pas    NEW  TIdTCPServer + per-connection WS session. No TCI knowledge.
uTCIProtocol.pas        NEW  TCI grammar: tokenize "name:a,b;" and format replies. Pure, no sockets.
uTCIServer.pas          NEW  TTCIServer: init burst, GET/SET dispatch, broadcast, radio snapshot.
```

The seam that already exists in the client is the one to keep: transport moves opaque strings,
grammar lives above it. `uWebSocketClient` reaches the driver through `OnTextMessage` /
`SendText`; the server side mirrors that with `OnTextMessage(session, text)` / `session.SendText`.

**Do not** try to share the *dispatch tables* between client and server — client dispatch
(`uRadioTCI.DispatchCommand`, :435-636) consumes notifications; server dispatch answers requests.
Only the tokenizer and the formatters are genuinely common.

### `uWebSocketFraming.pas` — what moves

From `uWebSocketClient.pas`: `SendFrame` (:454-522), the reader's header decode (`Execute`
:166-233), `HandleFrame`'s fragment reassembly (:558-635), `BuildAcceptKey` (:255-267), the opcode
constants and `WS_MAGIC_GUID` (:120-131).

Three things must become role-aware rather than hard-coded, because the current unit is client-only:

1. **Masking on send.** `SendFrame` unconditionally sets the mask bit and XORs
   (`uWebSocketClient.pas:463-464, 478, 500-509`). RFC 6455 **forbids a server masking**. Encode
   takes a role.
2. **Masking on receive.** The reader treats any masked inbound frame as a fatal violation
   (`Execute` :206-212) and there is no unmask path anywhere in the unit. A server must *require*
   masking and unmask.
3. **The handshake.** `DoHandshake` (:269-331) is the client half only — generate nonce, verify
   `101` + `Sec-WebSocket-Accept`. The server needs a request parser and a 101 generator.
   `BuildAcceptKey` itself is direction-symmetric and reused verbatim.

Shape the API as free functions over `TBytes` plus a small `TWSDecoder` state object for
fragment reassembly, so it is testable with no socket at all. That matters: **today none of the
framing is tested** — there is no `uTestWebSocket.pas`.

### `uWebSocketServer.pas`

- `TIdTCPServer`, one `TIdContext` per client (Indy owns the accept and per-connection threads —
  same as `uWSJTX` does today, no new threading primitive).
- `TWSSession` per connection: handshake state, decoder, send lock, and the client's declared
  identity (`audio_start:<n>`, see below).
- Hardening, mirroring AetherSDR's limits (`TciServer.cpp:41-42, 685-699`):
  - **Bind loopback (127.0.0.1) by default**, with an explicit opt-in to bind all interfaces.
    The Commander server binds all interfaces unconditionally (`uWSJTX.pas:288-302`); we should not
    repeat that. These clients are local.
  - Max 8 concurrent clients; 64 KiB cap on message *and* frame.
  - No path check and **no subprotocol negotiation** — AetherSDR accepts any URL path and negotiates
    none. Clients rely on that.

### Radio state — superseded by the seqlock (2026-08-09)

**This section's premise was fixed elsewhere before the server was built.** The plan assumed
`RadioStatusRecord` had no synchronisation of any kind, and proposed a private `TTCIRadioSnapshot`
plus a lock to work around that. In the meantime a **seqlock** landed in `LOGRADIO.PAS`
(`BeginStatusPublish` / `EndStatusPublish` / `ReadStatusSnapshot`, :784-822, :2978-3035), and the
poll loop now brackets its whole update — the `CurrentStatus` fill *and* the `FilteredStatus` copy —
between them (`uRadioPolling.pas`, "THE BATCH BOUNDARY").

So the private snapshot was **not built**, and would have been a second, worse copy of a mechanism
the program already has. What was built instead:

- `ReadRadioStatus(rig)` is called directly from the Indy connection threads. It is a seqlock read:
  safe from any thread, and it never stalls the poller.
- One new observer hook, `RadioStatusPublished`, declared in `uRadioPolling.pas` beside the existing
  `RadioStatusTrace` and called **after** `EndStatusPublish` — outside the odd/even window, so the
  observer's read is coherent on its first attempt instead of spinning its retry budget.
- `TTCIServer` keeps only **what it last told clients**, per radio, under one critical section, and
  diffs against it so a broadcast means something actually moved. Single writer per radio, so the
  diff is race-free without holding the lock across a send.

### Radio control — the apply path

Client threads must not call the legacy façade directly. `RadioObject.SetRadioFreq`
(`LOGRADIO.PAS:277/2730`) also writes globals (`tCommandedQSYFreq`, the Issue #795 auto-S&P hook)
and the `uWSJTX` paths call `QuickDisplay` off-thread.

Marshal instead: `TThread.Queue` a small apply closure onto the main thread, which then calls
`SetRadioFreq` / `SetMode` / `PutRadioIntoSplit` / `PutRadioOutOfSplit` / `tPTTVIACAT`
(`LOGRADIO.PAS:277, 260-261, 751/2835`). `TThread.Queue` is **proven working** in this program — the
main loop's fall-through `DispatchMessage` drains it (established during the FMX coexistence bench).

**PTT confirmation, and the death of the kludge.** TCI's contract is that the *server* confirms:
reply `trx:<n>,true;` immediately from commanded state, then let the next publish broadcast the truth
if the radio disagrees. That is principled, unlike `KLUDGESECONDSV` — a client that watches the
broadcast learns the real state instead of being told a timed lie. Note `tPTTVIACAT` bails unless
`tPTTViaCommand` is set (the Ctrl-J option); `uWSJTX` force-enables it at :1217-1229 and the TCI
server must decide the same explicitly rather than failing silently.

### Protocol contract to honor

Init burst on connect, one command per text frame, in this order (from
`AetherSDR/src/core/TciProtocol.cpp:212-421`), pruned to what a control-only bridge can truthfully
claim:

```
vfo_limits:<lo>,<hi>;  if_limits:<lo>,<hi>;  trx_count:<N>;  channels_count:2;
device:TR4W;  receive_only:false;  modulations_list:<...>;  protocol:ExpertSDR3,1.5;
   -- then per trx: vfo:<t>,0,<hz>; vfo:<t>,1,<hz>; modulation:<t>,<m>; rx_enable:<t>,true;
      rx_filter_band; rit_enable; xit_enable; rit_offset; xit_offset; split_enable; tx_enable
   -- then: drive; tune_drive; trx:<t>,false;
ready;
start;
```

Grammar: `name[:arg1,arg2,...];`, **input lowercased**, output always lowercase, args split on `,`
and trimmed, no escaping. Unknown or refused command → **silence**, with the one exception that a
refused `trx:<n>,true` must answer `trx:<n>,false;` (a silent refusal shows in WSJT-X as
"TCI failed to set ptt" with no cause).

Minimum viable command set: `vfo`, `modulation`, `trx`, `tune`, `drive`, `tune_drive`,
`split_enable`, `rx_filter_band`, `rit_enable`/`xit_enable`, `rit_offset`/`xit_offset`,
`cw_macros_speed`, `cw_msg`, `dds`, `start`/`stop`, plus echo-only handling of
`audio_start`/`audio_stop`, `iq_start`/`iq_stop`, `audio_samplerate`, `audio_stream_*`,
`rx_sensors_enable`/`tx_sensors_enable`.

**Gotchas taken straight from AetherSDR's scars — build these in from day one:**

1. **Arity per command, never one global `isSet` rule.** AetherSDR's `isSet = args.size() >= 2`
   (`TciProtocol.cpp:455`) makes every legitimately single-argument SET unreachable —
   `cw_macros_speed:20` is answered as a GET, live today, untested. Each command declares its own
   GET/SET arity.
2. **`drive`/`tune_drive` replies must always carry `<trx>,<power>`.** A bare `drive:0;` crashes
   ESDR3-mode WSJT-X/JTDX, which index `args[1]` unconditionally.
3. **`channels_count` is plural.** The published PDF says `CHANNEL_COUNT`; the reference `eesdr-tci`
   parser aborts the handshake on the singular form.
4. **`ready;` last, after everything.** SDC / CW Skimmer latch cached settings the instant `ready`
   arrives. And **never** emit `audio_start`/`iq_start` in the greeting — those are client-owned and
   a greeting-side primer wedged SDC.
5. **The `vfo:` confirmation must echo the frequency actually reached, not the requested one**
   (AetherSDR #4500/#4493 — WSJT-X's `do_frequency()` waits on that echo and transmitted out of band
   when it went stale). A refused or no-op tune must still be confirmed, with what the model holds —
   never met with silence.
6. **Range-check the `vfo` channel.** `vfo:0,2,...` produces no request at all.
7. **Inbound `tx_enable` is notification-only** — it must mutate nothing and reply nothing.
8. **`split_enable:<t>,false` is not an edge.** WSJT-X Improved 3.1.0 sends a steady `false` before
   programming channel 1; only a true→false *transition* should tear anything down.
9. **PTT must never guess a receiver.** `trx:<n>` addresses radio *n*; if it is not configured,
   decline with `trx:<n>,false;`. Do not fall back to radio 0.
10. **Sanitize at the wire boundary.** Any value containing `;` or `,` corrupts framing for every
    client on the socket. Ours are numeric/enum today — enforce it centrally in `uTCIProtocol` so it
    stays true.
11. **Disconnect fails closed.** Losing the client that owns a TCI PTT session unkeys. An *unowned*
    `trx:<n>,false` reports actual state and must never unkey the operator or another client.
    Unlike `uWSJTX`'s log-only connect/disconnect stubs (:1392-1403), per-session state is released.

### Configuration

New keys in `uCFG.pas` `CommandsArray` (near the existing WSJT-X block, :887-890):
`TCI SERVER ENABLED` (default false), `TCI SERVER PORT` (default 50001 — the TCI convention),
`TCI SERVER BIND ALL` (default false).

Avoid the `uWSJTX` trap: its `WSJTXRadioControlEnabled` is read **only in the constructor**
(:214-222) so the enable key needs a program restart to take effect. Create the `TTCIServer` object
unconditionally at startup and let `Start`/`Stop` be genuinely runtime-toggleable.

Per `CLAUDE.md`, this goes in `CommandsArray` for now — the whole ini is slated for a rewrite, so do
not invent a new config mechanism here.

---

## Files

**New:** `tr4w/src/uWebSocketFraming.pas`, `tr4w/src/uWebSocketServer.pas`,
`tr4w/src/uTCIProtocol.pas`, `tr4w/src/uTCIServer.pas`,
`tr4w/test/unit/uTestWebSocketFraming.pas`, `uTestTCIProtocol.pas`, `uTestTCIServer.pas`,
`docs/TCI_SERVER_DESIGN.md`.

**Modified:** `tr4w/src/uWebSocketClient.pas` (framing delegated out),
`tr4w/src/radioFactory/uRadioTCI.pas` (adopt the shared tokenizer only — leave `DispatchCommand`'s
dispatch alone), `tr4w/src/uRadioPolling.pas` (one `PublishRadioState` call),
`tr4w/src/uCFG.pas` (3 keys), `tr4w/tr4w.dpr` (unit list + create/start/stop, near the existing
wsjtx wiring at :897-900 / :1141-1143), `tr4w/test/unit/tr4w_unit_tests.dpr` (unit list),
`CLAUDE.md` (documentation map row).

**Untouched:** `tr4w/src/uWSJTX.pas`. `src/trdos/` beyond nothing at all.

---

## Phases

Each phase builds green and is committable on its own.

**0 — Framing extraction.** Create `uWebSocketFraming.pas`, repoint `uWebSocketClient.pas` at it,
add `uTestWebSocketFraming.pas` (accept-key vector from RFC 6455 §1.3, all three length forms,
masked and unmasked round-trip both roles, fragment reassembly, control-frame interleave, oversize
rejection). Behaviour-neutral for the client. **Regression check: the existing TCI client still
drives AetherSDR.**

**1 — WebSocket server transport.** `uWebSocketServer.pas`: Indy listener, handshake request parse
+ 101 response, per-session decode, unmask, PING/PONG, CLOSE, limits, loopback binding.
Test: point our own `uWebSocketClient` at our own `uWebSocketServer` over loopback and round-trip
text. That single test exercises both halves of the extracted framing.

**2 — Snapshot + publish.** `TTCIRadioSnapshot`, the lock, the diff, and the one call site in
`uRadioPolling.pas`. Testable against a fake radio with no socket involved.

**3 — TCI grammar and server.** `uTCIProtocol.pas` + `uTCIServer.pas`: init burst, per-command
arity table, GET/SET dispatch, `TThread.Queue` apply path, broadcast on publish-diff, per-session
PTT ownership. Tests assert the init-burst *ordering* invariants (§4 above) and every numbered
gotcha, table-driven.

**4 — Wiring and docs.** `uCFG` keys, `tr4w.dpr` lifecycle, `docs/TCI_SERVER_DESIGN.md`, CLAUDE.md
doc-map row.

**5 — Bench.** Not provable by code review; see verification.

---

## Verification

**Unit** — `cd tr4w\test\unit && msbuild tr4w_unit_tests.dproj /t:Make /p:Config=Debug
/p:Platform=Win32 && tr4w_unit_tests.exe`. Baseline is 2021 tests / 0 failures (`55f4f5ed`); the new
suites add to it. The loopback client↔server round-trip lives here.

**Corpus** — the contest engine is untouched, but run it anyway before committing since
`uRadioPolling.pas` and `tr4w.dpr` are edited. **Full `/t:Build` first** (a `/t:Make` exe has
produced phantom corpus failures), confirm no `tr4w.exe` is running, then
`bash tr4w/test/corpus/export-d12-corpus.sh`. Expect `22 passed, 0 failed, 4 known-divergence`.
Read the result, **then** commit — never chain them in one shell block.

**Lints** — `Lint-PascalBeginEnd.ps1`, `Lint-PCharAnsi.ps1`, `Lint-LineEndings.ps1`. New files must
be **CRLF**; the Write tool emits LF, so check every file created.

**Loopback integration** — TR4W's own `TTCIRadio` client connecting to TR4W's own TCI server is the
strongest cheap test available: it exercises the real grammar in both directions against an
independently-written peer. Worth a scripted run in `tr4w/test/integration/`.

**Bench (the real gate)** — none of the following is provable by review:
1. A real TCI client (WSJT-X / JTDX with the TCI rig backend) connects, reads frequency and mode,
   sets frequency, and keys and unkeys PTT against a live rig on trx 0.
2. Confirm PTT round-trip latency is inside the client's timeout **without** any Commander-style
   kludge.
3. Split: `split_enable:0,true` + `vfo:0,1,<hz>` moves VFO B on a real radio, and the steady
   `split_enable:0,false` WSJT-X sends beforehand destroys nothing.
4. Two clients at once — one's SET broadcasts to the other.
5. Kill a client mid-transmission; verify it unkeys and the session is released.
6. SO2R: a client on `trx 1` keeps addressing Radio2 across a TR4W radio swap.

Record results in `docs/RADIO_BENCH_STATUS.md` alongside the existing TCI client row (:87).

---

## Risks

- **Highest: the client population is the spec.** The AetherSDR notes above are a catalogue of ways
  real clients misbehave when a server is technically correct. Phase 5 is the gate, not phase 4.
- **`tPTTViaCommand` interaction.** Force-enabling it (as `uWSJTX` does) changes keying behaviour
  for the operator, not just the client. Decide explicitly and log it; do not silently flip it.
- **Two servers, one radio.** With the Commander server also enabled, two clients can fight over
  frequency and PTT. Out of scope to arbitrate, but worth a warning in the log when both are on.
- **`uWebSocketClient` regression.** The framing extraction touches working, bench-proven code. This
  is why phase 0 is standalone, tested, and re-verified against AetherSDR before anything is built
  on top.

---

## Build status (2026-08-09, branch `tci-server`)

Phases 0-4 are **built, green and committed**. Phase 5 (bench) is the remaining gate.

| Phase | State | Notes |
|---|---|---|
| 0 — framing extraction | done | `uWebSocketFraming.pas`, role-aware; 4 GiB-length defect fixed on the way |
| 1 — WS server transport | done | `uWebSocketServer.pas`; per-session sender thread so a wedged client cannot stall the poller |
| 2 — publish hook | done | superseded by the seqlock; one `RadioStatusPublished` hook, no private snapshot |
| 3 — grammar + server | done | `uTCIProtocol.pas`, `uTCIServer.pas`; per-command arity table |
| 4 — wiring | done | Preferences check box, not a `CommandsArray` key — see below |
| 5 — bench | **owed** | nothing below the wire level is provable by review |

**Configuration moved.** The plan proposed `TCI SERVER ENABLED` / `PORT` / `BIND ALL` keys in
`uCFG.CommandsArray`. NY4I directed it onto the **new Preferences system** instead: the Hardware tab,
under "Connect radios at startup", labelled **"Enable TCI radio server"**. It is stored in the radio
config library (`TRadioConfigStore.TCIServerEnabled`, JSON key `tciServer`, ini key `TCIServer`) and
published to the program at startup as `RadioLibraryTCIServerEnabled`. Port and bind-all are not
exposed: the port is the TCI convention (50001) and the binding is loopback, deliberately.

**Divergences from the reference server, all deliberate, all tested:**

1. **Arity is per command, not a global `argc >= 2` rule.** AetherSDR's global rule makes every
   one-argument SET unreachable — `cw_macros_speed:20;` is answered as a GET — and it has three
   commands special-cased at the dispatch site because of it. `TCI_SPECS` is a table.
2. **`vfo_limits` / `if_limits` answer the same values they announce.** The reference drifted into
   two different sets.
3. **An unknown modulation is refused, not coerced to USB.** The reference's coercion puts a radio
   in a mode nobody asked for, silently.
4. **A non-boolean argument is refused.** The reference reads anything that is not `true` as false,
   so `split_enable:0,yes` silently turns split off and `trx:0,yes` silently unkeys.

**One bug the tests caught during construction**, worth keeping in mind for anything added later:
`TCIMsg` scrubs `,` and `;` out of every argument, which is correct for a value and wrong for the two
identity strings that are legitimately comma-bearing — `modulations_list` *is* a comma-separated
list, and `ExpertSDR3,1.5` is a two-field value. Scrubbing produced `protocol:expertsdr3_1.5;`, which
is exactly the string WSJT-X fails to match before it halves transmit amplitude. Those two use
`TCIMsgFreeText`, and `Test_CommaBearingIdentityValuesNeedFreeText` pins both directions.

**Not implemented, and the server says so by staying silent:** `cw_msg` and `cw_macros_speed` SETs
are logged and dropped (sending CW from a network client while the operator is running a contest
interleaves with the keyer and the interlock — a decision, not a detail), and RIT/XIT offset and
`rx_filter_band` SETs are accepted into silence because the factory exposes no setter for them that
is safe to drive from a network client mid-contest.

Baselines at the last commit on this branch: **3572 unit tests, 0 failures**; corpus
**22 passed, 0 failed, 4 known-divergence**; all lints clean.
