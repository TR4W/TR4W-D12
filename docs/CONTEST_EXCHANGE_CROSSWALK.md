# `ContestExchange` → the `qso` row — every field

**Task A1 of [`SQLITE_MIGRATION_TASKS.md`](SQLITE_MIGRATION_TASKS.md).** All 71
fields of the record, each mapped to a column or recorded as not persisted
**with the reason**. Measured against `VC.pas` and the code that reads and writes
each field, 2026-09-01.

**The list is the deliverable, not a summary of it.** CLAUDE.md rule 9: a
silently defaulted field reads as a legal zero, and an undeclared capability, an
uninitialised `maxLen` and a wholesale `DefineCapabilities` override have each
produced exactly that defect in this tree. A field quietly missing from this
table is the same class of bug, one layer down.

---

## Two findings that change the design

### 1. The record has NO sent-exchange field. That IS issue #2.

`ExchString` is documented as *"What is entered as SRX exchange"* and
`PerQSOExchString` (`MainUnit.pas:695`) builds it from `RSTReceived` and
`QTHString`. It is the **received** exchange.

There is no counterpart. Nothing in the 71 fields records what we **sent** —
which is exactly why the sent half is rebuilt from station globals at export
time, and why two of the four corpus known-divergences exist.

So `exchange_sent` is a column with **no source in the record**. It cannot be
populated by the importer and it is not the mapper's job. It is filled at log
time in **Phase C**, and that is the whole event-sourcing fix stated
structurally rather than as a complaint.

### 2. Eleven `rcvd_*` columns have no record source, because the record has ONE polymorphic QTH field

The schema names `rcvd_state`, `rcvd_section`, `rcvd_grid`, `rcvd_postal_code`,
`rcvd_society`, `rcvd_department`, `rcvd_rda`, `rcvd_park`, `rcvd_summit`,
`rcvd_iota` and `rcvd_coords`. The record has **`QTHString`** — *"QTH received by
user (literal)"* — and that one field is whichever of those the contest asked
for.

**This is a genuine coupling to the contest factory** and it is worth being plain
about, because it is a piece of NY4I's *"the database may be more tied to the
contest factory than we think"* that turns out to be correct.

**It is not, however, data loss, and it does not block anything.** The rule:

- the importer and the mapper store the **literal** in `rcvd_qth`, always;
- the eleven specific columns are an **enrichment** the contest factory writes
  when it knows what the exchange meant;
- nothing is lost in the meantime, because the literal is what the operator
  actually copied.

Deciding to fill `rcvd_grid` from `QTHString` in the mapper would mean the mapper
knowing the contest, which is the fusion this whole ordering exists to avoid.

**The same shape appears once more:** `QTH.Zone` is one byte serving both the CQ
and the ITU zone, exactly as `MyZone` does on the sending side (§12a). The
importer fills `cty_cq_zone` and leaves `cty_itu_zone` NULL rather than guessing;
the factory knows which the contest wanted.

---

## Mapped to a column that already exists

| # | field | type | column | note |
|---|---|---|---|---|
| 1 | `tSysTime` | `TQSOTime` | `qso_at` | Y/M/D/H/M/S **bytes**. `qtYear` is `year - 2000`, verified — see the section below |
| 2 | `Band` | `BandType` | `band` | enum → token |
| 3 | `Mode` | `ModeType` | `mode` | `CW, Digital, Phone, Both, NoMode, FM` |
| 6 | `Frequency` | `LONGINT` | `freq_tx_hz` | **Hz** — verified: `uExternalLogger:333` divides by 1,000,000 for MHz, `PostUnit:2914` by 1,000 for kHz. No conversion |
| 7 | `ceQSO_Deleted` | `boolean` | `deleted` | |
| 12 | `ceSendToServer` | `boolean` | `sent_to_server` | |
| 13 | `ceNeedSendToServerAE` | `boolean` | `server_dirty` | the record's own precedent for the distribution-state block |
| 14 | `ceDupe` | `boolean` | `is_dupe` | |
| 19 | `Callsign` | `CallString` | `callsign` | |
| 20 | `Age` | `byte` | `rcvd_age` | |
| 26 | `ExtMode` | `ExtendedModeType` | `submode` | `eFT8`, `eUSB`, `eCW_R` … from the radio (`MainUnit:6812`) |
| 27 | `ExchString` | `Str40` | `exchange_received` | the RECEIVED exchange — see finding 1 |
| 28 | `ceClass` | `string[3]` | `rcvd_class` | Field Day "2A" |
| 30 | `Precedence` | `AnsiChar` | `rcvd_precedence` | Sweepstakes |
| 31 | `ceRadio` | `RadioType` | `radio_nr` | `NoRadio, RadioOne, RadioTwo` → 0/1/2 |
| 32 | `Check` | `Byte` | `rcvd_check` | Sweepstakes 2-digit year |
| 41 | `Name` | `Str10` | `rcvd_name` | |
| 43 | `Power` | `string[6]` | `rcvd_power` | ARRL DX |
| 45 | `NumberReceived` | `integer` | `serial_received` | |
| 46 | `NumberSent` | `integer` | `serial_sent` | |
| 47 | `RSTSent` | `smallInt` | `rst_sent` | |
| 48 | `RSTReceived` | `smallInt` | `rst_received` | the record comment wishes this were an int for FT8 reports; the schema gives that its own `snr_received` |
| 49 | `QTHString` | `Str10` | `rcvd_qth` | **the polymorphic one** — finding 2 |
| 52 | `TenTenNum` | `word` | `rcvd_member_no` | |
| 53 | `Chapter` | `string[4]` | `rcvd_chapter` | |
| 56 | `ceSearchAndPounce` | `boolean` | `is_run` | **INVERTED.** S&P is the opposite of run, and getting this backwards is invisible |
| 57 | `Prefecture` | `Byte` | `rcvd_prefecture` | JA |
| 59 | `Zone` | `Byte` | `rcvd_zone` | the zone he SENT — outranks `cty_*` (§4a) |
| 63 | `QSOPoints` | `word` | `qso_points` | |
| 64 | `RandomCharsReceived` | `string[7]` | `rcvd_random` | |
| 68 | `ceOperator` | `OperatorType` | `operator_call` | `CurrentOperator` (`MainUnit:9123`); 11 chars |
| 69 | `id` | `string[32]` | `guid` | **already a per-QSO GUID** — `RescoredRXData^.id := GetGUID`, set on ADIF import, emitted by HamScore as `<ID>`. Do not invent a second identity |

