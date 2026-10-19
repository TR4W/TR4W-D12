# N1MM Logger+ User Defined Contest (UDC) harvest

Downloads the community-written UDC files from the N1MM Logger+ download
library and turns them into one searchable index, so a contest-factory agent
can look for gaps in TR4W's contest data: Cabrillo names, display names,
bands and modes, exchange layout, section and multiplier lists.

**This is a research aid, not a source of truth.** UDC files are written by
volunteers for a different program, are not reviewed against the sponsors'
rules, and are frequently approximate (a wrong Cabrillo name, a missing
multiplier). Rank them **below the D7 tree, the sponsor's published rules and
WA7BNM**. A difference between a UDC and TR4W is a lead to check, never a
verdict. We are not adding every UDC contest to TR4W.

The downloaded files are third-party and this repository is public:
`tools/udc/cache/` is in `.gitignore`. Never commit anything from it.

## Run

```
python -I tools/udc/fetch_udc.py        # ~15 minutes the first time, resumable
python -I tools/udc/parse_udc.py        # seconds
python tools/udc/test_parse_udc.py      # the parser test (exit 0 = pass)
```

`fetch_udc.py` options: `--cache DIR`, `--delay SECONDS` (default 1.0),
`--limit N` (first N entries only, for trying it out). It sends a real
User-Agent, waits between requests, retries with backoff, logs a failure and
keeps going, and skips any file already in the cache, so re-running after an
interruption (or later, to pick up new uploads) only fetches what is missing.

The download library serves a file by a form POST (a plain GET returns the
HTML page), so the fetcher opens each entry's page, reads the download form's
nonce and posts it. That is why it needs two requests per new file.

## What lands in `tools/udc/cache/`

| path | what |
|---|---|
| `files/` | the downloaded `.udc` and `.zip` files, byte for byte |
| `manifest.json` | one record per listing entry: title, date, author, description, page URL, download URL, file name, size, sha256, status |
| `display_names.json` | one record per heading on the manual's "Setup User Defined Contests" page: display name, description, file name(s) |
| `extracted/<zip>/` | the text members of each ZIP (written by `parse_udc.py`) |
| `udc_index.json` | the full result: `stats`, `failures`, and one record per `.udc` |
| `udc_index.csv` | the useful columns, flat. UTF-8 with BOM, every field quoted, CRLF |
| `fetch.log` | only if you redirect the fetcher's output to it |

ZIP members are treated as untrusted data: nothing is executed; a member is
written only if its path stays inside its extraction directory, it is not a
link or encrypted, it is under 10 MB (50 MB per archive, no extreme
compression ratio), and it looks like text. Skipped members are still listed,
with the reason. Encodings handled: UTF-16 (BOM or not), UTF-8 (BOM or not),
else cp1252.

## `udc_index.json` record

