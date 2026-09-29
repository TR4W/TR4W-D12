# Post scores to HamScore

The HamScore integration sends live score information and can also send QSO contact data to the configured service. It is separate from exporting a Cabrillo entry and does not submit your contest entry to the sponsor.

1. Open **Ctrl+J** and find **Online scoring**.
2. Enable **Post my score while the contest runs**.
3. Set **Service URL**, **Username**, and **Password** for your service account. An empty username falls back to your configured callsign; an empty password prevents the uploader from starting.
4. Decide whether to **Include contact information**. QSO uploads require this setting and a contest marked RTC-capable by TR4W. Turning it off suppresses contact log/edit/delete uploads; score posts remain enabled.
5. Save the preferences and restart TR4W; this page's settings take effect at startup.
6. Open **Windows → HamScore RTC Status** and check the queue and last status. Confirm the result on your scoreboard account before relying on it during a contest.

Normally the worker posts every two minutes. **Push Now** requests an immediate cycle. Unconfirmed contacts remain queued for retry; explicit server confirmation clears them. A growing queue or repeated error needs attention: check credentials, service URL, connectivity, and whether the service accepts the contest. Both radios use the same uploader.

## Rebuild the remote log

Use **Tools → HamScore: Resync log from scratch** when the remote log needs to be rebuilt from the current local log. This queues a remote `<deletelog>` request and walks the current contacts for upload. Contact uploads still require the contact-information setting and an RTC-capable contest: do not request a remote-log rebuild in score-only mode. It changes the remote log; use it deliberately for the correct contest/account. It does not delete the local contest database.

!!! warning "Current status-window button limitation"
    The status window's **Resync from log** button currently calls a helper that queues only `<deletelog>` and tells the operator to use the Tools menu to enqueue all QSOs. Use the complete Tools-menu action for a rebuild, rather than relying on that button alone.

A server request for `ResyncLog` is reported for manual action rather than automatically rebuilding. Do not treat the in-memory upload queue as a backup of the local database. See [backups](../log/backup.md) and [diagnostic logging](../log/diagnostics.md) for recovery evidence.

??? info "Source check"
    `uHamScore.pas` worker, configuration and queue helpers; `uPrefsForm.lfm` Online scoring controls; `uHamScoreForm` button handlers; `MainUnit` Tools handler calling both `HamScoreResyncFromScratch` and `SendFullLogToHamScore`. No credentials were entered and no score data was posted while preparing this guide.