### `QTH: QTHRecord` (field 33) expands into six

| sub-field | column | note |
|---|---|---|
| `CountryID` | `dxcc_entity` | |
| `Zone` | `cty_cq_zone` | **one byte serving two zones** — see finding 2 |
| `Prefix` | `dxcc_prefix` | the CTY.DAT prefix, NOT the WPX multiplier (field 17) |
| `Continent` | `cty_continent` | |
| `StandardCall` | **NEW** `standard_call` | the resolved callsign; no column existed |
| `Country` | `dxcc_code` | |

---

## Needs a NEW column

Adding these is free **now** — the schema is version 1 and no operator has a log.
It stops being free the day one does.

| # | field | type | new column | why it must be kept |
|---|---|---|---|---|
| 4 | `ceQSOID1` | `Cardinal` | `session_id` | `STARTTIMEOFTHETR4W` (`MainUnit:9115`). With the next field it is the **network identity**: `tr4wserverUnit:547-548` matches records on both |
| 5 | `ceQSOID2` | `Cardinal` | `session_seq` | `GetTickCount` (`LOGSUBS2:1556`). Also how WAE links a QTC to its QSO — `LOGWAE:266` stores it as `qsQSOID2` |
| 8 | `ceComputerID` | `AnsiChar` | `computer_id` | **the multi-op station letter.** It is how each station knows which QSOs are its own and which are foreign, and `PostUnit:3028` derives the Cabrillo transmitter digit from it. Dropping it would silently break multi-op |
| 9 | `ceOperatorID` | `Byte` | `operator_id` | **no live reader** — it survives only in the version-migration copies. Kept for import fidelity and flagged here rather than dropped, because "no reader today" is not "no meaning" |
| 10 | `ceRecordKind` | `LogRecordKind` | `record_kind` | `rkQSO, rkQTCR, rkQTCS, rkNote`. **A log record is not always a QSO**, and several fields below mean different things depending on it |
| 11 | `ceQSO_Skiped` | `boolean` | `is_skipped` | read by the scoring paths (`MainUnit:7688, 7963, 8539`) — a skipped QSO is not scored |
| 17 | `Prefix` | `PrefixMultiplierString` | `prefix_mult` | the **WPX prefix multiplier**, which is not `QTH.Prefix` from CTY.DAT. Two different facts, similar names |
| 21 | `ceWasSendInQTC` | `Boolean` | `sent_in_qtc` | WAE: whether this QSO has already gone out in a QTC book. Losing it means sending it twice |
| 22 | `DomesticMult` | `boolean` | `mult_domestic` | |
| 23 | `DXMult` | `boolean` | `mult_dx` | |
| 24 | `PrefixMult` | `boolean` | `mult_prefix` | |
| 25 | `ZoneMult` | `boolean` | `mult_zone` | |
| 34 | `DXQTH` | `DXMultiplierString` | `dx_mult` | the DX multiplier as counted |
| 37 | `DomMultQTH` | `DomesticMultiplierString` | `domestic_mult` | *"String for dom mult count"* |
| 39 | `DomesticQTH` | `Str10` | `domestic_qth` | *"Corrected QTH"* — `AF1` → `AF-001` in IOTA. The corrected form, distinct from the literal in `rcvd_qth` |
| 51 | `RandomCharsSent` | `string[5]` | `random_sent` | the received counterpart already has `rcvd_random` |
| 55 | `ceClearDupeSheet` | `boolean` | `clear_dupe_sheet` | a **stream marker**, not UI state — set on a record (`MainUnit:738`) and read during rescore (`8517`) |
| 60 | `NameSent` | `boolean` | `name_sent` | set by `LOGSTUFF:1204` |
| 61 | `Kids` | `Str20` | `rcvd_kids` **and** `qtc_call` | **OVERLOADED BY RECORD KIND — two columns, not one** (see below) |
| 66 | `ceClearMultSheet` | `Boolean` | `clear_mult_sheet` | same as 55; `tr4wserverUnit:1012` sets it too |
| 67 | `MP3Record` | `Boolean` | `mp3_recorded` | an MP3 exists on disk for this QSO (`LOGSUBS2:1561`, read by `uEditQSO:178`) |
| 70 | `ceXQSO` | `Boolean` | `is_xqso` | **NOT `deleted`.** The record's own comment: the contact happened and is kept for the other station's NIL protection, but is not claimed — excluded from QSO count, multipliers, points and dupe checking. Folding it into `deleted` would silently change what a submitted log claims |

