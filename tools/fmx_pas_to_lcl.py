"""Port an FMX form/helper unit's Pascal to the LCL.

The companion to fmx_to_lfm.py, which does the markup.  This does the code.

WHY IT IS TYPE-AWARE.  The single largest idiom is `.Text`, 181 occurrences
across the units being ported, and it CANNOT be renamed blindly: FMX calls the
visible string Text on every control, while the LCL splits it -- Caption on
TLabel/TButton/TCheckBox/TRadioButton/TGroupBox, Text on TEdit/TComboBox.  Get
it backwards and the control streams and compiles perfectly and displays
nothing, which is the failure mode this whole port has been trying to avoid.

So the receiver's type is resolved first, from two sources:

  * the .fmx, which names every designed control and its class, and
  * `name: TType` declarations in the unit itself, for locals and fields.

Anything whose type cannot be resolved is REPORTED AND LEFT ALONE rather than
guessed at -- a compile error a person then fixes, instead of a silent blank.

Usage:
    python fmx_pas_to_lcl.py <in.pas> [--fmx <form.fmx>] -o <out.pas>
"""

import argparse
import os
import re
import sys

CAPTION_TYPES = {
    'TLabel', 'TButton', 'TCheckBox', 'TRadioButton', 'TGroupBox',
    'TPanel', 'TTabSheet', 'TForm', 'TSpeedButton',
}
TEXT_TYPES = {'TEdit', 'TComboBox', 'TMemo', 'TListBox'}

# FMX unit -> LCL unit.  A one-to-many collapse: FMX splits controls across many
# units where the LCL keeps a handful.
USES_MAP = {
    'FMX.Types': 'Controls',
    'FMX.Controls': 'Controls',
    'FMX.Forms': 'Forms',
    'FMX.StdCtrls': 'StdCtrls',
    'FMX.Edit': 'StdCtrls',
    'FMX.Layouts': 'ExtCtrls',
    'FMX.Controls.Presentation': 'Controls',
    'FMX.ListBox': 'StdCtrls',
    'FMX.TabControl': 'ComCtrls',
    'FMX.TreeView': 'ComCtrls',
    'FMX.Dialogs': 'Dialogs',
    'FMX.Platform.Win': 'uHostedFormWindows',
    'FMX.Graphics': 'Graphics',
    'FMX.Objects': 'ExtCtrls',
    'FMX.ComboEdit': 'StdCtrls',
    'FMX.ScrollBox': 'Forms',
    'FMX.Memo': 'StdCtrls',
    'FMX.Menus': 'Menus',
    'FMX.Ani': None,          # no LCL equivalent and nothing here uses it
    'FMX.Effects': None,
    'FMX.Filter.Effects': None,
}

UNIT_RENAME = {
    'uFMXFormHelpers': 'uLCLFormHelpers',
    'uFMXTranslate':   'uLCLTranslate',
    'uFMXCoexist':     'uHostedFormWindows',
}

# Straight token substitutions that carry no type ambiguity.
TOKENS = [
    (r'\bIsChecked\b',                 'Checked'),
    (r'\bTFmxObject\b',                'TWinControl'),
    (r'\bTCloseAction\.caHide\b',      'caHide'),
    (r'\bTCloseAction\.caFree\b',      'caFree'),
    (r'\bTCloseAction\.caNone\b',      'caNone'),
    (r'\bRegisterFMXFormHandle\b',     'RegisterHostedFormHandle'),
    (r'\bUnregisterFMXFormHandle\b',   'UnregisterHostedFormHandle'),
    (r'\bMessageIsForFMXWindow\b',     'MessageIsForHostedWindow'),
    (r'\bAnyFMXWindowOpen\b',          'AnyHostedWindowOpen'),
    (r'\bFormToHWND\(Self\)',          'Self.Handle'),
    (r'\bFormToHWND\((\w+)\)',         r'\1.Handle'),
    (r'\bTAlignLayout\.',              'al'),
    (r'\bTTextAlign\.',                'ta'),
]

DECL_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*:\s*(T[A-Za-z]\w*)\s*;', re.M)
DOTTEXT_RE = re.compile(r'\b([A-Za-z_]\w*)\.Text\b')


def build_type_map(pas, fmx_path):
    """control/variable name -> type, from the .fmx and from declarations."""
    types = {}
    if fmx_path and os.path.exists(fmx_path):
        f = open(fmx_path, encoding='utf-8', errors='surrogateescape').read()
        for name, ftype in re.findall(r'^\s*object\s+(\w+):\s*(\w+)\s*$', f, re.M):
            types[name] = ftype
    # Declarations in the unit win only where the .fmx said nothing, so a
    # designed control keeps the class the designer gave it.
    for name, ttype in DECL_RE.findall(pas):
        types.setdefault(name, ttype)
    return types


def port(pas, types):
    unresolved = []

    # --- uses clauses --------------------------------------------------------
    def fix_uses(m):
        unit = m.group(1)
        if unit in USES_MAP:
            repl = USES_MAP[unit]
            return '' if repl is None else repl
        return unit

    pas = re.sub(r'\b(FMX\.[A-Za-z.]+)\b', fix_uses, pas)
    for old, new in UNIT_RENAME.items():
        pas = re.sub(r'\b%s\b' % old, new, pas)

    # --- token substitutions -------------------------------------------------
    for pat, repl in TOKENS:
        pas = re.sub(pat, repl, pas)

    # --- the type-aware one --------------------------------------------------
    def fix_text(m):
        name = m.group(1)
        ttype = types.get(name)
        if ttype in CAPTION_TYPES:
            return '%s.Caption' % name
        if ttype in TEXT_TYPES:
            return m.group(0)
        if ttype is None:
            unresolved.append(name)
        return m.group(0)

    pas = DOTTEXT_RE.sub(fix_text, pas)
    return pas, sorted(set(unresolved))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('source')
    ap.add_argument('--fmx')
    ap.add_argument('-o', '--out', required=True)
    args = ap.parse_args()

    pas = open(args.source, encoding='utf-8', errors='surrogateescape').read()
    types = build_type_map(pas, args.fmx)
    out, unresolved = port(pas, types)

    open(args.out, 'w', encoding='utf-8', errors='surrogateescape',
         newline='').write(out)

    print('%s -> %s' % (os.path.basename(args.source), os.path.basename(args.out)))
    print('   %d control/variable types resolved' % len(types))
    if unresolved:
        print('   %d UNRESOLVED .Text receiver(s), left as .Text for a human:'
              % len(unresolved))
        for n in unresolved:
            print('      %s' % n)

    leftover = [l.strip() for l in out.splitlines()
                if 'FMX' in l and not l.strip().startswith(('//', '{', '*', '}'))]
    if leftover:
        print('   %d line(s) still mentioning FMX:' % len(leftover))
        for l in leftover[:10]:
            print('      %s' % l[:96])
    return 0


sys.exit(main())
