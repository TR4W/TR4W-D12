# rxprobe — the equivalence probes behind uRegex

One-off programs, kept because the claims they support are in commit messages
and unit-test headers and would otherwise be unfalsifiable assertions.

They are NOT part of any build and are not run by the test suite. The two data
files they need are regenerated, not checked in:

    calls.txt             67,681 unique callsigns, built from
                          tr4w/test/corpus/*/ref.adi and tr4w/target/TRMASTER.DTA
    delphi-baseline.txt   what rxdelphi.exe answered for every one of them

| program | compiler | question it answers |
|---|---|---|
| `rxdelphi.dpr` | Delphi (`rxdelphi.dproj`) | Does removing PCRE's possessive `?+` from RX_CALLSIGN change any answer? Writes `delphi-baseline.txt`. **Result: 0 differences over 67,681 subjects.** |
| `rxfpc.dpr` | FPC | Does TRegExpr agree with PCRE on all five patterns? Reads the baseline back. **Result: 0 differences over 67,681 subjects.** |
| `rx.dpr` | FPC | First look at the five patterns under TRegExpr; found that `?+` is rejected outright ("nested *?+") rather than silently mis-handled. |
| `gp.dpr` | FPC | Isolates the GUID failure: `([0-9a-fA-F]{4}-?){3}` throws "loop without loop entry" on a near-miss, the expanded three-copy form does not. |
| `wt.dpr` | FPC | Thirty lines proving `Classes.AllocateHWnd` dies with runtime error 217 under FPC 3.2.2 — the reason uWinTimer owns its own window class. |

## Rebuilding the callsign list

```bash
python - <<'PY'
import re, glob
calls = set()
for f in glob.glob('tr4w/test/corpus/*/ref.adi'):
    d = open(f, 'rb').read().decode('latin-1')
    for m in re.finditer(r'(?i)<call:(\d+)>', d):
        n = int(m.group(1)); calls.add(d[m.end():m.end()+n].strip())
d = open('tr4w/target/TRMASTER.DTA', 'rb').read().decode('latin-1')
for tok in re.findall(r'[A-Z0-9/]{3,12}', d):
    if any(c.isdigit() for c in tok) and any(c.isalpha() for c in tok):
        calls.add(tok)
open('spike/rxprobe/calls.txt','w',newline='\r\n').write('\n'.join(sorted(c for c in calls if c))+'\n')
PY
```

## A caveat worth keeping

This corpus is CALLSIGNS. It exercises RX_CALLSIGN, RX_US_PREFIX and
RX_US_CALLSIGN hard, and RX_GUID and RX_POTA_PARK barely at all — which is
exactly why the GUID defect survived the sweep and was caught later by
`test/unit/uTestRegexValidators.pas`. A bulk probe answers "do these agree on
real traffic"; only the pinned test answers "do these agree on the inputs that
make them work".
