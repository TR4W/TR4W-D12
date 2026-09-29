# Choose a CW sending method

TR4W's CW sending layer selects one active method for sending text. Radio CAT control, CW generation, PTT, and two-radio output routing are related but separate parts of station setup.

| Method | What generates the CW | What to check |
| --- | --- | --- |
| CW by CAT | The radio receives text through its supported control protocol and keys it | Model capability, connection, speed, buffering, and stop behavior. |
| WinKeyer | An external WinKeyer device | Correct keyer port, successful device connection, output routing, and speed control. |
| YCCC SO2R+ | The external YCCC device | Device connection, selected output, and SO2R configuration. |
| CPU/software keyer | TR4W supplies timed keying through the configured output | Output line configuration and platform timing support. |

The [radio reference](../reference/radios.md) identifies transport support, not a complete CW capability matrix. A network connection or native driver alone does not establish CW-by-CAT support.

## Selection precedence

The current selector chooses CW by CAT when active, otherwise an active WinKeyer, otherwise an active YCCC device, and finally the CPU keyer. Configuration and successful activation are not interchangeable: a WinKeyer that never opens is not the active device.

Avoid configuring several methods and assuming they send together. The code reports conflicts because CW-by-CAT can take precedence over a hardware keyer for the active radio.

## Configure and test

1. Select the intended method for your radio and platform.
2. For an external keyer, review **CW keying device**, **Keyer type**, and **Port**. The WinKeyer panel exposes timing, sidetone, weight, paddle, and speed-pot options.
3. For software keying, review the radio's separate keyer-output and RTS/DTR controls. CAT port settings alone do not configure those lines.
4. Review the function-key text with **Alt+P** before sending it. Use **Alt+S** to review CW speed.
5. With an appropriate station test setup, check a short message, a longer buffered message, speed changes, and cancellation with **Esc**.
6. In a two-radio station, verify which output keys and that switching radios does not leave an earlier message transmitting.

The CAT path has a specific sole-transmitter interlock because two radios have independent CW buffers. Hardware keyers route a shared keying engine to an output; their switching behavior is different. Test both routing and message cancellation with the actual station hardware.

## Platform limits

The Linux preview notes identify gaps in host-timed CW. Do not assume CPU keying has the same timing behavior on every platform, or that an older manual's LPT instructions apply. External-device and CAT paths have their own verification requirements.

## Related settings and evidence

Start with [CODE SPEED](../reference/commands/a-d.md#code-speed), [ALL CW MESSAGES CHAINABLE](../reference/commands/a-d.md#all-cw-messages-chainable), and [WEIGHT](../reference/commands/t-z.md#weight); inherited help remains labeled in that reference.

??? info "Source check"
    Selection and conflict handling: `uCWKeyerBase.pas`. Implementations: `uCWKeyerCAT.pas`, `uCWKeyerWinKey.pas`, `uCWKeyerYCCC.pas`, and `uCWKeyerCPU.pas`. UI: `ui/lcl/uKeyerEditForm.lfm`. The factory design (`docs/CW_Keyer_Factory_Plan.md`) provides historical rationale; its older output descriptions are not proof of current platform support. No on-air keying tests were run for this guide.
