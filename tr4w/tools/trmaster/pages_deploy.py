"""Publish data files to the TR4W GitHub Pages repository."""

import shutil
import subprocess
import tempfile
from pathlib import Path


DEFAULT_DEPLOY_URL = "https://github.com/TR4W/TR4W.github.io.git"


def run_git(args, cwd):
   result = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
   if result.returncode:
      raise RuntimeError(f"git {' '.join(args)} failed: {(result.stderr or result.stdout).strip()}")
   return result.stdout


def publish_files(paths, deploy_url, message, workdir):
   """Commit the given files by basename and push. Return False if already current."""
   with tempfile.TemporaryDirectory(prefix="pages-", dir=workdir) as stage:
      checkout = Path(stage) / "site"
      run_git(["clone", "--depth", "1", "--", deploy_url, str(checkout)], stage)
      for path in paths:
         shutil.copyfile(path, checkout / path.name)
      run_git(["add", "--", *(path.name for path in paths)], checkout)
      if not run_git(["status", "--porcelain"], checkout).strip():
         return False
      run_git(["commit", "-m", message], checkout)
      run_git(["push", "origin", "HEAD"], checkout)
   return True
