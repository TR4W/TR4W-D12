# What a factory radio still gets from the legacy path

Read-only audit, 2026-07-29. Prompted by a question about where the TS-850's
2 stop bits come from — the answer turned out to be "a legacy typeset that will
disappear when the legacy does, with nothing in the factory to replace it".

The point of the audit is that these failures are **silent and late**: they do not
break the build, they break on somebody's radio after the legacy is deleted.

## Summary

The factory object's surface toward the legacy is small and mostly healthy. Every
member the legacy touches:

```
11 SendToRadio   7 Disconnect   6 Connect    3 SendCW   3 MemoryKeyer
 2 VFOBumpUp/Down/Split/SetFrequency/RITClear/BufferCW
 1 rigLabel  StopCW  SetCWSpeed  SendPollRequests  IsConnected  Free
```

Only **one** is a write of state: `rigLabel`. Everything else is a method call.
That is the shape we want.

The problem is not that surface. It is what the legacy computes and hands over
**before** the object exists.

## A. Port settings — the real landmine

`SetUpRadioInterface` passes six values into `CreateRadioSerial`:

```pascal
RadioBaudRate, RadioNumberBits, RadioStopBits, Ord(RadioParity),
tr4w_cat_rts_state = RtsDtr_ON, tr4w_cat_dtr_state = RtsDtr_ON
```

and `uRadioFactory.pas:154-157` **overwrites** the object's own values with all
of them. So `TFactoryRadioBase.Create`'s `serialBaudRate := 38400; serialDataBits
:= 8; serialStopBits := 1; serialParity := 0` is **dead code for serial
creation** — it is always replaced. No radio subclass sets any of the four.

Where each value really comes from:

| setting | source | per-model? |
|---|---|---|
| baud | `CFGDEF:386/406` = 4800; `CAT BAUDRATE` overrides | No. The per-model value in `RadioParametersArray.br` survives ONLY as the dialog's preselected combo entry (`uCAT.pas:1387`) |
| data bits | `CFGDEF:389/409` = 8 | No, never varied |
| parity | `CFGDEF:392/412` = `tNoParity` | No, never varied |
| **stop bits** | `InitRadios` = 2, then **overwritten on every port init** | **YES** |

The per-model stop-bit rule, `LOGRADIO.PAS:1571-1578`, inside
`CheckAndInitializePorts_ForThisRadio`, which runs immediately before
`SetUpRadioInterface`:

```pascal
if RadioModel in [IC78..IC9700, FT100, Orion] then
   RadioStopBits := 1
else
   RadioStopBits := 2;
```

Three consequences:

1. **Delete the legacy and every Icom silently gets 2 stop bits.** This typeset is
   the only thing setting them to 1. Nothing in the factory replaces it. The
   fallback is `InitRadios`' global 2 — wrong for every Icom, the FT-100 and the
   Orion.

2. **The TS-850 gets its 2 stop bits by accident.** Its manual requires them, but
   the code does not know that — it gets them by not being an Icom. Nothing names
   the TS-850, and no comment records the requirement.

3. **It would clobber a UI.** The assignment is unconditional and runs on every
   port init, so exposing stop bits in the radio-control window without
   restructuring this first means the user's setting is overwritten on the next
   connect.

## B. Other things handed over at connect

| what | from | status |
|---|---|---|
| `rigLabel` | `Self.RadioName` ("Rig 1"/"Rig 2") | Fine — presentation, legacy owns the concept |
| `radioModel` | registry `DisplayName` | Already factory-owned |
| Icom network credentials + `DataModeID` | `Self.NetworkUsername/Password`, `Self.IcomDataModeID` | Set via `is TIcomRadio` / `is TKenwoodTS890Radio` casts in `LOGRADIO:3139-3160`. Works, but it is the legacy asking what class the object is. Needs a home when the legacy goes — a virtual `ApplyCredentials` or config passed at construction |
| `StartupCommand` | config; sent after first connect | Fine — a config string, not radio knowledge |
| `pollingInterval` | **overwritten** by `FreqPollRate` unless `honorsFreqPollRate = False` | Already bitten us twice (Flex, TS-890). Documented in the driver headers |
| `CurrentStatus` | legacy `RadioStatusRecord` on the rig record | Not a landmine — this is the intended seam. `pFactoryRadio` writes it 22 times; it is how a factory radio publishes state to the display, band map and the rest of TR4W |

Checked and cleared: `icomHasDataMode` is read only by
`pFT817_FT847_FT857_FT897` (`uRadioPolling:1986`), a legacy poller. No factory
radio depends on it.

## C. The design question — and why the parameters are split

NY4I's objection to splitting these settings across two homes is right, and the
audit says the split is not actually necessary.

The reason a split looked unavoidable is the **radio dialog**: it must show a
default baud for a model the operator is *selecting*, before any radio object
exists. That seems to force the value into the registry (data), while stop bits
is protocol-driven (Icom CI-V vs Kenwood ASCII) and belongs with the family base
that already knows the protocol. Hence two homes.

But constructing a factory radio is **cheap and side-effect free** — the
constructor opens no port and touches no hardware; `Connect` does. So the dialog
can simply build a throwaway instance and ask it:

```pascal
r := uRadioRegistry.CreateInstance(model);
try
   baud := r.serialBaudRate;
   stop := r.serialStopBits;
finally
   r.Free;
end;
```

That collapses the split. **All four port settings live in one place — the
class constructor** — which is exactly what NY4I expected to find:

> "I would expect it to be in the constructor of the class as a default, then
>  potentially reset from the tr4w.ini file."

`TIcomRadio` sets 1 stop bit, `TKenwoodSerial` sets 2, `TYaesuBinary` sets 2, and
a model that differs from its family overrides it in its own constructor. The
`[IC78..IC9700, FT100, Orion]` typeset dies with the legacy and is not replaced
by another typeset — each radio states its own requirement, which is the rule the
factory already follows everywhere else.

Cost: the constructor allocates a `TIdTCPClient` and a `TCriticalSection`, so a
throwaway instance is not free — but it is a dialog, once, on a user action.

### The blocker either way

For a class default to survive, `CreateRadioSerial` must stop overwriting it
unconditionally. It needs to tell "the user configured this" from "nobody set
it", and today it cannot: `CFGDEF` seeds a real value (4800), so every radio
looks configured.

Smallest fix: make the config default a sentinel (0 = "not set"), and have
`CreateRadioSerial` apply a parameter only when it is non-zero:

```pascal
if baudRate > 0 then Result.serialBaudRate := baudRate;   // else keep the class default
```

`CAT BAUDRATE` in a cfg/ini then means "override this radio's default", which is
what an operator would expect it to mean.

## D. Suggested order

1. Port settings into the class constructors, with the sentinel change (A + C).
   **Do this before deleting the legacy**, not during — it is the one item where
   deletion causes silent hardware-level breakage.
2. Icom/TS-890 credentials off the `is`-casts and onto a virtual.
3. Then the InitRadios capability sets (tasks #7–#8), which are the same job:
   things the legacy still supplies that nothing in the factory has taken over.

Nothing in this document has been changed in code.
