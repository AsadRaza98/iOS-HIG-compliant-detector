#!/usr/bin/env python3
"""Reads `xcrun simctl list devices available -j` on stdin and prints up to N
iPhone simulators (UDID|name), preferring different screen sizes."""
import json
import re
import sys

want = int(sys.argv[1]) if len(sys.argv) > 1 else 3
devices_by_runtime = json.load(sys.stdin)["devices"]


def version(runtime):
    tail = runtime.rsplit("iOS-", 1)[-1]
    return tuple(int(part) for part in tail.split("-") if part.isdigit())


runtimes = sorted((r for r in devices_by_runtime if "SimRuntime.iOS-" in r), key=version, reverse=True)
if not runtimes:
    sys.exit(0)

phones = [d for d in devices_by_runtime[runtimes[0]]
          if d.get("isAvailable", True) and d["name"].startswith("iPhone")]


def category(name):
    if "Pro Max" in name:
        return "max"
    if "SE" in name:
        return "se"
    if "Plus" in name:
        return "plus"
    if "Air" in name:
        return "air"
    if "mini" in name:
        return "mini"
    if name.endswith("Pro"):
        return "pro"
    if re.search(r"\d+e$", name):
        return "e"
    return "base"


priority = ["base", "max", "se", "e", "mini", "air", "plus", "pro"]
chosen = []
for cat in priority:
    for d in phones:
        if len(chosen) >= want:
            break
        if category(d["name"]) == cat and all(c["name"] != d["name"] for c in chosen):
            chosen.append(d)
            break
for d in phones:  # fill up if there were fewer categories than workers
    if len(chosen) >= want:
        break
    if all(c["udid"] != d["udid"] for c in chosen):
        chosen.append(d)

for d in chosen[:want]:
    print(f'{d["udid"]}|{d["name"]}')
