"""Run isolated, repeatable Windows GUI regression cases through sequential SSH."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import uuid
import zipfile

from stage_main_build import DEFAULT_EXE, GUEST_PYTHON, stage
from vm_run import remote, ps_quote
from fixture_data import snapshot_corpus_log


CASES = {
   "seed": "bench-seed",
   "hints": "bench-prefs-hints",
   "focus": "bench-prefs-focus",
   "online": "bench-prefs-online",
   "loggers": "bench-prefs-loggers",
   "radio": "bench-prefs-radio",
   "search": "bench-search-regression",
   "switch": "bench-switch-regression",
   "locked": "bench-locked-regression",
   "import": "bench-import-regression",
   "messages": "bench-messages-regression",
   "wizard-no": "bench-wizard-offer-no",
   "wizard-station": "bench-wizard-station",
   "wizard-empty": "bench-wizard-station-empty",
   "wizard-hardware": "bench-wizard-hardware",
   "wizard-tools": "bench-wizard-tools",
   "wizard-done-serial": "bench-wizard-done-serial",
   "wizard-done-network": "bench-wizard-done-network",
   # Reaches country-files.com over HTTPS from the guest; select it explicitly.
   "wizard-download": "bench-wizard-cty-download",
   # Reaches api.hamdb.org over HTTPS (the callsign only); select it explicitly.
   "wizard-callbook": "bench-wizard-callbook",
   # OPENS THE GUEST'S LIVE WINKEYER on COM3 (no CW is sent); select it explicitly.
   "wizard-keyer": "bench-wizard-tools-keyer",
   # --wizard on a station that already has a callsign, and -h listing it.
   "wizard-switch": "bench-wizard-switch",
   # Issue 322: distinctive settings survive --wizard + Create; a start with no
   # --lang then loads them (the stored language in force).
   "wizard-preserve": "bench-wizard-preserve",
   # Issue 322: a settings file with no callsign: the offer, Yes, Create; the
   # language and CW speed it held survive.
   "wizard-partial": "bench-wizard-partial",
   # A stored station in a folder with no dom: the startup install warning
   # naming dom\ alone, then a dom-using contest's "could not find" message.
   "install-dom": "bench-install-dom",
}

# Cases that start as a BRAND-NEW INSTALL: no settings file and no contest log
# (prepare_fixture --fresh-install), with what an installed copy has in its
# folder: CTY.DAT, dom, TRMASTER.DTA and TRCLUSTER.DAT.
FRESH_INSTALL_CASES = {"wizard-no", "wizard-station", "wizard-empty", "wizard-hardware", "wizard-download",
   "wizard-callbook", "wizard-done-serial", "wizard-done-network"}
# ...and of those, the ones whose working folder holds no data files at all.
EMPTY_FOLDER_CASES = {"wizard-empty", "wizard-download"}
# Ordinary (settings-template) cases that get the full installed data set too.
INSTALL_DATA_CASES = {"wizard-switch", "wizard-preserve", "wizard-partial", "install-dom"}
# Cases with no contest log: a contest on the command line skips the startup
# offer and install check, so these start with no argument.
NO_DATABASE_CASES = {"wizard-switch", "wizard-preserve", "wizard-partial"}
# Installed parts deliberately left out, so the startup install check
# (uProgramMain.WarnIfInstallIncomplete) meets each branch of its rule: a lone
# missing CTY.DAT and a lone missing TRMASTER.DTA must NOT warn, dom alone must.
OMIT_PARTS = {"wizard-no": ["CTY.DAT"], "wizard-callbook": ["TRMASTER.DTA"], "install-dom": ["dom"]}
SCP_MASTER = "TRMASTER.DTA"
# A contest that loads a domestic (dom\) file, from the golden corpus, copied
# with SQLite's backup API (the corpus log has -wal/-shm siblings a plain copy
# would miss). The corpus file itself is only read.
DOM_CONTEST_LOG = Path(__file__).resolve().parents[2] / "tr4w/test/corpus/michigan_qp_2026_ny4i/log.db"
DOM_CONTEST_DB = "MIQP-dom.db"
# Cases that leave the guest for the internet or open real hardware: never part
# of the default run.
OPT_IN_CASES = {"wizard-download", "wizard-callbook", "wizard-keyer"}
# The public cluster list the DX cluster pickers read. On Windows it is found
# in the WORKING folder (DataFilePath), the shipped tier CTY.DAT and dom come
# from, so it is staged into each run folder with them (prepare_fixture).
CLUSTER_LIST = "TRCLUSTER.DAT"


def run_python(args, script, arguments):
   command = "& " + " ".join(ps_quote(str(value)) for value in (args.python, script, *arguments))
   return remote(args.host, "$ErrorActionPreference='Stop'; " + command +
      "; if($LASTEXITCODE -ne 0){throw 'Remote Python command failed'}")


def install(args, metadata, output):
   root = metadata["vm_root"]
   executable = root + r"\app\tr4w_fpc.exe"
   info = json.loads(remote(args.host, "$p=" + ps_quote(executable) +
      "; if(Test-Path -LiteralPath $p){@{exists=$true;sha=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash} | ConvertTo-Json -Compress}"
      "else{@{exists=$false} | ConvertTo-Json -Compress}"))
   if info["exists"] and info["sha"].lower() != metadata["sha256"]:
      raise RuntimeError("Existing VM snapshot hash differs; refusing to overwrite it")
   if not info["exists"]:
      incoming = "C:/TR4W-Test/incoming-" + metadata["sha256"][:12] + ".zip"
      subprocess.run(["scp", "-o", "ConnectTimeout=60", metadata["archive"], args.host + ":" + incoming], check=True)
      remote(args.host, "$ErrorActionPreference='Stop'; New-Item -ItemType Directory " + ps_quote(root) +
         " | Out-Null; Expand-Archive " + ps_quote(incoming) + " " + ps_quote(root) +
         "; icacls " + ps_quote(root) + " /grant 'gui-test:(OI)(CI)M' /T | Out-Null")
   data_root = args.data_root or args.exe.resolve().parents[2] / "tr4w/target"
   if not (data_root / "CTY.DAT").is_file() or not (data_root / "dom").is_dir():
      raise RuntimeError("--data-root must contain CTY.DAT and dom")
   cluster_list = next((path for path in data_root.iterdir() if path.name.lower() == CLUSTER_LIST.lower()), None)
   if cluster_list is None:
      raise RuntimeError("--data-root lacks " + CLUSTER_LIST)
   master = next((path for path in data_root.iterdir() if path.name.lower() == SCP_MASTER.lower()), None)
   if master is None:
      raise RuntimeError("--data-root lacks " + SCP_MASTER)
   dom_contest_db = snapshot_corpus_log(DOM_CONTEST_LOG, output / DOM_CONTEST_DB)
   archive = output / "fixtures.zip"
   with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as bundle:
      fixture_source = Path(__file__).parent / "fixtures"
      for path in fixture_source.rglob("*"):
         if path.is_file():
            bundle.write(path, path.relative_to(fixture_source))
      bundle.write(data_root / "CTY.DAT", "CTY.DAT")
      bundle.write(cluster_list, CLUSTER_LIST)
      bundle.write(master, SCP_MASTER)
      bundle.write(dom_contest_db, DOM_CONTEST_DB)
      for path in (data_root / "dom").rglob("*"):
         if path.is_file():
            bundle.write(path, path.relative_to(data_root))
   incoming = "C:/TR4W-Test/fixtures-" + output.name + ".zip"
   subprocess.run(["scp", "-o", "ConnectTimeout=60", str(archive), args.host + ":" + incoming], check=True)
   fixture_root = root + "\\fixtures\\" + output.name
   remote(args.host, "$ErrorActionPreference='Stop'; New-Item -ItemType Directory " + ps_quote(fixture_root) +
      " | Out-Null; Expand-Archive " + ps_quote(incoming) + " " + ps_quote(fixture_root) +
      "; icacls " + ps_quote(fixture_root) + " /grant 'gui-test:(OI)(CI)M' /T | Out-Null")
   subprocess.run(["scp", "-o", "ConnectTimeout=60", str(Path(__file__).parent / "prepare_fixture.py"),
      args.host + ":C:/TR4W-Test/readiness/"], check=True)
   return fixture_root


def prepare(args, root, fixture_root, run_name, database=None, fresh_install=False, no_data=False,
      install_data=False, omit=()):
   arguments = ["--root", root, "--run", run_name, "--assets-template", fixture_root]
   if fresh_install:
      arguments += ["--fresh-install"]
      if no_data:
         arguments += ["--no-data"]
   else:
      arguments += ["--settings-template", fixture_root + r"\tr4w.json"]
      if install_data:
         arguments += ["--install-data"]
   for part in omit:
      arguments += ["--omit", part]
   if database:
      arguments += ["--database-template", database]
   run_python(args, r"C:\TR4W-Test\readiness\prepare_fixture.py", arguments)


def run_case(args, root, run_name, case, output):
   phase = CASES[case]
   directory = output / case
   command = [sys.executable, str(Path(__file__).parent / "vm_run.py"), phase,
      "--host", args.host, "--python", args.python, "--root", root, "--run", run_name,
      "--output", str(directory)]
   directory.mkdir(parents=True, exist_ok=True)
   with (directory / "runner.log").open("w", encoding="utf-8") as stream:
      process = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
   path = directory / phase / "result.json"
   if not path.is_file():
      return {"case": case, "status": "ERROR", "reason": "No result from worker", "exit_code": process.returncode}
   result = json.loads(path.read_text(encoding="utf-8"))
   if result.get("run") != run_name:
      return {"case": case, "status": "ERROR", "reason": "Result belongs to a different fixture"}
   if result.get("status") == "INSPECTED":
      return {"case": case, "status": "ERROR", "reason": "Inspection is not regression acceptance"}
   if result.get("incomplete"):
      # Part of the case could not run here (e.g. no serial port on the guest):
      # no reliable verdict, so ERROR (exit 2), never PASS.
      return {"case": case, "status": "ERROR", "exit_code": process.returncode, "result": str(path),
         "reason": "INCOMPLETE: " + "; ".join(result["incomplete"]),
         "failures": result.get("failures", []), "note": result.get("note")}
   passed = process.returncode == 0 and result.get("passed") is True
   error = result.get("error")
   status = "PASS" if passed else ("ERROR" if error and "AssertionError:" not in error else "FAIL")
   return {"case": case, "status": status, "exit_code": process.returncode,
      "result": str(path), "error": result.get("error"), "failures": result.get("failures", []),
      "note": result.get("note")}


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--exe", type=Path, default=DEFAULT_EXE)
   parser.add_argument("--data-root", type=Path)
   parser.add_argument("--host", default="tr4w-gui-test")
   parser.add_argument("--python", default=GUEST_PYTHON, help="guest Python (64-bit; must match the app)")
   parser.add_argument("--output", type=Path, default=Path("build-out/gui-regression"))
   parser.add_argument("--case", action="append", choices=CASES)
   parser.add_argument("--list", action="store_true")
   args = parser.parse_args()
   if args.list:
      print("\n".join(CASES))
      return 0
   identifier = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:6]
   output = (args.output / identifier).resolve()
   output.mkdir(parents=True)
   selected = list(dict.fromkeys(args.case or [case for case in CASES if case not in OPT_IN_CASES]))
   summary = {"suite": identifier, "requested_cases": selected, "cases": [], "status": "RUNNING"}

   def save():
      (output / "summary.json").write_text(json.dumps(summary, indent=3), encoding="utf-8")

   save()
   try:
      metadata = stage(args.exe, output / "build")
      summary["build"] = metadata
      fixture_root = install(args, metadata, output)
      root = metadata["vm_root"]
      seed_run = "suite-" + identifier + "-seed"
      prepare(args, root, fixture_root, seed_run)
      result = run_case(args, root, seed_run, "seed", output)
      summary["cases"].append(result)
      save()
      print("seed: " + result["status"], flush=True)
      if result["status"] != "PASS":
         raise RuntimeError("Seed fixture did not pass; dependent cases cannot run")
      databases = json.loads(remote(args.host, "$files=@((Get-ChildItem -LiteralPath " +
         ps_quote(root + "\\runs\\" + seed_run) + " -Filter '*.db').FullName); ConvertTo-Json -InputObject $files -Compress"))
      if not isinstance(databases, list) or len(databases) != 1:
         raise RuntimeError("Seed did not produce exactly one database")
      for case in selected:
         if case == "seed":
            continue
         run_name = "suite-" + identifier + "-" + case
         try:
            omit = OMIT_PARTS.get(case, ())
            if case in FRESH_INSTALL_CASES:
               prepare(args, root, fixture_root, run_name, fresh_install=True,
                  no_data=case in EMPTY_FOLDER_CASES, omit=omit)
            elif case in NO_DATABASE_CASES:
               prepare(args, root, fixture_root, run_name, install_data=case in INSTALL_DATA_CASES, omit=omit)
            elif case == "install-dom":
               # The dom-using contest log instead of the seed's CW Open.
               prepare(args, root, fixture_root, run_name, fixture_root + "\\" + DOM_CONTEST_DB,
                  install_data=case in INSTALL_DATA_CASES, omit=omit)
            else:
               prepare(args, root, fixture_root, run_name, databases[0])
            result = run_case(args, root, run_name, case, output)
         except Exception as error:
            result = {"case": case, "status": "ERROR", "reason": str(error)}
         summary["cases"].append(result)
         save()
         print(case + ": " + result["status"], flush=True)
      summary["status"] = "ERROR" if any(x["status"] == "ERROR" for x in summary["cases"]) else (
         "FAIL" if any(x["status"] == "FAIL" for x in summary["cases"]) else "PASS")
   except Exception as error:
      summary["status"] = "ERROR"
      summary["error"] = str(error)
   save()
   print(str(output / "summary.json"), flush=True)
   return {"PASS": 0, "FAIL": 1, "ERROR": 2}[summary["status"]]


if __name__ == "__main__":
   raise SystemExit(main())
