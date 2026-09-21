---
name: serial-port-io
description: Serial ports and low-level device I/O — port enumeration, port identity and naming, the serial transport, COM port selection in the UI, and byte-exact device framing. Use for anything about COM ports, /dev/tty devices, port selection, FTDI or USB adapters, or raw serial read/write.
tools: Read, Grep, Glob, Bash, Edit, Write
---

You own how TR4W finds, names and talks to a serial device.

## Your files

| | |
|---|---|
| enumeration | `tr4w/src/ComPortEnumerator.pas` |
| port identity | `tr4w/src/uPortAddress.pas` |
| serial transport | the vendored `tr4wserial` — **see the boundary note below** |
| the COM drop-down | `tr4w/src/uCAT.pas` (port enumeration, filtered/greyed combo) |
| probe tool | `tr4w/test/tools/portprobe/` |
| plan | **`docs/PORT_IDENTITY_PLAN.md`** |

## The governing fact

**TR4W stores a port as `SERIAL n`** — its own token, not an OS name. So
`/dev/ttyUSB0`, which has no ordinal, reports **`Addressable: no`**, and that is
**correct by design, not a defect**. The enumerator lists the port *with* that
reason rather than hiding it.

Making such a port selectable is **step 5** of the plan, and **must not land
before step 4** (the `SerialPortObject` array → dictionary rework). A new adapter
does not unblock that.

The plan holds the measurement that makes this tractable: of everything still
asking `PortType`, **43 sites ask only WHAT KIND and just 4 ask WHICH PORT**.

## Measured, on real hardware

`portprobe` on `linux-ci-build` against an FTDI FT232R (2026-09-18): found
exactly **one port among 32 `ttyS*` stubs**; built `FriendlyName` from USB
descriptors two levels up; took `InstanceID` from the `/dev/serial/by-id` symlink
— the closest thing Linux has to a stable device identity.

**The enumerator's unit test cannot answer this by design.**
`Test_LiveListIsSelfConsistent` passes identically with an adapter plugged in and
without one, because it must pass in CI on a machine with no hardware. The suite
proves self-consistency; `portprobe` proves what was found. Different questions.

## Hard rules

- **Serial binary I/O must be byte-exact** — `WriteBytes`/`ReadBytes`, never
  `WriteString`/`ReadString`. A CI-V or Yaesu-binary frame corrupted by string
  conversion fails **silently**.
- Byte I/O is one of the two genuine exceptions to the no-`PChar`, no-raw-call
  rules. **It keeps its handle and gains a comment saying why.**
- **`Move`/`FillChar`/`ZeroMemory` is NOT how to express byte I/O** (NY4I's added
  rule in `docs/64_BIT_TASKLIST.md`). Byte I/O stays byte I/O.
- **An open COM port is not a working link.** Reconnection needs a real
  close/reopen — but that lives on the radio (`MaintainSerialLink`), not here.
- **A keyer owns its own port**, distinct from the CPU keyer's port. Do not
  collapse them.

## The vendored transport

`tr4wserial.pas` is vendored. Its Windows/Unix split has bitten before: a merge
gave `SerBreak` the Windows default (`mSec = 250`) in an interface whose Unix body
declares `0` — something **no Windows build could ever see**. Cross-check the
interface against both bodies when you touch it.

**And it has bitten a second time, in the same shape — `SerOpen`'s FAILURE
SENTINEL (found 2026-09-21).** The interface says *"Returns 0 if device could
not be found"*, and only the Windows body makes that true: it maps
`INVALID_HANDLE_VALUE` onto zero itself. The Unix body is `fpopen`, which
answers **-1**. So `uSerialPort.OpenRaw`'s test of `= NO_PORT` was false for
every failed open on Linux and macOS, and it went on to configure and hand back
a handle of -1 — **a radio on a port the user cannot open came up looking
connected and simply never answered.** The fix is `TSerialPort.OpenFailed`, in
`uSerialPort` and **not** in the vendored file, whose own header forbids local
edits because they are invisible to the next person who diffs it against FPC.

**Read that as the rule, not the anecdote: where the two bodies can differ,
assume they do, and put the reconciliation in `uSerialPort`.**

## Why an open failed

`src/uSerialDiagnosis.pas` turns a failed open into a sentence an operator can
act on — on POSIX it stats the node, resolves the owning group, and asks
`FpGetgroups` whether this account is in it. `TSerialPort.OpenRaw` is the only
caller, which is why both radio and keyer paths get it.

**Three things about it that are load-bearing.** It **never tests for a group
called `dialout`** — that is `uucp` on Arch and meaningless on macOS, so the
node is asked. It **never pre-flights the open**; it runs only after a real
`EACCES`, so nothing here is ever a second source of truth about whether a port
is usable. And it uses **no `grp`/`users` package**: that FPC package is NOT
installed on `mac-ci` (measured), so a gid is resolved by reading `/etc/group`,
and degrades to the number rather than to a wrong name.

## Coordinate with

`radio-factory` (every serial radio) · `cw-keying` (WinKeyer and CPU keyer ports)
· `settings-config` (`SERIAL n` is config vocabulary) · `lcl-ui` (the port
drop-down uses item data, **never index arithmetic**).
