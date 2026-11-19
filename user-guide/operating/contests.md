# Contest additions and rule checks

Search the new-contest picker by part of the event's name. Read the event information and supply the operating area, category, and exchange requested for that contest. Existing logs can still open when an older event is hidden from the new-contest list.

## Additions since the 5.0.26 guide

Subsequent release notes include Georgia, Delaware, Nebraska, Idaho, North Dakota, Oklahoma, New Mexico, Ontario, and Quebec QSO parties; URC DX RTTY; and the combined IN7QPNE choice for stations outside the participating areas. Use the named event rather than a generic QSO party when available.

Rules were also updated for existing events, including Missouri, California, British Columbia, Florida, and Wisconsin QSO parties. Idaho uses the log's contest year for its applicable rules. Check the sponsor's current rules before the event; support in the picker alone does not certify every category or bonus.

Mobile/rover bonuses remain a documented limitation for affected QSO parties. Do not assume selecting a mobile category calculates every sponsor bonus. Verify the submitted score and any required manual claim.

## Entering the exchange

Type the exchange as it is sent on the air, words separated by spaces. When TR4W knows a typed code is not valid for the contest, for example a district, state or section the contest does not list, or a CQ zone above 40, it refuses the entry and says why on the status line. Correct the word and press Enter again. Not every contest's parser names its reason yet; with the standard QSL mode, a refusal without a message still means the entry was not logged.

With [QSL MODE](../reference/commands/q-s.md#qsl-mode) set to QSL AND LOG, a refused entry is still logged. A refused zone is not written to the contact, but the exchange text is stored with the contact as typed, so the zone can be corrected afterwards.

RSGB IOTA references may be typed with or without the dash: `EU-005`, `EU005` and `EU-5` are all logged as `EU-005`. Only a dash straight after the continent is accepted.

## Check before submission

Confirm the exchange, multiplier totals, eligible bands/modes, and category. An off-contest contact can remain in the log as an X-QSO worth zero points. Grid-based contests require the applicable grid information.

TR4W records station facts with each QSO, including applicable own-call, location, and zone information. Review these when operating from more than one location; changing today's station settings is not a substitute for correcting an earlier contact.

Export and inspect [Cabrillo or ADIF](../log/export.md), then follow the sponsor's submission instructions.

??? info "Review boundary"
    Based on RELEASE_NOTES.md and CHANGES.md through 48806af1, covering releases after 5.0.26. This summarizes documented support and limitations; it is not independent certification of sponsor rules or every contest score.
