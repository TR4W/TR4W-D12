"""The first-run setup wizard (issue 81; docs/SETUP_WIZARD_DESIGN.md section 6,
'CHANGED AGAIN 2026-11-14'; BENCH_QUEUE 'THE SETUP WIZARD').

Four phases, each in its own run folder:

   bench-wizard-offer-no    brand-new install: the Yes/No offer (default Yes)
                            comes BEFORE New Contest. The rule is 'no callsign
                            stored' with no once-only flag, so three starts in
                            one folder -- No; Yes then wizard Cancel; No -- are
                            each asked, and none stores a callsign.
   bench-wizard-station-empty  the literal EMPTY folder (no CTY.DAT, no dom):
                            after Yes NO other question may come before the
                            wizard; the Station page shows its own 'Download
                            country file' button (and the missing-file line,
                            a TLabel, judged from station.png); the call fills
                            nothing, and nothing blocks. Offline: not pressed.
   bench-wizard-cty-download   the same empty folder, and the button IS pressed:
                            Back/Next/Cancel disabled while it runs, then the
                            file lands in the run's own settings directory, the
                            button goes, and the callsign derives. Needs
                            outbound HTTPS from the guest to country-files.com.

(revised 2026-11-14 for the rebuilt startup rule; the station phases also
restart once the callsign is stored and require that the offer is NOT made.)
   bench-wizard-station     brand-new install, Yes: the modal wizard, callsign ->
                            derived zone/ITU/country/continent, nothing ticked,
                            Create configuration, Done, Close -> New Contest
                            carries the callsign; tr4w.json has it. With a
                            country file present the Download button is absent.
   bench-wizard-hardware    brand-new install, Yes, Radio + WinKeyer + DX cluster
                            ticked: the radio and keyer editors are HOSTED as
                            pages of the one wizard window (2026-11-14). Measured:
                            nothing clipped, Back/Next below the editor, the
                            window inside the work area and a 1366x768 screen;
                            each radio tab selectable; Next runs the editor's
                            own validation; Back then Next keeps what was typed.
   bench-wizard-tools       an existing station: Tools > Setup Wizard opens the
                            wizard MODELESS (the main window stays enabled).

(added 2026-11-14, second rebuild)
   bench-wizard-hardware    now also: the two CW choices under the hosted radio
                            editor follow the radio TYPE (K4 both, FT-817 none,
                            FT-991 speed sync only), CW by CAT is disabled while
                            a WinKeyer is ticked, the window stays inside the
                            work area on every type change; the grid box writes
                            EL88pa / EL88 on leaving it; the cluster page splits
                            a pasted host:port and a list pick into Server and
                            Port, refuses 'abc' and '70000'; the Done page names
                            the K4's address and the cluster, and 'Show details'
                            adds indented lines with no password in them; the
                            Default profile carries CWOutput1 'CAT' and
                            speedSync1, the radio itself neither.
   bench-wizard-tools-keyer A LIVE WINKEYER (the guest's COM3): Tools > Setup
                            Wizard, the hosted Radio page in the modeless window,
                            then the WinKeyer page on COM3 and a cluster with a
                            blank port. The Tools run PUTS IT INTO USE, so the
                            port is really opened: tr4w.log is read for it.
                            Opt-in (hardware); never part of the default run.
   bench-wizard-callbook    the callbook (hamdb.org) on a station with no
                            callsign: NY4I fills Name/Grid/State; a name typed
                            first is kept. Opt-in (network).

(added 2026-11-15, after the Radio-page height and cluster-pick fixes)
   every hosted measure    the window (GetWindowRect, judged; DWM visible frame
                            recorded beside it), Back and Next/Create inside the
                            work area, and the work area itself [0,0,1280,752].
   bench-wizard-tools       now goes on to the hosted Radio page in the MODELESS
                            window: no type, K4, FT-817, FT-991 measured, then
                            Cancel (nothing stored).
   bench-wizard-hardware    after the list pick, Port 'abc' and Next: the PORT
                            message must answer (the server is checked first),
                            not 'Enter a cluster server'. Nothing committed.
   bench-wizard-done-network   also ticks the DX cluster, picks the top list
                            entry with the mouse and presses Create
                            configuration at once: no message, the Done page and
                            clusters[] name the picked host:port.

A "brand-new install" run folder holds CTY.DAT and dom only -- what an installed
copy has in its folder -- and NO settings file (prepare_fixture --fresh-install).
The program is started with --settings naming that absent file; tr4w.log must
record "[Startup] brand-new install: offering the setup wizard first", which is
the proof the condition was real rather than assumed.

THE OFFLINE PHASES TOUCH NO HARDWARE AND NO NETWORK. The radio is never put into
use (startup mode saves only, and New Contest is cancelled); the cluster is a
loopback address. Since 2026-11-14 a settled callsign asks hamdb.org for the
name, grid, state and (2026-11-15) postal code -- but only while one of those
four is EMPTY, so the offline phases type all four BEFORE the callsign and no
lookup is made (common_log_checks fails on any '[Callbook]' line there). The
passwords typed are dummies made up here, so that the Done page can be shown to
print 'set' rather than the value; they are not secrets.

(added 2026-11-15, the startup install check)
   every New Contest wait  uProgramMain.WarnIfInstallIncomplete runs after the
                            wizard step and before New Contest, on a start with
                            no contest argument. Its expectation is COMPUTED
                            from the run folder (dom\\, CTY.DAT, TRMASTER.DTA;
                            warn when dom is gone or two or more are), so every
                            case judges it: the full folders must NOT warn, the
                            empty ones must, naming the folder and the parts
                            one per line; tr4w.log has one line per warning.
   bench-wizard-switch      --wizard on a stored station: no question, the
                            Station page shows the stored values; Cancel, then
                            a second start through Create configuration; -h
                            lists --wizard. Nothing is typed back: the page
                            must carry the stored station (issue 322).
   bench-wizard-preserve    issue 322: distinctive settings in seven groups;
                            --wizard, change nothing, Create: the settings
                            section is diffed (only Station keys may change);
                            then a start with no --lang must load normally
                            with the stored language in force.
   bench-wizard-partial     issue 322: settings with a language and a CW speed
                            but no callsign: the offer, Yes, a station, Create;
                            both values must survive.
   bench-install-dom       a stored station, no dom folder: the warning names
                            dom\\ alone; then the Michigan QP log opened, whose
                            dom\\michigan_cty.dom cannot be found: 'could not
                            find this file' plus 'The folder is missing too'
                            (the program then halts, as LogCfg always has on
                            a missing domestic file; the exit code is recorded).

Labels (TLabel) are not windows in the LCL, so the lookup line and the page
summaries cannot be read; they are in the screenshots, and the driver asserts
on their EFFECTS instead (derived boxes filled, Next accepted).
"""

import json
import re
import time
from pathlib import Path

import win32api
import win32con
import win32gui
import win32process
from pywinauto.controls.win32_controls import ComboBoxWrapper
from pywinauto.controls.common_controls import TabControlWrapper

from window_capture import visible_frame
from session import (capture, close_normally, describe_windows, launch, acknowledge_notice,
   dialog_facts, click_dialog_button, select_menu, notice_text)

NEW_CONTEST = r".*Open configuration file or start a new contest"
WIZARD = "TR4W setup"
OFFER_TEXT = "This looks like a new installation. Would you like to run the Setup Wizard first?"
OFFER_LOG = "[Startup] no callsign stored: offering the setup wizard first"
WIZARD_CTY_LOG = "[SetupWizard] country file:"
CTY_DOWNLOAD = "Download country file"
CTY_EXCEPTION = "Exception in ctyFindCallsign"
# A 1366x768 screen less a Windows 11 taskbar at 96 DPI (48 px): the tallest
# window that still shows its bottom row of buttons on such a laptop.
SMALL_SCREEN = (1366, 768 - 48)
# The guest's required screen: 1280x800 at 96 DPI less its 48 px taskbar.
EXPECTED_WORK_AREA = [0, 0, 1280, 752]
RADIO_TABS = ("Serial", "Network", "Advanced")
# The coordinator's stated expectation (2026-11-14): CQ 5, ITU 8, continent NA.
CALL = "NY4I"
# A loopback address nothing listens on: the wizard only SAVES it here, and New
# Contest is cancelled afterwards, so it is never even dialled.
CLUSTER_HOST = "127.0.0.1"
CLUSTER_PORT = "7300"
CLUSTER = CLUSTER_HOST + ":" + CLUSTER_PORT
PORT_BAD = "The port must be a number from 1 to 65535, or blank."
# The station's own values, typed BEFORE the callsign so no callbook lookup is
# started (the wizard asks only while Name, Grid or State is empty).
STATION_NAME = "Wizard"
STATION_STATE = "FL"
# Since 2026-11-15 the Postal code box is the fourth the lookup can fill, so it
# is typed too; deliberately not NY4I's own code, so a callbook write would show.
STATION_POSTAL = "34698"
# THE STARTUP INSTALL CHECK (uProgramMain.WarnIfInstallIncomplete): a MessageDlg
# titled 'TR4W' after the wizard step and before New Contest, when dom is gone
# or two or more of the three parts are. uAppStrings.SInstallIncompleteStartup.
INSTALL_HEAD = "This copy of TR4W looks incompletely installed."
INSTALL_ADVICE = "Start TR4W from the folder the installer put it in"
# Since 2026-11-15 the log line names the whole folder: '... incomplete in
# <folder>; missing: <parts>'. install_log_checks matches the folder exactly.
INSTALL_LOG = "[Startup] the installation looks incomplete in "
INSTALL_LOG_PARTS = "; missing: "
# WarnIfInstallIncomplete.MAX_SHOWN_FOLDER: the dialog's longest folder.
INSTALL_SHOWN_MAX = 60
# What MissingInstallParts names, in its order.
INSTALL_CHECKED = (("dom", "dom\\"), ("CTY.DAT", "CTY.DAT"), ("TRMASTER.DTA", "TRMASTER.DTA"))
WIZARD_SWITCH_LOG = "[Startup] --wizard: running the setup wizard first"
CALLBOOK_LOG = "[Callbook]"
# The K4 is given an address nothing answers at; startup mode never dials it.
K4_ADDRESS = "192.168.1.5"
K4_PORT = "9200"
# Made-up passwords: the Done page must say 'set' and never print these.
DUMMY_RADIO_PASSWORD = "k4-dummy-pw"
DUMMY_CLUSTER_PASSWORD = "cl-dummy-pw"
CW_BY_CAT = "Send CW through the radio (CW by CAT)"
SPEED_SYNC = "Keep the radio's CW speed in step with TR4W"
SHOW_DETAILS = "Show details"
# uAppStrings.SWizCallbookFilled. A TLabel: no window, so not read by the
# driver -- judged from callbook-1.png / callbook-2.png and recorded in facts.
CALLBOOK_NOTE = "Some details were filled in from the callbook (hamdb.org). Please check them."


# ---------------------------------------------------------------- helpers ----

def run_dir(root, run_name):
   return Path(root) / "runs" / run_name


def read_settings(root, run_name):
   path = run_dir(root, run_name) / "tr4w.json"
   if not path.is_file():
      return None
   return json.loads(path.read_text(encoding="utf-8-sig"))


def log_text(root, run_name):
   path = run_dir(root, run_name) / "tr4w.log"
   return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def watch_exit(app):
   """A handle opened while the process lives, so its exit code can be read."""
   return win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.SYNCHRONIZE, False, app.process)


def exit_code(app, handle, journal):
   journal.perform("wait for owned application exit", lambda: app.wait_for_process_exit(timeout=30))
   code = win32process.GetExitCodeProcess(handle)
   handle.Close()
   return code


def visible_titles(app):
   return [window.window_text() for window in app.windows() if window.is_visible()]


def new_contest_visible(app):
   import re
   return any(re.fullmatch(NEW_CONTEST, title) for title in visible_titles(app))


def button(window, caption):
   """The one visible button whose caption (without '&') is CAPTION."""
   matches = [control for control in window.descendants(class_name="Button")
      if control.is_visible() and control.window_text().replace("&", "") == caption]
   if len(matches) != 1:
      raise RuntimeError("Button not unique: " + caption + " -> " + str(len(matches)))
   return matches[0]


def has_button(window, caption):
   return any(control.is_visible() and control.window_text().replace("&", "") == caption
      for control in window.descendants(class_name="Button"))


def enabled(control):
   return bool(win32gui.IsWindowEnabled(control.handle))


def field_by_caption(window, caption):
   """The input on CAPTION's row, to its right -- paired by geometry, never by
   the input's own accessible name."""
   captions = [control for control in window.descendants() if control.is_visible()
      and control.window_text() == caption and control.class_name() not in {"Edit", "Button"}]
   if len(captions) != 1:
      raise RuntimeError("Caption not unique: " + caption)
   label = captions[0].rectangle()
   middle = label.mid_point().y
   inputs = [control for control in window.descendants() if control.is_visible()
      and control.class_name() in {"Edit", "LCLComboBox"}
      and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"
      and control.rectangle().top <= middle <= control.rectangle().bottom
      and control.rectangle().left >= label.left]
   if not inputs:
      raise RuntimeError("No input on the row of " + caption)
   return min(inputs, key=lambda control: control.rectangle().left)


def combo_text(control):
   if control.class_name() == "LCLComboBox":
      wrapper = ComboBoxWrapper(control.handle)
      index = wrapper.selected_index()
      return wrapper.item_texts()[index] if index is not None and index >= 0 else control.window_text()
   return control.window_text()


def new_contest_callsign(window):
   """The New Contest callsign box: the top-most edit right of the search box
   (contest_forms.choose_contest's rule)."""
   edits = [control for control in window.descendants(class_name="Edit") if control.is_visible()]
   find = min(edits, key=lambda control: control.rectangle().left)
   return min([control for control in edits if control.rectangle().left > find.rectangle().left],
      key=lambda control: control.rectangle().top)


def answer_offer(app, answer, output, journal, facts, failures, label="offer"):
   """The startup question: its text, its answers and default, and that New
   Contest is NOT on screen yet. Then press ANSWER."""
   dialog, offer = dialog_facts(app, "TR4W", timeout=45)
   offer["new_contest_visible"] = new_contest_visible(app)
   offer["visible_windows"] = visible_titles(app)
   facts[label] = offer
   capture(dialog, output / (label + ".png"))
   body = " ".join(offer["uia_texts"] + [item["text"] for item in offer["win32_texts"]])
   if OFFER_TEXT not in body:
      # NEVER answer an unclassified question: in an empty folder the first
      # "TR4W" dialog could be the country-file download offer, and Yes there
      # goes to the network (session.answer_question's rule).
      raise AssertionError("First TR4W question is not the setup-wizard offer: " + repr(body))
   if sorted(name.replace("&", "") for name in offer["answers"]) != ["No", "Yes"]:
      failures.append("Offer answers are not exactly Yes/No: " + repr(offer["answers"]))
   # YES is the default since the 2026-11-14 rebuild (Enter starts the setup).
   if (offer.get("default") or "").replace("&", "") != "Yes":
      failures.append("Offer default is not Yes: " + repr(offer.get("default")))
   if offer["new_contest_visible"]:
      failures.append("New Contest is visible while the offer is asked")
   click_dialog_button(app, dialog, answer, journal)


# The run being judged, for the install check every New Contest wait makes.
# Set by run() (one phase per process), like OCCLUDED_PRESSES.
INSTALL_CHECK = {}


def expected_install_missing(root, run_name):
   """What MissingInstallParts would name for the run folder (the working
   folder is the data folder; --settings puts the downloaded tier there too),
   and whether WarnIfInstallIncomplete says it: dom gone, or two or more."""
   folder = run_dir(root, run_name)
   missing = []
   for name, shown in INSTALL_CHECKED:
      present = (folder / name).is_dir() if name == "dom" else (folder / name).is_file()
      if not present:
         missing.append(shown)
   warns = "dom\\" in missing or len(missing) >= 2
   return missing, warns


def install_warning_body(facts):
   """The warning's text with its line breaks: the longest text that holds the
   head (UIA and Win32 each report the label; neither is assumed to keep the
   breaks, which is checked separately)."""
   texts = list(facts["uia_texts"]) + [item["text"] for item in facts["win32_texts"]]
   candidates = [text for text in texts if INSTALL_HEAD in text]
   if not candidates:
      return " ".join(texts)
   return max(candidates, key=len).replace("\r\n", "\n").replace("\r", "\n")


def shown_install_folder(folder):
   """The folder as WarnIfInstallIncomplete shows it (2026-11-15): a path over
   INSTALL_SHOWN_MAX characters becomes '...' plus its last
   INSTALL_SHOWN_MAX - 3 characters; the whole path goes to tr4w.log."""
   if len(folder) > INSTALL_SHOWN_MAX:
      return "..." + folder[-(INSTALL_SHOWN_MAX - 3):]
   return folder


def judge_install_warning(app, dialog, record, journal, failures):
   """Assert the warning's text against the run folder, capture it, press OK."""
   ctx = INSTALL_CHECK
   label = record["label"]
   body = record["body"]
   expected = record["expected_missing"]
   folder = str(run_dir(ctx["root"], ctx["run_name"])) + "\\"
   if not record["expected_warning"]:
      failures.append(label + ": the install warning appeared although only " + repr(expected)
         + " is missing: " + repr(body))
   if not body.startswith(INSTALL_HEAD):
      failures.append(label + ": the warning does not start with " + repr(INSTALL_HEAD) + ": " + repr(body))
   lines = body.split("\n")
   heading = "Not found in " + shown_install_folder(folder) + ":"
   where = [index for index, line in enumerate(lines) if line.strip().casefold() == heading.casefold()]
   record["names_listed"] = None
   if len(where) != 1:
      failures.append(label + ": no single line " + repr(heading) + " in " + repr(body))
   else:
      names = []
      for line in lines[where[0] + 1:]:
         if not line.strip():
            break
         names.append(line.strip())
      record["names_listed"] = names
      if record["expected_warning"] and names != expected:
         failures.append(label + ": the warning lists " + repr(names) + " one per line, expected " + repr(expected))
   if INSTALL_ADVICE not in body:
      failures.append(label + ": the warning lacks " + repr(INSTALL_ADVICE))
   if sorted(name.replace("&", "") for name in record["answers"]) != ["OK"]:
      failures.append(label + ": the warning's answers are " + repr(record["answers"]) + ", expected OK only")
   if record["new_contest_visible"]:
      failures.append(label + ": New Contest is on screen while the install warning is up")
   capture(dialog, ctx["output"] / (label + "-install-warning.png"))
   click_dialog_button(app, dialog, "OK", journal)


