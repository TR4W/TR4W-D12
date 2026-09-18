---
name: integrations
description: Third-party program integration — WSJT-X (UDP), MMTTY (RTTY), and the external logger factory (DXKeeper, ACLog, HRD). Use for digital-mode interop, decode handling, colorization hints, QSO hand-off to another logger, or anything about an out-of-process companion program.
tools: Read, Grep, Glob, Bash, Edit, Write
---

You own TR4W's links to other programs on the operator's desk.

## Your files

| | |
|---|---|
| WSJT-X — UDP | `tr4w/src/uWSJTX.pas` |
| MMTTY — RTTY | `tr4w/src/uMMTTY.pas`, `src/ui/lcl/uMMTTYForm.pas` |
| external logger factory | `uExternalLoggerFactory.pas` |
| abstract base | `uExternalLoggerBase.pas` (`TExternalLoggerBase`) |
| implementation | `uExternalLogger.pas`, `uExternalLoggerManager.pas` |

Globals in `MainUnit`: `wsjtx: TWSJTXServer`, `externalLogger: TExternalLogger`.

## WSJT-X

UDP; sends colorization hints, receives decodes and QSOs. Enabled with
`WSJT-X ENABLE = TRUE`.

The UDP thread **does not write the entry fields** — that separation was a fix,
not an accident. Highlighting had two separate defects before it worked reliably;
dupe and new-multiplier colouring in the decode list is the visible contract.

## MMTTY

**MMTTY is out-of-process** — launched with `WinExec`, not loaded as a DLL. That
matters for one reason worth stating: **it does not block the 64-bit work.**

The `MMTTYMODE` compile-time switch was **deleted 2026-08-18** (NY4I: *"the
boolean controls it now"*). It had been `True` for the life of this tree, so all
20 of its `{$IF}` blocks always compiled and one `{$IF NOT MMTTYMODE}` block never
did. Do not reintroduce a compile-time gate here.

## External loggers

| type | status |
|---|---|
| `lt_DXKeeper` | Complete |
| `lt_ACLog` | **Incomplete** — the factory logs a warning on creation |
| `lt_HRD` | **Incomplete** — same |

Each logger runs its own `TReadingThread` / `TSenderThread` pair.

**This is the OLDER factory shape** — a `case` in one class function
(`TExternalLoggerFactory.CreateLogger`) raising
`EExternalLoggerFactoryException`, not the radio factory's self-registration
registry. **If it grows, move it toward the registry pattern rather than extending
the `case`.** That is the standing instruction, not a suggestion.

Note `TReadingThread` here owns its own `radioWasDisconnected` flag and holds no
radio reference — do not reach for a radio from inside it.

## Gone — do not restore

**MixW was deleted 2026-09-05** (NY4I: *"you can remove all traces of mixw. I
confused it with a different program"*). It was never working code: the whole unit
body sat inside `{$IFDEF MIXWMODE}`, a define that existed **nowhere** in the
tree, and defining it would not have helped — the var block was commented out and
`tw_MixWWINDOW_INDEX` was never declared. `SendMessageToMixW` compiled to an empty
procedure and its six live callers did nothing.

## Prefer a reported error over a silent fallback

Several defects on this branch were silent downgrades. A companion program that
fails to start, or an incomplete logger type selected by an operator, should
**say so**.

## Coordinate with

`contest-scoring` (a decode becomes a QSO) · `log-database` (hand-off writes) ·
`multi-op-network` (the other UDP/TCP consumers) · `lcl-ui` (`uMMTTYForm`).
