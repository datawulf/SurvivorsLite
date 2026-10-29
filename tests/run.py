"""Runs SurvivorsLite in a mock 1.12 client under Lua 5.1 and checks 5.0 compatibility.

Usage: python tests/run.py [addon_dir] [harness_dir]   (needs: pip install lupa)
"""
import os
import re
import sys

from lupa import lua51

here = os.path.dirname(os.path.abspath(__file__))
addon_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "SurvivorsLite")
harness_dir = sys.argv[2] if len(sys.argv) > 2 else here

# ---- Lua 5.0 lint: constructs the 1.12 client's Lua does not have.
BAD = [
    (r"#\s*[A-Za-z_({]", "length operator #"),
    (r"[^%\w'\"]\s%\s", "modulo operator %"),
    (r"\bselect\s*\(", "select()"),
    (r"\.\.\.", "varargs ..."),
    (r"string\.match|string\.gmatch|:match\(|:gmatch\(", "string.match/gmatch"),
    (r"math\.huge|math\.fmod", "math.huge/fmod"),
    (r"\bgoto\b|//", "goto or //"),
    (r":HookScript\(|hooksecurefunc", "HookScript/hooksecurefunc"),
]


def strip(line):
    out, q = [], None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\":
                i += 2
                continue
            if c == q:
                q = None
            out.append(" ")
        elif c in "'\"":
            q = c
            out.append(" ")
        elif line.startswith("--", i):
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


problems = 0
toc = open(os.path.join(addon_dir, "SurvivorsLite.toc"), encoding="utf-8").read().splitlines()
files = [l.strip() for l in toc if l.strip() and not l.startswith("#")]
for name in files:
    for n, line in enumerate(open(os.path.join(addon_dir, name), encoding="utf-8"), 1):
        code = strip(line)
        for pat, what in BAD:
            if re.search(pat, code):
                print(f"LINT {name}:{n}: {what}: {line.strip()}")
                problems += 1
        if any(ord(ch) > 127 for ch in line):
            print(f"LINT {name}:{n}: non-ASCII character")
            problems += 1

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
g = lua.globals()
lua.execute("function setglobal(k, v) _G[k] = v end function getglobal(k) return _G[k] end")


def load(path, chunkname):
    src = open(path, encoding="utf-8").read()
    fn = lua.eval("function(src, name) local f, err = loadstring(src, name) if not f then error(err) end return f end")(src, chunkname)
    fn()


api = os.path.join(harness_dir, "azs_api.lua")
if not os.path.exists(api):
    sys.exit("tests/azs_api.lua is missing: run python tools/fetch_api.py first (the game's API is not shipped here)")
load(os.path.join(harness_dir, "mock.lua"), "mock.lua")
load(api, "azs_api.lua")
for name in files:
    load(os.path.join(addon_dir, name), name)

src = open(os.path.join(harness_dir, "scenario.lua"), encoding="utf-8").read()
fails = lua.execute(src)

chat = [g.MOCK.chat[i] for i in range(1, len(g.MOCK.chat) + 1)]
errors = [c for c in chat if "error" in c.lower()]
for c in chat:
    print("CHAT", re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", c))
failures = [fails[i] for i in range(1, len(fails) + 1)]
for f in failures:
    print("FAIL", f)
print(f"lint={problems} errors={len(errors)} failures={len(failures)}")
sys.exit(1 if problems or errors or failures else 0)
