# Ficha del modelo, paquete 2014-2025

**Objetivo:** describir asociaciones entre sexo del productor agropecuario y edad, educación, región natural y ronda de ENA. El resultado binario es `P1103=2` entre personas con `P1102=1`.

**Datos:** 330.134 registros analíticos de once rondas, 2014-2025 sin 2020. Pesos anuales de expansión. La muestra de 2014-2022 y la de 2023-2025 se analizan también por separado debido al cambio de marco.

**Algoritmo:** `survey::svyglm`, familia `quasibinomial`, linealización de Taylor; efectos de ronda, edad lineal y cuadrática, cuatro niveles educativos, tres regiones. Conglomerados recuperados `CONGLOMERADO`/`NSEGM`; estratos analíticos año-departamento. El diseño no reproduce todos los estratos oficiales.

**Interpretación permitida:** razones de momios condicionales y probabilidades estandarizadas sobre la distribución de covariables de 2025. Las diferencias son asociaciones, no efectos de cambiar educación o residencia.

**Validación:** separación temporal con entrenamiento 2014-2024 y prueba 2025, sin indicador de ronda en el modelo predictivo. AUC ponderada 0,615; Brier 0,206 frente a 0,215 de referencia; predicción media 28,61 % frente a 31,18 % observado. La subestimación es 2,57 puntos porcentuales. No hay rendimiento suficiente para usar el modelo en decisiones individuales.

**Señal de revisión:** una nueva ejecución debe comparar recuentos, categorías, pesos, cobertura de identificadores muestrales, AUC, Brier y calibración con `results_historical/`. Una falla de los controles de datos detiene la ejecución. Cambios de marco o cuestionario requieren nueva validación conceptual antes de comparar coeficientes o desplegar predicciones.

**Uso no recomendado:** inferir migración masculina, propiedad legal de tierra, empoderamiento, vulnerabilidad causal, elegibilidad para programas o resultados individuales. La muestra y la especificación no permiten esas inferencias.

**Trazabilidad:** `source_hashes.csv` identifica el consolidado histórico y el módulo de productores 2025; `source_manifest.csv` identifica los cuatro módulos usados en el análisis de acceso de 2025. `PACKAGE_MANIFEST_SHA256.csv` identifica los entregables y `verify_package.py` permite comprobar su integridad. `results_historical/sessionInfo.txt` y `results_2025/sessionInfo.txt` documentan el entorno verificado. El lanzador histórico registra hashes de cada ejecución nueva.
