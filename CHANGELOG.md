# Changelog

All notable changes to CleanEX are documented in this file.

## [1.1] - 2026-10-29

### Added

- Spanish (ES) and French (FR) interface, alongside English and Italian, as in CleanRhizo and CleanSpeX. The header wraps on narrow screens so the language switcher stays visible.

### Fixed

- **CSV export**: text columns are now quoted, so treatment names containing commas or quotes (e.g. `Ctrl, low N`) no longer shift columns in the exported files. Numeric columns remain unquoted.
- **Merge error message**: when the previous CSV cannot be read, a clear error message is now shown (it was previously empty).
- **Language switch**: changing language no longer resets or desynchronises the interface. Column selection, treatment names, the long-format switch, the jitter switch and the chart parameter selection are all preserved, and what is shown always matches what is computed.
- **Input file**: the file picker now accepts both `.txt` and `.csv` Dualex exports; the loaded file name is shown next to the measurement count.
- **Parameters**: only numeric, non-descriptive columns are treated as parameters. Columns such as `qual_sat`, `etal` or GPS coordinates, if kept, stay as identifier columns in the long format and no longer appear in the chart.
- **Merge order**: merged data are now sorted chronologically by date and time (`dd/mm/yyyy` and ISO dates supported), as stated in the interface.
- **Merge values**: the previous CSV is read as text, so numeric values keep their original formatting (e.g. `28.0` no longer becomes `28`). A UTF-8 BOM (e.g. from Excel) is handled.
- **Stale merge result**: loading a new Dualex file now clears the previous merge and the treatment names.
- **Column counter** (step 2): the "x of y columns selected" text is now translated in both languages.

### Changed

- Distinct download names: `<name>_clean.csv` (step 3), `<name>_treatments.csv` (step 4), `<name>_final.csv` (step 5), `<name>_combined.csv` (step 7), `<name>_chart.png` (step 6).
- Version shown in the credits is defined once in the code (`APP_VERSION`).

## [1.0] - 2026-08-11

- First public release. Zenodo DOI: [10.5281/zenodo.21894246](https://doi.org/10.5281/zenodo.21894246).
