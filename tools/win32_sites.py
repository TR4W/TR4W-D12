"""Classify every Win32 call site as COMPILED or NEVER-COMPILED, before counting it.

WHY THIS EXISTS
---------------
`Lint-Win32Dialogs` counts code only -- build/PascalSource.psm1 strips comments
and string literals first, and that part is right. But it deliberately treats
`{$IFDEF}` and `{$IF}` as DIRECTIVES rather than comments, so THE CODE THEY
GUARD IS COUNTED WHETHER OR NOT IT IS EVER COMPILED.

That makes the ratchet a moving target you cannot finish. Measured 2026-09-05,
three sites reported as remaining Win32 work turned out to be:

  * uWinKey.pas:1344   inside {$IF WINKEYDEBUG}  -- VC.pas says False
  * uMixW.pas:140      inside {$IFDEF MIXWMODE}  -- defined NOWHERE in the tree
  * MainUnit.pas:9742  inside {$IF tKeyerDebug}  -- VC.pas says False

No amount of conversion work removes those from the count, because the compiler
never sees them. NY4I: "we have a never ending target."

WHAT THIS DOES
--------------
Evaluates the conditionals the way the compiler does, for the defines the build
actually passes, and reports each site as LIVE or DEAD -- so "how much Win32 is
left" is answerable and finite.

DEAD IS NOT THE SAME AS DELETABLE. A block under {$IF tDebugMode} is code
somebody may switch on. It is reported separately so the decision -- delete,
mark //AGENT_DEPRECATED, or leave -- is made deliberately rather than by a
counter nobody can drive to zero.

   python tools/win32_sites.py                 # summary
   python tools/win32_sites.py --dead          # every never-compiled site
   python tools/win32_sites.py --live          # every compiled site
   python tools/win32_sites.py --pattern X     # one pattern only
"""

import io
import os
import re
import sys

SRC = 'c:/tr4w-d12/tr4w/src'

# What FullBuild.ps1 passes, plus what FPC defines for this target itself.
DEFINES = {
    'LANG_ENG', 'VERSIONINFO_RES',
    'FPC', 'WINDOWS', 'WIN32', 'MSWINDOWS', 'CPU386', 'CPUI386', 'CPU32',
    'FPC_HAS_TYPE_EXTENDED', 'UNICODE',
}

# Compile-time booleans read by {$IF <name>}. Harvested from VC.pas rather than
# hardcoded, so flipping one there changes this too.
def read_switches():
    out = {}
    t = io.open(os.path.join(SRC, 'VC.pas'), encoding='utf-8', errors='replace').read()
    for m in re.finditer(r'^\s+([A-Za-z_]\w*)\s*=\s*(True|False)\s*;', t, re.M):
        out[m.group(1).lower()] = (m.group(2) == 'True')
    return out


SWITCHES = read_switches()

# The kinds Lint-Win32Dialogs tracks, plus the operate-on-a-window calls it does
# not -- those are the ones this tree keeps finding by accident.
PATTERNS = {
    'CreateWindowEx':   r'\bCreateWindowEx[AW]?\s*\(',
    'CreateModalDialog': r'\bCreateModalDialog\s*\(',
    'DialogBox':        r'\bDialogBox(Param|Indirect|IndirectParam)?[AW]?\s*\(',
    'CreateDialog':     r'\bCreateDialog(Param|Indirect|IndirectParam)?[AW]?\s*\(',
    'SetWindowText':    r'\bSetWindowText[AW]?\s*\(',
    'GetWindowText':    r'\bGetWindowText[AW]?\s*\(',
    'SetWindowPos':     r'\bSetWindowPos\s*\(',
    'ShowWindow':       r'\bShowWindow\s*\(',
    'EnableWindow':     r'\bEnableWindow\s*\(',
    'InvalidateRect':   r'\bInvalidateRect\s*\(',
    'SetWindowLong':    r'\bSetWindowLong(Ptr)?[AW]?\s*\(',
    'SendDlgItemMessage': r'\bSendDlgItemMessage[AW]?\s*\(',
    'SetDlgItemText':   r'\bSetDlgItemText[AW]?\s*\(',
    'GetDlgItem':       r'\bGetDlgItem\s*\(',
    'ListView_':        r'\bListView_\w+\s*\(',
    'LB_message':       r'\bSendMessage[AW]?\s*\([^,]+,\s*LB_',
}


