# A port's identity: the three pieces, planned together

**NY4I, 2026-09-10.** Three items came out of a bench report that Linux showed
no serial ports in the drop-down. Two are done; this plans all three as one
piece of work so the third is not designed in isolation from what it replaces.

| | | |
|---|---|---|
| 1 | The drop-down tells the truth | **DONE** |
| 2 | Linux enumerates its ports | **DONE**, verified against real hardware |
| 3 | The device name becomes the identity | **PLANNED — this document** |

---

## 1 and 2, and what they proved

`ComPortEnumerator` reads `/sys/class/tty` and reports device nodes:
`/dev/ttyUSB0`, never `SERIAL 1`. Identity comes from `/dev/serial/by-id`,
which udev builds from the adapter's own USB descriptors and serial number, so
it survives a replug that renumbers the node.

Verified on the bench box against an FTDI FT232R, and on the build host, which
has 32 `ttyS` stubs and correctly reports none.

**One filler serves every port drop-down**, and a port the settings file has no
spelling for is LISTED with a reason rather than shown and silently saved as
`NONE`.

**And a port name has one producer.** `uPortAddress.SerialDeviceName` replaced
five copies of "the ordinal is the COM number" and, in doing so, found a defect
in three of them: they guarded with `<> NoPort`, which a port configured as
NETWORK satisfies, so the name built was `COM65`.

**What 1 and 2 could NOT do** is make a Linux port selectable, because the
settings file has no way to spell a device node. That is item 3.

---

## 2a. Why `SERIAL n` goes — settled, not open

NY4I asked whether to drop it and agreed on 2026-09-10.

**It is not an OS name.** `COM7` and `/dev/ttyUSB0` are. `SERIAL 7` is TR4W's
own token, and the `PortType` ordinal behind it is a third spelling.

```
   the drop-down          /dev/ttyUSB0  or  COM7        the OS name
   ComNameToPortValue     'SERIAL 7'                    TR4W's own token
   settings/tr4w.json     "controlPort": "SERIAL 7"
   the legacy key text    RADIO ONE CONTROL PORT = SERIAL 7
   PortTypeSA             ordinal 7                     a third spelling
   SerialDeviceName       'COM7'                        the OS name again
```

Both ends are the OS name. Everything between is TR4W talking to itself.

Three reasons, in order of weight:

1. It cannot name a port on two of the three platforms we build for. No
   arithmetic on an ordinal produces `/dev/ttyUSB0`.
2. **It is a second definition of a thing the OS already named** — the same
   shape as the deleted radio enum tables, where a config saying `TS440`
   selected the TS-140 driver for four Kenwoods for years.
3. A numbered slot is not an identity. Replug an adapter and `SERIAL 7` points
   at a different radio while claiming nothing changed. The enumerator already
   computes a stable identity that has nowhere to live.

---

## 3. What `PortType` is actually being asked

Measured 2026-09-10 over every live reference to the port globals
(`tCATPortType`, `tKeyerPort`, `ActiveRotatorPort`, `wksWinKey2Port`,
`serialPort`), classified by what the line asks:

| the line asks | sites |
|---|---:|
| **what KIND** — `= NoPort`, `= Network`, `in SerialPorts`, the LPT range | **43** |
| a declaration | 21 |
| `Ord()`, for a log message | 11 |
| the config rows and a few assignments | 27 |
| renders a SPELLING through `PortTypeSA` | 5 |
| **indexes an array BY the enum** | **4** |
| **which port** — the one namer | **4** |

**That table is the plan.** Three of the seven rows are the work; the rest
either do not care or follow.

- **43 ask what kind.** They want a four-value enum, not a sixty-eight value
  one. Mechanical to repoint and exhaustively testable.
- **4 ask which port.** All four already call `SerialDeviceName`, because item
  1 centralised them. This is the only place a device node has to appear, and
  it is now one function.
- **4 index an array**, `SerialPortObject: array[TSerialPortRange] of
  TSerialPort` in the CPU keyer. The single genuine structural dependency, and
  it wants a dictionary keyed by device name.

---

## 4. The steps, in order, each one shippable

Each step builds green on both platforms and changes no behaviour on Windows
until the last.

### Step 1 — the radio carries a device NAME beside the enum

