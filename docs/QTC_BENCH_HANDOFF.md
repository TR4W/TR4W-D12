# WAE QTC windows — bench handoff

**For N4AF (Howie), or anyone who operates WAE QTCs.**

Both QTC windows were converted from raw Win32 dialogs to LCL forms on
2026-08-31/09-01, along with several fixes on top. **Neither has been exercised
by an operator.** NY4I (2026-09-01): *"I have to look up how to operate QTCs
honestly. That is Howie's area."*

This is the only part of the Win32-to-LCL conversion in that state. Every other
converted window is either driven by an automated harness in `tr4w/test/ui/` or
is something NY4I uses himself. These two are neither, and three separate fixes
to them have been made from photographs rather than from a bench run.

---

## Why there is no automated test

The harnesses in `tr4w/test/ui/` drive the running program, post a menu command
and read the result out of `tr4w.log`. That works for Alt-P, the Cabrillo
summary and the file viewer because each opens from a menu item with nothing in
the way.

A QTC window opens only during a DARC WAE contest, with a callsign in the call
window and QSOs available to send — and there is **no WAE set in the golden
corpus** to drive it from. Building one would prove the windows open; it would
not prove the QTC exchange is right, which is the part that matters and the part
that needs someone who knows the mode.

So: what follows is a script, not a test. Every item says what to do and what
correct looks like, taken from what the Win32 code did.

---

## Before you start

Set `DEBUG LOG LEVEL = DEBUG` under `[COMMANDS]` in `settings/tr4w.ini`. Several
checks below are read off `tr4w.log` rather than the screen, and the log lines
named here exist specifically so this session does not have to be repeated.

The contest must be `DARC-WAEDC-CW` or `DARC-WAEDC-SSB`. Those are the only two
that enable the QTC menu item (Ctrl+Q).

---

## Part 1 — the QTC SEND window (`uQTCSendForm`)

Opens when you send a QTC book to a DX station. Up to ten QSOs, read one line at
a time, with eight command buttons along the bottom.

### 1.1 It opens correctly

- [ ] The title reads **`<your QRV message> for <callsign>`** — e.g.
      `QTC 3/10 for DL8UHJ`. **Not** with a box or a stray glyph in front of the
      QRV message. (That glyph was a length byte being drawn as a character; it
      was fixed on 2026-09-01 and is the kind of thing that comes back.)
- [ ] The second command button shows your QRV message, same text as the title.
- [ ] One row per QSO to be sent, each reading `HHMM CALL NR` in a fixed-pitch
      font with the columns lined up.
- [ ] The window **opens** wide enough to show all eight command buttons
      including `STOP`. It should not open clipped and then jump when you touch
      a corner.

### 1.2 It cannot be made too small

- [ ] Drag it as small as it will go. Every command button must still read in
      full — `NEXT [return]`, not `EXT [retur`.
- [ ] Close it and open it again, then drag it small again. It must stop at the
      same place. **This is the specific check**: the minimum used to be
      re-derived from however small the window currently was, so each reopen let
      it go smaller than the last.
- [ ] `tr4w.log` carries a line like

      [MinSize] frmQTCSend: client WxH, content WxH, slack WxH -> min WxH, window now WxH

      If a button is clipped, that line says whether the measurement was wrong
      or the window did not get the width it asked for.

### 1.3 Sending a book

- [ ] `NEXT` sends the next line. The line just sent turns **yellow**, and the
      blue `< Next` marker steps down to the following row.
- [ ] After the last line, the marker disappears.
- [ ] Pressing `NEXT` again asks **`QSL n/n ?`**. Answering OK saves the book and
      closes the window. Answering Cancel leaves it open.
- [ ] The saved QSOs appear in the log as QTCs, and the QTC count for that
      station goes up.
- [ ] `QRV?`, `TIME`, `CALL`, `NR` and `ALL` send what their names say. `TIME`,
      `CALL` and `NR` re-send parts of the line **most recently sent** and do
      nothing before the first `NEXT`.
