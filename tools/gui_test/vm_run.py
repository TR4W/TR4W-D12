"""Upload Python scenarios and run them in GUI-TEST's existing desktop via SSH."""

import argparse
from scenario_names import SCENARIOS
import base64
import json
import ntpath
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
   parser.add_argument("scenario", choices=SCENARIOS)
   parser.add_argument("--host", default="tr4w-gui-test")
   parser.add_argument("--run", default="pilot-001")
   parser.add_argument("--root", default=r"C:\TR4W-Test")
   parser.add_argument("--python", default=r"C:\TR4W-Test\.venv-x86\Scripts\python.exe")
   parser.add_argument("--output", type=Path, required=True)
   args = parser.parse_args()
   if not args.run.replace("-", "").isalnum():
      raise ValueError("Run name must contain only letters, digits and hyphens")
   source = Path(__file__).resolve().parent
   subprocess.run(
      ["scp", "-o", "ConnectTimeout=60", str(source / "session.py"),
       str(source / "scenarios.py"), str(source / "preferences_audit.py"),
       str(source / "radio_workflow.py"),
       str(source / "message_workflow.py"),
       str(source / "window_capture.py"),
       str(source / "guide_capture.py"),
       str(source / "bench_ui.py"),
       str(source / "bench_preferences.py"),
       str(source / "contest_forms.py"),
       str(source / "prepare_fixture.py"),
       str(source / "bench_log_names.py"),
       str(source / "bench_entry_errors.py"),
       str(source / "bench_years.py"),
       str(source / "bench_county.py"),
       str(source / "bench_switch.py"),
       str(source / "bench_exports.py"),
       str(source / "bench_remaining.py"),
       str(source / "bench_messages.py"),
       str(source / "bench_online.py"),
       str(source / "bench_radio_editor.py"),
       str(source / "bench_loggers.py"),
       str(source / "fixture_data.py"), str(source / "adif_fixtures.py"), str(source / "bench_import.py"),
       str(source / "bench_locked.py"),
       str(source / "bench_search.py"), str(source / "visual_assert.py"),
       str(source / "qso_entry.py"),
       str(source / "evidence.py"),
       str(source / "bootstrap.py"), str(source / "scenario_names.py"),
       args.host + ":C:/TR4W-Test/readiness/"],
      check=True, timeout=120,
   )
   task = "TR4W-GuiScenario"
   worker = ntpath.join(ntpath.dirname(args.python), "pythonw.exe")
   arguments = subprocess.list2cmdline([
      r"C:\TR4W-Test\readiness\bootstrap.py", args.scenario,
      "--run", args.run, "--root", args.root,
   ])
   process_guard = 'if(Get-Process tr4w,tr4w_fpc -ErrorAction SilentlyContinue){throw "TR4W already running"}; '
   if args.scenario.startswith("radio-") and args.scenario != "radio-start":
      process_guard = ""
   script = (
      '$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"; '
      + process_guard +
      f'if(Get-ScheduledTask -TaskName {ps_quote(task)} -ErrorAction SilentlyContinue)'
      '{throw "Scenario task already exists"}; '
      f'$caseRoot=[IO.Path]::GetFullPath({ps_quote(args.root)}).TrimEnd([char]92); '
      f'$caseOut=[IO.Path]::GetFullPath({ps_quote(ntpath.join(args.root, "artifacts", args.scenario))}); '
      f'$caseArchive=[IO.Path]::GetFullPath({ps_quote(ntpath.join(args.root, "artifacts", "history", args.run + "-" + args.scenario + "-" + str(time.time_ns())))}); '
      'foreach($candidate in @($caseOut,$caseArchive)){'
      'if(!$candidate.StartsWith($caseRoot+[char]92,[StringComparison]::OrdinalIgnoreCase))'
      '{throw "Artifact path escaped the test root"}}; '
      'if(Test-Path -LiteralPath $caseOut){'
      'New-Item -ItemType Directory -Force (Split-Path -Parent $caseArchive) | Out-Null; '
      'Move-Item -LiteralPath $caseOut -Destination $caseArchive}; '
      f'$action=New-ScheduledTaskAction -Execute {ps_quote(worker)} '
      f'-Argument {ps_quote(arguments)}; '
      '$principal=New-ScheduledTaskPrincipal -UserId "gui-test" -LogonType Interactive -RunLevel Limited; '
      f'Register-ScheduledTask -TaskName {ps_quote(task)} -Action $action -Principal $principal | Out-Null; '
      f'Start-ScheduledTask -TaskName {ps_quote(task)}'
   )
   remote(args.host, script)
   crash_seen = False
   deadline = time.monotonic() + 1200
   while time.monotonic() < deadline:
      time.sleep(2)
      status = remote(
         args.host,
         '$ProgressPreference="SilentlyContinue"; '
         f'$t=Get-ScheduledTask -TaskName {ps_quote(task)}; '
         f'$i=Get-ScheduledTaskInfo -TaskName {ps_quote(task)}; '
         f'$log={ps_quote(args.root + chr(92) + "runs" + chr(92) + args.run + chr(92) + "tr4w.log")}; '
         '$crash=$false; if(Test-Path $log){$crash=[bool](Select-String -Path $log -SimpleMatch "[CRASH] LCL: unhandled" -Quiet)}; '
         '[pscustomobject]@{state=[string]$t.State;result=$i.LastTaskResult;crash=$crash} | ConvertTo-Json -Compress',
      )
      state = json.loads(status)
      if state["crash"]:
         crash_seen = True
         break
      if state["state"] != "Running":
         break
   else:
      crash_seen = True
      state = {"result": 1, "state": "Timed out"}
   if crash_seen or state["result"] != 0:
      # Capture the still-live application BEFORE stopping the Python worker.
      failure_script = (
         '$ProgressPreference="SilentlyContinue"; '
         f'$shouldDump=${str(crash_seen).lower()}; '
         f'$root={ps_quote(args.root)}; $run={ps_quote(args.run)}; '
         f'$out=Join-Path $root {ps_quote("artifacts/" + args.scenario)}; '
         'if(Test-Path -LiteralPath (Join-Path $out "hung-process.json")){$shouldDump=$true}; '
         'New-Item -ItemType Directory -Force $out | Out-Null; '
         '$pidFile=Join-Path $root ("runs/"+$run+"/owned-process.json"); '
         'if(!(Test-Path $pidFile)){$pidFile=Join-Path $root ("runs/"+$run+"/bench-workflow.json")}; '
         'if(!(Test-Path $pidFile)){$pidFile=Join-Path $root ("runs/"+$run+"/radio-workflow.json")}; '
         'if($shouldDump -and (Test-Path $pidFile)){$ownedPid=(Get-Content $pidFile -Raw | ConvertFrom-Json).pid; '
         'if(Get-Process -Id $ownedPid -ErrorAction SilentlyContinue){'
         '$dump=Join-Path $out ("crash-"+$ownedPid+".dmp"); '
         '& C:\\TR4W-Test\\tools\\procdump\\procdump.exe -accepteula -ma $ownedPid '
         '$dump *> (Join-Path $out "dump.log"); '
         'if($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dump)){'
         '$p=Get-CimInstance Win32_Process -Filter ("ProcessId="+$ownedPid); '
         '$expected=Join-Path $root "app\\tr4w_fpc.exe"; '
         '$settings=Join-Path $root ("runs\\"+$run+"\\tr4w.json"); '
         'if($p -and $p.ExecutablePath -eq $expected -and $p.CommandLine.Contains($settings))'
         '{Stop-Process -Id $ownedPid -Force}}}}; '
         f'Stop-ScheduledTask -TaskName {ps_quote(task)} -ErrorAction SilentlyContinue; '
         "Get-CimInstance Win32_Process -Filter \"Name = 'python.exe' OR Name = 'pythonw.exe'\" | "
         f'Where-Object {{$_.CommandLine -like {ps_quote("*bootstrap.py " + args.scenario + " --run " + args.run + "*")}}} | '
         'ForEach-Object {Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue}; '
         'Copy-Item (Join-Path $root ("runs/"+$run+"/tr4w*.log")) $out -ErrorAction SilentlyContinue'
      )
      remote(args.host, failure_script)
   if args.scenario.startswith("bench-"):
      remote(args.host, '$ProgressPreference="SilentlyContinue"; '
         f'$root={ps_quote(args.root)}; $run={ps_quote(args.run)}; '
         f'$out=Join-Path $root {ps_quote("artifacts/" + args.scenario)}; '
         'Copy-Item (Join-Path $root ("runs/"+$run+"/tr4w*.log")) $out -ErrorAction SilentlyContinue')
   args.output.mkdir(parents=True, exist_ok=True)
   subprocess.run(
      ["scp", "-r", "-o", "ConnectTimeout=60",
       args.host + ":" + args.root.replace("\\", "/") + "/artifacts/" + args.scenario, str(args.output)],
      check=True, timeout=120,
   )
   remote(args.host, f'Unregister-ScheduledTask -TaskName {ps_quote(task)} -Confirm:$false')
   result_path = args.output / args.scenario / "result.json"
   if result_path.exists():
      print(result_path.read_text(encoding="utf-8"))
   else:
      print(json.dumps({"passed": False, "task": state, "crash_detected": crash_seen}))
   return 0 if state["result"] == 0 and not crash_seen else 1


if __name__ == "__main__":
   raise SystemExit(main())
