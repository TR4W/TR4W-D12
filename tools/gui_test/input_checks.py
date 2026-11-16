"""Pure helpers for the input-validation cases (no pywinauto, no win32).

Shared by the Station-page check (bench_station_check), the invalid-input
sweep (bench_invalid_sweep) and the host-side report (sweep_report), and
pinned by test_input_checks so they can be exercised without the VM.
"""

import re


# THE STATION FIELDS THE PROGRAM CHECKS (uStationFieldCheck.StationFieldProblem),
# in the page's designed order. caption is the visible TInputCaption text the
# driver pairs with its input by geometry (bench_station_names.station_rows);
# key is the property under settings.My in tr4w.json; bad is one value the
# rule must refuse; goods are values it must accept, tried in order until one
# differs from what the page loaded (a save writes only what changed, so a
# value equal to the loaded one would prove nothing in tr4w.json). words are
# what the message line must contain when it names this field: a caption word
# and a word only this field's reason uses, compared with spaces and
# punctuation removed so an OCR spacing slip does not matter.
STATION_FIELDS = (
   {"caption": "Grid square:", "command": "MY GRID", "key": "Grid", "bad": "ZZ99", "goods": ("EL88", "EL89"),
      "words": ("grid", "EL88")},
   {"caption": "CQ zone:", "command": "MY ZONE", "key": "Zone", "bad": "41", "goods": ("5", "4"),
      "words": ("cqzone", "1to40")},
   {"caption": "ITU zone:", "command": "MY ITU ZONE", "key": "ItuZone", "bad": "91", "goods": ("8", "7"),
      "words": ("ituzone", "1to90")},
   {"caption": "State/Province:", "command": "MY STATE", "key": "State", "bad": "AA", "goods": ("FL", "GA"),
      "words": ("state", "territory")},
   {"caption": "ARRL section:", "command": "MY SECTION", "key": "Section", "bad": "okh", "goods": ("WCF", "NFL"),
      "words": ("section", "racsection")},
   {"caption": "Country:", "command": "MY COUNTRY", "key": "Country", "bad": "QQQ", "goods": ("K", "VE"),
      "words": ("country", "ctydat")},
   {"caption": "Check:", "command": "MY CHECK", "key": "Check", "bad": "5", "goods": ("85", "86"),
      "words": ("check", "lasttwo")},
   {"caption": "Precedence:", "command": "MY PREC", "key": "Prec", "bad": "X", "goods": ("A", "B"),
      "words": ("precedence", "precedenceisoneletter")},
   {"caption": "FD class:", "command": "MY FD CLASS", "key": "FdClass", "bad": "2Z", "goods": ("2A", "3A"),
      "words": ("fdclass", "fieldday")},
   {"caption": "FOC number:", "command": "MY FOC NUMBER", "key": "FocNumber", "bad": "12a", "goods": ("1234", "1235"),
      "words": ("focnumber", "digitsonly")},
   {"caption": "IOTA:", "command": "MY IOTA", "key": "Iota", "bad": "NA-01", "goods": ("NA-001", "NA-002"),
      "words": ("iota", "na001")},
   {"caption": "Park:", "command": "MY PARK", "key": "Park", "bad": "abcdedf", "goods": ("US-0001", "US-0002"),
      "words": ("park", "us1234")},
   {"caption": "License year:", "command": "MY LICENSE YEAR", "key": "LicenseYear", "bad": "alph",
      "goods": ("1985", "1986"), "words": ("licenseyear", "1985")},
)

# Bad values written into tr4w.json before a launch, for the "loaded, never
# touched" check. Only fields with NO model value check (uCFG registers one
# for My.Country and My.LicenseYear, which would refuse the value on load),
# and not MY ZONE/MY COUNTRY, which are exempt while they show what they
# loaded. NY4I's own values. Section is first in page order.
PRELOADED_BAD = (("Section", "okh"), ("Park", "abcdedf"))

# The sentence the line starts with when Save is refused (SStationPageNotSaved).
NOT_SAVED_WORDS = ("stationsettingsnotsaved",)

# Top-level windows that come and go without meaning anything: tooltips.
TRANSIENT_WINDOW_CLASSES = {"HintWindow", "tooltips_class32"}

# Windows' own input-filter feedback (the balloon's drop shadow); reported as
# such by classify, never as the program's modal box.
INPUT_FILTER_CLASSES = {"SysShadow"}

# The sweep's three obviously invalid values.
SWEEP_VALUES = (
   ("letters", "abcxyz"),
   ("out-of-range number", "-99999999999"),
   ("300-char string", "X" * 300),
)


def squeeze(text):
   """Case-folded, with everything but letters and digits removed."""
   return re.sub(r"[^0-9a-z]", "", (text or "").casefold())


def names_all(text, words):
   """Does TEXT contain every word in WORDS (after squeeze on both)?"""
   flat = squeeze(text)
   return all(squeeze(word) in flat for word in words)


def names_any(text, words):
   flat = squeeze(text)
   return any(squeeze(word) in flat for word in words)


def choose_good(goods, loaded):
   """The first good value that differs from what the page loaded."""
   for value in goods:
      if value.casefold() != (loaded or "").strip().casefold():
         return value
   raise ValueError("Every good value equals the loaded text " + repr(loaded))


