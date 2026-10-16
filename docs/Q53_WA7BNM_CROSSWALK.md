# Q53 cross-walk: the 49 enum-spelled contests -> WA7BNM refs

Research date 2026-10-15, read-only. Branch `contestFactory`.

## Method and what the sources can and cannot say

- **WA7BNM's own complete list.** `https://www.contestcalendar.com/alphabetical.php`
  holds **719 contests, active and inactive** (inactive ones are greyed,
  CSS class `tgray`; every detail page fetched confirms grey = `Status: Inactive`).
  Every ref from 1 to 790 that is NOT on that page was fetched one at a time
  (3 s apart) and **all 71 return `[contest not found]`**, so the alphabetical
  page is the whole database. **"NONE FOUND" below therefore means WA7BNM does
  not list the event at all**, not that a search missed it.
  One oddity: ref 189 ("RSGB 2nd 1.8 MHz Contest, CW", grey) is on the
  alphabetical page but its detail page says `[contest not found]`.
- Detail pages (`contestdetails.php?ref=N`) were fetched for every candidate
  (48 pages, one at a time, 3 s apart) for name, status, Cabrillo name,
  exchange and rules URL.
- Identity was taken from the class header, its Cabrillo/ADIF names, its
  QRZ.RU id, the D7 `ContestsArray` row (`C:\TR4W\tr4w\src\VC.pas`) and
  DXLog.net's `C:\Program Files (x86)\DXLog.net\Contest\*.txt`.
- **qrz.ru could not be reached** from this machine (`curl` returned no HTTP
  status), so the QRZ.RU ids could not be used to identify the unknowns.
  One QRZ.RU link was usable indirectly: WA7BNM's own rules link for ref 595
  is `qrz.ru/contest/detail/86.html`, and 86 is `CUPRFDIG`'s QRZ.RU id.

Status is WA7BNM's (Active / Inactive). "Proposed friendly name" is WA7BNM's
exact name unless a reason is stated.

## The table

