"""Build the documentation reference from the checked-in inventory and sources.

No application code is executed. Fail on vocabulary drift; do not silently publish
an outdated inventory. Editorial explanations live separately from generated pages.
"""
from pathlib import Path
import configparser
import html
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'user-guide/reference/commands'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def strip_comments(text):
    # Preserve quoted Pascal strings, including doubled apostrophes.
    return re.sub(r"'(?:''|[^'])*'|\(\*.*?\*\)|\{.*?\}|//[^\n]*",
                  lambda m: m[0] if m[0].startswith("'") else ' ', text,
                  flags=re.S)


def slug(name):
    return re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')


def cell(value):
    return html.escape(str(value)).replace('|', '&#124;').replace('\n', ' ')


def write(name, text):
    (OUT / name).write_text(text.rstrip() + '\n', encoding='utf-8')


inventory = read('tr4w/docs/SETTINGS_INVENTORY.md')
rows = []
for line in inventory.splitlines():
    if not line.startswith('| `'):
        continue
    cells = [c.strip().strip('`') for c in re.split(r'(?<!\\)\|', line)[1:-1]]
    if len(cells) == 6 and cells[3].startswith('Settings.'):
        rows.append(dict(zip(('name', 'aliases', 'scope', 'path', 'type', 'notes'), cells)))
names = {r['name'] for r in rows}
aliases = {a.strip(): r['name'] for r in rows for a in r['aliases'].split(',') if a.strip()}
frozen = {m[1] or m[2] for m in re.finditer(
    r'''^\s*\+ '(?:"([^"]+)"|([A-Z0-9][^,']*))[,']''',
    read('tr4w/test/unit/uTestSettingsModel.pas'), re.M)}
if not rows or not frozen or names | set(aliases) != frozen:
    raise SystemExit('Inventory differs from frozen settings vocabulary; regenerate/review inventory first.')
if len(names) != len(rows) or len({slug(n) for n in names}) != len(names):
    raise SystemExit('Duplicate command or anchor in inventory')

model = strip_comments(read('tr4w/src/uSettingsModel.pas'))
cfg = strip_comments(read('tr4w/src/uCFG.pas'))


def array_names(name):
    match = re.search(r'\b' + name + r':\s*array\[0\.\.(\d+)\] of string = \((.*?)\);', cfg, re.S)
    if not match:
        raise ValueError('Missing command list: ' + name)
    values = re.findall(r"'([^']+)'", match[2])
    assert len(values) == int(match[1]) + 1, name
    return set(values)


retired = array_names('RETIRED_COMMANDS')
owned = array_names('OWNED_BY_A_STORE')
action_body = cfg.split('function TryApplyCommandAction(', 1)[1].split('function CheckCommand', 1)[0]
actions = set(re.findall(r"UnicodeSameText\(aCommand, '([^']+)'\)", action_body))
assert len(actions) == 4, 'Review action dispatch before regenerating'
assert not (names & retired or names & owned or retired & owned)

old_manual = read('docs/TR4W_Reference_Manual_4.01-1.md')
old_names = set(re.findall(r'^3\.2\.\d+\s*(.*?)\.{3,}\d+\s*$', old_manual, re.M))
assert len(old_names) >= 300, 'Old manual contents extraction failed'
help_ini = configparser.RawConfigParser(strict=False, interpolation=None)
help_ini.read_string(read('tr4w/target/commands_help_eng.ini'))
editorial = json.loads(read('tools/command_reference_notes.json'))
assert set(editorial) <= names, 'Editorial entry no longer resolves to a setting'
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()


def source(path, label=None):
    # Keep provenance readable offline without requiring repository access.
    return f'{label} (`{path}`)' if label else f'`{path}`'


def bounds(typ):
    if typ.lower() == 'boolean':
        return 'TRUE or FALSE'
    if typ == 'TSecretText':
        return 'Credential; use the settings UI'
    m = re.search(r'\b' + re.escape(typ) + r'\s*=\s*(-?\d+)\.\.(-?\d+)\s*;', model)
    if m:
        return f'{m[1]}–{m[2]} (numeric type bounds; see description for units)'
    return {'string': 'Text', 'integer': 'Integer', 'double': 'Number',
            'char': 'Single character', 'ansichar': 'Single character'}.get(typ.lower(),
                'See type ' + typ + '; allowed values need editorial review')


