"""Convert the Swiss Food Composition Database (Schweizer Nährwertdatenbank, BLV) into the compact
JSON bundled with the app. Download: https://naehrwertdaten.ch/de/downloads/ (free, also for
diary apps, with source attribution).

Usage: python convert_swiss.py Schweizer_Nahrwertdatenbank.xlsx ../Purrtion/Resources/swiss.json
Needs openpyxl.
"""
import json
import re
import sys

import openpyxl

# app nutrient key -> column header (first match wins), factor to app unit
FIELDS = [
    ("kcal", ["Energie, Kilokalorien (kcal)"], 1),
    ("protein", ["Protein (g)"], 1),
    ("carbs", ["Kohlenhydrate, verfügbar (g)"], 1),
    ("fat", ["Fett, total (g)"], 1),
    ("sugar", ["Zucker (g)"], 1),
    ("fiber", ["Nahrungsfasern (g)"], 1),
    ("saturatedFat", ["Fettsäuren, gesättigt (g)"], 1),
    ("monoFat", ["Fettsäuren, einfach ungesättigt (g)"], 1),
    ("polyFat", ["Fettsäuren, mehrfach ungesättigt (g)"], 1),
    ("cholesterol", ["Cholesterin (mg)"], 1),
    ("salt", ["Salz (NaCl) (g)"], 1),
    ("sodium", ["Natrium (Na) (mg)"], 1),
    ("potassium", ["Kalium (K) (mg)"], 1),
    ("calcium", ["Calcium (Ca) (mg)"], 1),
    ("magnesium", ["Magnesium (Mg) (mg)"], 1),
    ("iron", ["Eisen (Fe) (mg)"], 1),
    ("zinc", ["Zink (Zn)  (mg)", "Zink (Zn) (mg)"], 1),
    ("phosphorus", ["Phosphor (P) (mg)"], 1),
    ("iodine", ["Jod (I) (µg)"], 1),
    ("selenium", ["Selen (Se) (µg)"], 1),
    ("vitaminA", ["Vitamin A-Aktivität, RE (µg)", "Vitamin A-Aktivität, RAE (µg)"], 1),
    ("vitaminC", ["Vitamin C (Ascorbinsäure) (mg)"], 1),
    ("vitaminD", ["Vitamin D (Calciferol) (µg)"], 1),
    ("vitaminE", ["Vitamin E (α-Tocopherol) (mg)"], 1),
    ("vitaminB1", ["Vitamin B1 (Thiamin) (mg)"], 1),
    ("vitaminB2", ["Vitamin B2 (Riboflavin) (mg)"], 1),
    ("vitaminB3", ["Niacin (mg)", "Niacin equivalent (mg)"], 1),
    ("vitaminB5", ["Pantothensäure (mg)"], 1),
    ("vitaminB6", ["Vitamin B6 (Pyridoxin) (mg)"], 1),
    ("vitaminB12", ["Vitamin B12 (Cobalamin) (µg)"], 1),
    ("folate", ["Folat (µg)"], 1),
    ("alcohol", ["Alkohol (g)"], 1),
]


def number(v):
    if isinstance(v, (int, float)):
        return v
    if isinstance(v, str):
        s = v.strip().replace(",", ".").lstrip("<")
        try:
            return float(s)
        except ValueError:
            return None
    return None


def main(src, dst):
    wb = openpyxl.load_workbook(src, read_only=True)
    rows = list(wb["Generische Lebensmittel"].iter_rows(values_only=True))
    m = re.search(r"V\s*(\d+(?:\.\d+)*)", str(rows[0][0] or ""))
    version = m.group(1) if m else "?"
    header = rows[2]
    col = {h: i for i, h in enumerate(header) if h}
    idx = []
    for key, names, factor in FIELDS:
        i = next((col[n] for n in names if n in col), None)
        if i is None:
            sys.exit(f"column missing: {names}")
        idx.append((key, i, factor))

    foods = []
    for r in rows[3:]:
        if not r[0] or not r[3]:
            continue
        values = []
        for key, i, factor in idx:
            v = number(r[i])
            values.append(None if v is None else round(v * factor, 4))
        if values[0] is None:
            continue
        foods.append([f"CH{r[0]}", str(r[3]).strip(), values, r[5] or "", r[4] or ""])

    out = {
        "source": f"Schweizer Nährwertdatenbank V {version}, Bundesamt für Lebensmittelsicherheit und Veterinärwesen BLV, naehrwertdaten.ch",
        "keys": [k for k, _, _ in FIELDS],
        "foods": foods,
    }
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(foods)} foods → {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
