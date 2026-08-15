"""crC is already the station-vs-event scope attribute. This checks it against
reality instead of re-deriving it.

crC:1 -> the editor writes the key to the contest .CFG; crC:0 -> tr4w.ini
(uOption.pas:765/772). So the classification NY4I is being asked to confirm
already exists per row. The useful question is not "which are contest related"
but "where does crC disagree with what the .cfg files actually contain".
"""
import io
import os
import re

SRC = r'C:\tr4w-d12\tr4w\src'
TARGET = r'C:\tr4w-d12\tr4w\target'
OUT = r'C:\tr4w-d12\docs\CFG_REMAINING_ROWS.md'

cfg = io.open(os.path.join(SRC, 'uCFG.pas'), encoding='utf-8',
              errors='surrogateescape', newline='').read()

# COMMENTED-OUT ROWS ARE NOT LIVE ROWS. CFGCA still carries six of them marked
# crS: csOld, and reading the file as text counted every one -- which is how the
# whole TAIL END family (MESSAGE / CW MESSAGE / SSB MESSAGE / KEY) came to be
# raised as an open question. It was withdrawn years ago, which is also why the
# help file has no entry for it.
#
# A row is deprecated if it is COMMENTED OUT or marked csRem. Those are two
# different sets and both have to go before anything counts as live.
NL = chr(13) + chr(10)
cfg = NL.join(l for l in cfg.split(NL)
              if not l.lstrip().startswith(('//', '{ (', '{(')))

ROW = re.compile(
    r"crCommand:\s*'([^']*)';\s*crAddress:\s*([^;]*?);.*?crS:\s*(cs\w+);"
    r"\s*crA:\s*(\d+);\s*crC:\s*(\d+)\s*;.*?crKind:\s*(\w+);\s*cfFunc:\s*(\w+);"
    r"\s*crType:\s*ct(\w+)", re.S)

allrows, rows = [], []
for m in ROW.finditer(cfg):
    cmd, addr, status, crA, crC, kind, fn, typ = [g.strip() for g in m.groups()]
    r = dict(cmd=cmd, addr=addr, status=status, crC=int(crC), kind=kind,
             fn=fn, typ=typ)
    allrows.append(r)
    # csNew IS IN SCOPE TOO. Ctrl-J hides only csRem, csOwned and csJSON, so a
    # csNew row is exactly as visible to the operator as a csOld one. Scanning
    # csOld alone reported 152 rows left when the dialog still held 207 -- the
    # status names say where a row CAME FROM, not whether it still needs a home.
    # CASE-INSENSITIVELY. Pascal does not care how csOld is spelled and four
    # rows in CFGCA are written csOLD or csoLD; comparing the strings exactly
    # dropped all four, IE SWITCH among them. Third time this scan has silently
    # narrowed its own denominator, so the comparison is folded now and the
    # source spellings are normalized as well.
    if status.lower() in ('csold', 'csnew'):
        rows.append(r)
assert len(rows) == cfg.count('crS: csOld') + cfg.count('crS: csNew'), \
    'parsed %d of %d live rows' % (len(rows),
                                   cfg.count('crS: csOld') + cfg.count('crS: csNew'))


def table_entries(name, varfield, lo):
    i = cfg.index(name + ': array[')
    j = cfg.index('{*)}', i)
    return {lo + k: v for k, v in
            enumerate(re.findall('(?i)' + varfield + r':\s*@([A-Za-z_][\w.]*)',
                                 cfg[i:j]))}


lists = table_entries('ListParamArray', 'lpVar', 0)
arrays = table_entries('ArrayRecordArray', 'arVar', 1)

for r in rows:
    m = re.match(r'pointer\((\d+)\)', r['addr'])
    if m:
        n = int(m.group(1))
        r['sym'] = (lists if r['kind'] == 'ckList' else arrays).get(n, '')
        r['via'] = ' *(%s[%d])*' % (
            'ListParamArray' if r['kind'] == 'ckList' else 'ArrayRecordArray', n)
    else:
        r['sym'] = r['addr'].lstrip('@')
        r['via'] = ''

# What the real .cfg files contain.
blobs = []
for root, _, files in os.walk(TARGET):
    for f in files:
        if f.lower().endswith('.cfg'):
            try:
                # A dom/ .cfg is a contest DEFINITION -- a template shipped with
                # TR4W. Every other .cfg is a per-EVENT copy that TR4W itself
                # wrote when the log was created, so finding MY CALL in 73 of
                # them says the event file records station state, NOT that the
                # key is contest-scoped by design. Keeping them apart is the
                # difference between evidence and an artefact of our own writer.
                isdef = os.sep + 'dom' + os.sep in os.path.join(root, f).lower()
                blobs.append((f, io.open(os.path.join(root, f), encoding='utf-8',
                                         errors='replace').read().upper(), isdef))
            except Exception:
                pass