def evaluate(kind, arg):
    """True when the compiler takes this branch."""
    name = arg.strip().split()[0].strip('()') if arg.strip() else ''
    if kind == 'IFDEF':
        return name.upper() in {d.upper() for d in DEFINES}
    if kind == 'IFNDEF':
        return name.upper() not in {d.upper() for d in DEFINES}
    # {$IF <expr>} -- only the simple forms this tree uses.
    expr = arg.strip().rstrip('}').strip()
    low = expr.lower()
    if low in SWITCHES:
        return SWITCHES[low]
    m = re.match(r'^(\w+)\s*=\s*(TRUE|FALSE)$', expr, re.I)
    if m and m.group(1).lower() in SWITCHES:
        return SWITCHES[m.group(1).lower()] == (m.group(2).upper() == 'TRUE')
    m = re.match(r'^(?:not\s+)?defined\s*\(\s*(\w+)\s*\)$', expr, re.I)
    if m:
        got = m.group(1).upper() in {d.upper() for d in DEFINES}
        return (not got) if low.startswith('not') else got
    return True          # unknown -- assume compiled, which never hides work


def strip_comments(text, in_block):
    """Remove comments from one line, KEEPING {$...} directives.

    Returns (stripped_text, new_block_state). `in_block` is None, '}' or '*)'
    and carries across lines.

    Keeping directives is what lets the caller read them from text that has had
    prose removed -- see scan().
    """
    out = ''
    i = 0
    while i < len(text):
        if in_block:
            j = text.find(in_block, i)
            if j < 0:
                i = len(text)
            else:
                i = j + len(in_block)
                in_block = None
            continue
        if text.startswith('//', i):
            break
        if text.startswith('(*', i):
            # (*$DIRECTIVE*) is a directive, not a comment.
            if text.startswith('(*$', i):
                j = text.find('*)', i)
                if j < 0:
                    out += text[i:]
                    i = len(text)
                else:
                    out += text[i:j + 2]
                    i = j + 2
                continue
            in_block = '*)'
            i += 2
            continue
        if text.startswith('{', i):
            if text.startswith('{$', i):
                j = text.find('}', i)
                if j < 0:
                    out += text[i:]
                    i = len(text)
                else:
                    out += text[i:j + 1]
                    i = j + 1
                continue
            in_block = '}'
            i += 1
            continue
        out += text[i]
        i += 1
    return out, in_block


def scan(path):
    """Yield (line_number, pattern_name, text, live) for each call site."""
    raw = io.open(path, encoding='utf-8', errors='replace').read()
    lines = raw.split('\n')

    in_block = None          # '}' or '*)' carried across lines
    stack = []               # one bool per open conditional

    for n, line in enumerate(lines, 1):
        # COMMENTS COME OFF FIRST, AND THAT ORDER IS THE WHOLE POINT.
        #
        # A directive looks exactly like a comment ({$...}), so reading
        # directives from the RAW line means a directive merely MENTIONED IN
        # PROSE is obeyed. MainUnit.pas line 661 reads
        #     // {$IF tDebugMode} switch, and the LOGK1EA caller is inside ...
        # which pushed a False frame that nothing ever popped -- so every Win32
        # site in the remaining 9,000 lines was reported as never compiled.
        #
        # Measured: MainUnit had 38 openers against 34 closers while compiling
        # perfectly, so the four extras were all text. strip_comments keeps
        # {$...} precisely so this can be done in the right order.
        code, in_block = strip_comments(line, in_block)

        # IFOPT IS AN OPENER and must be listed. {$IFOPT R+} closes with
        # {$ENDIF}; omitting it pushed nothing while its $ENDIF still popped,
        # discarding a real enclosing frame. Treated as TAKEN, because it tests
        # a compiler switch rather than a feature flag -- and assuming taken can
        # only over-report live work, the safe direction for this tool.
        for m in re.finditer(
                r'\{\$(IFDEF|IFNDEF|IFOPT|IF|ELSE|ENDIF|IFEND|ELSEIF)\b([^}]*)\}',
                code, re.I):
            kind = m.group(1).upper()
            if kind == 'IFOPT':
                stack.append(True)
            elif kind in ('IFDEF', 'IFNDEF', 'IF'):
                stack.append(evaluate(kind, m.group(2)))
            elif kind == 'ELSE':
                if stack:
                    stack[-1] = not stack[-1]
            elif kind in ('ENDIF', 'IFEND'):
                if stack:
                    stack.pop()

        live_here = all(stack)

        for name, pat in PATTERNS.items():
            if re.search(pat, code):
                yield (n, name, line.strip(), live_here)


