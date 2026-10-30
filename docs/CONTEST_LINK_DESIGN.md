# TR4W Contest Link: Cross-Platform Secure Remote Logging

## Status and purpose

This is a proposed architecture and implementation brief, not an existing implementation or a verified description of the current TR4W source tree. The implementing agent must inspect the repository and validate assumptions before changing code.

Build an operator-friendly way to connect remote TR4W instances to a contest station's logging network. Users should select a station and connect, rather than configure VPN routes, subnets, or port forwarding.

Required application platforms: Win64, macOS, and Linux. TR4W is implemented in Free Pascal. Determine the supported CPU architectures and minimum OS versions from the actual build and release configuration; do not assume every architecture listed below is already supported.

Scope is logging-network transport only. Radio control, audio, device access, general LAN access, and interoperability between different logger protocols are out of scope.

## 1. Architectural decision

Use a native Go companion executable containing Tailscale's `tsnet` library. TR4W launches and controls the helper; TR4W retains the operator-facing UI. The helper does not need its own window.

`tsnet` is a Go library, not a standalone application. It embeds a Tailscale node and provides tailnet dialing/listening. We must implement configuration, local forwarding, control IPC, diagnostics, and lifecycle management around it.

Prefer the helper over an in-process Go shared library for the first implementation. This separates Pascal and Go lifecycles, isolates transport crashes, and avoids a C ABI inside the logger. This is a design preference, not a claim that shared libraries are unsupported.

### Data path

```text
Remote operator                                      Contest station

TR4W TCP networking
       |
       | TCP to 127.0.0.1:<allocated-port>
       v
Contest Link helper ===== authenticated, encrypted ===== Station gateway
   Go + tsnet                 tailnet connection               |
                                                               | TCP on station LAN
                                                               v
                                                          TR4WSERVER
                                                               ^
                                                               |
                                                      Local TR4W clients
```

The station gateway is a proposed application service, not a built-in tsnet role. It may use the same Go codebase in a different mode.

Each accepted remote logging connection maps to a separate upstream connection to TR4WSERVER. Do not merge multiple clients into one upstream byte stream.

Local station clients can continue connecting directly to TR4WSERVER. A stable localhost endpoint can eventually support both local and remote paths, but automatic LAN discovery and seamless switching are not part of the initial milestone.

## 2. Why an application gateway rather than a network bridge

The term 'bridge' describes the user experience, not an Ethernet bridge. Do not implement layer-2 bridging, broadcast forwarding, full LAN routing, or an exit node.

Expose a specific authorized logging service rather than the station LAN. The remote logger only needs the local listener address. The station gateway owns the actual LAN destination configuration.

This avoids requiring remote operators to understand station LAN addressing and avoids routing entire overlapping home/station subnets. It does not remove the need for identity, enrollment, access policy, and endpoint authentication.

## 3. Platform and packaging plan

Build native helpers from one Go codebase:

| Platform | Candidate helper target |
| --- | --- |
| Win64 | windows/amd64 |
| macOS Intel, if supported | darwin/amd64 |
| macOS Apple Silicon | darwin/arm64 |
| Linux x86-64 | linux/amd64 |
| Linux ARM64, if supported | linux/arm64 |

Confirm the selected tsnet version, dependencies, build flags, and minimum OS requirements for each target. Do not promise cross-compilation or a no-C-toolchain build until tested.

Package the matching helper with TR4W. Resolve its path relative to the installed application or bundle, not the current working directory or an uncontrolled PATH lookup. Inspect existing platform packaging conventions before selecting locations.

Address executable permissions on Unix, macOS bundle layout/signing/notarization as applicable, Windows signing and console suppression as applicable, and trusted update/version pairing. These are implementation tasks, not completed capabilities.

## 4. Pascal integration

Add a focused Free Pascal unit/class that owns:

