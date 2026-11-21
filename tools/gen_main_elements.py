"""Generate the main window's bands and status panels into uMainForm.lfm.

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
   time MainUnit.LayOutMainWindow still positions every element from
   TWindows[e].mweiX * ws, where ws follows the operator's font-size setting.
   The .lfm holds those same positions computed at the DEFAULT scale
   (WindowSize = 5, so ws = 17), which is what makes the designer show
   something recognisable rather than a pile of panels at 0,0.

THE BANDS (plan stage e5, 2026-11-21).

   Every control lives in one of three panels, and this script writes all
   three with everything in them:

     pnlTopBand     alTop, 7 * ws tall: the clocks, the totals grid, Total
                    Score and Dupe Info, and
       pnlNeedsBlock  alRight inside it, 14 * ws wide: the need headers, Beam
                      Heading and the need strips (TWindows[] columns 32..46);
     pnlBottomBand  alBottom, 7 * ws + 6 tall: every row with mweB = 1, and
                    the five hand-written controls below.

   A CHILD'S POSITION IS IN ITS BAND'S COORDINATES, exactly as
   uMainLayout.ElementRect computes it: a bottom-band row is (mweiY - 7) * ws
   down the band, a needs-block row starts (mweiX - 32) * ws in. The log is
   alClient at run time and is not in the .lfm.

   THE FIVE HAND-WRITTEN CONTROLS of the bottom band -- the three progress
   bars, the tour readout and the possible-call strip -- carry properties this
   script does not know (Max, Smooth, the grid's options and its
   OnPrepareCanvas). They are TAKEN from the file wherever they are, and put
   back inside the bottom band with their geometry and TabOrder set here and
   every other line kept. sbStatus and the timers are hand-written and stay
   where they are; this script sets only sbStatus's place.

   TAB ORDER AND STREAM ORDER ARE READING ORDER, per band, by
   tools/lfm_taborder.py's own rule (row_order), so Lint-TabOrder judges the
   bands and the form and has nothing to excuse.

   python tools/gen_main_elements.py            # rewrite the .lfm
   python tools/gen_main_elements.py --check    # fail if it is out of date
"""

import io
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
import lfm_taborder   # noqa: E402  -- the reading-order rule, not a copy of it

# PATHS DERIVED FROM THIS FILE, NOT HARDCODED -- and the hardcoded ones were a
# release blocker, not an untidiness.
#
# These read 'c:/tr4w-d12/tr4w/src/...' until 2026-09-17. On this developer's
# machine that is the repository, so --check passed and kept passing. ANYWHERE
# ELSE it names a directory that does not exist: read_rows() then matches zero
# rows and reports EVERY element as missing --
#
#     TWindows[] has no row for: mweAutoSendCount, mweBandMode, ... (48 of them)
#
# which is what failed the v5.0.4 release build on the win-ci runner, whose
# workspace is C:\actions-runner-v334\_work\... The lint had therefore NEVER
# been able to pass on any machine but the one it was written on.
#
# WORSE, AND THE REASON THIS IS WRITTEN DOWN: it fails as a FALSE NEGATIVE in
# the other direction too. Checking a clean clone at /tmp/whatever also read
# c:/tr4w-d12 and reported "the .lfm is current" about a tree it never opened.
# A check that silently answers about a different repository is worse than no
# check, because it is believed.
_REPO = os.path.dirname(_HERE)

VC = os.path.join(_REPO, 'tr4w', 'src', 'VC.pas')
LFM = os.path.join(_REPO, 'tr4w', 'src', 'ui', 'lcl', 'uMainForm.lfm')

CRLF = '\r\n'

# NO MARKER COMMENTS IN THE .lfm.  Lazarus form text is a strict object grammar
# with no comment syntax at all -- a `{ ... }` line makes the resource compiler
# stop with "Symbol expected but { found", which is how this was found.  The
# generated region is identified by the COMPONENT NAMES instead, which is what
# a regeneration has to match anyway.

