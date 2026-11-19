# Multi-station networking

On macOS, the `.pkg` installs the desktop application only. Obtain `tr4wserver` from the matching `.dmg` or `.tar.gz` when this station will host the network. A client-only station does not need its own server. The main-window status strip now shows the Network condition separately; open the network window for connection details.

TR4W stations connect to TR4WServer to exchange contest activity. This network is separate from a radio's network CAT connection, a DX cluster, and WSJT-X UDP traffic.

## Set up a practice network

1. Choose the server computer and run a compatible TR4WServer build for the clients being tested.
2. On each client, select the same intended contest and configure **SERVER ADDRESS**, **SERVER PORT**, and **SERVER PASSWORD** in the network settings. You caqn also select if you want to use Tailcat for connection to a remote TR4WServer. Please see below for more information on the Tailcat process.
3. Give every station a distinct **COMPUTER ID**. The protocol's station-status display uses station letters; duplicate IDs can confuse status even though transport connections are separate.
4. Make the server's main port and its synchronization port reachable. The conventional main port is `1061`; the synchronization port is **main port + 1**, normally `1062`.
5. Check the Network/Stations displays, log a practice contact, and confirm that the other clients receive the expected contact and station state.
6. Test a disconnect/reconnect and a log mismatch before the event. Preserve each station's test log so you can compare what happened.

Keep each client's database in its own intended location and use the application's network protocol. Do not substitute multiple processes writing one shared SQLite file for TR4W networking.

## When logs differ

The client compares local and server log information. A mismatch can open **Differences in the log**, with **Synchronize**, **Clear all logs**, and **Exit** choices.

Synchronization pulls the server's log; do not assume it merges every unsent local contact. Establish which log is authoritative and preserve local work before replacing it. **Clear all logs** is a destructive action, not a routine fix for a reconnect warning.

[SERVER AUTO SYNCHRONIZE LOG ON CONNECT](../reference/commands/q-s.md#server-auto-synchronize-log-on-connect) can bypass the mismatch dialog when enabled and the contest matches, or when the server has no contest yet. A different contest falls back to the dialog. Enable this only after testing the intended server and synchronization behavior.

## Version compatibility in newer source

**Unreleased source through 48806af1** uses **protocol 2** in both the client and TR4WServer. A HELLO handshake checks protocol compatibility. Delphi 7 / 4.x clients and older 5.x builds without this handshake cannot join. Update the server and every station together; a shared password alone does not make versions compatible.

The handshake carries the registered contest identifier, allowing the newer contests to travel over the multi-op link. Earlier restrictions that excluded new contest identifiers no longer describe this source. Test the actual client/server pair before an event.

## What the protocol does and does not promise

The password and bulk-sync transport are not made encrypted by the protocol-2 handshake. The networking analysis also describes a proposed V2 design for another project; its TLS, Protocol Buffers, and server-authoritative behavior are not features of this TR4W handshake. Use a trusted station network.

Database integrity at one client and agreement between several clients are different properties. Verify both [local log protection](../theory/database.md) and network consistency.

## Tailcat

Tailcat is a technology offered by Tailscale. From Tailscale's website, "Tailcat connects machines over an encrypted connection, even when they’re on different networks. No accounts, login flow, tailnets, or IP addresses. Just share a tailcat address and connect."

For those with some networking exoerience, Tailcat acts similarly to using netcat where one can establish a client/server relationship between two computers. 

You do not need to setup a Tailnet to use Tailcat. All features are built into TR4W and its TR4WServer component.

### How does TR4W use Tailcat

There are several options when it comes to setting up a remote connection. The goal is to allow multiple versions of TR4W to operate in a networked environment to share their log. THis means that each user runs their preferred version of TR4W (WIndows, macOS or Linux) and they can all interoperate with a single TR4W server running at a single location. Thus each remote logger gets the benefit of dupe checking, log backup and other benefits of a remote setup.  The anticipated use case for Tailcat is one where Tom NY4I has at his QTH. 

Tom likes to contest with friends. Tom has a networked Elecraft K4 as well as a networked KPA1500 amplifier, Green Heron Engineering RT-21 rotor controller (with Ethernet control) and an Antenna Genius (also with Ethernet control). 

To allow remote contesting with some members of Tom's radio clubs, he sets up the K4 and other equipment to be accessible to his users via port forwarding (or full-blown Tailscale with a subnet router but that is an differen topic). The remote user with either an Elecraft K4 radio (in client terminal mode), an Elecraft K4/0, KF5O's QK4 software or any of the other remote control solutions available for the K4.  To take the case of QK4, it is setup to connect to Tom's remote DNS name that passes to his K4. TR4W is setup to pass the local network traffic to the Tailcat address on its internal ports (1061 and 1062). 



### Security

TR4W’s remote connection invitation contains a cryptographically random secret, not just a server location. Tailcat uses it to establish an end-to-end encrypted WireGuard connection. Guessing that secret is not computationally practical. However, anyone who obtains the invitation can access the exposed TR4W service unless additional client authorization is enabled, so treat it like a password and share it privately.[Tailcat Read Me](https://raw.githubusercontent.com/tailscale/tailcat/main/README.md)