Add a name field to the radio and to the keyer and rotator settings, set
wherever the enum is set, and have the four namer sites prefer it when it is
non-empty. On Windows the name derives from the enum exactly as today, so
behaviour is identical.

This is the widen half of a widen-then-narrow: nothing is removed and the new
carrier can be proven before anything depends on it.

### Step 2 — the store holds the OS name

`ComNameToPortValue` stops producing `SERIAL n` and returns the device name.
`TRadioDefinition.ControlPort` is **already a free string in JSON, with no
validation**, so this needs no schema change.

A stored `SERIAL n` is translated once on read, on Windows only, because that is
the only platform where such a value can exist.

**Compatibility, checked rather than assumed:**

| question | answer |
|---|---|
| does a port cross the multi-op wire? | **No.** The only reference in the networking units is a commented-out line in `lognet.pas` |
| does a shipped contest `.cfg` carry one? | **No.** None in `target/dom` |
| what must still be read? | one operator-local `tr4w.json` holding `SERIAL n` |

**There is no deployed encoding to preserve.** That is what makes this cheap,
and it is worth restating to anyone who assumes otherwise.

### Step 3 — the kind becomes its own enum

`TPortKind = (pkNone, pkSerial, pkNetwork, pkParallel)` in `uPortAddress`, and
the 43 kind sites repoint. Write the exhaustive pin test in the same commit —
a mis-mapped arm reads as a legal value and no compiler will say so.

### Step 4 — the array becomes a dictionary

`SerialPortObject` keyed by device name. Four sites. This is the step that
makes a device node representable end to end, and it is the one with real
lifetime questions: two radios may nominate the same keyer port, and the object
is owned by the keyer rather than the radio.

### Step 5 — `Addressable` becomes true

`ComPortEnumerator` marks Linux ports addressable, the "(not selectable yet)"
caption goes, and a Linux operator can pick their adapter. **This is the step
the bench can see**, and it must not land before step 4.

### Step 6 — retire what is left

The six port rows over five `ListParamArray` entries go to `csRem`, and
`PortType`'s sixty-four serial members go with them. `Lint-SpellingTables`
loses one of its forty tables.

---

## 5. What does NOT change, so nobody widens this

- **Network radios.** An IP address and a port are not a device node and were
  never `SERIAL n`.
- **LPT.** `Parallel1..3` is a genuinely small fixed set, `inpout32` addresses
  by base address, and CLAUDE.md records that LPT stays Windows-gated with
  Linux later. It keeps its enum.
- **The settings model.** `uSettingsModel`'s command-name reflection is NOT the
  vehicle here: radios, keyers and rotators live in structured JSON stores, not
  in the `commands` section. Conflating the two would put a library of radios
  behind a flat key namespace. They are separate migrations that happen to be
  running at the same time.

---

## 6. How it gets proven

**No step above is proven by a compiler.** The gate is CLAUDE.md's own: one
verified rig per protocol family, and the four bench defects of 2026-08-29/30
are the reason — none of them would have failed a build.

| what | how |
|---|---|
| the name a port resolves to | unit tests, exhaustive over the enum; already in `uTestPortAddress` |
| the store round trip | unit test, and a `SERIAL n` fixture for the one-time translation |
| a Linux port opens a radio | **bench, on the Mint box, with the FTDI adapter already proven to enumerate** |
| Windows is unchanged | the golden corpus is blind to this, so: a Windows bench session on one serial rig |

**The Windows check is the one most likely to be skipped and the most
important.** Everything here is motivated by Linux, and the failure mode of a
careless step 2 is a Windows station whose radio silently stops opening.

---

## 7. Risks, named

1. **Step 4 has lifetime questions.** Two radios may nominate one keyer port
   and the port object is not owned by either. Getting it wrong closes a port
   another radio is using.
2. **Step 2 can silently reset a station.** A translation that fails to
   recognise a stored value leaves a port unset, and TR4W would come up with no
   radio. It must keep what it cannot read, which is the rule the settings
   import already follows.
3. **Step 5 is visible and the rest are not.** That makes it tempting to do
   first. It cannot be: a selectable device node with no carrier under it saves
   `NONE`, which is the exact silent loss item 1 removed.
