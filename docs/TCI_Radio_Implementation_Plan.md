# TCI Radio Type — Implementation Plan (Delphi 12 Radio Factory)

**Status: DESIGN ONLY — no code exists yet.** This document specifies how to add a
native **TCI** radio type to the D12 radio factory. It is written for the agent who
will build the driver class. Read `docs/ADDING_A_RADIO.md` first; this document
does not repeat its rules, it applies them.

**Evidence base.** The protocol facts below were read out of the AetherSDR project
(`c:\projects\AetherSDR`), which implements a production TCI **server**
(`src/core/TciProtocol.{h,cpp}`, `src/core/TciServer.{h,cpp}`) that real TCI
clients (WSJT-X, JTDX, SDC/CW Skimmer, RF2K-S amplifiers, Stream Deck plugins) run
against, plus its architecture notes (`docs/architecture/tci-receivers.md`,
`tci-routing-ordering.md`, `tci-discovery.md`) and a minimal Python client
(`plugins/streamcontroller-aethersdr/tci_client.py`). TR4W will be a TCI
**client** — the role opposite AetherSDR — so AetherSDR's server code tells us
exactly what a client receives and what grammar a server accepts. The official
protocol reference is https://github.com/ExpertSDR3/TCI (v2.0). Facts NOT
verified against that spec or against a real ExpertSDR/Thetis are marked
**[VERIFY]** below.

---

## 1. What TCI is, and why a native driver

TCI (Transceiver Control Interface, by Expert Electronics) is a text
command protocol carried over a **WebSocket** connection. Servers include:

- **ExpertSDR2 / ExpertSDR3** (SunSDR radios) — the protocol's origin
- **Thetis** (Apache Labs ANAN)
- **AetherSDR** (FlexRadio front end, port 50001 — verified in its source)
- **SDC**, LAN peripherals (amps, antenna switches), and others

TR4W today reaches TCI radios only through the HamLib bridge:
`uRadioHamLibOnly.pas` registers `EXPERTTCI` → 'Expert TCI (HamLib bridge)',
hamlib model 7. That path works but is polled, read-mostly, and puts hamlib's
DLL between TR4W and a protocol that is natively **push**: a TCI server
broadcasts every state change (frequency, mode, PTT, split, RIT/XIT) the moment
it happens, and accepts CW keying, PTT, and even spot display commands. A native
driver gets:

- event-driven frequency/mode/TX state with **no polling** (like the K4 `AI5;` path)
- CW keying through the radio (`cw_macros` / `cw_macros_stop` / `cw_macros_speed`)
- two-way spot integration: TR4W can **push bandmap spots onto the SDR
  panadapter** (`spot:`) and receive operator **spot clicks** back
  (`clicked_on_spot:` / `rx_clicked_on_spot:`) — tune-by-click from the SDR screen

---

## 2. Protocol summary (what the driver must speak)

### 2.1 Framing

- Transport: WebSocket (RFC 6455) over TCP. **Text frames only** for control.
  Binary frames carry audio/IQ streams — TR4W never starts those and can ignore
  any binary frame.
- Every command is `name:arg1,arg2,...;` or bare `name;`. Command names are
  case-insensitive (AetherSDR lowercases on parse; ExpertSDR docs write them
  uppercase). Args are comma-separated.
- **One WebSocket text message may contain many commands** — AetherSDR sends its
  entire init burst as one string of `;`-terminated commands. The receive path
  must split on `;` and process each, buffering any trailing partial command for
  the next frame.
- GET/SET convention (verified in `TciProtocol::handleCommand`): 0–1 args = GET
  (no args, or receiver index only), 2+ args = SET. A GET is answered to the
  sender; a SET is confirmed by a **broadcast** of the accepted state to all
  clients including the sender. The driver therefore needs no special-case
  "reply" handling: treat every inbound message as a state notification.

### 2.2 Receivers and channels

