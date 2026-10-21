#!/usr/bin/env python3
"""
Prints the server code of the friends page ("purrtion-server:…") from the gitignored Purrtion/Resources/Firebase.plist.

Paste it in the app under Einstellungen → Freunde → Freunde-Server verbinden, or send it to friends. Apps that are
already connected can share it themselves (Einstellungen → Freunde → Server-Code teilen).

    python3 tools/server_code.py
"""
import base64
import json
import os
import plistlib
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLIST = os.path.join(ROOT, "Purrtion", "Resources", "Firebase.plist")

if not os.path.exists(PLIST):
    sys.exit("Firebase.plist fehlt (siehe backend/README.md).")
with open(PLIST, "rb") as f:
    d = plistlib.load(f)
server = {"k": d.get("APIKey", ""), "p": d.get("ProjectID", ""), "i": d.get("InviteURL", "")}
if len(server["k"]) <= 20 or not server["p"]:
    sys.exit("Firebase.plist ist unvollständig.")
body = base64.urlsafe_b64encode(json.dumps(server, separators=(",", ":")).encode()).decode().rstrip("=")
print("purrtion-server:" + body)
