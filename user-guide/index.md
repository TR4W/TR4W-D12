# TR4W — Cross-platform contest logging

A free, open-source contest logger rooted in N6TR's TRLOG. TR4W brings keyboard-driven exchange entry, radio control, and digital-mode integration to your station.

Native on **Windows, macOS, and Linux**. [Install the build for your platform](start/install.md) and check its release-specific notes.

!!! warning "5.x documentation preview"
    These pages target the **5.x preview, updated through 5.0.26**, not the public 4.x manual. They have been checked against source files, but the procedures still need an operator walkthrough. See [Choose your version](start/version.md) before following them.

For the earlier TR4W version, see the [existing TR4W documentation](https://tr4w.github.io/).

<div class="grid cards" markdown>

- **Start a contest**

    Choose a contest, enter your station call, and reopen your log.

    [Open your first contest →](start/first-contest.md)

- **Connect your radio**

    Set up serial or network CAT and check that frequency follows the rig.

    [Set up radio control →](station/radio.md)

- **Use WSJT-X**

    Match the UDP settings and check that a logged contact reaches TR4W.

    [Connect WSJT-X →](station/wsjtx.md)

- **Bring an older log**

    Understand the change from legacy contest files to a database.

    [Moving from 4.x →](start/migration.md)

- **Operate from a park**

    Set your park, enter park-to-park exchanges, and handle multiple parks.

    [POTA operating guide →](operating/pota.md)

- **Protect and export your log**

    Configure verified backups and prepare files for another logger or a contest sponsor.

    [Back up your log →](log/backup.md) · [Export your log →](log/export.md)

</div>

## Before a contest

Use a separate practice contest to check your exchange, radio connection, CW or voice messages, and log export. Confirm the submitted log format and exchange requirements with the contest organizer. A successful radio connection alone does not check keying or scoring.

Start with [installation](start/install.md), [file locations](start/files.md), and [data updates](start/data-updates.md). Moving an older station? Review [INI-to-JSON conversion](start/ini-to-json.md) and [contact import](log/import.md) separately.

## Operating and understanding TR4W

- Browse [available contests](reference/contests.md) and [languages with testing codes](reference/languages.md).
- Use the [band map](operating/bandmap.md), [DX cluster](operating/dxcluster.md), and [multiplier windows](operating/multipliers.md).
- Configure [CW sending](station/cw.md) and [multi-station networking](station/network.md).
- Understand [SQLite integrity](theory/database.md), [test methodology](theory/testing.md), and [reports](log/reports.md).

## Looking for another topic?

Search this guide by task or configuration name, such as `WSJT-X BROADCAST PORT`. Browse the [command reference](reference/commands/index.md), check an older name in the [old-to-new lookup](reference/commands/legacy-map.md), or find your model in the [radio support table](reference/radios.md).

For other software, see [TCI](station/tci.md), [WSJT-X](station/wsjtx.md), and [external loggers](station/external-loggers.md). The [earlier manuals and wiki](reference/legacy.md) cover additional topics; their instructions may differ from 5.x.
