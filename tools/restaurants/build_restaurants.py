#!/usr/bin/env python3
"""
Builds Purrtion/Resources/restaurants.json – official nutrition values of large restaurant chains in Germany.

Only the chains' own published data is used (no crowd-sourced databases):
  * Burger King Deutschland – fetched live from the public content API behind burgerking.de.
  * McDonald's Deutschland  – mcdonalds.com blocks scripted downloads, so the raw data is collected once in a
    normal browser with tools/restaurants/mcdonalds_scrape.js and saved as tools/restaurants/raw/mcdonalds.json.

Format (same idea as bls.json / swiss.json, values per 100 g or 100 ml):
  {"version", "keys": [...], "chains": {id: {name, source}}, "foods": [[code, chain, name, category, serving, unit, [values]]]}

Usage:  python3 tools/restaurants/build_restaurants.py
"""
import datetime
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "tools", "restaurants", "raw")
OUT = os.path.join(ROOT, "Purrtion", "Resources", "restaurants.json")
KEYS = ["kcal", "protein", "carbs", "fat", "sugar", "fiber", "saturatedFat", "salt"]
TODAY = datetime.date.today()


def clean_name(name: str) -> str:
    name = re.sub(r"\s+", " ", name.replace(" ", " ")).strip()
    # Price and ordering notes are not part of the product: "Red Bull 0,25l (zzgl. 1,50€ Aufpreis)", "(BK Lieferservice)"
    name = re.sub(r"\s*\((zzgl\.[^)]*|[^)]*Lieferservice[^)]*)\)", "", name, flags=re.I).strip()
    # Same size written differently: "0,5l" / "0,5 l"
    name = re.sub(r"(\d) ?l\b", r"\1 l", name)
    if name[:1].islower():
        name = name[0].upper() + name[1:]
    return name


def per100(portion: dict, weight: float, given: dict) -> list:
    """Per-100 values: computed from the exact portion values when the weight is known, else the published per-100 values."""
    out = []
    for k in KEYS:
        v = None
        if weight and portion.get(k) is not None:
            v = portion[k] / weight * 100
        elif given.get(k) is not None:
            v = given[k]
        out.append(None if v is None else round(v, 2))
    c, sug, f, sat = KEYS.index("carbs"), KEYS.index("sugar"), KEYS.index("fat"), KEYS.index("saturatedFat")
    if out[sug] is not None and (out[c] or 0) < out[sug]:
        out[c] = out[sug]   # e.g. Mezzo Mix is published with 0 g carbs but 38 g sugar
    if out[sat] is not None and (out[f] or 0) < out[sat]:
        out[f] = out[sat]
    return out


# MARK: Burger King

def bk_query(q: str):
    url = "https://czqk28jt.apicdn.sanity.io/v2023-08-01/data/query/prod_bk_de?" + urllib.parse.urlencode({"query": q})
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Purrtion"}), timeout=60) as r:
        return json.load(r)["result"]


def burger_king() -> list:
    sections = bk_query('*[_type=="menu"][0].options[]->{"name": name.de, "options": options[]->{_type, _id,'
                        ' "options": options[]{"o": option->{_type, _id, "main": mainItem._ref}}, "main": mainItem._ref}}')
    wanted = {}   # item id -> category
    for s in sections or []:
        cat = (s.get("name") or "").strip()
        if not cat or cat.upper() == "TEST":
            continue
        for o in s.get("options") or []:
            if not o:
                continue
            if o["_type"] == "item":
                wanted.setdefault(o["_id"], cat)
            elif o["_type"] == "combo" and o.get("main"):
                wanted.setdefault(o["main"], cat)
            elif o["_type"] == "picker":
                for p in o.get("options") or []:
                    x = (p or {}).get("o") or {}
                    if x.get("_type") == "item":
                        wanted.setdefault(x["_id"], cat)
                    elif x.get("_type") == "combo" and x.get("main"):
                        wanted.setdefault(x["main"], cat)
    # Sides, dips and drinks offered inside the current menus (only those, old promotions stay out).
    combos = set()
    for s in sections or []:
        for o in (s.get("options") or []) if (s.get("name") or "").strip().upper() != "TEST" else []:
            if o and o["_type"] == "combo":
                combos.add(o["_id"])
            for p in (o or {}).get("options") or []:
                x = (p or {}).get("o") or {}
                if x.get("_type") == "combo":
                    combos.add(x["_id"])
    slot_items = bk_query('*[_type=="combo" && _id in $ids].options[]->options[].option->{_type, _id, "name": name.de}'.replace(
        "$ids", json.dumps(sorted(combos))))
    for x in slot_items or []:
        if x and x.get("_type") == "item":
            nm = (x.get("name") or "").lower()
            cat = "Drinks" if re.search(r"\d[,.]\d+ ?l\b|cola|fanta|sprite|wasser|tee|kaffee|saft|energy|red bull|bier|heineken", nm) else "Beilagen & Dips"
            wanted.setdefault(x["_id"], cat)
    # Referenced items sometimes have no values while an item with the same name has them: fall back by name.
    every = bk_query('*[_type=="item" && nutrition.calories > 0]{_id, "name": name.de, nutrition}')
    by_name = {}
    for it in every:
        by_name.setdefault(clean_name(it.get("name") or "").lower(), it)
    refs = bk_query('*[_type=="item" && _id in $ids]{_id, "name": name.de, nutrition}'.replace("$ids", json.dumps(sorted(wanted))))
    items = []
    for it in refs:
        if not (it.get("nutrition") or {}).get("calories"):
            alt = by_name.get(clean_name(it.get("name") or "").lower())
            if not alt:
                continue
            it = dict(alt, _id=it["_id"])
        items.append(it)
    foods, seen = [], set()
    for it in items:
        n = it.get("nutrition") or {}
        name = clean_name(it.get("name") or "")
        if not name or not n.get("calories") or name.lower().startswith("ohne "):
            continue
        weight = float(n.get("weight") or 0)
        portion = {"kcal": n.get("calories"), "protein": n.get("proteins"), "carbs": n.get("carbohydrates"), "fat": n.get("fat"),
                   "sugar": n.get("sugar"), "fiber": n.get("fiber"), "saturatedFat": n.get("saturatedFat"), "salt": n.get("salt")}
        given = {"kcal": n.get("caloriesPer100"), "protein": n.get("proteinsPer100"), "carbs": n.get("carbohydratesPer100"),
                 "fat": n.get("fatPer100"), "sugar": n.get("sugarPer100"), "saturatedFat": n.get("saturatedFatPer100"),
                 "salt": n.get("saltPer100")}
        if not weight and given.get("kcal"):
            weight = round(portion["kcal"] / given["kcal"] * 100)   # derive the portion size from the per-100 value
        if not weight:
            continue
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        cat = wanted.get(it["_id"], "")
        unit = "ml" if cat == "Drinks" else "g"
        foods.append([f"bk-{it['_id']}", "burgerking", name, cat, round(weight), unit, per100(portion, weight, given)])
    return foods


