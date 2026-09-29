# Operate POTA and park-to-park

Select **POTA** when [starting your contest](../start/first-contest.md). Use a practice log first to check park entry and exported fields.

## Set your own park

Open settings with **Ctrl+J** and find **MY PARK**. Set it to the full reference of the park you are activating, for example `US-0663`. This identifies your park in the ADIF export and supplies the country prefix when you enter a digits-only worked-park reference.

Use **Download POTA Parks** in the Tools menu to update the park-name database before operating. The current code resolves the data location for the platform; the older wiki instruction that the download always lives beside the executable should not be assumed for this build.

## Enter a worked park

Enter the other station's callsign in the call field. In the exchange field, enter the signal report and the park reference, for example:

```text
59 US-1274
```

Use the actual received report and park. The following examples illustrate the normalization rules:

| What you type | Interpretation |
| --- | --- |
| `US-1274` | Full reference. |
| `US1274` | Normalized to `US-1274`. |
| `1274` | Uses the country prefix from MY PARK; with `US-0663`, becomes `US-1274`. |
| `59` | A report, not a park reference. |

Use a full reference when the worked park has a different country prefix from yours. If the local parks database contains the reference, check the displayed park name before logging.

## Work a station at multiple parks

Put each worked park in the same exchange, separated by spaces:

```text
57 US-0663 US-1234
```

When the contact is logged, the first park is recorded normally and the pending-park handling records the additional park contacts. Check that the resulting entries have the same worked call, band, mode, and report, with a different park reference in each entry. The number of log entries can therefore exceed the number of on-air contacts.

These are example references, not a claim about which parks can be activated together.

## Repeat the exchange for another callsign

After logging the park exchange, use **Ctrl+T** or **Repeat POTA Parks (2nd Op)** to recall its park information. Check the exchange, enter the next worked callsign, and log the contact.

This command saves typing; it does not switch your own station identity or your own park. Explicitly check the callsign field before logging. If there is no saved POTA exchange in the session, the command reports that no parks have been logged yet.

## Check the ADIF before upload

[Export ADIF](../log/export.md), then inspect a single-park and a multi-park contact:

| Field | What to verify |
| --- | --- |
| `MY_SIG_INFO`, `MY_POTA_REF` | Your activating park from MY PARK. |
| `SIG_INFO`, `POTA_REF` | The worked park when a recognized park reference is present. |
| `SRX_STRING` | The individual worked-park reference for each park entry. |

Confirm MY PARK before exporting: the export code takes your park from the current setting. This preview does not establish how a log containing several different activating locations should be managed.

??? info "Evidence and review status"
    Adapted from the wiki's `POTA-Operation.md`. Current checks: `uPOTAParks.pas`; `ProcessRSTAndPOTAPark` in `trdos/logstuff.pas`; pending-park handling and `HandleRepeatPOTAParks` in `MainUnit.pas`; ADIF tail fields in `trdos/postunit.pas`; MY PARK binding in `ui/lcl/uPrefsForm.pas`. A field activation, multi-park sequence, and exported file still need an operator walkthrough.
