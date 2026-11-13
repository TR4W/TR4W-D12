# New QSO parties

Worktree: `.worktrees/new-qso-parties`, branch `codex/new-qso-parties`.
Requests come from GitHub's `New Contest Request` label; titles containing
`QSO Party` are the first batch. South Carolina #111 and #113 are one event.

## Architecture

Each event owns its rules in `tr4w/src/contestFactory/uContest<State>QP.pas`
and registers by a stable string ID. Application/test imports link its unit;
no frozen enum member or new-contest CFG is added. Sponsor documents and
dated transcriptions live under `docs/ContestRules/QSOParties/<State>/`.

The state-party base supplies host-area eligibility, county-qualified rover
dupes and ADIF county/state handling. Each leaf explicitly states its bands,
modes, points, exchange helpers, multiplier scope and county-line limit.
`<state>_cty.dom` contains only host counties; `<state>.dom` adds the other
locations an in-state entrant may work. Sponsor codes take precedence over
another logger's definition.

The shared entry path retains its existing country and string-key lookup
order before exchange parsing. Alabama and West Virginia override `ParseReceivedExchange`,
calls the inherited parser, and finalizes its received-location string key
only after a successful parse. It calls the same `PrefixMultiplierKey`
policy used by rescore. Existing contests retain their refusal behavior,
including prefix keys derived from fields a refusing parser later changes.

