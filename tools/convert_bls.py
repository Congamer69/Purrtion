"""Convert the official BLS 4.0 Excel file (Max Rubner-Institut, CC BY 4.0) into the compact
JSON bundled with the app.

Usage: python convert_bls.py BLS_4_0_Daten_2025_DE.xlsx ../Purrtion/Resources/bls.json
Needs openpyxl.
"""
import json
import sys

import openpyxl

# app nutrient key -> (BLS component code(s) in priority order, factor to app unit)
FIELDS = [
    ("kcal", ["ENERCC"], 1),
    ("protein", ["PROT625"], 1),
    ("carbs", ["CHO"], 1),
    ("fat", ["FAT"], 1),
    ("sugar", ["SUGAR"], 1),
    ("fiber", ["FIBT"], 1),
    ("saturatedFat", ["FASAT"], 1),
    ("monoFat", ["FAMS"], 1),
    ("polyFat", ["FAPU"], 1),
    ("omega3", ["FAPUN3"], 1),
    ("cholesterol", ["CHORL"], 1),
    ("salt", ["NACL"], 1),
    ("sodium", ["NA"], 1),
    ("potassium", ["K"], 1),
    ("calcium", ["CA"], 1),
    ("magnesium", ["MG"], 1),
    ("iron", ["FE"], 1),
    ("zinc", ["ZN"], 1),
    ("phosphorus", ["P"], 1),
    ("iodine", ["ID"], 1),
    ("copper", ["CU"], 0.001),        # µg -> mg
    ("manganese", ["MN"], 0.001),     # µg -> mg
    ("vitaminA", ["VITA"], 1),
    ("vitaminC", ["VITC"], 1),
    ("vitaminD", ["VITD"], 1),
    ("vitaminE", ["VITE"], 1),
    ("vitaminK", ["VITK"], 1),
    ("vitaminB1", ["THIA"], 1),
    ("vitaminB2", ["RIBF"], 1),
    ("vitaminB3", ["NIAEQ", "NIA"], 1),
    ("vitaminB5", ["PANTAC"], 1),
    ("vitaminB6", ["VITB6"], 0.001),  # µg -> mg
    ("biotin", ["BIOT"], 1),
    ("vitaminB12", ["VITB12"], 1),
    ("folate", ["FOL", "FOLFD"], 1),
    ("alcohol", ["ALC"], 1),
]


def main(src, dst):
    ws = openpyxl.load_workbook(src, read_only=True).active
    rows = ws.iter_rows(values_only=True)
    header = next(rows)
    col = {}
    for i, h in enumerate(header):
        if h and " " in h and h.endswith("/100g]"):
            col[h.split(" ", 1)[0]] = i

    foods = []
    for r in rows:
        code, name = r[0], r[1]
        if not code or not name:
            continue
        values = []
        for _, codes, factor in FIELDS:
            v = None
            for c in codes:
                raw = r[col[c]] if c in col else None
                if isinstance(raw, (int, float)):
                    v = round(raw * factor, 4)
                    break
            values.append(v)
        if values[0] is None:
            continue
        foods.append([code, name.strip(), values])

    out = {
        "source": "Bundeslebensmittelschlüssel (BLS) 4.0, Max Rubner-Institut 2025, CC BY 4.0, DOI 10.25826/Data20251217-134202-0",
        "keys": [k for k, _, _ in FIELDS],
        "foods": foods,
    }
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(foods)} foods -> {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
