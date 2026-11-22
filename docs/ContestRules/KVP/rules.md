# KVP -- KV prvenstvo ZRS (the ZRS HF Championship)

TR4W contest: `KVP` (`tr4w/src/contestFactory/uContestKVP.pas`).

## Sources

| what | where | retrieved |
| --- | --- | --- |
| Rules (Slovenian, sponsor) | http://kvp.hamradio.si/pravila.html | 2026-11-22. The live host did not answer (connection failed on http and https). Read from the Internet Archive snapshot `http://web.archive.org/web/20250115213222/http://kvp.hamradio.si/pravila.html`. The text is in `pravila_kvp_zrs_sl.txt` beside this file, extracted verbatim. |
| Rules site home | http://kvp.hamradio.si/ | 2026-11-22, the Internet Archive snapshot `20250728174347`. This is the home page only. |
| ZRS event listing | https://www.hamradio.si/event/zrs-kvp-2/ | 2026-11-22, live. |
| Log reception (robot) | https://vhfmanager.net/modules/log_reception.php?ContestID=498&language=S5 | 2026-11-22, live. Accepts `.cbr`/`.log`/`.zip`. |

The rules say they were adopted by the ZRS board on 2013-01-29.

## Summary of the rules

This summary is our own English reading of the Slovenian text. The Slovenian text governs.

- **Sponsor (I):** Zveza radioamaterjev Slovenije (ZRS). Open to **Slovenian** licensed amateurs only.
- **When (II):** twice a year, in **April** (spring part) and **November** (autumn part). It runs on the Sunday of the third full weekend, **09:00 to 10:59 local time**.
  - The ZRS listing for 2026-11-22 gives 09:00-10:59 +01:00, which is 08:00-09:59 UTC.
- **Band and modes (III):** **80 m only**.
  - CW: 3510-3600 kHz.
  - SSB: 3600-3775 kHz.
  - A QSO is valid only CW-CW or SSB-SSB.
  - The same station may be worked once on CW and once on SSB.
  - Only one signal on the band at a time.
- **Exchange (IV):** RS(T) plus a **two-digit number**: the last two digits of the year of the operator's first licence exam. A club station sends the year its first club licence was issued.
  - Examples from the rules: `599 00` / `59 00`, and `599 63` / `59 63`.
- **Points (V):** SSB QSO **1** point, CW QSO **2** points. Incomplete and duplicate QSOs score 0.
- **Multipliers (VI):** each different two-digit number is one multiplier, **counted separately per mode** (CW and SSB).
  - The rule also says: *"Mnozitelj oddajan v tekmovanju se steje kot delan mnozitelj."* That is, **the multiplier you SEND counts as a worked multiplier.**
- **Score (VII):** (CW points + SSB points) x (CW multipliers + SSB multipliers).
  - Worked example: 25 CW + 45 SSB QSOs = 95 points; 20 + 30 = 50 multipliers; score 4750.
- **Categories (VIII):**
  - Power: HIGH (> 100 W), LOW (5 to 100 W), QRP (<= 5 W).
  - Mode: CW, SSB or CW/SSB.
  - Overlays: NOVINCI (rookie, licensed less than 3 years), EKIPE (teams of up to three stations, registered beforehand), RADIOKLUBI (club aggregate, by the CLUB field).
- **Log (IX):** Cabrillo, file named `<call>.cbr`, QSOs in time order.
  - Category line, one of:
    - `SINGLE-OP 80M HIGH|LOW|QRP CW|SSB|MIXED`
  - The rules' example log has these header lines:
    - `CONTEST: KV prvenstvo ZRS`
    - `CATEGORY-OVERLAY: ROOKIE`
    - `CLUB: S59ABC`
  - The example QSO lines are:
    - `QSO: 3500 CW 2005-11-20 0800 S59XXX 599 01 S52L 599 02`
    - `QSO: 3500 PH ...`
  - Unique QSOs, which cannot be checked against another log, are removed.
- **Deadline (X):** 5 days after the contest, through the log robot. `kvp@hamradio.si` is accepted only in exceptional cases.

## How TR4W's KVP class compares (2026-11-22, not changed here)

| rule | TR4W | agrees? |
| --- | --- | --- |
| Points CW 2 / SSB 1 | `FixedModePoints(Mode, 2, 1, 1)` | yes. Digital scores 1, but the contest has no digital. |
| Multiplier = distinct two-digit year, per mode | zone-kind sheet of 100 cells from 00, keyed on the received year (issue 298 stage 4), `cfMultByBand, cfMultByMode` | yes. By band is moot on one band. |
| Exchange RS(T) + two-digit year | `ParseRSTLicenceYear`, `rykTwoDigitYear` | yes |
| Own sent year counts as a worked multiplier (VI) | not implemented | **NO -- open** |
| 80 m only, CW/SSB only | `UsesBand` / `UsesMode` are the base's (every band, every mode) | **NO -- open** |
| Cabrillo `CONTEST:` | `KVP` | **differs from the rules' example `KV prvenstvo ZRS` -- open** |
| Cabrillo category `SINGLE-OP 80M ...` | not checked here | open |

## Not verified

- **WA7BNM calendar id.** None was found in the repo; the class states `GetWA7BNMId = 0`. The WA7BNM calendar is not to be scraped (its terms), so this was not looked up.
- **Whether the live rules differ from the archived 2025-01-15 copy.** The live host `kvp.hamradio.si` did not answer on 2026-11-22.
- **Whether the log robot requires a particular `CONTEST:` value.** We did not submit a test log.
- **The DXLog `S5KVP.txt` definition the class header cites.** It was not fetched in this pass.
