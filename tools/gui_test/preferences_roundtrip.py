"""Platform-independent Preferences persistence scenario and storage oracle."""

from decimal import Decimal
import json


SETTING = "RADIUS OF EARTH"
SETTING_PATH = ("settings", "GridMap", "RadiusOfEarth")


def numeric(value):
   result = Decimal(str(value or 0))
   if not result.is_finite():
      raise AssertionError("Preference must be a finite number")
   return result


def stored_value(settings_path):
   value = json.loads(settings_path.read_text(encoding="utf-8-sig"))
   for key in SETTING_PATH:
      value = value.get(key) if isinstance(value, dict) else None
   return numeric(value)


def run_preferences_roundtrip(driver, settings_path, restart, journal, result=None):
   """Check the same observable behavior through each native driver."""
   if result is None:
      result = {}
   result.update(setting=SETTING, storage_path=list(SETTING_PATH), checks=[], passed=False)

   def inspect_setting(expected=None):
      driver.select_setting(SETTING)
      actual = numeric(driver.read_value())
      if expected is not None and actual != expected:
         raise AssertionError(f"Preferences value {actual} != expected {expected}")
      return actual

   def footer(dirty):
      states = driver.footer_state()
      expected = {"Save": dirty, "Save and close": True, "Cancel": True}
      if states != expected:
         raise AssertionError("Unexpected Preferences footer: " + repr(states))

   driver.open_preferences()
   baseline = inspect_setting()
   if stored_value(settings_path) != baseline:
      raise AssertionError("Initial UI and stored preference disagree")
   result["baseline"] = str(baseline)
   # uCFG validates this setting in kilometres. Use accepted values distinct
   # from the observed baseline. Only disposable run settings are changed.
   cancelled = Decimal(6371) if baseline != Decimal(6371) else Decimal(6373)
   saved = Decimal(6372) if baseline != Decimal(6372) else Decimal(6374)
   result.update(cancelled=str(cancelled), saved=str(saved))
   footer(False)
   journal.perform("edit preference for Cancel", lambda: driver.write_value(str(cancelled)))
   footer(True)
   if stored_value(settings_path) != baseline:
      raise AssertionError("Uncommitted edit reached settings on disk")
   driver.activate_footer("Cancel")
   if stored_value(settings_path) != baseline:
      raise AssertionError("Cancel changed stored preference")
   driver.open_preferences()
   inspect_setting(baseline)
   footer(False)
   result["checks"].append("Cancel discarded the edit in UI and storage")

   journal.perform("edit preference for Save", lambda: driver.write_value(str(saved)))
   footer(True)
   driver.activate_footer("Save")
   footer(False)
   if numeric(driver.read_value()) != saved or stored_value(settings_path) != saved:
      raise AssertionError("Save did not commit the displayed preference")
   driver.activate_footer("Cancel")
   journal.perform("normal exit and restart after Save", restart)
   driver.open_preferences()
   inspect_setting(saved)
   footer(False)
   result["checks"].append("Save persisted to disk and a fresh application process")

   journal.perform("restore baseline preference", lambda: driver.write_value(str(baseline)))
   footer(True)
   driver.activate_footer("Save and close")
   if stored_value(settings_path) != baseline:
      raise AssertionError("Save and close did not restore the baseline")
   journal.perform("normal exit and restart after baseline restoration", restart)
   driver.open_preferences()
   inspect_setting(baseline)
   footer(False)
   driver.activate_footer("Cancel")
   result["checks"].append("Save and close restored the baseline across restart")
   result["passed"] = True
   return result