# THE GEOMETRY, AT THE DEFAULT SCALE. Each is the Python twin of a function in
# tr4w/src/uMainLayout.pas; keep the two in step.
WS = 17                                   # VC.pas: WindowSize = 5; ws = WindowSize + 12
LAYOUT_COLUMNS = 46
LAYOUT_WIDTH = LAYOUT_COLUMNS * WS        # LayoutWidth
BAND_ROWS = 7
BOTTOM_BAND_MARGIN = 6
TOP_BAND_HEIGHT = BAND_ROWS * WS          # TopBandHeight
BOTTOM_BAND_HEIGHT = BAND_ROWS * WS + BOTTOM_BAND_MARGIN   # BottomBandHeight
NEEDS_BLOCK_COLUMNS = 14
NEEDS_FIRST_COLUMN = LAYOUT_COLUMNS - NEEDS_BLOCK_COLUMNS
NEEDS_BLOCK_WIDTH = NEEDS_BLOCK_COLUMNS * WS                # NeedsBlockWidth
# The log at its start height, MAIN_LOG_START_ROWS = 5: LogHeightForRows.
EDITABLE_LOG_HEIGHT = 30 + 5 * (WS + 2)

# THE STATUS BAR'S OWN HEIGHT, WHICH IS NEW SPACE AND NOT SPACE TAKEN.
#
# sbStatus is hand-written in the .lfm -- it is chrome, not an element of
# TWindows[] -- and Align = alBottom decides where it goes. The bottom band
# sits on top of it. Its height is needed here only to size the FORM.
#
# The runtime twin of this number is uMainForm.MainStatusBarHeight, which
# MainUnit adds to the client height it hands MakeMainWindowResizeable -- and
# that is the one that matters on screen, because the .lfm size is a
# design-time picture. There it is READ FROM THE CONTROL rather than restated.
STATUS_BAR_HEIGHT = 23

CLIENT_HEIGHT = (TOP_BAND_HEIGHT + EDITABLE_LOG_HEIGHT + BOTTOM_BAND_HEIGHT
                 + STATUS_BAR_HEIGHT)

TOP_BAND = 'pnlTopBand'
NEEDS_BLOCK = 'pnlNeedsBlock'
BOTTOM_BAND = 'pnlBottomBand'
BANDS = (TOP_BAND, NEEDS_BLOCK, BOTTOM_BAND)

# THE HAND-WRITTEN CONTROLS OF THE BOTTOM BAND, and where each goes in it, in
# band coordinates: (left, top, width, height, extra properties). The rects
# are uMainLayout's LastHourBarRect, RateBarRect, TourDurationBarRect,
# TourDurationTextRect and PossibleCallRect. The strip is alBottom in the
# band, BOTTOM_BAND_MARGIN above the band's bottom edge.
HAND_BLOCKS = {
   'pbLastHour': (28 * WS, 3 * WS, 5 * WS, WS, []),
   'pbRate': (33 * WS, 3 * WS, 5 * WS, WS, []),
   'pbTourDuration': (33 * WS, 5 * WS, 5 * WS, WS, []),
   'pnlTourDuration': (38 * WS, 5 * WS, 8 * WS, WS, []),
   'lstPossibleCall': (0, BOTTOM_BAND_HEIGHT - BOTTOM_BAND_MARGIN - WS, LAYOUT_WIDTH, WS,
                       [('Align', 'alBottom'),
                        ('BorderSpacing.Bottom', str(BOTTOM_BAND_MARGIN))]),
}


# ---------------------------------------------------------------------------
# THE .lfm AS A TREE.
#
#   An object is its header line, its own property lines (kept verbatim,
#   relative to the object's indent, so a collection or a continued string
#   survives untouched) and its child objects. The file is printed back from
#   the tree, so everything this script does not own comes back as it was.

