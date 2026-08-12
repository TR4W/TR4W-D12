# Read and implement this file

You are working in an existing Delphi 12 FireMonkey codebase and your task is to migrate the application from compile-time language constant units to a cross-platform `resourcestring`-based localization architecture.

The application is an FMX app and must run on Windows, macOS, and Linux. The localization design must be compatible with FMX and must not depend on VCL-only patterns or Windows-only resource DLL assumptions. FMX apps are commonly deployed as a single build per platform with runtime language selection rather than separate builds per language.[cite:5][cite:4]

Delphi strings in modern RAD Studio are Unicode-based (`UnicodeString`), which is important because the application must support languages including Russian and Chinese without ANSI conversions or code-page-dependent behavior.[cite:54][cite:56]

## Project context

The current application:

- Uses language-specific constant files.
- Uses conditional compilation to include one language file per build.
- Produces separate builds per language.
- Is moving toward a stronger FMX-first architecture.

The target application should:

- Use one application build per platform.
- Support multiple languages at runtime.
- Keep the default source language in Delphi `resourcestring` sections.[cite:47][cite:5]
- Load translations at runtime from translator-maintainable files.
- Work consistently on Windows, macOS, and Linux via FMX-friendly APIs and abstractions.
- Allow translation maintenance by native speakers using files that can be sent out and returned.
- Safely fall back to the default language when translations are missing.

## Primary objective

Implement a practical, incremental migration plan and code changes so the application moves from language constant files to `resourcestring` plus runtime translations.

The implementation must be maintainable in a mature codebase. Do not propose a greenfield rewrite. Old constants and new `resourcestring` entries may coexist during migration, but the final direction must clearly favor `resourcestring`.

## Required architecture

Design and implement the solution with these rules:

1. Replace language constant units with Delphi `resourcestring` declarations over time.[cite:47]
2. Keep one default source language in code, preferably English.
3. Use a runtime localization manager, for example `TLocalizationManager`, responsible for:
   - active language selection,
   - loading translation files,
   - stable key lookup,
   - fallback behavior,
   - optional reporting of missing translations.
4. Support one build per platform, not one build per language.[cite:5]
5. Make translations editable by native speakers outside the Delphi IDE.
6. Use Unicode-safe file formats and APIs throughout.[cite:54][cite:56]
7. Ensure the design works on Windows, macOS, and Linux.
8. Do not rely on VCL-only tooling.
9. Do not assume Windows resource DLLs are the main solution.
10. Favor maintainability, clarity, and incremental adoption over cleverness.

## Translation maintenance requirements

A non-developer translation workflow is required.

Design the workflow so that:

- Developers own the source text and keys.
- Translators receive a file in a format they can edit safely.
- Translators only change translation content, not key structure.
- Returned files can be validated and imported with minimal risk.
- The format preserves Russian and Chinese correctly with no encoding corruption.

Recommend the best workflow for both runtime use and human editing. A good answer may separate:

- a translator-facing exchange format such as UTF-8 CSV or XLSX, because it is easy to review in a grid,
- and a runtime format such as JSON, because it is easier for the app to consume safely.

If you recommend CSV, specify UTF-8 handling, delimiter rules, quoting, and import validation. If you recommend JSON, specify UTF-8, stable keys, and schema rules.

At minimum, the translation data model must support:

- `Key`
- `SourceText`
- `Context`
- `Notes`
- `en`
- `it`
- `ru`
- `zh`

If a better language-code convention is appropriate, use it consistently and explain it.

## Russian and Chinese requirements

Explicitly design for the following:

- Russian uses Cyrillic and often expands relative to English.
- Chinese can have very different line-breaking behavior and does not depend on spaces between words.
- UI controls must be reviewed for clipping, truncation, column width assumptions, dialog sizing, and layout overflow.
- Font fallback behavior may differ by platform.
- The implementation must avoid ANSI file APIs, manual code-page conversion, or locale-dependent parsing.[cite:54][cite:56]

Include recommendations for:

- UTF-8 file IO,
- font and glyph coverage testing,
- text measurement checks,
- runtime layout validation for longer and denser strings.

## Platform requirements

Account for resource locations by platform.

- On macOS, bundled read-only resources are commonly stored in `YourApp.app/Contents/Resources/`.[cite:29][cite:37]
- On Windows and Linux, propose sensible deployment and lookup locations for bundled translation files and optional user overrides.
- If editable user overrides are supported, do not write back into a signed macOS app bundle in place.[cite:27]

Design a lookup strategy that can handle:

