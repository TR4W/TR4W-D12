# How the parts work together

TR4W connects several sources of information to one contest: your entries, radio state, cluster spots, and messages from other applications. Each has a different role.

| Part | What it contributes | What it does not establish |
| --- | --- | --- |
| Radio connection | Frequency, mode, and supported control operations | That a contact was completed or saved |
| CW sending path | Delivers text or keying through the selected method | That the other operator received it |
| DX cluster and band map | Candidate stations and operating frequencies | That a spotted call or exchange is correct |
| Contest rules and multiplier state | Interpret exchanges and track worked multipliers | The sponsor's final adjudicated score |
| SQLite contest log | Stores contacts and contest-associated data | An independent backup on another device |
| Export and external loggers | Deliver contact data to another format or application | That a sponsor has accepted a submission |

## From a contact to a saved record

The entry and contest logic construct a contact record. The log store sends it through the repository to SQLite. A boundary or multi-park entry commits all of its rows together. Only after a successful commit does TR4W publish the contact to the multi-op link, external loggers, and UDP destinations. The record retains the applicable station facts and contest X-QSO decision for display and export.

On a multi-op network, the server keeps a separate SQLite log of the fields shared by protocol 5. Each client owns its contest database. On reconnect, contacts are compared by identity and the client adds missing rows in a transaction. See [multi-station networking](../station/network.md) for upgrade and catch-up behavior.

This division is useful when diagnosing a problem. A radio can follow frequency correctly while a keyer is misconfigured. A structurally sound database can contain a mistyped exchange. A correct export can still have the wrong submission category.

## From a cluster line to an operating decision

A cluster connection receives text; spot parsing extracts fields such as call and frequency. Spot and contest logic determine what to display and whether a station may be a new multiplier or a dupe. The band-map view filters and paints that data. Selecting a spot can tune a radio; it does not log a completed QSO.

## Explore the details

- [Database integrity and durability](database.md)
- [Test methodology](testing.md)
- [Band map](../operating/bandmap.md) and [DX cluster](../operating/dxcluster.md)
- [Multiplier windows](../operating/multipliers.md)
- [CW sending methods](../station/cw.md)
- [Internationalization](../station/language.md)

??? info "Evidence"
    This overview summarizes the source snapshot used throughout the guide: `uLogStore.pas`, `uLogRepository.pas`, `domain/uLogDatabase.pas`, `uDXClusterClient.pas`, `uTelnet.pas`, `uSpots.pas`, and the LCL display forms. The following pages link the supporting implementation and test documents.
