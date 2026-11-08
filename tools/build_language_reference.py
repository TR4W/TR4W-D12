"""Summarize catalogue coverage without equating non-fuzzy text with human review."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/i18n'))
import pofile

LANGUAGES = {
    'en': ('English', 'Source language'),
    'cs': ('Czech', 'Earlier translation — OK1RR'),
    'de': ('German', 'Earlier translation — DL4BBH'),
    'es': ('Spanish', 'Earlier translation — EB2CYQ'),
    'mn': ('Mongolian', 'Earlier translation — JT1CD'),
    'pl': ('Polish', 'Earlier authored translation — SP2EWQ'),
    'ro': ('Romanian', 'Earlier translation — YO2IS'),
    'ru': ('Russian', 'Earlier translation — UR7QM / R8TR'),
    'sr': ('Serbian', 'Earlier translation — YT3W'),
    'uk': ('Ukrainian', 'Earlier translation — UR7QM'),
    'da': ('Danish', 'New machine-seeded catalogue — review required'),
    'el': ('Greek', 'New machine-seeded catalogue — review required'),
    'fi': ('Finnish', 'New machine-seeded catalogue — review required'),
    'fr': ('French', 'New LibreTranslate catalogue — review required'),
    'it': ('Italian', 'New LibreTranslate catalogue — review required'),
    'ja': ('Japanese', 'New machine-seeded catalogue — review required'),
    'ko': ('Korean', 'New machine-seeded catalogue — review required'),
    'nl': ('Dutch', 'New machine-seeded catalogue — review required'),
    'pt': ('Portuguese', 'New machine-seeded catalogue — review required'),
    'pt_BR': ('Portuguese (Brazil)', 'New machine-seeded catalogue — review required'),
    'sv': ('Swedish', 'New machine-seeded catalogue — review required'),
    'zh_CN': ('Chinese (Simplified)', 'New machine-seeded catalogue — review required'),
}
files = {p.stem.removeprefix('tr4w_'): p for p in (ROOT / 'i18n').glob('tr4w_*.po')}
assert set(files) == set(LANGUAGES), 'Review language names/provenance when catalogues change'
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
lines = ['# Available languages and translation status', '',
    f'The source snapshot contains **{len(files)} UI catalogues, including English**. '
    'A normal resource build embeds the catalogues; the language choices in your installed build '
    'are authoritative if it was packaged differently.', '',
    '## Test a language', '',
    'Use the table’s `--lang=` argument when launching TR4W. Examples:', '',
    '=== "Windows"', '', '    ```powershell', '    .\\tr4w.exe --lang=it', '    ```', '',
    '=== "Linux"', '', '    ```sh', '    ./tr4w --lang=fr', '    ```', '',
    '=== "macOS"', '', '    ```sh', '    open -a TR4W --args --lang=de', '    ```', '',
    'Close the running instance first so the argument is applied to a new launch. '
    'You can also save a choice in Preferences. Command-line language tags differ from '
    'three-letter translation-tool arguments such as ITA or FRA.', '',
    '## How to interpret the counts', '',
    '- **Unflagged text**: nonempty translation with no fuzzy flag. This includes inherited text '
    'and metadata; it is not a certificate of human review.',
    '- **Needs review**: nonempty text marked fuzzy. It may be a machine draft or a copied translation requiring context review.',
    '- **Empty**: no translation text, whether fuzzy or not. English fallback can remain visible.',
    '- Counts exclude the catalogue header and obsolete entries. Totals can differ between languages '
    'because their catalogues were refreshed at different times.', '',
    'Earlier translation means the catalogue credits an earlier language contributor; new UI strings '
    'can still be machine-generated or missing. Italian and French have no inherited human translation '
    'baseline in this expansion: their LibreTranslate drafts require review, even where a few '
    'entries are not marked fuzzy. Treat the other newly seeded languages the same way.', '',
    'English is the compiled source/fallback language, so translation flags in its extraction catalogue '
    'do not measure the availability of the English interface.', '',
    '## Language table', '',
    '| Language | Test argument | Translation history | Unflagged text | Needs review | Empty | Help catalogue |',
    '| --- | --- | --- | ---: | ---: | ---: | --- |']
for code, (label, history) in sorted(LANGUAGES.items(), key=lambda item: item[1][0]):
    entries = [e for e in pofile.read_po(str(files[code])) if e.source.strip() and not e.obsolete]
    unflagged = sum(bool(e.target.strip()) and not e.fuzzy for e in entries)
    fuzzy = sum(bool(e.target.strip()) and e.fuzzy for e in entries)
    empty = sum(not e.target.strip() for e in entries)
    assert unflagged + fuzzy + empty == len(entries)
    help_status = 'Present; separate review' if (ROOT / f'i18n/help_{code}.po').exists() else 'Not in this snapshot'
    values = ('Source', '—', '—') if code == 'en' else (str(unflagged), str(fuzzy), str(empty))
    lines += [f'| {label} | `--lang={code.lower()}` | {history} | {values[0]} | {values[1]} | {values[2]} | {help_status} |']
lines += ['', '## Review before calling a language complete', '',
    'Review contest terminology and every machine draft, preserve formatting placeholders, '
    'then inspect real windows for clipping, keyboard markers, and meaning in context. '
    'The current test build includes fuzzy UI entries by default; '
    '[language loading and ReviewedOnly behavior](../station/language.md#unreviewed-translations-in-this-preview) '
    'explain why unreviewed text can be visible.', '',
    'Presence of a help catalogue does not establish its completeness. Its review workload is '
    'separate from the UI counts above.', '', '## Provenance and regeneration', '',
    f'Counts: `i18n/tr4w_*.po` at source revision `{revision}`. Earlier contributor names come '
    'from the catalogues’ translation-author entries. New-language classification follows '
    'the project’s translation expansion and supplied editorial guidance; fuzzy flags alone '
    'cannot identify which tool wrote an individual phrase.', '',
    'Run `python tools/build_language_reference.py` to refresh this table. This measures source '
    'catalogues, not the resources of an arbitrary downloaded binary.']
(ROOT / 'user-guide/reference/languages.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('Language catalogues:', len(files))
