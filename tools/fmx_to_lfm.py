"""Convert a Delphi FMX designed form (.fmx) to a Lazarus LCL one (.lfm).

The FMX -> LCL port is mechanical for the overwhelming majority of TR4W's
designed forms: 467 control instances across five forms, of which nine types
account for 449, and every one of those nine exists in the LCL under the same
name.  This does that translation.

WHAT IT REFUSES TO DO IS THE POINT.  A converter that silently drops a control
or a property produces a form that looks plausible and is missing a setting --
in a 4,410-line Preferences window, nobody notices until an operator cannot find
something.  So every control type and every property is either MAPPED, or
EXPLICITLY DROPPED by name, or it is an error that stops the conversion.  There
is no default-ignore path.

THE AUTOSIZE HAZARD, proven by spike/lclprobe:

    LCL controls autosize by DEFAULT; FMX ones do not.  A streamed Width/Height
    is accepted and then silently overridden -- a TLabel's 90 became 42 to fit
    its caption.  It is not "sizes are ignored": TEdit.Width came through at 200
    and TPanel at 60, so ONLY the autosizing dimensions move, and a converted
    form looks right in the .lfm while being wrong on screen.  TR4W ships in
    nine languages, so a label sized to fit English is exactly the defect that
    survives testing and clips in the Russian build.

    The signal is already in the .fmx: Size.PlatformDefault = False means "this
    size is explicit", and appears 434 times.  Every control carrying it gets
    AutoSize = False.

Usage:
    python fmx_to_lfm.py <in.fmx> [-o <out.lfm>]     convert one form
    python fmx_to_lfm.py --check <in.fmx> ...        report only, write nothing
"""

import argparse
import os
import re
import sys

# --------------------------------------------------------------------------
# Type mapping.  A type that is not here is an ERROR, not a pass-through.
# --------------------------------------------------------------------------
# Same name in both frameworks -- the easy 449 of 467.
SAME_NAME = {
    'TLabel', 'TEdit', 'TCheckBox', 'TButton', 'TComboBox',
    'TRadioButton', 'TListBox', 'TGroupBox', 'TPanel', 'TTreeView',
}

# No direct twin.  Each substitute was streamed and checked in spike/lclprobe.
SUBSTITUTE = {
    # FMX's invisible grouping container.  TPanel with no bevel is the closest
    # LCL analogue; the alternative (drop it, re-parent the children) loses the
    # grouping that the Preferences navigation relies on.
    'TLayout':     ('TPanel', {'BevelOuter': 'bvNone', 'Caption': "''"}),
    # LCL pages are TPageControl / TTabSheet.
    'TTabControl': ('TPageControl', {}),
    'TTabItem':    ('TTabSheet', {}),
    # FMX's editable combo.  csDropDown is the LCL equivalent of "typing
    # allowed"; csDropDownList would silently make it read-only.
    'TComboEdit':  ('TComboBox', {'Style': 'csDropDown'}),
}

# TTreeViewItem is NOT convertible as a streamed object: LCL's TTreeView holds
# TTreeNode built in code, not design-time children.  Reported, never guessed.
BUILD_IN_CODE = {'TTreeViewItem'}

# --------------------------------------------------------------------------
# Property mapping.
# --------------------------------------------------------------------------
RENAME = {
    'Position.X':   'Left',
    'Position.Y':   'Top',
    'Size.Width':   'Width',
    'Size.Height':  'Height',
}

# Carried through unchanged.
KEEP = {
    'Left', 'Top', 'Width', 'Height', 'Caption', 'Text', 'TabOrder', 'Tag',
    'Visible', 'Enabled', 'Anchors', 'GroupName', 'Checked', 'ClientHeight',
    'ClientWidth', 'BorderIcons', 'BorderStyle', 'ItemIndex', 'Style',
    'BevelOuter', 'Name', 'ShowHint', 'Hint', 'ReadOnly', 'MaxLength',
    'ItemHeight', 'Color', 'Font.Height', 'Font.Name', 'Font.Style',
    'TabIndex', 'Align',
}

