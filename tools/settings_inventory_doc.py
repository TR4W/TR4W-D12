import json
import os
import re
import sys
sys.path.insert(0, r'C:\tr4w-d12\tools')
import srcfile

SCRATCH = os.path.dirname(os.path.abspath(__file__))
OUT = r'C:\tr4w-d12\tr4w\docs\SETTINGS_INVENTORY.md'
FROZEN = r'C:\tr4w-d12\tr4w\test\unit\uTestSettingsModel.pas'

inv = json.load(open(os.path.join(SCRATCH, 'inv.json')))
moved = sorted(inv['moved'], key=lambda r: r['command'])
pending = sorted(inv['pending'], key=lambda r: r['command'])


# THE NOTES COLUMN IS NY4I'S, AND IT IS CARRIED FORWARD (2026-09-19).
#
# Everything else in the table is reproducible from the source; the notes are
# not. This generator used to write every Notes cell empty, so regenerating
# the file erased them. Now the existing file is read first, each note is kept
# against its command, and a note whose row has gone -- a setting retired or
# renamed -- is not dropped: it is listed under "Notes whose row has gone" and
# printed, so a person decides what happens to it.
def existing_notes(path):
   notes = {}
   if not os.path.exists(path):
      return notes
   for line in srcfile.read(path).replace('\r\n', '\n').split('\n'):
      if not line.startswith('| `'):
         continue
      # An escaped pipe is part of a cell, not a boundary.
      cells = [c.strip() for c in re.split(r'(?<!\\)\|', line.strip())[1:-1]]
      if len(cells) < 2:
         continue
      command = cells[0].strip('`').replace(r'\|', '|')
      if cells[-1]:
         notes[command] = cells[-1]
   return notes


notes = existing_notes(OUT)


# THE CHECK THE REGENERATION NOTE PROMISES, made rather than asserted. The
# frozen vocabulary in uTestSettingsModel is read out of the live settings
# object by a test, so if this generator and it disagree, THE GENERATOR IS
# WRONG -- and it stops rather than writing a table that says otherwise.
def frozen_vocabulary(path):
   text = srcfile.read(path)
   return set(m.group(1) or m.group(2) for m in re.finditer(
      r"^\s*\+ '(?:\"([^\"]+)\"|([A-Z0-9][^,']*))[,']", text, re.M))


generated = set(r['command'] for r in moved)
for r in moved:
   for a in r['aka'].split(','):
      if a.strip():
         generated.add(a.strip())
frozen = frozen_vocabulary(FROZEN)
if generated != frozen:
   print('GENERATOR DISAGREES WITH THE FROZEN VOCABULARY -- the generator is wrong')
   print('  generated only:', sorted(generated - frozen))
   print('  frozen only   :', sorted(frozen - generated))
   sys.exit(1)

# Why each pending row is still where it is. Keyed by command, or by a prefix
# for the two families. Anything unlisted gets the empty reason, which is
# itself information: nothing is stopping it.
BLOCKED = {}
for c in ('RADIO ONE', 'RADIO TWO'):
   BLOCKED[c] = ('radio library -- CheckCommand is the transport for these, '
                 'so they move with that track')
for c in ('WK ',):
   BLOCKED[c] = 'keyer library -- same shape as the radio rows'