# MARK: McDonald's

MCD_CATEGORIES = {
    "burger": "Burger", "mcwrap": "McWrap", "mccrispy": "McCrispy", "mcnuggets-fingerfood": "McNuggets & Fingerfood",
    "veggie-und-plantbased": "Veggie & Plant-based", "beilagen-extras": "Beilagen & Extras", "fruehstueck": "Frühstück",
    "getraenke": "Getränke", "desserts": "Desserts", "mccafe": "McCafé", "mcsmart-snacks": "McSmart Snacks", "highlights": "Highlights",
}


def num(x):
    try:
        return float(str(x).replace(",", "."))
    except (TypeError, ValueError):
        return None


DRINK = re.compile(r"café|cappuccino|latte|espresso|tee\b|grüntee|kakao|chocolate|refresher|energizer|cola|fanta|sprite|"
                   r"mezzo|wasser|schorle|saft|red bull|haferdrink|milch\b", re.I)


def volume_ml(name: str):
    """Volume written in the product name: "0,5l" → 500, "250 ml" → 250."""
    m = re.search(r"(\d+(?:[,.]\d+)?) ?(ml|l)\b", name, re.I)
    if not m:
        return None
    v = float(m.group(1).replace(",", "."))
    return v if m.group(2).lower() == "ml" else v * 1000


def mcdonalds() -> list:
    path = os.path.join(RAW, "mcdonalds.jsonl")
    if not os.path.exists(path):
        print("  McDonald's: raw/mcdonalds.jsonl fehlt, übersprungen", file=sys.stderr)
        return []
    foods, seen = [], set()
    for line in open(path, encoding="utf-8"):
        if not line.strip():
            continue
        pid, cat_key, raw_name, size, *values = json.loads(line)
        portion = {k: (num(v[0]) if v else None) for k, v in zip(KEYS, values)}
        given = {k: (num(v[2]) if v else None) for k, v in zip(KEYS, values)}
        name = clean_name(raw_name)
        cat = MCD_CATEGORIES.get(cat_key, cat_key)
        drink = (cat in ("Getränke", "McCafé") or DRINK.search(name)) and not re.search(r"sahne|milchshake", name, re.I)
        weight = num(size[0]) if size else None
        if size and str(size[1]).lower() == "l":
            weight *= 1000
        # Bottles are listed with their gross weight (0,5 l → 543 g): the volume in the name is the better serving.
        if drink and volume_ml(name):
            weight = volume_ml(name)
        elif drink and weight == 543:
            weight = 500   # 0,5 l bottle without the volume in its name
        if not weight and given.get("kcal") and portion.get("kcal"):
            weight = round(portion["kcal"] / given["kcal"] * 100)
        if not weight or portion.get("kcal") is None:
            continue
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        foods.append([f"mcd-{pid}", "mcdonalds", name, cat, round(weight), "ml" if drink else "g", per100(portion, weight, given)])
    return foods


def main():
    chains = {}
    foods = []
    for chain_id, title, source, fn in [
        ("mcdonalds", "McDonald's", "McDonald's Deutschland, Nährwertangaben auf mcdonalds.com/de", mcdonalds),
        ("burgerking", "Burger King", "Burger King Deutschland, Nährwertangaben auf burgerking.de", burger_king),
    ]:
        part = fn()
        print(f"  {title}: {len(part)} Produkte")
        if part:
            chains[chain_id] = {"name": title, "source": source}
            foods += part
    foods.sort(key=lambda f: (f[1], f[2].lower()))
    codes = [f[0] for f in foods]
    assert len(codes) == len(set(codes)), "doppelte Codes"
    data = {"source": "Offizielle Nährwertangaben der Restaurantketten (Deutschland), Stand " + TODAY.strftime("%d.%m.%Y"),
            "version": TODAY.strftime("%Y.%m"), "keys": KEYS, "chains": chains, "foods": foods}
    text = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print(f"{len(foods)} Produkte → {os.path.relpath(OUT, ROOT)} ({len(text) // 1024} KB)")
    print("sha256", hashlib.sha256(text.encode()).hexdigest())


if __name__ == "__main__":
    main()