Alabama's first received county in each mode earns both that county and the
Alabama state multiplier (NY4I, #114, 2026-11-13). Counties and other
states/provinces use the domestic sheet; the additional `AL` key uses the
existing string-key sheet, which already supports non-prefix keys for CW
Open. Its totals row is labelled `AL`. The normal sheet scope, dupe/X-QSO
exclusion, worked counts, score summation and rescore apply to both credits.
No additional QSO field or database schema is required.

West Virginia uses the same two-credit mechanism with its own once-overall
scope, as NY4I ruled on #131. The county-to-state computation is now
`TContestStateQSOPartyBase.CountyStateMultiplierKey`, extracted from Alabama
when WV became its second caller. Each class elects to use it and owns its
multiplier availability and scope; the helper validates the county and
returns the host-state key. Both leaf parsers finalize the key after their
inherited validation, and rescore uses the same leaf key policy. Alabama's
policy is unchanged. WV's W8WVA bonus uses the existing declared bonus-station
mechanism, filtered by `IsCreditedContact`, with no new engine path.
Shared bonus counting now scans the view once for any declared scope,
including `bsPerQSO` for Arkansas's WR5P. Each leaf still owns contact and
mode eligibility. State-party matching removes trailing county suffixes
verified by the session table, preserving district and portable suffixes.
Ontario club-station points reuse the same stripping helper; New Mexico's
W1AW/5/BER and WV's W8WVA/BAR now earn their declared bonuses (#111).

The new tests share `uTestQSOPartyEngine`: it owns isolated domestic,
multiplier and dupe sheets, configures the entrant from the class and shipped
files, enters contacts through the real parser and sheets, and restores the
session globals on destruction. `CountyFileDifference` compares canonical
county entries against independently saved sponsor transcriptions.
The fixture and ten older party tests call `uTestQSOPartyRules.EnterPartyQSO`
for the parser/dupe/multiplier entry step. The older bodies were compared
before extraction; two used the default submode and the rest were identical.
Both overloads reach one implementation, so fixes cannot drift between copies.

## First implementations

| Issue | Event | Stored ID | Rules |
|---|---|---|---|
| #114 | Alabama | AL-QSO-PARTY | 2026 sponsor rules; NY4I's county plus state ruling |
| #124 | New Jersey | NJ-QSO-PARTY | 2026 rev0.5, multiplier tables and FT8 FAQ |
| #131 | West Virginia | WV-QSO-PARTY | 2026 sponsor rules; overall scope and DXLog naming rulings |

New Jersey's power factors follow the declared category: HIGH 1, LOW 2,
QRP 4. Its table has 21 counties, 49 other states, 13 provinces and one DX
multiplier (84 total). Sponsor `NF` is exported as ADIF `NL`. FT8 is excluded
explicitly by the sponsor FAQ; other digital contacts require the full
exchange.

The entrant's mobile-category and own-county rework support is still the
pre-existing gap #133, as recorded in the class headers. Received rover
county changes are supported. Real-screen setup and 3830 report comparison
remain bench work in `BENCH_QUEUE.md`.

## Issue workflow

### Two domestic multipliers: specialist handoff #317

NY4I confirmed on #110 (comment 6862605577) that a Kentucky entrant's
county QSO also earns KY as a state. All such engine work belongs to the
Claude specialist agents on #317. Kentucky documents the missing extra state credit in its new leaf and
rules transcription, without adding another prefix-sheet solution. Alabama and WV are already added locally with that
interim string-sheet implementation; #317 now names both leaves, their
tests and scopes (AL per mode, WV overall) for migration. Their passing
tests do not establish correct domestic totals/needs UI. South Carolina is
also tracked there. Arkansas explicitly excludes AR from its states, and
New Jersey excludes NJ, so neither should gain an additional host-state key.

Post rule questions on the relevant issue and apply `Agent Question`.
Read answers directly, retain the ruling in the source/rules transcription,
and remove the label once every question on that issue is resolved. Keep
implementation findings and validation results on the issue. Do not close
requests merely because a class compiles.

## Remaining queue

South Carolina #111/#113; Atlantic Canada
#116; Canadian Prairies #117; Hawaii #118; Illinois #119; Iowa #120; Kansas
#121; Louisiana #122; Mississippi #123; South Dakota #129.

These remain requests, not claimed implementations. Regional Canadian
events require their actual multi-province eligibility, not an assumed
single-state base.

NY4I answered the three queued issues in comments on 2026-11-13:

- Kentucky #110, comment 6857618922: use the **2027 draft**. NY4I will
  update the rules when finalized if necessary. The rule-year question is
  resolved and `Agent Question` is removed.
- South Dakota #129, comment 6857555807: score FT4/FT8 as total digital
  contacts times total grids worked digitally; calculate the CW/phone
  geographic component separately and add the components. Follow-up
  comment 6858796866 resolves the remaining questions: FT4/FT8 grids are
  **four characters**; digital contacts do not require a county or earn
  county multipliers, and no grid-center-to-county inference is required;
  **DX entrants may work SD digital stations**. All current SD questions
  are resolved and `Agent Question` is removed. Preserve the distinct
  digital and geographic scoring components when implementing the class.
- West Virginia #131, comment 6857387343: all multiplier kinds count once
  per contest, with **no repetition by mode**. The scope question is
  resolved. NY4I subsequently directed use of DXLog's name: the installed
  `WVQP.txt` explicitly states `CABRILLO_CONTEST_NAME=WV-QSO-PARTY`,
  verified through the existing cross-check parser. Use `WV-QSO-PARTY`
  for Cabrillo, replacing the earlier proposed `WVQP`; the planned ADIF
  and stored identifier remains `WV-QSO-PARTY`. All current WV questions
  are resolved and `Agent Question` is removed. The naming lookup strategy
  is retained in `ADDING_A_CONTEST.md`.

#114's state-credit ruling is resolved and its question label has been
removed. #124's DC question is also resolved: NY4I confirmed that DC will
never be received, citing the 84-multiplier maximum. The sponsor table
remains unchanged and #124's question label is removed.

## Alabama/New Jersey validation, 2026-11-13

- Full FPC application rebuild passed; range warnings remain 3/3 and narrowing conversions 1187/1187.
- Full unit suite: 473,358 passed, zero failures. Focused party run: 2,361 passed, zero failures.
- All 58 lints passed. Deliberate point, scope, band and county-line mutations were detected for both parties.
- New contest records were generated by the freeze script only, with the sponsor-rule and #114 ruling reason recorded in the commit message.
- Full matrix: 198 identical, zero differing, missing or unfrozen. Independent ADIF validation: no unpinned findings or stale pins; the four existing WAG finding lines remain pinned. Both new contests have zero compliance errors.
- Corpus exports: 15 passed, zero failed, 11 existing known divergences, zero awaiting candidates. Its 13 ADIF files have zero compliance errors.
- Corpus rescore: all 13 logs identical to their frozen legacy baseline.
- Sponsor county comparisons: all 67 Alabama and 21 New Jersey canonical codes/names agree; DXLog cross-check results and differences are retained with the rules.

The generated contest-rules inventory was not regenerated: its existing model explicitly refuses RegisterContestById, including the parties already present on the base branch. Registry walks, matrix coverage and linked-unit lints cover these additions. Extending that separate inventory tool is outside this batch.

Screen setup/totals and real 3830 form comparison remain in BENCH_QUEUE.md. Own-mobile reworks remain the existing engine gap #133; received rover county reworks are covered by the new tests.

## West Virginia validation, 2026-11-13

- Full FPC application rebuild passed; range warnings remain 3/3 and narrowing conversions 1187/1187.
- Full unit suite: 475,826 passed, zero failures. The closed bonus-contest list now includes WV and W8WVA. Focused party run: 3,191 passed, zero failures.
- All 58 lints passed. Four deliberate WV mutations (points, multiplier scope, bands and county-line limit) were detected; restored source passed again.
- Only the new WV-QSO-PARTY matrix record was generated by the freeze script. All 199 matrix records are identical, with zero differing, missing or unfrozen records, including Alabama after helper extraction.
- Independent matrix ADIF validation: 199 files, existing 24 compliance errors all pinned, no unpinned findings or stale pins. WV has zero compliance errors; its 17 MY_STATE county-code consistency reports match the existing party setup convention.
- Corpus exports: 15 passed, zero failed, 11 existing known divergences. All 13 ADIF outputs have zero compliance errors. The first attempt stopped safely when another TR4W instance appeared; the complete retry passed.
- Corpus rescore: all 13 logs identical to their frozen legacy baseline.
- Sponsor and DXLog county codes match exactly: 55 versus 55. All shipped county codes and names are checked against the saved sponsor transcription.

Screen/3830 bench work remains queued. Existing own-mobile gaps #133/#87 remain documented. The shared county-suffixed bonus-call gap #111 is fixed in the AR/KY batch below.

## Arkansas/Kentucky and shared bonus batch, 2026-11-13

Arkansas and Kentucky now have registered leaves, application/test links,
own DOMs and saved primary rules/tables. AR uses current sponsor rules;
KY uses the approved 2027 draft. AR has 138 in-state multipliers, excluding
AR state; its WR5P bonus pays 200 for each valid QSO. KY scores CW 2/phone 1,
HP/LP/QRP 1/2/3, DX points only, K4KCG 100 per band/mode; extra KY domestic
state credit is documented for specialist issue #317. Their class headers
identify own-mobile/category and adjudication dependencies explicitly.

The shared bonus scan preserves the existing scopes, adds per-contact
payment, and uses the state-party county-strip helper. Ontario club points
reuse that helper; NM district suffixes remain intact. The protected
county-state helper now has its own probe tests. Wisconsin's power factors
use standard Free Pascal Round as ruled in #88, before bonuses.

Validation: full unit suite 480,898 passed, zero failures; focused affected
suites 7,097 passed; full app build passed at existing 3/3 range and
1187/1187 narrowing ceilings; all 58 lints passed. AR/KY frozen records
were generated with the sponsor-rule and #317-deferral reason. Both new
ADIF files have zero compliance errors. The partial validator reports four
stale WAG pins because WAG is not in that two-file subset; pins are unchanged.
The full matrix was deliberately interrupted at NY4I's quiet-stop request
after 59 record files were created; full comparison/ADIF and corpus gates
remain for the integrating agent. No final full-matrix or corpus pass is claimed.

NY4I requested this stop point; do not start further parties until the
session resumes. Integration instructions and remaining punchlist:
[QSO_PARTY_TURNOVER.md](QSO_PARTY_TURNOVER.md).
