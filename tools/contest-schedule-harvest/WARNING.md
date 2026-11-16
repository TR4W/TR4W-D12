# WARNING: one-time harvest only. Do NOT program an automatic lookup.

The contest dates in `docs/CONTEST_SCHEDULES.csv` were harvested ONCE, on
2026-11-16, partly from the public pages and API endpoints of **Ham Radio
Contest Calendar** (hamradiocontestcalendar.com, run by DL2NBY), and partly from
qsoparty.eqth.net and the sponsors' own rules.

## What the site's terms say (read 2026-11-16, quoted in substance)

- It is a private, non-commercial project; its data "may be incomplete, outdated
  or incorrect" and the organizer's official rules take precedence.
- **Individual contest facts** (names, dates, times, modes, bands) "may be shared,
  quoted and used in other amateur-radio contexts"; a link back to the calendar
  or to the organizer's source is appreciated.
- "Original editorial text and the compilation of the database remain protected."

NY4I's decision: a one-time use of individual facts is within those terms. A
program that fetches the site on its own, or copies the compilation, is not what
the terms grant.

## Rules for anyone (human or agent) working here

1. **Never write code, in the program or in a build or test step, that calls
   hamradiocontestcalendar.com or its API.** No startup fetch, no timer, no
   scheduled job, no "refresh the dates" script. The program must stay offline
   for schedules: the contest classes own their schedule strings.
2. **Do not copy the compilation.** Take a date only to confirm or fill a
   specific contest, and prefer the sponsor's own rules; a calendar date is a
   `candidate`, never `verified`, until it is checked against the sponsor.
3. **Keep raw API responses, scraped pages and scraper scripts out of the
   repository.** If a one-off script is genuinely needed, run it from outside the
   tree and commit only the resulting facts (with their source in `notes`).
4. **Give credit.** The README beside the CSV names the calendar as a source.

(A different feed, WA7BNM's contest calendar, has its own permission, recorded
on issue 190. This warning is about hamradiocontestcalendar.com.)
