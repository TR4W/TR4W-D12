"""Native Cocoa Preferences operations for the shared persistence scenario."""

import json

from mac_bridge import wait_for


class MacPreferences:
   def __init__(self, bridge, application, window, output, journal):
      self.bridge = bridge
      self.application = application
      self.window = window
      self.output = output
      self.journal = journal
      self.selected_path = None
      self.sequence = 0

   def send(self, operation, **fields):
      return self.bridge(operation, pid=self.application().pid, **fields)

   def nodes(self):
      tree = self.send("inspect")["tree"]
      roots = [row for row in tree if row.get("AXRole") == "AXWindow" and "Preferences" in row.get("AXTitle", "")]
      if len(roots) != 1:
         raise AssertionError("Cocoa Preferences accessibility root is not unique")
      path = roots[0]["path"]
      return [row for row in tree if row["path"][:len(path)] == path]

   def selector(self, row):
      return {"window": "Preferences", "role": row["AXRole"], "path": row["path"]}

   def focus(self, row):
      self.send("focus", selector=self.selector(row))
      wait_for("Cocoa control focus", lambda: any(item["path"] == row["path"] and item.get("AXFocused")
         for item in self.nodes()), 5)

   def replace_text(self, row, value):
      self.focus(row)
      self.send("key", key="a", modifiers=["command"])
      # Make replacement explicit before posting and acknowledging new text.
      self.send("key", key="backspace")

      def displayed(expected):
         matches = [item for item in self.nodes() if item["path"] == row["path"]]
         if len(matches) != 1 or not matches[0].get("AXFocused"):
            raise AssertionError("Cocoa focus left the intended text field during input")
         return matches[0].get("AXValue", "") == expected

      wait_for("Cocoa text field cleared", lambda: displayed(""), 5)
      prefix = ""
      for character in value:
         self.send("text", text=character)
         prefix += character
         # A posted event is not a delivery acknowledgement. Read each prefix
         # before posting the next character; bulk posting lost trailing input.
         wait_for("Cocoa text prefix " + repr(prefix), lambda: displayed(prefix), 5)

   def open_preferences(self):
      self.send("activate")
      self.journal.perform("open Cocoa Preferences", lambda: self.send("key", key="j", modifiers=["control"]))
      wait_for("Cocoa Preferences window", lambda: self.window("Preferences"), 15)

   def selected(self):
      matches = [row for row in self.nodes() if row["path"] == self.selected_path and row.get("AXRole") == "AXTextField"]
      if len(matches) != 1 or not matches[0].get("AXEnabled"):
         raise AssertionError("Selected Cocoa setting is no longer an enabled text field")
      return matches[0]

   def select_setting(self, term):
      edits = [row for row in self.nodes() if row.get("AXRole") == "AXTextField" and row.get("AXEnabled") and "rectangle" in row]
      if not edits:
         raise AssertionError("Cocoa Preferences has no visible search field")
      search = min(edits, key=lambda row: (row["rectangle"][0], row["rectangle"][1]))
      self.replace_text(search, term)
      # Cocoa exposes the owner-drawn results as unnamed cells. Require a
      # unique popup below search and exactly one result for this exact query.
      # The native click additionally validates the live bounds and hit target.
      def result_cell():
         rows = self.nodes()
         x, y, width, height = search["rectangle"]
         tables = [row for row in rows if row.get("AXRole") == "AXTable" and "rectangle" in row
            and abs(row["rectangle"][0] - x) <= height / 2
            and y + height <= row["rectangle"][1] < y + height * 2
            and row["rectangle"][2] > width]
         if len(tables) != 1:
            return None
         path = tables[0]["path"]
         cells = [row for row in rows if row.get("AXRole") == "AXCell" and row["path"][:len(path)] == path]
         if len(cells) > 1:
            raise AssertionError("Exact Cocoa setting query has multiple result cells")
         if not cells:
            return None
         table = tables[0]
         tx, ty, tw, th = table["rectangle"]
         cx, cy, cw, ch = cells[0]["rectangle"]
         if not (cx <= tx + tw / 2 < cx + cw and cy <= ty + th / 2 < cy + ch):
            raise AssertionError("Search table center is outside its unique result cell")
         # Virtual owner-drawn cells hit-test as their native table. Target
         # that table only after proving its center lies in the sole result.
         return table

      cell = wait_for("Single Cocoa search result " + term, result_cell, 5)
      self.journal.perform("click single Cocoa search result " + term,
         lambda: self.send("click", selector=self.selector(cell)))

      def focused_setting():
         matches = [row for row in self.nodes() if row.get("AXRole") == "AXTextField" and row.get("AXFocused")
            and row["path"] != search["path"]]
         return matches[0] if len(matches) == 1 else None

      row = wait_for("Cocoa searched setting focus", focused_setting, 8)
      self.selected_path = row["path"]
      self.sequence += 1
      (self.output / f"setting-{self.sequence:02d}.json").write_text(json.dumps(self.nodes(), indent=3))

   def read_value(self):
      return self.selected().get("AXValue", "")

   def write_value(self, value):
      self.replace_text(self.selected(), value)

   def footer_state(self):
      rows = self.nodes()
      states = {}
      for caption in ("Save", "Save and close", "Cancel"):
         matches = [row for row in rows if row.get("AXRole") == "AXButton" and row.get("AXTitle") == caption]
         if len(matches) != 1:
            raise AssertionError("Cocoa footer button is not unique: " + caption)
         states[caption] = bool(matches[0].get("AXEnabled"))
      return states

   def activate_footer(self, caption):
      self.journal.perform("activate Cocoa Preferences " + caption,
         lambda: self.send("click" if caption == "Cancel" else "press",
            selector={"window": "Preferences", "role": "AXButton", "title": caption}))
      if caption == "Save":
         wait_for("Cocoa Save completed", lambda: not self.footer_state()["Save"], 10)
      else:
         wait_for("Cocoa Preferences dismissed", lambda: not self.window("Preferences"), 10)
