"""Live K4 checks on the owned CW Open log: link, displayed state, gated CW by CAT.

The K4 (192.168.73.108:9200) is the only radio available. NY4I put it in TX
test mode for these runs; the CW phase additionally refuses to send unless the
radio ITSELF reports TX test (TS1, shown by TR4W as "TX INHIBITED: TX test
mode"), so safety never rests on the statement alone. Nothing here tunes the
radio or changes its mode. Beyond TR4W's own link-up reads and polling, the
radio receives the profile's startup command (here `KY <;`) at every connect,
including after Reset Radio Ports, and, in the CW phase only, the F1 message.
"""

import json
import re
import time

from session import capture, describe_windows, menu_paths


CONNECTED = "Connected successfully to network radio"
# The radio's own TS1 answer, logged at idle by TFactoryRadioBase.SetTXInhibited.
# The on-screen "TX INHIBITED" sentence appears only on a key-up, so it cannot
# gate a send that has not happened yet.
TX_TEST_LOG = "[TX inhibit] ON -- the radio reports: TX test mode"
TX_TEST = "TX INHIBITED"
KEYED_INHIBITED_LOG = "is keyed and reports TX inhibited"


def log_text(root, run_name):
   path = root / "runs" / run_name / "tr4w.log"
   return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def wait_for_log(root, run_name, needle, timeout):
   deadline = time.monotonic() + timeout
   while time.monotonic() < deadline:
      if needle in log_text(root, run_name):
         return True
      time.sleep(0.25)
   return False


def texts(window):
   rows = []
   for control in window.descendants():
      if control.is_visible() and control.window_text().strip():
         rect = control.rectangle()
         rows.append({"text": control.window_text(), "class": control.class_name(),
            "rect": [rect.left, rect.top, rect.right, rect.bottom]})
   return rows


def wait_for_text(window, needle, timeout):
   deadline = time.monotonic() + timeout
   while time.monotonic() < deadline:
      found = [row for row in texts(window) if needle in row["text"]]
      if found:
         return found
      time.sleep(0.25)
   return []


def frequency_like(rows):
   # Frequency and band/mode cells as displayed; kept raw for review, not parsed
   # into a number the display may not mean.
   pattern = re.compile(r"\d{3,6}[.,]\d|\b\d{1,3}(CW|SSB|USB|LSB|DIG|FM|AM|RTTY)\b|\bCW\b|SSB|LSB|USB")
   return [row for row in rows if pattern.search(row["text"])]


def observe(app, main, root, run_name, output, journal):
   observations = {}
   started = time.monotonic()
   connected = journal.perform("wait for K4 network connect in tr4w.log",
      lambda: wait_for_log(root, run_name, CONNECTED, 45))
   observations["connected"] = connected
   observations["connect_seconds_after_main"] = round(time.monotonic() - started, 2)
   if not connected:
      capture(main, output / "k4-not-connected.png")
      raise AssertionError("K4 link did not report connected within 45 s")
   observations["tx_test_reported_by_radio"] = journal.perform("wait for the K4's own TX test report (TS1)",
      lambda: wait_for_log(root, run_name, TX_TEST_LOG, 20))
   observations["tx_test_display_idle"] = wait_for_text(main, TX_TEST, 1)
   samples = []
   for index in range(8):
      samples.append({"t": round(time.monotonic() - started, 2), "cells": frequency_like(texts(main))})
      time.sleep(1)
   observations["display_samples"] = samples
   capture(main, output / "k4-main.png")
   # "Radio 1" is also under Windows->Dupesheet; the radio display is the item
   # directly under Windows, so choose by depth from the actual menu.
   entries = [entry for entry in menu_paths(main) if len(entry["path"].split("->")) == 2
      and entry["path"].replace("&", "").startswith("Windows->Radio 1")]
   if len(entries) != 1 or not entries[0]["enabled"]:
      raise RuntimeError("Windows->Radio 1 not unique/enabled: " + repr(entries))
   journal.perform("menu " + entries[0]["path"], lambda: main.menu_select(entries[0]["path"]))
   radio = app.window(title_re=r"Radio 1.*")
   journal.perform("wait for Radio 1 window", lambda: radio.wait("visible", timeout=10))
   time.sleep(1.5)
   observations["radio_window_title"] = radio.window_text()
   observations["radio_window_texts"] = texts(radio)
   capture(radio, output / "k4-radio-window.png")
   observations["main_texts_final"] = texts(main)
   observations["split_or_vfo_cells"] = [row for row in observations["main_texts_final"] + observations["radio_window_texts"]
      if re.search(r"split|vfo|\bA\b|\bB\b|RIT|XIT", row["text"], re.IGNORECASE)]
   main.set_focus()
   return observations


