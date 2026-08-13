# Prefixes TF-style Format(...) calls with `TF.`.
#
# Why this is needed at all: TF.pas declares ~24 cdecl sprintf-style overloads
# named Format, and SysUtils declares its own.  Delphi MERGES overload sets
# across units and picks the best match, so both spellings resolve today.  FPC
# does not merge -- the LAST unit in the uses clause owns the name outright, and
# in TR4W that is SysUtils.  Qualifying the TF-style calls says which one is
# meant and compiles identically under both compilers.
#
# The discriminator is exact, not a heuristic: SysUtils.Format's SECOND argument
# is always an open array literal, i.e. it starts with '['.  TF.Format's second
# argument is always a format string.  (Testing merely whether the call text
# contains a '[' would be wrong -- TF.Format calls routinely pass things like
# BandStringsArray[RXData.Band] as later arguments.)
#
#   python qualify-tf-format.py            # report only
#   python qualify-tf-format.py --apply

import os
import re
import sys

SRC = r'C:\tr4w-d12\tr4w\src'
SKIP = {'tf.pas'}          # TF.pas declares and defines them; leave it alone
CALL = re.compile(r'(?<![.\w])Format\s*\(')


def split_top_level(argtext):
    """Split an argument list on commas that are not nested in (), [] or ''."""
    args, depth, instr, cur = [], 0, False, ''
    for ch in argtext:
        if instr:
            cur += ch
            if ch == "'":
                instr = False
            continue
        if ch == "'":
            instr = True
            cur += ch
        elif ch in '([':
            depth += 1
            cur += ch
        elif ch in ')]':
            depth -= 1
            cur += ch
        elif ch == ',' and depth == 0:
            args.append(cur)
            cur = ''
        else:
            cur += ch
    args.append(cur)
    return args


def match_close(text, open_idx):
    """Index of the ')' closing the '(' at open_idx, or -1."""
    depth, instr, i = 0, False, open_idx
    while i < len(text):
        ch = text[i]
        if instr:
            if ch == "'":
                instr = False
        elif ch == "'":
            instr = True
        elif ch in '([':
            depth += 1
        elif ch in ')]':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def process(text):
    out, pos, changed = '', 0, 0
    for m in CALL.finditer(text):
        if m.start() < pos:
            continue
        open_idx = m.end() - 1
        close_idx = match_close(text, open_idx)
        if close_idx < 0:
            continue
        args = split_top_level(text[open_idx + 1:close_idx])
        if len(args) < 2 or args[1].strip().startswith('['):
            continue                      # SysUtils.Format -- leave it
        out += text[pos:m.start()] + 'TF.' + text[m.start():m.end()]
        pos = m.end()
        changed += 1
    out += text[pos:]
    return out, changed


def main():
    apply = '--apply' in sys.argv
    total, files = 0, 0
    for root, _dirs, names in os.walk(SRC):
        for name in names:
            if not name.lower().endswith('.pas'):
                continue
            if name.lower() in SKIP:
                continue
            path = os.path.join(root, name)
            with open(path, 'rb') as fh:
                raw = fh.read()
            text = raw.decode('utf-8', errors='surrogateescape')
            new, n = process(text)
            if n:
                total += n
                files += 1
                print('%4d  %s' % (n, os.path.relpath(path, SRC)))
                if apply:
                    with open(path, 'wb') as fh:
                        fh.write(new.encode('utf-8', errors='surrogateescape'))
    print('---- %d call sites in %d files%s' %
          (total, files, ' (APPLIED)' if apply else ' (dry run)'))


main()