def settle_install_check(app, journal, label):
   """Between the wizard step and New Contest: the install warning when the
   folder calls for it, and NOTHING when it does not. Any other 'TR4W' dialog
   here is unclassified and stops the case (never answered blindly)."""
   ctx = INSTALL_CHECK
   failures = ctx["failures"]
   expected, warns = expected_install_missing(ctx["root"], ctx["run_name"])
   record = {"label": label, "expected_missing": expected, "expected_warning": warns, "warning_seen": False}
   ctx["records"].append(record)
   deadline = time.monotonic() + 45
   while time.monotonic() < deadline:
      if new_contest_visible(app):
         break
      # A message box (#32770): the main window may already exist, titled 'TR4W'.
      if app.window(title="TR4W", class_name="#32770", visible_only=True).exists(timeout=0):
         dialog, facts = dialog_facts(app, "TR4W", timeout=5, class_name="#32770")
         body = install_warning_body(facts)
         if INSTALL_HEAD not in body:
            capture(dialog, ctx["output"] / (label + "-unexpected-dialog.png"))
            raise AssertionError(label + ": an unclassified TR4W dialog before New Contest: " + repr(body))
         if record["warning_seen"]:
            failures.append(label + ": the install warning was shown twice in one start")
         record.update({"warning_seen": True, "body": body, "answers": facts["answers"],
            "new_contest_visible": new_contest_visible(app)})
         judge_install_warning(app, dialog, record, journal, failures)
         continue
      time.sleep(0.2)
   if warns and not record["warning_seen"]:
      failures.append(label + ": no install warning, although " + repr(expected) + " is missing")


def wait_new_contest(app, journal, label="start", title_re=NEW_CONTEST):
   window = app.window(title_re=title_re)
   if INSTALL_CHECK:
      label = label + "-" + str(len(INSTALL_CHECK["records"]) + 1)
      journal.perform("startup install check before New Contest (" + label + ")",
         lambda: settle_install_check(app, journal, label))
   journal.perform("wait for New Contest", lambda: window.wait("visible enabled", timeout=45))
   return window


def stray_questions(app):
   """Visible message boxes / question dialogs of this process: a window titled
   exactly 'TR4W' (QuestionDlg, MessageDlg) or of the #32770 class."""
   return [window for window in app.windows() if window.is_visible()
      and (window.window_text() == "TR4W" or window.class_name() == "#32770")]


def wait_wizard(app, journal, output=None, facts=None):
   """The wizard, and NOTHING before it: since 2026-11-14 the country file is
   offered on the Station page, so any question between the offer's Yes and
   the wizard (the old EnsureCountryFile prompt) is a failure."""
   def appear():
      deadline = time.monotonic() + 45
      while time.monotonic() < deadline:
         if app.window(title=WIZARD, visible_only=True).exists(timeout=0):
            return
         strays = stray_questions(app)
         if strays:
            texts = []
            for window in strays:
               texts += [control.window_text() for control in window.descendants() if control.window_text()]
            if facts is not None:
               facts["prompt_before_wizard"] = {"titles": [window.window_text() for window in strays],
                  "texts": texts}
            if output is not None:
               capture(strays[0], output / "prompt-before-wizard.png")
            raise AssertionError("A question appeared before the wizard: " + repr(texts))
         time.sleep(0.2)
      raise TimeoutError("The setup wizard did not appear")
   journal.perform("wait for the setup wizard (no question first)", appear)
   wizard = app.window(title=WIZARD, visible_only=True)
   wizard.wait("visible enabled", timeout=15)
   return app.window(handle=wizard.handle)


def check_cty_line(wizard, facts, failures, expect_download):
   """The Station page's country-file state. The status line is a TLabel (no
   window: see station.png); the Download button is a real button."""
   facts["cty_download_button"] = has_button(wizard, CTY_DOWNLOAD)
   facts["cty_download_enabled"] = facts["cty_download_button"] and enabled(button(wizard, CTY_DOWNLOAD))
   if expect_download and not facts["cty_download_enabled"]:
      failures.append("No country file, yet the Station page has no enabled '" + CTY_DOWNLOAD + "' button")
   if not expect_download and facts["cty_download_button"]:
      failures.append("A country file is loaded, yet the Station page shows '" + CTY_DOWNLOAD + "'")


def wizard_cty_log(root, run_name, facts):
   facts["wizard_cty_log"] = [line for line in log_text(root, run_name).splitlines() if WIZARD_CTY_LOG in line]


def fresh_start(root, run_name, journal):
   app = journal.perform("launch as a brand-new install (no settings file)",
      lambda: launch(root, run_name, "", fresh_install=True))
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   return app


def start_again(root, run_name, journal, label):
   """Restart in the SAME folder, with whatever the last run left there: a
   settings file may or may not exist (the rule is 'no callsign stored')."""
   exists = (run_dir(root, run_name) / "tr4w.json").is_file()
   app = journal.perform(label, lambda: launch(root, run_name, "", fresh_install=not exists))
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   return app


def set_box(box, text, journal, label):
   """Real keystrokes into a box: click it, select all, type (or delete)."""
   journal.perform("click " + label, box.click_input)
   keys = "^a" + text if text else "^a{DELETE}"
   journal.perform("type " + repr(text) + " into " + label, lambda: box.type_keys(keys, with_spaces=True))


def tab_out(box, journal, label):
   journal.perform("Tab out of " + label, lambda: box.type_keys("{TAB}"))
   time.sleep(0.3)


GRID_CASES = (("el88", "EL88"), ("EL88PA", "EL88pa"))
SAVED_GRID = GRID_CASES[-1][1]


def grid_case(wizard, journal, facts, failures):
   """THE LOCATOR'S STANDARD CASE, written when the operator LEAVES the box
   (GridExit): el88 -> EL88, EL88PA -> EL88pa. The last one stays."""
   grid = field_by_caption(wizard, "Grid square:")
   facts["grid_after_tab"] = {}
   for typed, expected in GRID_CASES:
      set_box(grid, typed, journal, "Grid square")
      before = grid.window_text()
      tab_out(grid, journal, "Grid square")
      after = grid.window_text()
      facts["grid_after_tab"][typed] = {"before_tab": before, "after_tab": after}
      if after != expected:
         failures.append("Grid typed " + repr(typed) + " reads " + repr(after) + " after Tab, expected "
            + repr(expected))


def station_page(wizard, output, journal, facts, failures, expect_derived=True, prefill=True):
   """Type the callsign with real keystrokes and wait out the debounce.
   expect_derived False: no country file is reachable, so the four derived
   boxes must stay EMPTY ('unknown call' changes nothing, design section 4).
   prefill: Name, State, Postal code and Grid (the grid case) FIRST, so the
   callbook is not asked -- it is asked only while one of the four is empty."""
   if prefill:
      set_box(field_by_caption(wizard, "First name:"), STATION_NAME, journal, "First name")
      set_box(field_by_caption(wizard, "State/Province:"), STATION_STATE, journal, "State/Province")
      set_box(field_by_caption(wizard, "Postal code:"), STATION_POSTAL, journal, "Postal code")
      grid_case(wizard, journal, facts, failures)
   call_box = field_by_caption(wizard, "Callsign:")
   facts["callsign_before"] = call_box.window_text()
   # What the four boxes show BEFORE the callsign: on a new install the store's
   # defaults (observed: ITU zone '0', continent 'NONE'), not blanks.
   facts["derived_before"] = {caption: combo_text(field_by_caption(wizard, caption))
      for caption in ("CQ zone:", "ITU zone:", "Country:", "Continent:")}
   journal.perform("click the wizard Callsign box", call_box.click_input)
   journal.perform("type " + CALL, lambda: call_box.type_keys("^a" + CALL))
   facts["station_prefilled"] = prefill
   derived = {}
   deadline = time.monotonic() + 4
   while time.monotonic() < deadline:
      derived = {caption: combo_text(field_by_caption(wizard, caption))
         for caption in ("CQ zone:", "ITU zone:", "Country:", "Continent:")}
      if all(derived.values()):
         break
      time.sleep(0.2)
   facts["callsign_typed"] = call_box.window_text()
   facts["derived"] = derived
   journal.perform("capture Station page", lambda: capture(wizard, output / "station.png"))
   if facts["callsign_typed"] != CALL:
      failures.append("Callsign box reads " + repr(facts["callsign_typed"]) + " after typing " + CALL)
   if not expect_derived:
      # A lookup that finds nothing CHANGES nothing (design section 4).
      if derived != facts["derived_before"]:
         failures.append("No country file, yet the derived fields changed: " + repr(facts["derived_before"])
            + " -> " + repr(derived))
   elif not all(derived.values()):
      failures.append("Derived fields not filled from " + CALL + " (lookup 'unknown call'? see station.png): "
         + repr(derived))
   else:
      if derived["CQ zone:"] != "5" or derived["ITU zone:"] != "8" or derived["Continent:"] != "NA":
         failures.append(CALL + " should derive CQ 5, ITU 8, NA: " + repr(derived))


# Buttons found off the usable screen. The layout assertion (measure_hosted)
# records that as the failure; the press itself then goes by window message, so
# the rest of the case still gets a verdict instead of clicking the taskbar.
OCCLUDED_PRESSES = []


def press(wizard, caption, journal, label=None):
   control = button(wizard, caption)
   box = control.rectangle()
   work = win32api.GetMonitorInfo(win32api.MonitorFromWindow(wizard.handle))["Work"]
   on_screen = box.top >= work[1] and box.bottom <= work[3] and box.left >= work[0] and box.right <= work[2]
   action = label or ("press " + caption)
   if on_screen:
      journal.perform(action, control.click_input)
   else:
      OCCLUDED_PRESSES.append({"caption": caption, "button": [box.left, box.top, box.right, box.bottom],
         "work_area": list(work)})
      journal.perform(action + " (by message: the button is outside the work area)", control.click)


def next_page(wizard, caption, journal):
   control = button(wizard, caption)
   if not enabled(control):
      raise AssertionError(caption + " is disabled")
   press(wizard, caption, journal)
   time.sleep(0.4)


def result_memo(wizard):
   memos = [control for control in wizard.descendants(class_name="Edit") if control.is_visible()]
   if len(memos) != 1:
      raise AssertionError("Result page should show one memo, found " + str(len(memos)))
   return memos[0]


def memo_fit(memo):
   """Whether every line of the memo is on view: the wrapped line count
   (EM_GETLINECOUNT) against the lines its client area holds."""
   import win32con as wc
   count = win32gui.SendMessage(memo.handle, wc.EM_GETLINECOUNT, 0, 0)
   left, top, right, bottom = win32gui.GetClientRect(memo.handle)
   # A line's height from the first characters of lines 0 and 1.
   first = win32gui.SendMessage(memo.handle, wc.EM_LINEINDEX, 0, 0)
   second = win32gui.SendMessage(memo.handle, wc.EM_LINEINDEX, 1, 0)
   height = None
   if count > 1 and second >= 0:
      y0 = win32gui.SendMessage(memo.handle, wc.EM_POSFROMCHAR, first, 0) >> 16 & 0xFFFF
      y1 = win32gui.SendMessage(memo.handle, wc.EM_POSFROMCHAR, second, 0) >> 16 & 0xFFFF
      height = y1 - y0 if y1 > y0 else None
   style = win32gui.GetWindowLong(memo.handle, wc.GWL_STYLE)
   holds = (bottom - top) // height if height else None
   return {"wrapped_lines": count, "line_height": height, "client": [left, top, right, bottom],
      "lines_on_view": holds, "all_on_view": holds is None or count <= holds,
      "vertical_scrollbar": bool(style & wc.WS_VSCROLL), "horizontal_scrollbar": bool(style & wc.WS_HSCROLL)}


def finish_result_page(app, wizard, output, journal, facts, failures, inspect=None, call=CALL):
   """The result page: what it says, Back/Next gone, Cancel now Close.
   inspect(memo) runs before Close, for the phases that judge the report."""
   memo = result_memo(wizard)
   facts["result_text"] = memo.window_text()
   facts["result_buttons"] = [control.window_text() for control in wizard.descendants(class_name="Button")
      if control.is_visible()]
   journal.perform("capture Done page", lambda: capture(wizard, output / "done.png"))
   if "Station " + call + " saved." not in facts["result_text"]:
      failures.append("Done page does not report the station: " + repr(facts["result_text"]))
   if has_button(wizard, "Next >") or has_button(wizard, "< Back") or has_button(wizard, "Create configuration"):
      failures.append("Back/Next still visible on the Done page: " + repr(facts["result_buttons"]))
   if inspect is not None:
      inspect(memo)
   journal.perform("press Close", button(wizard, "Close").click_input)
   journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=15))


def show_details(wizard, output, journal, facts, failures, secrets, expected_details):
   """'Show details': the brief report, then the same plus indented detail
   lines, and back. Never a password -- only 'set'. Nothing clipped."""
   memo = result_memo(wizard)
   brief = memo.window_text()
   if not has_button(wizard, SHOW_DETAILS):
      failures.append("Done page has no '" + SHOW_DETAILS + "' box although there are details to show")
      return
   box = button(wizard, SHOW_DETAILS)
   facts["details_box_checked_at_start"] = bool(box.get_check_state())
   journal.perform("tick " + SHOW_DETAILS, box.click_input)
   time.sleep(0.4)
   detailed = result_memo(wizard).window_text()
   facts["result_text_details"] = detailed
   facts["result_fit_details"] = memo_fit(result_memo(wizard))
   journal.perform("capture Done page with details", lambda: capture(wizard, output / "done-details.png"))
   added = [line for line in detailed.splitlines() if line not in brief.splitlines()]
   facts["detail_lines"] = added
   if not detailed.startswith(brief.rstrip()):
      failures.append("The detailed report does not begin with the brief one")
   if not added:
      failures.append("Ticking '" + SHOW_DETAILS + "' added no lines")
   for line in added:
      if line.strip() and not line.startswith("   "):
         failures.append("Detail line not indented: " + repr(line))
   for expected in expected_details:
      if not any(expected in line for line in added):
         failures.append("Detail lines lack " + repr(expected) + ": " + repr(added))
   for secret in secrets:
      if secret in detailed or secret in brief:
         failures.append("A password typed into the wizard is printed on the Done page")
   if not facts["result_fit_details"]["all_on_view"] and not facts["result_fit_details"]["vertical_scrollbar"]:
      failures.append("Detail report has " + str(facts["result_fit_details"]["wrapped_lines"])
         + " lines, the memo shows " + str(facts["result_fit_details"]["lines_on_view"]) + " and has no scroll bar")
   # The box itself: inside its page and above Close.
   page = client_rect_on_screen(win32gui.GetParent(box.handle))
   area = box.rectangle()
   close_top = button(wizard, "Close").rectangle().top
   memo_bottom = result_memo(wizard).rectangle().bottom
   facts["details_box_layout"] = {"box": [area.left, area.top, area.right, area.bottom], "page": page,
      "close_top": close_top, "memo_bottom": memo_bottom}
   if area.bottom > page[3] or area.right > page[2] or area.bottom > close_top:
      failures.append("'" + SHOW_DETAILS + "' box is clipped or below Close: " + repr(facts["details_box_layout"]))
   if memo_bottom > area.top:
      failures.append("The report memo overlaps the '" + SHOW_DETAILS + "' box")
   journal.perform("untick " + SHOW_DETAILS, button(wizard, SHOW_DETAILS).click_input)
   time.sleep(0.4)
   facts["result_text_after_untick"] = result_memo(wizard).window_text()
   if facts["result_text_after_untick"] != brief:
      failures.append("Unticking '" + SHOW_DETAILS + "' did not return to the brief report")


def after_wizard(app, root, run_name, output, journal, facts, failures, expect_call):
   """New Contest after the wizard: the callsign it offers, the settings as
   written BEFORE it read them, then Cancel and a clean exit."""
   startup = wait_new_contest(app, journal)
   facts["new_contest_callsign"] = new_contest_callsign(startup).window_text()
   facts["settings_while_new_contest_open"] = read_settings(root, run_name)
   journal.perform("capture New Contest", lambda: capture(startup, output / "new-contest.png"))
   if facts["new_contest_callsign"] != expect_call:
      failures.append("New Contest callsign is " + repr(facts["new_contest_callsign"]) + ", expected "
         + repr(expect_call))
   handle = watch_exit(app)
   journal.perform("cancel New Contest", lambda: startup.child_window(title="Cancel", class_name="Button").click_input())
   facts["exit_code"] = exit_code(app, handle, journal)
   if facts["exit_code"] != 0:
      failures.append("Exit code after cancelling New Contest: " + str(facts["exit_code"]))
   return facts["settings_while_new_contest_open"]


def check_station_settings(settings, failures, grid_prompt_expected, grid=SAVED_GRID, postal=STATION_POSTAL):
   if settings is None:
      failures.append("No settings file after the wizard")
      return
   my = settings.get("settings", {}).get("My", {})
   my_call = my.get("Call")
   general = settings.get("general", {})
   if my_call != CALL:
      failures.append("settings.My.Call is " + repr(my_call))
   # MY POSTAL CODE, as typed (or as the callbook filled it).
   if postal is not None and my.get("PostalCode") != postal:
      failures.append("settings.My.PostalCode is " + repr(my.get("PostalCode")) + ", expected " + repr(postal))
   # The grid as the wizard showed it after Tab, case and all.
   if grid is not None and my.get("Grid") != grid:
      failures.append("settings.My.Grid is " + repr(my.get("Grid")) + ", expected " + repr(grid))
   if general.get("gridPromptShown") is not grid_prompt_expected:
      failures.append("general.gridPromptShown is " + repr(general.get("gridPromptShown"))
         + ", expected " + repr(grid_prompt_expected))


def stored_callsign(settings):
   """The callsign the offer rule looks at (My.MainCallsign / My.Call)."""
   if settings is None:
      return ""
   my = settings.get("settings", {}).get("My", {})
   return my.get("MainCallsign") or my.get("Call") or ""


def check_no_callsign_stored(root, run_name, facts, failures, label):
   settings = read_settings(root, run_name)
   facts[label] = {"settings_file": settings is not None, "callsign": stored_callsign(settings)}
   if stored_callsign(settings):
      failures.append(label + ": a callsign is stored although none was given: "
         + repr(stored_callsign(settings)))