- Native helper discovery and launch.
- Child-process pipes and asynchronous reading.
- Version negotiation.
- Sending commands and receiving events.
- Reporting sign-in URLs and status to the UI.
- Supplying the local endpoint to the existing logging TCP client.
- Helper termination, diagnostics, and shutdown.

Suggested conceptual API:

```pascal
type
  TContestLink = class
  public
    procedure Start;
    procedure Connect(const ProfileName: string);
    procedure Disconnect;
    procedure Stop;
  end;
```

This is not drop-in code. Determine the real threading, UI, process, and network abstractions in TR4W first. Keep blocking pipe reads and network operations off the UI thread; marshal events using the project's established mechanism.

Inspect how TR4W currently configures its server address and port. Prefer a runtime endpoint override while connected rather than permanently overwriting user configuration. Preserve and restore the ordinary networking path when Contest Link is disabled.

## 5. Control protocol

Use newline-delimited UTF-8 JSON over child-process standard input/output initially:

- stdin: commands from TR4W.
- stdout: protocol messages only.
- stderr: diagnostic logs, drained concurrently to prevent pipe blockage.
- Local TCP listener: logger bytes only, never control messages.

No local control TCP port is required for this design.

Illustrative messages; finalize a documented schema before implementation:

```json
{"event":"hello","protocolVersion":1,"helperVersion":"0.1.0"}
{"command":"connect","profile":"W1XYZ","requestId":1}
{"event":"authentication_required","url":"<browser sign-in URL>"}
{"event":"listening","address":"127.0.0.1","port":43127}
{"event":"status","transport":"connected","logger":"reachable"}
{"command":"disconnect","requestId":2}
{"command":"shutdown","requestId":3}
```

Required protocol decisions:

- Define request/response correlation, command completion, and asynchronous event ordering.
- Define stable error codes separately from human-readable details.
- Define maximum line size, malformed JSON behavior, unknown command behavior, and timeouts.
- Reject incompatible protocol versions clearly.
- Define whether a listener is created before or after remote readiness; a listening event alone must not imply station connectivity.
- Bind to IPv4 loopback explicitly for the first version; support IPv6 deliberately rather than accidentally.
- Let the OS allocate the local port when practical and communicate the result.
- Do not pass secrets through command-line arguments or log them.

Suggested command set: connect, disconnect, get_status, shutdown. A status event may be pushed on changes, with get_status available for recovery and diagnostics.

## 6. Identity, enrollment, and authorization

Embedding tsnet removes the need to install a separate system-wide Tailscale client for this application. It does not eliminate tailnet membership or administrative policy.

For the first version, use supported tsnet enrollment mechanisms and a station-admin-managed authorization workflow:

1. Administrator authorizes the intended operator/device.
2. Helper starts with a persistent private state directory.
3. If authentication is needed, helper reports the authentication URL.
4. TR4W presents the URL and allows the operator to open a browser.
5. Helper reports actual readiness and access failures.

Do not ship a reusable enrollment key in the executable, configuration template, invitation, or repository. If auth keys are used in controlled provisioning, define their scope, lifetime, storage, and revocation.

Store helper node identity outside the installation directory in an appropriate per-user application state directory. Treat it as sensitive; restrict access and prevent simultaneous helper processes from sharing the same state directory unsafely.

For the MVP, choose and document one tailnet ownership model. Do not silently move a user's existing system-wide Tailscale installation between tailnets. The embedded application's node identity is separate from the host application's ordinary networking identity.

A centrally managed 'enter station invitation code' experience is a later product feature requiring enrollment/backend design. It does not arise automatically from tsnet.

## 7. Gateway security

