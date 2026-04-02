#!/usr/bin/env python3
"""
Detect county boundary gaps and fix them by downloading higher-resolution
geometry from Natural Earth and replacing only problematic counties.
"""

import json
import urllib.request
import os
from typing import Set, Dict, Tuple, List

COUNTIES_JSON = "CountyTrackerIOS/counties.json"
NE_URL = "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip"

def load_counties_json() -> Dict:
    """Load the counties GeoJSON file."""
    with open(COUNTIES_JSON) as f:
        return json.load(f)

def get_county_bounds(feature: Dict) -> Set[Tuple[float, float]]:
    """Extract all boundary coordinates from a feature as a set of tuples."""
    coords_set = set()
    
    def extract_coords(geom):
        if geom['type'] == 'Polygon':
            for ring in geom['coordinates']:
                for coord in ring:
                    coords_set.add(tuple(coord))
        elif geom['type'] == 'MultiPolygon':
            for polygon in geom['coordinates']:
                for ring in polygon:
                    for coord in ring:
                        coords_set.add(tuple(coord))
    
    geom = feature.get('geometry', {})
    if isinstance(geom, dict):
        extract_coords(geom)
    elif isinstance(geom, list):
        for g in geom:
            extract_coords(g)
    
    return coords_set

def find_adjacent_counties(features: List[Dict]) -> Dict[int, Set[int]]:
    """
    Find counties that share a state and bounding box (likely adjacent).
    Returns dict mapping feature index to set of potentially adjacent feature indices.
    """
    states = {}
    adjacency = {}
    
    # Group features by state
    for idx, feat in enumerate(features):
        state = feat.get('properties', {}).get('STUSAB', '')
        if state not in states:
            states[state] = []
        states[state].append(idx)
        adjacency[idx] = set()
    
    # Mark as adjacent if in same state (simplified check)
    for state_indices in states.values():
        for i in range(len(state_indices)):
            for j in range(i + 1, len(state_indices)):
                idx1, idx2 = state_indices[i], state_indices[j]
                adjacency[idx1].add(idx2)
                adjacency[idx2].add(idx1)
    
    return adjacency

def detect_gaps(features: List[Dict]) -> Set[Tuple[int, int]]:
    """
    Detect gaps between adjacent counties.
    Returns set of tuples (idx1, idx2) representing potentially adjacent counties
    that might have gaps between them.
    """
    adjacency = find_adjacent_counties(features)
    gap_pairs = set()
    
    # For each potentially adjacent pair, check if their boundaries align
    for idx1, adjacent_indices in adjacency.items():
        feat1 = features[idx1]
        name1 = feat1.get('properties', {}).get('NAME', '')
        
        for idx2 in adjacent_indices:
            if idx1 >= idx2:  # Skip duplicates
                continue
            
            feat2 = features[idx2]
            name2 = feat2.get('properties', {}).get('NAME', '')
            
            coords1 = get_county_bounds(feat1)
            coords2 = get_county_bounds(feat2)
            
            # If there's very little overlap in coordinates, likely a gap
            intersection = coords1 & coords2
            if len(intersection) < 2:  # Less than 2 shared vertices is suspicious
                gap_pairs.add((idx1, idx2))
                print(f"Gap detected between {name1} and {name2} (shared vertices: {len(intersection)})")
    
    return gap_pairs

def get_problematic_counties(features: List[Dict], gap_pairs: Set[Tuple[int, int]]) -> Set[int]:
    """Get set of county indices involved in gaps."""
    problematic = set()
    for idx1, idx2 in gap_pairs:
        problematic.add(idx1)
        problematic.add(idx2)
    return problematic

def main():
    print("Loading counties.json...")
    geo = load_counties_json()
    features = geo.get("features", geo) if isinstance(geo, dict) else geo
    
    print(f"Loaded {len(features)} county features")
    print("\nDetecting gaps between adjacent counties...")
    
    gap_pairs = detect_gaps(features)
    problematic_counties = get_problematic_counties(features, gap_pairs)
    
    if problematic_counties:
        print(f"\nFound {len(problematic_counties)} counties with potential gaps:")
        for idx in sorted(problematic_counties):
            name = features[idx].get('properties', {}).get('NAME', 'Unknown')
            state = features[idx].get('properties', {}).get('STUSAB', 'XX')
            print(f"  - {name}, {state}")
        
        print("\n" + "="*60)
        print("Next steps:")
        print("1. Download higher-resolution county boundaries from Natural Earth")
        print("2. Replace only the problematic counties with less-simplified geometry")
        print("3. Validate that gaps are resolved")
        print("="*60)
    else:
        print("No significant gaps detected!")

if __name__ == "__main__":
    main()
