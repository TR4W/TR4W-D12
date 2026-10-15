"""Cross-check TR4W's domestic multiplier (.dom) files against DXLog.net.

WHY: a .dom file IS a contest's domestic multiplier list -- which values count,
and which typed inputs reach each one. Nothing in the tree checks those lists
against the sponsor: the golden corpus byte-diffs exports, the contest matrix
pins "same as before", and neither can say "Nova Scotia is missing". DXLog.net
ships 543 independently-maintained contest definition files, so comparing the
two finds the places where one of them is wrong. NY4I, 2026-10-15: "it would
be good to validate our DOM files against the dxlog cfg files and also use
that to help build any new qso parties." A difference is a LEAD, not a
verdict: DXLog is wrong sometimes too, and the sponsor's rules decide.

WHERE THE DATA COMES FROM -- each input is data a program produced or reads,
never a regex over Pascal:

   * WHICH .dom A CONTEST LOADS, PER STATION: the frozen contest matrix,
     tr4w/test/contest-matrix/frozen/<CONTEST>.matrix. Each record has
     station sections ("### variant us: MY CALL=... MY STATE=..."), and in
     each a "setting.DOMESTIC FILENAME = x.dom" line, the
     "multipliersarecounties" flag (an out-of-state QSO-party station counts
     the county itself, FCONTEST) and the Cabrillo "CONTEST:" line. The frozen
     record is only as fresh as its last freeze -- re-freeze before trusting a
     difference that a recent commit might have fixed.
   * THE .dom FILES: tr4w/target/dom/. Read exactly as LOGDOM.EnumDOMFILE
     reads them (src/trdos/logdom.pas):
        - every line is offered; leading spaces/tabs stripped;
        - a line beginning (case-SENSITIVE) "INCLUDE FILE " loads the named
          file from dom/ (the program resolves the name case-insensitively);
        - ANY line containing '=' is an entry, header prose included:
             LEFT = alias, alias, ^Long name
          LEFT is "QTH > MULT" or just "MULT". The MULTIPLIER is MULT, or
          QTH when multipliersarecounties is set (out-of-state party).
          The INPUTS are the aliases, upper-cased; one starting '^' is the
          display name, not an input. LEFT itself is NOT an input.
        - a lookup takes the FIRST alias that matches, in load order, so an
          alias listed under two multipliers silently goes to the first.
   * DXLOG: C:\\Program Files (x86)\\DXLog.net\\Contest\\*.txt (read-only).
        - CABRILLO_CONTEST_NAME, possibly with a {MODE} placeholder;
        - [MULTIPLIERS START] ... [MULTIPLIERS END]: the multiplier list,
          lines "KEY=Name" or "KEY{alias;alias}=Name", or the compact form
          "Group->K3: DE,PA,MD/DC" (each comma item one multiplier, its '/'
          spellings aliases -- an INTERPRETATION, from NA Sprint's
          "NL/LB/NF" and NAQP's lists; DXLog does not document it);
          [VALID FOR=CONFIG->EXCHANGE:<re>] blocks select
          a list by the operator's OWN sent exchange (a two-letter exchange =
          out-of-state station, "DX" for a DX station);
        - CFG_MULT_RGX_CHECK: NOTE, this validates the operator's OWN sent
          QTH in DXLog's contest-configuration dialog (see its
          CFG_MULT_ERRORTEXT), not the received exchange. It is the set of
          values a station of this contest may SEND, so it is still the set a
          logger must ACCEPT -- reported as a secondary check, and used as
          the list when the file has no [MULTIPLIERS] section;
        - MULTn_EXCEPTION=...DEST->RCVD:<re>: the last resort for a party
          whose counties appear nowhere else (KSQP).
     A QSO party's OUT-OF-STATE file is compared against DXLog's
     out-of-state view: the station is given the exchange 'DX', and a list
     that serves every station has its US/VE/DX entries left out.

HOW THE COMPARISON WORKS: by MEANING, not by spelling. TR4W names a mult
"vE7" where DXLog names it "BC", so each DXLog multiplier key (and its
aliases) is typed into TR4W's lookup, and the report says:
   only in DXLog   -- no TR4W input reaches it;
   only in TR4W    -- a TR4W multiplier no DXLog multiplier reaches;
   merged in TR4W  -- several DXLog multipliers land on ONE TR4W multiplier
                      (TR4W counts fewer);
   split in TR4W   -- one DXLog multiplier's spellings land on SEVERAL;
   unreachable     -- a TR4W multiplier with no input at all;
   alias collision -- one input listed under two TR4W multipliers.
DX is reported apart from the rest: it is a DX multiplier in most of these
contests, not a domestic one.

   python tools/dom-crosscheck/crosscheck_dom_dxlog.py              # the report
   python tools/dom-crosscheck/crosscheck_dom_dxlog.py --contest NASPRINTCW
   python tools/dom-crosscheck/crosscheck_dom_dxlog.py --new-party "C:\\...\\IDQP.txt" [--host Id]

--new-party writes a STARTER .dom to stdout for a party TR4W does not have:
INCLUDE FILE lines for the shared state/province files whose multipliers the
DXLog list contains, then one entry per remaining multiplier. It is a start,
not a finished file -- read the sponsor's rules before shipping it.

EXIT: 0 for the report, whatever it finds (it is a report, not a gate). Non-
zero only when an input is missing or implausibly small, so that a run that
read nothing can never print "no differences".
"""

import argparse
import glob
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
MATRIX_DIR = os.path.join(REPO_ROOT, 'tr4w', 'test', 'contest-matrix', 'frozen')
DOM_DIR = os.path.join(REPO_ROOT, 'tr4w', 'target', 'dom')
DXLOG_DIR = r'C:\Program Files (x86)\DXLog.net\Contest'

# FLOORS: below these, an input was not read and the report would lie.
MIN_MATRIX_FILES = 150
MIN_DOM_RECORDS = 80
MIN_DXLOG_FILES = 400
MIN_MATCHED_CONTESTS = 50

