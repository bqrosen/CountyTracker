#!/usr/bin/env python3
"""Simplify the Census GeoJSON using mapshaper."""

import subprocess
import json
import os

json_file = "CountyTrackerIOS/counties.json"
simplified_file = "CountyTrackerIOS/counties_simplified.json"

print(f"Simplifying {json_file} with mapshaper...")
print("This may take a few minutes...")

# Use mapshaper to simplify geometry
# tolerance of 0.005 degrees (~500m) should be good for county boundaries
try:
    result = subprocess.run([
        'mapshaper',
        json_file,
        '-simplify',
        'interval=0.005',
        '-o', 'format=geojson',
        simplified_file
    ], capture_output=True, text=True, timeout=600)
    
    if result.returncode == 0:
        print(f"✓ Simplified successfully")
        
        # Check file sizes
        orig_size_mb = os.path.getsize(json_file) / (1024*1024)
        simp_size_mb = os.path.getsize(simplified_file) / (1024*1024)
        ratio = simp_size_mb / orig_size_mb * 100
        
        print(f"  Original: {orig_size_mb:.1f} MB")
        print(f"  Simplified: {simp_size_mb:.1f} MB ({ratio:.0f}%)")
        
        # Replace original with simplified
        import shutil
        shutil.move(simplified_file, json_file)
        print(f"✓ Replaced original with simplified version")
    else:
        print(f"✗ Error: {result.stderr}")
        
except subprocess.TimeoutExpired:
    print("✗ Timeout - simplification took too long")
except Exception as e:
    print(f"✗ Error: {e}")
