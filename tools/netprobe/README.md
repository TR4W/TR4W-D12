# netprobe

An independent client for the TR4W multi-op wire protocol -- **network protocol 5**
(a QSO is a length-framed JSON row; docs/TR4WSERVER_SQLITE_DESIGN.md 13.6 and
13.7) -- to be pointed at any server (`tr4wserver`, TR4WServerPy, or a future
one). Python 3, standard library only.

The in-tree client and `tr4wserver` agree with each other because both compile the
same units; a change there changes the wire for everyone else and nothing in the
build notices. This tool carries its own framing and its own copy of the row codec,
so it can disagree with a server and say so.

Files: `netprobe.py` (the cases), `compare.py` (both servers, row-level),
`test_codec.py` (the codec copy against the golden vectors).

## Use

```
python -I tools/netprobe/netprobe.py --host 127.0.0.1 --port 1061 --label mine --case qso
python -I tools/netprobe/netprobe.py --case selftest          # no server needed
python -I -m unittest discover -s tools/netprobe              # the codec copy
```

| option | meaning |
|---|---|
| `--case` | one of the cases below, or `all` (every case that talks to a server; default) |
| `--host`, `--port` | the main port; the log-sync port is `PORT + 1` |
| `--password` | default `TR4WSERVER` (sent as ten NUL-padded bytes) |
| `--label` | name printed on every result line |
| `--timeout` | seconds to wait for any one message (default 3) |
| `--burst` | rows in `burst`, `resend`, `catchup`, `offline-ack` and the first `restock` round (default 30) |
| `--restock-big` | rows in the second, large `restock` round (default 0 = skip; the in-tree server takes about 45 ms per OFFLINE row, so 5000 is minutes) |
| `--contest` | the contest id the probes announce in their HELLO (default `ARRL-DX-CW`) |
| `--seed-ids` | first row number (guid `%032x`) the run hands out; default the clock. A fixed seed makes the rows repeatable, which `compare.py` needs |
| `--columns` | `columns.json` (default `tr4w/test/wire/columns.json`) |
| `--launch pascal\|python` | start the server as a child process, fresh directory per case, stop it after; needs `--server` (`tr4wserver.exe` or `tr4wserver.py`) and `--workdir` |

Output is one line per check, `RESULT <label> <case> <check>: PASS|FAIL|INFO|SKIP`.
Exit 0: no check failed; 1: one did; 2: a case could not run. Every wait has a
deadline.

**The row codec is a COPY of TR4WServerPy's `wire.py`** (copied, not imported, so
this stays one file; the header of `netprobe.py` says so). `--case selftest` and
`test_codec.py` prove the copy reproduces `tr4w/test/wire/golden_vectors.json`,
the independent oracle's output, in both directions. Re-copy and re-run them if
`wire.py` changes.

## The cases

The server's log is read through the sync port (header frame, then one framed row
per QSO) and every row's checksum is verified. With `--launch` the case also
leaves `final-sync.bin` and `final-db.json` (every column of every row, in seq
order, plus `meta`, read with sqlite3 after the server is stopped) in the case's
directory.

