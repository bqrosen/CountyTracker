import json, re

with open("CountyTrackerIOS/counties.json") as f:
    geo = json.load(f)

features = geo.get("features", geo) if isinstance(geo, dict) else geo

cities = {}
for feat in features:
    props = feat.get("properties", {})
    lsad = (props.get("LSAD", "") or "").lower()
    if lsad != "city":
        continue
    name = props.get("NAME", "")
    state = props.get("STUSAB", "")
    geom = feat.get("geometry", {})
    coords_flat = []
    stack = [geom.get("coordinates", [])]
    while stack:
        cur = stack.pop()
        if isinstance(cur, list) and len(cur) >= 2 and isinstance(cur[0], (int, float)):
            coords_flat.append(cur)
        elif isinstance(cur, list):
            stack.extend(cur)
    if coords_flat:
        lats = [c[1] for c in coords_flat]
        lons = [c[0] for c in coords_flat]
        key_name = re.sub(r"\s+", " ", name.lower().replace(".", "").replace("'", "").replace("-", " ")).strip()
        key = "us-%s-%s city" % (state.lower(), key_name)
        cities[key] = {
            "lat": round(sum(lats) / len(lats), 5),
            "lon": round(sum(lons) / len(lons), 5),
            "name": name + " city",
            "state": state,
        }

for k in sorted(cities.keys()):
    print("%s -> %s" % (k, json.dumps(cities[k])))
