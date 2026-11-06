# External logger definitions, factory and delivery

Implemented in worktree `codex/external-loggers-191`, based on `aedfe202afe1f873aa800df58f1a6ba76235e8c2`. Design approved by NY4I on November 4, 2026. Issue [191](https://github.com/TR4W/TR4W-D12/issues/191) is the Club Log pilot. All implemented providers handle new contacts, changes and deletes.

## Configuration and operator setup

Open Preferences > External Software > External Logger. **The grid is the editor** (issue 220; there is no separate list dialog). It lists configured loggers in active delivery order, then inactive definitions, with Order (the delivery position; a dash means the logger is not active, so Order and Send new QSOs are one fact), Logger, Provider and Send new QSOs. These are configured values, not a live connection-health indicator.

- **Add...** opens the one-definition editor with a provider choice; OK appends the definition (inactive until the operator ticks Active or switches Send new QSOs on).
- **Right-click a row** (or double-click it): Edit..., Send new QSOs (checked item; double-clicking that cell also toggles it), Move up, Move down, Remove. Switching Send new QSOs ON runs the same checks as the editor's OK (required fields, unique names, the shared-destination question) and is refused if they fail.
- **Drag the Order cell** to reorder (`goRowMoving`; the LCL starts a row drag only from a fixed column, which is why Order is the fixed column). Move up/down use the grid's own `MoveColRow`, so they take the drag's path. Either way the new order is written back: `Definitions` follow the grid, and `ActiveIds` becomes the active rows in grid order, which is the delivery order. A row dropped across the active/inactive line snaps back to its group.
- **Remove** asks for confirmation and drops the definition from both lists. It leaves the vault and any queued deliveries alone (below).

Save Preferences and restart to apply (applying live is issue 218). Multiple instances of a provider are allowed. Restart is explicit: the running services keep immutable snapshots so an in-flight operation cannot be redirected by an edit in the grid.

The grid edits the Preferences working copy directly, so Cancel (which reloads it) discards every grid edit; the outer Save or Save and close persists them. The per-definition editor uses a private copy; its Save to Preferences returns that one definition to the working copy, and its Cancel discards the dialog's edits without touching the vault. Preferences Save uses the existing single JSON writer. An empty active list deliberately disables delivery. Deactivation pauses durable delivery and stops acquiring new contacts, but subsequent edits/deletes to existing bindings are still captured for later delivery. Removing a definition explicitly leaves its queued rows in the contest log; they are not redirected to another definition. Keep a settings backup if the definition might need to be restored.

| Provider | Settings | Delivery behavior |
| --- | --- | --- |
| DXKeeper | Host/IP and TCP port (normally 52001) | Existing per-command TCP protocol and sender queue. Edit remains ordered delete/re-log. TCP handoff is not a remote acknowledgement. Existing queue remains in memory. |
| World Radio League | API key, account ID and logbook ID; existing WRL setup dialog | Durable intent committed with the local QSO, API create/update/delete and revision tracking. |
| Club Log | Personal API bearer token and destination callsign | JSON REST create; edit deletes the confirmed qsoid then creates the replacement; delete uses the confirmed qsoid. Accepted test-mode replies count as successful delivery. |

Passwords and API keys live in the existing platform keychain under definition IDs. JSON contains references, never newly written plaintext credentials. Names/order are not credential identity. An unreadable vault does not turn an empty field into an instruction to remove an existing reference. During migration, an unreadable legacy WRL key keeps a reference to its original vault name until the new reference can be stored.

Club Log uses a personal token created under Settings > API. Only the token and destination callsign are needed; no account email, password or developer application key is sent. The callsign must belong to the token's account. The earlier pilot selected the obsolete multipart API; this was corrected on November 5 after NY4I supplied the working REST request and the current issue comment.

## Factory and ownership

| Unit | Responsibility |
| --- | --- |
| `uExternalLoggerConfig` | Definitions, ordered active IDs, validation, JSON and destination identity. A malformed external section disables external delivery without preventing other libraries from loading; ordinary configuration saves preserve that section for repair. |
| `uExternalLoggerMigration` | One-time conversion of the old singleton settings into a named definition; the presence of the new section, including an empty one, prevents reimport. |
| `uExternalLoggerRegistry` | Stable provider IDs, constructor functions and the fields each provider uses. Duplicate registration is refused. |
| `uExternalLoggerFactory` | Public definition-based class factory and startup composition. Constructors receive explicit configuration; provider construction does not read global settings or perform network I/O. The old enum overload is a compatibility bridge. |
| `uExternalLoggers` | Owns services behind the existing process-wide `TExternalLoggerService` boundary. Orders active handoffs, contains per-provider preparation/enqueue errors and forwards database lifecycle hooks. Inactive durable definitions can update existing bindings. |
| `uQsoDispatcher` / `uQsoSinks` | Existing outward FIFO/worker. Messages now carry destination-addressed external commands instead of only one provider's command pair. |
| `uDurableExternalLogger` | Shared main-thread capture/savepoint, delivery lifecycle, watchdog and detached-owner rules for durable providers. |
| `uExternalDeliveryWorker` / `uExternalDeliveryClient` | Shared worker-owned database and transport contract. Short claim/settle transactions never span HTTP. |
| `uExternalDelivery` | Durable revisions, claims, settlement, recovery and scoped legacy-row adoption. |
| `uWRLExternalLogger` / `uWRLWorker` / `uWRLClient` | WRL payload adaptation, protocol and legacy ownership migration. |
| `uClubLogExternalLogger` / `uClubLogClient` | Club Log ADIF adaptation and real-time create/replace/delete protocol. |
| `uDefinitionId` | Shared ID minting for radios, keyers and loggers; GUID failure refuses creation rather than risking a timestamp collision. |
| `uKeychainJSON` | Existing radio/cluster vault serialization helpers lifted for reuse by logger definitions. |
| `uExternalLoggersForm` | Native designed LCL editor for ONE definition (Add and Edit), registered provider fields and per-definition durable status; also the shared acceptance checks (`ExternalLoggerConfigAcceptable`). |
| `uExternalLoggerGrid` | The Preferences grid as the editor: rows, popup, drag reorder, Send new QSOs, Remove. The order logic itself is in `TExternalLoggerConfig` (`DisplayOrder`, `ApplyOrder`, `SetActive`, `RemoveDefinition`), pinned in `uTestExternalLoggerGrid`. |

DXKeeper, WRL and Club Log register constructor functions from their implementation units. Adding Club Log required no provider branch in the QSO logging path or dispatcher. Future providers register their constructor and editor-field metadata through the same registry. ACLog and HRD placeholders are not registered as working providers.

## Queue and thread invariants

The main thread snapshots live QSO/contest/station state. Existing DXKeeper formatting still runs there because it reads live state. The dispatcher receives immutable command values with destination IDs and only enqueues them to sender workers. Durable providers additionally capture local intent inside the QSO transaction and wake their independent workers after commit. This small local database write is intentional: a committed QSO must not depend on an in-memory notification surviving a crash.

No DNS, TCP, HTTP, retry wait or worker join runs on the logging path. Disabled definitions do not create idle sender workers. A blocked HTTP request holds no database transaction and does not hold up another destination's worker. The existing UDP and HamScore paths remain separate dispatcher sinks.

Order means enqueue/start priority and per-contact revision ordering, not completion order across networks. TCP command queues are FIFO; durable outboxes coalesce contact revisions and schedule by retry deadlines. Waiting for destination one to finish before destination two would make an unavailable service block the rest.

Restart requirement verified in code: uProgramMain calls StartExternalLoggerFromSettings once at startup; the factory returns if the global already exists. Preferences saves only its store, and closing/reopening a contest calls LogClosed without reconstructing services. Thus saving or reopening a contest does not load changed definitions. This is a current implementation limitation, not an external API requirement. Hot application would need a safe dispatcher/worker handoff, not merely another factory call.

The manager is immutable during a session. Producers/dispatcher must be stopped before closing its services. Shutdown requests all workers to stop before waiting, with one shared one-second deadline. An unfinished service is detached and retained until process exit rather than freeing resources still used by its worker. Durable work remains on disk. The existing DXKeeper in-memory queue does not gain crash persistence in this change; undelivered commands retain its explicit diagnostics.

Each durable instance's namespace contains its stable ID plus a SHA-256 fingerprint of destination settings. Display-name/order and credentials do not participate. Changing a server/account/logbook parks the old namespace, so an old backlog cannot be sent to the new destination. Claims, recovery, capture bindings and gap markers are scoped by that namespace. No schema-version change is needed: the existing logger key already holds strings.

WRL's migrated definition adopts only legacy rows matching its original account and logbook, including confirmed rows and remote IDs. Other accounts/logbooks are not adopted. Adoption is per contest file and does not resend a confirmed contact. Legacy commands/settings are migration input; after the new section exists, the definition library is authoritative and the old singleton does not override it.

## Changes, deletes and uncertainty

A worker claims a revision, commits the claim, sends it, then settles that revision. A newer local revision remains pending after the older request completes. A delete before an unsent create is cancelled locally. An edit/delete arriving while a create is in flight is subsequently applied using the confirmed remote version.

Club Log stores the numeric qsoid returned by POST /api/v1/qso. Replacements first DELETE /api/v1/qso/{qsoid}, then POST the new ADIF with its destination call. Deletes carry no body or edited identity fields. A failed delete never proceeds to create; a 404 requires review rather than assuming the ID belonged to this account. An undelete after a confirmed deletion creates a fresh contact. If replacement creation fails after the delete, the operation pauses as uncertain: the old QSO has gone, so replaying the two-step replacement blindly is unsafe.

The outbox preserves both current and confirmed payloads. If a reply is lost, the outcome is uncertain; it is not silently marked successful. Club Log also treats interrupted replacement requests as uncertain on restart because a replacement contains a create and may already have installed a different remote identity. WRL retains its existing recovery policy for operations keyed by a remote ID.

Authentication errors stop the affected worker. Club Log pauses on other failed/unrecognised responses as well, avoiding automatic request storms. The editor shows pending/in-flight/synced/uncertain/failed durable counts. Fix credentials/configuration and restart for a paused worker; uncertain remote state requires reconciliation before replay. No bulk real-time backfill or whole-log deletion is introduced.

## Remaining External Logger issues

Investigated all five currently open issues bearing the label; none were closed at investigation time. This change implements the Club Log pilot and the shared foundation, not the other providers' protocols.

| Issue | Provider | Framework requirement identified |
| --- | --- | --- |
| [191](https://github.com/TR4W/TR4W-D12/issues/191) | Club Log | Bearer-token JSON REST, returned qsoid, durable real-time create/change/delete. Original [TR4W/TR4W#772](https://github.com/TR4W/TR4W/issues/772) supplied an obsolete queue example; the existing dispatcher/outbox are reused. |
| [203](https://github.com/TR4W/TR4W-D12/issues/203) | Log4OM | Configurable host/IP and UDP port. This repository asks only for TR4W-to-Log4OM, not inbound logging from the linked project's issue. |
| [204](https://github.com/TR4W/TR4W-D12/issues/204) | Cloudlog/Wavelog | Instance URL, API credential and remote station profile; several instances may be active. |
| [205](https://github.com/TR4W/TR4W-D12/issues/205) | MacLoggerDX | Verify the actual QSO-import mechanism. Emitting a compatible UDP announcement does not prove that MacLoggerDX will import it. A native macOS adapter remains an option. |
| [33](https://github.com/TR4W/TR4W-D12/issues/33) | ACLog | Configurable host/IP/TCP port; replace the incomplete placeholder with a provider implementing create/change/delete. |

Every future implemented logger must support changes and deletes with its actual protocol and original remote identity. An unsupported operation must fail visibly rather than reporting success.

## Protocol evidence and live acceptance

The current [real-time upload documentation](https://clublog.org/support/knowledgebase/rest-api/uploads-and-adif/how-to-upload-qsos-in-real-time/), [delete documentation](https://clublog.org/support/knowledgebase/rest-api/uploads-and-adif/how-to-delete-qsos-in-real-time/) and [REST contract summary](https://clublog.org/support/knowledgebase/rest-api/for-llms/club-log-api-information-for-llms/) supersede the old multipart examples. The interactive OpenAPI reference requires a logged-in browser session; the public articles explicitly document the implemented requests.

POST /api/v1/qso accepts JSON containing call plus one adif record. A real creation returns HTTP 201, status created and a numeric qsoid. HTTP 200 duplicate/updated is accepted only with a valid qsoid, so future changes/deletes never invent an identifier. Missing IDs and unrecognised or dropped responses require review. DELETE /api/v1/qso/{qsoid} returns HTTP 200 status deleted. All requests carry Authorization: Bearer and User-Agent: TR4W, with HTTPS and redirects disabled.

An accepted test-mode creation (HTTP 201, status created, test_mode true, qsoid null) counts as successful delivery and advances the outbox to synced, per NY4I's November 5 testing requirement. The local marker clublog:test-mode satisfies the outbox's nonempty delivery-identity invariant; it is never sent as a qsoid. Edits validate another upload; deletes settle locally because no remote QSO exists. A later edit with a normal token creates a real contact and replaces the marker with the returned numeric qsoid. Rejected/malformed replies remain failures even if they contain test_mode true. Use a designated test token while validating requests. HTTP 429 respects Retry-After; authentication, access, validation and unknown-ID errors stop the destination. Transport/5xx write outcomes require reconciliation rather than blind replay. Account quotas are shared with other clients; no whole-log backfill is added. Live persisted create/change/delete acceptance remains necessary with an explicitly designated logbook and normal token.

## Validation

After the REST correction, full application and unit-test builds pass, as do all 54 repository lints and the staged whitespace check. The latest worktree suite, including the accepted test-mode lifecycle, reports 423,944 checks passed and zero failures. Local capture/commit while HTTP was blocked measured 0 ms. Application warning gates remain at their existing ceilings (3 range warnings and 1,201 narrowing conversions). A curl smoke request using NY4I's supplied test token and the same call/adif JSON shape returned status created, qsoid null, test_mode true and nothing stored; no real QSO was created. Coverage includes definition/vault JSON round trips; active ordering and idempotent migration; class-factory construction of WRL and Club Log; per-destination preparation/enqueue containment; native form streaming; Club Log create/change/delete/undelete and failed-delete suppression; destination-isolated capture/claims/recovery; inactive binding updates; legacy row adoption; and simultaneous real worker threads with one HTTP operation deliberately blocked.

The blocked-worker fixture measures the local capture/commit while that HTTP operation is in flight and checks that the other destination drains. These are local fixture measurements, not a claim about every radio, platform or remote service. Existing WRL capture benchmarks remain in the suite.

## Handoff: observed startup delivery failure

On November 5, NY4I observed a startup warning before logging a new contact. Read-only inspection of the worktree test contest showed the existing W7EDT 15m CW delivery (2026-11-05 06:09:58 UTC), revision 2, with no remote ID. Startup resumes pending work; it does not manufacture a new QSO. The application log at 01:19:44 local recorded TLS unavailable before HTTP, followed by CLUBLOG_RESPONSE_REQUIRES_REVIEW with HTTP 0. TLS loading remains to be investigated, and the client should distinguish a proven pre-request setup failure from an ambiguous write outcome. No user delivery rows were cleared or rewritten. The existing uncertain row will not be automatically replayed by changing the test-mode success policy.

Resolution (NY4I rulings, November 5): `THttpRequest.TlsUnavailable` marks the proven pre-request failure (https asked for, `EnsureOpenSSL` false, no byte sent). Club Log and WRL classify it as `doRetry` with `CLUBLOG_TLS_UNAVAILABLE` / `WRL_TLS_UNAVAILABLE` and a 300 s delay, never uncertain; the diagnostic text is in tr4w.log, written once per distinct text. On Windows `EnsureOpenSSL` retries a failed load after 30 s. The HTTP layer now logs method, URL, exception class and message for every failed request, credentialed or not; the bearer token and form password are scrubbed out of all of it (`uHTTPDownload.MaskSecret` / `ScrubSecret`, raw and URL-encoded) and each request writes one TRACE line with the token masked (`ab...(36 chars)`). Pinned in `uTestHttpSecrets`. A missing or unreadable CA bundle (`ApplyTLSVerification` refusal, issue 221) is classified the same way: `THttpRequest.TrustBundleMissing`, `doRetry`, 300 s, `CLUBLOG_CA_BUNDLE_MISSING` / `WRL_CA_BUNDLE_MISSING`. `cacert.pem` is looked for in the data directory, then beside the program; the operator gets one notice per service per session (the worker's `Notice`, shown by the owner on the main thread). An OS trust-store fallback is not part of this.

Accepted test-mode responses now settle successfully with a local-only marker; rejected responses and transport failures do not. The rebuilt worktree executable is build-out/app-i386-win32/tr4w_external_loggers.exe, named separately to leave the running test application untouched.