| case | what it sends | what it proves |
|---|---|---|
| `selftest` | nothing | the codec copy equals the golden vectors |
| `connect` | password, banner, HELLO | the handshake; the 19-byte LOGCOMPARE on admit carries the row count (no CRC, no contest); link stays up |
| `spot` | one 106-byte DX spot | B receives it byte for byte; A not disconnected |
| `qso` | one NEW row, then one with a lying sender byte | B receives the row intact with sender = A's HELLO id (re-stamped); A not echoed; the log grew by exactly the rows sent, in order |
| `burst` | `--burst` rows in ONE write | every one reaches B and the log, in order |
| `edit` | NEW, then an EDIT with fields omitted; an EDIT of an unheld guid; an EDIT with an empty guid | relayed, ACKed (8300), the stored row is the whole edited row (an omitted field is its default); unheld guid: relayed and ACKed, stores nothing; empty guid changes nothing |
| `disc` | A and B connect, B closes | A receives 8260 carrying B's ordinal |
| `dup` | two connections claim id 1; the same guid twice and from two stations | 8320 for the second claimant; the id can be retaken once free; a held guid is neither stored nor relayed |
| `serial` | A reserves a serial (needs `SERIAL NUMBER LOCKOUT=1`, which `--launch` sets) | 8310 pushed on admit; B sees it advance; the next serial after a restart over stored serials is reported (INFO) |
| `time` | the removed 20-byte time-sync packet, then an intercom line in the same write | skipped, not relayed, the line behind it relayed |
| `hello` | HELLO, a second station, a contest change, stations that break the handshake, protocol 4 and 6, ids 0 and 27, an empty contest | the server answers with its own HELLO (protocol 5, id 0); contests relayed byte for byte; a QSO or COMPUTERID first closes the connection; **a protocol-4 HELLO is refused readably with SM_PROTOCOL_MISMATCH (8330, param 5) and closed**; a held id gets 8320 |
| `resend` | the same row as NEW twice, as OFFLINE, a new OFFLINE row, empty-guid rows, an edit, a burst twice | stored and relayed once however often it arrives; an OFFLINE row of a held guid is still ACKed; OFFLINE is never relayed; an empty guid is never a duplicate |
| `restock` | `--burst` rows as OFFLINE in one write, again, then `--restock-big` | every row ACKed; nobody else sees any; the log grows by exactly the set, once each, in order; the same set adds none and is still ACKed |
| `catchup` | A logs rows while nobody is there; C joins late and downloads | header `{contest, rows, schema: 5}` agrees with the rows; every row verifies, in arrival order, once; a joiner is not sent the old rows on admit but is told the contest; a second download is the same bytes; an edit is in place; **with `--launch`: after a kill and restart the download is the same bytes and the contest survives** |
| `badcrc` | rows with a wrong or missing checksum, a changed field, bad JSON, a non-object, `0x1F` and `14.025` in a numeric column, a non-UTF-8 payload, a sender byte alone, a bad EDIT, an OFFLINE run of good-bad-good | each refused (not stored, not relayed), the link stays up, and the good row sent right behind it arrives |
| `big` | a row of about 58000 bytes; one whose payload is exactly 60000; a header declaring 60001; one declaring 4 GB | the legal rows travel and are stored whole; an over-cap declaration disconnects the sender from the six header bytes, others untouched |
| `legacy` | protocol-4 frames (1040, 1050, 1055) and an unknown id | the connection is closed and nothing is relayed |
| `offline-ack` | `--burst` OFFLINE rows; the server process is KILLED when the first ACK arrives; restart (needs `--launch`) | every acknowledged row is in the log after the restart (ACK only after durable); a run cut mid-frame leaves no half row |
| `clear` | set-dupesheet, clear-mults, then clear-all-logs; then a HELLO for a new contest and a new row | the flags are set on every QSO row; clear-all writes a dated backup holding every old row BEFORE emptying the log; the other station is told; a new contest is then accepted and becomes the server's contest |

## Comparing both servers

```
python -I tools/netprobe/compare.py --pascal tr4w/tr4wserver/tr4wserver.exe ^
     --python C:\projects\TR4WServerPy\tr4wserver.py --work <scratch dir> [--cases a,b,c] [--port 1261]
```

For each case it starts each server fresh, runs the case with the SAME seed, then
compares the two: the RESULT lines (status and detail; `timing` checks and the
servers' own version text are ignored), **every column of every row of both
`.tr4wsrv` files in seq order**, the `meta` table, and the sync stream (decoded
as JSON values; the byte spelling differs and is printed as a NOTE). Every
difference is a `DIVERGENCE` line; exit 0 only when nothing failed and nothing
diverged. It copies the Pascal exe and `sqlite3.dll` into the scratch directory so
nothing in the tree is touched, and uses temp ports and files only.

The old byte-oracle scripts (`Run-SyncBaseline.ps1`, `Run-TrwRoundTrip.ps1`,
`baselines/`) are gone: there is no 376-byte image to hash, and `compare.py`
compares rows instead.

## Cautions

- It writes real QSOs into the server's log. Point it at a throwaway server, never
  a station's live one, and give the server its own working directory (`--launch`
  does).
- Without `--launch`, the cases that need a restart or a kill (`offline-ack`, the
  restart half of `catchup` and `serial`, the backup check of `clear`) are SKIPped.
