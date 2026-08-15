import io
import re

src = open(r'C:\tr4w-d12\tools\cfg_remaining_rows.py').read()
exec(src.split('agree_event =')[0])

CONTEST_PATTERNS = [
    r'^CONTEST$', r'^CONTEST NAME$', r'^CONTEST TITLE$', r'^CALL OK NOW ',
    r'^CLEAR DUPE SHEET$',
    # NY4I 2026-08-15: "cq exchange was an omission. it is a macro." The
    # mode-neutral pair joins the CW and SSB ones. NOT a blanket ^CQ -- CQ MENU
    # is a menu, not a message.
    r'^CQ EXCHANGE', r'^CQ CW ', r'^CQ SSB ', r'^DOMESTIC FILENAME$',
    r'^DOMESTIC MULTIPLIER$', r'^DX MULTIPLIER$', r'^PREFIX MULTIPLIER$',
    r'^ZONE MULTIPLIER$', r'^EXCHANGE RECEIVED$', r'^LATEST CONFIG FILE$',
    r'^MULT BY BAND$', r'^MULT BY MODE$', r'^QSL MESSAGE$', r'^QSL CW MESSAGE$',
    r'^QSL SSB MESSAGE$', r'^QSO BEFORE ', r'^QSO BY BAND$', r'^QSO BY MODE$',
    r'^QSO POINT', r'^QUICK QSL ', r'^R150S MODE$', r'^RFOBL MODE$',
    r'^REPEAT ', r'^S&P ', r'^SHORT \d+$', r'^SINGLE BAND SCORE$',
    # NY4I 2026-08-15: "This does not currently consider that a contest level
    # but I do so it goes there." Which settles the HF/WARC/VHF inconsistency --
    # all three are contest-scoped, and WARC's crC:0 is simply wrong.
    r'^HF BAND ENABLE$', r'^WARC BAND ENABLE$', r'^VHF BAND ENABLE$',
    # NY4I 2026-08-15: "band is the startup band but since fcontest uses it, it
    # goes on the contest." Note the REASONING -- what the setting means matters
    # less than who writes it; a startup value a contest overwrites cannot be a
    # station setting whatever it is called.
    r'^BAND$',
]
PAT = re.compile('|'.join(CONTEST_PATTERNS))

contest = sorted([r['cmd'] for r in rows if PAT.match(r['cmd'])])
migrate = [r for r in rows if not PAT.match(r['cmd'])]
conflict = sorted([r for r in migrate if r['fc'] or r['crC'] == 1],
                  key=lambda x: (-x['fc'], x['cmd']))


def conflict_table(rs):
    out = ['| command | `crC` | `FCONTEST` writes | in real `.cfg` |',
           '|---|---|---|---|']
    for r in rs:
        out.append('| `%s` | %d | %s | %s |'
                   % (r['cmd'], r['crC'],
                      ('**%d×**' % r['fc']) if r['fc'] else '—',
                      len(r['cfg']) or '—'))
    return '\n'.join(out)


section = """
## Contest scope — NY4I's classification (2026-08-15)

**This is the authoritative answer to "which commands belong to a contest".** It supersedes guessing
from names, and it is what the migration works from: everything NOT on this list *"should go into
the registry and not exist in this Ctrl-J any longer"* (NY4I).

`crC` was the closest thing to this attribute and it is **not reliable** — see the conflicts below.

**Ruled 2026-08-15:** `HF BAND ENABLE`, `WARC BAND ENABLE` and `VHF BAND ENABLE` are contest-level.
NY4I: *"This does not currently consider that a contest level but I do so it goes there."* That also
settles an inconsistency in the table — `HF` and `VHF` are `crC:1` while `WARC` is `crC:0`, for three
settings handled identically, so **`WARC BAND ENABLE` should become `crC:1`** as a data fix.

### The contest set — %d of the %d rows still `csOld`

%s

Marked **(macro)** by NY4I, meaning a CW/SSB message template: `CALL OK NOW *`, `CQ CW *`,
`CQ SSB *`, `QSL *`, `QSO BEFORE *`, `QUICK QSL *`, `REPEAT *`, `S&P *`. **These come last** — the
macro definitions are contest-scoped but their design is deferred, so nothing should migrate or
re-home them yet.

Three on his list are already `csNew` rather than `csOld` and so need no action: `LATEST CONFIG
FILE`, `R150S MODE`, `RFOBL MODE`.

### %d rows to migrate to the registry

Everything else still `csOld`. They leave Ctrl-J, stop being read from and written to `tr4w.ini`,
and their globals move into the config object.

### %d of those are contest-driven ANYWAY — this needs a ruling

Not on NY4I's list, but `FCONTEST.PAS` assigns them when a contest is selected, or they are declared
`crC:1`. **Migrating one as a flat station setting gives Preferences an editor whose value is
silently replaced at the next contest selection.** It is the same problem as the three band-enable
rows just ruled on, and those were not the only ones.

%s

`BAND` and `MODE` are the extreme cases — 29 and 9 `FCONTEST` writes — and are arguably not settings
at all but *current operating state* that a contest initialises, the same category as `CODE SPEED`.

**Until this is ruled on they are held back and the other %d proceed.** Splitting the batch costs
nothing; migrating a contest-owned row costs a defect that only shows up when someone changes
contest.

### Macro siblings

**Answered 2026-08-15:** *"cq exchange was an omission. it is a macro."* `CQ EXCHANGE` and
`CQ EXCHANGE NAME KNOWN` are in the contest set with the CW and SSB members. The pattern is
`^CQ EXCHANGE` and not a blanket `^CQ ` — `CQ MENU` is a menu, not a message.

**Still unplaced:** `TAIL END MESSAGE` / `TAIL END CW MESSAGE` / `TAIL END SSB MESSAGE`, the same
shape of macro and on no list. `MULTI INFO MESSAGE` is a message but a multi-op one, not a contest
exchange.

"""
section = section % (len(contest), len(rows),
                     '\n'.join('* `%s`' % c for c in contest),
                     len(migrate), len(conflict), conflict_table(conflict),
                     len(migrate) - len(conflict))

p = r'C:\tr4w-d12\docs\CFG_COMMAND_TABLE.md'
t = io.open(p, encoding='utf-8', errors='surrogateescape', newline='').read()

# IDEMPOTENT. Running this over a file that already carries the section used to
# insert a second copy, which is what happened once already -- the document had
# the whole classification twice, with the older copy still saying an answered
# question was open.
start = t.find('## Contest scope')
if start != -1:
    t = t[:start] + t[t.index('### `crP` — post-change UI refresh', start):]

anchor = '### `crP` — post-change UI refresh'
assert t.count(anchor) == 1
t = t.replace(anchor, section.lstrip('\n') + '\n' + anchor, 1)
io.open(p, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(t)
print('  CFG_COMMAND_TABLE.md updated')
print('  contest set %d / migrate %d / needs a ruling %d'
      % (len(contest), len(migrate), len(conflict)))