- Radios are exposed as receivers `trx 0..N-1` (contiguous; `trx_count:N;` in
  the init burst). **Indexes can shift at runtime** when the server's slice
  topology changes (AetherSDR `tci-receivers.md` rule 2) — the driver must
  re-read state from notifications, never cache "my trx is still what it was".
- Each receiver has two channels (`channels_count:2;`): **channel 0 = RX VFO**,
  **channel 1 = TX/split VFO**. This maps directly onto the factory's
  `nrVFOA` / `nrVFOB`.
- Phase 1 scope: **drive receiver 0 only.** A per-radio "TCI RECEIVER" config
  (so Radio 1/Radio 2 could be two receivers of one SDR — SO2R on one box) is a
  deliberate later phase; see §8.

### 2.3 Connect lifecycle (client's view)

On connect the server sends an init burst, in order (verified in
`TciProtocol::generateInitBurst`):

```
vfo_limits:...; if_limits:...; trx_count:N; channels_count:2;
device:<name>; receive_only:false;
modulations_list:usb,lsb,cw,cwr,am,sam,fm,nfm,digu,digl,rtty;
protocol:<name>,<version>;
-- then per receiver --
vfo:<trx>,0,<hz>; vfo:<trx>,1,<hz>; dds:<trx>,<hz>; modulation:<trx>,<mode>;
rx_enable...; rx_filter_band:<trx>,<lo>,<hi>;
rit_enable:<trx>,<bool>; xit_enable:<trx>,<bool>;
rit_offset:<trx>,<hz>; xit_offset:<trx>,<hz>;
split_enable:<trx>,<bool>; lock...; sql...; agc...; DSP flags...; mute...;
tx_enable:<trx>,<bool>;
-- global --
drive:<trx>,<pwr>; tune_drive:<trx>,<pwr>; mic_level:<n>; trx:<trx>,<bool>;
volume:<db>; [active_slice:<trx>,<letter>;   -- AetherSDR extension]
audio/IQ stream parameters...;
ready;
start;
```

So a freshly connected driver is fully seeded — frequency, mode, RIT/XIT, split,
TX state — **before** it sends anything. `ready;` marks end-of-init;
`IsOperational` should be "connected AND ready seen".

**Caution:** `start;` / `stop;` are *device power/on-air state* notifications,
bidirectional. The driver must never send `stop;` — on ExpertSDR that stops the
radio.

### 2.4 Commands TR4W will use

| TCI wire form (client → server)          | Factory method / state                | Notes |
|------------------------------------------|---------------------------------------|-------|
| `vfo:0,0,<hz>;`                           | `SetFrequency(freq, nrVFOA, mode)`    | server echoes accepted freq; a no-op set is still confirmed |
| `vfo:0,1,<hz>;`                           | `SetFrequency(freq, nrVFOB, mode)`    | targets the TX/split VFO |
| `modulation:0,<mode>;`                    | `SetMode`                             | mode strings in §2.5 |
| `trx:0,true[,tci];` / `trx:0,false;`      | `Transmit` / `Receive` (PTT via CAT)  | third arg = audio source tag; send `tci` only if TX audio comes via TCI (TR4W: omit) |
| `split_enable:0,true/false;`              | `Split(splitOn)`                      | set split **before** programming VFO B (JTDX-proven order, §2.6) |
| `rit_enable:0,true/false;`                | `RITOn` / `RITOff`                    | |
| `rit_offset:0,<hz>;`                      | `SetRITFreq`                          | signed Hz |
| `xit_enable:0,...;` / `xit_offset:0,...;` | `XITOn/Off`, `SetXITFreq`             | RIT and XIT are independent in TCI |
| `cw_macros:<text>;`                       | `BufferCW`/`SendCW`                   | grammar varies by server — **[VERIFY]**, see §6 |
| `cw_macros_stop;`                         | `StopCW`                              | the Escape abort |
| `cw_macros_speed:<wpm>;`                  | `SetCWSpeed` — **not sent; `rcCWSpeedSync` withdrawn** | AetherSDR ignores a client set (see §capabilities); range 5..100 |
| `rx_filter_band:0,<lo>,<hi>;`             | `SetFilterHz`                         | low/high edges in Hz relative to carrier |
| `spot:<call>,<mode>,<hz>[,<color>,<text>];` | bandmap push (later phase)          | verified against AetherSDR `cmdSpot` |
| `spot_delete:<call>;` / `spot_clear;`     | bandmap sync (later phase)            | |