# UNITS THAT *DECLARE* THE WIN32 API RATHER THAN CALLING IT.
#
# uCommctrl.pas is FPC's common-controls header: it defines ListView_*, and
# every one of its ~246 matches is a DECLARATION, not a use. Counting those as
# remaining work overstates it by a factor of four and can never be reduced --
# the same point CLAUDE.md already makes about MMSystem's 189 winmm entries
# ("misleading -- MMSystem.pas DECLARES the whole API").
#
# tr4wserver is a DIFFERENT PROGRAM: a console app with no LCL, so its Win32
# use is not part of the app's conversion at all.
API_HEADERS = ('uCommctrl.pas', 'MMSystem.pas', 'HtmlHelp.pas')
OTHER_PROGRAM = ('tr4wserverUnit.pas', 'tr4wserver')


def classify_file(rel):
    base = rel.split('/')[-1]
    if base in API_HEADERS:
        return 'header'
    if base in OTHER_PROGRAM or rel.startswith('tr4wserver'):
        return 'server'
    return 'app'


def main():
    show_dead = '--dead' in sys.argv
    show_live = '--live' in sys.argv
    only = None
    if '--pattern' in sys.argv:
        only = sys.argv[sys.argv.index('--pattern') + 1]

    live_by_kind, dead_by_kind = {}, {}
    dead_rows, live_rows = [], []
    header_count, server_count = [0], [0]

    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in ('backup', 'graphify-out')]
        for f in sorted(files):
            if not f.lower().endswith(('.pas', '.inc')):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, SRC).replace('\\', '/')
            for n, name, text, live in scan(path):
                if only and name != only:
                    continue
                row = '%s:%d  %s' % (rel, n, text[:96])
                where = classify_file(rel)
                if not live:
                    dead_by_kind[name] = dead_by_kind.get(name, 0) + 1
                    dead_rows.append(row)
                elif where == 'header':
                    header_count[0] += 1
                elif where == 'server':
                    server_count[0] += 1
                else:
                    live_by_kind[name] = live_by_kind.get(name, 0) + 1
                    live_rows.append(row)

    if show_dead:
        for r in dead_rows:
            print(r)
        return
    if show_live:
        for r in live_rows:
            print(r)
        return

    print('Win32 call sites in tr4w/src, by whether the compiler SEES them')
    print('defines: %s' % ', '.join(sorted(DEFINES)))
    print()
    print('  %-22s %8s %8s' % ('pattern', 'LIVE', 'never'))
    print('  %-22s %8s %8s' % ('-' * 22, '-' * 8, '-' * 8))
    for name in sorted(set(list(live_by_kind) + list(dead_by_kind))):
        print('  %-22s %8d %8d'
              % (name, live_by_kind.get(name, 0), dead_by_kind.get(name, 0)))
    print('  %-22s %8s %8s' % ('-' * 22, '-' * 8, '-' * 8))
    print('  %-22s %8d %8d'
          % ('TR4W app', sum(live_by_kind.values()), sum(dead_by_kind.values())))
    print()
    print('  excluded, and why:')
    print('    %-40s %5d' % ('API HEADERS (uCommctrl etc) -- declarations', header_count[0]))
    print('    %-40s %5d' % ('tr4wserver -- a different program', server_count[0]))
    print()
    print('LIVE is the only number that can be driven down. "never" is inside a')
    print('conditional the build does not take, so converting one changes nothing;')
    print('the headers DECLARE the API rather than calling it.')


if __name__ == '__main__':
    main()
