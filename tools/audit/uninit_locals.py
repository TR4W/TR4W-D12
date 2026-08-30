"""Find unmanaged local variables whose FIRST use in a routine is a READ.

WHY THIS EXISTS RATHER THAN JUST READING THE COMPILER LOG. FPC already warns
"Local variable X does not seem to be initialized" and finds 23 sites in this
tree. It did NOT find uWSJTX.OnServerRead's foundCall/foundGrid, which made
WSJT-X highlighting work roughly one time in seven for years (fixed ec5f4277).

The reason is that FPC's dataflow is conservative in the direction that makes it
quiet: foundCall IS assigned, inside a loop, on some paths -- so the analyser
sees a possible initialisation and says nothing. The dangerous cases are exactly
the ones where an assignment exists somewhere, because that is also what makes
the code look correct to a reader.

So this asks a blunter question the compiler does not: for each unmanaged local,
is its first textual appearance in the body a read rather than a write? That
over-reports by design -- the output is a triage list for a human, not a build
gate.

MANAGED TYPES ARE SKIPPED because the compiler zero-initialises them: string,
AnsiString, WideString, UnicodeString, interfaces, dynamic arrays, variants.
That distinction is the whole trap in the foundCall case -- every other local in
that var block was a string, so the variables beside it were genuinely safe.

NOTE ShortString IS NOT MANAGED. Str10/Str20/Str80 and friends are fixed arrays
with a length byte and are NOT initialised, so they are in scope here.
"""
import collections
import io
import json
import os
import re
import sys

BOUND = r'\b'

MANAGED = re.compile(r'^\s*(ansistring|widestring|unicodestring|string|'
                     r'utf8string|rawbytestring|variant|olevariant|'
                     r'array\s+of\b|i[A-Z]\w*|t?stringlist)\b', re.I)
DECL = re.compile(r'^\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*([^;]+);')
ROUTINE = re.compile(r'^\s*(procedure|function|constructor|destructor)\s+'
                     r'([A-Za-z_][\w.]*)', re.I)
WRITE_TAIL = re.compile(r'\s*(\[[^\]]*\])?\s*(\.\w+)*\s*:=')
ZEROERS = re.compile(r'\b(FillChar|ZeroMemory|FillByte|GetMem|New)\b', re.I)
COND = re.compile(r'^(else\s+)?(if|while|until|case|repeat)\b', re.I)
RISKY_TYPE = re.compile(r'^(boolean|bool|longbool|wordbool)\b', re.I)


def word(name):
    return BOUND + re.escape(name) + BOUND


def strip_noise(src):
    """Blank comments and string literals so they cannot match identifiers."""
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "'":
            j = i + 1
            while j < n and src[j] != "'":
                j += 1
            out.append("'" + ' ' * (j - i - 1) + "'")
            i = j + 1
        elif c == '{':
            j = src.find('}', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i + 1))
            i = j + 1
        elif src.startswith('(*', i):
            j = src.find('*)', i)
            j = n if j < 0 else j + 1
            out.append(' ' * (j - i + 1))
            i = j + 1
        elif src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def in_call_args(line, var):
    """Is this occurrence an ARGUMENT to a call rather than a bare operand?

    `if not tOpenFileForRead(h, name) then` looks like a use of h, but h is an
    OUT PARAMETER the call fills -- the single largest source of noise in the
    first pass (20 of 23 'DANGER' hits). A bare operand, `if not foundCall
    then`, is the shape that actually matters.

    Heuristic, not a parser: walk left counting parens; landing on an unclosed
    '(' immediately preceded by an identifier means a call argument.
    """
    m = re.search(word(var), line, re.I)
    if not m:
        return False
    depth = 0
    i = m.start() - 1
    while i >= 0:
        c = line[i]
        if c == ')':
            depth += 1
        elif c == '(':
            if depth == 0:
                j = i - 1
                while j >= 0 and line[j] == ' ':
                    j -= 1
                k = j
                while k >= 0 and (line[k].isalnum() or line[k] in '_.'):
                    k -= 1
                return k < j
            depth -= 1
        i -= 1
    return False