# Dropped ON PURPOSE, each with the reason.  Being on this list is a decision;
# anything not on it and not mapped stops the conversion.
DROP = {
    'Size.PlatformDefault':      'consumed -- it is what triggers AutoSize = False',
    'FormFactor.Width':          'FMX mobile form-factor preview, no LCL meaning',
    'FormFactor.Height':         'FMX mobile form-factor preview, no LCL meaning',
    'FormFactor.Devices':        'FMX mobile form-factor preview, no LCL meaning',
    'DesignerMasterStyle':       'FMX style designer, no LCL meaning',
    'TextSettings.Trimming':     'FMX text trimming; LCL labels clip differently',
    'Touch.InteractiveGestures': 'FMX gesture support, no LCL meaning',
    'DisableFocusEffect':        'FMX focus rendering, no LCL meaning',
    'Viewport.Width':            'FMX scrollable viewport, no LCL meaning',
    'Viewport.Height':           'FMX scrollable viewport, no LCL meaning',
    'IsExpanded':                'TTreeViewItem only -- those are built in code',
    'StyleLookup':               'FMX style name, no LCL meaning',
    'StyledSettings':            'FMX style inheritance, no LCL meaning',
    'CanFocus':                  'FMX focus flag; LCL uses TabStop',
    'HitTest':                   'FMX hit-testing, no LCL meaning',
    'TabPosition':               'FMX tab placement; LCL uses TPageControl.TabPosition values',
    'CustomIcon':                'FMX per-tab icon (binary blob), no LCL equivalent',
    'ExplicitSize.cx':           'FMX designer bookkeeping, not a real property',
    'ExplicitSize.cy':           'FMX designer bookkeeping, not a real property',
    'TextSettings.Font.Size':    'FMX font sizing; LCL uses Font.Height, and the default is right for every control here',
    'DefaultItemStyles.ItemStyle':        'FMX TListBox item styling, no LCL meaning',
    'DefaultItemStyles.GroupHeaderStyle': 'FMX TListBox item styling, no LCL meaning',
    'DefaultItemStyles.GroupFooterStyle': 'FMX TListBox item styling, no LCL meaning',
    # IsSelected marks the active FMX tab.  Dropped rather than mapped because
    # the LCL equivalent lives on the PARENT (TPageControl.ActivePage), not on
    # the sheet -- emitting it per-sheet would be three controls each claiming
    # to be active.  The converter reports it so the parent can be set by hand.
    'IsSelected':                'FMX per-tab active flag; LCL sets TPageControl.ActivePage instead',
}

# Enumerated values whose spelling differs.
VALUE_MAP = {
    ('Position', 'ScreenCenter'): 'poScreenCenter',
    ('Position', 'DesktopCenter'): 'poDesktopCenter',
    ('BorderStyle', 'Single'):    'bsSingle',
    ('BorderStyle', 'None'):      'bsNone',
    ('BorderStyle', 'Sizeable'):  'bsSizeable',
    ('BorderStyle', 'ToolWindow'): 'bsToolWindow',
}

OBJ_RE = re.compile(r'^(\s*)object\s+(\w+):\s*(\w+)\s*$')
END_RE = re.compile(r'^(\s*)end\s*$')
PROP_RE = re.compile(r'^(\s*)([A-Za-z][\w.]*)\s*=\s*(.*)$')


class Problem(Exception):
    pass


def num(value):
    """FMX writes coordinates as 16.000000000000000000; LCL wants 16."""
    v = value.strip()
    if re.fullmatch(r'-?\d+\.\d+', v):
        f = float(v)
        return str(int(round(f)))
    return v


# Controls whose visible string is Caption in the LCL but Text in FMX.  Getting
# this wrong is silent: the control streams fine and shows nothing.
# LCL controls that are TGraphicControl, not TWinControl.  They have NO
# TabOrder and no TabStop -- FMX puts TabOrder on every control, so emitting it
# for a TLabel makes the whole form fail to stream:
#     EReadError: Error reading lblAddress.TabOrder: Unknown property "TabOrder"
# TLabel alone is 189 of the 467 control instances, so this is not an edge case.
NON_WINDOWED = {'TLabel', 'TShape', 'TImage', 'TSpeedButton', 'TBevel'}

WINCONTROL_ONLY = {'TabOrder', 'TabStop'}

CAPTION_TYPES = {
    'TLabel', 'TButton', 'TCheckBox', 'TRadioButton', 'TGroupBox',
    'TPanel', 'TTabSheet', 'TForm',
}


