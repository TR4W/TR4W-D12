# SO2R: one operator, two radios

SO2R lets you run on one radio while searching for another contact on the other. TR4W distinguishes the **active radio**, whose operating context you are using, from the **inactive radio**. Two radio windows alone do not configure audio, PTT, or CW routing.

## Commission the station

1. Configure and test each [radio connection](radio.md) separately. Open both [radio panels](../operating/radio-windows.md) and check frequency, mode, and active-radio indication.
2. Configure the intended [CW keyer](cw.md) and station switching hardware. Verify which radio is keyed and which audio you hear for each selection. A successful CAT connection does not establish correct transmit routing.
3. In **Ctrl+J**, enable **TWO RADIO MODE**. The earlier SO2R tips also recommend **ALT-D BUFFER ENABLE** and **TUNE ALT-D ENABLE** for an inactive-radio search workflow; configure these to suit your operation.
4. Test **Alt+R** to swap radios. Confirm the active highlight and logging band/mode, then swap back.
5. Rehearse a complete contact on each radio in a practice log before adding automation.

## Use the inactive radio

**Alt+D** invokes dupe checking on the inactive radio. Use it to investigate a call while retaining the running-radio context. The Alt-D buffer and tuning option support bringing spotted calls into this workflow. Check the displayed radio and contact before completing the QSO; **Alt+R** is the explicit swap action.

For a band map focused on the search radio, review **SO2R DISPLAY**, disable **ALL BANDS** if appropriate, and configure **QSY INACTIVE RADIO**. See [band map operation](../operating/bandmap.md) for the actual filters and tuning behavior. Verify a spot selection tunes the intended radio before using it during a run.

## Add message automation gradually

Program ordinary CQ and exchange messages first, then add inactive-radio sending or radio-swap commands through the [message editor](cw-messages.md). The earlier wiki warns that combining inactive-radio transmission with a focus switch while entering the running radio's exchange can associate that contact with the other radio. Finish or deliberately preserve the current contact before changing context.

Practice stopping messages with **Esc**, recovering from a mistaken swap, and checking the logged band/mode. The old recommendation to use WinKey is an operating suggestion, not a requirement that every SO2R installation use that hardware: the current application also has CAT and YCCC sending paths. Their availability and routing depend on the configured hardware and driver.

??? info "Source check"
    Baseline: wiki `SO2R-Tips.md`. Current checks: `MainUnit` handlers for `menu_alt_dupecheck` and `menu_alt_tooglerigs`, `uAccelerators` (Alt+D/Alt+R), the current command reference, radio-panel active tint, and the CW adapters. Hardware timing, interlocks, and a complete two-radio contest remain bench-review tasks.