def initial_value(row):
    group, prop = row['path'].removeprefix('Settings.').split('.')
    root = model.split('TR4WSettings = class(TPersistent)', 1)[1].split('\n   end;', 1)[0]
    root_prop = re.search(r'property\s+' + re.escape(group) + r':\s*(\w+)\s+read', root)
    if not root_prop:
        raise ValueError('No group for ' + row['path'])
    cls = root_prop[1]
    body = re.search(r'\b' + cls + r'\s*=\s*class\(TSettingsGroup\)(.*?)\n\s*end;', model, re.S)
    if not body:
        raise ValueError('Missing class body: ' + cls)
    decl = re.search(r'property\s+' + re.escape(prop) + r':\s*(\w+)\s+read\s+(\w+)', body[1])
    if not decl or decl[1] != row['type']:
        raise ValueError('Inventory property/type drift: ' + row['path'])
    ctor = re.search(r'constructor\s+' + cls + r'\.Create;\s*begin(.*?)\nend;', model, re.S)
    if not ctor:
        return None
    # Only a direct literal assignment to the property's backing field. No
    # expression evaluation, zero-initialization guesses, or legacy defaults.
    assignments = re.findall(r'\b' + re.escape(decl[2]) + r'\s*:=\s*(.*?);', ctor[1], re.S)
    if len(assignments) != 1:
        return None
    value = assignments[0].strip()
    if re.fullmatch(r"True|False|-?\d+(?:\.\d+)?|'(?:''|[^'])*'", value, re.I):
        return value
    return None


buckets = [('a-d', 'A–D'), ('e-l', 'E–L'), ('m-p', 'M–P'), ('q-s', 'Q–S'), ('t-z', 'T–Z')]


def bucket(name):
    for key, _ in buckets:
        if key[0] <= name[0].lower() <= key[-1]:
            return key
    raise ValueError(name)


def link(name):
    canonical = aliases.get(name, name)
    return f'[{cell(name)}]({bucket(canonical)}.md#{slug(canonical)})'


OUT.mkdir(parents=True, exist_ok=True)
missing = []
counts = {'settings': len(rows), 'accepted_setting_names': len(frozen),
          'retired': len(retired), 'store_owned': len(owned), 'actions': len(actions),
          'old_manual_names': len(old_names), 'editorially_reviewed': len(editorial)}
defaults = 0
for key, title in buckets:
    lines = [f'# Commands {title}', '',
        'Current setting metadata comes from the 5.0.22 inventory and source snapshot. '
        'Inherited help is explicitly labeled and may describe older behavior. '
        '[Read the reference conventions](index.md) before editing settings.', '']
    for row in sorted(rows, key=lambda r: r['name']):
        name = row['name']
        if bucket(name) != key:
            continue
        initial = initial_value(row)
        defaults += initial is not None
        scope = 'Contest' if 'CONTEST' in row['scope'] else 'Station'
        lines += [f'## {name} {{#{slug(name)}}}', '',
                  '| Detail | Current metadata |', '| --- | --- |',
                  f'| Scope | {scope} |',
                  f'| Values | {cell(bounds(row["type"]))} |',
                  f'| Initial value in constructor | {cell(initial) if initial is not None else "Not extracted; see source"} |',
                  f'| Other accepted names | {cell(row["aliases"]) or "None listed"} |', '']
        if name in editorial:
            lines += [editorial[name]['description'], '']
            if editorial[name].get('guide'):
                lines += [f'[Step-by-step guide]({editorial[name]["guide"]})', '']
        else:
            description = help_ini.get(name, 'DESCRIPTION', fallback='').strip()
            if description:
                lines += ['!!! quote "Inherited English help — behavior needs review"',
                          '    ' + html.escape(description).replace('\n', '\n    '), '']
            else:
                missing.append(name)
                lines += ['!!! warning "Explanation not yet written"',
                          '    The setting is present in the inventory, but no usable English description '
                          'was found. Its name alone is not enough to infer its behavior.', '']
        old_default = help_ini.get(name, 'DEFAULT', fallback='').strip()
        lines += ['??? info "Evidence and historical context"',
                  f'    Model path: `{row["path"]}`. Source type: `{row["type"]}`.', '',
                  '    ' + source('tr4w/src/uSettingsModel.pas', 'Settings model') + ' · '
                  + source('tr4w/docs/SETTINGS_INVENTORY.md', 'Inventory') + ' · '
                  + source('tr4w/target/commands_help_eng.ini', 'Inherited help'), '',
                  '    ' + ('This exact name appears in the v4.01 manual contents.' if name in old_names
                            else 'This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.'), '']
        if old_default:
            lines += [f'    Historical help default: {cell(old_default)}. This is not a verified current default.', '']
    write(key + '.md', '\n'.join(lines))

