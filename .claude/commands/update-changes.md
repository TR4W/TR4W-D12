Update both CHANGES.md (developer-level technical changelog) and RELEASE_NOTES.md (user-facing release notes) with any commits not yet documented, using the version number from `tr4w/src/Version.pas`.

> **Ported from the D7 tree (`C:\TR4W`) on 2026-08-30 and ADAPTED — do not diff
> it against the original expecting a match.** The repository, remote and branch
> are all different here: `TR4W/TR4W-D12`, remote **`d12`** (there is no
> `origin`), branch **`main`** (there is no `master`). Every git command below
> reflects that. See [Differences from the D7 original](#differences-from-the-d7-original).

## Steps

1. **Read the current version** from `tr4w/src/Version.pas` — extract the value of `TR4W_CURRENTVERSION_NUMBER`. This tree is on the **5.x** series; the D7 tree was on 4.x.

2. **Read both `CHANGES.md` and `RELEASE_NOTES.md`** — scan each for version headers of the form `### X.X.X` to find documented versions. If the current version is present in BOTH, report "CHANGES.md and RELEASE_NOTES.md are already up to date for vX.X.X" and stop. If it is in one but not the other, proceed but flag the asymmetry to the user.

3. **STOP AND ASK IF THE BACKLOG IS LARGE.** Both files are inherited from the D7 tree and their newest entry is `4.149.00` (2026-07-02), while this tree is on 5.x — so *every commit of the D12/FPC port is undocumented*. A naive run would try to write up hundreds of commits in one section, which is not a changelog entry, it is a rewrite.

   Count the undocumented commits first. **If there are more than ~30, do not draft. Report the count and ask how the user wants the port documented** — one summary entry for 5.0.0, a per-area breakdown, or a deliberate baseline reset. This step exists because the D7 original assumed a handful of commits since the last release and that assumption does not hold here yet.

4. **Find undocumented commits** — run:
   ```
   git -C /c/tr4w-d12 log --format="%h %s" d12/main
   ```
   For each non-merge commit (exclude subjects starting with "Merge pull request" or "Merge branch"), check whether the commit subject appears anywhere in the full text of CHANGES.md. A commit counts as documented if any 6+ consecutive words from its subject appear verbatim in CHANGES.md. Collect the rest.

   Also exclude pure version-bump commits (subject contains "Update Version.pas" or "version bump").

5. **Determine contributor** — look at the author of the most recent non-merge, non-version-bump commit:
   ```
   git -C /c/tr4w-d12 log --format="%an" d12/main
   ```
   Map known authors to their handle: "Tom Schaefer" → NY4I, "Howie Hoyt" or "n4af" → N4AF, "Gavin Taylor" → GM0GAV.

6. **Draft the CHANGES.md section** — technical, audience is developers. Include file paths and issue numbers in `####` headers. Inline code (function names, type names, file paths) is encouraged. Insert immediately after the `---` separator that follows the contributors table (before any existing `## X.X.x` section). Use today's date (YYYY-MM-DD). Match the style of existing entries:

```markdown
### X.X.X (YYYY-MM-DD) — HANDLE

#### Group Heading (`relevant/files`) — Issue #NNN (if applicable)

- **Short bold title**: technical description of change.

---
```

Group related commits under a shared `####` heading. Each undocumented commit becomes one bullet.

7. **Draft the RELEASE_NOTES.md section** — user-facing, audience is operators on the air. Group by what the operator cares about (e.g. "Radio Control", "CW", "Digital / WSJT-X", "Usability", "Multi-Op / Networking"), NOT by source file or module. Plain English; NO file paths in headers, NO inline code, NO source-level jargon. Insert at the same position as CHANGES.md. Match existing RELEASE_NOTES.md style:

```markdown
### X.X.X (YYYY-MM-DD) — HANDLE

#### User-Facing Category

- Plain English description focused on what the operator will notice.

---
```

Skip commits with no user-visible effect (diagnostic logging, internal refactors, build/test infrastructure). Translate technical changes into operator-relevant language:

- "protect format specifiers as HTML, not as a clever marker" → "Machine-seeded translations no longer lose their `%s` placeholders, so far more strings arrive ready for a translator to review."
- "the WSJT-X UDP thread stops writing the entry fields" → nothing — internal, no operator-visible change. Skip it.
- "highlighting never worked reliably — two separate defects" → "WSJT-X now reliably colours dupes and new multipliers in its decode list."

8. **Show BOTH drafts** to the user for review before touching any files.

9. **On approval**, write both files and commit BOTH in ONE commit on `main`:
   ```
   git -C /c/tr4w-d12 add CHANGES.md RELEASE_NOTES.md
   git -C /c/tr4w-d12 commit -m "CHANGES + RELEASE_NOTES: document v X.X.X"
   git -C /c/tr4w-d12 push d12 main
   ```

   **NO BRANCH DANCE.** The D7 original stashed, checked out `master`, pulled, popped and checked back out, because work there happened on feature branches. Work here happens on `main`, so that sequence is unnecessary and its `stash push`/`stash pop` pair is a real hazard — it moves *uncommitted work you did not intend to move*. If you are genuinely on another branch, say so and stop rather than improvising.

   **If the push is rejected**, rebase or merge onto `d12/main` and push again. **NEVER** `--force` or `--force-with-lease`: `main` is shared across clones, a rewrite is blocked server-side by the `protect-main` ruleset, and a previous rewrite cost a day (see CLAUDE.md).

   **NO `Claude-Session:` TRAILER** in the commit message. This repository is public and that trailer links a private transcript. `Co-Authored-By` is fine.

   The push is part of this command's flow: the user reviewed and approved the drafts at step 8. Document-only commits do not affect tested feature work.

## Differences from the D7 original

Recorded so the two can be compared deliberately rather than accidentally.

| | D7 (`C:\TR4W`) | here |
|---|---|---|
| repo path | `/c/TR4W` | `/c/tr4w-d12` |
| remote | `origin` | **`d12`** (no `origin` exists) |
| branch | `master` | **`main`** |
| version series | 4.x | **5.x** |
| branch dance in step 9 | stash / checkout / pull / pop | **removed** — work happens on `main` |
| backlog guard | none | **step 3** — the D7 assumption of a small delta does not hold here yet |
| commit trailer rule | not stated | **no `Claude-Session:`** — this repo is public |

The `feedback_no_pr_until_tested.md` override in the D7 original is dropped: that file does not exist in this tree.
