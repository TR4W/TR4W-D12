# Icom LAN: cross-check against rigplane-core

**This is a COMPARISON, not a plan.** It sets TR4W's Icom network transport beside an
independent third-party implementation of the same protocol and records where the two
disagree. Nothing here is a decision to change code, and no change was made.

**Why it is worth reading.** `docs/RADIO_BENCH_STATUS.md` lists Icom LAN as UNPROVEN — our
implementation has never been contradicted by a radio. A divergence from an implementation
that demonstrably works is therefore a *hypothesis about why ours might not*, and the bench
section below turns each one into a test.

## Provenance and licence

| | |
|---|---|
| Their tree | `C:\Users\toms\projects\rigplane-core` (Sergey Morozik, KN4KYD) |
| Their licence | **MIT** (`LICENSE`, line 1) — permissive; no copyleft reach into this tree |
| Their page | `docs/internals/protocol.md`, published at `rigplane.dev/internals/protocol/` |
| Their own upstream | both implementations trace the protocol to **wfview** (GPLv3). Ours cites wfview in code comments; theirs cites it at `docs/internals/protocol.md:235`. **Neither is independent of wfview**, which weakens "two implementations agree" as evidence — it may only mean both read the same source |

**Only protocol FACTS are taken across** — offsets, endianness, timers, ordering. No code was
copied and no routine was paraphrased into Pascal. Every claim below cites a file and line on
both sides so it can be checked.

## What we agree on

Worth stating, because it narrows where to look. Byte-for-byte agreement on:

- the fixed 16-byte header, all five fields little-endian (theirs `src/rigplane/core/protocol.py:14`;
  ours `tr4w/src/uIcomNetworkTypes.pas:139-145`)
- packet type numbers 0x00/0x01/0x03/0x04/0x05/0x06/0x07 (theirs `docs/internals/protocol.md:26-32`;
  ours `uIcomNetworkTypes.pas:45-51`)
- the credential substitution table, all 128 bytes, and the `ord(ch)+i`, wrap at 126 rule
  (theirs `src/rigplane/core/auth.py:23-243`; ours `uIcomNetworkTypes.pas:398-437`)
- the login packet at 0x80 bytes with big-endian payload size, `requestreply`=0x01,
  `requesttype`=0x00, big-endian inner sequence, credentials at 0x40/0x50, client name at 0x60
  (theirs `core/auth.py:270-289`; ours `uIcomNetworkTypes.pas:180-203`)
- the status packet: error LE at 0x30, disconnect flag at 0x40, **CI-V port big-endian at 0x42**
  (theirs `core/auth.py:421-424`; ours `uIcomNetworkTypes.pas:279-283`)
- the CI-V data wrapper: 0x15-byte header, 0xC1 marker at 0x10, **frame length little-endian at
  0x11**, **inner send sequence big-endian at 0x13** (theirs
  `src/rigplane/runtime/_civ_rx.py:3714-3729`; ours `uIcomNetworkTransport.pas:554-563`)
- the OpenClose packet at 0x16 bytes, 0x01C0 at 0x10, magic 0x04 open / 0x00 close
  (theirs `runtime/_control_phase.py:42`; ours `uIcomNetworkTypes.pas:171-178`)
- ping period 500 ms (theirs `core/transport.py:38`; ours `uIcomNetworkTypes.pas:67`)
- ports 50001 control, 50002 CI-V, 50003 audio, with CI-V and audio **negotiated** in the status
  packet (theirs `docs/internals/protocol.md:36-42`; ours `uIcomNetworkTypes.pas:39-40`)

## The divergences, ranked by what they would cost an operator

### D1 — We never ping the CI-V socket. They ping both.

**Them:** after the CI-V transport connects they start ping, retransmit and idle loops **on that
transport** (`runtime/_control_phase.py:404-406` — `h._civ_transport.start_ping_loop()`,
`start_retransmit_loop()`, `start_idle_loop()`). Their page states the consequence plainly:
*"Pings are sent every 500ms. The radio drops connections that stop pinging."*
(`docs/internals/protocol.md:194`).

