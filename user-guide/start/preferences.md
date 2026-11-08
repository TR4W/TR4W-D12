# Find and save settings

Open **Preferences** with **Ctrl+J**. Use the search box to find a setting by name, or choose a task in the tree.

The old **More settings** placeholder has been removed. Settings now belong to their relevant task pages. Search is the quickest route when a setting has moved.

## Save changes

**Save** writes changes and keeps Preferences open. **Save and close** writes them and closes the window. **Cancel** discards pending changes. Check each setting's help and restart notice: some changes apply immediately; others need a restart.

For [external loggers](../station/external-loggers.md), saving applies enable/disable and ordering immediately. New logger definitions and changed connections need a restart. For radios, **FREQUENCY POLL RATE** is now in that radio's **Advanced** settings, so configure each radio separately.

Passwords and API keys use the operating system's credential store. A settings-file backup alone does not move these secrets to another machine.

## Contest pages in newer source

**Unreleased source through 48806af1** organizes Contest settings into **QSO settings**, **Modes**, **Initial exchange**, **Multiplier data**, **Quick QSL**, **QTC**, **Contest rules**, and **Cabrillo headings**. The initial-exchange and call-history filename controls have browse buttons. An older installed release may show a different tree.

Use a setting's help tooltip for its meaning. The generated [command reference snapshot](../reference/commands/index.md) preserves older names and descriptions; it is not a complete inventory of these newer pages.
