# TCI mock radio

A standalone mock **server** for testing TCI clients, with a line-oriented terminal interface. No TR4W, QK4 or AetherSDR application needs to run, and no physical radio is connected. Everything, including PTT and CW, is simulated.

## Run on Windows

From the repository root:

~~~powershell
python -m pip install -r tools/tcimock/requirements.txt
python tools/tcimock
~~~

Python 3.11 or later. The only external dependency is websockets (tested with 17.0.1); it provides bounded RFC 6455 framing, fragment assembly, ping/pong and close handling. It is already installed on NY4I's machine. There is no Qt build or dependency on the other repositories.

The default endpoint is **ws://127.0.0.1:50011/**, deliberately different from the real TR4W TCI server's usual 50001. Configure TR4W's radio provider as TCI, address 127.0.0.1 and port 50011. If running it in a worktree, the complete command is:

~~~powershell
python C:\tr4w-d12\.worktrees\tci-mock\tools\tcimock
~~~

Other options:

~~~powershell
python tools/tcimock --port 50012 --trace
python tools/tcimock --no-console
~~~

Host defaults to loopback. Use --host explicitly for testing a client on another computer; this test server has no authentication. Ctrl+C or quit stops the process and closes its client connections. --no-console does not read stdin and runs until interrupted.

## Terminal controls

Commands are line-oriented: type one, then Enter. These change the radio at the server, so every connected client sees the same state.

| Command | Effect |
| --- | --- |
| status | Both receivers, VFOs, modes, offsets, TX state, client and stream counters |
| clients | Also show endpoints and subscriptions |
| freq 0 14030000 | Tune receiver 0 VFO A; frequencies are integer Hz |
| freq 0 14035000 B | Tune receiver 0 VFO B |
| mode 1 LSB | Change receiver 1's mode |
| split 0 on | Enable split on receiver 0 |
| rit 0 100 | Enable RIT and set +100 Hz |
| xit 0 -200 | Enable XIT and set -200 Hz independently |
| ptt 0 on / ptt 0 off | Simulate local transmit/receive |
| speed 30 | Set CW speed in WPM |
| spectrum 0 | Print a small ASCII preview of the synthetic spectrum |
| trace on / trace off | Show/hide incoming text commands |
| drop | Disconnect all clients; listener remains up for reconnect testing |
| raw rit_enable:0,false; | Apply a supported state command locally |
| help / quit | Show commands / stop |

Receivers are numbered 0 and 1. They start on 14.025 MHz and 7.025 MHz, with independent VFO A/B, mode, filter and RIT/XIT values. There is one simulated transmitter: a client cannot unkey another client's or the local operator's PTT. Disconnecting the owning client releases PTT. CW macros print their text and simulate a TX interval; this is not a Morse audio decoder/keyer.

## Spectrum, waterfall and audio

Standard TCI carries **IQ samples**, from which a capable client can compute its spectrum/waterfall. There is no standard pre-rendered spectrum command in the referenced TCI 2.0 contract. This tool supplies:

- **iq_start:0; / iq_stop:0;**: interleaved float32 I/Q, 48 kHz, type 0, channels 2.
- **spectrum_event:on; / spectrum_event:off;**: AetherSDR's optional spectrum extension, type 4, float32 dBm bins, channels 1. Both receivers are delivered, tagged by receiver ID. Header reserved words 0/1 carry the lower/upper RF frequencies in Hz, matching AetherSDR's implementation.
- **audio_start:0; / audio_stop:0;**: a synthetic 700 Hz stereo RX tone, type 1. Simulated client PTT also sends header-only type-3 TX_CHRONO requests. Incoming TX audio is discarded; there is no hardware output.

All binary frames have the 64-byte, little-endian TCI header. Header length is the number of float values, not bytes or I/Q pairs. Sample format is float32 and rate is fixed at 48000; negotiation queries/requests return these actual values. Other formats/rates are not implemented.

