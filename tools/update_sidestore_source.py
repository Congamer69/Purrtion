#!/usr/bin/env python3
"""Adds a release to the SideStore source (distribution/sidestore-source.json).

usage: update_sidestore_source.py IPA [--tag v2.2] [--notes-out FILE]

Version and build come from the Xcode project, the notes from the matching CHANGELOG section. Size and SHA-256 are
computed from the IPA. Older versions stay in the list (newest first) so a release can be rolled back. Running it
again for the same version replaces that entry.
"""
import argparse, datetime, hashlib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "distribution", "sidestore-source.json")
REPO = "Congamer69/Purrtion"


def project_value(key):
    text = open(os.path.join(ROOT, "Purrtion.xcodeproj", "project.pbxproj")).read()
    return re.search(key + r" = ([0-9.]+);", text).group(1)


def changelog_notes(version):
    """The CHANGELOG section of `version` as plain text (headings and bold marks removed)."""
    text = open(os.path.join(ROOT, "CHANGELOG.md")).read()
    m = re.search(r"^## " + re.escape(version) + r"\b.*?\n(.*?)(?=^## |\Z)", text, re.S | re.M)
    if not m:
        return "Purrtion " + version
    lines = []
    for line in m.group(1).strip().splitlines():
        line = line.replace("**", "")
        if line.startswith("### "):
            line = line[4:].upper()
        elif line.startswith("- "):
            line = "• " + line[2:]
        lines.append(line)
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ipa")
    ap.add_argument("--tag")
    ap.add_argument("--notes-out")
    a = ap.parse_args()

    version = project_value("MARKETING_VERSION")
    build = project_value("CURRENT_PROJECT_VERSION")
    tag = a.tag or "v" + version
    if tag.lstrip("v") != version:
        sys.exit(f"Tag {tag} passt nicht zur Version {version} im Xcode-Projekt.")

    data = open(a.ipa, "rb").read()
    notes = changelog_notes(version)
    entry = {
        "version": version,
        "buildVersion": build,
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "localizedDescription": notes,
        "downloadURL": f"https://github.com/{REPO}/releases/download/{tag}/Purrtion-{version}.ipa",
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "minOSVersion": "27.0",
    }

    source = json.load(open(SOURCE))
    app = source["apps"][0]
    app["versions"] = [entry] + [v for v in app["versions"] if v["version"] != version]
    with open(SOURCE, "w") as f:
        json.dump(source, f, ensure_ascii=False, indent=2)
        f.write("\n")
    if a.notes_out:
        open(a.notes_out, "w").write(notes + "\n")
    print(f"Quelle aktualisiert: {version} ({build}), {entry['size']} Bytes, sha256 {entry['sha256'][:12]}…")


if __name__ == "__main__":
    main()
