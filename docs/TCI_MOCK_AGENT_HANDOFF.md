# TCI mock radio: TR4W agent handoff

November 8, 2026. NY4I has run the tool and reports that it appears to work. Use it as a controlled TCI peer for client development and build-time regression tests. It is a mock **server**, not a client, and never connects to a physical transmitter.

## Location and status

The implementation is **tools/tcimock/**, developed on branch **codex/tci-mock** in C:/tr4w-d12/.worktrees/tci-mock. NY4I authorized integration into main. After that merge, use the normal repository path C:/tr4w-d12/tools/tcimock, not the worktree path. This handoff does not install a build gate: the integration stages below are recommendations, not existing CI behavior.

[Tool README](../tools/tcimock/README.md) is the operating/architecture reference. Keep its command/protocol details there rather than maintaining a second copy here.

The final implementation is standalone Python, not the initially considered Qt wrapper around QK4. It reuses TR4W's existing radiosim RadioState. QK4's snapshot-based server and AetherSDR's TCI framing/spectrum extension supplied references; neither repository is required at runtime or modified.

## Run and connect

From the repository root:

~~~powershell
python -m pip install -r tools/tcimock/requirements.txt
python tools/tcimock
~~~

Python 3.11+, with websockets >=15,<18; developed and tested with Python 3.12 and websockets 17.0.1 on Windows. For unattended execution, add --no-console. For protocol diagnostics, add --trace.

The default listener is **ws://127.0.0.1:50011/**, distinct from TR4W's own TCI server's usual port 50001. In a disposable TR4W configuration, select the **TCI radio provider/client**, address **127.0.0.1**, port **50011**. Enabling TR4W's TCI server is not how to connect to the mock: that would start another server.

The tool's console accepts status, clients, freq/mode/split/rit/xit/ptt/speed, spectrum, drop, trace and quit. Frequencies are integer Hz. Examples:

~~~text
freq 0 14030000
mode 0 USB
split 0 on
rit 0 100
ptt 0 on
ptt 0 off
drop
~~~

Both receivers expose VFO A/B, mode, filters, independent RIT/XIT and a shared simulated transmitter. Console edits represent radio/front-panel changes and are broadcast to connected clients. Client SETs update the same state and are broadcast too. Initial state ends with start; then ready; no stream is enabled just by connecting.

## Existing validation: what is actually proved

Run the isolated suite:

~~~powershell
python -m unittest discover -s tools/tcimock -p test_mock.py -v
~~~

Thirteen tests passed on November 7, 2026. They use only loopback listeners on OS-assigned ports, and do not run the full application test suite or change station settings/logs. Coverage includes:

- Initialization ordering and shared state across multiple clients.
- Commands split across WebSocket messages/frames, and invalid commands followed by valid ones.
- Receiver/offset independence, PTT ownership and unkey on owner disconnect.
- CW completion/abort, audio and TX_CHRONO header shape.
- Opt-in IQ and spectrum subscriptions, binary header dimensions and finite samples.
- A synthetic IQ peak checked by an independent tone-power calculation.
- Idle generation, bounded queues and sustained two-receiver streaming.
- A real socket exchange with the existing **tools/tciclient.py** implementation, independent of the websockets client library.

The interactive subprocess smoke test exercised status, tuning, mode, RIT, ASCII spectrum and clean exit. NY4I subsequently confirmed basic operation manually. No third-party spectrum-display interoperability or real-radio conformance is implied by those results.

**Crucial distinction:** the Python suite does not instantiate TR4W's Pascal TTCIRadio. The existing uTestRadioTCI suite overrides SendToRadio and tests emitted commands without transport. Neither test by itself proves that a newly built TR4W driver connects to this mock, receives broadcasts, or updates application state. Build integration should add that missing boundary.

## Recommended build/test integration

### Stage 1: small independent Python gate

Run the command above after relevant tool/protocol changes, and in a separate CI job with the declared dependency installed. Keep it outside ordinary compiler-only builds and unrelated full-suite runs. A dependency failure must say that the mock tests did not run; do not count a skip as a pass.

Pin the dependency in the CI environment if reproducibility requires it. The tool declares a supported version range; its recorded passing version is 17.0.1.

### Stage 2: exercise the compiled Pascal TCI client

Add an opt-in integration harness around the real TTCIRadio transport. Reuse the repository's existing FPC build/toolchain helpers; do not copy their compiler paths or flags into a new build script. Inspect the driver and current application initialization before deciding what the harness must initialize.

Use assertions on the actual driver's reported state and connection lifecycle, not only on its emitted text or the mock's own state:

| Scenario | Required observation |
| --- | --- |
| Connect | Actual client receives initial state and becomes operational after ready |
| Client tunes or changes mode | Mock accepts SET; confirmation returns to the actual driver |
| Mock changes frequency/mode | Actual driver updates without issuing a matching SET first |
| Split and VFO B | Correct reported split/transmit frequency and no receiver-axis confusion |
| RIT/XIT | Enables and offsets remain independent in client state |
| CW speed/macros/abort | Commands reach mock and expected simulated status returns; no RF-timing claim |
| Simulated transmit/receive | Actual client follows state; no physical radio/keyer is opened |
| Link loss and reconnect | Client reports loss and recovers under its documented reconnect behavior |
| A second client edits state | Changes are broadcast to the client under test |
| Malformed input | No crash, unbounded wait or corruption of the next valid command |

Use a small number of precise cases first. The point is to cover the real socket/driver boundary, not replicate every existing model test against a fake.

### Process and test-data isolation

- Prefer constructing MockServer and awaiting start(port=0) in a Python test fixture, as the existing suite does. It returns the actual bound port. Pass that port to the driver harness rather than reserving a fixed global port.
- If a separate process is needed, use --no-console --port 0, capture the announced endpoint with a bounded startup timeout, retain the exact process handle and close only that process in a finally block. No process-name-wide kills. On Windows launch any background helper hidden.
- Do not run concurrent test suites against one shared mock. Each fixture owns its radio state, listener, clients and cleanup. Do not connect the harness to an already running operator session merely because it finds a TCI port.
- Use disposable configuration and contest directories. Never activate the operator's normal radio profile, use real COM ports, modify their logs, or overwrite station settings to point at localhost.
- Bound connect, receive, ready and shutdown waits. Collect useful transcripts/counters on failure. Quiet idle operation should not continuously log polling or generate samples.
- Do not start a full TR4W test suite alongside another agent's testing without coordination: a prior worktree test run in this session interfered with testing outside the worktree. The mock's isolated Python suite is not evidence that the application suite is isolated.

## Spectrum and audio: exact scope

The mock sends fixed-rate **48 kHz float32** IQ (standard TCI type 0), with noise and four synthetic fixed-frequency carriers. A client capable of IQ reception can compute a spectrum/waterfall. It also supports AetherSDR's **spectrum_event:on** extension (binary type 4) for synthetic dBm rows, and a simple 700 Hz RX audio tone. These are synthetic test signals, not decodable contest traffic.

**TR4W's current TCI driver does not subscribe to IQ/audio and discards binary data.** Starting this mock does not populate TR4W's existing Elecraft/Icom spectrum window. Receiving TCI IQ or the optional spectrum extension is separate application work. Until then, use a capable third-party client or the console's spectrum preview. Do not label a nonempty synthetic plot as proof that TR4W's TCI spectrum path works.

The sample rate, sample format, stream header and extension provenance are documented in the tool README. Not implemented: realistic propagation, full TCI command coverage, real RF/PTT, exact CW keying timing, real FT8/CW exchanges, spots, recording and full sensor telemetry. The mock must not become the sole authority for protocol details: compare the specification and captures from real servers when mock and client agree but hardware disagrees.

## Code map and ownership

| File | Responsibility |
| --- | --- |
| tools/tcimock/__main__.py | CLI, daemon stdin reader and terminal controls |
| tools/tcimock/radio.py | Radio model, initial burst, validation, GET/SET replies |
| tools/tcimock/server.py | WebSocket sessions, broadcasts, ownership, bounded queues, stream scheduling |
| tools/tcimock/signals.py | Synthetic IQ/spectrum scene and binary frame construction |
| tools/tcimock/test_mock.py | Targeted model and loopback tests |
| tools/radiosim/core.py | Existing shared RadioState reused by the mock |
| tools/tciclient.py | Independent client/framing used by a wire test |

All network/model updates execute on one asyncio event loop. The console thread only queues input to that loop. Each peer has one sender, bounded queues and private subscriptions. Samples are generated only while needed and shared between interested clients. Preserve these properties when adding scripted scenarios: no real-radio connection, unbounded transcript, per-client generator duplication or busy idle polling.

## Next agent's starting point

1. Confirm that tools/tcimock is present in the checkout after merge, then read its README.
2. Run its short isolated suite. Do not assume NY4I's machine has installed a dependency on a different runner.
3. Add the real-client integration seam in an isolated worktree, with disposable configuration and explicit timeouts.
4. Make the gate opt-in until process/config isolation is demonstrated on the relevant platforms; then decide which builds should require it.
5. Keep physical-radio bench checks. A useful mock reduces repetitive bench work; it cannot certify a hardware driver.