Inbound notifications the driver must parse (same spellings, server → client):
`vfo:`, `modulation:`, `trx:`, `split_enable:`, `rit_enable:`, `rit_offset:`,
`xit_enable:`, `xit_offset:`, `tx_enable:` (notification-only — never send it as
a SET; servers ignore it from clients), `cw_macros_speed:`, plus the spot-click
pair `clicked_on_spot:<call>,<hz>;` and
`rx_clicked_on_spot:<trx>,0,<call>,<hz>;` (AetherSDR emits **both** for every
click, back-to-back — dedupe them).

### 2.5 Mode mapping

TCI modulation strings (lowercase on the wire) → `TRadioMode`:

| TCI      | TRadioMode  | | TCI      | TRadioMode |
|----------|-------------|-|----------|------------|
| `cw`     | `rmCW`      | | `digu`   | `rmData`   |
| `cwr`    | `rmCWRev`   | | `digl`   | `rmDataRev`|
| `usb`    | `rmUSB`     | | `rtty`   | `rmFSK`    |
| `lsb`    | `rmLSB`     | | `am`/`sam`| `rmAM`    |
| `fm`/`nfm`| `rmFM`     | | `wfm`, `drm` (ExpertSDR extras) | nearest / **[VERIFY]** |

The init burst's `modulations_list:` tells the driver which strings this server
actually supports — parse it and refuse to send a mode the server did not list
(fall back to `digu`/`digl` for unknown data modes, the same default AetherSDR
uses).

### 2.6 Ordering rules that bit real clients (from AetherSDR's contract doc)

These are server-side battle scars that define the **client sequences known to
work** — follow them rather than inventing new ones:

- **Split:** send `split_enable:0,true;` first, wait for the confirming
  broadcast, then `vfo:0,1,<txHz>;`, then key. (JTDX Rig sequence.) Setting
  VFO B while split is false is also legal (WSJT-X "Rig" mode) — the server
  routes it — but the split-first order is the one every server handles.
- **PTT is not fire-and-forget.** A server may *decline* a key-up
  (`trx:0,false;` comes back — interlock, busy, unresolvable receiver). The
  driver must set `SetTransmitting` **only from the inbound `trx:` broadcast**,
  never optimistically on send. Same for frequency: the echoed `vfo:` carries
  the *accepted* value, which may differ from the requested one.
- **Unkey on disconnect is server-side** (owner-loss cleanup), but the driver's
  `Disconnect` should still send `trx:0,false;` first when it believes it is
  transmitting — belt and braces.
- Do not send `audio_start:` — that requests an audio stream and, per
  AetherSDR's client-identity rule, also *re-binds* which receiver your `trx:0`
  PTT addresses. A control-only client that never declares audio keeps plain
  wire-index addressing, which is what we want.

---

## 3. The transport problem: TR4W has no WebSocket

A repo-wide search confirms nothing in the D12 tree speaks WebSocket. This is
the one genuinely new piece. Options:

**A. Minimal in-house RFC 6455 client over Indy (RECOMMENDED).**
The factory base already uses `TIdTCPClient`; WebSocket-the-client-subset needed
here is small and fully specifiable:

- HTTP/1.1 Upgrade handshake: send `GET / HTTP/1.1`, `Host:`, `Upgrade:
  websocket`, `Connection: Upgrade`, `Sec-WebSocket-Key:` (16 random bytes,
  Base64), `Sec-WebSocket-Version: 13`; validate the `101` response's
  `Sec-WebSocket-Accept` (SHA-1 of key + RFC magic GUID — Indy ships both
  hash and Base64).
