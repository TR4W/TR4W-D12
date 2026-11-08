# TCI connections

TCI can connect TR4W to a software-defined radio application, or let other software control a radio already connected to TR4W. Choose the direction you need before configuring ports.

| Your goal | TR4W's role | Configure here |
| --- | --- | --- |
| Control a TCI-capable radio application from TR4W | TCI client / native radio driver | Radio configuration |
| Let another program control TR4W's connected radio | TCI server | Preferences, TCI Server |

These are separate connections. Neither one supplies a complete audio setup.

## Connect TR4W to a TCI radio application

1. Enable the TCI service in the radio application and note its address and port.
2. In TR4W's radio configuration, select **TCI (ExpertSDR / Thetis / AetherSDR)**.
3. Enter the radio application's address and port under **Network**. The registration seeds port `50001`; use the actual service port if different.
4. Save the radio configuration and check frequency and mode updates before testing transmit functions.

This is a native TR4W driver, registered under ID `TCI`, with a network connection and no discovery support. The older **Expert TCI (HamLib bridge)** is a separate placeholder whose backend is described as unavailable in the shipped Hamlib build; choosing it does not select the native driver.

## Let another application connect to TR4W

1. Establish and verify the radio's normal connection to TR4W first.
2. Open the **TCI Server** section in Preferences and select **Enable the TCI server**.
3. Set **Port:** to an unused listening port and apply the settings.
4. In the client application, select its TCI connection and use TR4W's address and the same port.
5. Check the intended receiver: TR4W maps **Radio 1 to trx 0** and **Radio 2 to trx 1**.
6. Verify frequency and mode control before testing PTT. Set **Stop transmitting after:** to the transmit limit appropriate for your test.

By default, the server listens on the local computer (`127.0.0.1`). **Also listen on the network (other computers can connect)** changes that scope. The form warns that this is an unauthenticated control socket: a reachable client can move the VFO and key the transmitter. Leave network listening off when all clients run locally.

## What the server does not provide

The server does not emit audio or IQ streams; clients still need their own audio path. Its handlers also identify `cw_msg` and CW-speed requests as unimplemented in this snapshot. Do not infer server support from capabilities of the separate native TCI radio driver.

## TCI and WSJT-X

[WSJT-X UDP integration](wsjtx.md) carries decoded-call, highlight, and logged-QSO information. TCI concerns a radio-control connection. Configuring one does not automatically configure the other. Confirm which radio-control interfaces your particular client build actually offers.

??? info "Evidence and review status"
    Native registration: `radioFactory/uRadioTCI.pas`. Bridge limitation: `radioFactory/uRadioHamLibOnly.pas`. Server behavior and limits: `uTCIServer.pas`. Controls: `ui/lcl/uPrefsForm.lfm`. This is source-checked documentation; no TCI client/server bench test was performed for this page.