def install_log_checks(text, facts, failures):
   """One '[Startup] the installation looks incomplete' line per warning seen,
   each naming exactly what that warning listed."""
   folder = str(run_dir(INSTALL_CHECK["root"], INSTALL_CHECK["run_name"])) + "\\" if INSTALL_CHECK else None
   lines = []
   for line in text.splitlines():
      if INSTALL_LOG not in line:
         continue
      rest = line[line.index(INSTALL_LOG) + len(INSTALL_LOG):].strip()
      named, _, parts = rest.partition(INSTALL_LOG_PARTS)
      if folder is not None and named.casefold() != folder.casefold():
         failures.append("Install log line names folder " + repr(named) + ", expected " + repr(folder))
      lines.append(parts)
   seen = [record for record in INSTALL_CHECK.get("records", []) if record["warning_seen"]]
   facts["install_log_lines"] = lines
   if len(lines) != len(seen):
      failures.append("tr4w.log has " + str(len(lines)) + " install-incomplete line(s) for " + str(len(seen))
         + " warning(s) seen")
      return
   for line, record in zip(lines, seen):
      if line != ", ".join(record["expected_missing"]):
         failures.append("Install log line names " + repr(line) + ", expected " + repr(", ".join(record["expected_missing"])))


def callbook_log_checks(text, facts, failures):
   """An offline phase types all four lookup boxes first, so no lookup is made.
   Weak by nature: a SUCCESSFUL lookup is logged at Debug only, which a fresh
   install's log level may not write; a failure or a 'no record' is."""
   facts["callbook_log_lines"] = [line for line in text.splitlines() if CALLBOOK_LOG in line]
   if facts["callbook_log_lines"]:
      failures.append("An offline phase asked the callbook: " + repr(facts["callbook_log_lines"][-1]))


def common_log_checks(root, run_name, facts, failures, offers_expected, offline=True):
   text = log_text(root, run_name)
   install_log_checks(text, facts, failures)
   if offline:
      callbook_log_checks(text, facts, failures)
   facts["offer_log_lines"] = text.count(OFFER_LOG)
   facts["crash_marker"] = "[CRASH]" in text
   facts["cty_exception"] = CTY_EXCEPTION in text
   if facts["cty_exception"]:
      failures.append("tr4w.log has '" + CTY_EXCEPTION + "'")
   if facts["offer_log_lines"] != offers_expected:
      failures.append("Offer logged " + str(facts["offer_log_lines"]) + " time(s), expected "
         + str(offers_expected))
   if facts["crash_marker"]:
      failures.append("tr4w.log has a [CRASH] marker")


# ----------------------------------------------------------------- phases ----

def cancel_new_contest(app, startup, output, journal, facts, failures, label):
   """New Contest with no callsign given anywhere: empty box, Cancel, exit 0."""
   facts[label + "_callsign"] = new_contest_callsign(startup).window_text()
   journal.perform("capture New Contest " + label, lambda: capture(startup, output / (label + "-new-contest.png")))
   if facts[label + "_callsign"] != "":
      failures.append(label + ": New Contest callsign is not empty: " + repr(facts[label + "_callsign"]))
   handle = watch_exit(app)
   journal.perform("cancel New Contest " + label,
      lambda: startup.child_window(title="Cancel", class_name="Button").click_input())
   facts[label + "_exit_code"] = exit_code(app, handle, journal)
   if facts[label + "_exit_code"] != 0:
      failures.append(label + ": exit code after cancelling New Contest: " + str(facts[label + "_exit_code"]))


def offer_no(root, run_name, output, journal, facts, failures, incomplete, owned):
   """The offer REPEATS until a callsign is stored, and nothing is written
   before the operator answers. Three starts in one folder: No; Yes then the
   wizard's Cancel; No again -- each must be asked, none may store a call."""
   # 1. No.
   app = fresh_start(root, run_name, journal)
   owned.append(app)
   answer_offer(app, "No", output, journal, facts, failures, "offer")
   cancel_new_contest(app, wait_new_contest(app, journal), output, journal, facts, failures, "after-no")
   check_no_callsign_stored(root, run_name, facts, failures, "stored_after_no")
   common_log_checks(root, run_name, facts, failures, 1)

   # 2. Asked again; Yes, then Cancel in the wizard.
   app = start_again(root, run_name, journal, "second start in the same folder")
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures, "offer-2")
   wizard = wait_wizard(app, journal, output, facts)
   journal.perform("capture wizard before Cancel", lambda: capture(wizard, output / "wizard-before-cancel.png"))
   journal.perform("press the wizard's Cancel", button(wizard, "Cancel").click_input)
   journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=15))
   cancel_new_contest(app, wait_new_contest(app, journal), output, journal, facts, failures, "after-wizard-cancel")
   check_no_callsign_stored(root, run_name, facts, failures, "stored_after_wizard_cancel")
   common_log_checks(root, run_name, facts, failures, 2)

   # 3. Still no callsign, so asked a third time.
   app = start_again(root, run_name, journal, "third start in the same folder")
   owned.append(app)
   answer_offer(app, "No", output, journal, facts, failures, "offer-3")
   cancel_new_contest(app, wait_new_contest(app, journal), output, journal, facts, failures, "third")
   check_no_callsign_stored(root, run_name, facts, failures, "stored_after_third")
   common_log_checks(root, run_name, facts, failures, 3)


def restart_without_offer(root, run_name, output, journal, facts, failures, owned, offers_so_far):
   """A callsign is stored now: the next start must NOT ask, and New Contest
   comes straight up carrying it."""
   app = start_again(root, run_name, journal, "restart once a callsign is stored")
   owned.append(app)
   startup = wait_new_contest(app, journal)
   time.sleep(1.5)
   facts["restart_visible_windows"] = visible_titles(app)
   facts["restart_asked_again"] = app.window(title="TR4W", visible_only=True).exists(timeout=0)
   facts["restart_new_contest_callsign"] = new_contest_callsign(startup).window_text()
   journal.perform("capture New Contest on restart", lambda: capture(startup, output / "restart-new-contest.png"))
   if facts["restart_asked_again"]:
      failures.append("The restart asked the setup-wizard question although a callsign is stored")
   if facts["restart_new_contest_callsign"] != CALL:
      failures.append("Restart New Contest callsign is " + repr(facts["restart_new_contest_callsign"]))
   handle = watch_exit(app)
   journal.perform("cancel New Contest after restart",
      lambda: startup.child_window(title="Cancel", class_name="Button").click_input())
   facts["restart_exit_code"] = exit_code(app, handle, journal)
   if facts["restart_exit_code"] != 0:
      failures.append("Exit code after the restart: " + str(facts["restart_exit_code"]))
   common_log_checks(root, run_name, facts, failures, offers_so_far)


def station_only(root, run_name, output, journal, facts, failures, incomplete, owned, expect_derived=True):
   app = fresh_start(root, run_name, journal)
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures)
   wizard = wait_wizard(app, journal, output, facts)
   wizard_cty_log(root, run_name, facts)
   facts["new_contest_visible_with_wizard"] = new_contest_visible(app)
   if facts["new_contest_visible_with_wizard"]:
      failures.append("New Contest is visible while the startup wizard is up")
   # No country file <=> the page offers the download (the negative control
   # is the ordinary install, which has CTY.DAT).
   check_cty_line(wizard, facts, failures, expect_download=not expect_derived)
   station_page(wizard, output, journal, facts, failures, expect_derived)
   next_page(wizard, "Next >", journal)
   # Next must be accepted with no message box: an unknown call blocks nothing.
   facts["notice_after_station_next"] = app.window(class_name="#32770", visible_only=True).exists(timeout=1)
   if facts["notice_after_station_next"]:
      raise AssertionError("A message box appeared on Next from the Station page")
   if not has_button(wizard, "A radio (rig control)"):
      raise AssertionError("Next from the Station page did not reach the checklist")
   facts["checklist_boxes"] = {caption: button(wizard, caption).get_check_state()
      for caption in ("A radio (rig control)", "A WinKeyer", "A DX cluster")}
   if any(facts["checklist_boxes"].values()):
      failures.append("A checklist box starts ticked: " + repr(facts["checklist_boxes"]))
   journal.perform("capture checklist", lambda: capture(wizard, output / "checklist.png"))
   if not has_button(wizard, "Create configuration"):
      failures.append("With nothing ticked the checklist's Next does not read Create configuration")
   next_page(wizard, "Create configuration", journal)
   finish_result_page(app, wizard, output, journal, facts, failures)
   settings = after_wizard(app, root, run_name, output, journal, facts, failures, CALL)
   check_station_settings(settings, failures, True)
   common_log_checks(root, run_name, facts, failures, 1)
   restart_without_offer(root, run_name, output, journal, facts, failures, owned, 1)


def combos_by_top(window):
   return sorted([control for control in window.descendants(class_name="LCLComboBox") if control.is_visible()],
      key=lambda control: control.rectangle().top)


def edits_by_top(window):
   """Visible edit boxes that are not the edit inside a combo box, top first."""
   return sorted([control for control in window.descendants(class_name="Edit") if control.is_visible()
      and win32gui.GetClassName(win32gui.GetParent(control.handle)) != "LCLComboBox"],
      key=lambda control: control.rectangle().top)


def hosted_name_box(wizard, page):
   """The hosted editor's Name box: the top-most visible edit on the page."""
   edits = edits_by_top(wizard)
   if not edits:
      raise AssertionError("The " + page + " page shows no editor (no visible edit box)")
   return edits[0]


def rect(hwnd):
   left, top, right, bottom = win32gui.GetWindowRect(hwnd)
   return [left, top, right, bottom]


def client_rect_on_screen(hwnd):
   left, top, right, bottom = win32gui.GetClientRect(hwnd)
   x1, y1 = win32gui.ClientToScreen(hwnd, (left, top))
   x2, y2 = win32gui.ClientToScreen(hwnd, (right, bottom))
   return [x1, y1, x2, y2]


def visible_children(hwnd):
   found = []

   def collect(child, _):
      if win32gui.IsWindowVisible(child):
         found.append(child)
      return True

   win32gui.EnumChildWindows(hwnd, collect, None)
   return found


def one_window(app, wizard, label, facts, failures):
   """The hosted page is a page of THE wizard: one 'TR4W setup' window, no
   separate editor window, and the editor's own Save/Cancel not hosted."""
   titles = visible_titles(app)
   state = {"visible_titles": titles,
      "foreground_is_wizard": win32gui.GetForegroundWindow() == wizard.handle,
      "save_and_close_hosted": has_button(wizard, "Save and close")}
   facts[label + "_windows"] = state
   if titles.count(WIZARD) != 1:
      failures.append(label + ": expected exactly one '" + WIZARD + "' window, saw " + repr(titles))
   for stray in ("Radio", "CW keying device"):
      if stray in titles:
         failures.append(label + ": a separate '" + stray + "' editor window is visible")
   if state["save_and_close_hosted"]:
      failures.append(label + ": the editor's own 'Save and close' button is shown inside the wizard")
   if not state["foreground_is_wizard"]:
      failures.append(label + ": the wizard is not the foreground window")


def measure_hosted(wizard, name_box, label, facts, failures):
   """Clipping by rectangles, not by eye. The hosted panel is the Name box's
   parent; its parent is the wizard's tab sheet. Every visible control in the
   panel must lie inside the sheet's client area, the sheet above Back/Next,
   and the window inside the work area and a 1366x768 laptop's."""
   panel = win32gui.GetParent(name_box.handle)
   sheet = win32gui.GetParent(panel)
   sheet_client = client_rect_on_screen(sheet)
   lowest, lowest_name, rightmost = None, "", None
   for child in visible_children(panel):
      bottom = rect(child)[3]
      right = rect(child)[2]
      if lowest is None or bottom > lowest:
         lowest = bottom
         lowest_name = win32gui.GetClassName(child) + " '" + win32gui.GetWindowText(child) + "'"
      if rightmost is None or right > rightmost:
         rightmost = right
   back = button(wizard, "< Back").rectangle()
   following_caption = "Next >" if has_button(wizard, "Next >") else "Create configuration"
   following = button(wizard, following_caption).rectangle()
   window = rect(wizard.handle)
   work = list(win32api.GetMonitorInfo(win32api.MonitorFromWindow(wizard.handle))["Work"])
   layout = {"panel": rect(panel), "sheet_client": sheet_client, "lowest_control_bottom": lowest,
      "lowest_control": lowest_name, "rightmost_control_right": rightmost,
      "back_button": [back.left, back.top, back.right, back.bottom],
      "next_button_top": following.top, "next_button_caption": following_caption,
      "next_button": [following.left, following.top, following.right, following.bottom], "window": window,
      "window_visible_frame": list(visible_frame(wizard.handle)),
      "window_size": [window[2] - window[0], window[3] - window[1]], "work_area": work}
   facts.setdefault("layout", {})[label] = layout
   if layout["panel"][3] > sheet_client[3] or layout["panel"][2] > sheet_client[2]:
      failures.append(label + ": the hosted editor panel " + repr(layout["panel"])
         + " extends past its page " + repr(sheet_client) + " (clipped)")
   if lowest is not None and lowest > sheet_client[3]:
      failures.append(label + ": control " + lowest_name + " ends at y=" + str(lowest)
         + ", below the page bottom y=" + str(sheet_client[3]) + " (clipped)")
   if rightmost is not None and rightmost > sheet_client[2]:
      failures.append(label + ": a control ends at x=" + str(rightmost) + ", past the page right edge x="
         + str(sheet_client[2]) + " (clipped)")
   if sheet_client[3] > back.top or (lowest is not None and lowest > back.top):
      failures.append(label + ": the editor reaches below the top of Back (y=" + str(back.top) + ")")
   # The judged rectangle is GetWindowRect (title bar, frame AND the invisible
   # resize margin): the stricter of the two. The DWM visible frame is recorded
   # beside it, so a verdict that hangs on those few pixels is visible.
   if window[1] < work[1] or window[3] > work[3] or window[0] < work[0] or window[2] > work[2]:
      failures.append(label + ": the wizard " + repr(window) + " is not inside the work area " + repr(work))
   for caption, box in (("< Back", back), (following_caption, following)):
      if box.top < work[1] or box.bottom > work[3] or box.left < work[0] or box.right > work[2]:
         failures.append(label + ": '" + caption + "' " + repr([box.left, box.top, box.right, box.bottom])
            + " is not fully inside the work area " + repr(work))
   # The verdict is stated for a 1280x800 screen at 96 DPI (work area bottom
   # 752); any other work area means the guest is not in its required state.
   if work != EXPECTED_WORK_AREA:
      failures.append(label + ": the work area is " + repr(work) + ", not " + repr(EXPECTED_WORK_AREA)
         + " -- the guest is not at 1280x800, 96 DPI, so this layout verdict is not the one asked for")
   if layout["window_size"][0] > SMALL_SCREEN[0] or layout["window_size"][1] > SMALL_SCREEN[1]:
      failures.append(label + ": the wizard is " + repr(layout["window_size"])
         + ", larger than a 1366x768 screen's work area " + repr(list(SMALL_SCREEN)))
   return layout


def press_next_expect_refusal(app, wizard, parts, shot, journal, facts, failures, label):
   """Next on a hosted page whose editor must refuse: its own message, and the
   wizard stays on the page."""
   press(wizard, "Next >", journal, "press Next > (" + label + ")")
   try:
      facts[label] = acknowledge_notice(app, parts, journal, shot)
   except Exception as error:
      failures.append(label + ": expected the editor's refusal " + repr(parts) + ", got " + repr(error))
      return
   time.sleep(0.3)


def tick(wizard, caption, journal, want):
   box = button(wizard, caption)
   if bool(box.get_check_state()) != want:
      journal.perform(("tick " if want else "untick ") + caption, box.click_input)


def find_transport(wizard):
   """The hosted radio editor's Serial/Network/Advanced tab control."""
   for control in wizard.descendants(class_name="SysTabControl32"):
      if control.is_visible():
         wrapper = TabControlWrapper(control.handle)
         if "Serial" in [wrapper.get_tab_text(index) for index in range(wrapper.tab_count())]:
            return wrapper
   return None


def cw_choice_state(wizard):
   """The two CW boxes under the hosted radio editor: shown, enabled, ticked."""
   state = {}
   for caption in (CW_BY_CAT, SPEED_SYNC):
      shown = [control for control in wizard.descendants(class_name="Button")
         if control.window_text().replace("&", "") == caption and control.is_visible()]
      state[caption] = {"visible": bool(shown), "enabled": bool(shown) and enabled(shown[0]),
         "checked": bool(shown) and bool(shown[0].get_check_state())}
   return state


def cw_layout(wizard, label, facts, failures):
   """A shown CW box lies inside its page, below the hosted editor's panel and
   above Back -- the window grew to make room for the row."""
   back = button(wizard, "< Back").rectangle()
   boxes = {}
   for caption in (CW_BY_CAT, SPEED_SYNC):
      shown = [control for control in wizard.descendants(class_name="Button")
         if control.window_text().replace("&", "") == caption and control.is_visible()]
      if not shown:
         continue
      area = shown[0].rectangle()
      page = client_rect_on_screen(win32gui.GetParent(shown[0].handle))
      panel = rect(win32gui.GetParent(hosted_name_box(wizard, "Radio").handle))
      boxes[caption] = {"box": [area.left, area.top, area.right, area.bottom], "page": page,
         "editor_panel_bottom": panel[3], "back_top": back.top}
      if area.bottom > page[3] or area.right > page[2] or area.bottom > back.top:
         failures.append(label + ": '" + caption + "' is clipped or below Back: " + repr(boxes[caption]))
      if area.top < panel[3]:
         failures.append(label + ": '" + caption + "' overlaps the hosted radio editor: " + repr(boxes[caption]))
   facts.setdefault("cw_layout", {})[label] = boxes


def pick_item(items, needle, exclude=()):
   found = [text for text in items if needle.lower() in text.lower()
      and not any(word.lower() in text.lower() for word in exclude)]
   if not found:
      raise RuntimeError("No radio type containing " + repr(needle) + " in " + repr(items))
   return min(found, key=len)


