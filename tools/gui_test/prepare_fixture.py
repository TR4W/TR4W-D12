"""Create a fresh VM test run; SQLite backup preserves committed fixture records."""

import argparse
from contextlib import closing
import json
from pathlib import Path
import re
import shutil
import sqlite3


def main():
   parser = argparse.ArgumentParser(description=__doc__)
   parser.add_argument("--root", type=Path, required=True)
   parser.add_argument("--run", required=True)
   parser.add_argument("--settings-template", type=Path, required=True)
   parser.add_argument("--assets-template", type=Path, required=True)
   parser.add_argument("--database-template", type=Path)
   parser.add_argument("--database-name")
   args = parser.parse_args()
   root = args.root.resolve()
   if not root.is_relative_to(Path(r"C:\TR4W-Test").resolve()) or not re.fullmatch(r"[A-Za-z0-9-]+", args.run):
      raise RuntimeError("Fixture must be a named run inside C:\\TR4W-Test")
   target = root / "runs" / args.run
   if target.exists():
      raise RuntimeError("Refusing to overwrite an existing fixture: " + str(target))
   target.mkdir(parents=True)
   shutil.copy2(args.settings_template, target / "tr4w.json")
   shutil.copy2(args.assets_template / "CTY.DAT", target / "CTY.DAT")
   shutil.copytree(args.assets_template / "dom", target / "dom")
   if (args.assets_template / "ui-baselines").is_dir():
      shutil.copytree(args.assets_template / "ui-baselines", target / "ui-baselines")
   if args.database_template:
      name = args.database_name or args.database_template.name
      if Path(name).name != name or not name.lower().endswith(".db"):
         raise RuntimeError("Database name must be one .db filename, not a path")
      with closing(sqlite3.connect(args.database_template.resolve().as_uri() + "?mode=ro", uri=True)) as source:
         with closing(sqlite3.connect(target / name)) as destination:
            source.backup(destination)
   (target / "fixture.json").write_text(json.dumps({"settings": str(args.settings_template),
      "assets": str(args.assets_template), "database": str(args.database_template)}, indent=3), encoding="utf-8")
   print(target)


if __name__ == "__main__":
   main()
