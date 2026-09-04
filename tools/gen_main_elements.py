"""Generate the main window's status panels into uMainForm.lfm.

WHY THIS IS GENERATED AND NOT HAND-TYPED.

   The layout lives in VC.pas's TWindows[] table -- a row per element giving
   its position in `ws` units, its style bits, its colours and its caption.
   Putting those elements in the .lfm is what makes opening tr4w.lpi and
   pressing F12 show them, named and selectable (NY4I, 2026-09-04: "I should
   be able to open Lazarus and hit F12 to see the main form. Then I will see
   each item as a LCL control that I could change something if I so desired.")

   Hand-typing 43 blocks would produce a SECOND COPY of the layout, and the two
   would drift the first time anyone touched the table -- silently, because
   nothing compares them. Generated, the .lfm is a VIEW of the table, and
   --check fails if it has gone stale.

   THE .lfm BOUNDS ARE A DESIGN-TIME PICTURE, NOT THE RUNTIME LAYOUT. At run
   time CreateMainElement still positions every element from
   TWindows[e].mweiX * ws, where ws follows the operator's font-size setting
   and the vertical origin follows the log's height. The .lfm holds those same
   positions computed at the DEFAULT scale (WindowSize = 5, so ws = 17), which
   is what makes the designer show something recognisable rather than a pile of
   panels at 0,0.

   That reconciles the note in CLAUDE.md -- "freezing them into a designed
   layout would be a regression" -- with the designer: nothing is frozen, the
   .lfm is a picture and the arithmetic still runs.

   python tools/gen_main_elements.py            # rewrite the .lfm block
   python tools/gen_main_elements.py --check    # fail if it is out of date
"""

import io
import re
import sys

VC = 'c:/tr4w-d12/tr4w/src/VC.pas'
LFM = 'c:/tr4w-d12/tr4w/src/ui/lcl/uMainForm.lfm'

CRLF = '\r\n'

# NO MARKER COMMENTS IN THE .lfm.  Lazarus form text is a strict object grammar
# with no comment syntax at all -- a `{ ... }` line makes the resource compiler
# stop with "Symbol expected but { found", which is how this was found.  The
# generated region is identified by the COMPONENT NAMES instead, which is what
# a regeneration has to match anyway.

# The default scale.  VC.pas: WindowSize = 5, and MainUnit does ws := WindowSize + 12.
WS = 17
# MainUnit: h := 30 + LinesInEditableLog * (ws + 2), with LinesInEditableLog = 5.
EDITABLE_LOG_HEIGHT = 30 + 5 * (WS + 2)

# Room for the things created in code -- the entry fields, the log grid and the
# possible-call strip -- which this script does not measure.
FORM_MARGIN = 24


def style_flags(expr):
    """Which of the four style properties a style expression implies.

    The named constants in VC.pas:
      defStyle       = MainStyle or SS_CENTER or SS_SUNKEN or WS_VISIBLE
      DefStyleBorder = defStyle or WS_BORDER
      DefStyleDis    = defStyle or WS_DISABLED
      DefStyleNoSun  = WS_CHILD or SS_NOTIFY or SS_CENTER or SS_NOPREFIX or WS_VISIBLE
    """
    e = expr.strip().lower()
    sunken = 'defstyle' in e and 'nosun' not in e
    centre = True                       # all four centre
    visible = True                      # and all four are visible
    enabled = 'dis' not in e
    return sunken, centre, visible, enabled


def read_rows():
    t = io.open(VC, encoding='utf-8', errors='replace').read()

    m = re.search(r'TMainWindowElement\s*=\s*\((.*?)\);', t, re.S)
    order = [x.strip() for x in m.group(1).split(',') if x.strip()]

    rows = re.findall(
        r'\{\s*(mwe\w+)\s*\}\s*\(\s*mweName:\s*\'([^\']*)\';\s*'
        r'mweiStyle:\s*([^;]+);\s*'
        r'mweText:\s*\'([^\']*)\'\s*;\s*'
        r'mweColor:\s*(\w+);\s*mweBackG:\s*(\w+);\s*'
        r'mweI:\s*(\d+);\s*mweB:\s*(\d+);\s*'
        r'mweiX:\s*(\d+);\s*mweiY:\s*(\d+);\s*'
        r'mweiWidth:\s*(\d+);\s*mweiHeight:\s*(\d+)\s*\)', t)

    by = {r[0]: r for r in rows}
    missing = [e for e in order if e not in by]
    if missing:
        raise SystemExit('TWindows[] has no row for: %s' % ', '.join(missing))

    return order, by


def component_name(element):
    return 'pnl' + element[3:]