# TR4W Cabrillo name -> DXLog Cabrillo name, for pairs the names do not join.
# Each one checked by reading the DXLog file's CONTESTNAME and multiplier list.
# A {MODE} template on the DXLog side is reached by naming one concrete mode.
CABRILLO_OVERRIDES = {
   'ARRL-FD': 'ARRL-FIELD-DAY',                  # ARRL_FD.txt, "ARRL Field Day"
   'CALIFORNIA QSO PARTY': 'CA-QSO-PARTY',       # CQP.txt
   'COQP': 'CO-QSO-PARTY',                       # COQP.txt
   'BCQP': 'BC-QSO-PARTY',                       # BCQP.txt
   'NEQP': 'NEWE-QSO-PARTY',                     # NEWEQP.txt -- NOT NE-QSO-PARTY, which is Nebraska
   'TEXAS QSO PARTY': 'TX-QSO-PARTY',            # TXQP.txt
   'WIQP': 'WI-QSO-PARTY',                       # WIQP.txt
   'NCCC-SPRINT': 'NCCC-SPRINT-CW',              # NCCCSprint.txt, NCCC-SPRINT-{MODE}
   'NRAU-BALTIC-CW': 'NRAU-CW',                  # NRAU.txt, "NRAU - Baltic Contest", NRAU-{MODE}
   'NRAU-BALTIC-SSB': 'NRAU-SSB',                # NRAU.txt
   'OK-OM DX CW': 'OK-OM-DX',                    # OKOM.txt
   'OK-OM DX SSB': 'OK-OM-DX',                   # OKOM.txt
   'YOTA-CONTEST': 'YOTA',                       # YOTA.txt
   'YUDX': 'YU-DX',                              # YUDX.txt
   'MWC': 'OK1WC',                               # MWC.txt, "OK1WC Memorial HF Contest"
   'GAGARIN-CUP': 'GC',                          # GAGARIN_KUP.txt, "Yuri Gagarin International DX Contest"
   'UKEI': 'UKEIDX-CW',                          # UKEIDX.txt, UKEIDX-{MODE}
   'UKRAINIAN': 'UKRAINIAN-DX',                  # URDXC.txt, "Ukrainian DX Contest (URDXC)"
   'CROATIAN': '9A-DX',                          # 9ADX.txt, "9A DX" -- the Croatian DX Contest
   'IRTS': 'IRTS-80-CONTEST',                    # IRTS_counties.txt, "IRTS HF Counties Contest"
   'EUDX': 'EUDXC',                              # EUDXC.txt, "European Union DX Contest"
   'CIS': 'CIS-DX',                              # CIS_DX_PSK.txt -- the PSK edition, DXLog's only CIS-DX file
}

US_STATES = set(
   'AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS '
   'MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV '
   'WI WY'.split())
# The 13 provinces and territories, plus the two halves of NL that some
# sponsors count apart (Newfoundland, Labrador).
VE_PROVINCES = set('AB BC MB NB NL NS NT NU ON PE QC SK YT'.split())
VE_EXTRA = set('NF LB'.split())

# Shared TR4W files --new-party may INCLUDE: a file is a candidate when its
# name says it is a plain state/province set.
SHARED_SET_FILE = re.compile(r'^(s\d+|p\d+|s\d+p\d+(dc)?|dc|alaska|hawaii|mexico)\.dom$', re.I)


class InputError(Exception):
   pass


# --------------------------------------------------------------------------
# TR4W: the .dom loader, mirroring LOGDOM.EnumDOMFILE
# --------------------------------------------------------------------------

def dom_index():
   """Lower-cased file name -> real path, for the program's case-blind lookup."""
   if not os.path.isdir(DOM_DIR):
      raise InputError('dom directory not found: ' + DOM_DIR)
   index = {}
   for name in os.listdir(DOM_DIR):
      index[name.lower()] = os.path.join(DOM_DIR, name)
   return index


def _strip_left(s):
   return s.lstrip(' \t')


def _strip_right(s):
   return s.rstrip(' \t')


class DomLoad:
   """One top-level load of a .dom, with its INCLUDEs, as the program does it."""

   def __init__(self, file_name, counties, index):
      self.file_name = file_name
      self.counties = counties
      self.mults = []                # in load order, as written (case kept)
      self.mult_set = set()          # upper-cased
      self.inputs = {}               # INPUT -> MULT (upper), first wins
      self.collisions = {}           # INPUT -> [mults], when >1 distinct
      self.long_names = {}           # MULT (upper) -> ^name
      self.mult_source = {}          # MULT (upper) -> the file that added it
      self.files_read = []
      self.problems = []             # missing include, BOM, ...
      self._index = index
      self._read(file_name, [])

   def _read(self, name, stack):
      path = self._index.get(name.strip().lower())
      if path is None:
         self.problems.append('missing file %r (from %s)' % (name, ' > '.join(stack) or 'matrix'))
         return
      if path.lower() in [s.lower() for s in stack]:
         self.problems.append('include loop at %s' % name)
         return
      self.files_read.append(os.path.basename(path))
      raw = open(path, 'rb').read()
      if raw.startswith(b'\xef\xbb\xbf'):
         self.problems.append('%s starts with a UTF-8 BOM: its first line is read with 3 junk bytes'
                              % os.path.basename(path))
      text = raw.decode('latin-1')
      for line in re.split(r'[\r\n]+', text):
         if line == '':
            continue
         self._line(line, stack + [os.path.basename(path)])

   def _line(self, line, stack):
      line = _strip_left(line)
      if line.startswith('INCLUDE FILE'):
         self._read(line[len('INCLUDE FILE') + 1:], stack)
      if '=' not in line:
         return
      left, _, right = line.partition('=')
      left = _strip_right(_strip_left(left))
      if '>' in left:
         qth, _, mult = left.partition('>')
         qth = _strip_right(qth)
         mult = _strip_left(mult)
         if self.counties:
            mult = qth
      else:
         mult = left
      mult_u = mult.upper()
      if mult_u not in self.mult_set:
         self.mult_set.add(mult_u)
         self.mults.append(mult)
         self.mult_source[mult_u] = stack[-1]
      while right != '':
         alias, sep, rest = right.partition(',')
         alias = _strip_right(_strip_left(alias))
         right = rest if sep else ''
         if alias == '':
            continue
         if alias.startswith('^'):
            self.long_names.setdefault(mult_u, alias[1:])
            continue
         key = alias.upper()
         if not re.match(r'[0-9A-Z]', key[0]):
            continue                     # RecordPointerIndex refuses it
         if key in self.inputs:
            if self.inputs[key] != mult_u:
               self.collisions.setdefault(key, [self.inputs[key]])
               if mult_u not in self.collisions[key]:
                  self.collisions[key].append(mult_u)
            continue
         self.inputs[key] = mult_u

   def unreachable(self):
      reached = set(self.inputs.values())
      return [m for m in self.mults if m.upper() not in reached]