index = ['# Command reference', '',
    '**Find a setting by its current name or an older name from the reference manual.**', '',
    'This reference combines the current settings inventory, source declarations, English help, '
    'and the v4.01 manual contents. It targets the same 5.0.22 snapshot as this guide.', '',
    f'There are **{len(rows)} settings** with **{len(frozen)} accepted names**, '
    f'plus **{len(actions)} action commands** documented separately. Radio, keyer, '
    'message, and compatibility command routes are not all ordinary settings.', '',
    '## Browse by name', '',
    *[f'- [Commands {label}]({key}.md)' for key, label in buckets],
    '- [Old-to-new lookup](legacy-map.md)', '- [Actions and moved configuration](lifecycle.md)',
    '- [Coverage and review gaps](coverage.md)', '',
    '## Read an entry', '',
    '- **Station** settings belong to the station settings model; **Contest** settings are captured with the contest. '
    'Do not carry forward the old manual’s INI/CFG storage column as a current editing recipe.',
    '- **Initial value** means a direct literal in the source constructor. Loading a station, a contest definition, '
    'or a saved database can change it. An unextracted value is not an empty or zero default.',
    '- **Values** gives boolean choices or literal numeric type bounds when available. '
    'Other validation can apply; numeric bounds do not establish units.',
    '- **Other accepted names** are inventory aliases. They do not imply that every input route applies the value.',
    '- **Inherited help** is useful background, not a reviewed 5.x procedure. Older hotkeys, file paths, '
    'default values, and platform assumptions require checking.', '',
    'Prefer the settings UI. Current command dispatch can recognize a name without applying it, '
    'depending on the caller and ownership. Recognition alone does not prove a legacy config line takes effect.', '',
    '## Topic starting points', '',
    '- [Log backup](../../log/backup.md)', '- [Radio connection](../../station/radio.md)',
    '- [WSJT-X](../../station/wsjtx.md)', '- [POTA](../../operating/pota.md)', '',
    '## All current setting names', '', '| Name | Scope |', '| --- | --- |']
for row in sorted(rows, key=lambda r: r['name']):
    index += [f'| {link(row["name"])} | {"Contest" if "CONTEST" in row["scope"] else "Station"} |']
write('index.md', '\n'.join(index))


def status(name):
    if name in names:
        return 'Current setting: ' + link(name)
    if name in aliases:
        return 'Accepted alias: ' + link(name)
    if name in retired:
        return 'Withdrawn name; accepted and ignored by compatibility dispatch'
    if name in owned:
        return 'Owned by a settings store; use the relevant setup panel'
    if name in actions:
        return '[Action command](lifecycle.md#actions)'
    if (name.startswith(('RADIO ONE ', 'RADIO TWO ', 'KEYER RADIO ONE ', 'KEYER RADIO TWO '))
            or name in ('POLL RADIO ONE', 'POLL RADIO TWO')):
        return 'Radio-library command family; exact suffix and application need review'
    return 'Not classified by this reference; review required (not proof of removal)'


legacy = ['# Old-to-new command lookup', '',
    'Names are extracted from the 335-command table of contents of the local v4.01 manual. '
    'Classification comes from the current inventory and dispatch lists, not from name similarity. '
    'Unclassified names can include message commands or other specialized parsers.', '',
    source('docs/TR4W_Reference_Manual_4.01-1.md', 'Original manual transcription') + ' · '
    + source('tr4w/src/uCFG.pas', 'Current dispatch'), '', '| Older name | Current classification |', '| --- | --- |']
