"""Create a fresh VM test run; SQLite backup preserves committed fixture records."""

import argparse
from contextlib import closing
import json
from pathlib import Path
import re
import shutil
import sqlite3


INSTALL_PARTS = ("dom", "CTY.DAT", "TRMASTER.DTA", "TRCLUSTER.DAT")

def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--root", type=Path, required=True)
   parser.add_argument("--run", required=True)
   # Exactly one: a settings template, or --fresh-install for the brand-new
   # condition (no settings file at all). Explicit, so a forgotten template can
   # never silently turn an ordinary case into a first-run case.
   settings = parser.add_mutually_exclusive_group(required=True)
   settings.add_argument("--settings-template", type=Path)
   settings.add_argument("--fresh-install", action="store_true")
   parser.add_argument("--assets-template", type=Path, required=True)
   # --fresh-install only: not even CTY.DAT and dom -- the literal empty working
   # folder (only this script's fixture.json record is written).
   parser.add_argument("--no-data", action="store_true")
   # The rest of what an installed copy has beside CTY.DAT and dom (TRMASTER.DTA,
   # TRCLUSTER.DAT). Fresh installs always get it; an ordinary case only when
   # asked, so the long-standing cases keep the environment their results were
   # established in.
   parser.add_argument("--install-data", action="store_true")
   # Leave one installed part out (repeatable): 'dom', 'CTY.DAT', 'TRMASTER.DTA',
   # 'TRCLUSTER.DAT'. How the startup install check is driven per case.
   parser.add_argument("--omit", action="append", default=[], choices=INSTALL_PARTS)
   parser.add_argument("--database-template", type=Path)
   parser.add_argument("--database-name")
   args = parser.parse_args()
   if args.no_data and not args.fresh_install:
      raise RuntimeError("--no-data is only meaningful with --fresh-install")
   root = args.root.resolve()
   if not root.is_relative_to(Path(r"C:\TR4W-Test").resolve()) or not re.fullmatch(r"[A-Za-z0-9-]+", args.run):
      raise RuntimeError("Fixture must be a named run inside C:\\TR4W-Test")
   target = root / "runs" / args.run
   if target.exists():
      raise RuntimeError("Refusing to overwrite an existing fixture: " + str(target))
   if args.fresh_install and args.database_template:
      raise RuntimeError("A fresh install has no contest log yet")
   target.mkdir(parents=True)
   if not args.fresh_install:
      shutil.copy2(args.settings_template, target / "tr4w.json")
   staged = []
   if not args.no_data:
      wanted = ["CTY.DAT", "dom"]
      if args.fresh_install or args.install_data:
         wanted += ["TRMASTER.DTA", "TRCLUSTER.DAT"]
      for name in wanted:
         if name in args.omit:
            continue
         source = args.assets_template / name
         if name == "dom":
            shutil.copytree(source, target / name)
         else:
            # Fail closed: a silently absent file would make the install check
            # judge a different folder than the case claims.
            if not source.is_file():
               raise FileNotFoundError(source)
            shutil.copy2(source, target / name)
         staged.append(name)
   # A fresh install gets only what an installed copy has in its folder.
   if (args.assets_template / "ui-baselines").is_dir() and not args.fresh_install:
      shutil.copytree(args.assets_template / "ui-baselines", target / "ui-baselines")
   if args.database_template:
      name = args.database_name or args.database_template.name
      if Path(name).name != name or not name.lower().endswith(".db"):
         raise RuntimeError("Database name must be one .db filename, not a path")
      with closing(sqlite3.connect(args.database_template.resolve().as_uri() + "?mode=ro", uri=True)) as source:
         with closing(sqlite3.connect(target / name)) as destination:
            source.backup(destination)
   (target / "fixture.json").write_text(json.dumps({"fresh_install": args.fresh_install, "no_data": args.no_data,
      "install_parts": staged, "omitted": args.omit,
      "settings": None if args.fresh_install else str(args.settings_template),
      "assets": str(args.assets_template), "database": str(args.database_template)}, indent=3), encoding="utf-8")
   print(target)


if __name__ == "__main__":
   main()
