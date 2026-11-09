# Send contacts to external loggers

TR4W can send contacts to several named external loggers. Each destination has its own queue and delivery state. Network work runs away from the main logging window; saving a contact does not mean the receiving logger has accepted it yet.

## Configure destinations

1. Open **Ctrl+J → External Software → External Logger**.
2. Choose **Add...**, give the destination a useful name, and select its provider. Enter that provider's connection details.
3. Select **Enabled** for destinations that should send new QSOs. Drag an **Order** cell to change their order. Double-click a row, or right-click and choose **Edit...**, to edit it.
4. Save Preferences. **Enabled** and **Order** changes apply immediately on Save. A new destination or changed connection details require a restart; check for **Restart TR4W to apply** in the row.
5. In a practice log, send one contact and check it in every enabled receiving logger. Compare the call, UTC time, band, mode, and exchange.

Order controls dispatch order, not the order in which independent remote services finish. Changing a destination's name does not redirect its existing backlog to another account.

## Provider details and limits

| Provider | Connection details | Changes and deletes |
| --- | --- | --- |
| DXKeeper | Receiving TCP host/IP and port | Supported; replacement can involve deleting and re-sending the QSO. Check the receiving log after an interrupted replacement. |
| World Radio League | API key; choose the logbook from the retrieved list | Supported, with persistent delivery/retry state. Create logbooks in WRL before selecting one here. |
| Club Log | Club Log callsign and API token | Supported through the bearer-token QSO API. An edit deletes the old remote QSO then creates its replacement; a failure between these steps requires review. No Club Log email/password is needed. |
| Cloudlog / Wavelog — **Unreleased source** | Server URL, API key, station profile ID | New QSOs only. Editing or deleting a previously sent QSO produces a failed delivery row; correct the remote log manually. |
| ACLog — **Unreleased source** | Host/IP and port; defaults 127.0.0.1:1100. Enable **TCP API Enabled** in ACLog. | New QSOs only. Changes/deletes of sent QSOs fail explicitly; correct the remote log manually. Live ACLog verification remains outstanding. Direct logging does not perform ACLog contest scoring. |

The first three providers are covered by the 5.0.37 release notes. Additional providers describe source through **48806af1**; check your installed build before expecting them in its list. The ACLog radio-control bridge is a separate feature.

For **Log4OM**, use TR4W's standard **UDP** contact-broadcast settings rather than adding an external-logger provider. New-QSO forwarding is documented in the change history; edit forwarding still needs verification.

## Check delivery and credentials

Review pending, retrying, uncertain, and failed counts. **Enabled** means a destination is selected for sending, not that all its contacts have arrived. A persistent queue can resume earlier work after startup, before you log a new QSO. Investigate an uncertain result in the receiving log before retrying it, to avoid duplicates.

Not every remote API supports the same operations. A successful create does not establish that a later edit or delete succeeded. Keep the TR4W log and inspect the receiving log when a delivery fails.

API keys and passwords use the operating system's credential store. Copying the settings file to another computer does not copy those secrets; re-enter credentials there. Resolve a locked or unavailable credential store rather than expecting a plaintext fallback.

??? info "Source and review boundary"
    Reviewed November 8, 2026 against release notes and the provider units, registry, queue service, and external-logger grid at 48806af1. This documentation update did not send contacts to live services.
