"""Shared black-box New Contest selection and entry helpers."""

from pywinauto import Application


def choose_contest(window, search, journal):
   edits = [control for control in window.descendants(class_name="Edit") if control.is_visible()]
   find = min(edits, key=lambda control: control.rectangle().left)
   call = min([control for control in edits if control.rectangle().left > find.rectangle().left],
      key=lambda control: control.rectangle().top)
   journal.perform("find contest " + search, lambda: find.set_edit_text(search))
   lists = [control for control in window.descendants(class_name="LCLListBox") if control.is_visible()]
   if len(lists) != 1:
      raise RuntimeError("Contest search list is not unique")
   journal.perform("focus contest results", lists[0].set_focus)
   journal.perform("select first matching contest", lambda: lists[0].type_keys("{HOME}"))
   journal.perform("enter practice station call", lambda: call.set_edit_text("W1AW"))
   journal.perform("leave callsign field", lambda: call.type_keys("{TAB}"))
   return sorted([control for control in window.descendants(class_name="Edit")
      if control.is_visible() and control.handle not in {find.handle, call.handle}],
      key=lambda control: control.rectangle().top)


def set_field(field, value, journal):
   journal.perform("focus form input", field.set_focus)
   journal.perform("enter " + value, lambda: field.set_edit_text(value))
   journal.perform("leave form input", lambda: field.type_keys("{TAB}"))


def dismiss_grid_prompt(app, journal):
   notice = app.window(class_name="#32770")
   if notice.exists(timeout=2):
      uiapp = Application(backend="uia").connect(process=app.process)
      text = " ".join(control.window_text() for control in uiapp.window(handle=notice.handle).descendants())
      if "Set value of MY GRID" not in text:
         raise RuntimeError("Unexpected startup prompt: " + text)
      journal.perform("defer grid for isolated UI-only fixture", lambda: notice.child_window(title="&No").click_input())
