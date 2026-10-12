"""Writes data/manifest.json for the in-app database updater.

Each database gets its version, a revision that increases whenever the file content changes,
the raw GitHub URL and the number of foods. Run after converting a new BLS or Swiss file:

    python tools/update_manifest.py
"""
import hashlib
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = "https://raw.githubusercontent.com/Congamer69/Purrtion/main/"
FILES = {"bls": "Purrtion/Resources/bls.json", "swiss": "Purrtion/Resources/swiss.json"}
MANIFEST = os.path.join(ROOT, "data", "manifest.json")


def version_of(name, source):
    m = re.search(r"(?:Version|V)\s*(\d+(?:\.\d+)*)", source)
    if m:
        return m.group(1)
    return "4.0" if name == "bls" else "7.1"


def main():
    old = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            old = json.load(f).get("databases", {})
    out = {}
    for name, rel in FILES.items():
        path = os.path.join(ROOT, rel)
        with open(path, "rb") as f:
            raw = f.read()
        data = json.loads(raw)
        sha = hashlib.sha256(raw).hexdigest()
        prev = old.get(name, {})
        revision = prev.get("revision", 1)
        if prev and prev.get("sha256") != sha:
            revision += 1
        out[name] = {
            "version": version_of(name, data.get("source", "")),
            "revision": revision,
            "url": RAW + rel,
            "foods": len(data["foods"]),
            "sha256": sha,
        }
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump({"databases": out}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
