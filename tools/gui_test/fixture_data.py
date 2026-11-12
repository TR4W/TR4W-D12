"""Read-only observations of disposable contest databases."""

from contextlib import closing
import hashlib
import json
import sqlite3


def log_state(database):
   with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      return {"qso_count": connection.execute("SELECT COUNT(*) FROM qso").fetchone()[0],
         "my_zone": connection.execute("SELECT value FROM config WHERE command='MY ZONE'").fetchall()}


def contacts(database):
   with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
      connection.row_factory = sqlite3.Row
      return [dict(row) for row in connection.execute('SELECT rowid AS _rowid,* FROM qso ORDER BY rowid')]


def contact_digest(database):
   data = json.dumps(contacts(database), sort_keys=True, default=str).encode("utf-8")
   return hashlib.sha256(data).hexdigest()
