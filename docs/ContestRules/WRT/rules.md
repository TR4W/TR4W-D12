# WRT, the Weekly RTTY Test -- sponsor rules

Source: https://radiosport.world/wrt.html (organizers N3QE Tim Shoppa and WV4P Ron Koenig).
Fetched 2026-11-15 for issue 25. The organizers' own N1MM+ module is beside this file as
`WRT.udc` (revision 1.0.2, 2024-01-04), downloaded from the same page.

## General Rules (verbatim)

- Held every Thursday night, 0145-0215Z (Friday UTC)
- Everyone Works Everyone
- Each unique call (once per session) is a multiplier
- 1 Point per QSO
- 10, 15, 20, 40, and 80 Meter bands
- 100 Watt (Low-Power) and 5 Watt (QRP) Categories.

## Suggested Frequencies (verbatim)

3.585-3.590, 7.083-7.090, 14.083-14.090, 21.083-21.090, and 28.083-28.090 MHz

## Exchange (verbatim)

- W/VE - Name and State
- DX - Name and Country Prefix

## Logging (abridged)

N1MM users can use the WRT UDC module. For other loggers without WRT support, we suggest
using the NAQP contest. Ignore the logger's multiplier count; instead manually count unique
callsigns per session for the multiplier.

## Reporting

Report your results on 3830scores.com. Hamscore real-time scoring is supported.

## What the UDC adds (the organizers' file, not the rules page)

- `CabrilloName = WRT`, `Mode = RTTY`, `PointsPerContact = 1`
- `Multiplier1Name = CallSign`, `MultSqlString = CallSign`, `IsMultPer = 4`
- `DupeType = 2`
- `DefaultContestExchange = Name State`
- `CabrilloString = SentExchPart1, 10, SentExchPart2, 10, CallSign, 13, Name, 10, Exchange1, 4`

## Silent in the rules

The rules page does not say whether a station may be worked once per band or once per
session. The UDC's `DupeType = 2` encodes the organizers' answer in N1MM's numbering.

**Answered (NY4I, issue 25):** `DupeType = 2` is "Each band (stations may be worked once on
each band)". DXLog.net's definition (`Contest\WRT.txt`, updated 2026-07-31) agrees:
`DOUBLE_QSO=PER_BAND`.

## Names TR4W uses (2026-11-22, `uContestWRT`)

- Contest id (stored): `WRT`.
- Cabrillo `CONTEST:` `WRT` -- the UDC's `CabrilloName` and DXLog.net's
  `CABRILLO_CONTEST_NAME=WRT`; the rules page states none.
- ADIF `CONTEST_ID`: none exists in the ADIF 3.1.6 Contest_ID enumeration (checked
  2026-11-22), so TR4W writes and matches its own id, `WRT`.
- WA7BNM reference: not looked up (0).
