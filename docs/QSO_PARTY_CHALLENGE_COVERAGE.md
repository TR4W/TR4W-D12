# State QSO Party Challenge coverage

Dated audit: 2026-11-13. Scope: NY4I's supplied list of **46 events**.
This is an inventory of registered implementations, not a certification
that every sponsor rule or operating category has completed the #88 audit.

Checked the rebuilt application's `/MATRIXLIST` output (201 contests),
application imports and source files; compared the release tag `v5.0.40`
and committed main at `8706893b5b02b7fbe5c275588e432dff96d325d0`.

**Published v5.0.40: 31/46. Local development build: 36/46.**
Alabama, New Jersey, West Virginia, Arkansas and Kentucky are additions
on the unmerged `codex/new-qso-parties` worktree. The remaining **10 events** have no
registered implementation in this build. Thus the current release is
missing 15 of these events; it is premature to claim all 46 are supported.
Alabama/NJ were committed locally as `bad18048`; WV as `ae586527`.

**Round scope versus implementation status:** the remaining missing entries below
are queued within the current new-QSO-party round, not additional work
excluded from it. South Dakota remains in that queue with its rule questions answered.
Kentucky now has its class/data/tests; its additional KY state credit, and
AL/WV/VT's, is a second domestic key since #317 (2026-11-13). The five new
registrations do not establish complete category or report support. "Missing" in the table means not implemented
yet, not outside the round's scope.

## Complete mapping

| Challenge event | Runtime contest ID | v5.0.40 | Development worktree | Request |
|---|---|---|---|---|
| 7th Call Area QSO Party | `7QP` | Present | Present |  |
| Atlantic Canada QSO Party | None | Absent | Missing | #116 |
| Alabama QSO Party | `AL-QSO-PARTY` | Absent | Present | #114 |
| Arizona QSO Party | `ARIZONA QSO PARTY` | Present | Present |  |
| Arkansas QSO Party | `AR-QSO-PARTY` | Absent | Present | #115; mobile/category gaps #133/#87 |
| British Columbia QSO Party | `BCQP` | Present | Present |  |
| California QSO Party | `CALIFORNIA QSO PARTY` | Present | Present |  |
| Canadian Prairies QSO Party | None | Absent | Missing | #117 |
| Colorado QSO Party | `COLORADO QSO PARTY` | Present | Present |  |
| Delaware QSO Party | `DELAWARE QSO PARTY` | Present | Present |  |
| Florida QSO Party | `FLORIDA QSO PARTY` | Present | Present |  |
| Georgia QSO Party | `GA-QSO-PARTY` | Present | Present |  |
| Hawaii QSO Party | None | Absent | Missing | #118 |
| Idaho QSO Party | `IDAHO QSO PARTY` | Present | Present |  |
| Illinois QSO Party | None | Absent | Missing | #119 |
| Indiana QSO Party | `IN QSO PARTY` | Present | Present |  |
| Iowa QSO Party | None | Absent | Missing | #120 |
| Kansas QSO Party | None | Absent | Missing | #121 |
| Kentucky QSO Party | `KY-QSO-PARTY` | Absent | Present | #110; extra KY credit built at #317 |
| Louisiana QSO Party | None | Absent | Missing | #122 |
| Michigan QSO Party | `MICHIGAN QSO PARTY` | Present | Present |  |
| Minnesota QSO Party | `MINNESOTA QSO PARTY` | Present | Present |  |
| Mississippi QSO Party | None | Absent | Missing | #123 |
| Missouri QSO Party | `MISSOURI QSO PARTY` | Present | Present |  |
| Nebraska QSO Party | `NE-QSO-PARTY` | Present | Present |  |
| New England QSO Party | `NEWEQP` | Present | Present |  |
| New Hampshire QSO Party | `NH-QSO-PARTY` | Present | Present |  |
| New Jersey QSO Party | `NJ-QSO-PARTY` | Absent | Present | #124 |
| New Mexico QSO Party | `NM-QSO-PARTY` | Present | Present |  |
| New York QSO Party | `NY-QSO-PARTY` | Present | Present |  |
| North Carolina QSO Party | `NC QSO PARTY` | Present | Present |  |
| North Dakota QSO Party | `ND-QSO-PARTY` | Present | Present |  |
| Ohio QSO Party | `OHIO QSO PARTY` | Present | Present |  |
| Oklahoma QSO Party | `OK-QSO-PARTY` | Present | Present |  |
| Ontario QSO Party | `ON-QSO-PARTY` | Present | Present |  |
| Pennsylvania QSO Party | `PA QSO PARTY` | Present | Present |  |
| Quebec QSO Party | `QC-QSO-PARTY` | Present | Present |  |
| South Carolina QSO Party | None | Absent | Missing | #111 / #113 |
| South Dakota QSO Party | None | Absent | Missing | #129 |
| Tennessee QSO Party | `TENNESSEE QSO PARTY` | Present | Present |  |
| Texas QSO Party | `TEXAS QSO PARTY` | Present | Present |  |
| Vermont QSO Party | `VT-QSO-PARTY` | Present | Present |  |
| Virginia QSO Party | `VAQP` | Present | Present |  |
| Washington State Salmon Run | `SALMON RUN` | Present | Present |  |
| West Virginia QSO Party | `WV-QSO-PARTY` | Absent | Present | #131 |
| Wisconsin QSO Party | `WISCONSIN QSO PARTY` | Present | Present |  |

## Combined contest handling

7QP, Indiana, New England and Delaware each have their own registered
class. `uContestIN7QPNE` also holds all four component contests and emits
one combined log. The combined option is additional functionality, not a
47th Challenge event and not a replacement for a missing standalone class.
The Challenge website calls this four-event workflow IN7QPNEDE.

## Conditions before an all-events submission

- Implement and validate the 10 missing events using their existing issues;
  #111/#113 refer to one South Carolina event, not two.
- Merge the local additions and ship a release containing all 46 modules
  and their DOM data. Verify that actual release build against this list.
- Complete the relevant #88 rule-correctness and bench follow-ups. Known
  shared limitations include own-mobile/category rules (#133/#87),
  the stored-flag undercount of the second domestic key (UDP
  `<ismultiplier2>`, hourly Mults column, HamScore; #317 follow-up), and pending
  screen/3830 checks.
  Registered presence alone must not hide those limits in an external claim.
  A concrete existing #88 gap is Wisconsin: its class still records the
  typed DX exchanges as refused. NY4I resolved the power-factor rounding
  question in #88 comment 6861756129: use standard Free Pascal `Round`.
  LOW x1.5 and QRP x2 now pass the unit suite. County-suffixed bonus-call
  matching (#111) is fixed in the shared party helper, pending final gates. These are
  correctness gaps in an existing module, not missing-contest entries.
- Test the combined four-party log and the per-party totals/exports needed
  for submission. The Challenge uses 3830 submissions, so report correctness
  is part of the acceptance work.

## Sources

- NY4I's 46-event list supplied in this working session.
- State QSO Party Challenge: https://stateqsoparty.com/
- 2026 Challenge rules: https://stateqsoparty.com/wp-content/uploads/2026/01/2026SQPCHALLENGERULES.pdf
- Four-event log processing: https://stateqsoparty.com/4qp-cabrillo-log-parsing/
- #88 research and earlier coverage snapshot: https://github.com/TR4W/TR4W-D12/issues/88

The earlier #88 calendar inventory was dated 2026-10-26 (24 committed
events, North Dakota in progress). This audit supersedes that snapshot for
presence counts; it does not close #88's separate rule-correctness work.
