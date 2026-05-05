#!/usr/bin/env python3
"""
Download raw US Census TIGER/Line county boundaries and convert to GeoJSON.
Uses pure Python (pyshp library) - no GDAL required.
"""

import json
import urllib.request
import zipfile
import os
import tempfile
import shutil
from pathlib import Path

STATEFP_TO_STUSAB = {
    "01": "AL", "02": "AK", "04": "AZ", "05": "AR", "06": "CA", "08": "CO",
    "09": "CT", "10": "DE", "11": "DC", "12": "FL", "13": "GA", "15": "HI",
    "16": "ID", "17": "IL", "18": "IN", "19": "IA", "20": "KS", "21": "KY",
    "22": "LA", "23": "ME", "24": "MD", "25": "MA", "26": "MI", "27": "MN",
    "28": "MS", "29": "MO", "30": "MT", "31": "NE", "32": "NV", "33": "NH",
    "34": "NJ", "35": "NM", "36": "NY", "37": "NC", "38": "ND", "39": "OH",
    "40": "OK", "41": "OR", "42": "PA", "44": "RI", "45": "SC", "46": "SD",
    "47": "TN", "48": "TX", "49": "UT", "50": "VT", "51": "VA", "53": "WA",
    "54": "WV", "55": "WI", "56": "WY", "60": "AS", "66": "GU", "69": "MP",
    "72": "PR", "78": "VI"
}

def download_census_counties():
    """Download US Census Bureau TIGER/Line county boundaries."""
    print("Downloading US Census TIGER/Line 2023 county boundaries...")
    
    url = "https://www2.census.gov/geo/tiger/TIGER2023/COUNTY/tl_2023_us_county.zip"
    
    temp_dir = tempfile.mkdtemp()
    zip_path = os.path.join(temp_dir, "counties.zip")
    
    try:
        print(f"  URL: {url}")
        urllib.request.urlretrieve(url, zip_path)
        print(f"  ✓ Downloaded ({os.path.getsize(zip_path) / (1024*1024):.1f} MB)")
        
        # Extract
        extract_dir = os.path.join(temp_dir, "extracted")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        # Find shapefile
        shapefile_path = None
        for f in os.listdir(extract_dir):
            if f.endswith(".shp"):
                shapefile_path = os.path.join(extract_dir, f)
                break
        
        if not shapefile_path:
            print("ERROR: Could not find .shp file in archive")
            return None
        
        print(f"  ✓ Extracted to {extract_dir}")
        return shapefile_path, temp_dir
        
    except Exception as e:
        print(f"ERROR: {e}")
        return None

def shapefile_to_geojson_raw(shapefile_path):
    """
    Convert shapefile to GeoJSON using pyshp (pure Python).
    NO SIMPLIFICATION - preserves all raw Census geometry.
    """
    print("\nInstalling shapefile library...")
    try:
        import shapefile
    except ImportError:
        print("  Installing pyshp...")
        import subprocess
        subprocess.run([
            'pip', 'install', 'pyshp'
        ], check=True, capture_output=True)
        import shapefile
    
    print("Converting shapefile to raw GeoJSON...")
    
    try:
        sf = shapefile.Reader(shapefile_path)
        features = []
        
        print(f"  Reading {len(sf.shapes())} county features...")
        
        for i, shape in enumerate(sf.shapes()):
            if i % 500 == 0:
                print(f"    {i}...", end='', flush=True)
            
            record = sf.record(i)
            
            # Extract properties
            field_names = [field[0] for field in sf.fields[1:]]
            properties = dict(zip(field_names, record))

            # App loader expects USPS state code in STUSAB.
            if "STUSAB" not in properties or not properties.get("STUSAB"):
                statefp = str(properties.get("STATEFP", ""))
                if statefp in STATEFP_TO_STUSAB:
                    properties["STUSAB"] = STATEFP_TO_STUSAB[statefp]
            
            # Get geometry
            geometry = shape.__geo_interface__
            
            feature = {
                "type": "Feature",
                "properties": properties,
                "geometry": geometry
            }
            features.append(feature)
        
        print(f"\n  ✓ Converted {len(features)} features")
        
        geojson = {
            "type": "FeatureCollection",
            "features": features
        }
        
        return geojson
        
    except Exception as e:
        print(f"ERROR: {e}")
        return None

def save_geojson(geojson, output_path):
    """Save GeoJSON to file."""
    print(f"\nSaving raw GeoJSON to {output_path}...")
    
    try:
        with open(output_path, 'w') as f:
            json.dump(geojson, f)
        
        size_mb = os.path.getsize(output_path) / (1024*1024)
        print(f"  ✓ Saved ({size_mb:.1f} MB)")
        return output_path
        
    except Exception as e:
        print(f"ERROR: {e}")
        return None

def process_and_backup(output_path):
    """Backup current counties.json and replace with raw Census data."""
    current_path = "CountyTrackerIOS/counties.json"
    backup_path = "CountyTrackerIOS/counties_simplified_backup.json"
    
    if os.path.exists(current_path):
        print(f"\nBacking up current {current_path}...")
        shutil.copy(current_path, backup_path)
        print(f"  ✓ Saved to {backup_path}")
    
    print(f"\nReplacing with raw Census data...")
    shutil.move(output_path, current_path)
    print(f"  ✓ Replaced {current_path}")
    
    return current_path

def main():
    print("="*70)
    print("US Census TIGER/Line Raw County Boundaries (No Simplification)")
    print("="*70)
    
    # Download
    print("\nStep 1: DOWNLOAD")
    print("-"*70)
    result = download_census_counties()
    if not result:
        print("Failed to download Census data")
        return
    
    shapefile_path, temp_dir = result
    
    try:
        # Convert to GeoJSON (raw, no simplification)
        print("\nStep 2: CONVERT (Raw - No Simplification)")
        print("-"*70)
        geojson = shapefile_to_geojson_raw(shapefile_path)
        if not geojson:
            print("Failed to convert shapefile")
            return
        
        # Save temporary GeoJSON
        print("\nStep 3: SAVE")
        print("-"*70)
        temp_output = "CountyTrackerIOS/counties_raw_census.json"
        if not save_geojson(geojson, temp_output):
            return
        
        # Replace current data
        print("\nStep 4: REPLACE")
        print("-"*70)
        final_path = process_and_backup(temp_output)
        
        print("\n" + "="*70)
        print("✓ SUCCESS!")
        print("="*70)
        print(f"\n{final_path} now contains raw US Census county boundaries.")
        print("\nFeatures:")
        print("  • No simplification applied - preserves all Census detail")
        print("  • County boundaries should perfectly align (no gaps)")
        print("  • File size will be larger than simplified version")
        print("\nNext steps:")
        print("  1. Build and test the app")
        print("  2. Verify gaps at county intersections are eliminated")
        print("  3. Check map rendering performance")
        print("\nIf performance issues occur:")
        print(f"  cp {final_path.replace('.json', '_simplified_backup.json')} {final_path}")
        print("  (Restore simplified version with: restore_simplified.py)")
        
    finally:
        # Cleanup
        shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == "__main__":
    main()