# --------------------------------------------------------------------------
# The contest matrix
# --------------------------------------------------------------------------

VARIANT_RE = re.compile(r'^### variant (\S+): (.*)$')
STATION_FIELD_RE = re.compile(r'(MY [A-Z]+)=(\S*)')


def read_matrix():
   """[{contest, variant, station:{}, dom, counties, cabrillo, domestic, literal}]"""
   if not os.path.isdir(MATRIX_DIR):
      raise InputError('contest matrix not found: ' + MATRIX_DIR)
   files = sorted(glob.glob(os.path.join(MATRIX_DIR, '*.matrix')))
   if len(files) < MIN_MATRIX_FILES:
      raise InputError('only %d .matrix files in %s (floor %d)' % (len(files), MATRIX_DIR, MIN_MATRIX_FILES))
   records = []
   for path in files:
      contest = os.path.splitext(os.path.basename(path))[0]
      current = None
      for line in open(path, encoding='utf-8', errors='replace'):
         line = line.rstrip('\r\n')
         m = VARIANT_RE.match(line)
         if m:
            current = {'contest': contest, 'variant': m.group(1),
                       'station': dict(STATION_FIELD_RE.findall(m.group(2))),
                       'dom': None, 'counties': False, 'cabrillo': None,
                       'domestic': None, 'literal': False}
            records.append(current)
            continue
         if current is None:
            continue
         if line.startswith('setting.DOMESTIC FILENAME = '):
            current['dom'] = line.split('=', 1)[1].strip() or None
         elif line.startswith('multipliersarecounties = '):
            current['counties'] = line.endswith('TRUE')
         elif line.startswith('literaldomesticqth = '):
            current['literal'] = line.endswith('TRUE')
         elif line.startswith('doing.domestic/dx/prefix/zone = '):
            current['domestic'] = line.split('=', 1)[1].split()[0] == 'TRUE'
         elif line.startswith('CONTEST: ') and current['cabrillo'] is None:
            current['cabrillo'] = line[len('CONTEST: '):].strip()
   return records


# --------------------------------------------------------------------------
# DXLog
# --------------------------------------------------------------------------

def norm_cabrillo(name):
   return re.sub(r'[\s_]+', '-', name.strip().upper())


def split_top_level(pattern):
   """Split a regex at top-level '|' (outside groups, classes and escapes)."""
   parts, depth, cls, buf, i = [], 0, False, '', 0
   while i < len(pattern):
      c = pattern[i]
      if c == '\\' and i + 1 < len(pattern):
         buf += pattern[i:i + 2]
         i += 2
         continue
      if cls:
         cls = c != ']'
      elif c == '[':
         cls = True
      elif c == '(':
         depth += 1
      elif c == ')':
         depth -= 1
      elif c == '|' and depth == 0:
         parts.append(buf)
         buf = ''
         i += 1
         continue
      buf += c
      i += 1
   parts.append(buf)
   return parts


def _outer_group(s):
   """The content of s when s is ONE group spanning it all, else None."""
   if not s.startswith('('):
      return None
   depth, cls, i = 0, False, 0
   while i < len(s):
      c = s[i]
      if c == '\\':
         i += 2
         continue
      if cls:
         cls = c != ']'
      elif c == '[':
         cls = True
      elif c == '(':
         depth += 1
      elif c == ')':
         depth -= 1
         if depth == 0 and i != len(s) - 1:
            return None
      i += 1
   inner = s[1:-1]
   return inner[2:] if inner.startswith('?:') else inner


def _optional_suffix(s):
   """(head, suffix) when s ends in one optional group "(...)?", else None."""
   if not s.endswith(')?'):
      return None
   stack, cls, i = [], False, 0
   while i < len(s):
      c = s[i]
      if c == '\\':
         i += 2
         continue
      if cls:
         cls = c != ']'
      elif c == '[':
         cls = True
      elif c == '(':
         stack.append(i)
      elif c == ')':
         start = stack.pop() if stack else 0
         if i == len(s) - 2:
            return s[:start], s[start:]
      i += 1
   return None


def regex_literals(pattern, approximations=None):
   """(literals, non_literal_alternatives) of an alternation regex.

   Two shapes are reduced rather than refused, and each reduction is
   appended to `approximations` so the report can say so:
      HEAD(\\/...)?   the optional county-line suffix ("ADA/BAN") is dropped,
                     leaving HEAD's alternatives;
      [KNS]DE        one class of plain letters is expanded (KDE NDE SDE)."""
   literals, other = [], []

   def walk(p):
      for alt in split_top_level(p):
         a = alt
         if a.startswith('^'):
            a = a[1:]
         if a.endswith('$') and not a.endswith('\\$'):
            a = a[:-1]
         inner = _outer_group(a)
         if inner is not None:
            walk(inner)
            continue
         cut = _optional_suffix(a)
         if cut is not None and cut[0] != '':
            if approximations is not None:
               approximations.append('optional suffix %s ignored' % cut[1][:40])
            walk(cut[0])
            continue
         plain = re.sub(r'\\([/\-. ])', r'\1', a)
         if re.fullmatch(r'[A-Za-z0-9/ .\-]+', plain):
            literals.append(plain.upper())
            continue
         m = re.fullmatch(r'([A-Za-z0-9]*)\[([A-Za-z0-9]+)\]([A-Za-z0-9]*)', plain)
         if m:
            for ch in m.group(2):
               literals.append((m.group(1) + ch + m.group(3)).upper())
            if approximations is not None:
               approximations.append('class %s expanded' % plain)
            continue
         other.append(alt)

   walk(pattern)
   return literals, other