# Radio type -> which CW boxes it must show (CW by CAT, speed sync). From the
# factory units' capability flags: the K4 declares rcCWByCAT and
# rcCWSpeedSync; the FT-817 neither; the FT-991 rcCWSpeedSync only.
CW_TYPE_MATRIX = (("k4", "K4", (True, True)), ("ft817", "817", (False, False)),
   ("ft991", "991", (False, True)), ("k4-again", "K4", (True, True)))


def choose_radio_type(wizard, needle, journal):
   model = ComboBoxWrapper(combos_by_top(wizard)[0].handle)
   text = pick_item(model.item_texts(), needle)
   journal.perform("choose radio type " + text, lambda: model.select(text))
   time.sleep(0.7)
   return text


def radio_type_matrix(wizard, output, journal, facts, failures, keyer_ticked, prefix=""):
   """Change the type and watch the CW boxes and the window follow it. Ends on
   the K4. Returns the K4's text as the type list shows it."""
   chosen = None
   for label, needle, (want_cat, want_sync) in CW_TYPE_MATRIX:
      text = choose_radio_type(wizard, needle, journal)
      state = cw_choice_state(wizard)
      key = prefix + label
      facts.setdefault("cw_choices", {})[key] = {"type": text, "state": state, "window": rect(wizard.handle)}
      journal.perform("capture radio type " + key, lambda: capture(wizard, output / ("radio-type-" + key + ".png")))
      if state[CW_BY_CAT]["visible"] != want_cat or state[SPEED_SYNC]["visible"] != want_sync:
         failures.append(key + " (" + text + "): CW boxes shown " + repr((state[CW_BY_CAT]["visible"],
            state[SPEED_SYNC]["visible"])) + ", expected " + repr((want_cat, want_sync)))
      if state[CW_BY_CAT]["visible"] and state[CW_BY_CAT]["enabled"] == keyer_ticked:
         failures.append(key + ": CW by CAT is " + ("enabled" if keyer_ticked else "disabled") + " while a WinKeyer is "
            + ("ticked" if keyer_ticked else "not ticked"))
      measure_hosted(wizard, hosted_name_box(wizard, "Radio"), "radio_type_" + key, facts, failures)
      cw_layout(wizard, "radio_type_" + key, facts, failures)
      if needle == "K4":
         chosen = text
   return chosen


def network_boxes(wizard, transport):
   """The Network tab's edits inside the tab control, top first: IP address,
   IP port, user name, password (the designer's order)."""
   area = transport.rectangle()
   return [control for control in edits_by_top(wizard)
      if control.rectangle().top >= area.top and control.rectangle().bottom <= area.bottom
      and control.rectangle().left >= area.left and control.rectangle().right <= area.right]


def fill_k4_network(wizard, output, journal, facts, failures):
   transport = find_transport(wizard)
   if transport is None:
      raise AssertionError("No transport tab control on the Radio page")
   facts["k4_tab_after_type"] = transport.get_tab_text(transport.get_selected_tab())
   if facts["k4_tab_after_type"] != "Network":
      journal.perform("select radio tab Network", lambda: transport.select("Network"))
      time.sleep(0.4)
   boxes = network_boxes(wizard, transport)
   if len(boxes) < 4:
      raise AssertionError("Network tab shows " + str(len(boxes)) + " edits, expected IP, port, user, password")
   address, port, user, password = boxes[:4]
   facts["k4_port_prefilled"] = port.window_text()
   import win32con as wc
   if not win32gui.GetWindowLong(password.handle, wc.GWL_STYLE) & wc.ES_PASSWORD:
      raise AssertionError("The fourth Network edit is not the password box")
   set_box(address, K4_ADDRESS, journal, "K4 IP address")
   if port.window_text() != K4_PORT:
      set_box(port, K4_PORT, journal, "K4 IP port")
   # The editor enables user/password only for a radio that logs in; the K4
   # does not, so the boxes are disabled and stay empty.
   facts["k4_credentials_enabled"] = {"user": enabled(user), "password": enabled(password)}
   if enabled(password):
      set_box(password, DUMMY_RADIO_PASSWORD, journal, "K4 network password (dummy)")
   facts["k4_network"] = {"address": address.window_text(), "port": port.window_text(), "user": user.window_text()}
   journal.perform("capture K4 network", lambda: capture(wizard, output / "radio-k4-network.png"))


def radio_page(app, wizard, output, journal, facts, failures):
   """THE RADIO PAGE, hosted, with the checklist's WinKeyer TICKED on arrival.
   Validation by its own editor; tabs; the CW boxes following the type with
   CW by CAT disabled; then Back, untick the WinKeyer, and both CW boxes ticked.
   Returns (name, type) and leaves the wizard on the page after the radio."""
   name_box = hosted_name_box(wizard, "Radio")
   facts["radio_name_preset"] = name_box.window_text()
   if facts["radio_name_preset"] != "Radio":
      failures.append("Radio page Name box reads " + repr(facts["radio_name_preset"]) + ", expected the preset 'Radio'")
   one_window(app, wizard, "radio_page", facts, failures)
   journal.perform("capture radio page", lambda: capture(wizard, output / "radio-page.png"))
   measure_hosted(wizard, name_box, "radio_page", facts, failures)
   facts["cw_choices_no_type"] = cw_choice_state(wizard)
   if any(item["visible"] for item in facts["cw_choices_no_type"].values()):
      failures.append("CW boxes shown before a radio type is chosen: " + repr(facts["cw_choices_no_type"]))

   # 1. No type chosen yet: the editor refuses Next.
   press_next_expect_refusal(app, wizard, ("Choose a radio type",), output / "radio-no-type.png",
      journal, facts, failures, "radio_refusal_no_type")
   if hosted_name_box(wizard, "Radio").window_text() != "Radio":
      failures.append("After refusing Next the wizard left the Radio page")

   # 2. Each transport tab, BEFORE a type is chosen (a serial-only type
   # disables Network). Selected, captured, measured.
   transport = find_transport(wizard)
   if transport is None:
      failures.append("No Serial/Network/Advanced tab control on the Radio page")
   else:
      facts["radio_tabs"] = {}
      for caption in RADIO_TABS:
         try:
            journal.perform("select radio tab " + caption, lambda: transport.select(caption))
            time.sleep(0.4)
            selected = transport.get_tab_text(transport.get_selected_tab())
            facts["radio_tabs"][caption] = selected
            if selected != caption:
               failures.append("Radio tab " + caption + " did not become selected (shows " + repr(selected) + ")")
            journal.perform("capture radio tab " + caption,
               lambda: capture(wizard, output / ("radio-tab-" + caption.lower() + ".png")))
            measure_hosted(wizard, hosted_name_box(wizard, "Radio"), "radio_tab_" + caption.lower(), facts, failures)
         except Exception as error:
            failures.append("Radio tab " + caption + " not usable: " + repr(error))
      journal.perform("back to the Serial tab", lambda: transport.select("Serial"))
      time.sleep(0.3)

   # 3. The type decides the CW boxes, the WinKeyer still ticked (so CW by CAT
   # is disabled). The preset name 'Radio' is kept. Ends on the K4.
   typed = "Radio"
   k4 = radio_type_matrix(wizard, output, journal, facts, failures, keyer_ticked=True)
   facts["radio_model"] = k4
   fill_k4_network(wizard, output, journal, facts, failures)

   # 4. Back, untick the WinKeyer, Next: the radio is kept and CW by CAT is
   # now offered. Both ticked.
   next_page(wizard, "< Back", journal)
   if not has_button(wizard, "A radio (rig control)"):
      raise AssertionError("Back from the Radio page did not reach the checklist")
   tick(wizard, "A WinKeyer", journal, False)
   next_page(wizard, "Next >", journal)
   check_radio_kept(wizard, typed, k4, "radio_kept_after_back_next", facts, failures)
   state = cw_choice_state(wizard)
   facts["cw_choices_keyer_unticked"] = state
   if not (state[CW_BY_CAT]["visible"] and state[CW_BY_CAT]["enabled"]):
      failures.append("With the WinKeyer unticked, CW by CAT is not offered and enabled for the K4: " + repr(state))
   for caption in (CW_BY_CAT, SPEED_SYNC):
      if cw_choice_state(wizard)[caption]["visible"]:
         tick(wizard, caption, journal, True)
   facts["cw_choices_ticked"] = cw_choice_state(wizard)
   journal.perform("capture radio CW ticked", lambda: capture(wizard, output / "radio-cw-ticked.png"))
   measure_hosted(wizard, hosted_name_box(wizard, "Radio"), "radio_cw_ticked", facts, failures)
   cw_layout(wizard, "radio_cw_ticked", facts, failures)

   # 5. A blank name is refused by the editor, on Next.
   name_box = hosted_name_box(wizard, "Radio")
   journal.perform("clear the radio name", lambda: name_box.type_keys("^a{DELETE}"))
   press_next_expect_refusal(app, wizard, ("The radio needs a name",), output / "radio-no-name.png",
      journal, facts, failures, "radio_refusal_no_name")
   name_box = hosted_name_box(wizard, "Radio")
   set_box(name_box, typed, journal, "radio Name again")
   facts["cw_choices_after_refusal"] = cw_choice_state(wizard)

   # 6. Accepted.
   next_page(wizard, "Next >", journal)
   if app.window(class_name="#32770", visible_only=True).exists(timeout=1):
      failures.append("A message box appeared on Next from the completed Radio page")
      acknowledge_notice(app, ("",), journal, output / "radio-unexpected-notice.png")
   return typed, k4


def check_radio_kept(wizard, name, model, label, facts, failures):
   name_box = hosted_name_box(wizard, "Radio")
   kept = {"name": name_box.window_text(), "model": combo_text(combos_by_top(wizard)[0])}
   facts[label] = kept
   if kept["name"] != name or kept["model"] != model:
      failures.append(label + ": the Radio page lost what was typed: " + repr(kept) + ", expected "
         + repr({"name": name, "model": model}))


def keyer_page(app, wizard, output, journal, facts, failures, incomplete, label, wanted_port="COM3",
      leave_caption="Next >"):
   """THE WINKEYER PAGE, hosted, on a REAL serial port (the guest's live
   WinKeyer). Returns (name, saved). With no such port the editor's refusal is
   proven and the case is INCOMPLETE -- never a pass. leave_caption is the
   button that leaves the page: 'Create configuration' when the keyer is the
   last ticked item."""
   name_box = hosted_name_box(wizard, "WinKeyer")
   facts["keyer_name_preset"] = name_box.window_text()
   if facts["keyer_name_preset"] != "WinKeyer":
      raise AssertionError("Did not reach the WinKeyer page (Name box reads " + repr(facts["keyer_name_preset"]) + ")")
   one_window(app, wizard, label, facts, failures)
   journal.perform("capture keyer page", lambda: capture(wizard, output / (label + ".png")))
   measure_hosted(wizard, name_box, label, facts, failures)
   port = ComboBoxWrapper(combos_by_top(wizard)[1].handle)
   facts["keyer_port_choices"] = port.item_texts()
   # Listed as the device and its port, e.g. 'USB Serial Port (COM3)'.
   import re
   matches = [text for text in facts["keyer_port_choices"]
      if re.search(r"(^|\()" + re.escape(wanted_port) + r"(\)|\s|$)", text.upper())]
   if not matches:
      press_next_expect_refusal(app, wizard, ("Choose the port",), output / "keyer-no-port.png",
         journal, facts, failures, "keyer_refusal_no_port")
      incomplete.append("WinKeyer not saved: " + wanted_port + " is not among the port choices "
         + repr(facts["keyer_port_choices"]))
      return "WinKeyer", False
   journal.perform("choose keyer port " + matches[0], lambda: port.select(matches[0]))
   time.sleep(0.4)
   facts["keyer_port_chosen"] = combo_text(combos_by_top(wizard)[1])
   journal.perform("capture keyer page with port", lambda: capture(wizard, output / (label + "-port.png")))
   next_page(wizard, leave_caption, journal)
   if app.window(class_name="#32770", visible_only=True).exists(timeout=1):
      facts["keyer_next_notice"] = acknowledge_notice(app, ("",), journal, output / "keyer-unexpected-notice.png")
      failures.append("A message box appeared on Next from the WinKeyer page: " + repr(facts["keyer_next_notice"]))
   return "WinKeyer", True


def set_clipboard(text):
   import win32clipboard
   win32clipboard.OpenClipboard()
   try:
      win32clipboard.EmptyClipboard()
      win32clipboard.SetClipboardText(text, win32clipboard.CF_UNICODETEXT)
   finally:
      win32clipboard.CloseClipboard()


def split_server(text):
   """uSetupWizard.SplitClusterServer, for the expectation: the first word,
   split at its first colon."""
   word = text.strip().split()[0] if text.strip() else ""
   host, _, port = word.partition(":")
   return host, port


