"""Read-only observations of disposable contest databases."""

from contextlib import closing
import hashlib
import json
import sqlite3
import shutil
import tempfile
from pathlib import Path


def snapshot_corpus_log(source, destination):
   """Snapshot a stopped corpus fixture, preserving its source WAL/SHM files.

   Copy to scratch before opening SQLite: even a reader may touch SHM. The
   source must not have an active writer while its file set is copied.
   """
   source = Path(source)
   destination = Path(destination)
   if destination.exists():
      raise FileExistsError(destination)
   with tempfile.TemporaryDirectory(prefix="corpus-source-", dir=destination.parent) as temporary:
      scratch = Path(temporary)
      for suffix in ("", "-wal", "-shm"):
         part = Path(str(source) + suffix)
         if part.is_file():
            shutil.copy2(part, scratch / (source.name + suffix))
      if not (scratch / source.name).is_file():
         raise FileNotFoundError(source)
      with closing(sqlite3.connect(scratch / source.name)) as reader:
         with closing(sqlite3.connect(destination)) as writer:
            reader.backup(writer)
   return destination


def prepare_offline_fixture(database_template, settings_template, run):
   """Create the shared native pilot fixture; never import a live station."""
   snapshot_corpus_log(database_template, run / "practice.db")
   settings = json.loads(Path(settings_template).read_text(encoding="utf-8"))
   for key in ("radios", "profiles", "keyers", "clusters", "rotators", "externalLoggers", "activeExternalLoggerIds"):
      if settings.get(key):
         raise RuntimeError("Template contains live definitions: " + key)
   if settings.get("general", {}).get("autoConnect") is not False:
      raise RuntimeError("Template must explicitly disable automatic connection")
   settings["settings"]["Country"] = {"UpdateCheckOnStartup": False}
   settings["settings"]["Wsjtx"] = {"Enabled": False}
   settings["settings"]["CW"] = {"Enable": False}
   (run / "tr4w.json").write_text(json.dumps(settings, indent=3), encoding="utf-8")
   with closing(sqlite3.connect(run / "practice.db")) as database:
      for name in ("CW ENABLE", "PTT ENABLE", "CTY UPDATE CHECK ON STARTUP", "WSJT-X ENABLED", "HAMSCORE ENABLE", "EXTERNAL LOGGER ENABLED"):
         database.execute("UPDATE config SET value='FALSE' WHERE command=?", (name,))
      database.commit()


def log_state(database):
   with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      return {"qso_count": connection.execute("SELECT COUNT(*) FROM qso").fetchone()[0],
         "my_zone": connection.execute("SELECT value FROM config WHERE command='MY ZONE'").fetchall()}


def contacts(database):
   with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      connection.row_factory = sqlite3.Row
      return [dict(row) for row in connection.execute('SELECT rowid AS _rowid,* FROM qso ORDER BY rowid')]


def contact_digest(database, columns=None):
   rows = contacts(database)
   if columns is not None:
      # Opening an old fixture may add migration columns. Project only when
      # the caller explicitly supplies its PRE-OPEN columns; missing original
      # columns still fail, and all original values remain part of the digest.
      rows = [{name: row[name] for name in columns} for row in rows]
   data = json.dumps(rows, sort_keys=True, default=str).encode("utf-8")
   return hashlib.sha256(data).hexdigest()
