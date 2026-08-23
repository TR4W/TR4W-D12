# The main window's controls: old Win32 handle -> new LCL object

**Read this before replacing any `wh[...]` use.** NY4I, 2026-08-23: *"You have
to keep careful watch on what specific windows on the main window the old code
changed to ensure you use the same newly generated field."*

That is not a style note. `tAltI` (Alt+I, "Increment number") is what happens
when it is not followed -- it addressed an LCL `TEdit` through
`GetDlgItemInt(tr4whandle, EXCHANGEWINDOWID, ...)`, the lookup failed, and the
routine did **nothing at all**. No error, no compiler warning, no lint. A
silent no-op is the characteristic failure of reaching an LCL control through
the Win32 API, and the only way to catch it is to know exactly which control
each handle names.

Generated from the source, not written by hand -- regenerate rather than trust:
the counts are `wh[mweX]` references across `src`, and "created by" is read from
`CreateMainWindow`.

## The three classes

**`wh` is `array[TMainWindowElement] of HWND` (`VC.pas:779`)** -- the Win32
registry for the main window, and the thing that has to go. 160 references,
24 elements actually used, of which:

1. **Four have an LCL object today.** The object is already created and already
   assigned; nothing reads it yet. `CreateTR4WEntryField` says so in its own
   comment: *"THE OBJECT IS KEPT, not only its handle. Nothing reads these two
   yet."* These are the conversions that can be done now.
2. **`mweEditableLog` waits for SQLite** -- 38 references, the largest single
   block, and deliberately deferred (ROADMAP section 2, decided 2026-08-22).
3. **The rest are raw Win32 STATICs** built by one generic loop in
   `CreateMainWindow` (`MainUnit.pas:3439`) from the `TWindows` table. They are
   display labels: the loop skips any element with `mweiStyle <= 2` -- which is
   how call, exchange and the possible-call list get created explicitly
   instead -- and everything else becomes `tCreateStaticWindow`. They become
   `TLabel`s on the form, and that is a batch of its own.

## The table

| uses | element | caption | created by | LCL object today |
|---:|---|---|---|---|
| 38 | `mweEditableLog` | EDITABLE LOG | CreateEditableLog | **none** |
| 29 | `mweCall` | CALL | CreateCallOrExchangeWin | TR4WCallEdit : TEdit |
| 23 | `mweExchange` | EXCHANGE | CreateCallOrExchangeWin | TR4WExchangeEdit : TEdit |
| 17 | `mweStations` | STATIONS | tCreateStaticWindow (the generic loop) | **none** |
| 11 | `mwePossibleCall` | POSSIBLE CALL | CreateTR4WPossibleCallList | TR4WMainForm.lstPossibleCall : TListBox |
| 5 | `mweQuickCommand` | QUICK COMMAND | tCreateStaticWindow (the generic loop) | **none** |
| 5 | `mweNetwork` | NETWORK | tCreateStaticWindow (the generic loop) | **none** |
| 4 | `mweRadioOne` | RADIO ONE NAME | tCreateStaticWindow (the generic loop) | **none** |
| 4 | `mweRadioTwo` | RADIO TWO NAME | tCreateStaticWindow (the generic loop) | **none** |
| 3 | `mweWSJTX` | ? | ? | **none** |
| 2 | `mweNewMultStatus` | MULT | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweMasterStatus` | MASTER | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweAutoSendCount` | ARROW | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweRadioOneFreq` | RADIO ONE FREQ | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweRadioTwoFreq` | RADIO TWO FREQ | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweDupeInfoCall` | DUPE INFO CALL | tCreateStaticWindow (the generic loop) | **none** |
| 2 | `mweUserInfo` | USER INFO | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mweWholeScreen` | WHOLE SCREEN | tr4whandle | TR4WMainForm (the form itself) |
| 1 | `mweQSONumber` | QSO NUMBER | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mwePTTStatus` | PTT | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mweWinKey` | WINKEYER | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mweQSOB4Status` | QSO B4 | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mwePaddle` | PADDLE | tCreateStaticWindow (the generic loop) | **none** |
| 1 | `mweFootSwitch` | FOOT SWITCH | tCreateStaticWindow (the generic loop) | **none** |

## How to do one, using tAltI as the worked example

**1. Find what the old code actually addressed, by BOTH routes.** A read and a
write may not target the same control, and the identifier is not evidence:

    read : GetDlgItemInt(tr4whandle, EXCHANGEWINDOWID, ...)
           -> EXCHANGEWINDOWID = 88 (VC.pas:475), and 88 is the id passed to
              CreateCallOrExchangeWin for the EXCHANGE field (MainUnit.pas:3508)
    write: SetMainWindowText(mweExchange, ...)
           -> SetWindowTextW(wh[mweExchange], ...) (TF.pas:976)

Both the exchange edit. Only then is the replacement object known.

**2. Check the D7 tree.** `C:\TR4W` is the authority on what the old program
did. `tAltI` there is byte-identical, which established that targeting the
exchange field is ORIGINAL behaviour and the port had not moved it -- so the
fix was to restore it, not to redesign it.

**3. Map to the object from the SAME creation call**, not by name:
`CreateCallOrExchangeWin(..., efExchange)` is what both fills `wh[mweExchange]`
and assigns `TR4WExchangeEdit`. Same call, same control, provably.

**4. Translate the idioms:**

| Win32 | LCL |
|---|---|
| `GetDlgItemInt(parent, id, ...)` | `TryStrToInt(edit.Text, v)` |
| `SetWindowTextA(wh[x], p)` | `edit.Text := s` |
| `SendMessage(wh[x], EM_SETSEL, a, b)` | `edit.SelStart` / `edit.SelLength` |
| `SetFocus(wh[x])` | `edit.SetFocus` |
| `PlaceCaretToTheEnd(wh[x])` | `edit.SelStart := Length(edit.Text)` |

**5. Keep the formatting.** `tAltI` wrote `' %u'` -- a LEADING SPACE. Every
other writer of that field matches it, so dropping it would have shifted the
exchange by one character only when Alt+I was used.

## One question this document exists to answer

**"Why would Alt+I have anything to do with the exchange window? The field it
updated is the number to the left of the callsign."**

The number to the left of the callsign is `mweQSONumber`, and it is **not what
Alt+I writes to**:

* it is created by the generic loop as a raw Win32 STATIC (`defStyle` includes
  `WS_VISIBLE`, so it is far above the loop's `<= 2` skip test) -- a display
  label, not an editable field;
* the only thing that writes it is `DisplayNextQSONumber`
  (`LOGWIND.PAS:1496`), which renders `NextSerialToSend` -- the serial TR4W is
  about to send;
* so anything else written into it would be replaced the next time that runs,
  and it could not hold an operator's edit.

`tAltI` reads control id 88 and writes `wh[mweExchange]` -- the exchange edit,
in this tree and identically in D7. The likely purpose is hand-entry after a
contest, the same use the manual gives for AUTO TIME INCREMENT: *"If you are
entering a log by hand, the AUTO TIME INCREMENT feature can be very useful."*
Received serials usually run consecutively, so Alt+I bumps the one you typed.

If the intended behaviour really is to change the serial TR4W SENDS, that is a
different change and a larger one: it would have to move `NextSerialToSend`,
not write text into a label.
