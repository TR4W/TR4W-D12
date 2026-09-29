# Keyboard essentials

Learn a small set of commands in a practice contest before adding more. These bindings are taken from the current accelerator table, rather than the older shortcut inventory.

## Settings and log review

| Keys | Action |
| --- | --- |
| **Ctrl+J** | Open settings. |
| **Ctrl+L** | View / Edit log. |
| **Alt+L** | Search log. |
| **Ctrl+N** | Add a note. |
| **Ctrl+R** | Recall last entry. |
| **Alt+F** | Back up the log to the configured destination. |

[Configure backups](../log/backup.md) before relying on Alt+F. With no destination set, the backup handler returns without creating a copy.

## Operating tools

| Keys | Action |
| --- | --- |
| **Alt+D** | Dupe check. |
| **Alt+P** | Open Fkeys. |
| **Alt+S** | CW speed. |
| **Ctrl+U** | View packet spots. |
| **Ctrl+Y** | Refresh band map. |
| **Ctrl+T** | Repeat the saved POTA park exchange for another callsign. |
| **Ctrl+Enter** | Log QSO without CW. |

Ctrl+Enter is a logging action: check the call and exchange before using it. Function-key messages depend on your configuration; review their contents before transmitting.

## If a shortcut does not work

Return focus to the main operating window and check the matching menu item. A dialog, text field, desktop shortcut, or keyboard layout may affect delivery of the key combination. Record the operating system, active window, and exact combination when reporting a mismatch.

!!! note "A focused reference"
    This is a selected list, not a complete keyboard specification. Context-sensitive entry keys and programmable messages require a separate operating walkthrough. The April inventory's “Ctrl+T is free” entry is superseded by the current POTA binding.

??? info "Source check"
    `tr4w/src/uAccelerators.pas` defines the displayed combinations and installed menu accelerators. Action labels and dispatch were checked in `uMenu.pas`, `uTR4WStrings.pas`, and `MainUnit.pas`. Actual delivery on each supported desktop has not been tested for this guide.
