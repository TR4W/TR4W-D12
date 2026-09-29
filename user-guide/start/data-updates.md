# Update country, callsign, and park data

Update reference data before an event, then verify the affected lookup in a practice contest. A successful download and a successful reload are separate steps.

| Dataset | Used for | Update action |
| --- | --- | --- |
| `CTY.DAT` | Country/prefix lookup used by contest calculations | Country-file download action; **Alt+O** in the current accelerator table. |
| `TRMASTER.DTA` | Super Check Partial/callsign assistance | **Download TRMASTER.DTA**. |
| `pota_parks.csv` | Park-reference lookup and displayed park names | **Download POTA Parks**. |
| `.DOM` files | Contest-specific domestic multiplier definitions | Obtain the correct contest definition/data set; these are not the CTY or TRMASTER download. |

## Download and check

1. Finish any active operating task and retain a backup of the contest before changing data used for scoring.
2. Select the appropriate download action and wait for its completion or error report.
3. Check the destination if diagnosing a failure. Downloads use the [settings directory](files.md), or the directory of the explicit `--settings` file, rather than the application bundle.
4. Follow the program's reload/restart message. The TRMASTER download module explicitly does not reload the running SCP database; restart before expecting the new callsign data to be active.
5. Check a known call/prefix or park reference. For POTA, confirm that the expected park name appears.

CTY, TRMASTER, and park data solve different problems. Updating the callsign database does not update country boundaries or domestic multiplier definitions. A callsign suggestion is assistance, not evidence that it is the station you heard.

## If an update fails

Read the diagnostic message for network, TLS, or destination-write errors. Confirm that the active settings directory is writable and that the download was for the intended station profile. Do not overwrite files inside a read-only AppImage or signed application bundle to work around a failed download.

## Sources

Current actions and destinations: `MainUnit.pas`, `uMenu.pas`, `uAppPaths.pas`. Downloaders: `uCTYUpdate.pas`, `uTRMasterUpdate.pas`, and `uPOTAParks.pas`. The TRMASTER downloader names `https://tr4w.net/TRMASTER.DTA`; the POTA module names `https://pota.app/all_parks_ext.csv`. Endpoint availability was not tested for this documentation update.
