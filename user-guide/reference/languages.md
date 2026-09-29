# Available languages and translation status

The source snapshot contains **22 UI catalogues, including English**. A normal resource build embeds the catalogues; the language choices in your installed build are authoritative if it was packaged differently.

## Test a language

Use the table’s `--lang=` argument when launching TR4W. Examples:

=== "Windows"

    ```powershell
    .\tr4w.exe --lang=it
    ```

=== "Linux"

    ```sh
    ./tr4w --lang=fr
    ```

=== "macOS"

    ```sh
    open -a TR4W --args --lang=de
    ```

Close the running instance first so the argument is applied to a new launch. You can also save a choice in Preferences. Command-line language tags differ from three-letter translation-tool arguments such as ITA or FRA.

## How to interpret the counts

- **Unflagged text**: nonempty translation with no fuzzy flag. This includes inherited text and metadata; it is not a certificate of human review.
- **Needs review**: nonempty text marked fuzzy. It may be a machine draft or a copied translation requiring context review.
- **Empty**: no translation text, whether fuzzy or not. English fallback can remain visible.
- Counts exclude the catalogue header and obsolete entries. Totals can differ between languages because their catalogues were refreshed at different times.

Earlier translation means the catalogue credits an earlier language contributor; new UI strings can still be machine-generated or missing. Italian and French have no inherited human translation baseline in this expansion: their LibreTranslate drafts require review, even where a few entries are not marked fuzzy. Treat the other newly seeded languages the same way.

English is the compiled source/fallback language, so translation flags in its extraction catalogue do not measure the availability of the English interface.

## Language table

| Language | Test argument | Translation history | Unflagged text | Needs review | Empty | Help catalogue |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Chinese (Simplified) | `--lang=zh_cn` | New machine-seeded catalogue — review required | 1 | 1268 | 26 | Not in this snapshot |
| Czech | `--lang=cs` | Earlier translation — OK1RR | 491 | 784 | 24 | Present; separate review |
| Danish | `--lang=da` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Dutch | `--lang=nl` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Present; separate review |
| English | `--lang=en` | Source language | Source | — | — | Present; separate review |
| Finnish | `--lang=fi` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| French | `--lang=fr` | New LibreTranslate catalogue — review required | 2 | 1273 | 24 | Present; separate review |
| German | `--lang=de` | Earlier translation — DL4BBH | 424 | 851 | 24 | Present; separate review |
| Greek | `--lang=el` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Italian | `--lang=it` | New LibreTranslate catalogue — review required | 19 | 1256 | 24 | Present; separate review |
| Japanese | `--lang=ja` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Korean | `--lang=ko` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Mongolian | `--lang=mn` | Earlier translation — JT1CD | 484 | 57 | 758 | Not in this snapshot |
| Polish | `--lang=pl` | Earlier authored translation — SP2EWQ | 438 | 1485 | 24 | Present; separate review |
| Portuguese | `--lang=pt` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Portuguese (Brazil) | `--lang=pt_br` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Romanian | `--lang=ro` | Earlier translation — YO2IS | 451 | 824 | 24 | Present; separate review |
| Russian | `--lang=ru` | Earlier translation — UR7QM / R8TR | 484 | 790 | 25 | Present; separate review |
| Serbian | `--lang=sr` | Earlier translation — YT3W | 505 | 35 | 759 | Not in this snapshot |
| Spanish | `--lang=es` | Earlier translation — EB2CYQ | 537 | 739 | 23 | Present; separate review |
| Swedish | `--lang=sv` | New machine-seeded catalogue — review required | 1 | 1272 | 26 | Not in this snapshot |
| Ukrainian | `--lang=uk` | Earlier translation — UR7QM | 487 | 788 | 24 | Present; separate review |

## Review before calling a language complete

Review contest terminology and every machine draft, preserve formatting placeholders, then inspect real windows for clipping, keyboard markers, and meaning in context. The current test build includes fuzzy UI entries by default; [language loading and ReviewedOnly behavior](../station/language.md#unreviewed-translations-in-this-preview) explain why unreviewed text can be visible.

Presence of a help catalogue does not establish its completeness. Its review workload is separate from the UI counts above.

## Provenance and regeneration

Counts: `i18n/tr4w_*.po` at source revision `24f06a30081b607dbca5020fe583d97944be97d8`. Earlier contributor names come from the catalogues’ translation-author entries. New-language classification follows the project’s translation expansion and supplied editorial guidance; fuzzy flags alone cannot identify which tool wrote an individual phrase.

Run `python tools/build_language_reference.py` to refresh this table. This measures source catalogues, not the resources of an arbitrary downloaded binary.