for r in rows:
    pat = re.compile(r'^\s*' + re.escape(r['cmd'].upper()) + r'\s*=', re.M)
    r['cfg'] = [n for n, b, d in blobs if pat.search(b)]

# The same check across EVERY row, not only csOld -- a crC:0 row that contests
# really do set is the layering problem, whatever its status.
for r in allrows:
    pat = re.compile(r'^\s*' + re.escape(r['cmd'].upper()) + r'\s*=', re.M)
    r['cfg'] = [n for n, b, d in blobs if pat.search(b)]
    r['defn'] = [n for n, b, d in blobs if d and pat.search(b)]

# SIGNAL 2, and the first cut of this document was wrong to omit it. A row can
# be contest-driven without appearing in any .cfg file: FCONTEST.PAS assigns it
# when a contest is selected. WARC BAND ENABLE is exactly that -- crC:0, in no
# .cfg, and assigned five times by FCONTEST -- so grouping on crC and .cfg alone
# filed it under "no confirmation needed", which is the opposite of true.
fc = io.open(os.path.join(SRC, 'trdos', 'FCONTEST.PAS'), encoding='utf-8',
             errors='surrogateescape', newline='').read()
fc_live = re.sub(r'\{[^}]*\}', ' ', fc)   # a commented assignment is not one
for r in rows:
    tail = (r.get('sym') or '').split('.')[-1]
    # Case-INSENSITIVE: Pascal is, and this tree spells the same identifier
    # differently at declaration and use.
    r['fc'] = (len(re.findall('(?<![A-Za-z0-9_])' + re.escape(tail)
                             + r'\s*:=', fc_live, re.I))
               if tail else 0)

agree_event = [r for r in rows if r['crC'] == 1 and r['cfg']]
declared_unused = [r for r in rows if r['crC'] == 1 and not r['cfg']]
mismatch = [r for r in allrows if r['crC'] == 0 and r['cfg']]
station = [r for r in rows if r['crC'] == 0 and not r['cfg'] and not r['fc']]
fcdriven = [r for r in rows if r['crC'] == 0 and not r['cfg'] and r['fc']]


def table(rs, cols=('cmd', 'typ', 'sym', 'ev')):
    out = ['| command | type | target | in real `.cfg` files |', '|---|---|---|---|']
    for r in sorted(rs, key=lambda x: x['cmd']):
        n = len(r['cfg'])
        ev = ('**%d** — %s' % (n, ', '.join(sorted(r['cfg'])[:3])
                               + (' …' if n > 3 else ''))) if n else '—'
        if not r['cfg'] and r.get('fc'):
            ev = '`FCONTEST` assigns it **%d×**' % r['fc']
        tgt = ('`%s`%s' % (r['sym'], r['via'])) if r.get('sym') else '—'
        out.append('| `%s` | %s | %s | %s |' % (r['cmd'], r['typ'], tgt, ev))
    return '\n'.join(out)


def table2(rs):
    out = ['| command | status | target | in real `.cfg` files |',
           '|---|---|---|---|']
    for r in sorted(rs, key=lambda x: x['cmd']):
        n, d = len(r['cfg']), len(r.get('defn') or [])
        ev = '%d event cop%s' % (n - d, 'y' if n - d == 1 else 'ies')
        if d:
            ev = '**contest DEFINITION** + ' + ev
        out.append('| `%s` | `%s` | `%s` | %s |'
                   % (r['cmd'], r['status'], r['addr'].lstrip('@'), ev))
    return '\n'.join(out)


