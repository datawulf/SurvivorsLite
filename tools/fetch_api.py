"""Extracts the game's addon API into tests/azs_api.lua for the test harness.

The API (AZS_*) is Lua embedded in the Azeroth Survivors client build. It belongs to the
game, so this repository does not ship it; run this once before tests/run.py, and again
when the game updates its API.

Usage:
    python tools/fetch_api.py                 download the current web build and extract
    python tools/fetch_api.py --wasm FILE     extract from a wenilla_bg.wasm you already have
"""
import argparse
import datetime
import os
import re
import sys
import urllib.request

SITE = "https://wow.aethus.pl/"
API_START = b"-- Azeroth Survivors: the run for addons"
API_END = b'AZSApiFrame:SetScript("OnEvent", AZS_ApiOnEvent);\n'
PARSE_START = b"-- Azeroth Survivors: the run's numbers on the character pane"
PARSE_END = b"\treturn t;\nend\n"
# The client writes the HUD settings into this placeholder when it boots.
HUD_PLACEHOLDER = "{ HUD_CVARS_LUA }"
HUD_FILLED = '{ clock = "hudClock", bosses = "hudBosses" }'

here = os.path.dirname(os.path.abspath(__file__))
out_path = os.path.join(here, "..", "tests", "azs_api.lua")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "SurvivorsLite fetch_api"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def block(data, start, end):
    s = data.find(start)
    if s < 0:
        sys.exit("not found in the build: " + start.decode())
    e = data.find(end, s)
    if e < 0:
        sys.exit("no end after: " + start.decode())
    return data[s:e + len(end)].decode("utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wasm", help="a wenilla_bg.wasm on disk instead of downloading")
    args = ap.parse_args()

    if args.wasm:
        stamp = "local file " + os.path.basename(args.wasm)
        data = open(args.wasm, "rb").read()
    else:
        page = get(SITE).decode("utf-8", "replace")
        m = re.search(r"\?v=([0-9a-f]+)", page)
        if not m:
            sys.exit("no build stamp on " + SITE)
        stamp = m.group(1)
        print("downloading build", stamp, "(about 90 MB)")
        data = get(SITE + "wenilla_bg.wasm?v=" + stamp)

    api = block(data, API_START, API_END)
    if HUD_PLACEHOLDER not in api:
        print("note: the HUD settings placeholder changed; check AZS_HUD_CVARS")
    api = api.replace(HUD_PLACEHOLDER, HUD_FILLED)
    parse = block(data, PARSE_START, PARSE_END)

    today = datetime.date.today().isoformat()
    header = (
        "-- The client's own addon API (AZS_*), extracted from the Azeroth Survivors web build\n"
        "-- wenilla_bg.wasm (" + stamp + ", " + today + ") by tools/fetch_api.py for local\n"
        "-- testing only. Only the AZS_HUD_CVARS placeholder was filled in.\n"
        "-- AZS_Parse at the end comes from the client's character pane code in the same build.\n\n"
    )
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(header + api + "\n" + parse)
    print("wrote", os.path.normpath(out_path))


if __name__ == "__main__":
    main()
