"""Turn invalid-input sweep rows (sweep-rows.jsonl) into a compact markdown table.

   python tools/gui_test/sweep_report.py <suite folder>... --output docs/gui-test/<name>.md

Reads every sweep-rows.jsonl under the suite folder. Page names are LABELS
only, taken from the navigation tree's own construction in uPrefsForm.pas
(the 'TNavNode(x).Tag := n' after 'x := tvNav.Items.Add...(..., caption)');
a page not found there is shown by its tag.
"""

import argparse
import json
import re
from pathlib import Path

from input_checks import classify, render_sweep, shorten

PREFS_SOURCE = Path(__file__).resolve().parents[2] / "tr4w/src/ui/lcl/uPrefsForm.pas"
# Where the translated node captions (SPrefsNav...) are declared.
STRINGS_SOURCE = Path(__file__).resolve().parents[2] / "tr4w/src/uAppStrings.pas"


def page_names(source=PREFS_SOURCE, strings=STRINGS_SOURCE):
   names = {}
   if not source.is_file():
      return names
   text = source.read_text(encoding="utf-8", errors="replace")
   captions = dict(re.findall(r"(\w+)\s*:=\s*tvNav\.Items\.Add(?:Child)?\([^,]+,\s*'([^']+)'\)", text))
   symbols = dict(re.findall(r"(\w+)\s*:=\s*tvNav\.Items\.Add(?:Child)?\([^,]+,\s*(\w+)\)", text))
   constants = dict(re.findall(r"\b(NAV_\w+)\s*=\s*(\d+)\s*;", text))
   declared = {}
   if strings.is_file():
      declared = dict(re.findall(r"^\s*(SPrefs\w+)\s*=\s*'([^']*)'\s*;",
         strings.read_text(encoding="utf-8", errors="replace"), re.MULTILINE))
   for node, tag in re.findall(r"TNavNode\((\w+)\)\.Tag\s*:=\s*(\w+)\s*;", text):
      tag = constants.get(tag, tag)
      if tag.isdigit():
         symbol = symbols.get(node)
         names[int(tag)] = captions.get(node) or declared.get(symbol) or symbol or node
   return names


def load_captions(folder):
   """{(page, index): caption text} OCR'd by the sweep (box-names.json)."""
   captions = {}
   for path in Path(folder).rglob("box-names.json"):
      for item in json.loads(path.read_text(encoding="utf-8")):
         if item.get("text"):
            captions[(item["page"], item["index"])] = item["text"]
   return captions


def control_label(control, caption=""):
   label = caption or control.get("uia_name") or ""
   help_text = control.get("help") or ""
   if help_text and help_text != label:
      label = (label + " - " if label else "") + shorten(help_text, 70)
   return label or "box at " + str(control.get("rect"))


def load_rows(folder):
   rows = []
   for path in sorted(Path(folder).rglob("sweep-rows.jsonl")):
      for line in path.read_text(encoding="utf-8").splitlines():
         if line.strip():
            rows.append(json.loads(line))
   return rows


def load_pages(folder):
   pages = []
   for path in Path(folder).rglob("sweep-summary.json"):
      pages.extend(json.loads(path.read_text(encoding="utf-8")).get("pages", []))
   return pages


def coverage_lines(pages, names):
   """What the walk did NOT sweep, from each run's sweep-summary.json."""
   label = lambda page: str(page["tag"]) + " " + names.get(page["tag"], "")
   empty = [label(page).strip() for page in sorted(pages, key=lambda page: page["tag"]) if not page["boxes"]]
   totals = {}
   for page in pages:
      for reason, count in (page.get("skipped") or {}).items():
         totals[reason] = totals.get(reason, 0) + count
   scrolled = sum(page.get("scrolled_into_view", 0) for page in pages)
   unreachable = sum(page.get("not_reachable", 0) for page in pages)
   lines = ["- Pages walked: " + str(len(pages)) + "; pages with no writable text box: " + (", ".join(empty) or "none") + "."]
   if any("skipped" in page for page in pages):
      lines.append("- Text boxes NOT swept: " + ", ".join(reason + " " + str(count) for reason, count in sorted(totals.items()))
         + "; below the fold and swept after scrolling into view: " + str(scrolled)
         + "; could not be brought into view: " + str(unreachable) + ".")
   return lines


def table_rows(rows, names, captions=None):
   captions = captions or {}
   result = []
   for row in sorted(rows, key=lambda item: (item["page"], item["index"])):
      page = str(row["page"]) + " " + names.get(row["page"], "")
      caption = shorten(captions.get((row["page"], row["index"]), ""), 60)
      # Re-classified from the stored observation, so a classifier correction
      # applies to rows already collected.
      behaviour = classify(row["observation"]) if "observation" in row else row["behaviour"]
      result.append({"page": page.strip(), "control": control_label(row["control"], caption),
         "value": row["value"], "behaviour": behaviour})
   return result


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("suite", type=Path, nargs="+", help="one or more suite folders")
   parser.add_argument("--output", type=Path, required=True)
   parser.add_argument("--title", default="Preferences invalid-input sweep")
   parser.add_argument("--preface", action="append", default=[])
   args = parser.parse_args()
   rows = [row for folder in args.suite for row in load_rows(folder)]
   if not rows:
      raise SystemExit("No sweep-rows.jsonl rows under " + ", ".join(map(str, args.suite)))
   captions = {}
   pages = []
   for folder in args.suite:
      captions.update(load_captions(folder))
      pages.extend(load_pages(folder))
   names = page_names()
   text = render_sweep(table_rows(rows, names, captions), args.title, args.preface + coverage_lines(pages, names))
   args.output.write_bytes(text.encode("utf-8"))
   print(str(len(rows)) + " rows -> " + str(args.output))
   return 0


if __name__ == "__main__":
   raise SystemExit(main())