The IQ scene has a noise floor and four fixed-frequency carriers per receiver. Tuning moves them relative to the receiver's center; continuous phase is maintained between IQ blocks. Spectrum rows use a matching synthetic scene at about 10 rows/second. Signal generation only runs while subscribed; frames are shared between clients, not regenerated for each client. ASCII preview does not require a subscription.

**TR4W's current TCI radio driver does not subscribe to audio or IQ.** Therefore this mock does not automatically populate TR4W's existing Elecraft/Icom spectrum window. Use a TCI IQ-capable client, an AetherSDR-spectrum-extension client, or the terminal preview to examine the dummy spectrum. Adding TCI spectrum reception to TR4W is separate work.

This is signal generation, not a realistic RF/propagation or FT8/CW-QSO generator. It can prove client behavior against a controlled peer; it cannot prove compatibility with a real transceiver.

## Architecture and limits

- radio.py reuses tools/radiosim/core.py's RadioState and adds the TCI-specific per-receiver fields; one model owns GET replies, initial state and state-change notifications.
- server.py uses one asyncio event loop for model, subscribers and sockets. No shared-state locks or real-radio transports. Text commands may span WebSocket messages or several may occur in one message.
- Each client has one writer and a bounded 128-entry output queue. Stream frames are dropped once that queue reaches eight entries. A saturated text queue or timed-out writer disconnects only that client. The server supports eight clients, 64 KiB inbound messages, an 8 KiB unfinished text-command limit and bounded unknown-command diagnostics.
- PTT ownership is separate from display state. Shutdown/disconnect unkeys the simulated owner, and CW stop cannot cancel another client's transmit.
- Control support: VFO/DDS, mode, filters, split, RIT/XIT enables/offsets, drive, AGC mode, lock, receiver enable, PTT, CW speed/macros/abort. Invalid/unsupported commands are ignored and logged once by command/error category. Sensor subscribe requests receive a fixed test reading; periodic meters, spots, recording and full TCI command coverage are not implemented.
- The standard initialization burst precedes start; ready is last. Stream subscriptions are never primed by the greeting. Device identifies itself as TR4W-TCI-MOCK.

QK4's snapshot server and test cases were the initial reference. Directly wrapping that Qt server was considered, but it currently has no IQ output and would require another repository and a compiled Qt runtime. The standalone Python version uses the existing TR4W state model, with protocol behavior checked independently against QK4/AetherSDR sources and TR4W's raw WebSocket test client. Neither other repository is modified or vendored.

Sources: [Expert Electronics TCI](https://github.com/ExpertSDR3/TCI), QK4 src/network/tciserver*.cpp and tciradiostate.h, AetherSDR src/core/TciServer.cpp (onIqDataReady, buildAudioFrame and onWaterfallRowReady), and [websockets asyncio server](https://websockets.readthedocs.io/en/stable/reference/asyncio/server.html).

## Tests

~~~powershell
python -m unittest discover -s tools/tcimock -p test_mock.py -v
~~~

Only this tool's targeted suite is run: isolated loopback sockets on OS-assigned ports, no existing applications, station settings, user logs or physical radios. Tests cover initial ordering, shared updates, split commands across frames/messages, invalid input, PTT ownership/disconnect, CW completion/abort, opt-in IQ/spectrum/audio, binary headers and synthetic signal peaks, idle generation and bounded slow-client queues. An independent wire test uses the existing tools/tciclient.py framing rather than the websockets client library.

## Validation record

November 7, 2026, Windows / Python 3.12 / websockets 17.0.1: 13 targeted tests passed. The interactive subprocess smoke test covered status, tuning, mode, RIT, ASCII spectrum and clean exit. The two-receiver IQ pacing fixture received 18 and 17 blocks in about 0.36 seconds with zero late ticks; CPU measurements included the debug-mode test client and are not a standalone-server performance guarantee. No TR4W application test suite or hardware test was run. IQ and spectrum-extension interoperability still need a real third-party display client; the wire shape is tested against the documented/referenced header and the signals against an independent tone-power calculation.