def mouse_pick_top_item(app, combo, journal):
   """Open COMBO's drop-down with a click on its arrow and click the top
   visible entry of the list that appears. Returns (item text, index)."""
   from pywinauto import mouse
   import win32con as wc
   area = combo.rectangle()
   journal.perform("open the list by its arrow",
      lambda: mouse.click(coords=(area.right - 8, (area.top + area.bottom) // 2)))
   time.sleep(0.6)
   lists = []

   def collect(hwnd, _):
      if win32gui.GetClassName(hwnd) == "ComboLBox" and win32gui.IsWindowVisible(hwnd) \
            and win32process.GetWindowThreadProcessId(hwnd)[1] == app.process:
         lists.append(hwnd)
      return True

   win32gui.EnumWindows(collect, None)
   if len(lists) != 1:
      raise RuntimeError("Expected one open drop-down list, found " + str(len(lists)))
   top = win32gui.SendMessage(lists[0], wc.LB_GETTOPINDEX, 0, 0)
   height = win32gui.SendMessage(lists[0], wc.LB_GETITEMHEIGHT, 0, 0)
   point = win32gui.ClientToScreen(lists[0], (12, height // 2))
   items = ComboBoxWrapper(combo.handle).item_texts()
   journal.perform("click list entry " + repr(items[top]), lambda: mouse.click(coords=point))
   return items[top], top


def no_stray_notice(app, output, label, facts, failures):
   """A message box nobody expected: recorded, captured and closed, so it
   cannot swallow the next steps' keystrokes."""
   if app.window(class_name="#32770", visible_only=True).exists(timeout=0.5):
      notice = app.window(class_name="#32770", visible_only=True)
      text = notice_text(app, notice)
      capture(notice, output / (label + "-stray-notice.png"))
      facts.setdefault("stray_notices", []).append({"at": label, "text": text})
      failures.append(label + ": unexpected message box " + repr(text))
      ok = [control for control in notice.descendants(class_name="Button")
         if control.window_text().replace("&", "") == "OK"]
      if ok:
         ok[0].click_input()
         time.sleep(0.4)


def cluster_boxes(wizard):
   from pywinauto.controls.hwndwrapper import HwndWrapper
   server = field_by_caption(wizard, "Server:")
   inner = win32gui.FindWindowEx(server.handle, 0, "Edit", None)
   return server, (HwndWrapper(inner) if inner else server), field_by_caption(wizard, "Port:")


def cluster_values(wizard):
   server, server_edit, port = cluster_boxes(wizard)
   return {"server": server_edit.window_text(), "port": port.window_text()}


def on_cluster_page(wizard):
   return any(control.is_visible() and control.window_text() == "Server:" for control in wizard.descendants())


def pick_cluster_from_list(app, wizard, output, journal, facts, failures, label):
   """A pick from the public list, as an operator makes it: open the list with
   the arrow, click the top entry. (Not Enter: with the list closed, Enter is
   the wizard's default button.) Records facts[LABEL] and judges Server/Port
   straight after the pick, before anything else touches them. Returns the
   expected {'server', 'port'}, or None when there is no list to pick from."""
   server, server_edit, port = cluster_boxes(wizard)
   items = ComboBoxWrapper(server.handle).item_texts()
   if not items:
      failures.append("The cluster list is empty (TRCLUSTER.DAT beside the program?): the list pick is not tested")
      return None
   picked, index = mouse_pick_top_item(app, server, journal)
   time.sleep(0.6)
   no_stray_notice(app, output, label, facts, failures)
   facts[label] = {"clicked_index": index, "item": picked,
      "item_has_description": len(picked.split()) > 1,
      "selected_index_after": ComboBoxWrapper(server.handle).selected_index(),
      "before_tab": cluster_values(wizard)}
   journal.perform("capture cluster after list pick", lambda: capture(wizard, output / (label.replace("_", "-") + ".png")))
   want_host, want_port = split_server(picked)
   want = {"server": want_host, "port": want_port}
   facts[label]["expected"] = want
   if facts[label]["before_tab"] != want:
      failures.append("List pick " + repr(picked) + " shows " + repr(facts[label]["before_tab"])
         + " in Server/Port, expected " + repr(want))
   return want


def cluster_page(app, wizard, output, journal, facts, failures, host, port_text, password=None, exercise=True):
   """THE CLUSTER PAGE: Server and Port are two boxes. exercise: a pasted
   host:port and a list pick each split into the two; 'abc' and '70000' are
   refused with the page kept. Then HOST and PORT_TEXT (blank allowed) are
   left in the boxes for the commit."""
   server, server_edit, port = cluster_boxes(wizard)
   facts["cluster_directory_entries"] = ComboBoxWrapper(server.handle).item_count()
   facts["cluster_window"] = rect(wizard.handle)
   journal.perform("capture cluster page empty", lambda: capture(wizard, output / "cluster-page-empty.png"))
   if exercise:
      # A pasted host:port, then leaving the box.
      pasted = "dxc.example.net:7373"
      set_clipboard(pasted)
      journal.perform("click the cluster Server box", server_edit.click_input)
      journal.perform("paste " + pasted, lambda: server_edit.type_keys("^a^v"))
      facts["cluster_after_paste_before_tab"] = cluster_values(wizard)
      tab_out(server_edit, journal, "Server")
      facts["cluster_after_paste"] = cluster_values(wizard)
      if facts["cluster_after_paste"] != {"server": "dxc.example.net", "port": "7373"}:
         failures.append("Pasted " + pasted + " did not split into Server/Port: " + repr(facts["cluster_after_paste"]))
      journal.perform("capture cluster after paste", lambda: capture(wizard, output / "cluster-paste-split.png"))

      want = pick_cluster_from_list(app, wizard, output, journal, facts, failures, "cluster_list_pick")
      if want is not None:
         tab_out(server_edit, journal, "Server")
         facts["cluster_list_pick"]["after_tab"] = cluster_values(wizard)
         if facts["cluster_list_pick"]["after_tab"] != want:
            failures.append("List pick " + repr(facts["cluster_list_pick"]["item"]) + " after leaving the box shows "
               + repr(facts["cluster_list_pick"]["after_tab"]) + ", expected " + repr(want))
         # THE NEXT AFTER A PICK (the 2026-11-15 defect: the pick left Server
         # empty, so Next said SWizClusterNeeded). Page validation checks the
         # server BEFORE the port, so a bad port makes Next refuse with the
         # PORT message only if the picked server is really there -- the
         # check runs without committing anything.
         set_box(port, "abc", journal, "Port (after the list pick)")
         press(wizard, "Create configuration", journal, "press Create configuration (list pick, port abc)")
         try:
            facts["cluster_list_pick"]["next_notice"] = acknowledge_notice(app, (PORT_BAD,), journal,
               output / "cluster-pick-next.png")
         except Exception as error:
            failures.append("Next after the list pick did not answer with the port message (the server check "
               + "comes first, so the picked server was lost?): " + repr(error))
            no_stray_notice(app, output, "cluster_pick_next", facts, failures)
         time.sleep(0.3)
         facts["cluster_list_pick"]["after_next"] = cluster_values(wizard)
         if facts["cluster_list_pick"]["after_next"]["server"] != want["server"]:
            failures.append("After Next the picked server reads " + repr(facts["cluster_list_pick"]["after_next"]))

      # Bad ports: refused with the page kept.
      no_stray_notice(app, output, "before_bad_ports", facts, failures)
      set_box(server_edit, host, journal, "Server")
      tab_out(server_edit, journal, "Server")
      facts["cluster_bad_ports"] = {}
      for bad in ("abc", "70000"):
         set_box(port, bad, journal, "Port")
         facts["cluster_bad_ports"][bad] = {"values_pressed": cluster_values(wizard)}
         press(wizard, "Create configuration", journal, "press Create configuration (port " + bad + ")")
         try:
            text = acknowledge_notice(app, (PORT_BAD,), journal, output / ("cluster-port-" + bad + ".png"))
         except Exception as error:
            text = "no expected notice: " + repr(error)
            failures.append("Port " + repr(bad) + " was not refused with " + repr(PORT_BAD) + ": " + repr(error))
            no_stray_notice(app, output, "port_" + bad, facts, failures)
         time.sleep(0.3)
         kept = on_cluster_page(wizard) and has_button(wizard, "Create configuration")
         facts["cluster_bad_ports"][bad].update({"notice": text, "stayed_on_page": kept,
            "values": cluster_values(wizard)})
         if not kept:
            raise AssertionError("Port " + repr(bad) + " left the cluster page")

   # What is committed.
   no_stray_notice(app, output, "before_cluster_commit_values", facts, failures)
   server, server_edit, port = cluster_boxes(wizard)
   set_box(server_edit, host, journal, "Server")
   tab_out(server_edit, journal, "Server")
   set_box(port, port_text, journal, "Port")
   if password is not None:
      set_box(field_by_caption(wizard, "Password:"), password, journal, "cluster Password (dummy)")
   facts["cluster_committed_values"] = cluster_values(wizard)
   journal.perform("capture cluster page", lambda: capture(wizard, output / "cluster-page.png"))
   if not has_button(wizard, "Create configuration"):
      failures.append("The cluster page's Next does not read Create configuration")


def key_ci(record, name):
   """A JSON field by name, case-insensitively (the stores' spelling is
   camelCase, the Pascal property is not)."""
   for key, value in (record or {}).items():
      if key.lower() == name.lower():
         return value
   return None


def default_profile(settings):
   found = [profile for profile in settings.get("profiles", []) if profile.get("name") == "Default"]
   return found[0] if len(found) == 1 else None


def hardware(root, run_name, output, journal, facts, failures, incomplete, owned):
   app = fresh_start(root, run_name, journal)
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures)
   wizard = wait_wizard(app, journal, output, facts)
   station_page(wizard, output, journal, facts, failures)
   facts["station_window"] = rect(wizard.handle)
   next_page(wizard, "Next >", journal)
   for caption in ("A radio (rig control)", "A WinKeyer", "A DX cluster"):
      tick(wizard, caption, journal, True)
   facts["ticked"] = {caption: button(wizard, caption).get_check_state()
      for caption in ("A radio (rig control)", "A WinKeyer", "A DX cluster")}
   journal.perform("capture checklist ticked", lambda: capture(wizard, output / "checklist-ticked.png"))
   if not all(facts["ticked"].values()):
      raise AssertionError("Checklist boxes did not tick: " + repr(facts["ticked"]))
   next_page(wizard, "Next >", journal)

   # The radio page unticks the WinKeyer on its way, so the next page is the
   # cluster's.
   radio_name, radio_model = radio_page(app, wizard, output, journal, facts, failures)
   if not on_cluster_page(wizard):
      raise AssertionError("Next from the Radio page (WinKeyer unticked) did not reach the cluster page")
   cluster_page(app, wizard, output, journal, facts, failures, CLUSTER_HOST, CLUSTER_PORT,
      password=DUMMY_CLUSTER_PASSWORD)
   next_page(wizard, "Create configuration", journal)

   radio_line = 'Radio 1: ' + radio_model + ' at ' + K4_ADDRESS + ':' + K4_PORT + '. Name: "' + radio_name + '".'

   def judge(memo):
      text = memo.window_text()
      facts["result_fit"] = memo_fit(memo)
      for expected in (radio_line, "CW is sent through the radio (CW by CAT).",
            "The radio's CW speed follows the speed set in TR4W.",
            'The station profile "Default" now holds the hardware you set up.'):
         if expected not in text:
            failures.append("Done page lacks " + repr(expected))
      import re
      if not re.search(r'DX cluster ".+": ' + re.escape(CLUSTER) + r', logging in as your station callsign\.', text):
         failures.append("Done page lacks the cluster line naming " + CLUSTER + " and the login")
      if "WinKeyer" in text:
         failures.append("Done page mentions a WinKeyer although it was unticked")
      expected = ["   Frequency polling:", "   Password: set"]
      if facts.get("k4_credentials_enabled", {}).get("password"):
         expected.append("   Network password: set")
      show_details(wizard, output, journal, facts, failures, (DUMMY_RADIO_PASSWORD, DUMMY_CLUSTER_PASSWORD),
         tuple(expected))

   finish_result_page(app, wizard, output, journal, facts, failures, inspect=judge)

   settings = after_wizard(app, root, run_name, output, journal, facts, failures, CALL)
   check_station_settings(settings, failures, True)
   if settings is not None:
      general = settings.get("general", {})
      radios = settings.get("radios", [])
      clusters = settings.get("clusters", [])
      keyers = settings.get("keyers", [])
      default = default_profile(settings)
      facts["stored"] = {"radios": radios, "profiles": settings.get("profiles", []), "clusters": clusters,
         "keyers": keyers, "general": general}
      if len(radios) != 1 or radios[0].get("name") != radio_name:
         failures.append("radios[] is not exactly the wizard's radio: " + repr(radios))
      else:
         # THE CW CHOICES BELONG TO THE PROFILE: the radio carries neither.
         for name in ("cwByCAT", "cwSpeedSync"):
            if key_ci(radios[0], name) is True:
               failures.append("The radio itself carries " + name + " true")
      if default is None:
         failures.append("No single profile named Default: " + repr(settings.get("profiles")))
      else:
         if radios and default.get("radio1Id") != radios[0].get("id"):
            failures.append("Default profile slot 1 is not the wizard's radio")
         if key_ci(default, "CWOutput1") != "CAT":
            failures.append("Default profile CWOutput1 is " + repr(key_ci(default, "CWOutput1")) + ", expected 'CAT'")
         if key_ci(default, "speedSync1") is not True:
            failures.append("Default profile speedSync1 is " + repr(key_ci(default, "speedSync1")) + ", expected true")
      if general.get("activeProfile") != "Default":
         failures.append("general.activeProfile is " + repr(general.get("activeProfile")))
      if len(clusters) != 1 or clusters[0].get("server") != CLUSTER:
         failures.append("clusters[] is not exactly the wizard's cluster with server " + CLUSTER + ": " + repr(clusters))
      elif general.get("activeCluster") != clusters[0].get("name"):
         failures.append("general.activeCluster is not the wizard's cluster")
      if keyers:
         failures.append("A keyer was stored although the WinKeyer was unticked: " + repr(keyers))
      dump = json.dumps(settings)
      facts["dummy_passwords_in_settings_json"] = [secret for secret in (DUMMY_RADIO_PASSWORD, DUMMY_CLUSTER_PASSWORD)
         if secret in dump]
   common_log_checks(root, run_name, facts, failures, 1)
   text = log_text(root, run_name)
   facts["dummy_passwords_in_log"] = [secret for secret in (DUMMY_RADIO_PASSWORD, DUMMY_CLUSTER_PASSWORD)
      if secret in text]
   if facts["dummy_passwords_in_log"]:
      failures.append("tr4w.log contains a password typed into the wizard")
   facts["callbook_lines"] = [line for line in text.splitlines() if "[Callbook]" in line or "hamdb" in line.lower()]
   if facts["callbook_lines"]:
      failures.append("An offline phase reached the callbook: " + repr(facts["callbook_lines"]))


KEYER_LOG_WORDS = ("[Keyer]", "WinKey", "Winkeyer", "WK thread", "WkOpen", "COM3")


def keyer_problem(line):
   """A keyer line at warn/error/fatal, or the open failure's own text. The
   main window's [Layout] lines name the pnlWinKey panel and are not about the
   device."""
   import re
   if "[Layout]" in line:
      return False
   return bool(re.search(r"\] (warn|error|fatal) ", line, re.IGNORECASE)) or "Winkeyer port" in line


def keyer_status(main):
   """The main window's WinKeyer panel as the operator reads it ('WK3 v31'),
   or None when no control shows one. Read from the window, not from the
   [Layout] shrink warning, which only appears when the panel is too narrow."""
   import re
   for control in main.descendants():
      try:
         text = control.window_text()
      except Exception:
         continue
      if re.fullmatch(r"WK\d v\d+", text or ""):
         return text
   return None


def judge_keyer_status(main, key, facts, failures):
   facts[key] = keyer_status(main)
   if not (facts[key] or "").startswith("WK3"):
      failures.append(key + ": the main window's WinKeyer status reads " + repr(facts[key]) + ", expected WK3")


def reader_thread_id(line):
   """The id in 'Created WK thread with id N', or None."""
   import re
   found = re.search(r"Created WK thread with id (\d+)", line)
   return found.group(1) if found else None


STOP_START_PROBLEMS = ("already in progress", "did not finish", "did not exit", "still running",
   "could not be started")


def tools_keyer_again(app, main, root, run_name, output, journal, facts, failures, incomplete):
   """A SECOND Tools wizard in the same session, the first WinKeyer still OPEN:
   create another WinKeyer on the same COM3 (radio and cluster unticked). The
   apply must stop the running reader (wkStop) and open the new definition
   (wkStart). wkStop logs nothing on success, so the proof is wkStart's own
   guard: it refuses with 'the previous reader thread is still running' while
   the old reader lives. Exactly one new open, none of the stop/start
   complaints, the old reader silent after it, and WK3 on the main window.
   Returns the new keyer's name (from the profile line), or None."""
   import re
   second = {}
   facts["second_pass"] = second
   out = output / "second-pass"
   out.mkdir(parents=True, exist_ok=True)
   first_lines = facts.get("keyer_log_lines", [])
   old_ids = [reader_thread_id(line) for line in first_lines if reader_thread_id(line)]
   second["old_reader_id"] = old_ids[-1] if old_ids else None
   log_before = len(log_text(root, run_name).splitlines())
   select_menu(main, ["Tools", "Setup Wizard"], journal)
   wizard = wait_wizard(app, journal)
   time.sleep(0.5)
   call = field_by_caption(wizard, "Callsign:").window_text()
   next_page(wizard, "Next >", journal)
   tick(wizard, "A radio (rig control)", journal, False)
   tick(wizard, "A WinKeyer", journal, True)
   tick(wizard, "A DX cluster", journal, False)
   next_page(wizard, "Next >", journal)
   _, saved = keyer_page(app, wizard, out, journal, second, failures, incomplete, "tools-keyer2-page",
      leave_caption="Create configuration")
   if not saved:
      incomplete.append("Second pass: the WinKeyer could not be chosen on COM3; reopen not exercised")
      journal.perform("cancel the second wizard", button(wizard, "Cancel").click_input)
      return None

   # wkStop may hold the main thread up to 3 s per wait; let it finish.
   deadline = time.monotonic() + 20
   second["commit_notices"] = []
   while time.monotonic() < deadline:
      if app.window(class_name="#32770", visible_only=True).exists(timeout=0):
         shot = out / ("commit-notice-" + str(len(second["commit_notices"]) + 1) + ".png")
         second["commit_notices"].append(acknowledge_notice(app, ("",), journal, shot))
         continue
      if has_button(wizard, "Close"):
         break
      time.sleep(0.2)
   if second["commit_notices"]:
      failures.append("Second pass: message box(es) on Create configuration: " + repr(second["commit_notices"]))

   def judge(memo):
      text = memo.window_text()
      if not re.search(r'WinKeyer ".+" on COM3, used for CW on radio 1\.', text):
         failures.append("Second pass: Done page lacks the WinKeyer line naming COM3")
      if "Radio 1:" in text:
         failures.append("Second pass: Done page has a radio line although the radio was unticked")

   finish_result_page(app, wizard, out, journal, second, failures, inspect=judge, call=call)
   time.sleep(5)
   lines = log_text(root, run_name).splitlines()[log_before:]
   second["keyer_log_lines"] = [line for line in lines if any(word in line for word in KEYER_LOG_WORDS)]
   second["wizard_log_lines"] = [line for line in lines if "[SetupWizard]" in line]
   opens = [line for line in lines if "Calling tCreateThread from WkOpen" in line]
   created = [line for line in lines if "Created WK thread" in line]
   complaints = [line for line in lines if any(word in line for word in STOP_START_PROBLEMS)
      and ("WinKey" in line or "WK" in line or "reader" in line)]
   second["open_count"] = len(opens)
   second["created_count"] = len(created)
   second["stop_start_complaints"] = complaints
   if len(opens) != 1 or len(created) != 1:
      failures.append("Second pass: expected exactly one reopen ('Calling tCreateThread from WkOpen' and "
         + "'Created WK thread' once each), found " + str(len(opens)) + " and " + str(len(created)))
   if complaints:
      failures.append("Second pass: wkStop/wkStart complained: " + repr(complaints))
   bad = [line for line in second["keyer_log_lines"] if keyer_problem(line)]
   second["keyer_log_problems"] = bad
   if bad:
      failures.append("Second pass: tr4w.log reports a WinKeyer problem: " + repr(bad))
   # Supporting evidence: the first reader says nothing once the new one exists.
   old = second["old_reader_id"]
   if old and created:
      after = lines[lines.index(created[0]) + 1:]
      second["old_reader_lines_after_reopen"] = [line for line in after if "[" + old + "]" in line]
      if second["old_reader_lines_after_reopen"]:
         failures.append("Second pass: the first reader thread [" + old + "] still logs after the reopen: "
            + repr(second["old_reader_lines_after_reopen"][:5]))
   names = [re.search(r'uses WinKeyer "([^"]+)"', line) for line in second["keyer_log_lines"]]
   names = [found.group(1) for found in names if found]
   second["profile_keyer_name"] = names[-1] if names else None
   if second["profile_keyer_name"] is None:
      failures.append("Second pass: tr4w.log does not say which WinKeyer the profile uses")
   judge_keyer_status(main, "keyer_status_after_second_pass", second, failures)
   journal.perform("capture main window after the second wizard", lambda: capture(main, out / "main-after-wizard.png"))
   return second["profile_keyer_name"]


def tools_keyer(root, run_name, output, journal, facts, failures, incomplete, owned):
   """THE LIVE WINKEYER, through Tools > Setup Wizard (modeless; the commit puts
   the profile into use, so the port is opened). The hosted Radio page is also
   measured in this modeless window, then unticked."""
   databases = list(run_dir(root, run_name).glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Tools-keyer case needs exactly one CW Open fixture")
   app = journal.perform("launch existing station", lambda: launch(root, run_name, databases[0].name))
   owned.append(app)
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=45)
   time.sleep(1)
   log_before = len(log_text(root, run_name).splitlines())
   select_menu(main, ["Tools", "Setup Wizard"], journal)
   wizard = wait_wizard(app, journal)
   time.sleep(0.5)
   facts["main_enabled_with_wizard"] = enabled(main)
   if not facts["main_enabled_with_wizard"]:
      failures.append("Main window disabled while the Tools wizard is up (modal, expected modeless)")
   facts["wizard_callsign"] = field_by_caption(wizard, "Callsign:").window_text()
   next_page(wizard, "Next >", journal)
   for caption in ("A radio (rig control)", "A WinKeyer", "A DX cluster"):
      tick(wizard, caption, journal, True)
   next_page(wizard, "Next >", journal)

   # The hosted Radio page, modeless: one window, nothing clipped, inside the
   # work area; the K4 shows both CW boxes with CW by CAT disabled (WinKeyer
   # ticked). Then Back and untick -- this run commits the keyer alone.
   name_box = hosted_name_box(wizard, "Radio")
   one_window(app, wizard, "tools_radio_page", facts, failures)
   journal.perform("capture tools radio page", lambda: capture(wizard, output / "tools-radio-page.png"))
   measure_hosted(wizard, name_box, "tools_radio_page", facts, failures)
   choose_radio_type(wizard, "K4", journal)
   state = cw_choice_state(wizard)
   facts["tools_k4_cw_choices"] = state
   if not (state[CW_BY_CAT]["visible"] and state[SPEED_SYNC]["visible"]):
      failures.append("Tools wizard: the K4 does not show both CW boxes: " + repr(state))
   elif state[CW_BY_CAT]["enabled"]:
      failures.append("Tools wizard: CW by CAT is enabled while a WinKeyer is ticked")
   journal.perform("capture tools radio K4", lambda: capture(wizard, output / "tools-radio-k4.png"))
   measure_hosted(wizard, hosted_name_box(wizard, "Radio"), "tools_radio_k4", facts, failures)
   cw_layout(wizard, "tools_radio_k4", facts, failures)
   next_page(wizard, "< Back", journal)
   tick(wizard, "A radio (rig control)", journal, False)
   next_page(wizard, "Next >", journal)

   keyer_name, keyer_saved = keyer_page(app, wizard, output, journal, facts, failures, incomplete, "tools-keyer-page")
   if not keyer_saved:
      # Untick so the cluster can still be judged.
      next_page(wizard, "< Back", journal)
      tick(wizard, "A WinKeyer", journal, False)
      next_page(wizard, "Next >", journal)
   if not on_cluster_page(wizard):
      raise AssertionError("Next from the WinKeyer page did not reach the cluster page")
   # Blank port: the saved server is the host alone. Put into use on commit, so
   # it is a loopback address (nothing listens; the connect fails at once).
   cluster_page(app, wizard, output, journal, facts, failures, CLUSTER_HOST, "", exercise=False)
   press(wizard, "Create configuration", journal)

   # A port that will not open is reported by a warning box; capture it.
   deadline = time.monotonic() + 20
   facts["commit_notices"] = []
   while time.monotonic() < deadline:
      if app.window(class_name="#32770", visible_only=True).exists(timeout=0):
         shot = output / ("commit-notice-" + str(len(facts["commit_notices"]) + 1) + ".png")
         facts["commit_notices"].append(acknowledge_notice(app, ("",), journal, shot))
         continue
      if has_button(wizard, "Close"):
         break
      time.sleep(0.2)
   if facts["commit_notices"]:
      failures.append("Message box(es) on Create configuration: " + repr(facts["commit_notices"]))

   def judge(memo):
      text = memo.window_text()
      facts["result_fit"] = memo_fit(memo)
      if keyer_saved and 'WinKeyer "' + keyer_name + '" on COM3, used for CW on radio 1.' not in text:
         failures.append("Done page lacks the WinKeyer line naming COM3")
      import re
      if not re.search(r'DX cluster ".+": ' + re.escape(CLUSTER_HOST) + r', logging in as ', text):
         failures.append("Done page lacks the cluster line naming the host alone (" + CLUSTER_HOST + ")")
      if "Radio 1:" in text:
         failures.append("Done page has a radio line although the radio was unticked")
      if keyer_saved:
         show_details(wizard, output, journal, facts, failures, (), ("   Mode ",))

   finish_result_page(app, wizard, output, journal, facts, failures, inspect=judge, call=facts["wizard_callsign"])
   # Let the keyer thread start and report.
   time.sleep(5)
   lines = log_text(root, run_name).splitlines()[log_before:]
   facts["keyer_log_lines"] = [line for line in lines if any(word in line for word in KEYER_LOG_WORDS)]
   facts["wizard_log_lines"] = [line for line in lines if "[SetupWizard]" in line]
   facts["cluster_log_lines"] = [line for line in lines if "luster" in line or "Telnet" in line][-15:]
   if keyer_saved:
      if not any('uses WinKeyer "' + keyer_name + '"' in line for line in facts["keyer_log_lines"]):
         failures.append("tr4w.log does not say the profile uses the WinKeyer")
      # The open runs on a worker, so its lines race the main thread's
      # 'configuration created'; the order is recorded, not asserted.
      facts["keyer_open_order"] = [line for line in lines if "configuration created" in line
         or "Calling tCreateThread from" in line or "Created WK thread" in line
         or "Created WinKeyer thread" in line]
      if not any("Created WK thread" in line for line in facts["keyer_log_lines"]):
         failures.append("Tools wizard: the WinKeyer was saved and named in the profile but NOT OPENED in this "
            + "session (no 'Created WK thread' after the wizard opened; the profile apply should wkStart it)")
      bad = [line for line in facts["keyer_log_lines"] if keyer_problem(line)]
      facts["keyer_log_problems"] = bad
      if bad:
         failures.append("tr4w.log reports a WinKeyer problem: " + repr(bad))
      judge_keyer_status(main, "keyer_status_after_wizard", facts, failures)
   journal.perform("capture main window with keyer", lambda: capture(main, output / "main-after-wizard.png"))
   second_name = None
   if keyer_saved:
      second_name = tools_keyer_again(app, main, root, run_name, output, journal, facts, failures, incomplete)
   close_normally(app, main, journal)
   settings = read_settings(root, run_name)
   if settings is None:
      failures.append("No settings file after the Tools wizard")
   else:
      keyers = settings.get("keyers", [])
      default = default_profile(settings)
      clusters = settings.get("clusters", [])
      facts["stored"] = {"keyers": keyers, "profiles": settings.get("profiles", []), "clusters": clusters,
         "radios": settings.get("radios", []), "general": settings.get("general", {})}
      if keyer_saved:
         # One keyer per wizard pass, all on COM3, distinct names; the Default
         # profile uses the one the LAST pass created.
         expected = 2 if second_name else 1
         names = [keyer.get("name") for keyer in keyers]
         if (len(keyers) != expected or len(set(names)) != len(names)
               or any("COM3" not in json.dumps(keyer).upper() for keyer in keyers)):
            failures.append("keyers[] is not " + str(expected) + " distinctly named keyer(s) on COM3: " + repr(keyers))
         elif default is None:
            failures.append("No single Default profile: " + repr(settings.get("profiles")))
         else:
            wanted = [keyer for keyer in keyers if keyer.get("name") == second_name] if second_name else keyers
            if len(wanted) != 1:
               failures.append("The second pass's keyer " + repr(second_name) + " is not in keyers[]: " + repr(names))
            else:
               if key_ci(default, "CWOutput1") != wanted[0].get("name"):
                  failures.append("Default profile CWOutput1 is " + repr(key_ci(default, "CWOutput1"))
                     + ", expected the latest keyer's name " + repr(wanted[0].get("name")))
               if key_ci(default, "CWOutput1Id") != wanted[0].get("id"):
                  failures.append("Default profile CWOutput1Id is not the latest keyer's id")
      if settings.get("radios"):
         failures.append("A radio was stored although the radio was unticked: " + repr(settings.get("radios")))
      if len(clusters) != 1 or clusters[0].get("server") != CLUSTER_HOST:
         failures.append("clusters[] is not exactly one cluster with server " + repr(CLUSTER_HOST) + ": " + repr(clusters))

   # A RESTART on what the wizard saved: startup opens an enabled WinKeyer
   # (uProgramMain), so this is where the port is proven to open, or not.
   if keyer_saved:
      log_before = len(log_text(root, run_name).splitlines())
      app = journal.perform("restart on the saved keyer", lambda: launch(root, run_name, databases[0].name))
      owned.append(app)
      (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible enabled", timeout=45)
      time.sleep(6)
      facts["restart_notices"] = []
      while app.window(class_name="#32770", visible_only=True).exists(timeout=0.5):
         shot = output / ("restart-notice-" + str(len(facts["restart_notices"]) + 1) + ".png")
         facts["restart_notices"].append(acknowledge_notice(app, ("",), journal, shot))
      lines = log_text(root, run_name).splitlines()[log_before:]
      facts["restart_keyer_log_lines"] = [line for line in lines if any(word in line for word in KEYER_LOG_WORDS)]
      journal.perform("capture main window after restart", lambda: capture(main, output / "main-after-restart.png"))
      problems = [line for line in facts["restart_keyer_log_lines"] if keyer_problem(line)]
      facts["restart_keyer_log_problems"] = problems
      if not any("Created WK thread" in line for line in facts["restart_keyer_log_lines"]):
         failures.append("After a restart tr4w.log still has no 'Created WK thread' line: the WinKeyer was not opened")
      if problems or facts["restart_notices"]:
         failures.append("Opening the WinKeyer at restart reported a problem: " + repr(problems + facts["restart_notices"]))
      judge_keyer_status(main, "keyer_status_after_restart", facts, failures)
      close_normally(app, main, journal)
   text = log_text(root, run_name)
   facts["crash_marker"] = "[CRASH]" in text
   if facts["crash_marker"]:
      failures.append("tr4w.log has a [CRASH] marker")
   facts["callbook_lines"] = [line for line in text.splitlines() if "[Callbook]" in line]


def tools_menu(root, run_name, output, journal, facts, failures, incomplete, owned):
   databases = list(run_dir(root, run_name).glob("CWOPEN*.db"))
   if len(databases) != 1:
      raise RuntimeError("Tools-menu case needs exactly one CW Open fixture")
   app = journal.perform("launch existing station", lambda: launch(root, run_name, databases[0].name))
   owned.append(app)
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=45)
   time.sleep(1)
   facts["auto_opened"] = app.window(title=WIZARD, visible_only=True).exists(timeout=0)
   if facts["auto_opened"]:
      failures.append("The wizard opened by itself for an existing station")
   select_menu(main, ["Tools", "Setup Wizard"], journal)
   wizard = wait_wizard(app, journal)
   time.sleep(0.5)
   facts["main_enabled_with_wizard"] = enabled(main)
   facts["wizard_callsign"] = field_by_caption(wizard, "Callsign:").window_text()
   facts["radios_before"] = (read_settings(root, run_name) or {}).get("radios")
   check_cty_line(wizard, facts, failures, expect_download=False)
   journal.perform("capture Tools wizard", lambda: capture(wizard, output / "tools-wizard.png"))
   if not facts["main_enabled_with_wizard"]:
      failures.append("Main window disabled while the Tools wizard is up (modal, expected modeless)")

   # THE HOSTED RADIO PAGE IN THE MODELESS WINDOW: measured with no type, then
   # K4, FT-817, FT-991 (radio_type_matrix). Only the radio is ticked, so CW by
   # CAT must be enabled. Cancelled afterwards: nothing is committed or opened.
   next_page(wizard, "Next >", journal)
   tick(wizard, "A radio (rig control)", journal, True)
   next_page(wizard, "Next >", journal)
   name_box = hosted_name_box(wizard, "Radio")
   one_window(app, wizard, "tools_radio_page", facts, failures)
   journal.perform("capture tools radio page", lambda: capture(wizard, output / "tools-radio-page.png"))
   measure_hosted(wizard, name_box, "tools_radio_no_type", facts, failures)
   radio_type_matrix(wizard, output, journal, facts, failures, keyer_ticked=False, prefix="tools_")

   journal.perform("cancel the wizard", button(wizard, "Cancel").click_input)
   journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=10))
   close_normally(app, main, journal)
   text = log_text(root, run_name)
   facts["crash_marker"] = "[CRASH]" in text
   if facts["crash_marker"]:
      failures.append("tr4w.log has a [CRASH] marker")
   facts["callbook_lines"] = [line for line in text.splitlines() if "[Callbook]" in line]
   settings = read_settings(root, run_name)
   if settings is not None and settings.get("radios") != facts["radios_before"]:
      failures.append("Cancel from the Tools wizard changed radios[]: " + repr(facts["radios_before"]) + " -> "
         + repr(settings.get("radios")))


def station_empty_folder(root, run_name, output, journal, facts, failures, incomplete, owned):
   """The literal NY4I condition: a working folder with NOTHING in it, so no
   country file is reachable (the shipped tier is the working folder)."""
   station_only(root, run_name, output, journal, facts, failures, incomplete, owned, expect_derived=False)


def cty_download(root, run_name, output, journal, facts, failures, incomplete, owned):
   """The empty folder again, and the Station page's Download button pressed.
   GOES TO THE NETWORK (country-files.com over HTTPS) -- run only where the
   guest has that. A failed fetch is reported NOT RUN with tr4w.log's reason,
   unless the log shows the program itself failing."""
   app = fresh_start(root, run_name, journal)
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures)
   wizard = wait_wizard(app, journal, output, facts)
   wizard_cty_log(root, run_name, facts)
   check_cty_line(wizard, facts, failures, expect_download=True)
   journal.perform("capture Station page before download", lambda: capture(wizard, output / "station-no-cty.png"))
   if not facts.get("cty_download_enabled"):
      raise AssertionError("No Download button to press")
   journal.perform("press " + CTY_DOWNLOAD, button(wizard, CTY_DOWNLOAD).click_input)

   # While it runs: Next and Cancel disabled (Back is disabled on page 1 anyway).
   observed = []
   deadline = time.monotonic() + 90
   while time.monotonic() < deadline:
      still = has_button(wizard, CTY_DOWNLOAD)
      state = {"t": round(time.monotonic(), 2), "download_button": still,
         "download_enabled": still and enabled(button(wizard, CTY_DOWNLOAD)),
         "next_enabled": enabled(button(wizard, "Next >")), "cancel_enabled": enabled(button(wizard, "Cancel")),
         "back_enabled": enabled(button(wizard, "< Back"))}
      observed.append(state)
      if not still or state["download_enabled"]:
         break   # finished: hidden on success, re-enabled on failure
      time.sleep(0.1)
   facts["download_states"] = observed
   during = [state for state in observed if state["download_button"] and not state["download_enabled"]]
   facts["download_running_observed"] = bool(during)
   if during:
      if any(state["next_enabled"] or state["cancel_enabled"] or state["back_enabled"] for state in during):
         failures.append("Back/Next/Cancel were enabled while the country file was downloading: " + repr(during))
   else:
      facts["download_running_note"] = "the download finished before a polling pass could see it running"
   journal.perform("capture Station page after download", lambda: capture(wizard, output / "station-after-download.png"))
   final = observed[-1] if observed else {}
   facts["downloaded_file"] = (run_dir(root, run_name) / "CTY.DAT").is_file()
   facts["cty_log_tail"] = [line for line in log_text(root, run_name).splitlines()
      if "CTY" in line.upper() or "country" in line.lower()][-15:]
   if final.get("download_button", True):
      # Not loaded: a network failure is NOT RUN; anything else is a failure.
      incomplete.append("Country-file download did not complete on the guest; see cty_log_tail in wizard-facts.json")
   else:
      if not facts["downloaded_file"]:
         failures.append("The Download button went, but no CTY.DAT is in the run's settings directory")
      if not (enabled(button(wizard, "Next >")) and enabled(button(wizard, "Cancel"))):
         failures.append("Next/Cancel not re-enabled after the download")
      station_page(wizard, output, journal, facts, failures, expect_derived=True)
   journal.perform("press the wizard's Cancel", button(wizard, "Cancel").click_input)
   journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=15))
   cancel_new_contest(app, wait_new_contest(app, journal), output, journal, facts, failures, "after-download")
   common_log_checks(root, run_name, facts, failures, 1)