**Us:** `TIcomNetworkTransport.SendPing` addresses `FControlSocket` / `FControlPort` and nothing
else (`tr4w/src/uIcomNetworkTransport.pas:1403-1425`). There is one ping timer
(`ICOM_TIMER_PING`) and one idle timer, and `SendIdlePacket` carries a comment saying idle is sent
on **the control socket only** (`uIcomNetworkTransport.pas:1659`). Nothing this program sends is
ever addressed to the CI-V port except CI-V data and the OpenClose packet.

**Why it might matter.** If the radio applies its "stopped pinging" rule per session-socket, our
CI-V stream is unkept whenever the operator is not actively polling. **Confidence: medium-high
that this is a real divergence; medium that it breaks anything**, because our CI-V watchdog
partly hides it — `OnCivWatchdogTimer` re-sends CivOpen after 2 s of CI-V silence
(`uIcomNetworkTransport.pas:1907-1921`), which would keep re-establishing a stream the radio keeps
dropping. That predicts a *specific* symptom rather than a dead radio: periodic
`CI-V data timeout … sending CivOpen` lines in `tr4w.log` during quiet spells, with control
apparently fine.

**What would settle it:** a `tr4w.log` at DEBUG through a 10-minute idle stretch. If those
watchdog lines repeat on a cadence, D1 is live. A capture would show it beyond doubt: pings
flowing to 50001 and none to the CI-V port.

### D2 — A radio reporting CI-V port 0 is a REFUSAL there, and a silent fallback here.

**Them:** `civ_port == 0` is treated as *the radio did not allocate a session*. They re-send
conninfo up to three times with a 10-second pause, and if it still returns 0 they fail with an
explicit message naming the error code and suggesting a previous session is still held
(`runtime/_control_phase.py:323-355`, `_STATUS_RETRY_PAUSE = 10.0` at line 95). Their page gives
the usual cause: *"The client must echo the radio's GUID … Otherwise, the status packet will
report CI-V port = 0."* (`docs/internals/protocol.md:133`).

**Us:** `HandleStatusPacket` reads the port and, if it is zero, substitutes the default 50002 and
carries on (`uIcomNetworkTransport.pas:1245-1249`). Nothing is logged at warning level.

**Why it might matter.** This is the shape CLAUDE.md calls out — *prefer a reported error over a
silent fallback*. The failure it masks is the one an operator hits after a crash or a second
client: the radio still holds the old session, refuses a new one, and we connect to 50002 anyway
and then look broken for a reason the log does not name. **Confidence: high that the behaviours
differ. I do not know which is right on a real radio** — it is conceivable some model reports 0
and still serves 50002.

**What would settle it:** connect, kill TR4W without a clean disconnect, reconnect within a
minute. If the second connect produces a running program with no CI-V traffic, D2 is the
explanation and D3 is probably the cause.

### D3 — `FGUID` is never assigned.

**Us:** `FGUID` is declared at `uIcomNetworkTransport.pas:127` and **read at line 1564** — in
`SendStreamRequest`, for the non-MAC branch — and it is written nowhere in the unit. A grep of
that file returns exactly two hits, the declaration and the read. So a radio whose capabilities
entry does not advertise `CommonCap and $8010` receives an all-zero GUID in our conninfo.

**Them:** the GUID is an explicit parameter of their conninfo builder and, when supplied, is
copied into 0x20–0x2F *instead of* the commoncap/MAC pair (`core/auth.py:346-350`).

**Why it might matter.** Their doc (`docs/internals/protocol.md:133`) says the client must echo
the radio's GUID and names CI-V port 0 as the symptom. Our MAC branch is populated properly
(`uIcomNetworkTransport.pas:1554-1560`), so this only bites radios that use the GUID path.
**Confidence: high that the field is unpopulated — that is a plain read of the code. Which radios
take that branch, I could not determine**, because it depends on a `CommonCap` value that only a
radio can tell us. Our log prints it: `Radio: %s, CI-V address=$%.2x, CommonCap=$%.4x`
(`uIcomNetworkTransport.pas:1196`).

**What would settle it:** the `CommonCap=` value from that log line, for each LAN radio. Anything
other than `$8010` puts that model on the GUID path, and D3 becomes a live defect for it.

