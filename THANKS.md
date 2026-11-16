# Thanks

TR4W stands on other people's work. This page records the sources and projects we
have used and are grateful for. It is a living list: if we used your work and you
are not here, tell us and we will add you.

## Foundational Information

First and foremost, tremendous thanks go to Tree N6TR. Tree created the original TRLog upon which all of this stands.  Second is the Herculean task of converting Tree's original DOS code to a Win32 application by Dmitriy Gulyaev UA4WLI.

Once open-sourced, Howie N4AF led our team through the years.

## AI Usage

Many projects led to the state this code is in today. Most importantly is the absolutely amazing tool called Claude Code created by Anthropic (ANT). Without Claude Code, this recent port would have taken years to accomplish. Codex by OpenAI has also been invaluable in helping keep Claude honest by providing agent oversight of changes and strategies. While I like to think my 40+ years of developing high-volume transaction processing applications helped with the architecture, test case guidance and other ways to get the AI tools to look at validating its own work, the AI tools made this happen. This is most certainly not a "vibe coded" application. It is AI-assisted development. 

Technology Inspirations

Many open-source projects like KF5O's amazing QK4 (K4 Spectrum), AetherSDR (TCI), wfview (Icom Network Support) have provided inspiration and guidance. Other countless tools such as ADIF parsing, the tools provided by WSJT-X, examples of interfacing to the various external loggers such as ClubLog, QRZ, World Radio League, DXKeeper and more have also helped make this code what it is today.

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