DUMMY_NETWORK_USER = "dummyuser"
ICOM_ADDRESS = "192.168.1.9"


def radio_done_report(root, run_name, output, journal, facts, failures, incomplete, owned, transport,
      cluster_pick=False):
   """THE DONE PAGE'S RADIO LINE for the two connections the K4 run cannot
   show: a SERIAL radio on COM3 ('... on COM3.', the Serial detail line) and a
   network radio that LOGS IN (the IC-9700: 'Network user', 'Network password:
   set', never the password). Startup mode and New Contest cancelled, so
   neither the port nor the address is opened."""
   app = fresh_start(root, run_name, journal)
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures)
   wizard = wait_wizard(app, journal, output, facts)
   station_page(wizard, output, journal, facts, failures)
   next_page(wizard, "Next >", journal)
   tick(wizard, "A radio (rig control)", journal, True)
   if cluster_pick:
      tick(wizard, "A DX cluster", journal, True)
   next_page(wizard, "Next >", journal)
   hosted_name_box(wizard, "Radio")
   secrets = ()
   if transport == "serial":
      model = choose_radio_type(wizard, "K3", journal)
      transport_tabs = find_transport(wizard)
      journal.perform("select radio tab Serial", lambda: transport_tabs.select("Serial"))
      time.sleep(0.4)
      port = ComboBoxWrapper(combos_by_top(wizard)[1].handle)
      facts["radio_port_choices"] = port.item_texts()
      com3 = [text for text in facts["radio_port_choices"] if "(COM3)" in text.upper() or text.upper() == "COM3"]
      if not com3:
         incomplete.append("No COM3 among the radio port choices " + repr(facts["radio_port_choices"]))
         return
      journal.perform("choose radio port " + com3[0], lambda: port.select(com3[0]))
      time.sleep(0.4)
      expected_line = 'Radio 1: ' + model + ' on COM3. Name: "Radio".'
      expected_details = ("   Serial: ", "   Frequency polling:")
   else:
      model = choose_radio_type(wizard, "9700", journal)
      transport_tabs = find_transport(wizard)
      journal.perform("select radio tab Network", lambda: transport_tabs.select("Network"))
      time.sleep(0.4)
      address, port_box, user, password = network_boxes(wizard, transport_tabs)[:4]
      facts["network_credentials_enabled"] = {"user": enabled(user), "password": enabled(password)}
      if not (enabled(user) and enabled(password)):
         failures.append(model + ": the user/password boxes are disabled for a radio that logs in")
      set_box(address, ICOM_ADDRESS, journal, "IP address")
      facts["network_port_prefilled"] = port_box.window_text()
      set_box(user, DUMMY_NETWORK_USER, journal, "network user (dummy)")
      set_box(password, DUMMY_RADIO_PASSWORD, journal, "network password (dummy)")
      secrets = (DUMMY_RADIO_PASSWORD,)
      expected_line = ('Radio 1: ' + model + ' at ' + ICOM_ADDRESS + ':' + facts["network_port_prefilled"]
         + '. Name: "Radio".')
      expected_details = ("   Network user: " + DUMMY_NETWORK_USER, "   Network password: set", "   Frequency polling:")
   facts["radio_model"] = model
   journal.perform("capture radio page filled", lambda: capture(wizard, output / "radio-filled.png"))
   picked_server = None
   if cluster_pick:
      # THE COMMITTED LIST PICK: the cluster page's Next pressed straight after
      # a mouse pick, nothing else touched. Startup mode only SAVES the
      # cluster and New Contest is cancelled, so it is never dialled.
      next_page(wizard, "Next >", journal)
      if not on_cluster_page(wizard):
         raise AssertionError("Next from the Radio page did not reach the cluster page")
      want = pick_cluster_from_list(app, wizard, output, journal, facts, failures, "cluster_pick_commit")
      if want is not None:
         picked_server = want["server"] + (":" + want["port"] if want["port"] else "")
         facts["cluster_pick_commit"]["stored_expected"] = picked_server
   next_page(wizard, "Create configuration", journal)
   no_stray_notice(app, output, "radio_commit", facts, failures)

   def judge(memo):
      text = memo.window_text()
      facts["result_fit"] = memo_fit(memo)
      if expected_line not in text:
         failures.append("Done page lacks " + repr(expected_line))
      if picked_server is not None:
         import re
         if not re.search(r'DX cluster ".+": ' + re.escape(picked_server) + r', logging in as ', text):
            failures.append("Done page lacks the cluster line naming the picked " + picked_server)
      show_details(wizard, output, journal, facts, failures, secrets, expected_details)

   finish_result_page(app, wizard, output, journal, facts, failures, inspect=judge)
   settings = after_wizard(app, root, run_name, output, journal, facts, failures, CALL)
   check_station_settings(settings, failures, True)
   if settings is not None:
      facts["stored"] = {"radios": settings.get("radios", []), "profiles": settings.get("profiles", []),
         "clusters": settings.get("clusters", [])}
      if picked_server is not None:
         clusters = settings.get("clusters", [])
         if len(clusters) != 1 or clusters[0].get("server") != picked_server:
            failures.append("clusters[] is not exactly the picked cluster " + repr(picked_server) + ": " + repr(clusters))
      if DUMMY_RADIO_PASSWORD in json.dumps(settings):
         failures.append("The radio's network password is written into tr4w.json in plain text")
   text = log_text(root, run_name)
   if DUMMY_RADIO_PASSWORD in text:
      failures.append("tr4w.log contains the radio's network password")
   common_log_checks(root, run_name, facts, failures, 1)


