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

The entry and contest logic construct a contact record. The log-store layer sends it through the repository to SQLite and commits it. The append routine reports success only after its commit succeeds. Displays, scoring, and exports depend on the stored contest data, but each also has logic that needs testing in its own right.

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
