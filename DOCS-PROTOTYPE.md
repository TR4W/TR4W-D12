# Material for MkDocs experiment

Branch: `docs/mkdocs-prototype`. Editorial source: `user-guide/`. Configuration: `mkdocs.yml`.

The existing engineering `docs/` folder is intentionally not the site's input: it mixes plans, investigations, historical manuals, and current instructions. The operator guide selects and reconciles sources rather than presenting every Markdown file as current documentation.

## Preview

From this worktree, with Python 3.12:

```powershell
python -m venv .venv-docs
.\.venv-docs\Scripts\python -m pip install -r requirements-docs.txt
.\.venv-docs\Scripts\python -m mkdocs serve
```

Visit http://127.0.0.1:8000. On Linux/macOS, use `.venv-docs/bin/python` instead.

## Build and check

Regenerate command and radio references when their source changes:

```powershell
python tools/build_command_reference.py
python tools/build_language_reference.py
```

This reads only the current worktree. It checks inventory names against the frozen settings vocabulary, verifies property types, extracts literal constructor values, and rejects unparsed radio registrations. It does not use the older inventory scripts' hard-coded paths into the main checkout. Maintain reviewed descriptions in `tools/command_reference_notes.json`.

```powershell
.\.venv-docs\Scripts\python -m mkdocs build --strict
```

Output: `build-out/docs-site/index.html`. Flat HTML URLs and Material's offline plugin permit a local-file preview, including search. The generated site is ignored by Git. Dependencies pin the two primary packages; transitive dependencies are not yet locked.

## Sources and scope

See `user-guide/about/sources.md` for source revisions, evidence per page, and remaining operator reviews. The wiki can be fetched for comparison with:

```powershell
git clone --depth 1 https://github.com/TR4W/TR4W.wiki.git build-out/wiki-source
```

This prototype does not depend on that clone at build time. Wiki changes should be reviewed, not blindly imported. Preserve existing attribution if whole passages or images are migrated later.

## Completion criteria for the experiment

- Strict build passes with internal links and anchors checked.
- Navigation, theme switching, tabbed instructions, and search are usable.
- Operators can distinguish 4.x instructions from 5.x preview content.
- Source-only checks are clearly distinguished from hands-on verification.

The guide remains a documentation preview; it does not change the application or claim a complete manual conversion.

## GitHub Pages

Public preview: https://tr4w.github.io/TR4W-D12/

The Markdown, configuration, and reference generators live on `docs/mkdocs-prototype` in `TR4W/TR4W-D12`. GitHub Pages serves generated files from that repository's `gh-pages` branch, at `/` within the branch. The separate `TR4W/TR4W.github.io` repository continues to serve the earlier documentation at https://tr4w.github.io/.

For subsequent updates, commit and push the guide changes on the documentation branch, then build and publish from that branch:

```powershell
python -m pip install -r requirements-docs.txt
python -m mkdocs build --strict --config-file mkdocs.pages.yml
git push d12 docs/mkdocs-prototype
python -m mkdocs gh-deploy --strict --config-file mkdocs.pages.yml --remote-name d12 --remote-branch gh-pages
```

`d12` is this checkout's remote for `TR4W/TR4W-D12`; use `origin` instead in a clone with that remote name. Publishing is explicit, not automatic on every source push. Do not edit generated files on `gh-pages` directly. Do not add a `CNAME` or publish to the organization-site repository for this project site.

`mkdocs.pages.yml` supplies the project's hosted URL and enables normal web search behavior. Use `mkdocs.yml` for the local/offline preview. Both builds retain `.html` page links. Rebuild with the desired configuration before previewing or publishing.

The reference expansion adds 288 settings, 298 accepted setting names, the 335-name old-manual lookup, four actions, 88 withdrawn names, 39 store-owned names, and 101 radio registrations. These are distinct sets; they must not be summed and advertised as a single count of working features. Dedicated TCI and external-logger pages distinguish implemented behavior from selectable placeholders.

## Validation performed (September 24–25, 2026)

- `python -m mkdocs build --strict` passed with no MkDocs validation warnings.
- The expanded guide includes theory, operating windows, CW, native-platform installation and file locations, networking, reports/imports, INI migration, and generated contest/language references.
- Search output contains representative current and legacy command names, IC-705, DXKEEPER, and TCI.
- Reference regeneration is byte-for-byte deterministic. Representative checks passed for native K4 and TCI transports/ports/discovery, the separate Hamlib TCI bridge, retired/store-owned/action classification, and the WSJT-X source initial port.
- The offline search JavaScript bundle is present.
- Interactive/visual browser checks could not run because the browser connector reported no available browser. Theme switching, tab interaction, narrow-screen layout, and disconnected local-file search remain manual checks.
- No TR4W application or radio tests were run; page-level review limits are explicit.

## Positioning

Keep TR4W as the established product name. The guide leads with “TR4W — Cross-platform contest logging” and places the TRLOG lineage in its introduction and About page. Platform-specific editions remain TR4W for Windows, TR4W for macOS, and TR4W for Linux. Availability and readiness are qualified separately; this development snapshot is not evidence of a production-ready release on every platform.

Project-owner clarification on September 25 confirms that this version runs natively on macOS as well as Windows and Linux. The guide states that support directly while retaining feature-specific test limits.