### Why `Kids` becomes two columns

`Kids` is declared *"used for whole ex string"* and that is true only for
`rkQSO`. In a QTC record it holds a **callsign**:

```pascal
uQTCR.pas:340   QTCRXData.Kids := frm.RowCall(i);
uQTCS.pas:283   QTCRXData.Kids := QTCsToBeSendArray[I].qsCall;
LOGSTUFF:1342   RData.Kids := ExchangeString;      { ProcessKidsExchange }
```

One column meaning "either the Kids exchange text or a third-party callsign,
depending on a different column" is precisely the kind of thing that produces a
wrong Cabrillo line two years later. Two columns cost nothing.

*(Note: `LOGDUPE:1700`'s `ExchangeInformation.Kids := True` is a **different
record type** with a boolean of the same name. Not this field.)*

---

## Not persisted

| # | field | why not |
|---|---|---|
| 15 | `PostalCode_old` | **dead — zero references in the tree.** The name says it |
| 16, 18, 29, 35, 38, 40, 42, 44, 50, 54, 65 | `ZERO_01` … `ZERO_13` | `DummyByte` alignment padding for the on-disk layout. Meaningless outside the binary format we are leaving |
| 36 | `Radio` | `InterfacedRadioType` — the radio **model**. A station setting, not a fact about a contact. **Flagged for NY4I rather than assumed**: if a multi-op wants to know which rig made a QSO, `radio_nr` (field 31) already answers the useful form of it |
| 62 | `ceContest` | belongs on the **contest row** (`contest_type`), not on ten thousand QSO rows. One log is one contest — `CHECK (id = 1)` |
| 71 | `sReserved` | `string[49]` of spare bytes. Its last byte was harvested for `ceXQSO` (issue #750), which is exactly what reserved space is for and exactly what a database does not need |

---

## Columns with no record source

Not omissions — destinations. Listed so nobody looks for a field to fill them.

| column | filled by |
|---|---|
| `exchange_sent` | **Phase C**, at log time. Finding 1 |
| `my_county`, `my_grid`, `my_state` | **Phase C** — tier 3, from the station globals at the moment of the QSO |
| `freq_rx_hz` | split working. The record has one `Frequency`; nothing is lost, there was never a second |
| `snr_sent`, `snr_received` | WSJT-X dB reports, which the record squeezes into `RSTReceived` |
| `cty_itu_zone` | the contest factory. `QTH.Zone` is one byte for both zones |
| the eleven specific `rcvd_*` | the contest factory. Finding 2 |
| `notes`, `sent_udp`, `udp_dirty` | new state with no predecessor |
| `contest`.* | the contest row, at log creation (Phase C/E) |

---

## `TQSOTime.qtYear` — answered, and there is a latent divergence beside it

```pascal
TQSOTime = packed record
  qtYear, qtMonth, qtDay, qtHour, qtMinute, qtSecond: Byte;
end;
```

A byte cannot hold 2026, so this needed settling before anything read a fixture.
**`qtYear` is the year minus 2000**, and writer and reader agree:

```pascal
tree.pas:4212     Time.qtYear := UTC.wYear - 2000;
uEditQSO:443      ...qtSysTime.qtYear := TempSysTime.wYear - 2000;
logdump.lpr:170   rec.tSysTime.qtYear + 2000
```

So the conversion is `qtYear + 2000`, and `logdump` — already cross-checked
against ADIF export — is the reference implementation. Pin it anyway with a test
that reads a known corpus log and asserts a known date: a wrong epoch moves every
QSO by a century and fails nothing.

**The latent divergence, recorded because it is one line away from this and
nobody has looked at it:** the ADIF importer does not use the same formula.

```pascal
uADIF.pas:656   qsoTime.qtYear := Ord(StrToInt(MidStr(sDate, 1, 4)) mod 100);
```

`mod 100` and `- 2000` agree for **this century only**. They differ for any date
before 2000 or after 2099 — an imported historical log from 1998 would land in
2098. Not in scope for the migration, and not a reason to touch `uADIF` now, but
the SQLite column is a proper unix timestamp with no such limit, so this is worth
fixing when ADIF import is next opened rather than being carried across.
