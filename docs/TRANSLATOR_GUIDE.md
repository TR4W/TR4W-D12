# Translating TR4W

Thank you for doing this. TR4W is a contest logger used at speed, often at three in
the morning, and a good translation is the difference between an operator reading a
window and hunting through it.

You need one program and one file. You do not need TR4W itself, and you cannot break
anything: nothing you send back reaches the program until it has been checked.

---

## 1. Install Poedit

Download from **<https://poedit.com/download/>**

**The free version is all you need.** Poedit offers a paid "Pro" upgrade for
translation memory and machine translation. Nothing in this job requires it — decline
the upgrade and carry on.

Windows, macOS and Linux are all fine.

## 2. Open the file you were sent

You will have received a `.po` file, for example `tr4w_es.po`. Double-click it, or
**File → Open** in Poedit.

You will see a list of English phrases with a column for your language. That is the
whole job: fill in the second column.

## 3. What the marks mean

| what you see | what it means |
|---|---|
| **orange / "Needs work"** | a machine produced a first draft. **Read it — it is often wrong.** Correct it, then clear the flag |
| blank | nobody has translated this yet |
| plain, no mark | already reviewed by a person. Leave it unless it is wrong |

**Clearing "Needs work" is how you approve a string.** In Poedit it is the
✓ **Needs Work** toggle on the toolbar, or **Ctrl+U**. A string still marked "Needs
work" **will not appear in the program** — that is deliberate, so an unreviewed
machine guess can never reach an operator.

So: a string is only finished when it has your text *and* the flag is off.

## 4. The machine drafts are worse than they look

They were produced by an automatic translator that knows nothing about amateur radio.
A real example from the Spanish first pass:

> `Dupe Check On Inactive Radio` → *"Control de tuberías en radio inactivo"*

**"tuberías" is plumbing.** The machine read "dupe" as pipework.

Contest vocabulary is where it will be confidently wrong. Words to watch:

**dupe** (a duplicate contact) · **mult** (multiplier) · **exchange** (the information
swapped during a contact) · **run** and **S&P** (search and pounce) · **QSY** (change
frequency) · **spot** · **band map** · **serial number** · **sprint**

If your language's contesting community has a settled word, use it. If it normally
uses the English term — many do — **keep the English term**. An operator who has read
English contest software for twenty years is not helped by a literal translation
nobody says out loud.

## 5. Three things you must not change

Poedit will warn about most of these, but please watch for them.

**`%s`, `%d`, `%u`, `%.2f` and similar.** These are placeholders the program fills in
at run time — a callsign, a count, a frequency.

> `You already worked %s in %s!!`

Keep **every one**, and keep them **in the same order**. If your language needs a
different word order and you cannot keep the order, tell us rather than dropping one:
a missing placeholder can crash the program, not merely misprint.

**Line breaks inside a message.** Some messages are several lines in one entry. In
Poedit these appear as actual new lines in the text box. Keep them where they are —
deleting one runs two sentences together, adding one splits a sentence in half.

**`&` before a letter**, as in `&File`. That marks the keyboard shortcut. Keep one `&`
somewhere sensible in your translation, ideally before a letter that is not already
used elsewhere in the same menu.

## 6. Things not worth translating

Leave these as they are:

- `F1` … `F12` and other key names
- `http://www.tr4w.net` and any other address
- `CW`, `SSB`, `RTTY`, `RST`, `QSO`, `DX` — these are international
- Program and file names: `TR4W`, `CTY.DAT`, `TRMASTER.DTA`, `libeay32.dll`
- `599`, `59` and other signal reports

## 7. Length

Screen space is fixed. A button that says `Clear` has room for about that much.
Where a translation would be much longer than the English, prefer the shorter
natural wording. If it genuinely cannot be shortened, translate it properly and
mention it — the window can usually be adjusted.

## 8. When you are done

**File → Save.** Send back the same `.po` file. Nothing else — no ZIP needed unless
your mail system insists, and please do not rename it.

You do not have to finish. A partly translated file is genuinely useful: the strings
you approved go in, the rest stay English until someone gets to them. If you would
rather do the most visible parts first, the entries whose names begin `tprefsform`
are the Preferences window and `tfrm…` are the various dialogs.

**If something is ambiguous, ask.** "Clear" could be a button that clears a list or
an adjective describing conditions, and the English does not say which. A question
costs a minute; a wrong guess is read by every operator using your language.

---

## A note on what happens next

Your file is checked automatically for the three things above — missing placeholders,
changed line breaks, entries left in an odd state — and then the strings you approved
are compiled into the program. They appear the next time it is built.

If the check finds something, we will come back to you with the specific line rather
than guessing at what you meant.
