"""Packs SurvivorsLite into dist/SurvivorsLite-<version>.zip for the game's AddOns page.

The zip holds one top folder named like its .toc, which is what the client's installer
looks for, with the Lua files the .toc lists and the textures in media/ (make them with
tools/make_media.py). Run tests/run.py first.
"""
import hashlib
import os
import re
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "SurvivorsLite")
toc = open(os.path.join(src, "SurvivorsLite.toc"), encoding="utf-8").read()
version = re.search(r"^## Version: (\S+)", toc, re.M).group(1)
files = ["SurvivorsLite.toc"] + [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
files += sorted("media/" + n for n in os.listdir(os.path.join(src, "media")) if n.endswith(".blp"))

os.makedirs(os.path.join(here, "dist"), exist_ok=True)
out = os.path.join(here, "dist", f"SurvivorsLite-{version}.zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for name in files:
        info = zipfile.ZipInfo(f"SurvivorsLite/{name}", date_time=(2026, 10, 29, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, open(os.path.join(src, name), "rb").read())
digest = hashlib.sha256(open(out, "rb").read()).hexdigest()
print(out)
print(f"{os.path.getsize(out)} bytes, sha256 {digest}")
