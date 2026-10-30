# WRL integration review and proposed architecture

Status: implementation prepared for Claude's final review, tests and integration,
authorized by the operator on 2026-10-30. Handoff:
`C:\tr4w-d12\docs\WRL_INTEGRATION_HANDOFF.md`. Implementation remains uncommitted
in `codex/wrl-api-review`; do not merge the branch tip without committing the work.
The original review and operator comments remain below for context.

Baseline refreshed to local `main` at `d2e44ce3` on 2026-10-29 by fast-forward.
The six incoming commits leave the external logger classes/factory, QSO schema
and repository unchanged. Relevant integration updates: secret settings are now
excluded from contest-log capture and protected by `ValueForLog`; HamScore stops
before the diagnostic logger is freed. WRL must follow both existing contracts.
Uncommitted changes in the main checkout were not imported.

Implementation baseline subsequently fast-forwarded to local `main` at
`f7e840b1` on 2026-10-30 before source changes began.

## Current implementation (2026-10-30)

- `TExternalLoggerService` is the protocol-neutral contract. Startup uses the
  factory, whose WRL implementation has no TCP socket or DXKeeper command path.
- `TExternalDelivery` stores pending intent in the contest database, in the same
  transaction as a new QSO or a saved edit/delete. Schema 5 adds `external_delivery`
  and its indexes. Older TR4W builds refuse a schema-5 log, as for prior migrations.
- Each delivery binds the local row GUID to its original WRL account/logbook.
  `remote_id` holds the returned WRL contact UUID (`data.id`). The account ID is
  `/me`'s `uid`; `logbookId` is the destination shared by contacts in that logbook.
  Editing an already tracked contact preserves these bindings after setup changes.
  Work for a different account waits until that account's credentials are active.
- Payloads go through the same `EmitADIFContact` and contest tail as file export.
  `uWRLContact` translates supported ADIF fields into WRL JSON, including activity
  arrays. It contains no contest-type or park interpretation branches. The current
  file exporter emits per row; WRL follows that existing contact boundary rather
  than inventing an independent grouping policy.
- `TWRLWorker` owns its HTTP client and a separate SQLDB connection. Claims commit
  before HTTP, and results commit afterwards. SQLite busy/snapshot conflicts roll
  back and retry; no transaction spans a network request. The local connection has
  a bounded 250 ms busy timeout while WRL is active, so a short metadata write is
  not immediately treated as a broken local log. Measure actual overhead below.
- Saved edits increment the desired revision. Only one request per contact can be
  in flight. An older completion preserves a newer pending edit and the remote ID.
  An unsent creation followed by deletion is cancelled locally. Successful remote
  deletion clears the active remote ID so an undelete can create a new contact.
- Delivery states are `pending`, `inflight`, `synced`, `uncertain`, and `failed`.
  Interrupted or unanswered creations become uncertain and are not replayed.
  Authentication rejection leaves work pending and stops the worker; restarting
  with validated replacement credentials can resume it. Throttling honors
  `Retry-After`; writes are paced and server/network failures back off.
- WRL setup validates the key and lists all logbook pages on a worker thread.
  Operators can select or explicitly create a logbook. Keys use `TSecretText` and
  a masked edit with the existing reveal control. Setup takes effect on restart.
- A capture failure rolls back only its savepoint, pauses WRL, and attempts to
  record a durable gap marker. The repository reprepares cached SQLDB statements
  after this rollback: fault injection found that otherwise a later read could
  fail with SQLite's aborted-cursor error. Local commit remains the success test;
  a transaction SQLite has aborted must never be reported as saved.
- Worker notices use queued main-thread callbacks, removed after joining the
  worker on close. There is no idle notification-polling timer. A failure notice
  is shown once per service session; individual outcomes remain in the database
  and diagnostic log. Recovery of uncertain requests or capture gaps is not yet
  exposed as an automatic repair or resend tool.

The current API specification was fetched again on 2026-10-30 (still 1.1.0).
It declares `freq` as a number and `txPwr` as a string; it does not declare
`dxcc` as a writable contact field. Optional absent fields are omitted on create.
If an edit would clear a previously sent optional field whose clearing semantics
are undocumented, it is marked `FIELD_CLEAR_UNSUPPORTED` rather than silently
reporting a successful synchronization with stale data. Activity arrays can be
cleared using their documented empty-array form.

## Architecture at initial review

- `uExternalLoggerFactory` knows the logger vocabulary, but startup constructs
  `TExternalLogger` directly. `MainUnit.externalLogger` has that concrete type.