| enum | what it is | WA7BNM ref | WA7BNM's exact name | status | proposed friendly name | source URL | confidence |
|---|---|---|---|---|---|---|---|
| ALLJA | JARL ALL JA (domestic Japan) | NONE FOUND | -- | -- | (needs a name from NY4I; DXLog says "All JA Contest") | -- | high that WA7BNM does not list it (complete list checked) |
| ALRS_UA1DZ_CUP | UA1DZ Memorial Cup, run by ALRS | **697** | UA1DZ Memorial Cup | Active | UA1DZ Memorial Cup | https://www.contestcalendar.com/contestdetails.php?ref=697 | high -- WA7BNM's Cabrillo name is `ALRS-UA1DZ-CUP`, exactly ours; DXLog `UA1DZ.txt` agrees; exchange (RDA district / grid) matches |
| APSPRINT | Asia-Pacific Sprint (JSFC) | **248, 164, 42** (three events) | Asia-Pacific Spring Sprint, CW / Asia-Pacific Fall Sprint, CW / Asia-Pacific Sprint, SSB | all Active | one class, three events -- see "more than one" below | ref=248, ref=164, ref=42 | high on identity (rules jsfc.org/apsprint, Cabrillo `AP-SPRINT`); the choice of ONE ref is NY4I's |
| ARCI | QRP ARCI -- ALREADY DECIDED: split into six (F26) | 315 / 168 / 31 / 69 / 193 / 198 | QRP ARCI Spring QSO Party / QRP ARCI Fall QSO Party / QRP ARCI Hootowl Sprint / QRP ARCI Summer Homebrew Sprint / QRP ARCI Topband Sprint / QRP ARCI Holiday Homebrew Sprint | all six Active | per F26 | ref=315 etc. | names confirmed from the detail pages; not re-researched |
| BWQP | FOC Bill Windle QSO Party | **479** | Bill Windle QSO Party | Active | Bill Windle QSO Party | https://www.contestcalendar.com/contestdetails.php?ref=479 | medium -- DXLog `FOCBWQP.txt` is "FOC BW QSO PARTY" and WA7BNM's rules are g4foc.org; BUT WA7BNM's exchange is RST + name + FOC number, and our class's is `RSTNameAndQTHExchange` -- a rule question for NY4I, not an identity doubt |
| CUPRFCW | Russian Cup, CW (Кубок России, RF-CUP-CW) | NONE FOUND | -- | -- | (needs a name; DXLog: "Кубок России на КВ телеграфом") | -- | high that it is unlisted |
| CUPRFDIG | Russian Cup, Digital (RF-CUP-DIG) | **595** | Russian Cup Digital Contest | Active | Russian Cup Digital Contest | https://www.contestcalendar.com/contestdetails.php?ref=595 | high -- WA7BNM's rules link is qrz.ru contest **86**, which is our QRZ.RU id; exchange serial + grid matches `QSONumberAndGridSquare` |
| CUPRFSSB | Russian Cup, SSB (RF-CUP-SSB) | NONE FOUND | -- | -- | (DXLog: "Кубок России на КВ телефон") | -- | high that it is unlisted |
| CUPURAL | Ural Cup (URAL-CUP, radiochel.ru) | NONE FOUND | -- | -- | (DXLog: "Ural Cup") | -- | high that it is unlisted |
| EUDX | European Union DX Contest | **687** | European Union DX Contest | Active | European Union DX Contest | https://www.contestcalendar.com/contestdetails.php?ref=687 | high -- e-mail log.eudxc@gmail.com (D7 row), Cabrillo `EUDXC`, exchange region/ITU zone matches |
| EUROPEANVHF | a generic European VHF contest (9A point multipliers; the EURASIA case) | NONE FOUND | -- | -- | (needs a name) | -- | high that no single WA7BNM event is it; DXLog uses Cabrillo `EUROPEAN-VHF` for four different events |
| EUSPRINT_SPRING_CW | EU Sprint, spring, CW | **317** (ALREADY STATED by the class and the D7 row) | RSGB International Sprint Contest, CW | Inactive (last 2016) | RSGB International Sprint Contest, CW -- matches the SSB sibling, whose friendly name is already "RSGB International Sprint Contest, SSB" (316) | https://www.contestcalendar.com/contestdetails.php?ref=317 | high that 317 is what D7 meant; see the note below -- WA7BNM's name is a single year's host, and its only current EU Sprint entry is 731 "EU Sprint, SSB" |
| FOCMARATHON | FOC Marathon (members' event) | NONE FOUND | -- | -- | (DXLog: "FOC Marathon") | -- | high that it is unlisted (771 "FOC Old School Classic 1960s QSO Party" is a different event) |
| GRIDLOC | ALREADY DECIDED: placeholder, Cabrillo FFMA (Fred Fish Memorial Award) | NONE FOUND | -- | -- | per the decision | -- | high -- WA7BNM has no FFMA entry |
| INTERNETSPRINT | Internet CW Sprint | **18** | Internet CW Sprint Contest | Inactive (last 2004) | Internet CW Sprint Contest | https://www.contestcalendar.com/contestdetails.php?ref=18 | medium-high -- exchange (copied call + nr + name + S/P/C + your call) is the shape of our `QSONumberNameDomesticOrDXQTHExchange` with domestic file `s49p13`; not confirmed in DXLog |
| IRTS | IRTS Counties contest (80 m HF; set-up is 80 m) | **756** best; also 757, 758 | IRTS 80m Counties Contest | Active | IRTS 80m Counties Contest | https://www.contestcalendar.com/contestdetails.php?ref=756 | medium -- the class sets up on 80 m and is HF, so 756 (Cabrillo `IRTS-80-CONTEST`); 757/758 are the 70 cm and 2 m counties contests |
| JALONGPREFECT | ALREADY DECIDED: JARL ACAG | NONE FOUND | -- | -- | per the decision (contestclock.com/contest/jarl-acag) | -- | high that WA7BNM does not list ACAG |
| JTDX | Mongolian (JT) DX Contest; display name is already 'MONGOLIAN DX' | **491** best; also 495, 462 | Mongolian DX Contest, CW/SSB | Inactive (last 2009) | Mongolian DX Contest, CW/SSB | https://www.contestcalendar.com/contestdetails.php?ref=491 | high -- exchange RS(T) + CQ zone matches `RSTZoneExchange`; e-mail jtdxcontest@gmail.com |
| KVP | KV Prvenstvo ZRS -- Slovenian HF Championship | NONE FOUND | -- | -- | (DXLog `S5KVP.txt`: "KV PRVENSTVO ZRS") | -- | high on identity (FCONTEST's commented-out name and DXLog's Cabrillo `KVP`), high that unlisted |
| MINITEST | Russian Wednesday Mini-Test (minitest.narod.ru), 80 m | NONE distinct -- 712 / 711 are ALREADY held by `MINI80` / `MINI40` | (Mini-Test 80 / Mini-Test 40) | Active | (needs a name; DXLog: "Wednesday mini-contest") | https://www.contestcalendar.com/contestdetails.php?ref=712 | medium -- same sponsor and rules page, but TR4W already gives the two WA7BNM events to two other contests |
| MWC | OK1WC Memorial | **683** | OK1WC Memorial (MWC) | Active | OK1WC Memorial (MWC) | https://www.contestcalendar.com/contestdetails.php?ref=683 | high -- D7 e-mail is memorial-ok1wc.cz, WA7BNM's rules are memorial-ok1wc.cz, exchange RST + serial |
| OLDNEWYEAR | Old New Year Contest (RADIO-ONY) | **554** | Old New Year Contest | Active | Old New Year Contest | https://www.contestcalendar.com/contestdetails.php?ref=554 | high -- WA7BNM's Cabrillo name is `RADIO-ONY`, our display spelling; BUT WA7BNM's exchange is RS(T) + age + years on air, ours is `RSTPowerExchange` (a rule finding, not an identity doubt) |
| OZCR_O | OZCHR contest, teams (QRZ.RU 182) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted; identity only as far as the class says |
| OZCR_Z | OZCHR contest (QRZ.RU 182) | NONE FOUND | -- | -- | (needs a name) | -- | as above |
| OZHCRVHF | OZ Ham Contest Radio VHF (QRZ.RU 203) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| PCC | PRO CW Contest (Romania, PRO Radio Contest Club) | **266** (active); also 396 (inactive duplicate) | PRO CW Contest | Active | PRO CW Contest | https://www.contestcalendar.com/contestdetails.php?ref=266 | high -- DXLog `PCC.txt` is "PRO CW Contest" with Cabrillo `PCC`; the "/M" member suffix on WA7BNM matches our class's "exchange ends in M" rule |
| QCWAGOLDEN | ALREADY DECIDED: retired | NONE FOUND | -- | -- | per the decision | -- | high -- WA7BNM has only 332 QCWA QSO Party (held by `QCWA`) and 127 QCWA Fall QSO Party, both Inactive |
| R9W_UW9WK_MEMORIAL | R9W and UW9WK Memorial (QRZ.RU 41) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| RADIOMEMORY | Radio Memory contest (QRZ.RU 83) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| RADIOVHFFD | Radio VHF Field Day, RF-VHF-FD (QRZ.RU 180) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| RADIOYOC | Radio YOC (QRZ.RU 119) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| REGION1FIELDDAY | IARU Region 1 Field Day (one class, both modes) | **35** (CW) and **105** (SSB) | IARU Region 1 Field Day, CW / IARU Region 1 Field Day, SSB | both Active | (one class, two events -- NY4I's choice) | ref=35, ref=105 | high on identity |
| REGION1FIELDDAY_RCC_CW | IARU R1 Field Day under RCC's rules, CW (QRZ.RU 358) | **35** (the same weekend's IARU event) | IARU Region 1 Field Day, CW | Active | not WA7BNM's name -- it is RCC's scoring of that event (DXLog: "RCC Fieldday", `FD-RCC-CW`) | ref=35 | medium -- WA7BNM has no RCC entry; 35 is the event, not RCC's rules |
| REGION1FIELDDAY_RCC_SSB | as above, SSB | **105** | IARU Region 1 Field Day, SSB | Active | as above | ref=105 | medium |
| RFASCHAMPIONSHIPCW | Asiatic Russia Championship, CW (AS-CHAMP) | NONE FOUND | -- | -- | (DXLog: "Asiatic Russia Championship") | -- | high that unlisted |
| RFCHAMPIONSHIPCW | Russian Federation Championship, CW (champ@srr.ru) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted (456 Russian Radio Team Championship is a different event) |
| RFCHAMPIONSHIPSSB | Russian Federation Championship, SSB | NONE FOUND | -- | -- | (needs a name) | -- | as above |
| RSGB18 | RSGB 1.8 MHz Contest (RSGB-160) | **252** | RSGB 1.8 MHz Contest | Active | RSGB 1.8 MHz Contest | https://www.contestcalendar.com/contestdetails.php?ref=252 | high -- WA7BNM's Cabrillo name `RSGB-160` is exactly ours. 189 "RSGB 2nd 1.8 MHz Contest, CW" exists but is grey and its detail page is not found |
| SASPRINT | SA Sprint | **604** | SA Sprint Contest | Inactive (last 2019) | SA Sprint Contest | https://www.contestcalendar.com/contestdetails.php?ref=604 | high -- Cabrillo `SA-SPRINT` is exactly ours; D7 e-mail sa-sprint.com matches WA7BNM's rules site |
| SOUTHAMERICANWW | TR Log's "South American WW" (RST + continent; 10 points across the SA boundary) | NONE FOUND | -- | -- | (needs a name) | -- | medium -- the only near misses are 45 GACW WWSA (RST + CQ zone, and ALREADY held by `GACWWWSACW`) and 521 CQ SA SSB (Inactive 2012; RS + serial, 1/2/3/10 points) -- neither has our exchange |
| TOEC | TOEC WW Grid Contest | **97** | TOEC WW Grid Contest, CW | Inactive (last 2007) | TOEC WW Grid Contest, CW | https://www.contestcalendar.com/contestdetails.php?ref=97 | high -- D7's SK3BG id `toecwwgc` is in WA7BNM's rules URL; exchange RST + grid matches |
| UA4WCHAMPIONSHIP | Udmurtia Open Championship (R4W-CHAMP; r4w@narod.ru) | NONE FOUND | -- | -- | (DXLog `R4W-CHAMP.txt`: "Открытый Чемпионат Удмуртии") | -- | high that unlisted |
| UCG | "UCG" (QRZ.RU 160; prefix mults, continent/band points) | NONE FOUND | -- | -- | (needs a name) | -- | low on identity -- not in DXLog by that name and qrz.ru unreachable |
| UKEI | UK/EI DX Contest | **597** (CW) and **596** (SSB) | UK/EI DX Contest, CW / UK/EI DX Contest, SSB | both Active | (one class, two events) | ref=597, ref=596 | high -- Cabrillo `UKEI-DX`; domestic file `uk-ei` |
| UKRAINECHAMPIONSHIP | Ukraine HF Championship (domestic file `ukraine`) | NONE FOUND | -- | -- | (needs a name) | -- | medium -- 334 "Open Ukraine RTTY Championship" (Active, Cabrillo `UKR-CHAMP-RTTY`) is RTTY only and is another event |
| WWL | ALREADY DECIDED: retired (grid-field contest) | NONE FOUND | -- | -- | per the decision | -- | low on identity -- no WA7BNM, DXLog or header evidence of what WWL was |
| XMAS | ALREADY DECIDED: retired (QRZ.RU 100; RST + serial + random characters, 2 points) | NONE FOUND | -- | -- | per the decision | -- | low on identity -- 210 DARC Christmas Contest has Cabrillo `XMAS` but its exchange is DOK / serial, not random characters, so the shared spelling is not evidence; 709 CW QRS Xmas Activity is RST + name + QTH |
| YOUTHCHAMPIONSHIPRF | Youth Championship of Russia (SRR-JR, QRZ.RU 331) | NONE FOUND | -- | -- | (needs a name) | -- | high that unlisted |
| YUDX | YU DX Contest | **322** | YU DX Contest | Active | YU DX Contest | https://www.contestcalendar.com/contestdetails.php?ref=322 | high -- exchange county / serial, domestic file `yu` |

Tally: **21 contests have a ref** (ARCI's six counted as one decided entry,
the R1FD RCC pair counted with medium confidence); **28 are NONE FOUND**
(MINITEST among them: no ref that another TR4W contest does not already hold).

## WA7BNM lists MORE than one event that could match

| enum | refs | note |
|---|---|---|
| APSPRINT | 248 (Spring CW), 164 (Fall CW), 42 (SSB) | one TR4W class runs all three |
| ARCI | 315, 168, 31, 69, 193, 198 | decided: six events (F26) |
| REGION1FIELDDAY | 35 (CW), 105 (SSB) | one class, both modes |
| UKEI | 597 (CW), 596 (SSB) | one class, both modes |
| IRTS | 756 (80 m), 757 (70 cm), 758 (2 m) | 756 is the HF one the class sets up for |
| JTDX | 491 (CW/SSB), 495 (RTTY), 462 (JT Hamradio-50, 2008) | 491 matches the exchange |
| PCC | 266 (Active), 396 (Inactive) | same name twice on WA7BNM; 396 is the 2010 "Top of Operators Activity" page |
| RSGB18 | 252, 189 | 189 is grey and its detail page is not found |
| EUSPRINT_SPRING_CW | 317; 731 ("EU Sprint, SSB") is the only current-named EU Sprint entry | see below |
| MINITEST | 712, 711 | both already held by `MINI80` and `MINI40` |

## Where the D7 row's WA7BNM id disagrees with this

- **None disagrees with a FOUND ref.** Every one of the 49 has D7 `WA7BNM: 0`
  except one:
- **EUSPRINT_SPRING_CW: D7 says 317 and so does the class today**
  (`uContestEUSprintSpringCW.GetWA7BNMId = 317`). So the premise that every one
  of the 49 returns 0 is wrong for this contest; it is on the list only because
  it has no friendly name. WA7BNM's 317 is now named "RSGB International Sprint
  Contest, CW" and is Inactive since 2016 -- the RSGB hosted that year, and the
  calendar kept the host's name. The SSB sibling already states that convention
  (`EUSPRINT_SPRING_SSB`'s friendly name is "RSGB International Sprint Contest,
  SSB", ref 316). Whether the EU Sprint deserves a host-neutral name is a
  question for NY4I; the TR4W website already links 317 under the enum spelling.

## Could not identify at all (beyond the class's own words)

- **UCG** -- no DXLog file, no WA7BNM entry, qrz.ru (id 160) unreachable.
- **WWL** -- retired; nothing names it.
- **XMAS** -- retired; QRZ.RU 100 unreachable; no WA7BNM or DXLog event has its
  random-characters exchange.
- **SOUTHAMERICANWW** -- identified only as TR Log's "South American WW"; no
  current event has its exchange.
- **OZCR_O / OZCR_Z / OZHCRVHF**, **RADIOMEMORY**, **RADIOYOC**,
  **R9W_UW9WK_MEMORIAL**, **RADIOVHFFD**, **YOUTHCHAMPIONSHIPRF** -- identified
  by their class headers and QRZ.RU ids only; WA7BNM does not list them, and
  the QRZ.RU pages that would give their names could not be fetched.

## Rule findings met along the way (not part of Q53, recorded for NY4I)

- **OLDNEWYEAR**: WA7BNM's exchange is RS(T) + operator's age plus years on
  the air; ours is `RSTPowerExchange`.
- **BWQP**: WA7BNM's exchange is RST + name + FOC number; ours is
  `RSTNameAndQTHExchange`.
- **MINITEST**: the event's two WA7BNM entries already belong to `MINI40` and
  `MINI80`, so `MINITEST` may be a third TR4W spelling of the same event.