def check(app, main, root, run_name, output, journal, phase):
   observations = observe(app, main, root, run_name, output, journal)
   result = {"passed": True, "phase": phase}
   if phase == "bench-k4-cw":
      if not observations["tx_test_reported_by_radio"]:
         (output / "k4-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
         raise AssertionError("NOT RUN: the K4 did not report TX test (no TS1 log line); refusing to send CW")
      modes = [row["text"] for row in observations["main_texts_final"] if re.fullmatch(r"\s*\d{1,3}(CW|SSB|DIG|FM|AM)\s*", row["text"])]
      observations["band_mode_cells"] = modes
      if not any(text.strip().endswith("CW") for text in modes):
         (output / "k4-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
         raise AssertionError("NOT RUN: the displayed mode is not CW, and this phase does not change the radio's mode")
      before = len(log_text(root, run_name))
      journal.perform("focus main window", main.set_focus)
      sent_at = time.monotonic()
      journal.perform("press F1 (CQ memory) in CQ mode", lambda: main.type_keys("{F1}"))
      time.sleep(1.0)
      capture(main, output / "k4-cw-sending.png")
      observations["texts_while_sending"] = texts(main)
      observations["inhibit_cells_while_sending"] = [row for row in observations["texts_while_sending"]
         if row["text"].strip() in {"INH", "ON", "OFF"} or TX_TEST in row["text"]]
      # Let a CQ finish at the configured speed, then read what was handed to the radio.
      time.sleep(12)
      capture(main, output / "k4-cw-after.png")
      tail = log_text(root, run_name)[before:]
      observations["log_after_f1"] = [line for line in tail.splitlines()
         if re.search(r"KY|CWByCAT|SendCW|SendToRadio|TX inhibit", line)][:200]
      observations["keyed_inhibited_logged"] = any(KEYED_INHIBITED_LOG in line for line in observations["log_after_f1"])
      observations["seconds_observed_after_f1"] = round(time.monotonic() - sent_at, 2)
      # uRadioKYBase logs every CW-by-CAT hand-off as "[<model>.SendCW] Sending CW: ..."
      if not any("SendCW] Sending CW" in line for line in observations["log_after_f1"]):
         result["passed"] = False
         result["failures"] = ["No '[...SendCW] Sending CW' line in tr4w.log after F1"]
      # A TR4W-initiated teardown and rebuild (Reset Radio Ports). It is NOT a
      # link drop by the radio or the network; that one needs a human.
      connects_before = log_text(root, run_name).count(CONNECTED)
      entries = [entry for entry in menu_paths(main) if "Reset Radio Ports" in entry["path"].replace("&", "")]
      if len(entries) != 1 or not entries[0]["enabled"]:
         raise RuntimeError("Reset Radio Ports not unique/enabled: " + repr(entries))
      reset_at = time.monotonic()
      journal.perform("menu " + entries[0]["path"], lambda: main.menu_select(entries[0]["path"]))
      deadline = time.monotonic() + 30
      while time.monotonic() < deadline and log_text(root, run_name).count(CONNECTED) <= connects_before:
         time.sleep(0.25)
      reconnected = log_text(root, run_name).count(CONNECTED) > connects_before
      observations["reset_radio_ports"] = {"menu": entries[0]["path"], "reconnected": reconnected,
         "seconds": round(time.monotonic() - reset_at, 2)}
      time.sleep(3)
      observations["display_after_reset"] = [row["text"] for row in frequency_like(texts(main))]
      capture(main, output / "k4-after-reset.png")
      if not reconnected:
         result["passed"] = False
         result.setdefault("failures", []).append("No second 'Connected successfully' within 30 s of Reset Radio Ports")
   describe_windows(app, output)
   (output / "k4-observations.json").write_text(json.dumps(observations, indent=3), encoding="utf-8")
   result["note"] = "Live K4 observations in k4-observations.json; exit timing is in steps.jsonl"
   return result
