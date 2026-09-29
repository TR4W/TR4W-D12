# Multi-station networking

TR4W stations connect to TR4WServer to exchange contest activity. This network is separate from a radio's network CAT connection, a DX cluster, and WSJT-X UDP traffic.

## Set up a practice network

1. Choose the server computer and run a compatible TR4WServer build for the clients being tested.
2. On each client, select the same intended contest and configure **SERVER ADDRESS**, **SERVER PORT**, and **SERVER PASSWORD** in the network settings.
3. Give every station a distinct **COMPUTER ID**. The protocol's station-status display uses station letters; duplicate IDs can confuse status even though transport connections are separate.
4. Make the server's main port and its synchronization port reachable. The conventional main port is `1061`; the synchronization port is **main port + 1**, normally `1062`.
5. Check the Network/Stations displays, log a practice contact, and confirm that the other clients receive the expected contact and station state.
6. Test a disconnect/reconnect and a log mismatch before the event. Preserve each station's test log so you can compare what happened.

Keep each client's database in its own intended location and use the application's network protocol. Do not substitute multiple processes writing one shared SQLite file for TR4W networking.

## When logs differ

The client compares local and server log information. A mismatch can open **Differences in the log**, with **Synchronize**, **Clear all logs**, and **Exit** choices.

Synchronization pulls the server's log; do not assume it merges every unsent local contact. Establish which log is authoritative and preserve local work before replacing it. **Clear all logs** is a destructive action, not a routine fix for a reconnect warning.

[SERVER AUTO SYNCHRONIZE LOG ON CONNECT](../reference/commands/q-s.md#server-auto-synchronize-log-on-connect) can bypass the mismatch dialog when enabled and the contest matches, or when the server has no contest yet. A different contest falls back to the dialog. Enable this only after testing the intended server and synchronization behavior.

## What the protocol does and does not promise

The current networking analysis describes a legacy protocol with a plaintext password and a separate bulk-sync connection. It also contains a proposed V2 protocol for another project; TLS, Protocol Buffers, and that proposal's server-authoritative behavior are not promises of this TR4W build. Use the station network accordingly rather than treating the legacy password as encrypted transport.

Database integrity at one client and agreement between several clients are different properties. Verify both [local log protection](../theory/database.md) and network consistency.

## Evidence and review status

Current synchronization decision: `uNet.pas`, including the contest guard around automatic synchronization. Form labels: `ui/lcl/uLogCompareForm.lfm`. Network settings: `ui/lcl/uPrefsForm.pas`. Networking analysis and corrections (`docs/TR4W_NETWORKING_ANALYSIS.md`) explains the protocol's history and separates it from the unimplemented V2 proposal.

No multi-computer or mixed-version test was run for this documentation update. Compatibility, reconnect recovery, and synchronization should be verified with the actual release pair before a contest.