OBJ_RE = re.compile(r'^(\s*)(object|inherited|inline)\s+(\w*)\s*:\s*(\w+)')
COLLECTION_RE = re.compile(r'^[\w.]+\s*=\s*<\s*$')


class Obj(object):
   def __init__(self, head, name, cls):
      self.head = head          # 'object Name: TClass'
      self.name = name
      self.cls = cls
      self.props = []           # property lines, relative to the object's indent + 2
      self.children = []        # Obj


def parse_obj(lines, i):
   """The object starting at lines[i], and the index after its `end`."""
   m = OBJ_RE.match(lines[i])
   indent = len(m.group(1))
   obj = Obj(lines[i].strip(), m.group(3), m.group(4))
   i += 1
   while i < len(lines):
      line = lines[i]
      if OBJ_RE.match(line):
         child, i = parse_obj(lines, i)
         obj.children.append(child)
         continue
      if line.strip() == 'end' and len(line) - len(line.lstrip(' ')) == indent:
         return obj, i + 1
      if COLLECTION_RE.match(line.strip()):
         # A collection closes on the first line that is `end>`; its items'
         # `end` lines are not an object's.
         while True:
            obj.props.append(dedent(lines[i], indent + 2))
            if lines[i].strip() == 'end>':
               break
            i += 1
         i += 1
         continue
      obj.props.append(dedent(line, indent + 2))
      i += 1
   raise SystemExit('uMainForm.lfm: object %s has no end' % obj.name)


def dedent(line, n):
   if line[:n].strip() == '':
      return line[n:]
   return line.lstrip(' ')


def render(obj, indent):
   pad = ' ' * indent
   out = [pad + obj.head]
   out += [(pad + '  ' + p) if p else p for p in obj.props]
   for child in obj.children:
      out += render(child, indent + 2)
   out.append(pad + 'end')
   return out


def set_prop(obj, key, value, after=None):
   """Set the object's own `key = value` line, adding it after `after` (or at
   the end) when it has none. Only the object's own lines: a nested
   collection's are indented further and never match."""
   text = '%s = %s' % (key, value)
   for n, p in enumerate(obj.props):
      if p.startswith(key + ' = '):
         obj.props[n] = text
         return
   at = len(obj.props)
   if after is not None:
      for n, p in enumerate(obj.props):
         if p.startswith(after + ' = '):
            at = n + 1
   obj.props.insert(at, text)


def prop(obj, key, default=0):
   for p in obj.props:
      if p.startswith(key + ' = '):
         try:
            return int(p.split('=', 1)[1].strip())
         except ValueError:
            return default
   return default


def take(parent, names, found):
   """Remove every object named in `names` from parent's subtree, recording
   it in `found` by name. A removed object's own children are searched too,
   so the hand-written controls are found inside an old band."""
   kept = []
   for child in parent.children:
      take(child, names, found)
      if child.name in names:
         found[child.name] = child
      else:
         kept.append(child)
   parent.children = kept


# ---------------------------------------------------------------------------
# WHAT THE TABLE SAYS.

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


def panel(name, left, top, width, height, caption='', sunken=True,
          alignment='taCenter', enabled=True, visible=True):
   """One TElementPanel.

   ONE EMITTER for every panel this script writes.  The property ORDER matters
   beyond tidiness: --check compares the generated text to the file byte for
   byte, so two emitters that agreed on content but not on order would make
   the check fail with nothing actually wrong.  TabOrder is set later, once
   the band's reading order is known.
   """
   obj = Obj('object %s: TElementPanel' % name, name, 'TElementPanel')
   obj.props = ['Left = %d' % left,
                'Height = %d' % height,
                'Top = %d' % top,
                'Width = %d' % width,
                'Alignment = %s' % alignment,
                'AutoSize = False',
                'BevelOuter = %s' % ('bvLowered' if sunken else 'bvNone'),
                "Caption = '%s'" % caption.replace("'", "''")]
   if not enabled:
      obj.props.append('Enabled = False')
   obj.props.append('ParentColor = False')
   obj.props.append('ParentFont = False')
   obj.props.append('TabOrder = 0')
   if not visible:
      obj.props.append('Visible = False')
   return obj


