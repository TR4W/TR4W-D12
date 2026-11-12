"""Shared operator-style entry for disposable practice logs, with CW suppressed."""


def entry_fields(main):
   fields = sorted([control for control in main.descendants(class_name="Edit") if control.is_visible()],
      key=lambda control: control.rectangle().top)
   if len(fields) != 2:
      raise RuntimeError("Expected the upper callsign and lower exchange inputs")
   return fields


def open_contact_editor(app, main, journal):
   grids = [control for control in main.descendants(class_name="Window") if control.is_visible()
      and control.rectangle().width() > 600 and 70 < control.rectangle().height() < 250]
   if len(grids) != 1:
      raise RuntimeError("Visible QSO grid is not unique")
   journal.perform("double-click the sole test contact", lambda: grids[0].double_click_input(coords=(300, 30)))
   editor = app.window(title="Edit QSO")
   editor.wait("visible enabled", timeout=10)
   return editor


def log_without_cw(main, call, exchange, journal):
   call_field, exchange_field = entry_fields(main)
   if call_field.window_text() or exchange_field.window_text():
      raise AssertionError("Practice entry must be empty before starting a new contact")
   journal.perform("focus callsign for " + call, call_field.set_focus)
   journal.perform("type callsign " + call, lambda: call_field.type_keys(call))
   journal.perform("advance without CW", lambda: call_field.type_keys("^{ENTER}"))
   journal.perform("focus exchange", exchange_field.set_focus)
   if exchange_field.window_text():
      journal.perform("replace suggested exchange with " + exchange,
         lambda: exchange_field.set_edit_text(exchange))
   else:
      journal.perform("enter exchange " + exchange, lambda: exchange_field.type_keys(exchange, with_spaces=True))
   journal.perform("log without CW", lambda: exchange_field.type_keys("^{ENTER}"))
   if call_field.window_text():
      journal.perform("complete CQ logging stage without CW", lambda: exchange_field.type_keys("^{ENTER}"))
   if call_field.window_text() or exchange_field.window_text():
      raise AssertionError("Entry fields did not clear after logging " + call)