### D4 — We never ask for a retransmission. We only answer requests for one.

**Them:** every received data packet's sequence is recorded, gaps are computed in uint16 space,
missing sequences are collected, and a background loop sends retransmit requests every 100 ms,
giving up after four attempts (`core/transport.py:504-536` for gap detection,
`core/transport.py:793-808` for the loop). They cap a gap at 50 before declaring a reset
(`MAX_MISSING`, `core/transport.py:44`).

**Us:** `HandleRetransmitRequest` serves the radio's requests from our TX buffer
(`uIcomNetworkTransport.pas:2107-2180`), and that is the whole of it. There is no inbound
sequence tracking — no `rx_last_seq` equivalent exists in the unit.
`ICOM_TIMER_RETRANSMIT` and `ICOM_RETRANSMIT_CHECK_INTERVAL` are **declared and never used**
(`uIcomNetworkTypes.pas:70, 104`), which reads as an intent that was not finished.

**Why it might matter.** On a wired LAN, probably nothing: UDP loss is rare and a lost CI-V
response just becomes a poll that returns nothing, retried 500 ms later. On WiFi it is the
difference between a momentary glitch and a dropped reply that nothing ever recovers.
**Confidence: high that the capability is absent; low that it is visible on a good network.**

**What would settle it:** run a LAN radio over WiFi with the radio at the edge of usable signal
and watch for stuck or stale readings.

### D5 — Dead-link detection only arms if the radio pings us first.

**Us:** `OnPingTimer` declares the link lost after `ICOM_PING_DEAD_TIMEOUT_MS` (3 s) without an
inbound ping — **but only when `FLastPingReceived <> 0`** (`uIcomNetworkTransport.pas:1878-1886`),
and that field is set only when a ping *request* arrives from the radio
(`uIcomNetworkTransport.pas:1079`). A radio that answers our pings but never initiates one leaves
the detector permanently disarmed.

**Them:** they do not use inbound pings for liveness at all; their watchdog is on the CI-V data
path (`runtime/_civ_rx.py:642` onward).

**Two internal inconsistencies worth noting while you are here**, neither of which is a
divergence from them: `ICOM_PING_DEAD_TIMEOUT_MS`'s own comment says *"Radio sends pings every
100 ms"* (`uIcomNetworkTypes.pas:74`) while our `ICOM_PING_INTERVAL` and their doc both say 500 ms
— so the "30 missed pings is unambiguous" reasoning in that comment is off by 5x. And
`uIcomNetworkTypes.pas:163` documents `TDataPacket.DataLen` as *"big-endian!"* while the code
correctly writes it little-endian (`uIcomNetworkTransport.pas:561`) and matches theirs. **Both are
comment defects, not code defects** — flagged because a future reader will trust them.

**Confidence: high on the gating logic; unknown whether any Icom actually initiates pings.**

**What would settle it:** power the radio off mid-session. If TR4W notices within ~3 s, the
detector is armed on that model. If it sits there indefinitely, it is not.

### D6 — Conninfo audio fields: we ask for a control-only session; they ask for audio.

Side by side, at the same offsets:

| field | ours (`uIcomNetworkTransport.pas:1580-1596`) | theirs (`core/auth.py:358-367`) |
|---|---|---|
| rxenable 0x70 | 1 | 1 |
| txenable 0x71 | 0 | 1 |
| rx codec 0x72 | 0x04 | 0x04 default |
| rx sample 0x74 | 8000 | 48000 |
| civ local port 0x7C | our bound port | caller's |
| audio local port 0x80 | 0 | caller's |
| tx buffer 0x84 | 0 | 150 |

Ours is deliberate — TR4W is a logger and wants no audio. **This is a divergence I would normally
leave alone**, except for one thing they found: a radio can **reject the whole session** over the
codec field, returning error `0xFFFFFFFF`, and single-RX firmware is named — *"Single-RX firmwares
(IC-7300/IC-705, possibly IC-9700) may reject stereo rx_codec at conninfo"*
(`runtime/_control_phase.py:272-276`). Our combination — `rxenable=1` with `audio port = 0` and an
8 kHz rate — is not one they exercise.