def band(name, left, top, width, height, align):
   """One band: a plain TPanel with no bevel, border or caption, so its client
   area IS its bounds and a child's band coordinates are exact. ParentColor
   is the TPanel default, so it shows the form's colour. Dragging it moves the
   window, as dragging the form's own background did before the bands
   covered it."""
   obj = Obj('object %s: TPanel' % name, name, 'TPanel')
   obj.props = ['Left = %d' % left,
                'Height = %d' % height,
                'Top = %d' % top,
                'Width = %d' % width,
                'Align = %s' % align,
                'BevelOuter = bvNone',
                "Caption = ''",
                'TabOrder = 0',
                'OnMouseDown = MainFormMouseDown',
                'OnMouseMove = MainFormMouseMove',
                'OnMouseUp = MainFormMouseUp']
   return obj


# ---------------------------------------------------------------------------
# THE TWO GRIDS THAT ARE NOT IN TWindows[].
#
#   The score totals grid (8 columns x 4 rows, plus 7 band headers) in the top
#   band, and the QSO-need / mult-need band strips in the needs block.  They
#   were sixty-seven raw Win32 STATICs created in code -- MainUnit's
#   CreateTotalWindows, CreateQSONeedWindows and CreateMultsWindows.  Their
#   geometry is a FORMULA, and a hand-typed copy of a formula drifts.
#
#   Not from TWindows[] because they are not elements: they are addressed by
#   (column, row) and by (row, band), which is what uMainGrids exposes.

TOT_COLS = 8                 # TotWinHandles: array[0..7, 0..3]
TOT_ROWS = 4
TOT_HEAD_FIRST = 1           # TotWinheadHandles: array[1..7]

# BandStringsArray, Band160..Band10 -- the six HF contest bands the strips show.
NEED_BANDS = ['160', '80', '40', '20', '15', '10']

# How much wider than a band cell the row LABEL is.  ZERO, and it was tried
# at WS and at WS*2 first: Lint-FormOverlap rejected both, because
# pnlDupeInfoCall ends at exactly the needs block's left edge and there is no
# empty space to take.  The labels get a smaller, UNIFORM font instead -- see
# uMainGrids.MatchNeedLabelFonts.  Kept as a named zero rather than deleted so
# the next person does not re-derive the same rejection.  (In the needs block
# a wider label would also start left of the block, outside it.)
LABEL_EXTRA = 0


def totals_panels():
   """The score totals grid, from CreateTotalWindows' own arithmetic.

   Column 0 is the wide label column; column 7 ("All") is wider than the band
   columns between them.  The header row sits above the cells and is what
   carries the current-band highlight.
   """
   colw = round(WS * 2.5)
   label_w = WS * 5
   out = []

   def cell_geometry(c):
      # THE BAND COLUMNS START AFTER THE LABEL COLUMN, not one pixel inside
      # it.  Column 0 is WS * 5 to line up with the clock panels above it
      # (TWindows[] gives those 5 units), while the pitch is round(WS * 2.5)
      # = 42 -- so the old (c + 1) * colw put column 1 at 84 against a label
      # column ending at 85.  uMainLayout.TotalsColumnGeometry is the runtime
      # twin of this and carries the full note.
      if c == 0:
         return 0, label_w
      return label_w + (c - 1) * colw, (round(WS * 3) if c == 7 else colw)

   for c in range(TOT_COLS):
      left, width = cell_geometry(c)
      for r in range(TOT_ROWS):
         out.append(panel('pnlTotalCell_%d_%d' % (c, r), left, WS * 2 + r * WS, width, WS,
                          alignment=('taLeftJustify' if c == 0 else 'taCenter')))

   for c in range(TOT_HEAD_FIRST, TOT_COLS):
      left, width = cell_geometry(c)
      out.append(panel('pnlTotalHead_%d' % c, left, 0, width, WS * 2))

   return out


