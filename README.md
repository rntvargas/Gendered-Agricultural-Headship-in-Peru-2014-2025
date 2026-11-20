# ENA 2014-2025 manuscript and replication package

Project repository: https://github.com/rntvargas/Gendered-Agricultural-Headship-in-Peru-2014-2025
Archived replication snapshot: https://doi.org/10.5281/zenodo.24395430
License: CC BY 4.0 (see LICENSE.md).

This manuscript analyses the recorded sex of agricultural producers in eleven ENA rounds: 2014-2019 and 2021-2025. There was no 2020 round. A separate 2025 analysis uses extension, credit, area, and producer modules to study service access. The two components have different estimands and variance designs.

## Contents

- manuscript.tex and manuscript.pdf: journal manuscript with five figures and 33 cited references.
- scripts_historical/: extraction, R analysis, setup, and manifest-writing launchers for the 2014-2025 series.
- supplementary_analysis.R: additional confidence intervals, standardized estimates, and 2025 holdout calibration for the historical model.
- build_2025_access.py, analyse_2025_access.R, and make_2025_figures.R: one-to-one linkage and service-access analysis for 2025.
- results_historical/ and results_2025/: aggregate tables and software information. The supplementary_*.csv files are also aggregate.
- source_hashes.csv and source_manifest.csv: SHA-256 checks for the historical input, 2025 Chapter 1100, and the other three 2025 SPSS modules.

No person-level microdata or private intermediate CSV is included.

## Reproduce

Obtain the official ENA 2025 SPSS modules from https://proyectos.inei.gob.pe/microdatos/ and place them in a local directory containing 19_CAP1100.sav, 15_CAP700.sav, 17_CAP900.sav, and 01_CAP100A_01.sav. The historical analysis additionally needs the project-supplied consolidated ENA_2014_2024.sav. Compare file hashes against the two manifests before running.

Use Python 3.12 with pandas 3.0.1 and pyreadstat 1.3.8 (requirements.txt), R 4.5.2, and survey 4.5. Set ENA_R_LIB if survey is installed in a nonstandard R library. The following commands illustrate the workflow; substitute local paths and keep all LOCAL_ONLY.csv files outside the publication folder:

    python -m pip install -r requirements.txt
    python scripts_historical/extract_design.py --historical "E:\metodo\ENA_2014_2024.sav" --round-2025 "E:\metodo\ENA_2025\1036-Modulo1911\19_CAP1100.sav" --output "C:\private\holders_2014_2025_LOCAL_ONLY.csv"
    Rscript scripts_historical/run_analysis.R "C:\private\holders_2014_2025_LOCAL_ONLY.csv" "C:\private\results_historical"
    Rscript supplementary_analysis.R "C:\private\holders_2014_2025_LOCAL_ONLY.csv" "C:\private\supplementary"

    python build_2025_access.py --ena-root "E:\metodo\ENA_2025" --output "C:\private\ena_2025_access_LOCAL_ONLY.csv"
    Rscript analyse_2025_access.R "C:\private\ena_2025_access_LOCAL_ONLY.csv" "C:\private\results_2025"
    Rscript make_2025_figures.R "C:\private\results_2025"

    pdflatex -interaction=nonstopmode -halt-on-error manuscript.tex
    pdflatex -interaction=nonstopmode -halt-on-error manuscript.tex

The Windows launchers in scripts_historical/ offer optional dependency setup and a dated input/output SHA-256 run manifest; pass executable and data paths as needed.

The figures used by the manuscript are included at the repository root. The versioned Zenodo snapshot has DOI [10.5281/zenodo.24395430](https://doi.org/10.5281/zenodo.24395430).

## Scientific and reproducibility limits

Annual weighted estimates refer to their survey-specific target populations. INEI changed the sampling frame around 2023, so the 2014 and 2025 percentages are not a like-for-like population trend. The historical consolidated SPSS file does not include a verified recipe from every original annual module. Computational reproduction is verified from that consolidated input plus official 2025 modules, not from all raw historical sources. Historical intervals use analytical year-by-department strata; 2025 access intervals use the recorded stratum and an explicit singleton-PSU adjustment. Neither is an official INEI interval. The recorded binary sex code is not a measure of gender identity, land ownership, work, agency, or discrimination.

The journal has not been selected. Authors must complete affiliations, correspondence, ORCID if applicable, contributions, funding, conflicts of interest, and the institutional ethics determination before submission.