def is_red(pixel):
   """clRed text is drawn at full red (255, and its ClearType fringes keep
   255 in the red channel). Black ClearType text has ORANGE fringes too,
   measured (182, 102, 0) on the VM, so the red channel must be near full."""
   red, green, blue = pixel[:3]
   return red >= 220 and green <= 110 and blue <= 110


def red_pixels(image):
   """How many pixels of a PIL image are clearly red (clRed text, anti-aliased)."""
   data = image.convert("RGB").tobytes()
   return sum(1 for offset in range(0, len(data), 3) if is_red(data[offset:offset + 3]))


def keys_for(text):
   """TEXT escaped for pywinauto type_keys, whose +^%~(){}[] are commands."""
   return "".join("{" + character + "}" if character in "+^%~(){}[]" else character for character in text)


def stored_matches(key, stored, expected):
   """Compare a tr4w.json value with the typed one. ItuZone is an integer."""
   if stored is None:
      return False
   if key == "ItuZone":
      try:
         return int(stored) == int(expected)
      except (TypeError, ValueError):
         return False
   return str(stored).strip().casefold() == expected.strip().casefold()


def classify(observation):
   """What the program did with one invalid value in the sweep, in words.

   observation keys: crashed, hung, modals (list of texts), typed (what was
   sent), entered (read back before leaving), after (read back after
   leaving), focus_held, red_before, red_after, field_red."""
   if observation.get("crashed"):
      return ["crashed"]
   behaviours = []
   if observation.get("hung"):
      behaviours.append("hung")
   details = observation.get("window_details")
   if details is None:
      details = [{"class": "", "title": "", "text": text} for text in observation.get("modals") or []]
   balloon = False
   for item in details:
      if item.get("class") in INPUT_FILTER_CLASSES:
         # The shadow of Windows' own "Unacceptable character" balloon, which
         # a number-only box (ES_NUMBER) shows: not the program's window.
         balloon = True
         continue
      text = item.get("text") or ""
      if item.get("class"):
         text = item["class"] + " '" + (item.get("title") or "") + "': " + text
      behaviours.append("modal box: " + shorten(text, 90))
   if balloon:
      behaviours.append("Windows number-only balloon")
   typed, entered, after = observation.get("typed", ""), observation.get("entered", ""), observation.get("after", "")
   if observation.get("masked"):
      # Nothing typed into a password box can be read back from outside.
      typed = entered = after = ""
      behaviours.append("password box (value not readable)")
   if entered != typed:
      if entered == "":
         behaviours.append("refused while typing (field stayed empty)")
      elif typed.startswith(entered):
         behaviours.append("cut to " + str(len(entered)) + " chars while typing")
      else:
         behaviours.append("filtered while typing to " + repr(shorten(entered, 24)))
   if after != entered:
      behaviours.append("changed on leaving to " + repr(shorten(after, 24)))
   inline = []
   if observation.get("focus_held"):
      inline.append("focus held")
   if observation.get("field_red"):
      inline.append("field red")
   if observation.get("red_after", 0) - observation.get("red_before", 0) > 15:
      inline.append("red text appeared on page")
   if inline:
      behaviours.append("marked inline (" + ", ".join(inline) + ")")
   if not behaviours or behaviours == ["password box (value not readable)"]:
      behaviours.append("accepted silently" if not behaviours else "no window, no mark")
   return behaviours


BEHAVIOUR_KINDS = ("crashed", "hung", "modal box", "Windows number-only balloon", "password box", "no window, no mark",
   "refused while typing", "cut while typing",
   "filtered while typing", "changed on leaving", "marked inline", "accepted silently")


def behaviour_kind(behaviour):
   """The summary bucket of one classify() phrase ('cut to 40 chars while
   typing' -> 'cut while typing')."""
   if behaviour.startswith("cut to "):
      return "cut while typing"
   for kind in BEHAVIOUR_KINDS:
      if behaviour.startswith(kind):
         return kind
   return behaviour


def shorten(text, limit):
   text = " ".join((text or "").split())
   return text if len(text) <= limit else text[:limit - 3] + "..."


def render_sweep(rows, title, preface):
   """A compact markdown table of sweep rows (one per control and value)."""
   lines = ["# " + title, ""]
   lines.extend(preface)
   lines.append("")
   counts = {}
   for row in rows:
      for behaviour in row["behaviour"]:
         kind = behaviour_kind(behaviour)
         counts[kind] = counts.get(kind, 0) + 1
   lines.append("| Behaviour | Rows |")
   lines.append("| --- | --- |")
   for kind in sorted(counts, key=lambda name: (-counts[name], name)):
      lines.append("| " + kind + " | " + str(counts[kind]) + " |")
   lines.append("")
   lines.append("| Page | Control | Value | Behaviour |")
   lines.append("| --- | --- | --- | --- |")
   for row in rows:
      lines.append("| " + " | ".join(cell(value) for value in (row["page"], row["control"], row["value"],
         "; ".join(row["behaviour"]))) + " |")
   lines.append("")
   return "\r\n".join(lines)


def cell(text):
   return str(text).replace("|", "\\|").replace("\r", " ").replace("\n", " ")