`source_file`, `udc_member`, `encoding`; `listing` (the library entry:
title, date, page URL, download URL, author, description); `display_page`
(the manual's heading for this contest, if one matched by page or file name);
`author`, `file` (the `[Author]` and `[File]` sections); `contest` (every
`[Contest]` key exactly as written -- keys are case-sensitive); `other_sections`;
`cabrillo_fields`, `entry_window_fields`, `log_info_fields` (parsed
name/width pairs, in order); `bands_modes`; `external_list` (the
`MultWindowType` name when it is not a built-in list, and whether the ZIP
carries a matching `.sec`); `companions`; `warnings`.

A **companion** is a ZIP member other than a `.udc`: `name`, `size`,
`encoding`, `line_count`, `first_lines`, `skipped` (reason, if not read), and
`referenced_by` -- the `Section.Key` entries in the `.udc` whose value names
that file (e.g. `Contest.MultWindowType` for a `.sec`, `Contest.BonusPoints2`
for a call list). These are the nearest equivalent of TR4W's `.dom` files.

## CSV columns

Definitions come from `UDC_HELP.txt` (N1MM's UDC editor help, last updated
11/28/2024). Empty means the key was absent or blank, in which case the logger
uses the documented default.

| column | meaning |
|---|---|
| Name | `[Contest] Name`: the short internal name, capitals, max 10 characters. It names the contest in the logger's selection list and its log folder |
| DisplayName | `DisplayName`: free text, max 50 characters, what the operator sees |
| CabrilloName | `CabrilloName`: the `CONTEST:` header value, no spaces, max 15 characters per the help (many files exceed it) |
| Mode | `Mode`: `CW`, `SSB`, `BOTH` or `RTTY` (BOTH = all modes) |
| MultiplierBands | `MultiplierBands`: 1 = HF contest bands, 2 = all HF bands, 3 = HF contest bands plus 6 m and 2 m, 4 = all VHF bands. There is **no per-band list** in a UDC; this and ShowWarcBands are as close as it gets to "bands" |
| ShowWarcBands | `ShowWarcBands`: True shows the WARC bands (default False) |
| EntryWindowFields | the field names from `EntryWindowInfo`, in order: the logging entry boxes (`SNTText` sent RST, `SntNrText` sent serial, `RCVText` received RST, `RcvNrText` received serial, `Exchange1Text` exchange, `NameText`, `CommentText`, `GridSquareText`, `MiscText`, `SectText`). Each is followed by a pixel width in the raw key; widths are in the JSON |
| FrameText | `FrameText`: the column captions shown above those boxes (free text) -- often the best statement of what the exchange IS |
| DefaultContestExchange | `DefaultContestExchange`: the sent exchange; a leading `001` means the logger numbers QSOs |
| QsoErrorString | `QsoErrorString`: validation of the received exchange: `Numeric`, `Any` (each optionally `_not_Empty`), `Grid`, or the name of a `.sec` file whose entries are the only legal values |
| Multiplier1Name, 2, 3 | `Multiplier1Name`...: what the multiplier is: `CountryPrefix`, `WPXPrefix`, `Sect`, `ZN`, `MiscText`, `Continent`, `GridSquare`, `Comment`, `N/A` |
| MultSqlString, 2, 3 | `MultSqlString`...: the rule that counts a multiplier (`CountryPrefix`, `Section`, `WPXPrefix`, `Grid`, `SGrid`, `CQZONE`, `IARUZONE`, `Misc`, `Exchange`, `CallSign`, `FirstQSO`, `CAllHist`, `FIELD`, `LASTLETTER`, `2LPREFIX`, `N/A`; continent-limited forms such as `EU_Country`) |
| MultWindowType | `MultWindowType`: which section list the multiplier window shows: a built-in (`State`, `StateProvince`, `Province`, `Section`, `Provincie`, `DOK`, `UBA`, `Oblast`) or the name of a `.sec` file (max 9 characters) in the ZIP |
| PointsPerContact | `PointsPerContact`: a point rule list, e.g. `SameContinent, 1, OtherContinent, 3` |
| CabrilloFormat | `CabrilloFormat`: 1 standard, 2 NAQP, 3 NASPRINT, 4 SS, 5 RFC, 99 hand-coded from CabrilloString, 0 no Cabrillo |
| CabrilloVersion | `CabrilloVersion`: 2.0 (default) or 3.0 |
| CabrilloString | `CabrilloString`: the raw `QSO:` line layout (see below) |
| CabrilloFields | the same, parsed: `Field:width` pairs in order |
| CompanionFiles | the non-`.udc` members of the ZIP, with line counts |
| ListingTitle, ListingDate | the library entry's title and publish date |
| DisplayPageName | the contest's display name on the manual's UDC page, if matched |
| SourceFile | the cached file; UdcMember is the `.udc` inside it (a ZIP can hold several) |
| SourceURL, DownloadURL | the library entry's page and its download form's address |
| Warnings | parse problems: duplicate keys, a key spelled with the wrong case, an odd-length CabrilloString, `CabrilloFormat` 99 with no string |

### CabrilloString

`CabrilloString = SNT, 4, SentNr, 4, CallSign, 13, RCV, 4, Exchange1, 4` is
`field, width, field, width ...`: the columns of the `QSO:` line after the
frequency, mode, date, time and the sender's own call, which the logger writes
itself. Valid field names: `SNT` (sent RST), `SentNr` (sent serial), `CallSign`
(the worked station), `RCV` (received RST), `RcvNr`, `Comment`, `GridSquare`,
`Exchange1`, `Name`, `SentExch`, `SentExchPart1..3`, `Misc`, `LastExch`, `Sect`.
`Space, N` inserts N blanks. The width is the column width, not a sum of
content. The parsed list keeps `Space` as a field. `GenericPrintString` (not
Cabrillo; the optional generic export) uses the same grammar and is parsed
into the JSON as well, but is not a CSV column.

`EntryWindowInfo` and `LogInfo` use the same name/width grammar (widths are
screen units, not characters).

### Other keys

Every `[Contest]` key is in the JSON `contest` object and counted in
`stats.contest_key_counts`. Keys the CSV leaves out: scoring detail
(`BonusPoints`, `PointsMult*`, `DupeType`, `IsMult*Per`), contest times
(`StartOfContest`, `EndOfContest`, `MultipleSessions`), `SpecialInstructions`,
`IsWorkable` and the band-change counters.

Note that real files sometimes spell a documented key differently from the
help (for example `PointMultAtTimeLocal` where the help says
`PointsMultAtTimeLocal`). The index keeps what the file says.

## Joining to the manual page

The manual's "Setup User Defined Contests" page lists each contest's display
name, a description and its file name(s). `parse_udc.py` joins that to a
`.udc` by the library entry's page URL first, then by the `.udc` or ZIP file
name. A contest with no match has `display_page: null`; there is no fuzzy
matching.

## Cross-walk against TR4W's contests

```
python -I tools/udc/crosswalk.py [--q98 CSV] [--cache DIR]
```

Matches each UDC record to a TR4W contest and writes
`cache/crosswalk.csv` (UTF-8 BOM, every field quoted, CRLF; gitignored like
the rest of the cache). The dated reading and the leads worth acting on are in
`docs/UDC_CROSSWALK_FINDINGS.md`; regenerate both together.

TR4W's side is read from the tree, never from the running program: the
contest matrix's frozen records (`tr4w/test/contest-matrix/frozen`: id, class,
the Cabrillo `CONTEST:` line and one `QSO:` line per station variant, the ADIF
record, the domestic file), the display names pinned in
`tr4w/test/unit/uTestContestIdentityPin.pas`, and `tr4w/target/dom`.
`--q98` names the bands/modes table: the resolved Q98 table
(`contest_id, resolution, bands, modes, ...`) when you have it, else
`docs/Q98_CONTEST_BANDS_MODES.csv` by default.

