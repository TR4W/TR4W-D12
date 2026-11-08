# Recent guide updates

## November 8, 2026 — 5.0.37 and marked source additions

Reviewed RELEASE_NOTES.md and CHANGES.md against the previous 5.0.26 baseline, using source through **48806af1**.

- Added [Preferences guidance](../start/preferences.md) and [contest additions and rule checks](../operating/contests.md).
- Replaced obsolete singleton-logger instructions with the editable grid, Save/restart rules, queue status, provider fields, and operation limits.
- Corrected backups: local snapshots work without an external destination; optional copies run in the background; the interval counts newly logged records.
- Corrected ADIF import transaction semantics, restore guidance, and export filenames.
- Updated contest creation/reopening, per-radio polling, keyboard guidance, and translation notes.
- Marked protocol-2 networking, Sweepstakes history downloads, multiplier targets, Cloudlog/Wavelog, and ACLog as Unreleased source features.

The generated inventories remain historical snapshots. The command-reference generator correctly refused vocabulary drift; updating its inventory/extraction is a separate maintenance task. Strict offline and hosted site builds passed, including navigation and anchor validation. This review did not install release packages or run hardware/live-service tests.

The September entry below records its historical scope; its then-unmerged contest work has since landed.

## September 29, 2026 — 5.0.26

Reviewed main-branch changes from `24f06a3` through `3753d2ba`, and checked the published 5.0.26 assets.

- [Installation](../start/install.md): Apple Silicon `.pkg`, `.dmg`, and archive choices; signed/notarized packages; the installer does not include `tr4wserver`.
- [Radio operation](../station/radio.md): Icom authentication recovery, session renewal, radio-specific band stepping, and corrected 1.25 m / 33 cm / 23 cm classification.
- [Radio windows](../operating/radio-windows.md): persistent, independent connection-status panels; matching cluster/network guidance.
- [Keyboard](../operating/keyboard.md): menu shortcut display, focused editing, autosend, and tool-window key handling.
- [Diagnostics](../log/diagnostics.md): append-only logs, quieter DEBUG output, and matching crash symbols.
- [INI migration](../start/ini-to-json.md): explicit legacy source paths and scope limited to existing settings, rather than a requirement for new native-platform users.
- [Testing](../theory/testing.md): recorded Icom soak results and new regression coverage.

The generated settings, radio, contest, and language inventories retain their original source provenance. The reviewed main-branch changes do not add inventory entries. This update does not merge application code into the documentation branch.

The separate local `contestFactory` work through `20943bc1` is newer than published main. Its contest/scoring changes are not described as released 5.0.26 behavior. They need a follow-up documentation review when that development line becomes the guide's target.

Installer-design and setup-wizard proposals were distinguished from implemented behavior. This update did not run an installer or perform on-air tests.