class DXLogFile:

   def __init__(self, path):
      self.path = path
      self.name = os.path.basename(path)
      raw = open(path, 'rb').read()
      try:
         text = raw.decode('utf-8-sig')
      except UnicodeDecodeError:
         text = raw.decode('cp1252', errors='replace')
      self.keys = {}
      self.rcvd_patterns = []
      self.blocks = []          # [(condition or None, [(key, aliases, name)])]
      self.list_unterminated = False
      in_list, condition, entries = False, None, None
      for line in text.splitlines():
         s = line.strip()
         if s == '[MULTIPLIERS START]':
            in_list, condition, entries = True, None, []
            self.blocks.append((None, entries))
            continue
         if s == '[MULTIPLIERS END]':
            in_list = False
            continue
         if in_list:
            if s.startswith('[VALID FOR='):
               condition, entries = s[len('[VALID FOR='):-1], []
               self.blocks.append((condition, entries))
               continue
            if s.startswith('[END VALID FOR'):
               condition, entries = None, []
               self.blocks.append((None, entries))
               continue
            if s.startswith('Group->'):
               # "Group->K3: DE,PA,MD/DC" -- the compact list form: each
               # comma item is ONE multiplier, its '/' spellings aliases.
               for item in s.partition(':')[2].split(','):
                  spell = [p.strip().upper() for p in item.split('/') if p.strip()]
                  if spell:
                     entries.append((spell[0], spell[1:], ''))
               continue
            if s == '' or s.startswith('#') or '=' not in s:
               continue
            left, _, long_name = s.partition('=')
            m = re.fullmatch(r'([^{}]+)(?:\{([^}]*)\})?', left.strip())
            if not m:
               continue
            aliases = [a.strip().upper() for a in (m.group(2) or '').split(';') if a.strip()]
            entries.append((m.group(1).strip().upper(), aliases, long_name.strip()))
            continue
         if s.startswith('#') or '=' not in s:
            continue
         k, _, v = s.partition('=')
         self.keys.setdefault(k.strip().upper(), v.strip())
         # "MULT1_EXCEPTION=!DEST->RCVD:^(ALL|AND|...)$;NONE" -- the only
         # place some parties (KSQP) list their counties.
         if re.match(r'MULT\d+_EXCEPTION$', k.strip().upper()):
            for part in v.split(';'):
               part = part.strip().lstrip('!')
               if part.startswith('DEST->RCVD:'):
                  self.rcvd_patterns.append(part[len('DEST->RCVD:'):])
      self.list_unterminated = in_list
      self.blocks = [(c, e) for c, e in self.blocks if e]
      self.cabrillo = self.keys.get('CABRILLO_CONTEST_NAME', '')
      self.contestname = self.keys.get('CONTESTNAME', '')
      self.rgx = self.keys.get('CFG_MULT_RGX_CHECK')
      self.dx_allowed = self.keys.get('CFG_MULT_DX_ALLOWED', '').upper() == 'YES'

   def has_list(self):
      return bool(self.blocks)

   def has_conditional_list(self):
      return any(c is not None for c, _ in self.blocks)

   def cabrillo_matches(self, tr4w_name):
      mine = norm_cabrillo(self.cabrillo)
      theirs = norm_cabrillo(tr4w_name)
      if mine == '':
         return None
      if '{' not in mine:
         return 'exact' if mine == theirs else None
      pattern = re.escape(mine)
      pattern = re.sub(r'\\\{[A-Z]+\\\}', '[A-Z0-9]+', pattern)
      return 'template' if re.fullmatch(pattern, theirs) else None

   def entries_for(self, sent_exchange):
      """The multiplier list a station sending sent_exchange sees.
      Returns (entries, notes)."""
      out, notes = [], []
      for condition, entries in self.blocks:
         if condition is None:
            out.extend(entries)
            continue
         negate = condition.startswith('!')
         body = condition[1:] if negate else condition
         if not body.startswith('CONFIG->EXCHANGE:'):
            notes.append('VALID FOR %s not evaluated; its block is included' % condition)
            out.extend(entries)
            continue
         try:
            hit = re.search(body[len('CONFIG->EXCHANGE:'):], sent_exchange) is not None
         except re.error:
            notes.append('VALID FOR %s is not a Python regex; its block is included' % condition)
            out.extend(entries)
            continue
         if hit != negate:
            out.extend(entries)
      return out, notes


def read_dxlog():
   if not os.path.isdir(DXLOG_DIR):
      raise InputError('DXLog contest directory not found: ' + DXLOG_DIR)
   paths = [p for p in glob.glob(os.path.join(DXLOG_DIR, '*')) if p.lower().endswith('.txt')]
   if len(paths) < MIN_DXLOG_FILES:
      raise InputError('only %d DXLog files in %s (floor %d)' % (len(paths), DXLOG_DIR, MIN_DXLOG_FILES))
   return [DXLogFile(p) for p in sorted(paths)]


def dxlog_candidates(dxfiles, tr4w_cabrillo):
   """DXLog files for a TR4W Cabrillo name: exact matches win over templates."""
   target = CABRILLO_OVERRIDES.get(tr4w_cabrillo, tr4w_cabrillo)
   exact = [f for f in dxfiles if f.cabrillo_matches(target) == 'exact']
   if exact:
      return exact
   return [f for f in dxfiles if f.cabrillo_matches(target) == 'template']


# --------------------------------------------------------------------------
# Comparison
# --------------------------------------------------------------------------

def sent_exchange_of(record):
   """What DXLog's CONFIG->EXCHANGE would hold for this matrix station.

   AN OUT-OF-STATE QSO-PARTY STATION (TR4W counts counties) is given 'DX',
   not its MY STATE: every party's out-of-state VALID FOR condition admits
   DX, while several (PAQP, NEQP) expect an ARRL SECTION from a W/VE
   station, which the matrix's 'ON' or 'KS' is not -- so testing the
   matrix text would put a Kansas station on the in-state list. TR4W has
   already decided which kind of station this is; that decision is used."""
   state = record['station'].get('MY STATE', '')
   return state if state else 'DX'


