"""Run isolated, repeatable Windows GUI regression cases through sequential SSH."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys
import uuid
import zipfile

from stage_main_build import DEFAULT_EXE, guest_python_for, stage
from vm_run import remote, ps_quote


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
}


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
   archive = output / "fixtures.zip"
   with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as bundle:
      fixture_source = Path(__file__).parent / "fixtures"
      for path in fixture_source.rglob("*"):
         if path.is_file():
            bundle.write(path, path.relative_to(fixture_source))
      bundle.write(data_root / "CTY.DAT", "CTY.DAT")
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


def prepare(args, root, fixture_root, run_name, database=None):
   arguments = ["--root", root, "--run", run_name, "--settings-template", fixture_root + r"\tr4w.json",
      "--assets-template", fixture_root]
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
   parser.add_argument("--python", default=None, help="guest Python; default follows the app's bitness")
   parser.add_argument("--output", type=Path, default=Path("build-out/gui-regression"))
   parser.add_argument("--case", action="append", choices=CASES)
   parser.add_argument("--list", action="store_true")
   args = parser.parse_args()
   if args.python is None:
      args.python = guest_python_for(args.exe)
   if args.list:
      print("\n".join(CASES))
      return 0
   identifier = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:6]
   output = (args.output / identifier).resolve()
   output.mkdir(parents=True)
   selected = list(dict.fromkeys(args.case or list(CASES)))
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
