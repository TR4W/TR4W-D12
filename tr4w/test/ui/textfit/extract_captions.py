# -*- coding: utf-8 -*-
"""Every FIXED-WIDTH captioned control in the designed forms, as TSV.

The inventory half of the text-fit measurement.  It answers "which controls
were given a hand-typed width", which is a question about the .lfm files and
needs no widget set.  textfit_probe.lpr answers the other half -- "how wide
does this caption actually come out ON THIS PLATFORM" -- which needs one.

WHY THE SPLIT, and why this is not src/ui/lcl/uTextFitAudit.pas.

uTextFitAudit measures forms that are OPEN, from inside the running program.
It is the truthful instrument -- real form, real font, real language -- and it
has one limitation that no amount of work inside it removes: a form that has
never been constructed has no controls to measure, so it only ever sees the
windows an operator has opened.  On a headless CI box nobody opens anything.

This pair measures from the .lfm instead, so every form is covered whether or
not it can be shown, at the cost of rebuilding each control standalone rather
than reading the real one.  The two are complements, not copies: when they
disagree, uTextFitAudit is right, because it is looking at the actual window.

USAGE
   python extract_captions.py captions.tsv
   <compile textfit_probe.lpr -- see its header>
   ./textfit_probe captions.tsv

COLUMNS
   form, control, class, width, font height, font name, bold, caption
"""

import re
import glob
import io
import os
import sys

# AutoSize defaults, per LCL class.  A class whose default is True is only
# FIXED when the .lfm explicitly says AutoSize = False.
AUTOSIZE_DEFAULT_TRUE = {'TLabel', 'TCheckBox', 'TRadioButton', 'TStaticText',
                         'TToggleBox'}

CAPTIONED = {'TButton', 'TBitBtn', 'TCheckBox', 'TRadioButton', 'TLabel',
             'TGroupBox', 'TSpeedButton', 'TStaticText', 'TToggleBox',
             'TRadioGroup', 'TCheckGroup', 'TPanel'}


def unquote(value):
   """The text out of an .lfm string literal, doubled quotes undone."""
   parts = re.findall(r"'([^']*(?:''[^']*)*)'", value)
   return ''.join(p.replace("''", "'") for p in parts)


def form_font(path):
   """The form's own font, which every control inherits unless it overrides.

   Read by stopping at the first child object: everything before that belongs
   to the form itself."""
   height, name = -11, ''
   with io.open(path, encoding='utf-8', errors='replace') as handle:
      for line in handle:
         if line.startswith('  object'):
            break
         stripped = line.strip()
         if stripped.startswith('Font.Height = ') and height == -11:
            height = int(stripped[14:])
         if stripped.startswith('Font.Name = ') and not name:
            name = unquote(stripped[12:])
   return height, name


def controls_in(path):
   """Every object in one .lfm, innermost first, with what we measure by.

   Nesting is tracked because an 'end' closes the innermost object and a form
   is objects all the way down."""
   stack, current, found = [], None, []
   with io.open(path, encoding='utf-8', errors='replace') as handle:
      for line in handle:
         stripped = line.strip()
         match = re.match(r'object\s+(\w+):\s*(T\w+)$', stripped)
         if match:
            if current is not None:
               stack.append(current)
            current = {'name': match.group(1), 'cls': match.group(2),
                       'w': None, 'cap': None, 'auto': None, 'wrap': False,
                       'fh': None, 'fn': None, 'fb': 0}
            continue
         if stripped == 'end':
            if current is not None:
               found.append(current)
               current = stack.pop() if stack else None
            continue
         if current is None:
            continue
         if stripped.startswith('Width = '):
            current['w'] = int(stripped[8:])
         elif stripped.startswith('Caption = '):
            current['cap'] = unquote(stripped[10:])
         elif stripped.startswith('AutoSize = '):
            current['auto'] = (stripped[11:] == 'True')
         elif stripped.startswith('WordWrap = '):
            current['wrap'] = (stripped[11:] == 'True')
         elif stripped.startswith('Font.Height = '):
            current['fh'] = int(stripped[14:])
         elif stripped.startswith('Font.Name = '):
            current['fn'] = unquote(stripped[12:])
         elif stripped.startswith('Font.Style') and 'fsBold' in stripped:
            current['fb'] = 1
   return found


def main(lfm_dir, out_path):
   written = 0
   forms = 0
   out = io.open(out_path, 'w', encoding='utf-8', newline='\n')
   for path in sorted(glob.glob(os.path.join(lfm_dir, '*.lfm'))):
      forms += 1
      form = os.path.basename(path)[:-4]
      default_height, default_name = form_font(path)
      for control in controls_in(path):
         if control['cls'] not in CAPTIONED:
            continue
         if not control['cap'] or not control['cap'].strip():
            continue
         if control['w'] is None:
            continue
         # A class that autosizes by default is only fixed when told not to.
         if control['cls'] in AUTOSIZE_DEFAULT_TRUE:
            fixed = (control['auto'] is False)
         else:
            fixed = (control['auto'] is not True)
         if not fixed:
            continue
         # A WORD-WRAPPED LABEL IS SUPPOSED TO BE WIDER THAN ITS BOX.  Whether
         # it still fits is a question about HEIGHT, which uTextFitAudit asks
         # properly; measuring one here reports every explanatory paragraph as
         # catastrophically clipped, and that noise buries the real findings.
         if control['wrap']:
            continue
         height = control['fh'] if control['fh'] is not None else default_height
         name = control['fn'] if control['fn'] else default_name
         out.write(u'\t'.join([form, control['name'], control['cls'],
                               str(control['w']), str(height), name,
                               str(control['fb']),
                               control['cap'].replace('\t', ' ')]) + u'\n')
         written += 1
   out.close()
   print('%d fixed-width captioned control(s) across %d form file(s) -> %s'
         % (written, forms, out_path))


if __name__ == '__main__':
   here = os.path.dirname(os.path.abspath(__file__))
   default_lfm = os.path.normpath(os.path.join(here, '..', '..', '..',
                                               'src', 'ui', 'lcl'))
   target = sys.argv[1] if len(sys.argv) > 1 else 'captions.tsv'
   source = sys.argv[2] if len(sys.argv) > 2 else default_lfm
   main(source, target)
