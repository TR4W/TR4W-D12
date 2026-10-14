---
name: integrations
description: Third-party program integration — WSJT-X (UDP), MMTTY (RTTY), and the external logger factory (DXKeeper, ACLog, HRD). Use for digital-mode interop, decode handling, colorization hints, QSO hand-off to another logger, or anything about an out-of-process companion program.
tools: Read, Grep, Glob, Bash, Edit, Write
model: sonnet
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

**The UDP handler runs on Indy's listener thread** (`ThreadedEvent := true`), so
anything it does that reads the dupe sheet, the multiplier structures or
`ActiveContest` is a data race with the main thread -- `ActiveContest` can free
and rebuild the contest object on EVERY call. Fixed 2026-10-14 for the CQ decode:
the listener parses and copies; `PostCQDecode` queues a job of VALUES through
`Application.QueueAsyncCall` (FIFO, not `TThread.Queue`, which purges a thread's
entries when it is destroyed), and `EvaluateCQDecode` -- which refuses off the
main thread -- does the dupe/mult test and sends the `HighlightCall` reply.
`Stop` detaches queued jobs from the server; a detached job is popped and dropped.
`HighlightCall`'s `SendBuffer` is thread-neutral (the binding is fixed when the
server goes Active), so the reply was never the problem.

**Still on the listener, knowingly:** the STATUS arm (`GoToBand`,
`PutCalltoCallWindow`, `ActiveRadioPtr`) and the LOGGED-ADIF arm (`ParseADIFRecord`,
`ParametersOkay`, `LogContact`, the entry-field state). Same defect class; moving
the logging arm changes how a QSO is logged and needs a live WSJT-X session.
Do not add a main-thread read to `OnServerRead`; add it to the hand-off.

**`destructor Destroy;` without `override` is a WARNING, not an error, and `Free`
never reaches it.** `TWSJTXServer`'s did not, so `FreeAndNil(wsjtx)` leaked the
sockets until 2026-10-14. Check the keyword on any destructor you add.

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
