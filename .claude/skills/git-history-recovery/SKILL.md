---
name: git-history-recovery
description: What happened to TR4W's git history in the 2026-08-19 filter-branch rewrite, and how to recover a clone that is behind it. Use when a git pull produces hundreds of conflicts, when commits appear duplicated or unsigned, or when someone proposes re-signing or re-stripping history.
---

# The 2026-08-19 history rewrite, and how to recover from it

Moved out of `CLAUDE.md` on 2026-08-31 because it is a **one-time recipe**: needed
when a stale clone turns up, and never otherwise, so it does not earn a place in
every session's context. The *prohibitions* it implies stayed behind in
`CLAUDE.md` — "**NEVER force-push `main`**" and "**DO NOT RE-SIGN OR RE-STRIP
HISTORY**" — because a safety rule must not be one invocation away from being
missed.

## What actually happened, so nobody chases the wrong commits

**The rewrite was 2026-08-19 at 12:04, not 2026-08-29.** The 29th is when a stale
clone first *fetched* it — that clone's tip was `152118b2` from **2026-08-14**, so
it met a ten-day-old force-push and reported it as same-day. Every push on
2026-08-29 was an ordinary fast-forward.

It was **deliberate**: `git filter-branch` over `fpc` to strip `Claude-Session:`
trailers, which are links to private transcripts and do not belong in a public
repo. Whoever ran it took a backup first — `backup-pre-trailer-strip-2026-08-19`,
still present, tip `e815d7a3`. `.git/refs/original/` was also left behind, which
is `filter-branch`'s fingerprint.

Signature loss was collateral: `filter-branch` re-creates every commit and
`gpgsig` does not survive. Hence **741 unsigned commits dated 2026-08-19 or
earlier, and 335 signed after it**.

**Three things follow, and the third is the one that will tempt someone:**

1. The cleanup did not hold — **12 more commits carrying the trailer landed
   after it**, 2026-08-25 to 2026-08-29. Not because a rule was ignored: **there
   was no rule.** CLAUDE.md had zero mentions of the trailer until 2026-08-29.
   That is now fixed there, and it is a one-line fix, not a mechanism.
2. A stale clone must **reset, not merge** — the recipe below.
3. **DO NOT RE-SIGN OR RE-STRIP HISTORY.** Mixed signing across the 2026-08-19
   boundary is cosmetic and signing is deliberately not enforced. "Tidying" it
   means another `filter-branch`, another force-push, and another round of broken
   clones — this time against a ruleset that will reject it. The unsigned commits
   broke nothing. Rewriting did.

## Recovering a clone that is behind the rewrite

A `git pull` will produce hundreds of conflicts. **Do not resolve them** — the
trees are identical, so there is nothing to resolve. The merge base moved back to
`0913dec7` (2026-07-06), so git tries to merge 560 commits against 1054 rewritten
twins of the same work and reports 200+ conflicts across the whole tree.

**Check for local work first**, then reset:

```powershell
git -C <clone> status --short                  # anything uncommitted? save it elsewhere first
git -C <clone> log --oneline d12/main..main    # any local commits not on the remote?
git -C <clone> fetch d12
git -C <clone> reset --hard d12/main
```

If the middle command lists commits, those are yours and `reset` would discard
them: cherry-pick them onto `d12/main` afterwards rather than merging.
