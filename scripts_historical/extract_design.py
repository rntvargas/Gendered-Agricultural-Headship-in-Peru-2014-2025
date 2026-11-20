"""Extract holder and design fields from local INEI/ENA SPSS sources."""
import argparse
import sys
from pathlib import Path

import pandas as pd
import pyreadstat

parser = argparse.ArgumentParser()
parser.add_argument("--historical", required=True)
parser.add_argument("--round-2025", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()
target = Path(args.output)
target.parent.mkdir(parents=True, exist_ok=True)
cols = [
    "ANIO", "CCDD", "CCPP", "CCDI", "CONGLOMERADO", "CONGLOME",
    "NSEGM", "ESTRATO", "REGION", "DOMINIO", "FACTOR",
    "FACTOR_PRODUCTOR", "RESFIN", "P1102", "P1103", "P1104_A", "P1105", "UA",
]
print("Reading selected historical columns in one pass...", flush=True)
raw, _ = pyreadstat.read_sav(args.historical, usecols=cols, encoding="latin1")
print(f"Loaded {len(raw)} rows", flush=True)
holders = raw.loc[raw["P1102"].eq(1)].copy()
del raw
print("Reading ENA 2025 chapter 1100...", flush=True)
raw25, _ = pyreadstat.read_sav(args.round_2025, usecols=cols, encoding="latin1")
holders25 = raw25.loc[raw25["P1102"].eq(1)].copy()
del raw25
for col in cols:
    if col not in holders:
        holders[col] = pd.NA
    if col not in holders25:
        holders25[col] = pd.NA
df = pd.concat([holders[cols], holders25[cols]], ignore_index=True)
assert len(df) == 330338, len(df)
assert len(holders25) == 38449, len(holders25)
df.to_csv(target, index=False)
print(f"Saved {len(df)} rows to {target}", flush=True)
for col in ["CONGLOMERADO", "CONGLOME", "NSEGM", "ESTRATO", "DOMINIO", "FACTOR", "FACTOR_PRODUCTOR"]:
    print(col, df.groupby("ANIO")[col].apply(lambda x: x.notna().mean()).to_dict())
