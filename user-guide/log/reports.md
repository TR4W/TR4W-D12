# Reports and exported files

Use exports to transfer or submit contacts, and reports to inspect the contest. Producing a file is not the same as submitting it.

## Exports

| File → Export choice | Use |
| --- | --- |
| ADIF | Transfer contact records to another logger or activity service. |
| Cabrillo | Prepare a contest submission where the sponsor requires Cabrillo. |
| CSV | Inspect exported data with a spreadsheet or other tabular tool. |
| EDI | Export for events/services that require EDI; check the event's requirements. |
| Initial exchanges list | Produce exchange-reference output for later use. |
| Notes | Export recorded notes. |

The [ADIF and Cabrillo procedure](export.md) explains how to generate and inspect those files. ADIF export uses the log's name with `.ADI`; Cabrillo output is identified in the corpus documentation as `<CALL>.LOG`. Inspect the preview and destination rather than assuming every `.LOG` file is a contest submission.

## File → Reports

The current menu provides:

- **All callsigns**
- **Band changes**
- **Continent List**
- **First callsign worked in each country**
- **First callsign worked in each zone**
- **QSOs by country by band**
- **Score by hour**
- **Summary**
- **3830 Score**

Choose a report that answers your operating question: inspect band changes for timing, score by hour for rate, or country-by-band totals for band coverage. The applicable interpretation still depends on the contest.

## Review before using a report

Confirm the contest and station identity, the relevant band/mode/category, and a few known contacts. After correcting contact data, regenerate the output so you are not reading a stale file. Investigate discrepancies against the stored contacts and contest rules.

A report or claimed score reflects TR4W's interpretation of the log. It does not replace the sponsor's rule checking or adjudication. Retain the actual submitted file and receipt separately.

??? info "Evidence and review status"
    Available names and menu grouping: `uMenu.pas` and `uTR4WStrings.pas`. ADIF export: `trdos/postunit.pas`. Cabrillo corpus contract: `tr4w/test/corpus/README.md`. This page inventories the current menu; each report's contents and format have not been individually validated in this documentation pass.
