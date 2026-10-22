# URC DX RTTY Contest -- rules

- **Source:** the URC DX RTTY Contest page on UA9QCQ's log robot (ua9qcq.com), as
  pasted by NY4I on 2026-10-22; organiser's web site https://unicomradio.com.
- **Rules year:** the page shows the 2026 running (02 October 2026); its Cabrillo
  examples are dated 2024-10-04.
- Saved by NY4I; stripped to the rules text 2026-10-22 (site menu and login strip
  dropped). The territory list is `territories.md` beside this file.

## Dates

- Start: 1st Friday of October at 00:00 UTC (02 October 2026, 00:00).
- Finish: the same Friday at 23:59 UTC (02 October 2026, 23:59).

## Modes

RTTY

## Bands

160m, 80m, 40m, 20m, 15m, 10m

## Categories (classes)

- SINGLE-OP ALL HIGH
- SINGLE-OP ALL LOW
- MULTI-ONE

HIGH Power - There are no power limits;
LOW Power - Power output must not exceed 100 watts.
SINGLE-OP - Single operator performs all operating, logging, and spotting. Only one
signal allowed at a time.
Entrants must clearly state their output power in the Cabrillo log. Failure to do so
will result in automatic classification in the High Power category.
MULTI-ONE - Only one transmitter and one band are allowed at a time. There are no
power limits.
Transmitters and receivers must be situated within a 500-meter diameter circle or
within the station licensee's property limits, whichever is greater.
All antennas used by the entrant must be physically connected by wires to the
transmitters and receivers.
Only the entrant's callsign may be used to contribute to their score. A different
callsign is required for each URC DX RTTY Contest entry.
All categories may use packet and web clusters.

## Exchanges

Each station must send a signal report (RST) followed by a 3-letter territory code
based on the URC Territories List.

For example:

- GM2G in Glasgow, Scotland: 599 SCO
- UN8LX in Qostanay Region: 599 QTY
- YO9HP in Southern Romania: 599 SRO

Maritime mobile stations should send the signal report (RST) followed by the MMS
territory code, regardless of their location.

## Points for QSO

- Same Territory: 1 point, regardless of the band.
- Same Continent (Different Territory):
  - 2 points on 40, 20, 15 meters;
  - 3 points on 10, 80 meters;
  - 5 points on 160 meters.
- Different Continents:
  - 4 points on 40, 20, 15 meters;
  - 5 points on 10 meters;
  - 6 points on 80 meters;
  - 10 points on 160 meters.
- Maritime mobile stations: 3 points, regardless of the band.

## Multipliers

Territory Multiplier: 1 multiplier for each unique territory contacted per band.
Maritime mobile stations do not count as multipliers but are worth 3 points.
The URC DX RTTY Contest Territories List is available at Territories List
(`territories.md`).

## Score

The final score is calculated by multiplying the total QSO points by the sum of
territory multipliers.

## Logs

Logs must be in Cabrillo format, named after the callsign (e.g., gm4agg.cbr,
gm4agg.txt, gm4agg.log).
Double-check your log before submission. Only the categories listed in these rules are
allowed. Ensure the Cabrillo header is correctly filled out.

Sending of electronic logs: logs should be uploaded via the Web interface.

Deadline: logs must be submitted within 5 days after the contest ends.
For confirmation of log submission, contact UA9QCQ at oleg@ua9qcq.com if you do not
receive an acknowledgment within 48 hours.

## Awards

Trophies: First place in the World.

Certificates:

- First, Second, and Third places in the World.
- First place in each continent (Europe, Asia, Africa, North America, South America,
  and Oceania).

All results will be published on the official URC DX RTTY Contest website.
Certificates will be issued in high-resolution PDF format and sent via email to the
winners.

Sponsorship: Any radio amateur, radio club, or organization interested in sponsoring a
special trophy should contact the Contest Committee.

## Rule Violations, Penalties and Declaration

Participants may be disqualified for:

- Violating amateur radio regulations or contest rules.
- Unsportsmanlike conduct.
- Claiming excessive unverifiable contacts or multipliers.
- Using non-amateur means (e.g., phone, internet, packet) to solicit contacts.

Decisions by the URC DX RTTY Contest Committee are final and binding.

Web-site: https://unicomradio.com

## Cabrillo examples

QSO lines:

```text
000000000111111111122222222223333333333444444444455555555556666666666777777777788
123456789012345678901234567890123456789012345678901234567890123456789012345678901
                              -------transmitted------ -------received---------
**** ***** ** ********** **** ************* *** ****** ************* *** ****** *
QSO:  7040 RY 2024-10-04 0000 UA8AAA        599 CLB     UA5GGG        599 LPK
QSO: 14073 RY 2024-10-04 0005 UA8AAA        599 CLB     KK2EEE        599 NJR
```

Header, SINGLE-OP ALL HIGH (Cabrillo 3.0 format):

```text
START-OF-LOG: 3.0
CONTEST: URCDX
CALLSIGN: UA8AAA
CATEGORY-OPERATOR: SINGLE-OP
CATEGORY-BAND: ALL
CATEGORY-POWER: HIGH
LOCATION: CB07
GRID-LOCATOR: MO05QE
NAME: Ivan Ivanov
ADDRESS: ul. Lenina 17-1
ADDRESS-CITY: Chelaybinsk
ADDRESS-POSTALCODE: 454111
ADDRESS-COUNTRY: Russia
EMAIL: ua8aaa@yandex.ru
```

SINGLE-OP ALL LOW is the same with `CATEGORY-POWER: LOW`.

Header, MULTI-ONE (Cabrillo 3.0 format):

```text
START-OF-LOG: 3.0
CONTEST: URCDX
CALLSIGN: UA8AAA
CATEGORY-OPERATOR: MULTI-OP
CATEGORY-TRANSMITTER: ONE
LOCATION: CB07
GRID-LOCATOR: MO05QE
OPERATORS: UA8AAA, UA8BBB
NAME: Ivan Ivanov
ADDRESS: ul. Lenina 17-1
ADDRESS-CITY: Chelaybinsk
ADDRESS-POSTALCODE: 454111
ADDRESS-COUNTRY: Russia
EMAIL: ua8aaa@yandex.ru
```
