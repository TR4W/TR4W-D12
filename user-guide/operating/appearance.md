# Colors, log rows, and window recovery

## Set colors

Open **Settings → Colors**, or **Ctrl+J → Appearance → Colors**. Each row names a screen element. Choose its foreground (text) and background colors from the offered names; the sample shows the combination as you choose it. Apply or save the preferences to use the colors in the operating windows.

Start with the callsign and exchange fields, editable log, dupe indication, and multiplier indication. Keep text readable against its background. Some status colors deliberately override the normal element color—for example, dupe alerts and the active-radio indication. The Colors page is not a replacement for those status rules. WSJT-X highlighting also uses TR4W's configured dupe and multiplier colors when sending highlights is enabled.

## Show more QSOs in the main window

Drag the main window wider or taller. The log, possible-call and status areas use the available width, and the main text scales with width. The sent exchange appears above the call field. Set the font and **Main window text size** in **Preferences → Appearance**. The earlier `ROW COUNT` and `WINDOW SIZE` settings are retired.

**SHOW GRIDLINES** and **NO COLUMN HEADER** apply immediately. **NO COLUMN HEADER** hides the heading row on the log grids and the Network and Stations lists. Hold **Alt** and drag with the left mouse button to move a tool window whose title bar is hidden by **NO CAPTION**.

## Recover a window from a missing monitor

TR4W checks saved positions when opening windows and revalidates open windows after display changes. A window outside the usable displays is moved onto an available monitor. Several recovered windows are staggered so they do not all occupy the same position.

1. Confirm in the operating system's display settings that the disconnected monitor is no longer part of the desktop. A display that the OS still reports as present can still receive windows.
2. Restore minimized windows; the live recovery pass skips minimized windows. Open the desired tool window from **Windows** if it is closed.
3. If necessary, close and restart TR4W with the current monitor arrangement so saved positions are checked again.
4. Move the recovered windows where you want them and exit normally to save the layout.

If a monitor returns during the session, an untouched rescued window can return to its original position. Moving it yourself adopts the new position. Layout now lives in the `windows` section of `tr4w.json`; old advice to delete `tr4w.pos` does not reset the current JSON layout. Do not delete the entire settings file to recover one window. See [settings locations](../start/files.md).

??? info "Source check"
    Earlier manual: “Program Windows — Names and Colors.” Current implementation: `uPrefsForm` color grid and `SaveColorRows`, `uMainForm` resize anchors, `MainUnit.EnsureRectOnScreen`/`RevalidateOpenWindowsOnScreen`, and `uWindowLayoutStore`. Monitor recovery is code-reviewed here, not tested on physical displays.