def out_of_state_view(load, dx):
   """True when this TR4W load is a QSO party's OUT-OF-STATE list.

   TR4W's own flag (multipliersarecounties) says so for the parties FCONTEST
   sets up; NEQP is run by its class and never sets it, but its file holds
   no state or province at all. The second test is asked only of a DXLog
   'NA QSO PARTY' file, so a foreign list whose codes happen to be no US
   state is never taken for one."""
   if load.counties:
      return True
   return (dx.keys.get('CONTESTGROUP', '').upper() == 'NA QSO PARTY'
           and not (load.mult_set & NA_SET))


def lookup(load, spellings):
   for s in spellings:
      if s in load.inputs:
         return load.inputs[s]
   return None


NA_SET = US_STATES | VE_PROVINCES | VE_EXTRA | {'DC'}

# ARRL/RAC section codes that are not also a state or province code -- three
# of them in a DXLog list mark it a SECTION list, not a state list.
ARRL_SECTION_ONLY = set(
   'EB EMA ENY EPA EWA GH LAX MDC NFL NLI NNJ NNY NTX ONE ONN ONS ORG PAC PR '
   'SB SCV SDG SF SFL SJV SNJ STX SV TER VI WCF WMA WNY WPA WTX WWA NWT'.split())


def compare(load, dx, sent):
   """A dict of findings for one TR4W load against one DXLog file."""
   r = {'notes': [], 'tags': set()}
   out_of_state = out_of_state_view(load, dx)
   if out_of_state:
      sent = 'DX'
   r['sent'] = sent
   entries, notes = dx.entries_for(sent)
   r['notes'].extend(notes)
   if dx.list_unterminated:
      r['notes'].append('%s: [MULTIPLIERS START] has no [MULTIPLIERS END]; read to end of file' % dx.name)
   r['source'] = 'list'

   def host_only(found, source):
      # ONE DXLog list (or the regex) serves every station, and holds the
      # in-state station's states and provinces too. TR4W's out-of-state
      # file counts only the host's subdivisions, so compare against those.
      kept = [e for e in found if e[0] not in NA_SET | {'DX'}]
      if len(kept) != len(found):
         r['notes'].append('DXLog %s serves every station; its %d US/VE/DX entries '
                           '(the in-state station\'s) are left out of this out-of-state comparison'
                           % (source, len(found) - len(kept)))
      return kept

   if out_of_state and entries and not dx.has_conditional_list():
      entries = host_only(entries, 'list')
   if not entries and dx.rgx:
      approx = []
      lits, other = regex_literals(dx.rgx, approx)
      entries = [(l, [], '') for l in lits]
      r['source'] = 'regex'
      for a in sorted(set(approx)):
         r['notes'].append('DXLog regex read approximately: ' + a)
      if out_of_state:
         entries = host_only(entries, 'regex')
      if other and len(entries) < 5:
         # The regex is a PATTERN (IARU's "[A-Z]{2,6}", ARRL SS's two
         # digits); its few literals are not the multiplier list.
         r['source'] = 'pattern'
         r['pattern'] = other
         r['tags'].add('DXLog gives only a pattern, no list')
         return r
   if not entries and out_of_state and dx.rcvd_patterns:
      for p in dx.rcvd_patterns:
         lits, _ = regex_literals(p)
         entries.extend((l, [], '') for l in lits)
      entries = host_only(entries, 'MULT_EXCEPTION DEST->RCVD list')
      r['source'] = 'exception'
   if not entries:
      r['source'] = 'none'
      r['tags'].add('DXLog lists nothing for this contest')
      return r

   dx_keys = [e[0] for e in entries if e[0] != 'DX']
   r['dxlog_has_dx'] = any(e[0] == 'DX' for e in entries)
   r['tr4w_has_dx'] = 'DX' in load.inputs
   mapping = {}
   for key, aliases, _ in entries:
      if key == 'DX':
         continue
      mapping[key] = lookup(load, [key] + aliases)
   only_dx = sorted(k for k, v in mapping.items() if v is None)
   reached = {}
   for k, v in mapping.items():
      if v is not None:
         reached.setdefault(v, []).append(k)
   merged = {t: sorted(ks) for t, ks in reached.items() if len(ks) > 1}
   split = {}
   for key, aliases, _ in entries:
      if key == 'DX':
         continue
      targets = sorted({load.inputs[s] for s in [key] + aliases if s in load.inputs})
      if len(targets) > 1:
         split[key] = targets
   only_tr4w = sorted(m for m in load.mult_set if m not in reached and m != 'DX')
   r.update(dict(dx_count=len(set(dx_keys)), tr4w_count=len(load.mult_set - {'DX'}),
                 only_dx=only_dx, only_tr4w=only_tr4w, merged=merged, split=split))

   # The regex is the SENT check; report the inputs TR4W would refuse.
   r['rgx_refused'], r['rgx_other'] = [], []
   if dx.rgx:
      lits, other = regex_literals(dx.rgx)
      r['rgx_refused'] = sorted(l for l in set(lits) if l != 'DX' and l not in load.inputs
                                 and not (out_of_state and l in NA_SET))
      r['rgx_other'] = other

   # ---- kinds ----
   # THE HOST'S SUBDIVISIONS merged onto one US/VE multiplier: DXLog counts
   # each county for an in-state station where TR4W counts the host once.
   host = {t: ks for t, ks in merged.items()
           if t in US_STATES | VE_PROVINCES and len([k for k in ks if k not in NA_SET]) >= 3}
   r['host'] = host
   for t, ks in host.items():
      r['tags'].add('host subdivisions: DXLog counts each (in-state), TR4W counts the host once')
   # THE REVERSE: DXLog's "CO{CO;ADA;...}" sends a host county to the host
   # state, where TR4W's in-state file counts the county itself.
   host_split = {k: ts for k, ts in split.items()
                 if k in US_STATES | VE_PROVINCES and len([t for t in ts if t not in NA_SET]) >= 3}
   r['host_split'] = host_split
   if host_split:
      r['tags'].add('host subdivisions: TR4W counts each (in-state), DXLog counts the host once')
   # And the case where DXLog's in-state list holds no host county at all
   # (its counties live only in the regex or a MULT_EXCEPTION).
   from_cty = [m for m in only_tr4w if load.mult_source.get(m, '').lower().endswith('_cty.dom')]
   if not out_of_state and len(from_cty) >= 3:
      r['tags'].add('host subdivisions: TR4W counts each (in-state), DXLog\'s in-state list has none')
   host_counties = set(from_cty) if not out_of_state else set()
   for ts in host_split.values():
      host_counties |= {t for t in ts if t not in NA_SET}
   r['host_counties'] = host_counties
   if 'DC' in only_dx:
      r['tags'].add('DC: DXLog counts it, TR4W has no DC input')
   if 'DC' in only_tr4w:
      r['tags'].add('DC: TR4W counts it, DXLog does not')
   if any('DC' in ks for ks in merged.values()):
      r['tags'].add('DC: merged into another TR4W multiplier')
   # Counted as distinct TR4W multipliers reached, the host left out. A
   # DXLog entry counts when its key OR an alias is the code ("NWT/NT").
   # Only where the list really is a state/province list: an ARRL-section
   # list, or a foreign list that happens to hold "AL" or "ON", would
   # produce a count that means nothing.
   spellings = {e[0]: {e[0]} | set(e[1]) for e in entries if e[0] != 'DX'}
   section_list = len(set(mapping) & ARRL_SECTION_ONLY) >= 3
   ve_dx = sorted(k for k, sp in spellings.items()
                  if sp & (VE_PROVINCES | VE_EXTRA) and k not in host)
   ve_tr4w = {load.inputs[k] for k in VE_PROVINCES | VE_EXTRA
              if k in load.inputs and load.inputs[k] not in host}
   if not section_list and len(ve_dx) >= 8 and len(ve_dx) != len(ve_tr4w):
      r['tags'].add('provinces: TR4W %d, DXLog %d' % (len(ve_tr4w), len(ve_dx)))
   us_dx = [k for k, sp in spellings.items() if sp & US_STATES and k not in host]
   us_tr4w = {load.inputs[k] for k in US_STATES
              if k in load.inputs and load.inputs[k] not in host}
   if not section_list and len(us_dx) >= 30 and len(us_dx) != len(us_tr4w):
      r['tags'].add('states: TR4W %d, DXLog %d' % (len(us_tr4w), len(us_dx)))
   if section_list and (only_dx or only_tr4w):
      r['tags'].add('ARRL/RAC section list differs')
   if r['dxlog_has_dx'] != r['tr4w_has_dx']:
      r['tags'].add('DX: in %s only' % ('DXLog' if r['dxlog_has_dx'] else 'TR4W'))
   rest_dx = [k for k in only_dx if k not in NA_SET]
   rest_tr4w = [k for k in only_tr4w
                if k not in NA_SET and k not in host and k not in host_counties]
   if rest_dx and not section_list:
      r['tags'].add('other multipliers only in DXLog')
   if rest_tr4w and not section_list:
      r['tags'].add('other multipliers only in TR4W')
   other_merges = {t: ks for t, ks in merged.items()
                   if t not in host and not set(ks) <= VE_PROVINCES | VE_EXTRA | {'DC'}}
   other_splits = {k: ts for k, ts in split.items() if k not in host_split}
   if other_merges or other_splits:
      r['tags'].add('merged/split mapping (not provinces)')
   return r