def generate():
    order, by = read_rows()
    out = []
    made = []
    extent = [0, 0]         # widest right edge, lowest bottom edge

    for element in order:
        (_, _, style, text, _colour, _back, _i, b, x, y, w, h) = by[element]

        # The runtime loop skips these: they are not status panels.  The call
        # and exchange fields, the log grid, the possible-call strip and the
        # two network windows are built by their own routines, and
        # mweWholeScreen is the main window itself.
        if style.strip() in ('0', '1', '2'):
            continue

        sunken, centre, visible, enabled = style_flags(style)

        left = int(x) * WS
        top = int(y) * WS + int(b) * EDITABLE_LOG_HEIGHT
        width = int(w) * WS
        height = int(h) * WS

        out.append('  object %s: TElementPanel' % component_name(element))
        out.append('    Left = %d' % left)
        out.append('    Height = %d' % height)
        out.append('    Top = %d' % top)
        out.append('    Width = %d' % width)
        out.append('    Alignment = %s' % ('taCenter' if centre else 'taLeftJustify'))
        out.append('    AutoSize = False')
        out.append('    BevelOuter = %s' % ('bvLowered' if sunken else 'bvNone'))
        out.append("    Caption = '%s'" % text.replace("'", "''"))
        if not enabled:
            out.append('    Enabled = False')
        out.append('    ParentColor = False')
        out.append('    ParentFont = False')
        out.append('    TabOrder = %d' % len(made))
        if not visible:
            out.append('    Visible = False')
        out.append('  end')
        made.append(element)

        extent[0] = max(extent[0], left + width)
        extent[1] = max(extent[1], top + height)

    return made, CRLF.join(out), extent


def strip_generated(raw, made):
    """Remove the top-level objects this script owns, by name.

    A regeneration must not append a second copy, and the names are the only
    handle there is -- see the note above on why there are no marker comments.
    """
    wanted = set(component_name(e) for e in made)
    lines = raw.split(CRLF)
    out = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        # BOTH CLASS NAMES.  These were plain TPanels until TElementPanel gave
        # them the off-thread report and the caption fit; a strip that knew
        # only the new name would leave the old blocks in place and append a
        # second copy of every element.
        if (stripped.startswith('object ')
                and (stripped.endswith(': TElementPanel')
                     or stripped.endswith(': TPanel'))):
            name = stripped[len('object '):stripped.rindex(':')]
            if name in wanted:
                i += 1
                while i < len(lines) and lines[i].strip() != 'end':
                    i += 1
                i += 1                          # the matching `end`
                continue
        out.append(lines[i])
        i += 1
    return CRLF.join(out)


def size_form(raw, extent):
    """Make the FORM big enough for the panels it now contains.

    The designer draws the form at its .lfm size, and the runtime window is
    sized separately (MainUnit: ws * 46 wide).  Left at the old 400x200 the
    designer would clip most of the layout, and Lint-FormOverlap would report --
    correctly -- that thirty controls hang outside their parent.

    Sized from the generated panels themselves rather than from a second copy of
    MainUnit's arithmetic.
    """
    w = extent[0] + FORM_MARGIN
    h = extent[1] + FORM_MARGIN

    out = []
    for line in raw.split(CRLF):
        s = line.strip()
        if line.startswith('  Width = '):
            line = '  Width = %d' % w
        elif line.startswith('  Height = '):
            line = '  Height = %d' % h
        elif s.startswith('ClientWidth = '):
            line = '  ClientWidth = %d' % w
        elif s.startswith('ClientHeight = '):
            line = '  ClientHeight = %d' % h
        out.append(line)
    return CRLF.join(out)


def main():
    made, block, extent = generate()

    raw = io.open(LFM, 'rb').read().decode('utf-8-sig')
    body = strip_generated(raw, made)

    cut = body.rstrip().rfind(CRLF + 'end')
    if cut < 0:
        raise SystemExit('uMainForm.lfm: cannot find the form terminator')

    new = body[:cut + 2] + block + CRLF + body[cut + 2:]
    new = size_form(new, extent)

    if '--check' in sys.argv:
        if new != raw:
            raise SystemExit(
                'uMainForm.lfm is out of date with VC.pas TWindows[].\n'
                'Run: python tools/gen_main_elements.py')
        print('gen_main_elements: %d element(s), .lfm is current' % len(made))
        return

    io.open(LFM, 'wb').write(new.encode('utf-8'))
    print('gen_main_elements: %d element(s) at ws=%d, form %dx%d'
          % (len(made), WS, extent[0] + FORM_MARGIN, extent[1] + FORM_MARGIN))


if __name__ == '__main__':
    main()
