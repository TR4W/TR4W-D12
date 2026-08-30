Generate (or regenerate) the consolidated, by-feature "What's New since the last major release" view and write it to `docs/WHATS_NEW_<MAJOR.MINOR>.md` (named for the CURRENT minor series, e.g. `docs/WHATS_NEW_4.149.md`).

> **Ported from the D7 tree (C:\TR4W) on 2026-08-30 and ADAPTED.** The repo,
> remote and branch differ here: `TR4W/TR4W-D12`, remote **`d12`** (there is no
> `origin`), branch **`main`** (there is no `master`). The D7 branch dance
> (stash / checkout / pull / pop) is REMOVED -- work here happens on `main`, and
> a stray `stash push`/`pop` moves uncommitted work you did not intend to move.
>
> **NOT YET USABLE ON THIS TREE, and that is the point of reading this first.**
> It projects `RELEASE_NOTES.md`, whose newest entry is `4.149.00` while this
> tree is on 5.x -- so there is no 5.x series to consolidate, and
> `docs/WHATS_NEW_4.149.md` is an inherited D7 artifact. Run `/update-changes`
> first and get the 5.x history documented; this is only meaningful after that.
>
> **NO `Claude-Session:` trailer** in the commit message -- this repo is public.
> **NEVER force-push `main`** -- it is shared and protected server-side.

This skill is a **projection**, not a new source of truth. `RELEASE_NOTES.md` remains the single authoritative changelog: it is appended one section per patch version by the `update-changes` skill. `monthly-changes` reads those per-version sections back and re-groups their bullets by function so operators can see everything shipped since the last major release, organized by what it affects — Radio Control, CW, Band Map, etc. — regardless of which patch shipped it.

**Scope = "since the last major release."** A "major release" here is a **minor-version bump** (the `.0`): `4.148.0`, `4.149.0`, etc. The interim patch versions and `-all` rebuilds in between are NOT majors. So the view for the current series spans the **current minor series plus the entire immediately-preceding minor series** — e.g. while on `4.149.x`, the doc consolidates all of `4.148.x` (the last major, `4.148.0`, was its baseline) **and** all of `4.149.x`. This is deliberately a moving two-series window: when `4.150.0` is cut, the view rescopes to `4.149.x + 4.150.x` and the previous `WHATS_NEW_4.149.md` is deleted (its content is fully contained in the new one).

Run it at the monthly `-all` release boundary (the `Invoke-Release.ps1` cadence), or any time you want a refreshed by-feature view.

## Hard rules

- **Do NOT rewrite, reword, shorten, merge, or split any bullet.** Each bullet is copied **verbatim** from `RELEASE_NOTES.md`. The ONLY transformation this skill performs is *moving* a bullet under a function heading. If a bullet's wording is wrong, that is fixed in `RELEASE_NOTES.md` and this skill re-run — never patched here.
- **Source of truth is `RELEASE_NOTES.md`** (the user-facing notes), NOT `CHANGES.md` (developer notes). Never pull bullets from `CHANGES.md`.
- **Scope is the current minor series plus the immediately-preceding one ("since the last major").** Include every `### ` version section under the current `## <MAJOR.MINOR>.x` month group in `RELEASE_NOTES.md` AND every `### ` section under the month group directly below it (the previous minor series). Determine the previous series **structurally** — the next `## <X.Y>.x` header below the current one — NOT by arithmetic `MINOR-1` (minor numbers can skip, e.g. 4.145 → 4.141). Nothing from two series back or earlier. Example: on `4.149.x`, include all of `4.149.x` and all of `4.148.x`; exclude `4.147.x` and older.
- **The previous series' standalone doc is superseded.** Once its bullets are folded into the current `docs/WHATS_NEW_<MAJOR.MINOR>.md`, delete the older `docs/WHATS_NEW_<prev MAJOR.MINOR>.md` in the same commit — there is exactly one live "since last major" doc at a time.
- This produces a **document-only** artifact. The commit (step 6) touches only the current `docs/WHATS_NEW_<MAJOR.MINOR>.md` and the deletion of the superseded prior one.

## Steps

1. **Read the current version** from `tr4w/src/Version.pas` — extract `TR4W_CURRENTVERSION_NUMBER`. Derive the current minor series as `MAJOR.MINOR` (e.g. `4.149.00` → `4.149`). The output file is `docs/WHATS_NEW_<MAJOR.MINOR>.md`, named for the CURRENT minor. Identify the **previous minor series** structurally: the `## <X.Y>.x` month-group header immediately below the current one in `RELEASE_NOTES.md` (e.g. current `## 4.149.x` → previous `## 4.148.x`); that series' `.0` is the "last major release." The **latest patch version** is the highest `### <MAJOR.MINOR>.<patch>` header in the CURRENT series, and its **date** is the `(YYYY-MM-DD)` in that same header — use both for the subtitle. Take the date from the header, NOT from "today", so the subtitle reflects the release even if the skill is re-run later.