- Send path: text frames (opcode 1), FIN set, **client frames MUST be masked**
  (4-byte random mask XORed over the payload). TCI commands are short, so no
  outbound fragmentation.
- Receive path: parse FIN/opcode/len (7-bit, 16-bit, 64-bit forms), server
  frames arrive unmasked. Handle: text (1) → command splitter; ping (9) → reply
  pong (10) with same payload; close (8) → echo close, drop link; binary (2) →
  discard (audio we never asked for); continuation (0) → append (rare for TCI,
  but cheap to support).
- Do **not** negotiate extensions (no permessage-deflate) — absence is the
  client's choice and every TCI server works without it.

This is ~300 lines in one dependency-free unit and matches the project's
lean-dependency stance. It also matches the precedent that transports live in
their own layer, not in drivers.

**B. Third-party WebSocket library** (sgcWebSockets et al.). Rejected:
commercial licensing, a large dependency for one radio type, and nothing else in
TR4W needs WS today.

**C. Stay on the HamLib bridge.** Status quo; forfeits push updates, CW keying,
and spot integration. Keep the bridge entry *alongside* the native driver until
the native one is bench-proven, then let NY4I decide its fate.

---

## 4. Delphi 12 design

### 4.1 Units (one-registration-per-unit rule applied)

| unit | role |
|---|---|
| `src/uWebSocketClient.pas` | `TWebSocketClient` — RFC 6455 client subset over `TIdTCPClient`. **No radio knowledge.** Own reader thread; callbacks: `OnTextMessage(s)`, `OnConnected`, `OnDisconnected`. Lives in `src/`, not `radioFactory/` — it is a transport, reusable (a future TCI keyer/peripheral, per AetherSDR's `_tci._tcp` peripheral ecosystem, would use it too). |
| `src/radioFactory/uRadioTCI.pas` | `TTCIRadio = class(TFactoryRadioBase)` — the protocol driver **and** the single `RegisterRadioById` (like `uRadioKenwoodLAN`; there is no per-model fan-out because TCI *is* the model — the server abstracts the hardware). |

Both listed explicitly in `tr4w.dpr` **and** `test/unit/tr4w_unit_tests.dpr`
(self-registration silently vanishes otherwise — known trap).

### 4.2 How TTCIRadio sits on the base class

The stock `TReadingThread` supports two framings — terminator-delimited strings
and fixed-length binary. WebSocket is neither, and per the factory's own
history, adding a third mode to the shared thread for one driver is the wrong
layer. So `TTCIRadio` **owns its transport** (precedent: `THamLibDirect`,
which also bypasses the base socket):

- override `Connect` / `Disconnect` — create/destroy the `TWebSocketClient`
  against `radioAddress:radioPort`; do **not** start the base reading thread.
- override `SendToRadio(s)` — wrap `s` in a masked text frame. `bAddTermination
  := False` (commands carry their own `;`; a stray CR/LF is exactly the
  TS-890-LAN class of bug).
- `OnTextMessage` splits on `;` (keeping a partial-command remainder buffer) and
  feeds each command to `ProcessMsg` — same threading shape as every other
  radio: state lands via the `ProcessMsg` → base setters path
  (`SetTransmitting`, `SetRITOn`, `SetSplitOn`, VFO record updates,
  `UpdateLastValidResponse`).
- override `GetISConnected` (WS layer up) and `GetIsOperational` (WS up AND
  `ready;` received).
- Reconnect: the base's `MaintainSerialLink` is serial-only; the WS client
  implements its own retry loop using the base's existing constants
  (`RECONNECT_INITIAL_DELAY` / `RECONNECT_MAX_DELAY` /
  `RECONNECT_BACKOFF_MULTIPLIER`) — same observable behavior as every other
  network radio. Liveness: any inbound frame refreshes
  `UpdateLastValidResponse`; send a WS ping if the link has been silent
  longer than ~15 s **[tune on bench]**.

### 4.3 Polling configuration

```pascal
   requiresPolling := False;      // TCI is push -- the K4 AI5 precedent
   pollingInterval := 1000;       // idle tick only; PollRadioState is a no-op
   autoUpdateCommand := '';       // nothing to enable -- push is unconditional
```

`PollRadioState` stays empty. Everything arrives as notifications.

### 4.4 Capabilities (declared in `DefineCapabilities`)

```pascal
   FCapabilities.Flags := [rcReadVFOB,     // vfo:<trx>,1 events
                           rcReadRIT,      // rit/xit enable+offset all readable
                           rcReadSplit,    // split_enable broadcast
                           rcReadTXStatus, // trx:<trx>,<bool> broadcast
                           rcCWByCAT];     // cw_macros / cw_macros_stop
   FCapabilities.CWSpeedMin := 5;          // AetherSDR-verified; ExpertSDR [VERIFY]
   FCapabilities.CWSpeedMax := 100;
```

**`rcCWSpeedSync` is WITHDRAWN as of 2026-08-03** — the command is right, the
server will not honour it. Ten PgUp/PgDn presses sent ten `cw_macros_speed:NN;`
and got ten `cw_macros_speed:30` back (`tr4w.log`, 03:52:02–10). AetherSDR
`src/core/TciProtocol.cpp:454` decides set-versus-get by argument count
(`isSet = args.size() >= 2`), which assumes every command is receiver-addressed;
`cw_macros_speed` is a **global taking one argument**, so a correctly-formed set
reads as a get and the handler returns the current speed. Unreachable for any
client. See AetherSDR #1677 (closed with this exact acceptance criterion never
wire-tested) and #1764 (same root cause, fix applied only to `volume`).