- Configure a fixed or tightly allowlisted TR4WSERVER destination on the gateway.
- Do not permit clients to request arbitrary destination hosts or ports.
- Apply tailnet access policy to the gateway service.
- Define how operator/device identity is authorized and audited; verify the chosen tsnet identity APIs before designing authorization around them.
- Preserve any existing TR4W application authentication; transport access does not replace it.
- Apply connection/time/resource limits appropriate to the contest deployment.
- Bind the operator-side logger listener only to loopback by default.
- Recognize that loopback binding is not per-process authentication: other local processes may be able to connect. Document the local trust model and consider additional controls if required.
- Protect logs and state; never log credentials, auth keys, or complete sensitive enrollment material.
- Do not expose the raw TR4W logging service directly to the public internet as a shortcut.

## 8. TCP forwarding and failure semantics

Keep the initial data plane byte-transparent.

- One downstream connection to one upstream connection.
- Bidirectional copying with bounded resource use and correct backpressure.
- Preserve half-close behavior where supported and relevant.
- Define dial, idle, and shutdown timeout policies explicitly.
- When transport fails, terminate affected logger connections and report failure. Do not leave TR4W believing a dead stream is healthy.
- Coordinate reconnect ownership with TR4W's existing reconnect logic to prevent duplicate sessions.
- Do not replay buffered logger data over a replacement connection.
- Do not claim that tunnel reconnect proves QSO synchronization or delivery.

Normal socket buffers are expected; application-level offline QSO queuing/replay is out of scope. Any future protocol-aware recovery requires inspection of TR4W acknowledgments and synchronization semantics.

Shutdown should stop new connections, close active streams according to policy, close tsnet, and exit. EOF on the parent's control pipe should trigger cleanup. TR4W should use a bounded shutdown timeout and a platform-appropriate final termination path if the child hangs.

## 9. Operator-facing status

Distinguish at least:

- Helper availability and protocol compatibility.
- Authentication/enrollment required.
- Authorization/access denied.
- Transport initialization/readiness.
- Station gateway reachability.
- Gateway-to-TR4WSERVER reachability.
- Local TR4W TCP connection state.
- Application/network synchronization state only if TR4W can independently establish it.

A green VPN indicator is not proof of functioning logging. Avoid reporting guessed application health as a transport fact. Distinguish idle/no active connection from an actual error.

Provide concise operator text and a more technical diagnostic view. A helper connected to its tailnet is not necessarily connected to the contest station.

## 10. Local operation and future logger support

First release: remote TR4W client to a known TR4WSERVER through the gateway.

Potential later feature: keep the same localhost logger endpoint while the helper selects an explicitly configured LAN or secure remote path. Switching paths will normally require a new TCP connection; do not advertise seamless migration without an implemented application-level strategy.

Other loggers require separate profiles and protocol/topology investigation. TCP transport alone does not establish compatibility. DXLog supports TCP and UDP networking; N1MM deployments may need connections to individual peers. Win-Test support has not been investigated in this brief. Do not assume broadcast discovery, callbacks, embedded addresses, UDP, or peer meshes work through a single TCP forwarder.

Supporting several logger transport profiles does not translate their logging protocols into one another.

## 11. Alternative: shared-library integration

A Go C-ABI wrapper is technically possible. Build with `go build -buildmode=c-shared`; export a small interface using cgo and declare matching Free Pascal functions using `cdecl` and `external`.

Library forms: DLL on Windows, dylib on macOS, SO on Linux. Relevant supported Go targets include Windows AMD64, Darwin AMD64/ARM64, and Linux AMD64/ARM64; verify the current toolchain and selected dependency version before committing.

If selected later:

- Use C-compatible scalars, opaque handles, and UTF-8 buffers.
- Define ownership and allocation explicitly; prefer caller-owned output buffers.
- Do not expose Go/Pascal strings, managed objects, or exceptions across the ABI.
- Prefer status polling or queued events over callbacks into UI code from Go threads.
- Match process/library architecture.
- Establish shutdown/unload safety rather than assuming the Go runtime can be unloaded freely.

This approach is not the MVP recommendation.

## 12. Implementation milestones

### Milestone 0: repository and API investigation