def fmt_list(items, limit=60):
   items = list(items)
   if len(items) <= limit:
      return ' '.join(items)
   return ' '.join(items[:limit]) + ' ... (+%d)' % (len(items) - limit)


def report(args):
   index = dom_index()
   records = read_matrix()
   dxfiles = read_dxlog()
   dom_records = [r for r in records if r['dom']]
   if len(dom_records) < MIN_DOM_RECORDS:
      raise InputError('only %d matrix records name a DOMESTIC FILENAME (floor %d)'
                       % (len(dom_records), MIN_DOM_RECORDS))
   if args.contest:
      dom_records = [r for r in dom_records if r['contest'].upper() == args.contest.upper()]

   print('TR4W .dom vs DXLog.net multiplier cross-check')
   print('  matrix   : %s (%d records, %d name a .dom)' % (MATRIX_DIR, len(records),
                                                         len([r for r in records if r['dom']])))
   print('  dom      : %s' % DOM_DIR)
   print('  DXLog    : %s (%d files, %d with a multiplier list, %d with CFG_MULT_RGX_CHECK)'
         % (DXLOG_DIR, len(dxfiles), len([f for f in dxfiles if f.has_list()]),
            len([f for f in dxfiles if f.rgx])))
   print()

   by_contest = {}
   for r in dom_records:
      by_contest.setdefault(r['contest'], []).append(r)

   matched, unmatched, differing, equal = [], [], set(), []
   kinds = {}
   dom_problems = {}
   rgx_patterns = {}

   for contest in sorted(by_contest):
      recs = by_contest[contest]
      cabrillo = next((r['cabrillo'] for r in recs if r['cabrillo']), None)
      cands = dxlog_candidates(dxfiles, cabrillo) if cabrillo else []
      print('=' * 78)
      print('%s   CONTEST: %s   DXLog: %s' % (contest, cabrillo or '(none)',
                                             ', '.join(f.name for f in cands) or 'NO MATCH'))
      if not cands:
         unmatched.append((contest, cabrillo))
      else:
         matched.append(contest)
      # one comparison per distinct (file, counties, DXLog block selection)
      seen = set()
      for r in recs:
         load = DomLoad(r['dom'], r['counties'], index)
         sent = sent_exchange_of(r)
         flags = []
         if r['counties']:
            flags.append('counties are the multiplier')
         if r['domestic'] is False:
            flags.append('doing.domestic=FALSE')
         if r['literal']:
            flags.append('literaldomesticqth=TRUE')
         for p in load.problems:
            dom_problems.setdefault(p, set()).add(contest)
         for c in cands:
            res = compare(load, c, sent)
            sel = tuple(id(e) for e in c.entries_for(res['sent'])[0])
            key = (r['dom'].lower(), r['counties'], c.name, sel)
            if key in seen:
               continue
            seen.add(key)
            includes = ', '.join(load.files_read[1:])
            print('-- %s [%s, DXLog station sends %s]%s  vs  %s (%s)%s'
                  % (r['dom'], r['variant'], res['sent'],
                     (' (includes ' + includes + ')') if includes else '',
                     c.name, res['source'], ('  {' + '; '.join(flags) + '}') if flags else ''))
            for n in res['notes'] + load.problems:
               print('   note: ' + n)
            if res['source'] in ('none', 'pattern'):
               if res['source'] == 'none':
                  print('   DXLog has no multiplier list and no CFG_MULT_RGX_CHECK')
               else:
                  print('   DXLog has only a pattern: %s' % ' | '.join(res['pattern']))
                  rgx_patterns.setdefault(c.name, res['pattern'])
               differing.add(contest)
               for t in res['tags']:
                  kinds.setdefault(t, set()).add(contest)
               continue
            print('   counts: TR4W %d, DXLog %d%s' % (
               res['tr4w_count'], res['dx_count'],
               '   (DX: TR4W %s, DXLog %s)' % ('yes' if res['tr4w_has_dx'] else 'no',
                                               'yes' if res['dxlog_has_dx'] else 'no')))
            clean = True
            if res['only_dx']:
               clean = False
               print('   only in DXLog (%d): %s' % (len(res['only_dx']), fmt_list(res['only_dx'])))
            if res['only_tr4w']:
               clean = False
               print('   only in TR4W  (%d): %s' % (len(res['only_tr4w']), fmt_list(res['only_tr4w'])))
            for t, ks in sorted(res['merged'].items()):
               clean = False
               if t in res['host']:
                  print('   host: TR4W counts %s once; DXLog counts its %d subdivisions apart (%s)'
                        % (t, len(ks), fmt_list(ks, 8)))
               else:
                  print('   merged in TR4W: %s <- %s' % (t, ' '.join(ks)))
            for k, ts in sorted(res['split'].items()):
               clean = False
               print('   split in TR4W:  %s -> %s' % (k, ' '.join(ts)))
            if res['rgx_refused']:
               print('   DXLog sent-QTH regex values TR4W refuses as input (%d): %s'
                     % (len(res['rgx_refused']), fmt_list(res['rgx_refused'])))
            if res['rgx_other']:
               rgx_patterns.setdefault(c.name, res['rgx_other'])
               print('   DXLog regex alternatives that are not literals: %s'
                     % ' | '.join(res['rgx_other']))
            unreach = load.unreachable()
            if unreach:
               print('   TR4W multipliers with NO input (unreachable): %s' % fmt_list(unreach))
               kinds.setdefault('TR4W multiplier with no input', set()).add(contest)
            for a, ms in sorted(load.collisions.items()):
               print('   TR4W alias collision: %s -> %s (the first wins)' % (a, ' / '.join(ms)))
               kinds.setdefault('TR4W alias listed under two multipliers', set()).add(contest)
            if clean and res['dxlog_has_dx'] == res['tr4w_has_dx']:
               print('   OK -- same multipliers')
               equal.append(contest)
            else:
               differing.add(contest)
            for t in res['tags']:
               kinds.setdefault(t, set()).add(contest)

   # DXLog files with a multiplier list that no TR4W contest in the matrix joins.
   all_cab = {r['cabrillo'] for r in records if r['cabrillo']}
   orphan = []
   for f in dxfiles:
      if not (f.has_list() or f.rgx) or not f.cabrillo:
         continue
      if any(f.cabrillo_matches(CABRILLO_OVERRIDES.get(c, c)) for c in all_cab):
         continue
      orphan.append(f)
   joined_no_dom = []
   dom_cab = {r['cabrillo'] for r in dom_records if r['cabrillo']}
   for f in dxfiles:
      if not (f.has_list() or f.rgx) or not f.cabrillo:
         continue
      hits = [c for c in all_cab - dom_cab if f.cabrillo_matches(CABRILLO_OVERRIDES.get(c, c))]
      if hits and not any(f.cabrillo_matches(CABRILLO_OVERRIDES.get(c, c)) for c in dom_cab):
         joined_no_dom.append((f, hits))

   print()
   print('=' * 78)
   print('SUMMARY')
   print('  TR4W contests loading a .dom : %d' % len(by_contest))
   print('  matched to DXLog             : %d' % len(matched))
   print('  unmatched (no DXLog file)    : %d' % len(unmatched))
   print('  differing                    : %d' % len(differing))
   print('  identical in every comparison: %d' % len([c for c in matched if c not in differing]))
   print()
   print('UNMATCHED TR4W contests (CONTEST: name has no DXLog CABRILLO_CONTEST_NAME):')
   for c, cab in unmatched:
      print('  %-24s %s' % (c, cab))
   print()
   print('DIFFERENCES BY KIND:')
   for k in sorted(kinds):
      print('  %s (%d): %s' % (k, len(kinds[k]), ' '.join(sorted(kinds[k]))))
   if dom_problems:
      print()
      print('.dom LOAD PROBLEMS:')
      for p in sorted(dom_problems):
         print('  %s  [%s]' % (p, ' '.join(sorted(dom_problems[p]))))
   if rgx_patterns:
      print()
      print('DXLog regex alternatives a set comparison cannot judge:')
      for n, alts in sorted(rgx_patterns.items()):
         print('  %s: %s' % (n, ' | '.join(alts)))
   print()
   print('DXLog files with a multiplier list or regex whose Cabrillo name joins a TR4W contest that loads NO .dom (%d):'
         % len(joined_no_dom))
   for f, hits in joined_no_dom:
      print('  %-28s %-28s -> %s' % (f.name, f.cabrillo, ', '.join(sorted(hits))))
   print()
   print('DXLog files with a multiplier list or regex that join NO TR4W contest (%d) -- new-contest candidates:'
         % len(orphan))
   for f in orphan:
      print('  %-28s %-28s %s' % (f.name, f.cabrillo, f.contestname))

   if not args.contest and len(matched) < MIN_MATCHED_CONTESTS:
      raise InputError('only %d contests matched DXLog (floor %d) -- the join is broken'
                       % (len(matched), MIN_MATCHED_CONTESTS))
   return 0