Withdrawn for **all** TCI servers, not just AetherSDR: TR4W cannot tell which
server it is connected to, so the honest blanket answer beats a guess. Restore
by putting `rcCWSpeedSync` back in the set — `SetCWSpeed` is already correct and
needs no change.

No `rcSharedRITXITOffset` — TCI carries `rit_offset` and `xit_offset` as
separate values (project rule says assume shared without evidence; here the
wire grammar IS the evidence of independence, but confirm once on a real
ExpertSDR before relying on it **[VERIFY]**).

`CWIsFactoryOwned` must return `True` — otherwise `StopSendingCW` never
delegates and Escape cannot abort CW (the K3 bench lesson, 2026-07-31).

### 4.5 Registration

```pascal
initialization
   RegisterRadioById('TCI',
      function: TFactoryRadioBase begin Result := TTCIRadio.Create end,
      'TCI (ExpertSDR / Thetis / AetherSDR)', [rlNetwork], 50001, False,
      SerialParams(0, 0, PARITY_NONE, 0)   // network-only; serial row unused
   );
```

- **String id, not the `EXPERTTCI` enum** — the enum stays bound to the HamLib
  bridge registration until the native driver is bench-proven; two entries,
  two distinct display names (duplicate display names hide a model — hard rule).
- Default port 50001 is AetherSDR's (verified). ExpertSDR2 is believed to
  default to 40001 and Thetis differs again **[VERIFY both]** — the operator
  sets the port in the dialog regardless, so the default only seeds the field.
- `discoverable = False`: per AetherSDR's discovery contract, `_tci._tcp` mDNS
  is for *peripherals*; TCI **radios** do not advertise themselves. Do not ship
  a Discover button with nothing behind it (the pre-implementation Flex flag
  mistake).

---

## 5. Failure modes to design for

- **Declined PTT.** `trx:0,true;` answered by `trx:0,false;` (interlock/busy).
  State must come from the broadcast, so TR4W's TX indicator simply never turns
  on. Log it at INFO with the reason context we have (none on the wire — say so).
- **Receiver index shift mid-contest.** Server topology changes re-number trx.
  Phase 1 pins trx 0, which always exists (`trx_count >= 1` guaranteed by
  AetherSDR; assume same elsewhere **[VERIFY]**). Notifications for trx <> 0 are
  ignored, not errors.
- **Init burst before `ready;`** — cache-as-you-go; the burst is syntactically
  identical to live notifications, so no special pre-ready parser state is
  needed (verified: WSJT-X parses every command on arrival and uses `ready`
  only for its own init state machine).