- Inspect TR4W's Free Pascal platform/build configuration.
- Locate networking configuration, client connection, reconnect, and server-authentication code.
- Inspect current TR4WSERVER behavior and concurrency assumptions.
- Determine supported OS/CPU matrix and packaging pipeline.
- Verify tsnet API, persistence, authentication callbacks, identity access, version/license/dependency requirements, and platform support against a pinned version.
- Propose exact files and interfaces before broad refactoring.

### Milestone 1: headless transport proof of concept

- Implement helper and gateway modes.
- Establish independent tsnet identities with persistent state.
- Forward one logger connection end to end.
- Verify multiple independent remote connections.
- Demonstrate failure and reconnect behavior with a real TR4WSERVER.

### Milestone 2: Pascal integration

- Add helper process ownership and asynchronous IPC.
- Add protocol handshake and structured errors.
- Integrate temporary local endpoint selection.
- Present authentication and transport status through existing UI patterns.
- Preserve existing direct networking when disabled.

### Milestone 3: packaging and hardening

- Build/test every supported release target.
- Package and sign according to project/platform requirements.
- Verify state permissions, upgrades, shutdown, and diagnostics.
- Document station-admin provisioning and operator connection workflows separately.

## 13. Acceptance tests

- Existing local TR4W networking remains unchanged when the feature is disabled.
- Remote operator connects without manually installing/configuring a system-wide VPN client or LAN routes.
- First-time sign-in, existing identity, denied authorization, and revoked access have distinct outcomes.
- Two remote operators create two independent upstream server connections.
- Local station clients continue functioning alongside remote clients.
- Gateway destination is restricted; arbitrary LAN forwarding is rejected.
- Helper stdout remains valid protocol output; heavy stderr output cannot deadlock it.
- Missing helper, incompatible version, malformed control message, and occupied port fail clearly.
- Test helper crash, parent exit, gateway restart, server restart, internet loss, sleep/resume, and reconnect.
- No duplicate logger sessions caused by competing reconnect loops.
- No application-level message replay introduced by the helper.
- Test an operator LAN using the same private subnet as the station.
- Test Unicode/spaces in installation and state paths.
- Verify behavior separately on Win64, each supported macOS architecture, and each supported Linux architecture.
- Confirm that UI responsiveness is preserved during sign-in and network timeouts.

## 14. Open decisions

1. Exact supported OS versions and architectures.
2. Tailnet ownership and administrator provisioning model.
3. Whether the gateway runs on the logging server machine or another station host.
4. Gateway authorization and auditing details.
5. Exact control protocol and status state machine.
6. TR4W connection/configuration integration points.
7. Reconnect responsibility and shutdown timeouts.
8. Packaging, updates, and helper integrity/version policy.
9. tsnet version, dependency/license review, and service/account constraints.

Do not resolve these by inventing repository details. Inspect code, prototype, and report findings.

## 15. Reference material

These references support the building blocks; they do not establish that the proposed product is already implemented.

- Tailscale tsnet documentation: https://tailscale.com/docs/features/tsnet
- tsnet Server API: https://tailscale.com/docs/reference/tsnet-server-api
- tsnet Go package: https://pkg.go.dev/tailscale.com/tsnet
- Go build-mode documentation: https://go.dev/src/cmd/go/internal/help/helpdoc.go
- Go platform build-mode support: https://go.dev/src/internal/platform/supported.go
- Free Pascal external functions: https://www.freepascal.org/docs-html/prog/progsu146.html
- Free Pascal cdecl convention: https://www.freepascal.org/docs-html/3.2.0/ref/refsu72.html
- TR4W user manual (historical; verify against current code): https://tr4w.net/TR4W_User_Manual_4.01b.pdf
- TR4W reference manual (historical; verify against current code): https://tr4w.net/TR4W_Reference_Manual_4.01.pdf
- N1MM network status documentation: https://n1mmwp.hamdocs.com/manual-windows/network-status-window/
- DXLog additional information: https://dxlog.net/docs/index.php/Additional_Information