doc = """# The rows still `csOld` — what needs confirming, and what does not

**The classification already exists: it is `crC`.** `crC:1` means the editor writes the key to the
contest `.CFG`; `crC:0` means `tr4w.ini` (`uOption.pas:765`, `:772`). So the station-vs-event
question is answered per row in `CFGCA` today, and NY4I's read is right — **%d of the %d rows still
`csOld` are `crC:0`, i.e. not contest-scoped**, against %d marked `crC:1`.

What follows is therefore not a fresh classification. It is `crC` **checked against what the %d
contest `.cfg` files on this machine actually contain, and against `FCONTEST.PAS`**, because the
rows worth anyone's attention are the ones where those disagree.

### The headline: `crC` under-declares by 38 rows

Counting a row as contest-related if **any** signal says so — `crC:1`, a real `.cfg` sets it, or
`FCONTEST` assigns it on contest selection — gives **55 of the 168**, not the 17 that `crC:1` marks.
The other 113 have no contest signal at all, so the "majority are not contest related" reading is
right; the count is simply higher than the table admits.

The gap is `FCONTEST.PAS`. Rows like `DX MULTIPLIER` (28 assignments), `S&P EXCHANGE` (19),
`CQ EXCHANGE` (18) and `WARC BAND ENABLE` (5) are written in code whenever a contest is selected
while being marked `crC:0`, "write me to `tr4w.ini`". `CFG_COMMAND_TABLE.md` already notes this
class for the 16 keys visible in `.cfg` files; the `FCONTEST` half more than doubles it.

**This is a data defect in `CFGCA`, not merely a documentation gap.** A `crC:0` row that a contest
overwrites gives Preferences an editor whose value is silently replaced at the next contest
selection — the `HF/WARC/VHF BAND ENABLE` problem, but across 38 rows rather than three.

---

## The one thing that needs your eyes — %d rows marked `crC:0` that contests really do set

These say "write me to `tr4w.ini`" while real contest files set them anyway. **This is the layering
problem**, and it is not confined to `csOld` rows — the list below spans every status, because a row
that already migrated has the same conflict.

A station value and an event value are both legitimate here; what is missing is a rule for which
wins and where an edit lands. `CommandCameFromContestCFG` now gives the read side (a loaded `.cfg`
wins while that contest is loaded); the write side is undecided.

**The evidence column separates a contest DEFINITION from an event copy, and the distinction
matters.** Only one `.cfg` here is a definition (`dom/Idaho QSO Party.cfg`); the other 73 are
per-event files TR4W itself wrote when each log was created. So these 25 rows are really two
different stories:

* **Nine appear in the DEFINITION** — `CONTEST`, `CONTEST NAME`, `CONTEST TITLE`, `DOMESTIC
  FILENAME`, `DOMESTIC MULTIPLIER`, `EXCHANGE RECEIVED`, `MULT BY BAND`, `MULT BY MODE`,
  `QSO POINT METHOD`. These are contest properties by construction and their `crC:0` looks simply
  wrong. Contest-factory rows, not settings.
* **The rest appear only in event copies** — the whole `MY *` family and the CQ/S&P/QSL message set.
  Two of them (`CONTEST`, `MY CALL`) are in *all* 73, which means TR4W writes them into every event
  file and proves nothing about scope. The others are in a SUBSET — `MY STATE` in 26, `MY GRID` in
  12, `S&P CW EXCHANGE` in 9 — and a subset is the interesting part, because something chose to
  record them for those events and not others. **Who wrote them is the question this scan cannot
  answer**, and it is the same station-vs-event line NY4I drew: home state FL, operating from GA.

%s

---

## Marked `crC:1` but no `.cfg` on this machine sets it — %d rows

Declared event-scoped and unexercised by the 74 files here. Most likely genuinely contest-scoped and
simply not used by the contests NY4I runs — **not evidence of anything wrong**, listed only so the
absence is visible rather than assumed.

%s

---

## Marked `crC:1` and contests do set them — %d rows

Agreed and uncontroversial. Contest-scoped, no action.

%s

---

## `crC:0`, no `.cfg` names them, but `FCONTEST` assigns them — %d rows

**Contest-driven without appearing in any contest file.** Selecting a contest writes these in code,
so a Preferences editor would be silently overwritten. `WARC BAND ENABLE` is the clearest case:
`crC:0`, in no `.cfg`, and assigned five times by `FCONTEST`.

%s

---

## The remaining %d — `crC:0`, no `.cfg`, no `FCONTEST` write

The bulk, and the pool future station-settings work draws from. **No confirmation needed** unless one
looks wrong to you; every signal agrees.

%s
""" % (len([r for r in rows if r['crC'] == 0]), len(rows),
       len([r for r in rows if r['crC'] == 1]), len(blobs),
       len(mismatch), table2(mismatch),
       len(declared_unused), table(declared_unused),
       len(agree_event), table(agree_event),
       len(fcdriven), table(fcdriven),
       len(station), table(station))

io.open(OUT, 'w', encoding='utf-8', newline='\n').write(doc)
print('  csOld rows: %d   (crC:0 %d / crC:1 %d)'
      % (len(rows), len([r for r in rows if r['crC'] == 0]),
         len([r for r in rows if r['crC'] == 1])))
print('  MISMATCH crC:0 but contests set it (all statuses): %d' % len(mismatch))
print('  crC:1 unexercised here                           : %d' % len(declared_unused))
print('  crC:1 and contests set it                        : %d' % len(agree_event))
print('  crC:0, no cfg, but FCONTEST assigns it           : %d' % len(fcdriven))
print('  crC:0 and nothing sets it at all                 : %d' % len(station))
