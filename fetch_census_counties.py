#!/usr/bin/env python3
"""
Download and convert US Census Bureau county boundaries to GeoJSON.
Uses the US Census Bureau's TIGER/Line Shapefiles for 2023 county boundaries.
"""

import json
import urllib.request
import zipfile
import os
import tempfile
import subprocess
from pathlib import Path

def download_census_counties():
    """
    Download US Census Bureau TIGER/Line county boundaries.
    These are the official, properly-aligned county boundaries.
    """
    print("Downloading US Census Bureau county boundaries...")
    
    # TIGER/Line 2023 county boundaries
    url = "https://www2.census.gov/geo/tiger/TIGER2023/COUNTY/tl_2023_us_county.zip"
    
    temp_dir = tempfile.mkdtemp()
    zip_path = os.path.join(temp_dir, "counties.zip")
    
    try:
        print(f"Downloading from {url}...")
        urllib.request.urlretrieve(url, zip_path)
        print(f"Downloaded to {zip_path}")
        
        # Extract
        extract_dir = os.path.join(temp_dir, "extracted")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        # Find shapefile
        shapefile = None
        for f in os.listdir(extract_dir):
            if f.endswith(".shp"):
                shapefile = os.path.join(extract_dir, f)
                break
        
        if not shapefile:
            print("ERROR: Could not find .shp file in downloaded archive")
            return None
        
        print(f"Found shapefile: {shapefile}")
        return shapefile, extract_dir
        
    except Exception as e:
        print(f"ERROR downloading: {e}")
        return None

def shapefile_to_geojson(shapefile_path):
    """
    Convert shapefile to GeoJSON using ogr2ogr (requires GDAL).
    If GDAL not available, try with pyshp library.
    """
    geojson_path = shapefile_path.replace('.shp', '.geojson')
    
    try:
        # Try with ogr2ogr first (faster, better quality)
        print(f"Converting shapefile to GeoJSON with ogr2ogr...")
        subprocess.run([
            'ogr2ogr',
            '-f', 'GeoJSON',
            geojson_path,
            shapefile_path
        ], check=True, capture_output=True)
        print(f"Converted to {geojson_path}")
        return geojson_path
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        print(f"ogr2ogr not available: {e}")
        print("Trying with pyshp library...")
        
        try:
            import shapefile
        except ImportError:
            print("ERROR: Neither GDAL nor pyshp available. Install with:")
            print("  brew install gdal  # macOS")
            print("  pip install pyshp")
            return None
        
        # Use pyshp
        sf = shapefile.Reader(shapefile_path)
        features = []
        
        for i, shape in enumerate(sf.shapes()):
            record = sf.record(i)
            
            feature = {
                "type": "Feature",
                "properties": dict(zip([field[0] for field in sf.fields[1:]], record)),
                "geometry": shape.__geo_interface__
            }
            features.append(feature)
        
        geojson = {
            "type": "FeatureCollection",
            "features": features
        }
        
        with open(geojson_path, 'w') as f:
            json.dump(geojson, f)
        
        print(f"Converted to {geojson_path}")
        return geojson_path

def simplify_geojson(geojson_path, output_path, tolerance=0.01):
    """
    Simplify GeoJSON using mapshaper (js library via node).
    If mapshaper not available, use a simple Python simplification.
    """
    print(f"Simplifying GeoJSON with tolerance={tolerance}...")
    
    try:
        # Try with mapshaper via node
        subprocess.run([
            'mapshaper',
            geojson_path,
            f'-simplify',
            f'interval={tolerance}',
            '-o', 'format=geojson',
            output_path
        ], check=True, capture_output=True)
        print(f"Simplified with mapshaper: {output_path}")
        return True
    except FileNotFoundError:
        print("mapshaper not available")
        print("Install with: npm install -g mapshaper")
        print("For now, using unsimplified GeoJSON (larger file size)")
        
        # Just copy the original
        import shutil
        shutil.copy(geojson_path, output_path)
        return True

def process_census_geojson(geojson_path, output_path):
    """
    Process Census GeoJSON to match the format expected by CountyTracker:
    - Extract relevant properties
    - Ensure NAME and STUSAB fields
    """
    print(f"Processing Census GeoJSON...")
    
    with open(geojson_path) as f:
        data = json.load(f)
    
    features = data.get('features', [])
    print(f"Found {len(features)} county features")
    
    # The Census TIGER file has different property names, we need to map them
    # NAMELSAD = Name with land status, STUSAB = State USPS abbreviation
    for feature in features:
        props = feature.get('properties', {})
        
        # Extract county name (remove suffixes like "County", "Parish", etc)
        namelsad = props.get('NAMELSAD', '')
        name = namelsad.replace(' County', '').replace(' Parish', '').replace(' Borough', '')
        
        # Ensure we have the fields the app expects
        props['NAME'] = name
        props['STUSAB'] = props.get('STUSAB', '')
        
        # Preserve other useful fields
        # (Keep existing props for compatibility)
    
    output_data = {
        "type": "FeatureCollection",
        "features": features
    }
    
    with open(output_path, 'w') as f:
        json.dump(output_data, f)
    
    print(f"Processed GeoJSON saved to {output_path}")
    return output_path

def main():
    print("="*60)
    print("US Census Bureau County Boundary Download & Conversion")
    print("="*60)
    
    # Check for required tools
    print("\nChecking for required tools...")
    try:
        subprocess.run(['ogr2ogr', '--version'], capture_output=True, check=True)
        print("✓ ogr2ogr (GDAL) found")
    except:
        print("✗ ogr2ogr not found - install with: brew install gdal")
    
    try:
        subprocess.run(['mapshaper', '--version'], capture_output=True, check=True)
        print("✓ mapshaper found")
    except:
        print("✗ mapshaper not found (optional) - install with: npm install -g mapshaper")
    
    # Download
    result = download_census_counties()
    if not result:
        print("Failed to download Census boundaries")
        return
    
    shapefile, temp_dir = result
    
    try:
        # Convert to GeoJSON
        geojson_path = shapefile_to_geojson(shapefile)
        if not geojson_path:
            print("Failed to convert shapefile to GeoJSON")
            return
        
        # Simplify
        simplified_path = geojson_path.replace('.geojson', '_simplified.geojson')
        simplify_geojson(geojson_path, simplified_path, tolerance=0.01)
        
        # Process (add required fields)
        output_path = "CountyTrackerIOS/counties.json"
        process_census_geojson(simplified_path, output_path)
        
        print(f"\n✓ Successfully created {output_path}")
        print("\nNext steps:")
        print("1. Test the app with the new county boundaries")
        print("2. Verify that gaps between counties are resolved")
        print("3. Commit the updated counties.json file")
        
    finally:
        # Cleanup temp files
        import shutil
        shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == "__main__":
    main()