Matching never guesses silently. Methods, strongest first: `cabrillo-exact`,
`cabrillo-normalized` (case, blanks, `-`, `_` folded), `cabrillo-to-id`
(TR4W's registry or ADIF id), `name-to-id` (the UDC's short Name),
`display-exact`, `curated` (`CURATED_MATCHES` in the script, each with the
evidence). One method tying a UDC to several contests is resolved by the UDC's
Mode only when that picks exactly one; otherwise every candidate is an
`ambiguous-match` row. Shared display words give `match-candidate` rows, and
`CANDIDATE_LEADS` adds hand-found ones: neither counts as a match.

| `finding_kind` | what |
|---|---|
| `match` | one row per matched UDC record, with the method |
| `cabrillo-name` | TR4W's `CONTEST:` name differs from the UDC's |
| `exchange-layout` | the kinds (report / serial / other) of the `QSO:` columns either side of the worked call differ from every TR4W station variant's; a lead for the sponsor's Cabrillo template |
| `mode`, `bands` | only where the Q98 table states none |
| `section-list` | the UDC's `.sec` against the TR4W `.dom` with the largest overlap (`INCLUDE FILE` followed): UDC entries TR4W does not accept, TR4W multipliers no UDC entry names |
| `q98-open` | a UDC that identifies (or, `Q98_LEADS`, may identify) a contest Q98 still has open; an open contest no UDC touches gets one row saying so |
| `ambiguous-match`, `match-candidate` | for a human to confirm |
| `not-in-tr4w` | UDC contests TR4W lacks -- a reference list, not a to-do list |

## Limits

- Only the English UDC help is used for definitions.
- A UDC holds no band list, no category list and no entry-point for sponsor
  rules; those cannot be harvested from it.
- The index reflects the library on the day it was fetched; re-run
  `fetch_udc.py` to pick up new uploads, then `parse_udc.py`.