# --------------------------------------------------------------------------
# --new-party
# --------------------------------------------------------------------------

def new_party(args):
   path = args.new_party
   if not os.path.isfile(path):
      raise InputError('DXLog file not found: ' + path)
   dx = DXLogFile(path)
   index = dom_index()
   names = {}
   values = []
   if dx.has_list():
      for _, entries in dx.blocks:
         for key, aliases, long_name in entries:
            if key not in names:
               values.append(key)
               names[key] = (aliases, long_name)
   other, approx = [], []
   rcvd_only = set()             # values only a DEST->RCVD exception names: subdivisions
   for pattern in ([dx.rgx] if dx.rgx else []) + dx.rcvd_patterns:
      lits, odd = regex_literals(pattern, approx)
      other.extend(odd)
      for l in lits:
         if l not in names:
            values.append(l)
            names[l] = ([], '')
            if pattern is not dx.rgx:
               rcvd_only.add(l)
   if not values:
      raise InputError('%s has no multiplier list, CFG_MULT_RGX_CHECK or DEST->RCVD exception' % path)
   remaining = [v for v in values if v != 'DX']

   # Greedy: the biggest shared set wholly contained in what is left. A set
   # that misses by one or two multipliers is NOT included -- it would add a
   # multiplier the sponsor does not count -- but is named in the header,
   # because that is usually the host state left out of its own list.
   shared, near = [], []
   for low, real in index.items():
      if SHARED_SET_FILE.match(low):
         load = DomLoad(os.path.basename(real), False, index)
         covers, missing = {}, []
         for m in load.mult_set:
            spell = [k for k, v in load.inputs.items() if v == m]
            # Only a US/VE/DC code may cover a shared state/province set: a
            # Kansas county LAB (Labette) is not Labrador.
            hit = [s for s in spell if s in remaining and s in NA_SET | {'LAB', 'NWT', 'PEI'}
                   and s not in rcvd_only]
            if hit:
               covers[m] = hit
            else:
               missing.append(m)
         if covers and not missing:
            shared.append((len(covers), os.path.basename(real), covers))
         elif len(covers) >= 5 and len(missing) <= 2:
            near.append('%s (DXLog lacks %s)' % (os.path.basename(real).upper(), ' '.join(sorted(missing))))
   includes = []
   while True:
      best = None
      for n, name, covers in sorted(shared, key=lambda x: (-x[0], x[1])):
         if all(any(h in remaining for h in hit) for hit in covers.values()):
            best = (name, covers)
            break
      if best is None:
         break
      includes.append(best[0])
      for hit in best[1].values():
         for h in hit:
            if h in remaining:
               remaining.remove(h)
      shared = [s for s in shared if s[1] != best[0]]

   # Every DXLog value an included file already ACCEPTS goes to that file's
   # multiplier in TR4W; listing it again would make a second multiplier.
   # Two DXLog multipliers landing on one included multiplier is a real
   # difference (s50p13's NF takes NL), so it is said in the header.
   merged_notes = []
   for name in includes:
      load = DomLoad(name, False, index)
      landed = {}
      for v in list(remaining):
         if v in load.inputs:
            if v not in NA_SET:
               merged_notes.append('%s also accepts %s, as its multiplier %s -- an alias '
                                   'collision with this contest\'s own %s'
                                   % (name.upper(), v, load.inputs[v], v))
               continue
            landed.setdefault(load.inputs[v], []).append(v)
            remaining.remove(v)
      for m, vs in sorted(landed.items()):
         if len(vs) > 1:
            merged_notes.append('%s: DXLog %s all reach its multiplier %s' % (name.upper(), ' '.join(vs), m))

   out = []
   out.append('Starter .dom generated from DXLog.net %s' % os.path.basename(path))
   out.append('DXLog CONTESTNAME: %s   Cabrillo: %s' % (dx.contestname, dx.cabrillo))
   if dx.keys.get('CONTESTRULES'):
      out.append('Rules: %s' % dx.keys['CONTESTRULES'])
   out.append('GENERATED by tools/dom-crosscheck/crosscheck_dom_dxlog.py --new-party.')
   out.append('CHECK AGAINST THE SPONSOR RULES BEFORE SHIPPING. No line above the entries may contain an')
   out.append('equals sign: LOGDOM reads ANY line with one as an entry.')
   if 'DX' in values:
      out.append('DXLog accepts DX as a sent QTH; it is not listed here (the contest class owns DX).')
   if dx.has_conditional_list():
      out.append('DXLog splits its list by station (VALID FOR); this file holds the UNION.')
      out.append('TR4W wants two: <state>.dom (in-state) and <state>_cty.dom (out-of-state).')
   if other:
      out.append('DXLog regex alternatives that are not literals (NOT converted): %s'
                 % ' | '.join(other).replace('=', '(equals)'))
   for a in sorted(set(approx)):
      out.append('DXLog regex read approximately: %s' % a.replace('=', '(equals)'))
   for n in sorted(near):
      out.append('Not included, a near miss: %s' % n)
   for n in merged_notes:
      out.append('CHECK, merged by an include: %s' % n)
   if args.host:
      out.append('Host form: each non-US/VE entry maps to the multiplier %s (see IDAHO_CTY.DOM).'
                 % args.host)
   out.append('')
   for name in includes:
      out.append('INCLUDE FILE %s' % name.upper())
   if includes:
      out.append('')
   for v in remaining:
      aliases, long_name = names[v]
      spellings = [v] + [a for a in aliases if a != v]
      left = '%s > %s' % (v, args.host) if args.host and v not in NA_SET else v
      tail = (',^' + long_name) if long_name else ''
      out.append('%s = %s%s' % (left, ','.join(spellings), tail))
   sys.stdout.write('\r\n'.join(out) + '\r\n')
   return 0


def main():
   ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
   ap.add_argument('--contest', help='report one TR4W contest (matrix file name, e.g. NASPRINTCW)')
   ap.add_argument('--new-party', metavar='DXLOG_FILE', help='write a starter .dom from a DXLog file')
   ap.add_argument('--host', help='with --new-party: emit "CODE > HOST = ..." (the _cty form)')
   args = ap.parse_args()
   # DXLog names carry non-ASCII (Polish, Czech); a console codepage must not
   # end the report half way.
   sys.stdout.reconfigure(encoding='utf-8', errors='replace')
   try:
      if args.new_party:
         return new_party(args)
      return report(args)
   except InputError as e:
      sys.stderr.write('crosscheck_dom_dxlog: %s\n' % e)
      return 2


if __name__ == '__main__':
   sys.exit(main())