def needs_panels():
   """The QSO-need and mult-need band strips, in needs-block coordinates.

   THE CELLS ARE CREATED HIDDEN and revealed per band.  That is not a
   decision made here: the Win32 style they used, uVisStyleNoSun, omits
   WS_VISIBLE, so every cell started hidden and ShowWindow drove it.  A
   generated `Visible = True` would put six band labels permanently on screen.

   Row 1 is CW when the contest counts by mode and Both when it does not; row
   2 is SSB and is shown only in the by-mode case.  The row LABEL is visible
   from the start and right-aligned, as its own style (SS_RIGHT, WS_VISIBLE)
   said.
   """
   w = WS * 2
   out = []

   for kind, row_tops in (('QSONeed', (WS, WS * 2)),
                          ('MultNeed', (WS * 4, WS * 5))):
      for row, top in enumerate(row_tops, start=1):
         out.append(panel('pnl%sR%dLabel' % (kind, row), 0 - LABEL_EXTRA, top,
                          w + LABEL_EXTRA, WS, sunken=False,
                          alignment='taRightJustify'))
         for i, band_name in enumerate(NEED_BANDS):
            out.append(panel('pnl%sR%d_%s' % (kind, row, band_name), (i + 1) * w, top,
                             w - 2, WS, caption=band_name, sunken=False,
                             visible=False))

   return out


def element_panels():
   """Every TWindows[] row that gets a panel, as (band name, panel), placed in
   its band as uMainLayout.ElementBand / ElementRect place it."""
   order, by = read_rows()
   out = []

   for element in order:
      (_, _, style, text, _colour, _back, _i, b, x, y, w, h) = by[element]

      # The runtime loop skips these: they are not status panels.  The call
      # and exchange fields, the log grid, the possible-call strip and the
      # two network windows are built by their own routines, and
      # mweWholeScreen is the main window itself.
      if style.strip() in ('0', '1', '2'):
         continue

      sunken, centre, visible, enabled = style_flags(style)
      column, row = int(x), int(y)

      if int(b) == 1:
         where = BOTTOM_BAND
         row -= BAND_ROWS
      elif column >= NEEDS_FIRST_COLUMN:
         where = NEEDS_BLOCK
         column -= NEEDS_FIRST_COLUMN
      else:
         where = TOP_BAND

      out.append((where, panel(component_name(element), column * WS, row * WS,
                               int(w) * WS, int(h) * WS, caption=text,
                               sunken=sunken,
                               alignment=('taCenter' if centre else 'taLeftJustify'),
                               enabled=enabled, visible=visible)))

   return out


def in_reading_order(children):
   """The children sorted as Lint-TabOrder reads them, with TabOrder set to
   match: lfm_taborder.row_order, the lint's own rule."""
   stubs = []
   for n, child in enumerate(children):
      node = lfm_taborder.Node(child.name, child.cls, 0, None)
      node.props = {'Top': str(prop(child, 'Top')), 'Left': str(prop(child, 'Left')),
                    'TabOrder': str(n)}
      node.obj = child
      stubs.append(node)
   ordered = [node.obj for node in lfm_taborder.row_order(stubs)]
   for n, child in enumerate(ordered):
      set_prop(child, 'TabOrder', n)
   return ordered