def radio_done_serial(root, run_name, output, journal, facts, failures, incomplete, owned):
   radio_done_report(root, run_name, output, journal, facts, failures, incomplete, owned, "serial")


def radio_done_network(root, run_name, output, journal, facts, failures, incomplete, owned):
   radio_done_report(root, run_name, output, journal, facts, failures, incomplete, owned, "network", cluster_pick=True)


CALLBOOK_EXPECTED = {"First name:": "Thomas", "Grid square:": "EL88pa", "State/Province:": "FL",
   "Postal code:": "33761"}
# Typed BEFORE the callsign on the first start: the callbook must keep both.
CALLBOOK_TYPED = {"First name:": "Tester", "Postal code:": "12345"}


def callbook_attempt(app, wizard, output, journal, facts, failures, incomplete, root, run_name, label, typed):
   """Type the callsign (after the boxes in TYPED, if any) and wait for the
   callbook's reply to land in the empty boxes. True when it was judged."""
   boxes = {caption: field_by_caption(wizard, caption) for caption in CALLBOOK_EXPECTED}
   before = {caption: box.window_text() for caption, box in boxes.items()}
   for caption, text in typed.items():
      set_box(boxes[caption], text, journal, caption.rstrip(":"))
   call_box = field_by_caption(wizard, "Callsign:")
   journal.perform("click the wizard Callsign box", call_box.click_input)
   journal.perform("type " + CALL, lambda: call_box.type_keys("^a" + CALL))
   typed_at = time.monotonic()
   values = {}
   deadline = typed_at + 15
   while time.monotonic() < deadline:
      values = {caption: box.window_text() for caption, box in boxes.items()}
      if all(values.values()):
         break
      time.sleep(0.2)
   # A little longer: a late second write would overwrite what was judged.
   time.sleep(1.5)
   values = {caption: box.window_text() for caption, box in boxes.items()}
   record = {"before": before, "typed": typed, "after": values,
      "seconds_to_fill": round(time.monotonic() - typed_at - 1.5, 1)}
   record["note_expected_on_screen"] = CALLBOOK_NOTE
   facts[label] = record
   journal.perform("capture " + label, lambda: capture(wizard, output / (label + ".png")))
   expected = dict(CALLBOOK_EXPECTED)
   expected.update(typed)
   if values == {caption: typed.get(caption, "") for caption in boxes}:
      failed = [line for line in log_text(root, run_name).splitlines() if "[Callbook]" in line and "failed" in line]
      if failed:
         incomplete.append(label + ": the callbook was not reachable from the guest: " + failed[-1])
         return False
   if values != expected:
      failures.append(label + ": after typing " + CALL + " the boxes read " + repr(values) + ", expected "
         + repr(expected))
   return True


def callbook(root, run_name, output, journal, facts, failures, incomplete, owned):
   """THE CALLBOOK (hamdb.org), GOES TO THE NETWORK. A station with no callsign:
   the settings file is the suite's template with the station removed, so the
   log is at DEBUG and the lookup's own lines are written. Two starts (a saved
   callsign ends the offer, so the saving start is the last): a name and a
   postal code typed first, which must be kept, then Cancel; then NY4I into
   empty boxes -- Name, Grid, State and Postal code (33761) filled -- carried
   through Create configuration, so MY POSTAL CODE is saved as 33761."""
   template = Path(facts["fixture"]["assets"]) / "tr4w.json"
   seeded = json.loads(template.read_text(encoding="utf-8-sig"))
   seeded.get("settings", {}).pop("My", None)
   (run_dir(root, run_name) / "tr4w.json").write_text(json.dumps(seeded, indent=3), encoding="utf-8")
   facts["seeded_log_level"] = seeded.get("settings", {}).get("Log", {}).get("DebugLevel")

   for attempt, typed in ((1, CALLBOOK_TYPED), (2, {})):
      label = "callbook-" + str(attempt)
      app = start_again(root, run_name, journal, "start " + str(attempt) + ": no callsign stored")
      owned.append(app)
      answer_offer(app, "Yes", output, journal, facts, failures, "offer-" + str(attempt))
      wizard = wait_wizard(app, journal, output, facts)
      judged = callbook_attempt(app, wizard, output, journal, facts, failures, incomplete, root, run_name, label,
         typed)
      if attempt == 2 and judged:
         # The filled values go through the wizard's own save.
         next_page(wizard, "Next >", journal)
         next_page(wizard, "Create configuration", journal)
         finish_result_page(app, wizard, output, journal, facts, failures)
         settings = after_wizard(app, root, run_name, output, journal, facts, failures, CALL)
         my = (settings or {}).get("settings", {}).get("My", {})
         facts["saved_station"] = my
         if my.get("PostalCode") != CALLBOOK_EXPECTED["Postal code:"]:
            failures.append("MY POSTAL CODE saved as " + repr(my.get("PostalCode")) + ", expected "
               + repr(CALLBOOK_EXPECTED["Postal code:"]))
         continue
      journal.perform("press the wizard's Cancel", button(wizard, "Cancel").click_input)
      journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=15))
      cancel_new_contest(app, wait_new_contest(app, journal), output, journal, facts, failures, label)
   common_log_checks(root, run_name, facts, failures, 2, offline=False)

   # WHAT LEFT THE MACHINE: only the callsign, in the URL path.
   import re
   lines = log_text(root, run_name).splitlines()
   facts["callbook_log_lines"] = [line for line in lines if "[Callbook]" in line]
   facts["http_hamdb_lines"] = [line for line in lines if "hamdb" in line.lower()]
   urls = re.findall(r"https?://[^\s'\"]*hamdb[^\s'\"]*", "\n".join(lines), re.IGNORECASE)
   facts["hamdb_urls"] = sorted(set(urls))
   if not facts["callbook_log_lines"] and not facts["http_hamdb_lines"]:
      failures.append("tr4w.log has no callbook or hamdb line (log level " + repr(facts["seeded_log_level"]) + ")")
   for url in facts["hamdb_urls"]:
      if not re.fullmatch(r"https://api\.hamdb\.org/v1/" + CALL + r"/json/TR4W", url):
         failures.append("A hamdb request carries more than the callsign: " + url)
   for word in ("Tester", "Wizard"):
      if any(word in line for line in facts["http_hamdb_lines"]):
         failures.append("A typed station value appears in a hamdb log line: " + word)


# A set-up station for --wizard: all four lookup boxes filled, so no callbook
# lookup is made, and values unlike anything the other phases type.
SWITCH_CALL = "W1AW"
SWITCH_STATION = {"Callsign:": SWITCH_CALL, "First name:": "Hiram", "Grid square:": "FN31pr",
   "State/Province:": "CT", "Postal code:": "06111"}
USAGE_WIZARD_LINE = "--wizard           run the setup wizard first, even on a set-up station"


def seed_station(root, run_name, facts):
   """The suite's settings template with a full station written into My."""
   path = run_dir(root, run_name) / "tr4w.json"
   settings = json.loads(path.read_text(encoding="utf-8-sig"))
   my = settings.setdefault("settings", {}).setdefault("My", {})
   my.update({"MainCallsign": SWITCH_CALL, "Call": SWITCH_CALL, "Name": SWITCH_STATION["First name:"],
      "Grid": SWITCH_STATION["Grid square:"], "State": SWITCH_STATION["State/Province:"],
      "PostalCode": SWITCH_STATION["Postal code:"]})
   path.write_text(json.dumps(settings, indent=3), encoding="utf-8")
   facts["seeded_station"] = dict(my)


def switch_start(root, run_name, journal, owned, label, extra_args):
   app = journal.perform(label, lambda: launch(root, run_name, "", extra_args=extra_args))
   owned.append(app)
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   return app


def switch_new_contest(app, output, journal, facts, failures, label, while_open=None):
   """New Contest after a --wizard start: the stored callsign, Cancel, exit 0.
   while_open() runs while New Contest is still up, before Cancel."""
   startup = wait_new_contest(app, journal, label)
   if while_open is not None:
      while_open()
   facts[label + "_new_contest_callsign"] = new_contest_callsign(startup).window_text()
   journal.perform("capture New Contest " + label, lambda: capture(startup, output / (label + "-new-contest.png")))
   if facts[label + "_new_contest_callsign"] != SWITCH_CALL:
      failures.append(label + ": New Contest callsign is " + repr(facts[label + "_new_contest_callsign"])
         + ", expected " + repr(SWITCH_CALL))
   handle = watch_exit(app)
   journal.perform("cancel New Contest " + label,
      lambda: startup.child_window(title="Cancel", class_name="Button").click_input())
   facts[label + "_exit_code"] = exit_code(app, handle, journal)
   if facts[label + "_exit_code"] != 0:
      failures.append(label + ": exit code after cancelling New Contest: " + str(facts[label + "_exit_code"]))


def wizard_switch(root, run_name, output, journal, facts, failures, incomplete, owned):
   """--wizard on a station that already has a callsign: the wizard at once, NO
   Yes/No question, the Station page showing the stored values; Cancel goes on
   to New Contest. A second start goes through Create configuration. Then -h
   must list the switch."""
   seed_station(root, run_name, facts)
   settings_path = run_dir(root, run_name) / "tr4w.json"
   facts["switch_file_sha256_seeded"] = file_sha256(settings_path)

   def cancel_wrote_nothing():
      # The wizard's Cancel must not write the settings file (issue 322: the
      # whole object is saved over the section, so a stray save is the risk).
      facts["switch_file_sha256_after_cancel"] = file_sha256(settings_path)
      if facts["switch_file_sha256_after_cancel"] != facts["switch_file_sha256_seeded"]:
         failures.append("The wizard's Cancel changed tr4w.json")

   # 1. --wizard, then the wizard's Cancel.
   app = switch_start(root, run_name, journal, owned, "start with --wizard (callsign stored)", ["--wizard"])
   wizard = wait_wizard(app, journal, output, facts)
   facts["switch_new_contest_with_wizard"] = new_contest_visible(app)
   if facts["switch_new_contest_with_wizard"]:
      failures.append("New Contest is visible while the --wizard wizard is up")
   shown = {caption: field_by_caption(wizard, caption).window_text() for caption in SWITCH_STATION}
   facts["switch_station_shown"] = shown
   journal.perform("capture --wizard Station page", lambda: capture(wizard, output / "switch-station.png"))
   if shown != SWITCH_STATION:
      failures.append("--wizard Station page shows " + repr(shown) + ", stored " + repr(SWITCH_STATION))
   journal.perform("press the wizard's Cancel", button(wizard, "Cancel").click_input)
   journal.perform("wizard closes", lambda: wizard.wait_not("visible", timeout=15))
   switch_new_contest(app, output, journal, facts, failures, "switch-cancel", while_open=cancel_wrote_nothing)

   # 2. --wizard again, through Create configuration. NOTHING is typed: the
   # page must carry the stored station by itself (issue 322), so a page
   # showing anything else stops the case here rather than being typed back.
   app = switch_start(root, run_name, journal, owned, "second start with --wizard", ["--wizard"])
   wizard = wait_wizard(app, journal, output, facts)
   shown = {caption: field_by_caption(wizard, caption).window_text() for caption in SWITCH_STATION}
   facts["switch_create_station_shown"] = shown
   if shown != SWITCH_STATION:
      raise AssertionError("--wizard (second start) Station page shows " + repr(shown) + ", stored "
         + repr(SWITCH_STATION))
   next_page(wizard, "Next >", journal)
   if not has_button(wizard, "Create configuration"):
      raise AssertionError("--wizard: the checklist's Next does not read Create configuration")
   next_page(wizard, "Create configuration", journal)
   finish_result_page(app, wizard, output, journal, facts, failures, call=SWITCH_CALL)
   switch_new_contest(app, output, journal, facts, failures, "switch-create")
   settings = read_settings(root, run_name) or {}
   my = settings.get("settings", {}).get("My", {})
   facts["switch_saved_station"] = my
   for caption, key in (("Callsign:", "Call"), ("First name:", "Name"), ("Grid square:", "Grid"),
         ("State/Province:", "State"), ("Postal code:", "PostalCode")):
      if my.get(key) != SWITCH_STATION[caption]:
         failures.append("--wizard Create changed My." + key + ": " + repr(my.get(key)))

   text = log_text(root, run_name)
   facts["switch_log_lines"] = text.count(WIZARD_SWITCH_LOG)
   if facts["switch_log_lines"] != 2:
      failures.append("tr4w.log has " + str(facts["switch_log_lines"]) + " '" + WIZARD_SWITCH_LOG
         + "' line(s), expected 2")
   common_log_checks(root, run_name, facts, failures, 0)

   # 3. -h lists --wizard (and exits 0 without starting).
   app = switch_start(root, run_name, journal, owned, "start with -h", ["-h"])
   handle = watch_exit(app)
   dialog, usage = dialog_facts(app, "TR4W", timeout=30)
   facts["usage"] = usage
   body = "\n".join(usage["uia_texts"] + [item["text"] for item in usage["win32_texts"]])
   journal.perform("capture usage", lambda: capture(dialog, output / "usage.png"))
   if USAGE_WIZARD_LINE not in body.replace("\r\n", "\n"):
      failures.append("-h usage lacks " + repr(USAGE_WIZARD_LINE))
   click_dialog_button(app, dialog, "OK", journal)
   facts["usage_exit_code"] = exit_code(app, handle, journal)
   if facts["usage_exit_code"] != 0:
      failures.append("-h exit code " + str(facts["usage_exit_code"]))


# ------------------------------------- issue 322: the wizard keeps settings ----
#
# The wizard saves through SaveSettings, which writes the WHOLE settings object
# over the file's `settings` section. Before the fix the object had not been
# loaded when the wizard ran, so a Create wrote defaults over everything. These
# phases seed DISTINCTIVE values in several groups, run the wizard changing
# nothing it does not own, and diff the section as parsed JSON.

# Keys the wizard's Station page owns: it may rewrite these. Any other key that
# was in the file before and is changed or gone afterwards is a failure. Keys
# only in the AFTER file are expected -- the whole object is written, defaults
# and all -- and are counted, not judged.
WIZARD_OWNED = {"My.Call", "My.MainCallsign", "My.Name", "My.Grid", "My.State", "My.PostalCode",
   "My.Country", "My.Zone", "My.ItuZone"}
# Integers and strings only (no float to compare), each inside its type's range
# in uSettingsModel, none equal to its default, across seven groups. My.Iota is
# a My key the wizard does NOT own. Log.DebugLevel is left alone: the driver
# asserts Info lines.
DISTINCTIVE = {
   "Display": {"Language": "de"},
   "Cw": {"CodeSpeed": 42, "Tone": 650, "FarnsworthEnable": True},
   "Cq": {"AutoDelay": 2500},
   "BandMap": {"DecayTime": 45, "ItemWidth": 150},
   "MainWindow": {"RowCount": 9, "ShowGridlines": True},
   "Font": {"Size": 1, "Face": "Consolas"},
   "Log": {"ConfirmEditChanges": False},
   "My": {"Iota": "NA-001"},
}
# Issue 322 item 3: a settings section with NO callsign -- a language and a CW
# speed and nothing else.
PARTIAL = {"Display": {"Language": "de"}, "Cw": {"CodeSpeed": 42}}
# The New Contest caption in English or German: the form caption and the
# TC_OPENCONFIGURATIONFILE string are both translated in tr4w_de.po, and which
# one heads the window is recorded, not assumed.
NEW_CONTEST_ANY = (r".*(Open configuration file or start a new contest"
   r"|Konfigurationsdatei oeffnen oder neuen Contest starten"
   r"|Konfigurationsdatei oder starten Sie einen neuen Wettbewerb)")
CANCEL_CAPTIONS = ("Cancel", "Abbrechen")
LOG_TROUBLE = ("exception", "error", "eaccessviolation", "[crash]")


def file_sha256(path):
   import hashlib
   return hashlib.sha256(Path(path).read_bytes()).hexdigest() if Path(path).is_file() else None


def flatten(section, prefix=""):
   """{'Cw': {'CodeSpeed': 42}} -> {'Cw.CodeSpeed': 42}."""
   flat = {}
   for key, value in section.items():
      path = prefix + key
      if isinstance(value, dict):
         flat.update(flatten(value, path + "."))
      else:
         flat[path] = value
   return flat


def settings_diff(before, after):
   """The `settings` sections of two parsed files, compared key by key."""
   old = flatten((before or {}).get("settings", {}))
   new = flatten((after or {}).get("settings", {}))
   changed = {key: [old[key], new[key]] for key in old if key in new and new[key] != old[key]}
   removed = sorted(key for key in old if key not in new)
   added = sorted(key for key in new if key not in old)
   return {"changed": changed, "removed": removed, "added_count": len(added),
      "added_owned": {key: new[key] for key in added if key in WIZARD_OWNED}}