legacy += [f'| {cell(n)} | {status(n)} |' for n in sorted(old_names)]
write('legacy-map.md', '\n'.join(legacy))

lifecycle = ['# Actions and moved configuration', '', '## Actions', '',
    'These commands do work rather than simply storing a preference. They are handled '
    'separately in `TryApplyCommandAction`; do not document them as persistent checkboxes.', '',
    '| Command | Current handler behavior |', '| --- | --- |',
    '| ADD DOMESTIC COUNTRY | Adds a country to the domestic list; CLEAR clears that list. |',
    '| CLEAR DUPE SHEET | Records the requesting config file as the clear-dupe instruction; its value is ignored. |',
    '| BAND MAP CUTOFF FREQUENCY | Parses an integer and adds a band-map mode cutoff. |',
    '| FREQUENCY MEMORY | Adds a band/mode frequency memory; the handler distinguishes SSB-prefixed values. |', '',
    '## Moved to a settings store', '',
    'These are not withdrawn features. The compatibility parser recognizes the old name, '
    'but configuration belongs to its owning store or setup panel. This list alone does not establish an import recipe.', '',
    *[f'- `{n}`' for n in sorted(owned)], '',
    '## Radio and keyer commands', '',
    'The dispatch recognizes the RADIO ONE / RADIO TWO and KEYER RADIO ONE / KEYER RADIO TWO '
    'families, plus POLL RADIO ONE and POLL RADIO TWO. A prefix match is not validation '
    'of every suffix. Use the [radio setup guide](../../station/radio.md) until the library fields '
    'have a dedicated reviewed reference.', '',
    '## Withdrawn names', '',
    'These exact names are in RETIRED_COMMANDS. Their acceptance avoids invalid-statement errors '
    'for older files; it does not apply their values. Do not infer the status of an entire hardware '
    'family from the retirement of one command name.', '',
    *[f'- `{n}`' for n in sorted(retired)], '',
    source('tr4w/src/uCFG.pas', 'Classification source')]
write('lifecycle.md', '\n'.join(lifecycle))

counts['literal_initial_values'] = defaults
counts['missing_descriptions'] = len(missing)
counts['unclassified_old_names'] = sum(status(n).startswith('Not classified') for n in old_names)
coverage = ['# Reference coverage and review', '',
    'Generated counts describe extraction coverage, not completed operator validation.', '',
    '| Measure | Count |', '| --- | --- |',
    *[f'| {k.replace("_", " ")} | {v} |' for k, v in counts.items()], '',
    '## Source precedence', '',
    '1. Current settings inventory, checked against the frozen command vocabulary, supplies names, aliases, scopes, and types.',
    '2. Current model declarations verify every inventory property/type and supply literal initial values and numeric subranges.',
    '3. Current uCFG dispatch lists distinguish withdrawn names, store-owned names, and actions.',
    '4. Reviewed editorial descriptions override inherited English help. Unreviewed help stays visibly labeled.',
    '5. The old manual supplies historical names and the migration lookup; its extracted PDF layout is too inconsistent '
    'to safely promote whole definition blocks automatically.', '',
    'The older CTRLJ_INVENTORY, CFG_COMMAND_TABLE, and HELP_TEXT_GAPS documents explain '
    'the migration but contain historical counts and architecture. They are not the current command list.', '',
    '## Missing explanations', '', *[f'- {link(n)}' for n in missing], '',
    '## Reproduce', '', 'Run `python tools/build_command_reference.py`, then '
    '`python -m mkdocs build --strict`. The generator reads only this worktree and refuses '
    'to publish when the inventory differs from the frozen settings vocabulary. It does not '
    'execute the application or prove end-to-end behavior.', '',
    f'Source revision: `{revision}`. Reviewed prose is maintained in '
    '`tools/command_reference_notes.json`; generated pages should not be edited directly.', '',
    'Historical manual credit: TR4W Reference Manual v4.01, Tod Olson, K0TO. '
    'Inherited English help retains its provenance in the project help catalogue.']
