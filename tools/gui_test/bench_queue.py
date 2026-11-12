"""Index unchecked bench items for review; signals never constitute a test pass."""

import argparse
import hashlib
import json
import re
from pathlib import Path


SIGNALS = {
   "screen_form": r"preferenc|dialog|\bform\b|screen|layout|clipp|label|caption|\btab\b|grid|column|caret|checkbox|check box|drop.down|window|menu|button|tooltip|hover",
   "local_data": r"\btype\b|\benter\b|exchang|\bimport\b|\bexport\b|\badif\b|cabrillo|rescore|\bsave\b|reopen|persist",
   "k4": r"\bK4\b|Elecraft K4",
   "cluster": r"DX cluster|band.?map|\bspots?\b|telnet",
   "other_hardware": r"WinKey|paddle|\bIcom\b|\bKenwood\b|TS-\d|\bK3\b|FlexRadio|\bSDR\b|\bTNC\b|\bhamlib\b|rotator|\bCOM\d|DTR|RTS|serial port",
   "transmission_audio": r"\btransmit|\bkeying\b|\bkeyed\b|\bPTT\b|\baudio\b|\blisten\b|\bheard\b|\bsidetone\b|dummy load",
   "external_app_service": r"DXKeeper|DXLab|PathFinder|AC ?Log|N3FJP|World Radio League|\bWRL\b|Club ?Log|Cloudlog|Wavelog|HamScore|QRZ|WSJT|MMTTY|supercheckhistory|3830|sponsor|submission|upload",
   "multiple_instances": r"multi.op|\bpeers?\b|second (?:PC|computer|station|client)|two (?:PC|computer|station|client)|network server",
   "other_platform": r"Linux|macOS|gtk2|Cocoa|Wayland|X11|\bMac\b",
   "display_variants": r"150\s*%|125\s*%|200\s*%|scaling|\bDPI\b|German|Spanish|translat|language",
   "decision": r"ruling|decide|NY4I.s call|NY4I to rule|say which|should the caption|wording.*want|decision owed",
}


def index_queue(text):
   lines = text.splitlines()
   items = []
   headings = []
   current = None

   def finish():
      nonlocal current
      if current is None:
         return
      body = "\n".join(current.pop("body")).strip()
      current["text"] = body
      current["id"] = hashlib.sha256((current["section"] + "\n" + body).encode()).hexdigest()[:16]
      combined = current["section"] + "\n" + body
      current["signals"] = [name for name, pattern in SIGNALS.items() if re.search(pattern, combined, re.I)]
      items.append(current)
      current = None

   for number, line in enumerate(lines, 1):
      heading = re.match(r"^(#{1,6})\s+(.+)", line)
      checkbox = re.match(r"^\s*[-*] \[([ xX-])\]\s+(.+)", line)
      if heading:
         finish()
         depth = len(heading[1])
         headings = [(d, name) for d, name in headings if d < depth]
         headings.append((depth, heading[2]))
      elif checkbox:
         finish()
         current = {"line": number, "state": checkbox[1].lower(),
            "section": " / ".join(name for _, name in headings if _ > 1),
            "title": checkbox[2], "body": [checkbox[2]]}
      elif current is not None:
         current["body"].append(line)
   finish()
   return items


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--queue", type=Path, default=Path("docs/BENCH_QUEUE.md"))
   parser.add_argument("--output", type=Path, default=Path("build-out/bench-ui"))
   args = parser.parse_args()
   raw = args.queue.read_bytes()
   items = index_queue(raw.decode("utf-8-sig"))
   args.output.mkdir(parents=True, exist_ok=True)
   opened = [item for item in items if item["state"] == " "]
   counts = {name: sum(name in item["signals"] for item in opened) for name in SIGNALS}
   result = {"source": str(args.queue.resolve()), "sha256": hashlib.sha256(raw).hexdigest(),
      "total": len(items), "open": len(opened), "signal_counts_overlap": counts, "items": items}
   (args.output / "queue-index.json").write_text(json.dumps(result, indent=3), encoding="utf-8")
   summary = []
   for item in opened:
      summary.append(f"L{item['line']} [{','.join(item['signals'])}] {item['title'][:240]}")
   (args.output / "item-summary.txt").write_text("\n".join(summary), encoding="utf-8")
   print(json.dumps({key: value for key, value in result.items() if key != "items"}, indent=3))


if __name__ == "__main__":
   main()