- `logsubs2.PostQsoEvent` builds immutable delivery messages on the main thread. (AGENT: Is this a queued mesage such that the man thread does not block beyond writing the queued record?)
  `uQsoDispatcher` routes them; `uQsoSinks` submits external commands to the
  logger's own sender. `TExternalLogger.PrepareOp` implements DXKeeper commands; (AGENT: TExternalLogger.PrepareOp calling something related to DXKeeper sounds like a base class calling something that is supposed to be in the factory method - Confirm the factory design).
  edits become delete followed by re-log.
- `uExternalLoggerBase` owns an in-memory command queue and bounded retries.
  It cannot preserve pending WRL work across process termination.
- `uLogStore` owns QSO commits through `uLogRepository`. The repository exposes
  the last inserted row GUID. `uLogSchema` distinguishes row `guid`, shared
  `exchange_id`, and contact grouping `qso_set_id`. They are not interchangeable.
- `uHTTPDownload` centralizes FPC HTTP/TLS transport. Its current POST abstraction
  needs extension for authenticated REST methods and response headers.
- `uSettingsModel.TSecretText` and `uKeychain` provide protected secret storage.

## Proposed implementation sequence

1. Define WRL's contact unit before coding. Only the original logging computer
   sends that contact to an external logger. Receiving a peer's contact, catch-up,
   or restock must not create upload work. Preserve that ownership for edits and
   deletes; do not infer ownership from the computer making the latest edit.
   Consume the existing contest/export interpretation of the contact. POTA park
   semantics belong to `TContestPOTA`, which already implements
   `EmitADIFExchangeFields` and `EmitADIFContestFields`; the external logger must
   not implement another park/grouping policy. Trace the complete export path
   before choosing the delivery identity. `qso_set_id` is a candidate storage
   identity, not a new operator-facing grouping decision. If shared export logic
   needs to serve live delivery, expose/reuse it at the existing owning layer.
2. Add destination-bound identity and pending work tables in each contest database.
   Save pending intent in the same transaction as the corresponding QSO change.
   Keep remote mappings and deletion intent after local removal. Capture account,
   logbook, contact identity, payload revision, and operation state; never secrets.
   Do not enqueue merely because a rescore or unrelated row rewrite occurred.
3. Extend the shared HTTP transport, preserving existing callers, to expose
   methods, bearer authentication, status/body, Retry-After and request ID. Disable
   redirects for credential-bearing WRL requests. Keep TLS validation centralized.
4. Give WRL one worker for network delivery. It must never use the main thread's
   SQLDB objects or read live contest/settings objects. Use explicit value snapshots
   and a defined database ownership protocol; complete that protocol before coding
   the worker. Network calls must hold no database transaction or UI lock. AAGENT: How do we ensure if the QSO is being edited in TR4W that we send the updated QSO when it is saved. We do not want these to overlap. I believe you mentioned it later so this is a confirmation).
5. Persist in-flight state before sending. A lost POST response or restart with an
   in-flight POST becomes delivery-uncertain, not an automatic repeat. Later work
   for that contact waits; unrelated contacts may proceed. PATCH/DELETE retries
   require explicit handling of repeat requests and remote absence. Do not promise
   exactly-once creation without server support.
6. Make factory creation and the common logger contract support WRL without
   inheriting TCP connection assumptions. Retain existing DXKeeper semantics and
   reuse its implementation. WRL durability must not depend on the volatile (AGENT: A volatile dispatcher sounds like a bad thing. A fix?)
   dispatcher accepting a message; a dispatcher notification may only wake work
   already persisted.
7. Add setup validation through `/v1/me`, explicit logbook selection, vault-backed
   API key storage, and visible pending/failed/uncertain status. Changing destination
   cannot retarget existing queued work. Invalid credentials pause delivery.

## Operator decisions and remaining boundaries

- Delivery tracking: operator accepted a separate delivery table associated with
  the local QSO/contact, rather than a single sent boolean on the QSO row. Track
  the destination, remote contact ID, delivery state, current payload revision and
  last confirmed revision. A completion for an older revision must not clear a
  newer pending edit. Preserve existing multi-op delivery flags and semantics.
- Multi-op: only the original logging computer uploads its contacts. External
  logging remains available during multi-computer operation. There is no automatic
  upload takeover by another station. During implementation, verify how peer edits
  and deletes reach the original station and whether its existing change path can
  record the required WRL update without uploading peer-owned contacts.
- Public API references do not document an idempotency key. Ask WRL whether it
  supports one or a unique client contact identifier. Matching call/time/frequency
  alone is insufficient proof of identity.
