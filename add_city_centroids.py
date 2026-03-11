import json, re

# Add city centroids to the centroid JSON
with open("CountyTrackerIOS/county_centroids.json") as f:
    centroids = json.load(f)

with open("CountyTrackerIOS/counties.json") as f:
    geo = json.load(f)

features = geo.get("features", geo) if isinstance(geo, dict) else geo

added = 0
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
        if key not in centroids:
            centroids[key] = {
                "lat": round(sum(lats) / len(lats), 5),
                "lon": round(sum(lons) / len(lons), 5),
                "name": name + " city",
                "state": state,
            }
            added += 1
            print("Added: %s" % key)

with open("CountyTrackerIOS/county_centroids.json", "w") as f:
    json.dump(centroids, f, separators=(",", ":"))

print("Added %d city centroids. Total: %d" % (added, len(centroids)))