def generate(root):
   """Rebuild the bands inside the parsed form `root`; answer the count of
   generated panels."""
   elements = element_panels()
   totals = totals_panels()
   needs = needs_panels()

   owned = set(BANDS) | set(HAND_BLOCKS)
   owned |= {p.name for _, p in elements} | {p.name for p in totals + needs}

   found = {}
   take(root, owned, found)

   missing = [n for n in HAND_BLOCKS if n not in found]
   if missing:
      raise SystemExit('uMainForm.lfm has no %s -- a hand-written control of the '
                       'bottom band is missing' % ', '.join(missing))

   hands = []
   for name, (left, top, width, height, extra) in sorted(HAND_BLOCKS.items()):
      obj = found[name]
      set_prop(obj, 'Left', left)
      set_prop(obj, 'Height', height)
      set_prop(obj, 'Top', top)
      set_prop(obj, 'Width', width)
      after = 'Width'
      for key, value in extra:
         set_prop(obj, key, value, after=after)
         after = key
      hands.append(obj)

   top = band(TOP_BAND, 0, 0, LAYOUT_WIDTH, TOP_BAND_HEIGHT, 'alTop')
   block = band(NEEDS_BLOCK, LAYOUT_WIDTH - NEEDS_BLOCK_WIDTH, 0, NEEDS_BLOCK_WIDTH,
                TOP_BAND_HEIGHT, 'alRight')
   bottom = band(BOTTOM_BAND, 0, TOP_BAND_HEIGHT + EDITABLE_LOG_HEIGHT, LAYOUT_WIDTH,
                 BOTTOM_BAND_HEIGHT, 'alBottom')

   block.children = in_reading_order([p for w, p in elements if w == NEEDS_BLOCK] + needs)
   top.children = in_reading_order([p for w, p in elements if w == TOP_BAND] + totals
                                   + [block])
   bottom.children = in_reading_order([p for w, p in elements if w == BOTTOM_BAND] + hands)

   # The form's own children: the bands join whatever is hand-written there
   # (the timers and sbStatus), in reading order among the windowed ones.
   root.children += [top, bottom]
   set_prop(top, 'TabOrder', 0)
   set_prop(bottom, 'TabOrder', 1)

   return len(elements) + len(totals) + len(needs)


def size_form(root):
   """The FORM at the layout's client size, and the status strip at its
   bottom.

   The designer draws the form at its .lfm size, and the runtime window is
   sized separately (MainUnit: ws * 46 wide).  Sized to the layout EXACTLY,
   with no margin, so the alRight needs block is drawn where it sits at run
   time.  sbStatus is aligned, so its place is only a picture too; it is set
   so the picture is consistent.
   """
   for key, value in (('Height', CLIENT_HEIGHT), ('Width', LAYOUT_WIDTH),
                      ('ClientHeight', CLIENT_HEIGHT), ('ClientWidth', LAYOUT_WIDTH)):
      set_prop(root, key, value)
   for child in root.children:
      if child.name == 'sbStatus':
         set_prop(child, 'Top', CLIENT_HEIGHT - STATUS_BAR_HEIGHT)
         set_prop(child, 'Width', LAYOUT_WIDTH)


def main():
   raw = io.open(LFM, 'rb').read().decode('utf-8-sig')
   lines = raw.split(CRLF)
   if not OBJ_RE.match(lines[0]):
      raise SystemExit('uMainForm.lfm: the first line is not the form')

   root, after = parse_obj(lines, 0)
   tail = lines[after:]

   count = generate(root)
   size_form(root)

   new = CRLF.join(render(root, 0) + tail)

   if '--check' in sys.argv:
      if new != raw:
         raise SystemExit(
            'uMainForm.lfm is out of date with VC.pas TWindows[].\n'
            'Run: python tools/gen_main_elements.py')
      print('gen_main_elements: %d panel(s) in 3 bands, .lfm is current' % count)
      return

   io.open(LFM, 'wb').write(new.encode('utf-8'))
   print('gen_main_elements: %d panel(s) at ws=%d in 3 bands, form %dx%d'
         % (count, WS, LAYOUT_WIDTH, CLIENT_HEIGHT))


if __name__ == '__main__':
   main()
