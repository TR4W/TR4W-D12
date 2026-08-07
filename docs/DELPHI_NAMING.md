# Delphi naming — component prefixes

NY4I's convention, supplied 2026-08-07. **Applies to all new code**, and the existing FMX
Preferences forms were brought into line the same day (`uRadioEditForm`, `uPrefsForm`).

## Component prefixes

| Component | Prefix | | Component | Prefix | | Component | Prefix |
|---|---|---|---|---|---|---|---|
| Actions | `act` | | Images | `img` | | Scroll Bars | `sbr` |
| Bevels | `bvl` | | Labels | `lbl` | | Scroll Boxes | `sbx` |
| Buttons | `btn` | | List Boxes | `lst` | | Shapes | `shp` |
| Check Boxes | `chk` | | List Views | `lvw` | | Splitters | `spl` |
| Combo Boxes | `cbx` | | Menus | `mnu` | | Status Panes | `sts` |
| Data Sources | `src` | | Navigators | `nav` | | Stored Procs | `stp` |
| Dialogs | `dlg` | | Radio Buttons | `opt` | | Tab Controls | `tbc` |
| Edits, Memos | `edt` | | Page Controls | `pgc` | | Tab Sheets | `tab` |
| Forms | `frm` | | Paint Boxes | `pbx` | | Tables | `tbl` |
| Grids | `grd` | | Panels | `pnl` | | Timers | `tmr` |
| Group Boxes | `grp` | | Progress Bars | `pbr` | | Track Bars | `trk` |
| Headers | `hdr` | | Queries | `qry` | | Tree Views | `tvw` |
| Image Lists | `iml` | | Rich Edits | `rtf` | | | |

**Forms are named `frm…`.**

## Additions for FMX, which the table predates

| Component | Prefix | Why |
|---|---|---|
| `TLayout` | `lay` | No VCL equivalent. It is a container, but `pnl` would misdescribe it — a layout draws nothing. |
| `TTabItem` | `tab` | The FMX spelling of a Tab Sheet, so it takes the Tab Sheet prefix. |

## Local conventions that override nothing but are worth knowing

- **Nav items are `nav…`** on Tag-dispatched forms (`navStation`, `navHardware`). This is
  load-bearing, not cosmetic: `build/Lint-FormTags.ps1` identifies section selectors by that
  prefix. Renaming one silently drops it from the lint.
- **Control fields on a designed form are published and carry no `F`.** Streaming binds a
  control to a field only when the field name matches the component `Name` exactly, and the
  IDE generates unprefixed names for anything dropped later. Non-control state keeps `F` and
  stays private. See `docs/CFG_COMMAND_TABLE.md`'s sibling discussion in
  `uRadioEditForm.pas`'s header.

## Corrections applied 2026-08-07

The first pass at the FMX Preferences forms used three prefixes that disagree with the
table; they were renamed before the CW Settings section added more controls:

| Was | Now | |
|---|---|---|
| `cboType`, `cboPort`, `cboFound`, `cboKeyerPort`, `cboProfile`, `cboRadio1/2`, `cboCW1/2` | `cbx…` | Combo Boxes |
| `rbData7/8`, `rbParityNone/Odd/Even`, `rbStop1/2` | `opt…` | Radio Buttons |
| `tabsTransport` | `tbcTransport` | Tab Control |
