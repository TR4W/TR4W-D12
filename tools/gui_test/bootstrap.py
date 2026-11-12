"""Run a scenario under pythonw without a console obscuring the tested forms."""

import runpy
import sys
import traceback
from pathlib import Path


def main():
   directory = Path(__file__).resolve().parent
   with (directory / "scenario-runner.log").open("w", buffering=1, encoding="utf-8") as log:
      sys.stdout = log
      sys.stderr = log
      sys.path.insert(0, str(directory))
      sys.argv[0] = str(directory / "scenarios.py")
      try:
         runpy.run_path(sys.argv[0], run_name="__main__")
      except SystemExit:
         raise
      except BaseException:
         traceback.print_exc()
         return 1
   return 0


if __name__ == "__main__":
   raise SystemExit(main())