**Confidence: low that this is wrong. It is a candidate**, and it is cheap to check because our
`HandleStatusPacket` already logs and disconnects on `Error = $FFFFFFFF`
(`uIcomNetworkTransport.pas:1236-1242`).

**What would settle it:** if a particular model refuses to connect while others succeed, look for
`Stream request failed (error=$FFFFFFFF)` in `tr4w.log`. That line points here.

### D7 — We disambiguate auth packets by datagram LENGTH, and we know radios pad.

**Us:** on the control socket, a type-0x00 packet is routed by its received length — 0x40 token,
0x50 status, 0x60 login response (`uIcomNetworkTransport.pas:926-937`). Directly above it, our own
comment records that *"Icom radios pad 16-byte control packets to 18 bytes (2 trailing zeros), so
exact length matching fails"* (`uIcomNetworkTransport.pas:897-899`).

**Them:** they route on the `requesttype` byte at 0x15 and parse with `>=` length guards rather
than equality (`core/auth.py:384`, `core/auth.py:418`).

**Why it might matter.** If the padding the comment describes ever applies to the larger auth
packets, our status packet arrives as 82 bytes, misses the `0x50` arm, falls through to the
capabilities arm and is silently mis-parsed. **Confidence: low — this is a hazard, not an observed
failure**, and it would be invisible except as "the connect hangs after login".

**What would settle it:** a capture of the connect handshake. It answers this question outright.

## Capability gaps, both directions

**They have, we do not:**

- inbound sequence-gap detection and retransmit requests (D4)
- a conninfo busy-retry with a cooldown, and a real error when the radio refuses (D2)
- **reconnect without re-discovery** — they cache `remote_id` and `my_id` and skip
  Are-You-There, explicitly because *"radio may reject login from a new sender_id while previous
  session is still cached"* (`core/transport.py:236-283`). Ours always starts from Are-You-There
  and always derives a fresh `FMyId` from the newly-bound socket port
  (`uIcomNetworkTransport.pas:454`). **That is a plausible mechanism for "it will not reconnect
  after a crash until I power-cycle the radio"**, and it is testable today.
- a bounded receive queue with priority shedding under load (`core/transport.py:636-700`) — ours
  dispatches synchronously on the Indy read thread
- audio, scope/panadapter streaming, Opus

**We have, they do not (or do differently):**

- the CI-V data watchdog that re-opens a stale stream after 2 s
  (`uIcomNetworkTransport.pas:1907-1921`) — theirs has a data watchdog too, but escalates on a
  60-second deadline (`runtime/_civ_rx.py:1363`)
- explicit token **renewal** every 60 s with a dedicated request type 0x05
  (`uIcomNetworkTypes.pas:96`, `uIcomNetworkTransport.pas:1502`); theirs has the same 60-second
  interval (`runtime/_control_phase.py:80`)
- a login retry timer, 5 s × 6, for the stale-session case (`uIcomNetworkTypes.pas:111-112`)
- exponential backoff on Are-You-There, 500 ms doubling to 5 s over 10 tries
  (`uIcomNetworkTypes.pas:77-79`); theirs is a flat 1 s × 10 (`core/transport.py:40-41`)

**Audio, in one line, as asked:** their audio shares the session and the conninfo negotiation but
runs on its own port and its own transport instance with its own sequence space
(`runtime/_control_phase.py:1000-1006`). **It does not constrain the control path**, and nothing
in it needs to come into TR4W.

## What I could not determine

- **Whether any Icom actually initiates pings toward the client.** D5's gating depends on it and
  only a capture or a log answers it.
- **Which of the eleven LAN models take the GUID branch rather than the MAC branch** (D3). The
  `CommonCap=` log line answers it per radio.
- **Whether the radio enforces keepalive per socket or per session** (D1). This is the crux of the
  highest-ranked divergence and neither codebase states it; wfview's behaviour is the best
  available evidence and both of us claim to follow it.
- **Whether our control-only conninfo values are accepted by every model** (D6).

## The bench checklist

See the handback, and `docs/RADIO_BENCH_STATUS.md` for where the results go.