- bundled read-only translation resources,
- optional writable user override files,
- fallback to default built-in source strings.

## Implementation tasks

Perform the following in the codebase where appropriate:

### 1. Analyze the current localization pattern

- Find the existing language constant units.
- Identify how conditional compilation selects language-specific files.
- Identify the main categories of localizable strings: UI captions, menu items, dialogs, messages, status text, formatted strings, and non-visual text.

### 2. Propose the new structure

Create or recommend units such as:

- `Localization.Keys.pas` if stable keys need to be centralized,
- `Localization.Manager.pas` for runtime loading and lookup,
- updated application/form units using `resourcestring`,
- optional import/export tooling or scripts.

Recommend whether stable lookup keys should be based on:

- resource string names,
- generated keys,
- or a DRC-derived mapping.

Explain the tradeoffs.

### 3. Convert code patterns

Refactor existing code patterns from language constants to `resourcestring`-based usage.

Show concrete examples of converting patterns such as:

```pascal
const
  TCQ = 'CQ';
```

to something based on:

```pascal
resourcestring
  SCallCQ = 'CQ';
```

Where runtime translation lookup is required, propose and implement a consistent pattern, for example:

```pascal
Label1.Text := L('SCallCQ', SCallCQ);
```

or another API you judge better.

Use a pattern that supports fallback to the source string and makes missing translations diagnosable.

### 4. Runtime language selection

Implement or propose:

- startup language resolution order,
- user override in settings,
- loading of the selected language,
- UI refresh behavior when language changes.

Preferred startup order:

1. Saved user override.
2. OS locale if supported.
3. Default source language.

State clearly whether language switching is immediate or requires restart, and justify the decision.

### 5. Translation files

Design the translator-maintainable file format and runtime import format.

Provide:

- sample file structure,
- naming convention,
- validation rules,
- missing-key handling,
- duplicate-key detection,
- round-trip safety rules.

### 6. Cross-platform file lookup

Implement or propose FMX-safe path resolution for:

- bundled translation files,
- writable user overrides,
- fallback behavior when files are missing.

Include platform-aware notes for Windows, macOS, and Linux.[cite:29][cite:37][cite:27]

### 7. Edge cases

Handle or document handling for:

- formatted strings with placeholders,
- plural-sensitive text,
- duplicate English source text that has different meanings in different contexts,
- untranslated keys,
- stale translator files after source changes,
- old constants still referenced during partial migration.

### 8. Validation and tooling

Provide or recommend:

- a report of missing translations by language,
- a validator for malformed translation files,
- an export/import helper for translator workflows,
- a development-mode option to highlight untranslated strings.

## Expected deliverables

Return your work in this structure:

## 1. Recommended architecture
Explain the final design in concrete Delphi/FM X terms.

## 2. Migration plan
Describe an incremental sequence that can be applied safely to a mature codebase.

## 3. Code changes
Show the actual units, classes, and method signatures you would add or modify.

## 4. Translation format
Define the translator-facing and runtime-facing file formats.

## 5. Translator workflow
Describe exactly how native speakers receive, edit, validate, and return translation files.

## 6. Unicode and script considerations
Explain Russian and Chinese handling, including encoding, fonts, line breaking, and UI sizing concerns.[cite:54][cite:56]

## 7. Cross-platform deployment
Explain where localization files live and how they are loaded on Windows, macOS, and Linux.[cite:29][cite:37]

## 8. Sample code
Provide Delphi 12 FMX code with realistic examples.

## 9. Validation checklist
Provide a checklist for testing the implementation.

## 10. Risks and tradeoffs
Document important design choices and migration risks.

## Additional instructions

- Assume this is a large, mature codebase.
- Favor incremental migration.
- Do not hand-wave.
- Show real Delphi 12 FMX patterns.
- Prefer readable and maintainable code.
- Avoid introducing unnecessary abstractions.
- Where you make an assumption, state it clearly.
- If you need to choose between a technically elegant approach and one that translators can actually maintain, prefer the translator-maintainable approach.
- If practical, include a simple helper script or internal tool concept for import/export.
- If practical, recommend how a grid-based review or edit flow can be supported for translators.

## Definition of done

The task is complete only when:

- the application no longer depends on separate builds per language for the migrated areas,
- localized strings can be selected at runtime,
- the translation workflow is safe for native speakers,
- Russian and Chinese are handled as first-class languages,
- the solution is portable across Windows, macOS, and Linux in FMX,
- and the migration path is realistic for an existing codebase.
