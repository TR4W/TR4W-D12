# Available languages and translation status

TR4W includes built-in English and **21 UI translation catalogues**. A normal resource build embeds the translation catalogues. Check the language choices in your installed build.

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

English is compiled into the program as the source and fallback language.

## Language table

| Language | Test argument | Translation history | Unflagged text | Needs review | Empty | Help catalogue |
| --- | --- | --- | ---: | ---: | ---: | --- |
| Chinese (Simplified) | `--lang=zh_cn` | New machine-seeded catalogue — review required | 3 | 1962 | 18 | Present, with separate review |
| Czech | `--lang=cs` | Earlier translation — OK1RR | 485 | 1486 | 18 | Present, with separate review |
| Danish | `--lang=da` | New machine-seeded catalogue — review required | 3 | 1967 | 18 | Present, with separate review |
| Dutch | `--lang=nl` | New machine-seeded catalogue — review required | 1 | 1320 | 668 | Present, with separate review |
| English | `--lang=en` | Source language | Source | — | — | Present, with separate review |
| Finnish | `--lang=fi` | New machine-seeded catalogue — review required | 2 | 1870 | 116 | Present, with separate review |
| French | `--lang=fr` | New LibreTranslate catalogue — review required | 3 | 1870 | 116 | Present, with separate review |
| German | `--lang=de` | Earlier translation — DL4BBH | 416 | 1457 | 116 | Present, with separate review |
| Greek | `--lang=el` | New machine-seeded catalogue — review required | 2 | 1870 | 116 | Present, with separate review |
| Italian | `--lang=it` | New LibreTranslate catalogue — review required | 18 | 1303 | 668 | Present, with separate review |
| Japanese | `--lang=ja` | New machine-seeded catalogue — review required | 1 | 1318 | 670 | Present, with separate review |
| Korean | `--lang=ko` | New machine-seeded catalogue — review required | 1 | 1312 | 676 | Present, with separate review |
| Mongolian | `--lang=mn` | Earlier translation — JT1CD | 475 | 59 | 1455 | Present, with separate review |
| Polish | `--lang=pl` | Earlier authored translation — SP2EWQ | 657 | 1535 | 655 | Present, with separate review |
| Portuguese | `--lang=pt` | New machine-seeded catalogue — review required | 1 | 1316 | 672 | Present, with separate review |
| Portuguese (Brazil) | `--lang=pt_br` | New machine-seeded catalogue — review required | 1 | 1318 | 669 | Present, with separate review |
| Romanian | `--lang=ro` | Earlier translation — YO2IS | 442 | 879 | 668 | Present, with separate review |
| Russian | `--lang=ru` | Earlier translation — UR7QM / R8TR | 473 | 848 | 668 | Present, with separate review |
| Serbian | `--lang=sr` | Earlier translation — YT3W | 496 | 38 | 1455 | Present, with separate review |
| Spanish | `--lang=es` | Earlier translation — EB2CYQ | 554 | 1419 | 16 | Present, with separate review |
| Swedish | `--lang=sv` | New machine-seeded catalogue — review required | 1 | 1321 | 666 | Present, with separate review |
| Ukrainian | `--lang=uk` | Earlier translation — UR7QM | 476 | 846 | 667 | Present, with separate review |

## Review before calling a language complete

Review contest terminology and every machine draft, preserve formatting placeholders, then inspect real windows for clipping, keyboard markers, and meaning in context. The current test build includes fuzzy UI entries by default; [language loading and ReviewedOnly behavior](../station/language.md#unreviewed-translations-in-this-preview) explain why unreviewed text can be visible.

Presence of a help catalogue does not establish its completeness. Its review workload is separate from the UI counts above.

## Provenance and regeneration

Counts: `i18n/tr4w_*.po` at source revision `4a0707be141d12c48327358c23deeddd2f0af0b7`. Earlier contributor names come from the catalogues’ translation-author entries. New-language classification follows the project’s translation expansion and supplied editorial guidance; fuzzy flags alone cannot identify which tool wrote an individual phrase.

Run `python tools/build_language_reference.py` to refresh this table. This measures source catalogues, not the resources of an arbitrary downloaded binary.
