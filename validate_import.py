#!/usr/bin/env python3
"""
Validate that every county path in a MapChart save file maps to a
county polygon in the app's counties.json GeoJSON bundle.

Usage: python3 validate_import.py [mapchartfile]
"""
import json, re, sys, unicodedata

MAPCHART_FILE = sys.argv[1] if len(sys.argv) > 1 else \
    "/Users/bqrosen/Library/Mobile Documents/com~apple~CloudDocs/mapchartSave__usa_counties__visited_260301.txt"
COUNTIES_JSON = "CountyTrackerIOS/counties.json"

# ── replicate CountyNameNormalizer ────────────────────────────────────────────

STATE_NAME_TO_CODE = {
    "alabama":"AL","alaska":"AK","arizona":"AZ","arkansas":"AR",
    "california":"CA","colorado":"CO","connecticut":"CT","delaware":"DE",
    "florida":"FL","georgia":"GA","hawaii":"HI","idaho":"ID",
    "illinois":"IL","indiana":"IN","iowa":"IA","kansas":"KS",
    "kentucky":"KY","louisiana":"LA","maine":"ME","maryland":"MD",
    "massachusetts":"MA","michigan":"MI","minnesota":"MN","mississippi":"MS",
    "missouri":"MO","montana":"MT","nebraska":"NE","nevada":"NV",
    "new hampshire":"NH","new jersey":"NJ","new mexico":"NM","new york":"NY",
    "north carolina":"NC","north dakota":"ND","ohio":"OH","oklahoma":"OK",
    "oregon":"OR","pennsylvania":"PA","rhode island":"RI","south carolina":"SC",
    "south dakota":"SD","tennessee":"TN","texas":"TX","utah":"UT",
    "vermont":"VT","virginia":"VA","washington":"WA","west virginia":"WV",
    "wisconsin":"WI","wyoming":"WY","district of columbia":"DC",
}

SUFFIXES = [" county", " parish", " borough", " census area", " municipality", " planning region", " co"]

def normalized_county_name(value):
    text = value.strip()
    lo = text.lower()
    for s in SUFFIXES:
        if lo.endswith(s):
            text = text[:-len(s)]
            break
    text = ''.join(c for c in unicodedata.normalize('NFKD', text) if not unicodedata.combining(c))
    # strip non-alphanumeric except space
    filtered = re.sub(r'[^a-zA-Z0-9 ]', ' ', text)
    return re.sub(r'\s+', ' ', filtered).strip()

def state_abbrev(code):
    if len(code) == 2:
        return code.upper()
    return STATE_NAME_TO_CODE.get(code.lower(), code.upper())

def county_key(country, state, name):
    state = state_abbrev(state)
    normalized = normalized_county_name(name)
    canonical = CANONICAL_COUNTY_NAME_BY_STATE_AND_NAME.get(
        (state.upper(), normalized.lower()),
        normalized,
    )
    return f"{country}-{state}-{canonical}".lower()

# ── robust MapChart path parse (mirrors Swift implementation) ─────────────────

COLLISION_SET = {
    ("st louis", "MO"), ("baltimore", "MD"), ("fairfax", "VA"),
    ("bedford", "VA"), ("franklin", "VA"), ("richmond", "VA"), ("roanoke", "VA"),
}

CANONICAL_COUNTY_NAME_BY_STATE_AND_NAME = {
    ("VI", "st croix"): "Saint Croix",
    ("VI", "st john"): "Saint John",
    ("VI", "st thomas"): "Saint Thomas",
    ("AK", "wade hampton"): "Kusilvak",
    ("AK", "southeast fairbanks"): "SE Fairbanks",
    ("AK", "chugach"): "Copper River",
    ("SD", "shannon"): "Oglala Lakota",
    ("LA", "la salle"): "LaSalle",
    ("IL", "lasalle"): "La Salle",
    ("NM", "do a ana"): "Dona Ana",
    ("MO", "ste genevieve"): "Sainte Genevieve",
}

def canonicalize_dc(name, state):
    return "District of Columbia" if state.upper() == "DC" else name

def parse_path(path):
    m = re.search(r'__([A-Z]{2})$', path)
    if not m:
        return None
    state = m.group(1)
    token = path[:m.start()]
    raw = re.sub(r'_+', ' ', token).strip()
    raw_lower = raw.lower()
    has_explicit_county_suffix = raw_lower.endswith(" co") or raw_lower.endswith(" county")
    name = normalized_county_name(raw)
    name = canonicalize_dc(name, state)
    if not has_explicit_county_suffix and (name.lower(), state.upper()) in COLLISION_SET:
        name = name + " city"
    return name, state

# ── load GeoJSON polygon keys ─────────────────────────────────────────────────

with open(COUNTIES_JSON) as f:
    geo = json.load(f)

features = geo.get("features", geo) if isinstance(geo, dict) else geo

# two-pass: only add " city" suffix when there's a true name collision
_pair_counts: dict = {}
for feat in features:
    p = feat.get("properties", {})
    k = (p.get("NAME", "").lower(), p.get("STUSAB", "").lower())
    _pair_counts[k] = _pair_counts.get(k, 0) + 1
_geo_collisions = {k for k, v in _pair_counts.items() if v > 1}

polygon_keys = set()
for feat in features:
    props = feat.get("properties", {})
    name  = props.get("NAME", "")
    state = props.get("STUSAB", "")
    lsad  = (props.get("LSAD", "") or "").lower()
    use_city = lsad == "city" and (name.lower(), state.lower()) in _geo_collisions
    county_name = name + " city" if use_city else name
    polygon_keys.add(county_key("us", state, county_name))

print(f"Polygon keys loaded: {len(polygon_keys)}")

# ── parse MapChart file ───────────────────────────────────────────────────────

with open(MAPCHART_FILE) as f:
    mc = json.load(f)

all_paths = []
for g in mc.get("groups", {}).values():
    all_paths.extend(g.get("paths", []))

print(f"MapChart paths: {len(all_paths)}")

# ── validate ──────────────────────────────────────────────────────────────────

missing   = []
unparseable = []

for path in all_paths:
    parsed = parse_path(path)
    if parsed is None:
        unparseable.append(path)
        continue
    name, state = parsed
    key = county_key("us", state, name)
    if key not in polygon_keys:
        missing.append((path, key))

print(f"\nUnparseable paths: {len(unparseable)}")
for p in unparseable:
    print(f"  {p!r}")

print(f"\nPaths with no matching polygon: {len(missing)}")
for path, key in missing:
    state_part = key.split("-")[1] if key.count("-") >= 2 else ""
    name_part = key.split("-")[2][:4] if key.count("-") >= 2 else ""
    candidates = [k for k in polygon_keys if k.split("-")[1] == state_part and k.split("-")[2][:4] == name_part] if state_part else []
    print("  path=%r" % path)
    print("    key=%r" % key)
    print("    similar: %r" % candidates[:3])

if not missing and not unparseable:
    print("\n✅ All paths matched successfully!")
