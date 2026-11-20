"""Build a local, non-public ENA 2025 producer-level access extract."""
import argparse
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.path.insert(0, str(Path(__file__).parent / "python"))
import pandas as pd
import pyreadstat

parser = argparse.ArgumentParser()
parser.add_argument("--ena-root", required=True, type=Path)
parser.add_argument("--output", required=True, type=Path)
args = parser.parse_args()
root = args.ena_root
key = ["ANIO", "CCDD", "CCPP", "CCDI", "NSEGM", "UA"]
spec = {
    "holder": ("19_CAP1100.sav", ["RESFIN", "REGION", "ESTRATO", "FACTOR_PRODUCTOR", "P1102", "P1103", "P1104_A", "P1105"]),
    "services": ("15_CAP700.sav", ["P701", "P704"]),
    "credit": ("17_CAP900.sav", ["P901", "P902", "P907"]),
    "area": ("01_CAP100A_01.sav", ["P104_SUP_ha"]),
}
frames = {}
for name, (filename, cols) in spec.items():
    path = next(root.rglob(filename))
    df, _ = pyreadstat.read_sav(str(path), usecols=key + cols, encoding="latin1")
    if name == "holder":
        df = df.loc[df.P1102.eq(1)].copy()
    duplicate = df.duplicated(key).sum()
    print(name, "rows", len(df), "duplicate keys", duplicate)
    if duplicate:
        print(df.loc[df.duplicated(key, keep=False), key].head(10).to_string(index=False))
        raise SystemExit("Nonunique key")
    frames[name] = df

combined = frames["holder"]
for name in ("services", "credit", "area"):
    before = len(combined)
    combined = combined.merge(frames[name], how="left", on=key, validate="one_to_one", indicator=name + "_merge")
    print(name, combined[name + "_merge"].value_counts().to_dict())
    assert len(combined) == before
    combined = combined.drop(columns=name + "_merge")

target = args.output
target.parent.mkdir(parents=True, exist_ok=True)
combined.to_csv(target, index=False)
print("wrote", target, len(combined))
for col in ["P701", "P704", "P901", "P902", "P907", "P104_SUP_ha"]:
    print(col, combined[col].value_counts(dropna=False).head(12).to_dict())
