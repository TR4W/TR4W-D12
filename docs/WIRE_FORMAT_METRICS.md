# Wire-format metrics (issue 300, 2026-11-22)

NY4I's question: for the multi-op wire, is it time to leave the raw 376-byte
`ContestExchange` for JSON or another extensible format -- sending **no blank
fields**, but **checksumming the record** so the server knows a field was blank
rather than lost?

Instrument: `tr4w/test/bench/bench_wire_formats.lpr` (built by `Build-Bench.ps1`;
run it with `sqlite3.dll` beside the exe). It reads every QSO of the 13 corpus
logs (on a temp copy -- the fixtures are never opened for write) and encodes each
record four ways. **No production code changed.**

| format        | what it is                                                            |
| ------------- | --------------------------------------------------------------------- |
| binary        | today: raw record, `SizeOf(ContestExchange)` = 376 bytes              |
| JSON full     | one object, **every** field named, blank number `0`, blank string `""` |
| JSON omit     | one object, blank and zero fields left out                            |
| TLV           | tag byte, 2-byte length, UTF-8 value; blanks omitted          |

JSON and TLV both end with the record checksum (JSON member `k`, TLV tag 0): a
CRC-32 over the **full** record, every field in a fixed order, blanks included,
so it is identical whether or not the sender omitted blanks.

## FINAL MEASUREMENT: the whole row, 89 columns (2026-11-22)

