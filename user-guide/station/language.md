# Language and internationalization

Internationalization (I18N) is the machinery that lets one TR4W build present its interface in different languages. Translation supplies the actual wording. A language option does not by itself establish that every phrase has been reviewed.

See [Available languages and translation status](../reference/languages.md) for all language names, command-line testing codes, earlier translation credits, and measured review/empty counts. Italian, French, and the other newly seeded catalogues require review of their machine-generated drafts.

## Choose the interface language

Use **Language:** in Preferences and restart TR4W to load the chosen interface language. The startup selection order is:

1. An explicit `--lang`, `-l`, or `--lang=` command-line option.
2. The saved language setting, if this build has that catalogue.
3. The operating system's language.
4. Compiled-in English when no usable translation is loaded.

For example, `--lang=de` requests German for that launch. An unavailable saved language is skipped so the OS language can be considered. An unknown explicit switch is reported by the loader and can result in English rather than silently honoring a different saved preference.

## What changes and what stays stable

The UI catalogue translates resource strings and form properties: menus, captions, buttons, and messages. Configuration help has its own catalogue. Literal command names used by configuration parsing remain the documented command vocabulary; translate the explanation rather than changing a command such as `WSJT-X BROADCAST PORT`.

Keep callsigns, park references, protocol fields, and format placeholders intact. A localized display does not change the meaning of an ADIF field or a radio-control command.

## Embedded catalogues and overrides

The program carries language catalogues in its resources, so routine language selection does not require a separate translated executable. A `languages/<code>/tr4w.po` file under the application's [shipped-data root](../start/files.md#default-locations) takes precedence over the embedded catalogue. The loader resolves it through `DataFilePath`; “beside the executable” is only accurate for layouts where that is the data root. Use a test installation when trying an override, rather than modifying a signed application bundle.

An override can therefore explain why two installations of the same build show different wording. Include any override and the selected language when reporting a translation problem.

## Unreviewed translations in this preview

!!! note "Current testing policy differs from the older translator guide"
    The current resource build includes unreviewed/fuzzy entries for testing by default. It removes their fuzzy markers from the embedded copy so the runtime loader will display them; source `.po` files retain those review markers. The build option `Make-LanguageRes.ps1 -ReviewedOnly` excludes fuzzy entries.

Consequently, text appearing in this preview is not proof that a translator has approved it. Older documentation saying that unreviewed strings can never appear is out of date for this snapshot. Missing translations can leave English visible alongside translated text.

## Help improve a translation

Work on the appropriate `.po` catalogue: `tr4w_<code>.po` for the interface, or `help_<code>.po` for configuration help. Review contesting terms in their actual context—especially dupe, multiplier, exchange, run, S&P, and spot. Preserve formatting placeholders such as `%s`, `%d`, and `%.2f`, including their types and order; they are filled by the program. Preserve the role of `&` keyboard-access markers and test the resulting shortcuts and text layout. Review the text in the application before marking a translation reviewed. See the [language and review-status table](../reference/languages.md) for the catalogue names and command-line language codes.

For a useful report, include the TR4W version, OS, selected language, window/control, the displayed wording, and a proposed correction. A screenshot helps identify clipped text and ambiguous context. This MkDocs prototype is currently English; application localization does not automatically translate these pages.

## Supporting documents

- Translator guide (`docs/TRANSLATOR_GUIDE.md`): translator workflow; read its review-policy claims with the correction above.
- Translation tools (`docs/I18N_TOOLS.md`): catalogue maintenance. Its three-letter tool arguments differ from the UI loader's language tags.
- Language selection implementation (`tr4w/src/uUILanguage.pas`)
- Embedded catalogue loader (`tr4w/src/ui/lcl/uEmbeddedTranslations.pas`)

Language selection and translated layout still require a walkthrough on each target desktop. This page documents source behavior, not a completed translation audit.