- [ ] `STOP` asks whether you really want to stop, then asks whether message *n*
      was confirmed. Answering No steps the count back one. If nothing is left
      confirmed, the book is abandoned.

### 1.4 The per-line resend buttons — NEW BEHAVIOUR, PLEASE JUDGE

**This is the one deliberate behaviour change in the send window and it wants
your opinion.**

Each row has a small button labelled `1`..`10` (Alt+1 … Alt+0). **In the Win32
version these never worked.** They were created with the same control id as the
row's text, while the handler that resends a line reads a different id range —
so the button stayed disabled forever and Alt+*n* reached nothing.

The intent was not in doubt (there is a handler for it, an enable call for it,
and a caption for it), so the conversion wired them up.

- [ ] After a line has been sent, its row button becomes enabled.
- [ ] Alt+*n*, or clicking it, **re-sends that line**.
- [ ] Rows not yet sent stay disabled.

**If you would rather they stayed inert**, say so — it is one line in
`BuildRows`. The question is whether an accidental Alt+3 mid-book is worse than
not being able to repeat a line.

### 1.5 Keys

- [ ] **PageUp / PageDown** change CW speed while the window has focus.
- [ ] **F10** opens send-from-keyboard.
- [ ] Closing part-way through asks before abandoning the book.

Those three used to be **system-wide hotkeys** (`RegisterHotKey`), registered and
unregistered on every activation, because a Win32 dialog's buttons swallow keys
before the dialog sees them. They are now ordinary key handling on the form. If
one of them has stopped working, that is why.

---

## Part 2 — the QTC RECEIVE window (`uQTCReceiveForm`)

Opens when a DX station sends you a QTC book. Ten rows of time / callsign /
serial, typed as he sends them, with a column of buttons that ask him to repeat
something.

**This was the heaviest window in the whole conversion.** It did not merely
create its controls — it **subclassed thirty-two of them**, pointing every edit
box's window procedure at one shared routine that then worked out which control
it was running for by comparing handles and doing arithmetic on control ids. All
of that is gone. Everything below is a behaviour that used to live in that
routine.

### 2.1 It opens correctly

- [ ] Title reads **Receiving QTCs**.
- [ ] `QTC?` goes out as the window opens.
- [ ] The caret starts in the **QTC number** box (top right).
- [ ] The callsign box shows his callsign.
- [ ] The label beside the number box reads `Enter QTC #/# (max of N)` with N
      being how many QTCs he may still send you.
- [ ] All ten rows are visible and **disabled**.

### 2.2 Starting a book

- [ ] Type a group like `3/10` and press **Return**.
- [ ] `QRV` goes out, row 1 unlocks, and the caret lands in row 1's **time**
      field.
- [ ] A bad number — no slash, two slashes, a count over 10, or a count larger
      than he may send — puts **`Check QTC number`** on the status line and does
      not unlock anything.

### 2.3 Typing a book

- [ ] Return in any of a row's three fields checks **that whole row**.
- [ ] A good row sends **`R`**, unlocks the next row, and puts the caret in its
      time field.
- [ ] A bad time says **`Check time`** and puts the caret back in the time field.
      Times are HHMM: minutes over 59 or hours over 23 are rejected.
- [ ] A callsign that does not look like one says **`Check callsign`** — but
      **only if something has been typed**. An empty field just takes the caret,
      with no message.
- [ ] A missing serial takes the caret to the number field with no message.
- [ ] After the last row of the group, it asks whether to save, then asks
      **`Edit QTC? Press Yes to edit QTC or No to log`** — note that **Yes means
      keep editing**, so No is what logs it. That wording is unchanged from the
      original; if it reads backwards to you, say so.
- [ ] On logging, `QSL <number> TU` goes out and the window closes.

### 2.4 Moving around — all of this used to be in the subclass

- [ ] **Right** or **Space** at the end of a field moves to the next field.
- [ ] **Left** at the start of a field moves to the previous one.
- [ ] **Down** moves to the same column of the **next row**; **Up** to the
      previous row. (This works by stepping three fields, which is why the ask
      buttons must not be tab stops — if Up/Down start landing on a button, that
      is the cause.)
