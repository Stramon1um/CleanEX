# Changelog

All notable changes to CleanEX are documented in this file.

## [1.2] - 2026-11-20

### Added

- `tests/data/example_dualex.csv`: a small synthetic Dualex file (with `#Groupe` blocks and `NaN` readings) to try the app.
- `tests/run_tests.R`: regression tests that run the real app code (parsing, NaN handling, long/wide export, CSV round-trip, dates, merge, chart, Shiny server logic in the four languages). Run with `Rscript tests/run_tests.R`.

### Fixed

- **`NaN` values**: a single `NaN`/`nan` (or empty) value in Chl, Flav, Anth or NBI no longer excludes the whole column from the parameters. Previously the long-format export kept only the remaining parameters (e.g. only Chl), the chart offered only those, and the affected columns were written as quoted text in the CSV. Missing values are ignored in means and standard errors.
- **Chart from long format**: the chart now reads the long table directly instead of rebuilding a wide table, which collapsed rows when the identifier columns (date, time, measure…) had been deselected and gave wrong means.
- **Chart axis**: negative values and all-zero parameters are drawn correctly; no more zero-length-arrow warnings; the PNG device is always closed, even if drawing fails.
- **Treatment order** in the chart is now natural (3, 4, 10, 11 instead of 10, 11, 3, 4).
- **Step 2**: "Deselect all" followed by Clean now shows an error instead of silently using the default columns.
- **Missing group column**: if `groupe` is deselected, a warning explains why treatments cannot be assigned.
- **Rename chips** in the summary list only the columns that were kept.
- **Empty group value** no longer yields `treatment = NA`.
- **Input file**: measurement rows are recognised by their date, so the `#Groupe` summary block can never leak into the data whatever its length or language; UTF-8/UTF-16 BOMs and Latin-1 bytes are handled; files that are not Dualex exports, too short or without measurements give a clear (translated) error message.
- **Decimal comma**: a warning is shown when values use a decimal comma (CleanEX expects a decimal point).
- **Merge**: a warning is shown when rows of the current file are already present in the previous file (e.g. the same file loaded twice).
- **Dates**: two-digit years (e.g. a CSV re-saved by Excel) are read correctly, and rows with an unreadable date go last instead of disabling the chronological sort.

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
