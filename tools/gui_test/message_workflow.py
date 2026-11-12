"""Program and capture Marv's message examples through the visible editors."""

import json

from session import capture


def program_messages(app, main, output, journal, event="CWO", exchange="# TOM", read_only=False, include_modifiers=False, bank="Standard"):
   if event not in {"CWO", "CWT"}:
      raise ValueError("Expected CWO or CWT")
   # An inspection phase may have left the editor/list open. Dismiss without sending.
   for title in ("Program message", "List of messages", "Memory program function"):
      window = app.window(title=title)
      if window.exists(timeout=0) and window.is_visible():
         journal.perform("dismiss existing " + title, lambda: window.type_keys("{ESC}"))
   cq = {
      "F1": "CQ " + event + " \\ \\ " + event,
      "F2": event + " \\", "F3": "", "F4": "@", "F5": "\\",
      "F6": "DE \\", "F7": "AGN?", "F8": "QRL?", "F9": "?",
      "F11": "TOM", "F12": "#" if event == "CWO" else "FL",
   }
   other = {
      "CQ CW EXCHANGE": exchange,
      "CQ CW EXCHANGE NAME KNOWN": exchange,
      "S&P CW EXCHANGE": exchange,
      "REPEAT S&P CW EXCHANGE": exchange,
      "QSL CW MESSAGE": "73 \\ " + event,
      "QUICK QSL CW MESSAGE": "TU \\",
      "QSO BEFORE CW MESSAGE": "SRI QSO B4 TU \\ " + event,
   }
   expected = {}
   for key, replacements in (
      ("c", {"CQ CW MEMORY " + k: v for k, v in cq.items()}),
      ("e", {"EX CW MEMORY " + k: v for k, v in cq.items() if k not in {"F1", "F2"}}),
      ("o", other),
   ):
      if bank != "Standard" and key == "o":
         continue
      journal.perform("focus main for message bank " + key, main.set_focus)
      journal.perform("open message bank chooser", lambda: main.menu_select("Settings->Program messages"))
      chooser = app.window(title="Memory program function")
      journal.perform("wait for message chooser", lambda: chooser.wait("visible", timeout=10))
      if key == "c":
         journal.perform("capture message chooser", lambda: capture(chooser, output / "message-chooser.png"))
      journal.perform("choose message bank " + key, lambda: chooser.type_keys(key))
      messages = app.window(title="List of messages")
      journal.perform("wait for message list", lambda: messages.wait("visible", timeout=10))
      if key != "o":
         journal.perform("select " + bank + " message bank", lambda: messages.child_window(title=bank, class_name="Button").click_input())
      listing = messages.child_window(class_name="SysListView32")
      names = [listing.get_item(i, 0).text() for i in range(listing.item_count())]
      (output / ("commands-" + key + ".json")).write_text(json.dumps(names, indent=3), encoding="utf-8")
      if bank != "Standard":
         command = names[2 if key == "c" else 0]
         if bank.upper() not in command.upper() and not (bank == "Control" and "CTRL" in command.upper()):
            raise AssertionError("Selected bank does not match message command: " + command)
         replacements = {command: "GUI " + bank.upper() + " " + key.upper() + " TEST"}
      for command, value in replacements.items():
         if names.count(command) != 1:
            raise RuntimeError("Message command is not unique: " + command + " in " + repr(names))
         index = names.index(command)
         if read_only:
            actual = listing.get_item(index, 1).text()
            if actual != value:
               raise AssertionError(command + ": expected " + repr(value) + ", got " + repr(actual))
            if include_modifiers and command == "CQ CW MEMORY F3" and listing.get_item(index, 2).text() != "GUI & CAPTION":
               raise AssertionError("Custom message caption did not survive restart")
            expected[command] = actual
            if command != "CQ CW MEMORY F1":
               continue
         journal.perform("select " + command, lambda: listing.select(index))
         journal.perform("focus selected memory", listing.set_focus)
         journal.perform("edit " + command, lambda: listing.type_keys("{ENTER}"))
         editor = app.window(title="Program message")
         journal.perform("wait for message editor", lambda: editor.wait("visible", timeout=10))
         fields = sorted(editor.descendants(class_name="Edit"), key=lambda c: c.rectangle().top)
         if len(fields) != 2:
            raise RuntimeError("Expected Message and Caption fields")
         if not read_only:
            journal.perform("set " + command, lambda: fields[0].set_edit_text(value))
         if not read_only and fields[1].is_enabled():
            caption = "GUI & CAPTION" if include_modifiers and command == "CQ CW MEMORY F3" else ""
            journal.perform("set custom caption for " + command, lambda: fields[1].set_edit_text(caption))
         if key == "o" and fields[1].is_enabled():
            raise AssertionError("Other-message Caption field should be disabled")
         if command == "CQ CW MEMORY F1":
            journal.perform("capture configured F1", lambda: capture(editor, output / "message-editor.png"))
         button = "Cancel" if read_only else "OK"
         journal.perform("close editor for " + command, lambda: editor.child_window(title=button).click_input())
         journal.perform("wait for editor close", lambda: editor.wait_not("visible", timeout=5))
         actual = listing.get_item(index, 1).text()
         if actual != value:
            raise AssertionError(command + ": expected " + repr(value) + ", got " + repr(actual))
         expected[command] = value
      journal.perform("show start of message bank", lambda: listing.get_item(0).ensure_visible())
      journal.perform("capture configured bank " + key,
         lambda: capture(messages, output / {"c": "cq-messages.png", "e": "sp-messages.png", "o": "other-messages.png"}[key]))
      journal.perform("close message list", lambda: messages.type_keys("{ESC}"))
   (output / "verified-messages.json").write_text(json.dumps(expected, indent=3), encoding="utf-8")
   if include_modifiers:
      for modifier in ("Control", "Alt"):
         directory = output / modifier.lower()
         directory.mkdir(exist_ok=True)
         program_messages(app, main, directory, journal, event, exchange, read_only, bank=modifier)
