# Use the band map

The band map organizes spots by operating frequency so you can find stations to work. Its contents depend on incoming spots, age, contest state, and display filters.

## Find and select a station

Open **Band map** from the Windows menu. Connect a [DX cluster](dxcluster.md) or use another configured spot source. Select a spot to inspect it; double-clicking invokes the tune-to-spot action.

In a two-radio setup, double-click behavior can target the inactive radio when the corresponding SO2R setting is enabled and both radios have frequency information. The context menu also offers **Send spot to inactive radio**. Verify which radio moves before relying on this during a contest.

Tuning to a spot does not complete or log a contact. Confirm the station's callsign and exchange on the air.

## Control what you see

Right-click the map for its display controls:

| Control | Purpose |
| --- | --- |
| BAND MAP ALL BANDS | Include spots outside the current band. |
| BAND MAP ALL MODES | Include other modes. |
| BAND MAP DISPLAY CQ | Control display of CQ entries. |
| BAND MAP DUPE DISPLAY | Control whether already-worked stations remain visible. |
| BAND MAP MULTS ONLY | Limit the view to spots classified as multipliers. |
| BAND MAP SO2R DISPLAY | Adjust the two-radio display behavior. |
| Delete selected spot / Remove all spots | Remove spot entries, not contacts from the contest log. |

Spot decay limits how long entries remain useful. [BAND MAP DECAY TIME](../reference/commands/a-d.md#band-map-decay-time) is used as minutes by the display's age calculation. A station can leave the frequency before the spot expires.

## Why a spot might disappear

Check band/mode filters, the mult-only filter, dupe visibility, and age before diagnosing a connection failure. A contact you just logged can change how its spot is classified. Compare the raw cluster console with the filtered map to separate reception from display.

## How the display stays separate from the data

The spot list owns the spot data; the LCL form owns selection, filtering, and painting. The view requests refreshes through a small interface, with refresh work coalesced by the timer rather than treating every incoming spot as a separate full redraw. This keeps the display and incoming-data processing distinct.

??? info "Evidence and review status"
    Current controls and tuning behavior: `ui/lcl/uBandMapForm.lfm` and `.pas`. Data/view boundary: `uBandMapView.pas` and `uSpots.pas`. Band-map design history (`docs/BANDMAP_LCL_DESIGN.md`) supplies rationale but predates the implemented LCL form. Two-radio behavior and colors need a running-build walkthrough.
