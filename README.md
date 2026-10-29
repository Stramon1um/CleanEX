# CleanEX 🧹

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21894245.svg)](https://doi.org/10.5281/zenodo.21894245)
[![Launch app](https://img.shields.io/badge/Launch-CleanEX-3A6B35)](https://www.mauromaver.eu/CleanEX/)

**▶ Use it online: <https://www.mauromaver.eu/CleanEX/>**

CleanEX is a free, browser-based application for cleaning, organizing, and exploring leaf optical data exported from the [Dualex](https://metos.global/en/dualex/) sensor (Metos Global). The tool is built with R and Shiny and deployed as a static web application via the shinylive and WebR frameworks, meaning it runs entirely within the user's browser without requiring any server-side infrastructure, software installation, or data upload to external services.

CleanEX addresses a recurring bottleneck in leaf optical phenotyping workflows: the raw Dualex export is a non-standard text file containing null bytes, embedded comment blocks, terse French column names, and measurement groups with no direct link to experimental treatment labels. Several preprocessing steps are needed before the data (chlorophyll, Chl; flavonoids, Flav; anthocyanins, Anth; nitrogen balance index, NBI) are suitable for downstream statistical analysis. The application automates these steps through a guided, step-by-step interface and produces tidy datasets in wide or long format, along with exploratory bar charts. A dedicated merge step combines data from several measurement sessions into a single file. CleanEX is available in English and Italian.

## Privacy

Your data never leave your computer. The file you load is processed locally by R compiled to WebAssembly (WebR); nothing is sent to a server. The first launch may take a few seconds while the R environment loads.

## Workflow

1. **Load** the file exported by the Dualex (`.txt` or `.csv`). Null bytes and `#Groupe` comment blocks are removed automatically.
2. **Select columns** to keep. GPS coordinates (`longitude`, `latitude`, `altitude`), `qual_sat` and `etal` are excluded by default and can be added back with one click.
3. **Clean**: the French column names are translated (`jj/mm/aaaa` → `date`, `hh:mm:ss` → `time`, `groupe` → `group`, `mesure` → `measure`). Download the cleaned file.
4. **Assign treatments** to measurement groups: one text field per Dualex group; if left blank, the group number is used.
5. **Export** a tidy CSV in wide or long format (`parameter`, `value`). Only the numeric parameters (Chl, Flav, Anth, NBI) are transposed; descriptive columns stay as identifiers.
6. **Explore** with bar charts (mean ± SE per treatment, optional individual points), downloadable as PNG at 300 dpi.
7. **Merge** (optional) the current file with a CSV previously exported by CleanEX in the same format. Rows are sorted chronologically by date and time.

## Biological vs technical replicates

In the exploratory chart, **every Dualex measurement counts as one observation**: mean and SE are computed across all measurements of the same treatment. If you take several readings on the same leaf or plant, those readings are technical replicates, and the SE shown in the chart underestimates the variability between biological replicates (plants or pots).

The exported CSV keeps the `group` and `measure` columns, so you can aggregate readings per plant before testing, or model the plant level explicitly (e.g. with a mixed model including plant as a random effect). The chart is meant for quick quality control and is not a substitute for proper statistical analysis.

## Input file

The file saved by the Dualex, either as `.txt` or `.csv`:

- semicolon-separated, possibly UTF-16 encoded (the null bytes are removed);
- four metadata lines, then the column header on line 5 (starting with `#`), then the data;
- a `#Groupe` comment block before each measurement group.

Expected columns: `jj/mm/aaaa`, `hh:mm:ss`, `longitude`, `latitude`, `altitude`, `temp`, `groupe`, `mesure`, `face`, `Chl`, `Flav`, `Anth`, `NBI`, `qual_sat`, `etal`. Values are kept exactly as in the original file (decimal point expected).

## Output

| File | Content |
|---|---|
| `<name>_clean.csv` | selected columns, cleaned and renamed |
| `<name>_treatments.csv` | plus the `treatment` column |
| `<name>_final.csv` | final dataset, wide or long format |
| `<name>_combined.csv` | current and previous file merged, sorted by date and time |
| `<name>_chart.png` | exploratory chart, 300 dpi |

CSV files use `,` as separator and `.` as decimal mark; text columns are quoted, so treatment names may contain commas.

## How to cite

If you use CleanEX in your research, please cite it:

> Maver, M. (2026). *CleanEX: a browser-based tool for Dualex leaf optical data cleaning and exploration*. Zenodo. <https://doi.org/10.5281/zenodo.21894245>

```bibtex
@software{maver_cleanex_2026,
  author    = {Maver, Mauro},
  title     = {CleanEX: a browser-based tool for Dualex leaf optical data cleaning and exploration},
  year      = {2026},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.21894245},
  url       = {https://doi.org/10.5281/zenodo.21894245}
}
```

The DOI above always resolves to the latest version. Version 1.0 has its own DOI: [10.5281/zenodo.21894246](https://doi.org/10.5281/zenodo.21894246).

## Run or build locally

The whole app lives in `CleanEX.qmd` (a single `shinylive-r` chunk). To rebuild the site you need [Quarto](https://quarto.org) and the R packages `shinylive`, `shiny` and `bslib`:

```bash
quarto render      # writes the static site to docs/
quarto preview     # local preview (WebR needs a web server, not file://)
```

The site in `docs/` is published with GitHub Pages.

## Related apps

CleanEX is part of a small family of browser-based tools for plant phenotyping data:

- [CleanRhizo](https://www.mauromaver.eu/CleanRhizo/) ([repository](https://github.com/Stramon1um/CleanRhizo)): WinRhizo root morphology data
- [CleanSpeX](https://www.mauromaver.eu/CleanSpeX/) ([repository](https://github.com/Stramon1um/CleanSpeX)): PlantEye F600 (Phenospex) multispectral 3D data

## Changes

See [CHANGELOG.md](CHANGELOG.md).

## Contact

Mauro Maver, University of Verona ([mauromaver.eu](https://www.mauromaver.eu), ORCID [0000-0002-8162-3618](https://orcid.org/0000-0002-8162-3618)).
Bug reports and suggestions: [GitHub issues](https://github.com/Stramon1um/CleanEX/issues) or [email](mailto:mauro.maver@univr.it).

## License

This project is licensed under the [MIT License](LICENSE).
