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
| TLV           | tag byte, length byte, value; blank and zero omitted                  |

JSON and TLV both end with the record checksum (JSON member `k`, TLV tag 0): a
CRC-32 over the **full** record, every field in a fixed order, blanks included,
so it is identical whether or not the sender omitted blanks.

## Result (1,855 QSOs, 13 logs; 3 timing passes; Windows x86_64)

| format     | avg bytes / QSO | vs binary | encode us/rec | decode us/rec |
| ---------- | --------------: | --------: | ------------: | ------------: |
| binary     |             376 |      100% |        (copy) |        (copy) |
| JSON full  |           959.8 |      255% |          ~33  |          ~50  |
| JSON omit  |           435.6 |      116% |          ~16  |          ~23  |
| TLV        |           147.1 |       39% |          ~1   |          ~6   |

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

Same 1,855 frames, decode plus checksum recompute, microseconds per record:

| format     | Windows PC, Python 3.12 | Raspberry Pi 400, Python 3.11 (aarch64) |
| ---------- | ----------------------: | --------------------------------------: |
| JSON full  |                    24.5 |                                   122.1 |
| JSON omit  |                    19.9 |                                    96.6 |
| TLV        |                    16.4 |                                    72.0 |

- **The checksum agrees across languages and machines**: every frame verified
  (0 failures) in all three formats on both, and 152,016 of 152,016 dropped
  fields (3 formats x 50,672) were detected. Pascal and Python build the same
  canonical stream.
- **In Python the formats are closer than in Pascal** (TLV 72 us versus JSON omit
  97 us on the Pi, where Pascal was 6 versus 23). The checksum itself is a
  Python loop over all 69 fields and is the same cost for every format, so it
  dominates TLV. A server that cared would compute the CRC incrementally or in C.
- **The Pi is about 4-5x slower than the PC.** At ~100 us a record a burst of
  300 QSOs decodes in ~30 ms on a Pi 400. Speed still does not decide this.

## What this does and does not say

- JSON that omits blanks is **larger than today's binary** (116%); only TLV
  beats it (39%). JSON's price is the key names. Shorter keys, or a numeric tag
  in the JSON, would narrow that -- not measured.
- Values are carried as **text** in both JSON and TLV (a number is its digits).
  A binary-integer TLV would be smaller than 147 B; this is the pessimistic TLV.
- Packet framing is not counted for any format.
- Times are one machine, three passes, a 1 us-class clock (QueryPerformanceCounter);
  read them as orders of magnitude.
- The fixed 376 bytes also costs nothing to parse; the table has no row for it
  because the bench does not copy it.
- Not built: version negotiation, unknown-tag skipping, an actual server side.
  NY4I will bring tr4wserverpy down for that half.

## Decision for NY4I

The metrics support the direction (omit blanks + checksum). The open choice is
the encoding: **JSON omit** (readable, extensible, 116% of today) versus **TLV**
(39%, needs a tag registry that is the field order in `EmitFields`). Neither is
built into the product.
