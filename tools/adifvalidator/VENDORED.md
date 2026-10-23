# Vendored: K1MU's ADIF validator

| | |
|---|---|
| origin | https://github.com/k1mu/adifvalidator |
| licence | MIT (`LICENSE`, copyright K1MU) |
| commit | `61b2e92`, 2022-08-01 (HEAD of the clone it was copied from) |
| vendored | 2026-10-23, from a local clone at `C:\projects\adifvalidator` |
| files | `adifparse.py`, `adiftags.py`, `LICENSE`, `README.md` (not `__pycache__`) |

## Why it is here

TR4W's golden corpus byte-compares the ADIF it writes against D7 references, and
the D7 references are themselves not valid ADIF (they carry `<MODE:4>DATA`). A
byte comparison proves "the same as before"; it cannot prove "valid". This is an
INDEPENDENT judge of the second question, written by someone else against the
ADIF specification, and rickmurphy.net's validator, which rejected NY4I's
`<MODE:4>DATA` file on 2026-10-23, is the same kind of tool.

It is vendored, like Indy, rather than fetched: the gate that uses it
(`tr4w/test/adif-validate/validate-adif-outputs.sh`) must run on a clean clone
with no network, and its last commit is from 2022. **It is Python with
TABS. Leave its indentation as it is** -- the project's three-space rule does not
apply to vendored code, and a reformat would make every upstream diff unreadable.

## How it is run

    python tools/adifvalidator/adifparse.py -f <file> [-a compliance.txt] [-c consistency.txt]

It always exits 0; the verdict is in its output. The gate counts the lines
`ADIF Compliance error` (the file is not valid ADIF -- fails the run) and
`Consistency error` (a judgement about the DATA: a zone that does not fit a
country, a state with no DXCC entity -- reported and counted, never a verdict),
and treats a run that never printed `Informational: Handled ...` as a crash.

## Local patches

Each is marked in `adiftags.py` or `adifparse.py` with `TR4W LOCAL PATCH`. Nothing else was
changed ("modernised") -- the version is otherwise upstream's byte for byte.

| patch | table | why | ADIF version that added the field |
|---|---|---|---|
| `MY_ARRL_SECT : E` | `qsoTags` | TR4W writes it; upstream had the section enumeration (`enumerations['MY_ARRL_SECT']`) but not the field, so every record was "not a valid tag" | 3.1.3 |
| `MY_POTA_REF : S` | `qsoTags` | TR4W writes it for POTA | 3.1.4 |
| `POTA_REF : S` | `qsoTags` | TR4W writes it for POTA | 3.1.4 |
| `verifyGrid` accepts a 2-character locator | `adifparse.py` | upstream rejects any grid under 4 characters; ADIF 3.1.6's GridSquare is "a 2-character, 4-character, 6-character, or 8-character Maidenhead locator", so a field (two letters A-R) is valid. Found by the contest matrix, 2026-10-23 | GridSquare data type, 3.1.6 |
| `ARRL_SECT` and `MY_ARRL_SECT` value lists | `enumerations` | upstream's 2022 list is stale: it lacks GH (Golden Horseshoe), NB, NS, TER (all added 2023-01-01), PE (2020-04-01), and the ONE/ONN/ONS split that came with 3.1.x. Replaced by the 90 codes of the ADIF 3.1.6 Section enumeration, III.B.2, **deleted codes included** (GTA, MAR, NT, NWT, ON are marked deleted but are still enumerated) | the Section enumeration is 3.1.6's; the codes were added 2012 to 2023 |

Checked and NOT patched:

* MODE/SUBMODE pairs TR4W now writes (`DIGITALVOICE/C4FM`, `DIGITALVOICE/DSTAR`,
  `PSK/PSK63`, `MFSK/JS8`, `MFSK/FT4`, `SSB/USB`, `SSB/LSB`) are all accepted.
* A free-text header preamble ("ADIF File", "Created by TR4W ...", and the
  "N QSO(s) logged in an unspecified DATA mode are exported as MODE RTTY." line)
  is accepted (ADIF 3.1.6 IV.A.3 allows any text before the first tag).
* `DOK` (WAG) and `FOC_NUM` (FOC Marathon) are rejected as unknown tags, and
  that is CORRECT: neither is a field of ADIF 3.1.6 (the WAG's is `DARC_DOK`).
  They are TR4W findings, deliberately left visible rather than patched in.
* Upstream is stale relative to ADIF 3.1.6 in places (it lists enumeration
  values from 3.1.3-era). Patch a table only when a field or value TR4W writes
  is missing, and record it here.
