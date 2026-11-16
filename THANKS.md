# Thanks

TR4W stands on other people's work. This page records the sources and projects we
have used and are grateful for. It is a living list: if we used your work and you
are not here, tell us and we will add you.

## Contest schedules

- **WA7BNM Contest Calendar** (https://www.contestcalendar.com). Bruce, WA7BNM,
  has kept the amateur contest calendar for years and gave permission for a
  program to use its feed. It is the reference the New Contest dialog's calendar
  links point at.
- **Ham Radio Contest Calendar** (https://hamradiocontestcalendar.com), by DL2NBY.
  Its public contest dates helped us fill in and cross-check the schedule of many
  contests in one harvest on 2026-11-16. The site's terms allow individual contest
  facts to be shared and used with a link back, and we used them that way, once;
  TR4W never calls the site. The organizer's own rules always take precedence.
- **Ham2K** (https://github.com/ham2k/extensions). The contest schedule sources in
  its extensions repository were a valuable cross-check for dates and operating
  windows.
- **QSO Party calendar** (https://qsoparty.eqth.net). The state and province
  calendar and the links to each sponsor's rules.

## Code and tools we build on

- **K1MU's ADIF validator** (https://github.com/k1mu/adifvalidator, MIT),
  vendored under `tools/adifvalidator/`. It checks every ADIF file our corpus,
  round trip and contest matrix write.
- **Indy** (vendored under `tr4w/include/`), **FreePascal and Lazarus**, **SQLite**
  and **Hamlib**, which carry the program, the contest log and many of the radios.

Thank you all.