write('coverage.md', '\n'.join(coverage))
print(json.dumps(counts, indent=2))

# Registration metadata is explicit. Do not infer instance capabilities such
# as CW-by-CAT from filenames or inheritance; those need a runtime export.
radio_rows = []
native_pattern = re.compile(
    r"RegisterRadio(?:ById)?\(\s*('?\w+'?)\s*,\s*\w+\s*,\s*"
    r"(?:\w+\s*,\s*)?'([^']+)'\s*,\s*\[([^]]*)\]\s*,\s*(\d+)\s*,\s*(True|False)\s*,"
    r"\s*SerialParams\((\d+),\s*(\d+),\s*(\w+),\s*(\d+)\)", re.I)
ham_pattern = re.compile(
    r"RegisterHamLibOnlyRadio\(\s*(\w+)\s*,\s*\w+\s*,\s*'([^']+)'\s*,\s*(\d+)\s*,"
    r"\s*SerialParams\((\d+),\s*(\d+),\s*(\w+),\s*(\d+)\)", re.I)
for path in sorted((ROOT / 'tr4w/src/radioFactory').glob('*.pas')):
    text = strip_comments(path.read_text(encoding='utf-8-sig'))
    if not re.search(r'\binitialization\b', text, re.I):
        continue
    init = re.split(r'\binitialization\b', text, flags=re.I)[-1]
    matches = list(native_pattern.finditer(init))
    ham_matches = list(ham_pattern.finditer(init))
    expected = len(re.findall(r'\bRegister(?:Radio(?:ById)?|HamLibOnlyRadio)\s*\(', init))
    if expected != len(matches) + len(ham_matches):
        raise ValueError(f'Unparsed radio registration in {path.name}: {expected}')
    for m in matches:
        ident, label, links, port, discover, baud, bits, parity, stop = m.groups()
        radio_rows.append((label, ident.strip("'"), 'Native TR4W',
            'Yes' if 'rlSerial' in links else 'No',
            'Yes' if 'rlNetwork' in links else 'No',
            port if 'rlNetwork' in links and port != '0' else '—',
            'Yes' if discover.lower() == 'true' else 'No',
            f'{baud} / {bits} / {parity.removeprefix("PARITY_")} / {stop}' if 'rlSerial' in links else '—',
            path.relative_to(ROOT).as_posix()))
    for m in ham_matches:
        ident, label, ham_id, baud, bits, parity, stop = m.groups()
        radio_rows.append((label, ident, f'Hamlib only (ID {ham_id})',
            'Backend-dependent', 'Backend-dependent', '—', 'No',
            f'{baud} / {bits} / {parity.removeprefix("PARITY_")} / {stop}',
            path.relative_to(ROOT).as_posix()))
assert radio_rows and len({r[1] for r in radio_rows}) == len(radio_rows)
radio_doc = ['# Radio support and connection reference', '',
    f'**{len(radio_rows)} registrations** extracted from the radio factory in this source snapshot. '
    'This is a declared driver/transport inventory, not a report of successful hardware tests.', '',
    '## Read the table', '',
    '- **Native TR4W** means a direct TR4W driver registration. It does not mean an operating-system release is production-ready.',
    '- **Serial / Network** are the transports explicitly registered for that driver. Network support does not imply discovery support.',
    '- **Port** and serial parameters are setup defaults, not requirements that override the radio’s actual configuration.',
    '- **Hamlib only** means the connection goes through a Hamlib backend. The registry exposes both transports generically; '
    'the backend and radio decide what works. A Hamlib model ID on a native radio is not proof it requires Hamlib.', '',
    '## Important exceptions', '',
    '- **Expert TCI (HamLib bridge)** is a retained placeholder. Its source says the shipped Hamlib backend is absent; '
    'do not treat that entry as a working alternative. The distinct native **TCI (ExpertSDR / Thetis / AetherSDR)** '
    'entry is documented in the [TCI guide](../station/tci.md).',
    '- **HamLib (any supported rig)** uses a placeholder model ID; choose the actual rig’s Hamlib model ID during setup.',
    '- CW-by-CAT, spectrum, voice keying, and model-specific operating limits live in driver capability code. '
    'They are not inferred by this table.', '',
    '[Connect a radio](../station/radio.md)', '',
    '## Registered models', '',
    '| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |',
    '| --- | --- | --- | --- | --- | --- | --- |']
