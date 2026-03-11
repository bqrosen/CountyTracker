#!/usr/bin/env python3
"""Full validation + centroid JSON fix for city/county disambiguation."""
import json, re

MAPCHART_FILE = "/Users/bqrosen/Library/Mobile Documents/com~apple~CloudDocs/mapchartSave__usa_counties__visited_260301.txt"
COUNTIES_JSON = "CountyTrackerIOS/counties.json"
CENTROIDS_JSON = "CountyTrackerIOS/county_centroids.json"

SUFFIXES = [" county", " parish", " borough", " census area", " municipality", " co"]

def normalize(value):
    text = value.strip()
    lo = text.lower()
    for s in SUFFIXES:
        if lo.endswith(s):
            text = text[: -len(s)]
            break
    filtered = re.sub(r'[^a-zA-Z0-9 ]', ' ', text)
    return re.sub(r'\s+', ' ', filtered).strip()

def county_key(country, state, name):
    return f"{country}-{state.upper()[:2]}-{normalize(name)}".lower()

# ── Load GeoJSON, two-pass collision detection ─────────────────────────────
with open(COUNTIES_JSON) as f:
    geo = json.load(f)
features = geo.get("features", geo) if isinstance(geo, dict) else geo

name_state_counts = {}
for feat in features:
    p = feat.get("properties", {})
    k = (p.get("NAME","").lower(), p.get("STUSAB","").lower())
    name_state_counts[k] = name_state_counts.get(k, 0) + 1

collisions = {k for k, v in name_state_counts.items() if v > 1}
print("Collision pairs:", sorted(collisions))

# Build polygon key set with two-pass approach
polygon_keys = set()
for feat in features:
    p = feat.get("properties", {})
    name  = p.get("NAME", "")
    state = p.get("STUSAB", "")
    lsad  = (p.get("LSAD", "") or "").lower()
    pair  = (name.lower(), state.lower())
    use_city = lsad == "city" and pair in collisions
    county_name = name + " city" if use_city else name
    polygon_keys.add(county_key("us", state, county_name))

print(f"Polygon keys: {len(polygon_keys)}")

# ── Collision set for import/recording disambiguation ─────────────────────
# (normalized name, state-upper) pairs where both city and county exist
COLLISION_SET = {(normalize(n), s.upper()) for (n, s) in collisions}
print("Collision set for code:", sorted(COLLISION_SET))

# ── Validate MapChart import ───────────────────────────────────────────────
def parse_mapchart_path(path):
    m = re.search(r'__([A-Z]{2})$', path)
    if not m:
        return None
    state = m.group(1)
    token = path[:m.start()]
    raw = re.sub(r'_+', ' ', token).strip()

    # If token had explicit " Co" suffix → county side of collision
    if raw.lower().endswith(" co"):
        county_name = normalize(raw)   # strips " co"
        # do NOT add " city", this is the county
    else:
        county_name = normalize(raw)
        # Is this a collision city?
        if (county_name.lower(), state.upper()) in COLLISION_SET:
            county_name = county_name + " city"

    return county_name, state

with open(MAPCHART_FILE) as f:
    mc = json.load(f)
all_paths = [p for g in mc.get("groups", {}).values() for p in g.get("paths", [])]
print(f"\nMapChart paths: {len(all_paths)}")

missing = []
unparseable = []
for path in all_paths:
    r = parse_mapchart_path(path)
    if r is None:
        unparseable.append(path)
        continue
    name, state = r
    key = county_key("us", state, name)
    if key not in polygon_keys:
        missing.append((path, key))

print(f"Unparseable: {len(unparseable)}")
print(f"Missing matches: {len(missing)}")
for path, key in missing:
    print(f"  {path!r} -> {key!r}")

# ── Fix centroid JSON ──────────────────────────────────────────────────────
with open(CENTROIDS_JSON) as f:
    centroids = json.load(f)

# Rebuild: for each " city"-suffixed key we added, re-key correctly
rebuilt = {}
for k, v in centroids.items():
    if not k.endswith(" city"):
        rebuilt[k] = v
        continue
    # Strip " city" suffix to get the base
    base_key = k[:-5]          # drop " city"
    # Find the state and name from the base key
    parts = base_key.split("-", 2)  # us / state / name
    if len(parts) != 3:
        rebuilt[k] = v
        continue
    _, state, name = parts
    pair = (name, state)
    collision_pairs_lower = {(normalize(n), s) for (n, s) in collisions}
    if pair in collision_pairs_lower:
        # Collision → keep " city" key
        rebuilt[k] = v
    else:
        # Non-collision → use plain key
        rebuilt[base_key] = v

print(f"\nCentroid keys before: {len(centroids)}")
print(f"Centroid keys after:  {len(rebuilt)}")
city_keys_after = sorted(k for k in rebuilt if "city" in k)
print("Remaining 'city' centroid keys:", city_keys_after)

with open(CENTROIDS_JSON, "w") as f:
    json.dump(rebuilt, f, separators=(",", ":"))
print("\nCentroid JSON updated.")