- WRL questions are below for the operator to submit to support.
- Initial scope: new contacts and subsequent edits/deletes. Historical backfill,
  bulk imports and remote-to-local synchronization require separate design.
- Initial release sends newly logged contacts and their subsequent edits/deletes.
  A future explicit resend tool is desirable. Reuse stored remote identities when
  resending; do not recreate contacts already known to WRL. Uncertain creations
  still require reconciliation. Do not automatically enqueue the existing log on
  enabling WRL.
- Local commits and remote delivery cannot be one transaction. If recording pending
  intent fails, do not claim the QSO was queued. Agree on whether that rolls back
  local logging or visibly disables synchronization; local logging should remain
  the priority, with a recoverable synchronization gap explicitly recorded.
- Failure policy: prioritize the local QSO commit. Use a transaction savepoint to
  isolate delivery-intent writes where SQLite leaves the transaction usable. If
  intent capture fails, roll back that portion and persist a synchronization-gap
  marker if possible, then commit the QSO. Pause WRL delivery and show a persistent
  actionable warning; do not claim synchronization succeeded. If SQLite aborts the
  whole transaction, report local save failure rather than claiming the QSO is
  safe. A durable gap marker is best effort under storage failure, never guaranteed.
  Recovery must reconcile saved contact identities and revisions before resuming,
  including grouped edits and deletes. Validate SQLDB/savepoint behavior and the
  repository's existing error handling before implementing this policy.
- Stored payloads must use recorded station facts, UTC and numeric MHz. Use shared
  ADIF mode mapping, with WRL's single mode field. Reuse grouped export logic where
  its semantics fit; do not create a second independent grouping implementation.
- Operator agreed to this field-mapping approach.
- Operator clarified that the contest class owns multiple-park interpretation.
  WRL adapts the resulting contact fields to its JSON contract; it does not ask
  the operator to approve a separate park/grouping rule.

## Questions for WRL support

We are integrating the TR4W desktop contest logger with your Developer API.

1. If WRL saves a new contact but our connection drops before we receive its ID,
   how can we safely retry without creating a second contact? Do you accept a
   unique request ID that we can reuse when retrying? If so, what field or header
   carries it, how long is it remembered, and what response does a retry receive?
2. Can we store our own permanent contact ID with a contact and look it up later?
   Can WRL enforce that this ID is unique within the account or logbook? This would
   let us recover the WRL contact ID after a lost response without guessing from
   callsign and time.
3. When the same contact is submitted twice, does WRL save two contacts and mark
   one as a duplicate, or return the existing contact? Which response fields tell
   us what happened? Does this behave differently for the API and ADIF imports?
4. If an edit or delete succeeds but its response is lost, is repeating exactly
   the same request safe? What response should we expect when deleting a contact
   that was already deleted? Can contacts deleted in the WRL app be distinguished
   from IDs that never existed?
5. If someone edits a contact in WRL while TR4W is also editing it, is there a
   way to reject an update based on an older version, so we do not silently
   overwrite their changes?
6. How should a client clear an optional contact field on PATCH, such as name,
   report, power or grid square? Their schemas accept strings rather than null;
   grid squares also have a format restriction. Is an empty string accepted to
   clear each field, or is there another documented way to do it?
7. The overview mentions preserving a supplied DXCC value, but the contact-create
   and contact-update request schemas do not list `dxcc` and reject unknown fields.
   Should integrations omit DXCC and leave it to WRL enrichment, or is that field
   accepted and missing from the request schema?

Questions 1 and 2 determine whether automatic recovery of uncertain creations is
possible. Until confirmed, uncertain POST requests remain paused for review.

## Validation

Test transactional intent capture and rollback; shared exchange IDs with distinct
rows; grouped contact edits and individual deletions; crash before/after POST;
lost POST response; restart recovery; edit/delete while creation is pending;
original-computer ownership across peer receipt, catch-up and restock; peer edits
of locally owned contacts; failure to record delivery intent while saving a QSO;
credential or destination changes; 429 scheduling; permanent validation failures;
bounded shutdown and worker lifetime; and credential redaction. Preserve existing
DXKeeper tests. Measure enqueue/commit latency with WRL enabled and disabled, and
verify a slow API cannot stall logging or other output destinations.

API inputs: repository `docs/World Radio League API.txt`, and downloaded public
`wrl-api-public.txt` / `wrl-openapi-public.json` (API version 1.1.0). No authenticated
requests were made during this review. Recheck the public contract before coding.