Once the wire became the QSO as an event, the bench was rebuilt to take its
field list from the `qso` table (`PRAGMA table_info`, minus the local-only
columns) and its values from the rows themselves, and omission became "equals
the column's default" so a NULL and a real 0 stay distinct. **The tables further
down measured a hand list of 69 record fields and are superseded by this one.**
(The bench reads the table with a raw `SELECT`; that is an interim exception and
is replaced by the repository's own column list in stage W1 of the plan.)

Same 1,855 corpus QSOs, 89 wire fields, 29.1 non-default fields per QSO on
average:

| format                      | avg bytes / QSO | vs the old 376-byte record |
| --------------------------- | --------------: | -------------------------: |
| JSON, every field named     |          1,844.6 |                       491% |
| **JSON, defaults omitted**  |        **680.7** |                   **181%** |
| TLV (considered, rejected)  |            241.6 |                        64% |

Time per QSO, microseconds (encode = checksum + build; decode = parse + checksum):

| format       | encode (PC, Pascal) | decode (PC, Pascal) | decode, Python, PC | Pi 400 | Pi 5 |
| ------------ | ------------------: | ------------------: | -----------------: | -----: | ---: |
| JSON full    |                51.3 |               154.7 |               34.3 |  163.8 | 71.1 |
| JSON omit    |                20.7 |                58.4 |               25.2 |  122.5 | 50.5 |
| TLV          |                 5.6 |                 8.2 |               22.6 |   98.3 | 44.2 |

- **Omitting defaults still cuts JSON by 63%** and its time by more than half.
  At a station's worst case (1,200 QSOs an hour) the slowest decode is 164 us on
  a Pi 400: a negligible load. Size and extensibility decide this, not speed.
- **Integrity.** Every non-default field of every QSO treated as lost changes the
  checksum: **53,937 of 53,937** (Pascal) and **161,856 of 161,856** (Python, all
  three formats). The round trip is EXACT, every field equal after decode, in all
  three formats: 0 failures. Python verifies every Pascal frame on the PC, the
  Pi 400 and the Pi 5.
- **The non-ASCII pin** (`unicode_synthetic.*`, 7 rows) verifies in both.

### A DATA FINDING THE BENCH MADE (not fixed here)

**3,229 TEXT values in the corpus logs hold a literal NUL character**, in
`computer_id` and `rcvd_precedence`: the old record's `AnsiChar` "none" (`#0`)
stored as a one-character string where NULL was meant. TLV carries a NUL
faithfully; the JSON parser does not, so the first JSON round trip failed on it.
The sender must treat NUL as blank (the bench strips it and counts it), and the
**writer** should store NULL: `uLogRepository`'s binding of those `AnsiChar`
fields is where to look. It is unknown whether live-logged QSOs do this or only
the migrated fixtures do; no live log was read.

### What posting a QSO costs the main thread today

`bench_post_cost.lpr`, the real `TNetSendQueue` plus the other caller-thread
work of `PostQsoPacket` (two 384-byte copies; the framing guard, `NetPacketKind`
and `NetIsConnected` are untimed and are a few nanoseconds). Microseconds per
post; for scale, the commit itself is **p50 0.60 ms, p99 2.4 ms** in the
issue-350 bench (WAL journal, `synchronous = 2`):

| link                  | paced (1 per 3 ms) p50 / p99 / max | burst p50 / p99 / max  |
| --------------------- | ---------------------------------: | ---------------------: |
| fast                  |                   9.2 / 95.5 / 711 |         0.6 / 4.5 / 55 |
| slow (5 ms a write)   |                   5.6 / 92.2 / 704 |         0.3 / 6.4 / 46 |
| stalled (250 ms)      |                  6.6 / 118 / 138   |         0.4 / 0.9 / 21 |

The caller does NOT feel a slow or stalled link (the queue grows, the post does
not slow), and the post is about 1-1.5% of the commit at p50. It is not zero: a
few microseconds, and a worst case near 0.7 ms comparable to the commit's p99.
The paced rows cost more than the bursts because the worker is waking and
contending for the lock between posts. NY4I's requirement (below) removes even
this.

## Superseded: the 69-field record measurement (1,855 QSOs, 13 logs; 3 timing passes; Windows x86_64)

| format     | avg bytes / QSO | vs binary | encode us/rec | decode us/rec |
| ---------- | --------------: | --------: | ------------: | ------------: |
| binary     |             376 |      100% |        (copy) |        (copy) |
| JSON full  |           959.8 |      255% |          ~33  |          ~50  |
| JSON omit  |           435.6 |      116% |          ~16  |          ~23  |
| TLV        |           175.4 |       47% |          ~4   |          ~5   |

Per log the same ordering holds (JSON full 950-1010 B, JSON omit 428-541 B, TLV
140-209 B). 1,316 of the 1,855 QSOs are `winter_fd`, so the totals lean on it;
the per-log lines are in the bench output.

**Speed.** "encode" is the checksum plus building the text/bytes from the
collected field list; "decode" is parsing plus recomputing the checksum. Both
exclude the record-to-field-list step, which is the same for every format
(timed inside the bench but not printed). Omitting blanks **halves** JSON's time as well as its size
(fewer members to build and parse). TLV is the cheapest by a wide margin. Even
JSON full is ~50 us to decode: a burst of 300 QSOs is 15 ms, nowhere near a
bottleneck. **Speed does not decide this; size and extensibility do.**

**Checksum.** The dropped-field test treated each non-blank field of each record
as lost and recomputed: **50,672 of 50,672 detected**. The round trip (encode,
decode with missing fields defaulted to blank, recompute, compare) failed **0**
times for JSON full, JSON omit and TLV. So "omit blanks, checksum the record"
works as NY4I proposed, and the checksum is what separates *nothing to say* from
*lost*.

## The receiver in another language, on another machine (Python)

`tr4w/test/bench/wire_check.py` is an **independent receiver**: it knows the
canonical rule from the comment at the top of the file, not from the Pascal
code. Run `bench_wire_formats.exe <corpus> 1 <outdir>` to write the frames
(length-prefixed files plus `fields.json`), then `python wire_check.py <outdir>`.
Nothing is sent over a network; this is step 1 of two, and the server's real
framing is not involved.

Same 1,862 frames (1,855 corpus QSOs plus 7 synthetic non-ASCII ones), decode plus checksum recompute, microseconds per record:

| format     | Windows PC, Python 3.12 | Raspberry Pi 400, Python 3.11 | Raspberry Pi 5 (bench5), Python 3.13 |
| ---------- | ----------------------: | ----------------------------: | -----------------------------------: |
| JSON full  |                    27.1 |                         127.1 |                                 55.5 |
| JSON omit  |                    22.1 |                         103.6 |                                 41.5 |
| TLV        |                    17.6 |                          82.3 |                                 35.1 |

The Pi 5 is about 2x the Pi 400 and about 2x slower than the PC; every frame
verified there too (0 failures, 152,082 of 152,082 dropped fields detected).
bench5's ssh port (22) was open and answered, so no firewall rule is in the way
of the step-1 copy; the step-2 listener port has not been tested.

- **The checksum agrees across languages and machines**: every frame verified
  (0 failures) in all three formats on both, and 152,082 of 152,082 dropped
  fields (3 formats x 50,672, plus 66 in the synthetic set) were detected. Pascal and Python build the same
  canonical stream.
- **In Python the formats are closer than in Pascal** (TLV 82 us versus JSON omit
  104 us on the Pi, where Pascal was about 5 versus 23). The checksum itself is a
  Python loop over all 69 fields and is the same cost for every format, so it
  dominates TLV. A server that cared would compute the CRC incrementally or in C.
- **The Pi is about 4-5x slower than the PC.** At ~100 us a record a burst of
  300 QSOs decodes in ~30 ms on a Pi 400. Speed still does not decide this.

## What this does and does not say

- JSON that omits blanks is **larger than today's binary** (116%); only TLV
  beats it (47%). JSON's price is the key names. Shorter keys, or a numeric tag
  in the JSON, would narrow that -- not measured.
- Values are carried as **text** in both JSON and TLV (a number is its digits).
  A binary-integer TLV would be smaller than 175 B; this is the pessimistic TLV.
- Packet framing is not counted for any format.
- Times are one machine, three passes, a 1 us-class clock (QueryPerformanceCounter);
  read them as orders of magnitude.
- The fixed 376 bytes also costs nothing to parse; the table has no row for it
  because the bench does not copy it.
- Not built: an actual server side. No TCP listener was built: at a station's
  worst case (1,200 QSOs an hour, one every 3 s) the slowest decode measured
  (about 127 us on a Pi 400) is ~0.004% of a core, and a 10,000-QSO catch-up
  is about 1.3 s on a Pi 400. Speed does not decide the format.

## Rulings and the design they imply (NY4I, 2026-11-22)

1. **No backward compatibility.** A peer or server speaking the old 376-byte
   QSO messages is an error. Only the three messages that carry a
   `ContestExchange` (new QSO, edit, offline QSO) get new forms; station status,
   spots, intercom, parameters and HELLO stay as they are.
2. **Version gate: report and reject.** The protocol version IS the schema
   version (it fixes the field set the checksum covers and every default).
   A client whose HELLO version differs from the server's is reported and
   refused, so two stations never exchange QSOs under different field sets and
   the checksum cannot raise a false "lost field" for a version mismatch. The
   server already closes a connection whose HELLO names a protocol it does not
   speak; what the operator SEES on the client when that happens has not been
   checked.
3. **The wire is UTF-8.** Every sender (Windows, Linux, macOS) converts from its
   own native strings. The checksum is over each value's UTF-8 BYTES with a
   byte-count length, never a character count. Pinned by `unicode_synthetic.*`
   (accented Latin, Cyrillic, Japanese, a 255-character = 510-byte value, a
   character outside the BMP, the string "0"): it verifies in Pascal and in
   Python on the PC, the Pi 400 and the Pi 5.
4. **Encoding: JSON with blanks omitted, plus the record checksum.** No
   dependency, readable in a capture, named fields so an unknown member is
   ignorable. Hand-rolled TLV and Protocol Buffers are considered and not chosen
   (positional tags need registry discipline; protobuf needs a shared schema and
   generated code). MessagePack or CBOR with string keys is the drop-in upgrade
   if size ever matters: the checksum is over the logical fields, so only the
   encode layer changes. Not measured.
5. **Edits are complete snapshots** (reset, then overlay), never a patch. An
   absent field means blank, not "unchanged" -- otherwise an operator clearing a
   field would be lost.
6. **No required-field list on the wire.** The client we control decides what
   goes on the wire, and the rule that matters (no contact is logged without a
   callsign) is enforced where the contact is logged. This is not a population
   of arbitrary senders: the version gate admits only our own clients, and the
   checksum proves what arrived is what was sent. A server-side required-field
   check would be a second copy of the logging rule, free to drift from it.
7. **The server's log moves to its own SQLite database at the same time as the
   wire change** (issue 341). That removes the old flat-record question: the
   server stores the named fields it receives as columns, as Unicode text, and
   the 376-byte `SERVERLOG.TRW`, its whole-log CRC32 and the hardcoded
   `CE_*_OFFSET` constants in `tr4wserver.py` all go. The per-record checksum
   is then the integrity check for each QSO as it arrives.
8. **Open (design, for the 341 plan):**
   - Wire field names are the bench's provisional short names (`pfx`, `rcs`).
     Making them the client's SQLite COLUMN names (`rcvd_year`, `year_sent`, ...)
     would make the server's mapping the identity and make drift visible; the
     checksum's field order and set would be defined once, against the schema.
   - **The wire carries the QSO as an event, not the 376-byte record (NY4I:
     "the 376 byte record is woefully poor design for an event source").** The
     station facts captured at the moment of the QSO (the `my_*` columns,
     `TQsoMyFacts`) are part of the QSO, so they travel with it. The 376-byte
     record "cannot carry these" (`uQsoMyFacts.pas`), which is why today a
     receiver stamps a peer's QSO with its OWN facts, marked assumed (ruling D).
     With the facts on the wire that stamping is no longer needed for a QSO from
     a current client, and a rover peer's grid arrives as the rover captured it.
     The server's table can then match the client's.
   - **So the wire is the `qso` row's columns, by column name, minus the local
     bookkeeping that is about THIS database and not about the QSO:** `id`,
     `session_id`, `session_seq`, `sent_to_server`, `server_dirty`, `sent_udp`,
     `udp_dirty`. (The exact exclusion list is for the 341 plan; `notes` and
     `rcvd_extra` need a decision.) The sender reads the row's own values, so
     the 376-byte record's representations (a 6-byte time, enum ordinals, one
     `Frequency`) stop mattering on the wire: the columns' are used (`qso_at`
     unix seconds, text tokens, `freq_tx_hz` / `freq_rx_hz`).
   - **The bench measured 69 record fields, so its sizes understate this.** The
     `qso` table has well over 100 columns. The numbers need re-measuring with
     the field list taken from the query's own columns, not a hand list.
   - **THE MAIN-THREAD RULE (NY4I): multi-op networking adds no time to logging
     a QSO.** The main thread commits the row to SQLite and does ONE non-blocking
     signal (an event, or the row id onto a lock-free queue) and nothing else for
     the network. A sender thread reads the committed row on its OWN connection
     (the log is WAL: a reader does not block the writer), builds the frame,
     checksums it and writes it, then marks the row sent. Today the post itself
     is on the main thread (a few microseconds; see above). The `qso` table is
     already the outbox: `sent_to_server`, `server_dirty` and
     `UNSENT_TO_SERVER_WHERE`. To prove the rule: commit-to-ready time unchanged
     with the link up versus down.
   - How a station catches up from the server's log now that there is no
     whole-log CRC32 to compare. The per-record identity is `(ceQSOID1, ceQSOID2)`
     and the row's `guid`; `uNetCatchUp` is where the current design lives.