EXACT = {
   'HAMSCORE USERNAME': 'keychain -- case-sensitive, see the note below',
   'HAMSCORE PASSWORD': 'keychain -- a credential, see the note below',
   'SERVER PASSWORD': 'keychain -- a credential, see the note below',
   'CW ENABLE': 'live session state -- control codes change it mid-message',
   'CW TONE': 'live session state -- changed by a control code',
   'FARNSWORTH ENABLE': 'live session state',
   'FARNSWORTH SPEED': 'live session state',
   'WEIGHT': 'live session state',
   'CODE SPEED': 'live session state -- a global for ALL keyers, not a setting',
   'STEREO PIN HIGH': 'live session state -- a keystroke toggles it',
   'CW SPEED INCREMENT': 'NOT blocked -- next to move, to Settings.Cw',
   'DVK ENABLE': 'crP: 7 wants a window seam that does not exist yet',
   'DVK PATH': 'path type -- what a path setting validates is undecided',
   'DVK RECORDER': 'path type -- same ruling',
   'BACKUP LOG FILE NAME': 'path type -- same ruling',
   'INITIAL EXCHANGE FILENAME': 'path type -- same ruling',
   'LPT1 BASE ADDRESS': 'port identity track',
   'LPT2 BASE ADDRESS': 'port identity track',
   'LPT3 BASE ADDRESS': 'port identity track',
   'PADDLE PORT': 'port identity track',
   'RELAY CONTROL PORT': 'port identity track',
   'STEREO CONTROL PORT': 'port identity track',
   'R150S MODE': 'a field of the CTY record that a leaf unit reads directly',
   'RFOBL MODE': 'a field of the CTY record that a leaf unit reads directly',
   'SCP COUNTRY STRING': 'a field of the SCP database object, read by bare name',
   'CONNECTION COMMAND': 'the cluster library writes it -- two models to merge',
   'CONTEST NAME': 'derived by FCONTEST at run time, and carries a hook',
   'CONTEST TITLE': 'derived by FCONTEST at run time from the year and name',
   'ADD DOMESTIC COUNTRY': 'an accumulating LIST, not a value',
   'FREQUENCY MEMORY': 'an accumulating LIST, not a value',
   'BAND MAP CUTOFF FREQUENCY': 'an accumulating LIST, not a value',
   'CLEAR DUPE SHEET': 'an ACTION, not a setting',
   'POLL RADIO ONE': 'radio library -- a field of the radio record',
   'POLL RADIO TWO': 'radio library -- a field of the radio record',
}


def reason_for(cmd):
   if cmd in EXACT:
      return EXACT[cmd]
   for pre, why in BLOCKED.items():
      if cmd.startswith(pre):
         return why
   return ''


def esc(s):
   return s.replace('|', r'\|')


def note_for(cmd):
   # pop, so what is left afterwards is exactly the notes with no row.
   return notes.pop(cmd, '')


L = []
A = L.append

A('# TR4W settings inventory')
A('')
A('Every setting TR4W accepts, where its value lives, and whether it belongs')
A('to the STATION or to the CONTEST.')
A('')
A('**The Notes column is yours.** Write `move` in it for anything filed in the')
A('wrong place and I will move it; write a confirmation for anything you have')
A('checked. The rest of the table is generated, so do not hand-edit it -- see')
A('the note on regeneration at the bottom.')
A('')
A('## What the two scopes mean, because the distinction is the point')
A('')
A('**global** -- a property of the STATION. It lives in `settings/tr4w.json`,')
A('survives every contest, and is the same whatever you are operating. A')
A('callsign, a keyer port, a cluster host.')
A('')
A('**CONTEST** -- a property of the CONTEST. It is captured into the contest')
A('database and deliberately kept OUT of the station settings file, because')
A('the contest chooses it and nothing sets it back afterwards. Whether a')
A('multiplier counts per band, what a QSO is worth, which bands are in play.')
A('')
A('The test for which one a setting is: **if the contest file assigns it and')
A('nothing ever restores it, it is the contest\'s.** That is why the band')
A('enables are contest-scoped even though they look like station preferences --')
A('the contest definition assigns all three the moment a contest loads.')
A('')
A('## A name that misleads, and is on its way out')
A('')
A('`Config.<field>` in the source is **not** the contest config. It is a global')
A('record variable holding station settings, and it exists only because the')
A('config array is a table of ADDRESSES -- a record field has one at link time')
A('where a property does not. It is a staging post: every row that reaches the')
A('settings model leaves the record, and it is down to a handful of fields.')
A('Read `Config.X` as "a station setting that has not finished moving yet".')
A('')

