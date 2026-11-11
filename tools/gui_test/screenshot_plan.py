"""Inventory the local MkDocs pages and generate a screenshot work list."""

import argparse
import csv
import re
from pathlib import Path


PRIORITIES = {
   "start/first-contest.md": "New contest search, call/name/category prompts, recent-log picker",
   "start/preferences.md": "Tree, search, Save/Cancel, restart notices",
   "station/radio.md": "Radio library, profile assignments, serial/network editor",
   "station/cw.md": "Keyer library, WinKeyer editor, CW output assignment",
   "station/cw-messages.md": "Message-group chooser, message list, message editor",
   "station/external-loggers.md": "Logger grid, provider fields, enabled/order/status",
   "station/wsjtx.md": "UDP settings and received practice contact",
   "station/so2r.md": "Two-radio profile and active-radio indication",
   "station/language.md": "Language selection and translated Preferences layout",
   "operating/bandmap.md": "Spots, filters, tuning and context menu using a mock radio",
   "operating/callsign-assistance.md": "Partial-call candidates and history settings",
   "operating/appearance.md": "Color settings and recovery of an off-screen window",
   "log/backup.md": "Backup settings, success path and external-copy status",
   "log/restore.md": "Open backup copy and verify contest identity",
   "log/export.md": "Cabrillo headings, generated file preview and output location",
   "log/import.md": "Append confirmation and completion counts in a practice log",
}


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
   parser.add_argument("--output", type=Path)
   args = parser.parse_args()
   destination = args.output or args.root / "docs" / "GUI_SCREENSHOT_INVENTORY.csv"
   rows = []
   for path in sorted((args.root / "user-guide").rglob("*.md")):
      text = path.read_text(encoding="utf-8")
      relative = path.relative_to(args.root / "user-guide").as_posix()
      title = re.search(r"^#\s+(.+)$", text, re.MULTILINE)
      images = re.findall(r"!\[[^\]]*\]\(([^)]+)\)", text)
      rows.append({
         "page": relative,
         "title": title.group(1) if title else relative,
         "priority": "high" if relative in PRIORITIES else "review",
         "requested_states": PRIORITIES.get(relative, "Decide whether an illustration aids this page"),
         "existing_images": " | ".join(images),
         "status": "images linked; review currency" if images else "not illustrated",
      })
   with destination.open("w", newline="", encoding="utf-8") as stream:
      writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
      writer.writeheader()
      writer.writerows(rows)
   print(f"Inventoried {len(rows)} MkDocs pages: {destination}")


if __name__ == "__main__":
   main()