- [ ] The fields accept only letters, digits and `/`. The QTC number box accepts
      only digits and `/`.
- [ ] Everything you type appears in **upper case**.
- [ ] **PageUp / PageDown** change CW speed, **F10** opens send-from-keyboard —
      and unlike the original these now work wherever the caret is, not only
      inside an edit box.

### 2.5 The ask buttons

- [ ] `AGN`, `RPT?`, `TIME?`, `CALL?`, `NR?`, `R`, `QTC?`, `QRV` each send their
      own caption as CW.
- [ ] The seventh button reads **`DE <your callsign>`** and sends that.
- [ ] The tenth button has no caption and does nothing. **It had none in the
      Win32 version either** — if it should have one, say what.

### 2.6 There is no OK button — DELIBERATE, PLEASE JUDGE

**The Win32 receive dialog had an OK button that did nothing.** Its handler is
literally `1: ;//SaveQTCR;` with an N4AF 04.32.3 note beside the commented-out
call — so saving on OK was switched off years ago, presumably by you.

The conversion **removed the button** rather than render a dead control.

- [ ] Escape still closes the window, asking first if a group has been started.
- [ ] If you want an OK button back, say what it should DO — the book is
      currently saved by finishing its last row.

---

## Part 3 — things that were changed and are NOT visible

Recorded here because they are easy to attribute to the wrong cause if something
looks odd.

**`SetTransmittersIdentifiers` is held shut.** Selecting `TWO` for
CATEGORY-TRANSMITTER in the Cabrillo summary used to be *supposed* to prompt for
"transmiter 1 computers IDs". That prompt is deliberately disabled, because the
value it collects (`Radio1IDs`) is **read by nothing** — the transmitter-id
column in the Cabrillo QSO line is derived from something else entirely. See the
note at that site in `trdos/PostUnit.PAS`, and Part 4.

**The QTC-per-station table now allocates itself.** Saving a book used to be able
to fault with an access violation, because the table counting QTCs per station
was allocated only if `QTC ENABLE` was true at config-load time, while the QTC
menu is enabled by the **contest** alone. Both gates still exist and still
disagree; the crash does not. If you see a `[QTC]` warning in the log about more
than 500 stations, that is a new bound check and not a fault.

---

## Part 4 — an open question for you

**The Cabrillo transmitter id looks wrong against the specification, and nobody
has changed it.**

Cabrillo v3 says the QSO line's transmitter id is a single `0` or `1`
identifying RUN/MULT or RUN1/RUN2, used in the one- and two-transmitter
categories (M/2, CQWW M/S) and **not** in single-op or M/M.

TR4W emits that column from `trdos/PostUnit.PAS`:

```pascal
if CategoryOperator = coMULTIOP then
  if TempRXData.ceComputerID = ComputerID then
     T4 := '1'
  else
     T4 := '0';
```

Two divergences:

1. It emits the column for **every multi-op entry**, so an M/M log carries a
   column the specification says it should not have.
2. It sets the id from *"was this QSO logged on the machine doing the export"*,
   not *"which transmitter made it"*. With three PCs on transmitter 1 and two on
   transmitter 2, that is the wrong split.

`Radio1IDs` — ten characters, prompted as *"transmiter 1 computers IDs"* — looks
like exactly the missing input: the set of computer ids belonging to transmitter
1, to test each QSO's `ceComputerID` against. It is collected and never read, so
the feature reads as unfinished rather than broken.

**Nothing has been changed here.** It alters what a submitted log contains, so it
needs someone who knows what the sponsors expect.

---

## What to do with the results

Tick what passes and send the rest back with the `tr4w.log` from the session —
the log lines named above (`[QTCSend]`, `[MinSize]`, `[CRASH]`) are there so a
failure can be diagnosed without a second run.

Items that pass come out of `docs/BENCH_QUEUE.md`. Anything interesting goes
into the unit's own header, where the next person reading the code will find it.