2. **Collect the per-version sections for BOTH series** from `RELEASE_NOTES.md` — the current `## <MAJOR.MINOR>.x` month group and the previous `## <prev>.x` month group directly below it. Find every `### <version>` header in both and capture all bullets beneath each (down to the next `###` / `---`), skipping the `> 📋` callout lines. Keep the source version + sub-heading of each bullet associated with it so nothing is dropped. Bullets under user-facing `####` sub-headings ("Radio Control", "CW", "Usability", etc.) carry their original sub-heading as a *grouping hint* for step 3. Order across the two series is earliest-patch-first (previous series before current).

3. **Re-group every bullet, verbatim, under a function heading.** Use the canonical heading taxonomy below. Map each bullet to the single best-fit heading (its original `####` sub-heading from RELEASE_NOTES.md is the strongest hint; fall back to the bullet's subject). Merge synonymous source sub-headings into one canonical heading (e.g. three separate "Cabrillo" sections across patches collapse into one **Cabrillo & Log Export**; "Digital" and "WSJT-X" collapse into **Digital / FT8 / WSJT-X**). Within a heading, preserve the bullets' order (earliest patch first). Do not invent headings outside the taxonomy unless a bullet genuinely fits none — in that case add a new heading and note it to the user.

   **Canonical function headings** (omit any with no bullets; this is the preferred order):
   - Radio Control
   - SO2R / Radio Mode
   - Band Map
   - CW
   - Digital / FT8 / WSJT-X
   - DX Cluster
   - Rotator Control
   - Function Keys
   - Send From Keyboard
   - Search & Pounce
   - Data Entry / Exchange
   - Cabrillo & Log Export
   - VHF
   - Reports & Scoring
   - Contests
   - Log Window
   - Display
   - Crash Recovery
   - Multi-Op / Networking
   - Configuration Files
   - Parallel-Port (LPT) Keying
   - Super Check Partial
   - Usability
   - Translations
   - Bundled Data
   - Under the Hood / For Contributors

4. **Draft the document.** Format:

```markdown
# What's New in TR4W <MAJOR.MINOR>

### Everything new since the <prev MAJOR.MINOR>.0 major release — current as of <LATEST-PATCH> (<YYYY-MM-DD of latest patch>)

*Consolidated by feature across the entire <prev MAJOR.MINOR>.x series plus <MAJOR.MINOR>.x — the full "what's new since your last major release" view. Source of truth is RELEASE_NOTES.md; re-run the `monthly-changes` skill to refresh.*

## Radio Control

- <verbatim bullet>
- <verbatim bullet>

## CW

- <verbatim bullet>

...
```

   Do not append per-version dates or handles to bullets — the by-feature view is intentionally release-agnostic. (The per-version log in `RELEASE_NOTES.md` retains that detail.)

5. **Show the draft to the user for review.** Before writing the file, also report a reconciliation count that spans BOTH series: "N_prev bullets (prev series) + N_cur bullets (current series) = N total → N bullets placed" so it is obvious nothing was lost. N in must equal N out. When only the current series exists yet (a brand-new minor with the previous series already documented), the previous series' count comes straight from its `## <prev>.x` sections.

6. **On approval, write, supersede, and commit.** Write `docs/WHATS_NEW_<MAJOR.MINOR>.md` (current minor) and `git rm` the superseded `docs/WHATS_NEW_<prev MAJOR.MINOR>.md` if it exists, then commit both **on `main`** regardless of current branch, push, and return to the original branch. Like `update-changes`, this is a self-contained document-publishing action approved at the draft stage:
   ```
   git -C /c/tr4w-d12 add docs/WHATS_NEW_<MAJOR.MINOR>.md
   git -C /c/tr4w-d12 rm docs/WHATS_NEW_<prev MAJOR.MINOR>.md   # only if it exists / is now superseded
   git -C /c/tr4w-d12 commit -m "docs: WHATS_NEW_<MAJOR.MINOR> (since <prev MAJOR.MINOR>.0); remove superseded WHATS_NEW_<prev MAJOR.MINOR>"
   git -C /c/tr4w-d12 push d12 main
   ```
   Also update the two `> 📋` "See … for a consolidated, by-feature view" callouts in `RELEASE_NOTES.md` (under the current and previous month-group headers) to point at the current `docs/WHATS_NEW_<MAJOR.MINOR>.md`, so no link dangles to the removed file.

## Relationship to `update-changes`

`update-changes` runs per patch and appends to `CHANGES.md` + `RELEASE_NOTES.md`. `monthly-changes` runs at each major (minor-bump) release boundary and regenerates the "since last major" by-feature projection — the current minor series plus the previous one, in one moving two-series window. They share `RELEASE_NOTES.md` as the single source of truth — `update-changes` writes it, `monthly-changes` reads it. Keeping them separate means the by-feature doc does not churn on every small patch; it is refreshed deliberately at release time, and there is always exactly one live `WHATS_NEW_<current minor>.md`.
