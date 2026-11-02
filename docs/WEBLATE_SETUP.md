# Weblate setup for the TR4W catalogues

Written 2026-11-02 for the agent on the Weblate machine (`ssh mint`). NY4I's plan: the TR4W
community reviews translations in Weblate, and Weblate writes the `.po` files back to GitHub.

This is a brief, not a finished configuration. Where it says "check", look at what Weblate
actually does and report; do not assume.

## 0. State of the repository

Everything is committed and pushed. Nothing translation-related is uncommitted on the
Windows machine. The newest commit that touches a catalogue is `6e70eb88` on `main`
(remote `d12`, repository `TR4W/TR4W-D12`). Pull `main` fast-forward only before configuring
anything. If a clone on mint has local changes to `i18n/`, stop and tell NY4I rather than
discarding them.

`i18n/inboundFromTranslators/` is untracked on the Windows machine and is not part of this.

## 1. What is in the repository

| Components | Files | Template | Notes |
|---|---|---|---|
| TR4W UI | `i18n/tr4w_<code>.po` (21 languages) | `tr4w/languages/tr4w_laz.pot` | Lazarus catalogue. `msgctxt` is a unit-qualified identifier and `msgid` is the English. The program matches by `msgctxt`, so Weblate must preserve it. |
| TR4W help | `i18n/help_<code>.po` (22 files, includes `help_en.po`) | none | One entry per Preferences setting. `msgctxt` is `TC_HELP_<NAME>`, `msgid` is the English. There are no `#:` source lines; that is expected. |

Language codes are `cs da de el es fi fr it ja ko mn nl pl pt pt_BR ro ru sr sv uk zh_CN`.
`pt_BR` and `zh_CN` keep the underscore and the capitals; Linux is case-sensitive and the
program looks for exactly those names.

English is the source language. There is no `tr4w_en.po`. `help_en.po` is the English help
text itself, not a translation, so Weblate must not treat it as a target language
(exclude `en` with the component's language regex).

Ignore `i18n/*.mo` (three stray binaries) and `i18n/languages.json`.

## 2. Suggested components

Two components, both file format "gettext PO file", both bilingual (the English is in `msgid`).

- **TR4W UI:** file mask `i18n/tr4w_*.po`, new-base template `tr4w/languages/tr4w_laz.pot`.
- **TR4W help:** file mask `i18n/help_*.po`, language regex excluding `en`, no template.

Check that Weblate reads a language file whose header says `Language: pt_BR` as `pt_BR`
and not `pt`. Check that `mn` and `sr` appear even though almost all of their entries are
empty (they have no machine-translation engine).

## 3. Rules the integration must respect

1. **Fuzzy is the review record.** An entry with `#, fuzzy` is an unreviewed machine draft.
   Weblate's "Needs editing" state is the same thing. A reviewer saving a string clears it,
   one string at a time. **Never bulk-clear fuzzy**, never run Weblate's "mark all as
   approved/translated" over a language, and do not enable automatic translation that
   accepts machine suggestions without review. The program ships fuzzy entries on purpose,
   and the flag is the only thing that says which text a native speaker has read.
2. **Keep `msgctxt`.** Do not let the component add `#:` lines, renumber, or reorder in a way
   that changes `msgctxt`. The Lazarus loader matches on it.
3. **Keep the previous-text lines.** Entries reworded in English carry `#| msgid "..."` and
   a dated `# ` comment. Weblate understands `#|`; do not strip them.
4. **Obsolete entries (`#~`) are intentional.** They are removed later by our own merge
   tool. Do not delete them in Weblate.
5. **Never run `pas2po`, `ini2po.py` or `mt_seed.py` from the Weblate machine.** Those are
   run by NY4I on the Windows machine. In particular `ini2po.py` must not run at all yet
   (issue #152). Weblate edits entries; it never generates them.
6. **Do not edit `tr4w/target/commands_help_*.ini`.** They are historical reference files.

## 4. Git settings

- Repository: `git@github.com:TR4W/TR4W-D12.git`, branch `main`.
- **Push to a branch, not `main`.** Set Weblate's push branch (for example `weblate`) and have
  changes arrive by pull request. `main` is shared across clones, rejects any non-fast-forward
  push, and the Windows machine regenerates files that Weblate also edits; a direct push
  would collide. Never force-push anything to `main`.
- Merge style: rebase or merge is fine for the `weblate` branch. Never rewrite `main`.
- **Commit messages:** no `Claude-Session:` trailer, and nothing that links a transcript.
  The repository is public. Weblate's own author and message are fine.
- Commits touch only `i18n/*.po` (and the template if Weblate regenerates it; prefer that it
  does not). If a Weblate commit changes any other path, stop and report.

## 5. Line endings

The repository stores text as LF and checks it out CRLF (`*  text=auto eol=crlf` in
`.gitattributes`), so the `.po` files on disk are CRLF. Weblate may write LF. Git normalises
that on commit, so the stored blobs should be identical either way.

**Check this before the first push:** make one edit in Weblate, let it commit, then run
`git diff --stat <before>..<after>` and confirm only the edited entries changed, not whole
files. If whole files show as changed, stop and report; do not push.

## 6. First-run checks to report back to NY4I

- The component lists 21 + 21 target languages (22 help files minus `en`), with the entry
  counts below. Counts are for `6e70eb88`; measure rather than trusting this table.

  | Catalogue | Expected |
  |---|---|
  | `help_*` | 425 live entries per language (`help_en` as source) |
  | `tr4w_*` | the template's entry count |

- Fuzzy entries show as "Needs editing" and the translated count is not inflated.
- A one-entry edit round-trips: Weblate saves, commits to the branch, the diff is one entry.
- Weblate does not create new language files under a different name pattern. If it offers
  "start new translation", the file name must be `i18n/tr4w_<code>.po` or
  `i18n/help_<code>.po` with the same code spelling as above.
- Whether the Weblate account or integration needs a GitHub deploy key or token, and where
  it is stored. Do not write that secret into this repository or its history.

## 7. What happens after Weblate merges

On the Windows machine NY4I pulls, and the build regenerates `tr4w/res/tr4w_languages.res`
from the `tr4w_*.po` files (a hash mismatch triggers it). The help catalogues are read at run
time from `help/help_<code>.po`, so a merged help file takes effect without that step. No
action is needed on the Weblate machine for either.

## 8. Not part of this task

Do not translate anything yourself, do not run any seeding or machine-translation script,
and do not change any `.po` outside Weblate's own commits. Reporting what you find is the
deliverable.
