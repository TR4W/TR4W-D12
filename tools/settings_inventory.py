"""Generate the settings inventory from the code.

SECTION-AWARE, because the first version was not and produced two wrong
answers: it swept up ZoneWasSet and CountryWasSet, which sit in a PUBLIC
section and therefore have no run-time type information at all, so the
program does not answer to them as commands. And it missed the unknown
country file group, whose property is declared across two lines.

Validated against the frozen vocabulary in uTestSettingsModel, which is read
out of the live settings object -- if the two disagree, this file is wrong.
"""
import json
import os
import re
import sys
sys.path.insert(0, r'C:\tr4w-d12\tools')
import srcfile

SRC = r'C:\tr4w-d12\tr4w\src'
SCRATCH = os.path.dirname(os.path.abspath(__file__))

model = srcfile.read(os.path.join(SRC, 'uSettingsModel.pas')).replace('\r\n', '\n')
cfg = srcfile.read(os.path.join(SRC, 'uCFG.pas')).replace('\r\n', '\n')


def command_name_of(path):
   out = []
   for i, c in enumerate(path):
      if c == '.':
         if out and out[-1] != ' ':
            out.append(' ')
         continue
      if i > 0 and c.isupper() and not path[i - 1].isupper() and out and out[-1] != ' ':
         out.append(' ')
      out.append(c)
   return ''.join(out).upper()


def published_properties(body):
   """Only what is inside a `published` section, and only settable."""
   found = []
   section = None
   text = body
   # Join a property declaration that wraps onto the next line.
   text = re.sub(r':\s*\n\s+', ': ', text)
   text = re.sub(r'\n\s+(read|write)\b', r' \1', text)
   for line in text.split('\n'):
      s = line.strip()
      low = s.lower()
      if low in ('private', 'public', 'published', 'protected'):
         section = low
         continue
      if section != 'published':
         continue
      m = re.match(r'property\s+(\w+)\s*:\s*(\w+)\s+read\s+\w+(\s+write\s+\w+)?',
                   s, re.I)
      if m:
         found.append((m.group(1), m.group(2), bool(m.group(3))))
   return found


contest_scoped = set()
for m in re.finditer(r'class function (T\w+)\.IsContestScoped: boolean;(.{0,200}?)end;',
                     model, re.S):
   if 'Result := True' in m.group(2):
      contest_scoped.add(m.group(1))

root = model[model.index('   TR4WSettings = class(TPersistent)'):]
root = root[:root.index('\n   end;')]
root_joined = re.sub(r':\s*\n\s+', ': ', root)
group_path = {}
for m in re.finditer(r'property (\w+):\s*(T\w+Settings)\s+read', root_joined):
   group_path[m.group(2)] = m.group(1)

alias = {}
also = {}
for m in re.finditer(r"Alias\('([^']+)',\s*'([^']+)'\)", model):
   alias.setdefault(m.group(2), m.group(1))
for m in re.finditer(r"AlsoKnownAs\('([^']+)',\s*'([^']+)'\)", model):
   also.setdefault(m.group(2), []).append(m.group(1))

moved = []
for m in re.finditer(r'   (T\w+Settings) = class\(TSettingsGroup\)(.*?)\n   end;',
                     model, re.S):
   cls, body = m.group(1), m.group(2)
   if cls not in group_path:
      continue
   for name, typ, settable in published_properties(body):
      if not settable:
         # READ-ONLY IS NOT A COMMAND. Nothing can set it from a config file.
         continue
      path = group_path[cls] + '.' + name
      moved.append({
         'command': alias.get(path, command_name_of(path)),
         'aka': ', '.join(also.get(path, [])),
         'scope': 'CONTEST' if cls in contest_scoped else 'global',
         'where': 'Settings.' + path,
         'type': typ,
      })

pending = []
for line in cfg.split('\n'):
   if not line.startswith(' (crCommand:'):
      continue
   m = re.match(r" \(crCommand: '([^']*)';\s*crAddress:\s*([^;]+);", line)
   if not m:
      continue
   crc = re.search(r'crC\s*:\s*(\d+)', line)
   typ = re.search(r'crType:\s*(\w+)', line)
   pending.append({
      'command': m.group(1),
      'addr': m.group(2).strip(),
      'contest_file': bool(crc) and crc.group(1) == '1',
      'type': typ.group(1) if typ else '',
   })

json.dump({'moved': moved, 'pending': pending},
          open(os.path.join(SCRATCH, 'inv.json'), 'w'), indent=1)
print('moved  :', len(moved))
print('pending:', len(pending))