def judge_diff(diff, label, facts, failures):
   facts[label] = diff
   for key, (old, new) in sorted(diff["changed"].items()):
      if key not in WIZARD_OWNED:
         failures.append(label + ": " + key + " changed " + repr(old) + " -> " + repr(new))
   for key in diff["removed"]:
      if key not in WIZARD_OWNED:
         failures.append(label + ": " + key + " is gone")


def require_values(settings, wanted, label, failures):
   """Each seeded value is in the file as seeded."""
   flat = flatten((settings or {}).get("settings", {}))
   for key, value in sorted(flatten(wanted).items()):
      if flat.get(key) != value:
         failures.append(label + ": " + key + " is " + repr(flat.get(key)) + ", seeded " + repr(value))


def seed_settings(root, run_name, groups, replace, facts, label):
   """Write GROUPS into the run's settings section: merged over what is there,
   or (replace) as the whole section."""
   path = run_dir(root, run_name) / "tr4w.json"
   settings = json.loads(path.read_text(encoding="utf-8-sig"))
   if replace:
      settings["settings"] = json.loads(json.dumps(groups))
   else:
      section = settings.setdefault("settings", {})
      for group, values in groups.items():
         section.setdefault(group, {}).update(values)
   path.write_text(json.dumps(settings, indent=3), encoding="utf-8")
   facts[label] = settings
   return settings


def log_size(root, run_name):
   path = run_dir(root, run_name) / "tr4w.log"
   return path.stat().st_size if path.is_file() else 0


def log_since(root, run_name, offset):
   """The tr4w.log lines written since OFFSET (bytes): one start's own lines."""
   path = run_dir(root, run_name) / "tr4w.log"
   if not path.is_file():
      return ""
   with open(path, "rb") as stream:
      stream.seek(offset)
      return stream.read().decode("utf-8", errors="replace")


def judge_log(text, label, facts, failures):
   """Every Exception / Error / EAccessViolation / [CRASH] line, verbatim. The
   pre-fix logs of the same phases (suites 20261115T044202 and ...045548) have
   none, so any here is new."""
   lines = [line for line in text.splitlines() if any(word in line.lower() for word in LOG_TROUBLE)]
   facts[label + "_trouble_lines"] = lines
   facts[label + "_ui_language_lines"] = [line for line in text.splitlines() if "UI language:" in line]
   for line in lines:
      failures.append(label + ": tr4w.log line " + repr(line.strip()))


def new_contest_cancel(startup):
   """New Contest's Cancel in either language, by caption."""
   matches = [control for control in startup.descendants(class_name="Button")
      if control.is_visible() and control.window_text().replace("&", "") in CANCEL_CAPTIONS]
   if len(matches) != 1:
      raise AssertionError("New Contest Cancel not unique: " + repr([control.window_text() for control in matches]))
   return matches[0]


def start_in_stored_language(root, run_name, output, journal, facts, failures, owned, label, expect_call):
   """A plain start with NO --lang, so the stored Display.Language decides: the
   log line naming the language, New Contest's caption and Cancel (recorded),
   the callsign it offers, Cancel, exit 0, and this start's log lines judged."""
   offset = log_size(root, run_name)
   app = journal.perform(label, lambda: launch(root, run_name, "", lang=None))
   owned.append(app)
   (run_dir(root, run_name) / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   startup = wait_new_contest(app, journal, label, title_re=NEW_CONTEST_ANY)
   time.sleep(1.0)
   facts[label + "_asked"] = app.window(title="TR4W", visible_only=True).exists(timeout=0)
   facts[label + "_title"] = startup.window_text()
   cancel = new_contest_cancel(startup)
   facts[label + "_cancel_caption"] = cancel.window_text()
   facts[label + "_callsign"] = new_contest_callsign(startup).window_text()
   journal.perform("capture New Contest " + label, lambda: capture(startup, output / (label + "-new-contest.png")))
   if facts[label + "_asked"]:
      failures.append(label + ": a question was asked although a callsign is stored")
   if facts[label + "_callsign"] != expect_call:
      failures.append(label + ": New Contest callsign is " + repr(facts[label + "_callsign"]))
   handle = watch_exit(app)
   journal.perform("cancel New Contest " + label, cancel.click_input)
   facts[label + "_exit_code"] = exit_code(app, handle, journal)
   if facts[label + "_exit_code"] != 0:
      failures.append(label + ": exit code " + str(facts[label + "_exit_code"]))
   text = log_since(root, run_name, offset)
   judge_log(text, label, facts, failures)
   # The language in force: the log names it (primary), the caption shows it.
   if not any('"de"' in line for line in facts[label + "_ui_language_lines"]):
      failures.append(label + ": no 'UI language' line names \"de\": " + repr(facts[label + "_ui_language_lines"]))
   if re.search(NEW_CONTEST, facts[label + "_title"]):
      failures.append(label + ": New Contest is still English with Display.Language de: "
         + repr(facts[label + "_title"]))


def wizard_preserve(root, run_name, output, journal, facts, failures, incomplete, owned):
   """Issue 322: a set-up station whose settings hold DISTINCTIVE values in
   several groups. --wizard, change nothing, Next, Create configuration: every
   seeded value must survive; only Station keys may differ. Then a plain start
   (no --lang) must load the file normally with the language in force."""
   seed_station(root, run_name, facts)
   before = seed_settings(root, run_name, DISTINCTIVE, False, facts, "seeded_settings")
   settings_path = run_dir(root, run_name) / "tr4w.json"

   def wizard_pass(label, new_name=None):
      """--wizard; the stored station must be shown; optionally a new first
      name; Next, Create; the file read while New Contest is up and after exit."""
      offset = log_size(root, run_name)
      sha_before = file_sha256(settings_path)
      app = switch_start(root, run_name, journal, owned, label + ": start with --wizard", ["--wizard"])
      wizard = wait_wizard(app, journal, output, facts)
      shown = {caption: field_by_caption(wizard, caption).window_text() for caption in SWITCH_STATION}
      facts[label + "_station_shown"] = shown
      journal.perform("capture --wizard Station page", lambda: capture(wizard, output / (label + "-station.png")))
      if shown != SWITCH_STATION:
         raise AssertionError(label + ": --wizard Station page shows " + repr(shown) + ", stored "
            + repr(SWITCH_STATION))
      if new_name:
         set_box(field_by_caption(wizard, "First name:"), new_name, journal, "First name")
      next_page(wizard, "Next >", journal)
      boxes = {caption: button(wizard, caption).get_check_state()
         for caption in ("A radio (rig control)", "A WinKeyer", "A DX cluster")}
      facts[label + "_checklist_boxes"] = boxes
      if any(boxes.values()):
         raise AssertionError(label + ": a checklist box starts ticked: " + repr(boxes))
      next_page(wizard, "Create configuration", journal)
      finish_result_page(app, wizard, output, journal, facts, failures, call=SWITCH_CALL)
      facts[label + "_result_text"] = facts["result_text"]
      # Read the moment the wizard has closed, before New Contest: the write
      # (if any) is then the wizard's own, not the later startup's.
      saved = {"wizard": read_settings(root, run_name)}
      facts[label + "_written_by_wizard"] = file_sha256(settings_path) != sha_before

      def snapshot():
         saved["open"] = read_settings(root, run_name)
         saved["sha_open"] = file_sha256(settings_path)

      switch_new_contest(app, output, journal, facts, failures, label, while_open=snapshot)
      saved["exit"] = read_settings(root, run_name)
      facts[label + "_file_written"] = saved["sha_open"] != sha_before
      facts[label + "_file_changed_at_exit"] = file_sha256(settings_path) != saved["sha_open"]
      judge_log(log_since(root, run_name, offset), label, facts, failures)
      return saved

   # A. Nothing changed. CommitStation writes only a field that changed, so
   # this pass must leave the file alone -- recorded, and diffed anyway.
   saved = wizard_pass("pass-a-unchanged")
   judge_diff(settings_diff(before, saved["open"]), "diff_seeded_to_pass_a", facts, failures)
   require_values(saved["open"], DISTINCTIVE, "after pass A", failures)
   if facts["pass-a-unchanged_file_written"]:
      facts["pass_a_note"] = "the file WAS written although nothing changed"

   # B. One owned field changed, so the save -- the whole settings object over
   # the section -- really happens. THIS is the issue 322 risk.
   saved_b = wizard_pass("pass-b-name", new_name="Percy")
   if not facts["pass-b-name_file_written"]:
      failures.append("pass B: changing First name did not write tr4w.json, so the save path was not exercised")
   judge_diff(settings_diff(saved["exit"], saved_b["wizard"]), "diff_pass_a_to_pass_b_wizard_save", facts, failures)
   require_values(saved_b["wizard"], DISTINCTIVE, "pass B, the wizard's own save", failures)
   judge_diff(settings_diff(saved["exit"], saved_b["open"]), "diff_pass_a_to_pass_b", facts, failures)
   judge_diff(settings_diff(saved_b["open"], saved_b["exit"]), "diff_pass_b_open_to_exit", facts, failures)
   require_values(saved_b["open"], DISTINCTIVE, "after pass B", failures)
   name = flatten(saved_b["open"].get("settings", {})).get("My.Name")
   if name != "Percy":
      failures.append("pass B: My.Name is " + repr(name) + ", typed 'Percy'")
   facts["after_pass_b_settings"] = saved_b["exit"]

   # C. A plain start on that file: loads normally, the language in force.
   start_in_stored_language(root, run_name, output, journal, facts, failures, owned, "second-start", SWITCH_CALL)
   after_second = read_settings(root, run_name)
   judge_diff(settings_diff(saved_b["exit"], after_second), "diff_pass_b_to_second_start", facts, failures)
   require_values(after_second, DISTINCTIVE, "after the second start", failures)
   facts["after_second_start_settings"] = after_second


def wizard_partial(root, run_name, output, journal, facts, failures, incomplete, owned):
   """Issue 322: a settings file holding ONLY a language and a CW speed (no
   callsign) and no --wizard. The offer appears; Yes; the station typed (the
   four lookup boxes first, so no callbook lookup); Create. The language and
   the CW speed must survive in the saved file."""
   before = seed_settings(root, run_name, PARTIAL, True, facts, "seeded_settings")
   offset = log_size(root, run_name)
   app = start_again(root, run_name, journal, "start with a partial settings file (no callsign)")
   owned.append(app)
   answer_offer(app, "Yes", output, journal, facts, failures)
   wizard = wait_wizard(app, journal, output, facts)
   station_page(wizard, output, journal, facts, failures)
   next_page(wizard, "Next >", journal)
   if not has_button(wizard, "Create configuration"):
      raise AssertionError("With nothing ticked the checklist's Next does not read Create configuration")
   next_page(wizard, "Create configuration", journal)
   finish_result_page(app, wizard, output, journal, facts, failures)
   # The wizard's own save, read before New Contest (and the later startup).
   by_wizard = read_settings(root, run_name)
   judge_diff(settings_diff(before, by_wizard), "diff_seeded_to_wizard_save", facts, failures)
   require_values(by_wizard, PARTIAL, "the wizard's own save", failures)
   settings = after_wizard(app, root, run_name, output, journal, facts, failures, CALL)
   check_station_settings(settings, failures, True)
   judge_diff(settings_diff(before, settings), "diff_seeded_to_after_create", facts, failures)
   require_values(settings, PARTIAL, "after Create", failures)
   facts["after_create_settings"] = read_settings(root, run_name)
   judge_log(log_since(root, run_name, offset), "wizard_start", facts, failures)
   common_log_checks(root, run_name, facts, failures, 1)


NOT_FOUND = "TR4W could not find this file:"
FOLDER_MISSING = "The folder is missing too, so this copy of TR4W is probably not completely installed."


def install_dom(root, run_name, output, journal, facts, failures, incomplete, owned):
   """A stored station in a folder with CTY.DAT and TRMASTER.DTA but no dom.
   1. No contest argument: the install warning names dom\\ ALONE (the dom
      branch of the rule), then New Contest; Cancel.
   2. The Michigan QP log on the command line (which skips the startup check):
      its domestic file is looked for in the absent dom folder, so 'could not
      find this file' must add 'The folder is missing too'. Every TR4W notice
      met on the way is recorded; only OK is ever pressed, and an unclassified
      question stops the case."""
   folder = run_dir(root, run_name)
   if (folder / "dom").exists():
      raise RuntimeError("install-dom needs a run folder without dom")
   databases = list(folder.glob("*.db"))
   if len(databases) != 1:
      raise RuntimeError("install-dom needs exactly one contest log")
   seed_station(root, run_name, facts)

   app = switch_start(root, run_name, journal, owned, "start with no contest (no dom folder)", [])
   switch_new_contest(app, output, journal, facts, failures, "no-dom")

   app = journal.perform("open the Michigan QP log", lambda: launch(root, run_name, databases[0].name))
   owned.append(app)
   handle = watch_exit(app)
   (folder / "bench-workflow.json").write_text(json.dumps({"pid": app.process}), encoding="utf-8")
   # The main window is titled plain 'TR4W' until the contest is loaded, so the
   # notices (message boxes, #32770) are told apart by class.
   main = app.window(title_re=r"TR4W( v.*)?", class_name="Window", visible_only=True)
   notices = []
   deadline = time.monotonic() + 60
   quiet_since = None
   # LogCfg HALTS when the domestic file cannot be loaded (observed 2026-11-15:
   # one notice, then a normal exit) -- so the process ending is an outcome
   # here, recorded with its exit code, not an error.
   while time.monotonic() < deadline and app.is_process_running():
      if app.window(title="TR4W", class_name="#32770", visible_only=True).exists(timeout=0):
         quiet_since = None
         dialog, notice = dialog_facts(app, "TR4W", timeout=5, class_name="#32770")
         body = "\n".join(notice["uia_texts"] + [item["text"] for item in notice["win32_texts"]])
         notice["body"] = body
         notices.append(notice)
         capture(dialog, output / ("open-notice-" + str(len(notices)) + ".png"))
         if [name.replace("&", "") for name in notice["answers"]] != ["OK"]:
            facts["open_notices"] = notices
            raise AssertionError("A question while opening the log (not answered): " + repr(body))
         click_dialog_button(app, dialog, "OK", journal)
         continue
      if main.exists(timeout=0) and main.is_enabled() and main.window_text().startswith("TR4W v"):
         quiet_since = quiet_since or time.monotonic()
         if time.monotonic() - quiet_since > 3:
            break
      time.sleep(0.2)
   facts["open_notices"] = notices
   # The file is the contest's own choice (michigan_cty.dom for an out-of-state
   # entrant); what matters is that it is a .dom in the run's absent dom folder.
   absent = str(folder / "dom").casefold() + "\\"
   matches = [notice for notice in notices if NOT_FOUND in notice["body"]
      and absent in notice["body"].casefold() and ".dom" in notice["body"].casefold()]
   if len(matches) != 1:
      failures.append("Expected one '" + NOT_FOUND + "' notice naming a .dom in " + absent + ", saw "
         + repr([notice["body"] for notice in notices]))
   elif FOLDER_MISSING not in matches[0]["body"].replace("\r\n", " ").replace("\n", " "):
      failures.append("The not-found notice lacks '" + FOLDER_MISSING + "': " + repr(matches[0]["body"]))
   if app.is_process_running():
      if not main.exists(timeout=0):
         raise AssertionError("Neither the main window nor an exit after the notices")
      main = app.window(handle=main.handle)
      facts["main_title"] = main.window_text()
      journal.perform("capture main window", lambda: capture(main, output / "miqp-main.png"))
      close_normally(app, main, journal)
   facts["miqp_exit_code"] = exit_code(app, handle, journal)
   facts["miqp_exited_after_notice"] = facts.get("main_title") is None
   text = log_text(root, run_name)
   facts["crash_marker"] = "[CRASH]" in text
   if facts["crash_marker"]:
      failures.append("tr4w.log has a [CRASH] marker")
   install_log_checks(text, facts, failures)



PHASES = {
   "bench-wizard-switch": wizard_switch,
   "bench-wizard-preserve": wizard_preserve,
   "bench-wizard-partial": wizard_partial,
   "bench-install-dom": install_dom,
   "bench-wizard-done-serial": radio_done_serial,
   "bench-wizard-done-network": radio_done_network,
   "bench-wizard-callbook": callbook,
   "bench-wizard-tools-keyer": tools_keyer,
   "bench-wizard-cty-download": cty_download,
   "bench-wizard-offer-no": offer_no,
   "bench-wizard-station": station_only,
   "bench-wizard-station-empty": station_empty_folder,
   "bench-wizard-hardware": hardware,
   "bench-wizard-tools": tools_menu,
}


def run(root, run_name, output, journal, phase):
   root = Path(root)
   facts = {"phase": phase, "fixture": json.loads((run_dir(root, run_name) / "fixture.json").read_text(encoding="utf-8")),
      "staged_files": sorted(path.name for path in run_dir(root, run_name).iterdir())}
   failures = []
   incomplete = []
   owned = []
   INSTALL_CHECK.clear()
   INSTALL_CHECK.update({"root": root, "run_name": run_name, "output": output, "failures": failures,
      "records": []})
   try:
      OCCLUDED_PRESSES.clear()
      PHASES[phase](root, run_name, output, journal, facts, failures, incomplete, owned)
      # A button the operator could not have reached is a failure on ANY page,
      # measured or not: the message fallback only keeps the case going.
      for caption in sorted({press_record["caption"] for press_record in OCCLUDED_PRESSES}):
         failures.append("'" + caption + "' was outside the screen's work area and had to be pressed by message")
   except BaseException:
      app = owned[-1] if owned else None
      if app is not None and app.is_process_running():
         try:
            describe_windows(app, output)
            capture(app.top_window(), output / "failure.png")
         except Exception as error:
            (output / "diagnostic-error.txt").write_text(repr(error), encoding="utf-8")
         if "[CRASH] LCL: unhandled" not in log_text(root, run_name):
            app.kill()
      raise
   finally:
      # Kept even when the phase raises, so an assertion recorded before the
      # exception is still in the evidence.
      facts["install_check"] = INSTALL_CHECK.get("records", [])
      facts["failures_recorded"] = list(failures)
      facts["occluded_presses"] = list(OCCLUDED_PRESSES)
      (output / "wizard-facts.json").write_text(json.dumps(facts, indent=3, default=str), encoding="utf-8")
   result = {"passed": not failures and not incomplete, "failures": failures,
      "note": "Setup wizard " + phase + "; see wizard-facts.json"}
   if incomplete:
      result["incomplete"] = incomplete
   return result