# Group by the explicit vendor in the registration display name. Unknown
# names remain visible under software/other, rather than guessing a vendor.
vendors = ['Icom', 'Elecraft', 'Kenwood', 'Yaesu', 'Flex', 'Ten-Tec']
def vendor_of(label):
    for vendor in vendors:
        if label.lower().startswith(vendor.lower()):
            return 'FlexRadio' if vendor == 'Flex' else vendor
    return 'Hamlib — generic' if label.startswith('HamLib (any') else 'Software interfaces and other models'
radio_doc = radio_doc[:-2]  # table header belongs inside each vendor section
vendor_order = ['Icom', 'Elecraft', 'Kenwood', 'Yaesu', 'FlexRadio', 'Ten-Tec',
                'Hamlib — generic', 'Software interfaces and other models']
for vendor in vendor_order:
    members = [r for r in sorted(radio_rows) if vendor_of(r[0]) == vendor]
    if not members:
        continue
    radio_doc += ['', f'### {vendor}', '',
        '| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |',
        '| --- | --- | --- | --- | --- | --- | --- |']
    for label, ident, driver, serial, network, port, discover, defaults_text, src in members:
        radio_doc += [f'| {cell(label)} | {cell(driver)} | {serial} | {network} | {port} | {discover} | {defaults_text} |']
radio_doc += ['', '## Reproduce and verify', '',
    '`python tools/build_command_reference.py` extracts initialization registrations and fails on '
    'unparsed registration calls or duplicate identifiers. It does not instantiate drivers, open '
    'ports, or check the linked application at runtime. Review model-specific source and bench '
    'status before claiming hardware validation.', '', f'Source snapshot: `{revision}`.']
(ROOT / 'user-guide/reference/radios.md').write_text('\n'.join(radio_doc) + '\n', encoding='utf-8')
print('Radio registrations:', len(radio_rows))

vc = strip_comments(read('tr4w/src/VC.pas'))
contest_match = re.search(r'ContestTypeSA\s*:\s*array\[ContestType\] of string\s*=\s*\((.*?)\);', vc, re.S)
if not contest_match:
    raise ValueError('Contest name table not found')
contest_names = re.findall(r"'((?:''|[^'])*)'", contest_match[1])
assert contest_names[0] == 'DUMMY CONTEST' and len(contest_names) > 100
contest_names = [n.replace("''", "'") for n in contest_names[1:]]
assert len(set(contest_names)) == len(contest_names)
contest_doc = ['# Available contests', '',
    f'**{len(contest_names)} choices** from the same `ContestTypeSA` table used by the new-contest picker. '
    'The internal DUMMY CONTEST entry is omitted, just as it is in that picker. '
    'This list includes general logging and operating activities as well as competitive events.', '',
    'Select the exact event/mode when [starting a contest](../start/first-contest.md). '
    'A selectable name means the program has a contest definition; it does not certify current '
    'sponsor rules, every exchange variation, or hardware/platform testing. Check the event rules '
    'and exercise an example exchange and export before operating.', '',
    'The newer contest factory is not the entire supported-contest list: definitions that remain '
    'in the existing contest engine still appear in the picker.', '']
for letter in sorted({n[0] for n in contest_names}):
    contest_doc += [f'## {letter}', ''] + [f'- {cell(n)}' for n in sorted(contest_names) if n[0] == letter] + ['']
contest_doc += ['## Evidence', '', source('tr4w/src/VC.pas', 'Contest name table') + ' · '
    + source('tr4w/src/ui/lcl/uNewContestForm.pas', 'Picker population'), '',
    'Regenerate with `python tools/build_command_reference.py`. Names are retained exactly as the picker supplies them.']
(ROOT / 'user-guide/reference/contests.md').write_text('\n'.join(contest_doc) + '\n', encoding='utf-8')
print('Contest choices:', len(contest_names))
