# Update country, callsign, and park data

Update reference data before an event, then verify the affected lookup in a practice contest. A successful download and a successful reload are separate steps.

| Dataset | Used for | Update action |
| --- | --- | --- |
| `CTY.DAT` | Country/prefix lookup used by contest calculations | Country-file download action; **Alt+O** in the current accelerator table. |
| `TRMASTER.DTA` | Super Check Partial/callsign assistance | **Download TRMASTER.DTA**. |
| Contest call history | Known exchange information such as a Sweepstakes check and section | **Help → Download call history for this contest**, where available. |
| `pota_parks.csv` | Park-reference lookup and displayed park names | **Download POTA Parks**. |
| `.DOM` files | Contest-specific domestic multiplier definitions | Obtain the correct contest definition/data set; these are not the CTY or TRMASTER download. |

## Download and check

1. Finish any active operating task and retain a backup of the contest before changing data used for scoring.
2. Select the appropriate download action and wait for its completion or error report. **Help → Download TRMASTER.DTA** updates callsign data without installing a new TR4W version.
3. Check the destination if diagnosing a failure. Downloads use the [settings directory](files.md), or the directory of the explicit `--settings` file, rather than the application bundle.
4. In 5.1.0 a successful TRMASTER or call-history load takes effect in the running application. If the new file fails validation or loading, TR4W continues using the previous data. Follow the program's message for other data files.
5. Check a known call/prefix or park reference. For POTA, confirm that the expected park name appears.

CTY, TRMASTER, and park data solve different problems. Updating the callsign database does not update country boundaries or domestic multiplier definitions. A callsign suggestion is assistance, not evidence that it is the station you heard.

## If an update fails

Read the diagnostic message for network, TLS, or destination-write errors. Confirm that the active settings directory is writable and that the download was for the intended station profile. Do not overwrite files inside a read-only AppImage or signed application bundle to work around a failed download.

## Sources

Current actions and destinations are in `MainUnit.pas`, `uMenu.pas`, and `uAppPaths.pas`. The TRMASTER downloader in `uTRMasterUpdate.pas` uses the stable Pages address with a `tr4w.net` fallback in builds that support Pages. Earlier builds fetch from `tr4w.net`. You can also download the standalone file shipped with a version from its GitHub release assets, once available. [TR4W releases](https://github.com/TR4W/TR4W-D12/releases)
