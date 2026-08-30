Update `RELEASE_NOTES.md` (user-facing release notes) and, once the initial 5.x cut is done, `CHANGES.md` (developer-level technical changelog), with any commits not yet documented.

> **Ported from the D7 tree (`C:\TR4W`) on 2026-08-30 and ADAPTED — do not diff
> it against the original expecting a match.** See
> [Differences from the D7 original](#differences-from-the-d7-original).

## Which files to write — read this first

**The initial 5.x cut is RELEASE_NOTES.md only. After that, both files, as in
the D7 tree.** NY4I, 2026-08-30.

The reason is the shape of the backlog, not a change of policy. This tree
carries **1,112 commits** of FPC port between the inherited D7 history and now.
That is not a changelog entry; written out at developer level it would be a
document nobody would read and nobody could verify.

So the initial cut is a **high-level, operator-facing summary of the 5.x line**
in `RELEASE_NOTES.md`, and `CHANGES.md` is left alone at its D7 end point.

**Detect which mode you are in:** if `RELEASE_NOTES.md` has no `### 5.` version
header yet, this is the initial cut → **RELEASE_NOTES.md only**. Once one
exists, the port is documented and normal service resumes → **both files**,
every run, keeping them in step.

For the initial cut, the technical detail is not lost — it is in `CLAUDE.md`
(architecture, kept current), `docs/` (one document per subsystem, with the
reasoning), and the commit messages.

## Steps

1. **Read the current version** from `tr4w/src/Version.pas` — the value of
   `TR4W_CURRENTVERSION_NUMBER`. This tree is on **5.x**; D7 was on 4.x.

2. **Decide the mode** per the section above, and say which one you are in
   before drafting anything.

3. **Read the baseline.** Both files carry a marker near the top:

   ```
   <!-- D12-CHANGELOG-BASELINE: <sha> -->
   ```

   **Only commits AFTER that sha are in scope** for the ongoing mode.
   Everything before it is the inherited D7 4.x history plus the FPC port. Do
   not widen the scope unless asked — a run that ignores the baseline produces a
   section nobody can review.

   *For the initial cut only*, the subject is the port as a whole rather than a
   commit list; summarise what an operator gains from 5.x (the FPC/LCL rebuild,
   the radio factory, the CW keyer factory, the LCL windows, translations) and
   keep it to something readable in a couple of minutes.

4. **Find undocumented commits** (ongoing mode):
   ```
   git -C /c/tr4w-d12 log --format="%h %s" <baseline-sha>..d12/main
   ```
   Exclude merges ("Merge pull request", "Merge branch") and pure version bumps
   ("Update Version.pas", "version bump"). A commit counts as documented if any
   6+ consecutive words of its subject appear verbatim in the target file.

   If this returns more than ~30, stop and report the count rather than
   drafting — something has gone unrun for a long time and the user should
   choose how to handle it.

5. **Determine the contributor** — author of the most recent non-merge,
   non-version-bump commit:
   ```
   git -C /c/tr4w-d12 log --format="%an" <baseline-sha>..d12/main
   ```
   "Tom Schaefer" → NY4I, "Howie Hoyt"/"n4af" → N4AF, "Gavin Taylor" → GM0GAV.

6. **Draft, appending under the existing `## Unreleased` heading.** Both files
   use **in-arrears versioning**, stated in a comment beside that heading:
   entries accumulate as work lands and the version number is assigned when a
   release is cut. **Do NOT invent a `### X.X.X` header for unreleased work.**
   Only when cutting a release does `## Unreleased` become
   `### X.X.X (YYYY-MM-DD) — HANDLE`, with `tr4w/src/Version.pas` bumped to
   match.

   **RELEASE_NOTES.md** — audience is operators on the air. Group by what they
   care about ("Radio Control", "CW", "Digital / WSJT-X", "Usability",
   "Multi-Op / Networking"), **not** by source file. Plain English, no file
   paths, no inline code, no source-level jargon.

   ```markdown
   #### User-Facing Category

   - Plain English description of what the operator will notice.
   ```

   **CHANGES.md** (ongoing mode only) — audience is developers. File paths and
   issue numbers in `####` headers, inline code encouraged.

   ```markdown
   #### Group Heading (`relevant/files`) — Issue #NNN

   - **Short bold title**: technical description of the change.
   ```

7. **Skip anything with no user-visible effect** from RELEASE_NOTES.md —
   diagnostic logging, internal refactors, build and test infrastructure,
   tooling. Most commits in this tree qualify, and that is correct: a release
   note is not a commit log. Translate what remains:

   - *"protect format specifiers as HTML, not as a clever marker"* → "Machine-seeded translations no longer lose their placeholders, so far more strings arrive ready for a translator to review."
   - *"the WSJT-X UDP thread stops writing the entry fields"* → **skip** — internal; the operator sees nothing change.
   - *"highlighting never worked reliably — two separate defects"* → "WSJT-X now reliably colours dupes and new multipliers in its decode list."

   Those same commits DO belong in `CHANGES.md` when it is back in scope.

8. **Show the draft to the user** before touching any file.

9. **On approval**, write and commit — both files in ONE commit when in ongoing
   mode:
   ```
   git -C /c/tr4w-d12 add RELEASE_NOTES.md          # + CHANGES.md in ongoing mode
   git -C /c/tr4w-d12 commit -m "RELEASE_NOTES: <short summary>"
   git -C /c/tr4w-d12 push d12 main
   ```

   **NO BRANCH DANCE.** The D7 original stashed, checked out `master`, pulled,
   popped and checked back, because work there happens on feature branches.
   Work here happens on `main`, so it is unnecessary — and the
   `stash push`/`stash pop` pair will happily move **uncommitted work the user
   did not intend to move**. If you are somehow on another branch, say so and
   stop rather than improvising.

   **If the push is rejected**, rebase or merge onto `d12/main` and push again.
   **NEVER** `--force` or `--force-with-lease`: `main` is shared across clones,
   a rewrite is blocked server-side by the `protect-main` ruleset, and a
   previous rewrite cost a day (see CLAUDE.md).

   **NO `Claude-Session:` trailer** — this repository is public and that trailer
   links a private transcript. `Co-Authored-By` is fine.

   The push is part of this command's flow: the user reviewed the draft at
   step 8, and a document-only commit does not affect tested feature work.

## Differences from the D7 original

Recorded so the two can be compared deliberately rather than by accident.

| | D7 (`C:\TR4W`) | here |
|---|---|---|
| files written | both, always | **RELEASE_NOTES only for the initial 5.x cut, then both** |
| repo path | `/c/TR4W` | `/c/tr4w-d12` |
| remote | `origin` | **`d12`** (no `origin` exists) |
| branch | `master` | **`main`** |
| version series | 4.x | **5.x** |
| section header | new `### X.X.X` per run | **appended under `## Unreleased`** |
| scope | all history | **after the baseline marker** |
| branch dance | stash / checkout / pull / pop | **removed** |
| commit trailer | not stated | **no `Claude-Session:`** |

The `feedback_no_pr_until_tested.md` override in the D7 original is dropped:
that file does not exist in this tree.
