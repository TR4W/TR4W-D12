# Export ADIF and Cabrillo

Choose the format required by the receiving program or contest sponsor. Keep the contest database and a [backup](backup.md) even after exporting.

For the complete menu inventory, see [Reports and exported files](reports.md). To bring contacts into TR4W, see [Import contacts](import.md).

| Your task | Start with |
| --- | --- |
| Move contacts to another logging application or prepare POTA records | ADIF. |
| Prepare a contest submission that requires Cabrillo | Cabrillo, with the correct station and category information. |
| Inspect contact data in a spreadsheet | The CSV export option. |

## Export ADIF

1. Open the contest you want to export.
2. Choose **File → Export → ADIF**.
3. Review the generated file in the preview. The exporter uses the log's filename with an `.ADI` extension.
4. Check representative contacts for callsign, date/time, band, mode, reports, and exchange. For POTA, also check [your park and worked-park fields](../operating/pota.md#check-the-adif-before-upload).
5. Use that file with the receiving application and compare its import report with what you expected to transfer.

The exporter filters records through the program's QSO-validity check. Investigate unexpected omissions rather than assuming every database record must appear in an export. Preserve a separate copy of any export you want to retain before generating a new one at the same path.

## Export Cabrillo

1. Open the correct contest and choose **File → Export → Cabrillo**.
2. Complete and review the station-information window that opens. Check your station callsign, entry category, and contest-specific information.
3. Confirm the dialog to generate the file, then inspect its header and QSO lines.
4. Compare the file's exchange and category with the event's submission requirements before submitting it.

You can also open **Station information** from **Tools → Edit Cabrillo Summary...** to review the category and station headers before exporting.

![Cabrillo Station information dialog with entry category, operators, club, and contact fields](<../assets/v5.1.0/Update Cabrillo Fields.png>)

Generating a file does not submit it to the sponsor. Retain the submitted file and the sponsor's receipt when you complete that step.

## Current export details

ADIF, Cabrillo, and CSV files are written beside the contest database using its basename and the appropriate extension. Check the preview path before replacing an earlier export. Station facts saved with individual QSOs are used for their applicable exported station/location fields.

ADIF includes the worked station's `DXCC` when it writes `STATE`. In a contest where the other station sends a Maidenhead grid, `STATE` is written when that grid lies in exactly one state or province of the station's own country (the 50 states and DC, or a Canadian province; the grid list is the ARRL's VUCC list); a grid that straddles two or more of them, or a call from any other country, gets no `STATE`. JTTY and FT2 use `MODE=MFSK` with their respective `SUBMODE` under ADIF 3.1.8. Older TR4W JTTY records remain importable.

ADIF exports a set of linked county-line or rover rows as one contact. For two counties, check `USACA_COUNTIES` for the worked station and `MY_USACA_COUNTIES` for your own locations, as applicable. A longer county list uses TR4W extension fields. Check how the receiving application reads those fields. Vermont's separate `-ft.adi` is written when the log contains contacts assigned to that export.

Hawaii rover logs can produce a Cabrillo file per activation. In an unsplit rover export, the header `CALLSIGN` is your base call. Inspect the sent call and place on the individual QSO lines. Review `CATEGORY-STATION` or an overlay where the contest offers one.

## What to check before delivery

- The file belongs to the intended contest and station.
- Date/time, frequency or band, mode, and exchanges look right in early and late contacts.
- Category and station information match your intended entry.
- A multi-park contact has the expected separate park entries.
- The receiving application or sponsor accepts the format without unexplained omissions.

??? info "Source check"
    Menu structure: `uMenu.pas`. Dispatch: `MainUnit.pas` (`menu_adif` and `menu_cabrillo`). ADIF naming, filtering, and preview: `ExportToADIF` in `trdos/postunit.pas`. General ADIF fields: `uADIF.pas`. This draft has not exercised export dialogs or a sponsor's upload service.
