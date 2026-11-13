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


MY_STATION_ROWS = (("call", "grid", "state", "county"), ("section", "park", "cq_zone", "itu_zone"),
   ("year_sent",))


def my_station_fields(editor):
   """Edit QSO's "Our station for this QSO" inputs by their designed rows
   (uEditQSOForm.lfm grpMyStation): the one container whose direct Edit
   children form rows of 4, 4 and 1. Rows and columns are observed geometry;
   a different shape fails rather than guessing which box is which."""
   matches = []
   for container in editor.descendants():
      if container.class_name() == "Edit" or not container.is_visible():
         continue
      edits = [child for child in container.children() if child.class_name() == "Edit"]
      if len(edits) != 9:
         continue
      rows = {}
      for edit in edits:
         top = edit.rectangle().top
         key = next((existing for existing in rows if abs(existing - top) <= 4), top)
         rows.setdefault(key, []).append(edit)
      ordered = [sorted(rows[key], key=lambda c: c.rectangle().left) for key in sorted(rows)]
      if [len(row) for row in ordered] == [len(names) for names in MY_STATION_ROWS]:
         matches.append({name: control for names, row in zip(MY_STATION_ROWS, ordered)
            for name, control in zip(names, row)})
   if len(matches) != 1:
      raise RuntimeError("Edit QSO our-station group not uniquely observable: " + str(len(matches)))
   return matches[0]


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
