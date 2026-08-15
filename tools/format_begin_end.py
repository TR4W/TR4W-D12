import re
from pathlib import Path

IF_LINE_RE = re.compile(r'^(?P<indent>[ \t]*)if\s+(?P<cond>.+?)\s+then\s*$', re.IGNORECASE)

def wrap_if_then_next_stmt(pascal: str, indent_step="   "):
    lines = pascal.splitlines(keepends=True)
    out = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        m = IF_LINE_RE.match(line.rstrip('\r\n'))
        if not m:
            out.append(line)
            i += 1
            continue

        if_indent = m.group("indent")
        out.append(line)  # keep "if ... then"
        i += 1

        # keep blank lines after then
        while i < n and lines[i].strip() == "":
            out.append(lines[i])
            i += 1

        if i >= n:
            break

        # don't touch if the next non-blank line already starts with begin
        if lines[i].lstrip().lower().startswith("begin"):
            out.append(lines[i])
            i += 1
            continue

        # collect statement up to first ';'
        stmt_start = i
        semicolon_at = None
        while i < n:
            if ';' in lines[i]:
                semicolon_at = i
                i += 1
                break
            i += 1

        if semicolon_at is None:
            out.extend(lines[stmt_start:])
            break

        stmt_lines = lines[stmt_start:semicolon_at+0]  # not used; keep simple below
        stmt_lines = lines[stmt_start:semicolon_at+1]

        begin_indent = if_indent + indent_step  # begin aligned under "then"
        inner_indent = begin_indent            # statements aligned with begin

        out.append(begin_indent + "begin\n")

        for L in stmt_lines:
            if L.strip() == "":
                out.append(L)
            else:
                out.append(inner_indent + L.lstrip(' \t'))

        out.append(begin_indent + "end;\n")

    return ''.join(out)

# ---- usage ----
inp = Path("C:\\tr4w-d12\\tr4w\\src\\uWSJTX.pas")
outp = Path("output.pas")
text = inp.read_text(encoding="utf-8")
outp.write_text(wrap_if_then_next_stmt(text), encoding="utf-8")
print("Wrote", outp)