def convert(text, path):
    out = []
    problems = []
    notes = []
    # One entry per nesting level: (name, kind, lcl_type).  kind is 'form',
    # 'control' or 'skip'.
    stack = []

    def cur_type():
        return stack[-1][2] if stack else ''

    # A dropped property whose value is a MULTI-LINE collection or list --
    # 'CustomIcon = <' followed by 'item' / 'end>' -- used to leave its body
    # behind as orphan lines, and the orphan 'end' was then miscounted as an
    # object terminator.  The value has to be swallowed with the property.
    # Depth, not a flag: FMX nests collections inside collections.
    swallow = 0

    def opens_multiline(v):
        v = v.strip()
        return v.endswith('<') or v.endswith('(')

    for raw in text.split('\r\n'):
        line = raw.rstrip('\r')
        if swallow:
            s = line.strip()
            swallow += s.count('<') + s.count('(')
            swallow -= s.count('>') + s.count(')')
            if swallow < 0:
                swallow = 0
            continue

        m = OBJ_RE.match(line)
        if m:
            indent, name, ftype = m.group(1), m.group(2), m.group(3)

            if ftype in BUILD_IN_CODE:
                notes.append('%s: %s is not streamable in the LCL -- build it in '
                             'code (TTreeNode), NOT emitted' % (name, ftype))
                stack.append((name, 'skip', ftype))
                continue

            kind = 'form' if not stack else 'control'
            if ftype in SAME_NAME:
                lcl, extra = ftype, {}
            elif ftype in SUBSTITUTE:
                lcl, extra = SUBSTITUTE[ftype]
                notes.append('%s: %s -> %s' % (name, ftype, lcl))
            elif kind == 'form':
                lcl, extra = ftype, {}    # the form class keeps its own name
            else:
                problems.append('%s: UNKNOWN control type %s -- no mapping, '
                                'conversion stopped' % (name, ftype))
                stack.append((name, 'skip', ftype))
                continue

            if not any(s[1] == 'skip' for s in stack):
                out.append('%sobject %s: %s' % (indent, name, lcl))
                for k, v in sorted(extra.items()):
                    out.append('%s%s = %s' % (indent + '  ', k, v))
            stack.append((name, kind, lcl))
            continue

        m = END_RE.match(line)
        if m and stack:
            skipping = any(s[1] == 'skip' for s in stack)
            stack.pop()
            if not skipping:
                out.append('%send' % m.group(1))
            continue

        m = PROP_RE.match(line)
        if m and stack:
            indent, prop, value = m.group(1), m.group(2), m.group(3)
            name = stack[-1][0]

            # Inside a control we could not map, emit nothing at all.
            if any(s[1] == 'skip' for s in stack):
                continue

            # Emitted the moment it is seen rather than buffered to the end of
            # the object: an LCL property may appear in any order, and buffering
            # was what put the FORM's own properties inside its first child.
            if prop == 'Size.PlatformDefault':
                if value.strip().lower() == 'false' and stack[-1][1] != 'form':
                    out.append('%sAutoSize = False' % indent)
                if opens_multiline(value):
                    swallow = 1
                continue

            if prop in DROP:
                if opens_multiline(value):
                    swallow = 1
                continue

            if prop in RENAME:
                out.append('%s%s = %s' % (indent, RENAME[prop], num(value)))
                continue

            # FMX calls it Text everywhere; the LCL splits Caption and Text by
            # control.  A TLabel given Text streams cleanly and displays nothing.
            if prop == 'Text':
                target = 'Caption' if cur_type() in CAPTION_TYPES else 'Text'
                out.append('%s%s = %s' % (indent, target, value))
                continue

            if prop.startswith('On'):
                out.append('%s%s = %s' % (indent, prop, value))
                continue

            # FMX marks a masked edit with Password = True; the LCL masks by
            # setting the character to show.  A rename would be wrong and a drop
            # would render the operator's radio password in CLEAR TEXT, so this
            # is a value transform and it is deliberate.
            if prop == 'Password':
                if value.strip().lower() == 'true':
                    out.append("%sPasswordChar = '*'" % indent)
                continue

            # TabOrder/TabStop exist only on TWinControl.  See NON_WINDOWED.
            if prop in WINCONTROL_ONLY and cur_type() in NON_WINDOWED:
                continue

            if prop in KEEP or prop == 'Position':
                key = (prop, value.strip())
                if key in VALUE_MAP:
                    out.append('%s%s = %s' % (indent, prop, VALUE_MAP[key]))
                else:
                    out.append('%s%s = %s' % (indent, prop, num(value)))
                continue

            # Multi-line values (Items.Strings = ( ... )).
            if value.strip().endswith('(') or prop.endswith('.Strings'):
                out.append('%s%s = %s' % (indent, prop, value))
                continue

            problems.append('%s: UNKNOWN property %s = %s -- not mapped, not on '
                            'the drop list' % (name, prop, value.strip()[:40]))
            continue

        # Continuation lines of a multi-line value, and blank lines.
        if not any(s[1] == 'skip' for s in stack):
            out.append(line)

    if stack:
        problems.append('unbalanced object/end -- %d still open' % len(stack))

    return '\r\n'.join(out) + '\r\n', problems, notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('files', nargs='+')
    ap.add_argument('-o', '--out')
    ap.add_argument('--check', action='store_true',
                    help='report only; write nothing')
    args = ap.parse_args()

    rc = 0
    for f in args.files:
        text = open(f, 'rb').read().decode('utf-8', errors='surrogateescape')
        lfm, problems, notes = convert(text, f)

        print('=== %s ===' % os.path.basename(f))
        for n in notes:
            print('   note: %s' % n)
        for p in problems:
            print('   PROBLEM: %s' % p)

        if problems:
            print('   %d problem(s) -- NOT written' % len(problems))
            rc = 1
            continue

        if args.check:
            print('   would convert cleanly (%d lines)' % lfm.count('\r\n'))
            continue

        out = args.out or os.path.splitext(f)[0] + '.lfm'
        with open(out, 'wb') as fh:
            fh.write(lfm.encode('utf-8', errors='surrogateescape'))
        print('   -> %s' % out)

    return rc


sys.exit(main())
