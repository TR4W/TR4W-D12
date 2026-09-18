# portprobe — what TR4W actually sees on this machine's serial ports

Prints every port `TComPortEnumerator` reports, with the fields that decide how
a port is displayed and whether an operator can choose it.

```
portprobe
```

Exits 0 always. It asks a question; it does not assert an answer.

## Why it exists

**The enumerator's unit test cannot answer this, by design.**
`Test_LiveListIsSelfConsistent` checks that the two entry points agree and that
`Addressable` means what it says — and its own comment records that *"a machine
with no serial port satisfies all of it."* That is the right property for a
test that must pass in CI on a machine with no hardware, and it is exactly why
the suite passes **identically with an adapter plugged in and without one**.

So the suite proves the enumerator is self-consistent. This proves what it
found. Different questions, and the second one needs real hardware.

## Measured 2026-09-18 — `linux-ci-build`, FTDI FT232R

NY4I fitted an FTDI FT232R USB adapter to the Linux build host. Built and run
there, against that adapter:

```
target: x86_64-Linux
enumeration supported on this platform: yes
highest COM number TR4W can store:      64

ports found: 1

[0]
  PortName     : /dev/ttyUSB0
  PortNumber   : 0   (0 = the name carries no COM number)
  FriendlyName : FTDI FT232R USB UART
  DeviceDesc   : ftdi_sio
  InstanceID   : usb-FTDI_FT232R_USB_UART_AB0NDXQ2-if00-port0
  Addressable  : no   (can TR4W's config vocabulary name it?)
  Present      : yes
  Describe     : /dev/ttyUSB0 - FTDI FT232R USB UART
```

**What that confirms.** The sysfs walk found exactly one port **among 32
`ttyS*` stubs** — it does not drown a real adapter in motherboard ghosts. It
built `FriendlyName` from the USB descriptors two levels above the tty
(`manufacturer` + `product`, well inside `USB_PARENT_LEVELS`), took
`InstanceID` from the `/dev/serial/by-id` symlink — the closest thing Linux has
to a stable device identity — and fell back to the driver name for
`DeviceDesc`.

**`Addressable: no` is correct, not a defect.** TR4W stores a port as
`SERIAL n`, and `/dev/ttyUSB0` has no ordinal. The enumerator lists the port
*with* that reason rather than hiding it. Making it selectable is **step 5** of
`docs/PORT_IDENTITY_PLAN.md`, which must not land before step 4 (the
`SerialPortObject` array → dictionary rework). A fresh adapter does not unblock
that on its own.

## Building it

There is no build stage for this — it is a tool, run when someone wants the
answer. On Unix, the flags are the ones `build-unix.sh`'s `search_paths` and
`compile` assemble:

```
fpc -Mdelphi -Sc -T<os> -P<cpu> -gl -FU<outdir> -o<exe> \
    -Fi<src> -Fi<tr4w>/include \
    -Fu<src>{,/ui/lcl,/trdos,/utils,/lang,/domain,/radioFactory,...} \
    -Fu<laz>/lcl/units/<arch>{,/<widgetset>} \
    -Fu<laz>/components/lazutils/lib/<arch> -Fu<laz>/packager/units/<arch> \
    -Fu<tr4w>/include{,/Core,/System,/Protocols} \
    portprobe.lpr
```

**`include/` must be on `-Fu` as well as `-Fi`**, and forgetting that is how
the first attempt failed: `Log4D.pas` lives there, `VC` uses it, and `-Fi` is a
separate list that `-Fu` lookups never search. `build-unix.sh` says so in a
comment; I reconstructed the flags by hand and left it out.

## It needs no widget set, and that is a finding

**No `Interfaces`, deliberately** — and it compiles and runs headless because
of it. `VC` reaches the LCL for `LCLType`, which declares `HWND`/`HFONT`/
`TLogFont` for every widget set: a **type** unit, not a widget set. Adding
`Interfaces` would link gtk2 and require a display, which is why the unit-test
binary needs `xvfb-run` on this host. A serial probe that could not run on a
headless build host would be useless on the machine most likely to need it.

## Why it is not part of `tr4w_platformcheck`

That program is deliberately free of this tree — it links only `uProbeReport`
and `uPlatformProbes`, and `Build-PlatformCheck.ps1` passes **no `-Fu` at
all**. It asks the *platform* questions. This asks a *TR4W* question and needs
TR4W's units to do it. Folding it in would give `platformcheck` a dependency on
`src/` it has been kept clean of — a decision worth making on its own merits,
not as a side effect of wanting one answer.