- **Command echoed with a different value** than requested (server clamped or
  refused). The VFO record must track the echo. Never re-send in a loop on
  mismatch — that is how client/server tune fights start.
- **Half-open TCP.** The serial world's lesson (`MaintainSerialLink`: an open
  port is not a working link) applies: silence past the liveness window means
  close and reconnect with backoff, not wait.
- **Unknown commands** arrive constantly (volume, AGC, IQ config, vendor
  extensions like `active_slice:`). Ignore them silently at DEBUG log level —
  a TCI client that aborts on unknown names is a known anti-pattern (the
  eesdr-tci parser bug class).

---

## 6. Open questions for the implementer (resolve before or during bench)

1. **`cw_macros` argument grammar.** AetherSDR treats the *entire* arg list as
   message text (`args.join(',')` — no leading trx). The ExpertSDR3 spec may
   define `cw_macros:<trx>,<text>;` and the contest-oriented
   `cw_msg:<before>,<callsign>,<after>;` triple. **This is the highest-risk
   compatibility point in the whole driver** — test the exact form against each
   target server; a wrong guess keys "0,TEST" in Morse.
2. **CW speed range and prosign handling** per server (AetherSDR: 5..100 wpm).
3. **Default ports:** ExpertSDR2/3, Thetis (50001 verified for AetherSDR only).
4. **`vfo_limits` vs `longint` frequency fields** — factory frequencies are
   32-bit; fine to 2.1 GHz, so ignore unless a 10 GHz transverter setup appears.
5. **Does ExpertSDR confirm no-op tunes?** AetherSDR guarantees it (a WSJT-X
   timeout fix). If a server does not, the driver must not wait on an echo for
   a frequency it knows is already set.
6. Whether NY4I wants the HamLib `EXPERTTCI` entry retired once this is proven.

---

## 7. Testing

- **Unit (`test/unit/`):** instantiate `TTCIRadio` with a captured-send seam
  (the WS client behind an interface or a virtual `SendToRadio`, so tests
  assert exact wire strings: `SetFrequency(14025000, nrVFOA, rmCW)` →
  `vfo:0,0,14025000;`). Feed canned notification strings (including a full
  AetherSDR init burst, multi-command-per-message) into `ProcessMsg` and assert
  the VFO records, capabilities behavior, and the partial-command buffer.
  Paired-opposite rule applies: assert `tx_enable:` inbound updates state AND
  that the driver never *sends* one.
- **`TWebSocketClient` unit tests:** handshake accept-key computation, frame
  encode/decode round-trips for the 7/16/64-bit length forms, mask correctness,
  ping→pong.
- **Integration:** `tools/radiosim` does not speak WebSocket. The natural bench
  server is **AetherSDR itself on port 50001** (or Thetis) — which is also the
  real deployment target. Remember: a sim/server disagreement indicts the
  server model only for that server; ExpertSDR remains the reference
  implementation for the protocol.
- Mark the unit header **NOT BENCH-VALIDATED** until run against a real
  ExpertSDR or Thetis, with the §6 items as the tester's checklist.

---

## 8. Phasing

| phase | scope |
|---|---|
| **1** | `uWebSocketClient` + `TTCIRadio`: connect/ready, frequency + mode + split + RIT/XIT + PTT on receiver 0, capabilities, registration, unit tests. |
| **2** | CW keying (`cw_macros*`), wired per the CW Keyer Factory plan (`docs/CW_Keyer_Factory_Plan.md`) — CW is its own domain; the driver exposes the wire commands, the keyer factory decides when they are used. |
| **3** | Spot push (`spot:` from the bandmap) and spot-click receive (`clicked_on_spot:` → tune/entry populate). |
| **4** | Per-radio receiver selection (`trx` <> 0) — SO2R on one SDR — plus multi-rx notifications. Needs a config command; park the design with the CFG rewrite backlog rather than inventing an ini key now. |