def routines(lines):
    """Yield (name, var_line, body_start, body_end)."""
    i, n = 0, len(lines)
    while i < n:
        m = ROUTINE.match(lines[i])
        if not m:
            i += 1
            continue
        j, var_at = i, None
        while j < n and not re.match(r'^\s*begin\b', lines[j], re.I):
            if re.match(r'^\s*var\b', lines[j], re.I):
                var_at = j
            if j > i and ROUTINE.match(lines[j]):
                break
            if re.search(r'\b(forward|external|abstract)\s*;', lines[j], re.I):
                break
            j += 1
        if j >= n or not re.match(r'^\s*begin\b', lines[j], re.I):
            i += 1
            continue
        depth, k = 0, j
        while k < n:
            for tok in re.findall(r'\b(begin|case|record|try|end)\b',
                                  lines[k], re.I):
                depth += -1 if tok.lower() == 'end' else 1
            if depth <= 0 and k > j:
                break
            k += 1
        yield m.group(2), var_at, j, min(k, n - 1)
        i = j + 1


CONTINUATION = re.compile(r'^[\w.\[\]@^ ]+\s*(,|\)\s*;?)\s*$')


def classify(code, typ, var):
    if ZEROERS.search(code):
        return 'WRITE (false positive)'
    if in_call_args(code, var):
        return 'LIKELY-OK (out param)'
    # A CALL SPREAD OVER LINES. in_call_args only sees one line, so the second
    # line of `WriteFile(h, buf, n,` + `bytesWritten, nil);` looks like a bare
    # read of an uninitialised Cardinal. It is an out parameter. Recognised by
    # shape: nothing but an argument and a separator or a closing paren.
    if CONTINUATION.match(code):
        return 'LIKELY-OK (out param, continuation line)'
    if COND.match(code):
        return 'DANGER' if RISKY_TYPE.match(typ.strip()) else 'CHECK (cond)'
    return 'CHECK (expr)'


def analyse(path):
    raw = io.open(path, encoding='utf-8', errors='replace').read()
    lines = strip_noise(raw).split('\n')
    hits = []
    for name, var_at, body_start, body_end in routines(lines):
        if var_at is None:
            continue
        decls = {}
        for ln in range(var_at + 1, body_start):
            m = DECL.match(lines[ln])
            if not m:
                continue
            typ = m.group(2).strip()
            if MANAGED.match(typ):
                continue
            for v in re.split(r'\s*,\s*', m.group(1)):
                decls[v] = (typ, ln + 1)
        body = lines[body_start:body_end + 1]
        for v, (typ, dline) in decls.items():
            pat = word(v)
            for off, bl in enumerate(body):
                m = None
                for cand in re.finditer(pat, bl, re.I):
                    # NOT A FIELD OF SOMETHING ELSE. `if RXData.QTHString = ''`
                    # is not a use of a local named QTHString, but the word
                    # boundary matches it happily -- five false positives in the
                    # condition bucket alone, and they are the ones a reader
                    # would look at first.
                    before = bl[:cand.start()].rstrip()
                    if before.endswith('.'):
                        continue
                    m = cand
                    break
                if not m:
                    continue
                if WRITE_TAIL.match(bl[m.end():]):
                    break                       # written first: fine
                code = bl.strip()[:100]
                hits.append(dict(routine=name, var=v, type=typ,
                                 decl_line=dline, use_line=body_start + off + 1,
                                 code=code, bucket=classify(code, typ, v)))
                break
    return hits


def main(roots):
    out = []
    for root in roots:
        for dirpath, _dirs, files in os.walk(root):
            low = dirpath.lower()
            if 'indy' in low or 'vendor' in low:
                continue
            for f in files:
                if not f.lower().endswith(('.pas', '.lpr')):
                    continue
                p = os.path.join(dirpath, f)
                try:
                    for h in analyse(p):
                        h['file'] = p.replace(chr(92), '/')
                        out.append(h)
                except Exception as exc:                # noqa: BLE001
                    print('  !! %s: %s' % (p, exc), file=sys.stderr)
    seen, uniq = set(), []
    for h in out:
        k = (h['file'], h['routine'], h['var'], h['use_line'])
        if k in seen:
            continue
        seen.add(k)
        uniq.append(h)
    os.makedirs('build-out', exist_ok=True)
    json.dump(uniq, io.open('build-out/uninit-locals.json', 'w',
                            encoding='utf-8'), indent=1)
    counts = collections.Counter(h['bucket'] for h in uniq)
    for k, v in counts.most_common():
        print('%-26s %d' % (k, v))
    print('%d unique candidate(s) -> build-out/uninit-locals.json' % len(uniq))


if __name__ == '__main__':
    main(sys.argv[1:] or ['tr4w/src'])
