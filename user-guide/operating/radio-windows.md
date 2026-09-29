# Radio 1 and Radio 2 windows

Open the radio panels from **Windows**. Each panel belongs to a configured radio slot; Radio 2 is not VFO B of Radio 1. The title can include the configured radio name.

| Field or indication | Meaning |
| --- | --- |
| VFO A and its mode | Frequency and mode reported for the first VFO. |
| VFO B and its mode | Frequency and mode reported for the second VFO, where the driver supplies them. The inactive VFO frequency is greyed. |
| RIT frequency | Reported receive incremental tuning offset. |
| RIT | Yellow when receive incremental tuning is on. |
| XIT | Yellow when transmit incremental tuning is on. |
| SPLIT | Yellow when split operation is on. Check which VFO transmits at the radio. |
| Status text | Status supplied by the radio polling/interface layer. |
| Light-blue panel background | This is TR4W's active radio. This indicates operating focus, not an assertion that it is transmitting. |
| Spectrum button | Opens this slot's panadapter when the connected radio both supports spectrum and currently makes it available. |

These panels display what the driver reports; a model's registration does not guarantee every field is supported. Compare the panel with the front panel while commissioning a radio. For SO2R, keep both panels visible and verify the active radio before sending or logging. Each spectrum-capable slot has its own panadapter window.

For a frozen frequency or a disconnected interface, use the checks under [Reset Radio Ports](../station/radio.md#reset-radio-ports).

??? info "Source check"
    `ui/lcl/uRadioPanelForm.lfm` and `.pas`, particularly `LabelFor`, `SetFlag`, `SyncActiveTint`, and `OpenPanadapterForSlot`; updates arrive through `uPanelUpdate` and `uRadioPolling`.
