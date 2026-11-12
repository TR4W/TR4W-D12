"""Incremental live-radio documentation actions against one owned VM instance."""

import json
import time
from pathlib import Path

from pywinauto import Application
from pywinauto.controls.win32_controls import ComboBoxWrapper

from session import capture, close_normally, describe_windows, launch
from evidence import StepLog, preserve_build


def diagnose(root, run_name, output):
   root = Path(root)
   preserve_build(root / "app" / "tr4w_fpc.exe", root / "evidence")
   state = root / "runs" / run_name / "radio-workflow.json"
   pid = json.loads(state.read_text(encoding="utf-8"))["pid"]
   app = Application(backend="win32").connect(process=pid)
   describe_windows(app, output)
   top = app.top_window()
   top.set_focus()
   capture(top, output / "failure.png")


def step(root, run_name, phase):
   root = Path(root)
   output = root / "artifacts" / phase
   output.mkdir(parents=True, exist_ok=True)
   journal = StepLog(output / "steps.jsonl")
   metadata = journal.perform(
      "preflight: bitness, symbols, source provenance and immutable build archive",
      lambda: preserve_build(root / "app" / "tr4w_fpc.exe", root / "evidence"),
   )
   (output / "build-evidence.json").write_text(json.dumps(metadata, indent=3), encoding="utf-8")
   state = root / "runs" / run_name / "radio-workflow.json"
   if phase == "radio-start":
      if state.exists():
         raise RuntimeError("Radio workflow already has an owned process record")
      databases = list((root / "runs" / run_name).glob("*.db"))
      if len(databases) != 1:
         raise RuntimeError("Expected one isolated practice database")
      app = journal.perform("launch isolated application", lambda: launch(root, run_name, databases[0].name))
      state.write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   else:
      pid = json.loads(state.read_text(encoding="utf-8"))["pid"]
      app = journal.perform("attach owned application PID", lambda: Application(backend="win32").connect(process=pid))
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   journal.perform("wait for main window", lambda: main.wait("visible", timeout=30))
   if phase == "radio-finish":
      close_normally(app, main, journal)
      return {"pid": app.process, "phase": phase, "passed": True, "note": "Owned application closed normally"}
   if phase == "radio-start":
      journal.perform("focus main window", main.set_focus)
      journal.perform("Ctrl+J", lambda: main.type_keys("^j"))
      prefs = app.window(title="TR4W Preferences")
      journal.perform("wait for Preferences", lambda: prefs.wait("visible", timeout=10))
      # Initial page in this fixture is the visible radio library.
      journal.perform("click Add radio", lambda: prefs.child_window(title="Add...", class_name="Button").click_input())
   if phase == "radio-model":
      editor = app.window(title="Radio")
      journal.perform("wait for Radio editor", lambda: editor.wait("visible", timeout=10))
      edits = sorted(editor.descendants(class_name="Edit"), key=lambda c: c.rectangle().top)
      journal.perform("enter radio name", lambda: edits[0].set_edit_text("Elecraft K4"))
      combos = sorted(editor.descendants(class_name="LCLComboBox"), key=lambda c: c.rectangle().top)
      model = ComboBoxWrapper(combos[0].handle)
      # texts()[0] is the current selection, not another list entry.
      items = journal.perform("enumerate radio model choices", model.texts)[1:]
      matches = [text for text in items if "K4" in text and "Elecraft" in text]
      (output / "radio-models.json").write_text(json.dumps(items, indent=3), encoding="utf-8")
      if len(matches) != 1:
         raise RuntimeError("K4 model not uniquely identified: " + repr(matches))
      journal.perform("model.select Elecraft K4", lambda: model.select(matches[0]))
      journal.perform("tab.select Network", lambda: editor.child_window(class_name="SysTabControl32").select("Network"))
   if phase == "radio-address":
      editor = app.window(title="Radio")
      journal.perform("focus Radio editor", editor.set_focus)
      region = editor.child_window(class_name="SysTabControl32").rectangle()
      fields = sorted([
         c for c in editor.descendants(class_name="Edit") if c.is_visible()
         and c.rectangle().top > region.top and c.rectangle().bottom < region.bottom
         and c.parent().class_name() != "LCLComboBox"
      ], key=lambda c: c.rectangle().top)
      if len(fields) != 4:
         raise RuntimeError("Expected address, port, username and password fields on Network")
      journal.perform("enter K4 address", lambda: fields[0].set_edit_text("192.168.73.108"))
      journal.perform("enter K4 port", lambda: fields[1].set_edit_text("9200"))
      journal.perform("capture K4 network definition", lambda: capture(editor, output / "k4-network.png"))
      journal.perform("save radio definition", lambda: editor.child_window(title="Save and close").click_input())
      journal.perform("wait for radio editor close", lambda: editor.wait_not("visible", timeout=10))
   if phase == "radio-profile":
      prefs = app.window(title="TR4W Preferences")
      prompt = app.window(title="Station profile")
      if not prompt.exists(timeout=0) or not prompt.is_visible():
         journal.perform("focus Preferences", prefs.set_focus)
         journal.perform("new station profile", lambda: prefs.child_window(title="New...").click_input())
         prompt = app.top_window()
      if prompt.handle in {prefs.handle, main.handle}:
         raise RuntimeError("Profile-name prompt was not observable")
      edits = prompt.descendants(class_name="Edit")
      if len(edits) != 1:
         raise RuntimeError("Expected one profile-name input")
      journal.perform("name documentation profile", lambda: edits[0].set_edit_text("NY4I K4 documentation"))
      journal.perform("confirm profile name with Enter", lambda: prompt.type_keys("{ENTER}"))
      journal.perform("wait for name prompt close", lambda: prompt.wait_not("visible", timeout=10))
      combos = sorted([
         c for c in prefs.descendants(class_name="LCLComboBox") if c.is_visible()
      ], key=lambda c: (c.rectangle().top, c.rectangle().left))
      if len(combos) != 5:
         raise RuntimeError("Expected profile, two radios and two CW output choices")
      radio_one = ComboBoxWrapper(combos[1].handle)
      journal.perform("assign Elecraft K4 to Radio 1", lambda: radio_one.select("Elecraft K4"))
      journal.perform("capture assigned profile", lambda: capture(prefs, output / "k4-profile.png"))
      journal.perform("activate selected profile", lambda: prefs.child_window(title="Activate this profile now").click_input())
   if phase == "radio-save":
      prefs = app.window(title="TR4W Preferences")
      notice = app.window(class_name="#32770")
      if notice.exists(timeout=0):
         uiapp = Application(backend="uia").connect(process=app.process)
         text = " ".join(c.window_text() for c in uiapp.window(handle=notice.handle).descendants())
         if "Profile" not in text or "is active" not in text:
            raise RuntimeError("Unexpected modal before save: " + text)
         journal.perform("acknowledge profile-active notice", lambda: notice.child_window(title="&OK").click_input())
         journal.perform("wait for notice close", lambda: notice.wait_not("visible", timeout=5))
      journal.perform("save and close Preferences", lambda: prefs.child_window(title="Save and close").click_input())
      journal.perform("wait for Preferences close", lambda: prefs.wait_not("visible", timeout=10))
      journal.perform("focus main window", main.set_focus)
      journal.perform("open Radio 1 display", lambda: main.menu_select("Windows->Radio 1"))
   if phase == "radio-cluster":
      journal.perform("focus main window", main.set_focus)
      cluster = app.window(title="DX Cluster")
      if not cluster.exists(timeout=0) or not cluster.is_visible():
         journal.perform("open DX Cluster", lambda: main.menu_select("Windows->DX Cluster"))
      journal.perform("focus DX Cluster", cluster.set_focus)
      journal.perform("size cluster window to expose toolbar", lambda: cluster.move_window(x=40, y=80, width=900, height=450))
      # Configure is visible in the captured toolbar but has no Win32 caption.
      journal.perform("open visible Configure toolbar button", lambda: cluster.click_input(coords=(620, 46)))
   if phase == "radio-refresh":
      cluster = app.window(title="DX Cluster")
      journal.perform("close cluster console", cluster.close)
      journal.perform("reopen cluster console", lambda: main.menu_select("Windows->DX Cluster"))
      cluster = app.window(title="DX Cluster")
      journal.perform("focus refreshed cluster", cluster.set_focus)
      journal.perform("size refreshed console", lambda: cluster.move_window(x=40, y=80, width=900, height=450))
      combos = sorted([c for c in cluster.descendants(class_name="LCLComboBox") if c.is_visible()], key=lambda c: c.rectangle().left)
      choices = combos[0].texts()[1:]
      (output / "cluster-hosts.json").write_text(json.dumps(choices), encoding="utf-8")
      named = [value for value in choices if "NC7J" in value and "dxc.nc7j.com:7373" in value]
      if len(named) != 1:
         raise RuntimeError("Expected one named NC7J cluster: " + repr(choices))
      journal.perform("select saved cluster host", lambda: combos[0].select(named[0]))
      journal.perform("connect saved host", lambda: cluster.click_input(coords=(56, 46)))
   if phase == "radio-inspect":
      prefs = app.window(title="TR4W Preferences")
      fields = sorted([c for c in prefs.descendants(class_name="Edit")
         if c.is_visible() and c.is_enabled() and c.parent().class_name() != "LCLComboBox"],
         key=lambda c: c.rectangle().top)
      if len(fields) != 5:
         raise RuntimeError("Expected search, name, login, password and after-connect fields")
      journal.perform("name NC7J cluster", lambda: fields[1].set_edit_text("NC7J"))
      combo = [c for c in prefs.descendants(class_name="LCLComboBox") if c.is_visible()]
      if len(combo) != 1:
         raise RuntimeError("Expected one server input")
      server = combo[0].descendants(class_name="Edit")
      if len(server) != 1:
         raise RuntimeError("Expected one editable server field")
      journal.perform("set NC7J server and port", lambda: server[0].set_edit_text("dxc.nc7j.com:7373"))
      journal.perform("set explicit cluster login", lambda: fields[2].set_edit_text("NY4I-2"))
      journal.perform("select configured cluster", lambda: prefs.child_window(title="Use this").click_input())
      journal.perform("capture cluster settings", lambda: capture(prefs, output / "nc7j-settings.png"))
      journal.perform("save cluster settings", lambda: prefs.child_window(title="Save and close").click_input())
      journal.perform("wait for Preferences close", lambda: prefs.wait_not("visible", timeout=10))
      cluster = app.window(title="DX Cluster")
      journal.perform("focus cluster", cluster.set_focus)
      journal.perform("connect selected cluster", lambda: cluster.click_input(coords=(56, 46)))
   if phase == "radio-capture":
      cluster = app.window(title="DX Cluster")
      journal.perform("focus connected cluster", cluster.set_focus)
      journal.perform("request last 50 spots", lambda: cluster.click_input(coords=(545, 46)))
      journal.perform("allow cluster response", lambda: time.sleep(5))
      journal.perform("capture connected cluster", lambda: capture(cluster, output / "nc7j-connected.png"))
      bandmap = app.window(title="Bandmap")
      if not bandmap.exists(timeout=0) or not bandmap.is_visible():
         journal.perform("open Band Map", lambda: main.menu_select("Windows->Band Map"))
      journal.perform("focus populated bandmap", bandmap.set_focus)
      journal.perform("capture bandmap", lambda: capture(bandmap, output / "nc7j-bandmap.png"))
      radio = app.window(title="Radio 1 Elecraft K4")
      journal.perform("focus connected radio display", radio.set_focus)
      journal.perform("capture K4 radio display", lambda: capture(radio, output / "k4-radio.png"))
      journal.perform("capture refreshed main", lambda: main.set_focus())
      journal.perform("capture radio-updated main", lambda: capture(main, output / "k4-connected-main.png"))
   if phase == "radio-bandmap":
      bandmap = app.window(title="Bandmap")
      journal.perform("wait for existing bandmap", lambda: bandmap.wait("visible", timeout=10))
      journal.perform("focus live bandmap without selecting a spot", bandmap.set_focus)
      journal.perform("size bandmap for readable documentation", lambda: bandmap.move_window(x=40, y=80, width=600, height=400))
      journal.perform("capture received bandmap spots", lambda: capture(bandmap, output / "nc7j-bandmap.png"))
   if phase == "radio-messages":
      from message_workflow import program_messages
      program_messages(app, main, output, journal)
   journal.perform("dump visible control metadata", lambda: describe_windows(app, output))
   top = app.top_window()
   editor = app.window(title="Radio")
   if editor.exists(timeout=0) and editor.is_visible():
      top = editor
   elif phase in {"radio-address", "radio-profile"}:
      top = app.window(title="TR4W Preferences")
   journal.perform("focus captured window", top.set_focus)
   journal.perform("capture settled window", lambda: capture(top, output / "screen.png"))
   return {"pid": app.process, "phase": phase, "window": top.window_text(),
           "passed": True, "note": "Owned application intentionally remains open between documented actions"}