A('## Settings that have moved (%d)' % len(moved))
A('')
A('These are published properties. The command name is DERIVED from the')
A('property path unless an alias says otherwise, and an alias exists only')
A('where the historic name cannot be derived -- a hyphen, a subject that')
A('comes last, a word run together.')
A('')
A('| Command | Also accepted as | Scope | Lives at | Type | Notes |')
A('|---|---|---|---|---|---|')
for r in moved:
   A('| `%s` | %s | %s | `%s` | %s | %s |'
     % (esc(r['command']),
        ('`%s`' % esc(r['aka'])) if r['aka'] else '',
        '**CONTEST**' if r['scope'] == 'CONTEST' else 'global',
        esc(r['where']), esc(r['type']),
        note_for(r['command'])))
A('')

if pending:
   A('## Settings still in the config array (%d)' % len(pending))
   A('')
   A('Each of these still writes through a table of addresses. The **Why still')
   A('here** column is the reason it has not moved; an empty one means nothing is')
   A('stopping it and it is simply next in line.')
   A('')
   A('The **Written to a contest file** column is the config array\'s own flag for')
   A('whether a value was ever saved into a contest `.cfg`. Treat it as a HINT and')
   A('not as the answer: nothing in the program reads that flag any more, so it')
   A('records what somebody intended years ago rather than what happens now. It is')
   A('here because it is evidence, and because where it disagrees with your')
   A('instinct one of the two is worth looking at.')
   A('')
   A('| Command | Written to a contest file | Type | Why still here | Notes |')
   A('|---|---|---|---|---|')
   for r in pending:
      A('| `%s` | %s | %s | %s | %s |'
        % (esc(r['command']),
           'yes' if r['contest_file'] else 'no',
           esc(r['type']),
           esc(reason_for(r['command'])),
           note_for(r['command'])))
   A('')
else:
   A('## Settings still in the config array: none')
   A('')
   A('The config array (`CFGCA`) was deleted on 2026-09-14. Every setting above')
   A('is a published property; a withdrawn command is a NAME in')
   A('`uCFG.RETIRED_COMMANDS`, accepted and ignored so an old file does not')
   A('raise "invalid statement in config file".')
   A('')

A('## The credentials')
A('')
A('A credential is a `TSecretText` property. The settings file holds only')
A('`<Name>Ref`, the setting\'s name; the value lives in the operating system\'s')
A('vault (`uKeychain`), is masked in Preferences, and is never sent to a')
A('multi-op peer -- all four from the one declaration.')
A('')

if notes:
   A('## Notes whose row has gone')
   A('')
   A('Kept, not dropped: each of these was written in the Notes column of a row')
   A('that no longer exists -- a setting retired or renamed since. Move it, act on')
   A('it, or delete it; the generator will not do either for you.')
   A('')
   A('| Command | Notes |')
   A('|---|---|')
   for cmd in sorted(notes):
      A('| `%s` | %s |' % (esc(cmd), notes[cmd]))
   A('')

A('## Regenerating this')
A('')
A('It is generated from `uSettingsModel.pas` and `uCFG.pas`, and validated')
A('against the frozen command vocabulary in `uTestSettingsModel.pas` -- which')
A('is read out of the live settings object, so if the generator and the program')
A('ever disagree, the generator is wrong. `tools/settings_inventory_doc.py`')
A('makes that comparison every time it runs and refuses to write this file')
A('when the two differ; when this file was written they agreed exactly on all')
A('%d command names.' % len(frozen))
A('')
A('Run `tools/settings_inventory.py`, then `tools/settings_inventory_doc.py`.')
A('')
A('**The Notes column is carried forward when regenerating**: the generator')
A('reads this file first and puts each note back against its command. A note')
A('whose row has gone is listed under "Notes whose row has gone" rather than')
A('dropped.')

open(OUT, 'wb').write((chr(10).join(L) + chr(10)).replace(chr(10), chr(13)+chr(10)).encode('utf-8'))
print('wrote', OUT)
print('moved rows  :', len(moved))
print('pending rows:', len(pending))
print('orphaned notes:', len(notes))
for cmd in sorted(notes):
   print('   %s: %s' % (cmd, notes[cmd]))
