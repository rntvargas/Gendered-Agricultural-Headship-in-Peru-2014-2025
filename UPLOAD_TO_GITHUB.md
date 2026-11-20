# Paquete para GitHub

Este paquete contiene el manuscrito, LaTeX, scripts, figuras, resultados agregados, verificaciones de procedencia y documentación. No contiene microdatos individuales ENA.

La versión archivada en Zenodo es [10.5281/zenodo.24395430](https://doi.org/10.5281/zenodo.24395430). Esta copia para GitHub añade el enlace del repositorio al artículo, un README visual y un verificador de integridad; sus archivos no son idénticos byte a byte a los del ZIP de Zenodo.

## Publicar

1. Descomprima el ZIP.
2. Copie **su contenido** a la raíz de `https://github.com/rntvargas/Gendered-Agricultural-Headship-in-Peru-2014-2025` y confirme los archivos con un commit.
3. No agregue archivos `.sav` ni ningún `LOCAL_ONLY.csv`.
4. Compruebe que `README.md`, `assets/readme_banner.svg`, `manuscript.pdf`, `manuscript.tex`, `CITATION.cff` y `LICENSE.md` aparecen en la raíz y sus rutas relativas.
5. Ejecute `python verify_package.py` desde la raíz para verificar los hashes del paquete.

El manuscrito cubre 2014-2025, sin ronda ENA 2020. El análisis de servicios de 2025 es distinto de la serie histórica. La construcción original del SPSS consolidado 2014-2024 sigue sin una receta verificable; lea `README.md` y `SUBMISSION_READINESS.md` antes del envío a revista.
