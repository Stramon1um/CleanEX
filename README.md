# CleanEX

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

CleanEX is a free, browser-based application for cleaning, organizing, and exploring leaf optical data exported from the Dualex sensor (Metos Global). The tool is built with R and Shiny and deployed as a static web application via the shinylive and WebR frameworks, meaning it runs entirely within the user's browser without requiring any server-side infrastructure, software installation, or data transmission to external services. CleanEX addresses a recurring bottleneck in leaf optical phenotyping workflows: the raw Dualex export is a non-standard .txt file containing null bytes, embedded comment blocks, terse column names, and measurement groups with no direct link to experimental treatment labels. Multiple preprocessing steps are required before the data — chlorophyll (Chl), flavonoids (Flav), anthocyanins (Anth), and nitrogen balance index (NBI) — are suitable for downstream statistical analysis. The application automates these steps through a guided, step-by-step interface and produces tidy datasets in wide or long format, along with exploratory bar charts. A dedicated merge step allows data from multiple measurement sessions to be combined into a single file. CleanEX is available in English and Italian.

## License

This project is licensed under the [MIT License](LICENSE).