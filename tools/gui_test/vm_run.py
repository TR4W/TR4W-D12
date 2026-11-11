"""Upload Python scenarios and run them in GUI-TEST's existing desktop via SSH."""

import argparse
import base64
import json
import subprocess
import time
from pathlib import Path


def ps_quote(value):
   return "'" + value.replace("'", "''") + "'"


def remote(host, script):
   encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
   process = subprocess.run(
      ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=60", host,
       "powershell.exe", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded],
      capture_output=True, text=True, timeout=120,
   )
   if process.returncode:
      raise RuntimeError(process.stdout + process.stderr)
   return process.stdout.strip()


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("scenario", choices=["preferences", "preferences-audit", "station-hints", "new-contest", "cw-open", "cw-open-qso", "cw-open-collision"])
   parser.add_argument("--host", default="tr4w-gui-test")
   parser.add_argument("--run", default="pilot-001")
   parser.add_argument("--output", type=Path, required=True)
   args = parser.parse_args()
   if not args.run.replace("-", "").isalnum():
      raise ValueError("Run name must contain only letters, digits and hyphens")
   source = Path(__file__).resolve().parent
   subprocess.run(
      ["scp", "-o", "ConnectTimeout=60", str(source / "session.py"),
       str(source / "scenarios.py"), str(source / "preferences_audit.py"),
       args.host + ":C:/TR4W-Test/readiness/"],
      check=True, timeout=120,
   )
   task = "TR4W-GuiScenario"
   launcher = (
      '$ProgressPreference="SilentlyContinue"; '
      '$python=Join-Path $env:LOCALAPPDATA "TR4W-Test\\.venv\\Scripts\\python.exe"; '
      '& $python C:\\TR4W-Test\\readiness\\scenarios.py '
      + args.scenario + ' --run ' + args.run
      + ' *> C:\\TR4W-Test\\readiness\\scenario-runner.log; exit $LASTEXITCODE'
   )
   encoded = base64.b64encode(launcher.encode("utf-16le")).decode("ascii")
   script = (
      '$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; '
      'if(Get-Process tr4w,tr4w_fpc -ErrorAction SilentlyContinue){throw "TR4W already running"}; '
      f'if(Get-ScheduledTask -TaskName {ps_quote(task)} -ErrorAction SilentlyContinue)'
      '{throw "Scenario task already exists"}; '
      '$action=New-ScheduledTaskAction -Execute '
      '"$env:SystemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" '
      f'-Argument {ps_quote("-NoProfile -NonInteractive -EncodedCommand " + encoded)}; '
      '$principal=New-ScheduledTaskPrincipal -UserId "gui-test" -LogonType Interactive -RunLevel Limited; '
      f'Register-ScheduledTask -TaskName {ps_quote(task)} -Action $action -Principal $principal | Out-Null; '
      f'Start-ScheduledTask -TaskName {ps_quote(task)}'
   )
   remote(args.host, script)
   deadline = time.monotonic() + 1200
   while time.monotonic() < deadline:
      time.sleep(2)
      status = remote(
         args.host,
         '$ProgressPreference="SilentlyContinue"; '
         f'$t=Get-ScheduledTask -TaskName {ps_quote(task)}; '
         f'$i=Get-ScheduledTaskInfo -TaskName {ps_quote(task)}; '
         '[pscustomobject]@{state=[string]$t.State;result=$i.LastTaskResult} | ConvertTo-Json -Compress',
      )
      state = json.loads(status)
      if state["state"] != "Running":
         break
   else:
      raise TimeoutError("Scenario did not finish; inspect its named task before retrying")
   args.output.mkdir(parents=True, exist_ok=True)
   subprocess.run(
      ["scp", "-r", "-o", "ConnectTimeout=60",
       args.host + ":C:/TR4W-Test/artifacts/" + args.scenario, str(args.output)],
      check=True, timeout=120,
   )
   remote(args.host, f'Unregister-ScheduledTask -TaskName {ps_quote(task)} -Confirm:$false')
   print((args.output / args.scenario / "result.json").read_text(encoding="utf-8"))
   return 0 if state["result"] == 0 else 1


if __name__ == "__main__":
   raise SystemExit(main())
