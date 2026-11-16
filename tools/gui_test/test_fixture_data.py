"""Verify corpus snapshots include committed WAL data without touching sources."""

import sqlite3
from contextlib import closing
import tempfile
import unittest
from pathlib import Path

from fixture_data import contact_digest, snapshot_corpus_log


class SnapshotTests(unittest.TestCase):
   def test_committed_wal_is_preserved_without_source_changes(self):
      with tempfile.TemporaryDirectory() as temporary:
         root = Path(temporary)
         source = root / "source.db"
         connection = sqlite3.connect(source)
         try:
            connection.execute("PRAGMA journal_mode=WAL")
            connection.execute("CREATE TABLE fixture(value TEXT)")
            connection.execute("INSERT INTO fixture VALUES ('committed in WAL')")
            connection.commit()
            before = {path.name: path.read_bytes() for path in root.iterdir()}
            destination = root / "snapshot.db"
            snapshot_corpus_log(source, destination)
            with closing(sqlite3.connect(destination)) as reader:
               self.assertEqual(reader.execute("SELECT value FROM fixture").fetchone(), ("committed in WAL",))
            self.assertEqual(before, {name: (root / name).read_bytes() for name in before})
         finally:
            connection.close()

   def test_existing_destination_is_never_overwritten(self):
      with tempfile.TemporaryDirectory() as temporary:
         destination = Path(temporary) / "existing.db"
         destination.write_bytes(b"existing evidence")
         with self.assertRaises(FileExistsError):
            snapshot_corpus_log(Path(temporary) / "missing.db", destination)
         self.assertEqual(destination.read_bytes(), b"existing evidence")

   def test_missing_source_does_not_create_empty_snapshot(self):
      with tempfile.TemporaryDirectory() as temporary:
         destination = Path(temporary) / "snapshot.db"
         with self.assertRaises(FileNotFoundError):
            snapshot_corpus_log(Path(temporary) / "missing.db", destination)
         self.assertFalse(destination.exists())

   def test_migration_projection_does_not_hide_changed_contact_values(self):
      with tempfile.TemporaryDirectory() as temporary:
         database = Path(temporary) / "fixture.db"
         with closing(sqlite3.connect(database)) as connection:
            connection.execute("CREATE TABLE qso(call TEXT)")
            connection.execute("INSERT INTO qso VALUES ('W1AW')")
            connection.commit()
            columns = ["_rowid", "call"]
            before = contact_digest(database, columns)
            connection.execute("ALTER TABLE qso ADD COLUMN migration_metadata TEXT")
            connection.commit()
            self.assertEqual(before, contact_digest(database, columns))
            connection.execute("UPDATE qso SET call='K1ABC'")
            connection.commit()
            self.assertNotEqual(before, contact_digest(database, columns))
            with self.assertRaises(KeyError):
               contact_digest(database, ["missing_column"])


if __name__ == "__main__":
   unittest.main()
